##Set-Location C:\SQLAnalyzer
<#
 Tim Chapman
 #>
. .\Functions\Logger.ps1

function Add-TableToWordDoc
{
    param
    (
        $ServerName, 
        $DatabaseName,
        [object]$doc, 
        $logfile, 
        $sql, 
        [object]$Selection, 
        $heading, 
        $description
    )

    try
    {
        $HeaderFooterIndex = "microsoft.office.interop.word.WdHeaderFooterIndex" -as [type]
        $BreakType = "microsoft.office.interop.word.WdBreakType" -as [type]
        $AlignmentTab = "microsoft.office.interop.word.WdAlignmentTabAlignment" -as [type]
        $ParagraphAlignment = "microsoft.office.interop.word.WdParagraphAlignment" -as [type]
        $Units = "microsoft.office.interop.word.WdUnits" -as [type]
        $PageNumberAlignment = "microsoft.office.interop.word.WdPageNumberAlignment" -as [type]
        $PageNumberStyle = "microsoft.office.interop.word.wdPageNumberStyle" -as [type]
        $Color = "microsoft.office.interop.word.wdColor" -as [type]

        $cn = new-object System.Data.SqlClient.SqlConnection "server=$ServerName;database=$DatabaseName;Integrated Security=sspi"
        $query = $sql

        $dataSet = new-object "System.Data.DataSet" 

        #Create a SQL Data Adapter to place the resultset into the DataSet
        $dataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($query, $cn) 
        $dataAdapter.SelectCommand.CommandTimeout = 0
        
        $dataAdapter.Fill($dataSet) | Out-Null

        $dataTable = new-object "System.Data.DataTable"
        $dataTable = $dataSet.Tables[0]

        $rowcount = $dataTable.Rows.Count
        $columncount = $dataTable.Columns.Count

        $Selection.Style = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).Style
        $Selection.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).FontName
        $Selection.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).FontSize
        $Selection.typetext($heading)
        $Selection.typeparagraph()

        if ($rowcount -gt 0)
        {
            if ($description -ne $null)
            {
                $Selection.typetext($description)
            }

            $Range = $Selection.Range()
            $Table = $doc.Tables.Add($Range, $rowcount, $columncount) #|Out-Null
            $Table.Range.Style = ($ReportStyles.Font.Where{$_.name -eq "TableStyle"}).Style

            $cols = $dataTable.Columns | sort Ordinal | select ColumnName
            $coliterator = 1
            $cols | % {
                $Table.Cell(1, $coliterator).Range.Text = $_.ColumnName
                $coliterator ++
            }

            #for each row returned

            $x = 2
            $dataTable | % {
                $row = $_
                #for each column
                $coliterator = 1
                $cols | % {
                    [string]$val = $row[$_.ColumnName]
                    $Table.Cell($x, $coliterator).Range.Text = $val
                    $coliterator ++
                }
                $x += 1
            }
           # $Selection.typeparagraph()   
            $Selection.EndKey(6)|Out-Null
        }
        else {
            $Selection.Font.Color = [int]($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontColor
            $Selection.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontName
            $Selection.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontSize
            $Selection.TypeText(($ReportFixedText.Value.Where{$_.name -eq "EmptyWordTable"}).InnerText)
            $Selection.TypeParagraph() 
        }
        $cn.Close()
    }
    catch
    {
        $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0] + " Line Number: " + $MyInvocation.ScriptLineNumber + `
            " Offset: " + $MyInvocation.OffsetInLine

        Write-Log -Message $errormsg -Path $logfile -Level Error
        $Variables = Get-Variable -Scope Local 
        write-UserVariablesToLog -Variables $Variables -LogFile $logfile -Category "UserVariables"     

        $ErrorActionPreference = "continue"
    }
}

<#
Tim Chapman
Add header document to Word report.

#>
function get-ExecutiveSummary
{
    param(
    $ServerName, 
    $DBName,
    $ReportType
    )

    if($ReportType -eq "Memory")
    {
        $query= "EXECUTE ExecutiveSummary_Memory"        
    }
    if($ReportType -eq "CPU")
    {
        $query= "EXECUTE ExecutiveSummary_CPU"
    }
    if($ReportType -eq "Disk")
    {
        $query= "EXECUTE ExecutiveSummary_Disk"
    }
    if($ReportType -eq "Concurrency")
    {
        $query= "EXECUTE ExecutiveSummary_Concurrency"
    }

    $cn = new-object System.Data.SqlClient.SqlConnection "server=$ServerName;database=$DatabaseName;Integrated Security=sspi"

    $dataSet = new-object "System.Data.DataSet" 

    #Create a SQL Data Adapter to place the resultset into the DataSet
    $dataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($query, $cn) 

    $dataAdapter.Fill($dataSet) | Out-Null

    $dataTable = new-object "System.Data.DataTable"
    $dataTable = $dataSet.Tables[0]

    $dataTable.Msg
}

function Add-DocHeaderSource
{
    param
    (
        $FilePath,
        $DocHeaderSourcePath
    )

    try
    {
        #need to open 2 files and swap them

        $Word = New-Object -ComObject Word.application
        $WordDoc = $Word.Documents.add()

        $WordSource = New-Object -ComObject Word.application
        $WordSource.visible = $false

        $DocHeaderSource = $WordSource.Documents.Open($DocHeaderSourcePath, $false, $true)

        $Range = $DocHeaderSource.Range()
        $copy = $Range.Copy()

        $Range2 = $WordDoc.Range()
        $Range2.Paste($copy)

        [ref]$SaveFormat = "microsoft.office.interop.Word.WdSaveFormat" -as [type]

        $WordDoc.saveas([ref] $FilePath, [ref]$saveFormat::wdFormatDocument)
        $Word.Application.Quit()
        $WordSource.Application.Quit()
    }
    catch
    {
        $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0] + " Line Number: " + $MyInvocation.ScriptLineNumber + `
            " Offset: " + $MyInvocation.OffsetInLine

        Write-Log -Message $errormsg -Path $logfile -Level Error
        $Variables = Get-Variable -Scope Local 
        write-UserVariablesToLog -Variables $Variables -LogFile $logfile -Category "UserVariables"    
        $ErrorActionPreference = "continue"
    }
}


