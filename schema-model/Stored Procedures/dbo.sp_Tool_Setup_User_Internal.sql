SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Setup_User_Internal]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000484,
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
EXEC [sp_Tool_Setup_User_Internal] @UserID=-10, @InstanceID=390, @VersionID=1011, @DebugBM=2

EXEC [sp_Tool_Setup_User_Internal] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.3.2153'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Add internal users',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created. Added UPDATE and INSERT queries to [Customer] and [Instance] tables. Added UPDATE of [User] for already existing Usernames.'
		IF @Version = '2.0.2.2149' SET @Description = 'DB-220: Delete Users that are added to their home instance in table User_Instance.'
		IF @Version = '2.0.3.2153' SET @Description = 'Removed references to detailed columns in master table Instance.'

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

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Update Customer'
		SELECT DISTINCT
			C.[CustomerID],
			C.[CustomerName],
			C.[CustomerDescription],
			C.[CompanyTypeID]
		INTO
			#Customer
		FROM 
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Customer] C
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I ON I.CustomerID = C.CustomerID
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[User] U ON U.InstanceID = I.InstanceID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Customer', * FROM #Customer ORDER BY CustomerID

		UPDATE C
		SET
			[CompanyTypeID] = CM.[CompanyTypeID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Customer] C
			INNER JOIN #Customer CM ON CM.[CustomerID] = C.[CustomerID]

		SET @Updated = @Updated + @@ROWCOUNT		

	SET @Step = 'Insert into Customer'
		SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Customer] ON
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Customer]
			(
			[CustomerID],
			[CustomerName],
			[CustomerDescription],
			[CompanyTypeID]			
			)
		SELECT DISTINCT
			C.[CustomerID],
			C.[CustomerName],
			C.[CustomerDescription],
			C.[CompanyTypeID]
		FROM 
			#Customer C
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Customer] D WHERE D.CustomerID = C.CustomerID)
		
		SET @Inserted = @Inserted + @@ROWCOUNT		
		SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Customer] OFF

	SET @Step = 'Update Instance'
		SELECT DISTINCT
			I.[InstanceID],
			I.[InstanceName],
			I.[InstanceDescription],
			I.[CustomerID],
			I.[ProductKey],
			I.[Nyc],
			I.[Nyu],
			I.[BrandID],
			I.[SelectYN]
		INTO
			#Instance
		FROM 
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[Instance] I
			INNER JOIN [DSPMASTER].[pcINTEGRATOR_Master].[dbo].[User] U ON U.InstanceID = I.InstanceID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Instance', * FROM #Instance ORDER BY InstanceID

		UPDATE I
		SET
			[InstanceName] = IM.[InstanceName],
			[InstanceDescription] = IM.[InstanceDescription],
			[SelectYN] = IM.[SelectYN]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Instance] I
			INNER JOIN #Instance IM ON IM.[InstanceID] = I.[InstanceID]

		SET @Updated = @Updated + @@ROWCOUNT	

	SET @Step = 'Insert into Instance'
		SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Instance] ON
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Instance]
			(
			[InstanceID],
			[InstanceName],
			[InstanceDescription],
			[CustomerID],
			[ProductKey],
			[Nyc],
			[Nyu],
			[BrandID],
			[SelectYN]			
			)
		SELECT DISTINCT
			I.[InstanceID],
			I.[InstanceName],
			I.[InstanceDescription],
			I.[CustomerID],
			I.[ProductKey],
			I.[Nyc],
			I.[Nyu],
			I.[BrandID],
			I.[SelectYN]	
		FROM 
			#Instance I
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Instance] D WHERE D.InstanceID = I.InstanceID)
		
		SET @Inserted = @Inserted + @@ROWCOUNT		
		SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Instance] OFF

	SET @Step = 'Insert into #User'
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
		INTO
			#User
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[User] S

		IF @DebugBM & 2 > 0 SELECT TempTable = '#User', * FROM #User ORDER BY [InstanceID], [UserName]

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
			INNER JOIN #User UU ON UU.UserName = U.UserName
		WHERE
			U.DeletedID IS NULL AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User_Instance] D WHERE D.[InstanceID] = U.[InstanceID] AND D.UserID = U.[UserID])

		UPDATE U
		SET	
			[InstanceID] = UU.InstanceID,
			[InheritedFrom] = UU.InheritedFrom
		FROM
			[pcINTEGRATOR_Data].[dbo].[User] U
			INNER JOIN #User UU ON UU.UserName = U.UserName
		WHERE
			U.DeletedID IS NULL

		UPDATE UPV
		SET
			[InstanceID] = UU.InstanceID
		FROM
			[pcINTEGRATOR_Data].[dbo].[User] U
			INNER JOIN #User UU ON UU.UserName = U.UserName
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV ON UPV.UserID = U.UserID
		WHERE
			U.DeletedID IS NULL

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
			[InheritedFrom],
			[SelectYN],
			[DeletedID]
		FROM
			#User S
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] D WHERE D.[UserName] = S.[UserName] AND D.[DeletedID] IS NULL)

		SET @Inserted = @Inserted + @@ROWCOUNT

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
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[UserPropertyValue] S
			INNER JOIN [User] U ON U.InstanceID = S.InstanceID AND U.InheritedFrom = S.UserID
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] D WHERE D.UserID = U.[UserID] AND D.[UserPropertyTypeID] = S.[UserPropertyTypeID])

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Delete Users that are added to their home instance in table User_Instance'
		DELETE UI
		FROM 
			[pcINTEGRATOR_Data].[dbo].[User_Instance] UI
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] U ON U.[InstanceID] = UI.[InstanceID] AND U.[UserID] = UI.[UserID]

		SET @Deleted = @Deleted + @@ROWCOUNT

/*
	SET @Step = 'Insert into User_Instance'
		INSERT INTO pcINTEGRATOR_Data..[User_Instance]
			(
			[InstanceID],
			[UserID],
			[ExpiryDate],
			[Inserted],
			[InsertedBy],
			[SelectYN],
			[DeletedID]
			)
		SELECT
			S.[InstanceID],
			U.[UserID],
			S.[ExpiryDate],
			S.[Inserted],
			S.[InsertedBy],
			S.[SelectYN],
			S.[DeletedID]
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[tmp_User_Instance] S
			INNER JOIN pcINTEGRATOR_Data..[User] U ON U.InheritedFrom = S.UserID
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..[User_Instance] D WHERE D.[InstanceID] = S.[InstanceID] AND D.UserID = U.[UserID])

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert into SecurityRoleUser'
		INSERT INTO pcINTEGRATOR_Data..[SecurityRoleUser]
			(
			[InstanceID],
			[SecurityRoleID],
			[UserID],
			[SelectYN]
			)
		SELECT 
			S.[InstanceID],
			S.[SecurityRoleID],
			U.[UserID],
			S.[SelectYN]
		FROM
			[DSPMASTER].[pcINTEGRATOR_Master].[dbo].[tmp_SecurityRoleUser] S
			INNER JOIN pcINTEGRATOR_Data..[User] U ON U.InheritedFrom = S.UserID
		WHERE
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data..[SecurityRoleUser] D WHERE D.[InstanceID] = S.[InstanceID] AND D.SecurityRoleID = S.SecurityRoleID AND D.UserID = U.[UserID])

		SET @Inserted = @Inserted + @@ROWCOUNT
*/
	SET @Step = 'Drop temp tables'
		DROP TABLE #Customer
		DROP TABLE #Instance

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
