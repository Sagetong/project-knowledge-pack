# 给 AI 的说明书

> **你是接手这个项目的 AI。这份文件告诉你怎么用这个经验包。**
>
> **⚠️ 先读根目录的 [`AGENTS.md`](../AGENTS.md)（约 150 行）。**
> 那份是入口，写明了三档使用门槛与可直接复制的命令。本文件是**详细版**，
> 在你需要更多细节时再读。

---

# 第一步：先做一次自检（只在新 clone 后需要）

```powershell
powershell -ExecutionPolicy Bypass -File '<经验包路径>\30-工具\selfcheck.ps1'
```

它检查运行环境、目录结构、数据可解析性、读取与写入能力、索引与签名。
**全绿就说明可以直接用。**

---

# 第二步：按门槛用起来 —— 从最轻的开始，够用就停

**⚠️ 不要一上来就跑 `memory.ps1 context`。** 那是最后手段，约 36 KB / 1.5-1.9 万 token。

## 第 0 档 · 开始任务前先扫标题（几秒）

```powershell
Get-Content '<经验包路径>\20-历史经验\data\INDEX.md'
```

或：

```powershell
cd <经验包路径>\30-工具
.\memory.ps1 summary            # 最轻：只列各类条数
.\memory.ps1 lessons            # 全部经验标题
.\memory.ps1 timeline -Last 20  # 最近发生了什么
```

**⇒ 没有相关的就去做你原本的事，不要硬读。**

## 第 1 档 · 按关键词检索（怀疑有相关经验时）

```powershell
cd <经验包路径>\30-工具
.\memory.ps1 search <关键词>
```

它同时搜 facts / lessons / decisions / timeline，并打印命中的**原始行**（含 id 与证据）。

## 第 2 档 · 实在想不出来，才做深度检索

```powershell
cd <经验包路径>\30-工具
.\memory.ps1 context          # ⚠️ 全量简报，约 36 KB
.\memory.ps1 decisions        # 当初为什么这么定
.\memory.ps1 facts verified   # 只看已实测的事实
```

## 第 3 档 · 可选：想到了就写一条（不是义务）

**⇒ 这一档是【邀请】，不是义务。** 本库追求有价值，不是大。

两条参考标准（满足任一条才考虑写）：

```
① 解决问题花了很长时间（过程曲折、试错多次、绕了远路）
② 遇到的是以前没遇到、超出原有认知的情况（新现象、新机制、新取舍）
```

**两条都不满足就别写** —— 常规操作、例行修复写进来只是噪音，
反而让后来的人分不清哪些真正重要。


```powershell
cd <经验包路径>\30-工具
.\memory.ps1 add-lesson -Title "..." -Kind technique -Context "..." `
    -Mistake "..." -Solution "..." -Reusable "..." -Tags "a,b" -Namespace contributed
```

**⚠️ 必须指定 `-Namespace contributed`**（外部经验进隔离区）。
省略的话默认写 `local`（本机层），而 local 层**不对外分发** —— 你的经验就传不出去。

> **参数名以脚本实际接受的为准。** 用错会被 PowerShell **静默忽略** ——
> 命令看起来成功了，但字段是空的、或者数据写到了默认层。
>
> | 命令 | 参数 |
> |---|---|
> | `add-lesson` | `-Title -Kind -Context -Mistake -Solution -Reusable -Tags` |
> | `add-fact` | `-Claim -Status -Evidence -Tags` |
> | `add-decision` | `-Question -Chosen -Rejected -Reason`（**不是** `-Decision` / `-Rationale` / `-Alternatives`） |
> | `add-event` | `-Event -Detail -Actor` |
>
> 所有写入命令都支持 `-Namespace local|universal|contributed`（默认 `local`）。
> 不确定时跑 `.\memory.ps1`（不带参数）看用法，或读脚本头部的注释。

---

---

# 第二步：了解目录含义

```
00-底层逻辑\ARCHITECTURE.md   为什么这样设计（想理解原理时读）
10-说明书\AGENTS.md           工作规范（你的行为准则，必读）
10-说明书\FOR-AI.md           本文件
20-历史经验\STATE.md          当前状态（现在到哪）
20-历史经验\LESSONS.md        经验教训（别踩哪些坑）
20-历史经验\data\*.jsonl      ★ 机器可读的知识库
30-工具\memory.ps1            读取工具
30-工具\harvest.ps1           ★ 写入工具（固化经验 + 生成 Skill）
40-Skills\<name>\SKILL.md     ★ 可复用的操作知识
50-环境档案\                  环境特有的知识
```

---

# 第三步：开始工作时必须遵守的 6 条

## 1. 先只读，再动手

**任何操作前，先确认现实状态与 `STATE.md` 的描述是否一致。**
不一致时以现实为准，并更新 STATE.md。

## 2. 严格区分 ✅已实测 / ⚠️假设 / ❓未验证

**这是硬规则。** 说"我不确定"不丢人；把假设说成事实，会让整个项目建立在沙子上。

## 3. 改系统配置的四步规范

```
① 先记录原状态（快照文件）
② 最小范围改动
③ 改完立即验证
④ 写下回滚命令
```

## 4. 网络/防火墙问题：先开日志，不要推理

**我们在这上面浪费过两轮用户测试。** 详见 `LESSONS.md` 的 l001。

## 5. 不要猜 API/协议行为，去读源码

**详见 `LESSONS.md` 的 l002。**

## 6. 不要为"技术方案"努力，要为"目标"努力

**每当引入新组件时先问：这离目标更近了吗？**

---

# 第四步：学到新东西时，立刻固化

## 遇到并解决了一个非平凡问题

```powershell
cd <经验包>\30-工具

