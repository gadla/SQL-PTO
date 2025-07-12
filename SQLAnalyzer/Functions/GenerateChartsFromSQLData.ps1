<#
Written by:  Tim Chapman, Microsoft
3/1/2017
#>

[void][Reflection.Assembly]::LoadWithPartialName(“System.Windows.Forms”) 
[void][Reflection.Assembly]::LoadWithPartialName(“System.Windows.Forms.DataVisualization”)
. .\Functions\Logger.ps1
. .\Functions\SQLPerfmonFunctions.ps1

function get-friendlycountername (
    [string]$fullname
) {
    $tmp = ($fullname.Substring($fullname.IndexOf('\',3)+1))
    return $tmp #.Substring($tmp.IndexOf(':')+1)
}

function Create-SingleChart (
    [object] $CounterData, 
    $CounterName, 
    $Source, 
    $filepath,
    $minWarning,
    $maxWarning,
    $minCritical,
    $maxCritical,
    $BackGradientStyle="TopBottom"
) {

    $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart 
    $Chart.Width = 600 
    $Chart.Height = 400 
    $Chart.Left = 60 
    $Chart.Top = 60

    $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 
    $Chart.ChartAreas.Add($ChartArea)

    $ChartMainTitle =New-Object System.Windows.Forms.DataVisualization.Charting.title
    $ChartTitleFont =new-object system.drawing.font("CALIBRI",18,[system.drawing.fontstyle]::Regular)
    $xaxisfont = new-object system.drawing.font("ARIAL",10,[system.drawing.fontstyle]::Regular)
    
    $Chart.titles.add($ChartMainTitle)
    $Chart.titles[0].forecolor = "Blue" 
    $Chart.titles[0].font = $ChartTitleFont
    $Chart.titles[0].forecolor = "black" 
    $Chart.BackColor = "White" 
    $Chart.BorderlineColor = "Black"
    $Chart.BorderColor = "Black"      
    $ChartArea.BackColor = "#D1EEFF"
    $ChartArea.AxisX.Title = "Capture Time"  


    $SeriesData = New-Object System.Windows.Forms.DataVisualization.Charting.Series
    $SeriesData["DrawingStyle"] = "lighttodark"
    $SeriesData.Color = "Blue"
    $SeriesData.BorderWidth = 4
    $SeriesData.SmartLabelStyle.Enabled=$true;
    $SeriesData.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::FastLine


    <#[void]$Chart.Series.Add(“Data”) 
    $Chart.Series["Data"]["DrawingStyle"] = "lighttodark"
    $Chart.Series["Data"].Color = "Blue"
    $Chart.Series["Data"].BorderWidth = 4
    $Chart.Series["Data"].SmartLabelStyle.Enabled=$true;
    $Chart.Series[“Data”].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::FastLine#>


    $SampleArray = @()
    $friendlyname = get-friendlycountername  $CounterName 

    if($Source -eq "SQL") {
        $Data = $CounterData
    }
    else {
        $Data = $CounterData.CounterSamples
    }

    $Series = 

    foreach($DataPoint in $Data) {
        $Properties = @{}
        if($DataPoint.TimeStamp -gt $null) {
            [datetime]$Timestamp = $DataPoint.TimeStamp 
            $Properties.TimeStamp += $Timestamp.tostring("t")
            $Properties.CookedValue += $DataPoint.CookedValue
            $DataSampleObject = new-object -TypeName PSObject -Property $Properties
            $SampleArray += $DataSampleObject
            $Series += ("35000")
        }
    }
    
    $chart.titles[0].text = $friendlyname
    [decimal]$maxsampleval = ($samplearray.CookedValue |measure -Maximum).Maximum

    if($maxsampleval -gt 1) {
        $maxyvalue = [math]::ceiling((($samplearray.CookedValue |measure -Maximum).Maximum)*1.1)
    }
    else {
        $maxyvalue = [math]::Round(($maxsampleval*1.25),5)
    }

    $idealxaxispoints = 6
    $xpoints = [math]::round(($samplearray.Count)/$idealxaxispoints)
    $ChartArea.Axisy.Maximum = $maxyvalue
    $ChartArea.AxisX.Interval = $xpoints
    $ChartArea.AxisX.TitleFont = $xaxisfont

    If ($maxWarning -ne $null){
        $SeriesWarningThreshold = New-Object System.Windows.Forms.DataVisualization.Charting.Series
        
        foreach($DataPoint in $Data) {
            If ($sBackGradientStyle -eq "BottomTop") {
                [Void] $SeriesWarningThreshold.Points.Add($maxWarning, $minWarning)
            }
            Else {
                [Void] $SeriesWarningThreshold.Points.Add($minWarning, $maxWarning)
            }
        }

        $SeriesWarningThreshold.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]"Range"
        $SeriesWarningThreshold.Name = "Warning"
        If ($BackGradientStyle -eq "BottomTop") {
            $SeriesWarningThreshold.Color = [System.Drawing.Color]"Transparent"
            $SeriesWarningThreshold.BackImageTransparentColor = [System.Drawing.Color]"White"
            $SeriesWarningThreshold.BackSecondaryColor = [System.Drawing.Color]"PaleGoldenrod"
        }
        else {
            $SeriesWarningThreshold.Color = [System.Drawing.Color]"PaleGoldenrod"
            $SeriesWarningThreshold.BackGradientStyle = [System.Windows.Forms.DataVisualization.Charting.GradientStyle]"TopBottom"
        }
        [Void] $Chart.Series.Add($SeriesWarningThreshold)        
    }

    If ($minCritical -ne $null)
    {
        $SeriesCriticalThreshold = New-Object System.Windows.Forms.DataVisualization.Charting.Series
        foreach($DataPoint in $Data) {
            if ($maxCritical -eq $null -or $maxCritical -eq "") {
    		    [Void] $SeriesCriticalThreshold.Points.Add($minCritical, $maxyvalue)
            }
            else {
    		    [Void] $SeriesCriticalThreshold.Points.Add($minCritical, $maxCritical)
            }
    	}
        $SeriesCriticalThreshold.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]"Range"
        $SeriesCriticalThreshold.Name = "Critical"

        If ($sBackGradientStyle -eq "BottomTop") {
            $SeriesCriticalThreshold.Color = [System.Drawing.Color]"Transparent"
            $SeriesCriticalThreshold.BackImageTransparentColor = [System.Drawing.Color]"White"
            $SeriesCriticalThreshold.BackSecondaryColor = [System.Drawing.Color]"Tomato"

            [Void] $Chart.Series.Add($SeriesCriticalThreshold)        
        }
        Else {
            $SeriesCriticalThreshold.Color = [System.Drawing.Color]"Tomato"
        }
        $SeriesCriticalThreshold.BackGradientStyle = [System.Windows.Forms.DataVisualization.Charting.GradientStyle]"TopBottom"
        [Void] $Chart.Series.Add($SeriesCriticalThreshold)        
    }
    <#

    [void]$Chart.Series.Insert(0,“Threshold”) 
    $Chart.Series["Threshold"]["DrawingStyle"] = "lighttodark"
    $Chart.Series["Threshold"].Color = "red"
    $Chart.Series[“Threshold”].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Area
    $Chart.Series[“Threshold”].Points.DataBindY($Series)

    #>

    if($samplearray.CookedValue -gt $null) {
        $SeriesData.Points.DataBindXY($samplearray.Timestamp, $samplearray.CookedValue)
    }
    [Void] $Chart.Series.Add($SeriesData)

    $fn = $friendlyname.Replace("\","").replace(" ","").replace("/","").replace("-","").replace(":","")
    $imagepath = "$filepath\$fn.png”
    $Chart.SaveImage($imagepath, “PNG”)
    return $imagepath
}

function Create-SingleChartInMemImage (
    [object] $CounterData, 
    $CounterName, 
    $Source, 
    $minWarning,
    $maxWarning,
    $minCritical,
    $maxCritical,
    $BackGradientStyle="TopBottom"
) {

    $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart 
    $Chart.Width = 600 
    $Chart.Height = 400 
    $Chart.Left = 60 
    $Chart.Top = 60

    $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 
    $Chart.ChartAreas.Add($ChartArea)

    $ChartMainTitle =New-Object System.Windows.Forms.DataVisualization.Charting.title
    $ChartTitleFont =new-object system.drawing.font("CALIBRI",18,[system.drawing.fontstyle]::Regular)
    $xaxisfont = new-object system.drawing.font("ARIAL",10,[system.drawing.fontstyle]::Regular)
    
    $Chart.titles.add($ChartMainTitle)
    $Chart.titles[0].forecolor = "Blue" 
    $Chart.titles[0].font = $ChartTitleFont
    $Chart.titles[0].forecolor = "black" 
    $Chart.BackColor = "White" 
    $Chart.BorderlineColor = "Black"
    $Chart.BorderColor = "Black"      
    $ChartArea.BackColor = "#D1EEFF"
    $ChartArea.AxisX.Title = "Capture Time"  

    $SeriesData = New-Object System.Windows.Forms.DataVisualization.Charting.Series
    $SeriesData["DrawingStyle"] = "lighttodark"
    $SeriesData.Color = "Blue"
    $SeriesData.BorderWidth = 4
    $SeriesData.SmartLabelStyle.Enabled=$true;
    $SeriesData.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::FastLine

    $SampleArray = @()
    $friendlyname = get-friendlycountername  $CounterName 

    if($Source -eq "SQL") {
        $Data = $CounterData
    }
    else {
        $Data = $CounterData.CounterSamples
    }

    $Series = 

    foreach($DataPoint in $Data) {
        $Properties = @{}
        if($DataPoint.TimeStamp -gt $null) {
            [datetime]$Timestamp = $DataPoint.TimeStamp 
            $Properties.TimeStamp += $Timestamp.tostring("t")
            $Properties.CookedValue += $DataPoint.CookedValue
            $DataSampleObject = new-object -TypeName PSObject -Property $Properties
            $SampleArray += $DataSampleObject
            $Series += ("35000")
        }
    }
    
    $chart.titles[0].text = $friendlyname
    [decimal]$maxsampleval = ($samplearray.CookedValue |measure -Maximum).Maximum

    if($maxsampleval -gt 1) {
        $maxyvalue = [math]::ceiling((($samplearray.CookedValue |measure -Maximum).Maximum)*1.1)
    }
    else {
        $maxyvalue = [math]::Round(($maxsampleval*1.25),5)
    }

    $idealxaxispoints = 6
    $xpoints = [math]::round(($samplearray.Count)/$idealxaxispoints)
    $ChartArea.Axisy.Maximum = $maxyvalue
    $ChartArea.AxisX.Interval = $xpoints
    $ChartArea.AxisX.TitleFont = $xaxisfont

    If ($maxWarning -ne $null){
        $SeriesWarningThreshold = New-Object System.Windows.Forms.DataVisualization.Charting.Series
        
        foreach($DataPoint in $Data) {
            If ($sBackGradientStyle -eq "BottomTop") {
                [Void] $SeriesWarningThreshold.Points.Add($maxWarning, $minWarning)
            }
            Else {
                [Void] $SeriesWarningThreshold.Points.Add($minWarning, $maxWarning)
            }
        }

        $SeriesWarningThreshold.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]"Range"
        $SeriesWarningThreshold.Name = "Warning"
        If ($BackGradientStyle -eq "BottomTop") {
            $SeriesWarningThreshold.Color = [System.Drawing.Color]"Transparent"
            $SeriesWarningThreshold.BackImageTransparentColor = [System.Drawing.Color]"White"
            $SeriesWarningThreshold.BackSecondaryColor = [System.Drawing.Color]"PaleGoldenrod"
        }
        else {
            $SeriesWarningThreshold.Color = [System.Drawing.Color]"PaleGoldenrod"
            $SeriesWarningThreshold.BackGradientStyle = [System.Windows.Forms.DataVisualization.Charting.GradientStyle]"TopBottom"
        }
        [Void] $Chart.Series.Add($SeriesWarningThreshold)        
    }

    If ($minCritical -ne $null)
    {
        $SeriesCriticalThreshold = New-Object System.Windows.Forms.DataVisualization.Charting.Series
        foreach($DataPoint in $Data) {
            if ($maxCritical -eq $null -or $maxCritical -eq "") {
    		    [Void] $SeriesCriticalThreshold.Points.Add($minCritical, $maxyvalue)
            }
            else {
    		    [Void] $SeriesCriticalThreshold.Points.Add($minCritical, $maxCritical)
            }
    	}
        $SeriesCriticalThreshold.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]"Range"
        $SeriesCriticalThreshold.Name = "Critical"

        If ($sBackGradientStyle -eq "BottomTop") {
            $SeriesCriticalThreshold.Color = [System.Drawing.Color]"Transparent"
            $SeriesCriticalThreshold.BackImageTransparentColor = [System.Drawing.Color]"White"
            $SeriesCriticalThreshold.BackSecondaryColor = [System.Drawing.Color]"Tomato"

            [Void] $Chart.Series.Add($SeriesCriticalThreshold)        
        }
        Else {
            $SeriesCriticalThreshold.Color = [System.Drawing.Color]"Tomato"
        }
        $SeriesCriticalThreshold.BackGradientStyle = [System.Windows.Forms.DataVisualization.Charting.GradientStyle]"TopBottom"
        [Void] $Chart.Series.Add($SeriesCriticalThreshold)        
    }

    if($samplearray.CookedValue -gt $null) {
        $SeriesData.Points.DataBindXY($samplearray.Timestamp, $samplearray.CookedValue)
    }
    [Void] $Chart.Series.Add($SeriesData)

    $MemoryStream = New-Object System.IO.MemoryStream
    $Chart.SaveImage($MemoryStream, [System.Windows.Forms.DataVisualization.Charting.ChartImageFormat]::Bmp)

    return [System.Drawing.Image]::FromStream($MemoryStream)
}




