SET NOCOUNT ON

DECLARE @MachineName VARCHAR(1024)

SELECT @MachineName = dbo.udf_GetMachineName()
SET @MachineName = '\\' + @MachineName

IF 
	OBJECT_ID('dbo.Counterdata') IS NOT NULL AND
	OBJECT_ID('dbo.CounterDetails') IS NOT NULL 
BEGIN

IF OBJECT_ID('cust_Baseline') IS NOT NULL
DROP TABLE cust_Baseline

CREATE TABLE [dbo].[cust_Baseline]
(
	[Description] [varchar](1024) NOT NULL,
	[ObjectName] [varchar](1024) NOT NULL,
	[CounterName] [varchar](1024) NOT NULL,
	[MachineName] [varchar](1024) NOT NULL,
	[InstanceName] [varchar](1024) NULL,
	[CounterAvg] float NULL,
	[CounterMin] float NULL,
	[CounterMax] float NULL
) 


INSERT INTO cust_Baseline
	SELECT 
	Description = CASE WHEN ObjectName LIKE '%SQL%' THEN 'SQL Server' ELSE 'Server' END,
	ObjectName, 
	CounterName, 
	MachineName,
	InstanceName = InstanceName,
	CounterAvg = AVG(CounterValue), 
	CounterMin = MIN(CounterValue),
	CounterMax = MAX(CounterValue)
	FROM dbo.Counterdata c
	JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
	WHERE 
		MachineName = @MachineName AND
		(
			ObjectName = 'SQLServer:Cursor Manager by Type' AND
			InstanceName = '_Total' AND
			CounterName IN
			(
				'Active cursors',
				'Cursor memory usage',
				'Number of active cursor plans',
				'Cursor Requests/sec'
			)
		)
		OR
		(
			ObjectName = 'SQLServer:CLR' 
			AND
			CounterName IN
			(
				'CLR Execution'
			)
		)
		OR
		(
			ObjectName = 'SQLServer:Workload Group Stats' 
			--AND
			--CounterName IN
			--(
			--	'CLR Execution'
			--)
		)

		OR
		(
			ObjectName = 'SQLServer:Database Mirroring' 
			AND
			CounterName IN
			(
				'Bytes Received/sec',
				'Bytes Sent/sec'
			)
		)
		--OR
		--(
		--	ObjectName = 'SQLServer:Broker TO Statistics' 
		--	--AND
		--	--CounterName IN
		--	--(
		--	--	'CLR Execution'
		--	--)
		--)
		OR
		(
			ObjectName = 'LogicalDisk' AND
			CounterName IN
			(
			'% Idle Time',
			'Avg. Disk Bytes/Read',
			'Avg. Disk Bytes/Write',
			'Avg. Disk sec/Read',
			'Avg. Disk sec/Write',
			'Free Megabytes'
			)
		)
		OR
		(
			ObjectName LIKE '%Access Methods' AND
			CounterName IN
			(
			'Full Scans/sec',
			'Index Searches/sec',
			'Range Scans/sec',
			'Table Lock Escalations/sec',
			'Forwarded Records/sec',
			'Table Lock Escalations/sec',
			'Page Splits/sec',
			'Pages compressed/sec'
			)
		) 
		OR
		(
			ObjectName LIKE '%Buffer Manager' AND
			CounterName IN
			(
			'Database pages',
			'Lazy writes/sec',
			'Page life expectancy',
			'Free list stalls/sec',
			'Page lookups/sec',
			'Page reads/sec',
			'Page writes/sec',
			'Readahead pages/sec',
			'Buffer cache hit ratio',
			'Extension allocated pages',
			'Extension page writes/sec'
			)
		) 
		OR
		(
			ObjectName LIKE '%General Statistics' AND
			CounterName IN
			(
			'Active Temp Tables',
			'Logins/sec',
			'Processes blocked',
			'Transactions',
			'User Connections',
			'Temp Tables Creation Rate'
			)
		) 
		OR
		(
			ObjectName LIKE '%Memory Manager' AND
			CounterName IN
			(
				'Connection Memory (KB)',
				'Database Cache Memory (KB)',
				'Lock Memory (KB)',
				'Memory Grants Outstanding',
				'Memory Grants Pending',
				'External benefit of memory',
				'Free Memory (KB)',
				'Granted Workspace Memory (KB)',
				'Optimizer Memory (KB)',
				'Reserved Server Memory (KB)',
				'SQL Cache Memory (KB)',
				'Stolen Server Memory (KB)',
				'Target Server Memory (KB)',
				'Total Server Memory (KB)'
			)
		) 
		OR
		(
			ObjectName LIKE '%SQL Statistics' AND
			CounterName IN
			(
				'Batch Requests/sec',
				'SQL Compilations/sec',
				'SQL Re-Compilations/sec',
				'Guided Plan Executions/sec'
			)
		) 
		OR
		(
			ObjectName LIKE '%Locks' AND
			InstanceName = '_Total' AND
			CounterName IN
			(
				'Lock Requests/sec',
				'Lock Wait Time (ms)',
				'Average Wait Time (ms)',
				'Lock Waits/sec',
				'Number of Deadlocks/sec'
			)
		) 
		OR
		(
			ObjectName = 'Memory' AND
			CounterName IN
			(
				'Available MBytes',
				'Pages/sec',
				'Memory \ Committed Bytes',
				'% Committed Bytes In Use',
				'Commit Limit'
			)
		) 
		OR
		(
			ObjectName = 'Processor Information' AND
			InstanceName = '_Total' AND
			CounterName IN
			(
				'% Processor Time',
				'% Privileged Time',
				'% User Time', 
				'% C1 Time', 
				'% C2 Time', 
				'% C3 Time',
				'% of Maximum Frequency',
				'C1 Transitions/sec',
				'C1 Transitions/sec',
				'C1 Transitions/sec'
			)
		) 
		OR
		(
			ObjectName = 'Network Interface' AND
			CounterName IN
			(
				'Current Bandwidth',
				'Bytes Total/sec'
			)
		) 


	GROUP BY ObjectName, CounterName, MachineName, InstanceName
	--ORDER BY CounterName


	INSERT INTO cust_Baseline
	SELECT 
	Description = 'Database Info',
	ObjectName, 
	CounterName, 
	MachineName,
	InstanceName,
	CounterAvg = AVG(CounterValue),
	CounterMin = MIN(CounterValue),
	CounterMax = MAX(CounterValue)
	FROM dbo.Counterdata c
	JOIN dbo.CounterDetails d ON c.CounterID = d.CounterID
	WHERE 
		ObjectName LIKE '%Databases' AND
		InstanceName <> '_Total'
		AND MachineName = @MachineName
	GROUP BY ObjectName, CounterName, InstanceName,MachineName


	INSERT INTO cust_Baseline
	SELECT 
	Description = 'Custom Counter',
	ObjectName = 'Custom',
	CounterName = 
		CASE 
			WHEN b.CounterName = 'Full Scans/sec' THEN 'FullScansToBatchReqRatio_AVG'
			WHEN b.CounterName = 'SQL Compilations/sec' THEN 'CompilationsToBatchReqRatio_AVG'
			WHEN b.CounterName = 'Page lookups/sec' THEN 'PageLookupsToBatchReqRatio_AVG'
		END,
	a.MachineName,
	InstanceName = NULL, 
	CounterAvg = CAST((CAST(b.CounterAvg AS DECIMAL)/CAST(a.CounterAvg AS DECIMAL)) AS DECIMAL(18,2)), 
	CounterMin = NULL, 
	CounterMax = NULL
	FROM 
	(
	SELECT *
	FROM cust_Baseline a
	WHERE CounterName = 'Batch Requests/sec' 
	AND MachineName = @MachineName
	) a, 
	(
	SELECT *
	FROM cust_Baseline a
	WHERE CounterName IN( 'Full Scans/sec','SQL Compilations/sec','Page lookups/sec') 
	AND	MachineName = @MachineName
	) b 	

END