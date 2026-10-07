#Requires -Version 5.1
<#
    tally-lib.ps1 —— 虎符安全系统 · 加密核心库

    ⚠️ 这是安全关键代码。修改前请完整理解其构造。

    构造说明：
      密钥派生：
        K1 = PBKDF2-HMAC-SHA256(passphrase, salt, 600000, 64)
        K2 = keyfile (64 随机字节)
        MasterKey = K1 XOR K2          ← 虎符：两者缺一不可
        EncKey = MasterKey[0..31]      ← AES-256
        MacKey = MasterKey[32..63]     ← HMAC-SHA256

      加密（encrypt-then-MAC）：
        IV = 16 随机字节
        密文 = AES-256-CBC(EncKey, IV, 明文)
        Mac  = HMAC-SHA256(MacKey, IV ‖ 密文)

      文件格式（固定偏移，手工拼字节 —— 不用 BinaryWriter，
                因为 PowerShell 的重载解析不可靠，曾导致布局错位）：
        偏移   长度  字段
        0      8     MAGIC 'TALLYv01'
        8      2     VERSION  (uint16 LE)
        10     4     ITER     (uint32 LE)
        14     2     SALTLEN  (uint16 LE)
        16     32    SALT
        48     2     IVLEN    (uint16 LE)
        50     16    IV
        66     2     MACLEN   (uint16 LE)
        68     32    MAC
        100    N     CIPHERTEXT
#>

Set-StrictMode -Version Latest

$script:TallyMagic   = [Text.Encoding]::ASCII.GetBytes('TALLYv01')   # 8 字节
$script:TallyVersion = 1
$script:Pbkdf2Iter   = 600000
$script:SaltLen      = 32
$script:KeyFileLen   = 64
$script:IvLen        = 16
$script:MacLen       = 32

# 固定偏移
$script:OffMagic  = 0
$script:OffVer    = 8
$script:OffIter   = 10
$script:OffSaltLn = 14
$script:OffSalt   = 16
$script:OffIvLn   = 48
$script:OffIv     = 50
$script:OffMacLn  = 66
$script:OffMac    = 68
$script:OffCipher = 100

# ─────────────────────────────────────────────
# 基础工具
# ─────────────────────────────────────────────

function New-RandomBytes([int]$count) {
    $b = New-Object byte[] $count
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    try { $rng.GetBytes($b) } finally { $rng.Dispose() }
    return ,$b
}

function ConvertTo-Hex($bytes) {
    if ($null -eq $bytes) { return '' }
    return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Get-BytesSha256($bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ,$sha.ComputeHash($bytes) } finally { $sha.Dispose() }
}

function Test-ConstantTimeEqual($a, $b) {
    # 恒定时间比较，防时序攻击
    if ($null -eq $a -or $null -eq $b) { return $false }
    if ($a.Length -ne $b.Length) { return $false }
    $diff = 0
    for ($i = 0; $i -lt $a.Length; $i++) { $diff = $diff -bor ($a[$i] -bxor $b[$i]) }
    return ($diff -eq 0)
}

# ─────────────────────────────────────────────
# 手工字节读写（避免 BinaryWriter 重载歧义）
# ─────────────────────────────────────────────

function Write-UInt16LE($buf, [int]$offset, [int]$value) {
    $buf[$offset]     = [byte]($value -band 0xFF)
    $buf[$offset + 1] = [byte](($value -shr 8) -band 0xFF)
}

function Write-UInt32LE($buf, [int]$offset, [long]$value) {
    $buf[$offset]     = [byte]($value -band 0xFF)
    $buf[$offset + 1] = [byte](($value -shr 8)  -band 0xFF)
    $buf[$offset + 2] = [byte](($value -shr 16) -band 0xFF)
    $buf[$offset + 3] = [byte](($value -shr 24) -band 0xFF)
}

function Read-UInt16LE($buf, [int]$offset) {
    return ([int]$buf[$offset] -bor ([int]$buf[$offset + 1] -shl 8))
}

function Read-UInt32LE($buf, [int]$offset) {
    return ([long]$buf[$offset] -bor ([long]$buf[$offset+1] -shl 8) -bor
            ([long]$buf[$offset+2] -shl 16) -bor ([long]$buf[$offset+3] -shl 24))
}

# ─────────────────────────────────────────────
# 虎符：密钥文件
# ─────────────────────────────────────────────

function New-TallyKeyFile([string]$Path) {
    $b = New-RandomBytes $script:KeyFileLen
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllBytes($Path, $b)
    # 尽力限制文件权限（仅当前用户）
    try {
        $acl = Get-Acl $Path
        $acl.SetAccessRuleProtection($true, $false)
        $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($me, 'FullControl', 'Allow')
        $acl.AddAccessRule($rule)
        Set-Acl -Path $Path -AclObject $acl
    } catch { }
    return ,$b
}

