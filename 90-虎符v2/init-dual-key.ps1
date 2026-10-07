# init-dual-key.ps1 —— 虎符 v3 双口令：初始化
# 用途: 输入左符（AI 生成）+ 右符（用户自设），派生主密钥并生成验证块
# 建立者: DSH   时间: 2026-10-07
#
# 安全要求:
#   · 两个口令都不落盘
#   · 只保存"验证块"（密文）与"盐"（非秘密）
#   · 一旦初始化完成，两个口令只存在于用户手上
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File init-dual-key.ps1
#   （交互式输入两个口令，输入时不回显）

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Dir = $PSScriptRoot
$SaltFile = Join-Path $Dir 'dual-key-salt.bin'
$BlobFile = Join-Path $Dir 'dual-key-blob.bin'
$MetaFile = Join-Path $Dir 'dual-key-meta.json'
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
Write-Host '=== 虎符 v3 · 双口令初始化 ===' -ForegroundColor Yellow
Write-Host ''
Write-Host '提示: 左符由 AI 生成（你已抄写）；右符由你自行设定（AI 从未见过）。'
Write-Host '      输入时不会回显，请仔细输入。'
Write-Host ''

$left = Read-Secret '  请输入【左符】(32 字符): '
if ([string]::IsNullOrWhiteSpace($left)) { Write-Host '左符为空，中止。' -ForegroundColor Red; exit 2 }
# 允许带连字符的输入
$left = $left -replace '[^A-Za-z0-9]', ''
if ($left.Length -ne 32) {
    Write-Host ("左符长度应为 32 个字符，实际 " + $left.Length + " 个（已去除分隔符）。") -ForegroundColor Red
    Write-Host '若长度不符，可能是抄写有误。已中止。'
    exit 3
}

# 校验左符指纹
$sha = [System.Security.Cryptography.SHA256]::Create()
$h = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($left))
$sha.Dispose()
$fp = (($h | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0,16).ToUpper()
Write-Host ("  左符指纹: " + $fp)
if (Test-Path $MetaFile) {
    $oldMeta = Get-Content $MetaFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $expect = $oldMeta.leftKey.fingerprint_sha256_first16
    if ($expect -and ($fp -ne $expect)) {
        Write-Host ("  ⚠ 与记录指纹不符（应为 " + $expect + "）") -ForegroundColor Red
        Write-Host '    可能抄写有误。请核对后再试。' -ForegroundColor Red
        exit 4
    }
    Write-Host '  ✅ 与记录指纹一致' -ForegroundColor Green
}
Write-Host ''

$right = Read-Secret '  请输入【右符】(你自己设定的口令，建议 ≥12 位): '
if ([string]::IsNullOrWhiteSpace($right) -or $right.Length -lt 8) {
    Write-Host '右符过短（至少 8 位），中止。' -ForegroundColor Red
    exit 5
}
$right2 = Read-Secret '  请再次输入【右符】以确认: '
if ($right -ne $right2) { Write-Host '两次输入不一致，中止。' -ForegroundColor Red; exit 6 }
Write-Host ''

# 盐
if (Test-Path $SaltFile) {
    $salt = [System.IO.File]::ReadAllBytes($SaltFile)
    Write-Host ('  使用已有盐: ' + $salt.Length + ' 字节')
} else {
    $salt = New-Object byte[] 32
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $rng.GetBytes($salt); $rng.Dispose()
    [System.IO.File]::WriteAllBytes($SaltFile, $salt)
    Write-Host ('  已生成新盐: ' + $salt.Length + ' 字节')
}

# 派生
$combined = $left + '|' + $right
$kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
    $combined, $salt, $Iterations,
    [System.Security.Cryptography.HashAlgorithmName]::SHA256)
$master = $kdf.GetBytes(32)
$kdf.Dispose()

# 验证块
$aes = [System.Security.Cryptography.Aes]::Create()
$aes.KeySize = 256
$aes.Key = $master
$aes.GenerateIV()
$iv = $aes.IV
$enc = $aes.CreateEncryptor()
$plain = [System.Text.Encoding]::UTF8.GetBytes($Marker)
$cipher = $enc.TransformFinalBlock($plain, 0, $plain.Length)
$enc.Dispose(); $aes.Dispose()

# 存 IV + 密文
$outBytes = New-Object byte[] ($iv.Length + $cipher.Length)
[Array]::Copy($iv, 0, $outBytes, 0, $iv.Length)
[Array]::Copy($cipher, 0, $outBytes, $iv.Length, $cipher.Length)
[System.IO.File]::WriteAllBytes($BlobFile, $outBytes)

# 清空内存中的秘密
$combined = $null; $right = $null; $right2 = $null
[System.GC]::Collect()

Write-Host ''
Write-Host '=== 初始化完成 ===' -ForegroundColor Green
Write-Host ('  验证块: ' + (Split-Path $BlobFile -Leaf) + '  ' + $outBytes.Length + ' 字节')
Write-Host ('  盐    : ' + (Split-Path $SaltFile -Leaf) + '  ' + $salt.Length + ' 字节')
Write-Host ''
Write-Host '  现在请确认:' -ForegroundColor Yellow
Write-Host '    1. 左符与右符已【分开】保存在两个地方'
Write-Host '    2. 两个口令都没有写进经验包目录'
Write-Host '    3. 日后解锁需同时输入两者，缺一不可'
Write-Host ''
Write-Host '  ⚠ 若两个口令都丢失，验证块将永久无法解开。' -ForegroundColor Red
