SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
create PROCEDURE [dbo].[spPortalSet_Journal_Entry_20231114]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JSON_table nvarchar(MAX) = NULL,
	@JournalID bigint = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000735,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"InstanceID","TValue":"529"},{"TKey":"UserID","TValue":"1002"},{"TKey":"VersionID","TValue":"1001"}]', @JSON_table='[{"ResultTypeBM":"4","Entity":"21","Book":"GL","JournalSequence":"CONS","TransactionDate":"2021-04-22","Description_Head":""}]', @ProcedureName='spPortalSet_Journal_Entry', @XML=null

--4=Journal Head, 8=Journal Line
DECLARE
	@JSON_table nvarchar(MAX) = '
	[
	{"ResultTypeBM" : "4", "Entity": "ADAMS", "Book": "MAIN", "TransactionDate": "2019-12-12", "JournalSequence": "TESTING", "Description_Head": "Description of testing"}
	]'

EXEC [dbo].[spPortalSet_Journal_Entry] 
	@UserID = -10,
	@InstanceID = -1335,
	@VersionID = -1273,
	@DebugBM = 0,
	@JSON_table = @JSON_table

--Insert lines
DECLARE
	@JSON_table nvarchar(MAX) = '
	[
	{"ResultTypeBM" : "4", "JournalID": "253770", "Posted":"0"},
	{"ResultTypeBM" : "8", "JournalLine": "1", "Account": "650390", "Segment01": "ADAM","Segment02": "1", "Segment03": "01","Segment04": "NONE", "Segment05": "NONE","Segment06": "NONE", "Segment07": "NONE", "Debit": "103.45", "Credit": "0", "Description_Line": "Description of testing Line 1"},
	{"ResultTypeBM" : "8", "JournalLine": "2", "Account": "650390", "Segment01": "ADAM","Segment02": "1", "Segment03": "01","Segment04": "NONE", "Segment05": "NONE","Segment06": "NONE", "Segment07": "NONE", "Debit": "0", "Credit": "103.45", "Description_Line": "Description of testing Line 2"}
	]'

EXEC [dbo].[spPortalSet_Journal_Entry] 
	@UserID = -10,
	@InstanceID = -1335,
	@VersionID = -1273,
	@DebugBM = 3,
	@JSON_table = @JSON_table

--Update lines
DECLARE
	@JSON_table nvarchar(MAX) = '
	[
	{"ResultTypeBM" : "4", "JournalID": "253770", "Posted":"0"},
	{"ResultTypeBM" : "8", "JournalID": "253803", "Account": "650390", "Segment01": "ADAM","Segment02": "1", "Segment03": "01","Segment04": "NONE", "Segment05": "NONE","Segment06": "NONE", "Segment07": "NONE", "Debit": "103.45", "Credit": "0", "Description_Line": "Description of testing Line 1"},
	{"ResultTypeBM" : "8", "JournalID": "253804", "Account": "650390", "Segment01": "ADAM","Segment02": "1", "Segment03": "01","Segment04": "NONE", "Segment05": "NONE","Segment06": "NONE", "Segment07": "NONE", "Debit": "0", "Credit": "103.45", "Description_Line": "Description of testing Line 2"}
	]'

EXEC [dbo].[spPortalSet_Journal_Entry] 
	@UserID = -10,
	@InstanceID = -1335,
	@VersionID = -1273,
	@DebugBM = 3,
	@JSON_table = @JSON_table

