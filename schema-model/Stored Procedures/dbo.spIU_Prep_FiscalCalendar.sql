SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Prep_FiscalCalendar]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000804,
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
EXEC [spIU_Prep_FiscalCalendar] @UserID=-10, @InstanceID=531, @VersionID=1057, @SourceID=1199, @DebugBM=3
EXEC [spIU_Prep_FiscalCalendar] @UserID=-10, @InstanceID=531, @VersionID=1057, @DebugBM=3
EXEC [spIU_Prep_FiscalCalendar] @UserID=-10, @InstanceID=413, @VersionID=1008, @DebugBM=3
EXEC [spIU_Prep_FiscalCalendar] @UserID=-10, @InstanceID=454, @VersionID=1021, @DebugBM=3

EXEC [spIU_Prep_FiscalCalendar] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceTypeID int,
	@SourceDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@ETLDatabase nvarchar(100),
	@TableName nvarchar(100),

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
	@Version nvarchar(50) = '2.1.2.2176'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create and update table [FiscalCalendar] in the ETL DB.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2176' SET @Description = 'Procedure created. DB-696 Create SP for preparing FiscalCalendar in pcETL DB (generic).'

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
			@ETLDatabase = [ETLDatabase]
		FROM
			pcINTEGRATOR_Data.[dbo].[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0

		SET @TableName = @ETLDatabase + '.dbo.FiscalCalendar'

		IF @DebugBM & 2 > 0
			SELECT
				[@ETLDatabase] = @ETLDatabase,
				[@TableName] = @TableName

	SET @Step = 'Create table, [FiscalCalendar]'
		IF OBJECT_ID(@TableName, N'U') IS NULL
			BEGIN
				SET @SQLStatement = '
					CREATE TABLE [dbo].[FiscalCalendar](
						[Entity] [nvarchar](50) NOT NULL,
						[Book] [nvarchar](50) NOT NULL,
						[FiscalYear] [int] NOT NULL,
						[FiscalPeriod] [int] NOT NULL,
						[YearMonth] [int] NOT NULL,
						[StartDate] [date] NOT NULL,
						[EndDate] [date] NOT NULL,
						[CloseFiscalPeriodYN] [bit] NOT NULL DEFAULT 0,
						[ClosedPeriodYN] [bit] NOT NULL DEFAULT 0,
						[Inserted] [datetime] NOT NULL DEFAULT getdate(),
						[InsertedBy] [nvarchar](100) NOT NULL DEFAULT suser_name(),
					 CONSTRAINT [PK_FiscalCalendar] PRIMARY KEY CLUSTERED 
					(
						[Entity] ASC,
						[Book] ASC,
						[FiscalYear] ASC,
						[FiscalPeriod] ASC
					)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
					) ON [PRIMARY]'

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Create temp tables'
		CREATE TABLE #EntityBook
			(
			[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Book] nvarchar(50) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Calendar_Cursor'
		IF CURSOR_STATUS('global','Calendar_Cursor') >= -1 DEALLOCATE Calendar_Cursor
		DECLARE Calendar_Cursor CURSOR FOR
			
			SELECT DISTINCT
				[SourceTypeID] = S.[SourceTypeID],
				[SourceID] = S.[SourceID],
				[SourceDatabase] = '[' + REPLACE(REPLACE(REPLACE(S.[SourceDatabase], '[', ''), ']', ''), '.', '].[') + ']'
			FROM
				[pcINTEGRATOR_Data].[dbo].[Source] S
				INNER JOIN [pcINTEGRATOR_Data].[dbo].[Model] M ON M.[InstanceID] = S.[InstanceID] AND M.[VersionID] = S.[VersionID] AND M.[ModelID] = S.[ModelID] AND M.[ModelBM] & 64 > 0
			WHERE
				S.[InstanceID] = @InstanceID AND
				S.[VersionID] = @VersionID AND
				(S.[SourceID] = @SourceID OR @SourceID IS NULL)

			OPEN Calendar_Cursor
			FETCH NEXT FROM Calendar_Cursor INTO @SourceTypeID, @SourceID, @SourceDatabase

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@SourceTypeID] = @SourceTypeID, [@SourceID] = @SourceID, [@SourceDatabase] = @SourceDatabase

					TRUNCATE TABLE #EntityBook

					INSERT INTO #EntityBook
						(
						[Entity],
						[Book]
						)
					SELECT 
						[Entity] = E.[MemberKey],
						[Book] = EB.[Book]
					FROM
						pcINTEGRATOR_Data.dbo.Entity E 
						INNER JOIN pcINTEGRATOR_Data.dbo.Entity_Book EB ON EB.[InstanceID] = E.[InstanceID] AND EB.[VersionID] = E.[VersionID] AND EB.[EntityID] = E.[EntityID] AND EB.[BookTypeBM] & 1 > 0 AND EB.[SelectYN] <> 0
					WHERE
						E.[InstanceID] = @InstanceID AND
						E.[VersionID] = @VersionID AND
						E.[SourceID] = @SourceID AND
						E.[EntityTypeID] = -1 AND
						E.[SelectYN] <> 0 AND
						E.[DeletedID] IS NULL

					IF @DebugBM & 2 > 0 SELECT [TempTable] = '#EntityBook', * FROM #EntityBook ORDER BY [Entity], [Book]
	
					IF @SourceTypeID = 11
						BEGIN
							SET @SQLStatement = '
								INSERT INTO [' + @ETLDatabase + '].[dbo].[FiscalCalendar]
									(
									[Entity],
									[Book],
									[FiscalYear],
									[FiscalPeriod],
									[YearMonth],
									[StartDate],
									[EndDate],
									[CloseFiscalPeriodYN],
									[ClosedPeriodYN]
									)
								SELECT 
									[Entity] = sub.[Entity],
									[Book] = sub.[Book],
									[FiscalYear] = sub.[FiscalYear],
									[FiscalPeriod] = sub.[FiscalPeriod],
									[YearMonth] = YEAR(sub.[MidDate]) * 100 + MONTH(sub.[MidDate]),
									[StartDate] = sub.[StartDate],
									[EndDate] = sub.[EndDate],
									[CloseFiscalPeriodYN] = sub.[CloseFiscalPeriodYN],
									[ClosedPeriodYN] = sub.[ClosedPeriodYN]
								FROM 
									(
									SELECT 
										[Entity] = EB.[Entity],
										[Book] = EB.[Book],
										[FiscalYear] = GLBP.[FiscalYear],
										[FiscalPeriod] = GLBP.[FiscalPeriod],
										[MidDate] = CONVERT(datetime, (CONVERT(int, CONVERT(datetime, [StartDate])) + CONVERT(int, CONVERT(datetime, [EndDate]))) / 2),
										[StartDate] = GLBP.[StartDate],
										[EndDate] = GLBP.[EndDate],
										[CloseFiscalPeriodYN] = CASE WHEN GLBP.[CloseFiscalPeriod] = 0 THEN 0 ELSE 1 END,
										[ClosedPeriodYN] = GLBP.[ClosedPeriod]
									FROM 
										' + @SourceDatabase + '.[Erp].[GLBookPer] GLBP
										INNER JOIN #EntityBook EB ON EB.[Entity] = GLBP.[Company] AND EB.[Book] = GLBP.[BookID]
									) sub
								WHERE
									NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[FiscalCalendar] FC WHERE FC.[Entity] = sub.[Entity] AND FC.[Book] = sub.[Book] AND FC.[FiscalYear] = sub.[FiscalYear] AND FC.[FiscalPeriod] = sub.[FiscalPeriod])'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
						END

					FETCH NEXT FROM Calendar_Cursor INTO @SourceTypeID, @SourceID, @SourceDatabase
				END

		CLOSE Calendar_Cursor
		DEALLOCATE Calendar_Cursor

	SET @Step = 'Add rows for Opening Fiscal Periods'
		SET @SQLStatement = '
			INSERT INTO [' + @ETLDatabase + '].[dbo].[FiscalCalendar]
				(
				[Entity],
				[Book],
				[FiscalYear],
				[FiscalPeriod],
				[YearMonth],
				[StartDate],
				[EndDate],
				[CloseFiscalPeriodYN],
				[ClosedPeriodYN]
				)
			SELECT 
				[Entity] = FC.[Entity],
				[Book] = FC.[Book],
				[FiscalYear] = FC.[FiscalYear],
				[FiscalPeriod] = 0,
				[YearMonth] = FC.[YearMonth],
				[StartDate] = DATEFROMPARTS (FC.[YearMonth] / 100, FC.[YearMonth] % 100, 1),
				[EndDate] = DATEFROMPARTS (FC.[YearMonth] / 100, FC.[YearMonth] % 100, 1),
				[CloseFiscalPeriodYN] = 0,
				[ClosedPeriodYN] = FC.[ClosedPeriodYN]
			FROM
				[' + @ETLDatabase + '].[dbo].[FiscalCalendar] FC
			WHERE
				[FiscalPeriod] = 1 AND
				NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[FiscalCalendar] DFC WHERE DFC.[Entity] = FC.[Entity] AND DFC.[Book] = FC.[Book] AND DFC.[FiscalYear] = FC.[FiscalYear] AND DFC.[FiscalPeriod] = 0)'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Return rows'
		IF @DebugBM & 1 > 0
			BEGIN
				SET @SQLStatement = '
					SELECT
						*
					FROM
						[' + @ETLDatabase + '].[dbo].[FiscalCalendar]
					ORDER BY
						[Entity],
						[Book],
						[FiscalYear],
						[FiscalPeriod]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = 'Drop Temp tables'
		DROP TABLE #EntityBook

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
