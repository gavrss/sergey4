SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_JobAgent]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SequenceBM int = NULL, --1=Queue-handling, 2=Callisto_Generic, 4=Tabular_Generic
	@NoOfJobs int = 50,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000583,
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
EXEC [spSetup_JobAgent] @UserID=-10, @InstanceID=0, @VersionID=0, @SequenceBM = 1, @Debug=1
EXEC [spSetup_JobAgent] @UserID=-10, @InstanceID=0, @VersionID=0, @SequenceBM = 2, @Debug=1
EXEC [spSetup_JobAgent] @UserID=-10, @InstanceID=0, @VersionID=0, @SequenceBM = 4, @NoOfJobs = 2, @Debug=1

EXEC [spSetup_JobAgent] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@Counter int = 0,
	@CategoryName nvarchar(128),
	@JobName nvarchar(128),
	@JobDescription nvarchar(512),
	@AgentJobID BINARY(16),
	@StepID int,
	@StepName nvarchar(128),
	@StartDate int,

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
	@Version nvarchar(50) = '2.1.1.2173'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create all standard jobs for SQL Server Agent',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2159' SET @Description = 'Set schedule for Check_JobQueue.'
		IF @Version = '2.1.1.2173' SET @Description = 'Handle @StepName = GenericSP.'
		IF @Version = '2.1.2.2199' SET @Description = 'Increased @NoOfJobs to 50.'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Queue handling'
		IF @SequenceBM & 1 > 0
			BEGIN
				SELECT
					@CategoryName = 'Check_JobQueue',
					@JobDescription = 'Check JobQueue for jobs to release.'

				IF NOT EXISTS (SELECT [name] FROM msdb.dbo.syscategories WHERE [name] = @CategoryName AND category_class = 1)
					EXEC msdb.dbo.sp_add_category @class=N'JOB', @type = N'LOCAL', @name = @CategoryName

				SET @JobName = 'Check_JobQueue'

				IF @DebugBM & 2 > 0 SELECT [@JobName] = @JobName

				--Delete job, if exists
				IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE [name] = @JobName)
					EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_history=1, @delete_unused_schedule=1

				--Create job
				SET @AgentJobID = NULL

				EXEC msdb.dbo.sp_add_job
						@job_name = @JobName, 
						@enabled=1, 
						@notify_level_eventlog=0, 
						@notify_level_email=0, 
						@notify_level_netsend=0, 
						@notify_level_page=0, 
						@delete_level=0, 
						@description = @JobDescription, 
						@category_name = @CategoryName, 
						@owner_login_name=N'sa',
						@job_id = @AgentJobID OUTPUT

				--@StepID = 1, @StepName = spCheck_JobQueue
				SELECT @StepID = 1, @StepName = N'spCheck_JobQueue'
				EXEC msdb.dbo.sp_add_jobstep
						@job_id = @AgentJobID,
						@step_name = @StepName, 
						@step_id = @StepID, 
						@cmdexec_success_code=0, 
						@on_success_action=3, 
						@on_success_step_id=0, 
						@on_fail_action=3, 
						@on_fail_step_id=0, 
						@retry_attempts=0, 
						@retry_interval=0, 
						@os_run_priority=0,
						@subsystem=N'TSQL', 
						@command = 'EXEC [spSet_JobAgent_Status]
	@UserID = -10,
	@InstanceID = 0,
	@VersionID = 0,
	@JobName = ''Check_JobQueue'',
	@StepName = ''spCheck_JobQueue'',
	@Status = ''Start'',
	@JobID = 0', 
						@database_name = N'pcINTEGRATOR', 
						@flags=0

				--@StepID = 2, @StepName = spCheck_JobQueue_2
				SELECT @StepID = 2, @StepName = N'spCheck_JobQueue_2'
				EXEC msdb.dbo.sp_add_jobstep
						@job_id = @AgentJobID,
						@step_name = @StepName, 
						@step_id = @StepID, 
						@cmdexec_success_code=0, 
						@on_success_action=4, 
						@on_success_step_id=3, 
						@on_fail_action=4, 
						@on_fail_step_id=4, 
						@retry_attempts=0, 
						@retry_interval=0, 
						@os_run_priority=0,
						@subsystem=N'TSQL', 
						@command=N'EXEC [spCheck_JobQueue]', 
						@database_name=N'pcINTEGRATOR', 
						@flags=0

				--@StepID = 3, @StepName = Success
				SELECT @StepID = 3, @StepName = N'Success'
				EXEC msdb.dbo.sp_add_jobstep
						@job_id = @AgentJobID,
						@step_name = @StepName, 
						@step_id = @StepID, 
						@cmdexec_success_code=0, 
						@on_success_action=1, 
						@on_success_step_id=0, 
						@on_fail_action=2, 
						@on_fail_step_id=0, 
						@retry_attempts=0, 
						@retry_interval=0, 
						@os_run_priority=0,
						@subsystem=N'TSQL', 
						@command = 'EXEC [spSet_JobAgent_Status]
	@UserID = -10,
	@InstanceID = 0,
	@VersionID = 0,
	@JobName = ''Check_JobQueue'',
	@StepName = ''Success'',
	@Status = ''Success'',
	@JobID = 0', 
						@database_name=N'pcINTEGRATOR', 
						@flags=0

				--@StepID = 4, @StepName = Failure
				SELECT @StepID = 4, @StepName = N'Failure'
				EXEC msdb.dbo.sp_add_jobstep
						@job_id = @AgentJobID,
						@step_name = @StepName, 
						@step_id = @StepID, 
						@cmdexec_success_code=0, 
						@on_success_action=1, 
						@on_success_step_id=0, 
						@on_fail_action=2, 
						@on_fail_step_id=0, 
						@retry_attempts=0, 
						@retry_interval=0, 
						@os_run_priority=0,
						@subsystem=N'TSQL', 
						@command = 'EXEC [spSet_JobAgent_Status]
	@UserID = -10,
	@InstanceID = 0,
	@VersionID = 0,
	@JobName = ''Check_JobQueue'',
	@StepName = ''Failure'',
	@Status = ''Failure'',
	@JobID = 0', 
						@database_name=N'pcINTEGRATOR', 
						@flags=0

				--Update job, set start step
				EXEC msdb.dbo.sp_update_job @job_id = @AgentJobID, @start_step_id = 1

				--Set Job Schedule
				SET @StartDate = Year(GetDate()) * 10000 + Month(GetDate()) * 100 + Day(GetDate())

				EXEC msdb.dbo.sp_add_jobschedule
					@job_id=@AgentJobID,
					@name=N'Check_JobQueue', 
					@enabled=1, 
					@freq_type=4, 
					@freq_interval=1, 
					@freq_subday_type=2, 
					@freq_subday_interval=30, 
					@freq_relative_interval=0, 
					@freq_recurrence_factor=0, 
					@active_start_date=@StartDate, 
					@active_end_date=99991231, 
					@active_start_time=0, 
					@active_end_time=235959

				--Add jobserver
				EXEC msdb.dbo.sp_add_jobserver @job_id = @AgentJobID, @server_name = N'(local)'
			END

	SET @Step = 'Callisto_Generic'
		IF @SequenceBM & 2 > 0
			BEGIN
				SELECT
					@CategoryName = 'Callisto_Generic',
					@JobDescription = 'Generic job for different Callisto Applications.'

				IF NOT EXISTS (SELECT [name] FROM msdb.dbo.syscategories WHERE [name] = @CategoryName AND category_class = 1)
					EXEC msdb.dbo.sp_add_category @class=N'JOB', @type = N'LOCAL', @name = @CategoryName

				SET @Counter = 1
				WHILE @Counter <= @NoOfJobs
					BEGIN
						SET @JobName = 'Callisto_Generic' + CASE WHEN @Counter <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), @Counter)

						IF @DebugBM & 2 > 0 SELECT [@JobName] = @JobName

						--Delete job, if exists
						IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE [name] = @JobName)
							EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_history=1, @delete_unused_schedule=1

						--Create job
						SET @AgentJobID = NULL

						EXEC msdb.dbo.sp_add_job
								@job_name = @JobName, 
								@enabled=0, 
								@notify_level_eventlog=0, 
								@notify_level_email=0, 
								@notify_level_netsend=0, 
								@notify_level_page=0, 
								@delete_level=0, 
								@description = @JobDescription, 
								@category_name = @CategoryName, 
								@owner_login_name=N'sa',
								@job_id = @AgentJobID OUTPUT

						--@StepID = 1, @StepName = Import
						SELECT @StepID = 1, @StepName = N'Import'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=3, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name = N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 2, @StepName = Import_2
						SELECT @StepID = 2, @StepName = N'Import_2'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=22, 
								@on_fail_action=4, 
								@on_fail_step_id=23, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'PowerShell', 
								@command = @StepName, 
								@database_name = N'master', 
								@flags=0

						--@StepID = 3, @StepName = Load
						SELECT @StepID = 3, @StepName = N'Load'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=3, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 4, @StepName = Load_2
						SELECT @StepID = 4, @StepName = N'Load_2'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID, 
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=22, 
								@on_fail_action=4, 
								@on_fail_step_id=23, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'master', 
								@flags=0

						--@StepID = 5, @StepName = Deploy
						SELECT @StepID = 5, @StepName = N'Deploy'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=3, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 6, @StepName = Deploy_2
						SELECT @StepID = 6, @StepName = N'Deploy_2'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=22, 
								@on_fail_action=4, 
								@on_fail_step_id=23, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'PowerShell', 
								@command = @StepName, 
								@database_name=N'master', 
								@flags=0

						--@StepID = 7, @StepName = Refresh
						SELECT @StepID = 7, @StepName = N'Refresh'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=3, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 8, @StepName = Refresh_2
						SELECT @StepID = 8, @StepName = N'Refresh_2'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=22, 
								@on_fail_action=4, 
								@on_fail_step_id=23, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0, @subsystem=N'PowerShell', 
								@command = @StepName, 
								@database_name=N'master', 
								@flags=0

						--@StepID = 9, @StepName = RunModelRule
						SELECT @StepID = 9, @StepName = N'RunModelRule'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=3, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 10, @StepName = RunModelRule_2
						SELECT @StepID = 10, @StepName = N'RunModelRule_2'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=22, 
								@on_fail_action=4, 
								@on_fail_step_id=23, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'PowerShell', 
								@command = @StepName, 
								@database_name=N'master', 
								@flags=0

						--@StepID = 11, @StepName = DeployRole
						SELECT @StepID = 11, @StepName = N'DeployRole'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=3, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 12, @StepName = DeployRole_2
						SELECT @StepID = 12, @StepName = N'DeployRole_2'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=22, 
								@on_fail_action=4, 
								@on_fail_step_id=23, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0, @subsystem=N'PowerShell', 
								@command = @StepName, 
								@database_name=N'master', 
								@flags=0

						--@StepID = 13, @StepName = Create
						SELECT @StepID = 13, @StepName = N'Create'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=3, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 14, @StepName = Create_2
						SELECT @StepID = 14, @StepName = N'Create_2'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=22, 
								@on_fail_action=4, 
								@on_fail_step_id=23, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'PowerShell', 
								@command = @StepName, 
								@database_name=N'master', 
								@flags=0

						--@StepID = 15, @StepName = ETLFull
						SELECT @StepID = 15, @StepName = N'ETLFull'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=3, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 16, @StepName = ETLFull_2
						SELECT @StepID = 16, @StepName = N'ETLFull_2'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=3, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 17, @StepName = ETLFull_3_Deploy
						SELECT @StepID = 17, @StepName = N'ETLFull_3_Deploy'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=22, 
								@on_fail_action=4, 
								@on_fail_step_id=23, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'PowerShell', 
								@command = @StepName, 
								@database_name=N'master', 
								@flags=0

						--@StepID = 18, @StepName = ETLData
						SELECT @StepID = 18, @StepName = N'ETLData'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=3, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 19, @StepName = ETLData_2
						SELECT @StepID = 19, @StepName = N'ETLData_2'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=3, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 20, @StepName = ETLData_3_Refresh
						SELECT @StepID = 20, @StepName = N'ETLData_3_Refresh'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=22, 
								@on_fail_action=4, 
								@on_fail_step_id=23, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'PowerShell', 
								@command = @StepName, 
								@database_name=N'master', 
								@flags=0

						--@StepID = 21, @StepName = GenericSP
						SELECT @StepID = 21, @StepName = N'GenericSP'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=22, 
								@on_fail_action=4, 
								@on_fail_step_id=23, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 22, @StepName = Success
						SELECT @StepID = 22, @StepName = N'Success'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=1, 
								@on_success_step_id=0, 
								@on_fail_action=2, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 23, @StepName = Failure
						SELECT @StepID = 23, @StepName = N'Failure'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=1, 
								@on_success_step_id=0, 
								@on_fail_action=2, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--Update job, set start step
						EXEC msdb.dbo.sp_update_job @job_id = @AgentJobID, @start_step_id = 1

						--Add jobserver
						EXEC msdb.dbo.sp_add_jobserver @job_id = @AgentJobID, @server_name = N'(local)'

						SET @Counter = @Counter + 1
					END
			END

	SET @Step = 'Tabular_Generic'
		IF @SequenceBM & 4 > 0
			BEGIN
				SELECT
					@CategoryName = 'Tabular_Generic',
					@JobDescription = 'Generic job for Tabular management.'

				IF NOT EXISTS (SELECT [name] FROM msdb.dbo.syscategories WHERE [name] = @CategoryName AND category_class = 1)
					EXEC msdb.dbo.sp_add_category @class=N'JOB', @type = N'LOCAL', @name = @CategoryName

				SET @Counter = 1
				WHILE @Counter <= @NoOfJobs
					BEGIN
						SET @JobName = 'Tabular_Generic' + CASE WHEN @Counter <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), @Counter)

						IF @DebugBM & 2 > 0 SELECT [@JobName] = @JobName

						--Delete job, if exists
						IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE [name] = @JobName)
							EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_history=1, @delete_unused_schedule=1

						--Create job
						SET @AgentJobID = NULL

						EXEC msdb.dbo.sp_add_job
								@job_name = @JobName, 
								@enabled=0, 
								@notify_level_eventlog=0, 
								@notify_level_email=0, 
								@notify_level_netsend=0, 
								@notify_level_page=0, 
								@delete_level=0, 
								@description = @JobDescription, 
								@category_name = @CategoryName, 
								@owner_login_name=N'sa',
								@job_id = @AgentJobID OUTPUT

						--@StepID = 1, @StepName = ASTabularManagement
						SELECT @StepID = 1, @StepName = N'ASTabularManagement'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=3, 
								@on_success_step_id=0, 
								@on_fail_action=3, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name = N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 2, @StepName = ASTabularManagement_2
						SELECT @StepID = 2, @StepName = N'ASTabularManagement_2'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=4, 
								@on_success_step_id=3, 
								@on_fail_action=4, 
								@on_fail_step_id=4, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'CmdExec', 
								@command = @StepName, 
								@flags=0

						--@StepID = 3, @StepName = Success
						SELECT @StepID = 3, @StepName = N'Success'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=1, 
								@on_success_step_id=0, 
								@on_fail_action=2, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--@StepID = 4, @StepName = Failure
						SELECT @StepID = 4, @StepName = N'Failure'
						EXEC msdb.dbo.sp_add_jobstep
								@job_id = @AgentJobID,
								@step_name = @StepName, 
								@step_id = @StepID, 
								@cmdexec_success_code=0, 
								@on_success_action=1, 
								@on_success_step_id=0, 
								@on_fail_action=2, 
								@on_fail_step_id=0, 
								@retry_attempts=0, 
								@retry_interval=0, 
								@os_run_priority=0,
								@subsystem=N'TSQL', 
								@command = @StepName, 
								@database_name=N'pcINTEGRATOR', 
								@flags=0

						--Update job, set start step
						EXEC msdb.dbo.sp_update_job @job_id = @AgentJobID, @start_step_id = 1

						--Add jobserver
						EXEC msdb.dbo.sp_add_jobserver @job_id = @AgentJobID, @server_name = N'(local)'

						SET @Counter = @Counter + 1
					END
			END

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
