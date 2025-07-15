SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Update_SendTo] 
	@Database nvarchar(100) = NULL,
	@DebugBM int = 8

AS

DECLARE
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@TableName nvarchar(100)


	CREATE TABLE #Table
		(
		[TableName] nvarchar(100)
		)

--'Database_Cursor'
		IF CURSOR_STATUS('global','Database_Cursor') >= -1 DEALLOCATE Database_Cursor
		DECLARE Database_Cursor CURSOR FOR
			
			SELECT
				[CallistoDatabase] = [name]
			FROM
				[master].[sys].[databases]
			WHERE
				[name] LIKE 'pcDATA_%' AND
				([name] = @Database OR @Database IS NULL)
			ORDER BY
				[name]

			OPEN Database_Cursor
			FETCH NEXT FROM Database_Cursor INTO @CallistoDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 8 > 0 SELECT [@CallistoDatabase] = @CallistoDatabase
--SendTo
					TRUNCATE TABLE #Table

					SET @SQLStatement = '
						INSERT INTO #Table
							(
							[TableName]
							)
						SELECT
							[TableName] = t.[name]
						FROM
							[' + @CallistoDatabase + '].[sys].[tables] t
							INNER JOIN [' + @CallistoDatabase + '].[sys].[columns] c ON c.[object_id] = t.[object_id] AND c.[name] = ''SendTo''
						WHERE
							t.[name] LIKE ''S_DS_%'' OR t.[name] LIKE ''O_DS_%'''

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					IF @DebugBM & 2 > 0 SELECT TempTable = '#Table', [@CallistoDatabase] = @CallistoDatabase, * FROM #Table ORDER BY [TableName]

				--'Table_Cursor'
					IF CURSOR_STATUS('global','Table_Cursor') >= -1 DEALLOCATE Table_Cursor
					DECLARE Table_Cursor CURSOR FOR
			
						SELECT 
							[TableName]
						FROM
							#Table
						ORDER BY
							[TableName]

						OPEN Table_Cursor
						FETCH NEXT FROM Table_Cursor INTO @TableName

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@TableName] = @TableName

								SET @SQLStatement = '
									UPDATE t1
									SET
										[SendTo] = t1.[Label],
										[SendTo_MemberId] = t1.[MemberId]
									FROM
										[' + @CallistoDatabase + '].[dbo].[' + @TableName + '] t1
									WHERE
										NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[' + @TableName + '] t2 WHERE t2.MemberId = t1.SendTo_MemberId)'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC(@SQLStatement)

								FETCH NEXT FROM Table_Cursor INTO @TableName
							END

					CLOSE Table_Cursor
					DEALLOCATE Table_Cursor

--NodeTypeBM
					TRUNCATE TABLE #Table

					SET @SQLStatement = '
						INSERT INTO #Table
							(
							[TableName]
							)
						SELECT
							[TableName] = t.[name]
						FROM
							[' + @CallistoDatabase + '].[sys].[tables] t
							INNER JOIN [' + @CallistoDatabase + '].[sys].[columns] c ON c.[object_id] = t.[object_id] AND c.[name] = ''NodeTypeBM''
						WHERE
							t.[name] LIKE ''S_DS_%'' OR t.[name] LIKE ''O_DS_%'''

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					IF @DebugBM & 2 > 0 SELECT TempTable = '#Table', [@CallistoDatabase] = @CallistoDatabase, * FROM #Table ORDER BY [TableName]

				--'Table_Cursor'
					IF CURSOR_STATUS('global','Table_Cursor') >= -1 DEALLOCATE Table_Cursor
					DECLARE Table_Cursor CURSOR FOR
			
						SELECT 
							[TableName]
						FROM
							#Table
						ORDER BY
							[TableName]

						OPEN Table_Cursor
						FETCH NEXT FROM Table_Cursor INTO @TableName

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@TableName] = @TableName

								SET @SQLStatement = '
									UPDATE t1
									SET
										[NodeTypeBM] = CASE t1.RNodeType WHEN ''L'' THEN 1 WHEN ''P'' THEN 18 WHEN ''LC'' THEN 9 WHEN ''PC'' THEN 10 ELSE 1 END
									FROM
										[' + @CallistoDatabase + '].[dbo].[' + @TableName + '] t1
									WHERE
										[NodeTypeBM] IS NULL'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC(@SQLStatement)

								FETCH NEXT FROM Table_Cursor INTO @TableName
							END

					CLOSE Table_Cursor
					DEALLOCATE Table_Cursor

					FETCH NEXT FROM Database_Cursor INTO @CallistoDatabase

				END

		CLOSE Database_Cursor
		DEALLOCATE Database_Cursor

DROP TABLE #Table
GO
