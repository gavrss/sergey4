SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_SalesReport_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000998,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spIU_DC_SalesReport_Raw',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "907"},
		{"TKey" : "VersionID",  "TValue": "1313"},
		]'

EXEC [spIU_DC_SalesReport_Raw] @UserID=-10, @InstanceID=907, @VersionID=1313, @Debug=1

EXEC [spIU_DC_SalesReport_Raw] @UserID=-10, @InstanceID=907, @VersionID=1313, @Debug=2

EXEC [spIU_DC_SalesReport_Raw] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@TempTable_ObjectID int,
	@CallistoDatabase nvarchar(100) = NULL,
	@DataClassID int = NULL,
	@DataClassName nvarchar(50),
	@SQLInsertInto nvarchar(4000) = '',
	@SQLSelect nvarchar(4000) = '',
	@SQLGroupBy nvarchar(4000) = '',
	@SQLStatement nvarchar(MAX),

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
	@InfoMessage nvarchar(4000),
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'OsVe',
	@ModifiedBy nvarchar(50) = 'OsVe',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Populate #DC_SalesReport_Raw. Called from [spIU_DC_SalesReport_Callisto]',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2199' SET @Description = 'Procedure created.'

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

	SET @Step = 'Set up variables'
		SELECT
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(ISNULL(@CallistoDatabase, A.DestinationDatabase), '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[pcINTEGRATOR].[dbo].[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		SELECT
			@DataClassID = ISNULL(@DataClassID, MAX(DC.DataClassID)),
			@DataClassName = MAX(DC.DataClassName)
		FROM
			[pcINTEGRATOR_Data].[dbo].DataClass DC
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.VersionID = @VersionID AND
			DC.DataClassTypeID = -10 AND
			(DC.DataClassID = @DataClassID OR @DataClassID IS NULL) AND
			DC.SelectYN <> 0 AND
			DC.DeletedID IS NULL

	SET @Step = 'SP-Specific check'
		IF @CallistoDatabase IS NULL
			BEGIN
				SET @InfoMessage = 'Callisto Database was not found.';
				THROW 51000, @InfoMessage, 2;
			END

	SET @Step = 'Create temp table #DataClassColumns'
				
		CREATE TABLE #DataClassColumns
			(
			DimensionID INT,
			DimensionTypeID INT,
			ColumnName NVARCHAR(100) COLLATE DATABASE_DEFAULT,
			DataType nvarchar(50) COLLATE DATABASE_DEFAULT,
			SortOrder int
			)

		INSERT INTO #DataClassColumns
			(
			DimensionID,
			DimensionTypeID,
			ColumnName,
			DataType,
			SortOrder
			)
		SELECT 
			DimensionID = DCD.DimensionID,
			DimensionTypeID = D.DimensionTypeID,
			ColumnName = CONVERT(nvarchar(100), D.DimensionName + '_MemberId') COLLATE DATABASE_DEFAULT,
			DataType = CONVERT(nvarchar(50), 'bigint'),
			SortOrder = DCD.SortOrder
		FROM
			[pcINTEGRATOR].[dbo].[DataClass_Dimension] DCD
			INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.DimensionID = DCD.DimensionID AND D.DimensionTypeID <> 27 AND D.SelectYN <> 0 AND D.DeletedID IS NULL
		WHERE
			DCD.DataClassID = @DataClassID  AND
			DCD.DimensionID NOT IN (-77)
		ORDER BY
			DCD.SortOrder

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DataClassColumns', * FROM #DataClassColumns ORDER BY SortOrder

		IF (SELECT COUNT(1) FROM #DataClassColumns) = 0
			BEGIN
				SET @InfoMessage = 'No dimensions specified for selected DataClassID';
				THROW 51000, @InfoMessage, 2;
			END
	
	SET @Step = 'Create Temp Table #DC_SalesReport_Raw'

		IF OBJECT_ID(N'TempDB.dbo.#DC_SalesReport_Raw', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE [#DC_SalesReport_Raw]
					([DataClassID] int)

				SELECT @TempTable_ObjectID = OBJECT_ID (N'tempdb..#DC_SalesReport_Raw', N'U')

				SET @SQLStatement = 'ALTER TABLE #DC_SalesReport_Raw' + CHAR(13) + CHAR(10) + 'ADD'

				SELECT 
					@SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + ColumnName + ' ' + DataType + CASE WHEN ColumnName = 'BusinessRule_MemberId' THEN ' DEFAULT -1 ,' 
																													WHEN ColumnName = 'CurrentOrderState_MemberId' THEN ' DEFAULT -1 ,'
																													WHEN ColumnName = 'Scenario_MemberId' THEN ' DEFAULT 110 ,'
																													WHEN ColumnName = 'TimeDataView_MemberId' THEN ' DEFAULT 101 ,'
																													ELSE ',' END
				FROM
					#DataClassColumns
				ORDER BY
					SortOrder

				SET @SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + @DataClassName + '_Value float' 
	
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END
		
		IF @DebugBM & 2 > 0 SELECT [@TempTable_ObjectID] = @TempTable_ObjectID
		IF @DebugBM & 8 > 0 SELECT [TempTable] = '#DC_SalesReport_Raw', * FROM #DC_SalesReport_Raw

	SET @Step = 'Insert values into Temp Table #DC_SalesReport_Raw'

		SELECT
			@SQLInsertInto = @SQLInsertInto + CHAR(13) + CHAR(10) + CHAR(9) + '[' + ColumnName + '],',
			@SQLSelect = @SQLSelect + CHAR(13) + CHAR(10) + CHAR(9) + CASE WHEN ColumnName = 'TimeDay_MemberId' THEN '[' + ColumnName + '] = F.[' + ColumnName + '] / 100,' ELSE '[' + ColumnName + '] = F.[' + ColumnName + '],' END,
			@SQLGroupBy = @SQLGroupBy +  CHAR(13) + CHAR(10) + CHAR(9) + CASE WHEN ColumnName = 'TimeDay_MemberId' THEN 'F.[' + ColumnName + '] / 100,' ELSE 'F.[' + ColumnName + '],' END
		FROM #DataClassColumns
		
		SELECT
			@SQLInsertInto = LEFT(@SQLInsertInto, LEN(@SQLInsertInto) - 1),
			@SQLSelect = LEFT(@SQLSelect, LEN(@SQLSelect) - 1),
			@SQLGroupBy = LEFT(@SQLGroupBy, LEN(@SQLGroupBy) - 1)

		IF @DebugBM & 2 > 0 SELECT [@SQLInsertInto] = @SQLInsertInto, [@SQLSelect] = @SQLSelect, [@SQLGroupBy] = @SQLGroupBy

		SET @SQLStatement = '
			INSERT INTO #DC_SalesReport_Raw
				(
				[DataClassID],' + @SQLInsertInto + ',
				[Sales_Value]
				)
			SELECT
				[DataClassID] = ' + CONVERT(nvarchar(10), @DataClassID) + ',' + @SQLSelect + ',
				[Sales_Value] = SUM(F.[Sales_Value])
			FROM
				' + @CallistoDatabase + '.[dbo].[FACT_Sales_default_partition] F
			GROUP BY'+ @SQLGroupBy + '
			HAVING
				SUM(F.[Sales_Value]) <> 0.0
			'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC(@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Return rows'
		IF @CalledYN = 0
			SELECT TempTable = '#DC_SalesReport_Raw', * FROM #DC_SalesReport_Raw --ORDER BY [Time_MemberId]

	SET @Step = 'Drop temp tables'
		IF @CalledYN = 0 DROP TABLE #DC_SalesReport_Raw

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
