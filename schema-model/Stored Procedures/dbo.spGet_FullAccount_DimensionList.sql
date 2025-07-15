SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_FullAccount_DimensionList]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ConversionID int = NULL,
	@AdvancedMappingYN bit = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000479,
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
EXEC spGet_FullAccount_DimensionList @UserID='2147', @InstanceID='454',@VersionID='1021', @ConversionID = 6332, @AdvancedMappingYN  = 0
EXEC spGet_FullAccount_DimensionList @UserID='2147', @InstanceID='454',@VersionID='1021', @ConversionID = 6332, @AdvancedMappingYN  = 1
EXEC spGet_FullAccount_DimensionList @UserID='2147', @InstanceID='454',@VersionID='1021', @ConversionID = 6333, @AdvancedMappingYN  = 1
EXEC spGet_FullAccount_DimensionList @UserID='2147', @InstanceID='454',@VersionID='1021', @ConversionID = 6334, @AdvancedMappingYN  = 0
EXEC spGet_FullAccount_DimensionList @UserID='2147', @InstanceID='454',@VersionID='1021', @ConversionID = 6334, @AdvancedMappingYN  = 1


EXEC [spGet_FullAccount_DimensionList] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,

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
	@Version nvarchar(50) = '2.0.2.2148'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return list of columns for FullAccount',
			@MandatoryParameter = 'ConversionID|AdvancedMappingYN' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'If needed create table #FADimensionList'
		IF OBJECT_ID (N'tempdb..#FADimensionList', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #FADimensionList
					(
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[StorageTypeBM] int,
					[SortOrder] int,
					[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Destination] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[SelectYN] bit,
					[ReadSecurityEnabledYN] bit
					)
			END

	SET @Step = 'Fill table #FADimensionList'
		INSERT INTO #FADimensionList
			(
			DimensionID,
			DimensionName,
			StorageTypeBM,
			SortOrder,
			[SelectYN],
			[ReadSecurityEnabledYN]
			)
		SELECT
			DCD.DimensionID,
			DimensionName = D.DimensionName COLLATE DATABASE_DEFAULT,
			DST.StorageTypeBM,
			DCD.SortOrder,
			[SelectYN] = 1,
			[ReadSecurityEnabledYN] = ISNULL(DST.[ReadSecurityEnabledYN], 0)
		FROM
			DataClass_Dimension DCD
			INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = DCD.DimensionID
			LEFT JOIN Dimension_StorageType DST ON DST.InstanceID = DCD.InstanceID AND DST.DimensionID = DCD.DimensionID
		WHERE
			DCD.InstanceID = @InstanceID AND
			DCD.VersionID = @VersionID AND
			DCD.DataClassID = @ConversionID AND
			DCD.SortOrder > 0
		ORDER BY
			DCD.SortOrder

		IF (SELECT COUNT(1) FROM #FADimensionList WHERE DimensionID = -1) > 0 AND @AdvancedMappingYN <> 0
			BEGIN
				INSERT INTO #FADimensionList
					(
					DimensionID,
					DimensionName,
					StorageTypeBM,
					SortOrder,
					[SelectYN],
					[ReadSecurityEnabledYN]
					)
				SELECT
					DimensionID,
					DimensionName,
					StorageTypeBM = 1,
					SortOrder = -20,
					[SelectYN] = 1,
					[ReadSecurityEnabledYN] = 0
				FROM
					Dimension
				WHERE
					DimensionID = -62

				INSERT INTO #FADimensionList
					(
					DimensionID,
					DimensionName,
					StorageTypeBM,
					SortOrder,
					[SelectYN],
					[ReadSecurityEnabledYN]
					)
				SELECT
					DimensionID,
					DimensionName,
					StorageTypeBM = 4,
					SortOrder = -10,
					[SelectYN] = 1,
					[ReadSecurityEnabledYN] = 0
				FROM
					Dimension
				WHERE
					DimensionID = -65
			END

		UPDATE FADL
		SET
			[Source] = CASE WHEN FADL.SortOrder < 0 THEN DimensionName ELSE 'SourceCol' + CASE WHEN FADL.[SortOrder] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), FADL.[SortOrder]) END,
			[Destination] = CASE WHEN FADL.SortOrder < 0 THEN NULL ELSE 'DestCol' + CASE WHEN FADL.[SortOrder] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), FADL.[SortOrder]) END
		FROM 
			#FADimensionList FADL

	SET @Step = 'Return data'
		IF @CalledYN = 0
			SELECT TempTable = '#FADimensionList', * FROM #FADimensionList ORDER BY SortOrder

	SET @Step = 'Drop temp table'
		IF @CalledYN = 0 DROP TABLE #FADimensionList

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
