SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Time_Enterprise]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Entity_MemberKey nvarchar(50) = NULL,
	@Book nvarchar(50) = NULL,
	@FiscalYear int = NULL,
	@FiscalPeriod int = NULL,
	@StartFiscalYear int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000448,
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
	@ProcedureName = 'spIU_Time_Enterprise',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "413"},
		{"TKey" : "VersionID",  "TValue": "1008"},
		{"TKey" : "Entity_MemberKey",  "TValue": "52982"},
		{"TKey" : "Book",  "TValue": "CBN_Main"}
		]',
	@Debug = 1

EXEC [spIU_Time_Enterprise] @UserID = -10, @InstanceID = -1051, @VersionID = -1051, @Entity_MemberKey = '4', @Book = 'GL', @Debug = 1

EXEC [spIU_Time_Enterprise] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceDatabase nvarchar(100),
	@EntityID int,
	@SQLStatement nvarchar(max),
	@SQLSegment nvarchar(max),
	@SegmentNo int = -1,
	@MinFiscalYear int,
	@MinYearMonth int,
	@MinStartDate int,
	@StartDate date,
	@PrevStartDate int,
	@PrevEndDate int,
	@AccountSegmentNo nchar(1),
	@MasterDatabase nvarchar(100),
	@SourceTypeID int = 12, --Enterprise
	@MaxYearMonth int,

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.2.2146'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Update NumberOfDays and PeriodEndDate in time domension.',
			@MandatoryParameter = 'Entity_MemberKey|Book' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'

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

	SELECT
			@EntityID = E.EntityID
		FROM
			Entity E
			INNER JOIN Entity_Book EB ON EB.EntityID = E.EntityID AND EB.Book = @Book AND EB.BookTypeBM & 1 > 0 AND EB.SelectYN <> 0
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			E.MemberKey = @Entity_MemberKey AND
			E.SelectYN <> 0

		SELECT
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(EntityPropertyValue, '[', ''), ']', ''), '.', '].[') + ']'
		FROM
			EntityPropertyValue
		WHERE
			EntityID = @EntityID AND
			EntityPropertyTypeID = -1 AND
			SelectYN <> 0

		SELECT
			@MasterDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@StartFiscalYear = ISNULL(@StartFiscalYear, S.StartYear)
		FROM
			[Source] S
			INNER JOIN [Model] M ON M.ModelID = S.ModelID AND M.BaseModelID = -7 AND M.SelectYN <> 0
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.InstanceID = @InstanceID AND A.VersionID = @VersionID AND A.SelectYN <> 0
		WHERE
			S.SourceTypeID = @SourceTypeID AND
			S.SelectYN <> 0

		IF @Debug <> 0
			SELECT 
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@SourceDatabase] = @SourceDatabase,
				[@MasterDatabase] = @MasterDatabase

	SET @Step = 'Create and fill temp table #FiscalPeriod'
		CREATE TABLE #FiscalPeriod
			(
			FiscalYear int,
			FiscalPeriod int,
			YearMonth int
			)

		IF @Debug <> 0 SELECT UserID = @UserID, InstanceID = @InstanceID, VersionID = @VersionID, EntityID = @EntityID, Book = @Book, StartFiscalYear = @StartFiscalYear, FiscalYear = @FiscalYear, FiscalPeriod = @FiscalPeriod

		EXEC dbo.[spGet_Entity_FiscalYear] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @EntityID = @EntityID, @Book = @Book, @StartFiscalYear = @StartFiscalYear, @FiscalYear = @FiscalYear, @FiscalPeriod = @FiscalPeriod, @JobID = @JobID

		IF @Debug <> 0 SELECT TempTable = '#FiscalPeriod', * FROM #FiscalPeriod ORDER BY YearMonth

		SELECT
			@MinYearMonth = MIN(YearMonth),
			@MaxYearMonth = MAX(YearMonth)
		FROM
			#FiscalPeriod

		IF @Debug <> 0 SELECT [@MinYearMonth] = @MinYearMonth, [@MaxYearMonth] = @MaxYearMonth

		CREATE TABLE #Period
			(
			FiscalPeriod int IDENTITY(1, 1),
			YearMonth int,
			MidDate date, 
			StartDate date, 
			EndDate date,
			NumberOfDays int
			)

		SET @SQLStatement = '
			INSERT INTO #Period
				(
				YearMonth,
				MidDate, 
				StartDate, 
				EndDate
				)
			SELECT 
				YearMonth = CONVERT(nvarchar(6), CONVERT(datetime, (period_start_date + period_end_date) / 2 - 693596), 112),
				MidDate = CONVERT(date, CONVERT(datetime, (period_start_date + period_end_date) / 2 - 693596)), 
				StartDate = CONVERT(date, CONVERT(datetime, period_start_date - 693596)), 
				EndDate = CONVERT(date, CONVERT(datetime, period_end_date - 693596))
			FROM
				 ' + @SourceDatabase + '.[dbo].[glprd]
			WHERE
				CONVERT(nvarchar(6), CONVERT(datetime, (period_start_date + period_end_date) / 2 - 693596), 112) BETWEEN ' + CONVERT(nvarchar(10), @MinYearMonth) + ' AND ' + CONVERT(nvarchar(10), @MaxYearMonth) + '
			ORDER BY
				period_type,
				period_start_date'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		UPDATE #Period
		SET
			NumberOfDays = DATEDIFF(day, StartDate, EndDate) + 1

		IF @Debug <> 0 SELECT TempTable = '#Period', * FROM #Period ORDER BY YearMonth

	SET @Step = 'Update Time dimension'
