#!/bin/bash
#
# 火山引擎 大模型录音文件极速版（auc_turbo / flash 接口）
#
# 用法:
#   ./volcengine_flash_transcribe.sh <local_file>      [output_dir]   ← 推荐，base64 直传
#   ./volcengine_flash_transcribe.sh <https://...>     [output_dir]   ← URL 模式
#
# 输出: <output_dir>/volcengine_v3_result.json （沿用 v3 同名输出，下游脚本无需改动）
#
# 特点（与标准版 / v1 对比）:
#   - 一次请求直出，无需 submit/query 轮询
#   - 单 X-Api-Key 认证（新版控制台），env 里只要 VOLCENGINE_API_KEY 一个字段
#   - base64 直传是官方文档化方案，不依赖外部图床
#   - 限制: 音频 ≤ 2h、≤ 100MB
#

set -e

AUDIO_INPUT="$1"
OUT_DIR="${2:-.}"

if [ -z "$AUDIO_INPUT" ]; then
  echo "❌ 用法: $0 <local_file_or_url> [output_dir]"
  exit 1
fi

# ── 读取 API Key ────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$(dirname "$(dirname "$SCRIPT_DIR")")/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ 找不到 $ENV_FILE"
  echo "   请先创建该文件并填入: VOLCENGINE_API_KEY=<你的新版控制台 API Key>"
  echo "   申请地址: https://console.volcengine.com/speech/new/setting/apikeys"
  exit 1
fi

API_KEY=$(grep '^VOLCENGINE_API_KEY=' "$ENV_FILE" | cut -d'=' -f2 | tr -d '\r\n ')

if [ -z "$API_KEY" ]; then
  echo "❌ $ENV_FILE 缺少 VOLCENGINE_API_KEY"
  echo "   申请地址: https://console.volcengine.com/speech/new/setting/apikeys"
  exit 1
fi

# ── 校验音频（本地文件）──────────────────────────────────
if [[ ! "$AUDIO_INPUT" =~ ^https?:// ]]; then
  if [ ! -f "$AUDIO_INPUT" ]; then
    echo "❌ 音频文件不存在: $AUDIO_INPUT"
    exit 1
  fi
  FILE_BYTES=$(stat -f%z "$AUDIO_INPUT" 2>/dev/null || stat -c%s "$AUDIO_INPUT" 2>/dev/null)
  if [ -n "$FILE_BYTES" ] && [ "$FILE_BYTES" -gt 104857600 ]; then
    echo "❌ 音频超过 100MB（极速版上限），请使用标准版或先压缩"
    exit 1
  fi
fi

# ── 构建请求体 ──────────────────────────────────────────
TEMP_REQUEST=$(mktemp /tmp/flash_request_XXXXX.json)
trap 'rm -f "$TEMP_REQUEST"' EXIT

if [[ "$AUDIO_INPUT" =~ ^https?:// ]]; then
  echo "🎤 火山引擎 极速版 转录（URL 模式）..."
  echo "   音频 URL: $AUDIO_INPUT"
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
  FILE_SIZE=$(du -sh "$AUDIO_INPUT" | cut -f1)
  echo "🎤 火山引擎 极速版 转录（base64 模式）..."
  echo "   音频文件: $AUDIO_INPUT ($FILE_SIZE)"
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

REQUEST_ID=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
REQUEST_ID=$(echo "$REQUEST_ID" | tr '[:upper:]' '[:lower:]')

# ── 调用（一次请求直出）─────────────────────────────────
mkdir -p "$OUT_DIR"
TEMP_HEADERS=$(mktemp /tmp/flash_headers_XXXXX.txt)
trap 'rm -f "$TEMP_REQUEST" "$TEMP_HEADERS"' EXIT

echo "   提交转录请求..."
HTTP_CODE=$(curl -s -o "$OUT_DIR/volcengine_v3_result.json" -D "$TEMP_HEADERS" -w "%{http_code}" \
  -X POST "https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash" \
  -H "X-Api-Key: $API_KEY" \
  -H "X-Api-Resource-Id: volc.bigasr.auc_turbo" \
  -H "X-Api-Request-Id: $REQUEST_ID" \
  -H "X-Api-Sequence: -1" \
  -H "Content-Type: application/json" \
  --data-binary "@$TEMP_REQUEST")

STATUS=$(grep -i '^x-api-status-code:' "$TEMP_HEADERS" | tr -d '\r' | awk '{print $2}')
MSG=$(grep -i '^x-api-message:' "$TEMP_HEADERS" | tr -d '\r' | cut -d' ' -f2-)

if [ "$STATUS" = "20000000" ]; then
  WORD_COUNT=$(python3 -c "
import json
d = json.load(open('$OUT_DIR/volcengine_v3_result.json'))
utts = d.get('result', {}).get('utterances', [])
text = d.get('result', {}).get('text', '')
print(f'{len(utts)} utterances / {len(text)} 字')
" 2>/dev/null || echo "?")
  echo "✅ 转录完成: $OUT_DIR/volcengine_v3_result.json"
  echo "📝 识别结果: $WORD_COUNT"
  exit 0
fi

# ── 错误诊断 ─────────────────────────────────────────────
echo ""
echo "❌ 转录失败"
echo "   HTTP: $HTTP_CODE"
echo "   状态码: ${STATUS:-未返回}"
echo "   消息: ${MSG:-未返回}"
case "$STATUS" in
  45000010) echo "   提示: API Key 无效，检查 $ENV_FILE 的 VOLCENGINE_API_KEY 是否来自新版控制台" ;;
  45000151) echo "   提示: 资源未授权，去控制台开通「录音文件识别极速版」" ;;
  45000003) echo "   提示: 请求参数错误（可能是音频格式 / 大小不支持）" ;;
  55000031) echo "   提示: 服务端处理失败，建议稍后重试" ;;
esac
echo ""
echo "完整响应:"
cat "$OUT_DIR/volcengine_v3_result.json"
echo ""
exit 1
