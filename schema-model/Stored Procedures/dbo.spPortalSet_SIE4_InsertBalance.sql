SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_SIE4_InsertBalance]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@Param nvarchar(50) = NULL,
	@RAR int = NULL,
	@Account nvarchar(50) = NULL,
	@Amount decimal(18,2) = NULL,
	@RowCountYN bit = 0,

	@JSON_table nvarchar(max) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000170,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
--EXEC [spPortalSet_SIE4_InsertBalance] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 1, @Param = '#IB', @RAR = 0, @Account = '1080', @Amount = 1141707.94, @Debug = 1
--EXEC [spPortalSet_SIE4_InsertBalance] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 1, @Param = '#IB', @RAR = -1, @Account = '1080', @Amount = 1531707.82, @Debug = 1
--EXEC [spPortalSet_SIE4_InsertBalance] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 1, @Param = '#UB', @RAR = 0, @Account = '1080', @Amount = 2141707.94, @Debug = 1
--EXEC [spPortalSet_SIE4_InsertBalance] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 1, @Param = '#UB', @RAR = -1, @Account = '1080', @Amount = 2531707.82, @Debug = 1
--EXEC [spPortalSet_SIE4_InsertBalance] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 1, @Param = '#RES', @RAR = 0, @Account = '3001', @Amount = 345678.75, @Debug = 1
--EXEC [spPortalSet_SIE4_InsertBalance] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 1, @Param = '#RES', @RAR = -1, @Account = '3001', @Amount = 245678.25, @Debug = 1
--EXEC [spPortalSet_SIE4_InsertBalance] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 2, @Param = '#RES', @RAR = -1, @Account = '3001', @Amount = 245678.25, @Debug = 1
--EXEC [spPortalSet_SIE4_InsertBalance] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 3, @Param = '#RES', @RAR = -1, @Account = '3001', @Amount = 245678.25, @RowCountYN = 1, @Debug = 1

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalSet_SIE4_InsertBalance',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"-10"},
		{"TKey":"InstanceID", "TValue":"404"},
		{"TKey":"VersionID", "TValue":"1003"},
		{"TKey":"JobID", "TValue":"1"}
		]',
	@JSON_table = '
		[
		{"Param":"#IB", "RAR":"0", "Account":"1080", "Amount":"1141707.94"},
		{"Param":"#IB", "RAR":"-1", "Account":"1080", "Amount":"1531707.82"},
		{"Param":"#UB", "RAR":"0", "Account":"1080", "Amount":"2141707.94"},
		{"Param":"#UB", "RAR":"-1", "Account":"1080", "Amount":"2531707.82"}
		]'

EXEC [spPortalSet_SIE4_InsertBalance] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.1.2143'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert SIE4 balance',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, introduced @JSON_table, changed database to [pcINTEGRATOR_Data].'

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

	SET @Step = 'Insert table or Row'
		IF @JSON_table IS NOT NULL	
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].SIE4_Balance
					(
					[InstanceID],
					[JobID],
					[Param],
					[RAR],
					[Account],
					[Amount],
					[InsertedBy]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[JobID] = @JobID,
					[Param] = [Param],
					[RAR] = [RAR],
					[Account] = [Account],
					[Amount] = [Amount],
					[InsertedBy] = @UserName
				FROM
					OPENJSON(@JSON_table)
				WITH
					(
					[Param] nvarchar(50) COLLATE database_default,
					[RAR] int,
					[Account] nvarchar(50) COLLATE database_default,
					[Amount] decimal(18,2)
					)

				SELECT @Inserted = @Inserted + @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].SIE4_Balance
					(
					[InstanceID],
					[JobID],
					[Param],
					[RAR],
					[Account],
					[Amount],
					[InsertedBy]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[JobID] = @JobID,
					[Param] = @Param,
					[RAR] = @RAR,
					[Account] = @Account,
					[Amount] = @Amount,
					[InsertedBy] = @UserName

				SELECT @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Return Debug'
		IF @Debug <> 0
			SELECT
				*
			FROM
				[pcINTEGRATOR_Data].[dbo].[SIE4_Balance]
			WHERE
				[JobID] = @JobID

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Return Statistics'
		IF @RowCountYN <> 0
			SELECT
				Duration = @Duration,
				Deleted = @Deleted,
				Inserted = @Inserted,
				Updated = @Updated

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
