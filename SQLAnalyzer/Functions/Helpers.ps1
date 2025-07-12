function find-ispscore
{
    if ($PSVersionTable.PSEdition -eq "Core")
    {
        $true
    }
    else
    {
        $false
    }
}


