SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_LinkedDimension_MemberKey]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,
	@LinkedDimensionID int = NULL,

	@JobID int = 0,
	@Debug bit = 0,
	@Duration datetime = 0 OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@GetVersion bit = 0

AS

--EXEC [spPortalAdminGet_LinkedDimension_MemberKey] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @LinkedDimensionID = 1006

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@Parameter nvarchar(4000),
	@UserName nvarchar(100),
	@SQLStatement nvarchar(max),
	@DatabaseName nvarchar(100) = 'pcDATA_Christian_14',
	@DimensionName nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @UserID IS NULL OR @InstanceID IS NULL OR @VersionID IS NULL OR @LinkedDimensionID IS NULL
	BEGIN
		SET @Message = 'Parameter @UserID, @InstanceID, @VersionID AND @LinkedDimensionID must be set'
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
			'@LinkedDimensionID = ' + ISNULL(CONVERT(nvarchar(10), @LinkedDimensionID), 'NULL') + ', '
			
		SET @Parameter = LEFT(@Parameter, LEN(@Parameter) - 1)

	SET @Step = 'Get data'
		SELECT DISTINCT
			@DimensionName = D.DimensionName
		FROM
			Dimension D 
		WHERE
			DimensionID = @LinkedDimensionID

		SET @SQLStatement = '
			SELECT 
				Dim = ''' + @DimensionName + ''',
				MemberID = D.MemberID,
				MemberKey = D.Label,
				MemberDescription = D.[Description],
				NodeTypeBM = CASE D.RNodeType WHEN ''L'' THEN 1 WHEN ''P'' THEN 18 WHEN ''LC'' THEN 9 WHEN ''PC'' THEN 10 END,
				ParentMemberId = H.ParentMemberId,
				SortOrder = H.SequenceNumber
			FROM
				' + @DatabaseName + '..S_DS_' + @DimensionName + ' D
				INNER JOIN ' + @DatabaseName + '..S_HS_' + @DimensionName + '_' + @DimensionName + ' H ON H.MemberId = D.MemberId
			ORDER BY
				SortOrder,
				D.Label'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

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
