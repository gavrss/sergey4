SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Journal_Segment]
(
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@Entity NVARCHAR(50) = NULL,
	@EntityID INT = NULL,
	@Book NVARCHAR(50) = NULL,

	@JobID int = NULL,
	@Rows int = NULL,
	@ProcedureID INT = 880000194,
	@Parameter NVARCHAR(4000) = NULL,
	@StartTime DATETIME = NULL,
	@Duration datetime = 0 OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,	
	@Updated int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0
)

/************************	PROBABLY OBSOLETE!!! **/

/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminGet_Journal_Segment',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "404"},
		{"TKey" : "VersionID",  "TValue": "1003"}
		]'
EXEC dbo.[spPortalAdminGet_Journal_Segment] @UserID = -10, @InstanceID = 404, @VersionID = 1003, @Debug = 1
EXEC dbo.[spPortalAdminGet_Journal_Segment] @GetVersion = 1
*/	

--#WITH ENCRYPTION#--

AS

DECLARE
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.1.2.2178'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2178' SET @Description = 'Get @EntityID from [pcIntegrator_Data].[dbo].[Entity] IF NULL.'

		IF ISNULL((SELECT [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = OBJECT_NAME(@@PROCID) AND DeletedID IS NULL), 0) <> @ProcedureID
			BEGIN
				SELECT @ProcedureID = [ProcedureID] FROM [Procedure] WHERE [ProcedureName] = OBJECT_NAME(@@PROCID) AND DeletedID IS NULL
				IF @ProcedureID IS NULL
					SET @Message = 'SP ' + OBJECT_NAME(@@PROCID) + ' is not registered. Run SP spInsert_Procedure'
				ELSE
					SET @Message = 'ProcedureID mismatch, should be ' + CONVERT(nvarchar(10), @ProcedureID)
				SET @Severity = 16
				GOTO EXITPOINT
			END
		SELECT [Version] = @Version, [Description] = @Description, [ProcedureID] = @ProcedureID
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())
		
	SET @Step = 'Set procedure variables'
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SET @UserName = suser_name()

		SELECT
			@EntityID = ISNULL(@EntityID, EntityID)
		FROM 
			[pcIntegrator_Data].[dbo].[Entity]
		WHERE 
			InstanceID  = @InstanceID AND
			VersionID = @VersionID AND
			MemberKey = @Entity AND
			SelectYN <> 0 AND
			DeletedID IS NULL 

	SET @Step = 'Return Name and description'
		SELECT
			[JobID],
			[InstanceID],
			[EntityID],
			[Book],
			[SegmentCode],
			[SegmentNo],
			[SegmentName],
			[DimensionID]
		FROM
			[Journal_SegmentNo]
		WHERE
			[InstanceID] = @InstanceID AND
			([EntityID] = @EntityID OR @EntityID IS NULL) AND
			([Book] = @Book OR @Book IS NULL)

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version, @Parameter, @UserName, @UserID, @InstanceID, @VersionID
				
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version], [Parameter], [UserName], [UserID], [InstanceID], [VersionID]) SELECT ISNULL(@JobID, @ProcedureID), @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version, @Parameter, @UserName, @UserID, @InstanceID, @VersionID
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
