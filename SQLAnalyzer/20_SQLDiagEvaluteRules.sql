--
--Author Carlos Reyes (careyes)
--Evaluate rules from data collected to fire issues
--

--TC  Moved this table creation to be in 
--Use it to evaluate rules in that script also.

--IF OBJECT_ID('PTOClinicFindings') IS NOT NULL
--DROP TABLE PTOClinicFindings
--GO
--CREATE TABLE dbo.PTOClinicFindings (
--     [Title] nvarchar(512), 
--     [Category] nvarchar(64), 
--     [Severity] nvarchar(32), 
--     [Impact] nvarchar(MAX), 
--     [Recommendation] nvarchar(MAX), 
--     [Reading] nvarchar(MAX),
--	SummaryCategory
--)
--truncate table PTOClinicFindings
--GO



IF OBJECT_ID('GetPTOClinicFindings') IS NOT NULL
DROP PROCEDURE GetPTOClinicFindings
GO
CREATE PROCEDURE GetPTOClinicFindings
	(
	@PrintRules BIT = 0
)
AS
BEGIN
	SET NOCOUNT ON
	--DELETE FROM PTOClinicFindings

	DECLARE @ServerType VARCHAR(40) = dbo.udf_GetServerType()

	DECLARE @executiondatetime datetime
	IF 	OBJECT_ID('dbo.tbl_FileStats') IS NOT NULL
    SELECT @executiondatetime= MIN(runtime)
	FROM tbl_FileStats
  ELSE 
    SET @executiondatetime=GETDATE()


	IF OBJECT_ID('cust_Index_Duplicate_Indexes') IS NOT NULL
     INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Tables and indexed views have been identified that have duplicate indexes.', 'Database Design', 'Critical', NULL, NULL, NULL)

	IF OBJECT_ID('cust_Index_Duplicate_Indexes_HardCoded') IS NOT NULL
     INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Tables and indexed views have been identified that have duplicate indexes.', 'Database Design', 'Critical', NULL, NULL, NULL)

	IF OBJECT_ID('cust_Index_Redundant_Indexes') IS NOT NULL
     INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Tables and/or indexed views have been identified that have redundant indexes.', 'Database Design', 'Critical', NULL, NULL, NULL)

	IF OBJECT_ID('cust_Index_Unused_Indexes') IS NOT NULL
     INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Tables have been identified that may have indexes that are never used.', 'Database Design', 'High', NULL, NULL, NULL)

	IF OBJECT_ID('cust_Index_Large_Index_Key') IS NOT NULL
     INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Indexes have been identified that are larger than the recommended size (900 bytes).', 'Database Design', 'Medium', NULL, NULL, NULL)

	IF OBJECT_ID('cust_Index_NonUnique_CIXs') IS NOT NULL
     INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Databases identified with one or more tables, with non-unique clustered indexes.', 'Database Design', 'Medium', NULL, NULL, NULL)

	IF OBJECT_ID('cust_Index_Index_Key_GUID') IS NOT NULL
     INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Databases identified with one or more tables, with clustered indexes that may use a GUID as key.', 'Database Design', 'High', NULL, NULL, NULL)

	IF OBJECT_ID('cust_Index_FK_no_Index') IS NOT NULL
     INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Databases identified with one or more tables, with Foreign Keys that are not indexed.', 'Database Design', 'Critical', NULL, NULL, NULL)

	IF OBJECT_ID('cust_Index_Tables_with_no_Indexes') IS NOT NULL
     INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Tables have been identified that have no indexes.', 'Database Design', 'Critical', NULL, NULL, NULL)
	/*
	IF OBJECT_ID('cust_IndexDetail') IS NOT NULL AND
	OBJECT_ID('cust_CompressionDetails') IS NOT NULL
	BEGIN

	IF EXISTS
	(
	SELECT 
	i.DBName, i.TableName, IndexStatus = 'No clustered index'
	FROM 
	[dbo].[cust_IndexDetail] i
	JOIN cust_CompressionDetails d ON i.DBName = d.DBName AND i.TableName = d.TableName
	WHERE 
	i.TableName NOT LIKE 'sys%' AND
	i.TableName NOT LIKE 'ServiceBroker%' AND
	IndexType = 'HEAP' AND
	CAST(d.RowCnt AS BIGINT) > 10000
	UNION ALL
	--tables w/o a NC index
	SELECT 
	o.DBName, o.TableName, IndexStatus = 'No non-clustered indexes'
	FROM 
	[dbo].[cust_IndexDetail] o
	JOIN cust_CompressionDetails d ON o.DBName = d.DBName AND o.TableName = d.TableName
	WHERE 
	IndexType NOT IN('NONCLUSTERED') AND
	IndexType NOT LIKE '%COLUMNSTORE%' AND
	o.TableName NOT LIKE 'sys%' AND
	o.TableName NOT LIKE 'ServiceBroker%' AND
	CAST(d.RowCnt AS BIGINT) > 10000
	AND NOT EXISTS
	(
	SELECT *
	FROM [dbo].[cust_IndexDetail] i
	WHERE IndexType = 'NONCLUSTERED' AND
	i.DBName = o.DBName AND
	i.TableName = o.TableName
	)
	)
	BEGIN
	INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Tables have been identified that are missing critical indexes.','Database Design','High',NULL,NULL,NULL)	
	END



	END
*/
	IF OBJECT_ID('cust_Index_Tables_with_no_CL_Index') IS NOT NULL
     INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Tables have been identified that do not have a clustered index, and have one or more non-clustered indexes.', 'Database Design', 'Critical', NULL, NULL, NULL)

	IF OBJECT_ID('cust_Index_Tables_with_more_Indexes_than_Cols') IS NOT NULL
     INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Tables have been identified that have more indexes than columns.', 'Database Design', 'Critical', NULL, NULL, NULL)

	IF OBJECT_ID('cust_Index_Tables_with_partition_misaligned_Indexes') IS NOT NULL
     INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	VALUES('Partitioned indexes are not aligned with partitioned tables.', 'Database Design', 'High', NULL, NULL, NULL)

	DECLARE @Tbl_ver_complevel  TABLE
  (sqlver int,
		sqlcomptlevel int
  )
	INSERT INTO @Tbl_ver_complevel
	VALUES(9, 90)
	INSERT INTO @Tbl_ver_complevel
	VALUES(10, 100)
	INSERT INTO @Tbl_ver_complevel
	VALUES(11, 110)
	INSERT INTO @Tbl_ver_complevel
	VALUES(12, 120)
	INSERT INTO @Tbl_ver_complevel
	VALUES(13, 130)
	INSERT INTO @Tbl_ver_complevel
	VALUES(14, 140)
	INSERT INTO @Tbl_ver_complevel
	VALUES(15, 150)

	
	DECLARE @MajorVersion INT
	IF OBJECT_ID('tbl_SCRIPT_ENVIRONMENT_DETAILS') IS NOT NULL
	BEGIN
		--SELECT TOP 1 CONVERT (int, substring(InfoDesc.value(N'(/NewDataSet/SQLServer/Version)[1]',N'nvarchar(50)'),1,  charindex('.',REVERSE(InfoDesc.value(N'(/NewDataSet/SQLServer/Version)[1]',N'nvarchar(50)'))))) FROM [cust_MachineCheck]
		SELECT @MajorVersion = CAST(LEFT(Value, CHARINDEX('.',Value)-1) AS BIGINT)
		FROM [dbo].[tbl_SCRIPT_ENVIRONMENT_DETAILS]
		WHERE Name = 'SQL Version (SP)'
	END

	IF OBJECT_ID('cust_Databases') IS NOT NULL AND OBJECT_ID('cust_MachineCheck') IS NOT NULL
  BEGIN
		IF EXISTS (
		SELECT database_id
		FROM [dbo].[cust_Databases] d
			LEFT OUTER JOIN @Tbl_ver_complevel v ON d.compatibility_level=v.sqlcomptlevel
		WHERE sqlver <> @MajorVersion
	 )
     INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('User database is set to compatibility level lower than the default installation level.', 'Database Settings', 'Critical', NULL, NULL, NULL)
	END

	IF OBJECT_ID('cust_Databases') IS NOT NULL
  BEGIN
		IF EXISTS (
	   SELECT database_id
		FROM cust_Databases
		WHERE collation_name <> (SELECT DISTINCT collation_name
			FROM cust_Databases
			WHERE database_id=1)
			AND name NOT LIKE '%ReportServer%'
	  )
	 INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Databases found that have collations different from master/model databases.', 'Database Settings', 'Critical', NULL, NULL, NULL)



		IF COLUMNPROPERTY(OBJECT_ID('cust_Databases'),'delayed_durability_desc', 'columnid') IS NOT NULL
BEGIN
			DECLARE @DelayedDurabilityDBs VARCHAR(2000) = ''
			DECLARE @DDSQL NVARCHAR(MAX)
			SET @DDSQL = N'

SELECT DISTINCT @DelayedDurabilityDBs = @DelayedDurabilityDBs + name + '', ''
FROM [dbo].[cust_Databases]
WHERE delayed_durability_desc <> ''DISABLED''
'
			EXECUTE sp_executesql
@stmt = @DDSQL, 
@params = N'@DelayedDurabilityDBs VARCHAR(2000) OUTPUT',
@DelayedDurabilityDBs = @DelayedDurabilityDBs OUTPUT


			IF @DelayedDurabilityDBs > ''
BEGIN
				SELECT @DelayedDurabilityDBs = CASE WHEN RIGHT(@DelayedDurabilityDBs,2) = ', ' THEN LEFT(@DelayedDurabilityDBs, (LEN(@DelayedDurabilityDBs)-1)) ELSE @DelayedDurabilityDBs END
				SET @DelayedDurabilityDBs = 'The following database(s) have Delayed Durability enabled: ' + @DelayedDurabilityDBs + '.'
				INSERT INTO PTOClinicFindings
					([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
				SELECT 'Databases using Delayed Durability.', 'Operational Excellence', 'Critical', NULL, NULL, @DelayedDurabilityDBs

			END
		END

		DECLARE @ParamForcedDBs VARCHAR(2000) = ''
		SELECT DISTINCT @ParamForcedDBs = @ParamForcedDBs + name + ', '
		FROM [dbo].[cust_Databases]
		WHERE is_parameterization_forced = '1' or is_parameterization_forced = 'True'

		IF @ParamForcedDBs > ''
BEGIN
			SELECT @ParamForcedDBs = CASE WHEN RIGHT(@ParamForcedDBs,2) = ', ' THEN LEFT(@ParamForcedDBs, (LEN(@ParamForcedDBs)-1)) ELSE @ParamForcedDBs END
			SET @ParamForcedDBs = 'The following database(s) have the Parameterization Forced setting enabled: ' + @ParamForcedDBs + '.'
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading], SummaryCategory)
			SELECT 'Databases with Parameterization Forced.', 'Operational Excellence', 'Critical', NULL, NULL, @ParamForcedDBs, 'QueryPerformance'

		END


		DECLARE @TrustworthyDBs VARCHAR(2000) = ''
		SELECT DISTINCT @TrustworthyDBs = @TrustworthyDBs + name + ', '
		FROM [dbo].[cust_Databases]
		WHERE (is_trustworthy_on = '1' or is_trustworthy_on = 'True') AND
			database_id > 4

		IF @TrustworthyDBs > ''
BEGIN
			SELECT @TrustworthyDBs = CASE WHEN RIGHT(@TrustworthyDBs,2) = ', ' THEN LEFT(@TrustworthyDBs, (LEN(@TrustworthyDBs)-1)) ELSE @TrustworthyDBs END
			SET @TrustworthyDBs = 'The following database(s) have the Trustworthy setting enabled: ' + @TrustworthyDBs + '.'
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading], SummaryCategory)
			SELECT 'Databases with Trustworthy setting enabled.', 'Operational Excellence', 'Critical', NULL, NULL, @TrustworthyDBs, 'Security'

		END


		DECLARE @StandByDBs VARCHAR(2000) = ''
		SELECT DISTINCT @StandByDBs = @StandByDBs + name + ', '
		FROM [dbo].[cust_Databases]
		WHERE is_in_standby = '1' or is_in_standby = 'True'

		IF @StandByDBs > ''
