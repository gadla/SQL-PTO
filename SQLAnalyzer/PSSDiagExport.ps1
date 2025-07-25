#Written By:  Tim Chapman
#parameters are so script can be called more easily

param(
    [string]$ServerName = ".", 
    [string]$DatabaseName = "SQLNexus", 
    [string]$SourcePath = ""
)

#Name (default or named) of the SQL instance to upload the data to.
#Winows auth is used right now.  Can change this later if necessary.

#Location of the unzipped output folder from pssdiag.  
if ($SourcePath -eq "")
{
    $CalledFromForm = $False
    $SourcePath = ""  
    $OverwriteLog = $true
}
else
{
    $CalledFromForm = $True
    $OverwriteLog = $true
}

clear-host

#if shorthand name passed in, look up computer name

if ($ServerName -eq "." -or $ServerName -eq "localhost")
{
    $ServerName = $env:COMPUTERNAME
}

#base path where files are located
#pull this dynamically based on where the script is located.

if ($psISE -eq $null)
{
    $CurrentLocation = split-path $PSCommandPath
}
else  
{

    if ($psISE.CurrentFile.FullPath)
    {
        $CurrentLocation = split-path $psISE.CurrentFile.FullPath
    }
    else
    {
        $CurrentLocation = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent
    }

}
Set-Location $CurrentLocation

#set-location C:\Users\Administrator\Documents\WindowsPowerShell\Modules\SQLAnalyzer

#loop through these.

#include helper functions

$Helpers = Get-ChildItem .\Functions\*.ps1

foreach ($Helper in $Helpers)
{
    . $Helper.FullName

}
<#
. .\Functions\Logger.ps1
. .\Functions\Clipboard.ps1
. .\Functions\PSSDiagImportFunctions.ps1
. .\Functions\GenerateChartsFromSQLData.ps1
. .\Functions\CustomerReadyEmail_Pretty.ps1
. .\Functions\CustomImport.ps1   
. .\Functions\UtilityFunctions.ps1
#>

#GetConfigValues
$Config = @{}
[xml]$ConfigXML = Get-Content .\Configuration\SQLAnalyzerConfig.xml
$Config = $ConfigXML.SQLAnalyzer.Configuration

#Create global variable for logging purposes
#May change this later to pass around.
$global:AnalyzerLogging = New-Object -TypeName "System.Collections.ArrayList"
[int] $global:LoggingCounter = 0

#get data related to version
[xml]$VersionDoc = Get-Content .\SQLAnalyzer.nuspec

$ExportFolder = $Config.ExportFolder
$ExportPath = $ExportFolder + $DatabaseName

[bool]$GenerateCharts = [int]($Config.GenerateCharts)

$ProcessingDate = Get-Date -Format "yyyyMMdd_HHmmss"
$logfile = $ExportPath + "\$($DatabaseName)_$ProcessingDate.log"

$DebugPreference = $Config.DebugPreference
Write-Log -Message 'Beginning PSSDiag Processing...' -Path $logfile -OverwriteExisting $OverwriteLog

$CurrentAnalyzerVersion = $VersionDoc.package.metadata.version

$GlobalSettings = get-AnalyzerGlobalSettings

#adding Analyzer version to the log file
Write-Log -Message "SQL Analyzer Version: $CurrentAnalyzerVersion " -Path $logfile -Category "SQL Analyzer Version" -MetricValue $CurrentAnalyzerVersion 
Write-Log -Message "SQL Analyzer ID: $($VersionDoc.package.metadata.id)" -Path $logfile -Category "SQL Analyzer ID" -MetricValue $VersionDoc.package.metadata.id
Write-Log -Message "SQL Analyzer Release Notes: $($VersionDoc.package.metadata.releasenotes)" -Path $logfile -Category "Release Notes" -MetricValue $VersionDoc.package.metadata.releasenotes

write-processingMachineInfoToLog -logfile $logfile

