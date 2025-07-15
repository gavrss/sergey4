SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_SqlQueryGroup_CB]
(
	@UserID int = NULL,
	@InstanceID int = NULL,
	@JobID int = 0,
	@Debug		bit = 0,
	@GetVersion bit = 0
)

/*
	EXEC dbo.[spPortalGet_SqlQueryGroup_CB] @UserID = 1005, @InstanceID = 357, @Debug = 1
	EXEC dbo.[spPortalGet_SqlQueryGroup_CB] @UserID = 1005, @Debug = 1
	EXEC dbo.[spPortalGet_SqlQueryGroup_CB] @GetVersion = 1
*/	

--#WITH ENCRYPTION#--

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@ParameterName nvarchar(50),
	@SortOrder int = 0,
	@Parameters int,
	@SQLStatement nvarchar(max),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2135'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created'
		IF @Version = '1.4.0.2135' SET @Description = 'Enhanced error handling.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserID IS NULL OR @InstanceID IS NULL
	BEGIN
		SET @Message = 'Parameter @UserID and @InstanceID must be set'
		SET @Severity = 16
		RAISERROR (@Message, @Severity, 100)
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Return Name and description'
		SELECT 
			SqlQueryGroupID,
			SqlQueryGroupName,
			SqlQueryGroupDescription
		FROM
			SqlQueryGroup
		WHERE
			(InstanceID = @InstanceID OR InstanceID = 0) AND
			SelectYN <> 0
		ORDER BY
			SqlQueryGroupName

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

GO
