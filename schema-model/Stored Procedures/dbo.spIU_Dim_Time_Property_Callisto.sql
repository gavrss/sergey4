SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spIU_Dim_Time_Property_Callisto]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	--SP-specific parameters
	@DimensionID INT = NULL, --When NULL, run all Time Property Dimensions; When set, run the specified
	@HierarchyNo INT = NULL,
	--NB New hierarchy routines are not yet implemented

	@StartYear INT = NULL,
	@AddYear INT = NULL, --Number of years to add after current year
	@FiscalYearStartMonth INT = NULL,
	@FiscalYearNaming INT = NULL,
	@DimensionName NVARCHAR(100) = NULL, --When NULL, run all Time Property Dimensions; When set, run the specified

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000677,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [pcINTEGRATOR].[dbo].[spIU_Dim_Time_Property_Callisto] @InstanceID=585,@UserID=-10,@VersionID=1084,@DimensionID = -40,@DebugBM=15,@AddYear=21

EXEC [spIU_Dim_Time_Property_Callisto] @UserID=-10, @InstanceID = -1329, @VersionID = -1267, @StartYear = 2019, @FiscalYearStartMonth = 7, @FiscalYearNaming = 1, @AddYear=2, @DebugBM=3
EXEC [spIU_Dim_Time_Property_Callisto] @UserID=-10, @InstanceID=452, @VersionID=1020, @DimensionID=-45, @DebugBM=1 --ReSales
EXEC [spIU_Dim_Time_Property_Callisto] @UserID=-10, @InstanceID=452, @VersionID=1020, @DimensionName='TimeFiscalYear', @DebugBM=1 --ReSales

