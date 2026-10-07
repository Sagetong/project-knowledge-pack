---
name: _template
title: Skill 模板 —— 复制这个目录来创建新 Skill
source: manual
created: 2026-10-06
tags:
  - template
---

# Skill 模板

> **复制整个 `_template` 目录，改名，然后编辑 `SKILL.md`。**
> 或者直接用 `harvest.ps1 -MakeSkill` 自动生成。

---

## 什么是 Skill

**Skill = 一段「遇到 X 情况就这么做」的可复用操作知识。**

```
经验 (Lesson)  = "我踩过这个坑，原因是……"        ← 记录型
Skill          = "遇到这个情况，按这 3 步做"      ← 行动型
```

**⇒ 经验是"知道"，Skill 是"会做"。**

---

## Skill 的最小结构

```
40-Skills\
   └─ <skill-name>\
        └─ SKILL.md      ← 必须叫这个名字
```

**目录名 = Skill 名，用小写字母 + 连字符（如 `fix-dsh-session-conflict`）。**

---

## SKILL.md 的字段

### YAML front matter（必需）

```yaml
---
name: skill-name            # 与目录名一致
title: 一句话说明这个 Skill 干什么
source: harvest | manual    # 来源
created: YYYY-MM-DD
tags:                       # 便于检索
  - 领域
  - 类型
---
```

### 正文（建议按这个顺序）

| 章节 | 内容 | 为什么重要 |
|---|---|---|
| **何时使用** | 什么症状/情况下该用这个 Skill | **AI 靠这个决定要不要调用** |
| **问题现象** | 具体的报错/表现 | 便于匹配 |
| **解决步骤** | **编号的、可直接执行的步骤** | 核心内容 |
| **为什么有效** | 原理 | 便于迁移到类似问题 |
| **可迁移的结论** | 抽象出的通用规律 | 最高价值 |

---

## 一个好的 Skill 长什么样

**❌ 差的写法：**
```
标题: 修复网络问题
步骤: 检查网络设置，看看哪里不对，改一下就好了
```
**问题**：没有具体症状、步骤不可执行、无法迁移。

**✅ 好的写法：**
```
标题: 修复 Windows 防火墙拦截导致的连接超时

何时使用: 局域网内某端口从其他设备访问时 ERR_CONNECTION_TIMED_OUT

问题现象: TCP 连接超时（不是拒绝），本机访问正常

解决步骤:
  1. 开启防火墙丢包日志:
     netsh advfirewall set allprofiles logging droppedconnections enable
  2. 重现问题，然后读日志:
     Get-Content "$env:SystemRoot\System32\LogFiles\Firewall\pfirewall.log" | Select-String "DROP"
  3. 确认是 DROP 且目标端口匹配后，加精确放行规则:
     New-NetFirewallRule -DisplayName "..." -Direction Inbound -Action Allow
       -Protocol TCP -LocalPort <端口> -RemoteAddress <网段> -Profile Any
  4. 立即在日志里确认出现 ALLOW

为什么有效: 显式 Block 规则优先级高于 Allow；日志能直接指出是哪条规则在拦

可迁移的结论: 网络/防火墙问题永远先开日志，不要靠推理猜测
```

---

## 如何被 AI 使用

**AI 读取本目录下的所有 `SKILL.md`，在遇到匹配的「何时使用」时执行「解决步骤」。**

**⇒ 所以「何时使用」写得越具体，Skill 被正确调用的概率越高。**

---

## 用 harvest.ps1 自动生成

```powershell
cd ..\..\30-工具
.\harvest.ps1 -Title "..." -Problem "..." -Solution "..." -Reusable "..." `
              -MakeSkill -SkillName "my-skill" `
              -SkillWhen "当出现 XXX 症状时" `
              -SkillSteps "1. ...`n2. ...`n3. ..."
```

**⇒ 会自动创建 `40-Skills\my-skill\SKILL.md`。**