--This part has to be dynamic
/*
		UPDATE T
		SET
			NumberOfDays = P.NumberOfDays,
			PeriodEndDate = CONVERT(nvarchar(50), P.EndDate, 101)
		FROM
			pcDATA_Saker.dbo.S_DS_Time T
			INNER JOIN #Period P ON P.YearMonth = T.MemberId

		UPDATE T
		SET
			NumberOfDays = sub.NumberOfDays,
			PeriodEndDate = C.PeriodEndDate
		FROM
			pcDATA_Saker.dbo.S_DS_Time T
			INNER JOIN (
				SELECT
					P.MemberId,
					NumberOfDays = SUM(T.NumberOfDays),
					MaxChild = MAX(T.MemberId)
				FROM
					pcDATA_Saker.dbo.S_DS_Time T
					INNER JOIN pcDATA_Saker.dbo.S_HS_Time_Time H ON H.MemberId = T.MemberId
					INNER JOIN pcDATA_Saker.dbo.S_DS_Time P ON P.MemberId = H.ParentMemberId
				WHERE
					T.[Level] = 'Month'
				GROUP BY
					P.MemberId
				) sub ON sub.MemberId = T.MemberId
			INNER JOIN pcDATA_Saker.dbo.S_DS_Time C ON C.MemberId = sub.MaxChild
			
		UPDATE T
		SET
			NumberOfDays = sub.NumberOfDays,
			PeriodEndDate = C.PeriodEndDate
		FROM
			pcDATA_Saker.dbo.S_DS_Time T
			INNER JOIN (
				SELECT
					P.MemberId,
					NumberOfDays = SUM(T.NumberOfDays),
					MaxChild = MAX(T.MemberId)
				FROM
					pcDATA_Saker.dbo.S_DS_Time T
					INNER JOIN pcDATA_Saker.dbo.S_HS_Time_Time H ON H.MemberId = T.MemberId
					INNER JOIN pcDATA_Saker.dbo.S_DS_Time P ON P.MemberId = H.ParentMemberId
				WHERE
					T.[Level] = 'Quarter'
				GROUP BY
					P.MemberId
				) sub ON sub.MemberId = T.MemberId
			INNER JOIN pcDATA_Saker.dbo.S_DS_Time C ON C.MemberId = sub.MaxChild

		TRUNCATE TABLE pcDATA_Saker.dbo.O_DS_Time
		
		INSERT INTO pcDATA_Saker.dbo.O_DS_Time
		SELECT * FROM pcDATA_Saker.dbo.S_DS_Time
*/
	SET @Step = 'Drop the temp tables'
		DROP TABLE #FiscalPeriod
		DROP TABLE #Period

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
