# unlock-triple-key.ps1 —— 虎符 v3.1 门限口令：解锁（三选二）
# 用途: 输入左符 + 你的三个口令中的【任意两个】，验证并取出真钥匙
# 建立者: DSH   时间: 2026-10-07
#
# 原理:
#   用输入的左符 + 两个口令派生出候选密钥 K
#   依次尝试三个保险箱；能打开哪个，就说明用的那组口令属于合法配对
#   打开后取回 REAL_KEY（真钥匙），并清除内存
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File unlock-triple-key.ps1
#   powershell -ExecutionPolicy Bypass -File unlock-triple-key.ps1 -ExportKey   # 输出真钥匙（谨慎）

param(
    [switch]$ExportKey
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Dir      = $PSScriptRoot
$SaltFile = Join-Path $Dir 'triple-salt.bin'
$Marker   = 'TIGER-TALLY-TRIPLE-KEY-V1'
$Iters    = 600000
$Vaults   = @('12','13','23')

function Read-Secret([string]$prompt) {
    Write-Host $prompt -NoNewline -ForegroundColor Cyan
    $sec = Read-Host -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Get-Key([string]$left, [string[]]$pair, [byte[]]$salt, [int]$it) {
    $sorted = $pair | Sort-Object
    $combined = $left + '|' + ($sorted -join '||')
    $k = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
        $combined, $salt, $it, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $m = $k.GetBytes(32); $k.Dispose()
    return $m
}

function Try-Open([byte[]]$key, [byte[]]$blob) {
    try {
        $ivLen = 16
        $iv = New-Object byte[] $ivLen
        $ct = New-Object byte[] ($blob.Length - $ivLen)
        [Array]::Copy($blob, 0, $iv, 0, $ivLen)
        [Array]::Copy($blob, $ivLen, $ct, 0, $ct.Length)
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.KeySize = 256; $aes.Key = $key; $aes.IV = $iv
        $dec = $aes.CreateDecryptor()
        $pt = $dec.TransformFinalBlock($ct, 0, $ct.Length)
        $dec.Dispose(); $aes.Dispose()
        # payload = REAL_KEY(32) + Marker
        if ($pt.Length -lt 32) { return $null }
        $tail = [System.Text.Encoding]::UTF8.GetString($pt, 32, $pt.Length - 32)
        if ($tail -ne $Marker) { return $null }
        $real = New-Object byte[] 32
        [Array]::Copy($pt, 0, $real, 0, 32)
        return $real
    } catch {
        return $null
    }
}

Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════╗' -ForegroundColor Yellow
Write-Host '║     虎符 v3.1 · 门限口令解锁（输入任意两个口令）          ║' -ForegroundColor Yellow
Write-Host '╚══════════════════════════════════════════════════════════╝' -ForegroundColor Yellow
Write-Host ''

if (-not (Test-Path $SaltFile)) {
    Write-Host '[失败] 缺少 triple-salt.bin —— 尚未初始化。' -ForegroundColor Red
    Write-Host '  ⇒ 请先运行 init-triple-key.ps1'
    exit 2
}
foreach ($v in $Vaults) {
    $f = Join-Path $Dir ('triple-vault-' + $v + '.bin')
    if (-not (Test-Path $f)) {
        Write-Host ('[失败] 缺少保险箱: triple-vault-' + $v + '.bin') -ForegroundColor Red
        exit 3
    }
}

$salt = [System.IO.File]::ReadAllBytes($SaltFile)

$left = Read-Secret '  请输入【左符】: '
$left = $left -replace '[^A-Za-z0-9]', ''
Write-Host ''
$pa = Read-Secret '  请输入你的口令（第 1 个，任意）: '
Write-Host ''
$pb = Read-Secret '  请输入你的口令（第 2 个，任意）: '
Write-Host ''

if ([string]::IsNullOrWhiteSpace($left) -or [string]::IsNullOrWhiteSpace($pa) -or [string]::IsNullOrWhiteSpace($pb)) {
    Write-Host '[失败] 输入不得为空。' -ForegroundColor Red
    exit 4
}
if ($pa -eq $pb) {
    Write-Host '[失败] 两个口令相同 —— 门限方案需要两个不同的口令。' -ForegroundColor Red
    exit 5
}

Write-Host '  正在派生密钥（约 1-2 秒）...' -ForegroundColor DarkGray
$key = Get-Key $left @($pa, $pb) $salt $Iters

$real = $null
$used = ''
foreach ($v in $Vaults) {
    $f = Join-Path $Dir ('triple-vault-' + $v + '.bin')
    $blob = [System.IO.File]::ReadAllBytes($f)
    $r = Try-Open $key $blob
    if ($r -ne $null) { $real = $r; $used = $v; break }
}

$key = $null; $pa = $null; $pb = $null
[System.GC]::Collect()

Write-Host ''
if ($real -ne $null) {
    Write-Host '  ╔══════════════════════════════════════════════════════╗' -ForegroundColor Green
    Write-Host '  ║   合符成功 —— 门限校验通过（任选两个口令有效）        ║' -ForegroundColor Green
    Write-Host '  ╚══════════════════════════════════════════════════════╝' -ForegroundColor Green
    Write-Host ('  打开的是保险箱: ' + $used + '  （即口令组合 ' + $used[0] + ' + ' + $used[1] + '）')
    Write-Host '  真钥匙已取出（仅存于内存，脚本结束即清除）'
    if ($ExportKey) {
        $hex = ($real | ForEach-Object { $_.ToString('x2') }) -join ''
        Write-Host ''
        Write-Host '  真钥匙（16 进制，谨慎使用）:' -ForegroundColor Yellow
        Write-Host ('    ' + $hex)
        Write-Host '  ⚠ 拿到真钥匙即可解密隐私层，用完请清除终端记录。' -ForegroundColor Red
    }
    $real = $null
    [System.GC]::Collect()
    exit 0
} else {
    Write-Host '  ╔══════════════════════════════════════════════════════╗' -ForegroundColor Red
    Write-Host '  ║   合符失败 —— 三个保险箱都打不开                      ║' -ForegroundColor Red
    Write-Host '  ╚══════════════════════════════════════════════════════╝' -ForegroundColor Red
    Write-Host ''
    Write-Host '  可能原因:' -ForegroundColor Yellow
    Write-Host '    · 左符抄写有误（指纹应为 D0A997CBA6E33F9A）'
    Write-Host '    · 两个口令中有拼写错误（区分大小写）'
    Write-Host '    · 这两个口令不属于同一套（例如用了后来新设的口令）'
    Write-Host ''
    Write-Host '  出于安全考虑，不提示具体是哪一个出错。'
    exit 6
}
