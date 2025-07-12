#running in ps cmd prompt
if($psISE -eq $null)
{

$BaseFolder = split-path (split-path $PSCommandPath)
}
else  
{
$BaseFolder = split-path (split-path $psISE.CurrentFile.FullPath)
}


get-childitem "$BaseFolder\*.*" -Recurse |unblock-file
