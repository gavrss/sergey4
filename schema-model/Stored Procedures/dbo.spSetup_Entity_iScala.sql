SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Entity_iScala]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,
	@ModelingStatusID int = -40,
	@ModelingComment NVARCHAR(100) = 'Copied from Callisto',

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000741,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC spSetup_Entity_iScala @UserID=-10, @InstanceID=621, @VersionID=1105, @SourceTypeID=3, @DebugBM=3

EXEC [spSetup_Entity_iScala] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceInstanceID INT = -10,
	@SourceVersionID INT = -10,
	@SQLStatement NVARCHAR(MAX),	
	@ApplicationID INT,
	@ApplicationName NVARCHAR(100),
	@ETLDatabase NVARCHAR(100),
	@CallistoDatabase NVARCHAR(100),
	@EntityGroupID INT,
	@SourceDatabase NVARCHAR(100),
	@SourceID_Financials INT,
	@SourceID_FxRate INT,
	@Owner NVARCHAR(3),
	@ExistsYN BIT,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
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
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup Entity from iScala',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2165' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2199' SET @Description = 'Added an update to [Entity].[EntityName].'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
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
			@SourceDatabase = MAX(CASE WHEN M.[BaseModelID] = -7 THEN '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']' ELSE '' END)
		FROM
			[Source] S
			INNER JOIN [Model] M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = @VersionID AND M.[ModelID] = S.[ModelID] AND M.[BaseModelID] IN (-3, -7)
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SourceTypeID] = @SourceTypeID

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
				[@Owner] = @Owner

	SET @Step = 'Create and fill temp table #Company'
		CREATE TABLE #Company
			(
			[Company] nvarchar(8) COLLATE DATABASE_DEFAULT,
			[Name] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SourceServer] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SourceDatabase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			)

		--TODO: temp, to be deleted
		SET @SQLStatement = '
			INSERT INTO #Company
				(
				[Company],
				[Name],
				[SourceServer],
				[SourceDatabase]
				)
			SELECT
				[Company] = C.[CompanyCode],
				[Name] = MAX(C.[CompanyName]),
				[SourceServer] = ''ABSH_ScalaDB'',
				[SourceDatabase] = ''ABSH_ScalaDB.ABSH_ScalaDB''
				--[SourceDatabase] = MAX(C.[ServerName]) + ''.'' + MAX(C.[DBName])
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[ScaCompanies] C
			GROUP BY
				C.[CompanyCode]'
/*
		SET @SQLStatement = '
			INSERT INTO #Company
				(
				[Company],
				[Name],
				[SourceServer],
				[SourceDatabase]
				)
			SELECT
				[Company] = C.[CompanyCode],
				[Name] = MAX(C.[CompanyName]),
				[SourceServer] = MAX(C.[ServerName]),
				[SourceDatabase] = MAX(C.[DBName])
				--[SourceDatabase] = MAX(C.[ServerName]) + ''.'' + MAX(C.[DBName])
			FROM
				' + @SourceDatabase + '.[' + @Owner + '].[ScaCompanies] C
			GROUP BY
				C.[CompanyCode]'
*/
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT TempTable = '#Company', * FROM #Company ORDER BY [Company]

	SET @Step = 'Update Entity'
		UPDATE E
		SET
			[EntityName] = C.[Name],
			[SourceID] = @SourceID_Financials
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN #Company C ON C.[Company] = E.[MemberKey]
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			(E.[SourceID] <> @SourceID_Financials OR E.[SourceID] IS NULL)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Fill Entity'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity]
			(
			[InstanceID],
			[VersionID],
			[SourceID],
			[MemberKey],
			[EntityName],
			[EntityTypeID],
			[SelectYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[SourceID] = @SourceID_Financials,
			[MemberKey] = C.[Company],
			[EntityName] = C.[Name],
			[EntityTypeID] = -1,
			[SelectYN] = CASE WHEN C.[Name] LIKE '%Test%' THEN 0 ELSE CASE WHEN d.[name] IS NULL THEN 0 ELSE 1 END END
		FROM
			[#Company] C
			LEFT JOIN sys.databases d ON d.[name] = c.[SourceDatabase]
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data]..[Entity] DE WHERE DE.InstanceID = @InstanceID AND DE.VersionID = @VersionID AND DE.MemberKey = C.[Company])
		ORDER BY
			C.[Company]

		SET @Inserted = @Inserted + @@ROWCOUNT
		
		IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity', * FROM [pcINTEGRATOR_Data].[dbo].[Entity] WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SourceID = @SourceID_Financials

	SET @Step = 'Fill [EntityPropertyValue]'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue]
			(
			[InstanceID],
			[VersionID],
			[EntityID],
			[EntityPropertyTypeID],
			[EntityPropertyValue],
			[SelectYN]
			)
		SELECT
			[InstanceID] = E.[InstanceID],
			[VersionID] = E.[VersionID],
			[EntityID] = E.[EntityID],
			[EntityPropertyTypeID] = P.[EntityPropertyTypeID],
			[EntityPropertyValue] = CASE P.[EntityPropertyTypeID] WHEN -1 THEN C.[SourceDatabase] WHEN -2 THEN CONVERT(nvarchar(15), @SourceTypeID) END,
			[SelectYN] = 1
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [#Company] C ON C.Company = E.[MemberKey]
			INNER JOIN (SELECT [EntityPropertyTypeID] = -1 UNION SELECT [EntityPropertyTypeID] = -2) P ON 1 = 1
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			E.[SourceID] = @SourceID_Financials AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV WHERE EPV.[InstanceID] = E.[InstanceID] AND EPV.[VersionID] = E.[VersionID] AND EPV.[EntityID] = E.[EntityID] AND EPV.[EntityPropertyTypeID] = P.[EntityPropertyTypeID])

	SET @Step = 'Create and fill temp table #GLBook'
		CREATE TABLE #Currency
			(
			[Company] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[CurrencyCode] nvarchar(4) COLLATE DATABASE_DEFAULT
			)

		IF CURSOR_STATUS('global','Currency_Cursor') >= -1 DEALLOCATE Currency_Cursor
		DECLARE Currency_Cursor CURSOR FOR

		SELECT DISTINCT
			DatabaseName = [SourceDatabase]
		FROM
			#Company c
