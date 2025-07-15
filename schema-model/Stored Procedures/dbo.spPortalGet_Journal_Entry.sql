SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Journal_Entry]
	@UserID INT = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ResultTypeBM int = 31, --1=DimensionList, 2=DimensionMember, 4=JournalHead, 8=JournalLine, 16=Valid segments, 32=Journal list, 64=Valid JournalSequence, 128=Valid TransactionDate
	
	@JournalID bigint = NULL,
	@Group nvarchar(50) = NULL, --Mandatory for ResultTypeBM 4, 8, 32 and 64. --Temporary, should be NULL
	@Entity nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@JournalSequence NVARCHAR(50) = NULL,
	@JournalNo NVARCHAR(50) = NULL,
	@TransactionDate DATE = NULL,	
	@JournalJobID INT = NULL,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000734,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

AS

/*
--JobID filter
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"InstanceID","TValue":"613"},{"TKey":"JournalJobID","TValue":"114720"},{"TKey":"UserID","TValue":"12054"},
{"TKey":"VersionID","TValue":"1100"},{"TKey":"ResultTypeBM","TValue":"32"}]', @ProcedureName='spPortalGet_Journal_Entry'

--valid Segments when Entity and Book = All_
EXEC [pcINTEGRATOR].[dbo].[spPortalGet_Journal_Entry_20231103_nehatest] @Book='All_',@Entity='All_',@InstanceID='613',@ResultTypeBM='16',@UserID='12054',@VersionID='1100',@DebugBM='15'
EXEC [pcINTEGRATOR].[dbo].[spPortalGet_Journal_Entry_20231103_nehatest] @InstanceID='613',@ResultTypeBM='16',@UserID='12054',@VersionID='1100',@DebugBM='15'
EXEC [pcINTEGRATOR].[dbo].[spPortalGet_Journal_Entry_20231103_nehatest] @Book='MAIN',@Entity='SG02',@InstanceID='613',@ResultTypeBM='16',@UserID='12054',@VersionID='1100',@DebugBM='15'

--valid Segments when Entity and Book = All_
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"DebugBM","TValue":"15"},{"TKey":"InstanceID","TValue":"613"},{"TKey":"Entity","TValue":"All_"},{"TKey":"Book","TValue":"All_"},
{"TKey":"UserID","TValue":"12054"},{"TKey":"VersionID","TValue":"1100"},{"TKey":"ResultTypeBM","TValue":"16"}]', @ProcedureName='spPortalGet_Journal_Entry'

--valid Segments for specific Entity and Book
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"DebugBM","TValue":"15"},{"TKey":"InstanceID","TValue":"613"},{"TKey":"Entity","TValue":"SG02"},{"TKey":"Book","TValue":"MAIN"},
{"TKey":"UserID","TValue":"12054"},{"TKey":"VersionID","TValue":"1100"},{"TKey":"ResultTypeBM","TValue":"16"}]', @ProcedureName='spPortalGet_Journal_Entry'


--set Entity and Book to All_
EXEC [pcINTEGRATOR].[dbo].[spPortalGet_Journal_Entry_20231103_nehatest] @InstanceID='613',@ResultTypeBM='3',@UserID='12054',@VersionID='1100',@DebugBM='0'

--set Entity and Book to All_
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"InstanceID","TValue":"613"},{"TKey":"UserID","TValue":"12054"},{"TKey":"DebugBM","TValue":"0"},
{"TKey":"VersionID","TValue":"1100"},{"TKey":"ResultTypeBM","TValue":"3"}]', @ProcedureName='spPortalGet_Journal_Entry'


--show JobID,Entity,Book columns for Entity=All, Book = All
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"DebugBM","TValue":"15"},{"TKey":"Entity","TValue":"SG02"},{"TKey":"InstanceID","TValue":"613"},{"TKey":"Book","TValue":"MAIN"},
{"TKey":"UserID","TValue":"12054"},{"TKey":"VersionID","TValue":"1100"},{"TKey":"ResultTypeBM","TValue":"32"}]', @ProcedureName='spPortalGet_Journal_Entry'

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
	@EntityID INT,
	@SQLStatement NVARCHAR(MAX),
	@JournalTable NVARCHAR(100),
	@DataClassID INT,
	@DimensionList NVARCHAR(1000) = '',
	@MasterClosedYear INT,
	@FiscalPeriod INT,
	@EB_EntityID INT, 
	@EB_Entity NVARCHAR(50),
	@EB_Book NVARCHAR(50),

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
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2199'

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
		IF @Version = '2.1.2.2196' SET @Description = 'Handle Group adjustments.'
		IF @Version = '2.1.2.2199' SET @Description = 'Added Currency dimension in ResultTypeBM 1 & 2. DB-1642: Handle filters for Entity = All_ and Book = All_. Added [DimensionID] for ResultTypeBM = 1.'

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
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

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
						@InternalVariable4 = J.[FiscalPeriod], 
						@InternalVariable5 = J.[JournalSequence], 
						@InternalVariable6 = J.[JournalNo], 
						@InternalVariable7 = J.[ConsolidationGroup]  
					FROM
						' + @JournalTable + ' J
					WHERE
						J.[InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID) + ' AND
						J.[JournalID] = ' + CONVERT(NVARCHAR(20), @JournalID)

--						--(J.[ConsolidationGroup] = ''' + @Group + ''' OR (''' + @Group + ''' = ''NONE'' AND J.[ConsolidationGroup] IS NULL)) AND
--						' + CASE WHEN @Group IS NULL OR @Group = 'NONE' THEN 'J.[ConsolidationGroup] IS NULL' ELSE 'J.[ConsolidationGroup] = ''' + @Group + '''' END + ' AND

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC sp_executesql @SQLStatement, N'@InternalVariable1 nvarchar(50) OUT, @InternalVariable2 nvarchar(50) OUT, @InternalVariable3 int OUT, @InternalVariable4 nvarchar(50) OUT, @InternalVariable5 nvarchar(50) OUT, @InternalVariable6 nvarchar(50) OUT, @InternalVariable7 nvarchar(50) OUT', @InternalVariable1 = @Entity OUT, @InternalVariable2 = @Book OUT, @InternalVariable3 = @FiscalYear OUT, @InternalVariable4 = @FiscalPeriod OUT, @InternalVariable5 = @JournalSequence OUT, @InternalVariable6 = @JournalNo OUT, @InternalVariable7 = @Group OUT
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
				[@FiscalPeriod] = @FiscalPeriod,
				[@JournalSequence] = @JournalSequence,
				[@JournalNo] = @JournalNo,
				[@Group] = @Group

	SET @Step = 'Reset to NULL for All_ values'	
		SELECT
			@Entity = CASE WHEN @Entity IN ('All','All_') THEN NULL ELSE @Entity END,
			@Book = CASE WHEN @Book IN ('All','All_') THEN NULL ELSE @Book END

		IF @DebugBM & 2 > 0  SELECT [@Entity] = @Entity, [@Book] = @Book

	SET @Step = 'Set @MasterClosedYear'	
		EXEC [dbo].[spGet_MasterClosedYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @MasterClosedYear = @MasterClosedYear OUT, @JobID = @JobID
		SET @MasterClosedYear = ISNULL(@MasterClosedYear, YEAR(GETDATE()) -1)
		IF @DebugBM & 2 > 0 SELECT [@MasterClosedYear] = @MasterClosedYear

	SET @Step = 'Create temp table #FiscalPeriod'	
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear INT,
			FiscalPeriod INT,
			YearMonth INT
			)
		
	SET @Step = 'Create and fill temp table #Entity_Book'
		CREATE TABLE #Entity_Book
			(
			[EntityID] INT,
			[Entity] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[Book] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[Currency] NCHAR(3) COLLATE DATABASE_DEFAULT,
			[FiscalYear] INT,
			[FiscalPeriod] INT
			)

		INSERT INTO #Entity_Book
			(
			[EntityID],
			[Entity],
			[Book],
			[Currency],
			[FiscalYear],
			[FiscalPeriod]
			)
		SELECT 
			[EntityID] = E.EntityID,
			[Entity] = E.MemberKey, 
			[Book] = EB.Book,
			[Currency] = EB.Currency,
			[FiscalYear] = @FiscalYear,
			[FiscalPeriod] = @FiscalPeriod
		FROM 
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 1 > 0 AND EB.SelectYN <> 0 AND (EB.Book = @Book OR @Book IS NULL)
		WHERE 
			E.InstanceID = @InstanceID AND 
			E.VersionID = @VersionID AND 
			(E.MemberKey = @Entity OR @Entity IS NULL) AND
			E.SelectYN <> 0
			
		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Entity_Book', * FROM #Entity_Book

		IF @FiscalYear IS NULL AND @TransactionDate IS NOT NULL
			BEGIN
				IF CURSOR_STATUS('global','Entity_Book_Cursor') >= -1 DEALLOCATE Entity_Book_Cursor
				DECLARE Entity_Book_Cursor CURSOR FOR
			
					SELECT DISTINCT		 
						[EntityID],
						[Entity], 
						[Book]
					FROM 
						#Entity_Book

					OPEN Entity_Book_Cursor
					FETCH NEXT FROM Entity_Book_Cursor INTO @EB_EntityID, @EB_Entity, @EB_Book

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@EB_EntityID] = @EB_EntityID, [@EB_Entity] = @EB_Entity, [@EB_Book] = @EB_Book

							EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear=@MasterClosedYear, @FiscalPeriod13YN = 1, @JobID = @JobID

							TRUNCATE TABLE #FiscalPeriod

							IF @DebugBM & 2 > 0 SELECT * FROM #FiscalPeriod ORDER BY FiscalYear, FiscalPeriod

							UPDATE EB
							SET 
								[FiscalYear] = ISNULL(@FiscalYear, FP.FiscalYear),
								[FiscalPeriod] = ISNULL(@FiscalPeriod, FP.FiscalPeriod)
							FROM
								#Entity_Book EB
								INNER JOIN #FiscalPeriod FP ON 1 =1 OR (FP.YearMonth = YEAR(@TransactionDate) * 100 + MONTH(@TransactionDate))
							WHERE
								EB.Entity = @EB_Entity AND
                                EB.Book = @EB_Book

								SELECT
									@FiscalYear = ISNULL(@FiscalYear, FiscalYear),
									@FiscalPeriod = ISNULL(@FiscalPeriod, FiscalPeriod)
								FROM
									#FiscalPeriod
								WHERE
									YEAR(@TransactionDate) * 100 + MONTH(@TransactionDate) = YearMonth

							FETCH NEXT FROM Entity_Book_Cursor INTO @EB_EntityID, @EB_Entity, @EB_Book
						END

				CLOSE Entity_Book_Cursor
				DEALLOCATE Entity_Book_Cursor

            END

			IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Entity_Book with FiscalYear/FiscalPeriod', * FROM #Entity_Book

		--SELECT
		--	@EntityID = EntityID
		--FROM
		--	pcINTEGRATOR_Data..Entity
		--WHERE
		--	InstanceID = @InstanceID AND
		--	VersionID = @VersionID AND
		--	MemberKey = @Entity AND
		--	SelectYN <> 0 AND
		--	DeletedID IS NULL
		
		--EXEC [pcINTEGRATOR].[dbo].[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear=@MasterClosedYear, @FiscalPeriod13YN = 1, @JobID = @JobID

		--IF @DebugBM & 2 > 0 SELECT * FROM #FiscalPeriod ORDER BY FiscalYear, FiscalPeriod

		--IF @FiscalYear IS NULL AND @TransactionDate IS NOT NULL
		--	BEGIN
		--		SELECT
		--			@FiscalYear = ISNULL(@FiscalYear, FiscalYear),
		--			@FiscalPeriod = ISNULL(@FiscalPeriod, FiscalPeriod)
		--		FROM
		--			#FiscalPeriod
		--		WHERE
		--			YEAR(@TransactionDate) * 100 + MONTH(@TransactionDate) = YearMonth
		--	END


	SET @Step = 'Fill table #SegmentsList'
		IF @ResultTypeBM & 19 > 0
			BEGIN
				--SELECT
				--	[SegmentNo] = 'Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), JSN.[SegmentNo]),
				--	[SegmentName] = JSN.[SegmentName],
				--	[DimensionID] = JSN.[DimensionID],
				--	[DimensionName] = D.[DimensionName]
				--INTO
				--	#SegmentsList
				--FROM
				--	pcINTEGRATOR_Data..Journal_SegmentNo JSN
				--	INNER JOIN pcINTEGRATOR..[Dimension] D ON D.[DimensionID] = JSN.[DimensionID]
				--WHERE
				--	JSN.[InstanceID] = @InstanceID AND
				--	JSN.[VersionID] = @VersionID AND
				--	JSN.[EntityID] = @EntityID AND
				--	JSN.[Book] = @Book AND
				--	JSN.[SelectYN] <> 0 AND
				--	JSN.[SegmentNo] > 0
				--ORDER BY
				--	JSN.[SegmentNo]

				SELECT
					[Entity] = EB.[Entity],
					[Book] = EB.[Book],
					[SegmentNo] = 'Segment' + CASE WHEN JSN.[SegmentNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), JSN.[SegmentNo]),
					[SegmentName] = JSN.[SegmentName],
					[DimensionID] = JSN.[DimensionID],
					[DimensionName] = D.[DimensionName]
				INTO
					#SegmentsList
				FROM
					[pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN
					INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.[DimensionID] = JSN.[DimensionID]
					INNER JOIN #Entity_Book EB ON EB.[EntityID] = JSN.[EntityID] AND EB.[Book] = JSN.[Book]
				WHERE
					JSN.[InstanceID] = @InstanceID AND
					JSN.[VersionID] = @VersionID AND
					JSN.[SelectYN] <> 0 AND
					JSN.[SegmentNo] > 0
				ORDER BY
					JSN.[SegmentNo]

				IF @DebugBM & 2 > 0 SELECT TempTable = '#SegmentsList', * FROM #SegmentsList
			END

	SET @Step = 'Set @DimensionList'
		IF @ResultTypeBM & 3 > 0
			BEGIN
				SET @DimensionList = '-1|-3|-4|-6|-34|-31|-35'

				SELECT  
					@DimensionList = @DimensionList + '|' + CONVERT(nvarchar(15), [DimensionID])
				FROM
					--#SegmentsList
					(
					SELECT DISTINCT 
						[SegmentNo],
						[DimensionID]
					FROM
						#SegmentsList
					) sub
				ORDER BY
					sub.[SegmentNo]

				IF @DebugBM & 2 > 0 SELECT [@DimensionList] = @DimensionList
			END

	SET @Step = 'Get Dimension list'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				
--				ResultTypeBM	ParameterType	DimensionID	ParameterName	DefaultMemberID	DefaultMemberKey	DefaultMemberDescription	DefaultHierarchyNo	DefaultHierarchyName	DefaultSource	Visible	Changeable	Parameter	DataType	FormatString	Axis	Index	ReadSecurityEnabledYN
--1	Dimension	-1	Account	NULL	NULL	NULL	0			1	0	Account	string	NULL	Filter	NULL	0
				CREATE TABLE #DimensionTable
					(
					ResultTypeBM int,
					ParameterType nvarchar(20),
					[DimensionID] int,
					[ParameterName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					DefaultMemberID bigint,
					DefaultMemberKey nvarchar(100) COLLATE DATABASE_DEFAULT,
					DefaultMemberDescription  nvarchar(255) COLLATE DATABASE_DEFAULT,
					DefaultHierarchyNo int,
					DefaultHierarchyName nvarchar(100) COLLATE DATABASE_DEFAULT,
					DefaultSource nvarchar(100) COLLATE DATABASE_DEFAULT,
					Visible bit,
					Changeable bit,
					Parameter nvarchar(100) COLLATE DATABASE_DEFAULT,
					DataType nvarchar(100) COLLATE DATABASE_DEFAULT,
					FormatString nvarchar(100) COLLATE DATABASE_DEFAULT,
					Axis nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Index] nvarchar(100) COLLATE DATABASE_DEFAULT,
					ReadSecurityEnabledYN bit
					)

				INSERT INTO #DimensionTable 
				EXEC [pcINTEGRATOR].[dbo].[spGet_DataClass_DimensionList] @UserID = @UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID=@DataClassID, @ResultTypeBM=1, @DimensionList = @DimensionList, @JobID=@JobID, @Debug=@DebugSub
			
				INSERT INTO #DimensionTable
					(
					ResultTypeBM,
					ParameterType,
					[DimensionID],
					[ParameterName]
					)
				SELECT
					ResultTypeBM = 1,
					ParameterType = 'Dimension',
					[DimensionID] = NULL,
					[ParameterName] = 'Book'

				IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionTable', * FROM #DimensionTable

				SELECT 
					ResultTypeBM,
					DimensionID,
					ParameterName,
					ParameterDescription = ParameterName,
					DataType = 'string',
					ParameterType = 'SingleSelect',
					KeyColumn = 'MemberKey',
					DefaultMemberKey = NULL,
					NodeTypeBM = NULL,
					LeafLevelFilter = NULL
				FROM #DimensionTable
			END

	SET @Step = 'Get Dimension members'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@DimensionList] = @DimensionList

				EXEC [pcINTEGRATOR].[dbo].[spGet_DataClass_DimensionMember] @UserID = @UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID=@DataClassID, @DimensionList = @DimensionList, @ShowAllMembersYN=1, @UseCacheYN=0, @JobID=@JobID, @Debug=@DebugSub
/*			
				SELECT
					ResultTypeBM = 2,
					Dim = 'Book',
					MemberID = 0,
					MemberKey = 'Main2',
					MemberDescription = 'Main2',
					NodeTypeBM = 1,
					ParentMemberId = 0,
					WriteYN	= 1,
					SortOrder = 1,
					Entity_MemberKey = 104
*/
				SELECT
					ResultTypeBM = 2,
					Dim = 'Book',
					MemberID = NULL,
					MemberKey = EB.Book,
					MemberDescription = EB.Book,
					NodeTypeBM = 1,
					ParentMemberId = 0,
					WriteYN	= 1,
					SortOrder = 1,
					Entity_MemberKey = E.MemberKey
				FROM
					pcINTEGRATOR_Data..Entity E
					INNER JOIN pcINTEGRATOR_Data..Entity_Book EB ON EB.EntityID = E.EntityID AND EB.BookTypeBM & 3 > 0 AND EB.SelectYN <> 0
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					E.EntityTypeID <> 0 AND
					E.SelectYN <> 0 AND
					E.DeletedID IS NULL
			
			END

	SET @Step = 'Get Journal head'
		IF @ResultTypeBM & 4 > 0
			BEGIN
