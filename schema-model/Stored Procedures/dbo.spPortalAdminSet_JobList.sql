SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_JobList]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JobListID int = NULL,
	@JobListName nvarchar(50) = NULL,
	@JobListDescription nvarchar(255) = NULL,
	@JobStepTypeBM int = NULL,
	@JobFrequencyBM int = NULL,
	@JobStepGroupBM int = NULL,
	@ProcessBM int = NULL,
	@JobSetupStepBM int = NULL,
	@JobStep_List nvarchar(4000) = NULL,
	@Entity_List nvarchar(4000) = NULL,
	@SelectYN bit = 1,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000216,
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
--UPDATE
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_JobList',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "304"},
		{"TKey" : "VersionID",  "TValue": "1001"},
		{"TKey" : "JobListID", "TValue": "1003"},
		{"TKey" : "JobListName",  "TValue": "Refresh all"},
		{"TKey" : "JobListDescription",  "TValue": "Refresh all processes"},
		{"TKey" : "JobStepTypeBM",  "TValue": "72"},
		{"TKey" : "JobFrequencyBM",  "TValue": "2"},
		{"TKey" : "JobStepGroupBM",  "TValue": "2"},
		{"TKey" : "ProcessBM",  "TValue": "3"},
		{"TKey" : "JobSetupStepBM",  "TValue": "65535"},
		{"TKey" : "Entity_List",  "TValue": "01,05,07"},
		{"TKey" : "SelectYN",  "TValue": "1"}
		]'

EXEC [dbo].[spPortalAdminSet_JobList] 
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@JobListID = 1003,
	@JobListName = 'Refresh all',
	@JobListDescription = 'Refresh all processes',
	@JobStepTypeBM = 72,
	@JobFrequencyBM = 2,
	@JobStepGroupBM = 2,
	@ProcessBM = 3,
	@JobSetupStepBM = 65535,
	@JobStep_List = NULL,
	@Entity_List = '01,05,07',
	@SelectYN = 1

--DELETE
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_JobList',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "304"},
		{"TKey" : "VersionID",  "TValue": "1001"},
		{"TKey" : "JobListID", "TValue": "1005"},
		{"TKey" : "DeleteYN",  "TValue": "1"}
		]'

EXEC [dbo].[spPortalAdminSet_JobList] 
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@JobListID = 1005,
	@DeleteYN = 1

--INSERT
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_JobList',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "304"},
		{"TKey" : "VersionID",  "TValue": "1001"},
		{"TKey" : "JobListName",  "TValue": "Refresh all"},
		{"TKey" : "JobListDescription",  "TValue": "Refresh all processes"},
		{"TKey" : "JobStepTypeBM",  "TValue": "72"},
		{"TKey" : "JobFrequencyBM",  "TValue": "2"},
		{"TKey" : "JobStepGroupBM",  "TValue": "2"},
		{"TKey" : "ProcessBM",  "TValue": "3"},
		{"TKey" : "JobSetupStepBM",  "TValue": "65535"},
		{"TKey" : "Entity_List",  "TValue": "01,05,07"},
		{"TKey" : "SelectYN",  "TValue": "1"}
		]'

EXEC [dbo].[spPortalAdminSet_JobList] 
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@JobListName = 'Refresh all',
	@JobListDescription = 'Refresh all processes',
	@JobStepTypeBM = 72,
	@JobFrequencyBM = 2,
	@JobStepGroupBM = 2,
	@ProcessBM = 3,
	@JobSetupStepBM = 65535,
	@JobStep_List = NULL,
	@Entity_List = '01,05',
	@SelectYN = 1

EXEC [spPortalAdminSet_JobList] @GetVersion = 1
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
			@ProcedureDescription = 'Update JobList',
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

	SET @Step = 'Update JobList'
		IF @JobListID IS NOT NULL AND @DeleteYN = 0
			BEGIN
				UPDATE JL
				SET
					[JobListName] = @JobListName,
					[JobListDescription] = @JobListDescription,
					[JobStepTypeBM] = @JobStepTypeBM,
					[JobFrequencyBM] = @JobFrequencyBM,
					[JobStepGroupBM] = @JobStepGroupBM,
					[ProcessBM] = @ProcessBM,
					[JobSetupStepBM] = @JobSetupStepBM,
					[JobStep_List] = @JobStep_List,
					[Entity_List] = @Entity_List,
					[UserID] = @UserID,
					[SelectYN] = @SelectYN
				FROM
					[pcINTEGRATOR_Data].[dbo].[JobList] JL
				WHERE
					[InstanceID] = @InstanceID AND
					[JobListID] = @JobListID

				SET @Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'Delete existing member'
		IF @JobListID IS NOT NULL AND @DeleteYN <> 0
			BEGIN
				DELETE JL
				FROM
					[pcINTEGRATOR_Data].[dbo].[JobList] JL
				WHERE
					[InstanceID] = @InstanceID AND
					[JobListID] = @JobListID

				SET @Deleted = @Deleted + @@ROWCOUNT
			END

	SET @Step = 'Insert new row into JobList'
		IF @JobListID IS NULL AND @DeleteYN = 0
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[JobList]
					(
					[InstanceID],
					[JobListName],
					[JobListDescription],
					[JobStepTypeBM],
					[JobFrequencyBM],
					[JobStepGroupBM],
					[ProcessBM],
					[JobSetupStepBM],
					[JobStep_List],
					[Entity_List],
					[UserID],
					[SelectYN]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[JobListName] = @JobListName,
					[JobListDescription] = @JobListDescription,
					[JobStepTypeBM] = @JobStepTypeBM,
					[JobFrequencyBM] = @JobFrequencyBM,
					[JobStepGroupBM] = @JobStepGroupBM,
					[ProcessBM] = @ProcessBM,
					[JobSetupStepBM] = @JobSetupStepBM,
					[JobStep_List] = @JobStep_List,
					[Entity_List] = @Entity_List,
					[UserID] = @UserID,
					[SelectYN] = @SelectYN
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[JobList] JL WHERE JL.[InstanceID] = @InstanceID AND JL.[JobListName] = @JobListName)

				SELECT
					@JobListID = @@IDENTITY,
					@Inserted = @Inserted + @@ROWCOUNT
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
