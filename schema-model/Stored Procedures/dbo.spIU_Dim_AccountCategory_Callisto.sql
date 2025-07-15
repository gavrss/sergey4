SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_AccountCategory_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -65,
	@HierarchyNo int = NULL,
	@SourceTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000645,
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
EXEC [spIU_Dim_AccountCategory_Callisto] @UserID=-10, @InstanceID=-1314, @VersionID=-1252, @DebugBM = 7
EXEC [spIU_Dim_AccountCategory_Callisto] @UserID=-10, @InstanceID=413, @VersionID=1008, @DebugBM = 1
EXEC [spIU_Dim_AccountCategory_Callisto] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @DebugBM = 1
EXEC [spIU_Dim_AccountCategory_Callisto] @UserID = -10, @InstanceID = 15, @VersionID = 1039, @DebugBM = 1
EXEC [spIU_Dim_AccountCategory_Callisto] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @DebugBM = 1
EXEC [spIU_Dim_AccountCategory_Callisto] @UserID = -10, @InstanceID = 574, @VersionID = 1045, @DebugBM=7 --GMN

EXEC [spIU_Dim_AccountCategory_Callisto] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@DimensionName nvarchar(50),
	@HierarchyName nvarchar(50),
	@Dimensionhierarchy nvarchar(100),
	@SourceDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@LinkedYN bit,
	@MappingTypeID int,
	@SQLStatement nvarchar(max),
	@JSON nvarchar(max),
	@StorageTypeBM int = 4,

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
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.2.2180'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into Callisto AccountCategory tables from different sources.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2151' SET @Description = 'Close SourceType_Cursor if already exists.'
		IF @Version = '2.0.3.2154' SET @Description = 'Changed AccountType to Member.'
		IF @Version = '2.1.0.2159' SET @Description = '@DebugBM from 1 to 2 for PRINT @SQLStatement regarding Hierarchy table. Handle no Source.'
		IF @Version = '2.1.0.2161' SET @Description = 'Added default parameters to subroutines. Added SP-check if @CallistoDatabase is not set/selected. Changed prefix in the SP name.'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle iScala.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle SIE4.'
		IF @Version = '2.1.1.2170' SET @Description = 'Clear Filter Cache'
		IF @Version = '2.1.2.2179' SET @Description = 'Use sub routine [spSet_Hierarchy].'
		IF @Version = '2.1.2.2180' SET @Description = 'Moved variable @SourceTypeID to input parameters. And added it in #SourceType_Cursor filling condition'

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

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1
		
		SELECT
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		SELECT
			@DimensionName = D.[DimensionName]
		FROM
			pcINTEGRATOR..[Dimension] D
		WHERE
			D.[InstanceID] IN (0, @InstanceID) AND
			D.[DimensionID] = @DimensionID AND
			D.[SelectYN] <> 0 AND
			D.[DeletedID] IS NULL

		SELECT
			@HierarchyName = DH.[HierarchyName]
		FROM
			pcINTEGRATOR..[DimensionHierarchy] DH
			INNER JOIN
				(
				SELECT
					[InstanceID] = CASE WHEN @InstanceID < 0 THEN MIN(DH.[InstanceID]) ELSE MAX(DH.[InstanceID]) END,
					[VersionID] = CASE WHEN @VersionID < 0 THEN MIN(DH.[VersionID]) ELSE MAX(DH.[VersionID]) END	
				FROM
					pcINTEGRATOR..[DimensionHierarchy] DH
				WHERE
					DH.[InstanceID] IN (0, @InstanceID) AND
					DH.[VersionID] IN (0, @VersionID) AND
					DH.[DimensionID] = @DimensionID AND
					DH.[HierarchyNo] = 0
				) sub ON sub.InstanceID = DH.InstanceID AND sub.VersionID = DH.VersionID
		WHERE
			DH.[DimensionID] = @DimensionID AND
			DH.[HierarchyNo] = 0

		SET @Dimensionhierarchy = @DimensionName + '_' + @HierarchyName

		SELECT
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF @DebugBM & 2 > 0
			SELECT
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@HierarchyName] = @HierarchyName,
				[@Dimensionhierarchy] = @Dimensionhierarchy,
				[@MappingTypeID] = @MappingTypeID,
				[@CallistoDatabase] = @CallistoDatabase

	SET @Step = 'Check if @CallistoDatabase is set/selected'
		IF @CallistoDatabase IS NULL
			BEGIN
				SET @Message = 'CallistoDatabase is not set/selected.'
				SET @Severity = 10
				GOTO EXITPOINT
			END

	SET @Step = 'Create temp tables'
		CREATE TABLE #AccountCategory_Members
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[AccountType] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[AccountType_MemberID] bigint,
			[NodeTypeBM] int,
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,				
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Handle ANSI_WARNINGS'
--		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = 'Create temp table #SourceType_Cursor'
			CREATE TABLE #SourceType_Cursor
				(
				SourceTypeID int,
				SourceDatabase nvarchar(100) COLLATE DATABASE_DEFAULT
				)
			
			INSERT INTO #SourceType_Cursor
				(
				SourceTypeID,
				SourceDatabase
				)
			SELECT DISTINCT
				SourceTypeID,
				SourceDatabase
			FROM
				[Source] S
			WHERE
				S.InstanceID = @InstanceID AND
				S.VersionID = @VersionID AND
				S.SelectYN <> 0 AND 
				(S.SourceTypeID = @SourceTypeID OR @SourceTypeID IS NULL)


			IF (SELECT COUNT(1) FROM #SourceType_Cursor) = 0
				BEGIN
					SELECT @SourceTypeID = 7 FROM pcINTEGRATOR_Data..SIE4_Job WHERE InstanceID = @InstanceID AND JobID = @JobID
					INSERT INTO #SourceType_Cursor
						(
						SourceTypeID,
						SourceDatabase
						)
					SELECT DISTINCT
						SourceTypeID = ISNULL(@SourceTypeID, 0),
						SourceDatabase = NULL
				END

	SET @Step = 'Run SourceType_Cursor'
		IF CURSOR_STATUS('global','SourceType_Cursor') >= -1 DEALLOCATE SourceType_Cursor
		DECLARE SourceType_Cursor CURSOR FOR
			SELECT DISTINCT
				SourceTypeID,
				SourceDatabase
			FROM
				#SourceType_Cursor
			ORDER BY
				SourceTypeID,
				SourceDatabase

			OPEN SourceType_Cursor
			FETCH NEXT FROM SourceType_Cursor INTO @SourceTypeID, @SourceDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@SourceTypeID] = @SourceTypeID, [@SourceDatabase] = @SourceDatabase

					EXEC [spIU_Dim_AccountCategory_Raw] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SourceTypeID = @SourceTypeID, @SourceDatabase = @SourceDatabase, @JobID=@JobID, @Debug = @DebugSub

					FETCH NEXT FROM SourceType_Cursor INTO @SourceTypeID, @SourceDatabase
				END
		CLOSE SourceType_Cursor
		DEALLOCATE SourceType_Cursor
		
		SET ANSI_WARNINGS OFF

		UPDATE #AccountCategory_Members SET [Label] = [MemberKey], [RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#AccountCategory_Members', * FROM #AccountCategory_Members

	SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[AccountCategory]
			SET
				[Description] = Members.[Description], 
				[HelpText] = Members.[HelpText], 
				[AccountType] = Members.[AccountType], 
				[AccountType_MemberId] = Members.[AccountType_MemberID], 
				[Source] = Members.[Source]  
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_AccountCategory] [AccountCategory] 
				INNER JOIN [#AccountCategory_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [AccountCategory].LABEL 
			WHERE 
				[AccountCategory].[Synchronized] <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT
		
	SET @Step = 'Insert new members from source system'
		SET @SQLStatement = '
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_AccountCategory]
				(
				[MemberId],
				[Label],
				[Description],
				[HelpText],
				[AccountType],
				[AccountType_MemberId],
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized]
				)
			SELECT
				[MemberId],
				[Label],
				[Description],
				[HelpText],
				[AccountType],
				[AccountType_MemberID],
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized]
			FROM   
				[#' + @DimensionName + '_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] WHERE Members.Label = [' + @DimensionName + '].Label)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update MemberId'
		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Database = @CallistoDatabase, @Dimension = @DimensionName, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Update selected hierarchy (or all hierarchies if @HierarchyNo IS NULL).'
		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
			{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(15), @DimensionID) + '"},
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

	SET @Step = 'Clear Filter Cache'
		IF @Inserted + @Deleted > 0
			BEGIN
				SET @JSON = '
					[
					{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
					{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
					{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
					{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(10), @DimensionID) + '"},
					{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
					{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}
					]'

				IF @DebugBM & 2 > 0 PRINT @JSON

				EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSet_LeafLevelFilter_ClearCache', @JSON = @JSON
			END

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#AccountCategory_Members]
		DROP TABLE [#SourceType_Cursor]

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
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
