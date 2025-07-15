SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_DimensionMember_Category]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DimensionID int = NULL,
	@JSON_table nvarchar(MAX) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000802,
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
--OBS
--OBSOLETE, replaced by [spPortalSet_DimensionMember_List]

AS
/*
DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"MemberId" : "1025", "P01": "More testing"},
	{"MemberId" : "1026", "H01_MemberKey": "Cat_AE", "H02_MemberKey": "Cat_AC"},
	{"D01_MemberKey" : "ST_VM", "D02_MemberKey": "019", "D03_MemberKey": "01", "H01_MemberKey" : "Cat_AB", "H02_MemberKey": "Cat_AC", "H03_MemberKey": "Cat_AD", "P01": "Test new row"},
	{"MemberId" : "1028", "DeleteYN": "1" }
	]'

EXEC [dbo].[spPortalSet_DimensionMember_Category] 
	@UserID = -10,
	@InstanceID = 531,
	@VersionID = 1041,
	@DimensionID = 9155,
	@DebugBM = 7,
	@JSON_table = @JSON_table

EXEC [spPortalSet_DimensionMember_Category] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
--	@EntityID int,
	@SQLStatement nvarchar(max),
	@CallistoDatabase nvarchar(100),
	@DeletedID int,
	@DimensionName nvarchar(50),
	@ColumnCode nchar(3),
	@ColumnName nvarchar(50),
	@SubDimensionName nvarchar(50),
	@Punctuation nvarchar(10) = '-',
	@DescriptionPunctuation nvarchar(10) = ' - ',
	@SQL_Dimension_Insert nvarchar(1000) = '',
	@SQL_Dimension_Select nvarchar(1000) = '',
	@SQL_Property_Insert nvarchar(1000) = '',
	@SQL_Property_Select nvarchar(1000) = '',
	@HierarchyName nvarchar(100),
	@Dimensionhierarchy nvarchar(100),
	@NodeTypeBMExistsYN bit,
	@TableName nvarchar(100),

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
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Maintain leaf dimension members setting Category parents in columns.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2175' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2177' SET @Description = 'DB-724: Added update and insert of multidim dimension values. DB-725: Update Helptext. DB-734: Removed SELECT query on error information.'
		IF @Version = '2.1.2.2179' SET @Description = 'Added SortOrder in temp table #Column.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

--IF @DebugBM & 2 > 0 

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
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0

		SELECT
			@DimensionName = [DimensionName],
			@TableName = 'S_DS_' + [DimensionName]
		FROM
			[Dimension]
		WHERE
			[InstanceID] IN (0, @InstanceID) AND
			[DimensionID] = @DimensionID

		EXEC [pcINTEGRATOR].[dbo].[spGet_ColumnExistsYN]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DatabaseName = @CallistoDatabase,
			@TableName = @TableName,
			@ColumnName = 'NodeTypeBM',
			@ExistsYN  = @NodeTypeBMExistsYN OUT

		IF @DebugBM & 2 > 0
			SELECT
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@CallistoDatabase] = @CallistoDatabase,
				[@NodeTypeBMExistsYN] = @NodeTypeBMExistsYN

	SET @Step = 'Create and fill #LeafMemberTable'
		CREATE TABLE #LeafMemberTable
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[D01_MemberID] bigint,
			[D01_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D01_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D02_MemberID] bigint,
			[D02_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D02_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D03_MemberID] bigint,
			[D03_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D03_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D04_MemberID] bigint,
			[D04_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D04_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D05_MemberID] bigint,
			[D05_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D05_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D06_MemberID] bigint,
			[D06_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D06_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D07_MemberID] bigint,
			[D07_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D07_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D08_MemberID] bigint,
			[D08_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D08_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D09_MemberID] bigint,
			[D09_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D09_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D10_MemberID] bigint,
			[D10_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[D10_Description] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H00_MemberID] bigint,
			[H00_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H01_MemberID] bigint,
			[H01_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H02_MemberID] bigint,
			[H02_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H03_MemberID] bigint,
			[H03_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H04_MemberID] bigint,
			[H04_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H05_MemberID] bigint,
			[H05_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H06_MemberID] bigint,
			[H06_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H07_MemberID] bigint,
			[H07_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H08_MemberID] bigint,
			[H08_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H09_MemberID] bigint,
			[H09_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[H10_MemberID] bigint,
			[H10_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[P01] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P02] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P03] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P04] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P05] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P06] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P07] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P08] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P09] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[P10] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[DeleteYN] bit DEFAULT 0
			)			

		IF @JSON_table IS NOT NULL	
			INSERT INTO #LeafMemberTable
				(
				[MemberId],
				[MemberKey],
				[Description],
				[HelpText],
				[D01_MemberID],
				[D01_MemberKey],
				[D02_MemberID],
				[D02_MemberKey],
				[D03_MemberID],
				[D03_MemberKey],
				[D04_MemberID],
				[D04_MemberKey],
				[D05_MemberID],
				[D05_MemberKey],
				[D06_MemberID],
				[D06_MemberKey],
				[D07_MemberID],
				[D07_MemberKey],
				[D08_MemberID],
				[D08_MemberKey],
				[D09_MemberID],
				[D09_MemberKey],
				[D10_MemberID],
				[D10_MemberKey],
				[H00_MemberID],
				[H00_MemberKey],
				[H01_MemberID],
				[H01_MemberKey],
				[H02_MemberID],
				[H02_MemberKey],
				[H03_MemberID],
				[H03_MemberKey],
				[H04_MemberID],
				[H04_MemberKey],
				[H05_MemberID],
				[H05_MemberKey],
				[H06_MemberID],
				[H06_MemberKey],
				[H07_MemberID],
				[H07_MemberKey],
				[H08_MemberID],
				[H08_MemberKey],
				[H09_MemberID],
				[H09_MemberKey],
				[H10_MemberID],
				[H10_MemberKey],
				[P01],
				[P02],
				[P03],
				[P04],
				[P05],
				[P06],
				[P07],
				[P08],
				[P09],
				[P10],
				[DeleteYN]
				)
			SELECT
				[MemberId],
				[MemberKey],
				[Description],
				[HelpText],
				[D01_MemberID],
				[D01_MemberKey],
				[D02_MemberID],
				[D02_MemberKey],
				[D03_MemberID],
				[D03_MemberKey],
				[D04_MemberID],
				[D04_MemberKey],
				[D05_MemberID],
				[D05_MemberKey],
				[D06_MemberID],
				[D06_MemberKey],
				[D07_MemberID],
				[D07_MemberKey],
				[D08_MemberID],
				[D08_MemberKey],
				[D09_MemberID],
				[D09_MemberKey],
				[D10_MemberID],
				[D10_MemberKey],
				[H00_MemberID],
				[H00_MemberKey],
				[H01_MemberID],
				[H01_MemberKey],
				[H02_MemberID],
				[H02_MemberKey],
				[H03_MemberID],
				[H03_MemberKey],
				[H04_MemberID],
				[H04_MemberKey],
				[H05_MemberID],
				[H05_MemberKey],
				[H06_MemberID],
				[H06_MemberKey],
				[H07_MemberID],
				[H07_MemberKey],
				[H08_MemberID],
				[H08_MemberKey],
				[H09_MemberID],
				[H09_MemberKey],
				[H10_MemberID],
				[H10_MemberKey],
				[P01],
				[P02],
				[P03],
				[P04],
				[P05],
				[P06],
				[P07],
				[P08],
				[P09],
				[P10],
				[DeleteYN] = ISNULL([DeleteYN], 0)
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				[MemberId] bigint,
				[MemberKey] nvarchar(100),
				[Description] nvarchar(255),
				[HelpText] nvarchar(1024),
				[D01_MemberID] bigint,
				[D01_MemberKey] nvarchar(100),
				[D02_MemberID] bigint,
				[D02_MemberKey] nvarchar(100),
				[D03_MemberID] bigint,
				[D03_MemberKey] nvarchar(100),
				[D04_MemberID] bigint,
				[D04_MemberKey] nvarchar(100),
				[D05_MemberID] bigint,
				[D05_MemberKey] nvarchar(100),
				[D06_MemberID] bigint,
				[D06_MemberKey] nvarchar(100),
				[D07_MemberID] bigint,
				[D07_MemberKey] nvarchar(100),
				[D08_MemberID] bigint,
				[D08_MemberKey] nvarchar(100),
				[D09_MemberID] bigint,
				[D09_MemberKey] nvarchar(100),
				[D10_MemberID] bigint,
				[D10_MemberKey] nvarchar(100),
				[H00_MemberID] bigint,
				[H00_MemberKey] nvarchar(100),
				[H01_MemberID] bigint,
				[H01_MemberKey] nvarchar(100),
				[H02_MemberID] bigint,
				[H02_MemberKey] nvarchar(100),
				[H03_MemberID] bigint,
				[H03_MemberKey] nvarchar(100),
				[H04_MemberID] bigint,
				[H04_MemberKey] nvarchar(100),
				[H05_MemberID] bigint,
				[H05_MemberKey] nvarchar(100),
				[H06_MemberID] bigint,
				[H06_MemberKey] nvarchar(100),
				[H07_MemberID] bigint,
				[H07_MemberKey] nvarchar(100),
				[H08_MemberID] bigint,
				[H08_MemberKey] nvarchar(100),
				[H09_MemberID] bigint,
				[H09_MemberKey] nvarchar(100),
				[H10_MemberID] bigint,
				[H10_MemberKey] nvarchar(100),
				[P01] nvarchar(255),
				[P02] nvarchar(255),
				[P03] nvarchar(255),
				[P04] nvarchar(255),
				[P05] nvarchar(255),
				[P06] nvarchar(255),
				[P07] nvarchar(255),
				[P08] nvarchar(255),
				[P09] nvarchar(255),
				[P10] nvarchar(255),
				[DeleteYN] bit
				)
		ELSE
			GOTO EXITPOINT

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#LeafMemberTable_1', * FROM #LeafMemberTable

	SET @Step = 'Create and fill temp table #Column'
		CREATE TABLE #Column
			(
			[ColumnCode] nchar(3) COLLATE DATABASE_DEFAULT,
			[ColumnName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DimensionID] int,
			[DimensionName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)

		EXEC [spGet_Category_Column]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@DimensionID = @DimensionID,
			@JobID = @JobID

		IF @DebugBM & 2 > 0
			SELECT TempTable = '#Column', * FROM #Column ORDER BY [ColumnCode]

	SET @Step = 'Add new categories'
		CREATE TABLE #Category
			(
			[Category_MemberKey] nvarchar(50) COLLATE DATABASE_DEFAULT,
			)

		IF CURSOR_STATUS('global','Category_Cursor') >= -1 DEALLOCATE Category_Cursor
		DECLARE Category_Cursor CURSOR FOR
			
			SELECT 
				[ColumnCode]
			FROM
				#Column C
			WHERE
				[ColumnCode] LIKE 'H%'
			ORDER BY
				[ColumnCode]

			OPEN Category_Cursor
			FETCH NEXT FROM Category_Cursor INTO @ColumnCode

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ColumnCode] = @ColumnCode

					SET @SQLStatement = '
						INSERT INTO #Category
							(
							[Category_MemberKey]
							)
						SELECT DISTINCT
							[Category_MemberKey] = LMT.[' + @ColumnCode + '_MemberKey]
						FROM
							#LeafMemberTable LMT
						WHERE
							LMT.[' + @ColumnCode + '_MemberKey] IS NOT NULL AND
							LMT.[' + @ColumnCode + '_MemberID] IS NULL AND
							NOT EXISTS (SELECT 1 FROM #Category C WHERE C.[Category_MemberKey] = LMT.[' + @ColumnCode + '_MemberKey])'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM Category_Cursor INTO @ColumnCode
				END

		CLOSE Category_Cursor
		DEALLOCATE Category_Cursor

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Category', * FROM #Category ORDER BY Category_MemberKey

		SET @SQLStatement = '
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
				(
				[Label],
				[Description],
				[HelpText],
				[Inserted],
				[JobID],'
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized],
				[Updated]
				)
			SELECT
				[Label] = C.[Category_MemberKey],
				[Description] = C.[Category_MemberKey],
				[HelpText] = C.[Category_MemberKey],
				[Inserted] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',
				[JobID] = ' + CONVERT(nvarchar(15), @JobID) + ','
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM] = 1042,' ELSE '' END + '
				[RNodeType] = ''P'',
				[SBZ] = 1,
				[Source] = ''Manually Loaded'',
				[Synchronized] = 0,
				[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + '''
			FROM
				#Category C
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D WHERE D.[Label] = C.[Category_MemberKey])'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = @DimensionName, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Update dim columns in #LeafMemberTable'
		IF CURSOR_STATUS('global','Column_Cursor') >= -1 DEALLOCATE Column_Cursor
		DECLARE Column_Cursor CURSOR FOR
			
			SELECT 
				[ColumnCode],
				[ColumnName],
				[DimensionName] = ISNULL(C.[DimensionName], @DimensionName)
			FROM
				#Column C
			WHERE
				[ColumnCode] NOT LIKE 'P%'
			ORDER BY
				[ColumnCode]

			OPEN Column_Cursor
			FETCH NEXT FROM Column_Cursor INTO @ColumnCode, @ColumnName, @SubDimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ColumnCode] = @ColumnCode, [@ColumnName] = @ColumnName, [@SubDimensionName] = @SubDimensionName

					SET @SQLStatement = '
						UPDATE LMT
						SET
							[' + @ColumnCode + '_MemberKey] = ISNULL(LMT.[' + @ColumnCode + '_MemberKey], D.[Label]),
							[' + @ColumnCode + '_MemberId] = ISNULL(LMT.[' + @ColumnCode + '_MemberID], D.[MemberId])' +
							CASE WHEN @ColumnCode LIKE 'D%' THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @ColumnCode + '_Description] = D.[Description]' ELSE '' END + '
						FROM
							#LeafMemberTable LMT
							INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @SubDimensionName + '] D ON D.[Label] = LMT.[' + @ColumnCode + '_MemberKey] OR D.[MemberId] = LMT.[' + @ColumnCode + '_MemberId]
						WHERE
							LMT.[DeleteYN] = 0'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM Column_Cursor INTO @ColumnCode, @ColumnName, @SubDimensionName
				END

		CLOSE Column_Cursor
		DEALLOCATE Column_Cursor

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#LeafMemberTable_2', * FROM #LeafMemberTable

	SET @Step = 'Update property columns in #LeafMemberTable'
		UPDATE LMT
		SET
			[MemberKey] = ISNULL(LMT.[MemberKey], REVERSE(STUFF(REVERSE(
								CASE WHEN [D01_MemberKey] IS NOT NULL THEN [D01_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D02_MemberKey] IS NOT NULL THEN [D02_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D03_MemberKey] IS NOT NULL THEN [D03_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D04_MemberKey] IS NOT NULL THEN [D04_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D05_MemberKey] IS NOT NULL THEN [D05_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D06_MemberKey] IS NOT NULL THEN [D06_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D07_MemberKey] IS NOT NULL THEN [D07_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D08_MemberKey] IS NOT NULL THEN [D08_MemberKey] + @Punctuation ELSE '' END + 
								CASE WHEN [D09_MemberKey] IS NOT NULL THEN [D09_MemberKey] + @Punctuation ELSE '' END +
								CASE WHEN [D10_MemberKey] IS NOT NULL THEN [D10_MemberKey] + @Punctuation ELSE '' END), 1, LEN(@Punctuation), ''))),
			[Description] = ISNULL(LMT.[Description], REVERSE(STUFF(REVERSE(
								CASE WHEN [D01_Description] IS NOT NULL THEN [D01_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D02_Description] IS NOT NULL THEN [D02_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D03_Description] IS NOT NULL THEN [D03_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D04_Description] IS NOT NULL THEN [D04_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D05_Description] IS NOT NULL THEN [D05_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D06_Description] IS NOT NULL THEN [D06_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D07_Description] IS NOT NULL THEN [D07_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D08_Description] IS NOT NULL THEN [D08_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D09_Description] IS NOT NULL THEN [D09_Description] + @DescriptionPunctuation ELSE '' END +
								CASE WHEN [D10_Description] IS NOT NULL THEN [D10_Description] + @DescriptionPunctuation ELSE '' END), 1, LEN(@DescriptionPunctuation), ''))),
			[HelpText] = COALESCE(LMT.[HelpText], LMT.[Description], REVERSE(STUFF(REVERSE(
								CASE WHEN [D01_Description] IS NOT NULL THEN [D01_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D02_Description] IS NOT NULL THEN [D02_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D03_Description] IS NOT NULL THEN [D03_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D04_Description] IS NOT NULL THEN [D04_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D05_Description] IS NOT NULL THEN [D05_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D06_Description] IS NOT NULL THEN [D06_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D07_Description] IS NOT NULL THEN [D07_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D08_Description] IS NOT NULL THEN [D08_Description] + @DescriptionPunctuation ELSE '' END + 
								CASE WHEN [D09_Description] IS NOT NULL THEN [D09_Description] + @DescriptionPunctuation ELSE '' END +
								CASE WHEN [D10_Description] IS NOT NULL THEN [D10_Description] + @DescriptionPunctuation ELSE '' END), 1, LEN(@DescriptionPunctuation), '')))
		FROM
			#LeafMemberTable LMT
		WHERE
			LMT.[MemberId] IS NULL AND
			LMT.[DeleteYN] = 0

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#LeafMemberTable_3', * FROM #LeafMemberTable

	SET @Step = 'Update identification columns in #LeafMemberTable'
		SET @SQLStatement = '
			UPDATE LMT
			SET
				[MemberKey] = ISNULL(LMT.[MemberKey], D.[Label]),
				[MemberId] = ISNULL(LMT.[MemberID], D.[MemberId])
			FROM
				#LeafMemberTable LMT
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[Label] = LMT.[MemberKey] OR D.[MemberId] = LMT.[MemberId]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#LeafMemberTable_4', * FROM #LeafMemberTable

	SET @Step = 'Delete dimension members'
		IF @DebugBM & 2 > 0 SELECT [@Step] = @Step, * FROM #LeafMemberTable WHERE [DeleteYN] <> 0

		SET @SQLStatement = '
			DELETE D
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
				INNER JOIN #LeafMemberTable LMT ON LMT.[MemberID] = D.[MemberID] AND LMT.[DeleteYN] <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Update dimension properties'
		IF @DebugBM & 2 > 0 SELECT [@Step] = @Step, * FROM #LeafMemberTable WHERE [DeleteYN] = 0 AND [MemberId] IS NOT NULL

		SET @SQLStatement = '
			UPDATE D
			SET
				[Description] = ISNULL(LMT.[Description], D.[Description]),
				[HelpText] = ISNULL(LMT.[HelpText], D.[HelpText]),'
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM] = ISNULL(D.[NodeTypeBM], 1),' ELSE '' END + '
				[RNodeType] = ISNULL(D.[RNodeType], ''L''),
				[SBZ] = ISNULL(D.[SBZ], 0),
				[Source] = ISNULL(D.[Source], ''MANUAL''),
				[Synchronized] = ISNULL(D.[Synchronized], 1)'

		SELECT
			@SQLStatement = @SQLStatement + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '] = ISNULL(LMT.[' + [ColumnCode] + '_MemberKey], D.[' + [ColumnName] + ']),' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '_MemberId] = ISNULL(LMT.[' + [ColumnCode] + '_MemberId], D.[' + [ColumnName] + '_MemberId])'
		FROM
			#Column
		WHERE
			LEFT([ColumnCode], 1) = 'D'
		ORDER BY
			[ColumnCode]

		SELECT
			@SQLStatement = @SQLStatement + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '] = ISNULL(LMT.[' + [ColumnCode] + '], D.[' + [ColumnName] + '])'
		FROM
			#Column
		WHERE
			LEFT([ColumnCode], 1) = 'P'
		ORDER BY
			[ColumnCode]

		SET @SQLStatement = @SQLStatement + '
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
				INNER JOIN #LeafMemberTable LMT ON LMT.[DeleteYN] = 0 AND LMT.[MemberID] = D.[MemberId]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert new dimension members'
		IF @DebugBM & 2 > 0 SELECT [@Step] = @Step, * FROM #LeafMemberTable WHERE [DeleteYN] = 0 AND [MemberId] IS NULL

		SELECT
			@SQL_Dimension_Insert = @SQL_Dimension_Insert + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '],' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '_MemberId]',
			@SQL_Dimension_Select = @SQL_Dimension_Select + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '] = LMT.[' + [ColumnCode] + '_MemberKey],' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '_MemberId] = LMT.[' + [ColumnCode] + '_MemberId]'
		FROM
			#Column
		WHERE
			LEFT([ColumnCode], 1) = 'D'
		ORDER BY
			[ColumnCode]

		SELECT
			@SQL_Property_Insert = @SQL_Property_Insert + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + ']',
			@SQL_Property_Select = @SQL_Property_Select + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '] = LMT.[' + [ColumnCode] + ']'
		FROM
			#Column
		WHERE
			LEFT([ColumnCode], 1) = 'P'
		ORDER BY
			[ColumnCode]			
			
		SET @SQLStatement = '		
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
				(
				[Label],
				[Description],
				[HelpText],'
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized]' + @SQL_Dimension_Insert + @SQL_Property_Insert + '
				)
			SELECT
				[Label] = LMT.[MemberKey],
				[Description] = LMT.[Description],
				[HelpText] = LMT.[Description],'
				+ CASE WHEN @NodeTypeBMExistsYN <> 0 THEN '[NodeTypeBM] = 1,' ELSE '' END + '
				[RNodeType] = ''L'',
				[SBZ] = 0,
				[Source] = ''MANUAL'',
				[Synchronized] = 1' + @SQL_Dimension_Select + @SQL_Property_Select + '
			FROM
				#LeafMemberTable LMT
			WHERE
				LMT.[DeleteYN] = 0 AND
				LMT.[MemberID] IS NULL'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = @DimensionName, @JobID = @JobID, @Debug = @DebugSub

		--Update MemberID in #LeafMemberTable
		SET @SQLStatement = '	
			UPDATE LMT
			SET
				[MemberID] = D.[MemberId]
			FROM
				#LeafMemberTable LMT
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[Label] = LMT.[MemberKey]
			WHERE
				LMT.[DeleteYN] = 0 AND
				LMT.[MemberID] IS NULL'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#LeafMemberTable_5', * FROM #LeafMemberTable

	SET @Step = 'Hierarchy members, (Update, Insert and Delete)'
		IF CURSOR_STATUS('global','HierarchyMember_Cursor') >= -1 DEALLOCATE HierarchyMember_Cursor
		DECLARE HierarchyMember_Cursor CURSOR FOR
			
			SELECT
				[ColumnCode],
				[HierarchyName] = [ColumnName]
			FROM
				#Column
			WHERE
				LEFT([ColumnCode], 1) = 'H'
			ORDER BY
				[ColumnCode]	

			OPEN HierarchyMember_Cursor
			FETCH NEXT FROM HierarchyMember_Cursor INTO @ColumnCode, @HierarchyName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @Dimensionhierarchy = @DimensionName + '_' + ISNULL(@HierarchyName,  @DimensionName)
					IF @DebugBM & 2 > 0 SELECT [@ColumnCode] = @ColumnCode, [@HierarchyName] = @HierarchyName, [@Dimensionhierarchy] = @Dimensionhierarchy

					SET @SQLStatement = '
						DELETE H
						FROM
							[' + @CallistoDatabase + '].[dbo].[S_HS_' + @Dimensionhierarchy + '] H
							INNER JOIN #LeafMemberTable LMT ON LMT.[MemberID] = H.[MemberID] AND (LMT.[' + @ColumnCode + '_MemberID] IS NOT NULL OR LMT.[DeleteYN] <> 0)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @SQLStatement = '
						INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_' + @Dimensionhierarchy + ']
							(
							[MemberID],
							[ParentMemberID],
							[SequenceNumber]
							)
						SELECT DISTINCT
							[MemberID] = LMT.[' + @ColumnCode + '_MemberID],
							[ParentMemberID] = 1,
							[SequenceNumber] = LMT.[' + @ColumnCode + '_MemberID]
						FROM
							#LeafMemberTable LMT 
						WHERE
							ISNULL(LMT.[' + @ColumnCode + '_MemberID], '''') <> '''' AND
							NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @Dimensionhierarchy + '] H WHERE H.[MemberID] = LMT.[' + @ColumnCode + '_MemberID])'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @SQLStatement = '
						INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_' + @Dimensionhierarchy + ']
							(
							[MemberID],
							[ParentMemberID],
							[SequenceNumber]
							)
						SELECT DISTINCT
							[MemberID] = LMT.[MemberID],
							[ParentMemberID] = LMT.[' + @ColumnCode + '_MemberID],
							[SequenceNumber] = LMT.[MemberID]
						FROM
							#LeafMemberTable LMT 
						WHERE
							LMT.[DeleteYN] = 0 AND
							ISNULL(LMT.[MemberID], '''') <> '''' AND
							ISNULL(LMT.[' + @ColumnCode + '_MemberID], '''') <> '''' AND
							NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_' + @Dimensionhierarchy + '] H WHERE H.[MemberID] = LMT.[MemberID])'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @Updated = @Updated + @@ROWCOUNT

					EXEC [pcINTEGRATOR].[dbo].[spSet_HierarchyCopy] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Database = @CallistoDatabase, @Dimensionhierarchy = @Dimensionhierarchy, @JobID = @JobID, @Debug = @DebugSub

					FETCH NEXT FROM HierarchyMember_Cursor INTO @ColumnCode, @HierarchyName
				END

		CLOSE HierarchyMember_Cursor
		DEALLOCATE HierarchyMember_Cursor
		
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID


END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
