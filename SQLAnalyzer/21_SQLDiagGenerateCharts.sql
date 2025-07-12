
-- Chart Automation Process
  -- CPU Usage
  -- Processor Time (%) vs Batch Requests/sec
  -- Available MBytes
  -- Buffer Cache Hit Ratio vs Page Life Expectancy
  -- Physical Disk: Avg. Disk sec/Read
  -- Physical Disk: Avg. Disk sec/Write
  -- Batch Requests/sec vs SQL Compilations/sec
  -- SQL Compilations/sec vs SQL Re-Compilations/sec
  -- Full Scans/sec vs Index Searches/sec
  -- Notable waits
SET NOCOUNT ON

IF OBJECT_ID('TabCharts') IS NOT NULL
DROP TABLE TabCharts
GO

CREATE TABLE TabCharts
(
procname sysname, 
tablename sysname,
xcolumn sysname,
ycolumn sysname,
zcolumn sysname,
charttype sysname,
charttitle sysname,
wordbookmark sysname
)

go
INSERT INTO TabCharts values ('ReportingCPU'   ,'TableData_ReportingCPU'   ,'CounterDateTime','Processor Time (%)','null','xlLine', 'CPU Usage','CPUG1')
INSERT INTO TabCharts values ('ReportingCPU2'  ,'TableData_ReportingCPU2'  ,'CounterDateTime','Processor Time (%)','Batch Requests/sec','xlLine', 'Processor Time (%) vs Batch Requests/sec','CPUG2')
INSERT INTO TabCharts values ('ReportingMemory1'   ,'TableData_ReportingMemory1'   ,'CounterDateTime','Available MBytes','null','xlLine', 'Available MBytes','MemoryG1')
INSERT INTO TabCharts values ('ReportingMemory2'   ,'TableData_ReportingMemory2'   ,'CounterDateTime','Buffer Cache Hit Ratio','Page Life Expectancy','xlLine', 'Buffer Cache Hit Ratio vs Page Life Expectancy','MemoryG2')
INSERT INTO TabCharts values ('ReportingIO1'   ,'TableData_ReportingIO1'   ,'CounterDateTime','Avg. Disk sec/Read','null','xlLine', 'Physical Disk: Avg. Disk sec/Read','IOG1')
INSERT INTO TabCharts values ('ReportingIO2'   ,'TableData_ReportingIO2'   ,'CounterDateTime','Avg. Disk sec/Write','null','xlLine', 'Physical Disk: Avg. Disk sec/Write','IOG2')
INSERT INTO TabCharts values ('ReportingSQL1'   ,'TableData_ReportingSQL1'   ,'CounterDateTime','Batch Requests/sec','SQL Compilations/sec','xlLine', 'Batch Requests/sec vs SQL Compilations/sec','SQLG1')
INSERT INTO TabCharts values ('ReportingSQL2'   ,'TableData_ReportingSQL2'   ,'CounterDateTime','SQL Compilations/sec','SQL Re-Compilations/sec','xlLine', 'SQL Compilations/sec vs SQL Re-Compilations/sec','SQLG2')
INSERT INTO TabCharts values ('ReportingSQL3'   ,'TableData_ReportingSQL3'   ,'CounterDateTime','Full Scans/sec','Index Searches/sec','xlLine', 'Full Scans/sec vs Index Searches/sec','SQLG3')
INSERT INTO TabCharts values ('ReportingWaits' ,'TableData_ReportingWaits' ,'WaitType','Percentage','null','xlColumnClustered', 'Notable waits','WaitsG1')

GO
IF OBJECT_ID('ReportingCPU') IS NOT NULL
DROP PROCEDURE ReportingCPU
GO
CREATE PROCEDURE ReportingCPU
AS
BEGIN 
	SELECT CounterDateTime, CounterValue as 'Processor Time (%)'
	FROM CounterData d
	INNER JOIN CounterDetails c on c.CounterID=d.CounterID
	WHERE ObjectName like 'Processor' 
	AND CounterName LIKE '[%] Processor Time'
	ORDER BY RecordIndex