BEGIN
			SELECT @StandByDBs = CASE WHEN RIGHT(@StandByDBs,2) = ', ' THEN LEFT(@StandByDBs, (LEN(@StandByDBs)-1)) ELSE @StandByDBs END
			SET @StandByDBs = 'The following database(s) are in StandBy mode: ' + @StandByDBs + '.'
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			SELECT 'Databases in StandyBy mode.', 'Operational Excellence', 'Critical', NULL, NULL, @StandByDBs

		END


		DECLARE @DBsNotOnline VARCHAR(2000) = ''
		SELECT DISTINCT @DBsNotOnline = @DBsNotOnline + name + ', '
		FROM [dbo].[cust_Databases]
		WHERE state_desc <> 'ONLINE'

		IF @DBsNotOnline > ''
BEGIN
			SELECT @DBsNotOnline = CASE WHEN RIGHT(@DBsNotOnline,2) = ', ' THEN LEFT(@DBsNotOnline, (LEN(@DBsNotOnline)-1)) ELSE @DBsNotOnline END
			SET @DBsNotOnline = 'The following database(s) are not Online: ' + @DBsNotOnline + '.'
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			SELECT 'Databases not online.', 'Operational Excellence', 'Critical', NULL, NULL, @DBsNotOnline

		END

	END


	IF OBJECT_ID('cust_DBFileSizes') IS NOT NULL AND OBJECT_ID('cust_OSInfo') IS NOT NULL AND @ServerType = 'OnPremisesSQL'
  BEGIN

		DECLARE @tdb_files int, @online_count int, @filesizes smallint, @initialfilesizes smallint, @tgrwoth smallint

		SELECT @tdb_files        = COUNT(FilePath)
		FROM [cust_DBFileSizes]
		WHERE DBName = 'tempdb' AND LogicalName <> 'templog';

		SELECT @filesizes        = COUNT(DISTINCT sizeInMB)
		FROM [cust_DBFileSizes]
		WHERE DBName = 'tempdb' AND LogicalName <> 'templog';

		SELECT @initialfilesizes = COUNT(DISTINCT InitialSizeInMB)
		FROM [cust_DBFileSizes]
		WHERE DBName = 'tempdb' AND LogicalName <> 'templog';

		SELECT @tgrwoth          = COUNT(DISTINCT Growth)
		FROM [cust_DBFileSizes]
		WHERE DBName = 'tempdb' AND LogicalName <> 'templog';

		SELECT @online_count     = [scheduler_count]
		FROM [cust_OSInfo]

		IF (@filesizes > 1 OR @initialfilesizes > 1 OR @tgrwoth > 1 OR (CASE WHEN (@tdb_files >= 4 AND @tdb_files <= 8 AND @tdb_files % 4 = 0) OR (@tdb_files >= (@online_count / 2) AND @tdb_files >= 8 AND @tdb_files % 4 = 0)  THEN 0 ELSE 1 END)>0)
    BEGIN
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading], SummaryCategory)
			VALUES('There are fewer tempdb files than the number of processors, the files are not equally sized or number of files is not a multiple of 4.', 'Database Settings', 'Critical', NULL, NULL, NULL, 'tempdb')
		END
	END

	IF OBJECT_ID('cust_DBDiskSpace') IS NOT NULL AND @ServerType = 'OnPremisesSQL'
  BEGIN
		IF EXISTS (SELECT DISTINCT DBName
		FROM cust_DBDiskSpace
		WHERE CASE WHEN ISNUMERIC(NextGrowthSizeMB)=1 THEN CONVERT(float, NextGrowthSizeMB) ELSE 0 END >1024.0)
    BEGIN
			DECLARE @DBBigAutoGrow VARCHAR(1000) = ''
			SELECT @DBBigAutoGrow = @DBBigAutoGrow + DBName + ','
			FROM cust_DBDiskSpace
			WHERE CASE WHEN ISNUMERIC(NextGrowthSizeMB)=1 THEN CONVERT(float, NextGrowthSizeMB) ELSE 0 END >1024.0
			SELECT @DBBigAutoGrow = LEFT(@DBBigAutoGrow, LEN(@DBBigAutoGrow)-1)

			SET @DBBigAutoGrow = 'The following databases have a large next autogrow increment: ' + @DBBigAutoGrow
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading], SummaryCategory)
			VALUES('Databases have been identified with next autogrow increment greater than 1GB.', 'Database Settings', 'Critical', NULL, NULL, @DBBigAutoGrow, 'Disk')
		END
	END

	IF OBJECT_ID('cust_DBFileSizes') IS NOT NULL
  BEGIN
		IF EXISTS (SELECT DISTINCT DBName
		FROM cust_DBFileSizes
		WHERE Growth LIKE '%[%]%' AND
			dbname NOT IN('msdb','master','model'))
    BEGIN

			DECLARE @DBPercentAutoGrow VARCHAR(2000) = ''
			SELECT @DBPercentAutoGrow = @DBPercentAutoGrow + DBName + ','
			FROM cust_DBFileSizes
			WHERE Growth LIKE '%[%]%' AND
				dbname NOT IN('msdb','master','model')

			SELECT @DBPercentAutoGrow = LEFT(@DBPercentAutoGrow, LEN(@DBPercentAutoGrow)-1)

			SET @DBPercentAutoGrow = 'The following databases are set to an autogrow percentage growth: ' + @DBPercentAutoGrow
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('Databases were identified with autogrow option set to percentage growth.', 'Database Settings', 'Critical', NULL, NULL, @DBPercentAutoGrow)
		END
	END

	IF OBJECT_ID('cust_Databases') IS NOT NULL
  BEGIN
		IF EXISTS (SELECT database_id
		FROM cust_Databases
		WHERE is_auto_close_on = '1' OR is_auto_close_on = 'True')
    BEGIN
			DECLARE @DBAutoCloseOn VARCHAR(1000) = ''
			SELECT @DBAutoCloseOn = @DBAutoCloseOn + name + ','
			FROM cust_Databases
			WHERE is_auto_close_on = '1' OR is_auto_close_on = 'True'
			SELECT @DBAutoCloseOn = LEFT(@DBAutoCloseOn, LEN(@DBAutoCloseOn)-1)

			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('Database(s) with AUTO_CLOSE option enabled.', 'Database Settings', 'Critical', NULL, NULL, @DBAutoCloseOn)
		END

		IF EXISTS (SELECT database_id
		FROM cust_Databases
		WHERE is_auto_shrink_on = '1' OR is_auto_shrink_on = 'True')
    BEGIN
			DECLARE @DBAutoShrinkOn VARCHAR(1000) = ''
			SELECT @DBAutoShrinkOn = @DBAutoShrinkOn + name + ','
			FROM cust_Databases
			WHERE is_auto_shrink_on = '1' OR is_auto_shrink_on = 'True'
			SELECT @DBAutoShrinkOn = LEFT(@DBAutoShrinkOn, LEN(@DBAutoShrinkOn)-1)

			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('Database(s) with AUTO_SHRINK option enabled.', 'Database Settings', 'Critical', NULL, NULL, @DBAutoShrinkOn)
		END

		IF EXISTS (SELECT database_id
		FROM cust_Databases
		WHERE is_auto_create_stats_on = '0' OR is_auto_create_stats_on = 'False' )
    BEGIN
			DECLARE @DBAutoCreateStatsOff VARCHAR(1000) = ''
			SELECT @DBAutoCreateStatsOff = @DBAutoCreateStatsOff + name + ','
			FROM cust_Databases
			WHERE is_auto_create_stats_on = '0' OR is_auto_create_stats_on = 'False'
			SELECT @DBAutoCreateStatsOff = LEFT(@DBAutoCreateStatsOff, LEN(@DBAutoCreateStatsOff)-1)

			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('Database(s) with AUTO_CREATE_STATISTICS option disabled.', 'Database Settings', 'High', NULL, NULL, @DBAutoCreateStatsOff)
		END

		IF EXISTS (SELECT database_id
		FROM cust_Databases
		WHERE is_auto_update_stats_on = '0' OR is_auto_update_stats_on = 'False'  )
    BEGIN
			DECLARE @DBAutoUpdateStatsOff VARCHAR(1000) = ''
			SELECT @DBAutoUpdateStatsOff = @DBAutoUpdateStatsOff + name + ','
			FROM cust_Databases
			WHERE is_auto_update_stats_on = '0' OR is_auto_update_stats_on = 'False'
			SELECT @DBAutoUpdateStatsOff = LEFT(@DBAutoUpdateStatsOff, LEN(@DBAutoUpdateStatsOff)-1)

			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('Database(s) with AUTO_UPDATE_STATISTICS option disabled.', 'Database Settings', 'High', NULL, NULL, @DBAutoUpdateStatsOff)
		END

		IF EXISTS (SELECT database_id
		FROM cust_Databases
		WHERE (is_auto_update_stats_on  = '0' OR is_auto_update_stats_on  = 'False') and (is_auto_update_stats_async_on= '1' OR is_auto_update_stats_async_on= 'True') )
    BEGIN
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('Database(s) with AUTO_UPDATE_STATISTICS option disabled and AUTO_UPDATE_STATISTICS_ASYNC enabled.', 'Database Settings', 'High', NULL, NULL, NULL)
		END

		IF EXISTS (SELECT database_id
		FROM cust_Databases
		WHERE page_verify_option_desc <> 'CHECKSUM' and @MajorVersion>9 )
    BEGIN
			DECLARE @DBPageVerifyOff VARCHAR(1000) = ''
			SELECT @DBPageVerifyOff = @DBPageVerifyOff + name + ','
			FROM cust_Databases
			WHERE page_verify_option_desc <> 'CHECKSUM' and @MajorVersion>9
			SELECT @DBPageVerifyOff = LEFT(@DBPageVerifyOff, LEN(@DBPageVerifyOff)-1)

			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('Database(s) with Page Verify option not set to CHECKSUM on a SQL 2005 or above instance.', 'Database Settings', 'Medium', NULL, NULL, @DBPageVerifyOff)
		END

	END


	IF 	OBJECT_ID('dbo.cust_SuspectPages') IS NOT NULL
  BEGIN
		IF EXISTS (SELECT *
		FROM dbo.cust_SuspectPages)
  	BEGIN

			DECLARE @DBSuspectPages VARCHAR(1000) = ''
			SELECT @DBSuspectPages = @DBSuspectPages+ ISNULL(name, cast(database_id as varchar(255))) + ','
			FROM cust_SuspectPages
			SELECT @DBSuspectPages = LEFT(@DBSuspectPages, LEN(@DBSuspectPages)-1)

			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('Suspect pages have been identified.', 'Operational Excellence', 'Critical', NULL, NULL, @DBSuspectPages)
		END
	END

	IF OBJECT_ID('dbo.cust_LastDBCCCheckDBDate') IS NOT NULL and @ServerType = 'OnPremisesSQL'
  BEGIN
		IF EXISTS (
  	  SELECT DBName
		FROM dbo.cust_LastDBCCCheckDBDate
		WHERE DATEDIFF(DAY, CASE WHEN ISDATE(LastDBCCDate)=1 THEN CONVERT(datetime, LastDBCCDate) ELSE CONVERT(datetime, '1900-01-01') END, @executiondatetime) > 14
			AND DBName NOT IN('tempdb')
	)
	BEGIN

			DECLARE @NoRecentCheckDB VARCHAR(2000) = ''

			SELECT DISTINCT @NoRecentCheckDB = @NoRecentCheckDB  + DBName + ','
			FROM dbo.cust_LastDBCCCheckDBDate
			WHERE DATEDIFF(DAY, CASE WHEN ISDATE(LastDBCCDate)=1 THEN CONVERT(datetime, LastDBCCDate) ELSE CONVERT(datetime, '1900-01-01') END, @executiondatetime) > 14
				AND DBName NOT IN('tempdb','master','tempdb','msdb')

			SELECT @NoRecentCheckDB = LEFT(@NoRecentCheckDB, LEN(@NoRecentCheckDB)-1)
			SET @NoRecentCheckDB = 'The following database(s) have not had DBCC CHECKDB executed in the last 7 days: ' + @NoRecentCheckDB
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('DBCC CHECKDB has not been run within seven days.', 'Operational Excellence', 'Critical', NULL, NULL, @NoRecentCheckDB)
		END

	END
	IF OBJECT_ID('tempdb..#cust_bkhist') IS NOT NULL
  DROP TABLE #cust_bkhist

	DECLARE @BackupOlder7Days int =0, @NoLogBackup int=0

	IF OBJECT_ID('dbo.cust_Databases') IS NOT NULL and OBJECT_ID('dbo.cust_backupHistory') IS NOT NULL
  BEGIN
		;with
			cust_bkhist
			as
			(
				SELECT d.name, recovery_model_desc, log_reuse_wait_desc, bk.LastFullBackupDate, bk.LastDifferentialBackupDate, bk.LastLogBackupDate,
					CASE WHEN  LastFullBackupDate IS NULL OR DATEDIFF(day,LastFullBackupDate, @executiondatetime ) >7 THEN 1 ELSE 0 END as 'BackupOlder7Days',
					CASE WHEN recovery_model_desc='FULL' and (LastLogBackupDate  IS NULL OR DATEDIFF(hour,LastFullBackupDate, LastLogBackupDate ) < 0) THEN 1 ELSE 0 END as 'NoLogBackup'
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
				WHERE d.name NOT IN('tempdb','master','model','msdb')
			)
		SELECT *
		INTO #cust_bkhist
		FROM cust_bkhist

		SELECT @BackupOlder7Days=SUM(BackupOlder7Days), @NoLogBackup=SUM(NoLogBackup)
		FROM #cust_bkhist

		IF @BackupOlder7Days>0
	BEGIN
			DECLARE @OldBackup VARCHAR(2000) = ''
			SELECT DISTINCT @OldBackup = @OldBackup + name + ','
			FROM #cust_bkhist
			WHERE BackupOlder7Days = 1

			SELECT @OldBackup = LEFT(@OldBackup, LEN(@OldBackup)-1)

			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('Databases found with most recent full database backup older than 7 days or that have never been backed up.', 'Operational Excellence', 'Critical', NULL, NULL, @OldBackup)

		END

		IF @NoLogBackup>0
	BEGIN
			DECLARE @NoTLog VARCHAR(2000) = ''
			SELECT DISTINCT @NoTLog = @NoTLog + name + ','
			FROM #cust_bkhist
			WHERE NoLogBackup = 1

			SELECT @NoTLog = LEFT(@NoTLog, LEN(@NoTLog)-1)

			SET @NoTLog = 'The following database(s) have no recent transaction log backups in the Full Recovery model: ' + @NoTLog
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('User Databases found with no Transactional log backups that are in Full recovery mode.', 'Operational Excellence', 'Critical', NULL, NULL, @NoTLog)
		END
	END

	IF OBJECT_ID('cust_GetStats') IS NOT NULL
	BEGIN
		IF EXISTS ( SELECT DBName, (RowMods*1.0/RowCnt), RowMods, RowCnt, *
		FROM dbo.cust_GetStats
		WHERE StatName NOT LIKE '_WA_Sys%' AND RowCnt > 10000 AND (RowMods*1.0/RowCnt) >.2 )
		BEGIN
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('Databases identified with one or more tables, with indexes that may require update statistics.', 'Operational Excellence', 'Critical', NULL, NULL, NULL)
		END
	END
