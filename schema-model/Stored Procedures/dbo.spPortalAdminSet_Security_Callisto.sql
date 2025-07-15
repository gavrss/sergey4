SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Security_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JobQueueYN bit = 0,
	@DeployRoleYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000341,
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
EXEC spPortalAdminSet_Security_Callisto @DeployRoleYN=1, @InstanceID=-1444, @UserID=-10, @VersionID=-1382, @DebugBM=7 

EXEC [spPortalAdminSet_Security_Callisto] @UserID=-10, @InstanceID=-1370, @VersionID=-1308, @DeployRoleYN=0, @DebugBM=7 

EXEC [spPortalAdminSet_Security_Callisto] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@OrganizationPositionID int,
	@RowCounter int,
	@RoleID int,
	@ApplicationName nvarchar(100),
	@ApplicationID int,
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@QueueID int,
	@AsynchronousYN bit = 0,
	@XT_Tablename nvarchar(100),
	@CheckoutYN bit = 0,
	@EnhancedStorageYN bit,

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set security in Callisto',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2144' SET @Description = 'Set [XT_UserDefinition] Email column from [UserPropertyValue], else UserName from [User].'
		IF @Version = '2.0.2.2145' SET @Description = 'Set Import Step into Callisto Job to be synchronous.'
		IF @Version = '2.0.2.2147' SET @Description = 'DB Upgrade: User & Security Management.'
		IF @Version = '2.0.2.2148' SET @Description = 'Use sub routine spGet_SecurityRoles_Dynamic. DB-169: Members of Standard roles were not added. Added Financials_Detail. Exclude exporting user members on SecurityRole-All Users.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-308: Save Current View when deploy security'
		IF @Version = '2.0.3.2154' SET @Description = 'Call spSet_Callisto_Security'
		IF @Version = '2.1.1.2168' SET @Description = 'Set Callisto Users to Active = 0 if no password is set.'
		IF @Version = '2.1.1.2171' SET @Description = 'Replace usage of [pcCALLISTO_Import].[XT_*] tables with [pcETL_*].[XT_*] tables. Set Callisto [Checkout].[Status]=0 for [Type]=SecurityRole. Added parameter @JobQueueYN.'
		IF @Version = '2.1.1.2174' SET @Description = 'Set @JobQueueYN = 0 by default. Always run Import part with @AsynchronousYN = 0.'
		IF @Version = '2.1.2.2196' SET @Description = 'Handle Enhanced Storage.'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ApplicationID = [ApplicationID],
			@ApplicationName = [ApplicationName],
			@ETLDatabase = [ETLDatabase],
			@CallistoDatabase = [DestinationDatabase],
			@EnhancedStorageYN = [EnhancedStorageYN]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		IF @DebugBM & 2 > 0
			SELECT
				[@ApplicationID] = @ApplicationID,
				[@ApplicationName] = @ApplicationName,
				[@ETLDatabase] = @ETLDatabase,
				[@CallistoDatabase] = @CallistoDatabase,
				[@EnhancedStorageYN] = @EnhancedStorageYN

	SET @Step = 'Enhanced Storage'
		IF @EnhancedStorageYN <> 0
			BEGIN
				IF @DebugBM & 2 > 0 PRINT 'Callisto is deprecated. No Security Users in Callisto.'
				GOTO EnhancedStorage
			END

	--SET @Step = 'Check queue'	
	--	INSERT INTO [pcCALLISTO_Import].[dbo].[Queue]
	--		(
	--		[UserID],
	--		[InstanceID],
	--		[VersionID],
	--		[ApplicationName]
	--		)
	--	SELECT
	--		[UserID] = @UserID,
	--		[InstanceID] = @InstanceID,
	--		[VersionID] = @VersionID,
	--		[ApplicationName] = @ApplicationName

	--	SET @QueueID = @@IDENTITY

	--	WHILE (SELECT COUNT(1) FROM [pcCALLISTO_Import].[dbo].[Queue] WHERE QueueID < @QueueID AND EndTime IS NULL) > 0
	--		BEGIN
	--			WAITFOR DELAY '00:00:01'
	--		END


