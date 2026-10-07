# init-triple-key.ps1 —— 虎符 v3.1 门限口令：初始化（三选二）
# 用途: 左符（AI 生成）+ 你自己的三个口令中的【任意两个】才能解锁
# 建立者: DSH   时间: 2026-10-07
#
# 原理:
#   三个口令 P1 P2 P3，合法配对为 (P1,P2) (P1,P3) (P2,P3)
#   为每一组配对派生一个密钥 K_ij = PBKDF2(左符 || 排序后的Pi,Pj, salt)
#   随机生成真钥匙 REAL_KEY
#   生成三个保险箱: vault_ij = AES(K_ij, REAL_KEY)
#   解锁时: 输入任意两个口令 → 派生出对应的 K_ij → 打开对应保险箱 → 得到 REAL_KEY
#
# 安全性质:
#   · 只知一个口令 → 无法组成任何合法配对 → 打不开
#   · 三个都不知道 → 打不开
#   · 知道任意两个 → 可以打开（这正是设计意图）
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File init-triple-key.ps1
#   （交互式输入左符 + 三个口令，输入均不回显）

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Dir       = $PSScriptRoot
$SaltFile  = Join-Path $Dir 'triple-salt.bin'
$LeftMeta  = Join-Path $Dir 'dual-key-meta.json'   # 复用已有的左符指纹记录
$Marker    = 'TIGER-TALLY-TRIPLE-KEY-V1'
$Iters     = 600000

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

function Protect-Bytes([byte[]]$key, [byte[]]$data) {
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.KeySize = 256; $aes.Key = $key; $aes.GenerateIV()
    $iv = $aes.IV
    $enc = $aes.CreateEncryptor()
    $ct = $enc.TransformFinalBlock($data, 0, $data.Length)
    $enc.Dispose(); $aes.Dispose()
    $out = New-Object byte[] ($iv.Length + $ct.Length)
    [Array]::Copy($iv, 0, $out, 0, $iv.Length)
    [Array]::Copy($ct, 0, $out, $iv.Length, $ct.Length)
    return $out
}

Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════╗' -ForegroundColor Yellow
Write-Host '║     虎符 v3.1 · 门限口令初始化（你的口令：三选二）        ║' -ForegroundColor Yellow
Write-Host '╚══════════════════════════════════════════════════════════╝' -ForegroundColor Yellow
Write-Host ''
Write-Host '  本次将设定:'
Write-Host '    · 左符（由 AI 生成，你已抄写）—— 1 个'
Write-Host '    · 你的口令 —— 3 个，日后只需其中【任意 2 个】即可解锁'
Write-Host ''
Write-Host '  ⚠ 输入时不回显。请仔细输入。' -ForegroundColor DarkGray
Write-Host ''

