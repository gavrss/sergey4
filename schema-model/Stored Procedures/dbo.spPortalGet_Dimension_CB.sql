SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Dimension_CB]

@UserID int = NULL,
@InstanceID int = NULL,
@JobID int = 0,
@GetVersion bit = 0,
@Debug bit = 0

--#WITH ENCRYPTION#--

AS

--EXEC spPortalGet_Dimension_CB @UserID = 1005, @InstanceID = 400
--EXEC spPortalGet_Dimension_CB @InstanceID = 357
--EXEC spPortalGet_Dimension_CB @GetVersion = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@UserName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2134'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserID IS NULL OR @InstanceID IS NULL
	BEGIN
		PRINT 'Parameter @UserID and parameter @InstanceID must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT

	SET @Step = 'Set User Name'
		SET @UserName = suser_name()

	SET @Step = 'Return rows'
		SELECT 
			[DimensionID],
			[DimensionName],
			[DimensionDescription]
		FROM
			Dimension
		WHERE
			([InstanceID] = @InstanceID OR [InstanceID] = 0) AND
			DimensionID NOT BETWEEN 0 AND 1000
		ORDER BY
			DimensionName

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
