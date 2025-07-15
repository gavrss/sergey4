SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Tabular_View_Dimension]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DataClassID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000513,
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
EXEC [spSetup_Tabular_View_Dimension] @UserID = -10, @InstanceID = -1318, @VersionID = -1256, @DataClassID = 6318, @DebugBM = 3 --AccountPayable
EXEC [spSetup_Tabular_View_Dimension] @UserID = -10, @InstanceID = -1318, @VersionID = -1256, @DataClassID = 6320, @DebugBM = 3 --Financials
EXEC [spSetup_Tabular_View_Dimension] @UserID = -10, @InstanceID = -1318, @VersionID = -1256, @DataClassID = 6321, @DebugBM = 3 --Sales

EXEC [spSetup_Tabular_View_Dimension] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DimensionID int = NULL,
	@DimensionName nvarchar(100),
	@ViewName nvarchar(100),
	@SQLStatement nvarchar(max),
	@SQLProperty nvarchar(4000),
	@StorageTypeBM int,
	@SourceDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@Action nvarchar(10),
	@FixedLevelsYN bit,
	@TopNode_MemberID int,

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
	@Version nvarchar(50) = '2.0.2.2148'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Create dimension views for Tabular.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'

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

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT
			@ETLDatabase = ETLDatabase
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND 
			VersionID = @VersionID

		IF @DebugBM & 2 > 0 SELECT [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@ETLDatabase] = @ETLDatabase

	SET @Step = 'Create temp tables'
		CREATE TABLE #PropertyName (PropertyName nvarchar(255))
		CREATE TABLE #ValidColumn (ColumnName nvarchar(255))

	SET @Step = 'Loop all dimensions for selected DataClass'
		SELECT DISTINCT
			[DimensionID] = DCD.[DimensionID],
			[DimensionName] = D.[DimensionName],
			[ViewName] = 'vw_Tab_pcD_' + D.[DimensionName],
			[StorageTypeBM] = DST.[StorageTypeBM],
			[FixedLevelsYN] = ISNULL(DH.[FixedLevelsYN], 0)
		INTO
			#DC_Dimension_Cursor
		FROM
			DataClass_Dimension DCD
			INNER JOIN Dimension_StorageType DST ON DST.InstanceID = DCD.InstanceID AND DST.VersionID = DCD.VersionID AND DST.DimensionID = DCD.DimensionID
			INNER JOIN Dimension D ON D.InstanceID IN (0, DCD.InstanceID) AND D.DimensionID = DCD.DimensionID AND D.ReportOnlyYN = 0 AND D.SelectYN <> 0
			INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID AND DT.DimensionTypeGroupID <> 3
			LEFT JOIN DimensionHierarchy DH ON DH.InstanceID IN (0, DCD.InstanceID) AND DH.DimensionID = DCD.DimensionID AND DH.HierarchyNo = 0
		WHERE
			DCD.InstanceID = @InstanceID AND
			DCD.VersionID = @VersionID AND
			DCD.DataClassID = @DataClassID

		IF @DebugBM & 2 > 0 SELECT * FROM #DC_Dimension_Cursor ORDER BY [DimensionID]

		IF CURSOR_STATUS('global','DC_Dimension_Cursor') >= -1 DEALLOCATE DC_Dimension_Cursor
		DECLARE DC_Dimension_Cursor CURSOR FOR
			SELECT 
				[DimensionID],
				[DimensionName],
				[ViewName],
				[StorageTypeBM],
				[FixedLevelsYN]
			FROM
				#DC_Dimension_Cursor
			ORDER BY
				DimensionID
				
			OPEN DC_Dimension_Cursor
			FETCH NEXT FROM DC_Dimension_Cursor INTO @DimensionID, @DimensionName, @ViewName, @StorageTypeBM, @FixedLevelsYN

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SELECT
						@SourceDatabase = CASE WHEN @StorageTypeBM & 4 > 0 THEN DestinationDatabase ELSE CASE WHEN @StorageTypeBM & 2 > 0 THEN ETLDatabase ELSE NULL END END
					FROM
						[Application]
					WHERE
						InstanceID = @InstanceID AND 
						VersionID = @VersionID

					SET @TopNode_MemberID = CASE WHEN @DimensionID = -1 THEN 290 ELSE 1 END

					IF @DebugBM & 2 > 0 SELECT [@SourceDatabase] = @SourceDatabase, [@ETLDatabase] = @ETLDatabase, [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@ViewName] = @ViewName, [@StorageTypeBM] = @StorageTypeBM, [@FixedLevelsYN] = @FixedLevelsYN, [@TopNode_MemberID] = @TopNode_MemberID
					
					TRUNCATE TABLE #ValidColumn

					IF @StorageTypeBM & 4 > 0
						SET @SQLStatement = '
							INSERT INTO #ValidColumn ([ColumnName])
							SELECT
								[ColumnName] = c.[name]
							FROM
								' + @SourceDatabase + '.sys.tables t
								INNER JOIN ' + @SourceDatabase + '.sys.columns c ON c.object_id = t.object_id
							WHERE
								t.[name] = ''S_DS_' + @DimensionName + ''''
					ELSE IF @StorageTypeBM & 2 > 0
						SET @SQLStatement = '
							INSERT INTO #ValidColumn ([ColumnName])
							SELECT
								[ColumnName] = c.[name]
							FROM
								' + @SourceDatabase + '.sys.tables t
								INNER JOIN ' + @SourceDatabase + '.sys.columns c ON c.object_id = t.object_id
							WHERE
								t.[name] = ''pcD_' + @DimensionName + ''''

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					
					SET @SQLProperty = ''
							
					TRUNCATE TABLE #PropertyName

					INSERT INTO #PropertyName
						(
						PropertyName
						)
					SELECT DISTINCT --Selected properties
						PropertyName = '[' + P.PropertyName + ']'
					FROM
						Dimension_Property DP
						INNER JOIN Property P ON P.PropertyID = DP.PropertyID
						INNER JOIN #ValidColumn VC ON VC.ColumnName = P.PropertyName
					WHERE
						DP.InstanceID IN (0, @InstanceID) AND
						DP.DimensionID = @DimensionID AND
						DP.TabularYN <> 0 AND
						DP.SelectYN <> 0 AND
						NOT EXISTS (SELECT 1 FROM #PropertyName PN WHERE PN.PropertyName = P.PropertyName)

					IF @FixedLevelsYN <> 0
						BEGIN
							INSERT INTO #PropertyName
								(
								PropertyName
								)
							SELECT
								sub.PropertyName
							FROM
								(
								SELECT DISTINCT --Levels for hierarchy
									PropertyName = '[' + DHL.LevelName + ']'
								FROM
									DimensionHierarchyLevel DHL 
									INNER JOIN #ValidColumn VC ON VC.ColumnName = DHL.LevelName
									INNER JOIN Property P ON P.InstanceID IN (0, @InstanceID) AND P.PropertyName = DHL.LevelName AND P.SelectYN <> 0
									INNER JOIN Dimension_Property DP ON DP.DimensionID = @DimensionID AND DP.PropertyID = P.PropertyID
								WHERE
									DHL.InstanceID IN (0, @InstanceID) AND 
									DHL.DimensionID = @DimensionID AND
									DHL.LevelNo <> 1 AND
									DHL.LevelName <> @DimensionName

								UNION SELECT DISTINCT --Timedate, specific for tabular
									PropertyName = '[TimeDate] = DATEADD(day,-1,DATEADD(month,1,DATEFROMPARTS(D.[MemberId] / 100, D.[MemberId] % 100, 1)))'
								WHERE
									@DimensionID = -7

								UNION SELECT DISTINCT --Timedate, specific for tabular
									PropertyName = '[TimeDate] = DATEFROMPARTS(D.[MemberId] / 10000, (D.[MemberId] / 100) % 100, D.[MemberId] % 100)'
								WHERE
									@DimensionID = -49
								) sub
							WHERE
								NOT EXISTS (SELECT 1 FROM #PropertyName PN WHERE PN.PropertyName = sub.PropertyName)
						END

					SELECT
						@SQLProperty = @SQLProperty + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + PropertyName + ','
					FROM
						#PropertyName 

					IF @DebugBM & 2 > 0 SELECT [@SQLProperty] = @SQLProperty

					--Determine CREATE or ALTER
					SET @SQLStatement = '
						SELECT @InternalVariable = CASE WHEN COUNT(1) > 0 THEN ''ALTER'' ELSE ''CREATE'' END FROM ' + @ETLDatabase + '.sys.views WHERE [name] = ''' + @ViewName + ''''
					EXEC sp_executesql @SQLStatement, N'@internalVariable nvarchar(10) OUT', @InternalVariable = @Action OUT

					IF @DebugBM & 2 > 0 SELECT [@Action] = @Action

					SET @SQLStatement = '
' + @Action + ' VIEW [dbo].[' + @ViewName + '] AS

	-- Current Version: ' + @Version + '
	-- Created: ' + CONVERT(nvarchar(100), @StartTime) + '
	'

					--Create View
					IF @StorageTypeBM & 4 > 0 --Callisto
						BEGIN
							IF @FixedLevelsYN = 0 SET @SQLStatement = @SQLStatement + '
	WITH 
	Hierarchy0 AS
	(
		SELECT t.MemberId, ParentMemberId = CAST(NULL as bigint), [Path] = CAST(NULL AS varchar(MAX)), Depth = 0, SortOrder = t.SequenceNumber 
		FROM [' + @SourceDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @DimensionName + '] t WHERE t.MemberId = ' + CONVERT(nvarchar(15), @TopNode_MemberID) + '
		UNION ALL
		SELECT p.MemberId, p.ParentMemberId, Path = ISNULL(c.[Path] + ''''|'''', '''''''') + CAST(p.MemberId AS varchar(MAX)), Depth = c.Depth + 1, SortOrder = (c.Depth + 1) * 10000 + p.SequenceNumber
		FROM [' + @SourceDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + @DimensionName + '] p 
		INNER JOIN Hierarchy0 c on c.MemberId = p.ParentMemberId
	)'

							SET @SQLStatement = @SQLStatement + '
	SELECT 
		D.[MemberId],
		[' + @DimensionName + '] = CASE WHEN ISNUMERIC([Label]) <> 0 THEN [Label] + '''' - '''' + [Description] ELSE [Label] END,
		[Description],' + @SQLProperty
								
							IF @FixedLevelsYN = 0 SET @SQLStatement = @SQLStatement + '
		[HierarchyPath0] = H0.Path, 
		[HierarchyDepth0] = H0.Depth, 
		[SortOrder0] = H0.SortOrder,'

							SET @SQLStatement = @SQLStatement + '
		[Updated] = GetDate(),
		[UserName] = suser_name()
	FROM
		[' + @SourceDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D'

							IF @FixedLevelsYN = 0 SET @SQLStatement = @SQLStatement + '
		INNER JOIN Hierarchy0 H0 ON H0.MemberId = D.MemberId AND H0.Depth > 0'

							SET @SQLStatement = @SQLStatement + '
	WHERE
		D.MemberID <> 1'

							IF @FixedLevelsYN <> 0 SET @SQLStatement = @SQLStatement + ' AND
		D.RNodeType LIKE ''''L%'''''								

							IF @DimensionID IN (-7, -49) SET @SQLStatement = @SQLStatement + ' AND
		D.MemberID <> -1'
						END
					ELSE IF @StorageTypeBM & 2 > 0 --V2
						BEGIN
							IF @FixedLevelsYN = 0 SET @SQLStatement = @SQLStatement + '
	WITH 
	Hierarchy0 AS
	(
		SELECT t.MemberId, ParentMemberId = NULL, [Path] = CAST(NULL AS varchar(MAX)), Depth = 0, SortOrder = t.SortOrder 
		FROM [' + @SourceDatabase + '].[dbo].[pcD_' + @DimensionName + '] t WHERE t.MemberId = ' + CONVERT(nvarchar(15), @TopNode_MemberID) + '
		UNION ALL
		SELECT p.MemberId, p.ParentMemberId, Path = ISNULL(c.[Path] + ''''|'''', '''''''') + CAST(p.MemberId AS varchar(MAX)), Depth = c.Depth + 1, SortOrder = (c.Depth + 1) * 10000 + p.SortOrder
		FROM [' + @SourceDatabase + '].[dbo].[pcD_' + @DimensionName + '] p 
		INNER JOIN Hierarchy0 c on c.MemberId = p.ParentMemberId
	)'

							SET @SQLStatement = @SQLStatement + '
	SELECT 
		D.[MemberId],
		[' + @DimensionName + '] = CASE WHEN ISNUMERIC([MemberKey]) <> 0 THEN [MemberKey] + '''' - '''' + [Description] ELSE [MemberKey] END,
		[Description],' + @SQLProperty

							IF @FixedLevelsYN = 0 SET @SQLStatement = @SQLStatement + '
		[HierarchyPath0] = H0.Path, 
		[HierarchyDepth0] = H0.Depth, 
		[SortOrder0] = H0.SortOrder,'

							SET @SQLStatement = @SQLStatement + '
		[Updated],
		[UserName] = U.[UserNameDisplay]
	FROM
		[' + @SourceDatabase + '].[dbo].[pcD_' + @DimensionName + '] D
		LEFT JOIN pcINTEGRATOR..[User] U ON U.UserID = D.UserID'

							IF @FixedLevelsYN = 0 SET @SQLStatement = @SQLStatement + '
		INNER JOIN Hierarchy0 H0 ON H0.MemberId = D.MemberId AND H0.Depth > 0'

							SET @SQLStatement = @SQLStatement + '
	WHERE
		D.MemberID <> 1'

							IF @FixedLevelsYN <> 0 SET @SQLStatement = @SQLStatement + ' AND
		D.NodeTypeBM & 1 > 0'

							IF @DimensionID IN (-7, -49) SET @SQLStatement = @SQLStatement + ' AND
		D.MemberID <> -1'
						END

					SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM DC_Dimension_Cursor INTO @DimensionID, @DimensionName, @ViewName, @StorageTypeBM, @FixedLevelsYN
				END

		CLOSE DC_Dimension_Cursor
		DEALLOCATE DC_Dimension_Cursor	

	SET @Step = 'Drop temp tables'
		DROP TABLE #PropertyName
		DROP TABLE #ValidColumn

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
