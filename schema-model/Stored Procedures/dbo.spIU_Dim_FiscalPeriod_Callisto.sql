SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_FiscalPeriod_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -76,
	@HierarchyNo int = NULL,
	@SequenceBMStep int = 65535, --1 = Parent level, 2 = Leaf level
	@StaticMemberYN bit = 1,
	@SourceTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000806,
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
EXEC [spIU_Dim_FiscalPeriod_Callisto] @UserID=-10, @InstanceID=531, @VersionID=1057, @DebugBM=7
EXEC [spIU_Dim_FiscalPeriod_Callisto] @UserID = -10, @InstanceID = 574, @VersionID = 1045, @DebugBM=7 --GMN
EXEC [spIU_Dim_FiscalPeriod_Callisto] @UserID = -10, @InstanceID = 531, @VersionID = 1041, @DebugBM=7 --PCX

EXEC [spIU_Dim_FiscalPeriod_Callisto] @UserID = -10, @InstanceID = 1020, @VersionID = 1415, @DebugBM=7 --EFPA2

EXEC [spIU_Dim_FiscalPeriod_Callisto] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@DimensionName nvarchar(50),
	@SourceDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@LinkedYN bit,
	@MappingTypeID int,
	@SQLStatement nvarchar(max),
	@JSON nvarchar(max),
	@ParentsWithoutChildrenCount int = 1,
	@LogPropertyYN BIT = 0, --Properties JobID, Inserted & Updated
	@StorageTypeBM int = 4,
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
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into FiscalPeriod.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2176' SET @Description = 'Procedure created. DB-697 Create SP for loading new dimension FiscalPeriod (generic)'
		IF @Version = '2.1.2.2179' SET @Description = 'Use sub routine [spSet_Hierarchy].'
		IF @Version = '2.1.2.2199' SET @Description = 'Look for table FiscalCalendar in pcETL.'

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
			@CallistoDatabase = A.[DestinationDatabase]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		SELECT
			@DimensionName = D.[DimensionName]
		FROM
			[pcINTEGRATOR].[dbo].[Dimension] D
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

	SET @Step = 'Create table #FiscalPeriod_Members'
		CREATE TABLE #FiscalPeriod_Members
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[TimeFiscalYear] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalYear_MemberId] bigint,
			[TimeFiscalPeriod] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[TimeFiscalPeriod_MemberId] bigint,	
			[Time] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Time_MemberId] bigint,
			[NodeTypeBM] int,
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,
			[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Handle ANSI_WARNINGS'
--		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	--SET @Step = 'Check for not synchronized parents'
	--	CREATE TABLE #NoSyncParent
	--		(
	--		[MemberId] bigint,
	--		[MemberKey] nvarchar(255) COLLATE DATABASE_DEFAULT
	--		)
			
	--	SET @SQLStatement = '
	--		INSERT INTO #NoSyncParent
	--			(
	--			[MemberId],
	--			[MemberKey]
	--			)
	--		SELECT
	--			[MemberId] = D.[MemberId],
	--			[MemberKey] = D.[Label]
	--		FROM
	--			' + @CallistoDatabase + '.[dbo].[S_DS_FiscalPeriod] D
	--		WHERE
	--			D.[Synchronized] = 0 AND
	--			NOT EXISTS (SELECT 1 FROM ' + @CallistoDatabase + '.[dbo].[S_HS_FiscalPeriod_FiscalPeriod] H WHERE H.[MemberId] = D.[MemberId])
	--		ORDER BY
	--			D.[Label]'

	--	IF @DebugBM & 2 > 0 PRINT @SQLStatement
	--	EXEC (@SQLStatement)

	--	IF @DebugBM & 2 > 0 SELECT TempTable = '#NoSyncParent', * FROM #NoSyncParent ORDER BY [MemberKey]

	SET @Step = 'Fetch members'
		EXEC [spIU_Dim_FiscalPeriod_Raw] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SequenceBMStep=@SequenceBMStep, @StaticMemberYN=@StaticMemberYN, @JobID=@JobID, @Debug=@DebugSub

		UPDATE FPM
		SET
			[Label] = [MemberKey], 
			[RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END
		FROM
			#FiscalPeriod_Members  FPM

		SET @SQLStatement = '
			UPDATE
				[Members]
			SET
				[TimeFiscalYear] = ISNULL(TFY.[Label], ''NONE''),
				[TimeFiscalYear_MemberId] = ISNULL(TFY.[MemberId], -1),
				[TimeFiscalPeriod] = ISNULL(TFP.[Label], ''NONE''),
				[TimeFiscalPeriod_MemberId] = ISNULL(TFP.[MemberId], -1),
				[Time] = ISNULL(T.[Label], ''NONE''),
				[Time_MemberId] = ISNULL(T.[MemberId], -1)
			FROM
				[#FiscalPeriod_Members] Members
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_TimeFiscalYear] [TFY] ON TFY.[MemberId] = [Members].[TimeFiscalYear_MemberId]
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_TimeFiscalPeriod] [TFP] ON TFP.[MemberId] = [Members].[TimeFiscalPeriod_MemberId]
				LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_Time] [T] ON T.[MemberId] = [Members].[Time_MemberId]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 8 > 0 SELECT TempTable = '#FiscalPeriod_Members', * FROM #FiscalPeriod_Members ORDER BY MemberKey

	SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[' + @DimensionName + ']
			SET
				[Description] = Members.[Description], 
				[HelpText] = Members.[HelpText], 
				[TimeFiscalYear] = Members.[TimeFiscalYear], 
				[TimeFiscalYear_MemberId] = Members.[TimeFiscalYear_MemberId], 
				[TimeFiscalPeriod] = Members.[TimeFiscalPeriod], 
				[TimeFiscalPeriod_MemberID] = Members.[TimeFiscalPeriod_MemberID],
				[Time] = Members.[Time], 
				[Time_MemberId] = Members.[Time_MemberId], 
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
					[' + @DimensionName + '].[TimeFiscalYear] <> Members.[TimeFiscalYear] OR  
					[' + @DimensionName + '].[TimeFiscalYear_MemberId] <> Members.[TimeFiscalYear_MemberId] OR  
					[' + @DimensionName + '].[TimeFiscalPeriod] <> Members.[TimeFiscalPeriod] OR  
					[' + @DimensionName + '].[TimeFiscalPeriod_MemberID] <> Members.[TimeFiscalPeriod_MemberID] OR
					[' + @DimensionName + '].[Time] <> Members.[Time] OR 
					[' + @DimensionName + '].[Time_MemberId] <> Members.[Time_MemberId] OR 
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
				[TimeFiscalYear], 
				[TimeFiscalYear_MemberId], 
				[TimeFiscalPeriod],
				[TimeFiscalPeriod_MemberID],
				[Time], 
				[Time_MemberId], 
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
				[TimeFiscalYear], 
				[TimeFiscalYear_MemberId], 
				[TimeFiscalPeriod],
				[TimeFiscalPeriod_MemberID],
				[Time], 
				[Time_MemberId], 
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
				[#' + @DimensionName + '_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] WHERE Members.[Label] = [' + @DimensionName + '].[Label])'

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

				EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSet_LeafLevelFilter_ClearCache', @JSON = @JSON
			END

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#FiscalPeriod_Members]

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
