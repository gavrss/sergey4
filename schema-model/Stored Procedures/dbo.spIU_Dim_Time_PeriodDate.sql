SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Time_PeriodDate]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Owner nvarchar(10) = NULL,
	@SourceDatabase nvarchar(100) = NULL,
	@SourceTypeID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000708,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spIU_Dim_Time_PeriodDate] @UserID=-10, @InstanceID=478, @VersionID=1032, @Debug=1
EXEC [spIU_Dim_Time_PeriodDate] @Owner = 'dbo', @SourceDatabase = '[DSPSOURCE02].[SakerEnterprises]', @SourceTypeID = 12, @Debug=1

EXEC [spIU_Dim_Time_PeriodDate] @GetVersion = 1
*/

SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@Entity nvarchar(50),
	@Book nvarchar(50),
	@FiscalCalendarID nvarchar(50),
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),

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
	@Version nvarchar(50) = '2.1.1.2178'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get PeriodPeriodStartDate and PeriodEndDate for specified FiscalPeriods.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2162' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2178' SET @Description = 'Selection of source database adjusted for Enterprise.'

		EXEC [spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		EXEC [spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@SourceDatabase = ISNULL(@SourceDatabase, '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']'),
			@Owner = COALESCE(@Owner, ST.[Owner], 'dbo'),
			@SourceTypeID = ISNULL(@SourceTypeID, S.[SourceTypeID])
		FROM
			[Application] A
			INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		IF @DebugBM & 2 > 0
			SELECT
				[@SourceDatabase] = @SourceDatabase,
				[@Owner] = @Owner,
				[@SourceTypeID] = @SourceTypeID

	SET @Step = 'Create temp table #Month'
		IF OBJECT_ID(N'TempDB.dbo.#Month', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #Month
					(
					[FiscalYear] int,
					[FiscalPeriod] int,
					[YearMonth] int,
					[MidDate] date, 
					[PeriodStartDate] date,
					[PeriodEndDate] date,
					[NumberOfDays] int
					)
			END

	SET @Step = 'Fill temp table #Month'
		IF @SourceTypeID IN (1, 11) --Epicor ERP
			BEGIN
				SELECT TOP 1 
					@Entity = E.MemberKey,
					@Book = EB.Book
				FROM
					pcINTEGRATOR_Data..Entity E
					INNER JOIN pcINTEGRATOR_Data..Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.VersionID = E.VersionID AND EB.EntityID = E.EntityID AND EB.BookTypeBM & 1 > 0 AND EB.BookTypeBM & 2 > 0 AND EB.SelectYN <> 0
				WHERE
					E.InstanceID = @InstanceID AND 
					E.VersionID = @VersionID AND
					E.EntityTypeID = -1 AND
					E.SelectYN <> 0 AND
					E.DeletedID IS NULL
				ORDER BY
					ISNULL([Priority], 99999999),
					MemberKey

				SET @SQLStatement = '
					SELECT @InternalVariable = FiscalCalendarID FROM ' + @SourceDatabase + '.[' + @Owner + '].[GLBook] WHERE Company = ''' + @Entity + ''' AND BookID = ''' + @Book + ''''

				EXEC sp_executesql @SQLStatement, N'@InternalVariable nvarchar(50) OUT', @InternalVariable = @FiscalCalendarID OUT

				IF @DebugBM & 2 > 0
					SELECT
						[@Entity] = @Entity,
						[@Book] = @Book,
						[@FiscalCalendarID] = @FiscalCalendarID

				SET @SQLStatement = '
					INSERT INTO #Month
						(
						[FiscalYear],
						[FiscalPeriod],
						[YearMonth],
						[MidDate], 
						[PeriodStartDate],
						[PeriodEndDate],
						[NumberOfDays]
						)
					SELECT
						[FiscalYear],
						[FiscalPeriod],
						[YearMonth] = CONVERT(int, CONVERT(nvarchar(6), [MidDate], 112)),
						[MidDate], 
						[PeriodStartDate],
						[PeriodEndDate],
						[NumberOfDays] = DATEDIFF(day, [PeriodStartDate], [PeriodEndDate]) + 1
					FROM
						(
						SELECT 
							[FiscalYear],
							[FiscalPeriod],
							[MidDate] = CONVERT(datetime, (CONVERT(int, CONVERT(datetime, [StartDate])) + CONVERT(int, CONVERT(datetime, [EndDate]))) / 2), 
							[PeriodStartDate] = [StartDate],
							[PeriodEndDate] = [EndDate]
						FROM
							' + @SourceDatabase + '.[' + @Owner + '].[GLBookPer]
						WHERE
							[Company] = ''' + @Entity + ''' AND
							[BookID] = ''' + @Book + ''' AND
							[FiscalCalendarID] = ''' + @FiscalCalendarID + '''
						) sub'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

		ELSE IF @SourceTypeID = 12 --Enterprise
			BEGIN
				IF CURSOR_STATUS('global','SourceTable_Cursor') >= -1 DEALLOCATE SourceTable_Cursor
				DECLARE SourceTable_Cursor CURSOR FOR
					SELECT
						[SourceDatabase] = EPV.EntityPropertyValue
					FROM
						[pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EPV
					WHERE
						EPV.InstanceID = @InstanceID AND
                        EPV.VersionID = @VersionID AND
						EPV.SelectYN <> 0 AND
						EPV.EntityPropertyTypeID = -1

					OPEN SourceTable_Cursor
					FETCH NEXT FROM SourceTable_Cursor INTO @SourceDatabase

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@SourceTable] = @SourceDatabase
							
							SET @SQLStatement = '
								INSERT INTO #Month
									(
									[YearMonth],
									[MidDate], 
									[PeriodStartDate],
									[PeriodEndDate],
									[NumberOfDays]
									)
								SELECT
									[YearMonth],
									[MidDate], 
									[PeriodStartDate],
									[PeriodEndDate],
									[NumberOfDays] = DATEDIFF(day, [PeriodStartDate], [PeriodEndDate]) + 1
								FROM
									(
									SELECT 
										[period_type],
										[YearMonth] = CONVERT(nvarchar(6), CONVERT(datetime, ([period_start_date] + [period_end_date]) / 2 - 693596), 112),
										[MidDate] = CONVERT(date, CONVERT(datetime, ([period_start_date] + [period_end_date]) / 2 - 693596)), 
										[PeriodStartDate] = CONVERT(date, CONVERT(datetime, [period_start_date] - 693596)), 
										[PeriodEndDate] = CONVERT(date, CONVERT(datetime, [period_end_date] - 693596))
									FROM
										' + @SourceDatabase + '.[' + @Owner + '].[glprd]
									) sub
								WHERE 
									NOT  EXISTS (SELECT 1 FROM #Month M WHERE M.[YearMonth] = sub.[YearMonth] AND M.[MidDate] = sub.[MidDate] AND M.[PeriodStartDate] = sub.[PeriodStartDate] AND M.[PeriodEndDate] = sub.[PeriodEndDate])
								ORDER BY
									[period_type],
									[PeriodStartDate]'
					
							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Selected = @Selected + @@ROWCOUNT

						FETCH NEXT FROM SourceTable_Cursor INTO @SourceDatabase
						END	
					CLOSE SourceTable_Cursor
					DEALLOCATE SourceTable_Cursor
			END

		--IF @DebugBM & 2 > 0 PRINT @SQLStatement
		--EXEC (@SQLStatement)

		--SET @Selected = @Selected + @@ROWCOUNT

	SET @Step = 'Return rows'
		IF @CalledYN = 0
			BEGIN
				SELECT TempTable = '#Month', * FROM #Month ORDER BY [PeriodStartDate], [PeriodEndDate]
			END

	SET @Step = 'Drop the temp tables'
		IF @CalledYN = 0
			BEGIN
				DROP TABLE #Month
			END

	SET @Step = 'Set ANSI_WARNINGS OFF'
		SET ANSI_WARNINGS OFF

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
