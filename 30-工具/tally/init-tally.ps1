#Requires -Version 5.1
<#
.SYNOPSIS
    init-tally.ps1 —— 初始化虎符安全系统

.DESCRIPTION
    ⚠️ 只运行一次。做三件事：
      ① 生成虎符右半：tally.key（密钥文件，你保管）
      ② 派生出主密钥（口令 = 虎符左半，不落盘）
      ③ 把受保护层加密成 PROTECTED.enc

    受保护层默认包含：
      · core\       核心安全配置
      · local\      私密经验（含本机信息）

.EXAMPLE
    .\init-tally.ps1                          # 标准初始化
    .\init-tally.ps1 -PackRoot C:\test\pack    # 指定包根目录（测试用）
    .\init-tally.ps1 -IncludeTools             # 连工具的核心实现一起加密
#>
[CmdletBinding()]
param(
    [string]$PackRoot,
    [switch]$IncludeTools,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tally-lib.ps1')

# ---- 定位包根 ----
if (-not $PackRoot) {
    $PackRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
if (-not (Test-Path $PackRoot)) { throw "包根目录不存在: $PackRoot" }

$TallyDir = Join-Path $PackRoot 'tally'
$EncFile  = Join-Path $PackRoot 'PROTECTED.enc'
$KeyFile  = Join-Path $TallyDir 'tally.key'
$Manifest = Join-Path $TallyDir 'manifest.json'

Write-Host ''
Write-Host '════════ 虎符安全系统 · 初始化 ════════' -ForegroundColor Cyan
Write-Host ''
Write-Host ('  包根目录: ' + $PackRoot) -ForegroundColor Gray
Write-Host ''

if ((Test-Path $EncFile) -and -not $Force) {
    Write-Host '  ⚠ 已存在 PROTECTED.enc。' -ForegroundColor Yellow
    Write-Host '    重新初始化会【覆盖】它，且旧密钥文件将无法解密新文件。' -ForegroundColor Yellow
    Write-Host '    如确认要重做，加 -Force 参数。' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

# ---- 收集受保护内容 ----
$targets = @()
$coreDir  = Join-Path $PackRoot 'core'
$localData = Join-Path $PackRoot '20-历史经验\data\local'
$localSkills = Join-Path $PackRoot '40-Skills\local'

if (Test-Path $coreDir)    { $targets += $coreDir } else { Write-Host ('  · core\ 不存在（将跳过）') -ForegroundColor DarkGray }
if (Test-Path $localData)  { $targets += $localData }
if (Test-Path $localSkills){ $targets += $localSkills }
if ($IncludeTools)         { $targets += (Join-Path $PackRoot '30-工具\tally') }

if ($targets.Count -eq 0) {
    Write-Host '  ❌ 没有找到任何受保护内容' -ForegroundColor Red
    exit 1
}

Write-Host '  将保护以下内容：' -ForegroundColor Green
foreach ($t in $targets) {
    $n = @(Get-ChildItem $t -Recurse -File -ErrorAction SilentlyContinue).Count
    Write-Host ('    · ' + $t.Replace($PackRoot,'.') + '   (' + $n + ' 个文件)')
}
Write-Host ''

# ---- 口令 ----
Write-Host '  ★ 虎符左半：口令' -ForegroundColor Yellow
Write-Host '     · 不会存储在任何地方' -ForegroundColor DarkGray
Write-Host '     · 忘记 = 数据永久丢失' -ForegroundColor DarkGray
Write-Host '     · 建议 ≥ 12 字符，混合大小写数字符号' -ForegroundColor DarkGray
Write-Host ''
$pass = Read-TallyPassphrase -Prompt '设置虎符口令' -Confirm

$issues = Test-PassphraseStrength $pass
if ($issues.Count -gt 0) {
    Write-Host ''
    Write-Host '  ⚠ 口令强度不足：' -ForegroundColor Yellow
    foreach ($i in $issues) { Write-Host ('     · ' + $i) -ForegroundColor Yellow }
    Write-Host ''
    $ans = Read-Host '  仍要继续？(yes/no)'
    if ($ans -ne 'yes') { Write-Host '  已取消。' -ForegroundColor Gray; exit 1 }
}

# ---- 生成虎符右半 ----
Write-Host ''
Write-Host '  ★ 虎符右半：密钥文件' -ForegroundColor Yellow
if (-not (Test-Path $TallyDir)) { New-Item -ItemType Directory -Path $TallyDir -Force | Out-Null }
if ((Test-Path $KeyFile) -and -not $Force) {
    Write-Host ('     ⚠ ' + $KeyFile + ' 已存在，保留原文件') -ForegroundColor Yellow
    $keyBytes = Read-TallyKeyFile $KeyFile
    $salt = if (Test-Path (Join-Path $TallyDir 'salt.bin')) {
        [IO.File]::ReadAllBytes((Join-Path $TallyDir 'salt.bin'))
    } else { New-RandomBytes $script:SaltLen }
} else {
    $keyBytes = New-TallyKeyFile $KeyFile
    $salt = New-RandomBytes $script:SaltLen
    [IO.File]::WriteAllBytes((Join-Path $TallyDir 'salt.bin'), $salt)
    Write-Host ('     ✅ 已生成: ' + $KeyFile) -ForegroundColor Green
}

# ---- 派生主密钥 ----
Write-Host ''
Write-Host '  派生主密钥（PBKDF2 60 万次迭代，约需数秒）...' -ForegroundColor Gray
$sw = [Diagnostics.Stopwatch]::StartNew()
$masterKey = Get-MasterKey -Passphrase $pass -Salt $salt -KeyFile $keyBytes
$sw.Stop()
Write-Host ('     ✅ 完成，耗时 ' + $sw.ElapsedMilliseconds + ' ms') -ForegroundColor Green

# ---- 打包受保护内容 ----
Write-Host ''
Write-Host '  打包受保护内容...' -ForegroundColor Gray
Add-Type -AssemblyName System.IO.Compression.FileSystem

$tmpZip = Join-Path $env:TEMP ('tally-pack-' + [guid]::NewGuid().ToString('N') + '.zip')
if (Test-Path $tmpZip) { Remove-Item $tmpZip -Force }

$fileList = @()
$zip = [System.IO.Compression.ZipFile]::Open($tmpZip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($t in $targets) {
        $relBase = $t.Substring($PackRoot.Length).TrimStart('\')
        foreach ($f in (Get-ChildItem $t -Recurse -File)) {
            $rel = $f.FullName.Substring($PackRoot.Length).TrimStart('\')
            $entryName = $rel.Replace('\','/')
            $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
            $es = $entry.Open()
            $bytes = [IO.File]::ReadAllBytes($f.FullName)
            $es.Write($bytes, 0, $bytes.Length)
            $es.Dispose()
            $fileList += [pscustomobject]@{
                path   = $rel
                bytes  = $f.Length
                sha256 = (ConvertTo-Hex (Get-BytesSha256 $bytes))
            }
        }
    }
} finally { $zip.Dispose() }

$zipBytes = [IO.File]::ReadAllBytes($tmpZip)
$zipHash  = ConvertTo-Hex (Get-BytesSha256 $zipBytes)
Write-Host ('     ✅ 打包 ' + $fileList.Count + ' 个文件，' + [math]::Round($zipBytes.Length/1KB,1) + ' KB') -ForegroundColor Green

# ---- 加密 ----
Write-Host ''
Write-Host '  加密...' -ForegroundColor Gray
$blob = Protect-Bytes -Plaintext $zipBytes -MasterKey $masterKey -Salt $salt
[IO.File]::WriteAllBytes($EncFile, $blob)
Remove-Item $tmpZip -Force
Write-Host ('     ✅ 已写入: ' + $EncFile + '  (' + [math]::Round($blob.Length/1KB,1) + ' KB)') -ForegroundColor Green

# ---- 清单 ----
$mf = [ordered]@{
    system      = 'tiger-tally'
    version     = '1.0.0'
    created     = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
    algorithm   = 'AES-256-CBC + HMAC-SHA256 (encrypt-then-MAC)'
    kdf         = ('PBKDF2-HMAC-SHA256, ' + $script:Pbkdf2Iter + ' iterations')
    tally       = 'two-factor: passphrase (not stored) + tally.key (stored separately)'
    encFile     = 'PROTECTED.enc'
    plainZipSha = $zipHash
    entries     = $fileList.Count
    files       = $fileList
}
[IO.File]::WriteAllText($Manifest, ($mf | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))

# ---- 清理 ----
$keyBytes = $null; $masterKey = $null; $blob = $null; $zipBytes = $null
[GC]::Collect()

# ---- 完成提示 ----
Write-Host ''
Write-Host '════════════════════════════════════════' -ForegroundColor Green
Write-Host '  ✅ 虎符系统初始化完成' -ForegroundColor Green
Write-Host '════════════════════════════════════════' -ForegroundColor Green
Write-Host ''
Write-Host '  ★★★ 现在立刻做这件事 ★★★' -ForegroundColor Yellow -BackgroundColor DarkRed
Write-Host ''
Write-Host '  把密钥文件备份到【与包分离】的安全位置：' -ForegroundColor Yellow
Write-Host ('     ' + $KeyFile) -ForegroundColor White
Write-Host ''
Write-Host '   建议：U 盘 / 密码管理器 / 加密云盘' -ForegroundColor DarkGray
Write-Host '   ⚠️  不要放在同一个文件夹里（那等于没有双因子）' -ForegroundColor Red
Write-Host '   ⚠️  丢失密钥文件 + 忘记口令 = 数据永久丢失' -ForegroundColor Red
Write-Host ''
Write-Host ('  加密文件: ' + $EncFile) -ForegroundColor Gray
Write-Host ('  清单文件: ' + $Manifest) -ForegroundColor Gray
Write-Host ('  受保护文件数: ' + $fileList.Count) -ForegroundColor Gray
Write-Host ''
Write-Host '  下一步：' -ForegroundColor Cyan
Write-Host '     .\verify-tally.ps1     校验完整性' -ForegroundColor Gray
Write-Host '     .\unlock.ps1           解锁使用' -ForegroundColor Gray
Write-Host ''
