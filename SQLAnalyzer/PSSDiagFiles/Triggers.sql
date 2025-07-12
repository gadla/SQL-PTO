SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING OFF
GO
IF OBJECT_ID('tempdb..#Triggers') IS NOT NULL
DROP TABLE #Triggers
GO
CREATE TABLE #Triggers
(
	DBName nvarchar(128) NULL,
	database_id int NULL,
	object_id int NOT NULL,
	cached_time datetime NULL,
	last_execution_time datetime NULL,
	execution_count bigint NULL,
	total_worker_time bigint NULL,
	last_worker_time bigint NULL,
	min_worker_time bigint NULL,
	max_worker_time bigint NULL,
	total_physical_reads bigint NULL,
	last_physical_reads bigint NULL,
	min_physical_reads bigint NULL,
	max_physical_reads bigint NULL,
	total_logical_writes bigint NULL,
	last_logical_writes bigint NULL,
	min_logical_writes bigint NULL,
	max_logical_writes bigint NULL,
	total_logical_reads bigint NULL,
	last_logical_reads bigint NULL,
	min_logical_reads bigint NULL,
	max_logical_reads bigint NULL,
	total_elapsed_time bigint NULL,
	last_elapsed_time bigint NULL,
	min_elapsed_time bigint NULL,
	max_elapsed_time bigint NULL,
	name sysname NOT NULL,
	parent_class tinyint NOT NULL,
	parent_class_desc nvarchar(60) NULL,
	parent_id int NOT NULL,
	type char(2) NULL,
	type_desc nvarchar(60) NULL,
	create_date datetime NOT NULL,
	modify_date datetime NOT NULL,
	is_ms_shipped bit NOT NULL,
	is_disabled bit NOT NULL,
	is_not_for_replication bit NOT NULL,
	is_instead_of_trigger bit NOT NULL,
	parent_table nvarchar(128) NULL
) 

INSERT INTO #Triggers
EXECUTE sp_msforeachdb N' USE [?]
IF DB_ID() > 4
SELECT
	DBName = DB_NAME(DB_ID()),
	database_id = DB_ID(),	
	t.object_id,	
	cached_time,	
	last_execution_time,	
	execution_count,	
	total_worker_time,	
	last_worker_time,	
	min_worker_time,	
	max_worker_time,	
	total_physical_reads,	
	last_physical_reads,	
	min_physical_reads,	
	max_physical_reads,	
	total_logical_writes,	
	last_logical_writes,	
	min_logical_writes,	
	max_logical_writes,	
	total_logical_reads,	
	last_logical_reads,	
	min_logical_reads,	
	max_logical_reads,	
	total_elapsed_time,	
	last_elapsed_time,	
	min_elapsed_time,	
	max_elapsed_time,	
	name,	
	parent_class,	
	parent_class_desc,	
	parent_id,	
	ts.type,	
	ts.type_desc,	
	create_date,	
	modify_date,	
	is_ms_shipped,	
	is_disabled,	
	is_not_for_replication,	
	is_instead_of_trigger, 
	parent_table = OBJECT_NAME(parent_id,DB_ID())
FROM 
	sys.triggers t
	LEFT JOIN sys.dm_exec_trigger_stats ts
	ON ts.object_id = t.object_id and ts.database_id = DB_ID()
	'
PRINT '-- Triggers'
SELECT *
FROM #Triggers