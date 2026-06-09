# Changelog

## 2026-06-09 — 首次使用引导（环境自检 + 配置向导，为开源准备）

新增首次使用的引导流程，让没装依赖、没配 key 的新用户能被手把手带上手；配好后永久跳过。

- 新增 `scripts/doctor.js`（**跨平台 Win/macOS/Linux**，用 Node 写因为 node 本就是依赖）：三层自检
  ① 系统依赖 ffmpeg/node/python3/curl（按平台给安装命令）
  ② `~/.claude/skills/.env` 的 `VOLCENGINE_API_KEY`（区分缺文件/缺字段/占位符）
  ③ **联网实测** key + 极速版/标准版两个资源——发极小假音频只看鉴权层状态码（`45000010`=key 无效、`45000151`=资源未开通），几乎不耗免费额度，能精确指出「key 有效但标准版没开通」这类首配痛点。
  全绿时自写 `.setup_done` 标记并退出 0；`--force` 可强制重测，`--json` 输出机器可解析结果。
- `SKILL.md` 新增「步骤 -1：首次引导」：见 `.setup_done` 即跳过；否则跑 doctor.js 并按报告分情况引导用户修复，全绿后再进步骤 0。
- 新增 `.env.example`（开源占位，含申请链接与两资源说明）、`README.md`（快速开始）。
- `.gitignore` 增加 `.setup_done`。

## 2026-06-09 — 标题图标对齐 + 松紧线变细加渐变

`scripts/templates/review.html`：

- 逐字稿标题栏 `align-items` 从 `baseline` 改 `center`，文字线小图标与标题对齐到同一水平线。
- 松紧楔形线再变细（10px→6px），配色改为**暖色热力渐变**：紧端红 `#E5402A` → 橙 `#FF6A3D` → 松端金 `#F6B23C`，
  紧=红更符合「绷紧/强烈」的直觉，且全程不经过紫/蓝，规避「不要紫蓝渐变」的设计约束。
## 2026-06-08 — 删逐字稿统计 + 松紧改为楔形力量线

`scripts/templates/review.html`：

- 删掉逐字稿标题栏右侧的 `36 段 · 1170 词` 统计（`head-right#transcriptMeta` 元素 + 填充它的 JS），信息冗余。
- 松紧示意从「轨道+跟随蓝点」改为**静态楔形线** `.tt-wedge`：左端（紧）粗、实蓝有力量感，
  向右端（松）渐细渐隐（`clip-path` 楔形 + 横向渐变）。不再随滑块移动，移除 `sync()` 里的 ttDot/ttCap 逻辑。
- 卡片「切割参数 / SNAP」改名「静音剪辑」（删 SNAP 装饰标签）；两个滑块「起始/结尾留白」改为「句头 / 句尾」，说明改口语化。
- 清理冗余信息：顶栏去掉「N 词」（留「N 处 AI 预选」）；删视频上的时间浮层 `.time-overlay`（元素+样式+JS）；
  底部状态栏去掉「切 N 段」；逐字稿标题的大号「01」换成文字线小图标（`.num` 内嵌 SVG，签蓝渐隐）。
## 2026-06-08 — 切割参数加「松紧示意线」，删掉自动处理说明框

让两个留白滑块更直观：它们本质是同一个维度——剪得紧还是松。`scripts/templates/review.html`：

- 删除 `.knob-auto`「导出时自动处理」说明框（切口对齐/去长卡顿那段）及其样式。
- 两个留白滑块**保留不变**，下方新增 `.tightness` 松紧示意线：左「紧」右「松」，带针脚刻度，
  蓝点位置 = 两段留白合计（0~16 帧）在紧↔松轴上的落点；`initKnobs` 的 `sync()` 实时更新蓝点
  `--p` 与说明文案（偏紧/适中/偏松）。松紧仅映射留白，不涉及段内长卡顿。无头 Chrome 截图验证。
## 2026-06-08 — 快捷键面板挪到逐字稿标题栏

把右侧栏底部独立的「快捷键」卡片移到逐字稿标题栏（`01 逐字稿 / Transcript`）右侧的空白区，
两行 kbd 提示压在标题与 `N 段 · N 词` 统计之间，右侧栏空出一块。纯布局改动，`scripts/templates/review.html`：
新增 `.head-shortcuts`（`margin-left:auto` 顶到右侧、`align-self:center`），`head-right` 去掉原 `margin-left:auto`，
删除 side-panel 里的 Help card。无头 Chrome 截图验证。

## 2026-06-08 — 新增 --auto 引擎轮流，吃满两份免费额度

flash（`auc_turbo`）与标准版（`auc`）在火山是两个独立计费资源，各有 20h 免费额度且各自优先抵扣。
要把两份都用上，只需把流量在两个引擎间分摊——不靠错误码检测（后付费下额度用完会静默扣费、不报错）。

- `scripts/run_transcribe.sh`：新增 `--auto`，用状态文件 `.engine_toggle` 在 flash / v3-standard 间
  逐次交替（5 行实现）。**并设为默认引擎**——正常剪视频即自动 50/50 分摊，两份 20h 同步见底 ≈ 共 40h 免费。
  想固定单引擎用 `--flash` / `--v3-standard`。
- `.gitignore`（新建）：忽略运行时 `.engine_toggle` 与 `.env`。
- `SKILL.md`：默认引擎说明改为 auto 轮流，并标注需同时开通极速版+标准版两个资源；v3-standard 从「慎用」改为「实测可用」。

## 2026-06-08 — 转录凭证统一为单一 API Key（为开源减负）

实测确认火山引擎标准版 `auc` 的 submit/query 同样接受新版控制台的单 `X-Api-Key`
（之前以为只有极速版 `auc_turbo` 支持），于是把 v3-standard 也切到单 key，三个引擎共用一个 key。

