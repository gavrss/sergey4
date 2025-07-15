SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_pcEXCHANGE]

	@JobID int = -1,
	@ApplicationID int = NULL,
	@pcExchangeType nvarchar(50) = NULL, --SIE4, Demo, Upgrade
	@pcExchangeDatabase nvarchar(100) = NULL,
	@Debug bit = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_pcEXCHANGE] @GetVersion = 1
--EXEC [spCreate_pcEXCHANGE] @ApplicationID = 52, @pcExchangeDatabase = 'pcEXCHANGE_Upgrade_DevTest48', @pcExchangeType = 'Upgrade', @Debug = true
--EXEC [spCreate_pcEXCHANGE] @ApplicationID = 400, @pcExchangeDatabase = 'pcEXCHANGE_Upgrade_DevTest63', @pcExchangeType = 'Upgrade', @Debug = true
--EXEC [spCreate_pcEXCHANGE] @ApplicationID = 400, @pcExchangeDatabase = 'pcEXCHANGE_Demo3', @pcExchangeType = 'Demo', @Debug = true
--EXEC [spCreate_pcEXCHANGE] @ApplicationID = 400, @pcExchangeDatabase = 'pcEXCHANGE_SIE4_DevTest63', @pcExchangeType = 'SIE4', @Debug = true
--EXEC [spCreate_pcEXCHANGE] @ApplicationID = 400, @pcExchangeDatabase = 'pcEXCHANGE_Demo_Jamo', @pcExchangeType = 'Demo', @Debug = true

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@ApplicationName nvarchar(100),
	@SourceDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@Collation nvarchar(50),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2064' SET @Description = 'Introduced.'
		IF @Version = '1.2.2065' SET @Description = 'Hierarchy handling improved.'
		IF @Version = '1.3.2070' SET @Description = 'Property Source added. Workaround for inconsistent handling of namespaces in XML'
		IF @Version = '1.3.2082' SET @Description = 'Get pcExchangeID from table where SelectYN <> 0'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2107' SET @Description = 'Added columns DimensionID, SelectYN to Dimension and SelectYN to Model.'
		IF @Version = '1.3.2109' SET @Description = 'Added column Version to SysParam.'
		IF @Version = '1.3.2110' SET @Description = 'Pick up Collation from [spGet_Version]. Handle AuthorType in WorkBookLibrary.'
		IF @Version = '1.3.2113' SET @Description = 'Handle different @pcExchangeTypes.'
		IF @Version = '1.3.2115' SET @Description = 'Added JobLog table for SIE4. Changed hardcoded @ApplicationID to dynamic.'
		IF @Version = '1.3.1.2120' SET @Description = 'Check existence of manually added dimensions, when inserting rows to Dimension table.'
		IF @Version = '1.3.1.2121' SET @Description = 'Changed setting of default parameters.'
		IF @Version = '1.4.0.2127' SET @Description = 'Fixed some bugs in the DimensionData procedure.'
		IF @Version = '1.4.0.2139' SET @Description = 'Fixed a bug in the Dimension procedure (SalesMan duplicated).'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

	IF (@ApplicationID IS NULL AND @pcExchangeType NOT IN ('Upgrade')) OR (@ApplicationID IS NOT NULL AND @pcExchangeType NOT IN ('SIE4', 'Demo', 'Upgrade'))
		BEGIN
			PRINT 'Parameter @ApplicationID must be set and parameter @pcExchangeType must be set to a correct value.'
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

		IF @ApplicationID IS NULL
			SELECT @ApplicationID = InheritedFrom FROM [Application] WHERE SelectYN <> 0