/*
				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 4,
						[JournalID] = MIN(J.[JournalID]),
						[Group] = MAX(CASE WHEN J.[ConsolidationGroup] IS NULL THEN ''NONE'' ELSE J.[ConsolidationGroup] END),
						[Entity] = J.[Entity],
						[Book] = J.[Book],
						[JournalSequence] = J.[JournalSequence],
						[JournalNo] = J.[JournalNo],
						[Currency] = MAX(CASE WHEN J.[ConsolidationGroup] IS NULL THEN J.[Currency_Book] ELSE J.[Currency_Group] END),
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
						J.[FiscalPeriod] = ' + CONVERT(nvarchar(15), @FiscalPeriod) + ' AND
						J.[JournalSequence] = ''' + @JournalSequence + ''' AND
						J.[JournalNo] = ''' + @JournalNo + ''' AND
						' + CASE WHEN @Group IS NULL OR @Group = 'NONE' THEN 'J.[ConsolidationGroup] IS NULL' ELSE 'J.[ConsolidationGroup] = ''' + @Group + '''' END + '
					GROUP BY
						J.[Entity],
						J.[Book],
						J.[FiscalYear],
						J.[JournalSequence],
						J.[JournalNo]'
*/

				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 4,
						[JournalID] = MIN(J.[JournalID]),
						[Group] = MAX(CASE WHEN J.[ConsolidationGroup] IS NULL THEN ''NONE'' ELSE J.[ConsolidationGroup] END),
						[Entity] = J.[Entity],
						[Book] = J.[Book],
						[JournalSequence] = J.[JournalSequence],
						[JournalNo] = J.[JournalNo],
						[Currency] = MAX(CASE WHEN J.[ConsolidationGroup] IS NULL THEN ISNULL(J.[Currency_Book], J.[Currency_Transaction]) ELSE J.[Currency_Group] END),
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
						[Source] = MAX(J.[Source]),						
						[JobID] = MIN(J.JobID)
					FROM
						' + @JournalTable + ' J
						INNER JOIN #Entity_Book EB ON EB.[Entity] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[FiscalYear] = J.[FiscalYear] AND EB.FiscalPeriod = J.[FiscalPeriod]
					WHERE
						' + CASE WHEN @JournalID IS NOT NULL THEN 'J.[JournalID] = ' + CONVERT(nvarchar(15), @JournalID) + ' AND' ELSE '' END + '
						J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						J.[JournalSequence] = ''' + @JournalSequence + ''' AND
						J.[JournalNo] = ''' + @JournalNo + ''' AND
						' + CASE WHEN @Group IS NULL OR @Group = 'NONE' THEN 'J.[ConsolidationGroup] IS NULL' ELSE 'J.[ConsolidationGroup] = ''' + @Group + '''' END + '
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
					[Credit] [FLOAT],
					[JobID] [int]
					)
			
