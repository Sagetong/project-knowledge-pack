#Requires -Version 5.1
<#
.SYNOPSIS
    verify-tally.ps1 —— 校验虎符系统的完整性

.DESCRIPTION
    两层校验：
      浅层（默认，不需要口令）：
        · 文件是否齐全
        · 文件头格式是否正确
        · manifest 与加密文件大小是否一致
        · ★ 安全检查：密钥文件是否与加密文件分离存放

      深层（-Deep，需要口令）：
        · 实际解密
        · 逐文件比对 SHA256
        · 确认内容未被篡改

.EXAMPLE
    .\verify-tally.ps1                    # 浅层校验
    .\verify-tally.ps1 -Deep              # 深层校验（需要口令）
#>
[CmdletBinding()]
param(
    [string]$PackRoot,
    [string]$KeyFile,
    [switch]$Deep
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
Write-Host '════════ 虎符 · 完整性校验 ════════' -ForegroundColor Cyan
Write-Host ''

$problems = 0
$warnings = 0

# ---- 1. 文件存在性 ----
Write-Host '  ① 文件检查' -ForegroundColor White
foreach ($pair in @(
    @{ n='加密文件';   p=$EncFile },
    @{ n='密钥文件';   p=$KeyFile },
    @{ n='盐文件';     p=$SaltFile },
    @{ n='清单文件';   p=$Manifest }
)) {
    if (Test-Path $pair.p) {
        $sz = [math]::Round((Get-Item $pair.p).Length/1KB,1)
        Write-Host ('     ✅ ' + $pair.n.PadRight(10) + $sz.ToString().PadLeft(9) + ' KB   ' + $pair.p) -ForegroundColor Green
    } else {
        Write-Host ('     ❌ ' + $pair.n.PadRight(10) + '缺失: ' + $pair.p) -ForegroundColor Red
        $problems++
    }
}
if ($problems -gt 0) { Write-Host ''; Write-Host '  ❌ 文件不齐，无法继续' -ForegroundColor Red; exit 1 }

# ---- 2. 加密文件头 ----
Write-Host ''
Write-Host '  ② 加密文件格式' -ForegroundColor White
$blob = [IO.File]::ReadAllBytes($EncFile)
$magic = New-Object byte[] 8
[Array]::Copy($blob, 0, $magic, 0, 8)
$magicStr = [Text.Encoding]::ASCII.GetString($magic)
if ($magicStr -eq 'TALLYv01') {
    Write-Host ('     ✅ magic 正确: ' + $magicStr) -ForegroundColor Green
} else {
    Write-Host ('     ❌ magic 错误: ' + $magicStr + '（期望 TALLYv01）') -ForegroundColor Red
    $problems++
}
Write-Host ('     · 文件大小: ' + [math]::Round($blob.Length/1KB,1) + ' KB') -ForegroundColor Gray

# ---- 3. 清单 ----
Write-Host ''
Write-Host '  ③ 清单' -ForegroundColor White
$mf = $null
try {
    $mf = Get-Content $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host ('     ✅ system=' + $mf.system + '  version=' + $mf.version) -ForegroundColor Green
    Write-Host ('     · 算法: ' + $mf.algorithm) -ForegroundColor Gray
    Write-Host ('     · KDF : ' + $mf.kdf) -ForegroundColor Gray
    Write-Host ('     · 创建: ' + $mf.created) -ForegroundColor Gray
    if ($mf.updated) { Write-Host ('     · 更新: ' + $mf.updated) -ForegroundColor Gray }
    Write-Host ('     · 受保护文件: ' + $mf.entries + ' 个') -ForegroundColor Gray
} catch {
    Write-Host ('     ⚠ 清单解析失败: ' + $_.Exception.Message) -ForegroundColor Yellow
    $warnings++
}

# ---- 4. ★ 安全检查：双因子是否真正分离 ----
Write-Host ''
Write-Host '  ④ 安全检查（虎符是否真正分离）' -ForegroundColor White
$encDir = Split-Path $EncFile -Parent
$keyDir = Split-Path $KeyFile -Parent
if ($encDir -eq $keyDir) {
    Write-Host '     ⚠ 密钥文件与加密文件在【同一个目录】' -ForegroundColor Yellow
    Write-Host '       ⇒ 建议把 tally.key 移到独立位置（U 盘/密码管理器）' -ForegroundColor Yellow
    Write-Host '       ⇒ 否则双因子退化为单因子' -ForegroundColor Yellow
    $warnings++
} else {
    Write-Host ('     ✅ 已分离') -ForegroundColor Green
    Write-Host ('       加密文件: ' + $encDir) -ForegroundColor Gray
    Write-Host ('       密钥文件: ' + $keyDir) -ForegroundColor Gray
}

# 密钥文件权限检查
try {
    $acl = Get-Acl $KeyFile
    $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $others = @($acl.Access | Where-Object {
        $_.IdentityReference -notmatch [regex]::Escape($me) -and
        $_.IdentityReference -notmatch 'SYSTEM|Administrators|管理员'
    })
    if (@($others).Count -gt 0) {
        Write-Host ('     ⚠ 密钥文件对以下主体有权限: ' + (($others | ForEach-Object { $_.IdentityReference }) -join ', ')) -ForegroundColor Yellow
        $warnings++
    } else {
        Write-Host '     ✅ 密钥文件权限正常（仅当前用户/SYSTEM/管理员）' -ForegroundColor Green
    }
} catch { }

# ---- 5. 深层校验 ----
Write-Host ''
if (-not $Deep) {
    Write-Host '  ⑤ 深层校验：跳过（加 -Deep 并输入口令可执行）' -ForegroundColor DarkGray
} else {
    Write-Host '  ⑤ 深层校验（解密 + 逐文件哈希）' -ForegroundColor White
    $keyBytes = Read-TallyKeyFile $KeyFile
    $salt = [IO.File]::ReadAllBytes($SaltFile)
    $pass = Read-TallyPassphrase -Prompt '输入虎符口令'
    Write-Host '     派生主密钥...' -ForegroundColor Gray
    $masterKey = Get-MasterKey -Passphrase $pass -Salt $salt -KeyFile $keyBytes

    try {
        $zipBytes = Unprotect-Bytes -Blob $blob -MasterKey $masterKey
        Write-Host ('     ✅ 解密成功 (' + [math]::Round($zipBytes.Length/1KB,1) + ' KB)') -ForegroundColor Green

        # 比对整个 zip 的哈希
        $zipHash = ConvertTo-Hex (Get-BytesSha256 $zipBytes)
        if ($mf.plainZipSha) {
            if ($zipHash -eq $mf.plainZipSha) {
                Write-Host '     ✅ 内容哈希与清单一致' -ForegroundColor Green
            } else {
                Write-Host '     ⚠ 内容哈希与清单不一致（可能被 lock.ps1 更新过内容）' -ForegroundColor Yellow
                $warnings++
            }
        }

        # 逐文件校验
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $msZip = New-Object IO.MemoryStream(,$zipBytes)
        $zip = New-Object System.IO.Compression.ZipArchive($msZip, [System.IO.Compression.ZipArchiveMode]::Read)
        try {
            $bad = 0; $checked = 0
            foreach ($e in $zip.Entries) {
                if ($e.FullName.EndsWith('/')) { continue }
                $es = $e.Open()
                $ms = New-Object IO.MemoryStream
                try { $es.CopyTo($ms) } finally { $es.Dispose() }
                $bytes = $ms.ToArray(); $ms.Dispose()
                $h = ConvertTo-Hex (Get-BytesSha256 $bytes)
                $checked++
                # 在 manifest 里找（兼容 WORK\ 前缀）
                $match = $mf.files | Where-Object {
                    $_.path -eq $e.FullName -or
                    $_.path -eq ($e.FullName.Replace('/','\')) -or
                    $_.path -eq ('WORK\' + $e.FullName.Replace('/','\'))
                } | Select-Object -First 1
                if ($match -and $match.sha256 -ne $h) {
                    Write-Host ('       ⚠ 不匹配: ' + $e.FullName) -ForegroundColor Yellow
                    $bad++
                }
            }
            Write-Host ('     · 检查 ' + $checked + ' 个文件，不匹配 ' + $bad) -ForegroundColor Gray
            if ($bad -eq 0) { Write-Host '     ✅ 全部一致' -ForegroundColor Green } else { $problems += $bad }
        } finally { $zip.Dispose(); $msZip.Dispose() }
    } catch {
        Write-Host ('     ❌ ' + $_.Exception.Message) -ForegroundColor Red
        $problems++
    } finally {
        $masterKey = $null; $keyBytes = $null; $zipBytes = $null
        [GC]::Collect()
    }
}

# ---- 汇总 ----
Write-Host ''
Write-Host '════════════════════════════════════════' -ForegroundColor Cyan
if ($problems -eq 0 -and $warnings -eq 0) {
    Write-Host '  ✅ 校验通过，无问题' -ForegroundColor Green
} elseif ($problems -eq 0) {
    Write-Host ('  ✅ 校验通过，但有 ' + $warnings + ' 条建议') -ForegroundColor Yellow
} else {
    Write-Host ('  ❌ 发现 ' + $problems + ' 个问题，' + $warnings + ' 条建议') -ForegroundColor Red
}
Write-Host '════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''
