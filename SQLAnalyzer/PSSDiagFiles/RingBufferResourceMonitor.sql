SET NOCOUNT ON
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
PRINT '-- RingBufferResourceMonitor'
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
