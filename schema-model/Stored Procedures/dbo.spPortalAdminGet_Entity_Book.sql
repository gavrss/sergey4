SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Entity_Book]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@EntityID int = NULL,
	@Book nvarchar(50) = NULL,
	@ResultTypeBM int = 1, --1 = Book, 2 = FiscalYear

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000287,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminGet_Entity_Book',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "-1187"},
		{"TKey" : "VersionID",  "TValue": "-1125"},
		{"TKey" : "EntityID",  "TValue": "10415"},
		{"TKey" : "Book",  "TValue": "Corp"},
		{"TKey" : "ResultTypeBM",  "TValue": "3"}
		]'

EXEC [spPortalAdminGet_Entity_Book] @UserID = -10, @InstanceID = -1187, @VersionID = -1125, @ResultTypeBM = 3, @EntityID = 10415, @Book = 'Corp'

EXEC [spPortalAdminGet_Entity_Book] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE

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
	@Version nvarchar(50) = '2.1.0.2162'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return Entity_Book details',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2152' SET @Description = 'Enhanced structure.'
		IF @Version = '2.1.0.2162' SET @Description = 'Now obsolete and replaced by [spPortalAdminGet_Entity] @ResultTypeBM = 132. Still not removed for legacy reasons.'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = '@ResultTypeBM = 1, Book'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					ResultTypeBM = 1,
					EB.EntityID,
					E.MemberKey,
					E.EntityName,
					EB.Book,
					EB.Currency,
					EB.BookTypeBM,
					EB.SelectYN
				FROM
					Entity_Book EB
					INNER JOIN Entity E ON E.InstanceID = EB.InstanceID AND E.VersionID = @VersionID AND E.EntityID = EB.EntityID
				WHERE
					EB.InstanceID = @InstanceID AND
					EB.EntityID = @EntityID AND
					EB.Book = @Book
			END

	SET @Step = '@ResultTypeBM = 2, FiscalYear'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT
					ResultTypeBM = 2,
					EFY.EntityID,
					EFY.Book,
					EFY.StartMonth,
					EFY.EndMonth,
					FYPeriods# = 12
				FROM
					Entity_FiscalYear EFY
					INNER JOIN Entity_Book EB ON EB.InstanceID = EFY.InstanceID AND EB.EntityID = EFY.EntityID AND EB.Book = EFY.Book
					INNER JOIN Entity E ON E.InstanceID = EB.InstanceID AND E.VersionID = @VersionID AND E.EntityID = EB.EntityID
				WHERE
					EFY.InstanceID = @InstanceID AND
					EFY.EntityID = @EntityID AND
					EB.Book = @Book
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
