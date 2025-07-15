SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_User_Member]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@UserID_Group int = NULL,
	@UserID_User int = NULL,
	@EnabledYN bit = 1,
	@DeleteYN bit = 0,

	@JSON_table nvarchar(max) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000434,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_User_Member',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

--Add/Update Single User Member
EXEC [spPortalAdminSet_User_Member] @UserID=-10, @InstanceID=390, @VersionID=1011, @UserID_Group=2519, @UserID_User=6572, @EnabledYN=1, @DeleteYN=0, @Debug=1

--Delete Single User Member
EXEC [spPortalAdminSet_User_Member] @UserID=-10, @InstanceID=390, @VersionID=1011, @UserID_Group=2519, @UserID_User=6572, @DeleteYN=1, @Debug=1

--Add Multiple User Members
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_User_Member',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"-10"},
		{"TKey":"InstanceID", "TValue":"390"},
		{"TKey":"VersionID", "TValue":"1011"},
		{"TKey":"Debug", "TValue":"1"}
		]',
	@JSON_table = '
		[
		{"UserID_Group":"2404","UserID_User":"2539","EnabledYN":"1","DeleteYN":"0"},
		{"UserID_Group":"2404","UserID_User":"2541","EnabledYN":"1","DeleteYN":"0"}
		]'

--Delete Multiple User Members
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_User_Member',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"-10"},
		{"TKey":"InstanceID", "TValue":"390"},
		{"TKey":"VersionID", "TValue":"1011"},
		{"TKey":"Debug", "TValue":"1"}
		]',
	@JSON_table = '
		[
		{"UserID_Group":"2404","UserID_User":"2539","EnabledYN":"1","DeleteYN":"1"},
		{"UserID_Group":"2404","UserID_User":"2541","EnabledYN":"1","DeleteYN":"1"}
		]'

EXEC [spPortalAdminSet_User_Member] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@AssignedInstanceID int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
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
	@Version nvarchar(50) = '2.0.2.2148'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create and Delete User_Member.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-148: Added variable @AssignedInstanceID dependent on @UserID_Group.'

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

		SELECT
			@AssignedInstanceID = InstanceID
		FROM
			[User]
		WHERE
			[UserID] = @UserID_Group

	SET @Step = 'Create temp table #UserMember'
		CREATE TABLE #UserMember
			(
			InstanceID int,
			UserID_Group int,
			UserID_User int,
			EnabledYN bit,
			DeleteYN bit
			)

	SET @Step = 'Insert data into temp table #UserMember'
		IF @JSON_table IS NOT NULL
			INSERT INTO #UserMember
				(
				InstanceID,
				UserID_Group,
				UserID_User,
				EnabledYN,
				DeleteYN
				)
			SELECT
				InstanceID = @AssignedInstanceID,
				UserID_Group,
				UserID_User,
				EnabledYN,
				DeleteYN
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				UserID_Group int,
				UserID_User int,
				EnabledYN bit,
				DeleteYN bit
				)
		ELSE
			INSERT INTO #UserMember
				(
				InstanceID,
				UserID_Group,
				UserID_User,
				EnabledYN,
				DeleteYN
				)
			SELECT
				InstanceID = @AssignedInstanceID,
				UserID_Group = @UserID_Group,
				UserID_User = @UserID_User,
				EnabledYN = @EnabledYN,
				DeleteYN = @DeleteYN	
				
	SET @Step = 'Update temp table #UserMember When InstanceID IS NULL'
		UPDATE UM
		SET
			InstanceID = U.InstanceID
		FROM
			#UserMember UM
			INNER JOIN [User] U ON U.UserID = UM.UserID_Group
		WHERE
			UM.InstanceID IS NULL

		IF @Debug <> 0
			SELECT [TempTable] = '#UserMember', * FROM #UserMember	

	SET @Step = 'Update User_Member'
		BEGIN
			UPDATE UM
			SET
				[SelectYN] = temp.EnabledYN
			FROM 
				[pcINTEGRATOR_Data].[dbo].[UserMember] UM
				INNER JOIN #UserMember temp ON temp.InstanceID = UM.InstanceID AND temp.UserID_Group = UM.UserID_Group AND temp.UserID_User = UM.UserID_User AND temp.DeleteYN = 0
			
			SELECT @Updated = @Updated + @@ROWCOUNT
		END	

	SET @Step = 'Add User_Member'
		BEGIN
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserMember]
				(
				[InstanceID],
				[UserID_Group],
				[UserID_User],
				[SelectYN]
				)
			SELECT
				[InstanceID],
				[UserID_Group],
				[UserID_User],
				[SelectYN] = temp.EnabledYN
			FROM 
				#UserMember temp
			WHERE
				temp.DeleteYN = 0 AND
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserMember] UM WHERE UM.UserID_Group = temp.UserID_Group AND UM.UserID_User = temp.UserID_User)
			
			SELECT @Inserted = @Inserted + @@ROWCOUNT
		END

	SET @Step = 'Delete User_Member'
		BEGIN
			DELETE UM
			FROM 
				[pcINTEGRATOR_Data].[dbo].[UserMember] UM
				INNER JOIN #UserMember temp ON temp.InstanceID = UM.InstanceID AND temp.UserID_Group = UM.UserID_Group AND temp.UserID_User = UM.UserID_User AND temp.DeleteYN <> 0
			
			SELECT @Deleted = @Deleted + @@ROWCOUNT
		END	

	SET @Step = 'Delete temp table'
		DROP TABLE #UserMember
	
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
