SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_SegmentDimension]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000246,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

--OBSOLETE--
--Replaced by spSetup_Dimension @SourceTypeID = -11 and spSet_SegmentNo
--OBSOLETE--

AS
/*
EXEC [spPortalAdminSet_SegmentDimension] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spPortalAdminSet_SegmentDimension] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ModelingStatusID int = -40,
	@ModelingComment nvarchar(100) = 'Copied from Segment mapping',
	@SegmentName nvarchar(100),
	@SegmentNo int,

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
			@ProcedureDescription = 'Set SegmentDimension',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2154' SET @Description = 'Now obsolete and replaced by spSetup_Dimension @SourceTypeID = -11 and spSet_SegmentNo. Still not removed for legacy reasons.'

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

	SET @Step = 'Insert into Dimension'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension]
			(
			[InstanceID],
			[DimensionName],
			[DimensionDescription],
			[DimensionTypeID],
			[ObjectGuiBehaviorBM],
			[GenericYN],
			[MultipleProcedureYN],
			[AllYN],
			[HiddenMember],
			[Hierarchy],
			[TranslationYN],
			[DefaultSelectYN],
			[DefaultValue],
			[DeleteJoinYN],
			[SourceTypeBM],
			[MasterDimensionID],
			[HierarchyMasterDimensionID],
			[InheritedFrom],
			[SeedMemberID],
			[ModelingStatusID],
			[ModelingComment],
			[Introduced],
			[SelectYN]
			)
		SELECT DISTINCT
			[InstanceID] = @InstanceID,
			[DimensionName] = JSN.SegmentName,
			[DimensionDescription] = JSN.SegmentName,
			[DimensionTypeID] = -1,
			[ObjectGuiBehaviorBM] = 1,
			[GenericYN] = 1,
			[MultipleProcedureYN] = 0,
			[AllYN] = 1,
			[HiddenMember] = 'All',
			[Hierarchy] = NULL,
			[TranslationYN] = 1,
			[DefaultSelectYN] = 1,
			[DefaultValue] = NULL,
			[DeleteJoinYN] = 0,
			[SourceTypeBM] = 65535,
			[MasterDimensionID] = NULL,
			[HierarchyMasterDimensionID] = NULL,
			[InheritedFrom] = NULL,
			[SeedMemberID] = 1001,
			[ModelingStatusID] = @ModelingStatusID,
			[ModelingComment] = @ModelingComment,
			[Introduced] = @Version,
			[SelectYN] = 1
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.EntityID = E.EntityID AND EB.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.EntityID = EB.EntityID AND JSN.Book = EB.Book AND JSN.DimensionID IS NULL AND JSN.SelectYN <> 0
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			E.SelectYN <> 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension] D WHERE D.InstanceID = @InstanceID AND D.[DimensionName] = JSN.SegmentName)
		ORDER BY
			JSN.SegmentName

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Update DimensionID in Journal_SegmentNo'
		UPDATE JSN
		SET
			DimensionID = D.DimensionID
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.EntityID = E.EntityID AND EB.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.EntityID = EB.EntityID AND JSN.Book = EB.Book AND JSN.DimensionID IS NULL AND JSN.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension] D ON D.InstanceID = E.InstanceID AND D.[DimensionName] = JSN.SegmentName
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			E.SelectYN <> 0

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Update SegmentNo in Journal_SegmentNo'
		SELECT DISTINCT
			JSN.SegmentName,
			SegmentNo = CASE WHEN JSN.SegmentNo = -1 THEN NULL ELSE JSN.SegmentNo END
		INTO
			#SegmentNo
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.EntityID = E.EntityID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.EntityID = EB.EntityID AND JSN.Book = EB.Book
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID

		DECLARE SegmentNo_Cursor CURSOR FOR
			SELECT DISTINCT
				SegmentName
			FROM
				#SegmentNo
			WHERE
				SegmentNo IS NULL

			OPEN SegmentNo_Cursor
			FETCH NEXT FROM SegmentNo_Cursor INTO @SegmentName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SELECT @SegmentNo = MAX(SegmentNo) FROM #SegmentNo WHERE SegmentName = @SegmentName
					SET @SegmentNo = ISNULL(@SegmentNo, (SELECT MAX(SegmentNo) FROM #SegmentNo) + 1)
					
					UPDATE SN
					SET
						SegmentNo = @SegmentNo
					FROM
						#SegmentNo SN
					WHERE
						SN.SegmentName = @SegmentName

					FETCH NEXT FROM SegmentNo_Cursor INTO @SegmentName
				END

		CLOSE SegmentNo_Cursor
		DEALLOCATE SegmentNo_Cursor	
		
		UPDATE JSN
		SET
			SegmentNo = SN.SegmentNo
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.EntityID = E.EntityID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.EntityID = EB.EntityID AND JSN.Book = EB.Book AND (JSN.SegmentNo IS NULL OR JSN.SegmentNo = -1)
			INNER JOIN #SegmentNo SN ON SN.SegmentName = JSN.SegmentName
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID		
		
		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Drop temp tables'
		DROP TABLE #SegmentNo

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