#compare current local version to global version
if ($GlobalSettings)
{
    if ($CurrentAnalyzerVersion -ne $GlobalSettings.CurrentVersion)
    {
        Write-Host "You do not have the current version of SQL Analyzer.  Please download the latest version from http://aka.ms/sqlanalzyer" -BackgroundColor Red
        Write-Log -Message "Not using the current version of SQL Analyzer  Local Version is $CurrentAnalyzerVersion Global version is $($GlobalSettings.CurrentVersion)." -Path $logfile -Category "GlobalConfiguration" -MetricValue "Fail"
    }
    else
    {
        Write-Log -Message "Using the most recent version of SQL Analyzer." -Path $logfile -Category "GlobalConfiguration" -MetricValue "Success"
    }
}
else
{
    Write-Log -Message "Unable to retreive the global SQL Analyzer version." -Path $logfile -Category "GlobalConfiguration" -MetricValue "Fail"
}

#need to wrap some code around this to catch an error if not exists
if (!(Get-Module -ListAvailable -Name SqlServer))
{
    Write-Log -Message 'SqlServer module not found.  Attempting to import...' -Path $logfile -Level Error
    Install-Module SqlServer
}

if (Get-Module -ListAvailable -Name SqlServer)
{
    Import-Module SqlServer
}
else 
{
    Write-Log -Message 'Unable to install SqlServer module.  Exiting...' -Path $logfile -Level Error
    break
}

Write-Log -Message "Executing from location: $CurrentLocation" -Path $logfile

foreach ($ConfigValue in $Config.ChildNodes)
{
    $LogMessage = "$($ConfigValue.Name) : $($ConfigValue.'#text')"
    Write-Log -Message $LogMessage -Path $logfile -Category "ConfigurationValues" -MetricValue $ConfigValue.Name -MetricValue2 $ConfigValue.'#text'
    
}

#only check the Nexus Path if a custom import isn't to be done.
if (!(test-path $Config.SQLNexusPath) -and $Config.PerformCustomImport -eq 0)
{
    Write-Log -Message "Invalid value for the SQL Nexus Path."  -Path $logfile
}

if ($Config.ValidateSourceFolder -eq 1)
{
    if (test-path $SourcePath)
    {
        #make sure there is something in the folder to process
        #make sure one of the following extensions exist in the folder:
        <#
        XEL
        OUT
        TXT
        BLG
        TRC
        SQLPlAN
        #>
        $PssDiagFilesSearchPath = join-path $SourcePath "\*"

        $PSSDiagExtensions = "*.XEL", "*.OUT", "*.TXT", "*.BLG", "*.TRC", "*.SQLPlAN"
        $FoundFiles = Get-ChildItem -Path $PssDiagFilesSearchPath -Include $PSSDiagExtensions
        
        if ($FoundFiles.Count -eq 0)
        {
            Write-Log -Message "Error locating Source Path: $SourcePath. Folder does not contain files to import." -Path $logfile  -Level Error
            return            
        }
    }
    else
    {
        Write-Log -Message "Error locating Source Path: $SourcePath" -Path $logfile 
    }
}

[bool]$ImportData = $false

