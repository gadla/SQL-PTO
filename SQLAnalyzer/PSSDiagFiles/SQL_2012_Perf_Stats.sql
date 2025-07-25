USE tempdb
GO
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO
IF (@@MICROSOFTVERSION < 184551476) --11.0.2100
BEGIN
  PRINT ''
  PRINT '**** NOTE ****'
  PRINT '**** This script is for SQL Server 2012.  Errors are expected when run on earlier versions.'
  PRINT '**************'
  PRINT ''
END
GO
PRINT 'Starting SQL Server 2012 Perf Stats Script...'
SET LANGUAGE us_english
PRINT '-- Script Source --'
SELECT 'SQL 2012 Perf Stats Script' AS script_name, '$Revision: 12 $ ($Change: 3355 $)' AS revision
PRINT ''
PRINT '-- Script and Environment Details --'
PRINT 'Name                     Value'
PRINT '------------------------ ---------------------------------------------------'
PRINT 'SQL Server Name          ' + @@SERVERNAME
PRINT 'Machine Name             ' + CONVERT (varchar, SERVERPROPERTY ('MachineName'))
PRINT 'SQL Version (SP)         ' + CONVERT (varchar, SERVERPROPERTY ('ProductVersion')) + ' (' + CONVERT (varchar, SERVERPROPERTY ('ProductLevel')) + ')'
PRINT 'Edition                  ' + CONVERT (varchar, SERVERPROPERTY ('Edition'))
PRINT 'Script Name              SQL 11 Perf Stats Script'
PRINT 'Script File Name         $File: SQL_2012_Perf_Stats.sql $'
PRINT 'Revision                 $Revision: 12 $ ($Change: 3355 $)'
PRINT 'Last Modified            $Date: 2011/03/03 10:03:24 $'
PRINT 'Script Begin Time        ' + CONVERT (varchar(30), GETDATE(), 126) 
PRINT 'Current Database         ' + DB_NAME()
PRINT ''
GO

IF OBJECT_ID ('sp_perf_stats11','P') IS NOT NULL
   DROP PROCEDURE sp_perf_stats11
