SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Dimension_Generic_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL,
	@HierarchyNo int = NULL, --Optional
	@SourceTypeID int = NULL, --Optional
	@DataOriginID int = NULL, --Optional
	@DimensionName nvarchar(100) = NULL,
	@RefreshHierarchyYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000657,
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
EXEC spIU_Dim_Dimension_Generic_Callisto @Debug='0',@DimensionID='-69',@InstanceID='485',@JobID='11',@UserID='-10',@VersionID='1034',@DebugBM = 7
EXEC [spIU_Dim_Dimension_Generic_Callisto] @UserID = -10, @InstanceID = 561, @VersionID = 1071, @DimensionID = 5605, @DebugBM = 7
EXEC [spIU_Dim_Dimension_Generic_Callisto] @UserID = -10, @InstanceID = 424, @VersionID = 1017, @DimensionID = -64, @DebugBM = 1
EXEC [spIU_Dim_Dimension_Generic_Callisto] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @DimensionID = -55, @DebugBM = 1
EXEC [spIU_Dim_Dimension_Generic_Callisto] @UserID = -10, @InstanceID = 514, @VersionID = 1047, @DimensionID = -34, @DebugBM = 1 --STN, Flow
EXEC [spIU_Dim_Dimension_Generic_Callisto] @UserID = -10, @InstanceID = 515, @VersionID = 1040, @DimensionID = -34, @DebugBM = 1 --STN, Flow
EXEC [spIU_Dim_Dimension_Generic_Callisto] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @DimensionID = -53, @DebugBM = 3
EXEC [spIU_Dim_Dimension_Generic_Callisto] @UserID = -10, @InstanceID = 15, @VersionID = 1039, @DimensionID = -27, @DebugBM = 3

