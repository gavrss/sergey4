SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_AssignedUser]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@AssignedUserID int = NULL,
	@AssignedUserName nvarchar(100) = NULL,
	@AssignedUserNameAD nvarchar(100) = NULL,
	@AssignedUserInstanceID int = NULL,
	@AssignedUserPropertyTypeID int = NULL,
	@AssignedUserPropertyValue nvarchar(100) = NULL,
	@ResultTypeBM int = 3,
		-- 1 = Loading User by UserName or ActiveDirectoryName
		-- 2 = Loading Feature setting for User in specific Instance

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 0,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000444,
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
EXEC [spRun_Procedure_KeyValuePair] 
	@ProcedureName='spPortalAdminGet_AssignedUser',
	@JSON='
		[
		{"TKey":"InstanceID","TValue":"0"},
		{"TKey":"AssignedUserName","TValue":"ihor.bohdanov@rozdoum.com"},
		{"TKey":"UserID","TValue":"-10"},
		{"TKey":"VersionID","TValue":"0"},
		{"TKey":"ResultTypeBM","TValue":"3"},
		{"TKey":"Debug","TValue":"1"}
		]'

EXEC [spPortalAdminGet_AssignedUser] @AssignedUserID='9625',@InstanceID='0',@ResultTypeBM='3',@UserID='-10',@VersionID='0',@Debug=1
EXEC [spPortalAdminGet_AssignedUser] @UserID=-10, @InstanceID=390, @VersionID=1011, @ResultTypeBM=3, @Debug=1
EXEC [spPortalAdminGet_AssignedUser] @UserID=NULL, @InstanceID=NULL, @VersionID=NULL, @ResultTypeBM=3, @AssignedUserID = 2538, @AssignedUserInstanceID=390, @Debug=1 --User
EXEC [spPortalAdminGet_AssignedUser] @UserID=NULL, @InstanceID=NULL, @VersionID=NULL, @ResultTypeBM=1, @AssignedUserName = 'erp10.administrator', @Debug=1 --UserLogin
EXEC [spPortalAdminGet_AssignedUser] @UserID='-10', @InstanceID='0', @VersionID='0', @AssignedUserPropertyTypeID=-10, @AssignedUserPropertyValue='jan.wogel@dspanel.com', @ResultTypeBM='1', @Debug=1
EXEC [spPortalAdminGet_AssignedUser] @UserID='-10', @InstanceID='0', @VersionID='0', @AssignedUserPropertyTypeID=-1, @AssignedUserPropertyValue='jan', @ResultTypeBM='1', @Debug=1
EXEC [spPortalAdminGet_AssignedUser] @InstanceID='574',@AssignedUserID='26881',@VersionID='1045'

