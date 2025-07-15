SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_LinkedDimension_List]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,
	@OrganizationHierarchyID int = NULL,

	@JobID int = 0,
	@Debug bit = 0,
	@Duration datetime = 0 OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@GetVersion bit = 0

AS

--EXEC [spPortalAdminGet_LinkedDimension_List] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @OrganizationHierarchyID = 1002
--EXEC [spPortalAdminGet_LinkedDimension_List] @UserID = -10, @InstanceID = 114, @VersionID = 1004, @OrganizationHierarchyID = 1009

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@Parameter nvarchar(4000),
	@UserName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserID IS NULL OR @InstanceID IS NULL OR @VersionID IS NULL OR @OrganizationHierarchyID IS NULL
	BEGIN
		SET @Message = 'Parameter @UserID, @InstanceID, @VersionID AND @OrganizationHierarchyID must be set'
		SET @Severity = 16
		GOTO EXITPOINT
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SET @UserName = suser_name()

		IF @JobID = 0
			SET @JobID = 10000000 + @InstanceID * 1000 + 1

		SET @Parameter = 
			'EXEC [spPortalAdminGet_LinkedDimension_List] ' +
			'@UserID = ' + ISNULL(CONVERT(nvarchar(10), @UserID), 'NULL') + ', ' +
			'@InstanceID = ' + ISNULL(CONVERT(nvarchar(10), @InstanceID), 'NULL') + ', ' +
			'@VersionID = ' + ISNULL(CONVERT(nvarchar(10), @VersionID), 'NULL') + ', ' +
			'@OrganizationHierarchyID = ' + ISNULL(CONVERT(nvarchar(10), @OrganizationHierarchyID), 'NULL') + ', '
			
		SET @Parameter = LEFT(@Parameter, LEN(@Parameter) - 1)

	SET @Step = 'Get data'
		SELECT DISTINCT
			D.DimensionID,
			D.DimensionName,
			D.DimensionDescription
		FROM
			OrganizationHierarchy OH
			INNER JOIN OrganizationHierarchy_Process OHP ON OHP.OrganizationHierarchyID = OH.OrganizationHierarchyID
			INNER JOIN DataClass_Process DCP ON DCP.ProcessID = OHP.ProcessID
			INNER JOIN DataClass_Dimension DCD ON DCD.DataClassID = DCP.DataClassID
			INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID
		WHERE
			OH.InstanceID = @InstanceID AND
			OH.VersionID = @VersionID AND
			OH.OrganizationHierarchyID = @OrganizationHierarchyID
		ORDER BY
			D.DimensionName

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version], [Parameter], [UserName]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version, @Parameter, @UserName
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
