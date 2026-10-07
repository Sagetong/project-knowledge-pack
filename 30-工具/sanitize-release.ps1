#Requires -Version 5.1
<#
.SYNOPSIS
    sanitize-release.ps1 —— 对发行版做发布前脱敏

.DESCRIPTION
    母版里必然含作者的本机信息（路径、用户名、机器名、内网 IP 等）。
    sync-to-release.ps1 会把母版的公开层复制到发行版，
    因此【每次同步之后都必须脱敏】，否则隐私会一次次被带回来。

    本脚本由 sync-to-release.ps1 在最后一步自动调用，
    也可以单独手工运行。

    做两件事：
      ① 把可识别到具体个人/机器的信息替换为通用占位符
      ② 剔除绝不该外发的文件（个人凭据、本机工作记录等）

.NOTES
    建立：2026-10-07
    起因：手工脱敏过一次，但下一次同步又全部覆盖回来。
          根治办法是让脱敏成为同步流程的一部分，而不是一次性动作。

    本文件必须保存为 UTF-8 with BOM。
#>
[CmdletBinding()]
param(
    [string]$Release,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = $PSScriptRoot
$PackRoot  = Split-Path $ScriptDir -Parent

if ([string]::IsNullOrEmpty($Release)) {
    $Release = $PackRoot
}

function Say($m) { if (-not $Quiet) { Write-Host $m } }

if (-not (Test-Path $Release)) {
    Write-Host ('[ERROR] 发行版目录不存在: ' + $Release) -ForegroundColor Red
    exit 2
}

Say ''
Say '  ── 发布前脱敏 ──'

# ===========================================================================
#  一、剔除绝不该外发的文件
# ===========================================================================
$neverShip = @(
    # 个人凭据（盐、保险箱、记录密钥指纹的元数据）
    '90-虎符v2\triple-vault-12.bin',
    '90-虎符v2\triple-vault-13.bin',
    '90-虎符v2\triple-vault-23.bin',
    '90-虎符v2\triple-salt.bin',
    '90-虎符v2\triple-meta.json',
    '90-虎符v2\dual-key-salt.bin',
    '90-虎符v2\dual-key-meta.json',
    # 本机工作记录
    'PROGRESS.md',
    'DESKTOP-REGISTRY.md',
    '_身份说明-①工作母版.md',
    '_身份说明-③开源版.md',
    '20-历史经验\data\sync.log'
)
$removed = 0
foreach ($f in $neverShip) {
    $p = Join-Path $Release $f
    if (Test-Path $p) {
        Remove-Item $p -Force -ErrorAction SilentlyContinue
        $removed++
    }
}
# 任何 .bak / .orig 残留
Get-ChildItem $Release -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '\.bak|\.orig$|~$' } |
    ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue; $removed++ }

# 整个不该存在的目录
foreach ($d in @('50-环境档案', '40-Skills\local')) {
    $p = Join-Path $Release $d
    if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue; $removed++ }
}

# 清空本机数据层（保留占位说明）
$localDir = Join-Path $Release '20-历史经验\data\local'
if (Test-Path $localDir) {
    Get-ChildItem $localDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'README.md' } |
        ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue; $removed++ }
}

Say ('    剔除文件/目录: ' + $removed + ' 项')

# ===========================================================================
#  二、文本脱敏
# ===========================================================================
$rules = @(
    @{ Old = '%USERPROFILE%'; New = '%USERPROFILE%' },
    @{ Old = '<信道目录>'; New = '<信道目录>' },
    @{ Old = '<项目盘>';            New = '<项目盘>' },
    @{ Old = '<AI管理器>';      New = '<AI管理器>' },
    @{ Old = '<密钥文件>';           New = '<密钥文件>' }
)

$exts = @('.md', '.json', '.jsonl', '.ps1', '.cmd', '.txt')
$changed = 0

foreach ($f in (Get-ChildItem $Release -Recurse -File -ErrorAction SilentlyContinue)) {
    if ($exts -notcontains $f.Extension.ToLower()) { continue }

    # 按字节读，保留原 BOM 状态与换行风格
    try {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    } catch { continue }
    if ($null -eq $bytes -or $bytes.Length -eq 0) { continue }

    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if ($hasBom) {
        if ($bytes.Length -le 3) { continue }        # 只有 BOM、没有内容
        $body = New-Object byte[] ($bytes.Length - 3)
        [Array]::Copy($bytes, 3, $body, 0, $bytes.Length - 3)
    } else {
        $body = $bytes
    }
    $text = [System.Text.Encoding]::UTF8.GetString($body)
    $orig    = $text

    # 2.1 固定字符串替换
    foreach ($r in $rules) {
        $text = $text.Replace($r.Old, $r.New)
    }

    # 2.2 内网 IP：隐藏主机号
    $text = [regex]::Replace($text, '\b192\.168\.\d{1,3}\.\d{1,3}\b', '192.168.x.x')
    $text = [regex]::Replace($text, '\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b',   '10.x.x.x')

    # 2.3 机器名
    $text = [regex]::Replace($text, '\bROG\\', '<机器名>\')
    $text = [regex]::Replace($text, '(?<![\w<])<机器名>(?![\w>])', '<机器名>')

    # 2.4 用户名裸词（避开已经是占位符的）
    $text = [regex]::Replace($text, '(?<!<)\bAdministrator\b(?!>)', '<用户名>')

    # 2.5 会话 UUID：隐去具体值
    $text = [regex]::Replace($text, '\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b', '<会话标识>')

    if ($text -ne $orig) {
        $out = [System.Text.Encoding]::UTF8.GetBytes($text)
        if ($hasBom) { $out = [byte[]](0xEF, 0xBB, 0xBF) + $out }
        [System.IO.File]::WriteAllBytes($f.FullName, $out)
        $changed++
    }
}

Say ('    脱敏文件: ' + $changed + ' 个')

# ===========================================================================
#  三、自查（发现问题就报出来，不静默通过）
# ===========================================================================
$problems = @()
foreach ($f in (Get-ChildItem $Release -Recurse -File -ErrorAction SilentlyContinue)) {
    if ($exts -notcontains $f.Extension.ToLower()) { continue }
    # 跳过本脚本自身：它里面必然写着待替换的模式字符串，那是规则不是泄露
    if ($f.Name -eq 'sanitize-release.ps1') { continue }
    $t = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $rel = $f.FullName.Substring($Release.Length).TrimStart('\')
    if ($t -match 'C:\\Users\\<用户名>')      { $problems += ('本机路径  ' + $rel) }
    if ($t -match '\b192\.168\.\d{1,3}\.\d{1,3}\b'){ $problems += ('内网IP    ' + $rel) }
    if ($t -match '(?<!<)\bAdministrator\b(?!>)')  { $problems += ('用户名    ' + $rel) }
    if ($t -match '\bROG\b')                       { $problems += ('机器名    ' + $rel) }
    if ($t -match '\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b') { $problems += ('会话UUID  ' + $rel) }
    if ($t -match '-----BEGIN (?:OPENSSH|RSA) PRIVATE KEY-----') { $problems += ('私钥内容  ' + $rel) }
}

if ($problems.Count -gt 0) {
    Say ''
    Say ('    [警告] 仍有 ' + $problems.Count + ' 处敏感信息残留:')
    $problems | Select-Object -First 10 | ForEach-Object { Say ('      ' + $_) }
    Say '    ⇒ 发布前必须处理'
} else {
    Say '    自查: 无敏感信息残留'
}
Say ''
