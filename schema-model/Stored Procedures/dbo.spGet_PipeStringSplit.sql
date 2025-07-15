SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_PipeStringSplit]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@PipeString nvarchar(max) = NULL,
/*
Separators:
	Semicolon ; (59) = Separator between different tuples
	Pipe | (124) = Separator between different objects
	Dot . (46) = After dot, reference to property
	Colon : (58) = After colon, reference to hierarchy
	Paragraph § (167) = After paragraph, ObjectReference
	Comma , (44) = Separator between different filter members of same object type

Comparisons:
	'-'				Exclude
	'='				IN
	' LIKE '		IN
	' IN '			IN
	'<>'			NOT IN
	'!='			NOT IN
	' NOT IN '		NOT IN
	' NOT LIKE '	NOT IN

SELECT [SemiColon] = ascii(';'), [Pipe] = ascii('|'), [Dot] = ascii('.'), [Colon] = ascii(':'), [Paragraph] = ascii('§'), [Comma] = ascii(',')
*/
	@SetJobLogYN bit = 0,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000423,
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
EXEC [spGet_PipeStringSplit] @UserID = -10, @InstanceID = 114, @VersionID = 1004, @PipeString = 'BudgetProduct.ProdFamily|BudgetProduct.ProdType|BudgetProduct.ProdGroup|BudgetProduct.CountryOrigin|Time', @Debug = 1
EXEC [spGet_PipeStringSplit] @UserID = -10, @InstanceID = 114, @VersionID = 1004, @PipeString = 'SalesManager§SalesMT=7|SalesManager§SalesRM|SalesPrice', @Debug = 1
EXEC [spGet_PipeStringSplit] @UserID = -10, @InstanceID = 114, @VersionID = 1004, @PipeString = 'AccountManager = WF34|Currency = MYR|Entity = AJ01|GL_Branch = 3B|Scenario <> Budget,Forecast|Time = 2017', @Debug = 1
EXEC [spGet_PipeStringSplit] @UserID = -10, @InstanceID = 114, @VersionID = 1004, @PipeString =  '-4|-6|-63', @Debug = 1
EXEC [spGet_PipeStringSplit] @UserID = -10, @InstanceID = 114, @VersionID = 1004, @PipeString =  '-7|-2|-10;-4|-6|-63', @Debug = 1

EXEC [spGet_PipeStringSplit] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@CalledYN bit = 1,
	@EqualitySignPos int,
	@EqualitySignLen int,
	@FullPipeObject nvarchar(max),
	@PipeObject nvarchar(max),
	@PipeFilter nvarchar(max),
	@EqualityString nvarchar(10),
	@TupleNo int = 0,

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
	@ToBeChanged nvarchar(255),
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.1.2173'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Split pipe string into a table with columns and filters.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-87: Handle single object without EqualityString. Handle Tuple and use new sub routine [spGet_EqualityProperty]'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-368: Handle Strings longer than 1000.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set ProcedureID in JobLog.'
		IF @Version = '2.1.1.2168' SET @Description = 'Added parameter @SetJobLogYN, defaulted to 0.'
		IF @Version = '2.1.1.2173' SET @Description = 'Changed meaning between | and ;, simplified string handling'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy, @JobID = @ProcedureID
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

	SET @Step = 'Create temp table, #Tuple'
		CREATE TABLE #Tuple
			(
			TupleNo int IDENTITY(0,1),
			PipeString nvarchar(4000)
			)

		INSERT INTO #Tuple
			(
			[PipeString]
			)
		SELECT
			[PipeString] = [Value]
		FROM
			STRING_SPLIT (@PipeString, ';')

		IF @Debug <> 0 SELECT TempTable = '#Tuple', * FROM #Tuple

	SET @Step = 'Create temp table, #PipeStringSplit'
		IF OBJECT_ID(N'TempDB.dbo.#PipeStringSplit', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #PipeStringSplit
					(
					[TupleNo] int,
					[PipeObject] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
					[PipeFilter] nvarchar(max) COLLATE DATABASE_DEFAULT
					)
			END
		ELSE
			TRUNCATE TABLE #PipeStringSplit

	SET @Step = 'Loop pipes, Fill temp table, #PipeStringSplit'
		IF CURSOR_STATUS('global','Tuple_Cursor') >= -1 DEALLOCATE Tuple_Cursor
		DECLARE Tuple_Cursor CURSOR FOR
			
			SELECT
				[TupleNo],
				[PipeString]
			FROM
				#Tuple
			ORDER BY
				[TupleNo]

			OPEN Tuple_Cursor
			FETCH NEXT FROM Tuple_Cursor INTO @TupleNo, @PipeString

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT [@TupleNo] = @TupleNo, [@PipeString] = @PipeString

					IF CURSOR_STATUS('global','Pipe_Cursor') >= -1 DEALLOCATE Pipe_Cursor
					DECLARE Pipe_Cursor CURSOR FOR
			
						SELECT
							[FullPipeObject] = [Value]
						FROM
							STRING_SPLIT (@PipeString, '|')

						OPEN Pipe_Cursor
						FETCH NEXT FROM Pipe_Cursor INTO @FullPipeObject

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @Debug <> 0 SELECT [@FullPipeObject] = @FullPipeObject

								EXEC [spGet_EqualityProperty] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @String=@FullPipeObject, @EqualitySignPos=@EqualitySignPos OUT, @EqualitySignLen=@EqualitySignLen OUT, @EqualityString=@EqualityString OUT, @CalledYN=1, @JobID = @JobID

								IF @Debug <> 0 SELECT [@EqualitySignPos]=@EqualitySignPos, [@EqualitySignLen]=@EqualitySignLen, [@EqualityString]=@EqualityString

								SELECT
									@PipeObject = CASE WHEN @EqualitySignPos = 0 THEN @FullPipeObject ELSE LTRIM(RTRIM(LEFT(@FullPipeObject, @EqualitySignPos - 1))) END,
									@PipeFilter = CASE WHEN @EqualitySignPos = 0 THEN NULL ELSE LTRIM(RTRIM(RIGHT(@FullPipeObject, LEN(@FullPipeObject) - (@EqualitySignPos + @EqualitySignLen - 1)))) END

								IF @Debug <> 0 SELECT [@PipeObject]=@PipeObject, [@PipeFilter]=@PipeFilter

								INSERT INTO #PipeStringSplit
									(
									[TupleNo],
									[PipeObject],
									[EqualityString],
									[PipeFilter]
									)
								SELECT
									[TupleNo] = @TupleNo,
									[PipeObject] = LTRIM(RTRIM(@PipeObject)),
									[EqualityString] = @EqualityString,
									[PipeFilter] = LTRIM(RTRIM(@PipeFilter))

								FETCH NEXT FROM Pipe_Cursor INTO @FullPipeObject
							END

					CLOSE Pipe_Cursor
					DEALLOCATE Pipe_Cursor		

					FETCH NEXT FROM Tuple_Cursor INTO @TupleNo, @PipeString
				END

		CLOSE Tuple_Cursor
		DEALLOCATE Tuple_Cursor		

		IF @Debug <> 0 OR @CalledYN = 0 SELECT TempTable = '#PipeStringSplit', * FROM #PipeStringSplit

	SET @Step = 'Drop temp table'
		DROP TABLE #Tuple
		IF @CalledYN = 0 DROP TABLE #PipeStringSplit

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
