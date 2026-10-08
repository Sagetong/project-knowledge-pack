# merge-pack.ps1 —— 按 80-合并与继承策略 执行跨包合并（最小可用版）
#
# 建立者: DSH   时间: 2026-10-08
# 依据: 80-合并与继承策略\README.md 第三节「合并流程（六步）」
#       + Codex 圆桌对"最小可用功能清单"的建议
#
# 设计目标：够用、不过度设计、失败不留半成品。
#
# 核心保证（按 80 的规则）：
#   · 核心层（core\ 00-底层逻辑\ 30-工具\）—— 只做比对，【永不写入】
#   · 共享层（20-历史经验\data\universal\ 40-Skills\universal\ 10-说明书\）—— 可合并
#   · 贡献层（contributed\）—— 只追加
#   · 本地层（local\ STATE.md LESSONS.md 50-环境档案\）—— 【绝不读取他人包里的这层】
#   · 同 id 不同内容 —— 两条都保留，不二选一，并在冲突报告里列出
#   · 绝不删除本地已有条目
#
# 用法:
#   # 先看会做什么（不写任何文件）
#   powershell -ExecutionPolicy Bypass -File merge-pack.ps1 `
#       -Local 'C:\path\to\my\pack' -Incoming 'C:\path\to\their\pack' -DryRun
#
#   # 真跑（结果写到输出目录，不覆盖本地包）
#   powershell -ExecutionPolicy Bypass -File merge-pack.ps1 `
#       -Local 'C:\path\to\my\pack' -Incoming 'C:\path\to\their\pack' `
#       -Out 'C:\path\to\merged'
#
# 退出码: 0=成功(可能含冲突但不影响)  2=参数/路径错误  3=输入包含核心层文件(拒绝)  4=数据校验失败

param(
    [Parameter(Mandatory=$true)][string]$Local,
    [Parameter(Mandatory=$true)][string]$Incoming,
    [string]$Out = '',
    [switch]$DryRun,
    # 对方包里含核心层文件时怎么办。
    #   Skip   = 跳过那些文件、继续合并数据层，并大声报告（默认，符合 80 号文档第 4 步）
    #   Reject = 整个合并直接失败（更严；审阅完全陌生的来源时可用）
    [ValidateSet('Skip', 'Reject')][string]$CorePolicy = 'Skip'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$bom = New-Object System.Text.UTF8Encoding($false)   # .jsonl / .md 都不用 BOM

function Say($m) { Write-Host $m }
function Fail($code, $msg) { Write-Host ('[失败] ' + $msg); exit $code }

# ---------------------------------------------------------------- 分层定义
$CORE_DIRS = @('core', '00-底层逻辑', '30-工具')
$SHARE_DIRS = @('20-历史经验\data\universal', '40-Skills\universal', '10-说明书')
$CONTRIB_DIRS = @('20-历史经验\data\contributed', '40-Skills\contributed')
$LOCAL_DIRS = @('20-历史经验\data\local', '40-Skills\local', '50-环境档案')
$DATA_NAMES = @('facts', 'lessons', 'decisions', 'timeline')

Say ''
Say '=== 经验包合并（merge-pack.ps1）==='
if ($DryRun) { Say '（试运行：不会写出任何文件）' }
Say ''

if (-not (Test-Path $Local))    { Fail 2 ('找不到本地包: ' + $Local) }
if (-not (Test-Path $Incoming)) { Fail 2 ('找不到对方包: ' + $Incoming) }
if (-not $DryRun -and -not $Out) { Fail 2 '非试运行必须指定 -Out（不覆盖本地包，写到新目录）' }

# ---------------------------------------------------------------- 0. 路径穿越防护
Say '[0/6] 安全检查：路径穿越与核心层'
function Assert-SafeRel([string]$root, [string]$rel, [string]$ctx) {
    if ([string]::IsNullOrWhiteSpace($rel)) { Fail 4 ($ctx + ' 出现空路径') }
    if ($rel -match '\.\.') { Fail 3 ($ctx + ' 含路径穿越: ' + $rel) }
    if ([System.IO.Path]::IsPathRooted($rel)) { Fail 3 ($ctx + ' 是绝对路径: ' + $rel) }
    $full = [System.IO.Path]::GetFullPath((Join-Path $root $rel))
    $rootFull = [System.IO.Path]::GetFullPath($root)
    if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Fail 3 ($ctx + ' 解析后越出包目录: ' + $rel)
    }
    return $full
}