function Read-TallyKeyFile([string]$Path) {
    if (-not (Test-Path $Path)) { throw "密钥文件不存在: $Path" }
    $b = [IO.File]::ReadAllBytes($Path)
    if ($b.Length -ne $script:KeyFileLen) {
        throw ("密钥文件长度错误：期望 " + $script:KeyFileLen + " 字节，实际 " + $b.Length)
    }
    return ,$b
}

# ─────────────────────────────────────────────
# 密钥派生（虎符核心）
# ─────────────────────────────────────────────

function Get-MasterKey {
    param(
        [Parameter(Mandatory)][string]$Passphrase,
        [Parameter(Mandatory)][byte[]]$Salt,
        [Parameter(Mandatory)][byte[]]$KeyFile
    )
    if ($Salt.Length -lt 8) { throw 'Salt 至少需要 8 字节' }
    # K1 = PBKDF2
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
        $Passphrase, $Salt, $script:Pbkdf2Iter,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    try { $k1 = $kdf.GetBytes($script:KeyFileLen) } finally { $kdf.Dispose() }

    # MasterKey = K1 XOR K2  ← 虎符：必须两者都有
    $mk = New-Object byte[] $script:KeyFileLen
    for ($i = 0; $i -lt $script:KeyFileLen; $i++) { $mk[$i] = $k1[$i] -bxor $KeyFile[$i] }
    return ,$mk
}

function Split-MasterKey($masterKey) {
    if ($masterKey.Length -ne 64) { throw ("MasterKey 必须是 64 字节，实际 " + $masterKey.Length) }
    $enc = New-Object byte[] 32
    $mac = New-Object byte[] 32
    [Array]::Copy($masterKey, 0,  $enc, 0, 32)
    [Array]::Copy($masterKey, 32, $mac, 0, 32)
    return @{ Enc = $enc; Mac = $mac }
}

# ─────────────────────────────────────────────
# 加密 / 解密
# ─────────────────────────────────────────────

function Protect-Bytes {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Plaintext,
        [Parameter(Mandatory)][byte[]]$MasterKey,
        [byte[]]$Salt
    )
    if ($null -eq $Salt -or $Salt.Length -eq 0) { $Salt = New-RandomBytes $script:SaltLen }
    $k = Split-MasterKey $MasterKey

    $iv = New-RandomBytes $script:IvLen
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.KeySize = 256
    $aes.Key = $k.Enc
    $aes.IV = $iv
    try {
        $encryptor = $aes.CreateEncryptor()
        $cipher = $encryptor.TransformFinalBlock($Plaintext, 0, $Plaintext.Length)
        $encryptor.Dispose()
    } finally { $aes.Dispose() }

    # MAC over IV ‖ ciphertext  (encrypt-then-MAC)
    $macInput = New-Object byte[] ($iv.Length + $cipher.Length)
    [Array]::Copy($iv,     0, $macInput, 0,           $iv.Length)
    [Array]::Copy($cipher, 0, $macInput, $iv.Length,  $cipher.Length)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $k.Mac
    try { $mac = $hmac.ComputeHash($macInput) } finally { $hmac.Dispose() }

    # 组装文件（固定偏移，手工写入）
    $total = $script:OffCipher + $cipher.Length
    $out = New-Object byte[] $total
    [Array]::Copy($script:TallyMagic, 0, $out, $script:OffMagic, 8)
    Write-UInt16LE $out $script:OffVer    $script:TallyVersion
    Write-UInt32LE $out $script:OffIter   $script:Pbkdf2Iter
    Write-UInt16LE $out $script:OffSaltLn $Salt.Length
    [Array]::Copy($Salt,   0, $out, $script:OffSalt,   $Salt.Length)
    Write-UInt16LE $out $script:OffIvLn   $iv.Length
    [Array]::Copy($iv,     0, $out, $script:OffIv,     $iv.Length)
    Write-UInt16LE $out $script:OffMacLn  $mac.Length
    [Array]::Copy($mac,    0, $out, $script:OffMac,    $mac.Length)
    [Array]::Copy($cipher, 0, $out, $script:OffCipher, $cipher.Length)
    return ,$out
}

