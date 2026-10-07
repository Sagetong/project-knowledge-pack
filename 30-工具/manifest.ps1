#Requires -Version 5.1
<#
.SYNOPSIS
    Manifest —— 生成经验包清单（含文件哈希，便于校验完整性）

.DESCRIPTION
    扫描整个经验包，生成 MANIFEST.json，包含：
      · 包版本与生成时间
      · 每个文件的路径、大小、SHA256
      · 各数据文件的记录数
      · 总览统计

    用途：
      · 复制到别的电脑后，可对比哈希确认文件完整
      · 快速了解包里有什么

.EXAMPLE
    .\manifest.ps1                # 生成并写入 MANIFEST.json
    .\manifest.ps1 -Verify        # 校验现有 MANIFEST.json 与文件是否一致
    .\manifest.ps1 -NoHash        # 不计算哈希（更快）
#>
[CmdletBinding()]
param(
    [switch]$Verify,
    [switch]$NoHash
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$PackRoot  = Split-Path $ScriptDir -Parent
if (-not (Test-Path (Join-Path $PackRoot '20-历史经验'))) { $PackRoot = $ScriptDir }

$ManifestFile = Join-Path $PackRoot 'MANIFEST.json'
$DataDir = Join-Path $PackRoot '20-历史经验\data'

function Get-Sha256($path) {
    try { return (Get-FileHash -Path $path -Algorithm SHA256).Hash } catch { return $null }
}

function Get-LineCount($path) {
    if (-not (Test-Path $path)) { return 0 }
    return @(Get-Content $path -Encoding UTF8 | Where-Object { $_.Trim() }).Count
}

function Scan-Files {
    $files = @()
    foreach ($f in (Get-ChildItem $PackRoot -Recurse -File | Sort-Object FullName)) {
        # 跳过清单自己，避免递归
        if ($f.Name -eq 'MANIFEST.json') { continue }
        $rel = $f.FullName.Substring($PackRoot.Length).TrimStart('\')
        $entry = [ordered]@{
            path   = $rel
            bytes  = $f.Length
            mtime  = $f.LastWriteTime.ToString('yyyy-MM-ddTHH:mm:ss')
        }
        if (-not $NoHash) { $entry.sha256 = Get-Sha256 $f.FullName }
        $files += [pscustomobject]$entry
    }
    return $files
}

# ============================ 主流程 ============================

Write-Host ''
Write-Host '════════ Manifest · 经验包清单 ════════' -ForegroundColor Cyan
Write-Host ''
Write-Host ('  包根目录: ' + $PackRoot) -ForegroundColor Gray
Write-Host ''

# ---- 模式 1：校验 ----
if ($Verify) {
    if (-not (Test-Path $ManifestFile)) {
        Write-Host '  ❌ MANIFEST.json 不存在，先运行不带 -Verify 的命令生成' -ForegroundColor Red
        exit 1
    }
    $old = Get-Content $ManifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $new = Scan-Files

    $oldMap = @{}
    foreach ($f in $old.files) { $oldMap[$f.path] = $f }
    $newMap = @{}
    foreach ($f in $new) { $newMap[$f.path] = $f }

    $ok = 0; $changed = 0; $missing = 0; $added = 0
    foreach ($k in $oldMap.Keys) {
        if (-not $newMap.ContainsKey($k)) {
            Write-Host ('  ❌ 缺失: ' + $k) -ForegroundColor Red
            $missing++
        } elseif (-not $NoHash -and $oldMap[$k].sha256 -ne $newMap[$k].sha256) {
            Write-Host ('  ⚠ 已修改: ' + $k) -ForegroundColor Yellow
            $changed++
        } else {
            $ok++
        }
    }
    foreach ($k in $newMap.Keys) {
        if (-not $oldMap.ContainsKey($k)) {
            Write-Host ('  ➕ 新增: ' + $k) -ForegroundColor Green
            $added++
        }
    }
    Write-Host ''
    Write-Host ('  未变 ' + $ok + ' · 修改 ' + $changed + ' · 缺失 ' + $missing + ' · 新增 ' + $added) -ForegroundColor Cyan
    Write-Host ''
    if ($missing -gt 0) { exit 2 }
    exit 0
}

# ---- 模式 2：生成 ----
$files = Scan-Files
Write-Host ('  扫描到 ' + $files.Count + ' 个文件') -ForegroundColor Green

# 数据统计
$stats = [ordered]@{}
$nsStats = [ordered]@{}
foreach ($ns in @('local','universal','contributed')) {
    $nsDir = Join-Path $DataDir $ns
    $nsTotal = 0
    foreach ($name in @('facts','lessons','timeline','decisions')) {
        $n = Get-LineCount (Join-Path $nsDir ($name + '.jsonl'))
        if (-not $stats.Contains($name)) { $stats[$name] = 0 }
        $stats[$name] += $n
        $nsTotal += $n
    }
    $nsStats[$ns] = $nsTotal
}
$skillCount = 0
$skillsDir = Join-Path $PackRoot '40-Skills'
if (Test-Path $skillsDir) {
    $skillCount = @(Get-ChildItem $skillsDir -Recurse -Filter 'SKILL.md' -File |
        Where-Object { $_.FullName -notmatch '\\_template\\' }).Count
}

$manifest = [ordered]@{
    pack        = 'experience-pack'
    version     = '1.0.0'
    generated   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
    # 2026-10-07 修正：原来写的是绝对路径 $PackRoot。
    # 两个问题：① 会把作者的本机路径写进对外发布的清单；
    #           ② 绝对路径本身就让清单失去可移植性（换台机器就对不上）。
    # 改为只记录相对位置，任何地方复制过去都成立。
    packRoot    = '.'
    summary     = [ordered]@{
        files      = $files.Count
        totalBytes = ($files | Measure-Object -Property bytes -Sum).Sum
        records    = $stats
        byNamespace= $nsStats
        skills     = $skillCount
    }
    layout      = [ordered]@{
        '00-底层逻辑' = '为什么这样设计（架构原理）'
        '10-说明书'   = '怎么用（AI/人类使用指南 + 工作规范）'
        '20-历史经验' = '发生过什么（状态 + 教训 + 机器可读数据）'
        '30-工具'     = '怎么操作它（memory.ps1 读 / harvest.ps1 写）'
        '40-Skills'   = '会做什么（可复用的操作知识）'
        '50-环境档案' = '跑在什么环境上'
    }
    commands    = [ordered]@{
        read  = '.\30-工具\memory.ps1 context'
        write = '.\30-工具\harvest.ps1 -Title "..." -Problem "..." -Solution "..." -Reusable "..."'
        verify= '.\30-工具\manifest.ps1 -Verify'
    }
    files       = $files
}

$json = $manifest | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($ManifestFile, $json, (New-Object Text.UTF8Encoding($false)))

Write-Host ('  ✅ 已写入: ' + $ManifestFile) -ForegroundColor Green
Write-Host ''
Write-Host '  内容概览：' -ForegroundColor Cyan
Write-Host ('    文件数     ' + $files.Count)
Write-Host ('    总大小     ' + [math]::Round(($files | Measure-Object -Property bytes -Sum).Sum / 1KB, 1) + ' KB')
Write-Host ('    事实库     ' + $stats.facts + ' 条')
Write-Host ('    经验库     ' + $stats.lessons + ' 条')
Write-Host ('    时间线     ' + $stats.timeline + ' 条')
Write-Host ('    决策库     ' + $stats.decisions + ' 条')
Write-Host ('    Skills     ' + $skillCount + ' 个')
Write-Host ''
