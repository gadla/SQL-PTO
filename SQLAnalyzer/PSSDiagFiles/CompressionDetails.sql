use master
GO
IF OBJECT_ID('tempdb..#CompressionDetails') IS NOT NULL
DROP TABLE #CompressionDetails
GO
CREATE TABLE #CompressionDetails
(
	DBName NVARCHAR(128),
	TableName NVARCHAR(128),
	RowCnt BIGINT,
	DataPages BIGINT,
	DataCompressionDescription NVARCHAR(60),
	PartitionID BIGINT
)

INSERT INTO #CompressionDetails
EXECUTE sp_msforeachdb'use [?]
IF db_name(db_id()) not in(''master'',''model'',''msdb'')
BEGIN
SELECT DBName = ''?'', TableName = object_name(p.object_id, db_id()), rows, data_pages, p.data_compression_desc, p.partition_id
FROM sys.partitions p with(nolock)
JOIN sys.allocation_units a with(nolock) ON a.container_id = CASE WHEN a.type IN(1,3) then p.hobt_id ELSE p.partition_id END
JOIN sys.objects o with(nolock) on p.object_id = o.object_id
WHERE o.type = ''U''
END
'
PRINT '-- CompressionDetails'
SELECT *
FROM #CompressionDetails
ORDER BY DBName, DataCompressionDescription, TableName