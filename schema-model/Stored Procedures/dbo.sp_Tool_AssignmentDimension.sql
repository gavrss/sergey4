SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_AssignmentDimension]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@WorkflowID int = NULL,
	@DataClassID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000570,
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
EXEC [sp_Tool_AssignmentDimension] @UserID=-10, @InstanceID=454, @VersionID=1021, @WorkflowID = 4645, @DataClassID = 5073, @Debug = 0

EXEC [sp_Tool_AssignmentDimension] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@AssignmentID int,
	@DimensionName nvarchar(100),
	@Dimension_MemberKey nvarchar(100),
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
	@Version nvarchar(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get a list of all dimension settings for Assignments within a specified Workflow/DataClass.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2196' SET @Description = 'Added hierarchy columns to temp table #AssignmentRow.'

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

	SET @Step = 'Create temp table #AssignmentDimension'
		SELECT
			A.InstanceID,
			A.VersionID,
			A.AssignmentID,
			A.AssignmentName,
			G.GridName
		INTO
			#AssignmentDimension
		FROM
			Assignment A
			INNER JOIN Grid G ON G.GridID = A.GridID
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.WorkflowID = @WorkflowID AND
			A.DataClassID = @DataClassID

	SET @Step = 'Add columns to temp table #AssignmentDimension'
		IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
		DECLARE AddColumn_Cursor CURSOR FOR

			SELECT
				D.[DimensionName]
			FROM
				pcINTEGRATOR_Data..DataClass_Dimension DCD
				INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID
			WHERE
				DCD.InstanceID = @InstanceID AND
				DCD.VersionID = @VersionID AND
				DCD.DataClassID = @DataClassID
			ORDER BY
				DCD.SortOrder,
				D.DimensionName

			OPEN AddColumn_Cursor
			FETCH NEXT FROM AddColumn_Cursor INTO @DimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = '
						ALTER TABLE #AssignmentDimension ADD [' + @DimensionName + ']  nvarchar(100) COLLATE DATABASE_DEFAULT'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM AddColumn_Cursor INTO @DimensionName
				END

		CLOSE AddColumn_Cursor
		DEALLOCATE AddColumn_Cursor	

		IF @DebugBM & 1 > 0 SELECT TempTable = '#AssignmentDimension', * FROM #AssignmentDimension

	SET @Step = 'Create temp table #AssignmentRow'
		CREATE TABLE #AssignmentRow
			(
			[Source] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[WorkflowID] int,
			[AssignmentID] int,
			[OrganizationPositionID] int,
			[DimensionID] int,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[HierarchyNo] int,
			[HierarchyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Dimension_MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[CogentYN] bit
			)

	SET @Step = 'AddFilter_Cursor'
		IF CURSOR_STATUS('global','AddFilter_Cursor') >= -1 DEALLOCATE AddFilter_Cursor
		DECLARE AddFilter_Cursor CURSOR FOR
			
			SELECT 
				AssignmentID
			FROM
				#AssignmentDimension

			OPEN AddFilter_Cursor
			FETCH NEXT FROM AddFilter_Cursor INTO @AssignmentID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@AssignmentID] = @AssignmentID

					TRUNCATE TABLE #AssignmentRow

					EXEC [spGet_AssignmentRow]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@WorkflowID = @WorkflowID,
						@AssignmentID = @AssignmentID,
						@UserDependentYN = 0,
						@ReadAccessYN = 0 

					IF CURSOR_STATUS('global','UpdateColumn_Cursor') >= -1 DEALLOCATE UpdateColumn_Cursor
					DECLARE UpdateColumn_Cursor CURSOR FOR

						SELECT
							[DimensionName],
							[Dimension_MemberKey]
						FROM
							#AssignmentRow

						OPEN UpdateColumn_Cursor
						FETCH NEXT FROM UpdateColumn_Cursor INTO @DimensionName, @Dimension_MemberKey

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@DimensionName] = @DimensionName, [@Dimension_MemberKey] = @Dimension_MemberKey

								SET @SQLStatement = '
									UPDATE #AssignmentDimension
									SET
										' + @DimensionName + ' = ''' + @Dimension_MemberKey + '''
									WHERE
										AssignmentID = ' + CONVERT(nvarchar(15), @AssignmentID)

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								FETCH NEXT FROM UpdateColumn_Cursor INTO @DimensionName, @Dimension_MemberKey
							END

					CLOSE UpdateColumn_Cursor
					DEALLOCATE UpdateColumn_Cursor	

					FETCH NEXT FROM AddFilter_Cursor INTO @AssignmentID
				END

		CLOSE AddFilter_Cursor
		DEALLOCATE AddFilter_Cursor

	SET @Step = 'Return rows'
		SELECT * FROM #AssignmentDimension ORDER BY Gridname, AssignmentName

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
