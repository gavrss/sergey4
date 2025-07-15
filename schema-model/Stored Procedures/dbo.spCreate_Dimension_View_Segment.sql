SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Dimension_View_Segment] 

	@SourceID int = NULL,
	@JobID int = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@ProcedureID int = 880000345

--#WITH ENCRYPTION#--
AS

/*
EXEC spCreate_Dimension_View_Segment @SourceID = -1579, @Debug = true --E9
EXEC spCreate_Dimension_View_Segment @SourceID = 307, @Debug = true --iScala
EXEC spCreate_Dimension_View_Segment @SourceID = 807, @Debug = true --Navision
EXEC spCreate_Dimension_View_Segment @SourceID = 907, @Debug = true --Axapta
EXEC spCreate_Dimension_View_Segment @SourceID = 1207, @Debug = true --Enterprise
EXEC spCreate_Dimension_View_Segment @SourceID = 983, @Debug = true --CBN
EXEC spCreate_Dimension_View_Segment @GetVersion = 1
*/

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@BaseQuerySQLStatement nvarchar(max),
	@BaseQuerySQLStatement1 nvarchar(max),
	@BaseQuerySQLStatement2 nvarchar(max),
	@SQLStatement nvarchar(max),
	@SQLStatementMember nvarchar(max),
	@SQLStatement3_01 nvarchar(max) = '',
	@SQLStatement3_02 nvarchar(max) = '',
	@SQLStatement3_03 nvarchar(max) = '',
	@SQLStatement3_04 nvarchar(max) = '',
	@SQLStatement3_05 nvarchar(max) = '',
	@SQLStatement3_06 nvarchar(max) = '',
	@SQLStatement3_07 nvarchar(max) = '',
	@SQLStatement3_08 nvarchar(max) = '',
	@SQLStatement3_09 nvarchar(max) = '',
	@SQLStatement3_10 nvarchar(max) = '',
	@SQLStatement3_11 nvarchar(max) = '',
	@SQLStatement3_12 nvarchar(max) = '',
	@SQLStatement3_13 nvarchar(max) = '',
	@SQLStatement3_14 nvarchar(max) = '',
	@SQLStatement3_15 nvarchar(max) = '',	
	@SQLStatement_spTemplateBegin nvarchar(max),
	@SQLStatement_spTemplateEnd nvarchar(max),
	@SQLStatement_spObjectName nvarchar(255),
	@SQLWhere1 nvarchar(500),
	@SQLWhere2 nvarchar(500),
	@SQLDescription nvarchar(100),
	@Action nvarchar(10),
	@UserID int,
	@InstanceID int,
	@VersionID int,
	@ApplicationID int,
	@SourceType nvarchar(50),
	@SourceDatabase nvarchar(255),
	@ETLDatabase nvarchar(50),
	@SourceID_varchar nvarchar(10),
	@ObjectName nvarchar(50),
	@spObjectName nvarchar(50),
	@Entity nvarchar(1000),
	@EntityPriority int,
	@TableName nvarchar(255),
	@Union nvarchar(50),
	@Dimension nvarchar(50),
	@Segment nvarchar(100),
	@StartYear int,
	@BaseModelID int,
	@OptFinanceDimYN bit,
	@SourceDBTypeID int,
	@SourceTypeFamilyID int,
	@SourceTypeID int,
	@Owner nvarchar(50),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.2116'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.2.2067' SET @Description = 'Handling of long SQL strings.'
		IF @Version = '1.2.2068' SET @Description = 'Requirement of GLB.MainBook = 1 for Epicor ERP is removed.'
		IF @Version = '1.3.2070' SET @Description = 'Collation problems fixed.'
		IF @Version = '1.3.2074' SET @Description = 'Sortorder fixed to get All_ & NONE first.'
		IF @Version = '1.3.2075' SET @Description = 'Changed from EntityCode to Entity when reading from the Entity table.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption, Added EntityPriority for Epicor ERP'
		IF @Version = '1.3.2095' SET @Description = 'Added RNodeType'
		IF @Version = '1.3.2101' SET @Description = 'Added Axapta'
		IF @Version = '1.3.2106' SET @Description = 'Added SBZ property'
		IF @Version = '1.3.2107' SET @Description = 'Added check on SourceTypeID'
		IF @Version = '1.3.2109' SET @Description = 'Fixed MemberIDs for all Static Members.'
		IF @Version = '1.3.2111' SET @Description = 'Added Navision'
		IF @Version = '1.3.2116' SET @Description = 'Added HelpText. Handle unicode in strings.'
		 
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

		SET @UserID = ISNULL(@UserID, -10)

		SELECT
			@InstanceID = A.InstanceID,
			@VersionID = A.VersionID,
			@SourceTypeID = S.SourceTypeID,
			@SourceType = ST.SourceTypeName,
			@SourceDBTypeID = 	ST.SourceDBTypeID,
			@SourceTypeFamilyID = ST.SourceTypeFamilyID,
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = A.ETLDatabase,
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

		EXEC [spGet_Owner] @SourceTypeID, @Owner OUTPUT

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Check Model type and SourceType'
		IF @OptFinanceDimYN = 0 OR @SourceTypeID = 6 RETURN

	SET @Step = 'Check Source DBType'
		IF @Debug <> 0 SELECT SourceDBTypeID = @SourceDBTypeID
			IF @SourceDBTypeID = 2 
			BEGIN
				EXEC [spCreate_Dimension_Procedure_Segment] @SourceID = @SourceID, @JobID = @JobID, @Encryption = @Encryption, @Debug = @Debug, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated
				RETURN
			END

	SET @Step = 'Make SP Template'	
		SET @SQLStatement_spTemplateBegin = '