function Unprotect-Bytes {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Blob,
        [Parameter(Mandatory)][byte[]]$MasterKey
    )
    if ($Blob.Length -lt $script:OffCipher) {
        throw ('文件太小，不是有效的加密文件（' + $Blob.Length + ' 字节）')
    }

    # 文件头校验
    $magic = New-Object byte[] 8
    [Array]::Copy($Blob, $script:OffMagic, $magic, 0, 8)
    if (-not (Test-ConstantTimeEqual $magic $script:TallyMagic)) {
        throw '文件格式错误：magic 不匹配（不是本系统加密的文件）'
    }
    $ver = Read-UInt16LE $Blob $script:OffVer
    if ($ver -ne $script:TallyVersion) { throw "不支持的格式版本: $ver" }

    $saltLen = Read-UInt16LE $Blob $script:OffSaltLn
    $ivLen   = Read-UInt16LE $Blob $script:OffIvLn
    $macLen  = Read-UInt16LE $Blob $script:OffMacLn
    if ($ivLen -ne 16) { throw ("IV 长度异常: " + $ivLen) }
    if ($macLen -ne 32) { throw ("MAC 长度异常: " + $macLen) }

    $salt = New-Object byte[] $saltLen
    [Array]::Copy($Blob, $script:OffSalt, $salt, 0, $saltLen)
    $iv = New-Object byte[] $ivLen
    [Array]::Copy($Blob, $script:OffIv, $iv, 0, $ivLen)
    $mac = New-Object byte[] $macLen
    [Array]::Copy($Blob, $script:OffMac, $mac, 0, $macLen)
    $cipherLen = $Blob.Length - $script:OffCipher
    if ($cipherLen -le 0) { throw '密文长度为 0' }
    $cipher = New-Object byte[] $cipherLen
    [Array]::Copy($Blob, $script:OffCipher, $cipher, 0, $cipherLen)

    $k = Split-MasterKey $MasterKey

    # 先验 MAC，再解密（关键：防止 padding oracle 等攻击）
    $macInput = New-Object byte[] ($iv.Length + $cipher.Length)
    [Array]::Copy($iv,     0, $macInput, 0,          $iv.Length)
    [Array]::Copy($cipher, 0, $macInput, $iv.Length, $cipher.Length)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $k.Mac
    try { $expect = $hmac.ComputeHash($macInput) } finally { $hmac.Dispose() }

    if (-not (Test-ConstantTimeEqual $mac $expect)) {
        throw '★ 完整性校验失败：口令或密钥文件错误，或文件已被篡改'
    }

    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.KeySize = 256
    $aes.Key = $k.Enc
    $aes.IV = $iv
    try {
        $dec = $aes.CreateDecryptor()
        return ,$dec.TransformFinalBlock($cipher, 0, $cipher.Length)
    } finally { $aes.Dispose() }
}

# ─────────────────────────────────────────────
# 文件级封装
# ─────────────────────────────────────────────

function Protect-File {
    param(
        [Parameter(Mandatory)][string]$InPath,
        [Parameter(Mandatory)][string]$OutPath,
        [Parameter(Mandatory)][byte[]]$MasterKey
    )
    $plain = [IO.File]::ReadAllBytes($InPath)
    $blob  = Protect-Bytes -Plaintext $plain -MasterKey $MasterKey
    [IO.File]::WriteAllBytes($OutPath, $blob)
    return ,$blob.Length
}

function Unprotect-File {
    param(
        [Parameter(Mandatory)][string]$InPath,
        [Parameter(Mandatory)][string]$OutPath,
        [Parameter(Mandatory)][byte[]]$MasterKey
    )
    $blob  = [IO.File]::ReadAllBytes($InPath)
    $plain = Unprotect-Bytes -Blob $blob -MasterKey $MasterKey
    [IO.File]::WriteAllBytes($OutPath, $plain)
    return $plain.Length
}

# ─────────────────────────────────────────────
# 口令输入
# ─────────────────────────────────────────────

function Read-TallyPassphrase {
    param([string]$Prompt = '输入虎符口令', [switch]$Confirm)
    $p1 = Read-Host -Prompt $Prompt -AsSecureString
    if ($Confirm) {
        $p2 = Read-Host -Prompt '再输一次确认' -AsSecureString
        $b1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1)
        $b2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p2)
        try {
            $s1 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b1)
            $s2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b2)
            if ($s1 -ne $s2) { throw '两次输入的口令不一致' }
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b1)
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b2)
        }
    }
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p1)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

function Test-PassphraseStrength([string]$p) {
    $issues = @()
    if ($p.Length -lt 12) { $issues += ('长度不足 12（当前 ' + $p.Length + '）') }
    if ($p -notmatch '[a-z]') { $issues += '缺少小写字母' }
    if ($p -notmatch '[A-Z]') { $issues += '缺少大写字母' }
    if ($p -notmatch '[0-9]') { $issues += '缺少数字' }
    if ($p -notmatch '[^a-zA-Z0-9]') { $issues += '缺少符号' }
    return $issues
}
