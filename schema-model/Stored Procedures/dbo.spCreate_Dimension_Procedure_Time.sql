SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Dimension_Procedure_Time]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ApplicationID int = NULL,
	@Encryption smallint = 1,
	@SortOrder int = 0 OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000022,
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
--EXEC [spCreate_Dimension_Procedure_Time] @ApplicationID = 400, @Debug = true
--EXEC [spCreate_Dimension_Procedure_Time] @ApplicationID = 600, @Debug = true
--EXEC [spCreate_Dimension_Procedure_Time] @ApplicationID = 1317, @Debug = true

EXEC [spCreate_Dimension_Procedure_Time] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SourceDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@StartYear int,
	@ResetStartYear bit,
	@FiscalYearStartMonth int,
	@SQLStatement nvarchar(max),
	@DimensionID int,
	@DimensionName nvarchar(100),
	@Property nvarchar(100),
	@TimeYN bit,
	@TimeDayYN bit,
	@TimeWeekYN bit,
	@Action nvarchar(10),

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
	@Version nvarchar(50) = '2.0.1.2143'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create SPs for time',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2055' SET @Description = 'Add version handling in the created procedures.'
		IF @Version = '1.2.2061' SET @Description = 'Check that Sources and Models are selected when fetching base values.'
		IF @Version = '1.2.2068' SET @Description = 'SET ANSI_WARNINGS OFF.'
		IF @Version = '1.3.2073' SET @Description = 'Fixed selection of time properties.'
		IF @Version = '1.3.2074' SET @Description = 'Test on MemberId is not NULL in hierarchy creation.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2095' SET @Description = 'Added RNodeType'
		IF @Version = '1.3.2098' SET @Description = 'Create objects when @Debug is set'
		IF @Version = '1.3.2100' SET @Description = 'Fixed bug for FiscalYear when starts in January'
		IF @Version = '1.3.2101' SET @Description = 'Changed label on FiscalYear.'
		IF @Version = '1.3.2106' SET @Description = 'Handle Property SBZ.'
		IF @Version = '1.3.2107' SET @Description = 'Increased performance on DayLevel. Reset @StartYear for pcEXCHANGE.'
		IF @Version = '1.3.2109' SET @Description = 'Fixed MemberIDs for all Static Members.'
		IF @Version = '1.3.2110' SET @Description = 'Fixed MemberIDs for TimeYear, TimeFiscalYear, Time, TimeDay and TimeWeek. Number of digits: Year(4), Quarter(5), Month(6), Week(7), Day(8).'
		IF @Version = '1.3.2111' SET @Description = 'Fiscal hierarchy for TimeDay. Changed length of SQL-strings.'
		IF @Version = '1.3.2115' SET @Description = 'Added posibility to get reference data. Used by spFix_ChangedLabel. Changed RNodeType for Month Level in TimeDay to P.'
		IF @Version = '1.3.2116' SET @Description = 'Changed logging logic for spIU_0000_Time_Property.'
		IF @Version = '1.3.2117' SET @Description = 'Added HelpText.'
		IF @Version = '1.3.0.2118' SET @Description = 'Adjust @StartYear for pcExchange.'
		IF @Version = '1.3.1.2120' SET @Description = 'Include DayLevel and WeekLevel in TimeDay procedure. Removed from LoadTable.'
		IF @Version = '1.4.0.2135' SET @Description = 'Add Property NumberOfDays.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'

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

		SELECT
			@UserID = ISNULL(@UserID, -10),
			@InstanceID = ISNULL(@InstanceID, A.InstanceID),
			@VersionID = ISNULL(@VersionID, A.VersionID)
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID AND
			A.SelectYN <> 0

		SELECT
			@ApplicationID = ISNULL(@ApplicationID, A.ApplicationID)
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		SELECT
			@SourceDatabase = MAX(S.SourceDatabase),
			@ETLDatabase = A.ETLDatabase,
			@CallistoDatabase = A.DestinationDatabase,
			@StartYear = MIN(S.StartYear),
			@FiscalYearStartMonth = MAX(A.FiscalYearStartMonth),
			@TimeYN = CASE WHEN MIN(BM.TimeTypeBM) & 1 > 0 THEN 1 ELSE 0 END,
			@TimeDayYN = CASE WHEN MAX(BM.TimeTypeBM) & 2 > 0 THEN 1 ELSE 0 END,
			@TimeWeekYN = CASE WHEN MAX(BM.TimeTypeBM) & 4 > 0 AND MAX(A.FiscalYearStartMonth) = 1 THEN 1 ELSE 0 END
		FROM
			[Application] A
			INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN [Model] BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
		WHERE
			A.ApplicationID = @ApplicationID AND
			A.SelectYN <> 0
		GROUP BY
			A.ETLDatabase,
			A.DestinationDatabase

