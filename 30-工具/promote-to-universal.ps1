# promote-to-universal.ps1 —— 把可共享的经验从 local 提升到 universal
# 建立者: DSH   时间: 2026-10-07
#
# 设计原则:
#   · 采用「复制 + 标注来源」而不是「移动」—— local/ 里的原条目保留不动
#   · 默认只做试运行；必须显式加 -Execute 才真正写入
#   · 逐条判定，判定依据写入条目本身，事后可复核
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File promote-to-universal.ps1                    # 试运行，全部类型
#   powershell -ExecutionPolicy Bypass -File promote-to-universal.ps1 -Kind lessons      # 只看 lessons
#   powershell -ExecutionPolicy Bypass -File promote-to-universal.ps1 -Kind lessons -Execute

param(
    [string]$PackRoot = (Split-Path $PSScriptRoot -Parent),
    [ValidateSet('lessons','facts','decisions','timeline','all')]
    [string]$Kind = 'lessons',
    [int]$Sample = 15,
    [switch]$Execute
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$noBom = New-Object System.Text.UTF8Encoding($false)

# ── 本机专属特征：命中任意一条 → 留在 local ──
$LocalPatterns = @(
    @{ p = 'C:\\Users\\';                      d = '本机绝对路径' },
    @{ p = 'C:/Users/';                        d = '本机绝对路径' },
    @{ p = '<用户名>';                    d = '用户名' },
    @{ p = '\b192\.168\.\d+\.\d+\b';           d = '内网IP' },
    @{ p = '\b10\.\d+\.\d+\.\d+\b';            d = '内网IP' },
    @{ p = 'e16948b7|01a11432|01a113ff';       d = '账号或会话ID' },
    @{ p = 'srv_e_|env_e_|7cec5810';           d = '注册ID' },
    @{ p = 'CMCC|192\.168\.10\.';              d = 'WiFi或网段' },
    @{ p = 'msyh\.ttc|C:\\Windows\\Fonts';     d = '本机字体路径' },
    @{ p = 'DeepSeek Harness\.exe|QianwenApp'; d = '本机程序路径' }
)

function Test-Shareable([string]$blob) {
    foreach ($lp in $LocalPatterns) {
        if ($blob -match $lp.p) { return @{ ok = $false; why = $lp.d } }
    }
    return @{ ok = $true; why = '' }
}

$kinds = if ($Kind -eq 'all') { @('lessons','facts','decisions','timeline') } else { @($Kind) }

Write-Host ''
Write-Host '=== 经验提升：local -> universal ===' -ForegroundColor Cyan
Write-Host ("  经验包: " + $PackRoot)
Write-Host ("  类型  : " + ($kinds -join ', '))
Write-Host ("  模式  : " + $(if ($Execute) { '★ 正式执行（会写入）' } else { '试运行（不改文件）' }))
Write-Host ''

if (-not (Test-Path $PackRoot)) { Write-Host '[失败] 找不到经验包' -ForegroundColor Red; exit 2 }

foreach ($k in $kinds) {
    $srcFile = Join-Path $PackRoot ("20-历史经验\data\local\" + $k + ".jsonl")
    $dstFile = Join-Path $PackRoot ("20-历史经验\data\universal\" + $k + ".jsonl")

    Write-Host ("── " + $k + " ──") -ForegroundColor Yellow
    if (-not (Test-Path $srcFile)) { Write-Host '   源文件不存在，跳过'; continue }

    $srcLines = Get-Content $srcFile -Encoding UTF8 | Where-Object { $_.Trim() }
    $dstLines = @()
    if (Test-Path $dstFile) { $dstLines = Get-Content $dstFile -Encoding UTF8 | Where-Object { $_.Trim() } }

    # 已存在的 id（避免重复提升）
    $existingIds = @{}
    foreach ($l in $dstLines) {
        try { $o = $l | ConvertFrom-Json; if ($o.id) { $existingIds[$o.id] = 1 } } catch {}
    }

    $promote = New-Object System.Collections.ArrayList
    $keep = 0
    $skip = 0
    $reasons = @{}

    foreach ($l in $srcLines) {
        $obj = $null
        try { $obj = $l | ConvertFrom-Json } catch { continue }
        if (-not $obj) { continue }

        if ($obj.id -and $existingIds.ContainsKey($obj.id)) { $skip++; continue }

        $r = Test-Shareable $l
        if ($r.ok) {
            [void]$promote.Add($obj)
        } else {
            $keep++
            if (-not $reasons.ContainsKey($r.why)) { $reasons[$r.why] = 0 }
            $reasons[$r.why]++
        }
    }

    Write-Host ("   源 " + $srcLines.Count + " 条   已在 universal " + $existingIds.Count + " 条")
    Write-Host ("   ⇒ 可提升 " + $promote.Count + " 条") -ForegroundColor Green
    Write-Host ("   ⇒ 留在 local " + $keep + " 条")
    if ($skip -gt 0) { Write-Host ("   ⇒ 已存在跳过 " + $skip + " 条") }
    if ($reasons.Count -gt 0) {
        Write-Host '   留在 local 的原因分布:'
        foreach ($rk in $reasons.Keys) { Write-Host ("      " + $rk + "  " + $reasons[$rk] + " 条") }
    }

    # 样例
    if ($promote.Count -gt 0 -and $Sample -gt 0) {
        Write-Host '   待提升样例:'
        $field = switch ($k) { 'lessons' {'title'} 'facts' {'claim'} 'decisions' {'question'} 'timeline' {'event'} }
        $promote | Select-Object -First $Sample | ForEach-Object {
            $v = $_.$field
            if ($v) { Write-Host ("      · " + $v.Substring(0, [Math]::Min(64, $v.Length))) }
        }
    }

    # 写入
    if ($Execute -and $promote.Count -gt 0) {
        $stamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
        $out = New-Object System.Collections.ArrayList
        # 原有内容保留
        foreach ($l in $dstLines) { [void]$out.Add($l) }
        # 新增（加来源标注）
        foreach ($o in $promote) {
            $o | Add-Member -NotePropertyName 'origin'    -NotePropertyValue 'local'      -Force
            $o | Add-Member -NotePropertyName 'promoted_at' -NotePropertyValue $stamp    -Force
            $o | Add-Member -NotePropertyName 'promote_rule' -NotePropertyValue 'no-local-fingerprint' -Force
            [void]$out.Add(($o | ConvertTo-Json -Compress -Depth 6))
        }
        $dir = Split-Path $dstFile -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        [System.IO.File]::WriteAllText($dstFile, (($out -join "`r`n") + "`r`n"), $noBom)
        Write-Host ("   ✅ 已写入 " + $dstFile.Replace($PackRoot,'') + "  共 " + $out.Count + " 条") -ForegroundColor Green
        Write-Host ("      注意: local/ 里的原条目【未删除】，仍保留")
    } elseif ($promote.Count -gt 0) {
        Write-Host '   （试运行，未写入。加 -Execute 才真正执行）' -ForegroundColor DarkGray
    }
    Write-Host ''
}

Write-Host '=== 结束 ==='
if (-not $Execute) {
    Write-Host '  本次未改动任何文件。确认无误后加 -Execute 重新运行。' -ForegroundColor Yellow
}
