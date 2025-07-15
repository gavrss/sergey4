SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Account_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -1,
	@HierarchyNo int = NULL,
	@SourceTypeID int = NULL,
	@SourceID int = NULL,
	@SequenceBMStep int = 65535, --1 = Parent level, 2 = Leaf level
	@StaticMemberYN bit = 1,
	@Entity_MemberKey nvarchar(50) = NULL, --Mandatory for SIE4

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000631,
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
EXEC [spIU_Dim_Account_Callisto] @UserID = -10, @InstanceID = 508, @VersionID = 1044, @DebugBM =3 
EXEC [spIU_Dim_Account_Callisto] @UserID=-10, @InstanceID=454, @VersionID=1021, @DebugBM = 3
EXEC [spIU_Dim_Account_Callisto] @UserID=-10, @InstanceID=413, @VersionID=1008, @DebugBM = 1
EXEC [spIU_Dim_Account_Callisto] @UserID = -10, @InstanceID = 476, @VersionID = 1029, @DebugBM = 3
EXEC [spIU_Dim_Account_Callisto] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @DebugBM = 1
EXEC [spIU_Dim_Account_Callisto] @UserID = -10, @InstanceID = 531, @VersionID = 1041, @DebugBM=11 --PCX

EXEC [spIU_Dim_Account_Callisto] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
--	@DimensionID int = -1,
	@DimensionName nvarchar(50),
	@SourceDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@LinkedYN bit,
	@MappingTypeID int,
	@SQLStatement nvarchar(max),
	@JSON nvarchar(max),
	@ParentsWithoutChildrenCount int = 1,
	@LogPropertyYN bit = 0, --Properties JobID, Inserted & Updated,
	@NodeTypeBMYN bit = 0,
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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into Callisto Account tables from different sources.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2151' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Changed AccountType to Member.'
		IF @Version = '2.1.0.2159' SET @Description = 'Handle Priority order and MappingTypeID.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added [Entity] property for MappingTypeID 1 & 2.'
		IF @Version = '2.1.1.2169' SET @Description = 'Clear Filter Cache'
		IF @Version = '2.1.1.2171' SET @Description = 'Added SetJobLogYN parameter in [spSet_LeafLevelFilter_ClearCache] call. Modified query for deleting parents without children.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added @SourceTypeID parameter. Handle references to not synchronized parents. Handle dimension LogProperties and improved counting of Inserted and Updated rows.'
		IF @Version = '2.1.1.2173' SET @Description = 'Use sub routine spSet_Hierarchy for hierarchy setup.'
		IF @Version = '2.1.2.2179' SET @Description = 'Added @DimensionID and @HierarchyNo as Parameters. Added @Entity_MemberKey parameter (Mandatory for SIE4).'

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
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

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
				[@MappingTypeID] = @MappingTypeID,
				[@CallistoDatabase] = @CallistoDatabase,
				[@LogPropertyYN] = @LogPropertyYN,
				[@NodeTypeBMYN] = @NodeTypeBMYN

	SET @Step = 'Create temp tables'
		CREATE TABLE #Account_Members
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[Account Type] nvarchar (50) COLLATE DATABASE_DEFAULT,
			[AccountCategory] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[AccountCategory_MemberId] bigint,
			[AccountType] nvarchar (50) COLLATE DATABASE_DEFAULT,
			[AccountType_MemberID] bigint,
			[Rate] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[Rate_MemberId] bigint,
			[Sign] int,
			[TimeBalance] int,
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

	SET @Step = 'Handle ANSI_WARNINGS'
