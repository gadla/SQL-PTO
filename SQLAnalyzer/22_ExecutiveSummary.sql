
set statistics io off
set nocount on
go
IF OBJECT_ID('ExecutiveSummary_CPU') IS NOT NULL
DROP PROCEDURE ExecutiveSummary_CPU
GO
CREATE PROCEDURE [dbo].ExecutiveSummary_CPU
AS
BEGIN
	--Memory
	--IF EXISTS
	--(
	--	SELECT * 
	--	FROM [dbo].[PTOClinicFindings]
	--	WHERE Title = 'The Windows OS power saving setting may affect the CPU Performance.' OR 
	--	Title = 'The SQL Server configuration setting: Max Degree of Parallelism is set to non-optimal value.' OR 
	--	Title = 'High parallelism waits exist in an OLTP environment.' OR 
	--	Title = 'Trace Flag 8048 is not set on a SQL Server with 8 processors or more per NUMA node.'
	--) 
	BEGIN
		DECLARE @Output TABLE(ID INT IDENTITY, Msg VARCHAR(MAX))
		DECLARE @PowerSaving BIT = 0, 
			@MaxDOP BIT = 0, 
			@CXPACKET BIT = 0, 
			@TF8048 BIT = 0,
			@ExpensiveQueriesExist BIT = 0
		DECLARE @AvgCPU DECIMAL (10,2) = 0
		DECLARE @IssuesCount SMALLINT = 0
		DECLARE @Statement NVARCHAR(1024)

		SET @PowerSaving = CASE WHEN EXISTS (SELECT * FROM [dbo].[PTOClinicFindings] WHERE Title = 'The Windows OS power saving setting may affect the CPU Performance.') THEN 1 ELSE 0 END
		SET @MaxDOP = CASE WHEN EXISTS (SELECT * FROM [dbo].[PTOClinicFindings] WHERE Title = 'The SQL Server configuration setting: Max Degree of Parallelism is set to non-optimal value.' ) THEN 1 ELSE 0 END
		SET @CXPACKET = CASE WHEN EXISTS (SELECT * FROM [dbo].[PTOClinicFindings] WHERE Title = 'High parallelism waits exist in an OLTP environment.' ) THEN 1 ELSE 0 END
		SET @TF8048 = CASE WHEN EXISTS (SELECT * FROM [dbo].[PTOClinicFindings] WHERE Title = 'Trace Flag 8048 is not set on a SQL Server with 8 processors or more per NUMA node.' ) THEN 1 ELSE 0 END

		IF OBJECT_ID('cust_ExpensiveQueries') IS NOT NULL
		BEGIN
			IF EXISTS
			(
				SELECT *
				FROM cust_ExpensiveQueries
				WHERE 
					CAST(AverageRunTimeSeconds AS DECIMAL(10,4)) >= 10 
					AND CAST(execution_count AS BIGINT) >= 16 -- Just beacuse it is binary value
			)
			BEGIN
				SET @ExpensiveQueriesExist = 1
			END
		END

		IF OBJECT_ID('dbo.CounterData') IS NOT NULL AND
			OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
		BEGIN
			SELECT
				dd.ObjectName,
				dd.CounterName,
				dd.InstanceName,
				AVGDataBytes = AVG(CounterValue),
				MaxDataBytes = MAX(CounterValue)
			INTO #WindowsCPU
			FROM
				dbo.CounterData d
				JOIN dbo.CounterDetails dd ON d.CounterID = dd.CounterID
				WHERE dd.ObjectName LIKE 'Processor%'
					AND dd.CounterName LIKE '_ Processor Time'
					AND dd.InstanceName LIKE '_Total'
			GROUP BY dd.ObjectName,
				dd.CounterName,
				dd.InstanceName
		END

		IF (@PowerSaving = 1)
		BEGIN
			SET @Statement = 'Server power settings may affect the performance of your SQL Server. Fixing this is a quick win.'

			INSERT INTO @Output
			SELECT @Statement
		END 

		IF (@MaxDOP = 1 OR @TF8048 = 1)
		BEGIN
			SET @Statement = 'SQL Server configuration is affecting performance. Fixing this may be a quick win.'

			INSERT INTO @Output
			SELECT @Statement
		END 

		IF (@MaxDOP = 1 OR @TF8048 = 1)
		BEGIN
			SET @Statement = 'SQL Server configuration is affecting performance. Fixing this may be a quick win.'

			INSERT INTO @Output
			SELECT @Statement
		END 

		IF (@ExpensiveQueriesExist = 1)
		BEGIN
			SET @Statement = 'There are several queries with long execution times. This can be hard to troubleshoot since re writting code can be the only way to improve performance ans this may affect your applications.'

			INSERT INTO @Output
			SELECT @Statement
		END 

		IF (@ExpensiveQueriesExist = 1)
		BEGIN
			SET @Statement = 'There are several queries with long execution times. This can be hard to troubleshoot since re writting code can be the only way to improve performance and this may affect your applications.'

			INSERT INTO @Output
			SELECT @Statement
		END 

		SELECT TOP 1 @AvgCPU = AVGDataBytes FROM #WindowsCPU ORDER BY AVGDataBytes DESC
		IF (@AvgCPU >= 80)
		BEGIN
			SET @Statement = 'CPU usage is high in average. This could be a symptom of several issues inside SQL Server or at Windows level. If the usage es because of SQL Server then this can be hard to troubleshoot since re writting code can be the only way to improve performance and this may affect your applications.'

			INSERT INTO @Output
			SELECT @Statement
		END

		IF (SELECT COUNT(*) FROM @Output) = 0
		BEGIN
			INSERT INTO @Output
			SELECT 'From a CPU perspective, everything looks great on this server.  There are no expensive queries overwhelming the CPU, there is no CPU issues and your CPU configuration settings are properly set.' 
		END
	END

	SELECT Msg FROM @Output
	ORDER BY ID ASC
