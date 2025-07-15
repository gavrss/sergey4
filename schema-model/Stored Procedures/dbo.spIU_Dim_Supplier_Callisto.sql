SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spIU_Dim_Supplier_Callisto]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	--SP-specific parameters
	@DimensionID INT = -10, 
	@HierarchyNo INT = NULL,
	--NB New hierarchy routines are not yet implemented

	@SequenceBMStep INT = 65535, --1 = Parent level, 2 = Leaf level
	@StaticMemberYN BIT = 1,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000725,
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
EXEC [spIU_Dim_Supplier_Callisto] @UserID = -10, @InstanceID = 476, @VersionID = 1024, @DebugBM = 1
EXEC [spIU_Dim_Supplier_Callisto] @UserID=-10, @InstanceID=454, @VersionID=1021, @DebugBM = 3
EXEC [spIU_Dim_Supplier_Callisto] @UserID=-10, @InstanceID=413, @VersionID=1008, @DebugBM = 1
EXEC [spIU_Dim_Supplier_Callisto] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @DebugBM = 3
EXEC [spIU_Dim_Supplier_Callisto] @UserID = -10, @InstanceID = -1508, @VersionID = -1508, @DebugBM = 1

EXEC [spIU_Dim_Supplier_Callisto] @GetVersion = 1
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
	@MappingTypeID INT,
	@SQLStatement NVARCHAR(MAX),
	@JSON NVARCHAR(MAX),
	@LogPropertyYN BIT = 0, --Properties JobID, Inserted & Updated,
	@NodeTypeBMYN BIT = 0,
	@StorageTypeBM INT = 4,

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
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into Callisto Supplier tables from different sources.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2166' SET @Description = 'Added [SupplierCategory].'
		IF @Version = '2.1.2.2191' SET @Description = 'Use sub routine spSet_Hierarchy for hierarchy setup.'
		IF @Version = '2.1.2.2199' SET @Description = 'Update to latest SP template.'

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
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[pcINTEGRATOR].[dbo].[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		SELECT
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF @DebugBM & 2 > 0 SELECT [@CallistoDatabase] = @CallistoDatabase, [@MappingTypeID] = @MappingTypeID

		EXEC [pcINTEGRATOR].[dbo].[spGet_DimPropertyStatus]
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
		CREATE TABLE #Supplier_Members
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
			[PaymentDays] int,
			[SupplierCategory] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SupplierCategory_MemberID] bigint,
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
		EXEC [spIU_Dim_Supplier_Raw] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBMStep=@SequenceBMStep, @StaticMemberYN=@StaticMemberYN, @MappingTypeID=@MappingTypeID, @JobID=@JobID, @Debug=@DebugSub

		UPDATE #Supplier_Members 
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
						[#Supplier_Members] Members
						LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Entity] [E] ON E.[Label] = [Members].[Entity]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Supplier_Members', * FROM #Supplier_Members

	SET @SQLStatement = '
			UPDATE
				[Members]
			SET
				[SupplierCategory] = CASE WHEN SC.[MemberId] IS NULL THEN ''NONE'' ELSE [Members].[SupplierCategory] END,
				[SupplierCategory_MemberId] = ISNULL(SC.[MemberId], -1)
			FROM
				[#Supplier_Members] Members
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_SupplierCategory] [SC] ON [SC].[Label] = [Members].[SupplierCategory]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Supplier_Members', * FROM #Supplier_Members

	SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[Supplier]
			SET
				[Description] = Members.[Description], 
				[HelpText] = Members.[HelpText], 
				[PaymentDays] = Members.[PaymentDays], 
				[SupplierCategory] = Members.[SupplierCategory],
				[SupplierCategory_MemberId] = Members.[SupplierCategory_MemberId], 
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase] = Members.[MemberKeyBase],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity] = Members.[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberID] = Members.[Entity_MemberID],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN  '[NodeTypeBM] = [Members].[NodeTypeBM],' ELSE '' END + '
				[Source] = Members.[Source]
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_Supplier] [Supplier] 
				INNER JOIN [#Supplier_Members] Members ON Members.[Label] COLLATE DATABASE_DEFAULT = [Supplier].[Label]
			WHERE 
				[Supplier].[Synchronized] <> 0 AND
				(
					[Supplier].[Description] <> Members.[Description] OR
					[Supplier].[HelpText] <> Members.[HelpText] OR
					[Supplier].[PaymentDays] <> Members.[PaymentDays] OR 
					[Supplier].[SupplierCategory] <> Members.[SupplierCategory] OR  
					[Supplier].[SupplierCategory_MemberId] <> Members.[SupplierCategory_MemberId] OR  
					' + CASE WHEN @MappingTypeID <> 0 THEN 'ISNULL([Supplier].[MemberKeyBase], '''') <> [Members].[MemberKeyBase] OR' ELSE '' END + '
					' + CASE WHEN @MappingTypeID <> 0 THEN 'ISNULL([Supplier].[Entity], '''') <> Members.[Entity] OR' ELSE '' END + '
					' + CASE WHEN @MappingTypeID <> 0 THEN 'ISNULL([Supplier].[Entity_MemberID], 0) <> [Members].[Entity_MemberID] OR' ELSE '' END + '
					' + CASE WHEN @NodeTypeBMYN <> 0 THEN  'ISNULL([Supplier].[NodeTypeBM], 0) <> [Members].[NodeTypeBM] OR [Supplier].[NodeTypeBM] IS NULL OR' ELSE '' END + '
					[Supplier].[Source] <> Members.[Source]
				)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT
		
	SET @Step = 'Insert new members from source system'
		SET @SQLStatement = '
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_Supplier]
				(
				[MemberId],
				[Label],
				[Description],
				[HelpText],
				[PaymentDays],
				[SupplierCategory],
				[SupplierCategory_MemberId], 
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberId],' ELSE '' END + '
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
				[PaymentDays],
				[SupplierCategory],
				[SupplierCategory_MemberId], 
				' + CASE WHEN @MappingTypeID <> 0 THEN '[MemberKeyBase],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity],' ELSE '' END + '
				' + CASE WHEN @MappingTypeID <> 0 THEN '[Entity_MemberId],' ELSE '' END + '
				[Members].[RNodeType],
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[Members].[NodeTypeBM],' ELSE '' END + '
				[Members].[SBZ],
				[Members].[Synchronized],
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				[Members].[Source]
			FROM   
				[#Supplier_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Supplier] [Supplier] WHERE Members.Label = [Supplier].Label)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update MemberId'
		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = N'Supplier', @JobID = @JobID, @Debug = @DebugSub

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
					
		EXEC [pcINTEGRATOR].[dbo].[spRun_Procedure_KeyValuePair]
			@DatabaseName = 'pcINTEGRATOR',
			@ProcedureName = 'spSet_Hierarchy',
			@JSON = @JSON

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_Supplier]'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Supplier]')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#Supplier_Members]

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
