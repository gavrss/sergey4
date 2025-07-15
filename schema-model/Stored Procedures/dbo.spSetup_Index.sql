SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spSetup_Index]
	@UserID int = NULL,
	@InstanceID int = NULL, --0 = All
	@VersionID int = NULL, --0 = All

	--SP-specific parameters
	@DataClassID int = NULL,
	@DataClassTypeID int = NULL,
	@CreateIndexYN bit = 1,
	@DropIndexYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000788,
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
EXEC [spSetup_Index] @UserID=-10, @InstanceID=0, @VersionID=0, @Debug=1
EXEC [spSetup_Index] @UserID=-10, @InstanceID=454, @VersionID=1021, @DropIndexYN=0, @CreateIndexYN=0, @Debug=1
EXEC [spSetup_Index] @UserID=-10, @InstanceID=454, @VersionID=1021, @DropIndexYN=1, @CreateIndexYN=0, @Debug=1
EXEC [spSetup_Index] @UserID=-10, @InstanceID=454, @VersionID=1021, @DropIndexYN=0, @CreateIndexYN=1, @Debug=1
EXEC [spSetup_Index] @UserID=-10, @InstanceID=454, @VersionID=1021, @DropIndexYN=1, @CreateIndexYN=1, @Debug=1
EXEC [spSetup_Index] @UserID=-10, @InstanceID=0, @VersionID=0, @DataClassTypeID=-1, @Debug=1

