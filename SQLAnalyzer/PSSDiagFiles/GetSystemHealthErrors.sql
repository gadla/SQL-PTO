SET QUOTED_IDENTIFIER ON
PRINT '--SystemHealthErrors'
SELECT
	'system_health errors' AS ResultsetType,
    errXML.value('(/event/@timestamp)[1]', 'DATETIME') AS EventTime,
    errXML.value('(/event/data/value)[1]', 'INT') AS ErrorNumber,
    errXML.value('(/event/data/value)[2]', 'INT') AS ErrorSeverity,
    errXML.value('(/event/data/value)[3]', 'INT') AS ErrorState,
    errXML.value('(/event/data/value)[5]', 'VARCHAR(MAX)') AS ErrorText,
    errXML.value('(/event/action/value)[2]', 'INT') AS SessionID
FROM
(
	SELECT
		C.query('.') errXML
	FROM
	(
		SELECT
			CAST(xet.target_data AS XML) AS XMLDATA
		FROM
			sys.dm_xe_session_targets xet
			JOIN sys.dm_xe_sessions xe ON xe.address = xet.event_session_address
		WHERE
			xe.name = 'system_health'
	) a
	CROSS APPLY a.XMLDATA.nodes('/RingBufferTarget/event') T(c)
	WHERE
		C.query('.').value('(/event/@name)[1]', 'varchar(500)') = 'error_reported'
)x