- `scripts/volcengine_v3_transcribe.sh`：认证头从 `X-Api-App-Key` + `X-Api-Access-Key` 双钥
  换成单 `X-Api-Key`，读取 `VOLCENGINE_API_KEY`（与 flash 共用）。base64 直传逻辑不变，端到端已验证。
- `~/.claude/skills/.env`：删除不再使用的 `VOLCENGINE_V3_APP_KEY` / `VOLCENGINE_V3_ACCESS_KEY` /
  `VOLCENGINE_V3_SECRET_KEY`（最后那个一直没被任何脚本引用），只保留 `VOLCENGINE_API_KEY` 一项。
- `SKILL.md`：配置说明改为「一个 key 通吃 flash + v3-standard」，并补充标准版需开通 `volc.bigasr.auc` 资源。
- 开源用户现在只需在控制台生成 1 个 API Key、填 1 个字段，不必再申请第二套双钥凭证。

## 2026-06-08 — 切割参数做减法（为开源）：撤掉两个抽象滑块，改静态说明

「吸附窗口」「内部静音切割」两个滑块对用户太抽象、几乎不需要调，为开源简化体验而撤掉。

- `scripts/templates/review.html`：移除 `knob-lookback` / `knob-internal` 两个滑块及其 `initKnobs` 读取；
  `lookBack 0.6` / `minInternalSilence 0.2` 改为 `cutOpts` 里的固定默认值。面板只保留
  「起始留白 / 结尾留白」两个能直观感受的滑块，下方新增 `.knob-auto` 静态说明块讲清机制：
  「切口对齐停顿」+「去掉长卡顿」（黄色段），让机制透明但不暴露为旋钮。
- 同步顺手删掉顶栏静态标题「审核稿」及其 `.file-name` 样式。
- `CLAUDE.md`：更新「三个可调阈值」描述为「两个滑块 + 两个固定默认」。

## 2026-06-08 — 划选工具条：恢复不弹窗 + 点别处即消失

- **恢复（remove）划选后不再弹工具条**：原来不论标删还是恢复，划选结束都弹「试听/撤销」条，
  但恢复操作不需要试听，纯属打扰。改为仅 `selectMode === 'add'`（标删）时才弹。
- **消失逻辑改为点击外部**：原来只有 4s 定时消失。改为捕获阶段监听 `document` 的 mousedown，
  点工具条以外任意位置即关闭（`toolbarEl.contains` 判定），并在 `hideToolbar` 里清理该监听；
  移除定时器。`toolbarTimer` → `toolbarDismiss`（清理函数）。

## 2026-06-08 — 切割参数：喘气余量拆成「起始留白 / 结尾留白」非对称

参考 Recut 的 Padding（Left/Right 可分离）。口播里句子开头常需要更多 lead-in（避免吞字、接得太赶），
结尾可以收紧，原来单一对称 `padFrames` 做不到。

- `scripts/lib/compute_keeps.js`：`computeFinalKeeps` 内把 `padFrames` 解析为 `padStart` / `padEnd`
  两个量——`trimmedStart`（含 tail 段）用 `padStart` 当 lead-in，`trimmedEnd` 与内部二次切的尾巴用 `padEnd`。
  未传 `padStart/padEnd` 时退回 `padFrames`，**向后兼容**旧请求体与默认值。
- `scripts/templates/review.html`：切割参数面板「喘气余量」单滑块换成**「起始留白」+「结尾留白」**两个滑块
  （各 0–8 帧），`initKnobs` 同步写入 `cutOpts.padStart/padEnd`，导出随 opts 一并发给 server。
  `cutOpts` 默认值改为 `padStart/padEnd: 2/30`。前后端单一来源不变，预览与产物一致。

## 2026-06-08 — 删掉视频上的 REC 徽标 + 重做品牌 logo

- 移除视频卡片左上角无用的 `REC · 1080P` 徽标（HTML + `.rec-chip` 样式 + 仅它使用的 `pulse` 动画）。
- 顶栏 logo 从「旋转奶油色文字图章」换成 **SVG 标志**：奶油色圆角方块内蓝色声波条 + 琥珀色切点标记
  （▼ + 竖线，切在声波中间），表达「剪 + 口播」；配 `--sans` 干净字标「剪<em>口播</em>」（口播取 signal-soft）。
  新增 `.brand-mark` / `.brand-word` 样式，无头 Chrome 截图验证。

## 2026-06-08 — 审核页交互重做：模型一「点=定位，划=删/恢复」

把原来「单击=跳转 / 双击=标删 / Shift+拖动=批量」这套手势冲突的交互，换成单一清晰的心智模型。
navigate 和 edit 彻底分到两个手势，消除「单击还是双击」的纠结。改动全在 `scripts/templates/review.html`。

- **手势统一为委托式**（不再逐元素绑 onclick/ondblclick/onmousedown）：
  - **单击词** = 定位播放头并播放；点到**红词**（已删）则试听这整段被删内容（`deletedRunAround` 取连续删除区间），
    否则正常播放——避免跳段逻辑把刚点的红词立刻跳过去。
  - **划过一串词** = 切换删除状态；方向由按下的第一个元素决定（已删→恢复 / 未删→删）。
  - **静音 chip 单击** = 直接切删除（保留的便利例外，配合静音阈值滑块批量处理）。
  - 用 `DRAG_THRESHOLD=4px` 区分「点」与「划」：没移动判定为单击，移动越过阈值才进入划选。
- **划选后浮动工具条**（`.sel-toolbar`）：`▶ 试听 <时长>` / `↺ 撤销`，跟随松手点定位、4s 自动消失。
- **「试听这段」预览模式**：`previewUntil` 让播放到段尾即停，且**期间不跳删除段**（否则红段会被直接跳过听不到）；
  `tick()` 顶部加预览分支，UI 更新抽成 `updatePlayheadUI()` 与正常播放共用。任何手动 seek（点词/波形/方向键/空格）
  经 `clearPreview()` 退出预览。
