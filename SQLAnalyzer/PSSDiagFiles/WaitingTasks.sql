SET NOCOUNT ON
PRINT '-- WaitingTasks ' + CAST(GETDATE() AS VARCHAR(30))
select t.* 
from sys.dm_os_waiting_tasks t 
join sys.dm_exec_sessions s on t.session_id = s.session_id
where s.is_user_process = 1