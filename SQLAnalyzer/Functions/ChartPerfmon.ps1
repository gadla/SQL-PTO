[void][Reflection.Assembly]::LoadWithPartialName(“System.Windows.Forms”) 
[void][Reflection.Assembly]::LoadWithPartialName(“System.Windows.Forms.DataVisualization”)

function get-friendlycountername (
    [string]$fullname
) {
    $tmp = ($fullname.Substring($fullname.IndexOf('\',3)+1))
    return $tmp #.Substring($tmp.IndexOf(':')+1)
}

function CreateSingleChart (
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

function CreateSingleChartInMemImage (
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


