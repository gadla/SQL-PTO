#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Adds a right-click context menu entry in Windows Explorer to launch SQLAnalyzer.

.DESCRIPTION
    This script creates a shell context menu entry under the "Directory" object in Windows Explorer.
    When a user right-clicks a folder, they will see "Run SQLAnalyzer", which launches a PowerShell
    session executing the WindowsFormInit.ps1 script with the selected folder path as a parameter.

.PARAMETER None
    This script takes no parameters. It must be run with Administrator privileges.

.EXAMPLE
    .\Register-SQLAnalyzerMenu.ps1

    Registers the context menu entry under 'HKEY_CLASSES_ROOT\Directory\shell'.

.NOTES
    Author: Gadi Lev-Ari
    Version: 1.0
    Last Updated: 2025-07-07
    Requires: Windows PowerShell 5.1 or higher
              Administrator privileges

.LINK
    https://learn.microsoft.com/windows/win32/shell/context-menu-handlers
#>

# Define path to WindowsFormInit.ps1
$scriptPath = 'C:\SQLAnalyzer\Utilities\WindowsFormInit.ps1'

# Validate the file exists
if (-not (Test-Path -Path $scriptPath -PathType Leaf)) {
    Write-Error "Script not found at expected path: $scriptPath"
    exit 1
}

# Mount HKCR drive if not already available
try {
    if (-not (Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) {
        New-PSDrive -PSProvider Registry -Root HKEY_CLASSES_ROOT -Name HKCR -ErrorAction Stop
    }
} catch {
    Write-Error "❌ Failed to mount HKCR registry path: $_"
    exit 1
}

# Create context menu registry keys
try {
    if (-not (Test-Path -Path 'HKCR:\Directory')) {
        New-Item -Path 'HKCR:\Directory' -Force
    }

    if (-not (Test-Path -Path 'HKCR:\Directory\shell')) {
        New-Item -Path 'HKCR:\Directory\shell' -Force
    }

    if (-not (Test-Path -Path 'HKCR:\Directory\shell\PowershellMenu')) {
        New-Item -Path 'HKCR:\Directory\shell' -Name 'PowershellMenu' -Force
    }

    if (-not (Test-Path -Path 'HKCR:\Directory\shell\PowershellMenu\command')) {
        New-Item -Path 'HKCR:\Directory\shell\PowershellMenu' -Name 'command' -Force
    }
} catch {
    Write-Error "❌ Failed to create registry keys: $_"
    exit 1
}

# Set menu label and command
try {
    Set-Item -Path 'HKCR:\Directory\shell\PowershellMenu' -Value 'Run SQLAnalyzer'
    
    $cmd = "powershell.exe -noexit -file `"$scriptPath`" -folderpath `"%V`""
    Set-Item -Path 'HKCR:\Directory\shell\PowershellMenu\command' -Value $cmd
} catch {
    Write-Error "❌ Failed to configure context menu command: $_"
    exit 1
}

Write-Host "✅ Context menu 'Run SQLAnalyzer' registered successfully." -ForegroundColor Green
