SET NOCOUNT ON
SET STATISTICS IO OFF

IF OBJECT_ID('tempdb..#Stats') IS NOT NULL
DROP TABLE #Stats
GO
DECLARE @MainSQL NVARCHAR(MAX)

CREATE TABLE #Stats
(
	StatName VARCHAR(1000), 
	Updated DATETIME, 
	RowCnt BIGINT, 
	RowsSampled BIGINT, 
	Steps TINYINT,
	Density DECIMAL, 
	AvgKeyLength BIGINT,
	StringIndex VARCHAR(100)
)
DECLARE @ProductVersion VARCHAR(30), @MajorVersion INT
SET @ProductVersion = CONVERT(VARCHAR(20),SERVERPROPERTY('ProductVersion'))
SELECT @MajorVersion = LEFT(@ProductVersion,CHARINDEX('.',@ProductVersion)-1)

IF @MajorVersion >=10
BEGIN
	ALTER TABLE #Stats
	ADD
		FilterExpression VARCHAR(2000),
		UnfilteredRows BIGINT
END

ALTER TABLE #Stats
ADD TableName VARCHAR(1000), DBName SYSNAME, RowMods BIGINT

SET @MainSQL = 'USE [?] 
IF DB_NAME() NOT IN(''tempdb'',''master'',''model'',''msdb'',''resourcedb'')
BEGIN

	DECLARE 
		@TableName VARCHAR(255), 
		@IndexName VARCHAR(255), 
		@SQL NVARCHAR(MAX), 
		@Insert NVARCHAR(MAX), 
		@RowMods BIGINT

	DECLARE StatsCursor 
	CURSOR FOR 
		SELECT s.name + ''.'' + t.name, i.name, rowmodctr
		FROM sys.tables t 
		JOIN sys.schemas s ON t.schema_id = s.schema_id
		JOIN sys.sysindexes i ON t.object_id = i.id
		WHERE t.type = ''U'' AND i.name IS NOT NULL

	OPEN StatsCursor;

	FETCH NEXT FROM StatsCursor 
	INTO @TableName, @IndexName, @RowMods

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @SQL = ''''
		SET @SQL = ''EXECUTE(''''DBCC SHOW_STATISTICS ('''''''''' + @TableName + '''''''''', '''''''''' + @IndexName + '''''''''') WITH STAT_HEADER'''')''
		
		SET @Insert = '' INSERT INTO #Stats
		(
			StatName ,
			Updated ,
			RowCnt ,
			RowsSampled ,
			Steps ,
			Density ,
			AvgKeyLength ,
			StringIndex''
		
		SET @Insert = @Insert + 
		CASE 
			WHEN CAST(' + CAST(@MajorVersion AS NVARCHAR(20)) + ' AS BIGINT) >= 10
			THEN '', 
			FilterExpression ,
			UnfilteredRows) ''
			ELSE '') ''
		END + @SQL
		--PRINT @Insert
		EXECUTE(@Insert)

		UPDATE #Stats
		SET TableName = @TableName, 
			RowMods = @RowMods
		WHERE TableName IS NULL
		
		FETCH NEXT FROM StatsCursor 
		INTO @TableName, @IndexName, @RowMods
	END
	CLOSE StatsCursor;
	DEALLOCATE StatsCursor;

	UPDATE #Stats
	SET DBName = ''?''
	WHERE DBName IS NULL

END'

EXECUTE sp_MSforeachdb @MainSQL

PRINT '-- GetStats'
SELECT * FROM #Stats