SET NOCOUNT ON
GO
IF OBJECT_ID('dbo.cust_MachineCheck_Computer') IS NOT NULL
DROP TABLE dbo.cust_MachineCheck_Computer
GO
IF OBJECT_ID('dbo.cust_MachineCheck_Service') IS NOT NULL
DROP TABLE dbo.cust_MachineCheck_Service
GO
IF OBJECT_ID('dbo.cust_MachineCheck_SQLInstance') IS NOT NULL
DROP TABLE dbo.cust_MachineCheck_SQLInstance
GO
IF OBJECT_ID('dbo.cust_MachineCheck_DiskDrive') IS NOT NULL
DROP TABLE dbo.cust_MachineCheck_DiskDrive
GO
IF OBJECT_ID('dbo.cust_MachineCheck_SQLServer') IS NOT NULL
DROP TABLE dbo.cust_MachineCheck_SQLServer
GO
IF OBJECT_ID('dbo.cust_MachineCheck_IPAddress') IS NOT NULL
DROP TABLE dbo.cust_MachineCheck_IPAddress
GO
IF OBJECT_ID('dbo.cust_MachineCheck_NetworkAdapter') IS NOT NULL
DROP TABLE dbo.cust_MachineCheck_NetworkAdapter
GO
IF OBJECT_ID('dbo.cust_MachineCheck_Messages') IS NOT NULL
DROP TABLE dbo.cust_MachineCheck_Messages
GO

IF OBJECT_ID('cust_MachineCheck') IS NOT NULL
BEGIN

SELECT 
	--scID = c.value('(scID)[1]','varchar(100)'),
	NETBIOSName = c.value('(NETBIOSName)[1]','varchar(100)'),
	FQDN = c.value('(FQDN)[1]','varchar(100)'),
	DNSSuffix  = c.value('(DNSSuffix )[1]','varchar(100)'),
	CPU64Bit = c.value('(CPU64Bit)[1]','varchar(100)'),
	ComputerRole = c.value('(ComputerRole)[1]','varchar(100)'),
	DomainOrWorkgroupName = c.value('(DomainOrWorkgroupName)[1]','varchar(100)'),
	JoinedToDomain = c.value('(JoinedToDomain)[1]','varchar(100)'),
	ConnectedToDomain = c.value('(ConnectedToDomain)[1]','varchar(200)'),
	ProgramFilesFolder = c.value('(ProgramFilesFolder)[1]','varchar(200)'),
	ProgramFilesx86Folder = c.value('(ProgramFilesx86Folder)[1]','varchar(200)'),
	CommonFilesFolder = c.value('(CommonFilesFolder)[1]','varchar(200)'),
	CommonFilesx86Folder = c.value('(CommonFilesx86Folder)[1]','varchar(200)'),
	WindowsVersion = c.value('(WindowsVersion)[1]','varchar(100)'),
	CLRVersion = c.value('(CLRVersion)[1]','varchar(100)'),
	IsClustered = c.value('(Clustered)[1]','varchar(100)'),
	CrashOnAuditFail = c.value('(CrashOnAuditFail)[1]','varchar(100)'),
	DisableLoopbackCheck  = c.value('(DisableLoopbackCheck )[1]','varchar(100)'),
	MaxTokenSize  = c.value('(MaxTokenSize )[1]','varchar(100)'),
	Kerberos_LogLevel  = c.value('(Kerberos_LogLevel )[1]','varchar(100)'),
	TcpMaxDataRetransmissions  = c.value('(TcpMaxDataRetransmissions )[1]','varchar(100)'),
	EnableTCPChimney  = c.value('(EnableTCPChimney )[1]','varchar(100)'),
	EnableRSS  = c.value('(EnableRSS )[1]','varchar(100)'),
	EnableTCPA  = c.value('(EnableTCPA )[1]','varchar(100)'),
	DisableTaskOffload  = c.value('(DisableTaskOffload )[1]','varchar(100)'),
	MaxUserPort  = c.value('(MaxUserPort )[1]','varchar(100)'),
	TcpTimedWaitDelay  = c.value('(TcpTimedWaitDelay )[1]','varchar(100)'),
	SynAttackProtect  = c.value('(SynAttackProtect )[1]','varchar(100)'),
	ODBC_User_Trace  = c.value('(ODBC_User_Trace )[1]','varchar(100)'),
	ODBC_Machine_Trace  = c.value('(ODBC_Machine_Trace )[1]','varchar(100)'),
	ODBC_User_Trace_WOW  = c.value('(ODBC_User_Trace_WOW )[1]','varchar(100)'),
	ODBC_Machine_Trace_WOW  = c.value('(ODBC_Machine_Trace_WOW )[1]','varchar(100)')
INTO dbo.cust_MachineCheck_Computer
FROM [dbo].[cust_MachineCheck] cp
CROSS APPLY InfoDesc.nodes('//Computer') t(c)

SELECT 
	scID = c.value('(scID)[1]','varchar(100)'),
	--scParentID = c.value('(scParentID)[1]','varchar(100)'),
	Name = c.value('(Name)[1]','varchar(100)'),
	Instance  = c.value('(Instance )[1]','varchar(100)'),
	PID = c.value('(PID)[1]','varchar(100)'),
	Description = c.value('(Description)[1]','varchar(200)'),
	Path = c.value('(Path)[1]','varchar(400)'),
	ServiceAccount = c.value('(ServiceAccount)[1]','varchar(200)'),
	DomainAccount = c.value('(DomainAccount)[1]','varchar(200)'),
	StartMode = c.value('(StartMode)[1]','varchar(100)'),
	Started = c.value('(Started)[1]','varchar(100)'),
	Status = c.value('(Status)[1]','varchar(100)')
