SET NOCOUNT ON
PRINT '-- DBFileSizes'
SELECT 
DBName = d.name, 
LogicalName = mf.name,
FilePath = physical_name,
InitialSizeInMB = (size*8.0)/1024.0, 
SizeInMB = (size_on_disk_bytes *8.0)/1024.0, 
Growth = CASE WHEN is_percent_growth = 1 THEN CAST(growth AS VARCHAR(10)) + ' %' ELSE CAST((growth/128) AS VARCHAR(10)) + ' MB' END, 
AverageReadStallMS = fs.io_stall_read_ms/(fs.num_of_reads+1),
AverageWriteStallMS = fs.io_stall_write_ms/(fs.num_of_writes+1),
SizeInMB2 = fs.size_on_disk_bytes/1024.0/1024.0,
AverageIOStallMS = io_stall/(num_of_reads + num_of_writes + 1),
fs.num_of_reads,
fs.num_of_bytes_read,
fs.io_stall_read_ms,
fs.num_of_writes,
fs.num_of_bytes_written,
fs.io_stall_write_ms,
fs.io_stall,
fs.size_on_disk_bytes
FROM sys.master_files mf
JOIN sys.databases d ON mf.database_id = d.database_id 
JOIN sys.dm_io_virtual_file_stats(NULL, NULL) fs ON fs.database_id = mf.database_id AND fs.file_id = mf.file_id
 