#1.  Import data into SQL Nexus
if ($Config.PerformNexusImport -eq 1 -and $Config.PerformCustomImport -eq 0)
{
    $ImportData = $true
    Write-Log -Message 'Beginning SQLNexusDataImport' -Path $logfile
    Write-Host 'Beginning SQLNexusDataImport' 

    import-SQLNexusData -SQLNexusPath $Config.SQLNexusPath -ServerName $ServerName -DatabaseName $DatabaseName -ImportFolder $SourcePath -LogFile $logfile -ExportPath $ExportPath
    Write-Log -Message 'Completing SQLNexusDataImport' -Path $logfile
}
elseif ($Config.PerformCustomImport -eq 1)
{
    #do the custom import!
    $ImportData = $true
    try
    {
        [bool]$DropIfExists = [bool]$Config.DropAndCreateDBForCustomImport
        Write-Log -Message "Calling initialize-database for $DatabaseName" -Path $logfile
        initialize-database -ServerName $ServerName -DatabaseName $DatabaseName -DropIfExists $DropIfExists -LogFile $logfile
    }
    catch
    {
        Write-Log -Message "Error calling initialize-database.  Error: $error[0]" -Path $logfile -Level "Error"
    }

    #create dictionary and pass in threshold for skipping large files
    $FileImportSizeRules = @{}
    $FileImportSizeRules.SkipLargeImportFiles = $Config.SkipLargeImportFiles
    $FileImportSizeRules.SkipLargeImportFileSizeCutoffMB = $Config.SkipLargeImportFileSizeCutoffMB

    #figure out where the textrowsets file is
    #if not in the configuration folder (where it should be), go try to use it from Nexus
    if (Test-Path .\Configuration\TextRowsets.xml)
    {
        $TextRowsetLocation = Resolve-Path .\Configuration\TextRowsets.xml
    }
    else 
    {
        $TextRowsetLocation = join-path (split-path $Config.SQLNexusPath) "TextRowsets.xml"
    }

    if (Test-Path $TextRowsetLocation)
    {
        import-pssdiagfolder -SQLServer $ServerName -DatabaseName $DatabaseName -FilePath $SourcePath -LogFile $logfile -TextRowsetLocation $TextRowsetLocation -FileImportSizeRules $FileImportSizeRules
    }
    else 
    {
        Write-Log -Message "Error locating TextRowsets.xml file" -Path $logfile -Level Error
        Break
    }
}
else
{
    #neither flag set, so don't import anything.  Only run reports
    $ImportData = $false
}




#Make sure output path exists.
if (!(test-path -path $ExportPath))
{
    new-item -ItemType directory -path $ExportPath
    Write-Log -Message "Creating Export Path: $ExportPath"  -Path $logfile 
}

#Build Excel file path name
#$ExcelFileName = "$DatabaseName_$ProcessingDate.xls"
$ExcelFileName = $DatabaseName + "_" + $ProcessingDate + ".xls"
$Excelfilepath = join-path -path $ExportPath -childpath $ExcelFileName
Write-Log -Message "Excelfilepath: $Excelfilepath"  -Path $logfile

write-log -Message "Creating Stored Procedures" -Path $logfile -WriteToHost

#2.  Create analysis stored procedures in database created by SQL Nexus import process.
Write-Log -Message 'Beginning LoadSQLAnalysisProcedures' -Path $logfile
import-SQLAnalysisProcedures -ServerName $ServerName -DatabaseName $DatabaseName -SQLFolderpath $CurrentLocation -LogFile $logfile
Write-Log -Message 'Completing LoadSQLAnalysisProcedures' -Path $logfile

#find out what type of SQL environment we are pulling data from
$SQLType = get-sqltype -ServerName $ServerName -DatabaseName $DatabaseName 
Write-Log -Message "The SQLType is: $SQLType" -Path $logfile

#3.  Import some data that is located in the pssdiag output directory that SQL Nexus doesn't load
#  Get these extentions from config files
$errorLogPath = join-path -path $SourcePath -childpath $Config.ErrorLogPathFilter
$MSInfoPath = join-path -path $SourcePath -childpath $Config.MSInfoPathFilter
$BaseTasksPath = join-path -path $SourcePath -childpath $Config.BaseTasksPathFilter
$PlanPath = join-path -path $SourcePath -childpath $Config.PlanPathFilter
$RTDSCPath = join-path -path $SourcePath -childpath $Config.RTDSCPathFilter
$MachinePath = join-path -path $SourcePath -childpath $Config.MachinePathFilter
$DBCCPath = join-path -path $SourcePath -childpath $Config.DBCCPathFilter
$VAPath = join-path -path $SourcePath -childpath $Config.VAPathFilter
$SRPath = join-path -path $SourcePath -childpath $Config.SRPathFilter
$systemHealthPath = join-path -path $SourcePath -childpath $Config.SystemHealthPathFilter


