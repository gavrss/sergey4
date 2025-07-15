SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_DemoData]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DemoYN bit = 1,

	@JobID int = NULL,
	@Rows int = NULL,
	@ProcedureID INT = 880000250,
	@Parameter NVARCHAR(4000) = NULL,
	@StartTime DATETIME = NULL,
	@Duration datetime = 0 OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

AS
/*
EXEC [dbo].[spCreate_DemoData] 
	@UserID = -10,
	@InstanceID = -1303,
	@VersionID = -1241,
	@Debug = 1

	--GetVersion
		EXEC [spCreate_DemoData] @GetVersion = 1
*/
DECLARE
	@Account nvarchar(4),
	@BusinessProcess nvarchar(10),
	@Currency nvarchar(3),
	@Entity nvarchar(20),
	@Scenario nvarchar(10),
	@Time nvarchar(6),
	@SQLStatement nvarchar(max),
	@ApplicationID int,
	@CallistoDatabase nvarchar(100),
	@InitialWorkflowStateID_Budget int,
	@InitialWorkflowStateID_Forecast int,

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

		SET @UserName = ISNULL(@UserName, suser_name())

		SELECT
			@ApplicationID = [ApplicationID],
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		SELECT
			@InitialWorkflowStateID_Budget = MAX(CASE WHEN S.MemberKey = 'BUDGET' THEN WF.InitialWorkflowStateID ELSE 0 END),
			@InitialWorkflowStateID_Forecast = MAX(CASE WHEN S.MemberKey = 'FORECAST' THEN WF.InitialWorkflowStateID ELSE 0 END)
		FROM
			[pcINTEGRATOR].[dbo].[Workflow] WF
			INNER JOIN [pcINTEGRATOR].[dbo].[Scenario] S ON S.ScenarioID = WF.ScenarioID AND S.ScenarioTypeID IN (-5, -3) 
		WHERE
			WF.InstanceID = @InstanceID AND
			WF.VersionID = @VersionID

		IF @Debug <> 0 SELECT ApplicationID = @ApplicationID, CallistoDatabase = @CallistoDatabase, InitialWorkflowStateID_Budget = @InitialWorkflowStateID_Budget, InitialWorkflowStateID_Forecast = @InitialWorkflowStateID_Forecast

	SET @Step = 'Check if demo'
		IF @DemoYN = 0
			BEGIN
				SET @Message = 'This SP can only be used for demo purposes'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Create temp table and fill with ACTUAL'
		SELECT 
			[Account],
			[BusinessProcess] = 'E10_Actual',
			[Currency],
			[Entity],
			[GL_Department],
			[Scenario] = CONVERT(nvarchar(10), 'ACTUAL'),
			[Time],
			[Financials_Value] = SUM([Financials_Value])
		INTO
			#Financials
		FROM
			[pcDATA_ERP10_INTEGRATED].[dbo].[FACT_Financials_View]
		WHERE
			Scenario = 'ACTUAL' AND
			Entity = 'EPIC03' AND
			[Time] BETWEEN '201701' AND '201804' AND
			ISNUMERIC(LEFT(Account, 4)) <> 0 AND LEN(Account) = 4 AND
			BusinessRule = 'NONE'
		GROUP BY
			[Account],
			[Currency],
			[Entity],
			[GL_Department],
			[Time]
		ORDER BY
			[Time]

	SET @Step = 'Fill temp table with BUDGET'
		INSERT INTO #Financials
			(
			[Account],
			[BusinessProcess],
			[Currency],
			[Entity],
			[GL_Department],
			[Scenario],
			[Time],
			[Financials_Value]
			)
		SELECT 
			[Account],
			[BusinessProcess] = 'INPUT',
			[Currency],
			[Entity],
			[GL_Department],
			[Scenario] = 'BUDGET',
			[Time],
			[Financials_Value] = SUM([Financials_Value])
		FROM
			[pcDATA_ERP10_INTEGRATED].[dbo].[FACT_Financials_View]
		WHERE
			Scenario = 'BUDGET' AND
			Entity = 'EPIC03' AND
			[Time] BETWEEN '201801' AND '201812' AND
			ISNUMERIC(LEFT(Account, 4)) <> 0 AND LEN(Account) = 4 AND
			BusinessRule = 'NONE'
		GROUP BY
			[Account],
			[Currency],
			[Entity],
			[GL_Department],
			[Time]
		ORDER BY
			[Time]

	SET @Step = 'Create Cursor for changing GL_Department when NONE'
		DECLARE Department_Cursor CURSOR FOR

			SELECT 
				[Account],
				[BusinessProcess],
				[Currency],
				[Entity],
				[Scenario],
				[Time]
			FROM
				#Financials
			WHERE
				[GL_Department] = 'NONE'

			OPEN Department_Cursor
			FETCH NEXT FROM Department_Cursor INTO @Account, @BusinessProcess, @Currency, @Entity, @Scenario, @Time

			WHILE @@FETCH_STATUS = 0
				BEGIN
					UPDATE #Financials
					SET
						[GL_Department] = CONVERT(nvarchar(2), CONVERT(int, RAND() * 6) * 10)
					WHERE
						[Account] = @Account AND
						[BusinessProcess] = @BusinessProcess AND
						[Currency] = @Currency AND
						[Entity] = @Entity AND
						[Scenario] = @Scenario AND
						[Time] = @Time

					FETCH NEXT FROM Department_Cursor INTO  @Account, @BusinessProcess, @Currency, @Entity, @Scenario, @Time
				END

		CLOSE Department_Cursor
		DEALLOCATE Department_Cursor	

	SET @Step = 'Update GL_Department when 0'
		UPDATE F
		SET
			[GL_Department] = '00'
		FROM
			#Financials F
		WHERE
			[GL_Department] = '0'

	SET @Step = 'Insert FORECAST'
		INSERT INTO #Financials
			(
			[Account],
			[BusinessProcess],
			[Currency],
			[Entity],
			[GL_Department],
			[Scenario],
			[Time],
			[Financials_Value]
			)
		SELECT 
			[Account],
			[BusinessProcess] = 'INPUT',
			[Currency],
			[Entity],
			[GL_Department],
			[Scenario] = 'FORECAST',
			[Time],
			[Financials_Value]
		FROM
			#Financials
		WHERE
			Scenario = 'ACTUAL' AND
			[Time] BETWEEN '201801' AND '201804'

		INSERT INTO #Financials
			(
			[Account],
			[BusinessProcess],
			[Currency],
			[Entity],
			[GL_Department],
			[Scenario],
			[Time],
			[Financials_Value]
			)
		SELECT 
			[Account],
			[BusinessProcess] = 'INPUT',
			[Currency],
			[Entity],
			[GL_Department],
			[Scenario] = 'FORECAST',
			[Time],
			[Financials_Value]
		FROM
			#Financials
		WHERE
			Scenario = 'BUDGET' AND
			[Time] BETWEEN '201805' AND '201812'

	SET @Step = 'Fill with zero values, Budget and Forecast'
		INSERT INTO #Financials
			(
			[Account],
			[BusinessProcess],
			[Currency],
			[Entity],
			[GL_Department],
			[Scenario],
			[Time],
			[Financials_Value]
			)
		SELECT DISTINCT
			F.[Account],
			F.[BusinessProcess],
			F.[Currency],
			F.[Entity],
			F.[GL_Department],
			F.[Scenario],
			sub.[Time],
			[Financials_Value] = 0
		FROM
			#Financials F
			INNER JOIN (SELECT DISTINCT [Time] FROM #Financials WHERE [Scenario] = 'BUDGET') sub ON 1 = 1
		WHERE
			F.[Scenario] = 'BUDGET' AND
			NOT EXISTS (SELECT 1 FROM #Financials FD WHERE
														FD.[Account] = F.[Account] AND
														FD.[BusinessProcess] = F.[BusinessProcess] AND
														FD.[Currency] = F.[Currency] AND
														FD.[Entity] = F.[Entity] AND
														FD.[GL_Department] = F.[GL_Department] AND
														FD.[Scenario] = F.[Scenario] AND
														FD.[Time] = sub.[Time]
														)

		INSERT INTO #Financials
			(
			[Account],
			[BusinessProcess],
			[Currency],
			[Entity],
			[GL_Department],
			[Scenario],
			[Time],
			[Financials_Value]
			)
		SELECT DISTINCT
			F.[Account],
			F.[BusinessProcess],
			F.[Currency],
			F.[Entity],
			F.[GL_Department],
			F.[Scenario],
			sub.[Time],
			[Financials_Value] = 0
		FROM
			#Financials F
			INNER JOIN (SELECT DISTINCT [Time] FROM #Financials WHERE [Scenario] = 'FORECAST') sub ON 1 = 1
		WHERE
			F.[Scenario] = 'FORECAST' AND
			NOT EXISTS (SELECT 1 FROM #Financials FD WHERE
														FD.[Account] = F.[Account] AND
														FD.[BusinessProcess] = F.[BusinessProcess] AND
														FD.[Currency] = F.[Currency] AND
														FD.[Entity] = F.[Entity] AND
														FD.[GL_Department] = F.[GL_Department] AND
														FD.[Scenario] = F.[Scenario] AND
														FD.[Time] = sub.[Time]
														)

		IF @Debug <> 0
			SELECT
				TempTable = '#Financials', *
			FROM
				#Financials
			ORDER BY
				Scenario,
				[Time],
				Account,
				GL_Department

	SET @Step = 'Insert into FACT table'
		SET @SQLStatement = '
			INSERT INTO [' + @CallistoDatabase + ']..[FACT_Financials_default_partition]
				(
				[Account_MemberId],
				[BusinessProcess_MemberId],
				[BusinessRule_MemberId],
				[Currency_MemberId],
				[Entity_MemberId],
				[Scenario_MemberId],
				[Time_MemberId],
				[TimeDataView_MemberId],
				[Version_MemberId],
				[GL_Department_MemberId],
				[WorkflowState_MemberId],
				[ChangeDatetime],
				[Userid],
				[Financials_Value]
				)
			SELECT
				[Account_MemberId] = ISNULL([Account].[MemberId], -1),
				[BusinessProcess_MemberId] = ISNULL([BusinessProcess].[MemberId], -1),
				[BusinessRule_MemberId] = -1,
				[Currency_MemberId] = ISNULL([Currency].[MemberId], -1),
				[Entity_MemberId] = ISNULL([Entity].[MemberId], -1),
				[Scenario_MemberId] = ISNULL([Scenario].[MemberId], -1),
				[Time_MemberId] = ISNULL([Time].[MemberId], -1),
				[TimeDataView_MemberId] = ISNULL([TimeDataView].[MemberId], -1),
				[Version_MemberId] = -1,
				[GL_Department_MemberId] = ISNULL([GL_Department].[MemberId], -1),
				[WorkflowState_MemberId] = CASE [Scenario].[MemberId] WHEN 120 THEN ' + CONVERT(nvarchar(10), @InitialWorkflowStateID_Forecast) + ' WHEN 130 THEN ' + CONVERT(nvarchar(10), @InitialWorkflowStateID_Budget) + ' ELSE -1 END,
				[ChangeDatetime] = GetDate(),
				[Userid]= suser_name(),
				[Financials_Value] = F.[Financials_Value]
			FROM
				#Financials F
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Account] [Account] ON [Account].Label COLLATE DATABASE_DEFAULT = [F].[Account]
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_BusinessProcess] [BusinessProcess] ON [BusinessProcess].Label COLLATE DATABASE_DEFAULT = [F].[BusinessProcess]
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Currency] [Currency] ON [Currency].Label COLLATE DATABASE_DEFAULT = [F].[Currency]
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Entity] [Entity] ON [Entity].Label COLLATE DATABASE_DEFAULT = [F].[Entity]
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Scenario] [Scenario] ON [Scenario].Label COLLATE DATABASE_DEFAULT = [F].[Scenario]
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Time] [Time] ON [Time].Label COLLATE DATABASE_DEFAULT = [F].[Time]
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDataView] [TimeDataView] ON [TimeDataView].Label COLLATE DATABASE_DEFAULT = ''RAWDATA''
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_GL_Department] [GL_Department] ON [GL_Department].Label COLLATE DATABASE_DEFAULT = [F].[GL_Department]'
 
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'DROP temp tables'
		DROP TABLE #Financials

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
