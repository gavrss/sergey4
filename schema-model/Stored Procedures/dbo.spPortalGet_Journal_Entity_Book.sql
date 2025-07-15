SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_Journal_Entity_Book] 
	@UserID INT = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ResultTypeBM int = 3, --1 = Filter, 2 = Filter rows, 4 = Data, Flat, 8 = Data, Head, 16 = Data, Line

	@Entity NVARCHAR(50) = NULL, --Optional
	@Book NVARCHAR(50) = NULL, --Optional

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000302,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

AS

/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalGet_Journal_Entity_Book',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "413"},
		{"TKey" : "VersionID",  "TValue": "1008"},
		{"TKey" : "ResultTypeBM",  "TValue": "2"}
		]'

EXEC [dbo].[spPortalGet_Journal_Entity_Book] @UserID = -10, @InstanceID = 404, @VersionID = 1003, @ResultTypeBM = 3, @Entity = '000', @Book = 'GL', @Debug = 1
EXEC [dbo].[spPortalGet_Journal_Entity_Book] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @ResultTypeBM = 3, @Entity = '52982', @Book = 'CBN_Main', @Debug = 1
EXEC [dbo].[spPortalGet_Journal_Entity_Book] @UserID = -10, @InstanceID = 413, @VersionID = 1008, @ResultTypeBM = 1

EXEC [dbo].[spPortalGet_Journal_Entity_Book] @GetVersion = 1
*/

DECLARE
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
	@Version nvarchar(50) = '2.0.0.2140'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return available Entities and Books from Journal.',
			@MandatoryParameter = ''
		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description
		RETURN
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())
		
	SET @Step = 'Set procedure variables'
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = suser_name()

	SET @Step = '@ResultTypeBM & 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					ParameterType = CONVERT(nvarchar(50), ParameterType),
					ParameterName = CONVERT(nvarchar(50), ParameterName),
					DataType = CONVERT(nvarchar(50), DataType),
					KeyColumn = CONVERT(nvarchar(50), KeyColumn),
					SortOrder
				INTO
					#ResultType1
				FROM
					(
					SELECT ParameterType = 'SingleSelect', ParameterName = 'Entity', DataType = 'string', KeyColumn = 'MemberKey', SortOrder = 20
					UNION SELECT ParameterType = 'SingleSelect', ParameterName = 'Book', DataType = 'string', KeyColumn = 'MemberKey', SortOrder = 30
					) sub

				IF @Debug <> 0 SELECT InstanceID = @InstanceID, Entity = @Entity, Book = @Book
				
				SELECT 
					ResultTypeBM = 1,
					ParameterName,
					ParameterDescription = ParameterName,
					DataType,
					ParameterType,
					KeyColumn
				FROM
					#ResultType1
				ORDER BY
					SortOrder

				SET @Selected = @Selected + @@ROWCOUNT

				DROP TABLE #ResultType1
			END

	SET @Step = '@ResultTypeBM & 2'
		IF @ResultTypeBM & 2 > 0
			BEGIN

--All, only filtered by @InstanceID
				SELECT DISTINCT
					ResultTypeBM = 2, 
					ParameterName = 'Entity', 
					MemberKey = Entity, 
					[Name] = E.EntityName, 
					[Description] = E.EntityName 
				FROM
					Journal J
					INNER JOIN Entity E ON E.InstanceID = J.InstanceID AND E.MemberKey = J.Entity
				WHERE 
					J.InstanceID = @InstanceID AND
					(J.Entity = @Entity OR @Entity IS NULL)
				ORDER BY
					E.EntityName

				SELECT DISTINCT
					ResultTypeBM = 2, 
					ParameterName = 'Book', 
					MemberKey = J.Book, 
					[Name] = J.Book,
					[Description] = J.Book, 
					Entity_MemberKey = Entity 
				FROM
					Journal J
					INNER JOIN Entity E ON E.InstanceID = J.InstanceID AND E.MemberKey = J.Entity
					INNER JOIN Entity_Book EB ON EB.InstanceID = E.InstanceID AND EB.EntityID = E.EntityID AND EB.Book = J.Book
				WHERE
					J.InstanceID = @InstanceID AND
					(J.Entity = @Entity OR @Entity IS NULL) AND
					(J.Book = @Book OR @Book IS NULL)
				ORDER BY
					J.Book
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		SET @JobID = ISNULL(@JobID, @ProcedureID)
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	SET @JobID = ISNULL(@JobID, @ProcedureID)
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
