SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spRun_Job_Tabular_Generic]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DataClassID int = NULL,
	@Action nvarchar(50) = NULL, --'Deploy', 'DeployProcess', 'DeployProcessCreateTemplate', 'Process', 'Delete', 'CreateTemplate'
	@AsynchronousYN bit = 0,
	
	@JobName nvarchar(255) = 'Tabular_Generic',
	@StepName nvarchar(255) = 'ASTabularManagement', --ASTabularManagement
	@Path nvarchar(255) = 'c:\dspanel\pcTabMngt\DSPanel.pcTabMngt.ConsoleApp.exe',
	@MasterCommand nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000486,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC [spRun_Job_Tabular_Generic] @UserID=-10, @InstanceID=-1125, @VersionID=-1125, @DataClassID = 5708, @Action = 'DeployProcessCreateTemplate', @Debug=1
EXEC [spRun_Job_Tabular_Generic] @UserID=-10, @InstanceID=-1313, @VersionID=-1313, @DataClassID = 0, @Action = 'fASDFASDF',@AsynchronousYN = 0, @Debug=1

EXEC [spRun_Job_Tabular_Generic] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
--	@JobName nvarchar(255) = 'Tabular_Generic',
	@ParallelJob# int = 5,
	@JobNo int,
	@JobNo_String nvarchar(3),
	@CommandString nvarchar(4000),
	@Counter int = 0,
	@CounterString nvarchar(50),
	@SysJob_InstanceID int,
	@StepID int,
	@ServerName nvarchar(100),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.2.2195'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Run Tabular jobs',
			@MandatoryParameter = 'DataClassID|Action|StepName' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Added start, failure and success step to job.'
		IF @Version = '2.1.0.2159' SET @Description = 'Use sub routine [spSet_Job] Add parameter @MasterCommand.'
		IF @Version = '2.1.2.2195' SET @Description = 'Added "if exist" - run .exe if it exists only'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		SET @MasterCommand = ISNULL(@MasterCommand, @ProcedureName)

		SET @ServerName = @@SERVERNAME + CASE WHEN DEFAULT_DOMAIN() = 'LIVE' THEN N'.live.dspcloud.local' WHEN DEFAULT_DOMAIN() IN('DEV','DEMO') THEN N'.' + LOWER(DEFAULT_DOMAIN()) + N'.live.dspcloud.local' ELSE N'' END

	SET @Step = 'Start Job'
		IF @JobID IS NULL
			BEGIN
				EXEC [spSet_Job]
					@UserID=@UserID,
					@InstanceID=@InstanceID,
					@VersionID=@VersionID,
					@ActionType='Start',
					@MasterCommand=@MasterCommand,
					@CurrentCommand=@ProcedureName,
					@CheckCount=0,
					@JobID=@JobID OUT

				--INSERT INTO [pcINTEGRATOR_Log].[dbo].[Job]
				--	(
				--	[InstanceID],
				--	[VersionID],
				--	[MasterCommand],
				--	[CheckCount],
				--	[StartTime],
				--	[CurrentCommand],
				--	[CurrentCommand_StartTime]
				--	)
				--SELECT
				--	[InstanceID] = @InstanceID,
				--	[VersionID] = @VersionID,
				--	[MasterCommand] = @ProcedureName,
				--	[CheckCount] = 0,
				--	[StartTime] = GetDate(),
				--	[CurrentCommand] = @ProcedureName,
				--	[CurrentCommand_StartTime] = GetDate()

				--SELECT
				--	@JobID = @@IDENTITY,
				--	@Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Select Job to run, queue handling'
		WHILE @JobName = 'Tabular_Generic'	
			BEGIN
				SET @JobNo = 1
				WHILE @JobNo <= @ParallelJob#
					BEGIN 
						SET @JobNo_String = CASE WHEN @JobNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), @JobNo)

						IF NOT EXISTS
							(     
							SELECT 1 
							FROM
								msdb.dbo.sysjobs_view job  
								INNER JOIN msdb.dbo.sysjobactivity activity on job.job_id = activity.job_id 
							WHERE  
								activity.run_Requested_date IS NOT NULL AND
								activity.stop_execution_date IS NULL AND
								job.[name] = @JobName + @JobNo_String
							)
							BEGIN
								SET @JobName = @JobName + @JobNo_String
								GOTO CONTINUATION						
							END
						ELSE
							SET @JobNo = @JobNo + 1 
					END

				WAITFOR DELAY '00:00:01'
			END

		CONTINUATION:

	SET @Step = 'Set @CommandString for step Start'
		SET @CommandString = '
