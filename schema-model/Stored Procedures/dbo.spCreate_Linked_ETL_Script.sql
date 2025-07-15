SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
--Linked server
--SET RPC Out = TRUE
--SET a Name without dots (Dont use the IP-address, If that is wanted replace dots with underscore)
--SET Security USE Service account

CREATE PROCEDURE [dbo].[spCreate_Linked_ETL_Script]

	@ApplicationID int = NULL,
	@ManuallyYN bit = 0,
	@JobID int = 0,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

SET NOCOUNT ON

--EXEC spCreate_Linked_ETL_Script @ApplicationID = 400, @ManuallyYN = 1
--EXEC spCreate_Linked_ETL_Script_New @ApplicationID = -1026, @ManuallyYN = 1, @Debug = 1
--EXEC [spCreate_Linked_ETL_Script] @ApplicationID = 1324, @ManuallyYN = 0, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@InstanceID int,
	@SQLStatement nvarchar(max),
	@ETLDatabase_Linked nvarchar(100),
	@ETLDatabase_Linked_Local nvarchar(100),
	@SourceDatabase nvarchar(100),
	@SourceDatabase_Local nvarchar(100),
	@LinkedServer nvarchar(100),
	@Collation nvarchar(50),
	@iScalaYN bit,
	@Script nvarchar(max) = '',
	@Script01 nvarchar(max) = '',
	@Script02 nvarchar(max) = '',
	@Script03 nvarchar(max) = '',
	@Script04 nvarchar(max) = '',
	@Script05 nvarchar(max) = '',
	@Script06 nvarchar(max) = '',
	@Script07 nvarchar(max) = '',
	@Script08 nvarchar(max) = '',
	@Script09 nvarchar(max) = '',
	@Script10 nvarchar(max) = '',
	@Script11 nvarchar(max) = '',
	@Script12 nvarchar(max) = '',
	@Script13 nvarchar(max) = '',
	@Script14 nvarchar(max) = '',
	@Counter int,
	@TotalCount int,
 	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.3.2151'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2075' SET @Description = 'Procedure created'
		IF @Version = '1.3.2076' SET @Description = 'Added Account_TimeBalance'
		IF @Version = '1.3.2083' SET @Description = 'Handle odd signs in database names. Added Time and MappedLabel.'
		IF @Version = '1.3.2095' SET @Description = 'Added Scenario and TransactionType_iScala.'
		IF @Version = '1.3.2096' SET @Description = 'Added AccountType and AccountType_Translate. Changed COLLATION to SQL_Latin1_General_CP1_CI_AS.'
		IF @Version = '1.3.2098' SET @Description = 'Added FinancialSegment and MappedObject.'
		IF @Version = '1.3.2107' SET @Description = 'Changed key for MappedObject.'
		IF @Version = '1.3.2109' SET @Description = 'Added columns to TransactionType_iScala.'
		IF @Version = '1.3.2109' SET @Description = 'Added columns to TransactionType_iScala.'
		IF @Version = '1.4.0.2139' SET @Description = 'Handle automatic creation of database.'
		IF @Version = '2.0.3.2151' SET @Description = 'Added Deallocation for Script_Cursor if existing.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @ApplicationID IS NULL
	BEGIN
		PRINT 'Parameter @ApplicationID must be set'
		RETURN 
	END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @Collation = @Collation OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT @InstanceID = A.InstanceID FROM [Application] A WHERE A.ApplicationID = @ApplicationID

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		IF
			(
			SELECT
			 COUNT(S.SourceID) 
			FROM
			 [Application] A
			 INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.Introduced < @Version AND M.SelectYN <> 0
			 INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0 AND S.SourceTypeID = 3 --iScala
			WHERE
			 A.InstanceID = @InstanceID
			)
			> 0 SET @iScalaYN = 1 ELSE SET @iScalaYN = 0

	SET @Step = 'Create temp tables'
		CREATE TABLE #Source
			(
			ID int IDENTITY(1, 1),
			SourceDatabase nvarchar(100),
			SourceDatabase_Local nvarchar(100),
			ETLDatabase_Linked nvarchar(100),
			ETLDatabase_Linked_Local nvarchar(100),
			LinkedServer nvarchar(100),
			Collation nvarchar(100)
			)

		CREATE TABLE #Collation ([Collation] nvarchar(50))

		INSERT INTO #Source
			(
			SourceDatabase,
			ETLDatabase_Linked,
			Collation
			)
		SELECT DISTINCT
			SourceDatabase = REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''),
			ETLDatabase_Linked = REPLACE(REPLACE(S.ETLDatabase_Linked, '[', ''), ']', ''),
			Collation = @Collation
		FROM
			[Source] S
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0 
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0 
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.SelectYN <> 0 
		WHERE
			S.SourceDatabase LIKE '%.%' AND
			S.SelectYN <> 0 
		ORDER BY
			ETLDatabase_Linked

		IF (SELECT COUNT(1) FROM #Source) = 0
			GOTO EXITPOINT

		UPDATE
			#Source
		SET
			SourceDatabase_Local = SUBSTRING(SourceDatabase, CHARINDEX ('.', SourceDatabase) + 1, LEN(SourceDatabase) - CHARINDEX ('.', SourceDatabase)),
			LinkedServer = '[' + REPLACE(REPLACE(SUBSTRING(SourceDatabase, 1, CHARINDEX ('.', SourceDatabase) - 1), '[', ''), ']', '') + ']',
			SourceDatabase = '[' + REPLACE(SourceDatabase, '.', '].[') + ']',
			ETLDatabase_Linked_Local = SUBSTRING(ETLDatabase_Linked, CHARINDEX ('.', ETLDatabase_Linked) + 1, LEN(ETLDatabase_Linked) - CHARINDEX ('.', ETLDatabase_Linked))

		IF @Debug <> 0 SELECT TempTable = '#Source', * FROM #Source

/*
	SET @Step = 'Create Collation_Cursor'
		DECLARE Collation_Cursor CURSOR FOR

			SELECT DISTINCT
				SourceDatabase,
				SourceDatabase_Local,
				LinkedServer
			FROM
				#Source
			ORDER BY
				SourceDatabase

			OPEN Collation_Cursor
			FETCH NEXT FROM Collation_Cursor INTO @SourceDatabase, @SourceDatabase_Local, @LinkedServer

			WHILE @@FETCH_STATUS = 0
				BEGIN

					TRUNCATE TABLE #Collation

					SET @SQLStatement = 'SELECT collation_name FROM [' + @LinkedServer + '].master.sys.databases WHERE [name] = ''' + @SourceDatabase_Local + ''''
					INSERT INTO #Collation ([Collation]) EXEC (@SQLStatement)

					SELECT @Collation = [Collation] FROM #Collation

					UPDATE
						#Source
					SET
						Collation = @Collation
					WHERE
						SourceDatabase = @SourceDatabase AND
						SourceDatabase_Local = @SourceDatabase_Local AND
						LinkedServer = @LinkedServer

					FETCH NEXT FROM Collation_Cursor INTO @SourceDatabase, @SourceDatabase_Local, @LinkedServer
				END

		CLOSE Collation_Cursor
		DEALLOCATE Collation_Cursor		

		IF @Debug <> 0 SELECT * FROM #Source
*/

	SET @Step = 'Create Script_Cursor'

		SELECT @TotalCount = COUNT(1) FROM #Source

		IF CURSOR_STATUS('global','Script_Cursor') >= -1 DEALLOCATE Script_Cursor
		DECLARE Script_Cursor CURSOR FOR

			SELECT DISTINCT
				ID,
				LinkedServer,
				ETLDatabase_Linked_Local,
				Collation
			FROM
				#Source
			ORDER BY
				ID

			OPEN Script_Cursor
			FETCH NEXT FROM Script_Cursor INTO @Counter, @LinkedServer, @ETLDatabase_Linked_Local, @Collation

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @ManuallyYN <> 0
						SET @Script01 = '

		--==================================================================================--
		-- Start of script ' + CONVERT(nvarchar(10), @Counter) + ' of ' + CONVERT(nvarchar(10), @TotalCount) + '
		-- Run this script on the ' + @LinkedServer + ' server with administrative privileges.
		--==================================================================================--

		USE master
		--#GO#--

		IF (SELECT COUNT(1) FROM sys.databases WHERE name = ''' + @ETLDatabase_Linked_Local + ''') = 0
			BEGIN
				CREATE DATABASE [' + @ETLDatabase_Linked_Local + '] COLLATE ' + @Collation + '
				ALTER DATABASE [' + @ETLDatabase_Linked_Local + '] SET RECOVERY SIMPLE
			END
		--#GO#--'
					ELSE
						SET @Script01 = '
				CREATE DATABASE [' + @ETLDatabase_Linked_Local + '] COLLATE ' + @Collation + '
				ALTER DATABASE [' + @ETLDatabase_Linked_Local + '] SET RECOVERY SIMPLE'

	SET @Step = 'Create BudgetSelection'
					IF @ManuallyYN <> 0
						SET @Script02 = '

		USE [' + @ETLDatabase_Linked_Local + ']
		--#GO#--'
					ELSE
						SET @Script02 = ''

						SET @Script02 = @Script02 + '
		SET ANSI_NULLS ON
		--#GO#--
		SET QUOTED_IDENTIFIER ON
		--#GO#--
		CREATE TABLE [dbo].[BudgetSelection](
			[SourceID] [int] NOT NULL,
			[EntityCode] [nvarchar](50) NOT NULL,
			[BudgetCode] [nvarchar](50) NOT NULL,
			[Scenario] [nvarchar](100) NOT NULL,
			[SelectYN] [bit] NOT NULL,
			[Inserted] [datetime] NOT NULL,
		 CONSTRAINT [PK_BudgetSelection] PRIMARY KEY CLUSTERED 
		(
			[SourceID] ASC,
			[EntityCode] ASC,
			[BudgetCode] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
		--#GO#--
		
		ALTER TABLE [dbo].[BudgetSelection] ADD  CONSTRAINT [DF_BudgetSelection_Inserted]  DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'

	SET @Step = 'Create ClosedPeriod'
					SET @Script03 = '

		SET ANSI_PADDING ON
		--#GO#--
		CREATE TABLE [dbo].[ClosedPeriod](
			[SourceID] [int] NOT NULL,
			[EntityCode] [nvarchar](50) NOT NULL,
			[TimeFiscalYear] [int] NOT NULL,
			[TimeFiscalPeriod] [int] NOT NULL,
			[TimeYear] [int] NOT NULL,
			[TimeMonth] [int] NOT NULL,
			[BusinessProcess] [nvarchar](50) NOT NULL,
			[ClosedPeriod] [bit] NOT NULL,
			[ClosedPeriod_Counter] [int] NOT NULL,
			[UpdateYN] [bit] NOT NULL,
			[Updated] [datetime] NOT NULL,
			[UpdatedBy] [varchar](50) NOT NULL,
			[Inserted] [datetime] NOT NULL,
		 CONSTRAINT [PK_ClosedPeriod] PRIMARY KEY CLUSTERED 
		(
			[SourceID] ASC,
			[EntityCode] ASC,
			[TimeFiscalYear] ASC,
			[TimeFiscalPeriod] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
		--#GO#--
		SET ANSI_PADDING OFF
		--#GO#--

		ALTER TABLE [dbo].[ClosedPeriod] ADD  CONSTRAINT [DF_ClosedPeriod_Inserted]  DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'

	SET @Step = 'Create Entity'
					SET @Script04 = '

		CREATE TABLE [dbo].[Entity](
			[SourceID] [int] NOT NULL,
			[EntityCode] [nvarchar](50) NOT NULL,
			[Entity] [nvarchar](50) NOT NULL,
			[EntityName] [nvarchar](255) NOT NULL,
			[Currency] [nchar](3) NULL,
			[EntityPriority] [int] NULL,
			[SelectYN] [bit] NOT NULL,
			[Par01] [nvarchar](255) NULL,
			[Par02] [nvarchar](255) NULL,
			[Par03] [nvarchar](255) NULL,
			[Par04] [nvarchar](255) NULL,
			[Par05] [nvarchar](255) NULL,
			[Par06] [nvarchar](255) NULL,
			[Par07] [nvarchar](255) NULL,
			[Par08] [nvarchar](255) NULL,
			[Par09] [nvarchar](255) NULL,
			[Par10] [nvarchar](255) NULL,
			[Inserted] [datetime] NOT NULL,
		 CONSTRAINT [PK_Entity] PRIMARY KEY CLUSTERED 
		(
			[SourceID] ASC,
			[EntityCode] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
		--#GO#--

		ALTER TABLE [dbo].[Entity] ADD  CONSTRAINT [DF_Entity_Inserted]  DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'

	SET @Step = 'Create MemberSelection'
					SET @Script05 = '

		CREATE TABLE [dbo].[MemberSelection](
			[DimensionID] [int] NOT NULL,
			[Label] [nvarchar](50) NOT NULL,
			[SelectYN] [bit] NOT NULL,
			[Inserted] [datetime] NOT NULL,
		 CONSTRAINT [PK_MemberSelection] PRIMARY KEY CLUSTERED 
		(
			[DimensionID] ASC,
			[Label] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
		--#GO#--

		ALTER TABLE [dbo].[MemberSelection] ADD  CONSTRAINT [DF_MemberSelection_Inserted]  DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'

	SET @Step = 'Create Account_TimeBalance'
					SET @Script06 = '

		CREATE TABLE [dbo].[Account_TimeBalance](
			[Account] [nvarchar](255) NOT NULL,
			[TimeBalance] [bit] NOT NULL,
			[Inserted] [datetime] NOT NULL,
		 CONSTRAINT [PK_Account_TimeBalance] PRIMARY KEY CLUSTERED 
		(
			[Account] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
		--#GO#--

		ALTER TABLE [dbo].[Account_TimeBalance] ADD  CONSTRAINT [DF_Account_TimeBalance_Inserted]  DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'

	SET @Step = 'Create MappedLabel'
					SET @Script07 = '

		CREATE TABLE [dbo].[MappedLabel](
			[MappedObjectName] [nvarchar](100) NOT NULL,
			[Entity] [nvarchar](50) NOT NULL,
			[LabelFrom] [nvarchar](255) NOT NULL,
			[LabelTo] [nvarchar](255) NOT NULL,
			[MappingTypeID] [int] NOT NULL,
			[MappedLabel] [nvarchar](255) NULL,
			[MappedDescription] [nvarchar](255) NULL,
			[SelectYN] [bit] NOT NULL,
			[Inserted] [datetime] NOT NULL,
		 CONSTRAINT [PK_AccountMapping] PRIMARY KEY CLUSTERED 
		(
			[MappedObjectName] ASC,
			[Entity] ASC,
			[LabelFrom] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
		--#GO#--
		
		ALTER TABLE [dbo].[MappedLabel] ADD  CONSTRAINT [DF_MappedLabel_Inserted]  DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'

	SET @Step = 'Create TransactionType_iScala'
				IF @iScalaYN <> 0
					SET @Script08 = '

		CREATE TABLE [dbo].[TransactionType_iScala](
			[Group] [nvarchar](50) NULL,
			[Period] [nvarchar](2) NULL,
			[Scenario] [nvarchar](50) NULL,
			[Hex] [nchar](4) NOT NULL,
			[Symbol] [nchar](1) NULL,
			[Description] [nvarchar](100) NULL,
			[BusinessProcess] [nvarchar](50) NULL,
			[SelectYN] [bit] NOT NULL,
			[Inserted] [datetime] NOT NULL,
		CONSTRAINT [PK_TransactionType_iScala] PRIMARY KEY CLUSTERED 
		(
			[Hex] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
		--#GO#--
		
		ALTER TABLE [dbo].[TransactionType_iScala] ADD  CONSTRAINT [DF_TransactionType_iScala_Inserted]  DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'
				ELSE
					SET @Script08 = ''

	SET @Step = 'Create AccountType'
				SET @Script09 = '

		CREATE TABLE [dbo].[AccountType](
			[AccountType] [nvarchar](50) NOT NULL,
			[Sign] [int] NULL,
			[TimeBalance] [bit] NULL,
			[Rate] [nvarchar](255) NULL,
			[Source] [nvarchar](50) NULL,
			[Inserted] [datetime] NOT NULL,
		 CONSTRAINT [PK_AccountType] PRIMARY KEY CLUSTERED 
		(
			[AccountType] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
		--#GO#--
		
		ALTER TABLE [dbo].[AccountType] ADD  CONSTRAINT [DF_AccountType_Inserted]  DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'

	SET @Step = 'Create AccountType_Translate'
				SET @Script10 = '

		CREATE TABLE [dbo].[AccountType_Translate](
			[SourceTypeName] [nvarchar](50) NOT NULL,
			[CategoryID] [nvarchar](50) NOT NULL,
			[Description] [nvarchar](255) NULL,
			[AccountType] [nvarchar](50) NULL,
			[Inserted] [datetime] NOT NULL,
		 CONSTRAINT [PK_AccountType_Translate] PRIMARY KEY CLUSTERED 
		(
			[SourceTypeName] ASC,
			[CategoryID] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
		--#GO#--
		
		ALTER TABLE [dbo].[AccountType_Translate] ADD  CONSTRAINT [DF_AccountType_Translate_Inserted]  DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'

	SET @Step = 'Create FinancialSegment'
				SET @Script11 = '

		CREATE TABLE [dbo].[FinancialSegment](
			[SourceID] [int] NOT NULL,
			[EntityCode] [nvarchar](50) NOT NULL,
			[SegmentNbr] [int] NOT NULL,
			[EntityName] [nvarchar](255) NULL,
			[COACode] [nvarchar](10) NULL,
			[SQLDB] [nvarchar](50) NULL,
			[SegmentTable] [nvarchar](50) NULL,
			[SegmentCode] [nvarchar](50) NULL,
			[SegmentName] [nvarchar](50) NULL,
			[Company_COACode] [nvarchar](50) NULL,
			[DimensionTypeID] [int] NULL,
			[Start] [int] NULL,
			[Length] [int] NULL,
			[Inserted] [datetime] NOT NULL,
		 CONSTRAINT [PK_FinancialSegment] PRIMARY KEY CLUSTERED 
		(
			[SourceID] ASC,
			[EntityCode] ASC,
			[SegmentNbr] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
		--#GO#--
		
		ALTER TABLE [dbo].[FinancialSegment] ADD  CONSTRAINT [DF_FinancialSegment_Inserted] DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'


	SET @Step = 'Create MappedObject'
				SET @Script12 = '

		CREATE TABLE [dbo].[MappedObject](
			[Entity] [nvarchar](50) NOT NULL,
			[ObjectName] [nvarchar](100) NOT NULL,
			[DimensionTypeID] [int] NOT NULL,
			[MappedObjectName] [nvarchar](100) NOT NULL,
			[ObjectTypeBM] [int] NOT NULL,
			[ModelBM] [int] NOT NULL,
			[MappingTypeID] [int] NOT NULL,
			[ReplaceTextYN] [bit] NOT NULL,
			[TranslationYN] [bit] NOT NULL,
			[SelectYN] [bit] NOT NULL,
			[Inserted] [datetime] NOT NULL,
		 CONSTRAINT [PK_MappedObject] PRIMARY KEY CLUSTERED 
		(
			[Entity] ASC,
			[ObjectName] ASC,
			[ObjectTypeBM] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
		--#GO#--
		
		ALTER TABLE [dbo].[MappedObject] ADD  CONSTRAINT [DF_MappedObject_Inserted] DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'


	SET @Step = 'Create Scenario'
					SET @Script13 = '
		CREATE TABLE [dbo].[Scenario](
			[MemberId] [bigint] NULL,
			[Label] [nvarchar](255) NOT NULL,
			[Description] [nvarchar](512) NOT NULL,
			[Source] [nvarchar](50) NULL,
			[Source_Currency] [nvarchar](50) NULL,
			[Source_Scenario] [nvarchar](50) NULL,
			[Synchronized] [bit] NULL,
			[Inserted] [datetime] NOT NULL,
		) ON [PRIMARY]
		--#GO#--
		
		ALTER TABLE [dbo].[Scenario] ADD  CONSTRAINT [DF_Scenario_Inserted]  DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'

	SET @Step = 'Create Time'
					SET @Script14 = '

		CREATE TABLE [dbo].[Time](
			[MemberId] [bigint] NULL,
			[Label] [nvarchar](255) NOT NULL,
			[Description] [nvarchar](512) NOT NULL,
			[Level] [nvarchar](10) NULL,
			[SendTo] [nvarchar](255) NULL,
			[TimeFiscalPeriod] [nvarchar](255) NULL,
			[TimeFiscalQuarter] [nvarchar](255) NULL,
			[TimeFiscalSemester] [nvarchar](255) NULL,
			[TimeFiscalTertial] [nvarchar](255) NULL,
			[TimeFiscalYear] [nvarchar](255) NULL,
			[TimeMonth] [nvarchar](255) NULL,
			[TimeQuarter] [nvarchar](255) NULL,
			[TimeSemester] [nvarchar](255) NULL,
			[TimeTertial] [nvarchar](255) NULL,
			[TimeYear] [nvarchar](255) NULL,
			[TopNode] [nvarchar](50) NULL,
			[Source] [nvarchar](50) NULL,
			[Synchronized] [bit] NULL,
			[Inserted] [datetime] NOT NULL
		) ON [PRIMARY]
		--#GO#--

		ALTER TABLE [dbo].[Time] ADD  CONSTRAINT [DF_Time_Inserted]  DEFAULT (getdate()) FOR [Inserted]
		--#GO#--'

				IF @ManuallyYN <> 0
					SET @Script14 = @Script14 + '

		--==================================================================================--
		-- End of script ' + CONVERT(nvarchar(10), @Counter) + ' of ' + CONVERT(nvarchar(10), @TotalCount) + '
		--==================================================================================--'

					IF @ManuallyYN <> 0
						BEGIN
							SET @Script = REPLACE(@Script01 + @Script02 + @Script03 + @Script04 + @Script05 + @Script06 + @Script07 + @Script08 + @Script09 + @Script10 + @Script11 + @Script12 + @Script13 + @Script14, '--#GO#--', 'GO')
							PRINT @Script
						END
					ELSE
						BEGIN
							SELECT @SQLStatement = @Script01
							SET @SQLStatement = 'EXEC ' + @LinkedServer + '.master.dbo.sp_executesql N''' + @SQLStatement + ''''
							
							IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of LINKED ETL database', [SQLStatement] = @SQLStatement
							EXEC (@SQLStatement)

							SELECT @SQLStatement = REPLACE(@Script02 + @Script03 + @Script04 + @Script05 + @Script06 + @Script07 + @Script08 + @Script09 + @Script10 + @Script11 + @Script12 + @Script13 + @Script14, '--#GO#--', '')
							SET @SQLStatement = 'EXEC ' + @LinkedServer + '.' + @ETLDatabase_Linked_Local + '.dbo.sp_executesql N''' + @SQLStatement + ''''

							IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of tables in LINKED ETL database', [SQLStatement] = @SQLStatement
							EXEC (@SQLStatement)
						END

				FETCH NEXT FROM Script_Cursor INTO @Counter, @LinkedServer, @ETLDatabase_Linked_Local, @Collation
			END
		CLOSE Script_Cursor
		DEALLOCATE Script_Cursor	

	SET @Step = 'Define exit point'
		EXITPOINT:

	SET @Step = 'Drop temp tables'
		DROP TABLE #Source
		DROP TABLE #Collation

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH






GO