function create-SQLPerfmonSummary
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)] [string] $OutputPath, 
        [Parameter(Mandatory)] [bool] $GenerateCharts = $false, 
        $logfile = "", 
        [Parameter(Mandatory)] $Servername, 
        [Parameter(Mandatory)] $Databasename    
    )


    [string] $ChartSource="SQL"
    [bool] $GetFromBLG = $false

    if(!(test-path $logfile))
    {
        $logfile = join-path $OutputPath "$DatabaseName.log"
    }

    [string] $ChartPath = Join-Path $OutputPath "Charts"

    if(!(test-path $ChartPath))
    {
        new-item -Path $ChartPath -type Directory | Out-Null
    }

    [datetime] $StartTime = Get-Date

    #pull config data
    [xml]$DataLogicConfig = Get-Content ".\Configuration\DataLogic.xml"
      
    $LogicalDiskCounters = $DataLogicConfig.root.Counters.LogicalDiskCounters.Counter.CounterName| `
    Where-Object {(($_.Enabled -eq $true) -and ($_.Type = "Counter"))}|select "#text"|sort| `
    Select-Object @{Name="CounterName";Expression ={$_."#text"}}

    $SingleInstanceTargets = $DataLogicConfig.root.Counters.SingleMachineCounters.Counter.CounterName| `
    Where-Object {(($_.Enabled -eq $true) -and ($_.Type = "Counter"))}|select "#text"|sort| `
    Select-Object @{Name="CounterName";Expression ={$_."#text"}}

    #pull SQL counters from config file
    $SQLCounters = ($DataLogicConfig.root.Counters.SQLInstanceCounters.Counter.CounterName| `
    Where-Object {(($_.Enabled -eq $true) -and ($_.Type = "Counter"))})|select "#text"|sort| `
    Select-Object @{Name="CounterName";Expression ={$_."#text"}}

    $ProcessCounters = ($DataLogicConfig.root.Counters.ProcessCounters.Counter.CounterName| `
    Where-Object {(($_.Enabled -eq $true) -and ($_.Type = "Counter"))})|select "#text"|sort| `
    Select-Object @{Name="CounterName";Expression ={$_."#text"}}

    $CalculatedCounters = ($DataLogicConfig.root.Counters.CalculatedCounters.Counter| `
    Where-Object {(($_.CounterName.Enabled -eq $true) -and ($_.CounterName.Type = "Calculation"))})

    $DataLogicConfig.root.Counters.CalculatedCounters.Counter.Calculation

    $InstList = Get-SQLMachineInstanceNames -ServerName $ServerName -DatabaseName $DatabaseName   
    $MachineName = $InstList.Machinename |Select-Object -Unique

    if($MachineName -eq $null)
    {
        Write-Log -Message 'Error retrieving Machine Name.  Exiting Perfmon Summary.' -Path $logfile
        break
    }
    $perfsummarypath = join-path $OutputPath "PerfmonSummary.txt"
    $perfsummaryfile = new-item -Path $perfsummarypath -Force 

    $NumaNodeCount = $InstList.NumaNodeCount |Select-Object -Unique
    $ProcessorCount = $InstList.ProcessorCount |Select-Object -Unique
    $SQLInstanceTargets = @()

    #Inject the SQL instance Name in the SQL counters list

    Write-Log -Message 'Setting SQL instance targets list' -Path $logfile -WriteToHost

    foreach($Inst in $InstList)
    {
        $InstanceName = $Inst.InstanceName
        foreach($SQLCounter in $SQLCounters)
        {
            [string]$CounterName = $SQLCounter.CounterName
            $CalcCounter = "\\*\$InstanceName$CounterName"
            $SQLInstanceTargets += ""| select-object `
            @{Name="CalcCounter";Expression = {$CalcCounter}}, 
            @{Name="InstanceName";Expression = {$InstanceName}}, 
            @{Name="CounterName";Expression = {$CounterName}}
        }
    }
    $CounterObjectList = @()

    "Machine Name: $($MachineName)" | out-file -append $perfsummaryfile
    "Processor Count: $($ProcessorCount)" | out-file -append $perfsummaryfile
    "Numa Node Count: $($NumaNodeCount)" | out-file -append $perfsummaryfile
    "Instances in Capture: $($InstList.InstanceName)" | out-file -append $perfsummaryfile
    "" | out-file -append $perfsummaryfile


    $MachineName


    #output string separator variable - using for InstanceName below
    #should change this to use join instead.
    $OFS = ","
    Write-Log -Message 'Creating non-aggregated graphs from SQLInstanceCounters list' -Path $logfile -WriteToHost
    $Iterator = 1

    

    foreach($cntr in $SQLInstanceTargets)
    {
        Write-Progress -Activity "Generating SQLInstanceCounters data: $($cntr.CounterName)" -Status "Percent completed: $([int](($i/$SQLInstanceTargets.Length)*100))%" -PercentComplete (($i/$SQLInstanceTargets.Length)*100)
        $Iterator += 1

        $QuickCalc = $cntr.CalcCounter.Replace("\\*\", "\\$($MachineName)\")
        $LookupPath = $cntr.CounterName
        $Inst = $cntr.InstanceName

        $CounterData = Get-SQLCounterData -ServerName $ServerName -DatabaseName $DatabaseName -CounterName $QuickCalc -IncludeInstanceName $false -ReturnAggregate $false -MachineName $MachineName
        $ThresholdReached = $CounterData.ThresholdReached

        $path = $CounterData.CounterName |select-object -Unique 
        $output = $CounterData.CookedValue | measure-object -Average -Min -max 

        $CreateGraph = ($DataLogicConfig.root.Counters.SQLInstanceCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.Graph
        $minWarning = ($DataLogicConfig.root.Counters.SQLInstanceCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.minWarning
        $maxWarning = ($DataLogicConfig.root.Counters.SQLInstanceCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.maxWarning
        $minCritical = ($DataLogicConfig.root.Counters.SQLInstanceCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.minCritical
        $maxCritical = ($DataLogicConfig.root.Counters.SQLInstanceCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.maxCritical

        [bool]$WarningValuesExist = $false
        if(($maxWarning -eq $null) -or ($minCritical -eq $null))
        {
            $WarningValuesExist = $false
        }
        else
        {
            $WarningValuesExist = $true
        }

        $ChartImagePath = ""
        if(($output.Average -gt 0) -and ($output.Maximum -gt 0) -and ($CreateGraph -eq "true")-and (($ThresholdReached -eq $true) -or ($WarningValuesExist -eq $false)))
        {
            [string]$ChartImagePath = Create-SingleChart -CounterData $CounterData -CounterName $path -Source $ChartSource -filepath $ChartPath -MinWarning $minWarning -MaxWarning $maxWarning -MinCritical $minCritical -MaxCritical $maxCritical
        }


        $Description = $DataLogicConfig.root.Counters.SQLInstanceCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}|`
        Select-Object Description 
       
        #create custom aggreation object for each SQL Counter

        if($output.Count -gt 0)
        {
            $output = $output | Select-Object `
            @{Name="Average";Expression = {$_.Average}}, 
            @{Name="Minimum";Expression = {$_.Minimum}}, 
            @{Name="Maximum";Expression = {$_.Maximum}},
            @{Name="CounterName";Expression = {$QuickCalc}},
            @{Name="InstanceName";Expression = {$Inst}},
            @{Name="LookupPath";Expression = {$LookupPath}}, 
            @{Name="ImagePath";Expression = {$ChartImagePath}}, 
            @{Name="Description";Expression = {$Description.Description}}, 
            @{Name="Category";Expression = {"SQLInstanceCounters"}}

            $CounterObjectList += $output
        }
    }

    $Iterator = 1

    Write-Log -Message 'Creating aggregated graphs from SQLInstanceCounters list' -Path $logfile -WriteToHost
##    Write-Log -Message 'Before SQL Instance Targets aggregates' -Path $logfile -WriteToHost
    foreach($cntr in $SingleInstanceTargets)
    {
        Write-Progress -Activity "Generating Machine Counter Data: $($cntr.CounterName)" -Status "Percent completed: $([int](($Iterator/$SingleInstanceTargets.Count)*100))%" -PercentComplete (($Iterator/$SingleInstanceTargets.Count)*100)
        $Iterator += 1

        $LookupPath = $cntr.CounterName
        $CalcCounter = $LookupPath.Replace("\\*\", "\\$($MachineName)\")

        $ReturnAggregate = $false

        $CounterData = Get-SQLCounterData -ServerName $ServerName -DatabaseName $DatabaseName -CounterName $CalcCounter -IncludeInstanceName $false -ReturnAggregate $ReturnAggregate -MachineName $MachineName
        $path = $CounterData[0].FullPath

<#
         if($ReturnAggregate -eq $false)
        {
            $output = $CounterData.CookedValue | measure-object -Average -Min -max 

            $CreateGraph = ($DataLogicConfig.root.Counters.SingleMachineCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.Graph

            $ChartImagePath = ""
            if(($output.Average -gt 0) -and ($output.Maximum -gt 0) -and ($CreateGraph -eq "true"))
            {
                $ChartImagePath = Create-SingleChart -CounterData $CounterData -CounterName $LookupPath -Source $ChartSource -filepath $ChartPath
            }
        }
        else
        { #>
            #$output = $CounterData[0]
            
            $CreateGraph = ($DataLogicConfig.root.Counters.SingleMachineCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.Graph
            $minWarning = ($DataLogicConfig.root.Counters.SingleMachineCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.minWarning
            $maxWarning = ($DataLogicConfig.root.Counters.SingleMachineCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.maxWarning
            $minCritical = ($DataLogicConfig.root.Counters.SingleMachineCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.minCritical
            $maxCritical = ($DataLogicConfig.root.Counters.SingleMachineCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.maxCritical
            $Orientation = ($DataLogicConfig.root.Counters.SingleMachineCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.orientation

            
            $ChartImagePath = ""
            #if(($output.Average -gt 0) -and ($output.Maximum -gt 0) -and ($CreateGraph -eq "true"))
            #{
                $ChartImagePath = Create-SingleChart -CounterData $CounterData -CounterName $LookupPath -Source $ChartSource -filepath $ChartPath -minWarning $minWarning -maxWarning $maxWarning -minCritical $minCritical -maxCritical $maxCritical -BackGradientStyle $Orientation
            #}            
##        }

        $Description = $DataLogicConfig.root.Counters.SingleMachineCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}|`
        Select-Object Description 

        $output = $output | Select-Object `
        @{Name="Average";Expression = {$_.Average}}, 
        @{Name="Minimum";Expression = {$_.Minimum}}, 
        @{Name="Maximum";Expression = {$_.Maximum}},
        @{Name="CounterName";Expression = {$CalcCounter}},
        @{Name="InstanceName";Expression = {$MachineName}},
        @{Name="LookupPath";Expression = {$LookupPath}}, 
        @{Name="ImagePath";Expression = {$ChartImagePath}}, 
        @{Name="Description";Expression = {$Description.Description}}, 
        @{Name="Category";Expression = {"SingleMachineCounters"}}

        $CounterObjectList += $output

    }

    $DBCounters = 
    #"\Active Transactions",
    "\Data File(s) Size (KB)",
    "\Log File(s) Size (KB)"
    #"\Log File(s) Used Size (KB)"


    Write-Log -Message 'Creating specific database counters graphs from SQLInstanceCounters list' -Path $logfile -WriteToHost
    ##Write-Log -Message 'Before DB Counters' -Path $logfile -WriteToHost
    foreach($Inst in $InstList)
    {
        $InstanceName = $Inst.InstanceName
        $DBList = Get-PerfCounterDatabaseList -ServerName $ServerName -DatabaseName $DatabaseName

        $Iterator = 1
        foreach($DB in $DBList)
        {
            $DBName = $DB.Name
            foreach($DBCounter in $DBCounters)
            {
                $Iterator += 1
                $CalcCounter = "\\$MachineName\$($InstanceName):Databases($($DBName))$DBCounter"

                #Write-Progress -Activity "Generating Database Counter Data: $CalcCounter" -Status "Percent completed: $([int]((($Iterator/($DBList.Count*$DBCounters.Count))*100)))%" -PercentComplete (($Iterator/($DBList.Count*$DBCounters.Count))*100)

                $DBCounterData = Get-SQLCounterData -ServerName $ServerName -DatabaseName $DatabaseName -CounterName $CalcCounter -IncludeInstanceName $true -MachineName $MachineName
                $FullCounterPath = $DBCounterData[0].CounterName |select-object -Unique 
 
                $DBMetrics = $DBCounterData[0].CookedValue | measure-object -Average -Min -max 

                $Description = $DataLogicConfig.root.Counters.SingleMachineCounters.Counter |where-object {$DBCounter.CounterName."#text" -eq $LookupPath}|`
                Select-Object Description 

                #this doens't do anything right now.  Fix this later.
                #$CreateGraph = "false"
                #$CreateGraph = ($DataLogicConfig.root.Counters.SingleMachineCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.Graph
                
                #if(($output.maximum -gt 0) -and($CreateGraph -eq "true"))
                #{
                #    $ChartImagePath = Create-SingleChart -CounterData $DBCounterData -CounterName $FullCounterPath -Source $ChartSource -filepath $ChartPath
                # 
                #}

                $DBMetrics = $DBMetrics | Select-Object `
                @{Name="Average";Expression = {$_.Average}}, 
                @{Name="Minimum";Expression = {$_.Minimum}}, 
                @{Name="Maximum";Expression = {$_.Maximum}},
                @{Name="CounterName";Expression = {$FullCounterPath}},
                @{Name="InstanceName";Expression = {$InstanceName}},
                @{Name="LookupPath";Expression = {$($FullCounterPath)}}, 
                @{Name="ImagePath";Expression = {""}}, 
                @{Name="Description";Expression = {$Description.Description}}, 
                @{Name="Category";Expression = {"DatabaseCounters"}}

                $CounterObjectList += $DBMetrics

                #$CounterObjectList
            }
        }
    }

    $Iterator = 1

    foreach($LogicalDiskCounter in $LogicalDiskCounters)
    {
        $CounterName = $LogicalDiskCounter.CounterName
        $LookupPath = $CounterName

        $DriveList = Get-InstanceListByObjectName -ServerName $Servername -DatabaseName $DatabaseName -ObjectName "LogicalDisk"
        foreach($Drive in $DriveList)
        {
            Write-Progress -Activity "Generating Logical Disk Counter Data: $($Drive.Name)" -Status "Percent completed: $([int]((($Iterator/($LogicalDiskCounters.Count*$DriveList.Count))*100)))%" -PercentComplete (($Iterator/($LogicalDiskCounters.Count*$DriveList.Count))*100)
            $Iterator += 1

            $CreateGraph = ($DataLogicConfig.root.Counters.LogicalDiskCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.Graph
            $minWarning = ($DataLogicConfig.root.Counters.LogicalDiskCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.minWarning
            $maxWarning = ($DataLogicConfig.root.Counters.LogicalDiskCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.maxWarning
            $minCritical = ($DataLogicConfig.root.Counters.LogicalDiskCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.minCritical
            $maxCritical = ($DataLogicConfig.root.Counters.LogicalDiskCounters.Counter |where-object {$_.CounterName."#text" -eq $LookupPath}).CounterName.maxCritical

            [bool]$WarningValuesExist = $false
            if(($maxWarning -eq $null) -or ($minCritical -eq $null))
            {
                $WarningValuesExist = $false
            }
            else
            {
                $WarningValuesExist = $true
            }

            $DiskCounter = "\\$MachineName\LogicalDisk($($Drive.Name))\$CounterName"
            $DiskCounterData = Get-SQLCounterData -ServerName $ServerName -DatabaseName $DatabaseName -CounterName $DiskCounter -IncludeInstanceName $true -ReturnAggregate $false -minThreshold $maxWarning -maxThreshold $minCritical -MachineName $MachineName
            $FullCounterPath = $DiskCounterData.CounterName |select-object -Unique 
            $ThresholdReached = $DiskCounterData.ThresholdReached
            $DiskMetrics = $DiskCounterData.CookedValue | measure-object -Average -Min -max 

            if(($DiskMetrics.Average -gt 0) -and ($DiskMetrics.Maximum -gt 0) -and ($CreateGraph -eq "true") -and (($ThresholdReached -eq $true) -or ($WarningValuesExist -eq $false)))
            {
                $ChartImagePath = Create-SingleChart -CounterData $DiskCounterData -CounterName $DiskCounter -Source $ChartSource -filepath $ChartPath -MinWarning $minWarning -MaxWarning $maxWarning -MinCritical $minCritical -MaxCritical $maxCritical
            }else
            {
                $ChartImagePath = ""
            }
            
            $Description = $DataLogicConfig.root.Counters.LogicalDiskCounters.Counter|where-object {$_.CounterName."#text" -eq $LookupPath}|`
            Select-Object Description 

            $DiskMetrics = $DiskMetrics | Select-Object `
            @{Name="Average";Expression = {$_.Average}}, `
            @{Name="Minimum";Expression = {$_.Minimum}}, `
            @{Name="Maximum";Expression = {$_.Maximum}},`
            @{Name="CounterName";Expression = {$FullCounterPath}},`
            @{Name="InstanceName";Expression = {$InstanceName}},
            @{Name="LookupPath";Expression = {$FullCounterPath}}, 
            @{Name="ImagePath";Expression = {$ChartImagePath}}, 
            @{Name="Description";Expression = {$Description.Description}},
            @{Name="DriveName";Expression = {$($Drive.Name)}}, 
            @{Name="Category";Expression = {"DiskCounters"}},
            @{Name="ThresholdReached";Expression = {$ThresholdReached}}, 
            @{Name="WarningValuesExist";Expression = {$WarningValuesExist}}
            
            
            $CounterObjectList += $DiskMetrics
        }
    }

    Write-Progress -Activity "Generating Logical Disk Counter Data: " -Status "Percent completed: 100%" -PercentComplete 100 -Completed


    #-----------------------------------------------------------------------------------------------------------------
    Write-Log -Message 'Creating graphs from ProcessCounters list' -Path $logfile -WriteToHost
    ##Write-Log -Message 'Before Process Counters list' -Path $logfile -WriteToHost
    $Iterator = 1
    foreach($Process in $ProcessCounters)
    {
        $ProcessData = @()
        $ProcessCounter = $Process.CounterName
        $CounterTarget = "\\*\Process(*)\$ProcessCounter"
  
        $CounterData = Get-SQLCounterData -ServerName $ServerName -DatabaseName $DatabaseName -CounterName $CounterTarget -IncludeInstanceName $false -ReturnAggregate $false -MachineName $MachineName

    }
   #-----------------------------------------------------------------------------------------------------------------

   foreach($CalcCounter in $CalculatedCounters)
   {
        $CalcCounter.CounterName.'#text'
        $Numerator = $CalcCounter.Calculation.Numerator
        $Denominator = $CalcCounter.Calculation.Denominator

        #GetCalculatedSQLCounterData  -ServerName $ServerName -DatabaseName $DatabaseName -CounterName $CounterTarget -IncludeInstanceName $false -ReturnAggregate $false -NumeratorCounter $Numerator -DenominatorCounter $Denominator
   }



    $CounterObjectList | where-object {($_.countername -NotLike "*LogicalDisk(_total)*") -and ($_.Maximum -gt 0)} |
    Select-Object  | `
    format-table CounterName, 
    @{Label='Average';expression={"{0:N3}" -f $_.Average}}, 
    @{Label='Minimum';expression={"{0:N3}" -f $_.Minimum}}, 
    @{Label='Maximum';expression={"{0:N3}" -f $_.Maximum}} -AutoSize| out-string -width 4096 |out-file -append $perfsummaryfile

    #run rules
    #pull from config file
    $ResponseArray = @()

    Write-Log -Message 'Evaluating performance counter rules.' -Path $logfile -WriteToHost
    $InstList | %{
        $InstanceName = $_.InstanceName  #Don't change this variable name.  Tied to config file.

        $VarName = $DataLogicConfig.root.RulesEngine.VariableAssignments.Assignment.VariableName
        $Expression = $DataLogicConfig.root.RulesEngine.VariableAssignments.Assignment.Expression

        foreach($VariableObject in $DataLogicConfig.root.RulesEngine.VariableAssignments.Assignment)
        {
            $VariableName = $VariableObject.VariableName
            $WhereExpression = $VariableObject.Expression
            New-Variable -Name $VariableName -Value (invoke-expression $WhereExpression) -Force
        }

    
        #run rules from file against variables dynamically created above
        foreach($RuleObject in $DataLogicConfig.root.RulesEngine.Rules.Rule)
        {   
            #$RuleObject
            $Response = ""

            [string]$RuleExpression = $RuleObject.Expression
            if(invoke-expression $RuleExpression)
            {
                $Response += $RuleObject.Description
            }

            if($RuleObject.DescriptionExpression -and $Response -gt "")
            {
                $Response += (invoke-expression $RuleObject.DescriptionExpression)
            }

            if($Response -gt "")
            {
                $ResponseArray += $Response
            }
        }
    }
    #write out responses to the file
    Write-Log -Message "Writing performance counter evaluations. Take a look on the $perfsummaryfile" -Path $logfile -WriteToHost
    $ResponseArray | format-table -AutoSize | out-file -Encoding unicode -append $perfsummaryfile
    $CategoryList = ($CounterObjectList | group Category).Name

    <#
    Write-Log -Message "Creating Word documents from grouped categories..." -Path $logfile -WriteToHost
    ForEach($Category in $CategoryList) {
        #skip db counters for now
        if($Category -ne "DatabaseCounters") {
            $WordDocPath = join-path $OutputPath "PerfmonCounters_$Category.docx"
            Write-Log -Message "Creating $WordDocPath" -Path $logfile -WriteToHost
            $CounterObjectList |where-object {($_.Category -eq $Category)}  |sort-object LookupPath | GenerateWordDocFromObject -SavePath $WordDocPath
        }
    }
    #>

    $endtime = Get-Date
    #$starttime
    #$endtime

    return($CounterObjectList)
}

