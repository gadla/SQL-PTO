PRINT '-- QPRelOp'
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
cp.query_hash, cp.query_plan_hash,
PhysicalOperator = operators.value('@PhysicalOp','nvarchar(50)'), 
LogicalOp = operators.value('@LogicalOp','nvarchar(50)'),
AvgRowSize = operators.value('@AvgRowSize','nvarchar(50)'),
EstimateCPU = operators.value('@EstimateCPU','nvarchar(50)'),
EstimateIO = operators.value('@EstimateIO','nvarchar(50)'),
EstimateRebinds = operators.value('@EstimateRebinds','nvarchar(50)'),
EstimateRewinds = operators.value('@EstimateRewinds','nvarchar(50)'),
EstimateRows = operators.value('@EstimateRows','nvarchar(50)'),
Parallel = operators.value('@Parallel','nvarchar(50)'),
NodeId = operators.value('@NodeId','nvarchar(50)'),
EstimatedTotalSubtreeCost = operators.value('@EstimatedTotalSubtreeCost','nvarchar(50)')
FROM sys.dm_exec_query_stats cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
CROSS APPLY query_plan.nodes('//RelOp') rel(operators)

PRINT '-- QPQueryPlan'
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
cp.query_hash, cp.query_plan_hash, 
CachedPlanSize = smp.value('@CachedPlanSize','nvarchar(50)'),
CompileTime = smp.value('@CompileTime','nvarchar(50)'),
CompileCPU = smp.value('@CompileCPU','nvarchar(50)'),
CompileMemory = smp.value('@CompileMemory','nvarchar(50)')
FROM sys.dm_exec_query_stats cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
CROSS APPLY query_plan.nodes('//QueryPlan') stmt(smp)

PRINT '-- QPQueryDetail'
SELECT
	cp.query_hash, cp.query_plan_hash, execution_count, 
	total_worker_time, total_logical_reads, total_elapsed_time, 
	AvgLogicalReads = (total_logical_reads + 1)/execution_count,
	AvgWorkerTime = (total_worker_time + 1)/execution_count,
	AvgElapsedTime = (total_elapsed_time + 1)/execution_count,
	StatementText = REPLACE(REPLACE(StatementText, '"', ''), '''', '')
FROM (
SELECT 
cp.query_hash, cp.query_plan_hash, execution_count, 
total_worker_time, total_logical_reads, total_elapsed_time, 
StatementText = 
SUBSTRING(text, statement_start_offset/2+1,
			(CASE WHEN statement_end_offset=-1
				THEN LEN(CONVERT(NVARCHAR(MAX), text))*2
				ELSE statement_end_offset
			END-statement_start_offset)/2)
FROM sys.dm_exec_query_stats cp
CROSS APPLY sys.dm_exec_sql_text(cp.sql_handle) qp
) cp

PRINT '-- QPHardware'
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
cp.query_hash, cp.query_plan_hash,
EstimatedAvailableMemoryGrant = smp.value('@EstimatedAvailableMemoryGrant','nvarchar(50)'),
EstimatedPagesCached = smp.value('@EstimatedPagesCached','nvarchar(50)'),
EstimatedAvailableDegreeOfParallelism = smp.value('@EstimatedAvailableDegreeOfParallelism','nvarchar(50)')
FROM sys.dm_exec_query_stats cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
CROSS APPLY query_plan.nodes('//OptimizerHardwareDependentProperties') stmt(smp)

PRINT '-- QPMemGrants'
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
cp.query_hash, cp.query_plan_hash,
SerialRequiredMemory = smp.value('@SerialRequiredMemory','nvarchar(50)'),
SerialDesiredMemory = smp.value('@SerialDesiredMemory','nvarchar(50)')
FROM sys.dm_exec_query_stats cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
CROSS APPLY query_plan.nodes('//MemoryGrantInfo') stmt(smp)

PRINT '-- QPSetOptions'
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
cp.query_hash, cp.query_plan_hash,
SetQuotedIdentifier = smp.value('@QUOTED_IDENTIFIER','nvarchar(50)'),
SetArithAbort = smp.value('@ARITHABORT','nvarchar(50)'),
SetConcatNullYieldsNull = smp.value('@CONCAT_NULL_YIELDS_NULL','nvarchar(50)'),
SetAnsiNulls = smp.value('@ANSI_NULLS','nvarchar(50)'),
SetAnsiPadding = smp.value('@ANSI_PADDING','nvarchar(50)'),
SetAniWarnings = smp.value('@ANSI_WARNINGS','nvarchar(50)'),
SetNumericRoundAbort = smp.value('@NUMERIC_ROUNDABORT','nvarchar(50)')
FROM sys.dm_exec_query_stats cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
CROSS APPLY query_plan.nodes('//StatementSetOptions') stmt(smp)

PRINT '-- QPSniffing'
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
cp.query_hash, cp.query_plan_hash,
ColumnName = operators.value('@Column', 'nvarchar(250)'), 
CompiledValue = operators.value('@ParameterCompiledValue', 'nvarchar(250)')
FROM sys.dm_exec_query_stats cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
CROSS APPLY query_plan.nodes('//ParameterList/ColumnReference') rel(operators)

PRINT '-- QPWarnings'
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
cp.query_hash, cp.query_plan_hash,
ConvertIssue = operators.value('@ConvertIssue', 'nvarchar(250)'), 
Expression = operators.value('@Expression', 'nvarchar(250)')
FROM sys.dm_exec_query_stats cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
CROSS APPLY query_plan.nodes('//Warnings/PlanAffectingConvert') rel(operators)

PRINT '-- QPObjects'
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
cp.query_hash, cp.query_plan_hash,
DatabaseName = operators.value('@Database', 'nvarchar(250)'), 
SchemaName = operators.value('@Schema', 'nvarchar(250)'),
TableName = operators.value('@Table', 'nvarchar(250)'),
IndexName = operators.value('@Index', 'nvarchar(250)'),
Alias = operators.value('@Alias', 'nvarchar(250)'),
IndexKind = operators.value('@IndexKind', 'nvarchar(250)')
FROM sys.dm_exec_query_stats cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
CROSS APPLY query_plan.nodes('//Object') rel(operators)

	
