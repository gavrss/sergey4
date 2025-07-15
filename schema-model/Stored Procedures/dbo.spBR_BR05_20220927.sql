SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_20220927]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@SequenceBM int = 511, --1=InterCompany Counterpart, 2=HistRate, 4=Retained earnings, 8=Copy open, 16=Consolidation before FX, 32=FX, 64=Consolidation after FX, 128=Into Journal, 256=Into FACT_Financials
	--1=Copy open, 2=Consolidation before FX, 4=FX, 8=Consolidation after FX, 16=Into Journal, 32=Into FACT_Financials
	@EventTypeID int = NULL,
	@FiscalYear int = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',
	@FxRate_Scenario nvarchar(50) = NULL, --Optional
	@ConsolidationGroup nvarchar(50) = NULL, --Optional
	@Entity_MemberKey nvarchar(50) = NULL, --Optional
	@Level nvarchar(10) = 'Month',
	@Source_DataClassID int = NULL,
	@Filter nvarchar(max) = NULL,
	--@FrequencyID int = NULL, --Periods where rules should be applied; Yearly, Quarterly, Monthly Separate config table

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000531,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose (Fill table pcINTEGRATOR_Log..wrk_Debug_JournalBase)

--#WITH ENCRYPTION#--

AS
/*
EXEC [spBR_BR05] @UserID=-10, @InstanceID=476, @VersionID=1024, @BusinessRuleID = 3058, @FiscalYear = 2019, @ConsolidationGroup = 'G_ASRV', @Entity_MemberKey = 'IAH', @DebugBM=3
EXEC [spBR_BR05] @UserID=-10, @InstanceID=476, @VersionID=1024, @BusinessRuleID = 3058, @FiscalYear = 2019, @ConsolidationGroup = 'G_ASRV', @DebugBM=3
EXEC [spBR_BR05] @UserID=-10, @InstanceID=476, @VersionID=1024, @BusinessRuleID = 3058, @FiscalYear = 2019, @DebugBM=3
EXEC [spBR_BR05] @UserID=-10, @InstanceID=-1335, @VersionID=-1273, @BusinessRuleID = 3061, @FiscalYear = 2020, @ConsolidationGroup = 'G_INTERFOR', @Entity_MemberKey = 'USHO', @DebugBM=1

EXEC [spBR_BR05] @UserID=-10, @InstanceID=529, @VersionID=1001, @BusinessRuleID = 1001, @FiscalYear = 2020, @ConsolidationGroup = 'A', @FxRate_Scenario = 'ACT_Floating FX', @Entity_MemberKey = '42', @DebugBM=17
EXEC [spBR_BR05] @UserID=-10, @InstanceID=529, @VersionID=1001, @BusinessRuleID = 1001, @FiscalYear = 2020, @ConsolidationGroup = 'A', @FxRate_Scenario = 'ACT_Floating FX', @Entity_MemberKey = '23', @DebugBM=17
EXEC [spBR_BR05] @UserID=-10, @InstanceID=529, @VersionID=1001, @BusinessRuleID = 1001, @FiscalYear = 2020, @ConsolidationGroup = 'A', @FxRate_Scenario = 'ACT_Floating FX', @DebugBM=17
EXEC [spBR_BR05] @UserID=-10, @InstanceID=529, @VersionID=1001, @BusinessRuleID = 1001, @FiscalYear = 2021, @ConsolidationGroup = 'A', @FxRate_Scenario = 'ACT_Floating FX', @DebugBM=17
EXEC [spBR_BR05] @UserID=-10, @InstanceID=529, @VersionID=1001, @BusinessRuleID = 1001, @FiscalYear = 2020, @ConsolidationGroup = 'A', @FxRate_Scenario = 'ACT_Floating FX', @SequenceBM = 1, @DebugBM=23

EXEC [spBR_BR05] @UserID=-10, @InstanceID=527, @VersionID=1055, @BusinessRuleID = 1001, @FiscalYear = 2022, @ConsolidationGroup = 'Group', @Entity_MemberKey = '1004', @SequenceBM = 1, @DebugBM=51
EXEC [spBR_BR05] @UserID=-10, @InstanceID=527, @VersionID=1055, @BusinessRuleID = 1001, @FiscalYear = 2016, @ConsolidationGroup = 'Group'
EXEC [spBR_BR05] @UserID=-10, @InstanceID=527, @VersionID=1055, @BusinessRuleID = 1001, @FiscalYear = 2017, @ConsolidationGroup = 'Group'
EXEC [spBR_BR05] @UserID=-10, @InstanceID=527, @VersionID=1055, @BusinessRuleID = 1001, @FiscalYear = 2018, @ConsolidationGroup = 'Group'--, @Entity_MemberKey = 'GGI02', @Debug=0
EXEC [spBR_BR05] @UserID=-10, @InstanceID=527, @VersionID=1055, @BusinessRuleID = 1001, @FiscalYear = 2019, @ConsolidationGroup = 'Group'
EXEC [spBR_BR05] @UserID=-10, @InstanceID=527, @VersionID=1055, @BusinessRuleID = 1001, @FiscalYear = 2020, @ConsolidationGroup = 'Group'
EXEC [spBR_BR05] @UserID=-10, @InstanceID=527, @VersionID=1055, @BusinessRuleID = 1001, @FiscalYear = 2021, @ConsolidationGroup = 'Group'--, @DebugBM=16
EXEC [spBR_BR05] @UserID=-10, @InstanceID=527, @VersionID=1055, @BusinessRuleID = 1001, @FiscalYear = 2022, @ConsolidationGroup = 'Group'--, @DebugBM=16

EXEC [spBR_BR05] @UserID=-10, @InstanceID=531, @VersionID=1057, @BusinessRuleID = 2616, @FiscalYear = 2022, @ConsolidationGroup = 'Group', @DebugBM=19
EXEC [spBR_BR05] @UserID=-10, @InstanceID=527, @VersionID=1055, @BusinessRuleID = 1001, @FiscalYear = 2021, @ConsolidationGroup = 'Group', @DebugBM=19
EXEC [spBR_BR05] @UserID=-10, @InstanceID=531, @VersionID=1057, @BusinessRuleID = 2616, @DebugBM=19

EXEC pcINTEGRATOR..[spBR_BR05] @UserID=-10, @InstanceID=572, @VersionID=1080, @BusinessRuleID = 2587, @ConsolidationGroup = 'G_BRADKEN', @FiscalYear = 2022

EXEC [spBR_BR05] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@ValidYN bit,
	@TextValidation nvarchar(1024),
	@DataClassID int,
	@DataClassTypeID int,
	@EntityGroupID int,
	@JournalTable nvarchar(100),
	@GroupCurrency nchar(3),
	@CallistoDatabase nvarchar(100),
	@FiscalPeriod int,
	@YearMonth int,
	@PrevYearMonth int,
	@EntityGroupBook nvarchar(50),
	@InterCompany_BusinessRuleID int,
	@EntityID int,
	@Account_OCI nvarchar(255),
	@Account_OCI_String nvarchar(255),
	@MasterClosedFiscalYear int,
	@StartFiscalYear int,
	@EndFiscalYear int,
	@CalledYN bit = 1,
	@Source_DataClassName nvarchar(50),
	@Source_DataClassTypeID int,
	@Source_StorageTypeBM int,

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
	@Version nvarchar(50) = '2.1.2.2187'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Running business rule BR05.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2151' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2152' SET @Description = 'Enhancements.'
		IF @Version = '2.0.3.2153' SET @Description = 'TransactionTypeBM = 8.'
		IF @Version = '2.1.1.2169' SET @Description = 'Made generic.'
		IF @Version = '2.1.1.2170' SET @Description = 'Set EndTime for the actual job. Set InterCompanyEntity in Journal table.'
		IF @Version = '2.1.1.2171' SET @Description = 'Handle HistRate. Added parameter @ConsolidationStep for copy data to FACT table.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added call to [spBR_BR05_OBAdj]'
		IF @Version = '2.1.2.2179' SET @Description = 'Implement debug into pcINTEGRATOR_Log..wrk_Debug_JournalBase'
		IF @Version = '2.1.2.2181' SET @Description = 'Upgraded version of temp table #FilterTable'
		IF @Version = '2.1.2.2183' SET @Description = 'Upgraded version of temp table #FilterTable'
		IF @Version = '2.1.2.2186' SET @Description = 'Changed order for setting variables.'
		IF @Version = '2.1.2.2187' SET @Description = 'Handle multiple scenarios and dataclass sources. Calculate Retained earnings before HistRate.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables 1'
		SELECT
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

		SET @FxRate_Scenario = ISNULL(@FxRate_Scenario, @Scenario)

		IF @Source_DataClassID IS NULL
			SELECT
				@Source_DataClassID = DataClassID
			FROM
				pcINTEGRATOR_Data..DataClass
			WHERE 
				[InstanceID]=@InstanceID AND
				[VersionID]=@VersionID AND
				[DataClassTypeID] = -5 AND
				[SelectYN] <> 0 AND
				[DeletedID] IS NULL

		SELECT
			@Source_DataClassName = [DataClassName],
			@Source_DataClassTypeID = [DataClassTypeID],
			@Source_StorageTypeBM = [StorageTypeBM]
		FROM
			pcINTEGRATOR_Data..DataClass
		WHERE 
			[InstanceID]=@InstanceID AND
			[VersionID]=@VersionID AND
			[DataClassID] = @Source_DataClassID AND
			[SelectYN] <> 0 AND
			[DeletedID] IS NULL

		IF @DebugBM & 2 > 0
			SELECT
				[@Source_DataClassID] = @Source_DataClassID,
				[@Source_DataClassName] = @Source_DataClassName,
				[@Source_DataClassTypeID] = @Source_DataClassTypeID,
				[@Source_StorageTypeBM] = @Source_StorageTypeBM

--SELECT * FROM pcINTEGRATOR_Data..DataClass WHERE InstanceID = 527

	SET @Step = 'Start Job'
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

	SET @Step = 'Check if configuration is valid'
		EXEC [spBR_BR05_Validate] @UserID=-10, @InstanceID=@InstanceID, @VersionID=@VersionID, @BusinessRuleID = @BusinessRuleID, @ValidYN = @ValidYN OUT, @TextValidation = @TextValidation OUT, @JobID=@JobID, @Debug=@DebugSub

		IF @ValidYN = 0
			BEGIN
				SET @Message = @TextValidation
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Set procedure variables 2'
		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			pcINTEGRATOR_Data..[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		SELECT
			@DataClassID = [DataClassID],
			@InterCompany_BusinessRuleID = [InterCompany_BusinessRuleID]
		FROM
			pcINTEGRATOR_Data..BR05_Master
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			BusinessRuleID = @BusinessRuleID

		SELECT
			@DataClassTypeID = DataClassTypeID
		FROM
			DataClass
		WHERE
			DataClassID = @DataClassID

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT

		EXEC [pcINTEGRATOR].[dbo].[spGet_MasterClosedYear]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@MasterClosedFiscalYear = @MasterClosedFiscalYear OUT,
			@JobID = @JobID

		SET @StartFiscalYear = @MasterClosedFiscalYear + 1
		SET @EndFiscalYear = YEAR(GetDate()) + 1

		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,	
				[@DataClassID] = @DataClassID,
				[@DataClassTypeID] = @DataClassTypeID,
				[@JournalTable] = @JournalTable,
				[@InterCompany_BusinessRuleID] = @InterCompany_BusinessRuleID,
				[@Scenario] = @Scenario,
				[@FxRate_Scenario] = @FxRate_Scenario,
				[@SequenceBM] = @SequenceBM,
				[@MasterClosedFiscalYear] = @MasterClosedFiscalYear,
				[@StartFiscalYear] = @StartFiscalYear,
				[@EndFiscalYear] = @EndFiscalYear,
				[@FiscalYear] = @FiscalYear,
				[@Entity_MemberKey] = @Entity_MemberKey

	SET @Step = 'Check configuration'
		IF @DataClassTypeID <> -5
			BEGIN
				SET @Message = 'Current configuration is not yet handled'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Truncate TABLE [wrk_Debug_JournalBase]'
		IF @DebugBM & 32 > 0 TRUNCATE TABLE [pcINTEGRATOR_Log].[dbo].[wrk_Debug_JournalBase]

	SET @Step = 'CREATE TABLE #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int
			)

	SET @Step = 'CREATE TABLE #AccountExist'
		CREATE TABLE #AccountExist
			(
			Entity nvarchar(50) COLLATE DATABASE_DEFAULT,
			Account nvarchar(50) COLLATE DATABASE_DEFAULT,
			ExistYN bit
			)

	SET @Step = 'CREATE TABLE #EntityBook'
		CREATE TABLE #EntityBook
			(
			[EntityID] int,
			[MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[BookTypeBM] int,
			[Currency] nchar(3),
			[OwnershipConsolidation] float,
			[ConsolidationMethodBM] int,
			[Account_RE] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Account_OCI] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[SelectYN] bit
			)

	SET @Step = 'CREATE TABLE #JournalBase'
		CREATE TABLE #JournalBase
			(
			[Counter] int IDENTITY(1,1),
			[ReferenceNo] int,
			[Rule_ConsolidationID] int,
			[Rule_FXID] int,
			[ConsolidationMethodBM] int,
			[InstanceID] int,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT, 
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] int,
			[FiscalPeriod] int,
			[JournalSequence] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[JournalNo] int,
			[JournalLine] int,
			[YearMonth] int,
			[TransactionTypeBM] int,
			[BalanceYN] bit,
			[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
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
			[Segment20] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[JournalDate] date,
			[TransactionDate] date,
			[PostedDate] date,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Flow] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[ConsolidationGroup] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[InterCompanyEntity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Customer] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Supplier] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Description_Head] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description_Line] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Currency_Book] nchar(3) COLLATE DATABASE_DEFAULT,
			[Value_Book] float,
			[Currency_Group] nchar(3) COLLATE DATABASE_DEFAULT,
			[Value_Group] float,
			[Currency_Transaction] nchar(3) COLLATE DATABASE_DEFAULT,
			[Value_Transaction] float,
			[SourceModule] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[SourceModuleReference] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Inserted] datetime DEFAULT getdate()
			)

	SET @Step = 'CREATE TABLE #FilterTable'
		IF OBJECT_ID(N'TempDB.dbo.#FilterTable', N'U') IS NULL
			BEGIN
				CREATE TABLE #FilterTable
					(
					[StepReference] nvarchar(20) COLLATE DATABASE_DEFAULT,
					[TupleNo] int,
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[DimensionTypeID] int,
					[StorageTypeBM] int,
					[SortOrder] int,
					[ObjectReference] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[HierarchyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[PropertyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[JournalColumn] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
					[Filter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[PropertyFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[Segment] nvarchar(20) COLLATE DATABASE_DEFAULT,
					[Method] nvarchar(20) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'CREATE TABLE #Account_OCI'
		CREATE TABLE #Account_OCI
			(
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Account_OCI] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		IF @DebugBM & 16 > 0 SELECT [Step] = 'Initial settings', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Set InterCompany Counterpart'
		IF @SequenceBM & 1 > 0 AND @Source_DataClassTypeID = -5
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@UserID]=@UserID, [@InstanceID]=@InstanceID, [@VersionID]=@VersionID, [@BusinessRuleID]=@InterCompany_BusinessRuleID, [@JobID]=@JobID
				IF @InterCompany_BusinessRuleID IS NOT NULL
					EXEC [spBR_BR14] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @BusinessRuleID=@InterCompany_BusinessRuleID, @FiscalYear=@FiscalYear, @JobID=@JobID, @Debug=@DebugSub
			END

	SET @Step = 'Run ConsolidationGroup Cursor'
		SELECT DISTINCT
			EH.EntityGroupID,
			ConsolidationGroup = E.MemberKey,
			GroupCurrency = EB.Currency
		INTO
			#ConsolidationGroup_Cursor_Table
		FROM
			Entity E
			INNER JOIN EntityHierarchy EH ON EH.InstanceID = E.InstanceID AND EH.VersionID = E.VersionID AND EH.EntityGroupID = E.EntityID
			INNER JOIN Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 16 > 0 AND EB.SelectYN <> 0
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			(E.MemberKey = @ConsolidationGroup OR @ConsolidationGroup IS NULL) AND
			E.EntityTypeID = 0 AND
			E.SelectYN <> 0 AND
			E.DeletedID IS NULL

		IF @DebugBM & 2 > 0 SELECT TempTable = '#ConsolidationGroup_Cursor_Table', * FROM #ConsolidationGroup_Cursor_Table ORDER BY EntityGroupID

		IF CURSOR_STATUS('global','ConsolidationGroup_Cursor') >= -1 DEALLOCATE ConsolidationGroup_Cursor
		DECLARE ConsolidationGroup_Cursor CURSOR FOR
			
			SELECT DISTINCT
				EntityGroupID,
				ConsolidationGroup,
				GroupCurrency
			FROM
				#ConsolidationGroup_Cursor_Table
			ORDER BY
				EntityGroupID

			OPEN ConsolidationGroup_Cursor
			FETCH NEXT FROM ConsolidationGroup_Cursor INTO @EntityGroupID, @ConsolidationGroup, @GroupCurrency

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@EntityGroupID] = @EntityGroupID, [@ConsolidationGroup] = @ConsolidationGroup, [@GroupCurrency] = @GroupCurrency

					TRUNCATE TABLE #EntityBook
					INSERT INTO #EntityBook
						(
						[EntityID],
						[MemberKey],
						[Book],
						[BookTypeBM],
						[Currency],
						[OwnershipConsolidation],
						[ConsolidationMethodBM],
						[SelectYN]
						)
					SELECT 
						[EntityID] = E.[EntityID],
						[MemberKey] = E.[MemberKey],
						[Book] = EB.[Book],
						[BookTypeBM] = EB.[BookTypeBM],
						[Currency] = EB.[Currency],
						[OwnershipConsolidation] = EH.[OwnershipConsolidation],
						[ConsolidationMethodBM] = EH.[ConsolidationMethodBM],
						[SelectYN] = CASE WHEN E.[MemberKey] = @Entity_MemberKey OR @Entity_MemberKey IS NULL THEN 1 ELSE 0 END
					FROM 
						Entity E
						INNER JOIN Entity_Book EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID] AND EB.[BookTypeBM] & 18 > 0 AND EB.[SelectYN] <> 0
						INNER JOIN EntityHierarchy EH ON EH.[InstanceID] = E.[InstanceID] AND EH.[VersionID] = E.[VersionID] AND EH.[EntityGroupID] = @EntityGroupID AND EH.[EntityID] = E.[EntityID]
					WHERE
						E.[InstanceID] = @InstanceID AND
						E.[VersionID] = @VersionID AND
						E.[SelectYN] <> 0 AND
						E.[DeletedID] IS NULL
					ORDER BY
						E.[MemberKey],
						EB.[Book]

					UPDATE EB
					SET
						[Account_RE] = LTRIM(RTRIM(EPV.[EntityPropertyValue]))
					FROM
						#EntityBook EB
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV ON EPV.[InstanceID] = @InstanceID AND EPV.[VersionID] = @VersionID AND EPV.[EntityID] = EB.[EntityID] AND EPV.[EntityPropertyTypeID] = -10 AND EPV.[SelectYN] <> 0

					UPDATE EB
					SET
						[Account_OCI] = EPV.[EntityPropertyValue]
					FROM
						#EntityBook EB
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV ON EPV.[InstanceID] = @InstanceID AND EPV.[VersionID] = @VersionID AND EPV.[EntityID] = EB.[EntityID] AND EPV.[EntityPropertyTypeID] = -11 AND EPV.[SelectYN] <> 0

					TRUNCATE TABLE #Account_OCI
					INSERT INTO #Account_OCI
						(
						[Entity],
						[Account_OCI]
						)
					SELECT
						[Entity] = [MemberKey],
						[Account_OCI] = LTRIM(RTRIM([Value]))
					FROM
						#EntityBook EB
						CROSS APPLY STRING_SPLIT (EB.[Account_OCI], ',')
					WHERE
						EB.[SelectYN] <> 0 AND
						LEN(EB.[Account_OCI]) > 0

					IF @DebugBM & 2 > 0 
						BEGIN
							SELECT TempTable = '#EntityBook', [@ConsolidationGroup] = @ConsolidationGroup, * FROM #EntityBook ORDER BY [ConsolidationMethodBM], [MemberKey]
							SELECT TempTable = '#Account_OCI', * FROM #Account_OCI ORDER BY [Entity], [Account_OCI]
						END

					SELECT 
						@EntityGroupBook = Book
					FROM
						pcINTEGRATOR_Data..Entity_Book
					WHERE
						InstanceID = @InstanceID AND
						VersionID = @VersionID AND
						EntityID = @EntityGroupID AND
						BookTypeBM & 16 > 0

					SET @Step = 'Update #FiscalPeriod'
						TRUNCATE TABLE #FiscalPeriod
						EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityGroupID, @Book = @EntityGroupBook, @StartFiscalYear = @StartFiscalYear, @EndFiscalYear = @EndFiscalYear,  @FiscalYear = @FiscalYear, @FiscalPeriod13YN = 1, @JobID = @JobID
						IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY [FiscalYear], [FiscalPeriod], [YearMonth]

					SET @Step = 'FiscalYear_Cursor'
						IF CURSOR_STATUS('global','FiscalYear_Cursor') >= -1 DEALLOCATE FiscalYear_Cursor
						DECLARE FiscalYear_Cursor CURSOR FOR
			
							SELECT DISTINCT
								[FiscalYear]
							FROM
								#FiscalPeriod
							ORDER BY
								[FiscalYear]

							OPEN FiscalYear_Cursor
							FETCH NEXT FROM FiscalYear_Cursor INTO @FiscalYear

							WHILE @@FETCH_STATUS = 0
								BEGIN
									IF @DebugBM & 2 > 0 SELECT [@FiscalYear] = @FiscalYear
					
									SET @Step = 'Set Retained earnings from previous year'
										IF @SequenceBM & 4 > 0
											BEGIN
												EXEC [pcINTEGRATOR].[dbo].[spBR_BR05_RE] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @FiscalYear = @FiscalYear, @ConsolidationGroup = @ConsolidationGroup, @JournalTable = @JournalTable, @JobID = @JobID, @Debug = @DebugSub
											END

									SET @Step = 'Update HistRate'
										IF @SequenceBM & 2 > 0 AND @Scenario = 'ACTUAL'
											BEGIN
												EXEC [pcINTEGRATOR].[dbo].[spBR_BR05_Fx_HistRate] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @ConsolidationGroup = @ConsolidationGroup, @FiscalYear = @FiscalYear, @JobID = @JobID, @Debug = @DebugSub	
											END
						
									SET @Step = 'Insert Copy Open'
										IF @SequenceBM & 8 > 0
											BEGIN
												TRUNCATE TABLE #JournalBase
												
												IF @Source_DataClassTypeID = -5
													BEGIN
														EXEC [spBR_BR05_CopyOpen] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @BusinessRuleID=@BusinessRuleID, @Scenario=@Scenario, @JournalTable=@JournalTable, @CallistoDatabase=@CallistoDatabase, @ConsolidationGroup = @ConsolidationGroup, @FiscalYear=@FiscalYear, @Entity_MemberKey=@Entity_MemberKey, @JobID=@JobID, @Debug=@DebugSub
													END
												ELSE
													BEGIN
														EXEC [spBR_BR05_CopyOpen_Financials] 
															@UserID=@UserID, 	
															@InstanceID = @InstanceID,
															@VersionID = @VersionID,
															@FiscalYear = @FiscalYear,
															@BusinessRuleID = @BusinessRuleID,
															@ConsolidationGroup = @ConsolidationGroup,
															@Entity_MemberKey=@Entity_MemberKey,
															@JobID=@JobID,
															@Scenario = @Scenario,
															@Filter = @Filter,
															@Debug = @DebugSub
													END

												IF @DebugBM & 8 > 0 SELECT TempTable = '#JournalBase', * FROM #JournalBase ORDER BY Entity, Book, Account, Segment01, Segment02, Segment03, Segment04, Segment05, InterCompanyEntity, FiscalYear, FiscalPeriod, YearMonth
												IF @DebugBM & 16 > 0 SELECT [Step] = 'After CopyOpen', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
												IF @DebugBM & 32 > 0
													INSERT INTO [pcINTEGRATOR_Log].[dbo].[wrk_Debug_JournalBase]
														([Step],[Counter],[ReferenceNo],[Rule_ConsolidationID],[Rule_FXID],[ConsolidationMethodBM],[InstanceID],[Entity],[Book],[FiscalYear],[FiscalPeriod],[JournalSequence],[JournalNo],[JournalLine],[YearMonth],[TransactionTypeBM],[BalanceYN],[Account],[Segment01],[Segment02],[Segment03],[Segment04],[Segment05],[Segment06],[Segment07],[Segment08],[Segment09],[Segment10],[Segment11],[Segment12],[Segment13],[Segment14],[Segment15],[Segment16],[Segment17],[Segment18],[Segment19],[Segment20],[JournalDate],[TransactionDate],[PostedDate],[Source],[Flow],[ConsolidationGroup],[InterCompanyEntity],[Scenario],[Customer],[Supplier],[Description_Head],[Description_Line],[Currency_Book],[Value_Book],[Currency_Group],[Value_Group],[Currency_Transaction],[Value_Transaction],[SourceModule],[SourceModuleReference],[Inserted])
													SELECT
														[Step]='01 CopyOpen',[Counter],[ReferenceNo],[Rule_ConsolidationID],[Rule_FXID],[ConsolidationMethodBM],[InstanceID],[Entity],[Book],[FiscalYear],[FiscalPeriod],[JournalSequence],[JournalNo],[JournalLine],[YearMonth],[TransactionTypeBM],[BalanceYN],[Account],[Segment01],[Segment02],[Segment03],[Segment04],[Segment05],[Segment06],[Segment07],[Segment08],[Segment09],[Segment10],[Segment11],[Segment12],[Segment13],[Segment14],[Segment15],[Segment16],[Segment17],[Segment18],[Segment19],[Segment20],[JournalDate],[TransactionDate],[PostedDate],[Source],[Flow],[ConsolidationGroup],[InterCompanyEntity],[Scenario],[Customer],[Supplier],[Description_Head],[Description_Line],[Currency_Book],[Value_Book],[Currency_Group],[Value_Group],[Currency_Transaction],[Value_Transaction],[SourceModule],[SourceModuleReference],[Inserted]
													FROM #JournalBase
											END

									SET @Step = 'Set InterCompany Counterpart'
										IF @SequenceBM & 1 > 0 AND @Source_DataClassTypeID <> -5
											BEGIN
												IF @DebugBM & 2 > 0 SELECT [@UserID]=@UserID, [@InstanceID]=@InstanceID, [@VersionID]=@VersionID, [@BusinessRuleID]=@InterCompany_BusinessRuleID, [@JobID]=@JobID
												IF @InterCompany_BusinessRuleID IS NOT NULL
													EXEC [spBR_BR14] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @BusinessRuleID=@InterCompany_BusinessRuleID, @FiscalYear=@FiscalYear, @JournalTable = '#JournalBase', @JobID=@JobID, @Debug=@DebugSub

												IF @DebugBM & 8 > 0 SELECT TempTable='#JournalBase InterCompany', * FROM #JournalBase WHERE InterCompanyEntity <> 'NONE' ORDER BY YearMonth, Account
											END

									SET @Step = 'RULE_Consolidation before Fx'
										IF @SequenceBM & 16 > 0
											BEGIN
												PRINT 'RULE_Consolidation before Fx is not implemented'
											END

									SET @Step = 'RULE_Fx_Cursor'
										IF @SequenceBM & 32 > 0 AND (SELECT COUNT(1) FROM #EntityBook EB WHERE EB.[SelectYN] <> 0) > 0 --EB.[Currency] <> @GroupCurrency AND 
											BEGIN
												IF @DebugBM & 2 > 0 SELECT [Step] = 'FxConversion', [TempTable] = '#EntityBook', * FROM #EntityBook EB WHERE EB.[Currency] <> @GroupCurrency AND EB.[SelectYN] <> 0

												EXEC [spBR_BR05_Fx]
													@UserID=@UserID,
													@InstanceID=@InstanceID,
													@VersionID=@VersionID, 
													@BusinessRuleID = @BusinessRuleID,
													@CallistoDatabase = @CallistoDatabase,
													@GroupCurrency = @GroupCurrency,
													@FiscalYear = @FiscalYear,
													@Scenario = @FxRate_Scenario,
													@ConsolidationGroup = @ConsolidationGroup,
													@Level = @Level,
													@JobID=@JobID,
													@Debug=@DebugSub

												IF @DebugBM & 16 > 0 SELECT [Step] = 'After FX', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
												IF @DebugBM & 32 > 0
													INSERT INTO [pcINTEGRATOR_Log].[dbo].[wrk_Debug_JournalBase]
														([Step],[Counter],[ReferenceNo],[Rule_ConsolidationID],[Rule_FXID],[ConsolidationMethodBM],[InstanceID],[Entity],[Book],[FiscalYear],[FiscalPeriod],[JournalSequence],[JournalNo],[JournalLine],[YearMonth],[TransactionTypeBM],[BalanceYN],[Account],[Segment01],[Segment02],[Segment03],[Segment04],[Segment05],[Segment06],[Segment07],[Segment08],[Segment09],[Segment10],[Segment11],[Segment12],[Segment13],[Segment14],[Segment15],[Segment16],[Segment17],[Segment18],[Segment19],[Segment20],[JournalDate],[TransactionDate],[PostedDate],[Source],[Flow],[ConsolidationGroup],[InterCompanyEntity],[Scenario],[Customer],[Supplier],[Description_Head],[Description_Line],[Currency_Book],[Value_Book],[Currency_Group],[Value_Group],[Currency_Transaction],[Value_Transaction],[SourceModule],[SourceModuleReference],[Inserted])
													SELECT
														[Step]='02 FX',[Counter],[ReferenceNo],[Rule_ConsolidationID],[Rule_FXID],[ConsolidationMethodBM],[InstanceID],[Entity],[Book],[FiscalYear],[FiscalPeriod],[JournalSequence],[JournalNo],[JournalLine],[YearMonth],[TransactionTypeBM],[BalanceYN],[Account],[Segment01],[Segment02],[Segment03],[Segment04],[Segment05],[Segment06],[Segment07],[Segment08],[Segment09],[Segment10],[Segment11],[Segment12],[Segment13],[Segment14],[Segment15],[Segment16],[Segment17],[Segment18],[Segment19],[Segment20],[JournalDate],[TransactionDate],[PostedDate],[Source],[Flow],[ConsolidationGroup],[InterCompanyEntity],[Scenario],[Customer],[Supplier],[Description_Head],[Description_Line],[Currency_Book],[Value_Book],[Currency_Group],[Value_Group],[Currency_Transaction],[Value_Transaction],[SourceModule],[SourceModuleReference],[Inserted]
													FROM #JournalBase
											END

									SET @Step = 'RULE_Consolidation'
										IF @SequenceBM & 64 > 0
											BEGIN
												EXEC[spBR_BR05_Consolidation]
													@UserID = @UserID,
													@InstanceID = @InstanceID,
													@VersionID = @VersionID,
													@BusinessRuleID = @BusinessRuleID,
													@EntityGroupID = @EntityGroupID,
													@JobID = @JobID,
													@Debug = @DebugSub

												IF @DebugBM & 16 > 0 SELECT [Step] = 'After RULE_Consolidation', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
												IF @DebugBM & 32 > 0
													INSERT INTO [pcINTEGRATOR_Log].[dbo].[wrk_Debug_JournalBase]
														([Step],[Counter],[ReferenceNo],[Rule_ConsolidationID],[Rule_FXID],[ConsolidationMethodBM],[InstanceID],[Entity],[Book],[FiscalYear],[FiscalPeriod],[JournalSequence],[JournalNo],[JournalLine],[YearMonth],[TransactionTypeBM],[BalanceYN],[Account],[Segment01],[Segment02],[Segment03],[Segment04],[Segment05],[Segment06],[Segment07],[Segment08],[Segment09],[Segment10],[Segment11],[Segment12],[Segment13],[Segment14],[Segment15],[Segment16],[Segment17],[Segment18],[Segment19],[Segment20],[JournalDate],[TransactionDate],[PostedDate],[Source],[Flow],[ConsolidationGroup],[InterCompanyEntity],[Scenario],[Customer],[Supplier],[Description_Head],[Description_Line],[Currency_Book],[Value_Book],[Currency_Group],[Value_Group],[Currency_Transaction],[Value_Transaction],[SourceModule],[SourceModuleReference],[Inserted])
													SELECT
														[Step]='03 Consolidation',[Counter],[ReferenceNo],[Rule_ConsolidationID],[Rule_FXID],[ConsolidationMethodBM],[InstanceID],[Entity],[Book],[FiscalYear],[FiscalPeriod],[JournalSequence],[JournalNo],[JournalLine],[YearMonth],[TransactionTypeBM],[BalanceYN],[Account],[Segment01],[Segment02],[Segment03],[Segment04],[Segment05],[Segment06],[Segment07],[Segment08],[Segment09],[Segment10],[Segment11],[Segment12],[Segment13],[Segment14],[Segment15],[Segment16],[Segment17],[Segment18],[Segment19],[Segment20],[JournalDate],[TransactionDate],[PostedDate],[Source],[Flow],[ConsolidationGroup],[InterCompanyEntity],[Scenario],[Customer],[Supplier],[Description_Head],[Description_Line],[Currency_Book],[Value_Book],[Currency_Group],[Value_Group],[Currency_Transaction],[Value_Transaction],[SourceModule],[SourceModuleReference],[Inserted]
													FROM #JournalBase
											END

									SET @Step = 'Calculate CYNI'
										EXEC [spBR_BR05_CYNI] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @ConsolidationGroup = @ConsolidationGroup, @JobID = @JobID, @Debug = @DebugSub

									SET @Step = 'Update [JournalLine] & [Description_Line]'
										IF @SequenceBM & 128 > 0
											BEGIN
												UPDATE JB
												SET
													[JournalLine] = ISNULL(JB.[JournalLine], sub.[JournalLine]),
													[Description_Line] = 'Ref: ' + CONVERT(nvarchar(15), JB.[ReferenceNo]) + ', ' + ISNULL([Description_Line], '')
												FROM
													#JournalBase JB 
													LEFT JOIN
														(
														SELECT
															[Counter],
															[JournalLine] = ROW_NUMBER() OVER(PARTITION BY JB.[Entity], JB.[Book], JB.[FiscalYear], JB.[FiscalPeriod], JB.[JournalSequence], JB.[JournalNo] ORDER BY JB.[Counter])
														FROM
															#JournalBase JB
														WHERE
															JB.[JournalLine] IS NULL
														) sub ON sub.[Counter] = JB.[Counter]
											END

									SET @Step = 'Delete old rows from Journal'
										IF @SequenceBM & 128 > 0
											BEGIN
												SET @SQLStatement = '
													DELETE J
													FROM
															' + @JournalTable + ' J
															INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = J.[FiscalYear] AND FP.[FiscalPeriod] = J.[FiscalPeriod] AND FP.[YearMonth] = J.[YearMonth]
															INNER JOIN #EntityBook EB ON EB.[MemberKey] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[SelectYN] <> 0
													WHERE
														J.[TransactionTypeBM] & 40 > 0 AND
														J.[ConsolidationGroup] = ''' + @ConsolidationGroup + ''' AND
														J.[Scenario] = ''' + @Scenario + ''''

												IF @DebugBM & 2 > 0 PRINT @SQLStatement
												EXEC (@SQLStatement)

												SET @Deleted = @Deleted + @@ROWCOUNT
												IF @DebugBM & 16 > 0 SELECT [Step] = 'After delete rows from Journal', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
												IF @DebugBM & 32 > 0
													INSERT INTO [pcINTEGRATOR_Log].[dbo].[wrk_Debug_JournalBase]
														([Step],[Counter],[ReferenceNo],[Rule_ConsolidationID],[Rule_FXID],[ConsolidationMethodBM],[InstanceID],[Entity],[Book],[FiscalYear],[FiscalPeriod],[JournalSequence],[JournalNo],[JournalLine],[YearMonth],[TransactionTypeBM],[BalanceYN],[Account],[Segment01],[Segment02],[Segment03],[Segment04],[Segment05],[Segment06],[Segment07],[Segment08],[Segment09],[Segment10],[Segment11],[Segment12],[Segment13],[Segment14],[Segment15],[Segment16],[Segment17],[Segment18],[Segment19],[Segment20],[JournalDate],[TransactionDate],[PostedDate],[Source],[Flow],[ConsolidationGroup],[InterCompanyEntity],[Scenario],[Customer],[Supplier],[Description_Head],[Description_Line],[Currency_Book],[Value_Book],[Currency_Group],[Value_Group],[Currency_Transaction],[Value_Transaction],[SourceModule],[SourceModuleReference],[Inserted])
													SELECT
														[Step]='04 Before fill Journal',[Counter],[ReferenceNo],[Rule_ConsolidationID],[Rule_FXID],[ConsolidationMethodBM],[InstanceID],[Entity],[Book],[FiscalYear],[FiscalPeriod],[JournalSequence],[JournalNo],[JournalLine],[YearMonth],[TransactionTypeBM],[BalanceYN],[Account],[Segment01],[Segment02],[Segment03],[Segment04],[Segment05],[Segment06],[Segment07],[Segment08],[Segment09],[Segment10],[Segment11],[Segment12],[Segment13],[Segment14],[Segment15],[Segment16],[Segment17],[Segment18],[Segment19],[Segment20],[JournalDate],[TransactionDate],[PostedDate],[Source],[Flow],[ConsolidationGroup],[InterCompanyEntity],[Scenario],[Customer],[Supplier],[Description_Head],[Description_Line],[Currency_Book],[Value_Book],[Currency_Group],[Value_Group],[Currency_Transaction],[Value_Transaction],[SourceModule],[SourceModuleReference],[Inserted]
													FROM #JournalBase
											END

									SET @Step = 'Fill Journal table'
										IF @SequenceBM & 128 > 0
											BEGIN
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
														[Customer],
														[Supplier],
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
														[SourceModuleReference],
														[Inserted],
														[InsertedBy]
														)'

												SET @SQLStatement = @SQLStatement + '
													SELECT
														[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ',
														[InstanceID],
														[Entity],
														[Book],
														[FiscalYear],
														[FiscalPeriod],
														[JournalSequence],
														[JournalNo],
														[JournalLine],
														[YearMonth],
														[TransactionTypeBM] = ISNULL(JB.[TransactionTypeBM], 8),
														[BalanceYN] = ISNULL(JB.[BalanceYN], 0),
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
														[JournalDate] = ISNULL(JB.[JournalDate], CONVERT(date, DATEADD(d, -1, DATEADD(m, 1, LEFT(JB.[YearMonth], 4) + ''-'' + RIGHT(JB.[YearMonth], 2) + ''-01'')))),
														[TransactionDate] = ISNULL(JB.[TransactionDate], CONVERT(date, DATEADD(d, -1, DATEADD(m, 1, LEFT(JB.[YearMonth], 4) + ''-'' + RIGHT(JB.[YearMonth], 2) + ''-01'')))),
														[PostedDate] = ISNULL(JB.[PostedDate], GetDate()),
														[PostedStatus] = 1,
														[PostedBy] = ''' + @UserName + ''',
														[Source] = ISNULL(JB.[Source], ''CONS''),
														[Flow],
														[ConsolidationGroup],
														[InterCompanyEntity],
														[Scenario],
														[Customer],
														[Supplier],
														[Description_Head] = ISNULL(JB.[Description_Head], ''ConsolidationRule''),
														[Description_Line] = ISNULL(JB.[Description_Line], ''ConsolidationRule''),
														[Currency_Book],
														[ValueDebit_Book] = CASE WHEN [Value_Book] > 0 THEN [Value_Book] ELSE 0 END,
														[ValueCredit_Book] = CASE WHEN [Value_Book] < 0 THEN [Value_Book] * -1 ELSE 0 END,
														[Currency_Group],
														[ValueDebit_Group] = CASE WHEN [Value_Group] > 0 THEN [Value_Group] ELSE 0 END,
														[ValueCredit_Group] = CASE WHEN [Value_Group] < 0 THEN [Value_Group] * -1 ELSE 0 END,
														[Currency_Transaction],
														[ValueDebit_Transaction] = CASE WHEN [Value_Transaction] > 0 THEN [Value_Transaction] ELSE 0 END,
														[ValueCredit_Transaction] = CASE WHEN [Value_Transaction] < 0 THEN [Value_Transaction] * -1 ELSE 0 END,
														[SourceModule] = ISNULL(JB.[SourceModule], ''''),
														[SourceModuleReference] = ISNULL(JB.[SourceModuleReference], ''''),
														[Inserted] = GetDate(),
														[InsertedBy] = suser_name()
													FROM
														#JournalBase JB'

												IF @DebugBM & 2 > 0 PRINT @SQLStatement
												EXEC (@SQLStatement)

												SET @Inserted = @Inserted + @@ROWCOUNT

									SET @Step = 'Convert TransactionTypeBM = 32 to 8'
												--Convert TransactionTypeBM = 32 to 8
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
														[Customer],
														[Supplier],
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
														[SourceModuleReference],
														[Inserted],
														[InsertedBy]
														)'

												SET @SQLStatement = @SQLStatement + '
													SELECT
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
														[TransactionTypeBM] = 8,
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
														[PostedStatus] = 1,
														[PostedBy],
														[Source],
														[Flow],
														[ConsolidationGroup],
														[InterCompanyEntity],
														[Scenario],
														[Customer],
														[Supplier],
														[Description_Head],
														[Description_Line],
														[Currency_Book],
														[ValueDebit_Book] = CASE WHEN [Value_Book] > 0 THEN [Value_Book] ELSE 0 END,
														[ValueCredit_Book] = CASE WHEN [Value_Book] < 0 THEN -1 * [Value_Book] ELSE 0 END,
														[Currency_Group],
														[ValueDebit_Group] = CASE WHEN [Value_Group] > 0 THEN [Value_Group] ELSE 0 END,
														[ValueCredit_Group] = CASE WHEN [Value_Group] < 0 THEN -1 * [Value_Group] ELSE 0 END,
														[Currency_Transaction],
														[ValueDebit_Transaction] = CASE WHEN [Value_Transaction] > 0 THEN [Value_Transaction] ELSE 0 END,
														[ValueCredit_Transaction] = CASE WHEN [Value_Transaction] < 0 THEN -1 * [Value_Transaction] ELSE 0 END,
														[SourceModule] = [SourceModule],
														[SourceModuleReference] = [SourceModuleReference],
														[Inserted] = GetDate(),
														[InsertedBy] = suser_name()
													FROM
														('

												SET @SQLStatement = @SQLStatement + '
														SELECT
															[JobID] = MAX(J.[JobID]),
															[InstanceID] = MAX(J.[InstanceID]),
															[Entity],
															[Book],
															[FiscalYear] = MAX(J.[FiscalYear]),
															[FiscalPeriod] = FP.[FiscalPeriod],
															[JournalSequence],
															[JournalNo] = MAX([JournalNo]),
															[JournalLine] = MAX([JournalLine]),
															[YearMonth] = MAX(FP.[YearMonth]),
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
															[JournalDate] = MAX(J.[JournalDate]),
															[TransactionDate] = MAX(J.[TransactionDate]),
															[PostedDate] = MAX(J.[PostedDate]),
															[PostedBy] = MAX([PostedBy]),
															[Source],
															[Flow],
															[ConsolidationGroup] = MAX(J.[ConsolidationGroup]),
															[InterCompanyEntity],
															[Scenario],
															[Customer] = ISNULL([Customer], ''''),
															[Supplier],
															[Description_Head] = MAX(J.[Description_Head]),
															[Description_Line] = MAX(J.[Description_Line]),
															[Currency_Book] = ISNULL([Currency_Book], ''''),
															[Value_Book] = SUM(CASE WHEN J.[BalanceYN] = 0 OR FP.FiscalPeriod > 12 THEN CASE WHEN J.[FiscalPeriod] = FP.[FiscalPeriod] THEN [ValueDebit_Book] - [ValueCredit_Book] ELSE 0 END ELSE CASE WHEN J.[FiscalPeriod] <= FP.[FiscalPeriod] THEN [ValueDebit_Book] - [ValueCredit_Book] ELSE 0 END END),
															[Currency_Group],
															[Value_Group] = SUM(CASE WHEN J.[BalanceYN] = 0 OR FP.FiscalPeriod > 12 THEN CASE WHEN J.[FiscalPeriod] = FP.[FiscalPeriod] THEN [ValueDebit_Group] - [ValueCredit_Group] ELSE 0 END ELSE CASE WHEN J.[FiscalPeriod] <= FP.[FiscalPeriod] THEN [ValueDebit_Group] - [ValueCredit_Group] ELSE 0 END END),
															[Currency_Transaction] = ISNULL([Currency_Transaction], ''''),
															[Value_Transaction] = SUM(CASE WHEN J.[BalanceYN] = 0 OR FP.FiscalPeriod > 12 THEN CASE WHEN J.[FiscalPeriod] = FP.[FiscalPeriod] THEN [ValueDebit_Transaction] - [ValueCredit_Transaction] ELSE 0 END ELSE CASE WHEN J.[FiscalPeriod] <= FP.[FiscalPeriod] THEN [ValueDebit_Transaction] - [ValueCredit_Transaction] ELSE 0 END END),
															[SourceModule] = J.[SourceModule],
															[SourceModuleReference] = J.[SourceModuleReference]
														FROM
															' + @JournalTable + ' J
															INNER JOIN #FiscalPeriod FP ON FP.[FiscalYear] = J.[FiscalYear] AND FP.[FiscalPeriod] >= J.[FiscalPeriod]'

												SET @SQLStatement = @SQLStatement + '
														WHERE
															J.[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ' AND
															J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
															J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
															J.[ConsolidationGroup] = ''' + @ConsolidationGroup + ''' AND
															J.[TransactionTypeBM] & 32 > 0 AND
															J.[Scenario] = ''' + @Scenario + '''
														GROUP BY
															[Entity],
															[Book],
															FP.[FiscalPeriod],
															[JournalSequence],
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
															[Source],
															[Flow],
															[InterCompanyEntity],
															[Scenario],
															ISNULL([Customer], ''''),
															[Supplier],
															ISNULL([Currency_Book], ''''),
															[Currency_Group],
															ISNULL([Currency_Transaction], ''''),
															J.[SourceModule],
															J.[SourceModuleReference]
														) sub
													WHERE
														sub.[Value_Book] + sub.[Value_Group] + sub.[Value_Transaction] <> 0'

												IF @DebugBM & 16 > 0 
													BEGIN
														SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod
														IF LEN(@SQLStatement) > 4000 
															BEGIN
																PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; Convert 32 to 8.'
																EXEC [dbo].[spSet_wrk_Debug]
																	@UserID = @UserID,
																	@InstanceID = @InstanceID,
																	@VersionID = @VersionID,
																	@DatabaseName = @DatabaseName,
																	@CalledProcedureName = @ProcedureName,
																	@Comment = 'Convert 32 to 8', 
																	@SQLStatement = @SQLStatement,
																	@JobID = @JobID
															END
														ELSE
															PRINT @SQLStatement
													END
												EXEC (@SQLStatement)

												SET @Inserted = @Inserted + @@ROWCOUNT	

				--/*	Temporary removed 2021-12-22 by JaWo						
												--Carry forward opening balances
												EXEC [spBR_BR05_OBAdj]
													@UserID = @UserID,
													@InstanceID = @InstanceID,
													@VersionID = @VersionID,
													@FiscalYear = @FiscalYear,
													@ConsolidationGroup = @ConsolidationGroup,
													@GroupCurrency = @GroupCurrency,
													@Scenario = @Scenario,
													@JournalTable = @JournalTable,
													@JobID = @JobID,
													@Debug = @DebugSub
				--*/
												IF @DebugBM & 16 > 0 SELECT [Step] = 'After Insert rows into Journal', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
											END
				--Temporary plug 2022-01-11 by JaWo
											--EXEC pcETL_E2IP..spBRO5_Plug @JobID = @JobID, @InstanceID = @InstanceID
				--End of temporary plug 2022-01-11 by JaWo

									SET @Step = 'Fill FACT_Financials'
										IF @SequenceBM & 384 = 384
											BEGIN
												EXEC [spIU_Dim_BusinessProcess_Callisto] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID=@JobID

												EXEC [spIU_DC_Financials_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBM=0, @ConsolidationGroupYN=1, @ConsolidationStep=1, @FieldTypeBM=1, @FiscalYear=@FiscalYear, @ConsolidationGroup=@ConsolidationGroup, @Entity=@Entity_MemberKey, @Scenario = @Scenario, @JobID=@JobID

												EXEC [spIU_DC_Financials_Callisto] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBM=0, @ConsolidationGroupYN=1, @ConsolidationStep=2, @FieldTypeBM=4, @FiscalYear=@FiscalYear, @ConsolidationGroup=@ConsolidationGroup, @Entity=@Entity_MemberKey, @Scenario = @Scenario, @JobID=@JobID

												IF @DebugBM & 16 > 0 SELECT [Step] = 'After Insert rows into FACT_Financials', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
											END

									FETCH NEXT FROM FiscalYear_Cursor INTO @FiscalYear
								END

						CLOSE FiscalYear_Cursor
						DEALLOCATE FiscalYear_Cursor
							
					FETCH NEXT FROM ConsolidationGroup_Cursor INTO @EntityGroupID, @ConsolidationGroup, @GroupCurrency
				END

		CLOSE ConsolidationGroup_Cursor
		DEALLOCATE ConsolidationGroup_Cursor

	SET @Step = 'Refresh Fact table'
		IF @SequenceBM & 384 = 384
			BEGIN
				EXEC [spRun_Job_Callisto_Generic] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @StepName = 'Refresh', @ModelName = 'Financials', @AsynchronousYN = 1, @JobID=@JobID
			
				IF @DebugBM & 16 > 0 SELECT [Step] = 'After Refresh FACT_Financials', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #FilterTable
		DROP TABLE #FiscalPeriod
		DROP TABLE #JournalBase

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

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
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
