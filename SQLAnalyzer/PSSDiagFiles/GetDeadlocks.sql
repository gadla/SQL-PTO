/*
 This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment. THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE. We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded; (ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
 Author: Amit Banerjee
 Date: September 6, 2012
 Description:
 This T-SQL script extracts information about deadlocks found from the System Health Session and puts them into a permanent table in tempdb.
 
 Modification: March 7, 2013
 Changed the final XML node execution for only SQL Server 2008 R2 instances and below.
*/
USE tempdb
GO
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (SELECT TOP 1 name FROM sys.objects where name = 'deadlock_graphs')
BEGIN
	DROP TABLE dbo.deadlock_graphs
END

DECLARE @fix_needed int = 0, @sql2012 int = 0
-- Check if current build is prone to issue mentioned in KB978629
IF (CAST(SERVERPROPERTY('ProductVersion') AS varchar(128)) LIKE '10.50%') 
BEGIN
	IF (CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS varchar(128)),7,4) AS INT) <= 1702) 
	BEGIN
		SET @fix_needed = 1
	END
END
ELSE IF (CAST(SERVERPROPERTY('ProductVersion') AS varchar(128)) LIKE '10.0.%') 
BEGIN
	IF (CAST(SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS varchar(128)),6,4) AS INT) <= 2757) 
	BEGIN
		SET @fix_needed = 1
	END
END

IF (CAST(SERVERPROPERTY('ProductVersion') AS varchar(128)) LIKE '11.%') 
BEGIN
	SET @sql2012 = 1
END

-- Fetch system health session data into a temp table
SELECT CAST(xet.target_data AS XML) AS XMLDATA
INTO #SystemHealthSessionData
FROM sys.dm_xe_session_targets xet 
JOIN sys.dm_xe_sessions xe 
ON (xe.address = xet.event_session_address) 
WHERE xe.name = 'system_health' and xet.target_name = 'ring_buffer'

IF (@fix_needed = 1 and @sql2012 = 0)
BEGIN
	-- Credit for below code snippet goes to Michael Zilberstein
	-- Workaround for issue in KB978629
	-- Blog: http://sqlblog.com/blogs/michael_zilberstein/archive/2010/05/10/24970.aspx
	
	;WITH CTE(event_time, deadlock_graph ) 
	AS 
	( 
	   SELECT 
		   event_xml.value('(./@timestamp)', 'datetime') as event_time, 
		   event_xml.value('(./data[@name="xml_report"]/value)[1]', 'varchar(max)') as deadlock_graph 
	   FROM #SystemHealthSessionData 
		   CROSS APPLY xmldata.nodes('//event[@name="xml_deadlock_report"]') n (event_xml) 
	   WHERE event_xml.value('@name', 'varchar(4000)') = 'xml_deadlock_report' 
	) 
	SELECT identity(int,1,1) as row_id, event_time,  
		CAST( 
		   CASE  
			   WHEN CHARINDEX('<victim-list/>', deadlock_graph) > 0 THEN 
				   REPLACE ( 
					   REPLACE(deadlock_graph, '<victim-list/>', '<deadlock><victim-list>'), 
					   '<process-list>', '</victim-list><process-list>')  
			   ELSE 
				   REPLACE ( 
					   REPLACE(deadlock_graph, '<victim-list>', '<deadlock><victim-list>'), 
					   '<process-list>', '</victim-list><process-list>')  
		   END  
	   AS XML) AS DeadlockGraph
	INTO dbo.deadlock_graphs 
	FROM CTE 
END

IF (@fix_needed = 0 and @sql2012 = 0)
BEGIN
	-- Parse the system health session data and create the deadlock graph
	;with cte as
	(SELECT C.query('.').value('(/event/@timestamp)[1]', 'datetime') as EventTime,
	CAST(C.query('.').value('(/event/data/value)[1]', 'varchar(MAX)') AS XML).value('(/deadlock/victim-list/victimProcess/@id)[1]','varchar(100)')  VictimProcess
	,CAST(REPLACE(REPLACE(CAST(C.query('.') as varchar(max)),'&lt;','<'),'&gt;','>') as xml) as xmldata
	FROM #SystemHealthSessionData a
	CROSS APPLY a.XMLDATA.nodes('/RingBufferTarget/event') as T(C)
	WHERE C.query('.').value('(/event/@name)[1]', 'varchar(255)') = 'xml_deadlock_report'
	)
	select identity(int,1,1) as row_id, D.query('.') as deadlockgraph, EventTime as event_time
	INTO dbo.deadlock_graphs 
	from cte
	CROSS APPLY XMLDATA.nodes('/event/data/value/deadlock') as N(D)

END

IF (@sql2012 = 1)
BEGIN
	-- Parse the system health session data and create the deadlock graph
	;with cte as
	(SELECT C.query('.').value('(/event/@timestamp)[1]', 'datetime') as EventTime,
	CAST(C.query('.').value('(/event/data/value)[1]', 'varchar(MAX)') AS XML).value('(/deadlock/victim-list/victimProcess/@id)[1]','varchar(100)')  VictimProcess
	,C.query('.') as xmldata
	FROM #SystemHealthSessionData a
	CROSS APPLY a.XMLDATA.nodes('/RingBufferTarget/event') as T(C)
	WHERE C.query('.').value('(/event/@name)[1]', 'varchar(255)') = 'xml_deadlock_report'
	)
	select identity(int,1,1) as row_id, D.query('.') as deadlockgraph, EventTime as event_time
	INTO dbo.deadlock_graphs 
	from cte
	CROSS APPLY XMLDATA.nodes('/event/data/value/deadlock') as N(D)
END

IF (@sql2012 = 0)
BEGIN
	-- Replace the necessary nodes to get the correct XDL format
	DECLARE @processid varchar(20), @cntr int = 1, @max int = 0
	SELECT @max = max(row_id) from deadlock_graphs
	WHILE (@cntr <= @max)
	BEGIN
		SELECT @processid=deadlockgraph.value('(//deadlock-list/deadlock/victim-list/victimProcess/@id)[1]','varchar(150)') 
		FROM dbo.deadlock_graphs
		WHERE row_id = @cntr

		UPDATE dbo.deadlock_graphs
		SET deadlockgraph.modify('insert attribute victim {sql:variable("@processid") }           
		into   (deadlock-list/deadlock)[1]')
		WHERE row_id = @cntr

		UPDATE dbo.deadlock_graphs
		SET deadlockgraph.modify('delete //deadlock-list/deadlock/victim-list')
		WHERE row_id = @cntr

		SET @cntr = @cntr + 1

	END
END

-- Perform cleanup
DROP TABLE #SystemHealthSessionData

SELECT *
FROM tempdb..deadlock_graphs