#Written by Tim Chapman
#Used to input SQL Server and Database name for SQL Nexus upload
#Will skip import process if data isn't input

param
(
[string] $folderpath
)

$localroot = split-path $MyInvocation.MyCommand.path
Set-Location $localroot
write-host $localroot
$DoImport = 0

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

$objForm = New-Object System.Windows.Forms.Form 
$objForm.Text = "SQL Analyzer"
$objForm.Size = New-Object System.Drawing.Size(300,200) 
$objForm.StartPosition = "CenterScreen"
$objForm.MaximizeBox = $false
$objForm.FormBorderStyle = "FixedSingle"

$objForm.KeyPreview = $True
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
    {$x=$DBTextBox.Text;$objForm.Close()}})
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
    {$objForm.Close()}})

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(75,120)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.Add_Click(
{
    $Script:DoImport = 1
    $objForm.Close()
}
)
$objForm.Controls.Add($OKButton)

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(150,120)
$CancelButton.Size = New-Object System.Drawing.Size(75,23)
$CancelButton.Text = "Cancel"
$CancelButton.Add_Click(
{
    $Script:DoImport = 0
    $objForm.Close()
}
)
$objForm.Controls.Add($CancelButton)

$ServerLabel = New-Object System.Windows.Forms.Label
$ServerLabel.Location = New-Object System.Drawing.Size(10,20) 
$ServerLabel.Size = New-Object System.Drawing.Size(280,20) 
$ServerLabel.Text = "SQL Server Name"
$objForm.Controls.Add($ServerLabel) 

$ServerTextBox = New-Object System.Windows.Forms.TextBox 
$ServerTextBox.Location = New-Object System.Drawing.Size(10,40) 
$ServerTextBox.Size = New-Object System.Drawing.Size(260,20) 
$ServerTextBox.Text = "."
$objForm.Controls.Add($ServerTextBox) 

$DBLabel = New-Object System.Windows.Forms.Label
$DBLabel.Location = New-Object System.Drawing.Size(10,65) 
$DBLabel.Size = New-Object System.Drawing.Size(280,20) 
$DBLabel.Text = "Database Name"

$objForm.Controls.Add($DBLabel) 

$DBTextBox = New-Object System.Windows.Forms.TextBox 
$DBTextBox.Location = New-Object System.Drawing.Size(10,85) 
$DBTextBox.Size = New-Object System.Drawing.Size(260,20)
$DBTextBox.Text = "SQLNexus"
$objForm.Controls.Add($DBTextBox) 

$objForm.Topmost = $True

$objForm.Add_Shown({$objForm.Activate()})
[void] $objForm.ShowDialog()

$DatabaseName = $DBTextBox.Text
$ServerName = $ServerTextBox.Text


if(($DatabaseName -ne "" -and $ServerName -ne "") -and $Script:DoImport -eq 1)
{
. ..\PSSDiagExport.ps1 -ServerName $ServerName -DatabaseName $DatabaseName -SourcePath $folderpath
}