--		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = 'Check for not synchronized parents'
		CREATE TABLE #NoSyncParent
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(255) COLLATE DATABASE_DEFAULT
			)
			
		SET @SQLStatement = '
			INSERT INTO #NoSyncParent
				(
				[MemberId],
				[MemberKey]
				)
			SELECT
				[MemberId] = D.[MemberId],
				[MemberKey] = D.[Label]
			FROM
				' + @CallistoDatabase + '.[dbo].[S_DS_Account] D
			WHERE
				D.[Synchronized] = 0 AND
				NOT EXISTS (SELECT 1 FROM ' + @CallistoDatabase + '.[dbo].[S_HS_Account_Account] H WHERE H.[MemberId] = D.[MemberId])
			ORDER BY
				D.[Label]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#NoSyncParent', * FROM #NoSyncParent ORDER BY [MemberKey]

	SET @Step = 'Fetch members'
		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
			{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(15), @DimensionID) + '"},
			' + CASE WHEN @SourceTypeID IS NOT NULL THEN '{"TKey" : "SourceTypeID",  "TValue": "' + CONVERT(nvarchar(15), @SourceTypeID) + '"},' ELSE '' END + ' 
			' + CASE WHEN @SourceID IS NOT NULL THEN '{"TKey" : "SourceID",  "TValue": "' + CONVERT(nvarchar(15), @SourceID) + '"},' ELSE '' END + '
			' + CASE WHEN @Entity_MemberKey IS NOT NULL THEN '{"TKey" : "Entity_MemberKey",  "TValue": "' + @Entity_MemberKey + '"},' ELSE '' END + '
			{"TKey" : "SequenceBMStep",  "TValue": "' + CONVERT(nvarchar(15), @SequenceBMStep) + '"},
			{"TKey" : "StaticMemberYN",  "TValue": "' + CONVERT(nvarchar(15), CONVERT(int, @StaticMemberYN)) + '"},
			{"TKey" : "MappingTypeID",  "TValue": "' + CONVERT(nvarchar(15), @MappingTypeID) + '"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), CONVERT(int, @DebugSub)) + '"}
			]'

		IF @DebugBM & 2 > 0 PRINT @JSON
		EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_Dim_Account_Raw', @JSON = @JSON

	SET @Step = 'Update #Account_Members'
		UPDATE #Account_Members 
		SET
			[Label] = [MemberKey], 
			[RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END,
			[Account Type] = CASE WHEN [AccountType] IN ('Other', 'Statistical') THEN 'Expense' ELSE [AccountType] END

		SET @SQLStatement = '
			UPDATE
				[Members]
			SET
				[AccountCategory_MemberId] = AC.[MemberId]
			FROM
				[#Account_Members] Members
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_AccountCategory] [AC] ON AC.Label = [Members].[AccountCategory]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE
				[Members]
			SET
				[AccountType_MemberId] = AT.[MemberId]
			FROM
				[#Account_Members] Members
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_AccountType] [AT] ON AT.Label = [Members].[AccountType]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @SQLStatement = '
			UPDATE
				[Members]
			SET
				[Rate_MemberId] = R.[MemberId]
			FROM
				[#Account_Members] Members
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Rate] [R] ON R.Label = [Members].[Rate]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @MappingTypeID <> 0
			BEGIN
            	SET @SQLStatement = '
					UPDATE
						[Members]
					SET
						[Entity_MemberId] = E.[MemberId]
					FROM
						[#' + @DimensionName + '_Members] Members
						INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Entity] [E] ON E.Label = [Members].[Entity]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

		IF @DebugBM & 8 > 0 SELECT TempTable = '#Account_Members', * FROM #Account_Members ORDER BY MemberKey

	SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[' + @DimensionName + ']
			SET
				[Description] = Members.[Description], 
				[HelpText] = Members.[HelpText], 
				[Account Type] = Members.[Account Type], 
				[AccountCategory] = Members.[AccountCategory], 
				[AccountCategory_MemberId] = Members.[AccountCategory_MemberId], 
				[AccountType] = Members.[AccountType], 
				[AccountType_MemberID] = Members.[AccountType_MemberID],
				[Rate] = Members.[Rate], 
				[Rate_MemberId] = Members.[Rate_MemberId], 
				[Sign] = Members.[Sign], 
				[TimeBalance] = Members.[TimeBalance], 
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase] = Members.[MemberKeyBase],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity] = Members.[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberID] = Members.[Entity_MemberID],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM] = Members.[NodeTypeBM],' ELSE '' END + '
				[Source] = Members.[Source]
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] 
				INNER JOIN [#' + @DimensionName + '_Members] Members ON Members.[Label] COLLATE DATABASE_DEFAULT = [' + @DimensionName + '].[Label] 
			WHERE 
				[' + @DimensionName + '].[Synchronized] <> 0 AND
				(
					[' + @DimensionName + '].[Description] <> Members.[Description] OR
					[' + @DimensionName + '].[HelpText] <> Members.[HelpText] OR
					[' + @DimensionName + '].[Account Type] <> Members.[Account Type] OR 
					[' + @DimensionName + '].[AccountCategory] <> Members.[AccountCategory] OR  
					[' + @DimensionName + '].[AccountCategory_MemberId] <> Members.[AccountCategory_MemberId] OR  
					[' + @DimensionName + '].[AccountType] <> Members.[AccountType] OR  
					[' + @DimensionName + '].[AccountType_MemberID] <> Members.[AccountType_MemberID] OR
					[' + @DimensionName + '].[Rate] <> Members.[Rate] OR 
					[' + @DimensionName + '].[Rate_MemberId] <> Members.[Rate_MemberId] OR 
					[' + @DimensionName + '].[Sign] <> Members.[Sign] OR 
					[' + @DimensionName + '].[TimeBalance] <> Members.[TimeBalance] OR 
					' + CASE WHEN @MappingTypeID <> 0 THEN '[' + @DimensionName + '].[MemberKeyBase] <> Members.[MemberKeyBase] OR' ELSE '' END + '
					' + CASE WHEN @MappingTypeID <> 0 THEN '[' + @DimensionName + '].[Entity] <> Members.[Entity] OR' ELSE '' END + '
					' + CASE WHEN @MappingTypeID <> 0 THEN '[' + @DimensionName + '].[Entity_MemberID] <> Members.[Entity_MemberID] OR' ELSE '' END + '
					' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[' + @DimensionName + '].[NodeTypeBM] <> Members.[NodeTypeBM] OR [' + @DimensionName + '].[NodeTypeBM] IS NULL OR' ELSE '' END + '
					[' + @DimensionName + '].[Source] <> Members.[Source]
				)'

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
				[Account Type], 
				[AccountCategory], 
				[AccountCategory_MemberId], 
				[AccountType],
				[AccountType_MemberID],
				[Rate], 
				[Rate_MemberId], 
				[Sign], 
				[TimeBalance], 
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberID],' ELSE '' END + '
				[RNodeType],
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
				[SBZ],				
				[Synchronized],
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated],' ELSE '' END + '
				[Source]
				)
			SELECT
				[MemberId],
				[Label],
				[Description],
				[HelpText],
				[Account Type], 
				[AccountCategory], 
				[AccountCategory_MemberId], 
				[AccountType],
				[AccountType_MemberID],
				[Rate], 
				[Rate_MemberId], 
				[Sign], 
				[TimeBalance], 
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberID],' ELSE '' END + '
				[RNodeType],
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
				[SBZ],
				[Synchronized],
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				[Source]
			FROM   
				[#' + @DimensionName + '_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] WHERE Members.[Label] = [' + @DimensionName + '].[Label])'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update MemberId'
		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = @DimensionName, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Refresh selected hierarchies.'
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
		
		
		--EXEC [pcINTEGRATOR].[dbo].[spSet_Hierarchy]
		--	@UserID = @UserID,
		--	@InstanceID = @InstanceID,
		--	@VersionID = @VersionID,
		--	@StorageTypeBM = 4, 
		--	@StorageDatabase = @CallistoDatabase,
		--	@DimensionName = @DimensionName,
		--	@JobID = @JobID,
		--	@Inserted = @Inserted OUT,
		--	@Debug = @DebugSub

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
					{"TKey" : "SetJobLogYN",  "TValue": "0"},
					{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}
					]'

				IF @DebugBM & 2 > 0 PRINT @JSON

				EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSet_LeafLevelFilter_ClearCache', @JSON = @JSON
			END

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#Account_Members]
		DROP TABLE [#NoSyncParent]

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
