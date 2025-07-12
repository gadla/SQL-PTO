SELECT TracePath = REVERSE(SUBSTRING(REVERSE(path), CHARINDEX('\', REVERSE(path)), LEN(path))) + '*.trc'
FROM sys.traces