/*
		SELECT
			@ResetStartYear = CASE WHEN MinSourceTypeID = MaxSourceTypeID AND MinSourceTypeID = 6 THEN 1 ELSE 0 END
		FROM
			(
			SELECT 
				MinSourceTypeID = MIN(SourceTypeID),
				MaxSourceTypeID = MAX(SourceTypeID)
			FROM
				Source S
				INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
			WHERE
				S.SelectYN <> 0
			) sub

		IF @Debug <> 0 SELECT StartYear = @StartYear, ResetStartYear = @ResetStartYear

		IF @ResetStartYear <> 0
			BEGIN
				SET @DimensionID = -7
				CREATE TABLE #StartYear (StartYear int)

				WHILE @DimensionID >= -49
					BEGIN

						SELECT
							@DimensionName = DimensionName,
							@Property = ISNULL(Property1, Property2)
						FROM
							(
							SELECT 
								DimensionName,
								Property1 = 
									CASE WHEN PropertyName01 = 'TimeYear' THEN 'Property01' ELSE
									CASE WHEN PropertyName02 = 'TimeYear' THEN 'Property02' ELSE
									CASE WHEN PropertyName03 = 'TimeYear' THEN 'Property03' ELSE
									CASE WHEN PropertyName04 = 'TimeYear' THEN 'Property04' ELSE
									CASE WHEN PropertyName05 = 'TimeYear' THEN 'Property05' ELSE
									CASE WHEN PropertyName06 = 'TimeYear' THEN 'Property06' ELSE
									CASE WHEN PropertyName07 = 'TimeYear' THEN 'Property07' ELSE
									CASE WHEN PropertyName08 = 'TimeYear' THEN 'Property08' ELSE
									CASE WHEN PropertyName09 = 'TimeYear' THEN 'Property09' ELSE
									CASE WHEN PropertyName10 = 'TimeYear' THEN 'Property10' END END END END END END END END END END,
								Property2 = 
									CASE WHEN PropertyName11 = 'TimeYear' THEN 'Property11' ELSE
									CASE WHEN PropertyName12 = 'TimeYear' THEN 'Property12' ELSE
									CASE WHEN PropertyName13 = 'TimeYear' THEN 'Property13' ELSE
									CASE WHEN PropertyName14 = 'TimeYear' THEN 'Property14' ELSE
									CASE WHEN PropertyName15 = 'TimeYear' THEN 'Property15' ELSE
									CASE WHEN PropertyName16 = 'TimeYear' THEN 'Property16' ELSE
									CASE WHEN PropertyName17 = 'TimeYear' THEN 'Property17' ELSE
									CASE WHEN PropertyName18 = 'TimeYear' THEN 'Property18' ELSE
									CASE WHEN PropertyName19 = 'TimeYear' THEN 'Property19' ELSE
									CASE WHEN PropertyName20 = 'TimeYear' THEN 'Property20' END END END END END END END END END END 
							FROM
								[pcEXCHANGE_Demo].[dbo].[Dimension]
							WHERE
								DimensionID = @DimensionID
							) sub

						SET @SQLStatement = '
							INSERT INTO #StartYear (StartYear) SELECT StartYear = MIN(' + @Property + ') FROM [' + @SourceDatabase + '].[dbo].[DimensionData] WHERE DimensionName = ''' + @DimensionName + ''''

						IF @Debug <> 0
							SELECT
								DimensionID = @DimensionID,
								DimensionName = @DimensionName,
								Property = @Property,
								SQLStatement = @SQLStatement

						EXEC (@SQLStatement)
						SET @DimensionID = @DimensionID - 42
					END
				SELECT @StartYear = ISNULL(MIN(StartYear), @StartYear) FROM #StartYear
				DROP TABLE #StartYear
			END
*/
		IF @Debug <> 0
			SELECT
				ETLDatabase = @ETLDatabase,
				DestinationDatabase = @CallistoDatabase,
				StartYear = @StartYear,
				FiscalYearStartMonth = @FiscalYearStartMonth,
				TimeYN = @TimeYN,
				TimeDayYN = @TimeDayYN,
				[Version] = @Version,
				ResetStartYear = @ResetStartYear

	SET @Step = 'CREATE Temp TABLE #MappedObject'
		CREATE TABLE #MappedObject
			(
			ObjectName nvarchar(100),
			MappedObjectName nvarchar(100)
			)

		SET @SQLStatement = '
			INSERT INTO #MappedObject
				(
				ObjectName,
				MappedObjectName
				)
			SELECT
				ObjectName,
				MappedObjectName
			FROM
				' + @ETLDatabase + '..MappedObject
			WHERE
				DimensionTypeID = 25 AND
				SelectYN <> 0'

			EXEC (@SQLStatement)

	SET @Step = 'CREATE Temp TABLE #Action'
		CREATE TABLE #Action
			(
			[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
			)

-------------------------------
	SET @Step = 'Create view vw_0000_Time_SendTo'
	IF @TimeYN <> 0
		BEGIN
			TRUNCATE TABLE #Action
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''vw_0000_Time_SendTo''' + ', ' + '''V''' 
			INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
			SELECT @Action = [Action] FROM #Action

			SET @SQLStatement = @Action + ' VIEW [dbo].[vw_0000_Time_SendTo] 
				
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--Month
SELECT
 Label = SUBSTRING(Label, 1, 6), 
 SendTo = MAX(Label),
 [Level] = ''''Month''''
FROM
 ' + @CallistoDatabase + '.dbo.S_DS_Time 
WHERE
 ISNUMERIC(Label) <> 0 AND LEN(Label) = 6
GROUP BY
 SUBSTRING(Label, 1, 6)

--FiscalQuarter
UNION SELECT
 Label = FQ.[Quarter], 
 SendTo = MAX(D.Label),
 [Level] = ''''FiscalQuarter'''' 
FROM
 ' + @CallistoDatabase + '.dbo.S_DS_Time D
 INNER JOIN (SELECT [Quarter] = Label FROM ' + @CallistoDatabase + '.dbo.S_DS_Time WHERE SUBSTRING(Label, 5, 2) = ''''FQ'''') FQ ON 
	SUBSTRING(FQ.[Quarter], 1, 4) = SUBSTRING(D.[TimeFiscalYear], 3, 4) AND 
	SUBSTRING(FQ.[Quarter], 7, 1) = SUBSTRING(D.[TimeFiscalQuarter], 3, 1)
WHERE
 ISNUMERIC(D.Label) <> 0 AND LEN(D.Label) = 6
GROUP BY
 FQ.[Quarter]
 
--Quarter
UNION SELECT
 Label = Q.[Quarter], 
 SendTo = MAX(D.Label),
 [Level] = ''''Quarter'''' 
FROM
 ' + @CallistoDatabase + '.dbo.S_DS_Time D
 INNER JOIN (SELECT [Quarter] = Label FROM ' + @CallistoDatabase + '.dbo.S_DS_Time WHERE SUBSTRING(Label, 5, 1) = ''''Q'''') Q ON 
	SUBSTRING(Q.[Quarter], 1, 4) = SUBSTRING(D.[Label], 1, 4) AND 
	SUBSTRING(Q.[Quarter], 6, 1) = CONVERT(nvarchar, (CONVERT(int, SUBSTRING(D.Label, 5, 2)) + 2) / 3)
WHERE
 ISNUMERIC(D.Label) <> 0 AND LEN(D.Label) = 6
GROUP BY
 Q.[Quarter]

--FiscalYear
UNION SELECT
 Label = FY.[Year], 
 SendTo = MAX(D.Label),
 [Level] = ''''FiscalYear'''' 
FROM
 ' + @CallistoDatabase + '.dbo.S_DS_Time D
 INNER JOIN (SELECT [Year] = Label FROM ' + @CallistoDatabase + '.dbo.S_DS_Time WHERE SUBSTRING(Label, 1, 2) = ''''FY'''') FY ON 
	SUBSTRING(FY.[Year], 3, 4) = SUBSTRING(D.[TimeFiscalYear], 3, 4)
WHERE
 ISNUMERIC(D.Label) <> 0 AND LEN(D.Label) = 6
GROUP BY
 FY.[Year]

--Year
UNION SELECT
 Label = Y.[Year], 
 SendTo = MAX(D.Label),
 [Level] = ''''Year'''' 
FROM
 ' + @CallistoDatabase + '.dbo.S_DS_Time D
 INNER JOIN (SELECT [Year] = Label FROM ' + @CallistoDatabase + '.dbo.S_DS_Time WHERE ISNUMERIC(Label) <> 0 AND LEN(Label) = 4) Y ON 
	Y.[Year] = D.[TimeYear]
WHERE
 ISNUMERIC(D.Label) <> 0 AND LEN(D.Label) = 6
GROUP BY
 Y.[Year]'

			IF @Debug <> 0 PRINT @SQLStatement 
				
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
			EXEC (@SQLStatement)
		END

-------------------------
	SET @Step = 'Create view vw_0000_TimeDay_SendTo'
	IF @TimeDayYN <> 0
		BEGIN
			TRUNCATE TABLE #Action
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''vw_0000_TimeDay_SendTo''' + ', ' + '''V''' 
			INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
			SELECT @Action = [Action] FROM #Action

			SET @SQLStatement = @Action + ' VIEW [dbo].[vw_0000_TimeDay_SendTo] 
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '				
AS

--Day
SELECT
 Label = Label, 
 SendTo = MAX(Label),
 [Level] = ''''Day''''
FROM
 ' + @CallistoDatabase + '.dbo.S_DS_TimeDay 
WHERE
 ISNUMERIC(Label) <> 0 AND LEN(Label) = 8
GROUP BY
 Label

--Week
UNION SELECT
 Label = TimeYear + TimeWeek, 
 SendTo = MAX(Label),
 [Level] = ''''Week''''
FROM
 ' + @CallistoDatabase + '.dbo.S_DS_TimeDay 
WHERE
 ISNUMERIC(Label) <> 0 AND LEN(Label) = 8
GROUP BY
 TimeYear + TimeWeek

--Month
UNION SELECT
 Label = SUBSTRING(Label, 1, 6), 
 SendTo = MAX(Label),
 [Level] = ''''Month''''
FROM
 ' + @CallistoDatabase + '.dbo.S_DS_TimeDay 
WHERE
 ISNUMERIC(Label) <> 0 AND LEN(Label) = 8
GROUP BY
 SUBSTRING(Label, 1, 6)
 
--Quarter
UNION SELECT
 Label = Q.[Quarter], 
 SendTo = MAX(D.Label),
 [Level] = ''''Quarter'''' 
FROM
 ' + @CallistoDatabase + '.dbo.S_DS_TimeDay D
 INNER JOIN (SELECT [Quarter] = Label FROM ' + @CallistoDatabase + '.dbo.S_DS_TimeDay WHERE SUBSTRING(Label, 5, 1) = ''''Q'''') Q ON 
	SUBSTRING(Q.[Quarter], 1, 4) = SUBSTRING(D.[Label], 1, 4) AND 
	SUBSTRING(Q.[Quarter], 6, 1) = CONVERT(nvarchar, (CONVERT(int, SUBSTRING(D.Label, 5, 2)) + 2) / 3)
WHERE
 ISNUMERIC(D.Label) <> 0 AND LEN(D.Label) = 8
GROUP BY
 Q.[Quarter]

--Year
UNION SELECT
 Label = SUBSTRING(Label, 1, 4), 
 SendTo = MAX(Label),
 [Level] = ''''Year'''' 
FROM
 ' + @CallistoDatabase + '.dbo.S_DS_TimeDay 
WHERE
 ISNUMERIC(Label) <> 0 AND LEN(Label) = 8
GROUP BY
 SUBSTRING(Label, 1, 4)'

				IF @Debug <> 0 PRINT @SQLStatement 
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
				EXEC (@SQLStatement)

		END

---------------------------
	SET @Step = 'CREATE PROCEDURE spIU_0000_Time_Property'
		TRUNCATE TABLE #Action
		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''spIU_0000_Time_Property''' + ', ' + '''P''' 
		INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
		SELECT @Action = [Action] FROM #Action

		SET @SQLStatement = @Action + ' PROCEDURE [dbo].[spIU_0000_Time_Property]

	@UserID int = ' + CONVERT(nvarchar(10), @UserID) + ',
	@InstanceID int = ' + CONVERT(nvarchar(10), @InstanceID) + ',
	@VersionID int = ' + CONVERT(nvarchar(10), @VersionID) + ',

	@StartYear int = ' + CONVERT(nvarchar, @StartYear) + ',
	@FiscalYearStartMonth int = ' + CONVERT(nvarchar, @FiscalYearStartMonth) + ',
	@DimensionID int = 0,
	@LabelCheck bit = 0,

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

AS

SET ANSI_WARNINGS OFF

DECLARE
	@Deleted_Step int = 0,
    @Inserted_Step int = 0,
    @Updated_Step int = 0,

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

SET DATEFIRST 1 --Makes Monday first day of week	

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())
'
IF EXISTS (SELECT 1 FROM #MappedObject WHERE ObjectName = 'TimeWeekDay')
	BEGIN
		SELECT @DimensionID = -25, @DimensionName = MappedObjectName FROM #MappedObject WHERE ObjectName = 'TimeWeekDay' 
		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''TimeWeekDay, 1 - 7''''
		IF @DimensionID IN (0, -25)
			BEGIN
				TRUNCATE TABLE wrk_Dimension
				INSERT INTO wrk_Dimension
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[Label] = sub.[Label],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[RNodeType] = MAX(sub.[RNodeType]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number,
						[Label] = CONVERT(nvarchar(255), D1.Number),
						[Description] = DATENAME(weekday, CONVERT(smalldatetime, ''''2013-07-'''' + CONVERT(nvarchar, D1.Number))),
						[RNodeType] = ''''L'''',
						[Parent] = ''''All_''''
					FROM
						Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 7
			
					UNION SELECT [MemberId] = 1000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [RNodeType] = ''''P'''', [Parent] = ''''All_''''
					UNION SELECT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Weekdays'''', [RNodeType] = ''''P'''', [Parent] = NULL
					UNION SELECT [MemberId] = -1, [Label] = ''''NONE'''', [Description] = ''''N/A'''', [RNodeType] = ''''L'''', [Parent] = ''''All_''''
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND M.MemberId = sub.MemberId AND M.Label = sub.Label
				GROUP BY
					sub.[Label]

				IF @LabelCheck = 0
					BEGIN
						SELECT @Deleted_Step = 0, @Inserted_Step = 0, @Updated_Step = 0
						EXEC [dbo].[spIU_0000_Dimension_Generic] @JobID = @JobID, @DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ', @Dimension = ''''' + @DimensionName + ''''', @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step
					END
			END
'
	END

IF EXISTS (SELECT 1 FROM #MappedObject WHERE ObjectName = 'TimeWeek')
	BEGIN
		SELECT @DimensionID = -30, @DimensionName = MappedObjectName FROM #MappedObject WHERE ObjectName = 'TimeWeek' 
		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''TimeWeek W01 - W54''''
		IF @DimensionID IN (0, -30)
			BEGIN
				TRUNCATE TABLE wrk_Dimension
				INSERT INTO wrk_Dimension
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[Label] = sub.[Label],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[RNodeType] = MAX(sub.[RNodeType]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D2.Number * 10 + D1.Number + 1,
						[Label] = ''''W'''' + CASE WHEN LEN(D2.Number * 10 + D1.Number + 1) = 1 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1),
						[Description] = ''''Week '''' + CASE WHEN LEN(D2.Number * 10 + D1.Number + 1) = 1 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1),
						[RNodeType] = ''''L'''',
						[Parent] = ''''All_''''
					FROM
						Digit D1,
						Digit D2
					WHERE
						D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 54
		
					UNION SELECT [MemberId] = 1000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [RNodeType] = ''''P'''', [Parent] = ''''All_''''
					UNION SELECT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Weeks'''', [RNodeType] = ''''P'''', [Parent] = NULL
					UNION SELECT [MemberId] = -1, [Label] = ''''NONE'''', [Description] = ''''N/A'''', [RNodeType] = ''''L'''', [Parent] = ''''All_''''
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND M.MemberId = sub.MemberId AND M.Label = sub.Label
				GROUP BY
					sub.[Label]

				IF @LabelCheck = 0
					BEGIN
						SELECT @Deleted_Step = 0, @Inserted_Step = 0, @Updated_Step = 0
						EXEC [dbo].[spIU_0000_Dimension_Generic] @JobID = @JobID, @DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ', @Dimension = ''''' + @DimensionName + ''''', @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step
					END
			END
'
	END

IF EXISTS (SELECT 1 FROM #MappedObject WHERE ObjectName = 'TimeMonth')
	BEGIN
		SELECT @DimensionID = -11, @DimensionName = MappedObjectName FROM #MappedObject WHERE ObjectName = 'TimeMonth' 
		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''TimeMonth''''
		IF @DimensionID IN (0, -11)
			BEGIN
				TRUNCATE TABLE wrk_Dimension
				INSERT INTO wrk_Dimension
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[Label] = sub.[Label],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[RNodeType] = MAX(sub.[RNodeType]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D2.Number * 10 + D1.Number + 1,
						[Label] = CASE WHEN LEN(D2.Number * 10 + D1.Number + 1) = 1 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1),
						[Description] = DATENAME(month, CONVERT(smalldatetime, ''''2000-'''' + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1) + ''''-01'''')),
						[RNodeType] = ''''L'''',
						[Parent] = ''''All_''''
					FROM
						Digit D1,
						Digit D2
					WHERE
						D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
			
					UNION SELECT [MemberId] = 1000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [RNodeType] = ''''P'''', [Parent] = ''''All_''''
					UNION SELECT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Months'''', [RNodeType] = ''''P'''', [Parent] = NULL
					UNION SELECT [MemberId] = -1, [Label] = ''''NONE'''', [Description] = ''''N/A'''', [RNodeType] = ''''L'''', [Parent] = ''''All_''''
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND M.MemberId = sub.MemberId AND M.Label = sub.Label
				GROUP BY
					sub.[Label]

				IF @LabelCheck = 0
					BEGIN
						SELECT @Deleted_Step = 0, @Inserted_Step = 0, @Updated_Step = 0
						EXEC [dbo].[spIU_0000_Dimension_Generic] @JobID = @JobID, @DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ', @Dimension = ''''' + @DimensionName + ''''', @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step
					END
			END
'
	END

IF EXISTS (SELECT 1 FROM #MappedObject WHERE ObjectName = 'TimeQuarter')
	BEGIN
		SELECT @DimensionID = -37, @DimensionName = MappedObjectName FROM #MappedObject WHERE ObjectName = 'TimeQuarter' 
		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''TimeQuarter Q1 - Q4''''
		IF @DimensionID IN (0, -37)
			BEGIN
				TRUNCATE TABLE wrk_Dimension
				INSERT INTO wrk_Dimension
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[Label] = sub.[Label],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[RNodeType] = MAX(sub.[RNodeType]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number,
						[Label] = ''''Q'''' + CONVERT(nvarchar, D1.Number),
						[Description] = CONVERT(nvarchar, D1.Number) + CASE D1.Number WHEN 1 THEN ''''st'''' WHEN 2 THEN ''''nd'''' WHEN 3 THEN ''''rd'''' WHEN 4 THEN ''''th'''' ELSE '''''''' END + '''' Quarter'''',
						[RNodeType] = ''''L'''',
						[Parent] = ''''All_''''
					FROM
						Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 4
			
					UNION SELECT [MemberId] = 1000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [RNodeType] = ''''P'''', [Parent] = ''''All_''''
					UNION SELECT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Quarters'''', [RNodeType] = ''''P'''', [Parent] = NULL
					UNION SELECT [MemberId] = -1, [Label] = ''''NONE'''', [Description] = ''''N/A'''', [RNodeType] = ''''L'''', [Parent] = ''''All_''''
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND M.MemberId = sub.MemberId AND M.Label = sub.Label
				GROUP BY
					sub.[Label]

				IF @LabelCheck = 0
					BEGIN
						SELECT @Deleted_Step = 0, @Inserted_Step = 0, @Updated_Step = 0
						EXEC [dbo].[spIU_0000_Dimension_Generic] @JobID = @JobID, @DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ', @Dimension = ''''' + @DimensionName + ''''', @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step
					END
			END
'
	END

IF EXISTS (SELECT 1 FROM #MappedObject WHERE ObjectName = 'TimeTertial')
	BEGIN
		SELECT @DimensionID = -39, @DimensionName = MappedObjectName FROM #MappedObject WHERE ObjectName = 'TimeTertial' 
		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''TimeTertial T1 -T3''''
		IF @DimensionID IN (0, -39)
			BEGIN
				TRUNCATE TABLE wrk_Dimension
				INSERT INTO wrk_Dimension
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[Label] = sub.[Label],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[RNodeType] = MAX(sub.[RNodeType]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number,
						[Label] = ''''T'''' + CONVERT(nvarchar, D1.Number),
						[Description] = CONVERT(nvarchar, D1.Number) + CASE D1.Number WHEN 1 THEN ''''st'''' WHEN 2 THEN ''''nd'''' WHEN 3 THEN ''''rd'''' ELSE '''''''' END + '''' Tertial'''',
						[RNodeType] = ''''L'''',
						[Parent] = ''''All_''''
					FROM
						Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 3
			
					UNION SELECT [MemberId] = 1000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [RNodeType] = ''''P'''', [Parent] = ''''All_''''
					UNION SELECT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Tertials'''', [RNodeType] = ''''P'''', [Parent] = NULL
					UNION SELECT [MemberId] = -1, [Label] = ''''NONE'''', [Description] = ''''N/A'''', [RNodeType] = ''''L'''', [Parent] = ''''All_''''
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND M.MemberId = sub.MemberId AND M.Label = sub.Label
				GROUP BY
					sub.[Label]

				IF @LabelCheck = 0
					BEGIN
						SELECT @Deleted_Step = 0, @Inserted_Step = 0, @Updated_Step = 0
						EXEC [dbo].[spIU_0000_Dimension_Generic] @JobID = @JobID, @DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ', @Dimension = ''''' + @DimensionName + ''''', @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step
					END
			END
'
	END

IF EXISTS (SELECT 1 FROM #MappedObject WHERE ObjectName = 'TimeSemester')
	BEGIN
		SELECT @DimensionID = -38, @DimensionName = MappedObjectName FROM #MappedObject WHERE ObjectName = 'TimeSemester' 
		SET @SQLStatement = @SQLStatement + '	
	SET @Step = ''''TimeSemester S1 - S2''''
		IF @DimensionID IN (0, -38)
			BEGIN
				TRUNCATE TABLE wrk_Dimension
				INSERT INTO wrk_Dimension
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[Label] = sub.[Label],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[RNodeType] = MAX(sub.[RNodeType]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number,
						[Label] = ''''S'''' + CONVERT(nvarchar, D1.Number),
						[Description] = CONVERT(nvarchar, D1.Number) + CASE D1.Number WHEN 1 THEN ''''st'''' WHEN 2 THEN ''''nd'''' ELSE '''''''' END + '''' Semester'''',
						[RNodeType] = ''''L'''',
						[Parent] = ''''All_''''
					FROM
						Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 2
			
					UNION SELECT [MemberId] = 1000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [RNodeType] = ''''P'''', [Parent] = ''''All_''''
					UNION SELECT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Semesters'''', [RNodeType] = ''''P'''', [Parent] = NULL
					UNION SELECT [MemberId] = -1, [Label] = ''''NONE'''', [Description] = ''''N/A'''', [RNodeType] = ''''L'''', [Parent] = ''''All_''''
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND M.MemberId = sub.MemberId AND M.Label = sub.Label
				GROUP BY
					sub.[Label]

				IF @LabelCheck = 0
					BEGIN
						SELECT @Deleted_Step = 0, @Inserted_Step = 0, @Updated_Step = 0
						EXEC [dbo].[spIU_0000_Dimension_Generic] @JobID = @JobID, @DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ', @Dimension = ''''' + @DimensionName + ''''', @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step
					END
			END
'
	END

IF EXISTS (SELECT 1 FROM #MappedObject WHERE ObjectName = 'TimeYear')
	BEGIN
		SELECT @DimensionID = -40, @DimensionName = MappedObjectName FROM #MappedObject WHERE ObjectName = 'TimeYear' 
		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''TimeYear @StartYear - CurrentYear + 2''''
		IF @DimensionID IN (0, -40)
			BEGIN
				TRUNCATE TABLE wrk_Dimension
				INSERT INTO wrk_Dimension
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[Label] = sub.[Label],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[RNodeType] = MAX(sub.[RNodeType]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1, 
						Label = CONVERT(nvarchar, D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1),
						[Description] = CONVERT(nvarchar, D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1),
						[RNodeType] = ''''L'''',
						[Parent] = ''''All_''''
					FROM
						Digit D1,
						Digit D2,
						Digit D3,
						Digit D4
					WHERE
						D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @StartYear AND YEAR(GetDate()) + 2
			
					UNION SELECT [MemberId] = 30000000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [RNodeType] = ''''P'''', [Parent] = ''''All_''''
					UNION SELECT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Years'''', [RNodeType] = ''''P'''', [Parent] = NULL
					UNION SELECT [MemberId] = -1, [Label] = ''''NONE'''', [Description] = ''''N/A'''', [RNodeType] = ''''L'''', [Parent] = ''''All_''''
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND M.MemberId = sub.MemberId AND M.Label = sub.Label
				GROUP BY
					sub.[Label]

				IF @LabelCheck = 0
					BEGIN
						SELECT @Deleted_Step = 0, @Inserted_Step = 0, @Updated_Step = 0
						EXEC [dbo].[spIU_0000_Dimension_Generic] @JobID = @JobID, @DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ', @Dimension = ''''' + @DimensionName + ''''', @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step
					END
			END
'
	END

IF EXISTS (SELECT 1 FROM #MappedObject WHERE ObjectName = 'TimeFiscalPeriod')
	BEGIN
		SELECT @DimensionID = -41, @DimensionName = MappedObjectName FROM #MappedObject WHERE ObjectName = 'TimeFiscalPeriod' 
		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''TimeFiscalPeriod FP01 - FP12''''
		IF @DimensionID IN (0, -41)
			BEGIN
				TRUNCATE TABLE wrk_Dimension
				INSERT INTO wrk_Dimension
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[Label] = sub.[Label],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[RNodeType] = MAX(sub.[RNodeType]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D2.Number * 10 + D1.Number + 1,
						[Label] = ''''FP'''' + CASE WHEN LEN(D2.Number * 10 + D1.Number + 1) = 1 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1),
						[Description] = ''''Period '''' + CASE WHEN LEN(D2.Number * 10 + D1.Number + 1) = 1 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1) + '''' ('''' + DATENAME(month, DATEADD(month, @FiscalYearStartMonth - 1, CONVERT(smalldatetime, ''''2000-'''' + CONVERT(nvarchar, D2.Number * 10 + D1.Number + 1) + ''''-01''''))) + '''')'''',
						[RNodeType] = ''''L'''',
						[Parent] = ''''All_''''
					FROM
						Digit D1,
						Digit D2
					WHERE
						D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
			
					UNION SELECT [MemberId] = 1000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [RNodeType] = ''''P'''', [Parent] = ''''All_''''
					UNION SELECT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Fiscal Periods'''', [RNodeType] = ''''P'''', [Parent] = NULL
					UNION SELECT [MemberId] = -1, [Label] = ''''NONE'''', [Description] = ''''N/A'''', [RNodeType] = ''''L'''', [Parent] = ''''All_''''
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND M.MemberId = sub.MemberId AND M.Label = sub.Label
				GROUP BY
					sub.[Label]

				IF @LabelCheck = 0
					BEGIN
						SELECT @Deleted_Step = 0, @Inserted_Step = 0, @Updated_Step = 0
						EXEC [dbo].[spIU_0000_Dimension_Generic] @JobID = @JobID, @DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ', @Dimension = ''''' + @DimensionName + ''''', @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step
					END
			END
'
	END

IF EXISTS (SELECT 1 FROM #MappedObject WHERE ObjectName = 'TimeFiscalQuarter')
	BEGIN
		SELECT @DimensionID = -42, @DimensionName = MappedObjectName FROM #MappedObject WHERE ObjectName = 'TimeFiscalQuarter' 
		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''TimeFiscalQuarter FQ1 - FQ4''''
		IF @DimensionID IN (0, -42)
			BEGIN
				TRUNCATE TABLE wrk_Dimension
				INSERT INTO wrk_Dimension
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[Label] = sub.[Label],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[RNodeType] = MAX(sub.[RNodeType]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number, 
						[Label] = ''''FQ'''' + CONVERT(nvarchar, D1.Number),
						[Description] = CONVERT(nvarchar, D1.Number) + CASE D1.Number WHEN 1 THEN ''''st'''' WHEN 2 THEN ''''nd'''' WHEN 3 THEN ''''rd'''' WHEN 4 THEN ''''th'''' ELSE '''''''' END + '''' Fiscal Quarter'''',
						[RNodeType] = ''''L'''',
						[Parent] = ''''All_''''
					FROM
						Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 4
			
					UNION SELECT [MemberId] = 1000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [RNodeType] = ''''P'''', [Parent] = ''''All_''''
					UNION SELECT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Fiscal Quarters'''', [RNodeType] = ''''P'''', [Parent] = NULL
					UNION SELECT [MemberId] = -1, [Label] = ''''NONE'''', [Description] = ''''N/A'''', [RNodeType] = ''''L'''', [Parent] = ''''All_''''
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND M.MemberId = sub.MemberId AND M.Label = sub.Label
				GROUP BY
					sub.[Label]

				IF @LabelCheck = 0
					BEGIN
						SELECT @Deleted_Step = 0, @Inserted_Step = 0, @Updated_Step = 0
						EXEC [dbo].[spIU_0000_Dimension_Generic] @JobID = @JobID, @DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ', @Dimension = ''''' + @DimensionName + ''''', @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step
					END
			END
'
	END

IF EXISTS (SELECT 1 FROM #MappedObject WHERE ObjectName = 'TimeFiscalTertial')
	BEGIN
		SELECT @DimensionID = -44, @DimensionName = MappedObjectName FROM #MappedObject WHERE ObjectName = 'TimeFiscalTertial' 
		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''TimeFiscalTertial FT1 - FT3''''
		IF @DimensionID IN (0, -44)
			BEGIN
				TRUNCATE TABLE wrk_Dimension
				INSERT INTO wrk_Dimension
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[Label] = sub.[Label],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[RNodeType] = MAX(sub.[RNodeType]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number,
						[Label] = ''''FT'''' + CONVERT(nvarchar, D1.Number),
						[Description] = CONVERT(nvarchar, D1.Number) + CASE D1.Number WHEN 1 THEN ''''st'''' WHEN 2 THEN ''''nd'''' WHEN 3 THEN ''''rd'''' ELSE '''''''' END + '''' Fiscal Tertial'''',
						[RNodeType] = ''''L'''',
						[Parent] = ''''All_''''
					FROM
						Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 3
			
					UNION SELECT [MemberId] = 1000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [RNodeType] = ''''P'''', [Parent] = ''''All_''''
					UNION SELECT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Fiscal Tertials'''', [RNodeType] = ''''P'''', [Parent] = NULL
					UNION SELECT [MemberId] = -1, [Label] = ''''NONE'''', [Description] = ''''N/A'''', [RNodeType] = ''''L'''', [Parent] = ''''All_''''
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND M.MemberId = sub.MemberId AND M.Label = sub.Label
				GROUP BY
					sub.[Label]

				IF @LabelCheck = 0
					BEGIN
						SELECT @Deleted_Step = 0, @Inserted_Step = 0, @Updated_Step = 0
						EXEC [dbo].[spIU_0000_Dimension_Generic] @JobID = @JobID, @DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ', @Dimension = ''''' + @DimensionName + ''''', @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step
					END
			END
'
	END

IF EXISTS (SELECT 1 FROM #MappedObject WHERE ObjectName = 'TimeFiscalSemester')
	BEGIN
		SELECT @DimensionID = -43, @DimensionName = MappedObjectName FROM #MappedObject WHERE ObjectName = 'TimeFiscalSemester' 
		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''TimeFiscalSemester FS1 - FS2''''
		IF @DimensionID IN (0, -43)
			BEGIN
				TRUNCATE TABLE wrk_Dimension
				INSERT INTO wrk_Dimension
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[Label] = sub.[Label],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[RNodeType] = MAX(sub.[RNodeType]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = 100 + D1.Number, 
						[Label] = ''''FS'''' + CONVERT(nvarchar, D1.Number),
						[Description] = CONVERT(nvarchar, D1.Number) + CASE D1.Number WHEN 1 THEN ''''st'''' WHEN 2 THEN ''''nd'''' ELSE '''''''' END + '''' Fiscal Semester'''',
						[RNodeType] = ''''L'''',
						[Parent] = ''''All_''''
					FROM
						Digit D1
					WHERE
						D1.Number BETWEEN 1 AND 2
			
					UNION SELECT [MemberId] = 1000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [RNodeType] = ''''P'''', [Parent] = ''''All_''''
					UNION SELECT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Fiscal Semesters'''', [RNodeType] = ''''P'''', [Parent] = NULL
					UNION SELECT [MemberId] = -1, [Label] = ''''NONE'''', [Description] = ''''N/A'''', [RNodeType] = ''''L'''', [Parent] = ''''All_''''
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND M.MemberId = sub.MemberId AND M.Label = sub.Label
				GROUP BY
					sub.[Label]

				IF @LabelCheck = 0
					BEGIN
						SELECT @Deleted_Step = 0, @Inserted_Step = 0, @Updated_Step = 0
						EXEC [dbo].[spIU_0000_Dimension_Generic] @JobID = @JobID, @DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ', @Dimension = ''''' + @DimensionName + ''''', @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step
					END
			END
'
	END

IF EXISTS (SELECT 1 FROM #MappedObject WHERE ObjectName = 'TimeFiscalYear')
	BEGIN
		SELECT @DimensionID = -45, @DimensionName = MappedObjectName FROM #MappedObject WHERE ObjectName = 'TimeFiscalYear' 
		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''TimeFiscalYear FY + @StartYear - FY + CurrentYear + 2''''
		IF @DimensionID IN (0, -45)
			BEGIN
				TRUNCATE TABLE wrk_Dimension
				INSERT INTO wrk_Dimension
					(
					[MemberId],
					[Label],
					[Description],
					[HelpText],
					[RNodeType],
					[Parent]
					)
				SELECT
					[MemberId] = MAX(sub.[MemberId]),
					[Label] = sub.[Label],
					[Description] = MAX(sub.[Description]),
					[HelpText] = MAX(ISNULL(M.[HelpText], sub.[Description])),
					[RNodeType] = MAX(sub.[RNodeType]),
					[Parent] = MAX(sub.[Parent])
				FROM
					(
					SELECT
						[MemberId] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1,
						[Label] = ''''FY'''' + CONVERT(nvarchar, D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1),
						[Description] = ''''Yr '''' + CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar, D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1) ELSE CONVERT(nvarchar, D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number) + ''''/'''' + CONVERT(nvarchar, D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1) END,
						[RNodeType] = ''''L'''',
						[Parent] = ''''All_''''
					FROM
						Digit D1,
						Digit D2,
						Digit D3,
						Digit D4
					WHERE
						D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @StartYear AND YEAR(GetDate()) + 2
			
					UNION SELECT [MemberId] = 30000000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [RNodeType] = ''''P'''', [Parent] = ''''All_''''
					UNION SELECT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Fiscal Years'''', [RNodeType] = ''''P'''', [Parent] = NULL
					UNION SELECT [MemberId] = -1, [Label] = ''''NONE'''', [Description] = ''''N/A'''', [RNodeType] = ''''L'''', [Parent] = ''''All_''''
					) sub
					LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND M.MemberId = sub.MemberId AND M.Label = sub.Label
				GROUP BY
					sub.[Label]

				IF @LabelCheck = 0
					BEGIN
						SELECT @Deleted_Step = 0, @Inserted_Step = 0, @Updated_Step = 0
						EXEC [dbo].[spIU_0000_Dimension_Generic] @JobID = @JobID, @DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ', @Dimension = ''''' + @DimensionName + ''''', @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT
						SELECT @Deleted = @Deleted + @Deleted_Step, @Inserted = @Inserted + @Inserted_Step, @Updated = @Updated + @Updated_Step
					END
			END
'
	END

SET @SQLStatement = @SQLStatement + '
	
	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
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
	RAISERROR (@Message, @Severity, 100)'

		IF @Debug <> 0 PRINT @SQLStatement 
				
		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		EXEC (@SQLStatement)

		SET @SortOrder = @SortOrder + 10
		SET @SQLStatement = '
		INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 2, Command = ''spIU_0000_Time_Property'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1 
		WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_0000_Time_Property'')'
		EXEC (@SQLStatement)

-----------------------------
	SET @Step = 'CREATE PROCEDURE spIU_0000_Time'
	IF @TimeYN <> 0
		BEGIN
			TRUNCATE TABLE #Action
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''spIU_0000_Time''' + ', ' + '''P''' 
			INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
			SELECT @Action = [Action] FROM #Action

			SET @SQLStatement = @Action + ' PROCEDURE [dbo].[spIU_0000_Time]

	@UserID int = ' + CONVERT(nvarchar(10), @UserID) + ',
	@InstanceID int = ' + CONVERT(nvarchar(10), @InstanceID) + ',
	@VersionID int = ' + CONVERT(nvarchar(10), @VersionID) + ',

	@StartYear int = ' + CONVERT(nvarchar, @StartYear) + ',
	@FiscalYearStartMonth int = ' + CONVERT(nvarchar, @FiscalYearStartMonth) + ',

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

AS

SET ANSI_WARNINGS OFF

DECLARE
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

SET DATEFIRST 1 --Makes Monday first day of week	

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

	SET @Step = ''''Insert into temp table [#vwMonth]''''
		SELECT DISTINCT TOP 1000000
			[Month] = Y.Y * 100 + M.M
		INTO
			[#vwMonth]
		FROM
			(
				SELECT
					[Y] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 
				FROM
					Digit D1,
					Digit D2,
					Digit D3,
					Digit D4
				WHERE
					D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @StartYear AND YEAR(GetDate()) + 2
			) Y,
			(
				SELECT
					[M] = D2.Number * 10 + D1.Number + 1 
				FROM
					Digit D1,
					Digit D2
				WHERE
					D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
			) M 
		ORDER BY
			Y.Y * 100 + M.M'
SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Insert into temp table [#Time_Member]''''
		SELECT TOP 1000000
			[MemberId] = [calc].[MemberId],
			[Label] = CONVERT(nvarchar, [calc].[Label]),
			[Description] = [calc].[Description],
			[HelpText] = ISNULL(M.[HelpText], calc.[Description]),
			[TimeMonth] = [calc].[TimeMonth],
			[TimeMonth_MemberId] = ISNULL([TimeMonth].[MemberId], -1),
			[TimeQuarter] = [calc].[TimeQuarter],
			[TimeQuarter_MemberId] = ISNULL([TimeQuarter].[MemberId], -1),
			[TimeTertial] = [calc].[TimeTertial],
			[TimeTertial_MemberId] = ISNULL([TimeTertial].[MemberId], -1),
			[TimeSemester] = [calc].[TimeSemester],
			[TimeSemester_MemberId] = ISNULL([TimeSemester].[MemberId], -1),
			[TimeYear] = [calc].[TimeYear],
			[TimeYear_MemberId] = ISNULL([TimeYear].[MemberId], -1),
			[TimeFiscalPeriod] = [calc].[TimeFiscalPeriod],
			[TimeFiscalPeriod_MemberId] = ISNULL([TimeFiscalPeriod].[MemberId], -1),
			[TimeFiscalQuarter] = [calc].[TimeFiscalQuarter],
			[TimeFiscalQuarter_MemberId] = ISNULL([TimeFiscalQuarter].[MemberId], -1),
			[TimeFiscalTertial] = [calc].[TimeFiscalTertial],
			[TimeFiscalTertial_MemberId] = ISNULL([TimeFiscalTertial].[MemberId], -1),
			[TimeFiscalSemester] = [calc].[TimeFiscalSemester],
			[TimeFiscalSemester_MemberId] = ISNULL([TimeFiscalSemester].[MemberId], -1),
			[TimeFiscalYear] = [calc].[TimeFiscalYear],
			[TimeFiscalYear_MemberId] = ISNULL([TimeFiscalYear].[MemberId], -1),
			[Level] = [calc].[Level],
			[TopNode] = ''''All Time'''',
			[RNodeType] = [calc].[RNodeType],
			[SBZ] = [dbo].[f_GetSBZ] (-7, [calc].[RNodeType], CONVERT(nvarchar, [calc].[Label])),
			[Source] = ''''SQL'''',
			[Synchronized] = 1, 
			[NumberOfDays] = CONVERT(int, 0),
			[Parent] = [calc].[Parent]
		INTO
			[#Time_Member]
		FROM
			(
		--Month level
			SELECT DISTINCT
				[MemberId] = sub.[Month],
				[Label] = CONVERT(nvarchar, sub.[Month]),
				[Description] = SUBSTRING(DATENAME(m, CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''), 1, 3) + '''' '''' + CONVERT(nvarchar, sub.[Month] / 100)' + CASE WHEN @FiscalYearStartMonth <> 1 THEN ' + '''' (FP'''' + CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN ''''12'''' ELSE CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 < 10 THEN ''''0'''' + CONVERT(nvarchar, (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12) ELSE CONVERT(nvarchar, (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12) END END + '''')''''' ELSE '' END + ', 
				[TimeMonth] = CASE WHEN sub.[Month] % 100 < 10 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar, sub.[Month] % 100),
				[TimeQuarter] = ''''Q'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 2) / 3),
				[TimeTertial] = ''''T'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 3) / 4),
				[TimeSemester] = ''''S'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 5) / 6),
				[TimeYear] = CONVERT(nvarchar, sub.[Month] / 100),
				[TimeFiscalPeriod] = ''''FP'''' + CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN ''''12'''' ELSE CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 < 10 THEN ''''0'''' + CONVERT(nvarchar, (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12) ELSE CONVERT(nvarchar, (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12) END END,
				[TimeFiscalQuarter] = ''''FQ'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3),
				[TimeFiscalTertial] = ''''FT'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 3) / 4),
				[TimeFiscalSemester] = ''''FS'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 5) / 6),
				[TimeFiscalYear] = ''''FY'''' + CASE WHEN @FiscalYearStartMonth = 1 THEN CONVERT(nvarchar, sub.[Month] / 100) ELSE CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))) END,
				[Level] = ''''Month'''','

IF @FiscalYearStartMonth = 1 --Calendar hierarchy

SET @SQLStatement = @SQLStatement + '
				[RNodeType] = ''''L'''',
				[Parent] = CONVERT(nvarchar, sub.[Month] / 100) + ''''Q'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 2) / 3)
			FROM
				[#vwMonth] sub
				
		--Quarter level		
			UNION SELECT DISTINCT
				[MemberId] = (sub.[Month] / 100) * 10 + (sub.[Month] % 100 + 2) / 3,
				[Label] = CONVERT(nvarchar, sub.[Month] / 100) + ''''Q'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 2) / 3),
				[Description] = ''''Q'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 2) / 3) + '''' '''' + CONVERT(nvarchar, sub.[Month] / 100), 
				[TimeMonth] = ''''NONE'''',
				[TimeQuarter] = ''''Q'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 2) / 3),
				[TimeTertial] = ''''NONE'''',
				[TimeSemester] = ''''S'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 5) / 6),
				[TimeYear] = CONVERT(nvarchar, sub.[Month] / 100),
				[TimeFiscalPeriod] = ''''NONE'''',
				[TimeFiscalQuarter] = ''''NONE'''',
				[TimeFiscalTertial] = ''''NONE'''',
				[TimeFiscalSemester] = ''''NONE'''',
				[TimeFiscalYear] = ''''NONE'''',
				[Level] = ''''Quarter'''',
				[RNodeType] = ''''P'''',
				[Parent] = CONVERT(nvarchar, sub.[Month] / 100)
			FROM
				[#vwMonth] sub

		--Year level		
			UNION SELECT DISTINCT
				[MemberId] = sub.[Month] / 100,
				[Label] = CONVERT(nvarchar, sub.[Month] / 100),
				[Description] = CONVERT(nvarchar, sub.[Month] / 100), 
				[TimeMonth] = ''''NONE'''',
				[TimeQuarter] = ''''NONE'''',
				[TimeTertial] = ''''NONE'''',
				[TimeSemester] = ''''NONE'''',
				[TimeYear] = CONVERT(nvarchar, sub.[Month] / 100),
				[TimeFiscalPeriod] = ''''NONE'''',
				[TimeFiscalQuarter] = ''''NONE'''',
				[TimeFiscalTertial] = ''''NONE'''',
				[TimeFiscalSemester] = ''''NONE'''',
				[TimeFiscalYear] = ''''NONE'''',
				[Level] = ''''Year'''',
				[RNodeType] = ''''P'''',
				[Parent] = ''''All_''''
			FROM
				[#vwMonth] sub'

ELSE --Fiscal hierarchy
SET @SQLStatement = @SQLStatement + '
				[RNodeType] = ''''L'''',
				Parent = CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))) + ''''FQ'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3)
			FROM
				[#vwMonth] sub
				
		--Quarter level		
			UNION SELECT DISTINCT
				[MemberId] = YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01'''')) * 10 + (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3,
				[Label] = CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))) + ''''FQ'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3),
				[Description] = ''''FQ'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3) + '''' '''' + ''''FY'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))), 
				[TimeMonth] = ''''NONE'''',
				[TimeQuarter] = ''''NONE'''',
				[TimeTertial] = ''''NONE'''',
				[TimeSemester] = ''''NONE'''',
				[TimeYear] = ''''NONE'''',
				[TimeFiscalPeriod] = ''''NONE'''',
				[TimeFiscalQuarter] = ''''FQ'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3),
				[TimeFiscalTertial] = ''''NONE'''',
				[TimeFiscalSemester] = ''''NONE'''',
				[TimeFiscalYear] = ''''FY'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))),
				[Level] = ''''Quarter'''',
				[RNodeType] = ''''P'''',
				[Parent] = ''''FY'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01'''')))
			FROM
				[#vwMonth] sub

		--Year level		
			UNION SELECT DISTINCT
				[MemberId] = YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01'''')),
				[Label] = ''''FY'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))),
				[Description] = ''''Yr '''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01'''')) - 1) + ''''/'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))), 
				[TimeMonth] = ''''NONE'''',
				[TimeQuarter] = ''''NONE'''',
				[TimeTertial] = ''''NONE'''',
				[TimeSemester] = ''''NONE'''',
				[TimeYear] = ''''NONE'''',
				[TimeFiscalPeriod] = ''''NONE'''',
				[TimeFiscalQuarter] = ''''NONE'''',
				[TimeFiscalTertial] = ''''NONE'''',
				[TimeFiscalSemester] = ''''NONE'''',
				[TimeFiscalYear] = ''''FY'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))),
				[Level] = ''''Year'''',
				[RNodeType] = ''''P'''',
				[Parent] = ''''All_''''
			FROM
				[#vwMonth] sub'

SET @SQLStatement = @SQLStatement + ' 
				
			UNION SELECT DISTINCT [MemberId] = 30000000, Label = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [TimeMonth] = ''''NONE'''', [TimeQuarter] = ''''NONE'''', [TimeTertial] = ''''NONE'''', [TimeSemester] = ''''NONE'''', [TimeYear] = ''''NONE'''', [TimeFiscalPeriod] = ''''NONE'''', [TimeFiscalQuarter] = ''''NONE'''', [TimeFiscalTertial] = ''''NONE'''', [TimeFiscalSemester] = ''''NONE'''', [TimeFiscalYear] = ''''NONE'''', [Level] = ''''All_'''', [RNodeType] = ''''P'''', Parent = ''''All_''''
			UNION SELECT DISTINCT [MemberId] = 1, Label = ''''All_'''', [Description] = ''''All Time'''', [TimeMonth] = ''''NONE'''', [TimeQuarter] = ''''NONE'''', [TimeTertial] = ''''NONE'''', [TimeSemester] = ''''NONE'''', [TimeYear] = ''''NONE'''', [TimeFiscalPeriod] = ''''NONE'''', [TimeFiscalQuarter] = ''''NONE'''', [TimeFiscalTertial] = ''''NONE'''', [TimeFiscalSemester] = ''''NONE'''', [TimeFiscalYear] = ''''NONE'''', [Level] = ''''All_'''', [RNodeType] = ''''P'''', Parent = ''''NULL''''
			UNION SELECT DISTINCT [MemberId] = -1, Label = ''''None'''', [Description] = ''''None'''', [TimeMonth] = ''''NONE'''', [TimeQuarter] = ''''NONE'''', [TimeTertial] = ''''NONE'''', [TimeSemester] = ''''NONE'''', [TimeYear] = ''''NONE'''', [TimeFiscalPeriod] = ''''NONE'''', [TimeFiscalQuarter] = ''''NONE'''', [TimeFiscalTertial] = ''''NONE'''', [TimeFiscalSemester] = ''''NONE'''', [TimeFiscalYear] = ''''NONE'''', [Level] = ''''NONE'''', [RNodeType] = ''''L'''', Parent = ''''All_''''
			
			) calc'

SET @SQLStatement = @SQLStatement + '
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeMonth TimeMonth ON TimeMonth.Label COLLATE DATABASE_DEFAULT = calc.TimeMonth
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeQuarter TimeQuarter ON TimeQuarter.Label COLLATE DATABASE_DEFAULT = calc.TimeQuarter
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeTertial TimeTertial ON TimeTertial.Label COLLATE DATABASE_DEFAULT = calc.TimeTertial
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeSemester TimeSemester ON TimeSemester.Label COLLATE DATABASE_DEFAULT = calc.TimeSemester
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeYear TimeYear ON TimeYear.Label COLLATE DATABASE_DEFAULT = calc.TimeYear
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalPeriod TimeFiscalPeriod ON TimeFiscalPeriod.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalPeriod
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalQuarter TimeFiscalQuarter ON TimeFiscalQuarter.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalQuarter
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalTertial TimeFiscalTertial ON TimeFiscalTertial.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalTertial
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalSemester TimeFiscalSemester ON TimeFiscalSemester.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalSemester
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalYear TimeFiscalYear ON TimeFiscalYear.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalYear
			LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -7) AND M.MemberId = calc.MemberId AND M.Label = calc.Label
		ORDER BY
			calc.Label'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Update NumberOfDays.''''
		UPDATE [TM]
		SET 
			[NumberOfDays] =
				CASE [Level]
					WHEN ''''Year'''' THEN DATEDIFF(day, CONVERT(date, CONVERT(nvarchar(10), sub.YMin * 100 + 1), 112), DATEADD(month, 1, CONVERT(date, CONVERT(nvarchar(10), sub.YMax * 100 + 1), 112)))
					WHEN ''''Quarter'''' THEN DATEDIFF(day, CONVERT(date, CONVERT(nvarchar(10), sub.QMin * 100 + 1), 112), DATEADD(month, 1, CONVERT(date, CONVERT(nvarchar(10), sub.QMax * 100 + 1), 112)))
					WHEN ''''Month'''' THEN DATEDIFF(day, CONVERT(date, CONVERT(nvarchar(10), TM.MemberID * 100 + 1), 112), DATEADD(month, 1, CONVERT(date, CONVERT(nvarchar(10), TM.MemberID * 100 + 1), 112)))
					ELSE 0
				END
		FROM	
			[#Time_Member] TM
			INNER JOIN
				(
				SELECT
					TM.MemberID,
					QMin = MIN(Q.MemberID),
					QMax = MAX(Q.MemberID),
					YMin = MIN(Y.YMin),
					YMax = MAX(Y.YMax)
				FROM	
					[#Time_Member] TM
					LEFT JOIN [#Time_Member] Q ON Q.[Level] = ''''Month'''' AND Q.Parent = TM.Label
					LEFT JOIN 
						(SELECT Label = Q.Parent, YMin = MIN(M.MemberID), YMax = MAX(M.MemberID) 
						FROM [#Time_Member] M 
							INNER JOIN [#Time_Member] Q ON Q.[Level] = ''''Quarter'''' AND Q.Label = M.Parent 
						WHERE M.[Level] = ''''Month''''
						GROUP BY
							Q.Parent) Y ON Y.Label = TM.Label
				GROUP BY
					TM.MemberID
				) sub ON sub.MemberId = TM.MemberId'

SET @SQLStatement = @SQLStatement + '
		
	SET @Step = ''''Update Description and dimension specific Properties where Synchronized is set to true.''''
	
		UPDATE
			[Time]
		SET
			[Description] = [Members].[Description], 
			[TimeMonth] = [Members].[TimeMonth],
			[TimeMonth_MemberId] = [Members].[TimeMonth_MemberId],
			[TimeQuarter] = [Members].[TimeQuarter],
			[TimeQuarter_MemberId] = [Members].[TimeQuarter_MemberId],
			[TimeTertial] = [Members].[TimeTertial],
			[TimeTertial_MemberId] = [Members].[TimeTertial_MemberId],
			[TimeSemester] = [Members].[TimeSemester],
			[TimeSemester_MemberId] = [Members].[TimeSemester_MemberId],
			[TimeYear] = [Members].[TimeYear],
			[TimeYear_MemberId] = [Members].[TimeYear_MemberId],
			[TimeFiscalPeriod] = [Members].[TimeFiscalPeriod],
			[TimeFiscalPeriod_MemberId] = [Members].[TimeFiscalPeriod_MemberId],
			[TimeFiscalQuarter] = [Members].[TimeFiscalQuarter],
			[TimeFiscalQuarter_MemberId] = [Members].[TimeFiscalQuarter_MemberId],
			[TimeFiscalTertial] = [Members].[TimeFiscalTertial],
			[TimeFiscalTertial_MemberId] = [Members].[TimeFiscalTertial_MemberId],
			[TimeFiscalSemester] = [Members].[TimeFiscalSemester],
			[TimeFiscalSemester_MemberId] = [Members].[TimeFiscalSemester_MemberId],
			[TimeFiscalYear] = [Members].[TimeFiscalYear],
			[TimeFiscalYear_MemberId] = [Members].[TimeFiscalYear_MemberId],
			[Level] = [Members].[Level],
			[TopNode] = ''''All Time'''',
			[NumberOfDays] = [Members].[NumberOfDays],
			[Source] = ''''SQL''''
		FROM'
SET @SQLStatement = @SQLStatement + '
			[' + @CallistoDatabase + '].[dbo].[S_DS_Time] [Time] 
			INNER JOIN [#Time_Member] Members ON Members.Label COLLATE DATABASE_DEFAULT = [Time].LABEL 
		WHERE 
			[Time].[Synchronized] <> 0

		SET @Updated = @Updated + @@ROWCOUNT
		
	SET @Step = ''''Insert new members''''
		INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_Time]
			(
			[MemberId],
			[Label],
			[Description],
			[HelpText],
			[TimeMonth],
			[TimeMonth_MemberId],
			[TimeQuarter],
			[TimeQuarter_MemberId],
			[TimeTertial],
			[TimeTertial_MemberId],
			[TimeSemester],
			[TimeSemester_MemberId],
			[TimeYear],
			[TimeYear_MemberId],
			[TimeFiscalPeriod],
			[TimeFiscalPeriod_MemberId],
			[TimeFiscalQuarter],
			[TimeFiscalQuarter_MemberId],
			[TimeFiscalTertial],
			[TimeFiscalTertial_MemberId],
			[TimeFiscalSemester],
			[TimeFiscalSemester_MemberId],
			[TimeFiscalYear],
			[TimeFiscalYear_MemberId],
			[Level],
			[TopNode],
			[NumberOfDays],
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
			[TimeMonth],
			[TimeMonth_MemberId],
			[TimeQuarter],
			[TimeQuarter_MemberId],
			[TimeTertial],
			[TimeTertial_MemberId],
			[TimeSemester],
			[TimeSemester_MemberId],
			[TimeYear],
			[TimeYear_MemberId],
			[TimeFiscalPeriod],
			[TimeFiscalPeriod_MemberId],
			[TimeFiscalQuarter],
			[TimeFiscalQuarter_MemberId],
			[TimeFiscalTertial],
			[TimeFiscalTertial_MemberId],
			[TimeFiscalSemester],
			[TimeFiscalSemester_MemberId],
			[TimeFiscalYear],
			[TimeFiscalYear_MemberId],
			[Level],
			[TopNode],
			[NumberOfDays],
			[RNodeType],
			[SBZ],
			[Source],
			[Synchronized]
		FROM   
			[#Time_Member] Members
		WHERE
			NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Time] [Time] WHERE Members.Label = [Time].Label COLLATE DATABASE_DEFAULT)

		SET @Inserted = @Inserted + @@ROWCOUNT'
SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Update SendTo''''
		UPDATE [D]
		SET
			SendTo = SendTo.SendTo,
			SendTo_MemberId = ISNULL([Time].MemberId, -1)
		FROM
			[' + @CallistoDatabase + '].[dbo].[S_DS_Time] [D] 
			INNER JOIN [vw_0000_Time_SendTo] SendTo ON SendTo.Label COLLATE DATABASE_DEFAULT = [D].Label
			LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Time] [Time] ON [Time].Label = SendTo.SendTo

	SET @Step = ''''Update MemberId''''
		EXEC spSet_MemberId @Database = ''''' + @CallistoDatabase + ''''', @Dimension = ''''Time'''', @Debug = @Debug

	SET @Step = ''''Insert new members into the default hierarchy. To change the hierarchy, use the Modeler.''''
		INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_Time_Time]
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
			[' + @CallistoDatabase + '].[dbo].[S_DS_Time] D1
			INNER JOIN [#Time_Member] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
			LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Time] D2 ON D2.Label = CONVERT(nvarchar, V.Parent) COLLATE DATABASE_DEFAULT
		WHERE
			NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_Time_Time] H WHERE H.MemberId = D1.MemberId) AND
			[D1].[Synchronized] <> 0 AND
			D1.MemberId <> ISNULL(D2.MemberId, 0) AND
			D1.MemberId IS NOT NULL AND
			D1.MemberId NOT IN (1000, 30000000)
		ORDER BY
			D1.Label

	SET @Step = ''''Copy the hierarchy to all instances''''
		EXEC spSet_HierarchyCopy @Database = ''''' + @CallistoDatabase + ''''', @Dimensionhierarchy = ''''Time_Time''''

	SET @Step = ''''Drop the temp tables''''
		DROP TABLE [#vwMonth]
		DROP TABLE [#Time_Member]

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
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
	RAISERROR (@Message, @Severity, 100)'

			IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE spIU_0000_Time', [SQLStatement] = @SQLStatement
				
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
			EXEC (@SQLStatement)

			SET @SortOrder = @SortOrder + 10
			SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 2, Command = ''spIU_0000_Time'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1 
			WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_0000_Time'')'
			EXEC (@SQLStatement)
		END

----------------------------
	SET @Step = 'CREATE PROCEDURE spIU_0000_TimeDay'
	IF @TimeDayYN <> 0
		BEGIN
			TRUNCATE TABLE #Action
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''spIU_0000_TimeDay''' + ', ' + '''P''' 
			INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
			SELECT @Action = [Action] FROM #Action

			SET @SQLStatement = @Action + ' PROCEDURE [dbo].[spIU_0000_TimeDay]

	@UserID int = ' + CONVERT(nvarchar(10), @UserID) + ',
	@InstanceID int = ' + CONVERT(nvarchar(10), @InstanceID) + ',
	@VersionID int = ' + CONVERT(nvarchar(10), @VersionID) + ',

	@StartYear int = ' + CONVERT(nvarchar, @StartYear) + ',
	@FiscalYearStartMonth int = ' + CONVERT(nvarchar, @FiscalYearStartMonth) + ',

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

AS

SET ANSI_WARNINGS OFF

DECLARE
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

SET DATEFIRST 1 --Makes Monday first day of week	

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

	SET @Step = ''''Insert into temp table [#vwMonth]''''
		SELECT DISTINCT TOP 1000000
			[Month] = Y.Y * 100 + M.M
		INTO
			[#vwMonth]
		FROM
			(
				SELECT
					[Y] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 
				FROM
					Digit D1,
					Digit D2,
					Digit D3,
					Digit D4
				WHERE
					D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN @StartYear AND YEAR(GetDate()) + 2
			) Y,
			(
				SELECT
					[M] = D2.Number * 10 + D1.Number + 1 
				FROM
					Digit D1,
					Digit D2
				WHERE
					D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
			) M 
		ORDER BY
			Y.Y * 100 + M.M'
SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Insert into temp table [#Time_MemberDay]''''
		SELECT TOP 1000000
			[MemberId] = [calc].[MemberId],
			[Label] = CONVERT(nvarchar, [calc].[Label]),
			[Description] = [calc].[Description],
			[HelpText] = ISNULL(M.[HelpText], calc.[Description]),
			[TimeWeekDay] = ''''NONE'''',
			[TimeWeekDay_MemberId] = -1,
			[TimeWeek] = ''''NONE'''',
			[TimeWeek_MemberId] = -1,
			[TimeMonth] = [calc].[TimeMonth],
			[TimeMonth_MemberId] = ISNULL([TimeMonth].[MemberId], -1),
			[TimeQuarter] = [calc].[TimeQuarter],
			[TimeQuarter_MemberId] = ISNULL([TimeQuarter].[MemberId], -1),
			[TimeTertial] = [calc].[TimeTertial],
			[TimeTertial_MemberId] = ISNULL([TimeTertial].[MemberId], -1),
			[TimeSemester] = [calc].[TimeSemester],
			[TimeSemester_MemberId] = ISNULL([TimeSemester].[MemberId], -1),
			[TimeYear] = [calc].[TimeYear],
			[TimeYear_MemberId] = ISNULL([TimeYear].[MemberId], -1),
			[TimeFiscalPeriod] = [calc].[TimeFiscalPeriod],
			[TimeFiscalPeriod_MemberId] = ISNULL([TimeFiscalPeriod].[MemberId], -1),
			[TimeFiscalQuarter] = [calc].[TimeFiscalQuarter],
			[TimeFiscalQuarter_MemberId] = ISNULL([TimeFiscalQuarter].[MemberId], -1),
			[TimeFiscalTertial] = [calc].[TimeFiscalTertial],
			[TimeFiscalTertial_MemberId] = ISNULL([TimeFiscalTertial].[MemberId], -1),
			[TimeFiscalSemester] = [calc].[TimeFiscalSemester],
			[TimeFiscalSemester_MemberId] = ISNULL([TimeFiscalSemester].[MemberId], -1),
			[TimeFiscalYear] = [calc].[TimeFiscalYear],
			[TimeFiscalYear_MemberId] = ISNULL([TimeFiscalYear].[MemberId], -1),
			[Level] = [calc].[Level],
			[TopNode] = ''''All Time'''',
			[NumberOfDays] = CONVERT(int, 0),
			[RNodeType] = [calc].[RNodeType],
			[SBZ] = [dbo].[f_GetSBZ] (-49, [calc].[RNodeType], CONVERT(nvarchar, [calc].[Label])),
			[Source] = ''''SQL'''',
			[Synchronized] = 1, 
			[Parent] = [calc].[Parent]
		INTO
			[#Time_MemberDay]
		FROM
			(
		--Month level
			SELECT DISTINCT
				[MemberId] = sub.[Month],
				[Label] = CONVERT(nvarchar, sub.[Month]),
				[Description] = SUBSTRING(DATENAME(m, CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''), 1, 3) + '''' '''' + CONVERT(nvarchar, sub.[Month] / 100), 
				[TimeWeekDay] = ''''NONE'''',
				[TimeWeek] = ''''NONE'''',
				[TimeMonth] = CASE WHEN sub.[Month] % 100 < 10 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar, sub.[Month] % 100),
				[TimeQuarter] = ''''Q'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 2) / 3),
				[TimeTertial] = ''''T'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 3) / 4),
				[TimeSemester] = ''''S'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 5) / 6),
				[TimeYear] = CONVERT(nvarchar, sub.[Month] / 100),
				[TimeFiscalPeriod] = ''''FP'''' + CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN ''''12'''' ELSE CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 < 10 THEN ''''0'''' + CONVERT(nvarchar, (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12) ELSE CONVERT(nvarchar, (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12) END END,
				[TimeFiscalQuarter] = ''''FQ'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3),
				[TimeFiscalTertial] = ''''FT'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 3) / 4),
				[TimeFiscalSemester] = ''''FS'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 5) / 6),
				[TimeFiscalYear] = ''''FY'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))),
				[Level] = ''''Month'''','

IF @FiscalYearStartMonth = 1 --Calendar hierarchy

SET @SQLStatement = @SQLStatement + '
				[RNodeType] = ''''P'''',
				[Parent] = CONVERT(nvarchar, sub.[Month] / 100) + ''''Q'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 2) / 3)
			FROM
				[#vwMonth] sub
				
		--Quarter level		
			UNION SELECT DISTINCT
				[MemberId] = (sub.[Month] / 100) * 10 + (sub.[Month] % 100 + 2) / 3,
				[Label] = CONVERT(nvarchar, sub.[Month] / 100) + ''''Q'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 2) / 3),
				[Description] = ''''Q'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 2) / 3) + '''' '''' + CONVERT(nvarchar, sub.[Month] / 100), 
				[TimeWeekDay] = ''''NONE'''',
				[TimeWeek] = ''''NONE'''',
				[TimeMonth] = ''''NONE'''',
				[TimeQuarter] = ''''Q'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 2) / 3),
				[TimeTertial] = ''''NONE'''',
				[TimeSemester] = ''''S'''' + CONVERT(nvarchar, (sub.[Month] % 100 + 5) / 6),
				[TimeYear] = CONVERT(nvarchar, sub.[Month] / 100),
				[TimeFiscalPeriod] = ''''NONE'''',
				[TimeFiscalQuarter] = ''''NONE'''',
				[TimeFiscalTertial] = ''''NONE'''',
				[TimeFiscalSemester] = ''''NONE'''',
				[TimeFiscalYear] = ''''NONE'''',
				[Level] = ''''Quarter'''',
				[RNodeType] = ''''P'''',
				[Parent] = CONVERT(nvarchar, sub.[Month] / 100)
			FROM
				[#vwMonth] sub

		--Year level		
			UNION SELECT DISTINCT
				[MemberId] = sub.[Month] / 100,
				[Label] = CONVERT(nvarchar, sub.[Month] / 100),
				[Description] = CONVERT(nvarchar, sub.[Month] / 100), 
				[TimeWeekDay] = ''''NONE'''',
				[TimeWeek] = ''''NONE'''',
				[TimeMonth] = ''''NONE'''',
				[TimeQuarter] = ''''NONE'''',
				[TimeTertial] = ''''NONE'''',
				[TimeSemester] = ''''NONE'''',
				[TimeYear] = CONVERT(nvarchar, sub.[Month] / 100),
				[TimeFiscalPeriod] = ''''NONE'''',
				[TimeFiscalQuarter] = ''''NONE'''',
				[TimeFiscalTertial] = ''''NONE'''',
				[TimeFiscalSemester] = ''''NONE'''',
				[TimeFiscalYear] = ''''NONE'''',
				[Level] = ''''Year'''',
				[RNodeType] = ''''P'''',
				[Parent] = ''''All_''''
			FROM
				[#vwMonth] sub'

ELSE --Fiscal hierarchy
	BEGIN
		SET @SQLStatement = @SQLStatement + '
				[RNodeType] = ''''P'''',
				Parent = CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))) + ''''FQ'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3)
			FROM
				[#vwMonth] sub
				
		--Quarter level		
			UNION SELECT DISTINCT
				[MemberId] = YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01'''')) * 10 + (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3,
				[Label] = CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))) + ''''FQ'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3),
				[Description] = ''''FQ'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3) + '''' '''' + ''''FY'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))), 
				[TimeWeekDay] = ''''NONE'''',
				[TimeWeek] = ''''NONE'''',
				[TimeMonth] = ''''NONE'''',
				[TimeQuarter] = ''''NONE'''',
				[TimeTertial] = ''''NONE'''',
				[TimeSemester] = ''''NONE'''',
				[TimeYear] = ''''NONE'''',
				[TimeFiscalPeriod] = ''''NONE'''',
				[TimeFiscalQuarter] = ''''FQ'''' + CONVERT(nvarchar, (CASE WHEN (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[Month] % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3),
				[TimeFiscalTertial] = ''''NONE'''',
				[TimeFiscalSemester] = ''''NONE'''',
				[TimeFiscalYear] = ''''FY'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))),
				[Level] = ''''Quarter'''',
				[RNodeType] = ''''P'''',
				[Parent] = ''''FY'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01'''')))
			FROM
				[#vwMonth] sub'

		SET @SQLStatement = @SQLStatement + '

		--Year level		
			UNION SELECT DISTINCT
				[MemberId] = YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01'''')),
				[Label] = ''''FY'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))),
				[Description] = ''''Yr '''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01'''')) - 1) + ''''/'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))), 
				[TimeWeekDay] = ''''NONE'''',
				[TimeWeek] = ''''NONE'''',
				[TimeMonth] = ''''NONE'''',
				[TimeQuarter] = ''''NONE'''',
				[TimeTertial] = ''''NONE'''',
				[TimeSemester] = ''''NONE'''',
				[TimeYear] = ''''NONE'''',
				[TimeFiscalPeriod] = ''''NONE'''',
				[TimeFiscalQuarter] = ''''NONE'''',
				[TimeFiscalTertial] = ''''NONE'''',
				[TimeFiscalSemester] = ''''NONE'''',
				[TimeFiscalYear] = ''''FY'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[Month] / 100) + ''''-'''' + CONVERT(nvarchar, sub.[Month] % 100) + ''''-01''''))),
				[Level] = ''''Year'''',
				[RNodeType] = ''''P'''',
				[Parent] = ''''All_''''
			FROM
				[#vwMonth] sub'
	END

SET @SQLStatement = @SQLStatement + '				
			UNION SELECT DISTINCT [MemberId] = 30000000, [Label] = ''''pcPlaceHolder'''', [Description] = ''''Not used in any hierarchy'''', [TimeWeekDay] = ''''NONE'''', [TimeWeek] = ''''NONE'''', [TimeMonth] = ''''NONE'''', [TimeQuarter] = ''''NONE'''', [TimeTertial] = ''''NONE'''', [TimeSemester] = ''''NONE'''', [TimeYear] = ''''NONE'''', [TimeFiscalPeriod] = ''''NONE'''', [TimeFiscalQuarter] = ''''NONE'''', [TimeFiscalTertial] = ''''NONE'''', [TimeFiscalSemester] = ''''NONE'''', [TimeFiscalYear] = ''''NONE'''', [Level] = ''''All_'''', [RNodeType] = ''''P'''', Parent = ''''All_''''
			UNION SELECT DISTINCT [MemberId] = 1, [Label] = ''''All_'''', [Description] = ''''All Time'''', [TimeWeekDay] = ''''NONE'''', [TimeWeek] = ''''NONE'''', [TimeMonth] = ''''NONE'''', [TimeQuarter] = ''''NONE'''', [TimeTertial] = ''''NONE'''', [TimeSemester] = ''''NONE'''', [TimeYear] = ''''NONE'''', [TimeFiscalPeriod] = ''''NONE'''', [TimeFiscalQuarter] = ''''NONE'''', [TimeFiscalTertial] = ''''NONE'''', [TimeFiscalSemester] = ''''NONE'''', [TimeFiscalYear] = ''''NONE'''', [Level] = ''''All_'''', [RNodeType] = ''''P'''', Parent = ''''NULL''''
			UNION SELECT DISTINCT [MemberId] = -1, [Label] = ''''None'''', [Description] = ''''None'''', [TimeWeekDay] = ''''NONE'''', [TimeWeek] = ''''NONE'''', [TimeMonth] = ''''NONE'''', [TimeQuarter] = ''''NONE'''', [TimeTertial] = ''''NONE'''', [TimeSemester] = ''''NONE'''', [TimeYear] = ''''NONE'''', [TimeFiscalPeriod] = ''''NONE'''', [TimeFiscalQuarter] = ''''NONE'''', [TimeFiscalTertial] = ''''NONE'''', [TimeFiscalSemester] = ''''NONE'''', [TimeFiscalYear] = ''''NONE'''', [Level] = ''''NONE'''', [RNodeType] = ''''L'''', Parent = ''''All_''''
			
			) calc'
SET @SQLStatement = @SQLStatement + '
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeMonth TimeMonth ON TimeMonth.Label COLLATE DATABASE_DEFAULT = calc.TimeMonth
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeQuarter TimeQuarter ON TimeQuarter.Label COLLATE DATABASE_DEFAULT = calc.TimeQuarter
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeTertial TimeTertial ON TimeTertial.Label COLLATE DATABASE_DEFAULT = calc.TimeTertial
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeSemester TimeSemester ON TimeSemester.Label COLLATE DATABASE_DEFAULT = calc.TimeSemester
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeYear TimeYear ON TimeYear.Label COLLATE DATABASE_DEFAULT = calc.TimeYear
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalPeriod TimeFiscalPeriod ON TimeFiscalPeriod.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalPeriod
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalQuarter TimeFiscalQuarter ON TimeFiscalQuarter.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalQuarter
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalTertial TimeFiscalTertial ON TimeFiscalTertial.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalTertial
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalSemester TimeFiscalSemester ON TimeFiscalSemester.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalSemester
			LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalYear TimeFiscalYear ON TimeFiscalYear.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalYear
			LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID IN (0, -49) AND M.MemberId = calc.MemberId AND M.Label = calc.Label
		ORDER BY
			calc.Label'
SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Update NumberOfDays.''''
		UPDATE [TM]
		SET 
			[NumberOfDays] =
				CASE [Level]
					WHEN ''''Year'''' THEN DATEDIFF(day, CONVERT(date, CONVERT(nvarchar(10), sub.YMin * 100 + 1), 112), DATEADD(month, 1, CONVERT(date, CONVERT(nvarchar(10), sub.YMax * 100 + 1), 112)))
					WHEN ''''Quarter'''' THEN DATEDIFF(day, CONVERT(date, CONVERT(nvarchar(10), sub.QMin * 100 + 1), 112), DATEADD(month, 1, CONVERT(date, CONVERT(nvarchar(10), sub.QMax * 100 + 1), 112)))
					WHEN ''''Month'''' THEN DATEDIFF(day, CONVERT(date, CONVERT(nvarchar(10), TM.MemberID * 100 + 1), 112), DATEADD(month, 1, CONVERT(date, CONVERT(nvarchar(10), TM.MemberID * 100 + 1), 112)))
					ELSE 0
				END
		FROM	
			[#Time_MemberDay] TM
			INNER JOIN
				(
				SELECT
					TM.MemberID,
					QMin = MIN(Q.MemberID),
					QMax = MAX(Q.MemberID),
					YMin = MIN(Y.YMin),
					YMax = MAX(Y.YMax)
				FROM	
					[#Time_MemberDay] TM
					LEFT JOIN [#Time_MemberDay] Q ON Q.[Level] = ''''Month'''' AND Q.Parent = TM.Label
					LEFT JOIN 
						(SELECT Label = Q.Parent, YMin = MIN(M.MemberID), YMax = MAX(M.MemberID) 
						FROM [#Time_MemberDay] M 
							INNER JOIN [#Time_MemberDay] Q ON Q.[Level] = ''''Quarter'''' AND Q.Label = M.Parent 
						WHERE M.[Level] = ''''Month''''
						GROUP BY
							Q.Parent) Y ON Y.Label = TM.Label
				GROUP BY
					TM.MemberID
				) sub ON sub.MemberId = TM.MemberId'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Update Description and dimension specific Properties where Synchronized is set to true.''''
	
		UPDATE
			[TimeDay]
		SET
			[Description] = [Members].[Description], 
			[TimeWeekDay] = [Members].[TimeWeekDay],
			[TimeWeekDay_MemberId] = [Members].[TimeWeekDay_MemberId],
			[TimeWeek] = [Members].[TimeWeek],
			[TimeWeek_MemberId] = [Members].[TimeWeek_MemberId],
			[TimeMonth] = [Members].[TimeMonth],
			[TimeMonth_MemberId] = [Members].[TimeMonth_MemberId],
			[TimeQuarter] = [Members].[TimeQuarter],
			[TimeQuarter_MemberId] = [Members].[TimeQuarter_MemberId],
			[TimeTertial] = [Members].[TimeTertial],
			[TimeTertial_MemberId] = [Members].[TimeTertial_MemberId],
			[TimeSemester] = [Members].[TimeSemester],
			[TimeSemester_MemberId] = [Members].[TimeSemester_MemberId],
			[TimeYear] = [Members].[TimeYear],
			[TimeYear_MemberId] = [Members].[TimeYear_MemberId],
			[TimeFiscalPeriod] = [Members].[TimeFiscalPeriod],
			[TimeFiscalPeriod_MemberId] = [Members].[TimeFiscalPeriod_MemberId],
			[TimeFiscalQuarter] = [Members].[TimeFiscalQuarter],
			[TimeFiscalQuarter_MemberId] = [Members].[TimeFiscalQuarter_MemberId],
			[TimeFiscalTertial] = [Members].[TimeFiscalTertial],
			[TimeFiscalTertial_MemberId] = [Members].[TimeFiscalTertial_MemberId],
			[TimeFiscalSemester] = [Members].[TimeFiscalSemester],
			[TimeFiscalSemester_MemberId] = [Members].[TimeFiscalSemester_MemberId],
			[TimeFiscalYear] = [Members].[TimeFiscalYear],
			[TimeFiscalYear_MemberId] = [Members].[TimeFiscalYear_MemberId],
			[Level] = [Members].[Level],
			[TopNode] = ''''All Time'''',
			[NumberOfDays] = [Members].[NumberOfDays],
			[Source] = ''''SQL''''
		FROM'
SET @SQLStatement = @SQLStatement + '
			[' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] [TimeDay] 
			INNER JOIN [#Time_MemberDay] Members ON Members.Label COLLATE DATABASE_DEFAULT = [TimeDay].LABEL 
		WHERE 
			[TimeDay].[Synchronized] <> 0

		SET @Updated = @Updated + @@ROWCOUNT
		
	SET @Step = ''''Insert new members''''
		INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay]
			(
			[MemberId],
			[Label],
			[Description],
			[HelpText],
			[TimeWeekDay],
			[TimeWeekDay_MemberId],
			[TimeWeek],
			[TimeWeek_MemberId],
			[TimeMonth],
			[TimeMonth_MemberId],
			[TimeQuarter],
			[TimeQuarter_MemberId],
			[TimeTertial],
			[TimeTertial_MemberId],
			[TimeSemester],
			[TimeSemester_MemberId],
			[TimeYear],
			[TimeYear_MemberId],
			[TimeFiscalPeriod],
			[TimeFiscalPeriod_MemberId],
			[TimeFiscalQuarter],
			[TimeFiscalQuarter_MemberId],
			[TimeFiscalTertial],
			[TimeFiscalTertial_MemberId],
			[TimeFiscalSemester],
			[TimeFiscalSemester_MemberId],
			[TimeFiscalYear],
			[TimeFiscalYear_MemberId],
			[Level],
			[TopNode],
			[NumberOfDays],
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
			[TimeWeekDay],
			[TimeWeekDay_MemberId],
			[TimeWeek],
			[TimeWeek_MemberId],
			[TimeMonth],
			[TimeMonth_MemberId],
			[TimeQuarter],
			[TimeQuarter_MemberId],
			[TimeTertial],
			[TimeTertial_MemberId],
			[TimeSemester],
			[TimeSemester_MemberId],
			[TimeYear],
			[TimeYear_MemberId],
			[TimeFiscalPeriod],
			[TimeFiscalPeriod_MemberId],
			[TimeFiscalQuarter],
			[TimeFiscalQuarter_MemberId],
			[TimeFiscalTertial],
			[TimeFiscalTertial_MemberId],
			[TimeFiscalSemester],
			[TimeFiscalSemester_MemberId],
			[TimeFiscalYear],
			[TimeFiscalYear_MemberId],
			[Level],
			[TopNode],
			[NumberOfDays],
			[RNodeType],
			[SBZ],
			[Source],
			[Synchronized]
		FROM   
			[#Time_MemberDay] Members
		WHERE
			NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] [TimeDay] WHERE Members.Label = [TimeDay].Label COLLATE DATABASE_DEFAULT)

		SET @Inserted = @Inserted + @@ROWCOUNT'
SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Update MemberId''''
		EXEC spSet_MemberId @Database = ''''' + @CallistoDatabase + ''''', @Dimension = ''''TimeDay'''', @Debug = @Debug

	SET @Step = ''''Insert new members into the default hierarchy. To change the hierarchy, use the Modeler.''''
		INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_TimeDay_TimeDay]
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
			[' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D1
			INNER JOIN [#Time_MemberDay] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
			LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D2 ON D2.Label = CONVERT(nvarchar, V.Parent) COLLATE DATABASE_DEFAULT
		WHERE
			NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_TimeDay_TimeDay] H WHERE H.MemberId = D1.MemberId) AND
			[D1].[Synchronized] <> 0 AND
			D1.MemberId <> ISNULL(D2.MemberId, 0) AND
			D1.MemberId IS NOT NULL AND
			D1.MemberId NOT IN (1000, 30000000)
		ORDER BY
			D1.Label

	SET @Step = ''''Copy the hierarchy to all instances''''
		EXEC spSet_HierarchyCopy @Database = ''''' + @CallistoDatabase + ''''', @Dimensionhierarchy = ''''TimeDay_TimeDay''''

	SET @Step = ''''Drop the temp tables''''
		DROP TABLE [#vwMonth]
		DROP TABLE [#Time_MemberDay]
		'

	IF @TimeDayYN <> 0
		BEGIN
			SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''Add Day level''''
		EXEC [dbo].[spIU_0000_Time_DayLevel] @JobID = @JobID
		'
		END

	IF @TimeWeekYN <> 0
		BEGIN
			SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''Add Week level''''
		EXEC [dbo].[spIU_0000_Time_WeekLevel] @JobID = @JobID
		'
		END

SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
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
	RAISERROR (@Message, @Severity, 100)'

			IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE spIU_0000_TimeDay', [SQLStatement] = @SQLStatement
				
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
			EXEC (@SQLStatement)

			SET @SortOrder = @SortOrder + 10
			SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 2, Command = ''spIU_0000_TimeDay'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1 
			WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_0000_TimeDay'')'
			EXEC (@SQLStatement)
		END

---------------------------
	SET @Step = 'CREATE PROCEDURE spIU_0000_Time_DayLevel'
	IF @TimeDayYN <> 0
		BEGIN
			TRUNCATE TABLE #Action
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''spIU_0000_Time_DayLevel''' + ', ' + '''P''' 
			INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
			SELECT @Action = [Action] FROM #Action

			SET @SQLStatement = @Action + ' PROCEDURE [dbo].[spIU_0000_Time_DayLevel]

	@UserID int = ' + CONVERT(nvarchar(10), @UserID) + ',
	@InstanceID int = ' + CONVERT(nvarchar(10), @InstanceID) + ',
	@VersionID int = ' + CONVERT(nvarchar(10), @VersionID) + ',

	@FiscalYearStartMonth int = ' + CONVERT(nvarchar, @FiscalYearStartMonth) + ',

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

AS

SET ANSI_WARNINGS OFF

DECLARE
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

SET DATEFIRST 1 --Makes Monday first day of week	

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())


	SET @Step = ''''Create day level cursor''''
		  CREATE TABLE #Day (DayId int, [DayName] nvarchar(50))
		   
		  --Cursor that adds days
		  DECLARE Days_cursor CURSOR FOR
			SELECT
				MonthID = CONVERT(int, M.Label)
			FROM
				' + @CallistoDatabase + '..S_DS_TimeDay M
			WHERE
				ISNUMERIC(M.Label) = 1 AND
				LEN(M.Label) = 6 AND
				NOT EXISTS (SELECT MonthID = CONVERT(int, D.Label) / 100, NoDays = COUNT(1) FROM ' + @CallistoDatabase + '..S_DS_TimeDay D WHERE LEN(D.Label) = 8 AND CONVERT(int, D.Label) / 100 = CONVERT(int, M.Label) GROUP BY CONVERT(int, D.Label) / 100 HAVING COUNT(1) >= 28)
			ORDER BY 
				CONVERT(int, M.Label)

		   OPEN Days_cursor
		   FETCH NEXT FROM Days_cursor INTO  @MonthID

		   WHILE @@FETCH_STATUS = 0
			 BEGIN
			TRUNCATE TABLE #Day

			INSERT #Day (DayId, [DayName])
			EXEC [sp_AddDays] @MonthID '
SET @SQLStatement = @SQLStatement + '

			SET @Step = ''''Insert into temp table '''' + CONVERT(nvarchar, @MonthID)
				SELECT TOP 1000000
					[MemberId] = [calc].[Label],
					[Label] = CONVERT(nvarchar, [calc].[Label]),
					[Description] = [calc].[Description],
					[HelpText] = [calc].[Description],  
					[TimeWeekDay] = [calc].[TimeWeekDay],
					[TimeWeekDay_MemberId] = ISNULL([TimeWeekDay].[MemberId], -1),
					[TimeWeek] = [calc].[TimeWeek],
					[TimeWeek_MemberId] = ISNULL([TimeWeek].[MemberId], -1),
					[TimeMonth] = [calc].[TimeMonth],
					[TimeMonth_MemberId] = ISNULL([TimeMonth].[MemberId], -1),
					[TimeQuarter] = [calc].[TimeQuarter],
					[TimeQuarter_MemberId] = ISNULL([TimeQuarter].[MemberId], -1),
					[TimeTertial] = [calc].[TimeTertial],
					[TimeTertial_MemberId] = ISNULL([TimeTertial].[MemberId], -1),
					[TimeSemester] = [calc].[TimeSemester],
					[TimeSemester_MemberId] = ISNULL([TimeSemester].[MemberId], -1),
					[TimeYear] = [calc].[TimeYear],
					[TimeYear_MemberId] = ISNULL([TimeYear].[MemberId], -1),
					[TimeFiscalPeriod] = [calc].[TimeFiscalPeriod],
					[TimeFiscalPeriod_MemberId] = ISNULL([TimeFiscalPeriod].[MemberId], -1),
					[TimeFiscalQuarter] = [calc].[TimeFiscalQuarter],
					[TimeFiscalQuarter_MemberId] = ISNULL([TimeFiscalQuarter].[MemberId], -1),
					[TimeFiscalTertial] = [calc].[TimeFiscalTertial],
					[TimeFiscalTertial_MemberId] = ISNULL([TimeFiscalTertial].[MemberId], -1),
					[TimeFiscalSemester] = [calc].[TimeFiscalSemester],
					[TimeFiscalSemester_MemberId] = ISNULL([TimeFiscalSemester].[MemberId], -1),
					[TimeFiscalYear] = [calc].[TimeFiscalYear],
					[TimeFiscalYear_MemberId] = ISNULL([TimeFiscalYear].[MemberId], -1),
					[Level] = ''''Day'''',
					[TopNode] = ''''All Time'''',
					[NumberOfDays] = 1,
					[RNodeType] = ''''L'''',
					[SBZ] = [dbo].[f_GetSBZ] (-49, ''''L'''', CONVERT(nvarchar, [calc].[Label])),
					[Source] = ''''SQL'''',
					[Synchronized] = 1, 
					[Parent] = [calc].[Parent]
				INTO
					[#Time_DayLevel]
				FROM
					('
SET @SQLStatement = @SQLStatement + '
					SELECT DISTINCT
						[Label] = CONVERT(nvarchar, sub.[DayId]),
						[Description] = sub.[DayName], 
						[TimeWeekDay] = CONVERT(nvarchar, DATEPART (weekday, CONVERT(nvarchar, sub.DayId / 10000) + ''''-'''' + CONVERT(nvarchar, sub.DayId / 100 % 100) + ''''-'''' + CONVERT(nvarchar, sub.DayId % 100))),
						[TimeWeek] = ''''W'''' + CASE WHEN DATEPART (week, CONVERT(nvarchar, sub.DayId / 10000) + ''''-'''' + CONVERT(nvarchar, sub.DayId / 100 % 100) + ''''-'''' + CONVERT(nvarchar, sub.DayId % 100)) < 10 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar, DATEPART (week, CONVERT(nvarchar, sub.DayId / 10000) + ''''-'''' + CONVERT(nvarchar, sub.DayId / 100 % 100) + ''''-'''' + CONVERT(nvarchar, sub.DayId % 100))),
						[TimeMonth] = CASE WHEN sub.[DayId] / 100 % 100 < 10 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar, sub.[DayId] / 100 % 100),
						[TimeQuarter] = ''''Q'''' + CONVERT(nvarchar, (sub.[DayId] / 100 % 100 + 2) / 3),
						[TimeTertial] = ''''T'''' + CONVERT(nvarchar, (sub.[DayId] / 100 % 100 + 3) / 4),
						[TimeSemester] = ''''S'''' + CONVERT(nvarchar, (sub.[DayId] / 100 % 100 + 5) / 6),
						[TimeYear] = CONVERT(nvarchar, sub.[DayId] / 10000),
						[TimeFiscalPeriod] = ''''FP'''' + CASE WHEN (sub.[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN ''''12'''' ELSE CASE WHEN (sub.[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 < 10 THEN ''''0'''' + CONVERT(nvarchar, (sub.[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12) ELSE CONVERT(nvarchar, (sub.[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12) END END,
						[TimeFiscalQuarter] = ''''FQ'''' + CONVERT(nvarchar, (CASE WHEN (sub.[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 2) / 3),
						[TimeFiscalTertial] = ''''FT'''' + CONVERT(nvarchar, (CASE WHEN (sub.[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 3) / 4),
						[TimeFiscalSemester] = ''''FS'''' + CONVERT(nvarchar, (CASE WHEN (sub.[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 = 0 THEN 12 ELSE (sub.[DayId] / 100 % 100 + (13 - @FiscalYearStartMonth)) % 12 END + 5) / 6),
						[TimeFiscalYear] = ''''FY'''' + CONVERT(nvarchar, YEAR(DATEADD(m, (13 - @FiscalYearStartMonth), CONVERT(nvarchar, sub.[DayId] / 100 / 100) + ''''-'''' + CONVERT(nvarchar, sub.[DayId] / 100 % 100) + ''''-01''''))),
						Parent = CONVERT(nvarchar, sub.[DayId] / 100)
					FROM
						#Day sub
					) calc
					LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeWeekDay TimeWeekDay ON TimeWeekDay.Label COLLATE DATABASE_DEFAULT = calc.TimeWeekDay
					LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeWeek TimeWeek ON TimeWeek.Label COLLATE DATABASE_DEFAULT = calc.TimeWeek
					LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeMonth TimeMonth ON TimeMonth.Label COLLATE DATABASE_DEFAULT = calc.TimeMonth
					LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeQuarter TimeQuarter ON TimeQuarter.Label COLLATE DATABASE_DEFAULT = calc.TimeQuarter
					LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeTertial TimeTertial ON TimeTertial.Label COLLATE DATABASE_DEFAULT = calc.TimeTertial
					LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeSemester TimeSemester ON TimeSemester.Label COLLATE DATABASE_DEFAULT = calc.TimeSemester
					LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeYear TimeYear ON TimeYear.Label COLLATE DATABASE_DEFAULT = calc.TimeYear
					LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalPeriod TimeFiscalPeriod ON TimeFiscalPeriod.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalPeriod
					LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalQuarter TimeFiscalQuarter ON TimeFiscalQuarter.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalQuarter
					LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalTertial TimeFiscalTertial ON TimeFiscalTertial.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalTertial
					LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalSemester TimeFiscalSemester ON TimeFiscalSemester.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalSemester
					LEFT JOIN ' + @CallistoDatabase + '..S_DS_TimeFiscalYear TimeFiscalYear ON TimeFiscalYear.Label COLLATE DATABASE_DEFAULT = calc.TimeFiscalYear
				ORDER BY
					calc.Label'
--PRINT @SQLStatement
SET @SQLStatement = @SQLStatement + '

			SET @Step = ''''Update S_DS_TimeDay '''' + CONVERT(nvarchar, @MonthID)
				UPDATE
					[TimeDay]
				SET
					[Description] = [Members].[Description], 
					[HelpText] = [Members].[HelpText], 
					[TimeWeekDay] = [Members].[TimeWeekDay],
					[TimeWeekDay_MemberId] = [Members].[TimeWeekDay_MemberId],
					[TimeWeek] = [Members].[TimeWeek],
					[TimeWeek_MemberId] = [Members].[TimeWeek_MemberId],
					[TimeMonth] = [Members].[TimeMonth],
					[TimeMonth_MemberId] = [Members].[TimeMonth_MemberId],
					[TimeQuarter] = [Members].[TimeQuarter],
					[TimeQuarter_MemberId] = [Members].[TimeQuarter_MemberId],
					[TimeTertial] = [Members].[TimeTertial],
					[TimeTertial_MemberId] = [Members].[TimeTertial_MemberId],
					[TimeSemester] = [Members].[TimeSemester],
					[TimeSemester_MemberId] = [Members].[TimeSemester_MemberId],
					[TimeYear] = [Members].[TimeYear],
					[TimeYear_MemberId] = [Members].[TimeYear_MemberId],
					[TimeFiscalPeriod] = [Members].[TimeFiscalPeriod],
					[TimeFiscalPeriod_MemberId] = [Members].[TimeFiscalPeriod_MemberId],
					[TimeFiscalQuarter] = [Members].[TimeFiscalQuarter],
					[TimeFiscalQuarter_MemberId] = [Members].[TimeFiscalQuarter_MemberId],
					[TimeFiscalTertial] = [Members].[TimeFiscalTertial],
					[TimeFiscalTertial_MemberId] = [Members].[TimeFiscalTertial_MemberId],
					[TimeFiscalSemester] = [Members].[TimeFiscalSemester],
					[TimeFiscalSemester_MemberId] = [Members].[TimeFiscalSemester_MemberId],
					[TimeFiscalYear] = [Members].[TimeFiscalYear],
					[TimeFiscalYear_MemberId] = [Members].[TimeFiscalYear_MemberId],
					[Level] = [Members].[Level],
					[TopNode] = ''''All Time'''',
					[NumberOfDays] = [Members].[NumberOfDays],
					[Source] = ''''SQL''''
				FROM'
SET @SQLStatement = @SQLStatement + '
					[' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] [TimeDay] 
					INNER JOIN [#Time_DayLevel] Members ON Members.Label COLLATE DATABASE_DEFAULT = [TimeDay].LABEL 
				WHERE 
					[TimeDay].[Synchronized] <> 0

				SET @Updated = @Updated + @@ROWCOUNT
				
			SET @Step = ''''Insert new rows into S_DS_TimeDay '''' + CONVERT(nvarchar, @MonthID)
				INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay]
					(
					[MemberId],
					[Label],
					[Description], 
					[HelpText],
					[TimeWeekDay],
					[TimeWeekDay_MemberId],
					[TimeWeek],
					[TimeWeek_MemberId],
					[TimeMonth],
					[TimeMonth_MemberId],
					[TimeQuarter],
					[TimeQuarter_MemberId],
					[TimeTertial],
					[TimeTertial_MemberId],
					[TimeSemester],
					[TimeSemester_MemberId],
					[TimeYear],
					[TimeYear_MemberId],
					[TimeFiscalPeriod],
					[TimeFiscalPeriod_MemberId],
					[TimeFiscalQuarter],
					[TimeFiscalQuarter_MemberId],
					[TimeFiscalTertial],
					[TimeFiscalTertial_MemberId],
					[TimeFiscalSemester],
					[TimeFiscalSemester_MemberId],
					[TimeFiscalYear],
					[TimeFiscalYear_MemberId],
					[Level],
					[TopNode],
					[NumberOfDays],
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
					[TimeWeekDay],
					[TimeWeekDay_MemberId],
					[TimeWeek],
					[TimeWeek_MemberId],
					[TimeMonth],
					[TimeMonth_MemberId],
					[TimeQuarter],
					[TimeQuarter_MemberId],
					[TimeTertial],
					[TimeTertial_MemberId],
					[TimeSemester],
					[TimeSemester_MemberId],
					[TimeYear],
					[TimeYear_MemberId],
					[TimeFiscalPeriod],
					[TimeFiscalPeriod_MemberId],
					[TimeFiscalQuarter],
					[TimeFiscalQuarter_MemberId],
					[TimeFiscalTertial],
					[TimeFiscalTertial_MemberId],
					[TimeFiscalSemester],
					[TimeFiscalSemester_MemberId],
					[TimeFiscalYear],
					[TimeFiscalYear_MemberId],
					[Level],
					[TopNode],
					[NumberOfDays],
					[RNodeType],
					[SBZ],
					[Source],
					[Synchronized]
				FROM'
SET @SQLStatement = @SQLStatement + '   
					[#Time_DayLevel] Members
				WHERE
					NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] [TimeDay] WHERE Members.Label = [TimeDay].Label COLLATE DATABASE_DEFAULT)

				SET @Inserted = @Inserted + @@ROWCOUNT

			SET @Step = ''''Drop the temp table''''
				DROP TABLE [#Time_DayLevel]
				
			FETCH NEXT FROM Days_cursor INTO @MonthID
			 END

		  CLOSE Days_cursor
		  DEALLOCATE Days_cursor

	SET @Step = ''''Update SendTo''''
		UPDATE [D]
		SET
			SendTo = SendTo.SendTo,
			SendTo_MemberId = ISNULL([TimeDay].MemberId, -1)
		FROM
			[' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] [D] 
			INNER JOIN [vw_0000_TimeDay_SendTo] SendTo ON SendTo.Label COLLATE DATABASE_DEFAULT = [D].Label
			LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] [TimeDay] ON [TimeDay].Label = SendTo.SendTo
		WHERE
			D.SendTo IS NULL
		  
	SET @Step = ''''Update MemberId''''
		EXEC spSet_MemberId @Database = ''''' + @CallistoDatabase + ''''', @Dimension = ''''TimeDay'''', @Debug = @Debug

	SET @Step = ''''Insert new members into the default hierarchy. To change the hierarchy, use the Modeler.''''
		INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_TimeDay_TimeDay]
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
			[' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D1
			LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D2 ON D2.Label = CONVERT(nvarchar, SUBSTRING(D1.Label, 1, 6)) COLLATE DATABASE_DEFAULT
		WHERE
			ISNUMERIC(D1.Label) <> 0 AND
			LEN(D1.Label) = 8 AND
			[D1].[Synchronized] <> 0 AND
			D1.MemberId <> ISNULL(D2.MemberId, 0) AND
			D1.MemberId IS NOT NULL AND
			D1.MemberId NOT IN (1000, 30000000) AND
			NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_TimeDay_TimeDay] H WHERE H.MemberId = D1.MemberId)
		ORDER BY
			D1.Label'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Copy the hierarchy to all instances''''
		EXEC spSet_HierarchyCopy @Database = ''''' + @CallistoDatabase + ''''', @Dimensionhierarchy = ''''TimeDay_TimeDay''''

	SET @Step = ''''Drop the temp table''''
		DROP TABLE #Day

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
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
	RAISERROR (@Message, @Severity, 100)'

			IF @Debug <> 0 PRINT @SQLStatement 
				
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
			EXEC (@SQLStatement)

/*
1.3.0.2120 included in spIU_0000_TimeDay 
			SET @SortOrder = @SortOrder + 10
			SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 2, Command = ''spIU_0000_Time_DayLevel'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1 
			WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_0000_Time_DayLevel'')'
			EXEC (@SQLStatement)
*/
		END

---------------------------
	SET @Step = 'CREATE PROCEDURE spIU_0000_Time_WeekLevel'
	IF @TimeWeekYN <> 0
		BEGIN
			TRUNCATE TABLE #Action
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''spIU_0000_Time_WeekLevel''' + ', ' + '''P''' 
			INSERT INTO #Action ([Action]) EXEC (@SQLStatement)
			SELECT @Action = [Action] FROM #Action

			SET @SQLStatement = @Action + ' PROCEDURE [dbo].[spIU_0000_Time_WeekLevel]

	@UserID int = ' + CONVERT(nvarchar(10), @UserID) + ',
	@InstanceID int = ' + CONVERT(nvarchar(10), @InstanceID) + ',
	@VersionID int = ' + CONVERT(nvarchar(10), @VersionID) + ',

	@FiscalYearStartMonth int = 1,

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

AS

SET ANSI_WARNINGS OFF

DECLARE
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

SET DATEFIRST 1 --Makes Monday first day of week	

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())


	SET @Step = ''''Fill temp table''''
		SELECT 
			[MemberId] = REPLACE(TD.TimeYear + TD.TimeWeek, ''''W'''', ''''0''''),
			[Label] = TD.TimeYear + TD.TimeWeek,
			[Description] = TD.TimeYear + '''' '''' + TD.TimeWeek,
			[Closed] = 0,
			[Level] = ''''Week'''',
			[SendTo_MemberId] = 0,
			[SendTo] = MAX(TD.Label),
			[TimeFiscalPeriod_MemberId] = -1,
			[TimeFiscalPeriod] = ''''NONE'''',
			[TimeFiscalQuarter_MemberId] = -1,
			[TimeFiscalQuarter] = ''''NONE'''',
			[TimeFiscalSemester_MemberId] = -1,
			[TimeFiscalSemester] = ''''NONE'''',
			[TimeFiscalTertial_MemberId] = -1,
			[TimeFiscalTertial] = ''''NONE'''',
			[TimeFiscalYear_MemberId] = -1,
			[TimeFiscalYear] = ''''NONE'''',
			[TimeMonth_MemberId] = -1,
			[TimeMonth] = ''''NONE'''',
			[TimeQuarter_MemberId] = -1,
			[TimeQuarter] = ''''NONE'''',
			[TimeSemester_MemberId] = -1,
			[TimeSemester] = ''''NONE'''',
			[TimeTertial_MemberId] = -1,
			[TimeTertial] = ''''NONE'''',
			[TimeWeek_MemberId] = MAX(TD.TimeWeek_MemberId),
			[TimeWeek] = TD.TimeWeek,
			[TimeWeekDay_MemberId] = -1,
			[TimeWeekDay] = ''''NONE'''',
			[TimeYear_MemberId] = MAX(TD.TimeYear_MemberId),
			[TimeYear] = TD.TimeYear,
			[TopNode] = MAX(TD.TopNode),
			[RNodeType] = ''''P'''',
			[SBZ] = 1,
			[Source] = ''''SQL'''',
			[Synchronized] = 1, 
			[Parent] = TD.TimeYear
		INTO
			[#Time_WeekLevel]
		FROM
			' + @CallistoDatabase + '.dbo.S_DS_TimeDay TD
		WHERE
			[Level] = ''''Day''''
		GROUP BY
			TD.TimeYear,
			TD.TimeWeek
		ORDER BY
			TD.TimeYear,
			TD.TimeWeek'
SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Update SendTo''''
		UPDATE [TW]
		SET
			SendTo_MemberId = ISNULL([TimeDay].MemberId, -1)
		FROM
			[#Time_WeekLevel] [TW] 
			INNER JOIN [vw_0000_TimeDay_SendTo] SendTo ON SendTo.Label COLLATE DATABASE_DEFAULT = [TW].Label
			LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] [TimeDay] ON [TimeDay].Label = SendTo.SendTo

	SET @Step = ''''Update S_DS_TimeDay '''' + CONVERT(nvarchar, @MonthID)
		UPDATE
			[TimeDay]
		SET
			[Description] = [Members].[Description], 
			[TimeWeekDay] = [Members].[TimeWeekDay],
			[TimeWeekDay_MemberId] = [Members].[TimeWeekDay_MemberId],
			[TimeWeek] = [Members].[TimeWeek],
			[TimeWeek_MemberId] = [Members].[TimeWeek_MemberId],
			[TimeMonth] = [Members].[TimeMonth],
			[TimeMonth_MemberId] = [Members].[TimeMonth_MemberId],
			[TimeQuarter] = [Members].[TimeQuarter],
			[TimeQuarter_MemberId] = [Members].[TimeQuarter_MemberId],
			[TimeTertial] = [Members].[TimeTertial],
			[TimeTertial_MemberId] = [Members].[TimeTertial_MemberId],
			[TimeSemester] = [Members].[TimeSemester],
			[TimeSemester_MemberId] = [Members].[TimeSemester_MemberId],
			[TimeYear] = [Members].[TimeYear],
			[TimeYear_MemberId] = [Members].[TimeYear_MemberId],
			[TimeFiscalPeriod] = [Members].[TimeFiscalPeriod],
			[TimeFiscalPeriod_MemberId] = [Members].[TimeFiscalPeriod_MemberId],
			[TimeFiscalQuarter] = [Members].[TimeFiscalQuarter],
			[TimeFiscalQuarter_MemberId] = [Members].[TimeFiscalQuarter_MemberId],
			[TimeFiscalTertial] = [Members].[TimeFiscalTertial],
			[TimeFiscalTertial_MemberId] = [Members].[TimeFiscalTertial_MemberId],
			[TimeFiscalSemester] = [Members].[TimeFiscalSemester],
			[TimeFiscalSemester_MemberId] = [Members].[TimeFiscalSemester_MemberId],
			[TimeFiscalYear] = [Members].[TimeFiscalYear],
			[TimeFiscalYear_MemberId] = [Members].[TimeFiscalYear_MemberId],
			[SendTo] = Members.[SendTo],
			[SendTo_MemberId] = Members.[SendTo_MemberId],
			[Level] = [Members].[Level],
			[TopNode] = ''''All Time'''',
			[Source] = ''''SQL''''
		FROM
			[' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] [TimeDay] 
			INNER JOIN [#Time_WeekLevel] Members ON Members.Label COLLATE DATABASE_DEFAULT = [TimeDay].LABEL 
		WHERE 
			[TimeDay].[Synchronized] <> 0'
SET @SQLStatement = @SQLStatement + '

		SET @Updated = @Updated + @@ROWCOUNT
				
	SET @Step = ''''Insert new rows into S_DS_TimeDay '''' + CONVERT(nvarchar, @MonthID)
		INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay]
			(
			[MemberId],
			[Label],
			[Description], 
			[TimeWeekDay],
			[TimeWeekDay_MemberId],
			[TimeWeek],
			[TimeWeek_MemberId],
			[TimeMonth],
			[TimeMonth_MemberId],
			[TimeQuarter],
			[TimeQuarter_MemberId],
			[TimeTertial],
			[TimeTertial_MemberId],
			[TimeSemester],
			[TimeSemester_MemberId],
			[TimeYear],
			[TimeYear_MemberId],
			[TimeFiscalPeriod],
			[TimeFiscalPeriod_MemberId],
			[TimeFiscalQuarter],
			[TimeFiscalQuarter_MemberId],
			[TimeFiscalTertial],
			[TimeFiscalTertial_MemberId],
			[TimeFiscalSemester],
			[TimeFiscalSemester_MemberId],
			[TimeFiscalYear],
			[TimeFiscalYear_MemberId],
			[SendTo],
			[SendTo_MemberId],
			[Level],
			[TopNode],
			[RNodeType],
			[SBZ],
			[Source],
			[Synchronized]
			)
		SELECT
			[MemberId],
			[Label],
			[Description], 
			[TimeWeekDay],
			[TimeWeekDay_MemberId],
			[TimeWeek],
			[TimeWeek_MemberId],
			[TimeMonth],
			[TimeMonth_MemberId],
			[TimeQuarter],
			[TimeQuarter_MemberId],
			[TimeTertial],
			[TimeTertial_MemberId],
			[TimeSemester],
			[TimeSemester_MemberId],
			[TimeYear],
			[TimeYear_MemberId],
			[TimeFiscalPeriod],
			[TimeFiscalPeriod_MemberId],
			[TimeFiscalQuarter],
			[TimeFiscalQuarter_MemberId],
			[TimeFiscalTertial],
			[TimeFiscalTertial_MemberId],
			[TimeFiscalSemester],
			[TimeFiscalSemester_MemberId],
			[TimeFiscalYear],
			[TimeFiscalYear_MemberId],
			[SendTo],
			[SendTo_MemberId],
			[Level],
			[TopNode],
			[RNodeType],
			[SBZ],
			[Source],
			[Synchronized]
		FROM   
			[#Time_WeekLevel] Members
		WHERE
			NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] [TimeDay] WHERE Members.Label = [TimeDay].Label COLLATE DATABASE_DEFAULT)'
SET @SQLStatement = @SQLStatement + '

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Update MemberId''''
		EXEC spSet_MemberId @Database = ''''' + @CallistoDatabase + ''''', @Dimension = ''''TimeDay''''
		
	SET @Step = ''''Insert new members into the week hierarchy. To change the hierarchy, use the Modeler.''''
		INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_TimeDay_TimeWeek]
			(
			[MemberId],
			[ParentMemberId],
			[SequenceNumber]
			)
		SELECT
			[MemberId],
			[ParentMemberId],
			[SequenceNumber]
		FROM
			(
			--All
			SELECT
				[Label] = ''''0'''',
				[MemberId] = D1.MemberId,
				[ParentMemberId] = NULL,
				[SequenceNumber] = 0
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D1
			WHERE
				D1.Label = ''''All_'''' AND
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_TimeDay_TimeWeek] H WHERE H.MemberId = D1.MemberId) AND
				[D1].[Synchronized] <> 0

			--Year
			UNION SELECT
				[Label] = D1.Label,
				[MemberId] = D1.MemberId,
				[ParentMemberId] = ISNULL(D2.MemberId, 0),
				[SequenceNumber] = D1.MemberId  
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D1
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D2 ON D2.Label = ''''All_''''
			WHERE
				D1.[Level] = ''''Year'''' AND
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_TimeDay_TimeWeek] H WHERE H.MemberId = D1.MemberId) AND
				[D1].[Synchronized] <> 0 AND
				D1.MemberId <> ISNULL(D2.MemberId, 0) AND
				D1.MemberId IS NOT NULL'
SET @SQLStatement = @SQLStatement + '

			--Week
			UNION SELECT
				[Label] = D1.Label,
				[MemberId] = D1.MemberId,
				[ParentMemberId] = ISNULL(D2.MemberId, 0),
				[SequenceNumber] = D1.MemberId  
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D1
				INNER JOIN [#Time_WeekLevel] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D2 ON D2.Label = V.Parent COLLATE DATABASE_DEFAULT
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_TimeDay_TimeWeek] H WHERE H.MemberId = D1.MemberId) AND
				[D1].[Synchronized] <> 0 AND
				D1.MemberId <> ISNULL(D2.MemberId, 0) AND
				D1.MemberId IS NOT NULL

			--Day
			UNION SELECT
				[Label] = D1.Label,
				[MemberId] = D1.MemberId,
				[ParentMemberId] = ISNULL(D2.MemberId, 0),
				[SequenceNumber] = D1.MemberId  
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D1
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_TimeDay] D2 ON D2.Label = D1.TimeYear + D1.TimeWeek COLLATE DATABASE_DEFAULT
			WHERE
				D1.[Level] = ''''Day'''' AND
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_TimeDay_TimeWeek] H WHERE H.MemberId = D1.MemberId) AND
				[D1].[Synchronized] <> 0 AND
				D1.MemberId <> ISNULL(D2.MemberId, 0) AND
				D1.MemberId IS NOT NULL
			) sub
		WHERE
			sub.MemberId IS NOT NULL
		ORDER BY
			sub.Label

	SET @Step = ''''Copy the hierarchy to all instances''''
		EXEC spSet_HierarchyCopy @Database = ''''' + @CallistoDatabase + ''''', @Dimensionhierarchy = ''''TimeDay_TimeWeek''''

	SET @Step = ''''Drop the temp table''''
		DROP TABLE [#Time_WeekLevel]

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime
		
	SET @Step = ''''Insert into JobLog''''
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName'
SET @SQLStatement = @SQLStatement + '
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = ''''Define exit point''''
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)'

			IF @Debug <> 0 PRINT @SQLStatement 
				
			SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
			EXEC (@SQLStatement)

/*
1.3.0.2120 included in spIU_0000_TimeDay 
			SET @SortOrder = @SortOrder + 10
			SET @SQLStatement = '
			INSERT INTO ' + @ETLDatabase + '.dbo.[Load] (LoadTypeBM, Command, SortOrder, SelectYN) SELECT LoadTypeBM = 2, Command = ''spIU_0000_Time_WeekLevel'', SortOrder = ' + CONVERT(nvarchar, @SortOrder) + ', SelectYN = 1 
			WHERE NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.[Load] L WHERE L.Command = ''spIU_0000_Time_WeekLevel'')'
			EXEC (@SQLStatement)
*/
		END

-------------------
	SET @Step = 'Drop temp tables'	
		DROP TABLE #Action
		DROP TABLE #MappedObject

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
