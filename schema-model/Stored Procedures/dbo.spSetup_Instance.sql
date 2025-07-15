SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Instance]
	@UserID int = NULL,
	@InstanceID int = NULL OUT,
	@VersionID int = NULL OUT,

	--SP-specific parameters
	@StorageTypeBM int = NULL,
	@DemoYN bit = NULL,
	@CustomerID int = NULL OUT,
	@CustomerName nvarchar(50) = NULL,
	@InstanceName nvarchar(50) = NULL,
	@InstanceShortName nvarchar(5) = NULL,
	@ApplicationName nvarchar(100) = NULL,
	@ProductKey nvarchar(17) = NULL, 
	@StartYear int = NULL,
	@AddYear int = NULL,
	@FiscalYearStartMonthSetYN bit = 0,
	@FiscalYearStartMonth int = NULL,
	@FiscalYearNamingSetYN bit = 0,
	@FiscalYearNaming int = NULL,
	@BrandID int = NULL,
	@MasterCommand nvarchar(100) = NULL,
	@EnhancedStorageYN bit = 1,

	@JobID int = NULL OUT,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000445,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spSetup_Instance',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

--Add new Version, Instance & Customer are existing
EXEC [spSetup_Instance] 
	@UserID = -10,
	@InstanceID = 413,
	@VersionID = NULL,
	@CustomerID = 333,
	@ApplicationName = 'CBN_2',
	@DemoYN = 0,
	@StorageTypeBM = 4,
	@FiscalYearStartMonth = 4,
	@Debug = 1

EXEC [spSetup_Instance] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceInstanceID int = -10,
	@SourceVersionID int = -10,
	@ApplicationID int,

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2191'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup new Customer, Instance, Version and Application.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2151' SET @Description = 'Added [CompanyTypeID] column on INSERT INTO [Customer] table.'
		IF @Version = '2.0.3.2153' SET @Description = 'Removed references to detailed columns in master Instance table and references to master tables Version and Application.'
		IF @Version = '2.0.3.2154' SET @Description = 'Update table DSPMASTER.pcINTEGRATOR_Master.dbo.[Instance_Server]. Additional parameters.'
		IF @Version = '2.1.0.2155' SET @Description = 'Modified creation of [Version] query if Customer and Instance are existing but new @ApplicationName.'
		IF @Version = '2.1.0.2159' SET @Description = 'Use sub routine [spSet_Job].'
		IF @Version = '2.1.0.2165' SET @Description = 'Enhanced debugging.'
		IF @Version = '2.1.1.2173' SET @Description = 'Added parameter @MasterCommand. Removed @Step = Set EndTime for the actual job.'
		IF @Version = '2.1.2.2191' SET @Description = 'Handle @EnhancedStorageYN'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
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
			@Selected = ISNULL(@Selected, 0),
			@UserID = ISNULL(@UserID, -10)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF @DebugBM & 2 > 0
			SELECT
				[@ProcedureName] = @ProcedureName,
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@StorageTypeBM] = @StorageTypeBM,
				[@DemoYN] = @DemoYN,
				[@CustomerID] = @CustomerID,
				[@CustomerName] = @CustomerName,
				[@InstanceName] = @InstanceName,
				[@InstanceShortName] = @InstanceShortName,
				[@ApplicationName] = @ApplicationName,
				[@EnhancedStorageYN] = @EnhancedStorageYN,
				[@ProductKey] = @ProductKey,
				[@StartYear] = @StartYear,
				[@AddYear] = @AddYear,
				[@FiscalYearStartMonthSetYN] = @FiscalYearStartMonthSetYN,
				[@FiscalYearStartMonth] = @FiscalYearStartMonth,
				[@FiscalYearNamingSetYN] = @FiscalYearNamingSetYN,
				[@FiscalYearNaming] = @FiscalYearNaming,
				[@BrandID] = @BrandID,
				[@JobID] = @JobID

	SET @Step = 'Check if Customer name is already used.'
		IF @DemoYN <> 0 AND @CustomerID IS NULL
			IF (SELECT COUNT(1) FROM [Customer] WHERE [CustomerName] = @CustomerName) > 0
				BEGIN
					SET @Message = 'The Customer name ' + @CustomerName + ' is already in use. Choose another Customer name.'
					SET @Severity = 16
					GOTO EXITPOINT
				END

	SET @Step = 'Check if Instance name is already used.'
		IF @DemoYN <> 0 AND @InstanceID IS NULL
			IF (SELECT COUNT(1) FROM [Instance] WHERE [InstanceName] = @InstanceName) > 0
				BEGIN
					SET @Message = 'The Instance name ' + @InstanceName + ' is already in use. Choose another Instance name.'
					SET @Severity = 16
					GOTO EXITPOINT
				END

	SET @Step = 'Check if Application name is already used.'
		IF @DemoYN <> 0 AND @VersionID IS NULL
			IF (SELECT COUNT(1) FROM [Application] WHERE [ApplicationName] = @ApplicationName AND [InstanceID] <> @InstanceID) > 0
				BEGIN
					SET @Message = 'The Application name ' + @ApplicationName + ' is already in use. Choose another Application name.'
					SET @Severity = 16
					GOTO EXITPOINT
				END

	SET @Step = 'Create Customer'
		IF @DemoYN = 0 AND @CustomerID IS NULL
			BEGIN
				SELECT
					@CustomerID = CustomerID
				FROM 
					[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer]
				WHERE
					[CustomerName] = @CustomerName

				IF @CustomerID IS NULL
					BEGIN
						INSERT INTO [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer]
							(
							[CustomerName],
							[CustomerDescription],
							[CompanyTypeID],
							[ProductKey]
							)
						SELECT
							[CustomerName] = @CustomerName,
							[CustomerDescription] = @CustomerName,
							[CompanyTypeID] = 2,
							[ProductKey] = @ProductKey

						SET @Inserted = @Inserted + @@ROWCOUNT
						SELECT @CustomerID = MAX([CustomerID]) FROM [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer]
					END
			END

		IF @DemoYN = 0 AND @CustomerID IS NOT NULL
			BEGIN
