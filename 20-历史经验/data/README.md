# DSH 长期记忆框架

> **让任何 AI 或人，可以直接读写项目记忆，不必通读散文文档。**
>
> 建立：2026-10-06 · 维护：DSH

---

## 为什么需要它

**问题**：AI 的对话上下文会被压缩、会换新会话。每次都要用户重新解释项目历史 = 用户又在当传话筒。

**解法**：把项目的**事实 / 经验 / 事件 / 决策**固化成**机器可读**的追加式文件。

```
❌ 之前：只有 Markdown 文档 → AI 要通读全文 → 无法增量追加 → 无法查询
✅ 现在：JSONL 结构化   → AI 可直接解析 → 追加安全 → 支持搜索
```

---

## 文件结构

```
memory\
   ├─ facts.jsonl      事实库   —— 经过验证或标注为假设的判断
   ├─ lessons.jsonl    经验库   —— 踩过的坑、方法论、可复用技巧
   ├─ timeline.jsonl   时间线   —— 发生了什么（按时间追加）
   ├─ decisions.jsonl  决策库   —— 为什么选了 A 而不是 B
   ├─ index.json       索引     —— schema 定义 + 统计
   ├─ memory.ps1       工具     —— 查询 / 追加 / 生成简报
   ├─ CONTEXT.md       自动生成 —— 给 AI 的简报（每次 context 时重写）
   └─ README.md        本文件
```

### 为什么用 JSONL 而不是单个 JSON

| 特性 | JSONL | 单个 JSON | Markdown |
|---|---|---|---|
| **追加安全** | ✅ 直接加一行 | ❌ 要重写整个文件 | ✅ |
| **机器可解析** | ✅ | ✅ | ❌ |
| **grep 友好** | ✅ | 🟡 | ✅ |
| **并发安全** | ✅ | ❌ | 🟡 |

---

## 数据格式

### facts.jsonl

```json
{"id":"f001","ts":"2026-10-06T09:00:00+08:00","claim":"一句话陈述","status":"verified","evidence":"证据","source":"DSH","tags":["a","b"]}
```

**status 四态：**

| 值 | 含义 | 能否作为决策依据 |
|---|---|---|
| `verified` | ✅ 已实测，有证据 | ✅ 可以 |
| `hypothesis` | ⚠️ 合理推断，未验证 | ❌ **不可以** |
| `unverified` | ❓ 需要实测才知道 | ❌ 不可以 |
| `falsified` | ❌ 已证伪 | ❌ **不要再提** |

### lessons.jsonl

```json
{"id":"l001","ts":"...","title":"教训标题","kind":"pitfall|method|technique","context":"当时在做什么","mistake":"错在哪","solution":"怎么解决的","reusable":"可迁移的通用结论","tags":[]}
```

### timeline.jsonl

```json
{"id":"t001","ts":"...","event":"事件","detail":"细节","actor":"user|DSH|GPT|Codex|system"}
```

### decisions.jsonl

```json
{"id":"d001","ts":"...","question":"决策问题","chosen":"选了什么","rejected":["排除了什么"],"reason":"为什么","reversible":true}
```

---

## 使用方法

### 读取

```powershell
cd %USERPROFILE%\agents\bridge-client\memory

# 概览（默认）
.\memory.ps1

# ★ 生成给 AI 的简报（最重要的命令）
.\memory.ps1 context
#   → 打印完整简报，并写入 CONTEXT.md
#   → 可直接复制给任何 AI 作为项目背景

# 全文搜索（跨 4 个库）
.\memory.ps1 search 防火墙

# 分类查看
.\memory.ps1 facts              # 所有事实
.\memory.ps1 facts verified     # 只看已验证
.\memory.ps1 facts unverified   # 只看待验证
.\memory.ps1 lessons            # 所有经验
.\memory.ps1 timeline -Last 20  # 最近 20 条事件
.\memory.ps1 decisions          # 所有决策
```

### 写入

```powershell
# 追加事实
.\memory.ps1 add-fact -Claim "XXX 已验证可用" -Status verified -Evidence "日志显示 ..." -Tags "network,fix"

# 追加经验
.\memory.ps1 add-lesson -Title "XXX 的坑" -Kind pitfall -Context "当时在做..." -Mistake "错在..." -Solution "改成..." -Reusable "通用结论：..."

# 追加事件
.\memory.ps1 add-event -Event "完成 XXX" -Detail "细节..." -Actor DSH

# 追加决策
.\memory.ps1 add-decision -Question "选 A 还是 B" -Chosen "A" -Rejected "B" -Reason "因为..."
```

**⇒ 每次追加会自动更新 `index.json` 的统计。**

---

## 给 AI 的使用规范

**任何 AI 接手这个项目时：**

```
第 1 步  读 AGENTS.md   → 了解工作规范
第 2 步  读 STATE.md    → 了解当前状态
第 3 步  执行 .\memory.ps1 context  → 拿到结构化记忆简报
第 4 步  开始工作
```

**工作过程中：**

```
· 发现新事实     → .\memory.ps1 add-fact
· 踩到新坑       → .\memory.ps1 add-lesson
· 完成一件事     → .\memory.ps1 add-event
· 做了重要决策   → .\memory.ps1 add-decision
```

**⇒ 这就是"可传承、可更新、AI 可直接运用"的实现方式。**

---

## 设计原则

1. **只追加，不覆盖** —— 历史永远保留
2. **每条都带时间戳** —— 可追溯
3. **严格标注验证状态** —— 假设不得当依据
4. **人机双可读** —— JSONL 机器解析，字段名人类也看得懂
5. **工具极简** —— 一个 PowerShell 脚本，零依赖

---

## 与其他文件的关系

```
AGENTS.md     方法论      "我该怎么做事"
STATE.md      当前状态    "现在到哪了"（人类可读版）
LESSONS.md    经验教训    "别踩哪些坑"（人类可读版）
memory\       ★ 结构化记忆（机器可读 + 可查询 + 可追加）
   ↑
   └─ 前三个是"散文"，memory 是"数据库"。两者互补：
      · 人类/AI 初次了解 → 读散文
      · AI 程序化使用 → 读 memory
      · 新学到的东西 → 写 memory（同时可更新散文）
```
