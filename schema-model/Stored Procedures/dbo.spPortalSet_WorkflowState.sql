SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalSet_WorkflowState]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@AssignmentID int = NULL,
	@FromWorkflowStateID int = NULL,
	@ToWorkFlowStateID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000178,
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

--UPDATE
EXEC [spPortalSet_WorkflowState]
	@UserID = 2016,
	@InstanceID = 304,
	@VersionID = 1001,
	@AssignmentID = 1150,
	@FromWorkflowStateID = 1010,
	@ToWorkFlowStateID = 1012,
	@Debug = 1

EXEC [spPortalSet_WorkflowState] @GetVersion = 1

*/

SET ANSI_WARNINGS OFF

DECLARE
	@DeletedID int,
	@SQLStatement nvarchar(MAX),
	@SQL_Where nvarchar(MAX) = '',
	@DimensionName nvarchar(100),
	@Dimension_MemberKey nvarchar(100),
	@LeafLevelFilter nvarchar(4000),
	@DataClassName nvarchar(100),
	@DataClassID int,
	@StorageTypeBM_DataClass int,
	@StorageTypeBM_Dimension int,
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@DatabaseName nvarchar(100),
	@FACT_table nvarchar(100),
	@InstanceID_String nvarchar(10),
	@WorkflowStateColumn nvarchar(50),

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
	@Version nvarchar(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set WorkflowState for a full filtered sheet',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-473: Modified @SQL_Where statement to not include empty LeafLevelFilter.'
		IF @Version = '2.1.0.2156' SET @Description = 'DB-501: Modified AssignmentRow_Cursor query; added INNER JOINs to [Assignment] and [DataClass_Dimension].'
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
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		SET @InstanceID_String = CASE LEN(ABS(@InstanceID)) WHEN 1 THEN '000' WHEN 2 THEN '00' WHEN 3 THEN '0' ELSE '' END + CONVERT(nvarchar(10), ABS(@InstanceID))

		SELECT
			@CallistoDatabase = DestinationDatabase,
			@ETLDatabase = ETLDatabase
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		SELECT
			@DataClassID = DC.DataClassID,
			@DataClassName = DC.DataClassName,
			@StorageTypeBM_DataClass = DC.StorageTypeBM
		FROM
			Assignment A
			INNER JOIN DataClass DC ON DC.DataClassID = A.DataClassID
		WHERE
			AssignmentID = @AssignmentID

		IF @StorageTypeBM_DataClass & 2 > 0
			SELECT
				@FACT_table = '[' + @ETLDatabase + '].[dbo].[pcDC_' + @InstanceID_String + '_' + @DataClassName + ']'
		ELSE IF @StorageTypeBM_DataClass & 4 > 0
			SELECT
				@FACT_table = '[' + @CallistoDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition]'

		IF @Debug <> 0 
			SELECT 
				[@ETLDatabase] = @ETLDatabase, 
				[@CallistoDatabase] = @CallistoDatabase, 
				[@DataClassID] = @DataClassID, 
				[@DataClassName] = @DataClassName, 
				[@StorageTypeBM_DataClass] = @StorageTypeBM_DataClass,
				[@FACT_table] = @FACT_table

	SET @Step = 'Create, fill and update temp table #AssignmentRow.'
		CREATE TABLE #AssignmentRow
			(
			[Source] nvarchar(50),
			[WorkflowID] int,
			[AssignmentID] int,
			[OrganizationPositionID] int,
			[DimensionID] int,
			[DimensionName] nvarchar(100),
			[HierarchyNo] int,
			[HierarchyName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Dimension_MemberKey] nvarchar(100),
			[CogentYN] bit,
			[LeafLevelFilter] nvarchar(4000)
			)

		EXEC spGet_AssignmentRow @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @AssignmentID = @AssignmentID

		DECLARE AssignmentRow_Cursor CURSOR FOR

			SELECT DISTINCT
				AR.[DimensionName],
				AR.[Dimension_MemberKey],
				DST.[StorageTypeBM]
			FROM
				#AssignmentRow AR
				INNER JOIN Assignment A ON A.AssignmentID = AR.AssignmentID
				INNER JOIN DataClass_Dimension DD ON DD.DataClassID = A.DataClassID AND DD.DimensionID = AR.DimensionID
				INNER JOIN Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = AR.DimensionID
			ORDER BY
				[DimensionName],
				[Dimension_MemberKey]

			OPEN AssignmentRow_Cursor
			FETCH NEXT FROM AssignmentRow_Cursor INTO @DimensionName, @Dimension_MemberKey, @StorageTypeBM_Dimension

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @DatabaseName = CASE WHEN @StorageTypeBM_Dimension & 3 > 0 THEN @ETLDatabase ELSE @CallistoDatabase END
					IF @Debug <> 0 SELECT DimensionName = @DimensionName, Dimension_MemberKey = @Dimension_MemberKey, StorageTypeBM_Dimension = @StorageTypeBM_Dimension, DatabaseName = @DatabaseName

					EXEC [dbo].[spGet_LeafLevelFilter]
						@UserID = @UserID,
						@InstanceID = @InstanceID,
						@VersionID = @VersionID,
						@DatabaseName = @DatabaseName,
						@DimensionName = @DimensionName,
						@Filter = @Dimension_MemberKey,
						@StorageTypeBM_DataClass = @StorageTypeBM_DataClass,
						@StorageTypeBM = @StorageTypeBM_Dimension,
						@LeafLevelFilter = @LeafLevelFilter OUT
					
					UPDATE AR
					SET
						[LeafLevelFilter] = @LeafLevelFilter
					FROM
						#AssignmentRow AR
					WHERE
						[DimensionName] = @DimensionName AND
						[Dimension_MemberKey] = @Dimension_MemberKey

					FETCH NEXT FROM AssignmentRow_Cursor INTO @DimensionName, @Dimension_MemberKey, @StorageTypeBM_Dimension
				END

		CLOSE AssignmentRow_Cursor
		DEALLOCATE AssignmentRow_Cursor		

		IF @Debug <> 0 SELECT TempTable = '#AssignmentRow', * FROM #AssignmentRow ORDER BY [WorkflowID], [AssignmentID], [DimensionID]

	SET @Step = 'Create SQL statement for updating DataClass.'

		IF @Debug <> 0 SELECT AssignmentID = @AssignmentID
		SET @SQL_Where = ''
					
		SELECT @SQL_Where = @SQL_Where + DimensionName + CASE WHEN @StorageTypeBM_DataClass & 3 > 0 THEN '_MemberKey' ELSE '_MemberId' END + ' IN (' + LeafLevelFilter + ') AND ' FROM #AssignmentRow WHERE AssignmentID = @AssignmentID AND LEN(LeafLevelFilter) > 0 ORDER BY DimensionID
		SET @SQL_Where = LEFT(@SQL_Where, LEN(@SQL_Where) -4)
		IF @Debug <> 0 PRINT @SQL_Where

		SET @WorkflowStateColumn = CASE WHEN @StorageTypeBM_DataClass & 3 > 0 THEN 'WorkflowStateID' ELSE 'WorkflowState_MemberId' END

		SET @SQLStatement = '
			UPDATE F
			SET
				' + @WorkflowStateColumn + ' = ' + CONVERT(NVARCHAR(10), @ToWorkflowStateID) + '
			FROM
				' + @FACT_table + ' F
			WHERE
				F.' + @WorkflowStateColumn + ' = ' + CONVERT(NVARCHAR(10), @FromWorkflowStateID) + ' AND
				' + @SQL_Where

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = 'Drop temp tables'
		DROP TABLE #AssignmentRow

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
