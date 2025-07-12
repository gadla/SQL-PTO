/*
	The following query returns OS level information, such as CPU, memory, and instance start time..
	
	References:  http://msdn.microsoft.com/en-us/library/ms175048.aspx
		
*/
SET NOCOUNT ON
DECLARE @ProductVersion NVARCHAR(128)
SET @ProductVersion = CAST(SERVERPROPERTY ('ProductVersion') AS NVARCHAR(128))

IF CAST(LEFT(@ProductVersion, CHARINDEX('.',@ProductVersion)-1) AS INT) > 8
BEGIN
	PRINT '-- OSInfo'
	SELECT
	   *
	FROM
		sys.dm_os_sys_info
END