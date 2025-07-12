function get-sqltype
{
param
(
$ServerName , 
$DatabaseName
)
    $cn = new-object System.Data.SqlClient.SqlConnection "server=$ServerName;database=$DatabaseName;Integrated Security=sspi"
    $cn.Open()
    $sqlCommand = New-Object System.Data.SQLClient.SQLCommand
    $sqlCommand.Connection = $cn
    $query = "EXECUTE Summary_ServerType"
    $sqlCommand.CommandText = $query
    $SQLType = $sqlCommand.ExecuteScalar();
    $cn.Close()

    return $SQLType
}


function write-UserVariablesToLog
{
    param(
        $Variables,
        $LogFile
    )

    foreach($Variable in $Variables)
    {
        Write-Log -Message "Variable: $($Variable.Name) Variable Value: $($Variable.value)" -Path $logfile -Category "UserVariables" -MetricValue $Variable.Name -MetricValue2 $Variable.Value
    }

}
function create-SQLFilesTable
{
    param(
        $ServerName,
        $DatabaseName
    )
    $Query = "
    IF OBJECT_ID('cust_ImportedFiles') IS NOT NULL
    BEGIN
        DROP TABLE cust_ImportedFiles
    END
    CREATE TABLE cust_ImportedFiles
    (
        IDCol INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
        FileName NVARCHAR(4000), 
        FileSizeKB BIGINT, 
        CreateDate DATETIME DEFAULT(GETDATE())
    )
    "
    Write-Log -Message "Creating Table cust_ImportedFiles" -Path $LogFile -WriteToHost  -Category "TableCreation" -MetricValue "cust_ImportedFiles"
    Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Query $Query   

}

function write-FileImportData
{
    param(
        $ServerName,
        $DatabaseName, 
        $FileName, 
        $FileSizeKB, 
        $LogFile
    )

    #Write-Log -Message "Adding File Import Information for file: $FileName" -Path $LogFile -Category "FileImportInformation" -SubCategory $FileName -MetricValue $FileSizeKB
    $Query = "INSERT INTO cust_ImportedFiles(FileName, FileSizeKB) VALUES('$($FileName)', $FileSizeKB)"
    Invoke-Sqlcmd -ServerInstance $ServerName -Database $DatabaseName -Query $Query   

}

function get-AnalyzerGlobalSettings
{
    $Uri = "https://sqlanalyzerlogging.azurewebsites.net/api/SqlAnalyzerLogging?GetSAS=true"

    try
    {
        $Settings = Invoke-RestMethod -Uri $Uri

        if($Settings)
        {
            return($Settings)
        }
        else {
            return($null)
        }
    }
    catch{

    }
}
function save-logfile
{
    param(
        $LogFile, 
        $StoragePath
    )

    $Uri = "https://sqlanalyzerlogging.azurewebsites.net/api/SqlAnalyzerLogging?GetSAS=true"

    try
    {
        #$fileToTransfer = "C:/PSSDiagExporter/PNB2/PNB2.log"
        $arglist = " copy """ + $LogFile + """  """ + $StoragePath + """"
        Start-Process -FilePath ".\Utilities\azcopy.exe" -ArgumentList $arglist -WindowStyle Hidden
    }
    catch{

    }

}

function write-processingMachineInfoToLog
{
    param
    (
        $LogFile
    )
    $ProgPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    $CompInfo = Get-ComputerInfo
    $ProgressPreference = $ProgPref

    $PMName = $CompInfo.CsName
    $PMProcessorCount = $CompInfo.CsNumberOfLogicalProcessors
    $PMFamily = $CompInfo.CsSystemFamily
    $PMUserName = $CompInfo.CsUserName
    $PMOsName = $CompInfo.OsName
    $PMOsVersion = $CompInfo.OsVersion
    $PMOSVisibleMemoryKB = $CompInfo.OsTotalVisibleMemorySize
    $PMOsFreePhysicalMemoryKB = $CompInfo.OsFreePhysicalMemory
    $PMOsArchitecture = $CompInfo.OsArchitecture
    $PMOsLanguage = $CompInfo.OsLanguage
    $PMLogonServer = $CompInfo.LogonServer

    $Category = "ProcessingMachineMetrics"
    Write-Log -Message "Processing Machine Name: $PMName" -Path $logfile -Category $Category -SubCategory "Machine Name" -MetricValue $PMName
    Write-Log -Message "Processing Machine Processor Count: $PMProcessorCount" -Path $logfile -Category $Category -SubCategory "Processor Count" -MetricValue $PMProcessorCount
    Write-Log -Message "Processing Machine Family: $PMFamily" -Path $logfile -Category $Category -SubCategory "Machine Family" -MetricValue $PMFamily
    Write-Log -Message "Processing Machine User Name: $PMUserName" -Path $logfile -Category $Category -SubCategory "User Name" -MetricValue $PMUserName
    Write-Log -Message "Processing Machine OS Name: $PMOsName" -Path $logfile -Category $Category -SubCategory "OS Name" -MetricValue $PMOsName
    Write-Log -Message "Processing Machine OS Version: $PMOsVersion" -Path $logfile -Category $Category -SubCategory "OS version" -MetricValue $PMOsVersion
    Write-Log -Message "Processing Machine Visible Memory KB: $PMOSVisibleMemoryKB" -Path $logfile -Category $Category -SubCategory "Visibile Memory KB" -MetricValue $PMOSVisibleMemoryKB
    Write-Log -Message "Processing Machine Free Memory KB: $PMOsFreePhysicalMemoryKB" -Path $logfile -Category $Category -SubCategory "Free Memory KB" -MetricValue $PMOsFreePhysicalMemoryKB
    Write-Log -Message "Processing Machine OS Architecture: $PMOsArchitecture" -Path $logfile -Category $Category -SubCategory "OS Architecture" -MetricValue $PMOsArchitecture
    Write-Log -Message "Processing Machine OS Language: $PMOsLanguage" -Path $logfile -Category $Category -SubCategory "OS Language" -MetricValue $PMOsLanguage
    Write-Log -Message "Processing Machine Logon Server: $PMLogonServer" -Path $logfile -Category $Category -SubCategory "Logon Server" -MetricValue $PMLogonServer


}