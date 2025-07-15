SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_SalesReport_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@CallistoDatabase nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000997,
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
	@ProcedureName = 'spIU_DC_SalesReport_Callisto',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "907"},
		{"TKey" : "VersionID",  "TValue": "1313"}
		]'

EXEC [spIU_DC_SalesReport_Callisto] @UserID=-10, @InstanceID=907, @VersionID=1313, @Debug=1

EXEC [spIU_DC_SalesReport_Callisto] @UserID=-10, @InstanceID=907, @VersionID=1313, @Debug=2

EXEC [spIU_DC_SalesReport_Callisto] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DataClassID int = NULL,
	@DataClassName nvarchar(50),
	@BusinessProcess nvarchar(50),
	@BusinessProcess_MemberId bigint,
	@Scenario nvarchar(50) = 'ACTUAL',
	@Scenario_MemberId bigint,
	@TempTable_ObjectID int,
	@SQLInsertInto nvarchar(4000) = '',
	@SQLSelect nvarchar(4000) = '',
	@SQLStatement nvarchar(max),
	@StepStartTime datetime,
	@JSON nvarchar(max),

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
			@ProcedureDescription = 'Updates DC SalesReport with Actuals from DC Sales',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2199' SET @Description = 'Procedure created.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())
		SET DATEFIRST 1 -- Copying from HC sp

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
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(ISNULL(@CallistoDatabase, A.DestinationDatabase), '[', ''), ']', ''), '.', '].[') + ']',
			@BusinessProcess = S.[BusinessProcess]
		FROM
			[pcINTEGRATOR].[dbo].[Application] A
			INNER JOIN [pcINTEGRATOR].[dbo].[Model] M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -4 AND M.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR].[dbo].[Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR].[dbo].[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
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

		SET @SQLStatement = '
			SELECT @internalvariable = (SELECT [MemberId] FROM ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessProcess] WHERE [Label] = ''' + @BusinessProcess + ''')'
		IF @DebugBM & 2 > 0 SELECT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@internalvariable bigint out', @internalvariable = @BusinessProcess_MemberId out

		SET @SQLStatement = '
			SELECT @internalvariable = (SELECT [MemberId] FROM ' + @CallistoDatabase + '.[dbo].[S_DS_Scenario] WHERE [Label] = ''' + @Scenario + ''')'
		IF @DebugBM & 2 > 0 SELECT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@internalvariable bigint out', @internalvariable = @Scenario_MemberId out

		IF @DebugBM & 2 > 0 SELECT 
			[@CallistoDatabase] = @CallistoDatabase,
			[@DataClassID] = @DataClassID,
			[@DataClassName] = @DataClassName,
			[@BusinessProcess] = @BusinessProcess, 
			[@BusinessProcess_MemberId] = @BusinessProcess_MemberId, 
			[@Scenario] = @Scenario, 
			[@Scenario_MemberId] = @Scenario_MemberId

	SET @Step = 'SP-Specific check'
		IF @CallistoDatabase IS NULL
			BEGIN
				SET @InfoMessage = 'Callisto Database was not found.';
				THROW 51000, @InfoMessage, 2;
			END
		IF @BusinessProcess_MemberId IS NULL
			BEGIN
				SET @InfoMessage = 'Business Process for Sales was not found.';
				THROW 51000, @InfoMessage, 2;
			END
		IF @Scenario_MemberId IS NULL
			BEGIN
				SET @InfoMessage = 'Scenario ACTUAL was not found.';
				THROW 51000, @InfoMessage, 2;
			END

		IF @DataClassID IS NULL OR @DataClassName IS NULL
			BEGIN
				SET @InfoMessage = 'DataClass was not found.';
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
				SET @Message = 'No dimensions specified for selected DataClassID'
				SET @Severity = 0
				GOTO EXITPOINT
			END
	
	SET @Step = 'Create Temp Table #DC_SalesReport_Raw'

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

		IF @DebugBM & 2 > 0 SELECT [@TempTable_ObjectID] = @TempTable_ObjectID

	SET @Step = 'Fill Temp Table #DC_SalesReport_Raw by calling spIU_DC_SalesReport_Raw'

		SET @StepStartTime = GETDATE()

		SET @JSON = '
			[
			{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
			{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
			{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"}
			]'

		EXEC [pcINTEGRATOR].[dbo].[spRun_Procedure_KeyValuePair] @DatabaseName = @DatabaseName, @ProcedureName = 'spIU_DC_SalesReport_Raw', @JSON = @JSON

		SET @Selected = @Selected + (SELECT COUNT(1) FROM #DC_SalesReport_Raw)

		IF @DebugBM & 2 > 0 SELECT Step = '#DC_SalesReport_Raw', Duration = CONVERT(time(7), GetDate() - @StepStartTime), [Rows] = COUNT(1) FROM #DC_SalesReport_Raw
		IF @DebugBM & 8 > 0 SELECT TempTable = '#DC_SalesReport_Raw', * FROM #DC_SalesReport_Raw

	SET @Step = 'Delete existing rows'

		SET @SQLStatement = '
			DELETE
			FROM 
				' + @CallistoDatabase + '.[dbo].[FACT_SalesReport_default_partition]
			WHERE 1=1
				AND [BusinessProcess_MemberId] = ' + CONVERT(nvarchar(15), @BusinessProcess_MemberId) + '
				AND [Scenario_MemberId] = ' + CONVERT(nvarchar(15), @Scenario_MemberId) + ''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Insert new rows'

		SELECT
			@SQLInsertInto = @SQLInsertInto + CHAR(13) + CHAR(10) + CHAR(9) + '[' + CASE WHEN ColumnName = 'TimeDay_MemberId' THEN 'Time_MemberId' ELSE ColumnName END + '],',
			@SQLSelect = @SQLSelect + CHAR(13) + CHAR(10) + CHAR(9) + '[' + CASE WHEN ColumnName = 'TimeDay_MemberId' THEN 'Time_MemberId' ELSE ColumnName END + '] = SR.[' + ColumnName + '],'
		FROM #DataClassColumns
		
		SELECT
			@SQLInsertInto = LEFT(@SQLInsertInto, LEN(@SQLInsertInto) - 1),
			@SQLSelect = LEFT(@SQLSelect, LEN(@SQLSelect) - 1)

		IF @DebugBM & 2 > 0 SELECT [@SQLInsertInto] = @SQLInsertInto, [@SQLSelect] = @SQLSelect

		SET @SQLStatement = '
			INSERT INTO ' + @CallistoDatabase + '.[dbo].[FACT_SalesReport_default_partition]
				(
				' + @SQLInsertInto + ',
				[SalesReport_Value],
				[ChangeDatetime],
				[Userid]
				)
			SELECT
				' + @SQLSelect + ',
				[SalesReport_Value] = SR.[Sales_Value],
				[ChangeDatetime] = GetDate(),
				[Userid] = suser_name()
			FROM
				[#DC_SalesReport_Raw] SR
			'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Drop the temp tables'
		DROP TABLE #DC_SalesReport_Raw

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
