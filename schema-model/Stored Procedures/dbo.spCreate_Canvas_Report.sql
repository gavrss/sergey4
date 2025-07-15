SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Canvas_Report]

	@ApplicationID int = NULL,
	@JobID int = 0,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_Canvas_Report] @ApplicationID = 400, @Debug = true

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@DestinationDatabase nvarchar(100),
	@SourceDatabase_pcEXCHANGE nvarchar(100),
	@SQLStatement nvarchar(max),
	@LanguageID int,
	@ModelBM int,
	@pcExchangeYN bit,
	@InstanceID int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2134'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.3.2070' SET @Description = 'Handle SourceTypeID = 6, pcEXCHANGE.'
		IF @Version = '1.3.2110' SET @Description = 'Adding column AuthorType to [WorkbookLibrary]. Updated handling of SourceTypeID = 6, bracket handling on database names.'
		IF @Version = '1.3.2112' SET @Description = 'Enhanced handling of AuthorType.'
		IF @Version = '1.3.0.2120' SET @Description = 'Only load AuthorType = ''C'' from pcEXCHANGE.'
		IF @Version = '1.4.0.2134' SET @Description = 'Only load InstanceID = 0 from pcINTEGRATOR.'

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
			@DestinationDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@LanguageID = LanguageID
		FROM
			[Application] A
		WHERE
			ApplicationID = @ApplicationID

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		IF (SELECT COUNT(1) FROM [Source] S INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0 WHERE S.SourceID > 0 AND S.SourceTypeID = 6 AND S.SelectYN <> 0) > 0
			SET @pcExchangeYN = 1
		ELSE
			SET @pcExchangeYN = 0

		IF @pcExchangeYN <> 0
			SELECT
				@SourceDatabase_pcEXCHANGE = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']'
			FROM
				[Source] S
				INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
			WHERE
				S.SourceID > 0 AND
				S.SourceTypeID = 6 AND
				S.SelectYN <> 0

	SET @Step = 'Create table [WorkbookLibrary] and/or column [AuthorType] if needed'
 		CREATE TABLE #Object
			(
			ObjectType nvarchar(100) COLLATE DATABASE_DEFAULT,
			ObjectName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		SET @SQLStatement = 'SELECT ObjectType = ''Table'', ObjectName = st.name FROM ' + @DestinationDatabase + '.sys.tables st WHERE st.name = ''WorkbookLibrary'''
		INSERT INTO #Object (ObjectType, ObjectName) EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = '#Object', * FROM #Object

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'WorkbookLibrary') = 0
			BEGIN
				SET @SQLStatement = '
					CREATE TABLE ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary]
						(
						[Label] [nvarchar](255) NOT NULL,
						[Contents] [image] NOT NULL,
						[ChangeDatetime] [datetime] NOT NULL,
						[Userid] [nvarchar](100) NULL,
						[Sec] [nvarchar](max) NOT NULL,
						[AuthorType] [nchar](1) NOT NULL 
						) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
				
					ALTER TABLE ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary] ADD CONSTRAINT [DF_WorkbookLibrary_Sec]  DEFAULT ('''') FOR [Sec]
					ALTER TABLE ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary] ADD CONSTRAINT [DF_WorkbookLibrary_AuthorType] DEFAULT (''C'') FOR [AuthorType]'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC(@SQLStatement)
			END

		SET @SQLStatement = 'SELECT ObjectType = ''Column'', ObjectName = c.name FROM ' + @DestinationDatabase + '.sys.tables T INNER JOIN ' + @DestinationDatabase + '.sys.columns C ON C.object_id = T.object_id AND C.name = ''AuthorType'' WHERE T.name = ''WorkbookLibrary'''
		INSERT INTO #Object (ObjectType, ObjectName) EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = '#Object', * FROM #Object

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Column' AND ObjectName = 'AuthorType') = 0
			BEGIN
				SET @SQLStatement = '
					ALTER TABLE ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary] 
					ADD [AuthorType] [nchar](1) NOT NULL 
					CONSTRAINT [DF_WorkbookLibrary_AuthorType] DEFAULT (''C'')'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC(@SQLStatement)
			END

		DROP TABLE #Object

	SET @Step = 'Create Cursor table'
		CREATE TABLE #ModelBM
			(
			ModelBM int
			)

		INSERT INTO #ModelBM
			(
			ModelBM
			)			
		SELECT
			BM.ModelBM 
		FROM 
			Model M 
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
		WHERE
			M.ApplicationID = @ApplicationID AND
			M.SelectYN <> 0

		IF @pcExchangeYN <> 0
			BEGIN
				SET @SQLStatement = '
				INSERT INTO #ModelBM
					(
					ModelBM
					)			
				SELECT
					M.ModelBM
				FROM
					' + @SourceDatabase_pcEXCHANGE + '.[dbo].[Model] SM
					INNER JOIN Model M ON M.[BaseModelID] = SM.[BaseModelID]'

				EXEC(@SQLStatement)
			END

	SET @Step = 'Cursor on Model that loads reports into the Destination database'
		DECLARE BaseModel_Cursor CURSOR FOR

		SELECT
			ModelBM 
		FROM 
			#ModelBM

		OPEN BaseModel_Cursor

		FETCH NEXT FROM BaseModel_Cursor INTO @ModelBM

		WHILE @@FETCH_STATUS = 0
			BEGIN
				--Replace any changed standard objects
				SET @SQLStatement = '
					UPDATE ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary]
					SET
		 				[Label] = R.[Label],
						[Contents] = R.[Contents],
						[ChangeDatetime] = R.[ChangeDatetime],
						[Userid] = R.[Userid],
						[Sec] = R.[Sec],
						[AuthorType] = R.[AuthorType]
 					FROM
						' + @DestinationDatabase + '.[dbo].[WorkbookLibrary] W
						INNER JOIN Report R ON R.Label = W.Label AND R.InstanceID = 0
					WHERE
						(R.LanguageID = ' + CONVERT(nvarchar, @LanguageID) + ' OR R.LanguageID = -1) AND
						R.ModelBM & ' + CONVERT(nvarchar, @ModelBM) + ' > 0 AND
						W.[AuthorType] <> ''C'''

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC(@SQLStatement)
				SET @Updated = @Updated + @@ROWCOUNT

				--Insert new objects if not exists.
				SET @SQLStatement = '
				INSERT INTO ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary]
					(
					[Label],
					[Contents],
					[ChangeDatetime],
					[Userid],
					[Sec],
					[AuthorType]
					)
				SELECT
		 			[Label] = R.[Label],
					[Contents] = R.[Contents],
					[ChangeDatetime] = R.[ChangeDatetime],
					[Userid] = R.[Userid],
					[Sec] = R.[Sec],
					[AuthorType] = R.[AuthorType]
 				FROM
					Report R
				WHERE
					R.InstanceID = 0 AND
					(R.LanguageID = ' + CONVERT(nvarchar, @LanguageID) + ' OR R.LanguageID = -1) AND
					R.ModelBM & ' + CONVERT(nvarchar, @ModelBM) + ' > 0 AND
					NOT EXISTS (SELECT 1 FROM ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary] W WHERE W.Label = R.Label)'
					
				IF @Debug <> 0 PRINT @SQLStatement
				EXEC(@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
					
				--Insert new objects of AuthorType 'E' as AuthorType 'C' if not exists.
				SET @SQLStatement = '
				INSERT INTO ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary]
					(
					[Label],
					[Contents],
					[ChangeDatetime],
					[Userid],
					[Sec],
					[AuthorType]
					)
				SELECT
		 			[Label] = REPLACE(R.[Label], ''Sample\'', ''''),
					[Contents] = R.[Contents],
					[ChangeDatetime] = R.[ChangeDatetime],
					[Userid] = R.[Userid],
					[Sec] = R.[Sec],
					[AuthorType] = ''C''
 				FROM
					Report R
				WHERE
					R.InstanceID = 0 AND
					(R.LanguageID = ' + CONVERT(nvarchar, @LanguageID) + ' OR R.LanguageID = -1) AND
					R.ModelBM & ' + CONVERT(nvarchar, @ModelBM) + ' > 0 AND
					R.[AuthorType] = ''E'' AND
					NOT EXISTS (SELECT 1 FROM ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary] W WHERE W.Label = REPLACE(R.[Label], ''Sample\'', ''''))'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC(@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT

				FETCH NEXT FROM BaseModel_Cursor INTO @ModelBM
			END

		CLOSE BaseModel_Cursor
		DEALLOCATE BaseModel_Cursor

	SET @Step = 'Add reports from pcOBJECT'	
		IF OBJECT_ID (N'pcOBJECT..WorkbookLibrary', N'U') IS NOT NULL 
			BEGIN
				SET @SQLStatement = '
				INSERT INTO ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary]
					(
					[Label],
					[Contents],
					[ChangeDatetime],
					[Userid],
					[Sec],
					[AuthorType]
					)
				SELECT
		 			[Label],
					[Contents],
					[ChangeDatetime],
					[Userid],
					[Sec],
					[AuthorType] = ''O''
 				FROM
					pcOBJECT..WorkbookLibrary R
				WHERE
					R.SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary] W WHERE W.Label = R.Label)'

				EXEC(@SQLStatement)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Add reports from pcExchange'	
		IF @pcExchangeYN <> 0 
			BEGIN
				SET @SQLStatement = '
				INSERT INTO ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary]
					(
					Label,
					Contents,
					ChangeDatetime,
					Userid,
					Sec
					)
				SELECT
		 			Label,
					Contents,
					ChangeDatetime,
					Userid,
					Sec
 				FROM
					' + @SourceDatabase_pcEXCHANGE + '.dbo.[WorkbookLibrary] R
				WHERE
					R.AuthorType = ''C'' AND
					R.SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM ' + @DestinationDatabase + '.[dbo].[WorkbookLibrary] W WHERE W.Label = R.Label)'

				EXEC(@SQLStatement)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Drop temp tables'	
		DROP TABLE #ModelBM

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
