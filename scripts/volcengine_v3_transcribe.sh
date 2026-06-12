#!/bin/bash
#
# 火山引擎 v3 大模型语音识别标准版（异步模式）
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
#   - 标准版任务状态在响应头 X-Api-Status-Code，不在响应体
#     （20000000 成功 / 20000001 处理中 / 20000002 排队中 / 20000003 静音）
#   - 响应结构: { result: { utterances: [...] } }（v1 是顶层 utterances）
#   - 词级字段名与 v1 相同: text / start_time / end_time
#   - audio.url 与 audio.data（base64）二选一
#   - 标准版 API: https://www.volcengine.com/docs/6561/1354868
#

AUDIO_INPUT="$1"
OUT_DIR="${2:-.}"

if [ -z "$AUDIO_INPUT" ]; then
  echo "❌ 用法: ./volcengine_v3_transcribe.sh <local_file_or_url> [output_dir]"
  exit 1
fi

# ── 读取凭证（与 flash 共用同一个新版控制台 API Key；见 lib/load_api_key.sh）──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/load_api_key.sh"

is_local_input=0

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
    "audio": {"url": "$AUDIO_INPUT", "format": "mp3"},
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
  is_local_input=1
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
    "audio": {"data": data, "format": "mp3"},
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
# 标准版状态码在响应头（X-Api-Status-Code），不在 body —— 必须用 -D 抓头部。
SUBMIT_HEADERS=$(mktemp /tmp/v3_submit_headers_XXXXX.txt)
SUBMIT_BODY=$(mktemp /tmp/v3_submit_body_XXXXX.json)
QUERY_HEADERS=$(mktemp /tmp/v3_query_headers_XXXXX.txt)
QUERY_BODY=$(mktemp /tmp/v3_query_body_XXXXX.json)
trap 'rm -f "$TEMP_REQUEST" "$SUBMIT_HEADERS" "$SUBMIT_BODY" "$QUERY_HEADERS" "$QUERY_BODY"' EXIT

HTTP_CODE=$(curl -s -L -D "$SUBMIT_HEADERS" -o "$SUBMIT_BODY" -w "%{http_code}" -X POST "https://openspeech.bytedance.com/api/v3/auc/bigmodel/submit" \
  -H "X-Api-Key: $API_KEY" \
  -H "X-Api-Resource-Id: volc.bigasr.auc" \
  -H "X-Api-Request-Id: $REQUEST_ID" \
  -H "X-Api-Sequence: -1" \
  -H "Content-Type: application/json" \
  --data-binary "@$TEMP_REQUEST")

SUBMIT_STATUS=$(grep -i '^x-api-status-code:' "$SUBMIT_HEADERS" | tail -1 | tr -d '\r' | awk '{print $2}')
SUBMIT_MSG=$(grep -i '^x-api-message:' "$SUBMIT_HEADERS" | tail -1 | tr -d '\r' | cut -d' ' -f2-)
# query 时要带回 submit 返回的 logid，否则标准版可能查不到任务
LOG_ID=$(grep -i '^x-tt-logid:' "$SUBMIT_HEADERS" | tail -1 | tr -d '\r' | cut -d' ' -f2-)

echo "提交状态: ${SUBMIT_STATUS:-未返回} ${SUBMIT_MSG:-}"

if [ "$SUBMIT_STATUS" != "20000000" ]; then
  echo "❌ 提交失败"
  echo "   HTTP: $HTTP_CODE"
  echo "   状态码: ${SUBMIT_STATUS:-未返回}"
  echo "   消息: ${SUBMIT_MSG:-未返回}"
  echo "完整响应:"
  cat "$SUBMIT_BODY"
  echo ""
  exit 1
fi

echo "✅ 任务已提交"
echo "⏳ 等待转录完成..."

# ── 步骤 2: 轮询结果 ────────────────────────────────────────
# 关键：只看响应头 X-Api-Status-Code 判状态。
# 20000001/20000002 = 仍在处理/排队 → 继续轮询；
# 不要因为此时 body 是 {"result":{"text":""}} 这种空结果就误判“结果为空”退出。
MAX_ATTEMPTS=120  # 最多等待 10 分钟（每 5 秒一次）
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  sleep 5
  ATTEMPT=$((ATTEMPT + 1))

  if [ -n "$LOG_ID" ]; then
    curl -s -L -D "$QUERY_HEADERS" -o "$QUERY_BODY" -X POST "https://openspeech.bytedance.com/api/v3/auc/bigmodel/query" \
      -H "X-Api-Key: $API_KEY" \
      -H "X-Api-Resource-Id: volc.bigasr.auc" \
      -H "X-Api-Request-Id: $REQUEST_ID" \
      -H "X-Tt-Logid: $LOG_ID" \
      -H "Content-Type: application/json" \
      -d "{}"
  else
    curl -s -L -D "$QUERY_HEADERS" -o "$QUERY_BODY" -X POST "https://openspeech.bytedance.com/api/v3/auc/bigmodel/query" \
      -H "X-Api-Key: $API_KEY" \
      -H "X-Api-Resource-Id: volc.bigasr.auc" \
      -H "X-Api-Request-Id: $REQUEST_ID" \
      -H "Content-Type: application/json" \
      -d "{}"
  fi

  STATUS=$(grep -i '^x-api-status-code:' "$QUERY_HEADERS" | tail -1 | tr -d '\r' | awk '{print $2}')
  MSG=$(grep -i '^x-api-message:' "$QUERY_HEADERS" | tail -1 | tr -d '\r' | cut -d' ' -f2-)

  if [ "$STATUS" = "20000000" ]; then
    # 成功
    cp "$QUERY_BODY" "$OUT_DIR/volcengine_v3_result.json"
    echo ""
    echo "✅ 转录完成，已保存 $OUT_DIR/volcengine_v3_result.json"

    # 显示识别到的文字数量
    WORD_COUNT=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); r=d.get("result",{}); print("%d utterances / %d 字" % (len(r.get("utterances",[]) or []), len(r.get("text","") or "")))' "$OUT_DIR/volcengine_v3_result.json" 2>/dev/null || echo "?")
    echo "📝 识别结果: $WORD_COUNT"
    exit 0

  elif [ "$STATUS" = "20000001" ] || [ "$STATUS" = "20000002" ]; then
    # 处理中 / 排队中 —— 继续等，空 body 是正常的
    echo -n "."

  elif [ "$STATUS" = "20000003" ]; then
    echo ""
    echo "⚠️  音频为静音，无法识别"
    exit 1

  elif [ -n "$STATUS" ]; then
    # 其他错误码
    echo ""
    echo "❌ 转录失败（状态码: $STATUS），响应:"
    echo "   消息: ${MSG:-未返回}"
    if [ "$STATUS" = "45000000" ] && [ "$is_local_input" = "1" ]; then
      echo "   诊断: 若 submit 返回 OK 但 query 查不到任务，可改用 --flash，或传公网音频 URL。"
    fi
    cat "$QUERY_BODY"
    echo ""
    exit 1

  else
    # 头部暂时没拿到状态码，继续轮询
    echo -n "."
  fi
done

echo ""
echo "❌ 超时，任务未完成"
exit 1
