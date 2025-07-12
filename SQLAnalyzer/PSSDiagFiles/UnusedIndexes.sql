SET NOCOUNT ON
if OBJECT_ID('tempdb..#Ind') is not null
drop table #Ind
Go
create table #Ind
(
	DatabaseName nvarchar(255), TableName nvarchar(255), IndexName nvarchar(255), 
	UserSeeks BIGINT, UserScans BIGINT, UserLookups BIGINT, UserUpdates BIGINT,
	LastRestart DATETIME, LastUserSeek DATETIME, LastUserScan DATETIME,
	LastUserLookup DATETIME, LastUserUpdate DATETIME, TableRows BIGINT
)
GO
insert into #Ind
EXECUTE sp_msforeachdb N'use [?]
SELECT
	''?'' as dbname,
    o.name AS tablename,
    i.name AS indexname,
    u.user_seeks,
    u.user_scans,
    u.user_lookups,
    u.user_updates,
    LastRestart = 
    (
		SELECT create_date 
		FROM sys.databases
		WHERE database_id = 2
    ),    
    u.last_user_seek,
    u.last_user_scan,
    u.last_user_lookup,
    u.last_user_update, 
    x.TableRows
FROM
    sys.dm_db_index_usage_stats u 
JOIN sys.indexes i ON 
	u.object_id = i.object_id AND
	u.index_id = i.index_id
JOIN sys.objects o ON
	i.object_id = o.object_id
LEFT JOIN 
(
	 SELECT
		object_id,
		SUM(rows) AS TableRows
	 FROM
		sys.partitions  WITH(NOLOCK)
	 WHERE
		index_id = 1
	 GROUP BY
		object_id
) x
ON o.object_id = x.object_id
WHERE
    o.type = ''u'' and 
    u.database_id = DB_ID()'

PRINT '-- UnusedIndexes'
select * from #Ind