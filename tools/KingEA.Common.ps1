# Shared paths for the KingEA build and backtest scripts.
# Override with environment variables if MT5 is installed elsewhere.

$script:RepoRoot     = Split-Path -Parent $PSScriptRoot
$script:Mt5Install   = if ($env:KINGEA_MT5_INSTALL) { $env:KINGEA_MT5_INSTALL } else { 'C:\Program Files\MetaTrader 5' }
$script:TerminalId   = if ($env:KINGEA_TERMINAL_ID) { $env:KINGEA_TERMINAL_ID } else { 'D0E8209F77C8CF37AD8BF550E51FF075' }
$script:DataDir      = Join-Path $env:APPDATA "MetaQuotes\Terminal\$script:TerminalId"
$script:CommonFiles  = Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
$script:AgentsDir    = Join-Path $env:APPDATA "MetaQuotes\Tester\$script:TerminalId"
$script:TerminalExe  = Join-Path $script:Mt5Install 'terminal64.exe'
$script:MetaEditorExe = Join-Path $script:Mt5Install 'MetaEditor64.exe'

function Assert-Mt5NotRunning {
    $running = Get-Process -Name terminal64, metatester64 -ErrorAction SilentlyContinue
    if ($running) {
        throw 'MetaTrader 5 is running. Close the terminal before running a scripted backtest.'
    }
}
