SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_SqlQuery_List]
(
	@UserID int = NULL,
	@InstanceID int = NULL,
	@SqlQueryGroupID int = NULL,
	@JobID int = 0,
	@Debug		bit = 0,
	@GetVersion bit = 0
)

/*
	EXEC dbo.[spPortalGet_SqlQuery_List] @UserID = 1005, @InstanceID = 400, @SqlQueryGroupID = -107, @Debug = 1
	EXEC dbo.[spPortalGet_SqlQuery_List] @UserID = 1005, @Debug = 1
	EXEC dbo.[spPortalGet_SqlQuery_List] @GetVersion = 1
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
	@Version nvarchar(50) = '1.4.0.2137'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created'
		IF @Version = '1.4.0.2137' SET @Description = 'Modified where-clause'

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
		SELECT 
			[SqlQueryID] = SQ.SqlQueryID,
			[SqlQueryName] = SQ.SqlQueryName,
			[SqlQueryDescription] = SQ.SqlQueryDescription
		FROM
			SqlQuery SQ 
		WHERE
			SQ.InstanceID = @InstanceID AND
			SQ.[SqlQueryGroupID] <> -1 AND
			(SQ.[SqlQueryGroupID] = @SqlQueryGroupID OR @SqlQueryGroupID IS NULL) AND
--			SQ.[SqlQueryGroupID] = @SqlQueryGroupID AND
			SQ.SelectYN <> 0
		ORDER BY
			SQ.SqlQueryName

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

GO
