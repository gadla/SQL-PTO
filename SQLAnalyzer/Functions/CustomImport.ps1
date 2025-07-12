#Author: Tim Chapman, Microsoft

#Set-Location C:\Users\Administrator\Documents\WindowsPowerShell\Modules\SQLAnalyzer
. .\Functions\Logger.ps1
. .\Functions\UtilityFunctions.ps1
##. C:\SQLAnalyzer\Functions\Logger.ps1

##$progressPreference = 'SilentlyContinue' 



function initialize-database
{
    param
    (
        $ServerName,
        $DatabaseName, 
        [bool]$DropIfExists = 0, 
        $LogFile
    )
	Write-Log -Message "Initializing database $DatabaseName" -Path $LogFile -WriteToHost 
    if($DropIfExists)
    {
        $Query = "
        IF DB_ID('$DatabaseName') IS NOT NULL
        BEGIN
        ALTER DATABASE [$DatabaseName]
        SET SINGLE_USER WITH ROLLBACK IMMEDIATE

        DROP DATABASE [$DatabaseName]
        END"
        Write-Log -Message "Dropping database [$DatabaseName] if it exists." -Path $LogFile -WriteToHost  
        Invoke-Sqlcmd -ServerInstance $ServerName -Database "master" -Query $Query       
    }

    $Query = "CREATE DATABASE [$DatabaseName]"
    Write-Log -Message "Creating database [$DatabaseName]" -Path $LogFile -WriteToHost  
    Invoke-Sqlcmd -ServerInstance $ServerName -Database "master" -Query $Query

    #if MultipleInstances.txt file exists, then read the blg data somewhere else.   
}


function get-ColumnObject 
{
    #take a delimited list and the list of column headers and return a object with columns
    param
    (
        $DelimitList, 
        $ColumnHeaderList
    )

    if ($DelimitList.Length -gt $ColumnHeaderList.length) 
    {
        $ColumnHeaderList = $ColumnHeaderList.PadRight($DelimitList.Length, " ")
    }
    $FieldList = $DelimitList.Split(" ")
    $ColumnArray = @()

    $ColumnCounter = 1
    $PositionCounter = 1

    foreach ($Field in $FieldList) 
    {
        $ColumnArray += @{ColIndex = $ColCounter; ColLength = $Field.length; StartPosition = $PositionCounter}
        $PositionCounter += ($Field.Length + 1)
        $ColumnCounter += 1
    }

    foreach ($ColumnSpec in $ColumnArray) 
    {
        $ColumnSpec.Add("ColName", ($ColumnHeaderList.Substring($ColumnSpec.StartPosition - 1, $ColumnSpec.ColLength)).trim())
    }

    return([array]$ColumnArray)
}


function get-createtablestatement
{
    param
    (
        $ColumnObject, 
        $TableName
    )

    $SQL = "IF OBJECT_ID('$TableName') IS NULL BEGIN CREATE TABLE [$TableName] ( "
    foreach ($col in $ColumnObject)
    {
        $ColName = $col.ColName
        $ColName = $ColName.Replace(" ", "_")
        $ColLength = $col.ColLength
        $SQL += " [$ColName] VARCHAR($ColLength),"
    }
    $SQL = $SQL.Substring(0, $SQL.Length - 1) + ") END"
    return($SQL)
}  


function Find-RowsetTagNexus
{
    param
    (
        $SearchString, 
        $SearchTagsObj
    )
    #eventually convert the xml to a hash table so it is easier to search and store.

    $NameObj = $SearchTagsObj | Where-Object Identifier -eq $SearchString |select-object -First 1 Name
    return($NameObj.Name)
}



