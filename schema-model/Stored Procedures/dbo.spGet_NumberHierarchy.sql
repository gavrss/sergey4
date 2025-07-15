SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_NumberHierarchy]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@MappingTypeID int = 0,
	@NumberHierarchy int = 8,
	@SourceTable nvarchar(100) = '#Segment_Members_Raw',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000739,
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
	@ProcedureName = 'spGet_NumberHierarchy',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spGet_NumberHierarchy] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spGet_NumberHierarchy] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@NumberLevel int,
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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2164'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create number hierarchy for dimension',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.0.2164' SET @Description = 'Procedure created.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure] @CalledProcedureID=@ProcedureID, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

	SET @Step = 'Create temp table #NumberHierarchy'
		IF OBJECT_ID(N'TempDB.dbo.#NumberHierarchy', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #NumberHierarchy
					(
					[MemberKeyBase] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[NodeTypeBM] int,
					[Parent] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Entity] nvarchar(50) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'Fill temp table #NumberHierarchy'
		SET @NumberLevel = @NumberHierarchy
		WHILE @NumberLevel > 0
			BEGIN
				IF @NumberLevel = @NumberHierarchy
					BEGIN
						SET @SQLStatement = '
							INSERT INTO #NumberHierarchy
								(
								[MemberKeyBase],
								[MemberKey],
								[NodeTypeBM],
								[Parent],
								[Entity]
								)
							SELECT DISTINCT
								[MemberKeyBase] = [MemberKeyBase],
								[MemberKey] = [MemberKey],
								[NodeTypeBM] = 1,
								[Parent] = LEFT([MemberKey], ' + CONVERT(nvarchar(15), @NumberHierarchy) + ' - 2),
								[Entity]
							FROM
								(
								SELECT DISTINCT
									[MemberKeyBase] = R.[MemberKey],
									[MemberKey] = [dbo].[f_GetNumberHierarchy] (R.[MemberKey], ' + CONVERT(nvarchar(15), @NumberHierarchy) + '),
									[Entity] = CASE WHEN ' + CONVERT(nvarchar(15), @MappingTypeID) + ' & 3 > 0 THEN R.[Entity] ELSE '''' END
								FROM
									' + @SourceTable + ' R
								) sub'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END
				ELSE
					INSERT INTO #NumberHierarchy
						(
						[MemberKey],
						[NodeTypeBM],
						[Parent],
						[Entity]
						)
					SELECT DISTINCT
						[MemberKey] = LEFT(NH.[MemberKey], @NumberLevel),
						[NodeTypeBM] = 18,
						[Parent] = LEFT(NH.[MemberKey], @NumberLevel - 2),
						[Entity]
					FROM
						#NumberHierarchy NH

				SET @NumberLevel = @NumberLevel - 2
			END

	SET @Step = 'Handle Entity Level'
		IF @MappingTypeID & 3 > 0
			BEGIN
				INSERT INTO #NumberHierarchy
					(
					[MemberKeyBase],
					[MemberKey],
					[NodeTypeBM],
					[Parent],
					[Entity]
					)
				SELECT DISTINCT
					[MemberKeyBase] = NULL,
					[MemberKey] = [Entity],
					[NodeTypeBM] = 18,
					[Parent] = 'All_',
					[Entity] = [Entity]
				FROM
					#NumberHierarchy NH
				WHERE
					NOT EXISTS (SELECT 1 FROM #NumberHierarchy NHD WHERE NHD.[MemberKey] = NH.[Entity])

				UPDATE NH
				SET 
					[Parent] = [Entity]
				FROM
					#NumberHierarchy NH
				WHERE
					[Parent] = ''
			END
		ELSE
			BEGIN
				UPDATE NH
				SET 
					[Parent] = 'All_'
				FROM
					#NumberHierarchy NH
				WHERE
					[Parent] = ''
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#NumberHierarchy', * FROM #NumberHierarchy ORDER BY LEN([MemberKey]), [MemberKey]

	SET @Step = 'Drop temp table'
		IF @CalledYN = 0 DROP TABLE #NumberHierarchy

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
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
