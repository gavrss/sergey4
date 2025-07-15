SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR12]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@FromTime int = NULL,
	@ToTime int = NULL,
	@DataClassID int = NULL,
	@DimensionID int = NULL,
	@MemberKey nvarchar(100) = NULL,
	@DimensionFilter nvarchar(4000) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000759,
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
EXEC [spBR_BR12] @UserID=-10, @InstanceID=527, @VersionID=1055, @BusinessRuleID = 2322, @DebugBM = 3

EXEC [spBR_BR12] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@SQLFilter nvarchar(max),
	@SQLJoin nvarchar(max),
	@SQLStatement nvarchar(max),
	@DataClassName nvarchar(100),
	@MemberId bigint,
	@DC_StorageTypeBM int,
	@Dim_StorageTypeBM int,
	@DimensionName nvarchar(100),
	@PropertyDimension nvarchar(100),

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
	@Version nvarchar(50) = '2.1.1.2173'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Change dimension member(s) in DataClass based on dimension filter(s)',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2169' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2173' SET @Description = 'Updated version of temp table #FilterTable.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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
			@DataClassID = ISNULL(@DataClassID, BR12.[DataClassID]),
			@DimensionID = ISNULL(@DimensionID, BR12.[DimensionID])
		FROM
			pcINTEGRATOR_Data..BR12_Master BR12
			INNER JOIN pcINTEGRATOR_Data..BusinessRule BR ON BR.InstanceID = BR12.InstanceID AND BR.VersionID = BR12.VersionID AND BR.BusinessRuleID = BR12.BusinessRuleID AND BR.SelectYN <> 0 AND BR.DeletedID IS NULL
		WHERE
			BR12.InstanceID = @InstanceID AND
			BR12.VersionID = @VersionID AND
			BR12.BusinessRuleID = @BusinessRuleID AND
			BR12.DeletedID IS NULL

		SELECT
			@DataClassName = DC.[DataClassName],
			@DC_StorageTypeBM = DC.[StorageTypeBM]
		FROM
			pcINTEGRATOR_Data..DataClass DC
		WHERE
			DC.[InstanceID] = @InstanceID AND
			DC.[VersionID] = @VersionID AND
			DC.[DataClassID] = @DataClassID AND
			DC.[SelectYN] <> 0 AND
			DC.[DeletedID] IS NULL

		SELECT
			@DimensionName = D.[DimensionName]
		FROM
			pcINTEGRATOR..Dimension D
		WHERE
			D.[InstanceID] IN (0, @InstanceID) AND
			D.[DimensionID] = @DimensionID AND
			D.[SelectYN] <> 0 AND
			D.[DeletedID] IS NULL

		SELECT
			@Dim_StorageTypeBM = DST.StorageTypeBM
		FROM
			pcINTEGRATOR_Data..Dimension_StorageType DST
		WHERE
			DST.[InstanceID] IN (@InstanceID) AND
			DST.[VersionID] = @VersionID AND
			DST.[DimensionID] = @DimensionID

		SELECT
			@CallistoDatabase = [DestinationDatabase],
			@ETLDatabase = [ETLDatabase]
		FROM
			pcINTEGRATOR_Data..[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,
				[@DataClassID] = @DataClassID,
				[@DataClassName] = @DataClassName,
				[@DC_StorageTypeBM] = @DC_StorageTypeBM,
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@Dim_StorageTypeBM] = @Dim_StorageTypeBM,
				[@MemberKey] = @MemberKey,
				[@DimensionFilter] = @DimensionFilter,
				[@FromTime] = @FromTime,
				[@ToTime] = @ToTime

	SET @Step = 'CREATE TABLE #FilterTable'
		CREATE TABLE #FilterTable
			(
			[StepReference] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[TupleNo] int,
			[DimensionID] int,
			[DimensionTypeID] int,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
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

	SET @Step = 'Fill temp table #BR12_Cursor_Table'
		CREATE TABLE [#BR12_Cursor_Table]
			(
			[Comment] [nvarchar](1024) COLLATE DATABASE_DEFAULT,
			[MemberKey] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[MemberId] bigint,
			[DimensionFilter] [nvarchar](4000) COLLATE DATABASE_DEFAULT,
			[SortOrder] [int]
			)

		INSERT INTO [#BR12_Cursor_Table]
			(
			[Comment],
			[MemberKey],
			[DimensionFilter],
			[SortOrder]
			)
		SELECT
			[Comment],
			[MemberKey],
			[DimensionFilter],
			[SortOrder]
		FROM 
			[pcINTEGRATOR_Data].[dbo].[BR12_Step]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[BusinessRuleID] = @BusinessRuleID

		IF (SELECT COUNT(1) FROM [#BR12_Cursor_Table]) = 0
			INSERT INTO [#BR12_Cursor_Table]
				(
				[MemberKey],
				[DimensionFilter],
				[SortOrder]
				)
			SELECT
				[MemberKey] = @MemberKey,
				[DimensionFilter] = @DimensionFilter,
				[SortOrder] = 1

		IF @Dim_StorageTypeBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
					UPDATE CT
					SET
						[MemberId] = D.[MemberId]
					FROM
						[#BR12_Cursor_Table] CT
						INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[Label] = CT.[MemberKey]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#BR12_Cursor_Table', * FROM [#BR12_Cursor_Table] ORDER BY SortOrder

	SET @Step = 'Run BR12_Cursor'
		IF CURSOR_STATUS('global','BR12_Cursor') >= -1 DEALLOCATE BR12_Cursor
		DECLARE BR12_Cursor CURSOR FOR
			SELECT 
				[MemberId],
				[DimensionFilter]
			FROM
				[#BR12_Cursor_Table]
			ORDER BY
				[SortOrder]

			OPEN BR12_Cursor
			FETCH NEXT FROM BR12_Cursor INTO @MemberId, @DimensionFilter

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@MemberId]=@MemberId, [@DimensionFilter]=@DimensionFilter

					EXEC [dbo].[spGet_FilterTable]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@StepReference = 'BR12',
						@PipeString = @DimensionFilter, --Mandatory
						@DatabaseName = @CallistoDatabase, --Mandatory
						@StorageTypeBM_DataClass = 4, --3 returns _MemberKey, 4 returns _MemberId
						@StorageTypeBM = 4, --Mandatory
						@SQLFilter = @SQLFilter OUT,
						@JobID = @JobID
	
					IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable WHERE [StepReference] = 'BR12'
					
					SET @SQLFilter = ''
					SELECT
						@SQLFilter = @SQLFilter + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'DC.[' + [DimensionName] + CASE WHEN @DC_StorageTypeBM & 4 > 0 THEN '_MemberId]' ELSE ']' END + ' IN(' + [LeafLevelFilter] + ') AND'
					FROM
						#FilterTable
					WHERE
						[StepReference] = 'BR12' AND
						LEN([LeafLevelFilter]) > 0
					ORDER BY
						DimensionID

					IF LEN(@SQLFilter) > 3
						SET @SQLFilter = LEFT(@SQLFilter, LEN(@SQLFilter) - 3)

					--Property_Cursor
					SET @SQLJoin = ''

					IF CURSOR_STATUS('global','Property_Cursor') >= -1 DEALLOCATE Property_Cursor
					DECLARE Property_Cursor CURSOR FOR
			
						SELECT DISTINCT
							[PropertyDimension] = [DimensionName]
						FROM
							#FilterTable
						WHERE
							[StepReference] = 'BR12' AND
							LEN([PropertyName]) > 0
						ORDER BY
							[DimensionName]

						OPEN Property_Cursor
						FETCH NEXT FROM Property_Cursor INTO @PropertyDimension

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@PropertyDimension] = @PropertyDimension

								SET @SQLJoin = @SQLJoin + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @PropertyDimension + '] [' + @PropertyDimension + '] ON [' + @PropertyDimension + '].[MemberId] = DC.[' + @PropertyDimension + '_MemberId]'

								SELECT
									@SQLJoin = @SQLJoin + ' AND [' + @PropertyDimension + '].[' + [PropertyName] + '] IN (''' + [Filter] + ''')'
								FROM
									#FilterTable
								WHERE
									[StepReference] = 'BR12' AND
									[DimensionName] = @PropertyDimension AND
									LEN([PropertyName]) > 0
								ORDER BY
									[PropertyName]
								
								FETCH NEXT FROM Property_Cursor INTO @PropertyDimension
							END

					CLOSE Property_Cursor
					DEALLOCATE Property_Cursor

					SET @SQLStatement = '
						UPDATE DC
						SET
							[' + @DimensionName + '_MemberId] = ' + CONVERT(nvarchar(20), @MemberId) + '
						FROM
							[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition] DC
							' + @SQLJoin + '
						' + CASE WHEN LEN(@SQLFilter) > 3 OR LEN(@FromTime) > 3 OR LEN(@ToTime) > 3 THEN 'WHERE' ELSE '' END
						+ CASE WHEN LEN(@FromTime) > 3 THEN 'DC.[Time_MemberId] >= ' + CONVERT(nvarchar(15), @FromTime) + ' AND ' ELSE '' END
						+ CASE WHEN LEN(@ToTime) > 3 THEN 'DC.[Time_MemberId] <= ' + CONVERT(nvarchar(15), @ToTime) + ' AND ' ELSE '' END
						+ CASE WHEN LEN(@SQLFilter) > 3 THEN @SQLFilter + ' AND ' ELSE '' END

					IF RIGHT(RTRIM(@SQLStatement), 4) = ' AND '
						SET @SQLStatement = LEFT(RTRIM(@SQLStatement), LEN(RTRIM(@SQLStatement)) - 4)

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @Updated = @Updated + @@ROWCOUNT

					FETCH NEXT FROM BR12_Cursor INTO @MemberId, @DimensionFilter
				END

		CLOSE BR12_Cursor
		DEALLOCATE BR12_Cursor	

	SET @Step = 'Drop temp tables'
		DROP TABLE #FilterTable
		DROP TABLE #BR12_Cursor_Table

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
