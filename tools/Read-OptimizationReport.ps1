<#
.SYNOPSIS
  Reads an MT5 optimization XML report (Excel 2003 XML) into objects.

.EXAMPLE
  .\tools\Read-OptimizationReport.ps1 -Label fold1_opt | Export-Csv passes.csv
#>
param([Parameter(Mandatory)] [string]$Label)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'KingEA.Common.ps1')

$path = Join-Path $DataDir "reports\KingEA_$Label.xml"
[xml]$xml = Get-Content -LiteralPath $path -Raw
$ns = New-Object Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace('ss', 'urn:schemas-microsoft-com:office:spreadsheet')
$rowNodes = $xml.SelectNodes('//ss:Worksheet[1]/ss:Table/ss:Row', $ns)
$header = @($rowNodes[0].SelectNodes('ss:Cell/ss:Data', $ns) | ForEach-Object { $_.InnerText })
for ($i = 1; $i -lt $rowNodes.Count; $i++) {
    $cells = @($rowNodes[$i].SelectNodes('ss:Cell/ss:Data', $ns) | ForEach-Object { $_.InnerText })
    $row = [ordered]@{}
    for ($c = 0; $c -lt $header.Count; $c++) { $row[$header[$c]] = $cells[$c] }
    [pscustomobject]$row
}
