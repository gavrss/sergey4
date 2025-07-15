SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR01_HD]
	@UserID int = -10,
	@InstanceID int = 424,
	@VersionID int = 1017,

	@BR_ID int = 1002,
	@FromTime int = 201901,
	@ToTime int = 201912,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000403,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spBR_BR01_HD',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spBR_BR01_HD] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1
EXEC [spBR_BR01_HD] @UserID = -10, @InstanceID = 424, @VersionID = 1017, @BR_ID = 1002, @FromTime = 201801, @ToTime = 201812, @Debug = 1
EXEC [spBR_BR01_HD] @UserID = -10, @InstanceID = 424, @VersionID = 1017, @BR_ID = 1002, @FromTime = 201901, @ToTime = 201905, @Debug = 1
EXEC [spBR_BR01_HD] @UserID = -10, @InstanceID = 424, @VersionID = 1017, @BR_ID = 1006, @FromTime = 201901, @ToTime = 201901, @Debug = 1

EXEC [spBR_BR01_HD] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@InitialStepID [int], 
	@MemberKey [nvarchar](100),
	@DestinationMemberKey [nvarchar](100),
	@MasterMemberKey [nvarchar](100),
	@ModifierID [int],
	@Parameter [float],
	@PreModifierID [int],
	@PreParameter [float],
	@DataClassID [int],
	@DimensionSetting [nvarchar](4000),
	@DimensionFilter [nvarchar](4000),
	@BR01_StepID int,
	@Decimal int,
	@BR01_StepPartID int,
	@Operator nchar(1),
	@LeafLevelFilter nvarchar(max),
	@SQLStatement nvarchar(max),
	@PreExec nvarchar(100),
	@PostExec nvarchar(100),
	@Comment nvarchar(1024),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.2.2145'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Template for creating SPs',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2142' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Changed BR01_ID to BusinessRuleID.'
		IF @Version = '2.0.2.2145' SET @Description = 'Hardcoded for Heartland.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

