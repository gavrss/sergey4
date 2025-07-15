SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_SecurityRole]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@SecurityRoleID int = NULL OUT,
	@SecurityRoleName nvarchar(100) = NULL, --Mandatory
	@UserLicenseTypeID int = NULL, --Mandatory
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000428,
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
--INSERT
EXEC [spPortalAdminSet_SecurityRole]
	@UserID = -10,
	@InstanceID = 390,
	@VersionID = 1011,
	@SecurityRoleName = 'TestSecRoleSSS',
	@UserLicenseTypeID = -1,
	@Debug = 1

--UPDATE
EXEC [spPortalAdminSet_SecurityRole]
	@UserID = -10,
	@InstanceID = 390,
	@VersionID = 1011,
	@SecurityRoleID = 5007,
	@SecurityRoleName = 'TestSecRole',
	@UserLicenseTypeID = -1,
	@Debug = 1

--DELETE
EXEC [spPortalAdminSet_SecurityRole]
	@UserID = -10,
	@InstanceID = 390,
	@VersionID = 1011,
	@SecurityRoleName = 'TestSecRoleuPDATE',
	@UserLicenseTypeID = -1,
	@SecurityRoleID = 5002,
	@DeleteYN = 1,
	@Debug = 1

--GetVersion
EXEC [spPortalAdminSet_SecurityRole] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.0.2.2145'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Handles CREATE and DELETE of SecurityRole Object',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'

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

	SET @Step = 'Update Security Role'
		IF @DeleteYN = 0 
			BEGIN
				UPDATE SR
				SET
					[SecurityRoleName] = @SecurityRoleName,
					[UserLicenseTypeID] = @UserLicenseTypeID
				FROM
					[pcINTEGRATOR_Data].[dbo].[SecurityRole] SR
				WHERE
					[InstanceID] = @InstanceID AND 
					[SecurityRoleID] = @SecurityRoleID AND
					([SecurityRoleName] <> @SecurityRoleName OR [UserLicenseTypeID] <> @UserLicenseTypeID) AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRole] SR WHERE SR.InstanceID = @InstanceID AND SR.[SecurityRoleID] <> @SecurityRoleID AND SR.SecurityRoleName = @SecurityRoleName)

				SET @Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'Delete existing Security Role'
		IF @DeleteYN <> 0
			BEGIN
				SET @Step = 'Delete SecurityRoleObject'	
					DELETE SRO
					FROM
						[pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO
					WHERE
						SRO.InstanceID = @InstanceID AND
						SRO.SecurityRoleID = @SecurityRoleID

					SET @Deleted = @Deleted + @@ROWCOUNT

				SET @Step = 'Delete SecurityRoleUser'		
					DELETE SRU
					FROM
						[pcINTEGRATOR_Data].[dbo].[SecurityRoleUser] SRU
					WHERE
						SRU.InstanceID = @InstanceID AND
						SRU.SecurityRoleID = @SecurityRoleID

					SET @Deleted = @Deleted + @@ROWCOUNT

				SET @Step = 'Delete SecurityRole'				
					DELETE SR
					FROM
						[pcINTEGRATOR_Data].[dbo].[SecurityRole] SR
					WHERE
						SR.InstanceID = @InstanceID AND
						SR.SecurityRoleID = @SecurityRoleID

					SET @Deleted = @Deleted + @@ROWCOUNT

					IF @Deleted > 0
						SET @Message = 'The Security Role [' + @SecurityRoleName + '] is deleted.'
					ELSE
						SET @Message = 'No Security Role is deleted.' 

					SET @Severity = 0

					IF @Debug <> 0 PRINT @Message
			END

	SET @Step = 'Insert new Security Role'
		IF @DeleteYN = 0 AND @SecurityRoleID IS NULL
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRole]
					(
					[InstanceID],
					[SecurityRoleName],
					[UserLicenseTypeID],
					[SelectYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[SecurityRoleName] = @SecurityRoleName,
					[UserLicenseTypeID] = @UserLicenseTypeID,
					[SelectYN] = 1
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRole] SR WHERE SR.InstanceID = @InstanceID AND SR.SecurityRoleName = @SecurityRoleName)

				SELECT @SecurityRoleID = CASE WHEN @@ROWCOUNT = 0 THEN NULL ELSE @@IDENTITY END, @Inserted = @Inserted + @@ROWCOUNT

				IF @Inserted > 0
					SET @Message = 'The new Security Role [' + @SecurityRoleName + '] is added.'
				ELSE
					SET @Message = 'No Security Role is added.' 

				SET @Severity = 0

				IF @Debug <> 0 
					BEGIN
					    PRINT @Message
						SELECT * FROM [pcINTEGRATOR_Data].[dbo].[SecurityRole] WHERE SecurityRoleID = @SecurityRoleID
					END
			END

	SET @Step = 'Return SecurityRoleID'
		IF @SecurityRoleID IS NULL 
			SELECT @SecurityRoleID = SecurityRoleID FROM [pcINTEGRATOR_Data].[dbo].[SecurityRole] SR WHERE SR.InstanceID = @InstanceID AND SR.SecurityRoleName = @SecurityRoleName

		SELECT [@SecurityRoleID] = @SecurityRoleID
		
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

	RETURN @SecurityRoleID
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
