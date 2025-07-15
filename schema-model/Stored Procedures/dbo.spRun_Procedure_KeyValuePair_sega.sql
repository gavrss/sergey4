SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spRun_Procedure_KeyValuePair_sega]

@ProcedureName nvarchar(100) = NULL, --Mandatory
@JSON nvarchar(MAX) = NULL,
@XML xml = NULL,
@JSON_table nvarchar(max) = NULL,
@XML_table xml = NULL,
@OptParam nvarchar(4000) = NULL,
@JobStepID int = NULL,
@DatabaseName nvarchar(100) = 'pcINTEGRATOR', --Optional
@ProcedureID int = 880000185,
@GetVersion bit = 0,
@Debug bit = 0

AS

/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spSet_LeafLevelFilter_ClearCache',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "-1427"},
		{"TKey" : "VersionID",  "TValue": "-1365"},
		{"TKey" : "DimensionID",  "TValue": "-1"},
		{"TKey" : "SetJobLogYN",  "TValue": "0"},
		{"TKey" : "Debug",  "TValue": "1"}
		]',
	@Debug = 1

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalGet_Journal',
	@XML = '
		<root>
			<row TKey="UserID" TValue="-10" />
			<row TKey="InstanceID" TValue="404" />
			<row TKey="VersionID" TValue="1003" />
			<row TKey="ResultTypeBM" TValue="4" />
			<row TKey="Entity" TValue="000-7" />
			<row TKey="Book" TValue="GL" />
			<row TKey="FiscalPeriod" TValue="1" />
		</root>',
	@Debug = 1

EXEC spRun_Procedure_KeyValuePair @GetVersion = 1
*/

DECLARE
	@UserID int,
	@InstanceID int,
	@VersionID int,
	@AuthenticatedUserID int,
	@JobID int,
	@SetJobLogYN bit,
	@SQLStatement nvarchar(MAX),
	@Parameter nvarchar(4000),
	@StdParameterYN bit,
	@StdParameterMandatoryYN bit,
	@JSON_table_Value nvarchar(max),
	@XML_table_Value xml,
	@CalledProcedureID int,

	@Duration_KVP time(7),
	@ErrorSeverity_KVP int,
	@ErrorState_KVP int,
	@ErrorProcedure_KVP nvarchar(128),
	@ErrorLine_KVP int,
	@ErrorMessage_KVP nvarchar(4000),

	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@StartTime datetime,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@LocalProcedureName nvarchar(100),
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.1.2174'

SET NOCOUNT ON

IF @GetVersion <> 0
	BEGIN
		SELECT
			@LocalProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Execute selected procedure with logging and other features.',
			@MandatoryParameter = 'ProcedureName'

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2140' SET @Description = 'Enhanced error handling.'
		IF @Version = '2.0.0.2141' SET @Description = 'Added parameters @JSON_table and @XML_table.'
		IF @Version = '2.0.1.2143' SET @Description = 'Logging into pcINTEGRATOR_Log.'
		IF @Version = '2.0.2.2146' SET @Description = 'Set new validation for selected UserID. Updated error handling. Set UserLicenseTypeID = 1 on UserID validation.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-210: Accept @VersionID = 0.'
		IF @Version = '2.0.3.2154' SET @Description = 'Added parameter @OptParam and @JobStepID. Added ProcedureID to JobLog.'
		IF @Version = '2.1.0.2157' SET @Description = 'Add @OptParam to temp table #KeyValuePair before check for mandatory parameters.'
		IF @Version = '2.1.0.2158' SET @Description = 'Added @AuthenticatedUserID.'
		IF @Version = '2.1.1.2171' SET @Description = 'Set correct @JobID when inserting into [pcINTEGRATOR_Log].[dbo].[JobLog]. Added @SetJobLogYN. Added TRIM on parameters.'
		IF @Version = '2.1.1.2174' SET @Description = 'Changed order of parameters. Put the new parameter @Database at the end.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @LocalProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

