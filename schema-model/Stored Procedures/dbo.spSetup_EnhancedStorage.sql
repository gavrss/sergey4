SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_EnhancedStorage]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ETLDatabase nvarchar(100) = NULL,
	@CallistoDatabase nvarchar(100) = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000864,
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
EXEC [dbo].[spSetup_EnhancedStorage] @UserID = -10, @InstanceID = -1714, @VersionID = -1714 --NEHA2

EXEC [spSetup_EnhancedStorage] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DimensionName nvarchar(100),
	@TableName nvarchar(100),
	@SQLStatement nvarchar(max),
	@Property nvarchar(100),
	@DataType nvarchar(100),
	@DefaultValue nvarchar(255),
	@DimensionID int,
	@Collation nvarchar(50),
	@PropertyExists int,
	@HierarchyTableName nvarchar(100),
	@HierarchyName nvarchar(100),
	@DataClassID int,
	@DataClassName nvarchar(100),
	@DataClassTableName nvarchar(100),
	@TextYN bit,
	@ColumnName nvarchar(100),
	@ColumnNameExists int,

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
	@Version nvarchar(50) = '2.1.2.2191'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup or Alter storage for EnhancedStorage.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2191' SET @Description = 'Procedure created.'

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

		IF @ETLDatabase IS NULL OR @CallistoDatabase IS NULL
			SELECT
				@ETLDatabase = ISNULL(@ETLDatabase, [ETLDatabase]),
				@CallistoDatabase = ISNULL(@CallistoDatabase, [DestinationDatabase])
			FROM
				[Application]
			WHERE
				[InstanceID] = @InstanceID AND
				[VersionID] = @VersionID AND
				[SelectYN] <> 0
		
		IF @DebugBM & 2 > 0
			SELECT
				[@ETLDatabase] = @ETLDatabase,
				[@CallistoDatabase] = @CallistoDatabase

	SET @Step = 'Create databases'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @Collation = @Collation OUTPUT

		IF DB_ID (@ETLDatabase) IS NULL
			BEGIN
				SET @SQLStatement = 'CREATE DATABASE ' + @ETLDatabase + ' COLLATE ' + @Collation + ' ALTER DATABASE ' + @ETLDatabase + ' SET RECOVERY SIMPLE'
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

		EXEC [spSet_JournalTable] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @StorageTypeBM = 2, @DebugBM = @DebugSub, @JobID = @JobID

		IF DB_ID(@CallistoDatabase) IS NULL
			BEGIN
				SET @SQLStatement = 'CREATE DATABASE ' + @CallistoDatabase + ' COLLATE ' + @Collation + ' ALTER DATABASE ' + @CallistoDatabase + ' SET RECOVERY SIMPLE'
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END	

	SET @Step = 'Create dimension tables and hierarchies'	
		IF CURSOR_STATUS('global','Dim_Cursor') >= -1 DEALLOCATE Dim_Cursor
		DECLARE Dim_Cursor CURSOR FOR
			SELECT
				D.DimensionID,
				D.DimensionName
			FROM
				pcINTEGRATOR_Data..Dimension_StorageType DST
				INNER JOIN Dimension D ON D.InstanceID IN (0, DST.InstanceID) AND D.DimensionID = DST.DimensionID AND D.SelectYN <> 0 AND D.DeletedID IS NULL
			WHERE
				DST.InstanceID = @InstanceID AND
				DST.VersionID = @VersionID AND
				DST.StorageTypeBM & 4 > 0
			ORDER BY
				D.DimensionID
			
			OPEN Dim_Cursor
			FETCH NEXT FROM Dim_Cursor INTO @DimensionID, @DimensionName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @TableName = '[' + @CallistoDatabase + '].[dbo].[S_DS_' + @DimensionName + ']'
					IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@TableName] = @TableName

					IF object_id(@TableName) IS NULL
						BEGIN
							SET @SQLStatement = '
								CREATE TABLE ' + @TableName + '
								(
									[MemberId] [bigint] NULL,
									[Label] [nvarchar](255) NOT NULL,
									[Description] [nvarchar](512) NOT NULL,
									[HelpText] [nvarchar](1024) NULL,
									[RNodeType] [nvarchar](2) NULL,
									[SBZ] [bit] NOT NULL DEFAULT ((0)),
									[Source] [nvarchar](50) NOT NULL DEFAULT (N''ETL''),
									[Synchronized] [bit] NOT NULL DEFAULT ((1)),
									[Inserted] [datetime] NOT NULL DEFAULT (getdate()),
									[Updated] [datetime] NOT NULL DEFAULT (getdate()),
									[JobID] [int] NOT NULL DEFAULT ((0)),

								CONSTRAINT [PK_' + @DimensionName + '_Label_Clustered] PRIMARY KEY CLUSTERED 
								(
									[Label] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @SQLStatement = '
								CREATE NONCLUSTERED INDEX [' + @DimensionName + '_MemberId_Nonclustered] ON ' + @TableName + '
								(
									[MemberId] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
						END

			--Add dimension specific properties
					IF CURSOR_STATUS('global','AddDimProperty_Cursor') >= -1 DEALLOCATE AddDimProperty_Cursor
					DECLARE AddDimProperty_Cursor CURSOR FOR
						SELECT
							Property,
							DataType,
							DefaultValue
						FROM
							(
							SELECT 
								SortOrder = P.SortOrder,
								Property = P.PropertyName,
								DataType = CASE P.DataTypeID WHEN 3 THEN 'nvarchar(255)' ELSE DT.DataTypeCode + CASE WHEN DT.SizeYN <> 0 AND P.Size IS NOT NULL THEN '(' + CONVERT(nvarchar(15), P.Size) + ') COLLATE DATABASE_DEFAULT' ELSE '' END END,
								DefaultValue = CASE P.DataTypeID WHEN 3 THEN 'NONE' ELSE CASE WHEN ISNUMERIC(P.DefaultValueTable) <> 0 THEN P.DefaultValueTable ELSE '''' + P.DefaultValueTable + '''' END END
							FROM
								Property P
								INNER JOIN Dimension_Property DP ON DP.InstanceID IN(0, @InstanceID) AND DP.VersionID IN(0, @VersionID) AND DP.DimensionID IN (@DimensionID) AND DP.PropertyID = P.PropertyID AND DP.SelectYN <> 0
								INNER JOIN DataType DT ON DT.DataTypeID = P.DataTypeID
							WHERE
								P.InstanceID IN(0, @InstanceID) AND 
								P.SelectYN <> 0
							UNION SELECT 
								SortOrder = P.SortOrder,
								Property = P.PropertyName + '_MemberID',
								DataType = 'bigint',
								DefaultValue = '-1'
							FROM
								Property P
								INNER JOIN Dimension_Property DP ON DP.InstanceID IN(0, @InstanceID) AND DP.VersionID IN(0, @VersionID) AND DP.DimensionID IN (@DimensionID) AND DP.PropertyID = P.PropertyID AND DP.SelectYN <> 0
								INNER JOIN DataType DT ON DT.DataTypeID = P.DataTypeID
							WHERE
								P.InstanceID IN(0, @InstanceID) AND 
								P.DataTypeID = 3 AND
								P.SelectYN <> 0
							) sub
						ORDER BY
							sub.SortOrder,
							sub.Property
				
						OPEN AddDimProperty_Cursor
						FETCH NEXT FROM AddDimProperty_Cursor INTO @Property, @DataType, @DefaultValue

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@Property] = @Property, [@DataType] = @DataType

								SET @SQLStatement = '
									SELECT @InternalVariable = COUNT(1)
									FROM [' + @CallistoDatabase + '].[sys].[columns] 
									WHERE [name] = ''' + @Property + ''' AND Object_ID = Object_ID(''' + @TableName + ''')'

								IF @DebugBM & 32 > 0 PRINT @SQLStatement

								EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @PropertyExists OUT

								IF @PropertyExists = 0
									BEGIN
										SET @SQLStatement = 'ALTER TABLE ' + @TableName + ' ADD [' + @Property + '] ' + @DataType

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)

										IF @DefaultValue IS NOT NULL
											BEGIN
												SET @SQLStatement = 'ALTER TABLE ' + @TableName + ' ADD CONSTRAINT [Dim_' + @DimensionName + '_' + @Property + '] DEFAULT (''' + REPLACE(@DefaultValue, '''', '') + ''') FOR [' + @Property + ']'

												IF @DebugBM & 2 > 0 PRINT @SQLStatement
												EXEC (@SQLStatement)
											END
									END

								FETCH NEXT FROM AddDimProperty_Cursor INTO @Property, @DataType, @DefaultValue
							END

					CLOSE AddDimProperty_Cursor
					DEALLOCATE AddDimProperty_Cursor	

				--Add hierarchy tables
					IF CURSOR_STATUS('global','HierarchyTable_Cursor') >= -1 DEALLOCATE HierarchyTable_Cursor
					DECLARE HierarchyTable_Cursor CURSOR FOR

						SELECT DISTINCT
							[HierarchyTableName] = '[' + @CallistoDatabase + '].[dbo].[S_HS_' + @DimensionName + '_' + DH.HierarchyName + ']',
							[HierarchyName] = DH.HierarchyName
						FROM
							[pcINTEGRATOR].[dbo].[DimensionHierarchy] DH
						WHERE
							DH.InstanceID IN (0, @InstanceID) AND
							DH.VersionID IN (0, @VersionID) AND
							DH.DimensionID = @DimensionID	
						
						OPEN HierarchyTable_Cursor
						FETCH NEXT FROM HierarchyTable_Cursor INTO @HierarchyTableName, @HierarchyName

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@HierarchyTableName] = @HierarchyTableName, [@HierarchyName] = @HierarchyName

								IF object_id(@HierarchyTableName) IS NULL
									BEGIN
										SET @SQLStatement = '
											CREATE TABLE ' + @HierarchyTableName + '
											(
												[MemberId] [bigint] NOT NULL,
												[ParentMemberId] [bigint] NOT NULL,
												[SequenceNumber] [bigint] NOT NULL,

											CONSTRAINT [PK_' + @DimensionName + '_' + @HierarchyName + '] PRIMARY KEY CLUSTERED 
											(
												[MemberId] ASC
											)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
											) ON [PRIMARY]'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)

									END

								FETCH NEXT FROM HierarchyTable_Cursor INTO @HierarchyTableName, @HierarchyName
							END

					CLOSE HierarchyTable_Cursor
					DEALLOCATE HierarchyTable_Cursor	

					FETCH NEXT FROM Dim_Cursor INTO  @DimensionID, @DimensionName
				END

		CLOSE Dim_Cursor
		DEALLOCATE Dim_Cursor	

	SET @Step = 'Create FACT tables'
		IF CURSOR_STATUS('global','DC_Table_Cursor') >= -1 DEALLOCATE DC_Table_Cursor
		DECLARE DC_Table_Cursor CURSOR FOR

			SELECT
				[DataClassID],
				[DataClassName],
				[DataClassTableName],
				[TextYN]
			FROM
				(
				SELECT
					[DataClassID] = DC.[DataClassID],
					[DataClassName] = DC.[DataClassName],
					[DataClassTableName] = '[' + @CallistoDatabase + '].[dbo].[FACT_' + DC.[DataClassName] + '_default_partition]',
					[TextYN] = 0
				FROM
					[pcINTEGRATOR_Data].[dbo].[DataClass] DC
				WHERE
					DC.[InstanceID] = @InstanceID AND
					DC.[VersionID] = @VersionID AND
					DC.[StorageTypeBM] & 4 > 0 AND
					DC.[SelectYN] <> 0 AND
					DC.[DeletedID] IS NULL

				UNION SELECT
					[DataClassID] = DC.[DataClassID],
					[DataClassName] = DC.[DataClassName],
					[DataClassTableName] = '[' + @CallistoDatabase + '].[dbo].[FACT_' + DC.[DataClassName] + '_text]',
					[TextYN] = 1
				FROM
					[pcINTEGRATOR_Data].[dbo].[DataClass] DC
				WHERE
					DC.[InstanceID] = @InstanceID AND
					DC.[VersionID] = @VersionID AND
					DC.[StorageTypeBM] & 4 > 0 AND
					DC.[SelectYN] <> 0 AND
					DC.[DeletedID] IS NULL AND
					DC.[TextSupportYN] <> 0
				) sub
			ORDER BY
				[DataClassTableName]
						
			OPEN DC_Table_Cursor
			FETCH NEXT FROM DC_Table_Cursor INTO @DataClassID, @DataClassName, @DataClassTableName, @TextYN

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@DataClassID] = @DataClassID, [@DataClassName] = @DataClassName, [@DataClassTableName] = @DataClassTableName, [@TextYN] = @TextYN

					IF object_id(@DataClassTableName) IS NULL
						BEGIN
							SET @SQLStatement = '
								CREATE TABLE ' + @DataClassTableName + '
								(
									[ChangeDatetime] [datetime] NOT NULL DEFAULT (getdate()),
									[UserId] [nvarchar](100) NOT NULL DEFAULT (suser_name())
								) ON [PRIMARY]'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
						END

			--Add columns
					IF CURSOR_STATUS('global','AddDC_Column_Cursor') >= -1 DEALLOCATE AddDC_Column_Cursor
					DECLARE AddDC_Column_Cursor CURSOR FOR
						SELECT
							[ColumnName],
							[DataType],
							[DefaultValue]
						FROM
							(
							SELECT DISTINCT
								[SortOrder] = DCD.SortOrder,
								[ColumnName] = D.[DimensionName] + '_MemberId',
								[DataType] = 'bigint',
								[DefaultValue] = '-1'
							FROM
								[pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD
								INNER JOIN [Dimension] D ON D.InstanceID IN (0, DCD.[InstanceID]) AND D.[DimensionID] = DCD.[DimensionID] AND D.[DimensionTypeID] <> 27
								INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST ON DST.[InstanceID] = DCD.[InstanceID] AND DST.VersionID = DCD.[VersionID] AND DST.[DimensionID] = DCD.[DimensionID] AND DST.[StorageTypeBM] & 4 > 0
							WHERE
								DCD.[InstanceID] = @InstanceID AND
								DCD.[VersionID] = @VersionID AND
								DCD.[DataClassID] = @DataClassID AND
								DCD.[SelectYN] <> 0

							UNION SELECT DISTINCT
								[SortOrder] = 100000,
								[ColumnName] = M.[MeasureName] + '_Value',
								[DataType] = 'float',
								[DefaultValue] = '0'
							FROM
								[pcINTEGRATOR_Data].[dbo].[Measure] M
							WHERE
								M.[InstanceID] = @InstanceID AND
								M.[VersionID] = @VersionID AND
								M.[DataClassID] = @DataClassID AND
								M.[SelectYN] <> 0 AND
								M.[DeletedID] IS NULL AND
								@TextYN = 0

							UNION SELECT DISTINCT
								[SortOrder] = 100000,
								[ColumnName] = @DataClassName + '_Text',
								[DataType] = 'nvarchar(4000)',
								[DefaultValue] = NULL
							WHERE
								@TextYN <> 0
							) sub
						ORDER BY
							SortOrder
				
						OPEN AddDC_Column_Cursor
						FETCH NEXT FROM AddDC_Column_Cursor INTO @ColumnName, @DataType, @DefaultValue

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@ColumnName] = @ColumnName, [@DataType] = @DataType

								SET @SQLStatement = '
									SELECT @InternalVariable = COUNT(1)
									FROM [' + @CallistoDatabase + '].[sys].[columns] 
									WHERE [name] = ''' + @ColumnName + ''' AND Object_ID = Object_ID(''' + @DataClassTableName + ''')'

								IF @DebugBM & 32 > 0 PRINT @SQLStatement

								EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @ColumnNameExists OUT

								IF @ColumnNameExists = 0
									BEGIN
										SET @SQLStatement = 'ALTER TABLE ' + @DataClassTableName + ' ADD [' + @ColumnName + '] ' + @DataType

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)

										IF @DefaultValue IS NOT NULL
											BEGIN
												SET @SQLStatement = 'ALTER TABLE ' + @DataClassTableName + ' ADD CONSTRAINT [DC_' + @DataClassName + CASE WHEN @TextYN <> 0 THEN '_Text' ELSE '' END + '_' + @ColumnName + '] DEFAULT (''' + REPLACE(@DefaultValue, '''', '') + ''') FOR [' + @ColumnName + ']'

												IF @DebugBM & 2 > 0 PRINT @SQLStatement
												EXEC (@SQLStatement)
											END
									END

								FETCH NEXT FROM AddDC_Column_Cursor INTO @ColumnName, @DataType, @DefaultValue
							END

					CLOSE AddDC_Column_Cursor
					DEALLOCATE AddDC_Column_Cursor	

					FETCH NEXT FROM DC_Table_Cursor INTO @DataClassID, @DataClassName, @DataClassTableName, @TextYN
				END

		CLOSE DC_Table_Cursor
		DEALLOCATE DC_Table_Cursor	

	SET @Step = 'Create FACT views'	
		EXEC [dbo].[spSetup_Fact_View] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @Debug = @DebugSub
	
	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