--Loop has to be implemented for selected applications 2017-05-30 (WD40)

		SELECT
			@ApplicationName = A.ApplicationName,
			@SourceDatabase = A.DestinationDatabase
		FROM
			[Application] A
		WHERE
			A.[ApplicationID] = @ApplicationID
			AND A.[SelectYN] <> 0

		IF @pcExchangeDatabase IS NULL
			SET @pcExchangeDatabase = 'pcEXCHANGE_' + @pcExchangeType + '_' + @ApplicationName

	SET @Step = 'Check existence of pcExchange database'
		IF EXISTS (SELECT 1 FROM sys.databases WHERE [name] = @pcExchangeDatabase)
			GOTO EXITPOINT
		ELSE
			SET @pcExchangeDatabase = '[' + REPLACE(REPLACE(REPLACE(@pcExchangeDatabase, '[', ''), ']', ''), '.', '].[') + ']'

	SET @Step = 'Create database pcEXCHANGE'
		SET @SQLStatement = 'CREATE DATABASE ' + @pcExchangeDatabase + ' COLLATE ' + @Collation + ' ALTER DATABASE ' + @pcExchangeDatabase + ' SET RECOVERY SIMPLE'
		IF @Debug <> 0 PRINT @SQLStatement 
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	---------------------------
	SET @Step = 'CREATE TABLES'
	---------------------------

		IF @pcExchangeType IN ('SIE4', 'Demo', 'Upgrade') --Mandatory for all @pcExchangeType
			BEGIN
				SET @Step = 'Create table Dimension'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[Dimension](
							[DimensionName] [nvarchar](100) NOT NULL,
							[DimensionDescription] [nvarchar](255) NULL,
							[DimensionID] [int] NULL,
							[DimensionTypeID] [int] NULL,
							[Type] [nvarchar](50) NOT NULL,
							[object_id] [int] NULL,
							[DefaultHierarchy] [nvarchar](100) NULL,
							[HierarchyName1] [nvarchar](100) NULL,
							[HierarchyName2] [nvarchar](100) NULL,
							[HierarchyName3] [nvarchar](100) NULL,
							[HierarchyName4] [nvarchar](100) NULL,
							[HierarchyName5] [nvarchar](100) NULL,
							[PropertyName01] [nvarchar](100) NULL,
							[PropertyDataTypeID01] [int] NULL,
							[PropertySize01] [int] NULL,
							[PropertyDefaultValue01] [nvarchar](100) NULL,
							[PropertyMemberDimension01] [nvarchar](100) NULL,
							[PropertyMemberHierarchy01] [nvarchar](100) NULL,
							[PropertyName02] [nvarchar](100) NULL,
							[PropertyDataTypeID02] [int] NULL,
							[PropertySize02] [int] NULL,
							[PropertyDefaultValue02] [nvarchar](100) NULL,
							[PropertyMemberDimension02] [nvarchar](100) NULL,
							[PropertyMemberHierarchy02] [nvarchar](100) NULL,'

							SET @SQLStatement = @SQLStatement + '
							[PropertyName03] [nvarchar](100) NULL,
							[PropertyDataTypeID03] [int] NULL,
							[PropertySize03] [int] NULL,
							[PropertyDefaultValue03] [nvarchar](100) NULL,
							[PropertyMemberDimension03] [nvarchar](100) NULL,
							[PropertyMemberHierarchy03] [nvarchar](100) NULL,
							[PropertyName04] [nvarchar](100) NULL,
							[PropertyDataTypeID04] [int] NULL,
							[PropertySize04] [int] NULL,
							[PropertyDefaultValue04] [nvarchar](100) NULL,
							[PropertyMemberDimension04] [nvarchar](100) NULL,
							[PropertyMemberHierarchy04] [nvarchar](100) NULL,
							[PropertyName05] [nvarchar](100) NULL,
							[PropertyDataTypeID05] [int] NULL,
							[PropertySize05] [int] NULL,
							[PropertyDefaultValue05] [nvarchar](100) NULL,
							[PropertyMemberDimension05] [nvarchar](100) NULL,
							[PropertyMemberHierarchy05] [nvarchar](100) NULL,'

							SET @SQLStatement = @SQLStatement + '
							[PropertyName06] [nvarchar](100) NULL,
							[PropertyDataTypeID06] [int] NULL,
							[PropertySize06] [int] NULL,
							[PropertyDefaultValue06] [nvarchar](100) NULL,
							[PropertyMemberDimension06] [nvarchar](100) NULL,
							[PropertyMemberHierarchy06] [nvarchar](100) NULL,
							[PropertyName07] [nvarchar](100) NULL,
							[PropertyDataTypeID07] [int] NULL,
							[PropertySize07] [int] NULL,
							[PropertyDefaultValue07] [nvarchar](100) NULL,
							[PropertyMemberDimension07] [nvarchar](100) NULL,
							[PropertyMemberHierarchy07] [nvarchar](100) NULL,
							[PropertyName08] [nvarchar](100) NULL,
							[PropertyDataTypeID08] [int] NULL,
							[PropertySize08] [int] NULL,
							[PropertyDefaultValue08] [nvarchar](100) NULL,
							[PropertyMemberDimension08] [nvarchar](100) NULL,
							[PropertyMemberHierarchy08] [nvarchar](100) NULL,'

							SET @SQLStatement = @SQLStatement + '
							[PropertyName09] [nvarchar](100) NULL,
							[PropertyDataTypeID09] [int] NULL,
							[PropertySize09] [int] NULL,
							[PropertyDefaultValue09] [nvarchar](100) NULL,
							[PropertyMemberDimension09] [nvarchar](100) NULL,
							[PropertyMemberHierarchy09] [nvarchar](100) NULL,
							[PropertyName10] [nvarchar](100) NULL,
							[PropertyDataTypeID10] [int] NULL,
							[PropertySize10] [int] NULL,
							[PropertyDefaultValue10] [nvarchar](100) NULL,
							[PropertyMemberDimension10] [nvarchar](100) NULL,
							[PropertyMemberHierarchy10] [nvarchar](100) NULL,
							[PropertyName11] [nvarchar](100) NULL,
							[PropertyDataTypeID11] [int] NULL,
							[PropertySize11] [int] NULL,
							[PropertyDefaultValue11] [nvarchar](100) NULL,
							[PropertyMemberDimension11] [nvarchar](100) NULL,
							[PropertyMemberHierarchy11] [nvarchar](100) NULL,'

							SET @SQLStatement = @SQLStatement + '
							[PropertyName12] [nvarchar](100) NULL,
							[PropertyDataTypeID12] [int] NULL,
							[PropertySize12] [int] NULL,
							[PropertyDefaultValue12] [nvarchar](100) NULL,
							[PropertyMemberDimension12] [nvarchar](100) NULL,
							[PropertyMemberHierarchy12] [nvarchar](100) NULL,
							[PropertyName13] [nvarchar](100) NULL,
							[PropertyDataTypeID13] [int] NULL,
							[PropertySize13] [int] NULL,
							[PropertyDefaultValue13] [nvarchar](100) NULL,
							[PropertyMemberDimension13] [nvarchar](100) NULL,
							[PropertyMemberHierarchy13] [nvarchar](100) NULL,
							[PropertyName14] [nvarchar](100) NULL,
							[PropertyDataTypeID14] [int] NULL,
							[PropertySize14] [int] NULL,
							[PropertyDefaultValue14] [nvarchar](100) NULL,
							[PropertyMemberDimension14] [nvarchar](100) NULL,
							[PropertyMemberHierarchy14] [nvarchar](100) NULL,'

							SET @SQLStatement = @SQLStatement + '
							[PropertyName15] [nvarchar](100) NULL,
							[PropertyDataTypeID15] [int] NULL,
							[PropertySize15] [int] NULL,
							[PropertyDefaultValue15] [nvarchar](100) NULL,
							[PropertyMemberDimension15] [nvarchar](100) NULL,
							[PropertyMemberHierarchy15] [nvarchar](100) NULL,
							[PropertyName16] [nvarchar](100) NULL,
							[PropertyDataTypeID16] [int] NULL,
							[PropertySize16] [int] NULL,
							[PropertyDefaultValue16] [nvarchar](100) NULL,
							[PropertyMemberDimension16] [nvarchar](100) NULL,
							[PropertyMemberHierarchy16] [nvarchar](100) NULL,
							[PropertyName17] [nvarchar](100) NULL,
							[PropertyDataTypeID17] [int] NULL,
							[PropertySize17] [int] NULL,
							[PropertyDefaultValue17] [nvarchar](100) NULL,
							[PropertyMemberDimension17] [nvarchar](100) NULL,
							[PropertyMemberHierarchy17] [nvarchar](100) NULL,'

							SET @SQLStatement = @SQLStatement + '
							[PropertyName18] [nvarchar](100) NULL,
							[PropertyDataTypeID18] [int] NULL,
							[PropertySize18] [int] NULL,
							[PropertyDefaultValue18] [nvarchar](100) NULL,
							[PropertyMemberDimension18] [nvarchar](100) NULL,
							[PropertyMemberHierarchy18] [nvarchar](100) NULL,
							[PropertyName19] [nvarchar](100) NULL,
							[PropertyDataTypeID19] [int] NULL,
							[PropertySize19] [int] NULL,
							[PropertyDefaultValue19] [nvarchar](100) NULL,
							[PropertyMemberDimension19] [nvarchar](100) NULL,
							[PropertyMemberHierarchy19] [nvarchar](100) NULL,
							[PropertyName20] [nvarchar](100) NULL,
							[PropertyDataTypeID20] [int] NULL,
							[PropertySize20] [int] NULL,
							[PropertyDefaultValue20] [nvarchar](100) NULL,
							[PropertyMemberDimension20] [nvarchar](100) NULL,
							[PropertyMemberHierarchy20] [nvarchar](100) NULL,
							[SourceYN] bit NULL,
							[SelectYN] [bit] NOT NULL,
							CONSTRAINT [PK_Dimension] PRIMARY KEY CLUSTERED 
						(
							[DimensionName] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]
			
						ALTER TABLE ' + @pcExchangeDatabase + '.[dbo].[Dimension] ADD  CONSTRAINT [DF_Dimension_SelectYN]  DEFAULT ((1)) FOR [SelectYN]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1


				SET @Step = 'Create table DimensionData'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[DimensionData](
							[DimensionName] [nvarchar](100) NOT NULL,
							[MemberId] [bigint] NULL,
							[Label] [nvarchar](255) NOT NULL,
							[Description] [nvarchar](512) NULL,
							[Parent1] [nvarchar](255) NULL,
							[SortOrder1] [int] NULL,
							[Parent2] [nvarchar](255) NULL,
							[SortOrder2] [int] NULL,
							[Parent3] [nvarchar](255) NULL,
							[SortOrder3] [int] NULL,
							[Parent4] [nvarchar](255) NULL,
							[SortOrder4] [int] NULL,
							[Parent5] [nvarchar](255) NULL,
							[SortOrder5] [int] NULL,'

							SET @SQLStatement = @SQLStatement + '
							[Property01] [nvarchar](1024) NULL,
							[Property02] [nvarchar](1024) NULL,
							[Property03] [nvarchar](1024) NULL,
							[Property04] [nvarchar](1024) NULL,
							[Property05] [nvarchar](1024) NULL,
							[Property06] [nvarchar](1024) NULL,
							[Property07] [nvarchar](1024) NULL,
							[Property08] [nvarchar](1024) NULL,
							[Property09] [nvarchar](1024) NULL,
							[Property10] [nvarchar](1024) NULL,
							[Property11] [nvarchar](1024) NULL,
							[Property12] [nvarchar](1024) NULL,
							[Property13] [nvarchar](1024) NULL,
							[Property14] [nvarchar](1024) NULL,
							[Property15] [nvarchar](1024) NULL,
							[Property16] [nvarchar](1024) NULL,
							[Property17] [nvarchar](1024) NULL,
							[Property18] [nvarchar](1024) NULL,
							[Property19] [nvarchar](1024) NULL,
							[Property20] [nvarchar](1024) NULL,
							[Source] [nvarchar](50) NULL,
						 CONSTRAINT [PK_DimensionData] PRIMARY KEY CLUSTERED 
						(
							[DimensionName] ASC,
							[Label] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create table DimensionHierarchyLevel'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[DimensionHierarchyLevel](
							[DimensionName] [nvarchar](100) NOT NULL,
							[HierarchyName] [nvarchar](100) NOT NULL,
							[LevelName] [nvarchar](100) NOT NULL,
							[SequenceNumber] [bigint] NULL,
						 CONSTRAINT [PK_DimensionHierarchyLevel] PRIMARY KEY CLUSTERED 
						(
							[DimensionName] ASC,
							[HierarchyName] ASC,
							[LevelName] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create table Model'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[Model](
							[ModelName] [nvarchar](100) NOT NULL,
							[ModelDescription] [nvarchar](512) NULL,
							[ModelType] [nvarchar](100) NOT NULL,
							[BaseModelID] [int] NULL,
							[SelectYN] [bit] NOT NULL,
						 CONSTRAINT [PK_Model] PRIMARY KEY CLUSTERED 
						(
							[ModelName] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]
			
						ALTER TABLE ' + @pcExchangeDatabase + '.[dbo].[Model] ADD  CONSTRAINT [DF_Model_SelectYN]  DEFAULT ((1)) FOR [SelectYN]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create table ModelDimension'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[ModelDimension](
							[ModelName] [nvarchar](100) NOT NULL,
							[DimensionName] [nvarchar](100) NOT NULL,
							[HideInExcel] [int] NULL,
							[SendToMemberId] [int] NULL,
						 CONSTRAINT [PK_ModelDimension] PRIMARY KEY CLUSTERED 
						(
							[ModelName] ASC,
							[DimensionName] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create table WorkbookLibrary'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[WorkbookLibrary](
							[ReportID] [int] IDENTITY(1,1) NOT NULL,
							[Label] [nvarchar](255) NOT NULL,
							[Contents] [image] NOT NULL,
							[ChangeDatetime] [datetime] NOT NULL,
							[Userid] [nvarchar](100) NULL,
							[Sec] [nvarchar](max) NOT NULL,
							[AuthorType] [nchar](1) NOT NULL,
							[SelectYN] [bit] NOT NULL,
						 CONSTRAINT [PK_WorkbookLibrary] PRIMARY KEY CLUSTERED 
						(
							[ReportID] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

						ALTER TABLE ' + @pcExchangeDatabase + '.[dbo].[WorkbookLibrary] ADD CONSTRAINT [DF_WorkbookLibrary_Sec]  DEFAULT ('''') FOR [Sec]
						ALTER TABLE ' + @pcExchangeDatabase + '.[dbo].[WorkbookLibrary] ADD CONSTRAINT [DF_WorkbookLibrary_AuthorType] DEFAULT (''C'') FOR [AuthorType]
						ALTER TABLE ' + @pcExchangeDatabase + '.[dbo].[WorkbookLibrary] ADD CONSTRAINT [DF_WorkbookLibrary_SelectYN]  DEFAULT ((1)) FOR [SelectYN]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create table SysParam'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[SysParam](
							[SysParamID] [int] NOT NULL,
							[Version] [nvarchar](50) NULL,
							[ApplicationName] [nvarchar](100) NULL,
							[SourceDatabase] [nvarchar](100) NULL
						 CONSTRAINT [PK_SysParam] PRIMARY KEY CLUSTERED 
						(
							[SysParamID] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

					SET @SQLStatement = '
						INSERT INTO ' + @pcExchangeDatabase + '.[dbo].[SysParam]
							(
							[SysParamID],
							[Version],
							[ApplicationName],
							[SourceDatabase]
							)
						SELECT
							[SysParamID] = 1,
							[Version] = ''' + @Version + ''',
							[ApplicationName] = ''' + @ApplicationName + ''',
							[SourceDatabase] = ''' + @SourceDatabase + ''''

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1
			END --End of mandatory tables

		IF @pcExchangeType IN ('SIE4') 
			BEGIN
				SET @Step = 'Create table SIE4_Balance'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[SIE4_Balance](
							[JobID] [int] NOT NULL,
							[Param] [nvarchar](50) NOT NULL,
							[RAR] [int] NOT NULL,
							[Account] [nvarchar](50) NOT NULL,
							[Amount] [decimal](18, 2) NOT NULL,
							[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Balance_Inserted]  DEFAULT (getdate()),
							[InsertedBy] [nvarchar](100) NOT NULL,
						 CONSTRAINT [PK_SIE4_Balance] PRIMARY KEY CLUSTERED 
						(
							[JobID] ASC,
							[Param] ASC,
							[RAR] ASC,
							[Account] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create table SIE4_Dim'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[SIE4_Dim](
							[JobID] [int] NOT NULL,
							[Param] [nvarchar](50) NOT NULL,
							[DimCode] [nvarchar](50) NOT NULL,
							[DimName] [nvarchar](100) NOT NULL,
							[DimParent] [nvarchar](50) NULL,
							[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Dim_Inserted]  DEFAULT (getdate()),
							[InsertedBy] [nvarchar](100) NOT NULL,
						 CONSTRAINT [PK_SIE4_Dim] PRIMARY KEY CLUSTERED 
						(
							[JobID] ASC,
							[Param] ASC,
							[DimCode] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create table SIE4_Job'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[SIE4_Job](
							[JobID] [int] IDENTITY(1,1) NOT NULL,
							[FLAGGA] [nvarchar](100) NULL,
							[PROGRAM] [nvarchar](100) NULL,
							[FORMAT] [nvarchar](100) NULL,
							[GEN] [nvarchar](100) NULL,
							[SIETYP] [nvarchar](100) NULL,
							[PROSA] [nvarchar](100) NULL,
							[FNR] [nvarchar](100) NULL,
							[ORGNR] [nvarchar](100) NULL,
							[BKOD] [nvarchar](100) NULL,
							[ADRESS] [nvarchar](100) NULL,
							[FNAMN] [nvarchar](100) NULL,
							[RAR_0_FROM] [int] NOT NULL,
							[RAR_0_TO] [int] NOT NULL,
							[RAR_1_FROM] [int] NULL,
							[RAR_1_TO] [int] NULL,
							[TAXAR] [nvarchar](50) NULL,
							[OMFATTN] [nvarchar](100) NULL,
							[KPTYP] [nvarchar](50) NULL,
							[VALUTA] [nchar](3) NULL,
							[KSUMMA] [nvarchar](100) NULL,
							[SentRows] [int] NULL,
							[StartTime] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Load_StartTime]  DEFAULT (getdate()),
							[EndTime] [datetime] NULL,
							[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Load_Inserted]  DEFAULT (getdate()),
							[InsertedBy] [nvarchar](100) NOT NULL,
						 CONSTRAINT [PK_SIE4_Load] PRIMARY KEY CLUSTERED 
						(
							[JobID] DESC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create table SIE4_Object'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[SIE4_Object](
							[JobID] [int] NOT NULL,
							[Param] [nvarchar](50) NOT NULL,
							[DimCode] [nvarchar](50) NOT NULL,
							[ObjectCode] [nvarchar](50) NOT NULL,
							[ObjectName] [nvarchar](100) NOT NULL,
							[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Objekt_Inserted]  DEFAULT (getdate()),
							[InsertedBy] [nvarchar](100) NOT NULL,
						 CONSTRAINT [PK_SIE4_Objekt] PRIMARY KEY CLUSTERED 
						(
							[JobID] ASC,
							[Param] ASC,
							[DimCode] ASC,
							[ObjectCode] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create table SIE4_Other'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[SIE4_Other](
							[JobID] [int] NOT NULL,
							[Param] [nvarchar](50) NOT NULL,
							[String] [nvarchar](255) NOT NULL,
							[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Other_Inserted]  DEFAULT (getdate()),
							[InsertedBy] [nvarchar](100) NOT NULL,
						 CONSTRAINT [PK_SIE4_Other] PRIMARY KEY CLUSTERED 
						(
							[JobID] ASC,
							[Param] ASC,
							[String] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create table SIE4_Trans'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[SIE4_Trans](
							[JobID] [int] NOT NULL,
							[Param] [nvarchar](50) NOT NULL,
							[Seq] [nvarchar](50) NOT NULL,
							[Ver] [nvarchar](50) NOT NULL,
							[Trans] [int] NOT NULL,
							[Account] [nvarchar](50) NOT NULL,
							[DimCode_01] [nvarchar](50) NULL,
							[ObjectCode_01] [nvarchar](50) NULL,
							[DimCode_02] [nvarchar](50) NULL,
							[ObjectCode_02] [nvarchar](50) NULL,
							[DimCode_03] [nvarchar](50) NULL,
							[ObjectCode_03] [nvarchar](50) NULL,
							[DimCode_04] [nvarchar](50) NULL,
							[ObjectCode_04] [nvarchar](50) NULL,
							[DimCode_05] [nvarchar](50) NULL,
							[ObjectCode_05] [nvarchar](50) NULL,
							[DimCode_06] [nvarchar](50) NULL,
							[ObjectCode_06] [nvarchar](50) NULL,
							[DimCode_07] [nvarchar](50) NULL,
							[ObjectCode_07] [nvarchar](50) NULL,
							[DimCode_08] [nvarchar](50) NULL,
							[ObjectCode_08] [nvarchar](50) NULL,
							[DimCode_09] [nvarchar](50) NULL,
							[ObjectCode_09] [nvarchar](50) NULL,
							[DimCode_10] [nvarchar](50) NULL,
							[ObjectCode_10] [nvarchar](50) NULL,
							[DimCode_11] [nvarchar](50) NULL,
							[ObjectCode_11] [nvarchar](50) NULL,
							[DimCode_12] [nvarchar](50) NULL,
							[ObjectCode_12] [nvarchar](50) NULL,
							[DimCode_13] [nvarchar](50) NULL,
							[ObjectCode_13] [nvarchar](50) NULL,
							[DimCode_14] [nvarchar](50) NULL,
							[ObjectCode_14] [nvarchar](50) NULL,
							[DimCode_15] [nvarchar](50) NULL,
							[ObjectCode_15] [nvarchar](50) NULL,
							[DimCode_16] [nvarchar](50) NULL,
							[ObjectCode_16] [nvarchar](50) NULL,
							[DimCode_17] [nvarchar](50) NULL,
							[ObjectCode_17] [nvarchar](50) NULL,
							[DimCode_18] [nvarchar](50) NULL,
							[ObjectCode_18] [nvarchar](50) NULL,
							[DimCode_19] [nvarchar](50) NULL,
							[ObjectCode_19] [nvarchar](50) NULL,
							[DimCode_20] [nvarchar](50) NULL,
							[ObjectCode_20] [nvarchar](50) NULL,
							[Amount] [decimal](18, 2) NOT NULL,
							[Date] [int] NOT NULL,
							[Description] [nvarchar](255) NULL,
							[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Trans_Inserted]  DEFAULT (getdate()),
							[InsertedBy] [nvarchar](100) NOT NULL,
						 CONSTRAINT [PK_SIE4_Trans] PRIMARY KEY CLUSTERED 
						(
							[JobID] ASC,
							[Param] ASC,
							[Seq] ASC,
							[Ver] ASC,
							[Trans] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create table SIE4_Ver'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[SIE4_Ver](
							[JobID] [int] NOT NULL,
							[Param] [nvarchar](50) NOT NULL,
							[Seq] [nvarchar](50) NOT NULL,
							[Ver] [nvarchar](50) NOT NULL,
							[Date] [int] NOT NULL,
							[Description] [nvarchar](255) NULL,
							[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Ver_Inserted]  DEFAULT (getdate()),
							[InsertedBy] [nvarchar](100) NOT NULL,
						 CONSTRAINT [PK_SIE4_Ver] PRIMARY KEY CLUSTERED 
						(
							[JobID] ASC,
							[Param] ASC,
							[Seq] ASC,
							[Ver] ASC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]'

					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create table JobLog'
					SET @SQLStatement = '
						CREATE TABLE ' + @pcExchangeDatabase + '.[dbo].[JobLog](
							[JobID] [int] NOT NULL,
							[JobLogID] [int] IDENTITY(1,1) NOT NULL,
							[StartTime] [datetime] NOT NULL,
							[ProcedureName] [nvarchar](100) NOT NULL,
							[Duration] [time](7) NOT NULL,
							[Deleted] [int] NOT NULL,
							[Inserted] [int] NOT NULL,
							[Updated] [int] NOT NULL,
							[ErrorNumber] [int] NOT NULL,
							[ErrorSeverity] [int] NULL,
							[ErrorState] [int] NULL,
							[ErrorProcedure] [nvarchar](128) NULL,
							[ErrorStep] [nvarchar](255) NULL,
							[ErrorLine] [int] NULL,
							[ErrorMessage] [nvarchar](4000) NULL,
							[Version] [nvarchar](50) NULL,
							CONSTRAINT [PK_JobLog] PRIMARY KEY CLUSTERED 
						(
							[JobLogID] DESC
						)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
						) ON [PRIMARY]
				
						ALTER TABLE ' + @pcExchangeDatabase + '.[dbo].[JobLog] ADD CONSTRAINT [DF_JobLog_JobID] DEFAULT ((0)) FOR [JobID]
						ALTER TABLE ' + @pcExchangeDatabase + '.[dbo].[JobLog] ADD CONSTRAINT [DF_JobLog_ErrorNumber] DEFAULT ((0)) FOR [ErrorNumber]'
			
						IF @Debug <> 0 PRINT @SQLStatement 
						EXEC (@SQLStatement)
						SET @Inserted = @Inserted + 1

			END --End of SIE4 tables

	-------------------------------
	SET @Step = 'CREATE PROCEDURES'
	-------------------------------

		IF @pcExchangeType IN ('Demo', 'Upgrade')
			BEGIN

				SET @Step = 'Create procedure spGet_Dimension'
					SET @SQLStatement = '
CREATE PROCEDURE [dbo].[spGet_Dimension] 
@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--spGet_Dimension @Debug = 1

DECLARE
	@SourceDatabase nvarchar(100), 
	@object_id int,
	@DimensionName nvarchar(100),
	@Counter int,
	@PropertyName nvarchar(100),
	@PropertyDataTypeID int,
	@PropertySize int,
	@PropertyDefaultValue nvarchar(100),
	@PropertyMemberDimension nvarchar(100),
	@PropertyMemberHierarchy nvarchar(100),
	@HierarchyName nvarchar(100),
	@SQLStatement nvarchar(max)

--Get Variables
SELECT @SourceDatabase = SourceDatabase FROM SysParam WHERE SysParamID = 1

TRUNCATE TABLE Dimension

SET @SQLStatement = ''''
INSERT INTO Dimension
	(
	DimensionName,
    DimensionDescription,
	DimensionID,
	DimensionTypeID,
    [Type],
	[object_id]
	)
SELECT 
	DimensionName = DD.[Label],
    DimensionDescription = DD.[Description],
	DimensionID = COALESCE(D1.DimensionID, D2.DimensionID, D3.DimensionID, D4.DimensionID, 0),
	DimensionTypeID = COALESCE(DT1.DimensionTypeID, DT2.DimensionTypeID, DT3.DimensionTypeID, DT4.DimensionTypeID, DT5.DimensionTypeID, DT6.DimensionTypeID, DT7.DimensionTypeID, DT8.DimensionTypeID, D2.DimensionTypeID, 0),
    DD.[Type],
	ST.object_id
FROM
	['''' + @SourceDatabase + ''''].[dbo].[Dimensions] DD
	INNER JOIN ['''' + @SourceDatabase + ''''].[sys].tables ST ON ST.name = ''''''''DS_'''''''' + DD.[Label]
	LEFT JOIN pcINTEGRATOR..DimensionType DT1 ON DT1.DimensionTypeName = DD.Type AND DD.Type <> ''''''''Generic''''''''
	LEFT JOIN pcINTEGRATOR..DimensionType DT2 ON DT2.DimensionTypeName = DD.[Label]
	LEFT JOIN pcINTEGRATOR..DimensionType DT3 ON DT3.DimensionTypeName = ''''''''GLSegment'''''''' AND DD.[Label] LIKE ''''''''GL_%''''''''
	LEFT JOIN pcINTEGRATOR..DimensionType DT4 ON DT4.DimensionTypeName = ''''''''CustomerProperty'''''''' AND DD.[Label] LIKE ''''''''Customer%''''''''
	LEFT JOIN pcINTEGRATOR..DimensionType DT5 ON DT5.DimensionTypeName = ''''''''ProductProperty'''''''' AND DD.[Label] LIKE ''''''''Product%''''''''
	LEFT JOIN pcINTEGRATOR..DimensionType DT6 ON DT6.DimensionTypeName = ''''''''StatisticClass'''''''' AND DD.[Label] IN (''''''''SNI'''''''', ''''''''SIC'''''''', ''''''''NAICS'''''''', ''''''''ISIC'''''''', ''''''''NACE'''''''')	
	LEFT JOIN pcINTEGRATOR..DimensionType DT7 ON DT7.DimensionTypeName = ''''''''BaseCurrency'''''''' AND DD.[Label] IN (''''''''ReportingCurrency'''''''')	
	LEFT JOIN pcINTEGRATOR..DimensionType DT8 ON DT8.DimensionTypeName = ''''''''AccountManager'''''''' AND DD.[Label] IN (''''''''SalesMan'''''''')	
	LEFT JOIN pcINTEGRATOR..Dimension D1 ON D1.DimensionName = DD.Label AND D1.DimensionTypeID = COALESCE(DT1.DimensionTypeID, DT2.DimensionTypeID, DT3.DimensionTypeID, DT4.DimensionTypeID, DT5.DimensionTypeID, DT6.DimensionTypeID, DT7.DimensionTypeID, DT8.DimensionTypeID, 0) AND D1.SelectYN <> 0
	LEFT JOIN pcINTEGRATOR..Dimension D2 ON D2.DimensionName = DD.Label AND D2.SelectYN <> 0
	LEFT JOIN pcINTEGRATOR..Dimension D3 ON D3.DimensionTypeID = DT7.DimensionTypeID AND D3.DimensionName = ''''''''BaseCurrency'''''''' AND D3.SelectYN <> 0
	LEFT JOIN pcINTEGRATOR..Dimension D4 ON D4.DimensionTypeID = DT8.DimensionTypeID AND D4.DimensionName = ''''''''AccountManager'''''''' AND D4.SelectYN <> 0
ORDER BY
	DD.[Label]''''

IF @Debug <> 0 PRINT @SQLStatement
EXEC (@SQLStatement)

--Create Temp tables
CREATE TABLE #Property_Cursor
	(
	PropertyName nvarchar(100),
	PropertyDataTypeID int,
	PropertySize int,
	PropertyDefaultValue nvarchar(100),
	PropertyMemberDimension nvarchar(100),
	PropertyMemberHierarchy nvarchar(100)
	)

CREATE TABLE #DimensionHierarchy
	(
	DimensionName nvarchar(100),
	HierarchyName nvarchar(100)
	)

SET @SQLStatement = ''''
INSERT INTO #DimensionHierarchy
	(
	DimensionName,
	HierarchyName
	)
SELECT
	DimensionName = Dimension, 
	HierarchyName = Hierarchy 
FROM 
	['''' + @SourceDatabase + ''''].dbo.DimensionHierarchies''''

IF @Debug <> 0 PRINT @SQLStatement
EXEC (@SQLStatement)

CREATE TABLE #XML
(
 DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT NOT NULL,
 XmlDef xml NOT NULL
)

--Add Hierarchies and Properties
	DECLARE Dimension_Cursor CURSOR FOR
		SELECT object_id, DimensionName FROM Dimension

		OPEN Dimension_Cursor
		FETCH NEXT FROM Dimension_Cursor INTO @object_id, @DimensionName

		WHILE @@FETCH_STATUS = 0
		  BEGIN
			TRUNCATE TABLE #XML
			SET @SQLStatement = ''''
			INSERT INTO #XML
				(
				DimensionName,
				XmlDef
				)
			SELECT
				DimensionName = ADO.Label,
				XmlDef = CONVERT(xml, CONVERT(varchar(MAX), CONVERT(varbinary(max), ADO.[XmlDef])))
			FROM
				['''' + @SourceDatabase + ''''].[dbo].[ApplicationDefinitionObjects] ADO
			WHERE
				[Type] = ''''''''Dimension'''''''' AND 
				[Label] = '''''''''''' + @DimensionName + '''''''''''' AND
				[Version] = 0''''

			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

			IF @Debug <> 0
				BEGIN
					;WITH XMLNAMESPACES (DEFAULT ''''http://www.perlielab.com/'''')
					SELECT
					 DimensionName,
					 DefaultHierarchy = Data1.PD.value(''''@DefaultHierarchy'''', ''''nvarchar(100)'''')
					FROM #XML
					CROSS APPLY XmlDef.nodes(''''/DimensionDefinition'''') as Data1(PD)
				END

			;WITH XMLNAMESPACES (DEFAULT ''''http://www.perlielab.com/'''')
			UPDATE D
			SET
				DefaultHierarchy = X.DefaultHierarchy
			FROM
				Dimension D
				INNER JOIN
				(
				SELECT
				 DimensionName,
				 DefaultHierarchy = Data1.PD.value(''''@DefaultHierarchy'''', ''''nvarchar(100)'''')
				FROM #XML
				CROSS APPLY XmlDef.nodes(''''/DimensionDefinition'''') as Data1(PD)
				) X ON X.DimensionName = D.DimensionName

			SET @Counter = 0
			DECLARE Hierarchy_Cursor CURSOR FOR

				SELECT
					HierarchyName 
				FROM
					#DimensionHierarchy
				WHERE
					DimensionName = @DimensionName
				ORDER BY
					HierarchyName

				OPEN Hierarchy_Cursor
				FETCH NEXT FROM Hierarchy_Cursor INTO @HierarchyName

				WHILE @@FETCH_STATUS = 0 AND @Counter <= 5
				  BEGIN
					SET @Counter = @Counter + 1
					IF @Debug <> 0 SELECT DimensionName = @DimensionName,  HierarchyName = @HierarchyName, [Counter] = @Counter

					SET @SQLStatement = ''''
						UPDATE Dimension
						SET
							HierarchyName'''' + CONVERT(nvarchar(10), @Counter) + '''' = '''''''''''' + @HierarchyName + ''''''''''''
						WHERE
							object_id = '''' + CONVERT(nvarchar(20), @object_id)
					
					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
			
					FETCH NEXT FROM Hierarchy_Cursor INTO @HierarchyName
				  END

			CLOSE Hierarchy_Cursor
			DEALLOCATE Hierarchy_Cursor	

			TRUNCATE TABLE #Property_Cursor

			--Without defining XMLNAMESPACES http://www.perlielab.com/
			SET @SQLStatement = ''''
				INSERT INTO #Property_Cursor
					(
					PropertyName,
					PropertyDataTypeID,
					PropertySize,
					PropertyDefaultValue,
					PropertyMemberDimension,
					PropertyMemberHierarchy
					)
				SELECT
					PropertyName = c.name,
					PropertyDataTypeID = DT.DataTypeID,
					PropertySize = CASE WHEN DT.DataTypeID = 2 THEN c.max_length/2 ELSE '''''''''''''''' END,
					PropertyDefaultValue = X.PropertyDefaultValue,
					PropertyMemberDimension = X.PropertyMemberDimension,
					PropertyMemberHierarchy = X.PropertyMemberHierarchy
				FROM
					['''' + @SourceDatabase + ''''].[sys].columns C
					INNER JOIN ['''' + @SourceDatabase + ''''].[sys].types T ON T.system_type_id = C.system_type_id AND T.user_type_id = C.user_type_id
					INNER JOIN
						(
						SELECT
							DimensionName,
							PropertyName  = Data2.PD.value(''''''''@Label'''''''', ''''''''nvarchar(100)''''''''),
							PropertyDefaultValue = Data2.PD.value(''''''''@DefaultValue'''''''', ''''''''nvarchar(100)''''''''),
							PropertyMemberDimension = Data2.PD.value(''''''''@MemberDimension'''''''', ''''''''nvarchar(100)''''''''),
							PropertyMemberHierarchy = Data2.PD.value(''''''''@MemberHierarchy'''''''', ''''''''nvarchar(100)'''''''')
						FROM #XML
						CROSS APPLY XmlDef.nodes(''''''''/DimensionDefinition/PropertyDefinition'''''''') as Data2(PD)
						) X ON X.DimensionName = '''''''''''' + @DimensionName + '''''''''''' AND X.PropertyName = c.name''''
					
					SET @SQLStatement = @SQLStatement + ''''
					LEFT JOIN 
						(
						SELECT
							name = REPLACE(C.name, ''''''''_MemberId'''''''', '''''''''''''''')
						FROM
							['''' + @SourceDatabase + ''''].[sys].columns C
						WHERE
							object_id = '''' + CONVERT(nvarchar(20), @object_id) + ''''
						GROUP BY
							REPLACE(C.name, ''''''''_MemberId'''''''', '''''''''''''''')
						HAVING
							COUNT(1) > 1
						) MemberSub ON MemberSub.name = C.name
					LEFT JOIN pcINTEGRATOR..DataType DT ON DT.DataTypeID BETWEEN 1 AND 5 AND DT.DataTypeCode = t.name AND (CASE WHEN MemberSub.name IS NOT NULL THEN ''''''''Member'''''''' ELSE ''''''''Text'''''''' END = DT.DataTypeName OR DT.DataTypeID NOT IN (2, 3))
				WHERE
					object_id = '''' + CONVERT(nvarchar(20), @object_id) + '''' AND
					C.name NOT IN (''''''''MemberId'''''''', ''''''''Label'''''''', ''''''''Description'''''''', ''''''''Source'''''''', ''''''''Synchronized'''''''') AND
					C.name NOT LIKE ''''''''%_MemberId''''''''''''

			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

			IF (SELECT COUNT(1) FROM #Property_Cursor) = 0
				BEGIN
					--With defining XMLNAMESPACES http://www.perlielab.com/
					SET @SQLStatement = ''''
						;WITH XMLNAMESPACES (DEFAULT ''''''''http://www.perlielab.com/'''''''')
						INSERT INTO #Property_Cursor
							(
							PropertyName,
							PropertyDataTypeID,
							PropertySize,
							PropertyDefaultValue,
							PropertyMemberDimension,
							PropertyMemberHierarchy
							)
						SELECT
							PropertyName = c.name,
							PropertyDataTypeID = DT.DataTypeID,
							PropertySize = CASE WHEN DT.DataTypeID = 2 THEN c.max_length/2 ELSE '''''''''''''''' END,
							PropertyDefaultValue = X.PropertyDefaultValue,
							PropertyMemberDimension = X.PropertyMemberDimension,
							PropertyMemberHierarchy = X.PropertyMemberHierarchy
						FROM
							['''' + @SourceDatabase + ''''].[sys].columns C
							INNER JOIN ['''' + @SourceDatabase + ''''].[sys].types T ON T.system_type_id = C.system_type_id AND T.user_type_id = C.user_type_id
							INNER JOIN
								(
								SELECT
									DimensionName,
									PropertyName  = Data2.PD.value(''''''''@Label'''''''', ''''''''nvarchar(100)''''''''),
									PropertyDefaultValue = Data2.PD.value(''''''''@DefaultValue'''''''', ''''''''nvarchar(100)''''''''),
									PropertyMemberDimension = Data2.PD.value(''''''''@MemberDimension'''''''', ''''''''nvarchar(100)''''''''),
									PropertyMemberHierarchy = Data2.PD.value(''''''''@MemberHierarchy'''''''', ''''''''nvarchar(100)'''''''')
								FROM #XML
								CROSS APPLY XmlDef.nodes(''''''''/DimensionDefinition/PropertyDefinition'''''''') as Data2(PD)
								) X ON X.DimensionName = '''''''''''' + @DimensionName + '''''''''''' AND X.PropertyName = c.name
							LEFT JOIN 
								(
								SELECT
									name = REPLACE(C.name, ''''''''_MemberId'''''''', '''''''''''''''')
								FROM
									['''' + @SourceDatabase + ''''].[sys].columns C
								WHERE
									object_id = '''' + CONVERT(nvarchar(20), @object_id) + ''''
								GROUP BY
									REPLACE(C.name, ''''''''_MemberId'''''''', '''''''''''''''')
								HAVING
									COUNT(1) > 1
								) MemberSub ON MemberSub.name = C.name
							LEFT JOIN pcINTEGRATOR..DataType DT ON DT.DataTypeID BETWEEN 1 AND 5 AND DT.DataTypeCode = t.name AND (CASE WHEN MemberSub.name IS NOT NULL THEN ''''''''Member'''''''' ELSE ''''''''Text'''''''' END = DT.DataTypeName OR DT.DataTypeID NOT IN (2, 3))
						WHERE
							object_id = '''' + CONVERT(nvarchar(20), @object_id) + '''' AND
							C.name NOT IN (''''''''MemberId'''''''', ''''''''Label'''''''', ''''''''Description'''''''', ''''''''Source'''''''', ''''''''Synchronized'''''''') AND
							C.name NOT LIKE ''''''''%_MemberId''''''''''''

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
				END

			SET @Counter = 0
			DECLARE Property_Cursor CURSOR FOR

				SELECT
					PropertyName,
					PropertyDataTypeID,
					PropertySize,
					PropertyDefaultValue,
					PropertyMemberDimension,
					PropertyMemberHierarchy
				FROM
					#Property_Cursor
				WHERE
					NOT (PropertyDataTypeID = 3 AND PropertyMemberDimension IS NULL)
				ORDER BY
					CASE WHEN PropertyName IN (''''Source'''', ''''Synchronized'''') THEN 2 ELSE 1 END,
					PropertyName

				OPEN Property_Cursor
				FETCH NEXT FROM Property_Cursor INTO @PropertyName, @PropertyDataTypeID, @PropertySize, @PropertyDefaultValue, @PropertyMemberDimension, @PropertyMemberHierarchy

				WHILE @@FETCH_STATUS = 0
				  BEGIN
					SET @Counter = @Counter + 1
					IF @Debug <> 0 SELECT DimensionName = @DimensionName,  PropertyName = @PropertyName, PropertyDataTypeID = @PropertyDataTypeID, PropertySize = @PropertySize, [Counter] = @Counter

					SET @SQLStatement = ''''
						UPDATE Dimension
						SET
							PropertyName'''' + CASE WHEN @Counter <= 9 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar(10), @Counter) + '''' = '''''''''''' + @PropertyName + '''''''''''', 
							PropertyDataTypeID'''' + CASE WHEN @Counter <= 9 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar(10), @Counter) + '''' = '''' + CONVERT(nvarchar(10), @PropertyDataTypeID) + '''', 
							PropertySize'''' + CASE WHEN @Counter <= 9 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar(10), @Counter) + '''' = '''' + CONVERT(nvarchar(10), @PropertySize) + '''',
							PropertyDefaultValue'''' + CASE WHEN @Counter <= 9 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar(10), @Counter) + '''' = '''' + CASE WHEN @PropertyDefaultValue IS NULL THEN ''''NULL'''' ELSE '''''''''''''''' + @PropertyDefaultValue + '''''''''''''''' END + '''',
							PropertyMemberDimension'''' + CASE WHEN @Counter <= 9 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar(10), @Counter) + '''' = '''' + CASE WHEN @PropertyMemberDimension IS NULL THEN ''''NULL'''' ELSE '''''''''''''''' + @PropertyMemberDimension + '''''''''''''''' END + '''',
							PropertyMemberHierarchy'''' + CASE WHEN @Counter <= 9 THEN ''''0'''' ELSE '''''''' END + CONVERT(nvarchar(10), @Counter) + '''' = '''' + CASE WHEN @PropertyMemberHierarchy IS NULL THEN ''''NULL'''' ELSE '''''''''''''''' + @PropertyMemberHierarchy + '''''''''''''''' END + ''''
						WHERE
							object_id = '''' + CONVERT(nvarchar(20), @object_id)

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
			
					FETCH NEXT FROM Property_Cursor INTO @PropertyName, @PropertyDataTypeID, @PropertySize, @PropertyDefaultValue, @PropertyMemberDimension, @PropertyMemberHierarchy
				  END

			CLOSE Property_Cursor
			DEALLOCATE Property_Cursor	

			SET @SQLStatement = ''''
				UPDATE D
				SET
					SourceYN = CASE WHEN C.object_id IS NULL THEN 0 ELSE 1 END
				FROM 
					Dimension D
					LEFT JOIN ['''' + @SourceDatabase + ''''].[sys].columns C ON C.object_id = D.object_id AND C.name = ''''''''Source''''''''
				WHERE
					D.object_id = '''' + CONVERT(nvarchar(20), @object_id)

			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

			FETCH NEXT FROM Dimension_Cursor INTO @object_id, @DimensionName
		  END

	CLOSE Dimension_Cursor
	DEALLOCATE Dimension_Cursor	

UPDATE Dimension
SET
	DefaultHierarchy = DimensionName + ''''_'''' + HierarchyName1
WHERE
	(DefaultHierarchy IS NULL OR DefaultHierarchy = '''''''') AND
	LEN(DimensionName) > 1 AND
	LEN(HierarchyName1) > 1

DROP TABLE #DimensionHierarchy
DROP TABLE #Property_Cursor
DROP TABLE #XML'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spGet_Dimension] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spGet_DimensionHierarchyLevel'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spGet_DimensionHierarchyLevel] 

@Debug bit = 0
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--spGet_DimensionHierarchyLevel @Debug = 1

DECLARE
	@SourceDatabase nvarchar(100), 
	@SQLStatement nvarchar(max)

--Get Variables
SELECT @SourceDatabase = SourceDatabase FROM SysParam WHERE SysParamID = 1

TRUNCATE TABLE DimensionHierarchyLevel

SET @SQLStatement = ''''

INSERT INTO DimensionHierarchyLevel
	(
	[DimensionName],
	[HierarchyName],
    [LevelName],
    [SequenceNumber]
	)
SELECT 
	[DimensionName] = [Dimension],
	[HierarchyName] = [Hierarchy],
    [LevelName],
    [SequenceNumber]
FROM
	['''' + @SourceDatabase + ''''].[dbo].[DimensionHierarchyLevels]
''''

IF @Debug <> 0 PRINT @SQLStatement
EXEC (@SQLStatement)'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1


				SET @Step = 'Create procedure spGet_DimensionData'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spGet_DimensionData] 
@Debug bit = 0
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--spGet_DimensionData @Debug = 1

DECLARE 
	@SourceDatabase nvarchar(100),
	@DimensionName nvarchar(100),
	@Counter int,
	@HierarchyName1 nvarchar(100),
	@HierarchyName2 nvarchar(100),
	@HierarchyName3 nvarchar(100),
	@HierarchyName4 nvarchar(100),
	@HierarchyName5 nvarchar(100),
	@PropertyName01 nvarchar(100),
	@PropertyName02 nvarchar(100),
	@PropertyName03 nvarchar(100),
	@PropertyName04 nvarchar(100),
	@PropertyName05 nvarchar(100),
	@PropertyName06 nvarchar(100),
	@PropertyName07 nvarchar(100),
	@PropertyName08 nvarchar(100),
	@PropertyName09 nvarchar(100),
	@PropertyName10 nvarchar(100),
	@PropertyName11 nvarchar(100),
	@PropertyName12 nvarchar(100),
	@PropertyName13 nvarchar(100),
	@PropertyName14 nvarchar(100),
	@PropertyName15 nvarchar(100),
	@PropertyName16 nvarchar(100),
	@PropertyName17 nvarchar(100),
	@PropertyName18 nvarchar(100),
	@PropertyName19 nvarchar(100),
	@PropertyName20 nvarchar(100),
	@PropertyDataTypeID01 int,
	@PropertyDataTypeID02 int,
	@PropertyDataTypeID03 int,
	@PropertyDataTypeID04 int,
	@PropertyDataTypeID05 int,
	@PropertyDataTypeID06 int,
	@PropertyDataTypeID07 int,
	@PropertyDataTypeID08 int,
	@PropertyDataTypeID09 int,
	@PropertyDataTypeID10 int,
	@PropertyDataTypeID11 int,
	@PropertyDataTypeID12 int,
	@PropertyDataTypeID13 int,
	@PropertyDataTypeID14 int,
	@PropertyDataTypeID15 int,
	@PropertyDataTypeID16 int,
	@PropertyDataTypeID17 int,
	@PropertyDataTypeID18 int,
	@PropertyDataTypeID19 int,
	@PropertyDataTypeID20 int,
	@SourceYN bit,
	@SQLStatement nvarchar(max)

--Get Variables
SELECT @SourceDatabase = SourceDatabase FROM SysParam WHERE SysParamID = 1

TRUNCATE TABLE DimensionData

	DECLARE DimensionData_Cursor CURSOR FOR
		SELECT
			DimensionName,
			HierarchyName1,
			HierarchyName2,
			HierarchyName3,
			HierarchyName4,
			HierarchyName5,
			PropertyName01,
			PropertyDataTypeID01,
			PropertyName02,
			PropertyDataTypeID02,
			PropertyName03,
			PropertyDataTypeID03,
			PropertyName04,
			PropertyDataTypeID04,
			PropertyName05,
			PropertyDataTypeID05,
			PropertyName06,
			PropertyDataTypeID06,
			PropertyName07,
			PropertyDataTypeID07,
			PropertyName08,
			PropertyDataTypeID08,
			PropertyName09,
			PropertyDataTypeID09,
			PropertyName10,
			PropertyDataTypeID10,
			PropertyName11,
			PropertyDataTypeID11,
			PropertyName12,
			PropertyDataTypeID12,
			PropertyName13,
			PropertyDataTypeID13,
			PropertyName14,
			PropertyDataTypeID14,
			PropertyName15,
			PropertyDataTypeID15,
			PropertyName16,
			PropertyDataTypeID16,
			PropertyName17,
			PropertyDataTypeID17,
			PropertyName18,
			PropertyDataTypeID18,
			PropertyName19,
			PropertyDataTypeID19,
			PropertyName20,
			PropertyDataTypeID20,
			SourceYN
		FROM
			Dimension

		OPEN DimensionData_Cursor
		FETCH NEXT FROM DimensionData_Cursor INTO @DimensionName, @HierarchyName1, @HierarchyName2, @HierarchyName3, @HierarchyName4, @HierarchyName5, @PropertyName01, @PropertyDataTypeID01, @PropertyName02, @PropertyDataTypeID02, @PropertyName03, @PropertyDataTypeID03, @PropertyName04, @PropertyDataTypeID04, @PropertyName05, @PropertyDataTypeID05, @PropertyName06, @PropertyDataTypeID06, @PropertyName07, @PropertyDataTypeID07, @PropertyName08, @PropertyDataTypeID08, @PropertyName09, @PropertyDataTypeID09, @PropertyName10, @PropertyDataTypeID10, @PropertyName11, @PropertyDataTypeID11, @PropertyName12, @PropertyDataTypeID12, @PropertyName13, @PropertyDataTypeID13, @PropertyName14, @PropertyDataTypeID14, @PropertyName15, @PropertyDataTypeID15, @PropertyName16, @PropertyDataTypeID16, @PropertyName17, @PropertyDataTypeID17, @PropertyName18, @PropertyDataTypeID18, @PropertyName19, @PropertyDataTypeID19, @PropertyName20, @PropertyDataTypeID20, @SourceYN


		WHILE @@FETCH_STATUS = 0
		  BEGIN
			SET @Counter = 0
			SET @SQLStatement = ''''
			INSERT INTO DimensionData
				(
				[DimensionName],
				[MemberId],
				[Label],
				[Description],
				[Parent1],
				[SortOrder1],
				[Parent2],
				[SortOrder2],
				[Parent3],
				[SortOrder3],
				[Parent4],
				[SortOrder4],
				[Parent5],
				[SortOrder5],
				[Property01],
				[Property02],
				[Property03],
				[Property04],
				[Property05],
				[Property06],
				[Property07],
				[Property08],
				[Property09],
				[Property10],
				[Property11],
				[Property12],
				[Property13],
				[Property14],
				[Property15],
				[Property16],
				[Property17],
				[Property18],
				[Property19],
				[Property20],
				[Source]
				)''''

							SET @SQLStatement = @SQLStatement + ''''
			SELECT 
				[DimensionName] = '''''''''''' + @DimensionName + '''''''''''',
				[MemberId] = CASE D.[Label] WHEN ''''''''NONE'''''''' THEN -1 WHEN ''''''''All_'''''''' THEN 1 ELSE NULL END,
				[Label] = D.[Label],
				[Description] = MAX(D.[Description]),
				[Parent1] = '''' + CASE WHEN @HierarchyName1 IS NULL THEN ''''NULL'''' ELSE ''''MAX(PD1.Label)'''' END + '''',
				[SortOrder1] = '''' + CASE WHEN @HierarchyName1 IS NULL THEN ''''NULL'''' ELSE ''''MAX(H1.SequenceNumber)'''' END + '''',
				[Parent2] = '''' + CASE WHEN @HierarchyName2 IS NULL THEN ''''NULL'''' ELSE ''''MAX(PD2.Label)'''' END + '''',
				[SortOrder2] = '''' + CASE WHEN @HierarchyName2 IS NULL THEN ''''NULL'''' ELSE ''''MAX(H2.SequenceNumber)'''' END + '''',
				[Parent3] = '''' + CASE WHEN @HierarchyName3 IS NULL THEN ''''NULL'''' ELSE ''''MAX(PD3.Label)'''' END + '''',
				[SortOrder3] = '''' + CASE WHEN @HierarchyName3 IS NULL THEN ''''NULL'''' ELSE ''''MAX(H3.SequenceNumber)'''' END + '''',
				[Parent4] = '''' + CASE WHEN @HierarchyName4 IS NULL THEN ''''NULL'''' ELSE ''''MAX(PD4.Label)'''' END + '''',
				[SortOrder4] = '''' + CASE WHEN @HierarchyName4 IS NULL THEN ''''NULL'''' ELSE ''''MAX(H4.SequenceNumber)'''' END + '''',
				[Parent5] = '''' + CASE WHEN @HierarchyName5 IS NULL THEN ''''NULL'''' ELSE ''''MAX(PD5.Label)'''' END + '''',
				[SortOrder5] = '''' + CASE WHEN @HierarchyName5 IS NULL THEN ''''NULL'''' ELSE ''''MAX(H5.SequenceNumber)'''' END + '''',
				[Property01] = '''' + CASE WHEN @PropertyName01 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID01 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName01 + ''''])'''' ELSE ''''D.['''' + @PropertyName01 + '''']'''' END + '''')'''' END + '''',
				[Property02] = '''' + CASE WHEN @PropertyName02 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID02 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName02 + ''''])'''' ELSE ''''D.['''' + @PropertyName02 + '''']'''' END + '''')'''' END + '''',
				[Property03] = '''' + CASE WHEN @PropertyName03 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID03 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName03 + ''''])'''' ELSE ''''D.['''' + @PropertyName03 + '''']'''' END + '''')'''' END + '''',
				[Property04] = '''' + CASE WHEN @PropertyName04 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID04 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName04 + ''''])'''' ELSE ''''D.['''' + @PropertyName04 + '''']'''' END + '''')'''' END + '''',
				[Property05] = '''' + CASE WHEN @PropertyName05 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID05 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName05 + ''''])'''' ELSE ''''D.['''' + @PropertyName05 + '''']'''' END + '''')'''' END + '''',
				[Property06] = '''' + CASE WHEN @PropertyName06 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID06 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName06 + ''''])'''' ELSE ''''D.['''' + @PropertyName06 + '''']'''' END + '''')'''' END + '''',''''

							SET @SQLStatement = @SQLStatement + ''''
				[Property07] = '''' + CASE WHEN @PropertyName07 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID07 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName07 + ''''])'''' ELSE ''''D.['''' + @PropertyName07 + '''']'''' END + '''')'''' END + '''',
				[Property08] = '''' + CASE WHEN @PropertyName08 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID08 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName08 + ''''])'''' ELSE ''''D.['''' + @PropertyName08 + '''']'''' END + '''')'''' END + '''',
				[Property09] = '''' + CASE WHEN @PropertyName09 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID09 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName09 + ''''])'''' ELSE ''''D.['''' + @PropertyName09 + '''']'''' END + '''')'''' END + '''',
				[Property10] = '''' + CASE WHEN @PropertyName10 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID10 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName10 + ''''])'''' ELSE ''''D.['''' + @PropertyName10 + '''']'''' END + '''')'''' END + '''',
				[Property11] = '''' + CASE WHEN @PropertyName11 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID11 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName11 + ''''])'''' ELSE ''''D.['''' + @PropertyName11 + '''']'''' END + '''')'''' END + '''',
				[Property12] = '''' + CASE WHEN @PropertyName12 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID12 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName12 + ''''])'''' ELSE ''''D.['''' + @PropertyName12 + '''']'''' END + '''')'''' END + '''',
				[Property13] = '''' + CASE WHEN @PropertyName13 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID13 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName13 + ''''])'''' ELSE ''''D.['''' + @PropertyName13 + '''']'''' END + '''')'''' END + '''',
				[Property14] = '''' + CASE WHEN @PropertyName14 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID14 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName14 + ''''])'''' ELSE ''''D.['''' + @PropertyName14 + '''']'''' END + '''')'''' END + '''',
				[Property15] = '''' + CASE WHEN @PropertyName15 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID15 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName15 + ''''])'''' ELSE ''''D.['''' + @PropertyName15 + '''']'''' END + '''')'''' END + '''',
				[Property16] = '''' + CASE WHEN @PropertyName16 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID16 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName16 + ''''])'''' ELSE ''''D.['''' + @PropertyName16 + '''']'''' END + '''')'''' END + '''',
				[Property17] = '''' + CASE WHEN @PropertyName17 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID17 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName17 + ''''])'''' ELSE ''''D.['''' + @PropertyName17 + '''']'''' END + '''')'''' END + '''',
				[Property18] = '''' + CASE WHEN @PropertyName18 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID18 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName18 + ''''])'''' ELSE ''''D.['''' + @PropertyName18 + '''']'''' END + '''')'''' END + '''',
				[Property19] = '''' + CASE WHEN @PropertyName19 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID19 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName19 + ''''])'''' ELSE ''''D.['''' + @PropertyName19 + '''']'''' END + '''')'''' END + '''',
				[Property20] = '''' + CASE WHEN @PropertyName20 IS NULL THEN ''''NULL'''' ELSE + ''''MAX('''' + CASE WHEN @PropertyDataTypeID20 = 4 THEN ''''CONVERT(int, D.['''' + @PropertyName20 + ''''])'''' ELSE ''''D.['''' + @PropertyName20 + '''']'''' END + '''')'''' END + '''',
				[Source] = MAX('''' + CASE WHEN ISNULL(@SourceYN, 0) <> 0 THEN ''''D.Source'''' ELSE + '''''''''''''''''''''''' END + '''')''''

							SET @SQLStatement = @SQLStatement + '''' 
			FROM
				'''' + @SourceDatabase + ''''..DS_'''' + @DimensionName + '''' D'''' + 
				CASE WHEN @HierarchyName1 IS NULL THEN '''''''' ELSE ''''
				LEFT JOIN '''' + @SourceDatabase + ''''..HS_'''' + @DimensionName + ''''_'''' + @HierarchyName1 + '''' H1 ON H1.MemberId = D.MemberID
				LEFT JOIN '''' + @SourceDatabase + ''''..DS_'''' + @DimensionName + '''' PD1 ON PD1.MemberID = H1.ParentMemberId'''' END +
				CASE WHEN @HierarchyName2 IS NULL THEN '''''''' ELSE ''''
				LEFT JOIN '''' + @SourceDatabase + ''''..HS_'''' + @DimensionName + ''''_'''' + @HierarchyName2 + '''' H2 ON H2.MemberId = D.MemberID
				LEFT JOIN '''' + @SourceDatabase + ''''..DS_'''' + @DimensionName + '''' PD2 ON PD2.MemberID = H2.ParentMemberId'''' END +
				CASE WHEN @HierarchyName3 IS NULL THEN '''''''' ELSE ''''
				LEFT JOIN '''' + @SourceDatabase + ''''..HS_'''' + @DimensionName + ''''_'''' + @HierarchyName3 + '''' H3 ON H3.MemberId = D.MemberID
				LEFT JOIN '''' + @SourceDatabase + ''''..DS_'''' + @DimensionName + '''' PD3 ON PD3.MemberID = H3.ParentMemberId'''' END +
				CASE WHEN @HierarchyName4 IS NULL THEN '''''''' ELSE ''''
				LEFT JOIN '''' + @SourceDatabase + ''''..HS_'''' + @DimensionName + ''''_'''' + @HierarchyName4 + '''' H4 ON H4.MemberId = D.MemberID
				LEFT JOIN '''' + @SourceDatabase + ''''..DS_'''' + @DimensionName + '''' PD4 ON PD4.MemberID = H4.ParentMemberId'''' END +
				CASE WHEN @HierarchyName5 IS NULL THEN '''''''' ELSE ''''
				LEFT JOIN '''' + @SourceDatabase + ''''..HS_'''' + @DimensionName + ''''_'''' + @HierarchyName5 + '''' H5 ON H5.MemberId = D.MemberID
				LEFT JOIN '''' + @SourceDatabase + ''''..DS_'''' + @DimensionName + '''' PD5 ON PD5.MemberID = H5.ParentMemberId'''' END + ''''
			GROUP BY
				D.[Label]''''

			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

			FETCH NEXT FROM DimensionData_Cursor INTO @DimensionName, @HierarchyName1, @HierarchyName2, @HierarchyName3, @HierarchyName4, @HierarchyName5, @PropertyName01, @PropertyDataTypeID01, @PropertyName02, @PropertyDataTypeID02, @PropertyName03, @PropertyDataTypeID03, @PropertyName04, @PropertyDataTypeID04, @PropertyName05, @PropertyDataTypeID05, @PropertyName06, @PropertyDataTypeID06, @PropertyName07, @PropertyDataTypeID07, @PropertyName08, @PropertyDataTypeID08, @PropertyName09, @PropertyDataTypeID09, @PropertyName10, @PropertyDataTypeID10, @PropertyName11, @PropertyDataTypeID11, @PropertyName12, @PropertyDataTypeID12, @PropertyName13, @PropertyDataTypeID13, @PropertyName14, @PropertyDataTypeID14, @PropertyName15, @PropertyDataTypeID15, @PropertyName16, @PropertyDataTypeID16, @PropertyName17, @PropertyDataTypeID17, @PropertyName18, @PropertyDataTypeID18, @PropertyName19, @PropertyDataTypeID19, @PropertyName20, @PropertyDataTypeID20, @SourceYN
		  END

	CLOSE DimensionData_Cursor
	DEALLOCATE DimensionData_Cursor'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Create procedure spGet_DimensionData', [SQLStatement] = @SQLStatement
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spGet_FactData'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spGet_FactData] 
@Debug bit = 0
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--spGet_FactData @Debug = 1

DECLARE 
	@SourceDatabase nvarchar(100),
	@ModelName nvarchar(100),
	@SQLStatement nvarchar(max)

--Get Variables
SELECT @SourceDatabase = SourceDatabase FROM SysParam WHERE SysParamID = 1

	DECLARE FactData_Cursor CURSOR FOR
		SELECT
			ModelName
		FROM
			Model

		OPEN FactData_Cursor
		FETCH NEXT FROM FactData_Cursor INTO @ModelName

		WHILE @@FETCH_STATUS = 0
		  BEGIN
			IF (SELECT COUNT(1) FROM sys.Tables WHERE name = ''''FactData_'''' + @ModelName) > 0
				BEGIN
					SET @SQLStatement = ''''DROP TABLE FactData_'''' + @ModelName
					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)
				END

			SET @SQLStatement = ''''SELECT * INTO FactData_'''' + @ModelName + '''' FROM '''' + @SourceDatabase + ''''.[dbo].[FACT_'''' + @ModelName + ''''_View]''''
			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

			FETCH NEXT FROM FactData_Cursor INTO @ModelName
		  END

	CLOSE FactData_Cursor
	DEALLOCATE FactData_Cursor'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spGet_Model'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spGet_Model] 

@Debug bit = 0
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--spGet_Model @Debug = 1

DECLARE
	@SourceDatabase nvarchar(100), 
	@SQLStatement nvarchar(max)

--Get Variables
SELECT @SourceDatabase = SourceDatabase FROM SysParam WHERE SysParamID = 1

TRUNCATE TABLE Model

SET @SQLStatement = ''''

INSERT INTO Model
	(
	ModelName,
	ModelDescription,
    ModelType,
	BaseModelID
	)
SELECT 
	ModelName = DM.[Label],
	ModelDescription = DM.[Description],
    ModelType = CASE WHEN DM.[Type] = ''''''''Generic'''''''' THEN ISNULL(M.ModelName, DM.Type) ELSE DM.[Type] END,
	BaseModelID = M.ModelID
FROM
	['''' + @SourceDatabase + ''''].[dbo].[Models] DM
	LEFT JOIN pcINTEGRATOR..Model M ON M.ModelID < 0 AND M.ModelName = CASE WHEN DM.[Type] = ''''''''Generic'''''''' THEN DM.[Label] ELSE DM.[Type] END
''''

IF @Debug <> 0 PRINT @SQLStatement
EXEC (@SQLStatement)'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spGet_ModelDimension'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spGet_ModelDimension] 

@Debug bit = 0
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--spGet_ModelDimension @Debug = 1

DECLARE
	@SourceDatabase nvarchar(100), 
	@SQLStatement nvarchar(max)

--Get Variables
SELECT @SourceDatabase = SourceDatabase FROM SysParam WHERE SysParamID = 1

TRUNCATE TABLE ModelDimension

SET @SQLStatement = ''''
INSERT INTO ModelDimension
	(
	ModelName,
	DimensionName,
	[HideInExcel],
    [SendToMemberId]
	)
SELECT 
	ModelName = DMD.[Model],
	DimensionName = DMD.[Dimension],
	[HideInExcel],
    [SendToMemberId]
FROM
	['''' + @SourceDatabase + ''''].[dbo].[ModelDimensions] DMD
''''

IF @Debug <> 0 PRINT @SQLStatement
EXEC (@SQLStatement)'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spGet_Verification'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spGet_Verification] 
@Debug bit = 0
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

SET NOCOUNT ON

DECLARE 
	@SourceDatabase nvarchar(100),
	@ModelName nvarchar(100),
	@Counter int,
	@Error nvarchar(max) = ''''''''

--Get Variables
SELECT @SourceDatabase = SourceDatabase FROM SysParam WHERE SysParamID = 1

SELECT
	ModelName = REPLACE(t.name, ''''FactData_'''', ''''''''),
	DimensionName = c.name
INTO
	#Verification	 
FROM
	sys.tables t
	INNER JOIN sys.columns c ON c.object_id = t.object_id AND c.name NOT IN (''''ChangeDatetime'''', ''''Userid'''')
WHERE
	t.name LIKE ''''FactData_%''''

IF @Debug <> 0 SELECT * FROM #Verification

IF (SELECT COUNT(1) FROM ModelDimension MD WHERE NOT EXISTS (SELECT 1 FROM Model M WHERE M.ModelName = MD.ModelName)) > 0
	SELECT @Error = @Error + CASE WHEN LEN(@Error) > 0 THEN CHAR(13) + CHAR(10) ELSE '''''''' END + ''''The Model '''' + MD.ModelName + '''' is not defined in the Meta data for models'''' FROM ModelDimension MD WHERE NOT EXISTS (SELECT 1 FROM Model M WHERE M.ModelName = MD.ModelName)

IF (SELECT COUNT(1) FROM ModelDimension MD WHERE NOT EXISTS (SELECT 1 FROM Dimension D WHERE D.DimensionName = MD.DimensionName)) > 0
	SELECT @Error = @Error + CASE WHEN LEN(@Error) > 0 THEN CHAR(13) + CHAR(10) ELSE '''''''' END + ''''The Dimension '''' + MD.DimensionName + '''' is not defined in the Meta data for dimensions'''' FROM ModelDimension MD WHERE NOT EXISTS (SELECT 1 FROM Dimension D WHERE D.DimensionName = MD.DimensionName)


	DECLARE Verification_Cursor CURSOR FOR
		SELECT
			ModelName
		FROM
			Model

		OPEN Verification_Cursor
		FETCH NEXT FROM Verification_Cursor INTO @ModelName

		WHILE @@FETCH_STATUS = 0
		  BEGIN
		  	SELECT
				@Counter = COUNT(1)
			FROM
				ModelDimension MD
			WHERE
				MD.ModelName = @ModelName AND
				MD.DimensionName <> @ModelName + ''''_Value''''

			IF @Debug <> 0 	SELECT [Counter] = @Counter

		  	IF (SELECT
					COUNT(1)
				FROM
					ModelDimension MD
					INNER JOIN #Verification V ON V.ModelName = MD.ModelName AND V.DimensionName = MD.DimensionName
				WHERE
					MD.ModelName = @ModelName AND
					MD.DimensionName <> @ModelName + ''''_Value'''') <> @Counter
				
				SELECT @Error = @Error + CASE WHEN LEN(@Error) > 0 THEN CHAR(13) + CHAR(10) ELSE '''''''' END + ''''Dimension '''' + DimensionName + '''' is defined in MetaData for Model '''' + @ModelName + '''' but does not exists in the Fact table'''' FROM ModelDimension MD WHERE NOT EXISTS (SELECT 1 FROM #Verification V WHERE V.ModelName = MD.ModelName AND V.DimensionName = MD.DimensionName)
				

			IF (SELECT COUNT(1) FROM #Verification WHERE ModelName = @ModelName AND DimensionName = @ModelName + ''''_Value'''') <> 1
				SELECT @Error = @Error + CASE WHEN LEN(@Error) > 0 THEN CHAR(13) + CHAR(10) ELSE '''''''' END + ''''The value field '''' + @ModelName + ''''_Value is missing in the Fact table '''' + @SourceDatabase + ''''.dbo.FACT_'''' + @ModelName + ''''_default_partition''''

			FETCH NEXT FROM Verification_Cursor INTO @ModelName
		  END

	CLOSE Verification_Cursor
	DEALLOCATE Verification_Cursor	

DROP TABLE #Verification

IF LEN(@Error) = 0
	SET @Error = ''''Everything looks OK. The verification step does not find any errors.''''

PRINT @Error'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spGet_WorkbookLibrary'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spGet_WorkbookLibrary] 

@Debug bit = 0
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--spGet_WorkbookLibrary @Debug = 1

DECLARE
	@SourceDatabase nvarchar(100), 
	@SQLStatement nvarchar(max),
	@AuthorTypeYN bit

--Get Variables
	SELECT @SourceDatabase = SourceDatabase FROM SysParam WHERE SysParamID = 1

 	CREATE TABLE #Object
		(
		ObjectType nvarchar(100) COLLATE DATABASE_DEFAULT,
		ObjectName nvarchar(100) COLLATE DATABASE_DEFAULT
		)

	SET @SQLStatement = ''''SELECT ObjectType = ''''''''Column'''''''', ObjectName = c.name FROM '''' + @SourceDatabase + ''''.sys.tables T INNER JOIN '''' + @SourceDatabase + ''''.sys.columns C ON C.object_id = T.object_id AND C.name = ''''''''AuthorType'''''''' WHERE T.name = ''''''''WorkbookLibrary''''''''''''
	INSERT INTO #Object (ObjectType, ObjectName) EXEC (@SQLStatement)

	IF @Debug <> 0 SELECT TempTable = ''''#Object'''', * FROM #Object

	IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = ''''Column'''' AND ObjectName = ''''AuthorType'''') = 0 SET @AuthorTypeYN = 0 ELSE SET @AuthorTypeYN = 1

	TRUNCATE TABLE WorkbookLibrary

	IF @AuthorTypeYN = 0
		SET @SQLStatement = ''''
			INSERT INTO [dbo].[WorkbookLibrary]
				(
				[Label],
				[Contents],
				[ChangeDatetime],
				[Userid],
				[Sec],
				[AuthorType],
				[SelectYN]
				)
			SELECT
				[Label],
				[Contents],
				[ChangeDatetime],
				[Userid],
				[Sec],
				[AuthorType] = ''''''''C'''''''',
				[SelectYN] = 1
			FROM
				['''' + @SourceDatabase + ''''].[dbo].[WorkbookLibrary]''''
	ELSE
		SET @SQLStatement = ''''
			INSERT INTO [dbo].[WorkbookLibrary]
				(
				[Label],
				[Contents],
				[ChangeDatetime],
				[Userid],
				[Sec],
				[AuthorType],
				[SelectYN]
				)
			SELECT
				[Label],
				[Contents],
				[ChangeDatetime],
				[Userid],
				[Sec],
				[AuthorType],
				[SelectYN] = CASE WHEN [AuthorType] = ''''''''S'''''''' THEN 0 ELSE 1 END
			FROM
				['''' + @SourceDatabase + ''''].[dbo].[WorkbookLibrary]''''

	IF @Debug <> 0 PRINT @SQLStatement
	EXEC (@SQLStatement)
	
	DROP TABLE #Object'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spGet_Version'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spGet_Version] 
	(
	@GetVersion bit = 1,
	@Version nvarchar(50) = NULL OUTPUT,
	@Debug bit = 0
	)

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--EXEC [spGet_Version] @Debug = 1

DECLARE
	@Description nvarchar(255)

	SET @Version = ''''' + @Version + '''''
	SET @Description = ''''Created by pcINTEGRATOR, version ' +  @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @Debug <> 0 
	BEGIN
		SELECT [Version] = @Version
		PRINT ''''Version =  '''' + @Version
	END'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spGet_All'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spGet_All] 
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '		
AS

SET NOCOUNT ON

DECLARE
	@Version nvarchar(50)

EXEC spGet_Version @GetVersion = 0, @Version = @Version OUTPUT

EXEC spGet_Dimension
EXEC spGet_DimensionHierarchyLevel
EXEC spGet_Model
EXEC spGet_ModelDimension
EXEC spGet_DimensionData
EXEC spGet_FactData
EXEC spGet_WorkbookLibrary
EXEC spGet_Verification

PRINT ''''Version: '''' + @Version'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 PRINT @SQLStatement 
					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

			END --END of Procedures IN ('Demo', 'Upgrade')

		IF @pcExchangeType IN ('SIE4')
			BEGIN

				SET @Step = 'Create procedure spSIE4_File_EndJob'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_File_EndJob]
	(
	@UserName nvarchar(50),
	@ApplicationID int = ' + CONVERT(nvarchar(10), @ApplicationID) + '
	@JobID int = NULL OUT,
	@KSUMMA nvarchar(100) = NULL,
	@SentRows int = NULL,
	@Version nvarchar(50) = NULL,
	@RowCountYN bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

--EXEC [spSIE4_File_EndJob] @UserName = ''''jan@pc.com'''', @JobID = 55, @RowCountYN = 1, @Debug = 1

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''EXEC Procedure spSIE4_IU_Model''''
		EXEC [spSIE4_IU_Model] @UserName = @UserName, @JobID = @JobID, @Version = @Version, @Debug = @Debug

	SET @Step = ''''EXEC Procedure spSIE4_IU_Dimension''''
		EXEC [spSIE4_IU_Dimension] @UserName = @UserName, @JobID = @JobID, @Version = @Version, @Debug = @Debug

	SET @Step = ''''EXEC Procedure spSIE4_IU_ModelDimension''''
		EXEC [spSIE4_IU_ModelDimension] @UserName = @UserName, @JobID = @JobID, @Version = @Version, @Debug = @Debug

	SET @Step = ''''EXEC Procedure spSIE4_IU_DimensionData''''
		EXEC [spSIE4_IU_DimensionData] @UserName = @UserName, @JobID = @JobID, @Version = @Version, @Debug = @Debug

	SET @Step = ''''EXEC Procedure spSIE4_IU_FactData''''
		EXEC [spSIE4_IU_FactData] @UserName = @UserName, @JobID = @JobID, @Version = @Version, @Debug = @Debug

	SET @Step = ''''Load into pcDATA and Deploy''''
		EXEC pcINTEGRATOR..[spStart_Job] @ApplicationID = @ApplicationID, @AsynchronousYN = 1, @StepName = ''''Load''''

	SET @Step = ''''End #Job''''
		UPDATE J
		SET
			KSUMMA = ISNULL(@KSUMMA, J.KSUMMA),
			SentRows = ISNULL(@SentRows, J.SentRows),
			EndTime = GETDATE()
		FROM
			SIE4_Job J
		WHERE
			EndTime IS NULL AND
			JobID = @JobID

		SET @Updated = @Updated + @@ROWCOUNT

	SET @Step = ''''Return result''''
		SELECT 
--			[Error#] = COUNT(1),
			[ErrorInfo] = CASE WHEN COUNT(1) = 0 THEN ''''No errors occurred during the process.'''' ELSE CONVERT(nvarchar(10), COUNT(1)) + '''' error(s) occurred during the process. Look into the JobLog table for details.'''' END
		FROM
			JobLog 
		WHERE
			[JobID] = @JobID AND
			[ErrorNumber] <> 0

	SET @Step = ''''Return Statistics''''
		SELECT @Duration = CONVERT(time(7), EndTime - StartTime) FROM SIE4_Job WHERE [JobID] = @JobID
		
		IF @RowCountYN <> 0
			SELECT
				Duration = @Duration,
				Deleted = @Deleted,
				Inserted = @Inserted,
				Updated = @Updated

	SET @Step = ''''Return Debug''''
		IF @Debug <> 0
			BEGIN

				SELECT
					Duration = @Duration,
					*
				FROM
					SIE4_Job
				WHERE
					[JobID] = @JobID


				SELECT 
					[Table] = sub.[Table],
					[Param] = sub.[Param],
					[Counter] = sub.[Counter]
				FROM
					(
					SELECT 
						[Table] = ''''SIE4_Job'''',
						[Param] = ''''Multiple'''',
						[Counter] = COUNT(1)
					FROM
						SIE4_Job
					WHERE
						JobID = @JobID
					UNION SELECT 
						[Table] = ''''SIE4_Dim'''',
						[Param] = [Param],
						[Counter] = COUNT(1)
					FROM
						SIE4_Dim
					WHERE
						JobID = @JobID
					GROUP BY
						[Param]
					UNION SELECT 
						[Table] = ''''SIE4_Object'''',
						[Param] = [Param],
						[Counter] = COUNT(1)
					FROM
						SIE4_Object
					WHERE
						JobID = @JobID
					GROUP BY
						[Param]
					UNION SELECT 
						[Table] = ''''SIE4_Balance'''',
						[Param] = [Param],
						[Counter] = COUNT(1)
					FROM
						SIE4_Balance
					WHERE
						JobID = @JobID
					GROUP BY
						[Param]
					UNION SELECT 
						[Table] = ''''SIE4_Ver'''',
						[Param] = [Param],
						[Counter] = COUNT(1)
					FROM
						SIE4_Ver
					WHERE
						JobID = @JobID
					GROUP BY
						[Param]
					UNION SELECT 
						[Table] = ''''SIE4_Trans'''',
						[Param] = [Param],
						[Counter] = COUNT(1)
					FROM
						SIE4_Trans
					WHERE
						JobID = @JobID
					GROUP BY
						[Param]
					UNION SELECT 
						[Table] = ''''SIE4_Other'''',
						[Param] = [Param],
						[Counter] = COUNT(1)
					FROM
						SIE4_Trans
					WHERE
						JobID = @JobID
					GROUP BY
						[Param]
					) sub
				ORDER BY
					sub.[Table],
					sub.[Param]
			END

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_File_EndJob] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spSIE4_File_InsertBalance'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_File_InsertBalance]
	(
	@UserName nvarchar(50),
	@JobID int,
	@Param nvarchar(50),
	@RAR int,
	@Account nvarchar(50),
	@Amount decimal(18,2),
	@Version nvarchar(50) = NULL,
	@RowCountYN bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

--EXEC [spSIE4_File_InsertBalance] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#IB'''', @RAR = 0, @Account = ''''1080'''', @Amount = 1141707.94, @Debug = 1
--EXEC [spSIE4_File_InsertBalance] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#IB'''', @RAR = -1, @Account = ''''1080'''', @Amount = 1531707.82, @Debug = 1
--EXEC [spSIE4_File_InsertBalance] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#UB'''', @RAR = 0, @Account = ''''1080'''', @Amount = 2141707.94, @Debug = 1
--EXEC [spSIE4_File_InsertBalance] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#UB'''', @RAR = -1, @Account = ''''1080'''', @Amount = 2531707.82, @Debug = 1
--EXEC [spSIE4_File_InsertBalance] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#RES'''', @RAR = 0, @Account = ''''3001'''', @Amount = 345678.75, @Debug = 1
--EXEC [spSIE4_File_InsertBalance] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#RES'''', @RAR = -1, @Account = ''''3001'''', @Amount = 245678.25, @Debug = 1
--EXEC [spSIE4_File_InsertBalance] @UserName = ''''jan@pc.com'''', @JobID = 2, @Param = ''''#RES'''', @RAR = -1, @Account = ''''3001'''', @Amount = 245678.25, @Debug = 1
--EXEC [spSIE4_File_InsertBalance] @UserName = ''''jan@pc.com'''', @JobID = 3, @Param = ''''#RES'''', @RAR = -1, @Account = ''''3001'''', @Amount = 245678.25, @RowCountYN = 1, @Debug = 1

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Insert #Balance JobID = '''' + CONVERT(nvarchar(10), @JobID) + '''', Param = '''' + @Param + '''', RAR = '''' + CONVERT(nvarchar(10), @RAR) + '''', Account = '''' + @Account
		INSERT INTO SIE4_Balance
			(
			[JobID],
			[Param],
			[RAR],
			[Account],
			[Amount],
			[InsertedBy]
			)
		SELECT
			[JobID] = @JobID,
			[Param] = @Param,
			[RAR] = @RAR,
			[Account] = @Account,
			[Amount] = @Amount,
			[InsertedBy] = @UserName

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Return Statistics''''
		SELECT @Duration = CONVERT(time(7), GetDate() - @StartTime)
		
		IF @RowCountYN <> 0
			SELECT
				Duration = @Duration,
				Deleted = @Deleted,
				Inserted = @Inserted,
				Updated = @Updated

	SET @Step = ''''Return Debug''''
		IF @Debug <> 0
			SELECT
				*
			FROM
				SIE4_Balance
			WHERE
				[JobID] = @JobID AND
				[Param] = @Param AND
				[RAR] = @RAR AND
				[Account] = @Account

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_File_InsertBalance] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spSIE4_File_InsertDim'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_File_InsertDim]
	(
	@UserName nvarchar(50),
	@JobID int,
	@Param nvarchar(50),
	@DimCode nvarchar(50),
	@DimName nvarchar(100),
	@DimParent nvarchar(50) = NULL,
	@Version nvarchar(50) = NULL,
	@RowCountYN bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

--EXEC [spSIE4_File_InsertDim] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#DIM'''', @DimCode = ''''1'''', @DimName = ''''Kostnadsställe'''', @Debug = 1
--EXEC [spSIE4_File_InsertDim] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#UNDERDIM'''', @DimCode = ''''2'''', @DimName = ''''Kostnadsbärare'''', @DimParent = ''''1'''',  @RowCountYN = 1, @Debug = 1
--EXEC [spSIE4_File_InsertDim] @UserName = ''''jan@pc.com'''', @JobID = 2, @Param = ''''#DIM'''', @DimCode = ''''1'''', @DimName = ''''Kostnadsställe'''', @Debug = 1
--EXEC [spSIE4_File_InsertDim] @UserName = ''''jan@pc.com'''', @JobID = 3, @Param = ''''#DIM'''', @DimCode = ''''1'''', @DimName = ''''Kostnadsställe'''', @RowCountYN = 1, @Debug = 1
--EXEC [spSIE4_File_InsertDim] @UserName = ''''jan@pc.com'''', @JobID = 3, @Param = ''''#UNDERDIM'''', @DimCode = ''''2'''', @DimName = ''''Kostnadsbärare'''', @DimParent = ''''1'''',  @RowCountYN = 1, @Debug = 1

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Insert #Dim JobID = '''' + CONVERT(nvarchar(10), @JobID) + '''', Param = '''' + @Param + '''', DimCode = '''' + @DimCode
		INSERT INTO SIE4_Dim
			(
			[JobID],
			[Param],
			[DimCode],
			[DimName],
			[DimParent],
			[InsertedBy]
			)
		SELECT
			[JobID] = @JobID,
			[Param] = @Param,
			[DimCode] = @DimCode,
			[DimName] = @DimName,
			[DimParent] = @DimParent,
			[InsertedBy] = @UserName

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Return Statistics''''
		SELECT @Duration = CONVERT(time(7), GetDate() - @StartTime)
		
		IF @RowCountYN <> 0
			SELECT
				Duration = @Duration,
				Deleted = @Deleted,
				Inserted = @Inserted,
				Updated = @Updated

	SET @Step = ''''Return Debug''''
		IF @Debug <> 0
			SELECT
				*
			FROM
				SIE4_Dim
			WHERE
				[JobID] = @JobID AND
				[Param] = @Param AND
				[DimCode] = @DimCode

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_File_InsertDim] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spSIE4_File_InsertObject'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_File_InsertObject]
	(
	@UserName nvarchar(50),
	@JobID int,
	@Param nvarchar(50),
	@DimCode nvarchar(50),
	@ObjectCode nvarchar(50),
	@ObjectName nvarchar(100),
	@Version nvarchar(50) = NULL,
	@RowCountYN bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

--EXEC [spSIE4_File_InsertObject] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#OBJECT'''', @DimCode = ''''1'''', @ObjectCode = ''''01'''', @ObjectName = ''''Development'''', @Debug = 1
--EXEC [spSIE4_File_InsertObject] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#OBJECT'''', @DimCode = ''''2'''', @ObjectCode = ''''0102'''', @ObjectName = ''''Jan Wogel'''', @Debug = 1
--EXEC [spSIE4_File_InsertObject] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#KSUMMA'''', @DimCode = ''''Account'''', @ObjectCode = ''''30'''', @ObjectName = ''''Intäkter'''', @Debug = 1
--EXEC [spSIE4_File_InsertObject] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#KONTO'''', @DimCode = ''''Account'''', @ObjectCode = ''''3001'''', @ObjectName = ''''Försäljning varor, 25% moms'''', @Debug = 1
--EXEC [spSIE4_File_InsertObject] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#SRU'''', @DimCode = ''''Account'''', @ObjectCode = ''''3001'''', @ObjectName = ''''400'''', @Debug = 1
--EXEC [spSIE4_File_InsertObject] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#KTYP'''', @DimCode = ''''Account'''', @ObjectCode = ''''Income'''', @ObjectName = ''''Intäkter'''', @Debug = 1
--EXEC [spSIE4_File_InsertObject] @UserName = ''''jan@pc.com'''', @JobID = 2, @Param = ''''#OBJECT'''', @DimCode = ''''1'''', @ObjectCode = ''''01'''', @ObjectName = ''''Development'''', @Debug = 1
--EXEC [spSIE4_File_InsertObject] @UserName = ''''jan@pc.com'''', @JobID = 3, @Param = ''''#OBJECT'''', @DimCode = ''''1'''', @ObjectCode = ''''01'''', @ObjectName = ''''Development'''', @RowCountYN = 1, @Debug = 1
--EXEC [spSIE4_File_InsertObject] @UserName = ''''jan@pc.com'''', @JobID = 2, @Param = ''''#KONTO'''', @DimCode = ''''Account'''', @ObjectCode = ''''3001'''', @ObjectName = ''''Förs varor, 25% moms'''', @RowCountYN = 1, @Debug = 1
--EXEC [spSIE4_File_InsertObject] @UserName = ''''jan@pc.com'''', @JobID = 3, @Param = ''''#KONTO'''', @DimCode = ''''Account'''', @ObjectCode = ''''3001'''', @ObjectName = ''''Försäljning varor, 25% moms'''', @RowCountYN = 1, @Debug = 1

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Insert #Object JobID = '''' + CONVERT(nvarchar(10), @JobID) + '''', Param = '''' + @Param + '''', DimCode = '''' + @DimCode + '''', ObjectCode = '''' + @ObjectCode
		INSERT INTO SIE4_Object
			(
			[JobID],
			[Param],
			[DimCode],
			[ObjectCode],
			[ObjectName],
			[InsertedBy]
			)
		SELECT
			[JobID] = @JobID,
			[Param] = @Param,
			[DimCode] = @DimCode,
			[ObjectCode] = @ObjectCode,
			[ObjectName] = @ObjectName,
			[InsertedBy] = @UserName

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Return Statistics''''
		SELECT @Duration = CONVERT(time(7), GetDate() - @StartTime)
		
		IF @RowCountYN <> 0
			SELECT
				Duration = @Duration,
				Deleted = @Deleted,
				Inserted = @Inserted,
				Updated = @Updated

	SET @Step = ''''Return Debug''''
		IF @Debug <> 0
			SELECT
				*
			FROM
				SIE4_Object
			WHERE
				[JobID] = @JobID AND
				[Param] = @Param AND
				[DimCode] = @DimCode AND
				[ObjectCode] = @ObjectCode

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_File_InsertObject] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spSIE4_File_InsertOther'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_File_InsertOther]
	(
	@UserName nvarchar(50),
	@JobID int,
	@Param nvarchar(50),
	@String nvarchar(255),
	@Version nvarchar(50) = NULL,
	@RowCountYN bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

--EXEC [spSIE4_File_InsertOther] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#TEST'''', @String = ''''1'''', @Debug = 1

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Insert #Other JobID = '''' + CONVERT(nvarchar(10), @JobID) + '''', Param = '''' + @Param + '''', String = '''' + @String
		INSERT INTO SIE4_Other
			(
			[JobID],
			[Param],
			[String],
			[InsertedBy]
			)
		SELECT
			[JobID] = @JobID,
			[Param] = @Param,
			[String] = @String,
			[InsertedBy] = @UserName

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Return Statistics''''
		SELECT @Duration = CONVERT(time(7), GetDate() - @StartTime)
		
		IF @RowCountYN <> 0
			SELECT
				Duration = @Duration,
				Deleted = @Deleted,
				Inserted = @Inserted,
				Updated = @Updated

	SET @Step = ''''Return Debug''''
		IF @Debug <> 0
			SELECT
				*
			FROM
				SIE4_Other
			WHERE
				[JobID] = @JobID AND
				[Param] = @Param AND
				[String] = @String

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_File_InsertOther] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spSIE4_File_InsertTrans'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_File_InsertTrans]
	(
	@UserName nvarchar(50),
	@JobID int,
	@Param nvarchar(50),
	@Seq nvarchar(50),
	@Ver nvarchar(50),
	@Trans int, --Not from file, calculated counter per @Ver
	@Account nvarchar(50),
	@DimCode_01 nvarchar(50) = NULL,
	@ObjectCode_01 nvarchar(50) = NULL,
	@DimCode_02 nvarchar(50) = NULL,
	@ObjectCode_02 nvarchar(50) = NULL,
	@DimCode_03 nvarchar(50) = NULL,
	@ObjectCode_03 nvarchar(50) = NULL,
	@DimCode_04 nvarchar(50) = NULL,
	@ObjectCode_04 nvarchar(50) = NULL,
	@DimCode_05 nvarchar(50) = NULL,
	@ObjectCode_05 nvarchar(50) = NULL,
	@DimCode_06 nvarchar(50) = NULL,
	@ObjectCode_06 nvarchar(50) = NULL,
	@DimCode_07 nvarchar(50) = NULL,
	@ObjectCode_07 nvarchar(50) = NULL,
	@DimCode_08 nvarchar(50) = NULL,
	@ObjectCode_08 nvarchar(50) = NULL,
	@DimCode_09 nvarchar(50) = NULL,
	@ObjectCode_09 nvarchar(50) = NULL,
	@DimCode_10 nvarchar(50) = NULL,
	@ObjectCode_10 nvarchar(50) = NULL,
	@DimCode_11 nvarchar(50) = NULL,
	@ObjectCode_11 nvarchar(50) = NULL,
	@DimCode_12 nvarchar(50) = NULL,
	@ObjectCode_12 nvarchar(50) = NULL,
	@DimCode_13 nvarchar(50) = NULL,
	@ObjectCode_13 nvarchar(50) = NULL,
	@DimCode_14 nvarchar(50) = NULL,
	@ObjectCode_14 nvarchar(50) = NULL,
	@DimCode_15 nvarchar(50) = NULL,
	@ObjectCode_15 nvarchar(50) = NULL,
	@DimCode_16 nvarchar(50) = NULL,
	@ObjectCode_16 nvarchar(50) = NULL,
	@DimCode_17 nvarchar(50) = NULL,
	@ObjectCode_17 nvarchar(50) = NULL,
	@DimCode_18 nvarchar(50) = NULL,
	@ObjectCode_18 nvarchar(50) = NULL,
	@DimCode_19 nvarchar(50) = NULL,
	@ObjectCode_19 nvarchar(50) = NULL,
	@DimCode_20 nvarchar(50) = NULL,
	@ObjectCode_20 nvarchar(50) = NULL,
	@Amount decimal(18,2),
	@Date int, --If NULL in file, copy from #Ver
	@Description nvarchar(255) = NULL,
	@Version nvarchar(50) = NULL,
	@RowCountYN bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

--EXEC [spSIE4_File_InsertTrans] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#TRANS'''', @Seq = ''''A'''', @Ver = ''''1'''', @Trans = 1, @Account = ''''2016'''', @DimCode_01 = ''''1'''', @ObjectCode_01 = ''''01'''', @Amount = -202300.00, @Date = 20160124, @Debug = 1
--EXEC [spSIE4_File_InsertTrans] @UserName = ''''jan@pc.com'''', @JobID = 2, @Param = ''''#TRANS'''', @Seq = ''''A'''', @Ver = ''''1'''', @Trans = 1, @Account = ''''2016'''', @DimCode_01 = ''''1'''', @ObjectCode_01 = ''''01'''', @Amount = -202300.00, @Date = 20160124, @Debug = 1
--EXEC [spSIE4_File_InsertTrans] @UserName = ''''jan@pc.com'''', @JobID = 3, @Param = ''''#TRANS'''', @Seq = ''''A'''', @Ver = ''''1'''', @Trans = 1, @Account = ''''2016'''', @DimCode_01 = ''''1'''', @ObjectCode_01 = ''''01'''', @Amount = -202300.00, @Date = 20160124, @RowCountYN = 1, @Debug = 1

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Insert #Trans JobID = '''' + CONVERT(nvarchar(10), @JobID) + '''', Param = '''' + @Param + '''', Seq = '''' + @Seq + '''', Ver = '''' + @Ver + '''', Trans = '''' + CONVERT(nvarchar(10), @Trans)
		INSERT INTO SIE4_Trans
			(
			[JobID],
			[Param],
			[Seq],
			[Ver],
			[Trans],
			[Account],
			[DimCode_01],
			[ObjectCode_01],
			[DimCode_02],
			[ObjectCode_02],
			[DimCode_03],
			[ObjectCode_03],
			[DimCode_04],
			[ObjectCode_04],
			[DimCode_05],
			[ObjectCode_05],
			[DimCode_06],
			[ObjectCode_06],
			[DimCode_07],
			[ObjectCode_07],
			[DimCode_08],
			[ObjectCode_08],
			[DimCode_09],
			[ObjectCode_09],
			[DimCode_10],
			[ObjectCode_10],
			[DimCode_11],
			[ObjectCode_11],
			[DimCode_12],
			[ObjectCode_12],
			[DimCode_13],
			[ObjectCode_13],
			[DimCode_14],
			[ObjectCode_14],
			[DimCode_15],
			[ObjectCode_15],
			[DimCode_16],
			[ObjectCode_16],
			[DimCode_17],
			[ObjectCode_17],
			[DimCode_18],
			[ObjectCode_18],
			[DimCode_19],
			[ObjectCode_19],
			[DimCode_20],
			[ObjectCode_20],
			[Amount],
			[Date],
			[Description],
			[InsertedBy]
			)
		SELECT
			[JobID] = @JobID,
			[Param] = @Param,
			[Seq] = @Seq,
			[Ver] = @Ver,
			[Trans] = @Trans,
			[Account] = @Account,
			[DimCode_01] = @DimCode_01,
			[ObjectCode_01] = @ObjectCode_01,
			[DimCode_02] = @DimCode_02,
			[ObjectCode_02] = @ObjectCode_02,
			[DimCode_03] = @DimCode_03,
			[ObjectCode_03] = @ObjectCode_03,
			[DimCode_04] = @DimCode_04,
			[ObjectCode_04] = @ObjectCode_04,
			[DimCode_05] = @DimCode_05,
			[ObjectCode_05] = @ObjectCode_05,
			[DimCode_06] = @DimCode_06,
			[ObjectCode_06] = @ObjectCode_06,
			[DimCode_07] = @DimCode_07,
			[ObjectCode_07] = @ObjectCode_07,
			[DimCode_08] = @DimCode_08,
			[ObjectCode_08] = @ObjectCode_08,
			[DimCode_09] = @DimCode_09,
			[ObjectCode_09] = @ObjectCode_09,
			[DimCode_10] = @DimCode_10,
			[ObjectCode_10] = @ObjectCode_10,
			[DimCode_11] = @DimCode_11,
			[ObjectCode_11] = @ObjectCode_11,
			[DimCode_12] = @DimCode_12,
			[ObjectCode_12] = @ObjectCode_12,
			[DimCode_13] = @DimCode_13,
			[ObjectCode_13] = @ObjectCode_13,
			[DimCode_14] = @DimCode_14,
			[ObjectCode_14] = @ObjectCode_14,
			[DimCode_15] = @DimCode_15,
			[ObjectCode_15] = @ObjectCode_15,
			[DimCode_16] = @DimCode_16,
			[ObjectCode_16] = @ObjectCode_16,
			[DimCode_17] = @DimCode_17,
			[ObjectCode_17] = @ObjectCode_17,
			[DimCode_18] = @DimCode_18,
			[ObjectCode_18] = @ObjectCode_18,
			[DimCode_19] = @DimCode_19,
			[ObjectCode_19] = @ObjectCode_19,
			[DimCode_20] = @DimCode_20,
			[ObjectCode_20] = @ObjectCode_20,
			[Amount] = @Amount,
			[Date] = @Date,
			[Description] = @Description,
			[InsertedBy] = @UserName

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Return Statistics''''
		SELECT @Duration = CONVERT(time(7), GetDate() - @StartTime)
		
		IF @RowCountYN <> 0
			SELECT
				Duration = @Duration,
				Deleted = @Deleted,
				Inserted = @Inserted,
				Updated = @Updated

	SET @Step = ''''Return Debug''''
		IF @Debug <> 0
			SELECT
				*
			FROM
				SIE4_Trans
			WHERE
				[JobID] = @JobID AND
				[Param] = @Param AND
				[Seq] = @Seq AND
				[Ver] = @Ver AND
				[Trans] = @Trans

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_File_InsertTrans] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spSIE4_File_InsertVer'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_File_InsertVer]
	(
	@UserName nvarchar(50),
	@JobID int,
	@Param nvarchar(50),
	@Seq nvarchar(50),
	@Ver nvarchar(50),
	@Date int,
	@Description nvarchar(255) = NULL,
	@Version nvarchar(50) = NULL,
	@RowCountYN bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

--EXEC [spSIE4_File_InsertVer] @UserName = ''''jan@pc.com'''', @JobID = 1, @Param = ''''#VER'''', @Seq = ''''A'''', @Ver = ''''1'''', @Date = 20160124, @Description = ''''Epicor royalty report January 2016'''', @Debug = 1
--EXEC [spSIE4_File_InsertVer] @UserName = ''''jan@pc.com'''', @JobID = 2, @Param = ''''#VER'''', @Seq = ''''A'''', @Ver = ''''1'''', @Date = 20160124, @Description = ''''Epicor royalty report January 2016'''', @Debug = 1
--EXEC [spSIE4_File_InsertVer] @UserName = ''''jan@pc.com'''', @JobID = 3, @Param = ''''#VER'''', @Seq = ''''A'''', @Ver = ''''1'''', @Date = 20160124, @Description = ''''Epicor royalty report January 2016'''', @Debug = 1
--EXEC [spSIE4_File_InsertVer] @UserName = ''''jan@pc.com'''', @JobID = 4, @Param = ''''#VER'''', @Seq = ''''A'''', @Ver = ''''1'''', @Date = 20160124, @Description = ''''Epicor royalty report January 2016'''', @RowCountYN = 1, @Debug = 1

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Insert #Ver JobID = '''' + CONVERT(nvarchar(10), @JobID) + '''', Param = '''' + @Param + '''', Seq = '''' + @Seq + '''', Ver = '''' + @Ver
		INSERT INTO SIE4_Ver
			(
			[JobID],
			[Param],
			[Seq],
			[Ver],
			[Date],
			[Description],
			[InsertedBy]
			)
		SELECT
			[JobID] = @JobID,
			[Param] = @Param,
			[Seq] = @Seq,
			[Ver] = @Ver,
			[Date] = @Date,
			[Description] = @Description,
			[InsertedBy] = @UserName

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Return Statistics''''
		SELECT @Duration = CONVERT(time(7), GetDate() - @StartTime)
		
		IF @RowCountYN <> 0
			SELECT
				Duration = @Duration,
				Deleted = @Deleted,
				Inserted = @Inserted,
				Updated = @Updated

	SET @Step = ''''Return Debug''''
		IF @Debug <> 0
			SELECT
				*
			FROM
				SIE4_Ver
			WHERE
				[JobID] = @JobID AND
				[Param] = @Param AND
				[Seq] = @Seq AND
				[Ver] = @Ver

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_File_InsertVer] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spSIE4_File_StartJob'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_File_StartJob]
	(
	@UserName nvarchar(50),
	@JobID int = NULL OUT,
	@FLAGGA nvarchar(100) = NULL,
	@PROGRAM nvarchar(100) = NULL,
	@FORMAT nvarchar(100) = NULL,
	@GEN nvarchar(100) = NULL,
	@SIETYP nvarchar(100) = NULL,
	@PROSA nvarchar(100) = NULL,
	@FNR nvarchar(100) = NULL,
	@ORGNR nvarchar(100) = NULL,
	@BKOD nvarchar(100) = NULL,
	@ADRESS nvarchar(100) = NULL,
	@FNAMN nvarchar(100) = NULL,
	@RAR_0_FROM int,
	@RAR_0_TO int,
	@RAR_1_FROM int = NULL,
	@RAR_1_TO int = NULL,
	@TAXAR nvarchar(50) = NULL,
	@OMFATTN nvarchar(100) = NULL,
	@KPTYP nvarchar(50) = NULL,
	@VALUTA nchar(3) = NULL,
	@Version nvarchar(50) = NULL,
	@RowCountYN bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

--EXEC [spSIE4_File_StartJob] @UserName = ''''jan@pc.com'''', @FNR = ''''SE5566987300'''', @ORGNR = ''''556698-7300'''', @FNAMN = ''''DSPanel AB'''', @RAR_0_FROM = 20160101, @RAR_0_TO = 20161231, @RowCountYN = 1, @Debug = 1

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Insert #Job''''
		INSERT INTO SIE4_Job
			(
			[FLAGGA],
			[PROGRAM],
			[FORMAT],
			[GEN],
			[SIETYP],
			[PROSA],
			[FNR],
			[ORGNR],
			[BKOD],
			[ADRESS],
			[FNAMN],
			[RAR_0_FROM],
			[RAR_0_TO],
			[RAR_1_FROM],
			[RAR_1_TO],
			[TAXAR],
			[OMFATTN],
			[KPTYP],
			[VALUTA],
			[InsertedBy]
			)
		SELECT
			[FLAGGA] = @FLAGGA,
			[PROGRAM] = @PROGRAM,
			[FORMAT] = @FORMAT,
			[GEN] = @GEN,
			[SIETYP] = @SIETYP,
			[PROSA] = @PROSA,
			[FNR] = @FNR,
			[ORGNR] = @ORGNR,
			[BKOD] = @BKOD,
			[ADRESS] = @ADRESS,
			[FNAMN] = @FNAMN,
			[RAR_0_FROM] = @RAR_0_FROM,
			[RAR_0_TO] = @RAR_0_TO,
			[RAR_1_FROM] = @RAR_1_FROM,
			[RAR_1_TO] = @RAR_1_TO,
			[TAXAR] = @TAXAR,
			[OMFATTN] = @OMFATTN,
			[KPTYP] = @KPTYP,
			[VALUTA] = @VALUTA,
			[InsertedBy] = @UserName

		SELECT
			@JobID = @@IDENTITY,
			@Inserted = @Inserted + @@ROWCOUNT

		SELECT JobID = @JobID

	SET @Step = ''''Return Statistics''''
		SELECT @Duration = CONVERT(time(7), GetDate() - @StartTime)
		
		IF @RowCountYN <> 0
			SELECT
				Duration = @Duration,
				Deleted = @Deleted,
				Inserted = @Inserted,
				Updated = @Updated

	SET @Step = ''''Return Debug''''
		IF @Debug <> 0
			SELECT
				*
			FROM
				SIE4_Job
			WHERE
				[JobID] = @JobID

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_File_StartJob] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spSIE4_IU_Dimension'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_IU_Dimension] 
	(
	@UserName nvarchar(50),
	@JobID int,
	@Version nvarchar(50) = NULL,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC [spSIE4_IU_Dimension] @UserName = ''''jan@pc.com'''', @JobID = 41, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''TRUNCATE TABLE Dimension''''
		SELECT @Deleted = COUNT(1) FROM Dimension
		--TRUNCATE TABLE Dimension
		DELETE Dimension

	SET @Step = ''''Insert Hierachy Segments''''
		INSERT INTO Dimension
			(
			DimensionName,
			DimensionDescription,
			DimensionID,
			DimensionTypeID,
			[Type],
			[DefaultHierarchy],
			[HierarchyName1],
			[PropertyName01],
			[PropertyDataTypeID01],
			[PropertySize01],
			[PropertyDefaultValue01],
			[PropertyMemberDimension01],
			[PropertyMemberHierarchy01]
			)
		SELECT
			DimensionName = ''''GL_'''' + D.DimName,
			DimensionDescription = D.DimName,
			DimensionID = 0,
			DimensionTypeID = -1,
			[Type] = ''''GLSegment'''',
			[DefaultHierarchy] = ''''GL_'''' + D.DimName + ''''_'''' + ''''GL_'''' + D.DimName,
			[HierarchyName1] = ''''GL_'''' + D.DimName,
			[PropertyName01] = ''''RNodeType'''',
			[PropertyDataTypeID01] = 2,
			[PropertySize01] = 2,
			[PropertyDefaultValue01] = ''''P'''',
			[PropertyMemberDimension01] = NULL,
			[PropertyMemberHierarchy01] = NULL
		FROM
			SIE4_Dim D
		WHERE
			D.JobID = @JobID AND
			D.[Param] IN (''''#DIM'''', ''''#UNDERDIM'''') AND
			NOT EXISTS (SELECT 1 FROM SIE4_Dim SD WHERE SD.JobID = @JobID AND SD.DimParent = D.DimCode) 

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Insert not Hierachy Segments''''
		INSERT INTO Dimension
			(
			DimensionName,
			DimensionDescription,
			DimensionID,
			DimensionTypeID,
			[Type],
			[DefaultHierarchy],
			[HierarchyName1],
			[PropertyName01],
			[PropertyDataTypeID01],
			[PropertySize01],
			[PropertyDefaultValue01],
			[PropertyMemberDimension01],
			[PropertyMemberHierarchy01]
			)
		SELECT
			DimensionName = ''''GL_'''' + D.DimName,
			DimensionDescription = D.DimName,
			DimensionID = 0,
			DimensionTypeID = -1,
			[Type] = ''''GLSegment'''',
			[DefaultHierarchy] = ''''GL_'''' + D.DimName + ''''_'''' + ''''GL_'''' + D.DimName,
			[HierarchyName1] = ''''GL_'''' + D.DimName,
			[PropertyName01] = ''''RNodeType'''',
			[PropertyDataTypeID01] = 2,
			[PropertySize01] = 2,
			[PropertyDefaultValue01] = ''''P'''',
			[PropertyMemberDimension01] = NULL,
			[PropertyMemberHierarchy01] = NULL
		FROM
			SIE4_Dim D
		WHERE
			D.JobID = @JobID AND
			D.[Param] IN (''''#DIM'''', ''''#UNDERDIM'''') AND
			EXISTS (SELECT 1 FROM SIE4_Dim SD WHERE SD.JobID = @JobID AND SD.DimParent = D.DimCode) 

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Insert Account''''
		INSERT INTO Dimension
			(
			DimensionName,
			DimensionDescription,
			DimensionID,
			DimensionTypeID,
			[Type],
			[DefaultHierarchy],
			[HierarchyName1],
			[PropertyName01],
			[PropertyDataTypeID01],
			[PropertySize01],
			[PropertyDefaultValue01],
			[PropertyMemberDimension01],
			[PropertyMemberHierarchy01],
			[PropertyName02],
			[PropertyDataTypeID02],
			[PropertySize02],
			[PropertyDefaultValue02],
			[PropertyMemberDimension02],
			[PropertyMemberHierarchy02],
			[PropertyName03],
			[PropertyDataTypeID03],
			[PropertySize03],
			[PropertyDefaultValue03],
			[PropertyMemberDimension03],
			[PropertyMemberHierarchy03],
			[PropertyName04],
			[PropertyDataTypeID04],
			[PropertySize04],
			[PropertyDefaultValue04],
			[PropertyMemberDimension04],
			[PropertyMemberHierarchy04],
			[PropertyName05],
			[PropertyDataTypeID05],
			[PropertySize05],
			[PropertyDefaultValue05],
			[PropertyMemberDimension05],
			[PropertyMemberHierarchy05]
			)
		SELECT
			DimensionName = ''''Account'''',
			DimensionDescription = ''''Natural Account'''',
			DimensionID = -1,
			DimensionTypeID = 1,
			[Type] = ''''Account'''',
			[DefaultHierarchy] = ''''Account_Account'''',
			[HierarchyName1] = ''''Account'''',
			[PropertyName01] = ''''RNodeType'''',
			[PropertyDataTypeID01] = 2,
			[PropertySize01] = 2,
			[PropertyDefaultValue01] = ''''P'''',
			[PropertyMemberDimension01] = NULL,
			[PropertyMemberHierarchy01] = NULL,
			[PropertyName02] = ''''Account Type'''',
			[PropertyDataTypeID02] = 2,
			[PropertySize02] = 50,
			[PropertyDefaultValue02] = ''''Expense'''',
			[PropertyMemberDimension02] = NULL,
			[PropertyMemberHierarchy02] = NULL,
			[PropertyName03] = ''''Rate'''',
			[PropertyDataTypeID03] = 3,
			[PropertySize03] = NULL,
			[PropertyDefaultValue03] = ''''Average'''',
			[PropertyMemberDimension03] = ''''Rate'''',
			[PropertyMemberHierarchy03] = ''''Rate'''',
			[PropertyName04] = ''''Sign'''',
			[PropertyDataTypeID04] = 1,
			[PropertySize04] = NULL,
			[PropertyDefaultValue04] = 1,
			[PropertyMemberDimension04] = NULL,
			[PropertyMemberHierarchy04] = NULL,
			[PropertyName05] = ''''TimeBalance'''',
			[PropertyDataTypeID05] = 4,
			[PropertySize05] = NULL,
			[PropertyDefaultValue05] = 0,
			[PropertyMemberDimension05] = NULL,
			[PropertyMemberHierarchy05] = NULL

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Insert Entity''''
		INSERT INTO Dimension
			(
			DimensionName,
			DimensionDescription,
			DimensionID,
			DimensionTypeID,
			[Type],
			[DefaultHierarchy],
			[HierarchyName1],
			[PropertyName01],
			[PropertyDataTypeID01],
			[PropertySize01],
			[PropertyDefaultValue01],
			[PropertyMemberDimension01],
			[PropertyMemberHierarchy01],
			[PropertyName02],
			[PropertyDataTypeID02],
			[PropertySize02],
			[PropertyDefaultValue02],
			[PropertyMemberDimension02],
			[PropertyMemberHierarchy02]
			)
		SELECT
			DimensionName = ''''Entity'''',
			DimensionDescription = ''''Entity'''',
			DimensionID = -4,
			DimensionTypeID = 4,
			[Type] = ''''Entity'''',
			[DefaultHierarchy] = ''''Entity_Entity'''',
			[HierarchyName1] = ''''Entity'''',
			[PropertyName01] = ''''RNodeType'''',
			[PropertyDataTypeID01] = 2,
			[PropertySize01] = 2,
			[PropertyDefaultValue01] = ''''P'''',
			[PropertyMemberDimension01] = NULL,
			[PropertyMemberHierarchy01] = NULL,
			[PropertyName02] = ''''Currency'''',
			[PropertyDataTypeID02] = 3,
			[PropertySize02] = NULL,
			[PropertyDefaultValue02] = ''''NONE'''',
			[PropertyMemberDimension02] = ''''Currency'''',
			[PropertyMemberHierarchy02] = ''''Currency''''

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Insert BusinessProcess, Currency & Time''''
		INSERT INTO Dimension
			(
			DimensionName,
			DimensionDescription,
			DimensionID,
			DimensionTypeID,
			[Type],
			[DefaultHierarchy],
			[HierarchyName1],
			[PropertyName01],
			[PropertyDataTypeID01],
			[PropertySize01],
			[PropertyDefaultValue01],
			[PropertyMemberDimension01],
			[PropertyMemberHierarchy01]
			)
		SELECT
			DimensionName,
			DimensionDescription,
			DimensionID,
			DimensionTypeID,
			[Type],
			[DefaultHierarchy],
			[HierarchyName1],
			[PropertyName01] = ''''RNodeType'''',
			[PropertyDataTypeID01] = 2,
			[PropertySize01] = 2,
			[PropertyDefaultValue01] = ''''P'''',
			[PropertyMemberDimension01] = NULL,
			[PropertyMemberHierarchy01] = NULL
		FROM
			(
			SELECT
				DimensionName = ''''BusinessProcess'''',
				DimensionDescription = ''''Business Process'''',
				DimensionID = -2,
				DimensionTypeID = 2,
				[Type] = ''''BusinessProcess'''',
				[DefaultHierarchy] = ''''BusinessProcess_BusinessProcess'''',
				[HierarchyName1] = ''''BusinessProcess''''
			UNION SELECT
				DimensionName = ''''Currency'''',
				DimensionDescription = ''''Currency'''',
				DimensionID = -3,
				DimensionTypeID = 3,
				[Type] = ''''Currency'''',
				[DefaultHierarchy] = ''''Currency_Currency'''',
				[HierarchyName1] = ''''Currency''''
			UNION SELECT
				DimensionName = ''''Time'''',
				DimensionDescription = ''''Time'''',
				DimensionID = -7,
				DimensionTypeID = 7,
				[Type] = ''''Time'''',
				[DefaultHierarchy] = ''''Time_Time'''',
				[HierarchyName1] = ''''Time''''
			) sub

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_IU_Dimension] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spSIE4_IU_DimensionData'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_IU_DimensionData] 
	(
	@UserName nvarchar(50),
	@JobID int,
	@Version nvarchar(50) = NULL,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC [spSIE4_IU_DimensionData] @UserName = ''''jan@pc.com'''', @JobID = 41, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@KPTYP nvarchar(50)

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Get base parameters''''
		SELECT
			@KPTYP = KPTYP
		FROM
			SIE4_Job
		WHERE
			JobID = @JobID

	SET @Step = ''''TRUNCATE TABLE DimensionData''''
		SELECT @Deleted = COUNT(1) FROM DimensionData
		TRUNCATE TABLE DimensionData

	SET @Step = ''''Insert Account & Segment''''
		INSERT INTO DimensionData
			(
			[DimensionName],
			[Label],
			[Description],
			[Parent1],
			[Property01]
			)				
		SELECT DISTINCT
			[DimensionName] = CASE WHEN O.[Param] = ''''#KONTO'''' THEN O.DimCode ELSE ''''GL_'''' + ISNULL(SD.DimName, D.DimName) END,
			[Label] = O.ObjectCode,
			[Description] = O.ObjectName,
			[Parent1] = CASE WHEN O.[Param] = ''''#KONTO'''' THEN ''''All_'''' ELSE COALESCE(CASE WHEN D.DimParent IS NULL THEN ''''All_'''' ELSE SUBSTRING(O.ObjectCode, 1, LEN(SO.ObjectCode)) END, ''''All_'''') END,
			[Property01] = ''''L''''
		 FROM
			SIE4_Object O
			INNER JOIN SIE4_Dim D ON (D.[JobID] = O.[JobID] AND D.DimCode = O.DimCode) OR O.[Param] = ''''#KONTO''''
			LEFT JOIN SIE4_Dim SD ON SD.[JobID] = O.[JobID] AND SD.DimParent = D.DimCode AND O.[Param] <> ''''#KONTO''''
			LEFT JOIN SIE4_Object SO ON SO.[JobID] = O.[JobID] AND SO.DimCode = D.DimParent AND O.[Param] <> ''''#KONTO''''
		WHERE
			O.JobID = @JobID

		SELECT @Inserted = @Inserted + @@ROWCOUNT

		INSERT INTO DimensionData
			(
			[DimensionName],
			[MemberId],
			[Label],
			[Description],
			[Parent1],
			[Property01]
			)	
		SELECT DISTINCT
			[DimensionName] = ''''GL_'''' + D.DimName,
			[MemberId] = 1,
			[Label] = ''''All_'''',
			[Description] = ''''All GL_'''' + D.DimName + ''''(s)'''',
			[Parent1] = NULL,
			[Property01] = ''''P''''
		 FROM
			SIE4_Dim D
		WHERE
			D.JobID = @JobID

		UNION SELECT DISTINCT
			[DimensionName] = ''''GL_'''' + D.DimName,
			[MemberId] = -1,
			[Label] = ''''NONE'''',
			[Description] = ''''None'''',
			[Parent1] = ''''All_'''',
			[Property01] = ''''L''''
		 FROM
			SIE4_Dim D
		WHERE
			D.JobID = @JobID

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Set Account properties and parents''''
		CREATE TABLE #AccountType
			(
			[KTYP] [nchar](1),
			[AccountType] [nvarchar](50),
			[Sign] [int],
			[TimeBalance] [bit],
			[Rate] [nvarchar](255),
			[Parent] [nvarchar](50)
			)
				
		INSERT INTO #AccountType
			(
			[KTYP],
			[AccountType],
			[Sign],
			[TimeBalance],
			[Rate],
			[Parent]
			)
		SELECT
			[KTYP],
			[AccountType],
			[Sign],
			[TimeBalance],
			[Rate],
			[Parent]
		FROM
			(
					SELECT [KTYP] = ''''T'''',	[AccountType] = ''''Asset'''',		[Sign] = 1,		[TimeBalance] = 1, [Rate] = ''''EOP'''',		[Parent] = ''''Assets_''''
			UNION	SELECT [KTYP] = ''''S'''',	[AccountType] = ''''Equity'''',		[Sign] = -1,	[TimeBalance] = 1, [Rate] = ''''EOP'''',		[Parent] = ''''Equity_''''
			UNION	SELECT [KTYP] = ''''K'''',	[AccountType] = ''''Expense'''',		[Sign] = 1,		[TimeBalance] = 0, [Rate] = ''''Average'''',	[Parent] = ''''Expense_''''
			UNION	SELECT [KTYP] = ''''I'''',	[AccountType] = ''''Income'''',		[Sign] = -1,	[TimeBalance] = 0, [Rate] = ''''Average'''',	[Parent] = ''''Gross_Profit_''''
			UNION	SELECT [KTYP] = ''''0'''',	[AccountType] = ''''Liability'''',	[Sign] = -1,	[TimeBalance] = 1, [Rate] = ''''EOP'''',		[Parent] = ''''Liabilities_''''
			) sub

			--KTYP anges som T, S, K eller I (Tillgång, Skuld, Kostnad eller Intäkt)

		IF @KPTYP LIKE ''''%BAS%''''
			BEGIN
				UPDATE DD
				SET 
					Property02 = AT.[AccountType],
					Property03 = AT.[Rate],
					Property04 = AT.[Sign],
					Property05 = AT.[TimeBalance],
					Parent1 = AT.[Parent]
				FROM
					DimensionData DD
					INNER JOIN #AccountType AT ON AT.AccountType = CASE SUBSTRING(DD.Label, 1, 1)
						WHEN ''''1'''' THEN ''''Asset''''
						WHEN ''''2'''' THEN CASE WHEN SUBSTRING(DD.Label, 1, 2) IN (''''25'''', ''''26'''') THEN ''''Liability'''' ELSE ''''Equity'''' END
						WHEN ''''3'''' THEN ''''Income''''
						WHEN ''''4'''' THEN ''''Expense''''
						WHEN ''''5'''' THEN ''''Expense''''
						WHEN ''''6'''' THEN ''''Expense''''
						WHEN ''''7'''' THEN ''''Expense''''
						WHEN ''''8'''' THEN ''''Expense''''
						WHEN ''''9'''' THEN ''''Expense''''
						ELSE NULL END
				WHERE
					DD.[DimensionName] = ''''Account''''
			END
		ELSE
			BEGIN
				UPDATE DD
				SET 
					Property02 = AT.[AccountType],
					Property03 = AT.[Rate],
					Property04 = AT.[Sign],
					Property05 = AT.[TimeBalance],
					Parent1 = AT.[Parent]
				FROM
					DimensionData DD
					INNER JOIN [SIE4_Object] O ON O.[JobID] = @JobID AND O.[Param] = ''''#KTYP'''' AND O.DimCode = DD.[DimensionName] AND O.ObjectCode = DD.[Label]
					INNER JOIN #AccountType AT ON AT.KTYP = O.ObjectName
				WHERE
					DD.[DimensionName] = ''''Account''''
			END
		
		DROP TABLE #AccountType

	SET @Step = ''''Insert BusinessProcess''''
		INSERT INTO DimensionData
			(
			[DimensionName],
			[Label],
			[Description],
			[Parent1],
			[Property01]
			)	
		SELECT
			[DimensionName] = ''''BusinessProcess'''',
			[Label] = ''''SIE4'''',
			[Description] = ''''SIE4'''',
			[Parent1] = ''''ACTUALLOAD'''',
			[Property01] = ''''L''''

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Insert Currency''''
		INSERT INTO DimensionData
			(
			[DimensionName],
			[Label],
			[Description],
			[Parent1],
			[Property01]
			)	
		SELECT
			[DimensionName] = ''''Currency'''',
			[Label] = ISNULL(CONVERT(nvarchar(10), J.VALUTA), ''''NONE''''),
			[Description] = ISNULL(CONVERT(nvarchar(10), J.VALUTA), ''''NONE''''),
			[Parent1] = ''''All_'''',
			[Property01] = ''''L''''
		FROM
			SIE4_Job J
		WHERE
			J.JobID = @JobID

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Insert Entity''''
		INSERT INTO DimensionData
			(
			[DimensionName],
			[Label],
			[Description],
			[Parent1],
			[Property01],
			[Property02]
			)	
		SELECT
			[DimensionName] = ''''Entity'''',
			[Label] = COALESCE(J.FNR, J.ORGNR, J.FNAMN),
			[Description] = COALESCE(J.FNAMN, J.FNR, J.ORGNR),
			[Parent1] = ''''All_'''',
			[Property01] = ''''L'''',
			[Property02] = ISNULL(CONVERT(nvarchar(10), J.VALUTA), ''''NONE'''')
		FROM
			SIE4_Job J
		WHERE
			J.JobID = @JobID

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Insert Time''''
		INSERT INTO DimensionData
			(
			[DimensionName],
			[Label],
			[Description],
			[Parent1],
			[Property01]
			)	
		SELECT
			[DimensionName] = ''''Time'''',
			[Label] = MIN(LEFT(CONVERT(nvarchar(10), ISNULL(T.Date, V.Date), 112), 6)),
			[Description] = MIN(LEFT(CONVERT(nvarchar(10), ISNULL(T.Date, V.Date), 112), 6)),
			[Parent1] = ''''All_'''',
			[Property01] = ''''L''''
		FROM
			SIE4_Job J
			INNER JOIN SIE4_Ver V ON V.JobID = J.JobID AND V.[Param] = ''''#VER''''
			INNER JOIN SIE4_Trans T ON T.JobID = V.JobID AND T.[Param] = ''''#TRANS'''' AND  T.Seq = V.Seq AND T.Ver = V.Ver
		WHERE
			J.JobID = @JobID

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_IU_DimensionData] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spSIE4_IU_FactData'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_IU_FactData] 
	(
	@UserName nvarchar(50),
	@JobID int,
	@Version nvarchar(50) = NULL,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC [spSIE4_IU_FactData] @UserName = ''''jan@pc.com'''', @JobID = 58, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@ModelName nvarchar(100),
	@SQLStatement nvarchar(max),
	@Select nvarchar(max),
	@Select_Sub1 nvarchar(max),
	@Select_Sub2 nvarchar(max),
	@GroupBy nvarchar(max),
	@GroupBy_Sub1 nvarchar(max)

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Create FactData_Cursor''''
		DECLARE FactData_Cursor CURSOR FOR
			SELECT
				ModelName
			FROM
				Model

			OPEN FactData_Cursor
			FETCH NEXT FROM FactData_Cursor INTO @ModelName

			WHILE @@FETCH_STATUS = 0
			  BEGIN
				IF @Debug <> 0 SELECT ModelName = @ModelName

				IF (SELECT COUNT(1) FROM sys.Tables WHERE name = ''''FactData_'''' + @ModelName) > 0
					BEGIN
						SET @SQLStatement = ''''SELECT Temp = 1 INTO #Temp FROM FactData_'''' + @ModelName
						EXEC (@SQLStatement)
						SELECT @Deleted = @@ROWCOUNT
						SET @SQLStatement = ''''DROP TABLE FactData_'''' + @ModelName
						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)
					END

		--TopLevel
					SET @SQLStatement = ''''''''

					SELECT
						@SQLStatement = @SQLStatement + [String] + CHAR(13) + CHAR(10)
					FROM
						(
						SELECT
							[String] = CHAR(9) + ''''['''' + MD.DimensionName + ''''] = sub.['''' + MD.DimensionName + ''''],'''',
							SortOrder = CASE WHEN MD.DimensionName LIKE ''''GL_%'''' THEN 100 ELSE 50 END
						FROM
							ModelDimension MD
						WHERE
							MD.ModelName = @ModelName

						UNION 
						SELECT DISTINCT
							[String] = CHAR(9) + ''''['''' + ModelName + ''''_Value] = sub.['''' + ModelName + ''''_Value],'''',
							SortOrder = 150
						FROM 
							ModelDimension
						WHERE
							ModelName = @ModelName
						) sub
					ORDER BY
						[SortOrder],
						[String]

					SET @SQLStatement = ''''
SELECT
'''' + @SQLStatement + CHAR(9) + ''''[ChangeDatetime] = GetDate(),
	[UserID] = '''''''''''' + @UserName + ''''''''''''
INTO
	FactData_Financials
FROM
	(
	SELECT
''''

		--P&L
					SELECT
						@Select = '''''''', @GroupBy = ''''''''

					SELECT
						@Select = @Select + ISNULL([Select] + CHAR(13) + CHAR(10), ''''''''),
						@GroupBy = @GroupBy + ISNULL([GroupBy] + CHAR(13) + CHAR(10), '''''''')
					FROM
						(
						SELECT
							[Select] = CHAR(9) + CHAR(9) + ''''['''' + MD.DimensionName + ''''] = COALESCE(CASE WHEN T.DimCode_01 = '''' + D.DimCode + '''' THEN T.ObjectCode_01 END, CASE WHEN T.DimCode_02 = '''' + D.DimCode + '''' THEN T.ObjectCode_02 END, CASE WHEN T.DimCode_03 = '''' + D.DimCode + '''' THEN T.ObjectCode_03 END, CASE WHEN T.DimCode_04 = '''' + D.DimCode + '''' THEN T.ObjectCode_04 END, CASE WHEN T.DimCode_05 = '''' + D.DimCode + '''' THEN T.ObjectCode_05 END, CASE WHEN T.DimCode_06 = '''' + D.DimCode + '''' THEN T.ObjectCode_06 END, CASE WHEN T.DimCode_07 = '''' + D.DimCode + '''' THEN T.ObjectCode_07 END, CASE WHEN T.DimCode_08 = '''' + D.DimCode + '''' THEN T.ObjectCode_08 END, CASE WHEN T.DimCode_09 = '''' + D.DimCode + '''' THEN T.ObjectCode_09 END, CASE WHEN T.DimCode_10 = '''' + D.DimCode + '''' THEN T.ObjectCode_10 END, CASE WHEN T.DimCode_11 = '''' + D.DimCode + '''' THEN T.ObjectCode_11 END, CASE WHEN T.DimCode_12 = '''' + D.DimCode + '''' THEN T.ObjectCode_12 END, CASE WHEN T.DimCode_13 = '''' + D.DimCode + '''' THEN T.ObjectCode_13 END, CASE WHEN T.DimCode_14 = '''' + D.DimCode + '''' THEN T.ObjectCode_14 END, CASE WHEN T.DimCode_15 = '''' + D.DimCode + '''' THEN T.ObjectCode_15 END, CASE WHEN T.DimCode_16 = '''' + D.DimCode + '''' THEN T.ObjectCode_16 END, CASE WHEN T.DimCode_17 = '''' + D.DimCode + '''' THEN T.ObjectCode_17 END, CASE WHEN T.DimCode_18 = '''' + D.DimCode + '''' THEN T.ObjectCode_18 END, CASE WHEN T.DimCode_19 = '''' + D.DimCode + '''' THEN T.ObjectCode_19 END, CASE WHEN T.DimCode_20 = '''' + D.DimCode + '''' THEN T.ObjectCode_20 ELSE ''''''''NONE'''''''' END),'''',
							[GroupBy] = CHAR(9) + CHAR(9) + ''''COALESCE(CASE WHEN T.DimCode_01 = '''' + D.DimCode + '''' THEN T.ObjectCode_01 END, CASE WHEN T.DimCode_02 = '''' + D.DimCode + '''' THEN T.ObjectCode_02 END, CASE WHEN T.DimCode_03 = '''' + D.DimCode + '''' THEN T.ObjectCode_03 END, CASE WHEN T.DimCode_04 = '''' + D.DimCode + '''' THEN T.ObjectCode_04 END, CASE WHEN T.DimCode_05 = '''' + D.DimCode + '''' THEN T.ObjectCode_05 END, CASE WHEN T.DimCode_06 = '''' + D.DimCode + '''' THEN T.ObjectCode_06 END, CASE WHEN T.DimCode_07 = '''' + D.DimCode + '''' THEN T.ObjectCode_07 END, CASE WHEN T.DimCode_08 = '''' + D.DimCode + '''' THEN T.ObjectCode_08 END, CASE WHEN T.DimCode_09 = '''' + D.DimCode + '''' THEN T.ObjectCode_09 END, CASE WHEN T.DimCode_10 = '''' + D.DimCode + '''' THEN T.ObjectCode_10 END, CASE WHEN T.DimCode_11 = '''' + D.DimCode + '''' THEN T.ObjectCode_11 END, CASE WHEN T.DimCode_12 = '''' + D.DimCode + '''' THEN T.ObjectCode_12 END, CASE WHEN T.DimCode_13 = '''' + D.DimCode + '''' THEN T.ObjectCode_13 END, CASE WHEN T.DimCode_14 = '''' + D.DimCode + '''' THEN T.ObjectCode_14 END, CASE WHEN T.DimCode_15 = '''' + D.DimCode + '''' THEN T.ObjectCode_15 END, CASE WHEN T.DimCode_16 = '''' + D.DimCode + '''' THEN T.ObjectCode_16 END, CASE WHEN T.DimCode_17 = '''' + D.DimCode + '''' THEN T.ObjectCode_17 END, CASE WHEN T.DimCode_18 = '''' + D.DimCode + '''' THEN T.ObjectCode_18 END, CASE WHEN T.DimCode_19 = '''' + D.DimCode + '''' THEN T.ObjectCode_19 END, CASE WHEN T.DimCode_20 = '''' + D.DimCode + '''' THEN T.ObjectCode_20 ELSE ''''''''NONE'''''''' END),'''',
							SortOrder = 100 
						FROM
							ModelDimension MD 
							INNER JOIN SIE4_Dim D ON D.JobID = @JobID AND ''''GL_'''' + D.DimName = MD.DimensionName
						WHERE
							MD.ModelName = @ModelName

						UNION
						SELECT
							[Select] = CHAR(9) + CHAR(9) + CASE D.DimensionID
										WHEN -1 THEN ''''['''' + MD.DimensionName + ''''] = T.Account,''''
										WHEN -2 THEN ''''['''' + MD.DimensionName + ''''] = ''''''''SIE4'''''''',''''
										WHEN -3 THEN ''''['''' + MD.DimensionName + ''''] = ISNULL(CONVERT(nvarchar(10), J.VALUTA), ''''''''NONE''''''''),''''
										WHEN -4 THEN ''''['''' + MD.DimensionName + ''''] = COALESCE(J.FNR, J.ORGNR, J.FNAMN),''''
										WHEN -7 THEN ''''['''' + MD.DimensionName + ''''] = LEFT(CONVERT(nvarchar(10), ISNULL(T.Date, V.Date), 112), 6),''''
									END,
							[GroupBy] = CHAR(9) + CHAR(9) + CASE D.DimensionID
										WHEN -1 THEN ''''T.Account,''''
										WHEN -3 THEN ''''ISNULL(CONVERT(nvarchar(10), J.VALUTA), ''''''''NONE''''''''),''''
										WHEN -4 THEN ''''COALESCE(J.FNR, J.ORGNR, J.FNAMN),''''
										WHEN -7 THEN ''''LEFT(CONVERT(nvarchar(10), ISNULL(T.Date, V.Date), 112), 6),''''
									END,
							SortOrder = 50 
						FROM
							ModelDimension MD 
							INNER JOIN Dimension D ON D.DimensionName = MD.DimensionName AND D.DimensionTypeID <> -1
						WHERE
							MD.ModelName = @ModelName

						UNION 
						SELECT DISTINCT
							[Select] = CHAR(9) + CHAR(9) + ''''['''' + ModelName + ''''_Value] = SUM(T.Amount)'''',
							[GroupBy] = '''''''',
							SortOrder = 150
						FROM 
							ModelDimension
						WHERE
							ModelName = @ModelName
						) sub
					ORDER BY
						[SortOrder],
						[Select]

					SET @GroupBy = SUBSTRING(@GroupBy, 1, LEN(@GroupBy) - 5)

					SET @SQLStatement = @SQLStatement + @Select +
''''	FROM
		SIE4_Job J
		INNER JOIN [SIE4_Ver] V ON V.[JobID] = J.[JobID] AND V.[Param] = ''''''''#VER''''''''
		INNER JOIN [SIE4_Trans] T ON T.[JobID] = V.[JobID] AND T.[Param] = ''''''''#TRANS'''''''' AND  T.[Seq] = V.[Seq] AND T.[Ver] = V.[Ver]
		INNER JOIN (SELECT
						Account = DD.Label
					FROM
						[DimensionData] DD
						INNER JOIN [Dimension] D ON D.DimensionName = DD.DimensionName AND D.DimensionID = -1
					WHERE
						DD.Property05 = 0) R ON R.Account = T.Account
	WHERE
		J.[JobID] = '''' + CONVERT(nvarchar(10), @JobID) + ''''
	GROUP BY
'''' + @GroupBy + ''''

	UNION SELECT
''''
		--Balance
					SELECT
						@Select = '''''''', @Select_Sub1 = '''''''', @Select_Sub2 = '''''''', @GroupBy = '''''''', @GroupBy_Sub1 = ''''''''

					SELECT
						@Select = @Select + ISNULL([Select] + CHAR(13) + CHAR(10), ''''''''),
						@Select_Sub1 = @Select_Sub1 + ISNULL([Select_Sub1] + CHAR(13) + CHAR(10), ''''''''),
						@Select_Sub2 = @Select_Sub2 + ISNULL([Select_Sub2] + CHAR(13) + CHAR(10), ''''''''),
						@GroupBy = @GroupBy + ISNULL([GroupBy] + CHAR(13) + CHAR(10), ''''''''),
						@GroupBy_Sub1 = @GroupBy_Sub1 + ISNULL([GroupBy_Sub1] + CHAR(13) + CHAR(10), '''''''')
					FROM
						(
						SELECT
							[Select] = CHAR(9) + CHAR(9) + ''''['''' + MD.DimensionName + ''''] = sub.['''' + MD.DimensionName + ''''],'''',
							[Select_Sub1] = CHAR(9) + CHAR(9) + CHAR(9) + ''''['''' + MD.DimensionName + ''''] = COALESCE(CASE WHEN V.DimCode_01 = '''' + D.DimCode + '''' THEN V.ObjectCode_01 END, CASE WHEN V.DimCode_02 = '''' + D.DimCode + '''' THEN V.ObjectCode_02 END, CASE WHEN V.DimCode_03 = '''' + D.DimCode + '''' THEN V.ObjectCode_03 END, CASE WHEN V.DimCode_04 = '''' + D.DimCode + '''' THEN V.ObjectCode_04 END, CASE WHEN V.DimCode_05 = '''' + D.DimCode + '''' THEN V.ObjectCode_05 END, CASE WHEN V.DimCode_06 = '''' + D.DimCode + '''' THEN V.ObjectCode_06 END, CASE WHEN V.DimCode_07 = '''' + D.DimCode + '''' THEN V.ObjectCode_07 END, CASE WHEN V.DimCode_08 = '''' + D.DimCode + '''' THEN V.ObjectCode_08 END, CASE WHEN V.DimCode_09 = '''' + D.DimCode + '''' THEN V.ObjectCode_09 END, CASE WHEN V.DimCode_10 = '''' + D.DimCode + '''' THEN V.ObjectCode_10 END, CASE WHEN V.DimCode_11 = '''' + D.DimCode + '''' THEN V.ObjectCode_11 END, CASE WHEN V.DimCode_12 = '''' + D.DimCode + '''' THEN V.ObjectCode_12 END, CASE WHEN V.DimCode_13 = '''' + D.DimCode + '''' THEN V.ObjectCode_13 END, CASE WHEN V.DimCode_14 = '''' + D.DimCode + '''' THEN V.ObjectCode_14 END, CASE WHEN V.DimCode_15 = '''' + D.DimCode + '''' THEN V.ObjectCode_15 END, CASE WHEN V.DimCode_16 = '''' + D.DimCode + '''' THEN V.ObjectCode_16 END, CASE WHEN V.DimCode_17 = '''' + D.DimCode + '''' THEN V.ObjectCode_17 END, CASE WHEN V.DimCode_18 = '''' + D.DimCode + '''' THEN V.ObjectCode_18 END, CASE WHEN V.DimCode_19 = '''' + D.DimCode + '''' THEN V.ObjectCode_19 END, CASE WHEN V.DimCode_20 = '''' + D.DimCode + '''' THEN V.ObjectCode_20 ELSE ''''''''NONE'''''''' END),'''',
							[Select_Sub2] = CHAR(9) + CHAR(9) + CHAR(9) + ''''['''' + MD.DimensionName + ''''] = ''''''''NONE'''''''','''',
							[GroupBy] = CHAR(9) + CHAR(9) + ''''sub.['''' + MD.DimensionName + ''''],'''',
							[GroupBy_Sub1] = CHAR(9) + CHAR(9) + CHAR(9) + ''''COALESCE(CASE WHEN V.DimCode_01 = '''' + D.DimCode + '''' THEN V.ObjectCode_01 END, CASE WHEN V.DimCode_02 = '''' + D.DimCode + '''' THEN V.ObjectCode_02 END, CASE WHEN V.DimCode_03 = '''' + D.DimCode + '''' THEN V.ObjectCode_03 END, CASE WHEN V.DimCode_04 = '''' + D.DimCode + '''' THEN V.ObjectCode_04 END, CASE WHEN V.DimCode_05 = '''' + D.DimCode + '''' THEN V.ObjectCode_05 END, CASE WHEN V.DimCode_06 = '''' + D.DimCode + '''' THEN V.ObjectCode_06 END, CASE WHEN V.DimCode_07 = '''' + D.DimCode + '''' THEN V.ObjectCode_07 END, CASE WHEN V.DimCode_08 = '''' + D.DimCode + '''' THEN V.ObjectCode_08 END, CASE WHEN V.DimCode_09 = '''' + D.DimCode + '''' THEN V.ObjectCode_09 END, CASE WHEN V.DimCode_10 = '''' + D.DimCode + '''' THEN V.ObjectCode_10 END, CASE WHEN V.DimCode_11 = '''' + D.DimCode + '''' THEN V.ObjectCode_11 END, CASE WHEN V.DimCode_12 = '''' + D.DimCode + '''' THEN V.ObjectCode_12 END, CASE WHEN V.DimCode_13 = '''' + D.DimCode + '''' THEN V.ObjectCode_13 END, CASE WHEN V.DimCode_14 = '''' + D.DimCode + '''' THEN V.ObjectCode_14 END, CASE WHEN V.DimCode_15 = '''' + D.DimCode + '''' THEN V.ObjectCode_15 END, CASE WHEN V.DimCode_16 = '''' + D.DimCode + '''' THEN V.ObjectCode_16 END, CASE WHEN V.DimCode_17 = '''' + D.DimCode + '''' THEN V.ObjectCode_17 END, CASE WHEN V.DimCode_18 = '''' + D.DimCode + '''' THEN V.ObjectCode_18 END, CASE WHEN V.DimCode_19 = '''' + D.DimCode + '''' THEN V.ObjectCode_19 END, CASE WHEN V.DimCode_20 = '''' + D.DimCode + '''' THEN V.ObjectCode_20 ELSE ''''''''NONE'''''''' END),'''',
							SortOrder = 100 
						FROM
							ModelDimension MD 
							INNER JOIN SIE4_Dim D ON D.JobID = @JobID AND ''''GL_'''' + D.DimName = MD.DimensionName
						WHERE
							MD.ModelName = @ModelName

						UNION
						SELECT
							[Select] = CHAR(9) + CHAR(9) + CASE D.DimensionID
										WHEN -1 THEN ''''['''' + MD.DimensionName + ''''] = sub.Account,''''
										WHEN -2 THEN ''''['''' + MD.DimensionName + ''''] = ''''''''SIE4'''''''',''''
										WHEN -3 THEN ''''['''' + MD.DimensionName + ''''] = sub.[Currency],''''
										WHEN -4 THEN ''''['''' + MD.DimensionName + ''''] = sub.[Entity],''''
										WHEN -7 THEN ''''['''' + MD.DimensionName + ''''] = sub.[Time],''''
									END,
							[Select_Sub1] = CHAR(9) + CHAR(9) + CHAR(9) + CASE D.DimensionID
										WHEN -1 THEN ''''['''' + MD.DimensionName + ''''] = A.Account,''''
										WHEN -3 THEN ''''['''' + MD.DimensionName + ''''] = ISNULL(CONVERT(nvarchar(10), J.VALUTA), ''''''''NONE''''''''),''''
										WHEN -4 THEN ''''['''' + MD.DimensionName + ''''] = COALESCE(J.FNR, J.ORGNR, J.FNAMN),''''
										WHEN -7 THEN ''''['''' + MD.DimensionName + ''''] = T.[Time],''''
									END,
							[Select_Sub2] = CHAR(9) + CHAR(9) + CHAR(9) + CASE D.DimensionID
										WHEN -1 THEN ''''['''' + MD.DimensionName + ''''] = B.Account,''''
										WHEN -3 THEN ''''['''' + MD.DimensionName + ''''] = ISNULL(CONVERT(nvarchar(10), J.VALUTA), ''''''''NONE''''''''),''''
										WHEN -4 THEN ''''['''' + MD.DimensionName + ''''] = COALESCE(J.FNR, J.ORGNR, J.FNAMN),''''
										WHEN -7 THEN ''''['''' + MD.DimensionName + ''''] = T.[Time],''''
									END,
							[GroupBy] = CHAR(9) + CHAR(9) + CASE D.DimensionID
										WHEN -1 THEN ''''sub.Account,''''
										WHEN -3 THEN ''''sub.[Currency],''''
										WHEN -4 THEN ''''sub.[Entity],''''
										WHEN -7 THEN ''''sub.[Time],''''
									END,
							[GroupBy_Sub1] = CHAR(9) + CHAR(9) + CHAR(9) + CASE D.DimensionID
										WHEN -1 THEN ''''A.Account,''''
										WHEN -3 THEN ''''ISNULL(CONVERT(nvarchar(10), J.VALUTA), ''''''''NONE''''''''),''''
										WHEN -4 THEN ''''COALESCE(J.FNR, J.ORGNR, J.FNAMN),''''
										WHEN -7 THEN ''''T.[Time],''''
									END,
							SortOrder = 50 
						FROM
							ModelDimension MD 
							INNER JOIN Dimension D ON D.DimensionName = MD.DimensionName AND D.DimensionTypeID <> -1
						WHERE
							MD.ModelName = @ModelName

						UNION 
						SELECT DISTINCT
							[Select] = CHAR(9) + CHAR(9) + ''''['''' + ModelName + ''''_Value] = SUM(sub.['''' + ModelName + ''''_Value])'''',
							[Select_Sub1] = CHAR(9) + CHAR(9) + CHAR(9) + ''''['''' + ModelName + ''''_Value] = ISNULL(SUM(V.Amount), 0)'''',
							[Select_Sub2] = CHAR(9) + CHAR(9) + CHAR(9) + ''''['''' + ModelName + ''''_Value] = B.Amount'''',
							[GroupBy] = '''''''',
							[GroupBy_Sub1] = '''''''',
							SortOrder = 150
						FROM 
							ModelDimension
						WHERE
							ModelName = @ModelName
						) sub
					ORDER BY
						[SortOrder],
						[Select]

					SET @GroupBy = SUBSTRING(@GroupBy, 1, LEN(@GroupBy) - 5)
					SET @GroupBy_Sub1 = SUBSTRING(@GroupBy_Sub1, 1, LEN(@GroupBy_Sub1) - 5)


					SET @SQLStatement = @SQLStatement + ''''
'''' + @Select + ''''
	FROM
		(
		SELECT
'''' + @Select_Sub1 + ''''
		FROM
			(SELECT DISTINCT
				[Account] = B.Account
			FROM
				SIE4_Job J
				INNER JOIN SIE4_Balance B ON B.[JobID] = J.[JobID] AND B.[Param] = ''''''''#IB'''''''' AND B.[RAR] = 0
			WHERE
				J.[JobID] = '''' + CONVERT(nvarchar(10), @JobID) + ''''
			UNION SELECT DISTINCT
				[Account] = T.Account
			FROM	
				[SIE4_Trans] T
				INNER JOIN (SELECT
							Account = DD.Label
						FROM
							[DimensionData] DD
							INNER JOIN [Dimension] D ON D.DimensionName = DD.DimensionName AND D.DimensionID = -1
						WHERE
							DD.Property05 <> 0) R ON R.Account = T.Account
			WHERE
				T.[JobID] = '''' + CONVERT(nvarchar(10), @JobID) + '''' AND
				T.[Param] = ''''''''#TRANS'''''''') A
			INNER JOIN SIE4_Job J ON 1 = 1
			INNER JOIN (SELECT DISTINCT
							V.JobID,
							[Time] = LEFT(CONVERT(nvarchar(10), ISNULL(T.Date, V.Date), 112), 6)
						FROM
							[SIE4_Ver] V 
							INNER JOIN [SIE4_Trans] T ON T.[JobID] = V.[JobID] AND T.[Param] = ''''''''#TRANS'''''''' AND  T.[Seq] = V.[Seq] AND T.[Ver] = V.[Ver]
						WHERE
							V.[JobID] = '''' + CONVERT(nvarchar(10), @JobID) + '''' AND
							V.[Param] = ''''''''#VER'''''''') T ON T.JobID = J.JobID
			LEFT JOIN (SELECT DISTINCT
							V.JobID,
							T.Account,
							T.[DimCode_01],
							T.[ObjectCode_01],
							T.[DimCode_02],
							T.[ObjectCode_02],
							T.[DimCode_03],
							T.[ObjectCode_03],
							T.[DimCode_04],
							T.[ObjectCode_04],
							T.[DimCode_05],
							T.[ObjectCode_05],
							T.[DimCode_06],
							T.[ObjectCode_06],
							T.[DimCode_07],
							T.[ObjectCode_07],
							T.[DimCode_08],
							T.[ObjectCode_08],
							T.[DimCode_09],
							T.[ObjectCode_09],
							T.[DimCode_10],
							T.[ObjectCode_10],''''
					SET @SQLStatement = @SQLStatement + ''''
							T.[DimCode_11],
							T.[ObjectCode_11],
							T.[DimCode_12],
							T.[ObjectCode_12],
							T.[DimCode_13],
							T.[ObjectCode_13],
							T.[DimCode_14],
							T.[ObjectCode_14],
							T.[DimCode_15],
							T.[ObjectCode_15],
							T.[DimCode_16],
							T.[ObjectCode_16],
							T.[DimCode_17],
							T.[ObjectCode_17],
							T.[DimCode_18],
							T.[ObjectCode_18],
							T.[DimCode_19],
							T.[ObjectCode_19],
							T.[DimCode_20],
							T.[ObjectCode_20],
							T.Amount,
							[Time] = LEFT(CONVERT(nvarchar(10), ISNULL(T.Date, V.Date), 112), 6)
						FROM
							[SIE4_Ver] V 
							INNER JOIN [SIE4_Trans] T ON T.[JobID] = V.[JobID] AND T.[Param] = ''''''''#TRANS'''''''' AND  T.[Seq] = V.[Seq] AND T.[Ver] = V.[Ver]
						WHERE
							V.[JobID] = '''' + CONVERT(nvarchar(10), @JobID) + '''' AND
							V.[Param] = ''''''''#VER'''''''') V ON V.JobID = J.JobID AND V.Account = A.Account AND V.[Time] <= T.[Time]
		WHERE
			J.[JobID] = '''' + CONVERT(nvarchar(10), @JobID) + ''''
		GROUP BY
'''' + @GroupBy_Sub1 + ''''

		UNION SELECT
'''' + @Select_Sub2 + ''''
		FROM
			SIE4_Job J
			INNER JOIN SIE4_Balance B ON B.[JobID] = J.[JobID] AND B.[Param] = ''''''''#IB'''''''' AND B.[RAR] = 0
			INNER JOIN (SELECT DISTINCT
							V.JobID,
							[Time] = LEFT(CONVERT(nvarchar(10), ISNULL(T.Date, V.Date), 112), 6)
						FROM
							[SIE4_Ver] V 
							INNER JOIN [SIE4_Trans] T ON T.[JobID] = V.[JobID] AND T.[Param] = ''''''''#TRANS'''''''' AND  T.[Seq] = V.[Seq] AND T.[Ver] = V.[Ver]
						WHERE
							V.[JobID] = '''' + CONVERT(nvarchar(10), @JobID) + '''' AND
							V.[Param] = ''''''''#VER'''''''') T ON T.JobID = J.JobID
		WHERE
			J.[JobID] = '''' + CONVERT(nvarchar(10), @JobID) + ''''
		) sub
	GROUP BY
'''' + @GroupBy + ''''
		
	UNION SELECT
''''
	
		--Incoming Balance
					SELECT
						@SQLStatement = @SQLStatement + [String] + CHAR(13) + CHAR(10)
					FROM
						(
						SELECT
							[String] = CHAR(9) + CHAR(9) + ''''['''' + MD.DimensionName + ''''] = ''''''''NONE'''''''','''',
							SortOrder = 100 
						FROM
							ModelDimension MD 
							INNER JOIN SIE4_Dim D ON D.JobID = @JobID AND ''''GL_'''' + D.DimName = MD.DimensionName
						WHERE
							MD.ModelName = @ModelName

						UNION
						SELECT
							[String] = CHAR(9) + CHAR(9) + CASE D.DimensionID
										WHEN -1 THEN ''''['''' + MD.DimensionName + ''''] = B.Account,''''
										WHEN -2 THEN ''''['''' + MD.DimensionName + ''''] = ''''''''FP0'''''''',''''
										WHEN -3 THEN ''''['''' + MD.DimensionName + ''''] = ISNULL(CONVERT(nvarchar(10), J.VALUTA), ''''''''NONE''''''''),''''
										WHEN -4 THEN ''''['''' + MD.DimensionName + ''''] = COALESCE(J.FNR, J.ORGNR, J.FNAMN),''''
										WHEN -7 THEN ''''['''' + MD.DimensionName + ''''] = LEFT(CONVERT(nvarchar(10), J.RAR_0_FROM, 112), 6),''''
									END,
							SortOrder = 50 
						FROM
							ModelDimension MD 
							INNER JOIN Dimension D ON D.DimensionName = MD.DimensionName AND D.DimensionTypeID <> -1
						WHERE
							MD.ModelName = @ModelName

						UNION 
						SELECT DISTINCT
							[String] = CHAR(9) + CHAR(9) + ''''['''' + ModelName + ''''_Value] = B.Amount'''',
							SortOrder = 150
						FROM 
							ModelDimension
						WHERE
							ModelName = @ModelName
						) sub
					ORDER BY
						[SortOrder],
						[String]

					SET @SQLStatement = @SQLStatement + 
''''	FROM
		SIE4_Job J
		INNER JOIN SIE4_Balance B ON B.[JobID] = J.[JobID] AND B.[Param] = ''''''''#IB'''''''' AND B.[RAR] = 0
	WHERE
		J.[JobID] = '''' + CONVERT(nvarchar(10), @JobID) + ''''
	) sub''''

						IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Creation of table'''', [SQLStatement] = @SQLStatement

						EXEC (@SQLStatement)

						SELECT @Inserted = @Inserted + @@ROWCOUNT

				FETCH NEXT FROM FactData_Cursor INTO @ModelName
			  END

		CLOSE FactData_Cursor
		DEALLOCATE FactData_Cursor

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_IU_FactData] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1


				SET @Step = 'Create procedure spSIE4_IU_Model'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_IU_Model] 
	(
	@UserName nvarchar(50),
	@JobID int,
	@Version nvarchar(50) = NULL,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC [spSIE4_IU_Model] @UserName = ''''jan@pc.com'''', @JobID = 3, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''TRUNCATE TABLE Model''''
		SELECT @Deleted = COUNT(1) FROM Model
		--TRUNCATE TABLE Model
		DELETE Model

	SET @Step = ''''INSERT INTO Model''''
		INSERT INTO Model
			(
			ModelName,
			ModelDescription,
			ModelType,
			BaseModelID
			)
		SELECT 
			ModelName = ''''Financials'''',
			ModelDescription = ''''Financials'''',
			ModelType = ''''Financials'''',
			BaseModelID = -7

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_IU_Model] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1

				SET @Step = 'Create procedure spSIE4_IU_ModelDimension'
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSIE4_IU_ModelDimension] 
	(
	@UserName nvarchar(50),
	@JobID int,
	@Version nvarchar(50) = NULL,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT
	)

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC [spSIE4_IU_ModelDimension] @UserName = ''''jan@pc.com'''', @JobID = 3, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int

BEGIN TRY	
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''TRUNCATE TABLE ModelDimension''''
		SELECT @Deleted = COUNT(1) FROM ModelDimension
		--TRUNCATE TABLE ModelDimension
		DELETE ModelDimension

	SET @Step = ''''INSERT INTO ModelDimension''''
		INSERT INTO ModelDimension
			(
			ModelName,
			DimensionName,
			[HideInExcel],
			[SendToMemberId]
			)
		SELECT 
			ModelName = ''''Financials'''',
			DimensionName = sub.[DimensionName],
			HideInExcel = 0,
			[SendToMemberId] = 0
		FROM
			(
			SELECT DISTINCT
				DimensionName = ''''GL_'''' + D.DimName
			FROM
				SIE4_Dim D
			WHERE
				D.JobID = @JobID AND
				D.[Param] IN (''''#DIM'''', ''''#UNDERDIM'''') 

			UNION SELECT DISTINCT
				DimensionName = ''''Account''''

			UNION SELECT DISTINCT
				DimensionName = ''''BusinessProcess''''

			UNION SELECT DISTINCT
				DimensionName = ''''Currency''''

			UNION SELECT DISTINCT
				DimensionName = ''''Entity''''

			UNION SELECT DISTINCT
				DimensionName = ''''Time''''
			) sub

		SELECT @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, 0, 0, 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

					SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spSIE4_IU_ModelDimension] ', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
					SET @Inserted = @Inserted + 1
			END --End of procedures SIE4

	SET @Step = 'Fill the Exchange database'
		IF @pcExchangeType IN ('Demo', 'Upgrade')
			BEGIN
				SET @SQLStatement = 'EXEC ' + @pcExchangeDatabase + '.dbo.sp_executesql N''EXEC [spGet_All]'''
				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)
			END

	SET @Step = 'Add source metadata'
		IF @pcExchangeType IN ('Upgrade')
			BEGIN
				SET @SQLStatement = '
					INSERT INTO [Source]
						(
						[SourceName],
						[SourceDescription],
						[ModelID],
						[SourceTypeID],
						[SourceDatabase],
						[StartYear],
						[SelectYN]
						)
					SELECT 
						[SourceName] = ''pcEXCHANGE_'' + M.ModelName,
						[SourceDescription] = ''pcEXCHANGE_'' + M.ModelName,
						[ModelID] = M.ModelID,
						[SourceTypeID] = 6,
						[SourceDatabase] = ''' + REPLACE(REPLACE(@pcExchangeDatabase, '[', ''), ']', '') + ''',
						[StartYear] = 1950,
						[SelectYN] = 1
					FROM
						[Application] A
						INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
						INNER JOIN ' + @pcExchangeDatabase + '..Model SM ON SM.BaseModelID = M.BaseModelID AND SM.SelectYN <> 0
					WHERE
						A.InheritedFrom = ' + CONVERT(nvarchar(10), @ApplicationID) + ' AND
						A.SelectYN <> 0'

				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

				UPDATE S
				SET
					[BusinessProcess] = 'pcEXCHANGE_' + CONVERT(nvarchar(10), S.SourceID)
				FROM
					[Application] A
					INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
					INNER JOIN [Source] S ON S.ModelID = M.ModelID
				WHERE
					A.InheritedFrom = @ApplicationID AND
					A.SelectYN <> 0

			END

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		RETURN 0

	SET @Step = 'EXITPOINT:'
		EXITPOINT:
		SET @Duration = GetDate() - @StartTime
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ErrorNumber = -1000, ErrorSeverity = 10, ErrorState = 0, ErrorLine = 0, ErrorProcedure = OBJECT_NAME(@@PROCID), @Step, ErrorMessage = 'The database ' + @pcExchangeDatabase + ' already exists. To get it replaced, delete the database manually and rerun the procedure.', @Version
		SET @JobLogID = @@IDENTITY
		SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
		SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
		RETURN @ErrorNumber
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH


GO