INTO dbo.cust_MachineCheck_Service
FROM [dbo].[cust_MachineCheck] cp
CROSS APPLY InfoDesc.nodes('//Service') t(c)

SELECT 
	scID = c.value('(scID)[1]','varchar(100)'),
	--scParentID = c.value('(scParentID)[1]','varchar(100)'),
	InstanceType = c.value('(InstanceType)[1]','varchar(100)'),
	InstanceName = c.value('(InstanceName)[1]','varchar(100)'),
	InstanceFolder = c.value('(InstanceFolder)[1]','varchar(100)'),
	Wow6432Node = c.value('(Wow6432Node)[1]','varchar(100)')
INTO dbo.cust_MachineCheck_SQLInstance
FROM [dbo].[cust_MachineCheck] cp
CROSS APPLY InfoDesc.nodes('//SQLInstance') t(c)

SELECT 
	scID = c.value('(scID)[1]','varchar(100)'),
	--scParentID = c.value('(scParentID)[1]','varchar(100)'),
	Drive = c.value('(Drive)[1]','varchar(100)'),
	DriveType = c.value('(DriveType)[1]','varchar(100)'),
	DriveFormat = c.value('(DriveFormat)[1]','varchar(100)'),
	Capacity = c.value('(Capacity)[1]','varchar(100)'),
	BytesFree = c.value('(BytesFree)[1]','varchar(100)'),
	PctFree = c.value('(PctFree)[1]','varchar(100)')
INTO dbo.cust_MachineCheck_DiskDrive
FROM [dbo].[cust_MachineCheck] cp
CROSS APPLY InfoDesc.nodes('//DiskDrive') t(c)


SELECT 
	scID = c.value('(scID)[1]','varchar(100)'),
	--scParentID = c.value('(scParentID)[1]','varchar(100)'),
	Version = c.value('(Version)[1]','varchar(100)'),
	ServicePack = c.value('(ServicePack)[1]','varchar(100)'),
	PatchLevel = c.value('(PatchLevel)[1]','varchar(100)'),
	Edition = c.value('(Edition)[1]','varchar(100)'),
	IsClustered = c.value('(Clustered)[1]','varchar(100)'),
	ForceEncryption = c.value('(ForceEncryption)[1]','varchar(100)'),
	EnabledProtocols = c.value('(EnabledProtocols)[1]','varchar(100)'),
	PipeName = c.value('(PipeName)[1]','varchar(100)'),
	TCPPort = c.value('(TCPPort)[1]','varchar(100)'),
	TCPDynamicPort  = c.value('(TCPDynamicPort )[1]','varchar(100)'),
	Path = c.value('(Path)[1]','varchar(100)'),
	ProcessID = c.value('(ProcessID)[1]','varchar(100)'),
	ServiceAccount = c.value('(ServiceAccount)[1]','varchar(100)'),
	SPNServiceAccount = c.value('(SPNServiceAccount)[1]','varchar(100)')
INTO dbo.cust_MachineCheck_SQLServer
FROM [dbo].[cust_MachineCheck] cp
CROSS APPLY InfoDesc.nodes('//SQLServer') t(c)

SELECT 
	scID = c.value('(scID)[1]','varchar(100)'),
	--scParentID = c.value('(scParentID)[1]','varchar(100)'),
	AddressFamily = c.value('(AddressFamily)[1]','varchar(100)'),
	Address = c.value('(Address)[1]','varchar(100)')
INTO dbo.cust_MachineCheck_IPAddress
FROM [dbo].[cust_MachineCheck] cp
CROSS APPLY InfoDesc.nodes('//IPAddress') t(c)

SELECT 
	scID = c.value('(scID)[1]','varchar(100)'),
	--scParentID = c.value('(scParentID)[1]','varchar(100)'),
	Name = c.value('(Name)[1]','varchar(100)'),
	AdapterType = c.value('(AdapterType)[1]','varchar(100)'),
	DriverDate = c.value('(DriverDate)[1]','varchar(100)'),
	Speed = c.value('(Speed)[1]','varchar(100)'),
	SpeedDuplex = c.value('(SpeedDuplex)[1]','varchar(100)'),
	FlowControl = c.value('(FlowControl)[1]','varchar(100)'),
	RSS = c.value('(RSS)[1]','varchar(100)'),
	NICTeaming = c.value('(NICTeaming)[1]','varchar(100)')
INTO dbo.cust_MachineCheck_NetworkAdapter
FROM [dbo].[cust_MachineCheck] cp
CROSS APPLY InfoDesc.nodes('//NetworkAdapter') t(c)


SELECT 
	scID = c.value('(scID)[1]','varchar(100)'),
	scTableName = c.value('(scTableName)[1]','varchar(100)'),
	--scTableRowID = c.value('(scTableRowID)[1]','varchar(100)'),
	--scSeverity = c.value('(scSeverity)[1]','varchar(100)'),
	scAppMessage = c.value('(scAppMessage)[1]','varchar(1000)')
INTO dbo.cust_MachineCheck_Messages
FROM [dbo].[cust_MachineCheck] cp
CROSS APPLY InfoDesc.nodes('//scMessage') t(c)


END