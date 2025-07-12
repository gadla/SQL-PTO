# SQLAnalyzer

PFE authored utility to automate the analysis of a customer PSSDiag capture. The PowerShell module generates a summary of findings in a Microsoft Word and Excel document.

## Getting Started

These instructions will get you a copy of the PowerShell Module to get SQLAnalyzer up and running on your local machine.

### Prerequisites

What things do you need to install the software and how to install them:

[MS Chart Controls](https://www.microsoft.com/en-us/download/details.aspx?id=14422)  also requires .NET Framework 3.5. Used to create graphs.

[SQL 2012 CLR Types](https://www.microsoft.com/en-us/download/confirmation.aspx?id=29065) alternative [page](http://go.microsoft.com/fwlink/?LinkID=239644&clcid=0x409) w/ link to all feature pack downloads x64 version of CLR types.

[RML Utilities](https://www.microsoft.com/en-us/download/details.aspx?id=4511)

[Report Viewer Controls](https://www.microsoft.com/en-us/download/details.aspx?id=35747)

[SQL Nexus](https://microsoft.sharepoint.com/teams/bidpwiki/Pages1/SQLNexus.aspx) (Internal Version)


### Installing

SQLAnalyzer is a PowerShell scripting module that is maintained on an internal Microsoft Azure DevOps instance (not devops.azure.com but internal). As a result the code is private and available to PFE's and Consultant's per ASD and CTO MIP guidance. A private PowerShell repository has been created so that the PFE or Consultant need register the internal repository one time and can update SQLAnalyzer on a regular basis using Update-Module from PowerShell.

Authentication is handled via a [Personal Access Token](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops) which may be obtained from the home page of the [SQL Analyzer project](https://msblox-02.visualstudio.com/SQLAnalyzer) by select your user icon in the upper right corner -> Security -> New Token. Select 'New Token' and choose the Packaging -> Read permission. That is all that is required. Write down and store this secret and treat it as you would any other credential. It is against source control Microsoft Policy not to store credentials in source code or share them. Each PFE or Consultant must do this one time as the token is good for up to two years.

Below is a sample PowerShell script that accepts as input your Personal Access Token and will register the private SQLAnalyzer PSRepository, and install the module. You may also run this script to update if necessary. It's safe to re-run this script. Just create a file someplace and run the script providing your token as input.

```
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
```

So how do you use SQLAnalyzer? Simple. You run a PowerShell command and point to your PSSDiag output directory. 

```
# Example invocation of Start-SqlAnalyzer

Start-SqlAnalyzer -ServerName 'localhost\SQLEXPRESS' `
    -DatabaseName 'SqlNexus' `
    -SourcePath 'C:\Users\kkilt\Desktop\AngloAmerican\output'
```

The default configuration is located in the installation directory of the PowerShell module. Assuming you ran the installation script above that location is:

```
C:\Users\<user>\Documents\WindowsPowerShell\Modules\SQLAnalyzer\<version>\Configuration\SQLAnalyzerConfig.xml
```

The output of the analysis by default is ```C:\PSSDiagExporter```

## Built With

* [PowerShell 5.1](https://github.com/powershell) - The codez is 100% PowerShell.
* [Visual Studio Code](https://code.visualstudio.com/) - Development and authoring IDE. Accept no substitutes.
* [SqlServer Module](https://www.powershellgallery.com/packages/SqlServer) - Used for ETL to SQLNexus database. Shout out to Matteo Taveggia and team for this awesome library.

## Contributing

Please read [CONTRIBUTING.md] for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use Major.Minor.Build for versioning. For the versions available, browse the private [artifact NuGet feed](https://msblox-02.visualstudio.com/SQLAnalyzer/_packaging?_a=feed&feed=SQLAnalyzer-CI) that hosts the SQLAnalyzer module. 

## Authors

* **Tim Chapman** - *Did all the hard work on his own time just because he's that nice of a PFE.* - [LinkedIn](https://www.linkedin.com/in/chapmantim)
* **Ken Kilty** - *Pontificator and digital janitor. All he REALLY did was package up and operationalize Tim's great work using Azure DevOps. He stands on the shoulders of giants.* [Email](kkilty@microsoft.com)
)

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.

## License

This project is part of the PFE PTO Workshop and owned by ASD. For internal use only or for usage in delivery of MIP.

## Acknowledgments

* **CSS & PSSDiag** *The underlying engine (JackLi, KenH, countless others)* [Link to PSSDiag Github Repo](https://github.com/Microsoft/DiagManager) yes it's open source!
* Inspiration: Anyone who has had to run a tool countless times to get an idea of what is broken for a customer.
  **Version: 0.9.13**
  by: kkilt on 05/03/19
  **Version: 0.9.14**
  by: timchap on 05/14/19
  **Version: 0.9.15**
  by: timchap on 05/14/19
  **Version: 0.9.16**
  by: Administrator on 05/15/19
  **Version: 0.9.17**
  by: Administrator on 06/03/19
  **Version: 0.9.18**
  by: Administrator on 06/05/19
  **Version: 0.9.19**
  by: Administrator on 06/21/19
  **Version: 0.9.20**
  by: Administrator on 07/26/19
  **Version: 0.9.21**
  by: Administrator on 11/11/20
  **Version: 0.9.22**
  by: timchap on 12/05/20