.\harvest.ps1 `
  -Title "一句话描述这个问题" `
  -Problem "具体现象是什么" `
  -Solution "怎么解决的" `
  -Reusable "可迁移的通用结论" `
  -Kind pitfall `
  -Tags "network,firewall"
```

## 如果这个经验可以变成"可执行的操作步骤"

**加 `-MakeSkill`：**

```powershell
.\harvest.ps1 `
  -Title "修复防火墙拦截导致的连接超时" `
  -Problem "局域网访问某端口时 ERR_CONNECTION_TIMED_OUT" `
  -Solution "开启防火墙日志定位 DROP，加精确放行规则" `
  -Reusable "网络问题永远先开日志，不要靠推理" `
  -Kind pitfall -Tags "network,firewall" `
  -MakeSkill -SkillName "fix-firewall-drop" `
  -SkillWhen "当出现 TCP 超时（不是拒绝）且本机访问正常时" `
  -SkillSteps "1. 开日志`n2. 重现并读 DROP`n3. 加放行规则`n4. 验证 ALLOW"
```

**⇒ 会自动生成 `40-Skills\fix-firewall-drop\SKILL.md`。**

## 批量固化（一次提交多条）

```powershell
.\harvest.ps1 -Json '[{"title":"...","problem":"...","solution":"...","reusable":"..."}]'
```

---

# 第五步：Skill 什么时候用

**你在工作中遇到问题时，先查 Skills：**

```powershell
Get-ChildItem <经验包>\40-Skills -Recurse -Filter SKILL.md |
  Select-String -Pattern "关键词" -List
```

**若某个 Skill 的「何时使用」匹配当前症状，直接执行它的「解决步骤」。**

---

# 完整的会话流程（建议照做）

```
【开局】
  1. .\memory.ps1 context              → 拿上下文
  2. 读 AGENTS.md                       → 看规范
  3. 只读检查现实状态                    → 确认与 STATE.md 一致

【工作中】
  4. 遇到问题 → 查 40-Skills 有没有现成的
  5. 没有 → 解决它
  6. 解决了 → harvest.ps1 固化（重要！）
  7. 做了重要决策 → memory.ps1 add-decision

【收尾】
  8. 更新 STATE.md 的当前状态
  9. 把新踩的坑写进 LESSONS.md（可选，harvest 已记入 data 层）
```

---

# 常见误区

| 误区 | 正确做法 |
|---|---|
| ❌ 通读所有文件才开始 | ✅ 先跑 `memory.ps1 context`，按需再深入 |
| ❌ 解决了问题就算了 | ✅ **必须 harvest** —— 否则下次还得重新踩 |
| ❌ 把推测写成事实 | ✅ 标注 status，不确定就写 unverified |
| ❌ 直接改系统配置 | ✅ 四步规范：快照→最小改动→验证→回滚命令 |
| ❌ 硬编码路径 | ✅ 用 `$PSScriptRoot` 相对定位 |
| ❌ 为了用某个工具而用 | ✅ 先问"这离目标更近了吗" |

---

# 如果这个包被复制到别的电脑

```
① 先读 50-环境档案\ —— 里面的路径/版本是原电脑的
② 逐项核对新环境是否一致
③ 不一致的，新建一份环境档案，不要改旧的
④ 更新 STATE.md 里的路径
```

---

# 一句话

> ## **开局 `memory.ps1 context`，收尾 `harvest.ps1`。**
> ## **前者让你知道过去，后者让未来知道你。**