EXEC [spPortalAdminGet_AssignedUser] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Returns properties for Assigned User',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-86: Fixed bug regarding InstanceID ResultTypeBM=1. DB-99: Changed references to views instead of tables in pcINTEGRATOR_Data. Added CASE statement for handling UserLicenseTypeID.'
		IF @Version = '2.0.2.2147' SET @Description = 'DB-117: There are no "Administrative role"(-26) SecurityRoleObject for Admin for DSPanel Use user.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-142: Added filter on DeletedID for ResultTypeBM = 1. Added temp table #Users. DB-206: Securityrole "All users" always added.'
		IF @Version = '2.0.2.2149' SET @Description = 'DB-229: Added [ObjectGuiBehaviorBM] for ResultTypeBM = 1.'
		IF @Version = '2.0.3.2151' SET @Description = 'Update User info for Partner Users.'
		IF @Version = '2.1.0.2155' SET @Description = 'Check connection to DSPMASTER.'
		IF @Version = '2.1.0.2157' SET @Description = 'Use sub routine [spGet_Connection] for opening connection to DSPMASTER.'
		IF @Version = '2.1.0.2159' SET @Description = 'DB-465: Changed handling for Security role -3 (All users). Added InstanceID to temp table #SecurityRole.'
		IF @Version = '2.1.0.2163' SET @Description = 'Test on deleted Groups.'
		IF @Version = '2.1.1.2177' SET @Description = 'DB-711: Added parameter @AssignedUserPropertyTypeID and @AssignedUserPropertyValue.'
		IF @Version = '2.1.2.2179' SET @Description = 'Call sub routine [spGet_AssignedUser].'

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

		IF @Debug <> 0
			SELECT
				[@AssignedUserID] = @AssignedUserID,
				[@AssignedUserName] = @AssignedUserName,
				[@AssignedUserNameAD] = @AssignedUserNameAD,
				[@AssignedUserInstanceID] = @AssignedUserInstanceID,
				[@AssignedUserPropertyTypeID] = @AssignedUserPropertyTypeID,
				[@AssignedUserPropertyValue] = @AssignedUserPropertyValue

	SET @Step = 'Check connection'
		EXEC [spGet_Connection] @LinkedServer = 'DSPMASTER'

	SET @Step = 'Update user tables for partner users'
		SET ANSI_NULLS ON; SET ANSI_WARNINGS ON; EXEC [spGet_PartnerUser] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID
		SET ANSI_WARNINGS OFF

	SET @Step = 'Create and Insert data into temp table #Users'
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

		EXEC [dbo].[spGet_AssignedUser]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@AssignedUserID = @AssignedUserID,
			@AssignedUserName = @AssignedUserName,
			@AssignedUserNameAD = @AssignedUserNameAD,
			@AssignedUserInstanceID = @AssignedUserInstanceID,
			@AssignedUserPropertyTypeID = @AssignedUserPropertyTypeID,
			@AssignedUserPropertyValue = @AssignedUserPropertyValue,
			@JobID = @JobID,
			@Debug = @DebugSub

		IF @Debug <> 0
			SELECT [TempTable] = '#Users', * FROM #Users

	SET @Step = 'Create temp table #SecurityRole'
		CREATE TABLE #SecurityRole
			(
			InstanceID int,
			SecurityRoleID int,
			)
		
	SET @Step = 'Insert data into temp table #SecurityRole'
		IF @ResultTypeBM & 2 > 0 
			BEGIN
				INSERT INTO #SecurityRole
					(
					InstanceID,
					SecurityRoleID
					)
				SELECT DISTINCT
					SRU.InstanceID,
					SRU.SecurityRoleID
				FROM
					[#Users] U
					INNER JOIN [pcINTEGRATOR].[dbo].[SecurityRoleUser] SRU ON SRU.UserID = U.UserID
				WHERE 
					U.InstanceID = @AssignedUserInstanceID AND
					(U.UserID = @AssignedUserID OR U.UserName = @AssignedUserName OR U.UserNameAD = @AssignedUserNameAD) AND  
					U.[SelectYN] <> 0
				UNION
				SELECT DISTINCT
					SRU.InstanceID,
					SRU.SecurityRoleID
				FROM
					[#Users] U
					INNER JOIN [pcINTEGRATOR].[dbo].[UserMember] UM ON UM.InstanceID = U.InstanceID AND UM.UserID_User = U.UserID
					INNER JOIN [pcINTEGRATOR].[dbo].[User] US ON US.UserID = UM.UserID_Group AND US.SelectYN <> 0 AND US.DeletedID IS NULL
					INNER JOIN [pcINTEGRATOR].[dbo].[SecurityRoleUser] SRU ON SRU.UserID = UM.UserID_Group
				WHERE 
					U.InstanceID = @AssignedUserInstanceID AND
					(U.UserID = @AssignedUserID OR U.UserName = @AssignedUserName OR U.UserNameAD = @AssignedUserNameAD) AND  
					U.[SelectYN] <> 0
				UNION
				SELECT DISTINCT
					InstanceID,
					SecurityRoleID = -3
				FROM
					#Users

				IF @Debug <> 0
					SELECT [TempTable] = '#SecurityRole', * FROM #SecurityRole ORDER BY SecurityRoleID
			END

	SET @Step = 'Loading User by UserName or ActiveDirectoryName'
		IF @ResultTypeBM & 1 > 0 	
			BEGIN
				SELECT DISTINCT
					[ResultTypeBM] = 1,
					[InstanceID] = U.[InstanceID],
					[InstanceName] = I.[InstanceName],
					[UserID] = U.[UserID],
					[DisplayName] = U.[UserNameDisplay],
					[UserName] = U.[UserName],
					[ActiveDirectoryName] = U.[UserNameAD],
					[Email] = U.[Email],
					[UserLicenseTypeID] = CASE WHEN ISNULL(U.[UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END,
					[LicenseType] = ULT.[UserLicenseTypeName],
					[ObjectGuiBehaviorBM] = U.[ObjectGuiBehaviorBM],
					[LocaleID] = U.[LocaleID],
					[Locale] = LO.[LocaleName],
					[LanguageID] = U.[LanguageID],
					[Language] = LA.[LanguageName],
					[EnabledYN] = U.[SelectYN],
					[UserTypeID] = U.[UserTypeID],
					[UserTypeName] = UT.[UserTypeName],
					[PW] = UPV.[UserPropertyValue],
					[UserPropertyTypeID] = UPVD.[UserPropertyTypeID],
					[UserPropertyValue] = UPVD.[UserPropertyValue]
				FROM 
					[#Users] U
					INNER JOIN [Instance] I ON I.[InstanceID] = U.[InstanceID]
					INNER JOIN [pcINTEGRATOR].[dbo].[UserType] UT ON UT.[UserTypeID] = U.[UserTypeID]
					INNER JOIN [pcINTEGRATOR].[dbo].[UserLicenseType] ULT ON ULT.[UserLicenseTypeID] = CASE WHEN ISNULL(U.[UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END
					INNER JOIN [pcINTEGRATOR].[dbo].[Locale] LO ON LO.[LocaleID] = U.[LocaleID]
					INNER JOIN [pcINTEGRATOR].[dbo].[Language] LA ON LA.[LanguageID] = U.[LanguageID]
					LEFT JOIN [pcINTEGRATOR].[dbo].[UserPropertyValue] UPV ON UPV.[UserID] = U.[UserID] AND UPV.[UserPropertyTypeID] = -1001 AND UPV.[SelectYN] <> 0
					LEFT JOIN [pcINTEGRATOR].[dbo].[UserPropertyValue] UPVD ON UPVD.[UserID] = U.[UserID] AND UPVD.[UserPropertyTypeID] = @AssignedUserPropertyTypeID AND UPVD.[UserPropertyValue]=@AssignedUserPropertyValue AND UPVD.[SelectYN] <> 0
				WHERE 
					((U.[UserID] = @AssignedUserID OR U.[UserName] = @AssignedUserName OR U.[UserNameAD] = @AssignedUserNameAD) OR
					(UPVD.[UserPropertyTypeID] = @AssignedUserPropertyTypeID AND UPVD.[UserPropertyValue]=@AssignedUserPropertyValue)) AND
					U.[DeletedID] IS NULL

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Loading Feature setting for User in specific Instance'
		IF @ResultTypeBM & 2 > 0 	
			BEGIN
				SELECT DISTINCT
					[ResultTypeBM] = 2,
					SRO.[InstanceID],
					SRO.[ObjectID],
					O.[ObjectName]
				FROM 
					[pcINTEGRATOR].[dbo].[SecurityRoleObject] SRO
					INNER JOIN #SecurityRole SR ON SR.InstanceID = SRO.InstanceID AND SR.SecurityRoleID = SRO.SecurityRoleID
					INNER JOIN [pcINTEGRATOR].[dbo].[Object] O ON O.[InstanceID] IN (0, SRO.[InstanceID]) AND O.ObjectID = SRO.[ObjectID] AND O.[ParentObjectID] = -25 AND O.[ObjectTypeBM] & 16384 > 0 AND O.[SecurityLevelBM] & 32 > 0 AND O.[SelectYN] <> 0
				WHERE
					SRO.[InstanceID] = @AssignedUserInstanceID AND
					SRO.[SelectYN] <> 0
				UNION
				SELECT DISTINCT
					[ResultTypeBM] = 2,
					[InstanceID] = SR.InstanceID,
					[ObjectID] = O.[ObjectID],
					[ObjectName] = O.[ObjectName]
				FROM 
					[pcINTEGRATOR].[dbo].[Object] O
					INNER JOIN #SecurityRole SR ON SR.InstanceID = @AssignedUserInstanceID AND SR.SecurityRoleID = -1
				WHERE
					O.ObjectID = -26 --Administrative role

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp table'
		IF @ResultTypeBM & 2 > 0 
			DROP TABLE #SecurityRole

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
