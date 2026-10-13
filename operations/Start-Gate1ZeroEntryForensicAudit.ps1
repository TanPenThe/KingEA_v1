param(
    [ValidateRange(1, 10)]
    [int]$BatchesToRun = 1
)

$ErrorActionPreference = "Stop"
$projectRoot = "C:\KingEA_v1"
$archiveRoot = "C:\KingEA_archives\stage14\gate1_spools"
$outputRoot = Join-Path $projectRoot "governance\evidence\stage14\gate1_zero_entry_forensics_20260903"
$replacementChildren = Join-Path $projectRoot "governance\evidence\stage14\gate1_replacement_20260809\children"
$continuationChildren = Join-Path $projectRoot "governance\evidence\stage14\gate1_continuation_20260824_v2\children"
$diagnostic = Join-Path $projectRoot "governance\evidence\stage14\gate1_zero_entry_diagnostic_20260903_execution_v4\DIAGNOSTIC_RESULT.json"

if (Get-Process terminal64,metatester64 -ErrorAction SilentlyContinue) {
    throw "FORENSIC_AUDIT_REQUIRES_MT5_AND_METATESTER_STOPPED"
}

$done = @(Get-ChildItem $outputRoot -Filter "FORENSIC_BATCH_*.json" -ErrorAction SilentlyContinue)
$next = 0
while ($next -lt 10 -and ($done.Name -contains ("FORENSIC_BATCH_{0:D4}_{1:D4}.json" -f ($next * 20), ($next * 20 + 19)))) { $next++ }
if ($next -eq 10) { Write-Host "All ten forensic batches are already complete."; exit 0 }

$toRun = [Math]::Min($BatchesToRun, 10 - $next)
for ($offset = 0; $offset -lt $toRun; $offset++) {
    $batch = $next + $offset
    $first = $batch * 20
    $started = Get-Date
    Write-Host ("Forensic batch {0}/10: G1-{1:D4} through G1-{2:D4}; start {3:yyyy-MM-dd HH:mm:ss}" -f ($batch + 1), $first, ($first + 19), $started)
    & python -m research_pipeline.gate1_zero_entry_forensics_cli `
        --replacement-children $replacementChildren --continuation-children $continuationChildren `
        --archive-dir $archiveRoot --diagnostic-result $diagnostic --output-dir $outputRoot `
        --first $first --count 20
    if ($LASTEXITCODE -ne 0) { throw "Forensic audit stopped fail-closed at batch $($batch + 1)." }
    $ended = Get-Date
    Write-Host ("Forensic batch {0} complete; end {1:yyyy-MM-dd HH:mm:ss}; duration {2}" -f ($batch + 1), $ended, ($ended - $started))
}
