SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_DimensionFilter]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@FilterString nvarchar(4000) = NULL,
	@DimensionFilter nvarchar(max) = NULL OUT,
	@JournalDrillYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000322,
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
declare @DimensionFilter nvarchar(max) = NULL 
EXEC [spGet_DimensionFilter] @FilterString='FiscalYear=2021|Entity=1004|',@InstanceID='527',@UserID='9920',@VersionID='1055',@DebugBM=15, @DimensionFilter = @DimensionFilter OUT, @JournalDrillYN = 1
select [@DimensionFilter] = @DimensionFilter

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spGet_DimensionFilter',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spGet_DimensionFilter] @UserID=3813, @InstanceID=413, @VersionID=1008, @FilterString = 'SpreadingKey = Spread|AccountManager = WF34|Entity = AJ01|GL_Branch = 3B|Scenario = Budget|Time = FY2018', @Debug=1 --CBN
EXEC [spGet_DimensionFilter] @UserID = 2147, @InstanceID = 413, @VersionID = 1008, @FilterString='Entity=1|Book=GL|FiscalYear=2015|Account=746000', @Rows = 100, @Debug = 1

EXEC [spGet_DimensionFilter] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DimensionID INT, 
	@DimensionName NVARCHAR(100),
	@CalledYN BIT,
	@Filter NVARCHAR(4000) = '',
	@LeafLevelFilter NVARCHAR(MAX),
	@CallistoDatabase NVARCHAR(100),
	@StorageTypeBM_Dimension INT,
	@CharIndex INT, 
	@DimFilter NVARCHAR(2000),
	@FilterLen INT,
	@EqualSignPos INT,
	@NodeTypeBM INT,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.1.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Convert filterstring to Leaf Level Members',
			@MandatoryParameter = 'FilterString' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-336: Enhanced Debugging Structure. DB-352: Journal filter on parents for prefixed/suffixed accounts.'
		IF @Version = '2.1.0.2167' SET @Description = 'OBSOLETE, replaced by [spGet_FilterTable].'
		IF @Version = '2.1.1.2179' SET @Description = 'Handle extra separator "|" in @FilterString parameter; this SP should be OBSOLETE, but still called from [spPortalGet_Journal].'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			SelectYN <> 0

	SET @Step = 'Check if called'
		IF OBJECT_ID (N'tempdb..#DimensionFilter', N'U') IS NOT NULL
			BEGIN
				SET @CalledYN = 1
			END
		ELSE
			BEGIN
				SET @CalledYN = 0
				CREATE TABLE #DimensionFilter
					(
					[ID] INT IDENTITY(1,1) PRIMARY KEY,
					[DimensionID] int,
					[DimensionName] nvarchar(100),
					[MemberID] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
					[StorageTypeBM] int,
					[Filter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
					[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[NodeTypeBM] int,
					[DataColumn] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[FilterName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[SelectYN] bit
					)
			END

			CREATE TABLE #DimensionFilterRaw
				(
				[DimensionName] nvarchar(100),
				[MemberKey] nvarchar(100)
				)

	SET @Step = 'Fill temp table #DimensionFilterRaw'
		IF LEN(@FilterString) > 3
			BEGIN
				WHILE CHARINDEX ('|', @FilterString) > 0
					BEGIN
						SET @CharIndex = CHARINDEX('|', @FilterString)
						SET @DimFilter = LTRIM(RTRIM(LEFT(@FilterString, @CharIndex - 1)))
						SELECT
							@EqualSignPos = CHARINDEX('=', @DimFilter),
							@FilterLen = LEN(@DimFilter)
						IF @Debug <> 0 
							SELECT
								[CharIndex] = @CharIndex,
								[DimFilter] = @DimFilter,
								[EqualSignPos] = @EqualSignPos,
								[FilterLen] = @FilterLen,
								[DimensionName] = LTRIM(RTRIM(LEFT(@DimFilter, @EqualSignPos - 1))),
								[FilterValue] = LTRIM(RTRIM(RIGHT(@DimFilter, @FilterLen - @EqualSignPos)))
						
						INSERT INTO #DimensionFilterRaw
							(
							[DimensionName],
							[MemberKey]
							)
						SELECT 
							[DimensionName] = LTRIM(RTRIM(LEFT(@DimFilter, @EqualSignPos - 1))),
							[MemberKey] = LTRIM(RTRIM(RIGHT(@DimFilter, @FilterLen - @EqualSignPos)))

						SET @FilterString = SUBSTRING(@FilterString, @CharIndex + 1, LEN(@FilterString) - @CharIndex)
						IF @Debug <> 0 SELECT [@FilterString] = @FilterString, [LEN_@FilterString] = LEN(@FilterString)
					END

			IF LEN(@FilterString) <> 0
				BEGIN
					SELECT
						@EqualSignPos = CHARINDEX('=', @FilterString),
						@FilterLen = LEN(@FilterString)

					IF @Debug <> 0 
						SELECT
							[CharIndex] = @CharIndex,
							[DimFilter] = @FilterString,
							[EqualSignPos] = @EqualSignPos,
							[FilterLen] = @FilterLen,
							[DimensionName] = LTRIM(RTRIM(LEFT(@FilterString, @EqualSignPos - 1))),
							[FilterValue] = LTRIM(RTRIM(RIGHT(@FilterString, @FilterLen - @EqualSignPos)))

					INSERT INTO #DimensionFilterRaw
						(
						[DimensionName],
						[MemberKey]
						)
					SELECT 
						[DimensionName] = LTRIM(RTRIM(LEFT(@FilterString, @EqualSignPos - 1))),
						[MemberKey] = LTRIM(RTRIM(RIGHT(@FilterString, @FilterLen - @EqualSignPos)))
				END

			END

		IF @Debug <> 0 SELECT TempTable = '#DimensionFilterRaw', * FROM #DimensionFilterRaw ORDER BY DimensionName, MemberKey

	SET @Step = 'Fill temp table #DimensionFilter'
		SET @DimensionFilter = ''
		DECLARE DimensionFilter_Cursor CURSOR FOR

			SELECT DISTINCT
				DimensionID = D.DimensionID,
				DimensionName = ISNULL(D.DimensionName, DFR.DimensionName),
				StorageTypeBM = ISNULL(DST.StorageTypeBM, 1)
			FROM
				#DimensionFilterRaw DFR
				LEFT JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = DFR.DimensionName
				LEFT JOIN Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = D.DimensionID
			ORDER BY
				D.DimensionID,
				ISNULL(D.DimensionName, DFR.DimensionName)

			OPEN DimensionFilter_Cursor
			FETCH NEXT FROM DimensionFilter_Cursor INTO @DimensionID, @DimensionName, @StorageTypeBM_Dimension

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@StorageTypeBM_Dimension] = @StorageTypeBM_Dimension
					
					SET @Filter = ''

					SELECT
						@Filter = @Filter + MemberKey + ','
					FROM
						#DimensionFilterRaw
					WHERE
						DimensionName = @DimensionName
					ORDER BY
						MemberKey

					SET @Filter = LEFT(@Filter, LEN(@Filter) -1)

					IF @Debug <> 0 SELECT [@UserID] = @UserID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@DatabaseName] = @CallistoDatabase, [@DimensionName] = @DimensionName, [@Filter] = @Filter, [@StorageTypeBM] = @StorageTypeBM_Dimension, [@JournalDrillYN] = @JournalDrillYN
					EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @CallistoDatabase, @DimensionName = @DimensionName, @Filter = @Filter, @StorageTypeBM = @StorageTypeBM_Dimension, @JournalDrillYN = @JournalDrillYN, @LeafLevelFilter = @LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT, @Debug = @DebugSub
					IF @Debug <> 0 SELECT [@UserID] = @UserID, [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@DatabaseName] = @CallistoDatabase, [@DimensionName] = @DimensionName, [@Filter] = @Filter, [@StorageTypeBM] = @StorageTypeBM_Dimension, [@JournalDrillYN] = @JournalDrillYN, [@LeafLevelFilter] = @LeafLevelFilter, [@NodeTypeBM] = @NodeTypeBM

					INSERT INTO #DimensionFilter
						(
						[DimensionID],
						[DimensionName],
						[StorageTypeBM],
						[Filter],
						[LeafLevelFilter],
						[NodeTypeBM],
						[SelectYN]
						)
					SELECT
						[DimensionID] = @DimensionID,
						[DimensionName] = @DimensionName,
						[StorageTypeBM] = @StorageTypeBM_Dimension,
						[Filter] = @Filter,
						[LeafLevelFilter] = @LeafLevelFilter,
						[NodeTypeBM] = ISNULL(@NodeTypeBM, 1),
						[SelectYN] = 0

					SET @DimensionFilter = @DimensionFilter + @DimensionName + ' IN (' + @LeafLevelFilter + ') AND '

					FETCH NEXT FROM DimensionFilter_Cursor INTO @DimensionID, @DimensionName, @StorageTypeBM_Dimension
				END

		CLOSE DimensionFilter_Cursor
		DEALLOCATE DimensionFilter_Cursor	

		IF @Debug <> 0 SELECT TempTable = '#DimensionFilter', * FROM #DimensionFilter ORDER BY DimensionID

		SET @DimensionFilter = LEFT(@DimensionFilter, LEN(@DimensionFilter) - 4)
		IF @Debug <> 0 SELECT DimensionFilter = @DimensionFilter

	SET @Step = 'Drop temp tables'
		DROP TABLE #DimensionFilterRaw
		IF @CalledYN = 0 DROP TABLE #DimensionFilter

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
