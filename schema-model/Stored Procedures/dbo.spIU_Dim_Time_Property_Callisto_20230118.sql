SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spIU_Dim_Time_Property_Callisto_20230118]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	--SP-specific parameters
	@DimensionID INT = NULL, --When NULL, run all Time Property Dimensions; When set, run the specified
	@HierarchyNo INT = NULL,
	--NB New hierarchy routines are not yet implemented

	@StartYear INT = NULL,
	@AddYear INT = 2, --Number of years to add after current year
	@FiscalYearStartMonth INT = NULL,
	@FiscalYearNaming INT = NULL,
	@DimensionName NVARCHAR(100) = NULL, --When NULL, run all Time Property Dimensions; When set, run the specified

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000677,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM = 3 (include high and low prio, exclude sub routines)
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_Dim_Time_Property_Callisto] @UserID=-10, @InstanceID = -1329, @VersionID = -1267, @StartYear = 2019, @FiscalYearStartMonth = 7, @FiscalYearNaming = 1, @AddYear=2, @DebugBM=3
EXEC [spIU_Dim_Time_Property_Callisto] @UserID=-10, @InstanceID=452, @VersionID=1020, @DimensionID=-45, @DebugBM=1 --ReSales
EXEC [spIU_Dim_Time_Property_Callisto] @UserID=-10, @InstanceID=452, @VersionID=1020, @DimensionName='TimeFiscalYear', @DebugBM=1 --ReSales

