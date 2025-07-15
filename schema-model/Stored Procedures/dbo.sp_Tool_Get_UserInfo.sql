SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Get_UserInfo]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000483,
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
EXEC [sp_Tool_Get_UserInfo] @UserID=8348, @Debug=1

EXEC [sp_Tool_Get_UserInfo] @GetVersion = 1
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
			@ProcedureDescription = 'Get all info for a specific User',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'

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

		SELECT @InstanceID = InstanceID FROM [User] WHERE UserID = @UserID

	SET @Step = 'Base info'
		SELECT [Table] = 'User', * FROM [User] WHERE UserID = @UserID
		SELECT [Table] = 'Instance', * FROM [Instance] WHERE InstanceID = @InstanceID

	SET @Step = 'Added instances'
		SELECT
			[Table] = 'User_Instance',
			UI.*
		FROM
			[User_Instance] UI
		WHERE
			UI.UserID = @UserID

	SET @Step = 'Properties'
		SELECT
			[Table] = 'UserPropertyValue',
			UPT.UserPropertyTypeName,
			UPV.* 
		FROM
			[UserPropertyValue] UPV
			INNER JOIN UserPropertyType UPT ON UPT.UserPropertyTypeID = UPV.UserPropertyTypeID
		WHERE
			UPV.UserID = @UserID

	SET @Step = 'Groups'
		SELECT
			[BaseTable] = 'UserMember',
			GroupName = U.UserName,
			UM.* 
		FROM
			[UserMember] UM 
			INNER JOIN [User] U ON U.UserID = UM.UserID_Group
		WHERE
			UM.UserID_User = @UserID

	SET @Step = 'SecurityRoles'
		SELECT
			[BaseTable] = 'SecurityRoleUser',
			SR.SecurityRoleName,
			sub.*
		FROM
			(
			SELECT
				SRU.*
			FROM
				SecurityRoleUser SRU
			WHERE
				UserID = @UserID
			UNION SELECT
				SRU.*
			FROM
				SecurityRoleUser SRU
				INNER JOIN [UserMember] UM ON UM.UserID_Group = SRU.UserID AND UM.UserID_User = @UserID
			) sub
			INNER JOIN SecurityRole SR ON SR.SecurityRoleID = sub.SecurityRoleID

	SET @Step = 'OrganizationPosition'
		SELECT
			[BaseTable] = 'OrganizationPosition_User',
			OP.OrganizationPositionName,
			sub.*
		FROM
			(
			SELECT
				OPU.*
			FROM
				OrganizationPosition_User OPU
			WHERE
				UserID = @UserID

			UNION SELECT
				OPU.*
			FROM
				OrganizationPosition_User OPU
				INNER JOIN [UserMember] UM ON UM.UserID_Group = OPU.UserID AND UM.UserID_User = @UserID
			) sub
			INNER JOIN OrganizationPosition OP ON OP.OrganizationPositionID = sub.OrganizationPositionID

	SET @Step = 'Assignment'
		SELECT
			[BaseTable] = 'Assignment',
			A.*
		FROM
			(
			SELECT
				OPU.*
			FROM
				OrganizationPosition_User OPU
			WHERE
				UserID = @UserID

			UNION SELECT
				OPU.*
			FROM
				OrganizationPosition_User OPU
				INNER JOIN [UserMember] UM ON UM.UserID_Group = OPU.UserID AND UM.UserID_User = @UserID
			) sub
			INNER JOIN Assignment A ON A.OrganizationPositionID = sub.OrganizationPositionID

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
