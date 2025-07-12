
#############################################################################################
function Get-SQLCounterData
{
param
(
$ServerName , 
$DatabaseName,
$CounterName, 
$IncludeInstanceName = $false, 
$ReturnAggregate = $false, 
$minThreshold, 
$maxThreshold, 
[Parameter(Mandatory=$true)] $MachineName
)

    $CounterArray = @()
    #get a list of databases involved in the capture.
    $cn = new-object System.Data.SqlClient.SqlConnection "server=$ServerName;database=$DatabaseName;Integrated Security=sspi"
    $cn.Open()
    $fillCmd = New-Object System.Data.SQLClient.SQLCommand
    $fillCmd.Connection = $cn

    $StatementDS = New-Object "System.Data.DataSet"
    $Cmd = New-Object "System.Data.SqlClient.SqlCommand"
    $Cmd.Connection = $cn
    $Cmd.CommandType = "StoredProcedure"
    $Cmd.CommandText = "PerfCounter_GetDataByCounter"

    $DBParam = $Cmd.Parameters.Add("@CounterPath", [System.Data.SqlDbType]::VARCHAR, 1024)
    $DBParam.value = $CounterName

    $DBParam = $Cmd.Parameters.Add("@IncludeInstanceName", [System.Data.SqlDbType]::Bit)
    $DBParam.value = $IncludeInstanceName

    $DBParam = $Cmd.Parameters.Add("@ReturnAggregate", [System.Data.SqlDbType]::Bit)
    $DBParam.value = $ReturnAggregate

    $DBParam2 = $Cmd.Parameters.Add("@FullCounterPath", [System.Data.SqlDbType]::VARCHAR, 1024)
    $DBParam2.Direction = [system.Data.ParameterDirection]::Output

    $DBParam3 = $Cmd.Parameters.Add("@ThresholdReached", [System.Data.SqlDbType]::Bit)
    $DBParam3.Direction = [system.Data.ParameterDirection]::Output

    $DBParam4 = $Cmd.Parameters.Add("@MinThresholdValue", [System.Data.SqlDbType]::DECIMAL)
    $DBParam4.value = $minThreshold

    $DBParam5 = $Cmd.Parameters.Add("@MaxThresholdValue", [System.Data.SqlDbType]::DECIMAL)
    $DBParam5.value = $maxThreshold

    $DBParam6 = $Cmd.Parameters.Add("@MachineName", [System.Data.SqlDbType]::VARCHAR, 1024)
    $DBParam6.value = $MachineName
                            
    $newdataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($Cmd) 
    $newdataAdapter.SelectCommand.CommandTimeout = 240

    $newdataAdapter.Fill($StatementDS) | Out-Null
            
    $CD = $null
    $CD = new-object "System.Data.DataTable"
    $CD = $StatementDS.Tables[0]

    $FullCounterPath = $Cmd.Parameters["@FullCounterPath"].Value
    $ThresholdReached = $Cmd.Parameters["@ThresholdReached"].Value

    if($ReturnAggregate -eq $false)
    {
        $SQLPerfmonData = $CD| Select-Object `
        @{Name="TimeStamp";Expression = {$_.Timestamp}}, 
        @{Name="CookedValue";Expression = {$_.CookedValue}},
        @{Name="CounterName";Expression = {$FullCounterPath}}
    }
    else
    {
        $SQLPerfmonData = $CD| Select-Object `
        @{Name="Average";Expression = {$_.Average}}, `
        @{Name="Minimum";Expression = {$_.Minimum}}, `
        @{Name="Maximum";Expression = {$_.Maximum}},
        @{Name="CounterName";Expression = {$_.CounterPath}}
    }
    $CounterArray += $SQLPerfmonData

    if($ReturnAggregate -eq $false)
    {
        $CounterArray += $FullCounterPath | Select-Object @{Name="FullPath";Expression={$_.ToString()}}
    }

    if($cn.state -eq 1)
    {$cn.Close()}

    $CounterArray += $ThresholdReached | Select-Object @{Name="ThresholdReached";Expression={$_.ToString()}}

    return($CounterArray)


}


