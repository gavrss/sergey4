SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_ReadAccess]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ActingAs int = NULL, --Optional (OrganizationPositionID)
	@ReadAccessFilter nvarchar(max) = NULL OUT,
	@UseCacheYN bit = 1,
	@StorageTypeBM_DataClass int = 3, --3 returns _MemberKey, 4 returns _MemberId
	@ReturnColNameYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000320,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spGet_ReadAccess',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spGet_ReadAccess] @UserID = 7564, @InstanceID = 454, @VersionID = 1021 --, @Debug = 1
EXEC [spGet_ReadAccess] @UserID = 8770, @InstanceID = 454, @VersionID = 1021 --, @Debug = 1
EXEC [spGet_ReadAccess] @UserID = 8739, @InstanceID = 454, @VersionID = 1021, @Debug = 1

EXEC [spGet_ReadAccess] @UserID=-1181, @InstanceID=-1009, @VersionID=-1009, @Debug=1
EXEC [spGet_ReadAccess] @UserID=3833, @InstanceID=413, @VersionID=1008, @Debug=1 --CBN, Donald Olsen
EXEC [spGet_ReadAccess] @UserID=3903, @InstanceID=413, @VersionID=1008, @Debug=1 --CBN
EXEC [spGet_ReadAccess] @UserID=-10, @InstanceID=404, @VersionID=1003, @Debug=1 --Salinity
EXEC [spGet_ReadAccess] @UserID=3903, @InstanceID=413, @VersionID=1008, @Debug=1 --CBN

