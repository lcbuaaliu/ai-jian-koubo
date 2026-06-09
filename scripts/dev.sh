#!/usr/bin/env bash
# Dev preview for the review page. Uses bundled fixture so you can iterate on
# templates/review.html without running the full transcription pipeline.
#
# Usage: bash scripts/dev.sh [port]
#
# Workflow:
#   1. Copy fixture (data.json/audio.mp3/silence_periods.json/video.mp4) to a tmp dir
#   2. Copy the latest templates/review.html into the tmp dir
#   3. Start review_server.js in that dir, pointing at the fixture video
#   4. Open browser. Refresh after editing review.html — re-run to pick up template changes.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures/sample"
WORK_DIR="${TMPDIR:-/tmp}/AI剪口播-dev"
PORT="${1:-8899}"

if [ ! -d "$FIXTURE_DIR" ]; then
  echo "❌ fixture 不存在: $FIXTURE_DIR" >&2
  exit 1
fi

# Fresh work dir each run so template + fixture stay in sync
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp "$FIXTURE_DIR/data.json" "$WORK_DIR/"
cp "$FIXTURE_DIR/audio.mp3" "$WORK_DIR/"
cp "$FIXTURE_DIR/silence_periods.json" "$WORK_DIR/"
cp "$FIXTURE_DIR/peaks.json" "$WORK_DIR/"
cp "$SCRIPT_DIR/templates/review.html" "$WORK_DIR/"
# lib/compute_keeps.js 由 review_server.js 经 /lib 路由直供，无需拷贝

VIDEO_PATH="$FIXTURE_DIR/video.mp4"

# Free port if needed (dev convenience — kill any prior dev server)
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "⚠️  端口 $PORT 已被占用，尝试释放旧的 dev server..."
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t | xargs kill 2>/dev/null || true
  sleep 0.5
fi

echo "📁 工作目录: $WORK_DIR"
echo "🎬 视频: $VIDEO_PATH"
echo "🌐 启动: http://localhost:$PORT"
echo "   (Ctrl+C 停止；编辑 templates/review.html 后重跑本脚本)"
echo ""

cd "$WORK_DIR"
open -n "http://localhost:$PORT" 2>/dev/null &
exec node "$SCRIPT_DIR/review_server.js" "$PORT" "$VIDEO_PATH"
