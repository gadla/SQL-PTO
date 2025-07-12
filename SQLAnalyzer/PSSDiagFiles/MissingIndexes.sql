SET NOCOUNT ON
PRINT '-- MissingIndexes'
DECLARE @ProductVersion NVARCHAR(128)
SET @ProductVersion = CAST(SERVERPROPERTY ('ProductVersion') AS NVARCHAR(128))

IF CAST(LEFT(@ProductVersion, CHARINDEX('.',@ProductVersion)-1) AS INT) > 8
BEGIN
SELECT
    IndexImpact = user_seeks * avg_total_user_cost * (avg_user_impact * 0.5),
    LastUserSeek = groupstats.last_user_seek,
    FullObjectName = details.[statement],
    TableName = REPLACE(REPLACE(REVERSE(LEFT(REVERSE(details.[statement]), CHARINDEX('.', REVERSE(details.[statement]))-1)),'[',''), ']',''),
    EqualityColumns = details.equality_columns,
    InequalityColumns = details.inequality_columns,
    IncludedColumns = details.included_columns,
    Compiles = groupstats.unique_compiles,
    Seeks = groupstats.user_seeks,
    UserCost = groupstats.avg_total_user_cost,
    UserImpact = groupstats.avg_user_impact, 
    DatabaseName = DB_NAME(details.database_id)
FROM
    sys.dm_db_missing_index_group_stats AS groupstats
INNER JOIN sys.dm_db_missing_index_groups AS groups
    ON groupstats.group_handle = groups.index_group_handle
INNER JOIN sys.dm_db_missing_index_details AS details
    ON groups.index_handle = details.index_handle
ORDER BY
    IndexImpact DESC ;
END