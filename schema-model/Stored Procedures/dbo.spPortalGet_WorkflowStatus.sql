SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_WorkflowStatus]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	@WorkflowID INT = NULL, --Optional
	@AssignmentID INT = NULL, --Optional
	@ActingAs INT = NULL, --Optional (OrganizationPositionID)
	@DataClassID INT = NULL, --Optional

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@AuthenticatedUserID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000162,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [pcINTEGRATOR].[dbo].[spPortalGet_WorkflowStatus] @ActingAs='15290',@InstanceID='-1742',@UserID='21380',@VersionID='-1742'

--limited assginment states
EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"DebugBM","TValue":"3"},
{"TKey":"ActingAs","TValue":"12600"},{"TKey":"InstanceID","TValue":"-1590"},{"TKey":"UserID","TValue":"18518"},
{"TKey":"VersionID","TValue":"-1590"}]', @ProcedureName='spPortalGet_WorkflowStatus'

EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"DebugBM","TValue":"3"},
{"TKey":"ActingAs","TValue":"13176"},{"TKey":"InstanceID","TValue":"-1700"},
{"TKey":"UserID","TValue":"19247"},{"TKey":"VersionID","TValue":"-1700"}]', @ProcedureName='spPortalGet_WorkflowStatus'

EXEC spPortalGet_WorkflowStatus @InstanceID='-1232',@UserID='-1598',@VersionID='-1170',@Debug=1
EXEC spPortalGet_WorkflowStatus @InstanceID='-1125',@UserID='7273',@VersionID='-1125',@Debug=1

EXEC spPortalGet_WorkflowStatus @InstanceID='413',@UserID='2147',@VersionID='1008',@DebugBM=1

