SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_AssignedUser]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@AssignedUserID int = NULL,
	@AssignedUserName nvarchar(100) = NULL,
	@AssignedUserNameAD nvarchar(100) = NULL,
	@AssignedUserInstanceID int = NULL,
	@AssignedUserPropertyTypeID int = NULL,
	@AssignedUserPropertyValue nvarchar(100) = NULL,
	@ObjectGuiBehaviorBM int = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 0,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000822,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spGet_AssignedUser',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spGet_AssignedUser] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spGet_AssignedUser] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,

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
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Returns properties for Assigned User',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2179' SET @Description = 'Procedure created.'

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
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create temp table #Users'
		IF OBJECT_ID(N'TempDB.dbo.#Users', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #Users
					(
					[InstanceID] int,
					[UserID] int,
					[UserName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[UserNameAD] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[UserNameDisplay] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Email] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[UserTypeID] int,
					[UserLicenseTypeID] int,
					[LocaleID] int,
					[LanguageID] int,
					[ObjectGuiBehaviorBM] int,
					[HomeInstanceYN] bit,
					[HomeInstanceID] int,
					[ExpiryDate] date,
					[SelectYN] bit,
					[DeletedID] int
					)
			END

	SET @Step = 'Insert data into temp table #Users'
		INSERT INTO #Users
			(
			[InstanceID],
			[UserID],
			[UserName],
			[UserNameAD],
			[UserNameDisplay],
			[Email],
			[UserTypeID],
			[UserLicenseTypeID],
			[LocaleID],
			[LanguageID],
			[ObjectGuiBehaviorBM],
			[HomeInstanceYN],
			[HomeInstanceID],
			[ExpiryDate],
			[SelectYN],
			[DeletedID]
			)
		SELECT 
			U.[InstanceID],
			U.[UserID],
			[UserName],
			[UserNameAD],
			[UserNameDisplay],
			[Email] = ISNULL(UPV.UserPropertyValue, CASE WHEN CHARINDEX('@', U.[UserName]) = 0 THEN NULL ELSE U.[UserName] END),
			[UserTypeID],
			[UserLicenseTypeID] = CASE WHEN ISNULL([UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END,
			[LocaleID],
			[LanguageID],
			[ObjectGuiBehaviorBM],
			[HomeInstanceYN] = 1,
			[HomeInstanceID] = U.[InstanceID],
			[ExpiryDate] = NULL,
			U.[SelectYN],
			[DeletedID]
		FROM 
			[pcINTEGRATOR].[dbo].[User] U
			LEFT JOIN [UserPropertyValue] UPV ON UPV.UserID = U.UserID AND UPV.UserPropertyTypeID = -3 AND UPV.SelectYN <> 0
		WHERE 
			((U.UserID = @AssignedUserID OR U.UserName = @AssignedUserName OR U.UserNameAD = @AssignedUserNameAD) OR
			U.[InstanceID] = @AssignedUserInstanceID AND U.[UserID] IN (@AssignedUserID)) AND
			U.[DeletedID] IS NULL
		UNION
		SELECT 
			UI.[InstanceID],
			UI.[UserID],
			U.[UserName],
			U.[UserNameAD],
			U.[UserNameDisplay],
			[Email] = ISNULL(UPV.UserPropertyValue, CASE WHEN CHARINDEX('@', U.[UserName]) = 0 THEN NULL ELSE U.[UserName] END),
			U.[UserTypeID],
			[UserLicenseTypeID] = CASE WHEN ISNULL(U.[UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END,
			U.[LocaleID],
			U.[LanguageID],
			U.[ObjectGuiBehaviorBM],
			[HomeInstanceYN] = 0,
			[HomeInstanceID] = U.[InstanceID],
			UI.[ExpiryDate],
			UI.[SelectYN],
			UI.[DeletedID]
		FROM 
			[pcINTEGRATOR].[dbo].[User_Instance] UI
			INNER JOIN [pcINTEGRATOR].[dbo].[User] U ON U.[UserID] = UI.[UserID] AND U.[DeletedID] IS NULL
			LEFT JOIN [UserPropertyValue] UPV ON UPV.UserID = U.UserID AND UPV.UserPropertyTypeID = -3 AND UPV.SelectYN <> 0
		WHERE 
			UI.[InstanceID] = @AssignedUserInstanceID AND
			UI.[UserID] = @AssignedUserID AND
			(UI.[ExpiryDate] > GETDATE() OR UI.[ExpiryDate] IS NULL) AND
			UI.[DeletedID] IS NULL

		UNION SELECT 
			U.[InstanceID],
			U.[UserID],
			[UserName],
			[UserNameAD],
			[UserNameDisplay],
			[Email] = ISNULL(UPV.UserPropertyValue, CASE WHEN CHARINDEX('@', U.[UserName]) = 0 THEN NULL ELSE U.[UserName] END),
			[UserTypeID],
			[UserLicenseTypeID] = CASE WHEN ISNULL([UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END,
			[LocaleID],
			[LanguageID],
			[ObjectGuiBehaviorBM],
			[HomeInstanceYN] = 1,
			[HomeInstanceID] = U.[InstanceID],
			[ExpiryDate] = NULL,
			U.[SelectYN],
			[DeletedID]
		FROM 
			[pcINTEGRATOR].[dbo].[User] U
			INNER JOIN [UserPropertyValue] UPV ON UPV.UserID = U.UserID AND UPV.UserPropertyTypeID = @AssignedUserPropertyTypeID AND UPV.[UserPropertyValue]=@AssignedUserPropertyValue AND UPV.SelectYN <> 0
		WHERE 
			U.[DeletedID] IS NULL

		IF @Debug <> 0
			SELECT [TempTable] = '#Users', * FROM #Users

	SET @Step = 'Set return parameters'
		SELECT
			@ObjectGuiBehaviorBM = MAX([ObjectGuiBehaviorBM])
		FROM
			#Users

	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0
			DROP TABLE #Users

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
