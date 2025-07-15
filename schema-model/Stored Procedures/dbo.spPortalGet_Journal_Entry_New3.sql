SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Journal_Entry_New3] 
	@UserID INT = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ResultTypeBM int = 31, --1=DimensionList, 2=DimensionMember, 4=JournalHead, 8=JournalLine, 16=Valid segments, 32=Journal list, 64=Valid JournalSequence, 128=Valid TransactionDate
	
	@JournalID bigint = NULL,
	@Entity nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@JournalSequence nvarchar(50) = NULL,
	@JournalNo nvarchar(50) = NULL,
	@TransactionDate date = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000734,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

AS

/*
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"InstanceID","TValue":"529"},{"TKey":"UserID","TValue":"1134"},{"TKey":"VersionID","TValue":"1001"},{"TKey":"ResultTypeBM","TValue":"64"}]', @ProcedureName='spPortalGet_Journal_Entry'

EXEC spPortalGet_Journal_Entry @UserID=-10, @InstanceID=-1335, @VersionID=-1273, @ResultTypeBM=28, @Entity='ADAMS', @Book='MAIN', @FiscalYear=2019, @JournalSequence='GL', @JournalNo=1, @DebugBM=0
EXEC spPortalGet_Journal_Entry @UserID=-10, @InstanceID=-1335, @VersionID=-1273, @ResultTypeBM=28, @JournalID = 44547, @DebugBM=3
EXEC spPortalGet_Journal_Entry @UserID=-10, @InstanceID=-1335, @VersionID=-1273, @ResultTypeBM=28, @Entity='ADAMS', @Book='MAIN', @TransactionDate = '2019-12-12', @DebugBM=3
EXEC spPortalGet_Journal_Entry @UserID=-10, @InstanceID=-1335, @VersionID=-1273, @ResultTypeBM=32, @Entity='ADAMS', @Book='MAIN', @JournalSequence='GL', @DebugBM=3
EXEC spPortalGet_Journal_Entry @UserID=-10, @InstanceID=-1335, @VersionID=-1273, @ResultTypeBM=28, @JournalID = 253784
EXEC spPortalGet_Journal_Entry @UserID=-10, @InstanceID=-1335, @VersionID=-1273, @ResultTypeBM=28, @JournalID = 250082
EXEC spPortalGet_Journal_Entry_New3 @UserID=-10, @InstanceID=576, @VersionID=1082, @ResultTypeBM=3, @DebugBM=3

EXEC [dbo].[spPortalGet_Journal_Entry] @GetVersion = 1
*/

