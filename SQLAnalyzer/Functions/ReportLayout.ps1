##Set-Location C:\SQLAnalyzer
<#
 Tim Chapman
 #>
#. .\Functions\Logger.ps1
#. .\Functions\CustomerReadyEmail_Pretty.ps1

<###################################################################################################
###################################################################################################>
##Need to pass perfmon object to this report so I can grab the chart location for 
##graphs i want to add based on rules violated.
function create-FindingsReportUsingLayout
{
    param
    (
        $ServerName, 
        $DatabaseName, 
        [string]$FilePath, 
        $logfile = "", 
        $SummaryData, 
        $CollectUserCustomerInfo = 0, 
        $SQLType
    )

   
        $cn = new-object System.Data.SqlClient.SqlConnection "server=$ServerName;database=$DatabaseName;Integrated Security=sspi"
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand
        $sqlCommand.Connection = $cn
        $query = "SELECT Title, CapturedValue = ISNULL(Reading,'') FROM PTOClinicFindings"

        $dataSet = new-object "System.Data.DataSet" 

        #Create a SQL Data Adapter to place the resultset into the DataSet
        $dataAdapter = new-object "System.Data.SqlClient.SqlDataAdapter" ($query, $cn) 

        $dataAdapter.Fill($dataSet) | Out-Null

        if($dataSet.Tables[0].Rows.Count -gt 0)
        {
            try
            {
        
        
                $ReportSteps = @(
                    "GenerateFindingsReport - Adding main page", 
                    "GenerateFindingsReport - Adding legal advice",
                    "GenerateFindingsReport - Adding TOC",
                    "GenerateFindingsReport - Adding Summary",
                    "GenerateFindingsReport - Adding Memory Summary",
                    "GenerateFindingsReport - Adding Environment Tables",
                    "GenerateFindingsReport - Adding issues",
                    "GenerateFindingsReport - Adding the footer document",
                    "GenerateFindingsReport - Updating TOC")
        
                $CurrentReportStep = 0
        
                $HeaderFooterIndex = "microsoft.office.interop.word.WdHeaderFooterIndex" -as [type]
                #$BreakType = "microsoft.office.interop.word.WdBreakType" -as [type]
                $AlignmentTab = "microsoft.office.interop.word.WdAlignmentTabAlignment" -as [type]
                $ParagraphAlignment = "microsoft.office.interop.word.WdParagraphAlignment" -as [type]
                #$Units = "microsoft.office.interop.word.WdUnits" -as [type]
                $PageNumberAlignment = "microsoft.office.interop.word.WdPageNumberAlignment" -as [type]
                $PageNumberStyle = "microsoft.office.interop.word.wdPageNumberStyle" -as [type]
                $Color = "microsoft.office.interop.word.wdColor" -as [type]
        
                
                if($psISE -eq $null) {
                #$CurrentLocation = split-path $PSCommandPath -Parent
                    #set-location "C:\Users\Administrator\Documents\WindowsPowerShell\Modules\SQLAnalyzer"
                    $CurrentLocation = get-location
                }
                else {
                    if($psISE.CurrentFile.FullPath) {
                        $CurrentLocation = split-path $psISE.CurrentFile.FullPath -parent
                    }
                    else {
                        $CurrentLocation = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent
                    }
                }
        
                [xml]$rules = Get-Content ".\Configuration\Rules.xml"
                [xml]$datalogic = Get-Content ".\Configuration\DataLogic.xml"
        
                $ReportStyles = $datalogic.root.ReportStyles
                $ReportFixedText = $datalogic.root.ReportFixedTexts
    
        #$query = "SELECT [PropertyValue] FROM [dbo].[tbl_ServerProperties] WHERE [PropertyName] LIKE 'SQLServerName'"
        $query = "EXECUTE AppGetServerInstanceName"
        $sqlCommand.CommandText = $query
        $cn.Open()
        $InstanceName = $sqlCommand.ExecuteScalar();
        $cn.Close()

        $dataTable = new-object "System.Data.DataTable"
        $dataTable = $dataSet.Tables[0]
        $RuleList = $rules.IssuesList.PTOClinicIssue|Where-Object {$_.enabled -eq "true"}

        [ref]$SaveFormat = "microsoft.office.interop.Word.WdSaveFormat" -as [type]

        $location = Get-Location
        $docfooterpath = join-path $location "\Docs\End_PerfCounters.docx"
        $mainbannerpath = join-path $location "\Docs\MainBanner.png"
        $headerlogopath = join-path $location "\Docs\Microsoft.png"

        #AddCoverPage
        $Word = New-Object -ComObject Word.application
        $Word.visible = $false
        $WordDoc = $Word.Documents.Add() ##.Open($FilePath)

        Write-Log -Message $ReportSteps[$CurrentReportStep] -Path $logfile
        #Write-Progress -Activity "Creating Word document report: $($ReportSteps[$CurrentReportStep])" -Status "Percent completed: $([int](($CurrentReportStep/$ReportSteps.Length)*100))%" -PercentComplete (($CurrentReportStep/$ReportSteps.Length)*100)
        $CurrentReportStep++
        $Selection = $Word.Selection
        $Selection.Range.InlineShapes.AddPicture("$mainbannerpath") | Out-Null
        #$Selection.typeparagraph()   
        $Selection.EndKey(6)|Out-Null

        ## Add main page texts
        $Selection = $Word.selection
        #$Selection.TypeParagraph()
        $Selection.Font.Color = [int]($ReportStyles.Font.Where{$_.name -eq "DocumentTitle"}).FontColor
        $Selection.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "DocumentTitle"}).FontName
        $Selection.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "DocumentTitle"}).FontSize
        $Selection.TypeText(($ReportFixedText.Value.Where{$_.name -eq "DocumentTitle"}).InnerText)
        $Selection.TypeParagraph() 

        if ($CollectUserCustomerInfo -eq 1)
        {
            Write-Host "Collecting User and Customer Information for the Report..."
            $PFEName = Read-Host "`tPFE name"
            $Email = Read-Host "`tYour e-mail"
            $TAMName =Read-Host "`tTAM name"
            $CustomerName = Read-Host "`tCustomer name"

            $Selection.Font.Color = ($ReportStyles.Font.Where{$_.name -eq "DocumentSubtitle"}).FontColor
            $Selection.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "DocumentSubtitle"}).FontName
            $Selection.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "DocumentSubtitle"}).FontSize
            $Selection.TypeText($CustomerName)
            $Selection.TypeParagraph() 

            $Selection.Font.Color = ($ReportStyles.Font.Where{$_.name -eq "DocumentCoverText"}).FontColor
            $Selection.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "DocumentCoverText"}).FontName
            $Selection.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "DocumentCoverText"}).FontSize
            $Selection.TypeText(($ReportFixedText.Value.Where{$_.name -eq "PreparedBy"}).InnerText)
            $Selection.TypeText($PFEName)
            $Selection.TypeParagraph() 

            $Selection.Font.Color = ($ReportStyles.Font.Where{$_.name -eq "DocumentCoverText"}).FontColor
            $Selection.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "DocumentCoverText"}).FontName
            $Selection.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "DocumentCoverText"}).FontSize
            $Selection.TypeText($EMail)
            $Selection.TypeParagraph() 

            $Selection.Font.Color = ($ReportStyles.Font.Where{$_.name -eq "DocumentCoverText"}).FontColor
            $Selection.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "DocumentCoverText"}).FontName
            $Selection.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "DocumentCoverText"}).FontSize
            $Selection.TypeText(($ReportFixedText.Value.Where{$_.name -eq "TAMName"}).InnerText)
            $Selection.TypeText($TAMName)
            $Selection.TypeParagraph() 
        }
            $Selection.Paragraphs.Alignment = $ParagraphAlignment::wdAlignParagraphRight
            $Selection.Font.Color = ($ReportStyles.Font.Where{$_.name -eq "DocumentCoverText"}).FontColor
            $Selection.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "DocumentCoverText"}).FontName
            $Selection.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "DocumentCoverText"}).FontSize
            $Selection.TypeText(($ReportFixedText.Value.Where{$_.name -eq "DateOfCreation"}).InnerText)
            $Selection.TypeText((Get-Date).ToString("yyyy-MM-dd"))
            $Selection.TypeParagraph() 
    
        
        $Selection.Paragraphs.Alignment = $ParagraphAlignment::wdAlignParagraphLeft
        $Selection.InsertBreak()

        ## Add legal page advice header 
        Write-Log -Message $ReportSteps[$CurrentReportStep] -Path $logfile
        #Write-Progress -Activity "Creating Word document report: $($ReportSteps[$CurrentReportStep])" -Status "Percent completed: $([int](($CurrentReportStep/$ReportSteps.Length)*100))%" -PercentComplete (($CurrentReportStep/$ReportSteps.Length)*100)
        $CurrentReportStep++
        $Header = $WordDoc.Sections.Last.Headers.Item(1)
        #$Header = $WordDoc.Headers.Item(1)
        $Header.LinkToPrevious = $false
        $Header.Range.InsertAlignmentTab($alignmentTab::wdCenter)
        $Header.Range.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "Header"}).FontName
        $Header.Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "Header"}).FontSize
        $Header.Range.Text = ($ReportFixedText.Value.Where{$_.name -eq "Header1"}).InnerText
        $Header.Range.InlineShapes.AddPicture("$headerlogopath") |Out-Null
        $Selection.TypeParagraph()   
        $Selection.EndKey(6)|Out-Null
       
        ## Add legal advice
        $ContentsSelection = $Word.selection
        $ContentsSelection.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontName
        $ContentsSelection.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontSize
        $ContentsSelection.TypeText(($ReportFixedText.Value.Where{$_.name -eq "LegalAdvice"}).InnerText)
        $ContentsSelection.TypeParagraph() 
        $Selection.InsertBreak()

        ## Add legal page advice footer 
        $Footer = $WordDoc.Sections.Last.Footers.Item(1)
        $Footer.LinkToPrevious = $false
        #$Footer.Range.InsertAlignmentTab($alignmentTab::wdRight)
        $Footer.Range.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "Footer"}).FontName
        $Footer.Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "Footer"}).FontSize
        $Footer.Range.Text = "" #($ReportFixedText.Value.Where{$_.name -eq "Footer1"}).InnerText
        $Footer.PageNumbers.Add("wdAlignPageNumberOutside") | Out-Null
        $Footer.PageNumbers.NumberStyle = $PageNumberStyle::wdPageNumberStyleLowercaseRoman


        $Selection.EndKey(6)|Out-Null
        #$Word.Selection.Range.InsertBreak()
        ## Remove legal page advice header for the following section
        #$Header = $WordDoc.Sections.Last.Headers.Item(1)
        #$Header.LinkToPrevious = $false
        #$Header.Range.Text = ""

        ## Add TOC
        Write-Log -Message $ReportSteps[$CurrentReportStep] -Path $logfile
        #Write-Progress -Activity "Creating Word document report: $($ReportSteps[$CurrentReportStep])" -Status "Percent completed: $([int](($CurrentReportStep/$ReportSteps.Length)*100))%" -PercentComplete (($CurrentReportStep/$ReportSteps.Length)*100)
        $CurrentReportStep++
        $ContentsSelection = $Word.selection

        $ContentsSelection.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "TOCTitle"}).FontName
        $ContentsSelection.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "TOCTitle"}).FontSize
        $ContentsSelection.Font.Color = ($ReportStyles.Font.Where{$_.name -eq "TOCTitle"}).FontColor
        $ContentsSelection.Font.Bold = ($ReportStyles.Font.Where{$_.name -eq "TOCTitle"}).FontBold
        $ContentsSelection.typetext(($ReportFixedText.Value.Where{$_.name -eq "TOCTitle"}).InnerText)

        $ContentsSelection.TypeParagraph() 
        $ContentsSelection.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontName
        $ContentsSelection.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontSize
        $TocRange = $ContentsSelection.Range()
        $toc = $WordDoc.TablesOfContents.Add($TocRange)
        $toc.UseHyperLinks = $True

        #$ContentsSelection.TypeParagraph()    
        #$Word.Selection.Range.InsertBreak()
        $ContentsSelection.EndKey(6) | Out-Null

        #call a proc and get this data summary
        #have ExecutiveSummary generate this.
        $SelectionSummary = $Word.selection

        #region Summary title
        Write-Log -Message $ReportSteps[$CurrentReportStep] -Path $logfile
        #Write-Progress -Activity "Creating Word document report: $($ReportSteps[$CurrentReportStep])" -Status "Percent completed: $([int](($CurrentReportStep/$ReportSteps.Length)*100))%" -PercentComplete (($CurrentReportStep/$ReportSteps.Length)*100)
        $CurrentReportStep++
        $SelectionSummary.Style = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel1"}).Style
        $SelectionSummary.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel1"}).FontName
        $SelectionSummary.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel1"}).FontSize
        $SelectionSummary.typetext(($ReportFixedText.Value.Where{$_.name -eq "SummaryTitle"}).InnerText)
        $SelectionSummary.typeparagraph()
        #endregion Summary title

        #region Summary text 1
        $SelectionSummary.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontName
        $SelectionSummary.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontSize

        if($CustomerName -eq $null)
        {
            $CustomerName = "Customer"
        }
        $SelectionSummary.typetext($CustomerName)
        $SelectionSummary.typetext(($ReportFixedText.Value.Where{$_.name -eq "SummaryText1"}).InnerText)
        $SelectionSummary.typeparagraph()
        #endregion Summary text 1

        #region Summary bulleted list 1
        $SelectionSummary.Range.ListFormat.ListIndent()
        $SelectionSummary.Range.ListFormat.ApplyBulletDefault()
        $SelectionSummary.typetext(($ReportFixedText.Value.Where{$_.name -eq "SummaryList1"}).InnerText)
        $SelectionSummary.typeparagraph()
        $SelectionSummary.Range.ListFormat.ApplyBulletDefault()
        $SelectionSummary.Range.ListFormat.ListOutdent()
        #endregion Summary bulleted list 1

        #region Summary text 2
        $SelectionSummary.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontName
        $SelectionSummary.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontSize
        if($SQLType -eq "AzureSQLDB")
        {
            $SelectionSummary.typetext(($ReportFixedText.Value.Where{$_.name -eq "SummaryText2SQLDB"}).InnerText)
        }
        elseif($SQLType -eq "AzureSQLManagedInstance")
        {
            $SelectionSummary.typetext(($ReportFixedText.Value.Where{$_.name -eq "SummaryText2SQLMI"}).InnerText)
        }
        else {
            $SelectionSummary.typetext(($ReportFixedText.Value.Where{$_.name -eq "SummaryText2"}).InnerText)
        }
        $SelectionSummary.typeparagraph()
        #endregion Summary text 2

        #region Summary bulleted list of instances
        $SelectionSummary.Range.ListFormat.ListIndent()
        $SelectionSummary.Range.ListFormat.ApplyBulletDefault()
        $SelectionSummary.typetext($InstanceName)
        $SelectionSummary.typeparagraph()
        $SelectionSummary.Range.ListFormat.ApplyBulletDefault()
        $SelectionSummary.Range.ListFormat.ListOutdent()
        #endregion Summary bulleted list of instances

        #region Executive Summary
        ## Summary text 3
        $SelectionSummary.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontName
        $SelectionSummary.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontSize
        $SelectionSummary.typetext(($ReportFixedText.Value.Where{$_.name -eq "SummaryText3"}).InnerText)
        $SelectionSummary.typeparagraph()
        
        #region Summary CPU
        $SelectionSummary.Style = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).Style
        $SelectionSummary.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).FontName
        $SelectionSummary.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).FontSize
        $SelectionSummary.typetext(($ReportFixedText.Value.Where{$_.name -eq "SummaryCPU"}).InnerText)

        $Summary =  get-ExecutiveSummary -ServerName $ServerName -DBName $DatabaseName -ReportType "CPU"

        $SelectionSummary.typeparagraph()
        $SelectionSummary = $Word.selection

        foreach($SumVal in $Summary)
        {
            $SelectionSummary.Style = "Normal"
            $SelectionSummary.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontName
            $SelectionSummary.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontSize
            $SelectionSummary.typetext($SumVal)
            $SelectionSummary.typeparagraph()
        }
        #endregion Summary CPU

        #region Summary Disk
        $SelectionSummary.Style = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).Style
        $SelectionSummary.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).FontName
        $SelectionSummary.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).FontSize
        $SelectionSummary.typetext(($ReportFixedText.Value.Where{$_.name -eq "SummaryDisk"}).InnerText)

        $DiskSummary =  get-ExecutiveSummary -ServerName $ServerName -DBName $DatabaseName -ReportType "Disk"

        $SelectionSummary.typeparagraph()
       # $Word.Selection.Range.InsertBreak()
        $SelectionSummary = $Word.selection

        foreach($DiskSumVal in $DiskSummary)
        {
            $SelectionSummary.Style = "Normal"
            $Selection.font.size = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontSize
            $Selection.font.Name = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontName  
            $SelectionSummary.typetext($DiskSumVal)
            $SelectionSummary.typeparagraph()
        }
        #$SelectionSummary.typeparagraph()
        #endregion Summary Disk

        #region Summary Memory
        $SelectionSummary.Style = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).Style
        $SelectionSummary.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).FontName
        $SelectionSummary.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).FontSize
        $SelectionSummary.typetext(($ReportFixedText.Value.Where{$_.name -eq "SummaryMemory"}).InnerText)
        

        Write-Log -Message $ReportSteps[$CurrentReportStep] -Path $logfile
        #Write-Progress -Activity "Creating Word document report: $($ReportSteps[$CurrentReportStep])" -Status "Percent completed: $([int](($CurrentReportStep/$ReportSteps.Length)*100))%" -PercentComplete (($CurrentReportStep/$ReportSteps.Length)*100)
        $CurrentReportStep++

        $MemorySummary =  get-ExecutiveSummary -ServerName $ServerName -DBName $DatabaseName -ReportType "Memory"

        $SelectionSummary = $Word.selection
        $SelectionSummary.typeparagraph()

        foreach($MemSumVal in $MemorySummary)
        {
            $SelectionSummary.Style = "Normal"
            $Selection.font.size = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontSize
            $Selection.font.Name = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontName  
            $SelectionSummary.typetext($MemSumVal)
            $SelectionSummary.typeparagraph()
        }
        #endregion Summary Memory

        #region Summary Concurrency
        $SelectionSummary.Style = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).Style
        $SelectionSummary.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).FontName
        $SelectionSummary.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).FontSize
        $SelectionSummary.typetext(($ReportFixedText.Value.Where{$_.name -eq "SummaryConcurrency"}).InnerText)

        $ConcurrencySummary =  get-ExecutiveSummary -ServerName $ServerName -DBName $DatabaseName -ReportType "Concurrency"

        $SelectionSummary.typeparagraph()
       # $Word.Selection.Range.InsertBreak()
        $SelectionSummary = $Word.selection

        foreach($ConcurrencySumVal in $ConcurrencySummary)
        {
            $SelectionSummary.Style = "Normal"
            $Selection.font.size = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontSize
            $Selection.font.Name = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontName  
            $SelectionSummary.typetext($ConcurrencySumVal)
            $SelectionSummary.typeparagraph()
        }

        #endregion Summary Concurrency
        
        #endregion Executive Summary

        $Word.Selection.Range.InsertBreak()
        $Selection.EndKey(6)|Out-Null
        

        $Selection = $Word.selection
        $Selection.Style = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel1"}).Style
        $Selection.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel1"}).FontName
        $Selection.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel1"}).FontSize
        $Selection.typetext("System Information")
        #$Selection.typeparagraph()        
        $Selection.typeparagraph()   
        $Selection.EndKey(6)|Out-Null

        [xml]$DataLogic = Get-Content ".\Configuration\DataLogic.xml"
        $Reports = $DataLogic.root.OutputReportProcedures.Procedure

        Write-Log -Message $ReportSteps[$CurrentReportStep] -Path $logfile
       # Write-Progress -Activity "Creating Word document report: $($ReportSteps[$CurrentReportStep])" -Status "Percent completed: $([int](($CurrentReportStep/$ReportSteps.Length)*100))%" -PercentComplete (($CurrentReportStep/$ReportSteps.Length)*100)
        $CurrentReportStep++
        foreach ($ReportProc in $Reports)
        {
            $ReportProcName = $ReportProc.Name
            $ReportHeader = $ReportProc.Heading
            $ReportDesc = $ReportProc.Description

            Add-TableToWordDoc -ServerName $ServerName -DatabaseName $DatabaseName -doc $WordDoc -logfile $logfile -sql $ReportProcName -selection $Selection -heading $ReportHeader -description $ReportDesc
            $Selection.InsertBreak()
        }

        $Selection = $Word.selection  
        $Selection.EndKey(6)|Out-Null

        $SelectionFindings = $Word.selection
        $SelectionFindings.Style = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel1"}).Style
        $SelectionFindings.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel1"}).FontName
        $SelectionFindings.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel1"}).FontSize
        $SelectionFindings.typetext("Findings Report")
        $SelectionFindings.typeparagraph()

        $Selection = $Word.selection
        $Selection.font.size = ($ReportStyles.Font.Where{$_.name -eq "Annotation"}).FontSize
        $Selection.font.Name = ($ReportStyles.Font.Where{$_.name -eq "Annotation"}).FontName
        $Selection.font.bold = ($ReportStyles.Font.Where{$_.name -eq "Annotation"}).FontBold        
        $SelectionFindings.typetext("The following issues were identified from the data collected via the pssdiag.")
        $Selection.font.size = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontSize
        $Selection.typeparagraph()

        $RulesFired = @()

        Write-Log -Message $ReportSteps[$CurrentReportStep] -Path $logfile
        #Write-Progress -Activity "Creating Word document report: $($ReportSteps[$CurrentReportStep])" -Status "Percent completed: $([int](($CurrentReportStep/$ReportSteps.Length)*100))%" -PercentComplete (($CurrentReportStep/$ReportSteps.Length)*100)
        $CurrentReportStep++
        $dataTable | ForEach-Object {
            $CapturedIssue = $_.Title
            $CapturedValue = $_.CapturedValue

            $CurrentRule = $RuleList|Where-Object {$_.Title -eq $CapturedIssue}
            $CounterGraphs = $CurrentRule.Counters

            if ($CurrentRule.Title)
            {
                $Title = $CurrentRule.Title.Replace("'", "''").trim()
                $Category = $CurrentRule.Category.Replace("'", "''").trim()
                $Severity = $CurrentRule.Severity.Replace("'", "''").trim()
                $Impact = $CurrentRule.Impact.InnerText.Replace("'", "''").trim()
                $Recommendation = $CurrentRule.Recommendation.InnerText.Replace("'", "''").trim()
                $Reading = $CurrentRule.Reading.InnerText.Replace("'", "''").trim()

                $CurrentRule = New-Object System.Object
                $CurrentRule | Add-Member -MemberType NoteProperty -Name "Title" -Value $Title
                $CurrentRule | Add-Member -MemberType NoteProperty -Name "Category" -Value $Category
                $CurrentRule | Add-Member -MemberType NoteProperty -Name "Severity" -Value $Severity
                $CurrentRule | Add-Member -MemberType NoteProperty -Name "Impact" -Value $Impact
                $CurrentRule | Add-Member -MemberType NoteProperty -Name "Recommendation" -Value $Recommendation
                $CurrentRule | Add-Member -MemberType NoteProperty -Name "Reading" -Value $Reading
                $CurrentRule | Add-Member -MemberType NoteProperty -Name "CapturedValue" -Value $CapturedValue
                $CurrentRule | Add-Member -MemberType NoteProperty -Name "CounterGraphs" -Value $CounterGraphs

                $RulesFired += $CurrentRule
            }
        }

        $RulesFired = $RulesFired | Sort-Object -Property Category
        $CurrentCategory = ""
        $RulesFired | ForEach-Object {
            $Title = $_.Title
            $Category = $_.Category
            $Severity = $_.Severity
            $Impact = $_.Impact
            $Recommendation = $_.Recommendation
            $Reading = $_.Reading
            $CapturedValue = $_.CapturedValue

            if ($Category -ne $CurrentCategory){
                $SelectionSummary.Style = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).Style
                $SelectionSummary.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).FontName
                $SelectionSummary.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "SummaryLevel2"}).FontSize
                $SelectionSummary.typetext($Category)
                $SelectionSummary.typeparagraph()
                $SelectionSummary.Font.Color = [int]($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontColor
                $SelectionSummary.Font.Name = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontName
                $SelectionSummary.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "Normal"}).FontSize
                $CurrentCategory = $Category
            }

            $Range = $null
            $Range = $Selection.Range()
            $Table = $null
            $Table = $Worddoc.Tables.Add($Range, 1, 1) #|Out-Null

            ##$Selection.EndKey($Units::wdStory)|Out-Null
            $Table.Range.Style = ($ReportStyles.Font.Where{$_.name -eq "TableStyle"}).Style

            $rowcount = 0
            if ($Title.Length -gt 0)
            {
                $rowcount ++
                #$Table.Rows.Add()|Out-Null
                $Table.Cell($rowcount, 1).Range.Text = $Title
                $Table.Cell($rowcount, 1).Range.Font.Bold = ($ReportStyles.Font.Where{$_.name -eq "TableTitle"}).Bold
                $Table.Cell($rowcount, 1).Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "TableTitle"}).FontSize
            }

            if ($Impact.Length -gt 0)
            {
                $rowcount ++
                $Table.Rows.Add()|Out-Null
                $Table.Cell($rowcount, 1).Range.Text = "Impact"               
                $Table.Cell($rowcount, 1).Range.Font.Bold = ($ReportStyles.Font.Where{$_.name -eq "TableSubtitle"}).Bold
                $Table.Cell($rowcount, 1).Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "TableSubtitle"}).FontSize
        
                $rowcount ++
                $Table.Rows.Add()|Out-Null
                $Table.Cell($rowcount, 1).Range.Text = $_.Impact
                $Table.Cell($rowcount, 1).Range.Font.Bold = ($ReportStyles.Font.Where{$_.name -eq "TableText"}).Bold
                $Table.Cell($rowcount, 1).Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "TableText"}).FontSize
            }

            if ($Recommendation.Length -gt 0)
            {
                $rowcount ++
                $Table.Rows.Add()|Out-Null
                $Table.Cell($rowcount, 1).Range.Text = "Recommendation"
                $Table.Cell($rowcount, 1).Range.Font.Bold = ($ReportStyles.Font.Where{$_.name -eq "TableSubtitle"}).Bold
                $Table.Cell($rowcount, 1).Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "TableSubtitle"}).FontSize

                $rowcount ++
                $Table.Rows.Add()|Out-Null        
                $Table.Cell($rowcount, 1).Range.Text = $_.Recommendation
                $Table.Cell($rowcount, 1).Range.Font.Bold = ($ReportStyles.Font.Where{$_.name -eq "TableText"}).Bold
                $Table.Cell($rowcount, 1).Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "TableText"}).FontSize
            }

            if ($Reading.Length -gt 0)
            {
                $rowcount ++
                $Table.Rows.Add()|Out-Null
                $Table.Cell($rowcount, 1).Range.Text = "Reading"
                $Table.Cell($rowcount, 1).Range.Font.Bold = ($ReportStyles.Font.Where{$_.name -eq "TableSubtitle"}).Bold
                $Table.Cell($rowcount, 1).Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "TableSubtitle"}).FontSize

                $rowcount ++
                $Table.Rows.Add()|Out-Null
                $Table.Cell($rowcount, 1).Range.text = $_.Reading
                $Table.Cell($rowcount, 1).Range.Font.Bold = ($ReportStyles.Font.Where{$_.name -eq "TableText"}).Bold
                $Table.Cell($rowcount, 1).Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "TableText"}).FontSize
            }

            if ($CapturedValue.Length -gt 0)
            {
                $rowcount ++
                $Table.Rows.Add()|Out-Null
                $Table.Cell($rowcount, 1).Range.Text = "Findings From Capture"
                $Table.Cell($rowcount, 1).Range.Font.Bold = ($ReportStyles.Font.Where{$_.name -eq "TableSubtitle"}).Bold
                $Table.Cell($rowcount, 1).Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "TableSubtitle"}).FontSize

                $rowcount ++
                $Table.Rows.Add()|Out-Null
                $Table.Cell($rowcount, 1).Range.text = $CapturedValue
                $Table.Cell($rowcount, 1).Range.Font.Bold = ($ReportStyles.Font.Where{$_.name -eq "TableText"}).Bold
                $Table.Cell($rowcount, 1).Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "TableText"}).FontSize
                $Table.Cell($rowcount, 1).Range.Shading.BackgroundPatternColor = 65535
            }

            <#
        If there are counters associated with the findings, then add data for those counters
        to the word doc.
        #>
            if ($_.CounterGraphs)
            {
                $rowcount ++
                $Table.Rows.Add()|Out-Null
                $Table.Cell($rowcount, 1).Range.Text = "Graphs"
                $Table.Cell($rowcount, 1).Range.Font.Bold = ($ReportStyles.Font.Where{$_.name -eq "TableSubtitle"}).Bold
                $Table.Cell($rowcount, 1).Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "TableSubtitle"}).FontSize

                foreach ($Graph in $_.CounterGraphs)
                {
                    $Imagepath = $SummaryData|Where-Object {$_.LookupPath -eq $Graph.Counter}|select {$_.Imagepath}
                    if ($Imagepath.'$_.Imagepath' -gt "")
                    {
                        $rowcount ++
                        $Table.Rows.Add()|Out-Null
                        $picout = $Table.Cell($rowcount, 1).Range.InlineShapes.AddPicture($Imagepath.'$_.Imagepath') 
                        $Table.Cell($rowcount, 1).Range.Font.Bold = ($ReportStyles.Font.Where{$_.name -eq "TableText"}).Bold
                        $Table.Cell($rowcount, 1).Range.Font.Size = ($ReportStyles.Font.Where{$_.name -eq "TableText"}).FontSize
                        #$Table.Cell($rowcount,1).Range.Shading.BackgroundPatternColor = 65535
                    }
                }
            }
            #$Selection.typeparagraph()   
            $Selection.EndKey(6)|Out-Null
            $Selection.typeparagraph()   
            $Selection.InsertBreak()
            ##$Range.InsertBreak()
        }
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

        Write-Log -Message $ReportSteps[$CurrentReportStep] -Path $logfile
        #Write-Progress -Activity "Creating Word document report: $($ReportSteps[$CurrentReportStep])" -Status "Percent completed: $([int](($CurrentReportStep/$ReportSteps.Length)*100))%" -PercentComplete (($CurrentReportStep/$ReportSteps.Length)*100)
        $CurrentReportStep++
        Add-DocFooter -FilePath $FilePath -footerFilePath $docfooterpath

        #update TOC
        Write-Log -Message $ReportSteps[$CurrentReportStep] -Path $logfile
        #Write-Progress -Activity "Creating Word document report: $($ReportSteps[$CurrentReportStep])" -Status "Percent completed: $([int](($CurrentReportStep/$ReportSteps.Length)*100))%" -PercentComplete (($CurrentReportStep/$ReportSteps.Length)*100)
        $CurrentReportStep++
        $Word = New-Object -ComObject Word.application
        $WordDoc = $Word.documents.open($FilePath)
        $Word.visible = $false
        $toc = $WordDoc.TablesOfContents
        $toc.item(1).UseHyperLinks = $true
        $toc.item(1).Update()

        $WordDoc.saveas()
        $Word.Application.Quit()
    }
    else 
    {
        Write-Log -Message "No PTO Clinic Findings to put into report." -Path $logfile
    }
}

#set-location "C:\Users\Administrator\Documents\WindowsPowerShell\Modules\SQLAnalyzer"
#create-FindingsReportUsingLayout -ServerName "Analysis" -DatabaseName "rr4" -FilePath "C:\PSSDiagExporter\rr4\rr4.docx" -LogFile "C:\PSSDiagExporter\rr4\drew9.log" -CollectUserCustomerInfo 0

