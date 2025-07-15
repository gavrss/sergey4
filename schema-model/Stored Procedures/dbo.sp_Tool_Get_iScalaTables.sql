SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Get_iScalaTables] AS

DECLARE
	@StartYear int = 2020, --NULL to get all tables initially or 2011 to get all data from that year
	@DebugBM int = 0

--SELECT DISTINCT [TableCode] INTO #TableCode FROM pcINTEGRATOR..SourceTable WHERE SourceTypeFamilyID = 2 AND ModelBM & 68 > 0
SELECT [TableCode] INTO #TableCode FROM (SELECT [TableCode] = 'GL03' UNION SELECT 'GL06' UNION SELECT 'GL10' UNION SELECT 'GL12' UNION SELECT 'GL53' UNION SELECT 'PL01' UNION SELECT 'PL22' UNION SELECT 'ScaCompanyProperty' UNION SELECT 'SL01' UNION SELECT 'SL22' UNION SELECT 'ST01' UNION SELECT 'SY24' UNION SELECT 'SYCD' UNION SELECT 'SYCH') sub
IF @DebugBM & 1 > 0 SELECT TempTable = '#TableCode', * FROM #TableCode ORDER BY [TableCode]

SELECT DISTINCT [DBName], [CompanyCode] INTO #Company FROM [ScaSystemDB].[dbo].[ScaCompanies] WHERE CompanyName NOT LIKE '%Test%'
IF @DebugBM & 1 > 0 SELECT TempTable = '#Company', * FROM #Company ORDER BY [DBName], [CompanyCode]

DECLARE
	@DBName nvarchar(50),
	@TableName nvarchar(50),
	@SQLStatement nvarchar(max)

CREATE TABLE #Table
	(
	[DBName] nvarchar(50) COLLATE DATABASE_DEFAULT,
	[TableName] nvarchar(50) COLLATE DATABASE_DEFAULT,
	[RowCount] int
	)

IF CURSOR_STATUS('global','DB_Cursor') >= -1 DEALLOCATE DB_Cursor
DECLARE DB_Cursor CURSOR FOR
	SELECT DISTINCT
		[DBName] = SC.[DBName]
	FROM
		[master].[sys].[databases] db
		INNER JOIN [ScaSystemDB].[dbo].[ScaCompanies] SC ON SC.[DBName] COLLATE DATABASE_DEFAULT = db.[name] COLLATE DATABASE_DEFAULT 

	OPEN DB_Cursor
	FETCH NEXT FROM DB_Cursor INTO @DBName
	WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @DebugBM & 2 > 0 SELECT [@DBName] = @DBName
			SET @SQLStatement  = '
				INSERT INTO #Table
					(
					[DBName],
					[TableName]
					)
				SELECT 
					[DBName] = ''' + @DBName + ''',
					[TableName] = t.[name]
				FROM
					' + @DBName + '.sys.tables t
					INNER JOIN #Company CC ON DBName IN (''' + @DBName +''')
					INNER JOIN #TableCode TC ON t.[name] COLLATE DATABASE_DEFAULT LIKE TC.[TableCode] COLLATE DATABASE_DEFAULT + CC.[CompanyCode] COLLATE DATABASE_DEFAULT + ''%''
				WHERE
					LEN(t.[name]) = 8 AND
					ISNUMERIC(RIGHT(t.[name], 2)) <> 0'
					+ CASE WHEN @StartYear IS NULL THEN '' ELSE 'AND (RIGHT(t.[name], 2) = ''00'' OR CONVERT(int, RIGHT(t.[name], 2)) >= ''' + CONVERT(nvarchar(15), @StartYear % 100) + ''')' END + '
				UNION SELECT 
					[DBName] = ''' + @DBName + ''',
					[TableName] = t.[name]
				FROM
					' + @DBName + '.sys.tables t
					INNER JOIN #Company CC ON DBName IN (''' + @DBName +''')
					INNER JOIN #TableCode TC ON t.[name] COLLATE DATABASE_DEFAULT = TC.[TableCode] COLLATE DATABASE_DEFAULT
				WHERE
					t.[name] = ''ScaCompanyProperty'''
			IF @DebugBM & 2 > 0 PRINT @SQLStatement
			EXEC (@SQLStatement)
			FETCH NEXT FROM DB_Cursor INTO @DBName
		END
CLOSE DB_Cursor
DEALLOCATE DB_Cursor

IF CURSOR_STATUS('global','Table_Cursor') >= -1 DEALLOCATE Table_Cursor
DECLARE Table_Cursor CURSOR FOR
	SELECT [DBName], [TableName] FROM #Table ORDER BY [DBName], [TableName]

	OPEN Table_Cursor
	FETCH NEXT FROM Table_Cursor INTO @DBName, @TableName
	WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @DebugBM & 2 > 0 SELECT [@DBName] = @DBName, [@TableName] = @TableName
			SET @SQLStatement  = '
				UPDATE T
				SET
					[RowCount] = (SELECT COUNT(1) FROM [' + @DBName + '].[dbo].[' + @TableName + '])
				FROM
					#Table T
				WHERE
					[DBName] = ''' + @DBName + ''' AND
					[TableName] = ''' + @TableName + ''''
			IF @DebugBM & 2 > 0 PRINT @SQLStatement
			EXEC (@SQLStatement)
			FETCH NEXT FROM Table_Cursor INTO @DBName, @TableName
		END
CLOSE Table_Cursor
DEALLOCATE Table_Cursor

SELECT * FROM #Table WHERE [RowCount] <> 0 ORDER BY [DBName], [TableName] 
DROP TABLE #TableCode
DROP TABLE #Table
DROP TABLE #Company
GO
