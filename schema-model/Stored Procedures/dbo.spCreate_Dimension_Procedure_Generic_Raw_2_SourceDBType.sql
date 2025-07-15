SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Dimension_Procedure_Generic_Raw_2_SourceDBType] 

	@SourceID int = NULL,
	@DimensionID int = NULL,
	@SQLStatement1 nvarchar(max) = NULL,
	@SQLStatement2_01 nvarchar(max) = NULL,
	@SQLStatement2_02 nvarchar(max) = NULL,
	@SQLStatement2_03 nvarchar(max) = NULL,
	@SQLStatement2_04 nvarchar(max) = NULL,
	@SQLStatement2_05 nvarchar(max) = NULL,
	@SQLStatement2_06 nvarchar(max) = NULL,
	@SQLStatement2_07 nvarchar(max) = NULL,
	@SQLStatement2_08 nvarchar(max) = NULL,
	@SQLStatement2_09 nvarchar(max) = NULL,
	@SQLStatement2_10 nvarchar(max) = NULL,
	@Union nvarchar(100) = NULL,
	@SQLStatement3_01 nvarchar(max) = NULL,
	@SQLStatement3_02 nvarchar(max) = NULL,
	@SQLStatement3_03 nvarchar(max) = NULL,
	@SQLStatement3_04 nvarchar(max) = NULL,
	@SQLStatement3_05 nvarchar(max) = NULL,
	@SQLStatement3_06 nvarchar(max) = NULL,
	@SQLStatement3_07 nvarchar(max) = NULL,
	@SQLStatement3_08 nvarchar(max) = NULL,
	@SQLStatement3_09 nvarchar(max) = NULL,
	@SQLStatement3_10 nvarchar(max) = NULL,
	@SQLStatement3_11 nvarchar(max) = NULL,
	@SQLStatement3_12 nvarchar(max) = NULL,
	@SQLStatement3_13 nvarchar(max) = NULL,
	@SQLStatement3_14 nvarchar(max) = NULL,
	@SQLStatement3_15 nvarchar(max) = NULL,
	@SQLStatement3_16 nvarchar(max) = NULL,
	@SQLStatement3_17 nvarchar(max) = NULL,
	@SQLStatement3_18 nvarchar(max) = NULL,
	@SQLStatement3_19 nvarchar(max) = NULL,
	@SQLStatement3_20 nvarchar(max) = NULL,
	@SQLStatement4 nvarchar(max) = NULL,
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

