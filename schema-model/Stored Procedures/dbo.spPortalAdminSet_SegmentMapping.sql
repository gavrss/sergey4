SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_SegmentMapping]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JSON_table nvarchar(MAX) = NULL,
	@ResultTypeBM int = NULL, --1=Entity, 2=Book, 4=Segment
	@EntityID int = NULL,
	@Book nvarchar(50) = NULL,
	@SegmentCode nvarchar(50) = NULL,
	@SegmentName nvarchar(100) = NULL,
	@SelectYN bit = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000242,
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
DECLARE	@JSON_table nvarchar(MAX) = '
	[
	{"ResultTypeBM" : "1", "EntityID": "123", "SelectYN": "1"},
	{"ResultTypeBM" : "2", "EntityID": "123", "Book": "MAIN", "SelectYN": "1"},
	{"ResultTypeBM" : "4", "EntityID": "123", "Book": "MAIN", "SegmentCode": "CostCenter", "SegmentName": "GL_CostCenter", "SelectYN": "1"}
	]'

EXEC [dbo].[spPortalAdminSet_SegmentMapping] 
	@UserID = -10,
	@InstanceID = 52,
	@VersionID = 1035,
	@DebugBM = 7,
	@JSON_table = @JSON_table

EXEC [dbo].[spPortalAdminSet_SegmentMapping] 
	@UserID = -10,
	@InstanceID = -1057,
	@VersionID = -1057,
	@ResultTypeBM = 1, --Mandatory 1 will update Entity, 2 will update Entity_Book, 4 will update Journal_SegmentNo
	@EntityID = NULL, --Mandatory
	@Book = NULL, --Optional, mandatory when updating Entity_Book or Journal_SegmentNo
	@SegmentCode = NULL, --Optional, mandatory when updating Journal_SegmentNo
	@SegmentName = NULL, --Optional, mandatory when updating Journal_SegmentNo
	@SelectYN = NULL --Mandatory

EXEC [spPortalAdminSet_SegmentMapping] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2162'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set SegmentMapping',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2154' SET @Description = 'Use JSON table.'
		IF @Version = '2.1.0.2162' SET @Description = 'Updated template.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

	SET @Step = 'Create and fill #MappingTable'
		CREATE TABLE #MappingTable
			(
			[ResultTypeBM] int,
			[EntityID] int,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SegmentCode] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SegmentName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SelectYN] bit
			)			

		IF @JSON_table IS NOT NULL	
			INSERT INTO #MappingTable
				(
				[ResultTypeBM],
				[EntityID],
				[Book],
				[SegmentCode],
				[SegmentName],
				[SelectYN]
				)
			SELECT
				[ResultTypeBM],
				[EntityID],
				[Book],
				[SegmentCode],
				[SegmentName],
				[SelectYN]
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				[ResultTypeBM] int,
				[EntityID] int,
				[Book] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[SegmentCode] nvarchar(50) COLLATE DATABASE_DEFAULT,
				[SegmentName] nvarchar(100) COLLATE DATABASE_DEFAULT,
				[SelectYN] bit
				)
		ELSE
			INSERT INTO #MappingTable
				(
				[ResultTypeBM],
				[EntityID],
				[Book],
				[SegmentCode],
				[SegmentName],
				[SelectYN]
				)
			SELECT
				[ResultTypeBM] = @ResultTypeBM,
				[EntityID] = @EntityID,
				[Book] = @Book,
				[SegmentCode] = @SegmentCode,
				[SegmentName] = @SegmentName,
				[SelectYN] = @SelectYN

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#MappingTable', * FROM #MappingTable

	SET @Step = 'ResultTypeBM = 1, Entities'
		UPDATE
			E
		SET
			[SelectYN] = ISNULL(MT.[SelectYN], E.[SelectYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN #MappingTable MT ON MT.[ResultTypeBM] & 1 > 0 AND MT.[EntityID] = E.[EntityID]
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID
			
		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'ResultTypeBM = 2, Books'
		UPDATE EB
		SET
			[SelectYN] = ISNULL(MT.[SelectYN], EB.[SelectYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID]
			INNER JOIN #MappingTable MT ON MT.[ResultTypeBM] & 2 > 0 AND MT.[EntityID] = EB.[EntityID] AND MT.[Book] = EB.[Book]
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'ResultTypeBM = 4, Segments'
		UPDATE JSN
		SET
			[SegmentName] = ISNULL(MT.[SegmentName], JSN.[SegmentName]),
			[SelectYN] = ISNULL(MT.[SelectYN], JSN.[SelectYN])
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID]
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.[InstanceID] = EB.[InstanceID] AND JSN.[VersionID] = EB.[VersionID] AND JSN.[EntityID] = EB.[EntityID] AND JSN.[Book] = EB.[Book]
			INNER JOIN #MappingTable MT ON MT.[ResultTypeBM] & 4 > 0 AND MT.[EntityID] = JSN.[EntityID] AND MT.[Book] = JSN.[Book] AND MT.[SegmentCode] = JSN.[SegmentCode]
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Set SegmentNo'
		EXEC [spSet_SegmentNo] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @Debug = @DebugSub

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
