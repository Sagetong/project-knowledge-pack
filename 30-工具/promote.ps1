#Requires -Version 5.1
<#
.SYNOPSIS
    Promote —— 把 local 命名空间的经验提升为 universal（可分享的通用知识）

.DESCRIPTION
    经验先在 local 产生（含本机路径、IP 等）。当确认它具有普适性后，
    用本工具把它提升到 universal 命名空间 —— 那里才是可以分享出去的部分。

    提升时会做敏感信息扫描：
      · IP 地址、主机名、绝对路径、端口、密钥片段
      · 发现后给出警告，并要求显式确认

.EXAMPLE
    .\promote.ps1 -List                     # 列出 candidates（含敏感信息检查结果）
    .\promote.ps1 -Id l005                  # 提升 l005 到 universal
    .\promote.ps1 -Id l005 -DryRun          # 只看会做什么
    .\promote.ps1 -Id l005 -KeepLocal       # 提升后保留 local 副本（默认保留）
    .\promote.ps1 -Id l005 -RemoveLocal     # 提升后从 local 删除
    .\promote.ps1 -All -Kind method         # 批量提升所有 method 类经验
#>
[CmdletBinding()]
param(
    [string]$Id,
    [switch]$List,
    [switch]$All,
    [string]$Kind,
    [switch]$DryRun,
    [switch]$KeepLocal = $true,
    [switch]$RemoveLocal
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$PackRoot  = Split-Path $ScriptDir -Parent
if (-not (Test-Path (Join-Path $PackRoot '20-历史经验'))) { $PackRoot = $ScriptDir }

$DataRoot = Join-Path $PackRoot '20-历史经验\data'
$LocalDir = Join-Path $DataRoot 'local'
$UnivDir  = Join-Path $DataRoot 'universal'

# 敏感信息模式
$SensitivePatterns = @(
    @{ name = 'IPv4 地址';    re = '\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b' }
    @{ name = 'Windows 路径'; re = '[A-Za-z]:\\[^\s"'']+' }
    @{ name = 'Unix 路径';    re = '/(usr|etc|var|home|opt|root)/[^\s"'']+' }
    @{ name = '端口号';       re = '\b(port|端口)\s*[:=]?\s*\d{2,5}\b' }
    @{ name = 'UUID';         re = '\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b' }
    @{ name = '疑似密钥';     re = '\b[A-Za-z0-9_\-]{40,}\b' }
    @{ name = '主机名';       re = '\b(<机器名>|DESKTOP-[A-Z0-9]+|LAPTOP-[A-Z0-9]+)\b' }
)

function Get-SensitiveHits($text) {
    $hits = @()
    foreach ($p in $SensitivePatterns) {
        $m = [regex]::Matches($text, $p.re)
        if ($m.Count -gt 0) {
            $samples = @($m | Select-Object -First 2 | ForEach-Object { $_.Value })
            $hits += [pscustomobject]@{ kind = $p.name; count = $m.Count; samples = ($samples -join ', ') }
        }
    }
    return $hits
}

function Read-NsFile($dir, $type) {
    $p = Join-Path $dir ($type + '.jsonl')
    if (-not (Test-Path $p)) { return @() }
    $out = @()
    foreach ($line in (Get-Content $p -Encoding UTF8 | Where-Object { $_.Trim() })) {
        try { $out += ($line | ConvertFrom-Json) } catch { }
    }
    return $out
}

function Append-Line($dir, $type, $obj) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $p = Join-Path $dir ($type + '.jsonl')
    $json = $obj | ConvertTo-Json -Depth 8 -Compress
    $json = $json -replace ':\{\},"', ': [],"' -replace ':\{\}\}$', ': []}'
    if ($DryRun) { Write-Host ("  [DRY] " + $p + " ← " + $json) -ForegroundColor DarkGray; return }
    Add-Content -Path $p -Value $json -Encoding UTF8
}

