SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR05_CopyOpen_Financials_E2IP]
	@UserID int = NULL, -- -10, --temporary hardcoded
	@InstanceID int = NULL, -- 527, --temporary hardcoded
	@VersionID int = NULL, -- 1055, --temporary hardcoded

	--SP-specific parameters
	@BusinessRuleID int = NULL,
	@EntityGroupID int = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',
	@JournalTable nvarchar(100) = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@ConsolidationGroup nvarchar(50) = NULL, --Mandatory if @EntityGroupID is not set
	@FiscalYear int = NULL, --Mandatory if not called
	@Entity_MemberKey nvarchar(50) = NULL, --Optional filter mainly for debugging purposes

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000843,
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
EXEC [spBR_BR05_CopyOpen_Financials_E2IP] 
	@UserID=-10, 	
	@InstanceID = 527,
	@VersionID = 1055,
	@FiscalYear = 2021,
	@ConsolidationGroup = 'Group',
	@Debug = 1

EXEC [spBR_BR05_CopyOpen_Financials_E2IP] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
--	@Entity VARCHAR(30)='1004', -- source
--	@Time VARCHAR(30)='202103', -- source for selected conso year
	@Account VARCHAR(30)='CYNI_B_REVAL', -- Configurable as filter?
--	@Currency VARCHAR(30)='CAD', -- Selectable - Either Group Currency or BusinessRule='NONE'
	@Currency_Group nchar(3) = 'CAD',
