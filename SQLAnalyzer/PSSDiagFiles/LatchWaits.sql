SET NOCOUNT ON
PRINT '-- LatchWaits'
SELECT AvgWaitTimeMS = CASE WHEN wait_time_ms = 0 THEN 0 ELSE waiting_requests_count/wait_time_ms END,*
FROM sys.dm_os_latch_stats
ORDER BY wait_time_ms DESC