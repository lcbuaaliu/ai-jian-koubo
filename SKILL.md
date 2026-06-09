---
name: AI剪口播
description: 口播视频转录和口误识别。生成审查稿和删除任务清单。触发词：剪口播、处理视频、识别口误
---

# 剪口播 

> 火山引擎转录 + AI 口误识别 + 网页审核 / 字幕格式化

## 模式

- **模式 A: 剪口播** — 转录 → 口误识别 → 网页审核 → 剪辑
- **模式 B: 转字幕** — 转录 → 格式化字幕文本（markdown，无时间戳）

## 输出目录结构

**模式 A（剪口播）：**
```
output/YYYY-MM-DD_HH-MM_视频名/剪口播/
├── 1_转录/   audio.mp3 · volcengine_v3_result.json · subtitles_words.json
├── 2_分析/   analysis.txt · sentence_map.json · speech_errors.json · auto_selected.json
└── 3_审核/   review.html · audio.mp3 · data.json · silence_periods.json
                <视频名>_cut.fcpxml   ← 网页点击「导出 FCPXML」后生成在此目录
                                       拖入剪映 / Final Cut Pro 完成最终剪辑
```

**模式 B（转字幕）：**
```
output/YYYY-MM-DD_HH-MM_视频名/剪口播/
├── 1_转录/   audio.mp3 · volcengine_result.json · subtitles_words.json · raw_text.txt
└── 2_纠错/   corrected.txt · uncertain.md（可选）
视频所在目录/
└── subtitles_formatted.md   ← 最终输出
```

## 流程总览

```
-1. 首次引导（仅第一次：环境自检 + 配置火山引擎）
0. 确认视频路径 + 选择模式
1-4. run_transcribe.sh（自动，两模式共用）

模式 A（剪口播）:
  5.1 gen_analysis.js
  5.2 读规则.md + analysis.txt
  5.3 AI 判断整句口误 → speech_errors.json（只填 delete_sentences）
  5.4 auto_filler.js → 自动补充词级口癖 idx（快速预筛）
  5.5 AI 逐句扫剩余词级口癖（B2/B3/B4，脚本覆盖不到的部分）
  5.6 merge_selections.js
  6-7. 生成审核网页 + 启动服务器
  【等待用户确认】→ 网页点击「导出 FCPXML」→ 拖入剪映 / Final Cut Pro 完成剪辑
       （导出同时写 3_审核/review_log.json，供步骤 8 学习）
  8. 自进化学习（用户显式触发「已导出，学一下」）→ diff 抽规则 → 确认 → 写 经验规则.md

模式 B（转字幕）:
  B-1 提取纯文本
  B-2 第一步：纠错（只改词，不断行）→ corrected.txt
  B-3 第二步：断行（只格式化，不改字）→ subtitles_formatted.md
```

## 执行步骤

### 步骤 -1: 首次引导（只在第一次跑）

> **目的**：第一次用本 Skill 的人通常没装依赖、没配火山引擎 key。先做一次自检并手把手引导，配好后写标记文件，**以后永久跳过，不再打扰**。

**闸门**：先看标记文件是否存在。
```bash
SKILL_DIR="$HOME/.claude/skills/AI剪口播"
[ -f "$SKILL_DIR/.setup_done" ] && echo "已配置，跳过引导" || echo "需要引导"
```
- 存在 `.setup_done` → **直接进入步骤 0**，不要跑自检、不要提引导。
- 不存在 → 跑自检脚本（跨平台，Win/macOS/Linux 通用）：

```bash
node "$SKILL_DIR/scripts/doctor.js"
```

`doctor.js` 做三层检查并输出人话报告：① 系统依赖（ffmpeg/node/python3/curl）② `~/.claude/skills/.env` 里的 `VOLCENGINE_API_KEY` ③ 联网实测 key 与极速版/标准版两个资源是否开通。**全绿时它自己写 `.setup_done` 并退出 0**；有缺项退出 1。

**AI 按报告分情况引导用户**（不要让用户自己看懂报告）：
1. **缺系统依赖** → 把报告里对应平台的安装命令复制给用户（脚本已按 Win/Mac 给好），让其装完。
2. **缺 / 占位 API Key** → 按以下流程引导用户（火山引擎·豆包语音服务，共 40h 免费额度）：
   1. 登录控制台 https://console.volcengine.com/speech/new/overview
   2. 左侧「语音识别」→ 开通「录音文件识别 1.0」，**标准版 + 极速版都开**（各 20h、共 ≈40h，独立抵扣）
   3. 左侧「API Key 管理」→ 复制 API Key
   4. 写入 `~/.claude/skills/.env`：
   ```bash
   echo "VOLCENGINE_API_KEY=粘贴你的key" >> "$HOME/.claude/skills/.env"
   ```
