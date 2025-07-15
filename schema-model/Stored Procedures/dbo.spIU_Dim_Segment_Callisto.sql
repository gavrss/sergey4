SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Segment_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL, 
	@HierarchyNo int = NULL, 
	@SequenceBMStep int = 65535, --1 = Parent level, 2 = Leaf level
	@StaticMemberYN bit = 1,
	@SourceTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000669,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM = 3 (include high and low prio, exclude sub routines)
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_Dim_Segment_Callisto] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @DebugBM = 1
EXEC [spIU_Dim_Segment_Callisto] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @DebugBM = 1
EXEC [spIU_Dim_Segment_Callisto] @UserID = -10, @InstanceID = 523, @VersionID = 1051, @DimensionID = 5412, @DebugBM = 1
EXEC [spIU_Dim_Segment_Callisto] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @DimensionID = 1003, @DebugBM = 9
EXEC [spIU_Dim_Segment_Callisto] @UserID = -10, @InstanceID = 533, @VersionID = 1058, @SourceTypeID = 7, @DebugBM = 7
EXEC [spIU_Dim_Segment_Callisto] @UserID = -10, @InstanceID = 574, @VersionID = 1045, @DebugBM=1 --GMN
EXEC [spIU_Dim_Segment_Callisto] @UserID = -10, @InstanceID = 531, @VersionID = 1041, @DebugBM=1 --PCX

EXEC [spIU_Dim_Segment_Callisto] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@DimensionName nvarchar(100),
	@LinkedYN bit,
	@SQLStatement nvarchar(max),
	@Dimensionhierarchy nvarchar(100),
	@HierarchyName nvarchar(50),
	@MappingTypeID int,
	@NumberHierarchy int,
	@JSON nvarchar(max),
	@StorageTypeBM int = 4,
	@LogPropertyYN bit,
	@NodeTypeBMYN bit,

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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into Callisto Segment tables from different sources.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2153' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2159' SET @Description = 'Handle Priority order and MappingTypeID.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added [Entity] property for MappingTypeID 1 & 2.'
		IF @Version = '2.1.0.2164' SET @Description = 'Added property NumberHierarchy.'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle iScala.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle SIE4.'
		IF @Version = '2.1.1.2169' SET @Description = 'Enhanced debugging. Changed default Priority to 99999999.'
		IF @Version = '2.1.1.2171' SET @Description = 'Remove rows where [MemberKey] is empty string.'
		IF @Version = '2.1.2.2179' SET @Description = 'Use sub routine [spSet_Hierarchy].'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = A.[DestinationDatabase],
			@ETLDatabase = A.[ETLDatabase]
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		SET @HierarchyNo = ISNULL(@HierarchyNo, 0)
	
	SET @Step = 'Create temp tables'
		CREATE TABLE #Segment_Members
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[MemberKeyBase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar (50) COLLATE DATABASE_DEFAULT,
			[Entity_MemberID] bigint,
			[NodeTypeBM] int,
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,				
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
			)
				
	SET @Step = 'Create #EB (Entity/Book)'
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

	SET @Step = 'Handle ANSI_WARNINGS'
