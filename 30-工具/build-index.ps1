# build-index.ps1 —— 从 JSONL 生成「标题 + 一行摘要」的导航索引
#
# 建立者: DSH   时间: 2026-10-08
# 依据: Codex 圆桌建议 —— 现有 title/tags 足够生成轻量 INDEX，作为导航，不复制全文；
#       生成式索引避免手工漂移。
#
# 产物: 20-历史经验\data\INDEX.md    （事实/经验/决策/事件 四张表，每行一条）
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File build-index.ps1
#   powershell -ExecutionPolicy Bypass -File build-index.ps1 -Namespace universal

param(
    # 默认 = 本脚本所在包（$PSScriptRoot 是 30-工具，往上一层即包根）
    # 默认命名空间 = local —— 本机工作母版以 local 层为主（发行版那份默认 universal）
    [string]$Pack = (Split-Path $PSScriptRoot -Parent),
    [ValidateSet('local', 'universal', 'contributed')]
    [string]$Namespace = 'local',
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$dataDir = Join-Path $Pack "20-历史经验\data\$Namespace"
$outFile = Join-Path $Pack "20-历史经验\data\INDEX.md"
$bom = New-Object System.Text.UTF8Encoding($false)   # .md 不要 BOM

function Say($m) { if (-not $Quiet) { Write-Host $m } }

function Read-Jsonl([string]$path) {
    if (-not (Test-Path $path)) { return @() }
    $rows = @()
    foreach ($line in (Get-Content $path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if (-not $line.Trim()) { continue }
        try { $rows += ($line | ConvertFrom-Json) } catch { }
    }
    return $rows
}

# 一行摘要：压掉换行、限长
function OneLine([string]$s, [int]$max = 88) {
    if (-not $s) { return '' }
    $t = ($s -replace "[\r\n]+", ' ').Trim()
    if ($t.Length -gt $max) { $t = $t.Substring(0, $max) + '…' }
    return $t
}

Say ''
Say "=== 生成经验包索引 ($Namespace) ==="

$facts = Read-Jsonl (Join-Path $dataDir 'facts.jsonl')
$lessons = Read-Jsonl (Join-Path $dataDir 'lessons.jsonl')
$decisions = Read-Jsonl (Join-Path $dataDir 'decisions.jsonl')
$timeline = Read-Jsonl (Join-Path $dataDir 'timeline.jsonl')

Say ("   facts " + @($facts).Count + " / lessons " + @($lessons).Count +
     " / decisions " + @($decisions).Count + " / timeline " + @($timeline).Count)

$sb = New-Object System.Text.StringBuilder

[void]$sb.AppendLine('# 经验包索引（自动生成 —— 请勿手工编辑）')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("> 由 ``30-工具\build-index.ps1`` 生成于 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')，命名空间 ``$Namespace``。")
[void]$sb.AppendLine('>')
[void]$sb.AppendLine('> **用法**：这是导航，不是正文。下面每条只有一个标题/摘要 + id。')
[void]$sb.AppendLine('> 想读全文，用 ``memory.ps1 search <关键词>``（它会打印命中原行），')
[void]$sb.AppendLine('> 或直接在对应 ``.jsonl`` 里按 id 搜。')
[void]$sb.AppendLine('')

# ---------------------------------------------------------------- 事实
[void]$sb.AppendLine('## 一、已验证事实 / 假设（facts）')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| id | 状态 | 时间 | 摘要 |')
[void]$sb.AppendLine('|---|---|---|---|')
foreach ($f in $facts) {
    $st = if ($f.status) { $f.status } else { '' }
    $ts = if ($f.ts) { ([string]$f.ts).Substring(0, [Math]::Min(10, ([string]$f.ts).Length)) } else { '' }
    [void]$sb.AppendLine('| ' + $f.id + ' | ' + $st + ' | ' + $ts + ' | ' + (OneLine $f.claim) + ' |')
}
[void]$sb.AppendLine('')

# ---------------------------------------------------------------- 经验
[void]$sb.AppendLine('## 二、经验教训（lessons）')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| id | 类型 | 时间 | 标题 |')
[void]$sb.AppendLine('|---|---|---|---|')
foreach ($l in $lessons) {
    $k = if ($l.kind) { $l.kind } else { '' }
    $ts = if ($l.ts) { ([string]$l.ts).Substring(0, [Math]::Min(10, ([string]$l.ts).Length)) } else { '' }
    [void]$sb.AppendLine('| ' + $l.id + ' | ' + $k + ' | ' + $ts + ' | ' + (OneLine $l.title 96) + ' |')
}
[void]$sb.AppendLine('')

# ---------------------------------------------------------------- 决策
[void]$sb.AppendLine('## 三、决策（decisions）')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| id | 时间 | 问题 | 选定 |')
[void]$sb.AppendLine('|---|---|---|---|')
foreach ($d in $decisions) {
    $ts = if ($d.ts) { ([string]$d.ts).Substring(0, [Math]::Min(10, ([string]$d.ts).Length)) } else { '' }
    [void]$sb.AppendLine('| ' + $d.id + ' | ' + $ts + ' | ' + (OneLine $d.question 68) + ' | ' + (OneLine $d.chosen 68) + ' |')
}
[void]$sb.AppendLine('')

# ---------------------------------------------------------------- 事件
[void]$sb.AppendLine('## 四、事件（timeline，倒序）')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| id | 时间 | 事件 |')
[void]$sb.AppendLine('|---|---|---|')
foreach ($t in ($timeline | Sort-Object ts -Descending)) {
    $ts = if ($t.ts) { ([string]$t.ts).Substring(0, [Math]::Min(16, ([string]$t.ts).Length)) } else { '' }
    [void]$sb.AppendLine('| ' + $t.id + ' | ' + $ts + ' | ' + (OneLine $t.event 96) + ' |')
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('---')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('*本文件是导航索引。正文在 `facts.jsonl` / `lessons.jsonl` / `decisions.jsonl` / `timeline.jsonl`。*')

# 原子写
$tmp = "$outFile.tmp"
[System.IO.File]::WriteAllText($tmp, $sb.ToString(), $bom)
Move-Item $tmp $outFile -Force

$size = (Get-Item $outFile).Length
Say ("   已写入: " + $outFile)
Say ("   大小: " + $size + "B   行数: " + ($sb.ToString() -split "`n").Count)
Say '=== 完成 ==='
