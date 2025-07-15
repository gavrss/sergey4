SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_UserConversion]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@CheckYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000512,
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
Instruction: 
1. Run EXEC [sp_Tool_UserConversion] @CheckYN = 1
2. Make sure that there are no rows where UserID IS NULL in temp table #UserConversion before running with Parameter @CheckYN = 0
3. Run EXEC [sp_Tool_UserConversion] @CheckYN = 0

EXEC [sp_Tool_UserConversion] @CheckYN = 0

EXEC [sp_Tool_UserConversion] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

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
	@Version nvarchar(50) = '2.0.2.2148'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Convert duplicated users to new UserID and add unique index for UserName on table User',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created. Modified LEFT JOIN for #HomeInstance creation.'

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

	SET @Step = 'Check status'
		SELECT
			U.*
		FROM
			[pcINTEGRATOR_Data].[dbo].[User] U
			INNER JOIN (
				SELECT 
					[UserName]
				FROM
					[pcINTEGRATOR_Data].[dbo].[User]
				WHERE
					UserTypeID = -1 AND
					[DeletedID] IS NULL
				GROUP BY
					[UserName]
				HAVING COUNT(1) > 1
				) sub ON sub.UserName = U.userName
		WHERE
			U.UserTypeID = -1 AND
			U.[DeletedID] IS NULL
		ORDER BY
			U.UserName,
			U.InstanceID

		--SELECT t.* FROM sys.tables t INNER JOIN sys.columns c ON c.object_id = t.object_id and c.name = 'UserID'

		SELECT
			[InstanceID] = ISNULL(MAX(I.InstanceID), 390),
			[UserID] = MAX(CASE WHEN I.InstanceID IS NOT NULL THEN U.UserID ELSE NULL END),
			[UserName],
			[Rows#] = COUNT(1)
		INTO
			#HomeInstance
		FROM
			[pcINTEGRATOR_Data].[dbo].[User] U
			LEFT JOIN (SELECT InstanceID FROM [pcINTEGRATOR_Data].[dbo].[Instance] I INNER JOIN [pcINTEGRATOR_Data].[dbo].[Customer] C ON C.CustomerID = I.CustomerID AND (C.CompanyTypeID = 1 OR I.InstanceID = 390)) I ON I.InstanceID = U.InstanceID
		WHERE
			U.UserTypeID = -1 AND
			U.[DeletedID] IS NULL
		GROUP BY
			[UserName]
		HAVING
			COUNT(1) > 1

		IF @Debug <> 0 SELECT TempTable = '#HomeInstance', * FROM #HomeInstance
		
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
			[SelectYN]
			)
		SELECT
			[InstanceID] = HI.InstanceID,
			[UserName] = HI.UserName,
			[UserNameAD] = MAX(U.[UserNameAD]),
			[UserNameDisplay] = MAX(U.[UserNameDisplay]),
			[UserTypeID] = MAX(U.[UserTypeID]),
			[UserLicenseTypeID] = MAX(U.[UserLicenseTypeID]),
			[LocaleID] = MAX(U.[LocaleID]),
			[LanguageID] = MAX(U.[LanguageID]),
			[ObjectGuiBehaviorBM] = MAX(U.[ObjectGuiBehaviorBM]),
			[InheritedFrom] = MAX(U.[InheritedFrom]),
			[SelectYN] = MAX(CONVERT(int, U.[SelectYN]))
		FROM
			[pcINTEGRATOR_Data].[dbo].[User] U
			INNER JOIN #HomeInstance HI ON HI.UserName = U.UserName AND HI.InstanceID = 390 AND HI.UserID IS NULL
		WHERE
			U.DeletedID IS NULL AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User] D WHERE D.[InstanceID] = HI.InstanceID AND D.[UserName] = HI.UserName AND D.[DeletedID] IS NULL)
		GROUP BY
			HI.InstanceID,
			HI.UserName

		SET @Inserted = @Inserted + @@ROWCOUNT

		SELECT
			HI.*,
			OldInstanceID = U.InstanceID,
			OldUserID = U.UserID
		INTO
			#UserConversion
		FROM
			#HomeInstance HI
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[User] U ON U.UserTypeID = -1 AND U.UserName = HI.UserName AND U.InstanceID <> HI.InstanceID

		SELECT TempTable = '#UserConversion', * FROM #UserConversion ORDER BY InstanceID, UserName
		SET @Selected = @Selected + @@ROWCOUNT

		IF @CheckYN <> 0
			BEGIN
				SET @Message = 'Set @CheckYN to 0 to update tables.'
				SET @Severity = 0
				GOTO EXITPOINT
			END

	SET @Step = 'Add new rows into UserPropertyValue'
		--[UserPropertyValue]
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserPropertyValue]
			(
			[InstanceID],
			[UserID],
			[UserPropertyTypeID],
			[UserPropertyValue],
			[SelectYN]
			)
		SELECT
			[InstanceID] = MAX(UC.InstanceID),
			[UserID] = UC.UserID,
			[UserPropertyTypeID] = UPV.UserPropertyTypeID,
			[UserPropertyValue] = MAX(UPV.UserPropertyValue),
			[SelectYN] = MAX(CONVERT(int, UPV.SelectYN))
		FROM
			[pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV
			INNER JOIN #UserConversion UC ON UC.OldUserID = UPV.UserID
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] D WHERE D.[UserID] = UC.UserID AND D.[UserPropertyTypeID] = UPV.UserPropertyTypeID)
		GROUP BY
			UC.UserID,
			UPV.UserPropertyTypeID

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Add new rows into User_Instance, Step 1'
		--[User_Instance]
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[User_Instance]
			(
			InstanceID,
			UserID
			)
		SELECT
			InstanceID = UI.InstanceID,
			UserID = UC.UserID
		FROM
			[pcINTEGRATOR_Data].[dbo].[User_Instance] UI
			INNER JOIN #UserConversion UC ON UC.OldUserID = UI.UserID
		WHERE
			NOT EXISTS(SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User_Instance] D WHERE D.InstanceID = UI.InstanceID AND D.UserID = UC.UserID)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Add new rows into User_Instance, Step 2'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[User_Instance]
			(
			InstanceID,
			UserID
			)
		SELECT DISTINCT
			InstanceID = UC.OldInstanceID,
			UserID = UC.UserID
		FROM
			#UserConversion UC
		WHERE
			NOT EXISTS(SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User_Instance] D WHERE D.InstanceID = UC.OldInstanceID AND D.UserID = UC.UserID)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Add new rows into UserMember'
		--[UserMember]
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserMember]
			(
			InstanceID,
			UserID_Group,
			UserID_User,
			SelectYN
			)
		SELECT
			InstanceID = MAX(UM.InstanceID),
			UserID_Group = UM.UserID_Group,
			UserID_User = UC.UserID,
			SelectYN = MAX(CONVERT(int, UM.SelectYN))
		FROM
			[pcINTEGRATOR_Data].[dbo].[UserMember] UM
			INNER JOIN #UserConversion UC ON UC.OldUserID = UM.UserID_User
		WHERE
			NOT EXISTS(SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserMember] D WHERE D.UserID_Group = UM.UserID_Group AND D.UserID_User = UC.UserID)
		GROUP BY
			UM.UserID_Group,
			UC.UserID

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Add new rows into SecurityRoleUser'
		--[SecurityRoleUser]
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser]
			(
			[InstanceID],
			[SecurityRoleID],
			[UserID],
			[SelectYN]
			)
		SELECT
			[InstanceID] = SRU.[InstanceID],
			[SecurityRoleID] = SRU.[SecurityRoleID],
			[UserID] = UC.[UserID],
			[SelectYN] = MAX(CONVERT(int, SRU.[SelectYN]))
		FROM
			[pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU
			INNER JOIN #UserConversion UC ON UC.OldUserID = SRU.UserID
		WHERE
			NOT EXISTS(SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] D WHERE D.[InstanceID] = SRU.[InstanceID] AND D.[SecurityRoleID] = SRU.[SecurityRoleID] AND D.[UserID] = UC.[UserID])
		GROUP BY
			SRU.[InstanceID],
			SRU.[SecurityRoleID],
			UC.[UserID]

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Add new rows into OrganizationPosition_User'
		--[OrganizationPosition_User]
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User]
			(
			[InstanceID],
			[VersionID],
			[OrganizationPositionID],
			[UserID],
			[DelegateYN],
			[Comment],
			[DeletedID]
			)
		SELECT
			[InstanceID] = MAX(OPU.[InstanceID]),
			[VersionID] = MAX(OPU.[VersionID]),
			[OrganizationPositionID] = OPU.[OrganizationPositionID],
			[UserID] = UC.[UserID],
			[DelegateYN] = MAX(CONVERT(int, OPU.[DelegateYN])),
			[Comment] = MAX(OPU.[Comment]),
			[DeletedID] = MAX(OPU.[DeletedID])
		FROM
			[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU
			INNER JOIN #UserConversion UC ON UC.OldUserID = OPU.UserID
		WHERE
			NOT EXISTS(SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] D WHERE D.[OrganizationPositionID] = OPU.[OrganizationPositionID] AND D.[UserID] = UC.[UserID])
		GROUP BY
			OPU.[OrganizationPositionID],
			UC.[UserID]

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update rows in DeletedItem'
		--[DeletedItem]
		UPDATE DI
		SET
			[UserID] = UC.UserID
		FROM
			[pcINTEGRATOR_Data].[dbo].[DeletedItem] DI
			INNER JOIN #UserConversion UC ON UC.OldUserID = DI.UserID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Delete old rows from UserPropertyValue'
		--[UserPropertyValue]
		DELETE UPV
		FROM
			[pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV
			INNER JOIN #UserConversion UC ON UC.OldUserID = UPV.UserID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete old rows from User_Instance'
		--[User_Instance]
		DELETE UI
		FROM
			[pcINTEGRATOR_Data].[dbo].[User_Instance] UI
			INNER JOIN #UserConversion UC ON UC.OldUserID = UI.UserID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete old rows from UserMember'
		--[UserMember]
		DELETE UM
		FROM
			[pcINTEGRATOR_Data].[dbo].[UserMember] UM
			INNER JOIN #UserConversion UC ON UC.OldUserID = UM.UserID_User

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete old rows from SecurityRoleUser'
		--[SecurityRoleUser]
		DELETE SRU
		FROM
			[pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU
			INNER JOIN #UserConversion UC ON UC.OldUserID = SRU.UserID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete old rows from OrganizationPosition_User'
		--[OrganizationPosition_User]
		DELETE OPU
		FROM
			[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User] OPU
			INNER JOIN #UserConversion UC ON UC.OldUserID = OPU.UserID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Delete old rows from User'
		--[User]
		DELETE U
		FROM
			[pcINTEGRATOR_Data].[dbo].[User] U
			INNER JOIN #UserConversion UC ON UC.OldUserID = U.UserID

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Create unique index for UserName on table User'
		IF
			(
			SELECT
				COUNT(1) 
			FROM
				[pcINTEGRATOR_Data].[sys].[indexes] 
			WHERE
				[name]='IX_UserName' AND
				object_id = OBJECT_ID('pcINTEGRATOR_Data.dbo.User')
			) > 0
				BEGIN
					EXEC [pcINTEGRATOR_Data].[dbo].[sp_executesql] N'DROP INDEX [dbo].[User].[IX_UserName]'

					CREATE UNIQUE NONCLUSTERED INDEX [IX_UserName] ON [pcINTEGRATOR_Data].[dbo].[User]
						(
						[UserName] ASC,
						[DeletedID] ASC
						)
						WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
				END

	SET @Step = 'Drop temp tables'
		DROP TABLE #HomeInstance
		DROP TABLE #UserConversion

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
