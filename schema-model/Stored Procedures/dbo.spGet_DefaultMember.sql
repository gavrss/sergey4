SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_DefaultMember]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@OrganizationPositionID int = NULL, --Optional
	@DimensionID int = NULL, --Optional
	@DataClassID int = NULL, --Optional
	@ProcessID int = NULL, --Optional
	@ResultTypeBM int = 1, --1 = DefaultMember, 2 = List of sources

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000629,
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
EXEC spGet_DefaultMember @UserID = -10, @InstanceID = 413, @VersionID = 1008, @OrganizationPositionID = 1237, @DebugBM = 3
EXEC spGet_DefaultMember @UserID = -10, @InstanceID = 413, @VersionID = 1008, @OrganizationPositionID = 1237
EXEC spGet_DefaultMember @UserID = -10, @InstanceID = 413, @VersionID = 1008
EXEC spGet_DefaultMember @UserID = -10, @InstanceID = 413, @VersionID = 1008, @DimensionID = -6

EXEC spGet_DefaultMember @UserID = 7564, @InstanceID = 454, @VersionID = 1021, @DataClassID = 7736, @DebugBM = 2
EXEC spGet_DefaultMember @UserID = 7564, @InstanceID = 454, @VersionID = 1021, @ResultTypeBM = 2
EXEC spGet_DefaultMember @ResultTypeBM = 2

