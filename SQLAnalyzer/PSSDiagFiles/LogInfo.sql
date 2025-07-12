SET NOCOUNT ON

IF object_id('tempdb..#loginfo')IS NOT NULL
DROP TABLE #loginfo
GO
CREATE TABLE #loginfo
(
IDCol INT IDENTITY(1,1)
)
GO

DECLARE @SQL NVARCHAR(MAX), @ServerProp INT
SET @ServerProp = CAST((SERVERPROPERTY('ProductMajorVersion')) AS INT)
IF @ServerProp >=11
BEGIN
	SET @SQL = N'
	ALTER TABLE #loginfo
	ADD
	recoveryunitid INT, 
	fileid VARCHAR(255), 
	filesize VARCHAR(255), 
	startoffset VARCHAR(255), 
	fseqno VARCHAR(255), 
	STATUS VARCHAR(255), 
	parity VARCHAR(255), 
	createlsn VARCHAR(255), 
	dbname VARCHAR(255)'
	EXECUTE (@SQL)

END
ELSE
BEGIN
	SET @SQL = N'
	ALTER TABLE #loginfo
	ADD
	fileid VARCHAR(255), 
	filesize VARCHAR(255), 
	startoffset VARCHAR(255), 
	fseqno VARCHAR(255), 
	STATUS VARCHAR(255), 
	parity VARCHAR(255), 
	createlsn VARCHAR(255), 
	dbname VARCHAR(255)'
	EXECUTE (@SQL)
END
GO

DECLARE @name SYSNAME, @SQL NVARCHAR(MAX), @ServerProp INT
SET @ServerProp = CAST((SERVERPROPERTY('ProductMajorVersion')) AS INT)

DECLARE Looper 
CURSOR FOR  
	SELECT name FROM sys.databases
	WHERE database_id > 4

OPEN Looper   
FETCH NEXT FROM Looper INTO @name   

WHILE @@FETCH_STATUS = 0   
BEGIN   
	SET @SQL = 'EXECUTE (''DBCC LOGINFO (''''' + @name + ''''')'')'

	IF @ServerProp >=11
	BEGIN
		SET @SQL = 'INSERT INTO #loginfo
		(
			recoveryunitid,
			fileid, 
			filesize, 
			startoffset, 
			fseqno, 
			STATUS, 
			parity, 
			createlsn
		)' + @SQL
		EXECUTE (@SQL)
		PRINT @SQL
	END
	ELSE
	BEGIN
		
		SET @SQL = 'INSERT INTO #loginfo
		(
			fileid, 
			filesize, 
			startoffset, 
			fseqno, 
			STATUS, 
			parity, 
			createlsn
		)' + @SQL
		--EXECUTE (@SQL)
		PRINT @SQL
	END



	UPDATE #loginfo
	SET dbname = @name
	WHERE dbname IS NULL
	
	FETCH NEXT FROM Looper INTO @name   
END   

CLOSE Looper   
DEALLOCATE Looper 

PRINT '-- LogInfo'
SELECT dbname, status, COUNT(*) AS VLFCount
FROM #loginfo
GROUP BY dbname, status
ORDER BY dbname 


