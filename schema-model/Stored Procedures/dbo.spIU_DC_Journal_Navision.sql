SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Journal_Navision]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = 'GL',
	@FiscalYear int = NULL,
	@FiscalPeriod int = NULL,
	@StartFiscalYear int = NULL,
	@SequenceBM int = 3, --1 = GL transactions, 2 = Opening balances, 4 = Budget transactions
	@JournalTable nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000637,
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
	@ProcedureName = 'spIU_DC_Journal_Navision',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "413"},
		{"TKey" : "VersionID",  "TValue": "1008"},
		{"TKey" : "Entity_MemberKey",  "TValue": "52982"},
		{"TKey" : "Book",  "TValue": "CBN_Main"}
		]',
	@Debug = 1

EXEC [spIU_DC_Journal_Navision] @UserID = -10, @InstanceID = 412, @VersionID = 1005, @Entity_MemberKey = '801', @Book = 'GL', @SequenceBM = 3, @Debug = 1, @FiscalYear = 2013, @FiscalPeriod = 5
EXEC [spIU_DC_Journal_Navision] @UserID = -10, @InstanceID = 412, @VersionID = 1005, @Entity_MemberKey = '801', @Book = 'GL', @SequenceBM = 3, @Debug = 1

EXEC [spIU_DC_Journal_Navision] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceDatabase nvarchar(100),
	@EntityID int,
	@Currency nchar(3),
	@Entity nvarchar(50),
	@TablePrefix nvarchar(100),
	@SQLStatement nvarchar(max),
	@SQLSegment nvarchar(max),
	@SegmentNo int = -1,
	@MinFiscalYear int,
	@MinYearMonth int,
	@AccountSegmentNo nchar(1),
	@SourceTypeID int = 8, --Navision

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into #Journal from source Navision.',
			@MandatoryParameter = 'Entity_MemberKey|Book' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2151' SET @Description = 'Updated datatypes in temp table #Journal.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'

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
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@StartFiscalYear = ISNULL(@StartFiscalYear, S.StartYear)
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0 AND S.SourceTypeID = @SourceTypeID
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		IF @Debug <> 0
			SELECT 
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@SourceDatabase] = @SourceDatabase,
				[@StartFiscalYear] = @StartFiscalYear,
				[@JournalTable] = @JournalTable

	SET @Step = 'Create table #DimensionSet'
		CREATE TABLE [dbo].[#DimensionSet]
			(
			[InstanceID] [int] NOT NULL,
			[Entity] [nvarchar](50) NOT NULL,
			[DimensionSetID] [int] NOT NULL,
			[DimensionID] [int] NOT NULL,
			[MemberKey] [nvarchar](50) NOT NULL,
			[ParentDimensionSetID] [int] NOT NULL,
			[CheckStatus] [int] NULL
			)

	SET @Step = 'Create temp table #Segment'
		CREATE TABLE #Segment
			(
			[DimensionSetID] int,
			[Segment01] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment02] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment03] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment04] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment05] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment06] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment07] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment08] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment09] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment10] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment11] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment12] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment13] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment14] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment15] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment16] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment17] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment18] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment19] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Segment20] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int
			)

	SET @Step = 'Create temp table #Journal'
		IF OBJECT_ID(N'TempDB.dbo.#Journal', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #Journal
					(
					[JobID] [int],
					[InstanceID] [int],
					[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Book] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] [int],
					[FiscalPeriod] [int],
					[JournalSequence] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[JournalNo] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[JournalLine] [int],
					[YearMonth] [int],
					[TransactionTypeBM] [int],
					[BalanceYN] [bit],
					[Account] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment01] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment02] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment03] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment04] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment05] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment06] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment07] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment08] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment09] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment10] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment11] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment12] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment13] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment14] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment15] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment16] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment17] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment18] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment19] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Segment20] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[JournalDate] [date],
					[TransactionDate] [date],
					[PostedDate] [date],
					[PostedStatus] [bit],
					[PostedBy] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[Source] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Description_Head] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Description_Line] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Currency_Book] [nchar](3) COLLATE DATABASE_DEFAULT,
					[ValueDebit_Book] [float],
					[ValueCredit_Book] [float],
					[SourceModule] [nvarchar](20) COLLATE DATABASE_DEFAULT,
					[SourceModuleReference] [nvarchar](20) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'Create #EntityCursorTable'
		CREATE TABLE #EntityCursorTable
			(
			EntityID int,
			Entity nvarchar(50) COLLATE DATABASE_DEFAULT,
			Currency nchar(3) COLLATE DATABASE_DEFAULT,
			TablePrefix nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #EntityCursorTable
			(
			EntityID,
			Entity,
			Currency,
			TablePrefix
			)
		SELECT
			EntityID = E.EntityID,
			Entity = E.MemberKey,
			Currency = EB.Currency,
			TablePrefix = EPV.EntityPropertyValue
		FROM
			Entity E
			INNER JOIN Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.EntityID = E.EntityID AND EB.Book = @Book AND EB.BookTypeBM & 1 > 0 AND EB.SelectYN <> 0
			INNER JOIN EntityPropertyValue EPV ON EPV.InstanceID = E.InstanceID AND EPV.EntityID = E.EntityID AND EPV.EntityPropertyTypeID = -3 AND EPV.SelectYN <> 0
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			(E.MemberKey = @Entity_MemberKey OR @Entity_MemberKey IS NULL) AND
			E.SelectYN <> 0 AND
			E.DeletedID IS NULL

		IF @Debug <> 0 SELECT TempTable = '#EntityCursorTable', * FROM #EntityCursorTable

		DECLARE Entity_Currency_Cursor CURSOR FOR
			SELECT
				EntityID,
				Entity,
				Currency,
				TablePrefix
			FROM
				#EntityCursorTable
			ORDER BY
				Entity
			
			OPEN Entity_Currency_Cursor
			FETCH NEXT FROM Entity_Currency_Cursor INTO @EntityID, @Entity, @Currency, @TablePrefix

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT EntityID = @EntityID, Entity = @Entity, Currency = @Currency, TablePrefix = @TablePrefix

					TRUNCATE TABLE #DimensionSet

					SET @SQLStatement = '
						INSERT INTO [#DimensionSet]
							(
							[InstanceID],
							[Entity],
							[DimensionSetID],
							[DimensionID],
							[MemberKey],
							[ParentDimensionSetID],
							[CheckStatus]
							)
						SELECT DISTINCT
							[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
							[Entity] = ''' + @Entity + ''',
							[DimensionSetID] = DSTN.[Dimension Set ID],
							[DimensionID] = D.DimensionID,
							[MemberKey] = DV.Code,
							[ParentDimensionSetID] = DSTN.[Parent Dimension Set ID],
							[CheckStatus] = CASE WHEN DSTN.[Parent Dimension Set ID] = 0 THEN 2 ELSE 0 END
						FROM
							' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Set Tree Node] DSTN 
							INNER JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'Dimension Value] DV ON DV.[Dimension Value ID] = DSTN.[Dimension Value ID]
							INNER JOIN Entity E ON E.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND E.MemberKey = ''' + @Entity + ''' AND E.SelectYN <> 0 AND E.DeletedID IS NULL
							INNER JOIN Journal_SegmentNo JSN ON JSN.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND JSN.[Entity] = ''' + @Entity + ''' AND JSN.Book = ''' + @Book + ''' AND JSN.SegmentCode = DV.[Dimension Code] COLLATE DATABASE_DEFAULT
							INNER JOIN Dimension D ON D.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND D.DimensionID = JSN.DimensionID'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					WHILE (SELECT COUNT(1) FROM [#DimensionSet] WHERE [CheckStatus] = 0) > 0
						BEGIN
							UPDATE [#DimensionSet] SET [CheckStatus] = 1 WHERE [CheckStatus] = 0

							INSERT INTO [#DimensionSet]
								(
								[InstanceID],
								[Entity],
								[DimensionSetID],
								[DimensionID],
								[MemberKey],
								[ParentDimensionSetID],
								[CheckStatus]
								)
							SELECT DISTINCT
								[InstanceID] = DS.InstanceID,
								[Entity] = @Entity,
								[DimensionSetID] = DS.[DimensionSetID],
								[DimensionID] = wrk_DS.DimensionID,
								[MemberKey] = wrk_DS.[MemberKey],
								[ParentDimensionSetID] = wrk_DS.[ParentDimensionSetID],
								[CheckStatus] = 0
							FROM
								[#DimensionSet] DS
								INNER JOIN [#DimensionSet] wrk_DS ON wrk_DS.InstanceID = DS.InstanceID AND wrk_DS.DimensionSetID = DS.ParentDimensionSetID
							WHERE
								DS.CheckStatus = 1

							UPDATE [#DimensionSet] SET [CheckStatus] = 2 WHERE [CheckStatus] = 1
						END

					TRUNCATE TABLE #Segment
					SET @SQLStatement = '
						INSERT INTO #Segment
							(
							[DimensionSetID],
							[Segment01],
							[Segment02],
							[Segment03],
							[Segment04],
							[Segment05],
							[Segment06],
							[Segment07],
							[Segment08],
							[Segment09],
							[Segment10],
							[Segment11],
							[Segment12],
							[Segment13],
							[Segment14],
							[Segment15],
							[Segment16],
							[Segment17],
							[Segment18],
							[Segment19],
							[Segment20]
							)
						SELECT 
							DS.DimensionSetID,
							[Segment01] = MAX(CASE WHEN JSN.SegmentNo =  1 THEN DS.MemberKey ELSE NULL END),
							[Segment02] = MAX(CASE WHEN JSN.SegmentNo =  2 THEN DS.MemberKey ELSE NULL END),
							[Segment03] = MAX(CASE WHEN JSN.SegmentNo =  3 THEN DS.MemberKey ELSE NULL END),
							[Segment04] = MAX(CASE WHEN JSN.SegmentNo =  4 THEN DS.MemberKey ELSE NULL END),
							[Segment05] = MAX(CASE WHEN JSN.SegmentNo =  5 THEN DS.MemberKey ELSE NULL END),
							[Segment06] = MAX(CASE WHEN JSN.SegmentNo =  6 THEN DS.MemberKey ELSE NULL END),
							[Segment07] = MAX(CASE WHEN JSN.SegmentNo =  7 THEN DS.MemberKey ELSE NULL END),
							[Segment08] = MAX(CASE WHEN JSN.SegmentNo =  8 THEN DS.MemberKey ELSE NULL END),
							[Segment09] = MAX(CASE WHEN JSN.SegmentNo =  9 THEN DS.MemberKey ELSE NULL END),
							[Segment10] = MAX(CASE WHEN JSN.SegmentNo = 10 THEN DS.MemberKey ELSE NULL END),
							[Segment11] = MAX(CASE WHEN JSN.SegmentNo = 11 THEN DS.MemberKey ELSE NULL END),
							[Segment12] = MAX(CASE WHEN JSN.SegmentNo = 12 THEN DS.MemberKey ELSE NULL END),
							[Segment13] = MAX(CASE WHEN JSN.SegmentNo = 13 THEN DS.MemberKey ELSE NULL END),
							[Segment14] = MAX(CASE WHEN JSN.SegmentNo = 14 THEN DS.MemberKey ELSE NULL END),
							[Segment15] = MAX(CASE WHEN JSN.SegmentNo = 15 THEN DS.MemberKey ELSE NULL END),
							[Segment16] = MAX(CASE WHEN JSN.SegmentNo = 16 THEN DS.MemberKey ELSE NULL END),
							[Segment17] = MAX(CASE WHEN JSN.SegmentNo = 17 THEN DS.MemberKey ELSE NULL END),
							[Segment18] = MAX(CASE WHEN JSN.SegmentNo = 18 THEN DS.MemberKey ELSE NULL END),
							[Segment19] = MAX(CASE WHEN JSN.SegmentNo = 19 THEN DS.MemberKey ELSE NULL END),
							[Segment20] = MAX(CASE WHEN JSN.SegmentNo = 20 THEN DS.MemberKey ELSE NULL END)
						FROM
							Journal_SegmentNo JSN
							INNER JOIN #DimensionSet DS ON DS.InstanceID = JSN.InstanceID AND DS.Entity = JSN.Entity AND DS.DimensionID = JSN.DimensionID
						WHERE
							JSN.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
							JSN.Entity = ''' + @Entity + ''' AND
							JSN.Book = ''' + @Book + '''
						GROUP BY
							DS.DimensionSetID
						ORDER BY
							DS.DimensionSetID'
						
					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					IF @Debug <> 0 SELECT TempTable = '#DimensionSet', * FROM [#DimensionSet]

					TRUNCATE TABLE #FiscalPeriod
					IF @Debug <> 0 SELECT UserID = @UserID, InstanceID = @InstanceID, VersionID = @VersionID, EntityID = @EntityID, Book = @Book, StartFiscalYear = @StartFiscalYear, FiscalYear = @FiscalYear, FiscalPeriod = @FiscalPeriod
					EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @FiscalPeriod = @FiscalPeriod, @JobID = @JobID
					IF @Debug <> 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth

	SET @Step = 'Insert transactions into temp table #Journal'
					IF @SequenceBM & 1 > 0
						BEGIN
							SET @SQLStatement = '
								INSERT INTO #Journal
									(
									[JobID],
									[InstanceID],
									[Entity],
									[Book],
									[FiscalYear],
									[FiscalPeriod],
									[JournalSequence],
									[JournalNo],
									[JournalLine],
									[YearMonth],
									[TransactionTypeBM],
									[BalanceYN],
									[Account],
									[Segment01],
									[Segment02],
									[Segment03],
									[Segment04],
									[Segment05],
									[Segment06],
									[Segment07],
									[Segment08],
									[Segment09],
									[Segment10],
									[Segment11],
									[Segment12],
									[Segment13],
									[Segment14],
									[Segment15],
									[Segment16],
									[Segment17],
									[Segment18],
									[Segment19],
									[Segment20],
									[JournalDate],
									[TransactionDate],
									[PostedDate],
									[PostedStatus],
									[PostedBy],
									[Source],
									[Scenario],
									[Description_Head],
									[Description_Line],
									[Currency_Book],
									[ValueDebit_Book],
									[ValueCredit_Book]
									)
								SELECT
									[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
									[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
									[Entity] = ''' + @Entity + ''',
									[Book] = ''' + @Book + ''',
									[FiscalYear] = FP.[FiscalYear],
									[FiscalPeriod] = FP.[FiscalPeriod],
									[JournalSequence] = (''NAV_'' + [No_ Series]),
									[JournalNo] = CONVERT(nvarchar(50), [Transaction No_]),
									[JournalLine] = [Entry No_],
									[YearMonth] = FP.[YearMonth],
									[TransactionTypeBM] = 1,
									[BalanceYN] = CASE WHEN A.[Income_Balance] = 1 THEN 1 ELSE 0 END,
									[Account] = [G_L Account No_],
									[Segment01] = S.[Segment01],
									[Segment02] = S.[Segment02],
									[Segment03] = S.[Segment03],
									[Segment04] = S.[Segment04],
									[Segment05] = S.[Segment05],
									[Segment06] = S.[Segment06],
									[Segment07] = S.[Segment07],
									[Segment08] = S.[Segment08],
									[Segment09] = S.[Segment09],
									[Segment10] = S.[Segment10],
									[Segment11] = S.[Segment11],
									[Segment12] = S.[Segment12],
									[Segment13] = S.[Segment13],
									[Segment14] = S.[Segment14],
									[Segment15] = S.[Segment15],
									[Segment16] = S.[Segment16],
									[Segment17] = S.[Segment17],
									[Segment18] = S.[Segment18],
									[Segment19] = S.[Segment19],
									[Segment20] = S.[Segment20],
									[JournalDate] = [Posting Date],
									[TransactionDate] = [Document Date],
									[PostedDate] = [Posting Date],
									[PostedStatus] = 1,
									[PostedBy] = [User ID],
									[Source] = ''NAV'',
									[Scenario] = ''ACTUAL'',
									[Description_Head] = [Description],
									[Description_Line] = [Description],
									[Currency_Book] = ''' + @Currency + ''',
									[ValueDebit_Book] = [Debit Amount],
									[ValueCredit_Book] = [Credit Amount]
								FROM
									' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'G_L Entry] GL
									INNER JOIN ' + @SourceDatabase + '.[dbo].[' + @TablePrefix + 'G_L Account] A ON A.[No_] = GL.[G_L Account No_]
									INNER JOIN #FiscalPeriod FP ON FP.[YearMonth] = Year(GL.[Posting Date]) * 100 + Month(GL.[Posting Date])
									LEFT JOIN #Segment S ON S.DimensionSetID = GL.[Dimension Set ID]'

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
						END

	SET @Step = 'Insert opening balances into temp table #Journal'
					IF @SequenceBM & 2 > 0
						BEGIN
							SET @Message = 'Opening balance not yet implemented'
						END

					FETCH NEXT FROM Entity_Currency_Cursor INTO @EntityID, @Entity, @Currency, @TablePrefix
				END

		CLOSE Entity_Currency_Cursor
		DEALLOCATE Entity_Currency_Cursor	

	SET @Step = 'Return rows'
		IF @CalledYN = 0
			BEGIN
				SELECT * FROM #Journal ORDER BY [InstanceID], [Entity], [Book], [FiscalYear], [FiscalPeriod], [JournalSequence], [JournalNo], [JournalLine]
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #FiscalPeriod
		DROP TABLE #Segment
		DROP TABLE #DimensionSet
		DROP TABLE #EntityCursorTable
		IF @CalledYN = 0 DROP TABLE #Journal

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