EXEC [spIU_Dim_Time_Property_Callisto] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CallistoDatabase nvarchar(100),
	@Dimensionhierarchy nvarchar(100),
	@SQLStatement nvarchar(max),
	@ProcedureName_Step nvarchar(100),
	@StartTime_Step datetime,
	@Duration_Step time(7),
	@Deleted_Step int = 0,
	@Inserted_Step int = 0,
	@Updated_Step int = 0,
	@Selected_Step int = 0,

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
	@ToBeChanged nvarchar(255) = 'Add database stored parameters for @AddYear and @DataFirst',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2161'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'ETL Procedure to load Members into Dimension Tables',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Made generic.'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-310: Added @FiscalYearNaming.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'

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

		IF @DebugBM & 2 > 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = A.DestinationDatabase,
			@FiscalYearStartMonth = COALESCE(@FiscalYearStartMonth, A.FiscalYearStartMonth, I.FiscalYearStartMonth),
			@FiscalYearNaming = ISNULL(@FiscalYearNaming, I.FiscalYearNaming)
		FROM
			[Application] A
			INNER JOIN [Instance] I ON I.InstanceID = A.InstanceID 
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID

		SELECT
			@StartYear = ISNULL(@StartYear, MIN(StartYear))
		FROM
			[Source] S
		WHERE
			S.InstanceID = @InstanceID AND
			S.VersionID = @VersionID

		SELECT
			@AddYear = ISNULL(@AddYear, 2) --Number of years to add after current year

		IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@StartYear] = @StartYear, [@AddYear] = @AddYear, [@FiscalYearStartMonth] = @FiscalYearStartMonth, [@FiscalYearNaming] = @FiscalYearNaming

	SET @Step = 'Create table #LeafCheck'
		CREATE TABLE #LeafCheck
			(
			[MemberId] [bigint] NOT NULL,
			HasChild bit NOT NULL
			)

	SET @Step = 'Create table #Time_Property'
		CREATE TABLE #Time_Property
			(
			[MemberId] int,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Label] nvarchar(255) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar(512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[RNodeType] nvarchar(2) COLLATE DATABASE_DEFAULT,
			[SBZ] bit,
			[Source] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] bit,				
			[Parent] nvarchar(255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Time_Property_Callisto_Cursor'
		CREATE TABLE #Time_Property_Callisto_Cursor
			(
			DimensionID int,
			DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		SET @SQLStatement = '
			INSERT INTO #Time_Property_Callisto_Cursor
				(
				DimensionID,
				DimensionName
				)
			SELECT 
				DimensionID,
				DimensionName
			FROM
				[Dimension] D
				INNER JOIN [' + @CallistoDatabase + '].sys.tables t ON t.name = ''S_DS_'' + D.DimensionName
			WHERE
				InstanceID IN (0, ' + CONVERT(nvarchar(10), @InstanceID) + ') AND
				DimensionTypeID = 25' + '
				' + CASE WHEN @DimensionID IS NULL THEN '' ELSE 'AND D.DimensionID = ' +  CONVERT(NVARCHAR(10),@DimensionID) END + '
				' + CASE WHEN @DimensionName IS NULL THEN '' ELSE 'AND D.DimensionName = ''' +  @DimensionName + '''' END

			IF @DebugBM & 2 > 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

			IF @DebugBM & 2 > 0 SELECT TempTable = '#Time_Property_Callisto_Cursor', * FROM #Time_Property_Callisto_Cursor ORDER BY DimensionID

		IF CURSOR_STATUS('global','Time_Property_Callisto_Cursor') >= -1 DEALLOCATE Time_Property_Callisto_Cursor
		DECLARE Time_Property_Callisto_Cursor CURSOR FOR
			SELECT 
				DimensionID,
				DimensionName
			FROM
				#Time_Property_Callisto_Cursor
			ORDER BY
				DimensionID

			OPEN Time_Property_Callisto_Cursor
			FETCH NEXT FROM Time_Property_Callisto_Cursor INTO @DimensionID, @DimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @StartTime_Step = GETDATE()
					IF @DebugBM & 2 > 0 SELECT DimensionID = @DimensionID, DimensionName = @DimensionName

					SET @Step = 'Get values to insert'
						TRUNCATE TABLE #Time_Property
						EXEC [spIU_Dim_Time_Property_Raw] @DimensionID = @DimensionID, @StartYear = @StartYear, @AddYear = @AddYear, @FiscalYearStartMonth = @FiscalYearStartMonth, @FiscalYearNaming = @FiscalYearNaming, @Debug = @DebugSub
						
						SELECT @Selected_Step = COUNT(1) FROM #Time_Property

						UPDATE #Time_Property SET [Label] = [MemberKey], [RNodeType] = CASE WHEN NodeTypeBM & 1 > 0 THEN 'L' ELSE '' END + CASE WHEN NodeTypeBM & 2 > 0 THEN 'P' ELSE '' END  + CASE WHEN NodeTypeBM & 8 > 0 THEN 'C' ELSE '' END

					SET @Step = 'Update Description where Synchronized is set to true.'
						SET @SQLStatement = '
						UPDATE
							[Dimension]
						SET
							[Description] = Members.[Description]
						FROM
							' + @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + '] [Dimension] 
							INNER JOIN [#Time_Property] Members ON Members.Label COLLATE DATABASE_DEFAULT = [Dimension].[Label]
						WHERE 
							[Dimension].[Synchronized] <> 0'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement		
						EXEC (@SQLStatement)

						SET @Updated_Step = @@ROWCOUNT
		
					SET @Step = 'Insert new members'
						SET @SQLStatement = '
						INSERT INTO ' + @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + ']
							(
							[MemberId],
							[Label],
							[Description], 
							[HelpText],
							[RNodeType],
							[SBZ],
							[Source],
							[Synchronized] 
							)
						SELECT
							[MemberId],
							[Label],
							[Description],
							[HelpText],
							[RNodeType],
							[SBZ],
							[Source],
							[Synchronized]
						FROM   
							[#Time_Property] Members
						WHERE
							NOT EXISTS (SELECT 1 FROM ' + @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + '] [Dimension] WHERE [Dimension].Label COLLATE DATABASE_DEFAULT = Members.Label)' 
			
						IF @DebugBM & 2 > 0 PRINT @SQLStatement		
						EXEC (@SQLStatement)			

						SET @Inserted_Step = @@ROWCOUNT

					SET @Step = 'Update MemberId'
						EXEC spSet_MemberId @Database = @CallistoDatabase, @Dimension = @DimensionName

					SET @Step = 'Check which parent members have leaf members as children.'
						TRUNCATE TABLE #LeafCheck

						EXEC spSet_LeafCheck @Database = @CallistoDatabase, @Dimension = @DimensionName, @DimensionTemptable = N'#Time_Property', @Debug = @DebugSub

					SET @Step = 'Insert new members into the default hierarchy. To change the hierarchy, use the Modeler.'
						SET @Dimensionhierarchy = @DimensionName + '_' + @DimensionName
						SET @SQLStatement = '
						INSERT INTO ' + @CallistoDatabase + '.[dbo].[S_HS_' + @Dimensionhierarchy + ']
							(
							[MemberId],
							[ParentMemberId],
							[SequenceNumber]
							)
						SELECT
							D1.MemberId,
							ISNULL(D2.MemberId, 0),
							D1.MemberId  
						FROM
							' + @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + '] D1
							INNER JOIN [#Time_Property] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
							LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + '] D2 ON D2.Label = CONVERT(nvarchar(255), V.Parent) COLLATE DATABASE_DEFAULT
							LEFT JOIN [#LeafCheck] LC ON LC.MemberId = D1.MemberId AND LC.HasChild <> 0
						WHERE
							NOT EXISTS (SELECT 1 FROM ' + @CallistoDatabase + '.[dbo].[S_HS_' + @Dimensionhierarchy + '] H WHERE H.MemberId = D1.MemberId) AND
							[D1].[Synchronized] <> 0 AND
							D1.MemberId <> ISNULL(D2.MemberId, 0) AND
							D1.MemberId IS NOT NULL AND
							D1.MemberId NOT IN (1000, 30000000) AND
							(D1.RNodeType IN (''L'', ''LC'') OR LC.MemberId IS NOT NULL)
						ORDER BY
							D1.Label'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement		
						EXEC (@SQLStatement)

					SET @Step = 'Copy the hierarchy to all instances'
						EXEC spSet_HierarchyCopy @Database = @CallistoDatabase, @Dimensionhierarchy = @Dimensionhierarchy

					SET @Step = 'Return rows'
						IF @DebugBM & 1 > 0 EXEC('SELECT [Table] = ''[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']'', * FROM [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']')

					SET @Step = 'Log Property steps'
						SELECT
							@ProcedureName_Step = @ProcedureName + '; ' + @DimensionName,
							@Duration_Step = GETDATE() - @StartTime_Step
						EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime_Step, @ProcedureName = @ProcedureName_Step, @Duration = @Duration_Step, @Deleted = @Deleted_Step, @Inserted = @Inserted_Step, @Updated = @Updated_Step, @Selected = @Selected_Step, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

						SELECT
							@Deleted = @Deleted + ISNULL(@Deleted_Step, 0),
							@Inserted = @Inserted + ISNULL(@Inserted_Step, 0),
							@Updated = @Updated + ISNULL(@Updated_Step, 0),
							@Selected = @Selected + ISNULL(@Selected_Step, 0)
					
					FETCH NEXT FROM Time_Property_Callisto_Cursor INTO @DimensionID, @DimensionName
				END

		CLOSE Time_Property_Callisto_Cursor
		DEALLOCATE Time_Property_Callisto_Cursor

	SET @Step = 'Drop temp tables'
		DROP TABLE #LeafCheck
		DROP TABLE #Time_Property
		DROP TABLE #Time_Property_Callisto_Cursor

	SET @Step = 'Set @Duration'
		SET @Duration = GETDATE() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GETDATE() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
