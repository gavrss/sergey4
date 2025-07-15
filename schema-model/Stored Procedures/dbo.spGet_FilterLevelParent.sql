SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_FilterLevelParent]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@DatabaseName nvarchar(100) = NULL, --Mandatory
	@DimensionName nvarchar(100) = NULL, --Mandatory
	@HierarchyName nvarchar(100) = NULL,
	@Filter nvarchar(1000) = NULL,
	@StorageTypeBM int = NULL, --Mandatory
	@LeafLevelFilter nvarchar(1000) = NULL OUT, --Mandatory

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000325,
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
	@ProcedureName = 'spGet_FilterLevelParent',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spGet_FilterLevelParent] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spGet_FilterLevelParent] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@SQLStatement nvarchar(max),
	@ParentMemberKey nvarchar(100) = '',
	@MemberKey nvarchar(100),
	@RowCount int,

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
	@ToBeChanged nvarchar(255) = 'Verify call from [spGet_LeafLevelFilter]. Temp table #FilterLevel_MemberKey only created in sp [spPortalGet_DataClass_Data]',
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.0.2140'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Search for parent members matching rows in table [#FilterLevel_MemberKey]',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description
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

	SET @Step = 'Check that temp table #FilterLevel_MemberKey exists'
		IF OBJECT_ID(N'TempDB.dbo.#FilterLevel_MemberKey', N'U') IS NULL
			BEGIN
				SET @Message = 'Temp table #FilterLevel_MemberKey does not exists.'
				SET @Severity = 16
				GOTO EXITPOINT
			END

	SET @Step = 'Check StorageTypeBM'		
		IF @StorageTypeBM & 3 > 0
			GOTO EXITPOINT

	SET @Step = 'CREATE TABLE #ParentMember'	
		CREATE TABLE #ParentMember
			(
			MemberKey nvarchar(100) COLLATE DATABASE_DEFAULT,
			ParentMemberKey nvarchar(100) COLLATE DATABASE_DEFAULT,
			CheckedYN bit
			)

	SET @Step = 'Check for Parent'
		SELECT @LeafLevelFilter = NULL,  @ParentMemberKey = @Filter, @RowCount = 1
		WHILE @LeafLevelFilter IS NULL AND @ParentMemberKey IS NOT NULL AND @RowCount <> 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #ParentMember
						(
						MemberKey,
						ParentMemberKey,
						CheckedYN
						)
					SELECT 
						MemberKey = D.Label,
						ParentMemberKey = DP.Label,
						CheckedYN = 0
					FROM
						' + @DatabaseName + '..S_DS_' +	@DimensionName + ' D
						INNER JOIN ' + @DatabaseName + '..S_HS_' +	@DimensionName + '_' + @HierarchyName + ' H ON H.MemberId = D.MemberId
						LEFT JOIN ' + @DatabaseName + '..S_DS_' +	@DimensionName + ' DP ON DP.MemberId = H.ParentMemberId
					WHERE
						D.Label = ''' + @ParentMemberKey + ''''

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @RowCount = @@ROWCOUNT

				SELECT 
					@MemberKey = MemberKey,
					@ParentMemberKey = ParentMemberKey
				FROM
					#ParentMember
				WHERE
					CheckedYN = 0

				IF (SELECT COUNT(1) FROM #FilterLevel_MemberKey WHERE MemberKey = @MemberKey) > 0
					SET @LeafLevelFilter = '''' + @MemberKey + ''''
				ELSE
					UPDATE #ParentMember SET CheckedYN = 1
			END

		IF LEN(@LeafLevelFilter) = 0 OR @LeafLevelFilter IS NULL SET @LeafLevelFilter = '''All_'''

	SET @Step = 'Drop temp tables'
		DROP TABLE #ParentMember
	
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
