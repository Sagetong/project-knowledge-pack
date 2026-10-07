#Requires -Version 5.1
<#
.SYNOPSIS
    lock.ps1 —— 重新上锁：把明文重新加密，并安全清理

.DESCRIPTION
    解锁后明文会释放到 WORK\ 目录。用完必须上锁，否则加密就白做了。

    本脚本做四件事：
      ① 用虎符重新加密 WORK\ 的内容
      ② 覆盖写 + 删除 WORK\ 中的明文
      ③ 更新 manifest.json
      ④ 清空内存中的密钥

.EXAMPLE
    .\lock.ps1                          # 用默认 WORK\ 目录重新加密并清理
    .\lock.ps1 -WorkDir C:\temp\core    # 指定明文目录
    .\lock.ps1 -NoWipe                  # 不擦除明文（调试用，不推荐）
#>
[CmdletBinding()]
param(
    [string]$PackRoot,
    [string]$KeyFile,
    [string]$WorkDir,
    [switch]$NoWipe,
    [switch]$KeepPlaintext
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tally-lib.ps1')

if (-not $PackRoot) { $PackRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }

$TallyDir = Join-Path $PackRoot 'tally'
$EncFile  = Join-Path $PackRoot 'PROTECTED.enc'
if (-not $KeyFile) { $KeyFile = Join-Path $TallyDir 'tally.key' }
$SaltFile = Join-Path $TallyDir 'salt.bin'
$Manifest = Join-Path $TallyDir 'manifest.json'
if (-not $WorkDir) { $WorkDir = Join-Path $PackRoot 'WORK' }

Write-Host ''
Write-Host '════════ 虎符 · 上锁 ════════' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path $WorkDir)) { Write-Host ('  ❌ 找不到明文目录 ' + $WorkDir) -ForegroundColor Red; exit 1 }
if (-not (Test-Path $KeyFile)) { Write-Host ('  ❌ 找不到密钥文件 ' + $KeyFile) -ForegroundColor Red; exit 1 }

$files = @(Get-ChildItem $WorkDir -Recurse -File)
Write-Host ('  明文目录 : ' + $WorkDir) -ForegroundColor Gray
Write-Host ('  文件数   : ' + $files.Count) -ForegroundColor Gray
Write-Host ''

if ($files.Count -eq 0) { Write-Host '  ⚠ 目录为空，无需上锁' -ForegroundColor Yellow; exit 0 }

# ---- 虎符 ----
$keyBytes = Read-TallyKeyFile $KeyFile
$salt     = [IO.File]::ReadAllBytes($SaltFile)
$pass     = Read-TallyPassphrase -Prompt '输入虎符口令'

Write-Host ''
Write-Host '  派生主密钥...' -ForegroundColor Gray
$masterKey = Get-MasterKey -Passphrase $pass -Salt $salt -KeyFile $keyBytes
Write-Host '     ✅' -ForegroundColor Green

# ---- 打包 ----
Write-Host '  打包...' -ForegroundColor Gray
Add-Type -AssemblyName System.IO.Compression.FileSystem
$tmpZip = Join-Path $env:TEMP ('tally-lock-' + [guid]::NewGuid().ToString('N') + '.zip')