@UserID int = ' + CONVERT(nvarchar(10), @UserID) + ',
@InstanceID int = ' + CONVERT(nvarchar(10), @InstanceID) + ',
@VersionID int = ' + CONVERT(nvarchar(10), @VersionID) + ',

@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
@Entity nvarchar(50) = ''''-1'''',
@SequenceBMStep int = 65535,
@StaticMemberYN bit = 1,

@JobID int = NULL,
@JobLogID int = NULL,
@Rows int = NULL,
@ProcedureID int = ' + CONVERT(nvarchar, @ProcedureID) + ',
@StartTime datetime = NULL,
@Duration time(7) = ''''00:00:00'''' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT,
@Selected int = 0 OUT,
@GetVersion bit = 0,
@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS' + CHAR(13) + CHAR(10) +

'
SET ANSI_WARNINGS ON

DECLARE
	@CalledYN bit = 1,

	@Step nvarchar(255),
	@Message nvarchar(500) = '''''''',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@CreatedBy nvarchar(50) = ''''Auto'''',
	@ModifiedBy nvarchar(50) = ''''Auto'''',
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''SET @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''SET procedure variables''''
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())
'

		SET @SQLStatement_spTemplateEnd = '
	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		IF @CalledYN = 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = ''''Define exit point''''
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
'

	SET @Step = 'Create temp table'
		CREATE TABLE #FinanceDimension
		(
			[DimensionName] [nvarchar](100) COLLATE DATABASE_DEFAULT NOT NULL,
			[Entity] [nvarchar](100) COLLATE DATABASE_DEFAULT NOT NULL,
			[Segment] [nvarchar](100) COLLATE DATABASE_DEFAULT NOT NULL
		)

		SET @SQLStatement = '
		SELECT DISTINCT
			MO.MappedObjectName,
			E.Entity,
			SegmentCode = CASE WHEN ''' + CONVERT(nvarchar, @SourceTypeFamilyID) + ''' = 1 THEN CONVERT(nvarchar, FS.SegmentNbr) ELSE FS.SegmentCode END
		FROM
			[' + @ETLDatabase + '].dbo.[FinancialSegment] FS
			INNER JOIN [' + @ETLDatabase + '].dbo.[MappedObject] MO ON MO.ObjectName = FS.SegmentName COLLATE DATABASE_DEFAULT AND MO.DimensionTypeID = -1 AND MO.SelectYN <> 0
			INNER JOIN [' + @ETLDatabase + '].dbo.[Entity] E ON E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND E.EntityCode = FS.EntityCode COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
		WHERE
			FS.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + '
		ORDER BY
			MO.MappedObjectName,
			E.Entity'

		SET @SQLStatement = '
		SELECT DISTINCT
			MO.MappedObjectName,
			E.Entity,
			Segment = CASE ' + CONVERT(nvarchar(10), @SourceTypeFamilyID) + ' WHEN 1 THEN CONVERT(nvarchar(100), FS.SegmentNbr) WHEN 4 THEN FS.SegmentTable ELSE FS.SegmentCode END
		FROM
			' + @ETLDatabase + '.dbo.[Entity] E
			INNER JOIN ' + @ETLDatabase + '.dbo.[FinancialSegment] FS ON FS.SourceID = E.SourceID AND FS.EntityCode = E.EntityCode
			INNER JOIN ' + @ETLDatabase + '.dbo.[MappedObject] MO ON MO.Entity = E.Entity AND MO.ObjectName = FS.SegmentName AND MO.DimensionTypeID = -1 AND MO.SelectYN <> 0
		WHERE
			E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND
			E.SelectYN <> 0
		ORDER BY
			MO.MappedObjectName,
			E.Entity'

		IF @Debug <> 0 PRINT @SourceType
		IF @Debug <> 0 PRINT @SQLStatement

		INSERT INTO #FinanceDimension ([DimensionName], [Entity], [Segment]) EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = '#FinanceDimension', * FROM #FinanceDimension

		CREATE TABLE #Action
		(
		[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
		)

		IF @SourceTypeFamilyID IN (1, 4) -- Epicor ERP, Axapta
		  BEGIN
  
			SET @Step = 'Create Segment_DimensionName_Cursor'

  			DECLARE Segment_DimensionName_Cursor CURSOR FOR

			SELECT DISTINCT DimensionName FROM #FinanceDimension

			OPEN Segment_DimensionName_Cursor
			FETCH NEXT FROM Segment_DimensionName_Cursor INTO @Dimension
	
			WHILE @@FETCH_STATUS = 0
			  BEGIN
				IF @Debug <> 0 SELECT Dimension = @Dimension
				SET @ObjectName = N'vw_' + @SourceID_varchar + '_' + @Dimension
				IF @Debug <> 0 SELECT ObjectName = @ObjectName

				SET @SQLStatement = N'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject N''' + @ObjectName + '''' + ', ' + '''V''' 
				INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
				SELECT @Action = [Action] FROM #Action

				IF @Debug <> 0 PRINT @SQLStatement
				IF @Debug <> 0 SELECT [Action] = @Action

				IF @SourceTypeFamilyID = 1 --Epicor ERP
					BEGIN
						SET @BaseQuerySQLStatement = '
			SELECT
				[MemberId] = NULL,
				[Label] = CASE WHEN ISNULL(ML.MappingTypeID, MO.MappingTypeID) = 1 THEN E.Entity + ''''_'''' ELSE '''''''' END + CASE WHEN ML.MappingTypeID = 3 THEN ML.MappedLabel ELSE COASV.SegmentCode COLLATE DATABASE_DEFAULT END + CASE WHEN ISNULL(ML.MappingTypeID, MO.MappingTypeID) = 2 THEN  ''''_'''' + E.Entity ELSE '''''''' END,
				[Description] = MAX(ISNULL(CASE WHEN COASV.SegmentName = '''''''' THEN NULL ELSE COASV.SegmentName END, COASV.SegmentCode)),
				[HelpText] = '''''''',
				[RNodeType] = ''''L'''',
				[Source] = ''''' + @SourceType + ''''',
				[Parent] = ''''All_''''
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[COASegValues] COASV
				INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB ON GLB.Company = COASV.Company AND GLB.COACode = COASV.COACode
				INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COASegment] COAS ON COAS.Company = GLB.Company AND COAS.COACode = GLB.COACode AND COAS.SegmentNbr = COASV.SegmentNbr
				INNER JOIN [' + @ETLDatabase + '].[dbo].[Entity] E ON E.Par01 = GLB.Company COLLATE DATABASE_DEFAULT AND E.Par02 = GLB.BookID COLLATE DATABASE_DEFAULT AND E.Par03 = GLB.COACode COLLATE DATABASE_DEFAULT AND E.Par04 <> COAS.SegmentName COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
				INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.MappedObjectName = N''''' + @Dimension + ''''' AND MO.Entity = E.Entity AND MO.ObjectName = COAS.SegmentName COLLATE DATABASE_DEFAULT AND MO.SelectYN <> 0
				INNER JOIN (
					SELECT
						COASV.SegmentCode,
						EntityPriority = MIN(ISNULL(E.EntityPriority, 99999999))'

						SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + '
					FROM
						' + @SourceDatabase + '.[' + @Owner + '].[COASegValues] COASV
						INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB ON GLB.Company = COASV.Company AND GLB.COACode = COASV.COACode
						INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COASegment] COAS ON COAS.Company = GLB.Company AND COAS.COACode = GLB.COACode AND COAS.SegmentNbr = COASV.SegmentNbr
						INNER JOIN [' + @ETLDatabase + '].[dbo].[Entity] E ON E.Par01 = GLB.Company COLLATE DATABASE_DEFAULT AND E.Par02 = GLB.BookID COLLATE DATABASE_DEFAULT AND E.Par03 = GLB.COACode COLLATE DATABASE_DEFAULT AND E.Par04 <> COAS.SegmentName COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0
						INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.MappedObjectName = N''''' + @Dimension + ''''' AND MO.Entity = E.Entity AND MO.ObjectName = COAS.SegmentName COLLATE DATABASE_DEFAULT AND MO.SelectYN <> 0
					GROUP BY
						COASV.SegmentCode	
					) Prio ON Prio.SegmentCode = COASV.SegmentCode AND Prio.EntityPriority = ISNULL(E.EntityPriority, 99999999)
				LEFT JOIN [' + @ETLDatabase + '].[dbo].MappedLabel ML ON ML.MappedObjectName = MO.MappedObjectName AND ML.Entity = E.Entity AND COASV.SegmentCode COLLATE DATABASE_DEFAULT BETWEEN ML.LabelFrom AND ML.LabelTo AND ML.SelectYN <> 0
			GROUP BY
				CASE WHEN ISNULL(ML.MappingTypeID, MO.MappingTypeID) = 1 THEN E.Entity + ''''_'''' ELSE '''''''' END + CASE WHEN ML.MappingTypeID = 3 THEN ML.MappedLabel ELSE COASV.SegmentCode COLLATE DATABASE_DEFAULT END + CASE WHEN ISNULL(ML.MappingTypeID, MO.MappingTypeID) = 2 THEN  ''''_'''' + E.Entity ELSE '''''''' END'
					END
				ELSE IF @SourceTypeFamilyID = 4 --Axapta
					BEGIN
						IF @Debug <> 0 SELECT Segment, Entity FROM #FinanceDimension WHERE DimensionName = @Dimension

						CREATE TABLE #RowCount
						(
						[Column] nvarchar(50),
						[RowCount] int
						)

						CREATE TABLE #EntityPriority
						(
						EntityPriority int
						)

						SELECT @BaseQuerySQLStatement = NULL, @BaseQuerySQLStatement1 = NULL, @BaseQuerySQLStatement2 = NULL, @EntityPriority = NULL

						DECLARE Axapta_Segment_Cursor CURSOR FOR

							SELECT DISTINCT Segment FROM #FinanceDimension WHERE DimensionName = @Dimension

							OPEN Axapta_Segment_Cursor
							FETCH NEXT FROM Axapta_Segment_Cursor INTO @Segment

							WHILE @@FETCH_STATUS = 0
								BEGIN
									SET @Entity = NULL
									TRUNCATE TABLE #RowCount
									TRUNCATE TABLE #EntityPriority

									SET @SQLStatement = 'INSERT INTO #RowCount ([Column], [RowCount]) SELECT [Column] = c.name, [RowCount] = COUNT(1) FROM ' + @SourceDatabase + '.[dbo].[sysobjects] v INNER JOIN ' + @SourceDatabase + '.[sys].[columns] c ON c.[object_id] = v.[id] AND c.name IN (''DESCRIPTION'', ''NAME'', ''DATAAREAID'') WHERE v.xtype IN (''V'', ''U'') AND v.name = ''' + @Segment + ''' GROUP BY c.name'
									PRINT @SQLStatement
									EXEC (@SQLStatement)

									--Check DataAreaId
									SELECT @Entity = CASE WHEN @Entity IS NULL THEN '' ELSE @Entity + ', ' END + '''''' + Entity + '''''' FROM #FinanceDimension WHERE DimensionName = @Dimension AND Segment = @Segment ORDER BY Entity
									IF (SELECT [RowCount] FROM #RowCount WHERE [Column] = 'DATAAREAID') > 0
										BEGIN
											SET @SQLWhere1 = CHAR(13) + CHAR(10) +
												'				INNER JOIN (SELECT Par04, EntityPriority = MIN(ISNULL(E.EntityPriority, 99999999)) FROM Entity E WHERE SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' GROUP BY Par04) EP1 ON EP1.Par04 = S.[DATAAREAID] COLLATE DATABASE_DEFAULT' + CHAR(13) + CHAR(10) +
												'			WHERE' + CHAR(13) + CHAR(10) +
												'				[DATAAREAID] IN (' + @Entity + ')'
											SET @SQLWhere2 = CHAR(13) + CHAR(10) +
												'					INNER JOIN (SELECT Par04, EntityPriority = MIN(ISNULL(E.EntityPriority, 99999999)) FROM Entity E WHERE SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' GROUP BY Par04) EP1 ON EP1.Par04 = S.[DATAAREAID] COLLATE DATABASE_DEFAULT' + CHAR(13) + CHAR(10) +
												'				WHERE' + CHAR(13) + CHAR(10) +
												'					[DATAAREAID] IN (' + @Entity + ')' + CHAR(13) + CHAR(10) +
												'				GROUP BY'  + CHAR(13) + CHAR(10) +
												'					S.[VALUE]'
											IF @Debug <> 0 SELECT Entity = @Entity
										END
									ELSE
										BEGIN
											SET @SQLWhere1 = ''
											SET @SQLWhere2 = ''
											SET @Entity = REPLACE(@Entity, '''''', '''')
											SET @SQLStatement = 'INSERT INTO #EntityPriority (EntityPriority) SELECT EntityPriority = MIN(ISNULL(E.EntityPriority, 99999999)) FROM ' + @ETLDatabase + '..Entity E WHERE E.Par04 IN (' + @Entity + ')'
											IF @Debug <> 0 PRINT @SQLStatement
											EXEC(@SQLStatement)
											SELECT @EntityPriority = EntityPriority FROM #EntityPriority
										END

									--Check Description
									SELECT @SQLDescription = CASE WHEN MAX([Column]) = 'NAME' THEN 'NAME' ELSE CASE WHEN MIN([Column]) = 'DESCRIPTION' THEN 'DESCRIPTION' ELSE 'VALUE' END END FROM #RowCount WHERE [Column] IN ('DESCRIPTION', 'NAME') AND [RowCount] > 0
					
									IF @Debug <> 0
										BEGIN
											SELECT * FROM #RowCount
											SELECT SQLDescription = @SQLDescription
										END

									--Set Base Query SQLStatements
									SET @BaseQuerySQLStatement1 = CASE WHEN @BaseQuerySQLStatement1 IS NULL THEN '' ELSE @BaseQuerySQLStatement1 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'UNION' END + CHAR(13) + CHAR(10) +
										'			SELECT' + CHAR(13) + CHAR(10) +
										'				[MemberId] = NULL,' + CHAR(13) + CHAR(10) +
										'				[Label] = CONVERT(nvarchar(100), S.[VALUE]),' + CHAR(13) + CHAR(10) +
										'				[Description] = CONVERT(nvarchar(100), S.[' + @SQLDescription + ']),' + CHAR(13) + CHAR(10) +
										'				[EntityPriority] = ' + ISNULL(CONVERT(nvarchar(100), @EntityPriority), 'EP1.[EntityPriority]') + CHAR(13) + CHAR(10) +
										'			FROM' + CHAR(13) + CHAR(10) +
										'				' + @SourceDatabase + '.[dbo].[' + @Segment + '] S' + @SQLWhere1

									SET @BaseQuerySQLStatement2 = CASE WHEN @BaseQuerySQLStatement2 IS NULL THEN '' ELSE @BaseQuerySQLStatement2 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 'UNION' END + CHAR(13) + CHAR(10) +
										'				SELECT' + CHAR(13) + CHAR(10) +
										'					S.[VALUE],' + CHAR(13) + CHAR(10) +
										'					[EntityPriority] = ' + ISNULL(CONVERT(nvarchar(100), @EntityPriority), 'MIN(EP1.[EntityPriority])') + CHAR(13) + CHAR(10) +
										'				FROM' + CHAR(13) + CHAR(10) +
										'					' + @SourceDatabase + '.[dbo].[' + @Segment + '] S' + @SQLWhere2


									FETCH NEXT FROM Axapta_Segment_Cursor INTO @Segment
								END

						CLOSE Axapta_Segment_Cursor
						DEALLOCATE Axapta_Segment_Cursor

						SET @BaseQuerySQLStatement2 = '
			SELECT
				[Label] = CONVERT(nvarchar(100), EP1.[VALUE]),
				[EntityPriority] = MIN(EP1.[EntityPriority])
			FROM
				(' + @BaseQuerySQLStatement2 + '
				) EP1
			GROUP BY
				EP1.VALUE'

						SET @BaseQuerySQLStatement = '
	SELECT
		[MemberId] = NULL,
		[Label] = S.[Label],
		[Description] = S.[DESCRIPTION],
		[HelpText] = '''''''',
		[RNodeType] = ''''L'''',
		[Source] = ''''' + @SourceType + ''''',
		[Parent] = ''''All_''''
	FROM
		(' + @BaseQuerySQLStatement1 + '
		) S
		INNER JOIN
		(' + @BaseQuerySQLStatement2 + '
		) EP2 ON EP2.[Label] = S.[Label] AND EP2.EntityPriority = S.EntityPriority'

						DROP TABLE #RowCount
						DROP TABLE #EntityPriority
						
					END

				IF @Debug <> 0 PRINT @BaseQuerySQLStatement
				IF @Debug <> 0 SELECT SourceID = @SourceID, DimensionID = 0, Dimension = @Dimension, SQLStatement = @SQLStatementMember

				EXEC spGet_Member @Debug = @Debug, @SourceID = @SourceID, @DimensionID = 0, @Dimension = @Dimension, @SQLStatement3_01 = @SQLStatement3_01 OUT, @SQLStatement3_02 = @SQLStatement3_02 OUT, @SQLStatement3_03 = @SQLStatement3_03 OUT, @SQLStatement3_04 = @SQLStatement3_04 OUT, @SQLStatement3_05 = @SQLStatement3_05 OUT, @SQLStatement3_06 = @SQLStatement3_06 OUT, @SQLStatement3_07 = @SQLStatement3_07 OUT, @SQLStatement3_08 = @SQLStatement3_08 OUT, @SQLStatement3_09 = @SQLStatement3_09 OUT, @SQLStatement3_10 = @SQLStatement3_10 OUT, @SQLStatement3_11 = @SQLStatement3_11 OUT, @SQLStatement3_12 = @SQLStatement3_12 OUT, @SQLStatement3_13 = @SQLStatement3_13 OUT, @SQLStatement3_14 = @SQLStatement3_14 OUT, @SQLStatement3_15 = @SQLStatement3_15 OUT
				SET @SQLStatementMember = @SQLStatement3_01 + @SQLStatement3_02 + @SQLStatement3_03 + @SQLStatement3_04 + @SQLStatement3_05 + @SQLStatement3_06 + @SQLStatement3_07 + @SQLStatement3_08 + @SQLStatement3_09 + @SQLStatement3_10 + @SQLStatement3_11 + @SQLStatement3_12 + @SQLStatement3_13 + @SQLStatement3_14 + @SQLStatement3_15

				IF @Debug <> 0 
					BEGIN 
						SELECT SourceID = @SourceID, DimensionID = 0, Dimension = @Dimension, SQLStatement = @SQLStatementMember
						PRINT '1'
						PRINT @SQLStatementMember
					END

				SET @SQLStatementMember = REPLACE(@SQLStatementMember, '''', '''''')
				IF @Debug <> 0 		
					BEGIN 
						SELECT SourceID = @SourceID, DimensionID = 0, Dimension = @Dimension, SQLStatement = @SQLStatementMember
						PRINT '2'
						PRINT @SQLStatementMember
					END


		--Add default members
--				IF @SQLStatementMember IS NOT NULL AND @SQLStatement <> ''
--					SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 'UNION ' + @SQLStatementMember

				IF @SQLStatementMember IS NOT NULL AND @SQLStatementMember <> '' AND @BaseQuerySQLStatement <> ''
					SET @BaseQuerySQLStatement = @BaseQuerySQLStatement + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 'UNION ' + @SQLStatementMember

--------------------------------------------------------------
				SET @Step = 'Determine ObjectName for sp'
					SET @spObjectName = 'spIU_' + @SourceID_varchar + '_' + @Dimension + '_Raw'

					SET @SQLStatement = N'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject N''' + @spObjectName + '''' + ', ' + '''P''' 
					INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
					SELECT @Action = [Action] FROM #Action

					IF @Debug <> 0 PRINT @SQLStatement
					IF @Debug <> 0 SELECT [Action] = @Action

				SET @SQLStatement = '
	SET @Step = ''''Create temp table #' + @Dimension + '_Members''''
		IF OBJECT_ID (N''''tempdb..#' + @Dimension + '_Members'''', N''''U'''') IS NULL
		BEGIN
			SET @CalledYN = 0

			CREATE TABLE [#' + @Dimension + '_Members]
				(
				[MemberId] bigint,
				[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
				[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
				[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
				[SBZ] bit,
				[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[Synchronized] bit,
				[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
				)
		END

	SET @Step = ''''Insert values into temp table #' +  @Dimension + '_Members''''
		INSERT INTO [#' +  @Dimension + '_Members]
			(
			[MemberId],
			[Label],
			[Description],
			[HelpText],
			[RNodeType],
			[SBZ],
			[Source],
			[Synchronized],
			[Parent]
			)
		SELECT TOP 1000000
			[MemberId] = MAX(sub.[MemberId]),
			[Label] = sub.Label COLLATE DATABASE_DEFAULT,
			[Description] = MAX(sub.[Description]) COLLATE DATABASE_DEFAULT,
			[HelpText] = MAX(sub.[HelpText]),
			[RNodeType] = MAX(sub.[RNodeType]),
			[SBZ] = [dbo].[f_GetSBZ] (0, MAX([sub].[RNodeType]), [sub].[Label]),
			[Source] = MAX(sub.[Source]) COLLATE DATABASE_DEFAULT,
			[Synchronized] = 1,
			[Parent] = MAX(sub.[Parent]) COLLATE DATABASE_DEFAULT
		FROM
			(' + @BaseQuerySQLStatement + '
			) sub
		GROUP BY
			sub.Label
		ORDER BY
			CASE WHEN [sub].[Label] IN (''''All_'''', ''''NONE'''') OR [sub].[Label] LIKE ''''%NONE%'''' THEN ''''  '''' + [sub].[Label] ELSE [sub].[Label] END

	SET @Step = ''''RETURN rows''''
		IF @CalledYN = 0
			BEGIN
				SELECT TempTable = ''''#' +  @Dimension + '_Members'''', * FROM #' +  @Dimension + '_Members ORDER BY Label
				SET @Selected = @@ROWCOUNT
			END

	SET @Step = ''''DROP the temp tables''''
		IF @CalledYN = 0 DROP TABLE #' +  @Dimension + '_Members
'
			
				SET @Step = 'Make Creation statement'
					SET @SQLStatement_spObjectName = @Action + ' PROCEDURE [dbo].' + @spObjectName
					SET @SQLStatement = @SQLStatement_spObjectName + @SQLStatement_spTemplateBegin + @SQLStatement + @SQLStatement_spTemplateEnd
					SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					
					IF @Debug <> 0
						BEGIN
							SELECT
								[Action] = @Action,
								[spObjectName] = @spObjectName,
								[SourceID] = @SourceID_varchar,
								[Dimension] = @Dimension,
								[SQLStatement_spObjectName] = @SQLStatement_spObjectName,
								[spTemplateBegin] = @SQLStatement_spTemplateBegin,
								[SQLStatement] = @SQLStatement,
								[SQLStatement_spTemplateEnd] = @SQLStatement_spTemplateEnd

							INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Create Segment SP', [SQLStatement] = @SQLStatement
						END

					EXEC (@SQLStatement)
---------------------------------------------------------------

				FETCH NEXT FROM Segment_DimensionName_Cursor INTO @Dimension
			  END

			CLOSE Segment_DimensionName_Cursor
			DEALLOCATE Segment_DimensionName_Cursor
		  END

		ELSE IF @SourceType IN ('EvryDW')

		  BEGIN

  			DECLARE EvryDW_FinanceDimension_Cursor CURSOR FOR

			SELECT DISTINCT DimensionName, Segment FROM #FinanceDimension

			OPEN EvryDW_FinanceDimension_Cursor
			FETCH NEXT FROM EvryDW_FinanceDimension_Cursor INTO @Dimension, @Segment

			WHILE @@FETCH_STATUS = 0
			  BEGIN
	  
			/*
				SET @ObjectName = 'vw_' + @SourceID_varchar + '_' + @Dimension
	  
				SET @SQLStatement = N'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ObjectName + '''' + ', ' + '''V''' 
				INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
				SELECT @Action = [Action] FROM #Action
			*/
				SET @Step = 'Determine ObjectName for sp'
					SET @spObjectName = 'spIU_' + @SourceID_varchar + '_' + @Dimension + '_Raw'

				SET @SQLStatement = N'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject N''' + @spObjectName + '''' + ', ' + '''P''' 
				INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
				SELECT @Action = [Action] FROM #Action

				IF @Debug <> 0 PRINT @SQLStatement
				IF @Debug <> 0 SELECT [Action] = @Action

				SET @SQLStatement = '
			SELECT
				[MemberId] = NULL,
				[Label] = [' + @Segment + 'Code],
				[Description] = [' + @Segment + 'Name],
				[HelpText] = '''''''',
				[Parent] = ''''All_''''
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[tblDim' + @Segment + ']
			WHERE
				[' + @Segment + 'Code] <> ''''#NA'''''
	  
			IF @Debug <> 0 PRINT @SQLStatement

			SET @Step = 'Get default members'
				EXEC spGet_Member @SourceID = @SourceID, @DimensionID = 0, @Dimension = @Dimension, @SQLStatement3_01 = @SQLStatement3_01 OUT, @SQLStatement3_02 = @SQLStatement3_02 OUT, @SQLStatement3_03 = @SQLStatement3_03 OUT, @SQLStatement3_04 = @SQLStatement3_04 OUT, @SQLStatement3_05 = @SQLStatement3_05 OUT, @SQLStatement3_06 = @SQLStatement3_06 OUT, @SQLStatement3_07 = @SQLStatement3_07 OUT, @SQLStatement3_08 = @SQLStatement3_08 OUT, @SQLStatement3_09 = @SQLStatement3_09 OUT, @SQLStatement3_10 = @SQLStatement3_10 OUT, @SQLStatement3_11 = @SQLStatement3_11 OUT, @SQLStatement3_12 = @SQLStatement3_12 OUT, @SQLStatement3_13 = @SQLStatement3_13 OUT, @SQLStatement3_14 = @SQLStatement3_14 OUT, @SQLStatement3_15 = @SQLStatement3_15 OUT
				SET @SQLStatementMember = @SQLStatement3_01 + @SQLStatement3_02 + @SQLStatement3_03 + @SQLStatement3_04 + @SQLStatement3_05 + @SQLStatement3_06 + @SQLStatement3_07 + @SQLStatement3_08 + @SQLStatement3_09 + @SQLStatement3_10 + @SQLStatement3_11 + @SQLStatement3_12 + @SQLStatement3_13 + @SQLStatement3_14 + @SQLStatement3_15

		--		EXEC spGet_Member @SourceID = @SourceID, @DimensionID = 0, @Dimension = @Dimension, @SQLStatement1 = @SQLStatement1Member OUT, @SQLStatement2 = @SQLStatement2Member OUT, @SQLStatement3 = @SQLStatement3Member OUT
		--		SET @SQLStatementMember = @SQLStatement1Member + @SQLStatement2Member + @SQLStatement3Member

				IF @Debug <> 0 
					BEGIN 
						SELECT SourceID = @SourceID, DimensionID = 0, Dimension = @Dimension, SQLStatement = @SQLStatementMember
						PRINT '1'
						PRINT @SQLStatementMember
					END

				SET @SQLStatementMember = REPLACE(@SQLStatementMember, '''', '''''')
				IF @Debug <> 0 		
					BEGIN 
						SELECT SourceID = @SourceID, DimensionID = 0, Dimension = @Dimension, SQLStatement = @SQLStatementMember
						PRINT '2'
						PRINT @SQLStatementMember
					END

			SET @Step = 'Add default members'
				IF @SQLStatementMember IS NOT NULL AND @SQLStatement <> ''
					SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + CHAR(9) + 'UNION ' + @SQLStatementMember

--------------------------------------------------------------
			SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''Create temp table #' + @Dimension + '_Members''''
		IF OBJECT_ID (N''''tempdb..#' + @Dimension + '_Members'''', N''''U'''') IS NULL
		BEGIN
			SET @CalledYN = 0

			CREATE TABLE [#' + @Dimension + '_Members]
				(
				[MemberId] bigint,
				[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
				[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
				[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
				[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
				[SBZ] bit,
				[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[Synchronized] bit,
				[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
				)
		END
	SET @Step = ''''Insert values into temp table #' +  @Dimension + '_Members''''
		INSERT INTO [#' +  @Dimension + '_Members]
			(
			[MemberId],
			[Label],
			[Description],
			[HelpText],
			[RNodeType],
			[SBZ],
			[Source],
			[Synchronized],
			[Parent]
			)		
		SELECT TOP 1000000 
			[MemberId] = MAX(sub.[MemberId]),
			[Label] = sub.[Label],
			[Description] = MAX(sub.[Description]),
			[HelpText] = '''''''',
			[RNodeType] = ''''L'''',
			[SBZ] = [dbo].[f_GetSBZ] (0, MAX([sub].[RNodeType]), [sub].[Label]),
			[Source] = ''''' + @SourceType + ''''',
			[Synchronized] = 1,
			[Parent] = MAX(sub.[Parent])
		FROM
			(' + CHAR(13) + CHAR(10) + @SQLStatement + '
			) sub
		GROUP BY
			Label
		ORDER BY
			Label

	SET @Step = ''''RETURN rows''''
		IF @CalledYN = 0
			BEGIN
				SELECT TempTable = ''''#' +  @Dimension + '_Members'''', * FROM #' +  @Dimension + '_Members ORDER BY Label
				SET @Selected = @@ROWCOUNT
			END

	SET @Step = ''''DROP the temp tables''''
		IF @CalledYN = 0 DROP TABLE #' +  @Dimension + '_Members
'
--------------------------------------------------------------			
				SET @Step = 'Make Creation statement'
					SET @SQLStatement_spObjectName = @Action + ' PROCEDURE [dbo].' + @spObjectName
					SET @SQLStatement = @SQLStatement_spObjectName + @SQLStatement_spTemplateBegin + @SQLStatement + @SQLStatement_spTemplateEnd
					SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					
					IF @Debug <> 0
						BEGIN
							SELECT
								[Action] = @Action,
								[spObjectName] = @spObjectName,
								[SourceID] = @SourceID_varchar,
								[Dimension] = @Dimension,
								[SQLStatement_spObjectName] = @SQLStatement_spObjectName,
								[spTemplateBegin] = @SQLStatement_spTemplateBegin,
								[SQLStatement] = @SQLStatement,
								[SQLStatement_spTemplateEnd] = @SQLStatement_spTemplateEnd

							INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Create Segment SP', [SQLStatement] = @SQLStatement
						END

					EXEC (@SQLStatement)
---------------------------------------------------------------

				FETCH NEXT FROM EvryDW_FinanceDimension_Cursor INTO @Dimension, @Segment
			  END

			CLOSE EvryDW_FinanceDimension_Cursor
			DEALLOCATE EvryDW_FinanceDimension_Cursor

		  END

	SET @Step = 'Drop Temp table'
		DROP TABLE #Action
		DROP TABLE #FinanceDimension

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
