SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Feature]
(
	--Default parameter
	@JobID int = 0,
	@UserName	nvarchar(50) = NULL,
	@ApplicationID int = NULL,
	@FeatureBM int = NULL OUT,
	@Debug		bit = 0,
	@GetVersion bit = 0
)

/*
	EXEC dbo.[spGet_Feature] @UserName = 'dspepicor10\administrator', @Debug = 1
	EXEC dbo.[spGet_Feature] @UserName = 'jaxit\bengt.jax', @Debug = 1
	EXEC dbo.[spGet_Feature] @ApplicationID = 400
	EXEC dbo.[spGet_Feature] @GetVersion = 1
*/	

--#WITH ENCRYPTION#--

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@ReturnFeatureBM bit = 1,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2113'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2112' SET @Description = 'Procedure created'
		IF @Version = '1.3.2113' SET @Description = 'Added parameter @ApplicationID'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserName IS NULL AND @ApplicationID IS NULL
	BEGIN
		PRINT 'Parameter @UserName must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		IF @FeatureBM = 0 SET @ReturnFeatureBM = 0

		IF @ApplicationID IS NULL SELECT @ApplicationID = MAX(ApplicationID) FROM [Application] WHERE ApplicationID > 0 AND SelectYN <> 0

	SET @Step = 'Get Feature'
		SELECT
			@FeatureBM = MAX(Nyc) 
		FROM
			Instance I
			INNER JOIN [Application] A ON A.InstanceID = I.InstanceID AND A.ApplicationID = @ApplicationID AND A.SelectYN <> 0

		IF @ReturnFeatureBM <> 0 SELECT	@FeatureBM

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH


GO
