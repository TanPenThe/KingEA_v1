param([ValidateRange(1,10)][int]$BatchesToRun = 1,[switch]$HardenedRerunFirstShard)
$ErrorActionPreference = "Stop"
$projectRoot="C:\KingEA_v1"; $archiveRoot="C:\KingEA_archives\stage14\gate1_spools"
$outputRoot=Join-Path $projectRoot "governance\evidence\stage14\gate1_zero_entry_forensics_20260903"
$replacement=Join-Path $projectRoot "governance\evidence\stage14\gate1_replacement_20260809\children"
$continuation=Join-Path $projectRoot "governance\evidence\stage14\gate1_continuation_20260824_v2\children"
$diagnostic=Join-Path $projectRoot "governance\evidence\stage14\gate1_zero_entry_diagnostic_20260903_execution_v4\DIAGNOSTIC_RESULT.json"
if(Get-Process terminal64,metatester64 -ErrorAction SilentlyContinue){throw "STAGE13_FORENSICS_REQUIRES_MT5_AND_METATESTER_STOPPED"}
$prefix=if($HardenedRerunFirstShard){"STAGE13_FORENSIC_HARDENED_BATCH"}else{"STAGE13_FORENSIC_BATCH"}
if(-not $HardenedRerunFirstShard){throw "STAGE13_EXPANSION_NOT_AUTHORIZED"}
if($BatchesToRun -ne 1){throw "STAGE13_HARDENED_FIRST_SHARD_REQUIRES_EXACTLY_ONE_BATCH"}
$done=@(Get-ChildItem $outputRoot -Filter "$prefix`_*.json" -ErrorAction SilentlyContinue)
$next=0
if($done.Name -contains ("{0}_0000_0019.json" -f $prefix)){Write-Host "The hardened first shard is already complete."; exit 0}
$end=1
for($batch=$next;$batch -lt $end;$batch++){
  $first=$batch*20; $started=Get-Date
  Write-Host ("Stage 13 forensic batch {0}/10: G1-{1:D4}..G1-{2:D4}; start {3:yyyy-MM-dd HH:mm:ss}" -f ($batch+1),$first,($first+19),$started)
  $attemptStamp=Get-Date -Format "yyyyMMdd_HHmmss"
  $attemptLog=Join-Path $outputRoot ("{0}_{1:D4}_{2:D4}.RUN_{3}.log" -f $prefix,$first,($first+19),$attemptStamp)
  & python -m research_pipeline.gate1_zero_entry_forensics_cli --replacement-children $replacement --continuation-children $continuation --archive-dir $archiveRoot --diagnostic-result $diagnostic --output-dir $outputRoot --first $first --count 20 --stage13 --artifact-prefix $prefix *> $attemptLog
  $pythonExit=$LASTEXITCODE
  Get-Content -LiteralPath $attemptLog
  if($pythonExit -ne 0){throw "Stage 13 forensic audit stopped fail-closed at batch $($batch+1)."}
  $ended=Get-Date; Write-Host ("Batch complete; end {0:yyyy-MM-dd HH:mm:ss}; duration {1}" -f $ended,($ended-$started))
}
