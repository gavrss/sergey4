SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Entity_Enterprise]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	--SP-specific parameters
	@SourceTypeID INT = NULL,
	@ModelingStatusID INT = -40,
	@ModelingComment NVARCHAR(100) = 'Copied from Callisto',

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000812,
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
EXEC [spSetup_Entity_Enterprise] @UserID=-10, @InstanceID=568, @VersionID=1077, @SourceTypeID = 12, @DebugBM=3

EXEC [spSetup_Entity_Enterprise] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceInstanceID int = -10,
	@SourceVersionID int = -10,
	@SQLStatement nvarchar(max),	
	@ApplicationID int,
	@ApplicationName nvarchar(100),
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@EntityGroupID int,
	@SourceDatabase nvarchar(100),
	@LinkedServer nvarchar(100),
	@SourceID_Financials int,
	@SourceID_FxRate int,
	@Owner nvarchar(3),

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2175'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup Entity from Enterprise',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2175' SET @Description = 'Procedure created.'

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
			@ApplicationID = [ApplicationID],
			@ApplicationName = [ApplicationName],
			@ETLDatabase = [ETLDatabase],
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		SELECT
			@SourceID_Financials = MAX(CASE WHEN M.[BaseModelID] = -7 THEN S.[SourceID] ELSE 0 END),
			@SourceID_FxRate = MAX(CASE WHEN M.[BaseModelID] = -3 THEN S.[SourceID] ELSE 0 END),
			--@SourceDatabase = MAX(CASE WHEN M.[BaseModelID] = -7 THEN S.[SourceDatabase] ELSE '' END)
			@SourceDatabase = MAX(CASE WHEN M.[BaseModelID] = -7 THEN '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']' ELSE '' END)
		FROM
			[Source] S
			INNER JOIN [Model] M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = @VersionID AND M.[ModelID] = S.[ModelID] AND M.[BaseModelID] IN (-3, -7)
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SourceTypeID] = @SourceTypeID

		IF CHARINDEX('.', @SourceDatabase) <> 0
			SET @LinkedServer = REPLACE(REPLACE(LEFT(@SourceDatabase, CHARINDEX('.', @SourceDatabase) - 1), '[', ''), ']', '')

		SET @Owner = CASE WHEN @SourceTypeID = 11 THEN 'erp' ELSE 'dbo' END

		IF @DebugBM & 2 > 0
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@SourceTypeID] = @SourceTypeID,
				[@ModelingStatusID] = @ModelingStatusID,
				[@ModelingComment] = @ModelingComment,
				[@JobID] = @JobID,
				[@JobLogID] = @JobLogID,
				[@SourceID_Financials] = @SourceID_Financials,
				[@SourceID_FxRate] = @SourceID_FxRate,
				[@SourceDatabase] = @SourceDatabase,
				[@LinkedServer] = @LinkedServer,
				[@Owner] = @Owner

	SET @Step = 'Create and fill temp table #Company'
		CREATE TABLE #Company
			(
			[Company] nvarchar(8) COLLATE DATABASE_DEFAULT,
			[Name] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

		SET @SQLStatement = '
			INSERT INTO #Company
				(
				[Company],
				[Name]
				)
			SELECT
				[Company] = smc.[company_id],
				[Name] = MAX(smc.[company_name])
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[smcomp] smc
			GROUP BY
				smc.[company_id]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		IF @LinkedServer IS NOT NULL EXEC [spGet_Connection] @LinkedServer = @LinkedServer
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Company', * FROM #Company

	SET @Step = 'Update Entity'
		--UPDATE E
		--SET
		SELECT
			[SourceID] = @SourceID_Financials
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN #Company C ON C.[Company] = E.[MemberKey]
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			(E.[SourceID] <> @SourceID_Financials OR E.[SourceID] IS NULL)

		--SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Fill Entity'
		--INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity]
		--	(
		--	[InstanceID],
		--	[VersionID],
		--	[SourceID],
		--	[MemberKey],
		--	[EntityName],
		--	[EntityTypeID]
		--	)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[SourceID] = @SourceID_Financials,
			[MemberKey] = C.[Company],
			[EntityName] = C.[Name],
			[EntityTypeID] = -1
		FROM
			[#Company] C
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data]..[Entity] DE WHERE DE.InstanceID = @InstanceID AND DE.VersionID = @VersionID AND DE.MemberKey = C.[Company])
		ORDER BY
			C.[Company]

		--SET @Inserted = @Inserted + @@ROWCOUNT
		--IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity', * FROM [pcINTEGRATOR_Data].[dbo].[Entity] WHERE InstanceID = @InstanceID AND VersionID = @VersionID
