SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_FxRate_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@StartYear int = NULL,
	@BaseCurrency nchar(3) = NULL,
	@Entity_MemberKey nvarchar(50) = NULL,
	@InvertBaseCurrencyYN bit = 0,
	@InvertRateYN bit = 0,
	@MasterEntity nvarchar(50) = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000688,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_DC_FxRate_Raw] @UserID=-10, @InstanceID=454, @VersionID=1021, @Debug=1
EXEC [spIU_DC_FxRate_Raw] @UserID=-10, @InstanceID=454, @VersionID=1021, @InvertBaseCurrencyYN = 1, @InvertRateYN = 1, @Debug=1
EXEC [spIU_DC_FxRate_Raw] @UserID=-10, @InstanceID=454, @VersionID=1021, @Entity_MemberKey = 'R510', @InvertBaseCurrencyYN = 0, @InvertRateYN = 0, @Debug=1
EXEC [spIU_DC_FxRate_Raw] @UserID=-10, @InstanceID=485, @VersionID=1034, @InvertBaseCurrencyYN = 1, @StartYear=2018, @Debug=1

EXEC [spIU_DC_FxRate_Raw] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceDatabase nvarchar(100),
	@Owner nvarchar(10),
	@SQLStatement nvarchar(max),
	@SourceID int,
	@SourceTypeID int,
	@SourceTypeName nvarchar(50),
	@MasterClosedYear int,
	@Entity_StartDay int,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
	@ProcedureName nvarchar(100),
	@DebugSub bit = 0,
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2162'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get #FxRate_Raw from source system',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2161' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2162' SET @Description = 'Handle @MasterEntity and different source COLLATION.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@Owner = ST.[Owner],
			@StartYear = ISNULL(@StartYear, S.StartYear),
			@SourceID = S.[SourceID],
			@SourceTypeID = S.[SourceTypeID],
			@SourceTypeName = ST.[SourceTypeName]
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -3 AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeFamilyID = 1
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		EXEC [spGet_MasterClosedYear]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@MasterClosedYear = @MasterClosedYear OUT,
			@JobID = @JobID

		IF @MasterClosedYear >= @StartYear SET @StartYear = @MasterClosedYear + 1

		IF @DebugBM & 2 > 0 
			SELECT
				[@SourceDatabase] = @SourceDatabase,
				[@Owner] = @Owner,
				[@StartYear] = @StartYear,
				[@SourceID] = @SourceID,
				[@SourceTypeID] = @SourceTypeID,
				[@SourceTypeName] = @SourceTypeName

	SET @Step = 'Create temp table #FxRate_Raw'
		IF OBJECT_ID(N'TempDB.dbo.#FxRate_Raw', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #FxRate_Raw
					(
					[BaseCurrency] nchar(3) COLLATE DATABASE_DEFAULT,
					[Currency] nchar(3) COLLATE DATABASE_DEFAULT,
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[TimeDay] int,
					[FxRate_Value] float
					)
			END

	SET @Step = 'Create temp table #MissingDate'
		CREATE TABLE #MissingDate
			(
			[BaseCurrency] nchar(3) COLLATE DATABASE_DEFAULT,
			[Currency] nchar(3) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #Before'
		CREATE TABLE #Before
			(
			[BaseCurrency] nchar(3) COLLATE DATABASE_DEFAULT,
			[Currency] nchar(3) COLLATE DATABASE_DEFAULT,
			[FxRate_Value] float
			)

	SET @Step = 'Create temp table #After'
		CREATE TABLE #After
			(
			[BaseCurrency] nchar(3) COLLATE DATABASE_DEFAULT,
			[Currency] nchar(3) COLLATE DATABASE_DEFAULT,
			[FxRate_Value] float
			)

	SET @Step = 'Create and fill #FxRate_Raw_Cursor'
		CREATE TABLE #FxRate_Raw_Cursor
			(
			[Entity_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[BaseCurrency] nchar(3) COLLATE DATABASE_DEFAULT,
			[Priority] int
			)

		IF @Entity_MemberKey IS NOT NULL
			BEGIN
				INSERT INTO #FxRate_Raw_Cursor
					(
					[Entity_MemberKey],
					[BaseCurrency],
					[Priority]
					)
				SELECT
					[Entity_MemberKey] = @Entity_MemberKey,
					[BaseCurrency] = @BaseCurrency,
					[Priority] = 1
			END
		ELSE
			BEGIN
				INSERT INTO #FxRate_Raw_Cursor
					(
					[Entity_MemberKey],
					[BaseCurrency],
					[Priority]
					)
				SELECT DISTINCT
					[Entity_MemberKey] = E.[MemberKey],
					[BaseCurrency] = EB.[Currency],
					[Priority] = ISNULL(E.[Priority], 99999999)
				FROM
					pcINTEGRATOR_Data..Entity E
					INNER JOIN pcINTEGRATOR_Data..Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 4 > 0 AND EB.SelectYN <> 0
				WHERE
					E.InstanceID = @InstanceID AND 
					E.VersionID = @VersionID AND
					E.SelectYN <> 0 AND
					E.DeletedID IS NULL
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FxRate_Raw_Cursor', * FROM #FxRate_Raw_Cursor

	SET @Step = 'Set @MasterEntity'
		SELECT TOP 1
			@MasterEntity = Entity_MemberKey
		FROM
			#FxRate_Raw_Cursor
		ORDER BY
			[Priority],
			Entity_MemberKey

	SET @Step = 'FxRate_Raw_Cursor'
		IF CURSOR_STATUS('global','FxRate_Raw_Cursor') >= -1 DEALLOCATE FxRate_Raw_Cursor
		DECLARE FxRate_Raw_Cursor CURSOR FOR
			
			SELECT
				Entity_MemberKey,
				BaseCurrency
			FROM
				#FxRate_Raw_Cursor
			ORDER BY
				Entity_MemberKey

			OPEN FxRate_Raw_Cursor
			FETCH NEXT FROM FxRate_Raw_Cursor INTO @Entity_MemberKey, @BaseCurrency

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@Entity_MemberKey] = @Entity_MemberKey, [@BaseCurrency] = @BaseCurrency

					IF @SourceTypeID IN (1, 11) --Epicor ERP
						BEGIN
							SET @SQLStatement = '
								INSERT INTO #FxRate_Raw
									(
									[BaseCurrency],
									[Currency],
									[Entity],
									[Scenario],
									[TimeDay],
									[FxRate_Value]
									)
								SELECT
									[BaseCurrency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ',
									[Currency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.TargetCurrCode, 3)' ELSE 'LEFT(CR.SourceCurrCode, 3)' END + ',
									[Entity] = CR.[Company],
									[Scenario] = ''ACTUAL'',
									[TimeDay] = YEAR(CR.EffectiveDate) * 10000 + MONTH(CR.EffectiveDate) * 100 + DAY(CR.EffectiveDate),
									[FxRate_Value] = ' + CASE WHEN @InvertRateYN = 0 THEN 'MAX(CR.CurrentRate)' ELSE '1 / MAX(CR.CurrentRate)' END + '
								FROM
									' + @SourceDatabase + '.[' + @Owner + '].[CurrExRate] CR
									INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[XbSyst] XS ON XS.Company = CR.Company AND XS.[GenRateGrp] = CR.[RateGrpCode]
								WHERE
									CR.Company = ''' + @Entity_MemberKey + '''
									' + CASE WHEN @BaseCurrency IS NOT NULL THEN 'AND ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ' = ' + '''' + @BaseCurrency + '''' ELSE '' END + '
									' + CASE WHEN @StartYear IS NOT NULL THEN 'AND YEAR(CR.EffectiveDate) >= ' + CONVERT(nvarchar(15), @StartYear) ELSE '' END + '
								GROUP BY 
									CR.SourceCurrCode,
									CR.TargetCurrCode,
									CR.[Company],
									YEAR(CR.EffectiveDate) * 10000 + MONTH(CR.EffectiveDate) * 100 + DAY(CR.EffectiveDate)
								HAVING
									MAX(CR.CurrentRate) <> 0'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Selected = @Selected + @@ROWCOUNT

							--@Entity_StartDay
							SELECT
								@Entity_StartDay = ISNULL(@StartYear, MIN(TimeDay) / 10000) * 10000 + 101
							FROM
								#FxRate_Raw
							WHERE
								[Entity] = @Entity_MemberKey

							IF @DebugBM & 2 > 0 SELECT [@Entity_StartDay] = @Entity_StartDay

							--#MissingDate
							TRUNCATE TABLE #MissingDate

							INSERT INTO #MissingDate
								(
								[BaseCurrency],
								[Currency],
								[Entity],
								[Scenario]
								)
							SELECT DISTINCT	
								[BaseCurrency] = FRV.[BaseCurrency],
								[Currency] = FRV.[Currency],
								[Entity] = FRV.[Entity],
								[Scenario] = FRV.[Scenario]
							FROM
								#FxRate_Raw FRV
							WHERE
								[Entity] = @Entity_MemberKey AND
								NOT EXISTS (SELECT 1 FROM #FxRate_Raw DFRV WHERE DFRV.[BaseCurrency] = FRV.[BaseCurrency] AND DFRV.[Currency] = FRV.[Currency] AND DFRV.[Entity] = FRV.[Entity] AND DFRV.[Scenario] = FRV.[Scenario] AND DFRV.[TimeDay] = @Entity_StartDay)

							IF @DebugBM & 2 > 0 SELECT TempTable = '#MissingDate', * FROM #MissingDate ORDER BY [BaseCurrency], [Currency]

							--#Before
							TRUNCATE TABLE #Before

							SET @SQLStatement = '
								INSERT INTO #Before
									(
									[BaseCurrency],
									[Currency],
									[FxRate_Value]
									)
								SELECT
									[BaseCurrency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ',
									[Currency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.TargetCurrCode, 3)' ELSE 'LEFT(CR.SourceCurrCode, 3)' END + ',
									[FxRate_Value] = ' + CASE WHEN @InvertRateYN = 0 THEN 'CR.CurrentRate' ELSE '1 / CR.CurrentRate' END + '
								FROM
									' + @SourceDatabase + '.[' + @Owner + '].[CurrExRate] CR
									INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[XbSyst] XS ON XS.Company = CR.Company AND XS.[GenRateGrp] = CR.[RateGrpCode]
									INNER JOIN
										(
										SELECT
											[BaseCurrency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ',
											[Currency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.TargetCurrCode, 3)' ELSE 'LEFT(CR.SourceCurrCode, 3)' END + ',
											[EffectiveDate] = MAX(CR.EffectiveDate)
										FROM
											#MissingDate MD 
											INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[CurrExRate] CR ON ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ' COLLATE DATABASE_DEFAULT = MD.[BaseCurrency] AND ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.TargetCurrCode, 3)' ELSE 'LEFT(CR.SourceCurrCode, 3)' END + ' COLLATE DATABASE_DEFAULT = MD.[Currency] AND CR.[Company] COLLATE DATABASE_DEFAULT = MD.[Entity]
											INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[XbSyst] XS ON XS.Company = CR.Company AND XS.[GenRateGrp] = CR.[RateGrpCode]
										WHERE
											CR.EffectiveDate <= CONVERT(date, ''' + CONVERT(nvarchar(15), @Entity_StartDay) + ''', 112)
											' + CASE WHEN @BaseCurrency IS NOT NULL THEN 'AND ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ' = ' + '''' + @BaseCurrency + '''' ELSE '' END + '
										GROUP BY
											CR.SourceCurrCode,
											CR.TargetCurrCode
										) sub ON 
											sub.[BaseCurrency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ' COLLATE DATABASE_DEFAULT AND
											sub.[Currency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.TargetCurrCode, 3)' ELSE 'LEFT(CR.SourceCurrCode, 3)' END + ' COLLATE DATABASE_DEFAULT AND
											sub.[EffectiveDate] = CR.EffectiveDate
								WHERE
									CR.Company = ''' + @Entity_MemberKey + '''
									' + CASE WHEN @BaseCurrency IS NOT NULL THEN 'AND ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ' = ' + '''' + @BaseCurrency + '''' ELSE '' END

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)	
							
							IF @DebugBM & 2 > 0 SELECT TempTable = '#Before', * FROM #Before ORDER BY [BaseCurrency], [Currency]

							--#After
							TRUNCATE TABLE #After

							SET @SQLStatement = '
								INSERT INTO #After
									(
									[BaseCurrency],
									[Currency],
									[FxRate_Value]
									)
								SELECT
									[BaseCurrency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ',
									[Currency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.TargetCurrCode, 3)' ELSE 'LEFT(CR.SourceCurrCode, 3)' END + ',
									[FxRate_Value] = ' + CASE WHEN @InvertRateYN = 0 THEN 'CR.CurrentRate' ELSE '1 / CR.CurrentRate' END + '
								FROM
									' + @SourceDatabase + '.[' + @Owner + '].[CurrExRate] CR
									INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[XbSyst] XS ON XS.Company = CR.Company AND XS.[GenRateGrp] = CR.[RateGrpCode]
									INNER JOIN
										(
										SELECT
											[BaseCurrency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ',
											[Currency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.TargetCurrCode, 3)' ELSE 'LEFT(CR.SourceCurrCode, 3)' END + ',
											[EffectiveDate] = MIN(CR.EffectiveDate)
										FROM
											#MissingDate MD 
											INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[CurrExRate] CR ON ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ' COLLATE DATABASE_DEFAULT = MD.[BaseCurrency] AND ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.TargetCurrCode, 3)' ELSE 'LEFT(CR.SourceCurrCode, 3)' END + ' COLLATE DATABASE_DEFAULT = MD.[Currency] AND CR.[Company] COLLATE DATABASE_DEFAULT = MD.[Entity]
											INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[XbSyst] XS ON XS.Company = CR.Company AND XS.[GenRateGrp] = CR.[RateGrpCode]
										WHERE
											CR.EffectiveDate >= CONVERT(date, ''' + CONVERT(nvarchar(15), @Entity_StartDay) + ''', 112)
											' + CASE WHEN @BaseCurrency IS NOT NULL THEN 'AND ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ' = ' + '''' + @BaseCurrency + '''' ELSE '' END + '
										GROUP BY
											CR.SourceCurrCode,
											CR.TargetCurrCode
										) sub ON 
											sub.[BaseCurrency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ' COLLATE DATABASE_DEFAULT AND
											sub.[Currency] = ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.TargetCurrCode, 3)' ELSE 'LEFT(CR.SourceCurrCode, 3)' END + ' COLLATE DATABASE_DEFAULT AND
											sub.[EffectiveDate] = CR.EffectiveDate
								WHERE
									CR.Company = ''' + @Entity_MemberKey + '''
									' + CASE WHEN @BaseCurrency IS NOT NULL THEN 'AND ' + CASE WHEN @InvertBaseCurrencyYN = 0 THEN 'LEFT(CR.SourceCurrCode, 3)' ELSE 'LEFT(CR.TargetCurrCode, 3)' END + ' = ' + '''' + @BaseCurrency + '''' ELSE '' END

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							IF @DebugBM & 2 > 0 SELECT TempTable = '#After', * FROM #After ORDER BY [BaseCurrency], [Currency]

							--Insert start values
							SET @SQLStatement = '
								INSERT INTO #FxRate_Raw
									(
									[BaseCurrency],
									[Currency],
									[Entity],
									[Scenario],
									[TimeDay],
									[FxRate_Value]
									)
								SELECT
									[BaseCurrency] = MD.[BaseCurrency],
									[Currency] = MD.[Currency],
									[Entity] = MD.[Entity],
									[Scenario] = MD.[Scenario],
									[TimeDay] = ' + CONVERT(nvarchar(15), @Entity_StartDay) + ',
									[FxRate_Value] = ISNULL([Before].[FxRate_Value], [After].[FxRate_Value])
								FROM
									#MissingDate MD
									LEFT JOIN #Before [Before] ON [Before].[BaseCurrency] = MD.[BaseCurrency] AND [Before].[Currency] = MD.[Currency]
									LEFT JOIN #After [After] ON [After].[BaseCurrency] = MD.[BaseCurrency] AND [After].[Currency] = MD.[Currency]'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Selected = @Selected + @@ROWCOUNT
						END

					ELSE 
						BEGIN
							SET @Message = 'Setup FxRate is not yet implemented for ' + @SourceTypeName + '.'
							SET @Severity = 16
							GOTO EXITPOINT
						END

					FETCH NEXT FROM FxRate_Raw_Cursor INTO @Entity_MemberKey, @BaseCurrency
				END

		CLOSE FxRate_Raw_Cursor
		DEALLOCATE FxRate_Raw_Cursor

		SET ANSI_WARNINGS ON

	SET @Step = 'Return rows'
		IF @CalledYN = 0
			SELECT TempTable = '#FxRate_Raw', * FROM #FxRate_Raw ORDER BY [BaseCurrency], [TimeDay], [Currency], [Entity], [Scenario]

	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0 DROP TABLE #FxRate_Raw
		DROP TABLE #FxRate_Raw_Cursor

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