EXEC [spGet_ReadAccess] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DimensionID int, 
	@DimensionName nvarchar(100),
	@HierarchyNo int, 
	@MemberList nvarchar(max),
	@CalledYN bit = 1,
	@Filter nvarchar(4000) = '',
	@LeafLevelFilter nvarchar(max),
	@CallistoDatabase nvarchar(100),
	@StorageTypeBM_Dimension int,
	@NoRestrictionYN bit = 0,

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Procedure to pick up Dimension-based Security filters for specified User.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure.'
		IF @Version = '2.0.2.2144' SET @Description = 'Check for Membership in FullAccess role. Added test for DeletedIDs in WHEREs and JOINs.'
		IF @Version = '2.0.2.2145' SET @Description = 'Check for generic FullAccess Role'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-107: Based on spGet_AssignmentRow.'
		IF @Version = '2.1.0.2161' SET @Description = 'Added optional parameter @ActingAs.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added parameter @UseCacheYN.'
		IF @Version = '2.1.0.2164' SET @Description = 'Test on not selected and dynamic deleted groups.'
		IF @Version = '2.1.1.2169' SET @Description = 'Added parameters @StorageTypeBM_DataClass and @ReturnColNameYN.'
		IF @Version = '2.1.1.2171' SET @Description = 'Set StorageTypeBM in return table to @StorageTypeBM_DataClass.'
		IF @Version = '2.1.2.2196' SET @Description = 'Added hierarchy columns to temp table #AssignmentRow. Handle security based on not default hierarchy.'

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

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			SelectYN <> 0

	SET @Step = 'Check if called'
		IF OBJECT_ID (N'tempdb..#ReadAccess', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0
				CREATE TABLE #ReadAccess
					(
					[DimensionID] int,
					[DimensionName] nvarchar(100),
					[StorageTypeBM] int,
					[Filter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
					[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[DataColumn] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[SelectYN] bit
					)
			END

	SET @Step = 'Check if any dimensions are locked'
		CREATE TABLE #LockedDimension
			(
			DimensionID int
			)

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
		
		IF (SELECT COUNT(1) FROM #LockedDimension) = 0 
			BEGIN
				SET @NoRestrictionYN = 1
				GOTO NoRestriction
			END

	SET @Step = 'Check if @UserID is member of FullAccess'
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
			SELECT [UserID] FROM [pcINTEGRATOR_Data].[dbo].[User] WHERE [InstanceID] = @InstanceID AND [UserID] = @UserID AND [SelectYN] <> 0 AND [DeletedID] IS NULL
			UNION 
			SELECT [UserID] FROM [pcINTEGRATOR_Data].[dbo].[User_Instance] WHERE [InstanceID] = @InstanceID AND [UserID] = @UserID AND [SelectYN] <> 0 AND [DeletedID] IS NULL
			) sub

		INSERT INTO #Users
			(
			[UserID]
			)
		SELECT DISTINCT
			[UserID] = UM.[UserID_Group]
		FROM
			[UserMember] UM
			INNER JOIN [User] U ON U.[UserID] = UM.[UserID_Group] AND U.[SelectYN] <> 0 AND U.[DeletedID] IS NULL
		WHERE
			UM.[InstanceID] = @InstanceID AND
			UM.[UserID_User] = @UserID AND
			UM.[SelectYN] <> 0

		IF @Debug <> 0 SELECT TempTable = '#Users', * FROM #Users

		IF (
			SELECT 
				COUNT(1)
			FROM
				#Users U
				INNER JOIN SecurityRoleUser SRU ON SRU.UserID = U.UserID AND SRU.SecurityRoleID = -2
			) > 0 
			BEGIN
				SET @NoRestrictionYN = 1
				GOTO NoRestriction
			END
		
	SET @Step = 'Create temp table #AssignmentRow'
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

	SET @Step = 'Fill temp table #AssignmentRow'
		EXEC spGet_AssignmentRow @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @OrganizationPositionID = @ActingAs, @UserDependentYN = 1, @ReadAccessYN = 1, @Debug = @DebugSub

		IF @DebugBM & 2 > 0 SELECT TempTable = '#AssignmentRow',  * FROM #AssignmentRow

	SET @Step = 'Fill temp table #ReadAccessRaw'
		CREATE TABLE #ReadAccessRaw
			(
			DimensionID int,
			HierarchyNo nvarchar(50),
			MemberKey nvarchar(100) COLLATE DATABASE_DEFAULT
			)
		
		INSERT INTO #ReadAccessRaw
			(
			DimensionID,
			HierarchyNo,
			MemberKey
			)
		SELECT DISTINCT
			[DimensionID] = AR.[DimensionID],
			[HierarchyNo] = AR.[HierarchyNo],
			[MemberKey] = AR.[Dimension_MemberKey]
		FROM
			#AssignmentRow AR

		INSERT INTO #ReadAccessRaw
			(
			DimensionID,
			[HierarchyNo],
			MemberKey
			)
		SELECT DISTINCT
			DimensionID = LD.DimensionID,
			[HierarchyNo] = 0,
			MemberKey = '#NotAllowed#'
		FROM
			#LockedDimension LD
		WHERE
			NOT EXISTS (SELECT 1 FROM #ReadAccessRaw RAR WHERE RAR.DimensionID = LD.DimensionID)

		DELETE RAR
		FROM
			#ReadAccessRaw RAR
			INNER JOIN (
				SELECT DISTINCT
					DimensionID
				FROM
					#ReadAccessRaw
				WHERE
					MemberKey = 'All_'
				) sub ON sub.DimensionID = RAR.DimensionID
		WHERE
			RAR.MemberKey <> 'All_'

		IF @Debug <> 0 SELECT TempTable = '#ReadAccessRaw', * FROM #ReadAccessRaw ORDER BY DimensionID, MemberKey

	SET @Step = 'Fill temp table #ReadAccess'
		SET @ReadAccessFilter = ''
		DECLARE ReadAccess_Cursor CURSOR FOR

			SELECT DISTINCT
				RAR.DimensionID,
				D.DimensionName,
				RAR.HierarchyNo,
				DST.StorageTypeBM
			FROM
				#ReadAccessRaw RAR
				INNER JOIN Dimension D ON D.DimensionID = RAR.DimensionID
				INNER JOIN Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = RAR.DimensionID
			ORDER BY
				RAR.DimensionID

			OPEN ReadAccess_Cursor
			FETCH NEXT FROM ReadAccess_Cursor INTO @DimensionID, @DimensionName, @HierarchyNo, @StorageTypeBM_Dimension

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [@DimensionID] = @DimensionID
					
					SET @Filter = ''

					SELECT
						@Filter = @Filter + MemberKey + ','
					FROM
						#ReadAccessRaw
					WHERE
						DimensionID = @DimensionID
					ORDER BY
						MemberKey

					SET @Filter = LEFT(@Filter, LEN(@Filter) -1)

					IF @Debug <> 0 SELECT [@UserID]=@UserID, [@InstanceID]=@InstanceID, [@VersionID]=@VersionID, [@DatabaseName]=@CallistoDatabase, [@DimensionName]=@DimensionName, [@HierarchyNo] = @HierarchyNo, [@Filter]=@Filter, [@StorageTypeBM]=@StorageTypeBM_Dimension, [@UseCacheYN]=@UseCacheYN, [@StorageTypeBM_DataClass]=@StorageTypeBM_DataClass, [@ReturnColNameYN]=@ReturnColNameYN, [@LeafLevelFilter] = @LeafLevelFilter
					EXEC spGet_LeafLevelFilter @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DatabaseName=@CallistoDatabase, @DimensionName=@DimensionName, @HierarchyNo = @HierarchyNo, @Filter=@Filter, @StorageTypeBM=@StorageTypeBM_Dimension, @UseCacheYN=@UseCacheYN, @StorageTypeBM_DataClass=@StorageTypeBM_DataClass, @ReturnColNameYN=@ReturnColNameYN, @LeafLevelFilter=@LeafLevelFilter OUT

					INSERT INTO #ReadAccess
						(
						[DimensionID],
						[DimensionName],
						[StorageTypeBM],
						[Filter],
						[LeafLevelFilter],
						[SelectYN]
						)
					SELECT
						[DimensionID] = @DimensionID,
						[DimensionName] = @DimensionName,
						[StorageTypeBM] = @StorageTypeBM_DataClass, --@StorageTypeBM_Dimension,
						[Filter] = @Filter,
						[LeafLevelFilter] = @LeafLevelFilter,
						[SelectYN] = 0

					IF LEN(@LeafLevelFilter) > 0 SET @ReadAccessFilter = @ReadAccessFilter + @DimensionName + ' IN (' + @LeafLevelFilter + ') AND '

					FETCH NEXT FROM ReadAccess_Cursor INTO @DimensionID, @DimensionName, @HierarchyNo, @StorageTypeBM_Dimension
				END

		CLOSE ReadAccess_Cursor
		DEALLOCATE ReadAccess_Cursor	

		IF @Debug <> 0 SELECT TempTable = '#ReadAccess', * FROM #ReadAccess ORDER BY DimensionID

		IF LEN(@ReadAccessFilter) >= 4
			SET @ReadAccessFilter = LEFT(@ReadAccessFilter, LEN(@ReadAccessFilter) - 4)
		ELSE
			SET @ReadAccessFilter = ''

		IF @Debug <> 0 SELECT [@ReadAccessFilter] = @ReadAccessFilter

	SET @Step = 'Drop temp tables'
		DROP TABLE #ReadAccessRaw
		DROP TABLE #AssignmentRow
		DROP TABLE #Users

	SET @Step = 'Jump to here if no restrictions'
		NoRestriction:
		IF @NoRestrictionYN <> 0
			BEGIN
				SET @ReadAccessFilter = ''

				INSERT INTO #ReadAccess
					(
					[DimensionID],
					[DimensionName],
					[StorageTypeBM],
					[Filter],
					[LeafLevelFilter],
					[SelectYN]
					)
				SELECT
					[DimensionID] = LD.DimensionID,
					[DimensionName] = D.DimensionName,
					[StorageTypeBM] = @StorageTypeBM_DataClass,
					[Filter] = 'All_',
					[LeafLevelFilter] = '',
					[SelectYN] = 0
				FROM
					#LockedDimension LD
					INNER JOIN Dimension D ON D.DimensionID = LD.DimensionID
					INNER JOIN Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = LD.DimensionID
			END

	SET @Step = 'Return rows and drop table #ReadAccess if SP not called'
		IF @CalledYN = 0
			BEGIN
				SELECT
					*
				FROM
					#ReadAccess
				ORDER BY
					[DimensionID]

				SELECT [@ReadAccessFilter] = @ReadAccessFilter
				 
				DROP TABLE #ReadAccess
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #LockedDimension

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
