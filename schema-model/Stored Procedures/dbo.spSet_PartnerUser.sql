SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_PartnerUser]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@AssignedUserID int = NULL,
	@AssignedInstanceID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000525,
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
EXEC [spSet_PartnerUser] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedUserID = 9625, @AssignedInstanceID = 1, @DebugBM = 2
EXEC [spSet_PartnerUser] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedUserID = 12543, @AssignedInstanceID = 1, @DebugBM = 2

EXEC [spSet_PartnerUser] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@PartnerUserLastUpdate datetime,
	@CountRows int,
	@InsertedUserID int,
	@IdentityCheck int,

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
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Update user info for partner users on pcINTEGRATOR_Master',
			@MandatoryParameter = 'AssignedUserID|AssignedInstanceID' --Without @, separated by |

		IF @Version = '2.0.3.2151' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2152' SET @Description = 'Create temp table #UserPropertyValue before insert.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set ProcedureID in JobLog.'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-1808: Use linked server [DSPMASTER_Primary] for Write-Access transactions and [DSPMASTER] for Read-Access.'

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

	SET @Step = 'Check if partner user'
		IF (SELECT COUNT(1) FROM Instance I INNER JOIN Customer C ON C.CustomerID = I.CustomerID AND C.CompanyTypeID = 1 WHERE I.InstanceID = @AssignedInstanceID) = 0
			BEGIN
				SET @Message = 'Nothing to update'
				SET @Severity = 0
				GOTO EXITPOINT
			END

	SET @Step = 'Create temp table #UserPropertyValue'
		CREATE TABLE #UserPropertyValue
			(
			[InstanceID] int,
			[UserID] int,
			[UserPropertyTypeID] int,
			[UserPropertyValue] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SelectYN] bit,
			[InheritedFrom] int
			)

	SET @Step = 'Fill temp tables'
		SELECT * INTO #User FROM pcINTEGRATOR_Data.dbo.[User] WHERE InstanceID = @AssignedInstanceID AND UserID = @AssignedUserID
		INSERT INTO #UserPropertyValue
			(
			[InstanceID],
			[UserID],
			[UserPropertyTypeID],
			[UserPropertyValue],
			[SelectYN],
			[InheritedFrom]
			)
		SELECT 
			UPV.[InstanceID],
			UPV.[UserID],
			UPV.[UserPropertyTypeID],
			UPV.[UserPropertyValue],
			UPV.[SelectYN],
			U.[InheritedFrom]
		FROM
			pcINTEGRATOR_Data.dbo.[UserPropertyValue] UPV 
			INNER JOIN #User U ON U.UserID = UPV.UserID
		WHERE
			UPV.InstanceID = @AssignedInstanceID AND 
			UPV.UserID = @AssignedUserID

		IF @DebugBM & 2 > 0
			BEGIN
				SELECT TempTable = '#User', * FROM #User
				SELECT TempTable = '#UserPropertyValue', * FROM #UserPropertyValue
			END

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
			--DSPMASTER.pcINTEGRATOR_Master.dbo.[User] U
			[DSPMASTER_Primary].[pcINTEGRATOR_Master].[dbo].[User] U
			INNER JOIN #User S ON S.UserName = U.UserName AND
				(
				U.[InstanceID] <> S.[InstanceID] OR
				U.[UserNameAD] <> S.[UserNameAD] OR
				U.[UserNameDisplay] <> S.[UserNameDisplay] OR
				U.[UserTypeID] <> S.[UserTypeID] OR
				U.[UserLicenseTypeID] <> S.[UserLicenseTypeID] OR
				U.[LocaleID] <> S.[LocaleID] OR
				U.[LanguageID] <> S.[LanguageID] OR
				U.[ObjectGuiBehaviorBM] <> S.[ObjectGuiBehaviorBM] OR
				U.[InheritedFrom] <> S.[UserID] OR
				U.[SelectYN] <> S.[SelectYN] OR
				U.[DeletedID] <> S.[DeletedID]
				)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert into User'
		SET @IdentityCheck = @@IDENTITY

		--INSERT INTO DSPMASTER.pcINTEGRATOR_Master.dbo.[User]
		INSERT INTO [DSPMASTER_Primary].[pcINTEGRATOR_Master].[dbo].[User]
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
			NOT EXISTS (SELECT 1 FROM [DSPMASTER_Primary].[pcINTEGRATOR_Master].[dbo].[User] D WHERE D.[UserName] = S.[UserName] AND D.[DeletedID] IS NULL)
			--NOT EXISTS (SELECT 1 FROM DSPMASTER.pcINTEGRATOR_Master.dbo.[User] D WHERE D.[UserName] = S.[UserName] AND D.[DeletedID] IS NULL)

		SET @Inserted = @Inserted + @@ROWCOUNT

		IF @Inserted > 0
			SELECT @InsertedUserID = U.UserID
			FROM
				--DSPMASTER.pcINTEGRATOR_Master.dbo.[User] U
				[DSPMASTER_Primary].[pcINTEGRATOR_Master].[dbo].[User] U
				INNER JOIN #User S ON S.InstanceID = U.InstanceID AND S.UserName = U.UserName

