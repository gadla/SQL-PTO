
set statistics io off
set nocount on
go
IF OBJECT_ID('Summary_ExpensiveQueries') IS NOT NULL
DROP PROCEDURE Summary_ExpensiveQueries
GO

CREATE PROCEDURE Summary_ExpensiveQueries
AS
BEGIN

	DECLARE @ExpensiveQueryCount BIGINT, @MaxLogicalReads BIGINT

	IF OBJECT_ID('cust_ExpensiveQueries') IS NOT NULL
	BEGIN
		select @ExpensiveQueryCount = COUNT_BIG(*), @MaxLogicalReads = MAX(CAST(AverageLogicalReads AS BIGINT)) from cust_ExpensiveQueries
		WHERE CAST(AverageLogicalReads AS BIGINT)> 1000000

		IF @ExpensiveQueryCount > 0
		BEGIN
		DECLARE @SQL NVARCHAR(MAX)
		SET @SQL = 'There have been ' + CAST(@ExpensiveQueryCount AS VARCHAR(20)) + ' queries on this system with more than 1M logical reads. '
		SET @SQL = @SQL + ' A logical read is an 8K data or index page read from SQL Server''s buffer pool.  In general, the more pages that a '
		SET @SQL = @SQL + 'query causes to be read from the buffer pool, the more expensive (and longer running) that query is. The attached '
		SET @SQL = @SQL + 'Excel document has a worksheet named "ExpensiveQueries" that outlines the most expensive queries currently executing '
		SET @SQL = @SQL + 'on the system.'
		SET @SQL = @SQL + CHAR(10) + CHAR(10)
		SET @SQL = @SQL + 'In some cases, simply adding indexes suggested on the Excel worksheet (UsefulIndexes) can assist in execution time '
		SET @SQL = @SQL + 'for these queries.  In other cases more advanced tuning techniques may be necessary.'
		PRINT @SQL
	END

	

	END
END
GO
