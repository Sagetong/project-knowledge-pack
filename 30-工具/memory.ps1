#Requires -Version 5.1
<#
.SYNOPSIS
    DSH 长期记忆框架 —— 查询 / 追加 / 生成简报

.DESCRIPTION
    让任何 AI 或人可以直接读写项目记忆，不必通读散文文档。

.EXAMPLE
    .\memory.ps1                       # 概览
    .\memory.ps1 context               # ★ 生成给 AI 的简报（可复制）
    .\memory.ps1 search 防火墙          # 全文搜索
    .\memory.ps1 facts                 # 列出所有事实
    .\memory.ps1 facts verified        # 只看已验证
    .\memory.ps1 lessons               # 列出所有经验
    .\memory.ps1 timeline -Last 10     # 最近 10 条事件
    .\memory.ps1 decisions             # 列出决策
    .\memory.ps1 add-fact -Claim "..." -Status verified -Evidence "..." -Tags "a,b"
    .\memory.ps1 add-lesson -Title "..." -Kind pitfall -Context "..." -Solution "..." -Reusable "..."
    .\memory.ps1 add-event -Event "..." -Detail "..." -Actor DSH
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = 'summary',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Args,

    [string]$Claim, [string]$Status, [string]$Evidence, [string]$Tags, [string]$Source = 'DSH',
    [string]$Title, [string]$Kind, [string]$Context, [string]$Mistake, [string]$Solution,
    [string]$Reusable, [string]$Event, [string]$Detail, [string]$Actor = 'DSH',
    [string]$Question, [string]$Chosen, [string]$Rejected, [string]$Reason,
    [int]$Last = 10,

    # 写入哪个命名空间。默认 local（本机）。
    # 2026-10-07 补：原来没有这个参数，导致文档里写的
    #   `memory.ps1 add-lesson ... -Namespace contributed`
    # 实际是无效的 —— PowerShell 忽略/误绑了它，记录静默写进了 local。
    [ValidateSet('local', 'universal', 'contributed')]
    [string]$Namespace = 'local'
)

$ErrorActionPreference = 'Stop'
# 工具在 30-工具\，数据在 20-历史经验\data\<namespace>\
$ScriptDir = $PSScriptRoot
$PackRoot  = Split-Path $ScriptDir -Parent
$MemoryDir = Join-Path $PackRoot '20-历史经验\data'
if (-not (Test-Path $MemoryDir)) {
    # 兼容：脚本被单独复制出去时，回退到脚本同目录
    $MemoryDir = $ScriptDir
}

# 命名空间：读取顺序 = 通用优先，本机次之，外部贡献最后
$Namespaces = @('universal', 'local', 'contributed')
$IndexFile  = Join-Path $MemoryDir 'index.json'
# 写入命名空间：由 -Namespace 指定，默认 local
$WriteNs    = $Namespace

function Get-NsFiles([string]$type) {
    $out = @()
    foreach ($ns in $Namespaces) {
        $p = Join-Path (Join-Path $MemoryDir $ns) ($type + '.jsonl')
        if (Test-Path $p) { $out += $p }
    }
    if ($out.Count -eq 0) {
        $legacy = Join-Path $MemoryDir ($type + '.jsonl')
        if (Test-Path $legacy) { $out += $legacy }
    }
    return $out
}

function Get-NsLines([string]$type) {
    $out = @()
    foreach ($f in (Get-NsFiles $type)) {
        $out += @(Get-Content $f -Encoding UTF8 | Where-Object { $_.Trim() })
    }
    return $out
}

function Get-WriteFile([string]$type, [string]$ns) {
    if (-not $ns) { $ns = $WriteNs }
    $dir = Join-Path $MemoryDir $ns
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return (Join-Path $dir ($type + '.jsonl'))
}

$FactsFile     = Get-WriteFile 'facts'
$LessonsFile   = Get-WriteFile 'lessons'
$TimelineFile  = Get-WriteFile 'timeline'
$DecisionsFile = Get-WriteFile 'decisions'

function Get-Lines($path) {
    if (-not (Test-Path $path)) { return @() }
    return @(Get-Content $path -Encoding UTF8 | Where-Object { $_.Trim() })
}

function Parse-Jsonl($path) {
    foreach ($line in Get-Lines $path) {
        try { $line | ConvertFrom-Json } catch { }
    }
}

