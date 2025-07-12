<#
Written by:  Tim Chapman, Microsoft
3/1/2017
#>
##set-location c:\sqlanalyzer
. .\Functions\Logger.ps1
. .\Functions\CustomImport.ps1

Import-Module SqlServer

#$ErrorActionPreference = "SilentlyContinue"


function convert-MSInfoToTables
{
    param
    (
        $ServerName, 
        $DatabaseName, 
        $logfile
    )

    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    $Connection = New-Object System.Data.SQLClient.SQLConnection
    $Connection.ConnectionString = "server=$ServerName;database=$DatabaseName;trusted_connection=true;"
    $Connection.Open()
    $Command = New-object System.Data.SQLClient.SQLCommand 
    $Command.Connection = $Connection
    $bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($Connection.ConnectionString, [System.Data.SqlClient.SqlBulkCopyOptions]::TableLock) 
    $bulkcopy.bulkcopyTimeout = 0 
    
    
    $MSInfoTags = @()
    $MSInfoTags += @{Tag = "[System Summary]"; TableName = "cust_MSINFO_SystemSummary"}
    $MSInfoTags += @{Tag = "[Services]"; TableName = "cust_MSINFO_Services"}
    $MSInfoTags += @{Tag = "[Loaded Modules]"; TableName = "cust_MSINFO_LoadedModules"}
    $MSInfoTags += @{Tag = "[System Drivers]"; TableName = "cust_MSINFO_SystemDrivers"}
    $MSInfoTags += @{Tag = "[Running Tasks]"; TableName = "cust_MSINFO_RunningTasks"}
    
    
    foreach($MSInfo in $MSInfoTags)
    {
        $Category = $MSInfo.Tag
        $TableName = $MSInfo.TableName
    
        $Query = Invoke-Sqlcmd -ConnectionString $Connection.ConnectionString -Query "SELECT  [InfoDesc]  FROM [dbo].[cust_MSInfo] WHERE Category = '$Category' AND InfoDesc <> '$Category' ORDER BY IDCol ASC"  -As DataTables
        [int] $LineNumber = 1
        $DataTableForInsert = New-Object System.Data.DataTable 
        foreach($row in $Query)
        {
            
            $line = $row["InfoDesc"]
    
             if($LineNumber -eq 1)
                {
           
                    $ColNameArray = $line.Split("`t").replace(" ", "_") -gt ""
                    $ColumnObject = @()
    
                    foreach($Column in $ColNameArray)
                    {
                        $ColumnObject += @{ColName = $Column; ColLength = 1000}
                        $null = $DataTableForInsert.Columns.Add($Column) 
                    }
    
                    $Command.CommandText = "IF OBJECT_ID('$TableName') IS NOT NULL DROP TABLE $TableName "
                    $Command.ExecuteNonQuery() |Out-Null
    
                    $sql = get-createtablestatement -ColumnObject $ColumnObject -TableName $TableName
                    $Command.CommandText = $sql
                    $null = $Command.ExecuteNonQuery() 
                }
                else
                {
                    $ValuesArray = $line.Split("`t")
    
                    $ColIndex = 0
                    $NewDataRow = $DataTableForInsert.NewRow()
                    foreach($Column in $ColNameArray)
                    {
                        $nr = $NewDataRow[$Column] = $ValuesArray[$ColIndex]
                        $ColIndex += 1
                    }
                    $i = $DataTableForInsert.rows.Add($NewDataRow)
                }
                $LineNumber += 1
        }
            $bulkcopy.DestinationTableName = $TableName
            $bulkcopy.WriteToServer($DataTableForInsert)  
    }
    
}

