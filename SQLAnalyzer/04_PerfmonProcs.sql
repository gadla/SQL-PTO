
IF OBJECT_ID('CreateCustomCounter') IS NOT NULL
DROP PROCEDURE CreateCustomCounter
GO
CREATE PROCEDURE CreateCustomCounter
(
@CounterPath1 VARCHAR(1000),
@Operator VARCHAR(1),
@CounterPath2 VARCHAR(1000)

)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @CounterName1 VARCHAR(500), @ObjectName1 VARCHAR(500)
	DECLARE @CounterName2 VARCHAR(500), @ObjectName2 VARCHAR(500)

	SET @ObjectName1 = dbo.ParseCounterObjectName(@CounterPath1)
	SET @ObjectName2 = dbo.ParseCounterObjectName(@CounterPath2)

	SET @CounterName1 = dbo.ParseCounterName (@CounterPath1)
	SET @CounterName2 = dbo.ParseCounterName (@CounterPath2)

	DECLARE @SQL NVARCHAR(MAX)

	SET @SQL = 'SELECT
		TimeStamp = a.CounterDateTime, CookedValue = ' + 
			CASE WHEN @Operator = '/' 
				THEN 'CASE WHEN b.CookedValue = 0 THEN 0 ELSE (a.CookedValue ' + @Operator + ' b.CookedValue) END' 
				ELSE 'a.CookedValue ' + @Operator + ' b.CookedValue' 
			END + '
	FROM 
	(
		SELECT CounterDateTime, CookedValue = CounterValue
		FROM dbo.CounterData d 
		JOIN dbo.CounterDetails dd ON d.CounterID = dd.CounterID
		WHERE dd.countername = @CounterName1 AND
		ObjectName = @ObjectName1 
	) a
	JOIN
	(
		SELECT CounterDateTime, CookedValue = CounterValue
		FROM dbo.CounterData d 
		JOIN dbo.CounterDetails dd ON d.CounterID = dd.CounterID
		WHERE dd.countername = @CounterName2 AND
		ObjectName = @ObjectName2 
	) b ON a.CounterDateTime = b.CounterDateTime
'
	PRINT @SQL 

	EXECUTE sp_executesql
	@stmt = @SQL, 
	@params = N'@CounterName1 VARCHAR(500), @ObjectName1 VARCHAR(500), @CounterName2 VARCHAR(500), @ObjectName2 VARCHAR(500)', 
	@ObjectName1 = @ObjectName1,
	@CounterName1 = @CounterName1,
	@ObjectName2 = @ObjectName2,
	@CounterName2 = @CounterName2
END
GO