# 对方包里是否含核心层文件。
# 按 80 号文档第 4 步：核心层文件【拒绝导入】（指那些文件本身），而不是让整个合并失败。
# 现实里贡献者的包多半是 fork 来的，必然带 core\ —— 所以默认 Skip（跳过 + 大声报告），
# 需要更严时用 -CorePolicy Reject。
$coreLeak = @()
foreach ($d in $CORE_DIRS) {
    $p = Join-Path $Incoming $d
    if (Test-Path $p) {
        Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $coreLeak += $_.FullName.Replace($Incoming, '').TrimStart('\')
        }
    }
}
foreach ($f in @('core-manifest.txt', 'core-manifest.txt.sig', 'allowed_signers')) {
    if (Test-Path (Join-Path $Incoming $f)) { $coreLeak += $f }
}
if (@($coreLeak).Count -gt 0) {
    Say ('   [警告] 对方包含 ' + @($coreLeak).Count + ' 个核心层文件')
    $coreLeak | Select-Object -First 8 | ForEach-Object { Say ('      ' + $_) }
    if ($CorePolicy -eq 'Reject') {
        Say '   [拒绝] 按 -CorePolicy Reject 的设置，本次合并不执行'
        Fail 3 '输入含核心层文件，且已指定 Reject'
    }
    Say '   [跳过] 这些核心层文件【不会被读取或写入】；只合并共享层与贡献层（-CorePolicy Skip）'
} else {
    Say '   OK 对方包不含核心层文件'
}

# ---------------------------------------------------------------- 1. 读取 JSONL
Say ''
Say '[1/6] 读取两侧数据层'

function Read-Jsonl([string]$path) {
    $rows = @()
    if (-not (Test-Path $path)) { return $rows }
    $n = 0
    foreach ($line in [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)) {
        $n++
        if (-not $line.Trim()) { continue }
        try {
            $obj = $line | ConvertFrom-Json
            $rows += [pscustomobject]@{ Line = $line.Trim(); Obj = $obj; SrcLine = $n }
        } catch {
            throw ('JSONL 解析失败: ' + $path + ' 第 ' + $n + ' 行 —— ' + $_.Exception.Message)
        }
    }
    return $rows
}

$plan = @()   # 每个元素: 层, 相对路径, 本地条数, 对方条数, 合并后行数组, 冲突列表

