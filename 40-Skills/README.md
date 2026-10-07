# Skills 索引

> **Skill = 一段「遇到 X 情况就这么做」的可复用操作知识。**
> 与 Lesson（"我踩过这个坑"）的区别：**Skill 是能直接执行的步骤。**

---

# 现有 Skills

| Skill | 何时使用 | 来源 |
|---|---|---|
| [harvest-experience](harvest-experience/SKILL.md) | 成功解决非平凡问题后，需要固化经验时 | harvest 自动生成 |

**（本表随 Skill 增加而手动更新，或直接用下面的命令列出）**

---

# 列出所有 Skills

```powershell
Get-ChildItem . -Directory | Where-Object { $_.Name -ne '_template' } | ForEach-Object {
    $f = Join-Path $_.FullName 'SKILL.md'
    if (Test-Path $f) {
        $title = (Get-Content $f -Encoding UTF8 | Select-String '^title:' | Select-Object -First 1)
        Write-Host ("  " + $_.Name.PadRight(40) + $title)
    }
}
```

---

# 按关键词查找 Skill

```powershell
Get-ChildItem . -Recurse -Filter SKILL.md |
  Select-String -Pattern "关键词" -List |
  ForEach-Object { Write-Host $_.Path }
```

---

# 新建 Skill

## 方式 A：自动生成（推荐）

```powershell
cd ..\30-工具
.\harvest.ps1 -Title "..." -Problem "..." -Solution "..." -Reusable "..." `
              -MakeSkill -SkillName "my-skill" `
              -SkillWhen "当出现 XXX 症状时" `
              -SkillSteps "1. ...`n2. ...`n3. ..."
```

## 方式 B：手动复制模板

```powershell
Copy-Item _template my-new-skill -Recurse
# 然后编辑 my-new-skill\SKILL.md
```

---

# Skill 格式

**必需文件**：`<skill-name>/SKILL.md`

**目录名**：小写字母 + 连字符，如 `fix-firewall-drop`

**YAML front matter**：
```yaml
---
name: skill-name
title: 一句话说明
source: harvest | manual
created: YYYY-MM-DD
tags: [领域, 类型]
---
```

**正文建议章节**（顺序重要）：
```
## 何时使用        ← AI 靠这个决定要不要调用，写得越具体越好
## 问题现象
## 解决步骤        ← 编号的、可直接执行的步骤
## 为什么有效
## 可迁移的结论    ← 抽象出的通用规律（最高价值）
```

**详细规范见** [`_template/SKILL.md`](_template/SKILL.md)

---

# 设计原则

| 原则 | 说明 |
|---|---|
| **「何时使用」必须具体** | 模糊的描述会导致 AI 匹配不上 |
| **步骤必须可执行** | 不要写"检查一下设置"，要写"执行 X 命令" |
| **必写「可迁移的结论」** | 这是 Skill 相对普通经验的增值部分 |
| **一个 Skill 只解决一类问题** | 太宽泛会难以匹配 |
| **带具体报错文本** | 便于后来者搜索匹配 |
