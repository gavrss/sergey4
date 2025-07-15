SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_AssignmentRow]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@WorkflowID int = NULL, --Optional
	@AssignmentID int = NULL, --Optional
	@OrganizationPositionID int = NULL, --Optional
	@DataClassID int = NULL, --Optional
	@ProcessID int = NULL, --Optional
	@DimensionID int = NULL, --Optional
	@UserDependentYN bit = 1,
	@ReadAccessYN bit = 0, 
	@ResultTypeBM int = 1, --1 = AssignmentRow, 2 = List of sources

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000066,
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
--Carrie
EXEC spGet_AssignmentRow @UserID = 7576, @InstanceID = 413, @VersionID = 1008, @UserDependentYN = 1,  @WorkflowID = NULL, @AssignmentID = NULL, @OrganizationPositionID = 2652, @Debug = 7

--Jean
EXEC spGet_AssignmentRow @UserID = 3848, @InstanceID = 413, @VersionID = 1008, @UserDependentYN = 1,  @WorkflowID = NULL, @AssignmentID = NULL, @OrganizationPositionID = 2794, @Debug = 7

EXEC spGet_AssignmentRow @UserID = 7564, @InstanceID = 454, @VersionID = 1021, @UserDependentYN = 0, @DebugBM = 2
EXEC spGet_AssignmentRow @UserID = 7564, @InstanceID = 454, @VersionID = 1021, @UserDependentYN = 0, @DimensionID = -7, @DebugBM = 2
EXEC spGet_AssignmentRow @UserID = 7564, @InstanceID = 454, @VersionID = 1021, @ReadAccessYN = 1, @Debug = 1
EXEC spGet_AssignmentRow @UserID = 8770, @InstanceID = 454, @VersionID = 1021, @ReadAccessYN = 1, @Debug = 1
EXEC spGet_AssignmentRow @UserID = 2016, @InstanceID = 304, @VersionID = 1001, @Debug = 1
EXEC spGet_AssignmentRow @UserID = 2120, @InstanceID = 114, @VersionID = 1004, @UserDependentYN = 1, @Debug = 1

EXEC spGet_AssignmentRow @UserID = 2016, @InstanceID = 304, @VersionID = 1001, @AssignmentID = 1106, @Debug = 1
EXEC spGet_AssignmentRow @UserID = 2018, @InstanceID = 304, @VersionID = 1001, @Debug = 1
EXEC spGet_AssignmentRow @UserID = -1435, @InstanceID = -1184, @VersionID = -1122, @UserDependentYN = 0, @Debug = 1
EXEC spGet_AssignmentRow @UserID = -1435, @InstanceID = -1184, @VersionID = -1122, @WorkflowID = 2179, @UserDependentYN = 0

EXEC spGet_AssignmentRow @UserID = 7564, @InstanceID = 454, @VersionID = 1021, @DimensionID = -7, @DebugBM = 2
EXEC spGet_AssignmentRow @UserID = 7564, @InstanceID = 454, @VersionID = 1021, @DataClassID = 7736, @DebugBM = 2
EXEC spGet_AssignmentRow @UserID = 7564, @InstanceID = 454, @VersionID = 1021, @ProcessID = 7168, @DebugBM = 2

EXEC spGet_AssignmentRow @UserID = 7564, @InstanceID = 454, @VersionID = 1021, @ProcessID = 7168, @ResultTypeBM = 2
EXEC spGet_AssignmentRow @UserID = 3806, @InstanceID = 413, @VersionID = 1008, @OrganizationPositionID= 1173, @UserDependentYN = 1, @ReadAccessYN = 1, @DebugBM=7

