SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_ZeroValue_sega]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000703,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spSet_ZeroValue] @UserID=-10, @InstanceID=454, @VersionID=1021, @DataClassID=7736, @Debug=1

EXEC [spSet_ZeroValue] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@ColumnName nvarchar(100),
	@DataType nvarchar(20),
	@ColumnType nvarchar(10),
	@StorageTypeBM int,
	@SQL_ColumnList nvarchar(4000) = '',
	@SQL_GroupBy nvarchar(4000) = '',
	@SQL_NotExist nvarchar(4000) = '',
	@DataClassName nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@WorkflowStateYN bit,
	@DimensionID int,

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
	@Version nvarchar(50) = '2.1.1.2169'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Delete not needed Zero values from selected DataClass',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Handle DimensionType AutoMultiDim. Split setting @SQLStatement into 2 sections.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

		SELECT
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			pcINTEGRATOR_Data..[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID

		SELECT
			@DataClassName = DataClassName,
			@StorageTypeBM = StorageTypeBM
		FROM
			pcINTEGRATOR_Data..DataClass DC
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.VersionID = @VersionID AND
			DC.DataClassID = @DataClassID

		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,
				[@ETLDatabase] = @ETLDatabase,
				[@DataClassName] = @DataClassName,
				[@StorageTypeBM] = @StorageTypeBM

	SET @Step = 'Check @StorageTypeBM'
		IF @StorageTypeBM & 4 = 0
			BEGIN
				SET @Message = 'This routine only handle DataClasses stored in Callisto.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Create cursor table for creating temp tables for data'
		CREATE TABLE #DataClassList
			(
			[DimensionID] int,
			[ColumnName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[DataType] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[ColumnType] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)

		INSERT INTO #DataClassList
			(
			[DimensionID],
			[ColumnName],
			[DataType],
			[ColumnType],
			[SortOrder]
			)
		SELECT
			[DimensionID] = DCD.[DimensionID],
			[ColumnName] = D.[DimensionName] + '_MemberId',
			[DataType] = 'bigint',
			[ColumnType] = 'Dimension',
			[SortOrder] = DCD.[SortOrder]
		FROM
			pcINTEGRATOR_Data..DataClass_Dimension DCD
			INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID AND D.DimensionTypeID <> 27
		WHERE
			DCD.InstanceID = @InstanceID AND
			DCD.VersionID = @VersionID AND
			DCD.DataClassID = @DataClassID AND
			DCD.DimensionID NOT IN (-77)

		UNION
		SELECT
			[DimensionID] = NULL,
			[ColumnName] = M.[MeasureName] + '_Value',
			[DataType] = 'float',
			[ColumnType] = 'Measure',
			[SortOrder] = 10000 + M.[SortOrder]
		FROM
			pcINTEGRATOR_Data..Measure M
		WHERE
			M.InstanceID = @InstanceID AND M.VersionID = @VersionID AND M.DataClassID = @DataClassID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DataClassList', * FROM #DataClassList ORDER BY SortOrder

	SET @Step = 'SET @WorkflowStateYN'
		IF (SELECT COUNT(1) FROM #DataClassList WHERE DimensionID = -63) > 0
			SET @WorkflowStateYN = 1
		ELSE
			SET @WorkflowStateYN = 0

		IF @WorkflowStateYN = 0 GOTO DELETEPOINT

	SET @Step = 'Create temp tables for data'
		CREATE TABLE #KeepZeroValue
			(
			[Dummy] int
			)
IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Run cursor for adding columns to temp tables for data'
		IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
		DECLARE AddColumn_Cursor CURSOR FOR
			SELECT
				[DimensionID],
				[ColumnName],
				[DataType],
				[ColumnType]
			FROM
				#DataClassList
			ORDER BY
				DataType DESC,
				SortOrder

			OPEN AddColumn_Cursor
			FETCH NEXT FROM AddColumn_Cursor INTO @DimensionID, @ColumnName, @DataType, @ColumnType

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = '
						ALTER TABLE #KeepZeroValue ADD [' + @ColumnName + '] ' + @DataType

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

					IF @ColumnType = 'Dimension' SELECT @SQL_ColumnList = @SQL_ColumnList + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @ColumnName + '],'
					IF @ColumnType = 'Dimension' SELECT @SQL_GroupBy = @SQL_GroupBy + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @ColumnName + '],'
					IF @ColumnType = 'Dimension' AND @DimensionID NOT IN (-55, -63) SELECT @SQL_NotExist = @SQL_NotExist + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'FD.[' + @ColumnName + '] = F.[' + @ColumnName + '] AND'

					FETCH NEXT FROM AddColumn_Cursor INTO @DimensionID, @ColumnName, @DataType, @ColumnType
				END

		CLOSE AddColumn_Cursor
		DEALLOCATE AddColumn_Cursor

		SET @SQL_GroupBy = LEFT(@SQL_GroupBy, LEN(@SQL_GroupBy) -1)
IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Add StorageType specific columns'
		IF @StorageTypeBM & 4 > 0
			BEGIN
				ALTER TABLE #KeepZeroValue ADD [ChangeDatetime] datetime
				ALTER TABLE #KeepZeroValue ADD [UserId] nvarchar(100)
			END

	SET @Step = 'Fill temp table #KeepZeroValue'
		SET @SQLStatement = '
			INSERT INTO #KeepZeroValue
				(' + @SQL_ColumnList + '
				[ChangeDatetime],
				[UserId],
				[' + @DataClassName + '_Value]
				)
			SELECT' + @SQL_ColumnList + '
				[ChangeDatetime] = MAX(CONVERT(datetime, [ChangeDatetime])),
				[UserId] = MAX([UserId]),
				[' + @DataClassName + '_Value] = 0
			FROM
				' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition] F
			WHERE
				[' + @DataClassName + '_Value] = 0 AND
				[WorkflowState_MemberID] <> -1 AND'

		SET @SQLStatement = @SQLStatement + '
				NOT EXISTS (SELECT 1 FROM
					(
					SELECT DISTINCT
						[WorkflowStateID] = [InitialWorkflowStateID]
					FROM
						[pcINTEGRATOR_Data].[dbo].[Workflow]
					WHERE
						InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						VersionID = ' + CONVERT(nvarchar(15), @VersionID) + '
					UNION SELECT DISTINCT
						[WorkflowStateID] = [RefreshActualsInitialWorkflowStateID]
					FROM [pcINTEGRATOR_Data].[dbo].[Workflow]
					WHERE
						InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						VersionID = ' + CONVERT(nvarchar(15), @VersionID) + '
					) WS WHERE WS.WorkflowStateID = F.WorkflowState_MemberId) AND
				NOT EXISTS (SELECT 1 FROM ' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition] FD
					WHERE' + @SQL_NotExist + '
						FD.[' + @DataClassName + '_Value] <> 0
						)
			GROUP BY' + @SQL_GroupBy

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Selected = @Selected + @@ROWCOUNT
IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#KeepZeroValue', * FROM #KeepZeroValue

	SET @Step = 'Delete rows'
		DELETEPOINT:

		SET @SQLStatement = '
			DELETE F
			FROM
				' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition] F
			WHERE
				[' + @DataClassName + '_Value] = 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT
IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

		IF @WorkflowStateYN = 0 GOTO DURATIONPOINT

	SET @Step = 'Reinsert saved rows'
		SET @SQLStatement = '
			INSERT INTO ' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition]
				(' + @SQL_ColumnList + '
				[ChangeDatetime],
				[UserId],
				[' + @DataClassName + '_Value]
				)
			SELECT' + @SQL_ColumnList + '
				[ChangeDatetime],
				[UserId],
				[' + @DataClassName + '_Value]
			FROM
				#KeepZeroValue'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT
IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Drop temp tables'
		DROP TABLE #KeepZeroValue

	SET @Step = 'Set @Duration'
		DURATIONPOINT:
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