EXEC spRun_Procedure_KeyValuePair 
@ProcedureName = ''spSet_JobAgent_Status'', 
@JSON = ''
	[
	{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
	{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
	{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
	{"TKey" : "JobName",  "TValue": "' + @JobName + '"},
	{"TKey" : "StepName",  "TValue": "' + @StepName + '"},
	{"TKey" : "Status",  "TValue": "Start"},
	{"TKey" : "MasterCommand",  "TValue": "' + @MasterCommand + '"},
	{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"}
	]'''

		SELECT 
			@StepID = JS.step_id
		FROM
			msdb..sysjobsteps JS
			INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
		WHERE
			JS.[step_name] = @StepName

		EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandString

	SET @Step = 'Set @CommandString for step Success'
		SET @CommandString = '
EXEC spRun_Procedure_KeyValuePair 
@ProcedureName = ''spSet_JobAgent_Status'', 
@JSON = ''
	[
	{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
	{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
	{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
	{"TKey" : "JobName",  "TValue": "' + @JobName + '"},
	{"TKey" : "StepName",  "TValue": "Success"},
	{"TKey" : "Status",  "TValue": "Success"},
	{"TKey" : "MasterCommand",  "TValue": "' + @MasterCommand + '"},
	{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"}
	]'''

		SELECT 
			@StepID = JS.step_id
		FROM
			msdb..sysjobsteps JS
			INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
		WHERE
			JS.[step_name] = 'Success'

		EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandString

	SET @Step = 'Set @CommandString for step Failure'
		SET @CommandString = '
EXEC spRun_Procedure_KeyValuePair 
@ProcedureName = ''spSet_JobAgent_Status'', 
@JSON = ''
	[
	{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
	{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
	{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
	{"TKey" : "JobName",  "TValue": "' + @JobName + '"},
	{"TKey" : "StepName",  "TValue": "Failure"},
	{"TKey" : "Status",  "TValue": "Failure"},
	{"TKey" : "MasterCommand",  "TValue": "' + @MasterCommand + '"},
	{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"}
	]'''

		SELECT 
			@StepID = JS.step_id
		FROM
			msdb..sysjobsteps JS
			INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
		WHERE
			JS.[step_name] = 'Failure'

		EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandString


	SET @Step = 'StepName = ASTabularManagement'
		SELECT 
			@StepID = JS.step_id
		FROM
			msdb..sysjobsteps JS
			INNER JOIN msdb..sysjobs J ON J.job_id = JS.job_id AND J.[name] = @JobName
		WHERE
			JS.[step_name] = @StepName + '_2'

		IF @StepName = 'ASTabularManagement'
			BEGIN
				SET	@CommandString = 'if exist ' + @Path + ' ' + @Path + ' ' + @Action + ' ' + @ServerName + ' ' + CONVERT(nvarchar(15), @InstanceID) + ' ' + CONVERT(nvarchar(15), @VersionID) + ' ' + CONVERT(nvarchar(15), @DataClassID) + ' ' + CONVERT(nvarchar(20), @JobID)
			END

	SET @Step = 'Update Job Step'
		EXEC [msdb].[dbo].[sp_update_jobstep]  @job_name = @JobName, @step_id = @StepID, @command = @CommandString

	SET @Step = 'Enable Job'
		EXEC msdb.[dbo].sp_update_job @job_name = @JobName, @enabled = 1

	SET @Step = 'Get @SysJob_Instance_ID'
		SELECT
			@SysJob_InstanceID = MAX(H.instance_id)
		FROM
			msdb..sysjobhistory H 
			INNER JOIN msdb..sysjobs J ON J.name = @JobName AND J.job_id = H.job_id
		SET @SysJob_InstanceID = ISNULL(@SysJob_InstanceID, 0)

	SET @Step = 'Start the Job'
		EXEC msdb.[dbo].sp_start_job @job_name = @JobName, @step_name = @StepName

	SET @Step = 'Wait loop if not asynchronous'
		IF @AsynchronousYN = 0
			BEGIN
				WHILE (SELECT COUNT(1) FROM msdb..sysjobhistory H INNER JOIN msdb..sysjobs J ON J.name = @JobName AND J.job_id = H.job_id WHERE H.instance_id > @SysJob_InstanceID AND H.step_id = 0) = 0
					BEGIN
						WAITFOR DELAY '00:00:01'
						IF @Counter < 95
							BEGIN
								SET @Counter = @Counter + 2
								SET @CounterString = CONVERT(nvarchar(10), @Counter) + ' percent'
								RAISERROR (@CounterString, 0, @Counter) WITH NOWAIT
							END
					END
			END

	SET @Step = 'Get Return Values'
		SELECT
			JobName = J.name, 
			JobStatus = H.run_status,
			[Description] =	CASE H.run_status WHEN 0 THEN 'Failed' WHEN 1 THEN 'Successful' WHEN 3 THEN 'Cancelled' WHEN 4 THEN 'In Progress' END,
			[Message] = H.[message],
			Duration = H.run_duration
		FROM
			msdb..sysjobhistory H 
			INNER JOIN msdb..sysjobs J ON J.name = @JobName AND J.job_id = H.job_id
		WHERE
			H.instance_id > @SysJob_InstanceID AND
			H.step_id = 0

	SET @Step = 'Disable Job'
		EXEC msdb.[dbo].sp_update_job @job_name = @JobName, @enabled = 0

	SET @Step = 'Set Job to closed'
		UPDATE J
		SET
			[ClosedYN] = 1,
			[EndTime] = GetDate()
		FROM
			[pcINTEGRATOR_Log].[dbo].[Job] J
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[JobID] = @JobID AND
			[MasterCommand] = @ProcedureName

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
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
