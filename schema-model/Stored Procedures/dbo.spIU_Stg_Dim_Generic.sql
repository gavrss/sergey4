SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Stg_Dim_Generic]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL,
	@DimensionName nvarchar(100) = NULL,
	@JSON_table nvarchar(max) = NULL,
	@ResultTypeBM int = NULL, --1=Return table structure, 2=Returns existing rows, 4=Insert new rows from @JSON_table or from prepared temp table

	@JobID int = NULL,
	@JobLogID int = NULL,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000768,
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
EXEC [spIU_Stg_Dim_Generic] @UserID = -10, @InstanceID = 515, @VersionID = 1040, @DimensionID = -4, @ResultTypeBM = 1
EXEC [spIU_Stg_Dim_Generic] @UserID = -10, @InstanceID = 515, @VersionID = 1040, @DimensionID = -4, @ResultTypeBM = 2

DECLARE @JSON_table nvarchar(max) = '
		[
		{"MemberKey":"Entity1", "Description":"Entity 1", "Currency":"EUR"},
		{"MemberKey":"Entity2", "Description":"Entity 2", "Currency":"USD"},
		{"MemberKey":"Entity3", "Description":"Entity 3", "Currency":"GBP"}
		]'
EXEC [spIU_Stg_Dim_Generic] @UserID = -10, @InstanceID = 515, @VersionID = 1040, @DimensionID = -4, @ResultTypeBM = 4, @JSON_table = @JSON_table, @DebugBM = 3

EXEC [spIU_Stg_Dim_Generic] @UserID = -10, @InstanceID = 515, @VersionID = 1040, @DimensionID = 7959, @ResultTypeBM = 1

