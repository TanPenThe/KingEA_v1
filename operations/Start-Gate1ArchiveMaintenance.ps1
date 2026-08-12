[CmdletBinding()]
param(
    [ValidateRange(0, 199)] [int]$From = 2,
    [ValidateRange(0, 199)] [int]$To = 29
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ($From -gt $To) { throw 'From must not exceed To.' }

Push-Location $workspace
try {
    foreach ($number in $From..$To) {
        if (Get-Process -Name terminal64,metatester64 -ErrorAction SilentlyContinue) {
            throw 'Archive maintenance stopped: MT5 or MetaTester is active.'
        }
        $runId = 'G1-{0:D4}' -f $number
        Write-Host "Archiving $runId..."
        & python -m research_pipeline.gate1_archive_cli $runId
        if ($LASTEXITCODE -ne 0) {
            throw "Archive maintenance stopped fail-closed at $runId."
        }
        Start-Sleep -Seconds 5
    }
    Write-Host "Archive maintenance complete: G1-$('{0:D4}' -f $From) through G1-$('{0:D4}' -f $To)."
}
finally {
    Pop-Location
}
