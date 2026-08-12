[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$archiveLog = 'C:\KingEA_archives\stage14\logs\archive_maintenance_G1-0002_0029.out.log'
$archiveError = 'C:\KingEA_archives\stage14\logs\archive_maintenance_G1-0002_0029.err.log'
$deadline = (Get-Date).AddHours(12)

while ((Get-Date) -lt $deadline) {
    if ((Test-Path $archiveError) -and (Get-Item $archiveError).Length -gt 0) {
        throw 'Storage recovery stopped: archive maintenance reported an error.'
    }
    if ((Test-Path $archiveLog) -and
        (Select-String -LiteralPath $archiveLog -SimpleMatch 'Archive maintenance complete:' -Quiet)) {
        break
    }
    Start-Sleep -Seconds 60
}
if (-not (Select-String -LiteralPath $archiveLog -SimpleMatch 'Archive maintenance complete:' -Quiet)) {
    throw 'Storage recovery stopped: archive maintenance did not complete within 12 hours.'
}
if (Get-Process -Name terminal64,metatester64 -ErrorAction SilentlyContinue) {
    throw 'Storage recovery stopped: MT5 or MetaTester is active.'
}
$free = (Get-PSDrive -Name C).Free
if ($free -lt 16GB) {
    throw "Storage recovery stopped: only $([math]::Round($free / 1GB, 2)) GB free; 16 GB required."
}

Push-Location $workspace
try {
    & python -m research_pipeline.gate1_archive_cli G1-0037 `
        --invalidate-partial --last-configuration 17652
    if ($LASTEXITCODE -ne 0) { throw 'Partial-attempt invalidation failed.' }

    & python -m research_pipeline.gate1_archive_cli G1-0037 `
        --prepare-retry --batch-id BATCH-0036-0037 `
        --attempt-id G1-0037-DISK-EXHAUSTION-20260812-A1
    if ($LASTEXITCODE -ne 0) { throw 'Retry preparation failed.' }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File C:\KingEA_v1\operations\Start-Gate1ManualBatch.ps1 -Children 1
    if ($LASTEXITCODE -ne 0) { throw 'Governed G1-0037 retry failed.' }
}
finally {
    Pop-Location
}