function import-ErrorLogFromPSSDiag
{
    param
    (
    $ServerName, 
    $DatabaseName, 
    $FilePath, 
    $logfile = "", 
    [int]$SkipLoginSuccess = 1, 
    [int]$SkipLogBackupSuccess = 1
    )
    
    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    if(test-path $filepath)
    {
        try
        {

            #$x = get-content $filepath
            $Connection = New-Object System.Data.SQLClient.SQLConnection
            $Connection.ConnectionString = "server='$ServerName';database='$DatabaseName';trusted_connection=true;"
            $Connection.Open()
            $Command = New-Object System.Data.SQLClient.SQLCommand
            $Command.Connection = $Connection

            $OutputFile = Get-ChildItem $FilePath
            write-FileImportData -ServerName $SQLServer -DatabaseName $DatabaseName -FileName $OutputFile.Name -FileSizeKB $OutputFile.Length/1KB -LogFile $logfile

            $sql ="IF OBJECT_ID('cust_ErrorLog') IS NOT NULL
            DROP TABLE cust_ErrorLog
            CREATE TABLE cust_ErrorLog(IDCol INT IDENTITY PRIMARY KEY CLUSTERED, ErrorDate VARCHAR(40), ErrorMessage VARCHAR(MAX))" 

            $Command.CommandText = $sql
            $z = $Command.ExecuteNonQuery()
            $BatchSize = 25000

            $DataTableForInsert = New-Object System.Data.DataTable 
            $DataTableForInsert.Columns.Add("ErrorDate") |out-null
            $DataTableForInsert.Columns.Add("ErrorMessage") |out-null
            $bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($Connection.ConnectionString, [System.Data.SqlClient.SqlBulkCopyOptions]::TableLock) 
            $bulkcopy.DestinationTableName = "cust_ErrorLog"
    
            $bulkcopy.bulkcopyTimeout = 0 
            $bulkcopy.batchsize = $batchsize 
            $bulkcopy.ColumnMappings.Add("ErrorDate","ErrorDate") |Out-Null
            $bulkcopy.ColumnMappings.Add("ErrorMessage","ErrorMessage") |Out-Null

            foreach($line in [System.IO.File]::ReadLines($FilePath))
            {
                $LineNumber += 1

                #$line

                if($line.length -ge 24)
                {
                    $errorDate = $line.Substring(0,24)
                }
                else {
                    $errorDate = $null
                }
                #if errorDAte is valid, parse as normal, otherwise put all data inot the ErrorMessage col
                if ([string]$errorDate -as [DateTime])  
                {
                    $errorMessage = $line.Substring($errorDate.Length, $line.Length - $errorDate.Length-1)
                }
                else 
                {
                    $errorDate = $null
                    $errorMessage = $line
                }

                #skip records we won't do anything with
                #TC 03/23/2021
                $skipRow = 0

                if ($SkipLoginSuccess -eq 1 -and $errorMessage -match "Logon Login succeeded for user*")
                {
                    $skipRow = 1
                }

                if ($SkipLogBackupSuccess -eq 1 -and $errorMessage -match "Backup Log was backed up. Database*")
                {
                    $skipRow = 1
                }

                #don't import these messages.  THey are not useful
                if ($errorMessage -eq "Logon Error: 18456, Severity: 14, State: 8")
                {
                    $skipRow = 1
                }
                
                if($skipRow -eq 0)
                {
                    $NewDataRow = $DataTableForInsert.NewRow() 
                    $NewDataRow["ErrorDate"] = $errorDate
                    $NewDataRow["ErrorMessage"] = $errorMessage

                    $DataTableForInsert.rows.Add($NewDataRow)                    
                }

                if (($LineNumber % $BatchSize) -eq 0) 
                {  
                    $bulkcopy.WriteToServer($DataTableForInsert) 
                    $DataTableForInsert.Clear()  
                }  

            }

                # Add in all the remaining rows before the end of the function call
                if($DataTableForInsert.Rows.Count -gt 0) 
                { 
                    $bulkcopy.WriteToServer($DataTableForInsert) 
                    $DataTableForInsert.Clear() 
                } 

        $Connection.Close()
        }
        catch
        {
            $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0] + " Line Number: " + $MyInvocation.ScriptLineNumber + `
            " Offset: " + $MyInvocation.OffsetInLine + " FilePath: " + $FilePath 

            Write-Log -Message $errormsg -Path $logfile -Level Error
        }
    }
}





function import-MSInfoFromPSSDiag
{
    param
    (
    $ServerName, 
    $DatabaseName, 
    $filepath, 
    $logfile
    )

    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    try
    {
        if(test-path $filepath)
        {
            $x = get-content $filepath
            $Connection = New-Object System.Data.SQLClient.SQLConnection
            $Connection.ConnectionString = "server='$ServerName';database='$DatabaseName';trusted_connection=true;"
            $Connection.Open()
            $Command = New-Object System.Data.SQLClient.SQLCommand
            $Command.Connection = $Connection

            $OutputFile = Get-ChildItem $FilePath
            write-FileImportData -ServerName $SQLServer -DatabaseName $DatabaseName -FileName $OutputFile.Name -FileSizeKB $OutputFile.Length/1KB -LogFile $logfile


            $sql ="IF OBJECT_ID('cust_MSInfo') IS NOT NULL
            DROP TABLE  cust_MSInfo
            CREATE TABLE cust_MSInfo(IDCol INT IDENTITY, InfoDesc VARCHAR(MAX), Category varchar(50))" 
            $Command.CommandText = $sql
            $MSInfoOutput = $Command.ExecuteNonQuery()

            $pattern = [regex] "\A\[([^\[]*)\]"  #looking for [*]
            $category = ""

            foreach($i in $x) 
            {
            $i = $i.Replace("'","''")

            if($i -gt "")
            {
                $match = $pattern.Match($i)
                if($match.Success -eq $true)
                {
                    $category = $i
                }
        
                $sql ="INSERT cust_MSInfo (InfoDesc, Category)
                    SELECT '$i', '$category'" 

                $Command.CommandText = $sql
                $MSInfo = $Command.ExecuteNonQuery()
            }
        }
        $Connection.Close()
        convert-MSInfoToTables -ServerName $ServerName -DatabaseName $DatabaseName -logfile $logfile
        }

        

    }
    catch
    {
        $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0]
        Write-Log -Message $errormsg -Path $logfile -Level "Error"
    }

}

function import-BaseTaskListFromPSSDiag
{
param
(
$ServerName, 
$DatabaseName, 
$filepath, 
$logfile
)
    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    try
    {
        if(test-path $filepath)
        {
            $x = get-content $filepath
            $Connection = New-Object System.Data.SQLClient.SQLConnection
            $Connection.ConnectionString = "server='$ServerName';database='$DatabaseName';trusted_connection=true;"
            $Connection.Open()
            $Command = New-Object System.Data.SQLClient.SQLCommand
            $Command.Connection = $Connection

            $OutputFile = Get-ChildItem $FilePath
            write-FileImportData -ServerName $SQLServer -DatabaseName $DatabaseName -FileName $OutputFile.Name -FileSizeKB $OutputFile.Length/1KB -LogFile $logfile

            $sql ="IF OBJECT_ID('cust_TaskList') IS NOT NULL
            DROP TABLE  cust_TaskList
            CREATE TABLE cust_TaskList(IDCol INT IDENTITY, InfoDesc VARCHAR(MAX), Category varchar(50))" 
            $Command.CommandText = $sql
            $z = $Command.ExecuteNonQuery()

            $sql ="IF OBJECT_ID('cust_ProcessList') IS NOT NULL
            DROP TABLE  cust_ProcessList
            CREATE TABLE cust_ProcessList(IDCol INT IDENTITY, 
            ImageName varchar(255),                    
            PID varchar(255),
            SessionName varchar(255),        
            SessionNumber varchar(255),    
            MemUsage varchar(255),
            Status varchar(255),          
            UserName varchar(255),                                              
            CPUTime varchar(255)   
        
            )" 
            $Command.CommandText = $sql
            $z = $Command.ExecuteNonQuery()

            $pattern = [regex] "\(([^\[]*)\)\z"  #looking for (*)

            foreach($i in $x) 
            {
                $i = $i.Replace("'","''")
                if($i -gt "")
                {
                    $match = $pattern.Match($i)
                    if($match.Success -eq $true)
                    {
                        $category = $i
                    }

                    $sql ="INSERT cust_TaskList (InfoDesc, Category)
                        SELECT '$i', '$category'" 
                    $Command.CommandText = $sql
                    $CustTaskList = $Command.ExecuteNonQuery()

                    if($category -eq "TASKLIST /V (process list)")
                    {
                        $tst = $i.Replace("NT ","NT").Replace("Not Responding","NotResponding").Replace(" K ","K ")

                        #$template = @'
                        #{Imagename*:smss.exe}, {PID:276}, {SessionName:Services}, {SessionNo:0}, {MemUsage:1,044 k}, {Status:Unknown},{UserName:NT AUTHORITY\SYSTEM},{CPUTime:0:00:00}, {WindowTitle:N/A}
                        #{Imagename*:smss.exe}, {PID:276}, {SessionName:Services}, {SessionNo:0}, {MemUsage:21,044 k}, {Status:Not Responding},{UserName:NT AUTHORITY\NETWORK SERVICE},{CPUTime:0:00:00}, {WindowTitle:DWM Notification Window}
                        #{Imagename*:sqlservr.exe}, {PID:1208}, {SessionName:Services}, {SessionNo:0}, {MemUsage:3,333,21,044 k}, {Status:Started},{UserName:Analysis\timchapman},{CPUTime:0:00:00}, {WindowTitle:DWM Notification Window}
                        #'@

                        $FullList = $tst | ConvertFrom-String -PropertyNames ImageName, PID, SessionName, SessionNo, MemUsage, Status, UserName, CPUTime, Window
                    
                        foreach($zz in $FullList)
                        {
                            $ImageName = $zz.ImageName
                            $PID1 = $zz.PID
                            $SessionName = $zz.SessionName
                            $SessionNo = $zz.SessionNo
                            $MemUsage = $zz.MemUsage
                            $Status = $zz.Status
                            $UserName = $zz.UserName
                            $CPUTime = $zz.CPUTime

                        if($PID1 -ne "/V" -and $PID1 -ne "Name" -and $PID1 -notlike "*==*")
                        {
                            $sql ="INSERT INTO cust_ProcessList(ImageName,                    
                            PID,
                            SessionName,        
                            SessionNumber,    
                            MemUsage,
                            Status,          
                            UserName,                                              
                            CPUTime)
                            SELECT '$ImageName', '$PID1', '$SessionName', '$SessionNo', '$MemUsage', '$Status', '$UserName', '$CPUTime'"
                   
                            #$sql
                            $Command.CommandText = $sql
                            $ProcessListOutput = $Command.ExecuteNonQuery()
                        }
                        }
                    }
                }
            }
            $Connection.Close()
        }
    }
    catch
    {
        $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0]
        Write-Log -Message $errormsg -Path $logfile -Level Error -Category "FileProcessing" -SubCategory "cust_ProcessList"
    }
}




function create-ExcelReport
{
param
(
$ServerName, 
$DatabaseName,
$filepath, 
$logfile
)
    $pref = $progressPreference 
    $progressPreference = 'Continue' 
    
    Add-Type -AssemblyName Microsoft.Office.Interop.Excel

    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    try
    {
        $cn = new-object System.Data.SqlClient.SqlConnection "server=$ServerName;database=$DatabaseName;Integrated Security=sspi"

        $query= "EXECUTE GetProcs"

        $dataSet = new-object "System.Data.DataSet" 

        #Create a SQL Data Adapter to place the resultset into the DataSet
        $dataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($query, $cn) 

        $dataAdapter.Fill($dataSet) | Out-Null

        $dataTable = new-object "System.Data.DataTable"
        $dataTable = $dataSet.Tables[0]

        $proccount = $dataTable.Rows.Count

        #create a Dataset to store the DataTable  

        try
        {
            $excel = New-Object -ComObject Excel.Application
            $workbook = $excel.Workbooks.add()
        }
        catch
        {
            $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0]
            Write-Log -Message $errormsg -Path $logfile -Level Error
        }

        #foreach proc returned
        $i = 1
        $dataTable | ForEach-Object {
            [System.Windows.Forms.Clipboard]::Clear()
            try
            {
                $ProcSet = new-object "System.Data.DataSet" 
                $query = $_.ProcName.tostring()
                $procname = $query
                $newdataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($query, $cn) 
                $newdataAdapter.SelectCommand.CommandTimeout = 240
                Write-Log -Message "Executing $procname" -Path $logfile -Category "ReportingProcedureExecution" -SubCategory "BeginExec" -MetricValue $procname

                Write-Progress -Activity "Executing Data Analysis Stored Procedures: [$procname]" -Status "Percent completed: $([int](($i/$dataTable.Rows.Count)*100))%" -PercentComplete (($i/$dataTable.Rows.Count)*100)
                $i += 1
                $newdataAdapter.Fill($ProcSet) | Out-Null
                
                $dataTable2 = $null
                $dataTable2 = new-object "System.Data.DataTable"
                $dataTable2 = $ProcSet.Tables[0]
                Write-Log -Message "Executed $procname" -Path $logfile -Category "ReportingProcedureExecution" -SubCategory "EndExec" -MetricValue $procname -MetricValue2 $dataTable2.rows.count
            }
            catch
            {
                $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0]
                Write-Log -Message $errormsg -Path $logfile -Level Error -Category "ReportingProcedureExecution"
                $dataTable2 = $null  #make sure data doesn't get copied over to wrong tab on error
                $erroractionpreference = "continue"
            }

            if($dataTable2 -ne $null)
            {
                try
                {
                    $dataTable2 | convertto-csv -delimiter "`t" -notypeinformation | out-clipboard
                }
                catch
                {
                    start-sleep -s 1
                    $dataTable2 | convertto-csv -delimiter "`t" -notypeinformation | out-clipboard        
                }
    
                $sheetname = $procname.substring(15, $procname.length-15)    
                $worksheetA = $workbook.Worksheets.Add() 
                $worksheetA.name = $sheetname

                $range = $workbook.ActiveSheet.Range("a1","a$($dir.count + 1)")
    
                try
                {
                    $workbook.ActiveSheet.Paste($range, $false)
                    #make pretty
                    $ListObject = $excel.ActiveSheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $excel.ActiveCell.CurrentRegion, $null , [Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes)
                    $ListObject.Name = "TableData"
                    $ListObject.TableStyle = "TableStyleMedium2"      
                }
                catch
                {
                    start-sleep -s 3
                    $workbook.ActiveSheet.Paste($range, $false)   

                    #make pretty
                    $ListObject = $excel.ActiveSheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, `
                                    $excel.ActiveCell.CurrentRegion, $null ,[Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes)
                    $ListObject.Name = "TableData"
                    $ListObject.TableStyle = "TableStyleMedium2"                  
                }
            
                $range = $worksheetA.UsedRange
                $catchval = $range.EntireColumn.AutoFit()
            }
        }

        $cn.close();
        Write-Progress -Activity "Executing Data Analysis Stored Procedures: [$procname]" -Status "Percent completed: $([int](($i/$proccount)*100))%" -PercentComplete 100 -Completed

        foreach($x in $workbook.worksheets)
        {
            if ((($x.name -eq "Sheet1") -or ($x.name -eq "Sheet2") -or ($x.name -eq "Sheet3")-or ($x.name -eq "Sheet4")) -and $workbook.worksheets.Count -gt 1)
            {
                $excel.WorkSheets.Item($x.name).Delete()
            }
        }

        #"Workbook count: $excel.ActiveWorkbook.Count"
        $excel.ActiveWorkbook.SaveAs("$filepath")
        $excel.quit()
    }
    catch
    {
        $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0]
        Write-Log -Message $errormsg -Path $logfile -Level Error -Category "ReportingProcedureExecution"
        $erroractionpreference = "continue"
    }

    $progressPreference = $pref
}


function invoke-SQLSystemHealthAnalysis
{
param
(
$ServerName, 
$DatabaseName, 
$logfile
)
    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    try
    {

        $Connection = New-Object System.Data.SQLClient.SQLConnection
        $Connection.ConnectionString = "server='$ServerName';database='$DatabaseName';trusted_connection=true;"
        $Connection.Open()
        $Command = New-Object System.Data.SQLClient.SQLCommand
        $Command.Connection = $Connection

        Write-Log -Message "Processing System Health Session Data" -Path $logfile -Category "FileProcessing" -SubCategory "SystemHealthSessionReport" 
        $sql ="exec spLoadSystemHealthSession @UTDDateDiff=-6" 

        $Command.CommandText = $sql
        $Command.CommandTimeout = 0
        $z = $Command.ExecuteNonQuery()

        $Connection.Close()

    }
    catch
    {
        $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0]
        #$logfile
        Write-Log -Message $errormsg -Path $logfile -Level Error -Category "FileProcessing" -SubCategory "SystemHealthSessionReport" 
    }
}


function import-ExtendedEventFiles
{
param
(
$ServerName, 
$DatabaseName, 
$filepath, 
$logfile
)
    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    try
    {
        #only insert xel files with SQLDIAGXEL or SystemHealthXEL in the name.
        #everything else will be imported by ReadTrace
        if(test-path $filepath)
        {
            Write-Log -Message "Processing Extended Event File $filepath" -Path $logfile -Category "FileProcessing" -SubCategory "ExtendedEventImport"  -ProcessingFileName $FilePath 
            $Connection = New-Object System.Data.SQLClient.SQLConnection
            $Connection.ConnectionString = "server='$ServerName';database='$DatabaseName';trusted_connection=true;"
            $Connection.Open()
            $Command = New-Object System.Data.SQLClient.SQLCommand
            $Command.Connection = $Connection

            $OutputFile = Get-ChildItem $FilePath
            write-FileImportData -ServerName $SQLServer -DatabaseName $DatabaseName -FileName $OutputFile.Name -FileSizeKB $OutputFile.Length/1KB -LogFile $logfile

            $sql ="IF OBJECT_ID('cust_ExtendedEvents') IS NOT NULL
            DROP TABLE cust_ExtendedEvents

            CREATE TABLE cust_ExtendedEvents
            (
            IDCol INT IDENTITY(1,1),
            module_guid uniqueidentifier,
            package_guid uniqueidentifier,
            object_name nvarchar(2048),
            event_data nvarchar(max),
            file_name nvarchar(2000),
            file_offset bigint
            )" 

            $Command.CommandText = $sql
            $Command.CommandTimeout = 0
            Write-Log -Message "Creating table cust_ExtendedEvents" -Path $logfile -Category "FileProcessing" -SubCategory "ExtendedEventImport"
            $z = $Command.ExecuteNonQuery()

            #loop through the XE files that match what we want to import

            $XEFiles = get-childitem $filepath -Include "*SQLDIAGXEL*", "*SystemHealthXEL*"

            foreach($XEFile in $XEFiles)
            {
                Write-Log -Message "Importing Extended Event File $($XEFile.FullName)" -Path $logfile

                $sql ="INSERT INTO cust_ExtendedEvents (module_guid, package_guid, object_name, event_data, file_name, file_offset)
                SELECT module_guid, package_guid, object_name, event_data, file_name, file_offset 
                FROM sys.fn_xe_file_target_read_file('$($XEFile.FullName)', null, null, null)" 
                $Command.CommandText = $sql

                Write-Log -Message "Inserting XE Data into cust_ExtendedEvents" -Path $logfile -Category "FileProcessing" -SubCategory "ExtendedEventImport"  -ProcessingFileName $XEFile 

                $XEOutput = $Command.ExecuteNonQuery()               
            }


            $Connection.Close()
        }

    }
    catch
    {
        $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0]
        Write-Log -Message $errormsg -Path $logfile -Level Error -Category "FileProcessing" -SubCategory "ExtendedEventImport"  -ProcessingFileName $XEFile 
    }
}

function import-SQLAnalysisProcedures
{
    param
    (
        $ServerName, 
        $DatabaseName,
        $SQLFolderPath, 
        $logfile
    )
    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    try
    {
        if(test-path -Path $SQLFolderPath)
        {
            $files = Get-ChildItem $SQLFolderPath -Filter *.sql | Sort-Object name
            foreach($file in $files)
            {
                Write-Progress -Activity "Creating Data Analysis Stored Procedures: $($file.BaseName)" -Status "Percent completed: $([int](($i/$files.Length)*100))%" -PercentComplete (($i/$files.Length)*100)

                Write-Log -Message "Creating Data Analysis Stored Procedures" -Path $logfile -Category "FileProcessing" -SubCategory "StoredProcedureCreation"  -ProcessingFileName $file.Name
                Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -InputFile $file -QueryTimeout 32000 -ErrorAction SilentlyContinue
            }
            Write-Progress -Activity "Creating Data Analysis Stored Procedures: $($file.BaseName)" -Status "Percent completed: $([int](($i/$files.Length)*100))%" -PercentComplete 100 -Completed
        }
    }
    catch
    {
        $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0]
        Write-Log -Message $errormsg -Path $logfile -Level Error -Category "FileProcessing" -SubCategory "StoredProcedureCreation"  -ProcessingFileName $file.BaseName -MetricValue "Catch"
    }
    # finally
    # {
    #     if($Error)
    #     {
    #         Write-Log -Message $Error -Path $logfile -Category "FileProcessing" -SubCategory "StoredProcedureCreation"  -ProcessingFileName $file.BaseName -Level Error -MetricValue "Finally"
    #     }
    # }
}

function import-RDTSCFromPSSDiag
{
    param
    (
    $ServerName, 
    $DatabaseName, 
    $filepath, 
    $logfile
    )

    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    if(test-path $filepath)
    {
        try
        {
            $RTDSCFile = get-content $filepath
            $Connection = New-Object System.Data.SQLClient.SQLConnection
            $Connection.ConnectionString = "server='$ServerName';database='$DatabaseName';trusted_connection=true;"
            $Connection.Open()
            $Command = New-Object System.Data.SQLClient.SQLCommand
            $Command.Connection = $Connection

            $OutputFile = Get-ChildItem $FilePath
            write-FileImportData -ServerName $SQLServer -DatabaseName $DatabaseName -FileName $OutputFile.Name -FileSizeKB $OutputFile.Length/1KB

            $sql ="IF OBJECT_ID('cust_RTDSC') IS NOT NULL
            DROP TABLE cust_RTDSC
            CREATE TABLE cust_RTDSC(IDCol INT IDENTITY, Category VARCHAR(50), LineDesc VARCHAR(MAX))" 

            $Command.CommandText = $sql
            $z = $Command.ExecuteNonQuery()

            $pattern = [regex] "\A[=-][=-]([^\[]*)"  #looking for [==] or --
            $category = ""

            foreach($row in $RTDSCFile) 
            {
                $row = $row.Replace("'","''")
                $row = $row.trim()
                [bool] $heading = $false

                $match = $pattern.Match($row)
                if($match.Success -eq $true)
                {
                    $category = $row.Replace("-","")
                    $category = $category.Replace("=","")
                    $category = $category.trim()
                    $heading = $true
                }

                if($row -eq "")
                {
                    $category = ""
                }

                if(($heading -eq $false) -and ($category.Trim().Length -gt 0))
                {
                    $sql ="
                        insert cust_RTDSC (Category, LineDesc)
                        select '$category','$row'
                    " 
                    $Command.CommandText = $sql
                    $RTDSCOutput = $Command.ExecuteNonQuery()
                }
            }
            $Connection.Close()
        }
        catch
        {
            $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0]
            Write-Log -Message $errormsg -Path $logfile -Level Error -ProcessingFileName $filepath -Category "FileProcessing" -SubCategory "cust_RTDSC"
        }
    }
}

function import-MachineCheckFromPSSDiag
{
    param
    (
    $ServerName, 
    $DatabaseName, 
    $filepath, 
    $logfile
    )

    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    if(test-path $filepath)
    {
        try
        {
            $x = get-content $filepath
            $Connection = New-Object System.Data.SQLClient.SQLConnection
            $Connection.ConnectionString = "server='$ServerName';database='$DatabaseName';trusted_connection=true;"
            $Connection.Open()
            $Command = New-Object System.Data.SQLClient.SQLCommand
            $Command.Connection = $Connection

            $OutputFile = Get-ChildItem $FilePath
            write-FileImportData -ServerName $SQLServer -DatabaseName $DatabaseName -FileName $OutputFile.Name -FileSizeKB $OutputFile.Length/1KB

            $sql ="IF OBJECT_ID('cust_MachineCheck') IS NOT NULL
            DROP TABLE  cust_MachineCheck
            CREATE TABLE cust_MachineCheck(IDCol INT IDENTITY, InfoDesc XML, Category varchar(50))" 
            $Command.CommandText = $sql
            $MachineCheckOutput1 = $Command.ExecuteNonQuery()
        
            $sql ="INSERT cust_MachineCheck (InfoDesc, Category)
                SELECT '$x', '$category'" 

            $Command.CommandText = $sql
            $MachineCheckOutput2 = $Command.ExecuteNonQuery()

            $Connection.Close()
        }
        catch
        {
            $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0]
            Write-Log -Message $errormsg -Path $logfile -Level Error -ProcessingFileName $FilePath -Category "cust_MachineCheck"
        }
    }
}



function create-RelogFiles
{
param
(
$SourcePath, 
$OutputPath,
$logfile
)

    try
    {

        $Message = 'Inside function: ' + $MyInvocation.MyCommand 
        Write-Log -Message $Message -Path $logfile 

        $SourceBlgPath = join-path $SourcePath "*.blg"
        $OutputBlgPath = join-path $OutputPath "SQLPerformanceCounters.blg"

        if((Get-ChildItem $SourceBlgPath).count -gt 0)
        {
           [xml]$DataLogicConfig = Get-Content ".\Configuration\DataLogic.xml"
            $RelogCounterConfigFile = join-path $outputpath "PerformanceConfig.txt"

            #generate relog counter file
            New-Item $RelogCounterConfigFile -ItemType file -Force |Out-Null
        
            #just doing Performance Counters for now
            $PerfCountersToRelog = $DataLogicConfig.root.Relog.CounterList| `
            Where-Object {(($_.Enabled -eq $true) -and ($_.Category = "SQLPerformance"))}|Select-Object Counter
                            
            add-content $RelogCounterConfigFile $PerfCountersToRelog.Counter -Force

            $arglist = " """ + $SourceBlgPath + """ -cf """ + $RelogCounterConfigFile + """ -o """ + $OutputBlgPath + """ -y"
            write-log -Message "Inside GenerateRelogFiles  ArgumentList: $arglist" -Path $logfile
            Start-Process -FilePath "relog.exe" -ArgumentList $arglist 
        }
        else 
        {
            write-log -Message "No files to process for relog.exe" -Path $logfile -Category "FileProcessing" -SubCategory $SourcePath
        }
        #remove-item $RelogCounterConfigFile -Force -ErrorAction SilentlyContinue                    
            
    }
    catch
    {
        $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0]
        Write-Log -Message $errormsg -Path $logfile -Level Error -Path $logfile -Category "FileProcessing" -SubCategory $SourcePath
    }
}

function import-SQLPlans
{
param(
    $ServerName, 
    $DatabaseName, 
    $filepath
)

    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    if(test-path $filepath)
    {
        $plans = get-content $filepath

        $Connection = New-Object System.Data.SQLClient.SQLConnection
        $Connection.ConnectionString = "server='$ServerName';database='$DatabaseName';trusted_connection=true;"
        $Connection.Open()
        $Command = New-Object System.Data.SQLClient.SQLCommand
        $Command.Connection = $Connection


        $sql ="IF OBJECT_ID('cust_CapturedPlans') IS NOT NULL
        DROP TABLE  cust_CapturedPlans
        CREATE TABLE cust_CapturedPlans(IDCol INT IDENTITY, QueryPlan XML, FileName varchar(1000))" 
        $Command.CommandText = $sql
        $CapturedPlanCreate = $Command.ExecuteNonQuery()

        $Message = 'Inside function: ' + $MyInvocation.MyCommand 
        Write-Log -Message $Message -Path $logfile 

        foreach($QueryPlan in $plans) 
        {
            try 
            {

                $FileName = $QueryPlan.PSChildName
                $PlanXML = $QueryPlan.Replace("'","''").ToString()
                $FileSize = $OutputFile.Length/1KB

                $Message = "Importing query plan: $FileName"
                Write-Log -Message $Message -Path $logfile 

                $OutputFile = Get-ChildItem $QueryPlan.FullName
                Write-Log -Message "Writing SQL Plan to database." -Path $logfile -ProcessingFileName $FileName -MetricValue $FileSize -Level "Info"
                write-FileImportData -ServerName $SQLServer -DatabaseName $DatabaseName -FileName $FileName -FileSizeKB $FileSize -LogFile $logfile
            
                $sql ="
                    INSERT INTO cust_CapturedPlans (QueryPlan,FileName)
                    SELECT  '$PlanXML','$FileName'
                    "
                $Command.CommandText = $sql
                $CapturedPlans = $Command.ExecuteNonQuery()            
            }
            catch 
            {
                $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0] + ' FileName: ' + $FileName 
                Write-Log -Message $errormsg -Path $logfile -Level "Error" -Category "ImportSQLPlans" -ProcessingFileName $FileName -MetricValue $MyInvocation.MyCommand
            }

        }
        $Connection.Close()

    }
}


Function import-DBCCMemoryStatus
{
    Param
    (
        [String] $ServerName, 
        [String] $DatabaseName,
        [String] $filepath 
    )

        $Message = 'Inside function: ' + $MyInvocation.MyCommand 
        Write-Log -Message $Message -Path $logfile 

    if(test-path $filepath)
    {
        #otherwise get dbcc memorystatus from file
        $DBCCMemoryStatus = get-content $filepath

        $OutputFile = Get-ChildItem $filepath
        write-FileImportData -ServerName $SQLServer -DatabaseName $DatabaseName -FileName $OutputFile.Name -FileSizeKB $OutputFile.Length/1KB -LogFile $logfile
    
        $DBConnection = new-object system.data.SqlClient.SQLConnection("Data Source=$ServerName;
        Integrated Security=SSPI;Initial Catalog=$DatabaseName");
        $DBConnection.open()
        $Command = new-object system.data.sqlclient.sqlcommand;
        $Command.Connection = $DBConnection
        $Command.CommandText = "IF OBJECT_ID('cust_DBCCMemoryStatus') IS NOT NULL DROP TABLE cust_DBCCMemoryStatus"
        $Command.ExecuteNonQuery() | out-null
        $Command.CommandText = "CREATE TABLE cust_DBCCMemoryStatus(IDCol INT IDENTITY(1,1), MemObjType VARCHAR(1200), 
        MemObjName VARCHAR(1200), MemObjValue BIGINT, ValueType VARCHAR(20), CaptureTime DATETIME)"
        $Command.ExecuteNonQuery() | out-null

        $RowsInserted = 0
        for ($i = 0; $i -lt $DBCCMemoryStatus.length; $i++)
        {

            if ([regex]::ismatch($DBCCMemoryStatus[$i+1],"-----------------------"))
            {
                [int] $pivot = $DBCCMemoryStatus[$i+1].IndexOf(" ")
            }

            if([regex]::ismatch($DBCCMemoryStatus[$i],"Start time:"))
            {
                $CapureTime = $DBCCMemoryStatus[$i].Replace("Start time:","").Replace("T"," ")
            }

            if (     
                    ($DBCCMemoryStatus[$i].trim() -ne "") -and 
                    (![regex]::ismatch($DBCCMemoryStatus[$i],"-----------------------")) -and 
                    (![regex]::ismatch($DBCCMemoryStatus[$i],"affected")) -and
                    (![regex]::ismatch($DBCCMemoryStatus[$i],"Start time:")) -and
                    (![regex]::ismatch($DBCCMemoryStatus[$i],"MEM_SNAPSHOT_INTERVAL")) -and
                    (![regex]::ismatch($DBCCMemoryStatus[$i],"Sample interval:")) -and
                    (![regex]::ismatch($DBCCMemoryStatus[$i],"DBCC"))
                    
                )
            {
                if ([regex]::ismatch($DBCCMemoryStatus[$i+1],"-----------------------"))
                {
                    $valtype = $DBCCMemoryStatus[$i].substring($pivot + 1, ($DBCCMemoryStatus[$i].Length - $pivot -1))
                    $memtype = ($DBCCMemoryStatus[$i]).replace($valtype,"")

                }
        
                if (![regex]::ismatch($DBCCMemoryStatus[$i+1],"-----------------------"))
                {
                    $MemObjType = $memtype
                    $MemObjName = $DBCCMemoryStatus[$i].substring(0, $pivot)
                    try{
                    [int64]$MemObjValue = $DBCCMemoryStatus[$i].substring($pivot + 1, 
                        ($DBCCMemoryStatus[$i].Length - $pivot -1))        
                    }
                    catch
                    {
                        [int64]$MemObjValue = $null
                    }
                    $Command.CommandText = "INSERT INTO cust_DBCCMemoryStatus (MemObjType, MemObjName, MemObjValue, ValueType, CaptureTime) 
                    VALUES ('$MemObjType','$MemObjName', '$MemObjValue', '$valtype', '$CapureTime')"
                    
                    $Rows = $Command.ExecuteNonQuery() | out-null
                    $RowsInserted += $Rows
                }
            }
        }
          $DBConnection.Close();      
    }    

    return($RowsInserted)
}

function import-SQLNexusData
{
param
(
    $SQLNexusPath, 
    $ServerName, 
    $DatabaseName, 
    $ImportFolder, 
    $LogFile, 
    $ExportPath
)
    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 
    $NexusStandardOutput = join-path $ExportPath "SQLNexusOutput.txt"

    try
    {
        $arglist = "/S" +$ServerName + " /D""" + $DatabaseName + """ /E" + " /I""" + $ImportFolder + """" + " /X"
        write-log -Message "Inside SQLNexusDataImport  ArgumentList: $arglist" -Path $logfile
        Start-Process -FilePath $SQLNexusPath -ArgumentList $arglist -NoNewWindow -Wait -RedirectStandardOutput $NexusStandardOutput 
        
    }
    catch
    {
        $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0]
        Write-Log -Message $errormsg -Path $logfile -Level Error
    }
}



function import-VulnerabilityAssessment
{
param(
    $ServerName, 
    $DatabaseName, 
    $filepath, 
    $logfile
)

    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    if(test-path $filepath)
    {

        $Message = 'Inside function: ' + $MyInvocation.MyCommand 
        Write-Log -Message $Message -Path $logfile 

        $VAFiles = get-childitem $filepath
        #$VAFiles = get-childitem "C:\pssdiagtest\SQL2014WithoutTrace\output\*.VAOUT"
        $ResultArray = @()
        $TableName = "cust_VAResults"

        Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Query "IF OBJECT_ID('$TableName') IS NOT NULL DROP TABLE $TableName"

        foreach($VAFile in $VAFiles) 
        {
            $Message = "Processing Vulnerability Assessment from file: $($VAFile.Name)"
            Write-Log -Message $Message -Path $logfile 

            $ResultDictionary = @{}
            $VAObject = Import-Clixml $VAFile
    
            $Results = $VAObject.Results
            $SecurityChecks = $VAObject.SecurityChecks
    
            foreach($Key in $SecurityChecks.GetEnumerator())
            {
                $Rule = $Key.Name
                $Result = $Results[$Rule]
                $Check = $SecurityChecks[$Rule]
    
                $ResultDictionary.ServerName = [string]$VAObject.Server
                $ResultDictionary.Platform = [string]$VAObject.Platform
                $ResultDictionary.DatabaseName = [string]$VAObject.Database
                $ResultDictionary.SqlVersion = [string]$VAObject.SqlVersion
                $ResultDictionary.StartTimeUtc = [string]$VAObject.StartTimeUtc
                $ResultDictionary.EndTimeUtc = [string]$VAObject.EndTimeUtc
    
                $ResultDictionary.SecurityCheckID = [string]$Result.SecurityCheckID
                $ResultDictionary.Status = [string]$Result.Status
                $ResultDictionary.QueryResults = [string]$Result.QueryResults
                $ResultDictionary.ErrorMessage = [string]$Result.ErrorMessage
    
                $ResultDictionary.Severity = [string]$Check.Severity
                $ResultDictionary.Category = [string]$Check.Category
                $ResultDictionary.SecurityCheckType = [string]$Check.SecurityCheckType
                $ResultDictionary.Title = [string]$Check.Title
                $ResultDictionary.Description = [string]$Check.Description
                $ResultDictionary.Rationale = [string]$Check.Rationale
                $DataSampleObject = new-object -TypeName PSObject -Property $ResultDictionary
    
                $ResultArray += $DataSampleObject
            }
    
        }
    
        $ProgPref = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        $RowsInserted = Write-SqlTableData -ServerInstance $ServerName -Database $DatabaseName -TableName $TableName -InputData $ResultArray -SchemaName "dbo" -Force
        $ProgressPreference = $ProgPref
    }
}

function import-SensitivityRecommendations
{
param(
    $ServerName, 
    $DatabaseName, 
    $filepath, 
    $logfile
)

    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    if(test-path $filepath)
    {

        $Message = 'Inside function: ' + $MyInvocation.MyCommand 
        Write-Log -Message $Message -Path $logfile 
        
        $SRFiles = get-childitem $filepath
        $ResultArray = @()
        $TableName = "cust_SensitivityRecommendations"

        Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Query "IF OBJECT_ID('$TableName') IS NOT NULL DROP TABLE $TableName"

        $SRFile = $SRFiles
        foreach($SRFile in $SRFiles) 
        {
            $Message = "Processing Sensitivity Recommendations from file: $($SRFile.Name)"
            Write-Log -Message $Message -Path $logfile 

            $SRObject = Import-Clixml $SRFile
            $SensitivityData = $SRObject.Data
    
            foreach($Row in $SensitivityData)
            {
                $ResultObj = [PSCustomObject] @{
                    ServerName = [string]$SRObject.ServerName
                    DatabaseName = [string]$SRObject.DatabaseName
    
                    Column = [string]$Row.Column
                    InformationType = [string]$Row.InformationType
                    SensitivityLabel = [string]$Row.SensitivityLabel
                } 
                $ResultArray += $ResultObj
            }
    
        }
    
        $ProgPref = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        Write-SqlTableData -ServerInstance $ServerName -Database $DatabaseName -TableName $TableName -InputData $ResultArray -SchemaName "dbo" -Force
        $ProgressPreference = $ProgPref
    }
}


