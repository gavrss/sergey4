SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Segment_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL,
	@SourceTypeID int = NULL,
	@SourceDatabase nvarchar(100) = NULL,
	@SequenceBMStep int = 65535, --1 = Parent level, 2 = Leaf level
	@StaticMemberYN bit = 1,
	@MappingTypeID int = NULL,
	@NumberHierarchy int = 0,
	@ETLDatabase nvarchar(100) = NULL,
	@ReplaceStringYN bit = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000668,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_Dim_Segment_Raw] @UserID = -10, @InstanceID = 586, @VersionID = 1087, 
@DimensionID = 5708, @SourceTypeID = 11, @SourceDatabase = 'DSPSOURCE01.pcSource_JDT', @DebugBM = 15

EXEC [spIU_Dim_Segment_Raw] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @DimensionID = 5758, @SourceTypeID = 11, @DebugBM = 3, @SourceDatabase = 'DSPSOURCE01.CCM_E10'
EXEC [spIU_Dim_Segment_Raw] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @DimensionID = 5758, @SourceTypeID = 11, @DebugBM = 3, @SourceDatabase = 'DSPSOURCE01.pcSource_CALO'
EXEC [spIU_Dim_Segment_Raw] @UserID = -10, @InstanceID = 523, @VersionID = 1051, @DimensionID = 5412, @SourceTypeID = 11, @NumberHierarchy = 8, @DebugBM = 4, @SourceDatabase = 'DSPSOURCE01.pcSource_SUFS'
EXEC [spIU_Dim_Segment_Raw] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @DimensionID = 1001, @SourceTypeID = 3, @NumberHierarchy = 8, @DebugBM = 4, @SourceDatabase = 'ScaSystemDB'
EXEC [spIU_Dim_Segment_Raw] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @DimensionID = 1003, @SourceTypeID = 3, @DebugBM = 3