- **撤销栈**：`pushUndo()` 在每次编辑（划选开始、点静音、清空、静音阈值）前快照 `selected`，`Cmd/Ctrl+Z` 撤销。
- 底部帮助条与快捷键提示同步更新；移除死代码 `toggleItem`。
- 已同步到当前项目 `2026-05-29_18-55_C0122/.../3_审核/review.html`，无头 Chrome 截图验证渲染正常。

## 2026-06-08 — 修复播放预览「重放/卡顿」：跳段改用 computeFinalKeeps 同源切点 + seek 容差

排查用户反馈「把 AI 删的字加回来后，预览时这个字被播放 2 遍、很卡」。根因两条，都在 `review.html` 播放路径：

- **跳段数据源与导出/波形不一致**：`tick()` 用原始 `getDeleteSegments()`（生词边界）跳段，
  而波形和导出 FCPXML 都用 `ComputeKeeps.computeFinalKeeps()`（吸附静音 + 补帧 + 内部二次切）。
  预览听到的 ≠ 真正会剪掉的内容。
- **seek 欠冲导致重复跳转抖动**：seek 到段尾 `b` 时 HTML5 实际落点常比 `b` 早几毫秒，仍判定在删除段内；
  `seeked` 又每次把去重哨兵 `lastSeekTarget` 重置为 -1 → 反复 seek 到同一个 `b`。模拟显示当前逻辑
  1997 次 seek 死循环。**为什么偏偏「加回来的词」触发**：AI 原切点落在静音处，欠冲区安静听不出；
  把词加回来后新删除段末尾紧贴连续语音，欠冲区正是那个字的开头 → 反复重放。

修复（`scripts/templates/review.html`）：

- 新增 `getPlaybackCuts()`：播放跳段改用 `computeFinalKeeps` → `keepsToCuts` 的结果，与波形/导出**同源**，
  预览即所得。带 `playbackCutsDirty` 缓存，选段（`markSegsDirty`）和切割参数滑块变化时失效；时长未就绪时
  退回原始选段且不缓存。
- `tick()` 二分命中加 `SEEK_EPS = 0.03` 容差：落点在段尾 30ms 内即视为已出段，不再重复 seek。模拟显示
  修复后 1 次 seek、35 帧即稳定。
- 已把更新后的模板同步到当前项目 `2026-05-29_18-55_C0122/.../3_审核/review.html`，刷新即生效。

## 2026-06-04 — 自进化学习闭环：导出时落 review_log.json + 经验规则.md

新增「从你每次剪辑里学规则」的闭环。设计经 /grill-me 逐项敲定，核心：学习只靠词级 idx diff，不读 .fcpxml。

- **前端 review.html**：导出请求体新增 `finalSelected`（你最终选中的词级 idx 数组，从 `selected` Set 提取）。
- **review_server.js**：
  - 启动时读 `data.json` 拿 `words` + `autoSelected`（AI 初选）。
  - `/api/fcpxml` 导出时**同一次点击**多写一份 `3_审核/review_log.json`：自包含富日志
    （视频名、时间、opts、AI初选idx、你最终idx，及二者**词级 diff** `aiOnly`/`userOnly`，
    每条带 text + 句子上下文）。**只比对词，过滤静音段 isGap**（静音去留归 opts 管）。
    整段 try/catch，日志失败不影响导出。旧版前端不带 finalSelected 时跳过。
- **新建 `用户习惯/经验规则.md`**：机器学习产出、需人工确认；与手写 `规则.md` 分开维护。
- **SKILL.md**：5.2 改为同时读 `规则.md` + `经验规则.md`；新增**步骤 8 自进化学习**
  （用户显式触发「已导出，学一下」→ 读日志 diff → 抽象通用规则 → 违例逐条提醒 →
  列给用户确认 → 写入 `经验规则.md`，每条带出处）。流程总览同步加 step 8。
- 决策：学习信号=干净 idx diff；富日志只存项目 `3_审核/`（批量重学靠 glob output）；
  学到的只进 `经验规则.md` 纯文字，不动 auto_filler 词表/切割默认值；每次导出都可学，
  靠人工确认闸门防止把个例固化成过窄规则。

## 2026-05-31 — /simplify 清理：减少波形热路径浪费 + 切割几何归位单一来源

- 波形 `buildStatic`：删掉中间 `sm` Float32Array 和那趟平滑循环，3-tap 平滑改到描线时
  `hAt(x)` 现算 —— 每次重画少一次整长数组分配 + 一趟循环。
- `recompute()`（computeFinalKeeps+keepsToCuts+intervalSubtract）从「视口 key 变化」解耦，
  新增 `cutsDirty` 标志：只在选段/参数变化时重算，平移/缩放不再每帧重跑切割管线。
- `applyWaveTheme` 去掉多余的 `wave.markDirty()`，只 `redraw()`（暂停时原本会重画两次）。
- `subtract()` 区间相减搬到单一来源 `scripts/lib/compute_keeps.js` 导出 `intervalSubtract`，
  前端改调 `ComputeKeeps.intervalSubtract` —— 遵守 CLAUDE.md「切割/段落几何只此一份」。
- 抽出 `curWaveH()`，消除 dock resizer 里三处重复的 `--wave-h` 读取表达式。
- generate_review.js：`ffprobe` 取时长只探一次（原静音块/peaks 块各探一次），`audioDuration`
  提到外层共用；修正注释 4000Hz → 8000Hz。