function Get-BatchResponseBaselineFromSQL
{
param
(
$ServerName , 
$DatabaseName
)
    $CounterArray = @()
    #get a list of databases involved in the capture.
    $cn = new-object System.Data.SqlClient.SqlConnection "server=$ServerName;database=$DatabaseName;Integrated Security=sspi"
    $cn.Open()
    $fillCmd = New-Object System.Data.SQLClient.SQLCommand
    $fillCmd.Connection = $cn

    $StatementDS = New-Object "System.Data.DataSet"
    $Cmd = New-Object "System.Data.SqlClient.SqlCommand"
    $Cmd.Connection = $cn
    $Cmd.CommandType = "StoredProcedure"
    $Cmd.CommandText = "GetBatchResponseBaseline"
                    
    $newdataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($Cmd) 
    $newdataAdapter.SelectCommand.CommandTimeout = 240
    $newdataAdapter.Fill($StatementDS) | Out-Null
            
    $BatchResponse = $null
    $BatchResponse = new-object "System.Data.DataTable"
    $BatchResponse = $StatementDS.Tables[0]

    return($BatchResponse)

}


function Get-PerfCounterDatabaseList
{
param
(
$ServerName , 
$DatabaseName
)
    $CounterArray = @()
    #get a list of databases involved in the capture.
    $cn = new-object System.Data.SqlClient.SqlConnection "server=$ServerName;database=$DatabaseName;Integrated Security=sspi"
    $cn.Open()
    $fillCmd = New-Object System.Data.SQLClient.SQLCommand
    $fillCmd.Connection = $cn

    $StatementDS = New-Object "System.Data.DataSet"
    $Cmd = New-Object "System.Data.SqlClient.SqlCommand"
    $Cmd.Connection = $cn
    $Cmd.CommandType = "StoredProcedure"
    $Cmd.CommandText = "PerfCounter_GetDatabaseList"
                    
    $newdataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($Cmd) 
    $newdataAdapter.SelectCommand.CommandTimeout = 240
    $newdataAdapter.Fill($StatementDS) | Out-Null
            
    $DBList = $null
    $DBList = new-object "System.Data.DataTable"
    $DBList = $StatementDS.Tables[0]

    return($DBList)

}


function Get-SQLMachineInstanceNames
{
param
(
$ServerName , 
$DatabaseName
)
    $CounterArray = @()
    #get a list of databases involved in the capture.
    $cn = new-object System.Data.SqlClient.SqlConnection "server=$ServerName;database=$DatabaseName;Integrated Security=sspi"
    $cn.Open()
    $fillCmd = New-Object System.Data.SQLClient.SQLCommand
    $fillCmd.Connection = $cn

    $StatementDS = New-Object "System.Data.DataSet"
    $Cmd = New-Object "System.Data.SqlClient.SqlCommand"
    $Cmd.Connection = $cn
    $Cmd.CommandType = "StoredProcedure"
    $Cmd.CommandText = "PerfCounter_GetSQLInstanceNames"
                    
    $newdataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($Cmd) 
    $newdataAdapter.SelectCommand.CommandTimeout = 240
    $newdataAdapter.Fill($StatementDS) | Out-Null
            
    $MachineInstanceList = $null
    $MachineInstanceList = new-object "System.Data.DataTable"
    $MachineInstanceList = $StatementDS.Tables[0]

    return($MachineInstanceList)

}



function Get-InstanceListByObjectName
{
param
(
$ServerName , 
$DatabaseName, 
$ObjectName
)
    $CounterArray = @()
    #get a list of databases involved in the capture.
    $cn = new-object System.Data.SqlClient.SqlConnection "server=$ServerName;database=$DatabaseName;Integrated Security=sspi"
    $cn.Open()
    $fillCmd = New-Object System.Data.SQLClient.SQLCommand
    $fillCmd.Connection = $cn

    $StatementDS = New-Object "System.Data.DataSet"
    $Cmd = New-Object "System.Data.SqlClient.SqlCommand"
    $Cmd.Connection = $cn
    $Cmd.CommandType = "StoredProcedure"
    $Cmd.CommandText = "PerfCounter_GetInstanceList"

    $DBParam = $Cmd.Parameters.Add("@ObjectName", [System.Data.SqlDbType]::VARCHAR, 250)
    $DBParam.value = $ObjectName
                        
    $newdataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($Cmd) 
    $newdataAdapter.SelectCommand.CommandTimeout = 240
    $newdataAdapter.Fill($StatementDS) | Out-Null
            
    $MachineInstanceList = $null
    $MachineInstanceList = new-object "System.Data.DataTable"
    $MachineInstanceList = $StatementDS.Tables[0]

    return($MachineInstanceList)

}

