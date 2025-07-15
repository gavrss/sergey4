SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminSet_Dimension_Refresh]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL,
	@HierarchyNo int = 0, --default Hierarchy, only valid if @MemberID is NOT NULL
	@MemberID int = NULL, -- used for deleting MemberID and all children of selected @HierarchyNo
/*
— This SP has two very different behaviours
— 1. REFRESH - if @MemberID parameter is not set or set to NULL (same behaviour would have occurred next nightly load if not executed on demand)
— This will affect dimension, current and all other hierarchies.
— 2. RESET to default - If @MemberID is set - resets to default (as it would have been set up in a new installation)
— This will only affect the selected hierarchy and the selected @MemberID and the lower level hierarchy members.
*/
	@CallistoDeployYN bit = 0,
	@AsynchronousYN bit = 1,
	
	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000755,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [spPortalAdminSet_Dimension_Refresh] @UserID=-10, @InstanceID=-1436, @VersionID=-1374, @DimensionID=-1, @DebugBM=15, @MemberID=290
EXEC [spPortalAdminSet_Dimension_Refresh] @UserID=-10, @InstanceID=561, @VersionID=1044, @DimensionID=-1, @DebugBM=15, @MemberID=290
EXEC [spPortalAdminSet_Dimension_Refresh] @UserID=-10, @InstanceID=561, @VersionID=1044, @DimensionID=-1, @DebugBM=3, @MemberID=290
EXEC [spPortalAdminSet_Dimension_Refresh] @UserID=-10, @InstanceID=531, @VersionID=1041, @DimensionID=9182, @DebugBM=3
EXEC [spPortalAdminSet_Dimension_Refresh] @UserID=-10, @InstanceID=574, @VersionID=1045, @DimensionID=9188, @DebugBM=3

