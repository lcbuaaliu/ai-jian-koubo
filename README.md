# AI剪口播

**口播视频，先想清楚哪里该删，再交给剪映剪。**

AI剪口播 是一个 [Claude Code](https://claude.com/claude-code) Skill：把口播视频自动**转录 → 识别口误 / 口癖 / 静音 → 网页波形审核 → 导出 FCPXML**，拖进**剪映**或 **Final Cut Pro** 完成最后一刀。

它不直接剪视频，只把「哪里该删」想清楚。审核网页让你在波形上一眼看清「真正会切到哪一帧」：红=删、黄=算法补切、灰=静音。

无云端、无账号、无第三方图床。音频 base64 直传火山引擎转录，剩下全在你本机跑。

---

## 用 Claude Code 安装

把这个仓库地址发给 Claude Code，说一句 **「装一下」**：

```
https://github.com/你的用户名/AI剪口播
```

它会读 README 一步步带你装好（约 1 分钟）。装完直接说「帮我剪这个口播视频 /path/to/video.mp4」即可开剪。

---

## 功能

- **自动转录** 火山引擎大模型 ASR，字级时间戳，中英混说也认得
- **AI 标口误** 重复重说、残句、句内卡顿、纯语气词整句，自动预选出来等你确认
- **波形审核网页** 自绘 canvas 波形，长视频也顺滑；删除段、算法补切、静音三色叠加，所见即所得
- **真所见即所得** 前后端共用同一份切割算法，预览到哪一帧，导出就是哪一帧，不漂移
- **导出 FCPXML** 一个文件同时被**剪映专业版**和 **Final Cut Pro** 识别，拖进去就还原时间线
- **自进化学习** 说一句「学一下」，它从你这次的真实剪辑里抽规则，沉淀成你的个人偏好
- **100% 本机** 你的视频和音频不经任何第三方存储，key 也只在本地
- **跨平台自检** 一条命令逐项告诉你缺什么、怎么补（Windows / macOS / Linux）

---

## 手动安装

**1. 放到 Claude 的 skills 目录**

把整个仓库**重命名为 `AI剪口播`**，放到 `~/.claude/skills/` 下，最终路径必须是：

```
~/.claude/skills/AI剪口播/
```

> ⚠️ 文件夹名必须是 `AI剪口播`（skill 触发词和脚本路径都依赖这个名字）。

**2. 配置火山引擎 API Key**

复制 `.env.example` 到 **skill 目录的上一级**（不是 skill 里面）：

```bash
cp ~/.claude/skills/AI剪口播/.env.example ~/.claude/skills/.env
# 编辑 ~/.claude/skills/.env，把 your_api_key_here 换成真 key
```

> ⚠️ `.env` 放在 `~/.claude/skills/.env`，所有引擎共用这一个文件。

去[火山引擎新版控制台](https://console.volcengine.com/speech/new/setting/apikeys)生成**一个** API Key，并开通两个资源（各有 **20h 免费额度**，独立抵扣）：**录音文件识别-极速版**(`auc_turbo`) + **标准版**(`auc`)。默认轮流用，吃满 ≈40h。只想用一个就在转录时加 `--flash` / `--v3-standard`。

**3. 一键自检**

```bash
node ~/.claude/skills/AI剪口播/scripts/doctor.js
```

逐项检查依赖、凭证、联网鉴权，缺什么就告诉你怎么补。全绿后记一个标记，之后不再打扰。

**4. 开剪**

在 Claude Code 里直接说：

```
帮我剪这个口播视频 /path/to/video.mp4
```

---

## 工作原理

```
你扔进一个口播视频
  -> 抽音频 -> 火山引擎转录成字级字幕
  -> AI 读全文，标出口误 / 口癖 / 残句，预选要删的片段
  -> 起一个本地审核网页，波形上三色标注真正会切到哪一帧
  -> 你勾选确认 -> 点「导出 FCPXML」
  -> 把生成的 *_cut.fcpxml 拖进剪映 / Final Cut Pro，完成最终剪辑
```

整条流水线由 [SKILL.md](SKILL.md) 驱动，全在你本机跑。音频走 base64 直传火山引擎转录，不经任何第三方图床。

---

## 依赖与技术栈

| 项 | 说明 |
|------|------|
| 运行环境 | `node` · `python3` · `ffmpeg` · `curl`（doctor.js 会按平台给安装命令） |
| 转录 | 火山引擎大模型录音文件识别（极速版 + 标准版） |
| 审核页 | 原生 canvas 自绘波形，无前端框架 |
| 切割算法 | 前后端共用一份 UMD 模块（`scripts/lib/compute_keeps.js`） |
| 导出格式 | FCPXML 1.8（剪映 / Final Cut Pro 通吃） |

---

## 隐私

`.env`（你的 key）已被 `.gitignore` 忽略，不会进仓库。音频默认走 base64 直传火山引擎，不经任何第三方图床。

---

## 文档

- [SKILL.md](SKILL.md) — 完整执行流程（唯一入口）
- [ARCHITECTURE.md](ARCHITECTURE.md) — 架构
- [AGENTS.md](AGENTS.md) — 设计原则 / 脚本规范
- [CHANGELOG.md](CHANGELOG.md) — 变更记录

---

## License

[MIT](LICENSE)

---

Built by 栗氪聊AI
