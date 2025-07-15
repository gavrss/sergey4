SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminCopy_Instance]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@FromInstanceID int = NULL,
	@FromVersionID int = NULL,
	@ToInstanceID int = NULL,
	@InstanceName nvarchar(100) = NULL,
	@InstanceShortName nvarchar(5) = NULL,
	@ApplicationName nvarchar(100) = NULL,
	
	@ToDomainName varchar (100) =  '',
	@FromDomainName varchar (100) =  '',

	@CompanyAdminUserID int = NULL,
	
	@DemoYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000364,
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
/*
EXEC [pcINTEGRATOR].[dbo].[spPortalAdminCopy_Instance] @ApplicationName='GMNT',@CompanyAdminUserID='',
@FromDomainName='live',@FromInstanceID='574',@FromVersionID='1081',@InstanceID='0',
@InstanceName='GM Nameplate (Test)',@InstanceShortName='gmnt',@ToDomainName='live',@UserID='-10',@VersionID='0',@DebugBM=3

EXEC spPortalAdminCopy_Instance 
	@ApplicationName='JaWo1',
	@InstanceName='JaWo1-MAS05',
	@FromDomainName='demo',
	@ToDomainName='demo',
	@UserID='9784',
	@FromInstanceID='-1287',
	@FromVersionID='-1287',
	@Debug=1

EXEC [dbo].[spPortalAdminCopy_Instance] 
	@UserID = -10,
	@FromInstanceID = 709,
	@FromVersionID = 1157,
	@ToInstanceID = NULL,
	@InstanceName = 'EOHI2 (EOHI/SIT Test Instance)',
	@ApplicationName = 'EOHI2',
	@ToDomainName = 'live',
	@FromDomainName = 'live',
	@DemoYN = 1,
	@Debug = 1

		CLOSE Delete_Cursor
		DEALLOCATE Delete_Cursor
		
		CLOSE Insert_Cursor
		DEALLOCATE Insert_Cursor

EXEC spPortalAdminCopy_Instance 
@ApplicationName='DBT01',
@CompanyAdminUserID='9630',@FromDomainName='dev',
@FromInstanceID='-1318',@FromVersionID='-1256',
@InstanceID='0',@InstanceName='DBTest01',
@ToDomainName='dev',@UserID='-10',@VersionID='0',
@ProcedureID=880000364,@StartTime='2019-12-12 05:31:06.370'

	--GetVersion
		EXEC [spPortalAdminCopy_Instance] @GetVersion = 1
*/
DECLARE
	@ToVersionID int,
	@ToApplicationID int,
	@DataClassID int,
	@JSON nvarchar(max),

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
	@Version nvarchar(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create new demo Instances',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-143: Added parameters @FromInstanceID and @From VersionID. Added a call to [spRun_Job_Tabular_Generic]. Added Copy ETL Database. DB-161: Added parameter @CompanyAdminUserID. Added TabularServer in table Application'
		IF @Version = '2.0.3.2151' SET @Description = 'Added DebugBM enhancement.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-476: Added @InstanceShortName parameter to insert into [Instance] table.'
		IF @Version = '2.1.0.2166' SET @Description = 'Set CustomerID = 436 (DEMO) if copied from CustomerID = 435 (DEMO TEMPLATE).'
		IF @Version = '2.1.2.2192' SET @Description = 'Handled Enhanced Storage.' 
		IF @Version = '2.1.2.2196' SET @Description = 'Set [ErasableYN] = 1 when inserting into [Version] table for @DemoYN = 1.' 

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
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

	SET @Step = 'Create Instance'
		IF @DemoYN <> 0 AND ISNULL(@ToInstanceID, -100) = -100
			BEGIN
				SELECT @ToInstanceID = MIN(InstanceID) - 1 FROM Instance WHERE InstanceID < -1000
				SET @ToInstanceID = ISNULL(@ToInstanceID, -1001)

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Instance] ON
		
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Instance]
					(
					[InstanceID],
					[InstanceName],
					[InstanceDescription],
					[InstanceShortName],
					[CustomerID],
					[FiscalYearStartMonth],
					[FiscalYearNaming],
					[ProductKey],
					[pcPortal_URL],
					[Mail_ProfileName],
					[Rows],
					[Nyc],
					[Nyu],
					[InheritedFrom]
					)
				SELECT
					[InstanceID] = @ToInstanceID,
					[InstanceName] = @InstanceName,
					[InstanceDescription] = @InstanceName,
					[InstanceShortName] = @InstanceShortName,
					[CustomerID] = CASE WHEN CustomerID = 435 THEN 436 ELSE CustomerID END,
					[FiscalYearStartMonth],
					[FiscalYearNaming],
					[ProductKey],
					[pcPortal_URL],
					[Mail_ProfileName],
					[Rows],
					[Nyc],
					[Nyu],
					[InheritedFrom] = @FromInstanceID
				FROM
					[pcINTEGRATOR].[dbo].[Instance]
				WHERE
					InstanceID = @FromInstanceID

				SET @Inserted = @Inserted + @@ROWCOUNT

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Instance] OFF
			END

	SET @Step = 'Create Version'
		IF @DemoYN <> 0 AND ISNULL(@ToVersionID, -100) = -100
			BEGIN
				SELECT @ToVersionID = MIN(VersionID) - 1 FROM [Version] WHERE VersionID < -1000
				SET @ToVersionID = ISNULL(@ToVersionID, -1001)

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Version] ON
		
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Version]
					(
					[InstanceID],
					[VersionID],
					[VersionName],
					[VersionDescription],
					[EnvironmentLevelID],
					[ErasableYN],
					[InheritedFrom]
					)
				SELECT
					[InstanceID] = @ToInstanceID,
					[VersionID] = @ToVersionID,
					[VersionName],
					[VersionDescription],
					[EnvironmentLevelID],
					[ErasableYN] = 1,
					[InheritedFrom] = @FromVersionID
				FROM 
					[Version]
				WHERE
					InstanceID = @FromInstanceID AND
					VersionID = @FromVersionID

				SET @Inserted = @Inserted + @@ROWCOUNT
		
				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Version] OFF
			END

	SET @Step = 'Create Application'
		IF (SELECT COUNT(1) FROM [Application] WHERE InstanceID = @ToInstanceID AND VersionID = @ToVersionID) > 0
			SELECT @ToApplicationID = MAX(ApplicationID) FROM [Application] WHERE InstanceID = @ToInstanceID AND VersionID = @ToVersionID
		ELSE
			BEGIN
				SELECT @ToApplicationID = MIN(ApplicationID) - 1 FROM [Application] WHERE ApplicationID < -1000
				SET @ToApplicationID = ISNULL(@ToApplicationID, -1001)

				IF @Debug <> 0
					SELECT
						[ToInstanceID] = @ToInstanceID,
						[ToVersionID] = @ToVersionID,
						[ToApplicationID] = @ToApplicationID

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Application] ON
		
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Application]
					(
					[ApplicationID],
					[ApplicationName],
					[ApplicationDescription],
					[ApplicationServer],
					[InstanceID],
					[VersionID],
					[ETLDatabase],
					[DestinationDatabase],
					[TabularServer],
					[AdminUser],
					[FiscalYearStartMonth],
					[LanguageID],
					[InheritedFrom],
					[EnhancedStorageYN]
					)
				SELECT
					[ApplicationID] = @ToApplicationID,
					[ApplicationName] = @ApplicationName,
					[ApplicationDescription] = @ApplicationName,
					[ApplicationServer],
					[InstanceID] = @ToInstanceID,
					[VersionID] = @ToVersionID,
					[ETLDatabase] = 'pcETL_' + @ApplicationName,
					[DestinationDatabase] = 'pcDATA_' + @ApplicationName,
					[TabularServer],
					[AdminUser],
					[FiscalYearStartMonth],
					[LanguageID],
					[InheritedFrom] = ApplicationID,
					[EnhancedStorageYN]
				FROM
					[Application]
				WHERE
					InstanceID = @FromInstanceID AND
					VersionID = @FromVersionID

				SET @Inserted = @Inserted + @@ROWCOUNT

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Application] OFF
			END

	SET @Step = 'Copy metadata in pcINTEGRATOR_Data'
		--EXEC [spCopy_Instance_Version] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @FromInstanceID = @FromInstanceID, @FromVersionID = @FromVersionID, @ToInstanceID = @ToInstanceID, @ToVersionID = @ToVersionID, @FromDomainName = @FromDomainName,  @ToDomainName = @ToDomainName, @DemoYN = @DemoYN, @Debug = @DebugSub

	SET @Step = 'Add CompanyAdminUserID'
		IF @CompanyAdminUserID IS NOT NULL
			BEGIN
				INSERT INTO pcINTEGRATOR_Data..User_Instance
					(
					[InstanceID],
					[UserID],
					[ExpiryDate],
					[InsertedBy]
					)
				SELECT
					[InstanceID] = @ToInstanceID,
					[UserID] = @CompanyAdminUserID,
					[ExpiryDate] = NULL,
					[InsertedBy] = @UserID
				WHERE
					NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..User_Instance D WHERE D.[InstanceID] = @ToInstanceID AND D.[UserID] = @CompanyAdminUserID)

				INSERT INTO pcINTEGRATOR_Data..SecurityRoleUser
					(
					[InstanceID],
					[SecurityRoleID],
					[UserID]
					)
				SELECT
					[InstanceID] = @ToInstanceID,
					[SecurityRoleID] = -1,
					[UserID] = @CompanyAdminUserID
				WHERE
					NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..SecurityRoleUser D WHERE D.[InstanceID] = @ToInstanceID AND [SecurityRoleID] = -1 AND D.[UserID] = @CompanyAdminUserID)
			END

	SET @Step = 'Copy ETL_Database'
		--EXEC [spCopy_ETL_Database] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @FromInstanceID = @FromInstanceID, @FromVersionID = @FromVersionID, @ToInstanceID = @ToInstanceID, @ToVersionID = @ToVersionID, @FromDomainName = @FromDomainName,  @ToDomainName = @ToDomainName, @Debug = @Debug

	SET @Step = 'Copy Callisto_Database'
		--EXEC [spCopy_Callisto_Database] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @FromInstanceID = @FromInstanceID, @FromVersionID = @FromVersionID, @ToInstanceID = @ToInstanceID, @ToVersionID = @ToVersionID, @FromDomainName = @FromDomainName,  @ToDomainName = @ToDomainName, @Debug = @Debug

	SET @Step = 'Create Tabular Database'
		--EXEC [spRun_Job_Tabular_Generic] @UserID = @UserID, @InstanceID = @ToInstanceID, @VersionID = @ToVersionID, @DataClassID = 0, @Action = 'DeployProcessCreateTemplate', @AsynchronousYN = 1

	SET @Step = 'Return information'
		SELECT
			UserID = @UserID,
			ToInstanceID = @ToInstanceID,
			ToVersionID = @ToVersionID,
			ToApplicationID = @ToApplicationID

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
