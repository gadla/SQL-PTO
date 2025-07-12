#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Removes the right-click context menu entry for SQLAnalyzer from Windows Explorer.

.DESCRIPTION
    This script deletes the registry entries under HKEY_CLASSES_ROOT\Directory\shell\PowershellMenu,
    effectively removing the "Run SQLAnalyzer" option from the folder context menu in Explorer.

.PARAMETER None
    This script takes no parameters. It must be run with Administrator privileges.

.EXAMPLE
    .\Unregister-SQLAnalyzerMenu.ps1

    Removes the "Run SQLAnalyzer" shell extension from right-click context menu.

.NOTES
    Author: Gadi Lev-Ari
    Version: 1.0
    Last Updated: 2025-07-07
    Requires: Windows PowerShell 5.1 or higher
              Administrator privileges

.LINK
    https://learn.microsoft.com/windows/win32/shell/context-menu-handlers
#>

# Mount HKCR if needed
try {
    if (-not (Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) {
        New-PSDrive -PSProvider Registry -Root HKEY_CLASSES_ROOT -Name HKCR -ErrorAction Stop
    }
} catch {
    Write-Error "❌ Failed to mount HKCR registry path: $_"
    exit 1
}

# Attempt to remove the menu entry
try {
    $menuPath = 'HKCR:\Directory\shell\PowershellMenu'

    if (Test-Path -Path $menuPath) {
        Remove-Item -Path $menuPath -Recurse -Force
        Write-Host "✅ Context menu 'Run SQLAnalyzer' removed successfully." -ForegroundColor Green
    } else {
        Write-Host "ℹ️  Context menu 'Run SQLAnalyzer' was not found. No action taken." -ForegroundColor Yellow
    }
} catch {
    Write-Error "❌ Failed to remove context menu: $_"
    exit 1
}