--EXEC [spCreate_Dimension_Procedure_Generic_Raw] @SourceID = 307, @DimensionID = -1, @SQLStatement = '', @Debug = true
--EXEC [spCreate_Dimension_Procedure_Generic_Raw] @SourceID = 957, @DimensionID = -53, @SQLStatement = '', @Debug = true

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Action nvarchar(10),
	@ApplicationID int,
	@SQLStatement nvarchar(max),
	@SourceType nvarchar(50),
	@SourceDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@SourceID_varchar nvarchar(10),
	@ObjectName nvarchar(50),
	@Entity nvarchar(50),
	@StartYear int,
	@BaseModelID int,
	@OptFinanceDimYN bit,
	@SourceDBTypeID int,
	@SourceTypeFamilyID int,
	@SourceTypeID int,
	@DimensionName nvarchar(100),
	@MappedDimensionName nvarchar(100),
	@ModelBM int,
	@GenericYN bit,
	@SQLStatement_Action nvarchar(1000),
	@SQLStatement_CreateTable nvarchar(4000),
	@SQLStatement_InsertInto nvarchar(4000),
	@StaticOnlyYN bit, 
	@InstanceID int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.2.2146'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.2.2067' SET @Description = 'Handling of long SQL-strings.'
		IF @Version = '1.3.2081' SET @Description = 'Handling of iScala.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption, Enhanced TableCode handling'
		IF @Version = '1.3.2092' SET @Description = 'Handling dimensions with only static data'
		IF @Version = '1.3.2095' SET @Description = 'Added RNodeType'
		IF @Version = '1.3.2096' SET @Description = 'Replaced @SourceTable with @SourceTable_01 - @SourceTable_05.'
		IF @Version = '1.3.2097' SET @Description = 'Optimized wrk_SourceTable handling.'
		IF @Version = '1.3.2098' SET @Description = 'Replaced vw_XXXX_Dimension_Finance_Metadata with FinancialSegment.'
		IF @Version = '1.3.2106' SET @Description = 'Shortened instances of variable @SQLStatement. Handle SBZ property.'
		IF @Version = '1.3.2107' SET @Description = 'Added REPLACE of @DimensionID.'
		IF @Version = '1.3.2109' SET @Description = 'Fixed MemberIDs for all Static Members. Increased number of parameters for [spGet_Member] from 15 to 20.'
		IF @Version = '1.3.2111' SET @Description = 'Added Navision.'
		IF @Version = '1.3.2116' SET @Description = 'Handle iScala Currency for FxRate when no Entities are selected.'
		IF @Version = '1.3.1.2123' SET @Description = 'Handle @MultipleProcedureYN.'
		IF @Version = '2.0.2.2146' SET @Description = 'Added ABS function for @SourceID'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @SourceID IS NULL OR @DimensionID IS NULL OR @SQLStatement1 IS NULL OR @SQLStatement2_01 IS NULL OR @SQLStatement2_02 IS NULL OR @SQLStatement2_03 IS NULL OR @SQLStatement2_04 IS NULL OR @SQLStatement2_05 IS NULL OR @SQLStatement2_06 IS NULL OR @SQLStatement2_07 IS NULL OR @SQLStatement2_08 IS NULL OR @SQLStatement2_09 IS NULL OR @SQLStatement2_10 IS NULL OR @Union IS NULL OR @SQLStatement3_01 IS NULL OR @SQLStatement3_02 IS NULL OR @SQLStatement3_03 IS NULL OR @SQLStatement3_04 IS NULL OR @SQLStatement3_05 IS NULL OR @SQLStatement3_06 IS NULL OR @SQLStatement3_07 IS NULL OR @SQLStatement3_08 IS NULL OR @SQLStatement3_09 IS NULL OR @SQLStatement3_10 IS NULL OR @SQLStatement4 IS NULL
	BEGIN
		PRINT 'Parameter @SourceID, parameter @DimensionID and the @SQLStatements must be set'
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
			@ApplicationID = M.ApplicationID,
			@ETLDatabase = A.ETLDatabase,
			@DestinationDatabase = A.DestinationDatabase
		FROM
			Model M
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
			INNER JOIN Source S ON S.SourceID = @SourceID AND S.ModelID = M.ModelID AND S.SelectYN <> 0
		WHERE
			M.SelectYN <> 0

		SELECT DISTINCT
			@SourceType = ST.SourceTypeName,
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ModelBM = BM.ModelBM,
			@StartYear = S.StartYear,
			@GenericYN = D.GenericYN,
			@SourceDBTypeID = ST.SourceDBTypeID,
			@SourceTypeFamilyID = ST.SourceTypeFamilyID,
			@BaseModelID = M.BaseModelID,
			@OptFinanceDimYN = BM.[OptFinanceDimYN]
		FROM
			Source S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
			INNER JOIN Dimension D ON D.DimensionID = @DimensionID AND D.SelectYN <> 0 --AND D.ModelBM & BM.ModelBM > 0
			INNER JOIN [Language] L ON L.LanguageID = A.LanguageID
		WHERE
			SourceID = @SourceID

		SET @SourceID_varchar = CASE WHEN @GenericYN <> 0 THEN '0000' ELSE CASE WHEN ABS(@SourceID) <= 9 THEN '000' ELSE CASE WHEN ABS(@SourceID) <= 99 THEN '00' ELSE CASE WHEN ABS(@SourceID) <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, ABS(@SourceID)) END

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		--SELECT @CursorRows = 1

	SET @Step = 'Set @StaticOnlyYN'
		CREATE TABLE #CursorRows
			(
			CursorRows int
			)

		SET @SQLStatement = '
			INSERT INTO #CursorRows
				(
				CursorRows
				)
			SELECT
				CursorRows = COUNT(1)
			FROM
				' + @ETLDatabase + '..[Entity] E 
				INNER JOIN pcINTEGRATOR..[SourceTable] ST ON ST.SourceTypeFamilyID = ' + CONVERT(nvarchar(10), @SourceTypeFamilyID) + ' AND ST.ModelBM & ' + CONVERT(nvarchar(10), @ModelBM) + ' > 0 AND ST.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + '
				INNER JOIN ' + @ETLDatabase + '..wrk_SourceTable wST ON wST.SourceID = E.SourceID AND wST.EntityCode = E.EntityCode AND wST.TableCode = ST.TableCode
			WHERE
				E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND
				E.SelectYN <> 0'

			EXEC (@SQLStatement)

			IF @Debug <> 0 PRINT (@SQLStatement)
  
			SELECT
				@StaticOnlyYN = CASE WHEN CursorRows > 0 OR (@SourceTypeFamilyID = 2 AND @ModelBM & 4 > 0 AND @DimensionID = -3) THEN 0 ELSE 1 END
			FROM
				#CursorRows

			IF @Debug <> 0 SELECT TempTable = '#CursorRows', CursorRows, StaticOnlyYN = @StaticOnlyYN FROM #CursorRows

			DROP TABLE #CursorRows

	SET @Step = 'Get Fieldlist'
		EXEC spGet_FieldList
			@SourceID = @SourceID,
			@DimensionID = @DimensionID, 
			@JobID = @JobID, 
			@Debug = @Debug,
			@SQLStatement_CreateTable = @SQLStatement_CreateTable OUT, 
			@SQLStatement_InsertInto = @SQLStatement_InsertInto OUT, 
			@DimensionName = @DimensionName OUT

		IF @Debug <> 0 
			BEGIN
				PRINT @SQLStatement_CreateTable
				PRINT @SQLStatement_InsertInto
			END

	SET @Step = 'SET @ObjectName'
		SET @ObjectName = 'spIU_' + @SourceID_varchar + '_' + @DimensionName + '_Raw'

	SET @Step = 'CREATE TABLE #Action'
		CREATE TABLE #Action
		(
		[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
		)

		SET @SQLStatement_Action = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ObjectName + '''' + ', ' + '''P''' 
		INSERT INTO #Action ([Action]) EXEC (@SQLStatement_Action)
		SELECT @Action = [Action] FROM #Action

  	SET @Step = 'Create source specific Raw Procedure'
		IF @Debug <> 0 
			SELECT
				SQLStatement1 = @SQLStatement1,
				SQLStatement2_01 = @SQLStatement2_01,
				SQLStatement2_02 = @SQLStatement2_02,
				SQLStatement2_03 = @SQLStatement2_03,
				SQLStatement2_04 = @SQLStatement2_04,
				SQLStatement2_05 = @SQLStatement2_05,
				SQLStatement2_06 = @SQLStatement2_06,
				SQLStatement2_07 = @SQLStatement2_07,
				SQLStatement2_08 = @SQLStatement2_08,
				SQLStatement2_09 = @SQLStatement2_09,
				SQLStatement2_10 = @SQLStatement2_10,
				[Union] = @Union,
				SQLStatement3_01 = @SQLStatement3_01,
				SQLStatement3_02 = @SQLStatement3_02,
				SQLStatement3_03 = @SQLStatement3_03,
				SQLStatement3_04 = @SQLStatement3_04,
				SQLStatement3_05 = @SQLStatement3_05,
				SQLStatement3_06 = @SQLStatement3_06,
				SQLStatement3_07 = @SQLStatement3_07,
				SQLStatement3_08 = @SQLStatement3_08,
				SQLStatement3_09 = @SQLStatement3_09,
				SQLStatement3_10 = @SQLStatement3_10,
				SQLStatement3_11 = @SQLStatement3_11,
				SQLStatement3_12 = @SQLStatement3_12,
				SQLStatement3_13 = @SQLStatement3_13,
				SQLStatement3_14 = @SQLStatement3_14,
				SQLStatement3_15 = @SQLStatement3_15,
				SQLStatement3_16 = @SQLStatement3_16,
				SQLStatement3_17 = @SQLStatement3_17,
				SQLStatement3_18 = @SQLStatement3_18,
				SQLStatement3_19 = @SQLStatement3_19,
				SQLStatement3_20 = @SQLStatement3_20,
				SQLStatement4 = @SQLStatement4,
				SourceID = @SourceID,
				[Action] = @Action,
				ObjectName = @ObjectName

		SET @SQLStatement = @Action + ' PROCEDURE [dbo].[' + @ObjectName + '] 

	@JobID int = 0,
	@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
	@Entity nvarchar(50) = ''''-1'''',
	@DimensionID int = ' + CONVERT(nvarchar, @DimensionID) + ',
	@StartYear int = ' + CONVERT(nvarchar, @StartYear) + ',
	@Rows int = NULL,
	@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
--EXEC [' + @ObjectName + '] @Debug = 1

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SourceDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@ETLDatabase_Linked nvarchar(100),
	@SourceTable_01 nvarchar(100),
	@SourceTable_02 nvarchar(100),
	@SourceTable_03 nvarchar(100),
	@SourceTable_04 nvarchar(100),
	@SourceTable_05 nvarchar(100),
	@SQLStatement nvarchar(max) = '''''''',
	@SourceID_varchar nvarchar(10),
	@SourceType nvarchar(50),
	@SourceTypeFamilyID int,
	@EntityCode nvarchar(50),
	@ModelBM int,
	@RowsToInsert int, 
	@RowsInserted int = 0

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

    SET @Step = ''''Set procedure variables''''
		SELECT
			@SourceType = ST.SourceTypeName,
			@SourceTypeFamilyID = ST.SourceTypeFamilyID,
			@SourceID_varchar = CASE WHEN @SourceID <= 9 THEN ''''000'''' ELSE CASE WHEN @SourceID <= 99 THEN ''''00'''' ELSE CASE WHEN @SourceID <= 999 THEN ''''0'''' ELSE '''''''' END END END + CONVERT(nvarchar, @SourceID),
			@ModelBM = BM.ModelBM,
			@ETLDatabase = ''''['''' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, ''''['''', ''''''''), '''']'''', ''''''''), ''''.'''', ''''].['''') + '''']'''',
			@ETLDatabase_Linked = ''''['''' + REPLACE(REPLACE(REPLACE(S.ETLDatabase_Linked, ''''['''', ''''''''), '''']'''', ''''''''), ''''.'''', ''''].['''') + '''']''''
		FROM
			pcINTEGRATOR.dbo.[Source] S
			INNER JOIN pcINTEGRATOR.dbo.[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
			INNER JOIN pcINTEGRATOR.dbo.[Model] M ON M.ModelID = S.ModelID
			INNER JOIN pcINTEGRATOR.dbo.[Model] BM ON BM.ModelID = M.BaseModelID
			INNER JOIN pcINTEGRATOR.dbo.[Application] A ON A.ApplicationID = M.ApplicationID
		WHERE
			S.SourceID = @SourceID'

			SET @SQLStatement = @SQLStatement + '

		SET @RowsToInsert = ISNULL(@Rows, 100000000)

    SET @Step = ''''Create Temp Tables''''
		CREATE TABLE #CursorTable
			(
			EntityCode nvarchar(50),
			Entity nvarchar(50),
			SourceDatabase nvarchar(100),
			SourceTable_01 nvarchar(100),
			SourceTable_02 nvarchar(100),
			SourceTable_03 nvarchar(100),
			SourceTable_04 nvarchar(100),
			SourceTable_05 nvarchar(100),
			SortOrder int,
			FiscalYear int
			)

		CREATE TABLE #ReturnTable
			(' + @SQLStatement_CreateTable + '
			)
			'
    
	IF @StaticOnlyYN = 0 
		BEGIN
			SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''Fill #CursorTable''''
			INSERT INTO #CursorTable
				(
				EntityCode,
				Entity,
				SourceDatabase,
				SourceTable_01,
				SourceTable_02,
				SourceTable_03,
				SourceTable_04,
				SourceTable_05,
				SortOrder,
				FiscalYear
				)'

		SET @SQLStatement = @SQLStatement + '
			SELECT
				sub1.EntityCode,
				Entity,
				SourceDatabase,
				SourceTable_01,
				SourceTable_02,
				SourceTable_03,
				SourceTable_04,
				SourceTable_05,
				SortOrder,
				FiscalYear
			FROM
				(
				SELECT
					E.EntityCode,
					TableCode_01 = MAX(CASE WHEN ST.LevelBM & 1 > 0 THEN ST.TableCode ELSE '''''''' END),
					TableCode_02 = MAX(CASE WHEN ST.LevelBM & 2 > 0 THEN ST.TableCode ELSE '''''''' END),
					TableCode_03 = MAX(CASE WHEN ST.LevelBM & 4 > 0 THEN ST.TableCode ELSE '''''''' END),
					TableCode_04 = MAX(CASE WHEN ST.LevelBM & 8 > 0 THEN ST.TableCode ELSE '''''''' END),
					TableCode_05 = MAX(CASE WHEN ST.LevelBM & 16 > 0 THEN ST.TableCode ELSE '''''''' END)
				FROM
					[Entity] E 
					INNER JOIN [pcINTEGRATOR].[dbo].[SourceTable] ST ON ST.SourceTypeFamilyID = @SourceTypeFamilyID AND ST.ModelBM & @ModelBM > 0 AND ST.TableTypeBM & 2 > 0 AND ST.DimensionID = @DimensionID' +
					CASE WHEN  @SourceTypeFamilyID = 3 AND @DimensionID = -1 AND @OptFinanceDimYN <> 0 THEN '
					INNER JOIN [FinancialSegment] DFM ON DFM.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND DFM.EntityCode = E.EntityCode AND DFM.DimensionTypeID = 1 AND DFM.SegmentTable = ST.TableCode' ELSE '' END + '
				WHERE
					E.SourceID = @SourceID AND
					(E.Entity = @Entity OR @Entity = ''''-1'''') AND
					E.SelectYN <> 0
				GROUP BY
					E.EntityCode
				) sub1
				INNER JOIN 
				(
				SELECT DISTINCT
					E.EntityCode,
					E.Entity,
					SourceDatabase = E.Par01,
					TableCode_01 = MAX(CASE WHEN ST.LevelBM & 1 > 0 THEN ST.TableCode ELSE '''''''' END),
					TableCode_02 = MAX(CASE WHEN ST.LevelBM & 2 > 0 THEN ST.TableCode ELSE '''''''' END),
					TableCode_03 = MAX(CASE WHEN ST.LevelBM & 4 > 0 THEN ST.TableCode ELSE '''''''' END),
					TableCode_04 = MAX(CASE WHEN ST.LevelBM & 8 > 0 THEN ST.TableCode ELSE '''''''' END),
					TableCode_05 = MAX(CASE WHEN ST.LevelBM & 16 > 0 THEN ST.TableCode ELSE '''''''' END),
					SourceTable_01 = MAX(CASE WHEN ST.LevelBM & 1 > 0 THEN wST.TableName ELSE '''''''' END),
					SourceTable_02 = MAX(CASE WHEN ST.LevelBM & 2 > 0 THEN wST.TableName ELSE '''''''' END),
					SourceTable_03 = MAX(CASE WHEN ST.LevelBM & 4 > 0 THEN wST.TableName ELSE '''''''' END),
					SourceTable_04 = MAX(CASE WHEN ST.LevelBM & 8 > 0 THEN wST.TableName ELSE '''''''' END),
					SourceTable_05 = MAX(CASE WHEN ST.LevelBM & 16 > 0 THEN wST.TableName ELSE '''''''' END),
					SortOrder = ISNULL(E.EntityPriority, 99999999),
					FiscalYear = wST.FiscalYear
				FROM
					[Entity] E 
					INNER JOIN pcINTEGRATOR..[SourceTable] ST ON ST.SourceTypeFamilyID = @SourceTypeFamilyID AND ST.ModelBM & @ModelBM > 0 AND ST.TableTypeBM & 2 > 0 AND ST.DimensionID = @DimensionID
					INNER JOIN wrk_SourceTable wST ON wST.SourceID = @SourceID AND wST.EntityCode = E.EntityCode AND wST.TableCode = ST.TableCode' +
					CASE WHEN  @SourceTypeFamilyID = 3 AND @DimensionID = -1 AND @OptFinanceDimYN <> 0 THEN '
					INNER JOIN [FinancialSegment] DFM ON DFM.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND DFM.EntityCode = E.EntityCode AND DFM.DimensionTypeID = 1 AND DFM.SegmentTable = ST.TableCode' ELSE '' END + '
				WHERE
					E.SourceID = @SourceID AND
					(E.Entity = @Entity OR @Entity = ''''-1'''') AND
					E.SelectYN <> 0
				GROUP BY
					E.EntityCode,
					E.Entity,
					E.Par01,
					ISNULL(E.EntityPriority, 99999999),
					wST.FiscalYear
				) sub2 ON sub2.EntityCode = sub1.EntityCode AND sub2.TableCode_01 = sub1.TableCode_01 AND sub2.TableCode_02 = sub1.TableCode_02 AND sub2.TableCode_03 = sub1.TableCode_03 AND sub2.TableCode_04 = sub1.TableCode_04 AND sub2.TableCode_05 = sub1.TableCode_05
			ORDER BY
				SortOrder,
				FiscalYear DESC'

		SET @SQLStatement = @SQLStatement + '

		IF @Debug <> 0 SELECT TempTable = ''''#CursorTable'''', * FROM #CursorTable ORDER BY SortOrder, FiscalYear DESC

	SET @Step = ''''CREATE ' + @DimensionName + '_Raw_Cursor''''

  		DECLARE ' + @DimensionName + '_Raw_Cursor CURSOR FOR

			SELECT
				EntityCode,
				Entity,
				SourceDatabase,
				SourceTable_01,
				SourceTable_02,
				SourceTable_03,
				SourceTable_04,
				SourceTable_05
			FROM
				#CursorTable
			ORDER BY
				SortOrder,
				FiscalYear DESC

		OPEN ' + @DimensionName + '_Raw_Cursor
		FETCH NEXT FROM ' + @DimensionName + '_Raw_Cursor INTO @EntityCode, @Entity, @SourceDatabase, @SourceTable_01, @SourceTable_02, @SourceTable_03, @SourceTable_04, @SourceTable_05

		WHILE @@FETCH_STATUS = 0 AND @RowsToInsert > 0
		  BEGIN
			  IF @Debug <> 0 SELECT Entity = @Entity, SourceDatabase = @SourceDatabase
			  '
		END

		SET @SQLStatement = @SQLStatement + '
			SET @Step = ''''Set @SQLStatement''''
				SET @SQLStatement = ''''' + 
									REPLACE(@SQLStatement1, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' + 
									CASE WHEN LEN(@SQLStatement2_01) > 0 THEN REPLACE(@SQLStatement2_01, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement2_02) > 0 THEN REPLACE(@SQLStatement2_02, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement2_03) > 0 THEN REPLACE(@SQLStatement2_03, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement2_04) > 0 THEN REPLACE(@SQLStatement2_04, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement2_05) > 0 THEN REPLACE(@SQLStatement2_05, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement2_06) > 0 THEN REPLACE(@SQLStatement2_06, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement2_07) > 0 THEN REPLACE(@SQLStatement2_07, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement2_08) > 0 THEN REPLACE(@SQLStatement2_08, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement2_09) > 0 THEN REPLACE(@SQLStatement2_09, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement2_10) > 0 THEN REPLACE(@SQLStatement2_10, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@Union) > 0 THEN REPLACE(@Union, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_01) > 0 THEN REPLACE(@SQLStatement3_01, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_02) > 0 THEN REPLACE(@SQLStatement3_02, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_03) > 0 THEN REPLACE(@SQLStatement3_03, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_04) > 0 THEN REPLACE(@SQLStatement3_04, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_05) > 0 THEN REPLACE(@SQLStatement3_05, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_06) > 0 THEN REPLACE(@SQLStatement3_06, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_07) > 0 THEN REPLACE(@SQLStatement3_07, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_08) > 0 THEN REPLACE(@SQLStatement3_08, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_09) > 0 THEN REPLACE(@SQLStatement3_09, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_10) > 0 THEN REPLACE(@SQLStatement3_10, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_11) > 0 THEN REPLACE(@SQLStatement3_11, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_12) > 0 THEN REPLACE(@SQLStatement3_12, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_13) > 0 THEN REPLACE(@SQLStatement3_13, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_14) > 0 THEN REPLACE(@SQLStatement3_14, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_15) > 0 THEN REPLACE(@SQLStatement3_15, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_16) > 0 THEN REPLACE(@SQLStatement3_16, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_17) > 0 THEN REPLACE(@SQLStatement3_17, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_18) > 0 THEN REPLACE(@SQLStatement3_18, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_19) > 0 THEN REPLACE(@SQLStatement3_19, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									CASE WHEN LEN(@SQLStatement3_20) > 0 THEN REPLACE(@SQLStatement3_20, '''', '''''''''') + ''''' SET @SQLStatement = @SQLStatement + ''''' ELSE '' END + 
									REPLACE(@SQLStatement4, '''', '''''''''') + '''''

			SET @Step = ''''Replace variables''''
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@EntityCode'''', ISNULL(@EntityCode, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@Entity'''', ISNULL(@Entity, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@SourceDatabase'''', ISNULL(@SourceDatabase, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@ETLDatabase_Linked'''', ISNULL(@ETLDatabase_Linked, @ETLDatabase))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@SourceTable_01'''', ISNULL(@SourceTable_01, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@SourceTable_02'''', ISNULL(@SourceTable_02, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@SourceTable_03'''', ISNULL(@SourceTable_03, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@SourceTable_04'''', ISNULL(@SourceTable_04, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@SourceTable_05'''', ISNULL(@SourceTable_05, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@SourceType'''', ISNULL(@SourceType, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@SourceID_varchar'''', ISNULL(@SourceID_varchar, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@SourceID'''', ISNULL(@SourceID, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@DimensionID'''', ISNULL(@DimensionID, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@StartYear'''', ISNULL(@StartYear, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''@RowsToInsert'''', ISNULL(@RowsToInsert, ''''''''))
				SET @SQLStatement = REPLACE (@SQLStatement, ''''COLLATE DATABASE_DEFAULT COLLATE DATABASE_DEFAULT'''', ''''COLLATE DATABASE_DEFAULT'''')

			SET @Step = ''''Set SQL Statement''''
				SET @SQLStatement = ''''
INSERT INTO #ReturnTable
	(
	' + @SQLStatement_InsertInto + '
	)
SELECT
	* 
FROM
	('''' + @SQLStatement + '''') sub
WHERE
	NOT EXISTS (SELECT 1 FROM #ReturnTable RT WHERE RT.Label = sub.Label)''''

			SET @Step = ''''EXEC SQL Statement''''
				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Insert into #Return table'''', [SQLStatement] = @SQLStatement
				EXEC (@SQLStatement)
				SET @RowsInserted = @@ROWCOUNT
				SET @RowsToInsert = @RowsToInsert - @RowsInserted'

	IF @StaticOnlyYN = 0 
		BEGIN
			SET @SQLStatement = @SQLStatement + '

			FETCH NEXT FROM ' + @DimensionName + '_Raw_Cursor INTO @EntityCode, @Entity, @SourceDatabase, @SourceTable_01, @SourceTable_02, @SourceTable_03, @SourceTable_04, @SourceTable_05
		  END

		CLOSE ' + @DimensionName + '_Raw_Cursor
		DEALLOCATE ' + @DimensionName + '_Raw_Cursor
		'
		END

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Return Members''''
		SELECT 
			*
		FROM
			#ReturnTable
		ORDER BY
			Label

	SET @Step = ''''Drop Temp Tables''''
		DROP TABLE #CursorTable
		DROP TABLE #ReturnTable

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GETDATE() - @StartTime, Deleted = 0, Inserted = 0, Updated = 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of Raw Procedure', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)

	SET @Step = 'Drop Temp table'
		DROP TABLE #Action

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ' (' + @ObjectName + ')', @Duration, @Deleted, @Inserted, @Updated, @Version
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ' (' + @ObjectName + ')', GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH





GO
