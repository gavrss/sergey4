SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spBR_BR16]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@EventTypeID int = 0,
	@BusinessRuleID int = NULL,
	@FromTime int = NULL,
	@ToTime int = NULL,
	@Filter nvarchar(max) = NULL,

	@DataClassID int = NULL,
	@BackupLogID_Reference int = NULL,
	@PurgePlanned datetime = NULL,
	@StoringDatabaseName nvarchar(100) = NULL,
	@CalledBy nvarchar(50) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000796,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*

EXEC [spBR_BR16] 
	@UserID='-10', 
	@InstanceID='454', 
	@VersionID='1021', 
	@DataClassID=7736,
	@FromTime = 201901,
	@ToTime = 201904,
	@Filter='Scenario=ACTUAL|Time§FromTime=202001|Time§ToTime=202003',
	@PurgePlanned = '2021-10-18 17:10:00',
	@DebugBM = 3

EXEC [spBR_BR16] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(MAX),
	@CallistoDatabase nvarchar(100),
	@SourceDatabase nvarchar(100),
	@DataClassName nvarchar(100),
	@TableName nvarchar(100),
	@StorageTypeBM int,
	@DataClassTypeID int,
	@SQLFilter nvarchar(4000) = '',
	@PipeString nvarchar(1000),
	@ColumnList nvarchar(4000),
	@SelectList nvarchar(4000),
	@BackupLogID int,
	@Time_DimensionID int,
	@FilterTime nvarchar(1000) = '',
	@CalledFromTime int = NULL,
	@CalledToTime int = NULL,

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
	@Version nvarchar(50) = '2.1.1.2174'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Backup selected DataClass',
			@MandatoryParameter = 'DataClassID' --Without @, separated by |

		IF @Version = '2.1.1.2173' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2174' SET @Description = 'Change Parameter @Parameter to @Filter.'

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

		SET @CalledBy = ISNULL(@CalledBy, @ProcedureName)

		SELECT
			@CalledFromTime = @FromTime,
			@CalledToTime = @ToTime

		SELECT
			@FromTime = ISNULL(@FromTime, [FromTime]),
			@ToTime = ISNULL(@ToTime, [ToTime]),
			@Filter = ISNULL(@Filter, [Filter]),
			@DataClassID = ISNULL(@DataClassID, [DataClassID]),
			@BackupLogID_Reference = ISNULL(@BackupLogID_Reference, [BackupLogID_Reference]),
			@PurgePlanned = ISNULL(@PurgePlanned, [PurgePlanned]),
			@StoringDatabaseName = ISNULL(@StoringDatabaseName, [StoringDatabaseName])
		FROM
			[pcINTEGRATOR_Data].[dbo].[BR16_Master]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[BusinessRuleID] = @BusinessRuleID AND
			[DeletedID] IS NULL
	
		SELECT
			@DataClassName = DC.[DataClassName],
			@StorageTypeBM = DC.[StorageTypeBM],
			@DataClassTypeID = DC.DataClassTypeID
		FROM
			[pcINTEGRATOR_Data].[dbo].[DataClass] DC
		WHERE
			DC.[InstanceID]=@InstanceID AND
			DC.[VersionID]=@VersionID AND
			DC.[DataClassID]=@DataClassID

		SELECT
			@StoringDatabaseName = ISNULL(@StoringDatabaseName, ETLDatabase),
			@CallistoDatabase = [DestinationDatabase],
			@SourceDatabase = CASE WHEN @StorageTypeBM & 2 > 0 THEN [ETLDatabase] ELSE [DestinationDatabase] END
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0


		SET @TableName =	CASE WHEN @StorageTypeBM & 2 > 0 
								THEN CASE WHEN @DataClassTypeID IN (-5) THEN '' ELSE 'pcDC_' END + @DataClassName
							ELSE CASE WHEN @StorageTypeBM & 4 > 0 
								THEN 'FACT_' + @DataClassName + '_default_partition' ELSE NULL END
							END

		IF @DebugBM & 2 > 0
			SELECT
				[@UserName] = @UserName,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@CalledFromTime] = @CalledFromTime,
				[@CalledToTime] = @CalledToTime,
				[@FromTime] = @FromTime,
				[@ToTime] = @ToTime,
				[@Filter] = @Filter,
				[@DataClassID] = @DataClassID,
				[@BackupLogID_Reference] = @BackupLogID_Reference,
				[@PurgePlanned] = @PurgePlanned,
				[@StoringDatabaseName] = @StoringDatabaseName,
				[@DataClassName] = @DataClassName,
				[@StoringDatabaseName] = @StoringDatabaseName,
				[@StorageTypeBM] = @StorageTypeBM,
				[@SourceDatabase] = @SourceDatabase,
				[@TableName] = @TableName

	SET @Step = 'Handle filter settings'
		CREATE TABLE #FilterTable
			(
			[StepReference] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[TupleNo] int,
			[DimensionID] int,
			[DimensionTypeID] int,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[ObjectReference] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[HierarchyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[PropertyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[JournalColumn] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[Filter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[PropertyFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[Segment] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[Method] nvarchar(20) COLLATE DATABASE_DEFAULT
			)

		EXEC pcINTEGRATOR..spGet_FilterTable
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@StepReference = 'BR16',
			@PipeString = @Filter,
			@StorageTypeBM_DataClass = @StorageTypeBM,
			@StorageTypeBM = 4,
			@JobID = @JobID,
			@Debug = @DebugSub

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable

	SET @Step = 'Create table #Columns'
		CREATE TABLE #Columns
		(
		ColumnName nvarchar(100) COLLATE DATABASE_DEFAULT,
		DataType nvarchar(100),
		SortOrder int
		)

		SET @SQLStatement = '
			INSERT INTO #Columns
				(
				[ColumnName],
				[DataType],
				[SortOrder]
				)
			SELECT 
				[ColumnName] = c.[name],
				[DataType] = Ty.[name] + CASE WHEN c.[collation_name] IS NULL THEN '''' ELSE ''('' + CONVERT(nvarchar(15), c.[max_length]/2) + '') COLLATE '' + c.[collation_name] END,
				[SortOrder] = c.[column_id]
			FROM 
				[' + @SourceDatabase + '].[sys].[tables] t 
				INNER JOIN [' + @SourceDatabase + '].[sys].[columns] c ON c.[object_id] = t.[object_id]
				INNER JOIN [' + @SourceDatabase + '].[sys].[types] Ty ON Ty.[system_type_id] = c.[system_type_id] AND Ty.[user_type_id] = c.[user_type_id]
			WHERE
				t.[name] = ''' + @TableName + '''
			ORDER BY
				c.[column_id]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @DebugBM & 2 > 0 SELECT TempTable='#Columns', * FROM #Columns ORDER BY [SortOrder]

	SET @Step = 'Set @Time_DimensionID, @FromTime and @ToTime'
		SELECT
			@FromTime = COALESCE(@CalledFromTime, CASE WHEN [ObjectReference] = 'FromTime' THEN [Filter] ELSE NULL END, @FromTime),
			@ToTime = COALESCE(@CalledToTime, CASE WHEN [ObjectReference] = 'ToTime' THEN [Filter] ELSE NULL END, @ToTime)
		FROM
			#FilterTable
		WHERE
			[StepReference] = 'BR16' AND
			[DimensionID] = -7 AND
			[ObjectReference] IN ('FromTime', 'ToTime')

		IF @FromTime IS NOT NULL OR @ToTime IS NOT NULL
			BEGIN
				SELECT @Time_DimensionID = CASE WHEN COUNT(1) > 0 THEN -7 END FROM #Columns WHERE [ColumnName] = 'Time_MemberId'
				IF @Time_DimensionID IS NULL SELECT @Time_DimensionID = CASE WHEN COUNT(1) > 0 THEN -49 END FROM #Columns WHERE [ColumnName] = 'TimeDay_MemberId'

				IF @FromTime IS NOT NULL AND @Time_DimensionID = -49 SET @FromTime = @FromTime * 100 + 1
				IF @ToTime IS NOT NULL AND @Time_DimensionID = -49 SET @ToTime = @ToTime * 100 + 31

				IF @DebugBM & 2 > 0 SELECT [@Time_DimensionID] = @Time_DimensionID, [@FromTime] = @FromTime, [@ToTime] = @ToTime
			END

	SET @Step = 'Insert into  table [pcINTEGRATOR_Log].[dbo].[BackupLog]'
		INSERT INTO [pcINTEGRATOR_Log].[dbo].[BackupLog]
			(
			[InstanceID],
			[VersionID],
			[CalledBy],
			[DataClassID],
			[FromTime],
			[ToTime],
			[Filter],
			[BackupLogID_Reference],
			[PurgePlanned],
			[DatabaseName],
			[TableName],
			[Rows],
			[UserID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[CalledBy] = @CalledBy,
			[DataClassID] = @DataClassID,
			[FromTime] = @FromTime,
			[ToTime] = @ToTime,
			[Filter] = @Filter,
			[BackupLogID_Reference] = @BackupLogID_Reference,
			[PurgePlanned] = @PurgePlanned,
			[DatabaseName] = @StoringDatabaseName,
			[TableName] = @TableName,
			[Rows] = 0,
			[UserID] = @UserID

		SET @BackupLogID = @@IDENTITY

	SET @Step = 'Create destination table'
		SELECT @ColumnList = '', @SelectList = ''
							
		SELECT
			@ColumnList = @ColumnList + CHAR(13) + CHAR(10) + CHAR(9) + '[' + [ColumnName] + '] ' + [DataType] + ',',
			@SelectList = @SelectList + CHAR(13) + CHAR(10) + CHAR(9) + '[' + [ColumnName] + '],'
		FROM
			#Columns
		ORDER BY
			[SortOrder]	
			
		SELECT
			@ColumnList = LEFT(@ColumnList, LEN(@ColumnList) - 1),
			@SelectList = LEFT(@SelectList, LEN(@SelectList) - 1)

		SET @SQLStatement = '
CREATE TABLE [' + @StoringDatabaseName + '].[dbo].[BU_' + @TableName + '_' + CONVERT(nvarchar(15), @BackupLogID) + ']
	(' + @ColumnList + '
	)'
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)


	SET @Step = 'Insert data'
		SET @SQLStatement = '
INSERT INTO [' + @StoringDatabaseName + '].[dbo].[BU_' + @TableName + '_' + CONVERT(nvarchar(15), @BackupLogID) + ']
	(' + @SelectList + '
	)
SELECT ' + @SelectList + '
FROM
	[' + @SourceDatabase + '].[dbo].[' + @TableName + ']
WHERE'

		IF @Time_DimensionID = -7
			BEGIN
				IF @FromTime IS NOT NULL SET @FilterTime = @FilterTime + CHAR(13) + CHAR(10) + CHAR(9) + '[Time_MemberId] >= ' + CONVERT(nvarchar(15), @FromTime) + ' AND'
				IF @ToTime IS NOT NULL SET @FilterTime = @FilterTime + CHAR(13) + CHAR(10) + CHAR(9) + '[Time_MemberId] <= ' + CONVERT(nvarchar(15), @ToTime) + ' AND'
			END
		ELSE IF @Time_DimensionID = -49
			BEGIN
				IF @FromTime IS NOT NULL SET @FilterTime = @FilterTime + CHAR(13) + CHAR(10) + CHAR(9) + '[TimeDay_MemberId] >= ' + CONVERT(nvarchar(15), @FromTime) + ' AND'
				IF @ToTime IS NOT NULL SET @FilterTime = @FilterTime + CHAR(13) + CHAR(10) + CHAR(9) + '[TimeDay_MemberId] <= ' + CONVERT(nvarchar(15), @ToTime) + ' AND'
			END

		IF @DebugBM & 2 > 0 SELECT [@FilterTime] = @FilterTime

		SET @SQLStatement = @SQLStatement + ISNULL(@FilterTime, '')

		SELECT
			@SQLFilter = @SQLFilter + CHAR(13) + CHAR(10) + CHAR(9) + '[' + [DimensionName] + CASE WHEN @StorageTypeBM = 4 THEN '_MemberId' ELSE '' END + '] ' + [EqualityString] + ' (' + [LeafLevelFilter] + ') AND'
		FROM
			#FilterTable
		WHERE
			[StepReference] = 'BR16' AND
			[LeafLevelFilter] IS NOT NULL AND
			ISNULL([ObjectReference], '') NOT IN ('FromTime', 'ToTime')
		ORDER BY
			DimensionID

		IF @DebugBM & 2 > 0 SELECT [@SQLFilter] = @SQLFilter

		SET @SQLStatement = @SQLStatement + ISNULL(@SQLFilter, '')

		IF RIGHT(@SQLStatement, 5) = 'WHERE' SET @SQLStatement = LEFT(@SQLStatement, LEN(@SQLStatement) - 5)
		ELSE IF RIGHT(@SQLStatement, 3) = 'AND' SET @SQLStatement = LEFT(@SQLStatement, LEN(@SQLStatement) - 3)
		
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'UPDATE [pcINTEGRATOR_Log].[dbo].[BackupLog]'		
		UPDATE [pcINTEGRATOR_Log].[dbo].[BackupLog]
		SET
			[TableName] = 'BU_' + @TableName + '_' + CONVERT(nvarchar(15), @BackupLogID),
			[Rows] = @Inserted
		WHERE
			[BackupLogID] = @BackupLogID
			
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
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
