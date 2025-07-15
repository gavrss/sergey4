SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Feature]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@SecurityRoleID int = NULL, --Mandatory
	@ObjectID int = NULL,
	@DeleteYN bit = 0,
    
	@JSON_table nvarchar(max) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000430,
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

-- ADD single Feature
EXEC [spPortalAdminSet_Feature] 
	@UserID = -10, 
	@InstanceID = 390, 
	@VersionID = 1011, 
	@SecurityRoleID = 2404, 
	@ObjectID = -42, 
	@Debug = 1

-- ADD single Feature
EXEC [spPortalAdminSet_Feature] 
	@UserID = -10, 
	@InstanceID = 390, 
	@VersionID = 1011, 
	@SecurityRoleID = 2404, 
	@ObjectID = -43, 
	@Debug = 1

-- DELETE single Feature
EXEC [spPortalAdminSet_Feature] 
	@UserID = -10, 
	@InstanceID = 390, 
	@VersionID = 1011, 
	@SecurityRoleID = 2404, 
	@ObjectID = -42,
	@DeleteYN = 1, 
	@Debug = 1

-- ADD/DELETE multiple Features
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminSet_Feature',
	@JSON = '
		[
		{"TKey":"UserID", "TValue":"-10"},
		{"TKey":"InstanceID", "TValue":"390"},
		{"TKey":"VersionID", "TValue":"1011"},
		{"TKey":"SecurityRoleID", "TValue":"2404"},
		{"TKey":"Debug", "TValue":"1"}
		]',
	@JSON_table = '
		[
		{"ObjectID":"-26","DeleteYN":"0"},
		{"ObjectID":"-30","DeleteYN":"1"},
		{"ObjectID":"-36","DeleteYN":"0"},
		{"ObjectID":"-28","DeleteYN":"0"},
		{"ObjectID":"-29","DeleteYN":"1"},
		{"ObjectID":"-34","DeleteYN":"1"},
		{"ObjectID":"-39","DeleteYN":"0"},
		{"ObjectID":"-37","DeleteYN":"0"},
		{"ObjectID":"-27","DeleteYN":"1"},
		{"ObjectID":"-31","DeleteYN":"1"},
		{"ObjectID":"-38","DeleteYN":"0"},
		{"ObjectID":"-40","DeleteYN":"0"},
		{"ObjectID":"-41","DeleteYN":"0"},
		{"ObjectID":"-32","DeleteYN":"1"},
		{"ObjectID":"-33","DeleteYN":"1"},
		{"ObjectID":"-42","DeleteYN":"0"},
		{"ObjectID":"-43","DeleteYN":"0"}
		]'

DECLARE @JSON_table_Value nvarchar(max) = '
[{"ObjectID":"-30","DeleteYN":"0"},
{"ObjectID":"-36","DeleteYN":"0"},
{"ObjectID":"-28","DeleteYN":"0"},
{"ObjectID":"-29","DeleteYN":"0"},
{"ObjectID":"-34","DeleteYN":"0"},
{"ObjectID":"-39","DeleteYN":"0"},
{"ObjectID":"-37","DeleteYN":"0"},
{"ObjectID":"-27","DeleteYN":"0"},
{"ObjectID":"-31","DeleteYN":"0"},
{"ObjectID":"-38","DeleteYN":"0"},
{"ObjectID":"-40","DeleteYN":"0"},
{"ObjectID":"-41","DeleteYN":"0"},
{"ObjectID":"-32","DeleteYN":"0"},
{"ObjectID":"-33","DeleteYN":"0"},
{"ObjectID":"-42","DeleteYN":"0"},
{"ObjectID":"-43","DeleteYN":"1"},
{"ObjectID":"-26","DeleteYN":"0"}]'

EXEC spPortalAdminSet_Feature @InstanceID='413',@SecurityRoleID='-1',@UserID='2147',@VersionID='1008',@JSON_table=@JSON_table_Value, @Debug = 1