### 已评估保留（非本次改动范围或会改变行为，跳过）
- WAVE_THEMES 硬编码色值与 `:root` 设计令牌部分重复：画布配色是波形专属、刻意独立，改成读
  CSS 变量反增复杂度，保留。
- `waveHMax()` 的魔法数(64/64/200)：当前可用，改成 CSS `min-height`/读 offsetHeight 有布局回归风险，保留。
- 三处拖拽手柄脚手架(侧栏/dock/画布平移)雷同：抽公共 helper 会牵动本次之外的旧代码，保留。

## 2026-05-31 — 切割参数加常驻说明 + 静音下拉加区别提示

- 三个滑块各加一行常驻 `.knob-hint` 灰字说明：吸附窗口 / 喘气余量 / 内部静音切割，
  用一句话讲清干什么、调大调小的影响。
- 顶部 `静音 ≥` 下拉的 `title` 改为解释性提示：它是「一键勾选稿子里的停顿为删除（红）」，
  并点明与切割参数「内部静音切割」（导出时切保留段内残留静音，黄）的区别。

## 2026-05-31 — 修复右侧栏卡片被压扁裁切

- 右栏（视频/切割参数/快捷键）是 flex 纵向布局，卡片默认 `flex-shrink:1`，上半区变矮时
  卡片被压缩，而 `.card{overflow:hidden}` 直接把内容裁掉——表现为「切割参数」第三个滑块
  「内部静音切割」整条消失、喘气余量滑块被切一半。
- 修复：`.side-panel > .card { flex-shrink: 0 }`，卡片保持自身高度，空间不够时由
  `.side-panel`（已有 `overflow-y:auto`）滚动，不再裁切内容。

## 2026-05-31 — 时间线状态栏移到波形上方

- `.tl-status`（图例 + 总时长/剪后/切N段 + 配色下拉 + 缩放控件）整条从波形下方移到
  dock 顶部，新顺序：拖拽手柄 → 状态栏 → 时间标尺 → 波形。
- `.tl-status` 间距 `padding-top:8px` → `padding:2px 0 8px`（改为与下方标尺留白）。

## 2026-05-31 — 波形渲染重做：填充包络 + 归一化增益 + 高密度峰值（贴近剪映/FCP）

### 问题
波形「像像素、不如剪映/FCP」三个原因：(1) 用逐像素 1px 硬竖条画，顶边锯齿尖刺；
(2) 峰值密度低（~30/s，封顶 12000），放大后每像素摊不到 1 个点 → 阶梯块；
(3) 振幅未归一化，安静录音（实测 fixture 峰值仅 0.023）画出来几乎是条平线。

### 渲染端（scripts/templates/review.html）
- 逐像素硬竖条 → **填充镜像包络**：逐像素求幅值（样本多取峰、样本少线性插值消阶梯）
  → 3-tap 轻平滑去单像素尖刺 → 描上沿+回描下沿填成平滑包络（canvas 抗锯齿）。
- 新增 `computeGain()`：全局峰值归一化到 ~0.92 半高，安静录音也填满面板（像剪映/FCP 自适应）。
  `init()` 里算一次，`hOf()` 应用 `min(1, v*gain)` 限幅。

### 数据端（scripts/generate_review.js）
- 峰值密度 ~60/s 封顶 12000 → **~150/s 封顶 60000**，SR 4000→8000。放大时有真实细节、不阶梯。
  60000 浮点 ≈ 300KB，长视频内存仍可控。
- 同步重生成 fixtures/sample/peaks.json（7415 点）与 C0122 项目 peaks.json（58355 点）。

## 2026-05-31 — 删除「删减预览」卡片 + 波形配色可切换

### 删减预览卡片移除（scripts/templates/review.html）
- 底部状态栏已显示 剪后时长 / 切 N 段，右侧栏「删减预览」三宫格统计重复，删掉。
- 一并删除 `updateStats()` 函数、5 处调用、`.stats-body/.stat/.stat-value/.stat-label` CSS。
  选段变化经 `markSegsDirty()` → wave 重绘 → `recompute()` 已实时更新底部状态栏，无功能损失。

### 波形配色主题（可实时切换）
- `COL` 由写死常量改为 `WAVE_THEMES` 主题表（cool 冷调蓝白 / mint 薄荷青 /
  recut 暖灰 / outline 石墨霓虹·描边），`let COL` 指向当前主题，wave 闭包读外层 COL。
- 时间线状态栏右下角加 `#themeSelect` 下拉，`applyWaveTheme()` 实时换色 +
  同步图例色块 + `wave.redraw()` 重建静态缓冲；选择存 `localStorage.reviewWaveTheme`。
- 全部主题统一把波形主体调亮提对比（原 `#4A4640` 暗棕灰发糊），语义色保持
  删除=红 / 额外切=黄橙；outline 主题用「淡填充 + 亮描边」让色块不糊住波形。

## 2026-05-31 — 波形高度可拖拽 + 随视口自适应

### 背景
波形高度被写死两处（CSS `#waveCanvas{height:132px}` + JS `cssH=132`），既不能调，
底部 dock 又是 `flex-shrink:0` 的固定高度。小显示器上固定 dock 把 stage 挤掉、内容显示不全；
大显示器才正常。

### 改动（scripts/templates/review.html）
- `#waveCanvas` 高度改为 `var(--wave-h, 132px)`；JS `layout()` 用 `cv.clientHeight` 取实际高度，
  不再用常量。ResizeObserver(cv) 接住高度变化自动重绘。
- dock 顶边加拖拽手柄 `.dock-resizer`（row-resize），上下拖调整波形高度。
- 高度持久化到 `localStorage.reviewWaveH`；落地时才写。
- `clampWaveH`：min 70px，max = `innerHeight − 顶栏 − dock固定占用 − 200(stage 最小)`。
  load 与 window.resize 都重新夹紧 —— 换显示器/缩放窗口时波形自动收进可视范围，
  保证 stage 不被挤没。

