PRINT '-- SuspectPages'
select d.name, p.* 
from msdb..suspect_pages p
LEFT JOIN sys.databases d on p.database_id = p.page_id