# unlock-dual-key.ps1 —— 虎符 v3 双口令：解锁
# 用途: 输入左符 + 右符，验证两者是否同时正确
# 建立者: DSH   时间: 2026-10-07
#
# 设计要点:
#   · 不存储任何口令
#   · 通过"能否解开验证块"来判断两符是否正确
#   · 任一错误 → 解密失败，无法区分是左符错还是右符错（这是有意的安全设计）
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File unlock-dual-key.ps1
#   powershell -ExecutionPolicy Bypass -File unlock-dual-key.ps1 -ExportKey   # 输出主密钥（谨慎）

param(
    [switch]$ExportKey
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Dir = $PSScriptRoot
$SaltFile = Join-Path $Dir 'dual-key-salt.bin'
$BlobFile = Join-Path $Dir 'dual-key-blob.bin'
$Marker = 'TIGER-TALLY-DUAL-KEY-V1'
$Iterations = 600000

function Read-Secret([string]$prompt) {
    Write-Host $prompt -NoNewline -ForegroundColor Cyan
    $sec = Read-Host -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

Write-Host ''
Write-Host '=== 虎符 v3 · 双口令解锁 ===' -ForegroundColor Yellow
Write-Host ''

foreach ($f in @($SaltFile, $BlobFile)) {
    if (-not (Test-Path $f)) {
        Write-Host ('[失败] 缺少文件: ' + (Split-Path $f -Leaf)) -ForegroundColor Red
        Write-Host '  ⇒ 尚未初始化。请先运行 init-dual-key.ps1'
        exit 2
    }
}

$salt = [System.IO.File]::ReadAllBytes($SaltFile)
$blob = [System.IO.File]::ReadAllBytes($BlobFile)

$left = Read-Secret '  请输入【左符】: '
$left = $left -replace '[^A-Za-z0-9]', ''
$right = Read-Secret '  请输入【右符】: '
Write-Host ''

if ([string]::IsNullOrWhiteSpace($left) -or [string]::IsNullOrWhiteSpace($right)) {
    Write-Host '[失败] 口令不得为空。' -ForegroundColor Red
    exit 3
}

# 派生
$combined = $left + '|' + $right
$kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
    $combined, $salt, $Iterations,
    [System.Security.Cryptography.HashAlgorithmName]::SHA256)
$master = $kdf.GetBytes(32)
$kdf.Dispose()

# 验证块 = IV(16) + 密文
$ivLen = 16
$iv = New-Object byte[] $ivLen
$cipher = New-Object byte[] ($blob.Length - $ivLen)
[Array]::Copy($blob, 0, $iv, 0, $ivLen)
[Array]::Copy($blob, $ivLen, $cipher, 0, $cipher.Length)

$ok = $false
try {
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.KeySize = 256
    $aes.Key = $master
    $aes.IV = $iv
    $dec = $aes.CreateDecryptor()
    $plain = $dec.TransformFinalBlock($cipher, 0, $cipher.Length)
    $dec.Dispose(); $aes.Dispose()
    $text = [System.Text.Encoding]::UTF8.GetString($plain)
    if ($text -eq $Marker) { $ok = $true }
} catch {
    $ok = $false
}

$combined = $null; $right = $null
[System.GC]::Collect()

Write-Host ''
if ($ok) {
    Write-Host '  ╔══════════════════════════════════════════╗' -ForegroundColor Green
    Write-Host '  ║   合符成功 —— 两符均正确                  ║' -ForegroundColor Green
    Write-Host '  ╚══════════════════════════════════════════╝' -ForegroundColor Green
    if ($ExportKey) {
        $hex = ($master | ForEach-Object { $_.ToString('x2') }) -join ''
        Write-Host ''
        Write-Host '  主密钥（16 进制，谨慎使用）:' -ForegroundColor Yellow
        Write-Host ('    ' + $hex)
        Write-Host '  ⚠ 拿到主密钥即可解密隐私层，用完请清除终端记录。' -ForegroundColor Red
    }
    exit 0
} else {
    Write-Host '  ╔══════════════════════════════════════════╗' -ForegroundColor Red
    Write-Host '  ║   合符失败 —— 至少一符不正确              ║' -ForegroundColor Red
    Write-Host '  ╚══════════════════════════════════════════╝' -ForegroundColor Red
    Write-Host ''
    Write-Host '  出于安全考虑，不提示是左符错还是右符错。' -ForegroundColor Yellow
    Write-Host '  请核对:' 
    Write-Host '    · 左符是否抄写无误（指纹 D0A997CBA6E33F9A）'
    Write-Host '    · 右符是否与设定时完全一致（含大小写）'
    exit 4
}
