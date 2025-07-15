SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Dimension_List]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ProcessID int = NULL,
	@DataClassID int = NULL,
	@ObjectGuiBehaviorBM int = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000140,
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
EXEC [spPortalGet_Dimension_List] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1
EXEC spPortalGet_Dimension_List @InstanceID='-1335',@ObjectGuiBehaviorBM='3',@UserID='-2060',@VersionID='-1273'
EXEC spPortalGet_Dimension_List @InstanceID='-1335',@ObjectGuiBehaviorBM='3',@UserID='-2060',@VersionID='-1273', @DataClassID=7480
EXEC spPortalGet_Dimension_List @InstanceID='-1335',@ObjectGuiBehaviorBM='3',@UserID='-2060',@VersionID='-1273', @ProcessID=6874

EXEC [spPortalGet_Dimension_List] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.3.2153'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return list of dimensions.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2135' SET @Description = 'Procedure created.'
		IF @Version = '1.4.0.2139' SET @Description = 'New format. VersionID added.'
		IF @Version = '2.0.2.2144' SET @Description = 'Enhanced structure. Added DimensionType in returning result set.'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-172: Add [ObjectGuiBehaviorBM] column into [Dimension_StorageType] table.'
		IF @Version = '2.0.3.2153' SET @Description = 'Removed old bug regarding filtering on @ProcessID and @DataClassID.'

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

	SET @Step = 'Insert rows into #DimensionList'
		SELECT DISTINCT
			[DimensionID] = D.[DimensionID],
			[DimensionName] = D.[DimensionName],
			[DimensionDescription] = D.[DimensionDescription],
			[ObjectGuiBehaviorBM] = DS.[ObjectGuiBehaviorBM],
			[ReadSecurityEnabledYN] = DS.[ReadSecurityEnabledYN],
			[DimensionTypeID] = D.[DimensionTypeID],
			[DimensionTypeName] = DT.[DimensionTypeName]
		INTO
			#DimensionList
		FROM
			Dimension D
			INNER JOIN Dimension_StorageType DS ON DS.InstanceID = @InstanceID AND DS.VersionID = @VersionID AND DS.DimensionID = D.DimensionID AND DS.ObjectGuiBehaviorBM & @ObjectGuiBehaviorBM > 0
			INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID
		WHERE 
			D.[InstanceID] IN (0, @InstanceID) AND
			D.SelectYN <> 0

	SET @Step = 'Remove rows from #DimensionList'
		IF @DataClassID IS NOT NULL
			DELETE DL 
			FROM
				#DimensionList DL
			WHERE
				NOT EXISTS (SELECT 1 FROM DataClass_Dimension DCD WHERE DCD.InstanceID = @InstanceID AND DCD.VersionID = @VersionID AND DCD.DimensionID = DL.DimensionID AND DCD.DataClassID = @DataClassID)

		IF @ProcessID IS NOT NULL
			DELETE DL
			FROM
				#DimensionList DL
			WHERE
				NOT EXISTS (SELECT 1 
							FROM
								DataClass_Process DCP 
								INNER JOIN DataClass_Dimension DCD ON DCD.DataClassID = DCP.DataClassID AND DCD.DimensionID = DL.DimensionID 
							WHERE
								DCP.InstanceID = @InstanceID AND
								DCP.VersionID = @VersionID AND
								DCP.ProcessID = @ProcessID)

	SET @Step = 'Return list of dimensions'
		SELECT DISTINCT
			[DimensionID],
			[DimensionName],
			[DimensionDescription],
			[ObjectGuiBehaviorBM],
			[ReadSecurityEnabledYN],
			[DimensionTypeID],
			[DimensionTypeName]
		FROM
			#DimensionList
		ORDER BY
			[DimensionName],
			[ObjectGuiBehaviorBM]

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Drop temp tables'
		DROP TABLE #DimensionList

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