Write-Log -Message "errorLogPath: $errorLogPath" -Path $logfile -Category "ConfigurationSettings" -SubCategory "errorLogPath" -MetricValue $errorLogPath
Write-Log -Message "MSInfoPath: $MSInfoPath" -Path $logfile -Category "ConfigurationSettings" -SubCategory "MSInfoPath" -MetricValue $MSInfoPath 
Write-Log -Message "BaseTasksPath: $BaseTasksPath" -Path $logfile -Category "ConfigurationSettings" -SubCategory "BaseTasksPath" -MetricValue $BaseTasksPath 
Write-Log -Message "PlanPath: $PlanPath" -Path $logfile -Category "ConfigurationSettings" -SubCategory "PlanPath" -MetricValue $PlanPath
Write-Log -Message "RTDSCPath: $RTDSCPath" -Path $logfile -Category "ConfigurationSettings" -SubCategory "RTDSCPath" -MetricValue $RTDSCPath
Write-Log -Message "MachinePath: $MachinePath" -Path $logfile -Category "ConfigurationSettings" -SubCategory "MachinePath" -MetricValue $MachinePath
Write-Log -Message "DBCCPath: $DBCCPath" -Path $logfile -Category "ConfigurationSettings" -SubCategory "DBCCPath" -MetricValue $DBCCPath
Write-Log -Message "Vulnerability Assessment: $VAPath" -Path $logfile -Category "ConfigurationSettings" -SubCategory "Vulnerability Assessment" -MetricValue $VAPath
Write-Log -Message "Sensitivity Recommendations: $SRPath" -Path $logfile -Category "ConfigurationSettings" -SubCategory "Sensitivity Recommendations" -MetricValue $SRPath
Write-Log -Message "systemHealthPath: $systemHealthPath" -Path $logfile -Category "ConfigurationSettings" -SubCategory "systemHealthPath" -MetricValue $systemHealthPath

#bulk insert error log files
if ($Config.LoadErrorLogFromPSSDiag -eq 1 -and $ImportData -and $SQLType -ne "AzureSQL")
{
    Write-Log -Message 'Beginning LoadErrorLogFromPSSDiag' -Path $logfile -WriteToHost -Category "FileProcessing" -SubCategory "LoadErrorLogFromPSSDiag"

    $ErrorLogFiles = Get-ChildItem $errorLogPath
    foreach ($ErrorLogFile in $ErrorLogFiles)
    {
        import-ErrorLogFromPSSDiag -ServerName $ServerName -DatabaseName $DatabaseName -filepath $ErrorLogFile.FullName -logfile $logfile
    }
    Write-Log -Message 'Completing LoadErrorLogFromPSSDiag' -Path $logfile -Category "FileProcessing" -SubCategory "LoadErrorLogFromPSSDiag"
}

#4.  Load data from the MSInfo output file into SQL table.  This is for drive data, partition alignment, etc.
if ($Config.LoadMSInfoFromPSSDiag -eq 1 -and $ImportData -and $SQLType -ne "AzureSQL")
{
    Write-Log -Message 'Beginning LoadMSInfoFromPSSDiag' -Path $logfile -WriteToHost -Category "FileProcessing" -SubCategory "LoadMSInfoFromPSSDiag"
    import-MSInfoFromPSSDiag -ServerName $ServerName -DatabaseName $DatabaseName -filepath $MSInfoPath -LogFile $logfile
    Write-Log -Message 'Completing LoadMSInfoFromPSSDiag' -Path $logfile -Category "FileProcessing" -SubCategory "LoadMSInfoFromPSSDiag"
}

