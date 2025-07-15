SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_AccountPayable_Callisto]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL,
	@StartYear int = NULL,
	@StartDay int = NULL,
	@Entity nvarchar(50) = NULL,
	@FullReloadYN bit = 0,
	@SpeedRunYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN BIT = 1,
	@AuthenticatedUserID INT = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000737,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_DC_AccountPayable_Callisto] @UserID=-10, @InstanceID=817, @VersionID=1236, @DebugBM=31

EXEC [spIU_DC_AccountPayable_Callisto] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@LinkedYN bit,
	@SourceDatabase nvarchar(100) = NULL,
	@CallistoDatabase nvarchar(100) = NULL,
	@StorageTypeBM int, --1 = Internal, 2 = Table, 4 = Callisto
	@JSON nvarchar(max),
	@CalledYN bit = 1,
	@Owner nvarchar(10),
	@SQLStatement nvarchar(max),
	@SourceID int,
	@SourceTypeID int,
	@SourceTypeName nvarchar(50),
	@MasterClosedYear int,
	@StartDate date,
	@DataClassName nvarchar(50),	

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
			@ProcedureDescription = 'Insert new rows into Callisto AccountPayable FACT table',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2163' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2199' SET @Description = 'Updated sp template.'

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

		SET @StartDate = CONVERT(date, CONVERT(nvarchar(15), @StartDay), 112)
		
		SELECT
			@DataClassID = ISNULL(@DataClassID, MAX(DC.DataClassID)),
			@DataClassName = MAX(DC.DataClassName),
			@StorageTypeBM = MAX(StorageTypeBM)
		FROM
			[pcINTEGRATOR_Data].[dbo].[DataClass] DC
		WHERE
			DC.InstanceID = @InstanceID AND
			DC.VersionID = @VersionID AND
			DC.DataClassTypeID = -1 AND
			DC.ModelBM = 1024 AND
			(DC.DataClassID = @DataClassID OR @DataClassID IS NULL) AND
			DC.SelectYN <> 0 AND
			DC.DeletedID IS NULL

		SELECT
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(ISNULL(@CallistoDatabase, A.DestinationDatabase), '[', ''), ']', ''), '.', '].[') + ']',
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(ISNULL(@SourceDatabase, S.SourceDatabase), '[', ''), ']', ''), '.', '].[') + ']',
			@Owner = ST.[Owner],
			@StartYear = ISNULL(@StartYear, S.StartYear),
			@SourceID = S.[SourceID],
			@SourceTypeID = S.[SourceTypeID],
			@SourceTypeName = ST.[SourceTypeName]
		FROM
			[pcINTEGRATOR_Data].[dbo].[Application] A
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Model] M ON M.ApplicationID = A.ApplicationID AND M.ModelBM = 1024 AND M.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR].[dbo].SourceType ST ON ST.SourceTypeID = S.SourceTypeID --AND ST.SourceTypeFamilyID = 1
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		EXEC [pcINTEGRATOR].[dbo].[spGet_MasterClosedYear]
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@MasterClosedYear = @MasterClosedYear OUT,
			@JobID = @JobID

		IF @MasterClosedYear >= @StartYear SET @StartYear = @MasterClosedYear + 1
		
		IF @DebugBM & 2 > 0 
			SELECT
				[@SourceDatabase] = @SourceDatabase,
				[@CallistoDatabase] = @CallistoDatabase,
				[@Owner] = @Owner,
				[@StartYear] = @StartYear,
				[@StartDate] = @StartDate,
				[@MasterClosedYear] = @MasterClosedYear,
				[@SourceID] = @SourceID,
				[@SourceTypeID] = @SourceTypeID,
				[@SourceTypeName] = @SourceTypeName,
				[@DataClassID] = @DataClassID,
				[@DataClassName] = @DataClassName

	SET @Step = 'Handle ANSI_WARNINGS'
		EXEC [pcINTEGRATOR].[dbo].[spGet_Linked] @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = 'Create temp table'
		CREATE TABLE #DC_AccountPayable
		(
			[Account] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Aging_AP] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[BusinessProcess] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[BusinessRule] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Currency] nchar(3) COLLATE DATABASE_DEFAULT,
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[InvoiceNo_AP] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[Scenario] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Supplier] nvarchar(50) COLLATE DATABASE_DEFAULT, 
			[TimeDataView] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[TimeDay] int,
			[AccountPayable_Value] float DEFAULT 0.0
		)

	SET @Step = 'Insert into temp table'
		EXEC [pcINTEGRATOR].[dbo].[spIU_DC_AccountPayable_Raw] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID=@DataClassID, @JobID=@JobID, @Debug=@DebugSub

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DC_AccountPayable', * FROM #DC_AccountPayable ORDER BY [Entity], [Account], [TimeDay]
		
	SET @Step = 'Create #FACT_Update'
		CREATE TABLE #FACT_Update
			(
			[BusinessProcess_MemberId] bigint,
			[Entity_MemberId] bigint,
			[Scenario_MemberId] bigint,
			[TimeDay_MemberId] bigint,
			)

		SET @SQLStatement = '
			INSERT INTO	#FACT_Update
				(
				[BusinessProcess_MemberId],
				[Entity_MemberId],
				[Scenario_MemberId],
				[TimeDay_MemberId]
				)
			SELECT DISTINCT
				[BusinessProcess_MemberId] = [BusinessProcess].[MemberId],
				[Entity_MemberId] = [Entity].[MemberId],
				[Scenario_MemberId] = [Scenario].[MemberId],
				[TimeDay_MemberId] = [TimeDay].[MemberId]
			FROM
				[#DC_AccountPayable] [Raw]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessProcess] [BusinessProcess] ON [BusinessProcess].[Label] COLLATE DATABASE_DEFAULT = [Raw].[BusinessProcess]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Entity] [Entity] ON [Entity].[Label] COLLATE DATABASE_DEFAULT = [Raw].[Entity]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Scenario] [Scenario] ON [Scenario].[Label] COLLATE DATABASE_DEFAULT = [Raw].[Scenario]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_TimeDay] [TimeDay] ON [TimeDay].[Label] COLLATE DATABASE_DEFAULT = [Raw].[TimeDay] AND [TimeDay].[Level] = ''Day'''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 8 > 0 SELECT TempTable = '#FACT_Update', * FROM #FACT_Update

	SET @Step = 'Set all existing rows that should be inserted to 0'
		SET @SQLStatement = '
			UPDATE
				F
			SET
				[AccountPayable_Value] = 0
			FROM
				' + @CallistoDatabase + '.[dbo].[FACT_AccountPayable_default_partition] F
				INNER JOIN [#FACT_Update] V ON
							V.[BusinessProcess_MemberId] = F.[BusinessProcess_MemberId] AND
							V.[Entity_MemberId] = F.[Entity_MemberId] AND
							V.[Scenario_MemberId] = F.[Scenario_MemberId] AND
							V.[TimeDay_MemberId] = F.[TimeDay_MemberId]' 

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Insert new rows'
		SET @SQLStatement = '
			INSERT INTO ' + @CallistoDatabase + '.[dbo].[FACT_AccountPayable_default_partition]
				(
				[Account_MemberId],
				[Aging_AP_MemberId],
				[BusinessProcess_MemberId],
				[BusinessRule_MemberId],
				[Currency_MemberId],
				[Entity_MemberId],
				[InvoiceNo_AP_MemberId],
				[Scenario_MemberId],
				[Supplier_MemberId],
				[TimeDataView_MemberId],
				[TimeDay_MemberId],
				[ChangeDatetime],
				[Userid],
				[AccountPayable_Value]
				)
			SELECT
				[Account_MemberId] = ISNULL([Account].[MemberId], -1),
				[Aging_AP_MemberId] = ISNULL([Aging_AP].[MemberId], -1),
				[BusinessProcess_MemberId] = ISNULL([BusinessProcess].[MemberId], -1),
				[BusinessRule_MemberId] = ISNULL([BusinessRule].[MemberId], -1),
				[Currency_MemberId] = ISNULL([Currency].[MemberId], -1),
				[Entity_MemberId] = ISNULL([Entity].[MemberId], -1),
				[InvoiceNo_AP_MemberId] = ISNULL([InvoiceNo_AP].[MemberId], -1),
				[Scenario_MemberId] = ISNULL([Scenario].[MemberId], -1),
				[Supplier_MemberId] = ISNULL([Supplier].[MemberId], -1),
				[TimeDataView_MemberId] = ISNULL([TimeDataView].[MemberId], -1),
				[TimeDay_MemberId] = ISNULL([TimeDay].[MemberId], -1),
				[ChangeDatetime] = GetDate(),
				[Userid] = suser_name(),
				[AccountPayable_Value]
			FROM
				[#DC_AccountPayable] [Raw]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Account] [Account] ON [Account].[Label] COLLATE DATABASE_DEFAULT = [Raw].[Account]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Aging_AP] [Aging_AP] ON [Aging_AP].[Label] COLLATE DATABASE_DEFAULT = [Raw].[Aging_AP]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessProcess] [BusinessProcess] ON [BusinessProcess].[Label] COLLATE DATABASE_DEFAULT = [Raw].[BusinessProcess]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_BusinessRule] [BusinessRule] ON [BusinessRule].[Label] COLLATE DATABASE_DEFAULT = [Raw].[BusinessRule]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Currency] [Currency] ON [Currency].[Label] COLLATE DATABASE_DEFAULT = [Raw].[Currency]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Entity] [Entity] ON [Entity].[Label] COLLATE DATABASE_DEFAULT = [Raw].[Entity]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_InvoiceNo_AP] [InvoiceNo_AP] ON [InvoiceNo_AP].[Label] COLLATE DATABASE_DEFAULT = [Raw].[InvoiceNo_AP]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Scenario] [Scenario] ON [Scenario].[Label] COLLATE DATABASE_DEFAULT = [Raw].[Scenario]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_Supplier] [Supplier] ON [Supplier].[Label] COLLATE DATABASE_DEFAULT = [Raw].[Supplier]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_TimeDataView] [TimeDataView] ON [TimeDataView].[Label] COLLATE DATABASE_DEFAULT = [Raw].[TimeDataView]
				LEFT JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_TimeDay] [TimeDay] ON [TimeDay].[Label] COLLATE DATABASE_DEFAULT = [Raw].[TimeDay] AND [TimeDay].[Level] = ''Day'''
		
		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Run selected BusinessRules'
		EXEC [pcINTEGRATOR].[dbo].[spBR_BR04] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DataClassID = @DataClassID, @MultiplyYN = 0, @Debug = @DebugSub

	SET @Step = 'Clean up'
		IF (SELECT DATEPART(WEEKDAY, GETDATE())) IN (6, 7) OR @SpeedRunYN = 0 --Saturday, Sunday or not SpeedRun
			BEGIN
				SET @SQLStatement = '
					DELETE
						F
					FROM
						' + @CallistoDatabase + '.[dbo].[FACT_AccountPayable_default_partition] F
					WHERE
						[AccountPayable_Value] = 0'				

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
		
				SET @Deleted = @Deleted + @@ROWCOUNT
			END

	SET @Step = 'Drop the temp table'
		DROP TABLE #DC_AccountPayable
		DROP TABLE #FACT_Update	

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
