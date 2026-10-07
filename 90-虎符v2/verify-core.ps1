# verify-core.ps1 —— 虎符 v2 验签工具（使用者用）
# 用途: 验证经验包核心层确实出自作者且未被篡改
# 建立者: DSH   时间: 2026-10-07
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File verify-core.ps1
#   powershell -ExecutionPolicy Bypass -File verify-core.ps1 -PackRoot <路径>

param(
    [string]$PackRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$SignerIdentity = 'tally-author@SageTong'
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$manifest = Join-Path $PackRoot 'core-manifest.txt'
$sig      = Join-Path $PackRoot 'core-manifest.txt.sig'
$signers  = Join-Path $PackRoot 'allowed_signers'

Write-Output '=== 虎符 v2 · 核心验签 ==='
Write-Output ("经验包: " + $PackRoot)
Write-Output ("签署者: " + $SignerIdentity)
Write-Output ''

foreach ($f in @($manifest, $sig, $signers)) {
    if (-not (Test-Path $f)) {
        Write-Output ("[失败] 缺少文件: " + (Split-Path $f -Leaf))
        Write-Output '  ⇒ 无法验证来源。请勿使用来源不明的核心层。'
        exit 2
    }
}

# 1) 先按当前实际内容重算哈希，与清单比对（验完整性）
Write-Output '[步骤 1] 校验核心文件哈希'
$sha = [System.Security.Cryptography.SHA256]::Create()
$mismatch = 0; $checked = 0
foreach ($line in [System.IO.File]::ReadAllLines($manifest, [System.Text.Encoding]::UTF8)) {
    $line = $line.Trim()
    if (-not $line -or $line.StartsWith('#')) { continue }
    # 格式: <相对路径>  <sha256>
    $parts = $line -split '\s{2,}'
    if ($parts.Count -lt 2) { continue }
    $rel = $parts[0]; $expect = $parts[1].Trim().ToLower()
    $abs = Join-Path $PackRoot $rel
    if (-not (Test-Path $abs)) {
        Write-Output ("  [缺失] " + $rel)
        $mismatch++; continue
    }
    $fs = [System.IO.File]::OpenRead($abs)
    $h = $sha.ComputeHash($fs); $fs.Close()
    $actual = ($h | ForEach-Object { $_.ToString('x2') }) -join ''
    $checked++
    if ($actual -ne $expect) {
        Write-Output ("  [篡改] " + $rel)
        Write-Output ("         期望 " + $expect.Substring(0,16) + "...")
        Write-Output ("         实际 " + $actual.Substring(0,16) + "...")
        $mismatch++
    }
}
$sha.Dispose()
Write-Output ("  已校验 " + $checked + " 个文件，不一致 " + $mismatch + " 个")
Write-Output ''

# 2) 验签（验来源）
Write-Output '[步骤 2] 校验作者签名'
$out = & cmd.exe /c "ssh-keygen -Y verify -f `"$signers`" -I $SignerIdentity -n file -s `"$sig`" < `"$manifest`" 2>&1"
$code = $LASTEXITCODE
$text = ($out -join ' ').Trim()
Write-Output ("  " + $text)
Write-Output ''

Write-Output '=== 结论 ==='
if ($code -eq 0 -and $mismatch -eq 0) {
    Write-Output '  [通过] 核心层完整且签名有效 —— 可以信任。'
    exit 0
} elseif ($code -eq 0 -and $mismatch -gt 0) {
    Write-Output '  [警告] 签名有效，但核心文件与清单不一致 —— 可能被本地修改过。'
    exit 1
} else {
    Write-Output '  [失败] 签名无效 —— 该核心层并非出自声明的作者，或已被篡改。'
    Write-Output '  ⇒ 请勿使用。'
    exit 3
}