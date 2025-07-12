SET NOCOUNT ON
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
PRINT '-- RingBufferExceptionMonitor'
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