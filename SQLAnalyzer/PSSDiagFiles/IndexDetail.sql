SET NOCOUNT ON
IF OBJECT_ID('tempdb..#IndexDefs') IS NOT NULL
DROP TABLE #IndexDefs
GO
CREATE TABLE #IndexDefs
(
	DBName NVARCHAR(255),
	TableName NVARCHAR(255),
	IndexName NVARCHAR(255),
	IndexColumns NVARCHAR(MAX),
	IncludedColumns NVARCHAR(MAX),
	IndexType NVARCHAR(25),
	IsUnique BIT,
	IsPrimaryKey BIT,
	FillFact TINYINT, 
	IgnoreDupKey BIT, 
	IsUniqueConstraint BIT, 
	IsDisabled BIT, 
	IsHypothetical BIT, 
	AllowRowLocks BIT, 
	AllowPageLocks BIT
)

INSERT INTO #IndexDefs
EXECUTE sp_msforeachdb 'use ?
if db_name() not in(''tempdb'',''master'',''msdb'',''model'')
SELECT 
	DB_NAME(),
	TableName = object_name(object_id),
	IndexName = ind.name,
	IndexColumns = REVERSE(SUBSTRING(REVERSE((
		SELECT
			col.name + '', ''
		FROM
			sys.index_columns ind_col
			INNER JOIN sys.columns col ON col.object_id = ind_col.object_id AND col.column_id = ind_col.column_id
		WHERE
			ind_col.object_id = ind.object_id AND
			ind_col.index_id = ind.index_id AND
			is_included_column = 0
		ORDER BY
			ind_col.key_ordinal
		FOR XML PATH('''')
	)), 3, 8000)), 
	IncludedColumns = REVERSE(SUBSTRING(REVERSE((
	SELECT
		col.name + '', ''
	FROM
		sys.index_columns ind_col
		INNER JOIN sys.columns col ON col.object_id = ind_col.object_id AND col.column_id = ind_col.column_id
	WHERE
		ind_col.object_id = ind.object_id AND
		ind_col.index_id = ind.index_id AND
		is_included_column = 1
	ORDER BY
		ind_col.key_ordinal
	FOR XML PATH('''')
)), 3, 8000)),
	type_desc, 
	is_unique, 
	is_primary_key, 
	fill_factor, 
	ignore_dup_key , 
	is_unique_constraint , 
	is_disabled , 
	is_hypothetical , 
	allow_row_locks , 
	allow_page_locks
FROM sys.indexes ind
WHERE
	ind.index_id >= 0
	AND ind.type <> 3
	AND ind.is_hypothetical = 0
ORDER BY 1'

PRINT '--IndexDetail'
SELECT * FROM #IndexDefs