END
GO
IF OBJECT_ID('ReportingCPU2') IS NOT NULL
DROP PROCEDURE ReportingCPU2
GO
CREATE PROCEDURE ReportingCPU2
AS
BEGIN 
	;with t1 as(
	SELECT CounterDateTime, CounterValue as 'Processor Time (%)', RecordIndex, CounterName
	FROM CounterData d
	INNER JOIN CounterDetails c on c.CounterID=d.CounterID
	WHERE ObjectName like 'Processor' 
	AND CounterName LIKE '[%] Processor Time'
	),t2 as
	(
	SELECT CounterDateTime, CounterValue as 'Batch Requests/sec', RecordIndex,CounterName
	FROM CounterData d
	INNER JOIN CounterDetails c on c.CounterID=d.CounterID
	WHERE ObjectName like '%:SQL Statistics' 
	AND CounterName LIKE 'Batch Requests/sec'
	)
	SELECT t1.CounterDateTime, t1.[Processor Time (%)], t2.[Batch Requests/sec]
	FROM t1
	INNER JOIN t2 on t1.RecordIndex=t2.RecordIndex
	ORDER BY t1.RecordIndex
END
GO


IF OBJECT_ID('ReportingMemory1') IS NOT NULL
DROP PROCEDURE ReportingMemory1
GO
CREATE PROCEDURE ReportingMemory1
AS
BEGIN 
	SELECT CounterDateTime, CounterValue as 'Available MBytes'
	FROM CounterData d
	INNER JOIN CounterDetails c on c.CounterID=d.CounterID
	WHERE ObjectName like 'Memory' 
	AND CounterName LIKE 'Available MBytes'
	ORDER BY RecordIndex
END
GO

IF OBJECT_ID('ReportingMemory2') IS NOT NULL
DROP PROCEDURE ReportingMemory2
GO
CREATE PROCEDURE ReportingMemory2
AS
BEGIN 
	;with t1 as(
	SELECT CounterDateTime, CounterValue as 'Buffer Cache Hit Ratio', RecordIndex, CounterName
	FROM CounterData d
	INNER JOIN CounterDetails c on c.CounterID=d.CounterID
	WHERE ObjectName like '%:Buffer Manager' 
	AND CounterName LIKE 'Buffer Cache Hit Ratio'
	),t2 as
	(
	SELECT CounterDateTime, CounterValue as 'Page Life Expectancy', RecordIndex,CounterName
	FROM CounterData d
	INNER JOIN CounterDetails c on c.CounterID=d.CounterID
	WHERE ObjectName like '%:Buffer Manager' 
	AND CounterName LIKE 'Page Life Expectancy'
	)
	SELECT t1.CounterDateTime, t1.[Buffer Cache Hit Ratio], t2.[Page Life Expectancy]
	FROM t1
	INNER JOIN t2 on t1.RecordIndex=t2.RecordIndex
	ORDER BY t1.RecordIndex
END
GO

IF OBJECT_ID('ReportingIO1') IS NOT NULL
DROP PROCEDURE ReportingIO1
GO
CREATE PROCEDURE ReportingIO1
AS
BEGIN 
	DECLARE @disks as nvarchar(max)
	DECLARE @sql as nvarchar(max)

	SELECT @disks = COALESCE(@disks + ', ', '') + '['+ [InstanceName] +']' 
	FROM CounterData d
	INNER JOIN CounterDetails c on c.CounterID=d.CounterID
	WHERE ObjectName like 'PhysicalDisk' 
	AND CounterName LIKE 'Avg. Disk sec/Read'
	AND InstanceName NOT LIKE '%_Total%'
	GROUP BY [InstanceName]
	ORDER BY InstanceName

	SET @sql='
	SELECT 
		[CounterDateTime], ' + @disks + '
	FROM
	(
		SELECT RecordIndex, CounterDateTime,  CounterValue, InstanceName
		FROM CounterData d
		INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like ''PhysicalDisk'' 
		AND CounterName LIKE ''Avg. Disk sec/Read''
		AND InstanceName NOT LIKE ''%_Total%''
	)p
	PIVOT
	(
		MAX([CounterValue])
		FOR [InstanceName]
		IN (' + @disks + ')
	)as pvt
	'
	EXECUTE (@sql)
END
GO


IF OBJECT_ID('ReportingIO2') IS NOT NULL
DROP PROCEDURE ReportingIO2
GO
CREATE PROCEDURE ReportingIO2
AS
BEGIN 
	DECLARE @disks as nvarchar(max)
	DECLARE @sql as nvarchar(max)

	SELECT @disks = COALESCE(@disks + ', ', '') + '['+ [InstanceName] +']' 
	FROM CounterData d
	INNER JOIN CounterDetails c on c.CounterID=d.CounterID
	WHERE ObjectName like 'PhysicalDisk' 
	AND CounterName LIKE 'Avg. Disk sec/Write'
	AND InstanceName NOT LIKE '%_Total%'
	GROUP BY [InstanceName]
	ORDER BY InstanceName

	SET @sql='
	SELECT 
		[CounterDateTime], ' + @disks + '
	FROM
	(
		SELECT RecordIndex, CounterDateTime,  CounterValue, InstanceName
		FROM CounterData d
		INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like ''PhysicalDisk'' 
		AND CounterName LIKE ''Avg. Disk sec/Write''
		AND InstanceName NOT LIKE ''%_Total%''
	)p
	PIVOT
	(
		MAX([CounterValue])
		FOR [InstanceName]
		IN (' + @disks + ')
	)as pvt
	'
	EXECUTE (@sql)
