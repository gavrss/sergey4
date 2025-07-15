SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheck_PreRequisites] 

	@JobID int = 0,
	@Debug bit = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--

AS

--EXEC [spCheck_PreRequisites] @Debug = 1
--EXEC [spCheck_PreRequisites]
--EXEC [spCheck_PreRequisites] @GetVersion = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@InstanceID int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2127'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2126' SET @Description = 'Procedure created.'
		IF @Version = '1.4.0.2127' SET @Description = 'Removed SELECT-statement from ERROR-catch.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

BEGIN TRY

	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT
			@InstanceID = MAX(A.InstanceID)
		FROM
			[Application] A
			INNER JOIN [Instance] I ON I.InstanceID = A.InstanceID AND I.SelectYN <> 0
		WHERE
			A.SelectYN <> 0

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Check existance of Callisto'
		IF (SELECT COUNT(1) FROM sys.databases WHERE name = 'CallistoAppDictionary') = 0	
			BEGIN
				SET @Message = 'The installation of Callisto is a prerequisite for pcINTEGRATOR: ' 
				SET @Message = SUBSTRING(@Message, 1, LEN(@Message) - 1) + '. The setup can not continue until this problem is fixed.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Check Callisto version'
		IF (SELECT COUNT(1) FROM CallistoAppDictionary.sys.tables WHERE name = 'DbVersion') = 0	
			BEGIN
				SET @Message = 'Version 4 of Callisto is a prerequisite for this version of pcINTEGRATOR: ' 
				SET @Message = SUBSTRING(@Message, 1, LEN(@Message) - 1) + '. The setup can not continue until this problem is fixed.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Set success messages'
		SET @Message = 'The tested prerequisites are met.' 
		SET @Severity = 0

	SET @Step = 'Define exit point'
		EXITPOINT:
		RAISERROR (@Message, @Severity, 100)	

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
END CATCH


GO