--				SELECT @CustomerID = [CustomerID] FROM [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] WHERE [InstanceID] = @InstanceID

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Customer] ON
				
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Customer]
					(
					[CustomerID],
					[CustomerName],
					[CustomerDescription],
					[CompanyTypeID],
					[ProductKey]
					)
				SELECT
					[CustomerID] = MC.[CustomerID],
					[CustomerName] = MC.[CustomerName],
					[CustomerDescription] = MC.[CustomerDescription],
					[CompanyTypeID] = MC.[CompanyTypeID],
					[ProductKey] = MC.[ProductKey]
				FROM
					[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] MC
				WHERE
					MC.[CustomerID] = @CustomerID AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Customer] C WHERE C.[CustomerID] = MC.[CustomerID])

				SET @Inserted = @Inserted + @@ROWCOUNT

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Customer] OFF
			END

		IF @DemoYN <> 0 
			BEGIN
				IF @CustomerID IS NOT NULL
					BEGIN
						UPDATE C
						SET
							[CustomerName] = @CustomerName,
							[CompanyTypeID] = 3
						FROM
							[pcINTEGRATOR_Data].[dbo].[Customer] C
						WHERE
							C.[CustomerID] = @CustomerID

						SET @Updated = @Updated + @@ROWCOUNT
					END
				ELSE
					BEGIN
						SELECT @CustomerID = MIN(CustomerID) - 1 FROM Customer WHERE CustomerID < -1000
						SET @CustomerID = ISNULL(@CustomerID, -1001)

						SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Customer] ON
		
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[Customer]
							(
							[CustomerID],
							[CustomerName],
							[CustomerDescription],
							[CompanyTypeID],
							[ProductKey]
							)
						SELECT
							[CustomerID] = @CustomerID,
							[CustomerName] = @CustomerName,
							[CustomerDescription] = @CustomerName,
							[CompanyTypeID] = 3,
							[ProductKey] = @ProductKey

						SET @Inserted = @Inserted + @@ROWCOUNT

						SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Customer] OFF
					END
			END

	SET @Step = 'Create Instance'
		IF @DemoYN = 0 AND @InstanceID IS NULL
			BEGIN
				SELECT
					@InstanceID = InstanceID
				FROM 
					[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance]
				WHERE
					[InstanceName] = @InstanceName AND
					[CustomerID] = @CustomerID

				IF @InstanceID IS NULL
					BEGIN
						INSERT INTO [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance]
							(
							[InstanceName],
							[InstanceDescription],
							[InstanceShortName],
							[CustomerID],
							[BrandID]
							)
						SELECT
							[InstanceName] = @InstanceName,
							[InstanceDescription] = @InstanceName,
							[InstanceShortName] = @InstanceShortName,
							[CustomerID] = @CustomerID,
							[BrandID] = @BrandID

						SET @Inserted = @Inserted + @@ROWCOUNT
						SELECT @InstanceID = MAX([InstanceID]) FROM [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance]
					END
			END

		IF @DemoYN = 0 AND @InstanceID IS NOT NULL
			BEGIN
				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Instance] ON

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Instance]
					(
					[InstanceID],
					[InstanceName],
					[InstanceDescription],
					[InstanceShortName],
					[CustomerID],
					[StartYear],
					[AddYear],
					[FiscalYearStartMonthSetYN],
					[FiscalYearStartMonth],
					[FiscalYearNamingSetYN],
					[FiscalYearNaming],
					[ProductKey],
					[BrandID]
					)
				SELECT
					[InstanceID] = MI.[InstanceID],
					[InstanceName] = MI.[InstanceName],
					[InstanceDescription] = MI.[InstanceDescription],
					[InstanceShortName] = MI.[InstanceShortName],
					[CustomerID] = MI.[CustomerID],
					[StartYear] = @StartYear,
					[AddYear] = @AddYear,
					[FiscalYearStartMonthSetYN] = @FiscalYearStartMonthSetYN,
					[FiscalYearStartMonth] = @FiscalYearStartMonth,
					[FiscalYearNamingSetYN] = @FiscalYearNamingSetYN,
					[FiscalYearNaming] = @FiscalYearNaming,
					[ProductKey] = @ProductKey,
					[BrandID] = @BrandID
				FROM
					[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] MI
				WHERE
					MI.CustomerID = @CustomerID AND
					MI.InstanceID = @InstanceID AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Instance] I WHERE I.InstanceID = MI.InstanceID)

				SET @Inserted = @Inserted + @@ROWCOUNT

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Instance] OFF
			END

		IF @DemoYN <> 0
			BEGIN
				IF @InstanceID IS NOT NULL
					BEGIN
						UPDATE I
						SET
							[InstanceName] = @InstanceName,
							[InstanceDescription] = @InstanceName,
							[InstanceShortName] = @InstanceShortName,
							[CustomerID] = @CustomerID,
							[StartYear] = @StartYear,
							[AddYear] = @AddYear,
							[FiscalYearStartMonthSetYN] = @FiscalYearStartMonthSetYN,
							[FiscalYearStartMonth] = @FiscalYearStartMonth,
							[FiscalYearNamingSetYN] = @FiscalYearNamingSetYN,
							[FiscalYearNaming] = @FiscalYearNaming,
							[ProductKey] = @ProductKey,
							[BrandID] = @BrandID
						FROM
							[pcINTEGRATOR_Data].[dbo].[Instance] I
						WHERE
							I.[InstanceID] = @InstanceID

						SET @Updated = @Updated + @@ROWCOUNT
					END
				ELSE
					BEGIN
						SELECT @InstanceID = MIN(InstanceID) - 1 FROM Instance WHERE InstanceID < -1000
						SET @InstanceID = ISNULL(@InstanceID, -1001)

						SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Instance] ON
		
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[Instance]
							(
							[InstanceID],
							[InstanceName],
							[InstanceDescription],
							[InstanceShortName],
							[CustomerID],
							[StartYear],
							[AddYear],
							[FiscalYearStartMonthSetYN],
							[FiscalYearStartMonth],
							[FiscalYearNamingSetYN],
							[FiscalYearNaming],
							[ProductKey],
							[pcPortal_URL],
							[Mail_ProfileName],
							[Rows],
							[Nyc],
							[Nyu],
							[BrandID],
							[InheritedFrom]
							)
						SELECT
							[InstanceID] = @InstanceID,
							[InstanceName] = @InstanceName,
							[InstanceDescription] = @InstanceName,
							[InstanceShortName] = @InstanceShortName,
							[CustomerID] = @CustomerID,
							[StartYear] = @StartYear,
							[AddYear] = @AddYear,
							[FiscalYearStartMonthSetYN] = @FiscalYearStartMonthSetYN,
							[FiscalYearStartMonth] = @FiscalYearStartMonth,
							[FiscalYearNamingSetYN] = @FiscalYearNamingSetYN,
							[FiscalYearNaming] = @FiscalYearNaming,
							[ProductKey] = @ProductKey,
							[pcPortal_URL] = TI.[pcPortal_URL],
							[Mail_ProfileName] = TI.[Mail_ProfileName],
							[Rows] = TI.[Rows],
							[Nyc] = TI.[Nyc],
							[Nyu] = TI.[Nyu],
							[BrandID] = @BrandID,
							[InheritedFrom] = TI.[InstanceID]
						FROM
							pcINTEGRATOR.dbo.[@Template_Instance] TI
						WHERE
							TI.InstanceID = @SourceInstanceID AND
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Instance] I WHERE I.InstanceID = @InstanceID)

						SET @Inserted = @Inserted + @@ROWCOUNT

						SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Instance] OFF
					END
			END

	SET @Step = 'Create Version'
		SELECT
			@VersionID = ISNULL(@VersionID, V.[VersionID])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Version] V ON V.InstanceID = A.InstanceID AND V.VersionID = A.VersionID
			INNER JOIN pcINTEGRATOR.dbo.[@Template_Version] TV ON TV.InstanceID = @SourceInstanceID AND TV.VersionID = @SourceVersionID AND TV.[VersionID] = V.[InheritedFrom] AND TV.[VersionName] = V.[VersionName]
		WHERE
			A.InstanceID = @InstanceID AND 
			(A.ApplicationName = @ApplicationName OR @ApplicationName IS NULL)

		IF @DebugBM & 2 > 0 SELECT [@VersionID] = @VersionID
		
		IF @VersionID IS NULL
			BEGIN
				IF @DemoYN = 0 
					BEGIN
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[Version]
							(
							[InstanceID],
							[VersionName],
							[VersionDescription],
							[EnvironmentLevelID],
							[ErasableYN],
							[InheritedFrom]
							)
						SELECT
							[InstanceID] = @InstanceID,
							[VersionName] = TV.[VersionName],
							[VersionDescription] = TV.[VersionDescription],
							[EnvironmentLevelID] = TV.[EnvironmentLevelID],
							[ErasableYN] = 0,
							[InheritedFrom] = TV.[VersionID]
						FROM
							pcINTEGRATOR.dbo.[@Template_Version] TV
						WHERE
							TV.InstanceID = @SourceInstanceID AND
							TV.VersionID = @SourceVersionID AND
							(NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Version] V WHERE V.InstanceID = @InstanceID AND V.[InheritedFrom] = TV.[VersionID] AND V.[VersionName] =  TV.[VersionName]) OR
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Application] A WHERE A.InstanceID = @InstanceID AND (A.[ApplicationName] = @ApplicationName OR @ApplicationName IS NULL)))

						SET @Inserted = @Inserted + @@ROWCOUNT

						SELECT 
							@VersionID = MAX(V.[VersionID])
						FROM 
							[pcINTEGRATOR_Data].[dbo].[Version] V 
							INNER JOIN pcINTEGRATOR.dbo.[@Template_Version] TV ON TV.InstanceID = @SourceInstanceID AND TV.VersionID = @SourceVersionID AND TV.[VersionID] = V.[InheritedFrom] AND TV.[VersionName] = V.[VersionName]
						WHERE
							V.InstanceID = @InstanceID	
					END
				ELSE
					BEGIN
						SELECT @VersionID = MIN(VersionID) - 1 FROM [Version] WHERE VersionID < -1000
						SET @VersionID = ISNULL(@VersionID, -1001)

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
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[VersionName] = TV.[VersionName],
							[VersionDescription] = TV.[VersionDescription],
							[EnvironmentLevelID] = TV.[EnvironmentLevelID],
							[ErasableYN] = 1,
							[InheritedFrom] = TV.[VersionID]
						FROM
							pcINTEGRATOR.dbo.[@Template_Version] TV
						WHERE
							TV.InstanceID = @SourceInstanceID AND
							TV.VersionID = @SourceVersionID  AND
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Version] V WHERE V.InstanceID = @InstanceID AND V.[VersionName] =  TV.[VersionName])

						SET @Inserted = @Inserted + @@ROWCOUNT
		
						SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Version] OFF
					END
			END

	SET @Step = 'Start Job'
		SET @MasterCommand = ISNULL(@MasterCommand, @ProcedureName)

		IF @JobID IS NULL AND @InstanceID IS NOT NULL AND @VersionID IS NOT NULL
			EXEC [spSet_Job]
				@UserID=@UserID,
				@InstanceID=@InstanceID,
				@VersionID=@VersionID,
				@ActionType='Start',
				@MasterCommand=@MasterCommand,
				@CurrentCommand=@ProcedureName,
				@JobQueueYN=0,
				@CheckCount = 0,
				@JobID=@JobID OUT
			
	SET @Step = 'Create Application'
		SELECT
			@ApplicationID = ApplicationID
		FROM
			[Application] A
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[ApplicationName] = @ApplicationName

		IF @DebugBM & 2 > 0
			SELECT
				[@ProcedureName] = @ProcedureName,
				[@UserID] = @UserID,
				[@CustomerID] = @CustomerID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@ApplicationID] = @ApplicationID

		IF @ApplicationID IS NULL
			BEGIN
				IF @DemoYN = 0
					BEGIN
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[Application]
							(
							[InstanceID],
							[VersionID],
							[ApplicationName],
							[ApplicationDescription],
							[ApplicationServer],
							[StorageTypeBM],
							[ETLDatabase],
							[DestinationDatabase],
							[AdminUser],
							[FiscalYearStartMonth],
							[EnhancedStorageYN],
							[LanguageID],
							[InheritedFrom]
							)
						SELECT
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[ApplicationName] = @ApplicationName,
							[ApplicationDescription] = @ApplicationName,
							[ApplicationServer] = TA.[ApplicationServer],
							[StorageTypeBM] = @StorageTypeBM,
							[ETLDatabase] = 'pcETL_' + @ApplicationName,
							[DestinationDatabase] = 'pcDATA_' + @ApplicationName,
							[AdminUser] = '', --'LIVE\' + @ApplicationName + '.' + @UserNameDisplay,
							[FiscalYearStartMonth] = @FiscalYearStartMonth,
							[EnhancedStorageYN] = @EnhancedStorageYN,
							[LanguageID] = TA.[LanguageID],
							[InheritedFrom] = TA.ApplicationID
						FROM
							[pcINTEGRATOR].[dbo].[@Template_Application] TA 
						WHERE
							TA.InstanceID = @SourceInstanceID AND 
							TA.VersionID = @SourceVersionID AND
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Application] A WHERE A.InstanceID = @InstanceID AND A.[VersionID] = @VersionID)

						SET @Inserted = @Inserted + @@ROWCOUNT

						SELECT
							@ApplicationID = MAX(A.[ApplicationID])
						FROM 
							[pcINTEGRATOR_Data].[dbo].[Application] A
							INNER JOIN pcINTEGRATOR.dbo.[@Template_Application] TA ON TA.[InstanceID] = @SourceInstanceID AND TA.[VersionID] = @SourceVersionID AND TA.[ApplicationID] = A.[InheritedFrom] AND TA.[ApplicationName] = A.[ApplicationName]
						WHERE
							A.[InstanceID] = @InstanceID AND
							A.[VersionID] = @VersionID
					END
				ELSE IF @DemoYN <> 0
					BEGIN
						SELECT @ApplicationID = MIN(ApplicationID) - 1 FROM [Application] WHERE ApplicationID < -1000
						SET @ApplicationID = ISNULL(@ApplicationID, -1001)

						SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Application] ON
		
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[Application]
							(
							[InstanceID],
							[VersionID],
							[ApplicationID],
							[ApplicationName],
							[ApplicationDescription],
							[ApplicationServer],
							[ETLDatabase],
							[DestinationDatabase],
							[AdminUser],
							[FiscalYearStartMonth],
							[EnhancedStorageYN],
							[LanguageID],
							[InheritedFrom]
							)
						SELECT
							[InstanceID] = @InstanceID,
							[VersionID] = @VersionID,
							[ApplicationID] = @ApplicationID,
							[ApplicationName] = @ApplicationName,
							[ApplicationDescription] = @ApplicationName,
							[ApplicationServer] = TA.[ApplicationServer],
							[ETLDatabase] = 'pcETL_' + @ApplicationName,
							[DestinationDatabase] = 'pcDATA_' + @ApplicationName,
							[AdminUser] = '', --'LIVE\' + @ApplicationName + '.' + @UserNameDisplay,
							[FiscalYearStartMonth] = ISNULL(@FiscalYearStartMonth, TA.[FiscalYearStartMonth]),
							[EnhancedStorageYN] = @EnhancedStorageYN,
							[LanguageID] = TA.[LanguageID],
							[InheritedFrom] = TA.ApplicationID
						FROM
							pcINTEGRATOR.dbo.[@Template_Application] TA
						WHERE
							TA.InstanceID = @SourceInstanceID AND
							TA.VersionID = @SourceVersionID AND
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Application] A WHERE A.InstanceID = @InstanceID AND A.[VersionID] = @VersionID)

						SET @Inserted = @Inserted + @@ROWCOUNT

						SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Application] OFF
					END
			END

	SET @Step = 'Update table DSPMASTER.pcINTEGRATOR_Master.dbo.[Instance_Server]'
		EXEC [spSet_Instance_Server_Master] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID

	SET @Step = 'Return information'
		IF @DebugBM & 1 > 0 
			BEGIN
				SELECT
					[@ProcedureName] = @ProcedureName,
					[@CustomerID] = @CustomerID,
					[@InstanceID] = @InstanceID,
					[@VersionID] = @VersionID,
					[@ApplicationID] = @ApplicationID

				SELECT [Table] = 'pcINTEGRATOR_Data..Customer', * FROM [pcINTEGRATOR_Data].[dbo].[Customer] WHERE [CustomerID] = @CustomerID
				SELECT [Table] = 'pcINTEGRATOR_Data..Instance', * FROM [pcINTEGRATOR_Data].[dbo].[Instance] WHERE [InstanceID] = @InstanceID
				SELECT [Table] = 'pcINTEGRATOR_Data..Version', * FROM [pcINTEGRATOR_Data].[dbo].[Version] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
				SELECT [Table] = 'pcINTEGRATOR_Data..Application', * FROM [pcINTEGRATOR_Data].[dbo].[Application] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

	--SET @Step = 'Set EndTime for the actual job'
	--	EXEC [spSet_Job]
	--		@UserID=@UserID,
	--		@InstanceID=@InstanceID,
	--		@VersionID=@VersionID,
	--		@ActionType='End',
	--		@MasterCommand=@ProcedureName,
	--		@CurrentCommand=@ProcedureName,
	--		@JobID=@JobID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	EXEC [spSet_Job] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ActionType='Error', @MasterCommand=@ProcedureName, @CurrentCommand=@ProcedureName, @JobID=@JobID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
