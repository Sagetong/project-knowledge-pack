# selfcheck.ps1 —— 经验包自检：确认这个包在你机器上真的能用
#
# 建立者: DSH   时间: 2026-10-08
# 依据: Codex 圆桌建议 —— "另补一条自检命令，验证 PowerShell、脚本路径、
#       读写能力和索引生成"
#
# 用途: 别人 clone 到自己的电脑后，先跑这一条，就知道能不能用、缺什么。
#       它【只做只读检查】，不会修改任何数据（写入测试在临时副本里做）。
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File selfcheck.ps1
#   powershell -ExecutionPolicy Bypass -File selfcheck.ps1 -SkipWriteTest

param(
    [string]$Pack = (Split-Path $PSScriptRoot -Parent),
    [switch]$SkipWriteTest
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$pass = 0
$warn = 0
$fail = 0

function OK($m)   { Write-Host ("  [OK]   " + $m) -ForegroundColor Green;  $script:pass++ }
function WARN($m) { Write-Host ("  [注意] " + $m) -ForegroundColor Yellow; $script:warn++ }
function BAD($m)  { Write-Host ("  [失败] " + $m) -ForegroundColor Red;    $script:fail++ }

Write-Host ''
Write-Host '================================================================'
Write-Host '  经验包 自检'
Write-Host '================================================================'
Write-Host ('  包位置: ' + $Pack)
Write-Host ''

# ---------------------------------------------------------------- 1. 运行环境
Write-Host '--- 1. 运行环境 ---'
if ($PSVersionTable.PSVersion.Major -ge 5) {
    OK ('PowerShell ' + $PSVersionTable.PSVersion.ToString())
} else {
    BAD ('PowerShell 版本过低: ' + $PSVersionTable.PSVersion.ToString() + '（需要 5.1+）')
}

if ($env:OS -eq 'Windows_NT') {
    OK '操作系统 Windows'
} else {
    WARN ('操作系统 ' + [System.Environment]::OSVersion.Platform.ToString() + ' —— 本包的工具是 PowerShell，非 Windows 需自行移植')
}

$policy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
Write-Host ('  当前执行策略: ' + $policy)
if ($policy -in @('Restricted', 'AllSigned')) {
    WARN '执行策略可能阻止 .ps1 运行。可临时用: powershell -ExecutionPolicy Bypass -File <脚本>'
} else {
    OK '执行策略允许运行脚本'
}

# ---------------------------------------------------------------- 2. 目录结构
Write-Host ''
Write-Host '--- 2. 目录结构 ---'
$needDirs = @('20-历史经验\data', '30-工具', '10-说明书')
foreach ($d in $needDirs) {
    $full = Join-Path $Pack $d
    if (Test-Path -LiteralPath $full) { OK ('存在 ' + $d) } else { BAD ('缺失 ' + $d) }
}

$mem = Join-Path $Pack '30-工具\memory.ps1'
if (Test-Path -LiteralPath $mem) { OK '读取工具 memory.ps1 就位' } else { BAD '找不到 30-工具\memory.ps1（这个包不完整）' }
$idxTool = Join-Path $Pack '30-工具\build-index.ps1'
if (Test-Path -LiteralPath $idxTool) { OK '索引生成工具 build-index.ps1 就位' } else { WARN '找不到 build-index.ps1 —— 无法重新生成标题索引' }

# ---------------------------------------------------------------- 3. 数据文件
Write-Host ''
Write-Host '--- 3. 数据文件（逐行 JSONL 校验）---'
$namespaces = @('local', 'universal', 'contributed')
$dataTypes = @('facts', 'lessons', 'decisions', 'timeline')
$totalRows = 0
foreach ($ns in $namespaces) {
    $nsDir = Join-Path $Pack ('20-历史经验\data\' + $ns)
    if (-not (Test-Path -LiteralPath $nsDir)) {
        Write-Host ('  [--]   ' + $ns + '\ 不存在（若某层不存在属正常（发行版没有 local，工作母版主要有 local））')
        continue
    }
    foreach ($t in $dataTypes) {
        $f = Join-Path $nsDir ($t + '.jsonl')
        if (-not (Test-Path -LiteralPath $f)) { continue }
        $badLines = @()
        $n = 0
        $lineNo = 0
        foreach ($line in [System.IO.File]::ReadAllLines($f, [System.Text.Encoding]::UTF8)) {
            $lineNo++
            if (-not $line.Trim()) { continue }
            $n++
            try { $null = $line | ConvertFrom-Json } catch { $badLines += $lineNo }
        }
        $script:totalRows += $n
        if (@($badLines).Count -eq 0) {
            OK ($ns + '\' + $t + '.jsonl  ' + $n + ' 条，全部可解析')
        } else {
            BAD ($ns + '\' + $t + '.jsonl  第 ' + ($badLines -join ',') + ' 行不是合法 JSON')
        }
    }
}
Write-Host ('  合计数据条目: ' + $totalRows)

# ---------------------------------------------------------------- 4. 读取能力
Write-Host ''
Write-Host '--- 4. 读取能力（真跑一次检索）---'
if (Test-Path -LiteralPath $mem) {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $mem summary 2>&1
    if ($LASTEXITCODE -eq 0 -or ($out -join '').Length -gt 0) {
        OK 'memory.ps1 summary 可以运行'
    } else {
        BAD 'memory.ps1 summary 运行失败'
    }
    $out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $mem search 经验 2>&1
    if (($out2 -join '') -match '搜索|命中|facts|lessons') {
        OK 'memory.ps1 search 可以运行'
    } else {
        WARN 'memory.ps1 search 输出异常（可能本包数据为空）'
    }
}

# ---------------------------------------------------------------- 5. 索引
Write-Host ''
Write-Host '--- 5. 标题索引 ---'
$idx = Join-Path $Pack '20-历史经验\data\INDEX.md'
if (Test-Path -LiteralPath $idx) {
    $sz = (Get-Item -LiteralPath $idx).Length
    OK ('INDEX.md 存在（' + $sz + ' 字节）')
    $head = Get-Content -LiteralPath $idx -Encoding UTF8 -TotalCount 6
    if (($head -join '') -match '索引') { OK 'INDEX.md 内容看起来正常' } else { WARN 'INDEX.md 开头不像索引导言' }
} else {
    WARN 'INDEX.md 不存在。可运行: powershell -ExecutionPolicy Bypass -File 30-工具\build-index.ps1'
}

# ---------------------------------------------------------------- 6. 写入能力
Write-Host ''
Write-Host '--- 6. 写入能力（在临时副本里试，不动你的数据）---'
if ($SkipWriteTest) {
    WARN '按 -SkipWriteTest 要求跳过'
} else {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('pack-writecheck-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    try {
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        # 最小结构：只需 data 目录与工具
        New-Item -ItemType Directory -Path (Join-Path $tmp '20-历史经验\data\contributed') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tmp '30-工具') -Force | Out-Null
        Copy-Item -LiteralPath $mem -Destination (Join-Path $tmp '30-工具\memory.ps1') -Force
        # 空 jsonl，让工具自己追加
        foreach ($t in @('facts', 'lessons', 'decisions', 'timeline')) {
            $p = Join-Path $tmp ('20-历史经验\data\contributed\' + $t + '.jsonl')
            [System.IO.File]::WriteAllText($p, '', (New-Object System.Text.UTF8Encoding($false)))
        }
        $tmpTool = Join-Path $tmp '30-工具\memory.ps1'
        $r = & powershell -NoProfile -ExecutionPolicy Bypass -File $tmpTool add-lesson `
            -Title 'selfcheck 写入测试' -Kind technique -Namespace contributed 2>&1
        $written = Join-Path $tmp '20-历史经验\data\contributed\lessons.jsonl'
        $cnt = if (Test-Path -LiteralPath $written) { @(Get-Content -LiteralPath $written -Encoding UTF8 | Where-Object { $_.Trim() }).Count } else { 0 }
        if ($cnt -ge 1) {
            OK ('写入成功（写入正确落到 contributed 层，共 ' + $cnt + ' 条）')
        } else {
            BAD '写入失败 —— memory.ps1 add-lesson 没有产生数据'
        }
        # 确认没写错层
        $localFile = Join-Path $tmp '20-历史经验\data\local\lessons.jsonl'
        if (Test-Path -LiteralPath $localFile) {
            $lc = @(Get-Content -LiteralPath $localFile -Encoding UTF8 | Where-Object { $_.Trim() }).Count
            if ($lc -gt 0) { BAD '-Namespace 被忽略，数据误写进 local 层！' } else { OK '-Namespace 生效，未误写 local' }
        } else {
            OK '-Namespace 生效，未误写 local'
        }
    } catch {
        BAD ('写入测试异常: ' + $_.Exception.Message)
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------- 7. 签名（可选）
Write-Host ''
Write-Host '--- 7. 核心签名（可选）---'
$allowed = Join-Path $Pack 'allowed_signers'
$mani = Join-Path $Pack 'core-manifest.txt'
$sig = Join-Path $Pack 'core-manifest.txt.sig'
if ((Test-Path -LiteralPath $allowed) -and (Test-Path -LiteralPath $mani) -and (Test-Path -LiteralPath $sig)) {
    Push-Location $Pack
    $v = & cmd /c ('cd /d "' + $Pack + '" && ssh-keygen -Y verify -f allowed_signers -I tally-author@SageTong -n file -s core-manifest.txt.sig < core-manifest.txt 2>&1')
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -eq 0) {
        OK '核心签名验签通过'
    } else {
        WARN ('核心签名验签未通过（退出码 ' + $code + '）。若你改过 core\ 下的文件，属预期；否则请核对来源')
    }
} else {
    WARN '签名三件套不全，跳过（不影响读取与写入）'
}

# ---------------------------------------------------------------- 小结
Write-Host ''
Write-Host '================================================================'
Write-Host ('  通过 ' + $pass + '   注意 ' + $warn + '   失败 ' + $fail)
Write-Host '================================================================'
if ($fail -eq 0) {
    Write-Host '  这个包在你的机器上可以使用。' -ForegroundColor Green
    Write-Host ''

    # 写回建议要按包的形态给，不能一律说 contributed：
    #   · 本机工作母版（有 local 数据）→ 默认写 local（本机私有层，正确默认）
    #   · 对外发行版（无 local 数据）  → 外部经验应写 contributed（隔离区）
    $hasLocalData = $false
    $localProbe = Join-Path $Pack '20-历史经验\data\local'
    if (Test-Path -LiteralPath $localProbe) {
        foreach ($t in @('facts', 'lessons', 'decisions', 'timeline')) {
            $pf = Join-Path $localProbe ($t + '.jsonl')
            if (Test-Path -LiteralPath $pf) {
                if (@(Get-Content -LiteralPath $pf -Encoding UTF8 | Where-Object { $_.Trim() }).Count -gt 0) { $hasLocalData = $true }
            }
        }
    }
    if ($hasLocalData) {
        $nsHint = '（本机工作母版：不加 -Namespace 即写 local，这是正确的默认）'
        $nsArg  = ''
    } else {
        $nsHint = '（对外发行版：外部经验请指定 -Namespace contributed 进隔离区）'
        $nsArg  = ' -Namespace contributed'
    }

    Write-Host '  下一步（从最轻的开始）:'
    Write-Host '    Get-Content ''.\20-历史经验\data\INDEX.md''        # 先扫一眼标题'
    Write-Host '    cd .\30-工具 ; .\memory.ps1 search <关键词>        # 按需检索'
    Write-Host ('    cd .\30-工具 ; .\memory.ps1 add-lesson ...' + $nsArg + '   # 写回经验')
    Write-Host ('      ' + $nsHint)
    exit 0
} else {
    Write-Host '  有失败项，请先按上面的提示处理。' -ForegroundColor Red
    exit 1
}