END

IF OBJECT_ID('dbo.cust_LogInfo') IS NOT NULL
  BEGIN
	IF EXISTS ( SELECT dbname, SUM (CASE WHEN ISNUMERIC(VLFCount)=1 THEN VLFCount ELSE 0 END )
	FROM dbo.cust_LogInfo
	GROUP BY dbname
	HAVING SUM (CASE WHEN ISNUMERIC(VLFCount)=1 THEN VLFCount ELSE 0 END )>1000)
	BEGIN
		DECLARE @BigVLFCount VARCHAR(1000) = ''

		SELECT DISTINCT @BigVLFCount = @BigVLFCount + DBName + ' has ' + CAST(SUM(CAST(VLFCount AS BIGINT)) AS VARCHAR(10)) + ' VLFs, '
		FROM dbo.cust_LogInfo
		GROUP BY dbname
		HAVING SUM (CASE WHEN ISNUMERIC(VLFCount)=1 THEN VLFCount ELSE 0 END )>1000


		SELECT @BigVLFCount = LEFT(@BigVLFCount, LEN(@BigVLFCount)-1)

		SET @BigVLFCount = 'The following database(s) have too many Virtual Log Files: ' + @BigVLFCount + '.'
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Too many virtual log files may impact the SQL Server performance.', 'Operational Excellence', 'High', NULL, NULL, @BigVLFCount)
	END
END

IF OBJECT_ID('dbo.cust_Index_Low_Fill_Factor') IS NOT NULL
  BEGIN
	IF EXISTS ( SELECT [Database_Name], *
	FROM cust_Index_Low_Fill_Factor )
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Review the Fillfactor setting for indexes.', 'Operational Excellence', 'High', NULL, NULL, NULL)
	END
END

IF OBJECT_ID('tempdb..#cust_Waiting') IS NOT NULL
  DROP TABLE #cust_Waiting

CREATE TABLE #cust_Waiting
(
	WaitType sysname,
	[Percentage] decimal(18,4)
)