## 2026-05-31 — 审核页改版：Recut 风格全宽底部时间线

### 背景
波形原先挤在左侧 ~346px 宽的小卡片里（84px 高），长视频每像素 ≈1s，根本看不清，
不方便看波形和剪辑。参考 Recut 把时间线独占整个底边。

### 变更（仅 `templates/review.html`，后端零改动）
- 布局重构：`.main` → `.workspace`（上下两段）。上半区 `.stage`：**逐字稿移到左侧主编辑区**
  （flex 自适应），视频 + 切割参数 + 删减预览 + 快捷键收到右侧 `.side-panel`（固定 360px，可拖宽）。
- 新增**底部全宽时间线 dock**：波形 canvas 撑满整宽（84→132px），分辨率提升约 5×。
- 波形上方加**自适应时间标尺**（rulerCanvas，按 pxPerSec 在 1s~10min 间选刻度）。
- 时间线下方 **Recut 风格状态栏**：三色图例 + 总时长 / 剪后时长 / 切 N 段（由 `wave.recompute` 实时写入）。
- 缩放从 +/− 按钮升级为**缩放滑块**（对数映射 fit~400×，与滚轮缩放双向同步）+ 保留 −/+/⊡ 按钮。
- 播放头拉满时间线高度；其余交互（单击跳转 / 滚轮缩放 / 拖动平移 / 播放跟随）不变。
- 切割算法、三色带语义、`compute_keeps.js` 单一来源、`peaks.json` 加载全部不变。

## 2026-05-31 — 审核页波形可视化切割预览 + 切割算法单一来源 + 长视频性能

### 背景
导入 FCP 后发现有些帧把该保留的话切掉了。根因：前端用户操作的是「词级 idx」，
而 server 在 `/api/fcpxml` 里会对删除段做静音吸附（LOOK_BACK 0.6s）+ 保留段内部
长静音二次切割（MIN_INTERNAL_SILENCE 0.2s），这套转换全在导出那一刻盲发生，
前端看不到「真正切到哪一帧」。同时旧波形用 wavesurfer 直接 `url:'./audio.mp3'`，
长视频在浏览器端解码 + 主线程算 peaks 会卡顿甚至 OOM。

### 变更
- 新增 `scripts/lib/compute_keeps.js`：把切割算法（合并→取反→吸附→内部二次切）抽成
  纯函数 UMD 模块，**前后端单一来源**。`review_server.js` 改为 `require` 它；前端经
  `/lib/compute_keeps.js` 路由直接复用，彻底杜绝前后端预览漂移。
- `review_server.js`：删除内联切割逻辑与 `findNextSilenceEnd/findLastSilenceStart`；
  `/api/fcpxml` 改用 `computeFinalKeeps`，并兼容新请求体 `{ deleteList, opts }`（旧的纯数组仍可用）；
  新增 `/lib/compute_keeps.js` 静态路由（从 `scripts/lib` 直供，不拷贝）。
- `generate_review.js`：导出阶段预生成 `peaks.json`（ffmpeg 取 4000Hz 单声道 PCM 降采样到
  ≤12000 点的 0..1 包络）。前端用它渲染波形，跳过浏览器解码，长视频秒开。
- `templates/review.html`：
  - 移除 wavesurfer.js 依赖，改为**自绘 canvas 波形渲染器**（视口窗口化渲染，滚动/缩放顺滑）。
  - 波形叠加三色带：灰=静音段、红=用户选中删除、**黄=算法额外切掉的区间**（吸附+内部二次切的「误伤」），
    直接看见「该说的话被切掉」的高危区。
  - 交互：单击跳转、滚轮以光标为锚点缩放、拖动平移、播放时自动跟随。
  - 新增「切割参数」滑块卡片（吸附窗口 / 喘气余量帧 / 内部静音切割阈值），实时重算黄色预览，
    导出时把当前参数随 `opts` 发给 server，保证预览与产物一致。
- `fixtures/sample/` 增加 `peaks.json`；`dev.sh` 复制它（compute_keeps 经路由直供，无需拷贝）。

## 2026-05-28 — 收敛审核页前端为单一来源，删除 mock_demo

### 背景
审核页前端长期存在两份：生产模板 `scripts/templates/review.html` 与根目录 `mock_demo.html`。
后者是前者的复制副本 + 内联写死数据，每次只能手动同步真实数据，必然与模板漂移，
是「mock 页代码跟实际跑出来不一样」的根源。而 `scripts/dev.sh` + `fixtures/sample/`
（2026-05-19 引入）早已提供「单一模板 + 固化真实数据」的开发预览能力，足以完全替代 mock。

### 变更
- 删除 `mock_demo.html`（54KB 的 review.html 分叉副本）
- `.claude/launch.json`：移除 `mock-static`（python 静态服务器，仅用于打开 mock_demo），
  替换为 `dev-preview`（直接跑 `bash scripts/dev.sh 8899`，一键启动开发预览）
- `CLAUDE.md` 新增「本地开发预览」一节：明确审核页前端只有一份，开发统一走 `dev.sh`，禁止再造 mock 页
- `showcase.html`（对外介绍页）保留，与开发流程无关

## 2026-05-28 — 移除审核页「复制列表」按钮

### 变更
- 删除审核页 `review.html` 顶栏的「复制列表」按钮及其 `copyDeleteList()` 函数（用途与「导出 FCPXML」重叠，无实际使用价值）

## 2026-05-28 — mock_demo 改用真实转录数据

### 背景
`mock_demo.html` 的 `buildMockData()` 之前用写死的 gap 值 + `Math.random()` 生成单词时长，
导致页面上标红的静音时长、左侧时间码与音频/波形完全对不上（每次刷新还会变）。

