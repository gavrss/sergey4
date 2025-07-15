SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_JobQueue]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@JobQueueID bigint = NULL OUT,
	@JobQueueStatusID int = NULL,
	@StoredProcedure nvarchar(100) = NULL,
	@Parameter nvarchar(400) = NULL,
	@JobListID int = NULL,
	@SetJobLogYN bit = 1,

	@JobID int = NULL, --Mandatory
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000584,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spSet_JobQueue',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spSet_JobQueue] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spSet_JobQueue] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),

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
	@Version nvarchar(50) = '2.1.1.2172'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Add rows to JobQueue if needed',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2165' SET @Description = 'Added parameter @SetJobLogYN.'
		IF @Version = '2.1.1.2168' SET @Description = 'Updated [JobStatus].'
		IF @Version = '2.1.1.2172' SET @Description = 'Increased size of parameter @Parameter to 400.'

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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@JobQueueID = ISNULL(@JobQueueID, [JobQueueID]),
			@JobQueueStatusID = ISNULL(@JobQueueStatusID, [JobQueueStatusID]),
			@StoredProcedure = ISNULL(@StoredProcedure, [StoredProcedure]),
			@Parameter = ISNULL(@Parameter, [Parameter])
		FROM
			[pcINTEGRATOR_Log].[dbo].[JobQueue]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[JobID] = @JobID

		IF @DebugBM & 2 > 0
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@JobQueueID] = @JobQueueID,
				[@JobQueueStatusID] = @JobQueueStatusID,
				[@StoredProcedure] = @StoredProcedure,
				[@Parameter] = @Parameter,
				[@JobListID] = @JobListID,
				[@JobID] = @JobID

	SET @Step = 'Add row to JobQueue'
		IF	
		@JobQueueID IS NULL AND
		@JobQueueStatusID = 1 AND
		(SELECT COUNT(1) FROM [pcINTEGRATOR_Log].[dbo].[Job] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID AND [JobID] < @JobID AND [JobQueueYN] <> 0 AND [ClosedYN] = 0) > 0
			BEGIN
				INSERT INTO [pcINTEGRATOR_Log].[dbo].[JobQueue]
					(
					[InstanceID],
					[VersionID],
					[UserID],
					[JobID],
					[JobListID],
					[JobQueueStatusID],
					[StoredProcedure],
					[Parameter]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[UserID] = @UserID,
					[JobID] = @JobID,
					[JobListID] = @JobListID,
					[JobQueueStatusID] = @JobQueueStatusID,
					[StoredProcedure] = @StoredProcedure,
					[Parameter] = @Parameter

				SELECT
					@JobQueueID = @@IDENTITY,
					@Inserted = @@ROWCOUNT

				UPDATE J
				SET
					[JobStatus] = 'In Queue'
				FROM
					[pcINTEGRATOR_Log].[dbo].[Job] J
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[JobID] = @JobID
			END
		ELSE IF	
		@JobQueueID IS NOT NULL AND
		@JobQueueStatusID = 1 AND
		(SELECT COUNT(1) FROM [pcINTEGRATOR_Log].[dbo].[Job] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID AND [JobID] < @JobID AND [JobQueueYN] <> 0 AND [ClosedYN] = 0) = 0
			SET @JobQueueStatusID = 2

	SET @Step = 'Release job from JobQueue'
		IF @JobQueueID IS NOT NULL AND @JobQueueStatusID = 2
			BEGIN
				UPDATE JQ
				SET
					[JobQueueStatusID] = @JobQueueStatusID,
					[Updated] = GetDate(),
					[UpdatedBy] = @UserName
				FROM
					[pcINTEGRATOR_Log].[dbo].[JobQueue] JQ
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[JobQueueID] = @JobQueueID

				SET @Updated = @Updated + @@ROWCOUNT

				UPDATE J
				SET
					[JobStatus] = 'In Progress',
					[StartTime] = GetDate()
				FROM
					[pcINTEGRATOR_Log].[dbo].[Job] J
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[JobID] = @JobID

				SET @Updated = @Updated + @@ROWCOUNT

				SET @SQLStatement = 'EXEC ' + @StoredProcedure + ' ' + @Parameter
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Kill job in JobQueue'
		IF @JobQueueID IS NOT NULL AND @JobQueueStatusID = 3
			BEGIN
				UPDATE JQ
				SET
					[JobQueueStatusID] = @JobQueueStatusID,
					[Updated] = GetDate(),
					[UpdatedBy] = @UserName
				FROM
					[pcINTEGRATOR_Log].[dbo].[JobQueue] JQ
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[JobQueueID] = @JobQueueID

				SET @Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
