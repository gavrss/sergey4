SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_Journal_Entry_New]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	@JSON_table NVARCHAR(MAX) = NULL, --ResultTypeBM: 4 - Journal Entry/Header; 8 - Journal Lines; 16 - Journal Lines and generate Journal Entry/Header out of it;
	@JournalID BIGINT = NULL OUT,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000735,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
--Bulk Import
EXEC [pcINTEGRATOR].[dbo].[spPortalSet_Journal_Entry] @InstanceID='613',@UserID='12054',@VersionID='1100',@DebugBM=15
,@JSON_table='[{"ResultTypeBM":"16","Entity":"PH01","Group":"NONE","Book":"MAIN","JournalSequence":"TestJournalSeq","TransactionDate":"2019-01-01","Description_Head":"TestJournalSeq-DescHead","Posted":"0",
"Account":"20030","Debit":"789.0000","Credit":null,"Flow":"VAR_Increase","InterCompany":null,"Description_Line":"TestJournalSeq-DescLine-1","Segment01":"00","Segment02":"000","Segment03":"PH01"},
{"ResultTypeBM":"16","Entity":"PH01","Group":"NONE","Book":"MAIN","JournalSequence":"TestJournalSeq","TransactionDate":"2019-01-01","Description_Head":"TestJournalSeq-DescHead","Posted":"0",
"Account":"20030","Debit":null,"Credit":"789.0000","Flow":"VAR_Decrease","InterCompany":null,"Description_Line":"TestJournalSeq-DescLine-2","Segment01":"00","Segment02":"000","Segment03":"PH01"}]'

EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"InstanceID","TValue":"613"},{"TKey":"UserID","TValue":"12054"},{"TKey":"VersionID","TValue":"1100"},{"TKey":"DebugBM","TValue":"15"}]', 
@JSON_table='[{"Segment01":"00","Segment02":"000","Segment03":"PH01","Entity":"PH01","Book":"MAIN","JournalSequence":"Reversing Entry","TransactionDate":"2019-01-01","Description_Head":"1.01. Eliminate Inter-Company AR","Account":"11017","Debit":"114176.0000","Flow":"Var_Increase","Currency":"SGD","Source":"PROPHIX","Scenario":"Actual","ResultTypeBM":"16"},
{"Segment01":"00","Segment02":"000","Segment03":"SG01","Entity":"PH01","Book":"MAIN","JournalSequence":"Reversing Entry","TransactionDate":"2019-01-01","Description_Head":"1.01. Eliminate Inter-Company AR","Account":"27200","Credit":"114176.0000","Flow":"Var_Decrease","Currency":"SGD","Source":"PROPHIX","Scenario":"Actual","ResultTypeBM":"16"},
{"Segment01":"00","Segment02":"000","Segment03":"PH01","Entity":"PH01","Book":"MAIN","JournalSequence":"Journal Entry","TransactionDate":"2019-01-01","Description_Head":"1.02A - Eliminate Inter-Company AP - GIT Only","Account":"20020","Debit":"43517.0000","Flow":"Var_Increase","Currency":"SGD","Source":"PROPHIX","Scenario":"Actual","ResultTypeBM":"16"}]', 
@ProcedureName='spPortalSet_Journal_Entry', @XML=null

EXEC [pcINTEGRATOR].[dbo].[spPortalSet_Journal_Entry] @InstanceID='613',@UserID='12054',@VersionID='1100'
,@JSON_table='[{"ResultTypeBM":"4","Entity":"PH01","Group":"NONE","Book":"MAIN","JournalSequence":"TestJrnSeq","TransactionDate":"2019-01-01",
"Description_Head":"TestJrnSeq-DescHead","Posted":"0","JournalID":"2077607","FiscalYear":"2019","FiscalPeriod":"1"},
{"ResultTypeBM":"8","JournalLine":"1","Account":"20030","Debit":"12345.0000","Credit":null,"Flow":"VAR_Increase","InterCompany":null,
"Description_Line":"JRN-Line-1","Segment01":"00","Segment02":"000","Segment03":"PH01"},
{"ResultTypeBM":"8","JournalLine":"2","Account":"20030","Debit":null,"Credit":"12345.0000","Flow":"VAR_Decrease","InterCompany":null,
"Description_Line":"JRN-Line-2","Segment01":"00","Segment02":"000","Segment03":"PH01"}]'
,@DebugBM=15

EXEC [spPortalSet_Journal_Entry] @InstanceID='613',@UserID='12054',@VersionID='1100',@JSON_table='
[{"ResultTypeBM":"4","Entity":"PH01","Group":null,"Book":"MAIN","JournalSequence":"TestJrnSeq","TransactionDate":"2019-01-01","Description_Head":"TestJrnSeq-JE Head-Desc","Posted":"0"}]'
,@DebugBM=15