/* Temporary disabled
		SELECT
			@PreExec = PreExec,
			@PostExec = PostExec
		FROM
			pcINTEGRATOR..BR01_Master
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			BusinessRuleID = @BR_ID
*/

	SET @Step = 'Run PreExec'
		--Add security check (Correct InstanceID)
		IF @PreExec IS NOT NULL
			EXEC (@PreExec)

	SET @Step = 'Create temp tables'
		CREATE TABLE #InitialStep
			(
			[InitialStepID] [int] IDENTITY(1,1) NOT NULL, 
			[BR01_StepID] int,
			[MemberKey] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[ModifierID] [int] NULL,
			[Parameter] [float] NULL,
			[DataClassID] [int] NULL,
			[DimensionFilter] [nvarchar](4000) COLLATE DATABASE_DEFAULT
			)

		--Based on Master dataclass
		CREATE TABLE #BR01_FACT
			(
			[InitialStepID] int,
			[Account_MemberKey] nvarchar(50),
			[Currency_MemberKey] nvarchar(50),
			[Entity_MemberKey] nvarchar(50),
			[GL_Future_Use_MemberKey] nvarchar(50),
			[GL_Matrix_MemberKey] nvarchar(50),
			[GL_Office_MemberKey] nvarchar(50),
			[GL_PC_MemberKey] nvarchar(50),
			[Scenario_MemberKey] nvarchar(50),
			[Time_MemberKey] nvarchar(50),
			[Financials_Value] float
			)

		CREATE TABLE #BR01_FACT_Step
			(
			[Account_MemberKey] nvarchar(50),
			[Currency_MemberKey] nvarchar(50),
			[Entity_MemberKey] nvarchar(50),
			[GL_Future_Use_MemberKey] nvarchar(50),
			[GL_Matrix_MemberKey] nvarchar(50),
			[GL_Office_MemberKey] nvarchar(50),
			[GL_PC_MemberKey] nvarchar(50),
			[Scenario_MemberKey] nvarchar(50),
			[Time_MemberKey] nvarchar(50),
			[Financials_Value] float
			)

		CREATE TABLE #Modifier
			(
			ModifierID int,
			Parameter float
			)

	SET @Step = 'Fill table #InitialStep'
		INSERT INTO #InitialStep
			(
			[BR01_StepID],
			[MemberKey],
			[ModifierID],
			[Parameter],
			[DataClassID],
			[DimensionFilter]
			)
		SELECT
			[BR01_StepID] = S.[BR01_StepID],
			[MemberKey] = S.[MemberKey],
			[ModifierID] = S.[ModifierID],
			[Parameter] = S.[Parameter],
			[DataClassID] = CASE WHEN S.BR01_StepPartID = 0 THEN M.[DataClassID] ELSE ISNULL(S.[DataClassID], M.[DataClassID]) END,
			[DimensionFilter] = S.[DimensionFilter]
		FROM
			BR01_Master M 
			INNER JOIN BR01_Step S ON S.InstanceID = M.InstanceID AND S.VersionID = M.VersionID AND S.BusinessRuleID = M.BusinessRuleID AND S.BR01_StepPartID >= 0
		WHERE
			M.InstanceID = @InstanceID AND
			M.VersionID = @VersionID AND
			M.BusinessRuleID = @BR_ID AND
			NOT EXISTS (SELECT 1 FROM BR01_Step D WHERE D.BR01_StepPartID = -1 AND D.MemberKey = S.MemberKey)
		GROUP BY
			S.[BR01_StepID],
			S.MemberKey,
			S.ModifierID,
			S.Parameter,
			CASE WHEN S.BR01_StepPartID = 0 THEN M.[DataClassID] ELSE ISNULL(S.[DataClassID], M.[DataClassID]) END,
			S.DimensionFilter
		ORDER BY
			MIN([BR01_StepID]),
			MIN([BR01_StepPartID])

		IF @Debug <> 0 SELECT TempTable = '#InitialStep', * FROM #InitialStep

		--[dbo].[Get_BR_Modifier] (@ModifierID int, @Basevalue int, @Parameter int)
		--SELECT [dbo].[Get_BR_Modifier] (30, 201901, 13)

	SET @Step = 'Run Cursor on #InitialStep'
		DECLARE BR01_Base_Cursor CURSOR FOR
			
			SELECT
				[BR01_StepID],
				[InitialStepID], 
				[MemberKey],
				[ModifierID],
				[Parameter],
				[DataClassID],
				[DimensionFilter]
			FROM
				#InitialStep
			ORDER BY
				[InitialStepID]

			OPEN BR01_Base_Cursor
			FETCH NEXT FROM BR01_Base_Cursor INTO @BR01_StepID, @InitialStepID, @MemberKey, @ModifierID, @Parameter, @DataClassID, @DimensionFilter

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [BR01_StepID] = @BR01_StepID, InitialStepID = @InitialStepID, MemberKey = @MemberKey, ModifierID = @ModifierID, Parameter = @Parameter, DataClassID = @DataClassID, DimensionFilter = @DimensionFilter

					IF @ModifierID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM #Modifier M WHERE M.ModifierID = @ModifierID AND (M.Parameter = @Parameter OR (M.Parameter IS NULL AND @Parameter IS NULL)))
						BEGIN
							SELECT
								@PreModifierID = CASE WHEN @ModifierID = 70 THEN 30 ELSE @ModifierID END,
								@PreParameter = CASE WHEN @ModifierID = 70 THEN ISNULL(@Parameter, -1) ELSE @PreParameter END

							INSERT INTO #Modifier
								(
								ModifierID,
								Parameter
								)
							SELECT 
								ModifierID = @PreModifierID,
								Parameter = @PreParameter
							WHERE
								NOT EXISTS (SELECT 1 FROM #Modifier M WHERE M.ModifierID = @PreModifierID AND (M.Parameter = @PreParameter OR (M.Parameter IS NULL AND @PreParameter IS NULL)))
							
							INSERT INTO #Modifier
								(
								ModifierID,
								Parameter
								)
							SELECT 
								ModifierID = @ModifierID,
								Parameter = @Parameter
							WHERE
								NOT EXISTS (SELECT 1 FROM #Modifier M WHERE M.ModifierID = @ModifierID AND (M.Parameter = @Parameter OR (M.Parameter IS NULL AND @Parameter IS NULL)))

							IF @PreModifierID = 30
								BEGIN
									SELECT 
										Time_MemberKey = T.MemberId,
										Time_MemberKey_Modified = pcINTEGRATOR.[dbo].[Get_BR_Modifier] (@PreModifierID, T.MemberId, @PreParameter)
									INTO
										[#Modifier_30_-1]
									FROM
										[pcDATA_HD].[dbo].[S_DS_Time] T
									WHERE
										MemberId BETWEEN @FromTime AND @ToTime

									IF @Debug <> 0 SELECT TempTable = '#Modifier_30_-1', * FROM [#Modifier_30_-1]
								END
							IF @Debug <> 0 SELECT TempTable = '#Modifier', * FROM [#Modifier]
						END

					EXEC pcINTEGRATOR..spGet_LeafLevelFilter @UserID = -10, @InstanceID = 0, @VersionID = 0, @DatabaseName = 'pcDATA_HD', @DimensionName = 'Account', @Filter = @MemberKey, @StorageTypeBM = 4, @FilterLevel = 'L', @LeafLevelFilter = @LeafLevelFilter OUT, @Debug = 0

					IF @ModifierID = 70
						SET @SQLStatement = '
							INSERT INTO #BR01_FACT
								(
								[InitialStepID],
								[Account_MemberKey],
								[Currency_MemberKey],
								[Entity_MemberKey],
								[GL_Future_Use_MemberKey],
								[GL_Matrix_MemberKey],
								[GL_Office_MemberKey],
								[GL_PC_MemberKey],
								[Scenario_MemberKey],
								[Time_MemberKey],
								[Financials_Value]
								)
							SELECT 
								[InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ',
								[Account] = ''' + @MemberKey + ''',
								[Currency] = [Master].[Currency],
								[Entity] = [Master].[Entity],
								[GL_Future_Use] = [Master].[GL_Future_Use],
								[GL_Matrix] = [Master].[GL_Matrix],
								[GL_Office] = [Master].[GL_Office],
								[GL_PC] = [Master].[GL_PC],
								[Scenario] = [Master].[Scenario],
								[Time] = [Master].[Time],
								[Financials_Value] = ISNULL(CM.[Financials_Value], 0.0) - ISNULL(PM.[Financials_Value], 0.0)
							FROM
								(
								SELECT DISTINCT
									[Currency],
									[Entity],
									[GL_Future_Use],
									[GL_Matrix],
									[GL_Office],
									[GL_PC],
									[Scenario],
									[Time]
								FROM
									[pcDATA_HD].[dbo].[FACT_Financials_View] V
								WHERE
									V.[Account] IN (' + @LeafLevelFilter + ') AND
									V.[BusinessRule] = ''NONE'' AND
									V.[Time] BETWEEN ''' + CONVERT(nvarchar(10), @FromTime) + ''' AND ''' + CONVERT(nvarchar(10), @ToTime) + ''' AND
									ISNUMERIC(V.[Time]) <> 0 AND
									V.[Scenario] IN (''ACTUAL'') AND
									V.[Version] = ''NONE'' AND
									V.[TimeDataView] = ''RAWDATA''

								UNION SELECT DISTINCT
									[Currency],
									[Entity],
									[GL_Future_Use],
									[GL_Matrix],
									[GL_Office],
									[GL_PC],
									[Scenario],
									[Time] = M.[Time_MemberKey]
								FROM
									[pcDATA_HD].[dbo].[FACT_Financials_View] V
									INNER JOIN [#Modifier_30_-1] M ON M.[Time_MemberKey_Modified] = V.Time
								WHERE
									V.[Account] IN (' + @LeafLevelFilter + ') AND
									V.[BusinessRule] = ''NONE'' AND
									ISNUMERIC(V.[Time]) <> 0 AND
									V.[Scenario] IN (''ACTUAL'') AND
									V.[Version] = ''NONE'' AND
									V.[TimeDataView] = ''RAWDATA''
								) [Master]
								LEFT JOIN (
									SELECT 
										[Currency],
										[Entity],
										[GL_Future_Use],
										[GL_Matrix],
										[GL_Office],
										[GL_PC],
										[Scenario],
										[Time],
										[Financials_Value] = SUM(V.[Financials_Value])
									FROM
										[pcDATA_HD].[dbo].[FACT_Financials_View] V
									WHERE
										V.[Account] IN (' + @LeafLevelFilter + ') AND
										V.[BusinessRule] = ''NONE'' AND
										V.[Time] BETWEEN ''' + CONVERT(nvarchar(10), @FromTime) + ''' AND ''' + CONVERT(nvarchar(10), @ToTime) + ''' AND
										ISNUMERIC(V.[Time]) <> 0 AND
										V.[Scenario] IN (''ACTUAL'') AND
										V.[Version] = ''NONE'' AND
										V.[TimeDataView] = ''RAWDATA''
									GROUP BY
										[Currency],
										[Entity],
										[GL_Future_Use],
										[GL_Matrix],
										[GL_Office],
										[GL_PC],
										[Scenario],
										[Time]
									) CM ON
										CM.[Currency] = [Master].[Currency] AND
										CM.[Entity] = [Master].[Entity] AND
										CM.[GL_Future_Use] = [Master].[GL_Future_Use] AND
										CM.[GL_Matrix] = [Master].[GL_Matrix] AND
										CM.[GL_Office] = [Master].[GL_Office] AND
										CM.[GL_PC] = [Master].[GL_PC] AND
										CM.[Scenario] = [Master].[Scenario] AND
										CM.[Time] = [Master].[Time]

								LEFT JOIN (
									SELECT 
										[Currency],
										[Entity],
										[GL_Future_Use],
										[GL_Matrix],
										[GL_Office],
										[GL_PC],
										[Scenario],
										[Time] = M.[Time_MemberKey],
										[Financials_Value] = SUM(V.[Financials_Value])
									FROM
										[pcDATA_HD].[dbo].[FACT_Financials_View] V
										INNER JOIN [#Modifier_30_-1] M ON M.[Time_MemberKey_Modified] = V.Time
									WHERE
										V.[Account] IN (' + @LeafLevelFilter + ') AND
										V.[BusinessRule] = ''NONE'' AND
										ISNUMERIC(V.[Time]) <> 0 AND
										V.[Scenario] IN (''ACTUAL'') AND
										V.[Version] = ''NONE'' AND
										V.[TimeDataView] = ''RAWDATA''
									GROUP BY
										[Currency],
										[Entity],
										[GL_Future_Use],
										[GL_Matrix],
										[GL_Office],
										[GL_PC],
										[Scenario],
										M.[Time_MemberKey]
									) PM ON
										PM.[Currency] = [Master].[Currency] AND
										PM.[Entity] = [Master].[Entity] AND
										PM.[GL_Future_Use] = [Master].[GL_Future_Use] AND
										PM.[GL_Matrix] = [Master].[GL_Matrix] AND
										PM.[GL_Office] = [Master].[GL_Office] AND
										PM.[GL_PC] = [Master].[GL_PC] AND
										PM.[Scenario] = [Master].[Scenario] AND
										PM.[Time] = [Master].[Time]'

					ELSE IF @BR01_StepID IN (18) OR @BR_ID = 1006 --DimensionFilter: GL_Office.MemberKey LIKE '04%'
						SET @SQLStatement = '
							INSERT INTO #BR01_FACT
								(
								[InitialStepID],
								[Account_MemberKey],
								[Currency_MemberKey],
								[Entity_MemberKey],
								[GL_Future_Use_MemberKey],
								[GL_Matrix_MemberKey],
								[GL_Office_MemberKey],
								[GL_PC_MemberKey],
								[Scenario_MemberKey],
								[Time_MemberKey],
								[Financials_Value]
								)
							SELECT 
								[InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ',
								[Account] = ''' + @MemberKey + ''',
								[Currency],
								[Entity],
								[GL_Future_Use],
								[GL_Matrix],
								[GL_Office],
								[GL_PC],
								[Scenario],
								[Time],
								[Financials_Value] = SUM(V.[Financials_Value]) ' + CASE @ModifierID WHEN 10 THEN ' * ' + CONVERT(nvarchar(10), @Parameter) WHEN 20 THEN ' / ' + CONVERT(nvarchar(10), @Parameter) ELSE '' END + '
							FROM
								[pcDATA_HD].[dbo].[FACT_Financials_View] V
							WHERE
								V.[Account] IN (' + @LeafLevelFilter + ') AND
								V.[BusinessRule] = ''NONE'' AND
								V.[Time] BETWEEN ''' + CONVERT(nvarchar(10), CASE WHEN @ModifierID IN (30) THEN (SELECT pcINTEGRATOR.[dbo].[Get_BR_Modifier] (@ModifierID, @FromTime, @Parameter)) ELSE @FromTime END) + ''' AND ''' + CONVERT(nvarchar(10), CASE WHEN @ModifierID IN (30) THEN (SELECT pcINTEGRATOR.[dbo].[Get_BR_Modifier] (@ModifierID, @ToTime, @Parameter)) ELSE @ToTime END) + ''' AND
								ISNUMERIC(V.[Time]) <> 0 AND
								V.[Scenario] IN (''ACTUAL'') AND
								V.[Version] = ''NONE'' AND
								V.[TimeDataView] = ''RAWDATA'' AND
								' + CASE WHEN @BR01_StepID IN (18) THEN 'V.GL_Office LIKE ''04%'' AND' ELSE '' END + '
								V.GL_Future_Use IN (''00000'',''00004'',''00005'',''00008'',''00014'',''00016'',''00015'',''00017'')
							GROUP BY
								[Currency],
								[Entity],
								[GL_Future_Use],
								[GL_Matrix],
								[GL_Office],
								[GL_PC],
								[Scenario],
								[Time]'
/*
					ELSE IF @BR01_StepID = 19 --DimensionFilter: GL_Matrix.MemberKey = 'OF_DIRECT'|GL_Office.StartMonth + 100 >= Time.MemberKey|GL_Office.OfficeClass = 'Denovo'|Measure.Financials_Value < 0
						SET @SQLStatement = '
							INSERT INTO #BR01_FACT
								(
								[InitialStepID],
								[Account_MemberKey],
								[Currency_MemberKey],
								[Entity_MemberKey],
								[GL_Future_Use_MemberKey],
								[GL_Matrix_MemberKey],
								[GL_Office_MemberKey],
								[GL_PC_MemberKey],
								[Scenario_MemberKey],
								[Time_MemberKey],
								[Financials_Value]
								)
							SELECT 
								[InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ',
								[Account] = ''' + @MemberKey + ''',
								[Currency],
								[Entity],
								[GL_Future_Use],
								[GL_Matrix],
								[GL_Office],
								[GL_PC],
								[Scenario],
								[Time],
								[Financials_Value] = SUM(V.[Financials_Value])
							FROM
								[pcDATA_HD].[dbo].[FACT_Financials_View] V
--								INNER JOIN [pcDATA_HD].[dbo].[S_DS_GL_Office] GL_Office ON GL_Office.Label = V.GL_Office AND CONVERT(int, GL_Office.StartMonth) + 100 >= CONVERT(int, V.Time) AND GL_Office.OfficeClass = ''Denovo''
							WHERE
								V.[Account] IN (' + @LeafLevelFilter + ') AND
								V.[BusinessRule] = ''NONE'' AND
								V.[Time] BETWEEN ''' + CONVERT(nvarchar(10), CASE WHEN @ModifierID IN (30) THEN (SELECT pcINTEGRATOR.[dbo].[Get_BR_Modifier] (@ModifierID, @FromTime, @Parameter)) ELSE @FromTime END) + ''' AND ''' + CONVERT(nvarchar(10), CASE WHEN @ModifierID IN (30) THEN (SELECT pcINTEGRATOR.[dbo].[Get_BR_Modifier] (@ModifierID, @ToTime, @Parameter)) ELSE @ToTime END) + ''' AND
								ISNUMERIC(V.[Time]) <> 0 AND
								V.[Scenario] IN (''ACTUAL'') AND
								V.[Version] = ''NONE'' AND
								V.[TimeDataView] = ''RAWDATA''
							GROUP BY
								[Currency],
								[Entity],
								[GL_Future_Use],
								[GL_Matrix],
								[GL_Office],
								[GL_PC],
								[Scenario],
								[Time]
--							HAVING
--								SUM(V.[Financials_Value]) < 0'
*/
					ELSE
						SET @SQLStatement = '
							INSERT INTO #BR01_FACT
								(
								[InitialStepID],
								[Account_MemberKey],
								[Currency_MemberKey],
								[Entity_MemberKey],
								[GL_Future_Use_MemberKey],
								[GL_Matrix_MemberKey],
								[GL_Office_MemberKey],
								[GL_PC_MemberKey],
								[Scenario_MemberKey],
								[Time_MemberKey],
								[Financials_Value]
								)
							SELECT 
								[InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ',
								[Account] = ''' + @MemberKey + ''',
								[Currency],
								[Entity],
								[GL_Future_Use],
								[GL_Matrix],
								[GL_Office],
								[GL_PC],
								[Scenario],
	--							[Time] = ' + CASE WHEN @ModifierID IN (30) THEN 'CONVERT(nvarchar(10), pcINTEGRATOR.[dbo].[Get_BR_Modifier] (' + CONVERT(nvarchar(10), @ModifierID) + ', V.[Time], ' + CONVERT(nvarchar(10), @Parameter * -1) + '))' ELSE 'V.[Time]' END + ',
								[Time],
								[Financials_Value] = SUM(V.[Financials_Value]) ' + CASE @ModifierID WHEN 10 THEN ' * ' + CONVERT(nvarchar(10), @Parameter) WHEN 20 THEN ' / ' + CONVERT(nvarchar(10), @Parameter) ELSE '' END + '
							FROM
								[pcDATA_HD].[dbo].[FACT_Financials_View] V
							WHERE
	--							V.[Account] = ''' + @MemberKey + ''' AND
								V.[Account] IN (' + @LeafLevelFilter + ') AND
								V.[BusinessRule] = ''NONE'' AND
								V.[Time] BETWEEN ''' + CONVERT(nvarchar(10), CASE WHEN @ModifierID IN (30) THEN (SELECT pcINTEGRATOR.[dbo].[Get_BR_Modifier] (@ModifierID, @FromTime, @Parameter)) ELSE @FromTime END) + ''' AND ''' + CONVERT(nvarchar(10), CASE WHEN @ModifierID IN (30) THEN (SELECT pcINTEGRATOR.[dbo].[Get_BR_Modifier] (@ModifierID, @ToTime, @Parameter)) ELSE @ToTime END) + ''' AND
								ISNUMERIC(V.[Time]) <> 0 AND
								V.[Scenario] IN (''ACTUAL'') AND
								V.[Version] = ''NONE'' AND
								V.[TimeDataView] = ''RAWDATA''
							GROUP BY
								[Currency],
								[Entity],
								[GL_Future_Use],
								[GL_Matrix],
								[GL_Office],
								[GL_PC],
								[Scenario],
								[Time]'

					IF @Debug <> 0 AND LEN(@SQLStatement) > 4000 
						BEGIN
							SET @Comment = '@BR01_StepID = ' + CONVERT(nvarchar(10), @BR01_StepID) + ', @InitialStepID = ' + CONVERT(nvarchar(10), @InitialStepID)
							PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; ' + @Comment
							EXEC [pcINTEGRATOR].[dbo].[spSet_wrk_Debug]
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@DatabaseName = 'pcINTEGRATOR',
								@CalledProcedureName = @ProcedureName,
								@Comment = @Comment, 
								@SQLStatement = @SQLStatement
						END
					ELSE IF @Debug <> 0
						PRINT @SQLStatement

					EXEC (@SQLStatement)

					FETCH NEXT FROM BR01_Base_Cursor INTO @BR01_StepID, @InitialStepID, @MemberKey, @ModifierID, @Parameter, @DataClassID, @DimensionFilter
				END

		CLOSE BR01_Base_Cursor
		DEALLOCATE BR01_Base_Cursor

		IF @Debug <> 0 SELECT TempTable = '#BR01_FACT', * FROM #BR01_FACT

		--SELECT Account_MemberKey, SUM(Financials_Value) FROM #BR01_FACT WHERE Account_MemberKey IN ('260020', '260021', '130002', '260031') GROUP BY Account_MemberKey

	SET @Step = 'Run destination cursor'
		DECLARE BR01_Destination_Cursor CURSOR FOR
			
			SELECT
				[BR01_StepID] = S.[BR01_StepID],
				[DestinationMemberKey] = MAX(CASE WHEN S.BR01_StepPartID = -1 THEN S.[MemberKey] ELSE NULL END),
				[ModifierID] = MAX(CASE WHEN S.BR01_StepPartID = -1 THEN S.[ModifierID] ELSE NULL END),
				[Parameter] = MAX(CASE WHEN S.BR01_StepPartID = -1 THEN S.[Parameter] ELSE NULL END),
				[Decimal] = MAX(CASE WHEN S.BR01_StepPartID = -1 THEN S.[Decimal] ELSE NULL END),
				[MasterMemberKey] = MAX(CASE WHEN S.BR01_StepPartID = 0 THEN S.[MemberKey] ELSE NULL END),
				[InitialStepID] = MAX(CASE WHEN S.BR01_StepPartID = 0 THEN [IS].[InitialStepID] ELSE NULL END)
			FROM 
				BR01_Step S
				LEFT JOIN #InitialStep [IS] ON [IS].[MemberKey] = S.[MemberKey] AND ISNULL([IS].[ModifierID], 0) = ISNULL(S.[ModifierID], 0) AND ISNULL([IS].[Parameter], 0) = ISNULL(S.[Parameter], 0) AND ISNULL([IS].[DimensionFilter], '') = ISNULL(S.[DimensionFilter],'')
			WHERE
				S.InstanceID = @InstanceID AND
				S.VersionID = @VersionID AND
				S.[BusinessRuleID] = @BR_ID AND
				S.[BR01_StepPartID] IN (-1, 0)
			GROUP BY
				S.[BR01_StepID]
			ORDER BY
				S.[BR01_StepID]

			OPEN BR01_Destination_Cursor
			FETCH NEXT FROM BR01_Destination_Cursor INTO @BR01_StepID, @DestinationMemberKey, @ModifierID, @Parameter, @Decimal, @MasterMemberKey, @InitialStepID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT
									[BR01_StepID] = @BR01_StepID,
									[DestinationMemberKey] = @DestinationMemberKey,
									[ModifierID] = @ModifierID,
									[Parameter] = @Parameter,
									[Decimal] = @Decimal,
									[MasterMemberKey] = @MasterMemberKey,
									[InitialStepID] = @InitialStepID

					SET @SQLStatement = '
						INSERT INTO #BR01_FACT
							(
							[Account_MemberKey],
							[Currency_MemberKey],
							[Entity_MemberKey],
							[GL_Future_Use_MemberKey],
							[GL_Matrix_MemberKey],
							[GL_Office_MemberKey],
							[GL_PC_MemberKey],
							[Scenario_MemberKey],
							[Time_MemberKey],
							[Financials_Value]
							)
						SELECT 
							[Account_MemberKey] = ''' + @DestinationMemberKey + ''',
							[Currency_MemberKey],
							[Entity_MemberKey],
							[GL_Future_Use_MemberKey],
							[GL_Matrix_MemberKey],
							[GL_Office_MemberKey],
							[GL_PC_MemberKey],
							[Scenario_MemberKey],
							[Time_MemberKey],
							[Financials_Value]
						FROM
							#BR01_FACT F
						WHERE
							F.[Account_MemberKey] = ''' + @MasterMemberKey + ''' AND
							(F.[InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ' OR ''' + CONVERT(nvarchar(10), ISNULL(@InitialStepID, 0)) + ''' = ''0'')'

					IF @Debug <> 0 PRINT '[BR01_StepID] = ' + CONVERT(nvarchar(10), @BR01_StepID) + ', [DestinationMemberKey] = ' + @DestinationMemberKey+ ', [Decimal] = ' + CONVERT(nvarchar(10), @Decimal) + ', [MasterMemberKey] = ' + @MasterMemberKey + ', [InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID)
					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @BR01_StepPartID = 1

					WHILE @BR01_StepPartID <= (SELECT MAX(BR01_StepPartID) FROM BR01_Step S WHERE S.BusinessRuleID = @BR_ID AND S.[BR01_StepID] = @BR01_StepID)
						BEGIN
							SELECT
								@MemberKey = S.[MemberKey],
								@Operator = S.[Operator],
								@InitialStepID = [IS].[InitialStepID]
							FROM
								BR01_Step S
								LEFT JOIN #InitialStep [IS] ON [IS].[MemberKey] = S.[MemberKey] AND ISNULL([IS].[ModifierID], 0) = ISNULL(S.[ModifierID], 0) AND ISNULL([IS].[Parameter], 0) = ISNULL(S.[Parameter], 0) AND ISNULL([IS].[DimensionFilter], '') = ISNULL(S.[DimensionFilter],'')
							WHERE
								S.BusinessRuleID = @BR_ID AND 
								S.[BR01_StepID] = @BR01_StepID AND 
								S.BR01_StepPartID = @BR01_StepPartID

							IF @Debug <> 0 SELECT [BR01_StepPartID] = @BR01_StepPartID, [MemberKey] = @MemberKey, [InitialStepID] = @InitialStepID, [Operator] = @Operator
							IF @Debug <> 0 PRINT '[BR01_StepPartID] = ' + CONVERT(nvarchar(10), @BR01_StepPartID) + ', [MemberKey] = ' + @MemberKey + ', [InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ', [Operator] = ' + @Operator

							TRUNCATE TABLE #BR01_FACT_Step
							INSERT INTO #BR01_FACT_Step
								(
								[Account_MemberKey],
								[Currency_MemberKey],
								[Entity_MemberKey],
								[GL_Future_Use_MemberKey],
								[GL_Matrix_MemberKey],
								[GL_Office_MemberKey],
								[GL_PC_MemberKey],
								[Scenario_MemberKey],
								[Time_MemberKey],
								[Financials_Value]
								)
							SELECT
								[Account_MemberKey],
								[Currency_MemberKey],
								[Entity_MemberKey],
								[GL_Future_Use_MemberKey],
								[GL_Matrix_MemberKey],
								[GL_Office_MemberKey],
								[GL_PC_MemberKey],
								[Scenario_MemberKey],
								[Time_MemberKey],
								[Financials_Value]
							FROM
								#BR01_FACT
							WHERE
								[Account_MemberKey] = @DestinationMemberKey

							DELETE #BR01_FACT
							WHERE
								[Account_MemberKey] = @DestinationMemberKey

							IF @Operator IN ('*', '/')
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #BR01_FACT
											(
											[Account_MemberKey],
											[Currency_MemberKey],
											[Entity_MemberKey],
											[GL_Future_Use_MemberKey],
											[GL_Matrix_MemberKey],
											[GL_Office_MemberKey],
											[GL_PC_MemberKey],
											[Scenario_MemberKey],
											[Time_MemberKey],
											[Financials_Value]
											)
										SELECT
											[Account_MemberKey] = ''' + @DestinationMemberKey + ''',
											[Currency_MemberKey] = F.[Currency_MemberKey],
											[Entity_MemberKey] = F.[Entity_MemberKey],
											[GL_Future_Use_MemberKey] = F.[GL_Future_Use_MemberKey],
											[GL_Matrix_MemberKey] = F.[GL_Matrix_MemberKey],
											[GL_Office_MemberKey] = F.[GL_Office_MemberKey],
											[GL_PC_MemberKey] = F.[GL_PC_MemberKey],
											[Scenario_MemberKey] = F.[Scenario_MemberKey],
											[Time_MemberKey] = F.[Time_MemberKey],
											[Financials_Value] = F.[Financials_Value] ' + @Operator + ' OP.[Financials_Value]
										FROM
											#BR01_FACT_Step F
											INNER JOIN (
												SELECT
													[Currency_MemberKey],
													[Entity_MemberKey],
													[GL_Future_Use_MemberKey],
													[GL_Matrix_MemberKey],
													[GL_Office_MemberKey],
													[GL_PC_MemberKey],
													[Scenario_MemberKey],
													[Time_MemberKey],
													[Financials_Value]
												FROM
													#BR01_FACT
												WHERE
													[Account_MemberKey] = ''' + @MemberKey + ''' AND
													([InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ' OR ''' + CONVERT(nvarchar(10), ISNULL(@InitialStepID, 0)) + ''' = ''0'') AND
													[Financials_Value] <> 0
													) OP ON
--														OP.[Currency_MemberKey] = F.[Currency_MemberKey] AND
														OP.[Entity_MemberKey] = F.[Entity_MemberKey] AND
														OP.[GL_Future_Use_MemberKey] = F.[GL_Future_Use_MemberKey] AND
														OP.[GL_Matrix_MemberKey] = F.[GL_Matrix_MemberKey] AND
														OP.[GL_Office_MemberKey] = F.[GL_Office_MemberKey] AND
														OP.[GL_PC_MemberKey] = F.[GL_PC_MemberKey] AND
														OP.[Scenario_MemberKey] = F.[Scenario_MemberKey] AND
														OP.[Time_MemberKey] = F.[Time_MemberKey]
										WHERE
											F.[Account_MemberKey] = ''' + @DestinationMemberKey + ''''

									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END
							ELSE IF @Operator IN ('+', '-')
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #BR01_FACT
											(
											[Account_MemberKey],
											[Currency_MemberKey],
											[Entity_MemberKey],
											[GL_Future_Use_MemberKey],
											[GL_Matrix_MemberKey],
											[GL_Office_MemberKey],
											[GL_PC_MemberKey],
											[Scenario_MemberKey],
											[Time_MemberKey],
											[Financials_Value]
											)
										SELECT
											[Account_MemberKey] = ''' + @DestinationMemberKey + ''',
											[Currency_MemberKey] = M.[Currency_MemberKey],
											[Entity_MemberKey] = M.[Entity_MemberKey],
											[GL_Future_Use_MemberKey] = M.[GL_Future_Use_MemberKey],
											[GL_Matrix_MemberKey] = M.[GL_Matrix_MemberKey],
											[GL_Office_MemberKey] = M.[GL_Office_MemberKey],
											[GL_PC_MemberKey] = M.[GL_PC_MemberKey],
											[Scenario_MemberKey] = M.[Scenario_MemberKey],
											[Time_MemberKey] = M.[Time_MemberKey],
											[Financials_Value] = ISNULL(F.[Financials_Value], 0) ' + @Operator + ' ISNULL(OP.[Financials_Value], 0)
										FROM
											(
											SELECT DISTINCT
												[Currency_MemberKey],
												[Entity_MemberKey],
												[GL_Future_Use_MemberKey],
												[GL_Matrix_MemberKey],
												[GL_Office_MemberKey],
												[GL_PC_MemberKey],
												[Scenario_MemberKey],
												[Time_MemberKey]
											FROM
												#BR01_FACT_Step
											UNION SELECT DISTINCT
												[Currency_MemberKey],
												[Entity_MemberKey],
												[GL_Future_Use_MemberKey],
												[GL_Matrix_MemberKey],
												[GL_Office_MemberKey],
												[GL_PC_MemberKey],
												[Scenario_MemberKey],
												[Time_MemberKey]
											FROM
												#BR01_FACT
											WHERE
												[Account_MemberKey] = ''' + @MemberKey + ''' AND
												([InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ' OR ''' + CONVERT(nvarchar(10), ISNULL(@InitialStepID, 0)) + ''' = ''0'')
											) M
											LEFT JOIN #BR01_FACT_Step F ON
--												F.[Currency_MemberKey] = M.[Currency_MemberKey] AND
												F.[Entity_MemberKey] = M.[Entity_MemberKey] AND
												F.[GL_Future_Use_MemberKey] = M.[GL_Future_Use_MemberKey] AND
												F.[GL_Matrix_MemberKey] = M.[GL_Matrix_MemberKey] AND
												F.[GL_Office_MemberKey] = M.[GL_Office_MemberKey] AND
												F.[GL_PC_MemberKey] = M.[GL_PC_MemberKey] AND
												F.[Scenario_MemberKey] = M.[Scenario_MemberKey] AND
												F.[Time_MemberKey] = M.[Time_MemberKey]
											LEFT JOIN #BR01_FACT OP ON
												OP.[Account_MemberKey] = ''' + @MemberKey + ''' AND
--												OP.[Currency_MemberKey] = M.[Currency_MemberKey] AND
												OP.[Entity_MemberKey] = M.[Entity_MemberKey] AND
												OP.[GL_Future_Use_MemberKey] = M.[GL_Future_Use_MemberKey] AND
												OP.[GL_Matrix_MemberKey] = M.[GL_Matrix_MemberKey] AND
												OP.[GL_Office_MemberKey] = M.[GL_Office_MemberKey] AND
												OP.[GL_PC_MemberKey] = M.[GL_PC_MemberKey] AND
												OP.[Scenario_MemberKey] = M.[Scenario_MemberKey] AND
												OP.[Time_MemberKey] = M.[Time_MemberKey] AND
												([InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ' OR ''' + CONVERT(nvarchar(10), ISNULL(@InitialStepID, 0)) + ''' = ''0'')'

									IF @Debug <> 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END

							SET @BR01_StepPartID = @BR01_StepPartID + 1
						END

						IF @ModifierID = 10
							UPDATE #BR01_FACT
							SET
								Financials_Value = Financials_Value * @Parameter
							WHERE
								Account_MemberKey = @DestinationMemberKey

						ELSE IF @ModifierID = 20
							UPDATE #BR01_FACT
							SET
								Financials_Value = Financials_Value / @Parameter
							WHERE
								Account_MemberKey = @DestinationMemberKey
					
					FETCH NEXT FROM BR01_Destination_Cursor INTO @BR01_StepID, @DestinationMemberKey, @ModifierID, @Parameter, @Decimal, @MasterMemberKey, @InitialStepID
				END

		CLOSE BR01_Destination_Cursor
		DEALLOCATE BR01_Destination_Cursor


		-- DELETE/INSERT DataClass

		IF @Debug <> 0 SELECT TempTable = '#BR01_FACT', * FROM #BR01_FACT WHERE [InitialStepID] IS NULL ORDER BY Account_MemberKey, Time_MemberKey

	SET @Step = 'Write back to FACT table'
--		DROP TABLE tmp_BR01_FACT
--		SELECT * INTO tmp_BR01_FACT FROM #BR01_FACT WHERE [InitialStepID] IS NULL

		--Delete existing records from FACT table
		SELECT
			[Account_MemberId] = A.[MemberId],
			[Account_MemberKey] = F.[Account_MemberKey]
		INTO
			#Account
		FROM
			[pcDATA_HD].[dbo].[S_DS_Account] A
			INNER JOIN (SELECT DISTINCT [Account_MemberKey] FROM #BR01_FACT WHERE [InitialStepID] IS NULL) F ON F.[Account_MemberKey] = A.[Label]

		IF @Debug <> 0 SELECT TempTable = '#Account', * FROM #Account ORDER BY [Account_MemberKey]

		DELETE F
		FROM
			[pcDATA_HD].[dbo].[FACT_Financials_default_partition] F
			INNER JOIN #Account A ON A.[Account_MemberId] = F.[Account_MemberId]
		WHERE
			F.Time_MemberId BETWEEN @FromTime AND @ToTime

		SET @Deleted = @Deleted + @@ROWCOUNT

		--Insert new records into FACT table

		--BusinessProcess=INPUT|BusinessRule=NONE|TimeDataview=RAWDATA|Version=NONE|WorkflowState=NONE

		INSERT INTO [pcDATA_HD].[dbo].[FACT_Financials_default_partition]
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
			[WorkflowState_MemberId],
			[GL_Future_Use_MemberId],
			[GL_Matrix_MemberId],
			[GL_Office_MemberId],
			[GL_PC_MemberId],
			[GL_Posted_MemberId],
			[ChangeDatetime],
			[Userid],
			[Financials_Value]
			)
		SELECT
			[Account_MemberId] = ISNULL([Account].[MemberId], -1),
			[BusinessProcess_MemberId] = 149,
			[BusinessRule_MemberId] = -1,
			[Currency_MemberId] = ISNULL([Currency].[MemberId], -1),
			[Entity_MemberId] = ISNULL([Entity].[MemberId], -1),
			[Scenario_MemberId] = ISNULL([Scenario].[MemberId], -1),
			[Time_MemberId] = ISNULL([Time].[MemberId], -1),
			[TimeDataView_MemberId] = 101,
			[Version_MemberId] = -1,
			[WorkflowState_MemberId] = -1,
			[GL_Future_Use_MemberId] = ISNULL([GL_Future_Use].[MemberId], -1),
			[GL_Matrix_MemberId] = ISNULL([GL_Matrix].[MemberId], -1),
			[GL_Office_MemberId] = ISNULL([GL_Office].[MemberId], -1),
			[GL_PC_MemberId] = ISNULL([GL_PC].[MemberId], -1),
			[GL_Posted_MemberId] = 101,
			[ChangeDatetime] = GetDate(),
			[Userid] = suser_name(),
			[Financials_Value] = [Raw].[Financials_Value]
		FROM
			#BR01_FACT [Raw]
			LEFT JOIN [pcDATA_HD].[dbo].[S_DS_Account] [Account] ON [Account].Label COLLATE DATABASE_DEFAULT = [Raw].[Account_MemberKey]
			LEFT JOIN [pcDATA_HD].[dbo].[S_DS_Currency] [Currency] ON [Currency].Label COLLATE DATABASE_DEFAULT = [Raw].[Currency_MemberKey]
			LEFT JOIN [pcDATA_HD].[dbo].[S_DS_Entity] [Entity] ON [Entity].Label COLLATE DATABASE_DEFAULT = [Raw].[Entity_MemberKey]
			LEFT JOIN [pcDATA_HD].[dbo].[S_DS_Scenario] [Scenario] ON [Scenario].Label COLLATE DATABASE_DEFAULT = [Raw].[Scenario_MemberKey]
			LEFT JOIN [pcDATA_HD].[dbo].[S_DS_Time] [Time] ON [Time].Label COLLATE DATABASE_DEFAULT = [Raw].[Time_MemberKey]
			LEFT JOIN [pcDATA_HD].[dbo].[S_DS_GL_Future_Use] [GL_Future_Use] ON [GL_Future_Use].Label COLLATE DATABASE_DEFAULT = [Raw].[GL_Future_Use_MemberKey]
			LEFT JOIN [pcDATA_HD].[dbo].[S_DS_GL_Matrix] [GL_Matrix] ON [GL_Matrix].Label COLLATE DATABASE_DEFAULT = [Raw].[GL_Matrix_MemberKey]
			LEFT JOIN [pcDATA_HD].[dbo].[S_DS_GL_Office] [GL_Office] ON [GL_Office].Label COLLATE DATABASE_DEFAULT = [Raw].[GL_Office_MemberKey]
			LEFT JOIN [pcDATA_HD].[dbo].[S_DS_GL_PC] [GL_PC] ON [GL_PC].Label COLLATE DATABASE_DEFAULT = [Raw].[GL_PC_MemberKey]
		WHERE
			[Raw].[InitialStepID] IS NULL
			--AND [Time].[MemberId] BETWEEN @FromTime AND @ToTime

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Drop temp tables'
		DROP TABLE #InitialStep
		DROP TABLE #BR01_FACT
		DROP TABLE #BR01_FACT_Step

	SET @Step = 'Run PostExec'
		--Add security check (Correct InstanceID)
		IF @PostExec IS NOT NULL
			EXEC (@PostExec)

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