--		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = 'Create cursor table'
		CREATE TABLE #Segment_Cursor_table
			(
			DimensionID int, 
			DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT,
			SourceTypeID int,
			SourceDatabase nvarchar(100) COLLATE DATABASE_DEFAULT,
			MappingTypeID int,
			NumberHierarchy int
			)

		INSERT INTO #Segment_Cursor_table
			(
			DimensionID, 
			DimensionName,
			SourceTypeID,
			SourceDatabase,
			MappingTypeID,
			NumberHierarchy
			)
		SELECT DISTINCT
			D.DimensionID, 
			D.DimensionName,
			SourceTypeID = ISNULL(@SourceTypeID, S.SourceTypeID),
			S.SourceDatabase,
			DST.MappingTypeID,
			DST.NumberHierarchy
		FROM
			pcINTEGRATOR_Data..Dimension D
			INNER JOIN pcINTEGRATOR_Data.dbo.[Dimension_StorageType] DST ON DST.InstanceID = D.InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = D.DimensionID
			INNER JOIN pcINTEGRATOR_Data..Journal_SegmentNo JSN ON JSN.InstanceID = DST.InstanceID AND JSN.VersionID = DST.VersionID AND JSN.DimensionID = DST.DimensionID AND JSN.SelectYN <> 0
			LEFT JOIN pcINTEGRATOR_Data..[Model] M ON M.InstanceID = JSN.InstanceID AND M.VersionID = JSN.VersionID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			LEFT JOIN pcINTEGRATOR_Data..[Source] S ON S.InstanceID = M.InstanceID AND S.VersionID = M.VersionID AND S.ModelID = M.ModelID AND S.SelectYN <> 0 AND (S.SourceTypeID = @SourceTypeID OR @SourceTypeID IS NULL)
		WHERE
			D.InstanceID = @InstanceID AND
			D.DimensionTypeID = -1 AND
			(D.DimensionID = @DimensionID OR @DimensionID IS NULL) AND
			D.SelectYN <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Segment_Cursor_table', * FROM #Segment_Cursor_table ORDER BY SourceTypeID, DimensionName

	SET @Step = 'Segment_Cursor'
		IF CURSOR_STATUS('global','Segment_Cursor') >= -1 DEALLOCATE Segment_Cursor
		DECLARE Segment_Cursor CURSOR FOR
			
			SELECT 
				DimensionID, 
				DimensionName,
				SourceTypeID,
				SourceDatabase,
				MappingTypeID,
				NumberHierarchy
			FROM
				#Segment_Cursor_table
			ORDER BY
				SourceTypeID,
				DimensionName

			OPEN Segment_Cursor
			FETCH NEXT FROM Segment_Cursor INTO @DimensionID, @DimensionName, @SourceTypeID, @SourceDatabase, @MappingTypeID, @NumberHierarchy

			WHILE @@FETCH_STATUS = 0
				BEGIN
					--IF @HierarchyNo <> 0
					--	SELECT
					--		@HierarchyName = [HierarchyName]
					--	FROM
					--		[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH
					--	WHERE
					--		[InstanceID] = @InstanceID AND
					--		[VersionID] = @VersionID AND
					--		[DimensionID] = @DimensionID AND
					--		[HierarchyNo] = @HierarchyNo
					--ELSE
					--	SET @HierarchyName = @DimensionName
							
					--SET @Dimensionhierarchy = @DimensionName + '_' + ISNULL(@HierarchyName, @DimensionName)

					EXEC [dbo].[spGet_DimPropertyStatus]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@DimensionID = @DimensionID,
						@StorageTypeBM = @StorageTypeBM,
						@LogPropertyYN = @LogPropertyYN OUT,
						@NodeTypeBMYN = @NodeTypeBMYN OUT,
						@JobID = @JobID,
						@Debug = @DebugSub

					IF @DebugBM & 2 > 0 
						SELECT
							[@DimensionID] = @DimensionID,
							[@DimensionName] = @DimensionName,
							[@HierarchyName] = @HierarchyName,
							[@Dimensionhierarchy] = @Dimensionhierarchy,
							[@SourceTypeID] = @SourceTypeID,
							[@SourceDatabase] = @SourceDatabase,
							[@LogPropertyYN] = @LogPropertyYN,
							[@NodeTypeBMYN] = @NodeTypeBMYN

					TRUNCATE TABLE #Segment_Members

					SET @Step = 'Fetch members'
						EXEC [spIU_Dim_Segment_Raw] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SourceTypeID=@SourceTypeID, @SourceDatabase=@SourceDatabase, @DimensionID=@DimensionID, @SequenceBMStep=@SequenceBMStep, @StaticMemberYN=@StaticMemberYN, @MappingTypeID=@MappingTypeID, @NumberHierarchy=@NumberHierarchy, @ETLDatabase=@ETLDatabase, @JobID=@JobID, @Debug=@DebugSub

						DELETE #Segment_Members WHERE [MemberKey] = ''

						UPDATE #Segment_Members 
						SET
							[Label] = [MemberKey], 
							[RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END

						IF @MappingTypeID <> 0
							BEGIN
            					SET @SQLStatement = '
									UPDATE
										[Members]
									SET
										[Entity_MemberId] = E.[MemberId]
									FROM
										[#Segment_Members] Members
										INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Entity] [E] ON E.Label = [Members].[Entity]'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
							END

						IF @DebugBM & 8 > 0 SELECT TempTable = '#Segment_Members', * FROM #Segment_Members ORDER BY [MemberKey]

					SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
						SET @SQLStatement = '
							UPDATE
								[Segment]
							SET
								[Description] = Members.[Description], 
								[HelpText] = Members.[HelpText], 
								' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase] = Members.[MemberKeyBase],' ELSE '' END + '
								' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity] = Members.[Entity],' ELSE '' END + '
								' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberID] = Members.[Entity_MemberID],' ELSE '' END + '
								' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
								' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
								' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM] = Members.[NodeTypeBM],' ELSE '' END + '

								[Source] = Members.[Source]  
							FROM
								[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [Segment] 
								INNER JOIN [#Segment_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [Segment].LABEL 
							WHERE 
								[Segment].[Synchronized] <> 0'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @Updated = @Updated + @@ROWCOUNT
		
					SET @Step = 'Insert new members from source system'
						SET @SQLStatement = '
							INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']
								(
								[MemberId],
								[Label],
								[Description],
								[HelpText],
								' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase],' ELSE '' END + '
								' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity],' ELSE '' END + '
								' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberID],' ELSE '' END + '
								[RNodeType],
								' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
								' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID],' ELSE '' END + '
								' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted],' ELSE '' END + '
								' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated],' ELSE '' END + '
								[SBZ],
								[Source],
								[Synchronized]
								)
							SELECT
								[MemberId],
								[Label],
								[Description],
								[HelpText],
								' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase],' ELSE '' END + '
								' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity],' ELSE '' END + '
								' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberID],' ELSE '' END + '
								[RNodeType],
								' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
								' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
								' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
								' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
								[SBZ],
								[Source],
								[Synchronized]
							FROM   
								[#Segment_Members] Members
							WHERE
								NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [Segment] WHERE Members.Label = [Segment].Label)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						SET @Inserted = @Inserted + @@ROWCOUNT

					SET @Step = 'Update MemberId'
						EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = @DimensionName, @JobID = @JobID, @Debug = @DebugSub

					SET @Step = 'Update selected hierarchy (or all hierarchies if @HierarchyNo IS NULL).'
						SET @JSON = '
							[
							{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
							{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
							{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
							{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(15), @DimensionID) + '"},
							{"TKey" : "SourceTable",  "TValue": "#Segment_Members"},
							' + CASE WHEN @HierarchyNo IS NOT NULL THEN '{"TKey" : "HierarchyNo",  "TValue": "' + CONVERT(nvarchar(10), @HierarchyNo) + '"},' ELSE '' END + '
							{"TKey" : "StorageTypeBM",  "TValue": "' + CONVERT(nvarchar(15), @StorageTypeBM) + '"},
							{"TKey" : "StorageDatabase",  "TValue": "' + @CallistoDatabase + '"},
							{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
							{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}
							]'

						IF @DebugBM & 2 > 0 PRINT @JSON
					
						EXEC spRun_Procedure_KeyValuePair
							@DatabaseName = 'pcINTEGRATOR',
							@ProcedureName = 'spSet_Hierarchy',
							@JSON = @JSON

					SET @Step = 'Return rows'
						IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] ORDER BY [Label]')

					FETCH NEXT FROM Segment_Cursor INTO @DimensionID, @DimensionName, @SourceTypeID, @SourceDatabase, @MappingTypeID, @NumberHierarchy
				END
		CLOSE Segment_Cursor
		DEALLOCATE Segment_Cursor

	SET @Step = 'Drop temp tables'
		DROP TABLE [#Segment_Members]
		DROP TABLE [#EB]

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
