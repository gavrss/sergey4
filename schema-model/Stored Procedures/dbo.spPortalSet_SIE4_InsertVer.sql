SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_SIE4_InsertVer]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@Param nvarchar(50) = NULL,
	@Seq nvarchar(50) = NULL,
	@Ver nvarchar(50) = NULL,
	@Date int = NULL,
	@VerDescription nvarchar(255) = NULL,
	@RowCountYN bit = 0,

	@JSON_table nvarchar(max) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000175,
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
--EXEC [spPortalSet_SIE4_InsertVer] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 1, @Param = '#VER', @Seq = 'A', @Ver = '1', @Date = 20160124, @Description = 'Epicor royalty report January 2016', @Debug = 1
--EXEC [spPortalSet_SIE4_InsertVer] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 2, @Param = '#VER', @Seq = 'A', @Ver = '1', @Date = 20160124, @Description = 'Epicor royalty report January 2016', @Debug = 1
--EXEC [spPortalSet_SIE4_InsertVer] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 3, @Param = '#VER', @Seq = 'A', @Ver = '1', @Date = 20160124, @Description = 'Epicor royalty report January 2016', @Debug = 1
--EXEC [spPortalSet_SIE4_InsertVer] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @JobID = 4, @Param = '#VER', @Seq = 'A', @Ver = '1', @Date = 20160124, @Description = 'Epicor royalty report January 2016', @RowCountYN = 1, @Debug = 1

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalSet_SIE4_InsertVer',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"-10"},
		{"TKey":"InstanceID", "TValue":"404"},
		{"TKey":"VersionID", "TValue":"1003"},
		{"TKey":"JobID", "TValue":"1"}
		]',
	@JSON_table = '
		[
		{"Param":"#VER", "Seq":"A", "Ver":"1", "Date":"20160124", "VerDescription":"Epicor royalty report January 2016"},
		{"Param":"#VER", "Seq":"A", "Ver":"2", "Date":"20160125", "VerDescription":"Epicor royalty report January 2016"},
		{"Param":"#VER", "Seq":"A", "Ver":"3", "Date":"20160126", "VerDescription":"Epicor royalty report January 2016"},
		{"Param":"#VER", "Seq":"A", "Ver":"4", "Date":"20160127", "VerDescription":"Epicor royalty report January 2016"}
		]'

EXEC [spPortalSet_SIE4_InsertVer] @GetVersion = 1
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
			@ProcedureDescription = 'Insert SIE4 verifications',
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
				INSERT INTO [pcINTEGRATOR_Data].[dbo].SIE4_Ver
					(
					[InstanceID],
					[JobID],
					[Param],
					[Seq],
					[Ver],
					[Date],
					[Description],
					[InsertedBy]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[JobID] = @JobID,
					[Param] = [Param],
					[Seq] = [Seq],
					[Ver] = [Ver],
					[Date] = [Date],
					[Description] = [VerDescription],
					[InsertedBy] = @UserName
				FROM
					OPENJSON(@JSON_table)
				WITH
					(
					[Param] nvarchar(50) COLLATE database_default,
					[Seq] nvarchar(50) COLLATE database_default,
					[Ver] nvarchar(50) COLLATE database_default,
					[Date] int,
					[VerDescription] nvarchar(255) COLLATE database_default
					)

				SELECT @Inserted = @Inserted + @@ROWCOUNT
			END
		ELSE
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].SIE4_Ver
					(
					[InstanceID],
					[JobID],
					[Param],
					[Seq],
					[Ver],
					[Date],
					[Description],
					[InsertedBy]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[JobID] = @JobID,
					[Param] = @Param,
					[Seq] = @Seq,
					[Ver] = @Ver,
					[Date] = @Date,
					[Description] = @VerDescription,
					[InsertedBy] = @UserName

				SELECT @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Return Debug'
		IF @Debug <> 0
			SELECT
				*
			FROM
				[pcINTEGRATOR_Data].[dbo].[SIE4_Ver]
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
