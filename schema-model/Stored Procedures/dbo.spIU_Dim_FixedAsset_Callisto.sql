SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_FixedAsset_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = -68,
	@HierarchyNo int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000665,
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
EXEC [spIU_Dim_FixedAsset_Callisto] @UserID=-10, @InstanceID = -1370, @VersionID = -1308, @DebugBM = 3
EXEC [spIU_Dim_FixedAsset_Callisto] @UserID = -10, @InstanceID = 574, @VersionID = 1045, @DebugBM=7 --GMN
EXEC [spIU_Dim_FixedAsset_Callisto] @UserID = -10, @InstanceID = 531, @VersionID = 1041, @DebugBM=7 --PCX

EXEC [spIU_Dim_FixedAsset_Callisto] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceTypeID int = NULL,
	@SourceDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@LinkedYN bit,
	@SQLStatement nvarchar(max),
	@DebugSub bit = 0,
	@JSON nvarchar(max),
	@StorageTypeBM int = 4,
	@LogPropertyYN bit,
	@NodeTypeBMYN bit,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into Callisto FixedAsset tables from different sources.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.2.2179' SET @Description = 'Use sub routine [spSet_Hierarchy].'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

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

	SET @Step = 'Create temp tables'
		CREATE TABLE #FixedAsset_Members
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[AssetClass] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[DateAcquired] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DateCommissioned] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[UsefulLifeMonths] int,
			[SalvageValue] bigint
			)

	SET @Step = 'Handle ANSI_WARNINGS'
--		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = 'Run SourceType_Cursor'
		IF CURSOR_STATUS('global','SourceType_Cursor') >= -1 DEALLOCATE SourceType_Cursor
		DECLARE SourceType_Cursor CURSOR FOR
			SELECT DISTINCT
				SourceTypeID,
				SourceDatabase
			FROM
				[Source] S
			WHERE
				S.InstanceID = @InstanceID AND
				S.VersionID = @VersionID AND
				S.SelectYN <> 0

			OPEN SourceType_Cursor
			FETCH NEXT FROM SourceType_Cursor INTO @SourceTypeID, @SourceDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@SourceTypeID] = @SourceTypeID, [@SourceDatabase] = @SourceDatabase

					EXEC [spIU_Dim_FixedAsset_Raw] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @SourceTypeID = @SourceTypeID, @SourceDatabase = @SourceDatabase, @JobID=@JobID, @Debug = @DebugSub

					FETCH NEXT FROM SourceType_Cursor INTO @SourceTypeID, @SourceDatabase
				END
		CLOSE SourceType_Cursor
		DEALLOCATE SourceType_Cursor
		
		SET ANSI_WARNINGS OFF

		UPDATE #FixedAsset_Members SET [Label] = [MemberKey], [RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FixedAsset_Members', * FROM #FixedAsset_Members

	SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[FixedAsset]
			SET
				[Description] = Members.[Description], 
				[HelpText] = Members.[HelpText], 
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM] = Members.[NodeTypeBM],' ELSE '' END + '
				[Source] = Members.[Source]  
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_FixedAsset] [FixedAsset] 
				INNER JOIN [#FixedAsset_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [FixedAsset].LABEL 
			WHERE 
				[FixedAsset].[Synchronized] <> 0'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT
		
	SET @Step = 'Insert new members from source system'
		SET @SQLStatement = '
			INSERT INTO [' + @CallistoDatabase + '].[dbo].[S_DS_FixedAsset]
				(
				[MemberId],
				[Label],
				[Description],
				[HelpText],
				[Entity],
				[AssetClass],
				[DateAcquired],
				[DateCommissioned],
				[UsefulLifeMonths],
				[SalvageValue],
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
				[Entity],
				[AssetClass],
				[DateAcquired],
				[DateCommissioned],
				[UsefulLifeMonths],
				[SalvageValue],
				[RNodeType],
				' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(nvarchar(50), FORMAT(GetDate(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
				[SBZ],
				[Source],
				[Synchronized]
			FROM   
				[#FixedAsset_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_FixedAsset] [FixedAsset] WHERE Members.Label = [FixedAsset].Label)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update MemberId'
		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId] @Database = @CallistoDatabase, @Dimension = N'FixedAsset', @JobID = @JobID, @Debug = @DebugSub

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

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_FixedAsset]'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_FixedAsset]')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#FixedAsset_Members]

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
