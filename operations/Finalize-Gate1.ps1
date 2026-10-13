[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputRoot
)

$ErrorActionPreference = "Stop"
$workspace = "C:\KingEA_v1"
$archiveRoot = "C:\KingEA_archives\stage14\gate1_spools"

Set-Location -LiteralPath $workspace
& python.exe -m research_pipeline.gate1_finalization_cli `
    --workspace $workspace `
    --archive-root $archiveRoot `
    --output-root $OutputRoot `
    --single-stream

if ($LASTEXITCODE -ne 0) {
    throw "Gate 1 finalization stopped fail-closed (exit $LASTEXITCODE)."
}