EXEC [spIU_Dim_Dimension_Generic_Callisto] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF
--SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@SQLStatement_Insert nvarchar(2000) = '',
	@SQLStatement_Select nvarchar(2000) = '',
	@CallistoDatabase nvarchar(100),
	@DimensionHierarchy nvarchar(100),
	@AddString nvarchar (255),
	@StorageTypeBM int = 4,
	@HierarchyName nvarchar(100),
	@JSON nvarchar(max),
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
	@ModifiedBy nvarchar(50) = 'AlGA',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert rows into selected Callisto dimension table.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Handle multiple hierarchies.'
		IF @Version = '2.1.0.2161' SET @Description = 'Added default parameters to subroutines. Added SP-check if @CallistoDatabase is not set/selected. Changed prefix in the SP name.'
		IF @Version = '2.1.0.2163' SET @Description = 'Modified query on setting [AddString] column when inserting into temp table [@PropertyColumn].'
		IF @Version = '2.1.0.2167' SET @Description = 'Modified query on setting [AddString] column when inserting into temp table [@PropertyColumn]. Null check on Size for nvarchar. Removed sub routine LeafCheck.'
		IF @Version = '2.1.2.2178' SET @Description = 'Handle existence of NodeTypeBM as Property in the dimension table.'
		IF @Version = '2.1.2.2179' SET @Description = 'Use sub routine [spSet_Hierarchy].'
		IF @Version = '2.1.2.2199' SET @Description = 'Adding parameter @DataOriginID and @SourceTypeID in order to add new members from BAQ.'


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
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@CallistoDatabase] = @CallistoDatabase,
				[@LogPropertyYN] = @LogPropertyYN,
				[@NodeTypeBMYN] = @NodeTypeBMYN

	SET @Step = 'Check if @CallistoDatabase is set/selected'
		IF @CallistoDatabase IS NULL
			BEGIN
				SET @Message = 'CallistoDatabase is not set/selected.'
				SET @Severity = 10
				GOTO EXITPOINT
			END

	SET @Step = 'Create temp tables'
		CREATE TABLE [#Dimension_Generic_Members]
			(
			[MemberId] int,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[HierarchyNo] int
			)

	SET @Step = 'Create temp table #PropertyColumn'
		CREATE TABLE #PropertyColumn
			(
			[DimensionID] int,
			[PropertyID] int,
			[PropertyName] nvarchar (100) COLLATE DATABASE_DEFAULT,
			[ColumnName] nvarchar (100) COLLATE DATABASE_DEFAULT,
			[DefaultValue] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[AddString] nvarchar (255) COLLATE DATABASE_DEFAULT,
			[SortOrder] int IDENTITY (1,1)
			)

		INSERT INTO #PropertyColumn
			(
			[DimensionID],
			[PropertyID],
			[PropertyName],
			[ColumnName],
			[DefaultValue],
			[AddString]
			)
		SELECT 
			[DimensionID] = NULL,
			[PropertyID] = DP.[PropertyID],
			[PropertyName] = P.PropertyName,
			[ColumnName] = P.PropertyName,
			[DefaultValue] = P.[DefaultValueTable],
			[AddString] = '[' + P.[PropertyName] + '] ' + DT.[DataTypeCode] + CASE WHEN DT.[SizeYN] = 0 THEN '' ELSE CASE WHEN P.[Size] IS NULL OR CHARINDEX('(', DT.[DataTypeCode]) <> 0 THEN '' ELSE ' (' + CONVERT(nvarchar(15), P.[Size]) + ') COLLATE DATABASE_DEFAULT' END END
		FROM
			Dimension_Property DP
			INNER JOIN Property P ON P.[InstanceID] IN (0, @InstanceID) AND P.[PropertyID] = DP.[PropertyID] AND P.[SelectYN] <> 0
			INNER JOIN DataType DT ON DT.[DataTypeID] = P.[DataTypeID]
		WHERE
			DP.[InstanceID] IN (0, @InstanceID) AND
			DP.VersionID IN (0, @VersionID) AND
			DP.DimensionID = @DimensionID AND
			DP.[SelectYN] <> 0
		UNION
		SELECT 
			[DimensionID] = P.[DependentDimensionID],
			[PropertyID] = NULL,
			[PropertyName] = P.PropertyName,
			[ColumnName] = P.PropertyName + '_MemberId',
			[DefaultValue] = NULL,
			[AddString] = '[' + P.[PropertyName] + '_MemberId] bigint'
		FROM
			Dimension_Property DP
			INNER JOIN Property P ON P.[InstanceID] IN (0, @InstanceID) AND P.[PropertyID] = DP.[PropertyID] AND P.[SelectYN] <> 0 AND P.[DataTypeID] = 3
		WHERE
			DP.[InstanceID] IN (0, @InstanceID) AND
			DP.VersionID IN (0, @VersionID) AND
			DP.DimensionID = @DimensionID AND
			DP.[SelectYN] <> 0
		ORDER BY
			PropertyName,
			DimensionID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#PropertyColumn', * FROM #PropertyColumn ORDER BY SortOrder

	SET @Step = 'Add columns to temp table [#Dimension_Generic_Members]'
		IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
		DECLARE AddColumn_Cursor CURSOR FOR
			SELECT
				AddString
			FROM
				#PropertyColumn
			WHERE
				[PropertyName] NOT IN ('MemberId', 'MemberKey', 'Label', 'Description', 'HelpText', 'NodeTypeBM', 'HierarchyNo', 'RNodeType', 'SBZ', 'Source', 'Synchronized', 'Parent')
			ORDER BY
				SortOrder

			OPEN AddColumn_Cursor
			FETCH NEXT FROM AddColumn_Cursor INTO @AddString

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@AddString] = @AddString
					SET @SQLStatement = 'ALTER TABLE #Dimension_Generic_Members ADD ' + @AddString

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM AddColumn_Cursor INTO @AddString
				END

		CLOSE AddColumn_Cursor
		DEALLOCATE AddColumn_Cursor	

		ALTER TABLE #Dimension_Generic_Members ADD [RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT
		ALTER TABLE #Dimension_Generic_Members ADD [SBZ] bit
		ALTER TABLE #Dimension_Generic_Members ADD [Source] nvarchar (50) COLLATE DATABASE_DEFAULT
		ALTER TABLE #Dimension_Generic_Members ADD [Synchronized] bit
		ALTER TABLE #Dimension_Generic_Members ADD [Parent] nvarchar (255) COLLATE DATABASE_DEFAULT

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension_Generic_Members', * FROM #Dimension_Generic_Members

	SET @Step = 'Fetch members'
		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
			{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(15), @DimensionID) + '"},
			{"TKey" : "DimensionName",  "TValue": "' + @DimensionName + '"},
			{"TKey" : "StorageTypeBM",  "TValue": "' + CONVERT(nvarchar(15), @StorageTypeBM) + '"},
			{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
			{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), CONVERT(int, @DebugSub)) + '"}'
			+ CASE WHEN @SourceTypeID IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "SourceTypeID",  "TValue": "' + CONVERT(nvarchar(10), @SourceTypeID) + '"}' ELSE '' END +
			+ CASE WHEN @DataOriginID IS NOT NULL THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '{"TKey" : "DataOriginID",  "TValue": "' + CONVERT(nvarchar(10), @DataOriginID) + '"}' ELSE '' END +
			']'

		IF @DebugBM & 2 > 0 PRINT @JSON
		EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spIU_Dim_Dimension_Generic_Raw', @JSON = @JSON

		UPDATE #Dimension_Generic_Members SET [Label] = [MemberKey], [RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END
		
		IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension_Generic_Members', * FROM #Dimension_Generic_Members

	SET @Step = 'Create strings for extra property columns.'
		SELECT
			@SQLStatement_Insert = @SQLStatement_Insert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '],',
			@SQLStatement_Select = @SQLStatement_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '] = Members.[' +  ColumnName + '],'
		FROM
			#PropertyColumn
		ORDER BY
			SortOrder

	SET @Step = 'Update Description and dimension specific Properties from source system where Synchronized is set to true.'
		SET @SQLStatement = '
			UPDATE
				[' + @DimensionName + ']
			SET
				[Description] = Members.[Description], 
				[HelpText] = Members.[HelpText],' + @SQLStatement_Select + '
				[Source] = Members.[Source]  
			FROM
				[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] 
				INNER JOIN [#Dimension_Generic_Members] Members ON Members.Label COLLATE DATABASE_DEFAULT = [' + @DimensionName + '].LABEL 
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
				[HelpText],' + @SQLStatement_Insert + '
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized]
				)
			SELECT
				[MemberId],
				[Label],
				[Description],
				[HelpText],' + @SQLStatement_Select + '
				[RNodeType],
				[SBZ],
				[Source],
				[Synchronized]
			FROM   
				[#Dimension_Generic_Members] Members
			WHERE
				NOT EXISTS (SELECT 1 FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] [' + @DimensionName + '] WHERE Members.Label = [' + @DimensionName + '].Label)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update MemberId'
		EXEC [pcINTEGRATOR].[dbo].[spSet_MemberId]@UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Database = @CallistoDatabase, @Dimension = @DimensionName, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Update all hierarchies.'
		IF @RefreshHierarchyYN <> 0
			BEGIN
				SET @JSON = '
					[
					{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
					{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
					{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
					{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(15), @DimensionID) + '"},
					{"TKey" : "SourceTable",  "TValue": "#Dimension_Generic_Members"},
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
			END

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']')

	SET @Step = 'Drop temp tables'
		DROP TABLE [#Dimension_Generic_Members]

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
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
