SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Job]

@UserID int = NULL,
@InstanceID int = NULL,
@VersionID int = NULL,
@MasterCommand nvarchar(100) = '[spRun_Job]',
@MasterParameter nvarchar(1024) = NULL,
@TimeOut time(7) = '3:00:00',
@JobID int = NULL OUT,
@GetVersion bit = 0,
@Duration time(7) = '00:00:00' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT,
@Debug bit = 0

--#WITH ENCRYPTION#--

AS

--EXEC [spCreate_Job] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @MasterParameter = '@JobStepList = ''1,2,3'''

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@DatabaseName nvarchar(100),
	@Command nvarchar(100),
	@Parameter nvarchar(4000),
	@UserName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SET @Parameter = 
			'EXEC [spCreate_Job] ' +
			'@UserID = ' + ISNULL(CONVERT(nvarchar(10), @UserID), 'NULL') + ', ' +
			'@InstanceID = ' + ISNULL(CONVERT(nvarchar(10), @InstanceID), 'NULL') + ', ' +
			'@VersionID = ' + ISNULL(CONVERT(nvarchar(10), @VersionID), 'NULL') + ', ' +
			CASE WHEN @MasterCommand IS NOT NULL THEN '@MasterCommand = ''' + @MasterCommand + ''', ' ELSE 'NULL' END +
			CASE WHEN @MasterParameter IS NOT NULL THEN '@MasterParameter = ''' + @MasterParameter + ''', ' ELSE 'NULL' END
			
		SET @Parameter = LEFT(@Parameter, LEN(@Parameter) - 1)

	SET @Step = 'Insert new row into Job table'
		INSERT INTO [dbo].[Job]
			(
			[InstanceID],
			[MasterCommand],
			[TimeOut]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[MasterCommand] = @MasterCommand + CASE WHEN @MasterParameter IS NOT NULL THEN ' ' + @MasterParameter + ',' ELSE '' END,
			[TimeOut] = @TimeOut

		SELECT
			@JobID = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version], [Parameter], [UserName]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version, @Parameter, @UserName

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version], [Parameter], [UserName]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version, @Parameter, @UserName
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH
GO
