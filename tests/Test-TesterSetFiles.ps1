param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "TESTER_SET_FAIL: $Message" }
}

function Read-Set([string]$Path) {
    $values = @{}
    Get-Content -LiteralPath $Path |
        Where-Object { $_ -and -not $_.StartsWith(';') } |
        ForEach-Object {
            $parts = $_ -split '=', 2
            Assert-True ($parts.Count -eq 2) "invalid set row in $Path"
            $values[$parts[0]] = $parts[1]
        }
    return $values
}

$setRoot = Join-Path $Workspace 'MQL5\Profiles\Tester\KingEA'
$source = Get-Content -LiteralPath (Join-Path $Workspace 'MQL5\Experts\KingEA\ReconcileTesterRealTicks.mq5') -Raw
$matrix = Import-Csv -LiteralPath (Join-Path $setRoot 'tester_recon_run_matrix.csv')

Assert-True ($matrix.Count -eq 4) 'run matrix must retain all four governed reconciliation attempts'
$expectedRuns = @{
    'DEMO2_ORIGIN_20210701_WARMUP' = @('2021.07.01 00:00:00','2021.07.02 00:00:00','173712','2021.06.30','2021.07.02','AUTHORIZED')
    'RSB3_REDUCED_20210701_WARMUP' = @('2021.07.01 00:00:00','2021.07.02 00:00:00','173712','2021.06.30','2021.07.02','INFEASIBLE_MT5_MANDATORY_WARMUP')
    'RSB3_REDUCED_20210703_WARMUP' = @('2021.07.03 00:00:00','2021.07.04 00:00:00','88490','2021.07.01','2021.07.04','INFEASIBLE_MT5_WARMUP_ROUNDED_TO_END')
    'RSB3_REDUCED_20210704_WARMUP' = @('2021.07.04 00:00:00','2021.07.05 00:00:00','42787','2021.07.01','2021.07.05','PASS_20260726')
}
foreach ($row in $matrix) {
    Assert-True ($expectedRuns.ContainsKey($row.run_id)) "unregistered run $($row.run_id)"
    $expected = $expectedRuns[$row.run_id]
    $setPath = Join-Path $setRoot $row.set_file
    Assert-True (Test-Path -LiteralPath $setPath) "missing set file $($row.set_file)"
    $values = Read-Set $setPath
    foreach ($key in @('InpRunLabel','InpExpectedSymbol','InpWindowStart','InpWindowEnd','InpExpectedTicks')) {
        Assert-True ($values.ContainsKey($key)) "$($row.set_file) is missing $key"
        Assert-True ($source.Contains("input ") -and $source.Contains($key)) "EA source does not expose $key"
    }
    Assert-True ($values.InpRunLabel -eq $row.run_id) "$($row.set_file) label differs from matrix"
    Assert-True ($values.InpExpectedSymbol -eq $row.symbol) "$($row.set_file) symbol differs from matrix"
    Assert-True ($values.InpWindowStart -eq $expected[0]) "$($row.set_file) start window drifted"
    Assert-True ($values.InpWindowEnd -eq $expected[1]) "$($row.set_file) end window drifted"
    Assert-True ($values.InpExpectedTicks -eq $expected[2]) "$($row.set_file) expected count drifted"
    Assert-True ($row.timeframe -eq 'M30') "$($row.run_id) timeframe drifted"
    Assert-True ($row.model -eq 'Every tick based on real ticks') "$($row.run_id) model drifted"
    Assert-True ($row.tester_date_from -eq $expected[3]) "$($row.run_id) warm-up date drifted"
    Assert-True ($row.tester_date_to -eq $expected[4]) "$($row.run_id) end date drifted"
    Assert-True ($row.status -eq $expected[5]) "$($row.run_id) status drifted"
}

Write-Output 'TESTER_SET_PASS: all governed input sets match the EA and append-only UI run matrix.'
