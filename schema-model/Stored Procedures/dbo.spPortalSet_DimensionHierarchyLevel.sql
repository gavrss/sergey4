SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_DimensionHierarchyLevel]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DimensionID int = NULL,
	@HierarchyNo int = NULL,
	@LevelNo int = NULL,
	@LevelName nvarchar(50) = NULL,
	@Comment nvarchar(255) = NULL,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000228,
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
InstanceID = 0 standard hierarchy, specific InstanceID means customized
HierarchyNo = 0 default hierachy, 1-9 alternative hierarchies
FixedLevelsYN = If false, level view is not available
LockedYN = If true, the hierarchy should be possible to view, but not change

--EXEC [spPortalSet_DimensionHierarchyLevel] @UserID = 1005, @InstanceID = 357, @VersionID = 1006, @DimensionID = -4, @Debug = 1
--EXEC [spPortalSet_DimensionHierarchyLevel] @GetVersion = 1
--EXEC spPortalSet_DimensionHierarchyLevel @Comment='CurrencyComment',@DimensionId='-3',@HierarchyNo='0',@InstanceID='304',@LevelName='Currency',@LevelNo='2',@UserID='2002',@VersionID='1001',@ProcedureID=880000228

EXEC [spRun_Procedure_KeyValuePair] 
@ProcedureName='spPortalSet_DimensionHierarchyLevel',
@JSON='[
{"TKey":"InstanceID","TValue":"413"},
{"TKey":"Comment","TValue":"Voucher"},
{"TKey":"UserID","TValue":"2147"},
{"TKey":"DimensionId","TValue":"-58"},
{"TKey":"LevelNo","TValue":"3"},
{"TKey":"VersionID","TValue":"1008"},
{"TKey":"LevelName","TValue":"LeafLevel"},
{"TKey":"HierarchyNo","TValue":"0"},
{"TKey":"Debug","TValue":"1"}
]'

EXEC [spPortalSet_DimensionHierarchyLevel] @GetVersion = 1
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
			@ProcedureDescription = 'Set DimensionHierarchyLevel',
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

	SET @Step = 'Insert a copy of default rows if not exists'
		IF @Debug <> 0 
			BEGIN
				SELECT [InstanceID] = @InstanceID, [DimensionID] = @DimensionID, [HierarchyNo] = @HierarchyNo, [LevelNo] = @LevelNo

				SELECT
					[InstanceID] = @InstanceID,
					[DimensionID] = DHLS.DimensionID,
					[HierarchyNo] = DHLS.HierarchyNo,
					[LevelNo] = DHLS.LevelNo,
					[LevelName] = DHLS.LevelName,
					[Comment] = DHLS.Comment
				FROM
					DimensionHierarchyLevel DHLS
				WHERE
					DHLS.[InstanceID] = 0 AND 
					DHLS.[DimensionID] = @DimensionID AND 
					DHLS.[HierarchyNo] = @HierarchyNo AND
					DHLS.[LevelNo] <> @LevelNo
			END

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
			(
			[InstanceID],
			[DimensionID],
			[HierarchyNo],
			[HierarchyName],
			[Comment]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[DimensionID] = @DimensionID,
			[HierarchyNo] = @HierarchyNo,
			[HierarchyName] = DHS.[HierarchyName],
			[Comment] = DHS.[Comment]
		FROM
			DimensionHierarchy DHS
		WHERE
			DHS.[InstanceID] = 0 AND 
			DHS.[DimensionID] = @DimensionID AND 
			DHS.[HierarchyNo] = @HierarchyNo AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH WHERE DH.[InstanceID] = @InstanceID AND DH.[DimensionID] = @DimensionID AND DH.[HierarchyNo] = @HierarchyNo)

		SET @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
			(
			[InstanceID],
			[DimensionID],
			[HierarchyNo],
			[LevelNo],
			[LevelName],
			[Comment]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[DimensionID] = @DimensionID,
			[HierarchyNo] = @HierarchyNo,
			[LevelNo] = @LevelNo,
			[LevelName] = @LevelName,
			[Comment] = @Comment
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DHL WHERE DHL.[InstanceID] = @InstanceID AND DHL.[DimensionID] = @DimensionID AND DHL.[HierarchyNo] = @HierarchyNo AND DHL.[LevelNo] = @LevelNo)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update'
		IF @DeleteYN = 0
			BEGIN
				UPDATE DHL
				SET
					[LevelName] = @LevelName,
					[Comment] = @Comment
				FROM
					[pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DHL
				WHERE
					DHL.[InstanceID] = @InstanceID AND
					DHL.[DimensionID] = @DimensionID AND
					DHL.[HierarchyNo] = @HierarchyNo AND
					DHL.[LevelNo] = @LevelNo

				SET @Updated = @Updated + @@ROWCOUNT
			END

	SET @Step = 'Insert'
		IF @DeleteYN = 0
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
					(
					[InstanceID],
					[DimensionID],
					[HierarchyNo],
					[LevelNo],
					[LevelName],
					[Comment]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[DimensionID] = @DimensionID,
					[HierarchyNo] = @HierarchyNo,
					[LevelNo] = @LevelNo,
					[LevelName] = @LevelName,
					[Comment] = @Comment
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] DHL WHERE DHL.[InstanceID] = @InstanceID AND DHL.[DimensionID] = @DimensionID AND DHL.[HierarchyNo] = @HierarchyNo AND DHL.[LevelNo] = @LevelNo)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Delete'
		IF @DeleteYN <> 0
			BEGIN
				DELETE
					[pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
				WHERE
					[InstanceID] = @InstanceID AND
					[DimensionID] = @DimensionID AND
					[HierarchyNo] = @HierarchyNo AND
					[LevelNo] = @LevelNo

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