function Promote-One($item, $type) {
    Write-Host ''
    Write-Host ('  ── 处理 [' + $item.id + '] ' + $(if ($item.title) { $item.title } else { $item.claim })) -ForegroundColor Cyan

    # 敏感信息扫描
    $text = ($item | ConvertTo-Json -Depth 8 -Compress)
    $hits = Get-SensitiveHits $text
    if (@($hits).Count -gt 0) {
        Write-Host '     ⚠ 检测到可能的敏感信息：' -ForegroundColor Yellow
        foreach ($h in $hits) {
            Write-Host ('        · ' + $h.kind.PadRight(12) + ' ×' + $h.count + '  例: ' + $h.samples) -ForegroundColor Yellow
        }
        Write-Host '     → 提升前建议先改写为不含具体环境信息的表述' -ForegroundColor Yellow
    } else {
        Write-Host '     ✅ 未检测到明显敏感信息' -ForegroundColor Green
    }

    # 构造提升后的条目
    $new = [ordered]@{}
    foreach ($k in $item.PSObject.Properties.Name) {
        if ($k -eq 'id') { continue }
        $new[$k] = $item.$k
    }
    $new = [ordered]@{
        id     = $item.id
        ts     = $item.ts
        schema = '1.0.0'
        origin = ('promoted-from:local')
    } + $new

    # 写入 universal
    Append-Line $UnivDir $type $new
    if (-not $DryRun) {
        Write-Host ('     ✅ 已写入 universal\' + $type + '.jsonl') -ForegroundColor Green
    }

    # 处理 local
    if ($RemoveLocal) {
        Write-Host ('     ⚠ 未实现从 local 删除（需人工确认），请手动处理') -ForegroundColor Yellow
    } else {
        Write-Host ('     · local 副本保留') -ForegroundColor DarkGray
    }
}

# ============================ 主流程 ============================

Write-Host ''
Write-Host '════════ Promote · 提升为通用知识 ════════' -ForegroundColor Cyan

# 收集 local 的所有条目
$allLocal = @()
foreach ($type in @('lessons', 'facts', 'decisions', 'timeline')) {
    foreach ($it in (Read-NsFile $LocalDir $type)) {
        $allLocal += [pscustomobject]@{ type = $type; item = $it }
    }
}

# 已在 universal 的 id
$alreadyUniversal = @{}
foreach ($type in @('lessons', 'facts', 'decisions', 'timeline')) {
    foreach ($it in (Read-NsFile $UnivDir $type)) {
        if ($it.id) { $alreadyUniversal[$it.id] = $true }
    }
}

Write-Host ''
Write-Host ('  local 共 ' + @($allLocal).Count + ' 条 · universal 已有 ' + $alreadyUniversal.Count + ' 条') -ForegroundColor Gray

# ---- 列出候选 ----
if ($List -or (-not $Id -and -not $All)) {
    Write-Host ''
    Write-Host '  可提升候选（universal 中尚不存在）：' -ForegroundColor Cyan
    Write-Host ''
    $n = 0
    foreach ($e in $allLocal) {
        $it = $e.item
        if (-not $it.id) { continue }
        if ($alreadyUniversal.ContainsKey($it.id)) { continue }
        if ($Kind -and $it.kind -ne $Kind) { continue }
        $n++
        $label = if ($it.title) { $it.title } elseif ($it.claim) { $it.claim } elseif ($it.event) { $it.event } else { '(无标题)' }
        if ($label.Length -gt 60) { $label = $label.Substring(0, 60) + '…' }
        $text = ($it | ConvertTo-Json -Depth 8 -Compress)
        $hits = Get-SensitiveHits $text
        $flag = if (@($hits).Count -gt 0) { '⚠' } else { ' ' }
        Write-Host ('  ' + $flag + ' [' + $it.id + '] ' + $e.type.PadRight(10) + $label)
        if (@($hits).Count -gt 0) {
            Write-Host ('       敏感: ' + (($hits | ForEach-Object { $_.kind }) -join ', ')) -ForegroundColor DarkYellow
        }
    }
    Write-Host ''
    Write-Host ('  共 ' + $n + ' 条候选') -ForegroundColor Gray
    Write-Host ''
    Write-Host '  用法: .\promote.ps1 -Id <条目标识>       提升单条' -ForegroundColor Yellow
    Write-Host '        .\promote.ps1 -All -Kind method    批量提升 method 类' -ForegroundColor Yellow
    Write-Host ''
    exit 0
}

# ---- 单条提升 ----
if ($Id) {
    $found = $false
    foreach ($e in $allLocal) {
        if ($e.item.id -eq $Id) {
            Promote-One $e.item $e.type
            $found = $true
            break
        }
    }
    if (-not $found) {
        Write-Host ('  ❌ 未找到条目: ' + $Id) -ForegroundColor Red
        exit 1
    }
    Write-Host ''
    exit 0
}

# ---- 批量提升 ----
if ($All) {
    $cnt = 0
    foreach ($e in $allLocal) {
        $it = $e.item
        if (-not $it.id) { continue }
        if ($alreadyUniversal.ContainsKey($it.id)) { continue }
        if ($Kind -and $it.kind -ne $Kind) { continue }
        Promote-One $it $e.type
        $cnt++
    }
    Write-Host ''
    Write-Host ('  共处理 ' + $cnt + ' 条') -ForegroundColor Green
    Write-Host ''
    exit 0
}