#############################################################################################
function Get-CalculatedSQLCounterData
{
param
(
$ServerName , 
$DatabaseName,
$NumeratorCounter, 
$DenominatorCounter,
$IncludeInstanceName = $false, 
$ReturnAggregate = $false, 
$minThreshold, 
$maxThreshold
)
<#
$ServerName = "."
$DatabaseName = "SQLNexus"
$CounterName = "\\*\SQLServer\:General Statistics\Transactions"
$IncludeInstancename = $true
$ReturnAggregate = $true
#>


    $CounterArray = @()
    #get a list of databases involved in the capture.
    $cn = new-object System.Data.SqlClient.SqlConnection "server=$ServerName;database=$DatabaseName;Integrated Security=sspi"
    $cn.Open()
    $fillCmd = New-Object System.Data.SQLClient.SQLCommand
    $fillCmd.Connection = $cn

    $StatementDS = New-Object "System.Data.DataSet"
    $Cmd = New-Object "System.Data.SqlClient.SqlCommand"
    $Cmd.Connection = $cn
    $Cmd.CommandType = "StoredProcedure"
    $Cmd.CommandText = "PerfCounter_GetDataByCounter"

    $DBParam = $Cmd.Parameters.Add("@CounterPath", [System.Data.SqlDbType]::VARCHAR, 1024)
    $DBParam.value = $CounterName

    $DBParam = $Cmd.Parameters.Add("@IncludeInstanceName", [System.Data.SqlDbType]::Bit)
    $DBParam.value = $IncludeInstanceName

    $DBParam = $Cmd.Parameters.Add("@ReturnAggregate", [System.Data.SqlDbType]::Bit)
    $DBParam.value = $ReturnAggregate

    $DBParam2 = $Cmd.Parameters.Add("@FullCounterPath", [System.Data.SqlDbType]::VARCHAR, 1024)
    $DBParam2.Direction = [system.Data.ParameterDirection]::Output

    $DBParam3 = $Cmd.Parameters.Add("@ThresholdReached", [System.Data.SqlDbType]::Bit)
    $DBParam3.Direction = [system.Data.ParameterDirection]::Output

    $DBParam4 = $Cmd.Parameters.Add("@MinThresholdValue", [System.Data.SqlDbType]::DECIMAL)
    $DBParam4.value = $minThreshold

    $DBParam5 = $Cmd.Parameters.Add("@MaxThresholdValue", [System.Data.SqlDbType]::DECIMAL)
    $DBParam5.value = $maxThreshold
                            
    $newdataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($Cmd) 
    $newdataAdapter.SelectCommand.CommandTimeout = 240
    $newdataAdapter.Fill($StatementDS) | Out-Null
            
    $CD = $null
    $CD = new-object "System.Data.DataTable"
    $CD = $StatementDS.Tables[0]

    $FullCounterPath = $Cmd.Parameters["@FullCounterPath"].Value
    $ThresholdReached = $Cmd.Parameters["@ThresholdReached"].Value

    if($ReturnAggregate -eq $false)
    {
        $SQLPerfmonData = $CD| Select-Object `
        @{Name="TimeStamp";Expression = {$_.Timestamp}}, 
        @{Name="CookedValue";Expression = {$_.CookedValue}},
        @{Name="CounterName";Expression = {$FullCounterPath}}
    }
    else
    {
        $SQLPerfmonData = $CD| Select-Object `
        @{Name="Average";Expression = {$_.Average}}, `
        @{Name="Minimum";Expression = {$_.Minimum}}, `
        @{Name="Maximum";Expression = {$_.Maximum}},
        @{Name="CounterName";Expression = {$_.CounterPath}}
    }
    $CounterArray += $SQLPerfmonData

    if($ReturnAggregate -eq $false)
    {
        $CounterArray += $FullCounterPath | Select-Object @{Name="FullPath";Expression={$_.ToString()}}
    }

    if($cn.state -eq 1)
    {$cn.Close()}

    $CounterArray += $ThresholdReached | Select-Object @{Name="ThresholdReached";Expression={$_.ToString()}}

    return($CounterArray)


}
