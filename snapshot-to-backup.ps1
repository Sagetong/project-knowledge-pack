# snapshot-to-backup.ps1 —— 从工作母版刷新备份母版
# 建立者: DSH   时间: 2026-10-07
#
# 方向: ① 工作母版 → ② 备份母版（单向）
# 作用: 把工作母版的当前状态冻结成一份静止的参考副本
#
# 设计要点:
#   · 备份母版的价值在于「静止」。因此本脚本【按需运行】，不做定时。
#   · 运行时会先把旧备份移到一边（带时间戳），避免"快照失败还赔上旧副本"
#   · 备份母版永不设虎符
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File snapshot-to-backup.ps1
#   powershell -ExecutionPolicy Bypass -File snapshot-to-backup.ps1 -DryRun

param(
    [string]$Work   = '%USERPROFILE%\agents\经验包-工作母版',
    [string]$Backup = '%USERPROFILE%\agents\经验包-备份母版',
    [string]$ArchiveDir = '%USERPROFILE%\agents\_archive',
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$bom = New-Object System.Text.UTF8Encoding($true)

function Say($m) { Write-Host $m }

Say ''
Say '=== 工作母版 -> 备份母版 快照 ==='
if ($DryRun) { Say '（试运行模式，不会改动任何文件）' }
Say ''

if (-not (Test-Path $Work))   { Say ('[失败] 找不到工作母版: ' + $Work); exit 2 }
if (-not (Test-Path $Backup)) { Say ('[失败] 找不到备份母版: ' + $Backup); exit 3 }

# ---------- 1. 校验工作母版无虎符 ----------
Say '[1/5] 校验工作母版无虎符'
$pat = '(?i)(sign-core|verify-core|init-triple|unlock-triple|triple-vault|triple-salt|core-manifest|dual-key)'
$tiger = Get-ChildItem $Work -Recurse -File -EA SilentlyContinue | Where-Object { $_.Name -match $pat }
if ($tiger) {
    Say '  [失败] 工作母版中检测到虎符文件:'
    $tiger | ForEach-Object { Say ('    ' + $_.FullName.Replace($Work,'')) }
    exit 4
}
Say '  OK'

# ---------- 2. 把现有备份归档（不是删除） ----------
Say ''
Say '[2/5] 归档现有备份母版'
if (Test-Path $Backup) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $arch = Join-Path $ArchiveDir ('经验包-备份母版-' + $stamp)
    if ($DryRun) {
        Say ('  [试运行] 会把现有备份移到 ' + $arch)
    } else {
        if (-not (Test-Path $ArchiveDir)) { New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null }
        Move-Item $Backup $arch -Force
        Say ('  已归档 -> ' + (Split-Path $arch -Leaf))
    }
} else {
    Say '  现有备份不存在，跳过'
}

# ---------- 3. 复制工作母版 ----------
Say ''
Say '[3/5] 复制工作母版内容'
if ($DryRun) {
    $n = (Get-ChildItem $Work -Recurse -File | Measure-Object).Count
    Say ('  [试运行] 会复制 ' + $n + ' 个文件')
} else {
    robocopy $Work $Backup /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
    $n = (Get-ChildItem $Backup -Recurse -File -EA SilentlyContinue | Measure-Object).Count
    Say ('  已复制 ' + $n + ' 个文件')
}

# ---------- 4. 备份母版专属 security.json ----------
Say ''
Say '[4/5] 写入备份母版专属 security.json'
$secB = [ordered]@{
    system    = 'none-backup-master'
    version   = '1.0.0-backup'
    created   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
    snapshotOf = $Work
    description = '备份母版安全策略 —— 不设虎符、不直接调用。本目录是静止的参考副本，仅在工作母版损坏时用于参考与修复。'
    lockPolicy = [ordered]@{ tigerTally = $false; encryption = $false; calledDirectly = $false }
    usage = [ordered]@{
        normal   = '不调用。工具与 AI 都不应读写本目录。'
        onDamage = '工作母版损坏时，从本目录取回参考内容用于比对与修复。'
        refresh  = '仅在里程碑或重大变更后，由 snapshot-to-backup.ps1 刷新一次。'
    }
    rules = @(
        '永不设虎符、永不加密',
        '永不被工具读写（只由快照脚本写入）',
        '纯参考副本，出现分歧时以工作母版为准',
        '必须留在本机，不对外暴露'
    )
}
if (-not $DryRun) {
    $dst = Join-Path $Backup 'core\security.json'
    New-Item -ItemType Directory -Path (Split-Path $dst -Parent) -Force | Out-Null
    [System.IO.File]::WriteAllText($dst, ($secB | ConvertTo-Json -Depth 6), $bom)
    Say '  OK'
} else {
    Say '  [试运行] 跳过'
}

# ---------- 5. 校验 ----------
Say ''
Say '[5/5] 校验结果'
if (-not $DryRun) {
    $wf = (Get-ChildItem $Work   -Recurse -File -EA SilentlyContinue | Measure-Object).Count
    $bf = (Get-ChildItem $Backup -Recurse -File -EA SilentlyContinue | Measure-Object).Count
    Say ('  工作母版 ' + $wf + ' 文件   备份母版 ' + $bf + ' 文件')
    $t2 = Get-ChildItem $Backup -Recurse -File -EA SilentlyContinue | Where-Object { $_.Name -match $pat }
    if ($t2) { Say '  [警告] 备份母版中检测到虎符文件' } else { Say '  备份母版无虎符 OK' }

    # 比对关键数据条目数
    foreach ($rel in @('20-历史经验\data\local\facts.jsonl','20-历史经验\data\local\lessons.jsonl','20-历史经验\data\local\timeline.jsonl')) {
        $a = Join-Path $Work $rel
        $b = Join-Path $Backup $rel
        $ca = if (Test-Path $a) { (Get-Content $a -Encoding UTF8 | Measure-Object).Count } else { 0 }
        $cb = if (Test-Path $b) { (Get-Content $b -Encoding UTF8 | Measure-Object).Count } else { 0 }
        $flag = if ($ca -eq $cb) { 'OK' } else { '不一致!' }
        Say ('  ' + (Split-Path $rel -Leaf).PadRight(16) + ' 工作 ' + $ca + '  备份 ' + $cb + '   ' + $flag)
    }
} else {
    Say '  [试运行] 跳过'
}

Say ''
Say '=== 完成 ==='
Say '  提示: 备份母版的价值在于静止。不必频繁刷新。'