print	'sega1'
print	@JSON
select [@JSON] = @JSON
print	'sega2'

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SET @UserName = suser_name()

	SET @Step = 'Create temp table #KeyValuePair'
		CREATE TABLE #KeyValuePair
			(
			[TKey] nvarchar(100),
			[TValue] nvarchar(4000)
			)

	SET @Step = 'Fill temp table #KeyValuePair'
		IF ISNULL(@JSON, '') <> '' AND @XML IS NULL
			INSERT INTO #KeyValuePair
				(
				[TKey],
				[TValue]
				)
			SELECT
				[TKey],
				[TValue]
			FROM
				OPENJSON(@json)
			WITH
				(
				[TKey] nvarchar(100) COLLATE database_default,
				[TValue] nvarchar(4000) COLLATE database_default
				)

		ELSE IF ISNULL(@JSON, '') = '' AND @XML IS NOT NULL
			INSERT INTO #KeyValuePair
				(
				[TKey],
				[TValue]
				)
			SELECT
				[TKey] = r.v.value('@TKey[1]', 'nvarchar(100)'),
				[TValue] = r.v.value('@TValue[1]', 'nvarchar(4000)')
			FROM
				@XML.nodes('root/row') r(v)
		ELSE
			BEGIN
    			SET @Message = 'Not valid combination of parameters. Either @JSON or @XML must be set.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

		IF LEN(@OptParam) > 0
			INSERT INTO #KeyValuePair
				(
				[TKey],
				[TValue]
				)
			SELECT
				[TKey] = REPLACE(LEFT([Row], CHARINDEX('=',[Row])-1), '@', ''),
				[TValue] = LTRIM(RTRIM(REPLACE(SUBSTRING([Row], CHARINDEX('=',[Row])+1, LEN([Row])), '''', '')))
			FROM
				(
				SELECT
					[Row] = REPLACE(REPLACE(LTRIM(RTRIM([Value])), CHAR(13), ''), CHAR(10), '')
				FROM
					STRING_SPLIT(@OptParam, ',')
				) sub

		IF @Debug <> 0
			BEGIN
				SELECT ProcedureName = @ProcedureName
				SELECT TempTable = '#KeyValuePair', * FROM #KeyValuePair
			END

	SET @Step = 'Set standard variables'
		SELECT
			@UserID = MAX(CASE WHEN TKey = 'UserID' THEN TValue ELSE NULL END),
			@InstanceID = MAX(CASE WHEN TKey = 'InstanceID' THEN TValue ELSE NULL END),
			@VersionID = MAX(CASE WHEN TKey = 'VersionID' THEN TValue ELSE NULL END),
			@AuthenticatedUserID = MAX(CASE WHEN TKey = 'AuthenticatedUserID' THEN TValue ELSE NULL END),
			@JobID = MAX(CASE WHEN TKey = 'JobID' THEN TValue ELSE NULL END),
			@SetJobLogYN = MAX(CASE WHEN TKey = 'SetJobLogYN' THEN CONVERT(int, TValue) ELSE NULL END)
		FROM
			#KeyValuePair
		WHERE
			TKey IN ('UserID', 'InstanceID', 'VersionID', 'AuthenticatedUserID', 'JobID', 'SetJobLogYN')

		SELECT
			@CalledProcedureID = [ProcedureID],
			@StdParameterYN = [StdParameterYN],
			@StdParameterMandatoryYN = [StdParameterMandatoryYN]
		FROM
			[pcINTEGRATOR].[dbo].[Procedure]
		WHERE
			[InstanceID] IN (@InstanceID, 0) AND
			[VersionID] IN (@VersionID, 0) AND
			[DatabaseName] = @DatabaseName AND
			[ProcedureName] = @ProcedureName AND
			[DeletedID] IS NULL

		IF @CalledProcedureID IS NULL
			BEGIN
				SET @Message = 'Called SP (' + @ProcedureName + ') is not properly registered.'
				SET @Severity = 0
				GOTO EXITPOINT
            END

		IF @Debug <> 0
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@AuthenticatedUserID] = @AuthenticatedUserID,
				[@JobID] = @JobID,
				[@SetJobLogYN] = @SetJobLogYN,
				[@CalledProcedureID] = @CalledProcedureID,
				[@DatabaseName] = @DatabaseName,
				[@ProcedureName] = @ProcedureName,
				[@StdParameterYN] = @StdParameterYN,
				[@StdParameterMandatoryYN] = @StdParameterMandatoryYN

	SET @Step = 'Check that selected UserID is valid'
		IF @InstanceID IS NOT NULL AND @UserID IS NOT NULL
			BEGIN
				IF
					(
					/*
					SELECT
						COUNT(1)
					FROM
						[User]
					WHERE
						UserTypeID = -1 AND
						SelectYN <> 0 AND
						((InstanceID = @InstanceID AND UserID = @UserID) OR
						(InstanceID = 0 AND UserID = @UserID AND UserLicenseTypeID = -1))
					*/
					SELECT
						COUNT(1)
					FROM
						(
						SELECT
							UserID
						FROM
							[User]
						WHERE
							UserTypeID = -1 AND
							SelectYN <> 0 AND
							((InstanceID = @InstanceID AND UserID = @UserID) OR
							(InstanceID = 0 AND UserID = @UserID AND UserLicenseTypeID = 1))
						UNION
						SELECT
							UserID
						FROM
							pcINTEGRATOR_Data.dbo.[User_Instance]
						WHERE
							InstanceID = @InstanceID AND
							UserID = @UserID AND
							(ExpiryDate >= GetDATE() OR ExpiryDate IS NULL) AND
							SelectYN <> 0
						) sub
					) < 1

					BEGIN
						SET @Message = 'Selected User is not valid for this Instance.'
						SET @Severity = 16
						GOTO EXITPOINT
                    END
			END

	SET @Step = 'Check that selected VersionID is valid'
		IF @InstanceID IS NOT NULL AND ISNULL(@VersionID, 0) <> 0
			BEGIN
				IF (SELECT COUNT(1) FROM [Version] WHERE SelectYN <> 0 AND InstanceID = @InstanceID AND VersionID = @VersionID) <> 1
					BEGIN
						SET @Message = 'Selected Version is not valid for this Instance.'
						SET @Severity = 16
						GOTO EXITPOINT
                    END
			END

	SET @Step = 'Create temp table #KVP_Param'
		CREATE TABLE #KVP_Param
			(
			Parameter NVARCHAR(100) COLLATE database_default,
			MandatoryYN bit
			)

	SET @Step = 'Fill temp table #KVP_Param'
		IF @StdParameterYN <> 0 AND @StdParameterMandatoryYN <> 0
			INSERT INTO #KVP_Param (Parameter, MandatoryYN)
			SELECT Parameter, MandatoryYN = 1 FROM (SELECT Parameter = 'UserID' UNION SELECT Parameter = 'InstanceID' UNION SELECT Parameter = 'VersionID') sub

		INSERT INTO #KVP_Param (Parameter, MandatoryYN)
		SELECT Parameter, MandatoryYN = 1 FROM ProcedureParameter WHERE ProcedureID = @CalledProcedureID

		IF @Debug <> 0 SELECT TempTable = '#KVP_Param', * FROM #KVP_Param

	SET @Step = 'Add optional parameters to temp table #KVP_Param'
		INSERT INTO #KVP_Param (Parameter, MandatoryYN)
		SELECT
			Parameter = Par.[name],
			MandatoryYN = 0
		FROM
			sys.procedures Pro
			INNER JOIN sys.parameters Par ON Par.[object_id] = Pro.[object_id]
		WHERE
			Pro.[name] = @ProcedureName AND
			Par.[name] IN ('@ProcedureID', '@Parameter', '@StartTime', '@JobLogID')

		IF @Debug <> 0 SELECT TempTable = '#KVP_Param', * FROM #KVP_Param

	SET @Step = 'Check that mandatory parameters are set'
		SELECT @Message = @Message + '@' + Parameter + ', ' FROM #KVP_Param P WHERE P.MandatoryYN <> 0 AND NOT EXISTS (SELECT 1 FROM #KeyValuePair KVP WHERE KVP.TKey = P.Parameter AND KVP.TValue IS NOT NULL)
		IF LEN(@Message) > 0
			BEGIN
    			SET @Message = 'Following parameter(s) must be set: ' + LEFT(@Message, LEN(@Message) - 1) + '.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Set @SQLStatement'
		SET @SQLStatement = 'EXEC [' + @DatabaseName + '].[dbo].[' + @ProcedureName + '] '
		SELECT @SQLStatement = @SQLStatement + '@' + TKey + '=N''' + TValue + ''','
		FROM
			#KeyValuePair
		ORDER BY
			TKey

		IF @JSON_table IS NOT NULL
			SET @SQLStatement = @SQLStatement + '@JSON_table=@JSON_table_Value,'

		IF @XML_table IS NOT NULL
			SET @SQLStatement = @SQLStatement + '@XML_table=@XML_table_Value,'

--		IF LEN(@OptParam) > 0
--			SET @SQLStatement = @SQLStatement + @OptParam + ','

		IF (SELECT COUNT(1) FROM #KVP_Param WHERE Parameter = '@ProcedureID') > 0
			SET @SQLStatement = @SQLStatement + '@ProcedureID=' + CONVERT(nvarchar(10), @CalledProcedureID) + ','

		IF (SELECT COUNT(1) FROM #KVP_Param WHERE Parameter = '@StartTime') > 0
			SET @SQLStatement = @SQLStatement + '@StartTime=''' + CONVERT(nvarchar(50), @StartTime, 121) + ''','

	SET @Step = 'Set @Parameter'
		IF (SELECT COUNT(1) FROM #KVP_Param WHERE Parameter IN ('@Parameter', '@JobLogID')) > 0
			SET @Parameter = LEFT(@SQLStatement, LEN(@SQLStatement) - 1)

	SET @Step = 'Handle logging and parameters'
		IF (SELECT COUNT(1) FROM #KVP_Param WHERE Parameter = '@JobLogID') > 0
			BEGIN
				SELECT @SetJobLogYN = ISNULL(@SetJobLogYN, 1)
				IF @SetJobLogYN <> 0
					BEGIN
						SELECT @JobID = ISNULL(@JobID, -1)
						INSERT INTO pcINTEGRATOR_Log..JobLog ([JobID], [JobStepID], [StartTime], [ProcedureID], [ProcedureName], [Duration], [ErrorNumber], [Version], [Parameter], [ParameterTable], [UserName], [UserID], [InstanceID], [VersionID], [AuthenticatedUserID]) SELECT [JobID] = @JobID, [JobStepID] = @JobStepID, [StartTime] = @StartTime, [ProcedureID] = @CalledProcedureID, [ProcedureName] = @ProcedureName, [Duration] = '00:00:00', [ErrorNumber] = -1, [Version] = '', [Parameter] = @Parameter, [ParameterTable] = ISNULL(@JSON_table, CONVERT(nvarchar(max), @XML_table)), [UserName] = @UserName, [UserID] = @UserID, [InstanceID] = @InstanceID, [VersionID] = @VersionID, [AuthenticatedUserID] = @AuthenticatedUserID
						SET @JobLogID = @@IDENTITY

						SET @SQLStatement = @SQLStatement + '@JobLogID=''' + CONVERT(nvarchar(10), @JobLogID) + ''','
					END

				IF @Debug <> 0 SELECT [@SetJobLogYN] = @SetJobLogYN, [@JobLogID] = @JobLogID, [@JobID] = @JobID
			END

		ELSE IF (SELECT COUNT(1) FROM #KVP_Param WHERE Parameter = '@Parameter') > 0
			SET @SQLStatement = @SQLStatement + '@Parameter=N''' + REPLACE(@Parameter, '''', '''''') + ''','

-- print 'sega9'
select [@SQLStatement] = @SQLStatement
-- print 'sega10'

	SET @Step = 'Exec @SQLStatement'
		SET @SQLStatement = LEFT(@SQLStatement, LEN(@SQLStatement) - 1)

		IF @Debug <> 0 PRINT @SQLStatement

		IF @JSON_table IS NOT NULL
			BEGIN
				SET @JSON_table_Value = @JSON_table
				EXEC sp_executesql @SQLStatement, N'@JSON_table_Value nvarchar(max)', @JSON_table_Value
			END
		ELSE IF @XML_table IS NOT NULL
			BEGIN
				SET @XML_table_Value = @XML_table
				EXEC sp_executesql @SQLStatement, N'@XML_table_Value xml', @XML_table_Value
			END
		ELSE
			EXEC (@SQLStatement)
select [@SQLStatement9] = @SQLStatement

	SET @Step = 'Drop Temp tables'
		DROP TABLE #KeyValuePair
		DROP TABLE #KVP_Param
END TRY

BEGIN CATCH
	SELECT
		@UserID = ISNULL(@UserID, -100),
		@InstanceID = ISNULL(@InstanceID, -100),
		@VersionID = ISNULL(@VersionID, -100)
	SELECT @Duration_KVP = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity_KVP = ERROR_SEVERITY(), @ErrorState_KVP = ERROR_STATE(), @ErrorProcedure_KVP = ERROR_PROCEDURE(), @ErrorLine_KVP = ERROR_LINE(), @ErrorMessage_KVP = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration_KVP, @Deleted = 0, @Inserted = 0, @Updated = 0, @Selected = 0, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity_KVP, @ErrorState = @ErrorState_KVP, @ErrorProcedure = @ErrorProcedure_KVP, @ErrorStep = @Step, @ErrorLine = @ErrorLine_KVP, @ErrorMessage = @ErrorMessage_KVP, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity_KVP, ErrorState = @ErrorState_KVP, ErrorProcedure = @ErrorProcedure_KVP, ErrorStep = @Step, ErrorLine = @ErrorLine_KVP, ErrorMessage = @ErrorMessage_KVP
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
