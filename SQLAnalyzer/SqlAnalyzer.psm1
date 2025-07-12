#Requires -Modules SqlServer
#Get public and private function definition files.
$Private = @( Get-ChildItem -Path $PSScriptRoot\Functions\*.ps1 -ErrorAction SilentlyContinue )

#Import the logger first
. "$PSScriptRoot\Functions\Logger.ps1"

#Dot source the files
Foreach ($import in @($Private))
{
    Try
    {
        . $import.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

#Begin core module functions
Function Start-SqlAnalyzer {
    [CmdletBinding()]
    Param(
        [string]$ServerName = ".", 
        [string]$DatabaseName = "SQLNexus",
        [string]$SourcePath = ""
    )

    #Location of the unzipped output folder from pssdiag.  
    if($SourcePath -eq "")
    {
        $SourcePath = ""  
        $OverwriteLog = $true
    }
    else
    {
        $OverwriteLog = $true
    }

    #if shorthand name passed in, look up computer name
    if($ServerName -eq "." -or $ServerName -eq "localhost")
    {
        $ServerName = $env:COMPUTERNAME
    }

    #base path where files are located
    #pull this dynamically based on where the script is located.
    if ($null -eq $psISE)
    {
        $CurrentLocation = Split-Path $PSCommandPath
    }
    else  
    {
        if ($psISE.CurrentFile.FullPath)
        {
            $CurrentLocation = Split-Path $psISE.CurrentFile.FullPath
        }
        else
        {
            $CurrentLocation = Split-Path $SCRIPT:MyInvocation.MyCommand.Path -Parent
        }
    }

    Set-Location $CurrentLocation

    #GetConfigValues
    $Config = @{}
    [xml]$ConfigXML = Get-Content .\Configuration\SQLAnalyzerConfig.xml
    $Config = $ConfigXML.SQLAnalyzer.Configuration

    $ExportFolder = $Config.ExportFolder
    $ExportPath =  $ExportFolder + $DatabaseName

    $archiveFolder = $(New-Item -Path $ExportFolder -Name "Archive$([DateTime]::UtcNow.ToString("MMddyyyy-hhmmss"))" -ItemType Directory )
    Write-Output "'$ExportFolder' to '$archiveFolder'"
    Get-ChildItem -Path $ExportFolder -Recurse -Exclude $archiveFolder.Name | Move-Item -Destination $archiveFolder -ErrorAction SilentlyContinue

    $logfile = $ExportPath + "\$DatabaseName.log"

    $DebugPreference = $Config.DebugPreference
    Write-Log -Message 'Beginning PSSDiag Processing...' -Path $logfile -OverwriteExisting $OverwriteLog

    #need to wrap some code around this to catch an error if not exists
    if(!(Get-Module -ListAvailable -Name SqlServer))
    {
        Write-Log -Message 'SqlServer module not found.  Attempting to import...' -Path $logfile -Level Error
        Install-Module SqlServer
    }

    if(Get-Module -ListAvailable -Name SqlServer)
    {
        Import-Module SqlServer
    }
    else 
    {
        Write-Log -Message 'Unable to install SqlServer module.  Exiting...' -Path $logfile -Level Error
        break
        
    }

    foreach($ConfigValue in $Config.ChildNodes)
    {
        $LogMessage = "$($ConfigValue.Name) : $($ConfigValue.'#text')"
        Write-Log -Message $LogMessage -Path $logfile 
    }

    #only check the Nexus Path if a custom import isn't to be done.
    if(!(test-path $Config.SQLNexusPath) -and $Config.PerformCustomImport -eq 0)
    {
        Write-Log -Message "Invalid value for the SQL Nexus Path."  -Path $logfile 
    }

    if($Config.ValidateSourceFolder -eq 1)
    {
        if(test-path $SourcePath)
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

            $PSSDiagExtensions = "*.XEL","*.OUT","*.TXT","*.BLG","*.TRC","*.SQLPlAN"
            $FoundFiles = Get-ChildItem -Path $PssDiagFilesSearchPath -Include $PSSDiagExtensions
            
            if($FoundFiles.Count -eq 0)
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

    #1.  Import data into SQL Nexus
    if($Config.PerformNexusImport -eq 1 -and $Config.PerformCustomImport -eq 0)
    {
        Write-Log -Message 'Beginning SQLNexusDataImport' -Path $logfile
        Write-Host 'Beginning SQLNexusDataImport' 

        import-SQLNexusData -SQLNexusPath $Config.SQLNexusPath -ServerName $ServerName -DatabaseName $DatabaseName -ImportFolder $SourcePath -LogFile $logfile -ExportPath $ExportPath
        Write-Log -Message 'Completing SQLNexusDataImport' -Path $logfile
    }
    elseif($Config.PerformCustomImport -eq 1)
    {
        #do the custom import!
        try
        {
            [bool]$DropIfExists = [bool]$Config.DropAndCreateDBForCustomImport
            Write-Log -Message "Calling initialize-database for $DatabaseName" -Path $logfile
            initialize-database -ServerName $ServerName -DatabaseName $DatabaseName -DropIfExists $DropIfExists
        }
        catch
        {
            Write-Log -Message "Error calling initialize-database.  Error: $error[0]" -Path $logfile
        }


        #figure out where the textrowsets file is
        #if not in the configuration folder (where it should be), go try to use it from Nexus
        if(Test-Path .\Configuration\TextRowsets.xml)
        {
            $TextRowsetLocation = Resolve-Path .\Configuration\TextRowsets.xml
        }
        else 
        {
            $TextRowsetLocation = join-path (split-path $Config.SQLNexusPath) "TextRowsets.xml"
        }

        if(Test-Path $TextRowsetLocation)
        {
                import-pssdiagfolder -SQLServer $ServerName -DatabaseName $DatabaseName -FilePath $SourcePath -LogFile $logfile -TextRowsetLocation $TextRowsetLocation
        }
        else 
        {
            Write-Log -Message "Error locating TextRowsets.xml file" -Path $logfile -Level Error
            Break
        }
    }

    #Make sure output path exists.
    if(!(test-path -path $ExportPath))
    {
        new-item -ItemType directory -path $ExportPath
        Write-Log -Message "Creating Export Path: $ExportPath"  -Path $logfile 
    }

    #Build Excel file path name
    $Excelfilepath = join-path -path $ExportPath -childpath "$DatabaseName.xls"; 
    Write-Log -Message "Excelfilepath: $Excelfilepath"  -Path $logfile

    write-host "Creating Stored Procedures"

    #2.  Create analysis stored procedures in database created by SQL Nexus import process.
    Write-Log -Message 'Beginning LoadSQLAnalysisProcedures' -Path $logfile
    import-SQLAnalysisProcedures -ServerName $ServerName -DatabaseName $DatabaseName -SQLFolderpath $CurrentLocation -LogFile $logfile
    Write-Log -Message 'Completing LoadSQLAnalysisProcedures' -Path $logfile



    #3.  Import some data that is located in the pssdiag output directory that SQL Nexus doesn't load
    #  Get these extentions from config files
    $errorLogPath = join-path -path $SourcePath -childpath $Config.ErrorLogPathFilter
    $MSInfoPath = join-path -path $SourcePath -childpath $Config.MSInfoPathFilter
    $BaseTasksPath = join-path -path $SourcePath -childpath $Config.BaseTasksPathFilter
    $PlanPath = join-path -path $SourcePath -childpath $Config.PlanPathFilter
    $RTDSCPath = join-path -path $SourcePath -childpath $Config.RTDSCPathFilter
    $MachinePath = join-path -path $SourcePath -childpath $Config.MachinePathFilter
    $DBCCPath = join-path -path $SourcePath -childpath $Config.DBCCPathFilter
    $systemHealthPath = join-path -path $SourcePath -childpath $Config.SystemHealthPathFilter


    Write-Log -Message "errorLogPath: $errorLogPath" -Path $logfile
    Write-Log -Message "MSInfoPath: $MSInfoPath" -Path $logfile
    Write-Log -Message "BaseTasksPath: $BaseTasksPath" -Path $logfile
    Write-Log -Message "PlanPath: $PlanPath" -Path $logfile
    Write-Log -Message "RTDSCPath: $RTDSCPath" -Path $logfile
    Write-Log -Message "MachinePath: $MachinePath" -Path $logfile
    Write-Log -Message "DBCCPath: $DBCCPath" -Path $logfile
    Write-Log -Message "systemHealthPath: $systemHealthPath" -Path $logfile

    #bulk insert error log files
    if($Config.LoadErrorLogFromPSSDiag -eq 1)
    {
        Write-Log -Message 'Beginning LoadErrorLogFromPSSDiag' -Path $logfile
        Write-Debug -Message 'Beginning LoadErrorLogFromPSSDiag'

        $ErrorLogFiles = Get-ChildItem $errorLogPath
        foreach($ErrorLogFile in $ErrorLogFiles)
        {
        import-ErrorLogFromPSSDiag -ServerName $ServerName -DatabaseName $DatabaseName -filepath $ErrorLogFile.FullName -logfile $logfile -SkipLoginSuccess 1 -SkipLogBackupSuccess 1
        }
        Write-Log -Message 'Completing LoadErrorLogFromPSSDiag' -Path $logfile
        Write-Debug -Message 'Completing LoadErrorLogFromPSSDiag'
    }

    #4.  Load data from the MSInfo output file into SQL table.  This is for drive data, partition alignment, etc.
    if($Config.LoadMSInfoFromPSSDiag -eq 1)
    {
        Write-Log -Message 'Beginning LoadMSInfoFromPSSDiag' -Path $logfile
        Write-Debug -Message 'Beginning LoadMSInfoFromPSSDiag'
        import-MSInfoFromPSSDiag -ServerName $ServerName -DatabaseName $DatabaseName -filepath $MSInfoPath -LogFile $logfile
        Write-Log -Message 'Completing LoadMSInfoFromPSSDiag' -Path $logfile
        Write-Debug -Message 'Completing LoadMSInfoFromPSSDiag'
    }

    #5.  Get tasks running on the SQL Server machine during analysis.
    if($Config.LoadBaseTaskListFromPSSDiag -eq 1)
    {
        Write-Log -Message 'Beginning LoadBaseTaskListFromPSSDiag' -Path $logfile
        Write-Debug -Message 'Beginning LoadBaseTaskListFromPSSDiag'
        import-BaseTaskListFromPSSDiag -ServerName $ServerName -DatabaseName $DatabaseName -filepath $BaseTasksPath -LogFile $logfile
        Write-Log -Message 'Completing LoadBaseTaskListFromPSSDiag' -Path $logfile
        Write-Debug -Message 'Completing LoadBaseTaskListFromPSSDiag'
    }

    #6.  Load any .sqlplan files into the database
    if($Config.LoadSQLPlans -eq 1)
    {
        Write-Log -Message 'Beginning LoadSQLPlans' -Path $logfile
        Write-Debug -Message 'Beginning LoadSQLPlans'
        import-SQLPlans -ServerName $ServerName -DatabaseName $DatabaseName -filepath $PlanPath -LogFile $logfile
        Write-Log -Message 'Completing LoadSQLPlans' -Path $logfile
        Write-Debug -Message 'Completing LoadSQLPlans'
    }

    #7.  Load system_health XE
    if($Config.LoadExtendedEventFiles -eq 1)
    {
        Write-Log -Message 'Beginning LoadExtendedEventFiles' -Path $logfile
        Write-Debug -Message 'Beginning LoadExtendedEventFiles'
        import-ExtendedEventFiles  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $systemHealthPath -LogFile $logfile
        Write-Log -Message 'Completing LoadExtendedEventFiles' -Path $logfile
        Write-Debug -Message 'Completing LoadExtendedEventFiles'
    }

    if($Config.SQLSystemHealthAnalysis -eq 1)
    {
        Write-Log -Message 'Beginning System_Health Analysis' -Path $logfile
        invoke-SQLSystemHealthAnalysis -ServerName $ServerName -DatabaseName $DatabaseName -LogFile $logfile
        Write-Log -Message 'Completing SQLNexusDataImport' -Path $logfile
    }

    if($Config.LoadRDTSCFromPSSDiag -eq 1)
    {
        Write-Log -Message 'Beginning LoadRDTSCFromPSSDiag' -Path $logfile
        Write-Debug -Message 'Beginning LoadRDTSCFromPSSDiag'
        import-RDTSCFromPSSDiag  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $RTDSCPath -LogFile $logfile
        Write-Log -Message 'Completing LoadRDTSCFromPSSDiag' -Path $logfile
        Write-Debug -Message 'Completing LoadRDTSCFromPSSDiag'
    }

    if($Config.LoadMachineCheckFromPSSDiag -eq 1)
    {
        Write-Log -Message 'Beginning LoadMachineCheckFromPSSDiag' -Path $logfile
        Write-Debug -Message 'Beginning LoadMachineCheckFromPSSDiag'
        import-MachineCheckFromPSSDiag  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $MachinePath -LogFile $logfile
        Write-Log -Message 'Completing LoadMachineCheckFromPSSDiag' -Path $logfile
        Write-Debug -Message 'Completing LoadMachineCheckFromPSSDiag'
    }

    if($Config.ProcessDBCCMemoryStatus -eq 1)
    {
        Write-Log -Message 'Beginning DBCCMemoryStatus' -Path $logfile
        Write-Debug -Message 'Beginning DBCCMemoryStatus'
        import-DBCCMemoryStatus  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $DBCCPath -LogFile $logfile
        Write-Log -Message 'Completing DBCCMemoryStatus' -Path $logfile
        Write-Debug -Message 'Completing DBCCMemoryStatus'
    }

    #Write-Log -Message 'Beginning GenerateTSPROutput' -Path $logfile
    #GenerateTSPROutput  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $SourcePath -logfile $logfile
    #Write-Log -Message 'Completing GenerateTSPROutput' -Path $logfile

    #Generate the excel report.
    if($Config.GenerateExcelReport -eq 1)
    {
        Write-Log -Message 'Beginning GenerateExcelReport' -Path $logfile 
        Write-Debug -Message 'Beginning GenerateExcelReport'
        create-ExcelReport -ServerName $ServerName -DatabaseName $DatabaseName -filepath $Excelfilepath -logfile $logfile
        Write-Log -Message 'Completing GenerateExcelReport' -Path $logfile
        Write-Debug -Message 'Completing GenerateExcelReport'
    }

    Set-Location $CurrentLocation

    if($Config.GenerateSQLSummary -eq 1)
    {
        Write-Log -Message 'Beginning GenerateSQLSummary' -Path $logfile 
        Write-Debug -Message 'Beginning GenerateSQLSummary'
        $SummaryCounterData = create-SQLSummary -OutputPath  $ExportPath -GenerateCharts  $true -ServerName $ServerName -DatabaseName $DatabaseName -logfile $logfile
        Write-Log -Message 'Completing GenerateSQLSummary' -Path $logfile
        Write-Debug -Message 'Completing GenerateSQLSummary'
    }


    if($Config.GenerateRelogFiles -eq 1)
    {
        Write-Log -Message 'Beginning GenerateRelogFiles' -Path $logfile 
        Write-Debug -Message 'Beginning GenerateRelogFiles'
        create-RelogFiles -SourcePath $SourcePath  -OutputPath  $ExportPath -logfile $logfile
        Write-Log -Message 'Completing GenerateRelogFiles' -Path $logfile
        Write-Debug -Message 'Completing GenerateRelogFiles'
    }

    $FindingsReportPath = join-path -path $ExportPath -childpath "FindingsReport_$DatabaseName.docx"; 
    if($Config.GenerateFindingsReport -eq 1)
    {
        Write-Log -Message 'Beginning GenerateFindingsReport' -Path $logfile 
        Write-Debug -Message 'Beginning GenerateFindingsReport' 
        create-FindingsReport  -ServerName $ServerName -DatabaseName $DatabaseName -filepath $FindingsReportPath -logfile $logfile -SummaryData $SummaryCounterData
        Write-Log -Message 'Completing GenerateFindingsReport' -Path $logfile
        Write-Debug -Message 'Completing GenerateFindingsReport' 
    }

    write-host "All done."
}

New-Alias -Name ssa -Value Start-SqlAnalyzer -Description "Start SQLAnalyzer Processing" -Force