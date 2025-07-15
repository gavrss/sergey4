SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spInsert_Extension]

	@ApplicationID int = NULL,
	@Debug bit = 0,
	@JobID int = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--EXEC [spInsert_Extension] @ApplicationID = 400, @Debug = true
--EXEC [spInsert_Extension] @GetVersion = 1

--#WITH ENCRYPTION#--
AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@InstanceID int,
	@VersionID int,
	@ApplicationName nvarchar(100),
	@FeatureBM int = 0,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2136'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2013' SET @Description = 'Procedure created.'
		IF @Version = '1.4.0.2136' SET @Description = 'Test on Instance.SelectYN.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ApplicationID IS NULL
	BEGIN
		PRINT 'Parameter @ApplicationID must be set'
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
			@InstanceID = A.InstanceID,
			@VersionID = A.VersionID,
			@ApplicationName = A.ApplicationName
		FROM
			[Application] A 
		WHERE
			 A.ApplicationID = @ApplicationID

		SET @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		EXEC dbo.[spGet_Feature] @ApplicationID = @ApplicationID, @FeatureBM = @FeatureBM OUT

	SET @Step = 'Fill table Extension'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Extension]
			(
			InstanceID,
			VersionID,
			ExtensionName,
			ApplicationID,
			ExtensionTypeID,
			SelectYN
			)
		SELECT
			InstanceID = @InstanceID,
			VersionID = @VersionID,
			ExtensionName = REPLACE(ET.ExtensionName, '@ApplicationName', @ApplicationName),
			ApplicationID = @ApplicationID,
			ExtensionTypeID,
			SelectYN = 0
		FROM
			[ExtensionType] ET
		WHERE
			ET.SelectYN <> 0 AND
			ET.FeatureBM & @FeatureBM > 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Extension] E WHERE E.ExtensionName = REPLACE(ET.ExtensionName, '@ApplicationName', @ApplicationName))

		SELECT
			*
		FROM
			[pcINTEGRATOR_Data].[dbo].[Extension]
		WHERE
			ApplicationID = @ApplicationID

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH





GO
