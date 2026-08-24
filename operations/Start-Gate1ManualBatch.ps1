[CmdletBinding()]
param(
    [ValidateRange(1, 2)]
    [int]$Children = 2
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

Write-Host 'KingEA Gate 1 manual foreground batch'
Write-Host "Root: B59D8052C11D732503147210703C2DA0402106B0012A6DE5E7FC5346E099E6EF"
Write-Host 'Build-6140 continuation after parity PASS; G1-0000 through G1-0119 retained; candidate budget already consumed once.'
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
