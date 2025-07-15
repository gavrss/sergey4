SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSetup_3_EFP]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@AssignedInstanceID int = NULL,
	@AssignedVersionID int = NULL,	
	@SourceTypeID int = NULL,
	@ModelingStatusID int = -40,
	@ModelingComment nvarchar(100) = 'Default Setup',
	@MasterCommand nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000590,
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
EXEC [spPortalAdminSetup_3_EFP] @UserID=-10, @InstanceID = 0, @VersionID = 0, @AssignedInstanceID=573, @AssignedVersionID=1080, @DebugBM=7

EXEC [spPortalAdminSetup_3_EFP] @GetVersion = 1

TO BE MODIFIED:
1. Load dimensions + Journal data
2. Add Users&Roles into Callisto (Import)
3. Run Callisto Deploy
4. Load FACT Data 
5. Refresh FACT tables

*/

SET ANSI_WARNINGS OFF

DECLARE
	@StorageTypeBM int,
	@DemoYN bit,
	@JobListID int,
	@Total decimal(5,2) = 25,
	@Counter decimal(5,2) = 9,
	@StatusMessage nvarchar(100),
	@PercentDone int,

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2198'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup a new ETL process and corresponding objects in a sequence.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2159' SET @Description = 'Use sub routine [spSet_Job].'
		IF @Version = '2.1.0.2162' SET @Description = 'Added @CallistoDeployYN=1 in [spSetup_Callisto] subroutine.'
		IF @Version = '2.1.1.2173' SET @Description = 'Added @Step = Deploy Users & Roles and @Step = Create Demo Data.'
		IF @Version = '2.1.1.2175' SET @Description = 'Changed variable @SourceTypeID to parameter.'
		IF @Version = '2.1.2.2198' SET @Description = 'DB-1584: Added sub-call to [spSetup_Index] after Night Reload job routine.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
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

		SELECT
			@InstanceID = @AssignedInstanceID,
			@VersionID = @AssignedVersionID

		SELECT 
			@StorageTypeBM = A.StorageTypeBM
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
            A.VersionID = @VersionID

		SELECT
			@SourceTypeID = ISNULL(@SourceTypeID, [SourceTypeID])
		FROM
			pcINTEGRATOR_Data..[Source] S
			INNER JOIN pcINTEGRATOR_Data..[Model] M ON M.ModelID = S.ModelID AND M.BaseModelID = -7
		WHERE
			S.InstanceID = @AssignedInstanceID AND
			S.VersionID = @AssignedVersionID

		SET @DemoYN = CASE WHEN @InstanceID < 0 THEN 1 ELSE 0 END

		IF @DebugBM & 2 > 0
			SELECT
				[@ProcedureName] = @ProcedureName,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@StorageTypeBM] = @StorageTypeBM,
				[@ModelingStatusID] = @ModelingStatusID,
				[@ModelingComment] = @ModelingComment,
				[@DemoYN] = @DemoYN

	SET @Step = 'Set Job status.'
		SET @MasterCommand = ISNULL(@MasterCommand, @ProcedureName)

		EXEC [spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='Start',
			@MasterCommand=@MasterCommand,
			@CurrentCommand=@ProcedureName,
			@JobQueueYN=0,
			@JobID=@JobID OUT

	SET @Step = 'Create pcETL database.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_pcETL] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub

	SET @Step = 'Create Organization and Workflow.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_Workflow] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SourceTypeID=@SourceTypeID, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub

	SET @Step = 'Create Callisto database (XT_tables, Models+Dims, BusinessRules).'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBM=23, @CallistoDeployYN=0, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub

	SET @Step = 'Setup CheckSum.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_CheckSum] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub

	SET @Step = 'Create SQL Job.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @StorageTypeBM=@StorageTypeBM, @SourceTypeID=@SourceTypeID, @SequenceBM=3, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub

	SET @Step = 'Run job to load dimensions and full deploy to create fact tables.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		SELECT
			@JobListID = [JobListID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[JobList] JL
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[InheritedFrom] = -111 AND --Dim Load
			[SelectYN] <> 0

		--EXEC [spRun_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobListID=@JobListID, @JobID=@JobID, @Debug=@DebugSub
		EXEC [spRun_Job_Callisto_Generic] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @StepName='ETLFull', @JobListID=@JobListID, @AsynchronousYN=0, @JobID=@JobID, @Debug=@DebugSub
/*
	SET @Step = 'Deploy Users & Roles.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		--Deploy Users & Roles
		EXEC spPortalAdminSet_Security_Callisto @DeployRoleYN=1, @InstanceID=@InstanceID, @UserID=@UserID, @VersionID=@VersionID, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub
		
		--EXEC [spSetup_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBM=24, @CallistoDeployYN=1, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub
		--EXEC [spRun_Job_Callisto_Generic] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @StepName = 'DeployRole', @AsynchronousYN = 0, @MasterCommand = @ProcedureName, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub
	*/	
	SET @Step = 'Run Job to load data including business rules and full deploy.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		SELECT
			@JobListID = [JobListID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[JobList] JL
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[InheritedFrom] = -103 AND --Night Reload
			[SelectYN] <> 0

		--EXEC [spRun_Job_Callisto_Generic] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @StepName='ETLFull', @JobListID=@JobListID, @AsynchronousYN=0, @JobID=@JobID, @Debug=@DebugSub

		EXEC [spRun_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobListID=@JobListID, @JobID=@JobID, @Debug=@DebugSub

		--Recreate Index
		EXEC [spSetup_Index] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @Debug=@DebugSub
	
	SET @Step = 'Deploy Users & Roles.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		--Deploy Users & Roles
		EXEC [spSetup_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBM=24, @CallistoDeployYN=0, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub

		EXEC spPortalAdminSet_Security_Callisto @DeployRoleYN=1, @InstanceID=@InstanceID, @UserID=@UserID, @VersionID=@VersionID, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub
	

		--Callisto Full Deploy
		--EXEC [spRun_Job_Callisto_Generic] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @StepName = 'Deploy', @AsynchronousYN = 1, @MasterCommand = @ProcedureName, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub
	

/*
	SET @Step = 'Run Job to load data including business rules and refresh data.'
		SET @Counter = @Counter + 4
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		SELECT
			@JobListID = [JobListID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[JobList] JL
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[InheritedFrom] = -104 AND --Full Refresh
			[SelectYN] <> 0

		EXEC [spRun_Job_Callisto_Generic] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @StepName='ETLData', @JobListID=@JobListID, @AsynchronousYN=0, @ModelName='Financials', @JobID=@JobID, @Debug=@DebugSub
*/
	SET @Step = 'Create Demo Data (@DemoYN <> 0 AND SourceDB = DSPSOURCE01.ERP10).'
		SET @Counter = @Counter + 2
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_DemoData] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DemoYN=@DemoYN, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub

		--Callisto Refresh
		EXEC [spRun_Job_Callisto_Generic] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @ModelName='Financials', @StepName = 'Refresh', @AsynchronousYN = 1, @MasterCommand = @ProcedureName, @Deleted=@Deleted OUT, @Inserted=@Inserted OUT, @Updated=@Updated OUT, @Selected=@Selected OUT, @JobID=@JobID, @Debug=@DebugSub
	
/*	
	SET @Step = 'Execute check sums.'
		SET @Counter = @Counter + 2
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		SELECT
			@JobListID = [JobListID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[JobList] JL
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[InheritedFrom] = -121 AND --Execute all check sums
			[SelectYN] <> 0

		EXEC [spRun_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobListID=@JobListID, @JobID=@JobID, @Debug=@DebugSub
*/
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

	SET @Step = 'Set EndTime for the actual job'
		EXEC [spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='End',
			@MasterCommand=@MasterCommand,
			@CurrentCommand=@ProcedureName,
			@JobID=@JobID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Error', @MasterCommand=@MasterCommand, @CurrentCommand=@ProcedureName, @JobID=@JobID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
