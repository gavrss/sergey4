SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spExcelSet_Comment]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ApplicationName nvarchar(100) = NULL,
	@ModelName nvarchar(100) = NULL,
	@KeyValuePair xml = NULL,
	@Comment nvarchar(4000) = NULL,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@Rows int = NULL,
	@ProcedureID INT = 880000053,
	@Parameter NVARCHAR(4000) = NULL,
	@StartTime DATETIME = NULL,
	@Duration datetime = 0 OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--
AS
/*
	spExcelSet_Comment
		@UserID = -10,
		@InstanceID = 304,
		@VersionID = 1001,
		@ApplicationName = 'pcDATA_Christian_14',
		@ModelName = 'Financials',
		@KeyValuePair = '
		<root>
			<row TKey="Account" TValue="RR_EGEN_RÄKNING" />
			<row TKey="BusinessProcess" TValue="INPUT" />
			<row TKey="BusinessRule" TValue="NONE" />
			<row TKey="Currency" TValue="SEK" />
			<row TKey="Entity" TValue="01" />
			<row TKey="Scenario" TValue="ACTUAL" />
			<row TKey="Time" TValue="201802" />
			<row TKey="TimeDataView" TValue="RAWDATA" />
			<row TKey="Version" TValue="NONE" />
			<row TKey="GL_Kostnadställe" TValue="3102" />
			<row TKey="GL_Leverantörsgrupp" TValue="NONE" />
			<row TKey="GL_Objekt" TValue="NONE" />
			<row TKey="GL_Säljarnr" TValue="NONE" />
			<row TKey="GL_VAT" TValue="NONE" />
			<row TKey="ErrorTest" TValue="NONE" />
		</root>',
		@Comment = 'Comment which to store',
		@Debug = 1

	EXEC [spExcelSet_Comment] @GetVersion = 1
*/

