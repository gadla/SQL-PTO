SET NOCOUNT ON
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
PRINT '-- RingBufferSchedulerMonitor'
SELECT
	'RING_BUFFER_SCHEDULER_MONITOR' AS RingType, 
	DATEADD(ms, -1 * ((SELECT ms_ticks FROM sys.dm_os_sys_info) - [timestamp]), GETDATE()) AS EventTime,
	*
FROM (
	SELECT 
		record.value('(./Record/@id)[1]', 'bigint') AS record_id,
		record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'bigint') AS SystemIdle,
		record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'bigint') AS SQLProcessUtilization,
		record.value('(./Record/SchedulerMonitorEvent/SystemHealth/UserModeTime)[1]', 'bigint') AS UserModeTime,
		record.value('(./Record/SchedulerMonitorEvent/SystemHealth/KernelModeTime)[1]', 'bigint') AS KernelModeTime,
		record.value('(./Record/SchedulerMonitorEvent/SystemHealth/PageFaults)[1]', 'bigint') AS PageFaults,
		record.value('(./Record/SchedulerMonitorEvent/SystemHealth/WorkingSetDelta)[1]', 'bigint') AS WorkingSetDelta,
		record.value('(./Record/SchedulerMonitorEvent/SystemHealth/MemoryUtilization)[1]', 'bigint') AS MemoryUtilPct,
		timestamp
	FROM (
		SELECT timestamp, CONVERT(XML, record) AS record 
		FROM sys.dm_os_ring_buffers 
		WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
		AND record LIKE '%<SystemHealth>%') AS x
	) AS y
ORDER BY record_id DESC