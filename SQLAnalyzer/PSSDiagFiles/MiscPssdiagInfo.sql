set nocount on
declare @startup table (ArgsName nvarchar(128), ArgsValue nvarchar(max))

insert into @startup EXEC master..xp_instance_regenumvalues 'HKEY_LOCAL_MACHINE',   'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\Parameters'

print ''
RAISERROR ('--Startup Parameters--', 0, 1) WITH NOWAIT
select * from @startup
go


if ( CHARINDEX ('11.0', cast (serverproperty ('productversion') as nvarchar(20)))  > 0)
begin
print ''
RAISERROR ('--Hadron Configuration--', 0, 1) WITH NOWAIT
SELECT 
      ag.name AS ag_name, 
      ar.replica_server_name  ,
      ar_state.is_local AS is_ag_replica_local, 
      ag_replica_role_desc = 
            CASE 
                  WHEN ar_state.role_desc IS NULL THEN N'<unknown>'
                  ELSE ar_state.role_desc 
            END, 
      ag_replica_operational_state_desc = 
            CASE 
                  WHEN ar_state.operational_state_desc IS NULL THEN N'<unknown>'
                  ELSE ar_state.operational_state_desc 
            END, 
      ag_replica_connected_state_desc = 
            CASE 
                  WHEN ar_state.connected_state_desc IS NULL THEN 
                        CASE 
                              WHEN ar_state.is_local = 1 THEN N'CONNECTED'
                              ELSE N'<unknown>'
                        END
                  ELSE ar_state.connected_state_desc 
            END
      --ar.secondary_role_allow_read_desc
FROM 

      sys.availability_groups AS ag 
      JOIN sys.availability_replicas AS ar 
      ON ag.group_id = ar.group_id
 
JOIN sys.dm_hadr_availability_replica_states AS ar_state 
ON  ar.replica_id = ar_state.replica_id;


print ''
RAISERROR ('--sys.availability_groups--', 0, 1) WITH NOWAIT
select * from sys.availability_groups


print ''
RAISERROR ('--sys.dm_hadr_availability_group_states--', 0, 1) WITH NOWAIT
select * from sys.dm_hadr_availability_group_states

print ''
RAISERROR ('--sys.dm_hadr_availability_replica_states--', 0, 1) WITH NOWAIT
select * from sys.dm_hadr_availability_replica_states

print ''
RAISERROR ('--sys.availability_replicas--', 0, 1) WITH NOWAIT
select * from sys.availability_replicas

print ''
RAISERROR ('--sys.dm_hadr_database_replica_cluster_states--', 0, 1) WITH NOWAIT
select * from sys.dm_hadr_database_replica_cluster_states

end

go
print ''
RAISERROR ('--database files--', 0, 1) WITH NOWAIT
select db_name(database_id) 'Database_name', * from master.sys.master_files order by database_id, type, file_id

go

print ''
RAISERROR ('--dm_os_sys_info--', 0, 1) WITH NOWAIT
select * from sys.dm_os_sys_info

go
create table #traceflg (TraceFlag int, Status int, Global int, Session int)
insert into #traceflg exec ('dbcc tracestatus (-1)')
print ''
RAISERROR ('--traceflags--', 0, 1) WITH NOWAIT
select * from #traceflg
drop table #traceflg

go
print ''
RAISERROR ('--sys.dm_os_schedulers--', 0, 1) WITH NOWAIT
select * from sys.dm_os_schedulers
go
print ''
RAISERROR ('--sys.dm_os_nodes--', 0, 1) WITH NOWAIT
select * from sys.dm_os_nodes

go
--declare @summary table (PropertyName nvarchar(50) primary key, PropertyValue nvarchar(256))
create table #summary (PropertyName nvarchar(50) primary key, PropertyValue nvarchar(256))
insert into #summary values ('ProductVersion', cast (SERVERPROPERTY('ProductVersion') as nvarchar(max)))
insert into #summary values ('MajorVersion', LEFT(CONVERT(SYSNAME,SERVERPROPERTY('ProductVersion')), CHARINDEX('.', CONVERT(SYSNAME,SERVERPROPERTY('ProductVersion')), 0)-1))
insert into #summary values ('IsClustered', cast (SERVERPROPERTY('IsClustered') as nvarchar(max)))
insert into #summary values ('Edition', cast (SERVERPROPERTY('Edition') as nvarchar(max)))
insert into #summary values ('InstanceName', cast (SERVERPROPERTY('InstanceName') as nvarchar(max)))

insert into #summary values ('SQLServerName', @@SERVERNAME)
insert into #summary values ('MachineName', cast (SERVERPROPERTY('MachineName') as nvarchar(max)))
insert into #summary values ('ProcessID', cast (SERVERPROPERTY('ProcessID') as nvarchar(max)))
insert into #summary values ('ResourceVersion', cast (SERVERPROPERTY('ResourceVersion') as nvarchar(max)))
insert into #summary values ('ServerName', cast (SERVERPROPERTY('ServerName') as nvarchar(max)))
insert into #summary values ('IsHadrEnabled', cast (SERVERPROPERTY('IsHadrEnabled') as nvarchar(max)))
insert into #summary values ('ComputerNamePhysicalNetBIOS', cast (SERVERPROPERTY('ComputerNamePhysicalNetBIOS') as nvarchar(max)))
insert into #summary select 'Number Of Visible Schedulers', count (*) 'cnt' from sys.dm_os_schedulers where status = 'VISIBLE ONLINE'
insert into #summary select 'cpu_count', cpu_count from sys.dm_os_sys_info
insert into #summary select 'hyperthread_ratio', hyperthread_ratio from sys.dm_os_sys_info
if (cast ((LEFT(CONVERT(SYSNAME,SERVERPROPERTY('ProductVersion')), CHARINDEX('.', CONVERT(SYSNAME,SERVERPROPERTY('ProductVersion')), 0)-1)) as int) >=11)
	begin
	exec sp_executesql N'insert into #summary select ''physical_memory_kb'', physical_memory_kb from sys.dm_os_sys_info'
	end
insert into #summary select 'sqlserver_start_time', sqlserver_start_time from sys.dm_os_sys_info
print ''
RAISERROR ('--ServerProperty--', 0, 1) WITH NOWAIT

select * from #summary
order by PropertyName
drop table #summary
go

print ''
RAISERROR ('--sys.configurations--', 0, 1) WITH NOWAIT
select * from sys.configurations order by name
go

print ''
RAISERROR ('--sys.databases_ex--', 0, 1) WITH NOWAIT
select cast(DATABASEPROPERTYEX (name,'IsAutoCreateStatistics') as int) 'IsAutoCreateStatistics', cast( DATABASEPROPERTYEX (name,'IsAutoUpdateStatistics') as int) 'IsAutoUpdateStatistics', cast (DATABASEPROPERTYEX (name,'IsAutoCreateStatisticsIncremental') as int) 'IsAutoCreateStatisticsIncremental', *  from sys.databases

go

