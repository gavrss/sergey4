SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Dimension_Slave_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL,
	@DimensionName nvarchar(100) = NULL,
	@HierarchyNo int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000660,
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
EXEC [spIU_Dim_Dimension_Slave_Callisto] @UserID = -10, @InstanceID = 476, @VersionID = 1024, @DimensionID = -31, @DebugBM = 7
EXEC [spIU_Dim_Dimension_Slave_Callisto] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @DimensionID = -31, @DebugBM = 1
EXEC [spIU_Dim_Dimension_Slave_Callisto] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @DimensionID = -32, @DebugBM = 1
EXEC [spIU_Dim_Dimension_Slave_Callisto] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @DimensionID = -32, @DebugBM = 1

EXEC [spIU_Dim_Dimension_Slave_Callisto] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF
--SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@CallistoDatabase nvarchar(100),
	@Dimensionhierarchy nvarchar(100),
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
			@ProcedureDescription = 'Insert rows into selected Callisto dimension table.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2153' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
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

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF @DimensionName IS NULL
			SELECT @DimensionName = DimensionName FROM [Dimension] WHERE DimensionID = @DimensionID
		ELSE IF @DimensionID IS NULL
			SELECT @DimensionID = DimensionID FROM [Dimension] WHERE DimensionName = @DimensionName	AND InstanceID IN (0, @InstanceID)	

		SET @Dimensionhierarchy = @DimensionName + '_' + @DimensionName

		SELECT
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

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
				[@LogPropertyYN] = @LogPropertyYN,
				[@NodeTypeBMYN] = @NodeTypeBMYN

		IF @DebugBM & 2 > 0
			SELECT
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@CallistoDatabase] = @CallistoDatabase,
				[@LogPropertyYN] = @LogPropertyYN,
				[@NodeTypeBMYN] = @NodeTypeBMYN

	SET @Step = 'Create temp tables'
		CREATE TABLE #Dimension_Slave_Members
			(
			[MemberId] int,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,				
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Fetch members'
		EXEC [spIU_Dim_Dimension_Slave_Raw] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DimensionID=@DimensionID, @DimensionName=@DimensionName, @JobID=@JobID, @Debug=@DebugSub

		UPDATE #Dimension_Slave_Members SET [Label] = [MemberKey], [RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END
		
		IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension_Slave_Members', * FROM #Dimension_Slave_Members

	SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[' + @DimensionName + ']
			SET
				[Description] = Members.[Description], 
				[HelpText] = Members.[HelpText],
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM] = Members.[NodeTypeBM],' ELSE '' END + '
				[Source] = Members.[Source]  
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] 
				INNER JOIN [#Dimension_Slave_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [' + @DimensionName + '].LABEL 
			WHERE 
				[' + @DimensionName + '].[Synchronized] <> 0'

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
				[RNodeType],
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated],' ELSE '' END + '
				[SBZ],
				[Source],
				[Synchronized]				)
			SELECT
				[MemberId],
				[Label],
				[Description],
				[HelpText],
				[RNodeType],
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				[SBZ],
				[Source],
				[Synchronized]
			FROM   
				[#Dimension_Slave_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] WHERE Members.Label = [' + @DimensionName + '].Label)'

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
			{"TKey" : "SourceTable",  "TValue": "#Dimension_Slave_Members"},
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
		DROP TABLE [#Dimension_Slave_Members]

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		SET @ProcedureName = @ProcedureName + ' (' + @DimensionName + ')'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	SET @ProcedureName = @ProcedureName + ' (' + @DimensionName + ')'
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