function import-pssdiagfile 
{
    param(
        $FilePath, 
        $SQLServer, 
        $DatabaseName,
        $SearchTagsObj, 
        $BatchSize = 25000, 
        $LogFile
    )

    [bool] $TagFound = $false
    [int] $LineNumber = 0
    [int] $LineLimitWithoutTags = 10000

    $FileName = (get-item $FilePath).Name

    $Connection = New-Object System.Data.SQLClient.SQLConnection
    $Connection.ConnectionString = "server=$SQLServer;database=$DatabaseName;trusted_connection=true;"
    $Connection.Open()
    $Command = New-object System.Data.SQLClient.SQLCommand 
    $Command.Connection = $Connection
    $bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($Connection.ConnectionString, [System.Data.SqlClient.SqlBulkCopyOptions]::TableLock) 
    $bulkcopy.bulkcopyTimeout = 0 
    $bulkcopy.batchsize = $BatchSize 

    $CurrentLineNull = $false
    $TagFoundInFile = $false
    $ColumnHash = @{}
    $TableHash = @{}

    foreach ($line in [System.IO.File]::ReadLines($FilePath)) 
    {
        $LineNumber += 1
        $PreviousLineEmpty = $CurrentLineNull 
        $RowsInserted = 0

        #if the line is empty or if the line starts and ends with parentheses then
        #mark it as a blank line
        #also ignore line if it is a query warning
        
        if ($Line.trim().length -eq 0 -or ($Line -match "^\(.*\)$") -or ($Line.StartsWith("Warning:")))
        {
            $CurrentLineNull = $true
            $TagFound = $false
        }
        else
        {
            $CurrentLineNull = $false
        }
        
        #short circuit
        #if 10k lines have been looked at and no tag found yet, then break out
        if($LineNumber -ge $LineLimitWithoutTags -and $TagFoundInFile -eq $false)
        {
            Write-Log -Message "No tag found in $FileName after $LineLimitWithoutTags lines read." -Path $logfile  -Category "FileProcessing" -SubCategory "CustomDataImport" -ProcessingFileName $FileName 
            break
        }

        if (($PreviousLineEmpty -eq $true -and $CurrentLineNull -eq $false) -or ($LineNumber -eq 1) -or $TagFoundInFile -eq $false)
        {
            #this line is potentially a tag, so go check for it.
            if ($SearchTagsObj.Identifier -contains $line)
            {
                $TagFound = $true
                $TagFoundInFile = $true  #once true, never set this back to false for the current file
                $TagValue = $line
                $TableName = Find-RowsetTagNexus -SearchString $line -SearchTagsObj $SearchTagsObj
                $TagStart = $LineNumber
                $ColumnStart = $TagStart + 1
                $Delimiter = $ColumnStart + 1
    
            }
            else
            {
                $TagFound = $false
                $TagValue = $null
                continue
            }
            #if the tag isn't found, skip through any following lines until a blank line is found
            #if the tag is found, start processing rows afterwards until a blank line is found
        }

        if ($TagFound)
        {
            #make sure we skip to the next line if we just found the tag
            if ($LineNumber -ge $ColumnStart)
            {

                #this line contains the column names
                if ($LineNumber -eq $ColumnStart)
                {
                    $ColumnNames = $line
                }
                #this line contains the delimiter
                elseif ($LineNumber -eq $Delimiter)
                {
                    $DelimitList = $line

                    #check to see if the tag has already been found.  If so, pull the column object.
                    #if not, save the columnobject

                    if ($ColumnHash.Count -gt 0 -and $ColumnHash.ContainsKey($TagValue))
                    {
                        $ColumnObject = $ColumnHash.$TagValue
                    }
                    else
                    {
                        $ColumnObject = get-ColumnObject -delimitlist $DelimitList -ColumnHeaderList $ColumnNames
                        $ColumnHash.$TagValue = $ColumnObject
                    }        
                    $ColumnNameArray = [array]$ColumnObject.ColName

                    $DataTableForInsert = New-Object System.Data.DataTable 

                    #only want to do this if we haven't touched this table before
                    if ( !($TableHash.ContainsKey($TagValue))) 
                    {
                        $SQL = get-createtablestatement -ColumnObject $ColumnObject -TableName $TableName
                        $TableHash.$TagValue = $TableName
                        try
                        {
                            #Invoke-Sqlcmd -ServerInstance $SQLServer -Database $DatabaseName -Query $SQL -ErrorAction SilentlyContinue |Out-Null
                            $Command.CommandText = $SQL
                            $Command.ExecuteNonQuery() |Out-Null

                        }
                        catch
                        {
                            
                            Write-Log -Message "Error in $($file.name) $error[0] SQLStatement: $SQL" -Path $logfile -Level Error  -Category "FileProcessing" -SubCategory "CustomDataImport" -ProcessingFileName $FileName 
                        }
                        
                    }

                    #Loop through the columns and add to the DataTable
                    foreach ($Column in $ColumnNameArray)
                    {  
                        $null = $DataTableForInsert.Columns.Add($Column) 
                    } 

                }
                else
                {
                    #Start building table data, but only if the tag was found in the lookup
                    #We need to process the data rows

                    #This is the data row(s)
                    #Add this row to the Data Table
                    $NewDataRow = $DataTableForInsert.NewRow()
                    $ColCounter = 1
                    #$TotalCols = $ColumnObject.Count
                    $TotalCols = $ColumnNameArray.Count

                    foreach ($val in $ColumnObject)
                    {
                        #have to do this in case the rowset is poorly formed and the 
                        #header columns don't match up to data lengths
                        if ($ColCounter -eq $TotalCols)
                        {
                            $endposition = $line.Length + 1 - $val.StartPosition
                        }
                        else
                        {
                            $endposition = $val.ColLength
                        }
                        try
                        {
                            $NewDataRow[$val.colname] = ($line.Substring($val.StartPosition - 1, $endposition)).trim()

                        }
                        catch
                        {
                            #write this out to a file eventually
                            #Remove entries for the tag (in case rowsets in file do not match)

                            #if the current line is a tag that has already been found, ignore
                            if(!($TableHash.ContainsKey($line)))
                            {
                                Write-Log -Message "Import Error on line: $LineNumber in file $file" -Path $logfile -Level "Error" -Category "FileProcessing" -SubCategory "CustomDataImport" -ProcessingFileName $FileName 
                                $TableHash.Remove($TagValue)
                                $ColumnHash.Remove($TagValue)
                                $TagFound = $false
                            }

                            if ($DataTableForInsert.Rows.Count -gt 0)
                            {
                                try
                                {
                                    $bulkcopy.DestinationTableName = $TableName
                                    $bulkcopy.WriteToServer($DataTableForInsert)  
                                    #Write-SqlTableData -ServerInstance $SQLServer -DatabaseName $DatabaseName -SchemaName "dbo" -TableName $TableName -InputData $DataTableForInsert -force
                                    #[System.GC]::Collect()
                                }
                                catch
                                {
                                    $error[0]
                                }
                                $RowsInserted += $DataTableForInsert.Rows.Count
                                Write-Log -Message "Writing $RowsInserted row(s) to Table: $TableName" -Path $logfile -Category "FileProcessing" -SubCategory "TableInsert" -ProcessingFileName $FileName -MetricValue $Tablename -MetricValue2 $RowsInserted
                                $DataTableForInsert.Reset()
                            }
                            if ($SearchTagsObj.Identifier -contains $line)
                            {
                                $TagFound = $true
                                $TagFoundInFile = $true
                                $TagValue = $line
                                $TableName = Find-RowsetTagNexus -SearchString $line -SearchTagsObj $SearchTagsObj
                                $TagStart = $LineNumber
                                $ColumnStart = $TagStart + 1
                                $Delimiter = $ColumnStart + 1
                    
                            }
                            else 
                            {
                                $ColumnObject = get-ColumnObject -delimitlist $DelimitList -ColumnHeaderList $ColumnNames
                            }                            
                            break
                        }
                        $ColCounter ++
                    }

                    $DataTableForInsert.rows.Add($NewDataRow)

                    if (($LineNumber % $BatchSize) -eq 0)
                    {  
                        try
                        {
                            #Write-SqlTableData -ServerInstance $SQLServer -DatabaseName $DatabaseName -SchemaName "dbo" -TableName $TableName -InputData $DataTableForInsert -force
                            #[System.GC]::Collect()
                            $bulkcopy.DestinationTableName = $TableName
                            $bulkcopy.WriteToServer($DataTableForInsert) 

                            $RowsInserted += $DataTableForInsert.Rows.Count
                            Write-Log -Message "Writing $RowsInserted row(s) to Table: $TableName" -Path $logfile -Category "FileProcessing" -SubCategory "TableInsert" -ProcessingFileName $FileName  -MetricValue $Tablename -MetricValue2 $RowsInserted
                            $DataTableForInsert.Clear()  
                        }
                        catch
                        {
                            Write-Log -Message "Erorr writing to $TableName.  Error is $Error[0]" -Path $logfile -Category "FileProcessing" -SubCategory "TableInsert" -ProcessingFileName $FileName  -MetricValue $Tablename -MetricValue2 $RowsInserted -Level "Error"
                        }
                    }  

                }
            }
        }

        #if recently switched tags (resultsets), flush the current data table to db
        if (!$TagFound -and ($DataTableForInsert.Rows.Count -gt 0))
        {
            try
            {
                $bulkcopy.DestinationTableName = $TableName
                $bulkcopy.WriteToServer($DataTableForInsert) 
                #Write-SqlTableData -ServerInstance $SQLServer -DatabaseName $DatabaseName -SchemaName "dbo" -TableName $TableName -InputData $DataTableForInsert -force -ErrorAction Stop
                #[System.GC]::Collect()
                $RowsInserted += $DataTableForInsert.Rows.Count
                Write-Log -Message "Writing $RowsInserted row(s) to Table: $TableName" -Path $logfile -Category "FileProcessing" -SubCategory "TableInsert" -ProcessingFileName $FileName  -MetricValue $Tablename -MetricValue2 $RowsInserted
            }
            

            catch
            {
                Write-Log -Message "Error writing to table $TableName Error:  $error[0]" -Path $logfile -Level "Error" -Category "FileProcessing" -SubCategory "CustomDataImport" -ProcessingFileName $FileName 
            }
            finally
            {
                $DataTableForInsert.Clear() 
                
            }
        }
        


    }

    #if EOF
    if ($DataTableForInsert.Rows.Count -gt 0)
    {
        try
        {
            #Write-SqlTableData -ServerInstance $SQLServer -DatabaseName $DatabaseName -SchemaName "dbo" -TableName $TableName -InputData $DataTableForInsert -force -ErrorAction Stop
            #[System.GC]::Collect()
            $bulkcopy.DestinationTableName = $TableName
            $bulkcopy.WriteToServer($DataTableForInsert) 
            $RowsInserted += $DataTableForInsert.Rows.Count
            Write-Log -Message "Writing $RowsInserted row(s) to Table: $TableName" -Path $logfile -Category "FileProcessing" -SubCategory "TableInsert" -ProcessingFileName $FileName -MetricValue2 $RowsInserted -MetricValue $TableName
         
        }
        catch
        {
            Write-Log -Message "Error writing to table $TableName Error:  $error[0]" -Path $logfile -Level "Error" -Category "FileProcessing" -SubCategory "CustomDataImport" -ProcessingFileName $FileName  -MetricValue $TableName
            
        }
        finally
        {
            $DataTableForInsert.Clear() 
        }
    }

    return($LineNumber) 
}



