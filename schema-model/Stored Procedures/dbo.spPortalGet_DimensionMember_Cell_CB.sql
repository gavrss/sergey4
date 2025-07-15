SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_DimensionMember_Cell_CB]

@UserID int = NULL,
@InstanceID int = NULL,
@DimensionID int = NULL,
@HierarchyNo int = 0,
@HierarchyView nvarchar(10) = 'Parent', --'Parent' or 'Level'
@Column nvarchar(50) = NULL,
@JobID int = 0,
@GetVersion bit = 0,
@Debug bit = 0

--#WITH ENCRYPTION#--

AS

--EXEC [spPortalGet_DimensionMember_Cell_CB] @UserID = 1005, @InstanceID = 357, @DimensionID = -4, @HierarchyNo = 0, @HierarchyView = 'Level', @Column = 'Level', @Debug = 1

--EXEC [spPortalGet_DimensionMember] @InstanceID = 357
--EXEC [spPortalGet_DimensionMember] @GetVersion = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@UserName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2135'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2135' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserID IS NULL OR @InstanceID IS NULL OR @DimensionID IS NULL OR @Column IS NULL
	BEGIN
		PRINT 'Parameter @UserID, @InstanceID, @DimensionID and @Column must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT

	SET @Step = 'Set User Name'
		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT

	SET @Step = 'Return data'
		IF @Column = 'Level'
			BEGIN
				SELECT 
					[Level] = DHL.LevelName
				FROM
					DimensionHierarchyLevel DHL
					INNER JOIN
						(
						SELECT 
							InstanceID = MAX(DH.InstanceID),
							DH.DimensionID,
							DH.HierarchyNo
						FROM
							DimensionHierarchy DH
							
						WHERE
							(DH.InstanceID = @InstanceID OR DH.InstanceID = 0) AND
							DH.DimensionID = @DimensionID AND
							DH.HierarchyNo = @HierarchyNo
						GROUP BY
							DH.DimensionID,
							DH.HierarchyNo
						) sub ON sub.InstanceID = DHL.InstanceID AND sub.DimensionID = DHL.DimensionID AND sub.HierarchyNo = DHL.HierarchyNo
				ORDER BY
					DHL.LevelNo
			END

	SET @Step = 'Drop temp tables'

	SET @Step = 'EXITPOINT:'
		EXITPOINT:
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH


GO