EXEC [spIU_Dim_Segment_Raw] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceTypeName nvarchar(50),
	@SourceTypeBM int,
	@SQLStatement nvarchar(max),
	@SourceID int,
	@DimensionName nvarchar(50),
	@Owner nvarchar(3),
	@ModelBM int,
	@Step_ProcedureName nvarchar(100),
	@Entity nvarchar(50),
	@Priority int,
	@SourceCode nvarchar(50),
	@TableName nvarchar(255),
	@SourceTable nvarchar(100),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get list of Financial Segments from Source system',
			@MandatoryParameter = 'DimensionID|SourceTypeID|SourceDatabase' --Without @, separated by |

		IF @Version = '2.0.3.2153' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'
		IF @Version = '2.1.0.2159' SET @Description = 'Handle priority order and MappingTypeID.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added [Entity] property for MappingTypeID 1 & 2.'
		IF @Version = '2.1.0.2164' SET @Description = 'Handle number hierarchy.'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle iScala.'
		IF @Version = '2.1.1.2168' SET @Description = 'Modified IF-ELSE for SourceType iScala. Handle SIE4.'
		IF @Version = '2.1.1.2169' SET @Description = 'Added LTRIM(RTRIM( for iScala. Changed default Priority to 99999999. Check @ReplaceStringYN.'
		IF @Version = '2.1.1.2171' SET @Description = 'Modified INSERT query for iScala - use of [dbo].[f_ReplaceString] for [MemberKey].'
		IF @Version = '2.1.1.2173' SET @Description = 'Removed ELSE-IF statements for @SourceTypeIDs not yet implemented.'
		IF @Version = '2.1.1.2175' SET @Description = 'Handle @SourceTypeID = 12 Enterprise/E7.'
		IF @Version = '2.1.2.2187' SET @Description = 'Handle MappingTypeIDs.'
		IF @Version = '2.1.2.2199' SET @Description = 'For iScala, filter on [Journal_SegmentNo].[SelectYN] <> 0 when inserting into #SegmentTable.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
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
			@DimensionName = DimensionName
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension]
		WHERE
			InstanceID = @InstanceID AND
			DimensionID = @DimensionID

		SELECT
			@SourceTypeName = SourceTypeName,
			@SourceTypeBM = SourceTypeBM
		FROM
			pcINTEGRATOR.dbo.SourceType
		WHERE
			SourceTypeID = @SourceTypeID

		SELECT
			@SourceID = S.[SourceID]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Source] S
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Model] M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = S.[VersionID] AND M.[ModelID] = S.[ModelID] AND M.ModelBM & 64 > 0 AND M.[SelectYN] <> 0
		WHERE
			S.[InstanceID] = @InstanceID AND
			S.[VersionID] = @VersionID AND
			S.[SourceTypeID] = @SourceTypeID AND
			S.[SelectYN] <> 0

		SET @Owner = CASE WHEN @SourceTypeID = 11 THEN 'erp' ELSE 'dbo' END

		SELECT
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID),
			@ReplaceStringYN = ISNULL(@ReplaceStringYN, ReplaceStringYN)
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF @ETLDatabase IS NULL
			SELECT
				@ETLDatabase = ISNULL(@ETLDatabase, A.[ETLDatabase])
			FROM
				pcINTEGRATOR_Data.dbo.[Application] A
			WHERE
				A.InstanceID = @InstanceID AND
				A.VersionID = @VersionID AND
				A.SelectYN <> 0
		
		IF OBJECT_ID(N'TempDB.dbo.#Segment_Members', N'U') IS NULL SET @CalledYN = 0

		IF @DebugBM & 2 > 0
			SELECT
				[@SourceDatabase] = @SourceDatabase,
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@SourceTypeID] = @SourceTypeID,
				[@SourceTypeName] = @SourceTypeName,
				[@SourceTypeBM] = @SourceTypeBM,
				[@MappingTypeID] = @MappingTypeID,
				[@ReplaceStringYN] = @ReplaceStringYN,
				[@CalledYN] = @CalledYN,
				[@ETLDatabase] = @ETLDatabase,
				[@SourceID] = @SourceID,
				[@JobID] = @JobID

	SET @Step = 'Create temp table #Segment_Members_Raw'
		CREATE TABLE #Segment_Members_Raw
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[MemberKeyBase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Priority] int,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #NumberHierarchy'
		CREATE TABLE #NumberHierarchy
			(
			[MemberKeyBase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #SegmentTable'
		CREATE TABLE #SegmentTable
			(
			[TableName] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Entity_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[FiscalYear] int,
			[Priority] int,
			[SourceCode] nvarchar(255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create #EB (Entity/Book)'
		IF OBJECT_ID(N'TempDB.dbo.#EB', N'U') IS NULL
			BEGIN
				SELECT DISTINCT
					[InstanceID] = E.[InstanceID],
					[VersionID] = E.[VersionID],
					[EntityID] = E.[EntityID],
					[Entity] = E.[MemberKey],
					[EntityName] = E.[EntityName],
					B.Book,
					B.COA,
					[Priority] = CONVERT(int, ISNULL(E.[Priority], 99999999))
				INTO
					#EB
				FROM
					[pcINTEGRATOR_Data].[dbo].[Entity] E
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] B ON B.[InstanceID] = E.InstanceID AND B.[VersionID] = E.VersionID AND B.EntityID = E.EntityID AND B.BookTypeBM & 1 > 0 AND B.SelectYN <> 0
				WHERE
					E.[InstanceID] = @InstanceID AND
					E.[VersionID] = @VersionID AND
					E.[SelectYN] <> 0

				IF @DebugBM & 2 > 0 SELECT TempTable = '#EB', * FROM #EB
				IF @DebugBM & 16 > 0 SELECT ConsumedTime = CONVERT(time(7), GetDate() - @StartTime)
			END

	SET @Step = 'Fill temptable #Segment_Members_Raw, Entity level'
		IF @MappingTypeID IN (1, 2)
			BEGIN
				INSERT INTO #Segment_Members_Raw
					(
					[MemberKey],
					[Description],
					[NodeTypeBM],
					[Source],
					[Parent],
					[Priority],
					[Entity]
					)
				SELECT DISTINCT
					--[MemberKey] = 'E_' + E.[Entity],
					[MemberKey] = E.[Entity],
					[Description] = E.[EntityName],
					[NodeTypeBM] = 18,
					[Source] = 'ETL',
					[Parent] = 'All_',
					[Priority] = E.[Priority],
					[Entity] = E.[Entity]
				FROM
					#EB E
			END

	SET @Step = 'Create temp table #MappedMemberKey'
		CREATE TABLE #MappedMemberKey
			(
			[Entity] [nvarchar](50) COLLATE DATABASE_DEFAULT,
			[MemberKeyFrom] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[MemberKeyTo] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[MappedMemberKey] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[MappedDescription] [nvarchar](255) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #MappedMemberKey
			(
			[Entity],
			[MemberKeyFrom],
			[MemberKeyTo],
			[MappedMemberKey],
			[MappedDescription]
			)
		SELECT 
			[Entity] = [Entity_MemberKey],
			[MemberKeyFrom],
			[MemberKeyTo],
			[MappedMemberKey],
			[MappedDescription]
		FROM
			[pcINTEGRATOR_Data].[dbo].[MappedMemberKey]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[DimensionID] = @DimensionID AND
			[MappingTypeID] = 3 AND
			[SelectYN] <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#MappedMemberKey', * FROM #MappedMemberKey

	SET @Step = 'Fill temptable #Segment_Members_Raw'
		IF @SourceTypeID IN (1, 11) --Epicor ERP (E9, E10)
			BEGIN
				IF @SequenceBMStep & 1 > 0 --Segment Parents
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #Segment_Members_Raw
								(
								[MemberKey],
								[Description],
								[NodeTypeBM],
								[Source],
								[Parent],
								[Priority],
								[Entity]
								)
							SELECT
								[MemberKey] = COASV.[RefEntityType] COLLATE DATABASE_DEFAULT,
--								[Description] = MAX(ISNULL(CASE WHEN COASV.GLCOARefTypeRefTypeDEsc = '''' THEN NULL ELSE COASV.GLCOARefTypeRefTypeDesc END, COASV.RefEntityType)) COLLATE DATABASE_DEFAULT,
								[Description] = MAX(COASV.[RefEntityType]) COLLATE DATABASE_DEFAULT,
								[NodeTypeBM] = 18,
								[Source] = ''' + @SourceTypeName + ''',
--								[Parent] = ''All_'',
								--[Parent] =  ' + CASE WHEN @MappingTypeID IN (1, 2) THEN '''E_'' + EB.Entity' ELSE '''All_''' END + ',
								[Parent] =  ' + CASE WHEN @MappingTypeID IN (1, 2) THEN 'EB.Entity' ELSE '''All_''' END + ',
								[Priority] = MAX(EB.[Priority]),
								[Entity] = EB.[Entity]
							FROM
								' + @SourceDatabase + '.[' + @Owner + '].[COASegValues] COASV
								INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB ON GLB.Company = COASV.Company AND GLB.COACode = COASV.COACode
								INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COASegment] COAS ON COAS.Company = GLB.Company AND COAS.COACode = GLB.COACode AND COAS.SegmentNbr = COASV.SegmentNbr
								INNER JOIN #EB EB ON EB.Entity = GLB.Company COLLATE DATABASE_DEFAULT AND EB.Book = GLB.BookID COLLATE DATABASE_DEFAULT AND EB.COA = GLB.COACode COLLATE DATABASE_DEFAULT
								INNER JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.InstanceID = EB.InstanceID AND JSN.VersionID = EB.VersionID AND JSN.EntityID = EB.EntityID AND JSN.Book = EB.Book AND JSN.DimensionID = ' + CONVERT(nvarchar(15), @DimensionID) + '  AND JSN.SegmentCode = COAS.SegmentName COLLATE DATABASE_DEFAULT AND JSN.SelectYN <> 0
							WHERE
								LEN(COASV.[RefEntityType]) > 0
							GROUP BY
								EB.[Entity],
								COASV.RefEntityType'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
						SET @Selected = @Selected + @@ROWCOUNT
						
						IF @DebugBM & 16 > 0 SELECT ConsumedTime = CONVERT(time(7), GetDate() - @StartTime)
					END

				IF @SequenceBMStep & 2 > 0 --Segment Leafs
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #Segment_Members_Raw
								(
								[MemberKey],
								[Description],
								[NodeTypeBM],
								[Source],
								[Parent],
								[Priority],
								[Entity]
								)
							SELECT
								[MemberKey] = COASV.SegmentCode COLLATE DATABASE_DEFAULT,
								[Description] = ISNULL(CASE WHEN COASV.SegmentName = '''' THEN NULL ELSE COASV.SegmentName END, COASV.SegmentCode) COLLATE DATABASE_DEFAULT,
								[NodeTypeBM] = 1,
								[Source] = ''' + @SourceTypeName + ''',
--								[Parent] = CASE WHEN LEN(COASV.[RefEntityType]) > 0 THEN COASV.[RefEntityType] ELSE ''All_'' END,
								--[Parent] = CASE WHEN LEN(COASV.[RefEntityType]) > 0 THEN COASV.[RefEntityType] ELSE ' + CASE WHEN @MappingTypeID IN (1, 2) THEN '''E_'' + EB.Entity' ELSE '''All_''' END + ' END,
								[Parent] = CASE WHEN LEN(COASV.[RefEntityType]) > 0 THEN COASV.[RefEntityType] ELSE ' + CASE WHEN @MappingTypeID IN (1, 2) THEN 'EB.Entity' ELSE '''All_''' END + ' END,
								[Priority] = EB.[Priority],
								[Entity] = EB.[Entity]
							FROM
								' + @SourceDatabase + '.[' + @Owner + '].[COASegValues] COASV
								INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] GLB ON GLB.Company = COASV.Company AND GLB.COACode = COASV.COACode
								INNER JOIN ' + @SourceDatabase + '.[' + @Owner + '].[COASegment] COAS ON COAS.Company = GLB.Company AND COAS.COACode = GLB.COACode AND COAS.SegmentNbr = COASV.SegmentNbr
								INNER JOIN #EB EB ON EB.Entity = GLB.Company COLLATE DATABASE_DEFAULT AND EB.Book = GLB.BookID COLLATE DATABASE_DEFAULT AND EB.COA = GLB.COACode COLLATE DATABASE_DEFAULT
								INNER JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.InstanceID = EB.InstanceID AND JSN.VersionID = EB.VersionID AND JSN.EntityID = EB.EntityID AND JSN.Book = EB.Book AND JSN.DimensionID = ' + CONVERT(nvarchar(15), @DimensionID) + '  AND JSN.SegmentCode = COAS.SegmentName COLLATE DATABASE_DEFAULT AND JSN.SelectYN <> 0'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
						SET @Selected = @Selected + @@ROWCOUNT
						
						IF @DebugBM & 16 > 0 SELECT ConsumedTime = CONVERT(time(7), GetDate() - @StartTime)
					END
			END

		ELSE IF @SourceTypeID IN (3) --iScala
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #SegmentTable
						(
						[TableName],
						[Entity_MemberKey],
						[FiscalYear],
						[Priority],
						[SourceCode]
						)
					SELECT
						wST.[TableName],
						wST.[Entity_MemberKey],
						wST.[FiscalYear],
						wST.[Priority],
						JSN.[SourceCode]
					FROM
						' + @ETLDatabase + '.[dbo].[wrk_SourceTable] wST
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND E.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND E.MemberKey = wST.[Entity_MemberKey] AND E.SelectYN <> 0
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.InstanceID = E.InstanceID AND JSN.VersionID = E.VersionID AND JSN.EntityID = E.EntityID AND JSN.Book = ''GL'' AND JSN.DimensionID = ' + CONVERT(nvarchar(15), @DimensionID) + ' AND JSN.SelectYN <> 0
					WHERE
						wST.TableCode = ''GL03'' AND
						wST.SourceID = ' + CONVERT(nvarchar(15), @SourceID)

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#SegmentTable', * FROM #SegmentTable ORDER BY [Priority], [FiscalYear] DESC, [Entity_MemberKey]

				IF CURSOR_STATUS('global','SegmentTable_Cursor') >= -1 DEALLOCATE SegmentTable_Cursor
				DECLARE SegmentTable_Cursor CURSOR FOR
			
					SELECT
						[TableName],
						[SourceCode],
						[Entity_MemberKey],
						[Priority]
					FROM
						#SegmentTable
					ORDER BY
						[Priority],
						[FiscalYear] DESC,
						[Entity_MemberKey]

					OPEN SegmentTable_Cursor
					FETCH NEXT FROM SegmentTable_Cursor INTO @TableName, @SourceCode, @Entity, @Priority

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@TableName] = @TableName, [@SourceCode] = @SourceCode, [@Entity] = @Entity, [@Priority] = @Priority

							IF @SequenceBMStep & 2 > 0 --Segment Leafs
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #Segment_Members_Raw
											(
											[MemberKey],
											[Description],
											[NodeTypeBM],
											[Source],
											[Parent],
											[Priority],
											[Entity]
											)
										SELECT
											--[MemberKey] = LTRIM(RTRIM(REPLACE([glseg].[GL03002], CHAR(9), ''''))) COLLATE DATABASE_DEFAULT,
											[MemberKey] = LTRIM(RTRIM(CASE WHEN ' + CONVERT(NVARCHAR(5), @ReplaceStringYN) + ' = 0 THEN [glseg].[GL03002] ELSE [dbo].[f_ReplaceString](' + CONVERT(NVARCHAR(15),@InstanceID) + ', ' + CONVERT(NVARCHAR(15),@VersionID) + ',[glseg].[GL03002],1) END)) COLLATE DATABASE_DEFAULT,
											[Description] = LTRIM(RTRIM(MAX(CASE WHEN [glseg].[GL03003] IS NULL OR [glseg].[GL03003] = '''' THEN [glseg].[GL03002] ELSE [glseg].[GL03003] END))), 
											[NodeTypeBM] = 1,
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] = ''ToBeSet'',
											[Priority] = ' + CONVERT(nvarchar(15), @Priority) + ',
											[Entity] = ''' + @Entity + '''
										FROM
											' + @TableName  + ' [glseg]
										WHERE
											[glseg].[GL03001] = ''' + @SourceCode + ''' AND
											[glseg].[GL03002] <> '''' AND [glseg].[GL03002] IS NOT NULL AND
											NOT EXISTS (SELECT 1 FROM #Segment_Members_Raw SMR WHERE SMR.[MemberKey] = LTRIM(RTRIM(CASE WHEN ' + CONVERT(NVARCHAR(5), @ReplaceStringYN) + ' = 0 THEN [glseg].[GL03002] ELSE [dbo].[f_ReplaceString](' + CONVERT(NVARCHAR(15),@InstanceID) + ', ' + CONVERT(NVARCHAR(15),@VersionID) + ',[glseg].[GL03002],1) END)) COLLATE DATABASE_DEFAULT AND SMR.[Entity] = ''' + @Entity + ''')
										GROUP BY
											LTRIM(RTRIM(CASE WHEN ' + CONVERT(NVARCHAR(5), @ReplaceStringYN) + ' = 0 THEN [glseg].[GL03002] ELSE [dbo].[f_ReplaceString](' + CONVERT(NVARCHAR(15),@InstanceID) + ', ' + CONVERT(NVARCHAR(15),@VersionID) + ',[glseg].[GL03002],1) END)) COLLATE DATABASE_DEFAULT'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Selected = @Selected + @@ROWCOUNT
						
									IF @DebugBM & 16 > 0 SELECT ConsumedTime = CONVERT(Time(7), GetDate() - @StartTime)
								END
						
								FETCH NEXT FROM SegmentTable_Cursor INTO @TableName, @SourceCode, @Entity, @Priority
						END	
					CLOSE SegmentTable_Cursor
					DEALLOCATE SegmentTable_Cursor
			END

		ELSE IF @SourceTypeID IN (7) --SIE4
			BEGIN
				INSERT INTO #Segment_Members_Raw
					(
					[MemberKey],
					[Description],
					[NodeTypeBM],
					[Source],
					[Parent],
					[Priority],
					[Entity]
					)
				SELECT
					[MemberKey] = O.ObjectCode,
					[Description] = O.ObjectName,
					[NodeTypeBM] = 1,
					[Source] = @SourceTypeName,
					[Parent] = 'All_',
					[Priority] = CONVERT(int, ISNULL(E.[Priority], 99999999)),
					[Entity] = E.[MemberKey]
				FROM
					pcINTEGRATOR_Data..[SIE4_Job] J
					INNER JOIN pcINTEGRATOR_Data..[Entity] E ON E.InstanceID = @InstanceID AND E.VersionID = @VersionID AND E.EntityID = J.EntityID
					INNER JOIN pcINTEGRATOR_Data..[Journal_SegmentNo] JSN ON JSN.InstanceID = E.InstanceID AND JSN.VersionID = E.VersionID AND JSN.EntityID = E.EntityID AND JSN.DimensionID = @DimensionID
					INNER JOIN pcINTEGRATOR_Data..[SIE4_Object] O ON O.[JobID] = J.[JobID] AND O.[Param] = '#OBJEKT' AND O.DimCode = JSN.SegmentCode
				WHERE
					J.JobID = @JobID

				SET @Selected = @Selected + @@ROWCOUNT
						
				IF @DebugBM & 16 > 0 SELECT ConsumedTime = CONVERT(time(7), GetDate() - @StartTime)
			END

		ELSE IF @SourceTypeID = 12 --Enterprise (E7)
			BEGIN
				SET @Step = 'Create and Fill #Entity_SourceTable'
					CREATE TABLE #Entity_SourceTable
						(
						Entity_MemberKey nvarchar(50),
						Segment nvarchar(10),
						SourceTable nvarchar(100),
						MappingTypeID int,
						[Priority] int
						)

					SET @SQLStatement = '
						INSERT INTO #Entity_SourceTable
							(
							Entity_MemberKey,
							Segment,
							SourceTable,
							MappingTypeID,
							[Priority]
							)
						SELECT DISTINCT
							[Entity_MemberKey] = E.Entity,
							Segment = CONVERT(nvarchar(10), JSN.SegmentNo),
							SourceTable = EPV.EntityPropertyValue + ''.[dbo].[glseg'' + SUBSTRING(JSN.SourceCode, 4, CHARINDEX(''_code'', JSN.SourceCode) - 4) + '']'',
							MappingTypeID = ' + CONVERT(NVARCHAR(15), @MappingTypeID) + ',
							[Priority] = ISNULL(E.[Priority], 99999999)
						FROM
							#EB E
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.InstanceID = E.InstanceID AND JSN.VersionID = E.VersionID AND JSN.EntityID = E.EntityID AND JSN.DimensionID = ' + CONVERT(NVARCHAR(15), @DimensionID) + '
							INNER JOIN [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV ON EPV.InstanceID = E.InstanceID AND EPV.VersionID = E.VersionID AND EPV.EntityID = E.EntityID AND EPV.EntityPropertyTypeID = -1
						ORDER BY
							[Priority]'

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					IF @Debug <> 0 SELECT TempTable = '#Entity_SourceTable', * FROM #Entity_SourceTable

				IF CURSOR_STATUS('global','SourceTable_Cursor') >= -1 DEALLOCATE SourceTable_Cursor
				DECLARE SourceTable_Cursor CURSOR FOR
					SELECT
						Entity_MemberKey,
						SourceTable,
						[Priority]
					FROM
						#Entity_SourceTable
					ORDER BY
						[Priority]

					OPEN SourceTable_Cursor
					FETCH NEXT FROM SourceTable_Cursor INTO @Entity, @SourceTable, @Priority

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@Entity] = @Entity, [@SourceTable] = @SourceTable, [@Priority] = @Priority

							IF @SequenceBMStep & 2 > 0 --Segment Leafs
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #Segment_Members_Raw
											(
											[MemberKey],
											[Description],
											[NodeTypeBM],
											[Source],
											[Parent],
											[Priority],
											[Entity]
											)
										SELECT
											[MemberKey] = [glseg].[seg_code] COLLATE DATABASE_DEFAULT,
											[Description] = MAX(CASE WHEN [glseg].[short_desc] = '''' THEN [glseg].[description] ELSE [glseg].[short_desc] END COLLATE DATABASE_DEFAULT), 
											[NodeTypeBM] = 1,
											[Source] = ''' + @SourceTypeName + ''',
											[Parent] = ''All_'',
											[Priority] = ' + CONVERT(nvarchar(15), @Priority) + ',
											[Entity] = ''' + @Entity + '''
										FROM
											' + @SourceTable  + ' [glseg]
										WHERE
											NOT EXISTS (SELECT 1 FROM #Segment_Members_Raw SMR WHERE SMR.[MemberKey] = [glseg].[seg_code] COLLATE DATABASE_DEFAULT AND SMR.[Entity] = ''' + @Entity + ''')
										GROUP BY
											[glseg].[seg_code] COLLATE DATABASE_DEFAULT'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
									SET @Selected = @Selected + @@ROWCOUNT
						
									IF @DebugBM & 16 > 0 SELECT ConsumedTime = CONVERT(Time(7), GetDate() - @StartTime)
								END
						
								FETCH NEXT FROM SourceTable_Cursor INTO @Entity, @SourceTable, @Priority
						END	
					CLOSE SourceTable_Cursor
					DEALLOCATE SourceTable_Cursor

				DROP TABLE #Entity_SourceTable
			END

		--ELSE IF @SourceTypeID = 8 --Navision
		--	BEGIN
		--		SET @Message = 'Code for Navision is not yet implemented.'
		--		SET @Severity = 16
		--		GOTO EXITPOINT
		--	END

		--ELSE IF @SourceTypeID = 9 --Axapta
		--	BEGIN
		--		SET @Message = 'Code for Axapta is not yet implemented.'
		--		SET @Severity = 16
		--		GOTO EXITPOINT
		--	END

		--ELSE IF @SourceTypeID = 15 --pcSource
		--	BEGIN
		--		SET @Message = 'Code for pcSource is not yet implemented.'
		--		SET @Severity = 16
		--		GOTO EXITPOINT
		--	END

		--ELSE
		--	BEGIN
		--		SET @Message = 'Code for selected SourceTypeID (' + CONVERT(nvarchar(15), @SourceTypeID) + ') is not yet implemented.'
		--		SET @Severity = 16
		--		GOTO EXITPOINT
		--	END

	SET @Step = 'Handle NumberHierarchy'
		IF @NumberHierarchy <> 0
			BEGIN
				EXEC [spGet_NumberHierarchy] 
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@MappingTypeID = @MappingTypeID,
					@NumberHierarchy = @NumberHierarchy,
					@SourceTable = '#Segment_Members_Raw',
					@JobID = @JobID,
					@Debug = @DebugSub

				UPDATE SMR 
				SET
					[MemberKey] = NH.[MemberKey],
					[MemberKeyBase] = NH.[MemberKeyBase],
					[Parent] = NH.[Parent]
				FROM
					#Segment_Members_Raw SMR
					INNER JOIN #NumberHierarchy NH ON NH.MemberKeyBase = SMR.MemberKey AND NH.[NodeTypeBM] & 1 > 0
				WHERE
					SMR.[NodeTypeBM] & 1 > 0

				INSERT INTO #Segment_Members_Raw
					(
					[MemberKey],
					[Description],
					[MemberKeyBase],
					[NodeTypeBM],
					[Source],
					[Parent],
					[Priority],
					[Entity]
					)
				SELECT
					[MemberKey],
					[Description] = CASE WHEN NH.[MemberKey] = EB.[Entity] THEN EB.[EntityName] ELSE NH.[MemberKey] END,
					[MemberKeyBase],
					[NodeTypeBM],
					[Source] = 'ETL',
					[Parent],
					[Priority] = EB.[Priority],
					[Entity] = EB.[Entity]
				FROM
					#NumberHierarchy NH
					INNER JOIN (SELECT [Entity], [EntityName] = MAX([EntityName]), [Priority] = MIN([Priority]) FROM #EB GROUP BY [Entity]) EB ON EB.[Entity] = NH.[Entity]
				WHERE
					NH.[NodeTypeBM] & 2 > 0
			END

	SET @Step = 'Get default members'
		IF @StaticMemberYN <> 0
			BEGIN
				SELECT
					@ModelBM = SUM(ModelBM)
				FROM
					(SELECT DISTINCT ModelBM FROM pcINTEGRATOR_Data..DataClass WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SelectYN <> 0 AND DEletedID IS NULL) sub
				
				INSERT INTO #Segment_Members_Raw
					(
					[MemberId],
					[MemberKey],
					[Description],
					[HelpText],
					[NodeTypeBM],
					[Source],
					[Parent],
					[Priority],
					[Entity]
					)
				SELECT 
					[MemberId] = M.[MemberId],
					[MemberKey] = MAX(M.[Label]),
					[Description] = MAX(REPLACE(M.[Description], '@All_Dimension', 'All ' + CASE WHEN RIGHT(@DimensionName, 1) = 'y' THEN LEFT(@DimensionName, LEN(@DimensionName) - 1) + 'ie' ELSE @DimensionName END + 's')),
					[HelpText] = MAX(M.[HelpText]),
					[NodeTypeBM] = MAX(M.[NodeTypeBM]),
					[Source] = 'ETL',
					[Parent] = MAX(M.[Parent]),
					[Priority] = -999999,
					[Entity] = ''
				FROM 
					[Member] M
					LEFT JOIN [Member_Property_Value] MPV ON MPV.[DimensionID] = M.[DimensionID] AND MPV.[MemberId] = M.[MemberId]
				WHERE
					M.[DimensionID] IN (0, @DimensionID) AND
					M.[SourceTypeBM] & @SourceTypeBM > 0 AND
					M.[ModelBM] & @ModelBM > 0
				GROUP BY
					M.[MemberId]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#Segment_Members_Raw',
					*
				FROM
					#Segment_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END, [Priority], [Entity] 

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				IF CURSOR_STATUS('global','Account_Members_Cursor') >= -1 DEALLOCATE Account_Members_Cursor
				DECLARE Account_Members_Cursor CURSOR FOR
			
					SELECT DISTINCT
						[Entity],
						[Priority]
					FROM
						(
						SELECT DISTINCT
							[Entity] = '',
							[Priority] = -999999
						UNION SELECT DISTINCT
							[Entity],
							[Priority]
						FROM
							#EB
						) sub
					ORDER BY
						sub.[Priority],
						sub.[Entity]

					OPEN Account_Members_Cursor
					FETCH NEXT FROM Account_Members_Cursor INTO @Entity, @Priority

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@Entity] = @Entity, [@Priority] = @Priority

							INSERT INTO [#Segment_Members]
								(
								[MemberId],
								[MemberKey],
								[Description],
								[HelpText],
								[MemberKeyBase],
								[Entity],
								[NodeTypeBM],
								[SBZ],
								[Source],
								[Synchronized],
								[Parent]
								)
							SELECT TOP 1000000
								[MemberId] = ISNULL([MaxRaw].[MemberId], M.MemberID),
								[MemberKey] = CASE WHEN @ReplaceStringYN = 0 THEN [MaxRaw].[MemberKey] ELSE [dbo].[f_ReplaceString](@InstanceID,@VersionID,[MaxRaw].[MemberKey],1) END,
								[Description] = CASE WHEN @ReplaceStringYN = 0 THEN [MaxRaw].[Description] ELSE [dbo].[f_ReplaceString](@InstanceID,@VersionID,[MaxRaw].[Description],2) END,
								[HelpText] = CASE WHEN @ReplaceStringYN = 0 THEN CASE WHEN ISNULL([MaxRaw].[HelpText], '') = '' THEN [MaxRaw].[Description] ELSE [MaxRaw].[HelpText] END ELSE [dbo].[f_ReplaceString](@InstanceID,@VersionID,CASE WHEN ISNULL([MaxRaw].[HelpText], '') = '' THEN [MaxRaw].[Description] ELSE [MaxRaw].[HelpText] END,2) END,
								[MemberKeyBase] = CASE WHEN @ReplaceStringYN = 0 THEN [MaxRaw].[MemberKeyBase] ELSE [dbo].[f_ReplaceString](@InstanceID,@VersionID,[MaxRaw].[MemberKeyBase],1) END,
								[Entity] = [MaxRaw].[Entity],
								[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
								[SBZ] = [MaxRaw].[SBZ],
								[Source] = [MaxRaw].[Source],
								[Synchronized] = 1,
								[Parent] = CASE [MaxRaw].[Parent] WHEN 'NULL' THEN NULL ELSE [MaxRaw].[Parent] END
							FROM
								(
								SELECT
									[MemberId] = MAX([Raw].[MemberId]),
									[MemberKey] = CASE WHEN @MappingTypeID = 1 AND @Entity <> '' AND [Raw].[MemberKey] <> [Raw].[Entity] THEN @Entity + '_' ELSE '' END + CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END + CASE WHEN @MappingTypeID = 2 AND @Entity <> '' AND [Raw].[MemberKey] <> [Raw].[Entity] THEN '_' + @Entity ELSE '' END,
									[Description] = MAX(CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedDescription] ELSE [Raw].[Description] END),
									[HelpText] = MAX([Raw].[HelpText]),
									[MemberKeyBase] = MAX(ISNULL([Raw].[MemberKeyBase], [Raw].[MemberKey])),
									[Entity] = MAX([Raw].[Entity]),
									[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
									[SBZ] = [dbo].[f_GetSBZ2] (@DimensionID, MAX([Raw].[NodeTypeBM]), MAX([Raw].[MemberKey])),
									[Source] = MAX([Raw].[Source]),
									[Synchronized] = 1,
									[Parent] = CASE WHEN @MappingTypeID = 1 AND @Entity <> '' AND @NumberHierarchy <> 0 AND MAX([Raw].[Parent]) NOT IN ('All_', @Entity) THEN @Entity + '_' ELSE '' END + MAX([Raw].[Parent]) + CASE WHEN @MappingTypeID = 2 AND @Entity <> '' AND @NumberHierarchy <> 0 AND MAX([Raw].[Parent]) NOT IN ('All_', @Entity) THEN '_' + @Entity ELSE '' END
								--[Raw].[Parent] <> [Raw].[Entity] AND
								FROM
									[#Segment_Members_Raw] [Raw]
									LEFT JOIN #MappedMemberKey MMK ON MMK.[Entity] = [Raw].[Entity] AND [Raw].[MemberKey] BETWEEN MMK.[MemberKeyFrom] AND MMK.[MemberKeyTo]
								WHERE
									[Raw].[MemberKey] <> '' AND
									[Raw].[Entity] = @Entity AND
									[Raw].[Priority] = @Priority
								GROUP BY
									CASE WHEN @MappingTypeID = 1 AND @Entity <> '' AND [Raw].[MemberKey] <> [Raw].[Entity] THEN @Entity + '_' ELSE '' END + CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END + CASE WHEN @MappingTypeID = 2 AND @Entity <> '' AND [Raw].[MemberKey] <> [Raw].[Entity] THEN '_' + @Entity ELSE '' END
									--CASE WHEN @MappingTypeID = 3 THEN MMK.[MappedMemberKey] ELSE [Raw].[MemberKey] END
								) [MaxRaw]
								LEFT JOIN pcINTEGRATOR..Member M ON M.[DimensionID] = @DimensionID AND M.[Label] = [MaxRaw].[MemberKey]
							WHERE
								[MaxRaw].[MemberKey] IS NOT NULL AND
								NOT EXISTS (SELECT 1 FROM [#Segment_Members] AM WHERE AM.[MemberKey] = [MaxRaw].[MemberKey])
							ORDER BY
								CASE WHEN [MaxRaw].[MemberKey] IN ('All_', 'NONE') OR [MaxRaw].[MemberKey] LIKE '%NONE%' THEN '  ' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END

							FETCH NEXT FROM Account_Members_Cursor INTO @Entity, @Priority
						END

				CLOSE Account_Members_Cursor
				DEALLOCATE Account_Members_Cursor
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Segment_Members_Raw
		DROP TABLE #SegmentTable
		IF @CalledYN = 0 DROP TABLE #EB

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		SET @Step_ProcedureName = @ProcedureName + ' (' + @DimensionName + ')'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @Step_ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
