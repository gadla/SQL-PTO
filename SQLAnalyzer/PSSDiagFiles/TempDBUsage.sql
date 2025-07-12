SET NOCOUNT ON

PRINT '-- TempDBUsage'
SELECT TOP 10
     t1.session_id,
     t1.request_id,
     t1.task_alloc,
     t1.task_dealloc,
     t2.plan_handle,
     (SELECT SUBSTRING (text, t2.statement_start_offset/2 + 1,
        (CASE WHEN statement_end_offset = -1
           THEN LEN(CONVERT(nvarchar(MAX),text)) * 2
           ELSE statement_end_offset
        END - t2.statement_start_offset)/2)
     FROM sys.dm_exec_sql_text(sql_handle)) AS query_text
FROM (SELECT session_id, request_id,
        SUM(internal_objects_alloc_page_count +
        user_objects_alloc_page_count) AS task_alloc,
        SUM(internal_objects_dealloc_page_count +
        user_objects_dealloc_page_count) AS task_dealloc
     FROM sys.dm_db_task_space_usage
     GROUP BY session_id, request_id) AS t1,
   sys.dm_exec_requests AS t2
WHERE t1.session_id = t2.session_id AND
   (t1.request_id = t2.request_id) AND t1.session_id > 50
ORDER BY t1.task_alloc DESC

