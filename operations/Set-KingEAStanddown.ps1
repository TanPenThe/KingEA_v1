param(
    [Parameter(Mandatory)][string]$DeploymentId,
    [Parameter(Mandatory)][string]$Operator,
    [Parameter(Mandatory)][string]$Reason,
    [string]$CommonFilesRoot = 'C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\Common\Files'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'KingEAWatchdog.psm1') -Force

if ([string]::IsNullOrWhiteSpace($DeploymentId) -or
    [string]::IsNullOrWhiteSpace($Operator) -or
    [string]::IsNullOrWhiteSpace($Reason)) {
    throw 'KINGEA_STANDDOWN_REFUSED: deployment, operator, and reason are mandatory.'
}

$controlDirectory = Join-Path $CommonFilesRoot ('KingEA\control\' + $DeploymentId)
$path = Join-Path $controlDirectory 'manual_standdown.json'
$record = [pscustomobject]@{
    Schema = 1
    DeploymentId = $DeploymentId
    Operator = $Operator
    Utc = [datetime]::UtcNow.ToString('o')
    Reason = $Reason
}

$temporary = "$path.tmp"
if (-not (Test-Path -LiteralPath $controlDirectory)) {
    New-Item -ItemType Directory -Path $controlDirectory -Force | Out-Null
}
[System.IO.File]::WriteAllText($temporary, ($record | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
if (Test-Path -LiteralPath $path) {
    $backup = "$path.bak"
    [System.IO.File]::Replace($temporary, $path, $backup, $true)
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
}
else {
    [System.IO.File]::Move($temporary, $path)
}

if (-not (Test-KingEAStanddownLatch -Path $path -DeploymentId $DeploymentId)) {
    throw 'KINGEA_STANDDOWN_REFUSED: latch verification failed.'
}

Write-Output "KINGEA_STANDDOWN_ACTIVE: $path"
