SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spExcelGet_LoginToken]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,
	@TokenString nvarchar(36) = NULL,

	@ApplicationName	nvarchar(100) = NULL,
	@ModelName			nvarchar(100) = NULL,

	@Token UniqueIdentifier = NULL OUT,

	@JobID int = NULL,
	@Rows int = NULL,
	@ProcedureID INT = 880000221,
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
	@ProcedureName = 'spExcelGet_LoginToken',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "2129"},
		{"TKey" : "InstanceID",  "TValue": "404"},
		{"TKey" : "VersionID",  "TValue": "1003"}
		]'

EXEC [dbo].[spExcelGet_LoginToken] 
	@UserID = 2129,
	@InstanceID = 404,
	@VersionID = 1003


EXEC [dbo].[spExcelGet_LoginToken] 
	@UserID = 2129,
	@InstanceID = 404,
	@VersionID = 1003,
	@TokenString = '1C04C383-2309-4F03-BCD6-43241C2AEDA4'

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spExcelGet_LoginToken',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "2129"},
		{"TKey" : "InstanceID",  "TValue": "404"},
		{"TKey" : "VersionID",  "TValue": "1003"},
		{"TKey" : "TokenString",  "TValue": "1C04C383-2309-4F03-BCD6-43241C2AEDB4"}
		]'


EXEC [spExcelGet_LoginToken] @GetVersion = 1
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
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'

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

	SET @Step = 'Insert into LoginToken'

		BEGIN TRY 
			SET @Token =  CAST(@TokenString AS UNIQUEIDENTIFIER)
		END TRY
		BEGIN CATCH
			SET @Token = NULL
		END CATCH
		
		SET @Token = ISNULL(@Token, NewID())

		INSERT INTO [pcINTEGRATOR_Data]..[LoginToken]
			(
			[UserID],
			[InstanceID],
			[VersionID],
			[Token],
			[ValidUntil],
			[Inserted]
			)
     SELECT
			[UserID] = @UserID,
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[Token] = @Token,
			[ValidUntil] = DATEADD(second, @ValidSeconds, GetDate()),
			[Inserted] = GetDate()

	SET @Step = 'Return Token'
		SELECT 
			Token = @Token

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version, @Parameter, @UserName, @UserID, @InstanceID, @VersionID
				
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version, @Parameter, @UserName, @UserID, @InstanceID, @VersionID
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
