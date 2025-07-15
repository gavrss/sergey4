SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Grid_List]

@UserID int = NULL,
@InstanceID int = NULL,
@VersionID int = NULL,
@JobID int = 0,
@GetVersion bit = 0,
@Debug bit = 0

--#WITH ENCRYPTION#--

AS

--EXEC spPortalGet_Grid_List @UserID = 1005, @InstanceID = 304, @VersionID = 0, @Debug = 1
--EXEC spPortalGet_Grid_List @UserID = 1005, @InstanceID = 400, @VersionID = 0
--EXEC spPortalGet_Grid_List @UserID = 1005, @InstanceID = 304, @VersionID = 0
--EXEC spPortalGet_Grid_List @InstanceID = 357
--EXEC spPortalGet_Grid_List @GetVersion = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@UserName nvarchar(100),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserID IS NULL OR @InstanceID IS NULL OR @VersionID IS NULL
	BEGIN
		SET @Message = 'Parameter @UserID, @InstanceID and @VersionID must be set'
		SET @Severity = 16
		RAISERROR (@Message, @Severity, 100)
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
		SELECT DISTINCT
			[InstanceID] = G.[InstanceID],
			[GridID] = G.[GridID],
			[VersionID] = 0,
			[GridName] = G.[GridName],
			[GridDescription] = G.[GridDescription],
			[DataClassID] = G.[DataClassID],
			[GridSkinID] = G.[GridSkinID],
			[GetProc] = G.[GetProc],
			[SetProc] = G.[SetProc], 
			[InheritedFrom] = G.[InheritedFrom]		
		FROM
			Grid G
		WHERE
			G.InstanceID IN (0, @InstanceID)
--			G.VersionID = @VersionID
		ORDER BY
			G.[GridName]

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
