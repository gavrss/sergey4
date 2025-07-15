SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_StepXML] 

	@JobID int = 0,
	@InstanceID int = NULL,
	@Param_02 nvarchar(100) = NULL OUT, --@InstanceID
	@ApplicationID int = NULL,
	@StepType int = NULL,
	@Debug bit = 0,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--

AS

--EXEC spGet_StepXML @InstanceID = 400, @StepType = 1, @Debug = 1
--EXEC spGet_StepXML @InstanceID = 400, @StepType = 2, @Debug = 1
--EXEC spGet_StepXML @InstanceID = 52, @StepType = 1024, @Debug = 1
--EXEC spGet_StepXML @InstanceID = 52, @Debug = 1
--EXEC spGet_StepXML @InstanceID = 400, @StepType = 1024, @Param_02 = 52, @Debug = 1
/*
DECLARE
	@Param_02 nvarchar(100) = '52'
EXEC spGet_StepXML @InstanceID = 400, @StepType = 1024, @Param_02 = @Param_02 OUT, @Debug = 1

SELECT Param_02 = @Param_02
*/


DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@ApplicationName nvarchar(100),
	@ETLDatabase nvarchar(100),
	@Rows int,
	@StepID int,
	@Counter int,
	@SelectCheck nvarchar(1000),
	@SelectYN bit,
	@Message nvarchar(500),
	@Severity int,
	@Description nvarchar(255),
	@Version nvarchar(100) = '1.4.0.2126'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2076' SET @Description = 'Procedure created'
		IF @Version = '1.3.2078' SET @Description = 'Added cursor for multiple Applications'
		IF @Version = '1.3.2080' SET @Description = 'Test when @ApplicationID is set, Check on Omitted'
		IF @Version = '1.3.2104' SET @Description = 'Check on Warning and filter on @StepType.'
		IF @Version = '1.3.2110' SET @Description = 'Clustered index added on the TempTable #StepXML.'
		IF @Version = '1.3.1.2121' SET @Description = 'Added dynamic Params.'
		IF @Version = '1.3.1.2122' SET @Description = 'RAISERROR @ EXITPOINT.'
		IF @Version = '1.3.1.2123' SET @Description = 'Removed GetParam-function.'
		IF @Version = '1.4.0.2126' SET @Description = 'Removed application specific parameters from StepLevel 1 and 3.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @InstanceID IS NULL OR @StepType IS NULL
	BEGIN
		SET @Message = 'Parameter @InstanceID and parameter @StepType must be set.'
		SET @Severity = 16
		GOTO EXITPOINT
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

		SET @InstanceID = ISNULL(@Param_02, @InstanceID)
		SET @Param_02 = @InstanceID

		IF @Debug <> 0 SELECT InstanceID = @InstanceID, Param_02 = @Param_02, [Version] = @Version

		SELECT 
			@Rows = I.[Rows]
		FROM
			Instance I
		WHERE
			I.InstanceID = @InstanceID

		SELECT 
			@Counter = COUNT(1)
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			(A.ApplicationID = @ApplicationID OR @ApplicationID IS NULL) AND
			A.ApplicationID > 0 AND
			A.SelectYN <> 0

	SET @Step = 'Create temp table #StepXML'
		CREATE TABLE #StepXML
			(
			[StepID] int,
			[StepType] int,
			[ParamBM] int,
			[Name] nvarchar(100),
			[Description] nvarchar(1000),
			[HelpUrl] nvarchar(100),
			[FormName] nvarchar(50),
			[FormParameter] nvarchar(255),
			[Database] nvarchar(100),
			[Command] nvarchar(255),
			[SelectCheck] nvarchar(1000),
		CONSTRAINT [PK_Application] PRIMARY KEY CLUSTERED 
		(
			[StepID] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]

	SET @Step = 'Insert into StepXML where StepLevel = 1' --StepLevel 1 is running before Application specific tasks.
		INSERT INTO #StepXML
			(
			[StepID],
			[StepType],
			[ParamBM],
			[Name],
			[Description],
			[HelpUrl],
			[FormName],
			[FormParameter],
			[Database],
			[Command],
			[SelectCheck]
			)
		SELECT
			[StepID] = X.[StepID],
			[StepType] = X.[StepTypeBM],
			[ParamBM] = X.[ParamBM],
			[Name] = X.[Name],
			[Description] = X.[Description],
			[HelpUrl] = X.[HelpUrl],
			[FormName] = X.[FormName],
			[FormParameter] = REPLACE(X.[FormParameter], '@StepTypeBM_Replace', @StepType),
			[Database] = X.[Database],
			[Command] = REPLACE(REPLACE(REPLACE(X.[Command], '@InstanceID_Replace', @InstanceID), '@Rows_Replace', @Rows), '@JobID_Replace', @StepType),
			[SelectCheck] = REPLACE(REPLACE(REPLACE(X.[SelectCheck], '@InstanceID_Replace', @InstanceID), '@Version_Replace', @Version), '@StepTypeBM_Replace', @StepType)
		FROM
			StepXML X
		WHERE
			X.StepTypeBM & @StepType > 0 AND
			X.StepLevel = 1 AND
			X.Introduced < @Version AND
			X.Omitted > @Version AND
			X.SelectYN <> 0
		ORDER BY
			X.[StepID]

	SET @Step = 'Create StepXML_Application_Cursor' --StepLevel 2 are Application specific tasks.
		DECLARE StepXML_Application_Cursor CURSOR FOR

			SELECT 
				A.ApplicationID,
				A.ApplicationName,
				A.ETLDatabase
			FROM
				[Application] A
			WHERE
				A.InstanceID = @InstanceID AND
				(A.ApplicationID = @ApplicationID OR @ApplicationID IS NULL) AND
				A.ApplicationID > 0 AND
				A.SelectYN <> 0
			ORDER BY
				A.ApplicationID

			OPEN StepXML_Application_Cursor
			FETCH NEXT FROM StepXML_Application_Cursor INTO @ApplicationID, @ApplicationName, @ETLDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					INSERT INTO #StepXML
						(
						[StepID],
						[StepType],
						[ParamBM],
						[Name],
						[Description],
						[HelpUrl],
						[FormName],
						[FormParameter],
						[Database],
						[Command],
						[SelectCheck]
						)
					SELECT
						[StepID] = CASE WHEN @Counter > 1 THEN @ApplicationID * 100000 + X.[StepID] ELSE X.[StepID] END,
						[StepType] = X.[StepTypeBM],
						[ParamBM] = X.[ParamBM],
						[Name] = CASE WHEN @Counter > 1 THEN @ApplicationName + ' - ' ELSE '' END + X.[Name],
						[Description] = X.[Description],
						[HelpUrl] = X.[HelpUrl],
						[FormName] = X.[FormName],
						[FormParameter] = REPLACE(REPLACE(X.[FormParameter], '@ApplicationID_Replace', @ApplicationID), '@StepTypeBM_Replace', @StepType),
						[Database] = REPLACE(X.[Database], '@ETLDatabase_Replace', @ETLDatabase),
						[Command] = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(X.[Command], '@ETLDatabase_Replace', @ETLDatabase), '@ApplicationID_Replace', @ApplicationID), '@InstanceID_Replace', @InstanceID), '@Rows_Replace', @Rows), '@JobID_Replace', @StepType),
						[SelectCheck] = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(X.[SelectCheck], '@ETLDatabase_Replace', @ETLDatabase), '@ApplicationID_Replace', @ApplicationID), '@InstanceID_Replace', @InstanceID), '@Version_Replace', @Version), '@StepTypeBM_Replace', @StepType)
					FROM
						StepXML X
					WHERE
						X.StepTypeBM & @StepType > 0 AND
						X.StepLevel = 2 AND
						X.Introduced < @Version AND
						X.Omitted > @Version AND
						X.SelectYN <> 0
					ORDER BY
						CASE WHEN @Counter > 1 THEN @ApplicationID * 100000 + X.[StepID] ELSE X.[StepID] END

					FETCH NEXT FROM StepXML_Application_Cursor INTO @ApplicationID, @ApplicationName, @ETLDatabase
				END

		CLOSE StepXML_Application_Cursor
		DEALLOCATE StepXML_Application_Cursor		

	SET @Step = 'Insert into StepXML where StepLevel = 3' --StepLevel 3 is running after Application specific tasks.
		INSERT INTO #StepXML
			(
			[StepID],
			[StepType],
			[ParamBM],
			[Name],
			[Description],
			[HelpUrl],
			[FormName],
			[FormParameter],
			[Database],
			[Command],
			[SelectCheck]
			)
		SELECT
			[StepID] = CASE WHEN @Counter > 1 THEN @ApplicationID * 100000 + X.[StepID] ELSE X.[StepID] END,
			[StepType] = X.[StepTypeBM],
			[ParamBM] = X.[ParamBM],
			[Name] = X.[Name],
			[Description] = X.[Description],
			[HelpUrl] = X.[HelpUrl],
			[FormName] = X.[FormName],
			[FormParameter] = REPLACE(X.[FormParameter], '@StepTypeBM_Replace', @StepType),
			[Database] = X.[Database],
			[Command] = REPLACE(REPLACE(REPLACE(X.[Command], '@InstanceID_Replace', @InstanceID), '@Rows_Replace', @Rows), '@JobID_Replace', @StepType),
			[SelectCheck] = REPLACE(REPLACE(REPLACE(X.[SelectCheck], '@InstanceID_Replace', @InstanceID), '@Version_Replace', @Version), '@StepTypeBM_Replace', @StepType)
		FROM
			StepXML X
		WHERE
			X.StepTypeBM & @StepType > 0 AND
			X.StepLevel = 3 AND
			X.Introduced < @Version AND
			X.Omitted > @Version AND
			X.SelectYN <> 0
		ORDER BY
			CASE WHEN @Counter > 1 THEN @ApplicationID * 100000 + X.[StepID] ELSE X.[StepID] END

		IF @Debug <> 0 SELECT TempTable = '#StepXML', * FROM #StepXML

	SET @Step = 'Update Instance table'
		IF @StepType & 1 > 0 
			UPDATE
				[Instance]
			SET
				StepXML = (SELECT [StepID], [StepType], [ParamBM], [Name], [Description], [HelpUrl], [FormName], [FormParameter], [Database], [Command], [SelectCheck] FROM #StepXML FOR XML RAW, ROOT('table'))
			WHERE
				InstanceID = @InstanceID

	SET @Step = 'Return XML string'
		IF @StepType & 1 > 0 
			SELECT
				StepXML
			FROM
				[Instance]
			WHERE
				InstanceID = @InstanceID
		ELSE
			SELECT StepXML = (SELECT [StepID], [StepType], [ParamBM], [Name], [Description], [HelpUrl], [FormName], [FormParameter], [Database], [Command], [SelectCheck] FROM #StepXML FOR XML RAW, ROOT('table'))

	SET @Step = 'Drop temp table'
		DROP TABLE #StepXML

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

SET @Step = 'EXITPOINT:'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100) WITH NOWAIT




GO
