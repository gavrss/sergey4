SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_SqlQuery]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@SqlQueryID int = NULL,
	@SqlQueryName nvarchar(50) = NULL,
	@SqlQueryDescription nvarchar(255) = NULL,
	@SqlQuery nvarchar(max) = NULL,
	@SqlQueryGroupID int = NULL,
	@SelectYN bit = NULL,
	@DeleteYN bit = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000125,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_SqlQuery',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminSet_SqlQuery] @UserID = 1005, @InstanceID = 357, @SqlQueryID = 1010, @SqlQueryName = 'Natural Accounts not mapped to Type', @SqlQueryDescription = 'Shows all types of natural accounts that are not mapped to Account Type', @SqlQuery = 'SELECT * FROM [pcETL_DevTest78]..AccountType_Translate WHERE AccountType IS NULL', @SqlQueryGroupID = -1, @SelectYN = 1, @DeleteYN = 0

EXEC [spPortalAdminSet_SqlQuery] @GetVersion = 1
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
			@ProcedureDescription = 'Set SqlQuery',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2134' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'

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

	SET @Step = 'UPDATE'	 
		IF @DeleteYN = 0
			BEGIN
				UPDATE SQ
				SET
					[SqlQueryName] = @SqlQueryName,
					[SqlQueryDescription] = @SqlQueryDescription,
					[SqlQuery] = @SqlQuery,
					[SqlQueryGroupID] = @SqlQueryGroupID,
					[SelectYN] = @SelectYN
				FROM
					[pcINTEGRATOR_Data].[dbo].[SqlQuery] SQ
				WHERE
					SQ.[SqlQueryID] = @SqlQueryID

				SET @Updated = @@ROWCOUNT
			END

	SET @Step = 'INSERT'	
		IF @Updated = 0 AND @DeleteYN = 0
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[SqlQuery]
					(
					[InstanceID],
					[SqlQueryName],
					[SqlQueryDescription],
					[SqlQuery],
					[SqlQueryGroupID],
					[SelectYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[SqlQueryName] = @SqlQueryName,
					[SqlQueryDescription] = @SqlQueryDescription,
					[SqlQuery] = @SqlQuery,
					[SqlQueryGroupID] = @SqlQueryGroupID,
					[SelectYN] = @SelectYN

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'DELETE'	
		IF @DeleteYN <> 0
			BEGIN
				DELETE SQP
				FROM 
					[pcINTEGRATOR_Data].[dbo].[SqlQueryParameter] SQP
				WHERE
					SQP.[SqlQueryID] = @SqlQueryID

				DELETE SQ
				FROM 
					[pcINTEGRATOR_Data].[dbo].[SqlQuery] SQ
				WHERE
					SQ.[SqlQueryID] = @SqlQueryID

				SET @Deleted = @Deleted + @@ROWCOUNT
			END


	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

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
