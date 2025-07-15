SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Get_iScalaTables_New]
	@StartYear int = 2020, --NULL to get all tables initially or 2011 to get all data from that year
	@SourceDatabase nvarchar(100) = NULL, --'iScalaUA',
	@NumberOfCompanies int = 15,
	@DebugBM int = 3

 AS

DECLARE
	@DBName nvarchar(50),
	@TableName nvarchar(50),
	@SQLStatement nvarchar(max),
	@Counter int = 0,
	@CompanyCode nvarchar(50),
	@DBno nvarchar(10)

SELECT DISTINCT [TableCode] INTO #TableCode FROM pcINTEGRATOR..SourceTable WHERE SourceTypeFamilyID = 2 AND ModelBM & 68 > 0
--SELECT [TableCode] INTO #TableCode FROM (SELECT [TableCode] = 'GL03' UNION SELECT 'GL06' UNION SELECT 'GL10' UNION SELECT 'GL12' UNION SELECT 'GL53' UNION SELECT 'PL01' UNION SELECT 'PL22' UNION SELECT 'ScaCompanyProperty' UNION SELECT 'SL01' UNION SELECT 'SL22' UNION SELECT 'ST01' UNION SELECT 'SY24' UNION SELECT 'SYCD' UNION SELECT 'SYCH') sub
IF @DebugBM & 1 > 0 SELECT TempTable = '#TableCode', * FROM #TableCode ORDER BY [TableCode]

SELECT DISTINCT SC.[DBName], SC.[CompanyCode], [DestinationDatabase] = ISNULL(CONVERT(nvarchar(100), @SourceDatabase), SC.[DBName]) INTO #Company 
--SELECT * FROM [ScaSystemDB].[dbo].[ScaCompanies] SC WHERE UPPER(SC.[DBName]) = UPPER('iScalaUA')
FROM [ScaSystemDB].[dbo].[ScaCompanies] SC WHERE (UPPER(SC.[DBName]) = UPPER(@SourceDatabase) OR @SourceDatabase IS NULL) --CompanyName NOT LIKE '%Test%'

IF @SourceDatabase IS NOT NULL AND (SELECT COUNT(1) FROM #Company WHERE [DestinationDatabase] = @SourceDatabase) > @NumberOfCompanies
	BEGIN
		WHILE (SELECT COUNT(1) FROM #Company WHERE [DestinationDatabase] = @SourceDatabase) > 0
			BEGIN
				SET @Counter = @Counter + 1

				SELECT @CompanyCode = MIN([CompanyCode]) FROM #Company WHERE [DestinationDatabase] = @SourceDatabase

				IF @DebugBM & 2 > 0 SELECT ((@Counter - 1) / @NumberOfCompanies) + 1

				SET @DBno = CASE WHEN ((@Counter - 1) / @NumberOfCompanies) + 1 <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), ((@Counter - 1) / @NumberOfCompanies) + 1)

				UPDATE #Company SET [DestinationDatabase] = [DestinationDatabase] + @DBno WHERE [CompanyCode] = @CompanyCode
			END
	END

IF @DebugBM & 1 > 0 SELECT TempTable = '#Company', * FROM #Company ORDER BY [DBName], [CompanyCode]



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
--		[master].[sys].[databases] db
--		INNER JOIN [ScaSystemDB].[dbo].[ScaCompanies] SC ON SC.[DBName] COLLATE DATABASE_DEFAULT = db.[name] COLLATE DATABASE_DEFAULT
		[ScaSystemDB].[dbo].[ScaCompanies] SC 
	WHERE
		(SC.[DBName] = @SourceDatabase OR @SourceDatabase IS NULL)

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
					(LEN(t.[name]) = 8 AND
					ISNUMERIC(RIGHT(t.[name], 2)) <> 0'
					+ CASE WHEN @StartYear IS NULL THEN '' ELSE ' AND (RIGHT(t.[name], 2) = ''00'' OR RIGHT(t.[name], 2) >= ''' + CONVERT(nvarchar(15), @StartYear % 100) + ''')' END + '
					) OR UPPER(t.[name] COLLATE DATABASE_DEFAULT) = UPPER(TC.[TableCode] COLLATE DATABASE_DEFAULT)'
					
--					+ '
				
				
				--UNION SELECT 
				--	[DBName] = ''' + @DBName + ''',
				--	[TableName] = t.[name]
				--FROM
				--	' + @DBName + '.sys.tables t
				--	INNER JOIN #Company CC ON DBName IN (''' + @DBName +''')
				--	INNER JOIN #TableCode TC ON t.[name] COLLATE DATABASE_DEFAULT = TC.[TableCode] COLLATE DATABASE_DEFAULT
				--WHERE
				--	t.[name] = ''ScaCompanyProperty'''
			IF @DebugBM & 2 > 0 PRINT @SQLStatement
			EXEC (@SQLStatement)
			FETCH NEXT FROM DB_Cursor INTO @DBName
		END
CLOSE DB_Cursor
DEALLOCATE DB_Cursor

IF @DebugBM & 2 > 0 SELECT TempTable = '#Table', * FROM #Table

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
