SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spIU_Dim_Scenario_Callisto_20230118]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	--SP-specific parameters
	@DimensionID INT = -6,  
	@HierarchyNo INT = NULL,
	--NB New hierarchy routines are not yet implemented

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000651,
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
EXEC [spIU_Dim_Scenario_Callisto] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @DebugBM = 1
EXEC [spIU_Dim_Scenario_Callisto] @UserID = -10, @InstanceID = -1318, @VersionID = -1256, @DebugBM = 1
EXEC [spIU_Dim_Scenario_Callisto] @UserID = -10, @InstanceID = 533, @VersionID = 1058, @DebugBM = 1

EXEC [spIU_Dim_Scenario_Callisto] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@CallistoDatabase nvarchar(100),

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
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into Callisto Scenario dimension tables.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2153' SET @Description = 'Pass @JobID.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle SIE4.'

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

		SELECT
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Create temp tables'
		CREATE TABLE #Scenario_Members
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[WorkflowState_MemberID] bigint,
			[WorkflowState] nvarchar(255),
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,				
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Fetch members'
		EXEC [spIU_Dim_Scenario_Raw] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @Debug = @DebugSub

		UPDATE #Scenario_Members SET [Label] = [MemberKey], [RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END
		SET @SQLStatement = '
			UPDATE
				[Members]
			SET
				[WorkflowState] = WFS.[Label]
			FROM
				[#Scenario_Members] Members
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_WorkflowState] [WFS] ON WFS.MemberId = [Members].[WorkflowState_MemberID]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Scenario_Members', * FROM #Scenario_Members

	SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[Scenario]
			SET
				[Description] = Members.[Description], 
				[HelpText] = Members.[HelpText], 
				[WorkflowState_MemberID] = Members.[WorkflowState_MemberID], 
				[WorkflowState] = Members.[WorkflowState], 
				[Source] = Members.[Source]  
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_Scenario] [Scenario] 
				INNER JOIN [#Scenario_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [Scenario].LABEL 
			WHERE 
				[Scenario].[Synchronized] <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT
		
	SET @Step = 'Insert new members from source system'
		SET @SQLStatement = '
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_Scenario]
				(
				[MemberId],
				[Label],
				[Description],
				[HelpText],
				[WorkflowState_MemberID], 
				[WorkflowState], 
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
				[WorkflowState_MemberID], 
				[WorkflowState], 
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized]
			FROM   
				[#Scenario_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Scenario] [Scenario] WHERE Members.Label = [Scenario].Label)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update MemberId'
		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = N'Scenario', @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Insert new members into the default hierarchy. Not Synchronized members will not be added.'
		SET @SQLStatement = '
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_HS_Scenario_Scenario]
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
				[' + @CallistoDatabase + '].[dbo].[S_DS_Scenario] D1
				INNER JOIN [#Scenario_Members] V ON V.[Label] COLLATE DATABASE_DEFAULT = D1.[Label]
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Scenario] D2 ON D2.Label = CONVERT(nvarchar(255), V.Parent) COLLATE DATABASE_DEFAULT
			WHERE
				D1.[Synchronized] <> 0 AND
				D1.[MemberId] <> ISNULL(D2.[MemberId], 0) AND
				D1.[MemberId] IS NOT NULL AND
				(D2.[MemberId] IS NOT NULL OR D1.[Label] = ''All_'' OR V.[Parent] IS NULL) AND
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_HS_Scenario_Scenario] H WHERE H.[MemberId] = D1.[MemberId])
			ORDER BY
				D1.[MemberId]'

		IF @DebugBM & 1 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
	SET @Step = 'Delete parents without children.'
		SET @SQLStatement = '
			DELETE H
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_HS_Scenario_Scenario] H
				INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Scenario] DL ON DL.[MemberID] = H.[MemberID] AND DL.[RNodeType] = ''P''
			WHERE
				NOT EXISTS (SELECT DISTINCT HD.[ParentMemberID] FROM [' + @CallistoDatabase + '].[dbo].[S_HS_Scenario_Scenario] HD WHERE HD.[ParentMemberID] = H.[MemberID])'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Copy the hierarchy to all instances'
		EXEC [pcINTEGRATOR].[dbo].[spSet_HierarchyCopy] @Database = @CallistoDatabase, @Dimensionhierarchy = N'Scenario_Scenario', @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_Scenario]'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_Scenario]')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#Scenario_Members]

	SET @Step = 'Set @Duration'	
		SET @Duration = GETDATE() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GETDATE() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