IF (OBJECT_ID('dbo.cust_Waiting') IS NOT NULL) AND (SELECT COUNT(*)
	FROM #cust_Waiting )<=0
  BEGIN
	INSERT INTO #cust_Waiting
	SELECT WaitType, [Percentage]
	FROM cust_Waiting
	ORDER BY [Percentage] DESC
END

IF OBJECT_ID('dbo.tbl_OS_WAIT_STATS') IS NOT NULL AND NOT EXISTS(SELECT *
	FROM #cust_Waiting)
  BEGIN
	declare @StartTime datetime='19000101'
	declare @EndTime datetime='19000101'
	SELECT @StartTime=MIN(runtime)
	FROM tbl_OS_WAIT_STATS
	SELECT @EndTime  =MAX(runtime)
	FROM tbl_OS_WAIT_STATS


	INSERT INTO #cust_Waiting
	SELECT TOP 10
		s.wait_type AS WaitType
     --, (e.waiting_tasks_count - s.waiting_tasks_count) as [waiting_tasks_count]
     --, (e.wait_time_ms - s.wait_time_ms) as [wait_time_ms]
     --, (e.wait_time_ms - s.wait_time_ms)/((e.waiting_tasks_count - s.waiting_tasks_count)) as [avg_wait_time_ms]
     --, (e.max_wait_time_ms) as [max_wait_time_ms]
     --, (e.signal_wait_time_ms - s.signal_wait_time_ms) as [signal_wait_time_ms]
     --, (e.signal_wait_time_ms - s.signal_wait_time_ms)/((e.waiting_tasks_count - s.waiting_tasks_count)) as [avg_signal_time_ms]
  
     , 100.0 * (CAST(e.wait_time_ms AS BIGINT)- CAST(s.wait_time_ms AS BIGINT)) / SUM ((CAST(e.wait_time_ms AS BIGINT)- CAST(s.wait_time_ms AS BIGINT))) OVER() AS [Percentage]

	--, s.runtime as [start_time]
	--, e.runtime as [end_time]
	--, DATEDIFF(ss, s.runtime, e.runtime) as [seconds_in_sample]

	FROM tbl_OS_WAIT_STATS e
		inner join (
     		select *
		from tbl_OS_WAIT_STATS
		where runtime = @StartTime
     		) s on (s.wait_type = e.wait_type)
	where
     e.runtime = @EndTime
		and s.runtime = @StartTime
		and CAST(e.wait_time_ms AS BIGINT) > 0
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
		AND DATEDIFF(ss, s.runtime, e.runtime) > 0
	ORDER BY [Percentage] DESC
END



--- rules for waits
IF OBJECT_ID('tempdb..#cust_Waiting') IS NOT NULL
  BEGIN


	IF EXISTS ( SELECT *
	FROM #cust_Waiting
	WHERE WaitType IN ('RESOURCE_SEMAPHORE','RESOURCE_SEMAPHORE_SMALL_QUERY','RESOURCE_SEMAPHORE_QUERY_COMPILE')
		AND Percentage > 20)
	BEGIN
		DECLARE @WaitPercent1 VARCHAR(500)
		SELECT @WaitPercent1 = 'Memory Grant wait percentage is ' + CAST(Percentage AS VARCHAR(20))  + '.'
		FROM #cust_Waiting
		WHERE WaitType IN ('RESOURCE_SEMAPHORE','RESOURCE_SEMAPHORE_SMALL_QUERY','RESOURCE_SEMAPHORE_QUERY_COMPILE')
			AND Percentage > 20

		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High memory grant waits exist.', 'Performance Metrics', 'Critical', NULL, NULL, @WaitPercent1)
	END


	IF EXISTS ( SELECT *
	FROM #cust_Waiting
	WHERE WaitType IN ('CMEMTHREAD')
		AND Percentage > 20)
	BEGIN
		DECLARE @WaitPercent2 VARCHAR(500)
		SELECT @WaitPercent2 = 'CMEMTHREAD wait percentage is ' + CAST(Percentage AS VARCHAR(20))  + '.'
		FROM #cust_Waiting
		WHERE WaitType LIKE 'CMEMTHREAD' AND Percentage > 20

		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High CMEMTHREAD waits exist.', 'Performance Metrics', 'Critical', NULL, NULL, @WaitPercent2)
	END

	IF EXISTS ( SELECT *
	FROM #cust_Waiting
	WHERE WaitType LIKE 'WRITELOG' AND Percentage > 20 )
	BEGIN
		DECLARE @WaitPercent3 VARCHAR(500)
		SELECT @WaitPercent3 = 'WriteLog wait percentage is ' + CAST(Percentage AS VARCHAR(20))  + '.'
		FROM #cust_Waiting
		WHERE WaitType LIKE 'WRITELOG%' AND Percentage > 20
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High log write waits exist.', 'Performance Metrics', 'Critical', NULL, NULL, @WaitPercent3)
	END

	IF EXISTS ( SELECT WaitType
	FROM #cust_Waiting
	WHERE WaitType LIKE 'LATCH%' AND Percentage > 20 )
	BEGIN
		DECLARE @WaitPercent4 VARCHAR(500)
		SELECT @WaitPercent4 = 'Latch wait percentage is ' + CAST(Percentage AS VARCHAR(20))  + '.'
		FROM #cust_Waiting
		WHERE WaitType LIKE 'LATCH%' AND Percentage > 20
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High non-page latch waits exist.', 'Performance Metrics', 'Critical', NULL, NULL, @WaitPercent4)
	END

	IF EXISTS ( SELECT *
	FROM #cust_Waiting
	WHERE WaitType LIKE 'PAGELATCH%' AND Percentage > 30 )
	BEGIN
		DECLARE @WaitPercent5 VARCHAR(500)
		SELECT @WaitPercent5 = 'PageLatch wait percentage is ' + CAST(Percentage AS VARCHAR(20)) + '.'
		FROM #cust_Waiting
		WHERE WaitType LIKE 'PAGELATCH%' AND Percentage > 30
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High Page latch waits exist.', 'Performance Metrics', 'Critical', NULL, NULL, @WaitPercent5)
	END

	IF EXISTS ( SELECT WaitType
	FROM #cust_Waiting
	WHERE WaitType LIKE 'PAGEIOLATCH%' AND Percentage > 30 )
	BEGIN
		DECLARE @WaitPercent6 VARCHAR(500)
		SELECT @WaitPercent6 = 'PageIOLatch percentage is ' + CAST(Percentage AS VARCHAR(20))  + '.'
		FROM #cust_Waiting
		WHERE WaitType LIKE 'PAGEIOLATCH%' AND Percentage > 30
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High Page IO latch waits exist.', 'Performance Metrics', 'Medium', NULL, NULL, @WaitPercent6)
	END

	--need to add something here to verify it is an "OLTP" env. TC
	IF EXISTS (SELECT *
	FROM #cust_Waiting
	WHERE WaitType LIKE 'CXPACKET' AND Percentage > 50 )
	BEGIN
		DECLARE @WaitPercent7 VARCHAR(500)
		SELECT @WaitPercent7 = 'CXPACKET wait percentage is ' + CAST(Percentage AS VARCHAR(20))  + '.'
		FROM #cust_Waiting
		WHERE WaitType LIKE 'CXPACKET' AND Percentage > 50
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High parallelism waits exist in an OLTP environment.', 'Performance Metrics', 'High', NULL, NULL, @WaitPercent7)
	END
END

IF OBJECT_ID('dbo.CounterData') IS NOT NULL and OBJECT_ID('dbo.CounterDetails') IS NOT NULL
  BEGIN

	DECLARE @systemMemory bigint=0

	IF OBJECT_ID('dbo.cust_OSInfo') IS NOT NULL
      SELECT @systemMemory=CASE WHEN ISNUMERIC([physical_memory_in_bytes])=1 THEN CONVERT(BIGINT,[physical_memory_in_bytes]) /1024/1024.0 ELSE 100 END
	FROM [cust_OSInfo]

	BEGIN
		DECLARE @MinPLE INT, @MaxPLE INT, @AvgPLE INT, @PLEReading VARCHAR(2000)

		SELECT @MinPLE = MIN(CounterValue), @MaxPLE = MAX(CounterValue), @AvgPLE = AVG(CounterValue)

		--SELECT MIN(CounterValue),  MAX(CounterValue),  AVG(CounterValue)
		FROM CounterData d
			INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like '%:Buffer Manager'
			AND CounterName LIKE 'Page life expectancy'

		SELECT @PLEReading = 'Minimum PLE: ' + CAST(@MinPLE AS VARCHAR(100))+ ', Maxiumum PLE: ' + CAST(@MaxPLE AS VARCHAR(100)) + ', Average PLE: ' + CAST(@AvgPLE AS VARCHAR(100))

		IF @AvgPLE < 1000
		BEGIN
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading], SummaryCategory)
			VALUES('Low page life expectancy.', 'Performance Metrics', 'Critical', NULL, NULL, @PLEReading, 'Memory')
		END
	END

	--
	IF EXISTS ( 
       SELECT *
	FROM CounterData d
		INNER JOIN CounterDetails c on c.CounterID=d.CounterID
	WHERE ObjectName like '%:Buffer Manager'
		AND CounterName LIKE 'Free pages'
		AND CounterValue<640	
	)
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading], SummaryCategory)
		VALUES('Low free pages.', 'Performance Metrics', 'Critical', NULL, NULL, NULL, 'Memory')
	END

	IF @systemMemory > 0 AND EXISTS 
	( 
	   SELECT *
		FROM CounterData d
			INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like 'Memory'
			AND CounterName LIKE 'Available MBytes'
			AND ( CounterValue<64 OR (CounterValue*1.0/@systemMemory)<.10  )
	)
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading], SummaryCategory)
		VALUES('Available memory MB too low.', 'Performance Metrics', 'Critical', NULL, NULL, NULL, 'Memory')
	END



	/* Tim Chapman
	Check to see if the available MBytes is too high.
	Only report if the BPool is ramped up.
	*/
	IF EXISTS 
	( 
	   SELECT AVG(CounterValue)
		FROM CounterData d
			INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like 'Memory'
			AND CounterName LIKE 'Available MBytes'
		HAVING AVG(CounterValue) > 10000
	   ) AND NOT EXISTS
	   (
		SELECT (((MaxTargetServerMemory - MaxTotalServerMemory)/MaxTargetServerMemory*1.000)*100),
			MaxTargetServerMemory , MaxTotalServerMemory
		FROM
			(
		   SELECT
				AvgTargetServerMemory = AVG(CASE WHEN CounterName = 'Target Server Memory (KB)' THEN CounterValue ELSE NULL END),
				AvgTotalServerMemory = AVG(CASE WHEN CounterName = 'Total Server Memory (KB)' THEN CounterValue ELSE NULL END),
				MaxTargetServerMemory = MAX(CASE WHEN CounterName = 'Target Server Memory (KB)' THEN CounterValue ELSE NULL END),
				MaxTotalServerMemory = MAX(CASE WHEN CounterName = 'Total Server Memory (KB)' THEN CounterValue ELSE NULL END)
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE  (CounterName LIKE '%Target%' OR CounterName LIKE '%Total%')AND
				ObjectName LIKE '%Memory Manager' AND
				CounterValue > 0
		) x
		WHERE (((MaxTargetServerMemory - MaxTotalServerMemory)/MaxTargetServerMemory*1.000)*100)>8
	   )
	BEGIN
		DECLARE @AvailableMBytes VARCHAR(120)

		SELECT @AvailableMBytes = 'Available MBytes: ' + CAST((AVG(CounterValue)) AS VARCHAR(20))
		FROM CounterData d
			INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like 'Memory'
			AND CounterName LIKE 'Available MBytes'
		HAVING AVG(CounterValue) > 10000

		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Available memory MB set too high.', 'Performance Metrics', 'Critical', NULL, NULL, @AvailableMBytes)
	END

	IF EXISTS(
		SELECT (((MaxTargetServerMemory - MaxTotalServerMemory)/MaxTargetServerMemory*1.000)*100),
		MaxTargetServerMemory , MaxTotalServerMemory
	FROM (
		   SELECT
			AvgTargetServerMemory = AVG(CASE WHEN CounterName = 'Target Server Memory (KB)' THEN CounterValue ELSE NULL END),
			AvgTotalServerMemory = AVG(CASE WHEN CounterName = 'Total Server Memory (KB)' THEN CounterValue ELSE NULL END),
			MaxTargetServerMemory = MAX(CASE WHEN CounterName = 'Target Server Memory (KB)' THEN CounterValue ELSE NULL END),
			MaxTotalServerMemory = MAX(CASE WHEN CounterName = 'Total Server Memory (KB)' THEN CounterValue ELSE NULL END)
		FROM CounterData d
			INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE  (CounterName LIKE '%Target%' OR CounterName LIKE '%Total%')AND
			ObjectName LIKE '%Memory Manager' AND
			CounterValue > 0
		   ) x
	WHERE (((MaxTargetServerMemory - MaxTotalServerMemory)/MaxTargetServerMemory*1.000)*100)>25
     )
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Buffer Pool has not hit target.', 'Performance Metrics', 'Critical', NULL, NULL, NULL)
	END

	DECLARE @TopLazyWrites DECIMAL(18,3)

	SELECT @TopLazyWrites = AVG(CounterValue)
	FROM CounterData d
		INNER JOIN CounterDetails c on c.CounterID=d.CounterID
	WHERE ObjectName like '%:Buffer Manager'
		AND CounterName LIKE 'Lazy writes/sec'
	HAVING AVG(CounterValue) > 10

	IF @TopLazyWrites > 0
	BEGIN
		DECLARE @TopLazyMsg VARCHAR(MAX)
		SET @TopLazyMsg = 'The highest lazy write count is:' + CAST(@TopLazyWrites AS VARCHAR(20))
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading], SummaryCategory)
		VALUES('Too many lazy writes per second.', 'Performance Metrics', 'Critical', NULL, NULL, @TopLazyMsg, 'Memory')
	END

	IF OBJECT_ID('tempdb..#Rule_Compilations_ReCompilations') IS NOT NULL
	DROP TABLE #Rule_Compilations_ReCompilations

	IF OBJECT_ID('tempdb..#Rule_BatchRequests_Compilations') IS NOT NULL
	DROP TABLE #Rule_BatchRequests_Compilations

	IF OBJECT_ID('tempdb..#Rule_BatchRequests_FreeSpaceScans') IS NOT NULL
	DROP TABLE #Rule_BatchRequests_FreeSpaceScans

	IF OBJECT_ID('tempdb..#Rule_BatchRequests_Pagelookups') IS NOT NULL
	DROP TABLE #Rule_BatchRequests_Pagelookups

	IF OBJECT_ID('tempdb..#Rule_Target_Total_Server_Memory') IS NOT NULL
	DROP TABLE #Rule_Target_Total_Server_Memory

	IF OBJECT_ID('tempdb..#Rule_Logins_Logouts') IS NOT NULL
	DROP TABLE #Rule_Logins_Logouts

	-- Ratio Counters Rule
	--#Rule_Compilations_ReCompilations
    ;
	with
		c1
		AS
		(
			SELECT ObjectName, CounterName, c.CounterID, RecordIndex, CounterDateTime, CounterValue
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName like '%:SQL Statistics' AND CounterName LIKE 'SQL Re-Compilations/sec'
		)
    ,
		c2
		AS
		(
			SELECT ObjectName, CounterName, c.CounterID, RecordIndex, CounterDateTime, CounterValue, NTILE(4) OVER(ORDER BY RecordIndex) as Quartile
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName like '%:SQL Statistics' AND CounterName LIKE 'SQL Compilations/sec'
				AND CounterValue<>0
		)
	SELECT Quartile, c2.CounterName + ' / ' + c1.CounterName as Comparative,
		AVG(c1.CounterValue*1.0/c2.CounterValue) as avg_ratio, MAX(c1.CounterValue*1.0/c2.CounterValue) as max_ratio, MIN(c1.CounterDateTime) as min_interval, MAX(c1.CounterDateTime) as max_interval
	INTO #Rule_Compilations_ReCompilations
	FROM C1
		INNER JOIN C2 on c1.RecordIndex =c2.RecordIndex
	GROUP BY Quartile, c2.CounterName + ' / ' + c1.CounterName
	ORDER BY 1

	--#Rule_BatchRequests_Compilations
	;with
		c1
		AS
		(
			SELECT ObjectName, CounterName, c.CounterID, RecordIndex, CounterDateTime, CounterValue
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName like '%:SQL Statistics' AND CounterName LIKE 'SQL Compilations/sec'
		)
    ,
		c2
		AS
		(
			SELECT ObjectName, CounterName, c.CounterID, RecordIndex, CounterDateTime, CounterValue, NTILE(4) OVER(ORDER BY RecordIndex) as Quartile
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName like '%:SQL Statistics' AND CounterName LIKE 'Batch Requests/sec'
				AND CounterValue<>0
		)
	SELECT Quartile, c2.CounterName + ' / ' + c1.CounterName as Comparative,
		AVG(c1.CounterValue*1.0/c2.CounterValue) as avg_ratio, MAX(c1.CounterValue*1.0/c2.CounterValue) as max_ratio, MIN(c1.CounterDateTime) as min_interval, MAX(c1.CounterDateTime) as max_interval
	INTO #Rule_BatchRequests_Compilations
	FROM C1
		INNER JOIN C2 on c1.RecordIndex =c2.RecordIndex
	GROUP BY Quartile, c2.CounterName + ' / ' + c1.CounterName
	ORDER BY 1

	--#Rule_BatchRequests_FreeSpaceScans
	;with
		c1
		AS
		(
			SELECT ObjectName, CounterName, c.CounterID, RecordIndex, CounterDateTime, CounterValue
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName like '%:Access Methods' AND CounterName LIKE 'FreeSpace Scans/sec'
		)
    ,
		c2
		AS
		(
			SELECT ObjectName, CounterName, c.CounterID, RecordIndex, CounterDateTime, CounterValue, NTILE(4) OVER(ORDER BY RecordIndex) as Quartile
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName like '%:SQL Statistics' AND CounterName LIKE 'Batch Requests/sec'
				AND CounterValue<>0
		)
	SELECT Quartile, c2.CounterName + ' / ' + c1.CounterName as Comparative,
		AVG(c1.CounterValue*1.0/c2.CounterValue) as avg_ratio, MAX(c1.CounterValue*1.0/c2.CounterValue) as max_ratio, MIN(c1.CounterDateTime) as min_interval, MAX(c1.CounterDateTime) as max_interval
	INTO #Rule_BatchRequests_FreeSpaceScans
	FROM C1
		INNER JOIN C2 on c1.RecordIndex =c2.RecordIndex
	GROUP BY Quartile, c2.CounterName + ' / ' + c1.CounterName
	ORDER BY 1

	--#Rule_BatchRequests_Pagelookups
	;with
		c1
		AS
		(
			SELECT ObjectName, CounterName, c.CounterID, RecordIndex, CounterDateTime, CounterValue
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName like '%:Buffer Manager' AND CounterName LIKE 'Page lookups/sec'
		)
    ,
		c2
		AS
		(
			SELECT ObjectName, CounterName, c.CounterID, RecordIndex, CounterDateTime, CounterValue, NTILE(4) OVER(ORDER BY RecordIndex) as Quartile
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName like '%:SQL Statistics' AND CounterName LIKE 'Batch Requests/sec'
				AND CounterValue<>0
		)
	SELECT
		Quartile, c2.CounterName + ' / ' + c1.CounterName as Comparative,
		AVG(c1.CounterValue*1.0/c2.CounterValue) as avg_ratio, MAX(c1.CounterValue*1.0/c2.CounterValue) as max_ratio, MIN(c1.CounterDateTime) as min_interval, MAX(c1.CounterDateTime) as max_interval
	INTO #Rule_BatchRequests_Pagelookups
	FROM C1
		INNER JOIN C2 on c1.RecordIndex =c2.RecordIndex
	GROUP BY Quartile, c2.CounterName + ' / ' + c1.CounterName
	ORDER BY 1

	--#Rule_Target_Total_Server_Memory
	;with
		c1
		AS
		(
			SELECT ObjectName, CounterName, c.CounterID, RecordIndex, CounterDateTime, CounterValue
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName like '%:Memory Manager' AND CounterName LIKE 'Target Server Memory (KB)'
		)
    ,
		c2
		AS
		(
			SELECT ObjectName, CounterName, c.CounterID, RecordIndex, CounterDateTime, CounterValue, NTILE(4) OVER(ORDER BY RecordIndex) as Quartile
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName like '%:Memory Manager' AND CounterName LIKE 'Total Server Memory (KB)'
		)
	SELECT Quartile, c2.CounterName + ' / ' + c1.CounterName as Comparative,
		AVG(c1.CounterValue-c2.CounterValue)/1024 as avg_ratio, MAX(c1.CounterValue-c2.CounterValue)/1024 as max_ratio, MIN(c1.CounterDateTime) as min_interval, MAX(c1.CounterDateTime) as max_interval
	INTO #Rule_Target_Total_Server_Memory
	FROM C1
		INNER JOIN C2 on c1.RecordIndex =c2.RecordIndex
	GROUP BY Quartile, c2.CounterName + ' / ' + c1.CounterName
	ORDER BY 1

	--#Rule_Logins_Logouts
	;with
		c1
		AS
		(
			SELECT ObjectName, CounterName, c.CounterID, RecordIndex, CounterDateTime, CounterValue
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName like '%:General Statistics' AND CounterName LIKE 'Logins/sec'
		)
    ,
		c2
		AS
		(
			SELECT ObjectName, CounterName, c.CounterID, RecordIndex, CounterDateTime, CounterValue, NTILE(4) OVER(ORDER BY RecordIndex) as Quartile
			FROM CounterData d
				INNER JOIN CounterDetails c on c.CounterID=d.CounterID
			WHERE ObjectName like '%:General Statistics' AND CounterName LIKE 'Logouts/sec'
		)
	SELECT Quartile, c2.CounterName + ' / ' + c1.CounterName as Comparative,
		AVG(c1.CounterValue-c2.CounterValue) as avg_ratio, MAX(c1.CounterValue-c2.CounterValue) as max_ratio, MIN(c1.CounterDateTime) as min_interval, MAX(c1.CounterDateTime) as max_interval
	INTO #Rule_Logins_Logouts
	FROM C1
		INNER JOIN C2 on c1.RecordIndex =c2.RecordIndex
	GROUP BY Quartile, c2.CounterName + ' / ' + c1.CounterName
	ORDER BY 1

	--TC Fix these later.  Only add compilation info if CPU > x %
	-- IF EXISTS (SELECT * FROM #Rule_Compilations_ReCompilations WHERE avg_ratio>.1 or max_ratio>.1 )
	--BEGIN
	--     	INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	-- 	    VALUES('High number of SQL Recompilations.','Performance Metrics','Critical',NULL,NULL,NULL)
	--   END

	--IF EXISTS (SELECT * FROM #Rule_BatchRequests_Compilations WHERE avg_ratio>.1 or max_ratio>.1 )
	--BEGIN
	--     	INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	-- 	    VALUES('High number of SQL compilations.','Performance Metrics','Critical',NULL,NULL,NULL)
	--   END

	IF EXISTS (SELECT *
	FROM #Rule_BatchRequests_FreeSpaceScans
	WHERE avg_ratio>.1 or max_ratio>.1 )
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High number of free space scans exists.', 'Performance Metrics', 'Critical', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM #Rule_BatchRequests_Pagelookups
	WHERE avg_ratio> 10000)
	BEGIN
		DECLARE @AvgLookups DECIMAL(18,3), @AvgLookupsMsg VARCHAR(MAX)

		SELECT @AvgLookups = AVG(CAST(avg_ratio AS NUMERIC))
		FROM #Rule_BatchRequests_Pagelookups

		SET @AvgLookupsMsg = 'The average logical reads per batch on this system is: ' + CAST(FORMAT(@AvgLookups, 'N') AS VARCHAR(30))

		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High number of page lookups/sec exists.', 'Performance Metrics', 'High', NULL, NULL, @AvgLookupsMsg)
	END
	/*
	IF EXISTS (SELECT * FROM #Rule_Target_Total_Server_Memory WHERE avg_ratio>500 or max_ratio>500 )
	BEGIN
      	INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
  	    VALUES('Total server memory is less than target server memory.','Performance Metrics','Critical',NULL,NULL,NULL)
    END
	
	IF EXISTS (SELECT * FROM #Rule_Logins_Logouts WHERE avg_ratio>.1 or max_ratio>.1 )
	BEGIN
      	INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
  	    VALUES('Login rate higher than logout rate.','Performance Metrics','Critical',NULL,NULL,NULL)
    END


	*/

	DECLARE @DrivesLowDiskSpace VARCHAR(500) = ''

	SELECT @DrivesLowDiskSpace = @DrivesLowDiskSpace + Drive + ', '
	FROM
		(
		SELECT Drive = InstanceName, RowNo = ROW_NUMBER() OVER(PARTITION BY InstanceName ORDER BY RecordIndex DESC), CounterValue
		FROM CounterData d
			INNER JOIN CounterDetails c on c.CounterID=d.CounterID
		WHERE ObjectName like 'LogicalDisk'
			AND CounterName = '% Free Space'
	) x
	WHERE RowNo = 1 AND
		CounterValue < 25

	IF @DrivesLowDiskSpace > ''
	BEGIN
		SELECT @DrivesLowDiskSpace = CASE WHEN RIGHT(@DrivesLowDiskSpace,2) = ', ' THEN LEFT(@DrivesLowDiskSpace, (LEN(@DrivesLowDiskSpace)-1)) ELSE @DrivesLowDiskSpace END
		SET @DrivesLowDiskSpace = 'The following drives have less than 25% free space: ' + @DrivesLowDiskSpace + '.'
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		SELECT 'Drives low on disk space.', 'Operational Excellence', 'Critical', NULL, NULL, @DrivesLowDiskSpace

	END
END

IF OBJECT_ID('dbo.cust_Stalled_IO') IS NOT NULL
  BEGIN
	IF EXISTS ( SELECT *
	FROM cust_Stalled_IO )
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Stalled I/O was found.', 'Performance Metrics', 'Critical', NULL, NULL, NULL)
	END
END

IF OBJECT_ID('dbo.CounterData') IS NOT NULL AND OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
BEGIN
	DECLARE @TopLatency DECIMAL(18,3), @TopDrive VARCHAR(20)

	SELECT TOP(1)
		@TopDrive = InstanceName,
		@TopLatency = CAST(AVG(CAST(CounterValue AS DECIMAL(18,3)))AS DECIMAL(18,3))
	FROM
		dbo.CounterData d
		JOIN dbo.CounterDetails dd ON d.CounterID = dd.CounterID
	WHERE 
		dd.countername IN('Avg. Disk sec/Read', 'Avg. Disk sec/Write')
		AND (ObjectName = 'LogicalDisk' OR ObjectName = 'PhysicalDisk')
		AND InstanceName <> '_Total'
	GROUP BY CounterName, InstanceName
	HAVING CAST(AVG(CAST(CounterValue AS DECIMAL(18,3)))AS DECIMAL(18,3))>0.025
	ORDER BY 2 DESC

	IF @TopLatency > 0
	BEGIN
		DECLARE @LatencyMsg VARCHAR(MAX)
		SET @LatencyMsg = 'The top disk latency is: ' + CAST(@TopLatency AS VARCHAR(15)) + '(ms) on drive: ' + @TopDrive

		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Disk response times are too long.', 'Performance Metrics', 'Critical', NULL, NULL, @LatencyMsg)
	END
END

IF OBJECT_ID('dbo.cust_Plan_use_ratio') IS NOT NULL
  BEGIN
	IF EXISTS 
	( 
	    SELECT *
	FROM cust_Plan_use_ratio s
		INNER HASH JOIN cust_Plan_use_ratio m on s.objtype=m.objtype and s.avg_usecount_perplan=1 and m.avg_usecount_perplan<>1
	WHERE 
		(ISNUMERIC(s.allrefobjects) = 1 AND
		s.Avg_UseCount_perPlan > 0 
		)AND
		convert(numeric,s.allrefobjects)>convert(numeric,m.allrefobjects) 
	  )
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High number of single use plans in plan cache.', 'Performance Metrics', 'Critical', NULL, NULL, NULL)
	END
END


IF OBJECT_ID('dbo.CounterData') IS NOT NULL AND OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
  BEGIN
	IF EXISTS ( 
       SELECT *
	FROM CounterData d
		INNER JOIN CounterDetails c on c.CounterID=d.CounterID
	WHERE ObjectName like '%:Locks'
		AND CounterName LIKE 'Number of Deadlocks/sec'
		AND CounterValue>0
	)
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Deadlocking issues have been identified.', 'Performance Metrics', 'Critical', NULL, NULL, NULL)
	END
END


IF OBJECT_ID('dbo.tbl_requests') IS NOT NULL AND OBJECT_ID('dbo.tbl_NOTABLEACTIVEQUERIES') IS NOT NULL 
  BEGIN
	IF OBJECT_ID('tempdb..#Rule_Blocking') IS NOT NULL
    DROP TABLE #Rule_Blocking

	;
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
	INTO #Rule_Blocking
	FROM blocker
	ORDER BY lvl, session_id
	option(maxrecursion
	3000)

	IF EXISTS (SELECT *
	FROM #Rule_Blocking) 
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Blocking issues have been identified.', 'Performance Metrics', 'Critical', NULL, NULL, NULL)
	END
	ELSE IF OBJECT_ID('') IS NOT NULL
	BEGIN
		IF EXISTS(SELECT *
		FROM dbo.tbl_BlockingXeOutput)
		BEGIN
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('Blocking issues have been identified.', 'Performance Metrics', 'Critical', NULL, NULL, NULL)
		END
	END

END

IF OBJECT_ID('dbo.cust_ActiveTraceFlagsAnalysis') IS NOT NULL and OBJECT_ID('dbo.cust_ActiveTraceFlagsAnalysis') IS NOT NULL
  BEGIN
	IF EXISTS (SELECT *
	FROM cust_ActiveTraceFlagsAnalysis
	WHERE Deviation LIKE '%Consider enabling TF2335%')
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Trace Flag 2335 is not set on a SQL Server with a Max Server Memory setting of 100GB or more.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM cust_ActiveTraceFlagsAnalysis
	WHERE Deviation LIKE '%Consider enabling TF4199%')
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Trace Flag 4199 is not set on SQL Server to control multiple query optimizer changes.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM cust_ActiveTraceFlagsAnalysis
	WHERE Deviation LIKE '%Consider enabling TF8048%')
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Trace Flag 8048 is not set on a SQL Server with 8 processors or more per NUMA node.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM cust_ActiveTraceFlagsAnalysis
	WHERE Deviation LIKE '%Consider enabling TF2371%')
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Trace Flag 2371 is not set on SQL Server to fine tune AUTOSTATS threshold.  (this should include only really large tables)', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

