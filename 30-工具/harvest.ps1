#Requires -Version 5.1
<#
.SYNOPSIS
    Harvest —— AI 遇到困难并解决后，一键把经验固化 + 生成可复用 Skill

.DESCRIPTION
    这是经验包的"自动生长"机制。

    AI 在解决一个非平凡问题后，运行本脚本：
      ① 把这次的经验追加到 20-历史经验\data\lessons.jsonl
      ② 追加一条时间线事件
      ③ （可选）生成一个可复用的 Skill 到 40-Skills\<name>\SKILL.md
      ④ 更新 data\index.json

    下次任何 AI 遇到同类问题，可以直接查阅 lessons.jsonl 或调用 Skill。

.EXAMPLE
    # 最小用法：只记经验
    .\harvest.ps1 -Title "X 命令在 Y 情况下会失败" `
                  -Problem "执行 X 时报错 Z" `
                  -Solution "改用 W，因为 ..." `
                  -Reusable "遇到 Z 错误时，优先检查 ..."

.EXAMPLE
    # 完整用法：记经验 + 生成 Skill
    .\harvest.ps1 -Title "修复 DSH SDK session 冲突" `
                  -Problem "重启 bridge 后报 session already exists" `
                  -Solution "归档冲突的会话目录后重试" `
                  -Reusable "持久化 session + 无 resume 协议 = 必然冲突，用冲突自愈" `
                  -MakeSkill -SkillName "fix-dsh-session-conflict" `
                  -SkillWhen "当 bridge/SDK 报 session already exists 时" `
                  -SkillSteps "1. 定位会话目录`n2. 改名归档`n3. 重试"

.EXAMPLE
    # 从一条命令里批量导入（AI 可以在一次调用里提交多条）
    .\harvest.ps1 -Json '[{"title":"...","problem":"...","solution":"...","reusable":"..."}]'
#>
[CmdletBinding()]
param(
    [string]$Title,
    [string]$Problem,
    [string]$Solution,
    [string]$Reusable,
    [string]$Kind = 'pitfall',
    [string]$Tags = '',
    [string]$Actor = 'AI',

    # 生成 Skill
    [switch]$MakeSkill,
    [string]$SkillName,
    [string]$SkillWhen,
    [string]$SkillSteps,

    # 批量导入
    [string]$Json,

    # 命名空间：local | universal | contributed（默认 local）
    [ValidateSet('local','universal','contributed')]
    [string]$Namespace = 'local',

    # 干跑（不写文件，只显示会写什么）
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ---- 定位包根目录 ----
$ScriptDir = $PSScriptRoot
$PackRoot  = Split-Path $ScriptDir -Parent          # 30-工具 的上一级
if (-not (Test-Path (Join-Path $PackRoot '20-历史经验'))) {
    # 兼容：脚本被复制到别处时，尝试相对定位
    $PackRoot = $ScriptDir
}

$DataNs       = if ($Namespace) { $Namespace } else { 'local' }
$DataDir      = Join-Path $PackRoot ('20-历史经验\data\' + $DataNs)
if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
$LessonsFile  = Join-Path $DataDir 'lessons.jsonl'
$TimelineFile = Join-Path $DataDir 'timeline.jsonl'
$IndexFile    = Join-Path $DataDir 'index.json'
$SkillsDir    = Join-Path (Join-Path $PackRoot '40-Skills') $DataNs
if (-not (Test-Path $SkillsDir)) { New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null }

function Get-LineCount($path) {
    if (-not (Test-Path $path)) { return 0 }
    return @(Get-Content $path -Encoding UTF8 | Where-Object { $_.Trim() }).Count
}

function Next-Id($path, $prefix) {
    return ('{0}{1:d3}' -f $prefix, ((Get-LineCount $path) + 1))
}

function Append-Jsonl($path, $obj) {
    # PowerShell 把空数组 @() 序列化成 {}，会破坏 JSONL schema —— 强制修正为 []
    $json = $obj | ConvertTo-Json -Depth 8 -Compress
    $json = $json -replace ':\{\},"', ': [],"' -replace ':\{\}\}$', ': []}'
    if ($DryRun) { Write-Host ("  [DRY] " + $path + " ← " + $json) -ForegroundColor DarkGray; return }
    Add-Content -Path $path -Value $json -Encoding UTF8
}

function Update-Index {
    if ($DryRun) { return }
    if (-not (Test-Path $IndexFile)) { return }
    try {
        $idx = Get-Content $IndexFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $idx.updated = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
        foreach ($k in @('facts','lessons')) {
            $p = Join-Path $DataDir ($k + '.jsonl')
            if ($idx.stats.PSObject.Properties.Name -contains $k) { $idx.stats.$k = Get-LineCount $p }
        }
        foreach ($k in @('timeline','decisions')) {
            $p = Join-Path $DataDir ($k + '.jsonl')
            if ($idx.stats.PSObject.Properties.Name -contains $k) { $idx.stats.$k = Get-LineCount $p }
        }
        $idx | ConvertTo-Json -Depth 8 | Set-Content $IndexFile -Encoding UTF8
    } catch {
        Write-Host ("  ⚠ index.json 更新失败: " + $_.Exception.Message) -ForegroundColor Yellow
    }
}

function New-SkillFile($name, $title, $when, $steps, $problem, $solution, $reusable, $tags) {
    $skillDir = Join-Path $SkillsDir $name
    if (-not (Test-Path $skillDir)) { New-Item -ItemType Directory -Path $skillDir -Force | Out-Null }
    $skillFile = Join-Path $skillDir 'SKILL.md'

    $tagLine = if ($tags) { ($tags -split ',' | ForEach-Object { '  - ' + $_.Trim() }) -join "`n" } else { '  - (无)' }
    $body = @"
