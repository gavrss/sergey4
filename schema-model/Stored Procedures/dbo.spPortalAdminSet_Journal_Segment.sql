SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Journal_Segment]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@Entity NVARCHAR(50) = NULL, --Mandatory
	@Book NVARCHAR(50) = NULL, --Mandatory
	@SegmentCode NVARCHAR(50) = NULL, --Mandatory
	@DimensionID INT = NULL,
	@DimensionName NVARCHAR(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000198,
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
	@ProcedureName = 'spPortalAdminSet_Journal_Segment',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "404"},
		{"TKey" : "VersionID",  "TValue": "1003"},
		{"TKey" : "Entity",  "TValue": "000-7"},
		{"TKey" : "Book",  "TValue": "GL"},
		{"TKey" : "SegmentCode",  "TValue": "6"},
		{"TKey" : "DimensionID",  "TValue": "1013"}
		]'
EXEC dbo.[spPortalAdminSet_Journal_Segment] @UserID = -10, @InstanceID = 404, @VersionID = 1003, @Entity = '000-7', @Book = 'GL', @SegmentCode = '6', @DimensionID = 1013, @Debug = 1

EXEC [spPortalAdminSet_Journal_Segment] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@DataClassID int,
	@StorageTypeBM int,
	@MaxSortOrder int,
	@EntityID int,

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
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Insert new Journal_Segments',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2154' SET @Description = 'Removed references to Journal_SegmentNo.Entity'

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

		SELECT
			@EntityID = EntityID
		FROM
			Entity
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			MemberKey = @Entity

	SET @Step = 'Set DimensionID'
		IF @DimensionID IS NOT NULL
			BEGIN
				UPDATE [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo]
				SET
					DimensionID = @DimensionID
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[EntityID] = @EntityID AND
					[Book] = @Book AND
					[SegmentCode] = @SegmentCode

				SET @Updated = @@rowcount
			END

	SET @Step = 'Create new Segment Dimension'
		IF @DimensionID IS NULL AND @DimensionName IS NOT NULL
			BEGIN
				SELECT
					@DataClassID = MAX(DataClassID),
					@StorageTypeBM = MAX(StorageTypeBM)
				FROM
					[pcINTEGRATOR_Data].[dbo].[DataClass] dc
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					ModelBM & 64 > 0 AND
					SelectYN <> 0

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension]
					(
					[InstanceID],
					[DimensionName],
					[DimensionDescription],
					[DimensionTypeID],
					[SourceTypeBM]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[DimensionName] = @DimensionName,
					[DimensionDescription] = @DimensionName,
					[DimensionTypeID] = -1,
					[SourceTypeBM] = 65535 --Specific value can be picked from Source table
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension] D WHERE [InstanceID] = @InstanceID AND [DimensionName] = @DimensionName)

				SELECT
					@DimensionID = @@identity,
					@Inserted = @@rowcount

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
					(
					[InstanceID],
					[VersionID],
					[DimensionID],
					[StorageTypeBM],
					[ReadSecurityEnabledYN]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DimensionID] = @DimensionID,
					[StorageTypeBM] = @StorageTypeBM,
					[ReadSecurityEnabledYN] = 0
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID AND [DimensionID] = @DimensionID)

				UPDATE [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo]
				SET
					DimensionID = @DimensionID
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[EntityID] = @EntityID AND
					[Book] = @Book AND
					[SegmentCode] = @SegmentCode

				SET @Updated = @@rowcount

				SELECT
					@MaxSortOrder = MAX(SortOrder)
				FROM
					[pcINTEGRATOR_Data].[dbo].[DataClass_Dimension]
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[DataClassID] = @DataClassID

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension]
					(
					[InstanceID],
					[VersionID],
					[DataClassID],
					[DimensionID],
					[SortOrder]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DataClassID] = @DataClassID,
					[DimensionID] = @DimensionID,
					[SortOrder] = @MaxSortOrder + 10

				SET @Inserted = @Inserted + @@rowcount
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
