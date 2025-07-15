SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Customer_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -9,
	@HierarchyNo int = NULL,
	@SequenceBMStep int = 65535, --1 = Parent level, 2 = Leaf level
	@StaticMemberYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000696,
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
EXEC [spIU_Dim_Customer_Callisto] @UserID = -10, @InstanceID = 476, @VersionID = 1024, @DebugBM = 1
EXEC [spIU_Dim_Customer_Callisto] @UserID=-10, @InstanceID=454, @VersionID=1021, @DebugBM = 1
EXEC [spIU_Dim_Customer_Callisto] @UserID=-10, @InstanceID=413, @VersionID=1008, @DebugBM = 7
EXEC [spIU_Dim_Customer_Callisto] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @DebugBM = 3
EXEC [spIU_Dim_Customer_Callisto] @UserID = -10, @InstanceID = 527, @VersionID = 1055, @DebugBM = 1
EXEC [spIU_Dim_Customer_Callisto] @UserID = -10, @InstanceID = 574, @VersionID = 1045, @DebugBM=7 --GMN
EXEC [spIU_Dim_Customer_Callisto] @UserID = -10, @InstanceID = 531, @VersionID = 1041, @DebugBM=7 --PCX

EXEC [spIU_Dim_Customer_Callisto] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@DimensionName nvarchar(50),
	@SourceTypeID int = NULL,
	@SourceDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@LinkedYN bit,
	@MappingTypeID int,
	@SQLStatement nvarchar(max),
	@JSON nvarchar(max),
	@LogPropertyYN bit = 0, --Properties JobID, Inserted & Updated
	@StorageTypeBM int = 4,
	@NodeTypeBMYN bit,

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into Callisto Customer tables from different sources.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2161' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2162' SET @Description = 'Updated handling of @SourceDatabase and @Entity. Added property Level.'
		IF @Version = '2.1.1.2169' SET @Description = 'Update RNodeType.'
		IF @Version = '2.1.1.2174' SET @Description = 'New template.'
		IF @Version = '2.1.2.2179' SET @Description = 'Use sub routine [spSet_Hierarchy].'

