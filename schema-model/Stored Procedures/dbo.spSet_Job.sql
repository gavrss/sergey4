SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_Job]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ActionType nvarchar(10) = NULL, --Mandatory Start/End/Error
	@MasterCommand nvarchar(100) = NULL, --Mandatory
	@CurrentCommand nvarchar(100) = NULL, --Mandatory
	@TimeOut time(7) = '03:00:00',
	@JobQueueYN bit = 1,
	@CheckCount int = 0,
	@JobListID int = NULL,

	@JobID int = NULL OUT,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000625,
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
--Start
EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Start', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobQueueYN=1, @CheckCount=0, @JobListID=@JobListID, @JobID=@JobID OUT

--Status
EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Start', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobQueueYN=1, @JobListID=@JobListID, @JobID=@JobID OUT

--End
EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='End', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobID=@JobID


EXEC [spSet_Job] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables

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
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create new jobs, set status and end jobs.',
			@MandatoryParameter = 'ActionType|MasterCommand|CurrentCommand' --Without @, separated by |

		IF @Version = '2.1.0.2159' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2162' SET @Description = 'Added @Timeout as parameter.'
		IF @Version = '2.1.1.2168' SET @Description = 'Added [JobStatus]. Set @UserID to 0 if NULL.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
--			@JobID = ISNULL(@JobID, @ProcedureID),
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

		IF @DebugBM & 2 > 0 SELECT [@ActionType] = @ActionType, [@MasterCommand] = @MasterCommand, [@CurrentCommand] = @CurrentCommand

		SET @UserID = ISNULL(@UserID, 0)

	SET @Step = 'Insert new Job'
		IF @ActionType = 'Start' AND @JobID IS NULL
			BEGIN
				INSERT INTO [pcINTEGRATOR_Log].[dbo].[Job]
					(
					[InstanceID],
					[VersionID],
					[UserID],
					[JobQueueYN],
					[JobListID],
					[MasterCommand],
					[CheckCount],
					[StartTime],
					[JobStatus],
					[CurrentCommand],
					[CurrentCommand_StartTime],
					[TimeOut]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[UserID] = @UserID,
					[JobQueueYN] = @JobQueueYN,
					[JobListID] = @JobListID,
					[MasterCommand] = @MasterCommand,
					[CheckCount] = @CheckCount,
					[StartTime] = GetDate(),
					[JobStatus] = 'Waiting', --'Waiting,In Queue,In Progress,Finalized,Error'
					[CurrentCommand] = @CurrentCommand,
					[CurrentCommand_StartTime] = GetDate(),
					[TimeOut] = @TimeOut

				SELECT
					@JobID = @@IDENTITY,
					@Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Update Status'
		IF @ActionType NOT IN ('End', 'Error') AND @JobID IS NOT NULL
			BEGIN
				UPDATE J 
				SET
					[JobStatus] = 'In Progress', --'Waiting,In Queue,In Progress,Finalized,Error'
					[CurrentCommand] = @CurrentCommand,
					[CurrentCommand_StartTime] = GetDate()
				FROM
					[pcINTEGRATOR_Log].[dbo].[Job] J
				WHERE
					[JobID] = @JobID

				SET	@Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'End Job'
		IF @ActionType = 'End' AND @JobID IS NOT NULL
			BEGIN
				UPDATE J 
				SET
					[JobStatus] = 'Finalized', --'Waiting,In Queue,In Progress,Finalized,Error'
					[EndTime] = GetDate(),
					[ClosedYN] = 1 
				FROM
					[pcINTEGRATOR_Log].[dbo].[Job] J
				WHERE
					[JobID] = @JobID AND
					[MasterCommand] IN (@MasterCommand) --, 'spRun_Job_Callisto_Generic', 'spRun_Job_Tabular_Generic', 'spPortalAdmin_LoadCallisto')

				SET	@Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'Job Error'
		IF @ActionType = 'Error' AND @JobID IS NOT NULL
			BEGIN
				UPDATE J 
				SET
					[JobStatus] = 'Error', --'Waiting,In Queue,In Progress,Finalized,Error'
					[ErrorTime] = GetDate(),
					[ClosedYN] = 1 
				FROM
					[pcINTEGRATOR_Log].[dbo].[Job] J
				WHERE
					[JobID] = @JobID AND
					[MasterCommand] IN (@MasterCommand) --, 'spRun_Job_Callisto_Generic', 'spRun_Job_Tabular_Generic', 'spPortalAdmin_LoadCallisto')

				SET	@Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
--		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
