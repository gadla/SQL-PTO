SET QUOTED_IDENTIFIER ON
SET NOCOUNT ON

PRINT '--DefaultTraceData'
DECLARE @path VARCHAR(500)
SELECT @path = CAST(value AS VARCHAR(500))
FROM ::fn_trace_getinfo(default) 
WHERE TraceID = 1 AND CAST(value AS VARCHAR(500)) LIKE '%:\%'

SELECT * 
FROM fn_trace_gettable
(@path, default)
GO