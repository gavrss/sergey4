SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_SampleCode]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000413,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'sp_Tool_SampleCode',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [sp_Tool_SampleCode] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [sp_Tool_SampleCode] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@Par1 int,
	@Par2 int,

	@Sample nvarchar(255),
	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2162'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Template for sample code references.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2144' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2161' SET @Description = 'Added sample code for getting the variable out of dynamic SQL executed at a Linked Server .'
		IF @Version = '2.1.0.2162' SET @Description = 'Added Get multiple variables out of dynamic SQL.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Sample = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

	SET @Sample = 'SP-Specific check'
		IF @InstanceID <> @VersionID
			BEGIN
				SET @Message = 'This is just an example.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Sample = 'Sample Cursor'
		DECLARE Sample_Cursor CURSOR FOR
			
			SELECT 
				Par1 = 1,
				Par2 = 2

			OPEN Sample_Cursor
			FETCH NEXT FROM Sample_Cursor INTO @Par1, @Par2

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT Par1 = @Par1, Par2 = @Par2

					FETCH NEXT FROM Sample_Cursor INTO @Par1, @Par2
				END

		CLOSE Sample_Cursor
		DEALLOCATE Sample_Cursor


	SET @Sample = 'Get first Day and Last Day of YearMonth'
	/**
	SELECT
			@FromDate = CONVERT(NVARCHAR(15), @YearMonth/100) + '-' + CONVERT(NVARCHAR(15), @YearMonth%100) + '-01',
			@ToDate = DATEADD(DAY, -1, DATEADD(MONTH, 1, CONVERT(NVARCHAR(15), @YearMonth/100) + '-' + CONVERT(NVARCHAR(15), @YearMonth%100) + '-01'))

	*/

	SET @Sample = 'Get the variable out of dynamic SQL.'
	/**
	DECLARE
		@SQLStatement NVARCHAR(MAX),
		@ReturnVariable NVARCHAR(100)

	SET @SQLStatement = '
	SELECT @InternalVariable = LEFT(ApplicationName, 5) FROM [DSPTEST01].pcINTEGRATOR_Data.dbo.[Application] WHERE InstanceID = -1039 AND VersionID = -1039'

	EXEC sp_executesql @SQLStatement, N'@internalVariable nvarchar(100) OUT', @internalVariable = @ReturnVariable OUT

	SELECT [@ReturnVariable] = @ReturnVariable
	*/

	SET @Sample = 'Get multiple variables out of dynamic SQL.'
	/**
		SET @SQLStatement = 'SELECT @InternalVariable1 = MAX([PostedDate]), @InternalVariable2 = MAX([SourceCounter]) FROM ' + @JournalTable + ' WHERE [InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + 'AND [Scenario] = ''ACTUAL'' AND [Source] = ''' + @SourceTypeName + ''''
		IF @MasterClosedYearMonth IS NOT NULL SET @SQLStatement = @SQLStatement + ' AND [YearMonth] > ' + CONVERT(nvarchar(15), @MasterClosedYearMonth)
		EXEC sp_executesql @SQLStatement, N'@InternalVariable1 date OUT, @InternalVariable2 bigint OUT', @InternalVariable1 = @MaxPostedDate OUT, @InternalVariable2 = @MaxSourceCounter OUT
	*/

	SET @Sample = 'Get the variable out of dynamic SQL - executing at a Linked Server.'
	/**
	DECLARE		
		@LinkedServer nvarchar(100),
		@SourceDatabase_Local nvarchar(100),
		@SQLStatement NVARCHAR(MAX),
		@ReturnVariable NVARCHAR(100)

	SET @SQLStatement = '
		DECLARE @ReturnVar INT
		EXEC ' + @LinkedServer + '.[Master].dbo.sp_executesql N''SELECT @InternalVar = DB_ID(''''' + @SourceDatabase_Local + ''''')'', N''@InternalVar int OUT'', @InternalVar = @ReturnVar OUT
		SELECT @InternalVariable = @ReturnVar'

	IF @DebugBM & 2 > 0 PRINT @SQLStatement

	EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @ReturnVariable OUT
	IF @DebugBM & 2 > 0 SELECT [@ReturnVariable] = @ReturnVariable

	IF (@ReturnVariable) IS NULL 
		GOTO STATICPOINT
	*/

	SET @Sample = 'ON ERROR RESUME NEXT.'
	/*
		SELECT @StepNo = 1, @RetryYN = 1
		WHILE (@RetryYN <> 0)
		BEGIN
			BEGIN TRY
				IF @StepNo = 1 
					BEGIN                 
						SET @SQLStatement = '
							INSERT INTO #Version ([ProcedureID], [ProcedureName], [ProcedureDescription], [Version], [VersionDescription], [CreatedBy], [ModifiedBy]) EXEC pcINTEGRATOR..' + @ProcName + ' @GetVersion = 1'
						EXEC (@SQLStatement)
						SET @RetryYN = 0
					END
				ELSE IF @StepNo = 2
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #Version ([Version], [VersionDescription], [ProcedureID]) EXEC pcINTEGRATOR..' + @ProcName + ' @GetVersion = 1'
						EXEC (@SQLStatement)
						SET @RetryYN = 0
					END
				ELSE IF @StepNo = 3
					BEGIN                 
						SET @SQLStatement = '
							INSERT INTO #Version ([ProcedureID], [ProcedureName], [ProcedureDescription], [Version], [VersionDescription]) EXEC pcINTEGRATOR..' + @ProcName + ' @GetVersion = 1'
						EXEC (@SQLStatement)
						SET @RetryYN = 0
					END
				ELSE IF @StepNo = 4
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #Version ([Version], [VersionDescription]) EXEC pcINTEGRATOR..' + @ProcName + ' @GetVersion = 1'
						EXEC (@SQLStatement)
						SET @RetryYN = 0
					END
				ELSE IF @StepNo = 5
					BEGIN
						SELECT [@ProcName] = @ProcName
						SET @SQLStatement = '
							EXEC pcINTEGRATOR..' + @ProcName + ' @GetVersion = 1'
						EXEC (@SQLStatement)
						SET @RetryYN = 0
					END
				ELSE
					SET @RetryYN = 0
			END TRY 

			BEGIN CATCH
				IF @Debug <> 0 SELECT [@StepNo] = @StepNo, [@ErrorNumber] = ERROR_NUMBER(), [@ErrorSeverity] = ERROR_SEVERITY(), [@ErrorState] = ERROR_STATE(), [@ErrorProcedure] = ERROR_PROCEDURE(), [@ErrorLine] = ERROR_LINE(), [@ErrorMessage] = ERROR_MESSAGE()
				SET @StepNo = @StepNo + 1
			END CATCH 
		END 
	*/

	SET @Sample = 'Handle database name, default column name and reseed Counter'
	/*
		DECLARE
			@SQLStatement nvarchar(MAX),
			@DatabaseName nvarchar(100) = 'pcINTEGRATOR_Data',
			@TableName nvarchar(100) = 'Model',
			@ColumnName nvarchar(100) = NULL,
			@ReturnVariable int,
            @Debug bit = 1

		SELECT
			@DatabaseName = '[' + REPLACE(REPLACE(REPLACE(@DatabaseName, '[', ''), ']', ''), '.', '].[') + ']',
			@TableName = '[' + REPLACE(REPLACE(@TableName, '[', ''), ']', '') + ']',
			@ColumnName = ISNULL(@ColumnName, '[' + REPLACE(REPLACE(@TableName, '[', ''), ']', '') + 'ID]')

		--Dynamic
		SET @SQLStatement = '
			SELECT @InternalVariable = MAX(' + @ColumnName + ') FROM ' + @DatabaseName + '.[dbo].' + @TableName
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @ReturnVariable OUT

		SET @SQLStatement = '
			EXEC ' + @DatabaseName + '.[dbo].[sp_executesql] N''DBCC CHECKIDENT (' + @TableName + ', RESEED, ' + CONVERT(nvarchar, @ReturnVariable) + ')'''
		IF @Debug <> 0 PRINT @SQLStatement
		EXECUTE (@SQLStatement)

		--Static
		SELECT @ReturnVariable = MAX(ModelID) FROM [pcINTEGRATOR_Data].[dbo].[Model]
		DBCC CHECKIDENT ([Model], RESEED, @ReturnVariable)
	*/

	SET @Sample = 'Recreate time dimensions after changing setup (FiscalYearStartMonth)'
