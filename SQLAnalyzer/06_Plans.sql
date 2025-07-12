/*
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
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
FROM [dbo].[cust_CapturedPlans] cp
CROSS APPLY QueryPlan.nodes('//RelOp') rel(operators) 


;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 

CachedPlanSize = smp.value('@CachedPlanSize','nvarchar(50)'),
CompileTime = smp.value('@CompileTime','nvarchar(50)'),
CompileCPU = smp.value('@CompileCPU','nvarchar(50)'),
CompileMemory = smp.value('@CompileMemory','nvarchar(50)'), smp.query('.')
FROM [dbo].[cust_CapturedPlans] cp
CROSS APPLY QueryPlan.nodes('//QueryPlan') stmt(smp)


;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
SetQuotedIdentifier = smp.value('@QUOTED_IDENTIFIER','nvarchar(50)'),
SetArithAbort = smp.value('@ARITHABORT','nvarchar(50)'),
SetConcatNullYieldsNull = smp.value('@CONCAT_NULL_YIELDS_NULL','nvarchar(50)'),
SetAnsiNulls = smp.value('@ANSI_NULLS','nvarchar(50)'),
SetAnsiPadding = smp.value('@ANSI_PADDING','nvarchar(50)'),
SetAniWarnings = smp.value('@ANSI_WARNINGS','nvarchar(50)'),
SetNumericRoundAbort = smp.value('@NUMERIC_ROUNDABORT','nvarchar(50)')
FROM [dbo].[cust_CapturedPlans] cp
CROSS APPLY QueryPlan.nodes('//StatementSetOptions') stmt(smp)

PRINT '-- QPSniffing'
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
ColumnName = operators.value('@Column', 'nvarchar(250)'), 
CompiledValue = operators.value('@ParameterCompiledValue', 'nvarchar(250)'), 
operators.query('../..')
FROM [dbo].[cust_CapturedPlans] cp
CROSS APPLY QueryPlan.nodes('//ParameterList/ColumnReference') rel(operators)


;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
	ConvertIssue, Expression, 
	StatementText = LTRIM(RTRIM(StmtQuery.value('(/StmtSimple/@StatementText)[1]', 'varchar(max)'))), 
	StatementId = StmtQuery.value('(/StmtSimple/@StatementId)[1]', 'varchar(max)'), 
	StatementCompId = StmtQuery.value('(/StmtSimple/@StatementCompId)[1]', 'varchar(max)'), 
	StatementType = StmtQuery.value('(/StmtSimple/@StatementType)[1]', 'varchar(max)'), 
	RetrievedFromCache = StmtQuery.value('(/StmtSimple/@RetrievedFromCache)[1]', 'varchar(max)'), 
	StatementSubTreeCost = StmtQuery.value('(/StmtSimple/@StatementSubTreeCost)[1]', 'float'), 
	StatementEstRows = StmtQuery.value('(/StmtSimple/@StatementEstRows)[1]', 'float'), 
	StatementOptmLevel = StmtQuery.value('(/StmtSimple/@StatementOptmLevel)[1]', 'varchar(max)'), 
	QueryHash = StmtQuery.value('(/StmtSimple/@QueryHash)[1]', 'varchar(max)'), 
	QueryPlanHash = StmtQuery.value('(/StmtSimple/@QueryPlanHash)[1]', 'varchar(max)'), 
	CardinalityEstimationModelVersion = StmtQuery.value('(/StmtSimple/@CardinalityEstimationModelVersion)[1]', 'varchar(max)')
FROM (
SELECT 
ConvertIssue = operators.value('@ConvertIssue', 'nvarchar(250)'), 
Expression = operators.value('@Expression', 'nvarchar(250)'), 
StmtQuery = (operators.query('(../../..)'))
FROM [dbo].[cust_CapturedPlans] cp
CROSS APPLY QueryPlan.nodes('//Warnings/PlanAffectingConvert') rel(operators)
) x 




PRINT '-- QPObjects'
;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
DatabaseName = operators.value('@Database', 'nvarchar(250)'), 
SchemaName = operators.value('@Schema', 'nvarchar(250)'),
TableName = operators.value('@Table', 'nvarchar(250)'),
IndexName = operators.value('@Index', 'nvarchar(250)'),
Alias = operators.value('@Alias', 'nvarchar(250)'),
IndexKind = operators.value('@IndexKind', 'nvarchar(250)'), 
QueryPlan.query('.')
FROM [dbo].[cust_CapturedPlans] cp
CROSS APPLY QueryPlan.nodes('//Object') rel(operators)

;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT *, 
ROUND((100.0 * StatementSubTreeCost / SUM (StatementSubTreeCost) OVER(PARTITION BY IDCol)),0) AS OverallQueryCost
FROM (
select 
	IDCol,
	StatementText = LTRIM(RTRIM(StmtQuery.value('(@StatementText)[1]', 'varchar(max)'))), 
	StatementId = StmtQuery.value('(@StatementId)[1]', 'varchar(max)'), 
	StatementCompId = StmtQuery.value('(@StatementCompId)[1]', 'varchar(max)'), 
	StatementType = StmtQuery.value('(@StatementType)[1]', 'varchar(max)'), 
	RetrievedFromCache = StmtQuery.value('(@RetrievedFromCache)[1]', 'varchar(max)'), 
	StatementSubTreeCost = ISNULL(StmtQuery.value('(@StatementSubTreeCost)[1]', 'float'), 0),
	StatementEstRows = StmtQuery.value('(@StatementEstRows)[1]', 'float'), 
	StatementOptmLevel = StmtQuery.value('(@StatementOptmLevel)[1]', 'varchar(max)'), 
	QueryHash = StmtQuery.value('(@QueryHash)[1]', 'varchar(max)'), 
	QueryPlanHash = StmtQuery.value('(@QueryPlanHash)[1]', 'varchar(max)'), 
	CardinalityEstimationModelVersion = StmtQuery.value('(@CardinalityEstimationModelVersion)[1]', 'varchar(max)')
from [dbo].[cust_CapturedPlans] p
CROSS APPLY QueryPlan.nodes('//StmtSimple') rel(StmtQuery)
) x
ORDER BY IDCol ASC

select *
from [dbo].[cust_CapturedPlans] p
WHERE IDCol = 1
*/

