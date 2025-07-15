SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_JobLog]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL OUT,
	@LogStartTime datetime = NULL,
	@ProcedureID int = 880000292,
	@ProcedureName nvarchar(100) = NULL,
	@Duration time(7) = NULL,
	@Deleted int = 0,
	@Inserted int = 0,
	@Updated int = 0,
	@Selected int = 0,
	@ErrorNumber int = 0,
	@ErrorSeverity int = NULL,
	@ErrorState int = NULL,
	@ErrorProcedure nvarchar(128) = NULL,
	@ErrorStep nvarchar(255) = NULL,
	@ErrorLine int = NULL,
	@ErrorMessage nvarchar(4000) = NULL, 
	@ParameterTable nvarchar(4000) = NULL, 
	@Parameter nvarchar(4000) = NULL, 
	@LogVersion nvarchar(100) = NULL,
	@UserName nvarchar(100) = NULL,
	@AuthenticatedUserID int = NULL,
	@GetVersion bit = 0,
	@Debug bit = 0

AS

--EXEC spSet_JobLog @GetVersion = 1

DECLARE
	@StartTime DATETIME = NULL,
	@ErrorMessageForLog nvarchar(4000) = NULL,
	@ErrorNumberForLog int = NULL,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@DatabaseName nvarchar(100),
	@DebugSub bit = 0,
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2197'

SET NOCOUNT ON 

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Update JobLog',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Logging into pcINTEGRATOR_Log.'
		IF @Version = '2.0.3.2154' SET @Description = 'Added @ProcedureID.'
		IF @Version = '2.1.0.2155' SET @Description = 'Added @ParameterTable and @Parameter.'
		IF @Version = '2.1.0.2158' SET @Description = 'Added @AuthenticatedUserID.'
		IF @Version = '2.1.0.2160' SET @Description = 'Added @ProcedureID when inserting into [pcINTEGRATOR_Log].'
		IF @Version = '2.1.1.2174' SET @Description = 'If @ProcedureID not passed, pick up from @ProcedureName.'
		IF @Version = '2.1.1.2177' SET @Description = 'DB-734: Return Error information.'
		IF @Version = '2.1.2.2190' SET @Description = 'IF @ErrorSeverity = 16 and @ErrorMessage > 50000... set @ErrorMessage=..., @ErrorNumber=...'
		IF @Version = '2.1.2.2197' SET @Description = 'Close Job when Error to avoid blockers in the JobQueue.'
		
		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		IF @ProcedureID = 880000292
			SELECT @ProcedureID = ProcedureID FROM dbo.[Procedure] WHERE ProcedureName = @ProcedureName

		IF (@ErrorSeverity = 16 AND @ErrorNumber > 50000)
			BEGIN
				SET @ErrorMessageForLog	= 'ErrorNumber = ' + CAST(@ErrorNumber AS VARCHAR(255)) + ', ' + @ErrorMessage;
				SET @ErrorNumberForLog	= -2
            END

	SET @Step = 'UPDATE or INSERT table JobLog'
		IF @Debug <> 0 SELECT [@ProcedureID] = @ProcedureID, [@ProcedureName] = @ProcedureName, [@JobLogID] = @JobLogID


		IF @JobLogID IS NULL
			BEGIN
				INSERT INTO pcINTEGRATOR_Log..JobLog
					(
					[JobID],
					[StartTime],
					[ProcedureID],
					[ProcedureName],
					[Duration],
					[Deleted],
					[Inserted],
					[Updated],
					[Selected],
					[ErrorNumber],
					[ErrorSeverity],
					[ErrorState],
					[ErrorProcedure],
					[ErrorStep],
					[ErrorLine],
					[ErrorMessage],
					[ParameterTable], 
					[Parameter], 
					[Version],
					[UserName],
					[UserID],
					[InstanceID],
					[VersionID],
					[AuthenticatedUserID]
					) 
				SELECT
					[JobID] = @JobID,
					[StartTime] = @LogStartTime,
					[ProcedureID] = @ProcedureID,
					[ProcedureName] = @ProcedureName,
					[Duration] = @Duration,
					[Deleted] = @Deleted,
					[Inserted] = @Inserted,
					[Updated] = @Updated,
					[Selected] = @Selected,
					[ErrorNumber] = ISNULL(@ErrorNumberForLog, @ErrorNumber),
					[ErrorSeverity] = @ErrorSeverity,
					[ErrorState] = @ErrorState,
					[ErrorProcedure] = @ErrorProcedure,
					[ErrorStep] = @ErrorStep,
					[ErrorLine] = @ErrorLine,
					[ErrorMessage] = ISNULL(@ErrorMessageForLog, @ErrorMessage), 
					[ParameterTable] = @ParameterTable, 
					[Parameter] = @Parameter, 
					[Version] = @LogVersion,
					[UserName] = @UserName,
					[UserID] = @UserID,
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[AuthenticatedUserID] = @AuthenticatedUserID

				SET @JobLogID = @@IDENTITY
			END
		ELSE
			BEGIN
				UPDATE JL
				SET
					[JobID] = @JobID,
					[StartTime] = @LogStartTime,
					[ProcedureID] = ISNULL([ProcedureID], @ProcedureID),
					[ProcedureName] = @ProcedureName,
					[Duration] = @Duration,
					[Deleted] = @Deleted,
					[Inserted] = @Inserted,
					[Updated] = @Updated,
					[Selected] = @Selected,
					[ErrorNumber] = ISNULL(@ErrorNumberForLog, @ErrorNumber),
					[ErrorSeverity] = @ErrorSeverity,
					[ErrorState] = @ErrorState,
					[ErrorProcedure] = @ErrorProcedure,
					[ErrorStep] = @ErrorStep,
					[ErrorLine] = @ErrorLine,
					[ErrorMessage] = ISNULL(@ErrorMessageForLog, @ErrorMessage), 
					[ParameterTable] = ISNULL(JL.[ParameterTable], @ParameterTable), 
					[Parameter] = ISNULL(JL.[Parameter], @Parameter), 
					[Version] = @LogVersion,
					[UserName] = @UserName,
					[UserID] = @UserID,
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[AuthenticatedUserID] = @AuthenticatedUserID
				FROM
					pcINTEGRATOR_Log..JobLog JL
				WHERE
					[JobLogID] = @JobLogID
			END

	IF @ErrorNumber NOT IN (-1, 0)
		BEGIN
			UPDATE J
			SET
				[JobStatus] = 'Error',
				[ErrorTime] = GetDate(),
				[ClosedYN] = 1
			FROM
				[pcINTEGRATOR_Log].[dbo].[Job] J
			WHERE
				[InstanceID] = @InstanceID AND
				[VersionID] = @VersionID AND
				[JobID] = @JobID AND
				[MasterCommand] = @ProcedureName AND
				[ClosedYN] = 0

			SELECT [ErrorNumber] = @ErrorNumber, [ErrorSeverity] = @ErrorSeverity, [ErrorState] = @ErrorState, [ErrorProcedure] = @ErrorProcedure, [ErrorStep] = @ErrorStep, [ErrorLine] = @ErrorLine, [ErrorMessage] = @ErrorMessage
		END

