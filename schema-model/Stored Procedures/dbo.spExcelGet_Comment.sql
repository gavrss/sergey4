SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spExcelGet_Comment]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ApplicationName nvarchar(100) = NULL,
	@ModelName nvarchar(100) = NULL,

	@KeyValuePair xml = NULL,

	@JobID int = 0,
	@Debug bit = 0,
	@Duration datetime = 0 OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@GetVersion bit = 0
AS
/*
spExcelGet_Comment
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@ApplicationName = 'pcDATA_Christian_14',
	@ModelName = 'Financials',
	@KeyValuePair = '
	<root>
		<row TKey="BusinessProcess" TValue="INPUT" />
		<row TKey="BusinessRule" TValue="NONE" />
		<row TKey="Currency" TValue="SEK" />
		<row TKey="Entity" TValue="01" />
		<row TKey="Scenario" TValue="ACTUAL" />
		<row TKey="TimeDataView" TValue="RAWDATA" />
		<row TKey="Version" TValue="NONE" />
		<row TKey="GL_Kostnadställe" TValue="3102" />
		<row TKey="GL_Leverantörsgrupp" TValue="NONE" />
		<row TKey="GL_Objekt" TValue="NONE" />
		<row TKey="GL_Säljarnr" TValue="NONE" />
		<row TKey="GL_VAT" TValue="NONE" />
		<row TKey="ErrorTest" TValue="NONE" />
	</root>',
	@Debug = 1

spExcelGet_Comment
  @UserID = 2129,
  @InstanceID = 404,
  @VersionID = 1003,
  @ApplicationName = 'pcDATA_Salinity2',
  @ModelName = 'Financials',
  @KeyValuePair = '
  <root>
  <row TKey="BusinessProcess" TValue="INPUT" />
  <row TKey="BusinessRule" TValue="NONE" />
  <row TKey="Currency" TValue="SEK" />
  <row TKey="Entity" TValue="000-7" />
  <row TKey="GL_Extra" TValue="13" />
  <row TKey="GL_Kostnadsställe" TValue="All_" />
  <row TKey="GL_Projekt" TValue="All_" />
  <row TKey="LineItem" TValue="NONE" />
  <row TKey="Financials_Measures" TValue="Financials_Value" />
  <row TKey="Scenario" TValue="BUDGET" />
  <row TKey="TimeDataView" TValue="PERIODIC" />
  <row TKey="Version" TValue="NONE" />
</root>',
  @Debug = 1
*/

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@Parameter nvarchar(4000),
	@UserName nvarchar(100),
	@TKey nvarchar(100), 
	@TValue nvarchar(100),
	@SQLStatement nvarchar(max),
	@SQLStatement_SELECT nvarchar(max),
	@SQLStatement_FROM nvarchar(max),
	@SQLStatement_WHERE nvarchar(max),
	@NoOfRows int,
	@CounterSum int,
	@CounterSum_Max int,
	@DimName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserID IS NULL OR @InstanceID IS NULL OR @VersionID IS NULL OR @ApplicationName IS NULL OR @ModelName IS NULL OR @KeyValuePair IS NULL
	BEGIN
		SET @Message = 'Parameter @UserID, @InstanceID, @VersionID, @ApplicationName, @ModelName and @KeyValuePair must be set'
		SET @Severity = 16
		GOTO EXITPOINT
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SET @UserName = suser_name()

		IF @JobID = 0
			SET @JobID = 10000000 + @InstanceID * 1000 + 501

		SET @Parameter = 
			'EXEC [spExcelGet_Comment] ' +
			'@UserID = ' + ISNULL(CONVERT(nvarchar(10), @UserID), 'NULL') + ', ' +
			'@InstanceID = ' + ISNULL(CONVERT(nvarchar(10), @InstanceID), 'NULL') + ', ' +
			'@VersionID = ' + ISNULL(CONVERT(nvarchar(10), @VersionID), 'NULL') + ', ' +
			CASE WHEN @ApplicationName IS NOT NULL THEN '@ApplicationName = ''' + @ApplicationName + ''', ' ELSE 'NULL' END +
			CASE WHEN @ModelName IS NOT NULL THEN '@ModelName = ''' + @ModelName + ''', ' ELSE 'NULL' END +
			'@KeyValuePair = ''' + ISNULL(CONVERT(nvarchar(2000), @KeyValuePair), 'NULL') + ''', '
			
		SET @Parameter = LEFT(@Parameter, LEN(@Parameter) - 1)

	SET @Step = 'Create temp tables'
		CREATE TABLE #Select
			(
			[CounterSum] INT IDENTITY(1, 1),
			[FieldName] nvarchar(100)
			)

		CREATE TABLE #KeyValuePair
			(
			[TKey] nvarchar(100) PRIMARY KEY, 
			[TValue] nvarchar(100),
			[MemberId] bigint
			)

		CREATE TABLE #Dims
			(
			DimensionName NVARCHAR(100)
			)

	SET @Step = 'Fill temp table #Dims'
		SET @SQLStatement = '
		INSERT INTO #Dims
			(
			DimensionName
			)
		SELECT 
			DimensionName = REPLACE([name], ''S_DS_'', '''')
		FROM
			' + @ApplicationName + '.sys.tables
		WHERE
			[name] LIKE ''S_DS_%'''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Fill and Update temp table #KeyValuePair'
		INSERT INTO #KeyValuePair
			(
			[TKey], 
			[TValue]
			)
		SELECT 
			[TKey] = r.v.value('@TKey[1]', 'nvarchar(100)'),
			[TValue] = r.v.value('@TValue[1]', 'nvarchar(100)')
		FROM
			@KeyValuePair.nodes('root/row') r(v)

		DELETE KVP
		FROM
			#KeyValuePair KVP
		WHERE
			NOT EXISTS (SELECT 1 FROM #Dims D WHERE D.DimensionName = KVP.TKey)

		IF @Debug <> 0
			SELECT
				[TKey],
				[TValue],
				[MemberId]
			FROM
				#KeyValuePair

		UPDATE #KeyValuePair
		SET
			[MemberId] = -1
		WHERE
			[TValue] = 'NONE'

		DECLARE Comment_MemberId_Cursor CURSOR FOR

			SELECT
				[TKey],
				[TValue]
			FROM
				#KeyValuePair
			WHERE
				MemberId IS NULL

			OPEN Comment_MemberId_Cursor
			FETCH NEXT FROM Comment_MemberId_Cursor INTO @TKey, @TValue

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT TKey = @TKey, TValue = @TValue

					SET @SQLStatement = '
						UPDATE KV
						SET
							MemberId = D.MemberId
						FROM
							#KeyValuePair KV
							INNER JOIN ' + @ApplicationName + '..S_DS_' + @TKey + ' D ON D.Label = ''' + @TValue + '''
						WHERE
							KV.TKey = ''' + @TKey + ''''

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM Comment_MemberId_Cursor INTO  @TKey, @TValue
				END

		CLOSE Comment_MemberId_Cursor
		DEALLOCATE Comment_MemberId_Cursor	

		UPDATE KV
		SET
			MemberId = -1
		FROM
			#KeyValuePair KV
		WHERE
			MemberId IS NULL

		IF @Debug <> 0
			SELECT
				[TKey],
				[TValue],
				[MemberId]
			FROM
				#KeyValuePair

	SET @Step = 'Verify parameter @KeyValuePair matching FACT table'
		CREATE TABLE #TableCheck
			(
			[FieldName] NVARCHAR(100)
			)

		SET @SQLStatement = '
		INSERT INTO #TableCheck
			(
			FieldName
			)
		SELECT 
			FieldName = c.name 
		FROM
			' + @ApplicationName + '.sys.tables t
			INNER JOIN ' + @ApplicationName + '.sys.columns c ON c.object_id = t.object_id AND c.name LIKE ''%_MemberId''
		WHERE
			t.name = ''FACT_' + @ModelName + '_text'''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		DELETE KV
		FROM
			#KeyValuePair kv
		WHERE
			NOT EXISTS (SELECT 1 FROM #TableCheck TC WHERE TC.FieldName = KV.TKey + '_MemberId')

	SET @Step = 'Create SQL statements'
		SELECT @NoOfRows = COUNT(1) FROM #TableCheck

		IF @NoOfRows - (SELECT COUNT(1) FROM #KeyValuePair kv INNER JOIN #TableCheck tc ON tc.FieldName = kv.TKey + '_MemberId' AND MemberId IS NOT NULL) = 2
			BEGIN
				SELECT
					@SQLStatement_WHERE = ISNULL(@SQLStatement_WHERE, '') + CHAR(13) + CHAR(10) + CHAR(9) + 'F.[' + TKey + '_MemberId] = ' + CONVERT(nvarchar(10), MemberId) + ' AND'
				FROM
					#KeyValuePair
				ORDER BY
					TKey

				SET @SQLStatement_WHERE = LEFT(@SQLStatement_WHERE, LEN(@SQLStatement_WHERE) - 4)

				INSERT INTO #Select
					(
					[FieldName]
					)
				SELECT
					TC.FieldName
				FROM
					#TableCheck TC
				WHERE
					NOT EXISTS (SELECT 1 FROM #KeyValuePair KV WHERE  KV.TKey + '_MemberId' = TC.FieldName)

				IF @Debug <> 0 SELECT TempTable = '#Select', * FROM #Select

				SELECT
					@SQLStatement_SELECT = ISNULL(@SQLStatement_SELECT, '') + CHAR(13) + CHAR(10) + CHAR(9) + 'Dim' + CONVERT(NVARCHAR(10), S.CounterSum) + ' = ''' + REPLACE(S.FieldName, '_MemberId', '') + ''',' + CHAR(13) + CHAR(10) + CHAR(9) + 'Dim' + CONVERT(NVARCHAR(10), S.CounterSum) + '_MemberKey = ' + REPLACE(S.FieldName, '_MemberId', '') + '.[Label],',
					@SQLStatement_FROM = ISNULL(@SQLStatement_FROM, '') + CHAR(13) + CHAR(10) + CHAR(9) + 'INNER JOIN ' + @ApplicationName + '..S_DS_' + REPLACE(S.FieldName, '_MemberId', '') + ' ' + REPLACE(S.FieldName, '_MemberId', '') + ' ON ' + REPLACE(S.FieldName, '_MemberId', '') + '.MemberId = F.[' + S.FieldName + ']'
				FROM
					#Select S

				SELECT
					@SQLStatement_SELECT = @SQLStatement_SELECT + CHAR(13) + CHAR(10) + CHAR(9) + '[' + @ModelName + '_Text] = [' + @ModelName + '_Text]'

				SET @SQLStatement = '
							SELECT
								' + @SQLStatement_SELECT + '
							FROM
								' + @ApplicationName + '..FACT_' + @ModelName + '_text F' + @SQLStatement_FROM + '
							WHERE ' + @SQLStatement_WHERE
								
				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END
		ELSE
			BEGIN
				SET @Message = 'The number of correct parameters does not match the selected FACT table.' 
				SET @Severity = 16
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #KeyValuePair
		DROP TABLE #TableCheck
		DROP TABLE #Select
		DROP TABLE #Dims

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

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