EXEC [spIU_Dim_Time_Property_Callisto] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SourceDatabase NVARCHAR(100),
	@CallistoDatabase NVARCHAR(100),
	@LinkedYN BIT,
	@SQLStatement NVARCHAR(MAX),
	@JSON NVARCHAR(MAX),
	@ParentsWithoutChildrenCount INT = 1,
	@LogPropertyYN BIT = 0, --Properties JobID, Inserted & Updated,
	@NodeTypeBMYN BIT = 0,
	@StorageTypeBM INT = 4,
	@Dimensionhierarchy NVARCHAR(100),
	@ProcedureName_Step NVARCHAR(100),
	@StartTime_Step DATETIME,
	@Duration_Step TIME(7),
	@Deleted_Step INT = 0,
	@Inserted_Step INT = 0,
	@Updated_Step INT = 0,
	@Selected_Step INT = 0,

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@DatabaseName nvarchar(100),
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
	@ToBeChanged NVARCHAR(255) = 'Add database stored parameters for @AddYear and @DataFirst',
	@CreatedBy NVARCHAR(50) = 'JaWo',
	@ModifiedBy NVARCHAR(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2194'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'ETL Procedure to load Members into Dimension Tables',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2148' SET @Description = 'Made generic.'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-310: Added @FiscalYearNaming.'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.2.2191' SET @Description = 'Use sub routine spSet_Hierarchy for hierarchy setup.'
		IF @Version = '2.1.2.2194' SET @Description = 'Updated query for setting @AddYear.'

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
		SET @UserName = ISNULL(@UserName, SUSER_NAME())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@CallistoDatabase = A.DestinationDatabase,
			@FiscalYearStartMonth = COALESCE(@FiscalYearStartMonth, A.FiscalYearStartMonth, I.FiscalYearStartMonth),
			@FiscalYearNaming = ISNULL(@FiscalYearNaming, I.FiscalYearNaming),
			@AddYear = COALESCE(@AddYear, I.AddYear, 2)	--Number of years to add after current year
		FROM
			[Application] A
			INNER JOIN [Instance] I ON I.InstanceID = A.InstanceID 
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND 
			A.[SelectYN] <> 0
			
		SELECT
			@StartYear = ISNULL(@StartYear, MIN(StartYear))
		FROM
			[Source] S
		WHERE
			S.InstanceID = @InstanceID AND
			S.VersionID = @VersionID

		--SELECT @AddYear = ISNULL(@AddYear, 2) --Number of years to add after current year

		IF @DebugBM & 2 > 0 SELECT [@CallistoDatabase] = @CallistoDatabase, [@StartYear] = @StartYear, [@AddYear] = @AddYear, [@FiscalYearStartMonth] = @FiscalYearStartMonth, [@FiscalYearNaming] = @FiscalYearNaming

	SET @Step = 'Create table #Time_Property'
		CREATE TABLE #Time_Property
			(
			[MemberId] INT,
			[MemberKey] NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			[Label] NVARCHAR(255) COLLATE DATABASE_DEFAULT,
			[Description] NVARCHAR(512) COLLATE DATABASE_DEFAULT,
			[HelpText] NVARCHAR(1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] INT,
			[RNodeType] NVARCHAR(2) COLLATE DATABASE_DEFAULT,
			[SBZ] BIT,
			[Source] NVARCHAR(50) COLLATE DATABASE_DEFAULT,
			[Synchronized] BIT,				
			[Parent] NVARCHAR(255) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Time_Property_Callisto_Cursor'
		CREATE TABLE #Time_Property_Callisto_Cursor
			(
			DimensionID INT,
			DimensionName NVARCHAR(100) COLLATE DATABASE_DEFAULT
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
				InstanceID IN (0, ' + CONVERT(NVARCHAR(10), @InstanceID) + ') AND
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
			
                    EXEC [dbo].[spGet_DimPropertyStatus]
                        @UserID = @UserID,
                        @InstanceID = @InstanceID,
                        @VersionID = @VersionID,
                        @DimensionID = @DimensionID,
                        @StorageTypeBM = @StorageTypeBM,
                        @LogPropertyYN = @LogPropertyYN OUT,
                        @NodeTypeBMYN = @NodeTypeBMYN OUT,
                        @JobID = @JobID,
                        @Debug = @DebugSub
                        								
					IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@LogPropertyYN] = @LogPropertyYN, [@NodeTypeBMYN] = @NodeTypeBMYN

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
							[Description] = Members.[Description],
							' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
							' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(NVARCHAR(50), FORMAT(GETDATE(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
							' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM] = Members.[NodeTypeBM],' ELSE '' END + '
							[Source] = Members.[Source]  
						FROM
							' + @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + '] [Dimension] 
							INNER JOIN [#Time_Property] Members ON Members.Label COLLATE DATABASE_DEFAULT = [Dimension].[Label]
						WHERE 
							[Dimension].[Synchronized] <> 0 AND
							(
								[Dimension].[Description] <> Members.[Description] OR
								[Dimension].[HelpText] <> Members.[HelpText] OR
								' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[Dimension].[NodeTypeBM] <> Members.[NodeTypeBM] OR [Dimension].[NodeTypeBM] IS NULL OR' ELSE '' END + '
								[Dimension].[Source] <> Members.[Source]
							)'

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
							' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
							[SBZ],				
							[Synchronized],
							' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID],' ELSE '' END + '
							' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted],' ELSE '' END + '
							' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated],' ELSE '' END + '
							[Source]
							)
						SELECT
							[MemberId],
							[Label],
							[Description],
							[HelpText],
							[RNodeType],
							' + CASE WHEN @NodeTypeBMYN <> 0 THEN '[NodeTypeBM],' ELSE '' END + '
							[SBZ],
							[Synchronized],
							' + CASE WHEN @LogPropertyYN <> 0 THEN '[JobID] = ' + CONVERT(NVARCHAR(15), @JobID) + ',' ELSE '' END + '
							' + CASE WHEN @LogPropertyYN <> 0 THEN '[Inserted] = ''' + CONVERT(NVARCHAR(50), FORMAT(GETDATE(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
							' + CASE WHEN @LogPropertyYN <> 0 THEN '[Updated] = ''' + CONVERT(NVARCHAR(50), FORMAT(GETDATE(),'yyyy-MM-dd HH:mm:ss.fff')) + ''',' ELSE '' END + '
							[Source]
						FROM   
							[#Time_Property] Members
						WHERE
							NOT EXISTS (SELECT 1 FROM ' + @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + '] [Dimension] WHERE [Dimension].Label COLLATE DATABASE_DEFAULT = Members.Label)' 
			
						IF @DebugBM & 2 > 0 PRINT @SQLStatement		
						EXEC (@SQLStatement)			

						SET @Inserted_Step = @@ROWCOUNT

					SET @Step = 'Update MemberId'
						EXEC spSet_MemberId @Database = @CallistoDatabase, @Dimension = @DimensionName

					SET @Step = 'Refresh selected hierarchies.'
						SET @JSON = '
							[
							{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
							{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
							{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
							{"TKey" : "DimensionID",  "TValue": "' + CONVERT(nvarchar(15), @DimensionID) + '"},
							{"TKey" : "SourceTable",  "TValue": "#Time_Property"},
							' + CASE WHEN @HierarchyNo IS NOT NULL THEN '{"TKey" : "HierarchyNo",  "TValue": "' + CONVERT(nvarchar(10), @HierarchyNo) + '"},' ELSE '' END + '
							{"TKey" : "StorageTypeBM",  "TValue": "' + CONVERT(nvarchar(15), @StorageTypeBM) + '"},
							{"TKey" : "StorageDatabase",  "TValue": "' + @CallistoDatabase + '"},
							{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(10), @JobID) + '"},
							{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(10), @DebugSub) + '"}
							]'

						IF @DebugBM & 2 > 0 PRINT @JSON
					
						EXEC spRun_Procedure_KeyValuePair
							@DatabaseName = 'pcINTEGRATOR',
							@ProcedureName = 'spSet_Hierarchy',
							@JSON = @JSON

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
		DROP TABLE #Time_Property
		DROP TABLE #Time_Property_Callisto_Cursor

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