# ---- 左符 ----
$left = Read-Secret '  请输入【左符】(32 字符): '
$left = $left -replace '[^A-Za-z0-9]', ''
if ($left.Length -ne 32) {
    Write-Host ("  左符长度应为 32，实际 " + $left.Length + "。可能抄写有误，已中止。") -ForegroundColor Red
    exit 2
}
$sha = [System.Security.Cryptography.SHA256]::Create()
$h = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($left))
$sha.Dispose()
$fp = (($h | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0,16).ToUpper()
Write-Host ("  左符指纹: " + $fp)
if (Test-Path $LeftMeta) {
    $m = Get-Content $LeftMeta -Raw -Encoding UTF8 | ConvertFrom-Json
    $expect = $m.leftKey.fingerprint_sha256_first16
    if ($expect -and ($fp -ne $expect)) {
        Write-Host ("  ⚠ 与记录不符（应为 " + $expect + "）—— 可能抄写有误，已中止。") -ForegroundColor Red
        exit 3
    }
    Write-Host '  ✅ 指纹一致' -ForegroundColor Green
}
Write-Host ''

# ---- 三个口令 ----
$pw = @()
for ($i = 1; $i -le 3; $i++) {
    $p1 = Read-Secret ("  请输入你的第 " + $i + " 个口令: ")
    if ([string]::IsNullOrWhiteSpace($p1) -or $p1.Length -lt 6) {
        Write-Host ("  第 " + $i + " 个口令过短（至少 6 位），已中止。") -ForegroundColor Red
        exit 4
    }
    $p2 = Read-Secret ("  请再次输入第 " + $i + " 个口令以确认: ")
    if ($p1 -ne $p2) { Write-Host ("  第 " + $i + " 个口令两次不一致，已中止。") -ForegroundColor Red; exit 5 }
    $pw += $p1
    Write-Host ''
}

# 三个口令必须互不相同，否则"三选二"会退化成"一对一"
if ($pw[0] -eq $pw[1] -or $pw[0] -eq $pw[2] -or $pw[1] -eq $pw[2]) {
    Write-Host '  ⚠ 三个口令中存在重复。门限方案要求三者互不相同。已中止。' -ForegroundColor Red
    exit 6
}

# ---- 盐 ----
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

# ---- 生成真钥匙 ----
$realKey = New-Object byte[] 32
$rng2 = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$rng2.GetBytes($realKey); $rng2.Dispose()

# ---- 三组配对，各造一个保险箱 ----
$pairs = @(
    @(0,1), @(0,2), @(1,2)
)
$names = @('12','13','23')
$blobs = @{}
Write-Host ''
Write-Host '  正在派生密钥并生成保险箱（每组约需 1-2 秒）...'
for ($i = 0; $i -lt 3; $i++) {
    $a = $pairs[$i][0]; $b = $pairs[$i][1]
    $key = Get-Key $left @($pw[$a], $pw[$b]) $salt $Iters
    # 保险箱内容 = 真钥匙 + 标记，便于校验
    $payload = $realKey + [System.Text.Encoding]::UTF8.GetBytes($Marker)
    $blob = Protect-Bytes $key $payload
    $blobs[$names[$i]] = $blob
    $file = Join-Path $Dir ('triple-vault-' + $names[$i] + '.bin')
    [System.IO.File]::WriteAllBytes($file, $blob)
    Write-Host ('    ✅ 保险箱 ' + $names[$i] + '（口令 ' + ($a+1) + ' + ' + ($b+1) + '）  ' + $blob.Length + ' 字节')
    # 清理
    $key = $null; $payload = $null
}

# ---- 元数据 ----
$meta = [ordered]@{
    schema    = 'tiger-tally/threshold-key/v1'
    created   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
    threshold = [ordered]@{
        required = 2
        total    = 3
        note     = '用户三个口令中任意两个即可解锁；只知一个无法解锁'
    }
    leftKey   = [ordered]@{
        generated_by = 'DSH'
        length = 32
        entropy_bits = 186
        fingerprint_sha256_first16 = $fp
        stored = $false
    }
    userKeys  = [ordered]@{
        count = 3
        known_to_ai = $false
        stored = $false
        note = '三个口令均不落盘。AI 从未见过其中任何一个。'
    }
    derive    = [ordered]@{
        algorithm = 'PBKDF2-HMAC-SHA256'
        iterations = $Iters
        input = '左符 + "|" + 排序后的两个口令（以 || 连接）'
        salt_file = 'triple-salt.bin'
    }
    vaults    = @(
        @{ name='12'; protects='口令1+口令2'; file='triple-vault-12.bin' },
        @{ name='13'; protects='口令1+口令3'; file='triple-vault-13.bin' },
        @{ name='23'; protects='口令2+口令3'; file='triple-vault-23.bin' }
    )
}
$bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText((Join-Path $Dir 'triple-meta.json'), ($meta | ConvertTo-Json -Depth 6), $bom)

# 清空内存
$pw = $null; $left = $null; $realKey = $null
[System.GC]::Collect()

Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════╗' -ForegroundColor Green
Write-Host '║                    初始化完成                             ║' -ForegroundColor Green
Write-Host '╚══════════════════════════════════════════════════════════╝' -ForegroundColor Green
Write-Host ''
Write-Host '  已生成三个保险箱，各由一组口令对保护:'
Write-Host '      口令1 + 口令2  →  triple-vault-12.bin'
Write-Host '      口令1 + 口令3  →  triple-vault-13.bin'
Write-Host '      口令2 + 口令3  →  triple-vault-23.bin'
Write-Host ''
Write-Host '  日后解锁只需输入【任意两个】口令。' -ForegroundColor Yellow
Write-Host ''
Write-Host '  请确认:' -ForegroundColor Yellow
Write-Host '    1. 左符与三个口令【分开】保存'
Write-Host '    2. 三个口令都没有写进经验包目录'
Write-Host '    3. 三个口令互不相同（已校验）'
Write-Host ''
Write-Host '  ⚠ 若三个口令全部丢失，保险箱将永久无法打开。' -ForegroundColor Red
