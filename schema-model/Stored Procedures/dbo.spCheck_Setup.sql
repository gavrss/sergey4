SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCheck_Setup] 

	@JobID int = 0,
	@InstanceID int = NULL,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC spCheck_Setup @InstanceID = 400, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Rows int,
	@pcINTEGRATOR_Error nvarchar(max) = '',
	@pcETL_Error nvarchar(max) = '',
	@LimitedRows nvarchar(max) = '',
	@CheckSum nvarchar(max) = '',
	@JobName nvarchar(100),
	@ETLDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@CheckSumError int,
	@CheckSumID int,
	@CheckSumName nvarchar(50),
	@CheckSumDescription nvarchar(255),
	@CheckSumValue int,
	@CheckSumReport nvarchar(max),
	@JobID_ETL int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.2.2148'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.3.2106' SET @Description = 'Handle CheckSum.'
		IF @Version = '1.4.0.2136' SET @Description = 'Test on JobID in pcINTEGRATOR..JobLog. Updated in SPs until spCreate_Dimension_Procedure_Generic (Alphabetic order).'
		IF @Version = '1.4.0.2137' SET @Description = 'Test on JobID in pcINTEGRATOR..JobLog. JobID set to InstanceID when JobID defaulted to 0.'
		IF @Version = '2.0.2.2148' SET @Description = 'Match table definition for temp table #JobLog to @ETLDatabase..JobLog.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @InstanceID IS NULL
	BEGIN
		PRINT 'Parameter @InstanceID must be set'
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
			@Rows = I.[Rows],
			@JobName = A.DestinationDatabase + '_Load',
			@ETLDatabase = A.ETLDatabase
		FROM
			Instance I
			INNER JOIN [Application] A ON A.InstanceID = I.InstanceID AND A.SelectYN <> 0
		WHERE
			I.InstanceID = @InstanceID

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		IF @Debug <> 0
			SELECT
				[Rows] = @Rows,
				JobName = @JobName,
				ETLDatabase = @ETLDatabase

	SET @Step = 'pcINTEGRATOR'
		IF (SELECT COUNT(1) FROM JobLog WHERE JobID = @JobID AND ErrorNumber <> 0) = 0
			SET @pcINTEGRATOR_Error = 'No errors occurred during the phase when new objects were created.' + CHAR(13) + CHAR(10)
		ELSE
			BEGIN
				SET @pcINTEGRATOR_Error = 'The following errors occurred during the phase when new objects were created:'

				SELECT @pcINTEGRATOR_Error = @pcINTEGRATOR_Error + CHAR(13) + CHAR(10) + 'The procedure ' + ProcedureName + ' got the following error; (' + CONVERT(nvarchar(10), ErrorNumber) + ') ' + ErrorMessage FROM JobLog WHERE ErrorNumber <> 0

				SET @pcINTEGRATOR_Error = @pcINTEGRATOR_Error + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 'The complete JobLog can be seen in the table JobLog in the database pcINTEGRATOR.' + CHAR(13) + CHAR(10)
			END

		--Create #JobLog
		CREATE TABLE [dbo].[#JobLog]
		(
			[JobID] [int] NOT NULL,
			[JobLogID] [int] NOT NULL,
			[StartTime] [datetime] NOT NULL,
			[ProcedureName] [nvarchar](100) NOT NULL,
			[Duration] [time](7) NOT NULL,
			[Deleted] [int] NOT NULL,
			[Inserted] [int] NOT NULL,
			[Updated] [int] NOT NULL,
			[Selected] [INT] NOT NULL,
			[ErrorNumber] [int] NOT NULL,
			[ErrorSeverity] [int] NULL,
			[ErrorState] [int] NULL,
			[ErrorProcedure] [nvarchar](128) NULL,
			[ErrorStep] [nvarchar](255) NULL,
			[ErrorLine] [int] NULL,
			[ErrorMessage] [nvarchar](4000) NULL,
			[Version] [nvarchar](100) NULL,
			[Parameter] [nvarchar] (4000) NULL,
			[UserName] [nvarchar] (100) NULL,
			[UserID] [int] NULL,
			[InstanceID] [int] NULL,
			[VersionID] [int] NULL
		)

		SET @SQLStatement = 'INSERT INTO #JobLog SELECT * FROM ' + @ETLDatabase + '.dbo.JobLog WHERE ErrorNumber <> 0 OR Inserted = ' + CONVERT(nvarchar(10), @Rows)
		EXEC (@SQLStatement)

	SET @Step = 'pcETL'
		IF (SELECT COUNT(1) FROM #JobLog WHERE ErrorNumber <> 0) = 0
			SET @pcETL_Error = CHAR(13) + CHAR(10) + 'No errors occurred during the phase when rows were loaded from the source.' + CHAR(13) + CHAR(10)
		ELSE
			BEGIN
				SET @pcETL_Error = CHAR(13) + CHAR(10) + 'The following errors occurred during the phase when rows were loaded from the source:'

				SELECT @pcETL_Error = @pcETL_Error + CHAR(13) + CHAR(10) + 'The procedure ' + ProcedureName + ' got the following error; (' + CONVERT(nvarchar(10), ErrorNumber) + ') ' + ErrorMessage FROM #JobLog WHERE ErrorNumber <> 0

				SET @pcETL_Error = @pcETL_Error + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 'The complete JobLog can be seen in the table JobLog in the database ' + @ETLDatabase + '.' + CHAR(13) + CHAR(10)
			END

	SET @Step = 'Get LimitedRows info'
		SELECT 
			S.SourceID,
			S.SourceName,
			[Procedure] = CASE WHEN CHARINDEX('(', ProcedureName) = 0 THEN ProcedureName ELSE SUBSTRING(ProcedureName, 1, CHARINDEX('(', ProcedureName) - 2) END,
			ObjectType = CASE WHEN CHARINDEX('FACT', ProcedureName) = 0 THEN 'dimension' ELSE 'model' END,
			[Object] = CASE WHEN CHARINDEX('FACT', ProcedureName) = 0 THEN CASE WHEN CHARINDEX('(', ProcedureName) = 0 THEN SUBSTRING(ProcedureName, 11, LEN(ProcedureName) -10) ELSE SUBSTRING(ProcedureName, CHARINDEX('(', ProcedureName) + 1, CHARINDEX(')', ProcedureName) - CHARINDEX('(', ProcedureName) - 1) END ELSE CASE WHEN CHARINDEX('(', ProcedureName) = 0 THEN SUBSTRING(ProcedureName, 16, LEN(ProcedureName) -15) ELSE SUBSTRING(ProcedureName, 16, CHARINDEX('(', ProcedureName) - 17) END END,
			Entity = CASE WHEN CHARINDEX('FACT', ProcedureName) <> 0 AND CHARINDEX('(', ProcedureName) <> 0 THEN SUBSTRING(ProcedureName, CHARINDEX('(', ProcedureName) + 1, CHARINDEX(')', ProcedureName) - CHARINDEX('(', ProcedureName) - 1) ELSE '' END
		INTO
			#LimitedRows
		FROM
			#JobLog JL
			INNER JOIN [Source] S ON S.SourceID = CONVERT(int, SUBSTRING(JL.ProcedureName, 6, 4))
		WHERE
			Inserted = @Rows

		IF @Debug <> 0 SELECT * FROM #LimitedRows

		SELECT 
			@LimitedRows = @LimitedRows + CHAR(13) + CHAR(10) + 'The stored procedure ' + [Procedure] + ' just inserted the first ' + CONVERT(nvarchar(10), @Rows) + ' rows from source ' + SourceName + ' (' + CONVERT(nvarchar(10), SourceID) + ') into the ' + ObjectType + ' ' + [Object] + CASE WHEN Entity = '' THEN '' ELSE ' regarding Entity ' + Entity END + '.'
		FROM
			#LimitedRows

		IF LEN(@LimitedRows) > 0 
			SELECT @LimitedRows = @LimitedRows + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 'To get a complete load, wait for the night load that by default will start 2 PM every night, or manually start the job ' + @JobName + ' in SQL Server Agent.'

	SET @Step = 'Get CheckSum info'
		CREATE TABLE #JobID (JobID int)
		SET @SQLStatement = 'INSERT INTO #JobID (JobID) SELECT JobID = ISNULL(MAX(JobID), 0) FROM ' + @ETLDatabase + '..[Job]'
		EXEC (@SQLStatement)
		SELECT @JobID_ETL = JobID FROM #JobID
		DROP TABLE #JobID

		CREATE TABLE #CheckSumError (CheckSumError int)
		SET @SQLStatement = 'INSERT INTO #CheckSumError (CheckSumError) SELECT CheckSumError = COUNT(1) FROM ' + @ETLDatabase + '..[CheckSumLog] WHERE JobID = ' + CONVERT(nvarchar(10), @JobID_ETL) + ' AND CheckSumValue <> 0'
		EXEC (@SQLStatement)
		SELECT @CheckSumError = CheckSumError FROM #CheckSumError
		DROP TABLE #CheckSumError

		IF @Debug <> 0 SELECT JobID = @JobID, ETLDatabase = @ETLDatabase, JobID_ETL = @JobID_ETL, CheckSumError = @CheckSumError

		IF @CheckSumError > 0
			BEGIN
				CREATE TABLE #CheckSumCursor ([CheckSumID] int, [CheckSumName] nvarchar(50), [CheckSumDescription] nvarchar(255), [CheckSumValue] int, [CheckSumReport] nvarchar(max), SortOrder int)
				SET @SQLStatement = 'INSERT INTO #CheckSumCursor ([CheckSumID], [CheckSumName], [CheckSumDescription], [CheckSumValue], [CheckSumReport], SortOrder) SELECT CSL.[CheckSumID], CS.[CheckSumName], CS.[CheckSumDescription], CSL.[CheckSumValue], CS.[CheckSumReport], CS.[SortOrder] FROM ' + @ETLDatabase + '..[CheckSumLog] CSL INNER JOIN ' + @ETLDatabase + '..[CheckSum] CS ON CS.CheckSumID = CSL.CheckSumID AND CS.SelectYN <> 0 WHERE CSL.[JobID] = ' + CONVERT(nvarchar(10), @JobID_ETL) + ' AND CSL.[CheckSumValue] <> 0'
				EXEC (@SQLStatement)

				DECLARE CheckSum_Cursor CURSOR FOR

					SELECT 
						[CheckSumID],
						[CheckSumName],
						[CheckSumDescription],
						[CheckSumValue],
						[CheckSumReport]
					FROM
						#CheckSumCursor
					ORDER BY
						SortOrder

					OPEN CheckSum_Cursor
					FETCH NEXT FROM CheckSum_Cursor INTO @CheckSumID, @CheckSumName, @CheckSumDescription, @CheckSumValue, @CheckSumReport

					WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @CheckSum = @CheckSum + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 'The CheckSum ' + @CheckSumName + ' gives ' + CONVERT(nvarchar(10), @CheckSumValue) + ' error(s).' + CHAR(13) + CHAR(10) + @CheckSumDescription + CHAR(13) + CHAR(10) + 'Run this SQL query to see what is causing the error:' + CHAR(13) + CHAR(10) + @CheckSumReport
							FETCH NEXT FROM CheckSum_Cursor INTO @CheckSumID, @CheckSumName, @CheckSumDescription, @CheckSumValue, @CheckSumReport
						END

				CLOSE CheckSum_Cursor
				DEALLOCATE CheckSum_Cursor
			
				DROP TABLE #CheckSumCursor
			END
		ELSE
			SELECT @CheckSum = CHAR(13) + CHAR(10) + 'There are no CheckSum Errors'

	SET @Step = 'Set Return messages'	
		PRINT  @pcINTEGRATOR_Error + @pcETL_Error + @LimitedRows + @CheckSum

		SELECT SetupMessage = @pcINTEGRATOR_Error + @pcETL_Error + @LimitedRows + @CheckSum

	SET @Step = 'Drop temp tables'	
		DROP TABLE #JobLog
		DROP TABLE #LimitedRows

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