/*
	SET @Step = 'Create and fill temp table #GLBook'
		CREATE TABLE #GLBook
			(
			[Company] nvarchar(8) COLLATE DATABASE_DEFAULT,
			[BookID] nvarchar(12) COLLATE DATABASE_DEFAULT,
			[MainBook] bit,
			[COACode] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[CurrencyCode] nvarchar(4) COLLATE DATABASE_DEFAULT
			)

		SET @SQLStatement = '
			INSERT INTO #GLBook
				(
				[Company],
				[BookID],
				[MainBook],
				[COACode],
				[CurrencyCode]
				)
			SELECT
				[Company] = GLB.[Company],
				[BookID] = GLB.[BookID],
				[MainBook] = GLB.[MainBook],
				[COACode] = GLB.[COACode],
				[CurrencyCode] = GLB.[CurrencyCode]
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Create and fill temp table #BalanceType'
		CREATE TABLE #BalanceType
			(
			[Company] nvarchar(8) COLLATE DATABASE_DEFAULT,
			[BookID] nvarchar(12) COLLATE DATABASE_DEFAULT,
			[BalanceType] nvarchar(1) COLLATE DATABASE_DEFAULT
			)

		SET @SQLStatement = '
			INSERT INTO #BalanceType
				(
				[Company],
				[BookID],
				[BalanceType]
				)
			SELECT DISTINCT
				[Company] = GLPB.[Company],
				[BookID] = GLPB.[BookID],
				[BalanceType] = GLPB.[BalanceType]
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[GLPeriodBal] GLPB
			WHERE
				[BalanceType] = ''D'''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Update Entity_Book'
		UPDATE EB
		SET
			[Book] = GLB.[BookID],
			--[Currency] = UPPER(SUBSTRING(GLB.[CurrencyCode], 1, 3)),
			[BookTypeBM] = 1 + CASE WHEN GLB.[MainBook] <> 0 THEN 2 ELSE 0 END,
			[COA] =  ISNULL(EB.COA, GLB.COACode),
			[BalanceType] = COALESCE(EB.[BalanceType], BT.[BalanceType], 'B')
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity_Book] EB
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.EntityID = EB.EntityID
			INNER JOIN [#GLBook] GLB ON GLB.Company = E.MemberKey AND GLB.BookID = EB.Book
			LEFT JOIN [#BalanceType] BT ON BT.[Company] = E.[MemberKey] AND BT.[BookID] = GLB.[BookID]
		WHERE
			EB.[InstanceID] = @InstanceID AND
			EB.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Fill Entity_Book'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity_Book]
			(
			[InstanceID],
			[VersionID],
			[EntityID],
			[Book],
			[Currency],
			[BookTypeBM],
			[COA],
			[BalanceType],
			[SelectYN]
			)
		SELECT
			[InstanceID] = E.[InstanceID],
			[VersionID] = E.[VersionID],
			[EntityID] = E.[EntityID],
			[Book] = GLB.[BookID],
			[Currency] = UPPER(SUBSTRING(GLB.[CurrencyCode], 1, 3)),
			[BookTypeBM] = 1 + CASE WHEN GLB.[MainBook] <> 0 THEN 2 ELSE 0 END,
			[COA] = GLB.COACode,
			[BalanceType] = ISNULL(BT.[BalanceType], 'B'),
			[SelectYN] = GLB.[MainBook]
		FROM
			pcINTEGRATOR_Data..[Entity] E
			INNER JOIN [#GLBook] GLB ON GLB.Company = E.MemberKey
			LEFT JOIN [#BalanceType] BT ON BT.[Company] = E.[MemberKey] AND BT.[BookID] = GLB.[BookID]
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			E.[SourceID] = @SourceID_Financials AND
			NOT EXISTS (SELECT 1 FROM [Entity_Book] EB WHERE EB.InstanceID = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.EntityID = E.EntityID AND EB.Book = GLB.[BookID])

		SET @Inserted = @Inserted + @@ROWCOUNT
		IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity_Book', EB.* FROM [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB WHERE EB.InstanceID = @InstanceID AND EB.VersionID = @VersionID
*/
	SET @Step = 'Drop temp tables'	
		DROP TABLE #Company
		--DROP TABLE #GLBook
		--DROP TABLE #BalanceType

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