GO
CREATE PROCEDURE sp_perf_stats11 @appname sysname='PSSDIAG', @runtime datetime AS 
  SET NOCOUNT ON
  DECLARE @msg varchar(100)
  DECLARE @querystarttime datetime
  DECLARE @queryduration int
  DECLARE @qrydurationwarnthreshold int
  DECLARE @servermajorversion int
  DECLARE @cpu_time_start bigint, @elapsed_time_start bigint
  DECLARE @sql nvarchar(max)
  DECLARE @cte nvarchar(max)
  DECLARE @rowcount bigint

  SELECT @cpu_time_start = cpu_time, @elapsed_time_start = total_elapsed_time FROM sys.dm_exec_sessions WHERE session_id = @@SPID

  IF OBJECT_ID ('tempdb.dbo.#tmp_requests') IS NOT NULL DROP TABLE #tmp_requests
  IF OBJECT_ID ('tempdb.dbo.#tmp_requests2') IS NOT NULL DROP TABLE #tmp_requests2
  
  IF @runtime IS NULL 
  BEGIN 
    SET @runtime = GETDATE()
    SET @msg = 'Start time: ' + CONVERT (varchar(30), @runtime, 126)
    RAISERROR (@msg, 0, 1) WITH NOWAIT
  END
  SET @qrydurationwarnthreshold = 500
  
  -- SERVERPROPERTY ('ProductVersion') returns e.g. "9.00.2198.00" --> 9
  SET @servermajorversion = REPLACE (LEFT (CONVERT (varchar, SERVERPROPERTY ('ProductVersion')), 2), '.', '')

  RAISERROR (@msg, 0, 1) WITH NOWAIT
  SET @querystarttime = GETDATE()
  SELECT
    sess.session_id, req.request_id, tasks.exec_context_id AS 'ecid', tasks.task_address, req.blocking_session_id, LEFT (tasks.task_state, 15) AS 'task_state', 
    tasks.scheduler_id, LEFT (ISNULL (req.wait_type, ''), 50) AS 'wait_type', LEFT (ISNULL (req.wait_resource, ''), 40) AS 'wait_resource', 
    LEFT (req.last_wait_type, 50) AS 'last_wait_type', 
    /* sysprocesses is the only way to get open_tran count for sessions w/o an active request (SQLBUD #487091) */
    CASE 
      WHEN req.open_transaction_count IS NOT NULL THEN req.open_transaction_count 
      ELSE (SELECT open_tran FROM master.dbo.sysprocesses sysproc WHERE sess.session_id = sysproc.spid) 
    END AS open_trans, 
    LEFT (CASE COALESCE(req.transaction_isolation_level, sess.transaction_isolation_level)
      WHEN 0 THEN '0-Read Committed' 
      WHEN 1 THEN '1-Read Uncommitted (NOLOCK)' 
      WHEN 2 THEN '2-Read Committed' 
      WHEN 3 THEN '3-Repeatable Read' 
      WHEN 4 THEN '4-Serializable' 
      WHEN 5 THEN '5-Snapshot' 
      ELSE CONVERT (varchar(30), req.transaction_isolation_level) + '-UNKNOWN' 
    END, 30) AS transaction_isolation_level, 
    sess.is_user_process, req.cpu_time AS 'request_cpu_time', 
    req.logical_reads request_logical_reads,
    req.reads request_reads,
     req.writes request_writes,
    sess.memory_usage, sess.cpu_time AS 'session_cpu_time', sess.reads AS 'session_reads', sess.writes AS 'session_writes', sess.logical_reads AS 'session_logical_reads', 
    sess.total_scheduled_time, sess.total_elapsed_time, sess.last_request_start_time, sess.last_request_end_time, sess.row_count AS session_row_count, 
    sess.prev_error, req.open_resultset_count AS open_resultsets, req.total_elapsed_time AS request_total_elapsed_time, 
    CONVERT (decimal(5,2), req.percent_complete) AS percent_complete, req.estimated_completion_time AS est_completion_time, req.transaction_id, 
    req.start_time AS request_start_time, LEFT (req.status, 15) AS request_status, req.command, req.plan_handle, req.sql_handle, req.statement_start_offset, 
    req.statement_end_offset, req.database_id, req.[user_id], req.executing_managed_code, tasks.pending_io_count, sess.login_time, 
    LEFT (sess.[host_name], 20) AS [host_name], LEFT (ISNULL (sess.program_name, ''), 50) AS program_name, ISNULL (sess.host_process_id, 0) AS 'host_process_id', 
    ISNULL (sess.client_version, 0) AS 'client_version', LEFT (ISNULL (sess.client_interface_name, ''), 30) AS 'client_interface_name', 
    LEFT (ISNULL (sess.login_name, ''), 30) AS 'login_name', LEFT (ISNULL (sess.nt_domain, ''), 30) AS 'nt_domain', LEFT (ISNULL (sess.nt_user_name, ''), 20) AS 'nt_user_name', 
    ISNULL (conn.net_packet_size, 0) AS 'net_packet_size', LEFT (ISNULL (conn.client_net_address, ''), 20) AS 'client_net_address', conn.most_recent_sql_handle, 
    LEFT (sess.status, 15) AS 'session_status',
    /* sys.dm_os_workers and sys.dm_os_threads removed due to perf impact, no predicate pushdown (SQLBU #488971) */
    --  workers.is_preemptive,
    --  workers.is_sick, 
    --  workers.exception_num AS last_worker_exception, 
    --  convert (varchar (20), master.dbo.fn_varbintohexstr (workers.exception_address)) AS last_exception_address
    --  threads.os_thread_id 
    sess.group_id, req.query_hash, req.query_plan_hash  
  INTO #tmp_requests
  FROM sys.dm_exec_sessions sess 
  /* Join hints are required here to work around bad QO join order/type decisions (ultimately by-design, caused by the lack of accurate DMV card estimates) */
  LEFT OUTER MERGE JOIN sys.dm_exec_requests req  ON sess.session_id = req.session_id
  LEFT OUTER MERGE JOIN sys.dm_os_tasks tasks ON tasks.session_id = sess.session_id AND tasks.request_id = req.request_id 
  /* The following two DMVs removed due to perf impact, no predicate pushdown (SQLBU #488971) */
  --  LEFT OUTER MERGE JOIN sys.dm_os_workers workers ON tasks.worker_address = workers.worker_address
  --  LEFT OUTER MERGE JOIN sys.dm_os_threads threads ON workers.thread_address = threads.thread_address
  LEFT OUTER MERGE JOIN sys.dm_exec_connections conn on conn.session_id = sess.session_id
  WHERE 
    /* Get execution state for all active queries... */
    (req.session_id IS NOT NULL AND (sess.is_user_process = 1 OR req.status COLLATE Latin1_General_BIN NOT IN ('background', 'sleeping')))
    /* ... and also any head blockers, even though they may not be running a query at the moment. */
    OR (sess.session_id IN (SELECT DISTINCT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id != 0))
  /* redundant due to the use of join hints, but added here to suppress warning message */
  OPTION (FORCE ORDER)  
  SET @rowcount = @@ROWCOUNT
  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats qry0 - ' + CONVERT (varchar, @queryduration) + 'ms, rowcount=' + CONVERT(varchar, @rowcount) + CHAR(13) + CHAR(10)

  IF NOT EXISTS (SELECT * FROM #tmp_requests WHERE session_id <> @@SPID AND ISNULL (host_name, '') != @appname) BEGIN
    PRINT 'No active queries'
  END
  ELSE BEGIN
    -- There are active queries (other than this one). 
    -- This query could be collapsed into the query above.  It is broken out here to avoid an excessively 
    -- large memory grant due to poor cardinality estimates (see previous bugs -- ultimate cause is the 
    -- lack of good stats for many DMVs). 
    SET @querystarttime = GETDATE()
    SELECT 
      IDENTITY (int,1,1) AS tmprownum, 
      r.session_id, r.request_id, r.ecid, r.blocking_session_id, ISNULL (waits.blocking_exec_context_id, 0) AS blocking_ecid, 
      r.task_state, waits.wait_type, ISNULL (waits.wait_duration_ms, 0) AS wait_duration_ms, r.wait_resource, 
      LEFT (ISNULL (waits.resource_description, ''), 140) AS resource_description, r.last_wait_type, r.open_trans, 
      r.transaction_isolation_level, r.is_user_process, r.request_cpu_time, r.request_logical_reads, r.request_reads, 
      r.request_writes, r.memory_usage, r.session_cpu_time, r.session_reads, r.session_writes, r.session_logical_reads, 
      r.total_scheduled_time, r.total_elapsed_time, r.last_request_start_time, r.last_request_end_time, r.session_row_count, 
      r.prev_error, r.open_resultsets, r.request_total_elapsed_time, r.percent_complete, r.est_completion_time, 
      -- r.tran_name, r.transaction_begin_time, r.tran_type, r.tran_state, 
      LEFT (COALESCE (reqtrans.name, sesstrans.name, ''), 24) AS tran_name, 
      COALESCE (reqtrans.transaction_begin_time, sesstrans.transaction_begin_time) AS transaction_begin_time, 
      LEFT (CASE COALESCE (reqtrans.transaction_type, sesstrans.transaction_type)
        WHEN 1 THEN '1-Read/write'
        WHEN 2 THEN '2-Read only'
        WHEN 3 THEN '3-System'
        WHEN 4 THEN '4-Distributed'
        ELSE CONVERT (varchar(30), COALESCE (reqtrans.transaction_type, sesstrans.transaction_type)) + '-UNKNOWN' 
      END, 15) AS tran_type, 
      LEFT (CASE COALESCE (reqtrans.transaction_state, sesstrans.transaction_state)
        WHEN 0 THEN '0-Initializing'
        WHEN 1 THEN '1-Initialized'
        WHEN 2 THEN '2-Active'
        WHEN 3 THEN '3-Ended'
        WHEN 4 THEN '4-Preparing'
        WHEN 5 THEN '5-Prepared'
        WHEN 6 THEN '6-Committed'
        WHEN 7 THEN '7-Rolling back'
        WHEN 8 THEN '8-Rolled back'
        ELSE CONVERT (varchar(30), COALESCE (reqtrans.transaction_state, sesstrans.transaction_state)) + '-UNKNOWN'
      END, 15) AS tran_state, 
      r.request_start_time, r.request_status, r.command, r.plan_handle, r.[sql_handle], r.statement_start_offset, 
      r.statement_end_offset, r.database_id, r.[user_id], r.executing_managed_code, r.pending_io_count, r.login_time, 
      r.[host_name], r.[program_name], r.host_process_id, r.client_version, r.client_interface_name, r.login_name, r.nt_domain, 
      r.nt_user_name, r.net_packet_size, r.client_net_address, r.most_recent_sql_handle, r.session_status, r.scheduler_id,
      -- r.is_preemptive, r.is_sick, r.last_worker_exception, r.last_exception_address, 
      -- r.os_thread_id
      r.group_id, r.query_hash, r.query_plan_hash
    INTO #tmp_requests2
    FROM #tmp_requests r
    /* Join hints are required here to work around bad QO join order/type decisions (ultimately by-design, caused by the lack of accurate DMV card estimates) */
    LEFT OUTER MERGE JOIN sys.dm_tran_active_transactions reqtrans ON r.transaction_id = reqtrans.transaction_id
    
    LEFT OUTER MERGE JOIN sys.dm_tran_session_transactions sessions_transactions on sessions_transactions.session_id = r.session_id
    
    LEFT OUTER MERGE JOIN sys.dm_tran_active_transactions sesstrans ON sesstrans.transaction_id = sessions_transactions.transaction_id
    
    LEFT OUTER MERGE JOIN sys.dm_os_waiting_tasks waits ON waits.waiting_task_address = r.task_address 
    ORDER BY r.session_id, blocking_ecid
    /* redundant due to the use of join hints, but added here to suppress warning message */
    OPTION (FORCE ORDER)  
    SET @rowcount = @@ROWCOUNT
    SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
    IF @queryduration > @qrydurationwarnthreshold
      PRINT 'DebugPrint: perfstats qry0a - ' + CONVERT (varchar, @queryduration) + 'ms, rowcount=' + CONVERT(varchar, @rowcount) + CHAR(13) + CHAR(10)

    /* This index typically takes <10ms to create, and drops the head blocker summary query cost from ~250ms CPU down to ~20ms. */
    CREATE NONCLUSTERED INDEX idx1 ON #tmp_requests2 (blocking_session_id, session_id, wait_type, wait_duration_ms)

    /* Output Resultset #1: summary of all active requests (and head blockers) 
    ** Dynamic (but explicitly parameterized) SQL used here to allow for (optional) direct-to-database data collection 
    ** without unnecessary code duplication. */
    RAISERROR ('-- requests --', 0, 1) WITH NOWAIT
    SET @querystarttime = GETDATE()

    SELECT TOP 10000 CONVERT (varchar(30), @runtime, 126) AS 'runtime', 
      session_id, request_id, ecid, blocking_session_id, blocking_ecid, task_state, 
      wait_type, wait_duration_ms, wait_resource, resource_description, last_wait_type, 
      open_trans, transaction_isolation_level, is_user_process, 
      request_cpu_time, request_logical_reads, request_reads, request_writes, memory_usage, 
      session_cpu_time, session_reads, session_writes, session_logical_reads, total_scheduled_time, 
      total_elapsed_time, CONVERT (varchar(30), last_request_start_time, 126) AS 'last_request_start_time', 
      CONVERT (varchar(30), last_request_end_time, 126) AS 'last_request_end_time', session_row_count, 
      prev_error, open_resultsets, request_total_elapsed_time, percent_complete, 
      est_completion_time, tran_name, 
      CONVERT (varchar(30), transaction_begin_time, 126) AS 'transaction_begin_time', tran_type, 
      tran_state, CONVERT (varchar, request_start_time, 126) AS request_start_time, request_status, 
      command, statement_start_offset, statement_end_offset, database_id, [user_id], 
      executing_managed_code, pending_io_count, CONVERT (varchar(30), login_time, 126) AS 'login_time', 
      [host_name], [program_name], host_process_id, client_version, client_interface_name, login_name, 
      nt_domain, nt_user_name, net_packet_size, client_net_address, session_status, 
      scheduler_id,
      -- is_preemptive, is_sick, last_worker_exception, last_exception_address
      -- os_thread_id
      group_id, query_hash, query_plan_hash, plan_handle      
    FROM #tmp_requests2 r
    WHERE ISNULL ([host_name], '''') != @appname AND r.session_id != @@SPID 
      /* One EC can have multiple waits in sys.dm_os_waiting_tasks (e.g. parent thread waiting on multiple children, for example 
      ** for parallel create index; or mem grant waits for RES_SEM_FOR_QRY_COMPILE).  This will result in the same EC being listed 
      ** multiple times in the request table, which is counterintuitive for most people.  Instead of showing all wait relationships, 
      ** for each EC we will report the wait relationship that has the longest wait time.  (If there are multiple relationships with 
      ** the same wait time, blocker spid/ecid is used to choose one of them.)  If it were not for , we would do this 
      ** exclusion in the previous query to avoid storing data that will ultimately be filtered out. */
      AND NOT EXISTS 
        (SELECT * FROM #tmp_requests2 r2 
         WHERE r.session_id = r2.session_id AND r.request_id = r2.request_id AND r.ecid = r2.ecid AND r.wait_type = r2.wait_type 
           AND (r2.wait_duration_ms > r.wait_duration_ms OR (r2.wait_duration_ms = r.wait_duration_ms AND r2.tmprownum > r.tmprownum)))
    
    
    SET @rowcount = @@ROWCOUNT
    SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
    IF @queryduration > @qrydurationwarnthreshold
      PRINT 'DebugPrint: perfstats qry1 - ' + CONVERT (varchar, @queryduration) + 'ms, rowcount=' + CONVERT(varchar, @rowcount) + CHAR(13) + CHAR(10)

    /* Resultset #2: Head blocker summary 
    ** Intra-query blocking relationships (parallel query waits) aren't "true" blocking problems that we should report on here. */
    IF NOT EXISTS (SELECT * FROM #tmp_requests2 WHERE blocking_session_id != 0 AND wait_type NOT IN ('WAITFOR', 'EXCHANGE', 'CXPACKET') AND wait_duration_ms > 0) 
    BEGIN 
      PRINT ''
      PRINT '-- No blocking detected --'
      PRINT ''
    END
    ELSE BEGIN
      PRINT ''
      PRINT '-----------------------'
      PRINT '-- BLOCKING DETECTED --'
      PRINT ''
      RAISERROR ('-- headblockersummary --', 0, 1) WITH NOWAIT;
      /* We need stats like the number of spids blocked, max waittime, etc, for each head blocker.  Use a recursive CTE to 
      ** walk the blocking hierarchy. Again, explicitly parameterized dynamic SQL used to allow optional collection direct  
      ** to a database. */
      SET @querystarttime = GETDATE();
      
      WITH BlockingHierarchy (head_blocker_session_id, session_id, blocking_session_id, wait_type, wait_duration_ms, 
        wait_resource, statement_start_offset, statement_end_offset, plan_handle, sql_handle, most_recent_sql_handle, [Level]) 
      AS (
        SELECT head.session_id AS head_blocker_session_id, head.session_id AS session_id, head.blocking_session_id, 
          head.wait_type, head.wait_duration_ms, head.wait_resource, head.statement_start_offset, head.statement_end_offset, 
          head.plan_handle, head.sql_handle, head.most_recent_sql_handle, 0 AS [Level]
        FROM #tmp_requests2 head
        WHERE (head.blocking_session_id IS NULL OR head.blocking_session_id = 0) 
          AND head.session_id IN (SELECT DISTINCT blocking_session_id FROM #tmp_requests2 WHERE blocking_session_id != 0) 
        UNION ALL 
        SELECT h.head_blocker_session_id, blocked.session_id, blocked.blocking_session_id, blocked.wait_type, 
          blocked.wait_duration_ms, blocked.wait_resource, h.statement_start_offset, h.statement_end_offset, 
          h.plan_handle, h.sql_handle, h.most_recent_sql_handle, [Level] + 1
        FROM #tmp_requests2 blocked
        INNER JOIN BlockingHierarchy AS h ON h.session_id = blocked.blocking_session_id and h.session_id!=blocked.session_id --avoid infinite recursion for latch type of blocknig
        WHERE h.wait_type COLLATE Latin1_General_BIN NOT IN ('EXCHANGE', 'CXPACKET') or h.wait_type is null
      )
      SELECT CONVERT (varchar(30), @runtime, 126) AS 'runtime', 
        head_blocker_session_id, COUNT(*) AS 'blocked_task_count', SUM (ISNULL (wait_duration_ms, 0)) AS 'tot_wait_duration_ms', 
        LEFT (CASE 
          WHEN wait_type LIKE 'LCK%' COLLATE Latin1_General_BIN AND wait_resource LIKE '%\[COMPILE\]%' ESCAPE '\' COLLATE Latin1_General_BIN 
            THEN 'COMPILE (' + ISNULL (wait_resource, '') + ')' 
          WHEN wait_type LIKE 'LCK%' COLLATE Latin1_General_BIN THEN 'LOCK BLOCKING' 
          WHEN wait_type LIKE 'PAGELATCH%' COLLATE Latin1_General_BIN THEN 'PAGELATCH_* WAITS' 
          WHEN wait_type LIKE 'PAGEIOLATCH%' COLLATE Latin1_General_BIN THEN 'PAGEIOLATCH_* WAITS' 
          ELSE wait_type
        END, 40) AS 'blocking_resource_wait_type', AVG (ISNULL (wait_duration_ms, 0)) AS 'avg_wait_duration_ms', MAX(wait_duration_ms) AS 'max_wait_duration_ms', 
        MAX ([Level]) AS 'max_blocking_chain_depth', 
        MAX (ISNULL (CONVERT (nvarchar(60), CASE 
          WHEN sql.objectid IS NULL THEN NULL 
          ELSE REPLACE (REPLACE (SUBSTRING (sql.[text], CHARINDEX ('CREATE ', CONVERT (nvarchar(512), SUBSTRING (sql.[text], 1, 1000)) COLLATE Latin1_General_BIN), 50) COLLATE Latin1_General_BIN, CHAR(10), ' '), CHAR(13), ' ')
        END), '')) AS 'head_blocker_proc_name', 
        MAX (ISNULL (sql.objectid, 0)) AS 'head_blocker_proc_objid', MAX (ISNULL (CONVERT (nvarchar(1000), REPLACE (REPLACE (SUBSTRING (sql.[text], ISNULL (statement_start_offset, 0)/2 + 1, 
          CASE WHEN ISNULL (statement_end_offset, 8192) <= 0 THEN 8192 
          ELSE ISNULL (statement_end_offset, 8192)/2 - ISNULL (statement_start_offset, 0)/2 END + 1) COLLATE Latin1_General_BIN, 
        CHAR(13), ' '), CHAR(10), ' ')), '')) AS 'stmt_text', 
        CONVERT (varbinary (64), MAX (ISNULL (plan_handle, 0x))) AS 'head_blocker_plan_handle'
      FROM BlockingHierarchy
      OUTER APPLY sys.dm_exec_sql_text (ISNULL ([sql_handle], most_recent_sql_handle)) AS sql
      WHERE blocking_session_id != 0 AND [Level] > 0
      GROUP BY head_blocker_session_id, 
        LEFT (CASE 
          WHEN wait_type LIKE 'LCK%' COLLATE Latin1_General_BIN AND wait_resource LIKE '%\[COMPILE\]%' ESCAPE '\' COLLATE Latin1_General_BIN 
            THEN 'COMPILE (' + ISNULL (wait_resource, '') + ')' 
          WHEN wait_type LIKE 'LCK%' COLLATE Latin1_General_BIN THEN 'LOCK BLOCKING' 
          WHEN wait_type LIKE 'PAGELATCH%' COLLATE Latin1_General_BIN THEN 'PAGELATCH_* WAITS' 
          WHEN wait_type LIKE 'PAGEIOLATCH%' COLLATE Latin1_General_BIN THEN 'PAGEIOLATCH_* WAITS' 
          ELSE wait_type
        END, 40) 
      ORDER BY SUM (wait_duration_ms) DESC;
      
      
      SET @rowcount = @@ROWCOUNT
      SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
      IF @queryduration > @qrydurationwarnthreshold
        PRINT 'DebugPrint: perfstats qry2 - ' + CONVERT (varchar, @queryduration) + 'ms, rowcount=' + CONVERT(varchar, @rowcount) + CHAR(13) + CHAR(10)
    END

    /* Resultset #3: inputbuffers and query stats for "expensive" queries, head blockers, and "first-tier" blocked spids */
    PRINT ''
    RAISERROR ('-- notableactivequeries --', 0, 1) WITH NOWAIT
    SET @querystarttime = GETDATE()

    SELECT DISTINCT TOP 500 
      CONVERT (varchar(30), @runtime, 126) AS 'runtime', r.session_id AS session_id, r.request_id AS request_id, stat.execution_count AS 'plan_total_exec_count', 
      stat.total_worker_time/1000 AS 'plan_total_cpu_ms', stat.total_elapsed_time/1000 AS 'plan_total_duration_ms', stat.total_physical_reads AS 'plan_total_physical_reads', 
      stat.total_logical_writes AS 'plan_total_logical_writes', stat.total_logical_reads AS 'plan_total_logical_reads', 
      LEFT (CASE 
        WHEN pa.value=32767 THEN 'ResourceDb'
        ELSE ISNULL (DB_NAME (CONVERT (sysname, pa.value)), CONVERT (sysname, pa.value))
      END, 40) AS 'dbname', 
      sql.objectid AS 'objectid', 
      CONVERT (nvarchar(60), CASE 
        WHEN sql.objectid IS NULL THEN NULL 
        ELSE REPLACE (REPLACE (SUBSTRING (sql.[text] COLLATE Latin1_General_BIN, CHARINDEX ('CREATE ', SUBSTRING (sql.[text] COLLATE Latin1_General_BIN, 1, 1000)), 50), CHAR(10), ' '), CHAR(13), ' ')
      END) AS procname, 
      CONVERT (nvarchar(300), REPLACE (REPLACE (CONVERT (nvarchar(300), SUBSTRING (sql.[text], ISNULL (r.statement_start_offset, 0)/2 + 1, 
          CASE WHEN ISNULL (r.statement_end_offset, 8192) <= 0 THEN 8192 
          ELSE ISNULL (r.statement_end_offset, 8192)/2 - ISNULL (r.statement_start_offset, 0)/2 END + 1)) COLLATE Latin1_General_BIN, 
        CHAR(13), ' '), CHAR(10), ' ')) AS 'stmt_text', 
      CONVERT (varbinary (64), (r.plan_handle)) AS 'plan_handle',
      group_id
    FROM #tmp_requests2 r
    LEFT OUTER JOIN sys.dm_exec_query_stats stat ON r.plan_handle = stat.plan_handle AND stat.statement_start_offset = r.statement_start_offset
    OUTER APPLY sys.dm_exec_plan_attributes (r.plan_handle) pa
    OUTER APPLY sys.dm_exec_sql_text (ISNULL (r.[sql_handle], r.most_recent_sql_handle)) AS sql
    WHERE (pa.attribute = 'dbid' COLLATE Latin1_General_BIN OR pa.attribute IS NULL) AND ISNULL (host_name, '') != @appname AND r.session_id != @@SPID 
      AND ( 
        /* We do not want to pull inputbuffers for everyone. The conditions below determine which ones we will fetch. */
        (r.session_id IN (SELECT blocking_session_id FROM #tmp_requests2 WHERE blocking_session_id != 0)) -- head blockers
        OR (r.blocking_session_id IN (SELECT blocking_session_id FROM #tmp_requests2 WHERE blocking_session_id != 0)) -- "first-tier" blocked requests
        OR (LTRIM (r.wait_type) <> '''' OR r.wait_duration_ms > 500) -- waiting for some resource
        OR (r.open_trans > 5) -- possible orphaned transaction
        OR (r.request_total_elapsed_time > 25000) -- long-running query
        OR (r.request_logical_reads > 1000000 OR r.request_cpu_time > 3000) -- expensive (CPU) query
        OR (r.request_reads + r.request_writes > 5000 OR r.pending_io_count > 400) -- expensive (I/O) query
        OR (r.memory_usage > 25600) -- expensive (memory > 200MB) query
        -- OR (r.is_sick > 0) -- spinloop
      )
    ORDER BY stat.total_worker_time/1000 DESC

    SET @rowcount = @@ROWCOUNT
    SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
    IF @rowcount >= 500 PRINT 'WARNING: notableactivequeries output artificially limited to 500 rows'
    IF @queryduration > @qrydurationwarnthreshold
      PRINT 'DebugPrint: perfstats qry3 - ' + CONVERT (varchar, @queryduration) + 'ms, rowcount=' + CONVERT(varchar, @rowcount) + CHAR(13) + CHAR(10)

    IF '%runmode%' = 'REALTIME' BEGIN 
      -- In near-realtime/direct-to-database mode, we have to maintain tbl_BLOCKING_CHAINS on-the-fly
      -- 1) Insert new blocking chains
	  RAISERROR ('', 0, 1) WITH NOWAIT
      INSERT INTO tbl_BLOCKING_CHAINS (first_rownum, last_rownum, num_snapshots, blocking_start, blocking_end, head_blocker_session_id, 
        blocking_wait_type, max_blocked_task_count, max_total_wait_duration_ms, avg_wait_duration_ms, max_wait_duration_ms, 
        max_blocking_chain_depth, head_blocker_session_id_orig)
      SELECT rownum, NULL, 1, runtime, NULL, 
        CASE WHEN blocking_resource_wait_type LIKE 'COMPILE%' THEN 'COMPILE BLOCKING' ELSE head_blocker_session_id END AS head_blocker_session_id, 
        blocking_resource_wait_type, blocked_task_count, tot_wait_duration_ms, avg_wait_duration_ms, max_wait_duration_ms, 
        max_blocking_chain_depth, head_blocker_session_id
      FROM tbl_HEADBLOCKERSUMMARY b1 
      WHERE b1.runtime = @runtime AND NOT EXISTS (
        SELECT * FROM tbl_BLOCKING_CHAINS b2  
        WHERE b2.blocking_end IS NULL  -- end-of-blocking has not been detected yet
          AND b2.head_blocker_session_id = CASE WHEN blocking_resource_wait_type LIKE 'COMPILE%' THEN 'COMPILE BLOCKING' ELSE head_blocker_session_id END -- same head blocker
          AND b2.blocking_wait_type = b1.blocking_resource_wait_type -- same type of blocking
      )
      PRINT 'Inserted ' + CONVERT (varchar, @@ROWCOUNT) + ' new blocking chains...'

      -- 2) Update statistics for in-progress blocking incidents
      UPDATE tbl_BLOCKING_CHAINS 
      SET last_rownum = b2.rownum, num_snapshots = b1.num_snapshots + 1, 
        max_blocked_task_count = CASE WHEN b1.max_blocked_task_count > b2.blocked_task_count THEN b1.max_blocked_task_count ELSE b2.blocked_task_count END, 
        max_total_wait_duration_ms = CASE WHEN b1.max_total_wait_duration_ms > b2.tot_wait_duration_ms THEN b1.max_total_wait_duration_ms ELSE b2.tot_wait_duration_ms END, 
        avg_wait_duration_ms = (b1.num_snapshots-1) * b1.avg_wait_duration_ms + b2.avg_wait_duration_ms / b1.num_snapshots, 
        max_wait_duration_ms = CASE WHEN b1.max_wait_duration_ms > b2.max_wait_duration_ms THEN b1.max_wait_duration_ms ELSE b2.max_wait_duration_ms END, 
        max_blocking_chain_depth = CASE WHEN b1.max_blocking_chain_depth > b2.max_blocking_chain_depth THEN b1.max_blocking_chain_depth ELSE b2.max_blocking_chain_depth END
      FROM tbl_BLOCKING_CHAINS b1 
      INNER JOIN tbl_HEADBLOCKERSUMMARY b2 ON b1.blocking_end IS NULL -- end-of-blocking has not been detected yet
          AND b2.head_blocker_session_id = b1.head_blocker_session_id -- same head blocker
          AND b1.blocking_wait_type = b2.blocking_resource_wait_type -- same type of blocking
          AND b2.runtime = @runtime
      PRINT 'Updated ' + CONVERT (varchar, @@ROWCOUNT) + ' in-progress blocking chains...'

      -- 3) "Close out" blocking chains that were just resolved
      UPDATE tbl_BLOCKING_CHAINS 
      SET blocking_end = @runtime
      FROM tbl_BLOCKING_CHAINS b1
      WHERE blocking_end IS NULL AND NOT EXISTS (
        SELECT * FROM tbl_HEADBLOCKERSUMMARY b2 WHERE b2.runtime = @runtime 
          AND b2.head_blocker_session_id = b1.head_blocker_session_id -- same head blocker
          AND b1.blocking_wait_type = b2.blocking_resource_wait_type -- same type of blocking
      )
      PRINT + CONVERT (varchar, @@ROWCOUNT) + ' blocking chains have ended.'
    END
  END

  /* Resultset #4: System Requests */
  PRINT ''
  RAISERROR ('-- System Requests --', 0, 1) WITH NOWAIT
  SET @querystarttime = GETDATE()
  
  select CONVERT (varchar(30), @runtime, 126) AS 'runtime', tr.os_thread_id, req.* from sys.dm_exec_requests req join sys.dm_os_workers wrk  on req.task_address = wrk.task_address 
    join sys.dm_os_threads tr on tr.worker_address=wrk.worker_address
    join sys.dm_exec_sessions sess on req.session_id=sess.session_id
    where  sess.is_user_process = 0

  SET @rowcount = @@ROWCOUNT
  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats qry4 - ' + CONVERT (varchar, @queryduration) + 'ms, rowcount=' + CONVERT(varchar, @rowcount) + CHAR(13) + CHAR(10)

  -- Raise a diagnostic message if we use much more CPU than normal (a typical execution uses <300ms)
  DECLARE @cpu_time bigint, @elapsed_time bigint
  SELECT @cpu_time = cpu_time - @cpu_time_start, @elapsed_time = total_elapsed_time - @elapsed_time_start FROM sys.dm_exec_sessions WHERE session_id = @@SPID
  IF (@elapsed_time > 2000 OR @cpu_time > 750)
    PRINT 'DebugPrint: perfstats tot - ' + CONVERT (varchar, @elapsed_time) + 'ms elapsed, ' + CONVERT (varchar, @cpu_time) + 'ms cpu' + CHAR(13) + CHAR(10)  

  RAISERROR ('', 0, 1) WITH NOWAIT