END

IF OBJECT_ID('dbo.tbl_SPCONFIGURE') IS NOT NULL
  BEGIN

	IF OBJECT_ID('tempdb..#ConfigDefaults') IS NOT NULL
    DROP TABLE #ConfigDefaults

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
			SELECT 'Database Mail XPs '	, 0
		UNION ALL
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
			SELECT 'max server memory (MB)'	, 2147483647
		UNION ALL
			SELECT 'max text repl size'	, 65536
		UNION ALL
			SELECT 'max worker threads '	, 0
		UNION ALL
			SELECT 'media retention '	, 0
		UNION ALL
			SELECT 'min memory per query (KB)'	, 1024
		UNION ALL
			SELECT 'min server memory (MB)'	, 0
		UNION ALL
			SELECT 'nested triggers'	, 1
		UNION ALL
			SELECT 'network packet size (B)'	, 4096
		UNION ALL
			SELECT 'Ole Automation Procedures '	, 0
		UNION ALL
			SELECT 'open objects'	, 0
		UNION ALL
			SELECT 'optimize for ad hoc workloads '	, 0
		UNION ALL
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
			SELECT 'remote query timeout (s)'	, 0
		UNION ALL
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

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='Ole Automation Procedures' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, Ole Automation Procedures, has been changed from the default value.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='max worker threads' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, max worker threads, has been changed from the default value.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='query wait (s)' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, query wait (s), has been changed from the default value.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='Ad Hoc Distributed Queries' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, Ad Hoc Distributed Queries, has been changed from the default value.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='priority boost' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, priority boost, has been changed from the default value.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='remote query timeout' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, remote query timeout, has been changed from the default value.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value = DefaultValue and d.ConfigValue='cost threshold for parallelism' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, cost threshold for parallelism, has NOT been changed from the default value of 5.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END


	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value = DefaultValue and d.ConfigValue='optimize for ad hoc workloads' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, optimize for ad-hoc workloads, has NOT been changed from the default value of 0.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='cross db ownership chaining' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, cross db ownership chaining, has been changed from the default value.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='default trace enabled' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, default trace enabled, has been changed from the default value.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='min memory per query' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, min memory per query, has been changed from the default value.', 'SQL Configuration', 'Medium', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='blocked process threshold (s)' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, blocked process threshold (s), has been changed from the default value.', 'SQL Configuration', 'Medium', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='recovery interval (min)' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, recovery interval (min), has been changed from the default value.', 'SQL Configuration', 'Critical', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='network packet size (B)' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, network packet size (B), has been changed from the default value.', 'SQL Configuration', 'Critical', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='index create memory (KB)' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, index create memory (KB), has been changed from the default value.', 'SQL Configuration', 'Critical', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='locks' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, locks, has been changed from the default value.', 'SQL Configuration', 'Critical', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='lightweight pooling' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, lightweight pooling, has been changed from the default value.', 'SQL Configuration', 'Critical', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value = DefaultValue and d.ConfigValue='Optimize for Ad-hoc workloads' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, Optimize for Ad-hoc workloads, has NOT been changed from the default value.', 'SQL Configuration', 'Medium', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value = DefaultValue and d.ConfigValue='remote admin connections' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, remote admin connections, has NOT been changed from the default value.', 'SQL Configuration', 'Medium', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value = DefaultValue and d.ConfigValue='backup compression' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, backup compression, has NOT been changed from the default value.', 'SQL Configuration', 'Medium', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value <> DefaultValue and d.ConfigValue='xp_cmdshell' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server Configuration setting, xp_cmdshell, is enabled.', 'SQL Configuration', 'High', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value = DefaultValue and d.ConfigValue='max server memory' )
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, max server memory, has not been set.', 'SQL Configuration', 'Critical', NULL, NULL, NULL)
	END

	IF EXISTS (SELECT *
	FROM tbl_SPCONFIGURE c JOIN #ConfigDefaults d ON c.name = d.ConfigValue
	WHERE  run_value = DefaultValue and d.ConfigValue='min server memory')
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting, min server memory, has not been set on a clustered instance or VM.', 'SQL Configuration', 'Critical', NULL, NULL, NULL)
	END

	IF OBJECT_ID('cust_MemoryGrants') IS NOT NULL
	BEGIN
		IF EXISTS 
		(
			SELECT *
		FROM
			(
				SELECT *, gm = TRY_CONVERT(BIGINT, granted_memory_kb)
			FROM dbo.cust_MemoryGrants
			WHERE ISDATE(Runtime) = 1 
			) x
		WHERE gm/1024.0 > 1024
		)
		BEGIN
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('There are a number of query execution memory grants larger than 1GB.', 'Performance Metrics', 'Critical', NULL, NULL, NULL)
		END
	END
