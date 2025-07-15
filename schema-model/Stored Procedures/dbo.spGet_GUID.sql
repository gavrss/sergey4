SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_GUID]
(
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,
	@TableName nvarchar(100) = NULL,
	@GUID uniqueidentifier = NULL OUT,
	@JobID int = 0,
	@Debug bit = 0,
	@GetVersion bit = 0
)

--#WITH ENCRYPTION#--

AS

--	EXEC [dbo].[spGet_GUID] @UserID = -10, @InstanceID = 16, @VersionID = 1001, @TableName = 'DataClass', @Debug = 1
--	EXEC [dbo].[spGet_GUID] @UserID = -10, @InstanceID = 0, @VersionID = 1001, @TableName = 'SpreadingKey', @Debug = 1
--	EXEC [dbo].[spGet_GUID] @UserID = -10, @InstanceID = 114, @VersionID = 1004, @TableName = 'DataClass', @Debug = 1
--	EXEC [dbo].[spGet_GUID] @UserID = -10, @InstanceID = 114, @VersionID = 1004, @TableName = 'Measure', @Debug = 1
--	EXEC [dbo].[spGet_GUID] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @TableName = 'DataClass', @Debug = 1
--	EXEC [dbo].[spGet_GUID] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @TableName = 'Measure', @Debug = 1
--	EXEC [dbo].[spGet_GUID] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @TableName = 'Process', @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2136'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2137' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserID IS NULL OR @InstanceID IS NULL OR @VersionID IS NULL OR @TableName IS NULL
	BEGIN
		SET @Message = 'Parameter @UserID, @InstanceID, @VersionID and @TableName must be set'
		SET @Severity = 16
		RAISERROR (@Message, @Severity, 100)
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set @GUID Variable'
		SET @GUID = NewID()

	SET @Step = 'Add row into UniqueIdentifier table'
		INSERT INTO pcINTEGRATOR_Data.[dbo].[UniqueIdentifier]
			(
			[InstanceID],
			[GUID],
			[VersionID],
			[TableName],
			[UserID]
			)
		 SELECT
		 	[InstanceID] = @InstanceID,
			[GUID] = @GUID,
			[VersionID] = @VersionID,
			[TableName] = @TableName,
			[UserID] = @UserID

	SET @Step = 'Return @GUID'
		IF @Debug <> 0 SELECT [GUID] = @GUID

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH
GO