DECLARE
	@EntityID int,
	@SQLStatement nvarchar(max),
	@JournalTable nvarchar(100),
	@DataClassID int,
	@DimensionList nvarchar(1000) = '',
	@MasterClosedYear int,
	@FiscalPeriod int,

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2189'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return rows from Journal.',
			@MandatoryParameter = ''

		IF @Version = '2.1.0.2163' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2170' SET @Description = 'Made generic.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added DimensionName for ResultTypeBM = 16. Deleted hardcoded query. Modified query for @ResultTypeBM=64.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added parameter @UserID to call sub routines for @ResultTypeBM 1 and 2.'
		IF @Version = '2.1.2.2179' SET @Description = 'Handle alfanumeric Journal numbers.'
		IF @Version = '2.1.2.2189' SET @Description = 'Updated to new SP template.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1
	
		EXEC [pcINTEGRATOR].[dbo].[spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @JournalTable = @JournalTable OUT

		IF @DebugBM & 2 > 0 SELECT [@JournalTable] = @JournalTable

		IF @JournalID IS NOT NULL
			BEGIN
				SET @SQLStatement = '
					SELECT
						@InternalVariable1 = J.[Entity], 
						@InternalVariable2 = J.[Book], 
						@InternalVariable3 = J.[FiscalYear], 
						@InternalVariable4 = J.[JournalSequence], 
						@InternalVariable5 = J.[JournalNo] 
					FROM
						' + @JournalTable + ' J
					WHERE
						J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						J.[JournalID] = ' + CONVERT(nvarchar(20), @JournalID)

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC sp_executesql @SQLStatement, N'@InternalVariable1 nvarchar(50) OUT, @InternalVariable2 nvarchar(50) OUT, @InternalVariable3 int OUT, @InternalVariable4 nvarchar(50) OUT, @InternalVariable5 nvarchar(50) OUT', @InternalVariable1 = @Entity OUT, @InternalVariable2 = @Book OUT, @InternalVariable3 = @FiscalYear OUT, @InternalVariable4 = @JournalSequence OUT, @InternalVariable5 = @JournalNo OUT

			--SELECT
			--	@Entity = Entity,
			--	@Book = Book,
			--	@FiscalYear = FiscalYear,
			--	@JournalSequence = JournalSequence,
			--	@JournalNo = JournalNo
			--FROM
			--	pcETL_TECA..Journal
			--WHERE
			--	JournalID = @JournalID

			END

		IF @DebugBM & 2 > 0 SELECT [@JournalID] = @JournalID, [@Entity] = @Entity, [@Book] = @Book, [@FiscalYear] = @FiscalYear, [@JournalSequence] = @JournalSequence, [@JournalNo] = @JournalNo

		SELECT
			@EntityID = EntityID
		FROM
			pcINTEGRATOR_Data..Entity
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			MemberKey = @Entity AND
			SelectYN <> 0 AND
			DeletedID IS NULL

		EXEC [dbo].[spGet_MasterClosedYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @MasterClosedYear = @MasterClosedYear OUT, @JobID = @JobID

		IF @DebugBM & 2 > 0 SELECT [@MasterClosedYear] = @MasterClosedYear

		SET @MasterClosedYear = ISNULL(@MasterClosedYear, YEAR(GetDate()) -1)

		CREATE TABLE #FiscalPeriod
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int
			)
		
		EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear=@MasterClosedYear, @FiscalPeriod13YN = 1, @JobID = @JobID

		IF @DebugBM & 2 > 0 SELECT * FROM #FiscalPeriod ORDER BY FiscalYear, FiscalPeriod

		IF @FiscalYear IS NULL AND @TransactionDate IS NOT NULL
			BEGIN
				SELECT
					@FiscalYear = ISNULL(@FiscalYear, FiscalYear),
					@FiscalPeriod = ISNULL(@FiscalPeriod, FiscalPeriod)
				FROM
					#FiscalPeriod
				WHERE
					YEAR(@TransactionDate) * 100 + MONTH(@TransactionDate) = YearMonth
			END

		SELECT
			@DataClassID = DC.[DataClassID]
		FROM
			pcINTEGRATOR_Data..DataClass DC
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.VersionID = @VersionID AND
			DC.DataClassTypeID = -5 AND
			DC.SelectYN <> 0 AND
			DC.DeletedID IS NULL


		IF @DebugBM & 2 > 0 
			SELECT 
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@DataClassID] = @DataClassID,
				[@JournalTable] = @JournalTable,
				[@JournalID] = @JournalID,
				[@Entity] = @Entity,
				[@Book] = @Book,
				[@FiscalYear] = @FiscalYear,
				[@JournalSequence] = @JournalSequence,
				[@JournalNo] = @JournalNo

	SET @Step = 'Fill table #SegmentsList'
		IF @ResultTypeBM & 19 > 0
			BEGIN
				SELECT
					[SegmentNo] = 'Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), JSN.[SegmentNo]),
					[SegmentName] = JSN.[SegmentName],
					[DimensionID] = JSN.[DimensionID],
					[DimensionName] = D.[DimensionName]
				INTO
					#SegmentsList
				FROM
					pcINTEGRATOR_Data..Journal_SegmentNo JSN
					INNER JOIN pcINTEGRATOR..[Dimension] D ON D.[DimensionID] = JSN.[DimensionID]
				WHERE
					JSN.[InstanceID] = @InstanceID AND
					JSN.[VersionID] = @VersionID AND
					JSN.[EntityID] = @EntityID AND
					JSN.[Book] = @Book AND
					JSN.[SelectYN] <> 0 AND
					JSN.[SegmentNo] > 0
				ORDER BY
					JSN.[SegmentNo]

				IF @DebugBM & 2 > 0 SELECT TempTable = '#SegmentsList', * FROM #SegmentsList
			END

	SET @Step = 'Set @DimensionList'
		IF @ResultTypeBM & 3 > 0
			BEGIN
				SET @DimensionList = '-1|-4|-6|-34|-31|-35'

				SELECT
					@DimensionList = @DimensionList + '|' + CONVERT(nvarchar(15), [DimensionID])
				FROM
					#SegmentsList
				ORDER BY
					[SegmentNo]
			END

	SET @Step = 'Get Dimension list'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				EXEC [pcINTEGRATOR].[dbo].[spGet_DataClass_DimensionList] @UserID = @UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID=@DataClassID, @ResultTypeBM=1, @DimensionList = @DimensionList, @JobID=@JobID, @Debug=@DebugSub
			END

	SET @Step = 'Get Dimension members'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				EXEC [pcINTEGRATOR].[dbo].[spGet_DataClass_DimensionMember] @UserID = @UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID=@DataClassID, @DimensionList = @DimensionList, @ShowAllMembersYN=1, @UseCacheYN=0, @JobID=@JobID, @Debug=@DebugSub
			END

	SET @Step = 'Get Journal head'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 4,
						[JournalID] = MIN(J.[JournalID]),
						[Entity] = J.[Entity],
						[Book] = J.[Book],
						[JournalSequence] = J.[JournalSequence],
						[JournalNo] = J.[JournalNo],
						[Currency] = MAX(J.[Currency_Book]),
						[FiscalYear] = J.[FiscalYear],
						[FiscalPeriod] = MAX(J.[FiscalPeriod]),
						[TransactionDate] = MAX(J.[TransactionDate]),
						[Description_Head] = MAX(J.[Description_Head]),
						[Posted] = CONVERT(bit, MAX(CONVERT(int, J.[PostedStatus]))),
						[PostedDate] = MAX(J.[PostedDate]),
						[PostedBy] = MAX(J.[PostedBy]),
						[Scenario] = MAX(J.[Scenario]),
						[CreatedDate] = MAX(J.[JournalDate]),
						[CreatedBy] = MAX(J.[InsertedBy]),
						[Source] = MAX(J.[Source])
					FROM
						' + @JournalTable + ' J
					WHERE
						' + CASE WHEN @JournalID IS NOT NULL THEN 'J.[JournalID] = ' + CONVERT(nvarchar(15), @JournalID) + ' AND' ELSE '' END + '
						J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						J.[Entity] = ''' + @Entity + ''' AND
						J.[Book] = ''' + @Book + ''' AND
						J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
						J.[JournalSequence] = ''' + @JournalSequence + ''' AND
						J.[JournalNo] = ''' + @JournalNo + '''
					GROUP BY
						J.[Entity],
						J.[Book],
						J.[FiscalYear],
						J.[JournalSequence],
						J.[JournalNo]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Fill temp table #JournalLine'
		IF @ResultTypeBM & 24 > 0
			BEGIN
				CREATE TABLE #JournalLine
					(
					[JournalID] bigint,
					[JournalLine] [int],
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
					[Flow] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[InterCompany] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Description_Line] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Debit] [float],
					[Credit] [float]
					)
			
				SET @SQLStatement = '
					INSERT INTO #JournalLine
						(
						[JournalID],
						[JournalLine],
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
						[Flow],
						[InterCompany],
						[Description_Line],
						[Debit],
						[Credit]
						)
					SELECT
						[JournalID] = J.[JournalID],
						[JournalLine] = J.[JournalLine],
						[Account] = J.[Account],
						[Segment01] = J.[Segment01],
						[Segment02] = J.[Segment02],
						[Segment03] = J.[Segment03],
						[Segment04] = J.[Segment04],
						[Segment05] = J.[Segment05],
						[Segment06] = J.[Segment06],
						[Segment07] = J.[Segment07],
						[Segment08] = J.[Segment08],
						[Segment09] = J.[Segment09],
						[Segment10] = J.[Segment10],
						[Segment11] = J.[Segment11],
						[Segment12] = J.[Segment12],
						[Segment13] = J.[Segment13],
						[Segment14] = J.[Segment14],
						[Segment15] = J.[Segment15],
						[Segment16] = J.[Segment16],
						[Segment17] = J.[Segment17],
						[Segment18] = J.[Segment18],
						[Segment19] = J.[Segment19],
						[Segment20] = J.[Segment20],
						[Flow] = J.[Flow],
						[InterCompany] = J.[InterCompanyEntity],
						[Description_Line] = J.[Description_Line],
						[Debit] = J.[ValueDebit_Book],
						[Credit] = J.[ValueCredit_Book]
					FROM
						' + @JournalTable + ' J
					WHERE
						J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						J.[Entity] = ''' + @Entity + ''' AND
						J.[Book] = ''' + @Book + ''' AND
						J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
						J.[JournalSequence] = ''' + @JournalSequence + ''' AND
						J.[JournalNo] = ''' + @JournalNo + ''' AND
						J.[JournalLine] <> -1'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END