EXEC [spGet_AssignmentRow] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@CalledYN bit = 1,
	@LockedDimensionCalledYN bit = 1,
	@UsersCalledYN bit = 1,
	@ReadSecurityByOpYN bit = 0,

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
	@Version nvarchar(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Collect all Assignment rows from different sources.',
			@MandatoryParameter = ''

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Added InstanceID and VersionID filtering on all JOINS.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-105: Not include dimensions where ReportOnlyYN = 1, DB-107: Add ReadAccess as an option. Handle settings for Groups of users'
		IF @Version = '2.0.2.2147' SET @Description = 'DB-123: Removed filter of Workflow.SelectYN, DB-124 Incorrect dropping of temp table #LockedDimension fixed.'
		IF @Version = '2.0.2.2148' SET @Description = 'Enhanced debuging.'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-379: Fill #Assignment table correctly for each case of @UserDependentYN parameter.'
		IF @Version = '2.1.0.2161' SET @Description = 'Added optional parameter @OrganizationPositionID.'
		IF @Version = '2.1.0.2162' SET @Description = 'Added default levels from Dimension and Dimension_StorageType.'
		IF @Version = '2.1.0.2164' SET @Description = 'DB-601: Added [ProcessID] column into #Assignment table. Modified NOT EXISTS filter for Dimension-related INSERT to #AssignmentRow queries.'
		IF @Version = '2.1.0.2164' SET @Description = 'Modified INSERT query to #Assignment, reference @OrganizationPositionID from [Assignment_OrganizationLevel].'
		IF @Version = '2.1.1.2169' SET @Description = 'Modified INSERT query to #AssignmentRow in @Step = 7. Insert ReadAccess: added [OrganizationPositionID] in the NOT EXISTS filter.'
		IF @Version = '2.1.2.2182' SET @Description = 'Test on Workflow.SelectYN. Added variable @ReadSecurityByOpYN.'
		IF @Version = '2.1.2.2196' SET @Description = 'Added hierarchy columns to temp table #AssignmentRow. Handle security based on not default hierarchy.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		SELECT
			@ReadSecurityByOpYN = ISNULL(A.[ReadSecurityByOpYN], @ReadSecurityByOpYN)
		FROM
			pcINTEGRATOR_Data..[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID

		IF @DebugBM & 2 > 0
			SELECT
				[@ReadSecurityByOpYN] = @ReadSecurityByOpYN

	SET @Step = 'Return list of Sources'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 2,
					*
				FROM
					[pcINTEGRATOR].[dbo].[AssignmentSource]
				ORDER BY
					[AssignmentSourceID]

				SET @Selected = @Selected + @@ROWCOUNT

				GOTO ResultTypeBM2
			END

	SET @Step = 'Create temp tables'
		CREATE TABLE #Assignment
			(
			WorkflowID int,
			ScenarioID int,
			AssignmentID int,
			OrganizationPositionID int,
			ProcessID int
			)

	SET @Step = 'If not existing, create and fill temp table #Users.'
		IF OBJECT_ID (N'tempdb..#Users', N'U') IS NULL
			BEGIN
				SET @UsersCalledYN = 0

				CREATE TABLE #Users
					(
					[UserID] int
					)

				INSERT INTO #Users
					(
					[UserID]
					)
				SELECT DISTINCT
					[UserID] = sub.[UserID]
				FROM
					(
					SELECT [UserID] FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE [InstanceID] = @InstanceID AND [UserID] = @UserID
					UNION 
					SELECT [UserID] FROM [pcINTEGRATOR_Data].[dbo].[User_Instance] WHERE [InstanceID] = @InstanceID AND [UserID] = @UserID
					) sub

				IF @UserDependentYN <> 0
					INSERT INTO #Users
						(
						[UserID]
						)
					SELECT DISTINCT
						[UserID] = [UserID_Group]
					FROM
						pcINTEGRATOR_Data.dbo.UserMember
					WHERE
						[InstanceID] = @InstanceID AND
						[UserID_User] = @UserID AND
						[SelectYN] <> 0
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Users', * FROM #Users

	SET @Step = 'Fill temp table #Assignment'
		IF @UserDependentYN <> 0
			INSERT INTO #Assignment
				(
				WorkflowID,
				ScenarioID,
				AssignmentID,
				OrganizationPositionID,
				ProcessID
				)
			SELECT DISTINCT
				WF.WorkflowID,
				WF.ScenarioID,
				A.AssignmentID,
				A.OrganizationPositionID,
				WF.ProcessID
			FROM
				Assignment A
				INNER JOIN Workflow WF ON WF.InstanceID = A.InstanceID AND WF.VersionID = A.VersionID AND WF.WorkflowID = A.WorkflowID AND WF.DeletedID IS NULL AND (WF.WorkflowID = @WorkflowID OR @WorkflowID IS NULL) AND WF.SelectYN <> 0
				INNER JOIN Assignment_OrganizationLevel AOL ON AOL.InstanceID = A.InstanceID AND AOL.VersionID = A.VersionID AND AOL.AssignmentID = A.AssignmentID
				INNER JOIN OrganizationPosition OP ON OP.InstanceID = A.InstanceID AND OP.VersionID = A.VersionID AND OP.OrganizationPositionID = AOL.OrganizationPositionID AND OP.DeletedID IS NULL
				INNER JOIN OrganizationPosition_User OPU ON OPU.InstanceID = A.InstanceID AND OPU.VersionID = A.VersionID AND OPU.OrganizationPositionID = AOL.OrganizationPositionID AND OPU.DeletedID IS NULL
				INNER JOIN #Users U ON U.UserID = OPU.UserID
			WHERE
				A.InstanceID = @InstanceID AND
				A.VersionID = @VersionID AND
				A.DeletedID IS NULL AND
				(A.AssignmentID = @AssignmentID OR @AssignmentID IS NULL) AND
				(AOL.OrganizationPositionID = @OrganizationPositionID OR @OrganizationPositionID IS NULL)

		ELSE --IF @UserDependentYN = 0
			INSERT INTO #Assignment
				(
				WorkflowID,
				ScenarioID,
				AssignmentID,
				OrganizationPositionID,
				ProcessID
				)
			SELECT DISTINCT
				WF.WorkflowID,
				WF.ScenarioID,
				A.AssignmentID,
				A.OrganizationPositionID,
				WF.ProcessID
			FROM
				Assignment A
				INNER JOIN Workflow WF ON WF.InstanceID = A.InstanceID AND WF.VersionID = A.VersionID AND WF.WorkflowID = A.WorkflowID AND WF.DeletedID IS NULL AND (WF.WorkflowID = @WorkflowID OR @WorkflowID IS NULL)
				INNER JOIN Assignment_OrganizationLevel AOL ON AOL.InstanceID = A.InstanceID AND AOL.VersionID = A.VersionID AND AOL.AssignmentID = A.AssignmentID
				INNER JOIN OrganizationPosition OP ON OP.InstanceID = A.InstanceID AND OP.VersionID = A.VersionID AND OP.OrganizationPositionID = AOL.OrganizationPositionID AND OP.DeletedID IS NULL
			WHERE
				A.InstanceID = @InstanceID AND
				A.VersionID = @VersionID AND
				A.DeletedID IS NULL AND
				(A.AssignmentID = @AssignmentID OR @AssignmentID IS NULL) AND
				(A.OrganizationPositionID = @OrganizationPositionID OR @OrganizationPositionID IS NULL)		

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Assignment', * FROM #Assignment

	SET @Step = 'Create and fill temp table #DC'
		CREATE TABLE #DC (DataClassID int)

		INSERT INTO #DC
			(
			DataClassID
			)
		SELECT DISTINCT
			A1.DataClassID 
		FROM
			#Assignment A
			INNER JOIN pcINTEGRATOR_Data..Assignment A1 ON A1.AssignmentID = A.AssignmentID AND (A1.DataClassID = @DataClassID OR @DataClassID IS NULL)

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
			DCP.DataClassID 
		FROM
			pcINTEGRATOR_Data..DataClass_Process DCP
			INNER JOIN #Assignment A ON A.ProcessID = DCP.ProcessID
		WHERE
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

		IF (SELECT COUNT(1) FROM #Assignment) = 0 AND (SELECT COUNT(1) FROM #DC) = 0
			INSERT INTO #Dim
				(
				DimensionID
				)
			SELECT DISTINCT
				DimensionID
			FROM
				pcINTEGRATOR_Data..Dimension_StorageType DST
			WHERE
				DST.InstanceID = @InstanceID AND
				DST.VersionID = @VersionID AND
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

	SET @Step = 'Create or truncate table #AssignmentRow'
		IF OBJECT_ID(N'TempDB.dbo.#AssignmentRow', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #AssignmentRow
					(
					[Source] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[WorkflowID] int,
					[AssignmentID] int,
					[OrganizationPositionID] int,
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[HierarchyNo] int,
					[HierarchyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Dimension_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[CogentYN] bit
					)
			END
		ELSE
			TRUNCATE TABLE #AssignmentRow

	SET @Step = 'Create temp table #LockedDimension'
		IF OBJECT_ID(N'TempDB.dbo.#LockedDimension', N'U') IS NULL
			BEGIN
				SET @LockedDimensionCalledYN = 0

				CREATE TABLE #LockedDimension
					(
					DimensionID int
					)
			END
		ELSE
			TRUNCATE TABLE #LockedDimension

		IF @ReadAccessYN <> 0
			INSERT INTO #LockedDimension
				(
				DimensionID
				)
			SELECT DISTINCT
				DimensionID
			FROM
				Dimension_StorageType DST
			WHERE
				DST.InstanceID = @InstanceID AND
				DST.VersionID = @VersionID AND
				DST.ReadSecurityEnabledYN <> 0
		ELSE
			INSERT INTO #LockedDimension
				(
				DimensionID
				)
			SELECT
				DimensionID = 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#LockedDimension', * FROM #LockedDimension ORDER BY DimensionID

	SET @Step = '1. Insert Workflow Scenario setting'
		INSERT INTO #AssignmentRow
			(
			[Source],
			[WorkflowID],
			[AssignmentID],
			[OrganizationPositionID],
			[DimensionID],
			[DimensionName],
			[HierarchyNo],
			[HierarchyName],
			[Dimension_MemberKey],
			[CogentYN]
			)
		SELECT DISTINCT
			[Source] = [AS].[Description],
			A.[WorkflowID],
			A.[AssignmentID],
			A.[OrganizationPositionID],
			D.[DimensionID],
			D.[DimensionName],
			[HierarchyNo] = 0,
			[HierarchyName] = D.[DimensionName],
			S.[MemberKey],
			[CogentYN] = 0
		FROM
			#Assignment A
			INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = -6
			INNER JOIN #Dim Dim ON Dim.DimensionID = D.DimensionID
			INNER JOIN Scenario S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.ScenarioID = A.ScenarioID AND S.DeletedID IS NULL
			INNER JOIN #LockedDimension LD ON LD.DimensionID = D.DimensionID OR @ReadAccessYN = 0
			INNER JOIN AssignmentSource [AS] ON [AS].AssignmentSourceID = 1
		WHERE
			NOT EXISTS (SELECT 1 FROM #AssignmentRow TAR WHERE TAR.[AssignmentID] = A.[AssignmentID] AND TAR.[DimensionID] = D.[DimensionID])

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = '2. Insert WorkflowRow Cogent'
		INSERT INTO #AssignmentRow
			(
			[Source],
			[WorkflowID],
			[AssignmentID],
			[OrganizationPositionID],
			[DimensionID],
			[DimensionName],
			[HierarchyNo],
			[HierarchyName],
			[Dimension_MemberKey],
			[CogentYN]
			)
		SELECT DISTINCT
			[Source] = [AS].[Description],
			A.[WorkflowID],
			A.[AssignmentID],
			A.[OrganizationPositionID],
			WFR.[DimensionID],
			D.[DimensionName],
			[HierarchyNo] = 0,
			[HierarchyName] = D.[DimensionName],
			WFR.[Dimension_MemberKey],
			[CogentYN] = WFR.[CogentYN]
		FROM
			#Assignment A
			INNER JOIN Workflow WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.WorkflowID = A.WorkflowID AND WF.DeletedID IS NULL
			INNER JOIN WorkflowRow WFR ON WFR.InstanceID = @InstanceID AND WFR.VersionID = @VersionID AND WFR.WorkflowID = A.WorkflowID AND WFR.CogentYN <> 0
			INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = WFR.DimensionID AND D.ReportOnlyYN = 0
			INNER JOIN #Dim Dim ON Dim.DimensionID = D.DimensionID
			INNER JOIN #LockedDimension LD ON LD.DimensionID = D.DimensionID OR @ReadAccessYN = 0
			INNER JOIN AssignmentSource [AS] ON [AS].AssignmentSourceID = 2
		WHERE
			NOT EXISTS (SELECT 1 FROM #AssignmentRow TAR WHERE TAR.[AssignmentID] = A.[AssignmentID] AND TAR.[DimensionID] = WFR.[DimensionID])

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = '3. Insert Assignment'
		INSERT INTO #AssignmentRow
			(
			[Source],
			[WorkflowID],
			[AssignmentID],
			[OrganizationPositionID],
			[DimensionID],
			[DimensionName],
			[HierarchyNo],
			[HierarchyName],
			[Dimension_MemberKey],
			[CogentYN]
			)
		SELECT DISTINCT
			[Source] = [AS].[Description],
			A.[WorkflowID],
			A.[AssignmentID],
			A.[OrganizationPositionID],
			AR.[DimensionID],
			D.[DimensionName],
			[HierarchyNo] = 0,
			[HierarchyName] = D.[DimensionName],
			AR.[Dimension_MemberKey],
			[CogentYN] = 0
		FROM
			#Assignment A
			INNER JOIN [AssignmentRow] AR ON AR.InstanceID = @InstanceID AND AR.VersionID = @VersionID AND AR.AssignmentID = A.AssignmentID
			INNER JOIN [Dimension] D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = AR.DimensionID AND D.ReportOnlyYN = 0
			INNER JOIN #Dim Dim ON Dim.DimensionID = D.DimensionID
			INNER JOIN #LockedDimension LD ON LD.DimensionID = D.DimensionID OR @ReadAccessYN = 0
			INNER JOIN AssignmentSource [AS] ON [AS].AssignmentSourceID = 3
		WHERE
			NOT EXISTS (SELECT 1 FROM #AssignmentRow TAR WHERE TAR.[AssignmentID] = A.[AssignmentID] AND TAR.[DimensionID] = AR.[DimensionID])

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = '4. Insert OrganizationPositionRow'
		INSERT INTO #AssignmentRow
			(
			[Source],
			[WorkflowID],
			[AssignmentID],
			[OrganizationPositionID],
			[DimensionID],
			[DimensionName],
			[HierarchyNo],
			[HierarchyName],
			[Dimension_MemberKey],
			[CogentYN]
			)
		SELECT DISTINCT
			[Source] = [AS].[Description],
			A.[WorkflowID],
			A.[AssignmentID],
			A.[OrganizationPositionID],
			OPR.[DimensionID],
			D.[DimensionName],
			[HierarchyNo] = 0,
			[HierarchyName] = D.[DimensionName],
			OPR.[Dimension_MemberKey],
			[CogentYN] = 0
		FROM
			#Assignment A
			INNER JOIN OrganizationPosition OP ON OP.InstanceID = @InstanceID AND OP.VersionID = @VersionID AND OP.OrganizationPositionID = A.OrganizationPositionID AND OP.DeletedID IS NULL
			INNER JOIN OrganizationPositionRow OPR ON OPR.InstanceID = @InstanceID AND OPR.VersionID = @VersionID AND OPR.OrganizationPositionID = A.OrganizationPositionID
			INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = OPR.DimensionID AND D.ReportOnlyYN = 0
			INNER JOIN #Dim Dim ON Dim.DimensionID = D.DimensionID
			INNER JOIN #LockedDimension LD ON LD.DimensionID = D.DimensionID OR @ReadAccessYN = 0
			INNER JOIN AssignmentSource [AS] ON [AS].AssignmentSourceID = 4
		WHERE
			NOT EXISTS (SELECT 1 FROM #AssignmentRow TAR WHERE TAR.[AssignmentID] = A.[AssignmentID] AND TAR.[DimensionID] = OPR.[DimensionID])

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = '5. Insert OrganizationPosition'
		INSERT INTO #AssignmentRow
			(
			[Source],
			[WorkflowID],
			[AssignmentID],
			[OrganizationPositionID],
			[DimensionID],
			[DimensionName],
			[HierarchyNo],
			[HierarchyName],
			[Dimension_MemberKey],
			[CogentYN]
			)
		SELECT DISTINCT
			[Source] = [AS].[Description],
			A.[WorkflowID],
			A.[AssignmentID],
			A.[OrganizationPositionID],
			[DimensionID] = OH.[LinkedDimensionID],
			D.[DimensionName],
			[HierarchyNo] = 0,
			[HierarchyName] = D.[DimensionName],
			OP.[LinkedDimension_MemberKey],
			[CogentYN] = 0
		FROM
			#Assignment A
			INNER JOIN OrganizationPosition OP ON OP.InstanceID = @InstanceID AND OP.VersionID = @VersionID AND OP.OrganizationPositionID = A.OrganizationPositionID AND OP.DeletedID IS NULL
			INNER JOIN OrganizationHierarchy OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID AND OH.OrganizationHierarchyID = OP.OrganizationHierarchyID AND OH.DeletedID IS NULL
			INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = OH.LinkedDimensionID AND D.ReportOnlyYN = 0
			INNER JOIN #Dim Dim ON Dim.DimensionID = D.DimensionID
			INNER JOIN #LockedDimension LD ON LD.DimensionID = D.DimensionID OR @ReadAccessYN = 0
			INNER JOIN AssignmentSource [AS] ON [AS].AssignmentSourceID = 5
		WHERE
			NOT EXISTS (SELECT 1 FROM #AssignmentRow TAR WHERE TAR.[AssignmentID] = A.[AssignmentID] AND TAR.[DimensionID] = OH.[LinkedDimensionID])

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = '6. Insert Workflow not Cogent'
		INSERT INTO #AssignmentRow
			(
			[Source],
			[WorkflowID],
			[AssignmentID],
			[OrganizationPositionID],
			[DimensionID],
			[DimensionName],
			[HierarchyNo],
			[HierarchyName],
			[Dimension_MemberKey],
			[CogentYN]
			)
		SELECT DISTINCT
			[Source] = [AS].[Description],
			A.[WorkflowID],
			A.[AssignmentID],
			A.[OrganizationPositionID],
			WFR.[DimensionID],
			D.[DimensionName],
			[HierarchyNo] = 0,
			[HierarchyName] = D.[DimensionName],
			WFR.[Dimension_MemberKey],
			[CogentYN] = WFR.[CogentYN]
		FROM
			#Assignment A
			INNER JOIN Workflow WF ON WF.InstanceID = @InstanceID AND WF.VersionID = @VersionID AND WF.WorkflowID = A.WorkflowID AND WF.DeletedID IS NULL
			INNER JOIN WorkflowRow WFR ON WFR.InstanceID = @InstanceID AND WFR.VersionID = @VersionID AND WFR.WorkflowID = A.WorkflowID AND WFR.CogentYN = 0
			INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = WFR.DimensionID AND D.ReportOnlyYN = 0
			INNER JOIN #Dim Dim ON Dim.DimensionID = D.DimensionID
			INNER JOIN #LockedDimension LD ON LD.DimensionID = D.DimensionID OR @ReadAccessYN = 0
			INNER JOIN AssignmentSource [AS] ON [AS].AssignmentSourceID = 6
		WHERE
			NOT EXISTS (SELECT 1 FROM #AssignmentRow TAR WHERE TAR.[AssignmentID] = A.[AssignmentID] AND TAR.[DimensionID] = WFR.[DimensionID])

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = '7. Insert ReadAccess'
		IF @ReadAccessYN <> 0
			BEGIN
				INSERT INTO #AssignmentRow
					(
					[Source],
					[WorkflowID],
					[AssignmentID],
					[OrganizationPositionID],
					[DimensionID],
					[DimensionName],
					[HierarchyNo],
					[HierarchyName],
					[Dimension_MemberKey],
					[CogentYN]
					)
				SELECT DISTINCT
					[Source] = [AS].[Description],
					[WorkflowID] = 0,
					[AssignmentID] = 0,
					[OrganizationPositionID] = OP.[OrganizationPositionID],
					[DimensionID] = OPDM.[DimensionID],
					[DimensionName] = D.[DimensionName],
					[HierarchyNo] = OPDM.[HierarchyNo],
					[HierarchyName] = ISNULL(DH.[HierarchyName], D.[DimensionName]),
					[Dimension_MemberKey] = OPDM.MemberKey,
					[CogentYN] = 0
				FROM
					OrganizationPosition OP
					INNER JOIN OrganizationPosition_User OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.DeletedID IS NULL
					INNER JOIN #Users U ON U.UserID = OPU.UserID OR @UserDependentYN = 0
					INNER JOIN OrganizationPosition_DimensionMember OPDM ON OPDM.OrganizationPositionID = OP.OrganizationPositionID AND OPDM.ReadAccessYN <> 0 AND OPDM.DeletedID IS NULL
					INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = OPDM.DimensionID AND D.ReportOnlyYN = 0
					INNER JOIN #Dim Dim ON Dim.DimensionID = D.DimensionID
					INNER JOIN #LockedDimension LD ON LD.DimensionID = OPDM.DimensionID
					INNER JOIN AssignmentSource [AS] ON [AS].AssignmentSourceID = 7 
					LEFT JOIN pcINTEGRATOR_Data..DimensionHierarchy DH ON DH.InstanceID = OP.InstanceID AND DH.VersionID = OP.VersionID AND DH.[DimensionID] = OPDM.[DimensionID] AND DH.[HierarchyNo] = OPDM.[HierarchyNo]
				WHERE
					OP.InstanceID = @InstanceID AND
					OP.VersionID = @VersionID AND
					OP.DeletedID IS NULL AND
					(OP.OrganizationPositionID = @OrganizationPositionID OR @OrganizationPositionID IS NULL OR @ReadSecurityByOpYN = 0) AND
					NOT EXISTS (SELECT 1 FROM #AssignmentRow TAR WHERE TAR.[DimensionID] = OPDM.[DimensionID] AND TAR.[Dimension_MemberKey] = OPDM.MemberKey AND TAR.[OrganizationPositionID] = OP.[OrganizationPositionID])

				UNION SELECT DISTINCT
					[Source] = [AS].[Description],
					[WorkflowID] = 0,
					[AssignmentID] = 0,
					[OrganizationPositionID] = OP.[OrganizationPositionID],
					[DimensionID] = OH.[LinkedDimensionID],
					[DimensionName] = D.[DimensionName],
					[HierarchyNo] = 0,
					[HierarchyName] = D.[DimensionName],
					[Dimension_MemberKey] = OP.LinkedDimension_MemberKey,
					[CogentYN] = 0
				FROM
					OrganizationPosition OP
					INNER JOIN OrganizationPosition_User OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.UserID = @UserID AND OPU.DeletedID IS NULL
					INNER JOIN OrganizationHierarchy OH ON OH.InstanceID = OP.InstanceID AND OH.VersionID = OP.VersionID AND OH.OrganizationHierarchyID = OP.OrganizationHierarchyID AND OH.DeletedID IS NULL
					INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = OH.[LinkedDimensionID] AND D.ReportOnlyYN = 0
					INNER JOIN #Dim Dim ON Dim.DimensionID = D.DimensionID
					INNER JOIN #LockedDimension LD ON LD.DimensionID = OH.LinkedDimensionID
					INNER JOIN AssignmentSource [AS] ON [AS].AssignmentSourceID = 7 
				WHERE
					OP.InstanceID = @InstanceID AND
					OP.VersionID = @VersionID AND
					OP.DeletedID IS NULL AND
					ISNULL(OP.LinkedDimension_MemberKey, '') <> '' AND
					(OP.OrganizationPositionID = @OrganizationPositionID OR @OrganizationPositionID IS NULL OR @ReadSecurityByOpYN = 0) AND
					NOT EXISTS (SELECT 1 FROM #AssignmentRow TAR WHERE TAR.DimensionID = OH.LinkedDimensionID AND TAR.[Dimension_MemberKey] = OP.LinkedDimension_MemberKey)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '8. Insert Dimension Instance level'
		IF @ReadAccessYN = 0
			BEGIN
				INSERT INTO #AssignmentRow
					(
					[Source],
					[WorkflowID],
					[AssignmentID],
					[OrganizationPositionID],
					[DimensionID],
					[DimensionName],
					[HierarchyNo],
					[HierarchyName],
					[Dimension_MemberKey],
					[CogentYN]
					)
				SELECT DISTINCT
					[Source] = [AS].[Description],
					[WorkflowID] = NULL,
					[AssignmentID] = NULL,
					[OrganizationPositionID] = NULL,
					DST.[DimensionID],
					D.[DimensionName],
					[HierarchyNo] = 0,
					[HierarchyName] = D.[DimensionName],
					DST.[DefaultSetMemberKey],
					[CogentYN] = 0
				FROM
					pcINTEGRATOR_Data..Dimension_StorageType DST
					INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = DST.DimensionID AND D.ReportOnlyYN = 0
					INNER JOIN #Dim Dim ON Dim.DimensionID = D.DimensionID
					INNER JOIN #LockedDimension LD ON LD.DimensionID = D.DimensionID OR @ReadAccessYN = 0
					INNER JOIN AssignmentSource [AS] ON [AS].AssignmentSourceID = 8 
				WHERE
					DST.InstanceID = @InstanceID AND
					DST.VersionID = @VersionID AND
					DST.[DefaultSetMemberKey] IS NOT NULL AND
					NOT EXISTS (SELECT 1 FROM #AssignmentRow TAR WHERE (TAR.[AssignmentID] IS NULL OR TAR.[AssignmentID] = @AssignmentID) AND TAR.[DimensionID] = DST.[DimensionID])

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '9. Insert Dimension System level'
		IF @ReadAccessYN = 0
			BEGIN
				INSERT INTO #AssignmentRow
					(
					[Source],
					[WorkflowID],
					[AssignmentID],
					[OrganizationPositionID],
					[DimensionID],
					[DimensionName],
					[HierarchyNo],
					[HierarchyName],
					[Dimension_MemberKey],
					[CogentYN]
					)
				SELECT DISTINCT
					[Source] = [AS].[Description],
					[WorkflowID] = NULL,
					[AssignmentID] = NULL,
					[OrganizationPositionID] = NULL,
					DST.[DimensionID],
					D.[DimensionName],
					[HierarchyNo] = 0,
					[HierarchyName] = D.[DimensionName],
					D.[DefaultSetMemberKey],
					[CogentYN] = 0
				FROM
					pcINTEGRATOR_Data..Dimension_StorageType DST
					INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = DST.DimensionID AND D.ReportOnlyYN = 0
					INNER JOIN #Dim Dim ON Dim.DimensionID = D.DimensionID
					INNER JOIN #LockedDimension LD ON LD.DimensionID = D.DimensionID OR @ReadAccessYN = 0
					INNER JOIN AssignmentSource [AS] ON [AS].AssignmentSourceID = 9
				WHERE
					DST.InstanceID = @InstanceID AND
					DST.VersionID = @VersionID AND
					D.[DefaultSetMemberKey] IS NOT NULL AND
					NOT EXISTS (SELECT 1 FROM #AssignmentRow TAR WHERE (TAR.[AssignmentID] IS NULL OR TAR.[AssignmentID] = @AssignmentID) AND TAR.[DimensionID] = DST.[DimensionID])

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Return rows and drop table #AssignmentRow if SP not called'
		IF @CalledYN = 0
			BEGIN
				SELECT
					[ResultTypeBM] = 1,
					*
				FROM
					#AssignmentRow
				ORDER BY
					[WorkflowID],
					[AssignmentID],
					[DimensionID]

				DROP TABLE #AssignmentRow
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #Assignment
		DROP TABLE #DC
		DROP TABLE #Dim
		IF @LockedDimensionCalledYN = 0 DROP TABLE #LockedDimension
		IF @UsersCalledYN = 0 DROP TABLE #Users

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