EXEC [spPortalAdminSet_Feature] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SecurityLevelBM int = 32,
	@SelectYN bit = 1,

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.2.2147'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Handles CREATE and DELETE of Features stored in SecurityRoleObject Table',
			@MandatoryParameter = 'SecurityRoleID' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'Added InstanceID to NOT Exists check. InstanceID is now part of the PrimaryKey for table SecurityRoleObject.'
		IF @Version = '2.0.2.2147' SET @Description = 'Added possibility to use this SP for setting Callisto Actions Access.'


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

	SET @Step = 'Create temp table #SecurityRoleObject'
		CREATE TABLE #SecurityRoleObject
			(
			InstanceID int,
			SecurityRoleID int,
			ObjectID int,
			DeleteYN bit
			)

	SET @Step = 'Insert data into temp table #SecurityRoleObject'
		IF @JSON_table IS NOT NULL
			INSERT INTO #SecurityRoleObject
				(
				InstanceID,
				SecurityRoleID,
				ObjectID,
				DeleteYN
				)
			SELECT
				[InstanceID] = @InstanceID,
				SecurityRoleID = @SecurityRoleID,
				ObjectID,
				DeleteYN
			FROM
				OPENJSON(@JSON_table)
			WITH
				(
				ObjectID int,
				DeleteYN bit
				)
		ELSE
			INSERT INTO #SecurityRoleObject
				(
				InstanceID,
				SecurityRoleID,
				ObjectID,
				DeleteYN
				)
			SELECT
				[InstanceID] = @InstanceID,
				SecurityRoleID = @SecurityRoleID,
				ObjectID = @ObjectID,
				DeleteYN = @DeleteYN	
				
		IF @Debug <> 0
			SELECT 
				[TempTable] = '#SecurityRoleObject', SRO.*, O.ObjectName
			FROM 
				#SecurityRoleObject SRO
				LEFT JOIN [pcINTEGRATOR].[dbo].[Object] O ON O.ObjectID = SRO.ObjectID

	SET @Step = 'SP-Specific check'
		IF (
			SELECT 
				COUNT(1) 
			FROM 
				#SecurityRoleObject SRO
			WHERE 
				NOT EXISTS(SELECT 1 FROM [pcINTEGRATOR].[dbo].[@Template_Object] O WHERE O.ObjectID = SRO.ObjectID AND O.[SelectYN] <> 0)
			) > 0
			BEGIN
				SET @Message = 'Invalid Objects selected. Only Feature and Callisto Action Access objects are allowed in this SP.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Set @SecurityLevelBM'
		SELECT
			@SecurityLevelBM = CASE WHEN MIN(ObjectID) < -100 THEN 1 ELSE 32 END
		FROM
			#SecurityRoleObject

	SET @Step = 'Delete SecurityRoleObject'
		DELETE SRO
		FROM
			[pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO
			INNER JOIN #SecurityRoleObject temp ON temp.InstanceID = SRO.InstanceID AND temp.SecurityRoleID = SRO.SecurityRoleID AND temp.ObjectID = SRO.ObjectID AND temp.DeleteYN <> 0
		
		SELECT @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Update SecurityRoleObject/s'
		UPDATE SRO
		SET 
			SelectYN = @SelectYN
		FROM 
			[pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO
			INNER JOIN #SecurityRoleObject temp ON temp.InstanceID = SRO.InstanceID AND temp.SecurityRoleID = SRO.SecurityRoleID AND temp.ObjectID = SRO.ObjectID AND temp.DeleteYN = 0
		WHERE 
			SRO.SelectYN = 0

		SELECT @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert single or multiple SecurityRoleObject/s'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject]
			(
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM],
			[SelectYN]
			)
		SELECT
			[InstanceID],
			[SecurityRoleID],
			[ObjectID],
			[SecurityLevelBM] = @SecurityLevelBM,
			[SelectYN] = @SelectYN
		FROM
			#SecurityRoleObject temp
		WHERE
			DeleteYN = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[SecurityRoleObject] SRO WHERE SRO.InstanceID = temp.InstanceID AND SRO.SecurityRoleID = temp.SecurityRoleID AND SRO.ObjectID = temp.ObjectID)

		SELECT @Inserted = @Inserted + @@ROWCOUNT

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
