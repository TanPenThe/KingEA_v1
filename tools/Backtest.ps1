<#
.SYNOPSIS
  Runs one KingEA Strategy Tester pass (or an optimization) on real ticks.

.DESCRIPTION
  Writes a .set and .ini into the MT5 data folder, launches the terminal,
  waits for it to exit, then prints the EA's result and funnel lines.
  Trade lists and summaries are written by the EA to
  %APPDATA%\MetaQuotes\Terminal\Common\Files\KingEA\results\<Label>\.

.EXAMPLE
  .\tools\Backtest.ps1 -From 2022.01.01 -To 2023.01.01 -Label smoke
  .\tools\Backtest.ps1 -From 2021.07.01 -To 2024.01.01 -EvalEnd '2023.12.31 00:00' -Label fold1
  .\tools\Backtest.ps1 -From 2021.07.01 -To 2023.01.01 -Optimize -Label gate1_fold1 `
      -Inputs @{ InpConfigurationId = '0||0||1||19439||Y' }
#>
param(
    [Parameter(Mandatory)] [string]$From,
    [Parameter(Mandatory)] [string]$To,
    [string]$Label = 'default',
    [string]$EvalStart = '',
    [string]$EvalEnd = '',
    [string]$Symbol = 'ETHUSD.s',
    [int]$Deposit = 1000,
    [string]$Leverage = '1:100',
    [int]$ExecutionDelayMs = 20,
    [switch]$Optimize,
    [hashtable]$Inputs = @{},
    [int]$TimeoutMinutes = 240
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'KingEA.Common.ps1')
Assert-Mt5NotRunning

$values = [ordered]@{
    InpRunLabel = $Label
    InpEvalStart = if ($EvalStart) { $EvalStart } else { '1970.01.01 00:00:00' }
    InpEvalEnd = if ($EvalEnd) { $EvalEnd } else { '1970.01.01 00:00:00' }
}
foreach ($key in $Inputs.Keys) { $values[$key] = $Inputs[$key] }

$setName = "KingEA_$Label.set"
$setPath = Join-Path $DataDir "MQL5\Profiles\Tester\$setName"
$setLines = foreach ($key in $values.Keys) { "$key=$($values[$key])" }
Set-Content -LiteralPath $setPath -Value $setLines -Encoding ASCII

$reportName = "KingEA_$Label"
$ini = @"
[Tester]
Expert=KingEA\KingEA.ex5
ExpertParameters=$setName
Symbol=$Symbol
Period=M30
FromDate=$From
ToDate=$To
Model=4
ExecutionMode=$ExecutionDelayMs
Optimization=$(if ($Optimize) { 1 } else { 0 })
OptimizationCriterion=6
Visual=0
UseLocal=1
UseRemote=0
UseCloud=0
Deposit=$Deposit
Currency=USD
Leverage=$Leverage
Report=\reports\$reportName
ReplaceReport=1
ShutdownTerminal=1
"@
New-Item -ItemType Directory -Force -Path (Join-Path $DataDir 'reports') | Out-Null
$iniPath = Join-Path $DataDir "config\KingEA_$Label.ini"
Set-Content -LiteralPath $iniPath -Value $ini -Encoding ASCII

$started = Get-Date
Write-Host "Running $Symbol $From -> $To (label '$Label', optimize=$($Optimize.IsPresent))..."
$process = Start-Process -FilePath $TerminalExe -ArgumentList "/config:`"$iniPath`"" -PassThru
if (-not $process.WaitForExit($TimeoutMinutes * 60 * 1000)) {
    throw "Backtest did not finish within $TimeoutMinutes minutes."
}
Write-Host ("Finished in {0:n1} min, exit code {1}" -f ((Get-Date) - $started).TotalMinutes, $process.ExitCode)

# Print the EA's own result lines from the agent logs written during this run.
$logs = Get-ChildItem -LiteralPath $AgentsDir -Recurse -Filter '*.log' |
    Where-Object { $_.LastWriteTime -ge $started }
$since = $started.ToString('HH:mm:ss')
$lines = foreach ($log in $logs) {
    Get-Content -LiteralPath $log.FullName -Encoding Unicode |
        Where-Object { ($_ -split "`t")[2] -ge $since } |
        Where-Object { $_ -match 'KingEA (result|funnel|regime|sleeve|safety|WARNING)|KingEA: (seeded|WARNING|trading halted|entry failed)' }
}
$lines | Select-Object -Last 40 | ForEach-Object { Write-Host $_ }

$results = Join-Path $CommonFiles "KingEA\results\$Label"
Write-Host "Results: $results"
Write-Host "Report:  $(Join-Path $DataDir "reports\$reportName").htm/.xml"
