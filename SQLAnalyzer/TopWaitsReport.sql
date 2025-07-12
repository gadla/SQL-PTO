/*
CREATE TABLE #WaitsCapture(WaitType VARCHAR(100), WaitCount BIGINT, Percentage DECIMAL(18,3), AvgWaitTimeSec DECIMAL(18,3))

INSERT INTO #WaitsCapture
EXECUTE GetWaitsForCapture


CREATE TABLE #WaitsOverall(WaitType VARCHAR(100), WaitCount BIGINT, Percentage DECIMAL(18,3), AvgWaitTimeSec DECIMAL(18,3))

INSERT INTO #WaitsOverall
EXECUTE GetWaits


SELECT a.*
INTO #TopWaitOverall
FROM (
SELECT RowNo = ROW_NUMBER() OVER(ORDER BY Percentage DESC), *
FROM #WaitsCapture
) a 
JOIN 
(
SELECT RowNo = ROW_NUMBER() OVER(ORDER BY Percentage DESC), *
FROM #WaitsOverall
) b ON a.WaitType = b.WaitType AND a.RowNo = b.RowNo AND
a.RowNo = 1 AND
a.Percentage > 50

IF EXISTS(
SELECT * FROM #TopWaitOverall
)
BEGIN
	--overall waits and waits for capture is the same and is > 50 %
	DECLARE @TopWaitType VARCHAR(100), @TopWaitCount BIGINT, @TopWaitPercentage DECIMAL(18,3), @TopWaitAvgWaitTimeSec DECIMAL(18,3)

	SELECT 
		@TopWaitType = WaitType , @TopWaitCount = WaitCount, @TopWaitPercentage= Percentage, @TopWaitAvgWaitTimeSec = AvgWaitTimeSec
	FROM #TopWaitOverall

	IF @TopWaitType = 'CXPACKET'
	BEGIN
	
	CREATE TABLE #Config(Name varchar(1000), run_value varchar(100))
	INSERT INTO #Config
	EXECUTE GetSystemConfiguration

	END

END
*/