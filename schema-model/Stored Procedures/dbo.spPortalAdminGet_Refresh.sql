SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Refresh]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ResultTypeBM int = 7, --1 = Entity, 2 = Time From, 4 = Process

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000450,
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
	@ProcedureName = 'spPortalAdminGet_Refresh',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_Refresh] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1
EXEC [spPortalAdminGet_Refresh] @UserID=-10, @InstanceID=451, @VersionID=1019, @Debug=1

EXEC [spPortalAdminGet_Refresh] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@FiscalYearStartMonth int = NULL,

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
			@ProcedureDescription = 'Return possible parameters for running Refresh data',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created. DB-101: Enable refresh data in pcPortal'

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
			@FiscalYearStartMonth = ISNULL(@FiscalYearStartMonth, A.FiscalYearStartMonth)
		FROM
			[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID

	SET @Step = '@ResultTypeBM & 1, Entities'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					ResultTypeBM = 1,
					E.EntityID,
					E.MemberKey,
					EntityName,
					EH.ParentID,
					EH.SortOrder
				FROM
					Entity E
					LEFT JOIN EntityHierarchy EH ON EH.EntityID = E.EntityID
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					SelectYN <> 0 AND
					DeletedID IS NULL
				ORDER BY
					EH.SortOrder,
					E.MemberKey
			END 

	SET @Step = '@ResultTypeBM & 2, Time from'
		IF @Debug <> 0 SELECT [@FiscalYearStartMonth] = @FiscalYearStartMonth

		IF @ResultTypeBM & 2 > 0
			BEGIN
				CREATE TABLE #Digit
					(
					Number int
					)

				INSERT INTO #Digit
					(
					Number
					)
				SELECT Number = 0 UNION
				SELECT Number = 1 UNION
				SELECT Number = 2 UNION
				SELECT Number = 3 UNION
				SELECT Number = 4 UNION
				SELECT Number = 5 UNION
				SELECT Number = 6 UNION
				SELECT Number = 7 UNION
				SELECT Number = 8 UNION
				SELECT Number = 9

			SET @Step = 'Insert into temp table [#Month]'
				SELECT DISTINCT TOP 1000000
					[Year] = Y.Y,
					[Quarter] = Y.Y * 10 + (M.M + 2) / 3,
					[Month] = Y.Y * 100 + M.M
				INTO
					#Month
				FROM
					(
						SELECT
							[Y] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 
						FROM
							#Digit D1,
							#Digit D2,
							#Digit D3,
							#Digit D4
						WHERE
							D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN YEAR(GetDate()) - 2 AND YEAR(GetDate())
					) Y,
					(
						SELECT
							[M] = D2.Number * 10 + D1.Number + 1 
						FROM
							#Digit D1,
							#Digit D2
						WHERE
							D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
					) M 
				WHERE
					Y.Y * 100 + M.M BETWEEN CASE WHEN @FiscalYearStartMonth = 1 THEN (YEAR(GetDate()) - 1) * 100 + @FiscalYearStartMonth ELSE (YEAR(GetDate()) - 2) * 100 + @FiscalYearStartMonth END AND YEAR(GetDate()) * 100 + MONTH(GetDate())
				ORDER BY
					Y.Y * 100 + M.M

				SELECT
					[ResultTypeBM] = 2,
					[TimeID] = sub.[TimeID],
					[TimeName] = sub.[TimeName],
					[ParentID] = sub.[ParentID],
					[SortOrder] = sub.[TimeID]
				FROM
					(
					SELECT DISTINCT
						TimeID = [Year],
						TimeName = CONVERT(nvarchar(50), [Year]),
						ParentID = NULL
					FROM
						#Month

					UNION SELECT DISTINCT
						TimeID = [Quarter],
						TimeName = CONVERT(nvarchar, [Year]) + 'Q' + CONVERT(nvarchar, ([Month] % 100 + 2) / 3),
						ParentID = [Year]
					FROM
						#Month

					UNION SELECT DISTINCT
						TimeID = [Month],
						TimeName = SUBSTRING(DATENAME(m, CONVERT(nvarchar, [Year]) + '-' + CONVERT(nvarchar, [Month] % 100) + '-01'), 1, 3) + ' ' + CONVERT(nvarchar, [Year]),
						ParentID = [Quarter]
					FROM
						#Month
					) sub
				ORDER BY
					[SortOrder]

				DROP TABLE #Digit
				DROP TABLE #Month
			END 

	SET @Step = '@ResultTypeBM & 4, Process'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 4,
					[ProcessID],
					[ProcessName],
					[SortOrder] = [ProcessID]
				FROM
					Process P
				WHERE
					P.[InstanceID] = @InstanceID AND
					P.[VersionID] = @VersionID 
				ORDER BY
					[SortOrder]
			END 

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