3. **某个资源未开通**（报告会精确指出是极速版还是标准版）→ 引导去控制台开通对应「录音文件识别 1.0」资源；默认 auto 轮流需两个都开（各 20h 免费、共 ≈40h），只想用一个就转录时加 `--flash` / `--v3-standard`。
4. 用户修完 → **重跑 `node "$SKILL_DIR/scripts/doctor.js"`**，直到全绿（自动写 `.setup_done`），再进入步骤 0。

> 全程不要替用户去控制台点按钮或粘贴他的私有 key 到别处；只给清晰可复制的命令和链接。

### 步骤 0: 确认视频路径 + 选择模式

收到视频路径后，**先展示确认**，格式：

```
📹 视频：/path/to/视频.mp4
📁 输出：~/Desktop/output/YYYY-MM-DD_HH-MM_视频名/剪口播/

请选择模式：
  [A] 剪口播 — 识别口误 → 网页审核 → 导出 FCPXML 给剪映 / FCP
  [B] 转字幕 — 转录 → 格式化字幕文本（markdown，无时间戳）
```

用户确认后再继续，不自动开始。

### 步骤 1-4: 一键转录流水线（无需 AI）

```bash
SKILL_DIR="$HOME/.claude/skills/AI剪口播"
VIDEO_PATH="/path/to/视频.mp4"
BASE_DIR="$HOME/Desktop/output/$(date +%Y-%m-%d_%H-%M)_$(basename "$VIDEO_PATH" | sed 's/\.[^.]*$//')/剪口播"

"$SKILL_DIR/scripts/run_transcribe.sh" "$VIDEO_PATH" "$BASE_DIR"
# 输出: BASE_DIR/1_转录/{audio.mp3, volcengine_v3_result.json, subtitles_words.json}
#
# 默认引擎: auto 轮流（flash 极速版 auc_turbo ↔ 标准版 auc 交替）
#   - 每次转录自动切换引擎，分摊两份各 20h 免费额度 ≈ 共 40h
#   - 单 X-Api-Key 认证，base64 直传，不依赖外部图床
#   - 需在控制台同时开通极速版(auc_turbo)与标准版(auc)两个资源
#   - 限制: 音频 ≤ 2h、≤ 100MB
# 可选引擎（只开了一个资源、或想固定用某个时加）:
#   --flash        只用极速版（一次直出、最快）
#   --v3-standard  只用标准版（异步轮询，实测可用）
#   --v1           旧版 ASR（会把音频上传到 uguu.se 公网图床，有隐私风险）
```

### 步骤 5: 生成分析文件 + 口误识别

#### 5.1 生成分析文件

```bash
node "$SKILL_DIR/scripts/gen_analysis.js" \
  "$BASE_DIR/1_转录/subtitles_words.json" \
  "$BASE_DIR/2_分析"
# 输出: analysis.txt + sentence_map.json + auto_selected.json
```

#### 5.2 读取规则 + 分析文件

读 `用户习惯/规则.md`、`用户习惯/经验规则.md`（自进化沉淀的个人偏好，见步骤 8）和 `analysis.txt`。
两份规则都要遵守；冲突时以更具体、更新的为准。

`analysis.txt` 格式（每行一句，序号: 文本）：
```
0: 直接开始了啊
1: 这是深圳腾讯总部楼下
2: 就为了安装一只
```

#### 5.3 AI 判断整句口误（只填 delete_sentences）

> ⚠️ 由你直接阅读 `analysis.txt` 并判断哪些**整句**是口误。
> **本步只填 `delete_sentences`**，`delete_idx` 留空数组。词级口癖留到 5.4（脚本）+ 5.5（AI 补漏）。

按 `规则.md` 的 **A 节（整句删除）** 判断：重复重说、残句、句内卡顿、只含语气词的整句等。

**输出格式**（写入 `$BASE_DIR/2_分析/speech_errors.json`）：
```json
{
  "delete_sentences": [2, 3, 8, 10],
  "delete_idx": []
}
```

#### 5.4 脚本自动识别词级口癖（无需 AI）

```bash
node "$SKILL_DIR/scripts/auto_filler.js" \
  "$BASE_DIR/2_分析/sentence_map.json" \
  "$BASE_DIR/1_转录/subtitles_words.json" \
  "$BASE_DIR/2_分析/speech_errors.json"
```

