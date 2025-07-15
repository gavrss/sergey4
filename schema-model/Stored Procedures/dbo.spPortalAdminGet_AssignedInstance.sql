SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_AssignedInstance]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@AssignedUserID int = NULL,
	@AssignedInstanceID int = NULL, 
	@ResultTypeBM int = 15, 
		--1 = List of Users, 
		--2 = List of Instances, 
		--4 = List of Groups,
		--8 = Check GlobalAdminYN
		--16 = List of Admin Users for all Instances
		--32 = List of Security Roles of @AssignedInstanceID
		--64 = List of Licensed Users (UserLicenseType=1) AND HomeInstance Users of @AssignedInstanceID
		--128 = List of Selected Users (Enabled=1) AND Licensed Users AND HomeInstance Users of @AssignedInstanceID
		--256 = List of HomeInstance Users (HomeInstanceYN=1) of @AssignedInstanceID

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000366,
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
	@ProcedureName = 'spPortalAdminGet_AssignedInstance',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spRun_Procedure_KeyValuePair] 
	@JSON='
		[
		{"TKey":"InstanceID","TValue":"-1134"},
		{"TKey":"AssignedInstanceID","TValue":"-1134"},
		{"TKey":"UserID","TValue":"7390"},
		{"TKey":"VersionID","TValue":"-1134"},
		{"TKey":"ResultTypeBM","TValue":"15"}
		]', 
	@ProcedureName='spPortalAdminGet_AssignedInstance'

EXEC [spPortalAdminGet_AssignedInstance] @UserID=-10, @InstanceID=0, @VersionID=0, @AssignedUserID = 6313, @AssignedInstanceID = 390
EXEC [spPortalAdminGet_AssignedInstance] @UserID=-10, @InstanceID=0, @VersionID=0, @AssignedInstanceID = 390, @ResultTypeBM = 1
EXEC [spPortalAdminGet_AssignedInstance] @UserID=-10, @InstanceID=0, @VersionID=0, @AssignedUserID = 6313, @ResultTypeBM = 2
EXEC [spPortalAdminGet_AssignedInstance] @UserID=-10, @InstanceID=0, @VersionID=0, @ResultTypeBM = 128, @AssignedInstanceID = 413