foreach ($layer in @(@{n='共享层'; dirs=$SHARE_DIRS; mode='merge'},
                     @{n='贡献层'; dirs=$CONTRIB_DIRS; mode='append'})) {
    foreach ($rel in $layer.dirs) {
        foreach ($name in $DATA_NAMES) {
            $relFile = Join-Path $rel ($name + '.jsonl')
            $localFile = Join-Path $Local $relFile
            $inFile = Join-Path $Incoming $relFile

            $hasLocal = Test-Path $localFile
            $hasIn = Test-Path $inFile
            if (-not $hasLocal -and -not $hasIn) { continue }

            $localRows = if ($hasLocal) { Read-Jsonl $localFile } else { @() }
            $inRows = if ($hasIn) { Read-Jsonl $inFile } else { @() }

            # 本地 id 集合
            $localIds = @{}
            foreach ($r in $localRows) {
                $id = [string]$r.Obj.id
                if ($id) { $localIds[$id] = $r.Line }
            }

            $merged = New-Object System.Collections.ArrayList
            foreach ($r in $localRows) { [void]$merged.Add($r.Line) }

            $conflicts = @()
            $added = 0
            foreach ($r in $inRows) {
                $id = [string]$r.Obj.id
                if ($id -and $localIds.ContainsKey($id)) {
                    if ($localIds[$id] -eq $r.Line) {
                        # 完全相同，跳过
                    } else {
                        # 同 id 不同内容 —— 【两条都保留】
                        [void]$merged.Add($r.Line)
                        $conflicts += ('同 id 不同内容: ' + $id)
                        $added++
                    }
                } else {
                    [void]$merged.Add($r.Line)
                    $added++
                }
            }

            $plan += [pscustomobject]@{
                Layer      = $layer.n
                Mode       = $layer.mode
                RelFile    = $relFile
                LocalCount = @($localRows).Count
                InCount    = @($inRows).Count
                Added      = $added
                Lines      = $merged
                Conflicts  = $conflicts
            }
        }
    }
}

if (@($plan).Count -eq 0) {
    Say '   没有可合并的数据文件'
} else {
    foreach ($p in $plan) {
        Say ('   ' + $p.Layer + '  ' + $p.RelFile)
        Say ('      本地 ' + $p.LocalCount + '  对方 ' + $p.InCount + '  新增 ' + $p.Added + '  冲突 ' + @($p.Conflicts).Count)
    }
}

# ---------------------------------------------------------------- 2. 本地层保护
Say ''
Say '[2/6] 本地层保护'
$localLeak = @()
foreach ($d in $LOCAL_DIRS) {
    if (Test-Path (Join-Path $Incoming $d)) { $localLeak += $d }
}
if (@($localLeak).Count -gt 0) {
    Say ('   [忽略] 对方包里含有本地层内容（不读取、不合并）: ' + ($localLeak -join ', '))
} else {
    Say '   OK 对方包不含本地层内容'
}

