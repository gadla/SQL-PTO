SET NOCOUNT ON

IF OBJECT_ID('tempdb..#Objects') IS NOT NULL
DROP TABLE #Objects
SELECT TOP(0) DBName = DB_NAME(DB_ID()), *
INTO #Objects
FROM sys.objects

INSERT INTO #Objects
EXECUTE sp_msforeachdb 'USE [?]
SELECT DBName = DB_NAME(DB_ID()), *
FROM sys.objects'

PRINT '-- AllObjects'
SELECT *
FROM #Objects