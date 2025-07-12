
set statistics io off
set nocount on
go
IF OBJECT_ID('ExecutiveSummary_Memory') IS NOT NULL
DROP PROCEDURE ExecutiveSummary_Memory
GO

CREATE PROCEDURE [dbo].[ExecutiveSummary_Memory]
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

	DECLARE @ServerType VARCHAR(40) = dbo.udf_GetServerType()
	DECLARE @MemoryOutput TABLE(ID INT IDENTITY, Msg VARCHAR(MAX))

	IF @SErverType = 'OnPremisesSQL'
	BEGIN


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
	END

	--'High Database In-Memory OLTP storage percent'

	--INSERT INTO @MemoryOutput
	--SELECT 'This is not on-prem, so Tim will need to figure this out later.'

	SELECT Msg FROM @MemoryOutput
	ORDER BY ID ASC
END


GO