EXEC [spSetup_Index] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@CalledInstanceID int,
	@CalledVersionID int,
	@CalledDataClassID int,
	@DataClassName nvarchar(50),
	@StorageTypeBM int,
	@Database nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@TableName nvarchar(100),
	@IndexName nvarchar(100),
	@SQLStatement nvarchar(max),
	@ColumnList nvarchar(4000),
	@DataClassID_Original int = NULL,
	@DataClassTypeID_Original int = NULL,

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
	@ModifiedBy nvarchar(50) = 'SeGa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set Columnstore index for selected dataclasses.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2172' SET @Description = 'Procedure created.'
		IF @Version = '2.1.1.2174' SET @Description = 'Added parameters @CreateIndexYN and @DropIndexYN.'
		IF @Version = '2.1.2.2181' SET @Description = 'Automatically exclude not existing databases.'
		IF @Version = '2.1.2.2199' SET @Description = 'Add exec sp_RebuildDefragIndexes. Add "Creating indexes for AR/AP reports" step'

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
			@CalledInstanceID = @InstanceID,
			@CalledVersionID = @VersionID

	SET @Step = 'Create temp tables'
		CREATE TABLE #Columns
			(
			ColumnName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

	select   @DataClassID_Original = @DataClassID
	        ,@DataClassTypeID_Original = @DataClassTypeID;

	SET @Step = 'Create #DataClass_Cursor_Table'
		SELECT
			DC.[InstanceID],
			DC.[VersionID],
			DC.[DataClassID],
			DC.[DataClassName],
			DC.[DataClassTypeID],
			DC.[StorageTypeBM]
		INTO
			#DataClass_Cursor_Table
		FROM
			pcINTEGRATOR_Data..DataClass DC
			INNER JOIN pcINTEGRATOR_Data..[Application] A ON A.[InstanceID] = DC.[InstanceID] AND A.[VersionID] = DC.[VersionID] AND A.[SelectYN] <> 0
		WHERE
			(DC.[InstanceID] = @InstanceID OR @InstanceID = 0) AND
			(DC.[VersionID] = @VersionID OR @VersionID = 0) AND
			(DC.[DataClassID] = @DataClassID OR @DataClassID IS NULL) AND
			(DC.[DataClassTypeID] = @DataClassTypeID OR @DataClassTypeID IS NULL)

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DataClass_Cursor_Table', * FROM #DataClass_Cursor_Table ORDER BY [InstanceID], [VersionID], [DataClassID]

	SET @Step = 'DataClass_Cursor'
		IF CURSOR_STATUS('global','DataClass_Cursor') >= -1 DEALLOCATE DataClass_Cursor
		DECLARE DataClass_Cursor CURSOR FOR

			SELECT
				[InstanceID],
				[VersionID],
				[DataClassID],
				[DataClassName],
				[DataClassTypeID],
				[StorageTypeBM]
			FROM
				#DataClass_Cursor_Table
			ORDER BY
				[InstanceID],
				[VersionID],
				[DataClassID]

			OPEN DataClass_Cursor
			FETCH NEXT FROM DataClass_Cursor INTO @InstanceID, @VersionID, @DataClassID, @DataClassName, @DataClassTypeID, @StorageTypeBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@InstanceID] = @InstanceID, [@VersionID] = @VersionID, [@DataClassID] = @DataClassID, [@DataClassName] = @DataClassName, [@DataClassTypeID] = @DataClassTypeID, [@StorageTypeBM] = @StorageTypeBM

					IF @DropIndexYN <> 0 OR @CreateIndexYN <> 0
						BEGIN
							SELECT
								@Database = CASE WHEN @StorageTypeBM & 2 > 0 THEN [ETLDatabase] ELSE [DestinationDatabase] END
							FROM
								[pcINTEGRATOR_Data].[dbo].[Application]
							WHERE
								[InstanceID] = @InstanceID AND
								[VersionID] = @VersionID AND
								[SelectYN] <> 0

							SET @TableName =	CASE WHEN @StorageTypeBM & 2 > 0
													THEN CASE WHEN @DataClassTypeID IN (-5) THEN '' ELSE 'pcDC_' END + @DataClassName
												ELSE CASE WHEN @StorageTypeBM & 4 > 0
													THEN 'FACT_' + @DataClassName + '_default_partition' ELSE NULL END
												END

							IF @DebugBM & 2 > 0 SELECT [@Database] = @Database, [@TableName] = @TableName

							IF (SELECT COUNT(1) FROM sys.databases WHERE [name] = @Database) > 0
								BEGIN
									SET @IndexName = NULL
									SET @SQLStatement = '
										SELECT
											@InternalVariable = i.[name]
										FROM
											[' + @Database + '].[sys].[tables] t
											INNER JOIN [' + @Database + '].[sys].[indexes] i ON i.[type] = 6 AND i.[object_id] = t.[object_id]
										WHERE
											t.[name] = ''' + @TableName + ''''

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC sp_executesql @SQLStatement, N'@InternalVariable nvarchar(100) OUT', @InternalVariable = @IndexName OUT

									IF @IndexName IS NOT NULL
										BEGIN
											IF @DebugBM & 2 > 0 SELECT [@IndexName] = @IndexName
											SET @SQLStatement = '
												DROP INDEX [' + @IndexName + '] ON [' + @Database + '].[dbo].[' + @TableName + ']'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
										END
								END
						END

					IF @CreateIndexYN <> 0 AND (SELECT COUNT(1) FROM sys.databases WHERE [name] = @Database) > 0
						BEGIN
							TRUNCATE TABLE #Columns
							SET @SQLStatement = '
								INSERT INTO #Columns
									(
									[ColumnName]
									)
								SELECT
									[ColumnName] = c.[name]
								FROM
									[' + @Database + '].[sys].[tables] t
									INNER JOIN [' + @Database + '].[sys].[columns] c ON c.[object_id] = t.[object_id] AND c.[name] NOT LIKE ''%_Value'' AND c.[name] NOT LIKE ''Value%''
								WHERE
									t.[name] = ''' + @TableName + '''
								ORDER BY
									c.[name]'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)
							IF @DebugBM & 2 > 0 SELECT TempTable='#Columns', * FROM #Columns ORDER BY [ColumnName]

							SET @ColumnList = ''

							SELECT
								@ColumnList = @ColumnList + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + [ColumnName] + '],'
							FROM
								#Columns
							ORDER BY
								[ColumnName]

							IF LEN(@ColumnList) > 3
								BEGIN
									SET @ColumnList = LEFT(@ColumnList, LEN(@ColumnList) - 1)

									SET @SQLStatement = '
										CREATE NONCLUSTERED COLUMNSTORE INDEX [NCCSI_' + @DataClassName + '] ON [' + @Database + '].[dbo].[' + @TableName + ']
											(' + @ColumnList + '
											)
										WITH (DROP_EXISTING = OFF, COMPRESSION_DELAY = 0) ON [PRIMARY]'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END
						END
					FETCH NEXT FROM DataClass_Cursor INTO @InstanceID, @VersionID, @DataClassID, @DataClassName, @DataClassTypeID, @StorageTypeBM
				END

		CLOSE DataClass_Cursor
		DEALLOCATE DataClass_Cursor

	SET @Step = 'Creating indexes for AR/AP reports'
			SELECT TOP 1
				@DestinationDatabase = [DestinationDatabase] 
			FROM
				[pcINTEGRATOR_Data].[dbo].[Application]
			WHERE
				[InstanceID] = @InstanceID AND
				[VersionID] = @VersionID AND
				[SelectYN] <> 0				

			-- Index: S_HS_MultiDim_MultiDim_ParentMemberId
			SET @SQLStatement = '
			IF EXISTS (
				SELECT 1 FROM [' + @DestinationDatabase + '].sys.objects 
				WHERE name = ''S_HS_MultiDim_MultiDim'' AND type = ''U''
			) AND NOT EXISTS (
				SELECT 1 FROM [' + @DestinationDatabase + '].sys.indexes idx
				JOIN [' + @DestinationDatabase + '].sys.objects obj ON idx.object_id = obj.object_id
				WHERE idx.name = ''S_HS_MultiDim_MultiDim_ParentMemberId''
					AND obj.name = ''S_HS_MultiDim_MultiDim''
			)
			BEGIN
				CREATE NONCLUSTERED INDEX [S_HS_MultiDim_MultiDim_ParentMemberId]
				ON [' + @DestinationDatabase + '].[dbo].[S_HS_MultiDim_MultiDim] ([ParentMemberId])
				INCLUDE ([MemberId],[SequenceNumber]);
			END';
			EXEC sp_executesql @SQLStatement;

			-- Index: S_HS_MultiDim_MultiDim_MemberId
			SET @SQLStatement = '
			IF EXISTS (
				SELECT 1 FROM [' + @DestinationDatabase + '].sys.objects 
				WHERE name = ''S_HS_MultiDim_MultiDim'' AND type = ''U''
			) AND NOT EXISTS (
				SELECT 1 FROM [' + @DestinationDatabase + '].sys.indexes idx
				JOIN [' + @DestinationDatabase + '].sys.objects obj ON idx.object_id = obj.object_id
				WHERE idx.name = ''S_HS_MultiDim_MultiDim_MemberId''
					AND obj.name = ''S_HS_MultiDim_MultiDim''
			)
			BEGIN
				CREATE NONCLUSTERED INDEX [S_HS_MultiDim_MultiDim_MemberId]
				ON [' + @DestinationDatabase + '].[dbo].[S_HS_MultiDim_MultiDim] ([MemberId]);
			END';
			EXEC sp_executesql @SQLStatement;

			-- Index: S_DS_MultiDim_MemberId
			SET @SQLStatement = '
			IF EXISTS (
				SELECT 1 FROM [' + @DestinationDatabase + '].sys.objects 
				WHERE name = ''S_DS_MultiDim'' AND type = ''U''
			) AND NOT EXISTS (
				SELECT 1 FROM [' + @DestinationDatabase + '].sys.indexes idx
				JOIN [' + @DestinationDatabase + '].sys.objects obj ON idx.object_id = obj.object_id
				WHERE idx.name = ''S_DS_MultiDim_MemberId''
					AND obj.name = ''S_DS_MultiDim''
			)
			BEGIN
				CREATE NONCLUSTERED INDEX [S_DS_MultiDim_MemberId]
				ON [' + @DestinationDatabase + '].[dbo].[S_DS_MultiDim] ([MemberId])
				INCLUDE ([Label],[Description],[RNodeType]);
			END';
			EXEC sp_executesql @SQLStatement;

	SET @Step = 'Indexes Defragmentation'
	-- if we work with all dataclasses (as usual)
    if 	@DataClassID_Original is NULL and @DataClassTypeID_Original is NULL
        begin
        SELECT top 1
            @Database = [DestinationDatabase]
        FROM
            [pcINTEGRATOR_Data].[dbo].[Application]
        WHERE
            [InstanceID] = @InstanceID AND
            [VersionID] = @VersionID AND
            [SelectYN] <> 0
        if @Database is not null
            begin
                -- reorg/rebuild
                exec DBA_DB..sp_RebuildDefragIndexes @Action = 'Both', @RebuildPercent = 30, @DBName = @Database, @isShow  = 0, @isExec = 1;
                -- just recalculate new fragmentation
                exec DBA_DB..sp_RebuildDefragIndexes @Action = 'Both', @RebuildPercent = 30, @DBName = @Database, @isShow  = 0, @isExec = 0;
            end
        end

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @CalledInstanceID, @VersionID = @CalledVersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @CalledInstanceID, @VersionID = @CalledVersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