#5.  Get tasks running on the SQL Server machine during analysis.
if ($Config.LoadBaseTaskListFromPSSDiag -eq 1 -and $ImportData -and $SQLType -ne "AzureSQL")
{
    Write-Log -Message 'Beginning LoadBaseTaskListFromPSSDiag' -Path $logfile -WriteToHost -Category "FileProcessing" -SubCategory "LoadBaseTaskListFromPSSDiag"
    import-BaseTaskListFromPSSDiag -ServerName $ServerName -DatabaseName $DatabaseName -filepath $BaseTasksPath -LogFile $logfile
    Write-Log -Message 'Completing LoadBaseTaskListFromPSSDiag' -Path $logfile -Category "FileProcessing" -SubCategory "LoadBaseTaskListFromPSSDiag"
}

#6.  Load any .sqlplan files into the database
if ($Config.LoadSQLPlans -eq 1 -and $ImportData)
{
    Write-Log -Message 'Beginning LoadSQLPlans' -Path $logfile -WriteToHost -Category "FileProcessing" -SubCategory "LoadSQLPlans"
    import-SQLPlans -ServerName $ServerName -DatabaseName $DatabaseName -filepath $PlanPath -LogFile $logfile
    Write-Log -Message 'Completing LoadSQLPlans' -Path $logfile -Category "FileProcessing" -SubCategory "LoadSQLPlans"
}

#7.  Load system_health XE
if (($Config.LoadExtendedEventFiles -eq 1) -and $ImportData)
{
    Write-Log -Message 'Beginning LoadExtendedEventFiles' -Path $logfile -WriteToHost -Category "FileProcessing" -SubCategory "LoadExtendedEventFiles"
    import-ExtendedEventFiles  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $systemHealthPath -LogFile $logfile
    Write-Log -Message 'Completing LoadExtendedEventFiles' -Path $logfile -Category "FileProcessing" -SubCategory "LoadExtendedEventFiles"
}

if ($Config.SQLSystemHealthAnalysis -eq 1 -and $ImportData)
{
    Write-Log -Message 'Beginning System_Health Analysis' -Path $logfile -WriteToHost -Category "FileProcessing" -SubCategory "SystemHealthAnalysis"
    invoke-SQLSystemHealthAnalysis -ServerName $ServerName -DatabaseName $DatabaseName -LogFile $logfile
    Write-Log -Message 'Completing SQLNexusDataImport' -Path $logfile -Category "FileProcessing" -SubCategory "SystemHealthAnalysis"
}

if ($Config.LoadRDTSCFromPSSDiag -eq 1 -and $ImportData -and $SQLType -ne "AzureSQL")
{
    Write-Log -Message 'Beginning LoadRDTSCFromPSSDiag' -Path $logfile -WriteToHost -Category "FileProcessing" -SubCategory "LoadRDTSCFromPSSDiag"
    import-RDTSCFromPSSDiag  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $RTDSCPath -LogFile $logfile
    Write-Log -Message 'Completing LoadRDTSCFromPSSDiag' -Path $logfile -WriteToHost -Category "FileProcessing" -SubCategory "LoadRDTSCFromPSSDiag"
}

if ($Config.LoadMachineCheckFromPSSDiag -eq 1 -and $ImportData -and $SQLType -ne "AzureSQL")
{
    Write-Log -Message 'Beginning LoadMachineCheckFromPSSDiag' -Path $logfile -WriteToHost -Category "FileProcessing" -SubCategory "LoadMachineCheckFromPSSDiag"
    import-MachineCheckFromPSSDiag  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $MachinePath -LogFile $logfile
    Write-Log -Message 'Completing LoadMachineCheckFromPSSDiag' -Path $logfile -Category "FileProcessing" -SubCategory "LoadMachineCheckFromPSSDiag"
}

if ($Config.ProcessDBCCMemoryStatus -eq 1 -and $ImportData)
{
    Write-Log -Message 'Beginning DBCCMemoryStatus' -Path $logfile -WriteToHost -Category "FileProcessing" -SubCategory "DBCCMemoryStatus"
    $DBCCRowsInserted = import-DBCCMemoryStatus  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $DBCCPath -LogFile $logfile
    Write-Log -Message 'Completing DBCCMemoryStatus' -Path $logfile -Category "FileProcessing" -SubCategory "DBCCMemoryStatus" -MetricValue $DBCCRowsInserted
}

