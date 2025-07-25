USE tempdb
GO
PRINT '-- Trace flag initial values'
DBCC TRACESTATUS (-1)
PRINT ''
GO
IF OBJECT_ID ('tempdb.dbo.TraceFlagOriginalStatus') IS NULL 
  CREATE TABLE tempdb.dbo.TraceFlagOriginalStatus (
    [AppName] varchar(256), 
    TraceFlag int, 
    Status int, 
    [Global] int, 
    Session int, 
    ModifiedGlobal int)
GO

IF OBJECT_ID ('tempdb.dbo.sp_diag_trace_flag_get_initial_values') IS NOT NULL 
  DROP PROC dbo.sp_diag_trace_flag_get_initial_values
GO
CREATE PROC dbo.sp_diag_trace_flag_get_initial_values @appname varchar(256) = NULL AS 
  SET NOCOUNT ON
  IF @appname IS NULL SET @appname = 'Default'
  PRINT CONVERT (varchar, GETDATE(), 126) + ' - Saving initial trace flag values for app ''' + @appname + ''''
  DELETE FROM tempdb.dbo.TraceFlagOriginalStatus WHERE [AppName] = @appname
  CREATE TABLE #TraceFlagOriginalStatus90 (TraceFlag int, Status int, [Global] int, Session int)
  CREATE TABLE #TraceFlagOriginalStatus80 (TraceFlag int, Status int)

  IF PATINDEX ('% 9.0%', @@VERSION) > 0 
  BEGIN -- SQL 2005
    INSERT INTO #TraceFlagOriginalStatus90
      EXEC ('DBCC TRACESTATUS (-1)')
    INSERT INTO tempdb.dbo.TraceFlagOriginalStatus 
      SELECT @appname, *, 0 FROM #TraceFlagOriginalStatus90
  END 
  ELSE BEGIN -- SQL 2000
    INSERT INTO #TraceFlagOriginalStatus80 
      EXEC ('DBCC TRACESTATUS (-1)')
    INSERT INTO tempdb.dbo.TraceFlagOriginalStatus 
      SELECT @appname, TraceFlag, Status, 0, 0, 0 FROM #TraceFlagOriginalStatus80
  END
GO

IF OBJECT_ID ('tempdb.dbo.sp_diag_trace_flag_enable') IS NOT NULL 
  DROP PROC dbo.sp_diag_trace_flag_enable
GO
CREATE PROC dbo.sp_diag_trace_flag_enable @traceflag int, @appname varchar(128) = NULL 
AS 
  SET NOCOUNT ON
  IF @appname IS NULL SET @appname = 'Default'
  IF NOT EXISTS (SELECT * FROM tempdb.dbo.TraceFlagOriginalStatus WHERE [AppName] = @appname AND TraceFlag = @traceflag) 
    INSERT INTO tempdb.dbo.TraceFlagOriginalStatus VALUES (@appname, @traceflag, 0, 0, 0, 0)
  PRINT CONVERT (varchar, GETDATE(), 126) + ' - Enabling trace flag ' + CONVERT (varchar, @traceflag) + '...'
  PRINT CONVERT (varchar, GETDATE(), 126) + ' - DBCC TRACEON (' + CONVERT (varchar, @traceflag) + ', -1)'
  DBCC TRACEON (@traceflag, -1)
  UPDATE tempdb.dbo.TraceFlagOriginalStatus SET ModifiedGlobal = 1 WHERE [AppName] = @appname AND TraceFlag = @traceflag
GO

IF OBJECT_ID ('tempdb.dbo.sp_diag_trace_flag_disable') IS NOT NULL 
  DROP PROC dbo.sp_diag_trace_flag_disable
GO
CREATE PROC dbo.sp_diag_trace_flag_disable @traceflag int, @appname varchar(128) = NULL 
AS 
  SET NOCOUNT ON
  IF @appname IS NULL SET @appname = 'Default'
  IF NOT EXISTS (SELECT * FROM tempdb.dbo.TraceFlagOriginalStatus WHERE [AppName] = @appname AND TraceFlag = @traceflag) 
    INSERT INTO tempdb.dbo.TraceFlagOriginalStatus VALUES (@appname, @traceflag, 0, 0, 0, 0)
  PRINT CONVERT (varchar, GETDATE(), 126) + ' - Disabling trace flag ' + CONVERT (varchar, @traceflag) + '...'
  PRINT CONVERT (varchar, GETDATE(), 126) + ' - DBCC TRACEOFF (' + CONVERT (varchar, @traceflag) + ', -1)'
  DBCC TRACEOFF (@traceflag, -1)
  UPDATE tempdb.dbo.TraceFlagOriginalStatus SET ModifiedGlobal = 1 WHERE [AppName] = @appname AND TraceFlag = @traceflag
GO

IF OBJECT_ID ('tempdb.dbo.sp_diag_trace_flag_restore') IS NOT NULL 
  DROP PROC dbo.sp_diag_trace_flag_restore
GO
CREATE PROC dbo.sp_diag_trace_flag_restore @appname varchar(128) = NULL AS 
  SET NOCOUNT ON
  IF @appname IS NULL SET @appname = 'Default'
  DECLARE @TraceFlag int
  DECLARE @InitialGlobalVal int
  DECLARE c CURSOR FOR 
  SELECT TraceFlag, [Global] FROM tempdb.dbo.TraceFlagOriginalStatus WHERE ModifiedGlobal = 1
  OPEN c
  FETCH NEXT FROM c INTO @TraceFlag, @InitialGlobalVal
  WHILE (@@FETCH_STATUS <> -1)
  BEGIN
    IF @InitialGlobalVal = 0 BEGIN
      PRINT CONVERT (varchar, GETDATE(), 126) + ' - Restoring trace flag ' + CONVERT (varchar, @TraceFlag) + ' to original state (OFF)'
      DBCC TRACEOFF (@TraceFlag, -1)
    END
    ELSE BEGIN
      PRINT CONVERT (varchar, GETDATE(), 126) + ' - Restoring trace flag ' + CONVERT (varchar, @TraceFlag) + ' to original state (ON)'
      DBCC TRACEON (@TraceFlag, -1)
    END
    FETCH NEXT FROM c INTO @TraceFlag, @InitialGlobalVal
  END
  CLOSE c
  DEALLOCATE c
GO

EXEC dbo.sp_diag_trace_flag_get_initial_values
IF SUBSTRING ('SQLDIAG', 2, 7) != 'appname' 
  EXEC dbo.sp_diag_trace_flag_get_initial_values 'SQLDIAG'
GO
PRINT ''
SELECT * FROM tempdb.dbo.TraceFlagOriginalStatus 
GO
