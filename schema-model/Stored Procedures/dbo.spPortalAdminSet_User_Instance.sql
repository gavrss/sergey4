SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_User_Instance]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@AssignedInstanceID int = NULL, --Mandatory
	@AssignedUserID int = NULL, --Mandatory
	@AssignedUserID_Group int = NULL,
	@ExpiryDate date = NULL,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000369,
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
	@ProcedureName = 'spPortalAdminSet_User_Instance',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminSet_User_Instance] @UserID=-10, @InstanceID=390, @VersionID=1011, @AssignedUserID=2541, @Debug=1

EXEC [spPortalAdminSet_User_Instance] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DeletedID int,

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2163'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Add or delete user from Instance',
			@MandatoryParameter = 'AssignedInstanceID|AssignedUserID' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Set Default Group for the specified User to Assigned Instance.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-350: Possibility to assign Instances logically deleted fom User_Instance table.'
		IF @Version = '2.1.0.2163' SET @Description = 'Enhanced debugging.'

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

	SET @Step = 'Add User to Instance'
		IF @DeleteYN = 0
			BEGIN
				DELETE [UI]
				FROM
					[pcINTEGRATOR_Data].[dbo].[User_Instance] [UI]
				WHERE
					[UI].[InstanceID] = @AssignedInstanceID AND
					[UI].[UserID] = @AssignedUserID AND
					[UI].DeletedID IS NOT NULL

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[User_Instance]
					(
					[InstanceID],
					[UserID],
					[ExpiryDate],
					[Inserted],
					[InsertedBy]
					)
				SELECT
					[InstanceID] = @AssignedInstanceID,
					[UserID] = @AssignedUserID,
					[ExpiryDate] = @ExpiryDate,
					[Inserted] = GetDate(),
					[InsertedBy] = @UserID
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[User_Instance] UI WHERE UI.[InstanceID] = @AssignedInstanceID AND UI.[UserID] = @AssignedUserID)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Add Default Group to Assigned User'
		IF @DeleteYN = 0 AND @AssignedUserID_Group IS NOT NULL
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[UserMember]
					(
					[InstanceID],
					[UserID_Group],
					[UserID_User],
					[SelectYN]
					)
				SELECT
					[InstanceID] = @AssignedInstanceID,
					[UserID_Group] = @AssignedUserID_Group,
					[UserID_User] = @AssignedUserID,
					[SelectYN] = 1
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[UserMember] WHERE InstanceID = @AssignedInstanceID AND UserID_Group = @AssignedUserID_Group AND UserID_User = @AssignedUserID)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Delete Group of Assigned User'
		IF @DeleteYN <> 0 AND @AssignedUserID_Group IS NOT NULL
			BEGIN
				DELETE UM
				FROM 
					[pcINTEGRATOR_Data].[dbo].[UserMember] UM
				WHERE
					[InstanceID] = @AssignedInstanceID AND
					[UserID_Group] = @AssignedUserID_Group AND
					[UserID_User] = @AssignedUserID
			
				SELECT @Deleted = @Deleted + @@ROWCOUNT
			END	

	SET @Step = 'Delete/Unassign User from Instance'
		IF @DeleteYN <> 0
			BEGIN
				IF (SELECT COUNT(1) FROM [pcINTEGRATOR_Data].[dbo].[User_Instance] WHERE [InstanceID] = @AssignedInstanceID AND [UserID] = @AssignedUserID) = 1
					BEGIN
						EXEC [spGet_DeletedItem] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @TableName = 'User_Instance', @DeletedID = @DeletedID OUT, @JobID = @JobID, @Debug = @DebugSub
				
						UPDATE [pcINTEGRATOR_Data].[dbo].[User_Instance]
						SET
							DeletedID = @Deleted
						WHERE
							[InstanceID] = @AssignedInstanceID AND
							[UserID] = @AssignedUserID

						SET @Deleted = @Deleted + @@ROWCOUNT
					END
			END

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
