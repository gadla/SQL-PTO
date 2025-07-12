/*
	Use the following query to view the SQL statements of plans currently in the 
	plan cache.  We keep track of these statements in memory for as long as we can
	(as long as they're being used).  You can use this DMV to find expensive statements.
	High values for AverageLogicalReads with a high number of executions are good 
	candidates for optimization.
	
	References:
		sys.dm_exec_query_stats:  http://msdn.microsoft.com/en-us/library/ms189741.aspx
		sys.dm_exec_sql_text:  http://msdn.microsoft.com/en-us/library/ms181929.aspx
*/
SET NOCOUNT ON


DECLARE @ProductVersion NVARCHAR(128)
SET @ProductVersion = CAST(SERVERPROPERTY ('ProductVersion') AS NVARCHAR(128))

IF CAST(LEFT(@ProductVersion, CHARINDEX('.',@ProductVersion)-1) AS BIGINT) > 8
BEGIN
	--make sure that the context the statement is ran in is not in 2000 compat mode.
	DECLARE @DBContext SYSNAME, @SQL NVARCHAR(MAX)
	SELECT TOP 1 @DBContext = name 
	FROM sys.databases
	WHERE compatibility_level > 80

	SET @SQL = N' USE [' + @DBContext + ']
	SELECT TOP 1250
		AverageLogicalReads = total_logical_reads/execution_count,
		AverageRunTimeSeconds = (total_elapsed_time/1000000.0)/execution_count,
		execution_count,
		last_worker_time,
		last_physical_reads,
		total_logical_writes,
		last_logical_writes,
		last_logical_reads,
		last_elapsed_time,
		StatementText = 
				REPLACE(REPLACE((SUBSTRING(text, statement_start_offset/2+1,
						  (CASE WHEN statement_end_offset=-1
								THEN LEN(CONVERT(NVARCHAR(MAX), text))*2
								ELSE statement_end_offset
						   END-statement_start_offset)/2)),CHAR(10),''''),CHAR(13),'''')
		,'
	SET @SQL = @SQL + 
	CASE WHEN CAST(LEFT(@ProductVersion, CHARINDEX('.',@ProductVersion)-1) AS INT) > 9
	THEN 
		'query_hash,
		query_plan_hash,' ELSE '' END + ' 
		sql_handle
	FROM
		sys.dm_exec_query_stats q
		CROSS APPLY sys.dm_exec_sql_text(sql_handle)
		CROSS APPLY sys.dm_exec_query_plan(plan_handle)
	ORDER BY
		execution_count  DESC'
	    
	PRINT '-- ExpensiveQueries'	
	EXECUTE (@SQL)
END

    