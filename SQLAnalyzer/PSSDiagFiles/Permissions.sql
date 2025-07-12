SET NOCOUNT ON
GO
DECLARE @version VARCHAR(50), @build int
SET @version = CONVERT(VARCHAR(50), SERVERPROPERTY('ProductVersion') )

SELECT @build =  LEFT(@version, CHARINDEX('.', @version)-1)


IF OBJECT_ID('tempdb..#Permissions') IS NOT NULL
DROP TABLE #Permissions

IF OBJECT_ID('tempdb..#Membership') IS NOT NULL
DROP TABLE #Membership

CREATE TABLE #Permissions
(
	ServerName VARCHAR(255), 
	DBName VARCHAR(255), 
	PermissionName VARCHAR(255), 
	PermissionState VARCHAR(255), 
	GranteeName VARCHAR(255), 
	GranteePrincipalType VARCHAR(255), 
	GrantorName VARCHAR(255), 
	GrantorPrincipalType VARCHAR(255)

)

CREATE TABLE #Membership
(
	ServerName VARCHAR(255),
	DBName VARCHAR(255), 
	GranteeName VARCHAR(255), 
	GranteeDescription VARCHAR(255),
	GrantorName VARCHAR(255), 
	GrantorDescription VARCHAR(255)
)

IF @build >= 9
BEGIN

	EXECUTE master..sp_msforeachdb 'use [?]
	INSERT INTO #Permissions
	(
		ServerName, DBName, PermissionName, PermissionState, GranteeName, 
		GranteePrincipalType, GrantorName, GrantorPrincipalType
	)
	SELECT 
		@@servername, DB_NAME(), dp.permission_name, dp.state_desc, grantee.name, grantee.type_desc, grantor.name, grantor.type_desc
	FROM sys.database_permissions dp
	JOIN sys.database_principals grantee ON dp.grantee_principal_id = grantee.principal_id
	JOIN sys.database_principals grantor ON dp.grantor_principal_id = grantor.principal_id

	INSERT INTO #Membership
	(
		ServerName,
		DBName, 
		GranteeName, 
		GranteeDescription,
		GrantorName, 
		GrantorDescription
	)
	SELECT 
		@@SERVERNAME, DB_NAME(), grantee.name, grantee.type_desc, grantor.name, grantor.type_desc
	FROM sys.database_role_members drm
	JOIN sys.database_principals grantee ON drm.role_principal_id = grantee.principal_id
	JOIN sys.database_principals grantor ON drm.member_principal_id = grantor.principal_id

	'

	INSERT INTO #Permissions
	(
		ServerName, DBName, PermissionName, PermissionState, GranteeName, 
		GranteePrincipalType, GrantorName, GrantorPrincipalType
	)
	SELECT 
		@@SERVERNAME, NULL, dp.permission_name, dp.state_desc, grantee.name, grantee.type_desc, grantor.name, grantor.type_desc
	FROM sys.server_permissions dp
	JOIN sys.server_principals grantee ON dp.grantee_principal_id = grantee.principal_id
	JOIN sys.server_principals grantor ON dp.grantor_principal_id = grantor.principal_id

	INSERT INTO #Membership
	(
		ServerName, 
		DBName, 
		GranteeName, 
		GranteeDescription,
		GrantorName, 
		GrantorDescription
	)
	SELECT 
		@@SERVERNAME, NULL, grantee.name, grantee.type_desc, grantor.name, grantor.type_desc
	FROM sys.server_role_members drm
	JOIN sys.server_principals grantee ON drm.role_principal_id = grantee.principal_id
	JOIN sys.server_principals grantor ON drm.member_principal_id = grantor.principal_id

	PRINT '-- ObjectPermissions'
	SELECT * 
	FROM #Permissions
	ORDER BY ServerName, DBName

	PRINT ''

	PRINT '-- MembershipPermissions'
	SELECT * 
	FROM #Membership
	ORDER BY ServerName, DBName

END