脚本会**就地修改** `speech_errors.json`，把识别到的口癖 idx 合并进 `delete_idx`：

- 任意位置：`呃 / 嗯 / 额 / 诶 / 欸 / 唉 / 噢`（已排除"额外/金额"等真词）
- 任意位置的：`然后`（用户偏好：宁可手动加回）
- 句首过渡词：`然后 / 那么 / 好的 / 啊 / 哦 / 哎 / 呀 / 对 / 呢 / 那`（"那"会避开"那个/那么/那里"等）
- 句尾废词：`对 / 呢 / 啊 / 哦`
- 跳过已整句删除的句子；保护剩余字数 ≤3-4 的短句不被掏空

跑完后，用户已手工填的 idx 也会被保留（合并去重）。

#### 5.5 AI 逐句扫剩余词级口癖（脚本覆盖不到的部分）

脚本只处理"无需上下文判断"的安全口癖。AI 在此扫 `analysis.txt`，找出脚本覆盖不到的：

- **B4 句中重说**（优先级最高）：前半段说错、后半段纠正 → 删前半段，保留后半段
- **B3 冗余引导短语**：大家可以看到、你看、给大家看一下、比如说你看一下、我可以告诉你、你明白吗
- **B2 句中填充词**（**慎用**，需明确判断为口癖才删）：其实、就、也、大概、这个、那个、就是
- **B5 脚本未覆盖的句尾拖音**

**工作方式（避免 token 爆炸 + 过删）：**
1. 顺序扫 `analysis.txt`，只标"明显有问题"的句子。没明显问题的句子直接跳过，不要为了"也许能再删一点"硬挑刺。
2. 把候选句号攒成一批（建议 20-30 句一组），**一次** `gen_word_detail.js` 调用拿到词级 idx。
3. 把新增 idx **合并**写回 `speech_errors.json` 的 `delete_idx`（与 5.4 结果取并集，不要覆盖）。

```bash
# 一次传多个句号，减少往返
node "$SKILL_DIR/scripts/gen_word_detail.js" \
  "$BASE_DIR/2_分析/sentence_map.json" \
  "$BASE_DIR/1_转录/subtitles_words.json" \
  5 8 12 24 25 44 ...
```

**判断尺度**：句子已经能读通就不要再动。剪口播的容错来自审核网页（用户能取消勾选），但**误删比漏删难恢复**——用户得手动取消勾选才能找回。所以**漏删优于过删**。

#### 5.6 合并到 auto_selected（代码自动映射句号→idx）

```bash
node "$SKILL_DIR/scripts/merge_selections.js" \
  "$BASE_DIR/2_分析/sentence_map.json" \
  "$BASE_DIR/2_分析/speech_errors.json" \
  "$BASE_DIR/2_分析/auto_selected.json"
```

### 步骤 6-7: 生成审核数据并启动服务器

```bash
# 6. 生成 data.json + review.html（从 templates/review.html 复制）
#    前端模板在 scripts/templates/review.html，改样式直接改那里
node "$SKILL_DIR/scripts/generate_review.js" \
  "$BASE_DIR/1_转录/subtitles_words.json" \
  "$BASE_DIR/2_分析/auto_selected.json" \
  "$BASE_DIR/1_转录/audio.mp3" \
  "$BASE_DIR/3_审核"

# 7. 启动服务器（自动避开已占用端口）+ 打开浏览器
#    ⚠️ 必须 cd 进 3_审核 再启动，否则静态文件路径错乱
READY_PORT=""
for PORT in 8899 8900 8901 8902; do
  # 占用检测：lsof 比 sleep+kill 可靠
  if lsof -nP -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then continue; fi
  ( cd "$BASE_DIR/3_审核" && node "$SKILL_DIR/scripts/review_server.js" $PORT "$VIDEO_PATH" ) >/tmp/review_server.log 2>&1 &
  # 轮询端口直到可用（最多 5 秒）
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.5
    if curl -fsS "http://localhost:$PORT/" -o /dev/null 2>&1; then
      READY_PORT=$PORT; break
    fi
  done
  [ -n "$READY_PORT" ] && break
done

if [ -n "$READY_PORT" ]; then
  echo "✅ 服务器: http://localhost:$READY_PORT"
  open -n "http://localhost:$READY_PORT"
else
  echo "❌ 服务器启动失败，查看 /tmp/review_server.log"
fi
```

用户在网页中：播放片段确认 → 勾选/取消 → 点击「导出 FCPXML」→ 生成的 `*_cut.fcpxml` 拖入剪映或 Final Cut Pro 完成最终剪辑。

