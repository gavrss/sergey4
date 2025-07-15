SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSet_JournalTable]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@StorageTypeBM int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000587,
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
EXEC [spSet_JournalTable] @UserID=-10, @InstanceID=-1311, @VersionID=-1249, @StorageTypeBM =4, @DebugBM=2
EXEC [spSet_JournalTable] @UserID=-10, @InstanceID=458, @VersionID=1022, @StorageTypeBM = 2, @DebugBM=3
EXEC [spSet_JournalTable] @UserID=-10, @InstanceID=481, @VersionID=1031, @StorageTypeBM = 2, @DebugBM=3
EXEC [spSet_JournalTable] @UserID=-10, @InstanceID=15, @VersionID=1039, @StorageTypeBM = 2, @DebugBM=3
EXEC [spSet_JournalTable] @UserID=-10, @InstanceID=508, @VersionID=1044, @StorageTypeBM = 2, @DebugBM=3
EXEC [spSet_JournalTable] @UserID=-10, @InstanceID=454, @VersionID=1021, @StorageTypeBM = 2, @DebugBM=3
EXEC [spSet_JournalTable] @UserID=-10, @InstanceID=413, @VersionID=1008, @StorageTypeBM = 2, @DebugBM=3
EXEC [spSet_JournalTable] @UserID=-10, @InstanceID=476, @VersionID=1029, @StorageTypeBM = 2, @DebugBM=3

