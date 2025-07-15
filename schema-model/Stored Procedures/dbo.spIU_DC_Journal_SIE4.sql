SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_Journal_SIE4]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@FiscalPeriod int = NULL,
	@StartFiscalYear int = NULL,
	@SequenceBM int = 3, --1 = GL transactions, 2 = Opening balances, 4 = Budget transactions
	@JournalTable nvarchar(100) = NULL,
	@FullReloadYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000634,
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
	@ProcedureName = 'spIU_DC_Journal_SIE4',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "404"},
		{"TKey" : "VersionID",  "TValue": "1003"},
		{"TKey" : "JobID",  "TValue": "24416"}
		]'

EXEC [spIU_DC_Journal_SIE4] @UserID = -10, @InstanceID = 404, @VersionID = 1003, @JobID = 2105, @SequenceBM = 3, @FiscalYear = 2019, @Debug = 1

EXEC [spIU_DC_Journal_SIE4] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@CalledYN bit = 1,
	@SegmentNo int,
	@Entity nvarchar(50),
	--@Column nvarchar(50),
	--@MappingTypeID int,
	@SQLStatement nvarchar(max),

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
	@Version nvarchar(50) = '2.1.1.2177'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert data to Journal during SIE4 load',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Added filtering on DROP TABLE #IB and @FiscalYear.'
		IF @Version = '2.0.3.2151' SET @Description = 'Updated datatypes in temp table #Journal.'
		IF @Version = '2.0.3.2154' SET @Description = 'Removed references to Journal_SegmentNo.Entity.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.1.2168' SET @Description = 'Added parameter @FullReloadYN.'
		IF @Version = '2.1.1.2177' SET @Description = 'Set PostedStatus = 1.'

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
			@Entity = E.MemberKey
		FROM
			[SIE4_Job] J 
			INNER JOIN Entity E ON E.EntityID = J.EntityID
		WHERE
			J.InstanceID = @InstanceID AND
			J.JobID = @JobID

		IF @JournalTable IS NULL
			EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

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
					[JournalNo] [int],
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
					[PostedStatus] [int],
					[PostedBy] [nvarchar](100) COLLATE DATABASE_DEFAULT,
					[Source] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Scenario] [nvarchar](50) COLLATE DATABASE_DEFAULT,
					[Description_Head] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Description_Line] [nvarchar](255) COLLATE DATABASE_DEFAULT,
					[Currency_Book] [nchar](3) COLLATE DATABASE_DEFAULT,
					[ValueDebit_Book] [float],
					[ValueCredit_Book] [float],
					[Currency_Transaction] [nchar](3) COLLATE DATABASE_DEFAULT,
					[ValueDebit_Transaction] [float],
					[ValueCredit_Transaction] [float],
					[SourceModule] [nvarchar](20) COLLATE DATABASE_DEFAULT,
					[SourceModuleReference] [nvarchar](100) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'INSERT INTO #Journal, transactions'
		IF @SequenceBM & 1 > 0
			BEGIN
				INSERT INTO #Journal
					(
					[JobID],
					[InstanceID],
					[Entity],
					[Book],
					[JournalSequence],
					[JournalNo],
					[JournalLine],
					[FiscalYear],
					[FiscalPeriod],
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
					[ValueCredit_Book],
					[Currency_Transaction],
					[ValueDebit_Transaction],
					[ValueCredit_Transaction]
					)
				SELECT 
					[JobID] = MAX(V.JobID),
					[InstanceID] = V.InstanceID,
					[Entity] = E.MemberKey,
					[Book] = 'GL',
					[JournalSequence] = 'SIE4_' + V.Seq + CASE WHEN ISNUMERIC(V.Ver) = 0 THEN '_' + V.Ver ELSE '' END,
					[JournalNo] = CASE WHEN ISNUMERIC(V.Ver) = 0 THEN 0 ELSE V.Ver END,
					[JournalLine] = T.Trans,
					[FiscalYear] = J.RAR_0_FROM / 10000 + I.FiscalYearNaming,
					[FiscalPeriod] = CASE WHEN DATEDIFF(MONTH, CONVERT(DATE, CONVERT(NVARCHAR(10), J.RAR_0_FROM), 112), CONVERT(DATE, CONVERT(NVARCHAR(10), V.[Date]), 112)) + 1 <= 1 THEN 1 ELSE CASE WHEN DATEDIFF(MONTH, CONVERT(DATE, CONVERT(NVARCHAR(10), J.RAR_0_FROM), 112), CONVERT(DATE, CONVERT(NVARCHAR(10), V.[Date]), 112)) + 1 >= 12 THEN 12 ELSE DATEDIFF(MONTH, CONVERT(DATE, CONVERT(NVARCHAR(10), J.RAR_0_FROM), 112), CONVERT(DATE, CONVERT(NVARCHAR(10), V.[Date]), 112)) + 1 END END,
					[YearMonth] = MAX(CASE WHEN V.[Date] < J.[RAR_0_FROM] THEN J.[RAR_0_FROM] / 100 ELSE CASE WHEN V.[Date] > J.[RAR_0_TO] THEN J.[RAR_0_TO] / 100 ELSE V.[Date] / 100 END END),
					[TransactionTypeBM] = CONVERT(int, 1),
					[BalanceYN] = CONVERT(bit, CASE WHEN LEFT(MAX(T.Account), 1) IN ('1', '2') THEN 1 ELSE 0 END),
					[Account] = MAX(T.Account),
					[Segment01] = MAX(CASE WHEN JSN.SegmentNo =  1 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  1 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  1 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment02] = MAX(CASE WHEN JSN.SegmentNo =  2 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  2 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  2 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment03] = MAX(CASE WHEN JSN.SegmentNo =  3 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  3 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  3 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment04] = MAX(CASE WHEN JSN.SegmentNo =  4 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  4 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  4 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment05] = MAX(CASE WHEN JSN.SegmentNo =  5 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  5 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  5 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment06] = MAX(CASE WHEN JSN.SegmentNo =  6 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  6 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  6 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment07] = MAX(CASE WHEN JSN.SegmentNo =  7 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  7 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  7 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment08] = MAX(CASE WHEN JSN.SegmentNo =  8 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  8 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  8 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment09] = MAX(CASE WHEN JSN.SegmentNo =  9 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  9 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo =  9 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment10] = MAX(CASE WHEN JSN.SegmentNo = 10 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 10 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 10 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment11] = MAX(CASE WHEN JSN.SegmentNo = 11 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 11 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 11 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment12] = MAX(CASE WHEN JSN.SegmentNo = 12 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 12 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 12 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment13] = MAX(CASE WHEN JSN.SegmentNo = 13 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 13 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 13 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment14] = MAX(CASE WHEN JSN.SegmentNo = 14 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 14 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 14 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment15] = MAX(CASE WHEN JSN.SegmentNo = 15 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 15 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 15 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment16] = MAX(CASE WHEN JSN.SegmentNo = 16 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 16 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 16 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment17] = MAX(CASE WHEN JSN.SegmentNo = 17 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 17 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 17 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment18] = MAX(CASE WHEN JSN.SegmentNo = 18 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 18 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 18 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment19] = MAX(CASE WHEN JSN.SegmentNo = 19 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 19 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 19 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[Segment20] = MAX(CASE WHEN JSN.SegmentNo = 20 THEN CASE WHEN T.DimCode_01 = JSN.SegmentCode THEN T.ObjectCode_01 ELSE CASE WHEN T.DimCode_02 = JSN.SegmentCode THEN T.ObjectCode_02 ELSE CASE WHEN T.DimCode_03 = JSN.SegmentCode THEN T.ObjectCode_03 ELSE CASE WHEN T.DimCode_04 = JSN.SegmentCode THEN T.ObjectCode_04 ELSE CASE WHEN T.DimCode_05 = JSN.SegmentCode THEN T.ObjectCode_05 ELSE CASE WHEN T.DimCode_06 = JSN.SegmentCode THEN T.ObjectCode_06 ELSE CASE WHEN T.DimCode_07 = JSN.SegmentCode THEN T.ObjectCode_07 ELSE CASE WHEN T.DimCode_08 = JSN.SegmentCode THEN T.ObjectCode_08 ELSE CASE WHEN T.DimCode_09 = JSN.SegmentCode THEN T.ObjectCode_09 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 20 THEN CASE WHEN T.DimCode_10 = JSN.SegmentCode THEN T.ObjectCode_10 ELSE CASE WHEN T.DimCode_11 = JSN.SegmentCode THEN T.ObjectCode_11 ELSE CASE WHEN T.DimCode_12 = JSN.SegmentCode THEN T.ObjectCode_12 ELSE CASE WHEN T.DimCode_13 = JSN.SegmentCode THEN T.ObjectCode_13 ELSE CASE WHEN T.DimCode_14 = JSN.SegmentCode THEN T.ObjectCode_14 ELSE CASE WHEN T.DimCode_15 = JSN.SegmentCode THEN T.ObjectCode_15 ELSE CASE WHEN T.DimCode_16 = JSN.SegmentCode THEN T.ObjectCode_16 ELSE CASE WHEN T.DimCode_17 = JSN.SegmentCode THEN T.ObjectCode_17 ELSE CASE WHEN T.DimCode_18 = JSN.SegmentCode THEN T.ObjectCode_18 ELSE '' END END END END END END END END END ELSE '' END + CASE WHEN JSN.SegmentNo = 20 THEN CASE WHEN T.DimCode_19 = JSN.SegmentCode THEN T.ObjectCode_19 ELSE CASE WHEN T.DimCode_20 = JSN.SegmentCode THEN T.ObjectCode_20 ELSE '' END END ELSE '' END),
					[JournalDate] = MAX(CONVERT(DATE, CONVERT(NVARCHAR(10), V.[Date]), 112)),
					[TransactionDate] = MAX(CONVERT(DATE, CONVERT(NVARCHAR(10), ISNULL(T.[Date], V.[Date])), 112)),
					[PostedDate] = MAX(CONVERT(DATE, CONVERT(NVARCHAR(10), ISNULL(T.[Date], V.[Date])), 112)),
					[PostedStatus] = 1,
					[PostedBy] = '',
					[Source] = 'SIE4',
					[Scenario] = 'ACTUAL',
					[Description_Head] = MAX(ISNULL(V.[Description], '')),
					[Description_Line] = MAX(ISNULL(T.[Description], '')),
					[Currency_Book] = MAX(ISNULL(J.Valuta, EB.Currency)),
					[ValueDebit_Book] = MAX(CASE WHEN T.Amount > 0 THEN T.Amount ELSE 0 END),
					[ValueCredit_Book] = MAX(CASE WHEN T.Amount < 0 THEN T.Amount * -1 ELSE 0 END),
					[Currency_Transaction] = NULL,
					[ValueDebit_Transaction] = NULL,
					[ValueCredit_Transaction] = NULL
				FROM 
					Instance I
					INNER JOIN [SIE4_Job] J ON J.InstanceID = I.InstanceID AND J.JobID = @JobID
					INNER JOIN SIE4_Ver V ON V.InstanceID = J.InstanceID AND V.JobID = J.JobID
					INNER JOIN SIE4_Trans T ON T.JobID = V.JobID AND T.InstanceID = V.InstanceID AND T.Seq = V.Seq AND T.Ver = V.Ver
					INNER JOIN Entity E ON E.EntityID = J.EntityID
					INNER JOIN Entity_Book EB ON EB.EntityID = J.EntityID AND EB.Book = 'GL'
					INNER JOIN Journal_SegmentNo JSN ON JSN.InstanceID = V.InstanceID AND JSN.EntityID = E.EntityID AND JSN.Book = 'GL'
				WHERE
					I.InstanceID = @InstanceID AND
					J.RAR_0_FROM / 10000 + I.FiscalYearNaming = @FiscalYear
				GROUP BY
					V.InstanceID, --[InstanceID]
					E.MemberKey, --[Entity]
					V.Seq, --[JournalClass]
					V.Ver, --[JournalNo]
					T.Trans, --[JournalLine]
					J.RAR_0_FROM / 10000 + I.FiscalYearNaming, --[FiscalYear]
					DATEDIFF(MONTH, CONVERT(DATE, CONVERT(NVARCHAR(10), J.RAR_0_FROM), 112), CONVERT(DATE, CONVERT(NVARCHAR(10), V.[Date]), 112)) + 1	--[TimeFiscalPeriod]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'INSERT INTO #Journal, Opening balance'
		IF @SequenceBM & 2 > 0
			BEGIN
				CREATE TABLE #IB
					(
					JournalLine int IDENTITY(1, 1),
					Account nvarchar(50) COLLATE DATABASE_DEFAULT
					)

				INSERT INTO #IB
					(
					Account
					)
				SELECT DISTINCT
					B.[Account]
				FROM
					[SIE4_Balance] B
				WHERE
					B.[InstanceID] = @InstanceID AND
					B.[JobID] = @JobID AND
					B.[Param] = '#IB' AND
					B.[RAR] = 0
				ORDER BY
					B.Account

				INSERT INTO #Journal
					(
					[JobID],
					[InstanceID],
					[Entity],
					[Book],
					[JournalSequence],
					[JournalNo],
					[JournalLine],
					[FiscalYear],
					[FiscalPeriod],
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
					[ValueCredit_Book],
					[Currency_Transaction],
					[ValueDebit_Transaction],
					[ValueCredit_Transaction]
					)
				SELECT 
					[JobID] = B.JobID,
					[InstanceID] = B.InstanceID,
					[Entity] = E.MemberKey,
					[Book] = 'GL',
					[JournalSequence] = 'SIE4_IB',
					[JournalNo] = 0,
					[JournalLine] = IB.[JournalLine],
					[FiscalYear] = J.RAR_0_FROM / 10000 + I.FiscalYearNaming,
					[FiscalPeriod] = 0,
					[YearMonth] = J.RAR_0_FROM / 100,
					[TransactionTypeBM] = 1,
					[BalanceYN] = 1,
					[Account] = B.Account,
					[Segment01] = '',
					[Segment02] = '',
					[Segment03] = '',
					[Segment04] = '',
					[Segment05] = '',
					[Segment06] = '',
					[Segment07] = '',
					[Segment08] = '',
					[Segment09] = '',
					[Segment10] = '',
					[Segment11] = '',
					[Segment12] = '',
					[Segment13] = '',
					[Segment14] = '',
					[Segment15] = '',
					[Segment16] = '',
					[Segment17] = '',
					[Segment18] = '',
					[Segment19] = '',
					[Segment20] = '',
					[JournalDate] = CONVERT(DATE, CONVERT(NVARCHAR(10), J.RAR_0_FROM), 112),
					[TransactionDate] = CONVERT(DATE, CONVERT(NVARCHAR(10), J.RAR_0_FROM), 112),
					[PostedDate] = CONVERT(DATE, CONVERT(NVARCHAR(10), J.RAR_0_FROM), 112),
					[PostedStatus] = 1,
					[PostedBy] = '',
					[Source] = 'SIE4',
					[Scenario] = 'ACTUAL',
					[Description_Head] = 'Incoming balance',
					[Description_Line] = '',
					[Currency_Book] = ISNULL(J.Valuta, EB.Currency),
					[ValueDebit_Book] = CASE WHEN B.Amount > 0 THEN B.Amount ELSE 0 END,
					[ValueCredit_Book] = CASE WHEN B.Amount < 0 THEN B.Amount * -1 ELSE 0 END,
					[Currency_Transaction] = NULL,
					[ValueDebit_Transaction] = NULL,
					[ValueCredit_Transaction] = NULL
				FROM
					Instance I
					INNER JOIN [SIE4_Job] J ON J.InstanceID = I.InstanceID AND J.JobID = @JobID
					INNER JOIN [SIE4_Balance] B ON B.[InstanceID] = I.InstanceID AND B.[JobID] = J.JobID AND B.[Param] = '#IB' AND B.[RAR] = 0
					INNER JOIN Entity E ON E.EntityID = J.EntityID
					INNER JOIN Entity_Book EB ON EB.EntityID = J.EntityID AND EB.Book = 'GL'
					INNER JOIN #IB IB ON IB.Account = B.Account
				WHERE
					I.[InstanceID] = @InstanceID AND
					J.RAR_0_FROM / 10000 + I.FiscalYearNaming = @FiscalYear

				SET @Selected = @Selected + @@ROWCOUNT
			END

/**************************
--Set Mapping Step moved from [spIU_DC_Journal_SIE4] to [spIU_DC_Journal] after @Step = 'Run Entity_Cursor'

	SET @Step = 'Set Mapping'
		DECLARE Mapping_Cursor CURSOR FOR

			SELECT 
				[Column] = CASE WHEN JSN.SegmentNo = 0 THEN 'Account' ELSE 'Segment' + CASE WHEN JSN.SegmentNo <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), JSN.SegmentNo) END,
				DR.MappingTypeID
			FROM
				[Journal_SegmentNo] JSN 
				INNER JOIN Dimension_Rule DR ON DR.InstanceID = JSN.InstanceID AND DR.Entity_MemberKey = JSN.Entity AND DR.DimensionID = JSN.DimensionID AND DR.SelectYN <> 0
			WHERE
				JSN.InstanceID = @InstanceID AND
				JSN.Entity = @Entity

			OPEN Mapping_Cursor
			FETCH NEXT FROM Mapping_Cursor INTO @Column, @MappingTypeID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = '
						UPDATE #Journal
						SET
							' + @Column + ' = CASE WHEN ' + CONVERT(nvarchar(10), @MappingTypeID) + ' = 1 THEN ''' + @Entity + '_'' ELSE '''' END + ' + @Column + ' + CASE WHEN ' + CONVERT(nvarchar(10), @MappingTypeID) + ' = 2 THEN ''_' + @Entity + ''' ELSE '''' END'
					
					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM Mapping_Cursor INTO @Column, @MappingTypeID
				END

		CLOSE Mapping_Cursor
		DEALLOCATE Mapping_Cursor
************************************/

	SET @Step = 'Show data if not called'
		IF @CalledYN = 0
			BEGIN
				SELECT TempTable = '#Journal', * FROM #Journal
			END

	SET @Step = 'DROP temp tables'
		IF @CalledYN = 0 DROP TABLE #Journal
		IF @SequenceBM & 2 > 0 DROP TABLE #IB

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