IF OBJECT_ID('dbo.ParseCounterObjectName') IS NOT NULL
DROP FUNCTION dbo.ParseCounterObjectName
GO
CREATE FUNCTION dbo.ParseCounterObjectName
(
@CounterPath VARCHAR(1000)
)
RETURNS VARCHAR(500)
AS
BEGIN
	DECLARE @ObjectName VARCHAR(200), @InstanceName VARCHAR(200)
	SET @InstanceName = dbo.ParseInstanceName(@CounterPath)
	IF @InstanceName > ''
	BEGIN
		SET @InstanceName = '(' + @InstanceName + ')'
	END

	SET @CounterPath = REPLACE(@CounterPath, @InstanceName, '')

	SELECT @ObjectName = LTRIM(RTRIM(SUBSTRING(@CounterPath, 
							(CHARINDEX('\',@CounterPath,3)+1), 
							CHARINDEX('\', @CounterPath, (CHARINDEX('\',@CounterPath,3)+1))-(CHARINDEX('\',@CounterPath,3))-1)))
	RETURN(@ObjectName)

END
GO
IF OBJECT_ID('dbo.ParseCounterName') IS NOT NULL
DROP FUNCTION dbo.ParseCounterName
GO
CREATE FUNCTION dbo.ParseCounterName
(
@CounterPath VARCHAR(1000)
)
RETURNS VARCHAR(500)
AS
BEGIN
	DECLARE @ObjectName VARCHAR(200), @CounterName VARCHAR(200)
	SELECT @CounterName = LTRIM(RTRIM(REVERSE(LEFT(REVERSE(@CounterPath), CHARINDEX('\', REVERSE(@CounterPath))-1))))

	RETURN(@CounterName)

END
GO
IF OBJECT_ID('dbo.ParseInstanceName') IS NOT NULL
DROP FUNCTION dbo.ParseInstanceName
GO
CREATE FUNCTION dbo.ParseInstanceName
(
@CounterPath VARCHAR(1000)
)
RETURNS VARCHAR(500)
AS
BEGIN
	--DECLARE @CounterPath VARCHAR(1000) = 'SQLServer:General Statistics'
	DECLARE @InstanceName VARCHAR(200), @Start INT, @End INT
	SET @Start = CHARINDEX('(', @CounterPath)+1
	SET @End = (CHARINDEX(')', @CounterPath)-CHARINDEX('(', @CounterPath))-1

	IF @Start >1
	BEGIN
		SET @InstanceName = SUBSTRING(@CounterPath, @Start, @End)
	END
	ELSE
	BEGIN
		SET @InstanceName = ''
	END
	RETURN(@InstanceName)

END
GO
--select dbo.ParseInstanceName('SQLServer:Databases(tempdb)')

IF OBJECT_ID('dbo.chart_GetCounterData') IS NOT NULL
DROP PROCEDURE dbo.chart_GetCounterData
GO
CREATE PROCEDURE [dbo].[chart_GetCounterData]
(
	@ObjectName VARCHAR(1024),
	@CounterName VARCHAR(1024)
)
AS
BEGIN
	SET NOCOUNT ON
	SELECT 
		CookedValue = CounterValue, 
		TimeStamp = CounterDateTime
	FROM dbo.Counterdata c
	JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
	WHERE 
		CounterName LIKE '%' + @CounterName and
		ObjectName LIKE '%' + @ObjectName
	ORDER BY TimeStamp ASC

END



GO

IF OBJECT_ID('PerfCounter_GetDataByCounter') IS NOT NULL
DROP PROCEDURE PerfCounter_GetDataByCounter
GO
CREATE PROCEDURE [dbo].[PerfCounter_GetDataByCounter]
(
	@CounterPath VARCHAR(1024), 
	@IncludeInstanceName BIT = 0,
	@ReturnAggregate BIT = 0,
	@MinThresholdValue DECIMAL(18,5) = NULL,  --TC 2/28/18 Use for determining if we should generate charts.
	@MaxThresholdValue DECIMAL(18,5) = NULL,  --TC 2/28/18 Use for determining if we should generate charts.
	@FullCounterPath VARCHAR(1024) OUTPUT, 
	@ThresholdReached BIT OUTPUT, 
	@MachineName VARCHAR(1024)
)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @CounterName VARCHAR(500), @ObjectName VARCHAR(500), @InstanceName VARCHAR(500)
	--DECLARE @MachineName VARCHAR(1024)

	--SELECT @MachineName = '\\'+Value
	--FROM dbo.tbl_SCRIPT_ENVIRONMENT_DETAILS
	--WHERE Name = 'Machine Name'

	SET @MachineName = REPLACE(@MachineName, '\\', '')
	SET @MachineName = '\\' + @MachineName

--	DECLARE @CounterPath VARCHAR(1024)
--	SET @CounterPath = '\\CMZPCSQD03\LogicalDisk(R:)\% Idle Time'

	SET @ObjectName = dbo.ParseCounterObjectName(@CounterPath)
	SET @CounterName = dbo.ParseCounterName (@CounterPath)
	SET @InstanceName = dbo.ParseInstanceName(@CounterPath)
	--SET @ObjectName = REPLACE(@ObjectName, @InstanceName, '')
	SET @ObjectName = REPLACE(REPLACE(REPLACE(@ObjectName, '(*)',''),'(',''),')','')

	SET ANSI_NULLS OFF

	IF @ReturnAggregate = 0
	BEGIN
		CREATE TABLE #Results (CookedValue float, TimeStamp char(24), CounterPath varchar(250))
		CREATE INDEX idx_Results ON #Results(CookedValue)

		INSERT INTO #Results(CookedValue, TimeStamp, CounterPath)
		SELECT 
			CookedValue = CounterValue, 
			TimeStamp = CounterDateTime, 
			CounterPath = MachineName + '\' + ObjectName + 
			CASE WHEN @IncludeInstanceName = 1 THEN '(' + InstanceName + ')' ELSE '' END +
			'\' + CounterName
		FROM dbo.Counterdata c
		JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE 
			CounterName = @CounterName and
			ObjectName = @ObjectName and
			ISNULL(InstanceName,'') = CASE WHEN @InstanceName > '' THEN @InstanceName ELSE ISNULL(InstanceName,'') END
			AND MachineName = @MachineName

		SELECT CookedValue, TimeStamp, CounterPath
		FROM #Results
		ORDER BY TimeStamp ASC

		IF @MaxThresholdValue > 0
		BEGIN
			IF EXISTS(SELECT 1 FROM #Results WHERE CookedValue > @MaxThresholdValue)
			BEGIN
				SET @ThresholdReached = 1
			END
			ELSE
			BEGIN
				SET @ThresholdReached = 0
			END
		END
		ELSE
		BEGIN
			SET @ThresholdReached = 0
		END
		
		SET @FullCounterPath = (SELECT TOP(1) CounterPath FROM #Results)
	END
	ELSE
	BEGIN

		DECLARE @ResultsAgg TABLE 
		(
		CounterPath varchar(250), 
		Minimum DECIMAL(18,4), Average DECIMAL(18,4), Maximum DECIMAL(18,4)
		)

		INSERT INTO @ResultsAgg(CounterPath, Minimum, Average, Maximum)
		SELECT 
			CounterPath = MachineName + '\' + ObjectName + 
			CASE WHEN @IncludeInstanceName = 1 THEN '(' + InstanceName + ')' ELSE '' END +
			'\' + CounterName, 
			Minimum = MIN(CounterValue),
			Average = AVG(CounterValue),
			Maximum = MAX(CounterValue)
		FROM dbo.Counterdata c
		JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE 
			CounterName = @CounterName and
			ObjectName = @ObjectName and
			ISNULL(InstanceName,'') = CASE WHEN @InstanceName > '' THEN @InstanceName ELSE ISNULL(InstanceName,'') END
			AND MachineName = @MachineName
		GROUP BY 
			MachineName + '\' + ObjectName + 
			CASE WHEN @IncludeInstanceName = 1 THEN '(' + InstanceName + ')' ELSE '' END +
			'\' + CounterName

		SELECT CounterPath, Minimum, Average, Maximum
		FROM @ResultsAgg

		SET @FullCounterPath = (SELECT TOP(1) CounterPath FROM @ResultsAgg)
	END

	SET ANSI_NULLS ON
END
GO

IF OBJECT_ID('PerfCounter_GetCalculatedRatio') IS NOT NULL
DROP PROCEDURE PerfCounter_GetCalculatedRatio
GO
CREATE PROCEDURE [dbo].PerfCounter_GetCalculatedRatio
(
	@NumeratorCounter VARCHAR(1024), 
	@DemoninatorCounter VARCHAR(1024),
	@MachineName VARCHAR(1024),
	@MinThresholdValue DECIMAL(18,5) = NULL,  --TC 2/28/18 Use for determining if we should generate charts.
	@MaxThresholdValue DECIMAL(18,5) = NULL,  --TC 2/28/18 Use for determining if we should generate charts.
	@FullCounterPath VARCHAR(1024) OUTPUT, 
	@ThresholdReached BIT OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON

	--DECLARE @NumeratorCounter VARCHAR(1024), 
	--@DemoninatorCounter VARCHAR(1024), @MachineName varchar(100)
	DECLARE @NumeratorCounterName VARCHAR(500), @NumeratorObjectName VARCHAR(500), @NumeratorInstanceName VARCHAR(500)
	DECLARE @DenominatorCounterName VARCHAR(500), @DenominatorObjectName VARCHAR(500), @DenominatorInstanceName VARCHAR(500)

	--remove this lookup.  Have this passed in.  If this table doesn't exist, get it elsewhere.
	SELECT @MachineName = REPLACE(@MachineName, '\\', '')
	SET @MachineName = '\\' + @MachineName

	--DECLARE @CounterPath VARCHAR(1024)
--	SET @CounterPath = '\\CMZPCSQD03\LogicalDisk(R:)\% Idle Time'

	SET @NumeratorObjectName = dbo.ParseCounterObjectName(@NumeratorCounter)
	SET @NumeratorCounterName = dbo.ParseCounterName (@NumeratorCounter)
	SET @NumeratorInstanceName = dbo.ParseInstanceName(@NumeratorCounter)
	SET @NumeratorObjectName = REPLACE(REPLACE(REPLACE(@NumeratorCounter, '(*)',''),'(',''),')','')

	SET @DenominatorObjectName = dbo.ParseCounterObjectName(@DemoninatorCounter)
	SET @DenominatorCounterName = dbo.ParseCounterName (@DemoninatorCounter)
	SET @DenominatorInstanceName = dbo.ParseInstanceName(@DemoninatorCounter)
	SET @DenominatorObjectName = REPLACE(REPLACE(REPLACE(@DemoninatorCounter, '(*)',''),'(',''),')','')


	SET ANSI_NULLS OFF


		CREATE TABLE #Results (CookedValue float, TimeStamp datetime, CounterPath varchar(250))
		CREATE INDEX idx_Results ON #Results(CookedValue)

		INSERT INTO #Results(CookedValue, TimeStamp, CounterPath)
		SELECT 
			CookedValue = CounterValue, 
			TimeStamp = CounterDateTime, 
			CounterPath = MachineName + '\' + ObjectName + 
			CASE WHEN 0 = 1 THEN '(' + InstanceName + ')' ELSE '' END +
			'\' + CounterName
		FROM dbo.Counterdata c
		JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE 
			CounterName = @NumeratorCounterName and
			ObjectName = @NumeratorObjectName 
			--ISNULL(InstanceName,'') = CASE WHEN @InstanceName > '' THEN @InstanceName ELSE ISNULL(InstanceName,'') END
			--AND 
			--MachineName = @MachineName

		SELECT CookedValue, TimeStamp, CounterPath
		FROM #Results
		ORDER BY TimeStamp ASC

		IF @MaxThresholdValue > 0
		BEGIN
			IF EXISTS(SELECT 1 FROM #Results WHERE CookedValue > @MaxThresholdValue)
			BEGIN
				SET @ThresholdReached = 1
			END
			ELSE
			BEGIN
				SET @ThresholdReached = 0
			END
		END
		ELSE
		BEGIN
			SET @ThresholdReached = 0
		END
		
		SET @FullCounterPath = (SELECT TOP(1) CounterPath FROM #Results)
	END

GO

--IF OBJECT_ID('PerfCounter_GetLogicalDiskDriveList') IS NOT NULL
--DROP PROCEDURE PerfCounter_GetLogicalDiskDriveList
--GO
--CREATE PROCEDURE [dbo].PerfCounter_GetLogicalDiskDriveList
--AS
--BEGIN
--	SET NOCOUNT ON

--	SELECT 
--		CookedValue = CounterValue, 
--		TimeStamp = CounterDateTime, CounterName, ObjectName, InstanceName,

--	FROM dbo.Counterdata c
--	JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
--	WHERE 
--		ObjectName = 'LogicalDisk' AND
--		InstanceName <> '_Total'

--	SET @FullCounterPath = (SELECT TOP(1) CounterPath FROM @Results)

--	SELECT CookedValue, TimeStamp
--	FROM @Results
--	ORDER BY TimeStamp ASC

--END
--GO


IF OBJECT_ID('PerfCounter_GetDatabaseList') IS NOT NULL
DROP PROCEDURE PerfCounter_GetDatabaseList
GO
CREATE PROCEDURE [dbo].PerfCounter_GetDatabaseList
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	SELECT DISTINCT Name = InstanceName
	FROM dbo.CounterDetails d 
	WHERE 
		ObjectName = 'SQLServer:Databases' AND
		InstanceName <> '_Total'
		AND MachineName = @MachineName
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID('PerfCounter_GetSQLInstanceNames') IS NOT NULL
DROP PROCEDURE PerfCounter_GetSQLInstanceNames
GO
CREATE PROCEDURE [dbo].[PerfCounter_GetSQLInstanceNames]
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @CPUCount INT
	DECLARE @MachineName VARCHAR(1024)
	DECLARE @NumaNodeCount SMALLINT
	DECLARE @InstanceName VARCHAR(1024)

	IF OBJECT_ID('dbo.CounterDetails') IS NOT NULL
	BEGIN
		SELECT @MachineName = dbo.udf_GetMachineName()
		SET @MachineName = '\\' + @MachineName

		SELECT @CPUCount = COUNT(DISTINCT InstanceName)
		FROM dbo.CounterDetails d 
		WHERE ObjectName IN('Processor','Processor Information') AND
		InstanceName <> '_Total'
		AND MachineName = @MachineName

		SELECT 
		@InstanceName = LEFT(ObjectName, CHARINDEX(':',ObjectName)-1)
		FROM dbo.CounterDetails d 
		WHERE 
			MachineName = @MachineName 
			AND(
			ObjectName LIKE '%SQLServer%' OR
			ObjectName LIKE '%MSSQL%')

		IF @CPUCount = 0
		BEGIN
			SELECT @CPUCount = COUNT(DISTINCT InstanceName)
			FROM dbo.CounterDetails d 
			WHERE ObjectName LIKE 'Processor Information' AND
			InstanceName LIKE '%,_Total'
			AND MachineName = @MachineName
		END


		SELECT @NumaNodeCount = COUNT(DISTINCT InstanceName)
		FROM dbo.CounterDetails d 
		WHERE ObjectName LIKE '%:Buffer Node' AND
		MachineName = @MachineName

		SELECT 
		MachineName = REPLACE(@MachineName, '\\',''), 
		InstanceName = @InstanceName,
		NumaNodeCount = @NumaNodeCount,
		ProcessorCount = @CPUCount
	END

	

END
GO

IF OBJECT_ID('PerfCounter_GetInstanceList') IS NOT NULL
DROP PROCEDURE PerfCounter_GetInstanceList
GO
CREATE PROCEDURE PerfCounter_GetInstanceList
(
@ObjectName NVARCHAR(250)
)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	SELECT DISTINCT Name = InstanceName
	FROM dbo.CounterDetails d 
	WHERE 
		ObjectName = @Objectname AND
		InstanceName <> '_Total'
		AND MachineName = @MachineName
END
GO