EXEC [spPortalAdminGet_AssignedInstance] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@GlobalAdminYN bit,

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
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get list of Assigned Instances for specified User',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'Added list of users. DB-90: Added column AdminYN on resultset. DB-91: Added @ResultTypeBM 8 and 16.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-140: Added [LicenseType] and [InstanceName] for @ResulTypeBM = 1 and 4.'
		IF @Version = '2.0.2.2149' SET @Description = 'DB-220: Removed users that are added in User_Instance for their Home Instance.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added @ResultTypeBM = 32 (List of SecurityRoles) for @AssignedInstanceID.'
		IF @Version = '2.1.0.2164' SET @Description = 'Additional ResultTypeBMs for Licensed, Selected, and HomeInstance Users of @AssignedInstanceID.'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-3166: Modify query for setting @GlobalAdminYN. Updated to latest SP template.'

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

		SET @GlobalAdminYN = CASE WHEN 
		(
			SELECT 
				COUNT(1) 
			FROM
			(
				SELECT DISTINCT
					SRU.UserID
				FROM
					[pcINTEGRATOR].[dbo].[@Template_SecurityRoleUser] SRU 
				WHERE 
					SRU.InstanceID = 0 AND SRU.UserID = @UserID AND SRU.SecurityRoleID = -10
				UNION
				SELECT DISTINCT
					SRU.UserID
				FROM
					[pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU 
				WHERE 
					SRU.InstanceID = 0 AND SRU.UserID = @UserID AND SRU.SecurityRoleID = -10
				UNION
				SELECT DISTINCT
					SRU.UserID
				FROM
					[pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU 
				WHERE 
					SRU.InstanceID = @InstanceID AND SRU.UserID = @UserID AND SRU.SecurityRoleID = -10
				UNION
				SELECT DISTINCT
					UM.UserID_User
				FROM 
					[pcINTEGRATOR].[dbo].[@Template_UserMember] UM 
					INNER JOIN [pcINTEGRATOR].[dbo].[@Template_SecurityRoleUser] SRU ON SRU.InstanceID = 0 AND SRU.UserID = UM.UserID_Group AND SRU.SecurityRoleID = -10
				WHERE
					UM.UserID_User = @UserID
				UNION
				SELECT DISTINCT
					UM.UserID_User
				FROM 
					[pcINTEGRATOR_Data].[dbo].[UserMember] UM 
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU ON SRU.InstanceID = 0 AND SRU.UserID = UM.UserID_Group AND SRU.SecurityRoleID = -10
				WHERE
					UM.UserID_User = @UserID
			) sub 
		) > 0 THEN 1 ELSE 0 END

		IF @Debug & 2 > 0 SELECT [@GlobalAdminYN] = @GlobalAdminYN			

	SET @Step = 'Create and Insert data into temp table #Users'
		IF @ResultTypeBM & 453 > 0
			BEGIN
				CREATE TABLE #Users
					(
					[InstanceID] int,
					[UserID] int,
					[UserName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[UserNameAD] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[UserNameDisplay] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[UserTypeID] int,
					[UserLicenseTypeID] int,
					[LocaleID] int,
					[LanguageID] int,
					[HomeInstanceYN] bit,
					[HomeInstanceID] int,
					[ExpiryDate] date,
					[SelectYN] bit,
					[DeletedID] int
					)

				INSERT INTO #Users
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
					[HomeInstanceYN],
					[HomeInstanceID],
					[ExpiryDate],
					[SelectYN],
					[DeletedID]
					)
				SELECT 
					[InstanceID],
					[UserID],
					[UserName],
					[UserNameAD],
					[UserNameDisplay],
					[UserTypeID],
					[UserLicenseTypeID] = CASE WHEN ISNULL([UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END,
					[LocaleID],
					[LanguageID],
					[HomeInstanceYN] = 1,
					[HomeInstanceID] = [InstanceID],
					[ExpiryDate] = NULL,
					[SelectYN],
					[DeletedID]
				FROM 
					[pcINTEGRATOR].[dbo].[User]
				WHERE 
					[InstanceID] = @AssignedInstanceID AND
					[DeletedID] IS NULL

				INSERT INTO #Users
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
					[HomeInstanceYN],
					[HomeInstanceID],
					[ExpiryDate],
					[SelectYN],
					[DeletedID]
					)
				SELECT 
					UI.[InstanceID],
					UI.[UserID],
					U.[UserName],
					U.[UserNameAD],
					U.[UserNameDisplay],
					U.[UserTypeID],
					[UserLicenseTypeID] = CASE WHEN ISNULL(U.[UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END,
					U.[LocaleID],
					U.[LanguageID],
					[HomeInstanceYN] = 0,
					[HomeInstanceID] = U.[InstanceID],
					UI.[ExpiryDate],
					UI.[SelectYN],
					UI.[DeletedID]
				FROM 
					[pcINTEGRATOR_Data].[dbo].[User_Instance] UI
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] U ON U.[UserID] = UI.[UserID] AND U.[DeletedID] IS NULL
				WHERE 
					UI.[InstanceID] = @AssignedInstanceID AND
					(UI.[ExpiryDate] > GETDATE() OR UI.[ExpiryDate] IS NULL) AND
					UI.[DeletedID] IS NULL AND
					NOT EXISTS (SELECT 1 FROM #Users D WHERE D.[UserID] = UI.[UserID])

				IF @Debug & 2 > 0 
					SELECT [TempTable] = '#Users', * FROM #Users
			END

	SET @Step = 'Return List of Users'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 1,
					[InstanceID] = U.[InstanceID],
					[InstanceName] = I.[InstanceName],
					[UserID] = U.[UserID],
					[DisplayName] = U.[UserNameDisplay],
					[UserName] = U.[UserName],
					[ActiveDirectoryName] = U.[UserNameAD],
					[UserLicenseTypeID] = U.[UserLicenseTypeID],
					[LicenseType] = ULT.[UserLicenseTypeName],
					[AdminYN] = CASE WHEN sub.UserID IS NULL THEN 0 ELSE 1 END,
					[EnabledYN] = U.[SelectYN],
					[HomeInstanceYN] = U.[HomeInstanceYN],
					[HomeInstanceID] = U.[HomeInstanceID],
					[ExpiryDate] = U.[ExpiryDate],
					[UserTypeID] = U.[UserTypeID]
				FROM 
					#Users U
					INNER JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID
					INNER JOIN [pcINTEGRATOR].[dbo].[UserLicenseType] ULT ON ULT.UserLicenseTypeID = U.UserLicenseTypeID
					LEFT JOIN 
						(
						SELECT DISTINCT
							U.UserID
						FROM 
							#Users U
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU ON SRU.InstanceID = @AssignedInstanceID AND SRU.UserID = U.UserID AND SRU.SecurityRoleID = -1
						UNION
						SELECT DISTINCT
							U.UserID
						FROM 
							#Users U
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[UserMember] UM ON UM.UserID_User = U.UserID
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU ON SRU.InstanceID = @AssignedInstanceID AND SRU.UserID = UM.UserID_Group AND SRU.SecurityRoleID = -1
						) sub ON sub.UserID = U.UserID					
				WHERE 
					U.[UserTypeID] = -1

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return list of assigned Instances'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 2,
					[UserID] = sub.[UserID],
					[InstanceID] = sub.[InstanceID],
					[InstanceName] = I.[InstanceName],
					[HomeInstanceYN] = sub.[HomeInstanceYN]
				FROM
					(
					SELECT
						[UserID],
						[InstanceID],
						[HomeInstanceYN] = 1
					FROM
						pcINTEGRATOR_Data..[User] U
					WHERE
						U.[UserID] = @AssignedUserID AND
						U.[DeletedID] IS NULL

					UNION SELECT
						[UserID],
						[InstanceID],
						[HomeInstanceYN] = 0
					FROM
						pcINTEGRATOR_Data..[User_Instance] UI
					WHERE
						UserID = @AssignedUserID AND
						(UI.[ExpiryDate] > GETDATE() OR UI.[ExpiryDate] IS NULL) AND
						UI.[DeletedID] IS NULL
					) sub
					INNER JOIN pcINTEGRATOR_Data..[Instance] I ON I.[InstanceID] = sub.[InstanceID]

				ORDER BY
					[HomeInstanceYN] DESC,
					InstanceID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return List of Groups'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 4,
					[InstanceID] = U.[InstanceID],
					[InstanceName] = I.[InstanceName],
					[UserID] = U.[UserID],
					[DisplayName] = U.[UserNameDisplay],
					[UserName] = U.[UserName],
					[ActiveDirectoryName] = U.[UserNameAD],
					[UserLicenseTypeID] = U.[UserLicenseTypeID],
					[LicenseType] = ULT.[UserLicenseTypeName],
					[AdminYN] = CASE WHEN sub.UserID IS NULL THEN 0 ELSE 1 END,
					[EnabledYN] = U.[SelectYN],
					[HomeInstanceYN] = U.[HomeInstanceYN],
					[HomeInstanceID] = U.[HomeInstanceID],
					[ExpiryDate] = U.[ExpiryDate],
					[UserTypeID] = U.[UserTypeID]
				FROM 
					#Users U
					INNER JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID
					INNER JOIN [pcINTEGRATOR].[dbo].[UserLicenseType] ULT ON ULT.UserLicenseTypeID = U.UserLicenseTypeID
					LEFT JOIN 
						(
						SELECT DISTINCT
							U.UserID
						FROM 
							#Users U
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU ON SRU.InstanceID = @AssignedInstanceID AND SRU.UserID = U.UserID AND SRU.SecurityRoleID = -1
						) sub ON sub.UserID = U.UserID					
				WHERE 
					U.[UserTypeID] = -2

				SET @Selected = @Selected + @@ROWCOUNT
			END
	
	SET @Step = 'Return @GlobalAdminYN'
		IF @ResultTypeBM & 8 > 0
			SELECT 
				[ResultTypeBM] = 8,
				[UserID] = @UserID,
				[GlobalAdminYN] = @GlobalAdminYN

	SET @Step = 'Return List of Admin Users for all Instances'
		IF @ResultTypeBM & 16 > 0 AND @GlobalAdminYN <> 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 16,
					[InstanceID] = I.[InstanceID],
					[InstanceName] = I.[InstanceName],
					[InstanceDescription] = I.[InstanceDescription],
					[UserID] = sub1.[UserID],
					[UserName] = sub1.[UserName],
					[DisplayName] = sub1.[UserNameDisplay]
				FROM 
					[pcINTEGRATOR_Data].[dbo].[Instance] I
					INNER JOIN
						(
						SELECT
							[InstanceID],
							[UserID],
							[UserName],
							[UserNameDisplay]
						FROM
							[pcINTEGRATOR_Data].[dbo].[User]
						WHERE 
							[UserTypeID] = -1 AND
							[SelectYN] <> 0 AND
							[DeletedID] IS NULL
						UNION
						SELECT
							UI.[InstanceID],
							UI.[UserID],
							U.[UserName],
							U.[UserNameDisplay] 
						FROM 
							[pcINTEGRATOR_Data].[dbo].[User_Instance] UI
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] U ON U.[UserID] = UI.[UserID] AND U.[SelectYN] <> 0 AND U.[DeletedID] IS NULL AND U.[UserTypeID] = -1
						WHERE 
							UI.SelectYN <> 0 AND 
							(UI.[ExpiryDate] > GETDATE() OR UI.[ExpiryDate] IS NULL) AND
							UI.[DeletedID] IS NULL
						) sub1 ON sub1.InstanceID = I.InstanceID
					INNER JOIN 
						(
						SELECT DISTINCT
							InstanceID,
							UserID
						FROM 
							[pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU 
						WHERE
							SecurityRoleID = -1
						UNION
						SELECT
							UM.InstanceID,
							UM.UserID_User
						FROM
							[pcINTEGRATOR_Data].[dbo].[UserMember] UM 
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU ON SRU.UserID = UM.UserID_Group AND SRU.SecurityRoleID = -1
						) sub2 ON sub2.UserID = sub1.UserID AND sub2.InstanceID = I.InstanceID
				WHERE
					I.[SelectYN] <> 0
				ORDER BY
					I.InstanceDescription

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return List of SecurityRoles'
		IF @ResultTypeBM & 32 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 32,
					[InstanceID] = @AssignedInstanceID,
					[SecurityRoleID],
					[SecurityRoleName],
					[UserLicenseTypeID] = CASE WHEN ISNULL([UserLicenseTypeID], 0) = 0 THEN 0 ELSE 1 END
				FROM 
					[pcINTEGRATOR].[dbo].[SecurityRole]
				WHERE 
					[InstanceID] IN (0, @AssignedInstanceID) AND
					[SelectYN] <> 0 AND
					([SecurityRoleID] NOT IN (-10) OR @AssignedInstanceID = 0) AND
                    @AssignedInstanceID IS NOT NULL

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return List of Licensed Users (AND HomeInstance Users) of @AssignedInstanceID'
		IF @ResultTypeBM & 64 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 64,
					[InstanceID] = U.[InstanceID],
					[InstanceName] = I.[InstanceName],
					[UserID] = U.[UserID],
					[DisplayName] = U.[UserNameDisplay],
					[UserName] = U.[UserName],
					[ActiveDirectoryName] = U.[UserNameAD],
					[UserLicenseTypeID] = U.[UserLicenseTypeID],
					[LicenseType] = ULT.[UserLicenseTypeName],
					[EnabledYN] = U.[SelectYN],
					[HomeInstanceYN] = U.[HomeInstanceYN],
					[HomeInstanceID] = U.[HomeInstanceID],
					[ExpiryDate] = U.[ExpiryDate],
					[UserTypeID] = U.[UserTypeID]
				FROM 
					#Users U
					INNER JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID
					INNER JOIN [pcINTEGRATOR].[dbo].[UserLicenseType] ULT ON ULT.UserLicenseTypeID = U.UserLicenseTypeID				
				WHERE 
					U.[UserTypeID] = -1 AND
					U.[UserLicenseTypeID] = 1 AND
					U.[HomeInstanceYN] = 1

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return List of Selected Users (AND Licensed Users AND HomeInstance Users) of @AssignedInstanceID'
		IF @ResultTypeBM & 128 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 128,
					[InstanceID] = U.[InstanceID],
					[InstanceName] = I.[InstanceName],
					[UserID] = U.[UserID],
					[DisplayName] = U.[UserNameDisplay],
					[UserName] = U.[UserName],
					[ActiveDirectoryName] = U.[UserNameAD],
					[UserLicenseTypeID] = U.[UserLicenseTypeID],
					[LicenseType] = ULT.[UserLicenseTypeName],
					[EnabledYN] = U.[SelectYN],
					[HomeInstanceYN] = U.[HomeInstanceYN],
					[HomeInstanceID] = U.[HomeInstanceID],
					[ExpiryDate] = U.[ExpiryDate],
					[UserTypeID] = U.[UserTypeID]
				FROM 
					#Users U
					INNER JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID	
					INNER JOIN [pcINTEGRATOR].[dbo].[UserLicenseType] ULT ON ULT.UserLicenseTypeID = U.UserLicenseTypeID
				WHERE 
					U.[UserTypeID] = -1 AND
					U.[SelectYN] = 1 AND
					U.[UserLicenseTypeID] = 1 AND
					U.[HomeInstanceYN] = 1

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return List of HomeInstance Users of @AssignedInstanceID'
		IF @ResultTypeBM & 256 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 256,
					[InstanceID] = U.[InstanceID],
					[InstanceName] = I.[InstanceName],
					[UserID] = U.[UserID],
					[DisplayName] = U.[UserNameDisplay],
					[UserName] = U.[UserName],
					[ActiveDirectoryName] = U.[UserNameAD],
					[UserLicenseTypeID] = U.[UserLicenseTypeID],
					[LicenseType] = ULT.[UserLicenseTypeName],
					[EnabledYN] = U.[SelectYN],
					[HomeInstanceYN] = U.[HomeInstanceYN],
					[HomeInstanceID] = U.[HomeInstanceID],
					[ExpiryDate] = U.[ExpiryDate],
					[UserTypeID] = U.[UserTypeID]
				FROM 
					#Users U
					INNER JOIN [pcINTEGRATOR].[dbo].[Instance] I ON I.InstanceID = U.InstanceID	
					INNER JOIN [pcINTEGRATOR].[dbo].[UserLicenseType] ULT ON ULT.UserLicenseTypeID = U.UserLicenseTypeID
				WHERE 
					U.[UserTypeID] = -1 AND
					U.[HomeInstanceYN] = 1

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop Temp tables'
		IF @ResultTypeBM & 1 > 0 DROP TABLE #Users

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