### 变更
- 跑了一遍 `test_video/用来测试的视频.MP4` 的真实流水线（转录 + 自动口癖识别），
  把真实 `subtitles_words.json`（259 元素 / 241 词 / 99.58s）与 `auto_selected.json`（129 idx / 8 处）
  内联进 `mock_demo.html` 的 `REAL_WORDS` / `REAL_AUTO` 常量
- 顶部标题改为真实文件名；词数与「N 处 AI 预选」改由 JS 按真实数据动态计算填入（`#fileSub`）
- `.claude/launch.json` 增加 `mock-static` 静态服务器配置，便于预览 mock 页
- 波形仍为合成图形（mock 无真实振幅数据），未改动

## 2026-05-19 — 新增 dev 预览模式

### 背景
此前调审核页面的样式 / 交互，必须完整跑一遍转录 + 分析流水线才能看到效果。
增加 fixture + 一键脚本，开发时直接预览。

### 新增
- `scripts/fixtures/sample/`：固化一份真实样本数据（来自 C0121，~50s）
  - `data.json` · `audio.mp3` · `silence_periods.json` · `video.mp4`（裁到 51s，854px，1.8MB）
- `scripts/dev.sh`：拷贝 fixture + 最新 `templates/review.html` 到 tmp，启动 `review_server.js` 并开浏览器
  - 用法：`bash scripts/dev.sh [port]`
  - 改完模板重跑脚本即可看到最新效果
  - FCPXML 导出按钮保留，文件写入 tmp 工作目录

## 2026-05-18（晚）— 精简：去掉直接剪视频，只导出剪辑工程

### 背景
这个 skill 的核心定位调整为「**标注 + 导出剪辑工程**」，最终剪辑交给剪映 / Final Cut Pro。
直接 ffmpeg 剪辑视频的功能完全移除，砍掉大量复杂度。

### 删除
- `scripts/cut_video.sh` 整个文件（149 行）
- `scripts/review_server.js`：
  - `POST /api/cut` 路由（55 行）
  - `executeFFmpegCut()` + `executeFFmpegCutFallback()` 函数（130 行）
  - `detectEncoder()` / `getEncoder()` 硬件编码器探测（44 行，VideoToolbox / NVENC / QSV / AMF / VAAPI / x264）
  - 启动横幅里的"执行剪辑"操作说明
  - 总计 624 → 379 行
- `scripts/templates/review.html`：
  - 「执行剪辑」按钮 + `executeCut()` 函数（53 行）
  - `formatDuration()` 工具函数（仅 executeCut 使用，删除后成孤儿）
  - 总计 1312 → 1251 行

### 改名
- 审核网页 stats card 标题 "剪辑统计" → **"删减预览"**（不再有"剪辑产物"，所以叫"预览"更合适）

### 文档同步
- `SKILL.md` 输出目录结构去掉 `4_剪辑/`，新增 FCPXML 写入位置说明（`3_审核/` 目录内）
- `SKILL.md` 流程总览 / 模式选择文案 / 步骤 7 收尾说明都从"执行剪辑"改为"导出 FCPXML"
- `CLAUDE.md` 顶部「时间线导出格式」段落明确"本 skill 不直接剪视频"
- `ARCHITECTURE.md` 整体重写（系统概述 + 目录树 + 数据流图 + 模块表 + API 表 + 注意事项），所有 `/api/cut` 和 `*_cut.mp4` 引用清除
- `AGENTS.md` 用户使用场景 / 核心任务 / 情感诉求文案同步调整

### 验证
- `node -c review_server.js` 语法 OK
- 服务器仍能正常启动 + 提供静态文件
- `POST /api/fcpxml` 正常生成 fcpxml 文件（C0121 测试：17 个 segments）

## 2026-05-18

### 新增
- `scripts/volcengine_flash_transcribe.sh`：火山引擎大模型录音文件**极速版**（auc_turbo / flash 接口）
  - 一次请求直出，无需 submit/query 轮询
  - 单 `X-Api-Key` 认证（新版控制台），env 只需 `VOLCENGINE_API_KEY` 一个字段
  - base64 直传是官方文档化方案，不依赖外部图床
  - 限制：音频 ≤ 2h、≤ 100MB
  - 端到端测试：5.2MB 音频几秒出结果（对比标准版 ~45 秒轮询）

### 变更
- `scripts/run_transcribe.sh` **默认引擎改为 flash 极速版**
  - `--v3-standard` 切换到标准版（异步轮询，[volcengine_v3_transcribe.sh](scripts/volcengine_v3_transcribe.sh)，状态码读 header 的 bug 尚未修，慎用）
  - `--v1` 切换到旧版（必须上传到 uguu.se 公网图床，标记隐私警告，仅保留 fallback）
  - 启动时预检 ffmpeg / node / python3 / curl 依赖，缺失给安装提示
  - 校验视频文件存在性

### 修复
- 旧 `run_transcribe.sh` 顶部注释写"默认 v3"但代码 `ENGINE="v1"`，注释与代码不一致——新版彻底重写引擎选择逻辑

### 文档
- `SKILL.md` 步骤 1-4 引擎说明同步更新（默认 flash，标注 v3-standard / v1 为可选）
- `SKILL.md` 配置段新增新版控制台 API Key 申请链接，并标注热词词典仅 v1 生效

### 修复（flash 接入后发现的下游 bug）
- `scripts/generate_subtitles.js` 过滤火山 flash 返回的"分隔符词"
  - 现象：审核网页里 HTML 等英文词后面莫名出现 40+ 秒的假静音 chip，导致段落异常换行
  - 根因：flash 接口在中英文边界塞入 `text=' '` + `start_time/end_time=-1` 的分隔符词
    - generate_subtitles 把 -1ms / 1000 当成 -0.001 秒，污染了 `lastEnd`
    - 下一个真实词 start=40.58 → gap duration = 40.58 - (-0.001) ≈ 40.58 秒
  - 修复：提取阶段过滤 `start_time < 0` 或 `text` 为空白的词
  - 验证（C0121.MP4 测试）：字数 196 → 172（24 个分隔符过滤）、空白段 32 → 9、段落 32 → 9

