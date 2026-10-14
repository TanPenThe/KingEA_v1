<#
.SYNOPSIS
  Runs an MQL5 script (e.g. a unit test) in the terminal and prints its log lines.

.EXAMPLE
  .\tools\RunScript.ps1 -Script TestExitEthSt002
#>
param(
    [Parameter(Mandatory)] [string]$Script,
    [string]$Symbol = 'ETHUSD.s',
    [int]$TimeoutMinutes = 5
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'KingEA.Common.ps1')
Assert-Mt5NotRunning

$ini = @"
[StartUp]
Script=KingEA\$Script
Symbol=$Symbol
Period=M30
ShutdownTerminal=1
"@
$iniPath = Join-Path $DataDir "config\KingEA_script_$Script.ini"
Set-Content -LiteralPath $iniPath -Value $ini -Encoding ASCII
$started = Get-Date
$process = Start-Process -FilePath $TerminalExe -ArgumentList "/config:`"$iniPath`"" -PassThru
if (-not $process.WaitForExit($TimeoutMinutes * 60 * 1000)) { throw "Script did not finish in $TimeoutMinutes minutes." }

$since = $started.ToString('HH:mm:ss')
$log = Join-Path $DataDir ("MQL5\Logs\{0}.log" -f $started.ToString('yyyyMMdd'))
$lines = Get-Content -LiteralPath $log -Encoding Unicode |
    Where-Object { ($_ -split "`t")[2] -ge $since -and $_ -match [regex]::Escape($Script) }
$lines | ForEach-Object { Write-Host $_ }
if (-not ($lines -match 'PASS')) { exit 1 }
exit 0
