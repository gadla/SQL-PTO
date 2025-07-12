Import-Module -Name C:\Users\kkilt\source\repos\SQLAnalyzer\SqlAnalyzer.psd1 -Force 

Start-SqlAnalyzer -ServerName 'localhost\SQLEXPRESS' `
    -DatabaseName 'SqlNexus' `
    -SourcePath 'C:\Users\kkilt\Desktop\AngloAmerican\output'