END
GO

IF OBJECT_ID('ReportingSQL1') IS NOT NULL
DROP PROCEDURE ReportingSQL1
GO
CREATE PROCEDURE ReportingSQL1
AS
BEGIN 
	;with t1 as(
		SELECT CounterDateTime, CounterValue as 'Batch Requests/sec', RecordIndex,CounterName
		FROM CounterData d
		INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like '%:SQL Statistics' 
		AND CounterName LIKE 'Batch Requests/sec'
	),t2 as
	(
	
		SELECT CounterDateTime, CounterValue as 'SQL Compilations/sec', RecordIndex, CounterName
		FROM CounterData d
		INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like '%:SQL Statistics' 
		AND CounterName LIKE 'SQL Compilations/sec'
	)
	SELECT t1.CounterDateTime, t1.[Batch Requests/sec], t2.[SQL Compilations/sec]
	FROM t1
	INNER JOIN t2 on t1.RecordIndex=t2.RecordIndex
	ORDER BY t1.RecordIndex
END
GO

IF OBJECT_ID('ReportingSQL2') IS NOT NULL
DROP PROCEDURE ReportingSQL2
GO
CREATE PROCEDURE ReportingSQL2
AS
BEGIN 
	;with t1 as(
		SELECT CounterDateTime, CounterValue as 'SQL Compilations/sec', RecordIndex, CounterName
		FROM CounterData d
		INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like '%:SQL Statistics' 
		AND CounterName LIKE 'SQL Compilations/sec'
	),t2 as
	(
		SELECT CounterDateTime, CounterValue as 'SQL Re-Compilations/sec', RecordIndex,CounterName
		FROM CounterData d
		INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like '%:SQL Statistics' 
		AND CounterName LIKE 'SQL Re-Compilations/sec'

	)
	SELECT t1.CounterDateTime, t1.[SQL Compilations/sec], t2.[SQL Re-Compilations/sec]
	FROM t1
	INNER JOIN t2 on t1.RecordIndex=t2.RecordIndex
	ORDER BY t1.RecordIndex
END
GO

IF OBJECT_ID('ReportingSQL3') IS NOT NULL
DROP PROCEDURE ReportingSQL3
GO
CREATE PROCEDURE ReportingSQL3
AS
BEGIN 
	;with t1 as(
		SELECT CounterDateTime, CounterValue as 'Full Scans/sec', RecordIndex, CounterName
		FROM CounterData d
		INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like '%:Access Methods' 
		AND CounterName LIKE 'Full Scans/sec'
	),t2 as
	(
		SELECT CounterDateTime, CounterValue as 'Index Searches/sec', RecordIndex,CounterName
		FROM CounterData d
		INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like '%:Access Methods' 
		AND CounterName LIKE 'Index Searches/sec'

	)
	SELECT t1.CounterDateTime, t1.[Full Scans/sec], t2.[Index Searches/sec]
	FROM t1
	INNER JOIN t2 on t1.RecordIndex=t2.RecordIndex
	ORDER BY t1.RecordIndex
END
GO