EXEC [spPortalAdminSet_Dimension_Refresh] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(MAX),
	@JSON nvarchar(max),
	@DimensionName nvarchar(50),
	@StorageTypeBM int,
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@HierarchyName nvarchar(50),
	@HierarchyTypeID int,
	@ETLProcedure nvarchar(255),
	@Database nvarchar(100),
	@StoredProcedure nvarchar(100),
	@OptParam nvarchar(255),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
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
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Reset specified hierarchy if MemberID is set, If MemberID is not set all hierarchies will be refreshed using ETL procedure.',
			@MandatoryParameter = 'DimensionID' --Without @, separated by |

		IF @Version = '2.1.1.2169' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2172' SET @Description = 'Added parameters @HierarchyNo and @MemberID.'
		IF @Version = '2.1.1.2177' SET @Description = 'Implemented @Step = ''Delete @MemberID and its children in @HierarchyNo''.'
		IF @Version = '2.1.2.2179' SET @Description = 'Enhanced logic. Limitation to HierarchyTypeID IN (1, 2) when delete.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT 			 
			@DimensionName = [DimensionName]
		FROM 
			pcINTEGRATOR.dbo.Dimension 
		WHERE 
			InstanceID IN (0, @InstanceID) AND 
			DimensionID = @DimensionID
		
		SELECT 
			@StorageTypeBM = StorageTypeBM 
		FROM 
			pcINTEGRATOR_Data.dbo.Dimension_StorageType 
		WHERE 
			InstanceID = @InstanceID AND 
			VersionID = @VersionID AND 
			DimensionID = @DimensionID
				
		IF @StorageTypeBM IS NULL
			BEGIN
				SET @Message = 'StorageTypeBM is not defined for InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ', VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' and DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + '. Must be defined in table pcINTEGRATOR.dbo.Dimension_StorageType.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

		IF @StorageTypeBM & 4 > 0
			BEGIN
				SELECT
					@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
					@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
				FROM
					pcINTEGRATOR_Data.dbo.[Application] A
				WHERE
					A.InstanceID = @InstanceID AND
                    A.VersionID = @VersionID AND
					A.SelectYN <> 0
			END

			SELECT 
				@HierarchyName = MAX(ISNULL(DHI.[HierarchyName], DHG.[HierarchyName])),
				@HierarchyTypeID = MAX(ISNULL(DHI.[HierarchyTypeID], DHG.[HierarchyTypeID]))
			FROM
				pcINTEGRATOR.dbo.Dimension D
				LEFT JOIN [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DHI ON DHI.InstanceID = @InstanceID AND DHI.VersionID = @VersionID AND DHI.DimensionID = D.DimensionID AND DHI.HierarchyNo = @HierarchyNo
				LEFT JOIN [pcINTEGRATOR].[dbo].[@Template_DimensionHierarchy] DHG ON DHG.InstanceID = 0 AND DHG.VersionID = 0 AND DHG.DimensionID = D.DimensionID AND DHG.HierarchyNo = @HierarchyNo
			WHERE
				D.DimensionID = @DimensionID
			GROUP BY
				D.DimensionID	

			SELECT
				@ETLProcedure = [ETLProcedure]
			FROM
				[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] 
			WHERE 
				InstanceID = @InstanceID AND 
				VersionID = @VersionID AND 
				DimensionID = @DimensionID

			SELECT
				@Database = CASE WHEN LEFT(@ETLProcedure, 4) = 'spIU' THEN 'pcINTEGRATOR' ELSE LEFT(@ETLProcedure, CHARINDEX('.', @ETLProcedure) - 1) END,
				@StoredProcedure = SUBSTRING(@ETLProcedure, CHARINDEX('spIU', @ETLProcedure), CASE WHEN CHARINDEX(' ', @ETLProcedure) = 0 THEN 255 ELSE CHARINDEX(' ', @ETLProcedure) - CHARINDEX('spIU', @ETLProcedure) END),
				@OptParam = CASE WHEN CHARINDEX(' ', @ETLProcedure) = 0 THEN NULL ELSE SUBSTRING(@ETLProcedure, CHARINDEX(' ', @ETLProcedure) + 1, 255) END

		IF @DebugBM & 2 > 0
			SELECT
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@HierarchyNo] = @HierarchyNo,
				[@HierarchyName] = @HierarchyName,
				[@HierarchyTypeID] = @HierarchyTypeID,
				[@MemberID] = @MemberID,
				[@StorageTypeBM] = @StorageTypeBM,
				[@ETLProcedure] = @ETLProcedure,
				[@Database] = @Database,
				[@StoredProcedure] = @StoredProcedure,
				[@OptParam] = @OptParam

	SET @Step = 'Create temp table'
		CREATE TABLE #MembersToBeDeleted
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100),
			[RNodeType] nvarchar(2)
			)

	SET @Step = 'Delete @MemberID and its children in @HierarchyNo'
		IF @MemberID IS NULL OR @HierarchyTypeID NOT IN (1, 2)
			GOTO ETLLOAD

		IF @DimensionID IS NOT NULL
			BEGIN
				SET @SQLStatement = '
					;WITH cte AS
					(
						SELECT
							MemberID,
							ParentMemberID = CONVERT(bigint, 0)
						FROM
							' + @CallistoDatabase + '.[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H
						WHERE
							H.[MemberID] = ' + CONVERT(NVARCHAR(15), @MemberID) + ' 
						UNION ALL
						SELECT
							H.MemberID,
							H.ParentMemberID
						FROM
							' + @CallistoDatabase + '.[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H
							INNER JOIN cte c on c.[MemberID] = H.[ParentMemberID]
					)
					INSERT INTO #MembersToBeDeleted
						(
						[MemberId],
						[MemberKey],
						[RNodeType]
						)
					SELECT
						[MemberId] = D.[MemberId],
						[MemberKey] = D.[Label],
						[RNodeType] = D.[RNodeType]
					FROM
						cte
						INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + '] D ON D.MemberId = cte.MemberId'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT TempTable = '#MembersToBeDeleted', * FROM #MembersToBeDeleted

				SET @SQLStatement = '
					DELETE H
					FROM
						' + @CallistoDatabase + '.[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H
						INNER JOIN #MembersToBeDeleted MTBD ON MTBD.[MemberID] = H.[MemberID]'

				IF @HierarchyTypeID = 2 --Category
					SET @SQLStatement = @SQLStatement + ' AND MTBD.[RNodeType] LIKE ''L%'''

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)	
				
				SET @Deleted = @Deleted + @@ROWCOUNT
			END

	SET @Step = 'Execute dimension load SP'
		ETLLOAD:
		IF @DimensionID IS NOT NULL AND @StorageTypeBM & 4 > 0
			BEGIN
				SET @JSON = '
					[
					{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(10), @UserID) + '"},
					{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
					{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"},
					{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(10), @DimensionID) + '"},
					' + CASE WHEN @MemberID IS NOT NULL THEN '{"TKey" : "HierarchyNo",  "TValue": "' + CONVERT(nvarchar(10), @HierarchyNo) + '"},' ELSE '' END + '
					{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
					{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}
					]'

				IF @DebugBM & 2 > 0 PRINT @JSON
					
				EXEC spRun_Procedure_KeyValuePair
					@DatabaseName = @Database,
					@ProcedureName = @StoredProcedure,
					@OptParam = @OptParam,
					@JSON = @JSON

				SET @Step = 'Deploy Callisto database'
					IF @CallistoDeployYN <> 0
						EXEC [spRun_Job_Callisto_Generic]
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@StepName = 'Deploy',
								@AsynchronousYN = @AsynchronousYN,
								@MasterCommand = @ProcedureName,
								@JobID = @JobID
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