/*				SET @SQLStatement = '
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
						[Debit] = CASE WHEN J.[ConsolidationGroup] IS NULL THEN J.[ValueDebit_Book] ELSE J.[ValueDebit_Group] END,
						[Credit] = CASE WHEN J.[ConsolidationGroup] IS NULL THEN J.[ValueCredit_Book] ELSE J.[ValueCredit_Group] END
					FROM
						' + @JournalTable + ' J
					WHERE
						J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						J.[Entity] = ''' + @Entity + ''' AND
						J.[Book] = ''' + @Book + ''' AND
						J.[FiscalYear] = ' + CONVERT(nvarchar(15), @FiscalYear) + ' AND
						J.[FiscalPeriod] = ' + CONVERT(nvarchar(15), @FiscalPeriod) + ' AND
						J.[JournalSequence] = ''' + @JournalSequence + ''' AND
						J.[JournalNo] = ''' + @JournalNo + ''' AND
						J.[JournalLine] <> -1 AND
						J.[TransactionTypeBM] & 16 > 0 AND
						' + CASE WHEN @Group IS NULL OR @Group = 'NONE' THEN 'J.[ConsolidationGroup] IS NULL' ELSE 'J.[ConsolidationGroup] = ''' + @Group + '''' END
*/

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
						[Credit],
						[JobID]
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
						[Debit] = CASE WHEN J.[ConsolidationGroup] IS NULL THEN ISNULL(J.[ValueDebit_Book], J.[ValueDebit_Transaction]) ELSE J.[ValueDebit_Group] END,
						[Credit] = CASE WHEN J.[ConsolidationGroup] IS NULL THEN ISNULL(J.[ValueCredit_Book], J.[ValueCredit_Transaction]) ELSE J.[ValueCredit_Group] END,
						[JobID] = J.[JobID]
					FROM
						' + @JournalTable + ' J
						INNER JOIN #Entity_Book EB ON EB.[Entity] = J.[Entity] AND EB.[Book] = J.[Book] AND EB.[FiscalYear] = J.[FiscalYear] AND EB.FiscalPeriod = J.[FiscalPeriod]
					WHERE
						J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						J.[JournalSequence] = ''' + @JournalSequence + ''' AND
						J.[JournalNo] = ''' + @JournalNo + ''' AND
						J.[JournalLine] <> -1 AND
						J.[TransactionTypeBM] & 16 > 0 AND
						' + CASE WHEN @Group IS NULL OR @Group = 'NONE' THEN 'J.[ConsolidationGroup] IS NULL' ELSE 'J.[ConsolidationGroup] = ''' + @Group + '''' END

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				IF @DebugBM & 2 > 0 SELECT TempTable = '#JournalLine', * FROM #JournalLine
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
					[Credit] = CASE WHEN JL.[Credit] = 0 THEN '' ELSE JL.[Credit] END,
					[JobID] = JL.[JobID]
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
					[Entity] = SL.[Entity],
					[Book] = SL.[Book],
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
					SL.[Entity],
					SL.[Book],
					SL.[SegmentNo]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get Journal List'
		IF @ResultTypeBM & 32 > 0
			BEGIN