END TRY

BEGIN CATCH
	SELECT
		@UserID = ISNULL(@UserID, -100),
		@InstanceID = ISNULL(@InstanceID, -100),
		@VersionID = ISNULL(@VersionID, -100)

	INSERT INTO pcINTEGRATOR_Log..JobLog
		(
		[JobID],
		[StartTime],
		[ProcedureID],
		[ProcedureName],
		[Duration],
		[ErrorNumber],
		[ErrorSeverity],
		[ErrorState],
		[ErrorProcedure],
		[ErrorStep],
		[ErrorLine],
		[ErrorMessage],
		[Version],
		[UserName],
		[UserID],
		[InstanceID],
		[VersionID],
		[AuthenticatedUserID]
		)
	SELECT
		[JobID] = @ProcedureID,
		[StartTime] = @StartTime,
		[ProcedureID] = @ProcedureID,
		[ProcedureName] = OBJECT_NAME(@@PROCID),
		[Duration] = GetDate() - @StartTime,
		[ErrorNumber] = ERROR_NUMBER(),
		[ErrorSeverity] = ERROR_SEVERITY(),
		[ErrorState] = ERROR_STATE(),
		[ErrorProcedure] = ERROR_PROCEDURE(),
		[ErrorStep] = @Step,
		[ErrorLine] = ERROR_LINE(),
		[ErrorMessage] = ERROR_MESSAGE(),
		[Version] = @Version,
		[UserName] = suser_name(),
		[UserID] = @UserID,
		[InstanceID] = @InstanceID,
		[VersionID] = @VersionID,
		[AuthenticatedUserID] = @AuthenticatedUserID

	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM pcINTEGRATOR_Log..JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber = @ErrorMessageForLog, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage = @ErrorMessage FROM pcINTEGRATOR_Log..JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
