param(
    [string]$Workspace = 'C:\KingEA_v1',
    [string]$OutputRoot = 'C:\KingEA_v1\governance\evidence\stage14\gate1_zero_entry_diagnostic_20260902_v1'
)

$ErrorActionPreference = 'Stop'

Write-Host 'KingEA Gate 1 zero-entry diagnostic preparation'
Write-Host 'This command writes planned, non-executable manifests only.'
Write-Host 'It does not start MT5, access OOS/holdout, calculate returns, or authorize orders.'

& python -m research_pipeline.gate1_zero_entry_diagnostic_cli `
    --workspace $Workspace `
    --output-root $OutputRoot `
    --prepare

if ($LASTEXITCODE -ne 0) {
    throw "Zero-entry diagnostic preparation failed (exit $LASTEXITCODE)."
}
