SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_DimensionMember_List_Column]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL,
	@NodeTypeBM int = NULL,
	@ObjectGuiBehaviorBM int = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 0,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000820,
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
EXEC [spGet_DimensionMember_List_Column]
@UserID = -10,
@InstanceID = 666,
@VersionID = 1128,
@DimensionID = -1,
@NodeTypeBM = 2,
@ObjectGuiBehaviorBM = 3,
@Debug = 1

EXEC [spGet_DimensionMember_List_Column]
	@UserID = -10,
	@InstanceID = 531,
	@VersionID = 1041,
	@DimensionID = 9155

EXEC [spGet_DimensionMember_List_Column] @UserID = -10, @InstanceID = 574, @VersionID = 1045, @DimensionID = 9188, @NodeTypeBM = 1

EXEC [spGet_DimensionMember_List_Column] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get leaf dimension members showing Category parents in columns.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2175' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2179' SET @Description = 'Added SortOrder in temp table #Column.'
		IF @Version = '2.1.2.2180' SET @Description = 'Handle hierarchies for standard dimensions.'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-1702: Allow setting of [AccounType] property for Account dimension in DimensionMembers import routine.'

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

	SET @Step = 'Create and fill temp tables'
		IF OBJECT_ID(N'TempDB.dbo.#Column', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #Column
					(
					[ColumnCode] nchar(3) COLLATE DATABASE_DEFAULT,
					[ColumnName] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[DimensionID] int,
					[DimensionName] nvarchar(50) COLLATE DATABASE_DEFAULT,
					[VisibleYN] bit,
					[SortOrder] int
					)
			END
	
	SET @Step = 'Create and fill temp table #MultiDimension'
		CREATE TABLE #MultiDimension
			(
			[ID] int IDENTITY(1,1),
			[PropertyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DimensionID] int,
			[DimensionName] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

		IF @NodeTypeBM & 1 > 0
			BEGIN
				INSERT INTO #MultiDimension
					(
					[PropertyName],
					[DimensionID],
					[DimensionName]
					)
				SELECT 
					[PropertyName] = P.[PropertyName],
					[DimensionID] = P.[DependentDimensionID],
					[DimensionName] = D.[DimensionName]
				FROM
					[pcINTEGRATOR].[dbo].[Dimension_Property] DP
					INNER JOIN [pcINTEGRATOR].[dbo].[Property] P ON P.[PropertyID] = DP.[PropertyID]
					INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.InstanceID IN (0, @InstanceID) AND D.[DimensionID] = P.[DependentDimensionID]
				WHERE
					DP.[InstanceID] = @InstanceID AND
					DP.[VersionID] = @VersionID AND
					DP.[DimensionID] = @DimensionID AND
					DP.[MultiDimYN] <> 0
				ORDER BY
					DP.SortOrder
			END

	SET @Step = 'Create and fill temp table #Hierarchy'
		CREATE TABLE #Hierarchy
			(
			[HierarchyNo] int,
			[HierarchyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[HierarchyTypeID] int
			)

		IF @NodeTypeBM & 3 > 0
			BEGIN
				INSERT INTO #Hierarchy
					(
					[HierarchyNo],
					[HierarchyName],
					[HierarchyTypeID]
					)
				SELECT
					[HierarchyNo] = DH.[HierarchyNo],
					[HierarchyName] = DH.[HierarchyName],
					[HierarchyTypeID] = DH.[HierarchyTypeID]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_DimensionHierarchy] DH 
				WHERE
					[InstanceID] = 0 AND
					[VersionID] = 0 AND
					[DimensionID] = @DimensionID AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DDH WHERE DDH.[InstanceID] = @InstanceID AND DDH.[VersionID] = @VersionID AND DDH.[DimensionID] = @DimensionID AND DDH.[HierarchyName] = DH.[HierarchyName])

				UNION SELECT
					[HierarchyNo] = DH.[HierarchyNo],
					[HierarchyName] = DH.[HierarchyName],
					[HierarchyTypeID] = DH.[HierarchyTypeID]
				FROM
					[pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH 
				WHERE
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[DimensionID] = @DimensionID
			END

	SET @Step = 'Create and fill temp table #Property'
		CREATE TABLE #Property
			(
			[ID] int IDENTITY(1,1),
			[PropertyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[VisibleYN] bit,
			[SortOrder] int
			)

		INSERT INTO #Property
			(
			[PropertyName],
			[VisibleYN],
			[SortOrder]
			)
		SELECT 
			[PropertyName] = P.[PropertyName],
			[VisibleYN] = CASE WHEN P.ObjectGuiBehaviorBM & 32 > 0 THEN 0 ELSE CASE WHEN P.ObjectGuiBehaviorBM & @ObjectGuiBehaviorBM > 0 THEN 1 ELSE 0 END END,
			[SortOrder] = DP.[SortOrder]
		FROM
			[pcINTEGRATOR].[dbo].[Dimension_Property] DP
			INNER JOIN [pcINTEGRATOR].[dbo].[Property] P ON P.[PropertyID] = DP.[PropertyID]
		WHERE
			DP.[InstanceID] = @InstanceID AND
			DP.[VersionID] = @VersionID AND
			DP.[DimensionID] = @DimensionID AND
			DP.[MultiDimYN] = 0 AND
			DP.[PropertyID] NOT IN (-192, 12) AND
			DP.[NodeTypeBM] & @NodeTypeBM > 0
		--Add AccountType property if Dimension = Account
		UNION	
		SELECT 
			[PropertyName] = P.[PropertyName],
			[VisibleYN] = CASE WHEN P.ObjectGuiBehaviorBM & 32 > 0 THEN 0 ELSE CASE WHEN P.ObjectGuiBehaviorBM & @ObjectGuiBehaviorBM > 0 THEN 1 ELSE 0 END END,
			[SortOrder] = DP.[SortOrder]
		FROM
			[pcINTEGRATOR].[dbo].[Dimension_Property] DP
			INNER JOIN [pcINTEGRATOR].[dbo].[Property] P ON P.[PropertyID] = DP.[PropertyID]
		WHERE
			DP.[InstanceID] = 0 AND
			DP.[VersionID] = 0 AND
			DP.[DimensionID] = @DimensionID AND
			DP.[MultiDimYN] = 0 AND
			DP.[PropertyID] IN (-192) AND
			DP.[NodeTypeBM] & @NodeTypeBM > 0 AND
			@DimensionID = -1
		ORDER BY
			DP.SortOrder,
			P.[PropertyName]

	SET @Step = 'Fill temp table #Column'
		INSERT INTO #Column
			(
			[ColumnCode],
			[ColumnName],
			[DimensionID],
			[DimensionName],
			[VisibleYN],
			[SortOrder]
			)
		SELECT
			[ColumnCode],
			[ColumnName],
			[DimensionID],
			[DimensionName],
			[VisibleYN],
			[SortOrder]
		FROM
			(
			SELECT 
				[ColumnCode] = 'D' + CASE WHEN MD.[ID] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), MD.[ID]),
				[ColumnName] = MD.[PropertyName],
				[DimensionID] = MD.[DimensionID],
				[DimensionName] = MD.[DimensionName],
				[VisibleYN] = 1,
				[SortOrder] = 100 + MD.[ID]
			FROM
				#MultiDimension MD

			UNION
			SELECT
				[ColumnCode] = CASE WHEN H.[HierarchyTypeID] = 2 AND @NodeTypeBM & 1024 > 0 THEN 'C' ELSE 'H' END + CASE WHEN H.[HierarchyNo] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), H.[HierarchyNo]),
				[ColumnName] = H.[HierarchyName],
				[DimensionID] = NULL,
				[DimensionName] = NULL,
				[VisibleYN] = 1,
				[SortOrder] = CASE WHEN H.[HierarchyTypeID] = 2 THEN 200 ELSE 300 END + H.[HierarchyNo]
			FROM
				#Hierarchy H 

			UNION
			SELECT 
				[ColumnCode] = 'P' + CASE WHEN P.[ID] <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), P.[ID]),
				[ColumnName] = P.[PropertyName],
				[DimensionID] = NULL,
				[DimensionName] = NULL,
				[VisibleYN] = P.[VisibleYN],
				[SortOrder] = 400 + P.[ID]
			FROM
				#Property P
			) sub
		ORDER BY
			sub.[ColumnCode]

		SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Return rows'
		IF @CalledYN = 0
			SELECT TempTable = '#Column', * FROM #Column ORDER BY [SortOrder]

	SET @Step = 'Drop temp tables'
		DROP TABLE #MultiDimension
		DROP TABLE #Property
		IF @CalledYN = 0 DROP TABLE #Column

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
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