function import-blgfiles
{
    param(
        $SQLServer, 
        $DatabaseName,
        $FilePath, 
        $LogFile
    )
    if (Test-Path $FilePath)
    {
        
        $BGLFiles = get-childitem $FilePath       
    }
    
    $Message = 'Inside function: ' + $MyInvocation.MyCommand + ' File Path: ' + $FilePath
    Write-Log -Message $Message -Path $LogFile

    $ODBCName = "SQLAnalyzer"

    #Create an array with the properties we need to create the DSN
    $ODBCProperties = @("Server = $SQLServer", "Database = $DatabaseName", "Trusted_Connection=Yes")

    try
    {
        if (Get-OdbcDsn -Name $ODBCName -ErrorAction Ignore)
        {

                Write-Log -Message "Removing ODBC DSN" -Path $LogFile  -Category "SystemModification" -SubCategory "ODBCDSN"
                Remove-OdbcDsn -Name $ODBCName -DsnType "User" -platform 64-bit -DriverName "SQL Server"
        }       
    }
    catch
    {
        $Message = 'Error removing ODBC connection ' + $ODBCName
        Write-Log -Message $Message -Path $LogFile -Level "Error" -Category "SystemModification" -SubCategory "ODBCDSN"
        $Variables = Get-Variable -Scope Local 
        write-UserVariablesToLog -Variables $Variables -LogFile $logfile -Category "UserVariables" 
    }

    try 
    {
        if (!(Get-OdbcDsn -Name $ODBCName -ErrorAction Ignore))
        {
            Write-Log -Message "Adding ODBC DSN" -Path $LogFile -Category "SystemModification" -SubCategory "ODBCDSN"
            Add-OdbcDsn -Name $ODBCName -DsnType "User" -platform 64-bit -DriverName "SQL Server" -SetPropertyValue $ODBCProperties
        }       
    }
    catch 
    {
        $Message = 'Error creating ODBC connection ' + $ODBCName
        Write-Log -Message $Message -Path $LogFile -Level "Error " -Category "SystemModification" -SubCategory "ODBCDSN"
        $Variables = Get-Variable -Scope Local 
        write-UserVariablesToLog -Variables $Variables -LogFile $logfile -Category "UserVariables" 
    }


    foreach ($file in $BGLFiles)
    {
        $params = @()
        $params += """$file""" 
        $params += "-o SQL:$ODBCName!$DatabaseName"
        $params += "-f SQL"
        $params += "-t 2"

        try 
        {
            $Message = "Beginning relog of file: $file"
            Write-Log -Message $Message -Path $LogFile  -Category "FileProcessing" -SubCategory "Perfmon" -ProcessingFileName $file
            Start-Process -FilePath "relog.exe" -ArgumentList $params  -Wait            
        }
        catch 
        {
            $RelogParams = $params -join ' '
            $Message = 'Error calling relog to upload perfmon data ' + $RelogParams
            Write-Log -Message $Message -Path $LogFile -Level "Error" -Category "FileProcessing" -SubCategory "Perfmon"  -ProcessingFileName $file      
            $Variables = Get-Variable -Scope Local 
            write-UserVariablesToLog -Variables $Variables -LogFile $logfile -Category "UserVariables"      
        }


    }

}