### 说明
- **`volcengine_v3_transcribe.sh`（标准版异步）保留但不再是默认**
  - 已知 bug：状态码在 HTTP Header（X-Api-Status-Code）里，脚本却 grep body，导致轮询第 3 次误判"空结果"提前退出
  - 标准版 base64 是火山未文档化的灰色行为，生产不该依赖；改极速版是治本方案
- **`volcengine_transcribe.sh`（v1 旧版）保留**
  - 仅当极速版不可用时通过 `--v1` 走 fallback
  - 隐私警告：音频会被上传到匿名图床

## 2026-04-14

### 变更
- `scripts/gen_word_detail.js` 输出去掉时间戳，每行只保留 `[idx] 词`
  - 原因：AI 做局部删除判断只需要 idx + 词面，时间戳是纯噪声（后续剪辑从 words 文件读时间戳）
- `用户习惯/规则.md` 新增"重要前提：输入是语音转录"段落
  - 明确告知 AI：看到的是 ASR 转录，会有同音错词和专有名词识别错误（如 OPC点/卡巴西/Hans）
  - 不要纠正错字，也不要因为看到错字就把句子当口误删掉
  - 只判断口误本身（重复/残句/卡顿/口癖），不判断转录文字是否正确
- `用户习惯/规则.md` 重写，目标改为"剪出可直接发布的视频稿"
  - 整句删除规则合并整理：原 8 条 → 4 条（A1 重复/重说、A2 残句、A3 句内卡顿、A4 仅含语气词整句）
    - 合并原 1+2+6 为 A1（重说类统一处理）
    - 合并原 4+5 为 A3（卡顿即句内重复的特例）
    - 合并原 7+8 为 A4，并改判定：仅含语气词/口癖的整句**默认删**（原规则是"标记不自动删"）
  - 局部删除规则扩充：原 3 类 → 5 类
    - 新增 B1 句首过渡词（然后/那么/好/好吧/哦/对/呢/哎/那）
    - B2 句中填充词名单大幅扩充（加入 然后/对/呢/其实/就/也/大概/哦/呃）
    - 新增 B3 冗余引导短语（大家可以看到/你看/我可以告诉你 等）
    - 新增 B5 句尾废词（独立于句首废词，便于精确处理）
  - 新增 C 节"然后"判定细则：默认删，仅在真承接时序时保留

## 2026-04-13

### 新增
- `scripts/gen_word_detail.js` — 按需查看指定句子的词级 idx 详情，供 AI 做局部删除判断
- `规则.md` 新增"局部删除"规则：句中填充词、句中重说、句首/句尾废词三种场景
- `speech_errors.json` 格式扩展为 `{delete_sentences, delete_idx}`，支持整句+词级混合删除

### 变更
- `merge_selections.js` 兼容新旧格式：纯数组（旧）和对象格式（新）均可处理
- `SKILL.md` 步骤 5.3 加入词级分析流程：AI 遇到需局部删除的句子时，调 `gen_word_detail.js` 查词级 idx
- `CLAUDE.md` 架构决策记录新增"词级局部删除"条目

## 2026-04-10

### 新增
- 新建 `sbti-visualization_小红书版.html`：
  - 将原始 SBTI 可视化页改为更适合小红书截图传播的静态长图版
  - 文案整体改成大白话表达，减少术语和“说明书”口吻
  - 去掉筛选、展开等交互依赖，所有内容改为平铺展示
  - 逻辑说明压缩为更易懂的 4 步，并保留 5 大模型与 27 种人格清单

## 2026-04-03

### 改进
- 静音检测阈值改为自适应：用 `volumedetect` 取音频**峰值**音量，阈值 = 峰值 - 35dB，clamp 在 [-55dB, -20dB] 之间
  - 用峰值而非均值作基准，原因：均值包含静音段会被拉低，停顿越多均值越低、阈值越激进，逻辑反向；峰值只代表说话最响处，不受停顿比例影响，更稳定
  - `generate_review.js`：改用 `max_volume` 匹配，常量重命名为 `SILENCE_PEAK_OFFSET_DB = 35`
  - `review_server.js`：修复 `findNextSilenceEnd` bug——原来每次都覆盖 `best` 导致取的是窗口内最后一个静音终点，改为取最近的（最小的 end）；更新过期注释

## 2026-03-26 (2)

### 改进
- v3 转录引擎：改用 base64 直传音频，彻底移除对 uguu.se 的依赖
  - `volcengine_v3_transcribe.sh`：第一参数支持本地文件路径（base64 模式）或 HTTP URL（兼容旧用法）；用 Python 生成请求体写入临时文件，通过 `--data-binary @file` 传给 curl，避免 shell 变量大小限制；请求结束后自动清理临时文件
  - `run_transcribe.sh`：v3 引擎直接传 `audio.mp3` 本地路径，跳过 uguu.se 上传；v1 引擎保持原有逻辑不变

## 2026-03-26