---
name: $name
title: $title
source: harvest
created: $(Get-Date -Format 'yyyy-MM-dd')
tags:
$tagLine
---

# $title

## 何时使用

$when

## 问题现象

$problem

## 解决步骤

$steps

## 为什么有效

$solution

## 可迁移的结论

$reusable

## 备注

- 本 Skill 由 ``harvest.ps1`` 自动生成
- 原始经验记录在 ``20-历史经验\data\lessons.jsonl``
- 如需修改，直接编辑本文件即可
"@
    if ($DryRun) {
        Write-Host ("  [DRY] 将生成 Skill: " + $skillFile) -ForegroundColor DarkGray
    } else {
        [IO.File]::WriteAllText($skillFile, $body, (New-Object Text.UTF8Encoding($false)))
    }
    return $skillFile
}

# ============================ 主流程 ============================

Write-Host ''
Write-Host '════════ Harvest · 经验固化 ════════' -ForegroundColor Cyan
Write-Host ''

# ---- 批量模式 ----
if ($Json) {
    $items = @()
    try { $items = $Json | ConvertFrom-Json } catch {
        Write-Host ('  ❌ -Json 解析失败: ' + $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
    $n = 0
    foreach ($it in @($items)) {
        $n++
        $lid = Next-Id $LessonsFile 'l'
        Append-Jsonl $LessonsFile ([ordered]@{
            id       = $lid
            ts       = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
            title    = $it.title
            kind     = $(if ($it.kind) { $it.kind } else { 'pitfall' })
            context  = $it.context
            mistake  = $it.problem
            solution = $it.solution
            reusable = $it.reusable
            tags     = $(if ($it.tags) { @($it.tags) } else { @() })
        })
        Write-Host ("  ✅ [" + $lid + "] " + $it.title) -ForegroundColor Green
    }
    Append-Jsonl $TimelineFile ([ordered]@{
        id     = Next-Id $TimelineFile 't'
        ts     = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
        event  = ("harvest 批量固化 " + $n + " 条经验")
        detail = ("actor=" + $Actor)
        actor  = $Actor
    })
    Update-Index
    Write-Host ''
    Write-Host ("  共固化 " + $n + " 条经验") -ForegroundColor Green
    Write-Host ''
    exit 0
}

# ---- 单条模式 ----
if (-not $Title) {
    Write-Host '  需要 -Title（或使用 -Json 批量模式）' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  用法示例：' -ForegroundColor Gray
    Write-Host '    .\harvest.ps1 -Title "..." -Problem "..." -Solution "..." -Reusable "..."'
    Write-Host '    .\harvest.ps1 ... -MakeSkill -SkillName "my-skill" -SkillWhen "..." -SkillSteps "..."'
    Write-Host ''
    exit 1
}

$lessonId = Next-Id $LessonsFile 'l'
Append-Jsonl $LessonsFile ([ordered]@{
    id       = $lessonId
    ts       = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
    title    = $Title
    kind     = $Kind
    context  = ''
    mistake  = $Problem
    solution = $Solution
    reusable = $Reusable
    tags     = $(if ($Tags) { @($Tags -split ',' | ForEach-Object { $_.Trim() }) } else { @() })
})
Write-Host ("  ✅ 已固化经验 [" + $lessonId + "] " + $Title) -ForegroundColor Green

Append-Jsonl $TimelineFile ([ordered]@{
    id     = Next-Id $TimelineFile 't'
    ts     = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
    event  = ("固化经验: " + $Title)
    detail = $(if ($Reusable) { $Reusable } else { '' })
    actor  = $Actor
})
if (-not $DryRun) { Write-Host '  ✅ 已记录时间线' -ForegroundColor Green }

if ($MakeSkill) {
    if (-not $SkillName) {
        $SkillName = ($Title -replace '[^\w\u4e00-\u9fa5]+', '-').Trim('-').ToLower()
        if ($SkillName.Length -gt 48) { $SkillName = $SkillName.Substring(0, 48) }
    }
    $sf = New-SkillFile -name $SkillName -title $Title `
        -when $(if ($SkillWhen) { $SkillWhen } else { '遇到同类问题时' }) `
        -steps $(if ($SkillSteps) { $SkillSteps } else { $Solution }) `
        -problem $Problem -solution $Solution -reusable $Reusable -tags $Tags
    Write-Host ("  ✅ 已生成 Skill: " + $sf) -ForegroundColor Green
    # 同步记入时间线
    Append-Jsonl $TimelineFile ([ordered]@{
        id     = Next-Id $TimelineFile 't'
        ts     = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
        event  = ("生成 Skill: " + $SkillName)
        detail = $Title
        actor  = $Actor
    })
}

Update-Index
if ($DryRun) {
    Write-Host '  [DRY] 未写入任何文件' -ForegroundColor DarkGray
} else {
    Write-Host '  ✅ 已更新 index.json' -ForegroundColor Green
}
Write-Host ''
Write-Host ('  经验库现有 ' + (Get-LineCount $LessonsFile) + ' 条') -ForegroundColor Cyan

# ---- 自动同步到桌面副本 ----
if (-not $DryRun) {
    $syncScript = Join-Path $ScriptDir 'sync-pack.ps1'
    if (Test-Path $syncScript) {
        try {
            $syncOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $syncScript -Quiet 2>&1 | Out-String
            $m = [regex]::Match($syncOut, '变化: 新增 (\d+) · 更新 (\d+) · 删除 (\d+)')
            if ($m.Success) {
                Write-Host ('  ✅ 已同步到桌面副本 (+' + $m.Groups[1].Value + ' ~' + $m.Groups[2].Value + ' -' + $m.Groups[3].Value + ')') -ForegroundColor Green
            } else {
                Write-Host '  ✅ 桌面副本已是最新' -ForegroundColor Green
            }
        } catch {
            Write-Host ('  ⚠ 同步失败: ' + $_.Exception.Message) -ForegroundColor Yellow
        }
    }
}
if (Test-Path $SkillsDir) {
    $sc = @(Get-ChildItem $SkillsDir -Directory | Where-Object { $_.Name -ne '_template' }).Count
    Write-Host ('  Skills 现有 ' + $sc + ' 个') -ForegroundColor Cyan
}
Write-Host ''
