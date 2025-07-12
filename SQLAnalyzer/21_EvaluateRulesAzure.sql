
IF OBJECT_ID('cust_QueryStoreOptions') IS NOT NULL
BEGIN
	IF EXISTS
	(
		SELECT *
		FROM [dbo].[cust_QueryStoreOptions]
		WHERE DBName NOT IN('master','msdb','tempdb','model') AND
		actual_state_desc <> 'READ_WRITE'
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Query store is not enabled.','Operational Excellence','Critical',NULL,NULL,NULL)
	END


	IF EXISTS
	(
		SELECT *
		FROM [dbo].[cust_QueryStoreOptions]
		WHERE DBName NOT IN('master','msdb','tempdb','model') AND
		CAST(max_storage_size_mb AS INT) <= 100
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Query store max size is small.','Operational Excellence','Critical',NULL,NULL,NULL)
	END
END

/*
IF OBJECT_ID('cust_AutoTuningConfig') IS NOT NULL
BEGIN
	SELECT *
	FROM [dbo].[cust_AutoTuningConfig]
	WHERE DBName NOT IN('master','msdb','tempdb','model') 

END
*/

IF OBJECT_ID('cust_ResourceStats') IS NOT NULL
BEGIN
	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_ResourceStats]
		WHERE 
			database_name NOT IN('master','msdb','tempdb','model') AND
			CAST(avg_cpu_percent AS DECIMAL) > 60	
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High database CPU usage.','Operational Excellence','Critical',NULL,NULL,NULL)
	END



	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_ResourceStats]
		WHERE 
			database_name NOT IN('master','msdb','tempdb','model') AND
			CAST(avg_data_io_percent AS DECIMAL) > 60	
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High database IO usage.','Operational Excellence','Critical',NULL,NULL,NULL)
	END	


	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_ResourceStats]
		WHERE 
			database_name NOT IN('master','msdb','tempdb','model') AND
			CAST(avg_log_write_percent AS DECIMAL) > 60	
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High database log write percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END


	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_ResourceStats]
		WHERE 
			database_name NOT IN('master','msdb','tempdb','model') AND
			CAST(max_worker_percent AS DECIMAL) > 60	
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High Database Max Worker Percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END


	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_ResourceStats]
		WHERE 
			database_name NOT IN('master','msdb','tempdb','model') AND
			CAST(max_session_percent AS DECIMAL) > 60	
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High Database Max Session Percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END


	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_ResourceStats]
		WHERE 
			database_name NOT IN('master','msdb','tempdb','model') AND
			CAST(xtp_storage_percent AS DECIMAL) > 60	
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High Database In-Memory OLTP storage percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END


	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_ResourceStats]
		WHERE 
			database_name NOT IN('master','msdb','tempdb','model') AND
			CAST(avg_instance_cpu_percent AS DECIMAL) > 60	
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High Database instance cpu percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END


	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_ResourceStats]
		WHERE 
			database_name NOT IN('master','msdb','tempdb','model') AND
			CAST(avg_instance_memory_percent AS DECIMAL) > 60	
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High database instance memory percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END


END


---------------------------------------------
IF OBJECT_ID('cust_DBResourceStats') IS NOT NULL
BEGIN
	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_DBResourceStats]
		WHERE 
		DBName NOT IN('master','msdb','tempdb','model') AND
		CAST(avg_cpu_percent AS DECIMAL) > 60
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Database usage with high average CPU.','Operational Excellence','Critical',NULL,NULL,NULL)
	END



	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_DBResourceStats]
		WHERE 
		DBName NOT IN('master','msdb','tempdb','model') AND
		CAST(avg_data_io_percent AS DECIMAL) > 60
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Database usage with high io percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END



	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_DBResourceStats]
		WHERE 
		DBName NOT IN('master','msdb','tempdb','model') AND
		CAST(avg_log_write_percent AS DECIMAL) > 60
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Database usage with high log write percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END


	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_DBResourceStats]
		WHERE 
		DBName NOT IN('master','msdb','tempdb','model') AND
		CAST(max_worker_percent AS DECIMAL) > 60
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Databases with high max worker percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END


	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_DBResourceStats]
		WHERE 
		DBName NOT IN('master','msdb','tempdb','model') AND
		CAST(max_session_percent AS DECIMAL) > 60
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Databases with high max session percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END


	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_DBResourceStats]
		WHERE 
		DBName NOT IN('master','msdb','tempdb','model') AND
		CAST(xtp_storage_percent AS DECIMAL) > 60
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Databases with high In-Memory storage percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END



	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_DBResourceStats]
		WHERE 
		DBName NOT IN('master','msdb','tempdb','model') AND
		CAST(avg_instance_cpu_percent AS DECIMAL) > 60
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Databases with high instance CPU percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END


	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_DBResourceStats]
		WHERE 
			DBName NOT IN('master','msdb','tempdb','model') AND
			 CAST(avg_instance_memory_percent AS DECIMAL) > 60
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Databases with high instance memory percent.','Operational Excellence','Critical',NULL,NULL,NULL)
	END
END


/*

--add this to the summary
SELECT 
	start_time, end_time, avg_cpu_percent, io_requests,
	AvailableStorageGB = CAST(((CAST(reserved_storage_mb AS DECIMAL) - CAST(storage_space_used_mb AS DECIMAL(18,2)))/1024.0) AS DECIMAL(18,2)), 
	MBWritten = CAST(CAST(io_bytes_written AS BIGINT)/1024.0/1024.0 AS DECIMAL(18,2)),
	MBRead = CAST(CAST(io_bytes_read AS BIGINT)/1024.0/1024.0 AS DECIMAL(18,2)),
	ReservedStorageGB = CAST(CAST(reserved_storage_mb AS DECIMAL)/1024.0 AS DECIMAL(18,2)),
	StorageUsedGB = CAST(CAST(storage_space_used_mb AS DECIMAL)/1024.0 AS DECIMAL(18,2))
FROM [dbo].[cust_ServerResourceStats]
ORDER BY cast(start_time AS DATETIME) ASC


select * from [dbo].[cust_ResourceStatsSummary]

*/

IF OBJECT_ID('cust_ServerResourceStats') IS NOT NULL
BEGIN
	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[cust_ServerResourceStats]
		WHERE 
			CAST(avg_cpu_percent AS DECIMAL) > 60
	)
	BEGIN
		INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High CPU for the Managed Instance.','Operational Excellence','Critical',NULL,NULL,NULL)
	END

END


	IF 
	OBJECT_ID('tbl_query_store_runtime_stats') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_plan') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_query') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_query_text') IS NOT NULL 
	BEGIN
		IF EXISTS(
			SELECT *
			FROM 		
			tbl_query_store_runtime_stats q
			join tbl_query_store_plan p on q.dbid = p.dbid and q.plan_id = p.plan_id
			join tbl_query_store_query qq on p.dbid = qq.dbid and p.query_id = qq.query_id
			join tbl_query_store_query_text qt on qt.dbid = qq.dbid and qt.query_text_id = qq.query_text_id
			WHERE
				CAST(avg_logical_io_reads AS FLOAT) > 500000
		)
		BEGIN
			INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('There are queries that are driving high amounts of logical reads.','Operational Excellence','Critical',NULL,NULL,NULL)
		END
	END