EXEC [spSet_JournalTable] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@JournalStorageTypeBM int,
	@ETLDatabase nvarchar(100),
	@SQLStatement nvarchar(MAX),
	@DatabaseName nvarchar(100),
	@TableCount int,
	@SourceTable nvarchar(100) = '[pcINTEGRATOR_Data].[dbo].[Journal]',
	@DestinationTable nvarchar(100),
	@ColumnList nvarchar(max) = '',
	@SourceRows int,
	@DestinationRows int,
	@IndexCount int,

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.0.2159'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Set Journal Table',
			@MandatoryParameter = 'StorageTypeBM' --Without @, separated by |

		IF @Version = '2.0.3.2154' SET @Description = 'Procedure created.'
		IF @Version = '2.1.0.2155' SET @Description = 'Add new columns to to table when @StorageTypeBM = 2.'
		IF @Version = '2.1.0.2156' SET @Description = 'Separated Step for creating variable @ColumnList; Set @SourceRows by filtering on @InstanceID. Change name of PK for Journal_Old table.'
		IF @Version = '2.1.0.2157' SET @Description = 'Remove single mode during upgrade.'
		IF @Version = '2.1.0.2159' SET @Description = 'Remove test on SelectYN in table Application.'

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

		SELECT
			@ETLDatabase = ETLDatabase
		FROM
			[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

	SET @Step = 'Create temp table #MissingColumns'
		CREATE TABLE #MissingColumns
			(
			ColumnName nvarchar(100)
			)
	
	SET @Step = 'Check @JournalStorageTypeBM'
		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID=@JobID, @JournalStorageTypeBM = @JournalStorageTypeBM OUT

		IF @DebugBM & 2 > 0 SELECT [@JournalStorageTypeBM] = @JournalStorageTypeBM

	SET @Step = 'Verify existence of pcETL'
		IF DB_ID (@ETLDatabase) IS NULL
			EXEC [spSetup_pcETL] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID

	SET @Step = 'Set @DestinationTable'
		SET	@DestinationTable = '[' + @ETLDatabase + '].[dbo].[Journal]'

	SET @Step = 'Set @JournalStorageTypeBM'
		UPDATE pcINTEGRATOR_Data..DataClass
		SET
			StorageTypeBM = @StorageTypeBM
		WHERE
			InstanceID=@InstanceID AND
			VersionID=@VersionID AND
			ModelBM & 1 > 0 AND
			SelectYN <> 0 AND
			DeletedID IS NULL

		SET @Updated = @@ROWCOUNT

		IF @Updated = 0
			BEGIN
				INSERT INTO pcINTEGRATOR_Data..DataClass
					(
					[InstanceID],
					[VersionID],
					[DataClassName],
					[DataClassDescription],
					[DataClassTypeID],
					[ModelBM],
					[StorageTypeBM],
					[ReadAccessDefaultYN],
					[ModelingStatusID],
					[ModelingComment],
					[InheritedFrom]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DataClassName],
					[DataClassDescription],
					[DataClassTypeID],
					[ModelBM],
					[StorageTypeBM] = @StorageTypeBM,
					[ReadAccessDefaultYN],
					[ModelingStatusID],
					[ModelingComment],
					[InheritedFrom] = DataClassID
				FROM
					DataClass
				WHERE
					InstanceID = -10 AND
					VersionID = -10 AND
					DataClassID = -101 AND
					ModelBM & 1 > 0

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Check Journal table existance'
		SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].[sys].[tables] WHERE [name] = ''Journal'''
		EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @TableCount OUT

		IF @TableCount > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #MissingColumns
						(
						[ColumnName]
						)
					SELECT
						[ColumnName] = pc.[name]
					FROM 
						[pcINTEGRATOR_Data].[sys].[tables] pt
						INNER JOIN [pcINTEGRATOR_Data].[sys].[columns] pc ON pc.[object_id] = pt.[object_id]
					WHERE
						pt.[name] = ''Journal'' AND
						NOT EXISTS (
							SELECT 1 FROM [' + @ETLDatabase + '].[sys].[tables] t
								INNER JOIN [' + @ETLDatabase + '].[sys].[columns] c ON c.[object_id] = t.[object_id]
							WHERE
								t.[name] = ''Journal'' AND
								c.[name] = pc.[name])'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#MissingColumns', * FROM #MissingColumns
			END

		IF @JournalStorageTypeBM & @StorageTypeBM > 0 AND ((SELECT COUNT(1) FROM #MissingColumns) = 0) AND @TableCount > 0
			BEGIN
				SET @Message = 'Journal table is already set for this Application.'
				SET @Severity = 0
				GOTO EXITPOINT
			END

		IF @TableCount > 0 AND @StorageTypeBM & 2 > 0
			BEGIN
				--SET @SQLStatement = 'ALTER DATABASE [' + @ETLDatabase + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE'

				--IF @DebugBM & 2 > 0 PRINT @SQLStatement
				--EXEC (@SQLStatement)

				--Rename existing Journal table
				SELECT
					@SourceTable = '[' + @ETLDatabase + '].[dbo].[Journal_Old]',
					@SQLStatement = 'sp_rename @objname = ''''Journal'''', @newname = ''''Journal_Old'''''

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

				SET @SQLStatement = 'SELECT @InternalVariable = COUNT(1) FROM [' + @ETLDatabase + '].sys.indexes where [name] = ''PK_Journal_1'''
				EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @IndexCount OUT
				IF @IndexCount > 0
					BEGIN
						SET @SQLStatement = 'sp_rename @objname = ''''PK_Journal_1'''', @newname = ''''PK_Journal_1_Old'''''

						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END
			END
		
	SET @Step = 'Create variable @ColumnList'
		SELECT
			@ColumnList = @ColumnList + CHAR(13) + CHAR(10) + CHAR(9) + pc.[name] + ','
		FROM 
			[pcINTEGRATOR_Data].[sys].[tables] pt
			INNER JOIN [pcINTEGRATOR_Data].[sys].[columns] pc ON pc.[object_id] = pt.[object_id]
		WHERE
			pt.[name] = 'Journal' AND
			NOT EXISTS (SELECT 1 FROM #MissingColumns MC WHERE MC.ColumnName = pc.[name])

		SET @ColumnList = LEFT(@ColumnList, LEN(@ColumnList) -1)

		IF @DebugBM & 2 > 0 SELECT [@ColumnList] = @ColumnList

	SET @Step = 'Create new Journal table'
		IF @StorageTypeBM & 2 > 0 AND (@SourceTable <> '[pcINTEGRATOR_Data].[dbo].[Journal]' OR @TableCount = 0)
			BEGIN
				SET @SQLStatement = '
					CREATE TABLE [dbo].[Journal](
						[JobID] [int] NOT NULL DEFAULT ((0)),
						[JournalID] [bigint] IDENTITY(1001,1) NOT NULL,
						[InstanceID] [int] NOT NULL DEFAULT ((0)),
						[Entity] [nvarchar](50) NOT NULL,
						[Book] [nvarchar](50) NOT NULL,
						[FiscalYear] [int] NOT NULL,
						[FiscalPeriod] [int] NOT NULL,
						[JournalSequence] [nvarchar](50) NOT NULL,
						[JournalNo] [nvarchar](50) NOT NULL,
						[JournalLine] [int] NOT NULL,
						[YearMonth] [int] NULL,
						[TransactionTypeBM] [int] NOT NULL DEFAULT ((1)),
						[BalanceYN] [bit] NOT NULL DEFAULT ((0)),
						[Account] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment01] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment02] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment03] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment04] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment05] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment06] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment07] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment08] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment09] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment10] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment11] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment12] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment13] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment14] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment15] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment16] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment17] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment18] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment19] [nvarchar](50) NULL DEFAULT (''''''''),
						[Segment20] [nvarchar](50) NULL DEFAULT (''''''''),
						[JournalDate] [date] NULL,
						[TransactionDate] [date] NULL,
						[PostedDate] [date] NULL,
						[PostedStatus] [bit] NULL,
						[PostedBy] [nvarchar](100) NULL,
						[Source] [nvarchar](50) NULL,
						[Flow] [nvarchar](50) NULL,
						[ConsolidationGroup] [nvarchar](50) NULL,
						[InterCompanyEntity] [nvarchar](50) NULL,
						[Scenario] [nvarchar](50) NULL,
						[Customer] [nvarchar](50) NULL,
						[Supplier] [nvarchar](50) NULL,
						[Description_Head] [nvarchar](255) NULL,
						[Description_Line] [nvarchar](255) NULL,
						[Currency_Book] [nchar](3) NULL,
						[ValueDebit_Book] [float] NULL,
						[ValueCredit_Book] [float] NULL,
						[Currency_Group] [nchar](3) NULL,
						[ValueDebit_Group] [float] NULL,
						[ValueCredit_Group] [float] NULL,
						[Currency_Transaction] [nchar](3) NULL,
						[ValueDebit_Transaction] [float] NULL,
						[ValueCredit_Transaction] [float] NULL,
						[SourceModule] [nvarchar](20) NULL,
						[SourceModuleReference] [nvarchar](100) NULL,
						[SourceCounter] [bigint] NULL,
						[SourceGUID] [uniqueidentifier] NULL,
						[Inserted] [datetime] NULL DEFAULT (GETDATE()),
						[InsertedBy] [nvarchar](100) NULL DEFAULT (SUSER_NAME()),
					 CONSTRAINT [PK_Journal_1] PRIMARY KEY CLUSTERED 
					(
						[JournalID] ASC
					)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
					) ON [PRIMARY]'

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @DebugBM & 2 > 0
					BEGIN
						IF LEN(@SQLStatement) > 4000
							EXEC [dbo].[spSet_wrk_Debug]
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@DatabaseName = @DatabaseName,
								@CalledProcedureName = @ProcedureName,
								@Comment = 'Creation Journal table', 
								@SQLStatement = @SQLStatement
						ELSE
							PRINT  @SQLStatement
					END
				
				EXEC (@SQLStatement)

			SET @Step = 'Copy data'
				SET @SQLStatement = '
					SET IDENTITY_INSERT ' + @DestinationTable + ' ON

					INSERT INTO ' + @DestinationTable + '
						(' + @ColumnList + '
						)
					SELECT ' + @ColumnList + '
					FROM
						' + @SourceTable + '
					WHERE
						[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + '

					SET IDENTITY_INSERT ' + @DestinationTable + ' OFF'

				IF @DebugBM & 2 > 0 PRINT  @SQLStatement
				EXEC (@SQLStatement)

				SET @Inserted = @@ROWCOUNT

				CHECKPOINT

			SET @Step = 'Check numbers of inserted rows'
				SET @SQLStatement = '
					SELECT @InternalVariable = COUNT(1) FROM ' + @SourceTable + ' WHERE [InstanceID] = ' + CONVERT(NVARCHAR(15), @InstanceID)
				
				EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @SourceRows OUT

				SET @SQLStatement = '
					SELECT @InternalVariable = COUNT(1) FROM ' + @DestinationTable
				
				EXEC sp_executesql @SQLStatement, N'@InternalVariable int OUT', @InternalVariable = @DestinationRows OUT

				IF @DebugBM & 2 > 0
					SELECT
						[@SourceRows] = @SourceRows,
						[@DestinationRows] = @DestinationRows

			SET @Step = 'Delete old data'
				IF @DestinationRows = @SourceRows AND @DestinationRows > 0
					BEGIN
						IF @SourceTable = '[pcINTEGRATOR_Data].[dbo].[Journal]'
							BEGIN
								DELETE [pcINTEGRATOR_Data].[dbo].[Journal]
								WHERE
									InstanceID = @InstanceID

								SET @Deleted = @@ROWCOUNT

								CHECKPOINT
							END
						ELSE
							BEGIN
								SET @SQLStatement = '
									DROP TABLE ' + @SourceTable

--								SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql DROP TABLE Journal_Old'
								
								IF @Debug & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
								
								SET @Deleted = @SourceRows
							END

						SET @SQLStatement = '
							DBCC SHRINKDATABASE (' + @ETLDatabase  + ')'

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END
			END

	SET @Step = 'Set MULTI_USER for @ETLDatabase'
		--SET @SQLStatement = 'ALTER DATABASE [' + @ETLDatabase + '] SET MULTI_USER'

		--IF @DebugBM & 2 > 0 PRINT @SQLStatement
		--EXEC (@SQLStatement)

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
