SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Time_MemberKey]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@LiveYN bit = NULL,
	@ClosedMonth int = NULL,
	@TimeFrom int = NULL,
	@TimeTo int = NULL,
	@TimeOffsetFrom int = NULL,
	@TimeOffsetTo int = NULL,
	@Time_MemberKey nvarchar(4000) = NULL OUT,

	@JobID int = NULL,
	@Rows int = NULL,
	@ProcedureID INT = 880000211,
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
DECLARE @Time_MemberKey nvarchar(4000)
EXEC spGet_Time_MemberKey @UserID = -10, @InstanceID = 114, @VersionID = 1004, @LiveYN = 0, @TimeFrom = 201603, @TimeTo = 201712, @Time_MemberKey = @Time_MemberKey OUT
SELECT Time_MemberKey = @Time_MemberKey

DECLARE @Time_MemberKey nvarchar(4000)
EXEC spGet_Time_MemberKey @UserID = -10, @InstanceID = 114, @VersionID = 1004, @LiveYN = 1, @ClosedMonth = 201710, @TimeOffsetFrom = -3, @TimeOffsetTo = 12, @Time_MemberKey = @Time_MemberKey OUT
SELECT Time_MemberKey = @Time_MemberKey

EXEC [spGet_Time_MemberKey] @GetVersion = 1
*/
DECLARE
	@YearFrom int,
	@YearTo int,
	@ClosedMonth_Counter int,

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

		SELECT @UserName = ISNULL(@UserName, suser_name())		

	SET @Step = 'Check parameters'
		IF @LiveYN = 0 AND (@TimeFrom IS NULL OR @TimeTo IS NULL)
			BEGIN
				SET @Message = 'If the scenario is not of type Live @TimeFrom and @TimeTo must be set'
				SET @Severity = 16
				GOTO EXITPOINT
			END

		IF @LiveYN <> 0 AND (@ClosedMonth IS NULL OR @TimeOffsetFrom IS NULL OR @TimeOffsetTo IS NULL)
			BEGIN
				SET @Message = 'If the scenario is of type Live @ClosedMonth, @TimeOffsetFrom and @TimeOffsetTo must be set'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Create @Month table'
		DECLARE @Month table 
		   ( 
		   [Counter] int IDENTITY(1, 1), 
		   [Time] int
		   )

		SELECT
			@YearFrom = CASE WHEN @LiveYN = 0 THEN @TimeFrom / 100 ELSE @ClosedMonth / 100 + @TimeOffsetFrom / 12 - 1 END,
			@YearTo = CASE WHEN @LiveYN = 0 THEN @TimeTo / 100 ELSE @ClosedMonth / 100 + @TimeOffsetTo / 12 + 1 END

		INSERT INTO @Month
			(
			[Time]
			)
		SELECT DISTINCT TOP 1000000
			[Time] = Y.Y * 100 + M.M
		FROM
			(
				SELECT
					[Y] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 
				FROM
					Digit D1,
					Digit D2,
					Digit D3,
					Digit D4
				WHERE
					D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @YearFrom AND @YearTo
			) Y,
			(
				SELECT
					[M] = D2.Number * 10 + D1.Number + 1 
				FROM
					Digit D1,
					Digit D2
				WHERE
					D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
			) M 
		ORDER BY
			Y.Y * 100 + M.M

	SET @Step = 'Calculate @TimeFrom and @TimeTo'
		IF @LiveYN <> 0
			BEGIN
				SELECT @ClosedMonth_Counter = [Counter] FROM @Month WHERE [Time] = @ClosedMonth
				SELECT @TimeFrom = [Time] FROM @Month WHERE [Counter] = @ClosedMonth_Counter + @TimeOffsetFrom
				SELECT @TimeTo = [Time] FROM @Month WHERE [Counter] = @ClosedMonth_Counter + @TimeOffsetTo
			END

		SELECT TimeFrom = @TimeFrom, TimeTo = @TimeTo

		SET @Time_MemberKey = ''

		SELECT @Time_MemberKey = @Time_MemberKey + CONVERT(nvarchar(6), [Time]) + ',' FROM @Month WHERE [Time] BETWEEN @TimeFrom AND @TimeTo ORDER BY [Time]
		SET @Time_MemberKey = LEFT(@Time_MemberKey, LEN(@Time_MemberKey) - 1)

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

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
