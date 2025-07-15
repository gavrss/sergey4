SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_DC_FxRate_CloseAverage]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@FiscalYear int = NULL,
	@Scenario nvarchar(50) = 'ACTUAL',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000867,
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
EXEC [spIU_DC_FxRate_CloseAverage] @UserID=-10, @InstanceID=580, @VersionID=1084, @DebugBM=3

EXEC [spIU_DC_FxRate_CloseAverage] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CloseAverage_MemberId bigint,
	@Scenario_MemberId bigint,
	@DataClass_StorageTypeBM int,
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@TimeFrom int,
	@TimeTo int,

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
	@Version nvarchar(50) = '2.1.2.2192'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Add rate CloseAverage to FACT_FxRate',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2192' SET @Description = 'Procedure created.'

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
			@DataClass_StorageTypeBM = StorageTypeBM
		FROM
			pcINTEGRATOR_Data..DataClass
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DataClassTypeID = -6

		SELECT
			@CallistoDatabase = '[' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		SET @SQLStatement = '
			SELECT
				 @InternalVariable = [MemberId]
			FROM
				' + @CallistoDatabase + '.[dbo].[S_DS_Rate]
			WHERE
				[Label] = ''CloseAverage'''

		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @CloseAverage_MemberId OUT

		SET @SQLStatement = '
			SELECT
				 @InternalVariable = [MemberId]
			FROM
				' + @CallistoDatabase + '.[dbo].[S_DS_Scenario]
			WHERE
				[Label] = ''' + @Scenario + ''''

		EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @Scenario_MemberId OUT

		IF @DebugBM & 2 > 0
			SELECT
				[@DataClass_StorageTypeBM] = @DataClass_StorageTypeBM,
				[@CallistoDatabase] = @CallistoDatabase,
				[@ETLDatabase] = @ETLDatabase,
				[@CloseAverage_MemberId] = @CloseAverage_MemberId,
				[@Scenario_MemberId] = @Scenario_MemberId

	SET @Step = '#YearMonth'
		CREATE TABLE #YearMonth
			(
			[FiscalYear] int,
			[YearMonth] int,
			[NumberofDays] int
			)

		SET @SQLStatement = '
			INSERT INTO #YearMonth
				(
				[FiscalYear],
				[YearMonth],
				[NumberofDays]
				)
			SELECT
				[FiscalYear] = [TimeFiscalYear_MemberID],
				[YearMonth] = [MemberId],
				[NumberofDays]
			FROM
				' + @CallistoDatabase + '.[dbo].[S_DS_Time]
			WHERE
				[TimeFiscalYear_MemberID] IS NOT NULL AND
				[Level] = ''Month'''
				+ CASE WHEN @FiscalYear IS NOT NULL THEN ' AND [TimeFiscalYear_MemberID] = ' + CONVERT(nvarchar(15), @FiscalYear) ELSE '' END

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT [TempTable] = '#YearMonth', * FROM #YearMonth ORDER BY [YearMonth]

		SELECT
			[FiscalYear],
			[TimeFrom] = MIN([YearMonth]),
			[TimeTo] = MAX([YearMonth])
		INTO
			#FiscalYear
		FROM
			#YearMonth
		GROUP BY
			[FiscalYear]

		IF @DebugBM & 2 > 0 SELECT TempTable = '#FiscalYear', * FROM #FiscalYear ORDER BY [FiscalYear]

	SET @Step = 'Insert into #Average'
		CREATE TABLE #Average
			(
			[BusinessRule_MemberId] bigint,
			[Currency_MemberId] bigint,
			[BaseCurrency_MemberId] bigint,
			[Scenario_MemberId] bigint,
			[Simulation_MemberId] bigint,
			[Entity_MemberId] bigint,
			[Time_MemberId] bigint,
			[FxRate_Value] float,
			[NumberOfDays] int,
			[Average] float
			)
	
		SET @SQLStatement = '
			INSERT INTO #Average
				(
				[BusinessRule_MemberId],
				[Currency_MemberId],
				[BaseCurrency_MemberId],
				[Scenario_MemberId],
				[Simulation_MemberId],
				[Entity_MemberId],
				[Time_MemberId],
				[FxRate_Value],
				[NumberOfDays],
				[Average]
				)
			SELECT
				[BusinessRule_MemberId] = DC.[BusinessRule_MemberId],
				[Currency_MemberId] = DC.[Currency_MemberId],
				[BaseCurrency_MemberId] = DC.[BaseCurrency_MemberId],
				[Scenario_MemberId] = DC.[Scenario_MemberId],
				[Simulation_MemberId] = DC.[Simulation_MemberId],
				[Entity_MemberId] = DC.[Entity_MemberId],
				[Time_MemberId] = DC.[Time_MemberId],
				[FxRate_Value] = DC.[FxRate_Value],
				[NumberOfDays] = YM.[NumberOfDays],
				[Average] = DC.[FxRate_Value] * YM.[NumberOfDays]
			FROM
				' + @CallistoDatabase + '.[dbo].[FACT_FxRate_default_partition] DC
				INNER JOIN #YearMonth YM ON YM.[YearMonth] = DC.[Time_MemberId]
			WHERE
				DC.[Rate_MemberId] = 101 AND
				DC.[Scenario_MemberId] = ' + CONVERT(nvarchar(15), @Scenario_MemberId)

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Average', * FROM #Average ORDER BY [Time_MemberId]

	SET @Step = 'Delete from FACT table'
		SET @SQLStatement = '
			DELETE DC
			FROM
				' + @CallistoDatabase + '.[dbo].[FACT_FxRate_default_partition] DC
				INNER JOIN #YearMonth YM ON YM.[YearMonth] = DC.[Time_MemberId]
			WHERE
				DC.[Rate_MemberId] = ' + CONVERT(nvarchar(15), @CloseAverage_MemberId)

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Insert into FACT table'
		SET @SQLStatement = '
			INSERT INTO ' + @CallistoDatabase + '.[dbo].[FACT_FxRate_default_partition]
				(
				[BusinessRule_MemberId],
				[Currency_MemberId],
				[BaseCurrency_MemberId],
				[Rate_MemberId],
				[Scenario_MemberId],
				[Simulation_MemberId],
				[Entity_MemberId],
				[Time_MemberId],
				[FxRate_Value],
				[ChangeDatetime],
				[Userid]
				)
			SELECT
				[BusinessRule_MemberId],
				[Currency_MemberId],
				[BaseCurrency_MemberId],
				[Rate_MemberId] = ' + CONVERT(nvarchar(15), @CloseAverage_MemberId) + ',
				[Scenario_MemberId],
				[Simulation_MemberId],
				[Entity_MemberId],
				[Time] = YM.YearMonth,
				[FxRate_Value] = SUM(CASE WHEN YM.[YearMonth] >= A.[Time_MemberId] THEN A.[Average] ELSE 0 END) / SUM(CASE WHEN YM.[YearMonth] >= A.[Time_MemberId] THEN A.[NumberOfDays] ELSE 0 END),
				[ChangeDatetime] = GetDate(),
				[Userid] = ''' + @UserName + '''
			FROM
				#Average A
				INNER JOIN #FiscalYear FY ON A.[Time_MemberId] BETWEEN FY.[TimeFrom] AND FY.[TimeTo]
				INNER JOIN #YearMonth YM ON YM.[FiscalYear] = FY.[FiscalYear]
			GROUP BY
				A.[BusinessRule_MemberId],
				A.[Currency_MemberId],
				A.[BaseCurrency_MemberId],
				A.[Scenario_MemberId],
				A.[Simulation_MemberId],
				A.[Entity_MemberId],
				YM.[YearMonth]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Return Rows'
		IF @DebugBM & 1 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT
						[View] = ''' + @CallistoDatabase + '.[dbo].[FACT_FxRate_View]'',
						*
					FROM
						' + @CallistoDatabase + '.[dbo].[FACT_FxRate_View]
					WHERE
						[Rate] = ''CloseAverage''
					ORDER BY
						[Scenario],
						[BaseCurrency],
						[Time],
						[Currency]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
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
