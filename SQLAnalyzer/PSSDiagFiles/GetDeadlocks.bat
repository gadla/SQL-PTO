REM @echo off
REM -- TOP CPU SHOWPLAN_XML batch file 
REM -- This batch file get the top 10 CPU queries show plan xml 
REM
REM Usage: 
REM    TopCPUQueryShowPlanXML.bat <TOP N queries> <Output Path> <SQL Server Instance name> 
REM
REM Example: 
REM    TopCPUQueryShowPlanXML 10 C:\temp\Shutdown_ DSDAUTO1 
REM

for /L %%x in (1,1, %1) do bcp "select xmlplan from (SELECT ROW_NUMBER() OVER(ORDER BY row_id DESC) AS RowNumber, CAST(deadlockgraph as XML) xmlplan FROM tempdb..deadlock_graphs)x where RowNumber =%%x" queryout "%2%%x.xdl" -T -c -S %3 
