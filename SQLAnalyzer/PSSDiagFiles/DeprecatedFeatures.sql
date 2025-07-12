PRINT '--Deprecated'
SELECT * FROM sys.dm_os_performance_counters   
WHERE object_name LIKE '%Deprecated Features%';  