END

GO



IF OBJECT_ID('ExecutiveSummary_Memory') IS NOT NULL
DROP PROCEDURE ExecutiveSummary_Memory
GO

CREATE PROCEDURE ExecutiveSummary_Memory
AS

----Memory
--IF EXISTS
--(
--	SELECT * 
--	FROM [dbo].[PTOClinicFindings]
--	WHERE Title = 'Low page life expectancy.' OR 
--	Title = 'Too many lazy writes per second.' 

--) 
BEGIN
	DECLARE @MemoryOutput TABLE(ID INT IDENTITY, Msg VARCHAR(MAX))
	DECLARE @LowPLE BIT = 0, @HighLW BIT = 0, @HighPLEDips BIT = 0, @ExpensiveQueriesExist BIT = 0, @WorkingSetContention BIT = 0
	DECLARE @OSMemoryPressure BIT, @IssuesCount SMALLINT = 0

	DECLARE 	
		@ServerMemoryInGB DECIMAL,
		@MaxServerMemoryInGB DECIMAL,
		@OSMemoryInGB DECIMAL,
		@PercentageForOS DECIMAL,
		@AvgGBytes DECIMAL,
		@SQL NVARCHAR(MAX)

	IF OBJECT_ID('tempdb..#PLEDips') IS NOT NULL
	DROP TABLE #PLEDips

	IF OBJECT_ID('tempdb..#SQLProcessWorkingSet') IS NOT NULL
	DROP TABLE #SQLProcessWorkingSet

	IF OBJECT_ID('tempdb..#MemoryConfig') IS NOT NULL
	DROP TABLE #MemoryConfig
				
	CREATE TABLE #PLEDips(DipCount INT)

	CREATE TABLE #MemoryConfig
	(
		ServerMemoryInGB DECIMAL,
		MaxServerMemoryInGB DECIMAL,
		OSMemoryInGB DECIMAL,
		PercentageForOS DECIMAL,
		AvgMBytes DECIMAL,
		MinMBytes DECIMAL,
		MaxMBytes DECIMAL
	)

	INSERT INTO #MemoryConfig
	EXECUTE [dbo].[GetMemoryConfiguration]

	SELECT 
		@ServerMemoryInGB = ServerMemoryInGB,
		@MaxServerMemoryInGB = MaxServerMemoryInGB,
		@OSMemoryInGB = OSMemoryInGB,
		@PercentageForOS = PercentageForOS,
		@AvgGBytes = CAST(AvgMBytes/1024.0 AS DECIMAL(18,2))
	FROM #MemoryConfig
	
	INSERT INTO #PLEDips
	EXECUTE Summary_GetPLEDips

	SET @LowPLE = CASE WHEN EXISTS (SELECT * FROM [dbo].[PTOClinicFindings] WHERE Title = 'Low page life expectancy.') THEN 1 ELSE 0 END
	SET @HighLW = CASE WHEN EXISTS (SELECT * FROM [dbo].[PTOClinicFindings] WHERE Title = 'Too many lazy writes per second.' ) THEN 1 ELSE 0 END
	SET @HighPLEDips = CASE WHEN EXISTS (SELECT * FROM #PLEDips WHERE DipCount > 15 ) THEN 1 ELSE 0 END

	IF OBJECT_ID('cust_ExpensiveQueries') IS NOT NULL
	BEGIN
		IF EXISTS
		(
			SELECT *
			FROM cust_ExpensiveQueries
			WHERE 
			CAST(AverageLogicalReads AS BIGINT) > 10000000 OR
			(CAST(AverageLogicalReads AS BIGINT) > 250000 AND CAST(execution_count AS BIGINT) > 15)
		)
		BEGIN
			SET @ExpensiveQueriesExist = 1
		END
	END

	IF OBJECT_ID('dbo.CounterData') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN

		SELECT
			InstanceName,
			AVGDataBytes = AVG(CounterValue),
			MaxDataBytes = MAX(CounterValue), 
			RowNo = ROW_NUMBER() OVER(ORDER BY AVG(CounterValue) DESC),
			OverallPercentage = 100.0 * cast(AVG(CounterValue) as DECIMAL(18,3)) / SUM (cast(AVG(CounterValue) as DECIMAL(18,3))) OVER()
		INTO #SQLProcessWorkingSet
		FROM
			dbo.CounterData d
			JOIN dbo.CounterDetails dd ON d.CounterID = dd.CounterID
		WHERE 
			dd.countername = 'Working Set' AND
			ObjectName = 'Process' AND
			InstanceName <> '_Total'
		GROUP BY InstanceName

		IF EXISTS
		(
			SELECT *
			FROM #SQLProcessWorkingSet
			WHERE 
				(
					RowNo = 1 AND
					InstanceName NOT LIKE '%sqlservr%'
				) OR
				(
					OverallPercentage < 50 AND
					InstanceName LIKE '%sqlservr%'
				)
		)
		BEGIN
			SET @WorkingSetContention = 1
		END

		IF EXISTS
		(
			SELECT 
				CounterName,MIN(CounterValue), MAX(CounterValue), AVG(CounterValue)
			FROM CounterData d
			INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName = 'Memory' 
			AND CounterName = 'Pages/sec'
			GROUP BY CounterName
			HAVING 
			MAX(CounterValue) >12000 AND
			AVG(CounterValue) > 150
		)
		BEGIN
			SET @OSMemoryPressure = 1
		END 

	END

	IF (@AvgGBytes > @OSMemoryInGB *.5) AND (@OSMemoryInGB > 12)
	BEGIN
		SET @SQL = 'This server has ' + CAST(@ServerMemoryInGB AS VARCHAR(20)) + ' GB of memory. '
		SET @SQL = @SQL + 'The max server memory setting on this server is ' + CAST(@MaxServerMemoryInGB AS VARCHAR(20))
		SET @SQL = @SQL + ' GB, which leaves ' + CAST((@ServerMemoryInGB - @MaxServerMemoryInGB) AS VARCHAR(20)) + 'GB (' +CAST(@PercentageForOS AS VARCHAR(20)) + '%) for the OS.'
		SET @SQL = @SQL + CHAR(10)
		SET @SQL = @SQL + 'The average amount of memory not used by any process on the system is ' + CAST(@AvgGBytes AS VARCHAR(10)) + ' GB.'
		SET @SQL = @SQL + 'Consider allocating 25-50% of this memory to SQL Server by adjusting Max Server Memory for the instance.'

		INSERT INTO @MemoryOutput
		SELECT @SQL
	END 

	IF @LowPLE = 1 AND @HighPLEDips = 1 AND @HighLW = 1 AND @ExpensiveQueriesExist = 1
	BEGIN
		SET @IssuesCount += 1

		INSERT INTO @MemoryOutput
		SELECT 'There are a number of very expensive queries being executed on the system, resulting in a high number of pages in the buffer pool continually being removed to make room for additional pages to satisfy the queries being ran.  These queries should be tuned so that the large scans they are causing do not flood the buffer pool.  '    
	END

	IF @OSMemoryPressure = 1
	BEGIN
		SET @IssuesCount += 1
		INSERT INTO @MemoryOutput
		SELECT  'The operating system is experiencing memory contention, resulting in paging that could result in system-wide outages.  '
	END

	IF @WorkingSetContention = 1
	BEGIN
		SET @IssuesCount += 1

		INSERT INTO @MemoryOutput
		SELECT 'At least one process on this server competing with SQL Server for memory.  On a production-level SQL Server machine, no other application should be challenging SQL Server for memory.  ' 
	END

	IF @IssuesCount = 0
	BEGIN
		INSERT INTO @MemoryOutput
		SELECT 'From a memory perspective, everything looks great on this server.  There are no expensive queries overwhelming the buffer pool, there is no OS-level memory pressure, no processes are competing with SQL Server for process memory, and your memory configuration settings are properly set.  ' 
	END

	SELECT Msg FROM @MemoryOutput
	ORDER BY ID ASC
END


GO

IF OBJECT_ID('Summary_ExpensiveQueries') IS NOT NULL
DROP PROCEDURE Summary_ExpensiveQueries
GO

CREATE PROCEDURE Summary_ExpensiveQueries
AS
BEGIN

	DECLARE @ExpensiveQueryCount BIGINT, @MaxLogicalReads BIGINT

	select @ExpensiveQueryCount = COUNT_BIG(*), @MaxLogicalReads = MAX(CAST(AverageLogicalReads AS BIGINT)) from cust_ExpensiveQueries
	WHERE CAST(AverageLogicalReads AS BIGINT)> 1000000

	IF @ExpensiveQueryCount > 0
	BEGIN
	DECLARE @SQL NVARCHAR(MAX)
	SET @SQL = 'There have been ' + CAST(@ExpensiveQueryCount AS VARCHAR(20)) + ' queries on this system with more than 1M logical reads. '
	SET @SQL = @SQL + ' A logical read is an 8K data or index page read from SQL Server''s buffer pool.  In general, the more pages that a '
	SET @SQL = @SQL + 'query causes to be read from the buffer pool, the more expensive (and longer running) that query is. The attached '
	SET @SQL = @SQL + 'Excel document has a worksheet named "ExpensiveQueries" that outlines the most expensive queries currently executing '
	SET @SQL = @SQL + 'on the system.'
	SET @SQL = @SQL + CHAR(10) + CHAR(10)
	SET @SQL = @SQL + 'In some cases, simply adding indexes suggested on the Excel worksheet (UsefulIndexes) can assist in execution time '
	SET @SQL = @SQL + 'for these queries.  In other cases more advanced tuning techniques may be necessary.'
	PRINT @SQL

	END
END
GO

IF OBJECT_ID('ExecutiveSummary_Disk') IS NOT NULL
DROP PROCEDURE ExecutiveSummary_Disk
GO
CREATE PROCEDURE [dbo].[ExecutiveSummary_Disk]
AS
BEGIN

	DECLARE @Output TABLE(ID INT IDENTITY, Msg VARCHAR(MAX))

	--Disk 
	--latency?
	--pending IOs?
	--high pageiolatch
	--high disk stalls
	--something competing with sql for IO

	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[PTOClinicFindings]
		WHERE Title = 'Disk response times are too long.'
	)
	BEGIN

		BEGIN
			INSERT INTO @Output
			SELECT Msg = 'Disk response times were noticed.'
		END

	END

	IF NOT EXISTS(SELECT 1 FROM @Output)
	BEGIN
		INSERT INTO @Output
		SELECT Msg = 'No disk related issues were noticed in the captured workload.'
	END

	SELECT Msg
	FROM @Output
