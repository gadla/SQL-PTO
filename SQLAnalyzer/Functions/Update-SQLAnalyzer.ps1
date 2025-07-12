function Update-SQLAnalyzer {
    Param (
        [Parameter(Mandatory=$false)] [string] $Name
    )
    process {
        Write-Verbose "Getting info for loaded module 'SqlAnalyzer'..."
        $CurrentModule = Get-Module | Where-Object {$_.Name -eq "SqlAnalyzer"}
        if ($CurrentModule.Count -gt 1) {
            Write-Warning "Multiple versions  of the SQLAnalyzer module are loaded; please unload the modules or open a new PowerShell window and re-import the module and try again."
            Throw "Multiple SQLAnalyzer modules are loaded; please try again."
        }
        if ($CurrentModule) {
            $FullInstalledPath = $CurrentModule.Path.ToString()
            $InstalledPath = $FullInstalledPath.Replace("SqlAnalyzer.psm1","")
            Write-Verbose "Module 'SqlAnalyzer' is installed at $InstalledPath"
        } else {
            Write-Warning "Unable to determine where the existing SQLAnalyzer module is installed. Defaulting to current directory as download location."
            $InstalledPath = (Get-Location).Path
        }
        $DownloadLocation = $InstalledPath + "ModuleArchive.zip"

        $CurrentAzContext = Get-AzContext
        if (!$CurrentAzContext) {
            Write-Warning "No current Azure context detected! You will be prompted to login"
            $Context = Connect-AzAccount
        } else {
            $Context = Get-AzContext
        }
        $StorageContext = New-AzStorageContext -StorageAccountName "SQLAnalyzer" -UseConnectedAccount
        Get-AzStorageBlobContent -Context $StorageContext -Container "sqlblob" -Blob "SQLAnalyzer.zip" -Destination $DownloadLocation -Force | Out-Null
        Expand-Archive -Path $DownloadLocation -DestinationPath $InstalledPath -Force
        Write-Warning "Module updated. The module will now re-import..."
        Import-Module "$InstalledPath/SqlAnalyzer.psm1" -Force -Verbose
        Write-Verbose "Removing downloaded archive..."
        Remove-Item $DownloadLocation
    }
}