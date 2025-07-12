<#
.SYNOPSIS
    Unblocks files that were downloaded from the internet.

.DESCRIPTION
    This script recursively scans a specified folder for all files.
    If any file is found to be blocked by Windows (i.e., has a Zone.Identifier stream),
    it uses the Unblock-File cmdlet to remove the block. Errors during the unblocking
    process are caught and reported. A summary message is displayed if the script
    completes without errors.

.PARAMETER FolderPath
    The root folder to scan for files.
    The script will search this folder and all its subdirectories.

.EXAMPLE
    .\Unblock-FilesInFolder.ps1 -FolderPath "C:\MyDownloads" -Verbose

    Scans the C:\MyDownloads folder and unblocks any files found within it or its subfolders,
    displaying verbose output per file.

.NOTES
    Author: Gadi Lev-Ari
    Version: 1.3
    PowerShell version: 5.0 or later (requires Unblock-File cmdlet)

.LINK
    https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/unblock-file
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter the path to the folder containing the files.")]
    [string]$FolderPath
)

# Validate the folder path
if (-not (Test-Path -Path $FolderPath -PathType Container)) {
    Write-Error "The specified path '$FolderPath' is not a valid folder."
    exit 1
}

$files = Get-ChildItem -Path $FolderPath -Recurse -File -ErrorAction SilentlyContinue
$errorsOccurred = $false

foreach ($file in $files) {
    $zoneIdentifierPath = "$($file.FullName):Zone.Identifier"

    Write-Verbose "Checking file: $($file.FullName)"

    if (Test-Path -Path $zoneIdentifierPath) {
        try {
            Unblock-File -Path $file.FullName -ErrorAction Stop
            Write-Verbose "Unblocked: $($file.FullName)"
        }
        catch {
            Write-Error "❌ Failed to unblock: $($file.FullName). Error: $_"
            $errorsOccurred = $true
        }
    }
}

# Final user message
if (-not $errorsOccurred) {
    Write-Host "✅ All applicable files were successfully unblocked." -ForegroundColor Green
}
else {
    Write-Host "⚠️ Some files could not be unblocked. Please check the error messages above." -ForegroundColor Yellow
}