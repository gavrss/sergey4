SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Mapping_DataClass_Default]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@A_DataClassID int = NULL,
	@B_DataClassID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000305,
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
	@ProcedureName = 'spPortalAdminSet_Mapping_DataClass_Default',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "413"},
		{"TKey" : "VersionID",  "TValue": "1008"},
		{"TKey" : "DataClassID_A",  "TValue": "100"},
		{"TKey" : "DataClassID_B",  "TValue": "1028"}
		]',
	@Debug = 1

EXEC [spPortalAdminSet_Mapping_DataClass_Default] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @DataClassID_A = '100', @DataClassID_B = '1028', @Debug = 1

EXEC [spPortalAdminSet_Mapping_DataClass_Default] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@Mapping_DataClassID int,

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
			@ProcedureDescription = 'Setup default mapping between selected DataClasses.',
			@MandatoryParameter = 'A_DataClassID|B_DataClassID'

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
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

	SET @Step = 'Insert Rows into [Mapping_DataClass]'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Mapping_DataClass]
			(
			[InstanceID],
			[VersionID],
			[A_DataClassID],
			[B_DataClassID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[A_DataClassID] = @A_DataClassID,
			[B_DataClassID] = @B_DataClassID
		WHERE
			NOT EXISTS (SELECT 1 FROM [Mapping_DataClass] MDC WHERE MDC.[InstanceID] = @InstanceID AND MDC.[VersionID] = @VersionID AND ((MDC.[A_DataClassID] = @A_DataClassID AND MDC.[B_DataClassID] = @B_DataClassID) OR (MDC.[A_DataClassID] = @B_DataClassID AND MDC.[B_DataClassID] = @A_DataClassID)))

		SET @Mapping_DataClassID = @@IDENTITY

		IF @Mapping_DataClassID IS NULL
			SELECT
				@Mapping_DataClassID = Mapping_DataClassID
			FROM
				[pcINTEGRATOR_Data].[dbo].[Mapping_DataClass] MDC
			WHERE
				MDC.[InstanceID] = @InstanceID AND 
				MDC.[VersionID] = @VersionID AND 
				((MDC.[A_DataClassID] = @A_DataClassID AND MDC.[B_DataClassID] = @B_DataClassID) OR (MDC.[A_DataClassID] = @B_DataClassID AND MDC.[B_DataClassID] = @A_DataClassID))

/*
SELECT TOP (1000) [InstanceID]
      ,[VersionID]
      ,[Mapping_DataClassID]
      ,[A_DataClassID]
      ,[B_DataClassID]
      ,[Updated]
      ,[UpdatedBy]
  FROM [pcINTEGRATOR].[dbo].[Mapping_DataClass]
*/

	SET @Step = 'Drop the temp tables'

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
