IF OBJECT_ID('AppGetServerInstanceName') IS NOT NULL
DROP PROCEDURE AppGetServerInstanceName
GO
CREATE PROCEDURE AppGetServerInstanceName
AS
BEGIN
	IF OBJECT_ID('tbl_ServerProperties') IS NOT NULL
	BEGIN
		SELECT [PropertyValue] 
		FROM [dbo].[tbl_ServerProperties] 
		WHERE [PropertyName] LIKE 'SQLServerName'
	END
	ELSE IF OBJECT_ID('cust_azureserverproperties') IS NOT NULL
	BEGIN
		SELECT PropertyValue =  ServerName 
		FROM [dbo].[cust_azureserverproperties]  
	END
END
GO
IF OBJECT_ID('Summary_ServerType') IS NOT NULL
DROP PROCEDURE Summary_ServerType
GO
CREATE PROCEDURE [dbo].[Summary_ServerType]
AS
BEGIN
	DECLARE @ServerType VARCHAR(40)

	IF OBJECT_ID('tbl_ServerProperties') IS NOT NULL
	BEGIN
		IF EXISTS
		(
			SELECT *
			FROM [dbo].[tbl_ServerProperties] 
			WHERE PropertyName = 'EngineEdition' AND
			PropertyValue = '5'
		)
		BEGIN
			IF EXISTS
			(
				SELECT *
				FROM [dbo].[tbl_ServerProperties] 
				WHERE PropertyName = 'DatabaseEdition' AND
				PropertyValue = 'Hyperscale'
			)
			BEGIN
				SET @ServerType = 'AzureSQLDBHyperscale'
			END
			ELSE
			BEGIN
				SET @ServerType = 'AzureSQLDB'
			END
		END
		ELSE IF EXISTS
		(
			SELECT *
			FROM [dbo].[tbl_ServerProperties] 
			WHERE PropertyName = 'EngineEdition' AND
			PropertyValue = '8'
		)
		BEGIN
			SET @ServerType = 'AzureSQLManagedInstance'
		END
		ELSE
			SET @ServerType = 'OnPremisesSQL'
	END

	SELECT ServerType = @ServerType 
END