# check-variable-names.ps1 —— 扫描 .ps1 里可能发生大小写碰撞的变量名
#
# 建立者: DSH   时间: 2026-10-08
#
# 为什么需要它:
#   PowerShell 变量名【大小写不敏感】，$rel 会覆盖 $REL，$doc 会覆盖 $Doc。
#   本机在 2026-10-07 与 2026-10-08 共踩了 4 次，每次都造成误判
#   （最近一次：比较脚本里 $REL 被 $rel 覆盖，误报 25 个文件"缺失"）。
#   光靠"记住"没有效果，所以做成工具。
#
# 它判什么:
#   同一个文件里，是否存在【两个变量，名字只有大小写不同】。
#   这类组合一旦出现，后赋值的一定会覆盖先赋值的。
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File check-variable-names.ps1 -Path <文件或目录>

param(
    [Parameter(Mandatory = $true)][string]$Path
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$filesToScan = @()
if (Test-Path -LiteralPath $Path -PathType Container) {
    $filesToScan = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Filter '*.ps1' -ErrorAction SilentlyContinue)
} elseif (Test-Path -LiteralPath $Path -PathType Leaf) {
    $filesToScan = @(Get-Item -LiteralPath $Path)
} else {
    Write-Host ('[错误] 找不到: ' + $Path)
    exit 2
}

$totalIssues = 0
foreach ($scanFile in $filesToScan) {
    $rawText = [System.IO.File]::ReadAllText($scanFile.FullName, [System.Text.Encoding]::UTF8)

    # ⚠️ 必须先剔除注释，否则【注释里为了说明这个坑而举的例子】会被当成真变量。
    # 本检查器第一次跑时就误报了自己 —— 因为注释里写着 "$rel 会覆盖 $REL"。
    $text = [regex]::Replace($rawText, '(?s)<#.*?#>', '')   # 去掉块注释 <# ... #>

    # 去掉行内注释：逐行扫描，遇到第一个【不在引号内】的 # 就截断该行
    $keptLines = New-Object System.Collections.ArrayList
    foreach ($lineText in ($text -split "`r?`n")) {
        $inSingle = $false
        $inDouble = $false
        $cutAt = -1
        for ($ci = 0; $ci -lt $lineText.Length; $ci++) {
            $ch = $lineText[$ci]
            if ($ch -eq "'" -and -not $inDouble) { $inSingle = -not $inSingle }
            elseif ($ch -eq '"' -and -not $inSingle) { $inDouble = -not $inDouble }
            elseif ($ch -eq '#' -and -not $inSingle -and -not $inDouble) { $cutAt = $ci; break }
        }
        if ($cutAt -ge 0) { [void]$keptLines.Add($lineText.Substring(0, $cutAt)) }
        else { [void]$keptLines.Add($lineText) }
    }
    $text = $keptLines -join "`r`n"

    # 收集所有 $变量名（含 $script:xxx 形式）
    $names = @{}
    foreach ($m in [regex]::Matches($text, '\$(?:script:|global:|local:)?([A-Za-z_][A-Za-z0-9_]*)')) {
        $n = $m.Groups[1].Value
        if (-not $names.ContainsKey($n.ToLower())) { $names[$n.ToLower()] = @() }
        # 注意：必须用 -cnotcontains（区分大小写）。用 -notcontains 的话，
        # a lowercase form would be judged as already present, so the real
        # collision is missed -- the checker itself first failed exactly here,
        # because PowerShell comparison operators are case-insensitive by default.
        if ($names[$n.ToLower()] -cnotcontains $n) { $names[$n.ToLower()] += $n }
    }

    $collisions = @()
    foreach ($kv in $names.GetEnumerator()) {
        if (@($kv.Value).Count -gt 1) {
            $collisions += (($kv.Value | Sort-Object) -join ' / ')
        }
    }

    if (@($collisions).Count -gt 0) {
        Write-Host ('[碰撞] ' + $scanFile.FullName)
        $collisions | ForEach-Object { Write-Host ('         ' + $_) }
        $totalIssues += @($collisions).Count
    }
}

Write-Host ''
if ($totalIssues -eq 0) {
    Write-Host ('OK 扫描了 ' + $filesToScan.Count + ' 个 .ps1，没有发现大小写碰撞的变量名')
    exit 0
} else {
    Write-Host ('[!!] 发现 ' + $totalIssues + ' 组可能碰撞的变量名，请改名（路径类加后缀）')
    exit 1
}