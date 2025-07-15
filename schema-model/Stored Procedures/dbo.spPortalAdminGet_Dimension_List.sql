SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Dimension_List]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@OrganizationHierarchyID int = NULL,
	@ProcessID int = NULL,
	@ResultTypeBM int = 1,
		-- 1 = List of Dimension
		-- 2 = List of Dimension Templates
		-- 4 = List of Dimension Types
		-- 8 = List of Data Classes
		-- 16 = List of Master Data Management

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000202,
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
--**********************************************
--**********************************************
--OBS! OBSOLETE, Replaced by [spPortalAdminGet_Dimension]
--**********************************************
--**********************************************

/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminGet_Dimension_List',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_Dimension_List] @UserID = -10, @InstanceID = 114, @VersionID = 1004, @ProcessID = 1004
EXEC [spPortalAdminGet_Dimension_List] @UserID = -10, @InstanceID = 304, @VersionID = 1001, @OrganizationHierarchyID = 1002, @Debug = 1

EXEC [spPortalAdminGet_Dimension_List] @GetVersion = 1
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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.0.2.2145'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return list of Dimension-related queries',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Enhanced structure.'

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

	SET @Step = 'Get List of Dimension'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT DISTINCT
					D.DimensionID,
					D.DimensionName,
					D.DimensionDescription,
					[ReadSecurityEnabledYN] = ISNULL(DST.ReadSecurityEnabledYN, 0)
				FROM
					Dimension D 
					INNER JOIN DataClass_Dimension DCD ON DCD.InstanceID = @InstanceID AND DCD.VersionID = @VersionID AND DCD.DimensionID = D.DimensionID
					INNER JOIN DataClass_Process DCP ON DCP.InstanceID = @InstanceID AND DCP.VersionID = @VersionID AND DCP.DataClassID = DCD.DataClassID AND (DCP.ProcessID = @ProcessID OR @ProcessID IS NULL)
					INNER JOIN OrganizationHierarchy_Process OHP ON OHP.InstanceID = @InstanceID AND (OHP.OrganizationHierarchyID = @OrganizationHierarchyID OR @OrganizationHierarchyID IS NULL) AND OHP.ProcessID = DCP.ProcessID
					LEFT JOIN Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = D.DimensionID
				ORDER BY
					D.DimensionName

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Get List of Dimension Templates'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT 
					[DimensionID],
					[DimensionName],
					[DimensionDescription],
					[DimensionTypeID]    
				FROM 
					[pcINTEGRATOR].[dbo].[@Template_Dimension] TD
				WHERE 
					InstanceID = 0 AND
					SelectYN <> 0 AND 
					DeletedID IS NULL AND
					Introduced < = @Version AND
					TD.DimensionID < 0 AND 
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST WHERE DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = TD.DimensionID)
			
			SET @Selected = @Selected + @@ROWCOUNT
		END

	SET @Step = 'Get List of Dimension Templates'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT 
					[DimensionTypeID],
					[DimensionTypeName]
				FROM 
					[pcINTEGRATOR].[dbo].[DimensionType]
				WHERE
					[DimensionTypeID] >= -1 AND
					[InstanceID] IN (0, @InstanceID)

				SET @Selected = @Selected + @@ROWCOUNT
			END
			
	SET @Step = 'Get List of Data Classes'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT 
					DC.[DataClassID],
					DC.[DataClassName],
					DC.[DataClassDescription],
					DCT.DataClassTypeName
				FROM 
					[pcINTEGRATOR_Data].[dbo].[DataClass] DC
					INNER JOIN [pcINTEGRATOR].[dbo].[DataClassType] DCT ON DCT.[DataClassTypeID] = DC.[DataClassTypeID]
				WHERE 
					DC.[InstanceID] = @InstanceID AND
					DC.[VersionID] = @VersionID AND
					DC.[SelectYN] <> 0 AND
					DC.[DeletedID] IS NULL
			
				SET @Selected = @Selected + @@ROWCOUNT
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
