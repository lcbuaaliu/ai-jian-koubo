# AI剪口播 — 架构文档

## 系统概述

输入：视频文件 (*.mp4)
输出：剪辑工程文件 (*.fcpxml，可导入剪映 / Final Cut Pro)
核心：转录 → AI 分析 → 网页审核 → 导出 FCPXML

**这个 skill 不直接剪视频**——它只到"标注 + 导出剪辑工程"为止，最终的剪辑动作由剪映 / FCP 完成。

## 目录结构

```
AI剪口播/
├── SKILL.md              ← 技能执行入口，AI 首先读取
├── ARCHITECTURE.md       ← 本文档，架构说明
├── scripts/
│   ├── templates/
│   │   └── review.html   ← 前端审核页面模板（静态）
│   ├── generate_review.js          ← 数据准备脚本（写 data.json + silence_periods.json）
│   ├── review_server.js            ← HTTP 服务器（静态服务 + /api/fcpxml）
│   ├── run_transcribe.sh           ← 步骤 1-4 自动化流水线
│   ├── volcengine_flash_transcribe.sh  ← 火山极速版（默认）
│   ├── volcengine_v3_transcribe.sh     ← 火山标准版（可选）
│   ├── volcengine_transcribe.sh        ← 火山 v1（可选 fallback）
│   ├── generate_subtitles.js       ← 火山结果 → 字级别字幕
│   ├── gen_analysis.js / auto_filler.js / gen_word_detail.js / merge_selections.js
│   ├── extract_text.js             ← 模式 B 用
│   └── 用户习惯/                   ← 口误规则（AI 分析时读取）
└── 用户习惯/                       ← 规则.md / 纠错prompt.md / 断行prompt.md
```

## 数据流

```
[视频.mp4]
    │
    ▼ run_transcribe.sh
    ├─ ffmpeg 提取音频 ────────────────→ audio.mp3
    │                                     │
    │  volcengine_flash_transcribe.sh     │
    │  → volcengine_v3_result.json       │
    │                                     │
    └─ generate_subtitles.js ─────────────→ subtitles_words.json
                                              │
                              ┌───────────────┴───────────────┐
                              ▼                               ▼
                       gen_analysis.js                  AI 判断口误
                              │                               │
                              ▼                               ▼
                       sentence_map.json              speech_errors.json
                       analysis.txt                          │
                              │                               ▼
                              └───────────► auto_filler.js + merge_selections.js
                                                             │
                                                             ▼
                                                      auto_selected.json
                                                             │
                                                             ▼
                                                    generate_review.js
                                                             │
                              ┌──────────────────────────────┼──────────────────────┐
                              ▼                              ▼                      ▼
                          data.json              review.html ← templates/          audio.mp3
                                                             │                  silence_periods.json
                                                             ▼
                                                    review_server.js
                                                             │
                              ┌──────────────────────────────┼──────────────────────┐
                              ▼                              ▼                      ▼
                          GET /video                  GET /review.html         POST /api/fcpxml
                          (原视频流)                  (审核界面)                       │
                                                                                     ▼
                                                                              <视频名>_cut.fcpxml
                                                                                     │
                                                                                     ▼
                                                                          拖入剪映 / Final Cut Pro
```

## 各模块职责

| 模块 | 职责 | 关键输入 | 输出 |
|------|------|----------|------|
| run_transcribe.sh | 步骤 1-4 自动化 | 视频.mp4 | audio.mp3, subtitles_words.json |
| volcengine_flash_transcribe.sh | 火山极速版 ASR（默认） | audio.mp3 (base64) | volcengine_v3_result.json |
| generate_subtitles.js | ASR 结果 → 字级字幕 | volcengine_v3_result.json | subtitles_words.json |
| gen_analysis.js | 切句 + 静音 | subtitles_words.json | analysis.txt, sentence_map.json |
| auto_filler.js | 词级口癖自动识别 | sentence_map.json | speech_errors.json（就地合并） |
| merge_selections.js | 句号 → idx 展开 | sentence_map.json, speech_errors.json | auto_selected.json |
| generate_review.js | 数据准备 + 静音检测 + 模板复制 | subtitles_words.json, auto_selected.json | data.json, review.html, audio.mp3, silence_periods.json |
| review_server.js | HTTP 服务器 | 视频文件 | 静态文件服务 + `/api/fcpxml` |
| review.html (模板) | 审核界面 | fetch data.json | 选中片段 → POST /api/fcpxml |

## 数据文件格式

### subtitles_words.json（核心数据）
```json
[
  {"text": "大", "start": 0.12, "end": 0.2, "isGap": false},
  {"text": "", "start": 6.78, "end": 7.48, "isGap": true}
]
```
- `isGap: true` 表示静音段
- `isGap: false` 表示文字（单字）
- 数组下标 = idx，贯穿 auto_selected / speech_errors / sentence_map

### auto_selected.json
```json
[72, 85, 120]
```
AI 预选的待删除字索引（对应 subtitles_words.json 的数组下标）

### silence_periods.json
```json
[{"start": 1.23, "end": 1.85}, ...]
```
generate_review.js 跑 `ffmpeg silencedetect` 自适应阈值（峰值 - 35dB）得到的静音段。`/api/fcpxml` 用它做 keep 段内部静音拆分。

## 服务器 API

| 端点 | 方法 | 参数 | 返回 |
|------|------|------|------|
| `/` | GET | — | review.html |
| `/video` | GET | — | 原始视频流（支持 Range 跳转） |
| `/audio.mp3` | GET | — | 音频流 |
| `/data.json` | GET | — | 审核数据 |
| `/api/fcpxml` | POST | `{start,end}[]` | `{success, output, segments}` |

## review.html 数据加载流程

1. 页面加载 → 显示加载状态
2. `fetch('./data.json')` 获取数据
3. 数据就绪后调用 `render()` 渲染字幕
4. 用户审核 → 点击「导出 FCPXML」→ `fetch('/api/fcpxml', {...})` → 生成 `<视频名>_cut.fcpxml`

## 扩展点

- **换前端样式**：直接修改 `scripts/templates/review.html`，改完重新运行 `generate_review.js`
- **换数据格式**：修改 `generate_review.js` 里写 `data.json` 的逻辑
- **换转录引擎**：在 `run_transcribe.sh` 加新 case，输出 `volcengine_v3_result.json` 同款结构即可

## 注意事项

- `review_server.js` **必须**在 `3_审核/` 目录内启动，否则 `silence_periods.json` 等相对路径文件读不到
- 视频文件通过 `/video` 路由代理，前端不需要知道真实路径
- FCPXML 里的视频引用用**绝对路径** + 百分号编码，剪辑软件靠这个定位源视频
