#!/bin/bash
#
# 步骤 0-4 自动化流水线
# 用法: ./run_transcribe.sh <video.mp4> [base_output_dir] [--engine]
#
# 引擎选项（默认 auto 轮流）:
#   （无）/--auto 每次在 flash / 标准版 间交替，分摊两份各 20h 免费额度 ≈ 共 40h
#                 （需在控制台同时开通极速版 auc_turbo 与标准版 auc 两个资源）
#   --flash       只用极速版 auc_turbo（一次直出、最快；只开了一个资源时用这个）
#   --v3-standard 只用标准版 auc（异步轮询，base64 未文档化但实测可用）
#   --v1          旧版 ASR（必须先把音频上传到公网图床 uguu.se，不推荐）
#
# 输出: base_output_dir/1_转录/
#   ├── audio.mp3
#   ├── volcengine_v3_result.json （或 volcengine_result.json，取决于引擎）
#   └── subtitles_words.json
#

set -e

VIDEO_PATH="$1"
BASE_DIR="${2:-.}"
ENGINE="auto"  # 默认 flash / 标准版 轮流，吃满两份免费额度

# 检测引擎参数（任意位置）
for arg in "$@"; do
  case "$arg" in
    --v1)          ENGINE="v1" ;;
    --v3-standard) ENGINE="v3-standard" ;;
    --flash)       ENGINE="flash" ;;
    --auto)        ENGINE="auto" ;;
  esac
done

if [ -z "$VIDEO_PATH" ]; then
  echo "用法: $0 <video.mp4> [base_output_dir] [--v3-standard|--v1]"
  exit 1
fi

if [ ! -f "$VIDEO_PATH" ]; then
  echo "❌ 视频文件不存在: $VIDEO_PATH"
  exit 1
fi

# 依赖预检
for cmd in ffmpeg node python3 curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ 缺少依赖: $cmd"
    case "$cmd" in
      ffmpeg) echo "   macOS: brew install ffmpeg" ;;
      node)   echo "   macOS: brew install node" ;;
    esac
    exit 1
  fi
done

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# --auto：在 flash / 标准版 间轮流，让两份各 20h 的免费额度都被消耗（共 ≈40h）
if [ "$ENGINE" = "auto" ]; then
  STATE="$SKILL_DIR/.engine_toggle"
  [ "$(cat "$STATE" 2>/dev/null)" = "flash" ] && ENGINE="v3-standard" || ENGINE="flash"
  echo "$ENGINE" > "$STATE"
  echo "🔄 auto 轮流：本次用 $ENGINE"
fi

TRANSCRIBE_DIR="$BASE_DIR/1_转录"
mkdir -p "$TRANSCRIBE_DIR"

# ── 步骤 1: 提取音频 ────────────────────────────────────
echo "📦 步骤1: 提取音频..."
ffmpeg -i "file:$VIDEO_PATH" -vn -acodec libmp3lame -y "$TRANSCRIBE_DIR/audio.mp3" 2>/dev/null
echo "✅ 音频已保存: $TRANSCRIBE_DIR/audio.mp3"

# ── 步骤 2+3: 转录 ─────────────────────────────────────
echo "🚀 步骤2+3: 转录（引擎: $ENGINE）..."

case "$ENGINE" in
  flash)
    "$SKILL_DIR/scripts/volcengine_flash_transcribe.sh" "$TRANSCRIBE_DIR/audio.mp3" "$TRANSCRIBE_DIR"
    RESULT_FILE="$TRANSCRIBE_DIR/volcengine_v3_result.json"
    ;;
  v3-standard)
    "$SKILL_DIR/scripts/volcengine_v3_transcribe.sh" "$TRANSCRIBE_DIR/audio.mp3" "$TRANSCRIBE_DIR"
    RESULT_FILE="$TRANSCRIBE_DIR/volcengine_v3_result.json"
    ;;
  v1)
    (
      cd "$TRANSCRIBE_DIR"
      echo "  ⚠️  v1 引擎需要把音频上传到公网图床（uguu.se），存在隐私风险"
      echo "  上传音频到 uguu.se..."
      UPLOAD_RESP=$(curl -s -F "files[]=@audio.mp3" https://uguu.se/upload)
      AUDIO_URL=$(echo "$UPLOAD_RESP" | node -e "process.stdin.resume();let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).files[0].url))")
      if [ -z "$AUDIO_URL" ]; then
        echo "❌ 上传失败，响应: $UPLOAD_RESP"
        exit 1
      fi
      echo "  音频URL: $AUDIO_URL"
      "$SKILL_DIR/scripts/volcengine_transcribe.sh" "$AUDIO_URL" "$TRANSCRIBE_DIR"
    )
    RESULT_FILE="$TRANSCRIBE_DIR/volcengine_result.json"
    ;;
  *)
    echo "❌ 未知引擎: $ENGINE"
    exit 1
    ;;
esac

echo "✅ 步骤2+3 完成"

# ── 步骤 4: 生成字幕 ───────────────────────────────────
echo "📝 步骤4: 生成字幕..."
node "$SKILL_DIR/scripts/generate_subtitles.js" \
  "$RESULT_FILE" \
  "" \
  "$TRANSCRIBE_DIR"

echo ""
echo "🎉 流水线完成！"
echo "   输出目录: $TRANSCRIBE_DIR"
ls -lh "$TRANSCRIBE_DIR"/*.mp3 "$TRANSCRIBE_DIR"/*.json 2>/dev/null | awk '{print "     "$9"  "$5}'