--						' + CASE WHEN @JournalID IS NOT NULL THEN 'J.[JournalID] = ' + CONVERT(nvarchar(15), @JournalID) + ' AND' ELSE '' END + '

	SET @Step = 'Get Journal lines'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 8,
					[JournalID] = JL.[JournalID],
					[JournalLine] = JL.[JournalLine],
					[Account] = JL.[Account],
					[Segment01] = ISNULL(CASE WHEN JL.[Segment01] = '' THEN NULL ELSE JL.[Segment01] END, 'NONE'),
					[Segment02] = ISNULL(CASE WHEN JL.[Segment02] = '' THEN NULL ELSE JL.[Segment02] END, 'NONE'),
					[Segment03] = ISNULL(CASE WHEN JL.[Segment03] = '' THEN NULL ELSE JL.[Segment03] END, 'NONE'),
					[Segment04] = ISNULL(CASE WHEN JL.[Segment04] = '' THEN NULL ELSE JL.[Segment04] END, 'NONE'),
					[Segment05] = ISNULL(CASE WHEN JL.[Segment05] = '' THEN NULL ELSE JL.[Segment05] END, 'NONE'),
					[Segment06] = ISNULL(CASE WHEN JL.[Segment06] = '' THEN NULL ELSE JL.[Segment06] END, 'NONE'),
					[Segment07] = ISNULL(CASE WHEN JL.[Segment07] = '' THEN NULL ELSE JL.[Segment07] END, 'NONE'),
					[Segment08] = ISNULL(CASE WHEN JL.[Segment08] = '' THEN NULL ELSE JL.[Segment08] END, 'NONE'),
					[Segment09] = ISNULL(CASE WHEN JL.[Segment09] = '' THEN NULL ELSE JL.[Segment09] END, 'NONE'),
					[Segment10] = ISNULL(CASE WHEN JL.[Segment10] = '' THEN NULL ELSE JL.[Segment10] END, 'NONE'),
					[Segment11] = ISNULL(CASE WHEN JL.[Segment11] = '' THEN NULL ELSE JL.[Segment11] END, 'NONE'),
					[Segment12] = ISNULL(CASE WHEN JL.[Segment12] = '' THEN NULL ELSE JL.[Segment12] END, 'NONE'),
					[Segment13] = ISNULL(CASE WHEN JL.[Segment13] = '' THEN NULL ELSE JL.[Segment13] END, 'NONE'),
					[Segment14] = ISNULL(CASE WHEN JL.[Segment14] = '' THEN NULL ELSE JL.[Segment14] END, 'NONE'),
					[Segment15] = ISNULL(CASE WHEN JL.[Segment15] = '' THEN NULL ELSE JL.[Segment15] END, 'NONE'),
					[Segment16] = ISNULL(CASE WHEN JL.[Segment16] = '' THEN NULL ELSE JL.[Segment16] END, 'NONE'),
					[Segment17] = ISNULL(CASE WHEN JL.[Segment17] = '' THEN NULL ELSE JL.[Segment17] END, 'NONE'),
					[Segment18] = ISNULL(CASE WHEN JL.[Segment18] = '' THEN NULL ELSE JL.[Segment18] END, 'NONE'),
					[Segment19] = ISNULL(CASE WHEN JL.[Segment19] = '' THEN NULL ELSE JL.[Segment19] END, 'NONE'),
					[Segment20] = ISNULL(CASE WHEN JL.[Segment20] = '' THEN NULL ELSE JL.[Segment20] END, 'NONE'),
					[InterCompany] = ISNULL(CASE WHEN JL.[InterCompany] = '' THEN NULL ELSE JL.[InterCompany] END, 'NONE'),
					[Flow] = ISNULL(CASE WHEN JL.[Flow] = '' THEN NULL ELSE JL.[Flow] END, 'NONE'),
					[Description_Line] = JL.[Description_Line],
					[Debit] = CASE WHEN JL.[Debit] = 0 THEN '' ELSE JL.[Debit] END,
					[Credit] = CASE WHEN JL.[Credit] = 0 THEN '' ELSE JL.[Credit] END
				FROM
					#JournalLine JL
				ORDER BY
					JL.[JournalLine]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of segments'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 16,
					[SegmentNo] = SL.[SegmentNo],
					[SegmentName] = MAX(SL.[SegmentName]),
					[DimensionID] = MAX(SL.[DimensionID]),
					[DimensionName] = MAX(SL.[DimensionName]),
					[ByLineYN] = CONVERT(bit, CASE SL.[SegmentNo]
									WHEN 'Segment01' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment01]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment02' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment02]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment03' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment03]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment04' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment04]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment05' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment05]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment06' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment06]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment07' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment07]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment08' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment08]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment09' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment09]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment10' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment10]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment11' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment11]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment12' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment12]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment13' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment13]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment14' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment14]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment15' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment15]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment16' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment16]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment17' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment17]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment18' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment18]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment19' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment19]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
									WHEN 'Segment20' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment20]) FROM #JournalLine) <= 1 THEN 0 ELSE 1 END
								END),
					[Default] = CASE SL.[SegmentNo]
									WHEN 'Segment01' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment01]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment01]), '') = '' THEN 'NONE' ELSE MAX([Segment01]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment02' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment02]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment02]), '') = '' THEN 'NONE' ELSE MAX([Segment02]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment03' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment03]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment03]), '') = '' THEN 'NONE' ELSE MAX([Segment03]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment04' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment04]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment04]), '') = '' THEN 'NONE' ELSE MAX([Segment04]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment05' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment05]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment05]), '') = '' THEN 'NONE' ELSE MAX([Segment05]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment06' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment06]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment06]), '') = '' THEN 'NONE' ELSE MAX([Segment06]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment07' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment07]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment07]), '') = '' THEN 'NONE' ELSE MAX([Segment07]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment08' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment08]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment08]), '') = '' THEN 'NONE' ELSE MAX([Segment08]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment09' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment09]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment09]), '') = '' THEN 'NONE' ELSE MAX([Segment09]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment10' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment10]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment10]), '') = '' THEN 'NONE' ELSE MAX([Segment10]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment11' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment11]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment11]), '') = '' THEN 'NONE' ELSE MAX([Segment11]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment12' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment12]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment12]), '') = '' THEN 'NONE' ELSE MAX([Segment12]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment13' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment13]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment13]), '') = '' THEN 'NONE' ELSE MAX([Segment13]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment14' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment14]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment14]), '') = '' THEN 'NONE' ELSE MAX([Segment14]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment15' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment15]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment15]), '') = '' THEN 'NONE' ELSE MAX([Segment15]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment16' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment16]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment16]), '') = '' THEN 'NONE' ELSE MAX([Segment16]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment17' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment17]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment17]), '') = '' THEN 'NONE' ELSE MAX([Segment17]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment18' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment18]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment18]), '') = '' THEN 'NONE' ELSE MAX([Segment18]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment19' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment19]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment19]), '') = '' THEN 'NONE' ELSE MAX([Segment19]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
									WHEN 'Segment20' THEN CASE WHEN (SELECT COUNT(DISTINCT [Segment20]) FROM #JournalLine) = 1 THEN (SELECT CASE WHEN ISNULL(MAX([Segment20]), '') = '' THEN 'NONE' ELSE MAX([Segment20]) END FROM #JournalLine) ELSE MAX(DST.[DefaultSetMemberKey]) END
								END
				FROM
					#SegmentsList SL
					INNER JOIN pcINTEGRATOR_Data..Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = SL.DimensionID
				GROUP BY
					SL.[SegmentNo]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get Journal List'
		IF @ResultTypeBM & 32 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT TOP 1000
						[ResultTypeBM] = 32,
						[JournalID] = MIN(J.[JournalID]),
						[JournalSequence] = J.[JournalSequence],
						[JournalNo] = J.[JournalNo],
						[TransactionDate] = MAX(J.[TransactionDate]),
						[FiscalYear] = J.[FiscalYear],
						[FiscalPeriod] = MAX(J.[FiscalPeriod]),
						[Description_Head] = MAX(J.[Description_Head]),
						[Posted] = CONVERT(bit, MAX(CONVERT(int, J.[PostedStatus])))
					FROM
						' + @JournalTable + ' J
					WHERE
						J.[JournalSequence] IN (''CONS'', ''IFRS16'', ''GROUPADJ'') AND
						J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						J.[Entity] = ''' + @Entity + ''' AND
						J.[Book] = ''' + @Book + '''
						' + CASE WHEN @JournalSequence IS NOT NULL THEN ' AND J.[JournalSequence] = ''' + @JournalSequence + '''' ELSE '' END + '
						' + CASE WHEN @FiscalYear IS NOT NULL THEN ' AND J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) ELSE '' END + '
						' + CASE WHEN @JournalNo IS NOT NULL THEN ' AND J.[JournalNo] = ''' + @JournalNo + '''' ELSE '' END + '
					GROUP BY
						J.[Entity],
						J.[Book],
						J.[FiscalYear],
						J.[JournalSequence],
						J.[JournalNo]
					ORDER BY
						J.[Entity],
						J.[Book],
						MAX(J.[TransactionDate]) DESC,
						J.[FiscalYear] DESC,
						MAX(J.[FiscalPeriod]) DESC,
						J.[JournalSequence],
						J.[JournalNo]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of valid Journal Sequences'
		IF @ResultTypeBM & 64 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 64,
					[JournalSequence] = 'CONS',
					[Description] = 'Consolidation'
				UNION SELECT
					[ResultTypeBM] = 64,
					[JournalSequence] = 'IFRS16',
					[Description] = 'IFRS 16 adjustments'
					--[JournalSequence] = 'GL',
					--[Description] = 'General Ledger'

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get list of valid transaction dates (based on FiscalYear and FiscalPeriod)'
		IF @ResultTypeBM & 128 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 128,
					[FiscalYear] = 2019,
					[FiscalPeriod] = 12,
					[YearMonth] = 201912,
					[TransactionDate] = '2019-12-31'

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
