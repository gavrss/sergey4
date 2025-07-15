SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_PartnerUser]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000524,
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
EXEC [spGet_PartnerUser] @UserID=-10, @InstanceID=0, @VersionID=0, @DebugBM=2
EXEC [spGet_PartnerUser] @UserID=-10, @InstanceID=1, @VersionID=0, @DebugBM=2

EXEC [spGet_PartnerUser] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@PartnerUserLastUpdate datetime,
	@CountRows int,

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
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Add and update partner users',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2151' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2153' SET @Description = 'New instances will be set to SelectYN = 1. Removed references to FiscalYearStartMonth and FiscalYearNaming.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-450: Updated handling of DeletedID. Update Customer and Instance. DB-455: Do not add User if Source User [InheritedFrom] already exists.'
		IF @Version = '2.1.0.2165' SET @Description = 'Make it possible to just get users for a specified @InstanceID.'
		IF @Version = '2.1.2.2196' SET @Description = 'Modified INSERT query to [#User].'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
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

		SELECT
			@UserID = ISNULL(@UserID, -10),
			@InstanceID = ISNULL(@InstanceID, 0),
			@VersionID = ISNULL(@VersionID, 0)
		
		SELECT
			@PartnerUserLastUpdate = [PartnerUserLastUpdate]
		FROM
			pcINTEGRATOR_Data.dbo.SystemValue
		WHERE
			SystemID = 0

		IF @DebugBM & 2 > 0
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@PartnerUserLastUpdate] = @PartnerUserLastUpdate

	SET @Step = 'Open linked connection'
		EXEC [spGet_Connection] @LinkedServer = 'DSPMASTER'

	SET @Step = 'Update Customer and Instance'
		CREATE TABLE #Customer
			(
			[CustomerID] int,
			[CustomerName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[CustomerDescription] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[CompanyTypeID] int,
			[ProductKey] nvarchar(17) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #Instance
			(
			[InstanceID] int,
			[InstanceName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[InstanceDescription] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[InstanceShortName] nvarchar(5) COLLATE DATABASE_DEFAULT
			)

		IF @InstanceID = 0
			BEGIN
				INSERT INTO #Customer ([CustomerID], [CustomerName], [CustomerDescription], [CompanyTypeID], [ProductKey]) SELECT [CustomerID], [CustomerName], [CustomerDescription], [CompanyTypeID], [ProductKey] FROM [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C WHERE C.CompanyTypeID = 1 AND C.[Updated] > @PartnerUserLastUpdate
				INSERT INTO #Instance ([InstanceID], [InstanceName], [InstanceDescription], [InstanceShortName]) SELECT [InstanceID], [InstanceName], [InstanceDescription], [InstanceShortName] = ISNULL([InstanceShortName], LEFT([InstanceName], 5)) FROM [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C ON C.CustomerID = I.CustomerID AND C.CompanyTypeID = 1 WHERE I.[Updated] > @PartnerUserLastUpdate
			END
		ELSE
			BEGIN
				INSERT INTO #Customer ([CustomerID], [CustomerName], [CustomerDescription], [CompanyTypeID], [ProductKey])
				SELECT DISTINCT C.[CustomerID], C.[CustomerName], C.[CustomerDescription], C.[CompanyTypeID], C.[ProductKey]
				FROM
					[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C
					INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I ON I.[InstanceID] = @InstanceID AND I.[CustomerID] = C.[CustomerID]
				WHERE C.CompanyTypeID = 1 AND C.[Updated] > @PartnerUserLastUpdate
				
				INSERT INTO #Instance ([InstanceID], [InstanceName], [InstanceDescription], [InstanceShortName])
				SELECT I.[InstanceID], I.[InstanceName], I.[InstanceDescription], [InstanceShortName] = ISNULL(I.[InstanceShortName], LEFT(I.[InstanceName], 5)) 
				FROM [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C ON C.CustomerID = I.CustomerID AND C.CompanyTypeID = 1
				WHERE I.[InstanceID] = @InstanceID AND I.[Updated] > @PartnerUserLastUpdate
			END

		IF @DebugBM & 2 > 0
			BEGIN
				SELECT TempTable = '#Customer', * FROM #Customer ORDER BY [CustomerID]
				SELECT TempTable = '#Instance', * FROM #Instance ORDER BY [InstanceID]
			END

		UPDATE C
		SET
			[CustomerName] = SC.[CustomerName],
			[CustomerDescription] = SC.[CustomerDescription],
			[CompanyTypeID] = SC.[CompanyTypeID],
			[ProductKey] = SC.[ProductKey]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Customer] C
			INNER JOIN #Customer SC ON SC.[CustomerID] = C.[CustomerID]

		SET @Updated = @Updated + @@ROWCOUNT

		UPDATE I
		SET
			[InstanceName] = SI.[InstanceName],
			[InstanceDescription] = SI.[InstanceDescription],
			[InstanceShortName] = SI.[InstanceShortName]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Instance] I
			INNER JOIN #Instance SI ON SI.[InstanceID] = I.[InstanceID]

		SET @Updated = @Updated + @@ROWCOUNT
	
	SET @Step = 'Fill user temp tables'
		CREATE TABLE #User
			(
			[InstanceID] [int],
			[UserID] [int],
			[UserName] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[UserNameAD] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[UserNameDisplay] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[UserTypeID] [int],
			[UserLicenseTypeID] [int],
			[LocaleID] [int],
			[LanguageID] [int],
			[ObjectGuiBehaviorBM] [int],
			[InheritedFrom] [int],
			[SelectYN] [bit],
			[Inserted] [datetime],
			[Updated] [datetime],
			[Version] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[DeletedID] [int]
			)

		CREATE TABLE #UserPropertyValue
			(
			[InstanceID] [int],
			[UserID] [int],
			[UserPropertyTypeID] [int],
			[UserPropertyValue] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[SelectYN] [bit],
			[Inserted] [datetime],
			[Updated] [datetime],
			[Version] [nvarchar](100) COLLATE DATABASE_DEFAULT
			)

		IF @InstanceID = 0
			BEGIN
				INSERT INTO #User
					(
					[InstanceID],
					[UserID],
					[UserName],
					[UserNameAD],
					[UserNameDisplay],
					[UserTypeID],
					[UserLicenseTypeID],
					[LocaleID],
					[LanguageID],
					[ObjectGuiBehaviorBM],
					[InheritedFrom],
					[SelectYN],
					[Inserted],
					[Updated],
					[Version],
					[DeletedID]
					)
				SELECT DISTINCT
					U.[InstanceID],
					U.[UserID],
					U.[UserName],
					U.[UserNameAD],
					U.[UserNameDisplay],
					U.[UserTypeID],
					U.[UserLicenseTypeID],
					U.[LocaleID],
					U.[LanguageID],
					U.[ObjectGuiBehaviorBM],
					U.[InheritedFrom],
					U.[SelectYN],
					U.[Inserted],
					U.[Updated],
					U.[Version],
					U.[DeletedID]
				FROM 
					DSPMASTER.pcINTEGRATOR_Master.dbo.[User] U
					LEFT JOIN DSPMASTER.pcINTEGRATOR_Master.dbo.[UserPropertyValue] UPV ON UPV.UserID = U.UserID
				WHERE 
					U.Updated > @PartnerUserLastUpdate OR 
					UPV.Updated > @PartnerUserLastUpdate
				
				INSERT INTO #UserPropertyValue
					(
					[InstanceID],
					[UserID],
					[UserPropertyTypeID],
					[UserPropertyValue],
					[SelectYN],
					[Inserted],
					[Updated],
					[Version]
					)
				SELECT
					[InstanceID],
					[UserID],
					[UserPropertyTypeID],
					[UserPropertyValue],
					[SelectYN],
					[Inserted],
					[Updated],
					[Version]
				FROM DSPMASTER.pcINTEGRATOR_Master.dbo.[UserPropertyValue] WHERE Updated > @PartnerUserLastUpdate
			END
		ELSE
			BEGIN
				INSERT INTO #User
					(
					[InstanceID],
					[UserID],
					[UserName],
					[UserNameAD],
					[UserNameDisplay],
					[UserTypeID],
					[UserLicenseTypeID],
					[LocaleID],
					[LanguageID],
					[ObjectGuiBehaviorBM],
					[InheritedFrom],
					[SelectYN],
					[Inserted],
					[Updated],
					[Version],
					[DeletedID]
					)
				SELECT 
					[InstanceID],
					[UserID],
					[UserName],
					[UserNameAD],
					[UserNameDisplay],
					[UserTypeID],
					[UserLicenseTypeID],
					[LocaleID],
					[LanguageID],
					[ObjectGuiBehaviorBM],
					[InheritedFrom],
					[SelectYN],
					[Inserted],
					[Updated],
					[Version],
					[DeletedID]
				FROM DSPMASTER.pcINTEGRATOR_Master.dbo.[User] WHERE InstanceID = @InstanceID AND Updated > @PartnerUserLastUpdate
				
				INSERT INTO #UserPropertyValue
					(
					[InstanceID],
					[UserID],
					[UserPropertyTypeID],
					[UserPropertyValue],
					[SelectYN],
					[Inserted],
					[Updated],
					[Version]
					)
				SELECT
					[InstanceID],
					[UserID],
					[UserPropertyTypeID],
					[UserPropertyValue],
					[SelectYN],
					[Inserted],
					[Updated],
					[Version]
				FROM DSPMASTER.pcINTEGRATOR_Master.dbo.[UserPropertyValue] WHERE InstanceID = @InstanceID AND Updated > @PartnerUserLastUpdate
			END		

		SELECT @CountRows = COUNT(1) FROM #User
		SELECT @CountRows = @CountRows + COUNT(1) FROM #UserPropertyValue

		IF @DebugBM & 2 > 0 SELECT [@CountRows] = @CountRows
		IF @DebugBM & 2 > 0 SELECT TempTable = '#User', * FROM [#User] ORDER BY InstanceID, UserID
		IF @DebugBM & 2 > 0 SELECT TempTable = '#UserPropertyValue', * FROM [#UserPropertyValue] ORDER BY InstanceID, UserID, UserPropertyTypeID

	SET @Step = 'Check number of changed rows'
		IF @CountRows = 0
			BEGIN
				SET @Message = 'Nothing to update'
				SET @Severity = 0
				GOTO EXITPOINT
			END

	SET @Step = 'Check for new Customers and Instances'	
		SELECT
			@CountRows = COUNT(DISTINCT InstanceID)
		FROM
			#User U
		WHERE
			NOT EXISTS (SELECT 1 FROM [Instance] I WHERE I.InstanceID = U.InstanceID)

		IF @CountRows > 0
			BEGIN
				--Customer
				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Customer] ON
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Customer]
					(
					[CustomerID],
					[CustomerName],
					[CustomerDescription],
					[CompanyTypeID],
					[ProductKey]
					)
				SELECT DISTINCT
					C.[CustomerID],
					C.[CustomerName],
					C.[CustomerDescription],
					C.[CompanyTypeID],
					C.[ProductKey]
				FROM 
					DSPMASTER.pcINTEGRATOR_Master.dbo.Customer C
					INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I ON I.CustomerID = C.CustomerID
					INNER JOIN [#User] U ON U.InstanceID = I.InstanceID
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Customer] D WHERE D.CustomerID = C.CustomerID)
		
				SET @Inserted = @Inserted + @@ROWCOUNT		
				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Customer] OFF

				UPDATE C
				SET
					[CompanyTypeID] = CM.[CompanyTypeID]
				FROM
					[pcINTEGRATOR_Data].[dbo].[Customer] C
					INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] CM ON CM.[CustomerID] = C.[CustomerID]
					INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I ON I.CustomerID = C.CustomerID
					INNER JOIN [#User] U ON U.InstanceID = I.InstanceID

				--Instance
				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Instance] ON
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Instance]
					(
					[InstanceID],
					[InstanceName],
					[InstanceDescription],
					[InstanceShortName],
					[CustomerID],
					[BrandID],
					[SelectYN]			
					)
				SELECT DISTINCT
					I.[InstanceID],
					I.[InstanceName],
					I.[InstanceDescription],
					I.[InstanceShortName],
					I.[CustomerID],
					I.[BrandID],
					[SelectYN] = 1
				FROM 
					[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I
					INNER JOIN [#User] U ON U.InstanceID = I.InstanceID
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Instance] D WHERE D.InstanceID = I.InstanceID)
		
				SET @Inserted = @Inserted + @@ROWCOUNT		
				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Instance] OFF
			END

	SET @Step = 'Update User for already existing usernames'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[User_Instance]
			(
			[InstanceID],
			[UserID],
			[SelectYN],
			[DeletedID]
			)
		SELECT
			U.[InstanceID],
			U.[UserID],
			U.[SelectYN],
			U.[DeletedID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[User] U
			INNER JOIN #User UU ON UU.UserName = U.UserName AND UU.InstanceID <> U.InstanceID
		WHERE
			U.DeletedID IS NULL AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User_Instance] D WHERE D.[InstanceID] = U.[InstanceID] AND D.UserID = U.[UserID])

		UPDATE UPV
		SET
			[InstanceID] = UU.InstanceID
		FROM
			[pcINTEGRATOR_Data].[dbo].[User] U
			INNER JOIN #User UU ON UU.UserName = U.UserName AND UU.InstanceID <> U.InstanceID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV ON UPV.UserID = U.UserID
		WHERE
			U.DeletedID IS NULL

		UPDATE U
		SET	
			[InstanceID] = UU.InstanceID,
			[InheritedFrom] = UU.UserID
		FROM
			[pcINTEGRATOR_Data].[dbo].[User] U
			INNER JOIN #User UU ON UU.UserName = U.UserName AND UU.InstanceID <> U.InstanceID
		WHERE
			U.DeletedID IS NULL

	SET @Step = 'Update User'
		UPDATE U
		SET
			[InstanceID] = S.[InstanceID],
			[UserNameAD] = S.[UserNameAD],
			[UserNameDisplay] = S.[UserNameDisplay],
			[UserTypeID] = S.[UserTypeID],
			[UserLicenseTypeID] = S.[UserLicenseTypeID],
			[LocaleID] = S.[LocaleID],
			[LanguageID] = S.[LanguageID],
			[ObjectGuiBehaviorBM] = S.[ObjectGuiBehaviorBM],
			[InheritedFrom] = S.[UserID],
			[SelectYN] = S.[SelectYN],
			[DeletedID] = S.[DeletedID]
		FROM
			pcINTEGRATOR_Data.dbo.[User] U
			INNER JOIN #User S ON S.[UserName] = U.[UserName] AND (S.DeletedID = U.DeletedID OR S.[DeletedID] IS NOT NULL AND U.[DeletedID] IS NULL OR S.[DeletedID] IS NULL AND U.[DeletedID] IS NULL)
		WHERE
			U.DeletedID IS NULL

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert into User'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[User]
			(
			[InstanceID],
			[UserName],
			[UserNameAD],
			[UserNameDisplay],
			[UserTypeID],
			[UserLicenseTypeID],
			[LocaleID],
			[LanguageID],
			[ObjectGuiBehaviorBM],
			[InheritedFrom],
			[SelectYN],
			[DeletedID]
			)
		SELECT
			[InstanceID],
			[UserName],
			[UserNameAD],
			[UserNameDisplay],
			[UserTypeID],
			[UserLicenseTypeID],
			[LocaleID],
			[LanguageID],
			[ObjectGuiBehaviorBM],
			[InheritedFrom] = S.[UserID],
			[SelectYN],
			[DeletedID]
		FROM
			#User S
		WHERE
			S.[DeletedID] IS NULL AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] D WHERE D.[UserName] = S.[UserName] AND D.[DeletedID] IS NULL) AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] D WHERE D.[InheritedFrom] = S.[UserID] AND D.[DeletedID] IS NULL)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update UserPropertyValue'
		UPDATE UPV
		SET 
			[InstanceID] = S.[InstanceID],
			[UserPropertyValue] = S.[UserPropertyValue],
			[SelectYN] = S.[SelectYN]
		FROM 
			[pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV
			INNER JOIN [User] U ON U.UserID = UPV.UserID
			INNER JOIN [#UserPropertyValue] S ON S.UserID = U.InheritedFrom AND S.[UserPropertyTypeID] = UPV.UserPropertyTypeID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert into UserPropertyValue'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserPropertyValue]
			(
			[InstanceID],
			[UserID],
			[UserPropertyTypeID],
			[UserPropertyValue],
			[SelectYN]
			)
		SELECT 
			S.[InstanceID],
			U.[UserID],
			S.[UserPropertyTypeID],
			S.[UserPropertyValue],
			S.[SelectYN]
		FROM 
			[#UserPropertyValue] S
			INNER JOIN [#User] SU ON SU.[UserID] = S.[UserID] AND SU.[DeletedID] IS NULL
			INNER JOIN [User] U ON U.[InstanceID] = S.[InstanceID] AND U.[InheritedFrom] = S.[UserID]
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] D WHERE D.UserID = U.[UserID] AND D.[UserPropertyTypeID] = S.[UserPropertyTypeID])

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update [PartnerUserLastUpdate] in table [SystemValue]'
		UPDATE SV
		SET
			[PartnerUserLastUpdate] = @StartTime
		FROM
			pcINTEGRATOR_Data.dbo.SystemValue SV
		WHERE
			SystemID = 0 AND
			@InstanceID = 0

	SET @Step = 'Drop temp tables'
		DROP TABLE #Customer
		DROP TABLE #Instance
		DROP TABLE #User
		DROP TABLE #UserPropertyValue

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
