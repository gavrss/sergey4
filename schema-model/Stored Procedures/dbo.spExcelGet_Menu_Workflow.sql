SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spExcelGet_Menu_Workflow]
(
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ApplicationName	nvarchar(100) = NULL,
	@ModelName			nvarchar(100) = 'Financials',
	@ResultTypeBM		tinyint = 3,

	@JobID int = NULL,
	@Rows int = NULL,
	@ProcedureID INT = 880000052,
	@Parameter NVARCHAR(4000) = NULL,
	@StartTime DATETIME = NULL,
	@Duration datetime = 0 OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

)

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spExcelGet_Menu_Workflow',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "2129"},
		{"TKey" : "InstanceID",  "TValue": "404"},
		{"TKey" : "VersionID",  "TValue": "1003"},
		{"TKey" : "ApplicationName",  "TValue": "pcDATA_Salinity2"},
		{"TKey" : "ModelName",  "TValue": "Sales"},
		{"TKey" : "ResultTypeBM",  "TValue": "3"}
		]'

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spExcelGet_Menu_Workflow',
	@XML = '
		<root>
			<row TKey="UserID" TValue="2129" />
			<row TKey="InstanceID" TValue="404" />
			<row TKey="VersionID" TValue="1003" />
			<row TKey="ApplicationName" TValue="pcDATA_Salinity2" />
			<row TKey="ModelName" TValue="Sales" />
			<row TKey="ResultTypeBM" TValue="3" />
		</root>'

	EXEC dbo.[spExcelGet_Menu_Workflow] @UserID = 2129, @InstanceID = 404, @VersionID = 1003,  @ApplicationName = 'pcDATA_Salinity2', @ModelName = 'Sales', @ResultTypeBM = 3, @Debug = 1
	EXEC dbo.[spExcelGet_Menu_Workflow] @ApplicationName = 'pcDATA_Salinity2', @ResultTypeBM = 3, @Debug = 1
	EXEC [spExcelGet_Menu_Workflow] @GetVersion = 1
*/	

--#WITH ENCRYPTION#--

DECLARE
	@SQLStatement NVARCHAR(MAX),
	@UserNameAD nvarchar(100),
	@SQL_Select nvarchar(max) = '',

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

	SET @Step = 'Get @ResultTypeBM = 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
 				SET @SQLStatement = '
					SELECT Dimension, DefaultMember
					FROM
						(
						SELECT Dimension = ''Time'', DefaultMember = NULL, SortOrder = -1
						UNION ALL
						SELECT Dimension = ''Scenario'', DefaultMember = NULL, SortOrder = 0
						UNION ALL
						SELECT
							Dimension = Dimension, 
							DefaultMember = CASE WHEN Driver_Number = 0 THEN CASE WHEN ISNULL(DefaultValue, '''')  = '''' THEN ''None'' ELSE DefaultValue END ELSE NULL END, 
							SortOrder = CASE WHEN Driver_Number = 0 THEN 1000 ELSE Driver_Number END
						FROM
							[' + @ApplicationName + '].[dbo].[Canvas_Workflow_Segment]
						WHERE
							Dimension NOT IN (''Time'', ''Scenario'') AND
							Model = ''' + @ModelName + '''
						) sub
					ORDER BY
						SortOrder'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Get @ResultTypeBM = 2'
		IF @ResultTypeBM & 2 > 0
			BEGIN

				CREATE TABLE #Dimension
					(
					Dimension nvarchar(100) COLLATE DATABASE_DEFAULT,
					SortOrder int
					)

				SET @SQLStatement = '
					INSERT INTO #Dimension
						(
						Dimension,
						SortOrder
						)
					SELECT 
						Dimension = c.[name],
						SortOrder = Driver_Number
					FROM
						[' + @ApplicationName + '].[sys].[tables] t
						INNER JOIN [' + @ApplicationName + '].[sys].[columns] c ON c.object_id = t.object_id AND c.name NOT IN (''Time'', ''Scenario'')
						INNER JOIN
							(
							SELECT
								Dimension,
								Driver_Number
							FROM
								[' + @ApplicationName + '].[dbo].[Canvas_Workflow_Segment]
							WHERE
								CASE WHEN Driver_Number = 0 THEN CASE WHEN ISNULL(DefaultValue, '''')  = '''' THEN ''None'' ELSE DefaultValue END ELSE NULL END IS NULL AND
								Model = ''' + @ModelName + '''
							) sub ON sub.Dimension = c.name
					WHERE
						t.name = ''Canvas_Workflow_Detail'''

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
	
				SELECT
					@SQL_Select = @SQL_Select + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + Dimension + '] = CWD.[' + Dimension + ']'
				FROM
					#Dimension
				ORDER BY
					SortOrder

				 SET @SQLStatement = '
					SELECT 
						WorkflowType			= ''Canvas'', --Canvas = Herve, ExcelAddin = Bengt, Web = Andrey
						WorkflowDescription		= CWD.Workflow_Description + '' - ('' + Responsible + '' >>> '' + Approver + '')'',
						WorkflowParameter		= ''L\'' + ''' + @ModelName + '\Workflow\'' + CWD.[Schedule] + ''.xlsm'',
						[Status] = CW.[Status],
						[Time] = CWD.[Time],
						[Scenario] = CWD.[Scenario]' + @SQL_Select + '
					FROM
						[' + @ApplicationName + '].[dbo].[Canvas_Workflow_Detail] CWD
						INNER JOIN (SELECT DISTINCT [Label] FROM [' + @ApplicationName + '].[dbo].[Canvas_Users] WHERE WinUser = ''' + @UserNameAD + ''') U ON U.Label = CWD.Administrator OR U.Label = CWD.Approver OR U.Label = CWD.Responsible
						LEFT JOIN [' + @ApplicationName + '].[dbo].[Canvas_Workflow] CW ON CW.[Workflow_Detail_RecordID] = CWD.[RecordID]
					WHERE
						CWD.[Active] = 1 AND 
						CWD.[Model] = ''' + @ModelName + ''''

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				DROP TABLE #Dimension
			END

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