### 改进
- FCPXML 导出：开头静音也保留 1 帧（1/30s）喘气余量，与末尾行为对称
- FCPXML 导出：内部静音拆分阈值从 0.3s 降为 0.2s，减少火山未识别的换气声残留
- FCPXML 导出：保留片段末尾自动裁剪到静音边界，消除片段尾部多余静音
  - `generate_review.js`：对 `audio.mp3` 跑 `silencedetect`（-35dB，持续 ≥ 0.2s），结果写入 `silence_periods.json`；末尾未闭合的静音段用 `ffprobe` 取音频时长兜底（修复 `null` end 时间导致的比较错误）
  - `review_server.js`：启动时读取 `silence_periods.json`；`/api/fcpxml` 计算 keep 片段时，向前 0.6s 内找最近静音起点并裁剪 `end`，末尾保留 1 帧（1/30s）喘气余量
  - FCPXML 导出：keep 片段内部的长静音（≥ 0.3s）自动拆分为多个子片段，切除说话间隙中火山未识别的换气声
  - 降级安全：`silence_periods.json` 缺失或 silencedetect 失败时，行为退化为原逻辑，不报错
- 代码质量（`/simplify` 审查修复）
  - `generate_review.js` / `gen_analysis.js`：删除 `mkdirSync({ recursive: true })` 前冗余的 `existsSync` 检查（TOCTOU 反模式）
  - `gen_analysis.js`：将两次遍历（forEach + reduce）合并为单次遍历，同时收集 `sentences` 和 `silenceIdx`
  - `review_server.js`：`findLastSilenceStart` 提升至模块级（原在请求处理函数内，每次请求重建）；`silencePeriods` 改为直接 try-catch 读取（去除 existsSync + readFileSync 的 TOCTOU）；加载后排序保证升序
  - `generate_subtitles.js`：空白标记阈值 `> 0.2` 改为 `>= 0.2`，与 `gen_analysis.js` 保持一致

## 2026-03-25

### 新增
- 「转字幕」模式（模式 B）：转录后按 `字幕prompt.md` 规则格式化文本，输出 `subtitles_formatted.md` 到视频所在目录
- `scripts/extract_text.js` — 从 `subtitles_words.json` 提取纯文本，输出 `raw_text.txt`（按 gap 分句，每句一行）
- `用户习惯/字幕prompt.md` — 字幕格式化规则（纠错、≤25字断行、去标点、分段）
- `SKILL.md` 步骤 0 增加模式选择（A: 剪口播 / B: 转字幕）

## 2026-03-24 (2)

### 变更
- `scripts/run_transcribe.sh` 默认引擎切换为 v3；加 `--v1` 参数可切回旧版（两套脚本均保留）
- `scripts/volcengine_v3_transcribe.sh` 修复 query 接口错误使用 GET 导致永远轮询的 bug，改为 POST

## 2026-03-24

### 新增
- `scripts/volcengine_v3_transcribe.sh` — 火山引擎 v3 大模型语音识别脚本，与 v1 并存；使用新认证头（`X-Api-App-Key` + `X-Api-Access-Key`），自生成 UUID 作为 request ID，轮询状态码 `20000000`，输出 `volcengine_v3_result.json`
- `.env` 新增 `VOLCENGINE_V3_APP_KEY` / `VOLCENGINE_V3_ACCESS_KEY` 占位变量（需在控制台单独申请）

### 变更
- `scripts/generate_subtitles.js` 兼容 v1（顶层 `utterances`）和 v3（`result.utterances`）两种响应格式，自动检测；未找到 utterances 时输出诊断信息

## 2026-03-23（三）

### 变更
- `gen_analysis.js` analysis.txt 格式从 `句N|idx X-Y|文本` 简化为 `序号: 文本`，AI 只看纯文本
- `gen_analysis.js` 新增 `sentence_map.json` 输出，存储句号→idx 范围映射
- `规则.md` 去掉所有 idx 相关说明，AI 输出改为句号数组 `[2, 3]`
- `SKILL.md` 步骤5 更新：AI 输出句号 → `merge_selections.js` 做映射合并

### 新增
- `scripts/merge_selections.js` — 句号→idx 映射 + 合并到 auto_selected.json

## 2026-03-23（二）

### 变更
- `generate_subtitles.js` Gap 插入阈值 0.3s → 0.2s
- `generate_subtitles.js` 删除 >0.5s 按 1s 拆分静音段的逻辑，静音全段保持原样
- `gen_analysis.js` 分句边界阈值 0.5s → 0.2s
- `gen_analysis.js` auto_selected 收集阈值 0.5s → 0.2s
- `review_server.js` MIN_KEEP_DUR 从帧数（5帧）改为固定秒数（0.1s）
- `review.html` 静音阈值筛选器默认值 0.5s → 0.2s，选项范围同步调整

## 2026-03-23

### 删除
- `detect_audio_profile.js` 及全部分贝阈值逻辑 — 跑 4 次 ffmpeg 但数据未被使用，删除节省约 1.5s 启动时间
- `analysis.txt` 中的 `[静Xs]` 字段 — 对口误识别无帮助，信息冗余
- `analysis.txt` 中的词级参考块（`idx[N] 词 词 词`）— 整句删除不需要，句内中文删除可从句首 idx 推算，极少数含英文场景不足以保留

### 变更
- `规则.md` 改为 markdown 换行格式，去掉表格，改善可读性
- `规则.md` 补充多次重复规则（3句以上连续相同开头），从注意事项升格为正式规则
- `规则.md` 前置"分析流程"说明（先分句 → 逐条检测 → 输出 idx）
- AI 分析流程：AI 只输出 `speech_errors.json`，合并操作改由脚本执行（含去重）

## 2026-03-25

### 转录引擎切回 v1 为默认
- `run_transcribe.sh` 默认引擎从 v3 改回 v1（稳定可靠，直接支持 uguu.se URL）
- v3 大模型引擎改为 `--v3` 参数可选启用（需配置火山引擎 TOS 对象存储）
- 原因：v3 API 只支持 URL 方式，且无法访问第三方存储（uguu.se/catbox.moe），官方推荐方案为 TOS，但需额外付费配置
- 同步更新 SKILL.md 文档说明
