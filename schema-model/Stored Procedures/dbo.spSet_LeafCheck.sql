SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_LeafCheck]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@Database nvarchar(100) = NULL,
	@Dimension nvarchar(100) = NULL,
	@Hierarchy nvarchar(100) = NULL,
	@DimensionTemptable nvarchar(100) = NULL,
	@ParentColumn nvarchar(50) = N'Parent',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000189,
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
	@ProcedureName = 'spSet_LeafCheck',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spSet_LeafCheck] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spSet_LeafCheck] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@CalledYN bit = 1,
	@SQLStatement nvarchar(max),
	@MasterMemberId bigint,
	@MemberId bigint,
	@CheckID int = 0,
	@MaxCheckID int = 100,
	@HasChild bit = 0,

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
	@Version nvarchar(50) = '2.0.1.2143'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Checking for parents without any children',
			@MandatoryParameter = 'Database|Dimension' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created and moved from pcETL to pcINTEGRATOR.'

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

		SET @DimensionTemptable = ISNULL(@DimensionTemptable, '#' + @Dimension + '_Members')
		SET @Hierarchy = ISNULL(@Hierarchy, @Dimension)

	SET @Step = 'Create temp table #LeafCheck.'
		IF OBJECT_ID (N'tempdb..#LeafCheck', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0
				CREATE TABLE #LeafCheck
					(
					[MemberId] [bigint] NOT NULL,
					HasChild bit NOT NULL
					)
			END

	SET @Step = 'Create temp table #Check.'
		CREATE TABLE #Check
			(
			[CheckID] [int] IDENTITY(1,1) NOT NULL,
			[MemberId] [bigint] NOT NULL,
			[Label] [nvarchar](50) COLLATE DATABASE_DEFAULT NOT NULL,
			[RNodeType] [nvarchar](2) COLLATE DATABASE_DEFAULT NOT NULL
			)

	SET @Step = 'Fill temp table #LeafCheck.'
		SET @SQLStatement = '
		INSERT INTO #LeafCheck
			(
			MemberId,
			HasChild
			)
		SELECT
			MemberId = D1.MemberId,
			HasChild = CONVERT(bit, 0)
		FROM
			' + @Database + '.[dbo].[S_DS_' + @Dimension + '] D1
			INNER JOIN [' + @DimensionTemptable + '] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label AND (V.[' + @ParentColumn + '] IS NULL OR V.[' + @ParentColumn + '] <> ''-10'')
			LEFT JOIN ' + @Database + '.[dbo].[S_DS_' + @Dimension + '] D2 ON D2.Label = CONVERT(nvarchar(255), V.[' + @ParentColumn + ']) COLLATE DATABASE_DEFAULT
		WHERE
			NOT EXISTS (SELECT 1 FROM ' + @Database + '.[dbo].[S_HS_' + @Dimension + '_' + @Hierarchy + '] H WHERE H.MemberId = D1.MemberId) AND
			[D1].[Synchronized] <> 0 AND
			D1.MemberId <> ISNULL(D2.MemberId, 0) AND
			D1.MemberId IS NOT NULL AND
			(D2.MemberId IS NOT NULL OR D1.Label = ''All_'' OR V.[' + @ParentColumn + '] IS NULL) AND
			(D1.RNodeType IN (''P'', ''PC''))
		ORDER BY
			D1.Label'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Create cursor to update temp table #LeafCheck.'
		IF CURSOR_STATUS('global','LeafCheck_Cursor') >= -1 DEALLOCATE LeafCheck_Cursor
		DECLARE LeafCheck_Cursor CURSOR FOR
			SELECT 
				MasterMemberId = MemberId,
				MemberId
			FROM
				#LeafCheck
			ORDER BY
				MemberId

			OPEN LeafCheck_Cursor
			FETCH NEXT FROM LeafCheck_Cursor INTO @MasterMemberId, @MemberId

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT MasterMemberId = @MasterMemberId

					WHILE @HasChild = 0 AND @CheckID <= @MaxCheckID
						BEGIN
							SET @SQLStatement = '
								INSERT INTO #Check 
									(
									MemberId,
									Label,
									RNodeType) 
								SELECT
									D1.MemberId,
									D1.Label,
									D1.RNodeType
								FROM 
									' + @Database + '.[dbo].[S_DS_' + @Dimension + '] D1
									INNER JOIN [' + @DimensionTemptable + '] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
									INNER JOIN ' + @Database + '.[dbo].[S_DS_' + @Dimension + '] D2 ON D2.Label = CONVERT(nvarchar(255), V.[' + @ParentColumn + ']) COLLATE DATABASE_DEFAULT
								WHERE
									NOT EXISTS (SELECT 1 FROM ' + @Database + '.[dbo].[S_HS_' + @Dimension + '_' + @Hierarchy + '] HS WHERE HS.MemberID = D1.MemberID) AND
									D2.MemberId = ' + CONVERT(nvarchar(10), @MemberID)

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SELECT @MaxCheckID = MAX(CheckID) FROM #Check

							IF @Debug <> 0
								BEGIN
									SELECT * FROM #Check
									SELECT MasterMemberId = @MasterMemberId, MemberId = @MemberId, CheckID = @CheckID, MaxCheckID = @MaxCheckID
								END

							IF (SELECT COUNT(1) FROM #Check WHERE CheckID BETWEEN @CheckID AND @MaxCheckID AND RNodeType IN ('L', 'LC')) > 0
								BEGIN
									SET @HasChild = 1
									UPDATE #LeafCheck SET HasChild = @HasChild WHERE MemberId = @MasterMemberId
									IF @Debug <> 0 SELECT MemberId = @MasterMemberId, HasChild = @HasChild
									TRUNCATE TABLE #Check
								END
							ELSE
								BEGIN
									SET @CheckID = @CheckID + 1
									SELECT @MemberId = MemberId FROM #Check WHERE CheckID = @CheckID
								END

						END
					TRUNCATE TABLE #Check
					SET @CheckID = 0
					SET @MaxCheckID = 100
					SET @HasChild = 0
					FETCH NEXT FROM LeafCheck_Cursor INTO @MasterMemberId, @MemberId
				END

		CLOSE LeafCheck_Cursor
		DEALLOCATE LeafCheck_Cursor	

		IF @Debug <> 0 SELECT * FROM #LeafCheck ORDER BY MemberId

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Check
		IF @CalledYN = 0 DROP TABLE #LeafCheck

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

--	SET @Step = 'Insert into JobLog'
--		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
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
