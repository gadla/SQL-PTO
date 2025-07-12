#Requires -Modules SqlServer
param
(
    [Parameter(Mandatory=$true)]
    [String]
    $SQLAnalyzerPAT,
    [Boolean]
     $ListAvailableVersions = $false
)
Set-StrictMode -Version Latest

$PSRepository = 'PSSQLAnalyzer'
$PSSourceLocation = 'https://msblox-02.pkgs.visualstudio.com/_packaging/SQLAnalyzer-CI/nuget/v2'
$PSPublishLocation = 'https://msblox-02.pkgs.visualstudio.com/_packaging/SQLAnalyzer-CI/nuget/v2'
$SecureStringFromPAT = ConvertTo-SecureString $SQLAnalyzerPAT -AsPlainText -Force

try {
    if (Get-PSRepository | Where-Object { $_.Name -eq $PSRepository }) 
    {
        Write-Output -Message "Existing SQLAnalyzer Azure DevOps repository registration detected." 
    } 
    else 
    { 
        Write-Output -Message "Registering SQLAnalyzer Azure DevOps repository."

        Register-PSRepository -Name $PSRepository `
        -SourceLocation  $PSSourceLocation `
        -PublishLocation $PSPublishLocation `
        -InstallationPolicy Trusted 
    }


    $CredFromPAT = New-Object -TypeName System.Management.Automation.PSCredential `
        -ArgumentList 'PFENoReply@microsoft.com', $SecureStringFromPAT 

    if ($ListAvailableVersions)
    {
        Write-Output 'Available versions:'
        Find-Module -Name 'SQLAnalyzer' -Repository $PSRepository -Credential $CredFromPAT -AllVersions
    }

    if (Get-Module -Name 'SQLAnalyzer')
    {
        Write-Output "Attempting to update SQLAnalyzer PSModule to the latest version."

        Update-Module -Name 'SQLAnalyzer' -Credential $CredFromPAT
    }
    else 
    {
        Write-Output "Installing SQLAnalyzer PSModule scoped to the current user."

        Install-Module -Name 'SQLAnalyzer' -Scope CurrentUser -Credential $CredFromPAT
    }

    Write-Host "Installation or update of SQLAnalyzer PSModule completed."
}
catch {
    Write-Host "An error occurred: $_"
}

# Example invocation of Start-SqlAnalyzer
# Start-SqlAnalyzer -ServerName 'localhost\SQLEXPRESS' `
#    -DatabaseName 'SqlNexus' `
#    -SourcePath 'C:\Users\kkilt\Desktop\AngloAmerican\output'