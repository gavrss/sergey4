SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_pcDRILLPAGE]

	@JobID int = 0,
	@ApplicationID int = NULL,
	@pcDrillPage nvarchar(100) = NULL,
	@Debug bit = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_pcDRILLPAGE] @Debug = 1
--EXEC [spCreate_pcDRILLPAGE] @ApplicationID = 400, @pcDrillPage = 'pcDRILLPAGE_MR30', @Debug = 1
--EXEC [spCreate_pcDRILLPAGE] @GetVersion = 1
--EXEC [spCreate_pcDRILLPAGE] @ApplicationID = 114, @pcDrillPage = 'pcDRILLPAGE_AnnJoo', @Debug = 1 --AnnJoo
--EXEC [spCreate_pcDRILLPAGE] @ApplicationID = 53, @pcDrillPage = 'pcDRILLPAGE_02Test', @Debug = 1 --Epicor Cloud demo
--EXEC [spCreate_pcDRILLPAGE] @ApplicationID = 45, @pcDrillPage = 'pcDRILLPAGE_EFP_Demo', @Debug = 1 --Epicor Cloud demo

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@pcExchangeID int,
	@pcExchangeName nvarchar(100),
	@InstanceID int,
	@DestinationDatabase nvarchar(100),
	@SourceDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@SQLStatement2 nvarchar(max),
	@Collation nvarchar(50),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.3.0.2137'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.3.2113' SET @Description = 'Introduced.'
		IF @Version = '1.3.1.2120' SET @Description = 'Lot of modifications.'
		IF @Version = '1.4.0.2133' SET @Description = 'Performance enhancements.'
		IF @Version = '1.4.0.2134' SET @Description = 'Minor adjustments by Andrey.'
		IF @Version = '1.4.0.2136' SET @Description = 'spGet_LeafLabel and spConvert_KeyValuePair updated. Metadata updated. Triggers for Metadata tables.'
		IF @Version = '1.4.0.2137' SET @Description = 'When @JobID = 0, set to @InstanceID.'
		IF @Version = '1.4.0.2139' SET @Description = 'spConvert_KeyValuePair excludes MemberId IN (-1, 1)'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

CREATE TABLE #wrk_debug
(
	wrk_debugID INT IDENTITY(1,1) PRIMARY KEY
	,StepName NVARCHAR(MAX) 
	,SQLQuery NVARCHAR(MAX) 
)

IF @ApplicationID IS NULL OR @pcDrillPage IS NULL
	BEGIN
		PRINT 'Parameter @ApplicationID and parameter @pcDrillPage must be set'
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

		SELECT
			@InstanceID = A.InstanceID,
			@DestinationDatabase = A.DestinationDatabase,
			@SourceDatabase = S.SourceDatabase
		FROM
			[dbo].[Application] A
			INNER JOIN [dbo].[Model] M ON M.ApplicationID = A.ApplicationID
			INNER JOIN [dbo].[Source] S ON S.ModelID = M.ModelID
		WHERE
			A.ApplicationID = @ApplicationID

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'Check existence of DrillPage database'
		IF EXISTS (SELECT 1 FROM sys.databases WHERE [name] = @pcDrillPage)
			GOTO EXITPOINT
		ELSE
			SET @pcDrillPage = '[' + REPLACE(REPLACE(REPLACE(@pcDrillPage, '[', ''), ']', ''), '.', '].[') + ']'

	SET @Step = 'Create database pcDrillPage'
		SET @SQLStatement = 'CREATE DATABASE ' + @pcDrillPage + ' COLLATE ' + @Collation + ' ALTER DATABASE ' + @pcDrillPage + ' SET RECOVERY SIMPLE'
		IF @Debug <> 0 PRINT @SQLStatement 
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	---------------------------
	SET @Step = 'CREATE TABLES'
	---------------------------

	SET @Step = 'Create table SystemParameter'
		SET @SQLStatement = '
			CREATE TABLE ' + @pcDrillPage + '.[dbo].[SystemParameter](
			[SystemParameterID] [int] NOT NULL CONSTRAINT [DF_SystemParameter_SystemParameterID]  DEFAULT ((1)),
			[web_Server] [nvarchar](255) NOT NULL CONSTRAINT [DF_SystemParameter_web_Server]  DEFAULT (N''http://localhost:8015/''),
			[Filter_CB_Limit] [int] NOT NULL CONSTRAINT [DF_SystemParameter_Filter_CB_Limit]  DEFAULT ((100)),
			[Return_Row_Limit] [int] NOT NULL CONSTRAINT [DF_SystemParameter_Return_Row_Limit]  DEFAULT ((100)),
			[DateFormat] [smallint] NOT NULL CONSTRAINT [DF_SystemParameter_DateFormat]  DEFAULT ((23)),
			[CurrencyFormat] [smallint] NOT NULL,
			[pcData_DBName] [nvarchar](100) NOT NULL,
			[pcData_OwnerName] [nvarchar](100) NOT NULL,
			[SourceDB_DBName] [nvarchar](100) NOT NULL,
			[SourceDB_OwnerName] [nvarchar](100) NOT NULL,
			[SourceTypeBM] [int] NOT NULL,
			 CONSTRAINT [PK_SystemParameter] PRIMARY KEY CLUSTERED 
			(
				[SystemParameterID] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
			) ON [PRIMARY]'
			
		IF @Debug <> 0 PRINT @SQLStatement 
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'Create table wrk_ParameterCode'
		SET @SQLStatement = '
			CREATE TABLE ' + @pcDrillPage + '.[dbo].[wrk_ParameterCode](
				[PageID] [int] NULL,
				[ColumnID] [int] NOT NULL,
				[ParameterCode] [nvarchar](10) NULL,
				[isSortOrderAlfa] [bit] NULL,
			 CONSTRAINT [PK_wrk_ParameterCode] PRIMARY KEY CLUSTERED 
			(
				[ColumnID] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
			) ON [PRIMARY]'

		IF @Debug <> 0 PRINT @SQLStatement 
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1
	
	SET @Step = 'Create table Page'
		SET @SQLStatement = '
			CREATE TABLE ' + @pcDrillPage + '.[dbo].[Page](
				[PageID] [int] IDENTITY(1001,1) NOT NULL,
				[PageCode] [nvarchar](50) NOT NULL,
				[PageName] [nvarchar](100) NOT NULL,
				[PageWeight] [int] NULL CONSTRAINT [DF_Page_PageWeight]  DEFAULT ((1)),
				[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Page_SelectYN]  DEFAULT ((1)),
				[Help_Header] [nvarchar](500) NOT NULL CONSTRAINT [DF_Page_Version1]  DEFAULT (''''),
				[Help_Description] [nvarchar](max) NOT NULL CONSTRAINT [DF_Page_Help_Header1]  DEFAULT (''''),
				[Help_Link] [nvarchar](max) NOT NULL CONSTRAINT [DF_Page_Help_Description1]  DEFAULT (''''),
				[Version] [nvarchar](100) NOT NULL CONSTRAINT [DF_Page_Version]  DEFAULT (''''),
			 CONSTRAINT [PK_Page] PRIMARY KEY CLUSTERED 
			(
				[PageID] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
			 CONSTRAINT [UX_PageCode] UNIQUE NONCLUSTERED 
			(
				[PageCode] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
			) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]'

		IF @Debug <> 0 
			PRINT @SQLStatement 
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'Create table PageColumn'
		SET @SQLStatement = '
			CREATE TABLE ' + @pcDrillPage + '.[dbo].[PageColumn](
				[ColumnID] [int] IDENTITY(1001,1) NOT NULL,
				[ColumnName] [nvarchar](50) NOT NULL,
				[PageID] [int] NOT NULL,
				[NumericBM] [int] NOT NULL,
				[SequenceBM] [int] NOT NULL CONSTRAINT [DF_PageColumn_SequenceBM]  DEFAULT ((1)),
				[SortOrder] [int] NOT NULL CONSTRAINT [DF_PageColumn_SortOrder]  DEFAULT ((0)),
				[ColumnFormat] [nvarchar](50) NULL,
				[LinkPageYN] [bit] NOT NULL,
				[FilterYN] [bit] NOT NULL CONSTRAINT [DF_PageColumn_FilterYN]  DEFAULT ((0)),
				[FilterValueMandatoryYN] [bit] NOT NULL CONSTRAINT [DF_PageColumn_FilterValueMandatoryYN]  DEFAULT ((0)),
				[SelectYN] [bit] NOT NULL CONSTRAINT [DF_PageColumn_SelectYN]  DEFAULT ((1)),
				[DefaultYN] [bit] NOT NULL CONSTRAINT [DF_PageColumn_SelectYN1]  DEFAULT ((0)),
				[DeletedYN] [bit] NOT NULL CONSTRAINT [DF_PageColumn_DeletedYN]  DEFAULT ((0)),
				[Version] [nvarchar](100) NOT NULL CONSTRAINT [DF_PageColumn_Version]  DEFAULT (''''),
			 CONSTRAINT [PK_PageColumn] PRIMARY KEY CLUSTERED 
			(
				[ColumnID] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
			) ON [PRIMARY]'

		IF @Debug <> 0 
			PRINT @SQLStatement 
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'Create table PageSource'
		SET @SQLStatement = '
			CREATE TABLE ' + @pcDrillPage + '.[dbo].[PageSource](
				[Comment] [nvarchar](255) NOT NULL,
				[PageID] [int] NOT NULL,
				[ColumnID] [int] NOT NULL,
				[SourceTypeBM] [int] NOT NULL,
				[RevisionBM] [int] NOT NULL CONSTRAINT [DF_SqlSource_Model_FACT_RevisionBM]  DEFAULT ((15)),
				[SequenceBM] [int] NOT NULL,
				[NumericBM] [int] NOT NULL CONSTRAINT [DF_PageSource_NumericBM]  DEFAULT ((0)),
				[GroupByYN] [bit] NOT NULL CONSTRAINT [DF_SqlSource_Model_FACT_GroupByYN]  DEFAULT ((0)),
				[SourceString] [nvarchar](max) NOT NULL,
				[SourceStringCode] [nvarchar](100) NULL,
				[SelectYN] [bit] NOT NULL CONSTRAINT [DF_SqlSource_Model_FACT_SelectYN]  DEFAULT ((1)),
				[InvalidValues] [nvarchar](255) NULL,
				[SampleValue] [nvarchar](255) NULL,
				[Version] [nvarchar](100) NOT NULL CONSTRAINT [DF_SqlSource_Model_FACT_Version]  DEFAULT (''''),
			 CONSTRAINT [PK_PageSource_1] PRIMARY KEY CLUSTERED 
			(
				[PageID] ASC,
				[ColumnID] ASC,
				[SourceTypeBM] ASC,
				[RevisionBM] ASC,
				[SequenceBM] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
			) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

			ALTER TABLE ' + @pcDrillPage + '.[dbo].[PageSource]  WITH CHECK ADD  CONSTRAINT [FK_PageSource_PageColumn] FOREIGN KEY([ColumnID])
			REFERENCES [dbo].[PageColumn] ([ColumnID])
			
			ALTER TABLE ' + @pcDrillPage + '.[dbo].[PageSource] CHECK CONSTRAINT [FK_PageSource_PageColumn]

			ALTER TABLE ' + @pcDrillPage + '.[dbo].[PageSource]  WITH CHECK ADD  CONSTRAINT [FK_PageSource_PageTable] FOREIGN KEY([PageID])
			REFERENCES [dbo].[Page] ([PageID])

			ALTER TABLE ' + @pcDrillPage + '.[dbo].[PageSource] CHECK CONSTRAINT [FK_PageSource_PageTable]
			'

		IF @Debug <> 0 
			PRINT @SQLStatement 
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'Create table LinkDefinition'
		SET @SQLStatement = '
			CREATE TABLE ' + @pcDrillPage + '.[dbo].[LinkDefinition](
				[StartColumnID] [int] NOT NULL,
				[StartColumnValue] [nvarchar](100) NOT NULL CONSTRAINT [DF_LinkDefinition_StartColumnValue]  DEFAULT (N''@@@@@''),
				[ParameterColumnID] [int] NOT NULL,
				[SelectYN] [bit] NOT NULL CONSTRAINT [DF_LinkDefinition_SelectYN]  DEFAULT ((1)),
				[Version] [nvarchar](100) NOT NULL CONSTRAINT [DF_LinkDefinition_Version]  DEFAULT (''''),
			 CONSTRAINT [PK_LinkDefinition] PRIMARY KEY CLUSTERED 
			(
				[StartColumnID] ASC,
				[StartColumnValue] ASC,
				[ParameterColumnID] ASC
			)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
			) ON [PRIMARY]

			ALTER TABLE ' + @pcDrillPage + '.[dbo].[LinkDefinition]  WITH CHECK ADD  CONSTRAINT [FK_LinkDefinition_PageColumn] FOREIGN KEY([StartColumnID])
			REFERENCES [dbo].[PageColumn] ([ColumnID])

			ALTER TABLE ' + @pcDrillPage + '.[dbo].[LinkDefinition] CHECK CONSTRAINT [FK_LinkDefinition_PageColumn]

			ALTER TABLE ' + @pcDrillPage + '.[dbo].[LinkDefinition]  WITH CHECK ADD  CONSTRAINT [FK_LinkDefinition_PageColumn1] FOREIGN KEY([ParameterColumnID])
			REFERENCES [dbo].[PageColumn] ([ColumnID])
			
			ALTER TABLE ' + @pcDrillPage + '.[dbo].[LinkDefinition] CHECK CONSTRAINT [FK_LinkDefinition_PageColumn1]
			'

		IF @Debug <> 0 PRINT @SQLStatement 
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1
		
	---------------------------
	SET @Step = 'CREATE TABLE TYPE'
	---------------------------
	SET @Step = 'Create table type KeyValuePair'
		SET @SQLStatement = '
		CREATE TYPE [dbo].[KeyValuePair] AS TABLE(
	[Key] [nvarchar](100) NOT NULL,
	[Value] [nvarchar](255) NULL,
	PRIMARY KEY CLUSTERED 
(
	[Key] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)'

		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE TABLE TYPE [dbo].[KeyValuePair] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1




	-------------------------------
	SET @Step = 'CREATE PROCEDURES'
	-------------------------------
	
	SET @Step = 'CREATE PROCEDURE spaDelete_ColumnLink'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Marni Reyes
--- Date:   		2015-12-08
--- Description:	Get the current defined filters for the target link page
--- Changed    	Author     	Description       
--- 
--- *****************************************************

--DROP PROCEDURE [dbo].[spaDelete_ColumnLink]
CREATE PROCEDURE [dbo].[spaDelete_ColumnLink]
(
	--Default parameter
	@UserName	NVARCHAR(50),
	@ColumnID	INT,
	@LinkColumnID	INT,
	@Debug		BIT = 0,
	@SourceTypeBM INT = 1027
)

/*
	EXEC dbo.[spaDelete_ColumnLink] @UserName = ''bengt@jaxit.se'', @Debug = 1
	,@ColumnID = 3,@LinkColumnID = 34
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

DECLARE @SourcePageID INT 
DECLARE	@SequenceBM INT
DECLARE	@Version	NVARCHAR(100)

SELECT
	@SourcePageID = PageID
	,@SequenceBM = SequenceBM
	,@Version = [Version]
FROM [dbo].[PageColumn] PC
WHERE ColumnID = @ColumnID

IF @Debug > 0
BEGIN
SELECT
	@SourcePageID
	,@SequenceBM 
	,@Version
END

IF (@ColumnID != @LinkColumnID)
BEGIN
	IF @Debug > 0
	BEGIN
		SELECT
			*
		FROM [dbo].[PageSource]
		WHERE
			PageID = @SourcePageID
			AND ColumnID = @LinkColumnID
	END

	DELETE FROM [dbo].[PageSource]
	WHERE
		PageID = @SourcePageID
		AND ColumnID = @LinkColumnID
		--AND SequenceBM & @SequenceBM > 0
		--AND SourceTypeBM & @SourceTypeBM > 0 
END

DELETE FROM [dbo].[LinkDefinition]
WHERE
	StartColumnID = @ColumnID
	AND ParameterColumnID = @LinkColumnID
	
UPDATE PC
SET [LinkPageYN] = CASE WHEN LD.ParameterColumnID IS NULL THEN 0 ELSE 1 END
FROM PageColumn PC
LEFT JOIN [dbo].[LinkDefinition] LD
	ON LD.StartColumnID = PC.ColumnID
--WHERE 
--	PC.ColumnID = @ColumnID
	--AND PC.SequenceBM & @SequenceBM > 0


'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaDelete_ColumnLink] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaDelete_Page'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Reyes, Marni DSPanel
--- Date:   		2015-12-16
--- Description:	Get Data for Page(s)
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaDelete_Page]
(
	--Default parameter
	@UserName	nvarchar(50),
	@PageID		INT,
	@Debug		bit = 0
)

/*
	EXEC dbo.spaDelete_Page @UserName = ''bengt@jaxit.se'', @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DELETE LD
FROM [dbo].[PageColumn] PC
INNER JOIN [dbo].[LinkDefinition] LD
	ON LD.StartColumnID = PC.ColumnID
WHERE PC.PageID = @PageID

DELETE LD
FROM [dbo].[PageColumn] PC
INNER JOIN [dbo].[LinkDefinition] LD
	ON LD.ParameterColumnID = PC.ColumnID
WHERE PC.PageID = @PageID

UPDATE PC
SET [LinkPageYN] = CASE WHEN LD.ParameterColumnID IS NULL THEN 0 ELSE 1 END
FROM PageColumn PC
LEFT JOIN [dbo].[LinkDefinition] LD
	ON LD.StartColumnID = PC.ColumnID

DELETE PS
FROM [dbo].[PageColumn] PC
INNER JOIN [dbo].[PageSource] PS
	ON PS.ColumnID = PC.ColumnID
WHERE PC.PageID = @PageID

DELETE PS
FROM [dbo].[PageSource] PS
WHERE PS.PageID = @PageID

DELETE PC
FROM [dbo].[PageColumn] PC
WHERE PC.PageID = @PageID

DELETE P
FROM [dbo].[Page] P
WHERE P.PageID = @PageID





'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaDelete_Page] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaDelete_PageColumn'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Bengt Jax, JaxIT
--- Date:   		2015-11-19
--- Description:	Insert data into PageColumn and PageSource table
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaDelete_PageColumn]
(
	--Default parameter
	@UserName	nvarchar(50),
	--@PageID	int,
	@ColumnID	int,
	@Debug		bit = 0
)

/*
	EXEC dbo.[spaDelete_PageColumn] @UserName = ''bengt@jaxit.se'', @ColumnID = 77, @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

	DELETE [dbo].[LinkDefinition]
	WHERE 
		[StartColumnID] = @ColumnID
		OR [ParameterColumnID] = @ColumnID

	UPDATE PC
	SET [LinkPageYN] = CASE WHEN LD.ParameterColumnID IS NULL THEN 0 ELSE 1 END
	FROM PageColumn PC
	LEFT JOIN [dbo].[LinkDefinition] LD
		ON LD.StartColumnID = PC.ColumnID

	IF EXISTS(
		SELECT
			1
		FROM [dbo].[PageColumn]
		WHERE 
			[ColumnID] = @ColumnID
			AND DefaultYN = 1
	)
	BEGIN
		UPDATE [dbo].[PageColumn]
		SET 
			DeletedYN = 1
			,SelectYN = 0
		WHERE 
			[ColumnID] = @ColumnID
			AND DefaultYN = 1
	END
	ELSE
	BEGIN
		DELETE FROM [dbo].[PageSource]	
		WHERE
			[ColumnID] = @ColumnID

		DELETE FROM [dbo].[PageColumn]
		WHERE
			[ColumnID] = @ColumnID
			AND DefaultYN <> 1
	END







'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaDelete_PageColumn] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaDelete_PageRecordSet'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Reyes, Marni DSPanel
--- Date:   		2015-12-16
--- Description:	Delete Data for Page RecordSet(s)
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaDelete_PageRecordSet]
(
	--Default parameter
	@UserName	nvarchar(50),
	@PageID		INT,
	@SequenceBM		INT,
	@SourceTypeBM		INT,
	@Debug		bit = 0
)

/*
	EXEC dbo.spaDelete_PageRecordSet @UserName = ''bengt@jaxit.se'', @Debug = 1
	,@PageID = 3
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DELETE PS
FROM [dbo].[Page] P
INNER JOIN [dbo].[PageSource] PS
	ON PS.PageID = P.PageID
WHERE
	P.PageID = @PageID
	AND PS.SequenceBM  = @SequenceBM
	AND PS.SourceTypeBM & @SourceTypeBM > 0








'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaDelete_PageRecordSet] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaEncode_URL'
	SET @SQLStatement = ''

		SET @SQLStatement = ' 


-- ****************************************************************************************
-- Author: 		Marni Reyes, DSPanel
-- ****************************************************************************************

CREATE PROCEDURE [dbo].[spaEncode_URL]
(
	--Default parameter
	@UserName	nvarchar(50),
	--@Page		nvarchar(50) = ''Default'',
	--@ResultTypeBM int, --1 = Metadata, 2 = Data, 3 = Metadata & Data
	--@Freetext		nvarchar(MAX) = NULL,
	--@fromExcel		nvarchar(MAX) = NULL,
	@excelParams		nvarchar(MAX) = NULL,
	@Debug		bit = 0
	--@ShowFilterColumnsYN	bit = 0
)
/*
	EXEC [dbo].[spaEncode_URL] @UserName = ''mreyes'',@excelParams = ''[Account].[Account]=[Account].[Account].[Account_L4].%26[4136]&[BusinessProcess].[BusinessProcess]=[BusinessProcess].[BusinessProcess].[BusinessProcess_L1].%26[1]&[CostCenter].[CostCenter]=[CostCenter].[CostCenter].[CostCenter_L1].%26[1]&[Currency].[Currency]=[Currency].[Currency].[Currency_L2].%26[3]&[Entity].[Entity]=[Entity].[Entity].[Entity_L2].%26[14]&[InterCompany].[InterCompany]=[InterCompany].[InterCompany].[InterCompany_L1].%26[1]&[LineItem].[LineItem]=[LineItem].[LineItem].[LineItem_L1].%26[51]&[Measures]=[Measures].[Financials_Value]&[ProductGrCode].[ProductGrCode]=[ProductGrCode].[ProductGrCode].[ProductGrCode_L1].%26[1]&[Scenario].[Scenario]=[Scenario].[Scenario].[Scenario_L2].%26[1]&[Time].[Time]=[Time].[Time].[Year].%26[103]&[TimeDataView].[TimeDataView]=[TimeDataView].[TimeDataView].[TimeDataView_L2].%26[2]&[Version].[Version]=[Version].[Version].[Version_L2].%26[-1]''
*/

' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE @WebServer NVARCHAR(MAX)

SELECT
	@WebServer = web_Server
FROM dbo.SystemParameter

SELECT
	@WebServer + ''?excelParams='' + dbo.fnUrlEncode(@excelParams)




'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaEncode_URL] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_ColumnLink'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Marni Reyes
--- Date:   		2015-12-08
--- Description:	Get the current defined filters for the target link page
--- Changed    	Author     	Description       
--- 
--- *****************************************************

--DROP PROCEDURE [dbo].[spaGet_ColumnLink]
CREATE PROCEDURE [dbo].[spaGet_ColumnLink]
(
	--Default parameter
	@UserName	nvarchar(50),
	@PageID	INT,
	@ColumnID	INT,
	@SequenceBM INT = 1,
	@Debug		BIT = 0
)

/*
	EXEC dbo.[spaGet_ColumnLink] @UserName = ''bengt@jaxit.se''
	, @PageID = 2, @ColumnID = 2, @Debug = 1
	EXEC dbo.[spaGet_ColumnLink] @UserName = ''bengt@jaxit.se''
	, @PageID = 3, @ColumnID = 3, @Debug = 1
	EXEC dbo.[spaGet_ColumnLink] @UserName = ''bengt@jaxit.se''
	, @PageID = 2, @ColumnID = 3, @Debug = 1
	EXEC dbo.[spaGet_ColumnLink] @UserName = ''bengt@jaxit.se''
	, @PageID = 2, @ColumnID = 87, @Debug = 1

*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE @SourcePageID INT 

SELECT
	@SourcePageID = PageID
FROM [dbo].[PageColumn] PC
WHERE ColumnID = @ColumnID


IF OBJECT_ID(N''tempdb..#FilterColumns'') IS NOT NULL
BEGIN
	TRUNCATE TABLE #FilterColumns
	DROP TABLE #FilterColumns
END

CREATE TABLE #FilterColumns
(
	ID INT IDENTITY(1,1) PRIMARY KEY
	,[PageID] INT NOT NULL
	,[ColumnID] INT NOT NULL
	,[ColumnName] NVARCHAR(500) COLLATE DATABASE_DEFAULT
	,[SequenceBM] INT NOT NULL
	,[SortOrder] INT NOT NULL
	,[LinkPageYN] BIT NOT NULL
	,[LinkValue] NVARCHAR(500) COLLATE DATABASE_DEFAULT
	,[SelectYN] BIT NOT NULL
)

INSERT INTO #FilterColumns
(
	[PageID]
	,[ColumnID]
	,[ColumnName]
	,[SequenceBM]
	,[SortOrder]
	,[LinkPageYN]
	,[LinkValue]
	,[SelectYN]
)
SELECT
	PC.[PageID]
	,PC.[ColumnID]
	,PC.[ColumnName]
	,PC.[SequenceBM]
	,PC.[SortOrder]
	,[LinkPageYN] = CASE 
						WHEN LD.ParameterColumnID IS NOT NULL THEN 1
						ELSE 0 
					END
	,[LinkValue] = LD.StartColumnValue
	,[SelectYN] = ISNULL(LD.SelectYN,0)
FROM [dbo].[PageColumn] PC
LEFT JOIN [dbo].[LinkDefinition] LD
	ON LD.ParameterColumnID = PC.ColumnID
	AND LD.StartColumnID = @ColumnID
WHERE
	PC.PageID = @PageID
	AND PC.FilterYN = 1
	AND PC.SelectYN = 1
	AND PC.DeletedYN = 0
	--AND PC.SequenceBM & @SequenceBM > 0

--SELECT * FROM #FilterColumns

SELECT DISTINCT
	--LinkColumnKey = CONVERT(NVARCHAR(100),@SourcePageID) + ''@@@@@'' + CONVERT(NVARCHAR(100),FC.[ColumnID]) + ''@@@@@'' + ISNULL(NULLIF(FC.[LinkValue],''@@@@@''),''''),
	FC.[PageID]
	,[LinkColumnID] = FC.[ColumnID]
	,FC.[ColumnName]
	,FC.[SequenceBM]
	,FC.[SortOrder]
	,FC.[LinkPageYN]
	,[LinkValue] = ISNULL(NULLIF(FC.[LinkValue],''@@@@@''),'''')
	,FC.[SelectYN]
	--,TableSourceString = TS.SourceString
	,ColumnSourceString = CASE WHEN FC.[LinkPageYN] = 1 THEN ISNULL(PS.SourceString,'''') ELSE '''' END
	,ColumnSourceStringCode = CASE WHEN FC.[LinkPageYN] = 1 THEN ISNULL(PS.SourceStringCode,'''') ELSE '''' END
	,SampleValue = ISNULL(PS.SampleValue ,'''')
	,[InvalidValues] = ISNULL(PS.[InvalidValues] ,'''')
FROM #FilterColumns FC
LEFT JOIN [dbo].[PageSource] PS
	ON PS.ColumnID = FC.ColumnID
	AND PS.PageID = @SourcePageID
	AND PS.SequenceBM & @SequenceBM > 0
	--AND PS.ColumnID = @ColumnID
--LEFT JOIN [dbo].[PageSource] TS
--	ON TS.ColumnID = -100
--	AND TS.PageID = @SourcePageID
--	AND TS.SequenceBM & @SequenceBM > 0











'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_ColumnLink] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_CurrencyFormat'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Marni Reyes
--- Date:   		2016-04-26
--- 
--- *****************************************************

--DROP PROCEDURE [dbo].[spaGet_CurrencyFormat]
CREATE PROCEDURE [dbo].[spaGet_CurrencyFormat]
(
	--Default parameter
	@UserName	nvarchar(50),
	@Debug		BIT = 0
)

/*
	EXEC dbo.[spaGet_CurrencyFormat] @UserName = ''bengt@jaxit.se''
	,@Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT FormatID = 0,CurrencyFormat = ''xxxxxxx.xxxx'' UNION
SELECT FormatID = 1,CurrencyFormat = ''x,xxx,xxx.xx (1,234,567,890.12)'' UNION
SELECT FormatID = 2,CurrencyFormat = ''x.xxx.xxx,xx (1.234.567.890,12)'' UNION
SELECT FormatID = 3,CurrencyFormat = ''x.xxx.xxx xx (1.234.567.890 12)'' UNION
SELECT FormatID = 4,CurrencyFormat = ''x xxx xxx.xx (1 234 567 890.12)'' UNION
SELECT FormatID = 5,CurrencyFormat = ''x xxx xxx,xx (1 234 567 890,12)'' UNION
SELECT FormatID = 6,CurrencyFormat = ''x''''xxx''''xxx.xx (1''''234''''567''''890.12)'' UNION
SELECT FormatID = 7,CurrencyFormat = ''x''''xxx''''xxx,xx (1''''234''''567''''890,12)'' 

/*

SELECT 
	1234567890.12345678 -- No Format
	,CONVERT(NVARCHAR(50),CONVERT(MONEY,1234567890.12345678),1) -- x,xxx,xxx.xx
	,REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR(50),CONVERT(MONEY,1234567890.12345678),1),''.'','' ''),'','',''.''),'' '','','') -- x.xxx.xxx,xx
	,REPLACE(REPLACE(CONVERT(NVARCHAR(50),CONVERT(MONEY,1234567890.12345678),1),''.'','' ''),'','',''.'') -- x.xxx.xxx xx
	,REPLACE(CONVERT(NVARCHAR(50),CONVERT(MONEY,1234567890.12345678),1),'','','' '') -- x xxx xxx.xx
	,REPLACE(REPLACE(CONVERT(NVARCHAR(50),CONVERT(MONEY,1234567890.12345678),1),'','','' ''),''.'','','') -- x xxx xxx,xx
	,REPLACE(CONVERT(NVARCHAR(50),CONVERT(MONEY,1234567890.12345678),1),'','','''''''') -- x''xxx''xxx.xx
	,REPLACE(REPLACE(CONVERT(NVARCHAR(50),CONVERT(MONEY,1234567890.12345678),1),'','',''''''''),''.'','','') -- x''xxx''xxx,xx
*/




'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_CurrencyFormat] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_DateFormat'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Marni Reyes
--- Date:   		2016-02-18
--- Description:	Get the current defined filters for the target link page
--- Changed    	Author     	Description       
--- 
--- *****************************************************

--DROP PROCEDURE [dbo].[spaGet_DateFormat]
CREATE PROCEDURE [dbo].[spaGet_DateFormat]
(
	--Default parameter
	@UserName	nvarchar(50),
	@Debug		BIT = 0
)

/*
	EXEC dbo.[spaGet_DateFormat] @UserName = ''bengt@jaxit.se''
	,@Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

DECLARE @Selected int
SELECT @Selected = ISNULL(DateFormat, 23) FROM SystemParameter

SELECT FormatID, DateFormat, Selected = CASE WHEN @Selected = FormatID THEN 1 ELSE 0 END
FROM
(
	SELECT FormatID = 1,DateFormat = ''dd MMM yy'' UNION	-- SELECT REPLACE(CONVERT(NVARCHAR(100),GETDATE(),6),'','','''')
	SELECT FormatID = 2,DateFormat = ''dd MMM yyyy'' UNION	-- SELECT CONVERT(NVARCHAR(100),GETDATE(),106)
	SELECT FormatID = 3,DateFormat = ''dd-MM-yy''  UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 10) 
	SELECT FormatID = 4,DateFormat = ''dd-MM-yyyy'' UNION		-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 110) 
	SELECT FormatID = 5,DateFormat = ''dd.MM.yy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 4) 
	SELECT FormatID = 6,DateFormat = ''dd.MM.yyyy'' UNION		-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 104) 
	SELECT FormatID = 7,DateFormat = ''dd/MM/yy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 11) 
	SELECT FormatID = 8,DateFormat = ''dd/MM/yyyy'' UNION		-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 111) 
	SELECT FormatID = 9,DateFormat = ''ddMMMyy'' UNION	-- SELECT REPLACE(CONVERT(NVARCHAR(100),GETDATE(),6),'' '','''')
	SELECT FormatID = 10,DateFormat = ''ddMMMyyyy'' UNION		-- SELECT REPLACE(CONVERT(NVARCHAR(100),GETDATE(),106),'' '','''')
	SELECT FormatID = 11,DateFormat = ''MM-dd-yy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 10) 
	SELECT FormatID = 12,DateFormat = ''MM-dd-yyyy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 110) 
	SELECT FormatID = 13,DateFormat = ''MM/dd/yy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 1) 
	SELECT FormatID = 14,DateFormat = ''MM/dd/yyyy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 101) 
	SELECT FormatID = 15,DateFormat = ''MMM dd yyyy'' UNION	-- SELECT REPLACE(CONVERT(NVARCHAR(100),GETDATE(),107),'','','''')
	SELECT FormatID = 16,DateFormat = ''MMM dd, yy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 7) 
	SELECT FormatID = 17,DateFormat = ''MMM dd, yyyy'' UNION		-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 107) 
	SELECT FormatID = 18,DateFormat = ''MMMdd,yyyy'' UNION	-- SELECT REPLACE(CONVERT(NVARCHAR(100), GETDATE(), 107),'' '','''')
	SELECT FormatID = 19,DateFormat = ''MMMddyyyy'' UNION		-- SELECT REPLACE(REPLACE(CONVERT(NVARCHAR(100), GETDATE(), 107),'' '',''''),'','','''')
	SELECT FormatID = 20,DateFormat = ''yy.MM.dd'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 2) 
	SELECT FormatID = 21,DateFormat = ''yy/MM/dd'' UNION -- SELECT CONVERT(NVARCHAR(100), GETDATE(), 11) 
	SELECT FormatID = 22,DateFormat = ''yyMMdd'' UNION -- SELECT CONVERT(NVARCHAR(100), GETDATE(), 12)
	SELECT FormatID = 23,DateFormat = ''yyyy-MM-dd'' UNION -- SELECT REPLACE(CONVERT(NVARCHAR(100), GETDATE(), 102),''.'',''-'')
	SELECT FormatID = 24,DateFormat = ''yyyy.MM.dd'' UNION -- SELECT CONVERT(NVARCHAR(100), GETDATE(), 102) 
	SELECT FormatID = 25,DateFormat = ''yyyy/MM/dd'' UNION -- SELECT CONVERT(NVARCHAR(100), GETDATE(), 111)
	SELECT FormatID = 26,DateFormat = ''yyyyMMdd'' -- SELECT CONVERT(NVARCHAR(100), GETDATE(), 112)
) sub
--UNION
--SELECT FormatID = 27,DateFormat = ''MMMyyyy'' UNION
--SELECT FormatID = 28,DateFormat = ''MMM yyyy'' UNION
--SELECT FormatID = 29,DateFormat = ''yyyy MMM''

'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_DateFormat] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_DateFormat_All'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Marni Reyes
--- Date:   		2015-12-08
--- Description:	Get the current defined filters for the target link page
--- Changed    	Author     	Description       
--- 
--- *****************************************************

--DROP PROCEDURE [dbo].[spaGet_DateFormat_All]
CREATE PROCEDURE [dbo].[spaGet_DateFormat_All]
(
	--Default parameter
	@UserName	nvarchar(50),
	@Debug		BIT = 0
)

/*
	EXEC dbo.[spaGet_DateFormat_All] @UserName = ''bengt@jaxit.se''
	,@Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
SELECT FormatID = 1,DateFormat = ''dd MMM yy'' UNION	-- SELECT REPLACE(CONVERT(NVARCHAR(100),GETDATE(),6),'','','''')
SELECT FormatID = 2,DateFormat = ''dd MMM yyyy'' UNION	-- SELECT CONVERT(NVARCHAR(100),GETDATE(),106)
SELECT FormatID = 3,DateFormat = ''dd-MM-yy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 10) 
SELECT FormatID = 4,DateFormat = ''dd-MM-yyyy'' UNION		-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 110) 
SELECT FormatID = 5,DateFormat = ''dd.MM.yy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 4) 
SELECT FormatID = 6,DateFormat = ''dd.MM.yyyy'' UNION		-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 104) 
SELECT FormatID = 7,DateFormat = ''dd/MM/yy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 11) 
SELECT FormatID = 8,DateFormat = ''dd/MM/yyyy'' UNION		-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 111) 
SELECT FormatID = 9,DateFormat = ''ddMMMyy'' UNION	-- SELECT REPLACE(CONVERT(NVARCHAR(100),GETDATE(),6),'' '','''')
SELECT FormatID = 10,DateFormat = ''ddMMMyyyy'' UNION		-- SELECT REPLACE(CONVERT(NVARCHAR(100),GETDATE(),106),'' '','''')
SELECT FormatID = 11,DateFormat = ''MM-dd-yy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 10) 
SELECT FormatID = 12,DateFormat = ''MM-dd-yyyy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 110) 
SELECT FormatID = 13,DateFormat = ''MM/dd/yy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 1) 
SELECT FormatID = 14,DateFormat = ''MM/dd/yyyy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 101) 
SELECT FormatID = 15,DateFormat = ''MMM dd yyyy'' UNION	-- SELECT REPLACE(CONVERT(NVARCHAR(100),GETDATE(),107),'','','''')
SELECT FormatID = 16,DateFormat = ''MMM dd, yy'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 7) 
SELECT FormatID = 17,DateFormat = ''MMM dd, yyyy'' UNION		-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 107) 
SELECT FormatID = 18,DateFormat = ''MMMdd,yyyy'' UNION	-- SELECT REPLACE(CONVERT(NVARCHAR(100), GETDATE(), 107),'' '','''')
SELECT FormatID = 19,DateFormat = ''MMMddyyyy'' UNION		-- SELECT REPLACE(REPLACE(CONVERT(NVARCHAR(100), GETDATE(), 107),'' '',''''),'','','''')
SELECT FormatID = 20,DateFormat = ''yy.MM.dd'' UNION	-- SELECT CONVERT(NVARCHAR(100), GETDATE(), 2) 
SELECT FormatID = 21,DateFormat = ''yy/MM/dd'' UNION -- SELECT CONVERT(NVARCHAR(100), GETDATE(), 11) 
SELECT FormatID = 22,DateFormat = ''yyMMdd'' UNION -- SELECT CONVERT(NVARCHAR(100), GETDATE(), 12)
SELECT FormatID = 23,DateFormat = ''yyyy-MM-dd'' UNION -- SELECT REPLACE(CONVERT(NVARCHAR(100), GETDATE(), 102),''.'',''-'')
SELECT FormatID = 24,DateFormat = ''yyyy.MM.dd'' UNION -- SELECT CONVERT(NVARCHAR(100), GETDATE(), 102) 
SELECT FormatID = 25,DateFormat = ''yyyy/MM/dd'' UNION -- SELECT CONVERT(NVARCHAR(100), GETDATE(), 111)
SELECT FormatID = 26,DateFormat = ''yyyyMMdd'' -- SELECT CONVERT(NVARCHAR(100), GETDATE(), 112)
--UNION
--SELECT FormatID = 27,DateFormat = ''MMMyyyy'' UNION
--SELECT FormatID = 28,DateFormat = ''MMM yyyy'' UNION
--SELECT FormatID = 29,DateFormat = ''yyyy MMM''

'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_DateFormat_All] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_IsInAdminRole'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Bengt Jax, JaxIT
--- Date:   		2015-12-22
--- Description:	Check if user is in admin role
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaGet_IsInAdminRole]
(
	--Default parameter
	@UserName	nvarchar(50),
	@Debug		bit = 0
)

/*
	EXEC dbo.spaGet_IsInAdminRole @UserName = ''dspanel\bengt.jax'', @Debug = 1
	EXEC dbo.spaGet_IsInAdminRole @UserName = ''jaxit\bengt.jax'', @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
	IF EXISTS (SELECT 1 FROM CallistoAppDictionary..ApplicationUsers WHERE WinUser = @UserName AND LicenseUserType = ''Administrator'')
		SELECT CAST(1 as bit)
	ELSE
		SELECT CAST(0 as bit)


'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_IsInAdminRole] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_Page'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Bengt Jax, JaxIT
--- Date:   		2015-11-30
--- Description:	Get Data for Page(s)
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaGet_Page]
(
	--Default parameter
	@UserName	nvarchar(50),
	@Debug		bit = 0
)

/*
	EXEC dbo.spaGet_Page @UserName = ''bengt@jaxit.se'', @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

	SELECT 
		PageID,
		PageCode,
		PageName,
		SelectYN
	FROM Page
	WHERE PageID >= 1

'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_Page] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

SET @Step = 'CREATE PROCEDURE spaGet_Page_14'
	SET @SQLStatement = ''

		SET @SQLStatement = '' +
                        '
CREATE PROCEDURE [dbo].[spaGet_Page_14]
(
	--Default parameter
  @UserName nvarchar(50),
  @PageID int,
  @SequenceBM int = 1,
  @SourceTypeBM int = 1027,
  @RevisionBM int = 1
)

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT
	PC.ColumnID,
	ColumnName,
	SourceString = PS.[SourceString],
	TargetLinks = LD.LinkedTo,
	PC.SortOrder,
	FilterYN,
	PC.SelectYN
FROM
	PageColumn PC
	LEFT JOIN [PageSource] PS ON PS.PageID = PC.PageID AND PS.ColumnID = PC.ColumnID AND PS.SourceTypeBM & @SourceTypeBM > 0 AND PS.RevisionBM & @RevisionBM > 0 AND PS.SequenceBM & @SequenceBM > 0 AND PS.SelectYN <> 0
	LEFT JOIN
		(
		SELECT DISTINCT
			ColumnID = LD.StartColumnID,
			LinkedTo = CASE WHEN MIN(P2.PageName) = MAX(P2.PageName) THEN MAX(P2.PageName) ELSE MIN(P2.PageName) + '', '' + MAX(P2.PageName) END
		FROM
			LinkDefinition LD
			INNER JOIN PageColumn PC1 ON PC1.ColumnID = LD.StartColumnID AND PC1.PageID = @PageID
			INNER JOIN PageColumn PC2 ON PC2.ColumnID = LD.ParameterColumnID
			INNER JOIN [Page] P2 ON P2.PageID = PC2.PageID
		GROUP BY
			LD.StartColumnID
		) LD ON LD.ColumnID = PC.ColumnID
WHERE
	PC.PageID = @PageID AND
	PC.SequenceBM & @SequenceBM > 0
ORDER BY
	PC.SortOrder

'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_Page_14] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1


	SET @Step = 'CREATE PROCEDURE spaGet_PageColumn'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Bengt Jax, JaxIT
--- Date:   		2015-11-19
--- Description:	Get Data for selected PageColumn(s)
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaGet_PageColumn]
(
	--Default parameter
	@UserName	nvarchar(50),
	@PageID		int,
	@Debug		bit = 0,
	@SequenceBM INT = 1 -- 1 first table, 2 is the 2nd table, 4 is the third...
)

/*
	EXEC dbo.spaGet_PageColumn @UserName = ''bengt@jaxit.se'', @PageID = 1, @SequenceBM = 1, @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
	
	SELECT DISTINCT
		ColumnKey = CONVERT(NVARCHAR(MAX),CONVERT(NVARCHAR(100),PC.ColumnID) + ''@@@@@'' + CONVERT(NVARCHAR(100),PC.PageID) + ''@@@@@'' + CONVERT(NVARCHAR(100),PC.SortOrder) + ''@@@@@'' + CONVERT(NVARCHAR(100),PC.FilterYN) + ''@@@@@'' + CONVERT(NVARCHAR(100),PC.SelectYN) + ''@@@@@'' + CONVERT(NVARCHAR(100),PC.SequenceBM)) + ''@@@@@'' + PS.SourceString + ''@@@@@'' + PS.SourceStringCode
		,PC.*
		,PS.SourceString
		,PS.SourceStringCode
		--,[LinkYN] = CAST(CASE WHEN LD.ParameterColumnID IS NOT NULL THEN 1 ELSE 0 END AS BIT)
	FROM [dbo].[PageColumn] PC
	INNER JOIN [dbo].[PageSource] PS
		ON PS.PageID = PC.PageID
	--LEFT JOIN [dbo].[LinkDefinition] LD
	--	ON LD.StartColumnID = PC.ColumnID
	WHERE 
		PC.PageID = @PageID
		AND PC.SequenceBM & @SequenceBM > 0
		AND PC.DeletedYN <> 1
		AND PS.SequenceBM & @SequenceBM > 0
		AND PS.ColumnID = -100
	ORDER BY SortOrder

'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_PageColumn] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_PageColumn_All'
	SET @SQLStatement = ''

			SET @SQLStatement = @SQLStatement + '--- *****************************************************
--- Author: 		Reyes, Marni DSPanel
--- Date:   		2015-12-16
--- Description:	Get columns available to be used for PageColumn and PageSource table
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaGet_PageColumn_All]
(
	--Default parameter
	@UserName	nvarchar(50),
	--@PageID	int,
	@ColumnID	int,
	@Debug		bit = 0
)

/*
	EXEC dbo.[spaGet_PageColumn_All] @UserName = ''bengt@jaxit.se''
	, @ColumnID = 68, @Debug = 1


*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE @PageID	INT
DECLARE @SequenceBM	INT
DECLARE @pcDataDBName NVARCHAR(500)
DECLARE @pcDataOwnerName NVARCHAR(500)
DECLARE @SourceDBDBName NVARCHAR(500)
DECLARE @SourceDBOwnerName NVARCHAR(500)
DECLARE @SourceString nvarchar(50)
DECLARE @TableCount	INT
DECLARE @TableLoop	INT
DECLARE @CreateTables1 NVARCHAR(MAX)
DECLARE @CreateTables2 NVARCHAR(MAX)
DECLARE @SQLRun NVARCHAR(MAX)
DECLARE @SQLRun2 NVARCHAR(MAX)

SELECT
	@PageID = PageID
	,@SequenceBM = SequenceBM
FROM [dbo].[PageColumn]
WHERE ColumnID = @ColumnID

IF (@Debug > 0)
BEGIN
	SELECT
		PageID
		,ColumnName
		,SequenceBM
	FROM [dbo].[PageColumn]
	WHERE ColumnID = @ColumnID
END
	

IF OBJECT_ID(N''tempdb..#SourceStrings'') IS NOT NULL
BEGIN
	TRUNCATE TABLE #SourceStrings
	DROP TABLE #SourceStrings
END

SELECT DISTINCT
	ID = IDENTITY(INT,1,1)
	,SourceString = SourceString COLLATE DATABASE_DEFAULT
INTO #SourceStrings
FROM [dbo].[PageSource]
WHERE 
	PageID = @PageID
	AND SequenceBM & @SequenceBM > 0
	AND ColumnID = -100

SELECT
	@pcDataDBName = [pcData_DBName]
	,@pcDataOwnerName = [pcData_OwnerName]
	,@SourceDBDBName = [sourceDB_DBName]
	,@SourceDBOwnerName = [sourceDB_OwnerName]
FROM [dbo].[SystemParameter]


IF (@Debug > 0)
BEGIN
	SELECT
		''#SourceStrings''
	SELECT
		''#SourceStrings''
		,*
	FROM #SourceStrings
END

SET @CreateTables1 = ''
	DECLARE @SQLRunData NVARCHAR(MAX)

	IF OBJECT_ID(N''''tempdb..#Tables'''') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #Tables
		DROP TABLE #Tables
	END

	SELECT DISTINCT
		ID = ROW_NUMBER() OVER(ORDER BY CHARINDEX(TABLE_SCHEMA + ''''.'''' + TABLE_NAME,SS.SourceString))
		,TableID = DENSE_RANK() OVER(ORDER BY CHARINDEX(TABLE_SCHEMA + ''''.'''' + TABLE_NAME,SS.SourceString))
		,TABLE_CATALOG
		,TABLE_SCHEMA
		,TABLE_NAME
		,COLUMN_NAME
		,DATA_TYPE
	INTO #Tables
	FROM (
		SELECT DISTINCT
			TABLE_CATALOG = TABLE_CATALOG COLLATE DATABASE_DEFAULT
			,TABLE_SCHEMA = TABLE_SCHEMA COLLATE DATABASE_DEFAULT
			,TABLE_NAME = TABLE_NAME COLLATE DATABASE_DEFAULT
			,COLUMN_NAME = COLUMN_NAME COLLATE DATABASE_DEFAULT
			,DATA_TYPE = DATA_TYPE COLLATE DATABASE_DEFAULT
			,SourceString = SourceString COLLATE DATABASE_DEFAULT
		FROM '' + CASE WHEN NULLIF(@pcDataDBName,'''') IS NULL THEN '''' ELSE @pcDataDBName + ''.'' END + ''INFORMATION_SCHEMA.COLUMNS ISC
		INNER JOIN #SourceStrings SS
			ON (
				SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%'''' + TABLE_SCHEMA + ''''.'''' + TABLE_NAME + ''''%''''
				OR SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%\['''' + TABLE_SCHEMA + ''''].'''' + TABLE_NAME + ''''%'''' ESCAPE ''''\''''
				OR SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%'''' + TABLE_SCHEMA + ''''.\['''' + TABLE_NAME + '''']%'''' ESCAPE ''''\''''
				OR SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%\['''' + TABLE_SCHEMA + ''''].\['''' + TABLE_NAME + '''']%'''' ESCAPE ''''\''''
			)
			
		WHERE 
			UPPER(TABLE_SCHEMA) COLLATE DATABASE_DEFAULT = '''''' + UPPER(@pcDataOwnerName) + ''''''
		UNION
		SELECT DISTINCT
			TABLE_CATALOG = TABLE_CATALOG COLLATE DATABASE_DEFAULT
			,TABLE_SCHEMA = TABLE_SCHEMA COLLATE DATABASE_DEFAULT
			,TABLE_NAME'

			SET @SQLStatement = @SQLStatement + ' = TABLE_NAME COLLATE DATABASE_DEFAULT
			,COLUMN_NAME = COLUMN_NAME COLLATE DATABASE_DEFAULT
			,DATA_TYPE = DATA_TYPE COLLATE DATABASE_DEFAULT
			,SourceString = SourceString COLLATE DATABASE_DEFAULT
		FROM '' + CASE WHEN NULLIF(@SourceDBDBName,'''') IS NULL THEN '''' ELSE @SourceDBDBName + ''.'' END + ''INFORMATION_SCHEMA.COLUMNS ISC
		INNER JOIN #SourceStrings SS
			ON (
				SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%'''' + TABLE_SCHEMA + ''''.'''' + TABLE_NAME + ''''%''''
				OR SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%\['''' + TABLE_SCHEMA + ''''].'''' + TABLE_NAME + ''''%'''' ESCAPE ''''\''''
				OR SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%'''' + TABLE_SCHEMA + ''''.\['''' + TABLE_NAME + '''']%'''' ESCAPE ''''\''''
				OR SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%\['''' + TABLE_SCHEMA + ''''].\['''' + TABLE_NAME + '''']%'''' ESCAPE ''''\''''
			)
		WHERE 
			UPPER(TABLE_SCHEMA) COLLATE DATABASE_DEFAULT = '''''' + UPPER(@SourceDBOwnerName) + ''''''
	) AS SS
''

SET @CreateTables2 = ''
	IF OBJECT_ID(N''''tempdb..#Columns'''') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #Columns
		DROP TABLE #Columns
	END

	SELECT DISTINCT
		ID = IDENTITY(INT,1,1)
		,TABLE_CATALOG
		,TABLE_SCHEMA
		,TABLE_NAME
		,[COLUMN_NAME]
		,SourceString
		,SourceStringCode
	INTO #Columns
	FROM (
		SELECT DISTINCT
			SourceString = COLUMN_NAME
			,SourceStringCode = UPPER(LEFT(TABLE_NAME,1)) + CONVERT(NVARCHAR(5),TableID)
			,TABLE_CATALOG
			,TABLE_SCHEMA
			,TABLE_NAME
			,COLUMN_NAME
			,RK = ROW_NUMBER() OVER(PARTITION BY COLUMN_NAME ORDER BY TableID)
		FROM #Tables T
	) AS C
	WHERE 
		RK = 1
	
	--SELECT * FROM #Columns

	IF OBJECT_ID(N''''tempdb..#ColumnData'''') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #ColumnData
		DROP TABLE #ColumnData
	END

	CREATE TABLE #ColumnData
	(
		ID INT IDENTITY(1,1) PRIMARY KEY
		,SourceString NVARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL 
		,Data NVARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL 
	)
	
	SET @SQLRunData = ''''''''

	SELECT
		@SQLRunData = @SQLRunData + ''''
		INSERT INTO #ColumnData
		(
			SourceString
			,Data
		)
		SELECT TOP 1
			'''''''''''' + REPLACE(SourceString,'''''''''''''''','''''''''''''''''''''''') + ''''''''''''
			,CAST('''' + SourceString + '''' AS VARCHAR(100))
		FROM '''' + TABLE_CATALOG + ''''.'''' + TABLE_SCHEMA + ''''.'''' + TABLE_NAME + '''' '''' + SourceStringCode + ''''
		WHERE '''' + SourceString + '''' IS NOT NULL
		ORDER BY 2 ASC
		''''
	FROM #Columns

	PRINT(@SQLRunData)
	EXEC(@SQLRunData)

	--SELECT * FROM #ColumnData''

SET @SQLRun2 = ''
	SELECT
		ColumnKey = C.SourceString + ''''@@@@@'''' + C.SourceStringCode
		,TableName = C.TABLE_NAME
		,[ColumnName] = C.SourceString
		,C.SourceStringCode
		,SampleData = CD.Data
	FROM #Columns C
	LEFT JOIN #ColumnData CD
		ON CD.SourceString = C.SourceString 
	ORDER BY
		TableName
		,ColumnName

		
	--SELECT * FROM #SourceStrings
	--SELECT * FROM #Tables	

	
''		
		--AND PS.SequenceBM IS NULL

PRINT(@CreateTables1)
PRINT(@CreateTables2)
PRINT(@SQLRun2)

SET @SQLRun = @CreateTables1
SET @SQLRun = @SQLRun + @CreateTables2
SET @SQLRun = @SQLRun + @SQLRun2

EXEC(@SQLRun)



'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_PageColumn_All] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_PageColumn_Available'
	SET @SQLStatement = ''

			SET @SQLStatement = @SQLStatement + '
CREATE PROCEDURE [dbo].[spaGet_PageColumn_Available]
(
	--Default parameter
	@UserName	nvarchar(50),
	@PageID		int,
	@SourceTypeBM	int = 1027,
	@SequenceBM	int = 1, 
	@Debug		bit = 0
)

/*
	EXEC dbo.spaGet_PageColumn_Available 
		@UserName = ''bengt@jaxit.se''
		, @PageID = 122
		,@SourceTypeBM = 1027
		, @Debug = 1
		, @SequenceBM = 1

exec dbo.spaGet_PageColumn_Available @UserName=N''DSPANEL\Marni.F.reyes'',@PageID=42,@SourceTypeBM=1024,@SequenceBM=1
exec dbo.spaGet_PageColumn_Available @UserName=N''DSPANEL\Marni.F.reyes'',@PageID=58,@SourceTypeBM=1024,@SequenceBM=1
exec dbo.spaGet_PageColumn_Available @UserName=N''DSPANEL\Marni.F.reyes'',@PageID=59,@SourceTypeBM=1024,@SequenceBM=1
exec dbo.spaGet_PageColumn_Available @UserName=N''DSPANEL\Marni.F.reyes'',@PageID=8,@SourceTypeBM=1024,@SequenceBM=1

exec dbo.spaGet_PageColumn_Available @UserName=N''DSPANEL\Marni.F.reyes'',@PageID=40,@SourceTypeBM=1024,@SequenceBM=1
exec dbo.spaGet_PageColumn_Available @UserName=N''DSPANEL\Marni.F.reyes'',@PageID=79,@SourceTypeBM=1024,@SequenceBM=0
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

DECLARE @pcDataDBName NVARCHAR(500)
DECLARE @pcDataOwnerName NVARCHAR(500)
DECLARE @SourceDBDBName NVARCHAR(500)
DECLARE @SourceDBOwnerName NVARCHAR(500)
DECLARE @SourceString nvarchar(50)
DECLARE @TableCount	INT
DECLARE @TableLoop	INT
DECLARE @CreateTables1 NVARCHAR(MAX)
DECLARE @CreateTables2 NVARCHAR(MAX)
DECLARE @SQLRun NVARCHAR(MAX)
DECLARE @SQLRun2 NVARCHAR(MAX)

SELECT
	@pcDataDBName = [pcData_DBName]
	,@pcDataOwnerName = [pcData_OwnerName]
	,@SourceDBDBName = [sourceDB_DBName]
	,@SourceDBOwnerName = [sourceDB_OwnerName]
	,@SourceTypeBM = [SourceTypeBM]
FROM [dbo].[SystemParameter]

DECLARE @pcData NVARCHAR(4000)
DECLARE @pcDataOwner NVARCHAR(4000)
DECLARE @DataSource NVARCHAR(4000)
DECLARE @DataSourceOwner NVARCHAR(4000)

SELECT
	@pcData = [pcData_DBName]
    ,@pcDataOwner = [pcData_OwnerName]
    ,@DataSource = [sourceDB_DBName]
    ,@DataSourceOwner = [sourceDB_OwnerName]
FROM [dbo].[SystemParameter]

SET @CreateTables1 = ''
	DECLARE @SQLRunData NVARCHAR(MAX)

	IF OBJECT_ID(N''''tempdb..#SourceStrings'''') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #SourceStrings
		DROP TABLE #SourceStrings
	END

	SELECT DISTINCT
		ID = IDENTITY(INT,1,1)
		,SourceString = SourceString COLLATE DATABASE_DEFAULT
	INTO #SourceStrings
	FROM [dbo].[PageSource]
	WHERE 
		PageID = '' + CONVERT(NVARCHAR(20),@PageID) + ''
		AND ColumnID = -100
		AND (SourceTypeBM & '' + CONVERT(NVARCHAR(20),@SourceTypeBM) + '') > 0
		AND (SequenceBM & '' + CONVERT(NVARCHAR(20),@SequenceBM) + '') > 0

	--SELECT * FROM #SourceStrings

	IF OBJECT_ID(N''''tempdb..#Tables'''') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #Tables
		DROP TABLE #Tables
	END

	SELECT DISTINCT
		ID = ROW_NUMBER() OVER(ORDER BY CHARINDEX(TABLE_SCHEMA + ''''.'''' + TABLE_NAME,SS.SourceString))
		,TableID = DENSE_RANK() OVER(ORDER BY CHARINDEX(TABLE_SCHEMA + ''''.'''' + TABLE_NAME,SS.SourceString))
		,TABLE_CATALOG
		,TABLE_SCHEMA
		,TABLE_NAME
		,COLUMN_NAME
		,DATA_TYPE
	INTO #Tables
	FROM (
		SELECT DISTINCT
			TABLE_CATALOG = TABLE_CATALOG COLLATE DATABASE_DEFAULT
			,TABLE_SCHEMA = TABLE_SCHEMA COLLATE DATABASE_DEFAULT
			,TABLE_NAME = TABLE_NAME COLLATE DATABASE_DEFAULT
			,COLUMN_NAME = COLUMN_NAME COLLATE DATABASE_DEFAULT
			,DATA_TYPE = DATA_TYPE COLLATE DATABASE_DEFAULT
			,SourceString = SourceString COLLATE DATABASE_DEFAULT
		FROM '' + CASE WHEN NULLIF(@pcDataDBName,'''') IS NULL THEN '''' ELSE @pcDataDBName + ''.'' END + ''INFORMATION_SCHEMA.COLUMNS ISC
		INNER JOIN #SourceStrings SS
			ON SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%'''' + TABLE_SCHEMA + ''''.'''' + TABLE_NAME + ''''%'''' ESCAPE ''''\''''
			OR SS.SourceString COLLATE DATABA'

			SET @SQLStatement = @SQLStatement + 'SE_DEFAULT LIKE ''''%\['''' + TABLE_SCHEMA + ''''].'''' + TABLE_NAME + ''''%'''' ESCAPE ''''\''''
			OR SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%'''' + TABLE_SCHEMA + ''''.\['''' + TABLE_NAME + '''']%'''' ESCAPE ''''\''''
			OR SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%\['''' + TABLE_SCHEMA + ''''].\['''' + TABLE_NAME + '''']%'''' ESCAPE ''''\''''
		WHERE 
			UPPER(TABLE_SCHEMA) COLLATE DATABASE_DEFAULT = '''''' + UPPER(@pcDataOwnerName) + ''''''
		UNION
		SELECT DISTINCT
			TABLE_CATALOG = TABLE_CATALOG COLLATE DATABASE_DEFAULT
			,TABLE_SCHEMA = TABLE_SCHEMA COLLATE DATABASE_DEFAULT
			,TABLE_NAME = TABLE_NAME COLLATE DATABASE_DEFAULT
			,COLUMN_NAME = COLUMN_NAME COLLATE DATABASE_DEFAULT
			,DATA_TYPE = DATA_TYPE COLLATE DATABASE_DEFAULT
			,SourceString = SourceString COLLATE DATABASE_DEFAULT
		FROM '' + CASE WHEN NULLIF(@SourceDBDBName,'''') IS NULL THEN '''' ELSE @SourceDBDBName + ''.'' END + ''INFORMATION_SCHEMA.COLUMNS ISC
		INNER JOIN #SourceStrings SS
			ON SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%'''' + TABLE_SCHEMA + ''''.'''' + TABLE_NAME + ''''%'''' ESCAPE ''''\''''
			OR SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%\['''' + TABLE_SCHEMA + ''''].'''' + TABLE_NAME + ''''%'''' ESCAPE ''''\''''
			OR SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%'''' + TABLE_SCHEMA + ''''.\['''' + TABLE_NAME + '''']%'''' ESCAPE ''''\''''
			OR SS.SourceString COLLATE DATABASE_DEFAULT LIKE ''''%\['''' + TABLE_SCHEMA + ''''].\['''' + TABLE_NAME + '''']%'''' ESCAPE ''''\''''
		WHERE 
			UPPER(TABLE_SCHEMA) COLLATE DATABASE_DEFAULT = '''''' + UPPER(@SourceDBOwnerName) + ''''''
	) AS SS
''

SET @CreateTables2 = ''
	IF OBJECT_ID(N''''tempdb..#Columns'''') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #Columns
		DROP TABLE #Columns
	END

	SELECT DISTINCT
		ID = IDENTITY(INT,1,1)
		,TABLE_CATALOG
		,TABLE_SCHEMA
		,TABLE_NAME
		,[ColumnName]
		,[SelectYN]
		,[DefaultYN]
		,NumericBM
		,SourceString 
		,SourceStringCode
		,isAvailable
	INTO #Columns
	FROM (
		SELECT DISTINCT
			SourceString = ISNULL(PS.SourceString,COLUMN_NAME)
			,SourceStringCode = ISNULL(PS.SourceStringCode,UPPER(LEFT(TABLE_NAME,1)) + CONVERT(NVARCHAR(5),TableID))
			,isAvailable = CASE WHEN PS.[ColumnName] IS NULL THEN 1 ELSE 0 END
			,TABLE_CATALOG
			,TABLE_SCHEMA
			,TABLE_NAME
			,[ColumnName] = ISNULL([ColumnName],'''''''')
			,[SelectYN] = ISNULL([SelectYN],'''''''')
			,[DefaultYN] = ISNULL([DefaultYN],'''''''')
			,NumericBM = ISNULL(PS.PCNumericBM,CASE 
					--WHEN PS.SourceString LIKE ''''%+%'''' THEN 0
					WHEN PS.SourceString LIKE ''''%SUBSTRING%(%)%'''' THEN 0
					WHEN PS.SourceString LIKE ''''%CHARINDEX%(%)%'''' THEN 0
					WHEN T.DATA_TYPE IN (''''nvarchar'''',''''varchar'''',''''nchar'''',''''char'''','''''''') THEN 0
					WHEN T.DATA_TYPE IN (''''bit'''') THEN -2
					WHEN T.DATA_TYPE IN (''''date'''',''''datetime'''',''''time'''') THEN -1
					WHEN T.DATA_TYPE IN (''''bigint'''',''''smallint'''',''''int'''') THEN 1
					WHEN T.DATA_TYPE IN (''''decimal'''',''''float'''',''''numeric'''') THEN 2
					ELSE -3
				END)
			,RK = ROW_NUMBER() OVER(PARTITION BY COLUMN_NAME ORDER BY TableID)
		FROM #Tables T
		LEFT JOIN (
			SELECT
				PS1.*
				,PC.[ColumnName]
				,PC.[DefaultYN]
				,PCNumericBM = PC.NumericBM
			FROM [dbo].[PageSource] PS1
			INNER JOIN [dbo].[PageColumn] PC
				ON PC.ColumnID = PS1.ColumnID
			WHERE 
				PS1.PageID = '' + CONVERT(NVARCHAR(20),@PageID) + ''
				AND PS1.ColumnID <> -100
		) AS PS
			ON UPPER(PS.SourceString) LIKE ''''%'''' + UPPER(T.COLUMN_NAME) + ''''%'''' COLLATE SQL_Latin1_General_CP1_CI_AS
	) AS C
	WHERE 
		RK = 1
		AND isAvailable = 1
	
	--SELECT * FROM #Columns

	IF OBJECT_ID(N''''tempdb..#ColumnData'''') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #ColumnData
		DROP TABLE #ColumnData
	END

	CREATE TABLE'

			SET @SQLStatement = @SQLStatement + ' #ColumnData
	(
		ID INT IDENTITY(1,1) PRIMARY KEY
		,SourceString NVARCHAR(255) COLLATE DATABASE_DEFAULT NOT NULL 
		,Data NVARCHAR(MAX) COLLATE DATABASE_DEFAULT NOT NULL 
	)
	
	SET @SQLRunData = ''''''''

	SELECT
		@SQLRunData = @SQLRunData + ''''
		INSERT INTO #ColumnData
		(
			SourceString
			,Data
		)
		SELECT TOP 1
			'''''''''''' + REPLACE(SourceString,'''''''''''''''','''''''''''''''''''''''') + ''''''''''''
			,'''' + CASE WHEN NumericBM = -3 THEN '''''''''''''''''''''''' ELSE ''''CAST('''' + SourceString + '''' AS VARCHAR(100))'''' END + ''''
		FROM '''' + TABLE_CATALOG + ''''.'''' + TABLE_SCHEMA + ''''.'''' + TABLE_NAME + '''' '''' + SourceStringCode + ''''
		WHERE '''' + SourceString + '''' IS NOT NULL
		ORDER BY 2 DESC
		''''
	FROM #Columns

	PRINT(@SQLRunData)
	EXEC(@SQLRunData)

	--SELECT * FROM #ColumnData''

SET @SQLRun2 = ''
	SELECT
		ColumnKey = CAST(TBL.SourceString + ''''@@@@@'''' + ISNULL(PS.SourceStringCode,'''''''') + ''''@@@@@'''' + PC.ColumnName + ''''@@@@@'''' + CAST(PC.NumericBM AS NVARCHAR(10)) + ''''@@@@@'''' + ISNULL(PS.SampleValue,'''''''') + ''''@@@@@'''' + PS.SourceString + ''''@@@@@'''' + ''''1'''' + ''''@@@@@'''' + '''''' + CONVERT(NVARCHAR(20),@PageID) + '''''' + ''''@@@@@'''' + '''''' + CONVERT(NVARCHAR(20),@SourceTypeBM) + '''''' + ''''@@@@@'''' + '''''' + CONVERT(NVARCHAR(20),@SequenceBM) + '''''' AS NVARCHAR(4000))
		,TableName = TBL.SourceString
		,PC.NumericBM
		,PC.ColumnName
		,PS.SourceStringCode
		,SampleData = PS.SampleValue
		,PS.SourceString
	FROM 
	[dbo].[PageColumn] PC
	INNER JOIN [dbo].[PageSource] PS
		ON PS.ColumnID = PC.ColumnID
		AND PS.PageID = PC.PageID
	INNER JOIN [dbo].[PageSource] TBL
		ON TBL.SequenceBM = PS.SequenceBM
		AND PS.PageID = PC.PageID
	WHERE 
		TBL.[PageID] = '' + CONVERT(NVARCHAR(20),@PageID) + ''
		AND PC.[PageID] = '' + CONVERT(NVARCHAR(20),@PageID) + ''
		AND TBL.ColumnID = -100
		AND TBL.SequenceBM = '' + CONVERT(NVARCHAR(20),@SequenceBM) + ''
		AND PC.[DeletedYN] = 1
	UNION
	SELECT
		ColumnKey = CAST(C.TABLE_NAME + ''''@@@@@'''' + ISNULL(C.SourceStringCode,'''''''') + ''''@@@@@'''' + C.SourceString + ''''@@@@@'''' + CAST(C.NumericBM AS NVARCHAR(10)) + ''''@@@@@'''' + ISNULL(CD.Data,'''''''') + ''''@@@@@'''' + C.SourceString + ''''@@@@@'''' + ''''0'''' + ''''@@@@@'''' + '''''' + CONVERT(NVARCHAR(20),@PageID) + '''''' + ''''@@@@@'''' + '''''' + CONVERT(NVARCHAR(20),@SourceTypeBM) + '''''' + ''''@@@@@'''' + '''''' + CONVERT(NVARCHAR(20),@SequenceBM) + '''''' AS NVARCHAR(4000))
		,TableName = C.TABLE_NAME
		,C.NumericBM
		,[ColumnName] = C.SourceString
		,C.SourceStringCode
		,SampleData = CD.Data
		,C.SourceString
	FROM #Columns C
	LEFT JOIN #ColumnData CD
		ON CD.SourceString = C.SourceString 
	ORDER BY
		TableName
		,ColumnName

		
	--SELECT * FROM #SourceStrings
	--SELECT * FROM #Tables	

	
''		
		--AND PS.SequenceBM IS NULL

PRINT(@CreateTables1)
PRINT(@CreateTables2)
PRINT(@SQLRun2)

SET @SQLRun = @CreateTables1
SET @SQLRun = @SQLRun + @CreateTables2
SET @SQLRun = @SQLRun + @SQLRun2

	SET @SQLRun = REPLACE(@SQLRun,''@pcDataOwner'',@pcDataOwner)
	SET @SQLRun = REPLACE(@SQLRun,''@pcData'',@pcData)
	SET @SQLRun = REPLACE(@SQLRun,''@DataSourceOwner'',@DataSourceOwner)
	SET @SQLRun = REPLACE(@SQLRun,''@DataSource'',@DataSource)

EXEC(@SQLRun)

'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_PageColumn_Available] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_PageColumn_Detail'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Marni Reyes, DSPanel
--- Date:   		2015-11-19
--- Description:	Get Data for selected PageColumn(s)
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaGet_PageColumn_Detail]
(
	--Default parameter
	@UserName	nvarchar(50),
	@ColumnID INT,
	@SequenceBM INT,
	@Debug		bit = 0
)

/*
	EXEC dbo.[spaGet_PageColumn_Detail] 
		@UserName = ''bengt@jaxit.se''
		, @ColumnID = 2
		, @SequenceBM = 1
		, @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

	SELECT DISTINCT
		P.PageName
		,PC.*
		,PS.SourceString
		,PS.SourceStringCode
		--,[isLinked] = CAST(CASE WHEN LD.ParameterColumnID IS NOT NULL THEN 1 ELSE 0 END AS BIT)
	FROM PageColumn PC
	INNER JOIN [Page] P
		ON P.PageID = PC.PageID
	INNER JOIN [PageSource] PS
		ON PS.PageID = PC.PageID
	LEFT JOIN [dbo].[LinkDefinition] LD
		ON LD.ParameterColumnID = PC.ColumnID
	WHERE 
		PC.ColumnID = @ColumnID
		AND PC.SequenceBM & @SequenceBM > 0
		AND PC.DeletedYN <> 1
	ORDER BY SortOrder


'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_PageColumn_Detail] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_PageFilters'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Marni Reyes
--- Date:   		2015-12-08
--- Description:	Get the current defined filters for the target link page
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaGet_PageFilters]
(
	--Default parameter
	@UserName	nvarchar(50),
	@PageID	int,
	@ColumnID	int,
	@Debug		bit = 0
)

/*
	EXEC dbo.[spaGet_PageFilters] @UserName = ''bengt@jaxit.se''
	, @PageID = 6, @ColumnID = 46, @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE @SourcePageID INT 

SELECT
	@SourcePageID = PageID
FROM [dbo].[PageColumn] PC
WHERE ColumnID = @ColumnID


IF OBJECT_ID(N''tempdb..#FilterColumns'') IS NOT NULL
BEGIN
	TRUNCATE TABLE #FilterColumns
	DROP TABLE #FilterColumns
END

CREATE TABLE #FilterColumns
(
	ID INT IDENTITY(1,1) PRIMARY KEY
	,[PageID] INT NOT NULL
	,[ColumnID] INT NOT NULL
	,[ColumnName] NVARCHAR(500) COLLATE DATABASE_DEFAULT
	,[SequenceBM] INT NOT NULL
	,[SortOrder] INT NOT NULL
	,[isLinked] BIT NOT NULL
)

INSERT INTO #FilterColumns
(
	[PageID]
	,[ColumnID]
	,[ColumnName]
	,[SequenceBM]
	,[SortOrder]
	,[isLinked]
)
SELECT
	PC.[PageID]
	,PC.[ColumnID]
	,PC.[ColumnName]
	,PC.[SequenceBM]
	,PC.[SortOrder]
	,[isLinked] = CASE WHEN LD.ParameterColumnID IS NOT NULL THEN 1 ELSE 0 END
FROM [dbo].[PageColumn] PC
LEFT JOIN [dbo].[LinkDefinition] LD
	ON LD.ParameterColumnID = PC.ColumnID
	AND LD.StartColumnID = @ColumnID
WHERE
	PC.PageID = @PageID
	AND PC.FilterYN = 1
	AND PC.SelectYN = 1
	AND PC.DeletedYN = 0

SELECT DISTINCT
	LinkColumnKey = CONVERT(NVARCHAR(100),@SourcePageID) + ''@@@@@'' + CONVERT(NVARCHAR(100),FC.[ColumnID])
	,FC.[PageID]
	,FC.[ColumnID]
	,FC.[ColumnName]
	,FC.[SequenceBM]
	,FC.[SortOrder]
	,FC.[isLinked]
	--,TableSourceString = TS.SourceString
	,ColumnSourceString = PS.SourceString
	,PS.SampleValue 
FROM #FilterColumns FC
INNER JOIN [dbo].[PageSource] PS
	ON PS.ColumnID = FC.ColumnID
	AND PS.PageID = FC.PageID
INNER JOIN [dbo].[PageSource] TS
	ON TS.PageID = PS.PageID
	AND TS.ColumnID = -100
WHERE
	FC.SequenceBM & PS.SequenceBM > 0
	AND TS.SequenceBM & PS.SequenceBM > 0











'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_PageFilters] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_PageRecordSet'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Reyes, Marni DSPanel
--- Date:   		2015-12-16
--- Description:	Get Data for Page Record Sets
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaGet_PageRecordSet]
(
	--Default parameter
	@UserName	nvarchar(50),
	@PageID		INT,
	@Debug		bit = 0
)

/*
	EXEC dbo.spaGet_PageRecordSet @UserName = ''bengt@jaxit.se'', @Debug = 1
	,@PageID = 3
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE @Start INT
DECLARE @RecordSets INT

IF OBJECT_ID(N''tempdb..#SequenceBMs'') IS NOT NULL
BEGIN
	TRUNCATE TABLE #SequenceBMs
	DROP TABLE #SequenceBMs
END

CREATE TABLE #SequenceBMs
(
	SequenceBM INT
)

INSERT INTO #SequenceBMs VALUES (1)
INSERT INTO #SequenceBMs VALUES (2)
--INSERT INTO #SequenceBMs VALUES (4)
--INSERT INTO #SequenceBMs VALUES (8)
--INSERT INTO #SequenceBMs VALUES (16)

SELECT
	RecordSet = ''Result Set '' + CONVERT(NVARCHAR(100),RecordSet)
	,SourceString
	,SourceStringCode
	,SequenceBM 
FROM (
	SELECT
		RecordSet = SBM.SequenceBM
		,SourceString = ISNULL(T.SourceString,'''')
		,SourceStringCode = ISNULL(T.SourceStringCode,'''')
		,SequenceBM = SBM.SequenceBM
	FROM #SequenceBMs SBM
	LEFT JOIN (
		SELECT
			PS.SourceString
			,PS.SourceStringCode
			,PS.SequenceBM
		FROM [dbo].[Page] P
		INNER JOIN [dbo].[PageSource] PS
			ON PS.PageID = P.PageID
		WHERE
			PS.ColumnID = -100
			AND P.PageID = @PageID
			AND PS.SequenceBM & (1+2) > 0
		) AS T
		ON SBM.SequenceBM & T.SequenceBM > 0
) AS T
ORDER BY SequenceBM
'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_PageRecordSet] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_PageSequenceBM'
	SET @SQLStatement = ''

		SET @SQLStatement = '
CREATE PROCEDURE [dbo].[spaGet_PageSequenceBM]
(
	--Default parameter
	@UserName	nvarchar(50),
	@PageID		int,
	@Debug		bit = 0
)

/*
	EXEC dbo.spaGet_PageSequenceBM @UserName = ''bengt@jaxit.se'', @PageID = 1, @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

	SELECT DISTINCT 
		PS.SequenceBM,
		SequenceBMName = ''Result Set '' + CAST(CASE WHEN (PS.SequenceBM & 1) > 0 THEN 1
							WHEN (PS.SequenceBM & 2) > 0 THEN 2
							WHEN (PS.SequenceBM & 4) > 0 THEN 3
							WHEN (PS.SequenceBM & 8) > 0 THEN 4
							WHEN (PS.SequenceBM & 16) > 0 THEN 5
						END as nvarchar)
	FROM [dbo].[Page] P
	INNER JOIN [dbo].[PageSource] PS
		ON PS.PageID = P.PageID
	WHERE 
		P.PageID = @PageID
		AND PS.ColumnID = -100
		AND PS.SequenceBM & (1+2+4+8+16) > 0

'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_PageSequenceBM] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_SourceRecordSet_All'
	SET @SQLStatement = ''

			SET @SQLStatement = @SQLStatement + '--- *****************************************************
--- Author: 		Reyes, Marni DSPanel
--- Date:   		2015-12-16
--- Description:	Get Data for all available record sets
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaGet_SourceRecordSet_All]
(
	--Default parameter
	@UserName	nvarchar(50),
	@SourceTypeBM INT,
	@Debug		bit = 0
)

/*
	EXEC dbo.spaGet_SourceRecordSet_All @UserName = ''bengt@jaxit.se'', @Debug = 1,
	@SourceTypeBM = 1024

*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE @pcDataDBName NVARCHAR(500)
DECLARE @pcDataOwnerName NVARCHAR(500)
DECLARE @SourceDBDBName NVARCHAR(500)
DECLARE @SourceDBOwnerName NVARCHAR(500)
DECLARE @CreateTables1 NVARCHAR(MAX)
DECLARE @CreateTables2 NVARCHAR(MAX)
DECLARE @SQLRun NVARCHAR(MAX)

SELECT
	@SourceDBDBName = MAX([SourceDatabase])
	,@SourceDBOwnerName = MAX([Owner])
FROM [pcINTEGRATOR].[dbo].[SourceType] ST
INNER JOIN [pcINTEGRATOR].[dbo].[Source] S
	ON S.SourceTypeID = ST.SourceTypeID
WHERE 
	ST.SourceTypeBM = @SourceTypeBM

SET @CreateTables1 = ''
	IF OBJECT_ID(N''''tempdb..#Tables'''') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #Tables
		DROP TABLE #Tables
	END

	SELECT DISTINCT
		DatabaseName = TABLE_CATALOG
		,OwnerName = TABLE_SCHEMA
		,TableName = TABLE_NAME
		--,COLUMN_NAME
		--,DATA_TYPE
	INTO #Tables
	FROM (
		SELECT DISTINCT
			TABLE_CATALOG
			,TABLE_SCHEMA
			,TABLE_NAME
			,COLUMN_NAME
			,DATA_TYPE
		FROM '' + CASE WHEN NULLIF(@SourceDBDBName,'''') IS NULL THEN '''' ELSE @SourceDBDBName + ''.'' END + ''INFORMATION_SCHEMA.COLUMNS ISC
		WHERE 
			TABLE_SCHEMA = '''''' + @SourceDBOwnerName + ''''''
	) AS SS

	--SELECT DISTINCT
	--	* 
	--FROM #Tables
''
SET @CreateTables2 = ''
	DECLARE @Start INT
	DECLARE @End INT
	DECLARE @TableName NVARCHAR(500)
	DECLARE @PrimaryKeys NVARCHAR(500)

	
	IF OBJECT_ID(N''''tempdb..#TablePrimaryKeys'''') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #TablePrimaryKeys
		DROP TABLE #TablePrimaryKeys
	END
	CREATE TABLE #TablePrimaryKeys
	(
		TableName NVARCHAR(500) COLLATE DATABASE_DEFAULT,
		PrimaryKeys NVARCHAR(MAX) COLLATE DATABASE_DEFAULT
	)

	IF OBJECT_ID(N''''tempdb..#PrimaryKeys'''') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #PrimaryKeys
		DROP TABLE #PrimaryKeys
	END

	SELECT DISTINCT
		ID = DENSE_RANK() OVER(ORDER BY TABLE_NAME)
		,TableName = TABLE_NAME
		,ColumnName = COLUMN_NAME
	INTO #PrimaryKeys
	FROM (
		SELECT DISTINCT
			TC.TABLE_CATALOG
			,TC.TABLE_NAME
			,CU.COLUMN_NAME
		FROM '' + CASE WHEN NULLIF(@SourceDBDBName,'''') IS NULL THEN '''' ELSE @SourceDBDBName + ''.'' END + ''INFORMATION_SCHEMA.TABLE_CONSTRAINTS TC
		INNER JOIN '' + CASE WHEN NULLIF(@SourceDBDBName,'''') IS NULL THEN '''' ELSE @SourceDBDBName + ''.'' END + ''INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE CU
			ON CU.CONSTRAINT_NAME = TC.CONSTRAINT_NAME
			AND CU.TABLE_NAME = TC.TABLE_NAME
			AND TC.CONSTRAINT_TYPE = ''''PRIMARY KEY''''
		WHERE 
			TC.TABLE_SCHEMA = '''''' + @SourceDBOwnerName + ''''''
	) AS SS

	--SELECT 
	--	* 
	--FROM #PrimaryKeys
	--ORDER BY 2

	SELECT
		@Start = 1
		,@End = MAX(ID)
	FROM #PrimaryKeys 

	WHILE (@Start < (@End + 1))
	BEGIN
		SET @PrimaryKeys = ''''''''

		SELECT
			@TableName = TableName
			,@PrimaryKeys = @PrimaryKeys + ColumnName + '''',''''
		FROM #PrimaryKeys 
		WHERE ID = @Start
		ORDER BY ColumnName

		SET @PrimaryKeys = LEFT(@PrimaryKeys,LEN(@PrimaryKeys) - 1)
		
		--SELECT
		--	@TableName
		--	,@PrimaryKeys

		INSERT INTO #TablePrimaryKeys
		(
			TableName
			,PrimaryKeys
		)
		SELECT
			@TableName
			,@PrimaryKeys

		SET @Start = @Start + 1
	END
	
	--SELECT
	--	*
	--FROM #TablePrimaryKeys

	SELECT
		TableKey = T.DatabaseNam'

			SET @SQLStatement = @SQLStatement + 'e + ''''.'''' + T.OwnerName + ''''.'''' + T.TableName + ''''@@@@@'''' + LEFT(T.TableName,1) + ''''1''''
		,T.*
		,SourceStringCode = LEFT(T.TableName,1) + ''''1''''
		,TPK.PrimaryKeys
	FROM #Tables T
	INNER JOIN #TablePrimaryKeys TPK
		ON TPK.TableName = T.TableName
	ORDER BY 1,3
''
		
PRINT(@CreateTables1)
PRINT(@CreateTables2)

SET @SQLRun = @CreateTables1 + @CreateTables2

EXEC(@SQLRun)









'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_SourceRecordSet_All] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaGet_SourceTypeBM'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Bengt Jax, JaxIT
--- Date:   		2015-11-30
--- Description:	Get Data for source types
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaGet_SourceTypeBM]
(
	--Default parameter
	@UserName	nvarchar(50),
	@Debug		bit = 0
)

/*
	EXEC dbo.spaGet_SourceTypeBM @UserName = ''bengt@jaxit.se'', @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

	SELECT DISTINCT
		SourceTypeBM = st.SourceTypeBM,
		SourceTypeBMName = st.SourceTypeDescription
	FROM pcINTEGRATOR..Source s
	INNER JOIN pcINTEGRATOR..SourceType st ON
		st.SourceTypeID = s.SourceTypeID
	WHERE s.SelectYN <> 0 AND SourceID > 0









'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaGet_SourceTypeBM] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaInsert_ColumnLink'
	SET @SQLStatement = ''

			SET @SQLStatement = @SQLStatement + '--- *****************************************************
--- Author: 		Reyes, Marni DSPanel
--- Date:   		2015-12-16
--- Description:	Get the current defined filters for the target link page
--- Changed    	Author     	Description       
--- 
--- *****************************************************

--DROP PROCEDURE [dbo].[spaInsert_ColumnLink]
CREATE PROCEDURE [dbo].[spaInsert_ColumnLink]
(
	--Default parameter
	@UserName	NVARCHAR(50),
	@ColumnID	INT,
	@ColumnKey	NVARCHAR(500),
	@LinkColumnID	INT,
	@Debug		BIT = 0
)

/*
	EXEC dbo.[spaInsert_ColumnLink] @UserName = ''bengt@jaxit.se'', @Debug = 1,
	@ColumnID = 27, @ColumnName = ''Company'', @LinkColumnID = 34, @SourceStringCode = ''I1''
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

DECLARE @SourcePageID INT 
DECLARE @SourceTypeBM INT 
DECLARE	@SequenceBM INT
DECLARE	@Version	NVARCHAR(100)

	DECLARE @start INT, @end INT , @AndCount INT
    SELECT @start = 1, @end = CHARINDEX(''@@@@@'', @ColumnKey) 

    DECLARE @TableName NVARCHAR(4000)
    DECLARE @ColumnName NVARCHAR(4000)
    DECLARE @SourceStringCode NVARCHAR(4000)

	SET @AndCount = 1

	WHILE @start < LEN(@ColumnKey) + 1 BEGIN 
		IF @end = 0  
			SET @end = LEN(@ColumnKey) + 1
		
		IF @AndCount = 1
		BEGIN
			SET @ColumnName = SUBSTRING(@ColumnKey, @start, @end - @start)
		END
		
		IF @AndCount = 2
		BEGIN
			SET @SourceStringCode = SUBSTRING(@ColumnKey, @start, @end - @start)
		END
		
		SET @start = @end + 5
		SET @end = CHARINDEX(''@@@@@'', @ColumnKey, @start)
        SET @AndCount = @AndCount + 1

    END 
	
SELECT
	@SourcePageID = PageID
	,@SequenceBM = SequenceBM
	,@Version = [Version]
FROM [dbo].[PageColumn] PC
WHERE ColumnID = @ColumnID

SELECT
	@SourceTypeBM = SourceTypeBM
FROM [dbo].[PageSource]
WHERE
	PageID = @SourcePageID
	AND SequenceBM & @SequenceBM > 0
	AND ColumnID = -100

--IF EXISTS (
IF NOT EXISTS (
	SELECT
		1
	FROM [dbo].[LinkDefinition]
	WHERE
		StartColumnID = @ColumnID
		AND ParameterColumnID = @LinkColumnID
	--UNION
	--SELECT
	--	1
	--FROM [dbo].[PageSource]
	--WHERE
	--	PageID = @SourcePageID
	--	AND ColumnID = @ColumnID
)
BEGIN
	INSERT INTO [dbo].[LinkDefinition]
	(
		[StartColumnID]
		,[StartColumnValue]
		,[ParameterColumnID]
		,[SelectYN]
		,[Version]
	)
  	SELECT
		[StartColumnID] = @ColumnID
		,[StartColumnValue] = ''@@@@@''
		,[ParameterColumnID] = @LinkColumnID
		,[SelectYN] = 1
		,[Version] = @Version


IF @Debug > 0
BEGIN
	SELECT DISTINCT
		[Comment] = ''Page '' + [P].[PageCode] + '', '' + [PCLink].[ColumnName] + '', (Sequence '' + CONVERT(NVARCHAR(100),@SequenceBM) + ''), Linked to '' + [PLink].[PageCode] + '', E10''
		,[PageID] = [P].[PageID]
		,[ColumnID] = [PCLink].[ColumnID]
		,[SourceTypeBM] = @SourceTypeBM
		,[RevisionBM] = 1
		,[SequenceBM] = @SequenceBM
		,[NumericBM] = [PCLink].[NumericBM]
		,[GroupByYN] = 0
		,[SourceString] = @ColumnName
		,[SourceStringCode] = @SourceStringCode
		,[SelectYN] = 1
		,[Version] = @Version
		,[InvalidValues] = ''''
	FROM [dbo].[Page] [P]
	INNER JOIN [dbo].[PageColumn] [PC]
	  ON [PC].[PageID] = [P].[PageID]
	INNER JOIN [dbo].[LinkDefinition] [LD]
	  ON [LD].[StartColumnID] = [PC].[ColumnID]
	INNER JOIN [dbo].[PageColumn] [PCLink]
	  ON [PCLink].[ColumnID] = [LD].[ParameterColumnID]
	INNER JOIN [dbo].[Page] [PLink]
	  ON [PLink].[PageID] = [PCLink].[PageID]
	WHERE 
		[P].[PageID] = @SourcePageID
		AND [PC].[ColumnID] = @ColumnID
		AND [LD].[ParameterColumnID] = @LinkColumnID
		AND [P].[PageID] <> [PLink].[PageID]
END

INSERT INTO [dbo].[PageSource]
	(
		[Comment]
		,[PageID]
		,[ColumnID]
		,[SourceTypeBM]
		,[RevisionBM]
		,[SequenceBM]
		,[NumericBM]
		,[GroupByYN]
		,[SourceString]
		,[SourceStringCode]
		,[SelectYN]
		,[Version]'

			SET @SQLStatement = @SQLStatement + '
		,[InvalidValues]
	)
	SELECT DISTINCT
		[Comment] = ''Page '' + [P].[PageCode] + '', '' + [PCLink].[ColumnName] + '', (Sequence '' + CONVERT(NVARCHAR(100),@SequenceBM) + ''), Linked to '' + [PLink].[PageCode] + '', E10''
		,[PageID] = [P].[PageID]
		,[ColumnID] = [PCLink].[ColumnID]
		,[SourceTypeBM] = @SourceTypeBM
		,[RevisionBM] = 1
		,[SequenceBM] = @SequenceBM
		,[NumericBM] = [PCLink].[NumericBM]
		,[GroupByYN] = 0
		,[SourceString] = @ColumnName
		,[SourceStringCode] = @SourceStringCode
		,[SelectYN] = 1
		,[Version] = @Version
		,[InvalidValues] = ''''''''''''
	FROM [dbo].[Page] [P]
	INNER JOIN [dbo].[PageColumn] [PC]
	  ON [PC].[PageID] = [P].[PageID]
	INNER JOIN [dbo].[LinkDefinition] [LD]
	  ON [LD].[StartColumnID] = [PC].[ColumnID]
	INNER JOIN [dbo].[PageColumn] [PCLink]
	  ON [PCLink].[ColumnID] = [LD].[ParameterColumnID]
	INNER JOIN [dbo].[Page] [PLink]
	  ON [PLink].[PageID] = [PCLink].[PageID]
	WHERE 
		[P].[PageID] = @SourcePageID
		AND [PC].[ColumnID] = @ColumnID
		AND [LD].[ParameterColumnID] = @LinkColumnID
		AND [P].[PageID] <> [PLink].[PageID]

	UPDATE [PC]
	SET [LinkPageYN] = 1
	FROM [dbo].[PageColumn] [PC]
	WHERE [PC].[ColumnID] = @ColumnID
END
ELSE
BEGIN
	RAISERROR (''Please check LinkDefinition and PageSource Tables'', -- Message text.
               16, -- Severity.
               1 -- State.
               );
END


'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaInsert_ColumnLink] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaInsert_Page'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Reyes, Marni DSPanel
--- Date:   		2015-12-16s
--- Description:	Get Data for Page(s)
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaInsert_Page]
(
	--Default parameter
	@UserName	nvarchar(50),
	@PageCode		nvarchar(255),
	@PageName		nvarchar(255),
	@Version		nvarchar(255) = '''',
	@Debug		bit = 0
)

/*
	EXEC dbo.spaInsert_Page @UserName = ''bengt@jaxit.se'', @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
	INSERT INTO [dbo].[Page]
	(
		[PageCode]
		,[PageName]
		,[SelectYN]
		,[Version]
	)
	SELECT
		[PageCode] = @PageCode
		,[PageName] = @PageName
		,[SelectYN] = 1
		,[Version] = @Version









'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaInsert_Page] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaInsert_PageColumn'
	SET @SQLStatement = ''

			SET @SQLStatement = @SQLStatement + '--- *****************************************************
--- Author: 		Bengt Jax, JaxIT
--- Date:   		2015-11-19
--- Description:	Insert data into PageColumn and PageSource table
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaInsert_PageColumn]
(
	--Default parameter
	@UserName	nvarchar(50),
	@ColumnKey  nvarchar(4000),
	@Debug		bit = 0,
	@Version nvarchar(50) = ''''
)

/*
	EXEC dbo.spaInsert_PageColumn @UserName=N''DSPANEL\Marni.F.reyes''
	,@ColumnKey=N''CurrExRate@@@@@C1@@@@@SourceCurrCode@@@@@0@@@@@YEN@@@@@SourceCurrCode@@@@@0@@@@@8@@@@@1024@@@@@1''
	, @Debug = 1

	exec dbo.spaInsert_PageColumn @UserName=N''DSPANEL\marni.f.reyes'',@ColumnKey=N''CurrExRate@@@@@C1@@@@@CurrentRate@@@@@1@@@@@9.500000@@@@@CurrentRate@@@@@0@@@@@7@@@@@1024@@@@@129''
	, @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
	
	DECLARE @start INT, @end INT , @AndCount INT, @PageID INT,@SequenceBM INT,@SourceTypeBM INT
    DECLARE @ReturnString NVARCHAR(MAX)
    SELECT @start = 1, @end = CHARINDEX(''@@@@@'', @ColumnKey) 

    DECLARE @TableName NVARCHAR(4000)
    DECLARE @SourceString NVARCHAR(4000)
    DECLARE @ColumnName NVARCHAR(4000)
    DECLARE @ColumnCode NVARCHAR(4000)
    DECLARE @NumericBM INT
    DECLARE @DefaultYN INT
    DECLARE @SampleData NVARCHAR(4000)
    DECLARE @SortOrder INT
    DECLARE @ColumnID INT

	SET @AndCount = 1

--BEGIN TRY

	WHILE @start < LEN(@ColumnKey) + 1 BEGIN 
		IF @end = 0  
			SET @end = LEN(@ColumnKey) + 1
		
		IF @AndCount = 1
		BEGIN
			SET @TableName = SUBSTRING(@ColumnKey, @start, @end - @start)
		END
		
		IF @AndCount = 2
		BEGIN
			SET @ColumnCode = SUBSTRING(@ColumnKey, @start, @end - @start)
		END
		
		IF @AndCount = 3
		BEGIN
			SET @ColumnName = SUBSTRING(@ColumnKey, @start, @end - @start)
		END

		IF @AndCount = 4
		BEGIN
			SET @NumericBM = CAST(SUBSTRING(@ColumnKey, @start, @end - @start) AS INT)
		END

		IF @AndCount = 5
		BEGIN
			SET @SampleData = SUBSTRING(@ColumnKey, @start, @end - @start)
		END

		IF @AndCount = 6
		BEGIN
			SET @SourceString = SUBSTRING(@ColumnKey, @start, @end - @start)
		END
		
		IF @AndCount = 7
		BEGIN
			SET @DefaultYN = SUBSTRING(@ColumnKey, @start, @end - @start)
		END
		
		IF @AndCount = 8
		BEGIN
			SET @PageID = SUBSTRING(@ColumnKey, @start, @end - @start)
		END

		IF @AndCount = 9
		BEGIN
			SET @SourceTypeBM = SUBSTRING(@ColumnKey, @start, @end - @start)
		END

		IF @AndCount = 10
		BEGIN
			SET @SequenceBM = SUBSTRING(@ColumnKey, @start, @end - @start)
		END

		SET @start = @end + 5
		SET @end = CHARINDEX(''@@@@@'', @ColumnKey, @start)
        SET @AndCount = @AndCount + 1

    END 
	
	SELECT 
		TableName = @TableName
		,ColumnCode = @ColumnCode
		,ColumnName = ISNULL(NULLIF(@ColumnName,''''),@SourceString)
		,NumericBM = @NumericBM
		,SampleData = @SampleData
		,SourceString = @SourceString
		,DefaultYN = @DefaultYN

	IF @DefaultYN = 1
	BEGIN
		UPDATE [dbo].[PageColumn]
		SET 
			DeletedYN = 0
			,SelectYN = 1
		WHERE 
			DeletedYN = 1
			AND ColumnName = ISNULL(NULLIF(@ColumnName,''''),@SourceString)
			AND PageID = @PageID
			
	END
	ELSE
	BEGIN
		IF NOT EXISTS(
			SELECT
				1
			FROM [dbo].[PageColumn] PC
			INNER JOIN [dbo].[PageSource] PS
				ON PS.PageID = PC.PageID
				AND PC.ColumnID = PS.ColumnID
			WHERE 
				PS.SourceTypeBM & @SourceTypeBM > 0
				AND PC.PageID = @PageID
				AND PC.ColumnName = ISNULL(NULLIF(@ColumnName,''''),@SourceString)
		)
		BEGIN
			
			SELECT
				@SortOrder = MAX(SortOrder) -- calculate for the highest
			FROM [dbo].[PageColumn] 
			WHERE [PageID] = @PageID

			SET @SortOrder = ISNULL(@SortOrder,0)

			INSERT INTO [dbo].[Pag'

			SET @SQLStatement = @SQLStatement + 'eColumn]
			(
				[ColumnName]
				,[PageID]
				,[NumericBM]
				,[SequenceBM]
				,[SortOrder]
				,[LinkPageYN]
				,[FilterYN]
				,[FilterValueMandatoryYN]
				,[SelectYN]
				,[DefaultYN]
				,[Version]
			)
			SELECT
				[ColumnName] = ISNULL(NULLIF(@ColumnName,''''),@SourceString) -- from the selection
				,[PageID] = @PageID -- from the form
				,[NumericBM] = @NumericBM -- from the selection
				,[SequenceBM] = @SequenceBM  -- from the form
				,[SortOrder] = @SortOrder + 10 -- calculate for the highest
				,[LinkPageYN] = 0
				,[FilterYN] = CASE WHEN @SortOrder = 0 THEN 1 ELSE 0 END
				,[FilterValueMandatoryYN] = 0
				,[SelectYN] = 1
				,[DefaultYN] = 0
				,[Version] = @Version

			IF (@Debug <> 0)
			BEGIN
			SELECT DISTINCT
				[Comment] = ''Page '' + [P].[PageCode] + '', '' + [PC].[ColumnName] + '', (Sequence '' + CASE 
																										WHEN @SequenceBM & 1 > 0 THEN ''2''
																										WHEN @SequenceBM & 2 > 0 THEN ''3''
																										WHEN @SequenceBM & 4 > 0 THEN ''4''
																										WHEN @SequenceBM & 8 > 0 THEN ''5''
																										WHEN @SequenceBM & 16 > 0 THEN ''6''
																									END
																								 + '')''
				,[PageID] = [P].[PageID]
				,[ColumnID] = [PC].[ColumnID]
				,[SourceTypeBM] = @SourceTypeBM
				,[RevisionBM] = 1
				,[SequenceBM] = @SequenceBM
				,[NumericBM] = [PC].[NumericBM]
				,[GroupByYN] = 0
				,[SourceString] = @SourceString
				,[SourceStringCode] = NULLIF(@ColumnCode,'''')
				,[SelectYN] = 1
				,[Version] = @Version
				,[InvalidValues] = ''''
				,[SampleValue] = NULLIF(@SampleData,'''')
				,[PC].[ColumnName]
				,[P].[PageCode]
			FROM [dbo].[Page] [P]
			INNER JOIN [dbo].[PageColumn] [PC]
			  ON [PC].[PageID] = [P].[PageID]
			WHERE 
				[P].[PageID] = @PageID
				AND PC.ColumnName = ISNULL(@ColumnName,@SourceString)
				AND PC.[SequenceBM] = @SequenceBM

			END
	
			INSERT INTO [dbo].[PageSource]
			(
				[Comment]
				,[PageID]
				,[ColumnID]
				,[SourceTypeBM]
				,[RevisionBM]
				,[SequenceBM]
				,[NumericBM]
				,[GroupByYN]
				,[SourceString]
				,[SourceStringCode]
				,[SelectYN]
				,[Version]
				,[InvalidValues]
				,[SampleValue]
			)
			SELECT DISTINCT
				[Comment] = ''Page '' + [P].[PageCode] + '', '' + [PC].[ColumnName] + '', (Sequence '' + CASE 
																										WHEN @SequenceBM & 1 > 0 THEN ''2''
																										WHEN @SequenceBM & 2 > 0 THEN ''3''
																										WHEN @SequenceBM & 4 > 0 THEN ''4''
																										WHEN @SequenceBM & 8 > 0 THEN ''5''
																										WHEN @SequenceBM & 16 > 0 THEN ''6''
																									END
																								 + '')''
				,[PageID] = [P].[PageID]
				,[ColumnID] = [PC].[ColumnID]
				,[SourceTypeBM] = @SourceTypeBM
				,[RevisionBM] = 1
				,[SequenceBM] = @SequenceBM
				,[NumericBM] = [PC].[NumericBM]
				,[GroupByYN] = 0
				,[SourceString] = @SourceString
				,[SourceStringCode] = NULLIF(@ColumnCode,'''')
				,[SelectYN] = 1
				,[Version] = @Version
				,[InvalidValues] = ''''
				,[SampleValue] = NULLIF(@SampleData,'''')
			FROM [dbo].[Page] [P]
			INNER JOIN [dbo].[PageColumn] [PC]
			  ON [PC].[PageID] = [P].[PageID]
			WHERE 
				[P].[PageID] = @PageID
				AND PC.ColumnName = ISNULL(@ColumnName,@SourceString)
				AND PC.[SequenceBM] = @SequenceBM
		END

		IF (@SortOrder = 0)
		BEGIN
			SELECT
				@ColumnID = PC.ColumnID
			FROM [dbo].[PageColumn] [PC]
			WHERE 
				PC.ColumnName = ISNULL(@ColumnName,@SourceString)

			INSERT INTO [dbo].[PageSource]
				(
					[Comment]
					,[PageID]
					,[ColumnID]
					,[SourceTypeBM]
					,[RevisionBM]
					,[SequenceBM]
					,[NumericBM]
					,[GroupByYN]
					,[SourceString]
					,[SourceStringCode]
					,[S'

			SET @SQLStatement = @SQLStatement + 'electYN]
					,[Version]
					,[InvalidValues]
					,[SampleValue]
				)
				SELECT DISTINCT
					[Comment] = ''Page '' + [P].[PageCode] + '', FROM, (Sequence 1), Filter (SequenceBM=128)''
					,[PageID] = [P].[PageID]
					,[ColumnID] = [PS].[ColumnID]
					,[PS].[SourceTypeBM]
					,[RevisionBM] = 1
					,[SequenceBM] = 128
					,[PS].[NumericBM]
					,[GroupByYN] = 0
					,[PS].[SourceString]
					,[PS].[SourceStringCode]
					,[SelectYN] = 1
					,[PS].[Version] 
					,[PS].[InvalidValues]
					,[PS].[SampleValue]
				FROM [dbo].[Page] [P]
				INNER JOIN [dbo].[PageColumn] [PC]
				  ON [PC].[PageID] = [P].[PageID]
				INNER JOIN [dbo].[PageSource] [PS]
				  ON [PS].PageID = [PC].PageID
				WHERE 
					[PC].[ColumnID] = @ColumnID
					AND [PS].[ColumnID] = -100
					AND [PS].[SequenceBM] & 1 > 0

			INSERT INTO [dbo].[PageSource]
				(
					[Comment]
					,[PageID]
					,[ColumnID]
					,[SourceTypeBM]
					,[RevisionBM]
					,[SequenceBM]
					,[NumericBM]
					,[GroupByYN]
					,[SourceString]
					,[SourceStringCode]
					,[SelectYN]
					,[Version]
					,[InvalidValues]
					,[SampleValue]
				)
				SELECT DISTINCT
					[Comment] = ''Page '' + [P].[PageCode] + '', '' + [PC].[ColumnName] + '', (Sequence 1), Filter (SequenceBM=128), FilterValue (SequenceBM=32), FilterDescription (SequenceBM=64)''
					,[PageID] = [P].[PageID]
					,[ColumnID] = [PC].[ColumnID]
					,[PS].[SourceTypeBM]
					,[RevisionBM] = 1
					,[SequenceBM] = 224
					,[PS].[NumericBM]
					,[GroupByYN] = 0
					,[PS].[SourceString]
					,[PS].[SourceStringCode]
					,[SelectYN] = 1
					,[PS].[Version] 
					,[PS].[InvalidValues]
					,[PS].[SampleValue]
				FROM [dbo].[Page] [P]
				INNER JOIN [dbo].[PageColumn] [PC]
				  ON [PC].[PageID] = [P].[PageID]
				INNER JOIN [dbo].[PageSource] [PS]
				  ON [PS].PageID = [PC].PageID
				  AND [PS].[ColumnID] = [PC].[ColumnID]
				WHERE 
					[PC].[ColumnID] = @ColumnID
					AND [PS].[SequenceBM] & 1 > 0
		END
	END


--END TRY
--BEGIN CATCH
--	SELECT 
--		Error = ''An Error has occured. Please contact your system administrator.''
--	    ,ERROR_NUMBER() AS ErrorNumber
--        ,ERROR_SEVERITY() AS ErrorSeverity
--        ,ERROR_STATE() AS ErrorState
--        ,ERROR_PROCEDURE() AS ErrorProcedure
--        ,ERROR_LINE() AS ErrorLine
--        ,ERROR_MESSAGE() AS ErrorMessage;
--END CATCH

'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaInsert_PageColumn] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaInsert_PageRecordSet'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Reyes,Marni DSPanel
--- Date:   		2015-12-16
--- Description:	Insert Data for Page RecordSet(s)
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaInsert_PageRecordSet]
(
	--Default parameter
	@UserName	nvarchar(50),
	@PageID		INT,
	@SourceString	nvarchar(500),
	@SourceStringCode	nvarchar(500),
	@SourceTypeBM	INT,
	@SequenceBM INT,
	@Version	nvarchar(500) = '''',
	@Debug		bit = 0
)

/*
	EXEC dbo.spaInsert_PageRecordSet @UserName = ''bengt@jaxit.se'', @Debug = 1
	,@PageID = 3
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

INSERT INTO [dbo].[PageSource]
(
	[Comment]
	,[PageID]
	,[ColumnID]
	,[SourceTypeBM]
	,[RevisionBM]
	,[SequenceBM]
	,[NumericBM]
	,[GroupByYN]
	,[SourceString]
	,[SourceStringCode]
	,[SelectYN]
	,[Version]
	,[InvalidValues]
	,[SampleValue]
)
SELECT
	[Comment] = ''Page Default From, (Sequence '' + CONVERT(NVARCHAR(100),(@SequenceBM * 2)) +''), E10''
	,[PageID] = @PageID
	,[ColumnID] = -100
	,[SourceTypeBM] = @SourceTypeBM
	,[RevisionBM] = 1
	,[SequenceBM] = @SequenceBM
	,[NumericBM] = 0
	,[GroupByYN] = 0
	,[SourceString] = @SourceString
	,[SourceStringCode] = @SourceStringCode
	,[SelectYN] = 1
	,[Version] = @Version
	,[InvalidValues] = ''''
	,[SampleValue] = ''''









'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaInsert_PageRecordSet] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaUpdate_ColumnLink'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Marni Reyes
--- Date:   		2015-12-08
--- Description:	Get the current defined filters for the target link page
--- Changed    	Author     	Description       
--- 
--- *****************************************************

--DROP PROCEDURE [dbo].[spaUpdate_ColumnLink]
CREATE PROCEDURE [dbo].[spaUpdate_ColumnLink]
(
	--Default parameter
	@UserName	NVARCHAR(50),
	@ColumnID	INT,
	@LinkColumnID	INT,
	@LinkValue	NVARCHAR(100),
	@SelectYN	INT,
	@ColumnSourceString	NVARCHAR(MAX) = NULL,
	@InvalidValues	NVARCHAR(255) = NULL,
	@Debug		BIT = 0
)

/*
	EXEC dbo.[spaUpdate_ColumnLink] @UserName = ''bengt@jaxit.se'', @Debug = 1
	,@ColumnID = 27,@LinkColumnID = 34, @LinkValue '''', @SelectYN = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
DECLARE @PageID INT

SELECT
	@PageID = PageID
FROM [dbo].[PageColumn]
WHERE ColumnID = @ColumnID

UPDATE [dbo].[LinkDefinition]
SET
	StartColumnValue = ISNULL(NULLIF(@LinkValue,''''),''@@@@@'')
	,SelectYN = @SelectYN
WHERE
	StartColumnID = @ColumnID
	AND ParameterColumnID = @LinkColumnID

IF (@InvalidValues IS NOT NULL)
BEGIN
	UPDATE [dbo].[PageSource]
	SET [InvalidValues] = ISNULL(@InvalidValues,[InvalidValues])
	WHERE
		PageID = @PageID
		AND ColumnID = @LinkColumnID
END

IF (NULLIF(@ColumnSourceString,'''') IS NOT NULL)
BEGIN
	UPDATE [dbo].[PageSource]
	SET SourceString = ISNULL(@ColumnSourceString,[InvalidValues])
	WHERE
		PageID = @PageID
		AND ColumnID = @LinkColumnID
END


'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaUpdate_ColumnLink] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaUpdate_DateFormat'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Marni Reyes
--- Date:   		2015-12-08
--- Description:	Get the current defined filters for the target link page
--- Changed    	Author     	Description       
--- 
--- *****************************************************

--DROP PROCEDURE [dbo].[spaUpdate_DateFormat]
CREATE PROCEDURE [dbo].[spaUpdate_DateFormat]
(
	--Default parameter
	@UserName	nvarchar(50),
	@FormatID	INT,
	@Debug		BIT = 0
)

/*
	EXEC dbo.[spaUpdate_DateFormat] @UserName = ''bengt@jaxit.se''
	,@@FormatID = 1
	,@Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

	UPDATE [dbo].[SystemParameter]
	SET [DateFormat] = @FormatID










'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaUpdate_DateFormat] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaUpdate_Page'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Reyes, Marni DSPanel
--- Date:   		2015-12-16
--- Description:	Update Data for Page(s)
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaUpdate_Page]
(
	--Default parameter
	@UserName	nvarchar(50),
	@PageID		INT,
	@PageCode		nvarchar(255),
	@PageName		nvarchar(255),
	@SelectYN		bit,
	@Debug		bit = 0
)

/*
	EXEC dbo.spaUpdate_Page @UserName = ''bengt@jaxit.se'', @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
	UPDATE [dbo].[Page]
	SET
		PageCode = @PageCode
		,PageName = @PageName
		,SelectYN = @SelectYN
	WHERE PageID = @PageID









'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaUpdate_Page] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

SET @Step = 'CREATE PROCEDURE spaUpdate_Page_14'
	SET @SQLStatement = ''

		SET @SQLStatement = '

CREATE PROCEDURE [dbo].[spaUpdate_Page_14]
(
	--Default parameter
  @UserName nvarchar(50),
  @ColumnID int,
  @ColumnName nvarchar(50),
  @SourceString nvarchar(max),
  @SortOrder int,
  @FilterYN bit,
  @SelectYN bit,
  @SourceTypeBM int = 1027,
  @RevisionBM int = 1
)

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

  DECLARE @PageID INT
	DECLARE @SequenceBM INT

	SELECT
		@PageID = PageID
		,@SequenceBM = SequenceBM
	FROM dbo.PageColumn pc
	WHERE
		ColumnID = @ColumnID

  UPDATE
    PC
  SET
    ColumnName = @ColumnName,
    SortOrder = @SortOrder,
    FilterYN = @FilterYN,
    SelectYN = @SelectYN
  FROM
    PageColumn PC
  WHERE
    PC.ColumnID = @ColumnID


  UPDATE PS
  SET
    SourceString = @SourceString
  FROM
    [PageSource] PS
  WHERE
    PS.ColumnID = @ColumnID AND
    PS.SourceTypeBM & @SourceTypeBM > 0 AND
	  PS.RevisionBM & 1 > @RevisionBM AND
	  PS.SequenceBM & @SequenceBM > 0

DELETE [dbo].[PageSource]
	WHERE
		ColumnID = @ColumnID
		AND (
			[SequenceBM] & 128 > 0
			OR SequenceBM & 32 > 0
			OR SequenceBM & 64 > 0
		)

	UPDATE PS
	SET
		[SequenceBM] = CASE WHEN @FilterYN = 1 THEN (1+2+4+8+16) ELSE @SequenceBM END
	FROM dbo.[PageSource] PS
	WHERE
		ColumnID = @ColumnID
		AND PageID	= @PageID

	IF (@FilterYN = 1)
	BEGIN

		IF NOT EXISTS (
			SELECT
				1
			FROM [dbo].[PageSource]
			WHERE
				[SequenceBM] & 128 > 0
				AND [ColumnID] = -100

		)
		BEGIN
			INSERT INTO [dbo].[PageSource]
			(
				[Comment]
				,[PageID]
				,[ColumnID]
				,[SourceTypeBM]
				,[RevisionBM]
				,[SequenceBM]
				,[NumericBM]
				,[GroupByYN]
				,[SourceString]
				,[SourceStringCode]
				,[SelectYN]
				,[Version]
				,[InvalidValues]
				,[SampleValue]
			)
			SELECT DISTINCT
				[Comment] = ''Page '' + [P].[PageCode] + '', FROM, (Sequence 1), Filter''
				,[PageID] = [P].[PageID]
				,[ColumnID] = [PS].[ColumnID]
				,[PS].[SourceTypeBM]
				,[RevisionBM] = 1
				,[SequenceBM] = 128
				,[PS].[NumericBM]
				,[GroupByYN] = 0
				,[PS].[SourceString]
				,[PS].[SourceStringCode]
				,[SelectYN] = 1
				,[PS].[Version]
				,[PS].[InvalidValues]
				,[PS].[SampleValue]
			FROM [dbo].[Page] [P]
			INNER JOIN [dbo].[PageColumn] [PC]
			  ON [PC].[PageID] = [P].[PageID]
			INNER JOIN [dbo].[PageSource] [PS]
			  ON [PS].PageID = [PC].PageID
			WHERE
				[PC].[ColumnID] = @ColumnID
				AND [PS].[ColumnID] = -100
				AND [PS].[SequenceBM] & 1 > 0
		END

		INSERT INTO [dbo].[PageSource]
			(
				[Comment]
				,[PageID]
				,[ColumnID]
				,[SourceTypeBM]
				,[RevisionBM]
				,[SequenceBM]
				,[NumericBM]
				,[GroupByYN]
				,[SourceString]
				,[SourceStringCode]
				,[SelectYN]
				,[Version]
				,[InvalidValues]
				,[SampleValue]
			)
			SELECT DISTINCT
				[Comment] = ''Page '' + [P].[PageCode] + '', '' + [PC].[ColumnName] + '', (Sequence 1), Filter''
				,[PageID] = [P].[PageID]
				,[ColumnID] = [PC].[ColumnID]
				,[PS].[SourceTypeBM]
				,[RevisionBM] = 1
				,[SequenceBM] = 128
				,[PS].[NumericBM]
				,[GroupByYN] = 0
				,[PS].[SourceString]
				,[PS].[SourceStringCode]
				,[SelectYN] = 1
				,[PS].[Version]
				,[PS].[InvalidValues]
				,[PS].[SampleValue]
			FROM [dbo].[Page] [P]
			INNER JOIN [dbo].[PageColumn] [PC]
			  ON [PC].[PageID] = [P].[PageID]
			INNER JOIN [dbo].[PageSource] [PS]
			  ON [PS].PageID = [PC].PageID
			  AND [PS].[ColumnID] = [PC].[ColumnID]
			WHERE
				[PC].[ColumnID] = @ColumnID
				AND [PS].[SequenceBM] & 1 > 0

		INSERT INTO [dbo].[PageSource]
			(
				[Comment]
				,[PageID]
				,[ColumnID]
				,[SourceTypeBM]
				,[RevisionBM]
			,[SequenceBM]
				,[NumericBM]
				,[GroupByYN]
				,[SourceString]
				,[SourceStringCode]
				,[SelectYN]
				,[Version]
				,[InvalidValues]
				,[SampleValue]
			)
			SELECT DISTINCT
				[Comment] = ''Page '' + [P].[PageCode] + '', '' + [PC].[ColumnName] + '', (Sequence 1), FilterValue''
				,[PageID] = [P].[PageID]
				,[ColumnID] = [PC].[ColumnID]
				,[PS].[SourceTypeBM]
				,[RevisionBM] = 1
				,[SequenceBM] = 32
				,[PS].[NumericBM]
				,[GroupByYN] = 0
				,[PS].[SourceString]
				,[PS].[SourceStringCode]
				,[SelectYN] = 1
				,[PS].[Version]
				,[PS].[InvalidValues]
				,[PS].[SampleValue]
			FROM [dbo].[Page] [P]
			INNER JOIN [dbo].[PageColumn] [PC]
			  ON [PC].[PageID] = [P].[PageID]
			INNER JOIN [dbo].[PageSource] [PS]
			  ON [PS].PageID = [PC].PageID
			  AND [PS].[ColumnID] = [PC].[ColumnID]
			WHERE
				[PC].[ColumnID] = @ColumnID
				AND [PS].[SequenceBM] & 1 > 0

		INSERT INTO [dbo].[PageSource]
			(
				[Comment]
				,[PageID]
				,[ColumnID]
				,[SourceTypeBM]
				,[RevisionBM]
				,[SequenceBM]
				,[NumericBM]
				,[GroupByYN]
				,[SourceString]
				,[SourceStringCode]
				,[SelectYN]
				,[Version]
				,[InvalidValues]
				,[SampleValue]
			)
			SELECT DISTINCT
				[Comment] = ''Page '' + [P].[PageCode] + '', '' + [PC].[ColumnName] + '', (Sequence 1), FilterDescription''
				,[PageID] = [P].[PageID]
				,[ColumnID] = [PC].[ColumnID]
				,[PS].[SourceTypeBM]
				,[RevisionBM] = 1
				,[SequenceBM] = 64
				,[PS].[NumericBM]
				,[GroupByYN] = 0
				,[PS].[SourceString]
				,[PS].[SourceStringCode]
				,[SelectYN] = 1
				,[PS].[Version]
				,[PS].[InvalidValues]
				,[PS].[SampleValue]
			FROM [dbo].[Page] [P]
			INNER JOIN [dbo].[PageColumn] [PC]
			  ON [PC].[PageID] = [P].[PageID]
			INNER JOIN [dbo].[PageSource] [PS]
			  ON [PS].PageID = [PC].PageID
			  AND [PS].[ColumnID] = [PC].[ColumnID]
			WHERE
				[PC].[ColumnID] = @ColumnID
				AND [PS].[SequenceBM] & 1 > 0
	END

'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaUpdate_Page_14] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaUpdate_PageColumn'
	SET @SQLStatement = ''

			SET @SQLStatement = @SQLStatement + '
--- *****************************************************
--- Author: 		Bengt Jax, JaxIT
--- Date:   		2015-11-19
--- Description:	Update data in PageColumn table
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaUpdate_PageColumn]
(
	--Default parameter
	@UserName	nvarchar(50),
	@ColumnID	INT,
	@ColumnName	nvarchar(255),
	@SortOrder	INT,
	@SelectYN	INT,
	@FilterYN	INT,
	--Add all columns from PageColumn table
	@Debug		bit = 0
)

/*
	EXEC dbo.[spaUpdate_PageColumn] @UserName = ''bengt@jaxit.se''
		, @ColumnID = 1
		, @Debug = 1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

	DECLARE @PageID INT
	DECLARE @SequenceBM INT

	SELECT
		@PageID = PageID
		,@SequenceBM = SequenceBM
	FROM dbo.PageColumn pc 
	WHERE 
		ColumnID = @ColumnID

	UPDATE pc 
	SET
		[SortOrder] = @SortOrder
		,[SelectYN] = @SelectYN
		,[FilterYN] = @FilterYN
		,[ColumnName] = @ColumnName
	FROM dbo.PageColumn pc 
	WHERE 
		ColumnID = @ColumnID

	DELETE [dbo].[PageSource]
	WHERE 
		ColumnID = @ColumnID
		AND (
			[SequenceBM] & 128 > 0
			OR SequenceBM & 32 > 0
			OR SequenceBM & 64 > 0
		)
	
	UPDATE PS 
	SET
		[SequenceBM] = CASE WHEN @FilterYN = 1 THEN (1+2+4+8+16) ELSE @SequenceBM END 
	FROM dbo.[PageSource] PS		
	WHERE 
		ColumnID = @ColumnID
		AND PageID	= @PageID

	IF (@FilterYN = 1)
	BEGIN

		IF NOT EXISTS (
			SELECT
				1
			FROM [dbo].[PageSource]
			WHERE
				[SequenceBM] & 128 > 0
				AND [ColumnID] = -100
				
		)
		BEGIN
			INSERT INTO [dbo].[PageSource]
			(
				[Comment]
				,[PageID]
				,[ColumnID]
				,[SourceTypeBM]
				,[RevisionBM]
				,[SequenceBM]
				,[NumericBM]
				,[GroupByYN]
				,[SourceString]
				,[SourceStringCode]
				,[SelectYN]
				,[Version]
				,[InvalidValues]
				,[SampleValue]
			)
			SELECT DISTINCT
				[Comment] = ''Page '' + [P].[PageCode] + '', FROM, (Sequence 1), Filter''
				,[PageID] = [P].[PageID]
				,[ColumnID] = [PS].[ColumnID]
				,[PS].[SourceTypeBM]
				,[RevisionBM] = 1
				,[SequenceBM] = 128
				,[PS].[NumericBM]
				,[GroupByYN] = 0
				,[PS].[SourceString]
				,[PS].[SourceStringCode]
				,[SelectYN] = 1
				,[PS].[Version] 
				,[PS].[InvalidValues]
				,[PS].[SampleValue]
			FROM [dbo].[Page] [P]
			INNER JOIN [dbo].[PageColumn] [PC]
			  ON [PC].[PageID] = [P].[PageID]
			INNER JOIN [dbo].[PageSource] [PS]
			  ON [PS].PageID = [PC].PageID
			WHERE 
				[PC].[ColumnID] = @ColumnID
				AND [PS].[ColumnID] = -100
				AND [PS].[SequenceBM] & 1 > 0
		END

		INSERT INTO [dbo].[PageSource]
			(
				[Comment]
				,[PageID]
				,[ColumnID]
				,[SourceTypeBM]
				,[RevisionBM]
				,[SequenceBM]
				,[NumericBM]
				,[GroupByYN]
				,[SourceString]
				,[SourceStringCode]
				,[SelectYN]
				,[Version]
				,[InvalidValues]
				,[SampleValue]
			)
			SELECT DISTINCT
				[Comment] = ''Page '' + [P].[PageCode] + '', '' + [PC].[ColumnName] + '', (Sequence 1), Filter''
				,[PageID] = [P].[PageID]
				,[ColumnID] = [PC].[ColumnID]
				,[PS].[SourceTypeBM]
				,[RevisionBM] = 1
				,[SequenceBM] = 128
				,[PS].[NumericBM]
				,[GroupByYN] = 0
				,[PS].[SourceString]
				,[PS].[SourceStringCode]
				,[SelectYN] = 1
				,[PS].[Version] 
				,[PS].[InvalidValues]
				,[PS].[SampleValue]
			FROM [dbo].[Page] [P]
			INNER JOIN [dbo].[PageColumn] [PC]
			  ON [PC].[PageID] = [P].[PageID]
			INNER JOIN [dbo].[PageSource] [PS]
			  ON [PS].PageID = [PC].PageID
			  AND [PS].[ColumnID] = [PC].[ColumnID]
			WHERE 
				[PC].[ColumnID] = @ColumnID
				AND [PS].[SequenceBM] & 1 > 0
				
		INSERT INTO [dbo].[PageSource]
			(
				[Comment]
				,[PageID]
				,[ColumnID]
				,[SourceTypeBM]
				,[RevisionBM]
	'

			SET @SQLStatement = @SQLStatement + '			,[SequenceBM]
				,[NumericBM]
				,[GroupByYN]
				,[SourceString]
				,[SourceStringCode]
				,[SelectYN]
				,[Version]
				,[InvalidValues]
				,[SampleValue]
			)
			SELECT DISTINCT
				[Comment] = ''Page '' + [P].[PageCode] + '', '' + [PC].[ColumnName] + '', (Sequence 1), FilterValue''
				,[PageID] = [P].[PageID]
				,[ColumnID] = [PC].[ColumnID]
				,[PS].[SourceTypeBM]
				,[RevisionBM] = 1
				,[SequenceBM] = 32
				,[PS].[NumericBM]
				,[GroupByYN] = 0
				,[PS].[SourceString]
				,[PS].[SourceStringCode]
				,[SelectYN] = 1
				,[PS].[Version] 
				,[PS].[InvalidValues]
				,[PS].[SampleValue]
			FROM [dbo].[Page] [P]
			INNER JOIN [dbo].[PageColumn] [PC]
			  ON [PC].[PageID] = [P].[PageID]
			INNER JOIN [dbo].[PageSource] [PS]
			  ON [PS].PageID = [PC].PageID
			  AND [PS].[ColumnID] = [PC].[ColumnID]
			WHERE 
				[PC].[ColumnID] = @ColumnID
				AND [PS].[SequenceBM] & 1 > 0

		INSERT INTO [dbo].[PageSource]
			(
				[Comment]
				,[PageID]
				,[ColumnID]
				,[SourceTypeBM]
				,[RevisionBM]
				,[SequenceBM]
				,[NumericBM]
				,[GroupByYN]
				,[SourceString]
				,[SourceStringCode]
				,[SelectYN]
				,[Version]
				,[InvalidValues]
				,[SampleValue]
			)
			SELECT DISTINCT
				[Comment] = ''Page '' + [P].[PageCode] + '', '' + [PC].[ColumnName] + '', (Sequence 1), FilterDescription''
				,[PageID] = [P].[PageID]
				,[ColumnID] = [PC].[ColumnID]
				,[PS].[SourceTypeBM]
				,[RevisionBM] = 1
				,[SequenceBM] = 64
				,[PS].[NumericBM]
				,[GroupByYN] = 0
				,[PS].[SourceString]
				,[PS].[SourceStringCode]
				,[SelectYN] = 1
				,[PS].[Version] 
				,[PS].[InvalidValues]
				,[PS].[SampleValue]
			FROM [dbo].[Page] [P]
			INNER JOIN [dbo].[PageColumn] [PC]
			  ON [PC].[PageID] = [P].[PageID]
			INNER JOIN [dbo].[PageSource] [PS]
			  ON [PS].PageID = [PC].PageID
			  AND [PS].[ColumnID] = [PC].[ColumnID]
			WHERE 
				[PC].[ColumnID] = @ColumnID
				AND [PS].[SequenceBM] & 1 > 0
	END

'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaUpdate_PageColumn] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaUpdate_PageRecordSet'
	SET @SQLStatement = ''

			SET @SQLStatement = @SQLStatement + '--- *****************************************************
--- Author: 		Reyes, Marni DSPanel
--- Date:   		2015-12-16
--- Description:	Update Data for Page RecordSet(s)
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spaUpdate_PageRecordSet]
(
	--Default parameter
	@UserName	nvarchar(50),
	@PageID		INT,
	@SequenceBM		INT,
	@SourceTypeBM		INT,
	@SourceString	nvarchar(500),
	@SourceStringCode	nvarchar(500),
	@Debug		bit = 0
)

/*
	EXEC dbo.spaUpdate_PageRecordSet @UserName = ''bengt@jaxit.se'', @Debug = 1
	,@PageID = 1
	,@SequenceBM = 2
	,@SourceTypeBM = 1
	,@SourceString = ''''
	,@SourceStringCode = ''''
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
DECLARE @Version nvarchar(100)
DECLARE @PageCode nvarchar(100)

SELECT
	@PageCode = P.PageCode
FROM [pcDrillPage].[dbo].[Page] P
WHERE
	P.PageID = @PageID

SET @Version = ''''

IF (@Debug > 0)
BEGIN
	SELECT
		*
	FROM [pcDrillPage].[dbo].[Page] P
	INNER JOIN [pcDrillPage].[dbo].[PageSource] PS
		ON PS.PageID = P.PageID
	WHERE
		PS.ColumnID = -100
		AND P.PageID = @PageID
		AND PS.SequenceBM  = @SequenceBM
		AND PS.SourceTypeBM & @SourceTypeBM > 0
END

IF EXISTS (
	SELECT
		1
	FROM [pcDrillPage].[dbo].[Page] P
	INNER JOIN [pcDrillPage].[dbo].[PageSource] PS
		ON PS.PageID = P.PageID
	WHERE
		PS.ColumnID = -100
		AND P.PageID = @PageID
		AND PS.SequenceBM  = @SequenceBM
		AND PS.SourceTypeBM & @SourceTypeBM > 0
)
BEGIN
	IF (ISNULL(@SourceString,'''') = '''')
	BEGIN
		DELETE PS
		FROM [pcDrillPage].[dbo].[Page] P
		INNER JOIN [pcDrillPage].[dbo].[PageColumn] PC
			ON PC.PageID = P.PageID
		INNER JOIN [pcDrillPage].[dbo].[PageSource] PS
			ON PS.PageID = P.PageID
			AND PS.ColumnID = PC.ColumnID
		WHERE
			P.PageID = @PageID
			AND PS.SequenceBM  = @SequenceBM
			AND PS.SourceTypeBM & @SourceTypeBM > 0

		DELETE PS
		FROM [pcDrillPage].[dbo].[Page] P
		INNER JOIN [pcDrillPage].[dbo].[PageSource] PS
			ON PS.PageID = P.PageID
		WHERE
			PS.ColumnID = -100
			AND P.PageID = @PageID
			AND PS.SequenceBM  = @SequenceBM
			AND PS.SourceTypeBM & @SourceTypeBM > 0
		
		DELETE LD
		FROM [pcDrillPage].[dbo].[PageColumn] PC
		INNER JOIN [dbo].[LinkDefinition] LD
			ON LD.[StartColumnID] = PC.ColumnID
		WHERE
			PC.PageID = @PageID
			AND PC.SequenceBM  = @SequenceBM

		DELETE LD
		FROM [pcDrillPage].[dbo].[PageColumn] PC
		INNER JOIN [dbo].[LinkDefinition] LD
			ON LD.[ParameterColumnID] = PC.ColumnID
		WHERE
			PC.PageID = @PageID
			AND PC.SequenceBM  = @SequenceBM
				
		DELETE PC
		FROM [pcDrillPage].[dbo].[PageColumn] PC
		WHERE
			PC.PageID = @PageID
			AND PC.SequenceBM  = @SequenceBM
	END
	ELSE
	BEGIN
		UPDATE PS
		SET 
			PS.SourceString = @SourceString
			,PS.SourceStringCode = @SourceStringCode
		FROM [pcDrillPage].[dbo].[Page] P
		INNER JOIN [pcDrillPage].[dbo].[PageSource] PS
			ON PS.PageID = P.PageID
		WHERE
			PS.ColumnID = -100
			AND P.PageID = @PageID
			AND PS.SequenceBM  = @SequenceBM
			AND PS.SourceTypeBM & @SourceTypeBM > 0
	END
END
ELSE
BEGIN
	IF (ISNULL(@SourceString,'''') <> '''')
	BEGIN
		INSERT INTO [pcDrillPage].[dbo].[PageSource]
		(
			[Comment]
			,[PageID]
			,[ColumnID]
			,[SourceTypeBM]
			,[RevisionBM]
			,[SequenceBM]
			,[NumericBM]
			,[GroupByYN]
			,[SourceString]
			,[SourceStringCode]
			,[SelectYN]
			,[Version]
			,[InvalidValues]
			,[SampleValue]
		)
		SELECT
			[Comment] = ''Page '' + @PageCode + '' FROM, (Sequence '' + CONVERT(NVARCHAR(100),(@SequenceBM * 2)) +''), E10''
			,[PageID] = @PageID
			,[ColumnID] = -100
			,[SourceTypeBM] = @SourceTypeBM
			,[RevisionBM] = 1
			,[SequenceBM] = @SequenceBM
			,[NumericBM] = 0
			,[GroupByYN] = 0
'

			SET @SQLStatement = @SQLStatement + '			,[SourceString] = @SourceString
			,[SourceStringCode] = @SourceStringCode
			,[SelectYN] = 1
			,[Version] = @Version
			,[InvalidValues] = ''''
			,[SampleValue] = ''''
	END
END'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaUpdate_PageRecordSet] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spaUpdate_SystemDatabases'
	SET @SQLStatement = ''

		SET @SQLStatement = '--- *****************************************************
--- Author: 		Marni Reyes
--- Date:   		2015-12-08
--- Description:	Get the current defined filters for the target link page
--- Changed    	Author     	Description       
--- 
--- *****************************************************

--DROP PROCEDURE [dbo].[spaUpdate_SystemDatabases]
CREATE PROCEDURE [dbo].[spaUpdate_SystemDatabases]
(
	--Default parameter
	@pcData_DBName nvarchar(100),
    @pcData_OwnerName nvarchar(100),
    @sourceDB_DBName nvarchar(100),
    @sourceDB_OwnerName nvarchar(100),
	@Debug		BIT = 0
)

/*
	EXEC dbo.[spaUpdate_SystemDatabases]
		@pcData_DBName = ''pcDATA_DevTestJax''
		,@pcData_OwnerName = ''dbo''
		,@sourceDB_DBName = ''Epicor101''
		,@sourceDB_OwnerName = ''erp''
		,@Debug = 1

DECLARE @pcData_DBName nvarchar(100)
DECLARE @pcData_OwnerName nvarchar(100)
DECLARE @sourceDB_DBName nvarchar(100)
DECLARE @sourceDB_OwnerName nvarchar(100)

SET @pcData_DBName = ''pcDATA_DevTestJax''
SET @pcData_OwnerName = ''dbo''
SET @sourceDB_DBName = ''Epicor101''
SET @sourceDB_OwnerName = ''erp''

UPDATE [dbo].[SystemParameter]
SET 
    [pcData_DBName] = @pcData_DBName
    ,[pcData_OwnerName] = @pcData_OwnerName
    ,[sourceDB_DBName] = @sourceDB_DBName
    ,[sourceDB_OwnerName] = @sourceDB_OwnerName
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
DECLARE @Previous_pcData_DBName nvarchar(100)
DECLARE @Previous_pcData_OwnerName nvarchar(100)
DECLARE @Previous_sourceDB_DBName nvarchar(100)
DECLARE @Previous_sourceDB_OwnerName nvarchar(100)

SELECT 
	@Previous_pcData_DBName = [pcData_DBName]
	,@Previous_pcData_OwnerName = [pcData_OwnerName]
	,@Previous_sourceDB_DBName = [sourceDB_DBName]
	,@Previous_sourceDB_OwnerName = [sourceDB_OwnerName]
FROM [dbo].[SystemParameter]

IF @Debug > 0
BEGIN
	SELECT 
		[Previous_pcData_DBName] = @Previous_pcData_DBName
		,[Previous_pcData_OwnerName] = @Previous_pcData_OwnerName
		,[Previous_sourceDB_DBName] = @Previous_sourceDB_DBName
		,[Previous_sourceDB_OwnerName] = @Previous_sourceDB_OwnerName

	SELECT
		[pcData_DBName] = @pcData_DBName
		,[pcData_OwnerName] = @pcData_OwnerName
		,[sourceDB_DBName] = @sourceDB_DBName
		,[sourceDB_OwnerName] = @sourceDB_OwnerName
END

UPDATE [dbo].[SystemParameter]
SET 
    [pcData_DBName] = @pcData_DBName
    ,[pcData_OwnerName] = @pcData_OwnerName
    ,[sourceDB_DBName] = @sourceDB_DBName
    ,[sourceDB_OwnerName] = @sourceDB_OwnerName
	
UPDATE [dbo].[PageSource]
SET [SourceString] = REPLACE(
						[SourceString]
						,@Previous_pcData_DBName + ''.'' + @Previous_pcData_OwnerName
						,@pcData_DBName + ''.'' + @pcData_OwnerName
						)

UPDATE [dbo].[PageSource]
SET [SourceString] = REPLACE(
						[SourceString]
						,@Previous_sourceDB_DBName + ''.'' + @Previous_sourceDB_OwnerName
						,@sourceDB_DBName + ''.'' + @sourceDB_OwnerName
						)

EXEC dbo.spRunAll_spCreate_PageProcedure







'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spaUpdate_SystemDatabases] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1


	BEGIN
	SET @Step = 'CREATE PROCEDURE spConvert_KeyValuePair' 
	SET @SQLStatement = '
	
--- *****************************************************
--- Author: 		Bengt Jax, JaxIT
--- Date:   		2016-05-03
--- Description:	Convert KeyValuePair to pcDrillPage Url(s)
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spConvert_KeyValuePair]
(
	--Default parameter
	@UserName		nvarchar(50),
	@KeyValuePair	KeyValuePair READONLY,
	@Debug			bit = 0
)

/*
declare @p2 dbo.KeyValuePair
insert into @p2 values(N''[Account].[Account]'',N''[Account].[Account].[Account_L6].&[2770]'')
insert into @p2 values(N''[BusinessProcess].[BusinessProcess]'',N''[BusinessProcess].[BusinessProcess].[BusinessProcess_L2].&[10]'')
insert into @p2 values(N''[Currency].[Currency]'',N''[Currency].[Currency].[Currency_L2].&[4]'')
insert into @p2 values(N''[Entity].[Entity]'',N''[Entity].[Entity].[Entity_L1].&[1004]'')
insert into @p2 values(N''[GL_Department].[GL_Department]'',N''[GL_Department].[GL_Department].[GL_Department_L1].&[1]'')
insert into @p2 values(N''[GL_Division].[GL_Division]'',N''[GL_Division].[GL_Division].[GL_Division_L1].&[1]'')
insert into @p2 values(N''[LineItem].[LineItem]'',N''[LineItem].[LineItem].[LineItem_L1].&[1]'')
insert into @p2 values(N''[Measures]'',N''[Measures].[Financials_Value]'')
insert into @p2 values(N''[Scenario].[Scenario]'',N''[Scenario].[Scenario].[Scenario_L1].&[1]'')
insert into @p2 values(N''[Time].[Time]'',N''[Time].[Time].[Year].&[35]'')
insert into @p2 values(N''[TimeDataView].[TimeDataView]'',N''[TimeDataView].[TimeDataView].[TimeDataView_L2].&[2]'')
insert into @p2 values(N''[Version].[Version]'',N''[Version].[Version].[Version_L2].&[-1]'')

exec dbo.spConvert_KeyValuePair @UserName=N''DSPCLOUD1\Administrator'',@KeyValuePair=@p2,@debug=1
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS'

	SET @SQLStatement = @SQLStatement + '
	SET NOCOUNT ON
  EXEC dbo.spInsert_wrk_ParameterCode

	DECLARE @start INT,@startParameter INT,@DateFormat INT, @end INT , @endParameter INT , @LinkFilterCount INT, @PageID INT,@SequenceBM INT,@SourceTypeBM INT
    DECLARE @DataDB NVARCHAR(MAX)
    DECLARE @ParamString NVARCHAR(MAX)
    DECLARE @FilterName NVARCHAR(MAX)
    DECLARE @SQLRun NVARCHAR(MAX)
    DECLARE @DimensionName NVARCHAR(MAX)
    DECLARE @DimensionHierarchy NVARCHAR(MAX)
    DECLARE @MemberID NVARCHAR(MAX)
    DECLARE @LeafLabel NVARCHAR(MAX)

	SELECT
		@DataDB = [pcData_DBName],
		@DateFormat = [DateFormat]
	FROM
		dbo.SystemParameter

	IF @Debug > 0
		BEGIN
			SELECT DataDB = @DataDB
			SELECT TempTable = ''@KeyValuePair'', * FROM @KeyValuePair
		END

	CREATE TABLE #DimensionKeyValues
		(
		ID INT IDENTITY(1,1) PRIMARY KEY,
		DimensionName NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
		MemberID NVARCHAR(MAX) COLLATE DATABASE_DEFAULT
		)

	INSERT INTO #DimensionKeyValues
		(
		DimensionName,
		MemberID
		)
	SELECT DISTINCT
		DimensionName = RIGHT(LEFT([Key],CHARINDEX('']'',[Key]) - 1),CHARINDEX('']'',[Key]) - 2),
		MemberID = LEFT(RIGHT(Value,CHARINDEX(''['',REVERSE(Value)) - 1),CHARINDEX(''['',REVERSE(Value)) - 2)
	FROM
		@KeyValuePair
	WHERE
		LEFT(RIGHT(Value,CHARINDEX(''['',REVERSE(Value)) - 1),CHARINDEX(''['',REVERSE(Value)) - 2) NOT IN (''1'', ''-1'')'

	SET @SQLStatement = @SQLStatement + '
	
	CREATE TABLE #FilterDrillPageValues
		(
		ID INT IDENTITY(1,1) PRIMARY KEY,
		FilterName NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
		FilterValue NVARCHAR(MAX) COLLATE DATABASE_DEFAULT
		)
	
	CREATE TABLE #FilterDrillPageValuesSplit
		(
		ID INT IDENTITY(1,1) PRIMARY KEY,
		FilterName NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
		FilterValue NVARCHAR(MAX) COLLATE DATABASE_DEFAULT,
		SplitValue NVARCHAR(MAX) COLLATE DATABASE_DEFAULT
		)
	
	SET @start = 1
	SELECT
		@end = MAX(ID)
	FROM #DimensionKeyValues

	WHILE (@start < (@end + 1))
	BEGIN
		SELECT
			@DimensionName = DimensionName,
			@DimensionHierarchy = DimensionName + ''_'' + DimensionName,
			@MemberID = MemberID
		FROM
			#DimensionKeyValues
		WHERE 
			ID = @start AND
			ISNUMERIC(MemberID) = 1'

	SET @SQLStatement = @SQLStatement + '

		IF @Debug > 0 
		BEGIN
			SELECT
				[Loop] = ''spGet_LeafLabelLoop'',
				DimensionName = @DimensionName,
				DimensionHierarchy = @DimensionHierarchy,
				MemberID = @MemberID
		END
		
		EXEC [spGet_LeafLabel] @Database = @DataDB, @Dimension = @DimensionName, @Hierarchy = @DimensionHierarchy, @MemberId = @MemberID, @LeafLabel = @LeafLabel OUT

		--SELECT @LeafLabel
		INSERT INTO #FilterDrillPageValues
			(
			FilterName,
			FilterValue 
			)
		SELECT
			FilterName = CONVERT(NVARCHAR(MAX),@DimensionName),
			FilterValue = CONVERT(NVARCHAR(MAX),@LeafLabel)

		SET @start = @start + 1
	END

	IF @Debug <> 0 SELECT TempTable = ''#FilterDrillPageValues'', * FROM #FilterDrillPageValues
	
	SET @start = 1
	SELECT
		@end = MAX(ID)
	FROM #FilterDrillPageValues'

	SET @SQLStatement = @SQLStatement + '

	WHILE (@start < (@end + 1))
	BEGIN
		SELECT
			@DimensionName = FilterName,
			@LeafLabel = FilterValue
		FROM
			#FilterDrillPageValues
		WHERE 
			ID = @start
		
		--SELECT @LeafLabel

		INSERT INTO #FilterDrillPageValuesSplit
			(
			FilterName,
			FilterValue,
			SplitValue
			)
		SELECT DISTINCT
			FilterName = CASE 
							WHEN @DimensionName = ''Time'' AND LEN(REPLACE(SplitReturn,'''''''','''')) = 4 THEN ''Year''
							WHEN @DimensionName = ''Time'' AND LEN(REPLACE(SplitReturn,'''''''','''')) = 5 THEN ''Quarter''
							WHEN @DimensionName = ''Time'' AND LEN(REPLACE(SplitReturn,'''''''','''')) = 6 AND CHARINDEX(''q'',REPLACE(SplitReturn,'''''''','''')) > 0 THEN ''Quarter''
							WHEN @DimensionName = ''Time'' AND LEN(REPLACE(SplitReturn,'''''''','''')) = 6 AND CHARINDEX(''q'',REPLACE(SplitReturn,'''''''','''')) = 0 THEN ''Period''
							WHEN @DimensionName = ''Time'' AND LEN(REPLACE(SplitReturn,'''''''','''')) = 7 THEN ''Week''
							WHEN @DimensionName = ''Time'' AND LEN(REPLACE(SplitReturn,'''''''','''')) = 8 THEN ''Date''
							ELSE @DimensionName
						END,
			FilterValue = @LeafLabel,
			SplitValue =	CASE 
								WHEN @DimensionName = ''Time'' AND LEN(REPLACE(SplitReturn,'''''''','''')) = 8 THEN CONVERT(NVARCHAR(MAX),dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),REPLACE(SplitReturn,'''''''','''')),@DateFormat))
								ELSE SplitReturn
							END
		FROM
			dbo.fnSplitString(@LeafLabel,'','')

		SET @start = @start + 1
	END'

	SET @SQLStatement = @SQLStatement + '

	IF @Debug > 0 SELECT TempTable = ''#FilterDrillPageValuesSplit'', * FROM #FilterDrillPageValuesSplit

	SELECT DISTINCT
		P.PageID,
		P.PageCode,
		P.PageName,
		P.PageWeight,
		PC.ColumnID,
		NumberOfFilters = COUNT(FV.FilterName) OVER(PARTITION BY P.PageCode),
		WeightScore = COUNT(FV.FilterName) OVER(PARTITION BY P.PageCode) * P.PageWeight,
		FV.FilterName,
		FilterValue = REPLACE(FV.SplitValue,'''''''',''''),
		wPC.ParameterCode,
		URLParams = CONVERT(NVARCHAR(MAX),''''),
		PS.NumericBM
	INTO
		#DrillPages
	FROM 
		#FilterDrillPageValuesSplit FV
		INNER JOIN dbo.PageColumn PC ON PC.ColumnName COLLATE DATABASE_DEFAULT  = FV.FilterName COLLATE DATABASE_DEFAULT
		INNER JOIN dbo.[Page] P ON P.PageID = PC.PageID
		INNER JOIN [dbo].[wrk_ParameterCode] wPC ON wPC.ColumnID = PC.ColumnID
		INNER JOIN [dbo].[PageSource] PS ON PS.PageID = PC.PageID AND PS.ColumnID = PC.ColumnID AND PS.SelectYN <> 0
	WHERE
		PS.SequenceBM & 1 > 0

	SELECT
		DP.PageID,
		DP.FilterName,
		OriginalFilterValue = DP.FilterValue,
		FilterValue = REPLACE(REPLACE(PS.SourceString,''['' + FilterName + '']'','''''''' + DP.FilterValue + ''''''''),FilterName,'''''''' + DP.FilterValue + ''''''''),
		LinkedPageID = PC.PageID,
		LinkedColumnName = PC.ColumnName,
		LinkedColumnID = LD.ParameterColumnID,
		PS.SourceString,
		PS.SourceStringCode,
		wPC.ParameterCode,
		URLParams,
		PS.NumericBM
	INTO 
		#DrillPagesLinked
	FROM
		#DrillPages DP
		INNER JOIN [dbo].[LinkDefinition] LD ON LD.StartColumnID = DP.ColumnID
		INNER JOIN [dbo].[PageColumn] PC ON PC.ColumnID = LD.ParameterColumnID
		INNER JOIN [dbo].[wrk_ParameterCode] wPC ON wPC.ColumnID = PC.ColumnID
		INNER JOIN [dbo].[PageSource] PS ON PS.PageID = DP.PageID AND PS.ColumnID = LD.ParameterColumnID AND PS.SelectYN <> 0
	WHERE
		PS.SequenceBM & 1 > 0 AND
		DP.PageID <> PC.PageID AND
		PC.ColumnID NOT IN (SELECT ColumnID FROM #DrillPages)'

	SET @SQLStatement = @SQLStatement + '

	IF @Debug > 0
		BEGIN
			SELECT TempTable = ''#DrillPages'',* FROM #DrillPages
			SELECT TempTable = ''#DrillPagesLinked'',* FROM #DrillPagesLinked
		END
	
	CREATE TABLE #DrillPageParameters
		(
		ID INT IDENTITY(1,1) PRIMARY KEY,
		PageID INT,
		ParameterID INT,
		Parameter NVARCHAR(MAX) COLLATE DATABASE_DEFAULT
		)

	INSERT INTO #DrillPageParameters
		(
		PageID,
		ParameterID,
		Parameter 
		)
	
	SELECT DISTINCT
		PageID,
		ParameterID = ROW_NUMBER() OVER(PARTITION BY PageID ORDER BY ParameterCode),
		Parameter
	FROM
		(
		SELECT DISTINCT
			PageID,
			ParameterCode,
			Parameter = FilterName
		FROM 
			(
			SELECT DISTINCT
				PageID,
				FilterName,
				ParameterCode
			FROM
				#DrillPages
			) T'

	SET @SQLStatement = @SQLStatement + '
		UNION
		SELECT DISTINCT
			PageID,
			ParameterCode,
			Parameter = LinkedColumnName
		FROM
			(
			SELECT DISTINCT
				PageID = LinkedPageID,
				LinkedColumnName,
				ParameterCode
			FROM
				#DrillPagesLinked
			) T
		) T2
		
	SET @start = 1
	SELECT
		@end = MAX(LinkedPageID)
	FROM #DrillPagesLinked

	WHILE (@start < (@end + 1))
	BEGIN
		
		SELECT
			@SQLRun = CASE 
						WHEN NULLIF(@SQLRun,'''') IS NULL
						THEN ''
						UPDATE #DrillPagesLinked
						SET FilterValue = '' + CASE WHEN NULLIF(OriginalFilterValue,'''') IS NULL THEN '''''''''''' ELSE FilterValue END + ''
						WHERE 
							LinkedColumnID = '' + CONVERT(NVARCHAR(10),LinkedColumnID) + ''
							AND OriginalFilterValue = '''''' + OriginalFilterValue + ''''''
						''
						ELSE @SQLRun + ''
						UPDATE #DrillPagesLinked
						SET FilterValue = '' + CASE WHEN NULLIF(OriginalFilterValue,'''') IS NULL THEN '''''''''''' ELSE FilterValue END + ''
						WHERE 
							LinkedColumnID = '' + CONVERT(NVARCHAR(10),LinkedColumnID) + ''
							AND OriginalFilterValue = '''''' + OriginalFilterValue + ''''''
						''
					END
		FROM #DrillPagesLinked
		WHERE 
			LinkedPageID = @start'

	SET @SQLStatement = @SQLStatement + '
			/*
		IF @Debug > 0
		BEGIN
			SELECT 
				''#DrillPagesLinkedLoop'',*
			FROM #DrillPagesLinked
			WHERE 
				LinkedPageID = @start

			SELECT @SQLRun
			PRINT @SQLRun
		END
		*/
		EXEC(@SQLRun)
		SET @SQLRun = ''''

		SET @start = @start + 1 
	END

	SET @start = 1
	
	WHILE (@start < (@end + 1))
	BEGIN
		SET @startParameter = 1
		SELECT
			@endParameter = MAX(ParameterID)
		FROM #DrillPageParameters
		WHERE PageID = @start

		WHILE (@startParameter < (@endParameter + 1))
		BEGIN 
			SET @ParamString = ''''

			SELECT
				@FilterName = Parameter
			FROM #DrillPageParameters
			WHERE 
				PageID = @Start
				AND ParameterID = @startParameter'

	SET @SQLStatement = @SQLStatement + '

			SELECT
				@ParamString = CASE 
									WHEN NULLIF(@ParamString,'''') IS NULL 
										THEN CASE
												WHEN NULLIF(FilterValue,'''') IS NULL THEN  @ParamString + ParameterCode + ''='' + ''''''''''''
												ELSE @ParamString + ParameterCode + ''='' + '''''''' + FilterValue + ''''''''
											END
										ELSE CASE
												WHEN NULLIF(FilterValue,'''') IS NULL THEN @ParamString + '','' + ''''''''''''
												ELSE @ParamString + '','' + '''''''' + FilterValue + ''''''''
											END
								END
			FROM (
				SELECT DISTINCT
					FilterValue = CASE 
									WHEN NULLIF(FilterValue,'''') IS NULL THEN ''''
									WHEN FilterValue = '''''''''''' THEN ''''
									WHEN NumericBM = -1 AND ISDATE(REPLACE(FilterValue,'''''''','''')) <> 1 THEN ''''
									WHEN NumericBM & 1 > 0 AND ISNUMERIC(REPLACE(FilterValue,'''''''','''')) <> 1 THEN ''''
									WHEN NumericBM & 2 > 0 AND ISNUMERIC(REPLACE(FilterValue,'''''''','''')) <> 1 THEN ''''
									WHEN NumericBM & 4 > 0 AND ISNUMERIC(REPLACE(FilterValue,'''''''','''')) <> 1 THEN ''''
									ELSE FilterValue
								  END
					,ParameterCode
				FROM #DrillPagesLinked
				WHERE 
					LinkedPageID = @start
					AND LinkedColumnName = @FilterName
			) AS T
			WHERE FilterValue <> '''''

	SET @SQLStatement = @SQLStatement + '
			
			IF @Debug > 0
			BEGIN
				SELECT ''Update #DrillPagesLinked'',PageID = @start, @startParameter,@FilterName,@ParamString

				SELECT 
					*
				FROM #DrillPagesLinked
			END

			UPDATE DP
			SET URLParams = @ParamString
			FROM #DrillPagesLinked DP
			WHERE 
				LinkedPageID = @start
				AND LinkedColumnName = @FilterName

			SET @startParameter = @startParameter + 1

		END

		SET @start = @start + 1 
	END

	SET @start = 1
	SELECT
		@end = MAX(PageID)
	FROM #DrillPages'

	SET @SQLStatement = @SQLStatement + '

	SET @ParamString = ''''
	WHILE (@start < (@end + 1))
	BEGIN 
		SET @startParameter = 1
		SELECT
			@endParameter = MAX(ParameterID)
		FROM #DrillPageParameters
		WHERE PageID = @start

		WHILE (@startParameter < (@endParameter + 1))
		BEGIN 
			SET @ParamString = ''''

			SELECT
				@FilterName = Parameter
			FROM #DrillPageParameters
			WHERE 
				PageID = @Start
				AND ParameterID = @startParameter

			SELECT
				@ParamString = CASE 
									WHEN NULLIF(@ParamString,'''') IS NULL 
										THEN CASE
												WHEN NULLIF(FilterValue,'''') IS NULL THEN  @ParamString + ParameterCode + ''='' + ''''''''''''
												ELSE @ParamString + ParameterCode + ''='' + '''''''' + FilterValue + ''''''''
											END
										ELSE CASE
												WHEN NULLIF(FilterValue,'''') IS NULL THEN @ParamString + '','' + ''''''''''''
												ELSE @ParamString + '','' + '''''''' + FilterValue + ''''''''
											END
								END
			FROM #DrillPages
			WHERE 
				PageID = @start
				AND FilterName = @FilterName'

	SET @SQLStatement = @SQLStatement + '
				/*
			IF @Debug > 0
				SELECT PageID = @start, @startParameter,@FilterName,@ParamString
				*/
			UPDATE DP
			SET URLParams = @ParamString
			FROM #DrillPages DP
			WHERE 
				PageID = @start
				AND FilterName = @FilterName

			SET @startParameter = @startParameter + 1

		END

		
		SET @start = @start + 1 
	END

	SELECT
		PageID
		,URLParams
	INTO #PageURLParams
	FROM (
		SELECT DISTINCT
			PageID
			,URLParams
		FROM #DrillPages
		WHERE LTRIM(RTRIM(FilterValue)) <> ''''
		UNION
		SELECT DISTINCT
			PageID = LinkedPageID
			,URLParams
		FROM #DrillPagesLinked
		WHERE LTRIM(RTRIM(FilterValue)) <> ''''
	) AS T'

	SET @SQLStatement = @SQLStatement + '

	UPDATE DP
	SET DP.URLParams = ''''
	FROM #DrillPages DP

	SET @start = 1
	SELECT
		@end = MAX(PageID)
	FROM #DrillPages

	SET @ParamString = ''''

	IF @Debug > 0
	BEGIN
		SELECT
			''Before Update #PageURLParams'',*
		FROM #PageURLParams

		SELECT
			''Before Update #DrillPages'',*
		FROM #DrillPages
	END


	WHILE (@start < (@end + 1))
	BEGIN
		SET @ParamString = NULL

		SELECT
			@ParamString = CASE WHEN @ParamString IS NULL THEN URLParams
							ELSE @ParamString + ''&'' + URLParams END
		FROM #PageURLParams
		WHERE PageID = @start

		UPDATE DP
		SET DP.URLParams = @ParamString
		FROM #DrillPages DP
		WHERE DP.PageID = @start

		SET @start = @start + 1
	END'

	SET @SQLStatement = @SQLStatement + '
	
	IF @Debug > 0
	BEGIN
		SELECT
			''#DrillPages'',*
		FROM #DrillPages

		
		SELECT
			''#DrillPagesLinked'',*
		FROM #DrillPagesLinked
	END

	
	SELECT
		*
		,RK = ROW_NUMBER() OVER(ORDER BY WeightScore DESC,NumberOfFilters DESC,PageWeight DESC)
	INTO #DrillPagesRanked
	FROM (
		SELECT DISTINCT
			--DrillPages = ''/Default?Page='' + PageCode + ''&'' + MAX(URLParams)
			DrillPages = ''/Rpt/DrillPage/Default?Page='' + PageCode + ''&'' + MIN(URLParams)
			,PageCode
			,PageName
			,WeightScore
			,NumberOfFilters
			,PageWeight
		FROM #DrillPages
		GROUP BY PageCode,PageName,PageCode,WeightScore,NumberOfFilters,PageWeight
	) AS T
	ORDER BY WeightScore,NumberOfFilters,PageWeight'

	SET @SQLStatement = @SQLStatement + '
	
	IF EXISTS (
		SELECT
			Name = PageCode,
			Description = CASE
						WHEN RK = 1 THEN PageName /*+ '': '' + @DataDB*/ + ''  (Recommended)''
						ELSE PageName --+ '': '' + @DataDB 
					END,
			Link = DrillPages
		FROM #DrillPagesRanked
		WHERE PageCode <> ''Default''
	)
	BEGIN
		SELECT
			Name = PageCode,
			Description = CASE
						WHEN RK = 1 THEN PageName /*+ '': '' + @DataDB*/ + ''  (Recommended)''
						ELSE PageName --+ '': '' + @DataDB 
					END,
			Link = DrillPages
		FROM #DrillPagesRanked
		WHERE PageCode <> ''Default''
	END
	ELSE
	BEGIN
		SELECT
		Name = ''Default'',
		Description = ''Starting Point'',
		Link = ''/Rpt/DrillPage/Default''
	END'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
		BEGIN
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spConvert_KeyValuePair] ', [SQLStatement] = @SQLStatement
			SELECT * FROM #wrk_debug
			WHERE StepName = @Step
		END

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1
	END

	BEGIN
	SET @Step = 'CREATE PROCEDURE spCreate_PageProcedure' 
	SET @SQLStatement = ''
	SET @SQLStatement2 = ''
	

	SET @SQLStatement2 = '
CREATE PROCEDURE spCreate_PageProcedure
(
	@PageID INT = 1
	,@Debug	SMALLINT = 0 -- 0 No Debug, 1 Whole Code, 2 Step by step plus Whole Code
	,@Prefix	NVARCHAR(50) = '''' -- 0 No Debug, 1 Whole Code, 2 Step by step plus Whole Code
)

' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
--DECLARE @PageID INT
--DECLARE @Debug SMALLINT
--DECLARE @Prefix NVARCHAR(50) 
--SET @Debug = 1
--SET @PageID = 1
--SET @Prefix =  ''''

--EXEC dbo.spRunAll_spCreate_PageProcedure @Prefix = ''Test_''
--EXEC dbo.spRunAll_spCreate_PageProcedure @Debug = 1 , @Prefix = ''Test_''
--EXEC dbo.spRunAll_spCreate_PageProcedure @Debug = 1

/*
	EXEC spCreate_PageProcedure @PageID = 1, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 1, @Debug = 2 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 2, @Debug = 2 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 3, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 3, @Debug = 2 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 4, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 5, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 6, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 7, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 8, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 11, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 14, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 21, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 29, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 39, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 40, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 42, @Debug = 1 ,@Prefix = ''Test_''
	EXEC spCreate_PageProcedure @PageID = 60, @Debug = 1 ,@Prefix = ''Test_''
*/

---- ****************************************************************
---- Author: 		Marni Reyes, DSPanel
---- Date:   		2015-11-09
---- Description:	Create Dynamic Stored Procedures for Drill Page
---- ****************************************************************

DECLARE @Step NVARCHAR(MAX)
DECLARE @UpdateMidLinkParameter NVARCHAR(MAX)
DECLARE @AnchorLinkParameter NVARCHAR(500)
DECLARE @MidLinkParameter NVARCHAR(MAX)
DECLARE @CaseWhenLinkParameter NVARCHAR(500)
DECLARE @ColumnLinkCount INT
DECLARE @LinkValueCount INT
DECLARE @LinkValueCountLoop INT
DECLARE @ColumnLinkColumnID INT
DECLARE @InsertMidLinkParameterLoop INT
DECLARE @LinkValueLoop INT
DECLARE @FilterLoop INT
DECLARE @SourceTypeBM INT
 
DECLARE @Version NVARCHAR(255)
DECLARE @SQLRunDropProcedure NVARCHAR(MAX)
DECLARE @SQLRunCreateProcedure NVARCHAR(MAX)
DECLARE @SQLRunFilterValueCount NVARCHAR(MAX)
DECLARE @SQLRunFilterSelect NVARCHAR(MAX)
DECLARE @SQLRunFilterValue NVARCHAR(MAX)
DECLARE @SQLRunFilterDescription NVARCHAR(MAX)

DECLARE @SQLRunDataFirstRecordSetStart NVARCHAR(MAX)
DECLARE @SQLRunDataFirstRecordSet NVARCHAR(MAX)
DECLARE @SQLRunDataFirstRecordSetColumns NVARCHAR(MAX)
DECLARE @SQLRunDataFirstRecordSetIfNotExist NVARCHAR(MAX)
DECLARE @SQLRunDataFirstRecordSetEnd NVARCHAR(MAX)

DECLARE @SQLRunDataSecondRecordSetStart NVARCHAR(MAX)
DECLARE @SQLRunDataSecondRecordSet NVARCHAR(MAX)
DECLARE @SQLRunDataSecondRecordSetColumns NVARCHAR(MAX)
DECLARE @SQLRunDataSecondRecordSetIfNotExist NVARCHAR(MAX)
DECLARE @SQLRunDataSecondRecordSetEnd NVARCHAR(MAX)

DECLARE @SQLRunDataThirdRecordSetStart NVARCHAR(MAX)
DECLARE @SQLRunDataThirdRecordSet NVARCHAR(MAX)
DECLARE @SQLRunDataThirdRecordSetColumns NVARCHAR(MAX)
DECLARE @SQLRunDataThirdRecordSetIfNotExist NVARCHAR(MAX)
DECLARE @SQLRunDataThirdRecordSetEnd NVARCHAR(MAX)

DECLARE @SQLRunDataFourthRecordSet'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'Start NVARCHAR(MAX)
DECLARE @SQLRunDataFourthRecordSet NVARCHAR(MAX)
DECLARE @SQLRunDataFourthRecordSetColumns NVARCHAR(MAX)
DECLARE @SQLRunDataFourthRecordSetIfNotExist NVARCHAR(MAX)
DECLARE @SQLRunDataFourthRecordSetEnd NVARCHAR(MAX)

DECLARE @SQLRunDataFifthRecordSetStart NVARCHAR(MAX)
DECLARE @SQLRunDataFifthRecordSet NVARCHAR(MAX)
DECLARE @SQLRunDataFifthRecordSetColumns NVARCHAR(MAX)
DECLARE @SQLRunDataFifthRecordSetIfNotExist NVARCHAR(MAX)
DECLARE @SQLRunDataFifthRecordSetEnd NVARCHAR(MAX)

DECLARE @SQLRunDataInsertFirstRecordSetsSQL NVARCHAR(MAX)
DECLARE @SQLRunDataInsertSecondRecordSetsSQL NVARCHAR(MAX)
DECLARE @SQLRunDataInsertThirdRecordSetsSQL NVARCHAR(MAX)
DECLARE @SQLRunDataInsertFourthRecordSetsSQL NVARCHAR(MAX)
DECLARE @SQLRunDataInsertFifthRecordSetsSQL NVARCHAR(MAX)

DECLARE @SQLRunDataUpdateParameterRecordSetsSQL NVARCHAR(MAX)

DECLARE @SQLRunDataRecordSetColumns NVARCHAR(MAX)
DECLARE @SQLRunDataRecordSetLinkValues NVARCHAR(MAX)

DECLARE @UseDB NVARCHAR(MAX)
DECLARE @SQLRun NVARCHAR(MAX)
DECLARE @SQLRunResultTypeBM1 NVARCHAR(MAX)
DECLARE @SQLRunResultTables NVARCHAR(MAX)
DECLARE @SQLRun1 NVARCHAR(MAX)
DECLARE @SQLRun2 NVARCHAR(MAX)
DECLARE @InsertFilterValueCountLoopSQL NVARCHAR(MAX)
DECLARE @InsertFilterValueLoopSQL NVARCHAR(MAX)
DECLARE @InsertFilterValueLoopSQL2 NVARCHAR(MAX)
DECLARE @ColumnCount INT
DECLARE @FilterCount INT
DECLARE @FilterValueCount INT
DECLARE @InsertLinkParameterLoop INT
DECLARE @InsertColumnSortOrderAlfaLoop INT
DECLARE @InsertDataColumnLoop INT
DECLARE @InsertFilterValueCountLoop INT
DECLARE @InsertFilterValueLoop INT
DECLARE @WhereLoop INT
DECLARE @AndCheck INT
DECLARE @PageCode NVARCHAR(255)
DECLARE @ReturnRowLimit INT
DECLARE @DateFormat NVARCHAR(10)
DECLARE @CurrencyFormat NVARCHAR(10)
DECLARE @pcData NVARCHAR(4000)
DECLARE @pcDataOwner NVARCHAR(4000)
DECLARE @DataSource NVARCHAR(4000)
DECLARE @DataSourceOwner NVARCHAR(4000)

	SELECT
		@DateFormat = CONVERT(NVARCHAR(10),[DateFormat])
		,@CurrencyFormat = CONVERT(NVARCHAR(10),[CurrencyFormat])
		,@pcData = [pcData_DBName]
		,@pcDataOwner = [pcData_OwnerName]
		,@DataSource = [sourceDB_DBName]
		,@DataSourceOwner = [sourceDB_OwnerName]
		,@SourceTypeBM = [sourceTypeBM]
	FROM [dbo].[SystemParameter]
	
	EXEC dbo.spInsert_wrk_ParameterCode

	SELECT 
	  @ReturnRowLimit = [Return_Row_Limit]
	FROM [dbo].[SystemParameter]

	IF OBJECT_ID(N''tempdb..#SQLCode'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #SQLCode
		DROP TABLE #SQLCode
	END

	CREATE TABLE #SQLCode
				(
				ID INT IDENTITY(1,1) PRIMARY KEY
				,SQLCode NVARCHAR(MAX) COLLATE DATABASE_DEFAULT
				,SQLCodeDescription NVARCHAR(MAX) COLLATE DATABASE_DEFAULT
				,Debug INT
				)

	SELECT 
	  @PageCode = [PageCode]
	  ,@PageID = PageID
	FROM dbo.[Page]
	WHERE 
		PageID = @PageID -- 1 is Default Page. Added for Testing
		--PageID = 1 -- Default Page. Added for Testing

	/*

	FROM [dbo].[PageColumn]
	[NumericBM] -- This value is pertains to the general data type
		-2 = Bit
		, -1 = Date
		, 0 = Alfa
		, 1 = Numeric

	FROM [dbo].[PageSource]
	[SequenceBM] 
		-- 1 = First Result Table
		-- 2 = Second Result Table
		-- 4 = Third Result Table
		-- 8 = Fourth Result Table
		-- 16 = Fifth Result Table
		-- 32 = Filter Value
		-- 64 = Filter Description
		-- 128 = Filter Table

	[NumericBM] -- This value is how the format of the data will be shown in the webpage
		-2 = Bit
		, -1 = Date
		, 0 = Alfa
		, 1 = Numeric No Decimal
		, 2 = Currency

	ResultTypeBM
		1 = Filters
		2 = First ResultSet
		4 = Second ResultSet
		8 = Third ResultSet
		16 = Fourth ResultSet
		32 = Fifth ResultSet
	*/
	
	IF @Debug <> 0 
	BEGIN
		SELECT SourceTypeBM = @SourceTypeBM, PageID = @PageID

		SELECT A = ''Before #FirstRecordSet'', 
			PC.PageID
			,PS.ColumnID
			,PC.ColumnName
			,FirstRecor'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'dsetColumnSourceString = SourceString
			,FirstRecordsetColumnSourceStringCode = SourceStringCode
			,SortOrder
			,PC.NumericBM
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID <> -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 1 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
	END

	IF OBJECT_ID(N''tempdb..#FirstRecordSet'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #FirstRecordSet
		DROP TABLE #FirstRecordSet
	END
	SELECT
		FirstRecordsetColumns.PageID
		,FirstRecordsetColumns.ColumnID
		,FirstRecordsetColumns.ColumnName
		,FirstRecordsetColumns.NumericBM

		,FirstRecordsetColumns.FirstRecordsetColumnSourceString
		,FirstRecordsetColumns.FirstRecordsetColumnSourceStringCode
		,FirstRecordsetColumns.SortOrder
		,FirstRecordsetTable.FirstRecordsetTableSourceString
		,FirstRecordsetTable.FirstRecordsetTableSourceStringCode

		--,FilterColumnSourceString
		--,FilterTableSourceString
	INTO #FirstRecordSet
	FROM (
		SELECT
			PC.PageID
			,PS.ColumnID
			,PC.ColumnName
			,FirstRecordsetColumnSourceString = SourceString
			,FirstRecordsetColumnSourceStringCode = SourceStringCode
			,SortOrder
			,PC.NumericBM
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID <> -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 1 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
	) FirstRecordsetColumns
	INNER JOIN (
		SELECT
			PS.PageID
			,FirstRecordsetTableSourceString = SourceString
			,FirstRecordsetTableSourceStringCode = SourceStringCode
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID = -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 1 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
	) FirstRecordsetTable
		ON FirstRecordsetTable.PageID = FirstRecordsetColumns.PageID
	/*First Recordset*/


	IF OBJECT_ID(N''tempdb..#SecondRecordSet'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #SecondRecordSet
		DROP TABLE #SecondRecordSet
	END
	SELECT
		SecondRecordsetColumns.PageID
		,SecondRecordsetColumns.ColumnID
		,SecondRecordsetColumns.ColumnName
		,SecondRecordsetColumns.NumericBM

		,SecondRecordsetColumns.SecondRecordsetColumnSourceString
		,SecondRecordsetColumns.SecondRecordsetColumnSourceStringCode
		,SecondRecordsetColumns.SortOrder
		,SecondRecordsetTable.SecondRecordsetTableSourceString
		,SecondRecordsetTable.SecondRecordsetTableSourceStringCode

	INTO #SecondRecordSet
	FROM (
		SELECT
			PC.PageID
			,PS.ColumnID
			,PC.ColumnName
			,SecondRecordsetColumnSourceString = SourceString
			,SecondRecordsetColumnSourceStringCode = SourceStringCode
			,SortOrder
			,PC.NumericBM
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID <> -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 2 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
	) SecondRecordsetColumns
	INNER JOIN (
		SELECT
			PS.PageID
			,SecondRecordsetTableSourceString = SourceString
			,SecondRecordsetTableSourceStringCode = SourceStringCode
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID = -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & '
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = '@SourceTypeBM > 0
			AND PS.SequenceBM & 2 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
	) SecondRecordsetTable
		ON SecondRecordsetTable.PageID = SecondRecordsetColumns.PageID
	/*Second Recordset*/
	
	IF OBJECT_ID(N''tempdb..#ThirdRecordSet'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #ThirdRecordSet
		DROP TABLE #ThirdRecordSet
	END
	SELECT
		ThirdRecordsetColumns.PageID
		,ThirdRecordsetColumns.ColumnID
		,ThirdRecordsetColumns.ColumnName
		,ThirdRecordsetColumns.NumericBM

		,ThirdRecordsetColumns.ThirdRecordsetColumnSourceString
		,ThirdRecordsetColumns.ThirdRecordsetColumnSourceStringCode
		,ThirdRecordsetColumns.SortOrder
		,ThirdRecordsetTable.ThirdRecordsetTableSourceString
		,ThirdRecordsetTable.ThirdRecordsetTableSourceStringCode

	INTO #ThirdRecordSet
	FROM (
		SELECT
			PC.PageID
			,PS.ColumnID
			,PC.ColumnName
			,ThirdRecordsetColumnSourceString = SourceString
			,ThirdRecordsetColumnSourceStringCode = SourceStringCode
			,SortOrder
			,PS.NumericBM
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID <> -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 4 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
	) ThirdRecordsetColumns
	INNER JOIN (
		SELECT
			PS.PageID
			,ThirdRecordsetTableSourceString = SourceString
			,ThirdRecordsetTableSourceStringCode = SourceStringCode
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID = -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 4 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
	) ThirdRecordsetTable
		ON ThirdRecordsetTable.PageID = ThirdRecordsetColumns.PageID
	/*Third Recordset*/
	
	IF OBJECT_ID(N''tempdb..#FourthRecordSet'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #FourthRecordSet
		DROP TABLE #FourthRecordSet
	END
	SELECT
		FourthRecordsetColumns.PageID
		,FourthRecordsetColumns.ColumnID
		,FourthRecordsetColumns.ColumnName
		,FourthRecordsetColumns.NumericBM

		,FourthRecordsetColumns.FourthRecordsetColumnSourceString
		,FourthRecordsetColumns.FourthRecordsetColumnSourceStringCode
		,FourthRecordsetColumns.SortOrder
		,FourthRecordsetTable.FourthRecordsetTableSourceString
		,FourthRecordsetTable.FourthRecordsetTableSourceStringCode

	INTO #FourthRecordSet
	FROM (
		SELECT
			PC.PageID
			,PS.ColumnID
			,PC.ColumnName
			,FourthRecordsetColumnSourceString = SourceString
			,FourthRecordsetColumnSourceStringCode = SourceStringCode
			,SortOrder
			,PC.NumericBM
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID <> -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 8 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
	) FourthRecordsetColumns
	INNER JOIN (
		SELECT
			PS.PageID
			,FourthRecordsetTableSourceString = SourceString
			,FourthRecordsetTableSourceStringCode = SourceStringCode
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID = -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 8 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
	) FourthRecordsetTable
		ON FourthRecordsetTable.PageID = FourthRecordsetColumns.PageID
	/*Fourth Recordset*/
	
	IF OBJECT_ID(N''tempdb..#FifthRecordSet'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #FifthRecordSet
		DROP TABLE #Fif'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'thRecordSet
	END
	SELECT
		FifthRecordsetColumns.PageID
		,FifthRecordsetColumns.ColumnID
		,FifthRecordsetColumns.ColumnName
		,FifthRecordsetColumns.NumericBM

		,FifthRecordsetColumns.FifthRecordsetColumnSourceString
		,FifthRecordsetColumns.FifthRecordsetColumnSourceStringCode
		,FifthRecordsetColumns.SortOrder
		,FifthRecordsetTable.FifthRecordsetTableSourceString
		,FifthRecordsetTable.FifthRecordsetTableSourceStringCode

	INTO #FifthRecordSet
	FROM (
		SELECT
			PC.PageID
			,PS.ColumnID
			,PC.ColumnName
			,FifthRecordsetColumnSourceString = SourceString
			,FifthRecordsetColumnSourceStringCode = SourceStringCode
			,SortOrder
			,PS.NumericBM
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID <> -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 8 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
	) FifthRecordsetColumns
	INNER JOIN (
		SELECT
			PS.PageID
			,FifthRecordsetTableSourceString = SourceString
			,FifthRecordsetTableSourceStringCode = SourceStringCode
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID = -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 8 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
	) FifthRecordsetTable
		ON FifthRecordsetTable.PageID = FifthRecordsetColumns.PageID
	/*Fifth Recordset*/
	
	IF @Debug <> 0 
	BEGIN
		SELECT A = ''#FirstRecordSet'', * FROM #FirstRecordSet
	END

	IF OBJECT_ID(N''tempdb..#RecordSets'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #RecordSets
		DROP TABLE #RecordSets
	END
	SELECT
		PageID = COALESCE(FRS.PageID,SRS.PageID,TRS.PageID,FoRS.PageID,FiRS.PageID)
		,ColumnID = COALESCE(FRS.ColumnID,SRS.ColumnID,TRS.ColumnID,FoRS.ColumnID,FiRS.ColumnID)
		,ColumnName = COALESCE(FRS.ColumnName,SRS.ColumnName,TRS.ColumnName,FoRS.ColumnName,FiRS.ColumnName)
		,SortOrder = COALESCE(FRS.SortOrder,SRS.SortOrder,TRS.SortOrder,FoRS.SortOrder,FiRS.SortOrder)
		,NumericBM = COALESCE(FRS.NumericBM,SRS.NumericBM,TRS.NumericBM,FoRS.NumericBM,FiRS.NumericBM)
		,FRS.FirstRecordsetTableSourceString
		,FRS.FirstRecordsetTableSourceStringCode
		,FRS.FirstRecordsetColumnSourceString
		,FRS.FirstRecordsetColumnSourceStringCode
		,SRS.SecondRecordsetTableSourceString
		,SRS.SecondRecordsetTableSourceStringCode
		,SRS.SecondRecordsetColumnSourceString
		,SRS.SecondRecordsetColumnSourceStringCode
		,TRS.ThirdRecordsetTableSourceString
		,TRS.ThirdRecordsetTableSourceStringCode
		,TRS.ThirdRecordsetColumnSourceString
		,TRS.ThirdRecordsetColumnSourceStringCode
		,FoRS.FourthRecordsetTableSourceString
		,FoRS.FourthRecordsetTableSourceStringCode
		,FoRS.FourthRecordsetColumnSourceString
		,FoRS.FourthRecordsetColumnSourceStringCode
		,FiRS.FifthRecordsetTableSourceString
		,FiRS.FifthRecordsetTableSourceStringCode
		,FiRS.FifthRecordsetColumnSourceString
		,FiRS.FifthRecordsetColumnSourceStringCode
	INTO #RecordSets
	FROM #FirstRecordSet FRS
	FULL JOIN #SecondRecordSet SRS
		ON SRS.PageID = FRS.PageID
		AND SRS.ColumnID = FRS.ColumnID
	FULL JOIN #ThirdRecordSet TRS
		ON TRS.PageID = FRS.PageID
		AND TRS.ColumnID = FRS.ColumnID
	FULL JOIN #FourthRecordSet FoRS
		ON FoRS.PageID = FRS.PageID
		AND FoRS.ColumnID = FRS.ColumnID
	FULL JOIN #FifthRecordSet FiRS
		ON FiRS.PageID = FRS.PageID
		AND FiRS.ColumnID = FRS.ColumnID

	IF OBJECT_ID(N''tempdb..#LinkColumns'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #LinkColumns
		DROP TABLE #LinkColumns
	END
	SELECT
		RS.PageID
		,RS.ColumnID
		,RS.ColumnName
		,RS.SortOrder
		,LinkColumnID = PS.ColumnID
		,LinkNu'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'mericBM = PS.NumericBM
		,P.PageCode
		,PC.ParameterCode
		,[LinkValue] = NULLIF([LD].[StartColumnValue],''@@@@@'')
		,[LinkValueID] = DENSE_RANK() OVER(PARTITION BY RS.ColumnID ORDER BY P.PageCode)
		,MidLink = CONVERT(NVARCHAR(MAX),'''')
		,MidLinkCase = CONVERT(NVARCHAR(MAX),'''')
		,PS.InvalidValues
		,PS.SourceString
		,PS.SourceStringCode
		,LinkSourceString = COALESCE(FirstRecordsetColumnSourceString,SecondRecordsetColumnSourceString,ThirdRecordsetColumnSourceString,FourthRecordsetColumnSourceString,FifthRecordsetColumnSourceString)
		,LinkSourceStringCode = COALESCE(FirstRecordsetColumnSourceStringCode,SecondRecordsetColumnSourceStringCode,ThirdRecordsetColumnSourceStringCode,FourthRecordsetColumnSourceStringCode,FifthRecordsetColumnSourceStringCode)
	INTO #LinkColumns
	FROM #RecordSets RS
	INNER JOIN [dbo].[LinkDefinition] LD
		ON LD.StartColumnID = RS.ColumnID
	INNER JOIN [dbo].[wrk_ParameterCode] PC
		ON PC.ColumnID = LD.ParameterColumnID
	INNER JOIN [dbo].[Page] P
		ON P.PageID = PC.PageID
	INNER JOIN [dbo].[PageSource] PS
		ON PS.ColumnID = LD.ParameterColumnID
	WHERE 
		--PS.[PageID] = 1
		PS.[PageID] = @PageID
		AND LD.SelectYN = 1
		AND PS.SelectYN = 1
		AND PS.SequenceBM & 3 > 0
	
	IF (@Debug > 0)
	BEGIN
		SELECT
			A = ''#LinkColumns''
			,*
		FROM #LinkColumns
	END

	SELECT
		@ColumnLinkCount = MAX(ColumnID)
		,@LinkValueLoop = 1
	FROM #LinkColumns

	SET @MidLinkParameter = ''''
	SET @UpdateMidLinkParameter = ''''
	
	WHILE (@LinkValueLoop < (@ColumnLinkCount + 1))
	BEGIN
		SELECT
			@LinkValueCount = MAX(LinkValueID)
			,@LinkValueCountLoop = 1
		FROM #LinkColumns
		WHERE
			ColumnID = @LinkValueLoop

		WHILE (@LinkValueCountLoop < (@LinkValueCount + 1))
		BEGIN
			SELECT
				@MidLinkParameter = @MidLinkParameter + '' + ''''&'' + [PLP].ParameterCode + ''='''' + CONVERT(NVARCHAR(MAX), CASE WHEN CONVERT(NVARCHAR(MAX),'' + CASE WHEN NULLIF([PLP].[SourceStringCode] ,'''') IS NOT NULL THEN [PLP].[SourceStringCode] + ''.'' ELSE '''' END + [PLP].[SourceString] 
									+ '') '' + CASE WHEN [PLP].[LinkNumericBM] = 0 THEN ''COLLATE DATABASE_DEFAULT '' ELSE '''' END
									+ ''IN ('' + CASE 
													WHEN [PLP].[LinkNumericBM] = -1 THEN ''''''1900-01-01 00:00:00.000''''''
													WHEN [PLP].[LinkNumericBM] = 0 AND ISNULL(NULLIF([PLP].[InvalidValues],''''),'''''''''''') = '''''''''''' THEN ''''''''''''
													WHEN [PLP].[LinkNumericBM] = 0 THEN [dbo].[fnSplitStringPutDoubleQuotes]([PLP].[InvalidValues],'','')
													ELSE ISNULL([PLP].[InvalidValues],''-123456789'')
												END + '') THEN '''''''' ELSE '' + CASE WHEN NULLIF([PLP].[SourceStringCode] ,'''') IS NOT NULL THEN [PLP].[SourceStringCode] + ''.'' ELSE '''' END + [PLP].[SourceString] + '' END)''
			FROM (
				SELECT DISTINCT
					ColumnID
					,[LinkValueID]
					,ParameterCode
					,[LinkNumericBM]
					,[InvalidValues]
					,[SourceString]
					,[SourceStringCode]
				FROM #LinkColumns 
			) AS [PLP]
			WHERE
				ColumnID = @LinkValueLoop
				AND [LinkValueID] = @LinkValueCountLoop

			--SELECT @MidLinkParameter

			SELECT DISTINCT
				@UpdateMidLinkParameter = ''''''<a data-sort="'''''' + '' + CONVERT(NVARCHAR(MAX),'' 
											--THis is still original column
											+ CASE 
													WHEN CHARINDEX(''+'', [PLP].[LinkSourceString]) > 0 THEN ''''
													WHEN NULLIF([PLP].[LinkSourceStringCode] ,'''') IS NOT NULL THEN [PLP].[LinkSourceStringCode] + ''.'' 
													ELSE '''' 
											END + [PLP].[LinkSourceString] + '')'' + '' + ''''" href="Default?Page='' + [PLP].PageCode + '''''''' + @MidLinkParameter + '' + ''''">'''''' + '' + '' 
											+ ''CONVERT(NVARCHAR(MAX),'' +
											--This is still link column
											+ CASE 
													WHEN [PLP].[LinkNumericBM] = 0 THEN '''' 
														+ CASE 
															W'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'HEN CHARINDEX(''+'', [PLP].[LinkSourceString]) > 0 THEN ''''
															WHEN NULLIF([PLP].[LinkSourceStringCode] ,'''') IS NOT NULL THEN [PLP].[LinkSourceStringCode] + ''.'' 
															ELSE '''' 
														END + [PLP].[LinkSourceString] + '' '' 
													WHEN [PLP].[LinkNumericBM] = -1 THEN ''dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),''
														+ CASE 
															WHEN CHARINDEX(''+'', [PLP].[LinkSourceString]) > 0 THEN ''''
															WHEN NULLIF([PLP].[LinkSourceStringCode] ,'''') IS NOT NULL THEN [PLP].[LinkSourceStringCode] + ''.'' 
															ELSE '''' 
														END + [PLP].[LinkSourceString] + ''),'' + @DateFormat + '')'' 
													WHEN [PLP].[LinkNumericBM] = 1 THEN ''CONVERT(INT,'' 
														+ CASE 
															WHEN CHARINDEX(''+'', [PLP].[LinkSourceString]) > 0 THEN ''''
															WHEN NULLIF([PLP].[LinkSourceStringCode] ,'''') IS NOT NULL THEN [PLP].[LinkSourceStringCode] + ''.'' 
															ELSE '''' 
														END + [PLP].[LinkSourceString] + '') '' 
													WHEN [PLP].[LinkNumericBM] = -2 THEN ''CONVERT(BIT,'' 
														+ CASE 
															WHEN CHARINDEX(''+'', [PLP].[LinkSourceString]) > 0 THEN ''''
															WHEN NULLIF([PLP].[LinkSourceStringCode] ,'''') IS NOT NULL THEN [PLP].[LinkSourceStringCode] + ''.'' 
															ELSE '''' 
														END + [PLP].[LinkSourceString] + '') '' 
													WHEN [PLP].[LinkNumericBM] = 2 THEN ''dbo.fnFormatCurrency('' + CASE WHEN NULLIF([PLP].[LinkSourceStringCode] ,'''') IS NOT NULL THEN [PLP].[LinkSourceStringCode] + ''.'' ELSE '''' END + [PLP].[LinkSourceString] + '','' + @CurrencyFormat + '') '' 
												ELSE ''CONVERT(NVARCHAR(MAX),'' 
														+ CASE 
															WHEN CHARINDEX(''+'', [PLP].[LinkSourceString]) > 0 THEN ''''
															WHEN NULLIF([PLP].[LinkSourceStringCode] ,'''') IS NOT NULL THEN [PLP].[LinkSourceStringCode] + ''.'' 
															ELSE '''' 
														END + [PLP].[LinkSourceString] + '') '' 
												END
											+ '') + ''''</a>''''''
			FROM #LinkColumns [PLP]
			WHERE
				ColumnID = @LinkValueLoop
				AND [LinkValueID] = @LinkValueCountLoop


			UPDATE #LinkColumns
			SET MidLink = @UpdateMidLinkParameter
			WHERE
				ColumnID = @LinkValueLoop
				AND [LinkValueID] = @LinkValueCountLoop
		
			SET @LinkValueCountLoop = @LinkValueCountLoop + 1
			
			SET @MidLinkParameter = ''''
			SET @UpdateMidLinkParameter = ''''
		END

		SET @LinkValueLoop = @LinkValueLoop + 1
	END
	
	SET @SQLRunDataRecordSetLinkValues = ''''
	
	SELECT
		@ColumnCount = MAX(ColumnID)
		,@LinkValueLoop = 1
	FROM #LinkColumns

	WHILE (@LinkValueLoop < (@ColumnCount + 1))
	BEGIN
		SELECT
			@LinkValueCount = MAX(ColumnID)
			,@LinkValueCountLoop = 1
		FROM #LinkColumns

		WHILE (@LinkValueCountLoop < (@LinkValueCount + 1))
		BEGIN
			SELECT
				@SQLRunDataRecordSetLinkValues = @SQLRunDataRecordSetLinkValues 
				+ CASE 
					WHEN NULLIF(@SQLRunDataRecordSetLinkValues,'''') IS NULL THEN ''CONVERT(NVARCHAR(MAX),''
					ELSE '' AND CONVERT(NVARCHAR(MAX),''
				END
				+ CASE
					WHEN NULLIF(SourceStringCode,'''') IS NULL THEN SourceString
					ELSE SourceStringCode + ''.'' + SourceString
				END 
				+ CASE 
					WHEN LinkValue IS NULL THEN '') COLLATE DATABASE_DEFAULT NOT IN (REPLACE([dbo].[fnSplitStringPutDoubleQuotes]('''''' + ISNULL(InvalidValues,'''''''''''') + '''''','''',''''),'''''''''''''''','''''''') ) '' 
					ELSE '') COLLATE DATABASE_DEFAULT NOT IN (REPLACE([dbo].[fnSplitStringPutDoubleQuotes]('''''' + ISNULL(InvalidValues,'''''''''''') + '''''','''',''''),'''''''''''''''','''''''') )'' 
				END
			FROM (
				SELECT DISTINCT 
					ColumnID
					,SourceString
					,SourceStringCode
					,LinkSourceString
					,LinkSourceStringCode
					,LinkValue = NULLIF(LinkValue,'''')
					'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = ',LinkValueID
					,InvalidValues
					,MidLink
				FROM #LinkColumns
				WHERE 
					ColumnID = @LinkValueLoop
					AND LinkValueID = @LinkValueCountLoop
			) AS T
			
			IF EXISTS(SELECT 
							1 
						FROM #LinkColumns
						WHERE 
							ColumnID = @LinkValueLoop
							AND LinkValueID = @LinkValueCountLoop 
							AND @Debug > 1)
			SELECT
				LinkValue
				,LinkSourceString
				,LinkSourceStringCode
				,MidLink
				,''
					WHEN '' + @SQLRunDataRecordSetLinkValues +
					CASE
						WHEN LinkValue IS NOT NULL THEN '' AND '' 
													+ CASE
														WHEN NULLIF(LinkSourceStringCode,'''') IS NULL THEN LinkSourceString
														ELSE LinkSourceStringCode + ''.'' + LinkSourceString
													END 
													+  '' = '''''' + LinkValue + '''''''' 
						ELSE ''''
					END
					+ '' THEN '' + MidLink + CHAR(13) 
			FROM #LinkColumns
			WHERE 
				ColumnID = @LinkValueLoop
				AND LinkValueID = @LinkValueCountLoop

			UPDATE #LinkColumns
			SET MidLinkCase = ''
					WHEN '' + @SQLRunDataRecordSetLinkValues +
					CASE
						WHEN LinkValue IS NOT NULL THEN '' AND '' 
													+ CASE
														WHEN NULLIF(LinkSourceStringCode,'''') IS NULL THEN LinkSourceString
														ELSE LinkSourceStringCode + ''.'' + LinkSourceString
													END 
													+  '' = '''''' + LinkValue + '''''''' 
						ELSE ''''
					END
					+ '' THEN '' 
					+ MidLink + CHAR(13) 
			WHERE 
				ColumnID = @LinkValueLoop
				AND LinkValueID = @LinkValueCountLoop
			
			SET @SQLRunDataRecordSetLinkValues = ''''

			
			SET @LinkValueCountLoop = @LinkValueCountLoop + 1
		END

		SET @SQLRunDataRecordSetLinkValues = ''''

		SELECT
			@SQLRunDataRecordSetLinkValues = @SQLRunDataRecordSetLinkValues + MidLinkCase
		FROM (
			SELECT DISTINCT
				ColumnID
				,MidLinkCase
			FROM #LinkColumns
			WHERE 
				ColumnID = @LinkValueLoop
		) AS T
		

		UPDATE #LinkColumns
		SET MidLinkCase = @SQLRunDataRecordSetLinkValues
		WHERE 
			ColumnID = @LinkValueLoop

		SET @SQLRunDataRecordSetLinkValues = ''''

		SET @LinkValueLoop = @LinkValueLoop + 1
	END

	--SELECT * FROM #LinkColumns WHERE ColumnID = 14
	
	IF @Debug <> 0 
	BEGIN
		SELECT A = ''#RecordSets'', * FROM #RecordSets
	END

	IF OBJECT_ID(N''tempdb..#FullRecordSets'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #FullRecordSets
		DROP TABLE #FullRecordSets
	END
	SELECT
		RS.PageID
		,RS.ColumnID
		,RS.ColumnName
		,RS.SortOrder
		,RS.NumericBM
		,ParameterID
		,ParameterCode 
		,FilterTableSourceString
		,FilterTableSourceStringCode
		,FilterValueSourceString
		,FilterValueSourceStringCode
		,FilterDescriptionSourceString
		,FilterDescriptionSourceStringCode
		,FilterValueNumericBM
		,RS.FirstRecordsetTableSourceString
		,RS.FirstRecordsetTableSourceStringCode
		,RS.FirstRecordsetColumnSourceString
		,RS.FirstRecordsetColumnSourceStringCode
		,RS.SecondRecordsetTableSourceString
		,RS.SecondRecordsetTableSourceStringCode
		,RS.SecondRecordsetColumnSourceString
		,RS.SecondRecordsetColumnSourceStringCode
		,RS.ThirdRecordsetTableSourceString
		,RS.ThirdRecordsetTableSourceStringCode
		,RS.ThirdRecordsetColumnSourceString
		,RS.ThirdRecordsetColumnSourceStringCode
		,RS.FourthRecordsetTableSourceString
		,RS.FourthRecordsetTableSourceStringCode
		,RS.FourthRecordsetColumnSourceString
		,RS.FourthRecordsetColumnSourceStringCode
		,RS.FifthRecordsetTableSourceString
		,RS.FifthRecordsetTableSourceStringCode
		,RS.FifthRecordsetColumnSourceString
		,RS.FifthRecordsetColumnSourceStringCode
		--,LC.LinkValue
		--,LC.InvalidValues
		--,LC.MidLink
	INTO #FullRecordSets
	FROM #RecordSets RS
	--LEFT JOIN #LinkColumns LC
	--	ON LC.ColumnID = RS.ColumnID
	LEFT JOIN (
		SELECT
			PS.PageID
			,FilterTableSourceString = SourceString
			,FilterTableSourceStringCode'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = ' = SourceStringCode
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID = -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 128 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
	) FilterTable
		ON FilterTable.PageID = RS.PageID
	LEFT JOIN (
		SELECT
			PS.PageID
			,PS.ColumnID
			,PC.ColumnName
			,ParameterID = ROW_NUMBER() OVER (PARTITION BY PC.PageID ORDER BY PC.SortOrder)
			,ParameterCode = CASE 
								WHEN ROW_NUMBER() OVER (PARTITION BY PC.PageID ORDER BY PC.SortOrder) < 10 THEN ''P0'' + CAST(ROW_NUMBER() OVER (PARTITION BY PC.PageID ORDER BY PC.SortOrder) AS NVARCHAR(50))
								ELSE ''P'' + CAST(ROW_NUMBER() OVER (PARTITION BY PC.PageID ORDER BY PC.SortOrder) AS NVARCHAR(50))
							END
			,FilterValueSourceString = SourceString
			,FilterValueSourceStringCode = SourceStringCode
			,FilterValueNumericBM = PS.NumericBM
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID <> -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 32 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
			AND PC.FilterYN = 1
	) FilterValue
		ON FilterValue.PageID = RS.PageID
		AND FilterValue.ColumnID = RS.ColumnID
	LEFT JOIN (
		SELECT
			PS.PageID
			,PS.ColumnID
			,PC.ColumnName
			,FilterDescriptionSourceString = SourceString
			,FilterDescriptionSourceStringCode = SourceStringCode
		FROM [dbo].[PageSource] PS
		INNER JOIN [dbo].[PageColumn] PC
			ON PC.ColumnID = PS.ColumnID
		WHERE 
			--PS.[PageID] = 1
			PS.[PageID] = @PageID
			AND PS.ColumnID <> -100
			--AND PS.SourceTypeBM & 1 > 0
			AND PS.SourceTypeBM & @SourceTypeBM > 0
			AND PS.SequenceBM & 64 > 0
			AND PS.SelectYN = 1
			AND PC.SelectYN = 1
			AND PC.FilterYN = 1
	) FilterDescription
		ON FilterDescription.PageID = RS.PageID
		AND FilterDescription.ColumnID = RS.ColumnID
	/*Filters*/


	--SELECT DISTINCT
	--	FRS.*
	--	,LC.MidLink
	--FROM #FullRecordSets FRS
	--LEFT JOIN #LinkColumns LC
	--	ON LC.ColumnID = FRS.ColumnID
	SET @UseDB = ''USE '' + DB_NAME()
	
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@UseDB,''@UseDB'',1)

	SET @SQLRunDropProcedure = ''
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''''[dbo].['' + @Prefix + ''spGet_Page_'' + @PageCode + '']'''') AND type in (N''''P'''', N''''PC''''))
BEGIN
	DROP PROCEDURE [dbo].['' + @Prefix + ''spGet_Page_'' + @PageCode + '']
END''
	
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunDropProcedure,''@SQLRunDropProcedure'',1)


	--EXEC dbo.sp_executesql @statement = @SQLRunDropProcedure


	SET @SQLRunCreateProcedure = ''

-- ****************************************************************************************
-- Author: 		Marni Reyes, DSPanel
-- Description:	This stored procedure was created dynamically by spCreate_PageProcedure
-- ****************************************************************************************

CREATE PROCEDURE [dbo].[spGet_Page_'' + @PageCode + '']
	--Default parameter
	@UserName	nvarchar(50),
	@Page		nvarchar(50) = '''''' + @PageCode + '''''',
	@ResultTypeBM int, --1 = Metadata, 2 = Data, 3 = Metadata & Data
	--@Freetext		nvarchar(MAX) = NULL,
	@P01		nvarchar(MAX) = NULL,
	@P02		nvarchar(MAX) = NULL,
	@P03		nvarchar(MAX) = NULL,
	@P04		nvarchar(MAX) = NULL,
	@P05		nvarchar(MAX) = NULL,
	@P06		nvarchar(MAX) = NULL,
	@P07		nvarchar(MAX) = NULL,
	@P08		nvarchar(MAX) = NULL,
	@P09		nvarchar(MAX) = NULL,
	@P10		nvarchar(MAX) = NULL,
	@P11		nvarchar(MAX) = NULL,
	@P12		nvarchar(MAX) = NU'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'LL,
	@P13		nvarchar(MAX) = NULL,
	@P14		nvarchar(MAX) = NULL,
	@P15		nvarchar(MAX) = NULL,
	@P16		nvarchar(MAX) = NULL,
	@P17		nvarchar(MAX) = NULL,
	@P18		nvarchar(MAX) = NULL,
	@P19		nvarchar(MAX) = NULL,
	@P20		nvarchar(MAX) = NULL,
	@fromExcel		nvarchar(MAX) = NULL,
	@excelParams		nvarchar(MAX) = NULL,
	@Debug		bit = 0,
	@ShowFilterColumnsYN	bit = 0

/*
	EXEC dbo.spGet_Page_'' + @PageCode + '' @UserName = ''''bengt@jaxit.se'''', @Debug = 1,  @ResultTypeBM = 1, @P01 = ''''EPIC06_Main'''', @P03 = ''''2000''''
	EXEC dbo.spGet_Page_'' + @PageCode + '' @UserName = ''''bengt@jaxit.se'''', @Debug = 1,  @ResultTypeBM = 2, @P02 = ''''EPIC06_Main'''', @P03 = ''''2000''''
	EXEC dbo.spGet_Page_'' + @PageCode + '' @UserName = ''''bengt@jaxit.se'''', @Debug = 1,  @ResultTypeBM = 3, @P02 = ''''EPIC06_Main'''', @P03 = ''''2000''''
	EXEC dbo.spGet_Page_'' + @PageCode + '' @UserName = ''''bengt@jaxit.se'''', @Debug = 1,  @ResultTypeBM = 2
	EXEC dbo.spGet_Page_'' + @PageCode + '' @UserName = ''''bengt@jaxit.se'''', @Debug = 1,  @ResultTypeBM = 3

*/	

/*
!!!!!!!!!!!!!!!!!!!!!!!!!!
--WITH ENCRYPTION--
To be added later.
!!!!!!!!!!!!!!!!!!!!!!!!!!
*/

AS
	SET NOCOUNT ON

	DECLARE @Filter_CB_Limit INT
	DECLARE @Page_ID INT
	DECLARE @SQLExec NVARCHAR(MAX)
	DECLARE @SQLExec2 NVARCHAR(MAX)

	EXEC dbo.spInsert_wrk_ParameterCode


	SELECT
		@Page_ID = [PageID]
	FROM [dbo].[Page]
	WHERE [PageCode] = @Page

	SELECT 
		@Filter_CB_Limit = Filter_CB_Limit
	FROM
		SystemParameter
	WHERE
		SystemParameterID = 1
	
''

	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunCreateProcedure,''@SQLRunCreateProcedure'',1)

	SET @SQLRunResultTypeBM1 = ''
	IF @ResultTypeBM & 1 > 0 --MetaData
	BEGIN
	--Filter Definition (Template - all other SPs are hard coded in this part). Shall be moved to spGet_PageFilter.

		SELECT 
			@Filter_CB_Limit = Filter_CB_Limit
		FROM
			SystemParameter
		WHERE
			SystemParameterID = 1
		
		IF OBJECT_ID(N''''tempdb..FilterValueCount'''') IS NOT NULL
		BEGIN
			TRUNCATE TABLE #FilterValueCount
			DROP TABLE #FilterValueCount
		END

		CREATE TABLE #FilterValueCount
			(
			[ParameterCode] nvarchar(50) COLLATE DATABASE_DEFAULT, 
			[ParameterCount] int
			)''
	
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunResultTypeBM1,''@SQLRunResultTypeBM1'',1)

	
	SELECT
		@FilterCount = MAX(ParameterID)
		,@FilterLoop = 1
	FROM #FullRecordSets
	WHERE FilterValueSourceString IS NOT NULL


	SET @SQLRunFilterValueCount = CHAR(13) + ''
		SET @SQLExec = ''''''''''

	WHILE (@FilterLoop < (@FilterCount + 1))
	BEGIN
		SELECT
			@SQLRunFilterValueCount = @SQLRunFilterValueCount + ''
		SET @SQLExec = @SQLExec + ''''

		INSERT INTO	#FilterValueCount
			(
			[ParameterCode],
			[ParameterCount]
			)
		SELECT
			[ParameterCode] = '''''''''' + ParameterCode + ''''''''''
			,[ParameterCount] = COUNT(DISTINCT '' + CASE 
														WHEN NULLIF(FilterValueSourceStringCode,'''') IS NOT NULL THEN FilterValueSourceStringCode + ''.'' + REPLACE(FilterValueSourceString,'''''''','''''''''''')
														ELSE REPLACE(FilterValueSourceString,'''''''','''''''''''')
													END
														 + '')
        FROM '' + CASE 
						WHEN NULLIF(FilterTableSourceStringCode,'''') IS NOT NULL THEN FilterTableSourceString + '' '' + FilterTableSourceStringCode
						ELSE FilterTableSourceString
					END
					+ ''
        WHERE
			1 = 1''''''
		FROM #FullRecordSets
		WHERE 
			ParameterID = @FilterLoop
			AND FilterValueSourceString IS NOT NULL
			
		SELECT
			@SQLRunFilterValueCount = @SQLRunFilterValueCount + ''
		SET @SQLExec2 = ''''''''
			''
		SELECT
			@SQLRunFilterValueCount = @SQLRunFilterValueCount + ''

		SET @SQLExec2 = @SQLExec2 + ''''
			AND (@'' + ParameterCode + '' IS NULL OR '' + CASE 
	'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = '													WHEN [NumericBM] = -1 THEN ''CONVERT(DATETIME,''
														ELSE ''''
													END + ''CONVERT(NVARCHAR(MAX),'' + CASE 
																				WHEN NULLIF(FilterValueSourceStringCode,'''') IS NOT NULL THEN FilterValueSourceStringCode + ''.'' + REPLACE(FilterValueSourceString,'''''''','''''''''''')
																				ELSE REPLACE(FilterValueSourceString,'''''''','''''''''''')
																			END
													+ CASE 
														WHEN [NumericBM] = -1 THEN '')''
														ELSE ''''
													END +
																				 + '') '' + --COLLATE DATABASE_DEFAULT 
													+ CASE 
														WHEN ISNULL([FilterValueNumericBM],[NumericBM]) = 0 THEN ''COLLATE DATABASE_DEFAULT ''
														ELSE ''''
													END +
																				 + ''IN (SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''''''','''''''')))''''
																				 ''
			+ CASE 
				WHEN [NumericBM] = -1 THEN ''SELECT 	@SQLExec2 = REPLACE(@SQLExec2,''''REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '''''',''''CONVERT(DATETIME,REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''')) FROM dbo.fnSplitString(@'' + ParameterCode + '''''')''
				ELSE ''''
			END + ''
																				 
		SELECT 	@SQLExec2 = CASE WHEN NULLIF(@'' + ParameterCode + '','''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec2,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''''''','''''''')'''',''''NULL''''),''''@'' + ParameterCode + '''''',''''NULL'''') ELSE REPLACE(@SQLExec2,''''@'' + ParameterCode + '''''','''''''''''''''' + REPLACE(@'' + ParameterCode + '','''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
		'' 
		FROM #FullRecordSets
		WHERE 
			ParameterID <> @FilterLoop
			AND FilterValueSourceString IS NOT NULL
		
		SET @SQLRunFilterValueCount = @SQLRunFilterValueCount + CHAR(13) + ''
		SET @SQLExec = @SQLExec + @SQLExec2
		''
		IF @Debug > 0
			SELECT ''@SQLRunFilterValueCount'',@SQLRunFilterValueCount
		
		SET @FilterLoop = @FilterLoop + 1

	END

	--SET @SQLRunFilterValueCount = @SQLRunFilterValueCount + ''
		
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P01,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P01,'''''''','''''''')'''',''''NULL''''),''''@P01'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P01'''','''''''''''''''' + REPLACE(@P01,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P02,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P02,'''''''','''''''')'''',''''NULL''''),''''@P02'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P02'''','''''''''''''''' + REPLACE(@P02,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P03,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P03,'''''''','''''''')'''',''''NULL''''),''''@P03'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P03'''','''''''''''''''' + REPLACE(@P03,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P04,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P04,'''''''','''''''')'''',''''NULL''''),''''@P04'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P04'''','''''''''''''''' + REPLACE(@P04,'''''''''''''''','''''''''''''''''''
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = ''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P05,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P05,'''''''','''''''')'''',''''NULL''''),''''@P05'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P05'''','''''''''''''''' + REPLACE(@P05,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P06,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P06,'''''''','''''''')'''',''''NULL''''),''''@P06'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P06'''','''''''''''''''' + REPLACE(@P06,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P07,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P07,'''''''','''''''')'''',''''NULL''''),''''@P07'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P07'''','''''''''''''''' + REPLACE(@P07,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P08,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P08,'''''''','''''''')'''',''''NULL''''),''''@P08'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P08'''','''''''''''''''' + REPLACE(@P08,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P09,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P09,'''''''','''''''')'''',''''NULL''''),''''@P09'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P09'''','''''''''''''''' + REPLACE(@P09,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P10,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P10,'''''''','''''''')'''',''''NULL''''),''''@P10'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P10'''','''''''''''''''' + REPLACE(@P10,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	''
		
	--SET @SQLRunFilterValueCount = @SQLRunFilterValueCount + ''
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P11,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P11,'''''''','''''''')'''',''''NULL''''),''''@P11'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P11'''','''''''''''''''' + REPLACE(@P11,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P12,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P12,'''''''','''''''')'''',''''NULL''''),''''@P12'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P12'''','''''''''''''''' + REPLACE(@P12,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P13,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P13,'''''''','''''''')'''',''''NULL''''),''''@P13'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P13'''','''''''''''''''' + REPLACE(@P13,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P14,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''')'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = ' FROM dbo.fnSplitString(@P14,'''''''','''''''')'''',''''NULL''''),''''@P14'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P14'''','''''''''''''''' + REPLACE(@P14,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P15,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P15,'''''''','''''''')'''',''''NULL''''),''''@P15'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P15'''','''''''''''''''' + REPLACE(@P15,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P16,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P16,'''''''','''''''')'''',''''NULL''''),''''@P16'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P16'''','''''''''''''''' + REPLACE(@P16,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P17,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P17,'''''''','''''''')'''',''''NULL''''),''''@P17'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P17'''','''''''''''''''' + REPLACE(@P17,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P18,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P18,'''''''','''''''')'''',''''NULL''''),''''@P18'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P18'''','''''''''''''''' + REPLACE(@P18,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P19,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P19,'''''''','''''''')'''',''''NULL''''),''''@P19'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P19'''','''''''''''''''' + REPLACE(@P19,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P20,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P20,'''''''','''''''')'''',''''NULL''''),''''@P20'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P20'''','''''''''''''''' + REPLACE(@P20,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	''

	SET @SQLRunFilterValueCount = @SQLRunFilterValueCount + ''
		IF @Debug > 0
			SELECT @SQLExec
		-- EXEC(@SQLExec)
		''
	
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunFilterValueCount,''@SQLRunFilterValueCount'',1)

	SET @SQLRunFilterSelect = ''
		IF (@Debug > 0)
		BEGIN
			SELECT
				*
			FROM #FilterValueCount
			
			SELECT @Page

			SELECT
				*
			FROM [dbo].[Page] P
			INNER JOIN [dbo].[PageColumn] PC 
				ON [PC].[PageID] = [P].[PageID] 
				AND [PC].[FilterYN] <> 0 
				AND [PC].[SelectYN] <> 0
			WHERE
				[P].[PageCode] = @Page 
				AND [P].[SelectYN] <> 0
			ORDER BY
				[PC].SortOrder
		END

		SELECT
			[FilterParam] = [wPC].[ParameterCode],
			[FilterCode] = [PC].[ColumnName],
			[FilterCaption] = [PC].[ColumnName],
			[FilterControl] = CASE WHEN FVC.ParameterCount > @Filter_CB_Limit THEN ''''TB'''' ELSE ''''CB'''' END
		FROM [dbo].[Page] P
		INNER JOIN [dbo].[PageColumn] PC 
			ON [PC].[PageID] = [P].[PageID] 
			AND [PC].[FilterYN] <> 0 
			AND [PC].[SelectYN] <> 0
		INNER JOIN wrk_ParameterCode wPC 
			ON [wPC].[ColumnID] = [PC].[ColumnID]
		LEFT JOIN #FilterValueCount FVC 
			ON FVC.[ParameterCode] = [wPC].[ParameterCode]
		WHERE
			[P].[PageCo'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'de] = @Page 
			AND [P].[SelectYN] <> 0
		ORDER BY
			[PC].SortOrder

		IF OBJECT_ID(N''''tempdb..FilterValue'''') IS NOT NULL
		BEGIN
			TRUNCATE TABLE #FilterValue
			DROP TABLE #FilterValue
		END

		CREATE TABLE #FilterValue
			(
			[FilterCode] nvarchar(MAX) COLLATE DATABASE_DEFAULT,
			[FilterValue] nvarchar(MAX) COLLATE DATABASE_DEFAULT,
			[FilterDescription] nvarchar(MAX) COLLATE DATABASE_DEFAULT,
			[SortOrderAlfa] nvarchar(MAX) COLLATE DATABASE_DEFAULT,
			[SortOrderNum] float
			)''
	
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunFilterSelect,''@SQLRunFilterSelect'',1)
	
	SET @SQLRunFilterValue = CHAR(13) + ''
		SET @SQLExec = ''''''''
	''

	SELECT
		@FilterCount = MAX(ParameterID)
		,@FilterLoop = 1
	FROM #FullRecordSets
	WHERE FilterValueSourceString IS NOT NULL
	WHILE (@FilterLoop < (@FilterCount + 1))
	BEGIN
		SELECT DISTINCT
			@SQLRunFilterValue = @SQLRunFilterValue + ''
		SET @SQLExec = @SQLExec + ''''

	IF (SELECT ParameterCount FROM #FilterValueCount WHERE ParameterCode = '''''''''' + ParameterCode + '''''''''') > '''' + CONVERT(NVARCHAR(50),@Filter_CB_Limit) + ''''
		BEGIN
			INSERT INTO #FilterValue
				(
				[FilterCode],
				[FilterValue],
				[FilterDescription],
				[SortOrderAlfa],
				[SortOrderNum]
				)
			SELECT
				[FilterCode] = '''''''''' + ColumnName + '''''''''',
				[FilterValue] = ISNULL(@'' + ParameterCode + '',''''''''''''''''),
				[FilterDescription] = ISNULL(@'' + ParameterCode + '',''''''''''''''''),
				[SortOrderAlfa] = ISNULL(@'' + ParameterCode + '',''''''''''''''''),
				[SortOrderNum] = NULL
			--FROM dbo.[fnSplitString](@'' + ParameterCode + '','''''''','''''''')

		END''''
		
		SELECT 	@SQLExec = CASE WHEN NULLIF(@'' + ParameterCode + '','''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''''''','''''''')'''',''''NULL''''),''''@'' + ParameterCode + '''''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@'' + ParameterCode + '''''','''''''''''''''' + REPLACE(@'' + ParameterCode + '','''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
		''
		FROM #FullRecordSets
		WHERE 
			ParameterID = @FilterLoop
			AND FilterValueSourceString IS NOT NULL
			
		SELECT DISTINCT
			@SQLRunFilterValue = @SQLRunFilterValue + ''
		SET @SQLExec = @SQLExec + ''''

		ELSE
		BEGIN

			INSERT INTO #FilterValue
				(
				[FilterCode],
				[FilterValue],
				[FilterDescription],
				[SortOrderAlfa],
				[SortOrderNum]
				)''''
			''
		FROM #FullRecordSets
		WHERE 
			ParameterID = @FilterLoop
			AND FilterValueSourceString IS NOT NULL

		SELECT DISTINCT
			@SQLRunFilterValue = @SQLRunFilterValue + ''
		IF (NULLIF(@'' + ParameterCode + '','''''''') IS NOT NULL)
		BEGIN
			SET @SQLExec = @SQLExec + ''''
				SELECT 
					[FilterCode] = '''''''''' + ColumnName + '''''''''' COLLATE DATABASE_DEFAULT 
					, [FilterValue] = REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') COLLATE DATABASE_DEFAULT 
					, [FilterDescription] = REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') COLLATE DATABASE_DEFAULT 
					, [SortOrderAlfa] = REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') COLLATE DATABASE_DEFAULT 
					, [SortOrderNum] = NULL
				FROM dbo.[fnSplitString](@'' + ParameterCode + '','''''''','''''''')
				UNION''''

			SELECT 	@SQLExec = REPLACE(@SQLExec,''''@'' + ParameterCode + '''''','''''''''''''''' + REPLACE(@'' + ParameterCode + '','''''''''''''''','''''''''''''''''''''''') + '''''''''''''''')
		END

		SET @SQLExec = @SQLExec + ''''
			SELECT DISTINCT
				[FilterCode] = '''''''''' + ColumnName + '''''''''',
				[FilterValue] = CONVERT(NVARCHAR(MAX),'' + CASE 
										WHEN [Numer'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'icBM] = 0 THEN '''' + CASE 
																		WHEN NULLIF(FilterValueSourceStringCode,'''') IS NULL THEN REPLACE(FilterValueSourceString,'''''''','''''''''''')
																		ELSE FilterValueSourceStringCode + ''.'' + REPLACE(FilterValueSourceString,'''''''','''''''''''')
																	END + '' '' 
										WHEN [NumericBM] = -1 THEN ''dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),'' + CASE 
																							WHEN NULLIF(FilterValueSourceStringCode,'''') IS NULL THEN REPLACE(FilterValueSourceString,'''''''','''''''''''')
																							ELSE FilterValueSourceStringCode + ''.'' + REPLACE(FilterValueSourceString,'''''''','''''''''''')
																						END + ''),'' + @DateFormat + '')'' 
										WHEN [NumericBM] = 1 THEN ''CONVERT(INT,'' + CASE 
																						WHEN NULLIF(FilterValueSourceStringCode,'''') IS NULL THEN REPLACE(FilterValueSourceString,'''''''','''''''''''')
																						ELSE FilterValueSourceStringCode + ''.'' + REPLACE(FilterValueSourceString,'''''''','''''''''''')
																					END + '') '' 
										WHEN [NumericBM] = 2 THEN ''dbo.fnFormatCurrency('' + CASE 
																								WHEN NULLIF(FilterValueSourceStringCode,'''') IS NULL THEN REPLACE(FilterValueSourceString,'''''''','''''''''''')
																								ELSE FilterValueSourceStringCode + ''.'' + REPLACE(FilterValueSourceString,'''''''','''''''''''')
																							END + '','' + @CurrencyFormat + '') '' 
										ELSE ''CONVERT(NVARCHAR(MAX),'' + CASE 
																			WHEN NULLIF(FilterValueSourceStringCode,'''') IS NULL THEN REPLACE(FilterValueSourceString,'''''''','''''''''''')
																			ELSE FilterValueSourceStringCode + ''.'' + REPLACE(FilterValueSourceString,'''''''','''''''''''')
																		END + '') '' 
									END
									
									+ ''),
				[FilterDescription] = CONVERT(NVARCHAR(MAX),'' + CASE 
											WHEN [NumericBM] = 0 THEN '''' + CASE 
																			WHEN NULLIF(FilterDescriptionSourceStringCode,'''') IS NULL THEN REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																			ELSE FilterDescriptionSourceStringCode + ''.'' + REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																		END + '' '' 
											WHEN [NumericBM] = -1 THEN ''dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),'' + CASE 
																								WHEN NULLIF(FilterDescriptionSourceStringCode,'''') IS NULL THEN REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																								ELSE FilterDescriptionSourceStringCode + ''.'' + REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																							END + ''),'' + @DateFormat + '')'' 
											WHEN [NumericBM] = 1 THEN ''CONVERT(INT,'' + CASE 
																							WHEN NULLIF(FilterDescriptionSourceStringCode,'''') IS NULL THEN REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																							ELSE FilterDescriptionSourceStringCode + ''.'' + REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																						END + '') '' 
											WHEN [NumericBM] = 2 THEN ''dbo.fnFormatCurrency('' + CASE 
																									WHEN NULLIF(FilterDescriptionSourceStringCode,'''') IS NULL THEN REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																									ELSE FilterDescriptionSourceStringCode + ''.'' + REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																								END + '','' + @CurrencyFormat + '') '' 
											ELSE ''CONVERT(NVARCHAR(MAX),'' + CASE 
																				WHEN NULLIF(FilterDescriptionSourceStringCode,'''') IS NULL THEN REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																				ELSE FilterDescriptionSourceStringCode + ''.'' + REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																			END + '') '' 
										END
						'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = '				+ ''),
				[SortOrderAlfa] = CONVERT(NVARCHAR(MAX),'' + CASE 
																WHEN [NumericBM] = 0 THEN '''' + CASE 
																								WHEN NULLIF(FilterDescriptionSourceStringCode,'''') IS NULL THEN REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																								ELSE FilterDescriptionSourceStringCode + ''.'' + REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																							END + '' '' 
																WHEN [NumericBM] = -1 THEN ''dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),'' + CASE 
																													WHEN NULLIF(FilterDescriptionSourceStringCode,'''') IS NULL THEN REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																													ELSE FilterDescriptionSourceStringCode + ''.'' + REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																												END + ''),'' + @DateFormat + '')'' 
																WHEN [NumericBM] = 1 THEN ''CONVERT(INT,'' + CASE 
																												WHEN NULLIF(FilterDescriptionSourceStringCode,'''') IS NULL THEN REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																												ELSE FilterDescriptionSourceStringCode + ''.'' + REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																											END + '') '' 
																WHEN [NumericBM] = 2 THEN ''dbo.fnFormatCurrency('' + CASE 
																														WHEN NULLIF(FilterDescriptionSourceStringCode,'''') IS NULL THEN REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																														ELSE FilterDescriptionSourceStringCode + ''.'' + REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																													END + '','' + @CurrencyFormat + '') '' 
																ELSE ''CONVERT(NVARCHAR(MAX),'' + CASE 
																									WHEN NULLIF(FilterDescriptionSourceStringCode,'''') IS NULL THEN REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																									ELSE FilterDescriptionSourceStringCode + ''.'' + REPLACE(FilterDescriptionSourceString,'''''''','''''''''''')
																								END + '') '' 
															END
															+ ''),
				[SortOrderNum] = NULL
			FROM '' + CASE 
						WHEN NULLIF(FilterTableSourceStringCode,'''') IS NOT NULL THEN FilterTableSourceString + '' '' + FilterTableSourceStringCode
						ELSE FilterTableSourceString
					END
					+ ''
			WHERE
				1 = 1''''''
		FROM #FullRecordSets
		WHERE 
			ParameterID = @FilterLoop
			AND FilterValueSourceString IS NOT NULL

		SELECT
			@SQLRunFilterValue = @SQLRunFilterValue + ''
		SET @SQLExec2 = ''''''''''

		SELECT
			@SQLRunFilterValue = @SQLRunFilterValue + ''

		SET @SQLExec2 = @SQLExec2 + ''''
				AND (@'' + ParameterCode + '' IS NULL OR '' + CASE 
														WHEN [NumericBM] = -1 THEN ''CONVERT(DATETIME,''
														ELSE ''''
													END + ''CONVERT(NVARCHAR(MAX),'' + CASE 
																				WHEN NULLIF(FilterValueSourceStringCode,'''') IS NOT NULL THEN FilterValueSourceStringCode + ''.'' + REPLACE(FilterValueSourceString,'''''''','''''''''''')
																				ELSE REPLACE(FilterValueSourceString,'''''''','''''''''''')
																			END
													+ CASE 
														WHEN [NumericBM] = -1 THEN '')''
														ELSE ''''
													END + '') '' + --COLLATE DATABASE_DEFAULT 
													+ CASE 
														WHEN ISNULL([FilterValueNumericBM],[NumericBM]) = 0 THEN ''COLLATE DATABASE_DEFAULT ''
														ELSE ''''
													END +
																				 + ''IN (SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''''''','''''''')))''''''
		+ CASE 
			WHEN [NumericBM] = -1 THEN ''SELECT 	@SQLExec2 = REPLACE(@SQLExec2,''''REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplit'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'String(@'' + ParameterCode + '''''',''''CONVERT(DATETIME,REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''')) FROM dbo.fnSplitString(@'' + ParameterCode + '''''')''
			ELSE ''''
		END + ''
																				 
		SELECT 	@SQLExec2 = CASE WHEN NULLIF(@'' + ParameterCode + '','''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec2,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''''''','''''''')'''',''''NULL''''),''''@'' + ParameterCode + '''''',''''NULL'''') ELSE REPLACE(@SQLExec2,''''@'' + ParameterCode + '''''','''''''''''''''' + REPLACE(@'' + ParameterCode + '','''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
		'' 
		FROM #FullRecordSets
		WHERE 
			ParameterID <> @FilterLoop
			AND FilterValueSourceString IS NOT NULL

		SET @SQLRunFilterValue = @SQLRunFilterValue + ''
		SET @SQLExec = @SQLExec + @SQLExec2

		SET @SQLExec = @SQLExec + ''''
		END
		''''''

		SET @FilterLoop = @FilterLoop + 1

	END
	
	--SET @SQLRunFilterValue = @SQLRunFilterValue + ''
		
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P01,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P01,'''''''','''''''')'''',''''NULL''''),''''@P01'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P01'''','''''''''''''''' + REPLACE(@P01,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P02,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P02,'''''''','''''''')'''',''''NULL''''),''''@P02'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P02'''','''''''''''''''' + REPLACE(@P02,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P03,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P03,'''''''','''''''')'''',''''NULL''''),''''@P03'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P03'''','''''''''''''''' + REPLACE(@P03,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P04,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P04,'''''''','''''''')'''',''''NULL''''),''''@P04'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P04'''','''''''''''''''' + REPLACE(@P04,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P05,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P05,'''''''','''''''')'''',''''NULL''''),''''@P05'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P05'''','''''''''''''''' + REPLACE(@P05,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P06,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P06,'''''''','''''''')'''',''''NULL''''),''''@P06'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P06'''','''''''''''''''' + REPLACE(@P06,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P07,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P07,'''''''','''''''')'''',''''NULL''''),''''@P07'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P07'''','''''''''''''''' + REPLACE(@P07,'''''''''''''''','''''''''''''''''''''''') + '''''
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = ''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P08,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P08,'''''''','''''''')'''',''''NULL''''),''''@P08'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P08'''','''''''''''''''' + REPLACE(@P08,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P09,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P09,'''''''','''''''')'''',''''NULL''''),''''@P09'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P09'''','''''''''''''''' + REPLACE(@P09,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P10,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P10,'''''''','''''''')'''',''''NULL''''),''''@P10'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P10'''','''''''''''''''' + REPLACE(@P10,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	''
		
	--SET @SQLRunFilterValue = @SQLRunFilterValue + ''
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P11,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P11,'''''''','''''''')'''',''''NULL''''),''''@P11'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P11'''','''''''''''''''' + REPLACE(@P11,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P12,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P12,'''''''','''''''')'''',''''NULL''''),''''@P12'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P12'''','''''''''''''''' + REPLACE(@P12,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P13,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P13,'''''''','''''''')'''',''''NULL''''),''''@P13'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P13'''','''''''''''''''' + REPLACE(@P13,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P14,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P14,'''''''','''''''')'''',''''NULL''''),''''@P14'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P14'''','''''''''''''''' + REPLACE(@P14,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P15,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P15,'''''''','''''''')'''',''''NULL''''),''''@P15'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P15'''','''''''''''''''' + REPLACE(@P15,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P16,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P16,'''''''','''''''')'''',''''NULL''''),''''@P16'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P16'''','''''''''''''''' + REPLACE(@P16,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P17,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = '(@P17,'''''''','''''''')'''',''''NULL''''),''''@P17'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P17'''','''''''''''''''' + REPLACE(@P17,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P18,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P18,'''''''','''''''')'''',''''NULL''''),''''@P18'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P18'''','''''''''''''''' + REPLACE(@P18,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P19,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P19,'''''''','''''''')'''',''''NULL''''),''''@P19'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P19'''','''''''''''''''' + REPLACE(@P19,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	SELECT 	@SQLExec = CASE WHEN NULLIF(@P20,'''''''') IS NULL THEN REPLACE(REPLACE(@SQLExec,''''SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@P20,'''''''','''''''')'''',''''NULL''''),''''@P20'''',''''NULL'''') ELSE REPLACE(@SQLExec,''''@P20'''','''''''''''''''' + REPLACE(@P20,'''''''''''''''','''''''''''''''''''''''') + '''''''''''''''') END
	--	''

	SET @SQLRunFilterValue = @SQLRunFilterValue + ''
		IF @Debug > 0
			SELECT @SQLExec
		-- EXEC(@SQLExec)
		''

	SET @SQLRunFilterValue = @SQLRunFilterValue + ''

	 	SELECT
			FilterCode,
			FilterValue,
			FilterDescription
		FROM
			#FilterValue
		ORDER BY
			FilterCode, SortOrderAlfa, SortOrderNum, FilterValue

	END
	''

	SELECT 
		@SQLRunFilterValue = @SQLRunFilterValue + ''
	IF OBJECT_ID(N''''tempdb..#RecordSetsSQL'''') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #RecordSetsSQL
		DROP TABLE #RecordSetsSQL
	END

	CREATE TABLE #RecordSetsSQL (
		RecordSetID INT
		,ResultTypeBM INT
		,IfNotExist NVARCHAR(MAX)
		,IfNotExistOriginal NVARCHAR(MAX)
		,ColumnSet NVARCHAR(MAX)
		,ColumnSetOriginal NVARCHAR(MAX)
		,RecordSet NVARCHAR(MAX)
		,RecordSetOriginal NVARCHAR(MAX)
	)

	IF OBJECT_ID(N''''tempdb..#FiltersSQL'''') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #FiltersSQL
		DROP TABLE #FiltersSQL
	END

	CREATE TABLE #FiltersSQL (
		ParameterCode NVARCHAR(100)
		,ColumnName NVARCHAR(MAX)
		,isLinked INT
	)


	''
	

	SELECT
		@SQLRunFilterValue = @SQLRunFilterValue + ''

		INSERT INTO #FiltersSQL
		(
			ParameterCode
			,ColumnName
			,isLinked
		)
		SELECT
			ParameterCode = '''''' + ParameterCode + ''''''
			,ColumnName = '''''' + ColumnName + ''''''
			,isLinked = CASE 
							WHEN @ShowFilterColumnsYN = 1 THEN 1 
							ELSE '' + CASE WHEN isLinked = 1 THEN ''1'' ELSE ''0'' END + ''
						END
	''
	FROM (
		SELECT DISTINCT
			FRS.ColumnName
			--,FRS.ColumnID
			,FRS.FilterValueSourceString
			,FRS.ParameterCode
			,isLinked = CASE 
							WHEN LC.ColumnID IS NULL THEN 0
							WHEN PCLC.PageID = PCFRS.PageID THEN 0
							ELSE 1
						END
		FROM #FullRecordSets FRS
		LEFT JOIN (
			SELECT DISTINCT
				ColumnID
				,LinkColumnID
			FROM #LinkColumns
		) AS LC
			ON LC.ColumnID = FRS.ColumnID
		LEFT JOIN dbo.PageColumn PCFRS
			ON PCFRS.ColumnID = FRS.ColumnID
		LEFT JOIN dbo.PageColumn PCLC
			ON PCLC.ColumnID = LC.LinkColumnID
		WHERE 
			FirstRecordsetColumnSourceString IS NOT NULL
	) AS T
	WHERE NULLIF(FilterValueSourceString,'''') IS NOT NULL

	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunFilterValue,''@SQLRunFilterValue'',1)

	SET @SQLRunDataInsertFirstRecordSetsSQL = ''''

	/*
		RecordSets
	*/
	IF @Debug <> 0 
	BEGIN
		SELECT A = ''#FullRecordSets'', * FROM #FullRecordSets
	END

	SELECT 
		@SQLRunDataFirstRecord'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'SetStart = ''

		IF @ResultTypeBM & 2 > 0 --Result Set Based
		BEGIN
	''
	FROM #FullRecordSets
	WHERE NULLIF(FirstRecordsetTableSourceString,'''') IS NOT NULL

	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunDataFirstRecordSetStart,''@SQLRunDataFirstRecordSetStart'',1)

	SET	@SQLRunDataFirstRecordSetIfNotExist = ''''

	SELECT DISTINCT
		@SQLRunDataFirstRecordSetIfNotExist = @SQLRunDataFirstRecordSetIfNotExist + ''
			IF NOT EXISTS(
				SELECT 
					1
				FROM '' + CASE 
							WHEN NULLIF(FirstRecordsetTableSourceStringCode,'''') IS NULL THEN FirstRecordsetTableSourceString
							ELSE FirstRecordsetTableSourceString + '' '' + FirstRecordsetTableSourceStringCode
						END + ''
				WHERE
			 		1 = 1''
	FROM #FullRecordSets
	WHERE 
		FirstRecordsetColumnSourceString IS NOT NULL

	SELECT
		@SQLRunDataFirstRecordSetIfNotExist = @SQLRunDataFirstRecordSetIfNotExist + ''
					AND ('' + CASE 
								WHEN NULLIF(FilterValueSourceStringCode,'''') IS NULL THEN FilterValueSourceString
								ELSE FilterValueSourceStringCode + ''.'' + FilterValueSourceString
							END 
					 + '' '' + CASE WHEN ISNULL([FilterValueNumericBM],[NumericBM]) = 0 THEN ''COLLATE DATABASE_DEFAULT '' ELSE '''' END
					 + ''IN (SELECT REPLACE(SplitReturn,'''''''''''''''','''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''','''')) OR @'' + ParameterCode + '' IS NULL)''
	FROM #FullRecordSets
	WHERE FilterValueSourceString IS NOT NULL

	SELECT
		@SQLRunDataFirstRecordSetIfNotExist = @SQLRunDataFirstRecordSetIfNotExist + ''
			)
			BEGIN
				SELECT
					Result = ''''No Data on the Result Set.''''
				RETURN
			END'' 

	IF (@Debug > 1)
	BEGIN
		SELECT ''@SQLRunDataFirstRecordSetIfNotExist'',@SQLRunDataFirstRecordSetIfNotExist
	END
	
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunDataFirstRecordSetIfNotExist,''@SQLRunDataFirstRecordSetIfNotExist'',0)

	SET @SQLRunDataRecordSetColumns = ''''

	SELECT 
		@SQLRunDataRecordSetColumns = @SQLRunDataRecordSetColumns + 
					CASE 
						WHEN NULLIF(@SQLRunDataRecordSetColumns,'''') IS NULL THEN ''
				'' + ColumnName 
						ELSE '','' + ''
				'' + ColumnName 
					END
	FROM #FullRecordSets
	WHERE 
		FirstRecordsetColumnSourceString IS NOT NULL
	ORDER BY SortOrder ASC

	SET @SQLRunDataFirstRecordSetColumns = ''

			SELECT DISTINCT TOP '' + CONVERT(NVARCHAR(5),@ReturnRowLimit)

	SET @SQLRunDataFirstRecordSetColumns = @SQLRunDataFirstRecordSetColumns + @SQLRunDataRecordSetColumns
	
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunDataFirstRecordSetColumns,''@SQLRunDataFirstRecordSetColumns'',0)

	IF (@Debug > 1)
	BEGIN
		SELECT ''@SQLRunDataFirstRecordSetColumns'',@SQLRunDataFirstRecordSetColumns
	END

	SET @SQLRunDataFirstRecordSet = ''''

	SELECT
		@SQLRunDataFirstRecordSet = @SQLRunDataFirstRecordSet + CHAR(13)
		+ ''			FROM (
				SELECT TOP ''  + CONVERT(NVARCHAR(5),@ReturnRowLimit * 2)

	IF (@Debug > 1)
	BEGIN
		SELECT ''5'',@SQLRunDataFirstRecordSet
	END

	SET @SQLRunDataRecordSetColumns = ''''
	
	SELECT
		@SQLRunDataRecordSetColumns = @SQLRunDataRecordSetColumns + ''
					'' + CASE --CASE START
							WHEN NULLIF(@SQLRunDataRecordSetColumns,'''') IS NULL THEN ColumnName 
							+ '' = '' + CASE
											WHEN MidLinkCase IS NOT NULL 
											THEN + CASE 
													WHEN [NumericBM] = 0 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = -1 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = 1 THEN ''''''<label id="CellAlignRight">'''' + '' 
													WHEN [NumericBM] = -2 THEN ''''''<label id="CellAlignCenter">'''' + '' 
													WHEN [NumericBM] = 2 THEN ''''''<label id="CellAlignRight">'''' + '' 
													ELSE ''''''<label id="CellAlignLeft">'''' + '' 
												END
											+ ''CASE'' + CHAR(13) + '
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'MidLinkCase
											+ ''										ELSE'' + 
											+ CASE 
													WHEN [NumericBM] = 0 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = -1 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = 1 THEN ''''''<label id="CellAlignRight">'''' + '' 
													WHEN [NumericBM] = -2 THEN ''''''<label id="CellAlignCenter">'''' + '' 
													WHEN [NumericBM] = 2 THEN ''''''<label id="CellAlignRight">'''' + '' 
													ELSE ''''''<label id="CellAlignLeft">'''' + '' 
												END
											+ 
											+ ''CONVERT(NVARCHAR(MAX),'' + CASE 
																			WHEN [NumericBM] = 0 THEN '''' + CASE
																											WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																											ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																										END
																			WHEN [NumericBM] = -1 THEN ''dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),'' + CASE
																																WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																																ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																															END + ''),'' + @DateFormat + '')'' 
																			WHEN [NumericBM] = 1 THEN ''CONVERT(INT,'' + CASE
																															WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																															ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																														END + '')''
																			WHEN [NumericBM] = -2 THEN ''CONVERT(NVARCHAR(MAX),CONVERT(BIT,'' + CASE
																															WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																															ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																														END + ''))''
																			WHEN [NumericBM] = 2 THEN ''dbo.fnFormatCurrency('' + CASE
																																	WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																																	ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																																END + '','' + @CurrencyFormat + '')''
																			ELSE ''CONVERT(NVARCHAR(MAX),'' + CASE
																												WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																												ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																											END + '')''
																		END 
																+ '')'' + CHAR(13) 
											+ ''									END'' + '' + ''''</label>''''''
											ELSE
												+ CASE 
														WHEN [NumericBM] = 0 THEN ''''''<label id="CellAlignLeft">'''' + '' 
														WHEN [NumericBM] = -1 THEN ''''''<label id="CellAlignLeft">'''' + '' 
														WHEN [NumericBM] = 1 THEN ''''''<label id="CellAlignRight">'''' + '' 
														WHEN [NumericBM] = -2 THEN ''''''<label id="CellAlignCenter">'''' + '' 
														WHEN [NumericBM] = 2 THEN ''''''<label id="CellAlignRight">'''' + '' 
														ELSE ''''''<label id="CellAlignLeft">'''' + '' 
													END
													+ ''CONVERT(NVARCHAR(MAX),'' +
													CASE 
														WHEN [NumericBM] = 0 THEN '''' + CASE
																						WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																						ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
								'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = '													END
														WHEN [NumericBM] = -1 THEN ''dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),'' + CASE
																											WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																											ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																										END + ''),'' + @DateFormat + '')'' 
														WHEN [NumericBM] = 1 THEN ''CONVERT(INT,'' + CASE
																										WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																										ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																									END + '')''
														WHEN [NumericBM] = -2 THEN ''CONVERT(BIT,'' + CASE
																										WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																										ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																									END + '')''
														WHEN [NumericBM] = 2 THEN ''dbo.fnFormatCurrency('' + CASE
																												WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																												ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																											END + '','' + @CurrencyFormat + '')''
														ELSE ''CONVERT(NVARCHAR(MAX),'' + CASE
																							WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																							ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																						END + '')''
													END
													+ '')''
													+ '' + ''''</label>''''''
											END 
							ELSE '','' --ELSE BEGIN
							+ ColumnName 
							+ '' = '' + CASE
											WHEN MidLinkCase IS NOT NULL 
											THEN + CASE 
													WHEN [NumericBM] = 0 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = -1 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = 1 THEN ''''''<label id="CellAlignRight">'''' + '' 
													WHEN [NumericBM] = -2 THEN ''''''<label id="CellAlignCenter">'''' + '' 
													WHEN [NumericBM] = 2 THEN ''''''<label id="CellAlignRight">'''' + '' 
													ELSE ''''''<label id="CellAlignLeft">'''' + '' 
												END
											+ ''CASE'' + CHAR(13) + MidLinkCase
											+ ''										ELSE'' + 
											+ CASE 
													WHEN [NumericBM] = 0 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = -1 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = 1 THEN ''''''<label id="CellAlignRight">'''' + '' 
													WHEN [NumericBM] = -2 THEN ''''''<label id="CellAlignCenter">'''' + '' 
													WHEN [NumericBM] = 2 THEN ''''''<label id="CellAlignRight">'''' + '' 
													ELSE ''''''<label id="CellAlignLeft">'''' + '' 
												END
											+ 
											+ ''CONVERT(NVARCHAR(MAX),'' + CASE 
																			WHEN [NumericBM] = 0 THEN '''' + CASE
																											WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																											ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																										END
																			WHEN [NumericBM] = -1 THEN ''dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),'' + CASE
																																WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																																ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = '
																															END + ''),'' + @DateFormat + '')'' 
																			WHEN [NumericBM] = 1 THEN ''CONVERT(INT,'' + CASE
																															WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																															ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																														END + '')''
																			WHEN [NumericBM] = -2 THEN ''CONVERT(NVARCHAR(MAX),CONVERT(BIT,'' + CASE
																															WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																															ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																														END + ''))''
																			WHEN [NumericBM] = 2 THEN ''dbo.fnFormatCurrency('' + CASE
																																	WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																																	ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																																END + '','' + @CurrencyFormat + '')''
																			ELSE ''CONVERT(NVARCHAR(MAX),'' + CASE
																												WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																												ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																											END + '')''
																		END 
																+ '')'' + CHAR(13) 
											+ ''									END'' + '' + ''''</label>''''''
											ELSE
												+ CASE 
														WHEN [NumericBM] = 0 THEN ''''''<label id="CellAlignLeft">'''' + '' 
														WHEN [NumericBM] = -1 THEN ''''''<label id="CellAlignLeft">'''' + '' 
														WHEN [NumericBM] = 1 THEN ''''''<label id="CellAlignRight">'''' + '' 
														WHEN [NumericBM] = -2 THEN ''''''<label id="CellAlignCenter">'''' + '' 
														WHEN [NumericBM] = 2 THEN ''''''<label id="CellAlignRight">'''' + '' 
														ELSE ''''''<label id="CellAlignLeft">'''' + '' 
													END
												+ ''CONVERT(NVARCHAR(MAX),'' +
												CASE 
													WHEN [NumericBM] = 0 THEN '''' + CASE
																					WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																					ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																				END
													WHEN [NumericBM] = -1 THEN ''dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),'' + CASE
																										WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																										ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																									END + ''),'' + @DateFormat + '')'' 
													WHEN [NumericBM] = 1 THEN ''CONVERT(INT,'' + CASE
																									WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																									ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																								END + '')''
													WHEN [NumericBM] = -2 THEN ''CONVERT(BIT,'' + CASE
																									WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																									ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																								END + '')''
													WHEN [NumericBM] = 2 THEN ''dbo.fnFormatCurrency('' + CASE
																											WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																									'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = '		ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																										END + '','' + @CurrencyFormat + '')''
													ELSE ''CONVERT(NVARCHAR(MAX),'' + CASE
																						WHEN NULLIF(FirstRecordsetColumnSourceStringCode,'''') IS NULL THEN FirstRecordsetColumnSourceString
																						ELSE FirstRecordsetColumnSourceStringCode + ''.'' + FirstRecordsetColumnSourceString
																					END + '')''
												END
												+ '')''
												+ '' + ''''</label>''''''
									END --ELSE END
						END--CASE END
	FROM (
		SELECT DISTINCT
			FRS.ColumnName
			,LC.InvalidValues
			,LC.MidLinkCase
			,FirstRecordsetColumnSourceString
			,FirstRecordsetColumnSourceStringCode
			,FRS.SortOrder
			,FRS.NumericBM
		FROM #FullRecordSets FRS
		LEFT JOIN (
			SELECT
				ColumnID
				,MidLinkCase = MAX(MidLinkCase)
				,InvalidValues = MAX(InvalidValues)
			FROM #LinkColumns
			GROUP BY ColumnID
		) AS LC
			ON LC.ColumnID = FRS.ColumnID
		WHERE 
			FirstRecordsetColumnSourceString IS NOT NULL
	) AS T
	ORDER BY SortOrder ASC

	SET @SQLRunDataFirstRecordSet = @SQLRunDataFirstRecordSet + @SQLRunDataRecordSetColumns
	
	IF (@Debug > 1)
	BEGIN
		SELECT ''6'',@SQLRunDataFirstRecordSet
	END

	SELECT DISTINCT
		@SQLRunDataFirstRecordSet = @SQLRunDataFirstRecordSet + ''
				FROM '' + CASE 
							WHEN NULLIF(FirstRecordsetTableSourceStringCode,'''') IS NULL THEN FirstRecordsetTableSourceString
							ELSE FirstRecordsetTableSourceString + '' '' + FirstRecordsetTableSourceStringCode
						END
	FROM #FullRecordSets
	WHERE 
		FirstRecordsetColumnSourceString IS NOT NULL

	IF (@Debug > 1)
	BEGIN
		SELECT ''7'',@SQLRunDataFirstRecordSet
	END

	SET @SQLRunDataFirstRecordSet = @SQLRunDataFirstRecordSet + ''
				WHERE
			 		1 = 1''

	SELECT
		@SQLRunDataFirstRecordSet = @SQLRunDataFirstRecordSet + ''
					AND ('' + CASE 
								WHEN NULLIF(FilterValueSourceStringCode,'''') IS NULL THEN FilterValueSourceString
								ELSE FilterValueSourceStringCode + ''.'' + FilterValueSourceString
							END
					 + '' '' + CASE WHEN ISNULL([FilterValueNumericBM],[NumericBM]) = 0 THEN ''COLLATE DATABASE_DEFAULT '' ELSE '''' END
					 + ''IN (SELECT REPLACE(SplitReturn,'''''''''''''''','''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''','''')) OR @'' + ParameterCode + '' IS NULL)''
	FROM #FullRecordSets
	WHERE FilterValueSourceString IS NOT NULL
			
	IF (@Debug > 1)
	BEGIN
		SELECT ''8'',@SQLRunDataFirstRecordSet
	END

	SET @SQLRunDataFirstRecordSet = @SQLRunDataFirstRecordSet + ''
			) AS T''
			
	IF (@Debug > 1)
	BEGIN
		SELECT ''@SQLRunDataFirstRecordSet'',@SQLRunDataFirstRecordSet
	END
	
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunDataFirstRecordSet,''@SQLRunDataFirstRecordSet'',0)

	SET @SQLRunDataInsertFirstRecordSetsSQL = ''''

	SET @SQLRunDataInsertFirstRecordSetsSQL = @SQLRunDataInsertFirstRecordSetsSQL + ISNULL(''
		INSERT INTO #RecordSetsSQL
		(
			RecordSetID
			,ResultTypeBM
			,IfNotExist 
			,IfNotExistOriginal
			,ColumnSet 
			,ColumnSetOriginal
			,RecordSet
			,RecordSetOriginal
		)
		SELECT
			RecordSetID = 1 --Result Set Based
			,ResultTypeBM = 2 --Result Set Based
			,IfNotExist = '''''' + REPLACE(@SQLRunDataFirstRecordSetIfNotExist,'''''''','''''''''''') + ''''''
			,IfNotExistOriginal = '''''' + REPLACE(@SQLRunDataFirstRecordSetIfNotExist,'''''''','''''''''''') + ''''''
			,ColumnSet = '''''' + REPLACE(@SQLRunDataFirstRecordSetColumns,'''''''','''''''''''') + ''''''
			,ColumnSetOriginal = '''''' + REPLACE(@SQLRunDataFirstRecordSetColumns,'''''''','''''''''''') + ''''''
			,RecordSet = '''''' + REPLACE(@SQLRunDataFirstRecordSet,'''''''','''''''''''') + ''''''
			,RecordSetOriginal = '''''' + REPLACE(@SQLRunDataFirstRecordSet,'''''''','
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = ''''''''''''') + ''''''
	'','''')
	--@SQLRunDataFirstRecordSetColumns
	
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunDataInsertFirstRecordSetsSQL,''@SQLRunDataInsertFirstRecordSetsSQL'',1)
	
	SET @SQLRunDataFirstRecordSetEnd = ''

		SELECT
			@SQLExec = IfNotExist + ColumnSet + RecordSet
		FROM #RecordSetsSQL
		WHERE RecordSetID = 1 --Result Set Based

		IF @Debug > 0
		BEGIN
			SELECT 
				@SQLExec
		END
		
		IF @Debug > 1
		BEGIN
			SELECT 
				*
			FROM #RecordSetsSQL
		END

		EXEC dbo.sp_executesql @statement = @SQLExec
		''

	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunDataFirstRecordSetEnd,''@SQLRunDataFirstRecordSetEnd'',1)
	
	IF EXISTS(
		SELECT 1 
		FROM #FullRecordSets
		WHERE NULLIF(SecondRecordsetTableSourceString,'''') IS NOT NULL)
	BEGIN
		SELECT 
			@SQLRunDataSecondRecordSetStart = ''

			IF @ResultTypeBM & 4 > 0 --Result Set Based
			BEGIN
		''
		FROM #FullRecordSets
		WHERE NULLIF(SecondRecordsetTableSourceString,'''') IS NOT NULL

		INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
		VALUES (@SQLRunDataSecondRecordSetStart,''@SQLRunDataSecondRecordSetStart'',1)

		SET	@SQLRunDataSecondRecordSetIfNotExist = ''''

		SELECT DISTINCT
			@SQLRunDataSecondRecordSetIfNotExist = @SQLRunDataSecondRecordSetIfNotExist + ''
				IF NOT EXISTS(
					SELECT 
						1
					FROM '' + CASE 
								WHEN NULLIF(SecondRecordsetTableSourceStringCode,'''') IS NULL THEN SecondRecordsetTableSourceString
								ELSE SecondRecordsetTableSourceString + '' '' + SecondRecordsetTableSourceStringCode
							END + ''
					WHERE
			 			1 = 1''
		FROM #FullRecordSets
		WHERE 
			SecondRecordsetColumnSourceString IS NOT NULL

		SELECT
			@SQLRunDataSecondRecordSetIfNotExist = @SQLRunDataSecondRecordSetIfNotExist + ''
						AND ('' + CASE 
									WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
									ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
								END
					 + '' '' + CASE WHEN ISNULL([FilterValueNumericBM],[NumericBM]) = 0 THEN ''COLLATE DATABASE_DEFAULT '' ELSE '''' END
					 + ''IN (SELECT REPLACE(SplitReturn,'''''''''''''''','''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''','''')) OR @'' + ParameterCode + '' IS NULL)''
		FROM #FullRecordSets
		WHERE FilterValueSourceString IS NOT NULL

		SELECT
			@SQLRunDataSecondRecordSetIfNotExist = @SQLRunDataSecondRecordSetIfNotExist + ''
				)
				BEGIN
					SELECT
						Result = ''''No Data on the Result Set.''''
					RETURN
				END'' 

		IF (@Debug > 1)
		BEGIN
			SELECT ''@SQLRunDataSecondRecordSetIfNotExist'',@SQLRunDataSecondRecordSetIfNotExist
		END
	
		INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
		VALUES (@SQLRunDataSecondRecordSetIfNotExist,''@SQLRunDataSecondRecordSetIfNotExist'',0)

		SET @SQLRunDataRecordSetColumns = ''''

		SELECT 
			@SQLRunDataRecordSetColumns = @SQLRunDataRecordSetColumns + 
						CASE 
							WHEN NULLIF(@SQLRunDataRecordSetColumns,'''') IS NULL THEN ''
					'' + ColumnName 
							ELSE '','' + ''
					'' + ColumnName 
						END
		FROM #FullRecordSets
		WHERE 
			SecondRecordsetColumnSourceString IS NOT NULL
		ORDER BY SortOrder ASC

		SET @SQLRunDataSecondRecordSetColumns = ''

				SELECT TOP '' + CONVERT(NVARCHAR(5),@ReturnRowLimit)

		SET @SQLRunDataSecondRecordSetColumns = @SQLRunDataSecondRecordSetColumns + @SQLRunDataRecordSetColumns
	
		INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
		VALUES (@SQLRunDataSecondRecordSetColumns,''@SQLRunDataSecondRecordSetColumns'',0)

		IF (@Debug > 1)
		BEGIN
			SELECT ''@SQLRunDataSecondRecordSetColumns'',@SQLRunDataSecondRecordSetColumns
		END

		SET @SQLRunDataSecondRecordSet = ''''

		SELECT
			@SQLRunDat'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'aSecondRecordSet = @SQLRunDataSecondRecordSet + CHAR(13)
			+ ''			FROM (
					SELECT DISTINCT''

		IF (@Debug > 1)
		BEGIN
			SELECT ''5'',@SQLRunDataSecondRecordSet
		END

	SET @SQLRunDataRecordSetColumns = ''''
	
	SELECT
		@SQLRunDataRecordSetColumns = @SQLRunDataRecordSetColumns + ''
					'' + CASE --CASE START
							WHEN NULLIF(@SQLRunDataRecordSetColumns,'''') IS NULL THEN ColumnName 
							+ '' = '' + CASE
											WHEN MidLinkCase IS NOT NULL 
											THEN + CASE 
													WHEN [NumericBM] = 0 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = -1 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = 1 THEN ''''''<label id="CellAlignRight">'''' + '' 
													WHEN [NumericBM] = -2 THEN ''''''<label id="CellAlignCenter">'''' + '' 
													WHEN [NumericBM] = 2 THEN ''''''<label id="CellAlignRight">'''' + '' 
													ELSE ''''''<label id="CellAlignLeft">'''' + '' 
												END
											+ ''CASE'' + CHAR(13) + MidLinkCase
											+ ''										ELSE'' + 
											+ CASE 
													WHEN [NumericBM] = 0 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = -1 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = 1 THEN ''''''<label id="CellAlignRight">'''' + '' 
													WHEN [NumericBM] = -2 THEN ''''''<label id="CellAlignCenter">'''' + '' 
													WHEN [NumericBM] = 2 THEN ''''''<label id="CellAlignRight">'''' + '' 
													ELSE ''''''<label id="CellAlignLeft">'''' + '' 
												END
											+ 
											+ ''CONVERT(NVARCHAR(MAX),'' + CASE 
																			WHEN [NumericBM] = 0 THEN '''' + CASE
																											WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																											ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																										END
																			WHEN [NumericBM] = -1 THEN ''dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),'' + CASE
																																WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																																ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																															END + ''),'' + @DateFormat + '')'' 
																			WHEN [NumericBM] = 1 THEN ''CONVERT(INT,'' + CASE
																															WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																															ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																														END + '')''
																			WHEN [NumericBM] = -2 THEN ''CONVERT(NVARCHAR(MAX),CONVERT(BIT,'' + CASE
																															WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																															ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																														END + ''))''
																			WHEN [NumericBM] = 2 THEN ''dbo.fnFormatCurrency('' + CASE
																																	WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																																	ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																																END + '','' + @CurrencyFormat + '')''
																			ELSE ''CONVERT(NVARCHAR(MAX),'' + CASE
																												WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																												ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = '																											END + '')''
																		END 
																+ '')'' + CHAR(13) 
											+ ''									END'' + '' + ''''</label>''''''
											ELSE
												+ CASE 
														WHEN [NumericBM] = 0 THEN ''''''<label id="CellAlignLeft">'''' + '' 
														WHEN [NumericBM] = -1 THEN ''''''<label id="CellAlignLeft">'''' + '' 
														WHEN [NumericBM] = 1 THEN ''''''<label id="CellAlignRight">'''' + '' 
														WHEN [NumericBM] = -2 THEN ''''''<label id="CellAlignCenter">'''' + '' 
														WHEN [NumericBM] = 2 THEN ''''''<label id="CellAlignRight">'''' + '' 
														ELSE ''''''<label id="CellAlignLeft">'''' + '' 
													END
													+ ''CONVERT(NVARCHAR(MAX),'' +
													CASE 
														WHEN [NumericBM] = 0 THEN '''' + CASE
																						WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																						ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																					END
														WHEN [NumericBM] = -1 THEN ''dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),'' + CASE
																											WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																											ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																										END + ''),'' + @DateFormat + '')'' 
														WHEN [NumericBM] = 1 THEN ''CONVERT(INT,'' + CASE
																										WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																										ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																									END + '')''
														WHEN [NumericBM] = -2 THEN ''CONVERT(BIT,'' + CASE
																										WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																										ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																									END + '')''
														WHEN [NumericBM] = 2 THEN ''dbo.fnFormatCurrency('' + CASE
																												WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																												ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																											END + '','' + @CurrencyFormat + '')''
														ELSE ''CONVERT(NVARCHAR(MAX),'' + CASE
																							WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																							ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																						END + '')''
													END
													+ '')''
													+ '' + ''''</label>''''''
											END 
							ELSE '','' --ELSE BEGIN
							+ ColumnName 
							+ '' = '' + CASE
											WHEN MidLinkCase IS NOT NULL 
											THEN + CASE 
													WHEN [NumericBM] = 0 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = -1 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = 1 THEN ''''''<label id="CellAlignRight">'''' + '' 
													WHEN [NumericBM] = -2 THEN ''''''<label id="CellAlignCenter">'''' + '' 
													WHEN [NumericBM] = 2 THEN ''''''<label id="CellAlignRight">'''' + '' 
													ELSE ''''''<label id="CellAlignLeft">'''' + '' 
												END
											+ ''CASE'' + CHAR(13) + MidLinkCase
											+ ''										ELSE'' + 
											+ CASE 
													WHEN [NumericBM] = 0 THEN ''''''<label id="CellAlignLeft">'''' + '' 
													WHEN [NumericBM] = -1 THEN ''''''<label id="CellAlignLeft">'''''
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = ' + '' 
													WHEN [NumericBM] = 1 THEN ''''''<label id="CellAlignRight">'''' + '' 
													WHEN [NumericBM] = -2 THEN ''''''<label id="CellAlignCenter">'''' + '' 
													WHEN [NumericBM] = 2 THEN ''''''<label id="CellAlignRight">'''' + '' 
													ELSE ''''''<label id="CellAlignLeft">'''' + '' 
												END
											+ 
											+ ''CONVERT(NVARCHAR(MAX),'' + CASE 
																			WHEN [NumericBM] = 0 THEN '''' + CASE
																											WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																											ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																										END
																			WHEN [NumericBM] = -1 THEN ''dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),'' + CASE
																																WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																																ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																															END + ''),'' + @DateFormat + '')'' 
																			WHEN [NumericBM] = 1 THEN ''CONVERT(INT,'' + CASE
																															WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																															ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																														END + '')''
																			WHEN [NumericBM] = -2 THEN ''CONVERT(NVARCHAR(MAX),CONVERT(BIT,'' + CASE
																															WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																															ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																														END + ''))''
																			WHEN [NumericBM] = 2 THEN ''dbo.fnFormatCurrency('' + CASE
																																	WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																																	ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																																END + '','' + @CurrencyFormat + '')''
																			ELSE ''CONVERT(NVARCHAR(MAX),'' + CASE
																												WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																												ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																											END + '')''
																		END 
																+ '')'' + CHAR(13) 
											+ ''									END'' + '' + ''''</label>''''''
											ELSE
												+ CASE 
														WHEN [NumericBM] = 0 THEN ''''''<label id="CellAlignLeft">'''' + '' 
														WHEN [NumericBM] = -1 THEN ''''''<label id="CellAlignLeft">'''' + '' 
														WHEN [NumericBM] = 1 THEN ''''''<label id="CellAlignRight">'''' + '' 
														WHEN [NumericBM] = -2 THEN ''''''<label id="CellAlignCenter">'''' + '' 
														WHEN [NumericBM] = 2 THEN ''''''<label id="CellAlignRight">'''' + '' 
														ELSE ''''''<label id="CellAlignLeft">'''' + '' 
													END
												+ ''CONVERT(NVARCHAR(MAX),'' +
												CASE 
													WHEN [NumericBM] = 0 THEN '''' + CASE
																					WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																					ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																				END
													WHEN [NumericBM] = -1 THEN ''dbo.fnFormatDate(CONVERT(NVARCHAR(MAX),'' + CASE
																										WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN '
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = 'SecondRecordsetColumnSourceString
																										ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																									END + ''),'' + @DateFormat + '')'' 
													WHEN [NumericBM] = 1 THEN ''CONVERT(INT,'' + CASE
																									WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																									ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																								END + '')''
													WHEN [NumericBM] = -2 THEN ''CONVERT(BIT,'' + CASE
																									WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																									ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																								END + '')''
													WHEN [NumericBM] = 2 THEN ''dbo.fnFormatCurrency('' + CASE
																											WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																											ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																										END + '','' + @CurrencyFormat + '')''
													ELSE ''CONVERT(NVARCHAR(MAX),'' + CASE
																						WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
																						ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
																					END + '')''
												END
												+ '')''
												+ '' + ''''</label>''''''
									END --ELSE END
						END--CASE END
	FROM (
		SELECT DISTINCT
			FRS.ColumnName
			,LC.InvalidValues
			,LC.MidLinkCase
			,SecondRecordsetColumnSourceString
			,SecondRecordsetColumnSourceStringCode
			,FRS.SortOrder
			,FRS.NumericBM
		FROM #FullRecordSets FRS
		LEFT JOIN (
			SELECT
				ColumnID
				,MidLinkCase = MAX(MidLinkCase)
				,InvalidValues = MAX(InvalidValues)
			FROM #LinkColumns
			GROUP BY ColumnID
		) AS LC
			ON LC.ColumnID = FRS.ColumnID
		WHERE 
			SecondRecordsetColumnSourceString IS NOT NULL
	) AS T
	ORDER BY SortOrder ASC

	SET @SQLRunDataSecondRecordSet = @SQLRunDataSecondRecordSet + @SQLRunDataRecordSetColumns
	
	IF (@Debug > 1)
	BEGIN
		SELECT ''6'',@SQLRunDataSecondRecordSet
	END

	SELECT DISTINCT
		@SQLRunDataSecondRecordSet = @SQLRunDataSecondRecordSet + ''
				FROM '' + CASE 
							WHEN NULLIF(SecondRecordsetTableSourceStringCode,'''') IS NULL THEN SecondRecordsetTableSourceString
							ELSE SecondRecordsetTableSourceString + '' '' + SecondRecordsetTableSourceStringCode
						END
	FROM #FullRecordSets
	WHERE 
		SecondRecordsetColumnSourceString IS NOT NULL

	IF (@Debug > 1)
	BEGIN
		SELECT ''7'',@SQLRunDataSecondRecordSet
	END

	SET @SQLRunDataSecondRecordSet = @SQLRunDataSecondRecordSet + ''
				WHERE
			 		1 = 1''
	
	--20160729 Modified: Added ISNULL
	SELECT
		@SQLRunDataSecondRecordSet = @SQLRunDataSecondRecordSet + ISNULL('' 
					AND ('' + CASE 
								WHEN NULLIF(SecondRecordsetColumnSourceStringCode,'''') IS NULL THEN SecondRecordsetColumnSourceString
								ELSE SecondRecordsetColumnSourceStringCode + ''.'' + SecondRecordsetColumnSourceString
							END
					 + '' '' + CASE WHEN ISNULL([FilterValueNumericBM],[NumericBM]) = 0 THEN ''COLLATE DATABASE_DEFAULT '' ELSE '''' END
					 + ''IN (SELECT REPLACE(SplitReturn,'''''''''''''''','''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''','''')) OR @'' + ParameterCode + '' IS NULL)'','''')
	FROM #FullRecordSets
	WHERE FilterValueSourceString IS NOT NULL
			
	IF (@Debug > 1)
	BEGIN
		SELECT ''8'',@SQLRunDataSecondRecordSet
	END

	SET @SQLRunDataSecondRecordSet = @SQLRunDataSecondRecordSet + ''
			) AS T''
			'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = '
	IF (@Debug > 1)
	BEGIN
		SELECT ''@SQLRunDataSecondRecordSet'',@SQLRunDataSecondRecordSet
	END
	
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunDataSecondRecordSet,''@SQLRunDataSecondRecordSet'',0)

	SET @SQLRunDataInsertSecondRecordSetsSQL = ''''

	SET @SQLRunDataInsertSecondRecordSetsSQL = @SQLRunDataInsertSecondRecordSetsSQL + ISNULL(''
		INSERT INTO #RecordSetsSQL
		(
			RecordSetID
			,ResultTypeBM
			,IfNotExist 
			,IfNotExistOriginal
			,ColumnSet 
			,ColumnSetOriginal
			,RecordSet
			,RecordSetOriginal
		)
		SELECT
			RecordSetID = 2 --Result Set Based
			,ResultTypeBM = 4 --Result Set Based
			,IfNotExist = '''''' + REPLACE(@SQLRunDataSecondRecordSetIfNotExist,'''''''','''''''''''') + ''''''
			,IfNotExistOriginal = '''''' + REPLACE(@SQLRunDataSecondRecordSetIfNotExist,'''''''','''''''''''') + ''''''
			,ColumnSet = '''''' + REPLACE(@SQLRunDataSecondRecordSetColumns,'''''''','''''''''''') + ''''''
			,ColumnSetOriginal = '''''' + REPLACE(@SQLRunDataSecondRecordSetColumns,'''''''','''''''''''') + ''''''
			,RecordSet = '''''' + REPLACE(@SQLRunDataSecondRecordSet,'''''''','''''''''''') + ''''''
			,RecordSetOriginal = '''''' + REPLACE(@SQLRunDataSecondRecordSet,'''''''','''''''''''') + ''''''
	'','''')
	--@SQLRunDataSecondRecordSetColumns
	
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunDataInsertSecondRecordSetsSQL,''@SQLRunDataInsertSecondRecordSetsSQL'',1)
	
	SET @SQLRunDataSecondRecordSetEnd = ''

		SELECT
			@SQLExec = IfNotExist + ColumnSet + RecordSet
		FROM #RecordSetsSQL
		WHERE RecordSetID = 2 --Result Set Based

		IF @Debug > 0
		BEGIN
			SELECT 
				@SQLExec
		END
		
		IF @Debug > 1
		BEGIN
			SELECT 
				*
			FROM #RecordSetsSQL
		END

		EXEC dbo.sp_executesql @statement = @SQLExec
		''

	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunDataSecondRecordSetEnd,''@SQLRunDataSecondRecordSetEnd'',1)
	END
	


	/*
	End of RecordSets
	*/

	SET @SQLRunDataUpdateParameterRecordSetsSQL = ''''

	SELECT
		@SQLRunDataUpdateParameterRecordSetsSQL = @SQLRunDataUpdateParameterRecordSetsSQL + ''
		IF (NULLIF(@'' + ParameterCode + '','''''''') IS NOT NULL)
		BEGIN
			UPDATE RSS
			SET
				ColumnSet =
				CASE 
					WHEN NULLIF(FS.ColumnName,'''''''') IS NOT NULL THEN REPLACE(REPLACE(RSS.ColumnSet,''''	'''' + FS.ColumnName + '''','''',''''''''),''''	'''' + FS.ColumnName,'''''''')
					ELSE RSS.ColumnSet
				END
			FROM #RecordSetsSQL RSS
			LEFT JOIN #FiltersSQL FS
				ON FS.ParameterCode = '''''' + ParameterCode + ''''''
				AND FS.isLinked = 0
		END
		''
	FROM #FullRecordSets
	WHERE NULLIF(FilterValueSourceString,'''') IS NOT NULL
	ORDER BY ParameterCode

	SELECT
		@SQLRunDataUpdateParameterRecordSetsSQL = @SQLRunDataUpdateParameterRecordSetsSQL + ''
		UPDATE RSS
		SET
			IfNotExist = CASE 
							WHEN NULLIF(@'' + ParameterCode + '','''''''') IS NULL THEN REPLACE(RSS.IfNotExist,''''IN (SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''''''','''''''')) OR @'' + ParameterCode + '' IS NULL)'''',''''IN (NULL) OR NULL IS NULL)'''' )
							ELSE REPLACE(RSS.IfNotExist,''''IN (SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''''''','''''''')) OR @'' + ParameterCode + '' IS NULL)'''',''''IN ('''' + REPLACE('''''''''''''''' + @'' + ParameterCode + '' + '''''''''''''''','''''''''''''''''''''''','''''''''''''''') +''''))'''' )
						END
			,RecordSet = CASE 
							WHEN NULLIF(@'' + ParameterCode + '','''''''') IS NULL THEN REPLACE(RSS.RecordSet,''''IN (SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''''''','''''''')) OR @'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = ''' + ParameterCode + '' IS NULL)'''',''''IN (NULL) OR NULL IS NULL)'''' )
							ELSE REPLACE(RSS.RecordSet,''''IN (SELECT REPLACE(SplitReturn,'''''''''''''''''''''''''''''''','''''''''''''''') FROM dbo.fnSplitString(@'' + ParameterCode + '','''''''','''''''')) OR @'' + ParameterCode + '' IS NULL)'''',''''IN ('''' + REPLACE('''''''''''''''' + @'' + ParameterCode + '' + '''''''''''''''','''''''''''''''''''''''','''''''''''''''') +''''))'''' )
						END
			,ColumnSet = CASE WHEN RIGHT(RTRIM(ColumnSet),1) = '''','''' THEN LEFT(ColumnSet,LEN(ColumnSet)-1) ELSE ColumnSet END
		FROM #RecordSetsSQL RSS
		LEFT JOIN #FiltersSQL FS
			ON FS.ParameterCode = '''''' + ParameterCode + ''''''
			AND FS.isLinked = 0
		''
	FROM #FullRecordSets
	WHERE NULLIF(FilterValueSourceString,'''') IS NOT NULL
	ORDER BY ParameterCode
	
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunDataUpdateParameterRecordSetsSQL,''@SQLRunDataUpdateParameterRecordSetsSQL'',1)

	SET @SQLRunResultTables = ''
	END
--END TRY
--BEGIN CATCH
--	SELECT 
--		Error = ''''An Error has occured. Please contact your system administrator.'''' 
--END CATCH
''
	INSERT INTO #SQLCode (SQLCode,SQLCodeDescription,Debug)
	VALUES (@SQLRunResultTables,''@SQLRunResultTables'',1)

	SET @SQLRun = ''''
	--SET @SQLRun = @SQLRun + @UseDB
	--SET @SQLRun = @SQLRun + @SQLRunDropProcedure
	SET @SQLRun = @SQLRun + @SQLRunCreateProcedure
	SET @SQLRun = @SQLRun + @SQLRunResultTypeBM1
	SET @SQLRun = @SQLRun + @SQLRunFilterValueCount
	SET @SQLRun = @SQLRun + @SQLRunFilterSelect
	SET @SQLRun = @SQLRun + @SQLRunFilterValue

	IF (COALESCE(
			NULLIF(@SQLRunDataFirstRecordSetStart,'''')
			,NULLIF(@SQLRunDataSecondRecordSetStart,'''')
			,NULLIF(@SQLRunDataThirdRecordSetStart,'''')
			,NULLIF(@SQLRunDataFourthRecordSetStart,'''')
			,NULLIF(@SQLRunDataFifthRecordSetStart,'''')
		) IS NOT NULL)
	BEGIN
		SET @SQLRun = @SQLRun + COALESCE(
									NULLIF(@SQLRunDataFirstRecordSetStart,'''')
									,NULLIF(@SQLRunDataSecondRecordSetStart,'''')
									,NULLIF(@SQLRunDataThirdRecordSetStart,'''')
									,NULLIF(@SQLRunDataFourthRecordSetStart,'''')
									,NULLIF(@SQLRunDataFifthRecordSetStart,'''')
								)
	END

	IF NULLIF(@SQLRunDataInsertFirstRecordSetsSQL,'''') IS NOT NULL
	BEGIN
		--SET @SQLRun = @SQLRun + @SQLRunDataFirstRecordSetStart
		--SET @SQLRun = @SQLRun + ISNULL(@SQLRunDataFirstRecordSetIfNotExist,'''')
		--SET @SQLRun = @SQLRun + ISNULL(@SQLRunDataFirstRecordSetColumns,'''')
		--SET @SQLRun = @SQLRun + ISNULL(@SQLRunDataFirstRecordSet,'''')
		SET @SQLRun = @SQLRun + ISNULL(@SQLRunDataInsertFirstRecordSetsSQL,'''')
	END

	IF NULLIF(@SQLRunDataInsertSecondRecordSetsSQL,'''') IS NOT NULL
	BEGIN
		--SET @SQLRun = @SQLRun + @SQLRunDataSecondRecordSetStart
		--SET @SQLRun = @SQLRun + ISNULL(@SQLRunDataSecondRecordSetIfNotExist,'''')
		--SET @SQLRun = @SQLRun + ISNULL(@SQLRunDataSecondRecordSetColumns,'''')
		--SET @SQLRun = @SQLRun + ISNULL(@SQLRunDataSecondRecordSet,'''')
		SET @SQLRun = @SQLRun + ISNULL(@SQLRunDataInsertSecondRecordSetsSQL,'''')
	END

	SET @SQLRun = @SQLRun + @SQLRunDataUpdateParameterRecordSetsSQL
	
	IF NULLIF(@SQLRunDataInsertFirstRecordSetsSQL,'''') IS NOT NULL
	BEGIN
		SET @SQLRun = @SQLRun + @SQLRunDataFirstRecordSetEnd
	END

	IF NULLIF(@SQLRunDataInsertSecondRecordSetsSQL,'''') IS NOT NULL
	BEGIN
		SET @SQLRun = @SQLRun + @SQLRunDataSecondRecordSetEnd
	END

	SET @SQLRun = @SQLRun + @SQLRunResultTables
	
	EXEC dbo.sp_executesql @statement = @UseDB
	EXEC dbo.sp_executesql @statement = @SQLRunDropProcedure
	EXEC dbo.sp_executesql @statement = @SQLRun

	IF (@Debug > 0)
	BEGIN
		
		IF (@Debug > 1)
		BEGIN
			SELECT DISTINCT
				FRS.*
				,LC.MidLink
			FROM #FullRecordSets FRS
			LEFT JOIN #LinkColumns LC
				ON LC.ColumnID = FRS.ColumnID
		END

		SELECT
	'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

			SET @SQLStatement2 = '		*
		FROM #SQLCode

		SELECT
			@SQLRun

	END'
			SET @SQLStatement = @SQLStatement + @SQLStatement2
			IF @Debug <> 0
			BEGIN
				INSERT INTO #wrk_debug
				(StepName,SQLQuery)
				SELECT
					@Step, @SQLStatement2
			END
			

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
		BEGIN
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spCreate_PageProcedure] ', [SQLStatement] = @SQLStatement
			SELECT * FROM #wrk_debug
			WHERE StepName = @Step
		END

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1
	END

	SET @Step = 'CREATE PROCEDURE spGet_Help'
	SET @SQLStatement = ''

		SET @SQLStatement = '

--- *****************************************************
--- Author: 		Bengt Jax, JaxIT
--- Date:   		2015-12-21
--- Description:	Get Help Data for WebPage(s)
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spGet_Help]
(
            --Default parameter
            @UserName   nvarchar(50),
            @PageCode   nvarchar(50),
            @Version    nvarchar(50) = NULL,
            @Debug                  bit = 0
)

/*
            EXEC dbo.spGet_Help @UserName = ''bengt@jaxit.se'', @Debug = 1, @PageCode = ''Admin''
            EXEC dbo.spGet_Help @UserName = ''bengt@jaxit.se'', @Debug = 1, @PageCode = ''DrillPage''
            EXEC dbo.spGet_Help @UserName = ''bengt@jaxit.se'', @Debug = 1, @PageCode = ''EditColumnLink''
            EXEC dbo.spGet_Help @UserName = ''bengt@jaxit.se'', @Debug = 1, @PageCode = ''EditPage''
            EXEC dbo.spGet_Help @UserName = ''bengt@jaxit.se'', @Debug = 1, @PageCode = ''EditPageColumn''
            EXEC dbo.spGet_Help @UserName = ''bengt@jaxit.se'', @Debug = 1, @PageCode = ''GL''
*/          

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

            SELECT 
                        HeaderCaption = CASE WHEN [Help_Header] = '''' THEN PageName ELSE [Help_Header] END,
                        Instruction = [Help_Description],
                        HelpLink = [Help_Link],
                        [Version] = @Version
            FROM [dbo].[Page]
            WHERE [PageCode] = @PageCode



'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spGet_Help] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	BEGIN
	SET @Step = 'CREATE PROCEDURE spGet_LeafLabel' 
	SET @SQLStatement = '
CREATE PROCEDURE [dbo].[spGet_LeafLabel]
	@Database nvarchar(100),
	@Dimension nvarchar(100),
	@Hierarchy nvarchar(100),
	@MemberId nvarchar(100),
	@LeafLabel nvarchar(4000) = NULL OUT,
	@Debug bit = 0
	
--EXEC [spGet_LeafLabel] @Database = ''pcDATA_AnnJoo'', @Dimension = ''Time'', @Hierarchy = ''Time_Time'', @MemberId = 2017, @Debug = 1
--EXEC [spGet_LeafLabel] @Database = ''pcDATA_AnnJoo'', @Dimension = ''Entity'', @Hierarchy = ''Entity_Entity'', @MemberId = -1, @Debug = 1

/*
DECLARE @LeafLabel nvarchar(4000)
EXEC [spGet_LeafLabel] @Database = ''pcDATA_AnnJoo'', @Dimension = ''Time'', @Hierarchy = ''Time_Time'', @MemberId = 1, @LeafLabel = @LeafLabel OUT,@Debug = 1
SELECT LeafLabel = @LeafLabel

DECLARE @LeafLabel nvarchar(4000)
EXEC [spGet_LeafLabel] @Database = ''pcDATA_AnnJoo'', @Dimension = ''Entity'', @Hierarchy = ''Entity_Entity'', @MemberId = 1004, @LeafLabel = @LeafLabel OUT,@Debug = 1
SELECT LeafLabel = @LeafLabel

--SELECT RTRIM(SplitReturn FROM [dbo].[fnSplitString](@LeafLabel,'','')
*/

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@SQLStatement nvarchar(max),
	@Step nvarchar(255),
	@Version nvarchar(50) = ''1.3.2115''

	SET @Step = ''Check @MemberId if All_''
		IF @MemberID = 1 --All_
			BEGIN
				SET @LeafLabel = ''''
				GOTO EXITPOINT
			END'

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''Check @MemberId if None''
		IF @MemberID = -1 --None
			BEGIN
				SET @LeafLabel = ''-1''
				GOTO EXITPOINT
			END

	SET @Step = ''Create temp table #Check.''
		CREATE TABLE #LeafCheck
			(
			MemberId nvarchar(255),
			Label nvarchar(255),
			RNodeType nchar(2),
			Checked bit
			)

	SET @Step = ''Fill temp table #LeafCheck.''
		SELECT @SQLStatement = ''
			INSERT INTO #LeafCheck
				(
				MemberId,
				Label,
				RNodeType, 
				Checked
				)
			SELECT DISTINCT
				D.MemberId,
				D.Label,
				RNodeType = CASE WHEN ISNULL(D.RNodeType, '''''''') = '''''''' THEN ''''P'''' ELSE D.RNodeType END, 
				Checked = 0
			FROM
				'' + @Database + ''..DS_'' + @Dimension + '' D
				LEFT JOIN '' + @Database + ''..HS_'' + @Hierarchy + '' H ON H.ParentMemberId = D.MemberId
			WHERE
				D.MemberId = '' + CONVERT(nvarchar(10), @MemberId)'

	SET @SQLStatement = @SQLStatement + '
		
		IF @Debug <> 0 
			PRINT @SQLStatement

		EXEC (@SQLStatement)
		
		IF @Debug <> 0 SELECT Step = @Step, * FROM #LeafCheck

	SET @Step = ''Loop all Parents''
		WHILE (SELECT COUNT(1) FROM #LeafCheck WHERE RNodeType = ''P'' AND Checked = 0) > 0
			BEGIN
				DECLARE LeafCheck_Cursor CURSOR FOR

				SELECT 
					MemberId
				FROM
					#LeafCheck
				WHERE
					RNodeType = ''P'' AND
					Checked = 0

				OPEN LeafCheck_Cursor
				FETCH NEXT FROM LeafCheck_Cursor INTO @MemberId

				WHILE @@FETCH_STATUS = 0
					BEGIN
						SET @SQLStatement = ''
							INSERT INTO #LeafCheck
								(
								MemberId,
								Label,
								RNodeType, 
								Checked
								)
							SELECT DISTINCT
								D.MemberId,
								D.Label,
								RNodeType = CASE WHEN HC.MemberId IS NULL THEN ''''L'''' ELSE ''''P'''' END, 
								Checked = 0
							FROM
								'' + @Database + ''..HS_'' + @Hierarchy + '' H
								INNER JOIN '' + @Database + ''..DS_'' + @Dimension + '' D ON D.MemberId = H.MemberId
								LEFT JOIN '' + @Database + ''..HS_'' + @Hierarchy + '' HC ON HC.ParentMemberId = D.MemberId
							WHERE
								H.ParentMemberId = '' + CONVERT(nvarchar(10), @MemberId)'

	SET @SQLStatement = @SQLStatement + '

						IF @Debug <> 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

						UPDATE #LeafCheck
						SET
							Checked = 1
						WHERE
							MemberId = @MemberId

						FETCH NEXT FROM LeafCheck_Cursor INTO @MemberId
					END

				CLOSE LeafCheck_Cursor
				DEALLOCATE LeafCheck_Cursor	

			END

		IF @Debug <> 0 SELECT * FROM #LeafCheck

	SET @Step = ''Set @LeafLabel''
		SET @LeafLabel = ''''

		SELECT
			@LeafLabel = @LeafLabel + '''''''' + Label + '''''',''
		FROM
			#LeafCheck
		WHERE
			RNodeType = ''L''
			--OR Original = 1

		IF @Debug > 0
		BEGIN
			SELECT @LeafLabel, LEN(@LeafLabel)

			SELECT DISTINCT
				Label
			FROM
				#LeafCheck
			WHERE
				RNodeType = ''L''
		END'

	SET @SQLStatement = @SQLStatement + '

		IF NULLIF(@LeafLabel,'''') IS NOT NULL
		BEGIN
			SELECT @LeafLabel = SUBSTRING(@LeafLabel, 1, LEN(@LeafLabel) - 1)
		END

	SET @Step = ''Drop the temp table''
		DROP TABLE #LeafCheck

	SET @Step = ''Define exit point''
		EXITPOINT:
			IF @Debug <> 0 SELECT LeafLabel = @LeafLabel'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
		BEGIN
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spGet_LeafLabel] ', [SQLStatement] = @SQLStatement
			SELECT * FROM #wrk_debug
			WHERE StepName = @Step
		END

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1
	END

	SET @Step = 'CREATE PROCEDURE spGet_PageFilter'
	SET @SQLStatement = ''

			SET @SQLStatement = @SQLStatement + '--- *****************************************************
--- Author: 		Bengt Jax, JaxIT
--- Date:   		2015-10-19
--- Description:	Get Data Page settings
--- Changed    	Author     	Description       
--- 
--- *****************************************************
CREATE PROCEDURE [dbo].[spGet_PageFilter]
(
	--Default parameter
	@UserName	nvarchar(MAX),
	@Page		nvarchar(MAX),
	--@FreeText	nvarchar(50) = NULL,
	@P01		nvarchar(MAX) = NULL,
	@P02		nvarchar(MAX) = NULL,
	@P03		nvarchar(MAX) = NULL,
	@P04		nvarchar(MAX) = NULL,
	@P05		nvarchar(MAX) = NULL,
	@P06		nvarchar(MAX) = NULL,
	@P07		nvarchar(MAX) = NULL,
	@P08		nvarchar(MAX) = NULL,
	@P09		nvarchar(MAX) = NULL,
	@P10		nvarchar(MAX) = NULL,
	@P11		nvarchar(MAX) = NULL,
	@P12		nvarchar(MAX) = NULL,
	@P13		nvarchar(MAX) = NULL,
	@P14		nvarchar(MAX) = NULL,
	@P15		nvarchar(MAX) = NULL,
	@P16		nvarchar(MAX) = NULL,
	@P17		nvarchar(MAX) = NULL,
	@P18		nvarchar(MAX) = NULL,
	@P19		nvarchar(MAX) = NULL,
	@P20		nvarchar(MAX) = NULL,
	@Debug bit = 0
)
/*
	EXEC dbo.spGet_PageFilter @UserName = ''bengt@jaxit.se'', @Page = NULL, @Debug = 1
	EXEC dbo.spGet_PageFilter @UserName = ''bengt@jaxit.se'', @Page = ''Default'', @P02 = ''201009'', @P03 = ''2000'', @Debug = 1
	EXEC dbo.spGet_PageFilter @UserName = ''bengt@jaxit.se'', @Page = ''GL'', @Debug = 1
	EXEC dbo.spGet_PageFilter @UserName = ''bengt@jaxit.se'', @Page = ''SubLedgerAP'', @Debug = 1
	EXEC dbo.spGet_PageFilter @UserName = ''bengt@jaxit.se'', @Page = ''SubLedgerAR'', @Debug = 1
	EXEC dbo.spGet_PageFilter @UserName = ''bengt@jaxit.se'', @Page = ''InvoiceAR'', @Debug = 1
	EXEC dbo.spGet_PageFilter @UserName = ''bengt@jaxit.se'', @Page = ''SalesOrder'', @Debug = 1
	exec dbo.spGet_PageFilter @debug = 1, @UserName=N''DSPANEL\marni.f.reyes'',@Page=N''Default'',@P01=N''''''EPIC01_Corp''''''
	exec dbo.spGet_PageFilter @UserName=N''DSPANEL\marni.f.reyes'',@Page=N''GL'',@P01=N''''''EPIC02'''',''''EPIC02_MAIN'''''',@P02=NULL,@P03=N''''''1125'''''',@debug = 1
	exec dbo.spGet_PageFilter @UserName=N''DSPANEL\marni.f.reyes'',@Page=N''GL'',@P01=N''''''EPIC03_MAIN'''''',@P02=NULL,@P03=N''''''4000'''''',@P04=NULL,@P05=N''''''EPIC03_MAIN''''''
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@SQLStatement nvarchar(max)
	,@SplitReturn nvarchar(max)

	SET NOCOUNT ON

	SELECT @Page = ISNULL(@Page, ''Default'')

	IF (SELECT COUNT(1) FROM [Page] WHERE PageCode = @Page AND SelectYN <> 0) <> 1
		BEGIN
			SELECT [Message] = ''Selected Page - ('' + @Page + '') - is not available.''
			RETURN
		END

--Page	
	SELECT
		P.PageCode,
		P.PageName 
	FROM
		[Page] P
	WHERE
		P.PageCode = @Page AND
		P.SelectYN <> 0

--Filter Definition
	--Now handled in the page specific procedures. Will be moved to here when wrk_ParameterCode is properly handled.

--Filter Values	
--		@FreeText = '' + ISNULL(@FreeText, ''NULL'') + '',
	
	IF (@P01 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P01,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P01,'','') 

			SET @P01 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P01 = '''''''' + CASE WHEN REPLACE(@P01,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P01,'''''''','''') END + ''''''''
		END
	END

	IF (@P02 IS NOT NULL)
	'

			SET @SQLStatement = @SQLStatement + 'BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P02,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P02,'','') 

			SET @P02 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P02 = '''''''' + CASE WHEN REPLACE(@P02,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P02,'''''''','''') END + ''''''''
		END
	END

	IF (@P03 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P03,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P03,'','') 

			SET @P03 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P03 = '''''''' + CASE WHEN REPLACE(@P03,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P03,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P04 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P04,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P04,'','') 

			SET @P04 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P04 = '''''''' + CASE WHEN REPLACE(@P04,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P04,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P05 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P05,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P05,'','') 

			SET @P05 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P05 = '''''''' + CASE WHEN REPLACE(@P05,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P05,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P06 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P06,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @Sp'

			SET @SQLStatement = @SQLStatement + 'litReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P06,'','') 

			SET @P06 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P06 = '''''''' + CASE WHEN REPLACE(@P06,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P06,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P07 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P07,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P07,'','') 

			SET @P07 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P07 = '''''''' + CASE WHEN REPLACE(@P07,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P07,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P08 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P08,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P08,'','') 

			SET @P08 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P08 = '''''''' + CASE WHEN REPLACE(@P08,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P08,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P09 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P09,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P09,'','') 

			SET @P09 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P09 = '''''''' + CASE WHEN REPLACE(@P09,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P09,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P10 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P10,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P10,'','') 

			SET @P10 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BE'

			SET @SQLStatement = @SQLStatement + 'GIN
			SELECT @P10 = '''''''' + CASE WHEN REPLACE(@P10,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P10,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P11 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P11,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P11,'','') 

			SET @P11 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P11 = '''''''' + CASE WHEN REPLACE(@P11,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P11,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P12 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P12,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P12,'','') 

			SET @P12 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P12 = '''''''' + CASE WHEN REPLACE(@P12,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P12,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P13 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P13,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P13,'','') 

			SET @P13 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P13 = '''''''' + CASE WHEN REPLACE(@P13,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P13,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P14 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P14,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P14,'','') 

			SET @P14 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P14 = '''''''' + CASE WHEN REPLACE(@P14,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P14,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P15 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P15,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitRet'

			SET @SQLStatement = @SQLStatement + 'urn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P15,'','') 

			SET @P15 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P15 = '''''''' + CASE WHEN REPLACE(@P15,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P15,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P16 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P16,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P16,'','') 

			SET @P16 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P16 = '''''''' + CASE WHEN REPLACE(@P16,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P16,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P17 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P17,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P17,'','') 

			SET @P17 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P17 = '''''''' + CASE WHEN REPLACE(@P17,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P17,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P18 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P18,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P18,'','') 

			SET @P18 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P18 = '''''''' + CASE WHEN REPLACE(@P18,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P18,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P19 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P19,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM db'

			SET @SQLStatement = @SQLStatement + 'o.fnSplitString(@P19,'','') 

			SET @P19 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P19 = '''''''' + CASE WHEN REPLACE(@P19,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P19,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P20 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P20,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P20,'','') 

			SET @P20 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P20 = '''''''' + CASE WHEN REPLACE(@P20,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P20,'''''''','''') END + ''''''''
		END
	END

	SET @SQLStatement = ''
	EXEC [dbo].[spGet_Page_'' + @Page + '']
		@UserName = '''''' + @UserName + '''''',
		@ResultTypeBM = 1,
		@P01 = '' + ISNULL(@P01,''NULL'') + '',
		@P02 = '' + ISNULL(@P02,''NULL'') + '',
		@P03 = '' + ISNULL(@P03,''NULL'') + '',
		@P04 = '' + ISNULL(@P04,''NULL'') + '',
		@P05 = '' + ISNULL(@P05,''NULL'') + '',
		@P06 = '' + ISNULL(@P06,''NULL'') + '',
		@P07 = '' + ISNULL(@P07,''NULL'') + '',
		@P08 = '' + ISNULL(@P08,''NULL'') + '',
		@P09 = '' + ISNULL(@P09,''NULL'') + '',
		@P10 = '' + ISNULL(@P10,''NULL'') + '',
		@P11 = '' + ISNULL(@P11,''NULL'') + '',
		@P12 = '' + ISNULL(@P12,''NULL'') + '',
		@P13 = '' + ISNULL(@P13,''NULL'') + '',
		@P14 = '' + ISNULL(@P14,''NULL'') + '',
		@P15 = '' + ISNULL(@P15,''NULL'') + '',
		@P16 = '' + ISNULL(@P16,''NULL'') + '',
		@P17 = '' + ISNULL(@P17,''NULL'') + '',
		@P18 = '' + ISNULL(@P18,''NULL'') + '',
		@P19 = '' + ISNULL(@P19,''NULL'') + '',
		@P20 = '' + ISNULL(@P20,''NULL'') + '',
		@Debug = '' + CONVERT(nvarchar(10), @Debug) + ''''

	IF @Debug <> 0 
	BEGIN
		SELECT
			 CASE WHEN CHARINDEX('','',@P01) = 0 THEN REPLACE(@P01,'''''''''''','''''''') ELSE @P01 END
			 ,@P01
		PRINT @SQLStatement
	END

	EXEC (@SQLStatement)










'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spGet_PageFilter] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spGet_RecordSet'
	SET @SQLStatement = ''

			SET @SQLStatement = @SQLStatement + '
--- *****************************************************
--- Author: 		Bengt Jax, JaxIT
--- Date:   		2015-08-31
--- Description:	Get Data Query
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spGet_RecordSet]
(
	--Default parameter
	@UserName	NVARCHAR(MAX),
	@Page		NVARCHAR(MAX),
--	@FreeText	NVARCHAR(MAX) = NULL,
	@P01		NVARCHAR(MAX) = NULL,
	@P02		NVARCHAR(MAX) = NULL,
	@P03		NVARCHAR(MAX) = NULL,
	@P04		NVARCHAR(MAX) = NULL,
	@P05		NVARCHAR(MAX) = NULL,
	@P06		NVARCHAR(MAX) = NULL,
	@P07		NVARCHAR(MAX) = NULL,
	@P08		NVARCHAR(MAX) = NULL,
	@P09		NVARCHAR(MAX) = NULL,
	@P10		NVARCHAR(MAX) = NULL,
	@P11		NVARCHAR(MAX) = NULL,
	@P12		NVARCHAR(MAX) = NULL,
	@P13		NVARCHAR(MAX) = NULL,
	@P14		NVARCHAR(MAX) = NULL,
	@P15		NVARCHAR(MAX) = NULL,
	@P16		NVARCHAR(MAX) = NULL,
	@P17		NVARCHAR(MAX) = NULL,
	@P18		NVARCHAR(MAX) = NULL,
	@P19		NVARCHAR(MAX) = NULL,
	@P20		nvarchar(MAX) = NULL,
	@excelParams		nvarchar(MAX) = NULL,
	@fromExcel		NVARCHAR(MAX) = NULL,
	@Debug bit = 0,
	@ShowFilterColumnsYN	bit = 0
)

/*
	EXEC dbo.spGet_RecordSet @UserName = ''bengt@jaxit.se'', @Page = NULL, @P02 = ''201001'', @P03 = ''2000'', @Debug = 1
	EXEC dbo.spGet_RecordSet @UserName = ''bengt@jaxit.se'', @Page = ''Default'', @FreeText = ''C03'', @P02 = ''201001'', @P03 = ''2000'', @Debug = 1
	EXEC dbo.spGet_RecordSet @UserName = ''bengt@jaxit.se'', @Page = ''GL'', @P01 = ''201001'', @P02 = ''2000'', @Debug = 1
	EXEC dbo.spGet_RecordSet @UserName = ''bengt@jaxit.se'', @Page = ''SubLedgerAP'', @P02 = ''CP-1'', @Debug = 1
	EXEC dbo.spGet_RecordSet @UserName = ''bengt@jaxit.se'', @Page = ''SubLedgerAR'', @Debug = 1
	EXEC dbo.spGet_RecordSet @UserName = ''bengt@jaxit.se'', @Page = ''InvoiceAR'', @Debug = 1
	EXEC dbo.spGet_RecordSet @UserName = ''bengt@jaxit.se'', @Page = ''SalesOrder'', @Debug = 1
	exec dbo.spGet_RecordSet @debug = 1, @UserName=N''DSPANEL\marni.f.reyes'',@Page=N''Default'',@P01=N'''''''''',''''EPIC01_Corp'''',''''EPIC02_Corp'''''',@P03=N''''''1125'''''',@P02=N''''''''''''
	exec dbo.spGet_RecordSet @UserName=N''DSPANEL\marni.f.reyes'',@Page=N''GL'',@P01=N''''''EPIC02'''',''''EPIC02_MAIN'''''',@P02=NULL,@P03=N''''''1125'''''',@debug = 1
	exec dbo.spGet_RecordSet @UserName=N''DSPANEL\marni.f.reyes'',@Page=N''GL'',@P01=N''''''EPIC03_MAIN'''''',@P02=NULL,@P03=N''''''4000'''''',@P04=NULL,@P05=N''''''EPIC03_MAIN''''''
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@SQLStatement nvarchar(max)
	,@SplitReturn nvarchar(max)

	SET NOCOUNT ON

	SELECT @Page = ISNULL(@Page, ''Default'')

	IF (SELECT COUNT(1) FROM [Page] WHERE PageCode = @Page AND SelectYN <> 0) <> 1
		BEGIN
			SELECT [Message] = ''Selected Page - ('' + @Page + '') - is not available.''
			RETURN
		END
--		@FreeText = '' + ISNULL(@FreeText, ''NULL'') + '',	
	IF (@P01 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P01,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P01,'','') 

			SET @P01 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P01 = '''''''' + CASE WHEN REPLACE(@P01,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P01,'''''''','''') END + ''''''''
		END
	END

	IF (@P02 IS NOT NULL)
	BEGIN
'

			SET @SQLStatement = @SQLStatement + '		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P02,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P02,'','') 

			SET @P02 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P02 = '''''''' + CASE WHEN REPLACE(@P02,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P02,'''''''','''') END + ''''''''
		END
	END

	IF (@P03 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P03,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P03,'','') 

			SET @P03 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P03 = '''''''' + CASE WHEN REPLACE(@P03,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P03,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P04 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P04,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P04,'','') 

			SET @P04 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P04 = '''''''' + CASE WHEN REPLACE(@P04,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P04,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P05 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P05,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P05,'','') 

			SET @P05 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P05 = '''''''' + CASE WHEN REPLACE(@P05,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P05,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P06 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P06,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitRetu'

			SET @SQLStatement = @SQLStatement + 'rn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P06,'','') 

			SET @P06 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P06 = '''''''' + CASE WHEN REPLACE(@P06,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P06,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P07 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P07,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P07,'','') 

			SET @P07 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P07 = '''''''' + CASE WHEN REPLACE(@P07,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P07,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P08 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P08,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P08,'','') 

			SET @P08 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P08 = '''''''' + CASE WHEN REPLACE(@P08,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P08,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P09 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P09,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P09,'','') 

			SET @P09 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P09 = '''''''' + CASE WHEN REPLACE(@P09,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P09,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P10 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P10,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P10,'','') 

			SET @P10 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
		'

			SET @SQLStatement = @SQLStatement + '	SELECT @P10 = '''''''' + CASE WHEN REPLACE(@P10,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P10,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P11 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P11,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P11,'','') 

			SET @P11 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P11 = '''''''' + CASE WHEN REPLACE(@P11,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P11,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P12 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P12,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P12,'','') 

			SET @P12 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P12 = '''''''' + CASE WHEN REPLACE(@P12,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P12,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P13 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P13,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P13,'','') 

			SET @P13 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P13 = '''''''' + CASE WHEN REPLACE(@P13,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P13,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P14 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P14,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P14,'','') 

			SET @P14 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P14 = '''''''' + CASE WHEN REPLACE(@P14,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P14,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P15 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P15,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = C'

			SET @SQLStatement = @SQLStatement + 'ASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P15,'','') 

			SET @P15 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P15 = '''''''' + CASE WHEN REPLACE(@P15,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P15,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P16 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P16,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P16,'','') 

			SET @P16 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P16 = '''''''' + CASE WHEN REPLACE(@P16,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P16,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P17 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P17,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P17,'','') 

			SET @P17 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P17 = '''''''' + CASE WHEN REPLACE(@P17,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P17,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P18 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P18,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P18,'','') 

			SET @P18 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P18 = '''''''' + CASE WHEN REPLACE(@P18,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P18,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P19 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P19,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSpl'

			SET @SQLStatement = @SQLStatement + 'itString(@P19,'','') 

			SET @P19 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P19 = '''''''' + CASE WHEN REPLACE(@P19,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P19,'''''''','''') END + ''''''''
		END
	END
	
	IF (@P20 IS NOT NULL)
	BEGIN
		IF (
			SELECT
				COUNT(DISTINCT SplitReturn)
			FROM dbo.fnSplitString(@P20,'','')
		) > 1
		BEGIN
			SET @SplitReturn = NULL

			SELECT
				@SplitReturn = CASE WHEN @SplitReturn IS NULL THEN CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE REPLACE(SplitReturn,'''''''','''') END
								ELSE @SplitReturn + '','' + CASE WHEN NULLIF(REPLACE(SplitReturn,'''''''',''''),'''') IS NULL THEN ''NONE'' ELSE  REPLACE(SplitReturn,'''''''','''') END
								END
			FROM dbo.fnSplitString(@P20,'','') 

			SET @P20 = '''''''' + REPLACE(REPLACE('''''''' + @SplitReturn + '''''''','','','''''',''''''),'''''''','''''''''''') + ''''''''
		END
		ELSE
		BEGIN
			SELECT @P20 = '''''''' + CASE WHEN REPLACE(@P20,'''''''','''') = '''' THEN ''NONE'' ELSE REPLACE(@P20,'''''''','''') END + ''''''''
		END
	END

	SET @SQLStatement = ''
	EXEC [dbo].[spGet_Page_'' + @Page + '']
		@UserName = '''''' + @UserName + '''''',
		@ResultTypeBM = 2,
		@P01 = '' + ISNULL(@P01,''NULL'') + '',
		@P02 = '' + ISNULL(@P02,''NULL'') + '',
		@P03 = '' + ISNULL(@P03,''NULL'') + '',
		@P04 = '' + ISNULL(@P04,''NULL'') + '',
		@P05 = '' + ISNULL(@P05,''NULL'') + '',
		@P06 = '' + ISNULL(@P06,''NULL'') + '',
		@P07 = '' + ISNULL(@P07,''NULL'') + '',
		@P08 = '' + ISNULL(@P08,''NULL'') + '',
		@P09 = '' + ISNULL(@P09,''NULL'') + '',
		@P10 = '' + ISNULL(@P10,''NULL'') + '',
		@P11 = '' + ISNULL(@P11,''NULL'') + '',
		@P12 = '' + ISNULL(@P12,''NULL'') + '',
		@P13 = '' + ISNULL(@P13,''NULL'') + '',
		@P14 = '' + ISNULL(@P14,''NULL'') + '',
		@P15 = '' + ISNULL(@P15,''NULL'') + '',
		@P16 = '' + ISNULL(@P16,''NULL'') + '',
		@P17 = '' + ISNULL(@P17,''NULL'') + '',
		@P18 = '' + ISNULL(@P18,''NULL'') + '',
		@P19 = '' + ISNULL(@P19,''NULL'') + '',
		@P20 = '' + ISNULL(@P20,''NULL'') + '',
		@ShowFilterColumnsYN = '' + ISNULL('''''''' + CONVERT(NVARCHAR(2),@ShowFilterColumnsYN) + '''''''', ''NULL'') + '',
		@excelParams = '' + ISNULL('''''''' + @excelParams + '''''''', ''NULL'') + '',
		@fromExcel = '' + ISNULL('''''''' + @fromExcel + '''''''', ''NULL'') + ''''

	IF @Debug <> 0 PRINT @SQLStatement
	EXEC (@SQLStatement)







'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spGet_RecordSet] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spGet_SystemParameter'
	SET @SQLStatement = ''

		SET @SQLStatement = '
--- *****************************************************
--- Author: 		Bengt Jax, JaxIT
--- Date:   		2015-11-24
--- Description:	Get SystemParameter
--- Changed    	Author     	Description       
--- 
--- *****************************************************

CREATE PROCEDURE [dbo].[spGet_SystemParameter]
(
	--Default parameter
	@UserName	nvarchar(50),
	@Key		nvarchar(50),
	@Debug bit = 0
)

/*
	EXEC dbo.spGet_SystemParameter @UserName = ''bengt@jaxit.se'', @Key = ''RowLimit''
*/	

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

	SET NOCOUNT ON

	SELECT 105











'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spGet_SystemParameter] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spInsert_wrk_ParameterCode'
	SET @SQLStatement = ''

		SET @SQLStatement = '


CREATE PROCEDURE [dbo].[spInsert_wrk_ParameterCode]
AS

TRUNCATE TABLE [dbo].[wrk_ParameterCode]

INSERT INTO [dbo].[wrk_ParameterCode]
(
	[PageID]
	,[ColumnID]
	,[ParameterCode]
)
SELECT DISTINCT
	[PageID]
	,[ColumnID]
	,[ParameterCode] = ''P'' + 
	CASE WHEN RK < 10 THEN ''0'' + CONVERT(VARCHAR(2),RK)
	ELSE CONVERT(VARCHAR(2),RK) END
FROM (
	SELECT
	  [PageID]
	  ,[ColumnID]
	  ,RK = ROW_NUMBER() OVER(PARTITION BY [PageID] ORDER BY SortOrder ASC)
	FROM [dbo].[PageColumn] 
	WHERE 
		[PageID] > 0
		AND [FilterYN] = 1
) AS T
ORDER BY [PageID]

'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spInsert_wrk_ParameterCode] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'CREATE PROCEDURE spRunAll_spCreate_PageProcedure'
	SET @SQLStatement = ''

		SET @SQLStatement = '
CREATE PROCEDURE [dbo].[spRunAll_spCreate_PageProcedure]
	@Debug	SMALLINT = 0 -- 0 No Debug, 1 Whole Code, 2 Step by step plus Whole Code
	,@Prefix	NVARCHAR(50) = '''' -- 0 No Debug, 1 Whole Code, 2 Step by step plus Whole Code

' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
---- ****************************************************************
---- Author: 		Marni Reyes, DSPanel
---- Date:   		2015-11-24
---- Description:	Run All Create Dynamic Stored Procedures for Drill Page
---- ****************************************************************

DECLARE @MaxPageID INT
DECLARE @Increment INT
DECLARE @ErrorLog NVARCHAR(MAX)

SET @Increment = 1

SELECT
	@MaxPageID = MAX([PageID])
	,@ErrorLog = NULL
FROM [dbo].[Page]


WHILE (@Increment < (@MaxPageID + 1))
BEGIN
	BEGIN TRY
		IF (@Increment NOT IN (0,7))
		BEGIN
			EXEC spCreate_PageProcedure @PageID = @Increment, @Debug = @Debug, @Prefix = @Prefix
		END
	END TRY
	BEGIN CATCH
		SET @ErrorLog = CHAR(13) + ISNULL(@ErrorLog,'''') + ''An Error occured on Page: '' + CONVERT(NVARCHAR(3),@Increment)
	END CATCH

	SET @Increment = @Increment + 1
END

SELECT ISNULL(@ErrorLog,''Finished successfully.'')
'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spRunAll_spCreate_PageProcedure] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	---------------------------
	SET @Step = 'CREATE FUNCTIONS'
	---------------------------
	
	SET @Step = 'Create Function fnFormatDate'

		SET @SQLStatement = '
CREATE FUNCTION [dbo].[fnFormatDate](@Date DATETIME,@FormatID int = 23)
RETURNS NVARCHAR(100)
AS
/*
	SELECT dbo.fnFormatDate(GETDATE(),1)
	SELECT dbo.fnFormatDate(GETDATE(),23)
*/

BEGIN
DECLARE @ReturnDate NVARCHAR(100)
SELECT
	@ReturnDate =
	CASE 
		WHEN @FormatID = 1 THEN	REPLACE(CONVERT(NVARCHAR(100),@Date,6),'','','''')
		WHEN @FormatID = 2 THEN	CONVERT(NVARCHAR(100),@Date,106)
		WHEN @FormatID = 3 THEN	CONVERT(NVARCHAR(100), @Date, 10) 
		WHEN @FormatID = 4 THEN CONVERT(NVARCHAR(100), @Date, 110) 
		WHEN @FormatID = 5 THEN CONVERT(NVARCHAR(100), @Date, 4) 
		WHEN @FormatID = 6 THEN CONVERT(NVARCHAR(100), @Date, 104) 
		WHEN @FormatID = 7 THEN CONVERT(NVARCHAR(100), @Date, 11) 
		WHEN @FormatID = 8 THEN CONVERT(NVARCHAR(100), @Date, 111) 
		WHEN @FormatID = 9 THEN REPLACE(CONVERT(NVARCHAR(100),@Date,6),'' '','''')
		WHEN @FormatID = 10 THEN REPLACE(CONVERT(NVARCHAR(100),@Date,106),'' '','''')
		WHEN @FormatID = 11 THEN CONVERT(NVARCHAR(100), @Date, 10) 
		WHEN @FormatID = 12 THEN CONVERT(NVARCHAR(100), @Date, 110) 
		WHEN @FormatID = 13 THEN CONVERT(NVARCHAR(100), @Date, 1) 
		WHEN @FormatID = 14 THEN CONVERT(NVARCHAR(100), @Date, 101) 
		WHEN @FormatID = 15 THEN REPLACE(CONVERT(NVARCHAR(100),@Date,107),'','','''')
		WHEN @FormatID = 16 THEN CONVERT(NVARCHAR(100), @Date, 7) 
		WHEN @FormatID = 17 THEN CONVERT(NVARCHAR(100), @Date, 107) 
		WHEN @FormatID = 18 THEN REPLACE(CONVERT(NVARCHAR(100), @Date, 107),'' '','''')
		WHEN @FormatID = 19 THEN REPLACE(REPLACE(CONVERT(NVARCHAR(100), @Date, 107),'' '',''''),'','','''')
		WHEN @FormatID = 20 THEN CONVERT(NVARCHAR(100), @Date, 2) 
		WHEN @FormatID = 21 THEN CONVERT(NVARCHAR(100), @Date, 11) 
		WHEN @FormatID = 22 THEN CONVERT(NVARCHAR(100), @Date, 12)
		WHEN @FormatID = 23 THEN REPLACE(CONVERT(NVARCHAR(100), @Date, 102),''.'',''-'')
		WHEN @FormatID = 24 THEN CONVERT(NVARCHAR(100), @Date, 102) 
		WHEN @FormatID = 25 THEN CONVERT(NVARCHAR(100), @Date, 111)
		WHEN @FormatID = 26 THEN CONVERT(NVARCHAR(100), @Date, 112)
		ELSE REPLACE(CONVERT(NVARCHAR(100), @Date, 102),''.'',''-'')
	END

RETURN @ReturnDate
END'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE FUNCTION [dbo].[fnFormatDate] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'Create Function fnSplitString'

		SET @SQLStatement = '
CREATE FUNCTION [dbo].[fnSplitString] 
(
	@String NVARCHAR(MAX)
	, @delimiter NVARCHAR(10)
)

RETURNS @SplitValues TABLE
(
    SplitReturn VARCHAR(MAX) NOT NULL
)

AS
BEGIN
	DECLARE @FoundIndex INT
	DECLARE @ReturnValue VARCHAR(MAX)

	SET @FoundIndex = CHARINDEX(@delimiter, @String)

	WHILE (@FoundIndex <> 0)
	BEGIN
		SET @ReturnValue = SUBSTRING(@String, 0, @FoundIndex)
		
		INSERT INTO @SplitValues (SplitReturn) VALUES (@ReturnValue)
		
		SET @String = SUBSTRING(@String, @FoundIndex + 1, len(@String) - @FoundIndex)
		
		SET @FoundIndex = CHARINDEX(@delimiter, @String)
	END

	INSERT @SplitValues (SplitReturn) VALUES (ISNULL(@String,''''))

	RETURN
END'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE FUNCTION [dbo].[fnSplitString] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	
	SET @Step = 'Create Function fnFormatCurrency'

		SET @SQLStatement = '

CREATE FUNCTION [dbo].[fnFormatCurrency](@Currency NUMERIC(23,4),@FormatID int = 0)
RETURNS NVARCHAR(100)
AS
/*
	SELECT dbo.fnFormatCurrency(1234567890.12345678,0)
	SELECT dbo.fnFormatCurrency(1234567890.12345678,1)
	SELECT dbo.fnFormatCurrency(1234567890.12345678,2)
	SELECT dbo.fnFormatCurrency(1234567890.12345678,3)
	SELECT dbo.fnFormatCurrency(1234567890.12345678,23)
*/

BEGIN
DECLARE @ReturnCurrency NVARCHAR(100)
SELECT
	@ReturnCurrency =
	CASE 
		WHEN @FormatID = 1 THEN	CONVERT(NVARCHAR(50),CONVERT(MONEY,@Currency),1)
		WHEN @FormatID = 2 THEN	REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR(50),CONVERT(MONEY,@Currency),1),''.'','' ''),'','',''.''),'' '','','')
		WHEN @FormatID = 3 THEN	REPLACE(REPLACE(CONVERT(NVARCHAR(50),CONVERT(MONEY,@Currency),1),''.'','' ''),'','',''.'')
		WHEN @FormatID = 4 THEN REPLACE(CONVERT(NVARCHAR(50),CONVERT(MONEY,@Currency),1),'','','' '')
		WHEN @FormatID = 5 THEN REPLACE(REPLACE(CONVERT(NVARCHAR(50),CONVERT(MONEY,@Currency),1),'','','' ''),''.'','','')
		WHEN @FormatID = 6 THEN REPLACE(CONVERT(NVARCHAR(50),CONVERT(MONEY,@Currency),1),'','','''''''')
		WHEN @FormatID = 7 THEN REPLACE(REPLACE(CONVERT(NVARCHAR(50),CONVERT(MONEY,@Currency),1),'','',''''''''),''.'','','')
		ELSE CONVERT(NVARCHAR(50),@Currency)
	END

RETURN @ReturnCurrency
END'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE FUNCTION [dbo].[fnFormatCurrency] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'Create Function fnSplitStringPutDoubleQuotes'

		SET @SQLStatement = '/*
SELECT dbo.[fnSplitString](''0,'''''''''','','')
*/

CREATE FUNCTION [dbo].[fnSplitStringPutDoubleQuotes] 
( 
    @string NVARCHAR(MAX), 
    @delimiter CHAR(1) 
) 
RETURNS NVARCHAR(MAX)
BEGIN 
    DECLARE @start INT, @end INT , @AndCount INT 
    DECLARE @ReturnString NVARCHAR(MAX)

	SET @ReturnString = ''''
	SET @AndCount = 0
	SET @string = REPLACE(@string,'''''''','''''''''''')

    SELECT @start = 1, @end = CHARINDEX(@delimiter, @string) 
    WHILE @start < LEN(@string) + 1 BEGIN 
        IF @end = 0  
            SET @end = LEN(@string) + 1
		
		IF @AndCount = 0
		BEGIN
			
			SET @ReturnString = @ReturnString + '''''''' + SUBSTRING(@string, @start, @end - @start) + '''''''' 
			
			SET @AndCount = 1
		END
		ELSE
		BEGIN
			SET @ReturnString = @ReturnString + '','''''' + SUBSTRING(@string, @start, @end - @start) + '''''''' 
		END

        SET @start = @end + 1 
        SET @end = CHARINDEX(@delimiter, @string, @start)
        
    END 

    RETURN @ReturnString
END

'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE FUNCTION [dbo].[fnSplitStringPutDoubleQuotes] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'Create Function fnUrlEncode'

		SET @SQLStatement = 'CREATE FUNCTION [dbo].[fnUrlEncode] (@url NVARCHAR(1024))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @count INT, @c NCHAR(1), @i INT, @urlReturn NVARCHAR(3072)
    SET @count = LEN(@url)
    SET @i = 1
    SET @urlReturn = ''''    
    WHILE (@i <= @count)
     BEGIN
        SET @c = SUBSTRING(@url, @i, 1)
        IF @c LIKE N''[A-Za-z0-9()''''*\-._!~]'' COLLATE Latin1_General_BIN ESCAPE N''\'' COLLATE Latin1_General_BIN
         BEGIN
            SET @urlReturn = @urlReturn + @c
         END
        ELSE
         BEGIN
            SET @urlReturn =
                   @urlReturn + ''%''
                   + SUBSTRING(sys.fn_varbintohexstr(CAST(@c AS VARBINARY(MAX))),3,2)
                   + ISNULL(NULLIF(SUBSTRING(sys.fn_varbintohexstr(CAST(@c AS VARBINARY(MAX))),5,2), ''00''), '''')
         END
        SET @i = @i +1
     END
    RETURN @urlReturn
END
'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE FUNCTION [dbo].[fnUrlEncode] ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1


	---------------------------
	SET @Step = 'CREATE PROCEDURES'
	---------------------------

	BEGIN
	SET @Step = 'CREATE PROCEDURE spPopulate_DrillPageTables' 
		SET @SQLStatement = '
CREATE PROCEDURE [dbo].[spPopulate_DrillPageTables]
	@ApplicationID int = ' + CONVERT(nvarchar(10), @ApplicationID) + ',
	@Debug bit = 0

	' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

-- EXEC spPopulate_DrillPageTables @ApplicationID = 264
-- EXEC spPopulate_DrillPageTables @ApplicationID = 294, @Debug = 1
-- EXEC spPopulate_DrillPageTables @ApplicationID = 400, @Debug = 1

DECLARE
	@SQLExec NVARCHAR(MAX),
	@SourceDatabase NVARCHAR(255),
	@SourceOwner NVARCHAR(255),
	@DestinationDatabase NVARCHAR(255),
	@ETLDatabase NVARCHAR(255),
	@SourceID NVARCHAR(255),
	@SourceTypeName NVARCHAR(255),
	@SourceTypeFamilyID NVARCHAR(255),
	@ModelName NVARCHAR(255),
	@HighestFromSequenceBM INT,
	@HighestDimensionSequenceBM INT,
	@BaseModelID INT,
	@SourceTypeBM INT,
	@ModelBM INT,
	@SQLStatement nvarchar(max)

IF OBJECT_ID(N''tempdb..#Models'') IS NOT NULL
BEGIN
	TRUNCATE TABLE #Models
	DROP TABLE #Models
END
SELECT
	BaseModelID = M.BaseModelID
	,ModelName = M.ModelName
	,ModelBM = BM.ModelBM
	,ST.SourceTypeBM
	,SourceDatabase = S.SourceDatabase
	,SourceOwner = ST.Owner
	,ST.SourceTypeFamilyID
	,DestinationDatabase = A.DestinationDatabase
	,ETLDatabase = A.ETLDatabase
	,[ETLDatabase_Linked] = ISNULL(S.[ETLDatabase_Linked],A.ETLDatabase)
	,SourceID = CASE 
					WHEN S.SourceID < 10 THEN ''000'' + CONVERT(NVARCHAR(4),S.SourceID)
					WHEN S.SourceID < 100 THEN ''00'' + CONVERT(NVARCHAR(4),S.SourceID)
					WHEN S.SourceID < 1000 THEN ''0'' + CONVERT(NVARCHAR(4),S.SourceID)
					ELSE CONVERT(NVARCHAR(10),S.SourceID)
				END
	,SourceType = ST.SourceTypeName'

	SET @SQLStatement = @SQLStatement + '
INTO
	#Models
FROM
	[pcINTEGRATOR].[dbo].[Model] M
	INNER JOIN [pcINTEGRATOR].[dbo].[Model] BM ON BM.ModelID = M.BaseModelID AND BM.[SelectYN] <> 0
	INNER JOIN [pcINTEGRATOR].[dbo].[Source] S ON S.ModelID = M.ModelID AND S.[SelectYN] <> 0
	INNER JOIN [pcINTEGRATOR].[dbo].[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
	INNER JOIN [pcINTEGRATOR].[dbo].[Application] A ON A.ApplicationID = M.ApplicationID
WHERE 
	M.[SelectYN] <> 0 AND
	M.ApplicationID = @ApplicationID


SELECT
	@SourceDatabase = ''['' + REPLACE(REPLACE(REPLACE(SourceDatabase, ''['', ''''), '']'', ''''), ''.'', ''].['') + '']''
	,@DestinationDatabase = ''['' + REPLACE(REPLACE(REPLACE(DestinationDatabase, ''['', ''''), '']'', ''''), ''.'', ''].['') + '']''
	,@SourceTypeBM = SourceTypeBM
	,@SourceTypeFamilyID = SourceTypeFamilyID
	,@SourceOwner = ISNULL(SourceOwner,''dbo'')
	,@SourceTypeName = SourceType
FROM #Models

IF @Debug <> 0
	SELECT
		SourceDatabase = @SourceDatabase,
		DestinationDatabase = @DestinationDatabase,
		SourceTypeBM = @SourceTypeBM ,
		SourceOwner = @SourceOwner'

	SET @SQLStatement = @SQLStatement + '

IF (@SourceTypeBM & 1025 > 0)
BEGIN
	SET IDENTITY_INSERT [dbo].[Page] ON 
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (-4, N''EditColumnLink'', N''Edit Column Link Web Page'', NULL, 1, N''Edit Column Link Web Page'', N''Edit Column Link Web Page'', N''http://www.docu-pc.com/pc2/doku.php?id=pcdrillpage:adminguide:pagelink'', N''1.4.0.2136'')
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (-3, N''EditPage'', N''Edit Page Web Page'', NULL, 1, N''Edit Page Web Page'', N''Edit Page Web Page'', N''http://www.docu-pc.com/pc2/doku.php?id=pcdrillpage:adminguide:page'', N''1.4.0.2136'')
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (-2, N''EditPageColumn'', N''Edit Column Web Page'', NULL, 1, N''Edit Column Web Page'', N''Edit Column Web Page'', N''http://www.docu-pc.com/pc2/doku.php?id=pcdrillpage:adminguide:pagecolumn'', N''1.4.0.2136'')
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (-1, N''Admin'', N''Admin Web Page'', NULL, 1, N''pcDrillPage Administration'', N''This is the Admin Page where pcDrillPage Administrators manage Pages, Data Columns and Page Links.'', N''http://www.docu-pc.com/pc2/doku.php?id=pcdrillpage:adminguide:start'', N''1.4.0.2136'')
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (1, N''Default'', N''Starting Point'', NULL, 1, N''DrillPage'', N''Welcome to pcDrillPage'', N''http://www.docu-pc.com/pc2/doku.php?id=pcdrillpage:start'', N''1.4.0.2136'')
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (2, N''GL'', N''General Ledger'', 1, 1, N''GL Header'', N''GL Description'', N'''', N''1.4.0.2136'')
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (3, N''InvoiceAR'', N''Customer Invoice, Header & Rows'', NULL, 1, N''Accounts Receivable Invoice'', N'''', N'''', N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (4, N''SubLedgerAP'', N''Accounts Payable'', NULL, 1, N''Accounts Payable'', N'''', N'''', N''1.4.0.2136'')
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (5, N''SubLedgerAR'', N''Accounts Receivable'', NULL, 1, N''Accounts Receivable'', N'''', N'''', N''1.4.0.2136'')
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (6, N''SalesOrder'', N''Sales Order, Header & Rows'', NULL, 1, N''Sales Order'', N'''', N'''', N''1.4.0.2136'')
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (7, N''Reserved'', N''Reserved'', NULL, 1, N'''', N'''', N'''', N''1.4.0.2136'')
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (8, N''Supplier'', N''Supplier'', NULL, 1, N'''', N'''', N'''', N''1.4.0.2136'')
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (9, N''Customer'', N''Customer'', NULL, 1, N'''', N'''', N'''', N''1.4.0.2136'')
	INSERT [dbo].[Page] ([PageID], [PageCode], [PageName], [PageWeight], [SelectYN], [Help_Header], [Help_Description], [Help_Link], [Version]) VALUES (10, N''SalesRep'', N''SalesRep'', NULL, 1, N'''', N'''', N'''', N''1.4.0.2136'')
	SET IDENTITY_INSERT [dbo].[Page] OFF
	
	'

	SET @SQLStatement = @SQLStatement + '	
	SET IDENTITY_INSERT [dbo].[PageColumn] ON 
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (-500, N''SEQ DESC'', 0, 0, 1, 0, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (-300, N''GROUP BY'', 0, 0, 1, 0, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (-200, N''WHERE'', 0, 0, 1, 0, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (-100, N''FROM'', 0, 0, 1, 0, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (1, N''Account'', 1, 0, 1, 30, NULL, 1, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (2, N''Entity'', 1, 0, 1, 10, NULL, 1, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (3, N''Period'', 1, 0, 1, 20, NULL, 0, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (4, N''Currency'', 1, 0, 1, 40, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (5, N''Scenario'', 1, 0, 1, 50, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (6, N''Amount'', 1, 2, 1, 70, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (7, N''JournalNo'', 2, 1, 1, 10, NULL, 1, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (8, N''JournalLine'', 2, 1, 1, 20, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (9, N''Account'', 2, 0, 1, 30, NULL, 1, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (10, N''Description'', 2, 0, 1, 40, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (11, N''Date'', 2, -1, 1, 50, NULL, 1, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (12, N''Company'', 2, 0, 1, 5, NULL, 0, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (13, N''Book'', 2, 0, 1, 70, NULL, 0, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (14, N''SourceModule'', 2, 0, 1, 80, NULL, 1, 1, 0, 1, 1, 0, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (15, N''JournalCode'', 2, 0, 1, 90, NULL, 0, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (16, N''Amount'', 2, 2, 1, 100, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (17, N''Period'', 2, 0, 1, 110, NULL, 0, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (19, N''Company'', 4, 0, 1, 10, NULL, 0, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (20, N''InvoiceNo'', 4, 0, 1, 20, NULL, 0, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (21, N''Supplier'', 4, 0, 1, 30, NULL, 1, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (22, N''InvoiceDate'', 4, -1, 1, 40, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (23, N''DueDate'', 4, -1, 1, 50, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (24, N''Currency'', 4, 0, 1, 60, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (25, N''InvoiceAmount'', 4, 2, 1, 70, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (26, N''Company'', 5, 0, 1, 10, NULL, 0, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (27, N''InvoiceNo'', 5, 1, 1, 20, NULL, 1, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (28, N''Customer'', 5, 0, 1, 30, NULL, 1, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (29, N''InvoiceDate'', 5, -1, 1, 40, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (30, N''DueDate'', 5, -1, 1, 50, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (31, N''PaymentDate'', 5, -1, 1, 60, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (32, N''Currency'', 5, 0, 1, 70, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (33, N''InvoiceAmount'', 5, 2, 1, 80, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (34, N''Company'', 3, 0, 1, 10, NULL, 0, 1, 0, 1, 1, 0, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (35, N''InvoiceNo'', 3, 1, 1, 20, NULL, 0, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (36, N''InvoiceLine'', 3, 1, 2, 90, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (37, N''PartNo'', 3, 0, 2, 100, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (38, N''LineDesc'', 3, 0, 2, 110, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (39, N''UnitPrice'', 3, 1, 2, 120, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (40, N''Quantity'', 3, 1, 2, 130, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (41, N''Price'', 3, 2, 2, 140, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (42, N''OrderNo'', 3, 1, 2, 150, NULL, 1, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (43, N''OrderLine'', 3, 1, 2, 160, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (44, N''ShipDate'', 3, -1, 2, 170, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (45, N''OpenOrder'', 6, -2, 1, 10, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (46, N''Company'', 6, 0, 1, 5, NULL, 0, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (47, N''OrderNo'', 6, 1, 1, 30, NULL, 0, 1, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (48, N''Customer'', 6, 0, 1, 40, NULL, 1, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (49, N''OrderDate'', 6, -1, 1, 50, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (50, N''RequestDate'', 6, -1, 1, 60, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (51, N''SalesMan'', 6, 0, 1, 70, NULL, 1, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (52, N''OrderLine'', 6, 1, 2, 80, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (53, N''PartNo'', 6, 0, 2, 90, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (54, N''LineDesc'', 6, 0, 2, 100, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (55, N''UnitPrice'', 6, 2, 2, 110, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (56, N''Quantity'', 6, 1, 2, 120, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (57, N''Price'', 6, 2, 2, 130, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (68, N''Customer'', 3, 0, 1, 30, NULL, 1, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (69, N''InvoiceDate'', 3, -1, 1, 40, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (70, N''DueDate'', 3, -1, 1, 50, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (71, N''PaymentDate'', 3, -1, 1, 60, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (72, N''Currency'', 3, 0, 1, 70, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (73, N''InvoiceAmount'', 3, 1, 1, 80, NULL, 0, 0, 0, 1, 1, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (77, N''AllocID'', 2, 0, 2, 120, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (78, N''BalanceAcct'', 2, 0, 2, 130, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (79, N''BalanceAcct'', 2, 0, 2, 140, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (80, N''Company'', 8, 0, 1, 10, NULL, 0, 1, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (81, N''VendorID'', 8, 0, 1, 20, NULL, 0, 1, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (82, N''Name'', 8, 0, 1, 30, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (83, N''Address1'', 8, 0, 1, 40, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (84, N''Address2'', 8, 0, 1, 50, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (85, N''Address3'', 8, 0, 1, 60, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (86, N''EMailAddress'', 8, 0, 1, 70, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (88, N''InvoiceNum'', 8, 0, 2, 80, NULL, 1, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (89, N''CustID'', 9, 0, 1, 15, NULL, 0, 1, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (90, N''Name'', 9, 0, 1, 20, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (91, N''Address1'', 9, 0, 1, 30, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (92, N''Address2'', 9, 0, 1, 40, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (93, N''Address3'', 9, 0, 1, 50, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (94, N''InvoiceNum'', 9, 1, 2, 60, NULL, 1, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (95, N''Time'', 2, 1, 3, 150, NULL, 0, 1, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (96, N''InvoiceDate'', 9, -1, 2, 70, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (97, N''CustNum'', 9, 1, 1, 80, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (98, N''InvoiceAmt'', 9, 2, 2, 90, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (99, N''Company'', 9, 0, 1, 10, NULL, 0, 1, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (100, N''GLAccount'', 2, 0, 1, 160, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (101, N''InvoiceDate'', 8, -1, 2, 90, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (102, N''InvoiceAmt'', 8, 2, 2, 100, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (103, N''InvoiceBal'', 8, 2, 2, 110, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (104, N''InvoiceBal'', 9, 2, 2, 100, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (105, N''SalesRepCode'', 10, 0, 1, 10, NULL, 0, 1, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (106, N''Company'', 10, 0, 1, 5, NULL, 0, 1, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (107, N''Address1'', 10, 0, 1, 20, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (108, N''Address2'', 10, 0, 1, 30, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (109, N''Address3'', 10, 0, 1, 40, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (110, N''Name'', 10, 0, 1, 15, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (111, N''Country'', 10, 0, 1, 50, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (112, N''EMailAddress'', 10, 0, 1, 60, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (113, N''FaxPhoneNum'', 10, 0, 1, 70, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (114, N''HomePhoneNum'', 10, 0, 1, 80, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (115, N''City'', 10, 0, 1, 45, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (116, N''SalesRepTitle'', 10, 0, 1, 12, NULL, 0, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (117, N''SalesRepCode'', 9, 0, 1, 110, NULL, 1, 0, 0, 1, 0, 0, N''1.4.0.2136'')
	SET IDENTITY_INSERT [dbo].[PageColumn] OFF
	
	'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Default, FROM, Epicor ERP'', 1, -100, 1027, 1, 129, 0, 0, @DestinationDatabase + ''.dbo.FACT_Financials_View V INNER JOIN '' + @DestinationDatabase + ''.dbo.DS_Entity E ON E.Label = V.Entity'', NULL, 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Default, Account, Epicor ERP'', 1, 1, 1027, 1, 225, 0, 0, N''Account'', N''V'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Default, Entity, Epicor ERP'', 1, 2, 1027, 1, 225, 0, 0, N''Entity'', N''V'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Default, Period, Epicor ERP'', 1, 3, 1027, 1, 225, 0, 0, N''Time'', N''V'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Default, Currency, Epicor ERP'', 1, 4, 1027, 1, 225, 0, 0, N''Currency'', N''V'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Default, Scenario, Epicor ERP'', 1, 5, 1027, 1, 225, 0, 0, N''Scenario'', N''V'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Default, Amount, Epicor ERP'', 1, 6, 1027, 1, 225, 4, 0, N''Financials_Value'', N''V'', 1, N''0'', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Default, Account (Linked to GL), Epicor ERP'', 1, 9, 1027, 1, 1, 0, 0, N''Account'', N''V'', 1, N'''', NULL, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Default, Company (Linked to GL), Epicor ERP'', 1, 12, 1027, 1, 3, 0, 0, N''Company'', N''E'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Default, Book (Linked to GL), Epicor ERP'', 1, 13, 1027, 1, 3, 0, 0, N''Book'', N''E'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, FROM, Epicor ERP'', 2, -100, 1027, 1, 129, 0, 0, @SourceDatabase + ''.'' + @SourceOwner + ''.GLJrnDtl'', N''G1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, JournalNo, Epicor ERP'', 2, 7, 1027, 1, 225, 1, 0, N''JournalNum'', N''G1'', 1, N''0'', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, JournalLine, Epicor ERP'', 2, 8, 1027, 1, 225, 1, 0, N''JournalLine'', N''G1'', 1, N''0'', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, Account, Epicor ERP'', 2, 9, 1027, 1, 225, 0, 0, N''SegValue1'', N''G1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, Description, Epicor ERP'', 2, 10, 1027, 1, 225, 0, 0, N''Description'', N''G1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, Date, Epicor ERP'', 2, 11, 1027, 1, 225, -1, 0, N''JEDate'', N''G1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, Company, Epicor ERP'', 2, 12, 1027, 1, 255, 0, 0, N''Company'', N''G1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, Book, Epicor ERP'', 2, 13, 1027, 1, 225, 0, 0, N''BookID'', N''G1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, SourceModule, Epicor ERP'', 2, 14, 1027, 1, 225, 0, 0, N''SourceModule'', N''G1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, JournalCode, Epicor ERP'', 2, 15, 1027, 1, 225, 0, 0, N''JournalCode'', N''G1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, Amount, Epicor ERP'', 2, 16, 1027, 1, 225, 4, 0, N''CAST(BookDebitAmount + (-1 * BookCreditAmount) AS DECIMAL(17,2))'', NULL, 1, N''0'', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, Period, Epicor ERP'', 2, 17, 1027, 1, 225, 1, 0, N''CONVERT(nvarchar(50), FiscalYear * 100 + FiscalPeriod)'', NULL, 1, N''0'', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, Company (Linked to SubLedgerAP), Epicor ERP'', 2, 19, 1027, 1, 3, 0, 0, N''Company'', N''G1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, InvoiceNo (Linked to SubLedgerAP), Epicor ERP'', 2, 20, 1027, 1, 3, 0, 0, N''APInvoiceNum'', N''G1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, VendorNo (Linked to SubLedgerAP), Epicor ERP'', 2, 21, 1027, 1, 3, 1, 0, N''VendorNum'', N''G1'', 1, N''0'', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, Company (Linked to SubLedgerAR), Epicor ERP'', 2, 26, 1027, 1, 3, 0, 0, N''Company'', N''G1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, InvoiceNo (Linked to SubLedgerAR), Epicor ERP'', 2, 27, 1027, 1, 3, 1, 0, N''ARInvoiceNum'', N''G1'', 1, N''0'', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, Time, Epicor ERP'', 2, 95, 1027, 1, 227, 1, 0, N''FiscalYear'', N''G1'', 1, N'''', N''2012'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page GL, GLAccount, Epicor ERP'', 2, 100, 1027, 1, 1, 0, 0, N''GLAccount'', N''G1'', 1, N'''', N''999900|ROCK|0000|000'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR From, Epicor ERP'', 3, -100, 1027, 1, 1, 0, 0, @SourceDatabase + ''.'' + @SourceOwner + ''.InvcHead I1
					INNER JOIN '' + @SourceDatabase + ''.'' + @SourceOwner + ''.Customer C2 ON
						c2.Company = i1.Company AND c2.CustNum = i1.CustNum'', NULL, 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR From, Epicor ERP'', 3, -100, 1027, 1, 130, 0, 0, @SourceDatabase + ''.'' + @SourceOwner + ''.InvcDtl'', N''I1'', 1, N'''', N'''', N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, Company, Epicor ERP'', 3, 34, 1027, 1, 227, 0, 0, N''Company'', N''I1'', 1, N''NULL'', N''NULL'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, InvoiceNo, Epicor ERP'', 3, 35, 1027, 1, 227, 1, 0, N''InvoiceNum'', N''I1'', 1, N''NULL'', N''NULL'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, InvoiceLine, Epicor ERP'', 3, 36, 1027, 1, 2, 1, 0, N''InvoiceLine'', N''I1'', 1, N''NULL'', N''NULL'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, PartNo, Epicor ERP'', 3, 37, 1027, 1, 2, 0, 0, N''PartNum'', N''I1'', 1, N''NULL'', N''NULL'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, LineDesc, Epicor ERP'', 3, 38, 1027, 1, 2, 0, 0, N''LineDesc'', N''I1'', 1, N''NULL'', N''NULL'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, UnitPrice, Epicor ERP'', 3, 39, 1027, 1, 2, 4, 0, N''UnitPrice'', N''I1'', 1, N''NULL'', N''NULL'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, Quantity, Epicor ERP'', 3, 40, 1027, 1, 2, 1, 0, N''OurOrderQty'', N''I1'', 1, N''NULL'', N''NULL'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, Price, Epicor ERP'', 3, 41, 1027, 1, 2, 4, 0, N''ExtPrice'', N''I1'', 1, N''NULL'', N''NULL'', N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, OrderNo, Epicor ERP'', 3, 42, 1027, 1, 2, 1, 0, N''OrderNum'', N''I1'', 1, N''''''NULL'''',''''0'''',0'', N''NULL'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, OrderLine, Epicor ERP'', 3, 43, 1027, 1, 2, 1, 0, N''OrderLine'', N''I1'', 1, N''NULL'', N''NULL'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, ShipDate, Epicor ERP'', 3, 44, 1027, 1, 2, -1, 0, N''ShipDate'', N''I1'', 1, N''NULL'', N''NULL'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, Company (Linked to SalesOrder), Epicor ERP'', 3, 46, 1027, 1, 3, 0, 0, N''Company'', N''I1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, OrderNo (Linked to SalesOrder), Epicor ERP'', 3, 47, 1027, 1, 3, 1, 0, N''OrderNum'', N''I1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, Customer, Epicor ERP'', 3, 68, 1027, 1, 1, 0, 0, N''c2.CustID + '''' - '''' + c2.Name'', NULL, 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, InvoiceDate, Epicor ERP'', 3, 69, 1027, 1, 1, -1, 0, N''InvoiceDate'', N''I1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, DueDate, Epicor ERP'', 3, 70, 1027, 1, 1, -1, 0, N''DueDate'', N''I1'', 1, NULL, NULL, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, PaymentDate, Epicor ERP'', 3, 71, 1027, 1, 1, -1, 0, N''ClosedDate'', N''I1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, Currency, Epicor ERP'', 3, 72, 1027, 1, 1, 0, 0, N''CurrencyCode'', N''I1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, InvoiceAmount, Epicor ERP'', 3, 73, 1027, 1, 1, 4, 0, N''InvoiceAmt'', N''I1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, CustID (Linked to Customer), Epicor ERP'', 3, 89, 1027, 1, 1, 0, 0, N''CustID'', N''C2'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page InvoiceAR, Company, (Linked to Customer), Epicor ERP'', 3, 99, 1027, 1, 1, 0, 0, N''Company'', N''I1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAP FROM, Epicor ERP'', 4, -100, 1027, 1, 129, 0, 0, N''
					'' + @SourceDatabase + ''.'' + @SourceOwner + ''.APInvHed A1
					INNER JOIN '' + @SourceDatabase + ''.'' + @SourceOwner + ''.Vendor V2 ON
						V2.Company = A1.Company AND V2.VendorNum = A1.VendorNum'', NULL, 1, NULL, NULL, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAP, Company, Epicor ERP'', 4, 19, 1027, 1, 225, 0, 0, N''Company'', N''A1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAP, InvoiceNo, Epicor ERP'', 4, 20, 1027, 1, 225, 0, 0, N''InvoiceNum'', N''A1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAP, VendorNo, FilterValue, Epicor ERP'', 4, 21, 1027, 1, 32, 1, 0, N''VendorNum'', N''A1'', 1, N''0'', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAP, VendorNo, Epicor ERP'', 4, 21, 1027, 1, 65, 0, 0, N''v2.VendorID + '''' - '''' + v2.Name'', NULL, 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAP, VendorNo, Epicor ERP'', 4, 21, 1027, 1, 128, 1, 0, N''VendorNum'', N''V2'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAP, InvoiceDate, Epicor ERP'', 4, 22, 1027, 1, 129, -1, 0, N''InvoiceDate'', N''A1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAP, DueDate, Epicor ERP'', 4, 23, 1027, 1, 129, -1, 0, N''DueDate'', N''A1'', 1, NULL, NULL, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAP, Currency, Epicor ERP'', 4, 24, 1027, 1, 129, 0, 0, N''CurrencyCode'', N''A1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAP, InvoiceAmount, Epicor ERP'', 4, 25, 1027, 1, 129, 4, 0, N''InvoiceAmt'', N''A1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAP, Company, (Linked to Supplier), Epicor ERP'', 4, 80, 1027, 1, 1, 0, 0, N''Company'', N''A1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAP, VendorID, (Linked to Supplier), Epicor ERP'', 4, 81, 1027, 1, 1, 0, 0, N''VendorID'', N''V2'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR FROM, Epicor ERP'', 5, -100, 1027, 1, 129, 0, 0, @SourceDatabase + ''.'' + @SourceOwner + ''.InvcHead i1
	INNER JOIN '' + @SourceDatabase + ''.'' + @SourceOwner + ''.Customer c2 ON c2.Company = i1.Company AND c2.CustNum = i1.CustNum'', NULL, 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR, Company, Epicor ERP'', 5, 26, 1027, 1, 225, 0, 0, N''Company'', N''i1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR, InvoiceNo, Epicor ERP'', 5, 27, 1027, 1, 225, 1, 0, N''InvoiceNum'', N''i1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR, Customer, Epicor ERP'', 5, 28, 1027, 1, 225, 0, 0, N''c2.CustID + '''' - '''' + c2.Name'', NULL, 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR, InvoiceDate, Epicor ERP'', 5, 29, 1027, 1, 225, -1, 0, N''InvoiceDate'', N''i1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR, DueDate, Epicor ERP'', 5, 30, 1027, 1, 225, -1, 0, N''DueDate'', N''i1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR, PaymentDate, Epicor ERP'', 5, 31, 1027, 1, 225, -1, 0, N''ClosedDate'', N''i1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR, Currency, Epicor ERP'', 5, 32, 1027, 1, 225, 0, 0, N''CurrencyCode'', N''i1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR, InvoiceAmount, Epicor ERP'', 5, 33, 1027, 1, 225, 4, 0, N''InvoiceAmt'', N''i1'', 1, N''0'', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR, Company (Linked to InvoiceAR), Epicor ERP'', 5, 34, 1027, 1, 3, 0, 0, N''Company'', N''i1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR, InvoiceNo (Linked to InvoiceAR), Epicor ERP'', 5, 35, 1027, 1, 3, 1, 0, N''InvoiceNum'', N''i1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR, CustID (Linked to Customer), Epicor ERP'', 5, 89, 1027, 1, 1, 0, 0, N''CustID'', N''C2'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SubLedgerAR, Name (Linked to Customer), Epicor ERP'', 5, 90, 1027, 1, 1, 0, 0, N''Name'', N''C2'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder FROM, Epicor ERP'', 6, -100, 1027, 1, 1, 0, 0, @SourceDatabase + ''.'' + @SourceOwner + ''.OrderHed O1
  					INNER JOIN '' + @SourceDatabase + ''.'' + @SourceOwner + ''.Customer c2 ON
						c2.Company = O1.Company AND c2.CustNum = O1.CustNum'', NULL, 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder FROM, Epicor ERP'', 6, -100, 1027, 1, 2, 0, 0, @SourceDatabase + ''.'' + @SourceOwner + ''.OrderDtl'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder FROM, Epicor ERP'', 6, -100, 1027, 1, 128, 0, 0, @SourceDatabase + ''.'' + @SourceOwner + ''.OrderHed'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, OpenOrder, Epicor ERP'', 6, 45, 1027, 1, 1, -2, 0, N''OpenOrder'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, Company, Epicor ERP'', 6, 46, 1027, 1, 227, 0, 0, N''Company'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, OrderNo, Epicor ERP'', 6, 47, 1027, 1, 227, 1, 0, N''OrderNum'', N''O1'', 1, N''0,'''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, Customer, Epicor ERP'', 6, 48, 1027, 1, 1, 0, 0, N''c2.CustID + '''' - '''' + c2.Name'', NULL, 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, OrderDate, Epicor ERP'', 6, 49, 1027, 1, 1, -1, 0, N''OrderDate'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, RequestDate, Epicor ERP'', 6, 50, 1027, 1, 1, -1, 0, N''RequestDate'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, SalesMan, Epicor ERP'', 6, 51, 1027, 1, 1, 0, 0, N''SalesRepList'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, OrderLine, Epicor ERP'', 6, 52, 1027, 1, 2, 0, 0, N''OrderLine'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, PartNo, Epicor ERP'', 6, 53, 1027, 1, 2, 0, 0, N''PartNum'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, LineDesc, Epicor ERP'', 6, 54, 1027, 1, 2, 0, 0, N''LineDesc'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, UnitPrice, Epicor ERP'', 6, 55, 1027, 1, 2, 4, 0, N''UnitPrice'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, Quantity, Epicor ERP'', 6, 56, 1027, 1, 2, 1, 0, N''OrderQty'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, Price, Epicor ERP'', 6, 57, 1027, 1, 2, 4, 0, N''UnitPrice * OrderQty'', N''O1'', 1, NULL, NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, CustID (Linked to Customer), Epicor ERP'', 6, 89, 1027, 1, 1, 0, 0, N''CustID'', N''C2'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, Company (Linked to Customer), Epicor ERP'', 6, 99, 1027, 1, 1, 0, 0, N''Company'', N''O1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, SalesRepCode (Linked to SalesRep), Epicor ERP'', 6, 105, 1027, 1, 1, 0, 0, N''SalesRepCode'', N''C2'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesOrder, Company (Linked to SalesRep), Epicor ERP'', 6, 106, 1027, 1, 1, 0, 0, N''Company'', N''O1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier FROM, Epicor ERP'', 8, -100, 1027, 1, 2, 0, 0, @SourceDatabase + ''.'' + @SourceOwner + ''.APInvHed A1 INNER JOIN '' + @SourceDatabase + ''.'' + @SourceOwner + ''.Vendor V1 ON V1.Company = A1.Company AND V1.VendorNum = A1.VendorNum'', NULL, 1, N'''', N'''', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, FROM, Epicor ERP'', 8, -100, 1027, 1, 129, 0, 0, @SourceDatabase + ''.'' + @SourceOwner + ''.[Vendor]'', N''V1'', 1, N'''', N'''', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, Company (Linked to SubLedgerAP), Epicor ERP'', 8, 19, 1027, 1, 2, 0, 0, N''Company'', N''A1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, InvoiceNo (Linked to SubLedgerAP), Epicor ERP'', 8, 20, 1027, 1, 2, 0, 0, N''InvoiceNum'', N''A1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, Company, Epicor ERP'', 8, 80, 1027, 1, 227, 0, 0, N''Company'', N''V1'', 1, N'''', N''GPC'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, VendorID, Epicor ERP'', 8, 81, 1027, 1, 227, 0, 0, N''VendorID'', N''V1'', 1, N'''', N''VOB'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, Name, Epicor ERP'', 8, 82, 1027, 1, 1, 0, 0, N''Name'', N''V1'', 1, N'''', N''YSL'', N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, Address1, Epicor ERP'', 8, 83, 1027, 1, 1, 0, 0, N''Address1'', N''V1'', 1, N'''', N''Venustiano Carranza# 39-302'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, Address2, Epicor ERP'', 8, 84, 1027, 1, 1, 0, 0, N''Address2'', N''V1'', 1, N'''', N''Suite B'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, Address3, Epicor ERP'', 8, 85, 1027, 1, 1, 0, 0, N''Address3'', N''V1'', 1, N'''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, EMailAddress, Epicor ERP'', 8, 86, 1027, 1, 1, 0, 0, N''EMailAddress'', N''V1'', 1, N'''', N''steel@epicorsi.americas.epicor.net'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, InvoiceNum, Epicor ERP'', 8, 88, 1027, 1, 2, 0, 0, N''InvoiceNum'', N''A1'', 1, N'''', N''USD-1-2009'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, InvoiceDate, Epicor ERP'', 8, 101, 1027, 1, 2, -1, 0, N''InvoiceDate'', N''A1'', 1, N'''', N''2014-11-29'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, InvoiceAmt, Epicor ERP'', 8, 102, 1027, 1, 2, 2, 0, N''InvoiceAmt'', N''A1'', 1, N'''', N''985.000'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Supplier, InvoiceBal, Epicor ERP'', 8, 103, 1027, 1, 2, 2, 0, N''InvoiceBal'', N''A1'', 1, N'''', N''9805.000'', N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer FROM, Epicor ERP'', 9, -100, 1027, 1, 2, 0, 0, @SourceDatabase + ''.'' + @SourceOwner + ''.InvcHead i1 INNER JOIN '' + @SourceDatabase + ''.'' + @SourceOwner + ''.Customer c1 ON c1.Company = i1.Company AND c1.CustNum = i1.CustNum'', NULL, 1, N'''', N'''', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, FROM, Epicor ERP'', 9, -100, 1027, 1, 129, 0, 0, @SourceDatabase + ''.'' + @SourceOwner + ''.Customer'', N''C1'', 1, N'''', N'''', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, Company (Linked to SubLedgerAR), Epicor ERP'', 9, 26, 1027, 1, 2, 0, 0, N''Company'', N''I1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, InvoiceNo (Linked to SubLedgerAR), Epicor ERP'', 9, 27, 1027, 1, 2, 1, 0, N''InvoiceNum'', N''I1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, CustID, Epicor ERP'', 9, 89, 1027, 1, 255, 0, 0, N''CustID'', N''C1'', 1, N'''', N''WEB000355'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, Name, Epicor ERP'', 9, 90, 1027, 1, 1, 0, 0, N''Name'', N''C1'', 1, N'''', N''West Coast Direct Marketing - Seattle'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, Address1, Epicor ERP'', 9, 91, 1027, 1, 1, 0, 0, N''Address1'', N''C1'', 1, N'''', N''Valma Flinstone'', N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, Address2, Epicor ERP'', 9, 92, 1027, 1, 1, 0, 0, N''Address2'', N''C1'', 1, N'''', N''Suite 2000'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, Address3, Epicor ERP'', 9, 93, 1027, 1, 1, 0, 0, N''Address3'', N''C1'', 1, N'''', N''Postfach 153'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, InvoiceNum, Epicor ERP'', 9, 94, 1027, 1, 2, 1, 0, N''InvoiceNum'', N''I1'', 1, N'''', N''9149'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, InvoiceDate, Epicor ERP'', 9, 96, 1027, 1, 2, -1, 0, N''InvoiceDate'', N''I1'', 1, N'''', N''2015-02-02'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, CustNum, Epicor ERP'', 9, 97, 1027, 1, 1, 1, 0, N''CustNum'', N''C1'', 1, N'''', N''99'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, InvoiceAmt, Epicor ERP'', 9, 98, 1027, 1, 2, 2, 0, N''InvoiceAmt'', N''I1'', 1, N'''', N''9900.000'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, Company, Epicor ERP'', 9, 99, 1027, 1, 255, 0, 0, N''Company'', N''C1'', 1, N'''', N''GPC'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, InvoiceBal, Epicor ERP'', 9, 104, 1027, 1, 2, 2, 0, N''InvoiceBal'', N''I1'', 1, N'''', N''96000.000'', N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, SalesRepCode (Linked to SalesRep), Epicor ERP'', 9, 105, 1027, 1, 1, 0, 0, N''SalesRepCode'', N''C1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, Company (Linked to SalesRep), Epicor ERP'', 9, 106, 1027, 1, 1, 0, 0, N''Company'', N''C1'', 1, N'''''''''''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page Customer, SalesRepCode, Epicor ERP'', 9, 117, 1027, 1, 1, 0, 0, N''SalesRepCode'', N''C1'', 1, N'''', N''WILLIE'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, FROM, Epicor ERP'', 10, -100, 1027, 1, 129, 0, 0, @SourceDatabase + ''.'' + @SourceOwner + ''.SalesRep'', N''S1'', 1, N'''', N'''', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, SalesRepCode, Epicor ERP'', 10, 105, 1027, 1, 225, 0, 0, N''SalesRepCode'', N''S1'', 1, N'''', N''WRIGHT'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, Company, Epicor ERP'', 10, 106, 1027, 1, 255, 0, 0, N''Company'', N''S1'', 1, N'''', N''GPC'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, Address1, Epicor ERP'', 10, 107, 1027, 1, 1, 0, 0, N''Address1'', N''S1'', 1, N'''', N''7900 International Drive'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, Address2, Epicor ERP'', 10, 108, 1027, 1, 1, 0, 0, N''Address2'', N''S1'', 1, N'''', N''Ste. 400'', N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, Address3, Epicor ERP'', 10, 109, 1027, 1, 1, 0, 0, N''Address3'', N''S1'', 1, N'''', NULL, N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, Name, Epicor ERP'', 10, 110, 1027, 1, 1, 0, 0, N''Name'', N''S1'', 1, N'''', N''Willie Loman'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, Country, Epicor ERP'', 10, 111, 1027, 1, 1, 0, 0, N''Country'', N''S1'', 1, N'''', N''USA'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, EMailAddress, Epicor ERP'', 10, 112, 1027, 1, 1, 0, 0, N''EMailAddress'', N''S1'', 1, N'''', N''styler@wfo.com'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, FaxPhoneNum, Epicor ERP'', 10, 113, 1027, 1, 1, 0, 0, N''FaxPhoneNum'', N''S1'', 1, N'''', N''608-555-5566'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, HomePhoneNum, Epicor ERP'', 10, 114, 1027, 1, 1, 0, 0, N''HomePhoneNum'', N''S1'', 1, N'''', N''612-449-9023'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, City, Epicor ERP'', 10, 115, 1027, 1, 1, 0, 0, N''City'', N''S1'', 1, N'''', N''Madison'', N''1.4.0.2136'')
	INSERT [dbo].[PageSource] ([Comment], [PageID], [ColumnID], [SourceTypeBM], [RevisionBM], [SequenceBM], [NumericBM], [GroupByYN], [SourceString], [SourceStringCode], [SelectYN], [InvalidValues], [SampleValue], [Version]) VALUES (N''Page SalesRep, SalesRepTitle, Epicor ERP'', 10, 116, 1027, 1, 1, 0, 0, N''SalesRepTitle'', N''S1'', 1, N'''', N''US Domestic Sales Manager'', N''1.4.0.2136'')
	
	'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (1, N''@@@@@'', 9, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (2, N''@@@@@'', 12, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (2, N''@@@@@'', 13, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (7, N''@@@@@'', 7, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (7, N''@@@@@'', 12, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (7, N''@@@@@'', 13, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (7, N''@@@@@'', 14, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (7, N''@@@@@'', 15, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (7, N''@@@@@'', 17, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (9, N''@@@@@'', 9, 1, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (9, N''@@@@@'', 17, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (11, N''@@@@@'', 11, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (14, N''AP'', 19, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (14, N''AP'', 20, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (14, N''AP'', 21, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (14, N''AR'', 26, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (14, N''AR'', 27, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (21, N''@@@@@'', 80, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (21, N''@@@@@'', 81, 1, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (27, N''@@@@@'', 34, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (27, N''@@@@@'', 35, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (28, N''@@@@@'', 89, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (28, N''@@@@@'', 90, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (42, N''@@@@@'', 46, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (42, N''@@@@@'', 47, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (48, N''@@@@@'', 89, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (48, N''@@@@@'', 99, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (51, N''@@@@@'', 105, 1, N''1.4.0.2136'')'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (51, N''@@@@@'', 106, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (68, N''@@@@@'', 89, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (68, N''@@@@@'', 99, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (88, N''@@@@@'', 19, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (88, N''@@@@@'', 20, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (94, N''@@@@@'', 26, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (94, N''@@@@@'', 27, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (117, N''@@@@@'', 105, 1, N''1.4.0.2136'')
	INSERT [dbo].[LinkDefinition] ([StartColumnID], [StartColumnValue], [ParameterColumnID], [SelectYN], [Version]) VALUES (117, N''@@@@@'', 106, 1, N''1.4.0.2136'')
	
	'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[SystemParameter] ([SystemParameterID], [web_Server], [Filter_CB_Limit], [Return_Row_Limit], [DateFormat], [CurrencyFormat], [pcData_DBName], [pcData_OwnerName], [sourceDB_DBName], [sourceDB_OwnerName], [sourceTypeBM]) VALUES (1, N''90'', 100, 10000, 23, 1, @DestinationDatabase + '''', N''dbo'', @SourceDatabase, @SourceOwner, @SourceTypeBM)
	
	'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (1, 1, N''P03'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (1, 2, N''P01'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (1, 3, N''P02'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (2, 7, N''P02'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (2, 9, N''P03'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (2, 11, N''P04'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (2, 12, N''P01'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (2, 13, N''P05'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (2, 14, N''P06'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (2, 15, N''P07'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (2, 17, N''P08'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (4, 19, N''P01'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (4, 20, N''P02'', NULL)'

	SET @SQLStatement = @SQLStatement + '
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (4, 21, N''P03'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (5, 26, N''P01'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (5, 27, N''P02'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (3, 34, N''P01'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (3, 35, N''P02'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (6, 46, N''P01'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (6, 47, N''P02'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (8, 80, N''P01'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (8, 81, N''P02'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (9, 89, N''P02'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (2, 95, N''P09'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (9, 99, N''P01'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (10, 105, N''P02'', NULL)
	INSERT [dbo].[wrk_ParameterCode] ([PageID], [ColumnID], [ParameterCode], [isSortOrderAlfa]) VALUES (10, 106, N''P01'', NULL)'

	SET @SQLStatement = @SQLStatement + '

END
ELSE
BEGIN


	IF OBJECT_ID(N''tempdb..#TableColumns'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #TableColumns
		DROP TABLE #TableColumns
	END

	CREATE TABLE #TableColumns 
	(
		DbName NVARCHAR(4000) COLLATE DATABASE_DEFAULT
		,SchemaName NVARCHAR(4000) COLLATE DATABASE_DEFAULT
		,TableName NVARCHAR(4000) COLLATE DATABASE_DEFAULT
		,ColumnName NVARCHAR(4000) COLLATE DATABASE_DEFAULT
		,ModelBM INT
		,SortOrder INT
	)

	DECLARE @SQL NVARCHAR(4000)

	SELECT 
		@SQL= ''
	SELECT DISTINCT
		DbName = TABLE_CATALOG
		,SchemaName = TABLE_SCHEMA
		,TableName = TABLE_NAME
		,ColumnName = COLUMN_NAME
		,ModelBM
		,SortOrder = ORDINAL_POSITION
	FROM '' + @SourceDatabase + ''.INFORMATION_SCHEMA.COLUMNS C
	INNER JOIN [pcINTEGRATOR].[dbo].[SourceTable] ST
		ON ST.[TableCode] COLLATE DATABASE_DEFAULT = C.TABLE_NAME COLLATE DATABASE_DEFAULT
	WHERE ST.SourceTypeFamilyID = '' + CONVERT(NVARCHAR(50), @SourceTypeFamilyID) + ''
	'''

	SET @SQLStatement = @SQLStatement + '

	IF @Debug <> 0
	SELECT @SQL

	INSERT INTO #TableColumns
	(
		DbName
		, SchemaName
		, TableName
		,ColumnName
		,ModelBM
		,SortOrder
	)
	EXEC sp_executesql @SQL

	IF @Debug <> 0
	SELECT @SQL

	SELECT 
		@SQL= ''
	SELECT DISTINCT
		DbName = TABLE_CATALOG
		,SchemaName = TABLE_SCHEMA
		,TableName = TABLE_NAME
		,ColumnName = COLUMN_NAME
		,ModelBM = 65535
		,SortOrder = ORDINAL_POSITION
	FROM '' + @DestinationDatabase + ''.INFORMATION_SCHEMA.COLUMNS C
	''

	INSERT INTO #TableColumns
	(
		DbName
		, SchemaName
		, TableName
		,ColumnName
		,ModelBM
		,SortOrder
	)
	EXEC sp_executesql @SQL'

	SET @SQLStatement = @SQLStatement + '

	IF @Debug <> 0
	BEGIN
		SELECT DISTINCT 
			DbName
		FROM #TableColumns
	END


	IF OBJECT_ID(N''tempdb..#Tables'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #Tables
		DROP TABLE #Tables
	END

	SELECT DISTINCT
		DbName
		, SchemaName
		, TableName
		, ModelBM
	INTO #Tables
	FROM #TableColumns

	IF OBJECT_ID(N''tempdb..#FactSourceStrings'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #FactSourceStrings
		DROP TABLE #FactSourceStrings
	END'

	SET @SQLStatement = @SQLStatement + '

	SELECT DISTINCT
		T1.*
	INTO #FactSourceStrings
	FROM (
		SELECT
			M.ModelName
			--,D.DimensionID
			,D.DimensionName
			--,F.SourceString
			,[SourceString] = REPLACE(REPLACE(REPLACE(REPLACE([SourceString],''@SourceDatabase'',SourceDatabase),''@Owner'',SourceOwner),''@SourceID'',SourceID),''@DestinationDatabase'',DestinationDatabase)
			,F.SequenceBM
			,F.SourceTypeBM
		FROM [pcINTEGRATOR].[dbo].[SqlSource_Model_FACT] F
		INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D
			ON D.DimensionID = F.DimensionID
		INNER JOIN #Models M
			ON F.ModelBM & M.ModelBM > 0
			AND F.SourceTypeBM & M.SourceTypeBM > 0
		WHERE 
			(F.[DimensionID] < 0 OR F.[DimensionID] = 100)
			AND [LinkedBM] & 1 > 0
			AND [RevisionBM] & 1 > 0
			AND SequenceBM > 0
			AND F.SelectYN = 1
	) AS T1
	INNER JOIN (
		SELECT
			ModelName
			,HighestFromSequenceBM = MAX(SequenceBM)
		FROM (
			SELECT
				ModelName
				,SequenceBM =
					CASE
						WHEN MAX(SequenceBM) & 131072 > 0 THEN 131072
						WHEN MAX(SequenceBM) & 65536 > 0 THEN 65536
						WHEN MAX(SequenceBM) & 32768 > 0 THEN 32768
						WHEN MAX(SequenceBM) & 16384 > 0 THEN 16384
						WHEN MAX(SequenceBM) & 8192 > 0 THEN 8192
						WHEN MAX(SequenceBM) & 4096 > 0 THEN 4096
						WHEN MAX(SequenceBM) & 2048 > 0 THEN 2048
						WHEN MAX(SequenceBM) & 1024 > 0 THEN 1024
						WHEN MAX(SequenceBM) & 512 > 0 THEN 512
						WHEN MAX(SequenceBM) & 256 > 0 THEN 256
						WHEN MAX(SequenceBM) & 128 > 0 THEN 128
						WHEN MAX(SequenceBM) & 64 > 0 THEN 64
						WHEN MAX(SequenceBM) & 32 > 0 THEN 32
						WHEN MAX(SequenceBM) & 16 > 0 THEN 16
						WHEN MAX(SequenceBM) & 8 > 0 THEN 8
						WHEN MAX(SequenceBM) & 4 > 0 THEN 4
						WHEN MAX(SequenceBM) & 2 > 0 THEN 2
						WHEN MAX(SequenceBM) = 1 THEN 1
					END'

	SET @SQLStatement = @SQLStatement + '
			FROM [pcINTEGRATOR].[dbo].[SqlSource_Model_FACT] F
			INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D
				ON D.DimensionID = F.DimensionID
			INNER JOIN #Models M
				ON F.ModelBM & M.ModelBM > 0
				AND F.SourceTypeBM & M.SourceTypeBM > 0
			WHERE 
				F.[DimensionID] < 0
				AND [LinkedBM] & 1 > 0
				AND [RevisionBM] & 1 > 0
				AND SequenceBM > 0
				AND F.SelectYN = 1
			GROUP BY ModelName
		) AS T
		GROUP BY ModelName
	) AS T2
		ON T2.ModelName = T1.ModelName
		AND T2.HighestFromSequenceBM & T1.SequenceBM > 0

	--SELECT * FROM #FactSourceStrings

	IF OBJECT_ID(N''tempdb..#DimensionSourceStrings'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #DimensionSourceStrings
		DROP TABLE #DimensionSourceStrings
	END
	SELECT DISTINCT
		T1.*
	INTO #DimensionSourceStrings
	FROM (
		SELECT
			--M.ModelName
			--,D.DimensionID
			PropertyID
			,D.DimensionName
			--,F.SourceString
			,[SourceString] = REPLACE(REPLACE(REPLACE(REPLACE([SourceString],''@SourceDatabase'',SourceDatabase),''@Owner'',SourceOwner),''@SourceID'',SourceID),''@DestinationDatabase'',DestinationDatabase)
			,F.SequenceBM
			,M.SourceID
			,M.SourceTypeBM
			,M.DestinationDatabase
		FROM [pcINTEGRATOR].[dbo].[SqlSource_Dimension] F
		INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D
			ON D.DimensionID = F.DimensionID
		INNER JOIN #Models M
			ON F.ModelBM & M.ModelBM > 0
			AND F.SourceTypeBM & M.SourceTypeBM > 0
		WHERE 
			(F.[DimensionID] < 0 OR F.[DimensionID] = 100)
			AND [LinkedBM] & 1 > 0
			AND [RevisionBM] & 1 > 0
			AND SequenceBM > 0
			AND F.SelectYN = 1
			AND (PropertyID = 5 OR PropertyID = 100)
	) AS T1'

	SET @SQLStatement = @SQLStatement + '
	INNER JOIN (
		SELECT
			DimensionName
			,SourceID = MIN(SourceID)
			,HighestFromSequenceBM = MAX(SequenceBM)
		FROM (
			SELECT
				DimensionName
				,SourceID = MIN(SourceID)
				,SequenceBM =
					CASE
						WHEN MAX(SequenceBM) & 131072 > 0 THEN 131072
						WHEN MAX(SequenceBM) & 65536 > 0 THEN 65536
						WHEN MAX(SequenceBM) & 32768 > 0 THEN 32768
						WHEN MAX(SequenceBM) & 16384 > 0 THEN 16384
						WHEN MAX(SequenceBM) & 8192 > 0 THEN 8192
						WHEN MAX(SequenceBM) & 4096 > 0 THEN 4096
						WHEN MAX(SequenceBM) & 2048 > 0 THEN 2048
						WHEN MAX(SequenceBM) & 1024 > 0 THEN 1024
						WHEN MAX(SequenceBM) & 512 > 0 THEN 512
						WHEN MAX(SequenceBM) & 256 > 0 THEN 256
						WHEN MAX(SequenceBM) & 128 > 0 THEN 128
						WHEN MAX(SequenceBM) & 64 > 0 THEN 64
						WHEN MAX(SequenceBM) & 32 > 0 THEN 32
						WHEN MAX(SequenceBM) & 16 > 0 THEN 16
						WHEN MAX(SequenceBM) & 8 > 0 THEN 8
						WHEN MAX(SequenceBM) & 4 > 0 THEN 4
						WHEN MAX(SequenceBM) & 2 > 0 THEN 2
						WHEN MAX(SequenceBM) = 1 THEN 1
					END
			FROM [pcINTEGRATOR].[dbo].[SqlSource_Dimension] F
			INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D
				ON D.DimensionID = F.DimensionID
			INNER JOIN #Models M
				ON F.ModelBM & M.ModelBM > 0
				AND F.SourceTypeBM & M.SourceTypeBM > 0
			WHERE 
				(F.[DimensionID] < 0 OR F.[DimensionID] = 100)
				AND [LinkedBM] & 1 > 0
				AND [RevisionBM] & 1 > 0
				AND SequenceBM > 0
				AND F.SelectYN = 1
				AND (PropertyID = 5 OR PropertyID = 100)
			GROUP BY DimensionName
		) AS T
		GROUP BY DimensionName
	) AS T2
		ON T2.DimensionName = T1.DimensionName
		AND T2.SourceID = T1.SourceID
		AND T2.HighestFromSequenceBM & T1.SequenceBM > 0'

	SET @SQLStatement = @SQLStatement + '

	--SELECT DISTINCT * FROM #DimensionSourceStrings ORDER BY 2

	IF OBJECT_ID(N''tempdb..#DimensionSourceStringsTables'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #DimensionSourceStringsTables
		DROP TABLE #DimensionSourceStringsTables
	END
	SELECT
		*
		,TableRk = ROW_NUMBER() OVER(PARTITION BY DimensionName ORDER BY PATINDEX(''%'' + TableName + ''%'',SourceStringReplaced))
	INTO #DimensionSourceStringsTables
	FROM (
		SELECT DISTINCT
			DSS.*
			,T.*
			,SourceStringReplaced = REPLACE(REPLACE(REPLACE(REPLACE(DSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)
			--,TableRk = ROW_NUMBER() ORDER BY(PATINDEX(''%'' + T.TableName +''''))
		FROM #DimensionSourceStrings DSS
		INNER JOIN #Models M
			ON M.SourceID = DSS.SourceID
		INNER JOIN #Tables T
			ON (
			DSS.SourceString  LIKE ''%'' + T.DbName + ''.''  + T.SchemaName + ''.'' + T.TableName + ''%''
			OR DSS.SourceString  LIKE ''%\['' + T.DbName + ''].''  + T.SchemaName + ''.'' + T.TableName + ''%'' ESCAPE ''\''
			OR DSS.SourceString  LIKE ''%\['' + T.DbName + ''].\[''  + T.SchemaName + ''].'' + T.TableName + ''%'' ESCAPE ''\''
			OR DSS.SourceString  LIKE ''%\['' + T.DbName + ''].\[''  + T.SchemaName + ''].\['' + T.TableName + '']%'' ESCAPE ''\''
			OR DSS.SourceString  LIKE ''%'' + T.DbName + ''.\[''  + T.SchemaName + ''].\['' + T.TableName + '']%'' ESCAPE ''\''
			OR DSS.SourceString  LIKE ''%'' + T.DbName + ''.''  + T.SchemaName + ''.\['' + T.TableName + '']%'' ESCAPE ''\''
			OR DSS.SourceString  LIKE ''%'' + T.DbName + ''.\[''  + T.SchemaName + ''].'' + T.TableName + ''%'' ESCAPE ''\''
		
			--REPLACE(REPLACE(REPLACE(REPLACE(DSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%'' + T.DbName + ''.''  + T.SchemaName + ''.'' + T.TableName + ''%''
			--OR REPLACE(REPLACE(REPLACE(REPLACE(DSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%\['' + T.DbName + ''].''  + T.SchemaName + ''.'' + T.TableName + ''%'' ESCAPE ''\''
			--OR REPLACE(REPLACE(REPLACE(REPLACE(DSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%\['' + T.DbName + ''].\[''  + T.SchemaName + ''].'' + T.TableName + ''%'' ESCAPE ''\''
			--OR REPLACE(REPLACE(REPLACE(REPLACE(DSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%\['' + T.DbName + ''].\[''  + T.SchemaName + ''].\['' + T.TableName + '']%'' ESCAPE ''\''
			--OR REPLACE(REPLACE(REPLACE(REPLACE(DSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%'' + T.DbName + ''.\[''  + T.SchemaName + ''].\['' + T.TableName + '']%'' ESCAPE ''\''
			--OR REPLACE(REPLACE(REPLACE(REPLACE(DSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%'' + T.DbName + ''.''  + T.SchemaName + ''.\['' + T.TableName + '']%'' ESCAPE ''\''
			--OR REPLACE(REPLACE(REPLACE(REPLACE(DSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%'' + T.DbName + ''.\[''  + T.SchemaName + ''].'' + T.TableName + ''%'' ESCAPE ''\''
			)
		WHERE 
			DSS.PropertyID = 100
			AND M.ModelBM & T.ModelBM > 0
	) AS T1'

	SET @SQLStatement = @SQLStatement + '

	--SELECT * FROM #Tables
	--SELECT * FROM #DimensionSourceStringsTables

	IF OBJECT_ID(N''tempdb..#DimensionSourceStringsColumns'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #DimensionSourceStringsColumns
		DROP TABLE #DimensionSourceStringsColumns
	END
	SELECT
		*
	INTO #DimensionSourceStringsColumns
	FROM (
		SELECT DISTINCT
			DSS.DimensionName
			,DSS.SourceTypeBM
			,DSS.SourceString
			,TableSourceString = REPLACE(REPLACE(REPLACE(REPLACE(DSST.SourceString,''Entity E'', REPLACE(DSS.DestinationDatabase,''DATA'',''ETL'') + ''.dbo.Entity E''),''vw_'',REPLACE(DSS.DestinationDatabase,''DATA'',''ETL'') + ''.dbo.vw_''),''_varchar'',''''),'' AccountType'','' '' + REPLACE(DSS.DestinationDatabase,''DATA'',''ETL'') + ''.dbo.AccountType'')
			,DSST.DbName --AccountType_Translate ATT
			,DSST.SchemaName
			,DSST.TableName
			,TC.ColumnName
			,ColumnRK = ROW_NUMBER() OVER(PARTITION BY DSS.DimensionName ORDER BY PATINDEX(''%'' + TC.ColumnName + ''%'',DSS.SourceString))
		FROM #DimensionSourceStrings DSS
		INNER JOIN #DimensionSourceStringsTables DSST
			ON DSST.DimensionName = DSS.DimensionName
		INNER JOIN #TableColumns TC
			ON 
				TC.TableName = DSST.TableName
				AND (
					DSS.SourceString LIKE ''%'' + TC.ColumnName + ''%'' ESCAPE ''\''
					OR DSS.SourceString LIKE ''%\['' + TC.ColumnName + '']%'' ESCAPE ''\''
				)
		WHERE 
			DSS.PropertyID <> 100
			AND DSST.TableRk = 1
			AND DSST.ModelBM & TC.ModelBM > 0
	) AS T1
	WHERE ColumnRK = 1'

	SET @SQLStatement = @SQLStatement + '

	--SELECT * FROM #DimensionSourceStringsColumns ORDER BY 2

	--Insert Page Table
	/*
	DELETE [dbo].[PageSource]
	DELETE [dbo].[LinkDefinition]
	DELETE [dbo].[PageColumn]
	DBCC CHECKIDENT (''PageColumn'', RESEED, 0)
	DELETE [dbo].[Page]
	DBCC CHECKIDENT (''Page'', RESEED, 0)

	SET IDENTITY_INSERT [dbo].[PageColumn] ON 

	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (-500, N''SEQ DESC'', 0, 0, 1, 0, NULL, 0, 0, 0, 1, 1, 0, N'''')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (-300, N''GROUP BY'', 0, 0, 1, 0, NULL, 0, 0, 0, 1, 1, 0, N'''')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (-200, N''WHERE'', 0, 0, 1, 0, NULL, 0, 0, 0, 1, 1, 0, N'''')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (-100, N''FROM'', 0, 0, 1, 0, NULL, 0, 0, 0, 1, 1, 0, N'''')

	SET IDENTITY_INSERT [dbo].[PageColumn] OFF
	*/

	--Page Fact Tables
	/*
	INSERT INTO [dbo].[Page]
	(
		[PageCode]
		,[PageName]
		,[SelectYN]
		,[Version]
		,[Help_Header]
		,[Help_Description]
		,[Help_Link]
	)
	*/
'

	SET @SQLStatement = @SQLStatement + '
	/*
		CREATE Pages for Fact Views
	*/

	IF OBJECT_ID(N''tempdb..#Page'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #Page
		DROP TABLE #Page
	END
	SELECT DISTINCT
		[PageCode] = CASE WHEN ModelName = ''Financials'' THEN ''Default'' ELSE ''FACT_'' + ModelName + ''_View'' END
		,[PageName] = ''FACT_'' + ModelName + ''_View'' 
		,[SelectYN] = 1
		,[Version] = ''MR''
		,[Help_Header] = ''''
		,[Help_Description] = ''''
		,[Help_Link] = ''''
		,PageID = IDENTITY(INT,1,1)
	INTO #Page
	FROM #FactSourceStrings


	--SELECT * FROM #Page
	--PageSource From Fact Tables

	/*
	INSERT INTO [dbo].[PageSource]
	(
		[Comment]
		,[PageID]
		,[ColumnID]
		,[SourceTypeBM]
		,[RevisionBM]
		,[SequenceBM]
		,[NumericBM]
		,[GroupByYN]
		,[SourceString]
		,[SourceStringCode]
		,[SelectYN]
		,[Version]
		,[InvalidValues]
		,[SampleValue]
	)*/
	'

	SET @SQLStatement = @SQLStatement + '
	/*
		CREATE PageSource for Fact Views
	*/

	IF OBJECT_ID(N''tempdb..#PageSource'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #PageSource
		DROP TABLE #PageSource
	END
	SELECT DISTINCT
		[Comment] = CONVERT(nvarchar(255),N''Page FACT_'' + TD.ModelName + ''_View FROM (SequenceBM=1), Filter (SequenceBM=128), (Sequence 1)'')
		,P.[PageID]
		,[ColumnID] = -100
		,M.[SourceTypeBM]
		,[RevisionBM] = 1
		,[SequenceBM] = 129
		,[NumericBM] = 0
		,[GroupByYN] = 0
		,[SourceString] = ''['' + REPLACE(M.ETLDatabase,''pcETL'',''pcDATA'') + ''].[dbo].[FACT_'' + TD.ModelName + ''_View]''
		,[SourceStringCode] = ''F1''
		,[SelectYN] = 1
		,[Version] = ''''
		,[InvalidValues] = ''''
		,[SampleValue] = ''''
	INTO #PageSource
	FROM #FactSourceStrings TD
	INNER JOIN #Models M
		ON M.ModelName = TD.ModelName
		AND M.SourceTypeBM & TD.SourceTypeBM > 0
	--INNER JOIN [dbo].[Page] P
	INNER JOIN #Page P
		ON P.[PageName] = ''FACT_'' + TD.ModelName + ''_View''

	--SELECT * FROM #PageSource
	--Fact Table Columns'

	SET @SQLStatement = @SQLStatement + '


	/*
	INSERT INTO [dbo].[PageColumn]
	(
		[ColumnName]
		,[PageID]
		,[NumericBM]
		,[SequenceBM]
		,[SortOrder]
		,[ColumnFormat]
		,[LinkPageYN]
		,[FilterYN]
		,[FilterValueMandatoryYN]
		,[SelectYN]
		,[DefaultYN]
		,[DeletedYN]
		,[Version]
	)
	*/


	/*
		CREATE PageColumn for Fact Views
	*/

	IF OBJECT_ID(N''tempdb..#PageColumn'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #PageColumn
		DROP TABLE #PageColumn
	END'

	SET @SQLStatement = @SQLStatement + '
	SELECT
		[ColumnName] = TD.DimensionName
		,[PageID]
		,[NumericBM] = 0
		,[SequenceBM] = 1
		,[SortOrder] = ROW_NUMBER() OVER(PARTITION BY [PageID] ORDER BY TD.DimensionName DESC) * 10
		,[ColumnFormat] = ''''
		,[LinkPageYN] = 0
		,TD.[FilterYN] 
		,[FilterValueMandatoryYN] = 0
		,[SelectYN] = CASE WHEN TD.DimensionName IN(''FullAccount'',''TimeDay'') THEN 0 ELSE 1 END
		,[DefaultYN] = 1
		,[DeletedYN] = 0
		,[Version] = ''MR''
		,ColumnID = IDENTITY(INT,1,1)
	INTO #PageColumn
	FROM (
		SELECT
			P.[PageID]
			,TD1.DimensionName
			,[FilterYN] = MAX(CASE WHEN DSS.DimensionName IS NULL THEN 0 ELSE 1 END)
		FROM #FactSourceStrings TD1
		--INNER JOIN [dbo].[Page] P
		INNER JOIN #Page P
			ON P.[PageName] = ''FACT_'' + TD1.ModelName + ''_View''
		LEFT JOIN #DimensionSourceStringsColumns DSS
			ON DSS.DimensionName = TD1.DimensionName
		GROUP BY 
			P.[PageID]
			,TD1.DimensionName
	) AS TD
	WHERE TD.DimensionName <> ''FROM''

	--SELECT * FROM #PageColumn
	--PageSource Fact Table Columns


	/*
		INSERT PageSource for Source of columns in Fact Views
	*/'

	SET @SQLStatement = @SQLStatement + '

	--INSERT INTO [dbo].[PageSource]
	INSERT INTO #PageSource
	(
		[Comment]
		,[PageID]
		,[ColumnID]
		,[SourceTypeBM]
		,[RevisionBM]
		,[SequenceBM]
		,[NumericBM]
		,[GroupByYN]
		,[SourceString]
		,[SourceStringCode]
		,[SelectYN]
		,[Version]
		,[InvalidValues]
		,[SampleValue]
	)
	SELECT DISTINCT
		[Comment] = N''Page FACT_'' + TD.ModelName + ''_View '' + PC.ColumnName + '' (SequenceBM=1), Filter (SequenceBM=128), FilterValue (SequenceBM=32), FilterDescription (SequenceBM=64), (Sequence 1)''
		,P.[PageID]
		,[ColumnID] = PC.ColumnID
		,TD.[SourceTypeBM]
		,[RevisionBM] = 1
		,[SequenceBM] = 225
		,[NumericBM] = 0
		,[GroupByYN] = 0
		,[SourceString] = ''['' + DimensionName + '']''
		,[SourceStringCode] = ''F1''
		,[SelectYN] = 1
		,[Version] = ''''
		,[InvalidValues] = ''''
		,[SampleValue] = ''''
	FROM #FactSourceStrings TD
	INNER JOIN #Models M
		ON M.ModelName = TD.ModelName
		AND M.SourceTypeBM & TD.SourceTypeBM > 0
	--INNER JOIN [dbo].[Page] P
	INNER JOIN #Page P
		ON P.[PageName] = ''FACT_'' + TD.ModelName + ''_View''
	--INNER JOIN [dbo].[PageColumn] PC
	INNER JOIN #PageColumn PC
		ON PC.[ColumnName] = TD.DimensionName
		AND PC.[PageID] = P.[PageID]
	WHERE DimensionName <> ''FROM''

	--SELECT * FROM #PageSource ORDER BY 2'

	SET @SQLStatement = @SQLStatement + '


	/*
		CREATE #FactSourceStringsTables to be used to get the source tables
	*/

	IF OBJECT_ID(N''tempdb..#FactSourceStringsTables'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #FactSourceStringsTables
		DROP TABLE #FactSourceStringsTables
	END
	SELECT
		*
		,TableRk = ROW_NUMBER() OVER(PARTITION BY ModelName ORDER BY PATINDEX(''%'' + TableName + ''%'',SourceStringReplaced))
	INTO #FactSourceStringsTables
	FROM (
		SELECT DISTINCT
			FSS.*
			,T.*
			,SourceStringReplaced = REPLACE(REPLACE(REPLACE(REPLACE(FSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)
			--,TableRk = ROW_NUMBER() ORDER BY(PATINDEX(''%'' + T.TableName +''''))
		FROM #FactSourceStrings FSS
		INNER JOIN #Models M
			ON M.ModelName = FSS.ModelName
		INNER JOIN #Tables T
			ON (
			FSS.SourceString  LIKE ''%'' + T.DbName + ''.''  + T.SchemaName + ''.'' + T.TableName + ''%''
			OR FSS.SourceString  LIKE ''%\['' + T.DbName + ''].''  + T.SchemaName + ''.'' + T.TableName + ''%'' ESCAPE ''\''
			OR FSS.SourceString  LIKE ''%\['' + T.DbName + ''].\[''  + T.SchemaName + ''].'' + T.TableName + ''%'' ESCAPE ''\''
			OR FSS.SourceString  LIKE ''%\['' + T.DbName + ''].\[''  + T.SchemaName + ''].\['' + T.TableName + '']%'' ESCAPE ''\''
			OR FSS.SourceString  LIKE ''%'' + T.DbName + ''.\[''  + T.SchemaName + ''].\['' + T.TableName + '']%'' ESCAPE ''\''
			OR FSS.SourceString  LIKE ''%'' + T.DbName + ''.''  + T.SchemaName + ''.\['' + T.TableName + '']%'' ESCAPE ''\''
			OR FSS.SourceString  LIKE ''%'' + T.DbName + ''.\[''  + T.SchemaName + ''].'' + T.TableName + ''%'' ESCAPE ''\'''

	SET @SQLStatement = @SQLStatement + '
		
			--REPLACE(REPLACE(REPLACE(REPLACE(FSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%'' + T.DbName + ''.''  + T.SchemaName + ''.'' + T.TableName + ''%''
			--OR REPLACE(REPLACE(REPLACE(REPLACE(FSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%\['' + T.DbName + ''].''  + T.SchemaName + ''.'' + T.TableName + ''%'' ESCAPE ''\''
			--OR REPLACE(REPLACE(REPLACE(REPLACE(FSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%\['' + T.DbName + ''].\[''  + T.SchemaName + ''].'' + T.TableName + ''%'' ESCAPE ''\''
			--OR REPLACE(REPLACE(REPLACE(REPLACE(FSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%\['' + T.DbName + ''].\[''  + T.SchemaName + ''].\['' + T.TableName + '']%'' ESCAPE ''\''
			--OR REPLACE(REPLACE(REPLACE(REPLACE(FSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%'' + T.DbName + ''.\[''  + T.SchemaName + ''].\['' + T.TableName + '']%'' ESCAPE ''\''
			--OR REPLACE(REPLACE(REPLACE(REPLACE(FSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%'' + T.DbName + ''.''  + T.SchemaName + ''.\['' + T.TableName + '']%'' ESCAPE ''\''
			--OR REPLACE(REPLACE(REPLACE(REPLACE(FSS.SourceString,''@SourceDatabase'',M.SourceDatabase),''@Owner'',M.SourceOwner),''@SourceID'',M.SourceID),''@DestinationDatabase'',M.DestinationDatabase)  LIKE ''%'' + T.DbName + ''.\[''  + T.SchemaName + ''].'' + T.TableName + ''%'' ESCAPE ''\''
		
			)
		WHERE 
			FSS.DimensionName = ''FROM''
			AND M.ModelBM & T.ModelBM > 0
	) AS T1


	/*
		CREATE #FactSourceStringsColumns to be used to get the source columns
	*/

	IF OBJECT_ID(N''tempdb..#FactSourceStringsColumns'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #FactSourceStringsColumns
		DROP TABLE #FactSourceStringsColumns
	END
	SELECT DISTINCT
		FactTable = ''FACT_'' + FSS.ModelName + ''_View''
		,FSS.DimensionName
		,FSS.SourceTypeBM
		,FSS.SourceString
		,SourceStringTable = FSST.SourceString
		,TC.DbName
		,TC.SchemaName
		,TC.TableName
		,TC.ColumnName
		,TC.SortOrder
		,DimensionRk = ROW_NUMBER() OVER(PARTITION BY FSS.ModelName,FSS.DimensionName ORDER BY Convert(INT,SortOrder))
	INTO #FactSourceStringsColumns
	FROM #TableColumns TC
	INNER JOIN #FactSourceStringsTables FSST
		ON FSST.TableName = TC.TableName
		AND FSST.DbName = TC.DbName
	INNER JOIN #FactSourceStrings FSS
		ON FSS.ModelName = FSST.ModelName
		AND FSS.DimensionName <> ''FROM''
		AND (
			FSS.SourceString LIKE ''%'' + TC.ColumnName + ''%''
		)
	WHERE FSST.TableRk = 1'

	SET @SQLStatement = @SQLStatement + '

	/*
		INSERT #Page all pages of the source tables
	*/

	INSERT INTO #Page
	(
		[PageCode]
		,[PageName]
		,[SelectYN]
		,[Version]
		,[Help_Header]
		,[Help_Description]
		,[Help_Link]
	)
	SELECT DISTINCT
		[PageCode] = TableName
		,[PageName] = TableName
		,[SelectYN] = 1
		,[Version] = ''MR''
		,[Help_Header] = ''''
		,[Help_Description] = ''''
		,[Help_Link] = ''''
	FROM #FactSourceStringsColumns

	--SELECT * FROM #Page

	/*
		INSERT #PageSource all pages of the source tables
	*/

	INSERT INTO #PageSource
	(
		[Comment]
		,[PageID]
		,[ColumnID]
		,[SourceTypeBM]
		,[RevisionBM]
		,[SequenceBM]
		,[NumericBM]
		,[GroupByYN]
		,[SourceString]
		,[SourceStringCode]
		,[SelectYN]
		,[Version]
		,[InvalidValues]
		,[SampleValue]
	)
	SELECT DISTINCT
		[Comment] = N''Page '' + FSSC.TableName + '' FROM (SequenceBM=1), Filter (SequenceBM=128), (Sequence 1)''
		,P.[PageID]
		,[ColumnID] = -100
		,FSSC.[SourceTypeBM]
		,[RevisionBM] = 1
		,[SequenceBM] = 129
		,[NumericBM] = 0
		,[GroupByYN] = 0
		,[SourceString] = ''['' + FSSC.DbName + ''].['' + FSSC.SchemaName + ''].['' + FSSC.TableName + '']''
		,[SourceStringCode] = UPPER(LEFT(FSSC.TableName,1)) + ''1''
		,[SelectYN] = 1
		,[Version] = ''''
		,[InvalidValues] = ''''
		,[SampleValue] = ''''
	FROM #FactSourceStringsColumns FSSC
	INNER JOIN #Page P
		ON P.PageCode = FSSC.TableName'

	SET @SQLStatement = @SQLStatement + '

	--SELECT * FROM #PageSource ORDER BY 2

	/*
		INSERT #PageColumn all Columns that exist in the fact tables and the source tables
	*/

	INSERT INTO #PageColumn
	(
		[ColumnName]
		,[PageID]
		,[NumericBM]
		,[SequenceBM]
		,[SortOrder]
		,[ColumnFormat]
		,[LinkPageYN]
		,[FilterYN]
		,[FilterValueMandatoryYN]
		,[SelectYN]
		,[DefaultYN]
		,[DeletedYN]
		,[Version]
	)
	SELECT
		[ColumnName]
		,[PageID]
		,[NumericBM] = 0
		,[SequenceBM] = 1
		,[SortOrder] = ROW_NUMBER() OVER(PARTITION BY [PageID] ORDER BY [ColumnName] DESC) * 10
		,[ColumnFormat] = ''''
		,[LinkPageYN] = 0
		,[FilterYN] = FSSC.[FilterYN]
		,[FilterValueMandatoryYN] = 0
		,[SelectYN] = CASE WHEN [ColumnName] IN (''FullAccount'',''TimeDay'') THEN 0 ELSE 1 END
		,[DefaultYN] = 1
		,[DeletedYN] = 0
		,[Version] = ''MR''
	FROM (
		SELECT
			TableName
			,[ColumnName]
			,[FilterYN] = MAX(CASE WHEN FSSC.DimensionRk < 11 THEN 1 ELSE 0 END)
		FROM #FactSourceStringsColumns FSSC
		GROUP BY 
			TableName
			,[ColumnName]
	) AS FSSC
	INNER JOIN #Page P
		ON P.PageCode = FSSC.TableName'

	SET @SQLStatement = @SQLStatement + '

	--SELECT * FROM #PageColumn


	/*
		INSERT #PageSource all Columns that exist in the fact tables and the source tables
	*/
	
	INSERT INTO #PageSource
	(
		[Comment]
		,[PageID]
		,[ColumnID]
		,[SourceTypeBM]
		,[RevisionBM]
		,[SequenceBM]
		,[NumericBM]
		,[GroupByYN]
		,[SourceString]
		,[SourceStringCode]
		,[SelectYN]
		,[Version]
		,[InvalidValues]
		,[SampleValue]
	)
	SELECT DISTINCT
		[Comment] = N''Page '' + FSSC.TableName + '', '' + FSSC.ColumnName + '', (SequenceBM=1), Filter (SequenceBM=128), FilterValue (SequenceBM=32), FilterDescription (SequenceBM=64), (Sequence 1)''
		,P.[PageID]
		,[ColumnID] = PC.ColumnID
		,FSSC.[SourceTypeBM]
		,[RevisionBM] = 1
		,[SequenceBM] = 225
		,[NumericBM] = 0
		,[GroupByYN] = 0
		,[SourceString] = ''['' + FSSC.ColumnName + '']''
		,[SourceStringCode] = UPPER(LEFT(FSSC.TableName,1)) + ''1''
		,[SelectYN] = 1
		,[Version] = ''''
		,[InvalidValues] = ''''
		,[SampleValue] = ''''
	FROM #FactSourceStringsColumns FSSC
	INNER JOIN #Page P
		ON P.PageCode = FSSC.TableName
	INNER JOIN #PageColumn PC
		ON PC.ColumnName = FSSC.ColumnName
		AND PC.PageID = P.PageID'

	SET @SQLStatement = @SQLStatement + '


	
	/*
		CREATE #Links to connect the pages
	*/
	IF OBJECT_ID(N''tempdb..#Links'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #Links
		DROP TABLE #Links
	END

	SELECT DISTINCT
		SourcePageID = P1.PageID
		,SourceColumnID = PC1.ColumnID
		,SourcePage = DestinationPage.FactTable
		,SourceColumn = SourcePage.DimensionName
		,SourcePage.SourceTypeBM
		,SourceString = SourcePage.SourceString
		,DestinationPage = DestinationPage.TableName
		--,DestinationColumn = DestinationPage.ColumnName
		,DestinationPageID = P2.PageID
		,DestinationColumnID = PC2.ColumnID
		,DestinationPage.DimensionRk
	INTO #Links
	FROM #FactSourceStringsColumns DestinationPage
	INNER JOIN #FactSourceStrings SourcePage
		ON ''FACT_'' + SourcePage.ModelName + ''_View'' = DestinationPage.FactTable
		AND SourcePage.DimensionName = DestinationPage.DimensionName
	INNER JOIN #Page P1
		ON P1.PageName = ''FACT_'' + SourcePage.ModelName + ''_View''
	INNER JOIN #PageColumn PC1
		ON PC1.PageID = P1.PageID
		AND PC1.ColumnName = SourcePage.DimensionName
	INNER JOIN #Page P2
		ON P2.PageName = DestinationPage.TableName
	INNER JOIN #PageColumn PC2
		ON PC2.PageID = P2.PageID
		AND PC2.ColumnName = DestinationPage.ColumnName
	WHERE 
		SourcePage.DimensionName <> ''FROM''
		AND PC2.FilterYN = 1
		AND NOT (SourcePage.SourceString LIKE ''%+%'')
		AND NOT (SourcePage.SourceString LIKE ''%CONVERT%'')

	--SELECT * FROM #Links WHERE SourcePageID = 1
	/*
		CREATE #LinkDefinition to be used when populating the tables
	*/
	IF OBJECT_ID(N''tempdb..#LinkDefinition'') IS NOT NULL
	BEGIN
		TRUNCATE TABLE #LinkDefinition
		DROP TABLE #LinkDefinition
	END
	SELECT
		[StartColumnID] = SourceColumnID
		  ,[StartColumnValue] = ''@@@@@''
		  ,[ParameterColumnID] = DestinationColumnID
		  ,[SelectYN] = 1
		  ,[Version] = ''MR''
	INTO #LinkDefinition
	FROM #Links
	WHERE DimensionRk = 1'

	SET @SQLStatement = @SQLStatement + '

	/*
		INSERT #PageSource all links
	*/
	-- DELETE #PageSource WHERE [Comment] LIKE ''%Linked%''
	INSERT INTO #PageSource
	(
		[Comment]
		,[PageID]
		,[ColumnID]
		,[SourceTypeBM]
		,[RevisionBM]
		,[SequenceBM]
		,[NumericBM]
		,[GroupByYN]
		,[SourceString]
		,[SourceStringCode]
		,[SelectYN]
		,[Version]
		,[InvalidValues]
		,[SampleValue]
	)
	SELECT DISTINCT
		[Comment] = N''Page '' + L.SourcePage + '', '' + L.SourceColumn + '', (SequenceBM=1) Linked to '' + L.DestinationPage
		,L.SourcePageID
		,[ColumnID] = L.DestinationColumnID
		,L.[SourceTypeBM]
		,[RevisionBM] = 1
		,[SequenceBM] = 1
		,[NumericBM] = 0
		,[GroupByYN] = 0
		,[SourceString] = ''['' + L.SourceColumn + '']''
		,[SourceStringCode] = ''F1''
		,[SelectYN] = 1
		,[Version] = ''''
		,[InvalidValues] = ''''
		,[SampleValue] = ''''
	FROM #Links L
	WHERE DimensionRk = 1'

	SET @SQLStatement = @SQLStatement + '

	--SELECT * FROM #Links L
	--WHERE DimensionRk = 1
	--SELECT * FROM #PageSource ORDER BY 2,3


	DELETE [PageSource]
	DELETE wrk_ParameterCode
	DELETE LinkDefinition
	DELETE [PageColumn]
	DELETE [Page]

	SET IDENTITY_INSERT [dbo].[Page] ON 

	INSERT INTO [Page]
	(
		PageID
		,[PageCode]
		,[PageName]
		,[SelectYN]
		,[Version]
		,[Help_Header]
		,[Help_Description]
		,[Help_Link]
	)
	SELECT
		PageID
		,[PageCode]
		,[PageName]
		,[SelectYN]
		,[Version]
		,[Help_Header]
		,[Help_Description]
		,[Help_Link]
	FROM #Page

	SET IDENTITY_INSERT [dbo].[Page] OFF'

	SET @SQLStatement = @SQLStatement + '

	SET IDENTITY_INSERT [dbo].[PageColumn] ON

	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (-500, N''SEQ DESC'', 0, 0, 1, 0, NULL, 0, 0, 0, 1, 1, 0, N'''')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (-300, N''GROUP BY'', 0, 0, 1, 0, NULL, 0, 0, 0, 1, 1, 0, N'''')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (-200, N''WHERE'', 0, 0, 1, 0, NULL, 0, 0, 0, 1, 1, 0, N'''')
	INSERT [dbo].[PageColumn] ([ColumnID], [ColumnName], [PageID], [NumericBM], [SequenceBM], [SortOrder], [ColumnFormat], [LinkPageYN], [FilterYN], [FilterValueMandatoryYN], [SelectYN], [DefaultYN], [DeletedYN], [Version]) VALUES (-100, N''FROM'', 0, 0, 1, 0, NULL, 0, 0, 0, 1, 1, 0, N'''')

	INSERT INTO [PageColumn]
	(
		ColumnID
		,[ColumnName]
		,[PageID]
		,[NumericBM]
		,[SequenceBM]
		,[SortOrder]
		,[ColumnFormat]
		,[LinkPageYN]
		,[FilterYN]
		,[FilterValueMandatoryYN]
		,[SelectYN]
		,[DefaultYN]
		,[DeletedYN]
		,[Version]
	)
	SELECT
		ColumnID	
		,[ColumnName]
		,[PageID]
		,[NumericBM]
		,[SequenceBM]
		,[SortOrder]
		,[ColumnFormat]
		,[LinkPageYN]
		,[FilterYN]
		,[FilterValueMandatoryYN]
		,[SelectYN]
		,[DefaultYN]
		,[DeletedYN]
		,[Version]
	FROM #PageColumn
	SET IDENTITY_INSERT [dbo].[PageColumn] OFF'

	SET @SQLStatement = @SQLStatement + '

	INSERT INTO [PageSource]
	(
		[Comment]
		,[PageID]
		,[ColumnID]
		,[SourceTypeBM]
		,[RevisionBM]
		,[SequenceBM]
		,[NumericBM]
		,[GroupByYN]
		,[SourceString]
		,[SourceStringCode]
		,[SelectYN]
		,[Version]
		,[InvalidValues]
		,[SampleValue]
	)
	SELECT
		[Comment]
		,[PageID]
		,[ColumnID]
		,[SourceTypeBM]
		,[RevisionBM]
		,[SequenceBM]
		,[NumericBM]
		,[GroupByYN]
		,[SourceString]
		,[SourceStringCode]
		,[SelectYN]
		,[Version]
		,[InvalidValues]
		,[SampleValue]
	FROM #PageSource '

	SET @SQLStatement = @SQLStatement + '

	INSERT INTO [dbo].[LinkDefinition]
	(
		[StartColumnID]
		,[StartColumnValue]
		,[ParameterColumnID]
		,[SelectYN]
		,[Version]
	)
	SELECT
		[StartColumnID]
		,[StartColumnValue]
		,[ParameterColumnID]
		,[SelectYN]
		,[Version]
	FROM #LinkDefinition

	EXEC [dbo].[spInsert_wrk_ParameterCode]

	UPDATE PC
	SET LinkPageYN = 1
	FROM [dbo].[PageColumn] PC
	INNER JOIN [dbo].[LinkDefinition] LD
		ON LD.StartColumnID = PC.ColumnID

	TRUNCATE TABLE [dbo].[SystemParameter] 
	INSERT [dbo].[SystemParameter] 
	(
		[SystemParameterID]
		,[web_Server]
		,[Filter_CB_Limit]
		,[Return_Row_Limit]
		,[DateFormat]
		,[CurrencyFormat]
		,[pcData_DBName]
		,[pcData_OwnerName]
		,[sourceDB_DBName]
		,[sourceDB_OwnerName]
		,[sourceTypeBM]
	)
	SELECT
		[SystemParameterID] = 1
		,[web_Server] = 90
		,[Filter_CB_Limit] = 100
		,[Return_Row_Limit] = 100
		,[DateFormat] = 1
		,[CurrencyFormat] = 1
		,[pcData_DBName] = @DestinationDatabase
		,[pcData_OwnerName] = ''dbo''
		,[sourceDB_DBName] = @SourceDatabase
		,[sourceDB_OwnerName] = @SourceOwner
		,[sourceTypeBM] = @SourceTypeBM
END'


	SET @SQLStatement = @SQLStatement + '
SET @SQLStatement = ''
CREATE TRIGGER [dbo].[LinkDefinition_Upd]
	ON [dbo].[LinkDefinition]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [pcINTEGRATOR]..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + '''' CUSTOM '''' + SUSER_NAME() + '''' '''' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE LD
	SET
		[Version] = @Version
	FROM
		[LinkDefinition] LD
		INNER JOIN Inserted I ON	
			I.StartColumnID = LD.StartColumnID AND
			I.StartColumnValue = LD.StartColumnValue AND
			I.ParameterColumnID = LD.ParameterColumnID''

	EXEC (@SQLStatement)'

	SET @SQLStatement = @SQLStatement + '
SET @SQLStatement = ''
CREATE TRIGGER [dbo].[Page_Upd]
	ON [dbo].[Page]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [pcINTEGRATOR]..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + '''' CUSTOM '''' + SUSER_NAME() + '''' '''' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE LD
	SET
		[Version] = @Version
	FROM
		[Page] LD
		INNER JOIN Inserted I ON	
			I.PageID = LD.PageID''

	EXEC (@SQLStatement)'

	SET @SQLStatement = @SQLStatement + '
SET @SQLStatement = ''
CREATE TRIGGER [dbo].[PageColumn_Upd]
	ON [dbo].[PageColumn]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [pcINTEGRATOR]..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + '''' CUSTOM '''' + SUSER_NAME() + '''' '''' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE LD
	SET
		[Version] = @Version
	FROM
		[PageColumn] LD
		INNER JOIN Inserted I ON	
			I.ColumnID = LD.ColumnID''

	EXEC (@SQLStatement)'

	SET @SQLStatement = @SQLStatement + '
SET @SQLStatement = ''
CREATE TRIGGER [dbo].[PageSource_Upd]
	ON [dbo].[PageSource]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [pcINTEGRATOR]..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + '''' CUSTOM '''' + SUSER_NAME() + '''' '''' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE PS
	SET
		[Version] = @Version
	FROM
		[PageSource] PS
		INNER JOIN Inserted I ON	
			I.PageID = PS.PageID AND
			I.ColumnID = PS.ColumnID AND
			I.SourceTypeBM = PS.SourceTypeBM AND
			I.RevisionBM = PS.RevisionBM AND
			I.SequenceBM = PS.SequenceBM''

	EXEC (@SQLStatement)'

		SET @SQLStatement = REPLACE(@SQLStatement,'''','''''')
		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
		BEGIN
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'CREATE PROCEDURE [dbo].[spPopulate_DrillPageTables] ', [SQLStatement] = @SQLStatement
			SELECT * FROM #wrk_debug
			WHERE StepName = @Step
		END

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1
	END

	---------------------------
	SET @Step = 'POPULATE TABLES'
	---------------------------

	SET @Step = 'Populate all tables based on values from pcINTEGRATOR'
		SET @SQLStatement = 'EXEC spPopulate_DrillPageTables @ApplicationID = ' + CONVERT(NVARCHAR(10),@ApplicationID)

		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'EXEC spPopulate_DrillPageTables ', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1
		
	---------------------------
	SET @Step = 'CREATE PAGE PROCEDURES'
	---------------------------

	SET @Step = 'Create Page Procedures to be used by the webapplication'
		SET @SQLStatement = 'EXEC spRunAll_spCreate_PageProcedure'

		SET @SQLStatement = 'EXEC ' + @pcDrillPage + '.dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'EXEC spRunAll_spCreate_PageProcedure', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + 1

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated
		RETURN 0

	SET @Step = 'EXITPOINT:'
		EXITPOINT:
		SET @Duration = GetDate() - @StartTime
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ErrorNumber = -1000, ErrorSeverity = 10, ErrorState = 0, ErrorLine = 0, ErrorProcedure = OBJECT_NAME(@@PROCID), @Step, ErrorMessage = 'The database ' + @pcDrillPage + ' already exists. To get it replaced, delete the database manually and rerun the procedure.', @Version
		SET @JobLogID = @@IDENTITY
		SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
		SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
		RETURN @ErrorNumber
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

GO
