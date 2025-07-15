SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_JobAgent_Status]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Status nvarchar(10) = NULL, --Start, Success, Failure
	@MasterCommand nvarchar(100) = NULL,
	@JobName nvarchar(255) = NULL,
	@StepName nvarchar(255) = NULL,

	@JobID int = NULL, --Mandatory for @Status IN (Success, Failure)
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000581,
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
EXEC [spSet_JobAgent_Status] @UserID=-10, @InstanceID=52, @VersionID=1035, @Status = 'Start', @JobName = 'Callisto_Generic01', @StepName = 'ETLFull', @Debug=1
EXEC [spSet_JobAgent_Status] @UserID=-10, @InstanceID=52, @VersionID=1035, @Status = 'Start', @JobName = 'Callisto_Generic01', @StepName = 'ETLFull_2', @Debug=1
EXEC [spSet_JobAgent_Status] @UserID=-10, @InstanceID=52, @VersionID=1035, @Status = 'Start', @JobName = 'Callisto_Generic01', @StepName = 'ETLFull_3_Deploy', @Debug=1
EXEC [spSet_JobAgent_Status] @UserID=-10, @InstanceID=52, @VersionID=1035, @Status = 'Success', @JobName = 'Callisto_Generic01', @StepName = 'Success', @Debug=1

EXEC [spSet_JobAgent_Status] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@ActionType nvarchar(10),
	@FailStepTime datetime,
	@job_id uniqueidentifier,
	@step_id int,

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
	@Version nvarchar(50) = '2.1.0.2165'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set JobAgent Status',
			@MandatoryParameter = 'Status|JobName' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2159' SET @Description = 'Use sub routine [spSet_Job]. Add parameter @MasterCommand.'
		IF @Version = '2.1.0.2160' SET @Description = 'Removed variable @JobStartTime.'
		IF @Version = '2.1.0.2162' SET @Description = 'Set @Deleted, @Inserted, @Updated, @Selected in Job table.'
		IF @Version = '2.1.0.2165' SET @Description = 'Enhanced logging.'

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

		EXEC spGet_User @UserID = @UserID, @UserName = @UserName OUT
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = '@Status = Failure'
		IF @Status = 'Failure'
			BEGIN
				INSERT INTO pcINTEGRATOR_Log.dbo.wrk_JobAgent_Error
					(
					[@UserID],
					[@InstanceID],
					[@VersionID],
					[@JobName],
					[@StepName],
					[@JobID]
					)
				SELECT 
					[@UserID] = @UserID,
					[@InstanceID] = @InstanceID,
					[@VersionID] = @VersionID,
					[@JobName] = @JobName,
					[@StepName] = @StepName,
					[@JobID] = @JobID

				SELECT 
					@job_id = H.[job_id],
					@FailStepTime = MAX(msdb.dbo.agent_datetime(H.run_date, H.run_time))
				FROM
					[msdb].[dbo].[sysjobhistory] H 
					INNER JOIN [msdb].[dbo].[sysjobs] J ON J.[name] = @JobName AND J.[job_id] = H.[job_id]
				WHERE
					H.run_status = 0
				GROUP BY
					 H.[job_id]

				SELECT 
					@step_id = H.[step_id]
				FROM
					[msdb].[dbo].[sysjobhistory] H 
				WHERE
					H.[job_id] = @job_id AND
					msdb.dbo.agent_datetime(H.run_date, H.run_time) = @FailStepTime AND
					H.run_status = 0

				IF @DebugBM & 2 > 0 SELECT [@job_id] = @job_id, [@FailStepTime] = @FailStepTime, [@step_id] = @step_id

				UPDATE JAE
				SET
					[@job_id] = @job_id,
					[@FailStepTime] = @FailStepTime,
					[@step_id] = @step_id,
					[Updated] = GetDate()
				FROM
					 pcINTEGRATOR_Log.dbo.wrk_JobAgent_Error JAE
				WHERE
					[@UserID] = @UserID AND
					[@InstanceID] = @InstanceID AND
					[@VersionID] = @VersionID AND
					[@JobName] = @JobName AND
					[@StepName] = @StepName AND
					[@JobID] = @JobID

				INSERT INTO [pcINTEGRATOR_Log].[dbo].[JobLog]
					(
					[JobID],
					[StartTime],
					[ProcedureID],
					[ProcedureName],
					[Duration],
					[ErrorNumber],
					[ErrorSeverity],
					[ErrorStep],
					[ErrorMessage],
					[Version],
					[Parameter],
					[UserName],
					[UserID],
					[InstanceID],
					[VersionID]
					)
				SELECT TOP (1000) 
					[JobID] = @JobID,
					[StartTime] = GetDate(),
					[ProcedureID] = @ProcedureID,
					[ProcedureName] = @JobName + '.' + H.[step_name],
					[Duration] = CONVERT(time(7), CONVERT(nvarchar(20), (H.[run_duration] / 3600)) + ':' + CONVERT(nvarchar(20), ((H.[run_duration] % 3600) / 60))  + ':' +  CONVERT(nvarchar(20),(H.[run_duration] % 60))),
					[ErrorNumber] = 5000,
					[ErrorSeverity] = 16,
					[ErrorStep] = H.[step_name],
					[ErrorMessage] = H.[message],
					[Version] = @Version,
					[Parameter] = '--' + S.[subsystem] + CHAR(13) + CHAR(10) + S.[command], --'@Status=''Failure''',
					[UserName] = @UserName,
					[UserID] = @UserID,
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID
				FROM
					[msdb].[dbo].[sysjobhistory] H 
					INNER JOIN [msdb].[dbo].[sysjobsteps] S ON S.[job_id] = H.[job_id] AND S.[step_id] = H.[step_id]
				WHERE
					H.[job_id] = @job_id AND
					H.[step_id] = @step_id AND
					msdb.dbo.agent_datetime(H.run_date, H.run_time) = @FailStepTime AND
					H.run_status = 0
			END

	SET @Step = 'Set Job to closed'
		IF  @Status IN ('Success', 'Failure') AND @MasterCommand IN ('spRun_Job_Callisto_Generic', 'spRun_Job_Tabular_Generic', 'spPortalAdmin_LoadCallisto')
			BEGIN
				SET @ActionType=CASE @Status WHEN 'Success' THEN 'End' WHEN 'Failure' THEN 'Error' END
				
				EXEC [spSet_Job]
					@UserID=@UserID,
					@InstanceID=@InstanceID,
					@VersionID=@VersionID,
					@ActionType=@ActionType,
					@MasterCommand=@MasterCommand,
					@CurrentCommand=@ProcedureName,
					@Deleted = @Deleted OUT,
					@Inserted = @Inserted OUT,
					@Updated = @Updated OUT,
					@Selected = @Selected OUT,
					@JobID=@JobID
			END

	SET @Step = 'Set @Duration'
		SET @Duration = CONVERT(time(7), GetDate() - @StartTime)
		
	SET @Step = 'Insert into JobLog'
		IF @JobID <> 0 OR (DATEPART(minute, GetDate()) = 0 AND DATEPART(second, GetDate()) BETWEEN 10 AND 50)
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
