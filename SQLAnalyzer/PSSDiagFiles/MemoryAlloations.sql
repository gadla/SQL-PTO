IF object_id('tempdb..#AllocationResults') IS NOT NULL
DROP TABLE #AllocationResults
go

SET NOCOUNT ON
CREATE TABLE #AllocationResults
(
	DatabaseName sysname,
	ObjectName sysname,
	Index_ID SMALLINT,
	IndexName VARCHAR(500),
	IndexType VARCHAR(50),
	TotalMB DECIMAL,
	FreeSpaceMB DECIMAL,
	FreeSpacePC DECIMAL
)

INSERT INTO #AllocationREsults

EXEC sp_MSforeachdb 
    N'IF EXISTS (SELECT 1 FROM (SELECT DISTINCT DB_NAME ([database_id]) AS [name] 
    FROM sys.dm_os_buffer_descriptors WITH(NOLOCK)) AS names WHERE [name] = ''?'')
BEGIN
USE [?]
SELECT
    ''?'' AS [Database],
    OBJECT_NAME (p.[object_id]) AS [Object],
    p.[index_id],
    i.[name] AS [Index],
    i.[type_desc] AS [Type],
    (DPCount + CPCount) * 8 / 1024 AS [TotalMB],
    ([DPFreeSpace] + [CPFreeSpace]) / 1024 / 1024 AS [FreeSpaceMB],
    CAST (ROUND (100.0 * (([DPFreeSpace] + [CPFreeSpace]) / 1024) / (([DPCount] + [CPCount]) * 8), 1) AS DECIMAL (4, 1)) AS [FreeSpacePC]
FROM
    (SELECT
        allocation_unit_id,
        SUM (CASE WHEN ([is_modified] = 1)
            THEN 1 ELSE 0 END) AS [DPCount], 
        SUM (CASE WHEN ([is_modified] = 1)
            THEN 0 ELSE 1 END) AS [CPCount],
        SUM (CASE WHEN ([is_modified] = 1)
            THEN CAST ([free_space_in_bytes] AS BIGINT) ELSE 0 END) AS [DPFreeSpace], 
        SUM (CASE WHEN ([is_modified] = 1)
            THEN 0 ELSE CAST ([free_space_in_bytes] AS BIGINT) END) AS [CPFreeSpace]
    FROM sys.dm_os_buffer_descriptors WITH(NOLOCK)
    WHERE [database_id] = DB_ID (''?'')
    GROUP BY [allocation_unit_id]) AS buffers
INNER JOIN sys.allocation_units AS au WITH(NOLOCK)
    ON au.[allocation_unit_id] = buffers.[allocation_unit_id]
INNER JOIN sys.partitions AS p WITH(NOLOCK)
    ON au.[container_id] = p.[partition_id]
INNER JOIN sys.indexes AS i WITH(NOLOCK)
    ON i.[index_id] = p.[index_id] AND p.[object_id] = i.[object_id]
END'; 
PRINT '-- MemoryAllocations'
SELECT * FROM #AllocationREsults
ORDER BY DatabaseName