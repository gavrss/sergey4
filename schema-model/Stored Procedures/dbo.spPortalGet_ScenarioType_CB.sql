SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_ScenarioType_CB]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@WorkflowYN bit = NULL,
    @FullDimensionalityYN bit = NULL,
    @LiveYN bit = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000299,
	@Parameter nvarchar(4000) = NULL,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

AS

/*
**** LEGACY Replaced by [spPortalAdminGet_ScenarioList] ResultTypeBM=2 *******

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalGet_ScenarioType_CB',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "304"},
		{"TKey" : "VersionID",  "TValue": "1001"}
		]'

EXEC [spPortalGet_ScenarioType_CB] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @WorkflowYN = 1

EXEC [spPortalGet_ScenarioType_CB] @GetVersion = 1
*/

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
	@Version nvarchar(50) = '2.0.0.2140'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return rows for combobox ScenarioType.',
			@MandatoryParameter = ''
		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description
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
		--EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT

	SET @Step = 'Return rows'
		SELECT
			ScenarioTypeId = ST.ScenarioTypeId,
			ScenarioTypeName = ST.ScenarioTypeName,
			ScenarioTypeDescription = ST.ScenarioTypeName,
			WorkflowYN = ST.WorkflowYN,
			FullDimensionalityYN = ST.FullDimensionalityYN,
			LiveYN = ST.LiveYN
		FROM 
			[ScenarioType] ST
		WHERE
			(ST.InstanceID = @InstanceID OR ST.InstanceID = 0) AND
			(ST.WorkflowYN = @WorkflowYN OR @WorkflowYN IS NULL) AND
			(ST.FullDimensionalityYN = @FullDimensionalityYN OR @FullDimensionalityYN IS NULL) AND
			(ST.LiveYN = @LiveYN OR @LiveYN IS NULL)
		ORDER BY
			ScenarioTypeName

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version,  @UserName = @UserName
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