--	@FiscalYear int = 2021,

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
	@Version nvarchar(50) = '2.1.1.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Sub routine for [spBR_BR05_CopyOpen]. Insert rows from FACT_Financials.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2179' SET @Description = 'Procedure created.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@EntityGroupID = ISNULL(@EntityGroupID, EntityID),
			@ConsolidationGroup = ISNULL(@ConsolidationGroup, MemberKey)
		FROM
			pcINTEGRATOR_Data..Entity
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			(MemberKey = @ConsolidationGroup OR EntityID = @EntityGroupID) AND
			EntityTypeID = 0

	SET @Step = 'CREATE TABLE #EntityBook'
		IF OBJECT_ID(N'TempDB.dbo.#EntityBook', N'U') IS NULL
			BEGIN
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
					[SelectYN] bit
					)
			
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
					E.[EntityID],
					E.[MemberKey],
					EB.[Book],
					EB.[BookTypeBM],
					EB.[Currency],
					EH.[OwnershipConsolidation],
					EH.[ConsolidationMethodBM],
					[SelectYN] = CASE WHEN E.[MemberKey] = @Entity_MemberKey OR @Entity_MemberKey IS NULL THEN 1 ELSE 0 END
				FROM 
					Entity E
					INNER JOIN Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 18 > 0 AND EB.SelectYN <> 0
					INNER JOIN EntityHierarchy EH ON EH.InstanceID = E.InstanceID AND EH.VersionID = E.VersionID AND EH.EntityGroupID = @EntityGroupID AND EH.EntityID = E.EntityID
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					E.SelectYN <> 0 AND
					E.DeletedID IS NULL
				ORDER BY
					E.MemberKey,
					EB.Book

				UPDATE EB
				SET
					[Account_RE] = EPV.[EntityPropertyValue]
				FROM
					#EntityBook EB
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV ON EPV.[InstanceID] = @InstanceID AND EPV.[VersionID] = @VersionID AND EPV.[EntityID] = EB.[EntityID] AND EPV.[EntityPropertyTypeID] = -10 AND EPV.[SelectYN] <> 0			
			END

		IF @DebugBM & 2 > 0
			SELECT * FROM #EntityBook

	SET @Step = 'CREATE TABLE #JournalBase'
		IF OBJECT_ID(N'TempDB.dbo.#JournalBase', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0
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
			END

	SET @Step = 'Import data into #JournalBase'
		INSERT INTO #JournalBase
			(
			[ReferenceNo],
			[ConsolidationMethodBM],
			[InstanceID],
			[Entity], 
			[Book],
			[FiscalYear],
			[FiscalPeriod],
			[JournalSequence],
			[JournalNo],
			[YearMonth],
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
			[TransactionDate],
			[PostedDate],
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
			[Value_Book],
			[Currency_Group],
			[Value_Group],
			[SourceModule],
			[SourceModuleReference]
			)
		SELECT
			[ReferenceNo] = 13000000 + ROW_NUMBER() OVER(ORDER BY V.[Entity], EB.[Book], V.[Time] / 100, V.[Time] % 100, V.[Account]),
			[ConsolidationMethodBM] = MAX(EB.[ConsolidationMethodBM]),
			[InstanceID] = @InstanceID,
			[Entity] = V.[Entity], 
			[Book] = EB.Book,
			[FiscalYear] = V.[Time] / 100,
			[FiscalPeriod] = V.[Time] % 100,
			[JournalSequence] = 'FACT_Financials',
			[JournalNo] = 23000000 + ROW_NUMBER() OVER(PARTITION BY V.[Entity], EB.[Book], V.[Time] / 100 ORDER BY V.[Time] % 100),
			[YearMonth] = V.[Time],
			[BalanceYN] = 1,
			[Account] = V.[Account],
			[Segment01] = V.[GL_Department],
			[Segment02] = V.[GL_Division],
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
			[TransactionDate] = CONVERT(date, DATEADD(DAY, -1, DATEADD(MONTH, 1, CONVERT(NVARCHAR(15), V.[Time] / 100) + '-' + CONVERT(NVARCHAR(15), V.[Time] % 100) + '-1'))),
			[PostedDate] = CONVERT(date, GetDate()),
			[Source] = 'FACT',
			[Flow] = V.[Flow],
			[ConsolidationGroup] = V.[Group],
			[InterCompanyEntity] = V.[InterCompany],
			[Scenario] = V.[Scenario],
			[Customer] = V.[Customer],
			[Supplier] = V.[Supplier],
			[Description_Head] = 'Loaded from FACT_Financials',
			[Description_Line] = '',
			[Currency_Book] = EB.[Currency],
			[Value_Book] = ROUND(SUM(CASE WHEN V.[Currency] = EB.[Currency] AND V.[Group] = 'NONE' THEN V.[Financials_Value] ELSE 0 END), 4),
			[Currency_Group] = @Currency_Group,
			[Value_Group] = ROUND(SUM(CASE WHEN V.[Currency] = @Currency_Group AND V.[Group] = @ConsolidationGroup THEN V.[Financials_Value] ELSE 0 END), 4),
			[SourceModule] = 'FACT',
			[SourceModuleReference] = NULL
		FROM
			[pcDATA_E2IP].[dbo].[FACT_Financials_View] V
			INNER JOIN #EntityBook EB ON EB.MemberKey = V.[Entity] AND EB.[BookTypeBM] & 3 = 3 AND EB.[SelectYN] <> 0
		WHERE
			V.[Time] BETWEEN CONVERT(nvarchar(15), @FiscalYear * 100) AND CONVERT(nvarchar(15), @FiscalYear * 100 + 99) AND
			V.[Account] = @Account AND
			V.[Scenario] = @Scenario AND
			V.[BusinessProcess] = 'CYNI_B_REV_SP'
			-- AND V.[BusinessProcess] <> 'ELIM_POST' ' Jan M
		GROUP BY
			EB.Book,
			V.[Account],
			V.[GL_Department],
			V.[GL_Division],
			EB.[Currency],
			V.[Entity],
			V.[Flow],
			V.[Group],
			V.InterCompany,
			V.Scenario,
			V.[Customer],
			V.[Supplier],
			V.[Time]
		HAVING
			ROUND(SUM(CASE WHEN V.[Currency] = EB.[Currency] AND V.[Group] = 'NONE' THEN V.[Financials_Value] ELSE 0 END), 4) <> 0 OR
			ROUND(SUM(CASE WHEN V.[Currency] = @Currency_Group AND V.[Group] = @ConsolidationGroup THEN V.[Financials_Value] ELSE 0 END), 4) <> 0
	
		IF @DebugBM & 2 > 0 
			BEGIN	
				SELECT TempTable = '#JournalBase', * FROM #JournalBase ORDER BY YearMonth

				SELECT
					Entity,
					YearMonth,
					[Currency_Book],
					[Value_Book] = ROUND(SUM(Value_Book), 2),
					[Value_Group] = ROUND(SUM(Value_Group), 2)
				FROM
					#JournalBase
				GROUP BY
					Entity,
					YearMonth,
					[Currency_Book]
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