function Next-Id($path, $prefix) {
    # 2026-10-07 修复：原实现是「当前条数 + 1」。
    # 缺陷：只要删掉过任何一条记录，条数就会变小，下一条新增会拿到已被占用的编号。
    #      当天清理测试残留后就立刻撞车了（l103/l104/t087 各出现两次）。
    # 现改为「已有编号里的最大数字 + 1」，与条数无关。
    $max = 0
    foreach ($l in (Get-Lines $path)) {
        $oid = $null
        try { $oid = [string](($l | ConvertFrom-Json).id) } catch { continue }
        if (-not $oid) { continue }
        if (-not $oid.StartsWith($prefix)) { continue }
        $numPart = $oid.Substring($prefix.Length)
        $n = 0
        if ([int]::TryParse($numPart, [ref]$n)) {
            if ($n -gt $max) { $max = $n }
        }
    }
    return ('{0}{1:d3}' -f $prefix, ($max + 1))
}

function Append-Jsonl($path, $obj) {
    $json = $obj | ConvertTo-Json -Depth 6 -Compress
    Add-Content -Path $path -Value $json -Encoding UTF8
    # 更新索引
    if (Test-Path $IndexFile) {
        try {
            $idx = Get-Content $IndexFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $idx.updated = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
            $idx.stats.facts     = @(Get-NsLines 'facts').Count
            $idx.stats.lessons   = @(Get-NsLines 'lessons').Count
            $idx.stats.timeline  = @(Get-NsLines 'timeline').Count
            $idx.stats.decisions = @(Get-NsLines 'decisions').Count
            $idx | ConvertTo-Json -Depth 8 | Set-Content $IndexFile -Encoding UTF8
        } catch { }
    }
}

function Show-Table($items, $cols) {
    if (@($items).Count -eq 0) { Write-Host '  (无记录)' -ForegroundColor DarkGray; return }
    foreach ($it in $items) {
        $parts = @()
        foreach ($c in $cols) {
            $v = $it.$c
            if ($null -eq $v) { $v = '' }
            $v = [string]$v
            if ($v.Length -gt 78) { $v = $v.Substring(0, 78) + '…' }
            $parts += $v
        }
        Write-Host ('  ' + ($parts -join '  |  '))
    }
}

function Cmd-Summary {
    Write-Host ''
    Write-Host '════════ DSH 长期记忆框架 ════════' -ForegroundColor Cyan
    Write-Host ''
    $f = @(Get-NsLines 'facts')
    $l = @(Get-NsLines 'lessons')
    $t = @(Get-NsLines 'timeline')
    $d = @(Get-NsLines 'decisions')
    Write-Host ("  事实库  facts.jsonl     " + $f.Count + " 条") -ForegroundColor Green
    Write-Host ("  经验库  lessons.jsonl   " + $l.Count + " 条") -ForegroundColor Green
    Write-Host ("  时间线  timeline.jsonl  " + $t.Count + " 条") -ForegroundColor Green
    Write-Host ("  决策库  decisions.jsonl " + $d.Count + " 条") -ForegroundColor Green
    Write-Host ''
    if ($f.Count -gt 0) {
        $parsed = @(Parse-Jsonl $FactsFile)
        $g = $parsed | Group-Object status
        Write-Host '  事实按验证状态：'
        foreach ($x in $g) { Write-Host ("    " + $x.Name.PadRight(12) + $x.Count) }
        Write-Host ''
    }
    if ($t.Count -gt 0) {
        Write-Host '  最近 3 条事件：'
        @(Parse-Jsonl $TimelineFile) | Select-Object -Last 3 | ForEach-Object {
            Write-Host ("    " + $_.ts + "  " + $_.event)
        }
    }
    Write-Host ''
    Write-Host '  常用命令：' -ForegroundColor Yellow
    Write-Host '    .\memory.ps1 context          生成给 AI 的简报'
    Write-Host '    .\memory.ps1 search <关键词>   全文搜索'
    Write-Host '    .\memory.ps1 lessons          列出经验'
    Write-Host '    .\memory.ps1 add-event ...     追加事件'
    Write-Host ''
}

