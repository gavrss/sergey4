SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spIU_Dim_Dimension_Generic_Raw]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DimensionID int = NULL,
	@DimensionName nvarchar(100) = NULL,
	@StorageTypeBM int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000656,
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

AS
/*
EXEC [spIU_Dim_Dimension_Generic_Raw] @UserID = -10, @InstanceID = 561, @VersionID = 1071, @DimensionID = 5605,  @StorageTypeBM = 4,  @DebugBM = 7
EXEC [spIU_Dim_Dimension_Generic_Raw] @UserID = -10, @InstanceID = 15, @VersionID = 1039, @DimensionID = -55, @StorageTypeBM = 4, @Debug = 1
EXEC [spIU_Dim_Dimension_Generic_Raw] @UserID = -10, @InstanceID = 454, @VersionID = 1021, @DimensionID = -64, @Debug = 1
EXEC [spIU_Dim_Dimension_Generic_Raw] @UserID = -10, @InstanceID = -1059, @VersionID = -1057, @DimensionName = 'GL_Posted', @Debug = 1
EXEC [spIU_Dim_Dimension_Generic_Raw] @UserID = -10, @InstanceID = 515, @VersionID = 1040, @DimensionID = 9094, @DebugBM = 3
EXEC [spIU_Dim_Dimension_Generic_Raw] @UserID=-10, @InstanceID=529, @VersionID=1001, @DimensionID=-9, @DebugBM=7

EXEC [spIU_Dim_Dimension_Generic_Raw] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF
--SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@CalledYN bit = 1,
	@SourceTypeBM int,
	@PropertyName nvarchar (100),
	@RefDimensionID int,
	@RefDimensionName nvarchar (100),
	@AddString nvarchar (255),
	@SQLStatement nvarchar(max),
	@SQLStatement_Insert nvarchar(2000) = '',
	@SQLStatement_Select nvarchar(2000) = '',
	@SQLStatement_SelectSub nvarchar(2000) = '',
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get list of static dimension members for selected Dimension.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2148' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Handle multiple hierarchies.'
		IF @Version = '2.1.0.2159' SET @Description = '@SourceTypeBM defaulted to 1024'
		IF @Version = '2.1.0.2161' SET @Description = 'Changed prefix in the SP name.'
		IF @Version = '2.1.0.2162' SET @Description = 'Handle missing properties.'
		IF @Version = '2.1.0.2165' SET @Description = 'Set missing properties to -1.'
		IF @Version = '2.1.2.2178' SET @Description = 'Handle existence of NodeTypeBM as Property in the dimension table.'
		IF @Version = '2.1.2.2199' SET @Description = 'For static rows, handle member [Description] ending in ''y''. Updated to latest SP template.'

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
			@CallistoDatabase = [DestinationDatabase],
			@ETLDatabase = [ETLDatabase]
		FROM
			pcINTEGRATOR_Data.dbo.[Application] A
		WHERE
			A.[InstanceID] = @InstanceID AND
			A.[VersionID] = @VersionID AND
			A.[SelectYN] <> 0

		IF @DimensionName IS NULL
			SELECT @DimensionName = DimensionName FROM [Dimension] WHERE DimensionID = @DimensionID
		ELSE IF @DimensionID IS NULL
			SELECT @DimensionID = DimensionID FROM [Dimension] WHERE DimensionName = @DimensionName	AND InstanceID IN (0, @InstanceID)	

		SELECT
			@SourceTypeBM = SUM(SourceTypeBM)
		FROM
			(
			SELECT DISTINCT
				SourceTypeBM
			FROM
				SourceType ST
				INNER JOIN [Source] S ON S.InstanceID = @InstanceID AND S.VersionID = @VersionID AND S.SourceTypeID = ST.SourceTypeID
			) sub

		SET @SourceTypeBM = ISNULL(@SourceTypeBM, 1024)

		IF OBJECT_ID (N'tempdb..#Dimension_Generic_Members', N'U') IS NULL SET @CalledYN = 0

		IF @Debug <> 0 SELECT [@CallistoDatabase] = @CallistoDatabase, [@ETLDatabase] = @ETLDatabase, [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@CalledYN] = @CalledYN, [@StorageTypeBM] = @StorageTypeBM, [@SourceTypeBM] = @SourceTypeBM

	SET @Step = 'Create temp table #Dimension_Generic_Members_Raw'
		CREATE TABLE [#Dimension_Generic_Members_Raw]
			(
			[MemberId] bigint,
			[MemberKey] nvarchar (100) COLLATE DATABASE_DEFAULT,
			[Description] nvarchar (512) COLLATE DATABASE_DEFAULT,
			[HelpText] nvarchar (1024) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[HierarchyNo] int
			)

	SET @Step = 'If needed, create temp table #PropertyColumn'
		IF OBJECT_ID(N'TempDB.dbo.#PropertyColumn', N'U') IS NULL
			BEGIN
				CREATE TABLE #PropertyColumn
					(
					[DimensionID] int,
					[PropertyID] int,
					[PropertyName] nvarchar (100) COLLATE DATABASE_DEFAULT,
					[ColumnName] nvarchar (100) COLLATE DATABASE_DEFAULT,
					[DefaultValue] nvarchar (255) COLLATE DATABASE_DEFAULT,
					[AddString] nvarchar (255) COLLATE DATABASE_DEFAULT,
					[SortOrder] int IDENTITY (1,1)
					)

				INSERT INTO #PropertyColumn
					(
					[DimensionID],
					[PropertyID],
					[PropertyName],
					[ColumnName],
					[DefaultValue],
					[AddString]
					)
				SELECT 
					[DimensionID] = P.[DependentDimensionID],
					[PropertyID] = DP.[PropertyID],
					[PropertyName] = P.PropertyName,
					[ColumnName] = P.PropertyName,
					[DefaultValue] = P.[DefaultValueTable],
					[AddString] = '[' + P.[PropertyName] + '] ' + DT.[DataTypeCode] + CASE WHEN DT.[SizeYN] = 0 THEN '' ELSE ' (' + CONVERT(nvarchar(15), ISNULL(P.[Size], 100)) + ') COLLATE DATABASE_DEFAULT' END
				FROM
					Dimension_Property DP
					INNER JOIN Property P ON P.[InstanceID] IN (0, @InstanceID) AND P.[PropertyID] = DP.[PropertyID] AND P.[SelectYN] <> 0
					INNER JOIN DataType DT ON DT.[DataTypeID] = P.[DataTypeID]
				WHERE
					DP.[InstanceID] IN (0, @InstanceID) AND
					DP.VersionID IN (0, @VersionID) AND
					DP.DimensionID = @DimensionID AND
					DP.[SelectYN] <> 0
				UNION
				SELECT 
					[DimensionID] = P.[DependentDimensionID],
					[PropertyID] = DP.[PropertyID],
					[PropertyName] = P.PropertyName,
					[ColumnName] = P.PropertyName + '_MemberId',
					[DefaultValue] = NULL,
					[AddString] = '[' + P.[PropertyName] + '_MemberId] bigint'
				FROM
					Dimension_Property DP
					INNER JOIN Property P ON P.[InstanceID] IN (0, @InstanceID) AND P.[PropertyID] = DP.[PropertyID] AND P.[SelectYN] <> 0 AND P.[DataTypeID] = 3
				WHERE
					DP.[InstanceID] IN (0, @InstanceID) AND
					DP.VersionID IN (0, @VersionID) AND
					DP.DimensionID = @DimensionID AND
					DP.[SelectYN] <> 0
				ORDER BY
					PropertyName,
					DimensionID

				IF @DebugBM & 2 > 0 SELECT TempTable = '#PropertyColumn', * FROM #PropertyColumn ORDER BY SortOrder
			END

	SET @Step = 'Add columns to temp table [#Dimension_Generic_Members_Raw]'
		IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
		DECLARE AddColumn_Cursor CURSOR FOR
			SELECT
				AddString
			FROM
				#PropertyColumn
			WHERE
				PropertyName NOT IN ('MemberId', 'MemberKey', 'Description', 'HelpText', 'NodeTypeBM', 'HierarchyNo', 'Source', 'Parent')
			ORDER BY
				SortOrder

			OPEN AddColumn_Cursor
			FETCH NEXT FROM AddColumn_Cursor INTO @AddString

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = 'ALTER TABLE #Dimension_Generic_Members_Raw ADD ' + REPLACE(@AddString, ' bit', ' int')

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM AddColumn_Cursor INTO @AddString
				END

		CLOSE AddColumn_Cursor
		DEALLOCATE AddColumn_Cursor	

		ALTER TABLE #Dimension_Generic_Members_Raw ADD [Source] nvarchar (50) COLLATE DATABASE_DEFAULT
		ALTER TABLE #Dimension_Generic_Members_Raw ADD [Parent] nvarchar (255) COLLATE DATABASE_DEFAULT

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension_Generic_Members_Raw', * FROM #Dimension_Generic_Members_Raw

	SET @Step = 'Static Rows'
		SELECT
			@SQLStatement_Insert = @SQLStatement_Insert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + PropertyName + '],',
			@SQLStatement_Select = @SQLStatement_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + PropertyName + '] = ISNULL(MAX(CASE WHEN MPV.[PropertyID] = ' + CONVERT(nvarchar(15), [PropertyID]) + ' THEN REPLACE(MPV.[Value], '''''''', '''') END), ''' + ISNULL([DefaultValue], -1) + '''),'
		FROM
			(
			SELECT
				[PropertyName],
				[PropertyID],
				[DefaultValue],
				[SortOrder] = MIN([SortOrder])
			FROM
				#PropertyColumn
			WHERE
				[PropertyID] IS NOT NULL AND
				[PropertyName] NOT IN ('MemberId', 'MemberKey', 'Description', 'HelpText', 'NodeTypeBM', 'HierarchyNo', 'Source', 'Parent')
			GROUP BY
				[PropertyName],
				[PropertyID],
				[DefaultValue]
			) sub
		ORDER BY
			sub.SortOrder

		IF @DebugBM & 2 > 0 SELECT [@SQLStatement_Insert] = @SQLStatement_Insert, [@SQLStatement_Select] = @SQLStatement_Select

		SET @SQLStatement = '
			INSERT INTO [#Dimension_Generic_Members_Raw]
				(
				[MemberId],
				[MemberKey],
				[Description],
				[HelpText],
				[NodeTypeBM],
				[HierarchyNo],' + @SQLStatement_Insert + '
				[Source],
				[Parent]
				)
			SELECT 
				[MemberId] = MAX(M.[MemberId]),
				[MemberKey] = [Label],
				--[Description] = MAX(REPLACE([Description], ''@All_Dimension'', ''All ' + @DimensionName + 's'')),
				[Description] = MAX(REPLACE([Description], ''@All_Dimension'', ''All ' + CASE WHEN RIGHT(@DimensionName, 1) = 'y' THEN LEFT(@DimensionName, LEN(@DimensionName) - 1) + 'ie' ELSE @DimensionName END + 's'')),
				[HelpText] = MAX([HelpText]),
				[NodeTypeBM] = MAX([NodeTypeBM]),
				[HierarchyNo] = MAX([HierarchyNo]),' + @SQLStatement_Select + '
				[Source] = ''ETL'',
				[Parent] = MAX([Parent])
			FROM 
				Member M
				LEFT JOIN [Member_Property_Value] MPV ON MPV.[DimensionID] = M.[DimensionID] AND MPV.[MemberId] = M.[MemberId]
			WHERE
				M.[DimensionID] IN (0, ' + CONVERT(nvarchar(15), @DimensionID) + ') AND
				M.[SourceTypeBM] & ' + CONVERT(nvarchar(15), @SourceTypeBM) + ' > 0 AND
				M.[SelectYN] <> 0
			GROUP BY
				M.[Label]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Selected = @@ROWCOUNT
		IF @Debug <> 0 SELECT Step = @Step, Selected = @Selected

	SET @Step = 'Set Referenced Members'
		CREATE TABLE #ReferencedMember ([PropertyName] nvarchar (100) COLLATE DATABASE_DEFAULT, [MemberKey] nvarchar (100) COLLATE DATABASE_DEFAULT, [MemberId] bigint)

			SELECT
				[PropertyName] = PC.[PropertyName],
				[RefDimensionID] = PC.[DimensionID],
				[RefDimensionName] = D.[DimensionName],
				[SortOrder] = MIN(PC.[SortOrder])
			INTO
				#ReferencedMember_Cursor_Table
			FROM
				#PropertyColumn PC
				INNER JOIN [Dimension] D ON D.[InstanceID] IN (0, @InstanceID) AND D.[DimensionID] = PC.[DimensionID]
			WHERE
				PC.[DimensionID] IS NOT NULL
			GROUP BY
				PC.[PropertyName],
				PC.[DimensionID],
				D.[DimensionName]
			ORDER BY
				MIN(PC.[SortOrder])

			IF @DebugBM & 2 > 0 SELECT TempTable = '#ReferencedMember_Cursor_Table', * FROM #ReferencedMember_Cursor_Table ORDER BY [SortOrder]

		IF CURSOR_STATUS('global','ReferencedMember_Cursor') >= -1 DEALLOCATE ReferencedMember_Cursor
		DECLARE ReferencedMember_Cursor CURSOR FOR
			SELECT
				[PropertyName],
				[RefDimensionID],
				[RefDimensionName]
			FROM
				#ReferencedMember_Cursor_Table
			ORDER BY
				[SortOrder]

			OPEN ReferencedMember_Cursor
			FETCH NEXT FROM ReferencedMember_Cursor INTO @PropertyName, @RefDimensionID, @RefDimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@PropertyName] = @PropertyName, [@RefDimensionID] = @RefDimensionID, [@RefDimensionName] = @RefDimensionName

					TRUNCATE TABLE #ReferencedMember 

					IF @StorageTypeBM & 4 > 0
						BEGIN
							IF (
								SELECT 
									COUNT(1)
								FROM 
									Dimension_Property DP
									INNER JOIN Property P ON P.PropertyID = DP.PropertyID AND P.PropertyName = @PropertyName
								WHERE
									DP.DimensionID = @RefDimensionID
								) > 0

								BEGIN
									SET @SQLStatement = '
										INSERT INTO #ReferencedMember 
											(
											[PropertyName],
											[MemberKey],
											[MemberId]
											) 
										SELECT
											[PropertyName] = ''' + @PropertyName + ''',
											[MemberKey] = [Label],
											[MemberId] = [MemberId] 
										FROM
											' + @CallistoDatabase + '..S_DS_' + @RefDimensionName + ' 
										WHERE
											MemberID NOT IN (-1, 1, 2, 1000, 30000000)'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END
						END

					SET @SQLStatement = '
						UPDATE [Raw]
						SET
							[' + @PropertyName + '_MemberId] = ISNULL(RM.MemberID, -1)
						FROM
							[#Dimension_Generic_Members_Raw] [Raw]
							LEFT JOIN #ReferencedMember RM ON RM.PropertyName = ''' + @PropertyName + ''' AND RM.[MemberKey] = [Raw].[' + @PropertyName + ']'

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM ReferencedMember_Cursor INTO @PropertyName, @RefDimensionID, @RefDimensionName
				END

		CLOSE ReferencedMember_Cursor
		DEALLOCATE ReferencedMember_Cursor	

	SET @Step = 'Return data'
		IF @CalledYN = 0
			BEGIN
				SELECT
					TempTable = '#Dimension_Generic_Members_Raw',
					*
				FROM
					#Dimension_Generic_Members_Raw
				ORDER BY
					CASE WHEN [MemberKey] IN ('All_', 'NONE') OR [MemberKey] LIKE '%NONE%' THEN '  ' + [MemberKey] ELSE [MemberKey] END

				SET @Selected = @@ROWCOUNT
			END
		ELSE
			BEGIN
				SELECT
					@SQLStatement_Insert = '',
					@SQLStatement_Select = '',
					@SQLStatement_SelectSub = ''

				SELECT
					@SQLStatement_Insert = @SQLStatement_Insert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '],',
					@SQLStatement_Select = @SQLStatement_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '] = [MaxRaw].[' + ColumnName + '],',
					@SQLStatement_SelectSub = @SQLStatement_SelectSub + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '] = MAX([Raw].[' + ColumnName + ']),'
				FROM
					#PropertyColumn
				WHERE
					[PropertyName] NOT IN ('MemberId', 'MemberKey', 'Description', 'HelpText', 'NodeTypeBM', 'HierarchyNo', 'SBZ', 'Source', 'Synchronized', 'Parent')
				ORDER BY
					[SortOrder]

				SET @SQLStatement = '
					INSERT INTO [#Dimension_Generic_Members]
						(
						[MemberId],
						[MemberKey],
						[Description],
						[HelpText],
						[NodeTypeBM],
						[HierarchyNo],' + @SQLStatement_Insert + '
						[SBZ],
						[Source],
						[Synchronized],
						[Parent]
						)'

				SET @SQLStatement = @SQLStatement + '
					SELECT TOP 1000000
						[MemberId] = ISNULL([MaxRaw].[MemberId], M.MemberID),
						[MemberKey] = [MaxRaw].[MemberKey],
						[Description] = [MaxRaw].[Description],
						[HelpText] = CASE WHEN [MaxRaw].[HelpText] = '''' THEN [MaxRaw].[Description] ELSE [MaxRaw].[HelpText] END,
						[NodeTypeBM] = [MaxRaw].[NodeTypeBM],
						[HierarchyNo] = [MaxRaw].[HierarchyNo],' + @SQLStatement_Select + '
						[SBZ] = [MaxRaw].[SBZ],
						[Source] = [MaxRaw].[Source],
						[Synchronized] = 1,
						[Parent] = CASE [MaxRaw].[Parent] WHEN ''NULL'' THEN NULL ELSE [MaxRaw].[Parent] END'

				SET @SQLStatement = @SQLStatement + '
					FROM
						(
						SELECT
							[MemberId] = MAX([Raw].[MemberId]),
							[MemberKey] = [Raw].[MemberKey],
							[Description] = MAX([Raw].[Description]),
							[HelpText] = MAX([Raw].[HelpText]),
							[NodeTypeBM] = MAX([Raw].[NodeTypeBM]),
							[HierarchyNo] = MAX([Raw].[HierarchyNo]),' + @SQLStatement_SelectSub + '
							[SBZ] = [dbo].[f_GetSBZ2] (' + CONVERT(nvarchar(15), @DimensionID) + ', MAX([Raw].[NodeTypeBM]), [Raw].[MemberKey]),
							[Source] = MAX([Raw].[Source]),
							[Synchronized] = 1,
							[Parent] = MAX([Raw].[Parent])
						FROM
							[#Dimension_Generic_Members_Raw] [Raw]
						GROUP BY
							[Raw].[MemberKey]
						) [MaxRaw]
						LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = ' + CONVERT(nvarchar(15), @DimensionID) + ' AND M.[Label] = [MaxRaw].MemberKey
					WHERE
						[MaxRaw].[MemberKey] IS NOT NULL
					ORDER BY
						CASE WHEN [MaxRaw].[MemberKey] IN (''All_'', ''NONE'') OR [MaxRaw].[MemberKey] LIKE ''%NONE%'' THEN ''  '' + [MaxRaw].[MemberKey] ELSE [MaxRaw].[MemberKey] END'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Selected = @@ROWCOUNT
			END

	SET @Step = 'Drop the temp tables'
		DROP TABLE #Dimension_Generic_Members_Raw
		DROP TABLE #ReferencedMember

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
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
