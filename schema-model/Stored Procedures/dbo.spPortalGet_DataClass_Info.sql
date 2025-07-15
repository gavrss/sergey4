SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_DataClass_Info]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL, --@DataClassID OR @DataClassName is mandatory
	@DataClassName nvarchar(50) = NULL, --@DataClassID OR @DataClassName is mandatory
	@Filter nvarchar(max) = NULL,
	@ResultTypeBM int = 3, --1=List of members, 2=Number of rows
	@MemberKeyYN bit = 1,
	@MemberIDYN bit = 0,
	@MemberKeySuffixYN bit = 0,
	@OrderBy nvarchar(1000) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000842,
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
EXEC [pcINTEGRATOR].[dbo].[spPortalGet_DataClass_Info]
	@UserID='15383',
	@InstanceID='454',
	@VersionID='1021',
	--@DataClassID='7736',
	@DataClassName='Financials',
	@Filter='BusinessProcess=CONSOLIDATED|Scenario=Actual|Version=NONE|Time=2021,2022|Entity.Currency=CAD',
	@ResultTypeBM=3,
	@MemberIDYN = 0,
	@Rows = 2500,
	@OrderBy = 'ChangeDatetime DESC, Account_MemberKey',
	@DebugBM=0

EXEC [spPortalGet_DataClass_Info] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DataClassDatabase nvarchar(100),
	@StepReference nvarchar(20),
	@DataClassTypeID int,
	@StorageTypeBM int,
	@SQLStatement nvarchar(max),
	@SQL_Where nvarchar(max) = '',
	@SQL_Join nvarchar(4000) = '',
	@SQL_Join_PropertyFilter nvarchar(4000) = '',
	@SQL_Select nvarchar(4000) = '',

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2187'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Template for creating SPs',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2187' SET @Description = 'Procedure created.'

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
			@DataClassID = ISNULL(@DataClassID, [DataClassID]),
			@DataClassName = ISNULL(@DataClassName, [DataClassName]),
			@DataClassTypeID = [DataClassTypeID],
			@StorageTypeBM = [StorageTypeBM]
		FROM
			[pcINTEGRATOR_Data].[dbo].[DataClass]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			([DataClassID] = @DataClassID OR @DataClassID IS NULL) AND
			([DataClassName] = @DataClassName OR @DataClassName IS NULL) AND
			[SelectYN] <> 0 AND
			[DeletedID] IS NULL

		SELECT
			@DataClassDatabase = CASE WHEN @StorageTypeBM & 4 > 0 THEN [DestinationDatabase] ELSE [ETLDatabase] END
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0

		SELECT
			@Rows = ISNULL(@Rows, 1000),
			@StepReference = 'DC_Info'

		IF @DebugBM & 2 > 0
			SELECT
				[@Rows] = @Rows,
				[@DataClassDatabase] = @DataClassDatabase,
				[@DataClassID] = @DataClassID,
				[@DataClassName] = @DataClassName,
				[@DataClassTypeID] = @DataClassTypeID,
				[@StorageTypeBM] = @StorageTypeBM

	SET @Step = 'Fill #FilterTable'
		IF OBJECT_ID(N'TempDB.dbo.#FilterTable', N'U') IS NULL
			CREATE TABLE #FilterTable
				(
				[StepReference] nvarchar(20) COLLATE DATABASE_DEFAULT,
				[TupleNo] int,
				[DimensionID] int,
				[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
				[DimensionTypeID] int,
				[StorageTypeBM] int,
				[MultiDimIncludedYN] bit DEFAULT 0,
				[SortOrder] int,
				[ObjectReference] nvarchar(100) COLLATE DATABASE_DEFAULT,
				[HierarchyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
				[PropertyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
				[JournalColumn] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
				[Filter] nvarchar(max) COLLATE DATABASE_DEFAULT,
				[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
				[PropertyFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
				[Segment] nvarchar(20) COLLATE DATABASE_DEFAULT,
				[Method] nvarchar(20) COLLATE DATABASE_DEFAULT
				)

		EXEC pcINTEGRATOR.dbo.[spGet_FilterTable]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DataClassID = @DataClassID,
			@PipeString = @Filter,
			@DatabaseName = @DataClassDatabase, --Mandatory
			@StorageTypeBM_DataClass = 4, --3 returns _MemberKey, 4 returns _MemberId
			@StorageTypeBM = @StorageTypeBM, --Mandatory
			@StepReference = @StepReference,
			@Debug = @DebugSub

--		DELETE FT FROM #FilterTable FT WHERE FT.DimensionTypeID IN (50)

		IF @DebugBM & 2 > 0 SELECT * FROM #FilterTable WHERE [StepReference] = @StepReference

	SET @Step = 'Fill #SysColumns'
		CREATE TABLE #SysColumns ([name] nvarchar(100), [column_id] int)

		SET @SQLStatement = '
			INSERT INTO #SysColumns
				(
				[name],
				[column_id]
				)
			SELECT
				c.[name],
				c.[column_id]
			FROM
				[' + @DataClassDatabase + '].[sys].[tables] t
				INNER JOIN [' + @DataClassDatabase + '].[sys].[columns] c ON c.[object_id] = t.[object_id] 
			WHERE
				t.[name] = ''FACT_' + @DataClassName + '_default_partition'''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT TempTable = '#SysColumns', * FROM #SysColumns

		SELECT
			FT.[DimensionName],
			FT.[LeafLevelFilter],
			FT.[PropertyName],
			FT.[Filter],
			FT.[SortOrder],
			SC.[column_id]
		INTO
			#FT
		FROM
			#FilterTable FT
			INNER JOIN #SysColumns SC ON SC.[name] = FT.[DimensionName] + '_MemberId'
		WHERE
			FT.[StepReference] = @StepReference

		SELECT
			@SQL_Select = @SQL_Select + CASE WHEN @MemberIDYN <> 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [DimensionName] + '_MemberId] = DC.[' + [DimensionName] + '_MemberId],' ELSE '' END  + CASE WHEN @MemberKeyYN <> 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [DimensionName] + CASE WHEN @MemberKeySuffixYN <> 0 THEN '_MemberKey' ELSE '' END + '] = [' + [DimensionName] + '].[Label],' ELSE '' END,
			@SQL_Where = @SQL_Where + 
				CASE WHEN ISNULL(FT.[LeafLevelFilter], '') <> '' AND ISNULL(FT.[PropertyName], '') = ''
				THEN
					CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'DC.[' + FT.[DimensionName] + '_MemberID] IN (' + FT.[LeafLevelFilter] + ') AND'
				ELSE
					''
				END,
			@SQL_Join = @SQL_Join + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN ISNULL(FT.[PropertyName], '') <> '' AND ISNULL(FT.[Filter], '') <> '' THEN 'INNER' ELSE 'LEFT' END + ' JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_' + FT.[DimensionName] + '] [' + FT.[DimensionName]  + '] ON [' + FT.[DimensionName] + '].[MemberId] = DC.[' + FT.[DimensionName] + '_MemberId] ' + CASE WHEN ISNULL(FT.[PropertyName], '') <> '' AND ISNULL(FT.[Filter], '') <> '' THEN 'AND [' + FT.[DimensionName] + '].[' + FT.[PropertyName] + '] = ''' + FT.[Filter] + '''' ELSE '' END,
			@SQL_Join_PropertyFilter = @SQL_Join_PropertyFilter + CASE WHEN ISNULL(FT.[PropertyName], '') <> '' AND ISNULL(FT.[Filter], '') <> '' THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_' + FT.[DimensionName] + '] [' + FT.[DimensionName]  + '] ON [' + FT.[DimensionName] + '].[MemberId] = DC.[' + FT.[DimensionName] + '_MemberId] AND [' + FT.[DimensionName] + '].[' + FT.[PropertyName] + '] = ''' + FT.[Filter] + '''' ELSE '' END 
		FROM
			#FT FT
		ORDER BY
			FT.[DimensionName],
			FT.[SortOrder],
			FT.[column_id]

		SELECT
			@SQL_Select = @SQL_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + SC.[name] + '] = DC.[' + SC.[name] + '],'
		FROM
			#SysColumns SC 
		WHERE
			NOT EXISTS (SELECT 1 FROM #FilterTable FT WHERE FT.[StepReference] = @StepReference AND FT.[DimensionName] + '_MemberId' = SC.[name])
		ORDER BY
			SC.[column_id],
			SC.[name]

	SET @Step = 'Get ReadAccess'
		CREATE TABLE #ReadAccess
			(
			[DimensionID] int,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[StorageTypeBM] int,
			[Filter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[DataColumn] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SelectYN] bit
			)

		EXEC [spGet_ReadAccess] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @ActingAs = NULL, @StorageTypeBM_DataClass = @StorageTypeBM, @JobID = @JobID, @Debug = @DebugSub

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ReadAccess', * FROM #ReadAccess

		SELECT
			@SQL_Where = @SQL_Where + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'DC.[' + RA.[DimensionName] + '_MemberID] IN (' + RA.[LeafLevelFilter] + ') AND'
		FROM
			#ReadAccess RA
		WHERE
			ISNULL(RA.[LeafLevelFilter], '') <> ''
		ORDER BY
			RA.[DimensionName]

		SELECT
			@SQL_Select = CASE WHEN LEN(@SQL_Select) > 3 THEN LEFT(@SQL_Select, LEN(@SQL_Select) - 1) ELSE '' END,
			@SQL_Where = CASE WHEN LEN(@SQL_Where) > 3 THEN LEFT(@SQL_Where, LEN(@SQL_Where) - 4) ELSE '' END
		
		IF @DebugBM & 2 > 0
			SELECT
				[@SQL_Select] = @SQL_Select,
				[@SQL_Where] = @SQL_Where,
				[@SQL_Join] = @SQL_Join,
				[@SQL_Join_PropertyFilter] = @SQL_Join_PropertyFilter

	SET @Step = '@ResultTypeBM & 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT TOP ' + CONVERT(nvarchar(15), @Rows) + '
						[ResultTypeBM] = 1,' + @SQL_Select + '
					FROM'

				SET @SQLStatement = @SQLStatement + '
						[' + @DataClassDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition] DC' + CASE WHEN @MemberKeyYN <> 0 THEN @SQL_Join ELSE @SQL_Join_PropertyFilter END

				SET @SQLStatement = @SQLStatement + '
					' + CASE WHEN LEN(@SQL_Where) > 0 THEN 'WHERE' +  @SQL_Where ELSE '' END

				SET @SQLStatement = @SQLStatement + '
					' + CASE WHEN LEN(@OrderBy) > 0 THEN 'ORDER BY
						' +  @OrderBy ELSE '' END

				IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000 
					BEGIN
						PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Return ResultTypeBM = 1'
						EXEC [dbo].[spSet_wrk_Debug]
							@UserID = @UserID,
							@InstanceID = @InstanceID,
							@VersionID = @VersionID,
							@DatabaseName = @DatabaseName,
							@CalledProcedureName = @ProcedureName,
							@Comment = 'Return ResultTypeBM = 1', 
							@SQLStatement = @SQLStatement
					END
				ELSE
					PRINT @SQLStatement

				EXEC (@SQLStatement)
			END

	SET @Step = '@ResultTypeBM & 2'

		IF @ResultTypeBM & 2 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT 
						[ResultTypeBM] = 2,
						[Rows] = COUNT(1)
					FROM
						[' + @DataClassDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition] DC' + @SQL_Join_PropertyFilter + '
					' + CASE WHEN LEN(@SQL_Where) > 0 THEN 'WHERE' +  @SQL_Where ELSE '' END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

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
