SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_SIE4_Journal_SegmentNo]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000197,
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
	@ProcedureName = 'spPortalSet_SIE4_Journal_SegmentNo',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "404"},
		{"TKey" : "VersionID",  "TValue": "1003"},
		{"TKey" : "JobID",  "TValue": "24416"}
		]'

EXEC [spPortalSet_SIE4_Journal_SegmentNo] @UserID = -10, @InstanceID = 404, @VersionID = 1003, @JobID = 24416
EXEC [spPortalSet_SIE4_Journal_SegmentNo] @UserID = -10, @InstanceID = 533, @VersionID = 1058, @JobID = 367

EXEC [spPortalSet_SIE4_Journal_SegmentNo] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@EntityID int,
	@Book nvarchar(50),
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
	@Version nvarchar(50) = '2.1.1.2168'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set SegmentNo for Journal during SIE4 load',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2154' SET @Description = 'Removed all references to Journal_SegmentNo.Entity.'
		IF @Version = '2.1.1.2168' SET @Description = 'Create dimensions.'

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

	SET @Step = 'INSERT Segments INTO [dbo].[Journal_SegmentNo]'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo]
			(
			[JobID],
			[InstanceID],
			[EntityID],
			[Book],
			[SegmentCode],
			[SegmentName]
			)
		SELECT 
			[JobID] = D.[JobID],
			[InstanceID] = D.[InstanceID],
			[EntityID] = J.[EntityID],
			[Book] = 'GL',
			[SegmentCode] = D.[DimCode],
			[SegmentName] = D.DimName
		FROM
			[SIE4_Dim] D
			INNER JOIN [SIE4_Job] J ON J.InstanceID = D.InstanceID AND J.JobID = D.JobID
			INNER JOIN Entity E ON E.EntityID = J.EntityID
		WHERE
			D.InstanceID = @InstanceID AND
			D.JobID = @JobID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN WHERE JSN.InstanceID = D.InstanceID AND JSN.EntityID = E.EntityID AND JSN.Book = 'GL' AND JSN.SegmentCode = D.DimCode)

		SET @Inserted = @Inserted + @@rowcount

	SET @Step = 'INSERT Account INTO [dbo].[Journal_SegmentNo]'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo]
			(
			[JobID],
			[InstanceID],
			[EntityID],
			[Book],
			[SegmentCode],
			[SegmentNo],
			[SegmentName],
			[DimensionID]
			)
		SELECT DISTINCT
			[JobID] = D.[JobID],
			[InstanceID] = D.[InstanceID],
			[EntityID] = J.[EntityID],
			[Book] = 'GL',
			[SegmentCode] = -1,
			[SegmentNo] = 0,
			[SegmentName] = 'Account',
			[DimensionID] = -1
		FROM
			[SIE4_Dim] D
			INNER JOIN [SIE4_Job] J ON J.InstanceID = D.InstanceID AND J.JobID = D.JobID
			INNER JOIN Entity E ON E.EntityID = J.EntityID
		WHERE
			D.InstanceID = @InstanceID AND
			D.JobID = @JobID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN WHERE JSN.InstanceID = D.InstanceID AND JSN.EntityID = E.EntityID AND JSN.Book = 'GL' AND JSN.SegmentCode = -1)

		SET @Inserted = @Inserted + @@rowcount

	SET @Step = 'Run SegmentNo_Cursor'
		DECLARE SegmentNo_Cursor CURSOR FOR

			SELECT
				EntityID,
				Book
			FROM
				[Journal_SegmentNo]
			WHERE
				InstanceID = @InstanceID AND
				SegmentNo = -1

			OPEN SegmentNo_Cursor
			FETCH NEXT FROM SegmentNo_Cursor INTO @EntityID, @Book

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [@EntityID] = @EntityID, [@Book] = @Book

						SELECT @SegmentNo = MAX(SegmentNo) FROM [Journal_SegmentNo] WHERE EntityID = @EntityID AND Book = @Book

						WHILE (SELECT COUNT(1) FROM [Journal_SegmentNo] WHERE InstanceID = @InstanceID AND EntityID = @EntityID AND Book = @Book AND SegmentNo = -1) > 0
							BEGIN
								SET @SegmentNo = @SegmentNo + 1
			
								UPDATE JSO
								SET
									SegmentNo = @SegmentNo
								FROM
									[pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSO
									INNER JOIN (SELECT TOP 1 [SegmentCode] FROM [Journal_SegmentNo] WHERE [InstanceID] = @InstanceID AND [EntityID] = @EntityID AND Book = @Book AND SegmentNo = -1 ORDER BY CASE WHEN ISNUMERIC([SegmentCode]) = 0 THEN [SegmentCode] ELSE CONVERT(int, [SegmentCode]) END) DC ON DC.[SegmentCode] = JSO.[SegmentCode]
								WHERE
									JSO.InstanceID = @InstanceID AND
									JSO.EntityID = @EntityID AND
									JSO.Book = @Book 
							END

					FETCH NEXT FROM SegmentNo_Cursor INTO  @EntityID, @Book
				END

		CLOSE SegmentNo_Cursor
		DEALLOCATE SegmentNo_Cursor	

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
