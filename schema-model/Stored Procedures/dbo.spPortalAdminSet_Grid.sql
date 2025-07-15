SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Grid]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@GridID int = NULL,
	@GridName nvarchar(50) = NULL,
	@GridDescription nvarchar(50) = NULL,
	@DataClassID int = NULL,	
	@GetProc nvarchar(100) = '[spPortalGet_DataClass_Data]',
	@SetProc nvarchar(100) = '[spPortalSet_DataClass_Data]',
	@InheritedFrom int = NULL,
	@DeleteYN bit = 0,
	@NewGridID int = NULL OUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000494,
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
	@ProcedureName = 'spPortalAdminSet_Grid',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

--UPDATE
EXEC [spPortalAdminSet_Grid]
	@UserID = -10,
	@InstanceID = 413,
	@VersionID = 1008,
	@GridID = 12482,
	@GridName = 'TestGrid1-Updated',
	@GridDescription = 'TestGridDescription1-Updated',
	@DataClassID = 1028,
	@InheritedFrom = -130,
	@DeleteYN = 0

--DELETE
EXEC [spPortalAdminSet_Grid]
	@UserID = -10,
	@InstanceID = 413,
	@VersionID = 1008,
	@GridID = 12483,
	@DeleteYN = 1

--INSERT
EXEC [spPortalAdminSet_Grid]
	@UserID = -10,
	@InstanceID = 413,
	@VersionID = 1008,
	@GridName = 'TestGrid1234',
	@GridDescription = 'TestGridDescription1234',
	@DataClassID = 1028,
	@InheritedFrom = -130,
	@DeleteYN = 0

EXEC [spPortalAdminSet_Grid] @GetVersion = 1
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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2164'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Update Dimension list for a specific Grid',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-302: Added @InheritedFrom and @NewGridID parameters.'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-485: Return the correct newly added GridID.'
		IF @Version = '2.1.0.2164' SET @Description = 'DB-599: Return the correct GridID.'

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

	SET @Step = 'Update existing member'
		IF @DeleteYN = 0 AND @GridID IS NOT NULL
			BEGIN
				IF @Debug <> 0 SELECT 'Update'
				UPDATE G
				SET
					[GridName] = ISNULL(@GridName, G.[GridName]),
					[GridDescription] = ISNULL(@GridDescription, G.[GridDescription]),
					[DataClassID] = ISNULL(@DataClassID, G.[DataClassID]),
					[GetProc] = @GetProc,
					[SetProc] = @SetProc,
					[InheritedFrom] = ISNULL(@InheritedFrom, G.[InheritedFrom])
				FROM
					[pcINTEGRATOR_Data].[dbo].[Grid] G
				WHERE
					G.[InstanceID] = @InstanceID AND
					G.[VersionID] = @VersionID AND
					G.[GridID] = @GridID

				SET @Updated = @Updated + @@ROWCOUNT

				IF @Updated > 0
					SET @Message = 'The Grid is updated.' 
				ELSE
					SET @Message = 'No Grid is updated.' 
				SET @Severity = 0
			END

	SET @Step = 'Delete existing member'
		IF @DeleteYN <> 0
			BEGIN
				IF @Debug <> 0 SELECT 'Delete'
				DELETE GD
				FROM
					[pcINTEGRATOR_Data].[dbo].[Grid_Dimension] GD
				WHERE
					GD.[InstanceID] = @InstanceID AND
					GD.[VersionID] = @VersionID AND
					GD.[GridID] = @GridID 

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'Grid_Dimension is deleted.' 
				ELSE
					SET @Message = 'No Grid_Dimension is deleted.' 
				SET @Severity = 0

				DELETE G
				FROM
					[pcINTEGRATOR_Data].[dbo].[Grid] G
				WHERE
					G.[InstanceID] = @InstanceID AND
					G.[VersionID] = @VersionID AND
					G.[GridID] = @GridID

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'Grid is deleted.' 
				ELSE
					SET @Message = 'No Grid is deleted.' 
				SET @Severity = 0
			END

	SET @Step = 'Insert new Grid'
		IF @DeleteYN = 0 AND @Updated = 0 AND @GridID IS NULL
			BEGIN
				IF @Debug <> 0 SELECT 'Insert'

				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Grid]
					(
					[InstanceID],
					[VersionID],
					[GridName],
					[GridDescription],
					[DataClassID],
					[GridSkinID],
					[GetProc],
					[SetProc],
					[InheritedFrom]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[GridName] = @GridName,
					[GridDescription] = @GridDescription,
					[DataClassID] = @DataClassID,
					[GridSkinID] = 0,
					[GetProc] = @GetProc,
					[SetProc] = @SetProc,
					[InheritedFrom] = @InheritedFrom
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Grid] G WHERE G.InstanceID = @InstanceID AND G.VersionID = @VersionID AND G.GridName = @GridName AND G.DataClassID = @DataClassID)

				SELECT 
					@NewGridID = @@IDENTITY,
					@Inserted = @Inserted + @@ROWCOUNT

--				IF @Debug & 1 > 0 SELECT [@NewGridID] = @NewGridID
				
				IF @Inserted > 0
					SET @Message = 'The new Grid is added.' 
				ELSE
					SET @Message = 'No Grid is added.' 
			END

	SET @Step = 'Return new GridID'
		IF @DeleteYN = 0
			SELECT
				[@NewGridID] = GridID
			FROM
				[pcINTEGRATOR_Data].[dbo].[Grid] G
			WHERE
				G.InstanceID = @InstanceID AND
				G.VersionID = @VersionID AND
				G.GridName = @GridName AND
				G.DataClassID = @DataClassID

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
