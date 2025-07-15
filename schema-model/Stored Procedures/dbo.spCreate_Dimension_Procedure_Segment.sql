SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Dimension_Procedure_Segment] 

	@SourceID int = NULL,
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

--EXEC spCreate_Dimension_Procedure_Segment @SourceID = 107, @Debug = true --E9
--EXEC spCreate_Dimension_Procedure_Segment @SourceID = 307, @Debug = true --iScala
--EXEC spCreate_Dimension_Procedure_Segment @SourceID = 807, @Debug = true --Navision
--EXEC spCreate_Dimension_Procedure_Segment @SourceID = 1227, @Debug = true --Enterprise

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@Action nvarchar(10),
	@InstanceID int,
	@ApplicationID int,
	@SourceType nvarchar(50),
	@SourceDatabase nvarchar(255),
	@ETLDatabase nvarchar(50),
	@SourceID_varchar nvarchar(10),
	@ObjectName nvarchar(50),
	@EntityCode nvarchar(50),
	@StartYear int,
	@BaseModelID int,
	@OptFinanceDimYN bit,
	@SourceDBTypeID int,
	@SourceTypeFamilyID int,
	@SourceTypeID int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2117'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.2.2066' SET @Description = 'Fixed Collation bug and improved @Rows handling.'
		IF @Version = '1.2.2067' SET @Description = 'Improved handling of long SQL strings.'
		IF @Version = '1.2.2068' SET @Description = 'SET ANSI_WARNINGS OFF.'
		IF @Version = '1.3.2070' SET @Description = 'Collation problems fixed. SET ANSI_WARNINGS ON if needed.'
		IF @Version = '1.3.2071' SET @Description = 'Filter PropertyID NOT BETWEEN 100 AND 1000.'
		IF @Version = '1.3.2074' SET @Description = 'Test on MemberId is not NULL in hierarchy creation.'
		IF @Version = '1.3.2081' SET @Description = 'Handling iScala.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2095' SET @Description = 'Added RNodeType'
		IF @Version = '1.3.2098' SET @Description = 'Replaced vw_XXXX_Dimension_Finance_Metadata with FinancialSegment.'
		IF @Version = '1.3.2101' SET @Description = 'Enhanced handling of ANSI_WARNINGS.'
		IF @Version = '1.3.2109' SET @Description = 'Fixed MemberIDs for all Static Members.'
		IF @Version = '1.3.2111' SET @Description = 'Added Navision. Enhanced handling of RNodeType and SBZ.'
		IF @Version = '1.3.2116' SET @Description = 'Changed logging logic. Added HelpText.'
		IF @Version = '1.3.2117' SET @Description = 'Fixed bug on HelpText.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @SourceID IS NULL 
	BEGIN
		PRINT 'Parameter @SourceID must be set'
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

		SET @SourceID_varchar = CASE WHEN ABS(@SourceID) <= 9 THEN '000' ELSE CASE WHEN ABS(@SourceID) <= 99 THEN '00' ELSE CASE WHEN ABS(@SourceID) <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, ABS(@SourceID))

		SELECT
			@SourceTypeID = S.SourceTypeID,
			@SourceType = ST.SourceTypeName,
			@SourceDBTypeID = 	ST.SourceDBTypeID,
			@SourceTypeFamilyID = ST.SourceTypeFamilyID,
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = A.ETLDatabase,
			@InstanceID = A.InstanceID,
			@ApplicationID = A.ApplicationID,
			@StartYear = S.StartYear,
			@BaseModelID = M.BaseModelID,
			@OptFinanceDimYN = BM.OptFinanceDimYN
		FROM
			Source S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
			INNER JOIN Model M ON M.ModelID = S.ModelID
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
		WHERE
			SourceID = @SourceID

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Check Model type'
		IF @OptFinanceDimYN = 0 RETURN

	SET @Step = 'Check Source DBType'
		IF @SourceDBTypeID = 1 
			BEGIN
				EXEC [spCreate_Dimension_View_Segment] @SourceID = @SourceID, @Debug = @Debug, @JobID = @JobID, @Encryption = @Encryption, @GetVersion = 0, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated
				RETURN
			END

	SET @Step = 'SET @ObjectName'
		SET @ObjectName = 'spIU_' + @SourceID_varchar + '_GL_Segment_Raw'

	SET @Step = 'CREATE TABLE #Action'
		CREATE TABLE #Action
		(
		[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
		)

		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ObjectName + '''' + ', ' + '''P''' 
		INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
		SELECT @Action = [Action] FROM #Action

		SET @SQLStatement = @Action + ' PROCEDURE [dbo].[' + @ObjectName + '] 

	@JobID int = 0,
	@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
	@Entity nvarchar(50) = ''''-1'''',
	@DimensionName nvarchar(100),
	@Rows int = NULL,
	@GetVersion bit = 0,
	@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SET ANSI_WARNINGS OFF

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Segment nvarchar(10),
	@SourceTable nvarchar(100),
	@MappingTypeID int,
	@SQLStatement nvarchar(max) = '''''''',
	@SQLStatement3_01 nvarchar(max) = '''''''',
	@SQLStatement3_02 nvarchar(max) = '''''''',
	@SQLStatement3_03 nvarchar(max) = '''''''',
	@SQLStatement3_04 nvarchar(max) = '''''''',
	@SQLStatement3_05 nvarchar(max) = '''''''',
	@SQLStatement3_06 nvarchar(max) = '''''''',
	@SQLStatement3_07 nvarchar(max) = '''''''',
	@SQLStatement3_08 nvarchar(max) = '''''''',
	@SQLStatement3_09 nvarchar(max) = '''''''',
	@SQLStatement3_10 nvarchar(max) = '''''''',
	@SQLStatement3_11 nvarchar(max) = '''''''',
	@SQLStatement3_12 nvarchar(max) = '''''''',
	@SQLStatement3_13 nvarchar(max) = '''''''',
	@SQLStatement3_14 nvarchar(max) = '''''''',
	@SQLStatement3_15 nvarchar(max) = '''''''',
	@SourceTypeName nvarchar(50),
	@SourceTypeFamilyID int,
	@SourceID_varchar nvarchar(10),
	@LinkedYN bit,
	@Label nvarchar(200),
	@Description nvarchar(200),
	@RowsToInsert int, 
	@RowsInserted int = 0,
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

    SET @Step = ''''Set procedure variables''''
		SELECT
			@SourceTypeName = ST.SourceTypeName
		FROM
			pcINTEGRATOR.dbo.[Source] S
			INNER JOIN pcINTEGRATOR.dbo.[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
		WHERE
			S.SourceID = @SourceID

		SET @SourceID_varchar = CASE WHEN @SourceID <= 9 THEN ''''000'''' ELSE CASE WHEN @SourceID <= 99 THEN ''''00'''' ELSE CASE WHEN @SourceID <= 999 THEN ''''0'''' ELSE '''''''' END END END + CONVERT(nvarchar, @SourceID)

		SET @RowsToInsert = ISNULL(@Rows, 100000000)

	SET @Step = ''''Set field variables'''''
		IF @SourceTypeFamilyID = 2 --iScala
			SET @SQLStatement = @SQLStatement + '
		SELECT 
			@Label = ''''[glseg].[GL03002]'''',
			@Description = ''''CASE WHEN [glseg].[GL03003] IS NULL OR [glseg].[GL03003] = '''''''''''''''' THEN [glseg].[GL03002] ELSE [glseg].[GL03003] END'''''

		ELSE IF @SourceTypeFamilyID = 3 --EnterPrise
			SET @SQLStatement = @SQLStatement + '
		SELECT 
			@Label = ''''[glseg].[seg_code]'''',
			@Description = ''''CASE WHEN [glseg].[short_desc] = '''''''''''''''' THEN [glseg].[description] ELSE [glseg].[short_desc] END'''''

		ELSE IF @SourceTypeFamilyID = 5 --Navision
			SET @SQLStatement = @SQLStatement + '
		SELECT 
			@Label = ''''[glseg].[Code]'''',
			@Description = ''''[glseg].[Name]'''''

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Handle ANSI_WARNINGS''''
		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

    SET @Step = ''''Create Temp Tables''''
		CREATE TABLE #CursorTable
			(
			Entity nvarchar(50),
			Segment nvarchar(10),
			SourceTable nvarchar(100),
			MappingTypeID int,
			SortOrder int,
			FiscalYear int
			)

		CREATE TABLE #ReturnTable
			(
			[MemberId] bigint,
			[Label] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,	
			[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT
			)'

	SET @SQLStatement = @SQLStatement + '
    
	SET @Step = ''''Fill #CursorTable''''
		SET @SQLStatement = ''''
			INSERT INTO #CursorTable
				(
				Entity,
				Segment,
				SourceTable,
				MappingTypeID,
				SortOrder,
				FiscalYear
				)'

		IF @SourceTypeFamilyID = 2 --iScala
			SET @SQLStatement = @SQLStatement + '
			SELECT DISTINCT
				E.Entity,
				Segment = FS.SegmentCode,
				SourceTable = iST.TableName,
				MappingTypeID = MO.MappingTypeID,
				SortOrder = ISNULL(E.EntityPriority, 99999999),
				FiscalYear = iST.FiscalYear
			FROM
				[FinancialSegment] FS
				INNER JOIN [Entity] E ON E.SourceID = FS.SourceID AND E.EntityCode = FS.EntityCode COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
				INNER JOIN [MappedObject] MO ON MO.Entity = E.Entity AND MO.ObjectName = FS.SegmentName COLLATE DATABASE_DEFAULT AND MO.DimensionTypeID = -1 AND MO.MappedObjectName = '''''''''''' + @DimensionName + '''''''''''' AND MO.SelectYN <> 0
				INNER JOIN wrk_SourceTable iST ON iST.SourceID = E.SourceID AND iST.TableCode = ''''''''GL03'''''''' AND iST.EntityCode = FS.EntityCode
			WHERE
				FS.SourceID = '''' + CONVERT(nvarchar(10), @SourceID) + '''' AND
				(E.Entity = '''''''''''' + @Entity + '''''''''''' OR '''''''''''' + @Entity + '''''''''''' = ''''''''-1'''''''') AND
				FS.DimensionTypeID <> 1
			ORDER BY
				SortOrder,
				FiscalYear DESC'''''

		ELSE IF @SourceTypeFamilyID = 3 --EnterPrise
			SET @SQLStatement = @SQLStatement + '
			SELECT DISTINCT
				E.Entity,
				Segment = CONVERT(nvarchar(10), FS.SegmentNbr),
				SourceTable = E.Par01 + ''''''''.[dbo].[glseg'''''''' + CONVERT(nvarchar(10), FS.SegmentNbr) + '''''''']'''''''',
				MappingTypeID = MO.MappingTypeID,
				SortOrder = ISNULL(E.EntityPriority, 99999999),
				FiscalYear = NULL
			FROM
				[FinancialSegment] FS
				INNER JOIN [Entity] E ON E.SourceID = FS.SourceID AND E.EntityCode = FS.EntityCode COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
				INNER JOIN [MappedObject] MO ON MO.Entity = E.Entity AND MO.ObjectName = FS.SegmentName COLLATE DATABASE_DEFAULT AND MO.DimensionTypeID = -1 AND MO.MappedObjectName = '''''''''''' + @DimensionName + '''''''''''' AND MO.SelectYN <> 0
			WHERE
				FS.SourceID = '''' + CONVERT(nvarchar(10), @SourceID) + '''' AND
				(E.Entity = '''''''''''' + @Entity + '''''''''''' OR '''''''''''' + @Entity + '''''''''''' = ''''''''-1'''''''') AND
				FS.DimensionTypeID <> 1
			ORDER BY
				SortOrder,
				FiscalYear DESC'''''

		ELSE IF @SourceTypeFamilyID = 5 --Navision
			SET @SQLStatement = @SQLStatement + '
			SELECT DISTINCT
				E.Entity,
				Segment = FS.SegmentCode,
				SourceTable = FS.SQLDB + ''''''''.[dbo].'''''''' + FS.SegmentTable,
				MappingTypeID = MO.MappingTypeID,
				SortOrder = ISNULL(E.EntityPriority, 99999999),
				FiscalYear = NULL
			FROM
				[FinancialSegment] FS
				INNER JOIN [Entity] E ON E.SourceID = FS.SourceID AND E.EntityCode = FS.EntityCode COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
				INNER JOIN [MappedObject] MO ON MO.Entity = E.Entity AND MO.ObjectName = FS.SegmentName COLLATE DATABASE_DEFAULT AND MO.DimensionTypeID = -1 AND MO.MappedObjectName = '''''''''''' + @DimensionName + '''''''''''' AND MO.SelectYN <> 0
			WHERE
				FS.SourceID = '''' + CONVERT(nvarchar(10), @SourceID) + '''' AND
				(E.Entity = '''''''''''' + @Entity + '''''''''''' OR '''''''''''' + @Entity + '''''''''''' = ''''''''-1'''''''') AND
				FS.DimensionTypeID <> 1
			ORDER BY
				SortOrder,
				FiscalYear DESC'''''

	SET @SQLStatement = @SQLStatement + '
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @Debug <> 0 SELECT TempTable = ''''#CursorTable'''', * FROM #CursorTable

	SET @Step = ''''Fill #ReturnTable''''
		EXEC pcINTEGRATOR..spGet_Member @SourceID = @SourceID, @DimensionID = 0, @Dimension = @DimensionName, @SQLStatement3_01 = @SQLStatement3_01 OUT, @SQLStatement3_02 = @SQLStatement3_02 OUT, @SQLStatement3_03 = @SQLStatement3_03 OUT, @SQLStatement3_04 = @SQLStatement3_04 OUT, @SQLStatement3_05 = @SQLStatement3_05 OUT, @SQLStatement3_06 = @SQLStatement3_06 OUT, @SQLStatement3_07 = @SQLStatement3_07 OUT, @SQLStatement3_08 = @SQLStatement3_08 OUT, @SQLStatement3_09 = @SQLStatement3_09 OUT, @SQLStatement3_10 = @SQLStatement3_10 OUT, @SQLStatement3_11 = @SQLStatement3_11 OUT, @SQLStatement3_12 = @SQLStatement3_12 OUT, @SQLStatement3_13 = @SQLStatement3_13 OUT, @SQLStatement3_14 = @SQLStatement3_14 OUT, @SQLStatement3_15 = @SQLStatement3_15 OUT
		SET @SQLStatement = @SQLStatement3_01 + @SQLStatement3_02 + @SQLStatement3_03 + @SQLStatement3_04 + @SQLStatement3_05 + @SQLStatement3_06 + @SQLStatement3_07 + @SQLStatement3_08 + @SQLStatement3_09 + @SQLStatement3_10 + @SQLStatement3_11 + @SQLStatement3_12 + @SQLStatement3_13 + @SQLStatement3_14 + @SQLStatement3_15

		SET @SQLStatement = REPLACE(@SQLStatement, '''''''''''''''''''''''', '''''''''''''''')

		IF @Debug <> 0 PRINT @SQLStatement

		SET @SQLStatement = ''''
		INSERT INTO #ReturnTable
			(
			[MemberId],
			[Label],
			[Description],
			[HelpText],
			[RNodeType],
			[Source],
			[Parent]
			)
		'''' +	@SQLStatement'

SET @SQLStatement = @SQLStatement + '

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = ''''CREATE GL_Segment_Member_Cursor''''

  		DECLARE GL_Segment_Member_Cursor CURSOR FOR

			SELECT
				Entity,
				Segment,
				SourceTable,
				MappingTypeID
			FROM
				#CursorTable
			ORDER BY
				SortOrder,
				FiscalYear DESC

		OPEN GL_Segment_Member_Cursor
		FETCH NEXT FROM GL_Segment_Member_Cursor INTO @Entity, @Segment, @SourceTable, @MappingTypeID

		WHILE @@FETCH_STATUS = 0 AND @RowsToInsert > 0
		  BEGIN
			  SET @SQLStatement = ''''''''
	  
			  IF @Debug <> 0 SELECT Entity = @Entity, Segment = @Segment, SourceTable = @SourceTable, MappingTypeID = @MappingTypeID
			  IF @MappingTypeID IN (1, 2) OR (SELECT COUNT(1) FROM MappedLabel ML WHERE ML.MappedObjectName = @DimensionName AND ML.Entity = @Entity AND ML.MappingTypeID IN (1, 2)) > 0

			  SET @SQLStatement = ''''
					SELECT
						[MemberId] = NULL,
						[Label] = '''''''''''' + @Entity + '''''''''''' COLLATE DATABASE_DEFAULT,
						[Description] = E.EntityName COLLATE DATABASE_DEFAULT,
						[HelpText] = NULL,
						[RNodeType] = ''''''''P'''''''' COLLATE DATABASE_DEFAULT,	
						[Source] = '''''''''''' + @SourceTypeName + '''''''''''',
						[Parent] = ''''''''All_'''''''' COLLATE DATABASE_DEFAULT
					FROM
						Entity E
					WHERE
						SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''' AND
						Entity = '''''''''''' + @Entity + ''''''''''''''''

			  SET @SQLStatement = @SQLStatement + CASE WHEN @SQLStatement <> '''''''' THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ''''UNION '''' ELSE '''''''' END + ''''SELECT
						[MemberId] = NULL,
						[Label] = CASE WHEN ISNULL(ML.MappingTypeID, '''' + CONVERT(nvarchar, @MappingTypeID) + '''') = 1 THEN '''''''''''' + @Entity + ''''_'''''''' ELSE '''''''''''''''' END + CASE WHEN ML.MappingTypeID = 3 THEN ML.MappedLabel ELSE '''' + @Label + '''' COLLATE DATABASE_DEFAULT END + CASE WHEN ISNULL(ML.MappingTypeID, '''' + CONVERT(nvarchar, @MappingTypeID) + '''') = 2 THEN  ''''''''_'''' + @Entity + '''''''''''' ELSE '''''''''''''''' END COLLATE DATABASE_DEFAULT,
						[Description] = MAX('''' + @Description + '''' COLLATE DATABASE_DEFAULT), 
						[HelpText] = NULL,
						[RNodeType] = ''''''''L'''''''' COLLATE DATABASE_DEFAULT,
						[Source] = '''''''''''' + @SourceTypeName + '''''''''''',
						[Parent] = CASE WHEN MAX(ISNULL(ML.MappingTypeID, '''' + CONVERT(nvarchar, @MappingTypeID) + '''')) IN (1, 2) THEN '''''''''''' + @Entity + '''''''''''' ELSE ''''''''ToBeSet'''''''' END COLLATE DATABASE_DEFAULT
					FROM
						'''' + @SourceTable  + '''' [glseg]
						LEFT JOIN MappedLabel ML ON ML.MappedObjectName = '''''''''''' + @DimensionName + '''''''''''' AND ML.Entity = '''''''''''' + @Entity + '''''''''''' AND '''' + @Label + '''' COLLATE DATABASE_DEFAULT BETWEEN ML.LabelFrom AND ML.LabelTo AND ML.SelectYN <> 0
					' + CASE WHEN @SourceTypeFamilyID = 2 THEN 'WHERE
						[glseg].[GL03001] = ''''''''''''' + ' + @Segment + ' + ''''''''''''' AND
						[glseg].[GL03002] <> '''''''''''''''' AND [glseg].[GL03002] IS NOT NULL' ELSE '' END + '
					' + CASE WHEN @SourceTypeFamilyID = 5 THEN 'WHERE
						[glseg].[Dimension Code] = ''''''''''''' + ' + @Segment + ' + '''''''''''''' ELSE '' END + '
					GROUP BY
						CASE WHEN ISNULL(ML.MappingTypeID, '''' + CONVERT(nvarchar, @MappingTypeID) + '''') = 1 THEN '''''''''''' + @Entity + ''''_'''''''' ELSE '''''''''''''''' END + CASE WHEN ML.MappingTypeID = 3 THEN ML.MappedLabel ELSE '''' + @Label + '''' COLLATE DATABASE_DEFAULT END + CASE WHEN ISNULL(ML.MappingTypeID, '''' + CONVERT(nvarchar, @MappingTypeID) + '''') = 2 THEN  ''''''''_'''' + @Entity + '''''''''''' ELSE '''''''''''''''' END'''''

	SET @SQLStatement = @SQLStatement + '

			  SET @SQLStatement = ''''
				INSERT INTO #ReturnTable
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Source],
					[Parent]
					)
				SELECT TOP @RowsToInsert
					[MemberId] = sub.[MemberId],
					[Label] = sub.[Label],
					[Description] = sub.[Description],
					[HelpText] = sub.[HelpText],
					[RNodeType] = sub.[RNodeType],	
					[Source] = sub.[Source],
					[Parent] = sub.[Parent]
				FROM
					(
					'''' +	@SQLStatement + ''''
					) sub
				WHERE
					NOT EXISTS (SELECT 1 FROM #ReturnTable RT WHERE RT.Label = sub.Label)
				ORDER BY
					CASE WHEN [sub].[Label] IN (''''''''All_'''''''', ''''''''NONE'''''''') OR [sub].[Label] LIKE ''''''''%NONE%'''''''' THEN ''''''''  '''''''' + [sub].[Label] ELSE [sub].[Label] END''''

			SET @SQLStatement = REPLACE (@SQLStatement, ''''@RowsToInsert'''', @RowsToInsert)				

			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

			SET @RowsInserted = @@ROWCOUNT
			SET @RowsToInsert = @RowsToInsert - @RowsInserted

			UPDATE #ReturnTable
			SET [SBZ] = CASE WHEN [RNodeType] IN (''''L'''', ''''LC'''') THEN 0 ELSE 1 END

			FETCH NEXT FROM GL_Segment_Member_Cursor INTO @Entity, @Segment, @SourceTable, @MappingTypeID
		  END

		CLOSE GL_Segment_Member_Cursor
		DEALLOCATE GL_Segment_Member_Cursor

	SET @Step = ''''Return Members''''
		SELECT 
			[MemberId],
			[Label],
			[Description] = CASE WHEN [Description] = '''''''' THEN [Label] ELSE [Description] END,
			[HelpText],
			[RNodeType],
			[SBZ],
			[Source],	
			[Synchronized] = 1,
			[Parent]
		FROM
			#ReturnTable
		ORDER BY
			CASE WHEN [Label] IN (''''All_'''', ''''NONE'''') OR [Label] LIKE ''''%NONE%'''' THEN ''''  '''' + [Label] ELSE [Label] END'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Drop Temp Tables''''
		DROP TABLE #CursorTable
		DROP TABLE #ReturnTable

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, Deleted = 0, Inserted = 0, Updated = 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

  	SET @Step = 'Create source specific Raw Procedure'
		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Create source specific Segment Raw Procedure', [SQLStatement] = @SQLStatement
		EXEC (@SQLStatement)

  	SET @Step = 'Create generic Load Procedure'
		SET @ObjectName = 'spIU_' + @SourceID_varchar + '_GL_Segment'

		TRUNCATE TABLE #Action
		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ObjectName + '''' + ', ' + '''P''' 
		INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
		SELECT @Action = [Action] FROM #Action

		SET @SQLStatement = @Action + ' PROCEDURE [dbo].[' + @ObjectName + ']

	@JobID int = 0,
	@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
	@Entity nvarchar(50) = ''''-1'''',
	@Rows int = NULL,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SET ANSI_WARNINGS OFF

DECLARE
	@StartTime datetime,
	@StartTime_Step datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Deleted_Step int = 0,
    @Inserted_Step int = 0,
    @Updated_Step int = 0,
	@DestinationDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@DimensionName nvarchar(100),
	@DimensionHierarchy nvarchar(100),
	@SourceID_varchar nvarchar(10),

	@LinkedYN bit,
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET DATEFIRST 1
		SET @StartTime = GETDATE()

    SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)
       
		SET @SourceID_varchar = CASE WHEN @SourceID <= 9 THEN ''''000'''' ELSE CASE WHEN @SourceID <= 99 THEN ''''00'''' ELSE CASE WHEN @SourceID <= 999 THEN ''''0'''' ELSE '''''''' END END END + CONVERT(nvarchar, @SourceID)

		SELECT
			@DestinationDatabase = A.DestinationDatabase
		FROM
			pcINTEGRATOR.dbo.[Application] A
			INNER JOIN pcINTEGRATOR.dbo.[Model] M ON M.ApplicationID = A.ApplicationID
			INNER JOIN pcINTEGRATOR.dbo.[Source] S ON S.ModelID = M.ModelID AND S.SourceID = @SourceID'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create Temp tables''''
		CREATE TABLE [#GL_Segment]
			(
			[MemberId] bigint,
			[Label] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[SBZ] bit,	
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,	
			[Synchronized] bit,
			[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE [#Segment_Cursor]
			(
			DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #LeafCheck
			(
			[MemberId] [bigint] NOT NULL,
			HasChild bit NOT NULL
			)

	SET @Step = ''''Handle ANSI_WARNINGS''''
		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = ''''Insert into temp table''''
		SET @SQLStatement = ''''
		INSERT INTO [#Segment_Cursor]
			(
			DimensionName
			)
		SELECT DISTINCT
			DimensionName = MO.MappedObjectName
		FROM
			[Entity] E 
			INNER JOIN [FinancialSegment] FS ON FS.SourceID = E.SourceID AND FS.EntityCode COLLATE DATABASE_DEFAULT = E.EntityCode
			INNER JOIN MappedObject MO ON MO.Entity = E.Entity COLLATE DATABASE_DEFAULT AND MO.ObjectName = FS.SegmentName COLLATE DATABASE_DEFAULT AND MO.DimensionTypeID = -1 AND MO.ObjectTypeBM & 2 > 0 AND MO.SelectYN <> 0
		WHERE
			E.SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''' AND 
			(E.Entity = '''''''''''' + @Entity + '''''''''''' OR '''''''''''' + @Entity + '''''''''''' = ''''''''-1'''''''') AND
			E.SelectYN <> 0
		ORDER BY
			MO.MappedObjectName''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET ANSI_WARNINGS OFF'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create Segment Cursor''''
		DECLARE Segment_Cursor CURSOR FOR

		SELECT DISTINCT
			DimensionName
		FROM
			[#Segment_Cursor]
		ORDER BY
			DimensionName

			OPEN Segment_Cursor
			FETCH NEXT FROM Segment_Cursor INTO @DimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @Step = ''''Set @StartTime_Step''''
						SET @StartTime_Step = GETDATE()

					SET @Step = ''''Insert into temp table''''
						TRUNCATE TABLE [#GL_Segment]
						INSERT INTO [#GL_Segment] EXEC ' + @ObjectName + '_Raw @JobID = @JobID, @SourceID = @SourceID, @Entity = @Entity, @DimensionName = @DimensionName, @Rows = @Rows

					SET @Step = ''''Update Description from source database where Synchronized is set to true.''''

						SET @SQLStatement = ''''
						UPDATE
							[Dim]
						SET
							[Description] = Members.[Description]
						FROM
							['''' + @DestinationDatabase + ''''].[dbo].[S_DS_'''' + @DimensionName + ''''] [Dim] 
							INNER JOIN [#GL_Segment] Members ON Members.Label COLLATE DATABASE_DEFAULT = [Dim].Label 
						WHERE 
							[Dim].[Synchronized] <> 0''''
						
						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @Updated_Step = @@ROWCOUNT'

SET @SQLStatement = @SQLStatement + '
		
					SET @Step = ''''Insert new members from source database''''
						
						SET @SQLStatement = ''''
						INSERT INTO ['''' + @DestinationDatabase + ''''].[dbo].[S_DS_'''' + @DimensionName + '''']
							(
							[MemberId],
							[Label],
							[Description], 
							[HelpText],
							[RNodeType],
							[SBZ],
							[Source],
							[Synchronized]
							)
						SELECT
							[MemberId],
							[Label],
							[Description], 
							[HelpText],
							[RNodeType],
							[SBZ],
							[Source],
							[Synchronized]
						FROM   
							[#GL_Segment] Members
						WHERE
							NOT EXISTS (SELECT 1 FROM ['''' + @DestinationDatabase + ''''].[dbo].[S_DS_'''' + @DimensionName + ''''] [Dim] WHERE Members.Label COLLATE DATABASE_DEFAULT = [Dim].Label)''''

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @Inserted_Step = @@ROWCOUNT

					SET @Step = ''''Update MemberId''''
						EXEC spSet_MemberId @Database = @DestinationDatabase, @Dimension = @DimensionName, @Debug = @Debug'

SET @SQLStatement = @SQLStatement + '

					SET @Step = ''''Check which parent members have leaf members as children.''''
						TRUNCATE TABLE #LeafCheck

						IF @Debug <> 0 SELECT TempTable = ''''#GL_Segment'''', Dimension = @DimensionName, * FROM #GL_Segment

						EXEC spSet_LeafCheck @JobID = @JobID, @Database = @DestinationDatabase, @Dimension = @DimensionName, @DimensionTemptable = ''''#GL_Segment'''', @Debug = @Debug

					SET @Step = ''''Insert new members into the default hierarchy. To change the hierarchy, use the Modeler.''''

						SET @SQLStatement = ''''
						INSERT INTO ['''' + @DestinationDatabase + ''''].[dbo].[S_HS_'''' + @DimensionName + ''''_'''' + @DimensionName + '''']
							(
							[MemberId],
							[ParentMemberId],
							[SequenceNumber]
							)
						SELECT
							D1.MemberId,
							ISNULL(D2.MemberId, 0),
							D1.MemberId  
						FROM
							['''' + @DestinationDatabase + ''''].[dbo].[S_DS_'''' + @DimensionName + ''''] D1
							INNER JOIN [#GL_Segment] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
							LEFT JOIN ['''' + @DestinationDatabase + ''''].[dbo].[S_DS_'''' + @DimensionName + ''''] D2 ON D2.Label = CONVERT(nvarchar(255), V.Parent) COLLATE DATABASE_DEFAULT
							LEFT JOIN [#LeafCheck] LC ON LC.MemberId = D1.MemberId AND LC.HasChild <> 0
						WHERE
							NOT EXISTS (SELECT 1 FROM ['''' + @DestinationDatabase + ''''].[dbo].[S_HS_'''' + @DimensionName + ''''_'''' + @DimensionName + ''''] H WHERE H.MemberId = D1.MemberId) AND
							[D1].[Synchronized] <> 0 AND
							D1.MemberId <> ISNULL(D2.MemberId, 0) AND
							D1.MemberId IS NOT NULL AND
							(D1.RNodeType IN (''''''''L'''''''', ''''''''LC'''''''') OR LC.MemberId IS NOT NULL)
						ORDER BY
							D1.Label''''

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)'

SET @SQLStatement = @SQLStatement + '

					SET @Step = ''''Copy the hierarchy to all instances''''
						SET @DimensionHierarchy = @DimensionName + ''''_'''' + @DimensionName
						EXEC spSet_HierarchyCopy @Database = @DestinationDatabase, @DimensionHierarchy = @DimensionHierarchy

					SET @Step = ''''Step count handling''''
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step

					SET @Step = ''''Set @Duration Step''''	
						SET @Duration = GetDate() - @StartTime_Step

					SET @Step = ''''Insert into JobLog''''
						INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + '''' ('''' + @DimensionName + '''')'''', @Duration, @Deleted_Step, @Inserted_Step, @Updated_Step, @Version
 
					FETCH NEXT FROM Segment_Cursor INTO @DimensionName
				END

		CLOSE Segment_Cursor
		DEALLOCATE Segment_Cursor

	SET @Step = ''''Drop the temp tables''''
		DROP TABLE [#Segment_Cursor]
		DROP TABLE [#GL_Segment]
		DROP TABLE [#LeafCheck]

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime
		
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Create source specific Segment Load Procedure', [SQLStatement] = @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Drop Temp table'
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
