#Requires -Version 5.1
<#
.SYNOPSIS
    unlock.ps1 —— 用虎符解锁受保护层

.DESCRIPTION
    需要两半：
      左半 = 口令（你输入）
      右半 = tally.key（你提供路径）
    缺任何一半都无法解密。

.EXAMPLE
    .\unlock.ps1 -List                      # 只看里面有什么，不解密到磁盘
    .\unlock.ps1                            # 解密到 WORK\ 目录
    .\unlock.ps1 -OutDir C:\temp\core       # 解密到指定目录
    .\unlock.ps1 -KeyFile <密钥文件>      # 指定密钥文件位置
    .\unlock.ps1 -Extract core\security.json -OutDir C:\temp   # 只提取一个文件
#>
[CmdletBinding()]
param(
    [string]$PackRoot,
    [string]$KeyFile,
    [string]$OutDir,
    [string]$Extract,
    [switch]$List,
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

Write-Host ''
Write-Host '════════ 虎符 · 解锁 ════════' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path $EncFile)) { Write-Host ('  ❌ 找不到 ' + $EncFile) -ForegroundColor Red; exit 1 }
if (-not (Test-Path $KeyFile)) { Write-Host ('  ❌ 找不到密钥文件 ' + $KeyFile) -ForegroundColor Red; exit 1 }
if (-not (Test-Path $SaltFile)){ Write-Host ('  ❌ 找不到 ' + $SaltFile) -ForegroundColor Red; exit 1 }

Write-Host ('  加密文件 : ' + $EncFile) -ForegroundColor Gray
Write-Host ('  密钥文件 : ' + $KeyFile) -ForegroundColor Gray
Write-Host ''

# ---- 读虎符两半 ----
$keyBytes = Read-TallyKeyFile $KeyFile
$salt     = [IO.File]::ReadAllBytes($SaltFile)
$pass     = Read-TallyPassphrase -Prompt '输入虎符口令'

Write-Host ''
Write-Host '  派生主密钥...' -ForegroundColor Gray
$sw = [Diagnostics.Stopwatch]::StartNew()
$masterKey = Get-MasterKey -Passphrase $pass -Salt $salt -KeyFile $keyBytes
$sw.Stop()
Write-Host ('     ✅ ' + $sw.ElapsedMilliseconds + ' ms') -ForegroundColor Green

# ---- 解密 ----
Write-Host '  解密...' -ForegroundColor Gray
$blob = [IO.File]::ReadAllBytes($EncFile)
try {
    $zipBytes = Unprotect-Bytes -Blob $blob -MasterKey $masterKey
} catch {
    Write-Host ''
    Write-Host ('  ❌ ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ''
    Write-Host '  可能原因：' -ForegroundColor Yellow
    Write-Host '     · 口令输错了' -ForegroundColor Yellow
    Write-Host '     · 密钥文件不是这一份' -ForegroundColor Yellow
    Write-Host '     · 加密文件被篡改' -ForegroundColor Yellow
    Write-Host ''
    $masterKey = $null; $keyBytes = $null
    [GC]::Collect()
    exit 1
}
Write-Host ('     ✅ 解密成功，' + [math]::Round($zipBytes.Length/1KB,1) + ' KB') -ForegroundColor Green

# ---- 释放到内存 zip ----
Add-Type -AssemblyName System.IO.Compression.FileSystem
$msZip = New-Object IO.MemoryStream(,$zipBytes)
$zip = New-Object System.IO.Compression.ZipArchive($msZip, [System.IO.Compression.ZipArchiveMode]::Read)

try {
    # ---- 仅列出 ----
    if ($List) {
        Write-Host ''
        Write-Host ('  内容清单（' + $zip.Entries.Count + ' 个文件）：') -ForegroundColor Cyan
        Write-Host ''
        foreach ($e in ($zip.Entries | Sort-Object FullName)) {
            Write-Host ('    ' + $e.FullName.PadRight(60) + ([math]::Round($e.Length/1KB,1)).ToString().PadLeft(8) + ' KB')
        }
        Write-Host ''
        exit 0
    }

    # ---- 只提取一个 ----
    if ($Extract) {
        $target = $Extract.Replace('\','/')
        $entry = $zip.Entries | Where-Object { $_.FullName -eq $target -or $_.FullName -like ('*' + $target) } | Select-Object -First 1
        if (-not $entry) { Write-Host ('  ❌ 未找到: ' + $Extract) -ForegroundColor Red; exit 1 }
        if (-not $OutDir) { $OutDir = Join-Path $PackRoot 'WORK' }
        if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
        $dest = Join-Path $OutDir (Split-Path $entry.FullName -Leaf)
        $es = $entry.Open()
        $fs = [IO.File]::Create($dest)
        try { $es.CopyTo($fs) } finally { $fs.Dispose(); $es.Dispose() }
        Write-Host ''
        Write-Host ('  ✅ 已提取: ' + $dest) -ForegroundColor Green
        Write-Host ''
        exit 0
    }

    # ---- 全部解压 ----
    if (-not $OutDir) { $OutDir = Join-Path $PackRoot 'WORK' }
    if (Test-Path $OutDir) {
        Write-Host ''
        Write-Host ('  ⚠ 目标目录已存在: ' + $OutDir) -ForegroundColor Yellow
        $ans = Read-Host '  覆盖？(yes/no)'
        if ($ans -ne 'yes') { Write-Host '  已取消。' -ForegroundColor Gray; exit 1 }
        Remove-Item $OutDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

    $n = 0
    foreach ($e in $zip.Entries) {
        if ($e.FullName.EndsWith('/')) { continue }
        $dest = Join-Path $OutDir ($e.FullName.Replace('/','\'))
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        $es = $e.Open()
        $fs = [IO.File]::Create($dest)
        try { $es.CopyTo($fs) } finally { $fs.Dispose(); $es.Dispose() }
        $n++
    }

    Write-Host ''
    Write-Host ('  ✅ 已解压 ' + $n + ' 个文件到: ' + $OutDir) -ForegroundColor Green

    # ---- 完整性校验 ----
    if (Test-Path $Manifest) {
        Write-Host ''
        Write-Host '  校验文件完整性...' -ForegroundColor Gray
        $mf = Get-Content $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
        $bad = 0
        foreach ($f in $mf.files) {
            $p = Join-Path $PackRoot $f.path
            if (-not (Test-Path $p)) { continue }
            $h = ConvertTo-Hex (Get-BytesSha256 ([IO.File]::ReadAllBytes($p)))
            if ($h -ne $f.sha256) { Write-Host ('    ⚠ 不匹配: ' + $f.path) -ForegroundColor Yellow; $bad++ }
        }
        if ($bad -eq 0) { Write-Host '    ✅ 全部匹配' -ForegroundColor Green }
        else { Write-Host ('    ⚠ ' + $bad + ' 个文件不匹配') -ForegroundColor Yellow }
    }

    Write-Host ''
    Write-Host '  ⚠ 提醒：明文现已释放到磁盘。' -ForegroundColor Yellow
    Write-Host '     使用完毕后运行 .\lock.ps1 重新上锁并清理。' -ForegroundColor Yellow
    Write-Host ''
} finally {
    $zip.Dispose(); $msZip.Dispose()
    $masterKey = $null; $keyBytes = $null; $blob = $null; $zipBytes = $null
    [GC]::Collect()
}
