SET NOCOUNT ON
IF OBJECT_ID('tempdb..#IndexOps') IS NOT NULL
DROP TABLE #IndexOps
GO
CREATE TABLE #IndexOps
(
DBName nvarchar(255),
TableName nvarchar(255),
IndexName nvarchar(255),
partition_number int,
leaf_insert_count bigint,
leaf_delete_count bigint,
leaf_update_count bigint,
leaf_ghost_count bigint,
nonleaf_insert_count bigint,
nonleaf_delete_count bigint,
nonleaf_update_count bigint,
leaf_allocation_count bigint,
nonleaf_allocation_count bigint,
range_scan_count bigint,
singleton_lookup_count bigint,
row_lock_count bigint,
row_lock_wait_count bigint,
row_lock_wait_in_ms bigint,
page_lock_count bigint,
page_lock_wait_count bigint,
page_lock_wait_in_ms bigint,
index_lock_promotion_attempt_count bigint,
index_lock_promotion_count bigint,
page_latch_wait_count bigint,
page_latch_wait_in_ms bigint,
page_io_latch_wait_count bigint,
page_io_latch_wait_in_ms bigint,
AvgPageLatchWait bigint,
AvgPageIOLatchWait bigint)
GO

INSERT INTO #IndexOps
EXECUTE sp_msforeachdb N'USE [?]
SELECT
	''?'',
    TableName = OBJECT_NAME(o.object_id, o.database_id),
    IndexName = i.name,
    partition_number,
    o.leaf_insert_count,
    o.leaf_delete_count,
    o.leaf_update_count,
    o.leaf_ghost_count,
    o.nonleaf_insert_count,
    o.nonleaf_delete_count,
    o.nonleaf_update_count,
    o.leaf_allocation_count,  --page splits
    o.nonleaf_allocation_count,  --page splits
    o.range_scan_count,
    o.singleton_lookup_count,
    o.row_lock_count,
    o.row_lock_wait_count,
    o.row_lock_wait_in_ms,
    o.page_lock_count,
    o.page_lock_wait_count,
    o.page_lock_wait_in_ms,
    o.index_lock_promotion_attempt_count,   --lock escalation attempts
    o.index_lock_promotion_count,   --lock escalation successes
    o.page_latch_wait_count,  --contention for pages already in memory
    o.page_latch_wait_in_ms,  --contention for pages already in memory
    o.page_io_latch_wait_count,  --physical IOs.  Pages read into memory from disk.
    o.page_io_latch_wait_in_ms,  --physical IOs.  Pages read into memory from disk. 
    AvgPageLatchWait = o.page_latch_wait_in_ms/(o.page_latch_wait_count+1),
    AvgPageIOLatchWait = o.page_io_latch_wait_in_ms/(o.page_io_latch_wait_count+1)
FROM
    sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) o
    JOIN sys.tables t ON o.object_id = t.object_id
    LEFT JOIN sys.indexes i ON o.object_id = i.object_id AND o.index_id = i.index_id
ORDER BY
 leaf_insert_count DESC'

PRINT '-- IndexOperations'
select * from #IndexOps