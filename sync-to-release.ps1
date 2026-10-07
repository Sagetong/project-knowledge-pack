# sync-to-release.ps1 —— 从本机母版生成发行版
# 建立者: DSH   时间: 2026-10-07
#
# 方向: 母版 → 发行版（单向，绝不可反向）
# 作用: 母版是权威来源；发行版是脱敏后的公开版本
#
# 安全要求:
#   · 绝不修改母版
#   · 同步前校验母版确实"无虎符"
#   · 同步时对隐私层做脱敏
#   · 发行版的 local/ 与 环境档案 必须清空
#   · core/security.json 不参与整体覆盖（母版无虎符、发行版有虎符）
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File sync-to-release.ps1
#   powershell -ExecutionPolicy Bypass -File sync-to-release.ps1 -DryRun   # 只看会做什么

param(
    [string]$Master  = '%USERPROFILE%\agents\经验包-工作母版',
    [string]$Release = '%USERPROFILE%\agents\experience-pack',
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$bom = New-Object System.Text.UTF8Encoding($true)

function Say($m) { Write-Host $m }

Say ''
Say '=== 母版 -> 发行版 同步 ==='
if ($DryRun) { Say '（试运行模式，不会真的改动文件）' }
Say ''

if (-not (Test-Path $Master))  { Say ('[失败] 找不到母版: ' + $Master); exit 2 }
if (-not (Test-Path $Release)) { Say ('[失败] 找不到发行版: ' + $Release); exit 3 }

# ---------- 1. 校验母版无虎符 ----------
Say '[1/6] 校验母版确实无虎符'
$tigerPattern = '(?i)(sign-core|verify-core|init-triple|unlock-triple|init-dual|unlock-dual|triple-vault|triple-salt|core-manifest|dual-key)'
$tigerFiles = Get-ChildItem $Master -Recurse -File -EA SilentlyContinue | Where-Object { $_.Name -match $tigerPattern }
if ($tigerFiles) {
    Say '  [失败] 母版中检测到虎符文件 —— 母版必须保持无虎符:'
    $tigerFiles | ForEach-Object { Say ('    ' + $_.FullName.Replace($Master, '')) }
    exit 4
}
Say '  OK 母版无虎符文件'

# ---------- 2. 复制公开层 ----------
Say ''
Say '[2/6] 复制公开层到发行版'
$keepDirs = @('00-底层逻辑', '10-说明书', '30-工具', '60-贡献协议', '70-文明史书', '80-合并与继承策略')
$keepFiles = @('README.md', 'SCHEMA.md', 'MANIFEST.json', 'PROGRESS.md', 'DESKTOP-REGISTRY.md')

foreach ($d in $keepDirs) {
    $src = Join-Path $Master $d
    $dst = Join-Path $Release $d
    if (Test-Path $src) {
        if ($DryRun) { Say ('  [试运行] 会复制 ' + $d) }
        else {
            robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
            Say ('  ' + $d + '  OK')
        }
    }
}
foreach ($f in $keepFiles) {
    $src = Join-Path $Master $f
    if (Test-Path $src) {
        if (-not $DryRun) { Copy-Item $src (Join-Path $Release $f) -Force }
    }
}
Say '  顶层文件 OK'

# 历史经验的共享层
foreach ($sub in @('universal', 'contributed')) {
    $src = Join-Path $Master ('20-历史经验\data\' + $sub)
    $dst = Join-Path $Release ('20-历史经验\data\' + $sub)
    if (Test-Path $src) {
        if ($DryRun) { Say ('  [试运行] 会复制 20-历史经验\data\' + $sub) }
        else {
            robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
            Say ('  20-历史经验\data\' + $sub + '  OK')
        }
    }
}
# 历史经验的公共文档
foreach ($f in @('README.md', 'CONTEXT.md')) {
    $src = Join-Path $Master ('20-历史经验\' + $f)
    if (Test-Path $src) {
        if (-not $DryRun) { Copy-Item $src (Join-Path $Release ('20-历史经验\' + $f)) -Force }
    }
}

# Skills 的公开层
foreach ($sub in @('_template', 'universal', 'contributed')) {
    $src = Join-Path $Master ('40-Skills\' + $sub)
    $dst = Join-Path $Release ('40-Skills\' + $sub)
    if (Test-Path $src) {
        if ($DryRun) { Say ('  [试运行] 会复制 40-Skills\' + $sub) }
        else {
            robocopy $src $dst /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
        }
    }
}
if (-not $DryRun) { Say '  40-Skills OK' }

# ---------- 3. 清空隐私层 ----------
Say ''
Say '[3/6] 清空发行版的隐私层（作者数据不得外发）'
$purge = @(
    '20-历史经验\data\local',
    '40-Skills\local',
    '50-环境档案'
)
foreach ($rel in $purge) {
    $full = Join-Path $Release $rel
    if (Test-Path $full) {
        if (-not $DryRun) { Remove-Item $full -Recurse -Force -EA SilentlyContinue }
        Say ('  已清空 ' + $rel)
    } else {
        Say ('  不存在，跳过 ' + $rel)
    }
}

# 在发行版 local 放一个占位说明
if (-not $DryRun) {
    $localDir = Join-Path $Release '20-历史经验\data\local'
    New-Item -ItemType Directory -Path $localDir -Force | Out-Null
    $ph = "# local 层（用户私有）`r`n`r`n" +
          "此目录用于存放**使用者自己的**本地经验数据，不参与公开共享。`r`n`r`n" +
          "- 首次使用时由你的工具自动生成内容`r`n" +
          "- 受你自己的虎符（双口令 / 三选二）保护`r`n" +
          "- **不会**被上传或合并到他人的经验包`r`n`r`n" +
          "作者（Sage Tong）的本地数据已在生成发行版时清空，不会随发行版分发。`r`n"
    [System.IO.File]::WriteAllText((Join-Path $localDir 'README.md'), $ph, $bom)
}

# ---------- 4. security.json 差异说明 ----------
Say ''
Say '[4/6] 核对母版与发行版的 security.json'
$mSec = Join-Path $Master 'core\security.json'
$rSec = Join-Path $Release 'core\security.json'
if (Test-Path $mSec) {
    $mj = Get-Content $mSec -Raw -Encoding UTF8 | ConvertFrom-Json
    Say ('  母版: system=' + $mj.system + '  虎符=' + $mj.lockPolicy.tigerTally)
}
if (Test-Path $rSec) {
    $rj = Get-Content $rSec -Raw -Encoding UTF8 | ConvertFrom-Json
    Say ('  发行版: system=' + $rj.system + '  版本=' + $rj.version)
}
Say '  注: 两份 security.json 不同是【刻意设计】—— 故 core/ 不做整体覆盖'

# ---------- 5. 确认发行版仍有虎符 ----------
Say ''
Say '[5/6] 确认发行版仍持有虎符'
$relTiger = Get-ChildItem $Release -Recurse -File -EA SilentlyContinue | Where-Object { $_.Name -match $tigerPattern }
if ($relTiger) {
    Say ('  OK 发行版保留虎符文件 ' + @($relTiger).Count + ' 个')
} else {
    Say '  [警告] 发行版未发现虎符文件 —— 请确认是否被误删'
}

# ---------- 6. 单向性声明 ----------
Say ''
Say '[6/6] 单向性'
Say '  本脚本为【单向】：母版 -> 发行版。'
Say '  脚本中不存在任何从发行版回写母版的路径。'
Say '  若需把发行版的改动带回母版，请人工确认后另行处理。'

Say ''
Say '=== 完成 ==='
