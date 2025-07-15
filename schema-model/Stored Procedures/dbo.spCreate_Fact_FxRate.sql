SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Fact_FxRate] 

	@ApplicationID int = NULL,
	@SourceID_varchar nvarchar(50) = NULL,
	@TempTableName nvarchar(100) = NULL,
	@ModelName nvarchar(100) = NULL,
	@DestinationDatabase nvarchar(100) = NULL,
	@SourceTypeFamilyID int = NULL,
	@SQLStatement_SelectID nvarchar(4000) = NULL,
	@SQLStatement_DimJoin nvarchar(max) = NULL,
	@StartYear int = NULL,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@SQLStatement nvarchar(max) = NULL OUT

--#WITH ENCRYPTION#--

AS

DECLARE
	@StartDay int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2085' SET @Description = 'Procedure created'
		IF @Version = '1.3.2091' SET @Description = 'Fixed Entity bug and added some debug info'
		IF @Version = '1.3.2093' SET @Description = 'Fixed bug when initial rate is missing'
		IF @Version = '1.3.2100' SET @Description = 'Fixed bugs for Enterprise'
		IF @Version = '1.3.2101' SET @Description = 'Added BusinessRule dimension'
		IF @Version = '1.3.2104' SET @Description = 'Added MasterEntity handling'
		IF @Version = '1.3.2110' SET @Description = 'Handle ReportingCurrency for MasterEntity.'
		IF @Version = '1.3.2111' SET @Description = 'Handle ReportingCurrency for all selected Entities.'
		IF @Version = '1.3.2112' SET @Description = 'Rename ReportingCurrency to BaseCurrency.'
		IF @Version = '1.4.0.2139' SET @Description = 'Brackets around view name.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @SourceID_varchar IS NULL
	BEGIN
		PRINT 'Parameter @SourceID_varchar must be set'
		RETURN 
	END

--Set procedure variables
	SELECT
		@StartDay = CASE WHEN FiscalYearStartMonth = 1 THEN @StartYear ELSE @StartYear - 1 END * 10000 + FiscalYearStartMonth * 100 + 1 
	FROM
		[Application]
	WHERE
		ApplicationID = @ApplicationID

IF @Debug <> 0
	SELECT
		ApplicationID = @ApplicationID,
		SourceID_varchar = @SourceID_varchar,
		TempTableName = @TempTableName,
		ModelName = @ModelName,
		DestinationDatabase = @DestinationDatabase,
		SQLStatement_SelectID = @SQLStatement_SelectID,
		SQLStatement_DimJoin = @SQLStatement_DimJoin,
		StartYear = @StartYear,
		StartDate = @StartDay

