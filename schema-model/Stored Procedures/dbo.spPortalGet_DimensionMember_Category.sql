SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_DimensionMember_Category]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL,
	@ShowMemberIdYN bit = 0,
	@ShowDescriptionYN bit = 0,
	@ResultTypeBM int = 7,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000801,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--
--OBS
--OBSOLETE, replaced by [spPortalGet_DimensionMember_List]

AS
/*
EXEC [spPortalGet_DimensionMember_Category]
	@UserID = -10,
	@InstanceID = 531,
	@VersionID = 1041,
	@DimensionID = 9155,
	@ShowMemberIdYN = 0,
	@ShowDescriptionYN = 0,
	@ResultTypeBM = 7

EXEC [spPortalGet_DimensionMember_Category] @UserID = -10,@InstanceID = 531,@VersionID = 1041,@DimensionID = 9155,@ShowMemberIdYN = 0,@ShowDescriptionYN = 1,@ResultTypeBM = 2

EXEC [spPortalGet_DimensionMember_Category] @UserID = -10,@InstanceID = 531,@VersionID = 1041,@DimensionID = 9155,@ShowMemberIdYN = 0,@ShowDescriptionYN = 0,@ResultTypeBM = 4
EXEC [spPortalGet_DimensionMember_Category] @UserID = -10,@InstanceID = 531,@VersionID = 1041,@DimensionID = 9155,@ShowMemberIdYN = 1,@ShowDescriptionYN = 0,@ResultTypeBM = 4
EXEC [spPortalGet_DimensionMember_Category] @UserID = -10,@InstanceID = 531,@VersionID = 1041,@DimensionID = 9155,@ShowMemberIdYN = 0,@ShowDescriptionYN = 1,@ResultTypeBM = 4

EXEC [spPortalGet_DimensionMember_Category] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CallistoDatabase nvarchar(100),
	@DimensionName nvarchar(50),
	@SQLStatement nvarchar(max),
	@ColumnCode nchar(3),
	@SubDimensionName nvarchar(50),
	@DimensionTypeID int,
	@NodeTypeBM_ExistYN bit,

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
	@Version nvarchar(50) = '2.1.2.2179'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get leaf dimension members showing Category parents in columns.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2175' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2179' SET @Description = 'Added SortOrder in temp table #Column.'

		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
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

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0

		SELECT
			@DimensionName = [DimensionName],
			@DimensionTypeID = [DimensionTypeID]
		FROM
			[Dimension]
		WHERE
			[InstanceID] IN (0, @InstanceID) AND
			[DimensionID] = @DimensionID

		
		SET @SQLStatement = '
			SELECT 
				@InternalVariable = COUNT(1)
			FROM
				[' + @CallistoDatabase + '].[sys].[tables] t
				INNER JOIN [' + @CallistoDatabase + '].[sys].[columns] c ON c.object_id = t.object_id AND c.name = ''NodeTypeBM''
			WHERE
				t.name = ''S_DS_' + @DimensionName + ''''

		IF @DebugBM & 2 > 0 PRINT @SQLStatement

		EXEC sp_executesql @SQLStatement, N'@InternalVariable bit OUT', @InternalVariable = @NodeTypeBM_ExistYN OUT

		IF @DebugBM & 2 > 0
			SELECT
				[@CallistoDatabase] = @CallistoDatabase,
				[@DimensionName] = @DimensionName,
				[@DimensionTypeID] = @DimensionTypeID,
				[@NodeTypeBM_ExistYN] = @NodeTypeBM_ExistYN

	SET @Step = 'Create temp table #Column'
		CREATE TABLE #Column
			(
			[ColumnCode] nchar(3) COLLATE DATABASE_DEFAULT,
			[ColumnName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[DimensionID] int,
			[DimensionName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)

	SET @Step = 'Fill temp table #Column'
		IF @ResultTypeBM & 7 > 0
			BEGIN
				EXEC [spGet_Category_Column]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@DimensionID = @DimensionID,
					@JobID = @JobID
			END

	SET @Step = 'ResultTypeBM=1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 1,
					[ColumnCode],
					[ColumnName]
				FROM
					#Column
				ORDER BY
					[SortOrder],
					[ColumnCode]
			END

	SET @Step = 'ResultTypeBM=2'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				IF CURSOR_STATUS('global','Segment_Cursor') >= -1 DEALLOCATE Segment_Cursor
				DECLARE Segment_Cursor CURSOR FOR
			
					SELECT 
						[ColumnCode],
						[DimensionName]
					FROM
						#Column
					WHERE
						[ColumnCode] LIKE 'D%'
					ORDER BY
						[ColumnCode]

					OPEN Segment_Cursor
					FETCH NEXT FROM Segment_Cursor INTO @ColumnCode, @SubDimensionName

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@ColumnCode] = @ColumnCode, [@SubDimensionName] = @SubDimensionName

							SET @SQLStatement = '
								SELECT 
									[ResultTypeBM] = 2,
									[ColumnCode] = ''' + @ColumnCode + ''',
									[MemberId] = D.[MemberId],
									[MemberKey] = D.[Label],
									[Description] = D.[Description]
								FROM
									[' + @CallistoDatabase + '].[dbo].[S_DS_' + @SubDimensionName + '] D
								WHERE
									[RNodeType] LIKE ''L%''
								ORDER BY
									[Label]'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Selected = @Selected + @@ROWCOUNT

							FETCH NEXT FROM Segment_Cursor INTO @ColumnCode, @SubDimensionName
						END

				CLOSE Segment_Cursor
				DEALLOCATE Segment_Cursor

				SET @SQLStatement = '
					SELECT 
						[ResultTypeBM] = 2,
						[ColumnCode] = ''H'',
						[MemberId] = D.[MemberId],
						[MemberKey] = D.[Label],
						[Description] = D.[Description]
					FROM
						[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D
					WHERE
						' + CASE WHEN @NodeTypeBM_ExistYN <> 0 THEN '[NodeTypeBM] & 1024 > 0' ELSE '1=2' END + '
					ORDER BY
						[Label]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'ResultTypeBM=4'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				CREATE TABLE #ColumnType
					(
					SortOrder int,
					ColumnType nvarchar(20)
					)

				IF @ShowMemberIdYN <> 0
					INSERT INTO #ColumnType
						(
						[SortOrder],
						[ColumnType]
						)
					SELECT
						[SortOrder] = 1,
						[ColumnType] = 'MemberId'

				INSERT INTO #ColumnType
					(
					[SortOrder],
					[ColumnType]
					)
				SELECT
					[SortOrder] = 2,
					[ColumnType] = 'MemberKey'

				IF @ShowDescriptionYN <> 0
					INSERT INTO #ColumnType
						(
						[SortOrder],
						[ColumnType]
						)
					SELECT
						[SortOrder] = 3,
						[ColumnType] = 'Description'

				SET @SQLStatement = '
					SELECT 
						[ResultTypeBM] = 4,' + CASE WHEN @ShowMemberIdYN <> 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) +'[MemberId] = D.[MemberId],' ELSE '' END + '           
						[MemberKey] = D.[Label],
						[Description] = D.[Description],
						[HelpText] = D.[HelpText],'

				SELECT
					@SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + C.[ColumnCode] + '_' + CT.[ColumnType] + '] = ' + CASE CT.[SortOrder] WHEN 2 THEN 'D.[' + C.[ColumnName] + ']' WHEN 3 THEN '[' + C.[ColumnCode] + '].[' + CT.[ColumnType] + ']' ELSE 'D.[' + C.[ColumnName] + '_' + CT.[ColumnType] + ']' END + ','
				FROM
					#Column C
					INNER JOIN #ColumnType CT ON 1 = 1
				WHERE
					LEFT(ColumnCode, 1) IN ('D')
				ORDER BY
					C.[ColumnCode],
					CT.[SortOrder]

				SELECT
					@SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + C.[ColumnCode] + '_' + CT.[ColumnType] + '] = [' + C.[ColumnCode] + '].[Category_' + CT.[ColumnType] + '],'
				FROM
					#Column C
					INNER JOIN #ColumnType CT ON 1 = 1
				WHERE
					LEFT(ColumnCode, 1) IN ('H')
				ORDER BY
					C.[ColumnCode],
					CT.[SortOrder]

				SELECT
					@SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + C.[ColumnCode] + '] = D.[' + C.[ColumnName] + '],'
				FROM
					#Column C
				WHERE
					LEFT(ColumnCode, 1) IN ('P')
				ORDER BY
					C.[ColumnCode]

				SET @SQLStatement = LEFT(@SQLStatement, LEN(@SQLStatement) - 1)

				SET @SQLStatement = @SQLStatement + '
					FROM
						[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D'

				IF @ShowDescriptionYN <> 0
					SELECT
						@SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LEFT JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + C.[DimensionName] + '] [' + C.[ColumnCode] + '] ON [' + C.[ColumnCode] + '].[MemberId] = D.[' + C.[DimensionName] + '_MemberId]' 
					FROM
						#Column C
					WHERE
						LEFT(ColumnCode, 1) IN ('D')
					ORDER BY
						C.[ColumnCode]

				SELECT
					@SQLStatement = @SQLStatement + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LEFT JOIN
							(
							SELECT
								[MemberId] = H.[MemberId],
								[Category_MemberId] = H.[ParentMemberId],
								[Category_MemberKey] = D.[Label],
								[Category_Description] = D.[Description]
							FROM
								[' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + C.[ColumnName] + '] H
								INNER JOIN [' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + '] D ON D.[NodeTypeBM] & 1024 > 0 AND D.[MemberId] = H.[ParentMemberId]
							) [' + C.[ColumnCode] + '] ON [' + C.[ColumnCode] + '].[MemberId] = D.[MemberId]'
				FROM
					#Column C
				WHERE
					LEFT(ColumnCode, 1) IN ('H')
				ORDER BY
					C.[ColumnCode]

				SET @SQLStatement = @SQLStatement + '
					WHERE
						' + CASE WHEN @NodeTypeBM_ExistYN <> 0 THEN 'D.[NodeTypeBM] & 1 > 0' ELSE 'D.[RNodeType]=''L''' END + '
					ORDER BY
						D.[Label]'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #Column
		IF @ResultTypeBM & 4 > 0 DROP TABLE #ColumnType

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
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
