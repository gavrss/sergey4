SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_OrganizationPosition_DefaultDim]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@OrganizationPositionID int = NULL, 
	@DimensionID int = NULL,
	@DefaultHierarchyNo int = NULL,
	@DefaultMemberKey nvarchar(50) = NULL,
	@Comment nvarchar(100) = NULL,
	@SetDescendantYN bit = 0,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000628,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
--UPDATE / INSERT
EXEC [spPortalAdminSet_OrganizationPosition_DefaultDim] 
	@UserID = 2147, 
	@InstanceID = 413,
	@VersionID = 1008,
	@OrganizationPositionID = 1135, 
	@Comment = NULL,
	@DimensionID = -6,
	@DefaultHierarchyNo = 0,
	@DefaultMemberKey = 'ACTUAL_REPORT',
	@DeleteYN = 0,
	@SetDescendantYN = 1,
	@Debug = 1

--DELETE
EXEC [spPortalAdminSet_OrganizationPosition_DefaultDim]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@OrganizationPositionID = 1001,
	@DimensionID = -9,
	@DeleteYN = 1

--GetVersion
	EXEC [spPortalAdminSet_OrganizationPosition_DefaultDim] @GetVersion = 1

EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"Debug","TValue":"true"},
{"TKey":"Comment","TValue":"Dimension_StorageType"},{"TKey":"SetDescendantYN","TValue":"true"},
{"TKey":"DeleteYN","TValue":"false"},{"TKey":"InstanceID","TValue":"413"},{"TKey":"UserID","TValue":"2147"},
{"TKey":"VersionID","TValue":"1008"},{"TKey":"OrganizationPositionID","TValue":"1135"},
{"TKey":"DefaultHierarchyNo","TValue":"0"},{"TKey":"DefaultMemberKey","TValue":"All_"},{"TKey":"DimensionID","TValue":"-65"}
]', @ProcedureName='spPortalAdminSet_OrganizationPosition_DefaultDim'
*/

SET ANSI_WARNINGS OFF

DECLARE

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
	@DebugSub bit = 0,
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
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set default hierarchy and dimension member for specified OrganizationPosition and Dimension',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2161' SET @Description = 'Procedure created.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

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
				UPDATE OPD
				SET
					Comment = @Comment,
					[DefaultHierarchyNo] = @DefaultHierarchyNo,
					[DefaultMemberKey] = @DefaultMemberKey
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_Dimension] OPD
					INNER JOIN #OrganizationPosition OP ON OP.OrganizationPositionID = OPD.OrganizationPositionID
				WHERE
					OPD.InstanceID = @InstanceID AND
					OPD.VersionID = @VersionID AND
					OPD.DimensionID = @DimensionID

				SET @Updated = @Updated + @@ROWCOUNT

				IF @Updated > 0
					SET @Message = 'The members are updated.' 

				SET @Severity = 0
			END

	SET @Step = 'Delete existing member'
		IF @DeleteYN <> 0
			BEGIN
				DELETE OPD
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_Dimension] OPD
					INNER JOIN #OrganizationPosition OP ON OP.OrganizationPositionID = OPD.OrganizationPositionID
				WHERE
					OPD.InstanceID = @InstanceID AND
					OPD.VersionID = @VersionID AND
					OPD.DimensionID = @DimensionID

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The members are deleted.' 

				SET @Severity = 0
			END

	SET @Step = 'Insert new member'
		IF @DeleteYN = 0 --AND @Updated = 0
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_Dimension]
					(
					Comment,
					InstanceID,
					VersionID,
					OrganizationPositionID,
					DimensionID,
					[DefaultHierarchyNo],
					[DefaultMemberKey]
					)
				SELECT
					Comment = @Comment,
					InstanceID = @InstanceID,
					VersionID = @VersionID,
					OrganizationPositionID = OP.OrganizationPositionID,
					DimensionID = @DimensionID,
					[DefaultHierarchyNo] = @DefaultHierarchyNo,
					[DefaultMemberKey] = @DefaultMemberKey
				FROM
					#OrganizationPosition OP
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_Dimension] OPD WHERE OPD.OrganizationPositionID = OP.OrganizationPositionID AND OPD.DimensionID = @DimensionID)

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
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
