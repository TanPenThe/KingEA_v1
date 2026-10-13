$ErrorActionPreference = "Stop"
$projectRoot = "C:\KingEA_v1"
$output = Join-Path $projectRoot "governance\evidence\stage14\PRE_TOOLING_GATE1_ZERO_ENTRY_FORENSICS_20260903_V8.json"
$sources = @(
    "research_pipeline\gate1_zero_entry_forensics.py",
    "research_pipeline\gate1_zero_entry_forensics_cli.py",
    "operations\Start-Gate1ZeroEntryForensicAudit.ps1",
    "operations\Start-Gate1Stage13ForensicAudit.ps1",
    "operations\New-Gate1ZeroEntryForensicsPreTooling.ps1",
    "tests\test_gate1_zero_entry_forensics.py"
)
$entries = foreach ($relative in $sources) {
    $path = Join-Path $projectRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing source: $relative" }
    $item = Get-Item -LiteralPath $path
    [ordered]@{ path=$relative; size=[int64]$item.Length; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
}
$body = [ordered]@{
    kind="PRE_TOOLING"; build_id="KINGEA-GATE1-ZERO-ENTRY-FORENSICS-20260903-V1"
    sources=$entries; dependencies=@{
        zero_entry_anomaly="7BB71FFD6F3B50507CB92F282EAD4749520495C7E57ADF36C4E68DADC854CC20"
        diagnostic_root="B17EA4E5AA3A6D823B522252D5997F63BC8C0A6CD620C0DDDBA26851E194185D"
    }
}
$canonical = $body | ConvertTo-Json -Depth 8 -Compress
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try { $body["manifest_sha256"] = ($sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical)) | ForEach-Object ToString x2) -join '' }
finally { $sha256.Dispose() }
$payload = $body | ConvertTo-Json -Depth 8
if (Test-Path -LiteralPath $output) {
    if ((Get-Content -LiteralPath $output -Raw) -ne $payload) { throw "PRE_TOOLING_OUTPUT_CONFLICT" }
} else { [IO.File]::WriteAllText($output, $payload + [Environment]::NewLine, [Text.UTF8Encoding]::new($false)) }
Write-Output $output