--€£Account£€

	IF @SourceTypeFamilyID IN (1, 3)

		SET @SQLStatement = '

	SET @Step = ''''Set procedure variables''''
		SELECT @Entity = Label FROM ' + @DestinationDatabase + '.[dbo].S_DS_€£Entity£€ WHERE MemberID = @Entity_MemberID'

	ELSE
		SET @SQLStatement = ''

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create Month level temp table''''
		SELECT
			MonthID = Label 
		INTO
			#Month 			
		FROM
			' + @DestinationDatabase + '.dbo.S_DS_€£Time£€
 		WHERE
			ISNUMERIC(Label) <> 0 AND
			LEN(Label) = 6 AND
			CONVERT(int, LEFT(Label, 4)) <= YEAR(GetDate())
		ORDER BY
			Label

		IF @Debug <> 0 SELECT [Table] = ''''#Month'''', * FROM #Month

	SET @Step = ''''Create Day level temp table''''

		CREATE TABLE #Day
			(
			DayID int,
			[DayName] nvarchar(100)
			)

	SET @Step = ''''Cursor for creating days''''
		DECLARE Create_Day_Cursor CURSOR FOR

		SELECT MonthID FROM #Month ORDER BY MonthID

		OPEN Create_Day_Cursor

		FETCH NEXT FROM Create_Day_Cursor INTO @Month

		WHILE @@FETCH_STATUS = 0
			BEGIN
				INSERT INTO #Day (DayID, [DayName]) EXEC sp_AddDays @Month

				FETCH NEXT FROM Create_Day_Cursor INTO @Month
			END

		CLOSE Create_Day_Cursor
		DEALLOCATE Create_Day_Cursor
		
		IF @Debug <> 0 SELECT [Table] = ''''#Day'''', * FROM #Day'

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Handle ANSI_WARNINGS''''
		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = ''''Create temp table for FxRates on every specific day''''

		SELECT
			D.[DayID],
			V.[€£BusinessRule£€],
			V.[€£Currency£€],
			V.[€£Entity£€],
			V.[€£BaseCurrency£€],
			V.[€£Scenario£€],
			V.[€£Simulation£€],
			[€£TimeDay£€] = MAX(V.[€£TimeDay£€])
		INTO
			#DayMax
		FROM
			[' + CASE @SourceTypeFamilyID WHEN 2 THEN 'tmp_Model_Raw' ELSE 'vw_' + @SourceID_varchar + '_FACT_€£FxRate£€_Raw' END + '] V
			INNER JOIN (
				SELECT
					V.[€£BusinessRule£€],
					V.[€£Currency£€],
					V.[€£Entity£€],
					V.[€£BaseCurrency£€],
					V.[€£Scenario£€],
					V.[€£Simulation£€],
					[€£TimeDay£€] = ISNULL(MAX(sub2.[€£TimeDay£€]), MIN(V.[€£TimeDay£€]))
				FROM
					[' + CASE @SourceTypeFamilyID WHEN 2 THEN 'tmp_Model_Raw' ELSE 'vw_' + @SourceID_varchar + '_FACT_€£FxRate£€_Raw' END + '] V
					LEFT JOIN (
						SELECT
							V.[€£BusinessRule£€],
							V.[€£Currency£€],
							V.[€£Entity£€],
							V.[€£BaseCurrency£€],
							V.[€£Scenario£€],
							V.[€£Simulation£€],
							[€£TimeDay£€] = MAX(V.[€£TimeDay£€])
						FROM
							[' + CASE @SourceTypeFamilyID WHEN 2 THEN 'tmp_Model_Raw' ELSE 'vw_' + @SourceID_varchar + '_FACT_€£FxRate£€_Raw' END + '] V
						WHERE
							V.[€£TimeDay£€] <= ' + CONVERT(nvarchar(10), @StartDay) + '
						GROUP BY
							V.[€£BusinessRule£€],
							V.[€£Currency£€],
							V.[€£Entity£€],
							V.[€£BaseCurrency£€],
							V.[€£Scenario£€],
							V.[€£Simulation£€]
						) sub2 ON	sub2.[€£BusinessRule£€] = V.[€£BusinessRule£€] AND
									sub2.[€£Currency£€] = V.[€£Currency£€] AND
									sub2.[€£Entity£€] = V.[€£Entity£€] AND
									sub2.[€£BaseCurrency£€] = V.[€£BaseCurrency£€] AND
									sub2.[€£Scenario£€] = V.[€£Scenario£€] AND
									sub2.[€£Simulation£€] = V.[€£Simulation£€]
				GROUP BY
					V.[€£BusinessRule£€],
					V.[€£Currency£€],
					V.[€£Entity£€],
					V.[€£BaseCurrency£€],
					V.[€£Scenario£€],
					V.[€£Simulation£€]
				) sub ON	sub.[€£BusinessRule£€] = V.[€£BusinessRule£€] AND
							sub.[€£Currency£€] = V.[€£Currency£€] AND
							sub.[€£Entity£€] = V.[€£Entity£€] AND
							sub.[€£BaseCurrency£€] = V.[€£BaseCurrency£€] AND
							sub.[€£Scenario£€] = V.[€£Scenario£€] AND
							sub.[€£Simulation£€] = V.[€£Simulation£€] AND
							sub.[€£TimeDay£€] <= V.[€£TimeDay£€]
			INNER JOIN #Day D ON D.[DayID] >= V.[€£TimeDay£€]
		WHERE
			V.[€£Entity£€] = @Entity ' + CASE WHEN @SourceTypeFamilyID IN (1, 3) THEN 'OR @Entity_MemberId = -10' ELSE '' END + ' 
		GROUP BY
			D.[DayID],
			V.[€£BusinessRule£€],
			V.[€£Currency£€],
			V.[€£Entity£€],
			V.[€£BaseCurrency£€],
			V.[€£Scenario£€],
			V.[€£Simulation£€]'

	SET @SQLStatement = @SQLStatement + '

		IF @Debug <> 0 SELECT [Table] = ''''#DayMax'''', * FROM #DayMax

		SELECT
			DM.[DayID],
			V.[€£BusinessRule£€],
			V.[€£Currency£€],
			V.[€£Entity£€],
			V.[€£BaseCurrency£€],
			V.[€£Scenario£€],
			V.[€£Simulation£€],
			V.[€£FxRate£€_Value]
		INTO
			#FxRate_Day
		FROM
			[' + CASE @SourceTypeFamilyID WHEN 2 THEN 'tmp_Model_Raw' ELSE 'vw_' + @SourceID_varchar + '_FACT_€£FxRate£€_Raw' END + '] V
			INNER JOIN #DayMax DM ON 
						DM.[€£BusinessRule£€] = V.[€£BusinessRule£€] AND
						DM.[€£Currency£€] =	V.[€£Currency£€] AND 
						DM.[€£Entity£€] = V.[€£Entity£€] AND 
						DM.[€£BaseCurrency£€] = V.[€£BaseCurrency£€] AND 
						DM.[€£Scenario£€] = V.[€£Scenario£€] AND 
						DM.[€£Simulation£€] = V.[€£Simulation£€] AND 
						DM.[€£TimeDay£€] = V.[€£TimeDay£€]
		WHERE
			V.[€£Entity£€] = @Entity ' + CASE WHEN @SourceTypeFamilyID IN (1, 3) THEN 'OR @Entity_MemberId = -10' ELSE '' END + ' 
		ORDER BY
			DM.[DayID],
			V.[€£BusinessRule£€],
			V.[€£Currency£€],
			V.[€£Entity£€],
			V.[€£BaseCurrency£€],
			V.[€£Scenario£€],
			V.[€£Simulation£€]

		IF @Debug <> 0 SELECT [Table] = ''''#FxRate_Day'''', * FROM #FxRate_Day

		SET ANSI_WARNINGS OFF

	SET @Step = ''''Create temp table for FxRates on Month level''''

		SELECT
			[€£BusinessRule£€],
			[€£Currency£€],
			[€£Entity£€],
			[€£Rate£€],
			[€£BaseCurrency£€],
			[€£Scenario£€],
			[€£Simulation£€],
			[€£Time£€],
			[€£FxRate£€_Value]
		INTO
			#FxRate_Raw
		FROM
			(
			SELECT
				[€£Time£€] = CONVERT(nvarchar(100), [DayID] / 100),
				[€£BusinessRule£€],
				[€£Currency£€],
				[€£Entity£€],
				[€£BaseCurrency£€],
				[€£Scenario£€],
				[€£Simulation£€],
				[€£Rate£€] = ''''Average'''',
				[€£FxRate£€_Value] = AVG([€£FxRate£€_Value])
			FROM
				#FxRate_Day
			GROUP BY
				[DayID] / 100,
				[€£BusinessRule£€],
				[€£Currency£€],
				[€£Entity£€],
				[€£BaseCurrency£€],
				[€£Scenario£€],
				[€£Simulation£€]

			UNION SELECT
				[€£Time£€] = CONVERT(nvarchar(100), sub.[€£Time£€]),
				[€£BusinessRule£€],
				[€£Currency£€],
				[€£Entity£€],
				[€£BaseCurrency£€],
				[€£Scenario£€],
				[€£Simulation£€],
				[€£Rate£€] = ''''EOP'''',
				[€£FxRate£€_Value]
			FROM
				#FxRate_Day T
				INNER JOIN (SELECT [€£Time£€] = [DayID] / 100, [DayID] = MAX([DayID]) FROM #Day GROUP BY [DayID] / 100) sub ON sub.[DayID] = T.[DayID]
			) sub'

	SET @SQLStatement = @SQLStatement + '
			
	SET @Step = ''''Handle MasterEntity and BaseCurrency''''
		SELECT TOP 1
			@MasterEntity = E.Entity
		FROM
			Entity E
			INNER JOIN #FxRate_Raw R ON R.[€£Entity£€] = E.[Entity]
			INNER JOIN (SELECT EntityPriority = MIN(EntityPriority) FROM Entity WHERE SourceID = @SourceID) EP ON EP.EntityPriority = E.EntityPriority
		WHERE
			E.SourceID = @SourceID AND
			E.SelectYN <> 0
		ORDER BY
			E.Entity

		INSERT INTO #FxRate_Raw
			(
			[€£BusinessRule£€],
			[€£Currency£€],
			[€£Entity£€],
			[€£Rate£€],
			[€£BaseCurrency£€],
			[€£Scenario£€],
			[€£Simulation£€],
			[€£Time£€],
			[€£FxRate£€_Value]
			)
		SELECT
			[€£BusinessRule£€],
			[€£Currency£€],
			[€£Entity£€] = ''''NONE'''',
			[€£Rate£€],
			[€£BaseCurrency£€],
			[€£Scenario£€],
			[€£Simulation£€],
			[€£Time£€],
			[€£FxRate£€_Value]
		FROM
			#FxRate_Raw
		WHERE
			[€£Entity£€] = @MasterEntity

		INSERT INTO #FxRate_Raw
			(
			[€£BusinessRule£€],
			[€£Currency£€],
			[€£Entity£€],
			[€£Rate£€],
			[€£BaseCurrency£€],
			[€£Scenario£€],
			[€£Simulation£€],
			[€£Time£€],
			[€£FxRate£€_Value]
			)
		SELECT DISTINCT
			[€£BusinessRule£€] = S.[€£BusinessRule£€],
			[€£Currency£€] = S.[€£BaseCurrency£€],
			[€£Entity£€] = S.[€£Entity£€],
			[€£Rate£€] = S.[€£Rate£€],
			[€£BaseCurrency£€] = S.[€£BaseCurrency£€],
			[€£Scenario£€] = S.[€£Scenario£€],
			[€£Simulation£€] = S.[€£Simulation£€],
			[€£Time£€] = S.[€£Time£€],
			[€£FxRate£€_Value] = 1.0
		FROM
			#FxRate_Raw S
			LEFT JOIN
				(
				SELECT
					E.Entity
				FROM
					Entity E 
					INNER JOIN [pcINTEGRATOR].[dbo].[Source] S ON S.SourceID = E.SourceID AND S.SelectYN <> 0
					INNER JOIN [pcINTEGRATOR].[dbo].[Model] M ON M.ModelID = S.ModelID AND M.BaseModelID = -3 AND M.SelectYN <> 0
				WHERE
					E.SelectYN <> 0
				) E ON E.Entity = S.[€£Entity£€] OR S.[€£Entity£€] = ''''NONE''''
		WHERE
			NOT EXISTS (SELECT 1 FROM #FxRate_Raw T WHERE T.[Currency] = S.[BaseCurrency] AND T.[Entity] = S.[Entity] AND T.[Rate] = S.[Rate] AND T.[BaseCurrency] = S.[BaseCurrency] AND T.[Scenario] = S.[Scenario] AND T.[Time] = S.[Time])

		IF @Debug <> 0 SELECT [Table] = ''''#FxRate_Raw'''', * FROM #FxRate_Raw

	SET @Step = ''''Insert into temp table''''
		' + CASE @SourceTypeFamilyID WHEN 2 THEN 'IF @CalledYN <> 0 SET @SQLStatement = ''''INSERT INTO [' + @TempTableName + ']'''' ELSE SET @SQLStatement = ''''''''' ELSE 'SET @SQLStatement = ''''INSERT INTO [' + @TempTableName + ']''''' END + '
		SET @SQLStatement = @SQLStatement + ''''
		SELECT
			' + @SQLStatement_SelectID + '
		FROM
			#FxRate_Raw [Raw]
			' + @SQLStatement_DimJoin + '
		WHERE
			[Raw].[' + @ModelName + '_Value] <> 0.0''''

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Complete View with MemberID'''', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		'

		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''Drop temp tables''''
		' + CASE @SourceTypeFamilyID WHEN 2 THEN 'DROP TABLE #DimensionList' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'DROP TABLE #FieldList' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'DROP TABLE tmp_Model_Raw' ELSE '' END + '
		DROP TABLE #Month
		DROP TABLE #Day
		DROP TABLE #FxRate_Day
		DROP TABLE #FxRate_Raw
		DROP TABLE #DayMax'






GO