GO
IF OBJECT_ID('ReportingWaits') IS NOT NULL
DROP PROCEDURE ReportingWaits
GO
CREATE PROCEDURE ReportingWaits
AS
BEGIN 
	   declare @StartTime datetime='19000101' 
     declare @EndTime datetime='19000101' 
     SELECT @StartTime=MIN(runtime) FROM tbl_OS_WAIT_STATS
     SELECT @EndTime  =MAX(runtime) FROM tbl_OS_WAIT_STATS
     


     SELECT TOP 10
     s.wait_type AS WaitType
     --, (e.waiting_tasks_count - s.waiting_tasks_count) as [waiting_tasks_count]
     --, (e.wait_time_ms - s.wait_time_ms) as [wait_time_ms]
     --, (e.wait_time_ms - s.wait_time_ms)/((e.waiting_tasks_count - s.waiting_tasks_count)) as [avg_wait_time_ms]
     --, (e.max_wait_time_ms) as [max_wait_time_ms]
     --, (e.signal_wait_time_ms - s.signal_wait_time_ms) as [signal_wait_time_ms]
     --, (e.signal_wait_time_ms - s.signal_wait_time_ms)/((e.waiting_tasks_count - s.waiting_tasks_count)) as [avg_signal_time_ms]
  
     ,100.0 * (CAST(e.wait_time_ms  AS BIGINT)- CAST(s.wait_time_ms AS BIGINT)) / SUM ((CAST(e.wait_time_ms  AS BIGINT)- CAST(s.wait_time_ms AS BIGINT))) OVER() AS [Percentage]
     
     --, s.runtime as [start_time]
     --, e.runtime as [end_time]
     --, DATEDIFF(ss, s.runtime, e.runtime) as [seconds_in_sample]
     
     FROM tbl_OS_WAIT_STATS e
     inner join (
     		select * from tbl_OS_WAIT_STATS
     		where runtime = @StartTime
     		) s on (s.wait_type = e.wait_type)
     where
     e.runtime = @EndTime
     and s.runtime = @StartTime
     and e.wait_time_ms > 0
     and (CAST(e.waiting_tasks_count AS BIGINT) - CAST(s.waiting_tasks_count AS BIGINT)) > 0
     and e.wait_type  NOT IN (
             N'BROKER_EVENTHANDLER',             N'BROKER_RECEIVE_WAITFOR',
             N'BROKER_TASK_STOP',                N'BROKER_TO_FLUSH',
             N'BROKER_TRANSMITTER',              N'CHECKPOINT_QUEUE',
             N'CHKPT',                           N'CLR_AUTO_EVENT',
             N'CLR_MANUAL_EVENT',                N'CLR_SEMAPHORE',
             N'DBMIRROR_DBM_EVENT',              N'DBMIRROR_EVENTS_QUEUE',
             N'DBMIRROR_WORKER_QUEUE',           N'DBMIRRORING_CMD',
             N'DIRTY_PAGE_POLL',                 N'DISPATCHER_QUEUE_SEMAPHORE',
             N'EXECSYNC',                        N'FSAGENT',
             N'FT_IFTS_SCHEDULER_IDLE_WAIT',     N'FT_IFTSHC_MUTEX',
             N'HADR_CLUSAPI_CALL',               N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
             N'HADR_LOGCAPTURE_WAIT',            N'HADR_NOTIFICATION_DEQUEUE',
             N'HADR_TIMER_TASK',                 N'HADR_WORK_QUEUE',
             N'KSOURCE_WAKEUP',                  N'LAZYWRITER_SLEEP',
             N'LOGMGR_QUEUE',                    N'ONDEMAND_TASK_QUEUE',
             N'PWAIT_ALL_COMPONENTS_INITIALIZED',
             N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
             N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
             N'REQUEST_FOR_DEADLOCK_SEARCH',     N'RESOURCE_QUEUE',
             N'SERVER_IDLE_CHECK',               N'SLEEP_BPOOL_FLUSH',
             N'SLEEP_DBSTARTUP',                 N'SLEEP_DCOMSTARTUP',
             N'SLEEP_MASTERDBREADY',             N'SLEEP_MASTERMDREADY',
             N'SLEEP_MASTERUPGRADED',            N'SLEEP_MSDBSTARTUP',
             N'SLEEP_SYSTEMTASK',                N'SLEEP_TASK',
             N'SLEEP_TEMPDBSTARTUP',             N'SNI_HTTP_ACCEPT',
             N'SP_SERVER_DIAGNOSTICS_SLEEP',     N'SQLTRACE_BUFFER_FLUSH',
             N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
             N'SQLTRACE_WAIT_ENTRIES',           N'WAIT_FOR_RESULTS',
             N'WAITFOR',                         N'WAITFOR_TASKSHUTDOWN',
             N'WAIT_XTP_HOST_WAIT',              N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
             N'WAIT_XTP_CKPT_CLOSE',             N'XE_DISPATCHER_JOIN',
             N'XE_DISPATCHER_WAIT',              N'XE_TIMER_EVENT')
     AND  DATEDIFF(ss, s.runtime, e.runtime) > 0
     ORDER BY [Percentage] DESC

END
GO


IF OBJECT_ID('ReportingCharts') IS NOT NULL
DROP PROCEDURE ReportingCharts
GO

CREATE PROCEDURE ReportingCharts
AS
SELECT * FROM tabCharts
GO

--EXECUTE ReportingCharts

