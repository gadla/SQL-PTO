--You can use the following query to find the top sessions that are allocating internal objects. 
--Note that this query includes only the tasks that have been completed in the sessions.
SET NOCOUNT ON
PRINT '-- TempDBSessionSpaceUsage'
select 
    session_id, 
    internal_objects_alloc_page_count, 
    internal_objects_dealloc_page_count
from sys.dm_db_session_space_usage
order by internal_objects_alloc_page_count DESC

--You can use the following query to find the top user sessions that are allocating internal objects, including currently active tasks.
 
PRINT '-- TempDBTaskSpaceUsage'
SELECT
    t1.session_id,
    (t1.internal_objects_alloc_page_count + task_alloc) AS allocated_pages,
    (t1.internal_objects_dealloc_page_count + task_dealloc) AS deallocated_pages
FROM
    sys.dm_db_session_space_usage AS t1
    JOIN (
     SELECT
        session_id,
        SUM(internal_objects_alloc_page_count) AS task_alloc,
        SUM(internal_objects_dealloc_page_count) AS task_dealloc
     FROM
        sys.dm_db_task_space_usage
     GROUP BY
        session_id
    ) AS t2 ON t1.session_id = t2.session_id
    JOIN sys.dm_exec_sessions s ON t2.session_id = s.session_id AND s.is_user_process = 1
WHERE
    
    t1.session_id > 50
ORDER BY
    allocated_pages DESC



--After you have isolated the task or tasks that are generating a lot of internal object allocations, 
--you can find out which Transact-SQL statement it is and its query plan for a more detailed analysis.
PRINT '-- TempDBTaskAnalysis'
SELECT
    t1.session_id,
    t1.request_id,
    t1.task_alloc,
    t1.task_dealloc,
    t2.sql_handle,
    t2.statement_start_offset,
    t2.statement_end_offset,
    t2.plan_handle
FROM
    (
     SELECT
        session_id,
        request_id,
        SUM(internal_objects_alloc_page_count) AS task_alloc,
        SUM(internal_objects_dealloc_page_count) AS task_dealloc
     FROM
        sys.dm_db_task_space_usage
     GROUP BY
        session_id,
        request_id
    ) t1
    JOIN sys.dm_exec_requests t2 ON 
		t1.session_id = t2.session_id AND
		t1.request_id = t2.request_id
	JOIN sys.dm_exec_sessions s ON t2.session_id = s.session_id AND
		s.is_user_process = 1
  ORDER BY
    t1.task_alloc DESC
