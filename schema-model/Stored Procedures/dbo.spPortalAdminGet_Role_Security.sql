SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Role_Security]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--@AssignedInstanceID int = NULL,
	--@AssignedVersionID int = NULL,
	@SecurityRoleID int = NULL,
	@ResultTypeBM int = 63,
		-- 1 = List of Security Role
		-- 2 = List of Role Members
		-- 4 = List of enabled Features
		-- 8 = List of Users and Groups not set as Role Members
		--16 = List of User License Type
		--32 = Full List of Features Access
		--64 = Full List of Callisto Actions Access

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000438,
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
EXEC [pcINTEGRATOR].[dbo].[spPortalAdminGet_Role_Security] @InstanceID=N'858'
,@ResultTypeBM=N'8',@SecurityRoleID=N'-2',@UserID=N'31972',@VersionID=N'1265',@Debug=1

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminGet_Role_Security',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_Role_Security] @UserID=-10, @InstanceID=390, @VersionID=1011, @ResultTypeBM=63, @Debug=1
EXEC [spPortalAdminGet_Role_Security] @UserID=-10, @InstanceID=390, @VersionID=1011, @ResultTypeBM=63, @SecurityRoleID=-1, @Debug=1

EXEC spPortalAdminGet_Role_Security @InstanceID='413',@ResultTypeBM='4',@SecurityRoleID='-1',@UserID='2147',@VersionID='1008'
EXEC spPortalAdminGet_Role_Security @InstanceID='413',@UserID='2147',@VersionID='1008'
EXEC spPortalAdminGet_Role_Security @UserID='2147', @InstanceID='454',@VersionID='1021', @SecurityRoleID='-1', @ResultTypeBM='64'