END

IF OBJECT_ID('dbo.cust_Parallelism_MaxDOP') IS NOT NULL
  BEGIN
	IF EXISTS (SELECT *
	FROM cust_Parallelism_MaxDOP
	WHERE Deviation NOT LIKE '[[]OK]')
    BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The SQL Server configuration setting: Max Degree of Parallelism is set to non-optimal value.', 'SQL Configuration', 'Critical', NULL, NULL, NULL)
	END
END

IF OBJECT_ID('cust_ErrorLog') IS NOT NULL
  BEGIN
	IF OBJECT_ID('cust_ErrorLogAnalysis') IS NOT NULL
    DROP TABLE cust_ErrorLogAnalysis

	;
	WITH
		cte_error_raw
		AS
		
		(
			SELECT
				ErrorDate as logdate,
				ErrorMessage
			FROM cust_ErrorLog
			where ErrorDate IS NOT NULL AND
				ErrorMessage NOT LIKE '%BACKUP DATABASE successfully processed%' AND
				ErrorMessage NOT LIKE '%Backup Log was backed up.%' AND
				ErrorMessage NOT LIKE 'Backup Database backed up.%No user action is required'
		),
		cte_dbcc (err, errcnt, logdate, ErrorMessage)
		AS
		(
			SELECT CASE WHEN ErrorMessage LIKE 'Error: %' THEN RIGHT(LEFT(cte_error_raw.ErrorMessage, CHARINDEX(',', cte_error_raw.ErrorMessage)-1), CHARINDEX(',', cte_error_raw.ErrorMessage)-8) 
				WHEN ErrorMessage LIKE 'SQL Server has encountered % longer than 15 seconds %' THEN CONVERT(CHAR(3),833)
				WHEN ErrorMessage LIKE 'A significant part of sql server process memory has been paged out%' THEN CONVERT(CHAR(5),17890)
				WHEN ErrorMessage LIKE 'The SQL Server Network Interface library could not register the Service Principal Name%' THEN CONVERT(CHAR(5),26037)
				ELSE '' END AS err,
				COUNT(ErrorMessage) AS errcnt,
				logdate,
				CASE WHEN ErrorMessage LIKE 'SQL Server has encountered % longer than 15 seconds %' THEN 'SQL Server has encountered XXX occurrence(s) of IO requests taking longer than 15 seconds to complete on file YYY'
				WHEN ErrorMessage LIKE 'A significant part of sql server process memory has been paged out%' THEN 'A significant part of sql server process memory has been paged out.'
				ELSE ErrorMessage END AS ErrorMessage
			FROM cte_error_raw
			GROUP BY ErrorMessage, logdate
		)
	SELECT 'Maintenance_Monitoring_checks' AS [Category], 'Errorlog_Summary' AS [Information],
		err AS [Error_Number],
		SUM(errcnt) AS Error_Count,
		MIN(logdate) AS [First_Logged_Date],
		MAX(logdate) AS [Last_Logged_Date],
		ErrorMessage AS [Logged_Message],
		CASE WHEN ErrorMessage LIKE 'Error: 825%' THEN 'IO transient failure. Possible corruption'
			WHEN ErrorMessage LIKE 'Error: 833%' OR ErrorMessage LIKE 'SQL Server has encountered % longer than 15 seconds %' THEN 'Long IO detected: http://support.microsoft.com/kb/897284'
			WHEN ErrorMessage LIKE 'Error: 855%' OR ErrorMessage LIKE 'Error: 856%' THEN 'Hardware memory corruption'
			WHEN ErrorMessage LIKE 'Error: 3452%' THEN 'Metadata inconsistency in DB. Run DBCC CHECKIDENT'
			WHEN ErrorMessage LIKE 'Error: 3619%' THEN 'Chkpoint failed. No Log space available'
			WHEN ErrorMessage LIKE 'Error: 9002%' THEN 'No Log space available'
			WHEN ErrorMessage LIKE 'Error: 17204%' OR ErrorMessage LIKE 'Error: 17207%' THEN 'Error opening file during startup process'
			WHEN ErrorMessage LIKE 'Error: 17179%' THEN 'No AWE - LPIM related'
			WHEN ErrorMessage LIKE 'Error: 17890%' THEN 'sqlservr process paged out'
			WHEN ErrorMessage LIKE 'Error: 2508%' THEN 'Catalog views inaccuracies in DB. Run DBCC UPDATEUSAGE'
			WHEN ErrorMessage LIKE 'Error: 2511%' THEN 'Index Keys errors'
			WHEN ErrorMessage LIKE 'Error: 3271%' THEN 'IO nonrecoverable error'
			WHEN ErrorMessage LIKE 'Error: 5228%' OR ErrorMessage LIKE 'Error: 5229%' THEN 'Online Index operation errors'
			WHEN ErrorMessage LIKE 'Error: 5242%' THEN 'Page structural inconsistency'
			WHEN ErrorMessage LIKE 'Error: 5243%' THEN 'In-memory structural inconsistency'
			WHEN ErrorMessage LIKE 'Error: 5250%' THEN 'Corrupt page. Error cannot be fixed'
			WHEN ErrorMessage LIKE 'Error: 5901%' THEN 'Chkpoint failed. Possible corruption'
			WHEN ErrorMessage LIKE 'Error: 17130%' THEN 'No lock memory'
			WHEN ErrorMessage LIKE 'Error: 17300%' THEN 'Unable to run new system task'
			WHEN ErrorMessage LIKE 'Error: 802%' THEN 'No BP memory'
			WHEN ErrorMessage LIKE 'Error: 845%' OR ErrorMessage LIKE 'Error: 1105%' OR ErrorMessage LIKE 'Error: 1121%' THEN 'No disk space available'
			WHEN ErrorMessage LIKE 'Error: 1214%' THEN 'Internal parallelism error'
			WHEN ErrorMessage LIKE 'Error: 823%' OR ErrorMessage LIKE 'Error: 824%' THEN 'IO failure. Possible corruption'
			WHEN ErrorMessage LIKE 'Error: 832%' THEN 'Page checksum error. Possible corruption'
			WHEN ErrorMessage LIKE 'Error: 3624%' OR ErrorMessage LIKE 'Error: 17065%' OR ErrorMessage LIKE 'Error: 17066%' OR ErrorMessage LIKE 'Error: 17067%' THEN 'System assertion check failed. Possible corruption'
			WHEN ErrorMessage LIKE 'Error: 5572%' THEN 'Possible FILESTREAM corruption'
			WHEN ErrorMessage LIKE 'Error: 9100%' THEN 'Possible index corruption'
			-- How To Diagnose and Correct Errors 17883, 17884, 17887, and 17888 (http://technet.microsoft.com/en-us/library/cc917684.aspx)
			WHEN ErrorMessage LIKE 'Error: 17883%' THEN 'Non-yielding scheduler: http://technet.microsoft.com/en-us/library/cc917684.aspx'
			WHEN ErrorMessage LIKE 'Error: 17884%' OR ErrorMessage LIKE 'Error: 17888%' THEN 'Deadlocked scheduler: http://technet.microsoft.com/en-us/library/cc917684.aspx'
			WHEN ErrorMessage LIKE 'Error: 17887%' THEN 'IO completion error: http://technet.microsoft.com/en-us/library/cc917684.aspx'
			WHEN ErrorMessage LIKE 'Error: 1205%' THEN 'Deadlocked transaction'
			WHEN ErrorMessage LIKE 'Error: 610%' THEN 'Page header invalid. Possible corruption'
			WHEN ErrorMessage LIKE 'Error: 8621%' THEN 'QP stack overflow during optimization. Please simplify the query'
			WHEN ErrorMessage LIKE 'Error: 8642%' THEN 'QP insufficient threads for parallelism'
			WHEN ErrorMessage LIKE 'Error: 701%' THEN 'Insufficient memory'
			-- How to troubleshoot SQL Server error 8645 (http://support.microsoft.com/kb/309256)
			WHEN ErrorMessage LIKE 'Error: 8645%' THEN 'Insufficient memory: http://support.microsoft.com/kb/309256'
			WHEN ErrorMessage LIKE 'Error: 605%' THEN 'Page retrieval failed. Possible corruption'
			-- How to troubleshoot Msg 5180 (http://support.microsoft.com/kb/2015747)
			WHEN ErrorMessage LIKE 'Error: 5180%' THEN 'Invalid file ID. Possible corruption: http://support.microsoft.com/kb/2015747'
			WHEN ErrorMessage LIKE 'Error: 8966%' THEN 'Unable to read and latch on a PFS or GAM page'
			WHEN ErrorMessage LIKE 'Error: 9001%' OR ErrorMessage LIKE 'Error: 9002%' THEN 'Transaction log errors.'
			WHEN ErrorMessage LIKE 'Error: 9003%' OR ErrorMessage LIKE 'Error: 9004%' OR ErrorMessage LIKE 'Error: 9015%' THEN 'Transaction log errors. Possible corruption'
			-- How to reduce paging of buffer pool memory in the 64-bit version of SQL Server (http://support.microsoft.com/kb/918483)
			WHEN ErrorMessage LIKE 'A significant part of sql server process memory has been paged out%' THEN 'SQL Server process was trimmed by the OS. Preventable if LPIM is granted'
			WHEN ErrorMessage LIKE '%cachestore flush%' THEN 'CacheStore flush'
			WHEN ErrorMessage LIKE 'The SQL Server Network Interface library could not register the Service Principal Name%' THEN 'SPN'
		ELSE '' END AS [Comment],
		CASE WHEN ErrorMessage LIKE 'Error: %' THEN (SELECT REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(text,'%.*ls','%'),'%d','%'),'%ls','%'),'%S_MSG','%'),'%S_PGID','%'),'%#016I64x','%'),'%p','%'),'%08x','%'),'%u','%'),'%I64d','%'),'%s','%'),'%ld','%'),'%lx','%'), '%%%', '%')
		FROM sys.messages
		WHERE message_id = (CONVERT(int, RIGHT(LEFT(cte_dbcc.ErrorMessage, CHARINDEX(',', cte_dbcc.ErrorMessage)-1), CHARINDEX(',', cte_dbcc.ErrorMessage)-8))) AND language_id = (SELECT lcid
			FROM sys.syslanguages
			WHERE name = @@LANGUAGE)) 
			ELSE '' END AS [Look_for_Message_example]
	INTO cust_ErrorLogAnalysis
	FROM cte_dbcc
	GROUP BY err, ErrorMessage
	--ORDER BY SUM(errcnt) DESC;


	IF OBJECT_ID('dbo.cust_ErrorLogAnalysis') IS NOT NULL
    BEGIN
		IF EXISTS (SELECT *
		FROM cust_ErrorLogAnalysis
		WHERE Logged_Message LIKE '%longer than 15 seconds%')
      BEGIN
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('I/O taking longer than 15 seconds.', 'SQL Errors', 'Critical', NULL, NULL, NULL)
		END
	END

	IF OBJECT_ID('dbo.cust_ErrorLogAnalysis') IS NOT NULL
    BEGIN
		IF EXISTS (SELECT *
		FROM cust_ErrorLogAnalysis
		WHERE Logged_Message LIKE '%Failed Virtual Allocate%')
      BEGIN
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('Failed Virtual Allocate.', 'SQL Errors', 'Critical', NULL, NULL, NULL)
		END
	END



	IF OBJECT_ID('dbo.cust_ErrorLogAnalysis') IS NOT NULL
    BEGIN
		IF EXISTS (SELECT *
		FROM cust_ErrorLogAnalysis
		WHERE Logged_Message LIKE '%A significant part of SQL server process memory has been paged out%')
      BEGIN
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('A significant part of SQL server process memory has been paged out.', 'SQL Errors', 'Critical', NULL, NULL, NULL)
		END
	END

	IF OBJECT_ID('dbo.cust_ErrorLogAnalysis') IS NOT NULL
    BEGIN
		IF EXISTS (SELECT *
		FROM cust_ErrorLogAnalysis
		WHERE Logged_Message LIKE '%The SQL Network Interface library could not register the Service Principal Name%')
      BEGIN
			INSERT INTO PTOClinicFindings
				([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
			VALUES('The SQL Network Interface library could not register the Service Principal Name (SPN) for the SQL Server service.', 'SQL Errors', 'Medium', NULL, NULL, NULL)

		END
	END
END

IF OBJECT_ID('dbo.cust_PendingIOs') IS NOT NULL
    BEGIN
	IF EXISTS (SELECT *
	FROM cust_PendingIOs
	WHERE io_type LIKE 'disk' AND io_pending = 1
		AND CAST(io_pending_ms_ticks AS BIGINT) > 10)
      BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('There are a high number of outstanding SQL Server IOs.', 'SQL Errors', 'Critical', NULL, NULL, NULL)
	END
END
--END
--END
IF OBJECT_ID('cust_DBFileSizes') IS NOT NULL and @ServerType = 'OnPremisesSQL'
	BEGIN
	DECLARE @DBNames VARCHAR(MAX) = '', @Msg VARCHAR(MAX)

	SELECT @DBNames = @DBNames + DBName + ', '
	FROM
		(
			SELECT DBName, SizeInMB, RowCnt = COUNT(*)
		FROM [dbo].[cust_DBFileSizes]
		WHERE FilePath NOT LIKE '%ldf'
		GROUP BY DBName, SizeInMB
			)a
	GROUP BY DBName
	HAVING COUNT(*) > 1

	IF @DBNames > ''
		BEGIN
		SELECT @DBnames = CASE WHEN RIGHT(@DBNames,2) = ', ' THEN LEFT(@DBNames, (LEN(@DBNames)-1)) ELSE @DBNames END
		SET @Msg = 'Databases ' + @DBNames + ' have multiple different sized database files.'

		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('Databases with different sized data files.', 'SQL Errors', 'Medium', NULL, NULL, @Msg)
	END
END

IF OBJECT_ID('tempdb..#ProcessData') IS NOT NULL
	DROP TABLE #ProcessData

CREATE TABLE #ProcessData
(
	InstanceName VARCHAR(1000),
	AvgDataBytes DECIMAL,
	MaxDataBytes DECIMAL,
	DataBytesPercentage DECIMAL
)

INSERT INTO #ProcessData
EXECUTE GetProcessInfo

DECLARE @TopProcess VARCHAR(1000)

IF @@ROWCOUNT > 0
	BEGIN
	SET @TopProcess = (
			SELECT TOP(1)
		InstanceName
	FROM #ProcessData
	ORDER BY DataBytesPercentage DESC
		)

	IF @TopProcess NOT LIKE '%sqlservr%'
		BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('The top data driven process on the server is not SQL Server.', 'Performance Metrics', 'Critical', NULL, NULL, NULL)

	END

	IF EXISTS(
			SELECT *
	FROM #ProcessData
	WHERE InstanceName LIKE '%sqlservr%' AND
		DataBytesPercentage < 50
		)
		BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('SQL Server is not driving very much IO on this server.', 'Performance Metrics', 'Critical', NULL, NULL, NULL)
	END
END



/* Tim Chapman
High # of trivial plans vs optimizations overall.
*/

IF OBJECT_ID('cust_OptimizerInfo') IS NOT NULL
BEGIN
	--DECLARE @TrivialPlanCount INT

	--BEGIN TRY
	--	SELECT
	--	@TrivialPlanCount = 100*((
	--	SELECT TrivialPlanCount = CAST(occurrence AS BIGINT) * 1.00
	--	FROM [dbo].[cust_OptimizerInfo]
	--	WHERE counter = 'trivial plan'
	--	) /
	--	(
	--	SELECT TotalOptimizations = CAST(occurrence AS BIGINT)
	--	FROM [dbo].[cust_OptimizerInfo]
	--	WHERE counter = 'optimizations'
	--	))
	--END TRY
	--BEGIN CATCH
	--END CATCH

	--IF @TrivialPlanCount > 10
	--BEGIN
	--	INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	-- 		VALUES('High Trivial Plan Percentage.','Performance Metrics','Critical',NULL,NULL,'Total percentage of trivial plans: ' + CAST(@TrivialPlanCount AS VARCHAR(20)))
	--END


	/* Tim Chapman
	High average final cost.  > 200
	*/
	DECLARE @HighQueryCost VARCHAR(300)

	SELECT @HighQueryCost = CAST(value AS DECIMAL(18,2))
	FROM [dbo].[cust_OptimizerInfo]
	WHERE counter = 'final cost'

	IF CAST(@HighQueryCost AS DECIMAL(18,2)) > 200
	BEGIN
		SET @HighQueryCost = 'The average query cost for the system is ' + @HighQueryCost + '.'
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High Avg Query Final Cost.', 'Performance Metrics', 'Critical', NULL, NULL, @HighQueryCost)
	END

	/* Tim Chapman
	High number of tables per query.
	*/
	IF EXISTS
	(
		SELECT CAST(occurrence AS BIGINT), CAST(VALUE AS DECIMAL(13,2))
	FROM [dbo].[cust_OptimizerInfo]
	WHERE counter = 'tables' AND
		CAST(VALUE AS DECIMAL(13,2)) >= 5
	)
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High Avg Tables in each query.', 'Performance Metrics', 'Critical', NULL, NULL, NULL)
	END


	/* Tim Chapman
	High number of join hints.
	*/
	DECLARE @JoinHints INT

	SELECT @JoinHints = CAST(occurrence AS BIGINT)
	FROM [dbo].[cust_OptimizerInfo]
	WHERE counter = 'join hint'
		AND CAST(occurrence AS BIGINT) > 50

	IF @JoinHints > 0
	BEGIN
		DECLARE @HintsMsg VARCHAR(MAX)
		SET @HintsMsg = 'The number of join hints compiled since the last restart: ' + CAST(@JoinHints AS VARCHAR(10))
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High number of join hints used.', 'Performance Metrics', 'Medium', NULL, NULL, @HintsMsg)
	END
	/* Tim Chapman
	High number of remote queries.
	*/
	DECLARE @RemoteQueries VARCHAR(500)
	SELECT @RemoteQueries = CAST(occurrence AS BIGINT)
	FROM [dbo].[cust_OptimizerInfo]
	WHERE counter = 'remote query'

	IF @RemoteQueries > 10000
	BEGIN
		SET @RemoteQueries = 'There have been ' + @RemoteQueries + ' remote queries executed on the system since last restart.'
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High number of remote queries executed.', 'Performance Metrics', 'Critical', NULL, NULL, @RemoteQueries)
	END
	/* Tim Chapman
	High amount of cursor usage.
	*/
	DECLARE @CursorCount VARCHAR(200)
	SELECT @CursorCount = SUM(CAST(occurrence AS BIGINT))
	FROM [dbo].[cust_OptimizerInfo]
	WHERE counter LIKE '%cursor%'

	IF CAST(@CursorCount AS BIGINT) > 300
	BEGIN
		SET @CursorCount = 'Total Cursor Count: ' + @CursorCount
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		VALUES('High amount of cursor usage.', 'Performance Metrics', 'Critical', NULL, NULL, @CursorCount)
	END

END

IF OBJECT_ID('CounterData') IS NOT NULL AND
	OBJECT_ID('CounterDetails') IS NOT NULL
BEGIN
	DECLARE @BCHRatio VARCHAR(500)

	SELECT @BCHRatio = AVG(CounterValue)
	FROM CounterData d
		INNER JOIN CounterDetails c on c.CounterID=d.CounterID
	WHERE ObjectName like '%:Buffer Manager'
		AND CounterName LIKE 'Buffer cache hit ratio'

	IF CAST(@BCHRatio AS DECIMAL(18,2))< 90.00
	BEGIN
		SET @BCHRatio = 'The average Buffer Cache Hit Ratio is: ' + CAST(CAST(@BCHRatio AS DECIMAL(18,2)) AS VARCHAR(20)) + '.'

		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		SELECT 'Low Buffer Cache Hit Ratio.', 'Performance Metrics', 'Critical', NULL, NULL, @BCHRatio

	END

END


IF OBJECT_ID('tbl_PowerPlan') IS NOT NULL AND @ServerType = 'OnPremisesSQL'
BEGIN
	IF EXISTS(SELECT 1
	FROM tbl_PowerPlan
	WHERE ActivePlanName = 'Balanced')
INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	SELECT 'The Windows OS power saving setting may affect the CPU Performance.', 'Performance Metrics', 'Critical', NULL, NULL, NULL
END


IF OBJECT_ID('cust_DBFileSizes') IS NOT NULL AND @ServerType = 'OnPremisesSQL'
BEGIN


	DECLARE @DatabasesOnCDrive VARCHAR(2000) = ''
	SELECT DISTINCT @DatabasesOnCDrive = @DatabasesOnCDrive + DBName + ', '
	FROM dbo.cust_DBFileSizes
	WHERE FilePath LIKE 'C%'

	IF @DatabasesOnCDrive > ''
	BEGIN
		SELECT @DatabasesOnCDrive = CASE WHEN RIGHT(@DatabasesOnCDrive,2) = ', ' THEN LEFT(@DatabasesOnCDrive, (LEN(@DatabasesOnCDrive)-1)) ELSE @DatabasesOnCDrive END
		SET @DatabasesOnCDrive = 'The following database(s) have files on the C drive: ' + @DatabasesOnCDrive + '.'
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		SELECT 'Databases with files on the C drive.', 'Operational Excellence', 'Critical', NULL, NULL, @DatabasesOnCDrive

	END
END


IF OBJECT_ID('cust_Spinlocks') IS NOT NULL
BEGIN
	DECLARE @BigSpins VARCHAR(2000) = ''

	SELECT @BigSpins = @BigSpins + name + ', '
	FROM (
		SELECT *,
			SpinPercent = CAST((100.0 * CAST(spins AS BIGINT)/SUM(CAST(spins AS BIGINT)) OVER()) AS DECIMAL(18,2))
		FROM cust_Spinlocks
		) x
	WHERE SpinPercent > 60

	IF @BigSpins > ''
	BEGIN
		SELECT @BigSpins = CASE WHEN RIGHT(@BigSpins,2) = ', ' THEN LEFT(@BigSpins, (LEN(@BigSpins)-1)) ELSE @BigSpins END
		SET @BigSpins = 'The following spinlock is taking up greater than 60%: ' + @BigSpins + '.'
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		SELECT 'High spinlock count.', 'Performance Metrics', 'Critical', NULL, NULL, @BigSpins

	END

END



IF OBJECT_ID('tempdb..#NetworkData') IS NOT NULL
DROP TABLE #NetworkData

CREATE TABLE #NetworkData
(
	CounterName VARCHAR(255),
	CounterAvg DECIMAL(18,2),
	AvgPercentOfCapacity DECIMAL(18,2),
	MaxPercentOfCapacity DECIMAL(18,2),
	MaxNeworkBandwidth BIGINT
)
INSERT INTO #NetworkData
EXECUTE GetNetworkData

IF EXISTS
(
	SELECT *
FROM #NetworkData
WHERE AvgPercentOfCapacity > 20
)
BEGIN
	INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	SELECT 'High network utilization.', 'Operational Excellence', 'Critical', NULL, NULL, 'Network utilization is over 20%'
END



IF OBJECT_ID('tempdb..#LockData') IS NOT NULL
DROP TABLE #LockData

CREATE TABLE #LockData
(
	ObjectName VARCHAR(255),
	CounterName VARCHAR(255),
	CounterAvg DECIMAL(18,2),
	CounterMin DECIMAL(18,2),
	CounterMax DECIMAL(18,2)
)
INSERT INTO #LockData
EXECUTE GetLockInfo

DECLARE @LockWaitsSec DECIMAL(18,3)

SELECT @LockWaitsSec = CounterAvg
FROM #LockData
WHERE CounterName = 'Lock Waits/sec' AND CounterAvg > 50

IF @LockWaitsSec > 0
BEGIN
	DECLARE @LockWaitsMsg VARCHAR(MAX)
	SET @LockWaitsMsg = 'The average lock waits/sec on this system is: ' + CAST(@LockWaitsSec AS VARCHAR(30))

	INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	SELECT 'High Locks Waits/sec.', 'Performance Metrics', 'Critical', NULL, NULL, @LockWaitsMsg
END

DECLARE @AvgLockWaitTime DECIMAL(18,3)

SELECT @AvgLockWaitTime = CounterAvg
FROM #LockData
WHERE CounterName = 'Average Wait Time (ms)' AND CounterMax > 500

IF @AvgLockWaitTime > 0
BEGIN
	DECLARE @AvgLockWaitMsg VARCHAR(MAX)
	SET @AvgLockWaitMsg = 'The average lock wait time (ms) on this system is: ' + CAST(@AvgLockWaitTime AS VARCHAR(30))
	INSERT INTO PTOClinicFindings
		([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
	SELECT 'High Avg Lock Wait Time.', 'Performance Metrics', 'Critical', NULL, NULL, @AvgLockWaitMsg
END


--IF EXISTS
--(
--SELECT * FROM #LockData
--WHERE CounterName = 'Lock Requests/sec' AND CounterAvg > 1000
--)
--BEGIN
--	INSERT INTO PTOClinicFindings ([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
--	SELECT 'High Lock Requests/sec.','Performance Metrics','Critical',NULL,NULL,NULL
--END


IF OBJECT_ID('tbl_SPCONFIGURE') IS NOT NULL 
BEGIN
	IF EXISTS
(
	SELECT *
	FROM tbl_SPCONFIGURE
	WHERE name LIKE '%optimize%' AND
		run_value = 0
) 
BEGIN
		DECLARE @HighAdhocPlans BIT = 0

		IF OBJECT_ID('cust_PlanCacheStats') IS NOT NULL AND
			OBJECT_ID('cust_MemoryClerks') IS NOT NULL
	BEGIN
			IF EXISTS
		( 
		SELECT *
			FROM
				(
			SELECT *,
					DENSE_RANK() OVER(ORDER BY runtime ASC) AS RowNo,
					ROW_NUMBER() OVER(PARTITION BY runtime ORDER BY runtime ASC) AS InnerRowNo,
					100.0 * CAST(entry_count AS BIGINT) / SUM (CAST(entry_count AS BIGINT)) OVER(PARTITION BY runtime) AS [EntryPercentage],
					100.0 * CAST(cache_size_mb AS DECIMAL) / SUM (CAST(cache_size_mb AS DECIMAL)) OVER(PARTITION BY runtime) AS [SizePercentage]
				FROM
					(
				SELECT
						runtime, objtype, cache_size_mb = sum(cast(cache_size_mb AS DECIMAL)), entry_count = sum(cast(entry_count AS BIGINT))
					FROM [dbo].[cust_PlanCacheStats]
					WHERE ISNUMERIC(cache_size_mb) = 1
					GROUP BY runtime, objtype

			) x
		) y
			WHERE
			InnerRowNo = 1 AND
				objtype = 'Adhoc' AND
				(EntryPercentage > 50 OR SizePercentage > 50)
		)
		SET @HighAdhocPlans = @HighAdhocPlans | 1

			IF EXISTS
		(

			SELECT *
			FROM (
				SELECT
					MemPercentage = 100.0 * (CAST(Pages_KB AS BIGINT)) / SUM (CAST(Pages_KB AS BIGINT)) OVER(),
					Rnk = ROW_NUMBER() OVER(ORDER BY CAST(Pages_KB AS BIGINT) DESC),
					*
				FROM [dbo].[cust_MemoryClerks]
			)x
			WHERE Rnk = 1 AND
				MemPercentage > 50 AND
				type = 'CACHESTORE_SQLCP'
		)
		SET @HighAdhocPlans = @HighAdhocPlans | 1
		END

	END

	IF @HighAdhocPlans = 1
BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		SELECT 'Optimize for ad-hoc workloads is wasting memory.', 'Performance Metrics', 'Critical', NULL, NULL, NULL

	END
END


IF OBJECT_ID('cust_MemoryClerks') IS NOT NULL
BEGIN
	IF EXISTS
	(

		SELECT type, SUM(MemPercentage)
	FROM (
			SELECT
			MemPercentage = 100.0 * (CAST(Pages_KB AS BIGINT)) / SUM (CAST(Pages_KB AS BIGINT)) OVER(),
			Rnk = ROW_NUMBER() OVER(ORDER BY CAST(Pages_KB AS BIGINT) DESC),
			*
		FROM [dbo].[cust_MemoryClerks]
		)x
	WHERE 
		type = 'MEMORYCLERK_SQLBUFFERPOOL' AND
		memory_node_id <> 64
	GROUP BY type
	--group in case of >1 NUMA nodes
	HAVING SUM(MemPercentage) < 75
	)
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		SELECT 'Other memory consumers are competing with the Buffer Pool for Memory.', 'Performance Metrics', 'Critical', NULL, NULL, NULL

	END
END


--param sniffing
IF 
	OBJECT_ID('tbl_query_store_runtime_stats') IS NOT NULL AND
	OBJECT_ID('tbl_query_store_plan') IS NOT NULL AND
	OBJECT_ID('tbl_query_store_query') IS NOT NULL AND
	OBJECT_ID('tbl_query_store_query_text') IS NOT NULL 
	BEGIN

	IF EXISTS
	(
		SELECT *
	FROM
		tbl_query_store_runtime_stats q
		join tbl_query_store_plan p on q.dbid = p.dbid and q.plan_id = p.plan_id
		join tbl_query_store_query qq on p.dbid = qq.dbid and p.query_id = qq.query_id
		join tbl_query_store_query_text qt on qt.dbid = qq.dbid and qt.query_text_id = qq.query_text_id
	WHERE 
			query_sql_text like '%@%' AND
		CAST(max_logical_io_reads AS FLOAT) > 10000 AND
		((CAST(max_logical_io_reads AS FLOAT) - CAST(min_logical_io_reads AS FLOAT) )/CAST(max_logical_io_reads AS FLOAT)) *100.00 > 50
	)
	BEGIN
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		SELECT 'There are queries executed that may be sensitive to the parameters passed in.', 'Performance Metrics', 'Critical', NULL, NULL, NULL


	END
END

IF OBJECT_ID('tbl_PlanCache_Stats') IS NOT NULL
BEGIN
	DECLARE @AdhocPlanCount BIGINT
	DECLARE @AdhocPlanDBName VARCHAR(128)


	SELECT @AdhocPlanCount = MAX(CAST(Entry_Count AS BIGINT))
	FROM dbo.tbl_PlanCache_Stats
	WHERE CAST(Entry_Count AS BIGINT) > 10000

	SELECT TOP 1
		@AdhocPlanDBName = [db_name]
	FROM dbo.tbl_PlanCache_Stats
	WHERE CAST(Entry_Count AS BIGINT) = @AdhocPlanCount

	IF @AdhocPlanCount > 10000
	BEGIN
		DECLARE @AdhocPlanCountMsg VARCHAR(MAX)
		SET @AdhocPlanCountMsg = 'Database [' + @AdhocPlanDBName + '] had ' + CAST(@AdhocPlanCount AS VARCHAR(30)) + ' Adhoc query plans in cache.'
		INSERT INTO PTOClinicFindings
			([Title],[Category],[Severity],[Impact],[Recommendation],[Reading])
		SELECT 'High Adhoc query plan count.', 'Performance Metrics', 'Critical', NULL, NULL, @AdhocPlanCountMsg
	END

END

IF OBJECT_ID('PTOClinicFindings') IS NOT NULL
	 SELECT *
FROM PTOClinicFindings

--END
go
--EXECUTE GetPTOClinicFindings