GO


IF OBJECT_ID ('sp_perf_stats_infrequent11','P') IS NOT NULL
   DROP PROCEDURE sp_perf_stats_infrequent11
GO
CREATE PROCEDURE sp_perf_stats_infrequent11 @runtime datetime, @firstrun int = 0 AS 
  SET NOCOUNT ON
  DECLARE @queryduration int
  DECLARE @querystarttime datetime
  DECLARE @qrydurationwarnthreshold int
  DECLARE @cpu_time_start bigint, @elapsed_time_start bigint
  DECLARE @servermajorversion int
  DECLARE @msg varchar(100)
  DECLARE @sql nvarchar(max)

  IF @runtime IS NULL 
  BEGIN 
    SET @runtime = GETDATE()
    SET @msg = 'Start time: ' + CONVERT (varchar(30), @runtime, 126)
    RAISERROR (@msg, 0, 1) WITH NOWAIT
  END
  SET @qrydurationwarnthreshold = 750

  SELECT @cpu_time_start = cpu_time, @elapsed_time_start = total_elapsed_time FROM sys.dm_exec_sessions WHERE session_id = @@SPID

  /* SERVERPROPERTY ('ProductVersion') returns e.g. "9.00.2198.00" --> 9 */
  SET @servermajorversion = REPLACE (LEFT (CONVERT (varchar, SERVERPROPERTY ('ProductVersion')), 2), '.', '')


  /* Resultset #1: Server global wait stats */
  PRINT ''
  RAISERROR ('-- dm_os_wait_stats --', 0, 1) WITH NOWAIT;
  SET @querystarttime = GETDATE()

  SELECT CONVERT (varchar(30), @runtime, 126) AS 'runtime', waiting_tasks_count, wait_time_ms, max_wait_time_ms, signal_wait_time_ms, wait_type
  FROM sys.dm_os_wait_stats 
  WHERE waiting_tasks_count > 0 OR wait_time_ms > 0 OR signal_wait_time_ms > 0
  ORDER BY wait_time_ms DESC

  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats2 qry1 - ' + CONVERT (varchar, @queryduration) + 'ms' + CHAR(13) + CHAR(10)


  /* Resultset #2: Spinlock stats
  ** No DMV for this -- we will synthesize the [runtime] column during data load. */
  PRINT ''
  RAISERROR ('-- DBCC SQLPERF (SPINLOCKSTATS) --', 0, 1) WITH NOWAIT;
  DBCC SQLPERF (SPINLOCKSTATS)


  /* Resultset #2a: dm_os_spinlock_stats */
  PRINT ''
  RAISERROR ('--  dm_os_spinlock_stats --', 0, 1) WITH NOWAIT;
  SET @querystarttime = GETDATE()

  SELECT CONVERT (varchar(30), @runtime, 126) AS 'runtime', collisions, spins, spins_per_collision, sleep_time, backoffs, name FROM sys.dm_os_spinlock_stats

  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats2 qry2a - ' + CONVERT (varchar, @queryduration) + 'ms' + CHAR(13) + CHAR(10)

    
  /* Resultset #3: basic perf-related SQL perfmon counters */
  PRINT ''
  RAISERROR ('-- sysperfinfo_raw (general perf subset) --', 0, 1) WITH NOWAIT;
  SET @querystarttime = GETDATE()
 
  --IF '%runmode%' = 'REALTIME' SET @sql = 'INSERT INTO tbl_SYSPERFINFO (runtime, object_name, counter_name, instance_name, cntr_value)' + @sql
  --  EXEC sp_executesql @sql, N'@runtime datetime', @runtime = @runtime
  /* Force binary collation to speed up string comparisons (query uses 10-20ms CPU w/binary collation, 200-300ms otherwise) */
  
  SELECT 
    CONVERT (varchar(30), @runtime, 126) AS 'runtime', cntr_value,
    SUBSTRING ([object_name], CHARINDEX (':', [object_name]) + 1, 30) AS [object_name], 
    LEFT (counter_name, 40) AS 'counter_name', LEFT (instance_name, 50) AS 'instance_name'
  FROM sys.dm_os_performance_counters 
  WHERE 
       ([object_name] LIKE '%:Memory Manager%' COLLATE Latin1_General_BIN     AND counter_name COLLATE Latin1_General_BIN IN ('Connection Memory (KB)', 'Granted Workspace Memory (KB)', 'Lock Memory (KB)', 'Memory Grants Outstanding', 'Memory Grants Pending', 'Optimizer Memory (KB)', 'SQL Cache Memory (KB)'))
    OR ([object_name] LIKE '%:Buffer Manager%' COLLATE Latin1_General_BIN     AND counter_name COLLATE Latin1_General_BIN IN ('Buffer cache hit ratio', 'Buffer cache hit ratio base', 'Page lookups/sec', 'Page life expectancy', 'Lazy writes/sec', 'Page reads/sec', 'Page writes/sec', 'Checkpoint pages/sec', 'Free pages', 'Total pages', 'Target pages', 'Stolen pages'))
    OR ([object_name] LIKE '%:General Statistics%' COLLATE Latin1_General_BIN AND counter_name COLLATE Latin1_General_BIN IN ('User Connections', 'Transactions', 'Processes blocked'))
    OR ([object_name] LIKE '%:Access Methods%' COLLATE Latin1_General_BIN     AND counter_name COLLATE Latin1_General_BIN IN ('Index Searches/sec', 'Pages Allocated/sec', 'Table Lock Escalations/sec'))
    OR ([object_name] LIKE '%:SQL Statistics%' COLLATE Latin1_General_BIN     AND counter_name COLLATE Latin1_General_BIN IN ('Batch Requests/sec', 'Forced Parameterizations/sec', 'SQL Compilations/sec', 'SQL Re-Compilations/sec', 'SQL Attention rate'))
    OR ([object_name] LIKE '%:Transactions%' COLLATE Latin1_General_BIN       AND counter_name COLLATE Latin1_General_BIN IN ('Transactions', 'Snapshot Transactions', 'Longest Transaction Running Time', 'Free Space in tempdb (KB)', 'Version Generation rate (KB/s)'))
    OR ([object_name] LIKE '%:CLR%' COLLATE Latin1_General_BIN                AND counter_name COLLATE Latin1_General_BIN IN ('CLR Execution'))
    OR ([object_name] LIKE '%:Wait Statistics%' COLLATE Latin1_General_BIN    AND instance_name COLLATE Latin1_General_BIN IN ('Waits in progress', 'Average wait time (ms)'))
    OR ([object_name] LIKE '%:Exec Statistics%' COLLATE Latin1_General_BIN    AND instance_name COLLATE Latin1_General_BIN IN ('Average execution time (ms)', 'Execs in progress', 'Cumulative execution time (ms) per second'))
    OR ([object_name] LIKE '%:Plan Cache%' COLLATE Latin1_General_BIN             AND instance_name = '_Total' COLLATE Latin1_General_BIN AND counter_name COLLATE Latin1_General_BIN IN ('Cache Hit Ratio', 'Cache Hit Ratio Base', 'Cache Pages', 'Cache Object Counts'))
    OR ([object_name] LIKE '%:Locks%' COLLATE Latin1_General_BIN                  AND instance_name = '_Total' COLLATE Latin1_General_BIN AND counter_name COLLATE Latin1_General_BIN IN ('Lock Requests/sec', 'Number of Deadlocks/sec', 'Lock Timeouts (timeout > 0)/sec'))
    OR ([object_name] LIKE '%:Databases%' COLLATE Latin1_General_BIN              AND instance_name = '_Total' COLLATE Latin1_General_BIN AND counter_name COLLATE Latin1_General_BIN IN ('Data File(s) Size (KB)', 'Log File(s) Size (KB)', 'Log File(s) Used Size (KB)', 'Active Transactions', 'Transactions/sec', 'Bulk Copy Throughput/sec', 'Backup/Restore Throughput/sec', 'DBCC Logical Scan Bytes/sec', 'Log Flush Wait Time', 'Log Growths', 'Log Shrinks'))
    OR ([object_name] LIKE '%:Cursor Manager by Type%' COLLATE Latin1_General_BIN AND instance_name = '_Total' COLLATE Latin1_General_BIN AND counter_name COLLATE Latin1_General_BIN IN ('Cached Cursor Counts', 'Cursor Requests/sec', 'Cursor memory usage'))
    OR ([object_name] LIKE '%:Catalog Metadata%' COLLATE Latin1_General_BIN       AND instance_name = '_Total' COLLATE Latin1_General_BIN AND counter_name COLLATE Latin1_General_BIN IN ('Cache Hit Ratio', 'Cache Hit Ratio Base', 'Cache Entries Count'))
  
  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats2 qry3 - ' + CONVERT (varchar, @queryduration) + 'ms' + CHAR(13) + CHAR(10)


  /* Resultset #4: SQL processor utilization */
  PRINT ''
  RAISERROR ('-- Recent SQL Processor Utilization (Health Records) --', 0, 1) WITH NOWAIT;
  SET @querystarttime = GETDATE()

  if @firstrun=1
  begin
  SELECT /*TOP 5*/
    
      CONVERT (varchar(30), @runtime, 126) AS 'runtime', 
      record.value('(Record/@id)[1]', 'int') AS 'record_id',
      CONVERT (varchar, DATEADD (ms, -1 * (inf.ms_ticks - [timestamp]), GETDATE()), 126) AS 'EventTime', [timestamp], 
      record.value('(Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS 'system_idle_cpu',
      record.value('(Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS 'sql_cpu_utilization' 
    FROM sys.dm_os_sys_info inf CROSS JOIN (
      SELECT timestamp, CONVERT (xml, record) AS 'record' 
      FROM sys.dm_os_ring_buffers 
      WHERE ring_buffer_type = 'RING_BUFFER_SCHEDULER_MONITOR'
        AND record LIKE '%<SystemHealth>%') AS t
    ORDER BY record.value('(Record/@id)[1]', 'int') DESC
   end
  else
  begin
	  SELECT TOP 5
      CONVERT (varchar(30), @runtime, 126) AS 'runtime', 
      record.value('(Record/@id)[1]', 'int') AS 'record_id',
      CONVERT (varchar, DATEADD (ms, -1 * (inf.ms_ticks - [timestamp]), GETDATE()), 126) AS 'EventTime', [timestamp], 
      record.value('(Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS 'system_idle_cpu',
      record.value('(Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS 'sql_cpu_utilization' 
    FROM sys.dm_os_sys_info inf CROSS JOIN (
      SELECT timestamp, CONVERT (xml, record) AS 'record'
      FROM sys.dm_os_ring_buffers 
      WHERE ring_buffer_type = 'RING_BUFFER_SCHEDULER_MONITOR'
        AND record LIKE '%<SystemHealth>%') AS t
    ORDER BY record.value('(Record/@id)[1]', 'int') DESC
  end
    
  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats2 qry4 - ' + CONVERT (varchar, @queryduration) + 'ms' + CHAR(13) + CHAR(10)


  /* Resultset #5: sys.dm_os_sys_info 
  ** used to determine the # of CPUs SQL is able to use at the moment */
  PRINT ''
  RAISERROR ('-- sys.dm_os_sys_info --', 0, 1) WITH NOWAIT;
  SELECT CONVERT (varchar(30), @runtime, 126) AS 'runtime', * FROM sys.dm_os_sys_info


  /* Resultset #6: sys.dm_os_latch_stats */
  PRINT ''
  RAISERROR ('-- sys.dm_os_latch_stats --', 0, 1) WITH NOWAIT;
  SELECT CONVERT (varchar(30), @runtime, 126) AS 'runtime', waiting_requests_count, wait_time_ms, max_wait_time_ms, latch_class
    FROM sys.dm_os_latch_stats 
	WHERE waiting_requests_count > 0 OR wait_time_ms > 0 OR max_wait_time_ms > 0
    ORDER BY wait_time_ms DESC


  /* Resultset #7: File Stats Full
  ** To conserve space, output full dbname and filenames on 1st execution only. */
  PRINT ''
  RAISERROR ('-- File Stats (full) --', 0, 1) WITH NOWAIT;
  SET @sql = 'SELECT /* sp_perf_stats_infrequent11:7 */ CONVERT (varchar(30), @runtime, 126) AS runtime, 
    fs.DbId, fs.FileId, 
    fs.IoStallMS / (fs.NumberReads + fs.NumberWrites + 1) AS AvgIOTimeMS, fs.[TimeStamp], fs.NumberReads, fs.BytesRead, 
    fs.IoStallReadMS, fs.NumberWrites, fs.BytesWritten, fs.IoStallWriteMS, fs.IoStallMS, fs.BytesOnDisk, 
    f.type, LEFT (f.type_desc, 10) AS type_desc, f.data_space_id, f.state, LEFT (f.state_desc, 15) AS state_desc, 
    f.[size], f.max_size, f.growth, f.is_sparse, f.is_percent_growth'

  IF @firstrun = 0 
    SET @sql = @sql + ', NULL AS [database], NULL AS [file]'
  ELSE
    SET @sql = @sql + ', d.name AS [database], f.physical_name AS [file]'
  SET @sql = @sql + 'FROM ::fn_virtualfilestats (null, null) fs
  INNER JOIN master.dbo.sysdatabases d ON d.dbid = fs.DbId
  INNER JOIN sys.master_files f ON fs.DbId = f.database_id AND fs.FileId = f.[file_id]
  ORDER BY AvgIOTimeMS DESC'

  IF '%runmode%' = 'REALTIME' 
    SET @sql = 'INSERT /* sp_perf_stats_infrequent11:7a */ INTO tbl_FILE_STATS ' + @sql 
  SET @querystarttime = GETDATE()

  EXEC sp_executesql @sql, N'@runtime datetime', @runtime = @runtime

  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats2 qry7 - ' + CONVERT (varchar, @queryduration) + 'ms' + CHAR(13) + CHAR(10)

 
  /* Resultset #8: dm_exec_query_resource_semaphores 
  ** no reason to list columns since no long character columns */
  PRINT ''
  RAISERROR ('-- dm_exec_query_resource_semaphores --', 0, 1) WITH NOWAIT;
  SELECT CONVERT (varchar(30), @runtime, 126) AS 'runtime', * from sys.dm_exec_query_resource_semaphores


  /* Resultset #9: dm_exec_query_memory_grants */
  PRINT ''
  RAISERROR ('-- dm_exec_query_memory_grants --', 0, 1) WITH NOWAIT;
  SELECT CONVERT (varchar(30), @runtime, 126) AS 'runtime', session_id, request_id, scheduler_id, dop, request_time, grant_time, requested_memory_kb, granted_memory_kb, required_memory_kb, used_memory_kb, max_used_memory_kb, query_cost, timeout_sec, resource_semaphore_id, queue_id, wait_order, is_next_candidate, wait_time_ms, group_id, pool_id, is_small ideal_memory_kb, plan_handle, [sql_handle] from sys.dm_exec_query_memory_grants


  /* Resultset #10: dm_os_memory_brokers */
  PRINT ''
  RAISERROR ('-- dm_os_memory_brokers --', 0, 1) WITH NOWAIT;
  SELECT CONVERT (varchar(30), @runtime, 126) AS 'runtime', pool_id, allocations_kb, allocations_kb_per_sec, predicted_allocations_kb, target_allocations_kb, future_allocations_kb, overall_limit_kb, last_notification, memory_broker_type from sys.dm_os_memory_brokers

  /* Resultset #11: dm_os_schedulers 
  ** no reason to list columns since no long character columns */
  PRINT ''
  RAISERROR ('-- dm_os_schedulers --', 0, 1) WITH NOWAIT;
  select CONVERT (varchar(30), @runtime, 126) as 'runtime', * from sys.dm_os_schedulers


  /* Resultset #12: dm_os_nodes */
  PRINT ''
  RAISERROR ('-- sys.dm_os_nodes --', 0, 1) WITH NOWAIT;
  SELECT CONVERT (varchar(30), @runtime, 126) as 'runtime', node_id, memory_object_address, memory_clerk_address, io_completion_worker_address, memory_node_id, cpu_affinity_mask, online_scheduler_count, idle_scheduler_count, active_worker_count, avg_load_balance, timer_task_affinity_mask, permanent_task_affinity_mask, resource_monitor_state, online_scheduler_mask, processor_group, node_state_desc FROM sys.dm_os_nodes


  /* Resultset #13: dm_os_memory_nodes 
  ** no reason to list columns since no long character columns */
  PRINT ''
  RAISERROR ('-- sys.dm_os_memory_nodes --', 0, 1) WITH NOWAIT;
  SELECT CONVERT (varchar(30), @runtime, 126) as 'runtime',* FROM sys.dm_os_memory_nodes


  /* Resultset #14: Lock summary */
  PRINT ''
  RAISERROR ('-- Lock summary --', 0, 1) WITH NOWAIT;
  SET @querystarttime = GETDATE()

  select CONVERT (varchar(30), @runtime, 126) as 'runtime', * from 
    (select  count (*) as 'LockCount', Resource_database_id, LEFT(resource_type,15) as 'resource_type', LEFT(request_mode,20) as 'request_mode', request_status from sys.dm_tran_locks 
      group by  Resource_database_id, resource_type, request_mode, request_status ) t

  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats2 qry14 - ' + CONVERT (varchar, @queryduration) + 'ms' + CHAR(13) + CHAR(10)


  /* Resultset #15: Thread Statistics */
  PRINT ''
  RAISERROR ('-- Thread Statistics --', 0, 1) WITH NOWAIT
  SET @querystarttime = GETDATE()

  select CONVERT (varchar(30), @runtime, 126) as 'runtime', th.os_thread_id, ta.scheduler_id, ta.session_id, ta.request_id, req.command, usermode_time, kernel_time, req.cpu_time as 'req_cpu_time',  req.logical_reads,req.total_elapsed_time,
      REPLACE (REPLACE (SUBSTRING (sql.[text], CHARINDEX ('CREATE ', CONVERT (nvarchar(512), SUBSTRING (sql.[text], 1, 1000)) COLLATE Latin1_General_BIN), 50) COLLATE Latin1_General_BIN, CHAR(10), ' '), CHAR(13), ' ') as 'QueryText'
    from sys.dm_os_threads th join sys.dm_os_tasks ta on th.worker_address = ta.worker_address
      left outer join sys.dm_exec_requests req on ta.session_id = req.session_id and ta.request_id = req.request_id
      outer apply sys.dm_exec_sql_text (req.sql_handle) sql

  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats2 qry15 - ' + CONVERT (varchar, @queryduration) + 'ms' + CHAR(13) + CHAR(10)


  /* Resultset #16: dm_db_file_space_usage 
  ** must be run from tempdb */
  PRINT ''
  RAISERROR ('-- dm_db_file_space_usage --', 0, 1) WITH NOWAIT;
  SET @querystarttime = GETDATE()

  SELECT CONVERT (varchar(30), @runtime, 126) AS 'runtime', * FROM sys.dm_db_file_space_usage

  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats2 qry16 - ' + CONVERT (varchar, @queryduration) + 'ms' + CHAR(13) + CHAR(10)


  /* Resultset #17: dm_exec_cursors(0) */
  PRINT ''
  RAISERROR ('-- dm_exec_cursors(0) --', 0, 1) WITH NOWAIT;
  SET @querystarttime = GETDATE()

  SELECT CONVERT (varchar(30), @runtime, 126) AS 'runtime', COUNT(*) AS 'count', SUM(CONVERT(INT,is_open)) AS 'open count', MIN(creation_time) AS 'oldest create',[properties]
    FROM sys.dm_exec_cursors(0)
    GROUP BY [properties]

  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats2 qry17 - ' + CONVERT (varchar, @queryduration) + 'ms' + CHAR(13) + CHAR(10)


  /* Resultset #18:  dm_os_ring_buffers for connectivity*/
  PRINT ''
  RAISERROR ('-- dm_os_ring_buffers --', 0, 1) WITH NOWAIT;
  SET @querystarttime = GETDATE()
  declare @ts bigint
  declare @timediff bigint = 1000*60*2 --2 min in milliseconds
  select @ts = ms_ticks from sys.dm_os_sys_info
  if @ts < @timediff
  begin
	  set @ts = 0
  end
  else
  begin
	  set @ts = @ts - @timediff
  end

  SET @sql = 'SELECT /*sp_perf_stats_infrequent11:18*/ CONVERT (varchar(30), @runtime, 126) AS runtime, 
      CONVERT (varchar(23), DATEADD (ms, -1 * (inf.ms_ticks - rb.[timestamp]), GETDATE()), 126) AS EventTime, rb.[record]
    FROM sys.dm_os_sys_info inf 
      CROSS JOIN 
      (
        SELECT [timestamp], [record] 
          FROM sys.dm_os_ring_buffers 
          WHERE ring_buffer_type in (''RING_BUFFER_CONNECTIVITY'',''RING_BUFFER_SECURITY_ERROR'')'
  IF @firstrun = 0
    SET @sql = @sql + '            AND [timestamp] > @ts'
  SET @sql = @sql + '      ) as rb
    ORDER BY rb.[timestamp] DESC'

  EXEC sp_executesql @sql, N'@runtime datetime, @ts bigint', @runtime = @runtime, @ts = @ts

  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats2 qry18 - ' + CONVERT (varchar, @queryduration) + 'ms' + CHAR(13) + CHAR(10)


  /* Resultset #19: Plan Cache Stats */
  PRINT ''
  RAISERROR ('-- Plan Cache Stats --', 0, 1) WITH NOWAIT;
  SET @querystarttime = GETDATE()

  SELECT CONVERT (varchar(30), @runtime, 126) AS 'runtime',*  from 
    (select  objtype, sum(cast(size_in_bytes as bigint) /cast(1024.00 as decimal(38,2)) /1024.00) 'Cache_Size_MB' , count_big (*) 'Entry_Count', isnull(db_name(cast (value as int)),'mssqlsystemresource') 'db name'
	  from  sys.dm_exec_cached_plans AS p CROSS APPLY sys.dm_exec_plan_attributes ( plan_handle ) as t 
      where attribute='dbid'
      group by  isnull(db_name(cast (value as int)),'mssqlsystemresource'), objtype )  t
    order by Entry_Count desc

  SET @queryduration = DATEDIFF (ms, @querystarttime, GETDATE())
  IF @queryduration > @qrydurationwarnthreshold
    PRINT 'DebugPrint: perfstats2 qry19 - ' + CONVERT (varchar, @queryduration) + 'ms' + CHAR(13) + CHAR(10)

  /* Raise a diagnostic message if we use more CPU than normal (a typical execution uses <200ms) */
  DECLARE @cpu_time bigint, @elapsed_time bigint
  SELECT @cpu_time = cpu_time - @cpu_time_start, @elapsed_time = total_elapsed_time - @elapsed_time_start FROM sys.dm_exec_sessions WHERE session_id = @@SPID
  IF (@elapsed_time > 3000 OR @cpu_time > 1000) BEGIN
    PRINT ''
    PRINT 'DebugPrint: perfstats2 tot - ' + CONVERT (varchar, @elapsed_time) + 'ms elapsed, ' + CONVERT (varchar, @cpu_time) + 'ms cpu' + CHAR(13) + CHAR(10)  
  END

  RAISERROR ('', 0, 1) WITH NOWAIT;
GO

DECLARE @servermajorversion int
-- SERVERPROPERTY ('ProductVersion') returns e.g. "9.00.2198.00" --> 9
SET @servermajorversion = REPLACE (LEFT (CONVERT (varchar, SERVERPROPERTY ('ProductVersion')), 2), '.', '')
IF (@servermajorversion < 11)
  PRINT 'This script only runs on SQL Server 2012 and later. Exiting.'
ELSE BEGIN
  -- Main loop
  DECLARE @i int
  DECLARE @msg varchar(100)
  DECLARE @runtime datetime
  SET @i = 0
  WHILE (1=1)
  BEGIN
    SET @runtime = GETDATE()
    SET @msg = 'Start time: ' + CONVERT (varchar(30), @runtime, 126)
    IF '%runmode%' = 'REALTIME' 
      INSERT INTO tbl_RUNTIMES (runtime, source_script) VALUES (@runtime, 'SQL 2012 Perf Stats Script')
    PRINT ''
    RAISERROR (@msg, 0, 1) WITH NOWAIT
  
    -- Collect sp_perf_stats10 every 10 seconds
    EXEC sp_perf_stats11 @appname = '%appname%', @runtime = @runtime

    -- Collect sp_perf_stats_infrequent10 every minute
    IF @i = 0
      EXEC sp_perf_stats_infrequent11 @runtime = @runtime, @firstrun = 1
    ELSE IF @i % 6 = 0
      EXEC sp_perf_stats_infrequent11 @runtime = @runtime
  
    WAITFOR DELAY '0:0:10'
    SET @i = @i + 1
  END
END
GO
