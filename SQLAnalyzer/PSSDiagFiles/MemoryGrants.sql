SET NOCOUNT ON

WHILE(1=1)
BEGIN
PRINT '-- MemoryGrants'
SELECT Runtime = GETDATE(), *
FROM sys.dm_exec_query_memory_grants
WAITFOR DELAY '0:0:20'
END