END
GO


IF OBJECT_ID('ExecutiveSummary_Concurrency') IS NOT NULL
DROP PROCEDURE ExecutiveSummary_Concurrency
GO


CREATE PROCEDURE [dbo].[ExecutiveSummary_Concurrency]
AS
BEGIN
	DECLARE @Output TABLE(ID INT IDENTITY, Msg VARCHAR(MAX))

	IF OBJECT_ID('tempdb..#BlockedProcessOverview') IS NOT NULL
	DROP TABLE #BlockedProcessOverview

	CREATE TABLE #BlockedProcessOverview
	(
		CounterName VARCHAR(200),
		CounterAvg VARCHAR(30),
		CounterMin VARCHAR(30),
		CounterMax VARCHAR(30)
	)
	INSERT INTO #BlockedProcessOverview
	EXECUTE GetBlockedProcessOverview

	DECLARE @CounterAvgLockWaits DECIMAL(18,2), @CounterMinLockWaits DECIMAL(18,2), @CounterMaxLockWaits DECIMAL(18,2)
	DECLARE @CounterAvgBlocked DECIMAL(18,2), @CounterMinBlocked DECIMAL(18,2), @CounterMaxBlocked DECIMAL(18,2)
	SELECT
		@CounterAvgLockWaits = CounterAvg,
		@CounterMinLockWaits = CounterMin
		--@CounterMaxLockWaits = CAST(CounterMax AS DECIMAL(18,2))
	FROM #BlockedProcessOverview
	WHERE CounterName = 'Lock waits (ms)'
	
	SELECT
		@CounterAvgBlocked = CounterAvg, 
		@CounterMinBlocked = CounterMin
		--@CounterMaxBlocked = CAST(CounterMax AS DECIMAL(18,2))
	FROM #BlockedProcessOverview
	WHERE CounterName = 'Processes blocked'
	

	IF @CounterAvgLockWaits > 100
	BEGIN
		INSERT INTO @Output
		SELECT 'The average time spent waiting for a lock request to be granted on this system is ' + CAST(@CounterAvgLockWaits AS VARCHAR(20)) + ' milliseconds.'
	END

	IF @CounterAvgBlocked > 2
	BEGIN
		INSERT INTO @Output
		SELECT 'The average number of processes being blocked on this system at any given time during the capture was ' + CAST(@CounterAvgBlocked AS VARCHAR(20)) + '. Consider enabling RCSI.'
	END

	IF NOT EXISTS(SELECT * FROM @Output)
	BEGIN
		SELECT Msg = 'No concurrency issues detected in the captured workload.'
	END
	ELSE
	BEGIN
		SELECT Msg FROM @Output
	END
END
GO



