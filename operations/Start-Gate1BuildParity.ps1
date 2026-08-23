[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

Write-Host 'KingEA Gate 1 MT5 build-transition parity gate'
Write-Host 'References: G1-0000, G1-0039, G1-0080, G1-0119'
Write-Host 'This reruns development-only evidence for infrastructure comparison.'
Write-Host 'It cannot authorize continuation, OOS, holdout, demo orders, or live activity.'

Push-Location $workspace
try {
    & python -m research_pipeline.gate1_build_transition_cli execute `
        --workspace $workspace
    if ($LASTEXITCODE -ne 0) {
        throw "Gate 1 build parity stopped fail-closed (exit $LASTEXITCODE). Send the displayed reason to Codex."
    }
}
finally {
    Pop-Location
}
