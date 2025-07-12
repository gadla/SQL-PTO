SET NOCOUNT ON
if OBJECT_ID('tempdb..#Results') IS NOT NULL
DROP TABLE #Results
GO
create table #Results
(
	DBName sysname, ObjectName sysname, TypeDesc varchar(400), 
	TotalPages INT, UsedPages INT, DataPages INT, 
	RowCnt INT, PartitionCount INT
)

INSERT INTO #Results
EXECUTE sp_msforeachdb N' USE [?]
select 
	databasename = DB_NAME(),
	ObjectName = o.name, 
	u.type_desc,
	TotalPages = sum(total_pages),
	UsedPages = sum(used_pages),
	DataPages = sum(data_pages),
	RowCnt = sum(rows),
	PartitionCount = count(distinct partition_number)
from sys.allocation_units u with(nolock)
join sys.partitions p  with(nolock) on 
	u.container_id = case when u.type in(1,3) then p.hobt_id else partition_id end
join sys.objects o  with(nolock) on p.object_id = o.object_id 
where o.type = ''u''
group by 	o.name, 
	u.type_desc
	'
PRINT '-- TableAllocations'
select * from #Results
order by RowCnt desc