# release-gate.ps1 —— 发行版发布门禁：证明脱敏没有削弱「别人的 AI 能读、能写」
#
# 建立者: DSH   时间: 2026-10-08
#
# 为什么要有它:
#   四个独立模型在圆桌会议上 4/4 收敛指向同一件事 —— 建一个发行版能力回归验收。
#   原话摘录:
#     · "只说『脱敏不碰工具』不够。这才叫不削弱读写能力。"
#     · 验收标准只有一句: 从发行版隔离 clone 开始、不看本机上下文，
#       AI 能找到入口、能检索 universal 经验、能追加一条经验、能重建索引、selfcheck 全通过。
#
# 它做什么:
#   把发行版复制到临时目录，模拟「别人 clone 到自己的电脑」，
#   然后在那里真跑一遍：发现入口 → 读取 → 写入 → 重建索引 → 自检 → 隐私扫描 → 签名。
#   任何一项失败 = 拒绝发布。
#
# 安全承诺:
#   · 全程【只读真实发行版】；所有写入测试都在临时副本里做
#   · 不改动、不删除发行版的任何文件
#   · 结束时清理临时目录（-KeepTemp 可保留以便排查）
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File release-gate.ps1 -ReleasePack <发行版路径>
#   powershell -ExecutionPolicy Bypass -File release-gate.ps1 -ReleasePack <发行版路径> -MasterPack <母版路径>
#   powershell -ExecutionPolicy Bypass -File release-gate.ps1 -ReleasePack <发行版路径> -KeepTemp
#
# 退出码: 0 = 门禁通过（可发布）   1 = 有失败项（不可发布）   2 = 参数/环境错误

