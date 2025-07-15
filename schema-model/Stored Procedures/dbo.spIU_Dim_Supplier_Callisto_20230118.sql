SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spIU_Dim_Supplier_Callisto_20230118]
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
	@SourceTypeID int = NULL,
	@SourceDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@LinkedYN bit,
	@MappingTypeID int,
	@SQLStatement nvarchar(max),

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
	@Version nvarchar(50) = '2.1.0.2166'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into Callisto Supplier tables from different sources.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2166' SET @Description = 'Added [SupplierCategory].'

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
			@MappingTypeID = ISNULL(@MappingTypeID, MappingTypeID)
		FROM
			pcINTEGRATOR_Data.dbo.[Dimension_StorageType]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF @DebugBM & 2 > 0 SELECT [@CallistoDatabase] = @CallistoDatabase, [@MappingTypeID] = @MappingTypeID

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
				[Source] = Members.[Source]  
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_Supplier] [Supplier] 
				INNER JOIN [#Supplier_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [Supplier].LABEL 
			WHERE 
				[Supplier].[Synchronized] <> 0'

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
				[SBZ],
				[Source],
				[Synchronized]
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
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized]
			FROM   
				[#Supplier_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Supplier] [Supplier] WHERE Members.Label = [Supplier].Label)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update MemberId'
		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = N'Supplier', @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Check which parent members have leaf members as children.'
		
		CREATE TABLE #LeafCheck
			(
			[MemberId] [bigint] NOT NULL,
			HasChild bit NOT NULL
			)

		EXEC [pcINTEGRATOR].[dbo].[spSet_LeafCheck] @Database = @CallistoDatabase, @Dimension = N'Supplier', @JobID = @JobID, @Debug = @DebugSub
		IF @DebugBM & 2 > 0 SELECT TempTable = '#LeafCheck', * FROM #LeafCheck	

	SET @Step = 'Insert new members into the default hierarchy. Not Synchronized members will not be added. To change the hierarchy, use the Modeler.'
		SET @SQLStatement = '
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_Supplier_Supplier]
				(
				[MemberId],
				[ParentMemberId],
				[SequenceNumber]
				)
			SELECT
				[MemberId] = D1.MemberId,
				[ParentMemberId] = ISNULL(D2.MemberId, 0),
				[SequenceNumber] = D1.MemberId 
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_Supplier] D1
				INNER JOIN [#Supplier_Members] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Supplier] D2 ON D2.Label = CONVERT(nvarchar(255), V.Parent) COLLATE DATABASE_DEFAULT
				LEFT JOIN [#LeafCheck] LC ON LC.MemberId = D1.MemberId AND LC.HasChild <> 0
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_Supplier_Supplier] H WHERE H.MemberId = D1.MemberId) AND
				[D1].[Synchronized] <> 0 AND
				D1.MemberId <> ISNULL(D2.MemberId, 0) AND
				D1.MemberId IS NOT NULL AND
				(D2.MemberId IS NOT NULL OR D1.Label = ''All_'' OR V.Parent IS NULL) AND
				(D1.RNodeType IN (''L'', ''LC'') OR LC.MemberId IS NOT NULL)
			ORDER BY
				D1.MemberId'

		IF @DebugBM & 1 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Copy the hierarchy to all instances'
		EXEC [pcINTEGRATOR].[dbo].[spSet_HierarchyCopy] @Database = @CallistoDatabase, @Dimensionhierarchy = N'Supplier_Supplier', @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_Supplier]'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Supplier]')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#Supplier_Members]
		DROP TABLE [#LeafCheck]

	SET @Step = 'Set @Duration'	
		SET @Duration = GETDATE() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GETDATE() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
