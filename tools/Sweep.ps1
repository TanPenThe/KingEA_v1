<#
.SYNOPSIS
  One-at-a-time parameter sensitivity on a date window.

.DESCRIPTION
  For each strategy parameter, runs an MT5 optimization over that parameter's
  registered grid values with every other parameter at its default, then
  collects all passes into results\<Label>\sensitivity.csv.
  Breakers are off by default so the numbers measure signal edge.

.EXAMPLE
  .\tools\Sweep.ps1 -From 2021.07.01 -To 2023.01.01 -Label fold1
#>
param(
    [Parameter(Mandatory)] [string]$From,
    [Parameter(Mandatory)] [string]$To,
    [Parameter(Mandatory)] [string]$Label,
    [string[]]$Only = @(),
    [bool]$ApplyBreakers = $false
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'KingEA.Common.ps1')

# value||start||step||stop||Y  (matches the registered CAND-ETH-ST-001 grid)
$grid = [ordered]@{
    InpAtrPeriod              = '14||10||4||22||Y'
    InpSupertrendMultiplier   = '3.0||2.0||0.5||4.0||Y'
    InpBreakoutLookback       = '12||6||6||24||Y'
    InpEntryBufferAtr         = '0.1||0.0||0.1||0.2||Y'
    InpStopBufferAtr          = '0.25||0.0||0.25||0.5||Y'
    InpProgressCheckpointBars = '12||8||4||16||Y'
    InpRequiredProgressR      = '0.5||0.25||0.25||0.75||Y'
    InpMaximumHoldingBars     = '72||48||24||96||Y'
}

$rows = @()
foreach ($name in $grid.Keys) {
    if ($Only.Count -gt 0 -and $Only -notcontains $name) { continue }
    $runLabel = "$Label`_$name"
    & (Join-Path $PSScriptRoot 'Backtest.ps1') -From $From -To $To -Optimize -Label $runLabel `
        -Inputs @{ InpApplyBreakers = $ApplyBreakers.ToString().ToLower(); $name = $grid[$name] } |
        Where-Object { $_ -match 'Finished' } | Write-Host
    $rows += & (Join-Path $PSScriptRoot 'Read-OptimizationReport.ps1') -Label $runLabel |
        Select-Object @{ n = 'parameter'; e = { $name } }, @{ n = 'value'; e = { $_.$name } }, *
}

$out = Join-Path $CommonFiles "KingEA\results\$Label"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$csv = Join-Path $out 'sensitivity.csv'
$rows | Select-Object parameter, value, Trades, Profit, 'Profit Factor', 'Equity DD %', Custom |
    Sort-Object parameter, { [double]$_.value } | Export-Csv -LiteralPath $csv -NoTypeInformation
Write-Host "Sensitivity: $csv"
$rows | Select-Object parameter, value, Trades, Profit, 'Profit Factor', 'Equity DD %' |
    Sort-Object parameter, { [double]$_.value } | Format-Table -AutoSize | Out-String | Write-Host