function Add-DocFooter
{
    param
    (
        $FilePath,
        $footerFilePath
    )

    try
    {
        $HeaderFooterIndex = "microsoft.office.interop.word.WdHeaderFooterIndex" -as [type]
        $BreakType = "microsoft.office.interop.word.WdBreakType" -as [type]
        $AlignmentTab = "microsoft.office.interop.word.WdAlignmentTabAlignment" -as [type]
        $ParagraphAlignment = "microsoft.office.interop.word.WdParagraphAlignment" -as [type]
        $Units = "microsoft.office.interop.word.WdUnits" -as [type]
        $PageNumberAlignment = "microsoft.office.interop.word.WdPageNumberAlignment" -as [type]
        $PageNumberStyle = "microsoft.office.interop.word.wdPageNumberStyle" -as [type]
        $Color = "microsoft.office.interop.word.wdColor" -as [type]

        $Word = New-Object -ComObject Word.application
        $WordDoc = $Word.Documents.Open($FilePath, $false, $false)

        $WordSource = New-Object -ComObject Word.application
        $WordSource.visible = $false

        $DocHeaderSource = $WordSource.Documents.Open($footerFilePath, $false, $true)

        $Selection = $Word.selection
        #$Selection.typeparagraph()

        #$Selection.typeparagraph()   
        $Selection.EndKey(6)|Out-Null
        $Range2 = $Selection.range()
        $Range2.InsertBreak()
        $Selection.typeparagraph()   
        $Selection.EndKey(6)|Out-Null
        $Range = $DocHeaderSource.Range()
        $copy = $Range.Copy()

        $Range2.Paste($copy)

        [ref]$SaveFormat = "microsoft.office.interop.Word.WdSaveFormat" -as [type]

        $WordDoc.saveas([ref] $FilePath, [ref]$saveFormat::wdFormatDocument)
        $Word.Application.Quit()
        $WordSource.Application.Quit()
    }
    catch
    {
        $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0] + " Line Number: " + $MyInvocation.ScriptLineNumber + `
            " Offset: " + $MyInvocation.OffsetInLine

        Write-Log -Message $errormsg -Path $logfile -Level Error
        $Variables = Get-Variable -Scope Local 
        write-UserVariablesToLog -Variables $Variables -LogFile $logfile -Category "UserVariables"     
    }
}

##Need to pass perfmon object to this report so I can grab the chart location for 
##graphs i want to add based on rules violated.

function create-FindingsReport
{
    param
    (
        $ServerName, 
        $DatabaseName, 
        [string]$FilePath, 
        $logfile = "", 
        $SummaryData
    )

    try
    {
        [xml]$rules = Get-Content ".\Configuration\Rules.xml"

        $cn = new-object System.Data.SqlClient.SqlConnection "server=$ServerName;database=$DatabaseName;Integrated Security=sspi"
        $query = "SELECT Title, CapturedValue = ISNULL(Reading,'') FROM PTOClinicFindings"

        $dataSet = new-object "System.Data.DataSet" 

        #Create a SQL Data Adapter to place the resultset into the DataSet
        $dataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($query, $cn) 

        $dataAdapter.Fill($dataSet) | Out-Null

        $dataTable = new-object "System.Data.DataTable"
        $dataTable = $dataSet.Tables[0]
        $RuleList = $rules.IssuesList.PTOClinicIssue|Where-Object {$_.enabled -eq "true"}

        [ref]$SaveFormat = "microsoft.office.interop.Word.WdSaveFormat" -as [type]

        $location = Get-Location
        $DocHeaderSourcePath = join-path $location "\Docs\Begin_Banner.docx"
        $docfooterpath = join-path $location "\Docs\End_PerfCounters.docx"

        Add-DocHeaderSource -FilePath $FilePath -DocHeaderSourcePath $DocHeaderSourcePath

        #AddCoverPage
        $Word = New-Object -ComObject Word.application
        ##$Word.visible = $False
        $WordDoc = $Word.documents.open($FilePath)

        $Selection = $Word.selection
        $Selection.EndKey(6)|Out-Null
        $Range = $Selection.range()
        $Range.InsertBreak(7)
        $Selection.EndKey(6)|Out-Null


        $ContentsSelection = $Word.selection
        $ContentsSelection.Font.Name = "Calibri"

        $ContentsSelection.Font.Size = "16"
        $ContentsSelection.typetext("Contents")
        $ContentsSelection.TypeParagraph() 
        $TocRange = $ContentsSelection.Range()
        $toc = $WordDoc.TablesOfContents.Add($TocRange)
        #$toc.UseHyperLinks = 1
        $ContentsSelection.TypeParagraph()    
        $Word.Selection.Range.InsertBreak(7)         

        #call a proc and get this data summary
        #have ExecutiveSummary generate this.

        $ContentsSelection.EndKey(6)|Out-Null
        $SelectionSummary = $Word.selection
        $SelectionSummary.style = "Heading 1"
        $SelectionSummary.Font.Name = "Calibri"
        $SelectionSummary.Font.Size = 14
        $SelectionSummary.typetext("Overall Summary")
        $SelectionSummary.typeparagraph()

        $SelectionSummary.style = "Heading 2"
        $SelectionSummary.Font.Name = "Calibri"
        $SelectionSummary.Font.Size = 14
        $SelectionSummary.typetext("CPU")
        $SelectionSummary.typeparagraph()
        $SelectionSummary.typeparagraph()

        $SelectionSummary.style = "Heading 2"
        $SelectionSummary.Font.Name = "Calibri"
        $SelectionSummary.Font.Size = 14
        $SelectionSummary.typetext("Disk")
        $SelectionSummary.typeparagraph()
        $SelectionSummary.typeparagraph()

        $SelectionSummary.style = "Heading 2"        
        $SelectionSummary.Font.Name = "Calibri"
        $SelectionSummary.Font.Size = 14
        $SelectionSummary.typetext("Memory")

        #call a proc there to grab the overview
        $MemorySummary =  get-ExecutiveSummary -ServerName $ServerName -DBName $DatabaseName -ReportType "Memory"

        $SelectionSummary.typeparagraph()
        foreach($MemSumVal in $MemorySummary)
        {
            $SelectionSummary.typetext($MemSumVal)
            $SelectionSummary.typeparagraph()
        }

        $SelectionSummary.style = "Heading 2"        
        $SelectionSummary.Font.Name = "Calibri"
        $SelectionSummary.Font.Size = 14
        $SelectionSummary.typetext("Concurrency")
        $SelectionSummary.typeparagraph()
        #$SelectionSummary.typeparagraph()


        $SelectionSummary.Range.InsertBreak(7)      
        $SelectionSummary.EndKey(6)|Out-Null

        $Selection = $Word.selection
        $Selection.style = "Heading 1"
        $Selection.Font.Name = "Calibri"
        $Selection.Font.Size = 16
        $Selection.typetext("System Information")
        $Selection.typeparagraph()        
        $Selection.EndKey(6)|Out-Null

        [xml]$DataLogic = Get-Content ".\Configuration\DataLogic.xml"
        $Reports = $DataLogic.root.OutputReportProcedures.Procedure

        foreach ($ReportProc in $Reports)
        {
            $ReportProcName = $ReportProc.Name
            $ReportHeader = $ReportProc.Heading
            $ReportDesc = $ReportProc.Description

            Add-TableToWordDoc -ServerName $ServerName -DatabaseName $DatabaseName -doc $WordDoc -logfile $logfile -sql $ReportProcName -selection $Selection -heading $ReportHeader -description $ReportDesc
            $Selection.InsertBreak(7)            
        }

        $Selection = $Word.selection  
        $Selection.EndKey(6)|Out-Null

        $SelectionFindings = $Word.selection
        $SelectionFindings.style = "Heading 1"
        $SelectionFindings.Font.Name = "Calibri"
        $SelectionFindings.Font.Size = 16
        $SelectionFindings.typetext("Findings Report")
        $SelectionFindings.typeparagraph()

        $Selection = $Word.selection
        $Selection.font.size = 11
        $Selection.font.bold = 0        
        $SelectionFindings.typetext("The following issues were identified from the data collected via the pssdiag.")
        $Selection.font.size = 12

        $dataTable | ForEach-Object {

            $CapturedIssue = $_.Title
            $CapturedValue = $_.CapturedValue

            $CurrentRule = $RuleList|Where-Object {$_.Title -eq $CapturedIssue}
            $CounterGraphs = $CurrentRule.Counters

            if ($CurrentRule.Title)
            {
                $Title = $CurrentRule.Title
                $Category = $CurrentRule.Category
                $Severity = $CurrentRule.Severity
                $Impact = $CurrentRule.Impact.'#cdata-section'
                $Recommendation = $CurrentRule.Recommendation.'#cdata-section'
                $Reading = $CurrentRule.Reading.'#cdata-section'

                $Title = $Title.Replace("'", "''").trim()
                $Category = $Category.Replace("'", "''").trim()
                $Severity = $Severity.Replace("'", "''").trim()
                $Impact = $Impact.Replace("'", "''").trim()
                $Recommendation = $Recommendation.Replace("'", "''").trim()
                $Reading = $Reading.Replace("'", "''").trim()

                $Range = $null
                $Range = $Selection.Range()
                $Table = $null
                $Table = $Worddoc.Tables.Add($Range, 1, 1) #|Out-Null

                $Selection.EndKey(6)|Out-Null
                $Table.Range.Style = "Medium Shading 1 - Accent 1"  

                $rowcount = 0
                if ($Title.Length -gt 0)
                {
                    $rowcount ++
                    $Table.Rows.Add()|Out-Null
                    $Table.Cell($rowcount, 1).Range.Text = $Title
                    $Table.Cell($rowcount, 1).Range.Font.Bold = $True
                    $Table.Cell($rowcount, 1).Range.Font.Size = 14               
                }

                if ($Impact.Length -gt 0)
                {
                    $rowcount ++
                    $Table.Rows.Add()|Out-Null
                    $Table.Cell($rowcount, 1).Range.Text = "Impact"               
                    $Table.Cell($rowcount, 1).Range.Font.Bold = $True
                    $Table.Cell($rowcount, 1).Range.Font.Size = 11
        
                    $rowcount ++
                    $Table.Rows.Add()|Out-Null
                    $Table.Cell($rowcount, 1).Range.Text = $Impact
                    $Table.Cell($rowcount, 1).Range.Font.Bold = $false
                    $Table.Cell($rowcount, 1).Range.Font.Size = 11
                }


                if ($Recommendation.Length -gt 0)
                {

                    $rowcount ++
                    $Table.Rows.Add()|Out-Null
                    $Table.Cell($rowcount, 1).Range.Text = "Recommendation"
                    $Table.Cell($rowcount, 1).Range.Font.Bold = $true
                    $Table.Cell($rowcount, 1).Range.Font.Size = 11

                    $rowcount ++
                    $Table.Rows.Add()|Out-Null        
                    $Table.Cell($rowcount, 1).Range.Text = $Recommendation
                    $Table.Cell($rowcount, 1).Range.Font.Bold = $false
                    $Table.Cell($rowcount, 1).Range.Font.Size = 11
                }

                if ($Reading.Length -gt 0)
                {

                    $rowcount ++
                    $Table.Rows.Add()|Out-Null
                    $Table.Cell($rowcount, 1).Range.Text = "Reading"
                    $Table.Cell($rowcount, 1).Range.Font.Bold = $true
                    $Table.Cell($rowcount, 1).Range.Font.Size = 11

                    $rowcount ++
                    $Table.Rows.Add()|Out-Null
                    $Table.Cell($rowcount, 1).Range.text = $Reading
                    $Table.Cell($rowcount, 1).Range.Font.Bold = $false
                    $Table.Cell($rowcount, 1).Range.Font.Size = 11

                }

                if ($CapturedValue.Length -gt 0)
                {

                    $rowcount ++
                    $Table.Rows.Add()|Out-Null
                    $Table.Cell($rowcount, 1).Range.Text = "Findings From Capture"
                    $Table.Cell($rowcount, 1).Range.Font.Bold = $true
                    $Table.Cell($rowcount, 1).Range.Font.Size = 11

                    $rowcount ++
                    $Table.Rows.Add()|Out-Null
                    $Table.Cell($rowcount, 1).Range.text = $CapturedValue
                    $Table.Cell($rowcount, 1).Range.Font.Bold = $false
                    $Table.Cell($rowcount, 1).Range.Font.Size = 11
                    $Table.Cell($rowcount, 1).Range.Shading.BackgroundPatternColor = 65535
                }

                <#
            If there are counters associated with the findings, then add data for those counters
            to the word doc.
            #>
                if ($CounterGraphs)
                {
                    $rowcount ++
                    $Table.Rows.Add()|Out-Null
                    $Table.Cell($rowcount, 1).Range.Text = "Graphs"
                    $Table.Cell($rowcount, 1).Range.Font.Bold = $true
                    $Table.Cell($rowcount, 1).Range.Font.Size = 11

                    foreach ($Graph in $CounterGraphs)
                    {
                        $Imagepath = $SummaryData|Where-Object {$_.LookupPath -eq $Graph.Counter}|select {$_.Imagepath}
                        if ($Imagepath.'$_.Imagepath' -gt "")
                        {
                            $rowcount ++
                            $Table.Rows.Add()|Out-Null
                            $picout = $Table.Cell($rowcount, 1).Range.InlineShapes.AddPicture($Imagepath.'$_.Imagepath') 
                            $Table.Cell($rowcount, 1).Range.Font.Bold = $false
                            $Table.Cell($rowcount, 1).Range.Font.Size = 11
                            #$Table.Cell($rowcount,1).Range.Shading.BackgroundPatternColor = 65535
                        }
                    }

                }
                $Selection.EndKey(6)|Out-Null
                $Range.InsertBreak()

            }
        }
        #$toc.Update()
    }
    catch
    {    
        $errormsg = 'Error in :' + $MyInvocation.MyCommand + ' ' + $Error[0] + " Line Number: " + $MyInvocation.ScriptLineNumber + `
            " Offset: " + $MyInvocation.OffsetInLine + " FilePath: " + $FilePath

        Write-Log -Message $errormsg -Path $logfile -Level Error
        continue 
    }

    $WordDoc.saveas([ref] $FilePath, [ref]$saveFormat::wdFormatDocument)
    $WordDoc.saveas()
    $Word.Application.Quit()

    Add-DocFooter -FilePath $FilePath -footerFilePath $docfooterpath

    #update TOC
    $Word = New-Object -ComObject Word.application
    $WordDoc = $Word.documents.open($FilePath)
    $toc = $WordDoc.TablesOfContents
    $toc.item(1).Update()
    
    $WordDoc.saveas()
    $Word.Application.Quit()
}

<###################################################################################################
###################################################################################################>
##Need to pass perfmon object to this report so I can grab the chart location for 
##graphs i want to add based on rules violated.
<##>


#set-location "C:\Users\Administrator\Documents\WindowsPowerShell\Modules\SQLAnalyzer"
#create-FindingsReportUsingLayout -ServerName "Analysis" -DatabaseName "rr4" -FilePath "C:\PSSDiagExporter\rr4\rr4.docx" -LogFile "C:\PSSDiagExporter\rr4\drew9.log" -CollectUserCustomerInfo 0