EXEC [spPortalGet_WorkflowStatus] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@InstanceID_String nvarchar(10),
	@AssignmentName nvarchar(100),
	@WorkflowName nvarchar(100),
	@SourceTable nvarchar(100),
	@StorageTypeBM_DataClass int,
	@SQLStatement nvarchar(max),
	@FilterString nvarchar(max),
	@DimensionName  nvarchar(100),
	@StorageTypeBM_Dimension int,
	@Filter nvarchar(100),
	@LeafLevelFilter nvarchar(max),
	@LoopNo int = 0,
	@DataClassName nvarchar(100),
	@TableNo int,
	@ColumnName nvarchar(100),
	@DataType nvarchar(100),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2196'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Returns a list of existing WorkflowStates per Assignment.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2140' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Set correct concatenation of values for column @Filter on #AssignmentFilter - DB-36;DB-58.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-105: Not include dimensions where ReportOnlyYN = 1'
		IF @Version = '2.0.2.2147' SET @Description = 'DB-128: Test on Workflow.DeletedID IS NULL'
		IF @Version = '2.0.2.2149' SET @Description = 'DB-218: Test on WorkflowState exists in Dataclass, DB-230: Only calculate dataclasses of relevant DataClassTypeID. DB-239: Check for valid Dimensions in @FilterString.'
		IF @Version = '2.0.3.2151' SET @Description = 'DebugBM code enhancement.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-301: Handle single quotes in names/descriptions.'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-372: Doesnt calculate workflow statuses for assignment with data connections pointing to root ALL_ member. Added optional parameters @WorkflowID and @AssignmentID.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-425: Added WorkflowID Filter on INSERT query of #WorkflowStatus.'
		IF @Version = '2.1.0.2158' SET @Description = 'Test on length of @FilterString (WHERE clause) in AssignmentWorkflowState_Cursor.'
		IF @Version = '2.1.0.2164' SET @Description = 'Added parameter 	@ActingAs and @AuthenticatedUserID.'
		IF @Version = '2.1.1.2168' SET @Description = 'Applied table hint WITH (NOLOCK) when reading from @SourceTable in @Step = Assignment Cursor.'
		IF @Version = '2.1.2.2182' SET @Description = 'DB-1269: Exclude DimensionTypeID = 27 when inserting into #AssignmentFilter and #MissingDimension. Exclude BusinessProcess_MemberId = 118 (LineItem) in the resultset.'
		IF @Version = '2.1.2.2190' SET @Description = 'Increased performance. Just one call to each DataClass. Added (NOLOCK) HINT when retrieving from FACT table.'
		IF @Version = '2.1.2.2196' SET @Description = 'Added hierarchy columns to temp table #AssignmentRow.'

		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY

	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

		IF @DebugBM & 16 > 0 SELECT Step= 10, [Time]= CONVERT(time(7), GetDate() - @StartTime)

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ETLDatabase = ETLDatabase,
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application] A
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.SelectYN <> 0

		SET @InstanceID_String = CASE LEN(ABS(@InstanceID)) WHEN 1 THEN '000' WHEN 2 THEN '00' WHEN 3 THEN '0' ELSE '' END + CONVERT(nvarchar(10), ABS(@InstanceID))

	SET @Step = 'Create temp table #WorkflowStatus'
		CREATE TABLE #WorkflowStatus
			(
			WorkflowID int,
			WorkflowName nvarchar(100),
			AssignmentID int,
			AssignmentName nvarchar(100),
			[WorkflowStateID] int,
			ChangeableYN bit,
			NoOfItems int
			)

	SET @Step = 'Calculate Assignments'
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
			[CogentYN] bit
			)

		EXEC spGet_AssignmentRow @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @UserDependentYN = 1, @WorkflowID = @WorkflowID, @AssignmentID = @AssignmentID, @OrganizationPositionID = @ActingAs, @DataClassID = @DataClassID, @JobID = @JobID, @Debug = @DebugSub

		IF @DebugBM & 1 > 0 SELECT TempTable = '#AssignmentRow', * FROM #AssignmentRow

		IF @DebugBM & 16 > 0 SELECT Step= 20, [Time]= CONVERT(time(7), GetDate() - @StartTime)

		CREATE TABLE #MissingDimension (AssignmentID int, DimensionID int)

		INSERT INTO #MissingDimension (AssignmentID, DimensionID)
		SELECT DISTINCT
			A.AssignmentID,
			DCD.DimensionID
		FROM
			(SELECT DISTINCT AssignmentID FROM #AssignmentRow) AR
			INNER JOIN Assignment A ON A.AssignmentID = AR.AssignmentID
			INNER JOIN Workflow W ON W.WorkflowID = A.WorkflowID AND W.SelectYN <> 0 AND W.DeletedID IS NULL
			INNER JOIN DataClass_Dimension DCD ON DCD.DataClassID = A.DataClassID
			INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID AND D.ReportOnlyYN = 0 AND D.DimensionTypeID NOT IN (27) AND D.SelectYN <> 0 AND D.DeletedID IS NULL
		WHERE
			NOT EXISTS (SELECT 1 FROM (
							SELECT DISTINCT
								AssignmentID,
								DimensionID = -63 --WorkflowState
							FROM
								#AssignmentRow AR

							UNION SELECT DISTINCT
								AssignmentID,
								DimensionID
							FROM
								#AssignmentRow AR
								INNER JOIN Workflow W ON W.WorkflowID = AR.WorkflowID AND W.SelectYN <> 0 AND W.DeletedID IS NULL

							UNION SELECT DISTINCT
								A.AssignmentID,
								GD.DimensionID
							FROM
								Assignment A
								INNER JOIN Workflow W ON W.WorkflowID = A.WorkflowID AND W.SelectYN <> 0 AND W.DeletedID IS NULL
								INNER JOIN Grid_Dimension GD ON GD.InstanceID = @InstanceID AND GD.GridID = A.GridID
							) sub
						WHERE sub.AssignmentID = A.AssignmentID AND sub.DimensionID = DCD.DimensionID)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#MissingDimension', * FROM #MissingDimension

		IF @DebugBM & 16 > 0 SELECT Step= 30, [Time]= CONVERT(time(7), GetDate() - @StartTime)
	
	SET @Step = 'Create #AssignmentCursorTable'
		SELECT DISTINCT
			A.AssignmentID,
			A.AssignmentName,
			WF.WorkflowID,
			WF.WorkflowName,
			SourceTable = CASE DC.StorageTypeBM WHEN 2 THEN '[' + @ETLDatabase + '].[dbo].[pcDC_' + @InstanceID_String + '_' + DC.DataClassName + ']' WHEN 4 THEN '[' + @CallistoDatabase + '].[dbo].[FACT_' + DC.DataClassName + '_default_partition]' END,
			DC.StorageTypeBM,
			DC.DataClassID
		INTO
			#AssignmentCursorTable
		FROM
			(SELECT DISTINCT AssignmentID FROM #AssignmentRow) AR
			INNER JOIN Assignment A ON A.AssignmentID = AR.AssignmentID
			INNER JOIN DataClass DC ON DC.DataClassID = A.DataClassID AND DC.DataClassTypeID IN (-1) AND (DC.DataClassID = @DataClassID OR @DataClassID IS NULL)
			INNER JOIN Workflow WF ON WF.WorkflowID = A.WorkflowID AND WF.SelectYN <> 0 AND WF.DeletedID IS NULL
			INNER JOIN DataClass_Dimension DCD ON DCD.DataClassID = A.DataClassID AND DCD.DimensionID = -63 --WorkflowState
		WHERE
			A.InstanceID = @InstanceID AND
			A.VersionID = @VersionID AND
			A.DeletedID IS NULL AND
			NOT EXISTS (SELECT DISTINCT AssignmentID FROM #MissingDimension MD WHERE MD.AssignmentID = A.AssignmentID)
		ORDER BY
			A.AssignmentID

		IF @DebugBM & 1 > 0 SELECT TempTable = '#AssignmentCursorTable', * FROM #AssignmentCursorTable ORDER BY AssignmentID

	SET @Step = 'Create temp tables from included dataclasses'

		CREATE TABLE #AddColumn_Cursor_Table
			(
			ColumnName nvarchar(100),
			DataType nvarchar(100),
			SortOrder int
			)

		CREATE TABLE #DCtable_Cursor_Table
			(
			TableNo int IDENTITY(1,1),
			DataClassID int,
			SourceTable nvarchar(100) COLLATE DATABASE_DEFAULT,
			WorkFlowID int
			)

		INSERT INTO #DCtable_Cursor_Table
			(
			DataClassID,
			SourceTable,
			WorkFlowID
			)
		SELECT DISTINCT
			DataClassID,
			SourceTable,
			WorkFlowID
		FROM
			#AssignmentCursorTable

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DCtable_Cursor_Table', * FROM #DCtable_Cursor_Table

		IF CURSOR_STATUS('global','DCtable_Cursor') >= -1 DEALLOCATE DCtable_Cursor
		DECLARE DCtable_Cursor CURSOR FOR
			
			SELECT DISTINCT
				CT.TableNo,
				CT.DataClassID,
				CT.SourceTable,
				DC.DataClassName
			FROM
				#DCtable_Cursor_Table CT
				INNER JOIN pcINTEGRATOR_Data..DataClass DC ON DC.DataClassID = CT.DataClassID
			ORDER BY
				DataClassID

			OPEN DCtable_Cursor
			FETCH NEXT FROM DCtable_Cursor INTO @TableNo, @DataClassID, @SourceTable, @DataClassName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@TableNo] = @TableNo, [@DataClassID] = @DataClassID, [@SourceTable] = @SourceTable, [@DataClassName] = @DataClassName

					IF @TableNo = 1
						CREATE TABLE #DC1
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 2
						CREATE TABLE #DC2
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 3
						CREATE TABLE #DC3
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 4
						CREATE TABLE #DC4
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 5
						CREATE TABLE #DC5
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 6
						CREATE TABLE #DC6
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 7
						CREATE TABLE #DC7
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 8
						CREATE TABLE #DC8
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 9
						CREATE TABLE #DC9
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 10
						CREATE TABLE #DC10
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 11
						CREATE TABLE #DC11
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 12
						CREATE TABLE #DC12
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 13
						CREATE TABLE #DC13
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 14
						CREATE TABLE #DC14
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 15
						CREATE TABLE #DC15
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 16
						CREATE TABLE #DC16
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 17
						CREATE TABLE #DC17
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 18
						CREATE TABLE #DC18
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 19
						CREATE TABLE #DC19
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 20
						CREATE TABLE #DC20
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 21
						CREATE TABLE #DC21
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 22
						CREATE TABLE #DC22
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 23
						CREATE TABLE #DC23
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 24
						CREATE TABLE #DC24
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 25
						CREATE TABLE #DC25
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 26
						CREATE TABLE #DC26
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 27
						CREATE TABLE #DC27
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 28
						CREATE TABLE #DC28
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 29
						CREATE TABLE #DC29
							(
							[Dummy] [int] DEFAULT(0)
							)
					ELSE IF @TableNo = 30
						CREATE TABLE #DC30
							(
							[Dummy] [int] DEFAULT(0)
							)

					TRUNCATE TABLE #AddColumn_Cursor_Table

					SET @SQLStatement = '
						INSERT INTO #AddColumn_Cursor_Table
							(
							ColumnName,
							DataType,
							SortOrder
							)
						SELECT
							ColumnName = c.name,
							DataType = dt.name + CASE WHEN dt.collation_name IS NOT NULL THEN '' ('' + CONVERT(nvarchar(15), c.max_length / 2) + '')'' ELSE '''' END,
							SortOrder = c.[column_id]
						FROM
							' + @CallistoDatabase + '.sys.tables t
							INNER JOIN ' + @CallistoDatabase + '.sys.columns c ON c.[object_id] = t.[object_id]
							INNER JOIN ' + @CallistoDatabase + '.sys.types dt ON dt.[user_type_id] = c.[user_type_id]
						WHERE
							t.[name] = ''FACT_' + @DataClassName + '_default_partition'''

					EXEC (@SQLStatement)


					IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
					DECLARE AddColumn_Cursor CURSOR FOR
						
						SELECT
							[ColumnName],
							[DataType]
						FROM
							#AddColumn_Cursor_Table
						ORDER BY
							[SortOrder]

						OPEN AddColumn_Cursor
						FETCH NEXT FROM AddColumn_Cursor INTO @ColumnName, @DataType

						WHILE @@FETCH_STATUS = 0
							BEGIN
								SET @SQLStatement = '
									ALTER TABLE #DC' + CONVERT(nvarchar(15), @TableNo) + ' ADD [' + @ColumnName + '] ' + @DataType

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

								FETCH NEXT FROM AddColumn_Cursor INTO  @ColumnName, @DataType
							END

					CLOSE AddColumn_Cursor
					DEALLOCATE AddColumn_Cursor	

					SET @SQLStatement = '
						INSERT INTO #DC' + CONVERT(nvarchar(15), @TableNo) + '
						SELECT
							[Dummy] = 0,
							DC.*
						FROM
							' + @SourceTable + ' DC WITH (NOLOCK)
							INNER JOIN #DCtable_Cursor_Table CT ON CT.DataClassID = ' + CONVERT(nvarchar(15), @DataClassID) + '
							INNER JOIN pcINTEGRATOR_Data..WorkflowState WFS ON WFS.WorkFlowID = CT.WorkFlowID AND WFS.WorkFlowStateID = DC.WorkFlowState_MemberID
						WHERE
							DC.BusinessProcess_MemberId NOT IN (118)'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM DCtable_Cursor INTO @TableNo, @DataClassID, @SourceTable, @DataClassName
				END

		CLOSE DCtable_Cursor
		DEALLOCATE DCtable_Cursor

		IF @DebugBM & 16 > 0 SELECT Step= 35, [Time]= CONVERT(time(7), GetDate() - @StartTime)

		IF @DebugBM & 8 > 0
			BEGIN
				SELECT TempTable = '#DC1', * FROM #DC1
			END

	SET @Step = 'Calculate #AssignmentFilter'
		SELECT DISTINCT
			[AssignmentID],
			[DimensionID],
			[DimensionName],
			StorageTypeBM_Dimension,
			[Filter] = CONVERT(nvarchar(max), ''),
			[LeafLevelFilter] = CONVERT(nvarchar(max), ''),
			StorageTypeBM_DataClass
		INTO
			#AssignmentFilter
		FROM
			(
			SELECT DISTINCT
				AR.[AssignmentID],
				AR.[DimensionID],
				[DimensionName] = MAX(AR.DimensionName),
				StorageTypeBM_Dimension = MAX(DST.StorageTypeBM),
				StorageTypeBM_DataClass = MAX(DC.StorageTypeBM)
			FROM
				#AssignmentRow AR
				INNER JOIN Assignment A ON A.AssignmentID = AR.AssignmentID
				INNER JOIN DataClass DC ON DC.DataClassID = A.DataClassID
				INNER JOIN Dimension_StorageType DST ON DST.InstanceID = @InstanceID AND DST.VersionID = @VersionID AND DST.DimensionID = AR.DimensionID
				INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionID = DST.DimensionID AND D.DimensionTypeID NOT IN (27) AND D.SelectYN <> 0 AND D.DeletedID IS NULL 
				INNER JOIN Workflow W ON W.WorkflowID = AR.WorkflowID AND W.SelectYN <> 0 AND W.DeletedID IS NULL
			GROUP BY
				AR.[AssignmentID],
				AR.[DimensionID]
			) sub

		IF @DebugBM & 16 > 0 SELECT Step= 36, [Time]= CONVERT(time(7), GetDate() - @StartTime)

		IF CURSOR_STATUS('global','AssignmentFilter_Cursor1') >= -1 DEALLOCATE AssignmentFilter_Cursor1
		DECLARE AssignmentFilter_Cursor1 CURSOR FOR
			
			SELECT DISTINCT
				[AssignmentID],
				[DimensionName],
				[StorageTypeBM_DataClass],
				[StorageTypeBM_Dimension],
				[Filter]
			FROM
				#AssignmentFilter

			OPEN AssignmentFilter_Cursor1
			FETCH NEXT FROM AssignmentFilter_Cursor1 INTO @AssignmentID, @DimensionName, @StorageTypeBM_DataClass, @StorageTypeBM_Dimension, @Filter

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 32 > 0 SELECT [@AssignmentID] = @AssignmentID, [@DimensionName] = @DimensionName, [@StorageTypeBM_Dimension] = @StorageTypeBM_Dimension, [@Filter] = @Filter
					
					SELECT 
						@Filter = @Filter + [Dimension_MemberKey] + ','
					FROM 
						#AssignmentRow
					WHERE
						AssignmentID = @AssignmentID AND
						DimensionName = @DimensionName

					UPDATE #AssignmentFilter
					SET
						[Filter] = @Filter
					WHERE
						AssignmentID = @AssignmentID AND
						[DimensionName] = @DimensionName

					FETCH NEXT FROM AssignmentFilter_Cursor1 INTO @AssignmentID, @DimensionName, @StorageTypeBM_DataClass, @StorageTypeBM_Dimension, @Filter
				END

		CLOSE AssignmentFilter_Cursor1
		DEALLOCATE AssignmentFilter_Cursor1

		IF @DebugBM & 16 > 0 SELECT Step= 37, [Time]= CONVERT(time(7), GetDate() - @StartTime)

		IF CURSOR_STATUS('global','AssignmentFilter_Cursor2') >= -1 DEALLOCATE AssignmentFilter_Cursor2
		DECLARE AssignmentFilter_Cursor2 CURSOR FOR
			
			SELECT DISTINCT
				[DimensionName],
				[StorageTypeBM_DataClass],
				[StorageTypeBM_Dimension],
				[Filter]
			FROM
				#AssignmentFilter

			OPEN AssignmentFilter_Cursor2
			FETCH NEXT FROM AssignmentFilter_Cursor2 INTO @DimensionName, @StorageTypeBM_DataClass, @StorageTypeBM_Dimension, @Filter

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 32 > 0 SELECT [@DimensionName] = @DimensionName, [@StorageTypeBM_DataClass] = @StorageTypeBM_DataClass, [@StorageTypeBM_Dimension] = @StorageTypeBM_Dimension, [@Filter] = @Filter
					
					IF @StorageTypeBM_DataClass & 2 > 0
						BEGIN
							SET @SQLStatement = 'spGet_LeafLevelFilter @UserID = ' + CONVERT(nvarchar(10), @UserID) + ', @InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ', @VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ', @DatabaseName = ''' + @CallistoDatabase + ''', @DimensionName = ''' + @DimensionName + ''', @Filter = ''' + @Filter + ''', @StorageTypeBM = ' + CONVERT(nvarchar(10), @StorageTypeBM_Dimension) + ', @LeafLevelFilter = @LeafLevelFilter OUT'
							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							IF @DebugBM & 2 > 0 SELECT UserID = @UserID, InstanceID = @InstanceID, VersionID = @VersionID, DatabaseName = @CallistoDatabase, DimensionName = @DimensionName, [Filter] = @Filter, StorageTypeBM = @StorageTypeBM_Dimension, LeafLevelFilter = @LeafLevelFilter
							EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @CallistoDatabase, @DimensionName = @DimensionName, @Filter = @Filter, @StorageTypeBM = @StorageTypeBM_Dimension, @LeafLevelFilter = @LeafLevelFilter OUT
						END
					ELSE IF @StorageTypeBM_DataClass & 4 > 0
						EXEC spGet_LeafLevelFilter @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @DatabaseName = @CallistoDatabase, @DimensionName = @DimensionName, @Filter = @Filter, @StorageTypeBM = @StorageTypeBM_Dimension, @StorageTypeBM_DataClass = 4, @LeafLevelFilter = @LeafLevelFilter OUT

					IF @DebugBM & 32 > 0 SELECT DimensionName = @DimensionName, [Filter] = @Filter, LeafLevelFilter = @LeafLevelFilter

					UPDATE #AssignmentFilter
					SET
						[LeafLevelFilter] = @LeafLevelFilter
					WHERE
						[DimensionName] = @DimensionName AND
						[StorageTypeBM_Dimension] = @StorageTypeBM_Dimension AND
						[Filter] = @Filter
					
					FETCH NEXT FROM AssignmentFilter_Cursor2 INTO @DimensionName, @StorageTypeBM_DataClass, @StorageTypeBM_Dimension, @Filter
				END

		CLOSE AssignmentFilter_Cursor2
		DEALLOCATE AssignmentFilter_Cursor2


		IF @DebugBM & 1 > 0 SELECT TempTable = '#AssignmentFilter', * FROM #AssignmentFilter

		IF @DebugBM & 16 > 0 SELECT Step= 40, [Time]= CONVERT(time(7), GetDate() - @StartTime)
		
	SET @Step = 'Assignment Cursor'
		IF CURSOR_STATUS('global','AssignmentWorkflowState_Cursor') >= -1 DEALLOCATE AssignmentWorkflowState_Cursor
		DECLARE AssignmentWorkflowState_Cursor CURSOR FOR
			
			SELECT
				ACT.AssignmentID,
				ACT.AssignmentName,
				ACT.WorkflowID,
				ACT.WorkflowName,
				CT.TableNo,
				ACT.StorageTypeBM,
				ACT.DataClassID
			FROM
				#AssignmentCursorTable ACT
				INNER JOIN #DCtable_Cursor_Table CT ON CT.DataClassID = ACT.DataClassID AND CT.WorkFlowID = ACT.WorkflowID
			ORDER BY
				AssignmentID

			OPEN AssignmentWorkflowState_Cursor
			FETCH NEXT FROM AssignmentWorkflowState_Cursor INTO @AssignmentID, @AssignmentName, @WorkflowID, @WorkflowName, @TableNo, @StorageTypeBM_DataClass, @DataClassID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @LoopNo = @LoopNo + 1
					IF @DebugBM & 2 > 0 SELECT  [@AssignmentID] = @AssignmentID, [@AssignmentName] = @AssignmentName, [@WorkflowID] = @WorkflowID, [@WorkflowName] = @WorkflowName, [@TableNo] = @TableNo, [@StorageTypeBM_DataClass] = @StorageTypeBM_DataClass, [@DataClassID] = @DataClassID, [@LoopNo] = @LoopNo

/*
					IF @StorageTypeBM_DataClass & 2 > 0
						BEGIN
							SET @FilterString = ''
							SELECT
								@FilterString = @FilterString + AF.[DimensionName] + '_MemberKey IN (' + AF.[LeafLevelFilter] + ') AND '
							FROM
								#AssignmentFilter AF
								INNER JOIN DataClass_Dimension DC ON DC.DataClassID = @DataClassID AND DC.DimensionID = AF.DimensionID AND DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID
							WHERE
								AF.[AssignmentID] = @AssignmentID AND
								LEN(AF.[LeafLevelFilter]) > 0
							ORDER BY
								AF.[DimensionID]

							IF LEN(@FilterString) > 4 SET @FilterString = LEFT(@FilterString, LEN(@FilterString) - 4)

							IF @DebugBM & 2 > 0 SELECT FilterString = @FilterString

							SET @SQLStatement = '
								INSERT INTO #WorkflowStatus
									(
									WorkflowID,
									WorkflowName,
									AssignmentID,
									AssignmentName,
									[WorkflowStateID],
									ChangeableYN,
									NoOfItems
									)
								SELECT DISTINCT
									WorkflowID = ' + CONVERT(nvarchar(10), @WorkflowID) + ',
									WorkflowName = ''' + REPLACE(@WorkflowName, '''', '''''') + ''',
									AssignmentID = ' + CONVERT(nvarchar(10), @AssignmentID) + ',
									AssignmentName = ''' + REPLACE(@AssignmentName, '''', '''''') + ''',
									[WorkflowStateID] = DC.[WorkflowStateID],
									ChangeableYN = 1,
									NoOfItems = COUNT(1)
								FROM
									pcINTEGRATOR_Data..test_' + CONVERT(nvarchar(15), @DataClassID) + ' DC
									INNER JOIN WorkflowState WFS ON WFS.WorkflowStateID = DC.WorkflowStateID AND WFS.WorkflowID = ' + CONVERT(nvarchar(10), @WorkflowID) + ' 
								' + CASE WHEN LEN(@FilterString) > 0 THEN 'WHERE ' + @FilterString ELSE '' END + '
								GROUP BY
									DC.[WorkflowStateID]'
							
							IF @DebugBM & 1 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)		

						END
					ELSE
*/					
					IF @StorageTypeBM_DataClass & 4 > 0
						BEGIN
							SET @FilterString = ''
							SELECT
								@FilterString = @FilterString + AF.[DimensionName] + '_MemberId IN (' + AF.[LeafLevelFilter] + ') AND '
							FROM
								#AssignmentFilter AF
								INNER JOIN DataClass_Dimension DC ON DC.DataClassID = @DataClassID AND DC.DimensionID = AF.DimensionID AND DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID
							WHERE
								AF.[AssignmentID] = @AssignmentID AND
								LEN(AF.[LeafLevelFilter]) > 0 AND
								AF.[LeafLevelFilter] <> '-999'
							ORDER BY
								AF.[DimensionID]

							IF LEN(@FilterString) > 4 SET @FilterString = LEFT(@FilterString, LEN(@FilterString) - 4)

							IF @DebugBM & 2 > 0 SELECT FilterString = @FilterString

							SET @SQLStatement = '
								INSERT INTO #WorkflowStatus
									(
									WorkflowID,
									WorkflowName,
									AssignmentID,
									AssignmentName,
									[WorkflowStateID],
									ChangeableYN,
									NoOfItems
									)
								SELECT DISTINCT
									WorkflowID = ' + CONVERT(nvarchar(10), @WorkflowID) + ',
									WorkflowName = ''' + REPLACE(@WorkflowName, '''', '''''') + ''',
									AssignmentID = ' + CONVERT(nvarchar(10), @AssignmentID) + ',
									AssignmentName = ''' + REPLACE(@AssignmentName, '''', '''''') + ''',
									[WorkflowStateID] = DC.[WorkflowState_MemberId],
									ChangeableYN = 1,
									NoOfItems = COUNT(1)
								FROM
									#DC' + CONVERT(nvarchar(15), @TableNo) + ' DC
								WHERE
									1 = 1
								' + CASE WHEN LEN(@FilterString) > 0 THEN 'AND ' + @FilterString ELSE '' END + '
								GROUP BY
									DC.[WorkflowState_MemberId]'

							IF @DebugBM & 1 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)		
						END

					IF @DebugBM & 16 > 0 SELECT Step= 50, [LoopNo] = @LoopNo, [Time]= CONVERT(time(7), GetDate() - @StartTime)

					FETCH NEXT FROM AssignmentWorkflowState_Cursor INTO  @AssignmentID, @AssignmentName, @WorkflowID, @WorkflowName, @TableNo, @StorageTypeBM_DataClass, @DataClassID
				END

		CLOSE AssignmentWorkflowState_Cursor
		DEALLOCATE AssignmentWorkflowState_Cursor	

		IF @DebugBM & 16 > 0 SELECT Step= 60, [Time]= CONVERT(time(7), GetDate() - @StartTime)

	SET @Step = 'Return rows'
		SELECT DISTINCT
			WFS.WorkflowID,
			WorkflowName,
			AssignmentID,
			AssignmentName,
			WFS.[WorkflowStateID],
			WS.WorkflowStateName,
			ChangeableYN = CASE WHEN WFSC.[FromWorkflowStateID] IS NULL THEN 0 ELSE 1 END,
			NoOfItems
		FROM
			#WorkflowStatus WFS
			INNER JOIN pcINTEGRATOR_Data..WorkflowState WS ON WS.WorkflowStateID = WFS.WorkflowStateID AND WS.WorkflowID = WFS.[WorkflowID] 
			LEFT JOIN [pcINTEGRATOR].[dbo].[WorkflowStateChange] WFSC ON WFSC.[FromWorkflowStateID] = WFS.[WorkflowStateID] AND WFSC.[UserChangeableYN] <> 0
		ORDER BY
			AssignmentID,
			WFS.[WorkflowStateID]

	SET @Step = 'Drop temp tables'
		DROP TABLE #AssignmentRow
		DROP TABLE #MissingDimension
		DROP TABLE #AssignmentCursorTable
		DROP TABLE #AssignmentFilter
		DROP TABLE #WorkflowStatus

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
