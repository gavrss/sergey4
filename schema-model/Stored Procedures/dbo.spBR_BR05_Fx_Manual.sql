SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_Fx_Manual]

	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@GroupCurrency nchar(3) = NULL,
	@FiscalYear int = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',
	@ConsolidationGroup nvarchar(50) = NULL, --Optional
	@Level nvarchar(10) = 'Month',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	--@ProcedureID int = 880000557,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

AS

/*
		EXEC [dbo].[spBR_BR05_Fx_Manual]
			@UserID = -10,
			@InstanceID = 527,
			@VersionID = 1055,
			@BusinessRuleID = NULL,
			@CallistoDatabase = NULL,
			@GroupCurrency = 'CAD',
			@FiscalYear = 2021,
			@Scenario = 'ACTUAL',
			@ConsolidationGroup = 'Group',
			@Level = NULL,
			@JobID = -100,
			@Debug = 1

*/

IF @InstanceID <> 527 OR @FiscalYear <> 2021
	RETURN

SELECT
	[Entity] = 'GGI02',
	[YearMonth] = 202103,
	[Account] = sub.[Account],
	[Segment01] = '00',
	[Segment02] = sub.[Segment02],
	[Flow] = 'OP_Adjust',
	[ValueDebit_Group] = sub.[ValueDebit_Group],
	[ValueCredit_Group] = sub.[ValueCredit_Group]
INTO
	#Trans32
FROM
	(
	SELECT
		[Account] = '3000',
		[Segment02] = '01',
		[ValueDebit_Group] = 34536,
		[ValueCredit_Group] = 0
	UNION SELECT
		[Account] = '3000',
		[Segment02] = '02',
		[ValueDebit_Group] = 6024,
		[ValueCredit_Group] = 0
	UNION SELECT
		[Account] = '3006',
		[Segment02] = '02',
		[ValueDebit_Group] = 0,
		[ValueCredit_Group] = 40559
	) sub

IF @Debug <> 0
	BEGIN
		SELECT [TempTable]='#Trans32', * FROM #Trans32
	END

DELETE pcETL_E2IP..Journal
WHERE
	[InstanceID] = @InstanceID AND
	[TransactionTypeBM] & 32 > 0 AND
	[SourceModuleReference] = 'Manual_HC'

INSERT INTO [pcETL_E2IP].[dbo].[Journal]
	(
	[JobID]
	,[InstanceID]
	,[Entity]
	,[Book]
	,[FiscalYear]
	,[FiscalPeriod]
	,[JournalSequence]
	,[JournalNo]
	,[JournalLine]
	,[YearMonth]
	,[TransactionTypeBM]
	,[BalanceYN]
	,[Account]
	,[Segment01]
	,[Segment02]
	,[Segment03]
	,[Segment04]
	,[Segment05]
	,[Segment06]
	,[Segment07]
	,[Segment08]
	,[Segment09]
	,[Segment10]
	,[Segment11]
	,[Segment12]
	,[Segment13]
	,[Segment14]
	,[Segment15]
	,[Segment16]
	,[Segment17]
	,[Segment18]
	,[Segment19]
	,[Segment20]
	,[JournalDate]
	,[TransactionDate]
	,[PostedDate]
	,[PostedStatus]
	,[PostedBy]
	,[Source]
	,[Flow]
	,[ConsolidationGroup]
	,[InterCompanyEntity]
	,[Scenario]
	,[Customer]
	,[Supplier]
	,[Description_Head]
	,[Description_Line]
	,[Currency_Book]
	,[ValueDebit_Book]
	,[ValueCredit_Book]
	,[Currency_Group]
	,[ValueDebit_Group]
	,[ValueCredit_Group]
	,[Currency_Transaction]
	,[ValueDebit_Transaction]
	,[ValueCredit_Transaction]
	,[SourceModule]
	,[SourceModuleReference]
	,[SourceCounter]
	,[SourceGUID]
	,[Inserted]
	,[InsertedBy]
	)

SELECT 
	[JobID] = @JobID
      ,[InstanceID] = @InstanceID
      ,[Entity]
      ,[Book] = 'MainBook'
      ,[FiscalYear] = [YearMonth] / 100
      ,[FiscalPeriod] = [YearMonth] % 100
      ,[JournalSequence] = 'CONS'
      ,[JournalNo] = 0
      ,[JournalLine] = 0
      ,[YearMonth]
      ,[TransactionTypeBM] =32
      ,[BalanceYN] = 1
      ,[Account]
      ,[Segment01]
      ,[Segment02]
      ,[Segment03] = ''
      ,[Segment04] = ''
      ,[Segment05] = ''
      ,[Segment06] = ''
      ,[Segment07] = ''
      ,[Segment08] = ''
      ,[Segment09] = ''
      ,[Segment10] = ''
      ,[Segment11] = ''
      ,[Segment12] = ''
      ,[Segment13] = ''
      ,[Segment14] = ''
      ,[Segment15] = ''
      ,[Segment16] = ''
      ,[Segment17] = ''
      ,[Segment18] = ''
      ,[Segment19] = ''
      ,[Segment20] = ''
      ,[JournalDate] = GetDate()
      ,[TransactionDate] = GetDate()
      ,[PostedDate] = GetDate()
      ,[PostedStatus] = 1
      ,[PostedBy] = suser_name()
      ,[Source] = 'CFX'
      ,[Flow]
      ,[ConsolidationGroup] = 'Group'
      ,[InterCompanyEntity] = 'NONE'
      ,[Scenario] = 'ACTUAL'
      ,[Customer] = NULL
      ,[Supplier] = '0'
      ,[Description_Head] = 'Manual correction'
      ,[Description_Line] = ''
      ,[Currency_Book] = NULL
      ,[ValueDebit_Book] = 0
      ,[ValueCredit_Book] = 0
      ,[Currency_Group] = 'CAD'
      ,[ValueDebit_Group]
      ,[ValueCredit_Group]
      ,[Currency_Transaction] = NULL
      ,[ValueDebit_Transaction] = 0
      ,[ValueCredit_Transaction] = 0
      ,[SourceModule] = 'CFX'
      ,[SourceModuleReference] = 'Manual_HC'
      ,[SourceCounter] = NULL
      ,[SourceGUID] = NULL
      ,[Inserted] = GetDate()
      ,[InsertedBy] = suser_name()
  FROM 
	#Trans32

SELECT *
FROM pcETL_E2IP..Journal
WHERE
	[JobID] = @JobID AND
	[InstanceID] = @InstanceID AND
	[TransactionTypeBM] & 32 > 0 AND
	[SourceModuleReference] = 'Manual_HC'

DROP TABLE #Trans32
GO
