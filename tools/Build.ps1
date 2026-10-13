<#
.SYNOPSIS
  Copies KingEA sources into the MT5 data folder and compiles them.

.EXAMPLE
  .\tools\Build.ps1
  .\tools\Build.ps1 -Target Scripts\KingEA\TestSleeveEthSt001.mq5
#>
param(
    [string[]]$Target = @('Experts\KingEA\KingEA.mq5')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'KingEA.Common.ps1')

$mql5 = Join-Path $DataDir 'MQL5'
foreach ($folder in 'Include\KingEA', 'Experts\KingEA', 'Scripts\KingEA') {
    $source = Join-Path $RepoRoot "MQL5\$folder"
    $destination = Join-Path $mql5 $folder
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Get-ChildItem -LiteralPath $source -File -Include *.mq5, *.mqh -Recurse |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $destination -Force }
}
$filesDir = Join-Path $mql5 'Files\KingEA'
New-Item -ItemType Directory -Force -Path $filesDir | Out-Null
Copy-Item -LiteralPath (Join-Path $RepoRoot 'data\protection_intervals.csv') -Destination $filesDir -Force

$failed = $false
foreach ($item in $Target) {
    $path = Join-Path $mql5 $item
    $log = [IO.Path]::ChangeExtension($path, '.compile.log')
    & $MetaEditorExe "/compile:$path" "/inc:$mql5" "/log:$log" | Out-Null
    $text = Get-Content -LiteralPath $log -Encoding Unicode -Raw
    $summary = ($text -split "`r?`n" | Where-Object { $_ -match 'Result:|error|warning' }) -join "`n"
    Write-Host "== $item"
    Write-Host $summary
    if ($text -notmatch 'Result: 0 errors') { $failed = $true }
}
# MetaEditor's own exit code is not a reliable success signal; the log is.
if ($failed) { exit 1 }
exit 0
