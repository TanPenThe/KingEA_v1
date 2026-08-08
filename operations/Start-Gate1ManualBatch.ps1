[CmdletBinding()]
param(
    [ValidateRange(1, 2)]
    [int]$Children = 2
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

Write-Host 'KingEA Gate 1 manual foreground batch'
Write-Host "Root: BC4D5D84DBF45AAB6628AA0E1D39D984F715217BB1CA1C092DE1EE97385FA889"
Write-Host "Children: $Children (two projects take about 6.4 hours; hard batch ceiling 7.5 hours)"
Write-Host 'This is development-only Strategy Tester research. OOS and holdout remain blocked.'

Push-Location $workspace
try {
    & python -m research_pipeline.gate1_manual_cli --workspace $workspace --children $Children
    if ($LASTEXITCODE -ne 0) {
        throw "Gate 1 batch stopped fail-closed (exit $LASTEXITCODE). Send the displayed reason to Codex."
    }
}
finally {
    Pop-Location
}
