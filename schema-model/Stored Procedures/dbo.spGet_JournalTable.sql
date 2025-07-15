SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_JournalTable]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JournalStorageTypeBM int = NULL OUT,
	@JournalTable nvarchar(100) = NULL OUT,
	@SetJobLogYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000383,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spGet_JournalTable',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

DECLARE @JournalTable nvarchar(100)
EXEC [spGet_JournalTable] @UserID=-10, @InstanceID=390, @VersionID=1011, @JournalTable = @JournalTable OUT --, @Debug=1
SELECT JournalTable = @JournalTable

DECLARE @JournalTable nvarchar(100)
EXEC [spGet_JournalTable] @UserID=-10, @InstanceID=-1125, @VersionID=-1125, @JournalTable = @JournalTable OUT --, @Debug=1
SELECT JournalTable = @JournalTable

EXEC [spGet_JournalTable] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ETLDatabase nvarchar(100),
	@SQLStatement nvarchar(MAX),
	@RowCount int,

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
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get Journal location',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2154' SET @Description = 'Enhanced debugging.'
		IF @Version = '2.1.0.2159' SET @Description = 'Remove test on SelectYN in table Application. Use dynamic SQL instead of temp table for calculating @RowCount'
		IF @Version = '2.1.1.2168' SET @Description = 'Added parameter @SetJobLogYN, defaulted to 0.'

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

	SET @Step = 'Get @JournalStorageTypeBM'
		SELECT
			@JournalStorageTypeBM = StorageTypeBM
		FROM
			pcINTEGRATOR_Data..DataClass
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			ModelBM & 1 > 0 AND
			SelectYN <> 0 AND
			DeletedID IS NULL

		SET @JournalStorageTypeBM = ISNULL(@JournalStorageTypeBM, 1)
		
		IF @DebugBM & 2 > 0 SELECT [@JournalStorageTypeBM] = @JournalStorageTypeBM
		
		IF @JournalStorageTypeBM & 2 = 0 GOTO DefaultSetting

	SET @Step = 'Check table existance'
		SELECT
			@ETLDatabase = ETLDatabase
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		IF @DebugBM & 2 > 0 SELECT [@ETLDatabase] = @ETLDatabase

		SET @SQLStatement = '
			SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''Journal'''

		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @RowCount OUT

		IF @DebugBM & 2 > 0 SELECT [@RowCount] = @RowCount

		IF @RowCount > 0
			SET @JournalTable = '[' + @ETLDatabase + '].[dbo].[Journal]'

	SET @Step = 'Set Journal table to default'
		DefaultSetting:
		SET @JournalTable = ISNULL(@JournalTable, '[pcINTEGRATOR_Data].[dbo].[Journal]')

		IF @DebugBM & 1 > 0 SELECT [@JournalTable] = @JournalTable

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
