/*
Written by:  Tim Chapman
*/
/*
	SYSTEM INFORMATION
*/
SET NOCOUNT ON
GO
IF OBJECT_ID('PTOClinicFindings') IS NOT NULL
DROP TABLE PTOClinicFindings
GO
CREATE TABLE dbo.PTOClinicFindings
(
	[Title] nvarchar(512),
	[Category] nvarchar(64),
	[Severity] nvarchar(32),
	[Impact] nvarchar(MAX),
	[Recommendation] nvarchar(MAX),
	[Reading] nvarchar(MAX), 
	SummaryCategory nvarchar(64) NULL
)
GO

IF OBJECT_ID('dbo.cust_SQLPerfmonInstances') IS NOT NULL
DROP TABLE dbo.cust_SQLPerfmonInstances
GO
--Housekeeping
IF OBJECT_ID('tbl_spconfigure') IS NOT NULL
BEGIN
	IF EXISTS(SELECT *
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = 'tbl_SPCONFIGURE' AND COLUMN_NAME = 'value_in_use')
	BEGIN
		EXECUTE sp_rename 'dbo.tbl_SPCONFIGURE.value_in_use', 'run_value', 'COLUMN';
	END
END
GO
IF OBJECT_ID('cust_OSInfo') IS NOT NULL
BEGIN
	IF EXISTS(SELECT *
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = 'cust_OSInfo'
		AND COLUMN_NAME = 'physical_memory_kb')
	BEGIN
		EXECUTE sp_rename 'dbo.cust_OSInfo.physical_memory_kb', 'physical_memory_in_bytes', 'COLUMN';

		EXECUTE('UPDATE dbo.cust_OSInfo
		SET physical_memory_in_bytes = CAST(physical_memory_in_bytes AS NUMERIC) * 1024')
	END
END

GO
IF OBJECT_ID('cust_OSInfo') IS NOT NULL
BEGIN

	IF NOT EXISTS(SELECT *
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = 'cust_OSInfo'
		AND COLUMN_NAME = 'bpool_committed')
	BEGIN
		EXECUTE('ALTER TABLE dbo.cust_OSInfo ADD bpool_committed INT')
	END
END
GO
IF OBJECT_ID('cust_OSInfo') IS NOT NULL
BEGIN
	IF NOT EXISTS(SELECT *
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = 'cust_OSInfo'
		AND COLUMN_NAME = 'bpool_commit_target')
	BEGIN
		EXECUTE('ALTER TABLE dbo.cust_OSInfo ADD bpool_commit_target INT')
	END
END
	GO
IF OBJECT_ID('cust_OSInfo') IS NOT NULL
BEGIN
	IF NOT EXISTS(SELECT *
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = 'cust_OSInfo'
		AND COLUMN_NAME = 'bpool_visible')
	BEGIN
		EXECUTE('ALTER TABLE dbo.cust_OSInfo ADD bpool_visible INT')
	END
END
	GO
IF OBJECT_ID('cust_OSInfo') IS NOT NULL
BEGIN
	IF NOT EXISTS(SELECT *
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = 'cust_OSInfo'
		AND COLUMN_NAME = 'physical_memory_in_bytes')
	BEGIN
		EXECUTE('ALTER TABLE dbo.cust_OSInfo ADD physical_memory_in_bytes INT')
	END
END
	GO



IF OBJECT_ID('tbl_SPCONFIGURE') IS NULL
BEGIN
	CREATE TABLE tbl_SPCONFIGURE
	(
		name varchar(50),
		run_value varchar(250)
	)

	IF OBJECT_ID('cust_SPConfigure') IS NOT NULL
	BEGIN
		INSERT INTO tbl_SPCONFIGURE
		SELECT name, value_in_use
		FROM cust_SPConfigure
	END
	ELSE IF OBJECT_ID('tbl_Sys_Configurations') IS NOT NULL
	BEGIN
		INSERT INTO tbl_SPCONFIGURE
		SELECT name, value_in_use
		FROM [dbo].[tbl_Sys_Configurations]
	END

END

IF OBJECT_ID('dbo.cust_GetStats') IS NOT NULL
BEGIN
	BEGIN TRY
		UPDATE dbo.cust_GetStats
		SET RowCnt = NULL
		WHERE RowCnt = 'NULL'
	END TRY
	BEGIN CATCH
	END CATCH

	BEGIN TRY
		UPDATE dbo.cust_GetStats
		SET RowsSampled = NULL
		WHERE RowsSampled = 'NULL'
	END TRY
	BEGIN CATCH
	END CATCH

	BEGIN TRY
		UPDATE dbo.cust_GetStats
		SET RowMods = NULL
		WHERE RowMods = 'NULL'
	END TRY
	BEGIN CATCH
	END CATCH

	ALTER TABLE dbo.cust_GetStats
	ALTER COLUMN RowCnt BIGINT

	ALTER TABLE dbo.cust_GetStats
	ALTER COLUMN RowsSampled BIGINT

	ALTER TABLE dbo.cust_GetStats
	ALTER COLUMN RowMods BIGINT
END

IF NOT EXISTS(SELECT *
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = 'cust_MemoryClerks' AND COLUMN_NAME = 'Pages_KB') AND
	OBJECT_ID('cust_MemoryClerks') IS NOT NULL
BEGIN
	ALTER TABLE cust_MemoryClerks
	ADD Pages_KB INT

	EXECUTE ('UPDATE cust_MemoryClerks
	SET Pages_KB = CAST(single_pages_kb AS BIGINT) + CAST(multi_pages_kb AS BIGINT)')
END


DECLARE @CDPK NVARCHAR(255), @SQL NVARCHAR(MAX)
SELECT @CDPK = CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE table_name = 'CounterData' And
	CONSTRAINT_TYPE = 'PRIMARY KEY'
--this will fail if other indexes in 2014.  I'll fix it later.

IF 
OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
	OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
BEGIN

	IF @CDPK > ''
	BEGIN
		SET @SQL = 'ALTER TABLE dbo.CounterData DROP CONSTRAINT ' + @CDPK
		EXECUTE (@SQL)
	END

	--IF CAST(SERVERPROPERTY('ProductMajorVersion') AS DECIMAL) >= 12
	--BEGIN
	--	CREATE CLUSTERED COLUMNSTORE INDEX ccix_CounterData
	--	ON dbo.CounterData
	--END
	--ELSE
	--BEGIN
	IF INDEXPROPERTY(OBJECT_ID('dbo.CounterData'), 'idx_CounterData_Counter ', 'IndexID') IS NULL
		BEGIN
		CREATE CLUSTERED INDEX idx_CounterData_Counter 
			ON dbo.CounterData(CounterID, CounterDateTime, CounterValue)
	END
	--END

	IF INDEXPROPERTY(OBJECT_ID('dbo.CounterDetails'), 'idx_CounterDetails_Counter ', 'IndexID') IS NULL
	BEGIN
		CREATE NONCLUSTERED INDEX idx_CounterDetails_Counter 
	ON dbo.CounterDetails(CounterName, ObjectName)
	INCLUDE(MachineName)
	END

	SELECT DISTINCT MachineName
	INTO dbo.cust_SQLPerfmonInstances
	FROM dbo.CounterDetails
END
--ALTER VIEW vw_Counterdata
--WITH SCHEMABINDING
--AS
--	SELECT 
--		CookedValue = CounterValue, 
--		TimeStamp = CounterDateTime, 
--		CounterName, 
--		ObjectName,
--		CounterPath = MachineName + '\' + ObjectName + '\' + CounterName, 
--		c.GUID
--	FROM dbo.Counterdata c
--	JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
--GO
--CREATE UNIQUE CLUSTERED INDEX cix_vwCounterdata on dbo.vw_CounterData (CounterName, ObjectName, GUID)
--GO
IF OBJECT_ID('udf_CleanUpString') IS NOT NULL
DROP FUNCTION udf_CleanUpString
GO
CREATE FUNCTION [dbo].udf_CleanUpString 
(
@String AS VARCHAR(1000)
)
RETURNS VARCHAR(1000)
AS
BEGIN
	DECLARE @x AS INT
	SET @x = PATINDEX('%[^ -~0-9A-Z]%', @String COLLATE LATIN1_GENERAL_BIN)

	WHILE @x > 0 
	BEGIN
		SET @String = REPLACE(@String COLLATE LATIN1_GENERAL_BIN, SUBSTRING(@String, @x, 1), '')
		SET @x = PATINDEX('%[^ -~0-9A-Z]%', @String COLLATE LATIN1_GENERAL_BIN)
	END
	RETURN @String
END
GO
IF OBJECT_ID('fn_SortIncludedColumns') IS NOT NULL
DROP FUNCTION fn_SortIncludedColumns
GO
CREATE FUNCTION fn_SortIncludedColumns
(
@TableName VARCHAR(255), 
@EqualityColumns VARCHAR(MAX),
@ColList VARCHAR(MAX), 
@Delimiter CHAR(1) = ','
)
RETURNS @SortedCols TABLE
(ColList VARCHAR(MAX),
	ColHash INT)
AS
BEGIN
	DECLARE @Cols VARCHAR(MAX)

	DECLARE @ColListTable TABLE
(
		ColName VARCHAR(255)
)
	INSERT INTO @ColListTable
		(ColName)
	SELECT DISTINCT
		SUBSTRING(@Delimiter + @ColList + @Delimiter, RowNo + 1,
CHARINDEX(@Delimiter, @Delimiter + @ColList + @Delimiter, RowNo + 1)- RowNo -1)
	FROM
		( 
	SELECT RowNo = ROW_NUMBER() OVER(ORDER BY a.number ASC)
		FROM
			master..spt_values a 
	CROSS APPLY master..spt_values b
		WHERE 
	a.type = 'P' AND b.type = 'P' AND
			a.number < 200 AND b.number < 200
)x
	WHERE 
RowNo <= (LEN(@Delimiter + @ColList + @Delimiter) - 1) AND
		SUBSTRING(@Delimiter + @ColList + @Delimiter, RowNo, 1) = @Delimiter


	SELECT @Cols = (SELECT DISTINCT ColName = ColName + ','
		FROM @ColListTable
		ORDER BY ColName ASC
		FOR XML PATH('')
)

	SELECT @Cols = LEFT(@Cols, LEN(@Cols)-1)

	INSERT INTO @SortedCols
	SELECT @Cols, BINARY_CHECKSUM(@TableName + @EqualityColumns + @Cols)
	RETURN
END
GO
IF OBJECT_ID('udf_GetServerType') IS NOT NULL
DROP FUNCTION dbo.udf_GetServerType
GO
CREATE FUNCTION dbo.udf_GetServerType()
RETURNS VARCHAR(40)
AS
BEGIN
	DECLARE @ServerType VARCHAR(40)

	IF OBJECT_ID('tbl_ServerProperties') IS NOT NULL
	BEGIN
		IF EXISTS
		(
			SELECT *
			FROM [dbo].[tbl_ServerProperties] 
			WHERE PropertyName = 'EngineEdition' AND
			PropertyValue = '5'
		)
		BEGIN
			IF EXISTS
			(
				SELECT *
				FROM [dbo].[tbl_ServerProperties] 
				WHERE PropertyName = 'DatabaseEdition' AND
				PropertyValue = 'Hyperscale'
			)
			BEGIN
				SET @ServerType = 'AzureSQLDBHyperscale'
			END
			ELSE
			BEGIN
				SET @ServerType = 'AzureSQLDB'
			END
		END
		ELSE IF EXISTS
		(
			SELECT *
			FROM [dbo].[tbl_ServerProperties] 
			WHERE PropertyName = 'EngineEdition' AND
			PropertyValue = '8'
		)
		BEGIN
			SET @ServerType = 'AzureSQLManagedInstance'
		END
		ELSE
			SET @ServerType = 'OnPremisesSQL'
	END

	RETURN( @ServerType )

END
GO

----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetSystemInformation') IS NOT NULL
DROP PROCEDURE GetSystemInformation
GO

CREATE PROCEDURE [dbo].[GetSystemInformation]
AS
BEGIN
	DECLARE @MajorVersion INT

	IF OBJECT_ID('tbl_SCRIPT_ENVIRONMENT_DETAILS') IS NOT NULL
	BEGIN
		SELECT @MajorVersion = CAST(LEFT(Value, CHARINDEX('.',Value)-1) AS BIGINT)
		FROM [dbo].[tbl_SCRIPT_ENVIRONMENT_DETAILS]
		WHERE Name = 'SQL Version (SP)'
	END

	CREATE TABLE #TempOSInfo
	(
		ValueName varchar(200),
		Value nvarchar(300),
		Ranker INT
	)

	IF OBJECT_ID('dbo.cust_OSInfo') IS NOT NULL
	BEGIN
		INSERT INTO #TempOSInfo
			(ValueName, Value)
		SELECT 'SchedulerCount', scheduler_count
		FROM dbo.cust_OSInfo

		--IF @MajorVersion < 11
		BEGIN
			INSERT INTO #TempOSInfo
				(ValueName, Value)
			SELECT 'MemoryGB', MemoryGB = cast(physical_memory_in_bytes as bigint)/1024.0/1024.0/1024.0
			FROM dbo.cust_OSInfo
		END

		INSERT INTO #TempOSInfo
			(ValueName, Value)
		SELECT 'cpu_count', cpu_count
		FROM dbo.cust_OSInfo

		INSERT INTO #TempOSInfo
			(ValueName, Value)
		SELECT 'hyperthread_ratio', hyperthread_ratio
		FROM dbo.cust_OSInfo

		IF @MajorVersion < 11
			BEGIN
			INSERT INTO #TempOSInfo
				(ValueName, Value)
			SELECT 'bpool_committed', bpool_committed
			FROM dbo.cust_OSInfo
		END

		IF @MajorVersion < 11
			BEGIN
			INSERT INTO #TempOSInfo
				(ValueName, Value)
			SELECT 'bpool_commit_target', bpool_commit_target
			FROM dbo.cust_OSInfo
		END

		IF @MajorVersion < 11
			BEGIN
			INSERT INTO #TempOSInfo
				(ValueName, Value)
			SELECT 'bpool_visible', bpool_visible
			FROM dbo.cust_OSInfo
		END

		INSERT INTO #TempOSInfo
			(ValueName, Value)
		SELECT 'max_workers_count', max_workers_count
		FROM dbo.cust_OSInfo

		INSERT INTO #TempOSInfo
			(ValueName, Value)
		SELECT 'scheduler_count', scheduler_count
		FROM dbo.cust_OSInfo

		INSERT INTO #TempOSInfo
			(ValueName, Value)
		SELECT 'scheduler_total_count', scheduler_total_count
		FROM dbo.cust_OSInfo

		INSERT INTO #TempOSInfo
			(ValueName, Value)
		SELECT 'sqlserver_start_time', sqlserver_start_time
		FROM dbo.cust_OSInfo

	--INSERT INTO #Temp(ValueName, Value)
	--SELECT 'virtual_machine_type_desc', virtual_machine_type_desc
	--FROM dbo.cust_OSInfo
	END
	ELSE IF OBJECT_ID('cust_MSInfo') IS NOT NULL
	BEGIN
		DECLARE @ServerMemoryMB BIGINT

		SELECT
			@ServerMemoryMB = CASE 
				WHEN Metric = 'GB' THEN Val*1024.00
				WHEN Metric = 'TB' THEN Val*1024.00*1024.00
				END
		FROM
			(
			SELECT
				Val = dbo.udf_CleanUpString(CAST(LTRIM(RTRIM(LEFT(Mem, CHARINDEX(' ', Mem)))) AS VARCHAR(20))),
				Metric = SUBSTRING(Mem, CHARINDEX(' ', Mem)+1, 2)
			FROM
				(
				SELECT Mem = REPLACE((LTRIM(RTRIM(REPLACE(InfoDesc, 'Total Physical Memory', '')))),',','.')
				FROM [dbo].[cust_MSInfo]
				WHERE InfoDesc LIKE '%Total Physical Memory%'

			)x
		) y

		INSERT INTO #TempOSInfo
			(ValueName, Value)
		SELECT 'System Memory', CAST(@ServerMemoryMB/1024.0 AS VARCHAR(20)) + ' GB'

	END

	IF OBJECT_ID('dbo.tbl_SCRIPT_ENVIRONMENT_DETAILS') IS NOT NULL
	BEGIN
		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT Name, Value, 1
		FROM dbo.tbl_SCRIPT_ENVIRONMENT_DETAILS
		WHERE Name IN('SQL Server Name','Machine Name','SQL Version (SP)','Edition')
	END
	IF OBJECT_ID('dbo.tbl_XPMSVER') IS NOT NULL
	BEGIN
		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT Name, COALESCE(CAST(Character_Value as varchar(1000)), cast(Internal_Value as varchar(1000))), 2
		FROM dbo.tbl_XPMSVER
		WHERE Name IN(
		'Platform',
		'FileVersion',
		'OriginalFilename',
		'PrivateBuild',
		'SpecialBuild',
		'WindowsVersion',
		'ProcessorCount',
		'ProcessorActiveMask',
		'ProcessorType')
	END

	IF OBJECT_ID('dbo.cust_RTDSC') IS NOT NULL
	BEGIN
		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT
			LineSetting = LTRIM((LEFT(LineDesc,charindex(':',LineDesc)-1))),
			LineValue = LTRIM((SUBSTRING(LineDesc,(charindex(':',LineDesc)+1), LEN(LineDesc)))),
			3
		FROM [dbo].[cust_RTDSC]
		WHERE Category IN('Processor')
	END

	IF OBJECT_ID('cust_ErrorLog') IS NOT NULL
	BEGIN
		--grab some info about the instance we dont' have yet
		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT TOP(1)
			'Instant File Initialization', LTRIM(RTRIM(SUBSTRING(ErrorMessage, CHARINDEX(':', ErrorMessage)+2, 
			CHARINDEX('.',ErrorMessage)-CHARINDEX(':', ErrorMessage)-2))),
			50
		FROM cust_ErrorLog
		WHERE CHARINDEX('Instant File Initialization',ErrorMessage)>0


		IF EXISTS(SELECT *
		FROM #TempOSInfo
		WHERE ValueName = 'Instant File Initialization' AND Value <> 'Enabled')
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		SELECT 'Instant File Initialization is not enabled.', 'Database Design', 'Critical', NULL, NULL, NULL

		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT TOP(1)
			'LicensedCores', SUBSTRING(ErrorMessage, CHARINDEX('; using ', ErrorMessage)+2, (CHARINDEX('licensing.',ErrorMessage))-CHARINDEX('; using ', ErrorMessage)+7),
			51
		FROM cust_ErrorLog
		WHERE CHARINDEX('logical processors per socket',ErrorMessage)>0

		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT TOP(1)
			'SystemManufacturer', SUBSTRING(ErrorMessage, CHARINDEX('Manufacturer:', ErrorMessage)+14, LEN(ErrorMessage)),
			51
		FROM cust_ErrorLog
		WHERE CHARINDEX('System Manufacturer:',ErrorMessage)>0


		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT TOP(1)
			'WindowsVersion', ErrorMessage,
			52
		FROM cust_ErrorLog
		WHERE CHARINDEX('on Windows NT',ErrorMessage)>0

		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT TOP(1)
			'AuthenticationMode', SUBSTRING(ErrorMessage, CHARINDEX(' ', ErrorMessage)+1,LEN(ErrorMessage)),
			52
		FROM cust_ErrorLog
		WHERE CHARINDEX('Authentication',ErrorMessage)>0

		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT TOP(1)
			'MemoryManager', LEFT(ErrorMessage, CHARINDEX('.',ErrorMessage)),
			53
		FROM cust_ErrorLog
		WHERE CHARINDEX('memory manager',ErrorMessage)>0

		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT TOP(1)
			'HyperVisor', 'Yes',
			53
		FROM cust_ErrorLog
		WHERE CHARINDEX('Hypervisor',ErrorMessage)>0

		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT TOP(1)
			'MirroringEnabled', 'Database mirroring has been enabled on this instance of SQL Server.',
			54
		FROM cust_ErrorLog
		WHERE CHARINDEX('Database mirroring has been enabled',ErrorMessage)>0

		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT TOP(1)
			'SocketCounts', SUBSTRING(ErrorMessage, CHARINDEX('Server SQL Server detected ', ErrorMessage)+27, (CHARINDEX('sockets ',ErrorMessage))-CHARINDEX('Server SQL Server detected ', ErrorMessage)+4),
			55
		FROM cust_ErrorLog
		WHERE CHARINDEX('Server SQL Server detected ',ErrorMessage)>0

	END

	IF OBJECT_ID('tbl_ServerProperties') IS NOT NULL
	BEGIN
		INSERT INTO #TempOSInfo
			(ValueName, Value, Ranker)
		SELECT PropertyName, PropertyValue, 55
		FROM tbl_ServerProperties
		WHERE PropertyName NOT IN(SELECT ValueName
		FROM #TempOSInfo)

	END

	SELECT DISTINCT ValueName AS Setting, Value AS SettingValue, Ranker = ISNULL(Ranker, 99)
	INTO #AllInfo
	FROM #TempOSInfo

	SELECT 
		Setting, 
		SettingValue = 
			CASE 
				WHEN Setting = 'EngineEdition' THEN 
					CASE SettingValue	
						WHEN '1' THEN 'Desktop Engine'
						WHEN '2' THEN 'Standard'
						WHEN '3' THEN 'Enterprise'
						WHEN '5' THEN 'SQL Database'
						WHEN '6' THEN 'Azure Synapse'
						WHEN '8' THEN 'Managed Instance'
					END
			ELSE SettingValue 
			END
	FROM #AllInfo
	ORDER BY Ranker ASC

END

GO
IF OBJECT_ID('GetStats') IS NOT NULL
DROP PROCEDURE GetStats
GO
CREATE PROCEDURE [dbo].[GetStats]
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_GetStats') IS NOT NULL
	BEGIN

		--stats
		SELECT
			TableName,
			DBName,
			SampleRatePercent = CAST(((RowsSampled*1.0/RowCnt)*100.00) AS DECIMAL(18,4)),
			StatName,
			Updated,
			RowCnt,
			RowsSampled,
			UnfilteredRows
		--INTO #Stats
		FROM
			dbo.cust_GetStats
		WHERE 
			(
				(
					RowCnt > 10000 AND
					(RowsSampled*1.0/RowCnt) < .30 AND
					StatName NOT LIKE '_WA_Sys_%'
				) OR 
				RowsSampled IS NULL
			) AND
			DBName NOT IN('tempdb','master','msdb','model')
		ORDER BY RowCnt DESC, (RowsSampled*1.0/RowCnt) asc
	END
END
GO
IF OBJECT_ID('GetMemoryConfiguration') IS NOT NULL
DROP PROCEDURE GetMemoryConfiguration
GO
CREATE PROCEDURE [dbo].[GetMemoryConfiguration]
AS
BEGIN

	DECLARE @MachineName VARCHAR(1024)
	DECLARE @ServerType VARCHAR(40) = dbo.udf_GetServerType()

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName


	IF OBJECT_ID('tempdb..#SPConfigure') IS NOT NULL
	DROP TABLE #SPConfigure

	IF OBJECT_ID('tempdb..#TempMemConfig') IS NOT NULL
	DROP TABLE #TempMemConfig

	CREATE TABLE #SPConfigure
	(
		name varchar(50),
		run_value varchar(250)
	)

	IF OBJECT_ID('dbo.tbl_SPCONFIGURE') IS NOT NULL
	BEGIN
		INSERT INTO #SPConfigure
		SELECT *
		FROM dbo.tbl_SPCONFIGURE
		WHERE replace(run_value, '-', '') <> '' AND isnumeric(run_value)=1
	END
	ELSE IF OBJECT_ID('dbo.cust_SPConfigure') IS NOT NULL
	BEGIN
		INSERT INTO #SPConfigure
		SELECT *
		FROM dbo.cust_SPConfigure
		WHERE replace(value_in_use, '-', '') <> '' AND isnumeric(value_in_use)=1
	END
	--check to see how much memory is allocated to the OS
	--compare this value to Available MBytes

	SELECT
		ServerMemoryInMB = CAST(0 AS DECIMAL(18,2)),
		MaxServerMemoryInMB = MaxServerMemory,
		OSMemory = CAST(0 AS DECIMAL(18,2)),
		PercentageForOS = CAST(0 AS DECIMAL(18,2)),
		AvgMBytes = CAST(0 AS DECIMAL), MinMBytes= CAST(0 AS DECIMAL), MaxMBytes= CAST(0 AS DECIMAL)
	INTO #TempMemConfig
	FROM
	(
		SELECT
			--ServerMemoryInMB = (SELECT CAST(physical_memory_in_bytes AS BIGINT)/1024.0/1024.0 FROM dbo.cust_OSInfo) , 
			MaxServerMemory = MAX(CAST(run_value AS BIGINT))
		FROM #SPConfigure
		WHERE name in('max server memory (MB)')

	) mem

	IF OBJECT_ID('dbo.cust_OSInfo') IS NOT NULL
	BEGIN
		UPDATE t
		SET ServerMemoryInMB = (SELECT MAX(CAST(physical_memory_in_bytes AS BIGINT))/1024.0/1024.0
			FROM dbo.cust_OSInfo)
		FROM #TempMemConfig t

	END

	DECLARE @ServerMemoryMB BIGINT
	IF @@ROWCOUNT =0 AND OBJECT_ID('cust_MSInfo') IS NOT NULL
	BEGIN

		SELECT
			@ServerMemoryMB = 
		CASE 
			WHEN Metric = 'GB' THEN CAST(Val AS NUMERIC)*1024.00
			WHEN Metric = 'TB' THEN CAST(Val AS NUMERIC)*1024.00*1024.00
			END
		FROM
			(
		SELECT
				Val = dbo.udf_CleanUpString(CAST(LTRIM(RTRIM(LEFT(Mem, CHARINDEX(' ', Mem)))) AS VARCHAR(20))),
				Metric = SUBSTRING(Mem, CHARINDEX(' ', Mem)+1, 2)
			FROM
				(
			SELECT Mem = REPLACE((LTRIM(RTRIM(REPLACE(InfoDesc, 'Total Physical Memory', '')))),',','.')
				FROM [dbo].[cust_MSInfo]
				WHERE InfoDesc LIKE '%Total Physical Memory%'

				)x
			) y
	END
	ELSE IF OBJECT_ID('tbl_ServerProperties') IS NOT NULL
	BEGIN
			SELECT @ServerMemoryMB = CAST(PropertyValue AS BIGINT)/1024.0
			FROM [dbo].[tbl_ServerProperties]
			WHERE PropertyName = 'physical_memory_kb'
	END

	UPDATE t
	SET 
		ServerMemoryInMB = ISNULL(@ServerMemoryMB, ServerMemoryInMB)
	FROM #TempMemConfig t

	UPDATE t
	SET
	PercentageForOS = CASE WHEN MaxServerMemoryInMB > ServerMemoryInMB THEN 0 ELSE ((ServerMemoryInMB - MaxServerMemoryInMB) / ServerMemoryInMB) * 100 END,
	OSMemory = CASE WHEN MaxServerMemoryInMB > ServerMemoryInMB THEN 0 ELSE (ServerMemoryInMB - MaxServerMemoryInMB) END
	FROM #TempMemConfig t

	IF OBJECT_ID('dbo.CounterData') IS NOT NULL AND
	OBJECT_ID('dbo.CounterDetails') IS NOT NULL AND
	OBJECT_ID('dbo.tbl_SCRIPT_ENVIRONMENT_DETAILS') IS NOT NULL
	BEGIN
		UPDATE t
		SET AvgMBytes = x.AvgMBytes, 
		MinMBytes = x.MinMBytes, 
		MaxMBytes = x.MaxMBytes
		FROM #TempMemConfig t
		CROSS JOIN 
		(
			SELECT
					AvgMBytes = avg(FirstValueA), MinMBytes = MIN(FirstValueA), MaxMBytes = max(FirstValueA)
				FROM dbo.CounterData
				WHERE CounterID =(
			SELECT CounterID
				FROM dbo.CounterDetails
				WHERE countername = 'Available MBytes' AND
					MachineName = REPLACE(@MachineName, '\\', '')
			)
		)x
	END

	IF @ServerType <> 'OnPremisesSQL'
	BEGIN
		IF OBJECT_ID('cust_JobObjects') IS NOT NULL
		BEGIN
			SELECT
				ServerMemoryInGB = ServerMemoryInMB/1024.0,
				MaxServerMemoryInGB = MaxServerMemoryInMB/1024.0, 
				x.*
			FROM #TempMemConfig
			CROSS JOIN
			(
				SELECT 
					memory_limit_gb = CAST(memory_limit_mb AS BIGINT)/1024.0, 
					process_memory_limit_gb = CAST(process_memory_limit_mb AS BIGINT)/1024.0, 
					non_sos_mem_gap_gb = CAST(non_sos_mem_gap_mb AS BIGINT)/1024.0, 
					low_mem_signal_threshold_gb = CAST(low_mem_signal_threshold_mb AS BIGINT)/1024.0, 
					peak_job_memory_used_gb = CAST(peak_job_memory_used_mb AS BIGINT)/1024.0, 
					peak_process_memory_used_gb = CAST(peak_process_memory_used_mb AS BIGINT)/1024.0
				FROM cust_JobObjects
			) x
		END
		ELSE
		BEGIN
			SELECT
				ServerMemoryInGB = ServerMemoryInMB/1024.0,
				MaxServerMemoryInGB = MaxServerMemoryInMB/1024.0
			FROM #TempMemConfig
		END

	END 
	ELSE
	BEGIN
		SELECT
			ServerMemoryInGB = ServerMemoryInMB/1024.0,
			MaxServerMemoryInGB = MaxServerMemoryInMB/1024.0,
			OSMemoryInGB = OSMemory/1024.0,
			PercentageForOS,
			AvgMBytes,
			MinMBytes,
			MaxMBytes
		FROM #TempMemConfig

	END

END	
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetWaits') IS NOT NULL
DROP PROCEDURE GetWaits
GO
CREATE PROCEDURE GetWaits
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	SET NOCOUNT ON
	IF OBJECT_ID('dbo.cust_Waiting') IS NOT NULL
	BEGIN
		--waits
		SELECT
			WaitType,
			WaitCount = CAST(WaitCount AS BIGINT),
			Percentage, AvgWaitTimeSec = AvgWait_S
		INTO #TempWaiting
		FROM dbo.cust_Waiting

		SELECT *
		--RowFlag = CASE WHEN CAST(Percentage AS DECIMAL)> 40 THEN 'R' ELSE 'N' END
		FROM #TempWaiting

	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetUnusedIndexes') IS NOT NULL
DROP PROCEDURE GetUnusedIndexes
GO
CREATE PROCEDURE GetUnusedIndexes
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_UnusedIndexes') IS NOT NULL
	BEGIN
		SELECT
			DatabaseName, TableName, IndexName, TableRows, UserSeeks, UserScans,
			UserLookups, UserUpdates, *,
			LastRestart = CAST(CASE WHEN LastRestart = 'NULL' THEN NULL ELSE LastRestart END AS DATE) ,
			LastUserSeek = CAST(CASE WHEN LastUserSeek = 'NULL' THEN NULL ELSE LastUserSeek END AS DATE),
			LastUserScan = CAST(CASE WHEN LastUserScan = 'NULL' THEN NULL ELSE LastUserScan END AS DATE),
			LastUserLookup = CAST(CASE WHEN LastUserLookup = 'NULL' THEN NULL ELSE LastUserLookup END AS DATE),
			LastUserUpdate = CAST(CASE WHEN LastUserUpdate = 'NULL' THEN NULL ELSE LastUserUpdate END AS DATE)
		FROM dbo.cust_UnusedIndexes
		WHERE CAST(UserSeeks AS BIGINT) = 0 AND
			CAST(UserScans AS BIGINT) = 0 AND CAST(UserLookups AS BIGINT) = 0
			AND DatabaseName NOT IN('tempdb', 'msdb', 'master', 'model')
			AND cast(replace(TableRows, 'NULL', '') AS BIGINT)> 100000
		ORDER BY CAST(TableRows AS BIGINT) DESC
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetMembershipPermissions') IS NOT NULL
DROP PROCEDURE GetMembershipPermissions
GO

CREATE PROCEDURE GetMembershipPermissions
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_MembershipPermissions') IS NOT NULL
	BEGIN
		--find excessive permissions
		SELECT *
		FROM dbo.cust_MembershipPermissions
		WHERE GranteeName IN('sysadmin', 'SecurityAdmin', 'db_owner') and
			GrantorName NOT IN('dbo', 'sa')
	END
END
GO
/*
IF OBJECT_ID('GetObjectPermissions') IS NOT NULL
DROP PROCEDURE GetObjectPermissions
GO

CREATE PROCEDURE GetObjectPermissions
AS
BEGIN
		DECLARE @Tab VARCHAR(50)
		SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_ObjectPermissions') IS NOT NULL
	BEGIN
		--find excessive permissions
		SELECT *
		FROM dbo.cust_ObjectPermissions
		--WHERE GranteeName IN('public') and
		--GrantorName NOT IN('dbo', 'sa')
	END

END
GO
*/
/*  Index Detail

SELECT d.* FROM dbo.cust_IndexDetail d
JOIN (
SELECT TableName, DBName
FROM dbo.cust_IndexDetail
GROUP BY TableName, DBName
HAVING COUNT(*) > 10
) a ON d.TableName = a.TableName AND d.DBName = a.DBName
*/

----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetLogInfo') IS NOT NULL
DROP PROCEDURE GetLogInfo
GO
CREATE PROCEDURE GetLogInfo
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	SET NOCOUNT ON
	IF OBJECT_ID('dbo.cust_LogInfo') IS NOT NULL
	BEGIN
		--excessive log files
		DECLARE @VLFThreshold INT
		SET @VLFThreshold = 500

		SELECT DBName, VLFCount = SUM(CAST(VLFCount AS BIGINT))
		INTO #TempLogInfo
		FROM dbo.cust_LogInfo
		GROUP BY DBName
		HAVING SUM(CAST(VLFCount AS BIGINT))  > @VLFThreshold

		SELECT *
		FROM #TempLogInfo
	END
END
GO
IF OBJECT_ID('GetSystemConfiguration') IS NOT NULL
DROP PROCEDURE GetSystemConfiguration
GO

CREATE PROCEDURE GetSystemConfiguration
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('tempdb..#SPConfigure') IS NOT NULL
	DROP TABLE #SPConfigure

	CREATE TABLE #SPConfigure
	(
		name varchar(50),
		run_value varchar(250)
	)

	IF OBJECT_ID('tbl_SPCONFIGURE') IS NOT NULL
	BEGIN
		INSERT INTO #SPConfigure
		SELECT *
		FROM dbo.tbl_SPCONFIGURE
		WHERE replace(run_value, '-', '') <> '' AND isnumeric(run_value)=1
	END
	ELSE IF OBJECT_ID('cust_SPConfigure') IS NOT NULL
	BEGIN
		INSERT INTO #SPConfigure
		SELECT name, value_in_use
		FROM cust_SPConfigure
	END
	ELSE IF OBJECT_ID('tbl_Sys_Configurations') IS NOT NULL
	BEGIN
		INSERT INTO #SPConfigure
		SELECT name, value_in_use
		FROM [dbo].[tbl_Sys_Configurations]
	END

	SELECT *
	FROM #SPConfigure
END
GO
----------------------------------------------------------------------------------------------
--SELECT * 
--FROM dbo.cust_MemoryClerks
--WHERE type = 'MEMORYCLERK_SQLBUFFERPOOL'

--SELECT * 
--FROM dbo.cust_MemoryClerks
--WHERE type != 'MEMORYCLERK_SQLBUFFERPOOL'
--ORDER BY virtual_memory_committed_kb desc
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetDatabaseInfo') IS NOT NULL
DROP PROCEDURE GetDatabaseInfo
GO

CREATE PROCEDURE GetDatabaseInfo
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_Databases') IS NOT NULL
BEGIN

	SELECT Flag = 'The is_auto_close_on setting on database ' + name + ' is enabled.'
			FROM dbo.cust_Databases
			WHERE is_auto_close_on = '1' OR is_auto_close_on = 'True'
		UNION ALL
			SELECT 'The is_auto_shrink_on setting on database ' + name + ' is enabled.'
			FROM dbo.cust_Databases
			WHERE is_auto_shrink_on = '1' OR is_auto_shrink_on = 'True'
		UNION ALL
			SELECT 'The database ' + name + ' is in standby recovery mode.'
			FROM dbo.cust_Databases
			WHERE is_in_standby = '1' OR is_in_standby = 'True'
		UNION ALL
			SELECT 'The is_read_committed_snapshot_on setting on database ' + name + ' is enabled.'
			FROM dbo.cust_Databases
			WHERE is_read_committed_snapshot_on = '1' OR is_read_committed_snapshot_on = 'True'
		UNION ALL
			SELECT 'The is_auto_create_stats_on setting on database ' + name + ' is disabled.'
			FROM dbo.cust_Databases
			WHERE is_auto_create_stats_on = '0' OR is_auto_create_stats_on = 'False'
		UNION ALL
			SELECT 'The is_auto_create_stats_on setting on database ' + name + ' is disabled.'
			FROM dbo.cust_Databases
			WHERE (is_auto_update_stats_on = '0' AND is_auto_update_stats_async_on = 'False')
		UNION ALL
			SELECT 'The is_recursive_triggers_on setting on database ' + name + ' is enabled.'
			FROM dbo.cust_Databases
			WHERE is_recursive_triggers_on = '1' OR is_recursive_triggers_on = 'True'
		UNION ALL
			SELECT 'The is_trustworthy_on setting on database ' + name + ' is enabled.'
			FROM dbo.cust_Databases
			WHERE (is_trustworthy_on = '1' OR is_trustworthy_on = 'True') AND database_id >4
		UNION ALL
			SELECT 'The database ' + name + ' is enabled for database ownership chaining.'
			FROM dbo.cust_Databases
			WHERE (is_db_chaining_on = '1' OR is_db_chaining_on = 'True') AND database_id > 4
		UNION ALL
			SELECT 'The is_parameterization_forced setting on database ' + name + ' is enabled.'
			FROM dbo.cust_Databases
			WHERE is_parameterization_forced = '1' OR is_parameterization_forced = 'True'
		UNION ALL
			SELECT 'The is_master_key_encrypted_by_server setting on database ' + name + ' is enabled.'
			FROM dbo.cust_Databases
			WHERE (is_master_key_encrypted_by_server = '1' OR is_master_key_encrypted_by_server = 'True') AND database_id > 4
		UNION ALL
			SELECT 'The database ' + name + ' is acting as a replication publisher.'
			FROM dbo.cust_Databases
			WHERE is_published = '1' OR is_published = 'True'
		UNION ALL
			SELECT 'The database ' + name + ' is acting as a replication subscriber.'
			FROM dbo.cust_Databases
			WHERE is_subscribed = '1' OR is_subscribed = 'True'
		UNION ALL
			SELECT 'The database ' + name + ' is participating in merge replication.'
			FROM dbo.cust_Databases
			WHERE is_merge_published = '1' OR is_merge_published = 'True'
		UNION ALL
			SELECT 'The database ' + name + ' is enabled for replication distribution.'
			FROM dbo.cust_Databases
			WHERE is_distributor = '1' OR is_distributor = 'True'
		UNION ALL
			SELECT 'The is_sync_with_backup setting on database ' + name + ' is enabled.'
			FROM dbo.cust_Databases
			WHERE is_sync_with_backup = '1' OR is_sync_with_backup = 'True'
		UNION ALL
			SELECT 'The is_broker_enabled setting on database ' + name + ' is enabled.'
			FROM dbo.cust_Databases
			WHERE is_broker_enabled = '1' OR is_broker_enabled = 'True'
		UNION ALL
			SELECT 'The is_date_correlation_on setting on database ' + name + ' is enabled.'
			FROM dbo.cust_Databases
			WHERE is_date_correlation_on = '1' OR is_date_correlation_on = 'True'
		UNION ALL
			SELECT 'The is_cdc_enabled setting on database ' + name + ' is enabled.'
			FROM dbo.cust_Databases
			WHERE is_cdc_enabled = '1' OR is_cdc_enabled = 'True'
		UNION ALL
			SELECT 'The is_encrypted setting on database ' + name + ' is enabled.'
			FROM dbo.cust_Databases
			WHERE is_encrypted = '1' OR is_encrypted = 'True'
		UNION ALL
			--database snapshot
			SELECT 'Database ' + name + ' is a database snapshot of database ' + (SELECT name
				FROM dbo.cust_databases ii
				WHERE ii.database_id = dd.source_database_id) + '.'
			FROM dbo.cust_databases dd
			WHERE (source_database_id IS NOT NULL AND source_database_id <> 'NULL')

		--SELECT name, compatibility_level 
		--FROM dbo.cust_databases
		UNION ALL
			SELECT 'The database ' + name + ' is not set to allow multiple user connections.'
			FROM dbo.cust_databases
			WHERE user_access_desc <> 'MULTI_USER'
		UNION ALL
			SELECT 'The database ' + name + ' is not currently online.'
			FROM dbo.cust_databases
			WHERE state_desc <> 'ONLINE'
		UNION ALL
			SELECT 'The database ' + name + ' has Snapshot Isolation enabled.'
			FROM dbo.cust_databases
			WHERE snapshot_isolation_state_desc = 'ON'
		UNION ALL
			--SELECT name, recovery_model_desc 
			--FROM dbo.cust_databases 
			--WHERE recovery_model_desc = 

			SELECT 'The page verify option on database ' + name + ' is not set to Checksum.'
			FROM dbo.cust_databases
			WHERE page_verify_option_desc <> 'CHECKSUM'


	END
ELSE
	PRINT 'No information on databases'
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetUsefulIndexes') IS NOT NULL
DROP PROCEDURE GetUsefulIndexes
GO

CREATE PROCEDURE GetUsefulIndexes
AS
BEGIN
	--find helpful indexes
	IF OBJECT_ID('dbo.cust_MissingIndexes') IS NOT NULL
	BEGIN
		SELECT
			DatabaseName, Benefit = cast(UserImpact as real), Cost = cast(UserCost as real),
			Seeks, Compiles,
			LastUserSeek, FullObjectName, TableName, EqualityColumns, InequalityColumns, IncludedColumns,
			x.*
		INTO #UsefulIndexes
		FROM dbo.cust_MissingIndexes
		CROSS APPLY dbo.fn_SortIncludedColumns(TableName, EqualityColumns, IncludedColumns, ',')x
		WHERE FullObjectName NOT LIKE '%msdb%' AND
			Seeks > 3000 AND
			cast(UserImpact as real) > 60 AND
			cast(UserCost as real) < 30
		--ORDER BY cast(Seeks as BIGINT) desc



		IF EXISTS(
			SELECT *, RowFlag = CASE WHEN 
			Benefit > 60 AND Cost < 30 THEN 'G' ELSE 'N' END
			FROM #UsefulIndexes
			WHERE Seeks > 1000
		)
		BEGIN
			SELECT *, RowFlag = CASE WHEN 
			Benefit > 60 AND Cost < 30 THEN 'G' ELSE 'N' END
			FROM #UsefulIndexes
			WHERE Seeks > 1000
			ORDER BY CAST(Seeks AS BIGINT) DESC

			INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			SELECT 'Missing index suggestions exist that would speed query execution.','Performance Metrics','Critical',NULL,NULL,NULL


		END

	END

END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetReadWriteStalls') IS NOT NULL
DROP PROCEDURE GetReadWriteStalls
GO

CREATE PROCEDURE GetReadWriteStalls
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @RowCount INT
	DECLARE @DurationT INT
	SET @DurationT = 40

	IF OBJECT_ID('dbo.cust_DBFileSizes') IS NOT NULL
	BEGIN
		SELECT DBName, LogicalName, FilePath,
			--CurrentSize = SizeInMB2, 
			AverageReadStallMS, AverageWriteStallMS, Growth
		INTO #ReadWriteStalls
		FROM dbo.cust_DBFileSizes
		WHERE 
		dbname not in('master','msdb','model') AND
			(
			cast(AverageReadStallMS AS BIGINT) >= @DurationT or
			cast(AverageWriteStallMS AS BIGINT) >= @DurationT
		)

		SELECT *
		FROM #ReadWriteStalls
		SET @RowCount = @@ROWCOUNT

	IF @RowCount > 0
	BEGIN
			DECLARE @Read INT, @Write INT

			SELECT
				@Read = SUM(CASE WHEN AverageReadStallMS > @DurationT THEN 1 ELSE 0 END),
				@Write = SUM(CASE WHEN AverageWriteStallMS > @DurationT THEN 1 ELSE 0 END)
			FROM #ReadWriteStalls

			INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			SELECT 'High Read or Write Stall time.','Performance Metrics','Critical',NULL,NULL,NULL


		END
	END
END
GO
----------------------------------------------------------------------------------------------
/*
--high write/read stalls
SELECT DBName, LogicalName, FilePath, 
OriginalSize = SizeInMB, CurrentSize = SizeInMB2, 
AverageReadStallMS, AverageWriteStallMS, Growth
FROM dbo.cust_DBFileSizes
*/
----------------------------------------------------------------------------------------------
/*
SELECT d.name, p.* 
FROM msdb..suspect_pages p
LEFT JOIN sys.databases d on p.database_id = p.page_id
*/
----------------------------------------------------------------------------------------------
--compare schedulers AND tempdb sizes
IF OBJECT_ID('GetTempDBSchedulerInfo') IS NOT NULL
DROP PROCEDURE GetTempDBSchedulerInfo
GO

CREATE PROCEDURE GetTempDBSchedulerInfo
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_DBFileSizes') IS NOT NULL AND
		OBJECT_ID('dbo.cust_OSInfo') IS NOT NULL
	BEGIN
		SELECT
			TempDBFileCount = COUNT(*),
			DistinctTempDBFileSizes = COUNT(DISTINCT InitialSizeInMB),
			SchedulerCount = (SELECT MAX(scheduler_count)
			FROM dbo.cust_OSInfo)
		INTO #TempDBInfo
		FROM dbo.cust_DBFileSizes
		WHERE DBName = 'tempdb' AND (LogicalName not like '%log%' or FilePath not like '%.ldf')



		DECLARE @FileCount INT, @SchedulerCount INT

		SELECT @FileCount = TempDBFileCount, @SchedulerCount = SchedulerCount
		FROM #TempDBInfo
		WHERE ((TempDBFileCount*1.00)/ SchedulerCount) < .15

		BEGIN
			IF @FileCount > 0
		BEGIN
				INSERT INTO PTOClinicFindings
					([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
				SELECT 'There are ' + CAST(@FileCount as VARCHAR(10)) + ' tempdb files and ' + CAST(@SchedulerCount AS VARCHAR(10)) + ' logical processors.', 'Database Design', 'Critical', NULL, NULL, NULL
			END

		END
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetBackupHistory') IS NOT NULL
DROP PROCEDURE GetBackupHistory
GO

CREATE PROCEDURE GetBackupHistory
AS
BEGIN

	DECLARE @ServerType VARCHAR(40) = dbo.udf_GetServerType()

	IF OBJECT_ID('dbo.cust_backupHistory') IS NOT NULL AND @ServerType = 'OnPremisesSQL'
	BEGIN
		--database backup history
		IF OBJECT_ID('tempdb..#DBBackupDetails') IS NOT NULL
		DROP TABLE #DBBackupDetails

		SELECT
			d.name, recovery_model_desc, log_reuse_wait_desc, bk.LastFullBackupDate, bk.LastDifferentialBackupDate, bk.LastLogBackupDate
		INTO #DBBackupDetails
		FROM dbo.cust_Databases d
			LEFT JOIN
			(
			SELECT
				databasename name,
				max(case when TYPE = 'D' then backupfinishdate else null end) as LastFullBackupDate,
				max(case when TYPE = 'I' then backupfinishdate else null end) as LastDifferentialBackupDate,
				max(case when TYPE = 'L' then backupfinishdate else null end) as LastLogBackupDate
			FROM dbo.cust_backupHistory
			WHERE backupfinishdate IS NOT NULL
			GROUP BY databasename
		) bk
			ON d.name = bk.name
		WHERE d.name <> 'tempdb'

		SELECT *
		FROM #DBBackupDetails

	END
END
GO
------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('GetDiskLatency') IS NOT NULL
DROP PROCEDURE GetDiskLatency
GO

CREATE PROCEDURE GetDiskLatency
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF OBJECT_ID('dbo.CounterData') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			CounterName, InstanceName,
			AverageLatency = cast(AVG(cast(countervalue as decimal(18,3)))as decimal(18,3)),
			MaxLatency = MAX(CAST(countervalue as decimal(18,3)))
		FROM dbo.CounterData d
			JOIN dbo.CounterDetails dd ON d.CounterID = dd.CounterID
		WHERE dd.countername IN('Avg. Disk sec/Read', 'Avg. Disk sec/Write')
			AND ObjectName = 'LogicalDisk'
			AND InstanceName <> '_Total'
			AND MachineName = @MachineName
		GROUP BY CounterName, InstanceName
		ORDER BY AverageLatency DESC
	END
	--look at data bytes divided by process.  See if SQL is competing against another process for IO


END
GO
IF OBJECT_ID('GetProcessInfo') IS NOT NULL
DROP PROCEDURE GetProcessInfo
GO

CREATE PROCEDURE GetProcessInfo
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.CounterData') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			InstanceName,
			AVGDataBytes = AVG(CounterValue),
			MaxDataBytes = MAX(CounterValue)
		INTO #CounterInfo
		FROM
			dbo.CounterData d
			JOIN dbo.CounterDetails dd ON d.CounterID = dd.CounterID
		WHERE 
			dd.countername = 'IO Data Bytes/sec' AND
			ObjectName = 'Process' AND
			InstanceName <> '_Total'
		GROUP BY InstanceName

		DELETE FROM #CounterInfo
		WHERE AVGDataBytes = 0

		SELECT TOP(5)
			*, DataBytesPercentage = (AVGDataBytes/(SELECT SUM(AVGDataBytes)
			FROM #CounterInfo)*1.00)*100.00
		FROM #CounterInfo
		ORDER BY AVGDataBytes DESC

	END

END	
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetLatchWaits') IS NOT NULL
DROP PROCEDURE GetLatchWaits
GO

CREATE PROCEDURE GetLatchWaits
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_latchwaits') IS NOT NULL
BEGIN
		WITH
			[Latches]
			AS
			(
				SELECT
					[latch_class],
					cast([wait_time_ms] as bigint)  / 1000.0 AS [WaitS],
					cast([waiting_requests_count] as bigint) AS [WaitCount],
					100.0 * cast([wait_time_ms] as bigint) / SUM (cast([wait_time_ms] as bigint)) OVER() AS [Percentage],
					ROW_NUMBER() OVER(ORDER BY cast([wait_time_ms] as bigint) DESC) AS [RowNum]
				FROM dbo.cust_latchwaits
				WHERE [latch_class] NOT IN (
	N'BUFFER')
					AND cast([wait_time_ms] as bigint)> 0
			)
		SELECT
			[W1].[latch_class] AS [LatchClass],
			CAST ([W1].[WaitS] AS DECIMAL(14, 2)) AS [Wait_S],
			[W1].[WaitCount] AS [WaitCount],
			CAST ([W1].[Percentage] AS DECIMAL(14, 2)) AS [Percentage],
			CAST (([W1].[WaitS] / [W1].[WaitCount]) AS DECIMAL (14, 4)) AS [AvgWait_S]
		FROM [Latches] AS [W1]
			INNER JOIN [Latches] AS [W2] ON [W2].[RowNum] <= [W1].[RowNum]
		WHERE [W1].[WaitCount] > 0
		GROUP BY [W1].[RowNum], [W1].[latch_class], [W1].[WaitS], [W1].[WaitCount], [W1].[Percentage]
		HAVING SUM ([W2].[Percentage]) - [W1].[Percentage] < 95;
	-- percentage threshold
	END

END
GO
IF OBJECT_ID('GetLastCheckDBDate') IS NOT NULL
DROP PROCEDURE GetLastCheckDBDate
GO
CREATE PROCEDURE [dbo].[GetLastCheckDBDate]
AS
BEGIN

	DECLARE @ServerType VARCHAR(40) = dbo.udf_GetServerType()

	IF OBJECT_ID('dbo.cust_LastDBCCCheckDBDate') IS NOT NULL AND @ServerType = 'OnPremisesSQL'
	BEGIN
		SELECT DBName, LastDBCCDate = CONVERT(VARCHAR(10), cast(LastDBCCDate as datetime), 101)
		INTO #CheckDB
		FROM dbo.cust_LastDBCCCheckDBDate

		SELECT *
		FROM #CheckDB

	END
END
GO
IF OBJECT_ID('GetExpensiveQueries') IS NOT NULL
DROP PROCEDURE GetExpensiveQueries
GO
CREATE PROCEDURE [dbo].[GetExpensiveQueries]
AS
BEGIN

	IF 
		OBJECT_ID('tbl_query_store_runtime_stats') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_plan') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_query') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_query_text') IS NOT NULL 
	BEGIN
		SELECT DISTINCT TOP(1000)
			q.dbname,
			first_execution_time, q.last_execution_time,
			avg_durationSec = CAST(avg_duration AS FLOAT)/1000000.00,
			min_durationSec = CAST(min_duration AS FLOAT)/1000000.00,
			max_durationSec = CAST(max_duration AS FLOAT)/1000000.00,
			avg_logical_io_reads = cast(avg_logical_io_reads AS FLOAT), min_logical_io_reads, max_logical_io_reads,
			min_dop, max_dop,
			min_rowcount, max_rowcount,
			query_parameterization_type_desc,
			execution_type_desc,
			count_executions,
			query_hash,
			query_plan_hash,
			--min_tempdb_space_used,
			--max_tempdb_space_used,
			query_sql_text
		from
			tbl_query_store_runtime_stats q
			join tbl_query_store_plan p on q.dbid = p.dbid and q.plan_id = p.plan_id
			join tbl_query_store_query qq on p.dbid = qq.dbid and p.query_id = qq.query_id
			join tbl_query_store_query_text qt on qt.dbid = qq.dbid and qt.query_text_id = qq.query_text_id
		order by cast(avg_logical_io_reads as float) desc
	END
	ELSE 	IF OBJECT_ID('dbo.cust_expensivequeries') IS NOT NULL
	BEGIN
		SELECT *
		FROM dbo.cust_expensivequeries
		ORDER BY AverageRunTimeSeconds desc
	END 
END
GO

-------------------------------------------------------------------------------
--blocking
IF OBJECT_ID('GetBlocking') IS NOT NULL
DROP PROCEDURE GetBlocking
GO

CREATE PROCEDURE GetBlocking
AS
BEGIN
	DECLARE @ServerType VARCHAR(40) = dbo.udf_GetServerType()

	IF OBJECT_ID('dbo.tbl_requests') IS NOT NULL AND
		OBJECT_ID('dbo.tbl_NOTABLEACTIVEQUERIES') IS NOT NULL  AND
		@ServerType = 'OnPremisesSQL'
	BEGIN
		WITH
			blocker
			AS
			(

				SELECT a.runtime, a.session_id, a.blocking_session_id, task_state, wait_type, resource_description, blockingresource = CAST('' AS VARCHAR(4000)),
				stmt_text, blockingstmt = CAST('' AS VARCHAR(4000)),
				0 as lvl
					FROM
						(
		SELECT
							rownos = ROW_NUMBER() OVER(PARTITION BY r.session_id ORDER BY r.session_id ASC),
							r.runtime,
							r.session_id, r.blocking_session_id, task_state, wait_type, resource_description, stmt_text
						FROM tbl_requests r
							JOIN dbo.tbl_NOTABLEACTIVEQUERIES n ON r.session_id = n.session_id AND r.runtime = n.runtime
						WHERE 
		blocking_session_id = 0
							AND EXISTS(
			SELECT 1
							FROM tbl_requests ri
							WHERE ri.blocking_session_id = r.session_id
		)
	) a
					WHERE rownos = 1

				UNION ALL
					SELECT
						x.runtime, x.session_id, x.blocking_session_id, x.task_state, x.wait_type, x.resource_description, blockingresource = CAST( b.resource_description AS VARCHAR(4000)), x.stmt_text, blockingstmt = CAST(b.stmt_text AS VARCHAR(4000)),
						lvl + 1
					FROM blocker b
						JOIN
						(
		SELECT
							rownos = ROW_NUMBER() OVER(PARTITION BY r.session_id ORDER BY r.session_id ASC),
							r.runtime,
							r.session_id, r.blocking_session_id, task_state, wait_type, resource_description, stmt_text
						FROM tbl_requests r
							JOIN dbo.tbl_NOTABLEACTIVEQUERIES n ON r.session_id = n.session_id AND r.runtime = n.runtime
						WHERE 
		blocking_session_id != 0
	) x ON b.session_id = x.blocking_session_id AND b.runtime = x.runtime
			)
		SELECT *
		FROM blocker
		ORDER BY lvl, session_id
		option(maxrecursion
		3000)
	END


END
GO


/*
Other data to gather AND analyze:


getprocs
*/
IF OBJECT_ID('GetTopCPUQueries') IS NOT NULL
DROP PROCEDURE GetTopCPUQueries
GO

CREATE PROCEDURE GetTopCPUQueries
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_Top10CPU') IS NOT NULL AND
		OBJECT_ID('GetTopNQueryHash') IS NOT NULL
	BEGIN

		EXECUTE ('EXECUTE GetTopNQueryHash ''CPU''')

	END

END
Go
IF OBJECT_ID('_GetSemaphores') IS NOT NULL
DROP PROCEDURE _GetSemaphores
GO

CREATE PROCEDURE _GetSemaphores
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.tbl_dm_exec_query_resource_semaphores') IS NOT NULL 
	BEGIN
		SELECT *
		FROM [dbo].[tbl_dm_exec_query_resource_semaphores]
	END

END
GO
IF OBJECT_ID('GetTopPlanStats') IS NOT NULL
DROP PROCEDURE GetTopPlanStats
GO

CREATE PROCEDURE GetTopPlanStats
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('tbl_TopNLogicalReadsByQueryHash') IS NOT NULL
	BEGIN
		DECLARE @SQL NVARCHAR(MAX)
		SET @SQL = 'GetTopNQueryHash ''Logical Reads'''

		EXECUTE (@SQL)
	END

END
Go
--IF OBJECT_ID('GetMemoryGrants') IS NOT NULL
--DROP PROCEDURE GetMemoryGrants
--GO

--CREATE PROCEDURE GetMemoryGrants
--AS
--BEGIN
--	DECLARE @Tab VARCHAR(50)
--	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

--	IF OBJECT_ID('dbo.cust_MemoryGrants') IS NOT NULL 
--	BEGIN
--		DECLARE @Grants INT
--		SELECT *
--		FROM dbo.cust_MemoryGrants
--		WHERE ISDATE(Runtime) = 1

--		SELECT @Grants = @@ROWCOUNT
--	END

--	IF @Grants > 10
--	BEGIN

--		INSERT INTO PTOClinicFindings
--			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
--		SELECT 'The number of outstanding memory grants captured is ' + CAST(@Grants AS VARCHAR(10)) +'.', 'Database Design', 'Critical', NULL, NULL, NULL
--		INSERT INTO PTOClinicFindings
--			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
--		SELECT 'Consider optimizing the queries involved.', 'Database Design', 'Critical', NULL, NULL, NULL
--	END
--END
--GO
--/*
--	Waits by gather time.
--*/
--IF OBJECT_ID('GetTopRequestsByWaitType') IS NOT NULL
--DROP PROCEDURE GetTopRequestsByWaitType
--GO

--CREATE PROCEDURE GetTopRequestsByWaitType
--AS
--BEGIN
--	IF OBJECT_ID('dbo.cust_MemoryGrants') IS NOT NULL
--	BEGIN
--		SELECT runtime, wait_type, COUNT(*) 
--		FROM dbo.tbl_REQUESTS
--		WHERE wait_type <> 'NULL'
--		group by runtime, wait_type
--		ORDER BY COUNT(*) desc
--	END

--END
--GO

IF OBJECT_ID('GetPercentagGrowthFiles') IS NOT NULL
DROP PROCEDURE GetPercentagGrowthFiles
GO

CREATE PROCEDURE GetPercentagGrowthFiles
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_DBFileSizes') IS NOT NULL
	BEGIN
		SELECT *
		--INTO #TempDBFileSizes
		FROM [dbo].[cust_DBFileSizes]
		WHERE Growth LIKE '%[%]%' AND
			DBName NOT IN('master','model','msdb')

	END
END
GO


IF OBJECT_ID('GetTempDBSizeDifferences') IS NOT NULL
DROP PROCEDURE GetTempDBSizeDifferences
GO

CREATE PROCEDURE GetTempDBSizeDifferences
AS
DECLARE @Tab VARCHAR(50)
SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

IF OBJECT_ID('dbo.cust_DBFileSizes') IS NOT NULL
	BEGIN
	
	SELECT InitialSizeInMB, Growth, SizeInMB, FileCount = COUNT(*), RowNo = ROW_NUMBER() OVER(ORDER BY NEWID())
	INTO #tempfiles
	FROM [dbo].[cust_DBFileSizes]
	WHERE DBName = 'tempdb' and LogicalName <> 'templog'
	GROUP BY InitialSizeInMB, Growth, SizeInMB
	HAVING COUNT(*) > 1

	IF (SELECT COUNT(*) FROM #tempfiles) > 1
		BEGIN

		SELECT InitialSizeInMB, Growth, SizeInMB
		FROM #tempfiles
		
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		SELECT 'There are multiple tempdb files with different sizes.', 'Database Design', 'Critical', NULL, NULL, NULL

	END

END

GO

IF OBJECT_ID('GetSpinlocks') IS NOT NULL
DROP PROCEDURE GetSpinlocks
GO

CREATE PROCEDURE GetSpinlocks
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_Spinlocks') IS NOT NULL
	BEGIN
		SELECT TOP(10)
			*, SpinPercent = ((CAST(spins AS BIGINT)  + 1)/(TotalSpins*1.000))*100.00
		FROM [dbo].[cust_Spinlocks]
	CROSS JOIN 
	(
	SELECT SUM(CAST(spins AS BIGINT)) AS TotalSpins
			FROM [dbo].[cust_Spinlocks]
	)x
		ORDER BY SpinPercent DESC
	END

END
GO

--IF OBJECT_ID('GetRingBufferSchedulerMonitor') IS NOT NULL
--DROP PROCEDURE GetRingBufferSchedulerMonitor
--GO

--CREATE PROCEDURE GetRingBufferSchedulerMonitor
--AS
--BEGIN
--	DECLARE @Tab VARCHAR(50)
--	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

--	IF OBJECT_ID('dbo.cust_RingBufferSchedulerMonitor') IS NOT NULL
--	BEGIN
--		SELECT * 
--		FROM dbo.cust_RingBufferSchedulerMonitor
--	END

--END
--GO
--IF OBJECT_ID('GetRingBufferResourceMonitor') IS NOT NULL
--DROP PROCEDURE GetRingBufferResourceMonitor
--GO

--CREATE PROCEDURE GetRingBufferResourceMonitor
--AS
--BEGIN
--	DECLARE @Tab VARCHAR(50)
--	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

--	IF OBJECT_ID('dbo.cust_RingBufferResourceMonitor') IS NOT NULL
--	BEGIN
--		SELECT * 
--		FROM dbo.cust_RingBufferResourceMonitor
--	END

--END
--GO
--IF OBJECT_ID('GetRingBufferExceptionMonitor') IS NOT NULL
--DROP PROCEDURE GetRingBufferExceptionMonitor
--GO

--CREATE PROCEDURE GetRingBufferExceptionMonitor
--AS
--BEGIN
--	DECLARE @Tab VARCHAR(50)
--	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

--	IF OBJECT_ID('dbo.cust_RingBufferExceptionMonitor') IS NOT NULL
--	BEGIN
--		SELECT * 
--		FROM dbo.cust_RingBufferExceptionMonitor
--	END

--END
--GO

IF OBJECT_ID('GetDBFileInfo') IS NOT NULL
DROP PROCEDURE GetDBFileInfo
GO

CREATE PROCEDURE GetDBFileInfo
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_DBFileSizes') IS NOT NULL
	BEGIN

		--call GetDiskOverview
		--CounterName
		--Description
		--InstanceName
		--CounterAvg
		--CounterMin
		--CounterMax

		SELECT *
		FROM dbo.cust_DBFileSizes
	END

END
GO

/*
SELECT * FROM MSsubscriptions
SELECT * FROM MSarticles
SELECT * FROM MSpublication_access
SELECT * FROM MSdistribution_agents
SELECT * FROM MSreplication_monitordata
SELECT * FROM MSpublications
SELECT * FROM MSpublicationthresholds
SELECT * FROM MSsubscriber_schedule
SELECT * FROM MSsnapshot_agents
SELECT * FROM MSlogreader_agents
SELECT * FROM MSpublisher_databases
SELECT * FROM MSrepl_backup_lsns
SELECT * FROM MSsubscriber_info

*/
IF OBJECT_ID('GetProcs') IS NOT NULL
DROP PROCEDURE GetProcs
GO

CREATE PROCEDURE GetProcs
AS
BEGIN
	SELECT ProcName = 'EXECUTE dbo.' + name 
	FROM sys.procedures
	WHERE name like 'Get%' and name <> 'GetProcs' and name <> 'GetTopNQueryHash' 
	ORDER BY CASE WHEN name = 'GetPTOClinicFindings' THEN 'zzzzzzzzzzzzzzzzz' ELSE name END ASC
END
GO

 IF OBJECT_ID('GetSystemSettings') IS NOT NULL
 DROP PROCEDURE GetSystemSettings
 GO

 CREATE PROCEDURE GetSystemSettings
 AS
 BEGIN
 	DECLARE @Tab VARCHAR(50)
 	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

 	IF OBJECT_ID('dbo.tbl_SPCONFIGURE') IS NOT NULL
 	BEGIN
 		SELECT * 
 		FROM dbo.tbl_SPCONFIGURE
 		WHERE ISNUMERIC(run_value) = 1
 	END

 END
 GO
IF OBJECT_ID('GetIndexDetail') IS NOT NULL
DROP PROCEDURE GetIndexDetail
GO
CREATE PROCEDURE GetIndexDetail
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_IndexDetail') IS NOT NULL AND
		OBJECT_ID('dbo.cust_IndexOperations') IS NOT NULL AND
		OBJECT_ID('dbo.cust_UnusedIndexes') IS NOT NULL 
	BEGIN
		SELECT DISTINCT
			d.DBName, d.TableName, d.IndexName, d.IndexColumns, d.IncludedColumns, d.IndexType, d.IsUnique,
			d.IsPrimaryKey, d.FillFact, d.IgnoreDupKey, d.IsUniqueConstraint, d.IsDisabled, d.IsHypothetical,
			d.AllowRowLocks, d.AllowPageLocks
		--o.leaf_insert_count, o.leaf_delete_count, o.leaf_update_count, o.leaf_ghost_count, 
		--o.nonleaf_insert_count, o.nonleaf_delete_count, o.nonleaf_update_count, o.leaf_allocation_count, 
		--o.nonleaf_allocation_count, o.range_scan_count, o.singleton_lookup_count, o.row_lock_count, 
		--o.row_lock_wait_count, o.row_lock_wait_in_ms, o.page_lock_count, o.page_lock_wait_count, o.page_lock_wait_in_ms, 
		--o.index_lock_promotion_attempt_count, o.index_lock_promotion_count, o.page_latch_wait_count, 
		--o.page_latch_wait_in_ms, o.page_io_latch_wait_count, o.page_io_latch_wait_in_ms, o.AvgPageLatchWait, 
		--o.AvgPageIOLatchWait,
		--u.UserSeeks, u.UserScans, u.UserLookups, u.UserUpdates, u.LastRestart, u.LastUserSeek, u.LastUserScan, 
		--u.LastUserLookup, u.LastUserUpdate, u.TableRows
		FROM dbo.cust_IndexDetail d
			LEFT JOIN dbo.cust_IndexOperations o ON d.DBName = o.DBName AND d.TableName = o.TableName and d.IndexName = o.IndexName
			LEFT JOIN dbo.cust_UnusedIndexes u ON d.DBName = u.DatabaseName AND d.TableName = u.TableName and d.IndexName = u.IndexName
		ORDER BY d.DBName, d.TableName
	END

END
GO



IF OBJECT_ID('GetMemoryPerfData') IS NOT NULL
DROP PROCEDURE GetMemoryPerfData
GO
CREATE PROCEDURE GetMemoryPerfData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			ObjectName,
			CounterName,
			MachineName,
			CounterAvg = FORMAT(AVG(CounterValue), 'N'),
			CounterMin = FORMAT(MIN(CounterValue), 'N'),
			CounterMax = FORMAT(MAX(CounterValue), 'N')
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName = 'Memory' AND
			CounterName IN
		(
		'Available MBytes',
		'Commit Limit',
		'Page Faults/sec',
		'Page Reads/sec',
		'Page Writes/sec',
		'Pages Input/sec',
		'Pages Output/sec',
		'Pages/sec',
		'Free System Page Table Entries',
		'% Committed Bytes In Use'
		)
			AND MachineName = @MachineName
		GROUP BY ObjectName, CounterName, MachineName
		ORDER BY CounterName




	END

END
GO
IF OBJECT_ID('GetBufferPerfData') IS NOT NULL
DROP PROCEDURE GetBufferPerfData
GO
CREATE PROCEDURE GetBufferPerfData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			ObjectName,
			CounterName,
			MachineName,
			CounterAvg = FORMAT(AVG(CounterValue), 'N'),
			CounterMin = FORMAT(MIN(CounterValue), 'N'),
			CounterMax = FORMAT(MAX(CounterValue), 'N')
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName LIKE '%:Buffer Manager' AND
			CounterName NOT IN
		(
		'Integral Controller Slope',
		'Extension page evictions/sec',
		'Extension page unreferenced time',
		'Extension outstanding IO counter'
		)
			AND MachineName = @MachineName
		GROUP BY ObjectName, CounterName, MachineName
		ORDER BY CounterName
	END

END
GO
IF OBJECT_ID('GetAccessMethodPerfData') IS NOT NULL
DROP PROCEDURE GetAccessMethodPerfData
GO
CREATE PROCEDURE GetAccessMethodPerfData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			ObjectName,
			CounterName,
			MachineName,
			CounterAvg = FORMAT(AVG(CounterValue), 'N'),
			CounterMin = FORMAT(MIN(CounterValue), 'N'),
			CounterMax = FORMAT(MAX(CounterValue), 'N')
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName LIKE '%Access Methods' AND
			MachineName = @MachineName
		GROUP BY ObjectName, CounterName, MachineName
		ORDER BY CounterName
	END


END

GO
IF OBJECT_ID('GetGeneralStatsPerfData') IS NOT NULL
DROP PROCEDURE GetGeneralStatsPerfData
GO
CREATE PROCEDURE GetGeneralStatsPerfData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			ObjectName,
			CounterName,
			MachineName,
			CounterAvg = FORMAT(AVG(CounterValue), 'N'),
			CounterMin = FORMAT(MIN(CounterValue), 'N'),
			CounterMax = FORMAT(MAX(CounterValue), 'N')
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName LIKE '%General Statistics' AND
			CounterName IN
		(
		'Active Temp Tables',
		'Logical Connections',
		'Logins/sec',
		'Logouts/sec',
		'Processes blocked',
		'SQL Trace IO Provider Lock Waits',
		--'Temp Tables Creation Rate',
		--'Temp Tables For Destruction',
		'Transactions',
		'User Connections'
		)
			AND MachineName = @MachineName
		GROUP BY ObjectName, CounterName, MachineName
		ORDER BY CounterName
	END

END
GO
IF OBJECT_ID('GetSQLStatsPerfData') IS NOT NULL
DROP PROCEDURE GetSQLStatsPerfData
GO
CREATE PROCEDURE GetSQLStatsPerfData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)
	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			ObjectName,
			CounterName,
			MachineName,
			CounterAvg = FORMAT(AVG(CounterValue), 'N'),
			CounterMin = FORMAT(MIN(CounterValue), 'N'),
			CounterMax = FORMAT(MAX(CounterValue), 'N')
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName LIKE '%SQL Statistics'
			AND MachineName = @MachineName
		GROUP BY ObjectName, CounterName, MachineName
		HAVING MAX(CounterValue) > 0
		ORDER BY CounterName
	END

END
GO
IF OBJECT_ID('GetProcessorPerfData') IS NOT NULL
DROP PROCEDURE GetProcessorPerfData
GO
CREATE PROCEDURE GetProcessorPerfData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)
	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			ObjectName,
			CounterName,
			MachineName,
			CounterAvg = FORMAT(AVG(CounterValue), 'N'),
			CounterMin = FORMAT(MIN(CounterValue), 'N'),
			CounterMax = FORMAT(MAX(CounterValue), 'N')
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName = 'Processor'
			AND MachineName = @MachineName
		GROUP BY ObjectName, CounterName, MachineName
		ORDER BY CounterName
	END

END
GO
IF OBJECT_ID('GetProcessPerfData') IS NOT NULL
DROP PROCEDURE GetProcessPerfData
GO
CREATE PROCEDURE GetProcessPerfData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF OBJECT_ID('tempdb..#CounterTemp') IS NOT NULL
	DROP TABLE #CounterTemp
	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			CounterName,
			InstanceName,
			MachineName,
			CounterAvg = AVG(CounterValue),
			CounterMin = MIN(CounterValue),
			CounterMax = MAX(CounterValue)
		INTO #CounterTemp
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName = 'Process' AND CounterName NOT IN(
		'Creating Process ID',
		'Elapsed Time',
		'Handle Count',
		'ID Process',
		'Priority Base'
		) AND InstanceName <> '_Total'
			AND MachineName = @MachineName
		GROUP BY CounterName, InstanceName, MachineName
		ORDER BY CounterName

		SELECT *
		FROM
			(
			SELECT *,
				AverageOverallPercentage = (CounterAvg/(SELECT SUM(CounterAvg)
				FROM #CounterTemp i
				WHERE o.CounterName = i.CounterName AND CounterAvg > 0)*1.00)*100.00,
				Grouping = DENSE_RANK() OVER(ORDER BY CounterName),
				RowNo = ROW_NUMBER() OVER(PARTITION BY CounterName ORDER BY CounterAvg DESC)
			FROM #CounterTemp o
			WHERE CounterAvg > 0
		) x
		WHERE RowNo <=5
		ORDER BY CounterName, CounterAvg DESC

	END

END
GO
IF OBJECT_ID('GetMemManagerPerfData') IS NOT NULL
DROP PROCEDURE GetMemManagerPerfData
GO
CREATE PROCEDURE GetMemManagerPerfData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)
	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			ObjectName,
			CounterName,
			MachineName,
			CounterAvg = AVG(CounterValue),
			CounterMin = MIN(CounterValue),
			CounterMax = MAX(CounterValue)
		INTO #MemoryManager
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName LIKE '%Memory Manager'
			AND MachineName = @MachineName
		GROUP BY ObjectName, CounterName, MachineName

		SELECT *
		FROM #MemoryManager
		ORDER BY CounterName

		BEGIN
			DECLARE @Pending INT
			PRINT SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

			SELECT @Pending = CAST(CounterAvg AS DECIMAL)
			FROM #MemoryManager
			WHERE CounterName = 'Memory Grants Pending'

			IF @Pending > 2
			BEGIN
				INSERT INTO PTOClinicFindings
					([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
				SELECT 'The number of pending memory grants on this instance is ' + CAST(@Pending AS VARCHAR(10)) + '.', 'Database Design', 'Critical', NULL, NULL, NULL

			END
		END


	END


END
GO
IF OBJECT_ID('GetWaitStatsPerfData') IS NOT NULL
DROP PROCEDURE GetWaitStatsPerfData
GO
CREATE PROCEDURE GetWaitStatsPerfData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)
	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			ObjectName,
			InstanceName,
			CounterName,
			MachineName,
			CounterAvg = FORMAT(AVG(CounterValue), 'N'),
			CounterMin = FORMAT(MIN(CounterValue), 'N'),
			CounterMax = FORMAT(MAX(CounterValue), 'N')
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName LIKE '%Wait Statistics' AND
			InstanceName = 'Average wait time (ms)' AND
			CounterName NOT IN(
		'Transaction ownership waits','Thread-safe memory objects waits','Wait for the worker','Workspace synchronization waits'
		)
			AND MachineName = @MachineName
		GROUP BY ObjectName, InstanceName, CounterName, MachineName
		HAVING MAX(CounterValue) > 5
		ORDER BY CounterName
	END

END
GO
IF OBJECT_ID('GetDatabasePerfData') IS NOT NULL
DROP PROCEDURE GetDatabasePerfData
GO
CREATE PROCEDURE GetDatabasePerfData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			ObjectName,
			CounterName,
			InstanceName,
			CounterAvg = FORMAT(AVG(CounterValue), 'N'),
			CounterMin = FORMAT(MIN(CounterValue), 'N'),
			CounterMax = FORMAT(MAX(CounterValue), 'N')
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName LIKE '%Databases' AND InstanceName <> '_Total'
			AND MachineName = @MachineName
		GROUP BY ObjectName, CounterName, InstanceName
		ORDER BY CounterName, InstanceName
	END

END
GO
IF OBJECT_ID('GetTableSizes') IS NOT NULL
DROP PROCEDURE GetTableSizes
GO
CREATE PROCEDURE GetTableSizes
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('dbo.cust_CompressionDetails') IS NOT NULL
	BEGIN

		DELETE FROM dbo.cust_CompressionDetails WHERE RowCnt = 'NULL'

		SELECT DBName, TableName, TableRowCount = MAX(CAST(RowCnt AS BIGINT))
		FROM dbo.cust_CompressionDetails
		WHERE CAST(RowCnt AS BIGINT) > 100
		GROUP BY DBName, TableName
		ORDER BY TableRowCount DESC
	END

END
GO


--IF OBJECT_ID('GetTableUsage') IS NOT NULL
--DROP PROCEDURE GetTableUsage
--GO
--CREATE PROCEDURE GetTableUsage
--AS
--BEGIN
--	DECLARE @Tab VARCHAR(50)
--	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

--	IF OBJECT_ID('dbo.cust_UnusedIndexes') IS NOT NULL AND
--		OBJECT_ID('dbo.cust_CompressionDetails') IS NOT NULL AND
--		OBJECT_ID('dbo.cust_IndexDetail') IS NOT NULL
--	BEGIN
--		DELETE FROM dbo.cust_CompressionDetails WHERE RowCnt = 'NULL'

--		SELECT
--			idx.DatabaseName,
--			idx.TableName,
--			idx.IndexName,
--			co.TableRowCount,
--			idx.UserSeeks,
--			idx.UserScans,
--			idx.UserLookups,
--			idx.UserUpdates,
--			idx.LastRestart,
--			d.IndexType,
--			d.IsPrimaryKey,
--			d.IsUniqueConstraint
--		FROM [dbo].[cust_UnusedIndexes] idx
--			JOIN
--			(
--			SELECT DBName, TableName, TableRowCount = MAX(CAST(RowCnt AS BIGINT))
--			FROM dbo.cust_CompressionDetails co
--			GROUP BY DBName, TableName
--		) co ON co.DBName = idx.DatabaseName AND co.TableName = idx.TableName
--			JOIN dbo.cust_IndexDetail d ON idx.DatabaseName = d.DBName and d.TableName = idx.TableName and idx.IndexName = d.IndexName
--		ORDER BY idx.DatabaseName, CAST(UserScans AS BIGINT) DESC
--	END

--END
--GO
IF OBJECT_ID('GetDiskOverview') IS NOT NULL
DROP PROCEDURE GetDiskOverview
GO
CREATE PROCEDURE GetDiskOverview
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	--SELECT DBName, LogicalName, AverageReadStallMS, AverageWriteStallMS, BaseDrive = LEFT(FilePath, 2), FilePath
	--FROM dbo.cust_DBFileSizes
	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails ') IS NOT NULL 
	BEGIN


		IF OBJECT_ID('tempdb..#DBDrives') IS NOT NULL
		DROP TABLE #DBDrives

		CREATE TABLE #DBDrives
		(
			BaseDrive VARCHAR(MAX),
			FileList VARCHAR(MAX)
		)

		IF OBJECT_ID('dbo.cust_DBFileSizes') IS NOT NULL
		BEGIN
			INSERT INTO #DBDrives
			SELECT BaseDrive, FileList = REVERSE(SUBSTRING(LTRIM(REVERSE(FileList)), 2, LEN(FileList)-1))
			FROM
				(
			SELECT BaseDrive = LEFT(FilePath, 2),
					FileList = (
				SELECT LogicalName + ', '
					FROM dbo.cust_DBFileSizes i
					WHERE LEFT(i.FilePath, 2) = LEFT(o.FilePath, 2)
					FOR XML PATH('')
			)
				FROM dbo.cust_DBFileSizes o
				GROUP BY LEFT(FilePath, 2)
		) x
		END
		ELSE
		BEGIN
			--placeholder for next statement
			INSERT INTO #DBDrives
			SELECT BaseDrive = '', FileList = ''
			FROM (SELECT t = 1)x
		END

		SELECT
			CounterName = CASE WHEN CounterName LIKE '% Bytes%' THEN REPLACE(CounterName, 'Bytes', 'KBytes') ELSE CounterName END,
			Description = 
		CASE
			WHEN CounterName = 'Avg. Disk Bytes/Transfer' THEN 'Average IO Size'
			WHEN CounterName = 'Avg. Disk Bytes/Read' THEN 'Average Read IO Size'
			WHEN CounterName = 'Avg. Disk Bytes/Write' THEN 'Average Write IO Size'
			WHEN CounterName = 'Disk Writes/sec' THEN 'Write IOs per second'
			WHEN CounterName = 'Disk Reads/sec' THEN 'Read IOs per second'
			WHEN CounterName = 'Disk Transfers/sec' THEN 'Total IOs per second'
			WHEN CounterName = '% Disk Read Time' THEN '% Work spent servicing read requests'
			WHEN CounterName = '% Disk Write Time' THEN '% Work spent servicing write requests'
			WHEN CounterName = '% Disk Time' THEN '% Work spent servicing all requests'
			WHEN CounterName = 'Split IO/Sec' THEN 'Measures NTFS non-contiguous file segments IO requests'
			WHEN CounterName = 'Avg. Disk sec/Read' THEN 'Disk Read latency'
			WHEN CounterName = 'Avg. Disk sec/Transfer' THEN 'Total Disk latency'
			WHEN CounterName = 'Avg. Disk sec/Write' THEN 'Disk Write latency'

			WHEN CounterName = 'Current Disk Queue Length' THEN 'IOs Currently Waiting'
			WHEN CounterName = 'Avg. Disk Queue Length' THEN 'Average IOs Waiting'
			WHEN CounterName = 'Avg. Disk Write Queue Length' THEN 'Average Write IOs Waiting'
			WHEN CounterName = 'Avg. Disk Read Queue Length' THEN 'Average Read IOs Waiting'
			WHEN CounterName = 'Disk Bytes/sec' THEN 'Disk Transfer Rate'
			WHEN CounterName = 'Disk Read Bytes/sec' THEN 'Disk Read Transfer Rate'
			WHEN CounterName = 'Disk Write Bytes/sec' THEN 'Disk Write Transfer Rate'
			WHEN CounterName = '% Free Space' THEN 'Amount of free space on disk'
			WHEN CounterName = '% Idle Time' THEN '% of time disk is not servicing requests'
		ELSE CounterName
		END,
			InstanceName,
			CounterAvg = CASE WHEN CounterName LIKE '% Bytes%' THEN AVG(CounterValue)/1024.0 ELSE AVG(CounterValue) END,
			CounterMin = CASE WHEN CounterName LIKE '% Bytes%' THEN MIN(CounterValue)/1024.0 ELSE MIN(CounterValue) END,
			CounterMax = CASE WHEN CounterName LIKE '% Bytes%' THEN MAX(CounterValue)/1024.0 ELSE MAX(CounterValue) END
		INTO #DiskPerf
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName = 'LogicalDisk' AND
			InstanceName <> '_Total'
			AND MachineName = @MachineName
		GROUP BY CounterName, InstanceName
		ORDER BY InstanceName, CounterName

		SELECT p.*, SQLFileList = d.FileList
		FROM #DiskPerf p
			LEFT JOIN #DBDrives d on p.InstanceName = d.BaseDrive
	END

END
GO
IF OBJECT_ID('GetBaseline') IS NOT NULL
DROP PROCEDURE GetBaseline
GO
CREATE PROCEDURE GetBaseline
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)
	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN

		IF OBJECT_ID('Baseline_Summary') IS NOT NULL
		DROP TABLE Baseline_Summary

		IF OBJECT_ID('tempdb..#CounterTemp') IS NOT NULL
		DROP TABLE #CounterTemp

		
		IF OBJECT_ID('Baseline_CPU') IS NOT NULL
		DROP TABLE Baseline_CPU

		SELECT
			CounterName,
			InstanceName,
			ObjectName,
			CounterAvg = AVG(CounterValue),
			CounterMin = MIN(CounterValue),
			CounterMax = MAX(CounterValue)
		INTO Baseline_CPU
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE  
			MachineName = @MachineName AND
			InstanceName = '_Total' AND
			ObjectName LIKE 'Processor%' 
		GROUP BY CounterName, InstanceName, ObjectName

		IF OBJECT_ID('Baseline_Disk') IS NOT NULL
		DROP TABLE Baseline_Disk

		SELECT
			CounterName,
			InstanceName,
			ObjectName,
			CounterAvg = AVG(CounterValue),
			CounterMin = MIN(CounterValue),
			CounterMax = MAX(CounterValue)
		INTO Baseline_Disk
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE  
			MachineName = @MachineName AND
			ObjectName IN('LogicalDisk','PhysicalDisk')
		GROUP BY CounterName, InstanceName, ObjectName

		IF OBJECT_ID('Baseline_Memory') IS NOT NULL
		DROP TABLE Baseline_Memory

		SELECT
			CounterName,
			InstanceName,
			ObjectName,
			CounterAvg = AVG(CounterValue),
			CounterMin = MIN(CounterValue),
			CounterMax = MAX(CounterValue)
		INTO Baseline_Memory
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE  
			MachineName = @MachineName AND
			ObjectName = 'Memory' 
		GROUP BY CounterName, InstanceName, ObjectName

		SELECT
			CounterName,
			InstanceName,
			ObjectName,
			CounterAvg = AVG(CounterValue),
			CounterMin = MIN(CounterValue),
			CounterMax = MAX(CounterValue)
		INTO #CounterTemp
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE 
			ObjectName = 'Process' AND CounterName IN(
			'% Processor Time',
			'% User Time',
			'IO Data Bytes/sec',
			'Working Set',
			'IO Write Bytes/sec',
			'IO Read Bytes/sec',
			'Private Bytes',
			'Page File Bytes'
			) AND InstanceName <> '_Total'
			AND MachineName = @MachineName
		GROUP BY CounterName, InstanceName, ObjectName


		SELECT
			Description = CASE WHEN ObjectName LIKE '%SQL%' THEN 'SQL Server' ELSE 'Server' END,
			ObjectName,
			CounterName,
			InstanceName = MIN(InstanceName),
			CounterAvg = AVG(CounterValue),
			CounterMin = MIN(CounterValue),
			CounterMax = MAX(CounterValue)
		INTO Baseline_Summary
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE 
			MachineName = @MachineName AND
					(
			(
				ObjectName LIKE '%Access Methods' AND
					CounterName IN
				(
				'Full Scans/sec',
				'Index Searches/sec',
				'Range Scans/sec',
				'Table Lock Escalations/sec',
				'Forwarded Records/sec',
				'Table Lock Escalations/sec',
				'Page Splits/sec',
				'Pages compressed/sec'
				)
			)
				OR
				(
			ObjectName LIKE '%Buffer Manager' AND
				CounterName IN
			(
			'Database pages',
			'Lazy writes/sec',
			'Page life expectancy',
			'Free list stalls/sec',
			'Page lookups/sec',
			'Page reads/sec',
			'Page writes/sec',
			'Readahead pages/sec',
			'Buffer cache hit ratio',
			'Extension allocated pages',
			'Extension page writes/sec'
			)
		)
				OR
				(
			ObjectName LIKE '%General Statistics' AND
				CounterName IN
			(
			'Active Temp Tables',
			'Logins/sec',
			'Processes blocked',
			'Transactions',
			'User Connections',
			'Temp Tables Creation Rate'
			)
		)
				OR
				(
			ObjectName LIKE '%Memory Manager' AND
				CounterName IN
			(
				'Connection Memory (KB)',
				'Database Cache Memory (KB)',
				'Lock Memory (KB)',
				'Memory Grants Outstanding',
				'Memory Grants Pending',
				'External benefit of memory',
				'Free Memory (KB)',
				'Granted Workspace Memory (KB)',
				'Optimizer Memory (KB)',
				'Reserved Server Memory (KB)',
				'SQL Cache Memory (KB)',
				'Stolen Server Memory (KB)',
				'Target Server Memory (KB)',
				'Total Server Memory (KB)'
			)
		)
				OR
				(
			ObjectName LIKE '%SQL Statistics' AND
				CounterName IN
			(
				'Batch Requests/sec',
				'SQL Compilations/sec',
				'SQL Re-Compilations/sec',
				'Guided Plan Executions/sec'
			)
		)
				OR
				(
			ObjectName LIKE '%Locks' AND
				CounterName IN
			(
				'Lock Requests/sec',
				'Lock Wait Time (ms)',
				'Average Wait Time (ms)',
				'Lock Waits/sec',
				'Number of Deadlocks/sec'
			)
		)
				OR
				(
			ObjectName = 'Memory' AND
				CounterName IN
			(
				'Available MBytes',
				'Pages/sec',
				'Memory \ Committed Bytes',
				'% Committed Bytes In Use',
				'Commit Limit'
			)
		)
				OR
				(
			ObjectName = 'Processor' AND
				CounterName IN
			(
				'% Processor Time',
				'% User Time'
			)
		)
				OR
				(
			ObjectName = 'Network Interface' AND
				CounterName IN
			(
				'Current Bandwidth',
				'Bytes Total/sec'
			)
		) 
		)

			GROUP BY ObjectName, CounterName
			--ORDER BY CounterName


		UNION ALL

			SELECT
				Description,
				ObjectName,
				CounterName,
				InstanceName,
				CounterAvg ,
				CounterMin ,
				CounterMax
			FROM
				(
		SELECT
					Description = 'Busiest Database',
					ObjectName,
					CounterName,
					InstanceName,
					CounterAvg = AVG(CounterValue),
					CounterMin = MIN(CounterValue),
					CounterMax = MAX(CounterValue),
					RowNo = Row_Number() OVER(PARTITION BY CounterName ORDER BY AVG(CounterValue) DESC)
				FROM dbo.Counterdata c
					JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
				WHERE 
					ObjectName LIKE '%Databases' AND
					CounterName = 'Active Transactions' AND
					InstanceName <> '_Total'
					AND MachineName = @MachineName
				GROUP BY ObjectName, CounterName, InstanceName
		) x
			WHERE RowNo = 1


		UNION ALL

			SELECT Description = 'Top 10 Processes',
				ObjectName, CounterName, InstanceName, CounterAvg, CounterMin, CounterMax--, AverageOverallPercentage
			FROM
				(
		SELECT *,
					AverageOverallPercentage = (CounterAvg/(SELECT SUM(CounterAvg)
					FROM #CounterTemp i
					WHERE o.CounterName = i.CounterName AND CounterAvg > 0)*1.00)*100.00,
					RowNo = Row_Number() OVER(PARTITION BY CounterName ORDER BY CounterAvg DESC)
				FROM #CounterTemp o
				WHERE CounterAvg > 0
		) x
			WHERE RowNo <= 10
		ORDER BY Description, ObjectName, CounterName

		INSERT INTO Baseline_Summary(Description, ObjectName, CounterName, InstanceName, CounterAvg, CounterMin, CounterMax)
		SELECT 
			Description = 'SQL Server', 
			ObjectName = 'Custom Counter',
			CounterName = others.CounterName + ' to ' + batch.CounterName + ' ratio',
			InstanceName = NULL, 
			CASE WHEN batch.CounterAvg = 0 THEN 0 ELSE others.CounterAvg/batch.CounterAvg END,
			CASE WHEN batch.CounterMin = 0 THEN 0 ELSE others.CounterMin/batch.CounterMin END,
			CASE WHEN batch.CounterMax = 0 THEN 0 ELSE others.CounterMax/batch.CounterMax END
		FROM 
		(
			SELECT * 
			FROM baseline_summary
			WHERE CounterName = 'Batch Requests/sec'
		) batch, 
		(
			SELECT * 
			FROM baseline_summary
			WHERE CounterName IN
			( 
				'Page lookups/sec',
				'Lock Requests/sec',
				'SQL Compilations/sec',
				'SQL Re-Compilations/sec'
			)
		) others 

		SELECT *, OrderNo = DENSE_RANK() OVER(PARTITION BY Description, ObjectName, CounterName ORDER BY CounterAvg)
		FROM Baseline_Summary
	END

END
GO




IF OBJECT_ID('CompareBaseline') IS NOT NULL
DROP PROCEDURE CompareBaseline
GO
CREATE PROCEDURE CompareBaseline
(
	@DB1 VARCHAR(255),
	@DB2 VARCHAR(255)
)
AS
BEGIN
	DECLARE @SQL NVARCHAR(MAX)

	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('tempdb..#DB1') IS NOT NULL
	DROP TABLE #DB1
	IF OBJECT_ID('tempdb..#DB2') IS NOT NULL
	DROP TABLE #DB2
	IF OBJECT_ID('tempdb..#Display') IS NOT NULL
	DROP TABLE #Display

	CREATE TABLE #DB1
	(
		Description VARCHAR(255),
		ObjectName VARCHAR(255),
		CounterName VARCHAR(255),
		InstanceName VARCHAR(255),
		CounterAvg FLOAT,
		CounterMin FLOAT,
		CounterMax FLOAT,
		OrderNo INT
	)

	CREATE TABLE #DB2
	(
		Description VARCHAR(255),
		ObjectName VARCHAR(255),
		CounterName VARCHAR(255),
		InstanceName VARCHAR(255),
		CounterAvg FLOAT,
		CounterMin FLOAT,
		CounterMax FLOAT,
		OrderNo INT
	)

	SET @SQL = 'EXECUTE ' + @DB1 + '..GetBaseline'

	INSERT INTO #DB1
	EXECUTE (@SQL)


	SET @SQL = 'EXECUTE ' + @DB2 + '..GetBaseline'
	INSERT INTO #DB2
	EXECUTE (@SQL)

	SELECT
		Description = ISNULL(d1.Description,d2.Description),
		ObjectName = ISNULL(d1.ObjectName,d2.ObjectName),
		CounterName = ISNULL(d1.CounterName,d2.CounterName),
		DB1InstanceName = d1.InstanceName,
		DB2InstanceName = d2.InstanceName,
		DB1CounterAvg = d1.CounterAvg,
		DB2CounterAvg = d2.CounterAvg,
		AvgDiff = CASE WHEN ISNULL(d1.InstanceName,'') = ISNULL(d2.InstanceName,'') THEN d2.CounterAvg - d1.CounterAvg ELSE NULL END,
		AvgPercentChange = CASE WHEN ISNULL(d1.InstanceName,'') = ISNULL(d2.InstanceName,'') THEN CAST((CASE WHEN d1.CounterAvg = 0 THEN 0 ELSE ((d2.CounterAvg - d1.CounterAvg)/d1.CounterAvg)*100 END) AS FLOAT) ELSE NULL END,
		DB1CounterMin = d1.CounterMin,
		DB2CounterMin = d2.CounterMin,
		MinDiff = CASE WHEN ISNULL(d1.InstanceName,'') = ISNULL(d2.InstanceName,'') THEN d2.CounterMin - d1.CounterMin ELSE NULL END,
		DB1CounterMax = d1.CounterMax,
		DB2CounterMax = d2.CounterMax,
		MaxDiff = CASE WHEN ISNULL(d1.InstanceName,'') = ISNULL(d2.InstanceName,'') THEN d2.CounterMax - d1.CounterMax ELSE NULL END
	INTO #Display
	FROM
		#DB1 d1
		FULL OUTER JOIN #DB2 d2 ON 
			d1.Description = d2.Description AND
			d1.ObjectName = d2.ObjectName AND
			d1.CounterName = d2.CounterName AND
			d1.OrderNo = d2.OrderNo
	--ISNULL(d1.InstanceName,'') = ISNULL(d2.InstanceName,'')
	DECLARE @DB1ColName VARCHAR(55)
	DECLARE @DB2ColName VARCHAR(55)

	SELECT @DB1ColName = @DB1 + '_InstanceName', @DB2ColName = @DB2 + '_InstanceName'
	EXECUTE tempdb..sp_rename '#Display.DB1InstanceName', @DB1ColName
	EXECUTE tempdb..sp_rename '#Display.DB2InstanceName', @DB2ColName

	SELECT @DB1ColName = @DB1 + '_CounterAvg', @DB2ColName = @DB2 + '_CounterAvg'
	EXECUTE tempdb..sp_rename '#Display.DB1CounterAvg', @DB1ColName
	EXECUTE tempdb..sp_rename '#Display.DB2CounterAvg', @DB2ColName

	SELECT @DB1ColName = @DB1 + '_CounterMin', @DB2ColName = @DB2 + '_CounterMin'
	EXECUTE tempdb..sp_rename '#Display.DB1CounterMin', @DB1ColName
	EXECUTE tempdb..sp_rename '#Display.DB2CounterMin', @DB2ColName

	SELECT @DB1ColName = @DB1 + '_CounterMax', @DB2ColName = @DB2 + '_CounterMax'
	EXECUTE tempdb..sp_rename '#Display.DB1CounterMax', @DB1ColName
	EXECUTE tempdb..sp_rename '#Display.DB2CounterMax', @DB2ColName

	SELECT *
	FROM #Display
	ORDER BY 1,2,3

	IF OBJECT_ID('tempdb..#SystemSettings') IS NOT NULL
	DROP TABLE #SystemSettings

	CREATE TABLE #SystemSettings
	(
		Setting NVARCHAR(255),
		RunValue NVARCHAR(255),
		DBName NVARCHAR(255)
	)

	SET @SQL = 'EXECUTE ' + @DB1 + '..GetSystemSettings'
	INSERT INTO #SystemSettings
		(Setting, RunValue)
	EXECUTE (@SQL)

	UPDATE #SystemSettings
	SET DBName = @DB1
	WHERE DBName IS NULL

	SET @SQL = 'EXECUTE ' + @DB2 + '..GetSystemSettings'
	INSERT INTO #SystemSettings
		(Setting, RunValue)
	EXECUTE (@SQL)

	UPDATE #SystemSettings
	SET DBName = @DB2
	WHERE DBName IS NULL


	SET @SQL = 'EXECUTE ' + @DB1 + '..GetSystemInformation'
	INSERT INTO #SystemSettings
		(Setting, RunValue)
	EXECUTE (@SQL)

	UPDATE #SystemSettings
	SET DBName = @DB1
	WHERE DBName IS NULL

	SET @SQL = 'EXECUTE ' + @DB2 + '..GetSystemInformation'
	INSERT INTO #SystemSettings
		(Setting, RunValue)
	EXECUTE (@SQL)

	UPDATE #SystemSettings
	SET DBName = @DB2
	WHERE DBName IS NULL

	SELECT *
	FROM
		(
		SELECT *
		FROM #SystemSettings
		WHERE DBName = @DB1
	) db1
		JOIN
		(
		SELECT *
		FROM #SystemSettings
		WHERE DBName = @DB2
	) db2 ON db1.Setting = db2.Setting
	WHERE db1.RunValue <> db2.RunValue
END
GO
/*
exec CompareBaseline
	@DB1 = 'epostrx_0126_good', 
	@DB2 = 'epostrx_0202_bad'
*/


IF OBJECT_ID('CompareProcess') IS NOT NULL
DROP PROCEDURE CompareProcess
GO
CREATE PROCEDURE CompareProcess
(
	@DB1 VARCHAR(255),
	@DB2 VARCHAR(255),
	@ProcessName VARCHAR(255),
	@MismatchOnly BIT = 0
)
AS
BEGIN
	DECLARE @SQL NVARCHAR(MAX)

	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	CREATE TABLE #DB1
	(
		CounterName VARCHAR(255),
		InstanceName VARCHAR(255),
		CounterAvg DECIMAL(19,4),
		CounterMin DECIMAL(19,4),
		CounterMax DECIMAL(19,4)
	)

	CREATE TABLE #DB2
	(
		CounterName VARCHAR(255),
		InstanceName VARCHAR(255),
		CounterAvg DECIMAL(19,4),
		CounterMin DECIMAL(19,4),
		CounterMax DECIMAL(19,4)
	)
	SET @SQL = N'
	SELECT 
	CounterName, 
	InstanceName,
		CounterAvg = FORMAT(AVG(CounterValue), ''N''),
		CounterMin = FORMAT(MIN(CounterValue), ''N''), 
		CounterMax = FORMAT(MAX(CounterValue), ''N'')
	FROM ' + @DB1 + '.dbo.Counterdata c
	JOIN ' + @DB1 + '.dbo.CounterDetails d ON c.CounterID = d.CounterID
	WHERE ObjectName = ''Process'' AND 
	CounterName = @ProcessName
	AND InstanceName <> ''_Total''
	GROUP BY CounterName, InstanceName, ObjectName'

	INSERT INTO #DB1
	EXECUTE sp_executeSQL @SQL, N'@ProcessName VARCHAR(255)', @ProcessName = @ProcessName


	SET @SQL = N'
	SELECT 
	CounterName, 
	InstanceName,
	CounterAvg = FORMAT(AVG(CounterValue), ''N''),
	CounterMin = FORMAT(MIN(CounterValue), ''N''), 
	CounterMax = FORMAT(MAX(CounterValue), ''N'')
	FROM ' + @DB2 + '.dbo.Counterdata c
	JOIN ' + @DB2 + '.dbo.CounterDetails d ON c.CounterID = d.CounterID
	WHERE ObjectName = ''Process'' AND 
	CounterName = @ProcessName
	AND InstanceName <> ''_Total''
	GROUP BY CounterName, InstanceName, ObjectName'

	INSERT INTO #DB2
	EXECUTE sp_executeSQL @SQL, N'@ProcessName VARCHAR(255)', @ProcessName = @ProcessName

	SELECT
		CounterName = ISNULL(d1.CounterName, d2.CounterName),
		InstanceName = ISNULL(d1.InstanceName,	d2.InstanceName),
		DB1CounterAvg = d1.CounterAvg,
		DB2CounterAvg = d2.CounterAvg,
		AvgDiff = d2.CounterAvg - d1.CounterAvg,
		AvgPercentChange = CAST((CASE WHEN d1.CounterAvg = 0 THEN 0 ELSE ((d2.CounterAvg - d1.CounterAvg)/d1.CounterAvg)*100 END) AS DECIMAL(19,2)),
		DB1CounterMin = d1.CounterMin,
		DB2CounterMin = d2.CounterMin,
		MinDiff = d2.CounterMin - d1.CounterMin,
		DB1CounterMax = d1.CounterMax,
		DB2CounterMax = d2.CounterMax,
		MaxDiff = d2.CounterMax - d1.CounterMax
	INTO #Results
	FROM
		#DB1 d1
		FULL OUTER JOIN #DB2 d2 ON 
			d1.CounterName = d2.CounterName AND
			d1.InstanceName = d2.InstanceName


	IF @MismatchOnly = 0
	BEGIN
		SELECT *
		FROM #Results
		ORDER BY AvgDiff DESC
	END
	ELSE
	BEGIN
		SELECT *
		FROM #Results
		WHERE --DB1CounterAvg IS NULL OR 
		DB2CounterAvg IS NULL
		ORDER BY InstanceName
	--ORDER BY ISNULL(DB1CounterAvg, DB2CounterAvg) DESC
	END

END
GO

/*
exec CompareProcess
	@DB1 = '[35_PerfMon]', 
	@DB2 = '[102_PerfMon]',
	@ProcessName = 'Private Bytes', 
	@MismatchOnly = 1
*/



--SELECT 
--CounterName, 
--InstanceName,
--ObjectName,
--CounterAvg = AVG(CounterValue), 
--CounterMin = MIN(CounterValue), 
--CounterMax = MAX(CounterValue)
--FROM dbo.Counterdata c
--JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
--WHERE ObjectName = 'Process' AND 
--CounterName = 'IO Data Bytes/sec'
--AND InstanceName <> '_Total'
--GROUP BY CounterName, InstanceName, ObjectName


IF OBJECT_ID('CompareDiskOverview') IS NOT NULL
DROP PROCEDURE CompareDiskOverview
GO
CREATE PROCEDURE CompareDiskOverview
(
	@DB1 VARCHAR(255),
	@DB2 VARCHAR(255)
)
AS
BEGIN
	DECLARE @SQL NVARCHAR(MAX)

	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	CREATE TABLE #DB1
	(
		CounterName VARCHAR(255),
		Description VARCHAR(255),
		InstanceName VARCHAR(255),
		CounterAvg DECIMAL(19,4),
		CounterMin DECIMAL(19,4),
		CounterMax DECIMAL(19,4),
		SQLFileList VARCHAR(MAX)
	)

	CREATE TABLE #DB2
	(
		CounterName VARCHAR(255),
		Description VARCHAR(255),
		InstanceName VARCHAR(255),
		CounterAvg DECIMAL(19,4),
		CounterMin DECIMAL(19,4),
		CounterMax DECIMAL(19,4),
		SQLFileList VARCHAR(MAX)
	)

	SET @SQL = 'EXECUTE ' + @DB1 + '..GetDiskOverview'
	INSERT INTO #DB1
	EXECUTE (@SQL)

	SET @SQL = 'EXECUTE ' + @DB2 + '..GetDiskOverview'
	INSERT INTO #DB2
	EXECUTE (@SQL)

	SELECT
		d1.CounterName,
		d1.Description,
		InstanceName = ISNULL(d1.InstanceName,	d2.InstanceName),
		DB1CounterAvg = d1.CounterAvg,
		DB2CounterAvg = d2.CounterAvg,
		AvgDiff = d2.CounterAvg - d1.CounterAvg,
		AvgPercentChange = CAST((CASE WHEN d1.CounterAvg = 0 THEN 0 ELSE ((d2.CounterAvg - d1.CounterAvg)/d1.CounterAvg)*100 END) AS DECIMAL(19,2)),
		DB1CounterMin = d1.CounterMin,
		DB2CounterMin = d2.CounterMin,
		MinDiff = d2.CounterMin - d1.CounterMin,
		DB1CounterMax = d1.CounterMax,
		DB2CounterMax = d2.CounterMax,
		MaxDiff = d2.CounterMax - d1.CounterMax,
		d1.SQLFileList
	FROM
		#DB1 d1
		JOIN #DB2 d2 ON 
			d1.CounterName = d2.CounterName AND
			d1.InstanceName = d2.InstanceName AND
			(d1.SQLFileList IS NOT NULL OR d2.SQLFileList IS NOT NULL)
	ORDER BY InstanceName ASC, CounterName ASC

END
GO
/*
exec CompareDiskOverview
	@DB1 = '[35_PerfMon]', 
	@DB2 = '[102_PerfMon]'
*/

GO
IF OBJECT_ID('CompareBufferPerfData') IS NOT NULL
DROP PROCEDURE CompareBufferPerfData
GO
CREATE PROCEDURE CompareBufferPerfData
(
	@DB1 VARCHAR(255),
	@DB2 VARCHAR(255)
)
AS
BEGIN
	DECLARE @SQL NVARCHAR(MAX)

	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	CREATE TABLE #DB1
	(
		ObjectName VARCHAR(255),
		CounterName VARCHAR(255),
		CounterAvg DECIMAL(19,4),
		CounterMin DECIMAL(19,4),
		CounterMax DECIMAL(19,4)
	)

	CREATE TABLE #DB2
	(
		ObjectName VARCHAR(255),
		CounterName VARCHAR(255),
		CounterAvg DECIMAL(19,4),
		CounterMin DECIMAL(19,4),
		CounterMax DECIMAL(19,4)
	)

	SET @SQL = 'EXECUTE ' + @DB1 + '..GetBufferPerfData'
	INSERT INTO #DB1
	EXECUTE (@SQL)

	SET @SQL = 'EXECUTE ' + @DB2 + '..GetBufferPerfData'
	INSERT INTO #DB2
	EXECUTE (@SQL)


	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN

		SELECT
			d1.ObjectName,
			d1.CounterName,
			DB1CounterAvg = d1.CounterAvg,
			DB2CounterAvg = d2.CounterAvg,
			AvgDiff = d2.CounterAvg - d1.CounterAvg,
			AvgPercentChange = CAST((CASE WHEN d1.CounterAvg = 0 THEN 0 ELSE ((d2.CounterAvg - d1.CounterAvg)/d1.CounterAvg)*100 END) AS DECIMAL(19,2)),
			DB1CounterMin = d1.CounterMin,
			DB2CounterMin = d2.CounterMin,
			MinDiff = d2.CounterMin - d1.CounterMin,
			DB1CounterMax = d1.CounterMax,
			DB2CounterMax = d2.CounterMax,
			MaxDiff = d2.CounterMax - d1.CounterMax
		FROM
			#DB1 d1
			FULL OUTER JOIN #DB2 d2 ON 
				d1.CounterName = d2.CounterName AND
				d1.ObjectName = d2.ObjectName
		ORDER BY AvgDiff DESC
	END
END
GO
/*
exec CompareBufferPerfData
	@DB1 = '[35_PerfMon]', 
	@DB2 = '[102_PerfMon]'
*/
GO

IF OBJECT_ID('CompareAccessMethodPerfData') IS NOT NULL
DROP PROCEDURE CompareAccessMethodPerfData
GO
CREATE PROCEDURE CompareAccessMethodPerfData
(
	@DB1 VARCHAR(255),
	@DB2 VARCHAR(255)
)
AS
BEGIN
	DECLARE @SQL NVARCHAR(MAX)

	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	CREATE TABLE #DB1
	(
		ObjectName VARCHAR(255),
		CounterName VARCHAR(255),
		CounterAvg DECIMAL(19,4),
		CounterMin DECIMAL(19,4),
		CounterMax DECIMAL(19,4)
	)

	CREATE TABLE #DB2
	(
		ObjectName VARCHAR(255),
		CounterName VARCHAR(255),
		CounterAvg DECIMAL(19,4),
		CounterMin DECIMAL(19,4),
		CounterMax DECIMAL(19,4)
	)

	SET @SQL = 'EXECUTE ' + @DB1 + '..GetAccessMethodPerfData'
	INSERT INTO #DB1
	EXECUTE (@SQL)

	SET @SQL = 'EXECUTE ' + @DB2 + '..GetAccessMethodPerfData'
	INSERT INTO #DB2
	EXECUTE (@SQL)


	BEGIN

		SELECT
			d1.ObjectName,
			d1.CounterName,
			DB1CounterAvg = d1.CounterAvg,
			DB2CounterAvg = d2.CounterAvg,
			AvgDiff = d2.CounterAvg - d1.CounterAvg,
			AvgPercentChange = CAST((CASE WHEN d1.CounterAvg = 0 THEN 0 ELSE ((d2.CounterAvg - d1.CounterAvg)/d1.CounterAvg)*100 END) AS DECIMAL(19,2)),
			DB1CounterMin = d1.CounterMin,
			DB2CounterMin = d2.CounterMin,
			MinDiff = d2.CounterMin - d1.CounterMin,
			DB1CounterMax = d1.CounterMax,
			DB2CounterMax = d2.CounterMax,
			MaxDiff = d2.CounterMax - d1.CounterMax
		FROM
			#DB1 d1
			FULL OUTER JOIN #DB2 d2 ON 
				d1.CounterName = d2.CounterName AND
				d1.ObjectName = d2.ObjectName
		ORDER BY AvgDiff DESC
	END
END
GO
/*
exec CompareAccessMethodPerfData
	@DB1 = '[35_PerfMon]', 
	@DB2 = '[102_PerfMon]'
*/
GO

IF OBJECT_ID('CompareBufferPerfData') IS NOT NULL
DROP PROCEDURE CompareBufferPerfData
GO
CREATE PROCEDURE CompareBufferPerfData
(
	@DB1 VARCHAR(255),
	@DB2 VARCHAR(255)
)
AS
BEGIN
	DECLARE @SQL NVARCHAR(MAX)

	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	CREATE TABLE #DB1
	(
		ObjectName VARCHAR(255),
		CounterName VARCHAR(255),
		CounterAvg DECIMAL(19,4),
		CounterMin DECIMAL(19,4),
		CounterMax DECIMAL(19,4)
	)

	CREATE TABLE #DB2
	(
		ObjectName VARCHAR(255),
		CounterName VARCHAR(255),
		CounterAvg DECIMAL(19,4),
		CounterMin DECIMAL(19,4),
		CounterMax DECIMAL(19,4)
	)

	SET @SQL = 'EXECUTE ' + @DB1 + '..GetBufferPerfData'
	INSERT INTO #DB1
	EXECUTE (@SQL)

	SET @SQL = 'EXECUTE ' + @DB2 + '..GetBufferPerfData'
	INSERT INTO #DB2
	EXECUTE (@SQL)


	BEGIN

		SELECT
			d1.ObjectName,
			d1.CounterName,
			DB1CounterAvg = d1.CounterAvg,
			DB2CounterAvg = d2.CounterAvg,
			AvgDiff = d2.CounterAvg - d1.CounterAvg,
			AvgPercentChange = CAST((CASE WHEN d1.CounterAvg = 0 THEN 0 ELSE ((d2.CounterAvg - d1.CounterAvg)/d1.CounterAvg)*100 END) AS DECIMAL(19,2)),
			DB1CounterMin = d1.CounterMin,
			DB2CounterMin = d2.CounterMin,
			MinDiff = d2.CounterMin - d1.CounterMin,
			DB1CounterMax = d1.CounterMax,
			DB2CounterMax = d2.CounterMax,
			MaxDiff = d2.CounterMax - d1.CounterMax
		FROM
			#DB1 d1
			FULL OUTER JOIN #DB2 d2 ON 
				d1.CounterName = d2.CounterName AND
				d1.ObjectName = d2.ObjectName
		ORDER BY AvgDiff DESC
	END
END
GO
/*
exec CompareBufferPerfData
	@DB1 = '[35_PerfMon]', 
	@DB2 = '[102_PerfMon]'
GO
*/
--IF OBJECT_ID('GetNetworkData') IS NOT NULL
--DROP PROCEDURE GetNetworkData
--GO
--CREATE PROCEDURE GetNetworkData
--AS
--BEGIN
--	DECLARE @Tab VARCHAR(50)
--	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

--	IF 
--		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
--		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
--	BEGIN
--		SELECT 
--		ObjectName, 
--		CounterName, 
--		CounterAvg = AVG(CounterValue), 
--		CounterMin = MIN(CounterValue), 
--		CounterMax = MAX(CounterValue)
--		FROM dbo.Counterdata c
--		JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
--		WHERE ObjectName LIKE 'Network Interface%' AND
--		CounterName NOT LIKE 'Packets%' AND
--		CounterName NOT LIKE 'Output%'
--		GROUP BY ObjectName, CounterName
--		ORDER BY CounterName
--	END

--END
--GO
IF OBJECT_ID('GetPowerSettings') IS NOT NULL
DROP PROCEDURE GetPowerSettings
GO
CREATE PROCEDURE GetPowerSettings
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('tbl_PowerPlan') IS NOT NULL 
	BEGIN
		SELECT ActivePlanName
		FROM tbl_PowerPlan


	END

END
GO
IF OBJECT_ID('GetWaitsForCapture') IS NOT NULL
DROP PROCEDURE GetWaitsForCapture
GO
CREATE PROCEDURE GetWaitsForCapture
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	SET NOCOUNT ON
	IF OBJECT_ID('dbo.tbl_OS_WAIT_STATS') IS NOT NULL
	BEGIN
		--waits
		IF OBJECT_ID('tempdb..#WaitsForCapture') IS NOT NULL
		DROP TABLE #WaitsForCapture

		IF OBJECT_ID('tempdb..#TempWaiting') IS NOT NULL
		DROP TABLE #TempWaiting

		IF OBJECT_ID('tempdb..#WaitsForCapture') IS NOT NULL
		DROP TABLE #WaitsForCapture

		SELECT
			mx.wait_type,
			waiting_tasks_count = CAST(mx.waiting_tasks_count AS BIGINT)- CAST(mn.waiting_tasks_count AS BIGINT),
			wait_time_ms = CAST(mx.wait_time_ms AS BIGINT)- CAST(mn.wait_time_ms AS BIGINT),
			signal_wait_time_ms = CAST(mx.signal_wait_time_ms AS BIGINT) - CAST(mn.signal_wait_time_ms AS BIGINT)
		INTO #WaitsForCapture
		FROM
			(
			select *
			from [dbo].[tbl_OS_WAIT_STATS]
			where runtime = (select min(runtime)
			from [dbo].[tbl_OS_WAIT_STATS])
		) mn
			join
			(
			select *
			from [dbo].[tbl_OS_WAIT_STATS]
			where runtime = (select max(runtime)
			from [dbo].[tbl_OS_WAIT_STATS])
		) mx on mn.wait_type = mx.wait_type

		;WITH
			[Waits]
			AS
			(
				SELECT
					[wait_type],
					[wait_time_ms] / 1000.0 AS [WaitS],
					([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
					[signal_wait_time_ms] / 1000.0 AS [SignalS],
					[waiting_tasks_count] AS [WaitCount],
					100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
					ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
				FROM #WaitsForCapture
				WHERE [wait_type] NOT IN (
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
				N'XE_DISPATCHER_WAIT',              N'XE_TIMER_EVENT', 
				'PREEMPTIVE_OS_WRITEFILE', 'PREEMPTIVE_XE_DISPATCHER', 'QDS_ASYNC_QUEUE')
					AND [waiting_tasks_count] > 0
			)
		SELECT
			MAX ([W1].[wait_type]) AS [WaitType],
			CAST (MAX ([W1].[WaitS]) AS DECIMAL (16,2)) AS [Wait_S],
			CAST (MAX ([W1].[ResourceS]) AS DECIMAL (16,2)) AS [Resource_S],
			CAST (MAX ([W1].[SignalS]) AS DECIMAL (16,2)) AS [Signal_S],
			MAX ([W1].[WaitCount]) AS [WaitCount],
			CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage],
			CAST ((MAX ([W1].[WaitS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgWait_S],
			CAST ((MAX ([W1].[ResourceS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgRes_S],
			CAST ((MAX ([W1].[SignalS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgSig_S]
		INTO #TempWaiting
		FROM [Waits] AS [W1]
			INNER JOIN [Waits] AS [W2]
			ON [W2].[RowNum] <= [W1].[RowNum]
		GROUP BY [W1].[RowNum]
		HAVING SUM ([W2].[Percentage]) - MAX ([W1].[Percentage]) < 95;
		-- percentage threshold

		SELECT
			WaitType, WaitCount, Percentage, AvgWaitTimeSec = AvgWait_S
		--RowFlag = CASE WHEN CAST(Percentage AS DECIMAL) > 40 THEN 'R' ELSE 'N' END
		FROM #TempWaiting

	--BEGIN
	--	DECLARE @WaitType VARCHAR(50), @Percentage VARCHAR(10)
	--	PRINT SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	--	SELECT TOP 1 @WaitType = WaitType, @Percentage = CAST(Percentage AS VARCHAR(10))
	--	FROM #TempWaiting
	--	ORDER BY CAST(Percentage AS DECIMAL) DESC

	--	IF CAST(@Percentage AS DECIMAL) > 50
	--	INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	--	SELECT 'The top wait on the system is ' + @WaitType + ' which takes up ' + @Percentage + '% of overall wait time.','Database Design','Critical',NULL,NULL,NULL	

	--END
	END
END
GO
IF OBJECT_ID('GetBatchResponseBaseline') IS NOT NULL
DROP PROCEDURE GetBatchResponseBaseline
GO
CREATE PROCEDURE [dbo].[GetBatchResponseBaseline]
AS
BEGIN

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF OBJECT_ID('cust_BatchResponseBaseline') IS NOT NULL
	BEGIN
		SELECT * FROM cust_BatchResponseBaseline
	END
	ELSE
	BEGIN

		IF OBJECT_ID('tempdb..#BatchResponses') IS NOT NULL
		DROP TABLE #BatchResponses

		IF OBJECT_ID('dbo.CounterData') IS NOT NULL AND
			OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
		BEGIN
			SELECT
				CounterName, InstanceName,
				AverageValue = cast(AVG(cast(countervalue as decimal(18,3)))as decimal(18,3)),
				MaxValue = MAX(CAST(countervalue as decimal(18,3)))
			INTO #BatchResponses
			FROM dbo.CounterData d
				JOIN dbo.CounterDetails dd ON d.CounterID = dd.CounterID
			WHERE ObjectName LIKE '%Batch Resp Statistics'
				AND InstanceName IN(
			'Elapsed Time:Requests','Elapsed Time:Total(ms)'
			)
				AND MachineName = @MachineName
			GROUP BY CounterName, InstanceName

			SELECT
				BatchDuration = btime.countername,
				AvgRunTimeMS = FORMAT(CAST((CASE WHEN bcount.MaxValue = 0 THEN 0 ELSE btime.MaxValue/bcount.MaxValue END) AS DECIMAL(18,3)), 'N', 'en-us'),
				StatementCount = FORMAT(CAST(bcount.MaxValue AS BIGINT), 'N', 'en-us'),
				TimePercent = CASE WHEN btime.MaxValue = 0 THEN 0 ELSE CAST((100.0 * btime.MaxValue / SUM (btime.MaxValue) OVER()) as decimal(5,2)) END,
				CountPercent = CASE WHEN bcount.MaxValue = 0 THEN 0 ELSE CAST((100.0 * bcount.MaxValue / SUM (bcount.MaxValue) OVER()) as decimal(5,2)) END
			FROM
				(
			SELECT *
				FROM #BatchResponses
				WHERE InstanceName = 'Elapsed Time:Requests'
			) bcount
				JOIN
				(
			SELECT *
				FROM #BatchResponses
				WHERE InstanceName = 'Elapsed Time:Total(ms)'
			) btime ON bcount.CounterName = btime.CounterName
			order by bcount.CounterName asc

		END
	END
END
GO


IF OBJECT_ID('_GetPLEVariance') IS NOT NULL
DROP PROCEDURE _GetPLEVariance
GO

CREATE PROCEDURE _GetPLEVariance
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF OBJECT_ID('dbo.CounterData') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			RecordIndex, CounterDateTime,
			CounterValue, LeadVariance1Units = ISNULL(CAST(LeadVariance1Units AS DECIMAL(18,2)),0)
		FROM (
			SELECT
				RecordIndex, CounterDateTime, Countervalue,
				DiffVal = countervalue - LEAD(countervalue, 1) OVER(ORDER BY recordindex),
				LeadVariance1Units = (ABS(countervalue - LEAD(countervalue, 1) 
				OVER(ORDER BY recordindex))/(CASE WHEN CounterValue = 0 THEN 1 ELSE CounterValue END)*1.00)*100
			--LeadVariance5Units = (ABS(countervalue - LEAD(countervalue, 5) 
			--	OVER(ORDER BY recordindex))/(CASE WHEN CounterValue = 0 THEN 1 ELSE CounterValue END)*1.00)*100
			FROM dbo.Counterdata c
				JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
			WHERE ObjectName LIKE '%:Buffer Manager' AND
				CounterName = 'Page life expectancy' AND
				MachineName = @MachineName
		)x
		WHERE DiffVal > 100
	END

END
GO



IF OBJECT_ID('Summary_GetPLEDips') IS NOT NULL
DROP PROCEDURE Summary_GetPLEDips
GO

CREATE PROCEDURE Summary_GetPLEDips
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF OBJECT_ID('dbo.CounterData') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			DipCount = COUNT(*)
		FROM (
			SELECT
				RecordIndex, CounterDateTime, Countervalue,
				DiffVal = countervalue - LEAD(countervalue, 1) OVER(ORDER BY recordindex),
				VariancePercent = ((countervalue - LEAD(countervalue, 1) 
				OVER(ORDER BY recordindex))/(CASE WHEN CounterValue = 0 THEN 1 ELSE CounterValue END)*1.00)*100
			--LeadVariance5Units = (ABS(countervalue - LEAD(countervalue, 5) 
			--	OVER(ORDER BY recordindex))/(CASE WHEN CounterValue = 0 THEN 1 ELSE CounterValue END)*1.00)*100
			FROM dbo.Counterdata c
				JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
			WHERE ObjectName LIKE '%:Buffer Manager' AND
				CounterName = 'Page life expectancy' AND
				MachineName = @MachineName
		)x
		WHERE VariancePercent > 40
	END

END
GO



IF OBJECT_ID('GetTraceBatchData') IS NOT NULL
DROP PROCEDURE GetTraceBatchData
GO

CREATE PROCEDURE GetTraceBatchData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('[ReadTrace].[tblBatches]') IS NOT NULL AND
		OBJECT_ID('[ReadTrace].[tblConnections]') IS NOT NULL 
	BEGIN
		SELECT TOP(2500)
			t.StartTime,
			t.EndTime,
			t.Duration,
			t.Reads,
			t.Writes,
			t.CPU,
			ApplicationName,
			LoginName,
			HostName,
			NTDomainName,
			NTUserName,
			TextData = REPLACE(t.textdata, '''','''''')
		FROM
			[ReadTrace].[tblBatches] t
			JOIN [ReadTrace].[tblConnections] c ON t.ConnSeq = c.ConnSeq
		WHERE 
			t.textdata not like '%sp_trace%' AND
			t.textdata not like '%PRINT ''--%' AND
			t.textdata not like '%tbl_RUNTIMES%'
			AND t.Duration > 0
		ORDER BY t.Reads DESC
	END
END
GO
IF OBJECT_ID('GetStartupParameters') IS NOT NULL
DROP PROCEDURE GetStartupParameters
GO

CREATE PROCEDURE GetStartupParameters
AS
BEGIN

	IF OBJECT_ID('[dbo].[tbl_StartupParameters]') IS NOT NULL
	BEGIN

		SELECT ArgsName, ArgsValue = REPLACE(ArgsValue, '-','!')
		INTO #StartupParams
		FROM [dbo].[tbl_StartupParameters]
		WHERE ArgsName LIKE 'SQL%'

		IF OBJECT_ID('cust_AllDocumentedTraceFlags') IS NOT NULL
	BEGIN
			SELECT p.ArgsValue, TraceFlagDesc = c.Description
			FROM #StartupParams p
				LEFT JOIN cust_AllDocumentedTraceFlags c ON SUBSTRING(p.ArgsValue,3,LEN(p.ArgsValue)) = CAST(c.TraceFlag AS VARCHAR(10))
					AND p.ArgsValue LIKE '!T%'
		END
	ELSE
	BEGIN
			SELECT *
			FROM #StartupParams
		END

	END
END
GO
IF OBJECT_ID('GetOptimizerInfo') IS NOT NULL
DROP PROCEDURE GetOptimizerInfo
GO

CREATE PROCEDURE GetOptimizerInfo
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('[dbo].[cust_OptimizerInfo]') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_OptimizerInfo]
	END
END
GO
--IF OBJECT_ID('GetErrorLog') IS NOT NULL
--DROP PROCEDURE GetErrorLog
--GO

--CREATE PROCEDURE GetErrorLog
--AS
--BEGIN
--	DECLARE @Tab VARCHAR(50)
--	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

--	--have to do this dynamically becuse this table gets dropped and recreated later.
--	--need to fix that.
--	IF OBJECT_ID('[dbo].[cust_ErrorLog]') IS NOT NULL
--	BEGIN
--	EXECUTE ('SELECT * FROM [dbo].cust_ErrorLog
--	ORDER BY IDCol ASC')
--	END
--END
--GO

IF OBJECT_ID('_GetMSInfo') IS NOT NULL
DROP PROCEDURE _GetMSInfo
GO

CREATE PROCEDURE _GetMSInfo
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('[dbo].[cust_MSInfo]') IS NOT NULL
	BEGIN
		SELECT InfoDesc, Category
		FROM [dbo].cust_MSInfo
		WHERE Category IN('[Drives]','[Disks]','[Running Tasks]','[Services]') AND
			InfoDesc <> Category
		ORDER BY IDCol ASC
	END
END
GO

IF OBJECT_ID('_GetDriveInfo') IS NOT NULL
DROP PROCEDURE _GetDriveInfo
GO

CREATE PROCEDURE _GetDriveInfo
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('[dbo].[cust_MSInfo]') IS NOT NULL
	BEGIN
		SELECT DriveInfo = InfoDesc
		FROM [dbo].cust_MSInfo
		WHERE Category IN('[Drives]') AND
			InfoDesc <> Category
		ORDER BY IDCol ASC
	END
END
GO

IF OBJECT_ID('GetDiskInfo') IS NOT NULL
DROP PROCEDURE GetDiskInfo
GO

CREATE PROCEDURE GetDiskInfo
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('[dbo].[cust_MSInfo]') IS NOT NULL
	BEGIN
		SELECT DriveInfo = InfoDesc, *
		FROM [dbo].cust_MSInfo
		WHERE Category IN('[Disks]') AND
			InfoDesc <> Category
		ORDER BY IDCol ASC
	END
END
GO


IF OBJECT_ID('_GetSystemRunningTasks') IS NOT NULL
DROP PROCEDURE _GetSystemRunningTasks
GO

CREATE PROCEDURE _GetSystemRunningTasks
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('[dbo].[cust_MSInfo]') IS NOT NULL
	BEGIN
		SELECT TasksInfo = InfoDesc
		FROM [dbo].cust_MSInfo
		WHERE Category IN('[Running Tasks]') AND
			InfoDesc <> Category
		ORDER BY IDCol ASC
	END
END
GO


IF OBJECT_ID('_GetSystemServices') IS NOT NULL
DROP PROCEDURE _GetSystemServices
GO

CREATE PROCEDURE _GetSystemServices
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('[dbo].[cust_MSInfo]') IS NOT NULL
	BEGIN
		SELECT ServiceInfo = InfoDesc
		FROM [dbo].cust_MSInfo
		WHERE Category IN('[Services]') AND
			InfoDesc <> Category
		ORDER BY IDCol ASC
	END
END
GO



IF OBJECT_ID('_GetTaskList') IS NOT NULL
DROP PROCEDURE _GetTaskList
GO

CREATE PROCEDURE _GetTaskList
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('[dbo].[cust_TaskList]') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].cust_TaskList
		ORDER BY IDCol ASC
	END
END
GO


IF OBJECT_ID('GetNonDefaultSettings') IS NOT NULL
DROP PROCEDURE GetNonDefaultSettings
GO

CREATE PROCEDURE GetNonDefaultSettings
AS
BEGIN
	IF OBJECT_ID('tempdb..#ConfigDefaults') IS NOT NULL
DROP TABLE #ConfigDefaults

	IF OBJECT_ID('tbl_SPCONFIGURE') IS NOT NULL
BEGIN
		SELECT *
		INTO #ConfigDefaults
		FROM
			(
																																																																																																																																																																																						SELECT ConfigValue = 'access check cache bucket count' 	, DefaultValue = 0
			UNION ALL
				SELECT 'access check cache quota' 	, 0
			UNION ALL
				SELECT 'ad hoc distributed queries' 	, 0
			UNION ALL
				SELECT 'affinity I/O mask' 	, 0
			UNION ALL
				SELECT 'affinity64 I/O mask' 	, 0
			UNION ALL
				SELECT 'affinity mask' 	, 0
			UNION ALL
				SELECT 'affinity64 mask'	, 0
			UNION ALL
				SELECT 'automatic soft-NUMA disabled'	, 0
			UNION ALL
				SELECT 'backup checksum default'	, 0
			UNION ALL
				SELECT 'backup compression default'	, 0
			UNION ALL
				SELECT 'blocked process threshold '	, 0
			UNION ALL
				SELECT 'c2 audit mode '	, 0
			UNION ALL
				SELECT 'clr enabled'	, 0
			UNION ALL
				SELECT 'common criteria compliance enabled '	, 0
			UNION ALL
				SELECT 'contained database authentication'	, 0
			UNION ALL
				SELECT 'cost threshold for parallelism '	, 5
			UNION ALL
				SELECT 'cross db ownership chaining'	, 0
			UNION ALL
				SELECT 'cursor threshold ', -1
			UNION ALL
				--SELECT 'Database Mail XPs '	,0 UNION ALL 
				SELECT 'default full-text language '	, 1033
			UNION ALL
				SELECT 'default language'	, 0
			UNION ALL
				SELECT 'default trace enabled '	, 1
			UNION ALL
				SELECT 'disallow results from triggers '	, 0
			UNION ALL
				SELECT 'EKM provider enabled'	, 0
			UNION ALL
				SELECT 'external scripts enabled '	, 0
			UNION ALL
				SELECT 'filestream access level'	, 0
			UNION ALL
				SELECT 'fill factor (%)'	, 0
			UNION ALL
				SELECT 'index create memory (KB)'	, 0
			UNION ALL
				SELECT 'in-doubt xact resolution '	, 0
			UNION ALL
				SELECT 'lightweight pooling '	, 0
			UNION ALL
				SELECT 'locks'	, 0
			UNION ALL
				SELECT 'max degree of parallelism '	, 0
			UNION ALL
				SELECT 'max full-text crawl range '	, 4
			UNION ALL
				--SELECT 'max server memory (MB)'	,2147483647 UNION ALL 
				SELECT 'max text repl size'	, 65536
			UNION ALL
				SELECT 'max worker threads '	, 0
			UNION ALL
				SELECT 'media retention '	, 0
			UNION ALL
				SELECT 'min memory per query (KB)'	, 1024
			UNION ALL
				--SELECT 'min server memory (MB)'	,0 UNION ALL 
				SELECT 'nested triggers'	, 1
			UNION ALL
				SELECT 'network packet size (B)'	, 4096
			UNION ALL
				SELECT 'Ole Automation Procedures '	, 0
			UNION ALL
				SELECT 'open objects'	, 0
			UNION ALL
				--SELECT 'optimize for ad hoc workloads '	,0 UNION ALL 
				SELECT 'PH_timeout '	, 60
			UNION ALL
				SELECT 'PolyBase Hadoop and Azure blob storage '	, 0
			UNION ALL
				SELECT 'precompute rank '	, 0
			UNION ALL
				SELECT 'priority boost '	, 0
			UNION ALL
				SELECT 'query governor cost limit '	, 0
			UNION ALL
				SELECT 'query wait (s)', -1
			UNION ALL
				SELECT 'recovery interval (min)'	, 0
			UNION ALL
				SELECT 'remote access '	, 1
			UNION ALL
				SELECT 'remote admin connections'	, 0
			UNION ALL
				SELECT 'remote data archive'	, 0
			UNION ALL
				SELECT 'remote login timeout (s)'	, 10
			UNION ALL
				SELECT 'remote proc trans'	, 0
			UNION ALL
				--SELECT 'remote query timeout (s)'	,0 UNION ALL 
				SELECT 'Replication XPs Option '	, 0
			UNION ALL
				SELECT 'scan for startup procs '	, 0
			UNION ALL
				SELECT 'server trigger recursion'	, 1
			UNION ALL
				SELECT 'SMO and DMO XPs '	, 1
			UNION ALL
				SELECT 'transform noise words '	, 0
			UNION ALL
				SELECT 'two digit year cutoff '	, 2049
			UNION ALL
				SELECT 'user connections '	, 0
			UNION ALL
				SELECT 'user options'	, 0
			UNION ALL
				SELECT 'xp_cmdshell '	, 0 
	) x

		SELECT
			ConfigName = c.name,
			CurrentRunValue = run_value,
			DefaultValue
		FROM tbl_SPCONFIGURE c
			JOIN #ConfigDefaults d ON c.name = d.ConfigValue
		WHERE run_value <> DefaultValue
	END
END
GO





IF OBJECT_ID('GetConfigValuesToChange') IS NOT NULL
DROP PROCEDURE GetConfigValuesToChange
GO

CREATE PROCEDURE GetConfigValuesToChange
AS
BEGIN
	IF OBJECT_ID('tbl_SPCONFIGURE') IS NOT NULL
BEGIN

		IF OBJECT_ID('tempdb..#ConfigDefaults') IS NOT NULL
	DROP TABLE #ConfigDefaults
		SELECT *
		INTO #ConfigDefaults
		FROM
			(
								SELECT ConfigValue ='cost threshold for parallelism '	, DefaultValue =5
			UNION ALL
				SELECT 'max degree of parallelism '	, 0
			UNION ALL
				SELECT 'optimize for ad hoc workloads '	, 0 
	) x

		SELECT
			ConfigName = c.name,
			CurrentRunValue = run_value,
			DefaultValue
		FROM tbl_SPCONFIGURE c
			JOIN #ConfigDefaults d ON c.name = d.ConfigValue
		WHERE run_value = DefaultValue
	END


END
GO


IF OBJECT_ID('GetEnabledTraceFlags') IS NOT NULL
DROP PROCEDURE GetEnabledTraceFlags
GO

CREATE PROCEDURE GetEnabledTraceFlags
AS
BEGIN
	IF OBJECT_ID('cust_TraceFlags') IS NOT NULL
SELECT *
	FROM [dbo].[cust_TraceFlags]
END
GO
IF OBJECT_ID('GetNetworkData') IS NOT NULL
DROP PROCEDURE GetNetworkData
GO
CREATE PROCEDURE GetNetworkData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			ObjectName,
			CounterName,
			CounterAvg = AVG(CounterValue),
			CounterMin = MIN(CounterValue),
			CounterMax = MAX(CounterValue)
		INTO #Temp
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE 
			ObjectName LIKE 'Network Interface%' AND
			CounterName NOT LIKE 'Packets%' AND
			CounterName NOT LIKE 'Output%'
			AND MachineName = @MachineName
		GROUP BY ObjectName, CounterName
		ORDER BY CounterName

		SELECT
			CounterName, CounterAvg, AvgPercentOfCapacity = (CounterAvg/MaxNetworkBandwidth)*100,
			MaxPercentOfCapacity = (CounterMax/MaxNetworkBandwidth)*100, MaxNetworkBandwidth
		FROM #Temp t
		CROSS APPLY
		(
			SELECT MaxNetworkBandwidth = CounterMax
			FROM #Temp
			WHERE CounterName = 'Current Bandwidth'
		)x
		WHERE CounterName LIKE 'Bytes%'

	END
END
GO


IF OBJECT_ID('GetSuspectPages') IS NOT NULL
DROP PROCEDURE GetSuspectPages
GO
CREATE PROCEDURE GetSuspectPages
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.cust_SuspectPages') IS NOT NULL
	BEGIN
		SELECT *
		FROM dbo.cust_SuspectPages
	END

END
GO




/*




*/

IF OBJECT_ID('GetCursorUsage') IS NOT NULL
DROP PROCEDURE GetCursorUsage
GO
CREATE PROCEDURE GetCursorUsage
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.cust_Cursors') IS NOT NULL
	BEGIN
		SELECT
			runtime,
			count,
			opencount = [open count],
			oldestcreate = [oldest create],
			properties = replace(replace(properties,'|',''),'(0)','')
		FROM dbo.cust_Cursors
	END

END
GO


IF OBJECT_ID('GetDBDiskSpace') IS NOT NULL
DROP PROCEDURE GetDBDiskSpace
GO
CREATE PROCEDURE GetDBDiskSpace
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.cust_DBDiskSpace') IS NOT NULL
	BEGIN
		SELECT *
		FROM dbo.cust_DBDiskSpace
	END
END
GO
IF OBJECT_ID('GetDeprecatedFeatueres') IS NOT NULL
DROP PROCEDURE GetDeprecatedFeatueres
GO
CREATE PROCEDURE GetDeprecatedFeatueres
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.cust_DeprecatedFeatures') IS NOT NULL
	BEGIN
		SELECT
			Feature = instance_name,
			UsageCount = CAST(cntr_value AS BIGINT)
		FROM dbo.cust_DeprecatedFeatures
		WHERE
			CAST(cntr_value AS BIGINT) > 0
		ORDER BY CAST(cntr_value AS BIGINT) DESC
	END
END
GO

IF OBJECT_ID('GetTablesMissingIndexes') IS NOT NULL
DROP PROCEDURE GetTablesMissingIndexes
GO
CREATE PROCEDURE GetTablesMissingIndexes
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('tempdb..#TablesMissingIndexes') IS NOT NULL
	DROP TABLE #TablesMissingIndexes

	IF OBJECT_ID('[dbo].[cust_IndexDetail]') IS NOT NULL
	BEGIN
		--tables w/o a clustered index
		SELECT *
		INTO #TablesMissingIndexes
		FROM
			(
							SELECT DBName, TableName, IndexStatus = 'No clustered index'
				FROM [dbo].[cust_IndexDetail]
				WHERE 
				IndexType = 'HEAP'
			UNION ALL
				--tables w/o a NC index
				SELECT DBName, TableName, IndexStatus = 'No non-clustered indexes'
				FROM [dbo].[cust_IndexDetail] o
				WHERE IndexType NOT IN('NONCLUSTERED') AND
					IndexType NOT LIKE '%COLUMNSTORE%'
					AND NOT EXISTS
			(
				SELECT *
					FROM [dbo].[cust_IndexDetail] i
					WHERE IndexType = 'NONCLUSTERED' AND
						i.DBName = o.DBName AND
						i.TableName = o.TableName
			)
		) x

		IF OBJECT_ID('[dbo].cust_CompressionDetails') IS NOT NULL
		BEGIN

			SELECT DISTINCT tmi.*, RowCnt = CAST(c.RowCnt AS BIGINT), c.DataCompressionDescription
			FROM #TablesMissingIndexes tmi
				JOIN [dbo].[cust_CompressionDetails] c
				ON tmi.DBName = c.DBName AND
					tmi.TableName = c.TableName
			ORDER BY CAST(c.RowCnt AS BIGINT) DESC
		END
		ELSE
		BEGIN
			SELECT DISTINCT tmi.*
			FROM #TablesMissingIndexes tmi
		END


	END
END
GO

IF OBJECT_ID('GetTriggerExecutionMetrics') IS NOT NULL
DROP PROCEDURE GetTriggerExecutionMetrics
GO
CREATE PROCEDURE GetTriggerExecutionMetrics
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('tempdb..#TriggerData') IS NOT NULL
	DROP TABLE #TriggerData

	IF OBJECT_ID('dbo.cust_Triggers') IS NOT NULL 
	BEGIN
		SELECT DISTINCT
			TriggerName = t.name,
			TableName = t.parent_table,
			RowCnt = CAST(NULL AS BIGINT),
			TriggerExecutionCount = CASE WHEN t.execution_count IS NULL OR t.execution_count = 'NULL' THEN 0 ELSE t.execution_count END,
			total_logical_reads,
			total_logical_writes,
			total_elapsed_time,
			min_elapsed_time,
			max_elapsed_time,
			min_logical_reads,
			max_logical_reads,
			DBName,
			TriggerType = type_desc
		INTO #TriggerData
		FROM dbo.cust_Triggers t
	END

	IF OBJECT_ID('dbo.cust_CompressionDetails') IS NOT NULL AND
		OBJECT_ID('tempdb..#TriggerData') IS NOT NULL
	BEGIN
		UPDATE t
		SET
			RowCnt = CAST(d.RowCnt AS BIGINT)
		FROM #TriggerData t
			JOIN dbo.cust_CompressionDetails d
			ON t.DBName = d.DBName AND
				t.TableName = d.TableName
	END

	IF OBJECT_ID('tempdb..#TriggerData') IS NOT NULL
	BEGIN
		SELECT *
		FROM #TriggerData
		ORDER BY CAST(TriggerExecutionCount AS INT) DESC
	END
END
GO

IF OBJECT_ID('GetLockInfo') IS NOT NULL
DROP PROCEDURE GetLockInfo
GO
CREATE PROCEDURE GetLockInfo
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
		SELECT
			ObjectName,
			CounterName,
			CounterAvg = AVG(CounterValue),
			CounterMin = MIN(CounterValue),
			CounterMax = MAX(CounterValue)
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName LIKE '%Locks%'
			AND MachineName = @MachineName
		GROUP BY ObjectName, CounterName
		ORDER BY CounterName
	END
END
GO


IF OBJECT_ID('GetDBMirroring') IS NOT NULL
DROP PROCEDURE GetDBMirroring
GO
CREATE PROCEDURE GetDBMirroring
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.cust_DatabaseMirroring') IS NOT NULL 
	BEGIN
		SELECT *
		FROM dbo.cust_DatabaseMirroring

	END
END
GO



IF OBJECT_ID('GetPendingIOs') IS NOT NULL
DROP PROCEDURE GetPendingIOs
GO
CREATE PROCEDURE GetPendingIOs
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.cust_PendingIOs') IS NOT NULL 
	BEGIN
		SELECT io_handle_path, io_offset, io_user_data_address, io_completion_request_address
		INTO #pendingIOs
		FROM dbo.cust_PendingIOs
		GROUP BY io_handle_path, io_offset, io_user_data_address, io_completion_request_address
		HAVING(COUNT(*) > 1)

		SELECT o.*
		FROM #pendingIOs p
		JOIN dbo.cust_PendingIOs o ON
		p.io_handle_path = o.io_handle_path AND
		p.io_offset = o.io_offset AND
		p.io_user_data_address = o.io_user_data_address AND
		p.io_completion_request_address = o.io_completion_request_address

		/*
				SELECT io_offset, io_user_data_address, io_completion_request_address
		INTO #pendingIOs
		FROM dbo.cust_PendingIOs
		WHERE io_type <> 'network'
		GROUP BY io_offset, io_user_data_address, io_completion_request_address
		HAVING(COUNT(*) > 1)

		SELECT o.*
		FROM #pendingIOs p
		JOIN dbo.cust_PendingIOs o ON
		p.io_offset = o.io_offset AND
		p.io_user_data_address = o.io_user_data_address AND
		p.io_completion_request_address = o.io_completion_request_address
		*/
	END
END
GO
------------------------------------------------------------------------
IF OBJECT_ID('GetSchedulerMonitor') IS NOT NULL
DROP PROCEDURE GetSchedulerMonitor
GO
CREATE PROCEDURE GetSchedulerMonitor
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.tbl_scheduler_monitor') IS NOT NULL 
	BEGIN
		SELECT *
		FROM dbo.tbl_scheduler_monitor

	END
END
GO
IF OBJECT_ID('GetMemoryResources') IS NOT NULL
DROP PROCEDURE GetMemoryResources
GO
CREATE PROCEDURE GetMemoryResources
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.tbl_Resource') IS NOT NULL 
	BEGIN
		SELECT
			timestamp, state, LastNotification, available_physical_memory/(1024*1024) as AvailableMemory_MB,
			working_set/(1024*1024) as WorkingSet_MB ,
			available_virtual_memory/(1024*1024) as available_virtual_memory_MB,
			Target_committed_kb/1024 as TargetMemory_MB,
			current_committed_kb/1024 as TotalMemoryMB,
			Pages_free_kb/1024 as PagesFree_MB,
			Pages_allocated_kb/1024 as PagesAllocated_MB,
			Pages_in_use_kb/1024 as Pages_in_use_MB,
			locked_pages_allocated_kb/1024 as locked_pages_allocated_MB,
			large_pages_allocated_kb /1024  as large_pages_allocated_MB,
			outOfMemoryExceptions, isAnyPoolOutOfMemory, processOutOfMemoryPeriod,
			percent_workingset_committed,
			page_faults
		sys_physical_memory_high , sys_physical_memory_low ,
			process_phyiscal_memory_low , process_virtual_memory_low
		FROM tbl_Resource
		ORDER BY TIMESTAMP ASC

	END
END
GO
IF OBJECT_ID('GetIOSubsystem') IS NOT NULL
DROP PROCEDURE GetIOSubsystem
GO
CREATE PROCEDURE GetIOSubsystem
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.tbl_IO_SUBSYSTEM') IS NOT NULL 
	BEGIN
		SELECT
			timestamp, component_state,
			ioLatchTimeouts, intervalLongIos, totalLongIos, longestPendingRequests_duration,
			longestPendingRequests_filePath
		FROM tbl_IO_SUBSYSTEM
		WHERE longestPendingRequests_duration > 0
		ORDER BY longestPendingRequests_duration DESC

	END
END
GO
IF OBJECT_ID('GetSystemComponentStatus') IS NOT NULL
DROP PROCEDURE GetSystemComponentStatus
GO
CREATE PROCEDURE GetSystemComponentStatus
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.tbl_SYSTEM') IS NOT NULL 
	BEGIN
		SELECT *
		FROM tbl_SYSTEM
		WHERE 
			component_state <> 'CLEAN' OR
			spinlockBackoffs > 0 OR
			sickSpinlockTypeAfterAv <> 'none' OR
			latchWarnings > 0 OR
			isAccessViolationOccurred > 0 OR
			writeAccessViolationCount > 0 OR
			totalDumpRequests > 0 OR
			intervalDumpRequests > 0 OR
			nonYieldingTasksReported  > 0 OR
			systemCpuUtilization > 90 OR
			sqlCpuUtilization  > 90 OR
			BadPagesDetected > 0 OR
			BadPagesFixed > 0 OR
			LastBadPageAddress <> '0x0'

	END
END
GO
IF OBJECT_ID('GetSystemComponentSummary') IS NOT NULL
DROP PROCEDURE GetSystemComponentSummary
GO
CREATE PROCEDURE GetSystemComponentSummary
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.tbl_Summary') IS NOT NULL 
	BEGIN
		SELECT *
		FROM dbo.tbl_Summary

	END
END
GO
IF OBJECT_ID('GetSystemHealthWaitStats') IS NOT NULL
DROP PROCEDURE GetSystemHealthWaitStats
GO
CREATE PROCEDURE GetSystemHealthWaitStats
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('tempdb..#Waits') IS NOT NULL
	DROP TABLE #Waits

	IF OBJECT_ID('tempdb..#TopWaits') IS NOT NULL
	DROP TABLE #TopWaits

	IF OBJECT_ID('') IS NOT NULL
	BEGIN

		SELECT DISTINCT *, WaitDate = CAST(timestamp AS DATE)
		INTO #Waits
		FROM dbo.tbl_OS_WAIT_STATS_byDuration
		WHERE wait_type NOT LIKE '%PREEMPTIVE%' AND
			wait_category <> 'IGNORABLE'

		SELECT
			*,
			ID = ROW_NUMBER() OVER(PARTITION BY WaitDate  ORDER BY WaitDiff DESC)
		INTO #TopWaits
		FROM
			(			
		SELECT wait_type,
				WaitDiff = AVG(waiting_tasks_count - PrevWaitCount),
				WaitDate = CAST(timestamp AS DATE)
			FROM (
			SELECT DISTINCT
					UTCtimestamp, timestamp, wait_type, waiting_tasks_count = CAST(waiting_tasks_count AS BIGINT),
					avg_wait_time_ms, max_wait_time_ms, wait_category,
					PrevWaitCount = LAG(waiting_tasks_count, 1) OVER(PARTITION BY wait_type ORDER BY timestamp ASC)
				FROM #Waits
		) x
			GROUP BY wait_type, CAST(timestamp AS DATE)
	) y

		SELECT
			WaitDate,
			RecordedTime = timestamp,
			wait_type,
			waiting_tasks_count,
			avg_wait_time_ms,
			wait_category,
			PrevWaitCount,
			WaitDiff = waiting_tasks_count - PrevWaitCount,
			DateRank = ID
		FROM (
	SELECT DISTINCT
				UTCtimestamp, timestamp, w.wait_type, waiting_tasks_count = CAST(waiting_tasks_count AS BIGINT),
				avg_wait_time_ms, max_wait_time_ms, wait_category, t.ID,
				PrevWaitCount = LAG(waiting_tasks_count, 1) OVER(PARTITION BY w.wait_type ORDER BY timestamp ASC),
				w.WaitDate
			FROM #Waits w
				JOIN #TopWaits t ON w.wait_type = t.wait_type AND w.WaitDate = t.WaitDate
			WHERE t.ID <= 5
	) x
		ORDER BY WaitDate, ID ASC, timestamp ASC

	END
END
GO

IF OBJECT_ID('GetQueryProcessingStatus') IS NOT NULL
DROP PROCEDURE GetQueryProcessingStatus
GO
CREATE PROCEDURE GetQueryProcessingStatus
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.tbl_QUERY_PROCESSING') IS NOT NULL 
	BEGIN
		SELECT *
		FROM dbo.tbl_QUERY_PROCESSING
		WHERE component_state != 'CLEAN'

	END
END
GO

IF OBJECT_ID('GetBlockingXEData') IS NOT NULL
DROP PROCEDURE GetBlockingXEData
GO
CREATE PROCEDURE GetBlockingXEData
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.tbl_BlockingXeOutput') IS NOT NULL 
	BEGIN
		SELECT *
		FROM dbo.tbl_BlockingXeOutput

	END
END
GO
/*
IF OBJECT_ID('GetSecurityEvents') IS NOT NULL
DROP PROCEDURE GetSecurityEvents
GO
CREATE PROCEDURE GetSecurityEvents
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.tbl_security_ring_buffer') IS NOT NULL 
	BEGIN
		SELECT *
		FROM dbo.tbl_security_ring_buffer

	END
END
GO
*/
IF OBJECT_ID('GetXEErrors') IS NOT NULL
DROP PROCEDURE GetXEErrors
GO
CREATE PROCEDURE GetXEErrors
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.tbl_errors') IS NOT NULL 
	BEGIN
		SELECT
			error_number,
			ErrorMessage = MIN(message),
			RwCnt = COUNT(*)
		FROM dbo.tbl_errors
		WHERE 
			message NOT LIKE 'Changed database context to%' AND
			message > '' AND
			message NOT LIKE '--%' AND
			message NOT LIKE 'Changed language setting%' AND
			error_number NOT IN('17806') AND
			message NOT LIKE('%occurred while establishing a connection; the connection has been closed%')
		GROUP BY error_number
		ORDER BY RwCnt DESC

	END
END
GO

IF OBJECT_ID('GetConnectivityRB') IS NOT NULL
DROP PROCEDURE GetConnectivityRB
GO
CREATE PROCEDURE GetConnectivityRB
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF 
		OBJECT_ID('dbo.tbl_connectivity_ring_buffer') IS NOT NULL 
	BEGIN
		SELECT *
		FROM dbo.tbl_connectivity_ring_buffer

	END
END
GO
IF OBJECT_ID('TransformErrorLog') IS NOT NULL
DROP PROCEDURE TransformErrorLog
GO
CREATE PROCEDURE TransformErrorLog
	(
	@FileName VARCHAR(255)
)
AS
BEGIN

	DECLARE @InstanceName VARCHAR(255)

	SELECT TOP(1)
		@InstanceName = 
	SUBSTRING(
		ErrorMessage,
		(CHARINDEX('Server name is', ErrorMessage)+14), 
		(CHARINDEX('''.', ErrorMessage)) - (CHARINDEX('Server name is', ErrorMessage)+13)
		)
	FROM cust_ErrorLogRaw o
	WHERE ErrorMessage LIKE '%Server name%'

	INSERT INTO cust_ErrorLog
		(
		ErrorMessage,
		ErrorDate,
		ErrorFileName,
		InstanceName
		)
	SELECT
		CASE WHEN ISDATE(LEFT(ErrorMessage,23)) = 1 THEN LTRIM(RTRIM(SUBSTRING(ErrorMessage,24, LEN(ErrorMessage)))) ELSE ErrorMessage END,
		CASE WHEN ISDATE(LEFT(ErrorMessage,23)) = 1 THEN LEFT(ErrorMessage,23) ELSE NULL END,
		@FileName,
		REPLACE(@InstanceName,'''','')
	FROM cust_ErrorLogRaw
END
GO



IF OBJECT_ID('GetDeadlocks') IS NOT NULL
DROP PROCEDURE GetDeadlocks
GO
CREATE PROCEDURE GetDeadlocks
AS
BEGIN
	SET NOCOUNT ON

	IF OBJECT_ID('tempdb..#Deadlock') IS NOT NULL
	DROP TABLE #Deadlock

	CREATE TABLE #Deadlock
	(
		DeadlockID INT IDENTITY PRIMARY KEY CLUSTERED,
		UTCTimeStamp DATETIME,
		LocalTimeStamp DATETIME,
		DeadlockGraph XML
	)

	IF OBJECT_ID('tbl_DeadlockReport') IS NOT NULL
	BEGIN

		INSERT INTO #Deadlock
			(UTCTimeStamp, LocalTimeStamp, DeadlockGraph)
		SELECT UTCTimeStamp, timestamp, c1
		FROM tbl_DeadlockReport

		--CREATE PRIMARY XML INDEX ix_DLG 
		--ON #Deadlock(DeadlockGraph)

		IF OBJECT_ID('tempdb..#Victims') IS NOT NULL
		DROP TABLE #Victims

		SELECT
			ID = Victims.List.value('@id', 'varchar(50)')
		INTO #Victims
		FROM
			#Deadlock CTE
			CROSS APPLY CTE.DeadlockGraph.nodes('//deadlock/victim-list/victimProcess') AS Victims (List)

		IF OBJECT_ID('tempdb..#DeadlockLocks') IS NOT NULL
		DROP TABLE #DeadlockLocks

		SELECT
			CTE.DeadlockID,
			UTCTimeStamp,
			LocalTimeStamp,
			MainLock.Process.value('@id', 'varchar(100)') AS LockID,
			OwnerList.Owner.value('@id', 'varchar(200)') AS LockProcessId,
			REPLACE(MainLock.Process.value('local-name(.)', 'varchar(100)'), 'lock', '') AS LockEvent,
			MainLock.Process.value('@objectname', 'sysname') AS ObjectName,
			OwnerList.Owner.value('@mode', 'varchar(10)') AS LockMode,
			MainLock.Process.value('@dbid', 'INTEGER') AS Database_id,
			MainLock.Process.value('@associatedObjectId', 'BIGINT') AS AssociatedObjectId,
			MainLock.Process.value('@WaitType', 'varchar(100)') AS WaitType,
			WaiterList.Owner.value('@id', 'varchar(200)') AS WaitProcessId,
			WaiterList.Owner.value('@mode', 'varchar(10)') AS WaitMode
		INTO #DeadlockLocks
		FROM
			#Deadlock CTE
			CROSS APPLY CTE.DeadlockGraph.nodes('//deadlock/resource-list') AS Lock (list)
			CROSS APPLY Lock.list.nodes('*') AS MainLock (Process)
			OUTER APPLY MainLock.Process.nodes('owner-list/owner') AS OwnerList (Owner)
			CROSS APPLY MainLock.Process.nodes('waiter-list/waiter') AS WaiterList (Owner)

		IF OBJECT_ID('tempdb..#Process') IS NOT NULL
		DROP TABLE #Process

		SELECT
			CTE.DeadlockID,
			UTCTimeStamp,
			LocalTimeStamp,
			[Victim] = CONVERT(BIT, CASE WHEN Deadlock.Process.value('@id', 'varchar(50)') = ISNULL(Deadlock.Process.value('../../@victim', 'varchar(50)'), v.ID) 
											THEN 1
											ELSE 0
									END),
			[LockMode] = Deadlock.Process.value('@lockMode', 'varchar(10)'), -- how is this different from in the resource-list section?
			[ProcessID] = Process.ID, --Deadlock.Process.value('@id', 'varchar(50)'),
			[KPID] = Deadlock.Process.value('@kpid', 'BIGINT'), -- kernel-process id / thread ID number
			[SPID] = Deadlock.Process.value('@spid', 'BIGINT'), -- system process id (connection to sql)
			[SBID] = Deadlock.Process.value('@sbid', 'BIGINT'), -- system batch id / request_id (a query that a SPID is running)
			[ECID] = Deadlock.Process.value('@ecid', 'BIGINT'), -- execution context ID (a worker thread running part of a query)
			[IsolationLevel] = Deadlock.Process.value('@isolationlevel', 'varchar(200)'),
			[WaitResource] = Deadlock.Process.value('@waitresource', 'varchar(200)'),
			[LogUsed] = Deadlock.Process.value('@logused', 'BIGINT'),
			[ClientApp] = Deadlock.Process.value('@clientapp', 'varchar(100)'),
			[HostName] = Deadlock.Process.value('@hostname', 'varchar(20)'),
			[LoginName] = Deadlock.Process.value('@loginname', 'varchar(20)'),
			[TransactionTime] = Deadlock.Process.value('@lasttranstarted', 'datetime'),
			[BatchStarted] = Deadlock.Process.value('@lastbatchstarted', 'datetime'),
			[BatchCompleted] = Deadlock.Process.value('@lastbatchcompleted', 'datetime'),
			[InputBuffer] = Input.Buffer.value('.', 'varchar(2000)'),
			--CTE.[DeadlockGraph],
			es.ExecutionStack,
			--[SQLHandle] = ExecStack.Stack.value('@sqlhandle', 'varchar(64)'),
			[QueryStatement] = NULLIF(ExecStack.Stack.value('.', 'varchar(max)'), ''),
			--[QueryStatement] = Execution.Frame.value('.', 'varchar(max)'),
			[ProcessQty] = SUM(1) OVER (PARTITION BY CTE.DeadlockID),
			[TranCount] = Deadlock.Process.value('@trancount', 'BIGINT')
		INTO #Process
		FROM
			#Deadlock CTE
			CROSS APPLY CTE.DeadlockGraph.nodes('//deadlock/process-list/process') AS Deadlock (Process)
			CROSS APPLY (SELECT Deadlock.Process.value('@id', 'varchar(50)') ) AS Process (ID)
			LEFT JOIN #Victims v ON Process.ID = v.ID
			CROSS APPLY Deadlock.Process.nodes('inputbuf') AS Input (Buffer)
			CROSS APPLY Deadlock.Process.nodes('executionStack') AS Execution (Frame)
		-- get the data from the executionStack node as XML
			CROSS APPLY 
			(
				SELECT ExecutionStack = 
				(
					SELECT
					ProcNumber = ROW_NUMBER() OVER (PARTITION BY CTE.DeadlockID,
							Deadlock.Process.value('@id', 'varchar(50)'),
							Execution.Stack.value('@procname', 'sysname'),
							Execution.Stack.value('@code', 'varchar(MAX)') 
							ORDER BY (SELECT 1)),
					ProcName = Execution.Stack.value('@procname', 'sysname'),
					Line = Execution.Stack.value('@line', 'BIGINT'),
					SQLHandle = Execution.Stack.value('@sqlhandle', 'varchar(64)'),
					Code = LTRIM(RTRIM(Execution.Stack.value('.', 'varchar(MAX)')))
				FROM Execution.Frame.nodes('frame') AS Execution (Stack)
				ORDER BY ProcNumber
				FOR XML PATH('frame'), ROOT('executionStack'), TYPE 
				)
			) es
			CROSS APPLY Execution.Frame.nodes('frame') AS ExecStack (Stack)

		SELECT DISTINCT
			p.DeadlockID,
			p.UTCTimeStamp,
			p.LocalTimeStamp,
			p.Victim,
			p.ProcessQty,
			ProcessNbr = DENSE_RANK() 
							OVER (PARTITION BY p.DeadlockId 
									ORDER BY p.ProcessID),
			p.LockMode,
			LockedObject = NULLIF(l.ObjectName, ''),
			l.database_id,
			l.AssociatedObjectId,
			LockProcess = p.ProcessID,
			p.KPID,
			p.SPID,
			p.SBID,
			p.ECID,
			p.TranCount,
			l.LockEvent,
			LockedMode = l.LockMode,
			l.WaitProcessID,
			l.WaitMode,
			p.WaitResource,
			l.WaitType,
			p.IsolationLevel,
			p.LogUsed,
			p.ClientApp,
			p.HostName,
			p.LoginName,
			p.TransactionTime,
			p.BatchStarted,
			p.BatchCompleted,
			p.QueryStatement,
			--p.SQLHandle,
			p.InputBuffer
		--p.DeadlockGraph,
		--p.ExecutionStack
		FROM
			#Process p
			LEFT JOIN #DeadlockLocks l ON 
				p.DeadlockID = l.DeadlockID AND
				p.ProcessID = l.LockProcessID
		ORDER BY 
			p.DeadlockId,
			p.Victim DESC,
			p.ProcessId;

	END
END
GO


IF OBJECT_ID('GetDatabaseMirroringData') IS NOT NULL
DROP PROCEDURE GetDatabaseMirroringData
GO
CREATE PROCEDURE GetDatabaseMirroringData
AS
BEGIN
	IF (OBJECT_ID('Counterdata') IS NOT NULL AND OBJECT_ID('CounterDetails') IS NOT NULL)
	BEGIN
		IF EXISTS(
			SELECT
			ObjectName,
			CounterName,
			InstanceName ,
			CounterMax = MAX(CounterValue)
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName LIKE '%Mirror%'
		GROUP BY 
				ObjectName, 
				CounterName,
				InstanceName
		HAVING MAX(CounterValue) > 0
		)
		BEGIN
			SELECT

				ObjectName,
				CounterName,
				InstanceName ,
				CounterAvg = FORMAT(AVG(CounterValue), 'N'),
				CounterMin = FORMAT(MIN(CounterValue), 'N'),
				CounterMax = FORMAT(MAX(CounterValue), 'N')
			FROM dbo.Counterdata c
				JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
			WHERE ObjectName LIKE '%Mirror%'
			--OR ObjectName LIKE '%Database Replica%'
			GROUP BY 
			ObjectName, 
			CounterName,
			InstanceName
		END
	END


END
GO


IF OBJECT_ID('GetAGPerfData') IS NOT NULL
DROP PROCEDURE GetAGPerfData
GO
CREATE PROCEDURE GetAGPerfData
AS
BEGIN
	IF (OBJECT_ID('Counterdata') IS NOT NULL AND OBJECT_ID('CounterDetails') IS NOT NULL)
	BEGIN
		IF EXISTS
		(
			SELECT
			ObjectName,
			CounterName,
			InstanceName ,
			CounterMax = MAX(CounterValue)
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName LIKE '%Database Replica%'
		GROUP BY 
				ObjectName, 
				CounterName,
				InstanceName
		HAVING MAX(CounterValue) > 0
		)
		BEGIN
			SELECT

				ObjectName,
				CounterName,
				InstanceName ,
				CounterAvg = FORMAT(AVG(CounterValue), 'N'),
				CounterMin = FORMAT(MIN(CounterValue), 'N'),
				CounterMax = FORMAT(MAX(CounterValue), 'N')
			FROM dbo.Counterdata c
				JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
			WHERE ObjectName LIKE '%Database Replica%'
			GROUP BY 
			ObjectName, 
			CounterName,
			InstanceName
		END

	END

END
GO

IF OBJECT_ID('_GetReplicationAgents') IS NOT NULL
DROP PROCEDURE _GetReplicationAgents
GO
CREATE PROCEDURE _GetReplicationAgents
AS
BEGIN
	IF (OBJECT_ID('Counterdata') IS NOT NULL AND OBJECT_ID('CounterDetails') IS NOT NULL)
	BEGIN
		SELECT

			ObjectName,
			CounterName,
			InstanceName ,
			CounterAvg = FORMAT(AVG(CounterValue), 'N'),
			CounterMin = FORMAT(MIN(CounterValue), 'N'),
			CounterMax = FORMAT(MAX(CounterValue), 'N')
		FROM dbo.Counterdata c
			JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
		WHERE ObjectName LIKE '%Replication Agents%' AND
			CounterName = 'Running'
		GROUP BY 
		ObjectName, 
		CounterName,
		InstanceName
	END

END
GO
IF OBJECT_ID('GetMemoryConsumers') IS NOT NULL
DROP PROCEDURE GetMemoryConsumers
GO
CREATE PROCEDURE GetMemoryConsumers
AS
BEGIN
	IF (OBJECT_ID('cust_MemoryClerks') IS NOT NULL)
	BEGIN
		SELECT
			MemPercentage = CAST((100.0 * (CAST(Pages_KB AS BIGINT)) / SUM (CAST(Pages_KB AS BIGINT)) OVER()) AS DECIMAL(18,2)),
			Rnk = ROW_NUMBER() OVER(ORDER BY CAST(Pages_KB AS BIGINT) DESC), *
		FROM [dbo].[cust_MemoryClerks]
		WHERE type <> 'USERSTORE_TOKENPERM'
			AND pages_kb > 250
	END
END
GO

IF OBJECT_ID('GetAGReplicas') IS NOT NULL
DROP PROCEDURE GetAGReplicas
GO
CREATE PROCEDURE GetAGReplicas
AS
BEGIN
	IF (OBJECT_ID('cust_AGReplicas') IS NOT NULL) AND
		(OBJECT_ID('cust_AGReplicaStates') IS NOT NULL)
	BEGIN
		SELECT
			replica_server_name, owner_sid, endpoint_url, availability_mode, availability_mode_desc,
			failover_mode, failover_mode_desc, session_timeout, primary_role_allow_connections,
			primary_role_allow_connections_desc, secondary_role_allow_connections,
			secondary_role_allow_connections_desc, create_date, modify_date, backup_priority,
			read_only_routing_url,
			is_local, role, role_desc, operational_state, operational_state_desc, connected_state,
			connected_state_desc, recovery_health, recovery_health_desc, synchronization_health,
			synchronization_health_desc, last_connect_error_number, last_connect_error_description,
			last_connect_error_timestamp
		FROM [dbo].[cust_AGReplicas] rep
			JOIN [dbo].[cust_AGReplicaStates] rs ON rep.replica_id = rs.replica_id
				AND rs.group_id = rs.group_id

	END
END
GO
IF OBJECT_ID('GetAGState') IS NOT NULL
DROP PROCEDURE GetAGState
GO
CREATE PROCEDURE GetAGState
AS
BEGIN
	IF (OBJECT_ID('cust_AGStates') IS NOT NULL)
	BEGIN
		SELECT *
		FROM [dbo].[cust_AGStates]
	END
END

GO

IF OBJECT_ID('GetAGs') IS NOT NULL
DROP PROCEDURE GetAGs
GO
CREATE PROCEDURE GetAGs
AS
BEGIN
	IF (OBJECT_ID('cust_AGs') IS NOT NULL)
	BEGIN
		SELECT *
		FROM [dbo].[cust_AGs]
	END
END

GO

IF OBJECT_ID('GetTopMemGrantStatements') IS NOT NULL
DROP PROCEDURE GetTopMemGrantStatements
GO
CREATE PROCEDURE GetTopMemGrantStatements
AS
BEGIN
	IF (OBJECT_ID('tbl_Query_Execution_Memory') IS NOT NULL)
	BEGIN
		SELECT *
		FROM [dbo].[tbl_Query_Execution_Memory]
		WHERE text NOT LIKE '% sp_mem_stats_grants %'
		ORDER BY CAST(logical_reads AS BIGINT) DESC
	END
END

GO
IF OBJECT_ID('udf_GetMachineName') IS NOT NULL
DROP FUNCTION udf_GetMachineName
GO
CREATE FUNCTION [dbo].[udf_GetMachineName]()
RETURNS VARCHAR(255)
AS
BEGIN
	DECLARE @MachineName VARCHAR(255)

	IF OBJECT_ID('cust_SQLPerfmonInstances') IS NOT NULL
	BEGIN
		IF (
		SELECT COUNT(DISTINCT MachineName)
		FROM cust_SQLPerfmonInstances
		) = 1
		BEGIN
			SELECT @MachineName = LTRIM(RTRIM(REPLACE(Machinename, '\\', '')))
			FROM cust_SQLPerfmonInstances
		END
	END

	IF ISNULL(@MachineName,'') = ''
		BEGIN
		IF OBJECT_ID('tbl_SCRIPT_ENVIRONMENT_DETAILS') IS NOT NULL
		BEGIN
			SELECT @MachineName = Value
			FROM dbo.tbl_SCRIPT_ENVIRONMENT_DETAILS
			WHERE Name = 'Machine Name'
		END
	END

	IF ISNULL(@MachineName,'') = ''
	BEGIN
		IF OBJECT_ID('cust_MSInfo') IS NOT NULL
		BEGIN
			SELECT @MachineName = LTRIM(RTRIM(REPLACE([InfoDesc], 'System Name:', '')))
			FROM [dbo].[cust_MSInfo]
			WHERE InfoDesc LIKE 'System Name:%'
		END
	END

	RETURN(@MachineName)
END
GO

IF OBJECT_ID('GetLogReuse') IS NOT NULL
DROP PROCEDURE GetLogReuse
GO
CREATE PROCEDURE GetLogReuse
AS
BEGIN
	DECLARE @ServerType VARCHAR(40) = dbo.udf_GetServerType()
	
	IF OBJECT_ID('cust_Databases') IS NOT NULL AND @ServerType = 'OnPremisesSQL'
	BEGIN
		SELECT name, log_reuse_wait_desc
		FROM cust_Databases
		WHERE log_reuse_wait_desc <> 'NOTHING'
	END
END
GO



IF OBJECT_ID('GetErrorLogErrors') IS NOT NULL
DROP PROCEDURE GetErrorLogErrors
GO
CREATE PROCEDURE GetErrorLogErrors
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	IF OBJECT_ID('cust_ErrorLogAnalysis') IS NOT NULL
	BEGIN
	
		SELECT
			ErrorNumber,
			First_Logged_Date,
			Last_Logged_Date,
			Error_Count,
			ErrorMessage = Logged_Message + CASE WHEN ErrorNumber IS NULL THEN '' ELSE ' ' +
				(
				SELECT text
			FROM sys.messages m
			WHERE language_id = 1033 AND
				m.message_id = x.ErrorNumber AND
				x.ErrorNumber IS NOT NULL
				) END
		FROM
			(
				SELECT
				Logged_Message,
				First_Logged_Date,
				Last_Logged_Date,
				Error_Count,
				ErrorNumber = 
					CASE 
					WHEN Logged_Message LIKE '% Error: %, Severity: %, State: %.' 
						THEN SUBSTRING(Logged_Message, CHARINDEX('Error: ' , Logged_Message) + 7, (CHARINDEX(',' , Logged_Message)-CHARINDEX('Error: ' , Logged_Message)-7))
					ELSE NULL 
					END
			FROM [dbo].cust_ErrorLogAnalysis
			WHERE 
				(
					Logged_Message LIKE '%error%' OR
				Logged_Message LIKE '%fail%' OR
				Logged_Message LIKE '%paged%' OR
				Logged_Message LIKE '%timeout%' OR
				Logged_Message LIKE '%insufficient%' OR
				Logged_Message LIKE '%invalid%' OR
				Logged_Message LIKE '%unable%' OR
				Logged_Message LIKE '%overflow%' OR
				Logged_Message LIKE '%corrupt%'
				) AND
				(
					Logged_Message NOT LIKE '%0 errors%' AND
				Logged_Message NOT LIKE '%without errors%'AND
				Logged_Message NOT LIKE '%clientoption2%' AND
				Logged_Message NOT LIKE '%Login failed for%' AND
				Logged_Message NOT LIKE '%Backup Database backed up. Database: [%Error%]%' AND
				Logged_Message NOT LIKE '%Starting up database ''%Error%''%' AND
				Logged_Message NOT LIKE '%This is an informational message only%No user action is required.%' AND
				Logged_Message NOT LIKE '%Server Logging SQL Server messages in file%' AND
				Logged_Message NOT LIKE '%Logging SQL Server messages in file %' AND
				Logged_Message NOT LIKE '%The error log has been reinitialized%' AND
				Logged_Message NOT LIKE '%See the previous log for older entries%'  AND
				Logged_Message NOT LIKE '%Attempting to cycle error log%' AND
				Logged_Message NOT LIKE 'spid% Error: %, Severity: %, State: __' AND
				Logged_Message NOT LIKE 'spid% Error: %, Severity: %, State: _' AND
				Logged_Message NOT LIKE 'Backup Error: %, Severity: %, State: _'AND
				Logged_Message NOT LIKE 'Logon Error: %, Severity: %, State: __' AND
				Logged_Message NOT LIKE 'Logon Error: %, Severity: %, State: _' AND
				Logged_Message NOT LIKE 'Server Error: %, Severity: %, State: __' AND
				Logged_Message NOT LIKE 'Server Error: %, Severity: %, State: _' 

				)
			)x
		ORDER BY Last_Logged_Date DESC
	END
END
GO

/*
IF OBJECT_ID('GetQueryStoreQueries') IS NOT NULL
DROP PROCEDURE GetQueryStoreQueries
GO
CREATE PROCEDURE GetQueryStoreQueries
AS
BEGIN

	IF 
	OBJECT_ID('tbl_query_store_runtime_stats') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_plan') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_query') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_query_text') IS NOT NULL 
	BEGIN

		SELECT DISTINCT TOP(1000)
			q.dbname,
			first_execution_time, q.last_execution_time,
			avg_durationSec = CAST(avg_duration AS FLOAT)/1000000.00,
			min_durationSec = CAST(min_duration AS FLOAT)/1000000.00,
			max_durationSec = CAST(max_duration AS FLOAT)/1000000.00,
			avg_logical_io_reads = cast(avg_logical_io_reads AS FLOAT), min_logical_io_reads, max_logical_io_reads,
			min_dop, max_dop,
			min_rowcount, max_rowcount,
			query_parameterization_type_desc,
			execution_type_desc,
			count_executions,
			query_hash,
			query_plan_hash,
			--min_tempdb_space_used,
			--max_tempdb_space_used,
			query_sql_text
		from
			tbl_query_store_runtime_stats q
			join tbl_query_store_plan p on q.dbid = p.dbid and q.plan_id = p.plan_id
			join tbl_query_store_query qq on p.dbid = qq.dbid and p.query_id = qq.query_id
			join tbl_query_store_query_text qt on qt.dbid = qq.dbid and qt.query_text_id = qq.query_text_id
		order by cast(avg_logical_io_reads as float) desc
	END

END
GO
*/



IF OBJECT_ID('GetBlockedProcessOverview') IS NOT NULL
DROP PROCEDURE GetBlockedProcessOverview
GO
CREATE PROCEDURE GetBlockedProcessOverview
AS
BEGIN
	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF 
		OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN
					SELECT
				CounterName,
				CounterAvg = AVG(CounterValue),
				CounterMin = MIN(CounterValue),
				CounterMax = MAX(CounterValue)
			--INTO #Temp
			FROM dbo.Counterdata c
				JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
			WHERE 
			CounterName = 'Processes blocked'
				AND MachineName = @MachineName
			GROUP BY CounterName
		UNION ALL

			SELECT
				CounterName = 'Lock waits (ms)',
				CounterAvg = AVG(CounterValue),
				CounterMin = MIN(CounterValue),
				CounterMax = MAX(CounterValue)
			FROM dbo.Counterdata c
				JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
			WHERE ObjectName LIKE '%Wait Statistics' AND
				InstanceName = 'Average wait time (ms)' AND
				CounterName = 'Lock waits'
				AND MachineName = @MachineName
			GROUP BY CounterName


	END
END
GO


IF OBJECT_ID('GetPossibleParamSniffing') IS NOT NULL
DROP PROCEDURE GetPossibleParamSniffing
GO
CREATE PROCEDURE GetPossibleParamSniffing
AS
BEGIN

	IF 
	OBJECT_ID('tbl_query_store_runtime_stats') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_plan') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_query') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_query_text') IS NOT NULL 
	BEGIN
	SELECT * 
	INTO #Sniffing
	FROM (
		SELECT DISTINCT TOP(1000)
			q.dbname,
			first_execution_time, q.last_execution_time,
			avg_durationSec = CAST(avg_duration AS FLOAT)/1000000.00,
			min_durationSec = CAST(min_duration AS FLOAT)/1000000.00,
			max_durationSec = CAST(max_duration AS FLOAT)/1000000.00,
			avg_logical_io_reads = CAST(avg_logical_io_reads AS FLOAT), min_logical_io_reads, max_logical_io_reads,
			min_dop, max_dop,
			min_rowcount, max_rowcount,
			query_parameterization_type_desc,
			execution_type_desc,
			count_executions,
			query_hash,
			query_plan_hash,
			query_sql_text

		FROM
			tbl_query_store_runtime_stats q
			join tbl_query_store_plan p on q.dbid = p.dbid and q.plan_id = p.plan_id
			join tbl_query_store_query qq on p.dbid = qq.dbid and p.query_id = qq.query_id
			join tbl_query_store_query_text qt on qt.dbid = qq.dbid and qt.query_text_id = qq.query_text_id
		WHERE 
			query_sql_text like '%@%' AND
			CAST(max_logical_io_reads AS FLOAT) > 100000 AND
			((CAST(max_logical_io_reads AS FLOAT) - CAST(min_logical_io_reads AS FLOAT) )/CAST(max_logical_io_reads AS FLOAT)) *100.00 > 50
		) a

		ORDER BY 
			avg_logical_io_reads  DESC

		SELECT *
		FROM #Sniffing
		ORDER BY 
			avg_logical_io_reads  DESC
	END

END
GO

IF OBJECT_ID('report_SystemSummary') IS NOT NULL
DROP PROCEDURE report_SystemSummary
GO
CREATE PROCEDURE report_SystemSummary
AS
BEGIN
	IF OBJECT_ID('tempdb..#SettingReport') IS NOT NULL
	BEGIN
		DROP TABLE #SettingReport
	END

	create table #SettingReport(Setting varchar(1000), SettingValue varchar(2000))

	insert into #SettingReport
	exec [GetSystemInformation]


	select * from #SettingReport
	WHERE LTRIM(RTRIM(SettingValue)) > '' AND
	Setting NOT IN(
	'BuildClrVersion',
	'IsLocalDB',
	'IsFullTextInstalled',
	'VISIBLEONLINE_SCHEDULER_COUNT',
	'UTCOffset_in_Hours',
	'max_workers_count',
	'hyperthread_ratio',
	'scheduler_total_count',
	'MajorVersion',
	'cpu_ticks_per_sec',
	'operating system version build',
	'operating system install date',
	'operating system version major',
	'operating system version minor',
	'registry ActivePowerScheme',
	'resource governor enabled',
	'ResourceVersion',
	'FilestreamConfiguredLevel',
	'FilestreamEffectiveLevel',
	'suser_name()',
	'machine start time',
	'sqlserver_start_time',
	'number of active extended event traces',
	'number of active profiler traces',
	'number of tempdb data files',
	'SystemManufacturer',
	'possibly running in virtual machine',
	'ProductVersion',
	'scheduler_count',
	'SchedulerCount',
	'FilestreamShareName',
	'SQLServerName',
	'ServerName',
	'MachineName',
	'IsIntegratedSecurityOnly',
	'IsXTPSupported',
	'registry SystemProductName'
	)
END
GO
IF OBJECT_ID('GetPerProcessorUsage') IS NOT NULL
DROP PROCEDURE GetPerProcessorUsage
GO

CREATE PROCEDURE GetPerProcessorUsage
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	DECLARE @MachineName VARCHAR(1024)

	SELECT @MachineName = dbo.udf_GetMachineName()
	SET @MachineName = '\\' + @MachineName

	IF OBJECT_ID('dbo.CounterData') IS NOT NULL AND
		OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
	BEGIN

		SELECT
			CounterName, InstanceName,
			AverageCPU = cast(AVG(cast(countervalue as decimal(18,3)))as decimal(18,3)),
			MaxCPU = MAX(CAST(countervalue as decimal(18,3))), 
			CPUStDev = STDEV(CAST(countervalue as decimal(18,3)))
		FROM dbo.CounterData d
			JOIN dbo.CounterDetails dd ON d.CounterID = dd.CounterID
		WHERE 
			dd.ObjectName IN('Processor Information') AND
			CounterName LIKE '[%] Processor Time' AND
			MachineName = @MachineName
		GROUP BY CounterName, InstanceName
	END
END
GO


IF OBJECT_ID('GetNotableActiveQueries') IS NOT NULL
DROP PROCEDURE GetNotableActiveQueries
GO

CREATE PROCEDURE GetNotableActiveQueries
AS
BEGIN
	IF OBJECT_ID('dbo.cust_NotableActiveQueries') IS NOT NULL
	BEGIN
		SELECT 
		AvgLogicalReads = CAST(plan_total_logical_reads as bigint)/cast(plan_total_exec_count as bigint),*

		FROM [dbo].[cust_Requests] r
		JOIN [dbo].[cust_NotableActiveQueries] q ON r.runtime = q.runtime AND r.session_id = q.session_id
		WHERE plan_total_exec_count <> 'NULL'
		ORDER BY AvgLogicalReads DESC
	END
END  
GO
IF OBJECT_ID('GetDBWaitsForCapture') IS NOT NULL
DROP PROCEDURE GetDBWaitsForCapture
GO
CREATE PROCEDURE [dbo].[GetDBWaitsForCapture]
AS
BEGIN
	DECLARE @Tab VARCHAR(50)
	SET @Tab = SUBSTRING(OBJECT_NAME(@@PROCID), 4, 100)

	SET NOCOUNT ON
	IF OBJECT_ID('dbo.cust_DatabaseWaits') IS NOT NULL
	BEGIN
		--waits
		IF OBJECT_ID('tempdb..#WaitsForCapture') IS NOT NULL
		DROP TABLE #WaitsForCapture

		IF OBJECT_ID('tempdb..#TempWaiting') IS NOT NULL
		DROP TABLE #TempWaiting

		IF OBJECT_ID('tempdb..#WaitsForCapture') IS NOT NULL
		DROP TABLE #WaitsForCapture

		SELECT
			mx.wait_type,
			waiting_tasks_count = CAST(mx.waiting_tasks_count AS BIGINT)- CAST(mn.waiting_tasks_count AS BIGINT),
			wait_time_ms = CAST(mx.wait_time_ms AS BIGINT)- CAST(mn.wait_time_ms AS BIGINT),
			signal_wait_time_ms = CAST(mx.signal_wait_time_ms AS BIGINT) - CAST(mn.signal_wait_time_ms AS BIGINT)
		INTO #WaitsForCapture
		FROM
			(
			select *
			from [dbo].cust_DatabaseWaits
			where runtime = (select min(runtime)
			from [dbo].cust_DatabaseWaits)
		) mn
			join
			(
			select *
			from [dbo].cust_DatabaseWaits
			where runtime = (select max(runtime)
			from [dbo].cust_DatabaseWaits)
		) mx on mn.wait_type = mx.wait_type

		;WITH
			[Waits]
			AS
			(
				SELECT
					[wait_type],
					[wait_time_ms] / 1000.0 AS [WaitS],
					([wait_time_ms] - [signal_wait_time_ms]) / 1000.0 AS [ResourceS],
					[signal_wait_time_ms] / 1000.0 AS [SignalS],
					[waiting_tasks_count] AS [WaitCount],
					100.0 * [wait_time_ms] / SUM ([wait_time_ms]) OVER() AS [Percentage],
					ROW_NUMBER() OVER(ORDER BY [wait_time_ms] DESC) AS [RowNum]
				FROM #WaitsForCapture
				WHERE [wait_type] NOT IN (
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
				N'XE_DISPATCHER_WAIT',              N'XE_TIMER_EVENT', 
				'PREEMPTIVE_OS_WRITEFILE', 'PREEMPTIVE_XE_DISPATCHER', 'QDS_ASYNC_QUEUE')
					AND [waiting_tasks_count] > 0
			)
		SELECT
			MAX ([W1].[wait_type]) AS [WaitType],
			CAST (MAX ([W1].[WaitS]) AS DECIMAL (16,2)) AS [Wait_S],
			CAST (MAX ([W1].[ResourceS]) AS DECIMAL (16,2)) AS [Resource_S],
			CAST (MAX ([W1].[SignalS]) AS DECIMAL (16,2)) AS [Signal_S],
			MAX ([W1].[WaitCount]) AS [WaitCount],
			CAST (MAX ([W1].[Percentage]) AS DECIMAL (5,2)) AS [Percentage],
			CAST ((MAX ([W1].[WaitS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgWait_S],
			CAST ((MAX ([W1].[ResourceS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgRes_S],
			CAST ((MAX ([W1].[SignalS]) / MAX ([W1].[WaitCount])) AS DECIMAL (16,4)) AS [AvgSig_S]
		INTO #TempWaiting
		FROM [Waits] AS [W1]
			INNER JOIN [Waits] AS [W2]
			ON [W2].[RowNum] <= [W1].[RowNum]
		GROUP BY [W1].[RowNum]
		HAVING SUM ([W2].[Percentage]) - MAX ([W1].[Percentage]) < 95;
		-- percentage threshold

		SELECT
			WaitType, WaitCount, Percentage, AvgWaitTimeSec = AvgWait_S
		--RowFlag = CASE WHEN CAST(Percentage AS DECIMAL) > 40 THEN 'R' ELSE 'N' END
		FROM #TempWaiting


	--END
	END
END
GO
IF OBJECT_ID('GetManagedInstanceResourceStats') IS NOT NULL
DROP PROCEDURE GetManagedInstanceResourceStats
GO
CREATE PROCEDURE GetManagedInstanceResourceStats
AS
BEGIN
	IF OBJECT_ID('cust_serverresourcestats') IS NOT NULL
	BEGIN
	SELECT 
		[start_time]
		,[end_time]
		--,[resource_type]
		--,[resource_name]
		--,[sku]
		--,[hardware_generation]
		--,[virtual_core_count]
		,cpu = cast([avg_cpu_percent] as decimal(18,2))
		,cast([reserved_storage_mb] as decimal(18,2))/1024.0 as ReservedStorageGB
		,cast([storage_space_used_mb] as decimal(18,2))/1024.0 as StorageUsedGB
		,[io_requests]
		,[io_bytes_read]
		,[io_bytes_written]

	FROM [dbo].[cust_serverresourcestats]
	WHERE DATEADD(DAY, -3, GETDATE()) < start_time
	ORDER BY start_time asc
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetDBConnectionStatistics') IS NOT NULL
DROP PROCEDURE GetDBConnectionStatistics
GO
CREATE PROCEDURE GetDBConnectionStatistics
AS
BEGIN

	IF OBJECT_ID('dbo.cust_dbconnectionstats') IS NOT NULL
	BEGIN
		SELECT TOP 1000 *
		FROM dbo.cust_dbconnectionstats
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetSQLDBBufferPool') IS NOT NULL
DROP PROCEDURE GetSQLDBBufferPool
GO
CREATE PROCEDURE GetSQLDBBufferPool
AS
BEGIN

	IF OBJECT_ID('dbo.cust_azurebufferpool') IS NOT NULL
	BEGIN
		SELECT *
		FROM dbo.cust_azurebufferpool
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetSQLDBElasticPoolInfo') IS NOT NULL
DROP PROCEDURE GetSQLDBElasticPoolInfo
GO
CREATE PROCEDURE GetSQLDBElasticPoolInfo
AS
BEGIN

	IF OBJECT_ID('dbo.cust_azureelasticpools') IS NOT NULL
	BEGIN
		SELECT TOP 1000 *
		FROM dbo.cust_azureelasticpools
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetSQLDBEventLog') IS NOT NULL
DROP PROCEDURE GetSQLDBEventLog
GO
CREATE PROCEDURE GetSQLDBEventLog
AS
BEGIN

	IF OBJECT_ID('dbo.cust_AzureEventLog') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_AzureEventLog]
		WHERE event_type <> 'connection_successful'
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetSQLDBFirewallRules') IS NOT NULL
DROP PROCEDURE GetSQLDBFirewallRules
GO
CREATE PROCEDURE GetSQLDBFirewallRules
AS
BEGIN

	IF OBJECT_ID('dbo.cust_azurefilewallrules') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_azurefilewallrules]
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetGeoReplication') IS NOT NULL
DROP PROCEDURE GetGeoReplication
GO
CREATE PROCEDURE GetGeoReplication
AS
BEGIN

	IF OBJECT_ID('dbo.cust_AzureGeoRepl') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_AzureGeoRepl]
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetPLE') IS NOT NULL
DROP PROCEDURE GetPLE
GO
CREATE PROCEDURE GetPLE
AS
BEGIN

	IF OBJECT_ID('dbo.cust_AzurePLE') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_AzurePLE]
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetAzureServerInfo') IS NOT NULL
DROP PROCEDURE GetAzureServerInfo
GO
CREATE PROCEDURE GetAzureServerInfo
AS
BEGIN

	IF OBJECT_ID('dbo.cust_AzureServerInfo') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_azureserverinfo]
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetAzureServerProperties') IS NOT NULL
DROP PROCEDURE GetAzureServerProperties
GO
CREATE PROCEDURE GetAzureServerProperties
AS
BEGIN

	IF OBJECT_ID('dbo.cust_azureserverproperties') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_azureserverproperties]
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetDBFirewallRules') IS NOT NULL
DROP PROCEDURE GetDBFirewallRules
GO
CREATE PROCEDURE GetDBFirewallRules
AS
BEGIN

	IF OBJECT_ID('dbo.cust_dbfirewallrules') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_dbfirewallrules]
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetDBScopedConfiguration') IS NOT NULL
DROP PROCEDURE GetDBScopedConfiguration
GO
CREATE PROCEDURE GetDBScopedConfiguration
AS
BEGIN

	IF OBJECT_ID('dbo.cust_dbscopedconfiguration') IS NOT NULL
	BEGIN

			SELECT *
			FROM [dbo].[cust_dbscopedconfiguration]
			--WHERE DBName NOT IN('master','msdb','model','tempdb')
			--ORDER BY DBName, configuration_id

	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetDBServiceLevelAgreement') IS NOT NULL
DROP PROCEDURE GetDBServiceLevelAgreement
GO
CREATE PROCEDURE GetDBServiceLevelAgreement
AS
BEGIN

	IF OBJECT_ID('dbo.cust_general_DBSLAs') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_general_DBSLAs]
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetLocking') IS NOT NULL
DROP PROCEDURE GetLocking
GO
CREATE PROCEDURE GetLocking
AS
BEGIN

	IF OBJECT_ID('dbo.cust_Locking') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_Locking]
	END
END
GO
----------------------------------------------------------------------------------------------
IF OBJECT_ID('GetQueryStoreOptions') IS NOT NULL
DROP PROCEDURE GetQueryStoreOptions
GO
CREATE PROCEDURE GetQueryStoreOptions
AS
BEGIN

	IF OBJECT_ID('dbo.cust_QueryStoreOptions') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_QueryStoreOptions]
		WHERE DBName NOT IN('master','msdb','tempdb','model')
	END
END
GO
IF OBJECT_ID('GetResourceStats') IS NOT NULL
DROP PROCEDURE GetResourceStats
GO
CREATE PROCEDURE GetResourceStats
AS
BEGIN

	IF OBJECT_ID('dbo.cust_ResoureStats') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_ResoureStats]
	END
END
GO

IF OBJECT_ID('GetDBResourceStats') IS NOT NULL
DROP PROCEDURE GetDBResourceStats
GO
CREATE PROCEDURE GetDBResourceStats
AS
BEGIN

	IF OBJECT_ID('dbo.cust_DBResourceStats') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_DBResourceStats]
		WHERE DBName NOT IN('tempdb','master','msdb','model')
		ORDER BY DBName, end_time 
	END
END
GO



IF OBJECT_ID('GetQueryWaits') IS NOT NULL
DROP PROCEDURE GetQueryWaits
GO
CREATE PROCEDURE GetQueryWaits
AS
BEGIN
	IF 
		OBJECT_ID('tbl_query_store_runtime_stats') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_plan') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_query') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_query_text') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_wait_stats') IS NOT NULL AND
		OBJECT_ID('tbl_query_store_runtime_stats_interval') IS NOT NULL
	BEGIN

		SELECT TOP(5000)
			i.runtime_stats_interval_id, 
			ws.wait_category_desc, 
			rs.[dbname], 
			100.0 *  cast(total_query_wait_time_ms as bigint) / sum(cast(total_query_wait_time_ms as bigint)) OVER(partition by rs.runtime_stats_interval_id, rs.plan_id) AS [WaitsByPlanPercentage],
			100.0 *  cast(total_query_wait_time_ms as bigint) / sum(cast(total_query_wait_time_ms as bigint)) OVER(partition by rs.runtime_stats_interval_id) AS [WaitsByRuntimePercentage], 
			rs.runtime_stats_id,
			q.query_id,
			p.plan_id,
			i.start_time,
			i.end_time,
			qt.query_sql_text,
			total_query_wait_time_ms, 
			min_query_wait_time_ms,
			stdev_query_wait_time_ms, 
			max_query_wait_time_ms,
			rs.[execution_type], 
			rs.[execution_type_desc], 
			rs.[first_execution_time], 
			rs.[last_execution_time], 
			rs.[count_executions], 
			rs.[avg_duration], 
			rs.[last_duration], 
			rs.[min_duration], 
			rs.[max_duration], 
			rs.[stdev_duration], 
			rs.[avg_cpu_time], 
			rs.[last_cpu_time], 
			rs.[min_cpu_time], 
			rs.[max_cpu_time], 
			rs.[stdev_cpu_time], 
			rs.[avg_logical_io_reads], 
			rs.[last_logical_io_reads], 
			rs.[min_logical_io_reads], 
			rs.[max_logical_io_reads], 
			rs.[stdev_logical_io_reads], 
			rs.[avg_logical_io_writes], 
			rs.[last_logical_io_writes], 
			rs.[min_logical_io_writes], 
			rs.[max_logical_io_writes], 
			rs.[stdev_logical_io_writes], 
			rs.[avg_physical_io_reads], 
			rs.[last_physical_io_reads], 
			rs.[min_physical_io_reads], 
			rs.[max_physical_io_reads], 
			rs.[stdev_physical_io_reads], 
			rs.[avg_clr_time], 
			rs.[last_clr_time], 
			rs.[min_clr_time], 
			rs.[max_clr_time], 
			rs.[stdev_clr_time], 
			rs.[avg_dop], 
			rs.[last_dop], 
			rs.[min_dop], 
			rs.[max_dop], 
			rs.[stdev_dop], 
			rs.[avg_query_max_used_memory], 
			rs.[last_query_max_used_memory], 
			rs.[min_query_max_used_memory], 
			rs.[max_query_max_used_memory], 
			rs.[stdev_query_max_used_memory], 
			rs.[avg_rowcount], 
			rs.[last_rowcount], 
			rs.[min_rowcount], 
			rs.[max_rowcount], 
			rs.[stdev_rowcount], 
			rs.[avg_num_physical_io_reads], 
			rs.[last_num_physical_io_reads], 
			rs.[min_num_physical_io_reads], 
			rs.[max_num_physical_io_reads], 
			rs.[stdev_num_physical_io_reads], 
			rs.[avg_log_bytes_used], 
			rs.[last_log_bytes_used], 
			rs.[min_log_bytes_used], 
			rs.[max_log_bytes_used], 
			rs.[stdev_log_bytes_used], 
			rs.[avg_tempdb_space_used], 
			rs.[last_tempdb_space_used], 
			rs.[min_tempdb_space_used], 
			rs.[max_tempdb_space_used], 
			rs.[stdev_tempdb_space_used], 
			rs.[avg_page_server_io_reads], 
			rs.[last_page_server_io_reads], 
			rs.[min_page_server_io_reads], 
			rs.[max_page_server_io_reads], 
			rs.[stdev_page_server_io_reads]
		FROM tbl_query_store_wait_stats ws
		JOIN tbl_query_store_runtime_stats_interval i ON ws.runtime_stats_interval_id = i.runtime_stats_interval_id
		JOIN tbl_query_store_runtime_stats rs ON i.runtime_stats_interval_id = rs.runtime_stats_interval_id 
		and ws.plan_id = rs.plan_id
		JOIN tbl_query_store_plan p ON ws.plan_id = p.plan_id
		JOIN tbl_query_store_query q ON p.query_id = q.query_id
		JOIN tbl_query_store_query_text qt ON q.query_text_id = qt.query_text_id
		--ORDER BY i.start_time asc, [WaitsByRuntimePercentage] desc
		ORDER BY avg_logical_io_reads DESC
	END
END
GO
IF OBJECT_ID('GetAutoTuningConfiguration') IS NOT NULL
DROP PROCEDURE GetAutoTuningConfiguration
GO
CREATE PROCEDURE GetAutoTuningConfiguration
AS
BEGIN

	IF OBJECT_ID('dbo.cust_AutoTuningConfig') IS NOT NULL
	BEGIN
		SELECT *
		FROM [dbo].[cust_AutoTuningConfig]
		WHERE DBName NOT IN('tempdb','master','msdb','model')
		ORDER BY DBName, name
	END
END
GO

IF OBJECT_ID('GetBlockingData') IS NOT NULL
DROP PROCEDURE GetBlockingData
GO

CREATE PROCEDURE GetBlockingData
AS
BEGIN
	DECLARE @ServerType VARCHAR(40) = dbo.udf_GetServerType()



	IF OBJECT_ID('dbo.tbl_requests') IS NOT NULL AND
		@ServerType <> 'OnPremisesSQL'
	BEGIN

		UPDATE tbl_requests 
		SET blocking_session_id = NULL
		WHERE blocking_session_id = 'NULL'

		;WITH blocker
		AS
		(

		SELECT a.runtime, a.session_id, a.blocking_session_id, task_state, wait_type, resource_description, blockingresource = CAST('' AS VARCHAR(4000)),
		stmt_text, blockingstmt = CAST('' AS VARCHAR(4000)),
		0 as lvl
		FROM
		(
			SELECT
			rownos = ROW_NUMBER() OVER(PARTITION BY r.session_id ORDER BY r.session_id ASC),
			r.runtime,
			r.session_id, r.blocking_session_id, task_state, wait_type, resource_description, stmt_text
			FROM tbl_requests r
			WHERE 
			blocking_session_id = 0
			AND EXISTS
			(
				SELECT *
				FROM tbl_requests ri
				WHERE ri.blocking_session_id = r.session_id
			)
		) a
		WHERE rownos = 1

		UNION ALL
		SELECT
		x.runtime, x.session_id, x.blocking_session_id, x.task_state, x.wait_type, x.resource_description, blockingresource = CAST( b.resource_description AS VARCHAR(4000)), x.stmt_text, blockingstmt = CAST(b.stmt_text AS VARCHAR(4000)),
		lvl + 1
		FROM blocker b
		JOIN
		(
			SELECT
			rownos = ROW_NUMBER() OVER(PARTITION BY r.session_id ORDER BY r.session_id ASC),
			r.runtime,
			r.session_id, r.blocking_session_id, task_state, wait_type, resource_description, stmt_text
			FROM tbl_requests r
			WHERE 
			blocking_session_id != 0
		) x ON b.session_id = x.blocking_session_id 
		)
		SELECT *
		FROM blocker
		ORDER BY lvl, session_id
		option(maxrecursion
		3000)
	END

END
GO


IF OBJECT_ID('GetUDFExecutionData') IS NOT NULL
DROP PROCEDURE GetUDFExecutionData
GO
CREATE PROCEDURE GetUDFExecutionData
AS
BEGIN
	IF OBJECT_ID('cust_UDFExecution') IS NOT NULL
	BEGIN
	
		SELECT *
		FROM [dbo].[cust_UDFExecution]
		--WHERE 
		--	DBName <> 'NULL'
		ORDER BY CAST(execution_count AS BIGINT) DESC
	END

END
GO

IF OBJECT_ID('GetFailedVARules') IS NOT NULL
DROP PROCEDURE GetFailedVARules
GO
CREATE PROCEDURE GetFailedVARules
AS
BEGIN
	IF OBJECT_ID('cust_VAResults') IS NOT NULL
	BEGIN
	
		SELECT DatabaseName, Platform, Category, Title, Description, Rationale, Severity
		FROM [dbo].cust_VAResults
		WHERE
		Status = 'Failed'
	END

END
GO
IF OBJECT_ID('GetFailedVARules') IS NOT NULL
DROP PROCEDURE GetFailedVARules
GO
CREATE PROCEDURE GetFailedVARules
AS
BEGIN
	IF OBJECT_ID('cust_VAResults') IS NOT NULL
	BEGIN
	
		SELECT DatabaseName, Platform, Category, Title, Description, Rationale, Severity
		FROM [dbo].cust_VAResults
		WHERE
		Status = 'Failed'
	END

END
GO
IF OBJECT_ID('GetSensitiveDataColumns') IS NOT NULL
DROP PROCEDURE GetSensitiveDataColumns
GO
CREATE PROCEDURE GetSensitiveDataColumns
AS
BEGIN
	IF OBJECT_ID('cust_SensitivityRecommendations') IS NOT NULL
	BEGIN
	
		SELECT *
		FROM [dbo].cust_SensitivityRecommendations
	END

END
GO