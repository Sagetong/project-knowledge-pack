#Requires -Version 5.1
<#
.SYNOPSIS
    sync-pack.ps1 —— 把经验包从工作副本镜像同步到一个查看副本

.DESCRIPTION
    工作副本（AI 读写）: 脚本所在目录的上一级（即经验包根目录）
    目标（镜像）  : 由参数 -Dest 指定，或读 30-工具\mirror.config

    单向镜像：工作副本 → 查看副本
      · 复制新增和变更的文件
      · 删除查看副本里多出来的文件（保持镜像一致）
      · 记录日志

    触发方式：
      ① AI 写入经验后（harvest.ps1 / memory.ps1 自动调用）
      ② 登录时由「启动」文件夹的 AI系统开机自检 兜底（已废弃周期任务）

.EXAMPLE
    .\sync-pack.ps1                 正常同步
    .\sync-pack.ps1 -WhatIf         只显示会做什么，不改文件
    .\sync-pack.ps1 -Quiet          只在有变化时输出

.NOTES
    2026-10-07 修复两次：
    ① 原来在 param 之前插了一行 $PackRoot 赋值，导致 PowerShell 报
       "Unexpected attribute 'CmdletBinding'"。param 必须是第一条语句。
    ② 改成 param 默认值里用 $PSScriptRoot 推导后，PS 5.1 在 param 绑定
       阶段 $PSScriptRoot 还是空的，报 "Cannot bind argument to Path"。
       最终方案：param 里不推导，绑定完成后再推导。
#>
[CmdletBinding()]
param(
    [string]$Source,
    [string]$Dest,
    [switch]$WhatIf,
    [switch]$Quiet
)

# 源目录默认 = 脚本所在目录的上一级（经验包根目录）
if ([string]::IsNullOrEmpty($Source)) {
    $Source = Split-Path $PSScriptRoot -Parent
}

# ---------------------------------------------------------------------------
# 目标目录解析：参数 > 配置文件 > 跳过
#
# 2026-10-07 修正。原来这里默认值是作者的绝对路径，脱敏后变成字面量
# "$env:USERPROFILE\agents\_archive\查看副本-工作母版"。PowerShell 不展开
# %VAR%，所以它被当成一个相对路径，会以【当前工作目录】为基准创建一个
# 真的叫 "$env:USERPROFILE" 的文件夹并把整包复制进去 —— 制造垃圾且报成功。
#
# 现在刻意【不猜路径】。因为猜错会静默制造垃圾目录。
# 宁可安静跳过，也不要替使用者决定往哪里写。
# ---------------------------------------------------------------------------
if ([string]::IsNullOrEmpty($Dest)) {
    $cfg = Join-Path $PSScriptRoot 'mirror.config'
    if (Test-Path $cfg) {
        $line = Get-Content $cfg -Encoding UTF8 -ErrorAction SilentlyContinue |
                Where-Object { $_ -and -not $_.TrimStart().StartsWith('#') } |
                Select-Object -First 1
        if ($line) { $Dest = $line.Trim() }
    }
}

if ([string]::IsNullOrEmpty($Dest)) {
    if (-not $Quiet) {
        Write-Host ''
        Write-Host '════════ 经验包同步 ════════' -ForegroundColor Cyan
        Write-Host '  未配置镜像目录，跳过（这是正常状态）。' -ForegroundColor DarkGray
        Write-Host '  如需启用：' -ForegroundColor DarkGray
        Write-Host '    · 运行时加参数   -Dest "D:\你想放的位置"' -ForegroundColor DarkGray
        Write-Host '    · 或在本目录新建 mirror.config，第一行写目标路径' -ForegroundColor DarkGray
        Write-Host ''
    }
    exit 0
}

$ErrorActionPreference = 'Continue'

function Say($msg, $color = 'Gray') {
    if (-not $Quiet -or $color -ne 'Gray') { Write-Host $msg -ForegroundColor $color }
}

if (-not (Test-Path $Source)) {
    Say ("[ERROR] 源目录不存在: " + $Source) 'Red'
    exit 1
}