EXEC [spGet_DefaultMember] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@CalledYN bit = 1,

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
	@Version nvarchar(50) = '2.1.2.2183'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Collect all default members from different sources.',
			@MandatoryParameter = ''

		IF @Version = '2.1.0.2161' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2162' SET @Description = 'Added @DataClassID'
		IF @Version = '2.1.2.2183' SET @Description = 'Get all dimensions from Dimension_StorageType, including InstanceID = 0'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

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

	SET @Step = 'Return list of Sources'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 2,
					*
				FROM
					[pcINTEGRATOR].[dbo].[DefaultMemberSource]
				ORDER BY
					[DefaultMemberSourceID]

				SET @Selected = @Selected + @@ROWCOUNT

				GOTO ResultTypeBM2
			END

	SET @Step = 'Create or truncate table #DefaultMember'
		IF OBJECT_ID(N'TempDB.dbo.#DefaultMember', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #DefaultMember
					(
					[StepID] int,
					[Source] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[OrganizationPositionID] int,
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[StorageTypeBM] int,
					[HierarchyNo] int,
					[HierarchyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Dimension_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT
					)
			END
		ELSE
			TRUNCATE TABLE #DefaultMember

	SET @Step = 'Create and fill temp table #DC'
		CREATE TABLE #DC (DataClassID int)

		INSERT INTO #DC
			(
			DataClassID
			)
		SELECT DISTINCT
			DCP.DataClassID 
		FROM
			pcINTEGRATOR_Data..DataClass_Process DCP
		WHERE
			DCP.ProcessID = @ProcessID AND
			(DCP.DataClassID = @DataClassID OR @DataClassID IS NULL) AND
			NOT EXISTS (SELECT 1 FROM #DC DC WHERE DC.DataClassID = DCP.DataClassID)

		INSERT INTO #DC
			(
			DataClassID
			)
		SELECT DISTINCT
			DataClassID = @DataClassID
		WHERE
			@DataClassID IS NOT NULL AND
			NOT EXISTS (SELECT 1 FROM #DC DC WHERE DC.DataClassID = @DataClassID)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DC', * FROM #DC ORDER BY DataClassID

	SET @Step = 'Create and fill temp table #Dim'
		CREATE TABLE #Dim (DimensionID int)

		INSERT INTO #Dim
			(
			DimensionID
			)
		SELECT DISTINCT
			DCD.DimensionID 
		FROM
			#DC DC
			INNER JOIN pcINTEGRATOR_Data..DataClass_Dimension DCD ON DCD.DataClassID = DC.DataClassID AND (DCD.DimensionID = @DimensionID OR @DimensionID IS NULL)

		IF (SELECT COUNT(1) FROM #DC) = 0
			INSERT INTO #Dim
				(
				DimensionID
				)
			SELECT DISTINCT
				DimensionID
			FROM
				pcINTEGRATOR..Dimension_StorageType DST
			WHERE
				DST.InstanceID IN (0, @InstanceID) AND
				DST.VersionID IN (0, @VersionID) AND
				(DST.DimensionID = @DimensionID OR @DimensionID IS NULL) AND
				NOT EXISTS (SELECT 1 FROM #Dim Dim WHERE Dim.DimensionID = DST.DimensionID)

		INSERT INTO #Dim
			(
			DimensionID
			)
		SELECT DISTINCT
			DimensionID = @DimensionID
		WHERE
			@DimensionID IS NOT NULL AND
			NOT EXISTS (SELECT 1 FROM #Dim Dim WHERE Dim.DimensionID = @DimensionID)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Dim', * FROM #Dim ORDER BY DimensionID

	SET @Step = 'Create temp table #HierarchyName'
		CREATE TABLE #HierarchyName
			(
			[DimensionID] int,
			[DimensionName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[HierarchyNo] int,
			[HierarchyName] nvarchar(50) COLLATE DATABASE_DEFAULT
			)
		
		INSERT INTO #HierarchyName
			(
			[DimensionID],
			[HierarchyNo],
			[HierarchyName]
			)
		SELECT
			DH.[DimensionID],
			DH.[HierarchyNo],
			DH.[HierarchyName]
		FROM
			[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH
			INNER JOIN #Dim Dim ON Dim.DimensionID = DH.DimensionID
		WHERE
			[InstanceID] IN (@InstanceID) AND
			[VersionID] IN (@VersionID)

		INSERT INTO #HierarchyName
			(
			[DimensionID],
			[HierarchyNo],
			[HierarchyName]
			)
		SELECT
			DH.[DimensionID],
			DH.[HierarchyNo],
			DH.[HierarchyName]
		FROM
			[pcINTEGRATOR].[dbo].[@Template_DimensionHierarchy] DH
			INNER JOIN #Dim Dim ON Dim.DimensionID = DH.DimensionID
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = DH.DimensionID
		WHERE
			DH.[InstanceID] IN (0) AND
			DH.[VersionID] IN (0) AND
			NOT EXISTS (SELECT 1 FROM #HierarchyName HN WHERE HN.DimensionID = DH.DimensionID AND HN.HierarchyNo = DH.HierarchyNo)

		UPDATE HN
		SET
			DimensionName = D.DimensionName
		FROM
			#HierarchyName HN
			INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = HN.DimensionID

		IF @DebugBM & 2 > 0 SELECT TempTable = '#HierarchyName', * FROM #HierarchyName ORDER BY DimensionID, HierarchyNo

	SET @Step = '1. Insert OrganizationPosition_Dimension setting'
		IF @OrganizationPositionID IS NOT NULL
			BEGIN
				INSERT INTO #DefaultMember
					(
					[StepID],
					[Source],
					[OrganizationPositionID],
					[DimensionID],
					[DimensionName],
					[HierarchyNo],
					[HierarchyName],
					[Dimension_MemberKey]
					)
				SELECT DISTINCT
					[StepID] = [DMS].[DefaultMemberSourceID],
					[Source] = [DMS].[Description],
					[OrganizationPositionID] = OPD.[OrganizationPositionID],
					[DimensionID] = OPD.[DimensionID],
					[DimensionName] = HN.[DimensionName],
					[HierarchyNo] = OPD.DefaultHierarchyNo,
					[HierarchyName] = HN.[HierarchyName],
					[Dimension_MemberKey] = OPD.DefaultMemberKey
				FROM
					pcINTEGRATOR_Data..OrganizationPosition_Dimension OPD
					INNER JOIN #Dim Dim ON Dim.DimensionID = OPD.DimensionID
					INNER JOIN #HierarchyName HN ON HN.DimensionID = OPD.DimensionID AND HN.HierarchyNo = OPD.DefaultHierarchyNo
					INNER JOIN [pcINTEGRATOR].[dbo].[DefaultMemberSource] [DMS] ON [DMS].[DefaultMemberSourceID] = 1
				WHERE
					OPD.InstanceID = @InstanceID AND
					OPD.VersionID = @VersionID AND
					OPD.[OrganizationPositionID] = @OrganizationPositionID AND
					(OPD.DimensionID = @DimensionID OR @DimensionID IS NULL) AND
					NOT EXISTS (SELECT 1 FROM #DefaultMember DM WHERE DM.[DimensionID] = OPD.[DimensionID])

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '2. Insert OrganizationPosition setting'
		IF @OrganizationPositionID IS NOT NULL
			BEGIN
				INSERT INTO #DefaultMember
					(
					[StepID],
					[Source],
					[OrganizationPositionID],
					[DimensionID],
					[DimensionName],
					[HierarchyNo],
					[HierarchyName],
					[Dimension_MemberKey]
					)
				SELECT DISTINCT
					[StepID] = [DMS].[DefaultMemberSourceID],
					[Source] = [DMS].[Description],
					[OrganizationPositionID] = OP.[OrganizationPositionID],
					[DimensionID] = OH.[LinkedDimensionID],
					[DimensionName] = HN.[DimensionName],
					[HierarchyNo] = 0,
					[HierarchyName] = HN.[HierarchyName],
					[Dimension_MemberKey] = OP.LinkedDimension_MemberKey
				FROM
					pcINTEGRATOR_Data..OrganizationPosition OP
					INNER JOIN pcINTEGRATOR_Data..OrganizationHierarchy OH ON OH.InstanceID = OP.InstanceID AND OH.VersionID = OP.VersionID AND OH.OrganizationHierarchyID = OP.OrganizationHierarchyID AND (OH.LinkedDimensionID = @DimensionID OR @DimensionID IS NULL) AND OH.DeletedID IS NULL
					INNER JOIN #HierarchyName HN ON HN.DimensionID = OH.LinkedDimensionID AND HN.HierarchyNo = 0
					INNER JOIN #Dim Dim ON Dim.DimensionID = OH.[LinkedDimensionID]
					INNER JOIN [pcINTEGRATOR].[dbo].[DefaultMemberSource] [DMS] ON [DMS].[DefaultMemberSourceID] = 2
				WHERE
					OP.InstanceID = @InstanceID AND
					OP.VersionID = @VersionID AND
					OP.[OrganizationPositionID] = @OrganizationPositionID AND
					NOT EXISTS (SELECT 1 FROM #DefaultMember DM WHERE DM.[DimensionID] = OH.[LinkedDimensionID])

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '3. WorkflowState'
		--Not handled here

	SET @Step = '4. Insert Dimension_StorageType setting'
		INSERT INTO #DefaultMember
			(
			[StepID],
			[Source],
			[OrganizationPositionID],
			[DimensionID],
			[DimensionName],
			[StorageTypeBM],
			[HierarchyNo],
			[HierarchyName],
			[Dimension_MemberKey]
			)
		SELECT DISTINCT
			[StepID] = [DMS].[DefaultMemberSourceID],
			[Source] = [DMS].[Description],
			[OrganizationPositionID] = NULL,
			[DimensionID] = DST.[DimensionID],
			[DimensionName] = HN.[DimensionName],
			[StorageTypeBM] = DST.[StorageTypeBM],
			[HierarchyNo] = DST.DefaultGetHierarchyNo,
			[HierarchyName] = HN.[HierarchyName],
			[Dimension_MemberKey] = DST.DefaultGetMemberKey
		FROM
			pcINTEGRATOR_Data..Dimension_StorageType DST
			INNER JOIN #HierarchyName HN ON HN.DimensionID = DST.DimensionID AND HN.HierarchyNo = DST.DefaultGetHierarchyNo
			INNER JOIN #Dim Dim ON Dim.DimensionID = DST.[DimensionID]
			INNER JOIN [pcINTEGRATOR].[dbo].[DefaultMemberSource] [DMS] ON [DMS].[DefaultMemberSourceID] = 4
		WHERE
			DST.InstanceID = @InstanceID AND
			DST.VersionID = @VersionID AND
			(DST.DimensionID = @DimensionID OR @DimensionID IS NULL) AND
			NOT EXISTS (SELECT 1 FROM #DefaultMember DM WHERE DM.[DimensionID] = DST.[DimensionID])

		SET @Selected = @Selected + @@ROWCOUNT

		UPDATE DM
		SET
			[StorageTypeBM] = DST.[StorageTypeBM]
		FROM
			#DefaultMember DM
			INNER JOIN pcINTEGRATOR_Data..Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = DM.DimensionID
		WHERE
			DM.[StorageTypeBM] IS NULL

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = '5. Insert Dimension setting'
		UPDATE DM
		SET
			[StepID] = [DMS].[DefaultMemberSourceID],
			[Source] = [DMS].[Description],
			[Dimension_MemberKey] = D.DefaultGetMemberKey
		FROM
			#DefaultMember DM
			INNER JOIN pcINTEGRATOR..Dimension D ON D.InstanceID = @InstanceID AND D.DimensionID = DM.DimensionID
			INNER JOIN [pcINTEGRATOR].[dbo].[DefaultMemberSource] [DMS] ON [DMS].[DefaultMemberSourceID] = 5
		WHERE
			DM.[Dimension_MemberKey] IS NULL

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Return rows and drop table #DefaultMember if SP not called'
		IF @CalledYN = 0
			BEGIN
				SELECT
					[ResultTypeBM] = 1,
					*
				FROM
					#DefaultMember
				ORDER BY
					[DimensionID],
					[HierarchyNo]

				DROP TABLE #DefaultMember
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #HierarchyName
		DROP TABLE #DC
		DROP TABLE #Dim

	SET @Step = 'Set @Duration'
		ResultTypeBM2:
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