/*
		SELECT 
			'TRUNCATE TABLE [' + db_name() + '].[dbo].[' + [name] + ']'
		FROM
			sys.tables
		WHERE
			([name] LIKE 'S_DS_%' OR [name] LIKE 'S_HS_%') AND 
			[name] LIKE '%Time%' AND 
			[name] NOT LIKE '%TimeDataView%'

		--Created by query above
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_DS_Time]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_DS_TimeFiscalPeriod]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_DS_TimeFiscalQuarter]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_DS_TimeFiscalSemester]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_DS_TimeFiscalTertial]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_DS_TimeFiscalYear]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_DS_TimeMonth]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_DS_TimeQuarter]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_DS_TimeSemester]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_DS_TimeTertial]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_DS_TimeYear]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_HS_Time_Time]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_HS_TimeFiscalPeriod_TimeFiscalPeriod]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_HS_TimeFiscalQuarter_TimeFiscalQuarter]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_HS_TimeFiscalSemester_TimeFiscalSemester]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_HS_TimeFiscalTertial_TimeFiscalTertial]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_HS_TimeFiscalYear_TimeFiscalYear]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_HS_TimeMonth_TimeMonth]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_HS_TimeQuarter_TimeQuarter]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_HS_TimeSemester_TimeSemester]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_HS_TimeTertial_TimeTertial]
		TRUNCATE TABLE [pcDATA_UPML].[dbo].[S_HS_TimeYear_TimeYear]

		EXEC pcINTEGRATOR.dbo.spIU_Time_Property @UserID = -10, @InstanceID = -1053, @VersionID = -1052
		EXEC pcINTEGRATOR.dbo.spIU_Time @UserID = -10, @InstanceID = -1053, @VersionID = -1052
*/

	SET @Sample = 'Handle known cases and throw specific "error" number'
/*	
        drop table if exists #TestRethrow;
        CREATE TABLE #TestRethrow
        (    ID INT PRIMARY KEY
        );
        begin try
            INSERT #TestRethrow(ID) VALUES(1);
        --  Force error 2627, Violation of PRIMARY KEY constraint to be raised.
            INSERT #TestRethrow(ID) VALUES(1);
        end try
        begin catch
            if ERROR_NUMBER() = 2627
                    THROW 51000, @ErrorMessage, 1;
        end catch
*/
            
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
