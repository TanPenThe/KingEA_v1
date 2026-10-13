<#
.SYNOPSIS
  Full-factorial optimization over selected parameters on each training fold.

.DESCRIPTION
  Runs one MT5 optimization per fold and writes every pass to
  results\<Label>\grid_<fold>.csv. Parameters not listed stay at their
  defaults (the centre of the registered grid). Breakers are off by default
  so the numbers measure signal edge.

.EXAMPLE
  .\tools\Grid.ps1 -Label grid_rsb3 -Symbol KINGEA_ETHUSD_S_RSB3
#>
param(
    [Parameter(Mandatory)] [string]$Label,
    [string]$Symbol = 'KINGEA_ETHUSD_S_RSB3',
    [string[]]$Folds = @('fold1', 'fold2', 'fold3', 'fold4'),
    [hashtable]$Parameters = @{
        InpSupertrendMultiplier = '3.0||2.0||0.5||4.0||Y'
        InpAtrPeriod            = '14||10||4||22||Y'
        InpStopBufferAtr        = '0.25||0.0||0.25||0.5||Y'
        InpRequiredProgressR    = '0.5||0.25||0.25||0.75||Y'
    },
    [bool]$ApplyBreakers = $false
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'KingEA.Common.ps1')

# Development training windows (README "Data partitions").
$windows = @{
    fold1 = @('2021.07.01', '2023.01.01')
    fold2 = @('2021.10.01', '2023.04.01')
    fold3 = @('2022.01.01', '2023.07.01')
    fold4 = @('2022.04.01', '2023.10.01')
}

$out = Join-Path $CommonFiles "KingEA\results\$Label"
New-Item -ItemType Directory -Force -Path $out | Out-Null
foreach ($fold in $Folds) {
    $runLabel = "$Label`_$fold"
    $inputs = @{ InpApplyBreakers = $ApplyBreakers.ToString().ToLower() }
    foreach ($key in $Parameters.Keys) { $inputs[$key] = $Parameters[$key] }
    & (Join-Path $PSScriptRoot 'Backtest.ps1') -Symbol $Symbol -From $windows[$fold][0] -To $windows[$fold][1] `
        -Optimize -Label $runLabel -Inputs $inputs -TimeoutMinutes 600 |
        Where-Object { $_ -match 'Finished' } | Write-Host
    $csv = Join-Path $out "grid_$fold.csv"
    & (Join-Path $PSScriptRoot 'Read-OptimizationReport.ps1') -Label $runLabel |
        Export-Csv -LiteralPath $csv -NoTypeInformation
    Write-Host "Grid $fold`: $csv"
}
