
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

		DECLARE @MachineName VARCHAR(1024)

		SELECT @MachineName = dbo.udf_GetMachineName()
		SET @MachineName = '\\' + @MachineName

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
				AverageCPU = AVG(CounterValue),
				MaxCPU = MAX(CounterValue), 
				CPUStDev = STDEV(CounterValue)
			INTO #WindowsCPU
			FROM
				dbo.CounterData d
				JOIN dbo.CounterDetails dd ON d.CounterID = dd.CounterID
				WHERE dd.ObjectName LIKE 'Processor%'
					AND dd.CounterName LIKE '_ Processor Time'
					AND dd.InstanceName NOT LIKE '_Total'AND
					MachineName = @MachineName
			GROUP BY dd.ObjectName,
				dd.CounterName
		END

		IF (@PowerSaving = 1)
		BEGIN
			SET @Statement = 'Server power settings may affect the performance of your SQL Server. Fixing this is a quick win.'

			INSERT INTO @Output
			SELECT @Statement
		END 

		--IF (@MaxDOP = 1 OR @TF8048 = 1)
		--BEGIN
		--	SET @Statement = 'SQL Server configuration is affecting performance. Fixing this may be a quick win.'

		--	INSERT INTO @Output
		--	SELECT @Statement
		--END 

		IF (@ExpensiveQueriesExist = 1)
		BEGIN
			SET @Statement = 'There are several queries with high logical read cost. This can be hard to remediate since re-writing code can be the only way to improve performance and this may affect your applications.'

			INSERT INTO @Output
			SELECT @Statement
		END 

		IF OBJECT_ID('tempdb..#WindowsCPU') IS NOT NULL
		BEGIN

			SELECT TOP 1 @AvgCPU = AverageCPU
			FROM #WindowsCPU 
			ORDER BY AverageCPU DESC

			IF (@AvgCPU >= 60)
			BEGIN
				SET @Statement = 'CPU usage is high on average. This could be a symptom of several issues inside SQL Server or at Windows level.'

				INSERT INTO @Output
				SELECT @Statement
			END
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
