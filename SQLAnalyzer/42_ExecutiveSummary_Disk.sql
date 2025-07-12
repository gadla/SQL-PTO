
set statistics io off
set nocount on
go
IF OBJECT_ID('ExecutiveSummary_Disk') IS NOT NULL
DROP PROCEDURE ExecutiveSummary_Disk
GO
CREATE PROCEDURE [dbo].[ExecutiveSummary_Disk]
AS
BEGIN

	DECLARE @Output TABLE(ID INT IDENTITY, Msg VARCHAR(MAX))

	--Disk 
	--latency?
	--pending IOs?
	--high pageiolatch
	--high disk stalls
	--something competing with sql for IO

	IF EXISTS
	(
		SELECT * 
		FROM [dbo].[PTOClinicFindings]
		WHERE Title = 'Disk response times are too long.'
	)
	BEGIN

		BEGIN
			INSERT INTO @Output
			SELECT Msg = 'Disk response times were noticed.'
		END

	END

	IF NOT EXISTS(SELECT 1 FROM @Output)
	BEGIN
		INSERT INTO @Output
		SELECT Msg = 'No disk related issues were noticed in the captured workload.'
	END

	--'High database log write percent.'
	--'High database IO usage.'
	SELECT Msg
	FROM @Output
END
GO