EXEC [spIU_Stg_Dim_Generic] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@ColumnName nvarchar(100),
	@DataType nvarchar(20),
	@SQLInsert nvarchar(2000) = '',
	@SQLSelect nvarchar(2000) = '',
	@SQLWith nvarchar(2000) = '',
	@PropertyID int,
	@CalledYN bit = 0,
	@ETLDatabase nvarchar(100),
	@DimensionMemberTable nvarchar(4000),

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
	@Version nvarchar(50) = '2.1.1.2170'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Adding rows to Staging tables in pcETL.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2170' SET @Description = 'Procedure created.'

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

		SELECT
			@ETLDatabase = [ETLDatabase]
		FROM
			[pcINTEGRATOR].[dbo].[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID AND
			[SelectYN] <> 0

		SELECT
			@DimensionID = ISNULL(@DimensionID, [DimensionID])
		FROM
			[pcINTEGRATOR].[dbo].[Dimension]
		WHERE
			[InstanceID] IN (0, @InstanceID) AND
			[DimensionName] = @DimensionName
		
		SELECT
			@DimensionName = ISNULL(@DimensionName, [DimensionName])
		FROM
			[pcINTEGRATOR].[dbo].[Dimension]
		WHERE
			[InstanceID] IN (0, @InstanceID) AND
			[DimensionID] = @DimensionID
		
		IF @DebugBM & 2 > 0
			SELECT
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@ETLDatabase] = @ETLDatabase

	SET @Step = 'CREATE TABLE #Column'
		CREATE TABLE #Column
			(
			[@DimensionID] int,
			[@DimensionName] nvarchar(100),
			[Column] nvarchar(100),
			[DataType] nvarchar(20),
			[MandatoryYN] bit,
			[PropertyID] int,
			[SortOrder] int IDENTITY(1,1)
			)

		INSERT INTO #Column
			(
			[@DimensionID],
			[@DimensionName],
			[Column],
			[DataType],
			[MandatoryYN]
			)
		SELECT
			[@DimensionID] = @DimensionID,
			[@DimensionName] = @DimensionName,
			[Column] = sub.[Column],
			[DataType] = sub.[DataType],
			[MandatoryYN] = sub.[MandatoryYN]
		FROM
			(
			SELECT
				[Column] = 'Comment',
				[DataType] = 'nvarchar(100)',
				[MandatoryYN] = 0,
				[SortOrder] = 1
			UNION SELECT
				[Column] = 'MemberKey',
				[DataType] = 'nvarchar(100)',
				[MandatoryYN] = 1,
				[SortOrder] = 2
			UNION SELECT
				[Column] = 'Entity',
				[DataType] = 'nvarchar(50)',
				[MandatoryYN] = 0,
				[SortOrder] = 3
			UNION SELECT
				[Column] = 'Description',
				[DataType] = 'nvarchar(255)',
				[MandatoryYN] = 1,
				[SortOrder] = 4
			UNION SELECT
				[Column] = 'LongDescription',
				[DataType] = 'nvarchar(1024)',
				[MandatoryYN] = 0,
				[SortOrder] = 5
			UNION SELECT
				[Column] = 'ParentMemberKey',
				[DataType] = 'nvarchar(100)',
				[MandatoryYN] = 0,
				[SortOrder] = 6
			UNION SELECT
				[Column] = 'SortOrder',
				[DataType] = 'int',
				[MandatoryYN] = 0,
				[SortOrder] = 7
			) sub
		ORDER BY
			sub.[SortOrder]

		INSERT INTO #Column
			(
			[@DimensionID],
			[@DimensionName],
			[Column],
			[DataType],
			[MandatoryYN],
			[PropertyID]
			)
		SELECT
			[@DimensionID] = @DimensionID,
			[@DimensionName] = @DimensionName,
			[Column] = P.[PropertyName],
			[DataType] = CASE WHEN DT.[DataTypeCode] = 'nvarchar' THEN 'nvarchar(100)' ELSE DT.[DataTypeCode] END,
			[MandatoryYN] = 1, --DP.[MandatoryYN],
			[PropertyID] = DP.[PropertyID]
		FROM
			[pcINTEGRATOR].[dbo].[Dimension_Property] DP
			INNER JOIN [pcINTEGRATOR].[dbo].[Property] P ON P.InstanceID IN (0, @InstanceID) AND P.PropertyID = DP.PropertyID AND P.SelectYN <> 0
			INNER JOIN [pcINTEGRATOR].[dbo].[DataType] DT ON DT.DataTypeID = P.DataTypeID
		WHERE
			DP.InstanceID IN (0, @InstanceID) AND
			DP.VersionID IN (0, @VersionID) AND
			DP.DimensionID = @DimensionID AND
			DP.SelectYN <> 0 AND
			NOT EXISTS (SELECT 1 FROM #Column DC WHERE DC.[Column] = P.[PropertyName])
		ORDER BY
			P.PropertyName

	SET @Step = '@ResultTypeBM = 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				SELECT
					[@ResultTypeBM] = 1,
					[@DimensionID],
					[@DimensionName],
					[Column],
					[DataType],
					[MandatoryYN]
				FROM
					#Column
				ORDER BY
					[SortOrder]
			
				SET @DimensionMemberTable = '
CREATE TABLE #DimensionMember
	('

				SELECT
					@DimensionMemberTable = @DimensionMemberTable + CHAR(13) + CHAR(10) + CHAR(9) + '[' + [Column] + '] ' + [DataType] + ','
				FROM
					#Column

				SET @DimensionMemberTable = LEFT(@DimensionMemberTable, LEN(@DimensionMemberTable) - 1)


				SET @DimensionMemberTable = @DimensionMemberTable + CHAR(13) + CHAR(10) + CHAR(9) + ')'
			
				SELECT [@DimensionMemberTable] = @DimensionMemberTable
			END

	SET @Step = 'Create table #DimensionMember'
		IF @ResultTypeBM & 6 > 0
			BEGIN
				IF OBJECT_ID (N'tempdb..#DimensionMember', N'U') IS NOT NULL
					SET @CalledYN = 1
				ELSE
					BEGIN
						CREATE TABLE #DimensionMember
							(
							[Dummy] [int]
							)

						IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
						DECLARE AddColumn_Cursor CURSOR FOR
							SELECT
								[Column],
								[DataType]
							FROM
								#Column
							ORDER BY
								SortOrder

							OPEN AddColumn_Cursor
							FETCH NEXT FROM AddColumn_Cursor INTO @ColumnName, @DataType

							WHILE @@FETCH_STATUS = 0
								BEGIN
									SET @SQLStatement = '
										ALTER TABLE #DimensionMember ADD [' + @ColumnName + '] ' + @DataType

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)

									FETCH NEXT FROM AddColumn_Cursor INTO  @ColumnName, @DataType
								END

						CLOSE AddColumn_Cursor
						DEALLOCATE AddColumn_Cursor	

						IF @DebugBM & 2 > 0 SELECT * FROM #DimensionMember
					END
			END

	SET @Step = 'Return existing rows'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #DimensionMember
						(
						[Comment],
						[MemberKey],
						[Entity],
						[Description],
						[LongDescription],
						[ParentMemberKey],
						[SortOrder]
						)
					SELECT
						[Comment],
						[MemberKey],
						[Entity],
						[Description],
						[LongDescription],
						[ParentMemberKey],
						[SortOrder]
					FROM
						[' + @ETLDatabase + '].[dbo].[Stg_Dim_Member] SDM
					WHERE
						SDM.[DimensionID] = ' + CONVERT(nvarchar(15), @DimensionID)

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @Step = 'Return_Property_Cursor'
					IF CURSOR_STATUS('global','Return_Property_Cursor') >= -1 DEALLOCATE Return_Property_Cursor
					DECLARE Return_Property_Cursor CURSOR FOR
			
						SELECT
							[ColumnName] = [Column],
							[PropertyID]
						FROM
							#Column
						WHERE
							[PropertyID] IS NOT NULL
						ORDER BY
							[PropertyID]

						OPEN Return_Property_Cursor
						FETCH NEXT FROM Return_Property_Cursor INTO @ColumnName, @PropertyID

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@ColumnName] = @ColumnName, [@PropertyID] = @PropertyID

								SET @SQLStatement = '
									UPDATE DM
									SET
										[' + @ColumnName + '] = SDMP.[Value] 
									FROM
										[' + @ETLDatabase + '].[dbo].[Stg_Dim_MemberProperty] SDMP
										INNER JOIN #DimensionMember DM ON DM.[MemberKey] = SDMP.[MemberKey] AND ISNULL(DM.[Entity], '''') = ISNULL(SDMP.[Entity], '''')
									WHERE
										SDMP.[DimensionID] = ' + CONVERT(nvarchar(15), @DimensionID) + ' AND
										SDMP.[PropertyID] = ' + CONVERT(nvarchar(15), @PropertyID) 

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								FETCH NEXT FROM Return_Property_Cursor INTO @ColumnName, @PropertyID
							END

					CLOSE Return_Property_Cursor
					DEALLOCATE Return_Property_Cursor				
				
				SELECT
					[@ResultTypeBM] = 2,
					*
				FROM
					#DimensionMember

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Insert new rows from @JSON_table'
		IF @ResultTypeBM & 4 > 0 
			BEGIN
				IF @JSON_table IS NOT NULL
					BEGIN
						SELECT
							@SQLInsert = @SQLInsert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + [Column] + '],',
							@SQLSelect = @SQLSelect + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + [Column] + '] = [' + [Column] + '],',
							@SQLWith = @SQLWith + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + [Column] + '] ' + [DataType] + ','
						FROM
							#Column
						ORDER BY
							SortOrder

						SELECT
							@SQLInsert = LEFT(@SQLInsert, LEN(@SQLInsert) -1),
							@SQLSelect = LEFT(@SQLSelect, LEN(@SQLSelect) -1),
							@SQLWith = LEFT(@SQLWith, LEN(@SQLWith) -1)

						IF @DebugBM & 2 > 0
							SELECT
								[@SQLInsert] = @SQLInsert,
								[@SQLSelect] = @SQLSelect,
								[@SQLWith] = @SQLWith

						SET @SQLStatement = '

						INSERT INTO #DimensionMember
							(' + @SQLInsert + '
							)
						SELECT' + @SQLInsert + '
						FROM
							OPENJSON(''' + @JSON_table + ''')
						WITH
							(' + @SQLWith + '
							)'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
				
						SELECT @Inserted = @Inserted + @@ROWCOUNT
					END
				ELSE IF @CalledYN = 0
					GOTO NoData

				IF @DebugBM & 8 > 0 SELECT TempTable = '#DimensionMember', * FROM #DimensionMember

				SET @Step = 'Insert new rows into Stg_DimensionMember'
					SET @SQLStatement = '
						INSERT INTO [' + @ETLDatabase + '].[dbo].[Stg_Dim_Member]
							(
							[Comment],
							[DimensionID],
							[MemberKey],
							[Entity],
							[Description],
							[LongDescription],
							[ParentMemberKey],
							[SortOrder]
							)
						SELECT
							[Comment],
							[DimensionID] = ' + CONVERT(nvarchar(15), @DimensionID) + ',
							[MemberKey],
							[Entity] = ISNULL(DM.[Entity], ''''),
							[Description],
							[LongDescription],
							[ParentMemberKey],
							[SortOrder] = ISNULL([SortOrder], 0)
						FROM
							#DimensionMember DM
						WHERE
							NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[Stg_Dim_Member] SDM WHERE SDM.[DimensionID] = ' + CONVERT(nvarchar(15), @DimensionID) + ' AND SDM.[MemberKey] = DM.[MemberKey] AND SDM.[Entity] = ISNULL(DM.[Entity], ''''))'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
					
					SET @Inserted = @Inserted + @@ROWCOUNT

				SET @Step = 'Update rows in Stg_DimensionMember'
					SET @SQLStatement = '
						UPDATE SDM
						SET
							[Comment] = DM.[Comment],
							[Description] = DM.[Description],
							[LongDescription] = DM.[LongDescription],
							[ParentMemberKey] = DM.[ParentMemberKey],
							[SortOrder] = COALESCE(DM.[SortOrder], SDM.[SortOrder], 0)
						FROM
							[' + @ETLDatabase + '].[dbo].[Stg_Dim_Member] SDM
							INNER JOIN #DimensionMember DM ON DM.[MemberKey] = SDM.[MemberKey] AND ISNULL(DM.[Entity], '''') = ISNULL(SDM.[Entity], '''')
						WHERE
							SDM.DimensionID = ' + CONVERT(nvarchar(15), @DimensionID)

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					SET @Updated = @Updated + @@ROWCOUNT

				SET @Step = 'Property_Cursor'
					IF CURSOR_STATUS('global','Property_Cursor') >= -1 DEALLOCATE Property_Cursor
					DECLARE Property_Cursor CURSOR FOR
			
						SELECT
							[ColumnName] = [Column],
							[PropertyID]
						FROM
							#Column
						WHERE
							[PropertyID] IS NOT NULL
						ORDER BY
							[PropertyID]

						OPEN Property_Cursor
						FETCH NEXT FROM Property_Cursor INTO @ColumnName, @PropertyID

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@ColumnName] = @ColumnName, [@PropertyID] = @PropertyID

								SET @SQLStatement = '
									INSERT INTO [' + @ETLDatabase + '].[dbo].[Stg_Dim_MemberProperty]
										(
										[Comment],
										[DimensionID],
										[MemberKey],
										[Entity],
										[PropertyID],
										[Value]
										)
									SELECT
										[Comment],
										[DimensionID] = ' + CONVERT(nvarchar(15), @DimensionID) + ',
										[MemberKey],
										[Entity] = ISNULL(DM.[Entity], ''''),
										[PropertyID] = ' + CONVERT(nvarchar(15), @PropertyID) + ',
										[Value] = DM.[' + @ColumnName + ']
									FROM
										#DimensionMember DM
									WHERE
										DM.[' + @ColumnName + '] IS NOT NULL AND
										NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[Stg_Dim_MemberProperty] SDMP WHERE SDMP.[DimensionID] = ' + CONVERT(nvarchar(15), @DimensionID) + ' AND SDMP.[MemberKey] = DM.[MemberKey] AND ISNULL(SDMP.[Entity], '''') = ISNULL(DM.[Entity], '''') AND SDMP.[PropertyID] = ' + CONVERT(nvarchar(15), @PropertyID) + ')'

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								SET @SQLStatement = '
									UPDATE SDMP
									SET
										[Comment] = DM.[Comment],
										[Value] = [' + @ColumnName + ']
									FROM
										[' + @ETLDatabase + '].[dbo].[Stg_Dim_MemberProperty] SDMP
										INNER JOIN #DimensionMember DM ON DM.[MemberKey] = SDMP.[MemberKey] AND ISNULL(DM.[Entity], '''') = ISNULL(SDMP.[Entity], '''')
									WHERE
										SDMP.[DimensionID] = ' + CONVERT(nvarchar(15), @DimensionID) + ' AND
										SDMP.[PropertyID] = ' + CONVERT(nvarchar(15), @PropertyID) 

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)

								FETCH NEXT FROM Property_Cursor INTO @ColumnName, @PropertyID
							END

					CLOSE Property_Cursor
					DEALLOCATE Property_Cursor				

				NoData:
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #Column
		IF @CalledYN = 0 AND @ResultTypeBM & 6 > 0
			DROP TABLE #DimensionMember
	
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
