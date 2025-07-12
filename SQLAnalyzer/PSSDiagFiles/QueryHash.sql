PRINT '-- QueryHash'
SELECT
	a.*, 
	AverageLogicalReads = total_logical_reads/execution_count,
	AverageRunTimeSeconds = (total_elapsed_time/1000000.0)/execution_count, 
	ObjectName = object_name(x.objectid, x.dbid),
	StmtText = LEFT(x.text, 150)
FROM 
(
	SELECT
		query_hash, 
		CachedStatementCount = COUNT(*), 
		DistinctQueryCount = COUNT(DISTINCT query_hash),
		DistinctPlanCount = COUNT(DISTINCT query_plan_hash),
		execution_count = SUM(execution_count),
		total_elapsed_time = SUM(total_elapsed_time), 
		total_logical_reads = SUM(total_logical_reads),
		sql_handle = MIN(sql_handle)
	FROM
		sys.dm_exec_query_stats q
	GROUP BY query_hash
) a 
	CROSS APPLY sys.dm_exec_sql_text(sql_handle) x
ORDER BY AverageLogicalReads DESC
	