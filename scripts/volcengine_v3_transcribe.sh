#!/bin/bash
#
# 火山引擎 v3 大模型语音识别（异步模式）
#
# 用法:
#   ./volcengine_v3_transcribe.sh <local_file.mp3> [output_dir]   ← 推荐，base64 直传
#   ./volcengine_v3_transcribe.sh <audio_url>      [output_dir]   ← 兼容旧用法
#
# 输出: <output_dir>/volcengine_v3_result.json
#
# 与 v1 的主要差异：
#   - 单 X-Api-Key 认证（新版控制台），与 flash 共用同一个 VOLCENGINE_API_KEY
#   - task_id = 自己生成的 UUID，提交和查询复用同一个
#   - 响应结构: { result: { utterances: [...] } }（v1 是顶层 utterances）
#   - 词级字段名与 v1 相同: text / start_time / end_time
#   - audio.url 与 audio.data（base64）二选一
#

AUDIO_INPUT="$1"
OUT_DIR="${2:-.}"

if [ -z "$AUDIO_INPUT" ]; then
  echo "❌ 用法: ./volcengine_v3_transcribe.sh <local_file_or_url> [output_dir]"
  exit 1
fi

# ── 读取凭证（与 flash 共用同一个新版控制台 API Key）────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$(dirname "$(dirname "$SCRIPT_DIR")")/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ 找不到 $ENV_FILE"
  exit 1
fi

API_KEY=$(grep '^VOLCENGINE_API_KEY=' "$ENV_FILE" | cut -d'=' -f2 | tr -d '\r\n ')

if [ -z "$API_KEY" ]; then
  echo "❌ $ENV_FILE 缺少 VOLCENGINE_API_KEY（新版控制台 API Key）"
  exit 1
fi

# ── 生成唯一 Request ID（提交和查询复用同一个）──────────────
REQUEST_ID=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
REQUEST_ID=$(echo "$REQUEST_ID" | tr '[:upper:]' '[:lower:]')

# ── 构建请求体（本地文件用 base64，URL 直接传）──────────────
TEMP_REQUEST=$(mktemp /tmp/v3_request_XXXXX.json)
trap 'rm -f "$TEMP_REQUEST"' EXIT