# ---------------------------------------------------------------- 3. 写出
Say ''
Say '[3/6] 写出结果'
if ($DryRun) {
    Say ('   [试运行] 会把结果写到: ' + $(if ($Out) { $Out } else { '(未指定，试运行不需要)' }))
} else {
    # 先写临时目录，成功后整体替换 —— 避免半成品
    $tmpOut = $Out + '.tmp-' + (Get-Date -Format 'HHmmss')
    if (Test-Path $tmpOut) { Remove-Item $tmpOut -Recurse -Force }
    New-Item -ItemType Directory -Path $tmpOut -Force | Out-Null

    # 3.1 复制本地包全量（保底：本地有什么就有什么）
    robocopy $Local $tmpOut /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    Say ('   已复制本地包基准 -> ' + $tmpOut)

    # 3.2 写入合并后的数据文件
    foreach ($p in $plan) {
        $dst = Join-Path $tmpOut $p.RelFile
        $dir = Split-Path $dst -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $text = ($p.Lines -join "`r`n")
        if ($text) { $text += "`r`n" }
        [System.IO.File]::WriteAllText($dst, $text, $bom)
    }
    Say '   已写入合并后的数据文件'

    # 3.3 冲突报告
    $reports = @($plan | Where-Object { @($_.Conflicts).Count -gt 0 })
    if (@($reports).Count -gt 0) {
        $repDir = Join-Path $tmpOut 'merges'
        New-Item -ItemType Directory -Path $repDir -Force | Out-Null
        $repFile = Join-Path $repDir ('merge-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.md')
        $rl = New-Object System.Collections.ArrayList
        [void]$rl.Add('# 合并冲突报告')
        [void]$rl.Add('')
        [void]$rl.Add('- 时间: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        [void]$rl.Add('- 本地包: ' + $Local)
        [void]$rl.Add('- 对方包: ' + $Incoming)
        [void]$rl.Add('')
        [void]$rl.Add('> 按 80-合并与继承策略 第四节：同 id 有不同说法时不允许二选一，两条都保留。')
        [void]$rl.Add('')
        foreach ($r in $reports) {
            [void]$rl.Add('## ' + $r.RelFile)
            [void]$rl.Add('')
            foreach ($c in $r.Conflicts) { [void]$rl.Add('- ' + $c) }
            [void]$rl.Add('')
        }
        [System.IO.File]::WriteAllText($repFile, ($rl -join "`r`n"), $bom)
        Say ('   已写冲突报告: ' + $repFile.Replace($tmpOut, ''))
    }

    # 3.4 原子替换
    if (Test-Path $Out) {
        $old = $Out + '.old-' + (Get-Date -Format 'HHmmss')
        Move-Item $Out $old -Force
        Say ('   旧输出已改名保留: ' + (Split-Path $old -Leaf))
    }
    Move-Item $tmpOut $Out -Force
    Say ('   完成 -> ' + $Out)
}

# ---------------------------------------------------------------- 4. 校验
Say ''
Say '[4/6] 校验结果'
if ($DryRun) {
    Say '   [试运行] 跳过'
} else {
    $okAll = $true
    foreach ($p in $plan) {
        $dst = Join-Path $Out $p.RelFile
        if (-not (Test-Path $dst)) { Say ('   [缺] ' + $p.RelFile); $okAll = $false; continue }
        $n = @([System.IO.File]::ReadAllLines($dst, [System.Text.Encoding]::UTF8) | Where-Object { $_.Trim() }).Count
        $want = @($p.Lines).Count
        $flag = if ($n -eq $want) { 'OK' } else { '不一致!' }
        if ($n -ne $want) { $okAll = $false }
        Say ('   ' + $p.RelFile.PadRight(44) + ' 期望 ' + $want + '  实际 ' + $n + '   ' + $flag)
    }
    if (-not $okAll) { Fail 4 '合并结果校验未通过' }
}

# ---------------------------------------------------------------- 5. 核心层比对
Say ''
Say '[5/6] 核心层比对（只读，永不写入）'
$diffCore = @()
foreach ($d in $CORE_DIRS) {
    $lp = Join-Path $Local $d
    $ip = Join-Path $Incoming $d
    if (-not (Test-Path $ip)) { continue }
    Get-ChildItem $ip -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        $rel = $_.FullName.Substring($Incoming.Length).TrimStart('\')
        $lf = Join-Path $Local $rel
        if (-not (Test-Path $lf)) { $script:diffCore += ($rel + '  (本地无此文件)') }
        else {
            $h1 = (Get-FileHash $lf -Algorithm SHA256).Hash
            $h2 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
            if ($h1 -ne $h2) { $script:diffCore += ($rel + '  (内容不同)') }
        }
    }
}
if (@($diffCore).Count -eq 0) {
    Say '   OK 未发现核心层差异（或对方包不含核心层）'
} else {
    Say ('   对方包与本地在核心层有 ' + @($diffCore).Count + ' 处差异 —— 按策略【一律不采纳】，仅报告：')
    $diffCore | Select-Object -First 15 | ForEach-Object { Say ('      ' + $_) }
}

# ---------------------------------------------------------------- 6. 小结
Say ''
Say '[6/6] 小结'
$totalAdded = ($plan | Measure-Object -Property Added -Sum).Sum
$totalConf = (@($plan | ForEach-Object { $_.Conflicts }) | Measure-Object).Count
Say ('   新增条目: ' + $totalAdded)
Say ('   冲突条目: ' + $totalConf + '（两条都保留）')
Say ('   核心层:   ' + @($diffCore).Count + ' 处差异，全部未采纳')
Say ''
Say '=== 完成 ==='
Say '  提示: 合并只影响共享层与贡献层。核心层由原作者维护，永不变更。'
exit 0
