SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Copy_Instance]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@FromInstanceID int = NULL,
	@FromVersionID int = NULL,
	@ToInstanceID int = NULL,
	@InstanceName nvarchar(100) = NULL,
	@ApplicationName nvarchar(100) = NULL,
	@ToDomainName varchar (100) =  '',
	@FromDomainName varchar (100) =  '',
	@CompanyAdminUserID int = NULL,
	
	@SourceDatabase nvarchar(100) = '[pcINTEGRATOR_Data]',
	@CopyType nvarchar(10) = 'Instance',
	@TruncateYN bit = 1,
	@InsertYN bit = 1,
	@DemoYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000571,
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
EXEC [dbo].[sp_Tool_Copy_Instance] 
	@UserID = -10,
	@InstanceID = -1039,
	@VersionID = -1039,
	@ToInstanceID = 458,
	@InstanceName = 'Kiplinger',
	@ApplicationName = 'KIP',
	@ToDomainName = 'live',
	@FromDomainName = 'demo',
	@DemoYN = 0,
	@Debug = 1

		CLOSE Delete_Cursor
		DEALLOCATE Delete_Cursor
		
		CLOSE Insert_Cursor
		DEALLOCATE Insert_Cursor


EXEC [sp_Tool_Copy_Instance] @GetVersion = 1
*/
DECLARE
	@ToVersionID int,
	@ToApplicationID int,

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Allow copying of Instances between different environments.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created. DB-387: Allow copying Instances between different environments (follow [spPortalAdminCopy_Instance] routine).'

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

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SET @ApplicationName = ISNULL(@ApplicationName, @InstanceName)

		SET @Step = 'Check if demo'
		IF @DemoYN = 0
			BEGIN
				SET @Message = 'This SP can only be used for demo purposes'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Check if Instance name is already used.'
		IF (SELECT COUNT(1) FROM [pcINTEGRATOR_Data]..[Instance] WHERE InstanceName = @InstanceName) > 0
			BEGIN
				SET @Message = 'The Instance name ' + @InstanceName + ' is already in use. Choose another Instance name.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Check if Application name is already used.'
		IF (SELECT COUNT(1) FROM [Application] WHERE ApplicationName = @ApplicationName) > 0
			BEGIN
				SET @Message = 'The Application name ' + @ApplicationName + ' is already in use. Choose another Application name.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Setup Instance'
		EXEC [spSetup_Instance] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DemoYN = @DemoYN, @AssignedInstanceID = @ToInstanceID, @ApplicationName = @ApplicationName, @Debug = @DebugSub
		

	SET @Step = 'Copy metadata in pcINTEGRATOR_Data'
		EXEC [spCopy_Instance_Version] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @FromInstanceID = @FromInstanceID, @FromVersionID = @FromVersionID, @ToInstanceID = @ToInstanceID, @ToVersionID = @ToVersionID, @FromDomainName = @FromDomainName,  @ToDomainName = @ToDomainName, @DemoYN = @DemoYN, @Debug = @DebugSub

	--SET @Step = 'Add CompanyAdminUserID'
	--	IF @CompanyAdminUserID IS NOT NULL
	--		BEGIN
	--			INSERT INTO pcINTEGRATOR_Data..User_Instance
	--				(
	--				[InstanceID],
	--				[UserID],
	--				[ExpiryDate],
	--				[InsertedBy]
	--				)
	--			SELECT
	--				[InstanceID] = @ToInstanceID,
	--				[UserID] = @CompanyAdminUserID,
	--				[ExpiryDate] = NULL,
	--				[InsertedBy] = @UserID
	--			WHERE
	--				NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..User_Instance D WHERE D.[InstanceID] = @ToInstanceID AND D.[UserID] = @CompanyAdminUserID)

	--			INSERT INTO pcINTEGRATOR_Data..SecurityRoleUser
	--				(
	--				[InstanceID],
	--				[SecurityRoleID],
	--				[UserID]
	--				)
	--			SELECT
	--				[InstanceID] = @ToInstanceID,
	--				[SecurityRoleID] = -1,
	--				[UserID] = @CompanyAdminUserID
	--			WHERE
	--				NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..SecurityRoleUser D WHERE D.[InstanceID] = @ToInstanceID AND [SecurityRoleID] = -1 AND D.[UserID] = @CompanyAdminUserID)
	--		END

	SET @Step = 'Copy ETL_Database'
		EXEC [spCopy_ETL_Database] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @FromInstanceID = @FromInstanceID, @FromVersionID = @FromVersionID, @ToInstanceID = @ToInstanceID, @ToVersionID = @ToVersionID, @FromDomainName = @FromDomainName,  @ToDomainName = @ToDomainName, @Debug = @Debug

	SET @Step = 'Copy Callisto_Database'
		EXEC [spCopy_Callisto_Database] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @FromInstanceID = @FromInstanceID, @FromVersionID = @FromVersionID, @ToInstanceID = @ToInstanceID, @ToVersionID = @ToVersionID, @FromDomainName = @FromDomainName,  @ToDomainName = @ToDomainName, @Debug = @Debug

	SET @Step = 'Create Tabular Database'
		EXEC [spRun_Job_Tabular_Generic] @UserID = @UserID, @InstanceID = @ToInstanceID, @VersionID = @ToVersionID, @DataClassID = 0, @Action = 'DeployProcessCreateTemplate', @AsynchronousYN = 1

	SET @Step = 'Return information'
		SELECT
			UserID = @UserID,
			ToInstanceID = @ToInstanceID,
			ToVersionID = @ToVersionID,
			ToApplicationID = @ToApplicationID

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
