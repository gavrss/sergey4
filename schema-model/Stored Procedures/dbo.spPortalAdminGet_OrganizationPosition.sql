SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_OrganizationPosition]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@OrganizationPositionID int = NULL,
	@ResultTypeBM int = 127,
		-- 1 = OrganizationPosition definition
		-- 2 = Delegated persons
		-- 4 = OrganizationPosition rows
		-- 8 = OrganizationPosition Dimension ReadAccess
		--16 = OrganizationPosition DataClass ReadAccess
		--32 = Default dimension members and hierarchies
		--64 = [OrganizationPositionTypeID]
	@GetResultSetYN INT = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000103,
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

EXEC [pcINTEGRATOR].[dbo].[spPortalAdminGet_OrganizationPosition] @InstanceID='572',@OrganizationPositionID='5568',@ResultTypeBM='8',@UserID='9863',@VersionID='1080',@DebugBM=0
EXEC [pcINTEGRATOR].[dbo].[spPortalAdminGet_OrganizationPosition] @InstanceID='572',@OrganizationPositionID='5587',@ResultTypeBM='127',@UserID='9863',@VersionID='1080',@DebugBM=0

EXEC [pcINTEGRATOR].[dbo].[spPortalAdminGet_OrganizationPosition] @InstanceID='572',@OrganizationPositionID='5583'
,@ResultTypeBM='8',@UserID='9863',@VersionID='1080',@DebugBM=15

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminGet_OrganizationPosition',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_OrganizationPosition] @InstanceID='454', @OrganizationPositionID='2689', @UserID='7564', @VersionID='1021', @ResultTypeBM='16'
EXEC [spPortalAdminGet_OrganizationPosition] @InstanceID='454', @OrganizationPositionID='2689', @UserID='8770', @VersionID='1021', @ResultTypeBM='8'
EXEC [spPortalAdminGet_OrganizationPosition] @InstanceID='454', @OrganizationPositionID='6318', @UserID='8739', @VersionID='1021', @ResultTypeBM='16'

EXEC [spPortalAdminGet_OrganizationPosition] @InstanceID='454', @OrganizationPositionID='2689', @UserID='7564', @VersionID='1021', @ResultTypeBM='31'
EXEC [spPortalAdminGet_OrganizationPosition] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1
EXEC [spPortalAdminGet_OrganizationPosition] @UserID=2147, @InstanceID=413, @VersionID=1008, @OrganizationPositionID = 1136, @ResultTypeBM= 8, @Debug=1

EXEC [spPortalAdminGet_OrganizationPosition] @UserID=2147, @InstanceID=413, @VersionID=1008, @OrganizationPositionID = 1136, @ResultTypeBM=63, @Debug=1
EXEC [spPortalAdminGet_OrganizationPosition] @InstanceID='424', @OrganizationPositionID='-1810', @UserID='7564', @VersionID='1017', @ResultTypeBM='31'
EXEC [spPortalAdminGet_OrganizationPosition] @InstanceID='515', @OrganizationPositionID='-1810', @UserID='7564', @VersionID='1040', @ResultTypeBM='64'

