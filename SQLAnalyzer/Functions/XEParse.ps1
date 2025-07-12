#get-command Read-SqlXEvent 

#get-help Read-SqlXEvent  
#get-installedmodule -Name sqlserver -AllVersions|uninstall-module -Force


<#
.SYNOPSIS
Faster version of Compare-Object for large data sets with a single value.
.DESCRIPTION
Uses hash tables to improve comparison performance for large data sets.
.PARAMETER ReferenceObject
Specifies an array of objects used as a reference for comparison.
.PARAMETER DifferenceObject
Specifies the objects that are compared to the reference objects.
.PARAMETER IncludeEqual
Indicates that this cmdlet displays characteristics of compared objects that
are equal. By default, only characteristics that differ between the reference
and difference objects are displayed.
.PARAMETER ExcludeDifferent
Indicates that this cmdlet displays only the characteristics of compared
objects that are equal.
.EXAMPLE
Compare-Object2 -ReferenceObject 'a','b','c' -DifferenceObject 'c','d','e' `
    -IncludeEqual -ExcludeDifferent
.EXAMPLE
Compare-Object2 -ReferenceObject (Get-Content .\file1.txt) `
    -DifferenceObject (Get-Content .\file2.txt)
.EXAMPLE
$p1 = Get-Process
notepad
$p2 = Get-Process
Compare-Object2 -ReferenceObject $p1.Id -DifferenceObject $p2.Id
.NOTES
Does not support objects with properties. Expand the single property you want
to compare before passing it in.
Includes optimization to run even faster when -IncludeEqual is omitted.
#>            
function Compare-Object2 {            
param(            
    [psobject[]]            
    $ReferenceObject,            
    [psobject[]]            
    $DifferenceObject,            
    [switch]            
    $IncludeEqual,            
    [switch]            
    $ExcludeDifferent            
)            
            
    # Put the difference array into a hash table,            
    # then destroy the original array variable for memory efficiency.            
    $DifHash = @{}            
    $DifferenceObject | ForEach-Object {$DifHash.Add($_,$null)}            
    Remove-Variable -Name DifferenceObject            
            
    # Put the reference array into a hash table.            
    # Keep the original array for enumeration use.            
    $RefHash = @{}            
    for ($i=0;$i -lt $ReferenceObject.Count;$i++) {            
        $RefHash.Add($ReferenceObject[$i],$null)            
    }            
            
    # This code is ugly but faster.            
    # Do the IF only once per run instead of every iteration of the ForEach.            
    If ($IncludeEqual) {            
        $EqualHash = @{}            
        # You cannot enumerate with ForEach over a hash table while you remove            
        # items from it.            
        # Must use the static array of reference to enumerate the items.            
        ForEach ($Item in $ReferenceObject) {            
            If ($DifHash.ContainsKey($Item)) {            
                $DifHash.Remove($Item)            
                $RefHash.Remove($Item)            
                $EqualHash.Add($Item,$null)            
            }            
        }            
    } Else {            
        ForEach ($Item in $ReferenceObject) {            
            If ($DifHash.ContainsKey($Item)) {            
                $DifHash.Remove($Item)            
                $RefHash.Remove($Item)            
            }            
        }            
    }            
            
    If ($IncludeEqual) {            
        $EqualHash.Keys | Select-Object @{Name='InputObject';Expression={$_}},`
            @{Name='SideIndicator';Expression={'=='}}            
    }            
            
    If (-not $ExcludeDifferent) {            
        $RefHash.Keys | Select-Object @{Name='InputObject';Expression={$_}},`
            @{Name='SideIndicator';Expression={'<='}}            
        $DifHash.Keys | Select-Object @{Name='InputObject';Expression={$_}},`
            @{Name='SideIndicator';Expression={'=>'}}            
    }            
}    


function import-XEFiles
{
param(
    $XEFolder, 
    $ServerInstance, 
    $DatabaseName, 
    $SchemaName, 
    $TableName

)

get-date 
#$XEFolder = "D:\SQL\Import"

if(Test-Path $XEFolder)
{
   $XEFiles = get-childitem -Path $XEFolder -Filter "*.xel" 
}
else
{
    Write-Error "Unable to access XE File folder"
    return
}


$DTable = New-Object System.Data.DataTable 

$AllColumns = @()

foreach($XEFile in $XEFiles)
{

    try
    {
    $XEData = Read-SqlXEvent -FileName $XEFile.FullName
    }
    catch
    {
        $_.Exception.Message
        Write-Error "Unable to access XE File folder" -Level "Error"
        return
    }

    $ColListActions = $XEData.Actions.Keys |Select-Object -Unique
    $ColListFields = $XEData.Fields.Key |Select-Object -Unique

    $FileColumns = $ColListActions + $ColListFields|Select-Object -Unique

    #weird issue where a NULL is getting into the col list.  Remove them.
    if($AllColumns -contains $null)
    {
        $AllColumns = $AllColumns | Where-Object {$_ -ne $null}
    }

    if($FileColumns -contains $null)
    {
        $FileColumns = $FileColumns | Where-Object {$_ -ne $null}
    }

    try
    {
        $NewColumns = Compare-Object2 -ReferenceObject $AllColumns -DifferenceObject $FileColumns |Where-Object {$_.SideIndicator -eq "=>"} |select @{l = "ColumnName"; e = {$_.InputObject}}
    }
    catch
    {
        $_.Exception.Message
        return
    }
    #if there are new columns, need to add them to the base table
    #unless table hasn't been created yet

    if($NewColumns -and $AllColumns)
    {
        foreach($NewCol in $NewColumns)
        {
            $SQL = "ALTER TABLE $TableName ADD [$($NewCol.ColumnName)] nvarchar(max)"
            $AlterColCmd = @{}
            $AlterColCmd.ServerInstance = $ServerInstance
            $AlterColCmd.DatabaseName = $DatabaseName 
            $AlterColCmd.SchemaName = $SchemaName 
            $AlterColCmd.Query = $SQL 
            $AlterColCmd.ConnectionTimeout = 0 
            $AlterColCmd.Timeout = 0 

            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -Query $SQL -ConnectionTimeout 0
        }
    }
    
    $AllColumns += ($NewColumns.ColumnName |Where-Object {$_ -ne ""})

    foreach($col in $AllColumns)
    {
        if(-not($DTable.Columns.Contains($col)) -and $Col)
        {
            try
            {
                $DTable.Columns.Add($col) |Out-Null
            }
            catch
            {
                $_.Exception.Message
            }
        }
    }

    foreach($wait in $XEData)
    {
        $row = $DTable.NewRow()

        foreach($Fieldkey in $wait.Fields)
        {
            try
            {
                $row[$Fieldkey.Key] = $Fieldkey.Value
            }
            catch
            {
                $_.Exception.Message
            }
        }
        
        foreach($Actionkey in $wait.Actions.Keys)
        {
            try
            {
                $row[$Actionkey] = $wait.Actions[$Actionkey]
            }
            catch
            {
                $_.Exception.Message
            }
        }

        #Adding Row to table
        $DTable.Rows.Add($row)

    }

    $DTable.Rows.Count

    try
    {
        $WriteTableParms = @{}
        $WriteTableParms.ServerInstance = $ServerInstance
        $WriteTableParms.DatabaseName = $DatabaseName 
        $WriteTableParms.SchemaName = $SchemaName 
        $WriteTableParms.TableName = $TableName 
        $WriteTableParms.InputData = $DTable 
        $WriteTableParms.Force = $true
        $WriteTableParms.ErrorAction = "Stop"
        $WriteTableParms.ConnectionTimeout = 0 
        $WriteTableParms.Timeout = 0 

        Write-SqlTableData @WriteTableParams
        #-ServerInstance $ServerInstance -DatabaseName $DatabaseName -SchemaName $SchemaName -TableName $TableName -InputData $DTable -Force -ErrorAction Stop -ConnectionTimeout 0 -Timeout 0 |Out-Null
    }
    catch
    {
        $_.Exception.Message
    }

}

Get-Date
}

#import-XEFiles -XEFolder "D:\SQL\Import" -ServerInstance "." -DatabaseName "AdventureWorks2016" -SchemaName "dbo" -TableName "XEImport"
