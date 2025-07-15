SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Fact_pcEXCHANGE] 

	@SourceID int = NULL,
	@JobID int = 0,
	@SpeedRunYN bit = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--

AS

--EXEC spCreate_Fact_pcEXCHANGE @SourceID = 400, @Debug = true
--EXEC spCreate_Fact_pcEXCHANGE @SourceID = 647, @Debug = true

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@Action nvarchar(10),
	@SourceDatabase nvarchar(255),
	@ETLDatabase nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@SourceID_varchar nvarchar(10),
	@ObjectName nvarchar(50),
	@Description nvarchar(255),
	@ProcedureName nvarchar(100),
	@InstanceID int,
	@ApplicationID int,
	@DimensionID int,
	@SourceTypeID int,
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2070' SET @Description = 'Procedure introduced.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2107' SET @Description = 'Check on Licensed models'
		IF @Version = '1.3.2110' SET @Description = 'Add default values for missing dimensions.'
		IF @Version = '1.3.0.2118' SET @Description = 'Changed currency handling.'
		IF @Version = '1.3.1.2120' SET @Description = 'Fixed metadata bug when segments has same name as ordinary dimensions.'
		IF @Version = '1.4.0.2139' SET @Description = 'Filling #DimensionName with join on MappedObjectName instead of ObjectName.'

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

		SET @SourceID_varchar = CASE WHEN @SourceID <= 9 THEN '000' ELSE CASE WHEN @SourceID <= 99 THEN '00' ELSE CASE WHEN @SourceID <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, @SourceID)

		SELECT
			@InstanceID = A.InstanceID,
			@ApplicationID = A.ApplicationID,
			@SourceTypeID = S.SourceTypeID,
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = A.ETLDatabase,
			@DestinationDatabase = A.DestinationDatabase
		FROM
			Source S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
			INNER JOIN Model M ON M.ModelID = S.ModelID
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
		WHERE
			SourceID = @SourceID

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		IF @SourceTypeID = 6
			SET @SourceID_varchar = '6000'
		ELSE
			RETURN

	SET @Step = 'SET @ObjectName'
		SET @ObjectName = 'spIU_' + @SourceID_varchar + '_FACT'

	SET @Step = 'CREATE TABLE #Action'
		CREATE TABLE #Action
		(
		[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
		)

		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ObjectName + '''' + ', ' + '''P''' 
		INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
		SELECT @Action = [Action] FROM #Action


  BEGIN
		SET @SQLStatement = @Action + ' PROCEDURE [dbo].[' + @ObjectName + '] 
	@JobID int = 0,
	@ApplicationID int = ' + CONVERT(nvarchar(10), @ApplicationID) + ',
	@SourceID int = ' + @SourceID_varchar + ',
	@SpeedRunYN bit = ' + CONVERT(nvarchar(10), @SpeedRunYN) + ',
	@ETLDatabase nvarchar(100) = ''''' + @ETLDatabase + ''''',
	@DestinationDatabase nvarchar(100) = ''''' + @DestinationDatabase + ''''',
	@Rows int = NULL,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

--EXEC [spIU_6000_FACT] @Debug = 1

AS

SET NOCOUNT ON

DECLARE
	@StartTime datetime,
	@StartTime_Step datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Dimension nvarchar(100),
	@SQLInsert nvarchar(max),
	@SQLSelect nvarchar(max),
	@SQLJoin nvarchar(max),
	@SQLDeleteSelect nvarchar(max),
	@SQLDeleteJoin nvarchar(max),
	@SQLDeleteFactJoin nvarchar(max),
	@SQLStatement nvarchar(max),
	@ModelName_Org nvarchar(100),
	@ModelName nvarchar(100),
	@SourceDatabase nvarchar(100),
	@BusinessRule nvarchar(50),
	@Deleted_Step int = 0,
    @Inserted_Step int = 0,
    @Updated_Step int = 0,
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
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

        SET DATEFIRST 1'

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create temp tables''''
		CREATE TABLE #FactTable_Cursor (MappedObjectName nvarchar(100) COLLATE DATABASE_DEFAULT, ModelName nvarchar(100) COLLATE DATABASE_DEFAULT, SortOrder int)
		CREATE TABLE #DimensionName (DimensionID int, MappedObjectName nvarchar(100) COLLATE DATABASE_DEFAULT, DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT, DefaultValue nvarchar(100) COLLATE DATABASE_DEFAULT, DeleteJoinYN bit)
		CREATE TABLE #FACT_Update ([BusinessProcess_MemberId] bigint, [Entity_MemberId] bigint, [Scenario_MemberId] bigint, [Time_MemberId] bigint)

	SET @Step = ''''Create SourceDatabase cursor''''
		SELECT DISTINCT
			S.SourceDatabase
		INTO
			#SourceDatabase_Cursor
		FROM
			pcINTEGRATOR..[Source] S
			INNER JOIN pcINTEGRATOR..[Model] M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
			INNER JOIN pcINTEGRATOR..[Application] A ON A.ApplicationID = M.ApplicationID AND A.ApplicationID = @ApplicationID AND A.SelectYN <> 0
		WHERE
			S.SourceTypeID = 6 AND
			S.SelectYN <> 0

		IF @Debug <> 0 SELECT TempTable = ''''#SourceDatabase_Cursor'''', * FROM #SourceDatabase_Cursor

		DECLARE SourceDatabase_Cursor CURSOR FOR

		SELECT 
			SourceDatabase
		FROM
			#SourceDatabase_Cursor
		ORDER BY
			SourceDatabase

		OPEN SourceDatabase_Cursor
		FETCH NEXT FROM SourceDatabase_Cursor INTO @SourceDatabase

		WHILE @@FETCH_STATUS = 0
			BEGIN'

	SET @SQLStatement = @SQLStatement + '

				SET @Step = ''''Cursor on Fact tables''''
					SET @SQLStatement = ''''
					INSERT INTO #FactTable_Cursor
						(
						MappedObjectName,
						ModelName,
						SortOrder
						)
					SELECT
						MO.MappedObjectName,
						M.ModelName,
						SortOrder = CASE WHEN M.[BaseModelID] = -3 THEN 10 ELSE 20 END
					FROM
						'''' + @SourceDatabase + ''''.[dbo].[Model] M
						INNER JOIN '''' + @ETLDatabase + ''''.[dbo].[MappedObject] MO ON MO.ObjectName = M.ModelName AND MO.ObjectTypeBM & 1 > 0 AND MO.SelectYN <> 0
						INNER JOIN '''' + @DestinationDatabase + ''''.sys.tables t ON t.[name] = ''''''''FACT_'''''''' + M.ModelName + ''''''''_default_partition''''''''
					WHERE
						M.SelectYN <> 0''''

					EXEC (@SQLStatement)
					IF @Debug <> 0 SELECT TempTable = ''''#FactTable_Cursor'''', * FROM #FactTable_Cursor

					DECLARE pcEXCHANGE_FACT_Cursor CURSOR FOR

					SELECT
						ModelName = MappedObjectName,
						ModelName_Org = ModelName
					FROM
						#FactTable_Cursor
					ORDER BY
						SortOrder,
						MappedObjectName

					OPEN pcEXCHANGE_FACT_Cursor

					FETCH NEXT FROM pcEXCHANGE_FACT_Cursor INTO @ModelName, @ModelName_Org

					WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @Step = ''''Set @StartTime_Step''''
								SET @StartTime_Step = GETDATE()

							SET @Step = ''''Create List of dimensions''''
								SELECT @SQLInsert = '''''''', @SQLSelect = '''''''', @SQLJoin = '''''''',  @SQLDeleteSelect = '''''''', @SQLDeleteJoin = '''''''', @SQLDeleteFactJoin = ''''''''

								TRUNCATE TABLE #DimensionName

								SET @SQLStatement = ''''
								INSERT INTO #DimensionName
									(
									[DimensionID],
									[MappedObjectName],
									[DimensionName],
									[DefaultValue],
									[DeleteJoinYN]
									)
								SELECT
									[DimensionID] = D.[DimensionID],
									[MappedObjectName] = [MOD].[MappedObjectName],
									[DimensionName] = MAX(MD.[DimensionName]),
									[DefaultValue] = MAX(ISNULL(D.[DefaultValue], ''''''''NONE'''''''')),
									[DeleteJoinYN] = MAX(CONVERT(int, D.[DeleteJoinYN]))
								FROM
									'''' + @ETLDatabase + ''''..MappedObject [MOM]  
									INNER JOIN '''' + @ETLDatabase + ''''..MappedObject [MOD] ON [MOD].ObjectTypeBM & 2 > 0 AND [MOD].SelectYN <> 0
									INNER JOIN pcINTEGRATOR..Dimension D ON (D.DimensionName = [MOD].ObjectName AND D.DimensionTypeID = [MOD].DimensionTypeID AND D.SelectYN <> 0) OR (D.DimensionID = 0 AND MOD.DimensionTypeID = -1)
									INNER JOIN '''' + @DestinationDatabase + ''''.sys.tables t ON t.name = ''''''''FACT_'''''''' + [MOM].MappedObjectName + ''''''''_default_partition''''''''
									INNER JOIN '''' + @DestinationDatabase + ''''.sys.columns c ON c.object_id = t.object_id AND c.name = [MOD].MappedObjectName + ''''''''_MemberId''''''''
									LEFT JOIN '''' + @SourceDatabase + ''''.[dbo].[ModelDimension] MD ON MD.ModelName = [MOM].ObjectName AND MD.DimensionName = [MOD].MappedObjectName
								WHERE
									[MOM].ObjectName = '''''''''''' + @ModelName_Org + '''''''''''' AND
									[MOM].ObjectTypeBM & 1 > 0 AND
									[MOM].SelectYN <> 0
								GROUP BY
									D.[DimensionID],
									[MOD].[MappedObjectName]'''''

	SET @SQLStatement = @SQLStatement + '

								EXEC (@SQLStatement)
								IF @Debug <> 0 SELECT TempTable = ''''#DimensionName'''', * FROM #DimensionName

							SET @Step = ''''Create #FACT_Update''''
								SELECT
									@SQLDeleteSelect = @SQLDeleteSelect + CASE WHEN DeleteJoinYN <> 0 THEN SQLSelect + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) ELSE '''''''' END,
									@SQLDeleteJoin = @SQLDeleteJoin + CASE WHEN SQLJoinYN <> 0 THEN ''''LEFT JOIN '''' + @DestinationDatabase + ''''.[dbo].[S_DS_'''' + DN.MappedObjectName + ''''] ['''' + DN.MappedObjectName + ''''] ON ['''' + DN.MappedObjectName + ''''].Label COLLATE DATABASE_DEFAULT = '''' + CASE WHEN DN.[DimensionName] IS NULL THEN '''''''''''''''' + DN.DefaultValue + '''''''''''''''' ELSE ''''[Raw].['''' + DN.[DimensionName] + '''']'''' END ELSE '''''''' END + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9),
									@SQLDeleteFactJoin = @SQLDeleteFactJoin + CASE WHEN DeleteJoinYN = 0 OR (SQLJoinYN = 0 AND DimensionID <> -7) THEN '''''''' ELSE ''''V.['''' + DN.MappedObjectName + ''''_MemberId] = '''' + CASE WHEN DimensionID = -7 AND SQLJoinYN = 0 THEN ''''F.[TimeDay_MemberId] / 100 AND'''' ELSE ''''F.['''' + DN.MappedObjectName + ''''_MemberId] AND'''' END + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) END
								FROM
									(
									SELECT
										DimensionID,
										MappedObjectName,
										DimensionName,
										SQLSelect = ''''['''' + MappedObjectName + ''''_MemberId] = ISNULL(['''' + MappedObjectName + ''''].[MemberId], -1),'''',
										DefaultValue,
										DeleteJoinYN,
										SQLJoinYN = 1
									FROM
										#DimensionName
									WHERE
										DeleteJoinYN <> 0 OR
										DimensionID = -49

									UNION SELECT
										DimensionID = -7,
										MappedObjectName = ''''Time'''',
										DimensionName = ''''Time'''',
										SQLSelect = ''''[Time_MemberId] = ISNULL([TimeDay].[MemberId] / 100, -1),'''',
										DefaultValue = ''''NONE'''',
										DeleteJoinYN = 1,
										SQLJoinYN = 0
									WHERE
										NOT EXISTS (SELECT 1 FROM #DimensionName WHERE DimensionID = -7) AND
										EXISTS (SELECT 1 FROM #DimensionName WHERE DimensionID = -49)

									UNION SELECT
										DimensionID = -2,
										MappedObjectName = ''''BusinessProcess'''',
										DimensionName = ''''BusinessProcess'''',
										SQLSelect = ''''[BusinessProcess_MemberId] = 0,'''',
										DefaultValue = ''''NONE'''',
										DeleteJoinYN = 1,
										SQLJoinYN = 0
									WHERE
										NOT EXISTS (SELECT 1 FROM #DimensionName WHERE DimensionID IN (-2)) 
									) DN
								ORDER BY
									DN.MappedObjectName'

	SET @SQLStatement = @SQLStatement + '

								SELECT
									@SQLDeleteSelect = SUBSTRING(@SQLDeleteSelect, 1, LEN(@SQLDeleteSelect) - 17),
									@SQLDeleteJoin = SUBSTRING(@SQLDeleteJoin, 1, LEN(@SQLDeleteJoin) - 1),
									@SQLDeleteFactJoin = SUBSTRING(@SQLDeleteFactJoin, 1, LEN(@SQLDeleteFactJoin) - 17)

								TRUNCATE TABLE #FACT_Update
																
								SET @SQLStatement = ''''
									INSERT INTO #FACT_Update
										(
										[BusinessProcess_MemberId],
										[Entity_MemberId],
										[Scenario_MemberId],
										[Time_MemberId]
										)
									SELECT DISTINCT
										'''' + @SQLDeleteSelect + ''''
									FROM
										'''' + @SourceDatabase + ''''.[dbo].[FactData_'''' + @ModelName_Org + ''''] [Raw]
										'''' + @SQLDeleteJoin
								
								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

							SET @Step = ''''Set all existing rows that should be inserted to 0''''
								SET @SQLStatement = ''''
									UPDATE
										F
									SET
										['''' + @ModelName + ''''_Value] = 0
									FROM
										'''' + @DestinationDatabase + ''''.[dbo].[FACT_'''' + @ModelName + ''''_default_partition] F
										INNER JOIN #FACT_Update V ON
											'''' + @SQLDeleteFactJoin

								IF @Debug <> 0 PRINT @SQLStatement

								EXEC (@SQLStatement)

								SET @Updated_Step = @@ROWCOUNT'

	SET @SQLStatement = @SQLStatement + '

							SET @Step = ''''Insert rows into FACT table''''
								SELECT
									@SQLInsert = @SQLInsert + ''''['''' + DN.MappedObjectName + ''''_MemberId],'''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9),
									@SQLSelect = @SQLSelect + ''''['''' + DN.MappedObjectName + ''''_MemberId] = ISNULL(['''' + DN.MappedObjectName + ''''].[MemberId], -1),'''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9),
									@SQLJoin = @SQLJoin + ''''LEFT JOIN '''' + @DestinationDatabase + ''''.[dbo].[S_DS_'''' + DN.MappedObjectName + ''''] ['''' + DN.MappedObjectName + ''''] ON ['''' + DN.MappedObjectName + ''''].Label COLLATE DATABASE_DEFAULT = '''' + CASE WHEN DN.[DimensionName] IS NULL THEN '''''''''''''''' + DN.DefaultValue + '''''''''''''''' ELSE ''''[Raw].['''' + DN.[DimensionName] + '''']'''' END + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
								FROM
									#DimensionName DN
								ORDER BY
									DN.MappedObjectName

								SET @SQLStatement = ''''
									INSERT INTO '''' + @DestinationDatabase + ''''.[dbo].[FACT_'''' + @ModelName + ''''_default_partition]
										(
										'''' + @SQLInsert + 
										''''[ChangeDatetime],
										[Userid],
										['''' + @ModelName + ''''_Value]
										)
									SELECT
										'''' + @SQLSelect + 
										''''[ChangeDatetime] = GetDate(),
										[Userid] = ''''''''' + REPLACE(REPLACE(@SourceDatabase, '[', '('), ']', ')') + ' '''''''' + [Raw].[UserId],
										['''' + @ModelName + ''''_Value] = [Raw].['''' + @ModelName_Org + ''''_Value]
									FROM
										'''' + @SourceDatabase + ''''.[dbo].[FactData_'''' + @ModelName_Org + ''''] [Raw]
										'''' + @SQLJoin

									SET @SQLStatement = REPLACE(@SQLStatement, ''''@BusinessRule'''', ISNULL(@BusinessRule, ''''''''))

									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
		
									SET @Inserted_Step = @@ROWCOUNT

							SET @Step = ''''Add Currency conversion''''
								IF @ModelName_Org <> ''''FxRate''''
									BEGIN
										CREATE TABLE #Count ([Counter] int)
										SET @SQLStatement = ''''INSERT INTO #Count ([Counter]) SELECT [Counter] = COUNT(1) FROM '''' + @DestinationDatabase + ''''.[dbo].[S_DS_Currency] WHERE [Reporting] <> 0''''
										EXEC (@SQLStatement)

										IF (SELECT [Counter] FROM #Count) > 0
											EXEC spIU_0000_FACT_FxTrans @JobID = @JobID, @ModelName = @ModelName, @BPType = ''''ETL'''', @Debug = @Debug

										DROP TABLE #Count
									END

							SET @Step = ''''Clean up''''
								IF (SELECT DATEPART(WEEKDAY, GETDATE())) IN (6, 7) OR @SpeedRunYN = 0 --Saturday, Sunday or not SpeedRun
									BEGIN
										SET @SQLStatement = ''''
										DELETE
											f
										FROM
											['''' + @DestinationDatabase + ''''].[dbo].[FACT_'''' + @ModelName + ''''_default_partition] F
										WHERE
											['''' + @ModelName + ''''_Value] = 0''''

										IF @Debug <> 0 PRINT @SQLStatement
										EXEC (@SQLStatement)

										SET @Deleted_Step = @@ROWCOUNT
									END

							SET @Step = ''''Set @Duration''''	
								SET @Duration = GetDate() - @StartTime_Step'

	SET @SQLStatement = @SQLStatement + '

							SET @Step = ''''Insert into JobLog''''
								INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime_Step, OBJECT_NAME(@@PROCID) + '''' ('''' + @ModelName + '''')'''', @Duration, @Deleted_Step, @Inserted_Step, @Updated_Step, @Version

							SET @Step = ''''Set procedure Counters''''
								SET @Updated = @Updated + @Updated_Step
								SET @Deleted = @Deleted + @Deleted_Step
								SET @Inserted = @Inserted + @Inserted_Step

							FETCH NEXT FROM pcEXCHANGE_FACT_Cursor INTO @ModelName, @ModelName_Org
						END

					CLOSE pcEXCHANGE_FACT_Cursor
					DEALLOCATE pcEXCHANGE_FACT_Cursor

					FETCH NEXT FROM SourceDatabase_Cursor INTO @SourceDatabase
				END

		CLOSE SourceDatabase_Cursor
		DEALLOCATE SourceDatabase_Cursor

	SET @Step = ''''Drop temp tables''''
		DROP TABLE #FactTable_Cursor
		DROP TABLE #DimensionName

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
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

  END

  	SET @Step = 'Create pcEXCHANGE FACT Procedure'
		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Create pcEXCHANGE FACT Procedure', [SQLStatement] = @SQLStatement
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
