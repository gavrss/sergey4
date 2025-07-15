SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spIU_Dim_OrderLine_Callisto]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	--SP-specific parameters
	@DimensionID INT = -29, 
	@HierarchyNo INT = NULL,
	--NB New hierarchy routines are not yet implemented

	@SequenceBMStep INT = 65535, --1 = Parent level, 2 = Leaf level
	@StaticMemberYN BIT = 1,
	@MappingTypeID INT = NULL,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000713,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM = 3 (include high and low prio, exclude sub routines)
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_Dim_OrderLine_Callisto] @UserID = -10, @InstanceID = 531, @VersionID = 1057, @DebugBM = 1

EXEC [spIU_Dim_OrderLine_Callisto] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceTypeID INT = NULL,
	@SourceDatabase NVARCHAR(100),
	@CallistoDatabase NVARCHAR(100),
	@DimensionName NVARCHAR(100),
	@LinkedYN BIT,
	@SQLStatement NVARCHAR(MAX),
	@Dimensionhierarchy NVARCHAR(100),
	@JSON nvarchar(max),
	@LogPropertyYN bit = 0, --Properties JobID, Inserted & Updated,
	@NodeTypeBMYN bit = 0,
	@StorageTypeBM int = 4,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName nvarchar(100),
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
	@CreatedBy NVARCHAR(50) = 'NeHa',
	@ModifiedBy NVARCHAR(50) = 'SeGa',
	@Version NVARCHAR(50) = '2.1.2.2191'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into Callisto OrderLine tables from different sources.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2169' SET @Description = 'Changed default Priority to 99999999.'
		IF @Version = '2.1.2.2191' SET @Description = 'Use sub routine spSet_Hierarchy for hierarchy setup.'

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
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@DimensionName = DimensionName
		FROM
			pcINTEGRATOR.dbo.[Dimension]
		WHERE
			InstanceID IN (0, @InstanceID) AND
			DimensionID = @DimensionID

		SELECT
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		SELECT
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		SELECT DISTINCT
			@SourceTypeID = S.SourceTypeID,
			@SourceDatabase = S.SourceDatabase
		FROM
			pcINTEGRATOR_Data..[Model] M
			INNER JOIN pcINTEGRATOR_Data..[Source] S ON S.InstanceID = M.InstanceID AND S.VersionID = M.VersionID AND S.ModelID = M.ModelID AND S.SelectYN <> 0
		WHERE
			M.InstanceID = @InstanceID AND
			M.VersionID = @VersionID AND
			M.BaseModelID = -4 AND --Sales
			M.SelectYN <> 0

		IF @DebugBM & 2 > 0 SELECT [@SourceTypeID]=@SourceTypeID, [@SourceDatabase]=@SourceDatabase, [@DimensionID]=@DimensionID, [@DimensionName]=@DimensionName, [@SequenceBMStep]=@SequenceBMStep, [@StaticMemberYN]=@StaticMemberYN, [@MappingTypeID]=@MappingTypeID

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
		CREATE TABLE #OrderLine_Members
			(
			[MemberId] BIGINT,
			[MemberKey] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[Label] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[Description] NVARCHAR(512) COLLATE DATABASE_DEFAULT,
			[HelpText] NVARCHAR(1024) COLLATE DATABASE_DEFAULT,
			[MemberKeyBase] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] INT,
			[RNodeType] NVARCHAR(2) COLLATE DATABASE_DEFAULT,
			[SBZ] BIT,
			[Source] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] BIT,				
			[Parent] NVARCHAR(255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create #EB (Entity/Book)'
		SELECT DISTINCT
			[EntityID] = E.[EntityID],
			[Entity] = E.[MemberKey],
			[EntityName] = E.[EntityName],
			[Priority] = CONVERT(INT, ISNULL(E.[Priority], 99999999))
		INTO
			#EB
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] B ON B.[InstanceID] = E.InstanceID AND B.[VersionID] = E.VersionID AND B.EntityID = E.EntityID AND B.BookTypeBM & 8 > 0 AND B.SelectYN <> 0
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			E.[SelectYN] <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#EB', * FROM #EB

	SET @Step = 'Set Instance specific hierarchy levels'
		IF @MappingTypeID IN (1, 2)
			BEGIN
				--Set Instance specific Hierarchy
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
					(
					[Comment],
					[InstanceID],
					[VersionID],
					[DimensionID],
					[HierarchyNo],
					[HierarchyName],
					[FixedLevelsYN],
					[LockedYN]
					)
				SELECT
					[Comment] = @DimensionName,
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DimensionID] = @DimensionID,
					[HierarchyNo] = 0,
					[HierarchyName] = @DimensionName,
					[FixedLevelsYN] = 1,
					[LockedYN] = 0
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DimensionHierarchy] DDH WHERE DDH.[InstanceID] IN (0, @InstanceID) AND DDH.[VersionID] IN (0, @VersionID) AND DDH.[DimensionID] = @DimensionID AND DDH.[HierarchyNo] = 0)

				--Set Instance specific Hierarchy levels
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
					(
					[Comment],
					[InstanceID],
					[VersionID],
					[DimensionID],
					[HierarchyNo],
					[LevelNo],
					[LevelName]
					)
				SELECT
					[Comment] = sub.[Comment],
					[InstanceID] = sub.[InstanceID],
					[VersionID] = sub.[VersionID],
					[DimensionID] = sub.[DimensionID],
					[HierarchyNo] = sub.[HierarchyNo],
					[LevelNo] = sub.[LevelNo],
					[LevelName] = sub.[LevelName]
				FROM
					(
					SELECT [Comment] = @DimensionName, [InstanceID] = @InstanceID, [VersionID] = @VersionID, [DimensionID] = @DimensionID, [HierarchyNo] = 0, [LevelNo] = 1, [LevelName] = 'TopNode'
					UNION SELECT [Comment] = @DimensionName, [InstanceID] = @InstanceID, [VersionID] = @VersionID, [DimensionID] = @DimensionID, [HierarchyNo] = 0, [LevelNo] = 2, [LevelName] = @DimensionName
					) sub
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DDHL WHERE DDHL.[InstanceID] IN (0, sub.[InstanceID]) AND DDHL.[VersionID] IN (0, sub.[VersionID]) AND DDHL.[DimensionID] = sub.[DimensionID] AND DDHL.[HierarchyNo] = sub.[HierarchyNo] AND DDHL.[LevelNo] = sub.[LevelNo])
			END

	SET @Step = 'Fetch members'
		EXEC [spIU_Dim_OrderLine_Raw] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SourceTypeID=@SourceTypeID, @SourceDatabase=@SourceDatabase, @SequenceBMStep=@SequenceBMStep, @StaticMemberYN=@StaticMemberYN, @MappingTypeID=@MappingTypeID, @JobID=@JobID, @Debug=@DebugSub

		UPDATE #OrderLine_Members 
		SET
			[Label] = [MemberKey], 
			[RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#OrderLine_Members', * FROM #OrderLine_Members

	SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[OrderLine]
			SET
				[Description] = Members.[Description], 
				[HelpText] = Members.[HelpText], 
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase] = [Members].[MemberKeyBase],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity] = [Members].[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberID] = [Members].[Entity_MemberID],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM] = [Members].[NodeTypeBM],' ELSE '' END + '
				[Source] = Members.[Source] 
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [OrderLine] 
				INNER JOIN [#OrderLine_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [OrderLine].LABEL 
			WHERE 
				[OrderLine].[Synchronized] <> 0 AND
				(
					[OrderLine].[Description] <> Members.[Description] OR
					[OrderLine].[HelpText] <> Members.[HelpText] OR
					' + CASE WHEN @MappingTypeID <> 0 THEN 'ISNULL([OrderLine].[MemberKeyBase], '''') <> [Members].[MemberKeyBase] OR' ELSE '' END + '
					' + CASE WHEN @MappingTypeID <> 0 THEN 'ISNULL([OrderLine].[Entity], '''') <> Members.[Entity] OR' ELSE '' END + '
					' + CASE WHEN @MappingTypeID <> 0 THEN 'ISNULL([OrderLine].[Entity_MemberID], 0) <> [Members].[Entity_MemberID] OR' ELSE '' END + '
					' + CASE WHEN @NodeTypeBMYN <> 0 THEN  'ISNULL([OrderLine].[NodeTypeBM], 0) <> [Members].[NodeTypeBM] OR [OrderLine].[NodeTypeBM] IS NULL OR' ELSE '' END + '
					[OrderLine].[Source] <> Members.[Source]
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
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Members].[MemberKeyBase],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Members].[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Members].[Entity_MemberID],' ELSE '' END + '
				[Members].[RNodeType],
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[Members].[NodeTypeBM],' ELSE '' END + '
				[Members].[SBZ],
				[Members].[Synchronized],
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				[Members].[Source]
			FROM   
				[#OrderLine_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [OrderLine] WHERE Members.Label = [OrderLine].Label)'

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

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#OrderLine_Members]
		DROP TABLE [#EB]

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