--		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
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
		CREATE TABLE #Customer_Members
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[MemberKeyBase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Entity_MemberID] bigint,
			[NodeTypeBM] int,
			[Level] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[AccountManager] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[AccountManager_MemberId] bigint,
			[CustomerCategory] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[CustomerCategory_MemberId] bigint,
			[Geography] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[Geography_MemberId] bigint,
			[PaymentDays] int,
			[SendTo] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[SendTo_MemberId] bigint,
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

	SET @Step = 'Fetch members'
		EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_Customer_Raw] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBMStep=@SequenceBMStep, @StaticMemberYN=@StaticMemberYN, @MappingTypeID=@MappingTypeID, @JobID=@JobID, @Debug=@DebugSub

		UPDATE #Customer_Members 
		SET
			[Label] = [MemberKey], 
			[RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END

		IF @MappingTypeID <> 0
			BEGIN
				SET @SQLStatement = '
					UPDATE
						[Members]
					SET
						[Entity] = CASE WHEN E.[MemberId] IS NULL THEN ''NONE'' ELSE [Members].[Entity] END,
						[Entity_MemberId] = ISNULL(E.[MemberId], -1)
					FROM
						[#Customer_Members] Members
						LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Entity] [E] ON E.[Label] = [Members].[Entity]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

		SET @SQLStatement = '
			UPDATE
				[Members]
			SET
				[AccountManager] = CASE WHEN AM.[MemberId] IS NULL THEN ''NONE'' ELSE [Members].[AccountManager] END,
				[AccountManager_MemberId] = ISNULL(AM.[MemberId], -1),
				[CustomerCategory] = CASE WHEN CC.[MemberId] IS NULL THEN ''NONE'' ELSE [Members].[CustomerCategory] END,
				[CustomerCategory_MemberId] = ISNULL(CC.[MemberId], -1),
				[Geography] = CASE WHEN G.[MemberId] IS NULL THEN ''NONE'' ELSE [Members].[Geography] END,
				[Geography_MemberId] = ISNULL(G.[MemberId], -1),
				[SendTo] = CASE WHEN C.[MemberId] IS NULL THEN NULL ELSE [Members].[SendTo] END,
				[SendTo_MemberId] = C.[MemberId]
			FROM
				[#Customer_Members] Members
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_AccountManager] [AM] ON AM.[Label] = [Members].[AccountManager]
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_CustomerCategory] [CC] ON CC.[Label] = [Members].[CustomerCategory]
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Geography] [G] ON G.[Label] = [Members].[Geography]
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Customer] [C] ON C.[Label] = [Members].[SendTo]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Customer_Members', * FROM #Customer_Members

	SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[' + @DimensionName + ']
			SET
				[Description] = Members.[Description], 
				[HelpText] = Members.[HelpText], 
				[Level] = Members.[Level],
				[RNodeType] = Members.[RNodeType],
				[AccountManager] = Members.[AccountManager], 
				[AccountManager_MemberId] = Members.[AccountManager_MemberId], 
				[CustomerCategory] = Members.[CustomerCategory], 
				[CustomerCategory_MemberId] = Members.[CustomerCategory_MemberId], 
				[Geography] = Members.[Geography], 
				[Geography_MemberId] = Members.[Geography_MemberId], 
				[PaymentDays] = Members.[PaymentDays], 
				[SendTo] = Members.[SendTo],
				[SendTo_MemberId] = Members.[SendTo_MemberId], 
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase] = Members.[MemberKeyBase],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity] = Members.[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberID] = Members.[Entity_MemberID],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM] = Members.[NodeTypeBM],' ELSE '' END + '
				[Source] = Members.[Source]				
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] 
				INNER JOIN [#Customer_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [Customer].LABEL 
			WHERE 
				[' + @DimensionName + '].[Synchronized] <> 0 AND
				(
					ISNULL([' + @DimensionName + '].[Description], ''-9999'') <> ISNULL(Members.[Description], ''-9999'') OR
					ISNULL([' + @DimensionName + '].[HelpText], ''-9999'') <> ISNULL(Members.[HelpText], ''-9999'') OR
					ISNULL([' + @DimensionName + '].[Level], ''-9999'') <> ISNULL(Members.[Level], ''-9999'') OR
					ISNULL([' + @DimensionName + '].[RNodeType], ''-9999'') <> ISNULL(Members.[RNodeType], ''-9999'') OR
					ISNULL([' + @DimensionName + '].[AccountManager], ''-9999'') <> ISNULL(Members.[AccountManager], ''-9999'') OR 
					ISNULL([' + @DimensionName + '].[AccountManager_MemberId], -9999) <> ISNULL(Members.[AccountManager_MemberId], -9999) OR 
					ISNULL([' + @DimensionName + '].[CustomerCategory], ''-9999'') <> ISNULL(Members.[CustomerCategory], ''-9999'') OR 
					ISNULL([' + @DimensionName + '].[CustomerCategory_MemberId], -9999) <> ISNULL(Members.[CustomerCategory_MemberId], -9999) OR 
					ISNULL([' + @DimensionName + '].[Geography], ''-9999'') <> ISNULL(Members.[Geography], ''-9999'') OR 
					ISNULL([' + @DimensionName + '].[Geography_MemberId], -9999) <> ISNULL(Members.[Geography_MemberId], -9999) OR 
					ISNULL([' + @DimensionName + '].[PaymentDays], -9999) <> ISNULL(Members.[PaymentDays], -9999) OR 
					ISNULL([' + @DimensionName + '].[SendTo], ''-9999'') <> ISNULL(Members.[SendTo], ''-9999'') OR
					ISNULL([' + @DimensionName + '].[SendTo_MemberId], -9999) <> ISNULL(Members.[SendTo_MemberId], -9999) OR
					' + CASE WHEN @MappingTypeID <> 0 THEN 'ISNULL([' + @DimensionName + '].[MemberKeyBase], ''-9999'') <> ISNULL(Members.[MemberKeyBase], ''-9999'') OR' ELSE '' END + '
					' + CASE WHEN @MappingTypeID <> 0 THEN 'ISNULL([' + @DimensionName + '].[Entity], ''-9999'') <> ISNULL(Members.[Entity], ''-9999'') OR' ELSE '' END + '
					' + CASE WHEN @MappingTypeID <> 0 THEN 'ISNULL([' + @DimensionName + '].[Entity_MemberID], -9999) <> ISNULL(Members.[Entity_MemberID], -9999) OR' ELSE '' END + '
					' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[' + @DimensionName + '].[NodeTypeBM] <> Members.[NodeTypeBM] OR [' + @DimensionName + '].[NodeTypeBM] IS NULL OR' ELSE '' END + '
					ISNULL([' + @DimensionName + '].[Source], ''-9999'') <> ISNULL(Members.[Source], ''-9999'')
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
				[Level],
				[AccountManager],
				[AccountManager_MemberId],
				[CustomerCategory],
				[CustomerCategory_MemberId],
				[Geography],
				[Geography_MemberId],
				[PaymentDays],
				[SendTo],
				[SendTo_MemberId],
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberId],' ELSE '' END + '
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
				[Level],
				[AccountManager],
				[AccountManager_MemberId],
				[CustomerCategory],
				[CustomerCategory_MemberId],
				[Geography],
				[Geography_MemberId],
				[PaymentDays],
				[SendTo],
				[SendTo_MemberId],
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberId],' ELSE '' END + '
				[RNodeType],
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				[SBZ],
				[Source],
				[Synchronized]
			FROM   
				[#Customer_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] WHERE Members.Label = [' + @DimensionName + '].[Label])'

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
					{"TKey" : "SetJobLogYN",  "TValue": "0"},
					{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}
					]'

				IF @DebugBM & 2 > 0 PRINT @JSON

				EXEC [pcINTEGRATOR].[dbo].[spRun_Procedure_KeyValuePair] @ProcedureName = 'spSet_LeafLevelFilter_ClearCache', @JSON = @JSON
			END

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_Customer]'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Customer]')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#Customer_Members]

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
