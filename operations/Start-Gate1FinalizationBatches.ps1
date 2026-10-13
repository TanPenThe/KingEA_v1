[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = "Stop"

# Change only this value. Each audit batch verifies 20 governed archives.
$batchesToRun = 7

$workspace = "C:\KingEA_v1"
$archiveRoot = "C:\KingEA_archives\stage14\gate1_spools"
$outputRoot = "C:\KingEA_v1\governance\evidence\stage14\gate1_finalization_20260901_v1"

if ($WhatIfPreference) {
    Write-Host "WhatIf: no Gate 1 audit batch or merge will run."
    Write-Host "Configured batchesToRun: $batchesToRun"
    return
}

if ($batchesToRun -lt 1) {
    throw "batchesToRun must be at least 1."
}

Set-Location -LiteralPath $workspace

function Get-Gate1BatchStatus {
    $raw = & python.exe -m research_pipeline.gate1_finalization_cli `
        --workspace $workspace `
        --archive-root $archiveRoot `
        --output-root $outputRoot `
        --status
    if ($LASTEXITCODE -ne 0) {
        throw "Gate 1 batch-status check failed (exit $LASTEXITCODE)."
    }
    return ($raw | Select-Object -Last 1 | ConvertFrom-Json)
}

$workflowStart = Get-Date
Write-Host "KingEA Gate 1 resumable finalization"
Write-Host "Workflow start: $($workflowStart.ToString('yyyy-MM-dd HH:mm:ss'))"

for ($attempt = 1; $attempt -le $batchesToRun; $attempt++) {
    $state = Get-Gate1BatchStatus
    if ($state.status -eq "FINALIZED") {
        Write-Host "All batches and the final merge already completed."
        break
    }
    if ($null -eq $state.next_batch_id) {
        break
    }

    $batchId = [int]$state.next_batch_id
    $runStart = "G1-{0:D4}" -f (($batchId - 1) * 20)
    $runEnd = "G1-{0:D4}" -f ([Math]::Min(($batchId * 20) - 1, 199))
    $batchStart = Get-Date
    Write-Host ""
    Write-Host "Batch $batchId of $($state.batch_count): $runStart through $runEnd"
    Write-Host "Batch start: $($batchStart.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Host "Remaining before start: $($state.remaining_batches.Count)"

    & python.exe -m research_pipeline.gate1_finalization_cli `
        --workspace $workspace `
        --archive-root $archiveRoot `
        --output-root $outputRoot `
        --batch-id $batchId
    if ($LASTEXITCODE -ne 0) {
        throw "Gate 1 audit batch $batchId stopped fail-closed (exit $LASTEXITCODE)."
    }

    $batchEnd = Get-Date
    Write-Host "Batch end: $($batchEnd.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Host "Batch duration: $($batchEnd - $batchStart)"
}

$finalState = Get-Gate1BatchStatus
if ($finalState.status -eq "PENDING" -and $finalState.remaining_batches.Count -eq 0) {
    $mergeStart = Get-Date
    Write-Host "All shards verified. Starting deterministic final merge at $($mergeStart.ToString('yyyy-MM-dd HH:mm:ss'))"
    & python.exe -m research_pipeline.gate1_finalization_cli `
        --workspace $workspace `
        --archive-root $archiveRoot `
        --output-root $outputRoot `
        --merge
    if ($LASTEXITCODE -ne 0) {
        throw "Gate 1 final merge stopped fail-closed (exit $LASTEXITCODE)."
    }
    $mergeEnd = Get-Date
    Write-Host "Merge end: $($mergeEnd.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Host "Merge duration: $($mergeEnd - $mergeStart)"
    $finalState = Get-Gate1BatchStatus
}

$workflowEnd = Get-Date
Write-Host ""
Write-Host "Workflow end: $($workflowEnd.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Workflow duration: $($workflowEnd - $workflowStart)"
Write-Host "Completed batches: $($finalState.completed_batches -join ', ')"
Write-Host "Remaining batches: $($finalState.remaining_batches -join ', ')"
Write-Host "Status: $($finalState.status)"
