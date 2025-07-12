
set statistics io off
set nocount on
go
IF OBJECT_ID('ExecutiveSummary_Concurrency') IS NOT NULL
DROP PROCEDURE ExecutiveSummary_Concurrency
GO
CREATE PROCEDURE [dbo].[ExecutiveSummary_Concurrency]
AS
BEGIN
	DECLARE @Output TABLE(ID INT IDENTITY, Msg VARCHAR(MAX))

	IF OBJECT_ID('tempdb..#BlockedProcessOverview') IS NOT NULL
	DROP TABLE #BlockedProcessOverview

	CREATE TABLE #BlockedProcessOverview
	(
		CounterName VARCHAR(200),
		CounterAvg VARCHAR(30),
		CounterMin VARCHAR(30),
		CounterMax VARCHAR(30)
	)
	INSERT INTO #BlockedProcessOverview
	EXECUTE GetBlockedProcessOverview

	DECLARE @CounterAvgLockWaits DECIMAL(18,2), @CounterMinLockWaits DECIMAL(18,2), @CounterMaxLockWaits DECIMAL(18,2)
	DECLARE @CounterAvgBlocked DECIMAL(18,2), @CounterMinBlocked DECIMAL(18,2), @CounterMaxBlocked DECIMAL(18,2)
	SELECT
		@CounterAvgLockWaits = CounterAvg,
		@CounterMinLockWaits = CounterMin
		--@CounterMaxLockWaits = CAST(CounterMax AS DECIMAL(18,2))
	FROM #BlockedProcessOverview
	WHERE CounterName = 'Lock waits (ms)'
	
	SELECT
		@CounterAvgBlocked = CounterAvg, 
		@CounterMinBlocked = CounterMin
		--@CounterMaxBlocked = CAST(CounterMax AS DECIMAL(18,2))
	FROM #BlockedProcessOverview
	WHERE CounterName = 'Processes blocked'
	

	IF @CounterAvgLockWaits > 100
	BEGIN
		INSERT INTO @Output
		SELECT 'The average time spent waiting for a lock request to be granted on this system is ' + CAST(@CounterAvgLockWaits AS VARCHAR(20)) + ' milliseconds.'
	END

	IF @CounterAvgBlocked > 2
	BEGIN
		INSERT INTO @Output
		SELECT 'The average number of processes being blocked on this system at any given time during the capture was ' + CAST(@CounterAvgBlocked AS VARCHAR(20)) + '. Consider enabling RCSI.'
	END

	IF NOT EXISTS(SELECT * FROM @Output)
	BEGIN
		SELECT Msg = 'No concurrency issues detected in the captured workload.'
	END
	ELSE
	BEGIN
		SELECT Msg FROM @Output
	END
END
GO