/*
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
						--J.[JournalSequence] IN (''CONS'', ''IFRS16'', ''GROUPADJ'') AND
						J.[TransactionTypeBM] IN (0, 16) AND
						J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						J.[Entity] = ''' + @Entity + ''' AND
						J.[Book] = ''' + @Book + ''' AND
						' + CASE WHEN @Group IS NULL OR @Group = 'NONE' THEN 'J.[ConsolidationGroup] IS NULL' ELSE 'J.[ConsolidationGroup] = ''' + @Group + '''' END + '
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
*/

				SET @SQLStatement = '
					SELECT TOP 1000
						[ResultTypeBM] = 32,
						[Group] = MAX(CASE WHEN J.[ConsolidationGroup] IS NULL THEN ''NONE'' ELSE J.[ConsolidationGroup] END),
						[Entity] = J.[Entity],
						[Book] = J.[Book],
						[JournalID] = MIN(J.[JournalID]),
						[JournalSequence] = J.[JournalSequence],
						[JournalNo] = J.[JournalNo],
						[TransactionDate] = MAX(J.[TransactionDate]),
						[FiscalYear] = J.[FiscalYear],
						[FiscalPeriod] = MAX(J.[FiscalPeriod]),
						[Description_Head] = MAX(J.[Description_Head]),
						[Posted] = CONVERT(bit, MAX(CONVERT(int, J.[PostedStatus]))),
						[JobID] = MAX(J.[JobID])
					FROM
						' + @JournalTable + ' J
						INNER JOIN #Entity_Book EB ON EB.[Entity] = J.[Entity] AND EB.[Book] = J.[Book] AND (EB.[FiscalYear] = J.[FiscalYear] OR EB.[FiscalYear]  IS NULL)
					WHERE
						--J.[JournalSequence] IN (''CONS'', ''IFRS16'', ''GROUPADJ'') AND
						J.[TransactionTypeBM] IN (0, 16) AND
						J.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
						' + CASE WHEN @Group IS NULL OR @Group = 'NONE' THEN 'J.[ConsolidationGroup] IS NULL' ELSE 'J.[ConsolidationGroup] = ''' + @Group + '''' END + '
						' + CASE WHEN @JournalSequence IS NOT NULL THEN ' AND J.[JournalSequence] = ''' + @JournalSequence + '''' ELSE '' END + '						
						' + CASE WHEN @JournalNo IS NOT NULL THEN ' AND J.[JournalNo] = ''' + @JournalNo + '''' ELSE '' END + '
						' + CASE WHEN @JournalJobID IS NOT NULL THEN ' AND J.[JobID] = ' + CONVERT(nvarchar(15), @JournalJobID) + '' ELSE '' END + '
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
				/*
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
				*/
				
				SET @SQLStatement = '
					SELECT DISTINCT
						[ResultTypeBM] = 64,
						[JournalSequence],
						[Description] = [JournalSequence]
					FROM
						' + @JournalTable + ' J
					WHERE
						TransactionTypeBM IN (0, 16) AND
						' + CASE WHEN @Group IS NULL OR @Group = 'NONE' THEN 'J.[ConsolidationGroup] IS NULL' ELSE 'J.[ConsolidationGroup] = ''' + @Group + '''' END

				EXEC (@SQLStatement)

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

	SET @Step = 'Drop temp tables'
		DROP TABLE #FiscalPeriod
		drop TABLE #Entity_Book

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
