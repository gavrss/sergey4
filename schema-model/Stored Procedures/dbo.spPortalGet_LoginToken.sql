SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_LoginToken]
	@UserID int = NULL OUT,
	@InstanceID int = NULL OUT,
	@VersionID int = NULL OUT,

	@Token UniqueIdentifier = NULL OUT,

	@JobID int = NULL,
	@Rows int = NULL,
	@ProcedureID INT = 880000222,
	@Parameter NVARCHAR(4000) = NULL,
	@StartTime DATETIME = NULL,
	@Duration datetime = 0 OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
--CB
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalGet_LoginToken',
	@JSON = '
		[
		{"TKey" : "Token",  "TValue": "86BD60F0-F2A8-4059-8C49-E644790B8002"}
		]'

EXEC [dbo].[spPortalGet_LoginToken] 
	@Token = '27D00FEB-6338-4CB6-BC2A-B6C8334C5741'

EXEC [spPortalGet_LoginToken] @GetVersion = 1
*/
DECLARE
	@ValidSeconds int = 60,

	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.2.2144'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2144' SET @Description = 'Changed Delete-statement to table in pcINTEGRATOR_Data.'

		IF ISNULL((SELECT [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = OBJECT_NAME(@@PROCID) AND DeletedID IS NULL), 0) <> @ProcedureID
			BEGIN
				SET @ProcedureID = NULL
				SELECT @ProcedureID = [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = OBJECT_NAME(@@PROCID) AND DeletedID IS NULL
				IF @ProcedureID IS NULL
					BEGIN
						EXEC spInsert_Procedure
						SET @Message = 'SP ' + OBJECT_NAME(@@PROCID) + ' was not registered. It is now registered by SP spInsert_Procedure. Rerun the command to get correct ProcedureID.'
					END
				ELSE
					SET @Message = 'ProcedureID mismatch, should be ' + CONVERT(nvarchar(10), @ProcedureID)
				SET @Severity = 16
				GOTO EXITPOINT
			END
		SELECT [Version] = @Version, [Description] = @Description, [ProcedureID] = @ProcedureID
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

	SET @Step = 'Get user info'
		SELECT
			@UserID = [UserID],
			@InstanceID = [InstanceID],
			@VersionID = [VersionID]
		FROM
			[LoginToken]
		WHERE
			[Token] = @Token AND
			[ValidUntil] >= GetDate()

	SET @Step = 'Delete token'
		DELETE
			pcINTEGRATOR_Data..[LoginToken]
		WHERE
			[Token] = @Token OR
			[ValidUntil] < GetDate()

		SET @Deleted = @@ROWCOUNT

	SET @Step = 'Return user info'
		SELECT 
			[UserID] = @UserID,
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID 

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version, @Parameter, @UserName, ISNULL(@UserID, 0), ISNULL(@InstanceID, 0), ISNULL(@VersionID, 0)
				
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version, @Parameter, @UserName, ISNULL(@UserID, 0), ISNULL(@InstanceID, 0), ISNULL(@VersionID, 0)
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