function Cmd-Context {
    # ★ 生成可复制给任何 AI 的简报
    $facts = @(Get-NsLines 'facts' | ForEach-Object { $_ | ConvertFrom-Json })
    $lessons = @(Get-NsLines 'lessons' | ForEach-Object { $_ | ConvertFrom-Json })
    $events = @(Get-NsLines 'timeline' | ForEach-Object { $_ | ConvertFrom-Json })
    $decisions = @(Get-NsLines 'decisions' | ForEach-Object { $_ | ConvertFrom-Json })

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('【项目记忆简报 · 由 DSH 记忆框架自动生成】')
    [void]$sb.AppendLine(('生成时间: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('== 一、已验证的事实 ==')
    foreach ($f in ($facts | Where-Object { $_.status -eq 'verified' })) {
        [void]$sb.AppendLine(('  [' + $f.id + '] ' + $f.claim))
        [void]$sb.AppendLine(('        证据: ' + $f.evidence))
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('== 二、假设（不能当依据）==')
    foreach ($f in ($facts | Where-Object { $_.status -eq 'hypothesis' })) {
        [void]$sb.AppendLine(('  [' + $f.id + '] ' + $f.claim))
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('== 三、未验证 / 待办 ==')
    foreach ($f in ($facts | Where-Object { $_.status -eq 'unverified' })) {
        [void]$sb.AppendLine(('  [' + $f.id + '] ' + $f.claim))
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('== 四、已证伪（不要再提）==')
    foreach ($f in ($facts | Where-Object { $_.status -eq 'falsified' })) {
        [void]$sb.AppendLine(('  [' + $f.id + '] ' + $f.claim))
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('== 五、经验教训（务必遵守）==')
    foreach ($l in $lessons) {
        [void]$sb.AppendLine(('  [' + $l.id + '][' + $l.kind + '] ' + $l.title))
        if ($l.reusable) { [void]$sb.AppendLine(('        → ' + $l.reusable)) }
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('== 六、关键决策 ==')
    foreach ($d in $decisions) {
        [void]$sb.AppendLine(('  [' + $d.id + '] ' + $d.question))
        [void]$sb.AppendLine(('        选了: ' + $d.chosen))
        [void]$sb.AppendLine(('        理由: ' + $d.reason))
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('== 七、最近事件（时间倒序，10 条）==')
    foreach ($e in (@($events) | Select-Object -Last 10)) {
        [void]$sb.AppendLine(('  ' + $e.ts + '  ' + $e.event + '  —— ' + $e.detail))
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('== 八、配套文档 ==')
    [void]$sb.AppendLine('  AGENTS.md   方法论      %USERPROFILE%\agents\B\workspace\AGENTS.md')
    [void]$sb.AppendLine('  STATE.md    当前状态    %USERPROFILE%\agents\bridge-client\STATE.md')
    [void]$sb.AppendLine('  LESSONS.md  经验教训    %USERPROFILE%\agents\bridge-client\LESSONS.md')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('【使用说明】这是机器生成的记忆简报，可直接粘贴给任何 AI 作为项目背景。')

    $out = $sb.ToString()
    Write-Host $out
    $outFile = Join-Path $MemoryDir 'CONTEXT.md'
    [IO.File]::WriteAllText($outFile, $out, (New-Object Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('  ★ 已同时写入: ' + $outFile) -ForegroundColor Green
}

function Cmd-Search($kw) {
    if (-not $kw) { Write-Host '  用法: .\memory.ps1 search <关键词>' -ForegroundColor Yellow; return }
    Write-Host ''
    Write-Host ("  搜索: " + $kw) -ForegroundColor Cyan
    Write-Host ''
    $map = @{ 'facts' = 'facts'; 'lessons' = 'lessons'; 'timeline' = 'timeline'; 'decisions' = 'decisions' }
    foreach ($k in $map.Keys) {
        $hits = @(Get-NsLines $map[$k] | Select-String -Pattern $kw -SimpleMatch)
        if ($hits.Count -gt 0) {
            Write-Host ("  ── " + $k + " (" + $hits.Count + ") ──") -ForegroundColor Yellow
            foreach ($h in $hits) {
                $s = $h.Line
                if ($s.Length -gt 200) { $s = $s.Substring(0, 200) + '…' }
                Write-Host ('    ' + $s)
            }
            Write-Host ''
        }
    }
}

function Cmd-Facts($filter) {
    $facts = @(Get-NsLines 'facts' | ForEach-Object { $_ | ConvertFrom-Json })
    if ($filter) { $facts = @($facts | Where-Object { $_.status -eq $filter }) }
    Write-Host ''
    Write-Host ("  事实库 (" + $facts.Count + " 条" + $(if($filter){", status=$filter"}) + ")") -ForegroundColor Cyan
    Write-Host ''
    foreach ($f in $facts) {
        $color = switch ($f.status) {
            'verified'   { 'Green' }
            'hypothesis' { 'Yellow' }
            'unverified' { 'Gray' }
            'falsified'  { 'Red' }
            default      { 'White' }
        }
        Write-Host ("  [" + $f.id + "] " + $f.status.PadRight(11) + $f.claim) -ForegroundColor $color
    }
    Write-Host ''
}

function Cmd-Lessons {
    $lessons = @(Get-NsLines 'lessons' | ForEach-Object { $_ | ConvertFrom-Json })
    Write-Host ''
    Write-Host ("  经验库 (" + $lessons.Count + " 条)") -ForegroundColor Cyan
    Write-Host ''
    foreach ($l in $lessons) {
        Write-Host ("  [" + $l.id + "][" + $l.kind + "] " + $l.title) -ForegroundColor Green
        if ($l.reusable) { Write-Host ("        → " + $l.reusable) -ForegroundColor DarkGray }
    }
    Write-Host ''
}

function Cmd-Timeline($n) {
    $events = @(Get-NsLines 'timeline' | ForEach-Object { $_ | ConvertFrom-Json })
    Write-Host ''
    Write-Host ("  时间线（最近 " + $n + " / 共 " + $events.Count + " 条）") -ForegroundColor Cyan
    Write-Host ''
    foreach ($e in (@($events) | Select-Object -Last $n)) {
        Write-Host ("  " + $e.ts + "  " + $e.event) -ForegroundColor Green
        if ($e.detail) { Write-Host ("        " + $e.detail) -ForegroundColor DarkGray }
    }
    Write-Host ''
}

function Cmd-Decisions {
    $ds = @(Get-NsLines 'decisions' | ForEach-Object { $_ | ConvertFrom-Json })
    Write-Host ''
    Write-Host ("  决策库 (" + $ds.Count + " 条)") -ForegroundColor Cyan
    Write-Host ''
    foreach ($d in $ds) {
        Write-Host ("  [" + $d.id + "] " + $d.question) -ForegroundColor Green
        Write-Host ("        选了: " + $d.chosen)
        Write-Host ("        理由: " + $d.reason) -ForegroundColor DarkGray
    }
    Write-Host ''
}

switch ($Command.ToLower()) {
    'summary'   { Cmd-Summary }
    'context'   { Cmd-Context }
    'search'    { Cmd-Search ($Args -join ' ') }
    'facts'     { Cmd-Facts ($Args | Select-Object -First 1) }
    'lessons'   { Cmd-Lessons }
    'timeline'  { Cmd-Timeline $Last }
    'decisions' { Cmd-Decisions }
    'add-fact' {
        if (-not $Claim) { Write-Host '  需要 -Claim' -ForegroundColor Red; break }
        $o = [ordered]@{
            id = Next-Id $FactsFile 'f'; ts = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
            claim = $Claim; status = $(if($Status){$Status}else{'unverified'})
            evidence = $Evidence; source = $Source
            tags = $(if($Tags){$Tags -split ','}else{@()})
        }
        Append-Jsonl $FactsFile $o
        Write-Host ("  ✅ 已追加事实 " + $o.id) -ForegroundColor Green
    }
    'add-lesson' {
        if (-not $Title) { Write-Host '  需要 -Title' -ForegroundColor Red; break }
        $o = [ordered]@{
            id = Next-Id $LessonsFile 'l'; ts = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
            title = $Title; kind = $(if($Kind){$Kind}else{'method'})
            context = $Context; mistake = $Mistake; solution = $Solution
            reusable = $Reusable; tags = $(if($Tags){$Tags -split ','}else{@()})
        }
        Append-Jsonl $LessonsFile $o
        Write-Host ("  ✅ 已追加经验 " + $o.id) -ForegroundColor Green
    }
    'add-event' {
        if (-not $Event) { Write-Host '  需要 -Event' -ForegroundColor Red; break }
        $o = [ordered]@{
            id = Next-Id $TimelineFile 't'; ts = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
            event = $Event; detail = $Detail; actor = $Actor
        }
        Append-Jsonl $TimelineFile $o
        Write-Host ("  ✅ 已追加事件 " + $o.id) -ForegroundColor Green
    }
    'add-decision' {
        if (-not $Question) { Write-Host '  需要 -Question' -ForegroundColor Red; break }
        $o = [ordered]@{
            id = Next-Id $DecisionsFile 'd'; ts = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
            question = $Question; chosen = $Chosen; rejected = $Rejected; reason = $Reason; reversible = $true
        }
        Append-Jsonl $DecisionsFile $o
        Write-Host ("  ✅ 已追加决策 " + $o.id) -ForegroundColor Green
    }
    default {
        Write-Host ('  未知命令: ' + $Command) -ForegroundColor Red
        Write-Host '  可用: summary | context | search | facts | lessons | timeline | decisions'
        Write-Host '        add-fact | add-lesson | add-event | add-decision'
    }
}
