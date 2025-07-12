SET NOCOUNT ON
IF object_id('tempdb..#loginfo')IS NOT NULL
DROP TABLE #loginfo
go
CREATE TABLE #loginfo
(
recoveryunitid INT, 
fileid VARCHAR(255), 
filesize VARCHAR(255), 
startoffset VARCHAR(255), 
fseqno VARCHAR(255), 
STATUS VARCHAR(255), 
parity VARCHAR(255), 
createlsn VARCHAR(255), 
dbname VARCHAR(255))
go

DECLARE @name SYSNAME, @SQL NVARCHAR(MAX)

DECLARE Looper 
CURSOR FOR  
	SELECT name FROM sys.databases
	WHERE database_id > 4

OPEN Looper   
FETCH NEXT FROM Looper INTO @name   

WHILE @@FETCH_STATUS = 0   
BEGIN   
	SET @SQL = 'DBCC LOGINFO (''' + @name + ''')'
	INSERT INTO #loginfo
	(
		recoveryunitid,
		fileid, 
		filesize, 
		startoffset, 
		fseqno, 
		STATUS, 
		parity, 
		createlsn
	)
	EXECUTE (@SQL)

	UPDATE #loginfo
	SET dbname = @name
	WHERE dbname IS NULL
	
	FETCH NEXT FROM Looper INTO @name   
END   

CLOSE Looper   
DEALLOCATE Looper 

PRINT '-- LogInfo2012'
SELECT dbname, status, COUNT(*) AS VLFCount
FROM #loginfo
GROUP BY dbname, status
ORDER BY dbname 