--			@InsertedUserID = ident_current('DSPMASTER.pcINTEGRATOR_Master.dbo.[User]')
--			@InsertedUserID = @@IDENTITY

		IF @DebugBM & 2 > 0 SELECT [@Inserted] = @Inserted, [@InsertedUserID] = @InsertedUserID

		IF ISNULL(@IdentityCheck, 0) <> @InsertedUserID AND @InsertedUserID IS NOT NULL
			BEGIN
				UPDATE U
				SET
					InheritedFrom = @InsertedUserID
				FROM
					[#User] U
				WHERE
					U.InstanceID = @AssignedInstanceID AND
					U.UserID = @AssignedUserID

				UPDATE UPV
				SET
					InheritedFrom = @InsertedUserID
				FROM
					[#UserPropertyValue] UPV
				WHERE
					UPV.InstanceID = @AssignedInstanceID AND
					UPV.UserID = @AssignedUserID

				UPDATE U
				SET
					InheritedFrom = @InsertedUserID
				FROM
					pcINTEGRATOR_Data..[User] U
				WHERE
					U.InstanceID = @AssignedInstanceID AND
					U.UserID = @AssignedUserID

				IF @DebugBM & 2 > 0 SELECT TempTable = '#UserPropertyValue', * FROM #UserPropertyValue 

			END
--/*
	SET @Step = 'Update UserPropertyValue'
		UPDATE UPV
		SET 
			[InstanceID] = S.[InstanceID],
			[UserPropertyValue] = S.[UserPropertyValue],
			[SelectYN] = S.[SelectYN]
		FROM 
			--DSPMASTER.pcINTEGRATOR_Master.dbo.[UserPropertyValue] UPV
			[DSPMASTER_Primary].[pcINTEGRATOR_Master].[dbo].[UserPropertyValue] UPV
			INNER JOIN [#UserPropertyValue] S ON S.InheritedFrom = UPV.UserID AND S.[UserPropertyTypeID] = UPV.UserPropertyTypeID AND
				(
				UPV.[InstanceID] <> S.[InstanceID] OR
				UPV.[UserPropertyValue] <> S.[UserPropertyValue] OR
				UPV.[SelectYN] <> S.[SelectYN]
				)

		SET @Updated = @Updated + @@ROWCOUNT
--*/

	SET @Step = 'Insert into UserPropertyValue'
		--INSERT INTO DSPMASTER.pcINTEGRATOR_Master.dbo.[UserPropertyValue]
		INSERT INTO [DSPMASTER_Primary].[pcINTEGRATOR_Master].[dbo].[UserPropertyValue]
			(
			[InstanceID],
			[UserID],
			[UserPropertyTypeID],
			[UserPropertyValue],
			[SelectYN]
			)
		SELECT 
			S.[InstanceID],
			U.[InheritedFrom],
			S.[UserPropertyTypeID],
			S.[UserPropertyValue],
			S.[SelectYN]
		FROM 
			[#UserPropertyValue] S
			INNER JOIN [User] U ON U.InstanceID = S.InstanceID AND U.UserID = S.UserID
		WHERE
			NOT EXISTS (SELECT 1 FROM [DSPMASTER_Primary].[pcINTEGRATOR_Master].[dbo].[UserPropertyValue] D WHERE D.UserID = U.[InheritedFrom] AND D.[UserPropertyTypeID] = S.[UserPropertyTypeID])
			--NOT EXISTS (SELECT 1 FROM DSPMASTER.pcINTEGRATOR_Master.dbo.[UserPropertyValue] D WHERE D.UserID = U.[InheritedFrom] AND D.[UserPropertyTypeID] = S.[UserPropertyTypeID])

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Drop temp tables'
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