param(
    [Parameter(Mandatory = $true)][string]$ReleasePack,
    [string]$MasterPack = '',
    # 门禁报告写到哪里。默认写在发行版同级目录 —— 隔离目录随后会被清理，
    # 报告必须留在外面才有用，而且文件是 UTF-8 无 BOM，不受控制台代码页影响。
    [string]$ReportPath = '',
    [switch]$KeepTemp,
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------------- 计数器
$script:pass = 0
$script:warn = 0
$script:fail = 0
$script:details = New-Object System.Collections.ArrayList

function Say($m) { if (-not $Quiet) { Write-Host $m } }
function Group($t) { Say ''; Say ('── ' + $t + ' ' + ('─' * [Math]::Max(0, 60 - $t.Length))) }
function OK($m)   { Say ('  [通过] ' + $m); $script:pass++; [void]$script:details.Add('PASS  ' + $m) }
function WARN($m) { Say ('  [注意] ' + $m); $script:warn++; [void]$script:details.Add('WARN  ' + $m) }
function BAD($m)  { Say ('  [失败] ' + $m); $script:fail++; [void]$script:details.Add('FAIL  ' + $m) }

# ---------------------------------------------------------------- 前置检查
if (-not (Test-Path -LiteralPath $ReleasePack)) { Write-Host ('[错误] 找不到发行版: ' + $ReleasePack); exit 2 }
$ReleasePack = (Resolve-Path -LiteralPath $ReleasePack).Path

Say ''
Say '================================================================'
Say '  发行版发布门禁 (release-gate)'
Say '================================================================'
Say ('  发行版: ' + $ReleasePack)
if ($MasterPack) { Say ('  工作母版: ' + $MasterPack) }
Say ''

# ---------------------------------------------------------------- 建临时 clone
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('pack-gate-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$clone = Join-Path $tempRoot 'experience-pack'
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    # 用 robocopy 做完整镜像（排除 .git，模拟用户拿到的内容而非仓库历史）
    $null = robocopy $ReleasePack $clone /MIR /XD '.git' /NFL /NDL /NJH /NJS /NP
    Say ('  [准备] 已把发行版复制到隔离目录: ' + $clone)
} catch {
    Write-Host ('[错误] 复制失败: ' + $_.Exception.Message)
    exit 2
}

$toolDir = Join-Path $clone '30-工具'
$mem     = Join-Path $toolDir 'memory.ps1'
$idxTool = Join-Path $toolDir 'build-index.ps1'
$selfT   = Join-Path $toolDir 'selfcheck.ps1'
$idxFile = Join-Path $clone '20-历史经验\data\INDEX.md'

function RunTool([string]$script, [string[]]$arguments) {
    # 用 -Command 传参，避免 -File 的数组/引号解析问题（见经验 l150 等）
    $argLine = ''
    if ($arguments -and $arguments.Count -gt 0) { $argLine = ' ' + ($arguments -join ' ') }
    $cmd = '& ' + "'" + $script + "'" + $argLine
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>&1
    return ,@($out)
}

# ================================================================ 1 发现入口
Group '1. 发现入口（别人的 AI 能不能知道它存在）'
$entryFiles = [ordered]@{
    'AGENTS.md'                        = '跨工具标准入口（会话开始时自动加载）'
    'CLAUDE.md'                        = 'Claude Code 兼容入口'
    '.github\copilot-instructions.md'  = 'GitHub Copilot 兼容入口'
    'README.md'                        = '给人看的说明'
}
foreach ($kv in $entryFiles.GetEnumerator()) {
    $p = Join-Path $clone $kv.Key
    if (Test-Path -LiteralPath $p) { OK ($kv.Key + ' 存在  — ' + $kv.Value) }
    else { BAD ($kv.Key + ' 缺失  — ' + $kv.Value) }
}

$agentsPath = Join-Path $clone 'AGENTS.md'
if (Test-Path -LiteralPath $agentsPath) {
    $agentsText = [System.IO.File]::ReadAllText($agentsPath, [System.Text.Encoding]::UTF8)
    if ($agentsText -match '第 0 档') { OK 'AGENTS.md 含三档门槛（第 0 档扫标题）' } else { BAD 'AGENTS.md 缺少三档门槛说明' }
    if ($agentsText -match 'INDEX\.md') { OK 'AGENTS.md 指明了标题索引的位置' } else { BAD 'AGENTS.md 没有指向 INDEX.md' }
    if ($agentsText -match 'add-lesson') { OK 'AGENTS.md 含写入示例' } else { BAD 'AGENTS.md 没有写入示例' }
    if ($agentsText -match '自检|selfcheck') { OK 'AGENTS.md 提到自检' } else { WARN 'AGENTS.md 未提到自检（建议补）' }
}

if (Test-Path -LiteralPath $idxFile) {
    $idxLines = @(Get-Content -LiteralPath $idxFile -Encoding UTF8)
    $idxRows = @($idxLines | Where-Object { $_ -match '^\| [fldt]\d' })
    if ($idxRows.Count -ge 10) { OK ('INDEX.md 存在，含 ' + $idxRows.Count + ' 条标题') }
    else { WARN ('INDEX.md 存在但条目很少（' + $idxRows.Count + ' 条）') }
} else { BAD 'INDEX.md 缺失 —— AI 无法「先扫一眼标题」' }

# ================================================================ 2 读取能力
Group '2. 读取能力（在隔离 clone 里真跑一遍）'
if (-not (Test-Path -LiteralPath $mem)) {
    BAD 'memory.ps1 缺失 —— 读取与写入能力全部失效'
} else {
    OK 'memory.ps1 就位'
    foreach ($c in @('summary', 'search 经验', 'lessons', 'timeline', 'decisions')) {
        $o = RunTool $mem @($c)
        $len = ($o -join '').Length
        if ($len -gt 20) { OK ('memory.ps1 ' + $c + ' 有输出（' + $len + ' 字符）') }
        else { BAD ('memory.ps1 ' + $c + ' 输出为空') }
    }
    # 深度检索（体积大，只验能否运行）
    $o = RunTool $mem @('context')
    if (($o -join '').Length -gt 200) { OK 'memory.ps1 context 可运行（深度检索路径通）' }
    else { BAD 'memory.ps1 context 无法运行' }
}

# ================================================================ 3 写入能力
Group '3. 写入能力（写进临时副本，绝不动真实发行版）'
if (Test-Path -LiteralPath $mem) {
    # 判断该往哪一层写：有 local 数据=母版形态；无 local 数据=发行版形态
    $localDir = Join-Path $clone '20-历史经验\data\local'
    $hasLocalData = $false
    if (Test-Path -LiteralPath $localDir) {
        foreach ($t in @('facts', 'lessons', 'decisions', 'timeline')) {
            $pf = Join-Path $localDir ($t + '.jsonl')
            if (Test-Path -LiteralPath $pf) {
                if (@(Get-Content -LiteralPath $pf -Encoding UTF8 | Where-Object { $_.Trim() }).Count -gt 0) { $hasLocalData = $true }
            }
        }
    }
    $targetNs = if ($hasLocalData) { 'local' } else { 'contributed' }
    Say ('  [说明] 本包写入目标层判定为: ' + $targetNs)

    $stampTxt = 'release-gate-' + (Get-Date -Format 'HHmmss')

    $o1 = RunTool $mem @('add-fact', '-Claim', ('"' + $stampTxt + '"'), '-Status', 'unverified', '-Evidence', '"gate test"', '-Namespace', $targetNs)
    $o2 = RunTool $mem @('add-lesson', '-Title', ('"' + $stampTxt + '"'), '-Kind', 'technique', '-Namespace', $targetNs)
    $o3 = RunTool $mem @('add-decision', '-Question', '"gate"', '-Chosen', '"a"', '-Rejected', '"b"', '-Reason', '"c"', '-Namespace', $targetNs)
    $o4 = RunTool $mem @('add-event', '-Event', ('"' + $stampTxt + '"'), '-Detail', '"gate"', '-Actor', 'GATE', '-Namespace', $targetNs)

    foreach ($pair in @(@{ n = 'add-fact'; o = $o1 }, @{ n = 'add-lesson'; o = $o2 },
                        @{ n = 'add-decision'; o = $o3 }, @{ n = 'add-event'; o = $o4 })) {
        if (($pair.o -join '') -match '已追加') { OK ($pair.n + ' 成功且提示正确') }
        else { BAD ($pair.n + ' 未成功：' + (($pair.o -join ' ').Trim())) }
    }

    # 落点核对：必须在目标层，且不能写进别的层
    $nsDir = Join-Path $clone ('20-历史经验\data\' + $targetNs)
    $landed = 0
    foreach ($t in @('facts', 'lessons', 'decisions', 'timeline')) {
        $pf = Join-Path $nsDir ($t + '.jsonl')
        if (Test-Path -LiteralPath $pf) {
            $rows = @(Get-Content -LiteralPath $pf -Encoding UTF8 | Where-Object { $_.Trim() })
            foreach ($r in $rows) {
                if ($r -match [regex]::Escape($stampTxt) -or $r -match 'gate test' -or $r -match '"gate"') { $landed++ }
            }
        }
    }
    if ($landed -ge 4) { OK ('四条测试记录全部落在 ' + $targetNs + ' 层（共匹配 ' + $landed + ' 条）') }
    elseif ($landed -gt 0) { WARN ('只匹配到 ' + $landed + ' 条测试记录（期望 4 条）') }
    else { BAD '测试记录没有落到 ' + $targetNs + ' 层 —— 写入能力有问题' }

    # 逐行 JSONL 合法性（只查被写过的文件）
    foreach ($t in @('facts', 'lessons', 'decisions', 'timeline')) {
        $pf = Join-Path $nsDir ($t + '.jsonl')
        if (-not (Test-Path -LiteralPath $pf)) { continue }
        $badLines = @()
        $ln = 0
        foreach ($line in [System.IO.File]::ReadAllLines($pf, [System.Text.Encoding]::UTF8)) {
            $ln++
            if (-not $line.Trim()) { continue }
            try { $null = $line | ConvertFrom-Json } catch { $badLines += $ln }
        }
        if (@($badLines).Count -eq 0) { OK ($targetNs + '\' + $t + '.jsonl 逐行合法') }
        else { BAD ($targetNs + '\' + $t + '.jsonl 第 ' + ($badLines -join ',') + ' 行非法') }
    }

    # 确认没写到包外（memory.ps1 是否只用相对路径）
    $memText = [System.IO.File]::ReadAllText($mem, [System.Text.Encoding]::UTF8)
    if ($memText -match 'C:\\Users\\<用户名>' -or $memText -match 'E:\\deepseek') {
        BAD 'memory.ps1 里含作者机器的绝对路径 —— 别人 clone 后会写错地方'
    } else {
        OK 'memory.ps1 不含作者机器绝对路径（可移植）'
    }
} else { BAD 'memory.ps1 缺失，无法测试写入' }

# ================================================================ 4 结构 + 索引 + 自检
Group '4. 结构与索引'
foreach ($ns in @('local', 'universal', 'contributed')) {
    $d = Join-Path $clone ('20-历史经验\data\' + $ns)
    if (Test-Path -LiteralPath $d) { OK ('命名空间目录存在: ' + $ns) }
    else { BAD ('命名空间目录缺失: ' + $ns + ' —— 写入能力受限') }
}
foreach ($t in @('facts', 'lessons', 'decisions', 'timeline')) {
    $found = $false
    foreach ($ns in @('local', 'universal', 'contributed')) {
        if (Test-Path -LiteralPath (Join-Path $clone ('20-历史经验\data\' + $ns + '\' + $t + '.jsonl'))) { $found = $true }
    }
    if ($found) { OK ('数据文件存在: ' + $t + '.jsonl') } else { BAD ('四类数据文件全缺: ' + $t + '.jsonl') }
}

if (Test-Path -LiteralPath $idxTool) {
    $before = if (Test-Path -LiteralPath $idxFile) { (Get-Item -LiteralPath $idxFile).Length } else { 0 }
    $o = RunTool $idxTool @()
    if ((Test-Path -LiteralPath $idxFile) -and (Get-Item -LiteralPath $idxFile).Length -gt 0) {
        OK ('build-index.ps1 可重建 INDEX.md（' + $before + ' → ' + (Get-Item -LiteralPath $idxFile).Length + ' 字节）')
    } else { BAD 'build-index.ps1 无法重建 INDEX.md' }
} else { BAD 'build-index.ps1 缺失 —— 索引无法重建' }

if (Test-Path -LiteralPath $selfT) {
    $o = RunTool $selfT @()
    $joined = $o -join "`n"
    $m = [regex]::Match($joined, '通过 (\d+)\s+注意 (\d+)\s+失败 (\d+)')
    if ($m.Success) {
        $f = [int]$m.Groups[3].Value
        if ($f -eq 0) { OK ('selfcheck.ps1 通过（' + $m.Groups[1].Value + ' 通过 / ' + $m.Groups[2].Value + ' 注意 / 0 失败）') }
        else { BAD ('selfcheck.ps1 有 ' + $f + ' 项失败') }
    } else { WARN 'selfcheck.ps1 输出无法解析（建议检查）' }
} else { BAD 'selfcheck.ps1 缺失 —— 用户无法一条命令验证包可用' }

# ================================================================ 5 隐私 + 签名 + 漂移
Group '5. 隐私、签名与结构漂移'
$privacyHits = New-Object System.Collections.ArrayList
$patterns = @(
    @{ n = '作者主目录'; p = 'C:\\Users\\<用户名>' },
    @{ n = '真实项目盘'; p = 'E:\\deepseek' },
    @{ n = '私钥文件名'; p = 'sagetong_ed25519' },
    @{ n = '实例 ID';    p = '<服务器实例ID>' },
    @{ n = '公网 IP';    p = '47\.79\.39\.225' },
    @{ n = '家庭宽带 IP'; p = '39\.187\.237\.19' }
)

# 两处必须排除，否则会造成【假阳性】——这是本门禁第一次运行时自己抓出来的问题:
#   ① 本门禁脚本自身：它必须写着上面这些模式才能扫描，所以必然命中自己。
#   ② 被 .gitignore 排除的文件（如生成的 CONTEXT.md、本机层数据）：
#      它们不会被发布，扫它们等于对不存在的问题报警。
# 判据是"实际会不会被发布"，而不是"目录里有没有"。
$selfName = 'release-gate.ps1'

# 优先用 git 判断哪些文件会被忽略（最准确）；没有 git 就退回已知清单
$ignored = @{}
$hasGit = $false
Push-Location $clone
try {
    $null = & git rev-parse --is-inside-work-tree 2>&1
    if ($LASTEXITCODE -eq 0) { $hasGit = $true }
} catch { }
Pop-Location

if ($hasGit) {
    Push-Location $clone
    # 列出所有被忽略的文件（相对路径）
    $ig = & git ls-files --others --ignored --exclude-standard 2>&1
    Pop-Location
    foreach ($line in $ig) {
        $t = "$line".Trim()
        if ($t) { $ignored[$t -replace '/', '\'] = $true }
    }
    Say ('  [说明] 检测到 git 仓库；隐私扫描将排除 ' + $ignored.Count + ' 个被 .gitignore 忽略的文件')
} else {
    # 退化方案：按已知的忽略清单排除
    foreach ($t in @(
            '20-历史经验\data\CONTEXT.md',
            '20-历史经验\STATE.md',
            '20-历史经验\LESSONS.md'
        )) { $ignored[$t] = $true }
    Say '  [说明] 未检测到 git 仓库；隐私扫描按已知忽略清单排除生成物与本机层文件'
}

$scanned = 0
$skipped = 0
Get-ChildItem -LiteralPath $clone -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.md', '.json', '.jsonl', '.ps1', '.txt', '.cmd') -and $_.FullName -notmatch '\\\.git\\' } |
    ForEach-Object {
        $rel = $_.FullName.Substring($clone.Length).TrimStart('\')

        # 排除本门禁脚本自身
        if ($_.Name -eq $selfName) { $script:skipped++; return }
        # 排除被忽略的文件（不会被发布）
        if ($ignored.ContainsKey($rel)) { $script:skipped++; return }

        $scanned++
        $txt = ''
        try { $txt = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8) } catch { return }
        foreach ($pt in $patterns) {
            if ($txt -match $pt.p) {
                [void]$privacyHits.Add($pt.n + ' → ' + $rel)
            }
        }
    }
Say ('  [说明] 实际扫描 ' + $scanned + ' 个文件，跳过 ' + $skipped + ' 个（本门禁自身 + 不会发布的内容）')
if ($privacyHits.Count -eq 0) { OK ('隐私扫描通过（检查了 ' + $scanned + ' 个会被发布的文本文件）') }
else {
    BAD ('隐私扫描发现 ' + $privacyHits.Count + ' 处命中:')
    $privacyHits | Select-Object -First 10 | ForEach-Object { Say ('         ' + $_) }
}

# 签名
$allowed = Join-Path $clone 'allowed_signers'
$mani    = Join-Path $clone 'core-manifest.txt'
$sig     = Join-Path $clone 'core-manifest.txt.sig'
if ((Test-Path -LiteralPath $allowed) -and (Test-Path -LiteralPath $mani) -and (Test-Path -LiteralPath $sig)) {
    Push-Location $clone
    $v = & cmd /c ('ssh-keygen -Y verify -f allowed_signers -I tally-author@SageTong -n file -s core-manifest.txt.sig < core-manifest.txt 2>&1')
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -eq 0) { OK '核心签名验证通过' }
    else { BAD ('核心签名验证失败（退出码 ' + $code + '）—— 若刚改过 core\ 下的文件，需重新签名') }
} else { WARN '签名三件套不全（若本包不设签名，属正常）' }

$sec = Join-Path $clone 'core\security.json'
if (Test-Path -LiteralPath $sec) {
    $secTxt = [System.IO.File]::ReadAllText($sec, [System.Text.Encoding]::UTF8)
    if ($secTxt -match 'signatureBoundary') { OK 'core\security.json 声明了签名保护边界' }
    else { WARN 'core\security.json 未声明签名保护边界（使用者会误以为数据也被签名保护）' }

    # DEMO 检查要区分两种情况，否则会误报（本门禁第一次跑时就误报过）:
    #   ① 【危险】：把 DEMO 密钥的指纹当成正式指纹声明出去（历史上真的发生过）
    #   ② 【正常】：在"历史更正"说明里提到 DEMO 值，用来告诉读者"以前写错过"
    # 判据：看 DEMO 字样附近有没有"更正/废弃/历史/曾/已替换"这类词。
    if ($secTxt -match 'DemoFingerprint|publicKeyFingerprintDemo') {
        BAD 'core\security.json 里仍有 publicKeyFingerprintDemo 之类的【字段名】—— 这是把 DEMO 值当正式值声明的痕迹'
    } elseif ($secTxt -match 'DEMO') {
        # 进一步看语境：是"当正式值用"还是"当历史更正提"
        $isCorrection = ($secTxt -match '(更正|废弃|历史|曾经|已替换|以正式|错误地|原先|旧值)[^"]{0,80}DEMO') -or
                        ($secTxt -match 'DEMO[^"]{0,80}(更正|废弃|历史|曾经|已替换|错误地|原先|旧值)')
        if ($isCorrection) { OK 'core\security.json 里的 DEMO 字样出现在【历史更正】语境中（正常，是刻意保留以免后人重犯）' }
        else { WARN 'core\security.json 提到 DEMO 但看不出是历史更正语境，建议人工核对是否误把 DEMO 值当正式值' }
    } else { OK 'core\security.json 无 DEMO 字样' }
}

# 与母版的结构漂移
if ($MasterPack -and (Test-Path -LiteralPath $MasterPack)) {
    $mp = (Resolve-Path -LiteralPath $MasterPack).Path
    $masterFiles = @{}
    Get-ChildItem -LiteralPath $mp -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\\.git\\' } | ForEach-Object {
            $masterFiles[$_.FullName.Substring($mp.Length).TrimStart('\')] = $true
        }
    $cloneFiles = @{}
    Get-ChildItem -LiteralPath $clone -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\\.git\\' } | ForEach-Object {
            $cloneFiles[$_.FullName.Substring($clone.Length).TrimStart('\')] = $true
        }
    $onlyMaster = @($masterFiles.Keys | Where-Object { -not $cloneFiles.ContainsKey($_) })
    $onlyClone  = @($cloneFiles.Keys  | Where-Object { -not $masterFiles.ContainsKey($_) })
    Say ('  [漂移] 只在母版有的文件: ' + $onlyMaster.Count + ' 个；只在发行版有的: ' + $onlyClone.Count + ' 个')
    if ($onlyClone.Count -gt 0) {
        WARN ('发行版有母版没有的文件（应出现在声明的脱敏/新增清单里）:')
        $onlyClone | Select-Object -First 10 | ForEach-Object { Say ('         ' + $_) }
    }
    # 关键工具必须两边都有
    foreach ($k in @('30-工具\memory.ps1', '30-工具\selfcheck.ps1', '30-工具\build-index.ps1', 'AGENTS.md', '20-历史经验\data\INDEX.md')) {
        if ($cloneFiles.ContainsKey($k)) { OK ('关键文件在发行版中存在: ' + $k) }
        else { BAD ('关键文件在发行版中缺失: ' + $k) }
    }
} else {
    Say '  [漂移] 未提供 -MasterPack，跳过结构对比'
}

# ================================================================ 收尾
$overall = if ($script:fail -eq 0) { 'PASS' } else { 'FAIL' }

Say ''
Say '================================================================'
Say ('  通过 ' + $script:pass + '   注意 ' + $script:warn + '   失败 ' + $script:fail)
Say '================================================================'

# 五项能力结论
Say ''
Say '  五项能力判定:'
Say ('    发现入口  ' + $(if ($script:details -match '^FAIL.*AGENTS\.md 缺失' -or $script:details -match '^FAIL.*INDEX\.md 缺失') { '✗ 不通过' } else { '✓ 通过' }))
Say ('    读取能力  ' + $(if ($script:details -match '^FAIL.*memory\.ps1') { '✗ 不通过' } else { '✓ 通过' }))
Say ('    写入能力  ' + $(if ($script:details -match '^FAIL.*(未成功|没有落到|非法)') { '✗ 不通过' } else { '✓ 通过' }))
Say ('    隐私脱敏  ' + $(if ($script:details -match '^FAIL.*隐私扫描发现') { '✗ 不通过' } else { '✓ 通过' }))
Say ('    签名完整  ' + $(if ($script:details -match '^FAIL.*签名验证失败') { '✗ 不通过' } else { '✓ 通过' }))
Say ''

if ($overall -eq 'PASS') {
    Say '  ⇒ 门禁通过：这个发行版具备「别人的 AI 能发现、能读、能写」的能力。' 
    Say '     依据圆桌 4/4 收敛的验收标准：从隔离 clone 开始、不看本机上下文，'
    Say '     AI 能找到入口、能检索、能追加经验、能重建索引、selfcheck 全通过。'
} else {
    Say '  ⇒ 门禁失败：不要发布。上面标 [失败] 的项必须先修好。'
}

# 写一份门禁报告。
# 报告【写在隔离目录之外】（默认放发行版同级目录），原因有两条：
#   ① 隔离目录随后会被清理，报告要保留才有用；
#   ② 控制台输出会受代码页影响（中文可能乱码），而报告文件是 UTF-8 无 BOM，可靠。
$reportPath = if ($ReportPath) {
    $ReportPath
} else {
    Join-Path (Split-Path $ReleasePack -Parent) ('GATE-REPORT-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.md')
}
try {
    $rep = @()
    $rep += '# 发布门禁报告'
    $rep += ''
    $rep += '- 时间: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $rep += '- 发行版: ' + $ReleasePack
    if ($MasterPack) { $rep += '- 工作母版: ' + $MasterPack }
    $rep += '- 结论: ' + $(if ($overall -eq 'PASS') { 'PASS 通过（可发布）' } else { 'FAIL 失败（不可发布）' })
    $rep += '- 计数: 通过 ' + $script:pass + ' / 注意 ' + $script:warn + ' / 失败 ' + $script:fail
    $rep += ''
    $rep += '## 明细'
    $rep += ''
    foreach ($d in $script:details) { $rep += '- ' + $d }
    [System.IO.File]::WriteAllText($reportPath, ($rep -join [char]13 + [char]10), (New-Object System.Text.UTF8Encoding($false)))
    Say ''
    Say ('  报告已写入: ' + $reportPath)
} catch {
    Say ('  [注意] 报告写入失败: ' + $_.Exception.Message)
}

# 清理
if ($KeepTemp) {
    Say ('  [保留] 隔离目录未删除，可自行查看: ' + $clone)
} else {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Say '  [清理] 隔离目录已删除（真实发行版全程未被修改）'
}
Say ''

if ($overall -eq 'PASS') { exit 0 } else { exit 1 }
