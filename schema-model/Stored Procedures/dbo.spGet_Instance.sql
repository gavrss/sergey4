SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Instance]
	(
	--Default parameter
	@JobID int = 0,
	@UserName nvarchar(50) = NULL,
	@CustomerID int = NULL,
	@Debug		bit = 0,
	@GetVersion bit = 0
	)

--#WITH ENCRYPTION#--

AS

--EXEC [spGet_Instance] @UserName = 'Jan'

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2134'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2128' SET @Description = 'Procedure created'
		IF @Version = '1.4.0.2134' SET @Description = 'Default value for @UserName set to NULL'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserName IS NULL 
	BEGIN
		PRINT 'Parameter @UserName must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT

	SET @Step = 'Return available Instances'
		SELECT
			[InstanceID],
			[InstanceName]
		FROM
			[Instance]
		WHERE
			InstanceID > 0 AND
			SelectYN <> 0 AND
			(CustomerID = @CustomerID OR @CustomerID IS NULL)

	SET @Step = 'EXITPOINT:'
		EXITPOINT:
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH


GO
