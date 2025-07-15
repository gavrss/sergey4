SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Fact_View]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL,
	@DataClassName nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000865,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [dbo].[spSetup_Fact_View] @UserID = -10, @InstanceID = -1444, @VersionID = -1382, @DebugBM=63

EXEC [spSetup_Fact_View] @UserID=-10, @InstanceID=-1786, @VersionID=-1786, @DataClassName = 'Financials', @DebugBM=3

EXEC [spSetup_Fact_View] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@ViewName nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@SQLColumn nvarchar(max) = '',
	@SQLJoin nvarchar(max) = '',
	@ViewCount int,
	@TableName nvarchar(100),
	@Fact_Type nvarchar(50),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
	@ProcedureName nvarchar(100),
	@DebugSub bit = 0,
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create views built on FACT tables in pcDATA',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2191' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2196' SET @Description = 'Changed data type size for @SQLColumn and @SQLJoin to nvarchar(max).'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = A.[DestinationDatabase]
		FROM
			pcINTEGRATOR_Data..[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0


		IF @DataClassID IS NOT NULL OR @DataClassName IS NOT NULL
			SELECT 
				@DataClassID = ISNULL(@DataClassID, DC.[DataClassID]),
				@DataClassName = ISNULL(@DataClassName, DC.[DataClassName])
			FROM
				pcINTEGRATOR_Data..[DataClass] DC
			WHERE
				DC.[InstanceID] = @InstanceID AND
				DC.[VersionID] = @VersionID AND
				(DC.[DataClassID] = @DataClassID OR @DataClassID IS NULL) AND
				(DC.[DataClassName] = @DataClassName OR @DataClassName IS NULL) AND
				DC.[SelectYN] <> 0 AND
				DC.[DeletedID] IS NULL

		EXEC [spGet_Version] @Version = @Version OUTPUT


		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,
				[@DataClassID] = @DataClassID,
				[@DataClassName] = @DataClassName,
				--[@ViewName] = @ViewName,
				[@Version] = @Version

	SET @Step = 'Create temp tables'		
		CREATE TABLE #DataClassDimension
			(
			[DimensionID] int,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[ColumnName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SelectYN] bit,
			[SortOrder] int
			)

		CREATE TABLE #TableColumn
			(
			[TableName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[ColumnName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)

		CREATE TABLE #Table
			(
			[TableName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[DataClassName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[FACT_Type] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		SET @SQLStatement = '
			INSERT INTO #Table
				(
				[TableName],
				[DataClassName],
				[FACT_Type]
				)		
			SELECT 
				[TableName] = T.[name],
				[DataClassName] = REPLACE(REPLACE(REPLACE (T.[name], ''_default_partition'', ''''), ''FACT_'', ''''), ''_text'', ''''),
				[FACT_Type] = CASE WHEN T.[name] LIKE ''%_text'' THEN ''_text'' ELSE '''' END
			FROM
				' + @CallistoDatabase + '.sys.tables T
			WHERE
				' + CASE WHEN @DataClassName IS NULL THEN '' ELSE 'T.[name] LIKE ''%' + @DataClassName + '%'' AND' END + '
				((T.[name] LIKE ''FACT_%'' AND T.[name] LIKE ''%_default_partition'') OR
				(T.[name] LIKE ''FACT_%'' AND T.[name] LIKE ''%_text''))'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Table', * FROM #Table

		SELECT 
			[DataClassID] = DC.[DataClassID],
			[DataClassName] = DC.[DataClassName],
			[TableName] = T.[TableName],
			[FACT_Type] = T.[FACT_Type]
		INTO
			#DataClassFactView_Cursor_Table
		FROM
			pcINTEGRATOR_Data..[DataClass] DC
			INNER JOIN #Table T ON T.[DataClassName] = DC.[DataClassName]
		WHERE
			DC.[InstanceID] = @InstanceID AND
			DC.[VersionID] = @VersionID AND
			DC.[DataClassTypeID] NOT IN (-5) AND
			DC.[SelectYN] <> 0 AND
			DC.[DeletedID] IS NULL

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DataClassFactView_Cursor_Table', * FROM #DataClassFactView_Cursor_Table

	SET @Step = 'DataClassFactView_Cursor'
		IF CURSOR_STATUS('global','DataClassFactView_Cursor') >= -1 DEALLOCATE DataClassFactView_Cursor
		DECLARE DataClassFactView_Cursor CURSOR FOR
			
			SELECT 
				[DataClassID],
				[DataClassName],
				[TableName],
				[FACT_Type]
			FROM
				#DataClassFactView_Cursor_Table
			ORDER BY
				[TableName]

			OPEN DataClassFactView_Cursor
			FETCH NEXT FROM DataClassFactView_Cursor INTO @DataClassID, @DataClassName, @TableName, @Fact_Type

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DataClassID] = @DataClassID, [@DataClassName] = @DataClassName, [@TableName] = @TableName, [@Fact_Type] = @Fact_Type

					SET @ViewName = 'FACT_' + @DataClassName + @Fact_Type + '_View'

				SET @Step = 'Create table #DataClassDimension'
					TRUNCATE TABLE #DataClassDimension
		
					INSERT INTO #DataClassDimension
						(
						[DimensionID],
						[DimensionName],
						[ColumnName],
						[SelectYN],
						[SortOrder]
						)
					SELECT
						[DimensionID] = DCD.[DimensionID],
						[DimensionName] = D.[DimensionName],
						[ColumnName] = D.[DimensionName],
						[SelectYN] = 0,
						[SortOrder] = 0
					FROM
						pcINTEGRATOR..DataClass_Dimension DCD
						INNER JOIN pcINTEGRATOR..Dimension D ON D.DimensionID = DCD.DimensionID AND D.[DimensionTypeID] <> 27 AND D.[SelectYN] <> 0 AND D.[DeletedID] IS NULL
					WHERE
						DCD.[InstanceID] = @InstanceID AND
						DCD.[VersionID] = @VersionID AND
						DCD.[DataClassID] = @DataClassID AND
						DCD.[SelectYN] <> 0
					ORDER BY
						DCD.[SortOrder]

					IF @DebugBM & 2 > 0 SELECT TempTable = '#DataClassDimension_1', * FROM #DataClassDimension ORDER BY [SortOrder], [ColumnName]

					TRUNCATE TABLE #TableColumn

					SET @SQLStatement = '
						INSERT INTO #TableColumn
							(
							[TableName],
							[ColumnName],
							[SortOrder]
							)		
						SELECT 
							[TableName] = T.[name],
							[ColumnName] = C.[name],
							[SortOrder] = C.[column_id]
						FROM
							' + @CallistoDatabase + '.sys.tables T
							INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON C.[object_id] = T.[object_id]
						WHERE
							T.[name] = ''' + @TableName + ''''

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @DebugBM & 2 > 0 SELECT TempTable = '#TableColumn', * FROM #TableColumn ORDER BY [SortOrder]

					UPDATE DCD
					SET
						[ColumnName] = TC.[ColumnName],
						[SelectYN] = 1,
						[SortOrder] = TC.[SortOrder]
					FROM
						#DataClassDimension DCD
						INNER JOIN #TableColumn TC ON TC.[ColumnName] = DCD.ColumnName + '_MemberId'

					IF @DebugBM & 2 > 0 SELECT TempTable = '#DataClassDimension_2', * FROM #DataClassDimension ORDER BY [SortOrder], [ColumnName]

					INSERT INTO #DataClassDimension
						(
						[DimensionID],
						[DimensionName],
						[ColumnName],
						[SelectYN],
						[SortOrder]
						)
					SELECT
						[DimensionID] = 0,
						[DimensionName] = '',
						[ColumnName] = TC.[ColumnName],
						[SelectYN] = 1,
						[SortOrder] = 100 + TC.[SortOrder]
					FROM
						#TableColumn TC
					WHERE
						TC.[ColumnName] NOT LIKE '%_MemberId'
		
					IF @DebugBM & 2 > 0 SELECT TempTable = '#DataClassDimension_3', * FROM #DataClassDimension ORDER BY [SortOrder], [ColumnName]

				SET @Step = 'Drop existing View'
					SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM ' + @CallistoDatabase + '.sys.views WHERE [name] = ''' + @ViewName + ''''
			
					EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @ViewCount OUT

					IF @DebugBM & 2 > 0 SELECT [@ViewCount] = @ViewCount

					IF @ViewCount > 0
						BEGIN
							SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''DROP VIEW [' + @ViewName + ']'''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Deleted = @Deleted + @@ROWCOUNT
						END

				SET @Step = 'Create new View'
					SELECT @SQLColumn = '', @SQLJoin = ''

					SELECT
						@SQLColumn = @SQLColumn + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN [DimensionID] <> 0 THEN '[' + [DimensionName] + '] = ISNULL([' + [DimensionName] + '].[Label], ''''MemberID = '''' + CONVERT(nvarchar(20), DC.[' + [ColumnName] + ']) + '''' is missing in Dimension'''')' ELSE '[' + [ColumnName] + '] = DC.[' + [ColumnName] + ']' END + ',',
						@SQLJoin = @SQLJoin + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN [DimensionID] <> 0 THEN	'LEFT JOIN [S_DS_' + [DimensionName] + '] [' + [DimensionName] + '] ON [' + [DimensionName] + '].[MemberId] = DC.[' + [ColumnName] + ']' ELSE '' END
					FROM
						#DataClassDimension
					WHERE
						[SelectYN] <> 0
					ORDER BY
						[SortOrder]

					IF @DebugBM & 2 > 0
						BEGIN
							PRINT @SQLColumn
							PRINT @SQLJoin
						END

					SET @SQLStatement = '
			CREATE VIEW [' + @ViewName + '] AS
			-- Current Version: ' + @Version + '
			-- Created: ' + CONVERT(nvarchar(100), @StartTime) + '

			SELECT ' + LEFT(@SQLColumn, LEN(@SQLColumn) - 1)

					SET @SQLStatement = @SQLStatement + '
			FROM
				[' + @TableName + '] DC' + @SQLJoin

					SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

					IF @DebugBM & 2 > 0 
						IF LEN(@SQLStatement) > 4000 
							BEGIN
								PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Create FACT_View'
								EXEC [dbo].[spSet_wrk_Debug]
									@UserID = @UserID,
									@InstanceID = @InstanceID,
									@VersionID = @VersionID,
									@DatabaseName = @DatabaseName,
									@CalledProcedureName = @ProcedureName,
									@Comment = 'Create FACT_View', 
									@SQLStatement = @SQLStatement
							END
						ELSE
							PRINT @SQLStatement
		
					EXEC (@SQLStatement)



					FETCH NEXT FROM DataClassFactView_Cursor INTO @DataClassID, @DataClassName, @TableName, @Fact_Type
				END

		CLOSE DataClassFactView_Cursor
		DEALLOCATE DataClassFactView_Cursor


	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