if ($Config.IncludeSecurityAssessment -eq 1)
{
    $Category = "SecurityAssessment"
    Write-Log -Message 'Beginning Security Assessment' -Path $logfile -WriteToHost -Category $Category
    import-VulnerabilityAssessment  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $VAPath -LogFile $logfile
    import-SensitivityRecommendations  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $SRPath -LogFile $logfile
    Write-Log -Message 'Completing Security Assessment' -Path $logfile -Category $Category
}

#Write-Log -Message 'Beginning GenerateTSPROutput' -Path $logfile
#GenerateTSPROutput  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $SourcePath -logfile $logfile
#Write-Log -Message 'Completing GenerateTSPROutput' -Path $logfile

#Generate the excel report.
if ($Config.GenerateExcelReport -eq 1)
{
    Write-Log -Message 'Beginning GenerateExcelReport' -Path $logfile -WriteToHost
    create-ExcelReport -ServerName $ServerName -DatabaseName $DatabaseName -filepath $Excelfilepath -logfile $logfile
    Write-Log -Message 'Completing GenerateExcelReport' -Path $logfile
}

Set-Location $CurrentLocation

if ($SQLType -notlike "*AzureSQL*")
{
    if ($Config.GenerateSQLSummary -eq 1)
    {
        Write-Log -Message 'Beginning create-SQLPerfmonSummary' -Path $logfile -WriteToHost
        $SummaryCounterData = create-SQLPerfmonSummary -OutputPath  $ExportPath -GenerateCharts  $true -ServerName $ServerName -DatabaseName $DatabaseName -logfile $logfile
        Write-Log -Message 'Completing create-SQLPerfmonSummary' -Path $logfile
    }


    if ($Config.GenerateRelogFiles -eq 1)
    {
        Write-Log -Message 'Beginning GenerateRelogFiles' -Path $logfile -WriteToHost
        create-RelogFiles -SourcePath $SourcePath  -OutputPath  $ExportPath -logfile $logfile
        Write-Log -Message 'Completing GenerateRelogFiles' -Path $logfile
    }
}

$ReportName = "FindingsReport_" + $DatabaseName + "_" + $ProcessingDate + ".docx"
$FindingsReportPath = join-path -path $ExportPath -childpath $ReportName
if ($Config.GenerateFindingsReport -eq 1)
{
    $CollectUserCustomerInfo = $Config.CollectUserCustomerInfo
    Write-Log -Message 'Beginning GenerateFindingsReport' -Path $logfile -WriteToHost
    ##create-FindingsReport  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $FindingsReportPath -logfile $logfile -SummaryData $SummaryCounterData
    create-FindingsReportUsingLayout -ServerName $ServerName -DatabaseName $DatabaseName -filepath $FindingsReportPath -logfile $logfile -SummaryData $SummaryCounterData -CollectUserCustomerInfo $CollectUserCustomerInfo -SQLType $SQLType
    
    Write-Log -Message 'Completing GenerateFindingsReport' -Path $logfile
}

#$variables = Get-Variable
#write-UserVariablesToLog -Variables $variables -LogFile $logfile -Category "UserVariables" 

$JsonLogFileName = $DatabaseName + "_" + $ProcessingDate + ".json"
$jsonpath = join-path $ExportPath $JsonLogFileName
$AnalyzerLogging | ConvertTo-Json | Out-File $jsonpath

if ($GlobalSettings)
{
    save-logfile -LogFile $jsonpath -StoragePath $GlobalSettings.Body
}
write-host "All done."



<#
if($PTOReports -eq $true)
{
    Write-Log -Message 'Beginning Word Graph Doc' -Path $logfile 
    GenerateWordReport -ServerName $ServerName -DatabaseName $DatabaseName -filepath $ExcelGraphsfilepath -filepathword $Wordfilepath -filetemplate $Wordtemplatepath
    Write-Log -Message 'Completing Word Graph Doc' -Path $logfile
}
#>