--SELECT * FROM [pcCALLISTO_Import].[dbo].[Queue]
--DELETE Q FROM [pcCALLISTO_Import].[dbo].[Queue] Q WHERE QueueID > 2000

		--UPDATE Q
		--SET
		--	StartTime = GetDate()
		--FROM
		--	[pcCALLISTO_Import].[dbo].[Queue] Q
		--WHERE
		--	Q.QueueID = @QueueID
		
	SET @Step = 'Create temp tables'
		CREATE TABLE #User
			(
			[InstanceID] [INT],
			[UserID] [INT],
			[UserName] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[UserNameAD] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[AzureUPN] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[UserNameDisplay] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[UserTypeID] [INT],
			[UserLicenseTypeID] [INT],
			[LocaleID] [INT],
			[LanguageID] [INT],
			[ObjectGuiBehaviorBM] [INT],
			[InheritedFrom] [INT] NULL,
			[SelectYN] [BIT] NOT NULL,
			[Version] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[DeletedID] [INT]
			)

		CREATE TABLE [#DimensionDefinition]
			(
			[Action] [int] NULL,
			[Label] [nvarchar](100) NOT NULL,
			[Description] [nvarchar](255) NULL,
			[Type] [nvarchar](50) NOT NULL,
			[Secured] [bit] NULL,
			[DefaultHierarchy] [nvarchar](100) NULL
			)

		CREATE TABLE [#UserDefinition]
			(
			[Action] [int] NULL,
			[WinUser] [nvarchar](255) NOT NULL,
			[Active] [int] NULL,
			[Email] [nvarchar](255) NULL,
			[UserId] [int] NULL
			)

		CREATE TABLE [#SecurityUser]
			(
			[Role] [nvarchar](100) NOT NULL,
			[WinUser] [nvarchar](255) NULL,
			[WinGroup] [nvarchar](255) NULL
			)

		CREATE TABLE [#SecurityRoleDefinition]
			(
			[Action] [int] NULL,
			[Label] [nvarchar](100) NOT NULL,
			[Description] [nvarchar](255) NULL,
			[LicenseUserType] [nvarchar](255) NULL,
			[AppLogon] [bit] NOT NULL DEFAULT (1)
			)

		CREATE TABLE [#SecurityModelRuleAccess]
			(
			[Role] [nvarchar](100) NOT NULL,
			[Model] [nvarchar](100) NOT NULL,
			[Rule] [nvarchar](255) NOT NULL,
			[AllRules] [int] NOT NULL
			)

		CREATE TABLE [#SecurityMemberAccess]
			(
			[Role] [nvarchar](100) NOT NULL,
			[Model] [nvarchar](100) NOT NULL,
			[Dimension] [nvarchar](100) NOT NULL,
			[Hierarchy] [nvarchar](100) NULL,
			[Member] [nvarchar](255) NULL,
			[AccessType] [int] NULL
			)

		CREATE TABLE [#SecurityActionAccess]
			(
			[Role] [nvarchar](100) NOT NULL,
			[Label] [nvarchar](100) NOT NULL,
			[HideAction] [int] NOT NULL
			)

		CREATE TABLE #XT_Tables
			(
			[XT_TableName] [nvarchar](100) NOT NULL
			)

	SET @Step = 'EXEC [spGet_Callisto_Security]'
		EXEC [spGet_Callisto_Security]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DimensionYN = 1,
			@JobID = @JobID,
			@Debug = @DebugSub

	SET @Step = 'Truncate all pcETL..XT_tables'
		SET @SQLStatement = '
			INSERT INTO #XT_Tables 
				(
				[XT_TableName]
				)
			SELECT
				[XT_TableName] = [name]
			FROM 
				' + @ETLDatabase + '.sys.tables 
			WHERE 
				[name] LIKE ''XT_%'''
		
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		DECLARE XTTable_Cursor CURSOR FOR
			
			SELECT 
				[XT_TableName]
			FROM 
				#XT_Tables

			OPEN XTTable_Cursor
			FETCH NEXT FROM XTTable_Cursor INTO @XT_Tablename

			WHILE @@FETCH_STATUS = 0
				BEGIN
					--IF @DebugBM & 2 > 0 SELECT [@XT_Tablename] = @XT_Tablename

					SET @SQLStatement = 'TRUNCATE TABLE [' + @ETLDatabase + '].[dbo].[' + @XT_Tablename +']'
					EXEC (@SQLStatement)
					SET @Deleted = @Deleted + @@ROWCOUNT

					FETCH NEXT FROM XTTable_Cursor INTO @XT_Tablename
				END

		CLOSE XTTable_Cursor
		DEALLOCATE XTTable_Cursor

	SET @Step = 'Create XT_tables'
		EXEC [spSetup_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBM=1, @JobID=@JobID, @Debug=@DebugSub

	SET @Step = 'Fill XT_tables'

		SET @SQLStatement = 'INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_DimensionDefinition] SELECT * FROM [#DimensionDefinition]'
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

		SET @SQLStatement = 'INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_UserDefinition] SELECT * FROM [#UserDefinition]'
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT
		
		SET @SQLStatement = 'INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_SecurityUser] SELECT * FROM [#SecurityUser]'
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

		SET @SQLStatement = 'INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_SecurityRoleDefinition] SELECT * FROM [#SecurityRoleDefinition]'
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

		SET @SQLStatement = 'INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_SecurityModelRuleAccess] SELECT * FROM [#SecurityModelRuleAccess]'
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

		SET @SQLStatement = 'INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_SecurityMemberAccess] SELECT * FROM [#SecurityMemberAccess]'
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

		SET @SQLStatement = 'INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_SecurityActionAccess] SELECT * FROM [#SecurityActionAccess]'
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Debug, show result'	
		IF @DebugBM & 2 > 0
			BEGIN
				DECLARE XTTable_Cursor CURSOR FOR
			
					SELECT [XT_TableName] FROM #XT_Tables

					OPEN XTTable_Cursor
					FETCH NEXT FROM XTTable_Cursor INTO @XT_Tablename

					WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @SQLStatement = 'SELECT TableName = ''' + @XT_Tablename +''', * FROM [' + @ETLDatabase + '].[dbo].[' + @XT_Tablename +']'
							EXEC (@SQLStatement)

							FETCH NEXT FROM XTTable_Cursor INTO @XT_Tablename
						END

				CLOSE XTTable_Cursor
				DEALLOCATE XTTable_Cursor
			END

	SET @Step = 'Create temporary table for Callisto users'
		CREATE TABLE #Callisto_Users
			(
			[UserId] [int] NOT NULL,
			[WinUser] [nvarchar](255) NOT NULL,
			[Active] [int] NULL,
			[Email] [nvarchar](255) NULL,
			[DisplayName] [nvarchar](255) NULL,
			[CV] [nvarchar](max) NULL,
			[Config] [nvarchar](max) NULL,
			[ExternalAccess] [int] NULL
			)

		SET @SQLStatement = '
			INSERT INTO #Callisto_Users
				(
				[UserId],
				[WinUser],
				[Active],
				[Email],
				[DisplayName],
				[CV],
				[Config],
				[ExternalAccess]
				)
			SELECT
				[UserId],
				[WinUser],
				[Active],
				[Email],
				[DisplayName],
				[CV],
				[Config],
				[ExternalAccess]
			FROM
				' + @CallistoDatabase + '.[dbo].[Users]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Delete existing rows in Callisto database'	
		SET @SQLStatement = '
			TRUNCATE TABLE ' + @CallistoDatabase + '.[dbo].[SecurityFactTable]
			TRUNCATE TABLE ' + @CallistoDatabase + '.[dbo].[SecurityRoleMembers]
			TRUNCATE TABLE ' + @CallistoDatabase + '.[dbo].[SecurityRoles]
			TRUNCATE TABLE ' + @CallistoDatabase + '.[dbo].[Users]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
		SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM ' + @CallistoDatabase + '.sys.tables WHERE [name] = ''Checkout'''
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @CheckoutYN OUT

		IF @CheckoutYN <> 0
			BEGIN
				SET @SQLStatement = '
					UPDATE C
					SET 
						[Status] = 0
					FROM
						' + @CallistoDatabase + '.[dbo].[Checkout] C
					WHERE
						C.[Type] = ''SecurityRole'''

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Run Import into Callisto' 
		IF @DeployRoleYN = 0
			SET @AsynchronousYN = 1

		EXEC [spRun_Job_Callisto_Generic]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@StepName = 'Import', --Load, Deploy, Refresh, Import
			@AsynchronousYN = 0, --@AsynchronousYN,
			@SourceDatabase = @ETLDatabase,
			@JobQueueYN = @JobQueueYN,
			@JobID = @JobID,
			@Debug = @DebugSub

	SET @Step = 'Update Current View in Callisto Users table'
		SET @SQLStatement = '
			UPDATE U
			SET
				[CV] = CU.[CV],
				[Active] = CASE WHEN UPV.UserPropertyValue IS NULL THEN 0 ELSE 1 END
			FROM
				' + @CallistoDatabase + '.[dbo].[Users] U
				INNER JOIN #Callisto_Users CU ON CU.[WinUser] = U.[WinUser]
				LEFT JOIN [pcINTEGRATOR_Data].[dbo].[User] [User] ON [User].UserNameAD = U.[WinUser]
				LEFT JOIN [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV ON UPV.UserID = [User].UserID AND UPV.UserPropertyTypeID = -1001'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Update DisplayName in Callisto Users table'
		SET @SQLStatement = '
			UPDATE U
			SET
				[DisplayName] = PCU.[UserNameDisplay]
			FROM
				' + @CallistoDatabase + '.[dbo].[Users] U
				INNER JOIN #User PCU ON PCU.[UserNameAD] = U.[WinUser]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Deploy all roles in Callisto'	
		IF @DebugBM & 2 > 0 SELECT [@DeployRoleYN] = @DeployRoleYN

		IF @DeployRoleYN <> 0
			EXEC [spRun_Job_Callisto_Generic] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @StepName = 'DeployRole', @AsynchronousYN = 1, @JobQueueYN = @JobQueueYN, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Drop temp tables'
		DROP TABLE [#User]
		DROP TABLE [#DimensionDefinition]
		DROP TABLE [#UserDefinition]
		DROP TABLE [#SecurityUser]
		DROP TABLE [#SecurityRoleDefinition]
		DROP TABLE [#SecurityModelRuleAccess]
		DROP TABLE [#SecurityMemberAccess]
		DROP TABLE [#SecurityActionAccess]
		DROP TABLE [#Callisto_Users]
		DROP TABLE [#XT_Tables]

	EnhancedStorage:

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	--SET @Step = 'Release Queue'
	--	UPDATE Q
	--	SET
	--		EndTime = GetDate(),
	--		Duration = @Duration
	--	FROM
	--		[pcCALLISTO_Import].[dbo].[Queue] Q
	--	WHERE
	--		Q.QueueID = @QueueID

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	--DELETE Q FROM [pcCALLISTO_Import].[dbo].[Queue] Q WHERE QueueID = @QueueID
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
