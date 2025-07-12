set nocount on
set quoted_identifier On

declare @path_to_health_session nvarchar(4000)
declare @UTDDateDiff INT
SET @UTDDateDiff = DATEDIFF(mi,GETUTCDATE(),GETDATE())

select @path_to_health_session = (
select eventfile = cast(target_data as xml)
from sys.dm_xe_sessions s
join sys.dm_xe_session_targets t on s.address = t.event_session_address
where name = 'AlwaysOn_health' and t.target_name = 'event_file'
).value('(./EventFileTarget/File/@name)[1]', 'varchar(2000)')

select @path_to_health_session = left(@path_to_health_session, charindex('AlwaysOn_health', @path_to_health_session)-1)
select @path_to_health_session = @path_to_health_session + 'AlwaysOn_health*.xel'

select @path_to_health_session


--for /F usebackq %%i in (`sqlcmd -E -S "devserver,4711" -h-1 -Q "SET NOCOUNT ON; SELECT COUNT(1) ..."`) do (
--    set count=%%i
--)
