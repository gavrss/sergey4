SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spStart_Job]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ApplicationID int = NULL,
	@JobName nvarchar(255) = NULL,
	@StepName nvarchar(255) = 'Load', --'Create', 'Import', 'Load' or 'Deploy'
	@AsynchronousYN bit = 0,
	@SandBox nvarchar(100) = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000204,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose


--#WITH ENCRYPTION#--
AS

--NOTA BENE PROBABLY OBSOLETE AND CANDIDATE TO REMOVE

SET ANSI_WARNINGS OFF

--EXEC [dbo].[spStart_Job] 	@ApplicationID = 6, @StepName = 'Create'
--EXEC [dbo].[spStart_Job] 	@ApplicationID = 6, @StepName = 'Load'
--EXEC [dbo].[spStart_Job] 	@ApplicationID = 400, @JobName = 'pcDATA_DevTest76_Load', @StepName = 'Process', @AsynchronousYN = 1

--EXEC [dbo].[spStart_Job] @GetVersion = 1

DECLARE
	@DestinationDatabase nvarchar(255),
	@SysJob_Instance_ID int,
	@Counter int = 0,
	@CounterString nvarchar(50),

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
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Template for creating SPs',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.3.2113' SET @Description = 'Handle SandBox.'
		IF @Version = '1.4.0.2128' SET @Description = 'Handle case sensitive.'
		IF @Version = '1.4.0.2134' SET @Description = '@JobName added as parameter.'
		IF @Version = '2.1.2.2179' SET @Description = 'DB-877: Modified to new SP template.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

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
			@InstanceID = A.InstanceID,
			@DestinationDatabase = ISNULL(@SandBox, A.DestinationDatabase)
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'SP-Specific check'
		IF @ApplicationID IS NULL
			BEGIN
				SET @Message = 'Parameter @ApplicationID must be set.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Set JobName'
		IF @JobName IS NULL
			BEGIN
				IF @StepName IN ('Create', 'Import')
					SET @JobName = @DestinationDatabase + '_Create'
				ELSE --IF @StepName IN ('Load', 'Deploy')
					SET @JobName = @DestinationDatabase + '_Load'
			END

	SET @Step = 'Enable Job'
		EXEC msdb.[dbo].sp_update_job
			@job_name = @JobName,
			@enabled = 1

	SET @Step = 'Get @SysJob_Instance_ID'
		SELECT
			@SysJob_Instance_ID = MAX(H.instance_id)
		FROM
			msdb..sysjobhistory H 
			INNER JOIN msdb..sysjobs J ON J.name = @JobName AND J.job_id = H.job_id
		SET @SysJob_Instance_ID = ISNULL(@SysJob_Instance_ID, 0)

	SET @Step = 'Start the Job'
		EXEC msdb.[dbo].sp_start_job 
			 @job_name = @JobName,
			 @step_name = @StepName

	SET @Step = 'Wait loop if not asynchronous'
		IF @AsynchronousYN = 0
			BEGIN
				WHILE (SELECT COUNT(1) FROM msdb..sysjobhistory H INNER JOIN msdb..sysjobs J ON J.name = @JobName AND J.job_id = H.job_id WHERE H.instance_id > @SysJob_Instance_ID AND H.step_id = 0) = 0
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
			H.instance_id > @SysJob_Instance_ID AND
			H.step_id = 0

	SET @Step = 'Disable Job'
		IF RIGHT(@JobName, 6) = 'Create'
			EXEC msdb.[dbo].sp_update_job
				@job_name = @JobName,
				@enabled = 0

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)





GO
