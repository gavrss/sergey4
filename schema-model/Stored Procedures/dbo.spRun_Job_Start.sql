SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spRun_Job_Start]

@UserID int = NULL,
@InstanceID int = NULL,
@VersionID int = NULL,
@GetVersion bit = 0,
@Duration time(7) = '00:00:00' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT,
@Debug bit = 0

--#WITH ENCRYPTION#--

AS

--EXEC [spRun_Job_Start] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@JobID int = -1,
	@SQLStatement nvarchar(max),
	@MasterCommand nvarchar(1024),
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
			'EXEC [spRun_Job_Start] ' +
			'@UserID = ' + ISNULL(CONVERT(nvarchar(10), @UserID), 'NULL') + ', ' +
			'@InstanceID = ' + ISNULL(CONVERT(nvarchar(10), @InstanceID), 'NULL') + ', ' +
			'@VersionID = ' + ISNULL(CONVERT(nvarchar(10), @VersionID), 'NULL') + ', '
			
		SET @Parameter = LEFT(@Parameter, LEN(@Parameter) - 1)

	SET @Step = 'Close timed out jobs'
		UPDATE J
		SET
			ClosedYN = 1
		FROM
			Job J
		WHERE
			InstanceID = @InstanceID AND
			ClosedYN = 0 AND 
			StartTime IS NOT NULL AND 
			EndTime IS NULL AND 
			StartTime + CONVERT(datetime, [TimeOut]) < GetDate() 

	SET @Step = 'Run Job_Start_Cursor'
		IF (
			SELECT COUNT(1) FROM 
				Job J
			WHERE
				InstanceID = @InstanceID AND
				StartTime IS NOT NULL AND
				ClosedYN = 0  
			) = 0
			BEGIN	 
				DECLARE Job_Start_Cursor CURSOR FOR
					SELECT
						JobID, 
						MasterCommand 
					FROM 
						Job 
					WHERE
						InstanceID = @InstanceID AND 
						StartTime IS NULL AND 
						ClosedYN = 0 
					ORDER BY
						JobID

					OPEN Job_Start_Cursor
					FETCH NEXT FROM Job_Start_Cursor INTO @JobID, @MasterCommand

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @Debug <> 0 SELECT JobID = @JobID, MasterCommand = @MasterCommand
							SET @SQLStatement = 'EXEC ' + @MasterCommand + 
												' @UserID = ' + CONVERT(nvarchar(10), @UserID) + 
												', @InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + 
												', @VersionID = ' + CONVERT(nvarchar(10), @VersionID) +
												', @JobID = ' + CONVERT(nvarchar(10), @JobID)

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							FETCH NEXT FROM Job_Start_Cursor INTO @JobID, @MasterCommand
						END

				CLOSE Job_Start_Cursor
				DEALLOCATE Job_Start_Cursor	
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version], [Parameter], [UserName]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version, @Parameter, @UserName

END TRY

BEGIN CATCH
	UPDATE Job SET ErrorTime = GetDate(), ClosedYN = 1 WHERE JobID = @JobID
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version], [Parameter], [UserName]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version, @Parameter, @UserName
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH
GO
