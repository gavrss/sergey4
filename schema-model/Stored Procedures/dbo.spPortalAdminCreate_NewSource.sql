SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminCreate_NewSource]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DemoYN bit = 1,
	@SourceServer nvarchar(100) = 'DSPSOURCE01',
	@SourceDatabase nvarchar(100) = NULL,
	@FiscalYearStartMonth int = 1,
	@SourceTypeID int = 11,
	@StartYear int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000240,
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
	@ProcedureName = 'spPortalAdminCreate_NewSource',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminCreate_NewSource] 
	@UserID = -1216,
	@InstanceID = -1039,
	@VersionID = -1039,
	@DemoYN = 1,
	@SourceServer = 'DSPSOURCE01',
	@SourceDatabase = 'Kiplinger_E7',
	@SourceTypeID = 12,
	@Debug = 1

EXEC [spPortalAdminCreate_NewSource] 
	@UserID = -1124,
	@InstanceID = -1112,
	@VersionID = -1050,
	@DemoYN = 1,
	@SourceServer = 'DSPSOURCE01',
	@SourceDatabase = 'ERP10',
	@Debug = 1

EXEC [spPortalAdminCreate_NewSource] 
	@UserID = 3689,
	@InstanceID = 424,
	@VersionID = 1012,
	@DemoYN = 0,
	@SourceServer = 'DSPSOURCE01\HEARTLAND',
	@SourceDatabase = 'HDCI_Control',
	@Debug = 1

EXEC [spPortalAdminCreate_NewSource] 
	@UserID = 6271,
	@InstanceID = 442,
	@VersionID = 1014,
	@DemoYN = 0,
	@SourceServer = 'DSPSOURCE01',
	@SourceDatabase = 'Satco_Epicor10',
	@Debug = 1

