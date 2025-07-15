SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_OrganizationPosition_ReadDC]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@OrganizationPositionID int = NULL, 
	@DataClassID int = NULL,
	@Comment nvarchar(100) = NULL,
	@ReadAccessYN bit = 1,
	@WriteAccessYN bit = 0,
	@SetDescendantYN bit = 0,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000271,
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
--UPDATE / INSERT
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"Debug","TValue":"7"},
{"TKey":"Comment","TValue":""},{"TKey":"SetDescendantYN","TValue":"false"},{"TKey":"DeleteYN","TValue":"false"},
{"TKey":"InstanceID","TValue":"413"},{"TKey":"UserID","TValue":"2147"},{"TKey":"VersionID","TValue":"1008"},
{"TKey":"ReadAccessYN","TValue":"true"},
{"TKey":"WriteAccessYN","TValue":"true"},
{"TKey":"DataClassID","TValue":"1028"},{"TKey":"OrganizationPositionID","TValue":"1135"}
]', @ProcedureName='spPortalAdminSet_OrganizationPosition_ReadDC'

EXEC [spPortalAdminSet_OrganizationPosition_ReadDC] 
	 @UserID=2147, 
	 @InstanceID=413,
	 @VersionID=1008,
	 @DataClassID=1032, 
	 @OrganizationPositionID=1135, 
	 @Comment='Inherited from DC: Voucher',
	 @ReadAccessYN=0,
	 @DeleteYN=0,
	 @Debug = 1

--UPDATE / INSERT
EXEC [spPortalAdminSet_OrganizationPosition_ReadDC]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@OrganizationPositionID = 1001,
	@DataClassID = -9

--DELETE
EXEC [spPortalAdminSet_OrganizationPosition_ReadDC]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@OrganizationPositionID = 1001,
	@DataClassID = -9,
	@DeleteYN = 1

EXEC spPortalAdminSet_OrganizationPosition_ReadDC @Comment='',@DataClassID='1026',@DeleteYN='false',@InstanceID='413',@OrganizationPositionID='1134',@ReadAccessYN='false',@SetDescendantYN='true',@UserID='2147',@VersionID='1008',@Debug = 1
EXEC spPortalAdminSet_OrganizationPosition_ReadDC @Comment='',@DataClassID='3770',@DeleteYN='false',@InstanceID='413',@OrganizationPositionID='1134',@ReadAccessYN='false',@SetDescendantYN='true',@UserID='2147',@VersionID='1008',@Debug = 1

--GetVersion
	EXEC [spPortalAdminSet_OrganizationPosition_ReadDC] @GetVersion = 1
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.0.2163'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set read/write level Security for DataClasses',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2140' SET @Description = 'Updated template.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.1.0.2161' SET @Description = 'Added VersionID to [OrganizationPosition_DataClass] and WriteAccessYN'
		IF @Version = '2.1.0.2163' SET @Description = 'Modified UPDATE query of [OrganizationPosition_DataClass] by setting the correct VersionID.'

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

	SET @Step = 'Create temp table #OrganizationPosition.'
		CREATE TABLE #OrganizationPosition
			(
			OrganizationPositionID bigint,
			Checked bit
			)

	SET @Step = 'Fill temp table #OrganizationPosition.'
		INSERT INTO #OrganizationPosition
			(
			OrganizationPositionID,
			Checked 
			)
		SELECT
			OrganizationPositionID = @OrganizationPositionID,
			Checked = CASE WHEN @SetDescendantYN = 0 THEN 1 ELSE 0 END

	SET @Step = 'Loop all Parents'
		WHILE (SELECT COUNT(1) FROM #OrganizationPosition WHERE Checked = 0) > 0
			BEGIN
				DECLARE OrganizationPosition_Cursor CURSOR FOR

				SELECT 
					OrganizationPositionID
				FROM
					#OrganizationPosition
				WHERE
					Checked = 0

				OPEN OrganizationPosition_Cursor
				FETCH NEXT FROM OrganizationPosition_Cursor INTO @OrganizationPositionID

				WHILE @@FETCH_STATUS = 0
					BEGIN
						INSERT INTO #OrganizationPosition
							(
							OrganizationPositionID,
							Checked 
							)
						SELECT
							OrganizationPositionID = OrganizationPositionID,
							Checked = 0
						FROM
							OrganizationPosition
						WHERE
							InstanceID = @InstanceID AND
							VersionID = @VersionID AND
							ParentOrganizationPositionID = @OrganizationPositionID
							
						UPDATE #OrganizationPosition
						SET
							Checked = 1
						WHERE
							OrganizationPositionID = @OrganizationPositionID

						FETCH NEXT FROM OrganizationPosition_Cursor INTO @OrganizationPositionID
					END

				CLOSE OrganizationPosition_Cursor
				DEALLOCATE OrganizationPosition_Cursor	

			END

		IF @Debug <> 0 SELECT * FROM #OrganizationPosition

	SET @Step = 'Update existing member'
		IF @DeleteYN = 0
			BEGIN
				UPDATE OPDC
				SET
					Comment = @Comment,
					ReadAccessYN = CASE WHEN @WriteAccessYN <> 0 THEN 1 ELSE @ReadAccessYN END,
					WriteAccessYN = @WriteAccessYN
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DataClass] OPDC
					INNER JOIN #OrganizationPosition OP ON OP.OrganizationPositionID = OPDC.OrganizationPositionID
				WHERE
					OPDC.InstanceID = @InstanceID AND
					OPDC.VersionID = @VersionID AND
					OPDC.DataClassID = @DataClassID

				SET @Updated = @Updated + @@ROWCOUNT
	
				IF @Updated > 0
					SET @Message = 'The members are updated.' 

				SET @Severity = 0
			END

	SET @Step = 'Delete existing member'
		IF @DeleteYN <> 0
			BEGIN
				DELETE OPDC
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DataClass] OPDC
					INNER JOIN #OrganizationPosition OP ON OP.OrganizationPositionID = OPDC.OrganizationPositionID
				WHERE
					OPDC.InstanceID = @InstanceID AND
					OPDC.VersionID = @VersionID AND
					OPDC.DataClassID = @DataClassID

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The members are deleted.' 

				SET @Severity = 0
			END

	SET @Step = 'Insert new member'
		IF @DeleteYN = 0 --AND @Updated = 0
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DataClass]
					(
					Comment,
					InstanceID,
					VersionID,
					OrganizationPositionID,
					DataClassID,
					ReadAccessYN,
					WriteAccessYN
					)
				SELECT
					Comment = @Comment,
					InstanceID = @InstanceID,
					VersionID = @VersionID,
					OrganizationPositionID = OP.OrganizationPositionID,
					DataClassID = @DataClassID,
					ReadAccessYN = CASE WHEN @WriteAccessYN <> 0 THEN 1 ELSE @ReadAccessYN END,
					WriteAccessYN = @WriteAccessYN
				FROM
					#OrganizationPosition OP
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DataClass] OPDC WHERE OPDC.OrganizationPositionID = OP.OrganizationPositionID AND OPDC.DataClassID = @DataClassID)

				SET @Inserted = @Inserted + @@ROWCOUNT

				IF @Inserted > 0
					SET @Message = 'The new members are added.' 

				SET @Severity = 0
			END

	SET @Step = 'Drop temp table'
		DROP TABLE #OrganizationPosition

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