--16= Journal Head + Journal Line
DECLARE
@JSON_table nvarchar(MAX) = '
[
{"ResultTypeBM":"16","Entity":"PH01","Group":"NONE","Book":"MAIN","JournalSequence":"Test Reversing Entry","TransactionDate":"2019-01-01",
"Description_Head":"Test Journal Description Head","Posted":"0","Source":"PROPHIX",
"Account":"27200","Debit":"500.0000","Credit":null,"Flow":"VAR_Increase","InterCompany":null,
"Description_Line":"Test Journal Description Line","Segment01":"00","Segment02":"000","Segment03":"SG01","Currency":"PHP"}
,{"ResultTypeBM":"16","Entity":"PH01","Group":"NONE","Book":"MAIN","JournalSequence":"Test Reversing Entry","TransactionDate":"2019-01-01",
"Description_Head":"Test Journal Description Head","Posted":"0","Source":"PROPHIX",
"Account":"27200","Debit":null,"Credit":"500.0000","Flow":"VAR_Decrease","InterCompany":null,
"Description_Line":"Test Journal Description Line","Segment01":"00","Segment02":"000","Segment03":"SG01","Currency":"PHP"}

,{"ResultTypeBM":"16","Entity":"PH01","Group":"NONE","Book":"MAIN","JournalSequence":"Test Journal Entry","TransactionDate":"2019-01-01",
"Description_Head":"Test Journal Description Head","Posted":"0","Source":"PROPHIX",
"Account":"11017","Debit":"600.0000","Credit":null,"Flow":"VAR_Increase","InterCompany":null,
"Description_Line":"Test Journal Description Line","Segment01":"00","Segment02":"000","Segment03":"SG01","Currency":"PHP"}
,{"ResultTypeBM":"16","Entity":"PH01","Group":"NONE","Book":"MAIN","JournalSequence":"Test Journal Entry","TransactionDate":"2019-01-01",
"Description_Head":"Test Journal Description Head","Posted":"0","Source":"PROPHIX",
"Account":"11017","Debit":null,"Credit":"600.0000","Flow":"VAR_Decrease","InterCompany":null,
"Description_Line":"Test Journal Description Line","Segment01":"00","Segment02":"000","Segment03":"SG01","Currency":"PHP"}
]'
EXEC [dbo].[spPortalSet_Journal_Entry] 
	@UserID = -10,
	@InstanceID = 613,
	@VersionID = 1100,
	@DebugBM = 15,
	@JSON_table = @JSON_table

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
	@EntityID INT,
	@DeletedID INT,
	@Group NVARCHAR(50),
	@Entity NVARCHAR(50),
	@Book NVARCHAR(50),
	@MainBook NVARCHAR(50),
	@MasterClosedYear INT,
	@CallistoDatabase NVARCHAR(100),
	@SQLStatement NVARCHAR(MAX),
	@JournalNo INT,
	@JournalLine INT,
	@Posted BIT,
	@JournalTable NVARCHAR(100),
	@Currency NVARCHAR(3),
	@AccountList NVARCHAR(1000) = '',
	@CommandStringGeneric NVARCHAR(4000),
	@FiscalYear INT,
	@GroupYN BIT,
	@JournalSequence NVARCHAR(50),
	@ConsolidationGroup NVARCHAR(50),

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2199'

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
		IF @Version = '2.1.2.2199' SET @Description = 'DB-1635: Implement ResultTypeBM = 16 (Journal Lines and generate JournalHeader from Journal Line info). EA-8395: Removed ORDER By clause in @Step = Insert new rows.'

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
			EXEC [pcINTEGRATOR].[dbo].[spSet_Job]
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
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			SelectYN <> 0

		EXEC [pcINTEGRATOR].[dbo].[spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @JournalTable = @JournalTable OUT

		IF @DebugBM & 2 > 0 SELECT [@CallistoDatabase]=@CallistoDatabase, [@JournalTable]=@JournalTable

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)

	SET @Step = 'Create and fill #Journal'
		CREATE TABLE #Journal
			(
			[ResultTypeBM] INT,
			[JournalID] BIGINT,
			[Entity] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Book] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] [INT],
			[FiscalPeriod] [INT],
			[JournalSequence] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[JournalNo] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[JournalLine] [INT],
			[YearMonth] [INT],
			[TransactionTypeBM] [INT],
			[BalanceYN] [BIT],
			[Account] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment01] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment02] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment03] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment04] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment05] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment06] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment07] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment08] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment09] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment10] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment11] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment12] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment13] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment14] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment15] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment16] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment17] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment18] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment19] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Segment20] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[JournalDate] [DATE],
			[TransactionDate] [DATE],
			[PostedDate] [DATE],
			[Posted] [BIT],
			[PostedBy] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[Source] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Flow] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[ConsolidationGroup] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[InterCompany] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Scenario] [NVARCHAR](50) COLLATE DATABASE_DEFAULT,
			[Description_Head] [NVARCHAR](255) COLLATE DATABASE_DEFAULT,
			[Description_Line] [NVARCHAR](255) COLLATE DATABASE_DEFAULT,
			[Currency] [NCHAR](3) COLLATE DATABASE_DEFAULT,
			[Debit] [FLOAT],
			[Credit] [FLOAT],
			[SourceModule] [NVARCHAR](20) COLLATE DATABASE_DEFAULT,
			[SourceModuleReference] [NVARCHAR](100) COLLATE DATABASE_DEFAULT,
			[DeleteYN] BIT
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
					[ResultTypeBM] INT,
					[JournalID] BIGINT,
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

	SET @Step = 'Create temp table #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int
			)

	SET @Step = 'Create temp table #J'
		CREATE TABLE #J 
			(
			[JournalNo] nvarchar(50),
			[JournalLine] int
			)

	SET @Step = 'Create and fill #Entity_Currency'
		CREATE TABLE #Entity_Currency
			(
			[EntityID] INT,
			[Entity] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[Book] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[Currency] NCHAR(3) COLLATE DATABASE_DEFAULT,
			[GroupYN] BIT,
			[MainBookYN] BIT
			)

		INSERT INTO #Entity_Currency
			(
			[EntityID],
			[Entity],
			[Book],
			[Currency],
			[GroupYN],
			[MainBookYN]
			)
		SELECT 
			[EntityID] = E.EntityID,
			[Entity] = E.MemberKey, 
			[Book] = EB.Book,
			[Currency] = EB.Currency,
			[GroupYN] = CASE WHEN EB.BookTypeBM & 16 > 0 THEN 1 ELSE 0 END,
			[MainBookYN] = CASE WHEN EB.BookTypeBM & 2 > 0 THEN 1 ELSE 0 END
		FROM 
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.Currency IS NOT NULL AND EB.BookTypeBM & 17 > 0 AND EB.SelectYN <> 0
		WHERE 
			E.InstanceID = @InstanceID AND 
			E.VersionID = @VersionID AND 
			E.SelectYN <> 0
			
		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Entity_Currency', * FROM #Entity_Currency	
		
	SET @Step = 'Add ResutlTypeBM = 4 from ResultTypeBM = 16' 
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
			[ResultTypeBM] = 4,			
			[JournalID] = NULL,
			TJ.[Entity],
			TJ.[Book],
			TJ.[FiscalYear],
			TJ.[FiscalPeriod], 
			TJ.[JournalSequence],
			[JournalNo] = NULL,
			[JournalLine] = NULL,
			[Account] = NULL,
			[Segment01] = NULL,
			[Segment02] = NULL,
			[Segment03] = NULL,
			[Segment04] = NULL,
			[Segment05] = NULL,
			[Segment06] = NULL,
			[Segment07] = NULL,
			[Segment08] = NULL,
			[Segment09] = NULL,
			[Segment10] = NULL,
			[Segment11] = NULL,
			[Segment12] = NULL,
			[Segment13] = NULL,
			[Segment14] = NULL,
			[Segment15] = NULL,
			[Segment16] = NULL,
			[Segment17] = NULL,
			[Segment18] = NULL,
			[Segment19] = NULL,
			[Segment20] = NULL,
			TJ.[TransactionDate],
			[PostedDate] = MAX(TJ.[PostedDate]),
			[Posted] = MAX(ISNULL(CONVERT(INT,TJ.[Posted]), 1)),
			[Source] = MAX(TJ.[Source]),
			[Flow] = NULL,
			TJ.[ConsolidationGroup],
			[InterCompany] = NULL,
			[Scenario] = MAX(TJ.[Scenario]),
			[Description_Head] = MAX(TJ.[Description_Head]),
			[Description_Line] = NULL,
			[Currency] = MAX(TJ.[Currency]),
			[Debit] = NULL,
			[Credit] = NULL,
			[SourceModule] = MAX(TJ.[SourceModule]),
			[DeleteYN] = MAX(ISNULL(CONVERT(INT,TJ.[DeleteYN]), 0))
		FROM
			#Journal TJ
		WHERE
			TJ.[ResultTypeBM] & 16 > 0 AND 
			NOT EXISTS (SELECT 1 FROM #Journal J WHERE J.ResultTypeBM = 4 AND J.Entity = TJ.Entity AND J.Book = TJ.Book AND J.FiscalYear = TJ.FiscalYear AND J.FiscalPeriod = TJ.FiscalPeriod AND J.JournalSequence = TJ.JournalSequence AND J.TransactionDate = TJ.TransactionDate AND J.[ConsolidationGroup] = TJ.[ConsolidationGroup])
		GROUP BY
			TJ.[Entity],
			TJ.[Book],
			TJ.[FiscalYear],
			TJ.[FiscalPeriod],
			TJ.[JournalSequence],
			TJ.[TransactionDate],
			TJ.[ConsolidationGroup]

		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 1.1) - Add [ResultTypeBM]=4 from [ResultTypeBM]=16', * FROM #Journal ORDER BY [Entity], [Book], [JournalSequence], [ResultTypeBM], [JournalNo], [JournalLine]

	--SET @Step = 'Set variable @Group' 
	--	SELECT
	--		@Group = MAX([ConsolidationGroup])
	--	FROM
	--		#Journal
	--	WHERE
	--		[ResultTypeBM] & 4 > 0

	--	SET @GroupYN = CASE WHEN @Group = 'NONE' THEN 0 ELSE 1 END

	--	IF @DebugBM & 2 > 0 SELECT [@GroupYN] = @GroupYN, [@Group] = @Group

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
		
		IF LEN(@AccountList) > 0
			BEGIN
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
			END

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(TIME(7), GETDATE() - @StartTime)
		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Balance', * FROM #Balance

	SET @Step = 'Update [BalanceYN] column in temp table #Journal'	
		UPDATE TJ
		SET
			[BalanceYN] = ISNULL(TJ.[BalanceYN], B.[BalanceYN])
		FROM
			#Journal TJ
			INNER JOIN #Balance B ON B.[Account] = TJ.[Account]

		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 2) - Update [BalanceYN]', * FROM #Journal

	SET @Step = 'Update [ConsolidationGroup] column in temp table #Journal'	
		SELECT
			@ConsolidationGroup = [ConsolidationGroup]
		FROM
			#Journal TJ
		WHERE
			ResultTypeBM & 4 > 0
		
		UPDATE TJ
		SET
			[ConsolidationGroup] = @ConsolidationGroup
		FROM
			#Journal TJ
		WHERE
			ResultTypeBM & 8 > 0

		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 2) - Update [BalanceYN]', * FROM #Journal

	SET @Step = 'Update temp table #Journal for JournalID <> NULL'
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
		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 3) - Update on [JournalID] <> NULL', * FROM #Journal  ORDER BY [Entity], [Book], [JournalSequence], [ResultTypeBM], [JournalNo], [JournalLine]

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
						[Entity] = ISNULL(TJ1.[Entity], J1.[Entity]),
						[Book] = ISNULL(TJ1.[Book], J1.[Book]),
						[FiscalYear] = ISNULL(TJ1.[FiscalYear], J1.[FiscalYear]),
						[FiscalPeriod] = ISNULL(TJ1.[FiscalPeriod], J1.[FiscalPeriod]),
						[JournalSequence] = ISNULL(TJ1.[JournalSequence], J1.[JournalSequence]),
						[JournalNo] = ISNULL(TJ1.[JournalNo], J1.[JournalNo]),
						[JournalDate] = ISNULL(TJ1.[JournalDate], J1.[JournalDate]),
						[TransactionDate] = ISNULL(TJ1.[TransactionDate], J1.[TransactionDate]),
						[YearMonth] = ISNULL(TJ1.[YearMonth], J1.[YearMonth]),
						[Posted] = ISNULL(TJ1.[Posted], J1.[PostedStatus])
					FROM
						#Journal TJ1
						LEFT JOIN ' + @JournalTable + ' J1 ON J1.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND J1.JournalID = TJ1.JournalID
					WHERE
						TJ1.ResultTypeBM & 4 > 0
					) J ON 1 = 1 
			WHERE
				TJ.[ResultTypeBM] & 8 > 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 4) - Update on [ResultTypeBM] = 8 from [ResultTypeBM] = 4  with [JournalID] ', * FROM #Journal ORDER BY [Entity], [Book], [JournalSequence], [ResultTypeBM], [JournalNo], [JournalLine]

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
		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 5) - Update [JournalID] for existing data', * FROM #Journal ORDER BY [Entity], [Book], [JournalSequence], [ResultTypeBM], [JournalNo], [JournalLine]
 
	SET @Step = 'Update Book'
		UPDATE TJ
		SET
			[Book] = E.Book
		FROM
			#Journal TJ
			INNER JOIN #Entity_Currency E ON E.Entity = TJ.Entity AND E.MainBookYN = 1
		WHERE
			TJ.Book IS NULL

		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 5.5) - Update [Book] IF NULL', * FROM #Journal ORDER BY [Entity], [Book], [JournalSequence], [ResultTypeBM], [JournalNo], [JournalLine]

	SET @Step = 'Loop Entity_Book'
		EXEC [pcINTEGRATOR].[dbo].[spGet_MasterClosedYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @MasterClosedYear = @MasterClosedYear OUT, @JobID=@JobID
		SET @MasterClosedYear = ISNULL(@MasterClosedYear, YEAR(GETDATE()) -5)
		
		IF CURSOR_STATUS('global','Entity_Book_Cursor') >= -1 DEALLOCATE Entity_Book_Cursor
		DECLARE Entity_Book_Cursor CURSOR FOR
			
			SELECT DISTINCT
				E.[EntityID],
				E.[Entity],
				E.[Book],
				E.[Currency]
			FROM
				#Entity_Currency E
				INNER JOIN (SELECT DISTINCT Entity, Book, JournalSequence FROM #Journal) J ON J.Entity = E.Entity AND J.Book = E.Book
			WHERE 
				E.GroupYN = 0

			OPEN Entity_Book_Cursor
			FETCH NEXT FROM Entity_Book_Cursor INTO @EntityID, @Entity, @Book, @Currency

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@EntityID] = @EntityID, [@Entity] = @Entity, [@Book] = @Book, [@Currency] = @Currency, [@MasterClosedYear] = @MasterClosedYear

					SET @Step = 'Set FiscalYear, FiscalPeriod, YearMonth'
						TRUNCATE TABLE #FiscalPeriod
						EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear=@MasterClosedYear, @FiscalPeriod13YN = 1, @JobID=@JobID
					
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
									[Entity] = MAX(TJ.[Entity]),
									[Book] = MAX(TJ.[Book]),
									[TransactionDate] = TJ.[TransactionDate],
									[FiscalYear] = MIN(FP.[FiscalYear]),
									[FiscalPeriod] = MIN(FP.[FiscalPeriod]),
									[YearMonth] = MIN(FP.[YearMonth])
								FROM
									#Journal TJ
									INNER JOIN #FiscalPeriod FP ON FP.YearMonth = YEAR(TJ.[TransactionDate]) * 100 + MONTH(TJ.[TransactionDate])
								WHERE
									TJ.Entity = @Entity AND
									TJ.Book = @Book
								GROUP BY
									TJ.[TransactionDate]
								) sub ON sub.[TransactionDate] = TJ.[TransactionDate] AND sub.[Entity] = TJ.[Entity] AND sub.[Book] = TJ.[Book]
						WHERE
							TJ.Entity = @Entity AND
							TJ.Book = @Book

						UPDATE TJ
						SET
							[YearMonth] = ISNULL(TJ.[YearMonth], FP.[YearMonth])
						FROM
							#Journal TJ
							INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = TJ.[FiscalYear] AND FP.[FiscalPeriod] = TJ.[FiscalPeriod]
						WHERE
							TJ.Entity = @Entity AND
							TJ.Book = @Book

						UPDATE TJ
						SET
							[TransactionTypeBM] = ISNULL(TJ.[TransactionTypeBM], CASE WHEN TJ.ResultTypeBM & 4 > 0 THEN 0 ELSE 16 END),
							[Posted] = ISNULL(TJ.[Posted], 1),
							[JournalLine] = ISNULL(TJ.[JournalLine], CASE WHEN TJ.ResultTypeBM & 4 > 0 THEN -1 ELSE TJ.[JournalLine] END),
							[Scenario] = ISNULL(TJ.[Scenario], 'ACTUAL'),
							[JournalDate] = ISNULL(TJ.[JournalDate], GETDATE()),
							[ConsolidationGroup] = ISNULL(E.Entity, TJ.ConsolidationGroup),
							[Source] = ISNULL(TJ.[Source], 'MANUAL'),
							[SourceModule] = ISNULL(TJ.[SourceModule], 'MANUAL'),
							[Currency] = CASE WHEN E.Entity IS NOT NULL THEN E.Currency ELSE ISNULL(TJ.[Currency], @Currency) END,
							[Debit] = ISNULL(TJ.[Debit], 0),
							[Credit] = ISNULL(TJ.[Credit], 0)
						FROM
							#Journal TJ
							LEFT JOIN #Entity_Currency E ON E.GroupYN <> 0 AND E.Entity = TJ.ConsolidationGroup
						WHERE
							TJ.Entity = @Entity AND
							TJ.Book = @Book

						IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 6) - [' + @Entity + '_' + @Book + ']', * FROM #Journal WHERE Entity = @Entity AND Book = @Book ORDER BY [Entity], [Book], [JournalSequence], [ResultTypeBM], [JournalNo], [JournalLine]

					SET @Step = 'Loop FiscalYear'
						IF @DebugBM & 8 > 0
							SELECT DISTINCT 
								[EB_FY_JrnSeq_Cursor] = 'EB_FY_JrnSeq_Cursor',
								TJ.Entity,
								TJ.Book,
								TJ.FiscalYear,
								TJ.JournalSequence
							FROM
								#Journal TJ
							WHERE
								TJ.Entity = @Entity AND 
								TJ.Book = @Book
							ORDER BY
								TJ.FiscalYear,
								TJ.JournalSequence

						IF CURSOR_STATUS('global','EB_FY_JrnSeq_Cursor') >= -1 DEALLOCATE EB_FY_JrnSeq_Cursor
						DECLARE EB_FY_JrnSeq_Cursor CURSOR FOR
			
							SELECT DISTINCT 
								TJ.FiscalYear,
								TJ.JournalSequence
							FROM
								#Journal TJ
							WHERE
								TJ.Entity = @Entity AND 
								TJ.Book = @Book
							ORDER BY
								TJ.FiscalYear,
								TJ.JournalSequence

							OPEN EB_FY_JrnSeq_Cursor
							FETCH NEXT FROM EB_FY_JrnSeq_Cursor INTO @FiscalYear, @JournalSequence

							WHILE @@FETCH_STATUS = 0
								BEGIN
									IF @DebugBM & 8 > 0 SELECT * FROM #Journal WHERE ResultTypeBM & 4 > 0 AND JournalID IS NULL AND JournalNo IS NULL AND Entity = @Entity AND Book = @Book and JournalSequence = @JournalSequence AND FiscalYear = @FiscalYear
									
									SET @Step = 'Add new JournalNo'
										IF (SELECT COUNT(1) FROM #Journal WHERE ResultTypeBM & 4 > 0 AND JournalID IS NULL AND JournalNo IS NULL AND Entity = @Entity AND Book = @Book and JournalSequence = @JournalSequence AND FiscalYear = @FiscalYear) > 0
											BEGIN
												IF @DebugBM & 8 > 0 SELECT [@JournalTable]=@JournalTable, [@Entity]=@Entity, [@Book]=@Book, [@JournalSequence] = @JournalSequence, [@FiscalYear] = @FiscalYear

												TRUNCATE TABLE #J

												SET @SQLStatement = '
													INSERT INTO #J
														(
														[JournalNo],
														[JournalLine]
														)
													SELECT
														J.[JournalNo],
														J.[JournalLine]
													FROM
														' + @JournalTable + ' J
														INNER JOIN #Journal TJ ON TJ.[Entity] = J.[Entity] AND TJ.[Book] = J.[Book] AND TJ.[FiscalYear] = J.[FiscalYear] AND TJ.[JournalSequence] = J.[JournalSequence]
													WHERE
														J.[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND
														J.[Entity] = ''' + @Entity + ''' AND
														J.[Book] = ''' + @Book + ''' AND
														J.[FiscalYear] = ' + CONVERT(NVARCHAR(15), @FiscalYear) + ' AND
														J.[JournalSequence] = ''' + @JournalSequence + ''''

												IF @DebugBM & 2 > 0 PRINT @SQLStatement
												EXEC (@SQLStatement)
						
												SELECT
													@JournalNo = MAX(CONVERT(int, [JournalNo])),
													@JournalLine = MAX([JournalLine])
												FROM
													(
													SELECT
														[JournalNo],
														[JournalLine]
													FROM
														#J
													WHERE
														ISNUMERIC([JournalNo]) <> 0
													) sub

												IF @DebugBM & 8 > 0 SELECT [@JournalNo] = @JournalNo, [@JournalLine] = @JournalLine, [TempTable_#J] = '#J', * FROM #J
				
												SELECT 
													@JournalNo = ISNULL(@JournalNo, 0) + 1,
													@JournalLine = ISNULL(@JournalLine, 0)	

												IF @DebugBM & 8 > 0 SELECT [@JournalNo] = @JournalNo, [@JournalLine] = @JournalLine

												--DROP TABLE #J

												UPDATE TJ
												SET
													[JournalNo] = @JournalNo
												FROM
													#Journal TJ
												WHERE
													TJ.[Entity] = @Entity AND
													TJ.[Book] = @Book AND
													TJ.[FiscalYear] = @FiscalYear AND
													TJ.[JournalSequence] = @JournalSequence

												UPDATE TJ
												SET
													[JournalLine] = sub.JournalLine
												FROM
													#Journal TJ
													INNER JOIN (
														SELECT 
															J.ResultTypeBM,
															J.Entity,
															J.Book,
															J.FiscalYear,
															J.FiscalPeriod,
															J.JournalSequence,
															J.JournalNo,
															[JournalLine] = @JournalLine + ROW_NUMBER() OVER(PARTITION BY J.JournalNo ORDER BY J.FiscalPeriod, J.Account),
															J.YearMonth,
															J.TransactionTypeBM,
															J.BalanceYN,
															J.Account,
															J.Segment01,
															J.Segment02,
															J.Segment03,
															J.Segment04,
															J.Segment05,
															J.Segment06,
															J.Segment07,
															J.Segment08,
															J.Segment09,
															J.Segment10,
															J.Segment11,
															J.Segment12,
															J.Segment13,
															J.Segment14,
															J.Segment15,
															J.Segment16,
															J.Segment17,
															J.Segment18,
															J.Segment19,
															J.Segment20,
															J.JournalDate,
															J.TransactionDate,
															J.PostedDate,
															J.Posted,
															J.PostedBy,
															J.Source,
															J.Flow,
															J.ConsolidationGroup,
															J.InterCompany,
															J.Scenario,
															J.Description_Head,
															J.Description_Line,
															J.Currency,
															J.Debit,
															J.Credit,
															J.SourceModule,
															J.SourceModuleReference,
															J.DeleteYN
														FROM
															#Journal J
														WHERE
															J.[Entity] = @Entity AND
															J.[Book] = @Book AND
															J.[FiscalYear] = @FiscalYear AND
															J.[JournalSequence] = @JournalSequence AND
															J.[JournalNo] = CONVERT(NVARCHAR(15), @JournalNo) AND 
															(J.[JournalLine] IS NULL OR J.[JournalLine] <> -1)
													) sub ON 
															--sub.ResultTypeBM = TJ.ResultTypeBM AND 
															sub.Entity = TJ.Entity AND 
															sub.Book = TJ.Book AND                                                            
															sub.FiscalYear = TJ.FiscalYear AND 
															sub.FiscalPeriod = TJ.FiscalPeriod AND 
															sub.JournalSequence = TJ.JournalSequence AND 
															sub.JournalNo = TJ.JournalNo AND 
															sub.YearMonth = TJ.YearMonth AND 
															sub.TransactionTypeBM = TJ.TransactionTypeBM AND 
															sub.BalanceYN = TJ.BalanceYN AND 
															sub.Account = TJ.Account AND 
															ISNULL(sub.Segment01,'NULL') = ISNULL(TJ.Segment01,'NULL') AND 
															ISNULL(sub.Segment02,'NULL') = ISNULL(TJ.Segment02,'NULL') AND 
															ISNULL(sub.Segment03,'NULL') = ISNULL(TJ.Segment03,'NULL') AND 
															ISNULL(sub.Segment04,'NULL') = ISNULL(TJ.Segment04,'NULL') AND 
															ISNULL(sub.Segment05,'NULL') = ISNULL(TJ.Segment05,'NULL') AND 
															ISNULL(sub.Segment06,'NULL') = ISNULL(TJ.Segment06,'NULL') AND 
															ISNULL(sub.Segment07,'NULL') = ISNULL(TJ.Segment07,'NULL') AND 
															ISNULL(sub.Segment08,'NULL') = ISNULL(TJ.Segment08,'NULL') AND 
															ISNULL(sub.Segment09,'NULL') = ISNULL(TJ.Segment09,'NULL') AND 
															ISNULL(sub.Segment10,'NULL') = ISNULL(TJ.Segment10,'NULL') AND 
															ISNULL(sub.Segment11,'NULL') = ISNULL(TJ.Segment11,'NULL') AND 
															ISNULL(sub.Segment12,'NULL') = ISNULL(TJ.Segment12,'NULL') AND 
															ISNULL(sub.Segment13,'NULL') = ISNULL(TJ.Segment13,'NULL') AND 
															ISNULL(sub.Segment14,'NULL') = ISNULL(TJ.Segment14,'NULL') AND 
															ISNULL(sub.Segment15,'NULL') = ISNULL(TJ.Segment15,'NULL') AND 
															ISNULL(sub.Segment16,'NULL') = ISNULL(TJ.Segment16,'NULL') AND 
															ISNULL(sub.Segment17,'NULL') = ISNULL(TJ.Segment17,'NULL') AND 
															ISNULL(sub.Segment18,'NULL') = ISNULL(TJ.Segment18,'NULL') AND 
															ISNULL(sub.Segment19,'NULL') = ISNULL(TJ.Segment19,'NULL') AND 
															ISNULL(sub.Segment20,'NULL') = ISNULL(TJ.Segment20,'NULL') AND 
															sub.JournalDate = TJ.JournalDate AND 
															sub.TransactionDate = TJ.TransactionDate AND 
															--ISNULL(sub.PostedDate,'0000-00-00') = ISNULL(TJ.PostedDate,'0000-00-00') AND 
															sub.Posted = TJ.Posted AND 
															--ISNULL(sub.PostedBy,'NULL') = ISNULL(TJ.PostedBy,'NULL') AND 
															sub.Source = TJ.Source AND 
															sub.Flow = TJ.Flow AND 
															sub.ConsolidationGroup = TJ.ConsolidationGroup AND 
															ISNULL(sub.InterCompany,'NULL') = ISNULL(TJ.InterCompany,'NULL') AND 
															sub.Scenario = TJ.Scenario AND 
															ISNULL(sub.Description_Head,'NULL') = ISNULL(TJ.Description_Head,'NULL') AND 
															ISNULL(sub.Description_Line,'NULL') = ISNULL(TJ.Description_Line,'NULL') AND 
															sub.Currency = TJ.Currency AND 
															sub.Debit = TJ.Debit AND
															sub.Credit = TJ.Credit AND 
															sub.SourceModule = TJ.SourceModule AND 
															ISNULL(sub.SourceModuleReference,'NULL') = ISNULL(TJ.SourceModuleReference,'NULL') AND 
															sub.DeleteYN = TJ.DeleteYN
												WHERE
													TJ.[Entity] = @Entity AND
													TJ.[Book] = @Book AND
													TJ.[FiscalYear] = @FiscalYear AND
													TJ.[JournalSequence] = @JournalSequence AND
													TJ.[JournalNo] = CONVERT(NVARCHAR(15), @JournalNo) AND 
													(TJ.[JournalLine] IS NULL OR TJ.[JournalLine] <> -1)

												IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 7) - ['+@Entity+'_'+@Book+'_'+CONVERT(NVARCHAR(15),@FiscalYear)+'_'+@JournalSequence+'] with JournalNo/JournalLine', * FROM #Journal WHERE Entity = @Entity AND Book = @Book AND FiscalYear = @FiscalYear AND JournalSequence = @JournalSequence ORDER BY [ResultTypeBM], [JournalNo], [JournalLine]

											END

									SET @Step = 'Check @Posted'
										SET @SQLStatement = '
											SELECT
												@InternalVariable = MAX(CONVERT(int, J.[PostedStatus]))
											FROM
												' + @JournalTable + ' J
												INNER JOIN #Journal TJ ON TJ.[Entity] = J.[Entity] AND TJ.[Book] = J.[Book] AND TJ.[FiscalYear] = J.[FiscalYear] AND TJ.[JournalSequence] = J.[JournalSequence] AND TJ.[JournalNo] = J.[JournalNo]
											WHERE
												J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
												ISNUMERIC(J.[JournalNo]) <> 0 AND
												J.[Entity] = ''' + @Entity + ''' AND
												J.[Book] = ''' + @Book + ''' AND
												J.[FiscalYear] = ' + CONVERT(NVARCHAR(15), @FiscalYear) + ' AND
												J.[JournalSequence] = ''' + @JournalSequence + ''''

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @Posted OUT

										IF @DebugBM & 8 > 0 SELECT [@Posted] = @Posted

										IF @Posted <> 0 
											BEGIN
												IF (SELECT COUNT(1) FROM #Journal WHERE [ResultTypeBM] & 4 > 0 AND [JournalLine] = -1 AND [Posted] = 0 AND Entity = @Entity AND Book = @Book and JournalSequence = @JournalSequence AND FiscalYear = @FiscalYear) > 0
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
																ISNUMERIC(J.[JournalNo]) <> 0 AND
																J.[Entity] = ''' + @Entity + ''' AND
																J.[Book] = ''' + @Book + ''' AND
																J.[FiscalYear] = ' + CONVERT(NVARCHAR(15), @FiscalYear) + ' AND
																J.[JournalSequence] = ''' + @JournalSequence + ''''

														IF @DebugBM & 2 > 0 PRINT @SQLStatement
														EXEC (@SQLStatement)
														GOTO POSTED
													END
												ELSE
													BEGIN
														SET @Message = 'This JournalNo for Entity = '''+@Entity+''', Book = '''+@Book+''', FiscalYear = '+CONVERT(NVARCHAR(15),@FiscalYear)+' and JournalSequence = '''+@JournalSequence+''' is already posted.'
														SET @Severity = 0
														GOTO POSTED
													END
											END

										IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 8) - ['+@Entity+'_'+@Book+'_'+CONVERT(NVARCHAR(15),@FiscalYear)+'_'+@JournalSequence+'] with Posted', * FROM #Journal WHERE Entity = @Entity AND Book = @Book AND FiscalYear = @FiscalYear AND JournalSequence = @JournalSequence ORDER BY [ResultTypeBM], [JournalNo], [JournalLine]

									FETCH NEXT FROM EB_FY_JrnSeq_Cursor INTO @FiscalYear, @JournalSequence
								END

						CLOSE EB_FY_JrnSeq_Cursor
						DEALLOCATE EB_FY_JrnSeq_Cursor

					FETCH NEXT FROM Entity_Book_Cursor INTO @EntityID, @Entity, @Book, @Currency
				END

		CLOSE Entity_Book_Cursor
		DEALLOCATE Entity_Book_Cursor
		
		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

/******
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
		
		
		EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear=@MasterClosedYear, @FiscalPeriod13YN = 1, @JobID=@JobID

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
******/

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
					[Currency_Book] = CASE WHEN Grp.Entity IS NULL AND E.Currency = TJ.[Currency] THEN TJ.[Currency] ELSE NULL END,
					[ValueDebit_Book] = CASE WHEN Grp.Entity IS NULL AND E.Currency = TJ.[Currency] THEN TJ.[Debit] ELSE NULL END,
					[ValueCredit_Book] = CASE WHEN Grp.Entity IS NULL AND E.Currency = TJ.[Currency] THEN TJ.[Credit] ELSE NULL END,
					[Currency_Group] = CASE WHEN Grp.Entity IS NOT NULL AND Grp.Currency = TJ.[Currency] THEN TJ.[Currency] ELSE NULL END,
					[ValueDebit_Group] = CASE WHEN Grp.Entity IS NOT NULL AND Grp.Currency = TJ.[Currency] THEN TJ.[Debit] ELSE NULL END,
					[ValueCredit_Group] = CASE WHEN Grp.Entity IS NOT NULL AND Grp.Currency = TJ.[Currency] THEN TJ.[Credit] ELSE NULL END,
					[Currency_Transaction] = CASE WHEN Grp.Entity IS NULL AND E.Currency <> TJ.[Currency] THEN TJ.[Currency] ELSE NULL END,
					[ValueDebit_Transaction] = CASE WHEN Grp.Entity IS NULL AND E.Currency <> TJ.[Currency] THEN TJ.[Debit] ELSE NULL END,
					[ValueCredit_Transaction] = CASE WHEN Grp.Entity IS NULL AND E.Currency <> TJ.[Currency] THEN TJ.[Credit] ELSE NULL END,
					[SourceModule] = TJ.[SourceModule]
				FROM
					' + @JournalTable + ' J
					INNER JOIN #Journal TJ ON TJ.[JournalID] = J.[JournalID] AND TJ.DeleteYN = 0 
					INNER JOIN #Entity_Currency E ON E.GroupYN = 0 AND E.Entity = TJ.Entity AND E.Book = TJ.Book 
					LEFT JOIN #Entity_Currency Grp ON Grp.GroupYN <> 0 AND Grp.Entity = TJ.ConsolidationGroup
				WHERE
					J.[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID)

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT [@UserName] = @UserName, [@JournalTable] = @JournalTable, [@JobID] = @JobID, [@InstanceID] = @InstanceID

		IF @DebugBM & 16 > 0 SELECT [Step] = @Step, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 9) - Update rows', * FROM #Journal ORDER BY Entity, Book, JournalSequence, FiscalYear, ResultTypeBM, JournalNo, JournalLine
		
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
				[Currency_Transaction],
				[ValueDebit_Transaction],
				[ValueCredit_Transaction],
				[SourceModule],
				[Inserted],
				[InsertedBy]
				)
			SELECT
				[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',
				[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID) + ',
				TJ.[Entity],
				TJ.[Book],
				TJ.[FiscalYear],
				TJ.[FiscalPeriod],
				TJ.[JournalSequence],
				TJ.[JournalNo],
				TJ.[JournalLine],
				TJ.[YearMonth],
				TJ.[TransactionTypeBM],
				[BalanceYN] = ISNULL(TJ.[BalanceYN], 0),
				TJ.[Account],
				TJ.[Segment01],
				TJ.[Segment02],
				TJ.[Segment03],
				TJ.[Segment04],
				TJ.[Segment05],
				TJ.[Segment06],
				TJ.[Segment07],
				TJ.[Segment08],
				TJ.[Segment09],
				TJ.[Segment10],
				TJ.[Segment11],
				TJ.[Segment12],
				TJ.[Segment13],
				TJ.[Segment14],
				TJ.[Segment15],
				TJ.[Segment16],
				TJ.[Segment17],
				TJ.[Segment18],
				TJ.[Segment19],
				TJ.[Segment20],
				TJ.[JournalDate],
				TJ.[TransactionDate],
				[PostedDate] = CASE WHEN TJ.[Posted] <> 0 THEN GetDate() ELSE TJ.[PostedDate] END,
				[PostedStatus] = TJ.[Posted],
				[PostedBy] = CASE WHEN TJ.[Posted] <> 0 THEN ''' + @UserName + ''' ELSE TJ.[PostedBy] END,
				TJ.[Source],
				TJ.[Flow],
				[ConsolidationGroup] = CASE WHEN TJ.[ConsolidationGroup] = ''NONE'' THEN NULL ELSE TJ.[ConsolidationGroup] END,
				[InterCompanyEntity] = TJ.[InterCompany],
				TJ.[Scenario],
				TJ.[Description_Head],
				TJ.[Description_Line],
				[Currency_Book] = CASE WHEN Grp.Entity IS NULL AND E.Currency = TJ.[Currency] THEN TJ.[Currency] ELSE NULL END,
				[ValueDebit_Book] = CASE WHEN Grp.Entity IS NULL AND E.Currency = TJ.[Currency] THEN TJ.[Debit] ELSE NULL END,
				[ValueCredit_Book] = CASE WHEN Grp.Entity IS NULL AND E.Currency = TJ.[Currency] THEN TJ.[Credit] ELSE NULL END,
				[Currency_Group] = CASE WHEN Grp.Entity IS NOT NULL AND Grp.Currency = TJ.[Currency] THEN TJ.[Currency] ELSE NULL END,
				[ValueDebit_Group] = CASE WHEN Grp.Entity IS NOT NULL AND Grp.Currency = TJ.[Currency] THEN TJ.[Debit] ELSE NULL END,
				[ValueCredit_Group] = CASE WHEN Grp.Entity IS NOT NULL AND Grp.Currency = TJ.[Currency] THEN TJ.[Credit] ELSE NULL END,
				[Currency_Transaction] = CASE WHEN Grp.Entity IS NULL AND E.Currency <> TJ.[Currency] THEN TJ.[Currency] ELSE NULL END,
				[ValueDebit_Transaction] = CASE WHEN Grp.Entity IS NULL AND E.Currency <> TJ.[Currency] THEN TJ.[Debit] ELSE NULL END,
				[ValueCredit_Transaction] = CASE WHEN Grp.Entity IS NULL AND E.Currency <> TJ.[Currency] THEN TJ.[Credit] ELSE NULL END,
				TJ.[SourceModule],
				[Inserted] = GetDate(),
				[InsertedBy] = ''' + @UserName + '''
			FROM
				#Journal TJ
				INNER JOIN #Entity_Currency E ON E.GroupYN = 0 AND E.Entity = TJ.Entity AND E.Book = TJ.Book 
				LEFT JOIN #Entity_Currency Grp ON Grp.GroupYN <> 0 AND Grp.Entity = TJ.ConsolidationGroup
			WHERE
				TJ.[JournalID] IS NULL AND
				TJ.[DeleteYN] = 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#Journal (Step 10) - Insert rows FROM #Journal WHERE JournalID IS NULL AND DeleteYN = 0', * FROM #Journal WHERE JournalID IS NULL AND DeleteYN = 0 ORDER BY Entity, Book, JournalSequence, FiscalYear, ResultTypeBM, JournalNo, JournalLine

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

	SET @Step = 'Return inserted/updated Journal manual entries'
		SET @SQLStatement = '
			SELECT *
			FROM
				' + @JournalTable + ' J
			WHERE
				J.InstanceID = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND
				J.JobID = ' + CONVERT(NVARCHAR(15), @JobID) + '
			ORDER BY
				J.Entity,
				J.Book,
				J.FiscalYear,
				J.FiscalPeriod,
				J.JournalSequence,
				J.JournalNo,
				J.JournalLine'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Set Carry forward for manually entries'
--		IF @GroupYN = 0
		IF (SELECT DISTINCT [ConsolidationGroup] FROM #Journal WHERE [ResultTypeBM] & 4 > 0) IN ('NONE')
			BEGIN
				SELECT @FiscalYear = MAX([FiscalYear]) + 1 FROM #Journal

				EXEC [spSet_Journal_OP_ManAdj] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @FiscalYear=@FiscalYear, @JobID = @JobID, @Debug = @DebugSub

			END

	SET @Step = 'Fill FACT_Financials'
		--IF @GroupYN = 0 AND (SELECT COUNT(1) FROM #Journal WHERE ResultTypeBM & 24 > 0) > 0
		IF (SELECT DISTINCT [ConsolidationGroup] FROM #Journal WHERE [ResultTypeBM] & 4 > 0) IN ('NONE') AND 
			(SELECT COUNT(1) FROM #Journal WHERE ResultTypeBM & 24 > 0) > 0
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

	SET @Step = 'Drop temp tables'
		DROP TABLE #Journal
		DROP TABLE #Entity_Currency
		DROP TABLE #Balance
		DROP TABLE #FiscalPeriod
		DROP TABLE #J
	
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID

	SET @Step = 'Set EndTime for the actual job'
		EXEC [pcINTEGRATOR].[dbo].[spSet_Job]
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
