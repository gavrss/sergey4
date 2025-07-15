SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Segment_SIE4]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000754,
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
EXEC [spSetup_Segment_SIE4] @UserID=-10, @InstanceID=529, @VersionID=1001, @SourceTypeID = 3, @DebugBM=3

EXEC [spSetup_Segment_SIE4] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup financial segments from SIE4',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2168' SET @Description = 'Procedure created.'

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

	SET @Step = 'INSERT Segments INTO [dbo].[Journal_SegmentNo]'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo]
			(
			[JobID],
			[InstanceID],
			[VersionID],
			[EntityID],
			[Book],
			[SegmentCode],
			[SegmentName]
			)
		SELECT 
			[JobID] = D.[JobID],
			[InstanceID] = D.[InstanceID],
			[VersionID] = @VersionID,
			[EntityID] = J.[EntityID],
			[Book] = 'GL',
			[SegmentCode] = D.[DimCode],
			[SegmentName] = D.DimName
		FROM
			[SIE4_Dim] D
			INNER JOIN [SIE4_Job] J ON J.InstanceID = D.InstanceID AND J.JobID = D.JobID
			INNER JOIN Entity E ON E.EntityID = J.EntityID
		WHERE
			D.InstanceID = @InstanceID AND
			D.JobID = @JobID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN WHERE JSN.InstanceID = D.InstanceID AND JSN.EntityID = E.EntityID AND JSN.Book = 'GL' AND JSN.SegmentCode = D.DimCode)

		SET @Inserted = @Inserted + @@rowcount

	SET @Step = 'INSERT Account INTO [dbo].[Journal_SegmentNo]'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo]
			(
			[JobID],
			[InstanceID],
			[VersionID],
			[EntityID],
			[Book],
			[SegmentCode],
			[SegmentNo],
			[SegmentName],
			[DimensionID]
			)
		SELECT DISTINCT
			[JobID] = D.[JobID],
			[InstanceID] = D.[InstanceID],
			[VersionID] = @VersionID,
			[EntityID] = J.[EntityID],
			[Book] = 'GL',
			[SegmentCode] = -1,
			[SegmentNo] = 0,
			[SegmentName] = 'Account',
			[DimensionID] = -1
		FROM
			[SIE4_Dim] D
			INNER JOIN [SIE4_Job] J ON J.InstanceID = D.InstanceID AND J.JobID = D.JobID
			INNER JOIN Entity E ON E.EntityID = J.EntityID
		WHERE
			D.InstanceID = @InstanceID AND
			D.JobID = @JobID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN WHERE JSN.InstanceID = D.InstanceID AND JSN.EntityID = E.EntityID AND JSN.Book = 'GL' AND JSN.SegmentCode = -1)

		SET @Inserted = @Inserted + @@rowcount

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