EXEC [spPortalAdminGet_Role_Security] @GetVersion = 1
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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Returns data for pcPortal Roles and Security',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-95 Removed hidden roles from ResultTypeBM = 1.'
		IF @Version = '2.0.2.2147' SET @Description = 'DB-117: There are no "Administrative role"(-26) SecurityRoleObject for Admin for DSPanel Use user. Added "All Users" SecurityRole in @ResultTypeBM = 1. Added ResultTypeBM = 64'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-394: Test on InstanceID for @ResultTypeBM & 8.'
		IF @Version = '2.1.0.2158' SET @Description = 'DB-443: Modify #RoleUsers to include Users with @SecurityRoleID = -10 (Global Administrator).'
		IF @Version = '2.1.0.2163' SET @Description = 'Modified query for @ResultTypeBM = 2 to include Users with @SecurityRoleID = -10 (Global Administrator).'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-2507: Modified query for inserting users to #RoleUsers (select UI.InstanceID from [User_Instance]). Updated to latest sp template. FDB-2054: allow access for Users with SecurityRoleID = -10 (Global Administrator) and existing in InstanceID = 1 (DSPanel). FDB-2428: Modified query for @ResultTypeBM = 2 to include Users with @SecurityRoleID = -10 (Global Administrator) from InstanceID = 8 (Epicor).'

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

		SET @SecurityRoleID = ISNULL(@SecurityRoleID, -1)
		--SET @AssignedInstanceID = ISNULL(@AssignedInstanceID, @InstanceID)
		--SET @AssignedVersionID = ISNULL(@AssignedVersionID, @VersionID)

		IF @Debug <> 0 SELECT [@SecurityRoleID] = @SecurityRoleID			

	SET @Step = 'Create temp table #RoleUsers'
		IF @ResultTypeBM & 10 > 0
			BEGIN
				CREATE TABLE #RoleUsers
					(
					[InstanceID] int,
					[UserID] int,
					[UserName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[UserNameDisplay] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[UserTypeID] int,
					[UserLicenseTypeID] int
					)

				INSERT INTO #RoleUsers
					(
					[InstanceID],
					[UserID],
					[UserName],
					[UserNameDisplay],
					[UserTypeID],
					[UserLicenseTypeID]
					)
				SELECT 
					[InstanceID],
					[UserID],
					[UserName],
					[UserNameDisplay],
					[UserTypeID],
					[UserLicenseTypeID] = CASE WHEN ISNULL([UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END
				FROM 
					[pcINTEGRATOR_Data].[dbo].[User]
				WHERE 
					[InstanceID] = @InstanceID AND
					[SelectYN] <> 0 AND
					[DeletedID] IS NULL
				UNION
				SELECT 
					UI.[InstanceID],
					UI.[UserID],
					U.[UserName],
					U.[UserNameDisplay],
					U.[UserTypeID],
					[UserLicenseTypeID] = CASE WHEN ISNULL(U.[UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END
				FROM 
					[pcINTEGRATOR_Data].[dbo].[User_Instance] UI
					INNER JOIN [pcINTEGRATOR].[dbo].[User] U ON U.[UserID] = UI.[UserID] AND U.[SelectYN] <> 0 AND U.[DeletedID] IS NULL
				WHERE 
					UI.[InstanceID] = @InstanceID AND
					(UI.[ExpiryDate] > GETDATE() OR UI.[ExpiryDate] IS NULL) AND
					UI.[SelectYN] <> 0 AND
					UI.[DeletedID] IS NULL
				--Add Users with SecurityRoleID = -10 and InstanceID = 1 (DSPanel) and InstanceID = 8 (Epicor), if @SecurityRoleID = -10
				UNION 
				SELECT 
					UU.[InstanceID],
					UU.[UserID],
					UU.[UserName],
					UU.[UserNameDisplay],
					UU.[UserTypeID],
					[UserLicenseTypeID] = CASE WHEN ISNULL(UU.[UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END
				FROM 
					[pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] UU ON UU.UserID = SRU.UserID AND UU.InstanceID IN (1,8) AND UU.SelectYN <> 0 AND UU.DeletedID IS NULL
				WHERE 
					SRU.[InstanceID] IN (0, @InstanceID) AND
					SRU.[SelectYN] <> 0 AND
					SRU.[SecurityRoleID] = -10 AND
					@SecurityRoleID = -10

				IF @Debug <> 0 
					SELECT [TempTable] = '#RoleUser', * FROM #RoleUsers
			END

	SET @Step = 'List of Security Role'
		IF @ResultTypeBM & 1 > 0 
			BEGIN
				SELECT 
					[ResultTypeBM] = 1,
					[InstanceID],
					[SecurityRoleID],
					[SecurityRoleName],
					[UserLicenseTypeID] = CASE WHEN ISNULL([UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END
				FROM 
					[pcINTEGRATOR].[dbo].[SecurityRole]
				WHERE 
					[InstanceID] IN (0, @InstanceID) AND
					[SelectYN] <> 0 AND
					--[SecurityRoleID] NOT IN (-3) AND
					([SecurityRoleID] NOT IN (-10) OR @InstanceID = 0)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of Role Members'
		IF @ResultTypeBM & 2 > 0 
			BEGIN
				SELECT
					[ResultTypeBM] = 2,
					[InstanceID] = @InstanceID,
					SRU.[SecurityRoleID],
					SR.[SecurityRoleName],
					SRU.[UserID],
					RU.[UserName],
					RU.[UserNameDisplay],
					RU.[UserTypeID]
				FROM 
					[pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU
					INNER JOIN [pcINTEGRATOR].[dbo].[SecurityRole] SR ON SR.[InstanceID] IN (0, SRU.[InstanceID]) AND SR.[SecurityRoleID] = SRU.[SecurityRoleID]
					INNER JOIN #RoleUsers RU ON RU.[UserID] = SRU.[UserID]
				WHERE 
					SRU.[InstanceID] IN (0, @InstanceID) AND 
					SRU.[SecurityRoleID] = @SecurityRoleID AND
					SRU.[SelectYN] <> 0
				UNION
				SELECT
					[ResultTypeBM] = 2,
					[InstanceID] = @InstanceID,
					[SecurityRoleID] = @SecurityRoleID,
					[SecurityRoleName] = 'All Users',
					[UserID],
					[UserName],
					[UserNameDisplay],
					[UserTypeID]
				FROM
					#RoleUsers
				WHERE
					@SecurityRoleID = -3

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of enabled Features'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 4,
					[InstanceID],
					[SecurityRoleID],
					[SecurityRoleName],
					[ObjectID],
					[ObjectName]
				FROM 
					(
					SELECT DISTINCT
						SRO.[InstanceID],
						SRO.[SecurityRoleID],
						SR.[SecurityRoleName],
						SRO.[ObjectID],
						O.[ObjectName],
						O.[SortOrder]
					FROM 
						[pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO
						INNER JOIN [pcINTEGRATOR].[dbo].[SecurityRole] SR ON SR.[InstanceID] IN (0, SRO.[InstanceID]) AND SR.[SecurityRoleID] = SRO.[SecurityRoleID]
						INNER JOIN [pcINTEGRATOR].[dbo].[Object] O ON O.[InstanceID] IN (0, SRO.[InstanceID]) AND O.ObjectID = SRO.[ObjectID] AND O.[ParentObjectID] = -25 AND O.[ObjectTypeBM] & 16384 > 0 AND O.[SecurityLevelBM] & 32 > 0 AND O.[SelectYN] <> 0
					WHERE 
						SRO.[InstanceID] = @InstanceID AND
						SRO.[SecurityRoleID] = @SecurityRoleID AND
						SRO.[SelectYN] <> 0
					UNION
					SELECT DISTINCT
						[InstanceID] = @InstanceID,
						SR.[SecurityRoleID],
						SR.[SecurityRoleName],
						O.[ObjectID],
						O.[ObjectName],
						O.[SortOrder]
					FROM 
						[pcINTEGRATOR].[dbo].[SecurityRole] SR 
						INNER JOIN [pcINTEGRATOR].[dbo].[Object] O ON O.ObjectID = -26
					WHERE 
						SR.SecurityRoleID = @SecurityRoleID AND 
						@SecurityRoleID = -1
					) sub
				ORDER BY sub.[SortOrder]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of Users and Groups not set as Role Members'
		IF @ResultTypeBM & 8 > 0 
			BEGIN
				SELECT
					[ResultTypeBM] = 8,
					[InstanceID],
					[UserID],
					[UserName],
					[UserNameDisplay],
					[UserTypeID],
					[UserLicenseTypeID]
				FROM
					#RoleUsers RU
				WHERE
					@SecurityRoleID <> -3 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU WHERE SRU.[InstanceID] = RU.[InstanceID] AND SRU.[SecurityRoleID] = @SecurityRoleID AND SRU.[UserID] = RU.[UserID] AND SRU.[SelectYN] <> 0)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'List of User License Type'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 16,
					[UserLicenseTypeID],
					[UserLicenseTypeName],
					[SecurityLevelBM],
					[CallistoRestriction]
				FROM
					[pcINTEGRATOR].[dbo].[UserLicenseType]
				WHERE
					[UserLicenseTypeID] > = 0

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Full List of Features Access'
		IF @ResultTypeBM & 32 > 0 
			BEGIN
				SELECT
					[ResultTypeBM] = 32,
					[InstanceID],	
					[ObjectID], 
					[ObjectName]
				FROM 
					[pcINTEGRATOR].[dbo].[Object]
				WHERE 
					[InstanceID] IN (0, @InstanceID) AND
					[ParentObjectID] = -25 AND 
					[ObjectTypeBM] & 16384 > 0 AND 
					SelectYN <> 0
				ORDER BY 
					[SortOrder]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Full List of Callisto Actions Access'
		IF @ResultTypeBM & 64 > 0 
			BEGIN
				CREATE TABLE #Object
					(
					[InstanceID] int,
					[ObjectID] int,
					[ObjectName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[ObjectTypeBM] int,
					[ParentObjectID] int,
					[SecurityLevelBM] int,
					[InheritedFrom] int,
					[SortOrder] nvarchar(1000) COLLATE DATABASE_DEFAULT,
					[Level] int,
					[SelectYN] bit,
					[Version] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Children] int
					)

				EXEC [spPortalAdminGet_Object] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @StartNode = -104, @ReturnRowsYN = 0

				SELECT
					ObjectID = CASE WHEN O.SecurityLevelBM & 3 = 0 THEN NULL ELSE O.ObjectID END,
					O.ObjectName,
					O.[Level],
					CheckedYN = CASE WHEN O.SecurityLevelBM & 3 = 0 THEN NULL ELSE CASE WHEN SRO.SecurityLevelBM & 1 > 0 THEN 1 ELSE 0 END END
				FROM
					#Object O
					LEFT JOIN [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO ON SRO.[InstanceID] = @InstanceID AND SRO.[SecurityRoleID] = @SecurityRoleID AND SRO.ObjectID = O.ObjectID AND SRO.[SelectYN] <> 0
				ORDER BY
					[SortOrder]

				SET @Selected = @Selected + @@ROWCOUNT

				DROP TABLE #Object
			END

	SET @Step = 'Drop temp table #RoleUsers'
		IF @ResultTypeBM & 10 > 0 
			DROP TABLE #RoleUsers

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
