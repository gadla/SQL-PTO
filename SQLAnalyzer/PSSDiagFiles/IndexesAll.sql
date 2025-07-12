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
AvgPageIOLatchWait bigint
)
GO

INSERT INTO #IndexOps
EXECUTE master..sp_msforeachdb N'USE [?]
if db_name() not in(''tempdb'',''master'',''msdb'',''model'')
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
    JOIN sys.tables t  WITH(NOLOCK) ON o.object_id = t.object_id
    LEFT JOIN sys.indexes i  WITH(NOLOCK) ON o.object_id = i.object_id AND o.index_id = i.index_id'


SET NOCOUNT ON
IF OBJECT_ID('tempdb..#IndexDefs') IS NOT NULL
DROP TABLE #IndexDefs
GO
CREATE TABLE #IndexDefs
(
	DBName NVARCHAR(255),
	TableName NVARCHAR(255),
	IndexName NVARCHAR(255),
	IndexColumns NVARCHAR(MAX),
	IncludedColumns NVARCHAR(MAX),
	IndexType NVARCHAR(25),
	IsUnique BIT,
	IsPrimaryKey BIT,
	FillFact TINYINT, 
	IgnoreDupKey BIT, 
	IsUniqueConstraint BIT, 
	IsDisabled BIT, 
	IsHypothetical BIT, 
	AllowRowLocks BIT, 
	AllowPageLocks BIT, 
	LastRestart DATETIME
)

INSERT INTO #IndexDefs
EXECUTE master..sp_msforeachdb 'use [?]
if ''db_name()'' not in(''tempdb'',''master'',''msdb'',''model'')
SELECT 
	DB_NAME(),
	TableName = object_name(object_id),
	IndexName = ind.name,
	IndexColumns = REVERSE(SUBSTRING(REVERSE((
		SELECT
			col.name + '', ''
		FROM
			sys.index_columns ind_col WITH(NOLOCK)
			INNER JOIN sys.columns col WITH(NOLOCK)ON col.object_id = ind_col.object_id AND col.column_id = ind_col.column_id
		WHERE
			ind_col.object_id = ind.object_id AND
			ind_col.index_id = ind.index_id AND
			is_included_column = 0
		ORDER BY
			ind_col.key_ordinal
		FOR XML PATH('''')
	)), 3, 8000)), 
	IncludedColumns = REVERSE(SUBSTRING(REVERSE((
	SELECT
		col.name + '', ''
	FROM
		sys.index_columns ind_col WITH(NOLOCK)
		INNER JOIN sys.columns col WITH(NOLOCK) ON col.object_id = ind_col.object_id AND col.column_id = ind_col.column_id
	WHERE
		ind_col.object_id = ind.object_id AND
		ind_col.index_id = ind.index_id AND
		is_included_column = 1
	ORDER BY
		ind_col.key_ordinal
	FOR XML PATH('''')
)), 3, 8000)),
	type_desc, 
	is_unique, 
	is_primary_key, 
	fill_factor, 
	ignore_dup_key , 
	is_unique_constraint , 
	is_disabled , 
	is_hypothetical , 
	allow_row_locks , 
	allow_page_locks , 
	LastRestart = 
    (
		SELECT create_date 
		FROM sys.databases WITH(NOLOCK)
		WHERE database_id = 2
    )  
FROM sys.indexes ind WITH(NOLOCK)
WHERE
	ind.index_id >= 0
	AND ind.type <> 3
	AND ind.is_hypothetical = 0
ORDER BY 1'



SET NOCOUNT ON
if OBJECT_ID('tempdb..#IndexUsage') is not null
drop table #IndexUsage
Go
create table #IndexUsage
(
	DBName nvarchar(255), TableName nvarchar(255), IndexName nvarchar(255), 
	UserSeeks BIGINT, UserScans BIGINT, UserLookups BIGINT, UserUpdates BIGINT,
	LastUserSeek DATETIME, LastUserScan DATETIME,
	LastUserLookup DATETIME, LastUserUpdate DATETIME, TableRows BIGINT
)
GO
insert into #IndexUsage
EXECUTE master..sp_msforeachdb N'use [?]
if db_name() not in(''tempdb'',''master'',''msdb'',''model'')
SELECT
	''?'' as dbname,
    o.name AS tablename,
    i.name AS indexname,
    u.user_seeks,
    u.user_scans,
    u.user_lookups,
    u.user_updates,  
    u.last_user_seek,
    u.last_user_scan,
    u.last_user_lookup,
    u.last_user_update, 
    x.TableRows
FROM
    sys.dm_db_index_usage_stats u WITH(NOLOCK)
JOIN sys.indexes i WITH(NOLOCK) ON 
	u.object_id = i.object_id AND
	u.index_id = i.index_id
JOIN sys.objects o WITH(NOLOCK) ON 
	i.object_id = o.object_id
LEFT JOIN 
(
	 SELECT
		object_id,
		SUM(rows) AS TableRows
	 FROM
		sys.partitions WITH(NOLOCK)
	 WHERE
		index_id = 1
	 GROUP BY
		object_id
) x
ON o.object_id = x.object_id
WHERE
    o.type = ''u'' and 
    u.database_id = DB_ID()'

PRINT '-- IndexDefs'
SELECT * FROM #IndexDefs defs

PRINT '-- IndexUsage'
SELECT * FROM #IndexUsage detail

PRINT '-- IndexOps'
SELECT * FROM #IndexOps ops