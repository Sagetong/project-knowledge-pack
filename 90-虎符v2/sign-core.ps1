# sign-core.ps1 —— 虎符 v2 签名工具（仅作者使用）
# 用途: 对核心清单签名，发布给使用者验签
# 建立者: DSH   时间: 2026-10-07
#
# ⚠ 安全警告:
#   本脚本需要私钥。私钥必须:
#     · 离线保存，绝不提交到 Git
#     · 设置口令（正式使用）
#     · 与经验包物理分离存放
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File sign-core.ps1 -PrivateKey <私钥路径>

param(
    [Parameter(Mandatory=$true)][string]$PrivateKey,
    [string]$PackRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$SignerIdentity = 'tally-author@SageTong'
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path $PrivateKey)) { Write-Output ("找不到私钥: " + $PrivateKey); exit 2 }
if ($PrivateKey -match [regex]::Escape($PackRoot)) {
    Write-Output '⚠ 检测到私钥位于经验包目录内 —— 这非常危险，请移到包外。'
    Write-Output '   已中止。'
    exit 3
}

Write-Output '=== 虎符 v2 · 核心签名 ==='
Write-Output ''

# 1) 生成核心清单
$coreDirs = @('core', '00-底层逻辑', '30-工具')
$sha = [System.Security.Cryptography.SHA256]::Create()
$lines = New-Object System.Collections.ArrayList
[void]$lines.Add('# core-manifest.txt —— 核心层文件清单（路径与 SHA256）')
[void]$lines.Add('# 由 sign-core.ps1 生成，作者签名后发布')
[void]$lines.Add('# 验证方式见 90-虎符v2/README.md')
[void]$lines.Add('')

$count = 0
foreach ($d in $coreDirs) {
    $full = Join-Path $PackRoot $d
    if (-not (Test-Path $full)) { continue }
    Get-ChildItem $full -Recurse -File | Sort-Object FullName | ForEach-Object {
        $rel = $_.FullName.Substring($PackRoot.Length).TrimStart('\')
        $fs = [System.IO.File]::OpenRead($_.FullName)
        $h = $sha.ComputeHash($fs); $fs.Close()
        $hex = ($h | ForEach-Object { $_.ToString('x2') }) -join ''
        [void]$lines.Add($rel + '  ' + $hex)
        $count++
    }
}
$sha.Dispose()

$manifest = Join-Path $PackRoot 'core-manifest.txt'
[System.IO.File]::WriteAllText($manifest, (($lines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Output ('[1/3] 已生成清单: ' + $count + ' 个核心文件')

# 2) 签名
$sig = "$manifest.sig"
Remove-Item $sig -Force -EA SilentlyContinue
$out = & cmd.exe /c "ssh-keygen -Y sign -f `"$PrivateKey`" -n file `"$manifest`" 2>&1"
if (-not (Test-Path $sig)) {
    Write-Output '[2/3] 签名失败:'
    $out | ForEach-Object { Write-Output ('  ' + $_) }
    exit 4
}
Write-Output ('[2/3] 已签名: ' + (Get-Item $sig).Length + ' 字节')

# 3) 生成/更新 allowed_signers
$pub = "$PrivateKey.pub"
if (Test-Path $pub) {
    $signers = Join-Path $PackRoot 'allowed_signers'
    $pubText = (Get-Content $pub -Raw).Trim()
    [System.IO.File]::WriteAllText($signers, ($SignerIdentity + ' ' + $pubText + "`r`n"), (New-Object System.Text.ASCIIEncoding))
    $fp = & ssh-keygen -lf $pub 2>&1
    Write-Output ('[3/3] 已更新 allowed_signers')
    Write-Output ('      公钥指纹: ' + ($fp -join ' '))
}

Write-Output ''
Write-Output '=== 完成 ==='
Write-Output '  发布前请确认:'
Write-Output '    1. 私钥不在经验包目录内'
Write-Output '    2. .gitignore 已排除私钥'
Write-Output '    3. core-manifest.txt / .sig / allowed_signers 三件套齐全'