--Last Known Good DBCC CheckDB Date:

IF OBJECT_ID('tempdb..#temp') IS NOT NULL
DROP TABLE #temp
go
CREATE TABLE #temp
(
  ParentObject VARCHAR(255),
  [Object] VARCHAR(255),
  Field VARCHAR(255),
  [Value] VARCHAR(255),
  DBName VARCHAR(255)
)

EXECUTE SP_MSFOREACHDB '
INSERT INTO #temp (ParentObject, Object, Field, Value)
EXEC(''DBCC DBINFO ( ''''?'''') WITH TABLERESULTS'')

UPDATE #temp
SET DBName = ''?''
WHERE DBName IS NULL'

PRINT '-- LastDBCCCheckDBDate'
SELECT DISTINCT 
    DBName,
    LastDBCCDate = CAST(Value AS DATETIME)
FROM
    #temp
WHERE
    Field = 'dbi_dbccLastKnownGood'
