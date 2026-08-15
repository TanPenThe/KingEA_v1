[CmdletBinding()]
param(
    [ValidateRange(1, 2)]
    [int]$Children = 2
)

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

Push-Location $workspace
try {
    $archiveProcess = Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -match '[\\/]Start-Gate1ArchiveMaintenance\.ps1(?:\s|")'
    }
    if ($archiveProcess) {
        throw 'ARCHIVE_MAINTENANCE_ACTIVE: Gate 1 research must not overlap archival.'
    }
    & python -m research_pipeline.gate1_storage_cli --workspace $workspace
    if ($LASTEXITCODE -ne 0) {
        throw "STORAGE_POLICY_BLOCKED: Gate 1 research must not launch."
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $PSScriptRoot 'Start-Gate1ManualBatch.ps1') `
        -Children $Children
    if ($LASTEXITCODE -ne 0) {
        throw "Managed Gate 1 batch failed (exit $LASTEXITCODE)."
    }
}
finally {
    Pop-Location
}