EXEC [spPortalAdminGet_OrganizationPosition] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@AssignedUserID INT,
	@CalledYN INT = 1, 

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure NVARCHAR(128),
	@ErrorLine INT,
	@ErrorMessage NVARCHAR(4000), 
	@ProcedureDescription NVARCHAR(1024),
	@MandatoryParameter NVARCHAR(1000),
	@Description NVARCHAR(255),
	@ToBeChanged NVARCHAR(255) = '',
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'JaWo',
	@Version NVARCHAR(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'List all properties for a specific OrganizationPosition',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Enhanced structure.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-107: ResultTypeBM = 8, based on spGet_AssignmentRow.'
		IF @Version = '2.1.0.2161' SET @Description = 'Added VersionID to [OrganizationPosition_DataClass]. Added @ResultTypeBM = 32'
		IF @Version = '2.1.0.2163' SET @Description = 'Fixed bug on @ResultTypeBM = 32, added ResultTypeBM to temp table. DB-592: Added [WriteAccessYN] column to @ResultTypeBM = 16.'
		IF @Version = '2.1.0.2165' SET @Description = 'DB-607: Fixed bug with duplicating row. Missing join in ResultTypeBM = 8.'
		IF @Version = '2.1.1.2171' SET @Description = 'Added OrganizationPositionType and dates for connected users.'
		IF @Version = '2.1.2.2182' SET @Description = 'Handle generic OrganizationPositionTypes.'
		IF @Version = '2.1.2.2190' SET @Description = 'DB-1324: Added filters on [User].[SelectYN] and [User].[DeletedID] for @ResultTypeBM 1 and 2.'
		IF @Version = '2.1.2.2191' SET @Description = 'Created temp table #OPDimReadAccess for ResultTypeBM = 8.'
		IF @Version = '2.1.2.2196' SET @Description = 'Added hierarchy columns to temp table #AssignmentRow.'

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

		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = 'OrganizationPosition definition'
		IF @ResultTypeBM & 1 > 0 --OrganizationPosition definition
			BEGIN
				SELECT 
					ResultTypeBM = 1,
					ReadOnlyYN = 0,
					ModelingLockedYN = V.ModelingLockedYN,
					OrganizationHierarchyID = OP.OrganizationHierarchyID, 
					OrganizationHierarchyName = OH.OrganizationHierarchyName,
					OrganizationPositionID = OP.OrganizationPositionID,
					OrganizationPositionName = OP.OrganizationPositionName,
					OrganizationPositionDescription = OP.OrganizationPositionDescription,
					[OrganizationPositionTypeID] = OP.[OrganizationPositionTypeID],
					ParentOrganizationPositionID,
					OP.OrganizationLevelNo,
					OL.OrganizationLevelName,
					OH.LinkedDimensionID,
					LinkedDimensionName = D.DimensionName,
					OP.LinkedDimension_MemberKey,
					UserID = OPU.UserID,
					UserNameDisplay = U.UserNameDisplay,
					UserOrgComment = OPU.Comment
				FROM
					OrganizationPosition OP
					INNER JOIN [Version] V ON V.VersionID = OP.VersionID
					INNER JOIN OrganizationHierarchy OH ON OH.OrganizationHierarchyID = OP.OrganizationHierarchyID
					LEFT JOIN OrganizationPosition_User OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID AND OPU.DelegateYN = 0
					LEFT JOIN [User] U ON U.UserID = OPU.UserID AND U.SelectYN <> 0 AND U.DeletedID IS NULL 
					LEFT JOIN OrganizationLevel OL ON OL.OrganizationHierarchyID = OP.OrganizationHierarchyID AND OL.OrganizationLevelNo = OP.OrganizationLevelNo
					LEFT JOIN Dimension D ON D.DimensionID = OH.LinkedDimensionID
				WHERE
					OP.[InstanceID] = @InstanceID AND
					OP.[VersionID] = @VersionID AND
					OP.OrganizationPositionID = @OrganizationPositionID AND
					OP.[DeletedID] IS NULL

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Delegated persons'
		IF @ResultTypeBM & 2 > 0 --Delegated persons
			BEGIN
				SELECT
					ResultTypeBM = 2, 
					DelegateYN = OPU.DelegateYN,
					ReadOnlyYN = 0,
					ModelingLockedYN = V.ModelingLockedYN,
					ActiveYN = CASE WHEN ISNULL(DateFrom, GETDATE() -2) <= GETDATE() AND  ISNULL(DateTo, GETDATE() +2) >= GETDATE() THEN 1 ELSE 0 END,
					UserID = OPU.UserID,
					UserNameDisplay = U.UserNameDisplay,
					UserOrgComment = OPU.Comment,
					DateFrom = OPU.DateFrom,
					DateTo = OPU.DateTo
				FROM
					OrganizationPosition OP
					INNER JOIN [Version] V ON V.VersionID = OP.VersionID
					INNER JOIN [OrganizationPosition_User] OPU ON OPU.OrganizationPositionID = OP.OrganizationPositionID --AND OPU.DelegateYN <> 0
					INNER JOIN [User] U ON U.UserID = OPU.UserID AND U.SelectYN <> 0 AND U.DeletedID IS NULL 
				WHERE
					OP.[InstanceID] = @InstanceID AND
					OP.[VersionID] = @VersionID AND
					OP.OrganizationPositionID = @OrganizationPositionID AND
					OP.[DeletedID] IS NULL

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'OrganizationPosition rows'
		IF @ResultTypeBM & 4 > 0 --OrganizationPosition rows
			BEGIN
				SELECT 
					ResultTypeBM = 4,
					ReadOnlyYN = 0,
					OPR.[DimensionID],
					D.DimensionName,
					OPR.[Dimension_MemberKey]
				FROM
					OrganizationPositionRow OPR
					INNER JOIN Dimension D ON D.DimensionID = OPR.DimensionID
				WHERE
					OPR.OrganizationPositionID = @OrganizationPositionID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'OrganizationPosition Dimensions ReadAccess'
		IF @ResultTypeBM & 8 > 0 --OrganizationPosition Dimensions ReadAccess
			BEGIN
				SELECT @AssignedUserID = UserID FROM pcINTEGRATOR_Data.dbo.OrganizationPosition_User OPU WHERE OPU.OrganizationPositionID = @OrganizationPositionID AND OPU.DelegateYN = 0
				
				IF @DebugBM & 2 > 0 SELECT [@AssignedUserID] = @AssignedUserID, [@OrganizationPositionID] = @OrganizationPositionID

				CREATE TABLE #AssignmentRow
					(
					[Source] nvarchar(50),
					[WorkflowID] int,
					[AssignmentID] int,
					[OrganizationPositionID] int,
					[DimensionID] int,
					[DimensionName] nvarchar(100),
					[HierarchyNo] int,
					[HierarchyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[Dimension_MemberKey] nvarchar(100),
					[CogentYN] bit
					)

				EXEC spGet_AssignmentRow @UserID = @AssignedUserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @OrganizationPositionID=@OrganizationPositionID, @UserDependentYN = 1, @ReadAccessYN = 1

				IF @DebugBM & 2 > 0
					BEGIN
						SELECT TempTable = '#AssignmentRow', * FROM #AssignmentRow

						SELECT DISTINCT
							TempTable = 'sub',
							[DimensionID] = AR.[DimensionID],
							[DimensionName] = MAX(AR.[DimensionName]),
							[MemberKey] = AR.[Dimension_MemberKey],
							[AssignmentSourceID] = MIN([AS].[AssignmentSourceID])
						FROM
							#AssignmentRow AR
							INNER JOIN AssignmentSource [AS] ON [AS].[Description] = [AR].[Source]
						WHERE
							AR.[OrganizationPositionID] = @OrganizationPositionID --AND
							--NOT EXISTS (SELECT DISTINCT ARD.[DimensionID] FROM #AssignmentRow ARD WHERE ARD.[Dimension_MemberKey] = 'All_' AND ARD.[DimensionID] = AR.[DimensionID] AND AR.[Dimension_MemberKey] <> 'All_')
							--NOT EXISTS (SELECT DISTINCT ARD.[DimensionID] FROM #AssignmentRow ARD WHERE ARD.[DimensionID] = AR.[DimensionID])
						GROUP BY
							AR.[DimensionID],
							AR.[Dimension_MemberKey]
					END

				IF OBJECT_ID (N'tempdb..#OPDimReadAccess', N'U') IS NULL
					BEGIN
						CREATE TABLE #OPDimReadAccess
							(
							[OrganizationPositionID] int,
							[DimensionID] int,
							[DimensionName] nvarchar(50) COLLATE DATABASE_DEFAULT,
							[HierarchyNo] int,
							[HierarchyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
							[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
							[ReadAccessYN] bit,
							[WriteAccessYN] bit,
							[InheritedYN] bit,
							[Comment] nvarchar(100) COLLATE DATABASE_DEFAULT
							)

						SET @CalledYN = 0
					END

				TRUNCATE TABLE #OPDimReadAccess

				INSERT INTO #OPDimReadAccess
					(
					[OrganizationPositionID],
					[DimensionID],
					[DimensionName],
					[HierarchyNo],
					[HierarchyName],
					[MemberKey],
					[ReadAccessYN],
					[WriteAccessYN],
					[InheritedYN],
					[Comment]
					)
				SELECT DISTINCT
					[OrganizationPositionID] = @OrganizationPositionID,
					[DimensionID] = sub.[DimensionID],
					[DimensionName] = sub.[DimensionName],
					[HierarchyNo] = ISNULL(OPDM.[HierarchyNo], 0),
					[HierarchyName] = ISNULL(DH.[HierarchyName], CASE WHEN ISNULL(OPDM.[HierarchyNo], 0) = 0 THEN sub.[DimensionName] END),
					[MemberKey] = sub.[MemberKey],
					[ReadAccessYN] = ISNULL(OPDM.[ReadAccessYN], 1),
					[WriteAccessYN] = ISNULL(OPDM.[WriteAccessYN], 0),
					[InheritedYN] = CASE WHEN [AS].[AssignmentSourceID] = 7 THEN 0 ELSE 1 END,
					[Comment] = [AS].[Description]
				FROM
					[pcINTEGRATOR].[dbo].[AssignmentSource] [AS]
					INNER JOIN
						(
						SELECT DISTINCT
							[DimensionID] = AR.[DimensionID],
							[DimensionName] = MAX(AR.[DimensionName]),
							[MemberKey] = AR.[Dimension_MemberKey],
							[AssignmentSourceID] = MIN([AS].[AssignmentSourceID])
						FROM
							#AssignmentRow AR
							INNER JOIN AssignmentSource [AS] ON [AS].[Description] = [AR].[Source]
						WHERE
							AR.[OrganizationPositionID] = @OrganizationPositionID AND
							NOT EXISTS (SELECT DISTINCT ARD.[DimensionID] FROM #AssignmentRow ARD WHERE ARD.[Dimension_MemberKey] = 'All_' AND ARD.[DimensionID] = AR.[DimensionID] AND AR.[Dimension_MemberKey] <> 'All_')
						GROUP BY
							AR.[DimensionID],
							AR.[Dimension_MemberKey]
						) sub ON sub.[AssignmentSourceID] = [AS].[AssignmentSourceID]
					LEFT JOIN [pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DimensionMember] OPDM ON 
							OPDM.[InstanceID] = @InstanceID AND 
							OPDM.[VersionID] = @VersionID AND 
							OPDM.OrganizationPositionID = @OrganizationPositionID AND
							OPDM.[DimensionID] = sub.[DimensionID] AND
							OPDM.[MemberKey] = sub.[MemberKey] AND
							OPDM.[DeletedID] IS NULL
					LEFT JOIN 
						(
						SELECT
							[DimensionID],
							[HierarchyNo],
							[HierarchyName]
						FROM
							[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
						WHERE
							[InstanceID] IN (@InstanceID) AND
							[VersionID] IN (@VersionID)

						UNION SELECT
							[DimensionID],
							[HierarchyNo],
							[HierarchyName]
						FROM
							[pcINTEGRATOR].[dbo].[@Template_DimensionHierarchy] DH
						WHERE
							[InstanceID] IN (0) AND
							[VersionID] IN (0) AND
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DDH WHERE DDH.[InstanceID] IN (@InstanceID) AND DDH.[VersionID] IN (@VersionID) AND DDH.DimensionID = DH.DimensionID AND DDH.HierarchyNo = DH.HierarchyNo)
						) DH ON DH.[DimensionID] = sub.[DimensionID] AND DH.[HierarchyNo] = ISNULL(OPDM.[HierarchyNo], 0)
				ORDER BY
--					sub.[AssignmentSourceID],
					sub.[DimensionName]

				IF @GetResultSetYN <> 0
					SELECT 
						ResultTypeBM = 8,
						[DimensionID],
						[DimensionName],
						[HierarchyNo],
						[HierarchyName],
						[MemberKey],
						[ReadAccessYN],
						[WriteAccessYN],
						[InheritedYN],
						[Comment]
					FROM
						#OPDimReadAccess
					ORDER BY
						[DimensionName]

				DROP TABLE #AssignmentRow
				IF @CalledYN = 0 DROP TABLE #OPDimReadAccess
			END

	SET @Step = 'OrganizationPosition DataClass ReadAccess'
		IF @ResultTypeBM & 16 > 0 --OrganizationPosition DataClass ReadAccess
			BEGIN
				SELECT
					ResultTypeBM = 16,
					DataClassID = DC.DataClassID,
					DC.DataClassName,
					ReadAccessYN = DC.ReadAccessDefaultYN,
					WriteAccessYN = 0,
					InheritedYN = 1,
					Comment = 'Set in DataClass'
				FROM
					[OrganizationPosition] OP
					INNER JOIN DataClass DC ON DC.InstanceID = OP.InstanceID AND DC.VersionID = OP.VersionID
				WHERE
					OP.InstanceID = @InstanceID AND
					OP.VersionID = @VersionID AND
					OP.OrganizationPositionID = @OrganizationPositionID AND
					NOT EXISTS (SELECT 1 FROM [OrganizationPosition_DataClass] OPDC WHERE OPDC.InstanceID = OP.InstanceID AND OPDC.VersionID = OP.VersionID AND OPDC.DataClassID = DC.DataClassID AND OPDC.OrganizationPositionID = @OrganizationPositionID)

				UNION
				SELECT
					ResultTypeBM = 16,
					DataClassID = OPDC.DataClassID,
					DC.DataClassName,
					ReadAccessYN = OPDC.ReadAccessYN,
					WriteAccessYN = OPDC.WriteAccessYN,
					InheritedYN = 0,
					Comment = OPDC.Comment
				FROM
					[OrganizationPosition_DataClass] OPDC
					INNER JOIN DataClass DC ON DC.DataClassID = OPDC.DataClassID
				WHERE
					OPDC.InstanceID = @InstanceID AND
					OPDC.VersionID = @VersionID AND
					OPDC.OrganizationPositionID = @OrganizationPositionID

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Default dimension members'
		IF @ResultTypeBM & 32 > 0 --Default dimension members
			BEGIN
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

				EXEC spGet_DefaultMember @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @OrganizationPositionID = @OrganizationPositionID, @JobID = @JobID, @Debug = @DebugSub

				SELECT
					[ResultTypeBM] = 32,
					[DimensionID],
					[Dimension] = [DimensionName],
					[HierarchyNo],
					[Hierarchy] = [HierarchyName],
					[Member] = [Dimension_MemberKey],
					[Comment] = [Source],
					[InheritedYN] = CONVERT(bit, CASE WHEN StepID = 1 THEN 0 ELSE 1 END)
				FROM
					#DefaultMember
				ORDER BY
					[DimensionName],
					[HierarchyNo]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'OrganizationPositionType'
		IF @ResultTypeBM & 64 > 0 --OrganizationPositionType
			BEGIN
				SELECT
					[ResultTypeBM] = 64,
					[OrganizationPositionTypeID],
					[OrganizationPositionTypeName],
					[OrganizationPositionTypeDescription],
					[CommissionParameter]
				FROM
					[pcINTEGRATOR].[dbo].[OrganizationPositionType]
				WHERE
					[InstanceID] IN (0, @InstanceID) AND
					[VersionID] IN (0, @VersionID)
				ORDER BY
					[OrganizationPositionTypeName]
			END

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