--			INNER JOIN sys.databases d ON d.[name] = c.[SourceDatabase]

		OPEN Currency_Cursor

		FETCH NEXT FROM Currency_Cursor INTO @SourceDatabase

		WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@SourceDatabase] = @SourceDatabase
			
				EXEC spGet_TableExistsYN @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @SourceDatabase, @TableName = 'ScaCompanyProperty', @ExistsYN = @ExistsYN OUT, @JobID = @JobID, @Debug = @DebugSub
				
				IF @ExistsYN <> 0
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #Currency
								(
								[Company],
								[CurrencyCode]
								)
							SELECT
								[Company] = P.[CompanyCode],
								[CurrencyCode] = P.[Value]
							FROM
								' + @SourceDatabase + '.[dbo].ScaCompanyProperty P
							WHERE
								P.PropertyID = 111 AND
								NOT EXISTS (SELECT 1 FROM #Currency C WHERE C.[Company] = P.[CompanyCode] COLLATE DATABASE_DEFAULT)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END
			
			FETCH NEXT FROM Currency_Cursor INTO @SourceDatabase
			END

		CLOSE Currency_Cursor
		DEALLOCATE Currency_Cursor

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Currency', * FROM #Currency ORDER BY [Company]

		CREATE TABLE #GLBook
			(
			[Company] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[BookID] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[MainBook] bit,
			[COACode] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[CurrencyCode] nvarchar(4) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #GLBook
			(
			[Company],
			[BookID],
			[MainBook],
			[COACode],
			[CurrencyCode]
			)
		SELECT
			[Company] = E.[MemberKey],
			[BookID] = 'GL',
			[MainBook] = 1,
			[COACode] = NULL,
			[CurrencyCode] = C.[CurrencyCode]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			LEFT JOIN #Currency C ON C.Company = E.[MemberKey]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SourceID] = @SourceID_Financials

	SET @Step = 'Update Entity_Book'
		UPDATE EB
		SET
			[Book] = GLB.[BookID],
			[Currency] = ISNULL(UPPER(SUBSTRING(GLB.[CurrencyCode], 1, 3)), EB.[Currency]),
			[BookTypeBM] = 1 + CASE WHEN GLB.[MainBook] <> 0 THEN 2 ELSE 0 END,
			[COA] =  ISNULL(EB.COA, GLB.COACode),
			[BalanceType] = 'B'
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity_Book] EB
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.EntityID = EB.EntityID AND E.SourceID = @SourceID_Financials
			INNER JOIN [#GLBook] GLB ON GLB.Company = E.MemberKey AND GLB.BookID = EB.Book
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
			[BalanceType] = 'B',
			[SelectYN] = CASE WHEN GLB.[CurrencyCode] IS NULL THEN 0 ELSE 1 END
		FROM
			pcINTEGRATOR_Data..[Entity] E
			INNER JOIN [#GLBook] GLB ON GLB.Company = E.MemberKey
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			E.[SourceID] = @SourceID_Financials AND
			NOT EXISTS (SELECT 1 FROM [Entity_Book] EB WHERE EB.InstanceID = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.EntityID = E.EntityID AND EB.Book = GLB.[BookID])

		SET @Inserted = @Inserted + @@ROWCOUNT
		IF @DebugBM & 2 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity_Book', EB.* FROM [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB WHERE EB.InstanceID = @InstanceID AND EB.VersionID = @VersionID

	SET @Step = 'Drop temp tables'	
		DROP TABLE #Company
		DROP TABLE #GLBook
		DROP TABLE #Currency

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