> **导出时服务器同时写一份 `3_审核/review_log.json`**（与 FCPXML 同一次点击产出）：记录
> AI 初选 idx、用户最终 idx、切割参数，以及二者**词级 diff**（带文字+句子上下文）。
> 这是步骤 8「自进化学习」的唯一原料，**不读 `.fcpxml`**（那是算完的时间线，丢失了词级选择）。

### 步骤 8: 自进化学习（用户显式触发）

> **不自动跑。** 用户导出后，在**任意会话**说「<项目> 已导出，学一下」之类，才执行本步。
> 本步只读文件、不依赖对话上下文还在，所以冷会话也能跑。

1. **定位日志**：单个项目读 `<project>/剪口播/3_审核/review_log.json`；
   批量重学则 glob `~/Desktop/output/*/剪口播/3_审核/review_log.json`，逐个汇总。
   （日志只存在项目里，清理 output 会丢语料。）
2. **读现有规则**：先读 `用户习惯/经验规则.md` **全文** + `用户习惯/规则.md`，避免重复提已有规则。
3. **看 diff 抽规则**：对每条 `diff.aiOnly`（AI 想删你留回，可能过删）和 `diff.userOnly`
   （你删了 AI 没想到，可能漏删），对比「AI 为何这么剪 vs 你为何这么剪」，
   抽象出**能泛化到下一条视频**的通用偏好。**严禁**把单条口误/语境例外固化成规则。
4. **违例提醒**：若 diff 显示用户违反了某条已有规则，**逐条提醒**用户，让其判断
   是「正当例外（规则不动）」还是「该改松/加例外条件」。
5. **列给用户确认**：把候选的【新增 / 细化已有 / 合并重复 / 改某条】列出来，**等用户确认**。
6. **写入**：确认后才改 `用户习惯/经验规则.md`，每条带出处标签 `（学于 <视频名> YYYY-MM-DD；已确认）`。
   下次步骤 5.2 即生效。

### 模式 B: 转字幕

> 步骤 1-4 完成后，如果用户选了模式 B，执行以下步骤。
> **两步拆分**：先纠错，再断行。两步必须分开进行，不要混为一步。

#### B-1 提取纯文本（脚本执行）

```bash
node "$SKILL_DIR/scripts/extract_text.js" \
  "$BASE_DIR/1_转录/subtitles_words.json" \
  "$BASE_DIR/1_转录"
# 输出: $BASE_DIR/1_转录/raw_text.txt
```

#### B-2 第一步：纠错（AI 处理）

1. 读取 `$BASE_DIR/1_转录/raw_text.txt`
2. 读取 `$SKILL_DIR/用户习惯/纠错prompt.md` 规则
3. **只做纠错**，不断行、不去标点、不改格式
4. 输出到 `$BASE_DIR/2_纠错/corrected.txt`（每行一句，与输入 1:1 对应）
5. 如有「不确定清单」，输出到 `$BASE_DIR/2_纠错/uncertain.md` 并在对话中列出给用户

#### B-3 第二步：断行（AI 处理）

1. 读取 `$BASE_DIR/2_纠错/corrected.txt`
2. 读取 `$SKILL_DIR/用户习惯/断行prompt.md` 规则
3. **只做格式化**，不改字、不删字、不加字
4. 输出到**视频所在目录**：`$(dirname "$VIDEO_PATH")/subtitles_formatted.md`
5. 告知用户文件路径，流程结束

---

## 配置

火山引擎 API Key 存放在 `~/.claude/skills/.env`，字段 `VOLCENGINE_API_KEY`：
```
VOLCENGINE_API_KEY=your_api_key_here
```

去[新版控制台](https://console.volcengine.com/speech/new/setting/apikeys)生成 **一个** API Key 即可——所有引擎共用这同一个 `VOLCENGINE_API_KEY`（均为新版控制台单 `X-Api-Key` 认证）。

默认 `auto` 轮流模式会交替用极速版和标准版，**需同时开通两个资源**：「录音文件识别 - 极速版」（`volc.bigasr.auc_turbo`）+「录音文件识别 - 标准版」（`volc.bigasr.auc`）。两者各有 20h 免费额度、各自独立抵扣，轮流即可吃满 ≈40h。若只想/只开通了其中一个资源，加 `--flash` 或 `--v3-standard` 固定使用。

热词词典（可选，仅 `--v1` 引擎生效）：`scripts/词典.txt`，每行一个词。

