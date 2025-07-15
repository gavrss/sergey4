SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spCreate_Linked_ETL_Procedure]

	@ApplicationID int = NULL,
	@JobID int = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

SET NOCOUNT ON

--EXEC [spCreate_Linked_ETL_Procedure] @ApplicationID = 400, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@InstanceID int,
	@SQLStatement nvarchar(max),
	@SQLStatement1 nvarchar(max) = '',
	@SQLStatement2 nvarchar(max) = '',
	@ETLDatabase nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@LanguageID int,
	@iScalaYN bit,
	@ETLDatabase_Linked nvarchar(100),
	@ETLDatabase_Linked_Filter nvarchar(100),
	@SourceDatabase nvarchar(100),
	@OptFinanceDimYN bit,
	@SourceID_varchar nvarchar(10),
	@SourceDatabase_Local nvarchar(100),
	@LinkedServer nvarchar(100),
	@ProcedureName nvarchar(100),
	@Action nvarchar(10),
	@Counter int,
	@TotalCount int,
 	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.0.2140'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2076' SET @Description = 'Procedure created'
		IF @Version = '1.3.2078' SET @Description = 'Fixed source bug for Account_TimeBalance'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption. Added Time and MappedLabel.'
		IF @Version = '1.3.2094' SET @Description = 'Added brackets around @ETLDatabase_Linked.'
		IF @Version = '1.3.2095' SET @Description = 'Added extra variable for @ETLDatabase_Linked where brackets are not added, Used for filtering (@ETLDatabase_Linked_Filter). Added Scenario and TransactionType_iScala.'
		IF @Version = '1.3.2096' SET @Description = 'Added AccountType and AccountType_Translate. Added vw_XXXX_Dimension_Finance_Metadata'
		IF @Version = '1.3.2098' SET @Description = 'Replaced vw_XXXX_Dimension_Finance_Metadata with FinancialSegment. Added MappedObject.'
		IF @Version = '1.3.0.2118' SET @Description = 'Check on Application.SelectYN.'
		IF @Version = '2.0.0.2140' SET @Description = 'Loading of Account_TimeBalance is now more fault tolerant when AccountTypes are not set in Account'

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
			@ETLDatabase = ETLDatabase,
			@DestinationDatabase = DestinationDatabase,
			@LanguageID = LanguageID,
			@InstanceID = InstanceID
		FROM
			[Application]
		WHERE
			ApplicationID = @ApplicationID AND
			SelectYN <> 0

		IF
			(
			SELECT
			 COUNT(S.SourceID) 
			FROM
			 [Application] A
			 INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.Introduced < @Version AND M.SelectYN <> 0
			 INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0 AND S.SourceTypeID = 3 --iScala
			WHERE
			 A.InstanceID = @InstanceID AND
			 A.SelectYN <> 0
			)
			> 0 SET @iScalaYN = 1 ELSE SET @iScalaYN = 0

	SET @Step = 'Create temp tables'
		CREATE TABLE #Source
			(
			ID int IDENTITY(1, 1),
			SourceDatabase nvarchar(100) COLLATE DATABASE_DEFAULT,
			ETLDatabase_Linked nvarchar(100) COLLATE DATABASE_DEFAULT,
			ETLDatabase_Linked_Filter nvarchar(100) COLLATE DATABASE_DEFAULT,
			OptFinanceDimYN bit
			)

		CREATE TABLE #Action
			(
			[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Fill and update temp tables'
		INSERT INTO #Source
			(
			SourceDatabase,
			ETLDatabase_Linked,
			ETLDatabase_Linked_Filter,
			OptFinanceDimYN
			)
		SELECT DISTINCT
			SourceDatabase = S.SourceDatabase,
			ETLDatabase_Linked = '[' + REPLACE(REPLACE(REPLACE(S.ETLDatabase_Linked, '[', ''), ']', ''), '.', '].[') + ']',
			ETLDatabase_Linked_Filter = S.ETLDatabase_Linked,
			OptFinanceDimYN = CONVERT(bit, MAX(CONVERT(int, BM.[OptFinanceDimYN])))
		FROM
			[Source] S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0 
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0 
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.SelectYN <> 0 
		WHERE
			S.SourceDatabase LIKE '%.%' AND
			S.SelectYN <> 0 
		GROUP BY
			S.SourceDatabase,
			S.ETLDatabase_Linked
		ORDER BY
			ETLDatabase_Linked

		IF @Debug <> 0 SELECT * FROM #Source

		IF (SELECT COUNT(1) FROM #Source) = 0
			GOTO EXITPOINT

	SET @Step = 'Create Linked_Insert_Cursor'

		SELECT @TotalCount = COUNT(1) FROM #Source

		DECLARE Linked_Insert_Cursor CURSOR FOR

			SELECT DISTINCT
				ID,
				ETLDatabase_Linked,
				ETLDatabase_Linked_Filter,
				OptFinanceDimYN
			FROM
				#Source
			ORDER BY
				ID

			OPEN Linked_Insert_Cursor
			FETCH NEXT FROM Linked_Insert_Cursor INTO @Counter, @ETLDatabase_Linked, @ETLDatabase_Linked_Filter, @OptFinanceDimYN

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement1 = @SQLStatement1 + '

		--==================================================================================--
		-- Start of Insert Procedure for ' + @ETLDatabase_Linked + '
		-- Linked ETL database ' + CONVERT(nvarchar(10), @Counter) + ' of ' + CONVERT(nvarchar(10), @TotalCount) + '
		--==================================================================================--

	SET @Step = ''BudgetSelection''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[BudgetSelection]
		
		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[BudgetSelection]''

		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[BudgetSelection]
			(
			[SourceID],
			[EntityCode],
			[BudgetCode],
			[Scenario],
			[SelectYN]
			)
		SELECT
			BS.[SourceID],
			BS.[EntityCode],
			BS.[BudgetCode],
			BS.[Scenario],
			BS.[SelectYN]
		FROM
			[BudgetSelection] BS
			INNER JOIN pcINTEGRATOR..Source S ON S.SourceID = BS.SourceID AND S.ETLDatabase_Linked = ''' + @ETLDatabase_Linked_Filter + ''' AND S.SelectYN <> 0
			
		SET @Inserted = @Inserted + @@ROWCOUNT
		'

					SET @SQLStatement1 = @SQLStatement1 + '

	SET @Step = ''ClosedPeriod''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[ClosedPeriod]

		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[ClosedPeriod]''
		
		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[ClosedPeriod]
			(
			[SourceID],
			[EntityCode],
			[TimeFiscalYear],
			[TimeFiscalPeriod],
			[TimeYear],
			[TimeMonth],
			[BusinessProcess],
			[ClosedPeriod],
			[ClosedPeriod_Counter],
			[UpdateYN],
			[Updated],
			[UpdatedBy]
			)
		SELECT
			CP.[SourceID],
			CP.[EntityCode],
			CP.[TimeFiscalYear],
			CP.[TimeFiscalPeriod],
			CP.[TimeYear],
			CP.[TimeMonth],
			CP.[BusinessProcess],
			CP.[ClosedPeriod],
			CP.[ClosedPeriod_Counter],
			CP.[UpdateYN],
			CP.[Updated],
			CP.[UpdatedBy]
		FROM
			[ClosedPeriod] CP
			INNER JOIN pcINTEGRATOR..Source S ON S.SourceID = CP.SourceID AND S.ETLDatabase_Linked = ''' + @ETLDatabase_Linked_Filter + ''' AND S.SelectYN <> 0
			
		SET @Inserted = @Inserted + @@ROWCOUNT
		'
		
					SET @SQLStatement1 = @SQLStatement1 + '

	SET @Step = ''Entity''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[Entity]

		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[Entity]''
		
		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[Entity]
			(
			[SourceID],
			[EntityCode],
			[Entity],
			[EntityName],
			[Currency],
			[EntityPriority],
			[SelectYN],
			[Par01],
			[Par02],
			[Par03],
			[Par04],
			[Par05],
			[Par06],
			[Par07],
			[Par08],
			[Par09],
			[Par10]
			)
		SELECT
			E.[SourceID],
			E.[EntityCode],
			E.[Entity],
			E.[EntityName],
			E.[Currency],
			E.[EntityPriority],
			E.[SelectYN],
			E.[Par01],
			E.[Par02],
			E.[Par03],
			E.[Par04],
			E.[Par05],
			E.[Par06],
			E.[Par07],
			E.[Par08],
			E.[Par09],
			E.[Par10]
		FROM
			[Entity] E
			INNER JOIN pcINTEGRATOR..Source S ON S.SourceID = E.SourceID AND S.ETLDatabase_Linked = ''' + @ETLDatabase_Linked_Filter + ''' AND S.SelectYN <> 0
			
		SET @Inserted = @Inserted + @@ROWCOUNT
		'

					SET @SQLStatement1 = @SQLStatement1 + '

	SET @Step = ''MemberSelection''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[MemberSelection]

		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[MemberSelection]''

		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[MemberSelection]
			(
			[DimensionID],
			[Label],
			[SelectYN]
			)
		SELECT
			[DimensionID],
			[Label],
			[SelectYN]
		FROM
			[MemberSelection] MS
		
		SET @Inserted = @Inserted + @@ROWCOUNT
		'

					SET @SQLStatement1 = @SQLStatement1 + '

	SET @Step = ''MappedLabel''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[MappedLabel]

		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[MappedLabel]''

		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[MappedLabel]
			(
			[MappedObjectName],
			[Entity],
			[LabelFrom],
			[LabelTo],
			[MappingTypeID],
			[MappedLabel],
			[MappedDescription],
			[SelectYN]
			)
		SELECT
			[MappedObjectName],
			[Entity],
			[LabelFrom],
			[LabelTo],
			[MappingTypeID],
			[MappedLabel],
			[MappedDescription],
			[SelectYN]
		FROM
			[MappedLabel] ML
		
		SET @Inserted = @Inserted + @@ROWCOUNT
		'
				IF @iScalaYN <> 0
					SET @SQLStatement1 = @SQLStatement1 + '

	SET @Step = ''TransactionType_iScala''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[TransactionType_iScala]

		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[TransactionType_iScala]''

		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[TransactionType_iScala]
			(
			[Group],
			[Period],
			[Scenario],
			[Hex],
			[Symbol],
			[Description],
			[BusinessProcess],
			[SelectYN]
			)
		SELECT
			[Group] = TTiS.[Group],
			[Period] = TTiS.[Period],
			[Scenario] = TTiS.[Scenario],
			[Hex] = TTiS.[Hex],
			[Symbol] = TTiS.[Symbol],
			[Description] = TTiS.[Description],
			[BusinessProcess] = TTiS.[BusinessProcess],
			[SelectYN] = TTiS.[SelectYN]
		FROM
			[TransactionType_iScala] TTiS
		
		SET @Inserted = @Inserted + @@ROWCOUNT
		'

				SET @SQLStatement1 = @SQLStatement1 + '

	SET @Step = ''AccountType''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[AccountType]

		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[AccountType]''

		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[AccountType]
			(
			[AccountType],
			[Sign],
			[TimeBalance],
			[Rate],
			[Source]
			)
		SELECT
			[AccountType] = AT.[AccountType],
			[Sign] = AT.[Sign],
			[TimeBalance] = AT.[TimeBalance],
			[Rate] = AT.[Rate],
			[Source] = AT.[Source]
		FROM
			[AccountType] AT
		
		SET @Inserted = @Inserted + @@ROWCOUNT
		'

				SET @SQLStatement1 = @SQLStatement1 + '

	SET @Step = ''AccountType_Translate''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[AccountType_Translate]

		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[AccountType_Translate]''

		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[AccountType_Translate]
			(
			[SourceTypeName],
			[CategoryID],
			[Description],
			[AccountType]
			)
		SELECT
			[SourceTypeName] = ATT.[SourceTypeName],
			[CategoryID] = ATT.[CategoryID],
			[Description] = ATT.[Description],
			[AccountType] = ATT.[AccountType]
		FROM
			[AccountType_Translate] ATT
		
		SET @Inserted = @Inserted + @@ROWCOUNT
		'

				SET @SQLStatement1 = @SQLStatement1 + '

	SET @Step = ''FinancialSegment''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[FinancialSegment]

		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[FinancialSegment]''

		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[FinancialSegment]
			(
			[SourceID],
			[EntityCode],
			[SegmentNbr],
			[EntityName],
			[COACode],
			[SQLDB],
			[SegmentTable],
			[SegmentCode],
			[SegmentName],
			[Company_COACode],
			[DimensionTypeID],
			[Start],
			[Length]
			)
		SELECT
			[SourceID] = FS.[SourceID],
			[EntityCode] = FS.[EntityCode],
			[SegmentNbr] = FS.[SegmentNbr],
			[EntityName] = FS.[EntityName],
			[COACode] = FS.[COACode],
			[SQLDB] = FS.[SQLDB],
			[SegmentTable] = FS.[SegmentTable],
			[SegmentCode] = FS.[SegmentCode],
			[SegmentName] = FS.[SegmentName],
			[Company_COACode] = FS.[Company_COACode],
			[DimensionTypeID] = FS.[DimensionTypeID],
			[Start] = FS.[Start],
			[Length] = FS.[Length]
		FROM
			[FinancialSegment] FS
		
		SET @Inserted = @Inserted + @@ROWCOUNT
		'

				SET @SQLStatement1 = @SQLStatement1 + '

	SET @Step = ''MappedObject''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[MappedObject]

		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[MappedObject]''

		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[MappedObject]
			(
			[Entity],
			[ObjectName],
			[DimensionTypeID],
			[MappedObjectName],
			[ObjectTypeBM],
			[ModelBM],
			[MappingTypeID],
			[ReplaceTextYN],
			[TranslationYN],
			[SelectYN]
			)
		SELECT
			[Entity] = MO.[Entity],
			[ObjectName] = MO.[ObjectName],
			[DimensionTypeID] = MO.[DimensionTypeID],
			[MappedObjectName] = MO.[MappedObjectName],
			[ObjectTypeBM] = MO.[ObjectTypeBM],
			[ModelBM] = MO.[ModelBM],
			[MappingTypeID] = MO.[MappingTypeID],
			[ReplaceTextYN] = MO.[ReplaceTextYN],
			[TranslationYN] = MO.[TranslationYN],
			[SelectYN] = MO.[SelectYN]
		FROM
			[MappedObject] MO
		
		SET @Inserted = @Inserted + @@ROWCOUNT
		'

					SET @SQLStatement2 = @SQLStatement2 + '

	SET @Step = ''Time''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[Time]

		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[Time]''

		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[Time]
			(
			[MemberId],
			[Label],
			[Description],
			[Level],
			[SendTo],
			[TimeFiscalPeriod],
			[TimeFiscalQuarter],
			[TimeFiscalSemester],
			[TimeFiscalTertial],
			[TimeFiscalYear],
			[TimeMonth],
			[TimeQuarter],
			[TimeSemester],
			[TimeTertial],
			[TimeYear],
			[TopNode],
			[Source],
			[Synchronized]
			)
		SELECT
			[MemberId],
			[Label],
			[Description],
			[Level],
			[SendTo],
			[TimeFiscalPeriod],
			[TimeFiscalQuarter],
			[TimeFiscalSemester],
			[TimeFiscalTertial],
			[TimeFiscalYear],
			[TimeMonth],
			[TimeQuarter],
			[TimeSemester],
			[TimeTertial],
			[TimeYear],
			[TopNode],
			[Source],
			[Synchronized]
		FROM
			' + @DestinationDatabase + '..S_DS_€£Time£€ T
		
		SET @Inserted = @Inserted + @@ROWCOUNT
		'

					SET @SQLStatement2 = @SQLStatement2 + '

	SET @Step = ''Scenario''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[Scenario]

		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[Scenario]''

		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[Scenario]
			(
			[MemberId],
			[Label],
			[Description],
			[Source],
			[Source_Currency],
			[Source_Scenario],
			[Synchronized]
			)
		SELECT
			[MemberId] = S.[MemberId],
			[Label] = S.[Label],
			[Description] = S.[Description],
			[Source] = S.[Source],
			[Source_Currency] = S.[Source_Currency],
			[Source_Scenario] = S.[Source_Scenario],
			[Synchronized] = S.[Synchronized]
		FROM
			' + @DestinationDatabase + '..S_DS_€£Scenario£€ S
		
		SET @Inserted = @Inserted + @@ROWCOUNT
		'

					SET @SQLStatement2 = @SQLStatement2 + '

	SET @Step = ''Account_TimeBalance''
		SELECT @Deleted = @Deleted + COUNT(1) FROM ' + @ETLDatabase_Linked + '.[dbo].[Account_TimeBalance]

		EXEC ' + @ETLDatabase_Linked + '.sys.sp_executesql N''TRUNCATE TABLE [dbo].[Account_TimeBalance]''

		INSERT INTO ' + @ETLDatabase_Linked + '.[dbo].[Account_TimeBalance]
			(
			[Account],
			[TimeBalance]
			)
		SELECT
			[Account] = A.[Label],
			[TimeBalance] = ISNULL(A.[TimeBalance], 0)
		FROM
			' + @DestinationDatabase + '..S_DS_€£Account£€ A
		
		SET @Inserted = @Inserted + @@ROWCOUNT
		'
				FETCH NEXT FROM Linked_Insert_Cursor INTO @Counter, @ETLDatabase_Linked, @ETLDatabase_Linked_Filter, @OptFinanceDimYN
			END
		CLOSE Linked_Insert_Cursor
		DEALLOCATE Linked_Insert_Cursor	

		EXEC spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 2, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement1, @StringOut = @SQLStatement1 OUTPUT
		EXEC spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 2, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement2, @StringOut = @SQLStatement2 OUTPUT

		IF @Debug <> 0 
			BEGIN
				PRINT @SQLStatement1
				PRINT @SQLStatement2
			END

	SET @Step = 'Create SQL string'
		SET @Counter = 0
		WHILE @Counter < 2
			BEGIN
				SET @Counter = @Counter + 1

				IF @Counter = 1
					SET @ProcedureName = 'spIU_0000_ETL_Linked'
				IF @Counter = 2
					SET @ProcedureName = 'spIU_0000_Dimension_Linked'

				TRUNCATE TABLE #Action
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ProcedureName + '''' + ', ' + '''P''' 
				INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
				SELECT @Action = [Action] FROM #Action

				SET @SQLStatement = @Action + ' PROCEDURE [dbo].' + @ProcedureName + '

@JobID int = 0,
@Rows int = NULL,
@GetVersion bit = 0,
@Duration time(7) = ''00:00:00'' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(1000),
	@LinkedYN bit,
	@Version nvarchar(50) = ''' + @Version + '''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''Set @StartTime''
		SET @StartTime = GETDATE()

	SET @Step = ''Set procedure variables''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

	SET @Step = ''Update Linked ETL tables'''

SET @SQLStatement = @SQLStatement + CASE WHEN @Counter = 1 THEN @SQLStatement1 ELSE @SQLStatement2 END + '

	SET @Step = ''Set @Duration''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''Insert into JobLog''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

				SET @SQLStatement = REPLACE(@SQLStatement, '''', '''''')
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of Stored Procedure', [SQLStatement] = @SQLStatement

				EXEC (@SQLStatement)
			END

	SET @Step = 'Define exit point'
		EXITPOINT:

	SET @Step = 'Drop temp tables'
		DROP TABLE #Source
		DROP TABLE #Action

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
