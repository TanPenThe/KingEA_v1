param(
    [ValidateSet('RECORDED','RSB3')]
    [string]$Branch,
    [string]$Workspace = 'C:\KingEA_v1',
    [string]$EvidenceRoot = 'C:\KingEA_v1\governance\evidence\stage14\gate1_zero_entry_diagnostic_20260903_execution_v2',
    [string]$Terminal = 'C:\Program Files\MetaTrader 5\terminal64.exe',
    [string]$TerminalData = 'C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075',
    [string]$CommonFiles = 'C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\Common\Files'
)

$ErrorActionPreference = 'Stop'
$evidence = $EvidenceRoot
$approval = Get-Content -LiteralPath (Join-Path $evidence 'OWNER_APPROVAL.json') -Raw | ConvertFrom-Json
$childPath = Join-Path $evidence "children\$Branch.json"
$child = Get-Content -LiteralPath $childPath -Raw | ConvertFrom-Json

function Fail([string]$Reason) { throw "ZERO_ENTRY_DIAGNOSTIC_REFUSED:$Reason" }
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

if (-not $approval.owner_approved -or $approval.orders_authorized -or $approval.returns_authorized -or
    $approval.oos_authorized -or $approval.holdout_authorized) { Fail 'APPROVAL_SCOPE_INVALID' }
if ($child.diagnostic_root_sha256 -ne $approval.diagnostic_root_sha256 -or
    $child.configuration_id -ne 7168 -or $child.execution_adapter -ne 'VIRTUAL' -or
    $child.orders_authorized -or $child.returns_authorized -or $child.oos_authorized -or $child.holdout_authorized) { Fail 'CHILD_SCOPE_INVALID' }
if (@(Get-Process terminal64,metatester64 -ErrorAction SilentlyContinue).Count -ne 0) { Fail 'MT5_ALREADY_RUNNING' }
if (-not (Test-Path -LiteralPath $Terminal) -or (Split-Path -Leaf $Terminal).ToLowerInvariant() -ne 'terminal64.exe') { Fail 'TERMINAL_IDENTITY_INVALID' }
if ((Get-Item -LiteralPath $Terminal).VersionInfo.FileVersion.Split('.')[-1] -ne '6140') { Fail 'TERMINAL_BUILD_MISMATCH' }
if (Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'KingEA' }) { Fail 'KINGEA_SCHEDULED_TASK_PRESENT' }

$sourceSet = Join-Path $evidence "bundles\$Branch\$($child.manifest_sha256).set"
$sourceIni = Join-Path $evidence "bundles\$Branch\$($child.manifest_sha256).ini"
if (-not (Test-Path -LiteralPath $sourceSet) -or -not (Test-Path -LiteralPath $sourceIni)) { Fail 'BUNDLE_MISSING' }

$commonManifest = Join-Path $CommonFiles "KingEA\runs\$($child.manifest_sha256).json"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $commonManifest) | Out-Null
Copy-Item -LiteralPath $childPath -Destination $commonManifest -Force
$manifestFileHash = Hash $commonManifest
$finalSetText = (Get-Content -LiteralPath $sourceSet -Raw).Replace('SET_AT_EXECUTION',$manifestFileHash)
if ($finalSetText -match 'InpExecutionAdapter=NATIVE|InpZeroEntryDiagnostic=false') { Fail 'BUNDLE_EXECUTION_BOUNDARY_INVALID' }
$runtime = Join-Path $evidence "runtime\$Branch"
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
$runtimeSet = Join-Path $runtime "$($child.manifest_sha256).set"
[System.IO.File]::WriteAllText($runtimeSet,$finalSetText,[System.Text.UTF8Encoding]::new($false))
$profileSet = Join-Path $TerminalData "MQL5\Profiles\Tester\$($child.manifest_sha256).set"
Copy-Item -LiteralPath $runtimeSet -Destination $profileSet -Force
$runtimeIni = Join-Path $runtime "$Branch.ini"
Copy-Item -LiteralPath $sourceIni -Destination $runtimeIni -Force

$launch = [ordered]@{
    schema = 1; status = 'RUNNING'; branch = $Branch; configuration_id = 7168
    execution_adapter = 'VIRTUAL'; orders_authorized = $false; returns_authorized = $false
    manifest_sha256 = $child.manifest_sha256; manifest_file_sha256 = $manifestFileHash
    started_at = [DateTime]::UtcNow.ToString('o'); terminal_build = 6140
}
$launchPath = Join-Path $runtime 'RUNNING.json'
if (Test-Path -LiteralPath $launchPath) { Fail 'RUNTIME_EVIDENCE_ALREADY_EXISTS' }
[System.IO.File]::WriteAllText($launchPath,($launch | ConvertTo-Json),[System.Text.UTF8Encoding]::new($false))

Write-Host "Starting Gate 1 zero-entry diagnostic: $Branch"
Write-Host 'Development-only; virtual route; no native orders, returns, OOS, or holdout.'
$process = Start-Process -FilePath $Terminal -ArgumentList "/config:$runtimeIni" -PassThru -WindowStyle Hidden
Write-Output (@{status='LAUNCHED'; branch=$Branch; pid=$process.Id; runtime=$runtime} | ConvertTo-Json -Compress)
