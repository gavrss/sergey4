SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_BR02]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@BusinessRuleID int = NULL,
	@ResultTypeBM int = 3, --1 = BR02_Master, 2 = Parameters

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000441,
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
EXEC [pcINTEGRATOR].[dbo].[spPortalAdminGet_BR02] @BusinessRuleID='2629',@InstanceID='572',@ResultTypeBM='3',@UserID='9863',@VersionID='1080',@Debug=1

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminGet_BR02',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_BR02] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleID=2004, @Debug=1
EXEC [spPortalAdminGet_BR02] @UserID=-10, @InstanceID=527, @VersionID=1055, @BusinessRuleID=2494, @Debug=1

@InstanceID='527',@ResultTypeBM='3',@UserID='9427',@VersionID='1055'

EXEC [spPortalAdminGet_BR02] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SQLStatement nvarchar(max),
	@Database nvarchar(100),
	@Parameter nvarchar(4000),
	@StoredProcedureName nvarchar(100),

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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2176'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get parameter data for BR02',
			@MandatoryParameter = 'BusinessRuleID' --Without @, separated by |

		IF @Version = '2.0.2.2145' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2146' SET @Description = 'Added TupleNo to temp table #PipeStringSplit.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set ProcedureID in JobLog.'
		IF @Version = '2.1.2.2176' SET @Description = 'Added AuthenticatedUserID, DebugBM and SetJobLogYN to list of not needed parameters. Changed columns in metadata tables'

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

	SET @Step = 'Create temp table #PipeStringSplit and related tables'
		CREATE TABLE #PipeStringSplit
			(
			[TupleNo] int,
			[PipeObject] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
 			[PipeFilter] nvarchar(max) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'BR02_Master'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT 
					[ResultTypeBM] = 1,
					M.[Comment],
					M.[StoredProcedure],
					M.[FromTime],
					M.[ToTime],
					M.[Filter],
					BR.[LastExecTime],
					BR.[ExpectedExecTime]

					--[Parameter],
					--[Duration]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR02_Master] M
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[BusinessRule] BR ON BR.[InstanceID] = M.[InstanceID] AND BR.[VersionID] = M.[VersionID] AND BR.[BusinessRuleID] = M.[BusinessRuleID]
				WHERE
					M.[InstanceID] = @InstanceID AND
					M.[VersionID] = @VersionID AND
					M.[BusinessRuleID] = @BusinessRuleID AND
					M.[DeletedID] IS NULL
				ORDER BY
					M.[BusinessRuleID]

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'BR02 Parameters'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SELECT
					--@Database = REPLACE(REPLACE([StoredProcedure], '[', ''), ']', ''),
					@Database = REPLACE(REPLACE([DatabaseName], '[', ''), ']', ''),
					@StoredProcedureName = REPLACE(REPLACE([StoredProcedure], '[', ''), ']', ''),
					--@Parameter = [Parameter]
					@Parameter = [Filter]
				FROM
					[pcINTEGRATOR_Data].[dbo].[BR02_Master]
				WHERE
					InstanceID = @InstanceID AND
					VersionID = @VersionID AND
					BusinessRuleID = @BusinessRuleID AND
					DeletedID IS NULL
--SELECT 'Arne1'
				IF @Debug <> 0 SELECT [@Database] = @Database, [@StoredProcedureName] = @StoredProcedureName

				--SELECT
				--	@Database = LEFT(@Database, CHARINDEX('.', @Database) - 1),
				--	@StoredProcedureName = RIGHT(@StoredProcedureName , CHARINDEX ('.' ,REVERSE(@StoredProcedureName))-1)
--SELECT 'Arne2'	
				IF @Debug <> 0 SELECT [@Database] = @Database, [@StoredProcedureName] = @StoredProcedureName, [@Parameter] = @Parameter

				EXEC [dbo].[spGet_PipeStringSplit] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @PipeString = @Parameter
--SELECT 'Arne3'	
				IF @Debug <> 0 SELECT TempTable = '#PipeStringSplit', * FROM #PipeStringSplit

				SET @SQLStatement = '
					SELECT
						[ResultTypeBM] = 2,
						[Parameter] = REPLACE(AP.[name], ''@'', ''''),
						[DataType] = MAX(ISNULL(DT.DataTypePortal, T.[name])),
						[PreviousValue] = MAX(PSS.[PipeFilter])
					FROM
						[' + @Database + '].[sys].[procedures] P
						INNER JOIN [' + @Database + '].[sys].[all_parameters] AP ON AP.object_id = P.object_id AND AP.[name] NOT IN (''@UserID'',''@InstanceID'',''@VersionID'',''@JobID'',''@JobLogID'',''@Rows'',''@ProcedureID'',''@StartTime'',''@Duration'',''@Deleted'',''@Inserted'',''@Updated'',''@Selected'',''@GetVersion'',''@Debug'',''@AuthenticatedUserID'',''@DebugBM'',''@SetJobLogYN'')
						INNER JOIN [' + @Database + '].[sys].[types] T ON T.user_type_id = AP.user_type_id
						LEFT JOIN [pcINTEGRATOR].[dbo].[@Template_DataType] DT ON DT.DataTypeCode = T.[name]
						LEFT JOIN #PipeStringSplit PSS ON ''@'' + PSS.[PipeObject] = AP.[name]
					WHERE
						P.name = ''' + @StoredProcedureName + '''
					GROUP BY
						AP.[name]'

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				
				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp table'
		DROP TABLE #PipeStringSplit

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