EXEC [spPortalSet_Journal_Entry] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@EntityID int,
	@DeletedID int,
	@Group nvarchar(50),
	@Entity nvarchar(50),
	@Book nvarchar(50),
	@MasterClosedYear int,
	@CallistoDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@JournalNo int,
	@Posted bit,
	@JournalTable nvarchar(100),
	@Currency nvarchar(3),
	@AccountList nvarchar(1000) = '',
	@CommandStringGeneric nvarchar(4000),
	@FiscalYear int,
	@GroupYN bit,

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
	@Version nvarchar(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Add, update and delete rows in Journal',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2163' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2170' SET @Description = 'Made faster by using ColumnStoreIndex and temp tables.'
		IF @Version = '2.1.1.2171' SET @Description = 'Replaced hardcoded queries to generic.'
		IF @Version = '2.1.1.2172' SET @Description = 'Modified INSERT query to temp tables #NE, #UH and #J. Enhanced debugging.'
		IF @Version = '2.1.1.2173' SET @Description = 'Set correct JournalNo in temp table #J.'
		IF @Version = '2.1.2.2179' SET @Description = 'If MasterClosedYear is null, set to Current year - 5 when filling temp table #FiscalPeriod. Set TransactionTypeBM = 16. Handle alfanumeric Journal numbers. Calculate carry forward for manually entries.'
		IF @Version = '2.1.2.2183' SET @Description = 'Make it possible to unpost already posted JournalNo'
		IF @Version = '2.1.2.2189' SET @Description = 'Updated to new SP template.'
		IF @Version = '2.1.2.2196' SET @Description = 'Handle Group adjustments.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Start Job'
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		IF @JobID IS NULL
			EXEC [spSet_Job]
				@UserID=@UserID,
				@InstanceID=@InstanceID,
				@VersionID=@VersionID,
				@ActionType='Start',
				@MasterCommand=@ProcedureName,
				@CurrentCommand=@ProcedureName,
				@JobQueueYN=1,
				@CheckCount = 0,
				@JobID=@JobID OUT

	SET @Step = 'Set procedure variables'
		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserNameDisplay = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			pcINTEGRATOR_Data..[Application] A
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			SelectYN <> 0

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @JournalTable = @JournalTable OUT

		IF @DebugBM & 2 > 0 SELECT [@CallistoDatabase]=@CallistoDatabase, [@JournalTable]=@JournalTable

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Create and fill #Journal'
		CREATE TABLE #Journal
			(
			[ResultTypeBM] int,
			[JournalID] bigint,
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
			[Posted] [bit],
			[PostedBy] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[Source] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Flow] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[ConsolidationGroup] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[InterCompany] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[Description_Head] [nvarchar](255) COLLATE DATABASE_DEFAULT,
			[Description_Line] [nvarchar](255) COLLATE DATABASE_DEFAULT,
			[Currency] [nchar](3) COLLATE DATABASE_DEFAULT,
			[Debit] [float],
			[Credit] [float],
			[SourceModule] [nvarchar](20) COLLATE DATABASE_DEFAULT,
			[SourceModuleReference] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[DeleteYN] bit
			)

		IF @JSON_table IS NOT NULL	
			BEGIN
				INSERT INTO #Journal
					(
					[ResultTypeBM],
					[JournalID],
					[Entity],
					[Book],
					[FiscalYear],
					[FiscalPeriod], 
					[JournalSequence],
					[JournalNo],
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
					[TransactionDate],
					[PostedDate],
					[Posted],
					[Source],
					[Flow],
					[ConsolidationGroup],
					[InterCompany],
					[Scenario],
					[Description_Head],
					[Description_Line],
					[Currency],
					[Debit],
					[Credit],
					[SourceModule],
					[DeleteYN]				
					)
				SELECT
					[ResultTypeBM],
					[JournalID],
					[Entity],
					[Book],
					[FiscalYear],
					[FiscalPeriod], 
					[JournalSequence],
					[JournalNo],
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
					[TransactionDate],
					[PostedDate],
					[Posted],
					[Source],
					[Flow],
					[ConsolidationGroup] = ISNULL([Group], 'NONE'),
					[InterCompany],
					[Scenario],
					[Description_Head],
					[Description_Line],
					[Currency],
					[Debit],
					[Credit],
					[SourceModule],
					[DeleteYN] = ISNULL([DeleteYN], 0)
				FROM
					OPENJSON(@JSON_table)
				WITH
					(
					[ResultTypeBM] int,
					[JournalID] bigint,
					[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Book] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[FiscalYear] [int],
					[FiscalPeriod] [int],
					[JournalSequence] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[JournalNo] [nvarchar](50) COLLATE DATABASE_DEFAULT,
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
					[TransactionDate] [date],
					[PostedDate] [date],
					[Posted] [bit],
					[Source] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Flow] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Group] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[InterCompany] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Description_Head] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Description_Line] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Currency] [nchar](3) COLLATE DATABASE_DEFAULT,
					[Debit] [float],
					[Credit] [float],
					[SourceModule] [nvarchar](20) COLLATE DATABASE_DEFAULT,
					[DeleteYN] bit	
					)
			END
		ELSE
			GOTO EXITPOINT

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Journal (Step 1)', * FROM #Journal

	SET @Step = 'Set variable @Group' 
		SELECT
			@Group = MAX([ConsolidationGroup])
		FROM
			#Journal
		WHERE
			[ResultTypeBM] & 4 > 0

		SET @GroupYN = CASE WHEN @Group = 'NONE' THEN 0 ELSE 1 END

		IF @DebugBM & 2 > 0 SELECT [@GroupYN] = @GroupYN, [@Group] = @Group

	SET @Step = 'Create and fill temp table #Balance' 
		CREATE TABLE #Balance
			(
			Account nvarchar(100),
			BalanceYN bit
			)
	
		SELECT
			@AccountList = @AccountList + '''' + sub.[Account] + ''','
		FROM
			(
			SELECT DISTINCT
				[Account]
			FROM
				#Journal
			WHERE
				LEN([Account]) > 0
			) sub
		ORDER BY
			sub.[Account]

		IF @DebugBM & 2 > 0 SELECT [@AccountList] = @AccountList
		
		SET @SQLStatement = '
			INSERT INTO #Balance
				(
				Account,
				BalanceYN
				)
			SELECT
				Account = [Label],
				BalanceYN = [TimeBalance]
			FROM
				' + @CallistoDatabase + '.[dbo].[S_DS_Account]
			WHERE
				' + CASE WHEN LEN(@AccountList) > 0 THEN '[Label] IN (' + @AccountList + '''''' + ') AND' ELSE '' END + '
				1 = 1'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)
		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Balance', * FROM #Balance
	
		UPDATE TJ
		SET
			[BalanceYN] = ISNULL(TJ.[BalanceYN], B.[BalanceYN])
		FROM
			#Journal TJ
			INNER JOIN #Balance B ON B.[Account] = TJ.[Account]

		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 2)', * FROM #Journal

	SET @Step = 'Update temp table #Journal'
		SET @SQLStatement = '
			UPDATE TJ
			SET
				[Entity] = ISNULL(TJ.[Entity], J.[Entity]),
				[Book] = ISNULL(TJ.[Book], J.[Book]),
				[FiscalYear] = ISNULL(TJ.[FiscalYear], J.[FiscalYear]),
				[FiscalPeriod] = ISNULL(TJ.[FiscalPeriod], J.[FiscalPeriod]),
				[JournalSequence] = ISNULL(TJ.[JournalSequence], J.[JournalSequence]),
				[JournalNo] = ISNULL(TJ.[JournalNo], J.[JournalNo]),
				[JournalLine] = ISNULL(TJ.[JournalLine], J.[JournalLine])
			FROM
				#Journal TJ
				INNER JOIN ' + @JournalTable + ' J ON J.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND J.JournalID = TJ.JournalID
			WHERE
				TJ.JournalID IS NOT NULL'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 3)', * FROM #Journal

		SET @SQLStatement = '
			UPDATE TJ
			SET
				[Entity] = ISNULL(TJ.[Entity], J.[Entity]),
				[Book] = ISNULL(TJ.[Book], J.[Book]),
				[FiscalYear] = ISNULL(TJ.[FiscalYear], J.[FiscalYear]),
				[FiscalPeriod] = ISNULL(TJ.[FiscalPeriod], J.[FiscalPeriod]),
				[JournalSequence] = ISNULL(TJ.[JournalSequence], J.[JournalSequence]),
				[JournalNo] = ISNULL(TJ.[JournalNo], J.[JournalNo]),
				[JournalDate] = ISNULL(TJ.[JournalDate], J.[JournalDate]),
				[TransactionDate] = ISNULL(TJ.[TransactionDate], J.[TransactionDate]),
				[YearMonth] = ISNULL(TJ.[YearMonth], J.[YearMonth]),
				[Posted] = ISNULL(TJ.[Posted], J.[Posted])
			FROM
				#Journal TJ
				INNER JOIN
					(
					SELECT
						[Entity] = ISNULL(TJ.[Entity], J.[Entity]),
						[Book] = ISNULL(TJ.[Book], J.[Book]),
						[FiscalYear] = ISNULL(TJ.[FiscalYear], J.[FiscalYear]),
						[FiscalPeriod] = ISNULL(TJ.[FiscalPeriod], J.[FiscalPeriod]),
						[JournalSequence] = ISNULL(TJ.[JournalSequence], J.[JournalSequence]),
						[JournalNo] = ISNULL(TJ.[JournalNo], J.[JournalNo]),
						[JournalDate] = ISNULL(TJ.[JournalDate], J.[JournalDate]),
						[TransactionDate] = ISNULL(TJ.[TransactionDate], J.[TransactionDate]),
						[YearMonth] = ISNULL(TJ.[YearMonth], J.[YearMonth]),
						[Posted] = ISNULL(TJ.[Posted], J.[PostedStatus])
					FROM
						#Journal TJ
						LEFT JOIN ' + @JournalTable + ' J ON J.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND J.JournalID = TJ.JournalID
					WHERE
						TJ.ResultTypeBM & 4 > 0
					) J ON 1 = 1
			WHERE
				TJ.[ResultTypeBM] & 8 > 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 4)', * FROM #Journal

		SET @SQLStatement = '
			UPDATE TJ
			SET
				[JournalID] = ISNULL(TJ.JournalID, J.JournalID)
			FROM
				#Journal TJ
				INNER JOIN ' + @JournalTable + ' J ON
					J.[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND
					J.[Entity] = TJ.[Entity] AND
					J.[Book] = TJ.[Book] AND
					J.[FiscalYear] = TJ.[FiscalYear] AND
					J.[FiscalPeriod] = TJ.[FiscalPeriod] AND
					J.[JournalSequence] = TJ.[JournalSequence] AND
					J.[JournalNo] = TJ.[JournalNo] AND
					J.[JournalLine] = TJ.[JournalLine]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 5)', * FROM #Journal

	SET @Step = 'Set YearMonth'
		SELECT
			@Entity = MAX([Entity]),
			@Book = MAX([Book])
		FROM
			#Journal
		
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

		EXEC [dbo].[spGet_MasterClosedYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @MasterClosedYear = @MasterClosedYear OUT, @JobID=@JobID

		SET @MasterClosedYear = ISNULL(@MasterClosedYear, YEAR(GetDate()) -5)

		CREATE TABLE #FiscalPeriod
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int
			)
		
		EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear=@MasterClosedYear, @FiscalPeriod13YN = 1, @JobID=@JobID

		IF @DebugBM & 8 > 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY FiscalYear, FiscalPeriod

		UPDATE TJ
		SET
			[FiscalYear] = ISNULL(TJ.[FiscalYear], sub.[FiscalYear]),
			[FiscalPeriod] = ISNULL(TJ.[FiscalPeriod], sub.[FiscalPeriod]),
			[YearMonth] = ISNULL(TJ.[YearMonth], sub.[YearMonth])
		FROM
			#Journal TJ
			INNER JOIN
				(
				SELECT
					[TransactionDate] = TJ.[TransactionDate],
					[FiscalYear] = MIN(FP.[FiscalYear]),
					[FiscalPeriod] = MIN(FP.[FiscalPeriod]),
					[YearMonth] = MIN(FP.[YearMonth])
				FROM
					#Journal TJ
					INNER JOIN #FiscalPeriod FP ON FP.YearMonth = YEAR(TJ.[TransactionDate]) * 100 + MONTH(TJ.[TransactionDate])
				GROUP BY
					TJ.[TransactionDate]
				) sub ON sub.[TransactionDate] = TJ.[TransactionDate]

		UPDATE TJ
		SET
			[YearMonth] = ISNULL(TJ.[YearMonth], FP.[YearMonth])
		FROM
			#Journal TJ
			INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = TJ.[FiscalYear] AND FP.[FiscalPeriod] = TJ.[FiscalPeriod]

		IF @GroupYN = 0
			SELECT
				@Currency = [Currency]
			FROM
				pcINTEGRATOR_Data..Entity_Book EB
			WHERE
				[InstanceID] = @InstanceID AND
				[VersionID] = @VersionID AND
				[EntityID] = @EntityID AND
				[Book] = @Book AND
				[SelectYN] <> 0
		ELSE
			SELECT
				@Currency = EB.[Currency]
			FROM
				pcINTEGRATOR_Data..Entity E
				INNER JOIN pcINTEGRATOR_Data..Entity_Book EB ON EB.EntityID = E.EntityID AND EB.BookTypeBM & 16 > 0 AND EB.SelectYN <> 0
			WHERE
				E.[InstanceID] = @InstanceID AND
				E.[VersionID] = @VersionID AND
				E.[MemberKey] = @Group AND
				E.EntityTypeID = 0 AND
				E.SelectYN <> 0 AND
				E.DeletedID IS NULL

		IF @DebugBM & 2 > 0 SELECT [@Currency] = @Currency

		UPDATE TJ
		SET
			[TransactionTypeBM] = ISNULL(TJ.[TransactionTypeBM], CASE WHEN ResultTypeBM & 4 > 0 THEN 0 ELSE 16 END),
			[Posted] = ISNULL(TJ.[Posted], 0),
			[JournalLine] = ISNULL(TJ.[JournalLine], -1),
			[Scenario] = ISNULL(TJ.[Scenario], 'ACTUAL'),
			[JournalDate] = ISNULL(TJ.[JournalDate], GetDate()),
			[ConsolidationGroup] = @Group,
			[Source] = ISNULL(TJ.[Source], 'MANUAL'),
			[SourceModule] = ISNULL(TJ.[SourceModule], 'MANUAL'),
			[Currency] = ISNULL(TJ.[Currency], @Currency),
			[Debit] = ISNULL(TJ.[Debit], 0),
			[Credit] = ISNULL(TJ.[Credit], 0)
		FROM
			#Journal TJ
		
		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 6)', * FROM #Journal

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

		IF @DebugBM & 2 > 0 SELECT [@Entity] = @Entity, [@Book] = @Book, [@EntityID] = @EntityID, [@MasterClosedYear]=@MasterClosedYear

	SET @Step = 'Check @Posted'
		SET @SQLStatement = '
			SELECT
				@InternalVariable = MAX(CONVERT(int, J.[PostedStatus]))
			FROM
				' + @JournalTable + ' J
				INNER JOIN #Journal TJ ON TJ.[Entity] = J.[Entity] AND TJ.[Book] = J.[Book] AND TJ.[FiscalYear] = J.[FiscalYear] AND TJ.[JournalSequence] = J.[JournalSequence] AND TJ.[JournalNo] = J.[JournalNo]
			WHERE
				J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
				ISNUMERIC(J.[JournalNo]) <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @Posted OUT

		IF @Posted <> 0 
			BEGIN
				IF (SELECT COUNT(1) FROM #Journal WHERE [ResultTypeBM] & 4 > 0 AND [JournalLine] = -1 AND [Posted] = 0) > 0
					BEGIN
						SET @SQLStatement = '
							UPDATE J
							SET
								[PostedDate] = GetDate(),
								[PostedStatus] = 0,
								[PostedBy] = ''' + @UserName + '''
							FROM
								' + @JournalTable + ' J
								INNER JOIN #Journal TJ ON TJ.[Entity] = J.[Entity] AND TJ.[Book] = J.[Book] AND TJ.[FiscalYear] = J.[FiscalYear] AND TJ.[JournalSequence] = J.[JournalSequence] AND TJ.[JournalNo] = J.[JournalNo]
							WHERE
								J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
								ISNUMERIC(J.[JournalNo]) <> 0'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
						GOTO POSTED
					END
				ELSE
					BEGIN
						SET @Message = 'This JournalNo is already posted.'
						SET @Severity = 0
						GOTO POSTED
					END
			END

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Add new JournalNo'
		IF (SELECT COUNT(1) FROM #Journal WHERE ResultTypeBM & 4 > 0 AND JournalID IS NULL AND JournalNo IS NULL) > 0
			BEGIN
				IF @DebugBM & 16 > 0 SELECT [Step] = @Step + ', 1', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

				CREATE TABLE #J ([JournalNo] nvarchar(50))

				SET @SQLStatement = '
					INSERT INTO #J
						(
						[JournalNo]
						)
					SELECT
						J.[JournalNo]
					FROM
						' + @JournalTable + ' J
						INNER JOIN #Journal TJ ON TJ.[Entity] = J.[Entity] AND TJ.[Book] = J.[Book] AND TJ.[FiscalYear] = J.[FiscalYear] AND TJ.[JournalSequence] = J.[JournalSequence]
					WHERE
						J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID)

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
						
				SELECT
					@JournalNo = MAX(CONVERT(int, [JournalNo]))
				FROM
					(
					SELECT
						[JournalNo]
					FROM
						#J
					WHERE
						ISNUMERIC([JournalNo]) <> 0
					) sub

				IF @DebugBM & 2 > 0 SELECT TempTable = '#J', [@JournalNo] = @JournalNo, * FROM #J
				
				SET @JournalNo = ISNULL(@JournalNo, 0) + 1				
				IF @DebugBM & 8 > 0 SELECT [@JournalNo] = @JournalNo

				DROP TABLE #J

				UPDATE TJ
				SET
					[JournalNo] = ISNULL(TJ.[JournalNo], @JournalNo)
				FROM
					#Journal TJ

				IF @DebugBM & 2 > 0 SELECT [@JournalNo] = @JournalNo

				IF @DebugBM & 16 > 0 SELECT [Step] = @Step + ', 2', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
			
		END

	SET @Step = 'Update Head and Line'
		SET @SQLStatement = '
			UPDATE J
				SET
					[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',
					[Entity] = TJ.[Entity],
					[Book] = TJ.[Book],
					[FiscalYear] = TJ.[FiscalYear],
					[FiscalPeriod] = TJ.[FiscalPeriod],
					[JournalSequence] = TJ.[JournalSequence],
					[JournalNo] = TJ.[JournalNo],
					[JournalLine] = TJ.[JournalLine],
					[YearMonth] = TJ.[YearMonth],
					[TransactionTypeBM] = TJ.[TransactionTypeBM],
					[BalanceYN] = ISNULL(TJ.[BalanceYN], 0),
					[Account] = TJ.[Account],
					[Segment01] = TJ.[Segment01],
					[Segment02] = TJ.[Segment02],
					[Segment03] = TJ.[Segment03],
					[Segment04] = TJ.[Segment04],
					[Segment05] = TJ.[Segment05],
					[Segment06] = TJ.[Segment06],
					[Segment07] = TJ.[Segment07],
					[Segment08] = TJ.[Segment08],
					[Segment09] = TJ.[Segment09],
					[Segment10] = TJ.[Segment10],
					[Segment11] = TJ.[Segment11],
					[Segment12] = TJ.[Segment12],
					[Segment13] = TJ.[Segment13],
					[Segment14] = TJ.[Segment14],
					[Segment15] = TJ.[Segment15],
					[Segment16] = TJ.[Segment16],
					[Segment17] = TJ.[Segment17],
					[Segment18] = TJ.[Segment18],
					[Segment19] = TJ.[Segment19],
					[Segment20] = TJ.[Segment20],
					[PostedDate] = CASE WHEN TJ.[Posted] <> 0 THEN GetDate() ELSE NULL END,
					[PostedStatus] = TJ.[Posted],
					[PostedBy] = CASE WHEN TJ.[Posted] <> 0 THEN ''' + @UserName + ''' ELSE NULL END,
					[Source] = TJ.[Source],
					[Flow] = TJ.[Flow],
					[ConsolidationGroup] = CASE WHEN TJ.[ConsolidationGroup] = ''NONE'' THEN NULL ELSE TJ.[ConsolidationGroup] END,
					[InterCompanyEntity] = TJ.[InterCompany],
					[Scenario] = TJ.[Scenario],
					[Description_Head] = TJ.[Description_Head],
					[Description_Line] = TJ.[Description_Line],
					[Currency_Book] = ' + CASE WHEN @GroupYN = 0 THEN 'TJ.[Currency]' ELSE 'NULL' END + ',
					[ValueDebit_Book] = ' + CASE WHEN @GroupYN = 0 THEN ' TJ.[Debit]' ELSE 'NULL' END + ',
					[ValueCredit_Book] = ' + CASE WHEN @GroupYN = 0 THEN ' TJ.[Credit]' ELSE 'NULL' END + ',
					[Currency_Group] = ' + CASE WHEN @GroupYN <> 0 THEN ' TJ.[Currency]' ELSE 'NULL' END + ',
					[ValueDebit_Group] = ' + CASE WHEN @GroupYN <> 0 THEN ' TJ.[Debit]' ELSE 'NULL' END + ',
					[ValueCredit_Group] = ' + CASE WHEN @GroupYN <> 0 THEN ' TJ.[Credit]' ELSE 'NULL' END + ',
					[SourceModule] = TJ.[SourceModule]
				FROM
					' + @JournalTable + ' J
					INNER JOIN #Journal TJ ON TJ.[JournalID] = J.[JournalID] AND TJ.DeleteYN = 0 
				WHERE
					J.[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID)

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal  (Step 8)', * FROM #Journal

	SET @Step = 'Insert new rows'
		SET @SQLStatement = '
			INSERT INTO ' + @JournalTable + '
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
				[Flow],
				[ConsolidationGroup],
				[InterCompanyEntity],
				[Scenario],
				[Description_Head],
				[Description_Line],
				[Currency_Book],
				[ValueDebit_Book],
				[ValueCredit_Book],
				[Currency_Group],
				[ValueDebit_Group],
				[ValueCredit_Group],
				[SourceModule],
				[Inserted],
				[InsertedBy]
				)
			SELECT
				[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',
				[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID) + ',
				[Entity],
				[Book],
				[FiscalYear],
				[FiscalPeriod],
				[JournalSequence],
				[JournalNo],
				[JournalLine],
				[YearMonth],
				[TransactionTypeBM],
				[BalanceYN] = ISNULL(TJ.[BalanceYN], 0),
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
				[PostedStatus] = TJ.[Posted],
				[PostedBy],
				[Source],
				[Flow],
				[ConsolidationGroup] = CASE WHEN TJ.[ConsolidationGroup] = ''NONE'' THEN NULL ELSE TJ.[ConsolidationGroup] END,
				[InterCompanyEntity] = TJ.[InterCompany],
				[Scenario],
				[Description_Head],
				[Description_Line],
				[Currency_Book] = ' + CASE WHEN @GroupYN = 0 THEN 'TJ.[Currency]' ELSE 'NULL' END + ',
				[ValueDebit_Book] = ' + CASE WHEN @GroupYN = 0 THEN ' TJ.[Debit]' ELSE 'NULL' END + ',
				[ValueCredit_Book] = ' + CASE WHEN @GroupYN = 0 THEN ' TJ.[Credit]' ELSE 'NULL' END + ',
				[Currency_Group] = ' + CASE WHEN @GroupYN <> 0 THEN ' TJ.[Currency]' ELSE 'NULL' END + ',
				[ValueDebit_Group] = ' + CASE WHEN @GroupYN <> 0 THEN ' TJ.[Debit]' ELSE 'NULL' END + ',
				[ValueCredit_Group] = ' + CASE WHEN @GroupYN <> 0 THEN ' TJ.[Credit]' ELSE 'NULL' END + ',
				[SourceModule],
				[Inserted] = GetDate(),
				[InsertedBy] = ''' + @UserName + '''
			FROM
				#Journal TJ
			WHERE
				TJ.[JournalID] IS NULL AND
				TJ.[DeleteYN] = 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @JournalID = @@IDENTITY
			
		SELECT [@JournalID] = @JournalID

		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal  (Step 7)', * FROM #Journal

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step + ', 3', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Delete Line'
		SET @SQLStatement = '
			DELETE J
			FROM
				' + @JournalTable + ' J
				INNER JOIN #Journal TJ ON TJ.ResultTypeBM & 8 > 0 AND TJ.DeleteYN <> 0 AND TJ.[JournalID] = J.[JournalID]
			WHERE
				J.[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID)

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Delete Head'
		SET @SQLStatement = '
			DELETE J
			FROM
				' + @JournalTable + ' J
				INNER JOIN #Journal TJ ON TJ.ResultTypeBM & 4 > 0 AND TJ.DeleteYN <> 0 AND TJ.[Entity] = J.[Entity] AND  TJ.[Book] = J.[Book] AND TJ.[FiscalYear] = J.[FiscalYear] AND TJ.[JournalSequence] = J.[JournalSequence] AND TJ.[JournalNo] = J.[JournalNo]
			WHERE
				J.[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID)

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Set Carry forward for manually entries'
		IF @GroupYN = 0
			BEGIN
				SELECT @FiscalYear = MAX([FiscalYear]) + 1 FROM #Journal

				EXEC [spSet_Journal_OP_ManAdj] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @FiscalYear=@FiscalYear, @JobID = @JobID, @Debug = @DebugSub
			END

	SET @Step = 'Fill FACT_Financials'
		IF @GroupYN = 0 AND (SELECT COUNT(1) FROM #Journal WHERE ResultTypeBM & 8 > 0) > 0
			BEGIN
				--EXEC [spIU_DC_Financials_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @Debug=@DebugSub
				SET @CommandStringGeneric = '
EXEC [spIU_DC_Financials_Callisto]
	@UserID=' + CONVERT(nvarchar(15), @UserID) + ',
	@InstanceID=' + CONVERT(nvarchar(15), @InstanceID) + ',
	@VersionID=' + CONVERT(nvarchar(15), @VersionID) + ',
	@JobID=' + CONVERT(nvarchar(15), @JobID)

				IF @DebugBM & 2 > 0 SELECT [@UserID]=@UserID, [@InstanceID]=@InstanceID, [@VersionID]=@VersionID, [@StepName] = 'GenericSP', [@Database]  = 'pcINTEGRATOR', [@CommandStringGeneric] = @CommandStringGeneric, [@AsynchronousYN] = 1, [@JobID]=@JobID, [@Debug]=@DebugSub

				EXEC [spRun_Job_Callisto_Generic] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @StepName = 'GenericSP', @Database  = 'pcINTEGRATOR', @CommandStringGeneric = @CommandStringGeneric, @AsynchronousYN = 1, @JobID=@JobID, @Debug=@DebugSub
			END
	
		POSTED:
	
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID

	SET @Step = 'Set EndTime for the actual job'
		EXEC [spSet_Job]
			@UserID=@UserID,
			@InstanceID=@InstanceID,
			@VersionID=@VersionID,
			@ActionType='End',
			@MasterCommand=@ProcedureName,
			@CurrentCommand=@ProcedureName,
			@JobID=@JobID
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