function import-tracefiles
{
    param(
        $SQLServer, 
        $DatabaseName,
        $FilePath, 
        $LogFile
    )
    
    $Message = 'Inside function: ' + $MyInvocation.MyCommand + ' File Path: ' + $FilePath
    Write-Log -Message $Message -Path $LogFile

    $OuputPath = Split-Path $LogFile

    if (Test-Path $FilePath)
    {
        #must have .xel or .trc appended to the path for this to work properly
        #just need to grab the first one.  
        #assumes these files will be named in order of creation
        $TraceXELFile = (get-childitem $FilePath |Sort-Object Name |Select-Object -First 1).FullName    
    }
 
        $params = @()
        $params += "-I""$TraceXELFile""" 
        $params += "-S""$SQLServer"""
        $params += "-E"
        $params += "-d""$DatabaseName"""
        $params += "-o""$OuputPath"""

        #standard RML path.  If it doesn't exist, go look up where the RML utils are being stored.
        $FilePath = "C:\Program Files\Microsoft Corporation\RMLUtils\readtrace.exe"

        if(-not(test-path $Filepath))
        {
            $PathEnvVariable = Get-ChildItem Env:Path
            $PathArray = $PathEnvVariable.Value.Split(";")
            $RMLPath = $PathArray -like "*RML*"

            if($RMLPath)
            {
                $Filepath = Join-Path $RMLPath "readtrace.exe"
            }
        }

        if(Test-Path $FilePath)
        {
            $Message = "Processing Trace File: $FilePath"
            Write-Log -Message $Message -Path $LogFile -Category "FileProcessing" -SubCategory "TraceXEL"  -ProcessingFileName $FilePath   
            Start-Process -FilePath $FilePath -ArgumentList $params
        }
        else 
        {
            $Message = "Unable to locate readtrace.exe.  Filepath is $($Filepath)"
            Write-Log -Message $Message -Path $LogFile -Level "Error" -Category "FileProcessing" -SubCategory "TraceXEL"  -ProcessingFileName $FilePath  
        }
        

}