EXEC [spPortalAdminCreate_NewSource] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@ModelID_Financials int,
	@ModelID_Financials_Detail int,
	@ModelID_FxRate int,
	@SourceID_Financials int,
	@SourceID_FxRate int,
	@ApplicationID int,
	@ApplicationName nvarchar(100),
	@ETLDatabase nvarchar(100),
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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create New Source',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.2.2146' SET @Description = 'Added filter on SourceTypeFamilyID when Inserting into Entity-related tables.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'

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
			@ApplicationID = [ApplicationID],
			@ApplicationName = [ApplicationName],
			@ETLDatabase = [ETLDatabase],
			@StartYear =  ISNULL(@StartYear, I.StartYear)
		FROM
			[Application] A
			INNER JOIN [Instance] I ON I.InstanceID = A.InstanceID
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID

		SELECT
			@ModelID_Financials = MAX(CASE WHEN BaseModelID = -7 THEN ModelID ELSE NULL END),
			@ModelID_Financials_Detail = MAX(CASE WHEN BaseModelID = -8 THEN ModelID ELSE NULL END),
			@ModelID_FxRate = MAX(CASE WHEN BaseModelID = -3 THEN ModelID ELSE NULL END)
		FROM
			Model
		WHERE
			ApplicationID = @ApplicationID AND
			SelectYN <> 0

	SET @Step = 'Update Instance and Application for FiscalYearStartMonth'
		UPDATE I
		SET
			[FiscalYearStartMonth] = ISNULL(@FiscalYearStartMonth, 1)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Instance] I
		WHERE
			I.InstanceID = @InstanceID

		UPDATE A
		SET
			[FiscalYearStartMonth] = ISNULL(@FiscalYearStartMonth, 1)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID

	SET @Step = 'Create Source'
		IF (SELECT COUNT(1) FROM [Source] WHERE ModelID IN (@ModelID_Financials, @ModelID_FxRate)) = 0
			BEGIN
				SELECT @SourceID_Financials = MIN(SourceID) - 1 FROM [Source] WHERE SourceID < -1000
				SET @SourceID_Financials = ISNULL(@SourceID_Financials, -1001)
				SET @SourceID_FxRate = @SourceID_Financials - 1

				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Source] ON
		
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Source]
					(
					[InstanceID],
					[VersionID],
					[SourceID],
					[SourceName],
					[SourceDescription],
					[BusinessProcess],
					[ModelID],
					[SourceTypeID],
					[SourceDatabase],
					[StartYear]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[SourceID] = sub.[SourceID],
					[SourceName] = sub.[SourceName],
					[SourceDescription] = sub.[SourceDescription],
					[BusinessProcess] = sub.[BusinessProcess],
					[ModelID]= sub.[ModelID],
					[SourceTypeID] = sub.[SourceTypeID],
					[SourceDatabase] = sub.[SourceDatabase],
					[StartYear] = sub.[StartYear]
				FROM
					(	
					SELECT
						[InstanceID] = @InstanceID,
						[VersionID] = @VersionID,
						[SourceID] = @SourceID_Financials,
						[SourceName] = 'Financials',
						[SourceDescription] = 'Financials',
						[BusinessProcess] = 'E10_' + CONVERT(nvarchar(10), @SourceID_Financials),
						[ModelID]= @ModelID_Financials,
						[SourceTypeID] = @SourceTypeID,
						[SourceDatabase] = CASE WHEN @SourceServer = @@SERVERNAME THEN '' ELSE @SourceServer + '.' END + @SourceDatabase,
						[StartYear] = @StartYear
					UNION
					SELECT
						[InstanceID] = @InstanceID,
						[VersionID] = @VersionID,
						[SourceID] = @SourceID_FxRate,
						[SourceName] = 'FxRate',
						[SourceDescription] = 'FxRate',
						[BusinessProcess] = 'E10_' + CONVERT(nvarchar(10), @SourceID_FxRate),
						[ModelID]= @ModelID_FxRate,
						[SourceTypeID] = @SourceTypeID,
						[SourceDatabase] = CASE WHEN @SourceServer = @@SERVERNAME THEN '' ELSE @SourceServer + '.' END + @SourceDatabase,
						[StartYear] = @StartYear
					) sub
				WHERE
					NOT EXISTS (SELECT 1 FROM [Source] S WHERE S.[SourceName] = sub.[SourceName] AND S.[ModelID] = sub.[ModelID] AND S.[SourceTypeID] = sub.[SourceTypeID] AND S.[SourceDatabase] = sub.[SourceDatabase])

				SET @Inserted = @Inserted + @@ROWCOUNT
		
				SET IDENTITY_INSERT [pcINTEGRATOR_Data].[dbo].[Source] OFF
			END
		ELSE
			BEGIN
				SELECT @SourceID_Financials = SourceID FROM [pcINTEGRATOR_Data].[dbo].[Source] WHERE ModelID = @ModelID_Financials
				SELECT @SourceID_FxRate = SourceID FROM [pcINTEGRATOR_Data].[dbo].[Source] WHERE ModelID = @ModelID_FxRate
			END

	SET @Step = 'Standard Callisto Setup'
		IF @Debug <> 0 SELECT SourceServer = @SourceServer
		--EXEC [spGet_Customer_Metadata] @CustomerID = @CustomerID, @CreateXmlYN = 0         --Step  900, Shows your current settings

		EXEC [spCreate_Linked_ETL_Script] @ApplicationID = @ApplicationID, @ManuallyYN = 0  --Step 1100, If you have your source database on a Linked Server, you need to run this query from your source database to create a linked pcETL database

		CREATE TABLE #Counter ([Count] int)
		SET @SQLStatement = 'INSERT INTO #Counter ([Count]) SELECT COUNT(1) FROM [' + @SourceServer + '].master.sys.databases WHERE [name] = ''pcETL_LINKED_''' + @ApplicationName

--		WHILE (SELECT COUNT(1) FROM DSPSOURCE01.master.sys.databases WHERE [name] = 'pcETL_LINKED_' + @ApplicationName) = 0
		WHILE (SELECT [Count] FROM #Counter) = 0
			BEGIN 
				SELECT RemoteETL = 1, ApplicationID = @ApplicationID, ManuallyYN = 0, Duration = CONVERT(time(7), GetDate() - @StartTime)
				WAITFOR DELAY '00:00:02'  
				TRUNCATE TABLE #Counter
				EXEC(@SQLStatement)
			END  

		DROP TABLE #Counter
		EXEC [spCreate_ETL_Object_Initial] @ApplicationID = @ApplicationID, @DataBaseBM = 1 --Step 1200, Create the ETL database and all Tables, Procedures and Functions

		EXEC [spInsert_ETL_Entity] @ApplicationID = @ApplicationID                          --Step 1300, All Entities (Companies) will be loaded from the source database(s) into the ETL database.

		EXEC [spInsert_ETL_FinancialSegment] @ApplicationID = @ApplicationID                --Step 1500, Fill the ETL FinancialSegment table

	SET @Step = 'Fill Entity'
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity]
				(
				InstanceID,
				VersionID,
				MemberKey,
				EntityName,
				SelectYN
				)
			SELECT
				InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ',
				MemberKey = CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE CASE WHEN ST.SourceTypeFamilyID IN (3) THEN E.EntityCode ELSE E.Entity END END,
				EntityName = MAX(CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN REPLACE(E.EntityName, '' - '' + E.Par02, '''') ELSE E.EntityName END),
				SelectYN = MAX(CONVERT(int, E.SelectYN))
			FROM
				' + @ETLDatabase + '..Entity E
				INNER JOIN [Source] S ON S.SourceID = E.SourceID
				INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
			WHERE
				E.SourceID = ' + CONVERT(nvarchar(10), @SourceID_Financials) + ' AND
				NOT EXISTS (SELECT 1 FROM [Entity] pcIE WHERE pcIE.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND pcIE.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND pcIE.MemberKey = CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE CASE WHEN ST.SourceTypeFamilyID IN (3) THEN E.EntityCode ELSE E.Entity END END)
			GROUP BY
				CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE CASE WHEN ST.SourceTypeFamilyID IN (3) THEN E.EntityCode ELSE E.Entity END END'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity', * FROM [pcINTEGRATOR_Data].[dbo].[Entity] WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Fill Entity_Book'
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity_Book]
				(
				[InstanceID],
				[VersionID],
				[EntityID],
				[Book],
				[Currency],
				[BookTypeBM],
				SelectYN
				)
			SELECT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[EntityID] = pcIE.[EntityID],
				[Book] = CASE WHEN ST.SourceTypeFamilyID IN (1) AND BM.ModelID = -7 THEN E.Par02 ELSE CASE WHEN BM.ModelID = -7 THEN ''GL'' ELSE BM.ModelName END END,
				[Currency] = E.[Currency],
				[BookTypeBM] = CASE BM.ModelID WHEN -7 THEN 1 WHEN -3 THEN 4 ELSE 8 END + CASE WHEN BM.ModelID = -7 AND ((ST.SourceTypeFamilyID IN (1) AND E.Par08 = ''1'') OR ST.SourceTypeFamilyID NOT IN (1)) THEN 2 ELSE 0 END,
				SelectYN = E.SelectYN
			FROM
				' + @ETLDatabase + '..Entity E
				INNER JOIN [Source] S ON S.SourceID = E.SourceID
				INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
				INNER JOIN [Entity] pcIE ON pcIE.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND pcIE.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND pcIE.MemberKey = CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE CASE WHEN ST.SourceTypeFamilyID IN (3) THEN E.EntityCode ELSE E.Entity END END
				INNER JOIN Model M ON M.ModelID = S.ModelID
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
			WHERE
				E.SourceID IN (' + CONVERT(nvarchar(10), @SourceID_Financials) + ', ' + CONVERT(nvarchar(10), @SourceID_FxRate) + ') AND
				NOT EXISTS (SELECT 1 FROM [Entity_Book] EB WHERE EB.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND EB.EntityID = pcIE.EntityID AND EB.Book = CASE WHEN ST.SourceTypeFamilyID IN (1) AND BM.ModelID = -7 THEN E.Par02 ELSE CASE WHEN BM.ModelID = -7 THEN ''GL'' ELSE BM.ModelName END END)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity_Book', EB.* FROM [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.EntityID = EB.EntityID WHERE E.InstanceID = @InstanceID AND E.VersionID = @VersionID

	SET @Step = 'Fill Journal_SegmentNo'
		/**
		TODOS: Issues found:
		1) For ENT, the EntityNames does not match between [FinancialSegment] and [MappedObject]
		2) INNER JOIN ... FS.[EntityCode] = E.MemberKey + ''_'' + EB.Book --> IS ONLY VALID FOR EPICOR ERP
		3) Need a JOIN between FinancialSegment and MappedObject to get correct [SegmentName]
		*/
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo]
				(
				[JobID],
				[VersionID],
				[InstanceID],
				[EntityID],
				[Entity],
				[Book],
				[SegmentCode],
				[SourceCode],
				[SegmentNo],
				[SegmentName],
				[DimensionID],
				[MaskPosition],
				[MaskCharacters],
				[SelectYN]
				)
			SELECT
				[JobID] = ' + CONVERT(nvarchar(10), ISNULL(@JobID, @ProcedureID)) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[EntityID] = E.EntityID,
				[Entity] = E.MemberKey,
				[Book] = EB.Book,
				[SegmentCode] = FS.[SegmentName],
				[SourceCode] = FS.[SegmentCode],
				[SegmentNo] = CASE WHEN DimensionTypeID = 1 THEN 0 ELSE -1 END,
				[SegmentName] = CASE WHEN DimensionTypeID = 1 THEN ''Account'' ELSE ''GL_'' + REPLACE(REPLACE(FS.[SegmentName], '' '', ''_''), ''GL_'', '''') END,
				[DimensionID] = CASE WHEN DimensionTypeID = 1 THEN -1 ELSE NULL END,
				[MaskPosition] = NULL,
				[MaskCharacters] = NULL,
				[SelectYN] = 1
			FROM
				[Entity_Book] EB
				INNER JOIN [Entity] E ON E.InstanceID = EB.InstanceID AND E.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND E.EntityID = EB.EntityID
				INNER JOIN ' + @ETLDatabase + '..[FinancialSegment] FS ON FS.SourceID = ' + CONVERT(nvarchar(10), @SourceID_Financials) + ' AND FS.[EntityCode] = E.MemberKey + ''_'' + EB.Book
			WHERE
				EB.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				EB.BookTypeBM & 3 > 0
				AND NOT EXISTS (SELECT 1 FROM [Journal_SegmentNo] JSN WHERE JSN.[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND JSN.[EntityID] = E.EntityID AND JSN.[Book] = EB.Book AND JSN.[SegmentCode] = FS.[SegmentName])'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR..Journal_SegmentNo', JSN.* FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.EntityID = JSN.EntityID AND EB.Book = JSN.Book INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.EntityID = EB.EntityID WHERE E.InstanceID = @InstanceID AND E.VersionID = @VersionID

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