if [[ "$AUDIO_INPUT" =~ ^https?:// ]]; then
  echo "🎤 提交火山引擎 v3 大模型转录任务（URL 模式）..."
  echo "音频 URL: $AUDIO_INPUT"
  python3 - <<PYEOF > "$TEMP_REQUEST"
import json
req = {
    "user": {"uid": "ai_jiankoubo"},
    "audio": {"url": "$AUDIO_INPUT"},
    "request": {
        "model_name": "bigmodel",
        "enable_itn": True,
        "enable_punc": False,
        "enable_ddc": False,
        "show_utterances": True,
        "enable_speaker_info": False
    }
}
print(json.dumps(req))
PYEOF
else
  if [ ! -f "$AUDIO_INPUT" ]; then
    echo "❌ 文件不存在: $AUDIO_INPUT"
    exit 1
  fi
  FILE_SIZE=$(du -sh "$AUDIO_INPUT" | cut -f1)
  echo "🎤 提交火山引擎 v3 大模型转录任务（base64 模式）..."
  echo "音频文件: $AUDIO_INPUT ($FILE_SIZE)"
  python3 - "$AUDIO_INPUT" <<'PYEOF' > "$TEMP_REQUEST"
import json, base64, sys
with open(sys.argv[1], "rb") as f:
    data = base64.b64encode(f.read()).decode()
req = {
    "user": {"uid": "ai_jiankoubo"},
    "audio": {"data": data},
    "request": {
        "model_name": "bigmodel",
        "enable_itn": True,
        "enable_punc": False,
        "enable_ddc": False,
        "show_utterances": True,
        "enable_speaker_info": False
    }
}
print(json.dumps(req))
PYEOF
fi

echo "Request ID: $REQUEST_ID"

# ── 步骤 1: 提交任务 ────────────────────────────────────────
SUBMIT_RESPONSE=$(curl -s -L -X POST "https://openspeech.bytedance.com/api/v3/auc/bigmodel/submit" \
  -H "X-Api-Key: $API_KEY" \
  -H "X-Api-Resource-Id: volc.bigasr.auc" \
  -H "X-Api-Request-Id: $REQUEST_ID" \
  -H "X-Api-Sequence: -1" \
  -H "Content-Type: application/json" \
  --data-binary "@$TEMP_REQUEST")

echo "提交响应: $SUBMIT_RESPONSE"

# 检查提交是否成功（v3 成功提交返回空 {} 或包含状态码）
# 如果包含明显错误信息则退出
if echo "$SUBMIT_RESPONSE" | grep -q '"message"'; then
  ERROR_MSG=$(echo "$SUBMIT_RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
  if [ -n "$ERROR_MSG" ] && [ "$ERROR_MSG" != "success" ] && [ "$ERROR_MSG" != "ok" ]; then
    echo "❌ 提交失败: $ERROR_MSG"
    exit 1
  fi
fi

echo "✅ 任务已提交"
echo "⏳ 等待转录完成..."

# ── 步骤 2: 轮询结果 ────────────────────────────────────────
MAX_ATTEMPTS=120  # 最多等待 10 分钟（每 5 秒一次）
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  sleep 5
  ATTEMPT=$((ATTEMPT + 1))

  QUERY_RESPONSE=$(curl -s -L -X POST "https://openspeech.bytedance.com/api/v3/auc/bigmodel/query" \
    -H "X-Api-Key: $API_KEY" \
    -H "X-Api-Resource-Id: volc.bigasr.auc" \
    -H "X-Api-Request-Id: $REQUEST_ID" \
    -H "X-Api-Sequence: -1" \
    -H "Content-Type: application/json" \
    -d "{}")

  # 提取状态码（v3 状态码在响应体的 resp_header 或顶层）
  STATUS=$(echo "$QUERY_RESPONSE" | grep -o '"status_code":[0-9]*' | head -1 | cut -d':' -f2)

  if [ -z "$STATUS" ]; then
    # 备用：检查顶层 code 字段
    STATUS=$(echo "$QUERY_RESPONSE" | grep -o '"code":[0-9]*' | head -1 | cut -d':' -f2)
  fi

  if [ "$STATUS" = "20000000" ]; then
    # 成功
    echo "$QUERY_RESPONSE" > "$OUT_DIR/volcengine_v3_result.json"
    echo ""
    echo "✅ 转录完成，已保存 $OUT_DIR/volcengine_v3_result.json"

    # 显示识别到的文字数量
    WORD_COUNT=$(echo "$QUERY_RESPONSE" | grep -o '"text"' | wc -l | tr -d ' ')
    echo "📝 识别到 $WORD_COUNT 个文本段"
    exit 0

  elif [ "$STATUS" = "20000001" ] || [ "$STATUS" = "20000002" ]; then
    # 处理中 / 排队中
    echo -n "."

  elif [ "$STATUS" = "20000003" ]; then
    echo ""
    echo "⚠️  音频为静音，无法识别"
    exit 1

  elif [ -n "$STATUS" ]; then
    # 其他错误码
    echo ""
    echo "❌ 转录失败（状态码: $STATUS），响应:"
    echo "$QUERY_RESPONSE"
    exit 1

  else
    # 状态码未知，可能 v3 的响应格式不同，检查是否有 result 字段
    HAS_RESULT=$(echo "$QUERY_RESPONSE" | grep -c '"result"')
    HAS_UTTERANCES=$(echo "$QUERY_RESPONSE" | grep -c '"utterances"')

    if [ "$HAS_UTTERANCES" -gt 0 ]; then
      # 有 utterances 数据，认为成功
      echo "$QUERY_RESPONSE" > "$OUT_DIR/volcengine_v3_result.json"
      echo ""
      echo "✅ 转录完成，已保存 $OUT_DIR/volcengine_v3_result.json"
      exit 0
    elif [ "$HAS_RESULT" -gt 0 ] && [ $ATTEMPT -gt 3 ]; then
      # result 存在但没有 utterances，可能是空结果
      echo ""
      echo "⚠️  结果为空，完整响应:"
      echo "$QUERY_RESPONSE"
      exit 1
    else
      echo -n "."
    fi
  fi
done

echo ""
echo "❌ 超时，任务未完成"
exit 1