function import-pssdiagfolder
{
    param(
        $SQLServer, 
        $DatabaseName,
        $FilePath, 
        $LogFile, 
        $TextRowsetLocation, 
        $IsPSCore = $False, 
        $FileImportSizeRules 
    )

    $Message = 'Inside function: ' + $MyInvocation.MyCommand 
    Write-Log -Message $Message -Path $logfile 

    if (test-path $FilePath)
    {

		#need to pass this in at some point.
		#$TextRowsetLocation = "C:\SqlNexus\Internal\TextRowsets.xml"
		[xml] $TRXMLRaw = get-content -Path $TextRowsetLocation
		$SearchTagsObj = $TRXMLRaw.TextImport.KnownRowsets.Rowset | Where-Object Enabled -eq "True"

        $OutputFiles = Get-ChildItem $FilePath\* -Include *.txt, *.out
        $TraceFiles = Get-ChildItem $FilePath\* -Include *.trc, *.xel

		Write-Log -Message "Importing PSSDiag files..." -Path $logfile -WriteToHost 

        create-SQLFilesTable -SQLServer $SQLServer -DatabaseName $DatabaseName

        $i = 1
        foreach ($OutputFile in $OutputFiles)
        {
            Write-Progress -Activity "Importing PSSDiag files into [$DatabaseName] database: $($OutputFile.Name)" -Status "Percent completed: $([int](($i/$OutputFiles.Count)*100))%" -PercentComplete (($i/$OutputFiles.Count)*100)
            $FileSizeMB = $OutputFile.Length/1MB
            write-FileImportData -ServerName $SQLServer -DatabaseName $DatabaseName -FileName $OutputFile.Name -FileSizeKB $OutputFile.Length/1KB
            Write-Log -Message "Processing file: $($OutputFile.Name)" -Path $logfile -Category "FileProcessing" -SubCategory "CustomDataImport" -ProcessingFileName $OutputFile.Name -MetricValue $OutputFile.Length

            #dont import files that are larger than the file import threshold
            if(($FileImportSizeRules.SkipLargeImportFiles -eq 1) -and ($FileSizeMB -gt [int]$FileImportSizeRules.SkipLargeImportFileSizeCutoffMB))
            {
                Write-Log -Message "Skipping file: $($OutputFile.Name) as its size in MB $($FileSizeMB) is greater than the file size import threshold in MB: $($FileImportSizeRules.SkipLargeImportFileSizeCutoffMB)." -Path $logfile
            }
            else 
            {
                $FileRows = import-pssdiagfile -FilePath $OutputFile -SQLServer $SQLServer  -DatabaseName $DatabaseName -SearchTagsObj $SearchTagsObj -logfile $LogFile 
                $i++                
            }

        }
        Write-Progress -Activity "Importing PSSDiag files into [$DatabaseName] database: $($OutputFile.Name)" -Status "Percent completed: $([int](($i/$OutputFiles.Count)*100))%" -PercentComplete 100 -Completed

        if($IsPSCore -eq $False)
        {
            import-blgfiles -SQLServer $SQLServer -DatabaseName $DatabaseName -FilePath $FilePath\*.blg -LogFile $LogFile
            import-tracefiles -SQLServer $SQLServer -DatabaseName $DatabaseName -FilePath $FilePath\*.xel -LogFile $LogFile
            import-tracefiles -SQLServer $SQLServer -DatabaseName $DatabaseName -FilePath $FilePath\*.trc -LogFile $LogFile
        }
        else
        {
            Write-Log -Message "PSCore is being used so cannot import blg or trace files." -Path $logfile
        }
    }
}



<#
$TextRowsetLocation = "C:\Users\Administrator\Documents\WindowsPowerShell\Modules\SQLAnalyzer\Configuration\TextRowsets.xml"
[xml] $TRXMLRaw = get-content -Path $TextRowsetLocation
$SearchTagsObj = $TRXMLRaw.TextImport.KnownRowsets.Rowset | Where-Object Enabled -eq "True"
import-pssdiagfile -FilePath "C:\Customer\Missing\AGC3-BISQL01_MSSQLSERVER_MissingIndexes.sql.out" -SQLServer "Analysis"  -DatabaseName "Missing" -SearchTagsObj $SearchTagsObj -logfile "C:\PSSDiagExporter\Missing\Missing.log" 
#>