$fileList = @()
$zip = [System.IO.Compression.ZipFile]::Open($tmpZip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($WorkDir.Length).TrimStart('\')
        $entryName = $rel.Replace('\','/')
        $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
        $es = $entry.Open()
        $bytes = [IO.File]::ReadAllBytes($f.FullName)
        $es.Write($bytes, 0, $bytes.Length)
        $es.Dispose()
        $fileList += [pscustomobject]@{
            path   = ('WORK\' + $rel)
            bytes  = $f.Length
            sha256 = (ConvertTo-Hex (Get-BytesSha256 $bytes))
        }
    }
} finally { $zip.Dispose() }

$zipBytes = [IO.File]::ReadAllBytes($tmpZip)
$zipHash  = ConvertTo-Hex (Get-BytesSha256 $zipBytes)
Write-Host ('     ✅ ' + $fileList.Count + ' 个文件, ' + [math]::Round($zipBytes.Length/1KB,1) + ' KB') -ForegroundColor Green

# ---- 加密 ----
Write-Host '  加密...' -ForegroundColor Gray
$blob = Protect-Bytes -Plaintext $zipBytes -MasterKey $masterKey -Salt $salt
[IO.File]::WriteAllBytes($EncFile, $blob)
Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
Write-Host ('     ✅ 已写入 ' + $EncFile + '  (' + [math]::Round($blob.Length/1KB,1) + ' KB)') -ForegroundColor Green

# ---- 更新清单（保留原有条目 + 追加本次）----
if (Test-Path $Manifest) {
    $mf = Get-Content $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $mf = [pscustomobject]@{ system='tiger-tally'; version='1.0.0'; created=(Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'); files=@() }
}
$existing = @{}
foreach ($x in $mf.files) { $existing[$x.path] = $x }
foreach ($x in $fileList) { $existing[$x.path] = $x }
$out = [ordered]@{
    system      = 'tiger-tally'
    version     = '1.0.0'
    created     = $mf.created
    updated     = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
    algorithm   = 'AES-256-CBC + HMAC-SHA256 (encrypt-then-MAC)'
    kdf         = ('PBKDF2-HMAC-SHA256, ' + $script:Pbkdf2Iter + ' iterations')
    tally       = 'two-factor: passphrase (not stored) + tally.key (stored separately)'
    encFile     = 'PROTECTED.enc'
    plainZipSha = $zipHash
    entries     = $existing.Count
    files       = @($existing.Values)
}
[IO.File]::WriteAllText($Manifest, ($out | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
Write-Host '     ✅ 清单已更新' -ForegroundColor Green

# ---- 安全擦除明文 ----
if (-not $NoWipe -and -not $KeepPlaintext) {
    Write-Host ''
    Write-Host '  安全擦除明文（覆盖写 3 遍）...' -ForegroundColor Gray
    $wiped = 0
    foreach ($f in $files) {
        try {
            if ($f.Length -gt 0) {
                $fs = [IO.File]::Open($f.FullName, 'Open', 'Write')
                try {
                    $len = $f.Length
                    for ($pass = 0; $pass -lt 3; $pass++) {
                        $fs.Position = 0
                        $chunk = New-Object byte[] ([Math]::Min(1048576, [Math]::Max(1,$len)))
                        $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
                        $remaining = $len
                        while ($remaining -gt 0) {
                            $take = [Math]::Min($chunk.Length, $remaining)
                            $rng.GetBytes($chunk)
                            $fs.Write($chunk, 0, $take)
                            $remaining -= $take
                        }
                        $fs.Flush($true)
                    }
                    $rng.Dispose()
                } finally { $fs.Dispose() }
            }
            Remove-Item $f.FullName -Force
            $wiped++
        } catch {
            Write-Host ('     ⚠ 无法擦除: ' + $f.FullName) -ForegroundColor Yellow
        }
    }
    # 删空目录
    Get-ChildItem $WorkDir -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
        try { if (@(Get-ChildItem $_.FullName -Force).Count -eq 0) { Remove-Item $_.FullName -Force } } catch {}
    }
    try { if (@(Get-ChildItem $WorkDir -Force).Count -eq 0) { Remove-Item $WorkDir -Force } } catch {}
    Write-Host ('     ✅ 已擦除 ' + $wiped + ' 个文件') -ForegroundColor Green
}

# ---- 清理内存 ----
$masterKey = $null; $keyBytes = $null; $blob = $null; $zipBytes = $null
[GC]::Collect()

Write-Host ''
Write-Host '════════════════════════════════════════' -ForegroundColor Green
Write-Host '  ✅ 已上锁' -ForegroundColor Green
Write-Host '════════════════════════════════════════' -ForegroundColor Green
Write-Host ''
