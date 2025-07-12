#check to see if user is running this from the ISE

#running in ps cmd prompt
if($psISE -eq $null)
{

$FunctionFolder = split-path $PSCommandPath
}
else  
{
$FunctionFolder = split-path $SCRIPT:MyInvocation.MyCommand.Path -parent
}

#Run this in admin mode
New-PSDrive -PSProvider registry -Root HKEY_CLASSES_ROOT -Name HKCR -ErrorAction Ignore

if(-not (test-path -Path HKCR:\Directory))
{
    new-item -path HKCR:\Directory 
}

if(-not (test-path -Path HKCR:\Directory\Shell))
{
    new-item -path HKCR:\Directory\Shell 
}

#bug found by Nate Evenson
if(-not (test-path -Path HKCR:\Directory\shell\PowershellMenu))
{
    new-item -path HKCR:\Directory\shell -Name PowershellMenu
}

if(-not(test-path -Path HKCR:\Directory\shell\PowershellMenu\command))
{
    new-item -path HKCR:\Directory\shell\PowershellMenu -Name command
}

set-location HKCR:\Directory\shell\PowershellMenu\command

set-item -path HKCR:\Directory\shell\PowershellMenu -value "Run SQLAnalyzer"

$cmd = "powershell.exe -noexit -file ""$FunctionFolder\WindowsFormInit.ps1"" -folderpath ""%V"""

set-item -path HKCR:\Directory\shell\PowershellMenu\command -value $cmd
