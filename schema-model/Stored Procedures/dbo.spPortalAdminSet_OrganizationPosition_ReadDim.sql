SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_OrganizationPosition_ReadDim]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@OrganizationPositionID int = NULL, 
	@DimensionID int = NULL,
	@HierarchyNo int = 0,
	@Dimension_MemberKey nvarchar(100) = NULL,
	@Comment nvarchar(100) = NULL,
	@ReadAccessYN bit = 1,
	@WriteAccessYN bit = 0,
	@SetDescendantYN bit = 0,
	@DeleteYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000270,
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
EXEC [spPortalAdminSet_OrganizationPosition_ReadDim]
	@UserID = -10,
	@InstanceID = 454,
	@VersionID = 1021,
	@OrganizationPositionID = 6318,
	@DimensionID = -4,
	@Dimension_MemberKey = 'NorthAmerica',
	@WriteAccessYN = 1

--DELETE
EXEC [spPortalAdminSet_OrganizationPosition_ReadDim]
	@UserID = -10,
	@InstanceID = 304,
	@VersionID = 1001,
	@OrganizationPositionID = 1001,
	@DimensionID = -9,
	@DeleteYN = 1

EXEC [spPortalAdminSet_OrganizationPosition_ReadDim] @GetVersion = 1
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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2165'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set Read/Write Dims for OrganizationPosition.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.1.0.2161' SET @Description = 'Handle write access and HierarchyNo.'
		IF @Version = '2.1.0.2163' SET @Description = 'Fixed bug with duplicating row when setting write access.'
		IF @Version = '2.1.0.2165' SET @Description = 'DB-607: Fixed bug with duplicating row when setting write access.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		IF @DebugBM & 2 > 0
			SELECT 
				[@OrganizationPositionID] = @OrganizationPositionID, 
				[@DimensionID] = @DimensionID,
				[@HierarchyNo] = @HierarchyNo,
				[@Dimension_MemberKey] = @Dimension_MemberKey,
				[@Comment] = @Comment,
				[@ReadAccessYN] = @ReadAccessYN,
				[@WriteAccessYN] = @WriteAccessYN,
				[@SetDescendantYN] = @SetDescendantYN,
				[@DeleteYN] = @DeleteYN

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
						IF @DebugBM & 2 > 0 SELECT [@OrganizationPositionID] = @OrganizationPositionID
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

		IF @DebugBM & 2 > 0 SELECT TempTable = '#OrganizationPosition', * FROM #OrganizationPosition

	SET @Step = 'Update existing member'
		IF @DeleteYN = 0
			BEGIN
				UPDATE OPDM
				SET
					Comment = @Comment,
					MemberKey = @Dimension_MemberKey,
					ReadAccessYN = CASE WHEN @WriteAccessYN <> 0 THEN 1 ELSE @ReadAccessYN END,
					WriteAccessYN = @WriteAccessYN
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DimensionMember] OPDM
					INNER JOIN #OrganizationPosition OP ON OP.OrganizationPositionID = OPDM.OrganizationPositionID
				WHERE
					OPDM.InstanceID = @InstanceID AND
					OPDM.VersionID = @VersionID AND
					OPDM.DimensionID = @DimensionID AND
					OPDM.HierarchyNo = @HierarchyNo AND
					OPDM.MemberKey = @Dimension_MemberKey

				SET @Updated = @Updated + @@ROWCOUNT

				IF @Updated > 0
					SET @Message = 'The members are updated.' 

				SET @Severity = 0
			END

	SET @Step = 'Delete existing member'
		IF @DeleteYN <> 0
			BEGIN
				DELETE OPDM
				FROM
					[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DimensionMember] OPDM
					INNER JOIN #OrganizationPosition OP ON OP.OrganizationPositionID = OPDM.OrganizationPositionID
				WHERE
					OPDM.InstanceID = @InstanceID AND
					OPDM.VersionID = @VersionID AND
					OPDM.DimensionID = @DimensionID AND
					OPDM.HierarchyNo = @HierarchyNo AND
					OPDM.MemberKey = @Dimension_MemberKey

				SET @Deleted = @Deleted + @@ROWCOUNT

				IF @Deleted > 0
					SET @Message = 'The members are deleted.' 

				SET @Severity = 0
			END

	SET @Step = 'Insert new member'
		IF @DeleteYN = 0
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DimensionMember]
					(
					Comment,
					InstanceID,
					VersionID,
					OrganizationPositionID,
					DimensionID,
					HierarchyNo,
					MemberKey,
					ReadAccessYN,
					WriteAccessYN
					)
				SELECT
					Comment = @Comment,
					InstanceID = @InstanceID,
					VersionID = @VersionID,
					OrganizationPositionID = OP.OrganizationPositionID,
					DimensionID = @DimensionID,
					HierarchyNo = @HierarchyNo,
					MemberKey = @Dimension_MemberKey,
					ReadAccessYN = CASE WHEN @WriteAccessYN <> 0 THEN 1 ELSE @ReadAccessYN END,
					WriteAccessYN = @WriteAccessYN
				FROM
					#OrganizationPosition OP
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DimensionMember] OPDM WHERE OPDM.OrganizationPositionID = OP.OrganizationPositionID AND OPDM.DimensionID = @DimensionID AND OPDM.HierarchyNo = @HierarchyNo AND OPDM.MemberKey = @Dimension_MemberKey)

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
		EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
