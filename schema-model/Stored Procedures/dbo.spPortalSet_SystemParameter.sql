SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_SystemParameter]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@Parameter nvarchar(50) = NULL,
	@ParameterTypeID int = NULL,
	@ProcessID int = NULL,
	@ParameterDescription nvarchar(255) = NULL,
	@HelpText nvarchar(1024) = NULL,
	@ParameterValue nvarchar(50) = NULL,
	@UxFieldTypeID int = NULL,
	@UxEditableYN bit = NULL,
	@UxHelpUrl nvarchar(255) = NULL,
	@UxSelectionSource nvarchar(max) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000177,
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
EXEC [spPortalSet_SystemParameter] @UserID = 1005, @InstanceID = 356
EXEC [spPortalGet_SystemParameter] @UserID = 1005, @InstanceID = 357

EXEC [spPortalSet_SystemParameter] @GetVersion = 1
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
			@ProcedureDescription = 'Set SystemParameter',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
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
		UPDATE SP
		SET 
			[ParameterTypeID] = @ParameterTypeID,
			[ProcessID] = @ProcessID,
			[ParameterDescription] = @ParameterDescription,
			[HelpText] = @HelpText,
			[ParameterValue] = @ParameterValue,
			[UxFieldTypeID] = @UxFieldTypeID,
			[UxEditableYN] = @UxEditableYN,
			[UxHelpUrl] = @UxHelpUrl,
			[UxSelectionSource] = @UxSelectionSource
		FROM
			[pcINTEGRATOR_Data].[dbo].[SystemParameter] SP
		WHERE
			[InstanceID] = @InstanceID AND
			[Parameter] = @Parameter

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'INSERT'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SystemParameter]
			(
			[InstanceID],
			[Parameter],
			[ParameterTypeID],
			[ProcessID],
			[ParameterDescription],
			[HelpText],
			[ParameterValue],
			[UxFieldTypeID],
			[UxEditableYN],
			[UxHelpUrl],
			[UxSelectionSource]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[Parameter] = @Parameter,
			[ParameterTypeID] = @ParameterTypeID,
			[ProcessID] = @ProcessID,
			[ParameterDescription] = @ParameterDescription,
			[HelpText] = @HelpText,
			[ParameterValue] = @ParameterValue,
			[UxFieldTypeID] = @UxFieldTypeID,
			[UxEditableYN] = @UxEditableYN,
			[UxHelpUrl] = @UxHelpUrl,
			[UxSelectionSource] = @UxSelectionSource
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SystemParameter] SP WHERE SP.[InstanceID] = @InstanceID AND SP.[Parameter] = @Parameter)

		SET @Inserted = @Inserted + @@ROWCOUNT

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