DECLARE
	@TKey nvarchar(100), 
	@TValue nvarchar(100),
	@SQLStatement nvarchar(max),
	@SQLStatement_SELECT nvarchar(max),
	@SQLStatement_INSERT nvarchar(max),
	@SQLStatement_WHERE nvarchar(max),
	@NoOfRows int,
	@MissingDimension nvarchar(1000),
	@UserNameAD nvarchar(100),

	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'

		IF ISNULL((SELECT [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = OBJECT_NAME(@@PROCID) AND DeletedID IS NULL), 0) <> @ProcedureID
			BEGIN
				SET @ProcedureID = NULL
				SELECT @ProcedureID = [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = OBJECT_NAME(@@PROCID) AND DeletedID IS NULL
				IF @ProcedureID IS NULL
					BEGIN
						EXEC spInsert_Procedure
						SET @Message = 'SP ' + OBJECT_NAME(@@PROCID) + ' was not registered. It is now registered by SP spInsert_Procedure. Rerun the command to get correct ProcedureID.'
					END
				ELSE
					SET @Message = 'ProcedureID mismatch, should be ' + CONVERT(nvarchar(10), @ProcedureID)
				SET @Severity = 16
				GOTO EXITPOINT
			END
		SELECT [Version] = @Version, [Description] = @Description, [ProcedureID] = @ProcedureID
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		EXEC [spGet_User] @UserID = @UserID, @UserNameAD = @UserNameAD OUT

		IF @Debug <> 0 SELECT UserNameAD = @UserNameAD

	SET @Step = 'Create and fill temp table'
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

	SET @Step = 'Fill temp table'
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

	SET @Step = 'Update temp table'
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
			FieldName NVARCHAR(100)
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

		SELECT @NoOfRows = COUNT(1) FROM #TableCheck

		IF @NoOfRows > (SELECT COUNT(1) FROM #KeyValuePair kv INNER JOIN #TableCheck tc ON tc.FieldName = kv.TKey + '_MemberId' AND MemberId IS NOT NULL)
			BEGIN
				SELECT
					@MissingDimension = ISNULL(@MissingDimension, '') + REPLACE(TC.FieldName, '_MemberId', '') + ', '
				FROM
					#TableCheck TC
				WHERE
					NOT EXISTS (SELECT 1 FROM #KeyValuePair KV WHERE KV.TKey + '_MemberId' = TC.FieldName)

				SET @MissingDimension = LEFT(@MissingDimension, LEN(@MissingDimension) - 1)

				SET @Message = 'Dimension(s) ' + @MissingDimension + ' is missing in the parameter @KeyValuePair.'
				SET @Severity = 16
				GOTO EXITPOINT
			END
		ELSE
			BEGIN
				DELETE KV
				FROM
					#KeyValuePair kv
				WHERE
					NOT EXISTS (SELECT 1 FROM #TableCheck TC WHERE TC.FieldName = KV.TKey + '_MemberId')
			END


	SET @Step = 'Create SQL statements'
		SELECT
			@SQLStatement_WHERE = ISNULL(@SQLStatement_WHERE, '') + CHAR(13) + CHAR(10) + CHAR(9) + '[' + TKey + '_MemberId] = ' + CONVERT(nvarchar(10), MemberId) + ',',
			@SQLStatement_INSERT = ISNULL(@SQLStatement_INSERT, '') + CHAR(13) + CHAR(10) + CHAR(9) + '[' + TKey + '_MemberId],'
		FROM
			#KeyValuePair
		ORDER BY
			TKey

		SELECT
			@SQLStatement_SELECT = @SQLStatement_WHERE + 
									CHAR(13) + CHAR(10) + CHAR(9) + '[ChangeDatetime] = GETDATE(),' +
									CHAR(13) + CHAR(10) + CHAR(9) + '[Userid] = suser_name(),' +
									CHAR(13) + CHAR(10) + CHAR(9) + '[' + @ModelName + '_Text] = ''' + @Comment + '''',
			@SQLStatement_INSERT = @SQLStatement_INSERT + 
									CHAR(13) + CHAR(10) + CHAR(9) + '[ChangeDatetime],' +
									CHAR(13) + CHAR(10) + CHAR(9) + '[Userid],' +
									CHAR(13) + CHAR(10) + CHAR(9) + '[' + @ModelName + '_Text]',
			@SQLStatement_WHERE = REPLACE(LEFT(@SQLStatement_WHERE, LEN(@SQLStatement_WHERE) -1), ',', ' AND')

		IF @Debug <> 0
			BEGIN
				PRINT @SQLStatement_INSERT
				PRINT @SQLStatement_SELECT
				PRINT @SQLStatement_WHERE
			END

	SET @Step = 'Update FACT table'
		SET @SQLStatement = '
UPDATE ' + @ApplicationName + '..FACT_' + @ModelName + '_text
SET' + @SQLStatement_SELECT + '
WHERE' + @SQLStatement_WHERE

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Updated = @Updated + @@ROWCOUNT
		
		IF @Updated > 0
			SET @Message = 'The comment is updated.' 

		SET @Severity = 0

	SET @Step = 'Insert into FACT table'
		IF @Updated = 0
			BEGIN
				SET @SQLStatement = '
INSERT INTO ' + @ApplicationName + '..FACT_' + @ModelName + '_text
	(' + @SQLStatement_INSERT + '
	)
SELECT' + @SQLStatement_SELECT + '
WHERE
	NOT EXISTS (SELECT 1 FROM ' + @ApplicationName + '..FACT_' + @ModelName + '_text WHERE ' + @SQLStatement_WHERE + ')'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT

				IF @Inserted > 0
					SET @Message = 'The new comment is added.' 

				SET @Severity = 0
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #KeyValuePair
		DROP TABLE #TableCheck
		DROP TABLE #Dims

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version, @Parameter, @UserName, @UserID, @InstanceID, @VersionID
				
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version, @Parameter, @UserName, @UserID, @InstanceID, @VersionID
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
