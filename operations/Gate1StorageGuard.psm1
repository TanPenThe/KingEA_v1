function Test-Gate1ArchiveMaintenanceProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [object]$Process
    )

    if ([string]$Process.Name -ine 'powershell.exe') {
        return $false
    }
    $commandLine = [string]$Process.CommandLine
    return [bool]($commandLine -match '(?i)(?:^|\s)-File\s+(?:"[^"]*[\\/]Start-Gate1ArchiveMaintenance\.ps1"|[^\s"]*[\\/]Start-Gate1ArchiveMaintenance\.ps1)(?:\s|$)')
}

Export-ModuleMember -Function Test-Gate1ArchiveMaintenanceProcess
