SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_DataSourceStatus]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@Entity nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@ProcessID int = NULL,
	@Year int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000378,
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
EXEC [pcINTEGRATOR].[dbo].[spPortalGet_DataSourceStatus] @InstanceID='621',@UserID='-10',@VersionID='1105'
EXEC [spPortalGet_DataSourceStatus] @UserID=-10, @InstanceID=413, @VersionID=1008, @Debug=1 --CBN
EXEC [spPortalGet_DataSourceStatus] @UserID=-10, @InstanceID=-1039, @VersionID=-1039, @Debug=1 --KIP
EXEC [spPortalGet_DataSourceStatus] @UserID=-10, @InstanceID=424, @VersionID=1017, @Debug=1 --HD
EXEC [spPortalGet_DataSourceStatus] @UserID=-10, @InstanceID=529, @VersionID=1001, @Debug=1 --Telia Carrier
EXEC [spPortalGet_DataSourceStatus] @UserID=-10, @InstanceID=529, @VersionID=1001, @Entity = '18', @Year = 2019, @Debug=1 --Telia Carrier

EXEC [spPortalGet_DataSourceStatus] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@JournalTable nvarchar(100),
	@SQLStatement nvarchar(MAX),

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get CheckSum for specified Job (default last CheckSum executed).',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2144' SET @Description = 'Added correct reference of Journal table.'
		IF @Version = '2.1.0.2158' SET @Description = 'Changed group by from [SourceModule] to [JournalSequence].'
		IF @Version = '2.1.1.2171' SET @Description = 'Added new parameters and increased performance.'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-1926: Added [Entity] in the resultset. Updated to latest SP template.'

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
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'Get reference of Journal table'
		EXEC [pcINTEGRATOR].[dbo].[spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JournalTable = @JournalTable OUT
		IF @Debug <> 0 SELECT [@JournalTable] = @JournalTable

	SET @Step = 'Fill temp table #LastChange'
		CREATE TABLE #LastChange
			(
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DataClass] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Journal] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[LatestPosted] date,
			[LatestDataChange] datetime
			)

		SET @SQLStatement = '
			INSERT INTO #LastChange
				(
				[Source],
				[DataClass],
				[Entity],
				[Journal],
				[LatestPosted],
				[LatestDataChange]
				)
			SELECT 
				[Source],
				[DataClass] = ''Financials'',
				[Entity],
				[Journal] = J.[JournalSequence],
				[LatestPosted] = MAX(J.[PostedDate]),
				[LatestDataChange] = MAX(J.[Inserted])
			FROM
				' + @JournalTable + ' J
			WHERE
				J.[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
				J.[JournalSequence] IS NOT NULL AND
				J.[JournalSequence] <> '''' AND
				J.ConsolidationGroup IS NULL
				' + CASE WHEN @Entity IS NULL THEN '' ELSE 'AND J.[Entity] = ''' + @Entity + '''' END + '
				' + CASE WHEN @Book IS NULL THEN '' ELSE 'AND J.[Book] = ''' + @Book + '''' END + '
				' + CASE WHEN @Year IS NULL THEN '' ELSE 'AND J.[FiscalYear] = ' + CONVERT(nvarchar(15), @Year) END + '
			GROUP BY
				J.[Source],
				J.[Entity],
				J.[JournalSequence]'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Get Latest load per source'
		SELECT 
			[Source] = LC.[Source],
			[SourceDescription] = ISNULL(ST.[SourceTypeDescription], LC.[Source]),
			[DataClass] = LC.[DataClass],
			[Entity] = LC.[Entity],
			[Journal] = LC.[Journal],
			[LatestPosted] = LC.[LatestPosted],
			[LatestDataChange] = LC.[LatestDataChange]
		FROM
			#LastChange LC
			LEFT JOIN [pcINTEGRATOR].[dbo].[SourceType] ST ON ST.SourceTypeName = LC.[Source]
		ORDER BY
			LC.[Source],
			LC.[Journal]

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