# 源目录绝不能被当成目标
if ($Source.TrimEnd('\') -eq $Dest.TrimEnd('\')) {
    Say '[ERROR] 源和目标相同，拒绝执行' 'Red'
    exit 1
}

$logFile = Join-Path $Source '20-历史经验\data\sync.log'

Say ''
Say '════════ 经验包同步 ════════' 'Cyan'
Say ('  源  : ' + $Source) 'DarkGray'
Say ('  目标: ' + $Dest)   'DarkGray'
Say ''

# ---- 收集两边的文件（相对路径 → 信息）----
function Get-FileMap($root) {
    $map = @{}
    if (-not (Test-Path $root)) { return $map }
    foreach ($f in (Get-ChildItem $root -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        $rel = $f.FullName.Substring($root.Length).TrimStart('\')
        # 日志文件本身不参与同步
        if ($rel -eq '20-历史经验\data\sync.log') { continue }
        $map[$rel] = [pscustomobject]@{
            Full = $f.FullName
            Size = $f.Length
            Time = $f.LastWriteTimeUtc
        }
    }
    return $map
}

$srcMap = Get-FileMap $Source
$dstMap = Get-FileMap $Dest

Say ('  源文件数  : ' + $srcMap.Count)
Say ('  目标文件数: ' + $dstMap.Count)
Say ''

if (-not (Test-Path $Dest)) {
    if (-not $WhatIf) {
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null
        Say ('  [创建目标目录] ' + $Dest) 'Yellow'
    }
}

$added = 0; $updated = 0; $removed = 0; $same = 0
$changes = @()

# ---- 复制新增 / 变更 ----
foreach ($rel in $srcMap.Keys) {
    $s = $srcMap[$rel]
    $d = if ($dstMap.ContainsKey($rel)) { $dstMap[$rel] } else { $null }
    $target = Join-Path $Dest $rel

    if ($null -eq $d) {
        $changes += ('  + ' + $rel)
        if (-not $WhatIf) {
            $td = Split-Path $target -Parent
            if (-not (Test-Path $td)) { New-Item -ItemType Directory -Path $td -Force | Out-Null }
            Copy-Item $s.Full $target -Force
        }
        $added++
    }
    elseif ($s.Size -ne $d.Size -or $s.Time -gt $d.Time) {
        $changes += ('  ~ ' + $rel)
        if (-not $WhatIf) {
            $td = Split-Path $target -Parent
            if (-not (Test-Path $td)) { New-Item -ItemType Directory -Path $td -Force | Out-Null }
            Copy-Item $s.Full $target -Force
        }
        $updated++
    }
    else { $same++ }
}

# ---- 删除目标多出的 ----
foreach ($rel in $dstMap.Keys) {
    if (-not $srcMap.ContainsKey($rel)) {
        $changes += ('  - ' + $rel)
        if (-not $WhatIf) {
            try { Remove-Item $dstMap[$rel].Full -Force -ErrorAction SilentlyContinue } catch {}
        }
        $removed++
    }
}

# ---- 清理目标里的空目录 ----
if (-not $WhatIf -and (Test-Path $Dest)) {
    Get-ChildItem $Dest -Recurse -Directory -ErrorAction SilentlyContinue |
        Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
            if (@(Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0) {
                try { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
}

# ---- 输出 ----
$totalChanged = $added + $updated + $removed
if ($totalChanged -gt 0) {
    Say ('  变化: 新增 ' + $added + ' · 更新 ' + $updated + ' · 删除 ' + $removed) 'Green'
    if (-not $Quiet) {
        foreach ($c in ($changes | Select-Object -First 30)) { Say $c 'DarkGray' }
        if ($changes.Count -gt 30) { Say ('  ...还有 ' + ($changes.Count - 30) + ' 项') 'DarkGray' }
    }
    # 写日志
    if (-not $WhatIf) {
        $line = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  +' + $added + ' ~' + $updated + ' -' + $removed
        try { Add-Content -Path $logFile -Value $line -Encoding UTF8 } catch {}
    }
} else {
    Say ('  无变化（' + $same + ' 个文件已是最新）') 'DarkGray'
}

Say ''
if ($WhatIf) { Say '  [WhatIf] 未实际修改任何文件' 'Yellow' }
exit 0
