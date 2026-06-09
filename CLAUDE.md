# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目性质

这是一个 Claude Code Skill（不是 npm 包/应用），通过 `SKILL.md` 由 AI 按步骤驱动执行。**唯一入口是 [SKILL.md](SKILL.md)**，里面写死了完整的执行流程（步骤 0-7、模式 A/B）。改流程时改 SKILL.md，改代码时改 scripts/。

架构详情见 [ARCHITECTURE.md](ARCHITECTURE.md)，设计原则与脚本规范见 [AGENTS.md](AGENTS.md)，变更记录见 [CHANGELOG.md](CHANGELOG.md)。本文件只补这三份没写到的内容。

## 时间线导出格式：FCPXML（同时支持 FCP 和剪映）

**这个 skill 不直接剪视频，只生成剪辑工程文件给真正的剪辑软件做最后一步。** 审核网页上点「导出 FCPXML」后，[scripts/review_server.js](scripts/review_server.js) 的 `/api/fcpxml` 路由生成 **FCPXML 1.8** 格式的项目文件 `*_cut.fcpxml`，写到视频所在目录。

**这一个文件同时被两种软件识别**：
- **Final Cut Pro**：双击 `.fcpxml` 即可导入
- **剪映专业版（中国版）/ CapCut**：菜单 **文件 → 导入 → Final Cut Pro XML**（或类似命名），选中 `.fcpxml` 文件即可。剪辑时间线、保留段顺序、源视频引用都会被还原。剪映 2025 后版本原生支持此格式，无需任何转换工具或插件。

修改 FCPXML 生成逻辑时注意：
- FCPXML 1.8 DTD 不支持 fade 元素，淡入淡出留给剪辑软件自己加
- 媒体引用用绝对路径（`file://` URI 经过百分号编码），剪映和 FCP 都依赖这一点定位源视频
- 时间用 FCP ticks（`帧号 × fpsDen`），不要改成秒

## 切割算法单一来源：scripts/lib/compute_keeps.js（前后端共用，改这里）

「删除段 → 实际保留片段」的全部逻辑（合并相邻删除段 → 取反 → 边界向静音吸附 → 保留段内部
长静音二次切）只有一份：[scripts/lib/compute_keeps.js](scripts/lib/compute_keeps.js)，UMD 模块。
- `review_server.js` 的 `/api/fcpxml` `require` 它生成 FCPXML；
- 审核页前端经 `/lib/compute_keeps.js` 路由（review_server.js 从 `scripts/lib` 直供，**不拷贝**）
  复用同一份，在波形上实时预览「真正会切到哪一帧」。

**禁止把切割逻辑再写回 server 或前端内联**——那会复现前后端预览漂移。审核页「切割参数」只暴露
两个用户能直观感受的滑块：`padStart`（起始留白）/ `padEnd`（结尾留白）。另两个阈值
`lookBack`（切口吸附停顿）/ `minInternalSilence`（内部长卡顿二次切）已**固定为默认值不再暴露**
——它们是「工具自动做对的事」，面板用一段静态说明讲清机制即可（为开源做减法）。所有参数导出时随
请求体 `{ deleteList, opts }` 发给 server，确保预览与产物一致；要调那两个固定值就改 `cutOpts` 默认。

审核页波形是**自绘 canvas**（已弃用 wavesurfer），用导出阶段预生成的 `peaks.json`（4000Hz
单声道包络）渲染，长视频也顺滑。波形叠加：灰=静音 / 红=选中删除 / 黄=算法额外切掉（误伤高危区）。
改 `peaks.json` 生成逻辑在 `generate_review.js`；`fixtures/sample/peaks.json` 是开发预览用的固化样本。

## 关键命令

转录 + 分析 + 启动审核服务器（参数见 [SKILL.md 步骤 1-7](SKILL.md)）：
```bash
SKILL_DIR="$HOME/.claude/skills/AI剪口播"
"$SKILL_DIR/scripts/run_transcribe.sh" "<video>" "<base_dir>"     # 步骤 1-4
node "$SKILL_DIR/scripts/gen_analysis.js" ...                     # 步骤 5.1
node "$SKILL_DIR/scripts/auto_filler.js" ...                      # 步骤 5.4
node "$SKILL_DIR/scripts/merge_selections.js" ...                 # 步骤 5.6
node "$SKILL_DIR/scripts/generate_review.js" ...                  # 步骤 6
( cd <base>/3_审核 && node "$SKILL_DIR/scripts/review_server.js" <port> "<video>" )  # 步骤 7
```

审核服务器**必须**在 `3_审核/` 目录内启动，否则静态文件路径错乱。端口轮询 8899-8902 自动避让。

API Key：`~/.claude/skills/.env` 的 `VOLCENGINE_API_KEY`。可选热词词典：`scripts/词典.txt`。

## 本地开发预览（改审核页前端时用这个，不要再造 mock 页）

审核页前端**只有一份**：[scripts/templates/review.html](scripts/templates/review.html)。它既是生产模板（`generate_review.js` 复制它到输出目录），也是开发预览页。**禁止**再复制出第二份内联数据的 mock 文件——副本必然和模板漂移（历史上的 mock_demo.html 已因此删除）。

开发时跑：
```bash
bash scripts/dev.sh [port]    # 默认 8899
```
它拿 [scripts/fixtures/sample/](scripts/fixtures/sample)（一份固化的真实数据：data.json + audio.mp3 + silence_periods.json + video.mp4）+ 最新 `templates/review.html`，用 `review_server.js` 起服务并自动打开浏览器。改完模板重跑即可，全程不需要跑转录流水线。

> 审核页依赖 server 提供 `/video`（range 请求）、`/audio`、`/api/fcpxml`，**无法靠双击 file:// 打开**，必须经 `review_server.js`。`dev.sh` 就是这件事的一键封装；launch.json 的 `dev-preview` 配置等价于跑 `dev.sh`。

## 数据契约（修改脚本时必读）

`subtitles_words.json` 是核心数据，其它脚本都建立在它的 idx 基础上：
```json
[{"text": "大", "start": 0.12, "end": 0.2, "isGap": false}, ...]
```
- 数组下标 = idx（贯穿 auto_selected.json / speech_errors.json / sentence_map.json）
- `isGap: true` 是静音段（拆分阈值 1s）
- 改这个结构会连锁打穿 5-6 个脚本

AI 识别口误时**只输出句号数组**（不输出 idx），由 [merge_selections.js](scripts/merge_selections.js) 经 sentence_map.json 展开为 idx。这条决策记录在 AGENTS.md「架构决策记录」一节，改流程前先读。

## 脚本规范

所有生成脚本必须**接收输出目录作为参数**，禁止写 cwd。HTTP Header 含中文必须用 RFC 5987 编码（`filename*=UTF-8''`）。

## 改动后必做

按 AGENTS.md 顶部要求：每次改动后追加 `CHANGELOG.md`，按 `## YYYY-MM-DD` 日期分组。
</content>
</invoke>