SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_User_PW]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@AssignedUserID int = NULL,
	@AssignedUserPW nvarchar(100) = NULL, 
	@JSON_table nvarchar(max) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000436,
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
	@ProcedureName = 'spPortalAdminSet_User_PW',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminSet_User_PW] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedUserID=6573, @AssignedUserPW='testpww', @Debug=1
EXEC [spPortalAdminSet_User_PW] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedUserID=2538, @AssignedUserPW='testpww', @Debug=1

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_User_PW',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"-10"},
		{"TKey":"InstanceID", "TValue":"390"},
		{"TKey":"VersionID", "TValue":"1011"},
		{"TKey":"Debug", "TValue":"1"}
		]',
	@JSON_table = '
		[
		{"AssignedUserID":"6573","AssignedUserPW":"TEST2539"},
		{"AssignedUserID":"2540","AssignedUserPW":"TEST2539"}
		]'

EXEC [spPortalAdminSet_User_PW] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@UserPropertyTypeID int = -1001,
	@AssignedInstanceID int,

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.3.2152'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Update User Password',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Added variable @AssignedInstanceID.'
		IF @Version = '2.0.3.2151' SET @Description = 'Set master database. Temporarily disabled call to [spSet_PartnerUser].'
		IF @Version = '2.0.3.2152' SET @Description = 'Enhanced debugging.'

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
			@AssignedInstanceID = [InstanceID]
		FROM
			[User]
		WHERE
			[UserID] = @AssignedUserID

	SET @Step = 'Create temp table #PW'
		CREATE TABLE #PW
			(
			UserID int,
			UserPropertyTypeID int,
			UserPropertyValue nvarchar(100) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Insert data into temp table #PW'
		IF @JSON_table IS NOT NULL
			INSERT INTO #PW
				(
				UserID,
				UserPropertyTypeID,
				UserPropertyValue
				)
			SELECT
				UserID = AssignedUserID,
				UserPropertyTypeID = @UserPropertyTypeID,
				UserPropertyValue = AssignedUserPW
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				AssignedUserID int,
				AssignedUserPW nvarchar(100) COLLATE DATABASE_DEFAULT
				)
		ELSE
			INSERT INTO #PW
				(
				UserID,
				UserPropertyTypeID,
				UserPropertyValue
				)
			SELECT
				UserID = @AssignedUserID,
				UserPropertyTypeID = @UserPropertyTypeID,
				UserPropertyValue = @AssignedUserPW	
				
		IF @Debug <> 0
			SELECT [TempTable] = '#PW', * FROM #PW		

	SET @Step = 'Update User Password'
		UPDATE UPV
		SET
			[InstanceID] = @AssignedInstanceID,
			[UserPropertyValue] = PW.UserPropertyValue
		FROM
			[pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV
			INNER JOIN #PW PW ON PW.UserID = UPV.UserID AND PW.UserPropertyTypeID = UPV.UserPropertyTypeID
		WHERE
			UPV.[UserPropertyTypeID] = @UserPropertyTypeID AND 
			UPV.[SelectYN] <> 0
					
		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert User Password'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserPropertyValue]
			(
			[InstanceID],
			[UserID],
			[UserPropertyTypeID],
			[UserPropertyValue],
			[SelectYN]
			)
		SELECT	
			[InstanceID] = @AssignedInstanceID,
			[UserID],
			[UserPropertyTypeID],
			[UserPropertyValue],
			[SelectYN] = 1
		FROM
			#PW PW
		WHERE
            NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserPropertyValue] UPV WHERE UPV.[InstanceID] = @AssignedInstanceID AND UPV.UserID = PW.UserID AND UPV.UserPropertyTypeID = PW.UserPropertyTypeID)
					
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update master database'
		SET ANSI_NULLS ON; SET ANSI_WARNINGS ON; EXEC [spSet_PartnerUser] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @AssignedUserID = @AssignedUserID, @AssignedInstanceID = @AssignedInstanceID, @Debug = @DebugSub
		SET ANSI_WARNINGS OFF

	SET @Step = 'Delete temp table'
		DROP TABLE #PW

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
