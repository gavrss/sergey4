SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_SqlQueryGroup_List]
(
	@UserID int = NULL,
	@InstanceID int = NULL,
	@JobID int = 0,
	@Debug		bit = 0,
	@GetVersion bit = 0
)

/*
	EXEC dbo.[spPortalGet_SqlQueryGroup_List] @UserID = 1005, @InstanceID = 400, @Debug = 1
	EXEC dbo.[spPortalGet_SqlQueryGroup_List] @UserID = 1005, @Debug = 1
	EXEC dbo.[spPortalGet_SqlQueryGroup_List] @GetVersion = 1
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
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2134'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created'

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

	SET @Step = 'Return Name and description'
		SELECT DISTINCT
			[SqlQueryGroupID] = SQG.SqlQueryGroupID,
			[SqlQueryGroupName] = SQG.SqlQueryGroupName,
			[SqlQueryGroupDescription] = SQG.SqlQueryGroupDescription
		FROM
			SqlQueryGroup SQG
			INNER JOIN SqlQuery SQ ON SQ.InstanceID = @InstanceID AND SQ.SqlQueryGroupID = SQG.SqlQueryGroupID AND SQ.SelectYN <> 0
		WHERE
			SQG.[SqlQueryGroupID] <> -1 AND
			SQG.SelectYN <> 0

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

GO
