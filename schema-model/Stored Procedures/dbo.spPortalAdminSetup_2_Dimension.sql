SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSetup_2_Dimension]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@AssignedInstanceID int = NULL, --Mandatory
	@AssignedVersionID int = NULL, --Mandatory
	@SourceTypeID int = NULL, --Optional
	@ModelingStatusID int = -40,
	@ModelingComment nvarchar(100) = 'Default setup',
	@MasterCommand nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000589,
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
EXEC [spPortalAdminSetup_2_Dimension] @UserID=-10, @InstanceID = 0, @VersionID = 0, @AssignedInstanceID=-1335, @AssignedVersionID=-1273, @DebugBM=7

EXEC [spPortalAdminSetup_2_Dimension] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@StorageTypeBM int,
	@Total decimal(5,2) = 25,
	@Counter decimal(5,2) = 5,
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
	@Version nvarchar(50) = '2.1.1.2175'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup DataClass and corresponding dimensions in a sequence.',
			@MandatoryParameter = 'AssignedInstanceID|AssignedVersionID' --Without @, separated by |

		IF @Version = '2.0.3.2152' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Code refactoring, use of [spSetup_*] calls.'
		IF @Version = '2.1.0.2159' SET @Description = 'Use sub routine [spSet_Job].'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle iScala.'
		IF @Version = '2.1.1.2173' SET @Description = 'Acquire @JobID from [spSet_Job] subroutine. Added @Step = Set EndTime for the actual job.'
		IF @Version = '2.1.1.2175' SET @Description = 'Changed variable @SourceTypeID to parameter.'

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
			INNER JOIN [Instance] I ON I.InstanceID = A.InstanceID
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

		IF @DebugBM & 2 > 0
			SELECT
				[@ProcedureName] = @ProcedureName,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@StorageTypeBM] = @StorageTypeBM,
				[@SourceTypeID] = @SourceTypeID,
				[@ModelingStatusID] = @ModelingStatusID,
				[@ModelingComment] = @ModelingComment

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

	SET @Step = 'Setup FiscalYear.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_FiscalYear]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@SourceTypeID = @SourceTypeID,
			@Deleted = @Deleted OUT, 
			@Inserted = @Inserted OUT, 
			@Updated = @Updated OUT,
			@Selected = @Selected OUT, 
			@JobID = @JobID,
			@Debug = @DebugSub

	SET @Step = 'Create DataClass.'	
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_DataClass]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@SourceTypeID = -10,
			@StorageTypeBM = @StorageTypeBM,
			@ModelingStatusID = @ModelingStatusID,
			@ModelingComment = @ModelingComment,
			@Deleted = @Deleted OUT, 
			@Inserted = @Inserted OUT, 
			@Updated = @Updated OUT,
			@Selected = @Selected OUT, 
			@JobID = @JobID,
			@Debug = @DebugSub

	SET @Step = 'Create generic Dimensions.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_Dimension]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@SourceTypeID = -10,
			@StorageTypeBM = @StorageTypeBM, 
			@ModelingStatusID = @ModelingStatusID,
			@ModelingComment = @ModelingComment,
			@Deleted = @Deleted OUT, 
			@Inserted = @Inserted OUT, 
			@Updated = @Updated OUT,
			@Selected = @Selected OUT, 
			@JobID = @JobID,
			@Debug = @DebugSub

	SET @Step = 'Create Segment Dimensions.'
		SET @Counter = @Counter + 1
		SET @StatusMessage = @Step + ' ' + CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' steps of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed.'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@StatusMessage, 0, @PercentDone) WITH NOWAIT

		EXEC [spSetup_Dimension]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@SourceTypeID = -11,
			@StorageTypeBM = @StorageTypeBM, 
			@ModelingStatusID = @ModelingStatusID,
			@ModelingComment = @ModelingComment,
			@Deleted = @Deleted OUT, 
			@Inserted = @Inserted OUT, 
			@Updated = @Updated OUT,
			@Selected = @Selected OUT, 
			@JobID = @JobID,
			@Debug = @DebugSub

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
