SET NOCOUNT ON
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
PRINT '-- RingBufferInformation'
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


go

SELECT 
	'RING_BUFFER_EXCEPTION' AS RingType, 
	DATEADD(ms, -1 * ((SELECT ms_ticks FROM sys.dm_os_sys_info) - [timestamp]), GETDATE()) AS EventTime,
	*
FROM (
	SELECT 
		record.value('(./Record/@id)[1]', 'bigint') AS record_id,
		record.value('(./Record/Exception/Task/@address)[1]', 'varchar(200)') AS TaskAddress,
		record.value('(./Record/Exception/Error)[1]', 'int') AS ErrorNumber,
		record.value('(./Record/Exception/Severity)[1]', 'int') AS Severity,
		record.value('(./Record/Exception/State)[1]', 'int') AS State,
		record.value('(./Record/Exception/UserDefined)[1]', 'int') AS UserDefined,
		timestamp
	FROM (
		SELECT timestamp, CONVERT(XML, record) AS record 
		FROM sys.dm_os_ring_buffers 
		WHERE ring_buffer_type = N'RING_BUFFER_EXCEPTION'
		) AS x
	) AS y
	JOIN sys.messages m ON y.ErrorNumber = m.message_id AND m.severity = y.severity AND language_id = 1033
ORDER BY record_id DESC

go
PRINT '-- RingBufferInformation'
SELECT 
	'RING_BUFFER_RESOURCE_MONITOR' AS RingType, 
	DATEADD(ms, -1 * ((SELECT ms_ticks FROM sys.dm_os_sys_info) - [timestamp]), GETDATE()) AS EventTime,
	*
FROM (
	SELECT 
		record.value('(./Record/@id)[1]', 'bigint') AS record_id,
		record.value('(./Record/ResourceMonitor/Notification)[1]', 'varchar(100)') AS Notification,
		record.value('(./Record/ResourceMonitor/IndicatorsProcess)[1]', 'bit') AS IndicatorsProcess,
		record.value('(./Record/ResourceMonitor/IndicatorsSystem)[1]', 'bit') AS IndicatorsSystem,
		record.value('(./Record/ResourceMonitor/NodeId)[1]', 'bigint') AS NodeId,
		record.value('(./Record/ResourceMonitor/Effect/@type)[1]', 'varchar(100)') AS EffectType1,
		record.value('(./Record/ResourceMonitor/Effect/@state)[1]', 'varchar(100)') AS EffectState1,
		record.value('(./Record/ResourceMonitor/Effect/@reversed)[1]', 'varchar(100)') AS EffectReversed1,
		record.value('(./Record/ResourceMonitor/Effect/@type)[2]', 'varchar(100)') AS EffectType2,
		record.value('(./Record/ResourceMonitor/Effect/@state)[2]', 'varchar(100)') AS EffectState2,
		record.value('(./Record/ResourceMonitor/Effect/@reversed)[2]', 'varchar(100)') AS EffectReversed2,
		record.value('(./Record/ResourceMonitor/Effect/@type)[3]', 'varchar(100)') AS EffectType3,
		record.value('(./Record/ResourceMonitor/Effect/@state)[3]', 'varchar(100)') AS EffectState3,
		record.value('(./Record/ResourceMonitor/Effect/@reversed)[3]', 'varchar(100)') AS EffectReversed3,
		record.value('(./Record/MemoryNode/@id)[1]', 'bigint') AS PageFaults,
		record.value('(./Record/MemoryNode/ReservedMemory)[1]', 'bigint') AS ReservedMemory,
		record.value('(./Record/MemoryNode/CommittedMemory)[1]', 'bigint') AS CommittedMemory,
		record.value('(./Record/MemoryNode/SharedMemory)[1]', 'bigint') AS SharedMemory,
		record.value('(./Record/MemoryNode/AWEMemory)[1]', 'bigint') AS AWEMemory,
		record.value('(./Record/MemoryNode/SinglePagesMemory)[1]', 'bigint') AS SinglePagesMemory,
		record.value('(./Record/MemoryNode/MultiplePagesMemory)[1]', 'bigint') AS MultiplePagesMemory,
		record.value('(./Record/MemoryRecord/MemoryUtilization)[1]', 'bigint') AS MemoryUtilization,
		record.value('(./Record/MemoryRecord/TotalPhysicalMemory)[1]', 'bigint') AS TotalPhysicalMemory,
		record.value('(./Record/MemoryRecord/AvailablePhysicalMemory)[1]', 'bigint') AS AvailablePhysicalMemory,
		record.value('(./Record/MemoryRecord/TotalPageFile)[1]', 'bigint') AS TotalPageFile,
		record.value('(./Record/MemoryRecord/AvailablePageFile)[1]', 'bigint') AS AvailablePageFile,
		record.value('(./Record/MemoryRecord/TotalVirtualAddressSpace)[1]', 'bigint') AS TotalVirtualAddressSpace,
		record.value('(./Record/MemoryRecord/AvailableVirtualAddressSpace)[1]', 'bigint') AS AvailableVirtualAddressSpace,
		record.value('(./Record/MemoryRecord/AvailableExtendedVirtualAddressSpace)[1]', 'bigint') AS AvailableExtendedVirtualAddressSpace,
		timestamp
	FROM (
		SELECT timestamp, CONVERT(XML, record) AS record 
		FROM sys.dm_os_ring_buffers 
		WHERE ring_buffer_type = N'RING_BUFFER_RESOURCE_MONITOR'
		) AS x
	) AS y
ORDER BY record_id DESC
