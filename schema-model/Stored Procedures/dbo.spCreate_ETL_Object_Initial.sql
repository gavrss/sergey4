SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_ETL_Object_Initial]

	@ApplicationID int = NULL,
	@DataBaseBM int = 3, --1 = pcETL, 2 = pcDATA, 3 = All databases
	@JobID int = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_ETL_Object_Initial] @ApplicationID = 400, @DataBaseBM = 1, @Debug = true
--EXEC [spCreate_ETL_Object_Initial] @ApplicationID = 400, @DataBaseBM = 2, @Debug = true
--EXEC [spCreate_ETL_Object_Initial] @ApplicationID = 600, @DataBaseBM = 1, @Debug = true
--EXEC [spCreate_ETL_Object_Initial] @ApplicationID = 600, @DataBaseBM = 2, @Debug = true
--EXEC [spCreate_ETL_Object_Initial] @ApplicationID = 1312, @DataBaseBM = 1, @Debug = true
--EXEC [spCreate_ETL_Object_Initial] @ApplicationID = -1020, @DataBaseBM = 1, @Debug = true
--EXEC [spCreate_ETL_Object_Initial] @ApplicationID = -1234, @DataBaseBM = 1, @Debug = true
--EXEC [spCreate_ETL_Object_Initial] @ApplicationID = -1157, @DataBaseBM = 1, @Debug = true

/*
Main parts:
SET @Step = 'Set procedure variables'
SET @Step = 'CREATE TABLES'
	IF @DataBaseBM & 1 > 0 --pcETL
	IF @DataBaseBM & 2 > 0 --pcDATA
SET @Step = 'CREATE PROCEDURES'
	IF @DataBaseBM & 1 > 0 --pcETL
	IF @DataBaseBM & 2 > 0 --pcDATA
SET @Step = 'CREATE FUNCTIONS'
*/

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@InstanceID int,
	@VersionID int,
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@FiscalYearStartMonth int,
	@SQLStatement nvarchar(max),
	@iScalaYN bit,
	@EpicorErpYN bit,
	@SourceDBTypeBM int,
	@SourceID int,
	@ApplicationName nvarchar(100),
	@Number int,
	@SQLProcedureList nvarchar(max) = '',
	@Collation nvarchar(50),
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.0.2.2149'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2053' SET @Description = 'Version handling added to included procedures'
		IF @Version = '1.2.2057' SET @Description = 'ETL database set to SIMPLE RECOVERY'
		IF @Version = '1.2.2058' SET @Description = 'Rows in [XT_LST_CashFlow_Setup] are replaced'
		IF @Version = '1.2.2061' SET @Description = 'In dev phase, pcINTEGRATOR is used on all places instead of pcINTEGRATOR, spCreate_Canvas_Export_Financials_AFR is fixed regarding Segvalue1'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.2.2065' SET @Description = 'Handle SourceTypeID = 6, pcEXCHANGE. @Version added as parameter in spCreate_Canvas_Export_Financials_AFR. spCreate_Canvas_Export_Financials_AFR is only created when @EpicorErpYN <> 0.'
		IF @Version = '1.2.2067' SET @Description = 'Added brackets around tablenames in spSet_MemberId and spSet_HierarchyCopy, Rows added to ReplaceText.'
		IF @Version = '1.3.2070' SET @Description = 'SourceID for spCreate_Canvas_Export_Financials_AFR adjusted.'
		IF @Version = '1.3.2071' SET @Description = 'Procedure [spFormGetCB_ModelBM] updated. Table MemberSelection Added'
		IF @Version = '1.3.2073' SET @Description = 'Table BudgetSelection Added, Add rows to table [EventDefinition] in the pcDATA database'
		IF @Version = '1.3.2074' SET @Description = 'spSet_MemberId increased performance'
		IF @Version = '1.3.2075' SET @Description = 'Implement difference between EntityCode and Entity, added procedures for new forms'
		IF @Version = '1.3.2083' SET @Description = 'Change Entity trigger to handle pcEXCHANGE'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption, spSet_MemberId handles odd signs in dimension names.'
		IF @Version = '1.3.2085' SET @Description = 'Added Canvas_Get_Logo procedure'
		IF @Version = '1.3.2089' SET @Description = 'Adjusted Canvas_Get_Logo procedure'
		IF @Version = '1.3.2095' SET @Description = 'Added RNodeType'
		IF @Version = '1.3.2096' SET @Description = 'Adjusted spIU_0000_ETL_wrk_SourceTable'
		IF @Version = '1.3.2098' SET @Description = 'Added ORDER BY on spSet_MemberId. Added table FinancialSegment. Replaced vw_XXXX_Dimension_Finance_Metadata with FinancialSegment.'
		IF @Version = '1.3.2100' SET @Description = 'Updated Canvas_Export_Financials. Now support for DMT. Objects are created when @Debug <> 0.'
		IF @Version = '1.3.2101' SET @Description = 'Added procedure spSet_LeafCheck.'
		IF @Version = '1.3.2104' SET @Description = 'Added field Hint to AccountType_Translate. Added wrk_EntityPriority tables. Added fields to TransactionType_iScala, Trigger on MappedObjectName. Dash added to ReplaceText.'
		IF @Version = '1.3.2105' SET @Description = 'Fixed bug regarding TransactionType_iScala (Too long string).'
		IF @Version = '1.3.2106' SET @Description = 'Handle Property SBZ and modified CheckSum functionality. LST tables updated.'
		IF @Version = '1.3.2107' SET @Description = 'Input parameter changed from @InstanceID to @ApplicationID. Procedure spIU_Load_All check for severe errors.'
		IF @Version = '1.3.2108' SET @Description = 'Bugfix in Canvas_ETL_CheckSum.'
		IF @Version = '1.3.2109' SET @Description = 'spSet_MemberId now starts on 1001. Fixed MemberIds for all Static Members. Parameter @ApplicationID added to [spFormGetCB_ModelBM]. Change test of SourceDBType from ID to BM.'
		IF @Version = '1.3.2109' SET @Description = 'Fixed MemberIds for all Static Members including time dimensions.'
		IF @Version = '1.3.2110' SET @Description = 'Added spIU_0000_FACT_FxTrans procedure.'
		IF @Version = '1.3.2111' SET @Description = 'spIU_0000_FACT_FxTrans procedure handle Entity specific calculation for selected entities. Added Navision. Changed spSet_LeafCheck to handle Segments.'
		IF @Version = '1.3.2112' SET @Description = 'Added replacement of all standard reports in every nightload. Added debug tables to pcDATA db.'
		IF @Version = '1.3.2115' SET @Description = 'Added procedure spFix_ChangedLabel.'
		IF @Version = '1.3.2116' SET @Description = 'Changed logging logic for spIU_0000_Time_Property. Handle unicode. Dot added to ReplaceText.'
		IF @Version = '1.3.2117' SET @Description = 'HelpText added to wrk_Dimension.'
		IF @Version = '1.3.0.2118' SET @Description = 'Modified spIU_0000_FACT_FxTrans for pcEXCHANGE.'
		IF @Version = '1.3.1.2120' SET @Description = 'Modified spIU_0000_FACT_FxTrans to handle manually added dimensions into FACT tables.'
		IF @Version = '1.3.1.2123' SET @Description = 'spFormGetCB_MappedObjectName: Test on SelectYN <> 0 in MappedObject.'
		IF @Version = '1.3.1.2124' SET @Description = 'Bugfix on Procedure spFix_ChangedLabel handling pcPlaceHolder.'
		IF @Version = '1.4.0.2128' SET @Description = 'Handle case sensitive.'
		IF @Version = '1.4.0.2129' SET @Description = 'Changed parameter order on SP Canvas_Export_Financials. Changed Trigger on table Entity. Added parameters to LeafCheck SP. spRun_BR_All added.'
		IF @Version = '1.4.0.2130' SET @Description = 'Bugs on "spRun_BR_All" and "Canvas_Export_Financials" fixed. spCheck_CheckSum changed.'
		IF @Version = '1.4.0.2131' SET @Description = 'Changed default values for LST_BusinessRuleETL.'
		IF @Version = '1.4.0.2133' SET @Description = '[DynamicYN] added to FinancialSegment ETL-table.'
		IF @Version = '1.4.0.2135' SET @Description = 'Added DatabaseName to Load table. Enhanced Errorhandling on spCheck_CheckSum. Changed trigger on Entity table to handle manually changes of Entity. Fixed FiscalYear bug on spFix_ChangedLabel.'
		IF @Version = '1.4.0.2136' SET @Description = 'Changed Severity in spCheck_CheckSum when pcPortal URL is missing from 16 to 10.'
		IF @Version = '1.4.0.2137' SET @Description = 'TransactionType_iScala; BusinessProcess = ''iScala'' changed to NULL.'
		IF @Version = '1.4.0.2139' SET @Description = 'spIU_0000_FACT_FxTrans reads automatically from wrk_FACT_Update if #FACT_Update is not available. spIU_0000_ETL_wrk_SourceTable adjusted for Cloud-environment. Handle negative ApplicationID. Simplified Trigger on Entity table. spFix_ChangedLabel check SelectYN in Member table. Canvas_Get_BrandInfo & Canvas_Get_Logo dependent on InstanceID'
		IF @Version = '2.0.0.2140' SET @Description = 'Added columns to table JobLog.'
		IF @Version = '2.0.0.2141' SET @Description = 'Fixed bug regarding constraints for JobLog.'
		IF @Version = '2.0.1.2143' SET @Description = 'Fixed bug regarding ModelName in ETL list for AR and AP. Modify correct reference to InstanceID for spCheck_CheckSum.'
		IF @Version = '2.0.2.2146' SET @Description = 'Updated [spIU_0000_ETL_wrk_SourceTable] script to allow negative ModelID and SourceID (SourceTable_Cursor).'
		IF @Version = '2.0.2.2149' SET @Description = 'Added parameter @SequenceBM for [spIU_Journal] and modified SP calls for Step = Reload BusinessProcess and Scenario.'

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
		RAISERROR ('10 percent', 0, 10) WITH NOWAIT

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @Collation = @Collation OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT
			@InstanceID = A.InstanceID,
			@VersionID = A.VersionID,
			@ETLDatabase = A.ETLDatabase,
			@CallistoDatabase = A.DestinationDatabase,
			@FiscalYearStartMonth = A.FiscalYearStartMonth,
			@ApplicationName = A.ApplicationName
		FROM
			[Application] A
		WHERE
			A.ApplicationID = @ApplicationID AND
			A.ApplicationID <> 0 AND
			A.SelectYN <> 0

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
			 A.ApplicationID = @ApplicationID AND
			 A.SelectYN <> 0
			)
			> 0 SET @iScalaYN = 1 ELSE SET @iScalaYN = 0

		IF
			(
			SELECT
			 COUNT(S.SourceID) 
			FROM
			 [Application] A
			 INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.Introduced < @Version AND M.SelectYN <> 0
			 INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			 INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0 AND ST.SourceTypeFamilyID = 1 --Epicor ERP
			WHERE
			 A.ApplicationID = @ApplicationID AND
			 A.SelectYN <> 0
			)
			> 0 SET @EpicorErpYN = 1 ELSE SET @EpicorErpYN = 0

		SELECT
			@SourceDBTypeBM = SUM(SourceDBTypeBM)
		FROM
			(
			SELECT DISTINCT
				SDBT.SourceDBTypeBM
			FROM
				[Application] A
				INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
				INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
				INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
				INNER JOIN [SourceDBType] SDBT ON SDBT.SourceDBTypeID = ST.SourceDBTypeID
			WHERE
				A.ApplicationID = @ApplicationID AND
				A.SelectYN <> 0
			) sub

		IF @Debug <> 0 SELECT DataBaseBM = @DataBaseBM, iScalaYN = @iScalaYN, EpicorErpYN = @EpicorErpYN, SourceDBTypeBM = @SourceDBTypeBM

	SET @Step = 'Add DimensionTypeExtensions'
		IF @DataBaseBM & 1 > 0 --pcETL
			BEGIN
				IF (SELECT COUNT(1) FROM [CallistoAppDictionary].sys.tables st WHERE [type] = 'U' AND name = 'DimensionTypeExtension') = 0
					BEGIN
						CREATE TABLE [CallistoAppDictionary].[dbo].[DimensionTypeExtension](
						 [DimensionType] [nvarchar](50) NOT NULL,
						 [AS_DimensionType] [nvarchar](50) NOT NULL
						) ON [PRIMARY]
					END

				IF (SELECT
						COUNT(1)
					FROM 
						[CallistoAppDictionary].sys.tables t 
						INNER JOIN [CallistoAppDictionary].sys.columns c ON c.[Object_id] = t.[object_id] AND c.name = 'AS_DimensionType'
					WHERE
						t.[type] = 'U' AND t.name = 'DimensionTypeExtension') = 0

					BEGIN
						--SELECT 'Add column'

						ALTER TABLE [CallistoAppDictionary].[dbo].[DimensionTypeExtension] ADD [AS_DimensionType] [nvarchar](50) NOT NULL 
						CONSTRAINT DF_DimensionTypeExtension_AS_DimensionType DEFAULT '' 
					END

				EXEC (
					'UPDATE DTE
					SET 
						[AS_DimensionType] = ISNULL(DT.[AS_DimensionTypeName], DTE.[AS_DimensionType])
					FROM
						[CallistoAppDictionary].[dbo].[DimensionTypeExtension] DTE
						INNER JOIN [DimensionType] DT ON	DT.[DimensionTypeName] = DTE.[DimensionType] COLLATE DATABASE_DEFAULT AND 
															DT.[ExtensionYN] <> 0 AND 
															DT.[DimensionTypeID] >= 0'
					)

				EXEC (
					'INSERT INTO [CallistoAppDictionary].[dbo].[DimensionTypeExtension]
					(
					 [DimensionType],
					 [AS_DimensionType]
					) 
					SELECT DISTINCT
					 [DimensionTypeName],
					 ISNULL([AS_DimensionTypeName], '''')
					FROM
					 [DimensionType] DT
					WHERE
					 [ExtensionYN] <> 0 AND
					 [DimensionTypeID] >= 0 AND
					 NOT EXISTS (SELECT 1 FROM [CallistoAppDictionary].[dbo].[DimensionTypeExtension] E WHERE E.[DimensionType] COLLATE DATABASE_DEFAULT = DT.[DimensionTypeName])'
					)
			END

	SET @Step = 'CREATE Temp TABLE #Object'
		RAISERROR ('20 percent', 0, 20) WITH NOWAIT
		CREATE TABLE #Object
			(
			ObjectType nvarchar(100) COLLATE DATABASE_DEFAULT,
			ObjectName nvarchar(100) COLLATE DATABASE_DEFAULT,
			DatabaseName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

	  		IF @DataBaseBM & 1 > 0 --pcETL
				BEGIN
					IF DB_ID (@ETLDatabase) IS NULL
					  BEGIN
						SET @SQLStatement = 'CREATE DATABASE ' + @ETLDatabase + ' COLLATE ' + @Collation + ' ALTER DATABASE ' + @ETLDatabase + ' SET RECOVERY SIMPLE'
						EXEC (@SQLStatement)
					  END
				END

			SELECT @ETLDatabase = '[' + @ETLDatabase + ']', @CallistoDatabase = '[' + @CallistoDatabase + ']'

			TRUNCATE TABLE #Object

			IF @DataBaseBM & 1 > 0 --pcETL
				BEGIN
					SET @SQLStatement = 'SELECT ObjectType = ''Table'', ObjectName = st.name, DatabaseName = ''' + @ETLDatabase + ''' FROM ' + @ETLDatabase + '.sys.tables st'
					INSERT INTO #Object (ObjectType, ObjectName, DatabaseName) EXEC (@SQLStatement)
					SET @SQLStatement = 'SELECT ObjectType = ''Procedure'', ObjectName = sp.name, DatabaseName = ''' + @ETLDatabase + ''' FROM ' + @ETLDatabase + '.sys.procedures sp'
					INSERT INTO #Object (ObjectType, ObjectName, DatabaseName) EXEC (@SQLStatement)
					SET @SQLStatement = 'SELECT ObjectType = ''Function'', ObjectName = so.name, DatabaseName = ''' + @ETLDatabase + ''' FROM ' + @ETLDatabase + '.sys.objects so WHERE type = ''FN'''
					INSERT INTO #Object (ObjectType, ObjectName, DatabaseName) EXEC (@SQLStatement)
				END

			IF @DataBaseBM & 2 > 0 --pcDATA
				BEGIN
					SET @SQLStatement = 'SELECT ObjectType = ''Table'', ObjectName = st.name, DatabaseName = ''' + @CallistoDatabase + ''' FROM ' + @CallistoDatabase + '.sys.tables st'
					INSERT INTO #Object (ObjectType, ObjectName, DatabaseName) EXEC (@SQLStatement)
					SET @SQLStatement = 'SELECT ObjectType = ''Procedure'', ObjectName = sp.name, DatabaseName = ''' + @CallistoDatabase + ''' FROM ' + @CallistoDatabase + '.sys.procedures sp'
					INSERT INTO #Object (ObjectType, ObjectName, DatabaseName) EXEC (@SQLStatement)
				END

			IF @Debug <> 0 SELECT ETLDatabase = @ETLDatabase, CallistoDatabase = @CallistoDatabase
			IF @Debug <> 0 SELECT TempTable = '#Object', * FROM #Object ORDER BY ObjectType, ObjectName

SET @Step = 'CREATE TABLES'
	RAISERROR ('30 percent', 0, 30) WITH NOWAIT
		IF @DataBaseBM & 1 > 0 --pcETL
			BEGIN
				SET @Step = 'Create table XT_UserDefinition'		
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_UserDefinition' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_UserDefinition](
									[Action] [int] NULL,
									[WinUser] [nvarchar](255) NOT NULL,
									[Active] [int] NULL,
									[Email] [nvarchar](255) NULL,
									[UserId] [int] NULL
								) ON [PRIMARY]'

								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_PropertyDefinition'					
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_PropertyDefinition' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_PropertyDefinition](
									[Action] [int] NULL,
									[Dimension] [nvarchar](100) NOT NULL,
									[Label] [nvarchar](100) NOT NULL,
									[DataType] [nvarchar](20) NOT NULL,
									[Size] [int] NULL,
									[DefaultValue] [nvarchar](255) NULL,
									[MemberDimension] [nvarchar](100) NULL,
									[MemberHierarchy] [nvarchar](100) NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_ModelDimensions'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_ModelDimensions' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_ModelDimensions](
									[Action] [int] NULL,
									[Model] [nvarchar](100) NOT NULL,
									[Dimension] [nvarchar](100) NOT NULL,
									[HideInExcel] [int] NULL,
									[SendToMemberId] [int] NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_ModelDefinition'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_ModelDefinition' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_ModelDefinition](
									[Action] [int] NULL,
									[Label] [nvarchar](100) NOT NULL,
									[Description] [nvarchar](255) NULL,
									[ModelType] [nvarchar](50) NOT NULL,
									[TextSupport] [bit] NULL,
									[ChangeInfo] [bit] NULL,
									[EnableAuditLog] [bit] NULL,
									[StartupWorkbook] [nvarchar](512) NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_BusinessRuleRequestFilters'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_BusinessRuleRequestFilters' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleRequestFilters](
								   [Action] [int] NULL,
								   [Model] [nvarchar](100) NOT NULL,
								   [BusinessRule] [nvarchar](255) NOT NULL,
								   [Label] [nvarchar](255) NOT NULL,
								   [Dimension] [nvarchar](100) NOT NULL
							) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_ModelAssumptions'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_ModelAssumptions' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_ModelAssumptions](
									[Action] [int] NULL,
									[Model] [nvarchar](100) NOT NULL,
									[AssumptionModel] [nvarchar](100) NOT NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_BusinessRule'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_BusinessRule' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_BusinessRule](
									[Action] [int] NULL,
									[Model] [nvarchar](100) NOT NULL,
									[Label] [nvarchar](255) NOT NULL,
									[Description] [nvarchar](255) NULL,
									[Type] [nvarchar](50) NOT NULL,
									[Path] [nvarchar](255) NOT NULL,
									[Text] [nvarchar](max) NOT NULL
								) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_BusinessRuleSteps'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_BusinessRuleSteps' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleSteps](
									[Model] [nvarchar](100) NOT NULL,
									[BusinessRule] [nvarchar](255) NOT NULL,
									[Label] [nvarchar](255) NOT NULL,
									[DefinitionLabel] [nvarchar](255) NOT NULL,
									[SequenceNumber] [int] NOT NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_BusinessRuleStepRecords'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_BusinessRuleStepRecords' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecords](
									[Model] [nvarchar](100) NOT NULL,
									[BusinessRule] [nvarchar](255) NOT NULL,
									[BusinessRuleStep] [nvarchar](255) NOT NULL,
									[Label] [nvarchar](255) NOT NULL,
									[SequenceNumber] [int] NOT NULL,
									[Skip] [int] NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_BusinessRuleStepRecordParameters'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_BusinessRuleStepRecordParameters' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_BusinessRuleStepRecordParameters](
									[Model] [nvarchar](100) NOT NULL,
									[BusinessRule] [nvarchar](255) NOT NULL,
									[BusinessRuleStep] [nvarchar](255) NOT NULL,
									[BusinessRuleStepRecord] [nvarchar](255) NOT NULL,
									[Parameter] [nvarchar](255) NOT NULL,
									[Value] [nvarchar](max) NULL
								) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END


				SET @Step = 'Create table XT_MemberViewDefinition'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_MemberViewDefinition' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_MemberViewDefinition](
									[Action] [int] NULL,
									[Dimension] [nvarchar](100) NOT NULL,
									[Label] [nvarchar](100) NOT NULL,
									[Property] [nvarchar](255) NOT NULL,
									[ViewLevel] [int] NOT NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_HierarchyLevels'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_HierarchyLevels' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_HierarchyLevels](
									[Action] [int] NULL,
									[Dimension] [nvarchar](100) NOT NULL,
									[Hierarchy] [nvarchar](100) NOT NULL,
									[LevelName] [nvarchar](100) NOT NULL,
									[SequenceNumber] [int] NOT NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_HierarchyDefinition'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_HierarchyDefinition' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_HierarchyDefinition](
									[Action] [int] NULL,
									[Dimension] [nvarchar](100) NOT NULL,
									[Label] [nvarchar](100) NOT NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_DimensionDefinition'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_DimensionDefinition' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_DimensionDefinition](
									[Action] [int] NULL,
									[Label] [nvarchar](100) NOT NULL,
									[Description] [nvarchar](255) NULL,
									[Type] [nvarchar](50) NOT NULL,
									[Secured] [bit] NULL,
									[DefaultHierarchy] [nvarchar](100) NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_SecurityUser'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_SecurityUser' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_SecurityUser](
									[Role] [nvarchar](100) NOT NULL,
									[WinUser] [nvarchar](255) NULL,
									[WinGroup] [nvarchar](255) NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_SecurityActionAccess'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_SecurityActionAccess' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_SecurityActionAccess](
									[Role] [nvarchar](100) NOT NULL,
									[Label] [nvarchar](100) NOT NULL,
									[HideAction] [int] NOT NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_SecurityRoleDefinition'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_SecurityRoleDefinition' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_SecurityRoleDefinition](
									[Action] [int] NULL,
									[Label] [nvarchar](100) NOT NULL,
									[Description] [nvarchar](255) NULL,
									[LicenseUserType] [nvarchar](255) NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_SecurityMemberAccess'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_SecurityMemberAccess' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_SecurityMemberAccess](
									[Role] [nvarchar](100) NOT NULL,
									[Model] [nvarchar](100) NOT NULL,
									[Dimension] [nvarchar](100) NOT NULL,
									[Hierarchy] [nvarchar](100) NULL,
									[Member] [nvarchar](255) NULL,
									[AccessType] [int] NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_SecurityModelRuleAccess'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_SecurityModelRuleAccess' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_SecurityModelRuleAccess](
									[Role] [nvarchar](100) NOT NULL,
									[Model] [nvarchar](100) NOT NULL,
									[Rule] [nvarchar](255) NOT NULL,
									[AllRules] [int] NOT NULL
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_ListDefinition'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_ListDefinition' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_ListDefinition](
									[Action] [int] NULL,
									[Label] [nvarchar](100) NOT NULL,
									[SystemDefined] [bit] NULL
								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListDefinition] ([Action], [Label], [SystemDefined]) VALUES (NULL, N''BSRuleDetail'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListDefinition] ([Action], [Label], [SystemDefined]) VALUES (NULL, N''BSRuleMethods'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListDefinition] ([Action], [Label], [SystemDefined]) VALUES (NULL, N''BSRules'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListDefinition] ([Action], [Label], [SystemDefined]) VALUES (NULL, N''BusinessRuleETL'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListDefinition] ([Action], [Label], [SystemDefined]) VALUES (NULL, N''CashFlow_Setup'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListDefinition] ([Action], [Label], [SystemDefined]) VALUES (NULL, N''CashFlowAmount'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListDefinition] ([Action], [Label], [SystemDefined]) VALUES (NULL, N''Depreciation'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListDefinition] ([Action], [Label], [SystemDefined]) VALUES (NULL, N''DepreciationMethod'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListDefinition] ([Action], [Label], [SystemDefined]) VALUES (NULL, N''KeyName'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListDefinition] ([Action], [Label], [SystemDefined]) VALUES (NULL, N''Paid'', 0)
								'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

/*
'
								SET @SQLStatement = @SQLStatement + '
*/


				SET @Step = 'Create table XT_ListFieldDefinition'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_ListFieldDefinition' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition](
									[Action] [int] NULL,
									[List] [nvarchar](100) NOT NULL,
									[Label] [nvarchar](100) NOT NULL,
									[DataType] [nvarchar](20) NOT NULL,
									[Size] [int] NULL,
									[MemberDimension] [nvarchar](100) NULL,
									[MemberHierarchy] [nvarchar](100) NULL,
									[ListName] [nvarchar](100) NULL,
									[SystemDefined] [bit] NULL

								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRuleDetail'', N''BSRule'', N''List'', 0, N'''', N'''', N''BSRules'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRuleDetail'', N''BaseAmtAcct'', N''Member'', 0, N''Account'', N''Account'', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRuleDetail'', N''BaseAmtTimeOffset'', N''Integer'', 0, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRuleDetail'', N''BasePctAcct'', N''Member'', 0, N''Account'', N''Account'', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRuleDetail'', N''BasePctTimeoffset'', N''Integer'', 0, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRuleDetail'', N''OnlyClosing'', N''TrueFalse'', 0, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRuleDetail'', N''Acct'', N''Member'', 0, N''Account'', N''Account'', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRuleDetail'', N''Sign'', N''Integer'', 0, N'''', N'''', N'''', 0)'
								SET @SQLStatement = @SQLStatement + '
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRuleDetail'', N''BSRuleMethod'', N''List'', 0, N'''', N'''', N''BSRuleMethods'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRuleDetail'', N''FixedPct'', N''DoubleNum'', 0, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRules'', N''Description'', N''Text'', 50, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRules'', N''Entity'', N''Member'', 0, N''Entity'', N''Entity'', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BSRules'', N''BusinessProcess_Destination'', N''Member'', 0, N''BusinessProcess'', N''BusinessProcess'', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''CashFlow_Setup'', N''CashFlow_Account'', N''Text'', 250, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''CashFlow_Setup'', N''Sign'', N''Text'', 50, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''CashFlow_Setup'', N''Account'', N''Member'', 0, N''Account'', N''Account'', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''CashFlow_Setup'', N''Source_Amount'', N''List'', 0, N'''', N'''', N''CashFlowAmount'', 0)'
								SET @SQLStatement = @SQLStatement + '
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''Depreciation'', N''AssetAccount'', N''Member'', 0, N''Account'', N''Account'', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''Depreciation'', N''PL_Depr_Account'', N''Member'', 0, N''Account'', N''Account'', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''Depreciation'', N''BS_Depr_Account'', N''Member'', 0, N''Account'', N''Account'', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''Depreciation'', N''Selling'', N''Member'', 0, N''Account'', N''Account'', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''Depreciation'', N''COGS'', N''Member'', 0, N''Account'', N''Account'', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''Depreciation'', N''Admin'', N''Member'', 0, N''Account'', N''Account'', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''Depreciation'', N''Copy'', N''TrueFalse'', 0, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''KeyName'', N''Section'', N''Text'', 50, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''KeyName'', N''Description'', N''Text'', 255, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''KeyName'', N''Account'', N''Member'', 0, N''Account'', N''MgmtAccts'', N'''', 0)'
								SET @SQLStatement = @SQLStatement + '
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BusinessRuleETL'', N''Database'', N''Text'', 100, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BusinessRuleETL'', N''Model'', N''Text'', 100, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BusinessRuleETL'', N''BusinessRule'', N''Text'', 50, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BusinessRuleETL'', N''Param01'', N''Text'', 50, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BusinessRuleETL'', N''Param02'', N''Text'', 50, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BusinessRuleETL'', N''Param03'', N''Text'', 50, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BusinessRuleETL'', N''Param04'', N''Text'', 50, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BusinessRuleETL'', N''Param05'', N''Text'', 50, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BusinessRuleETL'', N''SortOrder'', N''Integer'', 0, N'''', N'''', N'''', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_ListFieldDefinition] ([Action], [List], [Label], [DataType], [Size], [MemberDimension], [MemberHierarchy], [ListName], [SystemDefined]) VALUES (NULL, N''BusinessRuleETL'', N''SelectYN'', N''TrueFalse'', 0, N'''', N'''', N'''', 0)'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_LST_BSRuleDetail'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_LST_BSRuleDetail' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_LST_BSRuleDetail](
									[RecordId] [bigint] NULL,
									[Label] [nvarchar](255) NOT NULL,
									[SystemDefined] [bit] NULL,
									[BSRule_RecordId] [bigint] NULL,
									[BSRule] [nvarchar](255) NULL,
									[BaseAmtAcct_MemberId] [bigint] NULL,
									[BaseAmtAcct] [nvarchar](255) NULL,
									[BaseAmtTimeOffset] [int] NULL,
									[BasePctAcct_MemberId] [bigint] NULL,
									[BasePctAcct] [nvarchar](255) NULL,
									[BasePctTimeoffset] [int] NULL,
									[OnlyClosing] [bit] NULL,
									[Acct_MemberId] [bigint] NULL,
									[Acct] [nvarchar](255) NULL,
									[Sign] [int] NULL,
									[BSRuleMethod_RecordId] [bigint] NULL,
									[BSRuleMethod] [nvarchar](255) NULL,
									[FixedPct] [float] NULL
								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BSRuleDetail] ([RecordId], [Label], [SystemDefined], [BSRule_RecordId], [BSRule], [BaseAmtAcct_MemberId], [BaseAmtAcct], [BaseAmtTimeOffset], [BasePctAcct_MemberId], [BasePctAcct], [BasePctTimeoffset], [OnlyClosing], [Acct_MemberId], [Acct], [Sign], [BSRuleMethod_RecordId], [BSRuleMethod], [FixedPct]) VALUES (10, N''1'', 0, 25, NULL, 363, NULL, -1, 465, NULL, 0, 0, 23, NULL, 1, 2, NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BSRuleDetail] ([RecordId], [Label], [SystemDefined], [BSRule_RecordId], [BSRule], [BaseAmtAcct_MemberId], [BaseAmtAcct], [BaseAmtTimeOffset], [BasePctAcct_MemberId], [BasePctAcct], [BasePctTimeoffset], [OnlyClosing], [Acct_MemberId], [Acct], [Sign], [BSRuleMethod_RecordId], [BSRuleMethod], [FixedPct]) VALUES (11, N''2'', 0, 25, NULL, 363, NULL, -2, 465, NULL, 0, 0, 23, NULL, 1, 3, NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BSRuleDetail] ([RecordId], [Label], [SystemDefined], [BSRule_RecordId], [BSRule], [BaseAmtAcct_MemberId], [BaseAmtAcct], [BaseAmtTimeOffset], [BasePctAcct_MemberId], [BasePctAcct], [BasePctTimeoffset], [OnlyClosing], [Acct_MemberId], [Acct], [Sign], [BSRuleMethod_RecordId], [BSRuleMethod], [FixedPct]) VALUES (12, N''3'', 0, 27, NULL, 363, NULL, 0, 466, NULL, 0, 0, 102, NULL, -1, 2, NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BSRuleDetail] ([RecordId], [Label], [SystemDefined], [BSRule_RecordId], [BSRule], [BaseAmtAcct_MemberId], [BaseAmtAcct], [BaseAmtTimeOffset], [BasePctAcct_MemberId], [BasePctAcct], [BasePctTimeoffset], [OnlyClosing], [Acct_MemberId], [Acct], [Sign], [BSRuleMethod_RecordId], [BSRuleMethod], [FixedPct]) VALUES (13, N''4'', 0, 27, NULL, 363, NULL, -1, 466, NULL, 0, 0, 102, NULL, -1, 3, NULL, 0)
								'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_LST_BSRuleMethods'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_LST_BSRuleMethods' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_LST_BSRuleMethods](
									[RecordId] [bigint] NULL,
									[Label] [nvarchar](255) NOT NULL,
									[SystemDefined] [bit] NULL
								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BSRuleMethods] ([RecordId], [Label], [SystemDefined]) VALUES (1, N''FixedPct'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BSRuleMethods] ([RecordId], [Label], [SystemDefined]) VALUES (2, N''BasePct'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BSRuleMethods] ([RecordId], [Label], [SystemDefined]) VALUES (3, N''(1-BasePct)'', 0)
								'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_LST_BSRules'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_LST_BSRules' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_LST_BSRules](
									[RecordId] [bigint] NULL,
									[Label] [nvarchar](255) NOT NULL,
									[SystemDefined] [bit] NULL,
									[Description] [nvarchar](50) NULL,
									[Entity_MemberId] [bigint] NULL,
									[Entity] [nvarchar](255) NULL,
									[BusinessProcess_Destination_MemberId] [bigint] NULL,
									[BusinessProcess_Destination] [nvarchar](255) NULL
								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BSRules] ([RecordId], [Label], [SystemDefined], [Description], [Entity_MemberId], [Entity], [BusinessProcess_Destination_MemberId], [BusinessProcess_Destination]) VALUES (25, N''TradeRec'', 0, N''Trade Receivable'', 0, NULL, 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BSRules] ([RecordId], [Label], [SystemDefined], [Description], [Entity_MemberId], [Entity], [BusinessProcess_Destination_MemberId], [BusinessProcess_Destination]) VALUES (27, N''TradePay'', 0, N''Trade Payables'', 0, NULL, 0, NULL)
								'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_LST_CashFlow_Setup'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_LST_CashFlow_Setup' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup](
									[RecordId] [bigint] NULL,
									[Label] [nvarchar](255) NOT NULL,
									[SystemDefined] [bit] NULL,
									[CashFlow_Account_MemberId] [bigint] NULL,
									[CashFlow_Account] [nvarchar](255) NULL,
									[Sign] [nvarchar](50) NULL,
									[Account_MemberId] [bigint] NULL,
									[Account] [nvarchar](255) NULL,
									[Source_Amount_RecordId] [bigint] NULL,
									[Source_Amount] [nvarchar](255) NULL

								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (1, N''CFD-010'', 0, 139, N''CFD_Net_Sales'', N''-1'', 5, N''TotRev'', 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (2, N''CFD-020'', 0, 140, N''CFD_Beginning_Accounts_Receivable'', N''-1'', 41, N''1100'', 4, N''Opening_Year'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (3, N''CFD-030'', 0, 141, N''CFD_Ending_Accounts_Receivable'', N''1'', 41, N''1100'', 1, N''Amount'')
								'
																SET @SQLStatement = @SQLStatement + '
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (4, N''CFD-040'', 0, 143, N''CFD_Purchases'', N''1'', 8, N''CostofGoods'', 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (5, N''CFD-050'', 0, 144, N''CFD_Ending_Inventory'', N''1'', 43, N''1200'', 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (6, N''CFD-060'', 0, 145, N''CFD_Beginning_Inventory'', N''-1'', 43, N''1200'', 4, N''Opening_Year'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (7, N''CFD-070'', 0, 146, N''CFD_Beginning_Accounts_Payable'', N''-1'', 50, N''2010'', 4, N''Opening_Year'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (8, N''CFD-080'', 0, 147, N''CFD_Ending_Accounts_Payable'', N''1'', 50, N''2010'', 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (9, N''CFD-090'', 0, 149, N''CFD_Beginning_Salaries_Payable'', N''-1'', 53, N''2440'', 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (10, N''CFD-100'', 0, 150, N''CFD_Ending_Salaries_Payable'', N''1'', 53, N''2440'', 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (11, N''CFD-110'', 0, 151, N''CFD_Salaries_Expense'', N''1'', 16, N''TotalPersonnelExp'', 1, N''Amount'')
								'
																SET @SQLStatement = @SQLStatement + '
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (12, N''CFD-120'', 0, 153, N''CFD_Ending_Prepaid_Rent_Prepaid_Insurance_etc'', N''1'', 0, NULL, 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (13, N''CFD-130'', 0, 155, N''CFD_Beginning_Prepaid_Rent_Prepaid_Insurance_etc'', N''-1'', 0, NULL, 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (14, N''CFD-140'', 0, 154, N''CFD_Expired_Rent_Expired_Insurance_etc'', N''1'', 0, NULL, 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (15, N''CFD-150'', 0, 157, N''CFD_Beginning_Interest_Payable'', N''1'', 0, NULL, 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (16, N''CFD-160'', 0, 158, N''CFD_Ending_Interest_Payable'', N''1'', 0, NULL, 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (17, N''CFD-170'', 0, 159, N''CFD_Interest_Expense'', N''1'', 0, NULL, 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (18, N''CFD-180'', 0, 161, N''CFD_Beginning_Income_Tax_Payable'', N''1'', 36, N''6600'', 4, N''Opening_Year'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (19, N''CFD-190'', 0, 162, N''CFD_Ending_Income_Tax_Payable'', N''1'', 36, N''6600'', 1, N''Amount'')
								'
																SET @SQLStatement = @SQLStatement + '
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (20, N''CFD-200'', 0, 163, N''CFD_Income_Tax_Expense'', N''1'', 36, N''6600'', 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (21, N''CFI-010'', 0, 121, N''CFI_Operating_Income_(EBIT)'', N''1'', 3, N''OperatingIncome'', 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (22, N''CFI-020'', 0, 122, N''CFI_Depreciation_Expense'', N''1'', 29, N''NonDeptExp'', 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (23, N''CFI-030'', 0, 123, N''CFI_Loss_on_Sales'', N''1'', 0, NULL, 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (24, N''CFI-040'', 0, 124, N''CFI_Gain_on_Sales'', N''1'', 0, NULL, 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (25, N''CFI-050'', 0, 125, N''CFI_Account_Receivable'', N''1'', 0, NULL, 2, N''Movement'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (26, N''CFI-060'', 0, 126, N''CFI_Prepaid_Expence'', N''1'', 0, NULL, 1, N''Amount'')
								'
																SET @SQLStatement = @SQLStatement + '
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (27, N''CFI-070'', 0, 127, N''CFI_Accounts_Payable'', N''1'', 0, NULL, 2, N''Movement'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (28, N''CFI-080'', 0, 128, N''CFI_Accrued_Expenses'', N''1'', 0, NULL, 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (29, N''CFI-090'', 0, 130, N''CFI_Sale'', N''-1'', 0, NULL, 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (30, N''CFI-100'', 0, 131, N''CFI_Purchase'', N''1'', 0, NULL, 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (31, N''CFI-110'', 0, 133, N''CFI_Payment_of_Dividends'', N''1'', 0, NULL, 1, N''Amount'')
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (32, N''CFI-120'', 0, 134, N''CFI_Payment_of_Bond_Payable'', N''1'', 0, NULL, 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlow_Setup] ([RecordId], [Label], [SystemDefined], [CashFlow_Account_MemberId], [CashFlow_Account], [Sign], [Account_MemberId], [Account], [Source_Amount_RecordId], [Source_Amount]) VALUES (33, N''CFI-130'', 0, 136, N''CFI_Cash_and_cash_equivalents_at_beginning_of_period'', N''1'', 0, NULL, 4, N''Opening_Year'')
								'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_LST_CashFlowAmount'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_LST_CashFlowAmount' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlowAmount](
									[RecordId] [bigint] NULL,
									[Label] [nvarchar](255) NOT NULL,
									[SystemDefined] [bit] NULL
								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlowAmount] ([RecordId], [Label], [SystemDefined]) VALUES (1, N''Amount'', 1)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlowAmount] ([RecordId], [Label], [SystemDefined]) VALUES (2, N''Movement'', 1)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlowAmount] ([RecordId], [Label], [SystemDefined]) VALUES (3, N''Previous_Period'', 1)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_CashFlowAmount] ([RecordId], [Label], [SystemDefined]) VALUES (4, N''Opening_Year'', 1)
								'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_LST_Depreciation'
					RAISERROR ('40 percent', 0, 40) WITH NOWAIT
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_LST_Depreciation' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_LST_Depreciation](
										[RecordId] [bigint] NULL,
										[Label] [nvarchar](255) NOT NULL,
										[SystemDefined] [bit] NULL,
										[AssetAccount_MemberId] [bigint] NULL,
										[AssetAccount] [nvarchar](255) NULL,
										[PL_Depr_Account_MemberId] [bigint] NULL,
										[PL_Depr_Account] [nvarchar](255) NULL,
										[BS_Depr_Account_MemberId] [bigint] NULL,
										[BS_Depr_Account] [nvarchar](255) NULL,
										[Selling_MemberId] [bigint] NULL,
										[Selling] [nvarchar](255) NULL,
										[COGS_MemberId] [bigint] NULL,
										[COGS] [nvarchar](255) NULL,
										[Admin_MemberId] [bigint] NULL,
										[Admin] [nvarchar](255) NULL,
										[Copy] [bit] NULL
								) ON [PRIMARY]
								
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_Depreciation] ([RecordId], [Label], [SystemDefined], [AssetAccount_MemberId], [AssetAccount], [PL_Depr_Account_MemberId], [PL_Depr_Account], [BS_Depr_Account_MemberId], [BS_Depr_Account], [Selling_MemberId], [Selling], [COGS_MemberId], [COGS], [Admin_MemberId], [Admin], [Copy]) VALUES (1, N''Building'', 0, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_Depreciation] ([RecordId], [Label], [SystemDefined], [AssetAccount_MemberId], [AssetAccount], [PL_Depr_Account_MemberId], [PL_Depr_Account], [BS_Depr_Account_MemberId], [BS_Depr_Account], [Selling_MemberId], [Selling], [COGS_MemberId], [COGS], [Admin_MemberId], [Admin], [Copy]) VALUES (2, N''Computer'', 0, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_Depreciation] ([RecordId], [Label], [SystemDefined], [AssetAccount_MemberId], [AssetAccount], [PL_Depr_Account_MemberId], [PL_Depr_Account], [BS_Depr_Account_MemberId], [BS_Depr_Account], [Selling_MemberId], [Selling], [COGS_MemberId], [COGS], [Admin_MemberId], [Admin], [Copy]) VALUES (3, N''Furniture_And_Fixtures'', 0, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_Depreciation] ([RecordId], [Label], [SystemDefined], [AssetAccount_MemberId], [AssetAccount], [PL_Depr_Account_MemberId], [PL_Depr_Account], [BS_Depr_Account_MemberId], [BS_Depr_Account], [Selling_MemberId], [Selling], [COGS_MemberId], [COGS], [Admin_MemberId], [Admin], [Copy]) VALUES (4, N''Machinery and Equipment'', 0, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_Depreciation] ([RecordId], [Label], [SystemDefined], [AssetAccount_MemberId], [AssetAccount], [PL_Depr_Account_MemberId], [PL_Depr_Account], [BS_Depr_Account_MemberId], [BS_Depr_Account], [Selling_MemberId], [Selling], [COGS_MemberId], [COGS], [Admin_MemberId], [Admin], [Copy]) VALUES (5, N''Vehicles'', 0, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_Depreciation] ([RecordId], [Label], [SystemDefined], [AssetAccount_MemberId], [AssetAccount], [PL_Depr_Account_MemberId], [PL_Depr_Account], [BS_Depr_Account_MemberId], [BS_Depr_Account], [Selling_MemberId], [Selling], [COGS_MemberId], [COGS], [Admin_MemberId], [Admin], [Copy]) VALUES (6, N''Software'', 0, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_Depreciation] ([RecordId], [Label], [SystemDefined], [AssetAccount_MemberId], [AssetAccount], [PL_Depr_Account_MemberId], [PL_Depr_Account], [BS_Depr_Account_MemberId], [BS_Depr_Account], [Selling_MemberId], [Selling], [COGS_MemberId], [COGS], [Admin_MemberId], [Admin], [Copy]) VALUES (7, N''Other Assets'', 0, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0)
								'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_LST_DepreciationMethod'
					RAISERROR ('40 percent', 0, 40) WITH NOWAIT
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_LST_DepreciationMethod' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_LST_DepreciationMethod](
									[RecordId] [bigint] NULL,
									[Label] [nvarchar](255) NOT NULL,
									[SystemDefined] [bit] NULL
								) ON [PRIMARY]
								
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_DepreciationMethod] ([RecordId], [Label], [SystemDefined]) VALUES (1, N''STRAIGHT_LINE'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_DepreciationMethod] ([RecordId], [Label], [SystemDefined]) VALUES (2, N''DIMINISHING_VALUE'', 0)'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END


				SET @Step = 'Create table XT_LST_KeyName'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_LST_KeyName' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName](
									[RecordId] [bigint] NULL,
									[Label] [nvarchar](255) NOT NULL,
									[SystemDefined] [bit] NULL,
									[Section] [nvarchar](50) NULL,
									[Description] [nvarchar](255) NULL,
									[Account_MemberId] [bigint] NULL,
									[Account] [nvarchar](255) NULL
								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (11, N''IS_NetIncome'', 0, N''Income Statement'', N''Net Income'', 5001, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (12, N''IS_OperatingCost'', 0, N''Income Statement'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (13, N''IS_TotalRevenue'', 0, N''Income Statement'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (14, N''IS_PersonnelCost'', 0, N''Income Statement'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (15, N''IS_COGS'', 0, N''Income Statement'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (16, N''IS_FinancialCost'', 0, N''Income Statement'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (17, N''IS_DepartmentalExpenses'', 0, N''Income Statement'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (18, N''IS_NonDepartmentalExpenses'', 0, N''Income Statement'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (19, N''IS_OtherOperatingCost'', 0, N''Income Statement'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (20, N''IS_FixedAssetsDepreciation'', 0, N''Income Statement'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (21, N''IS_GrossMargin'', 0, N''Income Statement'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (22, N''BS_TotalAssets'', 0, N''BalanceSheet'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (23, N''BS_TotalLiabEquity'', 0, N''BalanceSheet'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (24, N''ST_Stats'', 0, N''Statistical'', N'''', 0, NULL)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_KeyName] ([RecordId], [Label], [SystemDefined], [Section], [Description], [Account_MemberId], [Account]) VALUES (25, N''CF_CashFlow'', 0, N''CashFlow'', N'''', 0, NULL)
								'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_LST_Paid'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_LST_Paid' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_LST_Paid](
									[RecordId] [bigint] NULL,
									[Label] [nvarchar](255) NOT NULL,
									[SystemDefined] [bit] NULL
								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_Paid] ([RecordId], [Label], [SystemDefined]) VALUES (1, N''Y'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_Paid] ([RecordId], [Label], [SystemDefined]) VALUES (2, N''N'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_Paid] ([RecordId], [Label], [SystemDefined]) VALUES (3, N''P'', 0)
								'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table XT_LST_BusinessRuleETL'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'XT_LST_BusinessRuleETL' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[XT_LST_BusinessRuleETL](
									[RecordId] [bigint] NULL,
									[Label] [nvarchar](255) NOT NULL,
									[SystemDefined] [bit] NULL,
									[Database] [nvarchar](100) NULL,
									[Model] [nvarchar](100) NULL,
									[BusinessRule] [nvarchar](50) NULL,
									[Param01] [nvarchar](50) NULL,
									[Param02] [nvarchar](50) NULL,
									[Param03] [nvarchar](50) NULL,
									[Param04] [nvarchar](50) NULL,
									[Param05] [nvarchar](50) NULL,
									[SortOrder] [int] NULL,
									[SelectYN] [bit] NULL
								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BusinessRuleETL] ([RecordId], [Label], [SystemDefined], [Database], [Model], [BusinessRule], [Param01], [Param02], [Param03], [Param04], [Param05], [SortOrder], [SelectYN]) VALUES (1, N''1'', 0, N''' + @CallistoDatabase + ''', N''Financials'', N''Canvas_Capex_BR'', N'''', N'''', N'''', N'''', N'''', 710, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BusinessRuleETL] ([RecordId], [Label], [SystemDefined], [Database], [Model], [BusinessRule], [Param01], [Param02], [Param03], [Param04], [Param05], [SortOrder], [SelectYN]) VALUES (2, N''2'', 0, N''' + @CallistoDatabase + ''', N''Financials'', N''Canvas_Capex_Calculation2'', N'''', N'''', N'''', N'''', N'''', 720, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BusinessRuleETL] ([RecordId], [Label], [SystemDefined], [Database], [Model], [BusinessRule], [Param01], [Param02], [Param03], [Param04], [Param05], [SortOrder], [SelectYN]) VALUES (3, N''3'', 0, N''' + @CallistoDatabase + ''', N''Financials'', N''Canvas_CashFlow_Calculation'', N'''', N'''', N'''', N'''', N'''', 730, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BusinessRuleETL] ([RecordId], [Label], [SystemDefined], [Database], [Model], [BusinessRule], [Param01], [Param02], [Param03], [Param04], [Param05], [SortOrder], [SelectYN]) VALUES (4, N''4'', 0, N''' + @ETLDatabase + ''', N''Financials'', N''spIU_0000_FACT_FxTrans'', N''@ModelName = ''''Financials'''''', N''@BPType = ''''ETL'''''', N'''', N'''', N'''', 740, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BusinessRuleETL] ([RecordId], [Label], [SystemDefined], [Database], [Model], [BusinessRule], [Param01], [Param02], [Param03], [Param04], [Param05], [SortOrder], [SelectYN]) VALUES (5, N''5'', 0, N''' + @CallistoDatabase + ''', N''Financials'', N''Canvas_ICEliminations'', N'''', N'''', N'''', N'''', N'''', 750, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BusinessRuleETL] ([RecordId], [Label], [SystemDefined], [Database], [Model], [BusinessRule], [Param01], [Param02], [Param03], [Param04], [Param05], [SortOrder], [SelectYN]) VALUES (6, N''6'', 0, N''' + @CallistoDatabase + ''', N''Financials'', N''Canvas_ICEliminationsOther'', N'''', N'''', N'''', N'''', N'''', 760, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BusinessRuleETL] ([RecordId], [Label], [SystemDefined], [Database], [Model], [BusinessRule], [Param01], [Param02], [Param03], [Param04], [Param05], [SortOrder], [SelectYN]) VALUES (7, N''7'', 0, N''' + @ETLDatabase + ''', N''Sales'', N''spIU_0000_FACT_FxTrans'', N''@ModelName = ''''Sales'''''', N''@BPType = ''''ETL'''''', N'''', N'''', N'''', 410, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BusinessRuleETL] ([RecordId], [Label], [SystemDefined], [Database], [Model], [BusinessRule], [Param01], [Param02], [Param03], [Param04], [Param05], [SortOrder], [SelectYN]) VALUES (8, N''8'', 0, N''' + @ETLDatabase + ''', N''AccountReceivable'', N''spIU_0000_FACT_FxTrans'', N''@ModelName = ''''AccountReceivable'''''', N''@BPType = ''''ETL'''''', N'''', N'''', N'''', 1010, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[XT_LST_BusinessRuleETL] ([RecordId], [Label], [SystemDefined], [Database], [Model], [BusinessRule], [Param01], [Param02], [Param03], [Param04], [Param05], [SortOrder], [SelectYN]) VALUES (9, N''9'', 0, N''' + @ETLDatabase + ''', N''AccountPayable'', N''spIU_0000_FACT_FxTrans'', N''@ModelName = ''''AccountPayable'''''', N''@BPType = ''''ETL'''''', N'''', N'''', N'''', 1110, 1)
								'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END


				SET @Step = 'Create table Entity'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'Entity' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								IF @Debug <> 0 SELECT ETLDatabase = @ETLDatabase, CallistoDatabase = @CallistoDatabase

								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[Entity](
									[SourceID] [int] NOT NULL,
									[EntityCode] [nvarchar](50) NOT NULL,
									[Entity] [nvarchar](50) NOT NULL,
									[EntityName] [nvarchar](255) NOT NULL,
									[Currency] [nchar](3) NULL,  --Change to NOT NULL
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
								 CONSTRAINT [PK_Entity] PRIMARY KEY CLUSTERED 
								(
									[SourceID] ASC,
									[EntityCode] ASC
								)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
								) ON [PRIMARY]

								ALTER TABLE ' + @ETLDatabase + '.[dbo].[Entity] ADD  CONSTRAINT [DF_Entity_Entity]  DEFAULT (''N/A'') FOR [Entity]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[Entity] ADD  CONSTRAINT [DF_Entity_SelectYN]  DEFAULT ((1)) FOR [SelectYN]'
	
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)	
								
								SET @SQLStatement = 'CREATE TRIGGER [dbo].[Entity_Upd]
	ON [dbo].[Entity]

	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

	AFTER INSERT, UPDATE 
	
	AS 

	UPDATE E
	SET
		Entity = CASE WHEN E.SelectYN = 0 THEN ''''N/A'''' ELSE E.Par01 + CASE WHEN ST.SourceTypeFamilyID = 1 AND E.Par08 = ''''0'''' AND M.BaseModelID IN (-1, -7, -8, -9) THEN ''''_'''' + E.Par02 ELSE '''''''' END END
	FROM
		Entity E
		INNER JOIN [pcINTEGRATOR].[dbo].[Source] S ON S.SourceID = E.SourceID
		INNER JOIN [pcINTEGRATOR].[dbo].[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
		INNER JOIN [pcINTEGRATOR].[dbo].[Model] M ON M.ModelID = S.ModelID'

								SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

								IF @Debug <> 0
									BEGIN
										PRINT @SQLStatement 
										INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
									END
						
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table BudgetSelection'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'BudgetSelection' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[BudgetSelection](
									[SourceID] int NOT NULL,
									[EntityCode] [nvarchar](50) NOT NULL,
									[BudgetCode] [nvarchar](50) NOT NULL,
									[Scenario] [nvarchar](100) NOT NULL,
									[SelectYN] [bit] NOT NULL,
								 CONSTRAINT [PK_BudgetSelection] PRIMARY KEY CLUSTERED 
								(
									[SourceID] ASC,
									[EntityCode] ASC,
									[BudgetCode] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)

								SET @SQLStatement = 'CREATE TRIGGER [dbo].[BudgetSelection_Upd]
	ON [dbo].[BudgetSelection]

	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

	AFTER INSERT, UPDATE 
	
	AS 

	IF (SELECT COUNT(1) FROM sys.tables WHERE name = ''''TransactionType_iScala'''') > 0

		UPDATE TTi
			SET SelectYN = sub.SelectYN
		FROM
			(SELECT BudgetCode, SelectYN = MAX(CONVERT(int, SelectYN)) FROM BudgetSelection GROUP BY BudgetCode) sub
			INNER JOIN TransactionType_iScala TTi ON TTi.Scenario = sub.BudgetCode'

								SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

								IF @Debug <> 0
									BEGIN
										PRINT @SQLStatement 
										INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
									END
						
								EXEC (@SQLStatement)

							END

				SET @Step = 'Create table ClosedPeriod'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'ClosedPeriod' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[ClosedPeriod](
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
								 CONSTRAINT [PK_ClosedPeriod] PRIMARY KEY CLUSTERED 
								(
									[SourceID] ASC,
									[EntityCode] ASC,
									[TimeFiscalYear] ASC,
									[TimeFiscalPeriod] ASC
								)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
								) ON [PRIMARY]
				
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[ClosedPeriod] ADD  CONSTRAINT [DF_ClosedPeriod_ClosedPeriod]  DEFAULT ((0)) FOR [ClosedPeriod]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[ClosedPeriod] ADD  CONSTRAINT [DF_ClosedPeriod_ClosedPeriod_Counter]  DEFAULT ((0)) FOR [ClosedPeriod_Counter]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[ClosedPeriod] ADD  CONSTRAINT [DF_ClosedPeriod_UpdateYN]  DEFAULT ((1)) FOR [UpdateYN]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[ClosedPeriod] ADD  CONSTRAINT [DF_ClosedPeriod_Updated]  DEFAULT (getdate()) FOR [Updated]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[ClosedPeriod] ADD  CONSTRAINT [DF_ClosedPeriod_UpdatedBy]  DEFAULT (suser_name()) FOR [UpdatedBy]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table FiscalPeriod_BusinessProcess'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'FiscalPeriod_BusinessProcess' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[FiscalPeriod_BusinessProcess](
									[TimeFiscalPeriod] [int] NOT NULL,
									[TimeMonth] [int] NOT NULL,
									[BusinessProcess] [nvarchar](50) NULL,
								 CONSTRAINT [PK_FiscalPeriod_BusinessProcess] PRIMARY KEY CLUSTERED 
								(
									[TimeFiscalPeriod] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]
				
								INSERT INTO ' + @ETLDatabase + '.[dbo].[FiscalPeriod_BusinessProcess]
									(
									TimeFiscalPeriod,
									TimeMonth,
									BusinessProcess
									)
								SELECT
									TimeFiscalPeriod,
									TimeMonth,
									BusinessProcess
								FROM
									(
									SELECT       
										TimeFiscalPeriod = 0,
										TimeMonth = ' + CONVERT(nvarchar, @FiscalYearStartMonth) + ',
										BusinessProcess = ''FP0''
									UNION SELECT       
										TimeFiscalPeriod = 13,
										TimeMonth = CASE WHEN ' + CONVERT(nvarchar, @FiscalYearStartMonth) + ' = 1 THEN 12 ELSE ' + CONVERT(nvarchar, @FiscalYearStartMonth) + ' - 1 END,
										BusinessProcess = ''FP13''
									UNION SELECT       
										TimeFiscalPeriod = 14,
										TimeMonth = CASE WHEN ' + CONVERT(nvarchar, @FiscalYearStartMonth) + ' = 1 THEN 12 ELSE ' + CONVERT(nvarchar, @FiscalYearStartMonth) + ' - 1 END,
										BusinessProcess = ''FP14''
									UNION SELECT       
										TimeFiscalPeriod = 15,
										TimeMonth = CASE WHEN ' + CONVERT(nvarchar, @FiscalYearStartMonth) + ' = 1 THEN 12 ELSE ' + CONVERT(nvarchar, @FiscalYearStartMonth) + ' - 1 END,
										BusinessProcess = ''FP15''
									) sub'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table AccountType_Translate'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'AccountType_Translate' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[AccountType_Translate](
									[SourceTypeName] [nvarchar](50) NOT NULL,
									[CategoryID] [nvarchar](50) NOT NULL,
									[Description] [nvarchar](255) NULL,
									[Hint] [nvarchar](50) NULL,
									[AccountType] [nvarchar](50) NULL
								 CONSTRAINT [PK_AccountType_Translate] PRIMARY KEY CLUSTERED 
								(
									[SourceTypeName] ASC,
									[CategoryID] ASC
								)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
								) ON [PRIMARY]'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table AccountType'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'AccountType' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[AccountType](
									[AccountType] [nvarchar](50) NOT NULL,
									[Sign] [int] NULL,
									[TimeBalance] [bit] NULL,
									[Rate] [nvarchar](255) NULL,
									[Source] [nvarchar](50) NULL,
								 CONSTRAINT [PK_AccountType] PRIMARY KEY CLUSTERED 
								(
									[AccountType] ASC
								)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
								) ON [PRIMARY]
				
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[AccountType] ADD  CONSTRAINT [DF_AccountType_Sign]  DEFAULT ((-1)) FOR [Sign]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[AccountType] ADD  CONSTRAINT [DF_AccountType_TimeBalance]  DEFAULT ((0)) FOR [TimeBalance]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[AccountType] ADD  CONSTRAINT [DF_AccountType_Rate]  DEFAULT (N''Average'') FOR [Rate]
				
								INSERT ' + @ETLDatabase + '.[dbo].[AccountType] ([AccountType], [Sign], [TimeBalance], [Rate], [Source]) VALUES (N''Asset'', 1, 1, N''EOP'', N''Default'')
								INSERT ' + @ETLDatabase + '.[dbo].[AccountType] ([AccountType], [Sign], [TimeBalance], [Rate], [Source]) VALUES (N''Equity'', -1, 1, N''EOP'', N''Default'')
								INSERT ' + @ETLDatabase + '.[dbo].[AccountType] ([AccountType], [Sign], [TimeBalance], [Rate], [Source]) VALUES (N''Expense'', 1, 0, N''Average'', N''Default'')
								INSERT ' + @ETLDatabase + '.[dbo].[AccountType] ([AccountType], [Sign], [TimeBalance], [Rate], [Source]) VALUES (N''Income'', -1, 0, N''Average'', N''Default'')
								INSERT ' + @ETLDatabase + '.[dbo].[AccountType] ([AccountType], [Sign], [TimeBalance], [Rate], [Source]) VALUES (N''Liability'', -1, 1, N''EOP'', N''Default'')'
				
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table MappedObject'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'MappedObject' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[MappedObject](
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
								 CONSTRAINT [PK_MappedObject] PRIMARY KEY CLUSTERED 
								(
									[Entity] ASC,
									[ObjectName] ASC,
									[ObjectTypeBM] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]
			
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[MappedObject] ADD  CONSTRAINT [DF_MappedObject_MappingTypeID]  DEFAULT ((0)) FOR [MappingTypeID]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[MappedObject] ADD  CONSTRAINT [DF_MappedObject_ReplaceTextYN]  DEFAULT ((0)) FOR [ReplaceTextYN]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[MappedObject] ADD  CONSTRAINT [DF_MappedObject_TranslationYN]  DEFAULT ((0)) FOR [TranslationYN]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[MappedObject] ADD  CONSTRAINT [DF_MappedObject_SelectYN]  DEFAULT ((1)) FOR [SelectYN]'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)

								SET @SQLStatement = 'CREATE TRIGGER [dbo].[MappedObject_Upd]
	ON [dbo].[MappedObject]

	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

	AFTER INSERT, UPDATE 
	
	AS 

	UPDATE MO
	SET
		[MappedObjectName] = CASE WHEN I.[MappedObjectName] = ''''Account Type'''' THEN I.[MappedObjectName] ELSE [dbo].[f_ReplaceText] (I.[MappedObjectName], 1) END
	FROM
		[MappedObject] MO
		INNER JOIN Inserted I ON	
			I.Entity = MO.Entity AND
			I.ObjectName = MO.ObjectName AND
			I.ObjectTypeBM = MO.ObjectTypeBM'

								SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

								IF @Debug <> 0
									BEGIN
										PRINT @SQLStatement 
										INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
									END
						
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table TransactionType_iScala'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'TransactionType_iScala' AND DatabaseName = @ETLDatabase) = 0 AND @iScalaYN <> 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[TransactionType_iScala](
								[Group] [nvarchar](50) NULL,
								[Period] [nvarchar](2) NULL,
								[Scenario] [nvarchar](50) NULL,
								[Hex] [nchar](4) NOT NULL,
								[Symbol] [nchar](1) NULL,
								[Description] [nvarchar](100) NULL,
								[BusinessProcess] [nvarchar](50) NULL,
								[SelectYN] [bit] NOT NULL CONSTRAINT [DF_TransactionType_iScala_SelectYN]  DEFAULT ((1)),
								 CONSTRAINT [PK_TransactionType_iScala] PRIMARY KEY CLUSTERED 
								(
									[Hex] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Balances'', N''0'', N''Actual'', N''0x2F'', N''/'', N''Opening Balances'', N''FP0'', 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x30'', N''0'', N''Manual Transaction in General Ledger'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x31'', N''1'', N''Reversal Transaction in General Ledger'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x32'', N''2'', N''Accrued Transaction (Periodic Allocation)'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x33'', N''3'', N''Customer Invoice (From Sales Ledger)'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x34'', N''4'', N''Customer Payment (From Sales Ledger)'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x35'', N''5'', N''Supplier Invoice (From Purchase Ledger)'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x36'', N''6'', N''Supplier Payment (From Purchase Ledger)'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x37'', N''7'', N''Depreciation Transaction (From Asset Management)'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x38'', N''8'', N''Automatic Period Allocation'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x39'', N''9'', N''Transaction from Project Management'', NULL, 1)'

								SET @SQLStatement = @SQLStatement + '
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x41'', N''A'', N''Transaction from Payroll'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x42'', N''B'', N''Transaction from Stock  Journal'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x43'', N''C'', N''Transaction from Promissory Notes'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x44'', N''D'', N''Petty Cash Transaction'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x4B'', N''K'', N''Fixed Assets Revaluation Transaction'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x4C'', N''L'', N''Cash-Books Transaction'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x4D'', N''M'', N''Transaction from MPC WIP Journal'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transactions'', N''n'', N''Actual'', N''0x53'', N''S'', N''Transaction from Source Company (Consolidation)'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Temporary'', N''n'', N''Actual'', N''0x54'', N''T'', N''Temporary Cheques Transactions (Day-Book Journal)'', NULL, 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Budget'', N''n'', N''Budget1'', N''0x55'', N''U'', N''Budget Alternative 1'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Budget'', N''n'', N''Budget2'', N''0x56'', N''V'', N''Budget Alternative 2'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Budget'', N''n'', N''Budget3'', N''0x57'', N''W'', N''Budget Alternative 3'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Budget'', N''n'', N''Budget4'', N''0x58'', N''X'', N''Budget Alternative 4'', NULL, 0)'

								SET @SQLStatement = @SQLStatement + '
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Budget'', N''n'', N''Budget5'', N''0x59'', N''Y'', N''Budget Alternative 5'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Budget'', N''n'', N''BudgetPY'', N''0x5A'', N''Z'', N''Budget Previous Year'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Reporting'', N''0'', N''ReportingOB'', N''0x5C'', N''\'', N''Reporting Level Transaction Opening balances'', N''FP0'', 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Reporting'', N''n'', N''Reporting'', N''0x61'', N''a'', N''Reporting Level Transaction'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Reporting'', N''n'', N''Reporting1'', N''0x63'', N''c'', N''Reporting Level Transaction Budget Alternative 1'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Reporting'', N''n'', N''Reporting2'', N''0x64'', N''d'', N''Reporting Level Transaction Budget Alternative 2'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Reporting'', N''n'', N''Reporting3'', N''0x65'', N''e'', N''Reporting Level Transaction Budget Alternative 3'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Reporting'', N''n'', N''Reporting4'', N''0x66'', N''f'', N''Reporting Level Transaction Budget Alternative 4'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Reporting'', N''n'', N''Reporting5'', N''0x67'', N''g'', N''Reporting Level Transaction Budget Alternative 5'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Reporting'', N''n'', N''ReportingPY'', N''0x68'', N''h'', N''Reporting Level Transaction Budget Previous Year'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transaction Closing'', N''13'', N''Actual'', N''0x69'', N''i'', N''Closing Period Transaction'', N''FP13'', 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Reporting'', N''n'', N''ReportingCP'', N''0x6A'', N''j'', N''Reporting Level Closing Period Transaction'', NULL, 0)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Transaction Closing'', N''13'', N''Actual'', N''0x6B'', N''k'', N''Year End Closing Transaction'', N''FP13'', 1)
								INSERT ' + @ETLDatabase + '.[dbo].[TransactionType_iScala] ([Group], [Period], [Scenario], [Hex], [Symbol], [Description], [BusinessProcess], [SelectYN]) VALUES (N''Balances'', N''0'', N''Actual'', N''0x7C'', N''|'', N''Transferred Open Balances of Currency Accounts'', N''FP0'', 0)'

								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table wrk_SourceTable'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'wrk_SourceTable' AND DatabaseName = @ETLDatabase) = 0 AND @SourceDBTypeBM & 2 > 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[wrk_SourceTable](
									[SourceID] [int] NOT NULL,
									[TableCode] [nvarchar](50) NOT NULL,
									[EntityCode] [nvarchar](50) NOT NULL,
									[TableName] [nvarchar](255) NOT NULL,
									[FiscalYear] [int] NOT NULL,
									[Rows] [int] NOT NULL,
									[Inserted] [datetime] NOT NULL,
								 CONSTRAINT [PK_wrk_SourceTable] PRIMARY KEY CLUSTERED 
								(
									[SourceID] ASC,
									[TableCode] ASC,
									[EntityCode] ASC,
									[TableName] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]

								ALTER TABLE ' + @ETLDatabase + '.[dbo].[wrk_SourceTable] ADD  CONSTRAINT [DF_wrk_SourceTable_Inserted]  DEFAULT (getdate()) FOR [Inserted]'

								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table wrk_EntityPriority_SQLStatement'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'wrk_EntityPriority_SQLStatement' AND DatabaseName = @ETLDatabase) = 0 AND @SourceDBTypeBM & 1 > 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[wrk_EntityPriority_SQLStatement](
									[DimensionID] [int] NOT NULL,
									[SourceID] [int] NOT NULL,
									[SequenceBM] [int] NOT NULL,
									[SQLStatement] [nvarchar](max) NOT NULL,
									[Inserted] [datetime] NOT NULL,
								 CONSTRAINT [PK_wrk_EntityPriority_SQLStatement] PRIMARY KEY CLUSTERED 
								(
									[DimensionID] ASC,
									[SourceID] ASC,
									[SequenceBM] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

								ALTER TABLE ' + @ETLDatabase + '.[dbo].[wrk_EntityPriority_SQLStatement] ADD CONSTRAINT [DF_wrk_EntityPriority_SQLStatement_Inserted] DEFAULT (getdate()) FOR [Inserted]'

								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table wrk_EntityPriority_Member'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'wrk_EntityPriority_Member' AND DatabaseName = @ETLDatabase) = 0 AND @SourceDBTypeBM & 1 > 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[wrk_EntityPriority_Member](
									[DimensionID] [int] NOT NULL,
									[SourceID] [int] NOT NULL,
									[SequenceBM] [int] NOT NULL,
									[Label] [nvarchar](255) NOT NULL,
									[EntityPriority] [int] NOT NULL,
									[Inserted] [datetime] NOT NULL,
								 CONSTRAINT [PK_wrk_EntityPriority_Member] PRIMARY KEY CLUSTERED 
								(
									[DimensionID] ASC,
									[SourceID] ASC,
									[SequenceBM] ASC,
									[Label] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]

								ALTER TABLE ' + @ETLDatabase + '.[dbo].[wrk_EntityPriority_Member] ADD CONSTRAINT [DF_wrk_EntityPriority_Member_Inserted] DEFAULT (getdate()) FOR [Inserted]'

								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table wrk_SBZ_Check'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'wrk_SBZ_Check' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[wrk_SBZ_Check](
									[Dimension] [nvarchar](100) NOT NULL,
									[Model] [nvarchar](100) NOT NULL,
									[Label] [nvarchar](255) NOT NULL,
									[MemberId] [bigint] NOT NULL,
									[FACT_table] [nvarchar](100) NOT NULL,
									[FirstLoad] [smalldatetime] NULL,
									[LatestLoad] [smalldatetime] NULL,
									[Occurencies] [int] NOT NULL,
									[Inserted] [datetime] NOT NULL,
								 CONSTRAINT [PK_wrk_SBZ_Check] PRIMARY KEY CLUSTERED 
								(
									[Dimension] ASC,
									[Model] ASC,
									[MemberId] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]
								
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[wrk_SBZ_Check] ADD CONSTRAINT [DF_wrk_SBZ_Check_Inserted] DEFAULT (getdate()) FOR [Inserted]'

								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table Job'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'Job' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[Job](
									[JobID] [int] IDENTITY(1,1) NOT NULL,
									[StartTime] [datetime] NOT NULL,
									[CurrentCommand] [nvarchar](255) NULL,
									[CurrentCommand_StartTime] [datetime] NULL,
									[EndTime] [datetime] NULL,
								 CONSTRAINT [PK_Job] PRIMARY KEY CLUSTERED 
								(
									[JobID] DESC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]
				
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[Job] ADD  CONSTRAINT [DF_Job_StartTime]  DEFAULT (getdate()) FOR [StartTime]'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table JobLog (ETLDatabase)'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'JobLog' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[JobLog](
									[JobID] [int] NULL,
									[JobLogID] [int] IDENTITY(1,1) NOT NULL,
									[StartTime] [datetime] NOT NULL,
									[ProcedureName] [nvarchar](100) NULL,
									[Duration] [time](7) NOT NULL,
									[Deleted] [int] NOT NULL,
									[Inserted] [int] NOT NULL,
									[Updated] [int] NOT NULL,
									[Selected] [int] NOT NULL,
									[ErrorNumber] [int] NOT NULL,
									[ErrorSeverity] [int] NULL,
									[ErrorState] [int] NULL,
									[ErrorProcedure] [nvarchar](128) NULL,
									[ErrorStep] [nvarchar](255) NULL,
									[ErrorLine] [int] NULL,
									[ErrorMessage] [nvarchar](4000) NULL,
									[Version] [nvarchar](100) NULL,
									[Parameter] [nvarchar](4000) NULL,
									[UserName] [nvarchar](100) NULL,
									[UserID] [int] NULL,
									[InstanceID] [int] NULL,
									[VersionID] [int] NULL,
								 CONSTRAINT [PK_JobLog] PRIMARY KEY CLUSTERED 
								(
									[JobLogID] DESC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]
								
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[JobLog] ADD  CONSTRAINT [DF_JobLog_JobID]  DEFAULT ((0)) FOR [JobID]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[JobLog] ADD  CONSTRAINT [DF_JobLog_Deleted]  DEFAULT ((0)) FOR [Deleted]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[JobLog] ADD  CONSTRAINT [DF_JobLog_Inserted]  DEFAULT ((0)) FOR [Inserted]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[JobLog] ADD  CONSTRAINT [DF_JobLog_Updated]  DEFAULT ((0)) FOR [Updated]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[JobLog] ADD  CONSTRAINT [DF_JobLog_Selected]  DEFAULT ((0)) FOR [Selected]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[JobLog] ADD  CONSTRAINT [DF_JobLog_ErrorNumber]  DEFAULT ((0)) FOR [ErrorNumber]'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table CheckSum'
					RAISERROR ('50 percent', 0, 50) WITH NOWAIT
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'CheckSum' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[CheckSum](
									[CheckSumID] [int] IDENTITY(1,1) NOT NULL,
									[CheckSumName] [nvarchar](50) NOT NULL,
									[CheckSumDescription] [nvarchar](255) NOT NULL,
									[CheckSumQuery] [nvarchar](max) NOT NULL,
									[CheckSumReport] [nvarchar](1000) NOT NULL,
									[SortOrder] [int] NOT NULL,
									[SelectYN] [bit] NOT NULL,
								 CONSTRAINT [PK_CheckSum] PRIMARY KEY CLUSTERED 
								(
									[CheckSumID] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
								
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[CheckSum] ADD  CONSTRAINT [DF_CheckSum_SortOrder]  DEFAULT ((0)) FOR [SortOrder]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[CheckSum] ADD  CONSTRAINT [DF_CheckSum_SelectYN]  DEFAULT ((1)) FOR [SelectYN]'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table CheckSumLog'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'CheckSumLog' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[CheckSumLog](
									[CheckSumLogID] [int] IDENTITY(1,1) NOT NULL,
									[JobID] [int] NOT NULL,
									[CheckSumID] [int] NOT NULL,
									[CheckSumValue] [int] NOT NULL,
									[CheckSumReport] [nvarchar](1000) NOT NULL,
									[EndTime] [datetime] NOT NULL,
								 CONSTRAINT [PK_CheckSumLog] PRIMARY KEY CLUSTERED 
								(
									[CheckSumLogID] DESC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table Digit'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'Digit' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[Digit](
									[Number] [int] NOT NULL,
								 CONSTRAINT [PK_Digit] PRIMARY KEY CLUSTERED 
								(
									[Number] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]
				
								INSERT ' + @ETLDatabase + '.[dbo].[Digit] ([Number]) VALUES (0)
								INSERT ' + @ETLDatabase + '.[dbo].[Digit] ([Number]) VALUES (1)
								INSERT ' + @ETLDatabase + '.[dbo].[Digit] ([Number]) VALUES (2)
								INSERT ' + @ETLDatabase + '.[dbo].[Digit] ([Number]) VALUES (3)
								INSERT ' + @ETLDatabase + '.[dbo].[Digit] ([Number]) VALUES (4)
								INSERT ' + @ETLDatabase + '.[dbo].[Digit] ([Number]) VALUES (5)
								INSERT ' + @ETLDatabase + '.[dbo].[Digit] ([Number]) VALUES (6)
								INSERT ' + @ETLDatabase + '.[dbo].[Digit] ([Number]) VALUES (7)
								INSERT ' + @ETLDatabase + '.[dbo].[Digit] ([Number]) VALUES (8)
								INSERT ' + @ETLDatabase + '.[dbo].[Digit] ([Number]) VALUES (9)'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table MappedLabel'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'MappedLabel' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[MappedLabel](
									[MappedObjectName] [nvarchar](100) NOT NULL,
									[Entity] [nvarchar](50) NOT NULL,
									[LabelFrom] [nvarchar](255) NOT NULL,
									[LabelTo] [nvarchar](255) NOT NULL,
									[MappingTypeID] [int] NOT NULL,
									[MappedLabel] [nvarchar](255) NULL,
									[MappedDescription] [nvarchar](255) NULL,
									[SelectYN] [bit] NOT NULL,
								 CONSTRAINT [PK_AccountMapping] PRIMARY KEY CLUSTERED 
								(
									[MappedObjectName] ASC,
									[Entity] ASC,
									[LabelFrom] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]
				
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[MappedLabel] ADD  CONSTRAINT [DF_MappedLabel_SelectYN]  DEFAULT ((1)) FOR [SelectYN]
								ALTER TABLE ' + @ETLDatabase + '.[dbo].[MappedLabel] ADD  CONSTRAINT [DF_MappedLabel_MappingTypeID]  DEFAULT ((2)) FOR [MappingTypeID]
				
								EXEC ' + @ETLDatabase + '.sys.sp_addextendedproperty @name=N''MS_Description'', @value=N''1 = Label PreFixed with Entity, 2 = Label Suffixed with Entity, 3 = Map to MappedLabel'' , @level0type=N''SCHEMA'',@level0name=N''dbo'', @level1type=N''TABLE'',@level1name=N''MappedLabel'', @level2type=N''COLUMN'',@level2name=N''MappingTypeID'''
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table MappingType'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'MappingType' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[MappingType](
									[MappingTypeID] [int] NOT NULL,
									[MappingTypeName] [nvarchar](50) NOT NULL,
									[MappingTypeDescription] [nvarchar](255) NOT NULL,
									[MappingLevelBM] [int] NOT NULL,
								 CONSTRAINT [PK_MappingType] PRIMARY KEY CLUSTERED 
								(
									[MappingTypeID] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]

								ALTER TABLE ' + @ETLDatabase + '.[dbo].[MappingType] ADD  CONSTRAINT [DF_MappingLevelBM]  DEFAULT ((1)) FOR [MappingLevelBM]

								EXEC ' + @ETLDatabase + '.sys.sp_addextendedproperty @name=N''MS_Description'', @value=N''1 = Object level, 2 = Row level'' , @level0type=N''SCHEMA'',@level0name=N''dbo'', @level1type=N''TABLE'',@level1name=N''MappingType'', @level2type=N''COLUMN'',@level2name=N''MappingLevelBM''
								
								INSERT ' + @ETLDatabase + '.[dbo].[MappingType] ([MappingTypeID], [MappingTypeName], [MappingTypeDescription], [MappingLevelBM]) VALUES (0, N''Default'', N''Label from Source'', 1)
								INSERT ' + @ETLDatabase + '.[dbo].[MappingType] ([MappingTypeID], [MappingTypeName], [MappingTypeDescription], [MappingLevelBM]) VALUES (1, N''Prefix'', N''Label PreFixed with EntityCode'', 3)
								INSERT ' + @ETLDatabase + '.[dbo].[MappingType] ([MappingTypeID], [MappingTypeName], [MappingTypeDescription], [MappingLevelBM]) VALUES (2, N''Suffix'', N''Label Suffixed with EntityCode'', 3)
								INSERT ' + @ETLDatabase + '.[dbo].[MappingType] ([MappingTypeID], [MappingTypeName], [MappingTypeDescription], [MappingLevelBM]) VALUES (3, N''Mapped'', N''Map to MappedLabel'', 2)'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table wrk_Dimension'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'wrk_Dimension' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[wrk_Dimension](
									[MemberId] [bigint] NULL,
									[Label] [nvarchar](255) NOT NULL,
									[Description] [nvarchar](512) NULL,
									[HelpText] [nvarchar](1024) NULL,
									[RNodeType] [nvarchar](2) NULL,
									[Parent] [nvarchar](255) NULL,
								 CONSTRAINT [PK_wrk_Dimension] PRIMARY KEY CLUSTERED 
								(
									[Label] ASC
								)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
								) ON [PRIMARY]'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table wrk_Debug'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'wrk_Debug' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[wrk_Debug](
									[DebugID] [int] IDENTITY(1,1) NOT NULL,
									[ProcedureName] [nvarchar](100) NULL,
									[Comment] [nvarchar](255) NULL,
									[SQLStatement] [nvarchar](max) NULL,
									[Inserted] [datetime] NOT NULL,
								 CONSTRAINT [PK_wrk_Debug] PRIMARY KEY CLUSTERED 
								(
									[DebugID] DESC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

								ALTER TABLE ' + @ETLDatabase + '.[dbo].[wrk_Debug] ADD  CONSTRAINT [DF_wrk_Debug_Inserted]  DEFAULT (getdate()) FOR [Inserted]'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table LoadType'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'LoadType' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[LoadType](
									[LoadTypeBM] [int] NOT NULL,
									[LoadTypeDescription] [nvarchar](100) NULL,
								 CONSTRAINT [PK_LoadType] PRIMARY KEY CLUSTERED 
								(
									[LoadTypeBM] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[LoadType] ([LoadTypeBM], [LoadTypeDescription]) VALUES (1, N''ETL tables'')
								INSERT ' + @ETLDatabase + '.[dbo].[LoadType] ([LoadTypeBM], [LoadTypeDescription]) VALUES (2, N''Dimension tables'')
								INSERT ' + @ETLDatabase + '.[dbo].[LoadType] ([LoadTypeBM], [LoadTypeDescription]) VALUES (4, N''Fact tables'')
								INSERT ' + @ETLDatabase + '.[dbo].[LoadType] ([LoadTypeBM], [LoadTypeDescription]) VALUES (8, N''Business rules'')
								INSERT ' + @ETLDatabase + '.[dbo].[LoadType] ([LoadTypeBM], [LoadTypeDescription]) VALUES (16, N''Check sums'')'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table Frequency'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'Frequency' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[Frequency](
									[FrequencyBM] [int] NOT NULL,
									[FrequencyDescription] [nvarchar](100) NULL,
									CONSTRAINT [PK_Frequency] PRIMARY KEY CLUSTERED 
								(
									[FrequencyBM] ASC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]

								INSERT ' + @ETLDatabase + '.[dbo].[Frequency] ([FrequencyBM], [FrequencyDescription]) VALUES (1, N''Single load'')
								INSERT ' + @ETLDatabase + '.[dbo].[Frequency] ([FrequencyBM], [FrequencyDescription]) VALUES (2, N''Regular (included in every regular load)'')'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table Load'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'Load' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[Load](
					[LoadID] [int] IDENTITY(1,1) NOT NULL,
					[LoadTypeBM] [int] NOT NULL,
					[DatabaseName] [nvarchar](100) NULL,
					[Command] [nvarchar](100) NOT NULL,
					[SortOrder] [int] NOT NULL,
					[FrequencyBM] [int] NOT NULL,
					[SelectYN] [bit] NOT NULL,
				 CONSTRAINT [PK_Load] PRIMARY KEY CLUSTERED 
				(
					[LoadID] ASC
				)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
				) ON [PRIMARY]

				ALTER TABLE ' + @ETLDatabase + '.[dbo].[Load] ADD  CONSTRAINT [DF_Load_SortOrder]  DEFAULT ((0)) FOR [SortOrder]
				ALTER TABLE ' + @ETLDatabase + '.[dbo].[Load] ADD  CONSTRAINT [DF_Load_RegularYN]  DEFAULT ((2)) FOR [FrequencyBM]
				ALTER TABLE ' + @ETLDatabase + '.[dbo].[Load] ADD  CONSTRAINT [DF_Load_SelectYN]  DEFAULT ((1)) FOR [SelectYN]'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table ReplaceText'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'ReplaceText' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[ReplaceText](
					[Input] [int] NOT NULL,
					[StringTypeBM] [int] NOT NULL,
					[Output] [nvarchar](50) NOT NULL,
					[Comment] [nvarchar](100) NULL,
					[ScanYN] [bit] NOT NULL,
					[ReplaceYN] [bit] NOT NULL,
				 CONSTRAINT [PK_Replace_1] PRIMARY KEY CLUSTERED 
				(
					[Input] ASC,
					[StringTypeBM] ASC
				)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
				) ON [PRIMARY]
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (0, 3, N'''''''''''', N''Char(0) NULL --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (1, 3, N'''''''''''', N''Char(1) Start of heading --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (2, 3, N'''''''''''', N''Char(2) Start of text --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (3, 3, N'''''''''''', N''Char(3) End of text --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (4, 3, N'''''''''''', N''Char(4) End of transmission --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (5, 3, N'''''''''''', N''Char(5) Enquiry --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (6, 3, N'''''''''''', N''Char(6) Acknowledge --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (7, 3, N'''''''''''', N''Char(7) Bell --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (8, 3, N'''''''''''', N''Char(8) Backspace --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (9, 3, N'''''''''''', N''Char(9) Horizontal tab --> Blank'', 1, 0)'
				SET @SQLStatement = @SQLStatement + '
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (10, 3, N'''''''''''', N''Char(10) NL Line feed --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (11, 3, N'''''''''''', N''Char(11) Vertical tab --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (12, 3, N'''''''''''', N''Char(12) NP form feed --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (13, 1, N''''''_'''''', N''Char(13) Carriage return --> Underscore (Code)'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (13, 2, N'''''' '''''', N''Char(13) Carriage return --> Space (Text)'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (14, 3, N'''''''''''', N''Char(14) Shift out --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (15, 3, N'''''''''''', N''Char(15) Shift in --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (16, 3, N'''''''''''', N''Char(16) Data link escape --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (17, 3, N'''''''''''', N''Char(17) Device control 1 --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (18, 3, N'''''''''''', N''Char(18) Device control 2 --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (19, 3, N'''''''''''', N''Char(19) Device control 3 --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (20, 3, N'''''''''''', N''Char(20) Device control 4 --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (21, 3, N'''''''''''', N''Char(21) Negative acknowledge --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (22, 3, N'''''''''''', N''Char(22) Synchronous idle --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (23, 3, N'''''''''''', N''Char(23) End of trans --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (24, 3, N'''''''''''', N''Char(24) Cancel --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (25, 3, N'''''''''''', N''Char(25) End of medium --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (26, 3, N'''''''''''', N''Char(26) Substitute --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (27, 3, N'''''''''''', N''Char(27) Escape --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (28, 3, N'''''''''''', N''Char(28) File separator --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (29, 3, N'''''''''''', N''Char(29) Group separator --> Blank'', 1, 0)'
				SET @SQLStatement = @SQLStatement + '
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (30, 3, N'''''''''''', N''Char(30) Record separator --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (31, 3, N'''''''''''', N''Char(31) Unit separator --> Blank'', 1, 0)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (32, 1, N''''''_'''''', N''Char(32), '''' '''', Space --> Underscore (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (33, 1, N'''''''''''', N''Char(33), ''''!'''', Exclamation mark --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (34, 1, N'''''''''''', N''Char(34), ''''"'''', Double quotes --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (35, 1, N'''''''''''', N''Char(35), ''''#'''', Number --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (36, 1, N'''''''''''', N''Char(36), ''''$'''', Dollar --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (37, 1, N'''''''''''', N''Char(37), ''''%'''', Percent --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (38, 1, N''''''_'''''', N''Char(38), ''''&'''', Ampersand --> Underscore (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (39, 1, N'''''''''''', N''Char(39), '''''''''''', Single quote --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (40, 1, N'''''''''''', N''Char(40), ''''('''', Open parenthesis --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (41, 1, N'''''''''''', N''Char(41), '''')'''', Close parenthesis --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (42, 1, N'''''''''''', N''Char(42), ''''*'''', Asterisk --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (43, 1, N''''''_'''''', N''Char(43), ''''+'''', Plus --> Underscore (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (44, 1, N'''''''''''', N''Char(44), '''','''', Comma --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (45, 1, N''''''_'''''', N''Char(45), ''''-'''', Dash --> Underscore (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (46, 1, N''''''_'''''', N''Char(46), ''''.'''', Dot --> Underscore (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (47, 1, N''''''_'''''', N''Char(47), ''''/'''', Slash --> Underscore (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (58, 1, N'''''''''''', N''Char(58), '''':'''', Colon --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (60, 1, N'''''''''''', N''Char(60), ''''<'''', Less than --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (61, 1, N'''''''''''', N''Char(61), ''''='''', Equals --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (62, 1, N'''''''''''', N''Char(62), ''''>'''', Greater than --> Blank (Code)'', 0, 1)'
				SET @SQLStatement = @SQLStatement + '
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (63, 1, N''''''_'''''', N''Char(63), ''''?'''', Question mark --> Underscore (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (64, 1, N''''''_'''''', N''Char(64), ''''@'''', At symbol --> Underscore (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (91, 1, N'''''''''''', N''Char(91), ''''['''', Opening bracket --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (92, 1, N''''''_'''''', N''Char(92), ''''\'''', Backslash --> Underscore (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (93, 1, N'''''''''''', N''Char(93), '''']'''', Closing bracket --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (94, 1, N'''''''''''', N''Char(94), ''''^'''', Caret - circumflex --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (96, 1, N'''''''''''', N''Char(96), ''''`'''', Grave accent --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (123, 1, N'''''''''''', N''Char(123), ''''{'''', Opening brace --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (124, 1, N'''''''''''', N''Char(124), ''''|'''', Vertical bar --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (125, 1, N'''''''''''', N''Char(125), ''''}'''', Closing brace --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (126, 1, N'''''''''''', N''Char(126), ''''~'''', Equivalency sign - tilde --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (145, 1, N'''''''''''', N''Char(145), ''''‘'''', Left single quotation mark --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (146, 1, N'''''''''''', N''Char(146), ''''’'''', Right single quotation mark --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (147, 1, N'''''''''''', N''Char(147), ''''“'''', Left double quotation mark --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (148, 1, N'''''''''''', N''Char(148), ''''”'''', Right double quotation mark --> Blank (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (150, 1, N''''''_'''''', N''Char(150), ''''–'''', Dash --> Underscore (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (151, 1, N''''''_'''''', N''Char(151), ''''—'''', Dash --> Underscore (Code)'', 0, 1)
				INSERT ' + @ETLDatabase + '.[dbo].[ReplaceText] ([Input], [StringTypeBM], [Output], [Comment], [ScanYN], [ReplaceYN]) VALUES (180, 1, N'''''''''''', N''Char(180), ''''´'''', Acute accent --> Blank (Code)'', 0, 1)
				ALTER TABLE ' + @ETLDatabase + '.[dbo].[ReplaceText] ADD  CONSTRAINT [DF_Replace_StringTypeBM]  DEFAULT ((3)) FOR [StringTypeBM]
				ALTER TABLE ' + @ETLDatabase + '.[dbo].[ReplaceText] ADD  CONSTRAINT [DF_ReplaceText_ScanYN]  DEFAULT ((0)) FOR [ScanYN]
				ALTER TABLE ' + @ETLDatabase + '.[dbo].[ReplaceText] ADD  CONSTRAINT [DF_Replace_SelectYN]  DEFAULT ((1)) FOR [ReplaceYN]
				EXEC ' + @ETLDatabase + '.sys.sp_addextendedproperty @name=N''MS_Description'', @value=N''1 = Code, 2 = Text, 3 = All (1+2)'' , @level0type=N''SCHEMA'',@level0name=N''dbo'', @level1type=N''TABLE'',@level1name=N''ReplaceText'', @level2type=N''COLUMN'',@level2name=N''StringTypeBM'''
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)

				SET @SQLStatement = 'CREATE TRIGGER [dbo].[ReplaceText_Upd]
				ON [dbo].[ReplaceText]
				AFTER DELETE, INSERT, UPDATE 
				AS 
					EXEC spCreate_f_ReplaceText
					EXEC spCreate_f_ScanText'

								SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

								IF @Debug <> 0
									BEGIN
										PRINT @SQLStatement 
										INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
									END
						
								EXEC (@SQLStatement)
			
							END

					RAISERROR ('60 percent', 0, 60) WITH NOWAIT

				SET @Step = 'Create table ReplaceText_ScanLog'
							IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'ReplaceText_ScanLog' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[ReplaceText_ScanLog](
					[LogID] [int] IDENTITY(1,1) NOT NULL,
					[TableName] [nvarchar](100) NOT NULL,
					[FieldName] [nvarchar](100) NOT NULL,
					[ErrorMessage] [nvarchar](max) NOT NULL,
					[Inserted] [datetime] NOT NULL,
				 CONSTRAINT [PK_ReplaceText_ScanLog] PRIMARY KEY CLUSTERED 
				(
					[LogID] ASC
				)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
				) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
				
				ALTER TABLE ' + @ETLDatabase + '.[dbo].[ReplaceText_ScanLog] ADD  CONSTRAINT [DF_ReplaceText_ScanLog_Inserted]  DEFAULT (getdate()) FOR [Inserted]
				EXEC ' + @ETLDatabase + '.sys.sp_addextendedproperty @name=N''MS_Description'', @value=N''InputText, CharacterCode, Position'' , @level0type=N''SCHEMA'',@level0name=N''dbo'', @level1type=N''TABLE'',@level1name=N''ReplaceText_ScanLog'', @level2type=N''COLUMN'',@level2name=N''ErrorMessage'''
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table MemberSelection'
							IF @Version > '1.3' AND (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'MemberSelection' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[MemberSelection](
					[DimensionID] [int] NOT NULL,
					[Label] [nvarchar](50) NOT NULL,
					[SelectYN] [bit] NOT NULL,
				 CONSTRAINT [PK_MemberSelection] PRIMARY KEY CLUSTERED 
				(
					[DimensionID] ASC,
					[Label] ASC
				)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
				) ON [PRIMARY]
				
				ALTER TABLE ' + @ETLDatabase + '.[dbo].[MemberSelection] ADD  CONSTRAINT [DF_MemberSelection_SelectYN]  DEFAULT ((1)) FOR [SelectYN]'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table FinancialSegment'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'FinancialSegment' AND DatabaseName = @ETLDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[FinancialSegment](
					[SourceID] [int] NOT NULL,
					[EntityCode] [nvarchar](50) NOT NULL,
					[COACode] [nvarchar](20) NOT NULL,
					[SegmentNbr] [int] NOT NULL,
					[EntityName] [nvarchar](255) NULL,
					[SQLDB] [nvarchar](50) NULL,
					[SegmentTable] [nvarchar](50) NULL,
					[SegmentCode] [nvarchar](50) NULL,
					[SegmentName] [nvarchar](50) NULL,
					[Company_COACode] [nvarchar](50) NULL,
					[DimensionTypeID] [int] NULL,
					[DynamicYN] [bit] NOT NULL CONSTRAINT [DF_FinancialSegment_DynamicYN]  DEFAULT ((0)),
					[Start] [int] NULL,
					[Length] [int] NULL,
				 CONSTRAINT [PK_FinancialSegment] PRIMARY KEY CLUSTERED 
				(
					[SourceID] ASC,
					[EntityCode] ASC,
					[COACode] ASC,
					[SegmentNbr] ASC
				)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
				) ON [PRIMARY]'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table wrk_FACT_Update'
					IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'wrk_FACT_Update' AND DatabaseName = @ETLDatabase) = 0
						BEGIN
							SET @SQLStatement = 'CREATE TABLE ' + @ETLDatabase + '.[dbo].[wrk_FACT_Update](
								[BusinessProcess_MemberId] [bigint] NOT NULL,
								[Entity_MemberId] [bigint] NOT NULL,
								[Scenario_MemberId] [bigint] NOT NULL,
								[Time_MemberId] [bigint] NOT NULL,
							 CONSTRAINT [PK_wrk_FACT_Update] PRIMARY KEY CLUSTERED 
							(
								[BusinessProcess_MemberId] ASC,
								[Entity_MemberId] ASC,
								[Scenario_MemberId] ASC,
								[Time_MemberId] ASC
							)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
							) ON [PRIMARY]'
			
							IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
						END

			END --End of Create tables in pcETL

		IF @DataBaseBM & 2 > 0 --pcDATA
			BEGIN
				SET @Step = 'Create table JobLog (CallistoDatabase)'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'JobLog' AND DatabaseName = @CallistoDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @CallistoDatabase + '.[dbo].[JobLog](
									[JobID] [int] NULL,
									[JobLogID] [int] IDENTITY(1,1) NOT NULL,
									[StartTime] [datetime] NOT NULL,
									[ProcedureName] [nvarchar](100) NULL,
									[Duration] [time](7) NOT NULL,
									[Deleted] [int] NOT NULL,
									[Inserted] [int] NOT NULL,
									[Updated] [int] NOT NULL,
									[Selected] [int] NOT NULL,
									[ErrorNumber] [int] NOT NULL,
									[ErrorSeverity] [int] NULL,
									[ErrorState] [int] NULL,
									[ErrorProcedure] [nvarchar](128) NULL,
									[ErrorStep] [nvarchar](255) NULL,
									[ErrorLine] [int] NULL,
									[ErrorMessage] [nvarchar](4000) NULL,
									[Version] [nvarchar](100) NULL,
									[Parameter] [nvarchar](4000) NULL,
									[UserName] [nvarchar](100) NULL,
									[UserID] [int] NULL,
									[InstanceID] [int] NULL,
									[VersionID] [int] NULL,
								 CONSTRAINT [PK_JobLog] PRIMARY KEY CLUSTERED 
								(
									[JobLogID] DESC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY]
								
								ALTER TABLE ' + @CallistoDatabase + '.[dbo].[JobLog] ADD  CONSTRAINT [DF_JobLog_JobID]  DEFAULT ((0)) FOR [JobID]
								ALTER TABLE ' + @CallistoDatabase + '.[dbo].[JobLog] ADD  CONSTRAINT [DF_JobLog_Deleted]  DEFAULT ((0)) FOR [Deleted]
								ALTER TABLE ' + @CallistoDatabase + '.[dbo].[JobLog] ADD  CONSTRAINT [DF_JobLog_Inserted]  DEFAULT ((0)) FOR [Inserted]
								ALTER TABLE ' + @CallistoDatabase + '.[dbo].[JobLog] ADD  CONSTRAINT [DF_JobLog_Updated]  DEFAULT ((0)) FOR [Updated]
								ALTER TABLE ' + @CallistoDatabase + '.[dbo].[JobLog] ADD  CONSTRAINT [DF_JobLog_Selected]  DEFAULT ((0)) FOR [Selected]
								ALTER TABLE ' + @CallistoDatabase + '.[dbo].[JobLog] ADD  CONSTRAINT [DF_JobLog_ErrorNumber]  DEFAULT ((0)) FOR [ErrorNumber]'

								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table wrk_Debug'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'wrk_Debug' AND DatabaseName = @CallistoDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @CallistoDatabase + '.[dbo].[wrk_Debug](
									[DebugID] [int] IDENTITY(1,1) NOT NULL,
									[ProcedureName] [nvarchar](100) NULL,
									[Comment] [nvarchar](255) NULL,
									[SQLStatement] [nvarchar](max) NULL,
									[Inserted] [datetime] NOT NULL,
								 CONSTRAINT [PK_wrk_Debug] PRIMARY KEY CLUSTERED 
								(
									[DebugID] DESC
								)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
								) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

								ALTER TABLE ' + @CallistoDatabase + '.[dbo].[wrk_Debug] ADD  CONSTRAINT [DF_wrk_Debug_Inserted]  DEFAULT (getdate()) FOR [Inserted]'
			
								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

				SET @Step = 'Create table wrk_ParameterValues'
						IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Table' AND ObjectName = 'wrk_ParameterValues' AND DatabaseName = @CallistoDatabase) = 0
							BEGIN
								SET @SQLStatement = 'CREATE TABLE ' + @CallistoDatabase + '.[dbo].[wrk_ParameterValues]
									(
									[ParameterName] [nvarchar](255) NOT NULL,
									[MemberId] [bigint] NULL,
									[StringValue] [nvarchar](512) NULL
									)'

								IF @Debug <> 0 PRINT @SQLStatement 
								EXEC (@SQLStatement)
							END

			END --End of Create tables in pcDATA
-------------------------------
SET @Step = 'CREATE PROCEDURES'
-------------------------------
IF @Debug <> 0 PRINT @Step

IF @DataBaseBM & 1 > 0 --pcETL
	BEGIN

SET @Step = 'CREATE PROCEDURE spSet_JobLog'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spSet_JobLog' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSet_JobLog] 

	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL OUT,
	@LogStartTime datetime = NULL,
	@ProcedureName nvarchar(100) = NULL,
	@Duration time(7) = NULL,
	@Deleted int = 0,
	@Inserted int = 0,
	@Updated int = 0,
	@Selected int = 0,
	@ErrorNumber int = 0,
	@ErrorSeverity int = NULL,
	@ErrorState int = NULL,
	@ErrorProcedure nvarchar(128) = NULL,
	@ErrorStep nvarchar(255) = NULL,
	@ErrorLine int = NULL,
	@ErrorMessage nvarchar(4000) = NULL, 
	@LogVersion nvarchar(100) = NULL,
	@UserName nvarchar(100) = NULL,

	@ProcedureID INT = 880000292,
	@GetVersion bit = 0,
	@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
					
DECLARE
	@StartTime DATETIME = NULL,

	@Step nvarchar(255),
	@Message nvarchar(500) = '''''''',
	@Severity int = 0,
	@Description nvarchar(255),
	@Version nvarchar(50) = ''''2.0.0.2141''''

SET NOCOUNT ON 

IF @GetVersion <> 0
	BEGIN
		IF @Version = ''''2.0.0.2141'''' SET @Description = ''''Procedure created.''''

		SELECT [Version] = @Version, [Description] = @Description, [ProcedureID] = @ProcedureID
		RETURN
	END'
			
				SET @SQLStatement = @SQLStatement + '

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = ''''UPDATE or INSERT table JobLog''''
		IF @JobLogID IS NULL
			BEGIN
				INSERT INTO JobLog
					(
					[JobID],
					[StartTime],
					[ProcedureName],
					[Duration],
					[Deleted],
					[Inserted],
					[Updated],
					[Selected],
					[ErrorNumber],
					[ErrorSeverity],
					[ErrorState],
					[ErrorProcedure],
					[ErrorStep],
					[ErrorLine],
					[ErrorMessage],
					[Version],
					[UserName],
					[UserID],
					[InstanceID],
					[VersionID]
					) 
				SELECT
					[JobID] = @JobID,
					[StartTime] = @LogStartTime,
					[ProcedureName] = @ProcedureName,
					[Duration] = @Duration,
					[Deleted] = @Deleted,
					[Inserted] = @Inserted,
					[Updated] = @Updated,
					[Selected] = @Selected,
					[ErrorNumber] = @ErrorNumber,
					[ErrorSeverity] = @ErrorSeverity,
					[ErrorState] = @ErrorState,
					[ErrorProcedure] = @ErrorProcedure,
					[ErrorStep] = @ErrorStep,
					[ErrorLine] = @ErrorLine,
					[ErrorMessage] = @ErrorMessage, 
					[Version] = @LogVersion,
					[UserName] = @UserName,
					[UserID] = @UserID,
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID

				SET @JobLogID = @@IDENTITY
			END'
			
				SET @SQLStatement = @SQLStatement + '
		ELSE
			BEGIN
				UPDATE JobLog
				SET
					[JobID] = @JobID,
					[StartTime] = @LogStartTime,
					[ProcedureName] = @ProcedureName,
					[Duration] = @Duration,
					[Deleted] = @Deleted,
					[Inserted] = @Inserted,
					[Updated] = @Updated,
					[Selected] = @Selected,
					[ErrorNumber] = @ErrorNumber,
					[ErrorSeverity] = @ErrorSeverity,
					[ErrorState] = @ErrorState,
					[ErrorProcedure] = @ErrorProcedure,
					[ErrorStep] = @ErrorStep,
					[ErrorLine] = @ErrorLine,
					[ErrorMessage] = @ErrorMessage, 
					[Version] = @LogVersion,
					[UserName] = @UserName,
					[UserID] = @UserID,
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID
				WHERE
					[JobLogID] = @JobLogID
			END
END TRY

BEGIN CATCH
	SELECT
		@UserID = ISNULL(@UserID, -100),
		@InstanceID = ISNULL(@InstanceID, -100),
		@VersionID = ISNULL(@VersionID, -100)

	INSERT INTO JobLog
		(
		[JobID],
		[StartTime],
		[ProcedureName],
		[Duration],
		[ErrorNumber],
		[ErrorSeverity],
		[ErrorState],
		[ErrorProcedure],
		[ErrorStep],
		[ErrorLine],
		[ErrorMessage],
		[Version],
		[UserName],
		[UserID],
		[InstanceID],
		[VersionID]
		)'
			
				SET @SQLStatement = @SQLStatement + '
	SELECT
		[JobID] = @ProcedureID,
		[StartTime] = @StartTime,
		[ProcedureName] = OBJECT_NAME(@@PROCID),
		[Duration] = GetDate() - @StartTime,
		[ErrorNumber] = ERROR_NUMBER(),
		[ErrorSeverity] = ERROR_SEVERITY(),
		[ErrorState] = ERROR_STATE(),
		[ErrorProcedure] = ERROR_PROCEDURE(),
		[ErrorStep] = @Step,
		[ErrorLine] = ERROR_LINE(),
		[ErrorMessage] = ERROR_MESSAGE(),
		[Version] = @Version,
		[UserName] = suser_name(),
		[UserID] = @UserID,
		[InstanceID] = @InstanceID,
		[VersionID] = @VersionID

	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

SET @Step = ''''Define exit point''''
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)'
				
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)

			END

SET @Step = 'CREATE PROCEDURE spIU_0000_FACT_Financials'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spIU_0000_FACT_Financials' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spIU_0000_FACT_Financials] 

	@UserID int = -10,
	@InstanceID int = ' + CONVERT(nvarchar(10), @InstanceID) + ',
	@VersionID int = ' + CONVERT(nvarchar(10), @VersionID) + ',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000000,
	@StartTime datetime = NULL,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
					
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = ''''spIU_0000_FACT_Financials'''',
	@JSON = ''''
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(10), @InstanceID) + '"},
		{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(10), @VersionID) + '"}
		]''''

EXEC [spIU_0000_FACT_Financials] @UserID=-10, @InstanceID=' + CONVERT(nvarchar(10), @InstanceID) + ', @VersionID=' + CONVERT(nvarchar(10), @VersionID) + ', @Debug=1

EXEC [spIU_0000_FACT_Financials] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@Deleted_Step int = 0,
    @Inserted_Step int = 0,
    @Updated_Step int = 0,
	@Selected_Step int = 0,
	@StartTime_Step datetime,
	@Duration_Step time(7),
	@SequenceBM int = 7,

	@Step nvarchar(255),
	@Message nvarchar(500) = '''''''',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@Version nvarchar(50) = ''''2.0.0.2140'''''
			
				SET @SQLStatement = @SQLStatement + '

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = ''''Update Journal table and FACT Financials table'''',
			@MandatoryParameter = '''''''' --Without @, separated by |

		IF @Version = ''''2.0.0.2140'''' SET @Description = ''''Procedure created.''''

--		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = ''''Set procedure variables''''
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

	SET @Step = ''''Load Journal''''
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID) + '''' (spIU_Journal)'''',
			@StartTime_Step = GETDATE(),
			@Deleted_Step = 0,
			@Inserted_Step = 0,
			@Updated_Step = 0,
			@Selected_Step = 0
		EXEC pcINTEGRATOR..spIU_Journal @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @SequenceBM = @SequenceBM, @JobID = @JobID, @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT, @Selected = @Selected_Step OUT, @Debug = @Debug
		SET @Duration_Step = GetDate() - @StartTime_Step
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime_Step, @ProcedureName = @ProcedureName, @Duration = @Duration_Step, @Deleted = @Deleted_Step, @Inserted = @Inserted_Step, @Updated = @Updated_Step, @Selected = @Selected_Step, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

		SELECT
			@Deleted = @Deleted + @Deleted_Step,
			@Inserted = @Inserted + @Inserted_Step,
			@Updated = @Updated + @Updated_Step,
			@Selected = @Selected + @Selected_Step

	SET @Step = ''''Reload BusinessProcess and Scenario''''
		EXEC [pcINTEGRATOR]..[spIU_BusinessProcess_Callisto] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID
		EXEC [pcINTEGRATOR]..[spIU_Scenario_Callisto] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID

	SET @Step = ''''Load FACT Financials'''''
			
				SET @SQLStatement = @SQLStatement + '
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID) + '''' (spIU_Journal_DataClass_Financials)'''',
			@StartTime_Step = GETDATE(),
			@Deleted_Step = 0,
			@Inserted_Step = 0,
			@Updated_Step = 0,
			@Selected_Step = 0
--		EXEC pcINTEGRATOR..spIU_Journal_DataClass_Financials @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT, @Selected = @Selected_Step OUT, @Debug = @Debug
		EXEC pcINTEGRATOR..spIU_Journal_DataClass_Financials @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @Deleted = @Deleted_Step OUT, @Inserted = @Inserted_Step OUT, @Updated = @Updated_Step OUT, @Selected = @Selected_Step OUT, @Debug = @Debug
		SET @Duration_Step = GetDate() - @StartTime_Step
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime_Step, @ProcedureName = @ProcedureName, @Duration = @Duration_Step, @Deleted = @Deleted_Step, @Inserted = @Inserted_Step, @Updated = @Updated_Step, @Selected = @Selected_Step, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName

		SELECT
			@Deleted = @Deleted + @Deleted_Step,
			@Inserted = @Inserted + @Inserted_Step,
			@Updated = @Updated + @Updated_Step,
			@Selected = @Selected + @Selected_Step

	SET @Step = ''''Set @Duration''''
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = ''''Define exit point''''
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)'
				
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)

			END

SET @Step = 'CREATE PROCEDURE sp_CheckObject'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'sp_CheckObject' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[sp_CheckObject] 

					@ObjectName nvarchar(50),
					@ObjectType nvarchar(50)

				' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
					
				AS

				DECLARE
					@Count int,
					@Action nvarchar(10)

				SELECT
					@Count = COUNT(1) 
				FROM
					Sysobjects 
				WHERE
					name = @ObjectName AND
					xtype = @ObjectType
				 
				IF @Count = 0
					SET @Action = ''''CREATE''''
				ELSE
					SET @Action = ''''ALTER''''
					
				SELECT @Action'
				
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)

			END


	SET @Step = 'CREATE PROCEDURE spIU_0000_ETL_wrk_SourceTable'
				IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spIU_0000_ETL_wrk_SourceTable' AND DatabaseName = @ETLDatabase) = 0 AND @SourceDBTypeBM & 2 > 0
				BEGIN
					SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spIU_0000_ETL_wrk_SourceTable] 

	@JobID int = 0,
	@SourceID int = -1,
	@StartYear int = -1,
	@TableCode nvarchar(50) = NULL,
	@Rows int = NULL,
	@GetVersion bit = 0,
	@Duration  time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--EXEC [spIU_0000_ETL_wrk_SourceTable] @Debug = 1
--EXEC [spIU_0000_ETL_wrk_SourceTable] @SourceID = 303, @StartYear = 2009, @TableCode = ''''SYCH'''', @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@SourceTypeFamilyID int,
	@SourceType nvarchar(50),
	@SourceDBTypeID int,
	@SourceDatabase nvarchar(255),
	@ETLDatabase nvarchar(50),
	@EntityCode nvarchar(50),
	@DatabaseName nvarchar(50),
	@TableName nvarchar(50),
	@YearlyYN int,
	@Counter int,
	@CenturySplit int,
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT @CenturySplit = YEAR(GETDATE()) % 100 + 10

	SET @Step = ''''Create temp tables''''
		CREATE TABLE #Database
			(
			EntityCode nvarchar(50) COLLATE DATABASE_DEFAULT,
			DatabaseName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #SourceTable
			(
			[SourceID] [int] NOT NULL,
			[EntityCode] [nvarchar](50) COLLATE DATABASE_DEFAULT NOT NULL,
			[TableCode] [nvarchar](50) COLLATE DATABASE_DEFAULT NOT NULL,
			[DatabaseName] [nvarchar](100) COLLATE DATABASE_DEFAULT NOT NULL,
			[TableName] [nvarchar](255) COLLATE DATABASE_DEFAULT NOT NULL,
			[FiscalYear] [int] NOT NULL,
			[Rows] [int] NOT NULL
			)

		CREATE TABLE #Counter
			(
			[Counter] [int]
			)

	SET @Step = ''''Create master cursor''''
		DECLARE SourceTable_Cursor CURSOR FOR

			SELECT DISTINCT
				SourceTypeFamilyID = ST.SourceTypeFamilyID,
				SourceDBTypeID = ST.SourceDBTypeID,
				SourceType = ST.SourceTypeName,
				SourceDatabase = ''''['''' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, ''''['''', ''''''''), '''']'''', ''''''''), ''''.'''', ''''].['''') + '''']'''',
				ETLDatabase = A.ETLDatabase,
				SourceID = S.SourceID,
				StartYear = CASE WHEN @StartYear <> -1 THEN @StartYear ELSE S.StartYear END,
				TableCode = STa.TableCode,
				YearlyYN = STa.YearlyYN
			FROM
				pcINTEGRATOR..SourceTable STa
				INNER JOIN pcINTEGRATOR..Model BM ON BM.ModelBM & STa.ModelBM > 0 AND BM.SelectYN <> 0
				INNER JOIN pcINTEGRATOR..Model M ON M.ModelID <> 0 AND M.BaseModelID = BM.ModelID AND M.SelectYN <> 0
				INNER JOIN pcINTEGRATOR..[Source] S ON S.SourceID <> 0 AND S.ModelID = M.ModelID AND (S.SourceID = @SourceID OR @SourceID = -1) AND S.SelectYN <> 0
				INNER JOIN pcINTEGRATOR..[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeFamilyID = STa.SourceTypeFamilyID AND ST.SourceDBTypeID = 2 AND ST.SelectYN <> 0
				INNER JOIN pcINTEGRATOR..[Application] A ON A.ApplicationID = M.ApplicationID AND A.ETLDatabase = DB_Name() AND A.SelectYN <> 0
			WHERE
				(STa.TableCode = @TableCode OR @TableCode IS NULL)

			OPEN SourceTable_Cursor
			FETCH NEXT FROM SourceTable_Cursor INTO @SourceTypeFamilyID, @SourceDBTypeID, @SourceType, @SourceDatabase, @ETLDatabase, @SourceID, @StartYear, @TableCode, @YearlyYN

			WHILE @@FETCH_STATUS = 0
			  BEGIN

			  	IF @Debug <> 0 	
					SELECT
						CenturySplit = @CenturySplit,
						SourceTypeFamilyID = @SourceTypeFamilyID,
						SourceDBTypeID = @SourceDBTypeID,
						SourceType = @SourceType,
						SourceDatabase = @SourceDatabase,
						ETLDatabase = @ETLDatabase,
						SourceID = @SourceID,
						StartYear = @StartYear,
						TableCode =  @TableCode

				SET @Step = ''''Truncate temp tables''''	
					TRUNCATE TABLE #Database
					TRUNCATE TABLE #SourceTable
					TRUNCATE TABLE #Counter

				SET @Step = ''''Fill temp table #Database''''
					IF @SourceTypeFamilyID = 5
						SET @SQLStatement = ''''SELECT EntityCode, DatabaseName = '''''''''''' + @SourceDatabase + '''''''''''' FROM '''' + @ETLDatabase + ''''.dbo.Entity WHERE SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''' AND SelectYN <> 0''''
					ELSE
						SET @SQLStatement = ''''SELECT EntityCode, DatabaseName = Par01 FROM '''' + @ETLDatabase + ''''.dbo.Entity WHERE SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''' AND SelectYN <> 0''''

					IF @Debug <> 0 PRINT @SQLStatement

					INSERT INTO #Database (EntityCode, DatabaseName) EXEC (@SQLStatement)

					IF @Debug <> 0 PRINT CONVERT(nvarchar, GETDATE() - @StartTime, 114)
					IF @Debug <> 0 SELECT TempTable = ''''#Database'''', * FROM #Database

				SET @Step = ''''Start Database_Cursor''''
					DECLARE Database_Cursor CURSOR FOR

						SELECT 
							EntityCode,
							DatabaseName
						FROM
							#Database

						OPEN Database_Cursor
						FETCH NEXT FROM Database_Cursor INTO @EntityCode, @DatabaseName

						WHILE @@FETCH_STATUS = 0
						  BEGIN
							IF @SourceTypeFamilyID = 2 --iScala
								BEGIN
									SET @SQLStatement = ''''
										SELECT
											SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''',
											EntityCode = '''''''''''' + @EntityCode + '''''''''''',
											TableCode = '''''''''''' + @TableCode + '''''''''''',
											DatabaseName = E.Par01,
											TableName = st.name COLLATE DATABASE_DEFAULT,
											FiscalYear = CASE WHEN CONVERT(int, SUBSTRING(st.name, 7, 2)) < '''' + CONVERT(nvarchar, @CenturySplit) + '''' THEN 2000 + CONVERT(int, SUBSTRING(st.name, 7, 2)) ELSE 1900 + CONVERT(int, SUBSTRING(st.name, 7, 2)) END,
											[Rows] = 0
										FROM
											['''' + @ETLDatabase + ''''].dbo.Entity E
											INNER JOIN '''' + @DatabaseName + ''''.sys.tables st ON
											st.name COLLATE DATABASE_DEFAULT LIKE '''''''''''' + @TableCode + ''''%'''' + '''''''''''' AND
											SUBSTRING(st.name COLLATE DATABASE_DEFAULT, 5, 2) = E.EntityCode AND LEN(st.name) = 8
										WHERE
											E.SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''' AND
											E.EntityCode = '''''''''''' + @EntityCode + '''''''''''' AND
											E.SelectYN <> 0 AND
											ISNUMERIC(SUBSTRING(st.name, 7,2)) <> 0 AND'''' 

									SET @SQLStatement = @SQLStatement + ''''
											((CASE WHEN CONVERT(int, SUBSTRING(st.name, 7, 2)) < '''' + CONVERT(nvarchar, @CenturySplit) + '''' THEN 2000 + CONVERT(int, SUBSTRING(st.name, 7, 2)) ELSE 1900 + CONVERT(int, SUBSTRING(st.name, 7, 2)) END >= '''' + CONVERT(nvarchar, @StartYear) + '''') OR 
											(SUBSTRING(st.name, 7, 2) = ''''''''00'''''''' AND '''' + CONVERT(nvarchar(10), @YearlyYN) + '''' = 0))''''					 
				
									SET @SQLStatement = @SQLStatement + ''''	 
										ORDER BY
											E.Par01,
											st.name DESC''''
								END

							ELSE IF @SourceTypeFamilyID = 3 --Enterprise
								BEGIN
									SET @SQLStatement = ''''
										SELECT
											SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''',
											EntityCode = '''''''''''' + @EntityCode + '''''''''''',
											TableCode = '''''''''''' + @TableCode + '''''''''''',
											DatabaseName = E.Par01,
											TableName = st.name COLLATE DATABASE_DEFAULT,
											FiscalYear = 0,
											[Rows] = 0
										FROM
											['''' + @ETLDatabase + ''''].dbo.Entity E
											INNER JOIN '''' + @DatabaseName + ''''.dbo.sysobjects st ON xtype IN (''''''''U'''''''', ''''''''V'''''''') AND
												st.name COLLATE DATABASE_DEFAULT = '''''''''''' + @TableCode + ''''''''''''
										WHERE
											E.SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''' AND
											E.EntityCode = '''''''''''' + @EntityCode + '''''''''''' AND
											E.SelectYN <> 0''''					 
				
									SET @SQLStatement = @SQLStatement + ''''	 
										ORDER BY
											E.Par01,
											st.name DESC''''
								END

							ELSE IF @SourceTypeFamilyID = 5 --Navision
								BEGIN
									SET @SQLStatement = ''''
										SELECT
											SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''',
											EntityCode = '''''''''''' + @EntityCode + '''''''''''',
											TableCode = '''''''''''' + @TableCode + '''''''''''',
											DatabaseName = '''''''''''' + @SourceDatabase + '''''''''''',
											TableName = st.name COLLATE DATABASE_DEFAULT,
											FiscalYear = 0,
											[Rows] = 0
										FROM
											['''' + @ETLDatabase + ''''].dbo.Entity E
											INNER JOIN '''' + @DatabaseName + ''''.dbo.sysobjects st ON xtype IN (''''''''U'''''''', ''''''''V'''''''') AND
												st.name COLLATE DATABASE_DEFAULT = E.Par01 + '''''''''''' + @TableCode + ''''''''''''
										WHERE
											E.SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''' AND
											E.EntityCode = '''''''''''' + @EntityCode + '''''''''''' AND
											E.SelectYN <> 0''''					 
				
									SET @SQLStatement = @SQLStatement + ''''	 
										ORDER BY
											st.name DESC''''
								END

							IF @Debug <> 0 
								BEGIN
									PRINT @EntityCode + '''' '''' + CONVERT(nvarchar, GETDATE() - @StartTime, 114)
									PRINT @SQLStatement
								END

							INSERT INTO #SourceTable (SourceID, EntityCode, TableCode, DatabaseName, TableName, FiscalYear, [Rows]) EXEC (@SQLStatement)
				
							FETCH NEXT FROM Database_Cursor INTO @EntityCode, @DatabaseName
						  END

					CLOSE Database_Cursor
					DEALLOCATE Database_Cursor

					IF @Debug <> 0 	SELECT TempTable = ''''#SourceTable'''', * FROM #SourceTable WHERE SourceID = @SourceID AND TableCode = @TableCode ORDER BY EntityCode, FiscalYear DESC

				SET @Step = ''''Start Table_Cursor''''
					DECLARE Table_Cursor CURSOR FOR

						SELECT 
							DatabaseName,
							TableName
						FROM
							#SourceTable
						ORDER BY
							DatabaseName,
							TableName

						OPEN Table_Cursor
						FETCH NEXT FROM Table_Cursor INTO @DatabaseName, @TableName

						WHILE @@FETCH_STATUS = 0
						  BEGIN
							SET @SQLStatement = ''''
								SELECT [Counter] = COUNT(1) FROM '''' + @DatabaseName + ''''.dbo.sysobjects WHERE xtype IN (''''''''U'''''''', ''''''''V'''''''') AND [name] = '''''''''''' + @TableName + ''''''''''''''''
							IF @Debug <> 0 PRINT @SQLStatement
							TRUNCATE TABLE #Counter
							INSERT INTO #Counter ([Counter]) EXEC (@SQLStatement)
					
							IF (SELECT [Counter] FROM #Counter) = 1
								BEGIN
									SET @SQLStatement = ''''
										SELECT [Counter] = COUNT(1) FROM '''' + @DatabaseName + ''''.dbo.['''' + @TableName + '''']''''
									IF @Debug <> 0 PRINT @SQLStatement
									TRUNCATE TABLE #Counter
									INSERT INTO #Counter ([Counter]) EXEC (@SQLStatement)
									SELECT @Counter = [Counter] FROM #Counter

									IF @Counter > 0
										BEGIN
											UPDATE
												#SourceTable
											SET
												[Rows] = @Counter
											WHERE
												DatabaseName = @DatabaseName AND
												TableName = @TableName
										END
								END
							FETCH NEXT FROM Table_Cursor INTO @DatabaseName, @TableName
						  END

					CLOSE Table_Cursor
					DEALLOCATE Table_Cursor

				SET @Step = ''''CleanUp''''
					DELETE wrk_SourceTable WHERE SourceID = @SourceID AND TableCode = @TableCode
		
					SET @Deleted = @Deleted + @@ROWCOUNT

				SET @Step = ''''Insert data into wrk_SourceTable''''
					INSERT INTO [dbo].[wrk_SourceTable]
						(
						[SourceID],
						[TableCode],
						[EntityCode],
						[TableName],
						[FiscalYear],
						[Rows]
						)
					 SELECT
						[SourceID] = iST.[SourceID],
						[TableCode] = iST.[TableCode],
						[EntityCode] = iST.[EntityCode],
						[TableName] = iST.[DatabaseName] + ''''.[dbo].['''' + iST.[TableName] + '''']'''',
						[FiscalYear] = iST.[FiscalYear],
						[Rows] = iST.[Rows]
					FROM
						#SourceTable iST
					WHERE
						[Rows] > 0

					SET @Inserted = @Inserted + @@ROWCOUNT	

				FETCH NEXT FROM SourceTable_Cursor INTO @SourceTypeFamilyID, @SourceDBTypeID, @SourceType, @SourceDatabase, @ETLDatabase, @SourceID, @StartYear, @TableCode, @YearlyYN
				END

		CLOSE SourceTable_Cursor
		DEALLOCATE SourceTable_Cursor

	SET @Step = ''''Drop temp tables''''	
		DROP TABLE #Database
		DROP TABLE #SourceTable
		DROP TABLE #Counter

	SET @Step = ''''Define exit point''''
		EXITPOINT:

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ''''_'''' + CONVERT(nvarchar, @SourceID) + ''''_'''' + @TableCode, @Duration, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)
				END


SET @Step = 'CREATE PROCEDURE spCheck_CheckSum'
	RAISERROR ('70 percent', 0, 70) WITH NOWAIT

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spCheck_CheckSum' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE spCheck_CheckSum

@JobID int = 0,
@UserID int = NULL,
@ApplicationID int = ' + CONVERT(nvarchar(10), @ApplicationID) + ',
@ResultType nvarchar(10) = NULL, --''''pcPortal'''', ''''Mail'''' (Default = ''''Mail'''')
@Rows int = NULL,
@Debug bit = 0,
@GetVersion bit = 0,
@Duration time(7) = ''''00:00:00'''' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

--EXEC [spCheck_CheckSum] @JobID = 3, @Debug = 1
--EXEC [spCheck_CheckSum] @JobID = 3, @ResultType = ''''pcPortal''''
--EXEC [spCheck_CheckSum] @UserID = 1005, @ResultType = ''''pcPortal''''
--EXEC [spCheck_CheckSum] @ResultType = ''''pcPortal''''
--EXEC [spCheck_CheckSum] @JobID = 3, @ResultType = ''''Mail''''

AS

DECLARE
	@InstanceID int,
	@pcPortal_URL nvarchar(255),
	@Mail_ProfileName nvarchar(128),
	@CheckSumID int,
	@CheckSumValue int,
	@CheckSumQuery nvarchar(max),
	@CheckSumReport nvarchar(max),
	@Always_Subject nvarchar(255),
	@Always_Body nvarchar(max),
	@Always_Importance varchar(6),
	@OnError_Subject nvarchar(255),
	@OnError_Body nvarchar(max),
	@OnError_Importance varchar(6),
	@Recipient nvarchar(max),
	@CC nvarchar(max),
	@BCC nvarchar(max),
	@BodyHTML nvarchar(max),
	@UserName nvarchar(100),
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Message nvarchar(500) = '''''''',
	@Severity int = 0,
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END'
			
				SET @SQLStatement = @SQLStatement + '

IF @JobID <> 0 AND @UserID IS NULL
	SET @UserID = 0

IF @UserID IS NULL OR @ApplicationID IS NULL
	BEGIN
		SET @Message = ''''Parameter @UserID and @ApplicationID must be set''''
		SET @Severity = 16
		GOTO ERRORHANDLING
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		EXEC [pcINTEGRATOR]..[spGet_User] @UserID = @UserID, @UserName = @UserName OUT
		SELECT @UserName = ISNULL(@UserName, suser_name())

		SELECT
			@InstanceID = InstanceID
		FROM
			[pcINTEGRATOR]..[Application]
		WHERE
			[ApplicationID] = @ApplicationID'
			
				SET @SQLStatement = @SQLStatement + '

		SELECT
			@pcPortal_URL = [pcPortal_URL],
			@Mail_ProfileName = [Mail_ProfileName]
		FROM
			[pcINTEGRATOR]..[Instance]
		WHERE
			[InstanceID] = @InstanceID

		IF @JobID = 0
			SELECT
				@JobID = MAX([JobID])
			FROM
				[Job]
			WHERE
				[EndTime] IS NOT NULL

		IF @ResultType IS NULL
			SELECT @ResultType = CASE WHEN ISNULL(@Mail_ProfileName, '''''''') = '''''''' THEN ''''pcPortal'''' ELSE ''''Mail'''' END

	SET @Step = ''''Run CheckSum_Cursor''''
		DECLARE CheckSum_Cursor CURSOR FOR

		SELECT CheckSumID, CheckSumQuery, CheckSumReport FROM CheckSum WHERE SelectYN <> 0 ORDER BY SortOrder
		
		OPEN CheckSum_Cursor

		FETCH NEXT FROM CheckSum_Cursor INTO @CheckSumID, @CheckSumQuery, @CheckSumReport
	
		WHILE @@FETCH_STATUS = 0
			BEGIN
			SET @CheckSumQuery = REPLACE(@CheckSumQuery, ''''@JobID'''', CONVERT(nvarchar(10), @JobID))
			EXEC sp_executesql @CheckSumQuery, N''''@internalVariable int OUT'''', @internalVariable = @CheckSumValue OUT

			IF @Debug <> 0 SELECT pcPortal_URL = @pcPortal_URL, CheckSumReport = @CheckSumReport, JobID = @JobID'
			
				SET @SQLStatement = @SQLStatement + '

			INSERT INTO CheckSumLog (JobID, CheckSumID, CheckSumValue, CheckSumReport, EndTime) SELECT JobID = @JobID, CheckSumID = @CheckSumID, CheckSumValue = @CheckSumValue, ISNULL(@pcPortal_URL + CASE WHEN RIGHT(@pcPortal_URL, 1) = ''''/'''' THEN '''''''' ELSE ''''/'''' END + REPLACE(@CheckSumReport, ''''@JobID'''', @JobID), ''''''''), EndTime = GetDate()
			SET @Inserted = @Inserted + @@ROWCOUNT

			FETCH NEXT FROM CheckSum_Cursor INTO @CheckSumID, @CheckSumQuery, @CheckSumReport
			END

		CLOSE CheckSum_Cursor
		DEALLOCATE CheckSum_Cursor

	SET @Step = ''''Fill temp table #CheckSum''''
		SELECT 
			CSL.JobID,
			CS.CheckSumID,
			CS.CheckSumName,
			CS.CheckSumDescription,
			CSL.CheckSumValue,
			CSL.CheckSumReport,
			CSL.EndTime,
			SortOrder1 = CASE WHEN CSL.CheckSumValue > 0 THEN 1 ELSE 0 END
		INTO
			#CheckSum
		FROM
			[CheckSumLog] CSL
			INNER JOIN [CheckSum] CS ON CS.CheckSumID = CSL.CheckSumID
		WHERE
			CSL.JobID = @JobID
		ORDER BY
			CS.SortOrder'
			
				SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Check @ResultType''''
		IF @ResultType = ''''pcPortal''''
			GOTO pcPortal
		ELSE IF @ResultType = ''''Mail''''
			GOTO Mail
		ELSE
			GOTO EXITPOINT

	SET @Step = ''''Return result set to pcPortal''''
		pcPortal:
		IF ISNULL(@pcPortal_URL, '''''''') = ''''''''
			BEGIN
				SET @Message = ''''The variable @pcPortal_URL is not set in the database.''''
				SET @Severity = 10
			END

		SELECT
			[JobID],
			[Name] = CheckSumName,
			[Query] = REPLACE(CheckSumReport, @pcPortal_URL + CASE WHEN RIGHT(@pcPortal_URL, 1) = ''''/'''' THEN '''''''' ELSE ''''/'''' END + ''''pcPortal/#!query/'''', ''''''''),
			[Errors#] = CheckSumValue,
			[Time] = EndTime
		FROM
			[#CheckSum]
		ORDER BY
			SortOrder1 DESC,
			EndTime

		GOTO EXITPOINT'
			
				SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Check mail profile''''
		Mail:
		IF ISNULL(@Mail_ProfileName, '''''''') = ''''''''
			BEGIN
				SET @Message = ''''The variable @Mail_ProfileName is not set in the database.''''
				SET @Severity = 16
				RAISERROR (@Message, @Severity, 100)
				GOTO EXITPOINT
			END
		ELSE
			BEGIN
				SELECT 
					@Always_Subject = [Subject],
					@Always_Body = [Body],
					@Always_Importance = [Importance]
				FROM
					[pcINTEGRATOR].[dbo].[MailMessage]
				WHERE
					[ApplicationID] = @ApplicationID AND
					[UserPropertyTypeID] = -5

				SELECT 
					@OnError_Subject = [Subject],
					@OnError_Body = [Body],
					@OnError_Importance = [Importance]
				FROM
					[pcINTEGRATOR].[dbo].[MailMessage]
				WHERE
					[ApplicationID] = @ApplicationID AND
					[UserPropertyTypeID] = -6'
			
				SET @SQLStatement = @SQLStatement + '

				CREATE TABLE #Recipient
					(
					Recipient nvarchar(100),
					CC nvarchar(100),
					BCC nvarchar(100)
					)
			END

	SET @Step = ''''Send mail to Always group''''
		INSERT INTO #Recipient
			(
			Recipient,
			CC,
			BCC
			)
		SELECT
			Recipient = CASE WHEN UPV5.UserPropertyValue IS NULL THEN UPV3.UserPropertyValue ELSE NULL END,
			CC = CASE WHEN UPV5.UserPropertyValue = ''''CC'''' THEN UPV3.UserPropertyValue ELSE NULL END,
			BCC = CASE WHEN UPV5.UserPropertyValue = ''''BCC'''' THEN UPV3.UserPropertyValue ELSE NULL END
		FROM
			pcINTEGRATOR..[User] U
			INNER JOIN pcINTEGRATOR..[UserMember] UM ON UM.UserID_Group = -4 AND UM.UserID_User = U.UserID AND UM.SelectYN <> 0
			INNER JOIN pcINTEGRATOR..[UserPropertyValue] UPV3 ON UPV3.UserID = U.UserID AND UPV3.UserPropertyTypeID = -3 AND UPV3.SelectYN <> 0
			LEFT JOIN pcINTEGRATOR..[UserPropertyValue] UPV5 ON UPV5.UserID = U.UserID AND UPV5.UserPropertyTypeID = -5 AND UPV5.SelectYN <> 0
		WHERE
			U.InstanceID = @InstanceID AND
			U.SelectYN <> 0

		IF (SELECT COUNT(1) FROM #Recipient) = 0
			GOTO ONERROR'
			
				SET @SQLStatement = @SQLStatement + '

		SELECT
			@Recipient = '''''''',
			@CC = '''''''',
			@BCC = ''''''''

		SELECT
			@Recipient = @Recipient + CASE WHEN Recipient IS NULL THEN '''''''' ELSE Recipient + '''';'''' END,
			@CC = @CC + CASE WHEN CC IS NULL THEN '''''''' ELSE CC + '''';'''' END,
			@BCC = @BCC + CASE WHEN BCC IS NULL THEN '''''''' ELSE BCC + '''';'''' END
		FROM
			#Recipient

		SELECT
			@Recipient = CASE WHEN LEN(@Recipient) >= 4 THEN SUBSTRING(@Recipient, 1, LEN(@Recipient) -1) ELSE '''''''' END,
			@CC = CASE WHEN LEN(@CC) >= 4 THEN SUBSTRING(@CC, 1, LEN(@CC) -1) ELSE '''''''' END,
			@BCC = CASE WHEN LEN(@BCC) >= 4 THEN SUBSTRING(@BCC, 1, LEN(@BCC) -1) ELSE '''''''' END

		SET @BodyHTML = ''''
<html>
<body>
'''' + @Always_Body + ''''
<table border="1" cellspacing="0" cellpadding="0"><colgroup><col width="60" /><col width="400" /><col width="60" /><col width="200" /></colgroup>
    <tbody>
	<tr>
		<td>JobID</td>
		<td>Name</td>
		<td>Errors#</td>
		<td>Time</td>
	</tr>''''

		SELECT
			@BodyHTML = ISNULL(@BodyHTML, '''''''') + CASE WHEN CheckSumValue > 0 THEN ''''<font color="red">'''' ELSE '''''''' END +
						CHAR(13) + CHAR(10) + CHAR(9) + ''''<tr>'''' + 
						CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ''''<td>'''' + CONVERT(nvarchar(10), JobID) + ''''</td>'''' +
						CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ''''<td><a href="'''' + CheckSumReport + ''''">'''' + CheckSumName + ''''</a></td>'''' +
						CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ''''<td>'''' + CONVERT(nvarchar(10), CheckSumValue) + ''''</td>'''' + 
						CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ''''<td>'''' + CONVERT(nvarchar(50), EndTime) + ''''</td>'''' +
						CHAR(13) + CHAR(10) + CHAR(9) + ''''</tr>'''' + CASE WHEN CheckSumValue > 0 THEN ''''</font>'''' ELSE '''''''' END
		FROM
			[#CheckSum]
		ORDER BY
			SortOrder1 DESC,
			EndTime'
			
				SET @SQLStatement = @SQLStatement + '

		SET @BodyHTML = @BodyHTML + CHAR(13) + CHAR(10) + CHAR(9) + ''''</tbody>'''' + CHAR(13) + CHAR(10) + ''''</table>'''' + CHAR(13) + CHAR(10) + ''''</body>''''  + CHAR(13) + CHAR(10) + ''''</html>''''

		IF @Debug <> 0
			BEGIN
				SELECT
					Step = ''''Always'''',
					Recipient = @Recipient,
					CC = @CC,
					BCC = @BCC

				SELECT
					JobID,
					[Name] = CheckSumName,
					Errors# = CheckSumValue,
					[Time] = EndTime
				FROM
					#CheckSum
				ORDER BY
					CASE WHEN CheckSumValue > 0 THEN 1 ELSE 0 END DESC,
					EndTime

				PRINT @BodyHTML
			END

		EXEC msdb..sp_send_dbmail 
				@profile_name = @Mail_ProfileName,
				@recipients = @Recipient,
				@copy_recipients = @CC,
				@blind_copy_recipients = @BCC,
				@subject = @Always_Subject, 
				@body = @BodyHTML, 
				@body_format = ''''HTML'''',
				@importance = @Always_Importance

	SET @Step = ''''Send mail to OnError group''''
		ONERROR:
		IF (SELECT COUNT(1) FROM #CheckSum WHERE CheckSumValue > 0) > 0
			BEGIN
				TRUNCATE TABLE #Recipient

				INSERT INTO #Recipient
					(
					Recipient,
					CC,
					BCC
					)
				SELECT
					Recipient = CASE WHEN UPV6.UserPropertyValue IS NULL THEN UPV3.UserPropertyValue ELSE NULL END,
					CC = CASE WHEN UPV6.UserPropertyValue = ''''CC'''' THEN UPV3.UserPropertyValue ELSE NULL END,
					BCC = CASE WHEN UPV6.UserPropertyValue = ''''BCC'''' THEN UPV3.UserPropertyValue ELSE NULL END
				FROM
					pcINTEGRATOR..[User] U
					INNER JOIN pcINTEGRATOR..[UserMember] UM ON UM.UserID_Group = -5 AND UM.UserID_User = U.UserID AND UM.SelectYN <> 0
					INNER JOIN pcINTEGRATOR..[UserPropertyValue] UPV3 ON UPV3.UserID = U.UserID AND UPV3.UserPropertyTypeID = -3 AND UPV3.SelectYN <> 0
					LEFT JOIN pcINTEGRATOR..[UserPropertyValue] UPV6 ON UPV6.UserID = U.UserID AND UPV6.UserPropertyTypeID = -6 AND UPV6.SelectYN <> 0
				WHERE
					U.InstanceID = @InstanceID AND
					U.SelectYN <> 0'
			
				SET @SQLStatement = @SQLStatement + '

				IF (SELECT COUNT(1) FROM #Recipient) = 0
					BEGIN
						DROP TABLE #Recipient
						GOTO EXITPOINT
					END

				SELECT
					@Recipient = '''''''',
					@CC = '''''''',
					@BCC = ''''''''

				SELECT
					@Recipient = @Recipient + CASE WHEN Recipient IS NULL THEN '''''''' ELSE Recipient + '''';'''' END,
					@CC = @CC + CASE WHEN CC IS NULL THEN '''''''' ELSE CC + '''';'''' END,
					@BCC = @BCC + CASE WHEN BCC IS NULL THEN '''''''' ELSE BCC + '''';'''' END
				FROM
					#Recipient

				SELECT
					@Recipient = CASE WHEN LEN(@Recipient) >= 4 THEN SUBSTRING(@Recipient, 1, LEN(@Recipient) -1) ELSE '''''''' END,
					@CC = CASE WHEN LEN(@CC) >= 4 THEN SUBSTRING(@CC, 1, LEN(@CC) -1) ELSE '''''''' END,
					@BCC = CASE WHEN LEN(@BCC) >= 4 THEN SUBSTRING(@BCC, 1, LEN(@BCC) -1) ELSE '''''''' END

				SET @BodyHTML = ''''
<html>
<body>
'''' + @OnError_Body + ''''
<table border="1" cellspacing="0" cellpadding="0"><colgroup><col width="60" /><col width="400" /><col width="60" /><col width="200" /></colgroup>
    <tbody>
	<tr>
		<td>JobID</td>
		<td>Name</td>
		<td>Errors#</td>
		<td>Time</td>
	</tr><font color="red">''''

				SELECT
					@BodyHTML = ISNULL(@BodyHTML, '''''''') + 
								CHAR(13) + CHAR(10) + CHAR(9) + ''''<tr>'''' + 
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ''''<td>'''' + CONVERT(nvarchar(10), JobID) + ''''</td>'''' +
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ''''<td><a href="'''' + CheckSumReport + ''''">'''' + CheckSumName + ''''</a></td>'''' +
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ''''<td>'''' + CONVERT(nvarchar(10), CheckSumValue) + ''''</td>'''' + 
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ''''<td>'''' + CONVERT(nvarchar(50), EndTime) + ''''</td>'''' +
								CHAR(13) + CHAR(10) + CHAR(9) + ''''</tr>''''
				FROM
					[#CheckSum]
				WHERE
					CheckSumValue > 0
				ORDER BY
					SortOrder1 DESC,
					EndTime'
			
				SET @SQLStatement = @SQLStatement + '

				SET @BodyHTML = @BodyHTML + ''''</font>'''' + CHAR(13) + CHAR(10) + CHAR(9) + ''''</tbody>'''' + CHAR(13) + CHAR(10) + ''''</table>'''' + CHAR(13) + CHAR(10) + ''''</body>''''  + CHAR(13) + CHAR(10) + ''''</html>''''

				IF @Debug <> 0
					BEGIN
						SELECT
							Step = ''''OnError'''',
							Recipient = @Recipient,
							CC = @CC,
							BCC = @BCC

						SELECT
							JobID,
							[Name] = CheckSumName,
							Errors# = CheckSumValue,
							[Time] = EndTime
						FROM
							#CheckSum
						WHERE
							CheckSumValue > 0
						ORDER BY
							SortOrder1 DESC,
							EndTime
					END

				EXEC msdb..sp_send_dbmail 
					@profile_name = @Mail_ProfileName,
					@recipients = @Recipient,
					@copy_recipients = @CC,
					@blind_copy_recipients = @BCC,
					@subject = @OnError_Subject, 
					@body = @BodyHTML, 
					@body_format = ''''HTML'''',
					@importance = @OnError_Importance

			END'
			
				SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Drop temp tables (mail specific)''''
		DROP TABLE #Recipient

	SET @Step = ''''EXITPOINT:''''
		EXITPOINT:

	SET @Step = ''''Drop temp tables''''
		DROP TABLE #CheckSum

	SET @Step = ''''@Duration''''
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH

SET @Step = ''''ERRORHANDLING''''
	ERRORHANDLING:
	RAISERROR (@Message, @Severity, 100)'
				
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)
				
			END

SET @Step = 'CREATE PROCEDURE spCheck_SBZ'
	RAISERROR ('70 percent', 0, 70) WITH NOWAIT

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spCheck_SBZ' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE spCheck_SBZ

@JobID int = 0,
@Rows int = NULL,
@ReturnValue bit = 0,
@GetVersion bit = 0,
@Debug bit = 0,
@Duration time(7) = ''''00:00:00'''' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC spCheck_SBZ @ReturnValue = 1, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@CallistoDatabase nvarchar(100),
	@Dimension nvarchar(100),
	@FACT_table nvarchar(150),
	@Model nvarchar(100),
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT
			@CallistoDatabase = DestinationDatabase
		FROM
			pcINTEGRATOR..[Application] A
		WHERE
			A.ETLDatabase = DB_NAME() AND
			A.ApplicationID > 0 AND
			A.SelectYN <> 0

	SET @Step = ''''TRUNCATE TABLE wrk_SBZ_Check''''
		SELECT @Deleted = COUNT(1) FROM wrk_SBZ_Check
		TRUNCATE TABLE wrk_SBZ_Check

	SET @Step = ''''Create temp tables''''
		CREATE TABLE #Dimension_Cursor_Table
			(
			Dimension nvarchar(100) COLLATE DATABASE_DEFAULT
			)'
			
				SET @SQLStatement = @SQLStatement + '

		CREATE TABLE #SBZ_Member
			(
			Label nvarchar(255) COLLATE DATABASE_DEFAULT,
			MemberId bigint
			)

		CREATE TABLE #FACT_table_Cursor_Table
			(
			FACT_table nvarchar(255) COLLATE DATABASE_DEFAULT,
			Model nvarchar(100) COLLATE DATABASE_DEFAULT
			) 

	SET @Step = ''''Fill #Dimension_Cursor_Table''''
		SET @SQLStatement = ''''
			INSERT INTO #Dimension_Cursor_Table
				(
				Dimension
				) 
			SELECT
				Dimension = D.Label 
			FROM
				'''' + @CallistoDatabase + ''''..S_Dimensions D
				INNER JOIN '''' + @CallistoDatabase + ''''.sys.tables T ON T.name = ''''''''S_DS_'''''''' + D.Label
				INNER JOIN '''' + @CallistoDatabase + ''''.sys.columns C ON C.object_id = T.object_id AND C.name = ''''''''SBZ''''''''''''
	
		EXEC (@SQLStatement)

	SET @Step = ''''DECLARE SBZ_Dimension_Cursor''''
		DECLARE SBZ_Dimension_Cursor CURSOR FOR

			SELECT Dimension FROM #Dimension_Cursor_Table ORDER BY Dimension

			OPEN SBZ_Dimension_Cursor
			FETCH NEXT FROM SBZ_Dimension_Cursor INTO @Dimension

			WHILE @@FETCH_STATUS = 0
				BEGIN
					TRUNCATE TABLE #SBZ_Member

					SET @SQLStatement = ''''INSERT INTO #SBZ_Member (Label, MemberId) SELECT Label, MemberId FROM '''' + @CallistoDatabase + ''''..S_DS_'''' + @Dimension + '''' WHERE SBZ = 1''''

					IF @Debug <> 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					IF @Debug <> 0 SELECT TempTable = ''''#SBZ_Member'''', Dimension = @Dimension, * FROM #SBZ_Member

					SET @Step = ''''Fill #FACT_table_Cursor_Table''''
						TRUNCATE TABLE #FACT_table_Cursor_Table'
			
				SET @SQLStatement = @SQLStatement + '

						SET @SQLStatement = ''''
							INSERT INTO #FACT_table_Cursor_Table
								(
								FACT_table,
								Model
								) 
							SELECT
								FACT_table = '''''''''''' + @CallistoDatabase + '''''''''''' + ''''''''.dbo.'''''''' + '''' + ''''T.[name],
								Model = REPLACE(REPLACE(T.[name], ''''''''_default_partition'''''''', ''''''''''''''''), ''''''''FACT_'''''''', '''''''''''''''')
							FROM
								'''' + @CallistoDatabase + ''''.sys.tables T 
								INNER JOIN '''' + @CallistoDatabase + ''''.sys.columns C ON C.object_id = T.object_id AND C.name = '''''''''''' + @Dimension + ''''_MemberId''''''''
							WHERE
								T.name LIKE ''''''''FACT_%''''''''''''
					
						EXEC (@SQLStatement)

					SET @Step = ''''DECLARE SBZ_FACT_table_Cursor''''
						DECLARE SBZ_FACT_table_Cursor CURSOR FOR

						SELECT
							FACT_table,
							Model
						FROM
							#FACT_table_Cursor_Table
						ORDER BY
							FACT_table

						OPEN SBZ_FACT_table_Cursor
						FETCH NEXT FROM SBZ_FACT_table_Cursor INTO @FACT_table, @Model

						WHILE @@FETCH_STATUS = 0
							BEGIN

								IF @Debug <> 0 SELECT FACT_table = @FACT_table

								SET @SQLStatement = ''''
									INSERT INTO wrk_SBZ_Check
										(
										Dimension,
										Model,
										Label,
										MemberId,
										FACT_table,
										FirstLoad,
										LatestLoad,
										Occurencies
										)
									SELECT 
										Dimension = '''''''''''' + @Dimension + '''''''''''',
										Model = '''''''''''' + @Model + '''''''''''',
										Label = SM.Label,
										MemberId = MAX(SM.MemberId),
										FACT_table = '''''''''''' + @FACT_table + '''''''''''',
										FirstLoad = MIN(F.ChangeDateTime),
										LatestLoad = MAX(F.ChangeDateTime),
										Occurencies = COUNT(1)
									FROM
										'''' + @FACT_table + '''' F
										INNER JOIN #SBZ_Member SM ON SM.MemberId = F.'''' + @Dimension + ''''_MemberId
									GROUP BY
										SM.Label
									HAVING
										COUNT(1) > 0'''''
			
				SET @SQLStatement = @SQLStatement + '

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement)
								
								FETCH NEXT FROM SBZ_FACT_table_Cursor INTO @FACT_table, @Model
							END

						CLOSE SBZ_FACT_table_Cursor
						DEALLOCATE SBZ_FACT_table_Cursor		

					FETCH NEXT FROM SBZ_Dimension_Cursor INTO @Dimension
				END

		CLOSE SBZ_Dimension_Cursor
		DEALLOCATE SBZ_Dimension_Cursor	
		
		SELECT @Inserted = COUNT(1) FROM wrk_SBZ_Check	

	SET @Step = ''''Return data''''
		IF @ReturnValue <> 0 SELECT * FROM wrk_SBZ_Check

	SET @Step = ''''Drop temp tables''''
		DROP TABLE #Dimension_Cursor_Table
		DROP TABLE  #SBZ_Member
		DROP TABLE  #FACT_table_Cursor_Table

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'
				
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)
				
			END

SET @Step = 'CREATE PROCEDURE sp_AddDays'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'sp_AddDays' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[sp_AddDays] 

 @MonthID int

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
 @DayCount int

--EXEC sp_AddDays 200502

CREATE TABLE #Days
(DayNo Int)

INSERT INTO #Days
      SELECT  1 UNION SELECT  2 UNION SELECT  3 UNION SELECT  4 UNION SELECT  5 UNION SELECT  6 UNION SELECT  7 UNION SELECT  8
UNION SELECT  9 UNION SELECT 10 UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15 UNION SELECT 16
UNION SELECT 17 UNION SELECT 18 UNION SELECT 19 UNION SELECT 20 UNION SELECT 21 UNION SELECT 22 UNION SELECT 23 UNION SELECT 24 
UNION SELECT 25 UNION SELECT 26 UNION SELECT 27 UNION SELECT 28 UNION SELECT 29 UNION SELECT 30 UNION SELECT 31


IF @MonthID % 100 IN (1, 3, 5, 7, 8, 10, 12)
	SET @DayCount = 31
ELSE IF @MonthID % 100 IN (4, 6, 9, 11)
	SET @DayCount = 30
ELSE IF @MonthID % 100 = 2
  BEGIN
	IF (@MonthID / 100) % 4 = 0
		SET @DayCount = 29
	ELSE
		SET @DayCount = 28
  END
ELSE
	SET @DayCount = 0

SELECT 
 DayID = @MonthID * 100 + DayNo,
 [DayName] = SUBSTRING(DATENAME(DW, CONVERT(datetime, CONVERT(varchar, @MonthID * 100 + DayNo), 112)),1,3) + '''', '''' + 
			DATENAME(day, CONVERT(datetime, CONVERT(varchar, @MonthID * 100 + DayNo), 112))  + '''' '''' + 
			SUBSTRING(DATENAME(MONTH, CONVERT(datetime, CONVERT(varchar, @MonthID * 100 + DayNo), 112)), 1, 3)  + '''' '''' + 
			DATENAME(year, CONVERT(datetime, CONVERT(varchar, @MonthID * 100 + DayNo), 112))
FROM
 #Days
WHERE
 DayNo <= @DayCount
ORDER BY
 DayNo

DROP TABLE #Days'
				
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)

			END

SET @Step = 'CREATE PROCEDURE spSet_HierarchyCopy'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spSet_HierarchyCopy' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSet_HierarchyCopy]
		  @Database nvarchar(100),
		  @Dimensionhierarchy nvarchar(100)

		' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
					
		AS

		SET NOCOUNT ON

		DECLARE
		@OTable nvarchar(100),
		@STable nvarchar(100)

		SET @OTable = @Database + ''''.dbo.[O_HS_'''' + @Dimensionhierarchy + '''']''''
		SET @STable = @Database + ''''.dbo.[S_HS_'''' + @Dimensionhierarchy + '''']''''

		EXEC(''''TRUNCATE TABLE '''' + @OTable)
		EXEC(''''INSERT INTO ''''  + @OTable + '''' SELECT * FROM '''' + @STable)'
				
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)				
			END

SET @Step = 'CREATE PROCEDURE spSet_MemberId'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spSet_MemberId' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSet_MemberId]
@Database nvarchar(100),
@Dimension nvarchar(100),
@Debug bit = 0
	
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
	
AS
	 
--EXEC spSet_MemberId @Database = ''''' + @CallistoDatabase + ''''', @Dimension = ''''Account'''', @Debug = 1

SET ANSI_WARNINGS OFF

DECLARE
	@MemberId bigint,
	@None bigint,
	@Label nvarchar(100),
	@SQLStatement nvarchar(max),
	@OTable nvarchar(100),
	@STable nvarchar(100),
	@Number int,
	@CounterTable nvarchar(max),
	@Insert1 nvarchar(max),
	@Insert2 nvarchar(max),
	@JobID int,
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Version nvarchar(50) = ''''' + @Version + '''''

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SET @OTable = @Database + ''''.dbo.[O_DS_'''' + @Dimension + '''']''''
		SET @STable = @Database + ''''.dbo.[S_DS_'''' + @Dimension + '''']''''
		SELECT @JobID = MAX(JobID) FROM Job

	SET @Step = ''''Create temp tables''''
		CREATE TABLE #MaxMember
			(
			MemberId bigint
			)

		CREATE TABLE #Property
			(
			[Script] [nvarchar](512) COLLATE DATABASE_DEFAULT NULL,
			[Property] [sysname] NULL,
			[DataType] [sysname] NOT NULL,
			[Size] [smallint] NOT NULL,
			[Collation] [sysname] NULL,
			[SortOrder] [int] NOT NULL
			)
		
		IF (SELECT COUNT(1) FROM sys.tables WHERE name = ''''CounterTable_'''' + @Dimension) > 0
			BEGIN
				SET @SQLStatement = ''''
					DROP TABLE [CounterTable_'''' + @Dimension + '''']''''
				EXEC (@SQLStatement)
			END'

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Handle NONE''''
		SET @SQLStatement =
		''''INSERT INTO #MaxMember
			(
			MemberId
			)
		SELECT
			MemberId = -1
		FROM
			'''' + @STable + ''''
		WHERE
			Label = ''''''''NONE'''''''' AND
			MemberId IS NULL AND
			NOT EXISTS (SELECT 1 FROM '''' + @STable + '''' WHERE MemberId = -1 OR (MemberId IS NOT NULL AND Label = ''''''''NONE''''''''))''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SELECT @None = MemberId FROM #MaxMember

		IF @None = -1
			BEGIN
				SET @SQLStatement = ''''
					UPDATE
						'''' + @STable + ''''
					SET
						MemberId = '''' + CONVERT(nvarchar, @None) + ''''
					WHERE
						Label = ''''''''NONE''''''''''''

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

	SET @Step = ''''Handle MemberId''''
		TRUNCATE TABLE #MaxMember

		SET @SQLStatement = ''''
			INSERT INTO #MaxMember
				(MemberId)
			SELECT
				MAX(MemberId)
			FROM
				'''' + @STable

			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

		SELECT @MemberId = MemberId FROM #MaxMember

		IF @MemberId <= 1000 OR @MemberId IS NULL
			SET @MemberId = 1001
		ELSE
			SET @MemberId = @MemberId + 1'

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''INSERT INTO #Property table''''
		SET @SQLStatement = ''''
		INSERT INTO #Property
			(
			[Script],
			[Property],
			[DataType],
			[Size],
			[Collation],
			[SortOrder]
			)
		SELECT
			Script = ''''''''['''''''' + C.name + ''''''''] '''''''' + Ty.name + CASE WHEN C.name = ''''''''MemberId'''''''' THEN '''''''' IDENTITY('''' + CONVERT(nvarchar(10), @MemberId) + '''',1)'''''''' ELSE '''''''''''''''' END + CASE WHEN c.collation_name IS NULL THEN '''''''''''''''' ELSE ''''''''('''''''' + CONVERT(nvarchar(10), c.max_length / 2) + '''''''') COLLATE '''''''' + c.collation_name END,
			Property = ''''''''['''''''' + C.name + '''''''']'''''''',
			DataType = Ty.name,
			Size = c.max_length,
			Collation = c.collation_name,
			SortOrder = c.column_id
		FROM
			'''' + @Database + ''''.sys.columns C
			INNER JOIN '''' + @Database + ''''.sys.tables T ON T.object_id = C.object_id AND T.name = N''''''''S_DS_'''' + @Dimension + ''''''''''''
			INNER JOIN '''' + @Database + ''''.sys.types Ty ON Ty.system_type_id = C.system_type_id AND Ty.user_type_id = C.user_type_id
		ORDER BY
			c.column_id''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = ''''INSERT INTO [CounterTable_'''' + @Dimension + '''']''''
		SELECT
			@CounterTable = ISNULL(@CounterTable, '''''''') + CHAR(13) + CHAR(10) + CHAR(9) + Script + '''','''',
			@Insert2 = ISNULL(@Insert2, '''''''') + CHAR(13) + CHAR(10) + CHAR(9) +  Property + '''',''''
		FROM
			#Property
		ORDER BY
			SortOrder

		SELECT
			@Insert1 = ISNULL(@Insert1, '''''''') + CHAR(13) + CHAR(10) + CHAR(9) + Property + '''',''''
		FROM
			#Property
		WHERE
			Property <> ''''[MemberId]''''
		ORDER BY
			SortOrder

		SET @CounterTable = SUBSTRING(@CounterTable, 1, LEN(@CounterTable) -1)
		SET @Insert1 = SUBSTRING(@Insert1, 1, LEN(@Insert1) -1)
		SET @Insert2 = SUBSTRING(@Insert2, 1, LEN(@Insert2) -1)

		IF @Debug <> 0 PRINT ''''CREATE TABLE [CounterTable_'''' + @Dimension + ''''] ('''' + @CounterTable + '''')''''
		EXEC (''''CREATE TABLE [CounterTable_'''' + @Dimension + ''''] ('''' + @CounterTable + '''')'''')'

	SET @SQLStatement = @SQLStatement + '

		SET @SQLStatement = ''''
		INSERT INTO [CounterTable_'''' + @Dimension + '''']
			(
		'''' + @Insert1 + ''''
			)
		SELECT 
		'''' + @Insert1 + ''''
		FROM
			'''' + @STable + ''''
		WHERE
			MemberId IS NULL
		ORDER BY
			Label''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = ''''INSERT INTO '''' + @STable
		SET @SQLStatement = ''''
		DELETE '''' + @STable + ''''
		WHERE
			MemberId IS NULL''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @SQLStatement = ''''
		INSERT INTO '''' + @STable + ''''
			(
		'''' + @Insert2 + ''''
			)
		SELECT 
		'''' + @Insert2 + ''''
		FROM
			[CounterTable_'''' + @Dimension + '''']
		ORDER BY
			MemberId''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = ''''INSERT INTO '''' + @OTable
		EXEC(''''TRUNCATE TABLE '''' + @OTable)
		EXEC(''''INSERT INTO ''''  + @OTable + '''' SELECT * FROM '''' + @STable)

	SET @Step = ''''Update S_Dimensions''''
		CREATE TABLE #Number
			(
			[Number] int
			)
		INSERT INTO #Number ([Number]) EXEC(''''SELECT Number = COUNT(1) FROM '''' + @Database + ''''.sys.tables WHERE name = ''''''''S_Dimensions'''''''''''')
		SELECT @Number = [Number] FROM #Number
		DROP TABLE #Number'

	SET @SQLStatement = @SQLStatement + '

		IF @Number > 0
		  BEGIN
			SET @SQLStatement =
			''''UPDATE '''' + @Database + ''''.dbo.[S_Dimensions]
			   SET [ChangeDatetime] = getdate()
			 WHERE label = '''''''''''' + @Dimension + ''''''''''''''''
			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)
		  END

	SET @Step = ''''Drop Temp tables''''
		DROP TABLE #MaxMember
		DROP TABLE #Property

		SET @SQLStatement = ''''
			DROP TABLE [CounterTable_'''' + @Dimension + '''']''''
		EXEC (@SQLStatement)
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, ''''spSet_MemberId_'''' + @Dimension, GetDate() - @StartTime, Deleted = 0, Inserted = 0, Updated = 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'
					
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)
					
				END

SET @Step = 'CREATE PROCEDURE spSet_LeafCheck'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spSet_LeafCheck' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spSet_LeafCheck]
@JobID int = 0,
@Database nvarchar(100),
@Dimension nvarchar(100),
@Hierarchy nvarchar(100) = NULL,
@DimensionTemptable nvarchar(100) = NULL,
@ParentColumn nvarchar(50) = N''''Parent'''',
@Debug bit = 0
	
' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

DECLARE
	@SQLStatement nvarchar(max),
	@MasterMemberId bigint,
	@MemberId bigint,
	@CheckID int = 0,
	@MaxCheckID int = 100,
	@HasChild bit = 0,
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Version nvarchar(50) = ''''' + @Version + '''''

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SET @DimensionTemptable = ISNULL(@DimensionTemptable, ''''#'''' + @Dimension + ''''_Members'''')
		SET @Hierarchy = ISNULL(@Hierarchy, @Dimension)

	SET @Step = ''''Create temp table #Check.''''
		CREATE TABLE #Check
			(
			[CheckID] [int] IDENTITY(1,1) NOT NULL,
			[MemberId] [bigint] NOT NULL,
			[Label] [nvarchar](50) COLLATE DATABASE_DEFAULT NOT NULL,
			[RNodeType] [nvarchar](2) COLLATE DATABASE_DEFAULT NOT NULL
			)

	SET @Step = ''''Fill temp table #LeafCheck.''''
		SET @SQLStatement = ''''
		INSERT INTO #LeafCheck
			(
			MemberId,
			HasChild
			)
		SELECT
			MemberId = D1.MemberId,
			HasChild = CONVERT(bit, 0)
		FROM
			'''' + @Database + ''''.[dbo].[S_DS_'''' + @Dimension + ''''] D1
			INNER JOIN ['''' + @DimensionTemptable + ''''] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label AND (V.['''' + @ParentColumn + ''''] IS NULL OR V.['''' + @ParentColumn + ''''] <> ''''''''-10'''''''')
			LEFT JOIN '''' + @Database + ''''.[dbo].[S_DS_'''' + @Dimension + ''''] D2 ON D2.Label = CONVERT(nvarchar(255), V.['''' + @ParentColumn + '''']) COLLATE DATABASE_DEFAULT
		WHERE
			NOT EXISTS (SELECT 1 FROM '''' + @Database + ''''.[dbo].[S_HS_'''' + @Dimension + ''''_'''' + @Hierarchy + ''''] H WHERE H.MemberId = D1.MemberId) AND
			[D1].[Synchronized] <> 0 AND
			D1.MemberId <> ISNULL(D2.MemberId, 0) AND
			D1.MemberId IS NOT NULL AND
			(D2.MemberId IS NOT NULL OR D1.Label = ''''''''All_'''''''' OR V.['''' + @ParentColumn + ''''] IS NULL) AND
			(D1.RNodeType IN (''''''''P'''''''', ''''''''PC''''''''))
		ORDER BY
			D1.Label''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)'

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create cursor to update temp table #LeafCheck.''''
		DECLARE LeafCheck_Cursor CURSOR FOR

			SELECT 
				MasterMemberId = MemberId,
				MemberId
			FROM
				#LeafCheck
			ORDER BY
				MemberId

			OPEN LeafCheck_Cursor
			FETCH NEXT FROM LeafCheck_Cursor INTO @MasterMemberId, @MemberId

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT MasterMemberId = @MasterMemberId

					WHILE @HasChild = 0 AND @CheckID <= @MaxCheckID
						BEGIN
							SET @SQLStatement = ''''
								INSERT INTO #Check 
									(
									MemberId,
									Label,
									RNodeType) 
								SELECT
									D1.MemberId,
									D1.Label,
									D1.RNodeType
								FROM 
									'''' + @Database + ''''.[dbo].[S_DS_'''' + @Dimension + ''''] D1
									INNER JOIN ['''' + @DimensionTemptable + ''''] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
									INNER JOIN '''' + @Database + ''''.[dbo].[S_DS_'''' + @Dimension + ''''] D2 ON D2.Label = CONVERT(nvarchar(255), V.['''' + @ParentColumn + '''']) COLLATE DATABASE_DEFAULT
								WHERE
									NOT EXISTS (SELECT 1 FROM '''' + @Database + ''''.[dbo].[S_HS_'''' + @Dimension + ''''_'''' + @Hierarchy + ''''] HS WHERE HS.MemberID = D1.MemberID) AND
									D2.MemberId = '''' + CONVERT(nvarchar(10), @MemberID)

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SELECT @MaxCheckID = MAX(CheckID) FROM #Check

							IF @Debug <> 0
								BEGIN
									SELECT * FROM #Check
									SELECT MasterMemberId = @MasterMemberId, MemberId = @MemberId, CheckID = @CheckID, MaxCheckID = @MaxCheckID
								END'

	SET @SQLStatement = @SQLStatement + '

							IF (SELECT COUNT(1) FROM #Check WHERE CheckID BETWEEN @CheckID AND @MaxCheckID AND RNodeType IN (''''L'''', ''''LC'''')) > 0
								BEGIN
									SET @HasChild = 1
									UPDATE #LeafCheck SET HasChild = @HasChild WHERE MemberId = @MasterMemberId
									IF @Debug <> 0 SELECT MemberId = @MasterMemberId, HasChild = @HasChild
									TRUNCATE TABLE #Check
								END
							ELSE
								BEGIN
									SET @CheckID = @CheckID + 1
									SELECT @MemberId = MemberId FROM #Check WHERE CheckID = @CheckID
								END

						END
					TRUNCATE TABLE #Check
					SET @CheckID = 0
					SET @MaxCheckID = 100
					SET @HasChild = 0
					FETCH NEXT FROM LeafCheck_Cursor INTO @MasterMemberId, @MemberId
				END

		CLOSE LeafCheck_Cursor
		DEALLOCATE LeafCheck_Cursor	

		IF @Debug <> 0 SELECT * FROM #LeafCheck ORDER BY MemberId

	SET @Step = ''''Drop the temp table''''
		DROP TABLE #Check

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, ''''spSet_LeafCheck'''' + @Dimension, GetDate() - @StartTime, Deleted = 0, Inserted = 0, Updated = 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'
					
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)
					
				END

SET @Step = 'CREATE PROCEDURE spFormGetCB_ObjectTypeBM'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGetCB_ObjectTypeBM' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spFormGetCB_ObjectTypeBM] 

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT ObjectTypeBM, [Description] = ObjectTypeName, LockedYN = CASE WHEN ObjectTypeBM = 1 THEN 1 ELSE 0 END
FROM pcINTEGRATOR..ObjectType
WHERE ObjectTypeBM & 7 > 0
UNION SELECT ObjectTypeBM = 6, [Description] = ''''Dimension, Property'''', LockedYN = 0'
				
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)

			END

SET @Step = 'CREATE PROCEDURE spFormGetCB_TimeMonth'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGetCB_TimeMonth' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spFormGetCB_TimeMonth] 

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT
	[TimeMonth] = CONVERT(int, MonthID),
    [Description] = CONVERT(nvarchar, MonthID) + '''' - '''' + [MonthName]
FROM
	(
	SELECT [MonthID] = 1, [MonthName] = ''''Jan''''
	UNION SELECT [MonthID] = 2, [MonthName] = ''''Feb''''
	UNION SELECT [MonthID] = 3, [MonthName] = ''''Mar''''
	UNION SELECT [MonthID] = 4, [MonthName] = ''''Apr''''
	UNION SELECT [MonthID] = 5, [MonthName] = ''''May''''
	UNION SELECT [MonthID] = 6, [MonthName] = ''''Jun''''
	UNION SELECT [MonthID] = 7, [MonthName] = ''''Jul''''
	UNION SELECT [MonthID] = 8, [MonthName] = ''''Aug''''
	UNION SELECT [MonthID] = 9, [MonthName] = ''''Sep''''
	UNION SELECT [MonthID] = 10, [MonthName] = ''''Oct''''
	UNION SELECT [MonthID] = 11, [MonthName] = ''''Nov''''
	UNION SELECT [MonthID] = 12, [MonthName] = ''''Dec''''
	) sub
ORDER BY
	Sub.[MonthID]'
				
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)

			END


SET @Step = 'CREATE PROCEDURE spFormGetCB_MappedObjectName'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGetCB_MappedObjectName' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE spFormGetCB_MappedObjectName

@DimensionTypeID int = NULL

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--spFormGetCB_MappedObjectName
--spFormGetCB_MappedObjectName @DimensionTypeID = -1

SELECT DISTINCT 
	MO.MappedObjectName
FROM
	[pcINTEGRATOR].[dbo].[Dimension] D
	INNER JOIN MappedObject MO ON (MO.ObjectName = D.DimensionName OR MO.DimensionTypeID = -1) AND MO.SelectYN <> 0
	INNER JOIN [pcINTEGRATOR].[dbo].[DimensionType] DT ON DT.DimensionTypeID = MO.DimensionTypeID AND DT.[MappingEnabledYN] <> 0
WHERE
	(MO.DimensionTypeID = @DimensionTypeID OR @DimensionTypeID IS NULL) AND
	D.SelectYN <> 0
ORDER BY
	MO.MappedObjectName'
				
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)
			END

SET @Step = 'CREATE PROCEDURE spFormGetCB_EntityCode'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGetCB_EntityCode' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE spFormGetCB_EntityCode

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT DISTINCT
	EntityCode = E.Entity,
	EntityName = MAX(E.Entity + '''' - '''' + E.EntityName)
FROM
	Entity E
WHERE
	E.SelectYN <> 0
GROUP BY
	E.Entity
ORDER BY
	E.Entity'
				
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)
			END

SET @Step = 'CREATE PROCEDURE spFormGetCB_StringTypeBM'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGetCB_StringTypeBM' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE spFormGetCB_StringTypeBM

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

      SELECT StringTypeBM = 1, StringTypeName = ''''Code''''
UNION SELECT StringTypeBM = 2, StringTypeName = ''''Text''''
UNION SELECT StringTypeBM = 3, StringTypeName = ''''Code & Text''''
'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)
			END

SET @Step = 'CREATE PROCEDURE spFormGetCB_Command'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGetCB_Command' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE spFormGetCB_Command

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT
	Command = pr.name
FROM
	sys.procedures pr 
	INNER JOIN sys.parameters p on pr.object_id = p.object_id AND p.name = ''''@JobID''''
WHERE
	pr.name <> ''''spIU_Load_All''''
ORDER BY
	pr.name'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)
			END

SET @Step = 'CREATE PROCEDURE spFormGet_Load'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGet_Load' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE spFormGet_Load

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT 
	LoadID,
	LoadTypeBM,
	SortOrder,
	Command,
	SelectYN
FROM
	[Load]
ORDER BY
	LoadTypeBM,
	SortOrder'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)
			END

SET @Step = 'CREATE PROCEDURE spFormGet_CheckSumLog'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGet_CheckSumLog' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE spFormGet_CheckSumLog

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT 
	CSL.JobID,
	CS.CheckSumName,
	CS.CheckSumDescription,
	CS.CheckSumReport,
	CSL.CheckSumValue,
	CSL.EndTime
FROM
	CheckSumLog CSL
	INNER JOIN [CheckSum] CS ON CS.CheckSumID = CSL.CheckSumID
ORDER BY
	CheckSumLogID DESC'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)
			END

SET @Step = 'CREATE PROCEDURE spFormGet_JobLog'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGet_JobLog' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE spFormGet_JobLog

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT 
	[JobID],
	[ProcedureName],
	[StartTime],
	[Duration],
	[Deleted],
	[Inserted],
	[Updated],
	[ErrorNumber],
	[ErrorSeverity],
	[ErrorState],
	[ErrorProcedure],
	[ErrorStep],
	[ErrorLine],
	[ErrorMessage]
FROM
	JobLog
ORDER BY
	JobLogID DESC'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)
			END

SET @Step = 'CREATE PROCEDURE spFormGetCB_ModelBM'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGetCB_ModelBM' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spFormGetCB_ModelBM] 

@ApplicationID int = ' + CONVERT(nvarchar(10), @ApplicationID) + ',
@ObjectName nvarchar(100) = NULL,
@DimensionTypeID int = NULL,
@ObjectTypeBM int = NULL

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC [spFormGetCB_ModelBM] @ObjectName = ''''AccountReceivable'''', @DimensionTypeID = -2, @ObjectTypeBM = 1
--EXEC [spFormGetCB_ModelBM] @ObjectName = ''''BusinessProcess'''', @DimensionTypeID = 2, @ObjectTypeBM = 2
--EXEC [spFormGetCB_ModelBM] @ObjectName = ''''LineItem'''', @DimensionTypeID = 19, @ObjectTypeBM = 2
--EXEC [spFormGetCB_ModelBM] @ObjectName = ''''Customer'''', @DimensionTypeID = -1, @ObjectTypeBM = 2
--EXEC [spFormGetCB_ModelBM] @ObjectName = ''''Paid_Time'''', @DimensionTypeID = 7, @ObjectTypeBM = 4
--EXEC [spFormGetCB_ModelBM]

DECLARE
	@Version nvarchar(50)

DECLARE @ModelBM TABLE
 (
 ModelBM int,
 ModelName nvarchar(100)
 )

EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT

CREATE TABLE #Model (ModelID int)

IF @ObjectName IS NOT NULL AND @DimensionTypeID IS NOT NULL
	BEGIN
		IF @ObjectTypeBM & 1 > 0 AND @DimensionTypeID = -2
			INSERT INTO #Model
				(ModelID) 
			SELECT
				BM.ModelID
			FROM
				pcINTEGRATOR..[Model] BM
				INNER JOIN pcINTEGRATOR..[Model] M ON M.BaseModelID = BM.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
			WHERE
				BM.ModelID < 0 AND 
				BM.ModelName = @ObjectName AND 
				BM.Introduced < @Version AND 
				BM.SelectYN <> 0

		ELSE IF @ObjectTypeBM & 2 > 0 AND @DimensionTypeID <> -1
			INSERT INTO #Model
				(ModelID) 
			SELECT
				MD.ModelID
			FROM
				pcINTEGRATOR..[Dimension] D
				INNER JOIN pcINTEGRATOR..[Model_Dimension] MD ON MD.DimensionID = D.DimensionID AND MD.Introduced < @Version AND MD.SelectYN <> 0
			WHERE
				D.DimensionTypeID = @DimensionTypeID AND
				D.DimensionName = @ObjectName AND 
				D.Introduced < @Version AND 
				D.SelectYN <> 0

		ELSE IF @ObjectTypeBM & 2 > 0 AND @DimensionTypeID = -1
			INSERT INTO #Model
				(ModelID) 
			SELECT
				BM.ModelID
			FROM
				pcINTEGRATOR..Model M
				INNER JOIN pcINTEGRATOR..Model BM ON BM.ModelID = M.BaseModelID AND BM.OptFinanceDimYN <> 0 AND BM.Introduced < @Version AND BM.SelectYN <> 0
			WHERE
				M.ApplicationID = @ApplicationID AND
				M.SelectYN <> 0
	END
ELSE
	INSERT INTO #Model
		(ModelID) 
	SELECT
		BM.ModelID
	FROM
		pcINTEGRATOR..Model M
		INNER JOIN pcINTEGRATOR..Model BM ON BM.ModelID = M.BaseModelID AND BM.ApplicationID = 0 AND BM.Introduced < @Version AND BM.SelectYN <> 0
	WHERE
		M.ApplicationID = @ApplicationID AND
		M.SelectYN <> 0

INSERT INTO @ModelBM
	(
	ModelBM,
	ModelName
	)
SELECT
	BM.ModelBM,
	BM.ModelName
FROM
	pcINTEGRATOR..Model M
	INNER JOIN pcINTEGRATOR..Model BM ON BM.ModelID = M.BaseModelID AND BM.ApplicationID = 0 AND BM.Introduced < @Version AND BM.SelectYN <> 0
	INNER JOIN #Model ON #Model.ModelID = BM.ModelID
WHERE
	M.ApplicationID = @ApplicationID AND
	M.SelectYN <> 0
ORDER BY
	BM.ModelName

;WITH CTE (ModelBM, ModelName)
    AS
    (
    SELECT ModelBM,
           ModelName = Cast(ModelName as nvarchar(max)) + '''', ''''
    FROM @ModelBM
    UNION ALL
    SELECT ModelBM = m.ModelBM + cte.ModelBM,
           ModelName = cte.ModelName + m.ModelName + '''', ''''
    FROM @ModelBM m JOIN cte ON m.ModelBM > cte.ModelBM
    )

SELECT
	ModelBM,
	[Description]
FROM
	(
	SELECT ModelBM = 0, [Description] = ''''None'''', SortOrder = ''''0''''
	UNION SELECT ModelBM, [Description] = LEFT(ModelName, LEN(ModelName) - 1), SortOrder =  LEFT(ModelName, LEN(ModelName) - 1) FROM CTE
	) sub
ORDER BY
	SortOrder

DROP TABLE #Model'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)
			END

SET @Step = 'CREATE PROCEDURE spFormGetCB_AccountType'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGetCB_AccountType' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spFormGetCB_AccountType] 

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT
	AccountType
FROM
	AccountType
ORDER BY
	AccountType'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			END

SET @Step = 'CREATE PROCEDURE spFormGet_ClosedPeriod'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGet_ClosedPeriod' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spFormGet_ClosedPeriod]

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT cp.SourceID,
	cp.EntityCode,
	cp.TimeFiscalYear,
	cp.TimeFiscalPeriod,
	cp.TimeYear,
	cp.TimeMonth,
	cp.BusinessProcess,
	cp.ClosedPeriod,
	cp.ClosedPeriod_Counter,
	cp.UpdateYN,
	cp.Updated,
	cp.UpdatedBy,
	s.SourceName
FROM 
	ClosedPeriod cp
	INNER JOIN pcINTEGRATOR..Source s ON s.SourceID = cp.SourceID
'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)
			END

SET @Step = 'CREATE PROCEDURE spFormGet_Entity'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGet_Entity' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spFormGet_Entity] 

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT
	E.[SourceID],
	S.[SourceName],
	E.[EntityCode],
	E.[Entity],
	E.[EntityName],
	E.[Currency],
	E.[EntityPriority],
	E.[SelectYN]
FROM
	[Entity] E
	INNER JOIN pcINTEGRATOR..Source S ON S.SourceID = E.SourceID
'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			END

SET @Step = 'CREATE PROCEDURE spFormGet_BudgetSelection'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGet_BudgetSelection' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spFormGet_BudgetSelection] 

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT
	BS.[SourceID],
	S.[SourceName],
    BS.[EntityCode],
    BS.[BudgetCode],
    BS.[Scenario],
    BS.[SelectYN]
FROM
	[BudgetSelection] BS
	INNER JOIN pcINTEGRATOR..Source S ON S.SourceID = BS.SourceID'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			END

SET @Step = 'CREATE PROCEDURE spFormGet_MappedObjectModel'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGet_MappedObjectModel' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spFormGet_MappedObjectModel] 

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

CREATE TABLE #Model
	(
	ModelID		int IDENTITY(1,1) NOT NULL PRIMARY KEY,
	ModelBM		int,
	ModelName	nvarchar(100) COLLATE DATABASE_DEFAULT
	)

SET NOCOUNT ON

INSERT INTO #Model
	(
	ModelBM,
	ModelName
	)
SELECT 
	ModelBM,
	ModelName = MappedObjectName
FROM
	MappedObject
WHERE
	ObjectTypeBM & 1 > 0 AND
	DimensionTypeID = -2 AND
	SelectYN <> 0
ORDER BY
	ModelBM

SELECT
	ModelID,
	ModelBM,
	ModelName
FROM
	#Model

DROP TABLE #Model'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)
			END

SET @Step = 'CREATE PROCEDURE spFormGet_MemberSelection'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGet_MemberSelection' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spFormGet_MemberSelection] 

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT
	[DimensionID] = MS.[DimensionID],
	[DimensionName] = MO.MappedObjectName,
	[Label] = MS.[Label],
	[Description] = M.[Description],
	[SelectYN] = MS.[SelectYN]
FROM
	[MemberSelection] MS
	INNER JOIN pcINTEGRATOR.[dbo].Dimension D ON D.DimensionID = MS.DimensionID
	INNER JOIN MappedObject MO ON MO.Entity = ''''-1'''' AND MO.ObjectName = D.DimensionName
	INNER JOIN pcINTEGRATOR.[dbo].Member M ON M.DimensionID = MS.DimensionID AND M.Label = MS.Label'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			END

SET @Step = 'CREATE PROCEDURE spFormGetCB_Entity'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGetCB_Entity' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spFormGetCB_Entity] 

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT DISTINCT
	Entity = E.Entity,
	EntityName = MAX(E.Entity + '''' - '''' + E.EntityName)
FROM
	Entity E
WHERE
	E.SelectYN <> 0
GROUP BY
	E.Entity
ORDER BY
	E.Entity'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			END

SET @Step = 'CREATE PROCEDURE spFormGet_AccountType_Translate'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormGet_AccountType_Translate' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spFormGet_AccountType_Translate] 

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SELECT 
	[CategoryID],
	[Description],
	[Hint],
	[AccountType]
FROM
	[AccountType_Translate]
ORDER BY
	[CategoryID]'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			END


SET @Step = 'CREATE PROCEDURE spFormUpd_MappedObjectName_Advanced'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFormUpd_MappedObjectName_Advanced' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE spFormUpd_MappedObjectName_Advanced

@Old_MappedObjectName nvarchar(100),
@New_MappedObjectName nvarchar(100)

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

UPDATE
	MappedObject
SET
	MappedObjectName = @New_MappedObjectName
WHERE
	MappedObjectName = @Old_MappedObjectName'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			END

SET @Step = 'CREATE PROCEDURE spCreate_Fact_View'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spCreate_Fact_View' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spCreate_Fact_View] 

	@CallistoDatabase nvarchar(100) = ''''' + @CallistoDatabase + ''''',
	@Debug bit = 0,
	@JobID int = 0,
	@Rows int = NULL,
	@GetVersion bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC [spCreate_Fact_View] @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Action nvarchar(10),
	@SQLStatement nvarchar(MAX),
	@SQLStatementSelect nvarchar(MAX),
	@SQLStatementFrom nvarchar(MAX),
	@Model nvarchar(100),
	@Dimension nvarchar(100),
	@Property nvarchar(100),
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

    SET @Step = ''''Create TempTables''''
		CREATE TABLE #Object
			(
			ObjectType nvarchar(100) COLLATE DATABASE_DEFAULT,
			ObjectName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		TRUNCATE TABLE #Object
		SET @SQLStatement = ''''SELECT ObjectType = ''''''''View'''''''', ObjectName = v.name FROM '''' + @CallistoDatabase + ''''.sys.views v''''
		INSERT INTO #Object (ObjectType, ObjectName) EXEC (@SQLStatement)

		CREATE TABLE #ModelDimension
			(
			Model nvarchar(100) COLLATE DATABASE_DEFAULT,
			Dimension nvarchar(100) COLLATE DATABASE_DEFAULT
			)

        SET @SQLStatement = ''''
            SELECT
                Model,
                Dimension
            FROM
				'''' + @CallistoDatabase + ''''.dbo.ModelDimensions''''

        INSERT INTO #ModelDimension EXEC (@SQLStatement)

        IF @Debug <> 0 SELECT * FROM #ModelDimension'
SET @SQLStatement = @SQLStatement + '
		CREATE TABLE #DimensionProperty
			(
			Dimension nvarchar(100) COLLATE DATABASE_DEFAULT,
			Property nvarchar(100) COLLATE DATABASE_DEFAULT
			)

        SET @SQLStatement = ''''
			SELECT
				Dimension = SUBSTRING(T.name, 4, LEN(T.name) - 3),
				Property = SUBSTRING(C.name, 1, charindex(''''''''_MemberId'''''''', C.name) - 1)
			FROM 
				'''' + @CallistoDatabase + ''''.sys.columns C
				INNER JOIN '''' + @CallistoDatabase + ''''.sys.tables T ON T.object_id = C.object_id AND T.[name] LIKE ''''''''DS_%''''''''
			WHERE
				C.[name] LIKE ''''''''%_MemberId''''''''''''

        INSERT INTO #DimensionProperty EXEC (@SQLStatement)

        IF @Debug <> 0 SELECT * FROM #DimensionProperty

	SET @Step = ''''Create Fact_View_Model_Cursor''''

		DECLARE Fact_View_Model_Cursor CURSOR FOR

			SELECT DISTINCT
				Model
			FROM
				#ModelDimension  

			OPEN Fact_View_Model_Cursor
			FETCH NEXT FROM Fact_View_Model_Cursor INTO @Model

			WHILE @@FETCH_STATUS = 0
			BEGIN

				SET @Step = ''''Check existence of view''''
					IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = ''''View'''' AND ObjectName = ''''vw_FACT_'''' + @Model) = 0 SET @Action = ''''CREATE'''' ELSE SET @Action = ''''ALTER''''

                SET @SQLStatementSelect = ''''
'''' + @Action + '''' VIEW [dbo].[vw_FACT_'''' + @Model + ''''] AS 
	SELECT''''

				SET @SQLStatementFrom = ''''
	FROM
		[FACT_'''' + @Model + ''''_default_partitiON] F''''

				SET @Step = ''''Create Fact_View_Dimension_Cursor''''

                DECLARE Fact_View_Dimension_Cursor CURSOR FOR

                    SELECT DISTINCT
						Dimension
                    FROM
						#ModelDimension 
                    WHERE
						Model = @Model 
                    ORDER BY
						Dimension

                    OPEN Fact_View_Dimension_Cursor
                    FETCH NEXT FROM Fact_View_Dimension_Cursor INTO @Dimension'
SET @SQLStatement = @SQLStatement + '

                    WHILE @@FETCH_STATUS = 0
						BEGIN
							SET @SQLStatementSelect = @SQLStatementSelect + ''''
		['''' + @Dimension + ''''] = ISNULL(['''' + @Dimension + ''''].[Label], ''''''''''''''''NONE''''''''''''''''),''''

		                SET @Step = ''''Create Fact_View_Property_Cursor''''

						DECLARE Fact_View_Property_Cursor CURSOR FOR

							SELECT DISTINCT
								Property
							FROM
								#DimensionProperty 
							WHERE
								Dimension = @Dimension
							ORDER BY
								Property

							OPEN Fact_View_Property_Cursor
							FETCH NEXT FROM Fact_View_Property_Cursor INTO @Property

							WHILE @@FETCH_STATUS = 0
								BEGIN
									SET @SQLStatementSelect = @SQLStatementSelect + ''''
		['''' + @Dimension + ''''_'''' + @Property + ''''] = ISNULL(['''' + @Dimension + ''''].['''' +  @Property + ''''], ''''''''''''''''NONE''''''''''''''''),''''

									IF @Debug <> 0 SELECT Dimension = @Dimension, Property = @Property
                                     
									FETCH NEXT FROM Fact_View_Property_Cursor INTO @Property
								END

							CLOSE Fact_View_Property_Cursor
							DEALLOCATE Fact_View_Property_Cursor 

							SET @SQLStatementFrom = @SQLStatementFrom + ''''
		LEFT JOIN [DS_'''' + @Dimension + ''''] ['''' + @Dimension + ''''] ON ['''' + @Dimension + ''''].MemberId = F.['''' + @Dimension + ''''_MemberId]''''

							IF @Debug <> 0 SELECT Dimension = @Dimension
                                     
							FETCH NEXT FROM Fact_View_Dimension_Cursor INTO @Dimension
						END

                    CLOSE Fact_View_Dimension_Cursor
                    DEALLOCATE Fact_View_Dimension_Cursor'
SET @SQLStatement = @SQLStatement + ' 

				SET @SQLStatementSelect = @SQLStatementSelect + ''''
		['''' + @Model + ''''_Value] = ISNULL(F.['''' + @Model + ''''_Value], 0),
		[ChangeDatetime] = ISNULL(F.[ChangeDatetime], GetDate()),
		[Userid] = ISNULL(F.[Userid], suser_name())''''

                SET @SQLStatement = @SQLStatementSelect + @SQLStatementFrom

                IF @Debug <> 0 PRINT @SQLStatement 

				SET @SQLStatement = ''''EXEC '''' + @CallistoDatabase + ''''.dbo.sp_executesql N'''''''''''' + @SQLStatement + ''''''''''''''''
				EXEC (@SQLStatement)

                IF @Debug <> 0 PRINT @SQLStatement
                FETCH NEXT FROM Fact_View_Model_Cursor INTO @Model
			END

			CLOSE Fact_View_Model_Cursor
			DEALLOCATE Fact_View_Model_Cursor    

    SET @Step = ''''Drop TempTables''''
        DROP TABLE #Object
        DROP TABLE #ModelDimension
		DROP TABLE #DimensionProperty

    SET @Step = ''''Set @Duration''''          
        SET @Duration = GetDate() - @StartTime

    SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'
				
				IF @Debug <> 0
					PRINT @SQLStatement 
				ELSE 
					BEGIN
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
						EXEC (@SQLStatement)
					END

			  END


SET @Step = 'CREATE PROCEDURE spIU_0000_Report'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spIU_0000_Report' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spIU_0000_Report]

@JobID int = 0,
@ApplicationID int = ' + CONVERT(nvarchar(10), @ApplicationID) + ',
@Rows int = NULL,
@GetVersion bit = 0,
@Debug bit = 0,
@Duration time(7) = ''''00:00:00'''' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
					
AS

SET ANSI_WARNINGS OFF

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Execute SP''''
		EXEC pcINTEGRATOR..[spCreate_Canvas_Report] @ApplicationID = @ApplicationID, @Debug = @Debug, @Deleted = @Deleted OUT, @Inserted = @Inserted OUT, @Updated = @Updated OUT
		
	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'
				
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)

			END




SET @Step = 'CREATE PROCEDURE spCreate_Canvas_Export_Financials'
	RAISERROR ('80 percent', 0, 80) WITH NOWAIT

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spCreate_Canvas_Export_Financials' AND DatabaseName = @ETLDatabase) = 0 AND @EpicorErpYN <> 0
			BEGIN

				SELECT
					@SourceID = MAX(S.SourceID)
				FROM
					[Application] A
					INNER JOIN [Model] M ON M.ApplicationID = A.ApplicationID AND M.BaseModelID = -7
					INNER JOIN [Source] S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
					INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeFamilyID = 1
				WHERE
					A.ApplicationID = @ApplicationID AND
					A.SelectYN <> 0

				IF @SourceID IS NOT NULL
					BEGIN

						SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spCreate_Canvas_Export_Financials] 

	@CallistoDatabase nvarchar(100) = ''''' + @CallistoDatabase + ''''',
	@ETLDatabase nvarchar(100) = ''''' + REPLACE(REPLACE(@ETLDatabase, '[', ''), ']', '') + ''''',
	@pcINTEGRATOR nvarchar(100) = ''''pcINTEGRATOR'''',
	@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
	@Debug bit = 0,
	@JobID int = 0,
	@Rows int = NULL,
	@GetVersion bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC [spCreate_Canvas_Export_Financials] @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@Action nvarchar(10),
	@SegmentName nvarchar(50),
	@SegmentCode nvarchar(50),
	@MappedObjectName nvarchar(50),
	@TotalEntityCount int,
	@EntityCount int,
	@MappedObjectNameCount int,
	@SQLBalanceAcct nvarchar(max) = '''''''',
	@SQLSegmentList nvarchar(max),
	@SQLMixedString nvarchar(max),
	@SQLMixedWhereString nvarchar(max),
	@SQLStatement nvarchar(max),
	@SQLStatement1 nvarchar(max),
	@SQLStatement2 nvarchar(max),
	@SQLWhere nvarchar(max) = '''''''',
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END'
SET @SQLStatement = @SQLStatement + '

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

    SET @Step = ''''Create TempTables''''
		CREATE TABLE #Object
			(
			ObjectType nvarchar(100) COLLATE DATABASE_DEFAULT,
			ObjectName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		TRUNCATE TABLE #Object
		SET @SQLStatement = ''''SELECT ObjectType = ''''''''Procedure'''''''', ObjectName = p.name FROM '''' + @CallistoDatabase + ''''.sys.procedures p''''
		INSERT INTO #Object (ObjectType, ObjectName) EXEC (@SQLStatement)

		CREATE TABLE #SegmentCount
			(
			SegmentCode nvarchar(50) COLLATE DATABASE_DEFAULT,
			EntityCount int,
			MappedObjectNameCount int
			)

		CREATE TABLE #MappedObjectName
			(
			SegmentCode nvarchar(50) COLLATE DATABASE_DEFAULT,
			MappedObjectName nvarchar(50) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #MixedSetup_Cursor_Table
			(
			SegmentCode nvarchar(50) COLLATE DATABASE_DEFAULT,
			MappedObjectName nvarchar(50) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #Entity
			(
			SegmentCode nvarchar(50) COLLATE DATABASE_DEFAULT,
			MappedObjectName nvarchar(50) COLLATE DATABASE_DEFAULT,
			Entity nvarchar(50) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #TotalEntityCount (TotalEntityCount int)
		SET @SQLStatement = ''''
		INSERT INTO #TotalEntityCount (TotalEntityCount) SELECT TotalEntityCount = COUNT(DISTINCT EntityCode) FROM ['''' + @ETLDatabase + ''''].[dbo].[FinancialSegment] WHERE SourceID = '''' + CONVERT(nvarchar(10), @SourceID)
		EXEC (@SQLStatement)
		SELECT @TotalEntityCount = TotalEntityCount FROM #TotalEntityCount
		DROP TABLE #TotalEntityCount'

SET @SQLStatement = @SQLStatement + '

		IF @Debug <> 0 SELECT TotalEntityCount = @TotalEntityCount

    SET @Step = ''''Run SegmentCode_Cursor''''
		SET @SQLSegmentList = ''''''''

	DECLARE SegmentCode_Cursor CURSOR FOR

	SELECT
		sub.SegmentName,
		sub.SegmentCode
	FROM
		(
			  SELECT SegmentName = ''''SegName1'''', SegmentCode = ''''SegValue1'''', SortOrder = 1
		UNION SELECT SegmentName = ''''SegName2'''', SegmentCode = ''''SegValue2'''', SortOrder = 2
		UNION SELECT SegmentName = ''''SegName3'''', SegmentCode = ''''SegValue3'''', SortOrder = 3
		UNION SELECT SegmentName = ''''SegName4'''', SegmentCode = ''''SegValue4'''', SortOrder = 4
		UNION SELECT SegmentName = ''''SegName5'''', SegmentCode = ''''SegValue5'''', SortOrder = 5
		UNION SELECT SegmentName = ''''SegName6'''', SegmentCode = ''''SegValue6'''', SortOrder = 6
		UNION SELECT SegmentName = ''''SegName7'''', SegmentCode = ''''SegValue7'''', SortOrder = 7
		UNION SELECT SegmentName = ''''SegName8'''', SegmentCode = ''''SegValue8'''', SortOrder = 8
		UNION SELECT SegmentName = ''''SegName9'''', SegmentCode = ''''SegValue9'''', SortOrder = 9
		UNION SELECT SegmentName = ''''SegName10'''', SegmentCode = ''''SegValue10'''', SortOrder = 10
		UNION SELECT SegmentName = ''''SegName11'''', SegmentCode = ''''SegValue11'''', SortOrder = 11
		UNION SELECT SegmentName = ''''SegName12'''', SegmentCode = ''''SegValue12'''', SortOrder = 12
		UNION SELECT SegmentName = ''''SegName13'''', SegmentCode = ''''SegValue13'''', SortOrder = 13
		UNION SELECT SegmentName = ''''SegName14'''', SegmentCode = ''''SegValue14'''', SortOrder = 14
		UNION SELECT SegmentName = ''''SegName15'''', SegmentCode = ''''SegValue15'''', SortOrder = 15
		UNION SELECT SegmentName = ''''SegName16'''', SegmentCode = ''''SegValue16'''', SortOrder = 16
		UNION SELECT SegmentName = ''''SegName17'''', SegmentCode = ''''SegValue17'''', SortOrder = 17
		UNION SELECT SegmentName = ''''SegName18'''', SegmentCode = ''''SegValue18'''', SortOrder = 18
		UNION SELECT SegmentName = ''''SegName19'''', SegmentCode = ''''SegValue19'''', SortOrder = 19
		UNION SELECT SegmentName = ''''SegName20'''', SegmentCode = ''''SegValue20'''', SortOrder = 20
		) sub
	ORDER BY
		sub.SortOrder

		OPEN SegmentCode_Cursor
		FETCH NEXT FROM SegmentCode_Cursor INTO @SegmentName, @SegmentCode

		WHILE @@FETCH_STATUS = 0
			BEGIN
			    SET @Step = ''''Run SegmentCode_Cursor SegmentCode = '''' + @SegmentCode'
SET @SQLStatement = @SQLStatement + '

				SET @SQLStatement = ''''
				INSERT INTO #SegmentCount
					(
					SegmentCode,
					EntityCount,
					MappedObjectNameCount
					)
				SELECT
					SegmentCode = '''''''''''' + @SegmentCode + '''''''''''',
					EntityCount = COUNT(DISTINCT FS.EntityCode),
					MappedObjectNameCount = COUNT(DISTINCT MappedObjectName) 
				FROM
					['''' + @ETLDatabase + ''''].[dbo].[FinancialSegment] FS
					INNER JOIN ['''' + @ETLDatabase + ''''].[dbo].[MappedObject] MO ON MO.DimensionTypeID IN (-1, 1) AND MO.ObjectTypeBM & 2 > 0 AND (MO.ObjectName = FS.SegmentName OR (MO.ObjectName = ''''''''Account'''''''' AND FS.DimensionTypeID = 1))
				WHERE
					FS.SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''' AND
					SegmentCode = '''''''''''' + @SegmentCode + ''''''''''''''''

				EXEC (@SQLStatement)

				SELECT 
					@EntityCount = EntityCount,
					@MappedObjectNameCount = MappedObjectNameCount
				FROM
					#SegmentCount
				WHERE
					SegmentCode = @SegmentCode

				IF @Debug <> 0 SELECT SegmentCode = @SegmentCode, EntityCount = @EntityCount, MappedObjectNameCount = @MappedObjectNameCount

				--Not defined
				IF @MappedObjectNameCount = 0
					BEGIN
						SET @Step = ''''Run SegmentCode_Cursor SegmentCode = '''' + @SegmentCode + '''', Not defined''''
						SELECT @SQLSegmentList = @SQLSegmentList + '''','''' + CHAR(13) + CHAR(10) + CHAR(9) + @SegmentName + '''' = ISNULL(seg.'''' + @SegmentCode + '''', ''''''''''''''''''''''''''''''''),'''' + CHAR(13) + CHAR(10) + CHAR(9) + @SegmentCode + '''' = ''''''''''''''''''''''''''''''''''''
					END

				--All Entities equally defined
				ELSE IF @TotalEntityCount = @EntityCount AND @MappedObjectNameCount = 1
					BEGIN
						SET @Step = ''''Run SegmentCode_Cursor SegmentCode = '''' + @SegmentCode + '''', All Entities equally defined''''
						SET @SQLStatement = ''''
						INSERT INTO #MappedObjectName
							(
							SegmentCode,
							MappedObjectName
							)
						SELECT
							SegmentCode = '''''''''''' + @SegmentCode + '''''''''''',
							MappedObjectName = MAX(MO.MappedObjectName) 
						FROM
							['''' + @ETLDatabase + ''''].[dbo].[FinancialSegment] FS
							INNER JOIN ['''' + @ETLDatabase + ''''].[dbo].[MappedObject] MO ON MO.DimensionTypeID IN (-1, 1) AND MO.ObjectTypeBM & 2 > 0 AND (MO.ObjectName = FS.SegmentName COLLATE DATABASE_DEFAULT OR (MO.ObjectName = ''''''''Account'''''''' AND FS.DimensionTypeID = 1))
						WHERE
							FS.SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''' AND
							SegmentCode = '''''''''''' + @SegmentCode + ''''''''''''''''

						EXEC (@SQLStatement)'
SET @SQLStatement = @SQLStatement + '

						SELECT
							@MappedObjectName = MappedObjectName
						FROM
							#MappedObjectName
						WHERE
							SegmentCode = @SegmentCode

						SELECT @SQLSegmentList = @SQLSegmentList + '''','''' + CHAR(13) + CHAR(10) + CHAR(9) + @SegmentName + '''' = ISNULL(seg.'''' + @SegmentCode + '''', '''''''''''''''''''''''''''''''')''''
						SELECT @SQLSegmentList = @SQLSegmentList + '''','''' + CHAR(13) + CHAR(10) + CHAR(9) + @SegmentCode + '''' = CASE WHEN F.'''' + @MappedObjectName + '''' = ''''''''''''''''NONE'''''''''''''''' THEN '''''''''''''''''''''''''''''''' ELSE F.'''' + @MappedObjectName + '''' END''''
						
						SELECT @SQLWhere = @SQLWhere + '''' AND'''' + CHAR(13) + CHAR(10) + CHAR(9) + ''''(seg.'''' + @SegmentCode + '''' = @'''' + @SegmentName + '''' OR @'''' + @SegmentName + '''' = ''''''''''''''''-1'''''''''''''''')''''
						SELECT @SQLWhere = @SQLWhere + '''' AND'''' + CHAR(13) + CHAR(10) + CHAR(9) + ''''(CASE WHEN F.'''' + @MappedObjectName + '''' = ''''''''''''''''NONE'''''''''''''''' THEN '''''''''''''''''''''''''''''''' ELSE F.'''' + @MappedObjectName + '''' END = @'''' + @SegmentCode + '''' OR @'''' + @SegmentCode + '''' = ''''''''''''''''-1'''''''''''''''')''''
					END

				--Entities differently defined
				ELSE
					BEGIN
						SET @Step = ''''Run SegmentCode_Cursor SegmentCode = '''' + @SegmentCode + '''', Entities differently defined''''
						SET @SQLMixedString = NULL
						SET @SQLMixedWhereString = NULL

						SET @SQLStatement = ''''
						INSERT INTO #MixedSetup_Cursor_Table
							(
							SegmentCode,
							MappedObjectName
							)
						SELECT DISTINCT
							SegmentCode = '''''''''''' + @SegmentCode + '''''''''''',
							MO.MappedObjectName
						FROM
							['''' + @ETLDatabase + ''''].[dbo].[FinancialSegment] FS
							INNER JOIN ['''' + @ETLDatabase + ''''].[dbo].[Entity] E ON E.SourceID = FS.SourceID AND E.EntityCode = FS.EntityCode AND E.SelectYN <> 0
							INNER JOIN ['''' + @ETLDatabase + ''''].[dbo].[MappedObject] MO ON MO.Entity = E.Entity AND MO.DimensionTypeID = -1 AND MO.ObjectTypeBM & 2 > 0 AND MO.ObjectName = FS.SegmentName
						WHERE
							FS.SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''' AND
							SegmentCode = '''''''''''' + @SegmentCode + ''''''''''''
						ORDER BY
							MO.MappedObjectName''''

						EXEC (@SQLStatement)

						DECLARE MixedSetup_Cursor CURSOR FOR
							SELECT DISTINCT
								MappedObjectName
							FROM
								#MixedSetup_Cursor_Table
							WHERE
								SegmentCode = @SegmentCode
							ORDER BY
								MappedObjectName

							OPEN MixedSetup_Cursor
							FETCH NEXT FROM MixedSetup_Cursor INTO @MappedObjectName'
SET @SQLStatement = @SQLStatement + '

							WHILE @@FETCH_STATUS = 0
								BEGIN

									SET @SQLMixedString = CASE WHEN @SQLMixedString IS NULL THEN '''''''' ELSE @SQLMixedString + '''' + '''' END + ''''CASE WHEN seg.Entity IN (''''
									SET @SQLMixedWhereString = CASE WHEN @SQLMixedWhereString IS NULL THEN ''''('''' ELSE @SQLMixedWhereString + '''' + '''' END + ''''CASE WHEN seg.Entity IN (''''

									SET @SQLStatement = ''''

									INSERT INTO #Entity
										(
										SegmentCode,
										MappedObjectName,
										Entity
										)
									SELECT
										SegmentCode = '''''''''''' + @SegmentCode + '''''''''''',
										MappedObjectName = N'''''''''''' + @MappedObjectName + '''''''''''',
										E.Entity
									FROM
										['''' + @ETLDatabase + ''''].[dbo].[FinancialSegment] FS
										INNER JOIN ['''' + @ETLDatabase + ''''].[dbo].[Entity] E ON E.SourceID = FS.SourceID AND E.EntityCode = FS.EntityCode AND E.SelectYN <> 0
										INNER JOIN ['''' + @ETLDatabase + ''''].[dbo].[MappedObject] MO ON MO.Entity = E.Entity AND MO.DimensionTypeID = -1 AND MO.ObjectTypeBM & 2 > 0 AND MO.ObjectName = FS.SegmentName
									WHERE
										FS.SourceID = '''' + CONVERT(nvarchar, @SourceID) + '''' AND
										SegmentCode = '''''''''''' + @SegmentCode + '''''''''''' AND
										MO.MappedObjectName = N'''''''''''' + @MappedObjectName + ''''''''''''
									ORDER BY
										E.Entity''''

									EXEC (@SQLStatement)

									SELECT
										@SQLMixedString = @SQLMixedString + '''''''''''''''''''''''' + Entity + '''''''''''''''''''''''' + '''', '''',
										@SQLMixedWhereString = @SQLMixedWhereString + '''''''''''''''''''''''' + Entity + '''''''''''''''''''''''' + '''', ''''
									FROM
										#Entity
									WHERE
										SegmentCode = @SegmentCode AND
										MappedObjectName = @MappedObjectName
									ORDER BY
										Entity
						
									SET @SQLMixedString = SUBSTRING(@SQLMixedString, 1, LEN(@SQLMixedString) -1) + '''') THEN CASE WHEN F.'''' + @MappedObjectName + '''' = ''''''''''''''''NONE'''''''''''''''' THEN '''''''''''''''''''''''''''''''' ELSE F.'''' + @MappedObjectName + '''' END ELSE '''''''''''''''''''''''''''''''' END''''
									SET @SQLMixedWhereString = SUBSTRING(@SQLMixedWhereString, 1, LEN(@SQLMixedWhereString) -1) + '''') THEN CASE WHEN F.'''' + @MappedObjectName + '''' = ''''''''''''''''NONE'''''''''''''''' THEN '''''''''''''''''''''''''''''''' ELSE F.'''' + @MappedObjectName + '''' END ELSE '''''''''''''''''''''''''''''''' END''''
											
									FETCH NEXT FROM MixedSetup_Cursor INTO @MappedObjectName
								END

						CLOSE MixedSetup_Cursor
						DEALLOCATE MixedSetup_Cursor'
SET @SQLStatement = @SQLStatement + '

						SELECT @SQLSegmentList = @SQLSegmentList + '''','''' + CHAR(13) + CHAR(10) + CHAR(9) + @SegmentName + '''' = ISNULL(seg.'''' + @SegmentCode + '''', '''''''''''''''''''''''''''''''')''''
						SELECT @SQLSegmentList = @SQLSegmentList + '''','''' + CHAR(13) + CHAR(10) + CHAR(9) + @SegmentCode + '''' = '''' + @SQLMixedString

						SELECT @SQLWhere = @SQLWhere + '''' AND'''' + CHAR(13) + CHAR(10) + CHAR(9) + ''''(ISNULL(seg.'''' + @SegmentCode + '''', '''''''''''''''''''''''''''''''') = @'''' + @SegmentName + '''' OR @'''' + @SegmentName + '''' = ''''''''''''''''-1'''''''''''''''')''''
						SELECT @SQLWhere = @SQLWhere + '''' AND'''' + CHAR(13) + CHAR(10) + CHAR(9) + @SQLMixedWhereString + '''' = @'''' + @SegmentCode + '''' OR @'''' + @SegmentCode + '''' = ''''''''''''''''-1'''''''''''''''')''''

					END

				--Defined
				IF @MappedObjectNameCount > 0
					BEGIN
						SET @Step = ''''Set BalanceAcct''''
						SELECT @SQLBalanceAcct = @SQLBalanceAcct + CASE WHEN @SQLBalanceAcct = '''''''' THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + ''''CASE WHEN '''' + @SegmentName + '''' <> '''''''''''''''''''''''''''''''' THEN '''' + @SegmentCode + '''' ELSE '''''''''''''''''''''''''''''''' END'''' ELSE '''' + '''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + ''''CASE WHEN '''' + @SegmentName + '''' <> '''''''''''''''''''''''''''''''' THEN ''''''''''''''''-'''''''''''''''' + '''' + @SegmentCode + '''' ELSE '''''''''''''''''''''''''''''''' END'''' END
					END
				FETCH NEXT FROM SegmentCode_Cursor INTO @SegmentName, @SegmentCode
			END

	CLOSE SegmentCode_Cursor
	DEALLOCATE SegmentCode_Cursor

    SET @Step = ''''CREATE Final @SQLStatement''''

SET @SQLStatement1 = ''''
SELECT 
	Company = E.Par01,
	BookID = E.Par02,
	COACode = E.Par03,
	ScenarioCode = F.Scenario,
	CurrencyCode = F.Currency,
	FiscalYear = CONVERT(int, COALESCE(CONVERT(nvarchar, CP.TimeFiscalYear), RIGHT(CASE WHEN F.Time_TimeFiscalYear = ''''''''''''''''NONE'''''''''''''''' THEN ''''''''''''''''0'''''''''''''''' ELSE F.Time_TimeFiscalYear END, 4), F.Time_TimeYear)), 
	FiscalPeriod = CONVERT(int, CASE WHEN LEFT(COALESCE(CONVERT(nvarchar, CP.TimeFiscalPeriod), RIGHT(CASE WHEN F.Time_TimeFiscalPeriod = ''''''''''''''''NONE'''''''''''''''' THEN ''''''''''''''''0'''''''''''''''' ELSE F.Time_TimeFiscalPeriod END, 2), F.Time_TimeMonth), 1) = ''''''''''''''''0'''''''''''''''' THEN RIGHT(COALESCE(CONVERT(nvarchar, CP.TimeFiscalPeriod), RIGHT(CASE WHEN F.Time_TimeFiscalPeriod = ''''''''''''''''NONE'''''''''''''''' THEN ''''''''''''''''0'''''''''''''''' ELSE F.Time_TimeFiscalPeriod END, 2), F.Time_TimeMonth), 1) ELSE COALESCE(CONVERT(nvarchar, CP.TimeFiscalPeriod), RIGHT(CASE WHEN F.Time_TimeFiscalPeriod = ''''''''''''''''NONE'''''''''''''''' THEN ''''''''''''''''0'''''''''''''''' ELSE F.Time_TimeFiscalPeriod END, 2), F.Time_TimeMonth) END), 
	BudgetCodeID = BS.BudgetCode'''' +
	@SQLSegmentList

IF @Debug <> 0 PRINT @SQLStatement1'
SET @SQLStatement = @SQLStatement + '
	
SET @SQLStatement1 = @SQLStatement1 + '''',
	EFP_Value = F.Financials_Value,
	F.* 
INTO
	#Export_Financials''''

SET @SQLStatement1 = @SQLStatement1 + ''''
FROM 
	'''' + @CallistoDatabase + ''''.[dbo].[vw_FACT_Financials] F
	INNER JOIN ['''' + @ETLDatabase + ''''].[dbo].[Entity] E ON E.SourceID = @SourceID AND E.Entity = F.Entity
	INNER JOIN ['''' + @pcINTEGRATOR + ''''].[dbo].[Source] S ON S.SourceID = E.SourceID 
	INNER JOIN ['''' + @pcINTEGRATOR + ''''].[dbo].[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID AND ST.SourceTypeFamilyID = 1 
	INNER JOIN ['''' + @pcINTEGRATOR + ''''].[dbo].[Model] M ON M.ModelID = S.ModelID AND M.BaseModelID = -7
	INNER JOIN (
				SELECT
					Entity, SegValue1, SegValue2, SegValue3, SegValue4, SegValue5, SegValue6, SegValue7, SegValue8, SegValue9, SegValue10,
					SegValue11, SegValue12, SegValue13, SegValue14, SegValue15, SegValue16, SegValue17, SegValue18, SegValue19, SegValue20
				FROM
					(
					SELECT
						E.Entity, SegmentName, SegmentCode
					FROM 
						['''' + @ETLDatabase + ''''].[dbo].[FinancialSegment] FS
						INNER JOIN ['''' + @ETLDatabase + ''''].[dbo].[Entity] E ON E.SourceID = FS.SourceID AND E.EntityCode = FS.EntityCode AND E.SelectYN <> 0
					WHERE
						FS.SourceID = @SourceID
					) d
				pivot
					(
					MAX(SegmentName)
					FOR SegmentCode in (SegValue1, SegValue2, SegValue3, SegValue4, SegValue5, SegValue6, SegValue7, SegValue8, SegValue9, SegValue10,
									SegValue11, SegValue12, SegValue13, SegValue14, SegValue15, SegValue16, SegValue17, SegValue18, SegValue19, SegValue20)
					) piv
				) seg ON seg.Entity COLLATE DATABASE_DEFAULT = F.Entity
	LEFT JOIN ['''' + @ETLDatabase + ''''].[dbo].[ClosedPeriod] CP ON CP.SourceID IN (@SourceID) AND CP.EntityCode = E.EntityCode AND CONVERT(nvarchar, CP.TimeYear) = F.[Time_TimeYear] AND CASE WHEN CP.TimeMonth <= 9 THEN ''''''''''''''''0'''''''''''''''' ELSE '''''''''''''''''''''''''''''''' END + CONVERT(nvarchar, CP.TimeMonth) = F.[Time_TimeMonth]
	LEFT JOIN ['''' + @ETLDatabase + ''''].[dbo].[BudgetSelection] BS ON BS.SourceID = @SourceID AND BS.EntityCode = E.EntityCode AND BS.Scenario = F.Scenario'''''

SET @SQLStatement = @SQLStatement + '

SET @SQLStatement2 = ''''
WHERE
	(E.Par01 = @Company OR @Company = ''''''''''''''''-1'''''''''''''''') AND
	(E.Par02 = @BookID OR @BookID = ''''''''''''''''-1'''''''''''''''') AND
	(E.Par03 = @COACode OR @COACode = ''''''''''''''''-1'''''''''''''''') AND
	(F.Scenario = @Scenario OR @Scenario = ''''''''''''''''-1'''''''''''''''') AND
	(F.Currency = @Currency OR @Currency = ''''''''''''''''-1'''''''''''''''') AND
	(CONVERT(int, COALESCE(CONVERT(nvarchar, CP.TimeFiscalYear), RIGHT(CASE WHEN F.Time_TimeFiscalYear = ''''''''''''''''NONE'''''''''''''''' THEN ''''''''''''''''0'''''''''''''''' ELSE F.Time_TimeFiscalYear END, 4), F.Time_TimeYear)) = @FiscalYear OR @FiscalYear = -1)'''' +
	@SQLWhere + '''' AND
	(F.Account = @Account OR @Account = ''''''''''''''''-1'''''''''''''''') AND
	(F.BusinessProcess = @BusinessProcess OR @BusinessProcess = ''''''''''''''''-1'''''''''''''''') AND
	(F.Entity = @Entity OR @Entity = ''''''''''''''''-1'''''''''''''''') AND
	(F.[Time] = @Time OR @Time = ''''''''''''''''-1'''''''''''''''') AND
	(F.[Version] = @Version OR @Version = ''''''''''''''''-1'''''''''''''''')

IF @ResultType = 1
	SELECT
		*
	FROM
		#Export_Financials
	ORDER BY
		Company,
		BookID,
		COACode,
		ScenarioCode,
		CurrencyCode,
		FiscalYear,
		FiscalPeriod,
		SegValue1

ELSE IF @ResultType = 2
	SELECT
		Company,
		BookID,
		BalanceAcct = '''' + CASE WHEN @SQLBalanceAcct = '''''''' THEN '''''''''''''''''''''''''''''''' ELSE @SQLBalanceAcct END + '''',
		FiscalYear,
		BudgetPerCode = @BudgetPerCode,
		GLBudgetDtl#FiscalPeriod = FiscalPeriod,
		GLBudgetDtl#BudgetAmt = EFP_Value
	FROM
		#Export_Financials EF
		INNER JOIN ' + @ETLDatabase + '..Entity E ON E.SourceID = @SourceID AND E.Par01 = EF.Company AND E.Par02 = EF.BookID AND E.Currency = EF.Currency
	ORDER BY
		Company,
		BookID,
		COACode,
		ScenarioCode,
		CurrencyCode,
		FiscalYear,
		FiscalPeriod,
		SegValue1

DROP TABLE #Export_Financials''''

IF @Debug <> 0 PRINT @SQLStatement2

	SET @SQLStatement = @SQLStatement1 + @SQLStatement2

	SET @Step = ''''Check existence of Procedure''''
		
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = ''''Procedure'''' AND ObjectName = ''''Canvas_Export_Financials'''') = 0 SET @Action = ''''CREATE'''' ELSE SET @Action = ''''ALTER'''''
SET @SQLStatement = @SQLStatement + '

                SET @SQLStatement = ''''
'''' + @Action + '''' PROCEDURE [dbo].[Canvas_Export_Financials] 
	@Scenario nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@FiscalYear int = -1,
	@SourceTypeFamilyID int = 1, --1 = Epicor ERP
	@ResultType int = 2, --1 = Full, 2 = DMT
	@Company nvarchar(8) = ''''''''''''''''-1'''''''''''''''',
	@BookID nvarchar(12) = ''''''''''''''''-1'''''''''''''''',
	@COACode nvarchar(10) = ''''''''''''''''-1'''''''''''''''',
	@Currency nvarchar(3) = ''''''''''''''''-1'''''''''''''''',
	@BudgetPerCode nvarchar(255) = ''''''''''''''''P'''''''''''''''',
	@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
	@SegName1 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue1 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName2 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue2 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName3 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue3 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName4 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue4 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName5 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue5 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName6 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue6 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName7 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue7 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName8 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue8 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName9 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue9 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName10 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue10 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName11 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue11 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName12 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue12 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName13 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue13 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName14 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue14 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName15 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue15 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName16 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue16 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName17 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue17 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName18 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue18 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName19 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue19 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegName20 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@SegValue20 nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@Account nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@BusinessProcess nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@Entity nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@Time nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@Version nvarchar(50) = ''''''''''''''''-1'''''''''''''''',
	@Debug bit = 0'
SET @SQLStatement = @SQLStatement + '

--EXEC [Canvas_Export_Financials] @Scenario = ''''''''''''''''BUDGET'''''''''''''''', @FiscalYear = 2012
--EXEC [Canvas_Export_Financials] @ResultType = 1, @Account = ''''''''''''''''1070'''''''''''''''', @BusinessProcess = ''''''''''''''''E9'''''''''''''''', @Company = ''''''''''''''''EPIC03'''''''''''''''', @BookID = ''''''''''''''''MAIN'''''''''''''''', @FiscalYear = 2012

AS 

IF @SourceTypeFamilyID <> 1
	RETURN

	'''' + @SQLStatement

	SET @SQLStatement = ''''EXEC '''' + @CallistoDatabase + ''''.dbo.sp_executesql N'''''''''''' + @SQLStatement + ''''''''''''''''

    IF @Debug <> 0 
		BEGIN 
			INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''CREATE PROCEDURE'''', [SQLStatement] = @SQLStatement
			PRINT @SQLStatement
		END

	EXEC (@SQLStatement)

    SET @Step = ''''Drop TempTables''''
        DROP TABLE #Object
        DROP TABLE #SegmentCount
		DROP TABLE #MappedObjectName
		DROP TABLE #MixedSetup_Cursor_Table
		DROP TABLE #Entity

    SET @Step = ''''Set @Duration''''          
        SET @Duration = GetDate() - @StartTime

    SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'
						SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

						IF @Debug <> 0
							BEGIN
								PRINT @SQLStatement 
								INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
							END
						
						EXEC (@SQLStatement)
						
					END

			  END

SET @Step = 'CREATE PROCEDURE spIU_0000_Dimension_Generic'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spIU_0000_Dimension_Generic' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spIU_0000_Dimension_Generic]

@JobID int = 0,
@CallistoDatabase nvarchar(100) = ''''' + @CallistoDatabase + ''''',
@DimensionID int,
@Dimension nvarchar(100),
@GetVersion bit = 0,
@Duration time(7) = ''''00:00:00'''' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT,
@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC [dbo].[spIU_0000_Dimension_Generic] @Dimension = ''''TimeMonth'''', @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@Dimensionhierarchy nvarchar(100),
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

	SET @Step = ''''Update Description where Synchronized is set to true.''''
		SET @SQLStatement = ''''
		UPDATE
			[Dimension]
		SET
			[Description] = Members.[Description]
		FROM
			'''' + @CallistoDatabase + ''''.[dbo].[S_DS_'''' + @Dimension + ''''] [Dimension] 
			INNER JOIN [wrk_Dimension] Members ON Members.Label COLLATE DATABASE_DEFAULT = [Dimension].[Label]
		WHERE 
			[Dimension].[Synchronized] <> 0''''

		IF @Debug <> 0 PRINT @SQLStatement		
		EXEC (@SQLStatement)

		SET @Updated = @Updated + @@ROWCOUNT
		
	SET @Step = ''''Insert new members''''
		SET @SQLStatement = ''''
		INSERT INTO '''' + @CallistoDatabase + ''''.[dbo].[S_DS_'''' + @Dimension + '''']
			(
			[MemberId],
			[Label],
			[Description], 
			[HelpText],
			[RNodeType],
			[SBZ],
			[Source],
			[Synchronized] 
			)
		SELECT
			[MemberId],
			[Label],
			[Description],
			[HelpText],
			[RNodeType],
			[SBZ] = [dbo].[f_GetSBZ] ('''' + CONVERT(nvarchar(10), @DimensionID) + '''', [RNodeType], [Label]),
			[Source] = ''''''''ETL'''''''',
			[Synchronized] = 1
		FROM   
			[wrk_Dimension] Members
		WHERE
			NOT EXISTS (SELECT 1 FROM '''' + @CallistoDatabase + ''''.[dbo].[S_DS_'''' + @Dimension + ''''] [Dimension] WHERE [Dimension].Label COLLATE DATABASE_DEFAULT = Members.Label)'''''
SET @SQLStatement = @SQLStatement + ' 
			
		IF @Debug <> 0 PRINT @SQLStatement		
		EXEC (@SQLStatement)			

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = ''''Update MemberId''''
		EXEC spSet_MemberId @Database = @CallistoDatabase, @Dimension = @Dimension

	SET @Step = ''''Check which parent members have leaf members as children.''''
		CREATE TABLE #LeafCheck
			(
			[MemberId] [bigint] NOT NULL,
			HasChild bit NOT NULL
			)

		EXEC spSet_LeafCheck @Database = @CallistoDatabase, @Dimension = @Dimension, @DimensionTemptable = N''''wrk_Dimension'''', @Debug = @Debug

	SET @Step = ''''Insert new members into the default hierarchy. To change the hierarchy, use the Modeler.''''
		SET @SQLStatement = ''''
		INSERT INTO '''' + @CallistoDatabase + ''''.[dbo].[S_HS_'''' + @Dimension + ''''_'''' + @Dimension + '''']
			(
			[MemberId],
			[ParentMemberId],
			[SequenceNumber]
			)
		SELECT
			D1.MemberId,
			ISNULL(D2.MemberId, 0),
			D1.MemberId  
		FROM
			'''' + @CallistoDatabase + ''''.[dbo].[S_DS_'''' + @Dimension + ''''] D1
			INNER JOIN [wrk_Dimension] V ON V.Label COLLATE DATABASE_DEFAULT = D1.Label
			LEFT JOIN '''' + @CallistoDatabase + ''''.[dbo].[S_DS_'''' + @Dimension + ''''] D2 ON D2.Label = CONVERT(nvarchar(255), V.Parent) COLLATE DATABASE_DEFAULT
			LEFT JOIN [#LeafCheck] LC ON LC.MemberId = D1.MemberId AND LC.HasChild <> 0
		WHERE
			NOT EXISTS (SELECT 1 FROM '''' + @CallistoDatabase + ''''.[dbo].[S_HS_'''' + @Dimension + ''''_'''' + @Dimension + ''''] H WHERE H.MemberId = D1.MemberId) AND
			[D1].[Synchronized] <> 0 AND
			D1.MemberId <> ISNULL(D2.MemberId, 0) AND
			D1.MemberId IS NOT NULL AND
			D1.MemberId NOT IN (1000, 30000000) AND
			(D1.RNodeType IN (''''''''L'''''''', ''''''''LC'''''''') OR LC.MemberId IS NOT NULL)
		ORDER BY
			D1.Label''''

		IF @Debug <> 0 PRINT @SQLStatement		
		EXEC (@SQLStatement)

	SET @Step = ''''Copy the hierarchy to all instances''''
		SET @Dimensionhierarchy = @Dimension + ''''_'''' + @Dimension
		EXEC spSet_HierarchyCopy @Database = @CallistoDatabase, @Dimensionhierarchy = @Dimensionhierarchy

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + '''' ('''' + @Dimension + '''')'''', @Duration, @Deleted, @Inserted, @Updated, @Version
		
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + '''' ('''' + @Dimension + '''')'''', GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END
			
SET @Step = 'CREATE PROCEDURE spIU_Load_All'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spIU_Load_All' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spIU_Load_All]

@JobID int = NULL,
@LoadTypeBM int = 31, --1=ETL tables, 2=Dimensions, 4=FactTables, 8=BusinessRules, 16=Checksums
@FrequencyBM int = 2, --1=Single, 2=Regular
@Rows int = NULL,
@GetVersion bit = 0,
@Duration time(7) = ''''00:00:00'''' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT,
@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--SET ANSI_WARNINGS OFF  --Must be SET ON to handle heterogeneous queries

--EXEC [spIU_Load_All] @Debug = 1		--Run all procedures in debug mode						
--EXEC [spIU_Load_All] @LoadTypeBM = 1  --Load all ETL tables
--EXEC [spIU_Load_All] @LoadTypeBM = 2  --Load all dimension tables
--EXEC [spIU_Load_All] @LoadTypeBM = 4  --Load all fact tables
--EXEC [spIU_Load_All] @LoadTypeBM = 8  --Run all business rules
--EXEC [spIU_Load_All] @LoadTypeBM = 16 --Run all checksums
--EXEC [spIU_Load_All] @LoadTypeBM = 31 --Run all procedures (default)

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@DatabaseName nvarchar(100),
	@Command nvarchar(100),
	@SQLStatement nvarchar(max),
	@DebugStatement nvarchar(max),
	@Total decimal(5,2),
	@Counter decimal(5,2) = 0,
	@CounterString nvarchar(100),
	@PercentDone int,
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

SET @Step = ''''Set @StartTime''''
	SET @StartTime = GETDATE()

SET @Step = ''''Set procedure variables''''
	SELECT
		@Deleted = ISNULL(@Deleted, 0),
		@Inserted = ISNULL(@Inserted, 0),
		@Updated = ISNULL(@Updated, 0)

SET @Step = ''''Create a new job''''
	IF @JobID IS NULL
		BEGIN
			INSERT INTO Job (StartTime) SELECT StartTime = GetDate()
			SET @JobID = @@IDENTITY
		END

SET @Step = ''''Count total number of commands to run''''
		SELECT
			@Total = COUNT(1)
		FROM
			[Load]
		WHERE
			SelectYN <> 0 AND
			@LoadTypeBM & LoadTypeBM > 0 AND
			@FrequencyBM & FrequencyBM > 0'
			
				SET @SQLStatement = @SQLStatement + '

SET @Step = ''''Create LoadStep_Cursor''''
	DECLARE LoadStep_Cursor CURSOR FOR

		SELECT
			DatabaseName = ''''['''' + REPLACE(REPLACE(REPLACE(ISNULL(L.[DatabaseName], DB_NAME()), ''''['''', ''''''''), '''']'''', ''''''''), ''''.'''', ''''].['''') + '''']'''',
			Command = ''''['''' + REPLACE(REPLACE(REPLACE(L.[Command], ''''['''', ''''''''), '''']'''', ''''''''), ''''.'''', ''''].['''') + '''']''''
		FROM
			[Load] L
		WHERE
			L.SelectYN <> 0 AND
			L.LoadTypeBM & @LoadTypeBM > 0 AND
			L.FrequencyBM & @FrequencyBM > 0
		ORDER BY
			L.LoadTypeBM,
			L.SortOrder,
			L.Command

		OPEN LoadStep_Cursor
		FETCH NEXT FROM LoadStep_Cursor INTO @DatabaseName, @Command

		WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @SQLStatement = ''''EXEC '''' + @DatabaseName + ''''.[dbo].[sp_executesql] N'''''''''''' + @Command + '''' @JobID = '''' + CONVERT(nvarchar(100), @JobID) + CASE WHEN @Rows IS NULL THEN '''''''' ELSE '''', @Rows = '''' + CONVERT(nvarchar(20), @Rows) END + ''''''''''''''''

				IF @Debug <> 0 SET @DebugStatement = ISNULL(@DebugStatement, '''''''') + CHAR(13) + CHAR(10) + @SQLStatement

				UPDATE Job
				SET
					CurrentCommand = @SQLStatement,
					CurrentCommand_StartTime = GetDate()
				WHERE
					JobID = @JobID

				EXEC (@SQLStatement)

				SET @Counter = @Counter + 1
				SET @CounterString = CONVERT(nvarchar(10), CONVERT(int, @Counter)) + '''' of '''' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + '''' processed''''
				SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

				RAISERROR (@CounterString, 0, @PercentDone) WITH NOWAIT

				FETCH NEXT FROM LoadStep_Cursor INTO @DatabaseName, @Command
			END

	CLOSE LoadStep_Cursor
	DEALLOCATE LoadStep_Cursor	

	IF @Debug <> 0 PRINT @DebugStatement

SET @Step = ''''Check for severe error''''
	SELECT @Command = SUBSTRING(CurrentCommand, CHARINDEX (''''N''''''''['''', CurrentCommand, 1) + 3, CHARINDEX ('''']'''', CurrentCommand, CHARINDEX (''''N''''''''['''', CurrentCommand, 1) + 3) - (CHARINDEX (''''N''''''''['''', CurrentCommand, 1) + 3)) FROM Job WHERE JobID = @JobID
	
	IF (SELECT COUNT(1) FROM JobLog WHERE JobID = @JobID AND ProcedureName = @Command) = 0
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, @Command, GetDate() - @StartTime, Deleted = 0, Inserted = 0, Updated = 0, ErrorNumber = 90000, ErrorSeverity = 16, ErrorState = 0, ErrorLine = 0, @Command, @Step, ErrorMessage = ''''Severe error, system halted.'''', @Version

SET @Step = ''''Set @Duration''''	
	SET @Duration = GetDate() - @StartTime

SET @Step = ''''Insert into JobLog''''
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version

SET @Step = ''''Set EndTime for the actual job''''
	UPDATE Job SET EndTime = GetDate() WHERE JobID = @JobID'

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END

SET @Step = 'CREATE PROCEDURE sp_ScanText'
	RAISERROR ('90 percent', 0, 90) WITH NOWAIT
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'sp_ScanText' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[sp_ScanText]
	@TableName nvarchar(100),
	@FieldName_1 nvarchar(100),
	@StringTypeBM_1 int = 1, --1 = Code, 2 = Text
	@FieldName_2 nvarchar(100) = '''''''',
	@StringTypeBM_2 int = 1, --1 = Code, 2 = Text
	@FieldName_3 nvarchar(100) = '''''''',
	@StringTypeBM_3 int = 1, --1 = Code, 2 = Text
	@FieldName_4 nvarchar(100) = '''''''',
	@StringTypeBM_4 int = 1, --1 = Code, 2 = Text
	@FieldName_5 nvarchar(100) = '''''''',
	@StringTypeBM_5 int = 1, --1 = Code, 2 = Text
	@FieldName_6 nvarchar(100) = '''''''',
	@StringTypeBM_6 int = 1, --1 = Code, 2 = Text
	@GetVersion bit = 0,
	@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC sp_ScanText @TableName = ''''Test'''', @FieldName_1 = ''''Label'''', @StringTypeBM_1 = 1,  @FieldName_2 = ''''Description'''', @StringTypeBM_2 = 1, @Debug = 1

DECLARE
	@SQLStatement nvarchar(max) = '''''''',
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

SET @SQLStatement = ''''

INSERT INTO ReplaceText_ScanLog
(
	TableName,
	FieldName,
	ErrorMessage
)

SELECT
	TableName = '''''''''''' + @TableName + '''''''''''',
	FieldName = '''''''''''' + @FieldName_1 + '''''''''''',
	ErrorMessage = dbo.f_ScanText('''' + @FieldName_1 + '''', '''' + CONVERT(nvarchar, @StringTypeBM_1) + '''')
FROM
	'''' + @TableName + ''''
WHERE
	dbo.f_ScanText('''' + @FieldName_1 + '''', '''' + CONVERT(nvarchar, @StringTypeBM_1) + '''') <> ''''''''''''''''''''

IF @FieldName_2 <> '''''''' SET @SQLStatement = @SQLStatement + ''''

UNION SELECT
	TableName = '''''''''''' + @TableName + '''''''''''',
	FieldName = '''''''''''' + @FieldName_2 + '''''''''''',
	ErrorMessage = dbo.f_ScanText('''' + @FieldName_2 + '''', '''' + CONVERT(nvarchar, @StringTypeBM_2) + '''')
FROM
	'''' + @TableName + ''''
WHERE
	dbo.f_ScanText('''' + @FieldName_2 + '''', '''' + CONVERT(nvarchar, @StringTypeBM_2) + '''') <> ''''''''''''''''''''

IF @FieldName_3 <> '''''''' SET @SQLStatement = @SQLStatement + ''''

UNION SELECT
	TableName = '''''''''''' + @TableName + '''''''''''',
	FieldName = '''''''''''' + @FieldName_3 + '''''''''''',
	ErrorMessage = dbo.f_ScanText('''' + @FieldName_3 + '''', '''' + CONVERT(nvarchar, @StringTypeBM_3) + '''')
FROM
	'''' + @TableName + ''''
WHERE
	dbo.f_ScanText('''' + @FieldName_3 + '''', '''' + CONVERT(nvarchar, @StringTypeBM_3) + '''') <> ''''''''''''''''''''

IF @FieldName_4 <> '''''''' SET @SQLStatement = @SQLStatement + ''''

UNION SELECT
	TableName = '''''''''''' + @TableName + '''''''''''',
	FieldName = '''''''''''' + @FieldName_4 + '''''''''''',
	ErrorMessage = dbo.f_ScanText('''' + @FieldName_4 + '''', '''' + CONVERT(nvarchar, @StringTypeBM_4) + '''')
FROM
	'''' + @TableName + ''''
WHERE
	dbo.f_ScanText('''' + @FieldName_4 + '''', '''' + CONVERT(nvarchar, @StringTypeBM_4) + '''') <> ''''''''''''''''''''

IF @FieldName_5 <> '''''''' SET @SQLStatement = @SQLStatement + ''''

UNION SELECT
	TableName = '''''''''''' + @TableName + '''''''''''',
	FieldName = '''''''''''' + @FieldName_5 + '''''''''''',
	ErrorMessage = dbo.f_ScanText('''' + @FieldName_5 + '''', '''' + CONVERT(nvarchar, @StringTypeBM_5) + '''')
FROM
	'''' + @TableName + ''''
WHERE
	dbo.f_ScanText('''' + @FieldName_5 + '''', '''' + CONVERT(nvarchar, @StringTypeBM_5) + '''') <> ''''''''''''''''''''

IF @FieldName_6 <> '''''''' SET @SQLStatement = @SQLStatement + ''''

UNION SELECT
	TableName = '''''''''''' + @TableName + '''''''''''',
	FieldName = '''''''''''' + @FieldName_6 + '''''''''''',
	ErrorMessage = dbo.f_ScanText('''' + @FieldName_6 + '''', '''' + CONVERT(nvarchar, @StringTypeBM_6) + '''')
FROM
	'''' + @TableName + ''''
WHERE
	dbo.f_ScanText('''' + @FieldName_6 + '''', '''' + CONVERT(nvarchar, @StringTypeBM_6) + '''') <> ''''''''''''''''''''

IF @Debug <> 0 PRINT @SQLStatement

EXEC (@SQLStatement)'

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END

SET @Step = 'CREATE PROCEDURE spCreate_f_ReplaceText'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spCreate_f_ReplaceText' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spCreate_f_ReplaceText] 

@GetVersion bit = 0,
@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC spCreate_f_ReplaceText @Debug = 1

DECLARE
	@SQLStatement nvarchar(max),
	@SQLRow nvarchar(max) = '''''''',
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

SET @SQLStatement = ''''ALTER FUNCTION [dbo].[f_ReplaceText]
(
    @InputText nvarchar(max),
	@StringTypeBM int --1 = Code, 2 = Text
)
RETURNS nvarchar(max)
AS
BEGIN
	IF @StringTypeBM = 1 --Code
		BEGIN''''

SELECT 
	@SQLRow = @SQLRow + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + ''''SET @InputText = REPLACE(@InputText, char('''' + CONVERT(nvarchar, RT.Input) + ''''), '''' + RT.[Output] + '''')'''' + CASE WHEN RT.Comment IS NULL THEN '''''''' ELSE '''' --'''' + RT.Comment END
FROM
	ReplaceText RT
WHERE
	RT.StringTypeBM & 1 > 0 AND
	RT.ReplaceYN <> 0
ORDER BY
	RT.Input

--SET @SQLRow = REPLACE(@SQLRow, '''''''''''''''', '''''''''''''''''''''''''''''''')
IF @SQLRow = '''''''' SET @SQLRow = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + ''''SET @InputText = @InputText''''

SET @SQLStatement = @SQLStatement + @SQLRow + ''''
		END

	ELSE IF @StringTypeBM = 2 --Text
		BEGIN''''

SET @SQLRow = ''''''''

SELECT 
	@SQLRow = @SQLRow + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + ''''SET @InputText = REPLACE(@InputText, char('''' + CONVERT(nvarchar, RT.Input) + ''''), '''' + RT.[Output] + '''')'''' + CASE WHEN RT.Comment IS NULL THEN '''''''' ELSE '''' --'''' + RT.Comment END
FROM
	ReplaceText RT
WHERE
	RT.StringTypeBM & 2 > 0 AND
	RT.ReplaceYN <> 0
ORDER BY
	RT.Input

--SET @SQLRow = REPLACE(@SQLRow, '''''''''''''''', '''''''''''''''''''''''''''''''')
IF @SQLRow = '''''''' SET @SQLRow = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + ''''SET @InputText = @InputText''''

SET @SQLStatement = @SQLStatement + @SQLRow + ''''
		END

	RETURN @InputText       
END''''

IF @Debug <> 0 PRINT @SQLStatement

EXEC (@SQLStatement)'

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END

SET @Step = 'CREATE PROCEDURE spCreate_f_ScanText'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spCreate_f_ScanText' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spCreate_f_ScanText] 

@GetVersion bit = 0,
@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC spCreate_f_ScanText @Debug = 1

DECLARE
	@SQLStatement nvarchar(max),
	@SQLRow nvarchar(max) = '''''''',
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

SET @SQLStatement = ''''ALTER FUNCTION [dbo].[f_ScanText]
(
    @InputText nvarchar(max),
	@StringTypeBM int --1 = Code, 2 = Text
)

RETURNS nvarchar(max)
AS

BEGIN

DECLARE
	@Position int,
	@ReturnStatement nvarchar(max) = ''''''''''''''''

	IF @StringTypeBM = 1 --Code
		BEGIN''''

SELECT 
	@SQLRow = @SQLRow + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + ''''SELECT @Position = CHARINDEX (char('''' + CONVERT(nvarchar, RT.Input) + ''''), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + ''''''''InputText = '''''''' + @InputText + '''''''', CharacterCode = char('''' + CONVERT(nvarchar, RT.Input) + ''''), Position = '''''''' + CONVERT(nvarchar, @Position) + ''''''''; ''''''''''''
FROM
	ReplaceText RT
WHERE
	RT.StringTypeBM & 1 > 0 AND
	RT.ScanYN <> 0
ORDER BY
	RT.Input

--SET @SQLRow = REPLACE(@SQLRow, '''''''''''''''', '''''''''''''''''''''''''''''''')
IF @SQLRow = '''''''' SET @SQLRow = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + ''''SET @InputText = @InputText''''

SET @SQLStatement = @SQLStatement + @SQLRow + ''''
		END

	ELSE IF @StringTypeBM = 2 --Text
		BEGIN''''

SET @SQLRow = ''''''''

SELECT 
	@SQLRow = @SQLRow + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + ''''SELECT @Position = CHARINDEX (char('''' + CONVERT(nvarchar, RT.Input) + ''''), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + ''''''''InputText = '''''''' + @InputText + '''''''', CharacterCode = char('''' + CONVERT(nvarchar, RT.Input) + ''''), Position = '''''''' + CONVERT(nvarchar, @Position) + ''''''''; ''''''''''''
FROM
	ReplaceText RT
WHERE
	RT.StringTypeBM & 2 > 0 AND
	RT.ScanYN <> 0
ORDER BY
	RT.Input

--SET @SQLRow = REPLACE(@SQLRow, '''''''''''''''', '''''''''''''''''''''''''''''''')
IF @SQLRow = '''''''' SET @SQLRow = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + ''''SET @InputText = @InputText''''

SET @SQLStatement = @SQLStatement + @SQLRow + ''''
		END

	IF @ReturnStatement <> '''''''''''''''' SET @ReturnStatement = SUBSTRING(@ReturnStatement, 1, LEN(@ReturnStatement) - 1)
	RETURN @ReturnStatement      
END''''

IF @Debug <> 0 PRINT @SQLStatement

EXEC (@SQLStatement)'

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END

SET @Step = 'CREATE PROCEDURE spIU_0000_FACT_FxTrans'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spIU_0000_FACT_FxTrans' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spIU_0000_FACT_FxTrans]

	@JobID int = 0,
	@UserID nvarchar(100) = NULL,
	@ModelName nvarchar(100),
	@BPType nvarchar(10), --''''ETL'''' OR ''''BP''''
	@Simulation_MemberId bigint = -1,
	@CallistoDatabase nvarchar(100) = ''''' + @CallistoDatabase + ''''',
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC [spIU_0000_FACT_FxTrans] @ModelName = ''''Sales'''', @BPType = ''''ETL''''
--EXEC [spIU_0000_FACT_FxTrans] @ModelName = ''''Financials'''', @BPType = ''''ETL''''

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@SQLCreate nvarchar(2000) = '''''''',
	@SQLInsert nvarchar(2000) = '''''''',
	@SQLSelect nvarchar(2000) = '''''''',
	@SQLCheckJoin nvarchar(4000) = '''''''',
	@SQLFUJoin nvarchar(2000) = '''''''',
	@SQLFxJoin nvarchar(4000) = '''''''',
	@SQLFxFJoin nvarchar(4000) = '''''''',
	@FxModelName nvarchar(100),
	@DimPrefix nvarchar(10),
	@FTime nvarchar(50),
	@FAccount nvarchar(50),
	@FCurrency nvarchar(50),
	@FBusinessRule nvarchar(50),
	@FEntity nvarchar(50),
	@FSimulation nvarchar(50),
	@FBusinessRuleDimName nvarchar(50),
	@FBusinessRuleHierarchy nvarchar(100),
	@FBusinessRuleWhereString nvarchar(1000),
	@CreateTempTableYN bit = 0,
	@ErrorMessage nvarchar(255),
	@Counter int,
	@Version nvarchar(50)  = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

IF (SELECT OBJECT_ID(N''''tempdb..#FACT_Update'''')) IS NULL
	BEGIN
		SET @CreateTempTableYN = 1
		SELECT * INTO #FACT_Update FROM wrk_FACT_Update
	END'

SET @SQLStatement = @SQLStatement + '

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()
		SET DATEFIRST 1

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT	
			@FxModelName = [MOM].MappedObjectName
		FROM
			MappedObject [MOM]
		WHERE
			[MOM].ObjectName = ''''FxRate'''' AND
			[MOM].ObjectTypeBM & 1 > 0 AND
			[MOM].SelectYN <> 0

		SET @DimPrefix = CASE @BPType WHEN ''''ETL'''' THEN ''''S_DS'''' WHEN ''''BP'''' THEN ''''DS'''' END

		SET @UserID = ISNULL(@UserID, suser_name())

	SET @Step = ''''Check Simulation''''
		IF @Simulation_MemberId <> -1
			BEGIN
				CREATE TABLE #Count ([Counter] int)

				SET @SQLStatement = ''''
					INSERT INTO #Count 
						(
						[Counter]
						)
					SELECT
						[Counter] = COUNT(1)
					FROM
						'''' + @CallistoDatabase + ''''..ModelDimensions MD
						INNER JOIN MappedObject MO ON MO.Entity = ''''''''-1'''''''' AND MO.ObjectName = ''''''''Simulation'''''''' AND MO.DimensionTypeID = 17 AND MO.ObjectTypeBM & 2 > 0 AND MO.MappedObjectName = MD.Dimension
					WHERE
						MD.Model = '''''''''''' + @ModelName + ''''''''''''''''

				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Check if Simulation dimension exists in selected Model'''', [SQLStatement] = @SQLStatement
				EXEC (@SQLStatement)
				IF @Debug <> 0 SELECT Temptable = ''''#Count'''', * FROM #Count

				SELECT @Counter = [Counter] FROM #Count
				DROP TABLE #Count

				IF @Counter = 0
					SET @ErrorMessage = ''''The Simulation dimension is not available in the '''' + @ModelName + '''' model.''''
					GOTO EXITPOINT_SIMULATION
			END'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create fieldlist''''
		CREATE TABLE #FieldList
			(
			[ModelName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[FieldName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[DimensionTypeID] int,
			[DefaultValue] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[MainJoin] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SecJoin] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[SortOrder] int
			)

		SET @SQLStatement = ''''
		INSERT INTO #FieldList
			(
			[ModelName],
			[FieldName],
			[DimensionName],
			[DimensionTypeID],
			[DefaultValue],
			[MainJoin],
			[SecJoin],
			[SortOrder]
			)
		SELECT DISTINCT
			[ModelName] = '''''''''''' + @FxModelName + '''''''''''',
			[FieldName] = c.[name],
			[DimensionName] = '''''''''''''''',
			[DimensionTypeID] = MAX([MOD].[DimensionTypeID]),
			[DefaultValue] = '''''''''''''''',
			[MainJoin] = CASE WHEN c.[name] LIKE ''''''''%_MemberId%'''''''' THEN CASE MAX([MOD].[DimensionTypeID]) WHEN 3 THEN ''''''''BC.['''''''' + c.[name] + ''''''''] = F.['''''''' + c.[name] + '''''''']'''''''' ELSE ''''''''BC.['''''''' + c.[name] + ''''''''] = DC.['''''''' + c.[name] + '''''''']'''''''' END ELSE NULL END,
			[SecJoin] = CASE WHEN MAX([MOD].[DimensionTypeID]) IN (3, 4, 5, 6, 7) THEN ''''''''DC.['''''''' + c.[name] + ''''''''] = '''''''' + CASE MAX([MOD].[DimensionTypeID]) WHEN 3 THEN ''''''''C.[MemberId]'''''''' WHEN 4 THEN ''''''''ISNULL(E.Entity_MemberId, -1)'''''''' WHEN 5 THEN ''''''''A.['''''''' + c.[name] + '''''''']'''''''' WHEN 6 THEN ''''''''F.['''''''' + c.[name] + '''''''']'''''''' WHEN 7 THEN ''''''''@FTime'''''''' END ELSE NULL END,
			[SortOrder] = MAX(c.[column_id])
		FROM
			MappedObject [MOM]
			INNER JOIN '''' + @CallistoDatabase + ''''.sys.tables t ON t.[name] = ''''''''FACT_'''''''' + [MOM].MappedObjectName + ''''''''_default_partition''''''''
			INNER JOIN '''' + @CallistoDatabase + ''''.sys.columns c ON c.object_id = t.object_id
			LEFT JOIN MappedObject [MOD] ON [MOD].ObjectTypeBM & 2 > 0 AND [MOD].MappedObjectName + ''''''''_MemberId'''''''' = c.name
		WHERE
			[MOM].ObjectName = ''''''''FxRate'''''''' AND [MOM].ObjectTypeBM & 1 > 0 
		GROUP BY
			t.[name],
			c.[name]''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)'

SET @SQLStatement = @SQLStatement + '

		SET @SQLStatement = ''''
		INSERT INTO #FieldList
			(
			[ModelName],
			[FieldName],
			[DimensionName],
			[DimensionTypeID],
			[DefaultValue],
			[MainJoin],
			[SecJoin],
			[SortOrder]
			)
		SELECT DISTINCT
			[ModelName] = '''''''''''' + @ModelName + '''''''''''',
			[FieldName] = c.[name],
			[DimensionName] = ISNULL(MAX(CASE WHEN MOD.DimensionTypeID = -1 THEN [MOD].[MappedObjectName] ELSE [MOD].[ObjectName] END), MAX(DD.Label)),
			[DimensionTypeID] = ISNULL(MAX([MOD].[DimensionTypeID]), MAX(DT.DimensionTypeID)),
			[DefaultValue] = ISNULL(CASE ISNULL(MAX([MOD].[DimensionTypeID]), 0) WHEN 39 THEN ''''''''101'''''''' WHEN 3 THEN ''''''''DC.[Currency_MemberId]'''''''' WHEN 0 THEN CASE c.[name] WHEN ''''''''UserId'''''''' THEN '''''''''''''''''''''''''''' + @UserID + '''''''''''''''''''''''''''' WHEN ''''''''ChangeDatetime'''''''' THEN ''''''''GetDate()'''''''' WHEN '''''''''''' + @ModelName + '''''''''''' + ''''''''_Value'''''''' THEN ''''''''F.['''' + @ModelName + ''''_Value] * DC.['''' + @FxModelName + ''''_Value] / BC.['''' + @FxModelName + ''''_Value]'''''''' END ELSE ''''''''F.['''''''' + c.[name] + '''''''']'''''''' END, ''''''''F.['''''''' + c.[name] + '''''''']''''''''),
			[MainJoin] = CASE WHEN c.[name] LIKE ''''''''%_MemberId%'''''''' AND ISNULL(MAX([MOD].[DimensionTypeID]), 0) <> 39 THEN ''''''''D.['''''''' + c.[name] + ''''''''] = F.['''''''' + c.[name] + '''''''']'''''''' ELSE NULL END,
			[SecJoin] = CASE WHEN MAX(CONVERT(int, D.DeleteJoinYN)) <> 0 OR MAX([MOD].[DimensionTypeID]) = 7 THEN CASE WHEN MAX([MOD].[DimensionTypeID]) = 7 THEN ''''''''U.[Time_MemberId] = @FTime'''''''' ELSE ''''''''U.['''''''' + c.[name] + ''''''''] = F.['''''''' + c.[name] + '''''''']'''''''' END ELSE NULL END,
			[SortOrder] = MAX(c.[column_id])
		FROM
			'''' + @CallistoDatabase + ''''.sys.tables t
			INNER JOIN '''' + @CallistoDatabase + ''''.sys.columns c ON c.object_id = t.object_id
			LEFT JOIN '''' + @CallistoDatabase + ''''.[dbo].[Dimensions] DD ON DD.Label + ''''''''_MemberId'''''''' = c.name 
			LEFT JOIN pcINTEGRATOR..DimensionType DT ON DimensionTypeName = DD.[Type]
			LEFT JOIN MappedObject [MOD] ON [MOD].ObjectTypeBM & 2 > 0 AND [MOD].MappedObjectName + ''''''''_MemberId'''''''' = c.name
			LEFT JOIN pcINTEGRATOR..Dimension D ON D.DimensionName = [MOD].ObjectName AND D.DimensionTypeID = [MOD].DimensionTypeID
		WHERE
			t.name = ''''''''FACT_'''' + @ModelName + ''''_default_partition''''''''
		GROUP BY
			c.[name]''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = ''''#FieldList'''', * FROM #FieldList ORDER BY [ModelName], [SortOrder]'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create SQL-string variables''''
		SELECT
			@FAccount = MAX(CASE WHEN DimensionTypeID = 1 THEN REPLACE(FieldName, ''''_MemberId'''', '''''''') END),
			@FCurrency = MAX(CASE WHEN DimensionTypeID = 3 THEN REPLACE(FieldName, ''''_MemberId'''', '''''''') END),
			@FEntity = MAX(CASE WHEN DimensionTypeID = 4 THEN REPLACE(FieldName, ''''_MemberId'''', '''''''') END),
			@FTime = MAX(CASE WHEN DimensionTypeID = 7 THEN CASE DimensionName WHEN ''''Time'''' THEN DefaultValue WHEN ''''TimeDay'''' THEN DefaultValue + '''' / 100'''' END END),
			@FBusinessRule = MAX(CASE WHEN DimensionTypeID = 39 THEN FieldName END),
			@FBusinessRuleDimName = MAX(CASE WHEN DimensionTypeID = 39 THEN DimensionName END),
			@FBusinessRuleHierarchy = MAX(CASE WHEN DimensionTypeID = 39 THEN DimensionName + ''''_'''' + DimensionName END),
			@FSimulation = ISNULL(MAX(CASE WHEN DimensionTypeID = 17 THEN FieldName END), '''''''')
		FROM
			#FieldList
		WHERE
			ModelName = @ModelName AND
			DimensionTypeID IN (1, 3, 4, 7, 39)

		IF @Debug <> 0 SELECT FAccount = @FAccount, FCurrency = @FCurrency, FTime = @FTime, FBusinessRule = @FBusinessRule

		SELECT
			@SQLCreate = @SQLCreate + ''''['''' + [FieldName] + ''''] '''' + CASE WHEN [FieldName] LIKE ''''%_MemberId'''' THEN ''''bigint'''' ELSE CASE WHEN [FieldName] LIKE ''''%_Value'''' THEN ''''float'''' ELSE ''''nvarchar(100)'''' END END + '''','''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9),
			@SQLInsert = @SQLInsert + ''''['''' + [FieldName] + ''''],'''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9),
			@SQLSelect = @SQLSelect + ''''['''' + [FieldName] + ''''] = '''' + [DefaultValue] + '''','''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
		FROM
			#FieldList
		WHERE
			[ModelName] = @ModelName
		ORDER BY
			[SortOrder]

		SELECT
			@SQLCheckJoin = @SQLCheckJoin + [MainJoin] + '''' AND'''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
		FROM
			#FieldList
		WHERE
			[ModelName] = @ModelName AND
			[MainJoin] IS NOT NULL
		ORDER BY
			[SortOrder]'

SET @SQLStatement = @SQLStatement + '

		SELECT
			@SQLFUJoin = @SQLFUJoin + REPLACE([SecJoin], ''''@FTime'''', @FTime) + '''' AND ''''
		FROM
			#FieldList
		WHERE
			[ModelName] = @ModelName AND
			[SecJoin] IS NOT NULL
		ORDER BY
			[SortOrder]

		SELECT
			@SQLFxJoin = @SQLFxJoin + [MainJoin] + '''' AND'''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
		FROM
			#FieldList
		WHERE
			[ModelName] = @FxModelName AND
			[MainJoin] IS NOT NULL
		ORDER BY
			[SortOrder]

		SELECT
			@SQLFxFJoin = @SQLFxFJoin + REPLACE([SecJoin], ''''@FTime'''', @FTime) + '''' AND ''''
		FROM
			#FieldList
		WHERE
			[ModelName] = @FxModelName AND
			[SecJoin] IS NOT NULL
		ORDER BY
			[SortOrder]

--		EXEC pcINTEGRATOR..[spGet_LeafLevel] @Database = @CallistoDatabase, @Dimension = @FBusinessRuleDimName, @Hierarchy = @FBusinessRuleHierarchy, @MemberId = 202, @LeafMemberId = @FBusinessRuleWhereString OUT
		SET @FBusinessRuleWhereString = ''''-1''''


		SELECT
			@SQLCreate = SUBSTRING(@SQLCreate, 1, LEN(@SQLCreate) - 7),
			@SQLInsert = SUBSTRING(@SQLInsert, 1, LEN(@SQLInsert) - 7),
			@SQLSelect = SUBSTRING(@SQLSelect, 1, LEN(@SQLSelect) - 7),
			@SQLCheckJoin = SUBSTRING(@SQLCheckJoin, 1, LEN(@SQLCheckJoin) - 12),
			@SQLFUJoin = SUBSTRING(@SQLFUJoin, 1, LEN(@SQLFUJoin) - 4),
			@SQLFxJoin = SUBSTRING(@SQLFxJoin, 1, LEN(@SQLFxJoin) - 12),
			@SQLFxFJoin = SUBSTRING(@SQLFxFJoin, 1, LEN(@SQLFxFJoin) - 4)

		IF @Debug <> 0 
			BEGIN
				PRINT CHAR(13) + CHAR(10) + ''''--@SQLCreate'''' + CHAR(13) + CHAR(10) + @SQLCreate
				PRINT CHAR(13) + CHAR(10) + ''''--@SQLInsert'''' + CHAR(13) + CHAR(10) + @SQLInsert
				PRINT CHAR(13) + CHAR(10) + ''''--@SQLSelect'''' + CHAR(13) + CHAR(10) + @SQLSelect
				PRINT CHAR(13) + CHAR(10) + ''''--@SQLCheckJoin'''' + CHAR(13) + CHAR(10) + @SQLCheckJoin
				PRINT CHAR(13) + CHAR(10) + ''''--@SQLFUJoin'''' + CHAR(13) + CHAR(10) + @SQLFUJoin
				PRINT CHAR(13) + CHAR(10) + ''''--@SQLFxJoin'''' + CHAR(13) + CHAR(10) + @SQLFxJoin
				PRINT CHAR(13) + CHAR(10) + ''''--@SQLFxFJoin'''' + CHAR(13) + CHAR(10) + @SQLFxFJoin
				SELECT TempTable = ''''#FACT_Update'''', * FROM #FACT_Update
			END'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create #Entity''''
		CREATE TABLE #Entity
			(
			Entity_MemberId bigint
			)

		SET @SQLStatement = ''''
			INSERT INTO #Entity
				(
				Entity_MemberId
				)
			SELECT DISTINCT
				DSE.MemberId 
			FROM
				Entity E 
				INNER JOIN [pcINTEGRATOR].[dbo].[Source] S ON S.SourceID = E.SourceID AND S.SelectYN <> 0
				INNER JOIN [pcINTEGRATOR].[dbo].[Model] M ON M.ModelID = S.ModelID AND M.BaseModelID = -3 AND M.SelectYN <> 0
				INNER JOIN '''' + @CallistoDatabase + ''''..S_DS_'''' + @FEntity + '''' DSE ON DSE.Label = E.Entity
				INNER JOIN '''' + @CallistoDatabase + ''''..FACT_'''' + @FxModelName + ''''_default_partition F ON F.'''' + @FEntity + ''''_MemberId = DSE.MemberId
			WHERE
				E.SelectYN <> 0''''

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		IF @Debug <> 0 SELECT TempTable = ''''#Entity'''', * FROM #Entity

	SET @Step = ''''Create temptable wrk_FxRateRow''''
		IF (SELECT COUNT(1) FROM sys.tables WHERE name = ''''wrk_FxRateRow'''') > 0
			DROP TABLE wrk_FxRateRow

		SET @SQLStatement = ''''
			CREATE TABLE wrk_FxRateRow
				(
				'''' + @SQLCreate + ''''
				)''''

		EXEC (@SQLStatement)

	SET @Step = ''''Set INSERT @SQLStatement for wrk_FxRateRow''''
		SET @SQLStatement = ''''
			INSERT INTO wrk_FxRateRow
				(
				'''' + @SQLInsert + ''''
				)
			SELECT
				'''' + @SQLSelect'

SET @SQLStatement = @SQLStatement + '
		
		SET @SQLStatement = @SQLStatement + ''''
			FROM
				'''' + @CallistoDatabase + ''''..FACT_'''' + @ModelName + ''''_default_partition F
				INNER JOIN #FACT_Update U ON '''' + @SQLFUJoin + ''''
				INNER JOIN '''' + @CallistoDatabase + ''''..'''' + @DimPrefix + ''''_'''' + @FAccount + '''' A ON A.MemberId = F.'''' + @FAccount + ''''_MemberId
				INNER JOIN '''' + @CallistoDatabase + ''''..'''' + @DimPrefix + ''''_'''' + @FCurrency + '''' C ON C.Reporting <> 0
				LEFT JOIN #Entity E ON E.Entity_MemberId = F.'''' + @FEntity + ''''_MemberId
				INNER JOIN '''' + @CallistoDatabase + ''''..FACT_'''' + @FxModelName + ''''_default_partition DC ON '''' + @SQLFxFJoin + ''''
				INNER JOIN '''' + @CallistoDatabase + ''''..FACT_'''' + @FxModelName + ''''_default_partition BC ON
						'''' + @SQLFxJoin

		SET @SQLStatement = @SQLStatement + ''''
			WHERE'''' + CASE WHEN (SELECT COUNT(1) FROM #FieldList WHERE ModelName = @ModelName AND DimensionTypeID = 17) <> 0 THEN ''''
				F.['''' + @FSimulation + '''' ] = -1 AND'''' ELSE '''''''' END + ''''
				F.['''' + @FBusinessRule + ''''] IN ('''' + @FBusinessRuleWhereString + '''') AND
				F.['''' + @ModelName + ''''_Value] <> 0''''

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Add rows to wrk_FxRateRow'''', [SQLStatement] = @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = ''''Set INSERT @SQLStatement for destination database''''
		SET @SQLStatement = ''''
			INSERT INTO '''' + @CallistoDatabase + ''''..FACT_'''' + @ModelName + ''''_default_partition
				(
				'''' + @SQLInsert + ''''
				)
			SELECT
				'''' + @SQLInsert + ''''
			FROM
				wrk_FxRateRow F
			WHERE
				NOT EXISTS
					(
					SELECT
						1 
					FROM
						'''' + @CallistoDatabase + ''''..FACT_'''' + @ModelName + ''''_default_partition D
					WHERE
						'''' + @SQLCheckJoin + '''' AND
						D.['''' + @ModelName + ''''_Value] <> 0.0
					)''''
	
	SET @Step = ''''EXEC @SQLStatement''''
		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Add rows to FactTable'''', [SQLStatement] = @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Drop temp tables''''
		DROP TABLE #FieldList
		DROP TABLE #Entity
		IF @CreateTempTableYN <> 0 DROP TABLE #FACT_Update

	SET @Step = ''''Set @Duration''''
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + '''' ('''' + @ModelName + '''')'''', @Duration, @Deleted, @Inserted, @Updated, @Version
						
		RETURN 0

	SET @Step = ''''EXITPOINT_SIMULATION:''''
		EXITPOINT_SIMULATION:
		SET @Duration = GetDate() - @StartTime
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + '''' ('''' + @ModelName + '''')'''', GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ErrorNumber = -33, ErrorSeverity = 10, ErrorState = 0, ErrorLine = 0, ErrorProcedure = OBJECT_NAME(@@PROCID), @Step, ErrorMessage = @ErrorMessage, @Version
		SET @JobLogID = @@IDENTITY
		SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
		SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
		RETURN @ErrorNumber
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + '''' ('''' + @ModelName + '''')'''', GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END

SET @Step = 'CREATE PROCEDURE spFix_ChangedLabel'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spFix_ChangedLabel' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE spFix_ChangedLabel 

	@JobID int = 0,
	@Rows int = NULL,
	@CallistoDatabase nvarchar(100) = ''''' + @CallistoDatabase + ''''',
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC spFix_ChangedLabel @Debug = 1

SET ANSI_WARNINGS OFF

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@ObjectName nvarchar(100),
	@DimensionName nvarchar(100),
	@DimensionID int,
	@MemberId int,
	@Updated_Step int = 0,
	@FiscalYearStartMonth int = 1,
	@Version nvarchar(50)  = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@FiscalYearStartMonth = A.FiscalYearStartMonth
		FROM
			[pcINTEGRATOR].[dbo].[Application] A
		WHERE
			''''['''' + REPLACE(REPLACE(REPLACE(A.DestinationDatabase, ''''['''', ''''''''), '''']'''', ''''''''), ''''.'''', ''''].['''') + '''']'''' = ''''['''' + REPLACE(REPLACE(REPLACE(@CallistoDatabase, ''''['''', ''''''''), '''']'''', ''''''''), ''''.'''', ''''].['''') + '''']''''

		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

	SET @Step = ''''Create temp table''''
		CREATE TABLE #DimensionList
			(
			ObjectName nvarchar(100),
			DimensionName nvarchar(100),
			DimensionID int,
			MemberId int
			)'

SET @SQLStatement = @SQLStatement + '

		SET @SQLStatement = ''''
			INSERT INTO #DimensionList
				(
				ObjectName,
				DimensionName,
				DimensionID,
				MemberId
				)
			SELECT DISTINCT
				ObjectName = CASE WHEN MO.DimensionTypeID = -1 THEN ''''''''GLSegment'''''''' ELSE MO.ObjectName END,
				DimensionName = MO.MappedObjectName,
				DimensionID = CASE WHEN MO.DimensionTypeID IN(7, 25) THEN D.DimensionID ELSE 0 END,
				MemberId = ISNULL(M.MemberId, 1000)
			FROM 
				MappedObject MO
				INNER JOIN '''' + @CallistoDatabase + ''''.sys.tables t ON t.name = ''''''''S_DS_'''''''' + MO.MappedObjectName
				LEFT JOIN (
							SELECT 
								DimensionName = D.DimensionName,
								MemberId = MAX(M.MemberId)
							FROM 
								pcINTEGRATOR..Dimension D
								INNER JOIN pcINTEGRATOR..Member M ON (M.DimensionID = D.DimensionID OR M.DimensionID = 0) AND M.Label = ''''''''pcPlaceHolder'''''''' AND M.SelectYN <> 0
							GROUP BY
								D.DimensionName
							) M ON M.DimensionName = MO.ObjectName
				LEFT JOIN pcINTEGRATOR..Dimension D ON D.DimensionTypeID = MO.DimensionTypeID AND D.DimensionName = MO.ObjectName
				INNER JOIN (SELECT DISTINCT DimensionID FROM pcINTEGRATOR..Member WHERE SelectYN <> 0 AND Label <> ''''''''pcPlaceHolder'''''''') Mem ON Mem.DimensionID = D.DimensionID OR MO.DimensionTypeID IN(7, 25)
			WHERE
				MO.ObjectTypeBM & 2 > 0 AND
				MO.SelectYN <> 0''''

			IF @Debug <> 0 PRINT @SQLStatement
			EXEC (@SQLStatement)

			IF @Debug <> 0 SELECT TempTable = ''''#DimensionList'''', * FROM #DimensionList ORDER BY DimensionID, DimensionName'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create table cursor''''
		DECLARE CheckLabel_Cursor CURSOR FOR
			SELECT 
				ObjectName,
				DimensionName,
				DimensionID,
				MemberId
			FROM 
				#DimensionList
			ORDER BY
				DimensionID,
				DimensionName

			OPEN CheckLabel_Cursor
			FETCH NEXT FROM CheckLabel_Cursor INTO @ObjectName, @DimensionName, @DimensionID, @MemberId

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT ObjectName = @ObjectName, DimensionName = @DimensionName, DimensionID = @DimensionID, MemberId = @MemberId

					IF @DimensionID = 0
					--Not time related dimensions
						BEGIN
						--Duplicate
							SET @SQLStatement = ''''
							UPDATE SD
								SET Label = SD.Label + ''''''''_'''''''' + CONVERT(nvarchar(10), SD.MemberId)
							FROM
								pcINTEGRATOR..Member M
								INNER JOIN pcINTEGRATOR..Dimension D ON (D.DimensionID = M.DimensionID OR M.DimensionID = 0) AND D.DimensionName = '''''''''''' + @ObjectName + ''''''''''''
								INNER JOIN '''' + @CallistoDatabase + ''''..[S_DS_'''' + @DimensionName + ''''] SD ON SD.Label = M.Label AND SD.MemberId > '''' + CONVERT(nvarchar(10), @MemberId) + ''''
							WHERE
								M.SelectYN <> 0''''

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement) 

							SET @Updated_Step = @@ROWCOUNT'

SET @SQLStatement = @SQLStatement + '

						--Changed
							SET @SQLStatement = ''''
							UPDATE SD
								SET Label = M.Label
							FROM
								(
								SELECT 
									DimensionID = sub.DimensionID,
									MemberId = MAX(sub.MemberId),
									Label = sub.Label
								FROM
									(
									SELECT 
										DimensionID,
										MemberId,
										Label
									FROM 
										pcINTEGRATOR..Member M
									WHERE
										M.DimensionID <> 0 AND
										M.SelectYN <> 0
									UNION SELECT 
										D.DimensionID,
										M.MemberId,
										M.Label
									FROM 
										pcINTEGRATOR..Dimension D
										INNER JOIN pcINTEGRATOR..Member M ON M.DimensionID = 0 AND M.SelectYN <> 0
									WHERE
										D.DimensionID <= 0
									) sub
								GROUP BY
									sub.DimensionID,
									sub.Label
								) M
								INNER JOIN pcINTEGRATOR..Dimension D ON D.DimensionID = M.DimensionID AND D.DimensionName = '''''''''''' + @ObjectName + ''''''''''''
								INNER JOIN '''' + @CallistoDatabase + ''''..[S_DS_'''' + @DimensionName + ''''] SD ON SD.MemberId = M.MemberId AND SD.Label <> M.Label''''

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement) 

							SET @Updated_Step = @Updated_Step + @@ROWCOUNT
						END
					ELSE'

SET @SQLStatement = @SQLStatement + '
					--Time related dimensions
						IF @DimensionID NOT IN (-7, -49)
						--Time Properties
							BEGIN
								EXEC [spIU_0000_Time_Property] @JobID = @JobID, @DimensionID = @DimensionID, @LabelCheck = 1
								IF @Debug <> 0 SELECT wrkTable = ''''wrk_Dimension'''', * FROM wrk_Dimension
							--Duplicate
								SET @SQLStatement = ''''
								UPDATE SD
									SET Label = SD.Label + ''''''''_'''''''' + CONVERT(nvarchar(10), SD.MemberId)
								FROM
									wrk_Dimension M
									INNER JOIN '''' + @CallistoDatabase + ''''..[S_DS_'''' + @DimensionName + ''''] SD ON SD.Label = M.Label AND SD.MemberId <> M.MemberId''''

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement) 

								SET @Updated_Step = @@ROWCOUNT

							--Changed
								SET @SQLStatement = ''''
								UPDATE SD
									SET Label = M.Label
								FROM
									wrk_Dimension M
									INNER JOIN '''' + @CallistoDatabase + ''''..[S_DS_'''' + @DimensionName + ''''] SD ON SD.MemberId = M.MemberId AND SD.Label <> M.Label''''

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement) 

								SET @Updated_Step = @Updated_Step + @@ROWCOUNT
							END'

SET @SQLStatement = @SQLStatement + '
						ELSE
						--Time Dimensions
							BEGIN
								--Duplicate
								SET @SQLStatement = ''''
								UPDATE SD
									SET Label = SD.Label + ''''''''_'''''''' + CONVERT(nvarchar(10), SD.MemberId)
								FROM
									'''' + @CallistoDatabase + ''''..[S_DS_'''' + @DimensionName + ''''] SD
								WHERE
									((Label <> CONVERT(nvarchar(10), MemberId) AND Level NOT IN (''''''''All_'''''''', ''''''''NONE'''''''', ''''''''Year'''''''', ''''''''Quarter'''''''', ''''''''Week'''''''')) OR
									(Label <> CASE WHEN '''' + CONVERT(nvarchar(10), @FiscalYearStartMonth) + '''' <> 1 THEN ''''''''FY'''''''' ELSE '''''''''''''''' END + CONVERT(nvarchar(10), MemberId) AND Level IN (''''''''Year'''''''')) OR
									(Label <> CONVERT(nvarchar(10), MemberId / 10) + CASE WHEN '''' + CONVERT(nvarchar(10), @FiscalYearStartMonth) + '''' <> 1 THEN ''''''''FQ'''''''' ELSE ''''''''Q'''''''' END + CONVERT(nvarchar(10), MemberId % 10) AND Level IN (''''''''Quarter'''''''')) OR
									(Label <> CONVERT(nvarchar(10), MemberId / 1000) + ''''''''W'''''''' + CASE WHEN MemberId % 100 <= 9 THEN ''''''''0'''''''' ELSE '''''''''''''''' END + CONVERT(nvarchar(10), MemberId % 100) AND Level IN (''''''''Week'''''''')) OR
									(MemberId = -1 AND Label <> ''''''''NONE'''''''') OR
									(MemberId = 1 AND Label <> ''''''''All_'''''''') OR
									(MemberId = '''' + CONVERT(nvarchar(10), @MemberId) + '''' AND Label <> ''''''''pcPlaceHolder'''''''')) AND
									MemberId > '''' + CONVERT(nvarchar(10), @MemberId) + '''' AND
									RIGHT(Label, 8) <> CONVERT(nvarchar(10), MemberId)''''

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement) 

								SET @Updated_Step = @@ROWCOUNT

							--Changed
								SET @SQLStatement = ''''
								UPDATE SD
									SET Label = 
										CASE WHEN Level NOT IN (''''''''All_'''''''', ''''''''NONE'''''''', ''''''''Year'''''''', ''''''''Quarter'''''''', ''''''''Week'''''''') THEN CONVERT(nvarchar(10), MemberId) ELSE
										CASE WHEN Level IN (''''''''Year'''''''') THEN CASE WHEN '''' + CONVERT(nvarchar(10), @FiscalYearStartMonth) + '''' <> 1 THEN ''''''''FY'''''''' ELSE '''''''''''''''' END + CONVERT(nvarchar(10), MemberId) ELSE
										CASE WHEN Level IN (''''''''Quarter'''''''') THEN CONVERT(nvarchar(10), MemberId / 10) + CASE WHEN '''' + CONVERT(nvarchar(10), @FiscalYearStartMonth) + '''' <> 1 THEN ''''''''FQ'''''''' ELSE ''''''''Q'''''''' END + CONVERT(nvarchar(10), MemberId % 10) ELSE
										CASE WHEN Level IN (''''''''Week'''''''') THEN CONVERT(nvarchar(10), MemberId / 1000) + ''''''''W'''''''' + CASE WHEN MemberId % 100 <= 9 THEN ''''''''0'''''''' ELSE '''''''''''''''' END + CONVERT(nvarchar(10), MemberId % 100) ELSE
										CASE WHEN MemberId = -1 THEN ''''''''NONE'''''''' ELSE
										CASE WHEN MemberId = 1 THEN ''''''''All_'''''''' ELSE
										CASE WHEN MemberId = '''' + CONVERT(nvarchar(10), @MemberId) + '''' THEN ''''''''pcPlaceHolder'''''''' END END END END END END END
								FROM
									'''' + @CallistoDatabase + ''''..[S_DS_'''' + @DimensionName + ''''] SD
								WHERE
									((Label <> CONVERT(nvarchar(10), MemberId) AND Level NOT IN (''''''''All_'''''''', ''''''''NONE'''''''', ''''''''Year'''''''', ''''''''Quarter'''''''', ''''''''Week'''''''')) OR
									(Label <> CASE WHEN '''' + CONVERT(nvarchar(10), @FiscalYearStartMonth) + '''' <> 1 THEN ''''''''FY'''''''' ELSE '''''''''''''''' END + CONVERT(nvarchar(10), MemberId) AND Level IN (''''''''Year'''''''')) OR
									(Label <> CONVERT(nvarchar(10), MemberId / 10) + CASE WHEN '''' + CONVERT(nvarchar(10), @FiscalYearStartMonth) + '''' <> 1 THEN ''''''''FQ'''''''' ELSE ''''''''Q'''''''' END + CONVERT(nvarchar(10), MemberId % 10) AND Level IN (''''''''Quarter'''''''')) OR
									(Label <> CONVERT(nvarchar(10), MemberId / 1000) + ''''''''W'''''''' + CASE WHEN MemberId % 100 <= 9 THEN ''''''''0'''''''' ELSE '''''''''''''''' END + CONVERT(nvarchar(10), MemberId % 100) AND Level IN (''''''''Week'''''''')) OR
									(MemberId = -1 AND Label <> ''''''''NONE'''''''') OR
									(MemberId = 1 AND Label <> ''''''''All_'''''''') OR
									(MemberId = '''' + CONVERT(nvarchar(10), @MemberId) + '''' AND Label <> ''''''''pcPlaceHolder'''''''')) AND
									MemberId <= '''' + CONVERT(nvarchar(10), @MemberId) + '''''''''

SET @SQLStatement = @SQLStatement + '

								IF @Debug <> 0 PRINT @SQLStatement
								EXEC (@SQLStatement) 

								SET @Updated_Step = @Updated_Step + @@ROWCOUNT

							END

					IF @Updated_Step > 0
						BEGIN
							SET @SQLStatement = ''''
								TRUNCATE TABLE '''' + @CallistoDatabase + ''''..[O_DS_'''' + @DimensionName + '''']

								INSERT INTO '''' + @CallistoDatabase + ''''..[O_DS_'''' + @DimensionName + '''']
								SELECT * FROM '''' + @CallistoDatabase + ''''..[S_DS_'''' + @DimensionName + '''']''''

							IF @Debug <> 0 PRINT @SQLStatement
							EXEC (@SQLStatement) 
						END

					SET @Updated = @Updated + @Updated_Step

					FETCH NEXT FROM CheckLabel_Cursor INTO @ObjectName, @DimensionName, @DimensionID, @MemberId
				END

		CLOSE CheckLabel_Cursor
		DEALLOCATE CheckLabel_Cursor	

		IF @Debug <> 0 SELECT Updated = @Updated

	SET @Step = ''''Drop temp tables''''
		DROP TABLE #DimensionList

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END

-----------
SET @Step = 'CREATE PROCEDURE spIU_wrk_FACT_FxTrans'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spIU_wrk_FACT_FxTrans' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spIU_wrk_FACT_FxTrans]

	@JobID int = 0,
	@ETLDatabase nvarchar(100) = ''''' + @ETLDatabase + ''''',
	@CallistoDatabase nvarchar(100) = ''''' + @CallistoDatabase + ''''',
	@ModelName nvarchar(100) = '''''''',
	@Simulation_MemberId bigint = NULL,
	@Debug bit = 0,
	@GetVersion bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

--EXEC [spIU_wrk_FACT_FxTrans] @ModelName = ''''Financials'''', @Debug = 1
--EXEC [spIU_wrk_FACT_FxTrans] @ModelName = ''''Sales'''', @Debug = 1
--EXEC [spIU_wrk_FACT_FxTrans] @ModelName = ''''AccountPayable'''', @Debug = 1
--EXEC [spIU_wrk_FACT_FxTrans] @ModelName = ''''AccountReceivable'''', @Debug = 1

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@UserID nvarchar(100),
	@Dimension nvarchar(100),
	@ParameterName nvarchar(100),
	@MemberId nvarchar(20),
	@BusinessProcess nvarchar(100),
	@Entity nvarchar(100),
	@Scenario nvarchar(100),
	@Time nvarchar(100),
	@TimeDay nvarchar(100),
	@Simulation nvarchar(100),
	@BusinessRule nvarchar(100),
	@Description nvarchar(255),
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		IF @Version = ''''1.3.2118'''' SET @Description = ''''Procedure created''''

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @Debug OUTPUT

		SELECT @UserID = SUSER_NAME()
		SELECT @Simulation_MemberId = -1

	SET @Step = ''''Check all parameters are set''''
		CREATE TABLE #Dimension ([DimensionID] int, [DimensionTypeID] int, [DimensionName] nvarchar(100), [ParameterName] nvarchar(100))'

SET @SQLStatement = @SQLStatement + '

		SET @SQLStatement = ''''
			INSERT INTO #Dimension 
				(
				[DimensionID],
				[DimensionTypeID],
				[DimensionName],
				[ParameterName]
				)
			SELECT DISTINCT
				[DimensionID] = D.[DimensionID],
				[DimensionTypeID] = MO.[DimensionTypeID],
				[DimensionName] = MD.[Dimension],
				[ParameterName] = CASE WHEN MO.DimensionTypeID IN(2, 4, 6, 7, 17, 39) THEN MD.[Dimension] + ''''''''Mbrs'''''''' END
			FROM
				'''' + @CallistoDatabase + ''''..ModelDimensions MD
				INNER JOIN '''' + @ETLDatabase + ''''..MappedObject MO ON MO.Entity = ''''''''-1'''''''' AND MO.DimensionTypeID IN(2, 4, 6, 7, 17, 39) AND MO.ObjectTypeBM & 2 > 0 AND MO.MappedObjectName = MD.Dimension AND MO.SelectYN <> 0
				INNER JOIN pcINTEGRATOR..Dimension D ON D.DimensionTypeID = MO.DimensionTypeID AND D.DimensionName = MO.ObjectName
			WHERE
				MD.Model = '''''''''''' + @ModelName + ''''''''''''''''

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Add rows to temp table #Dimension'''', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		IF @Debug <> 0 SELECT Temptable = ''''#Dimension'''', * FROM #Dimension

		IF (SELECT COUNT(1) FROM #Dimension WHERE DimensionTypeID = 7 AND DimensionID = -7) = 0
			BEGIN
				SET @SQLStatement = ''''
					INSERT INTO #Dimension
						(
						[DimensionID],
						[DimensionTypeID],
						[DimensionName]
						)
					SELECT DISTINCT
						[DimensionID] = D.[DimensionID],
						[DimensionTypeID] = MO.[DimensionTypeID],
						[DimensionName] = MO.[MappedObjectName]
					FROM
						'''' + @ETLDatabase + ''''..MappedObject MO 
						INNER JOIN pcINTEGRATOR..Dimension D ON D.DimensionTypeID = MO.DimensionTypeID AND D.DimensionName = MO.ObjectName
					WHERE
						MO.Entity = -1 AND
						MO.ObjectName = ''''''''Time'''''''' AND
						MO.DimensionTypeID IN(7) AND
						MO.ObjectTypeBM & 2 > 0 AND
						MO.ObjectName = ''''''''Time''''''''''''

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

		SELECT
			@BusinessProcess = MAX(CASE WHEN DimensionTypeID = 2 THEN DimensionName END),
			@Entity = MAX(CASE WHEN DimensionTypeID = 4 THEN DimensionName END),
			@Scenario = MAX(CASE WHEN DimensionTypeID = 6 THEN DimensionName END),
			@Time = MAX(CASE WHEN DimensionID = -7 THEN DimensionName END),
			@TimeDay = MAX(CASE WHEN DimensionID = -49 THEN DimensionName END),
			@Simulation = MAX(CASE WHEN DimensionTypeID = 17 THEN DimensionName END),
			@BusinessRule = MAX(CASE WHEN DimensionTypeID = 39 THEN DimensionName END)
		FROM
			#Dimension

		IF @Debug <> 0 SELECT [BusinessProcess] = @BusinessProcess, [Entity] = @Entity, [Scenario] = @Scenario, [Time] = @Time, [TimeDay] = @TimeDay, [Simulation] = @Simulation'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create temptable #FACT_Update''''
		SET @SQLStatement = ''''
			CREATE TABLE ##FACT_Update
				(
				['''' + @BusinessProcess + ''''_MemberId] bigint,
				['''' + @Entity + ''''_MemberId] bigint,
				['''' + @Scenario + ''''_MemberId] bigint,
				['''' + @Time + ''''_MemberId] bigint
				)''''

		EXEC (@SQLStatement)
			
		SELECT * INTO #FACT_Update FROM ##FACT_Update

		DROP TABLE ##FACT_Update

	SET @Step = ''''Fill #FACT_Update''''
		
			INSERT INTO #FACT_Update
			SELECT DISTINCT
				[BusinessProcess_MemberId],
				[Entity_MemberId],
				[Scenario_MemberId],
				[Time_MemberId]
			FROM
				[wrk_FACT_Update]


	SET @Step = ''''Clean up data in FACT table that should be replaced.''''
		SET @SQLStatement = ''''
			DELETE F
			FROM
				'''' + @CallistoDatabase + ''''..FACT_'''' + @ModelName + ''''_default_partition F
				INNER JOIN #FACT_Update U ON U.'''' + @BusinessProcess + ''''_MemberId = F.'''' + @BusinessProcess + ''''_MemberId AND U.'''' + @Entity + ''''_MemberId = F.'''' + @Entity + ''''_MemberId AND U.'''' + @Scenario + ''''_MemberId = F.'''' + @Scenario + ''''_MemberId AND U.'''' + @Time + ''''_MemberId = CASE WHEN F.'''' + ISNULL(@TimeDay, @Time) + ''''_MemberId >= 19000000 THEN F.'''' + ISNULL(@TimeDay, @Time) + ''''_MemberId / 100 ELSE F.'''' + ISNULL(@TimeDay, @Time) + ''''_MemberId END
			WHERE
				F.['''' + @BusinessRule + ''''_MemberId] = 101 --Conversion '''' + 
				CASE WHEN @Simulation_MemberId IS NOT NULL THEN ''''AND F.['''' + ISNULL(@Simulation, '''''''') + ''''_MemberId] = '''' + CONVERT(nvarchar(10), @Simulation_MemberId) ELSE '''''''' END
		
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = ''''Execute procedure that inserts converted values.''''
		EXEC spIU_0000_FACT_FxTrans @UserID = @UserID, @ModelName = @ModelName, @BPType = ''''ETL'''', @Simulation_MemberId = @Simulation_MemberId, @Debug = @Debug, @Deleted = @Deleted OUT, @Inserted = @Inserted OUT,  @Updated = @Updated OUT

	SET @Step = ''''Drop temp table.''''
		DROP TABLE #FACT_Update
		DROP TABLE #Dimension
		
	SET @Step = ''''Set @Duration''''
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + '''' ('''' + @ModelName + '''')'''', @Duration, @Deleted, @Inserted, @Updated, @Version
		RETURN 0

	SET @Step = ''''Define exit point''''
		EXITPOINT:
		DROP TABLE #Dimension
		SET @Duration = GetDate() - @StartTime
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + '''' ('''' + ISNULL(@ModelName, ''''Mandatory parameters not set'''') + '''')'''', @Duration, @Deleted, @Inserted, @Updated, @Version
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END

SET @Step = 'CREATE PROCEDURE spRun_BR_All'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'spRun_BR_All' AND DatabaseName = @ETLDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[spRun_BR_All] 

@JobID int = 0,
@Model nvarchar(100) = ''''Financials'''',
@GetVersion bit = 0,
@Duration time(7) = ''''00:00:00'''' OUT,
@Deleted int = 0 OUT,
@Inserted int = 0 OUT,
@Updated int = 0 OUT,
@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

SET ANSI_WARNINGS OFF

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@Database nvarchar(100),
	@BR nvarchar(100),
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)


	SET @Step = ''''Create temp table #temp_parametervalues''''
		CREATE TABLE #temp_parametervalues
			(
			[ParameterName] [nvarchar](255) COLLATE DATABASE_DEFAULT NOT NULL,
			[MemberId] [bigint] NULL,
			[StringValue] [nvarchar](512) COLLATE DATABASE_DEFAULT NULL
			)'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Fill temp table #temp_parametervalues''''
		INSERT INTO #temp_parametervalues
			(
			[ParameterName],
			[MemberId]
			) 
		SELECT DISTINCT
			ParameterName = ''''BusinessProcessMbrs'''',
			MemberId = [BusinessProcess_MemberId]
		FROM
			[#FACT_Update]
		UNION SELECT DISTINCT
			ParameterName = ''''EntityMbrs'''',
			MemberId = [Entity_MemberId]
		FROM
			[#FACT_Update]
		UNION SELECT DISTINCT
			ParameterName = ''''ScenarioMbrs'''',
			MemberId = [Scenario_MemberId]
		FROM
			[#FACT_Update]
		UNION SELECT DISTINCT
			ParameterName = ''''TimeMbrs'''',
			MemberId = [Time_MemberId]
		FROM
			[#FACT_Update]

		INSERT INTO #temp_parametervalues
			(
			[ParameterName],
			[StringValue]
			) 
		SELECT
			[ParameterName] = ''''Model'''',
			[StringValue] = @Model

		INSERT INTO #temp_parametervalues
			(
			[ParameterName],
			[StringValue]
			) 
		SELECT
			[ParameterName] = ''''Userid'''',
			[StringValue] = suser_name()'

SET @SQLStatement = @SQLStatement + '

		IF @Debug <> 0 SELECT TempTable = ''''#temp_parametervalues'''', * FROM #temp_parametervalues

	SET @Step = ''''Execute all selected BusinessRules in a cursor.''''
		DECLARE BR_All_Cursor CURSOR FOR

			SELECT
				[Database],
				[BR] = BusinessRule + 
					CASE WHEN Param01 IS NULL OR Param01 = '''''''' THEN '''''''' ELSE '''' '''' + REPLACE(Param01, '''''''''''''''', '''''''''''''''''''''''') END + 
					CASE WHEN Param02 IS NULL OR Param02 = '''''''' THEN '''''''' ELSE '''', '''' + REPLACE(Param02, '''''''''''''''', '''''''''''''''''''''''') END + 
					CASE WHEN Param03 IS NULL OR Param03 = '''''''' THEN '''''''' ELSE '''', '''' + REPLACE(Param03, '''''''''''''''', '''''''''''''''''''''''') END + 
					CASE WHEN Param04 IS NULL OR Param04 = '''''''' THEN '''''''' ELSE '''', '''' + REPLACE(Param04, '''''''''''''''', '''''''''''''''''''''''') END + 
					CASE WHEN Param05 IS NULL OR Param05 = '''''''' THEN '''''''' ELSE '''', '''' + REPLACE(Param05, '''''''''''''''', '''''''''''''''''''''''') END
			FROM
				' + @CallistoDatabase + '.dbo.S_LST_BusinessRuleETL
			WHERE
				Model = @Model AND
				SelectYN <> 0
			ORDER BY
				SortOrder

			OPEN BR_All_Cursor
			FETCH NEXT FROM BR_All_Cursor INTO @Database, @BR

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @Step = ''''Execute '''' + @BR
					IF @Debug <> 0 SELECT BR = @BR

					SET @SQLStatement = ''''EXEC '''' + @Database + ''''.dbo.sp_executesql N'''''''''''' + @BR + ''''''''''''''''

					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Execution of BusinessRule'''', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)

					FETCH NEXT FROM BR_All_Cursor INTO @Database, @BR
				END

		CLOSE BR_All_Cursor
		DEALLOCATE BR_All_Cursor'

SET @SQLStatement = @SQLStatement + '	

	SET @Step = ''''Drop temp tables''''	
		DROP TABLE #temp_parametervalues

	SET @Step = ''''Set @Duration''''	
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
		
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END

-----------
	END --END of pcETL Procedures

--------------------
IF @DataBaseBM & 2 > 0 --pcDATA
--------------------
	BEGIN

SET @Step = 'Add rows to table [EventDefinition] in the pcDATA database'

IF @Version > '1.3'
	BEGIN
 		CREATE TABLE #Number
			(
			[Number] int
			)
		INSERT INTO #Number ([Number]) EXEC('SELECT Number = COUNT(1) FROM ' + @CallistoDatabase + '..EventDefinition')
		SELECT @Number = [Number] FROM #Number
		DROP TABLE #Number
 
		IF @Number = 0
			 BEGIN
				SET @SQLStatement = '
				INSERT ' + @CallistoDatabase + '.[dbo].[EventDefinition] ([Event], [Action], [ActionType], [ActionDescription], [SequenceNumber]) VALUES (N''EndDeploy'', N''Canvas_Asumption_AccountUpdate'', 1, N''Update Canvas AccountAssumption'', 1)'
--				INSERT ' + @CallistoDatabase + '.[dbo].[EventDefinition] ([Event], [Action], [ActionType], [ActionDescription], [SequenceNumber]) VALUES (N''StartDeploy'', N''Canvas_FullAccount'', 1, N''Update FullAccount Hierarchy'', 1)'

				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)
			END
	END

SET @Step = 'CREATE PROCEDURE Canvas_Get_BrandInfo'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Get_BrandInfo' AND DatabaseName = @CallistoDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[Canvas_Get_BrandInfo]

	@BrandID int = NULL OUTPUT,
	@OrgBrand nvarchar(50) = NULL OUTPUT,
	@ProductName nvarchar(50) = NULL OUTPUT,
	@LongName nvarchar(100) = NULL OUTPUT,
	@Version nvarchar(50) = NULL OUTPUT,
	@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC [Canvas_Get_BrandInfo] @Debug = 1

DECLARE
	@InstanceID int,
	@CallistoDatabase nvarchar(100)

SELECT @CallistoDatabase = DB_NAME()

SELECT @InstanceID = InstanceID FROM pcINTEGRATOR..[Application] WHERE DestinationDatabase = @CallistoDatabase

IF @Debug <> 0 SELECT InstanceID = @InstanceID, CallistoDatabase = @CallistoDatabase

EXEC pcINTEGRATOR..[spGet_Version] @InstanceID = @InstanceID, @GetVersion = 0, @Version = @Version OUTPUT, @BrandID = @BrandID OUTPUT, @ProductName = @ProductName OUTPUT, @LongName = @LongName OUTPUT, @OrgBrand = @OrgBrand OUTPUT

SELECT
	BrandID = @BrandID,
	OrgBrand = @OrgBrand,
	ProductName = @ProductName,
	LongName = @LongName,
	[Version] = @Version'

				SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END

SET @Step = 'CREATE PROCEDURE Canvas_Get_Logo'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Get_Logo' AND DatabaseName = @CallistoDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[Canvas_Get_Logo]
	@TypeID int = 2,
	@BrandID int = NULL,
	@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC Canvas_Get_Logo
--EXEC Canvas_Get_Logo @Debug = 1

DECLARE
	@Image varbinary(max),
	@InstanceID int,
	@CallistoDatabase nvarchar(100)

SELECT @CallistoDatabase = DB_NAME()

SELECT @InstanceID = InstanceID FROM pcINTEGRATOR..[Application] WHERE DestinationDatabase = @CallistoDatabase

IF @Debug <> 0 SELECT InstanceID = @InstanceID, CallistoDatabase = @CallistoDatabase

IF @BrandID IS NULL
	EXEC [pcINTEGRATOR]..[spGet_Version] @InstanceID = @InstanceID, @GetVersion = 0, @BrandID = @BrandID OUTPUT

IF @Debug <> 0 SELECT TypeID = @TypeID, BrandID = @BrandID

SELECT 
	@Image = [LogoType]
FROM
	[pcINTEGRATOR].[dbo].[LogoType]
WHERE
	TypeID = @TypeID AND
	BrandID = @BrandID

SELECT [LogoType] = CAST('''''''' as xml).value(''''xs:base64Binary(sql:variable(''''''''@Image''''''''))'''', ''''varchar(max)'''')'

				SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)
			  END

SET @Step = 'CREATE PROCEDURE Canvas_ETL_JobLog'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_ETL_JobLog' AND DatabaseName = @CallistoDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE Canvas_ETL_JobLog

@ETLDatabase nvarchar(100) = ''''' + @ETLDatabase + ''''',
@JobName nvarchar(128) = ''''pcDATA_' + @ApplicationName + '_Load'''',
@TopCount int = 50,
@GetVersion bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@SQLStatement nvarchar(max),
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

SET @SQLStatement = ''''
SELECT TOP '''' + convert(nvarchar, @TopCount) + ''''
	sub.StartTime,
	sub.Duration,
	sub.JobName,
	sub.[User],
	sub.JobStatus,
	sub.ErrorMessage
FROM
	(
	SELECT
		StartTime = CONVERT(datetime, SUBSTRING(CONVERT(nvarchar, H.run_date), 1, 4) + ''''''''-'''''''' + SUBSTRING(CONVERT(nvarchar, H.run_date), 5, 2) + ''''''''-'''''''' + SUBSTRING(CONVERT(nvarchar, H.run_date), 7, 2) + '''''''' '''''''' + CONVERT(nvarchar, H.run_time / 10000) + '''''''':'''''''' + CONVERT(nvarchar, (H.run_time / 100) % 100) + '''''''':'''''''' + CONVERT(nvarchar, H.run_time % 100)),
		Duration = CASE WHEN (H.run_duration / 10000) % 100 <= 9 THEN ''''''''0'''''''' ELSE '''''''''''''''' END + CONVERT(nvarchar, (H.run_duration / 10000) % 100) + '''''''':'''''''' + CASE WHEN (H.run_duration / 100) % 100 <= 9 THEN ''''''''0'''''''' ELSE '''''''''''''''' END + CONVERT(nvarchar, (H.run_duration / 100) % 100) + '''''''':'''''''' + CASE WHEN H.run_duration % 100 <= 9 THEN ''''''''0'''''''' ELSE '''''''''''''''' END + CONVERT(nvarchar, H.run_duration % 100),
		JobName = J.name COLLATE DATABASE_DEFAULT,
		[User] = ''''''''Server'''''''',
		JobStatus = CASE H.run_status WHEN 0 THEN ''''''''Failure'''''''' WHEN 1 THEN ''''''''OK'''''''' WHEN 3 THEN ''''''''Stopped'''''''' ELSE ''''''''Code: '''''''' + CONVERT(nvarchar, H.run_status) END,
		ErrorMessage = CASE WHEN H.run_status = 1 THEN '''''''''''''''' ELSE H.[message] END COLLATE DATABASE_DEFAULT
	FROM
		msdb..sysjobhistory H 
		INNER JOIN msdb..sysjobs J ON J.job_id = H.job_id AND J.name = '''''''''''' + @JobName + ''''''''''''
	WHERE
		H.step_id = 0

	UNION SELECT 
		StartTime,
		Duration = CASE WHEN DATEPART (hour, JL.Duration) <= 9 THEN ''''''''0'''''''' ELSE '''''''''''''''' END + CONVERT(nvarchar, DATEPART (hour, JL.Duration)) + '''''''':'''''''' + CASE WHEN DATEPART (minute, JL.Duration) <= 9 THEN ''''''''0'''''''' ELSE '''''''''''''''' END + CONVERT(nvarchar, DATEPART (minute, JL.Duration)) + '''''''':'''''''' + CASE WHEN DATEPART (second, JL.Duration) <= 9 THEN ''''''''0'''''''' ELSE '''''''''''''''' END + CONVERT(nvarchar, DATEPART (second, JL.Duration)),
		JobName = ProcedureName COLLATE DATABASE_DEFAULT,
		[User] = ''''''''Manual'''''''',
		JobStatus = CASE JL.ErrorNumber WHEN 0 THEN ''''''''OK'''''''' ELSE ''''''''Failure: '''''''' + CONVERT(nvarchar, JL.ErrorNumber) END,
		ErrorMessage = CASE WHEN JL.ErrorNumber = 0 THEN '''''''''''''''' ELSE JL.[ErrorMessage] END COLLATE DATABASE_DEFAULT
	FROM
		'''' + @ETLDatabase + ''''..JobLog JL
	WHERE
		JobID = 0
	) sub
ORDER BY 
	sub.StartTime DESC''''

EXEC (@SQLStatement)'

				SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END

SET @Step = 'CREATE PROCEDURE Canvas_ETL_CheckSum'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_ETL_CheckSum' AND DatabaseName = @CallistoDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE Canvas_ETL_CheckSum

@JobID int = NULL,
@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

--EXEC [Canvas_ETL_CheckSum] @Debug = 1

SET ANSI_WARNINGS OFF

DECLARE
	@Step nvarchar(255),
	@SQLStatement nvarchar(max),
	@ETLDatabase nvarchar(100),
	@Version nvarchar(50) = ''''' + @Version + '''''

	SET @Step = ''''Set procedure variables''''
		SELECT
			@ETLDatabase = ETLDatabase
		FROM
			pcINTEGRATOR..[Application] A
		WHERE
			A.DestinationDatabase = DB_NAME() AND
			A.ApplicationID > 0 AND
			A.SelectYN <> 0

		IF @Debug <> 0 SELECT ETLDatabase = @ETLDatabase

		IF @JobID IS NULL
			BEGIN
				CREATE TABLE #JobID (JobID int)
				SET @SQLStatement = ''''
					INSERT INTO #JobID (JobID) SELECT JobID = MAX([JobID]) FROM '''' + @ETLDatabase + ''''.[dbo].[Job]''''
				EXEC (@SQLStatement) 
				SELECT @JobID = JobID FROM #JobID
				DROP TABLE #JobID
			END

		IF @Debug <> 0 SELECT JobID = @JobID

	SET @Step = ''''Get JobLog''''
		SET @SQLStatement = ''''
			SELECT
				CSL.JobID,
				CS.CheckSumID,
				CS.CheckSumName,
				CS.CheckSumDescription,
				CSL.CheckSumValue,
				CSL.EndTime,
				CS.CheckSumReport
			FROM
				'''' + @ETLDatabase + ''''..CheckSumLog CSL
				INNER JOIN '''' + @ETLDatabase + ''''..[CheckSum] CS ON CS.CheckSumID = CSL.CheckSumID AND CS.SelectYN <> 0
			WHERE
				CSL.JobID = '''' + CONVERT(nvarchar(10), @JobID) + ''''
			ORDER BY
				CS.SortOrder''''
		
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)'

				SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END

SET @Step = 'CREATE PROCEDURE Canvas_ETL_LoadAll'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_ETL_LoadAll' AND DatabaseName = @CallistoDatabase) = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE dbo.[Canvas_ETL_LoadAll]
	@ApplicationID int = NULL, 
	@StepName nvarchar(255) = ''''Load'''', --''''Create'''', ''''Import'''', ''''Load'''' or ''''Deploy''''
	@AsynchronousYN bit = 0,
	@GetVersion bit = 0,
	@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN

	IF @ApplicationID IS NULL
		BEGIN
			SELECT @ApplicationID = MAX(ApplicationID) FROM [pcINTEGRATOR].[dbo].[Application] WHERE ApplicationID <> 0
		END

	EXEC [pcINTEGRATOR].[dbo].[spStart_Job] 
		@ApplicationID = @ApplicationID,
		@StepName = @StepName,
		@AsynchronousYN = @AsynchronousYN,
		@Debug = @Debug 

END'

				SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)

			  END

SET @Step = 'CREATE PROCEDURE Canvas_ETL_RefreshData'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_ETL_RefreshData' AND DatabaseName = @CallistoDatabase) = 0
			BEGIN

				SELECT
					@SQLProcedureList = @SQLProcedureList + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'EXEC ' + @ETLDatabase + '.[dbo].[spIU_' + 
					CASE LEN(S.SourceID) WHEN 1 THEN '000' WHEN 2 THEN '00' WHEN 3 THEN '0' ELSE '' END + CONVERT(nvarchar, S.SourceID) + '_FACT_' + M.ModelName + '] @Entity_MemberId = @Entity_MemberId'
				FROM
					pcINTEGRATOR.dbo.Source S
					INNER JOIN pcINTEGRATOR.dbo.Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0 AND M.ModelID > 0
				WHERE
					S.SelectYN <> 0 AND
					S.SourceID > 0

				SET @SQLStatement = 'CREATE PROCEDURE dbo.[Canvas_ETL_RefreshData]

@GetVersion bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END


BEGIN

	DECLARE
		@Entity_MemberId bigint,
		@Entity Nvarchar(255)
	
	CREATE TABLE #ParamTable 
		(
		MemberId bigint,
		Entity nvarchar(255) COLLATE DATABASE_DEFAULT
		)
	
	INSERT INTO #ParamTable
	SELECT DISTINCT
		MemberId = a.MemberId,
		Entity = b.Label
	FROM
		HC_Entity a
		INNER JOIN DS_Entity b ON b.MemberId = a.MemberId
	WHERE
		a.ParentId IN (SELECT MemberId FROM #Temp_ParameterValues WHERE ParameterName = ''''EntityMbrs'''')
	
	DECLARE Dim_cursor CURSOR FOR 
	
		SELECT
			[MemberId],
			[Entity]
		FROM
			#ParamTable
	
	OPEN Dim_cursor
		FETCH NEXT FROM Dim_cursor INTO @Entity_MemberId, @Entity
		WHILE @@FETCH_STATUS = 0
			BEGIN' + @SQLProcedureList + '
				FETCH NEXT FROM Dim_cursor INTO @Entity_MemberId, @Entity
			END
	CLOSE Dim_cursor
	DEALLOCATE Dim_cursor
	DROP TABLE #ParamTable
END'

				SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)
			  END

SET @Step = 'CREATE PROCEDURE Canvas_FxTrans'
		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_FxTrans' AND DatabaseName = @CallistoDatabase) = 0
--		IF 1 = 0
			BEGIN
				SET @SQLStatement = 'CREATE PROCEDURE [dbo].[Canvas_FxTrans]

	@JobID int = 0,
	@ETLDatabase nvarchar(100) = ''''' + @ETLDatabase + ''''',
	@GetVersion bit = 0,
	@Duration time(7) = ''''00:00:00'''' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@UserID nvarchar(100),
	@ModelName nvarchar(100),
	@Dimension nvarchar(100),
	@ParameterName nvarchar(100),
	@MemberId nvarchar(20),
	@SQLWhere nvarchar(max) = '''''''',
	@Simulation_MemberId bigint = -1,
	@BusinessProcess nvarchar(100),
	@Entity nvarchar(100),
	@Scenario nvarchar(100),
	@Time nvarchar(100),
	@TimeDay nvarchar(100),
	@Simulation nvarchar(100),
	@BusinessRule nvarchar(100),
	@Debug bit,
	@Description nvarchar(255),
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		IF @Version = ''''1.3.2112'''' SET @Description = ''''Procedure created''''

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()

	SET @Step = ''''Set procedure variables''''
		EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @Debug OUTPUT

		SELECT @UserID = Stringvalue FROM #temp_parametervalues WHERE ParameterName = ''''UserId''''
		SELECT @ModelName = Stringvalue FROM #temp_parametervalues WHERE ParameterName = ''''Model''''
		SELECT @Simulation_MemberId = MemberId FROM #temp_parametervalues WHERE ParameterName = ''''SimulationMbrs''''

	SET @Step = ''''Capture ParameterValues''''
		IF @Debug <> 0
			BEGIN
				TRUNCATE TABLE [wrk_ParameterValues]
				INSERT INTO [wrk_ParameterValues] SELECT * FROM #temp_parametervalues
			END'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Check all parameters are set''''
		CREATE TABLE #Dimension ([DimensionID] int, [DimensionTypeID] int, [DimensionName] nvarchar(100), [ParameterName] nvarchar(100))

		SET @SQLStatement = ''''
			INSERT INTO #Dimension 
				(
				[DimensionID],
				[DimensionTypeID],
				[DimensionName],
				[ParameterName]
				)
			SELECT DISTINCT
				[DimensionID] = D.[DimensionID],
				[DimensionTypeID] = MO.[DimensionTypeID],
				[DimensionName] = MD.[Dimension],
				[ParameterName] = CASE WHEN MO.DimensionTypeID IN(2, 4, 6, 7) THEN MD.[Dimension] + ''''''''Mbrs'''''''' END
			FROM
				ModelDimensions MD
				INNER JOIN '''' + @ETLDatabase + ''''..MappedObject MO ON MO.Entity = ''''''''-1'''''''' AND MO.DimensionTypeID IN(2, 4, 6, 7, 17, 39) AND MO.ObjectTypeBM & 2 > 0 AND MO.MappedObjectName = MD.Dimension AND MO.SelectYN <> 0
				INNER JOIN pcINTEGRATOR..Dimension D ON D.DimensionTypeID = MO.DimensionTypeID AND D.DimensionName = MO.ObjectName
			WHERE
				MD.Model = '''''''''''' + @ModelName + ''''''''''''''''

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Add rows to temp table #Dimension'''', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		IF @Debug <> 0 SELECT Temptable = ''''#Dimension'''', * FROM #Dimension

		IF (SELECT COUNT(1) FROM #Dimension WHERE DimensionTypeID = 7 AND DimensionID = -7) = 0
			BEGIN
				SET @SQLStatement = ''''
					INSERT INTO #Dimension
						(
						[DimensionID],
						[DimensionTypeID],
						[DimensionName]
						)
					SELECT DISTINCT
						[DimensionID] = D.[DimensionID],
						[DimensionTypeID] = MO.[DimensionTypeID],
						[DimensionName] = MO.[MappedObjectName]
					FROM
						'''' + @ETLDatabase + ''''..MappedObject MO 
						INNER JOIN pcINTEGRATOR..Dimension D ON D.DimensionTypeID = MO.DimensionTypeID AND D.DimensionName = MO.ObjectName
					WHERE
						MO.Entity = -1 AND
						MO.ObjectName = ''''''''Time'''''''' AND
						MO.DimensionTypeID IN(7) AND
						MO.ObjectTypeBM & 2 > 0 AND
						MO.ObjectName = ''''''''Time''''''''''''

				IF @Debug <> 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END'

SET @SQLStatement = @SQLStatement + '

		SELECT
			@BusinessProcess = MAX(CASE WHEN DimensionTypeID = 2 THEN DimensionName END),
			@Entity = MAX(CASE WHEN DimensionTypeID = 4 THEN DimensionName END),
			@Scenario = MAX(CASE WHEN DimensionTypeID = 6 THEN DimensionName END),
			@Time = MAX(CASE WHEN DimensionID = -7 THEN DimensionName END),
			@TimeDay = MAX(CASE WHEN DimensionID = -49 THEN DimensionName END),
			@Simulation = MAX(CASE WHEN DimensionTypeID = 17 THEN DimensionName END),
			@BusinessRule = MAX(CASE WHEN DimensionTypeID = 39 THEN DimensionName END)
		FROM
			#Dimension

		IF @Debug <> 0 SELECT [BusinessProcess] = @BusinessProcess, [Entity] = @Entity, [Scenario] = @Scenario, [Time] = @Time, [TimeDay] = @TimeDay, [Simulation] = @Simulation

		IF (SELECT COUNT(DISTINCT tpv.ParameterName) FROM #temp_parametervalues tpv INNER JOIN #Dimension dn ON dn.ParameterName = tpv.ParameterName) <> 4
			GOTO EXITPOINT

	SET @Step = ''''Create temptable #FACT_Update''''
		SET @SQLStatement = ''''
			CREATE TABLE ##FACT_Update
				(
				['''' + @BusinessProcess + ''''_MemberId] bigint,
				['''' + @Entity + ''''_MemberId] bigint,
				['''' + @Scenario + ''''_MemberId] bigint,
				['''' + @Time + ''''_MemberId] bigint
				)''''

		EXEC (@SQLStatement)
			
		SELECT * INTO #FACT_Update FROM ##FACT_Update

		DROP TABLE ##FACT_Update

	SET @Step = ''''Declare cursor for WHERE clause''''
		DECLARE Fx_All_Dim_Cursor CURSOR FOR

			SELECT DISTINCT
				Dimension = dn.DimensionName + ''''_MemberId'''' + CASE WHEN dn.DimensionID = -49 THEN '''' / 100'''' ELSE '''''''' END,
				ParameterName = tpv.ParameterName
			FROM
				#temp_parametervalues tpv
				INNER JOIN #Dimension dn ON dn.ParameterName = tpv.ParameterName

			OPEN Fx_All_Dim_Cursor
			FETCH NEXT FROM Fx_All_Dim_Cursor INTO @Dimension, @ParameterName

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLWhere = @SQLWhere + CASE WHEN LEN(@SQLWhere) = 0 THEN '''''''' ELSE '''' AND '''' END + @Dimension + '''' IN (''''
					DECLARE Fx_Dim_Cursor CURSOR FOR

						SELECT DISTINCT
							--MemberId = tpv.MemberId
							MemberId = CASE WHEN dn.DimensionID = -49 AND tpv.MemberId >= 19000000 THEN tpv.MemberId / 100 ELSE tpv.MemberId END
						FROM
							#temp_parametervalues tpv
							INNER JOIN #Dimension dn ON dn.ParameterName = tpv.ParameterName
						WHERE
							tpv.ParameterName = @ParameterName

						OPEN Fx_Dim_Cursor
						FETCH NEXT FROM Fx_Dim_Cursor INTO @MemberId

						WHILE @@FETCH_STATUS = 0
							BEGIN

								SET @SQLWhere = @SQLWhere + @MemberId + '''', ''''

								FETCH NEXT FROM Fx_Dim_Cursor INTO @MemberId
							END'

SET @SQLStatement = @SQLStatement + '

					CLOSE Fx_Dim_Cursor
					DEALLOCATE Fx_Dim_Cursor

					SET @SQLWhere = SUBSTRING(@SQLWhere, 1, LEN(@SQLWhere) - 1) + '''')''''

					FETCH NEXT FROM Fx_All_Dim_Cursor INTO @Dimension, @ParameterName
				END

		CLOSE Fx_All_Dim_Cursor
		DEALLOCATE Fx_All_Dim_Cursor	

	SET @Step = ''''Fill #FACT_Update''''
		SET @SQLStatement = ''''
			INSERT INTO #FACT_Update
				(
				['''' + @BusinessProcess + ''''_MemberId],
				['''' + @Entity + ''''_MemberId],
				['''' + @Scenario + ''''_MemberId],
				['''' + @Time + ''''_MemberId]
				)
			SELECT DISTINCT
				['''' + @BusinessProcess + ''''_MemberId],
				['''' + @Entity + ''''_MemberId],
				['''' + @Scenario + ''''_MemberId],
				['''' + @Time + ''''_MemberId] = CASE WHEN ['''' + ISNULL(@TimeDay, @Time) + ''''_MemberId] >= 19000000 THEN ['''' + ISNULL(@TimeDay, @Time) + ''''_MemberId] / 100 ELSE ['''' + ISNULL(@TimeDay, @Time) + ''''_MemberId] END
			FROM
				[FACT_'''' + @ModelName + ''''_default_partition]
			WHERE
				'''' + @SQLWhere

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Query to fill #FACT_Update'''', [SQLStatement] = @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = ''''Clean up data in FACT table that should be replaced.''''
		SET @SQLStatement = ''''
			DELETE F
			FROM
				FACT_'''' + @ModelName + ''''_default_partition F
				INNER JOIN #FACT_Update U ON U.'''' + @BusinessProcess + ''''_MemberId = F.'''' + @BusinessProcess + ''''_MemberId AND U.'''' + @Entity + ''''_MemberId = F.'''' + @Entity + ''''_MemberId AND U.'''' + @Scenario + ''''_MemberId = F.'''' + @Scenario + ''''_MemberId AND U.'''' + @Time + ''''_MemberId = CASE WHEN F.'''' + ISNULL(@TimeDay, @Time) + ''''_MemberId >= 19000000 THEN F.'''' + ISNULL(@TimeDay, @Time) + ''''_MemberId / 100 ELSE F.'''' + ISNULL(@TimeDay, @Time) + ''''_MemberId END
			WHERE
				F.['''' + @BusinessRule + ''''_MemberId] = 101 --Conversion '''' + 
				CASE WHEN @Simulation IS NOT NULL THEN ''''AND F.['''' + ISNULL(@Simulation, '''''''') + ''''_MemberId] = '''' + CONVERT(nvarchar(10), @Simulation_MemberId) ELSE '''''''' END
		
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT'

SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Execute procedure that inserts converted values.''''
		EXEC ' + @ETLDatabase + '..spIU_0000_FACT_FxTrans @UserID = @UserID, @ModelName = @ModelName, @BPType = ''''BP'''', @Simulation_MemberId = @Simulation_MemberId, @Debug = @Debug, @Deleted = @Deleted OUT, @Inserted = @Inserted OUT,  @Updated = @Updated OUT

	SET @Step = ''''Drop temp table.''''
		DROP TABLE #FACT_Update
		DROP TABLE #Dimension
		
	SET @Step = ''''Set @Duration''''
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert into JobLog''''
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + '''' ('''' + @ModelName + '''')'''', @Duration, @Deleted, @Inserted, @Updated, @Version
		RETURN 0

	SET @Step = ''''Define exit point''''
		EXITPOINT:
		DROP TABLE #Dimension
		SET @Duration = GetDate() - @StartTime
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + '''' ('''' + ISNULL(@ModelName, ''''Mandatory parameters not set'''') + '''')'''', @Duration, @Deleted, @Inserted, @Updated, @Version
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE()
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

				SET @SQLStatement = 'EXEC ' + @CallistoDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0
					BEGIN
						PRINT @SQLStatement 
						INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = @Step, [SQLStatement] = @SQLStatement
					END
						
				EXEC (@SQLStatement)
			  END

	END --END of pcDATA Procedures

-------------------------------
SET @Step = 'CREATE FUNCTIONS'
-------------------------------
IF @Debug <> 0 PRINT @Step

IF @DataBaseBM & 1 > 0 --pcETL
	BEGIN

SET @Step = 'Create function f_GetSBZ'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Function' AND ObjectName = 'f_GetSBZ' AND DatabaseName = @ETLDatabase) = 0
			BEGIN

				SET @SQLStatement = 'CREATE FUNCTION [dbo].[f_GetSBZ]
(
    @DimensionID int,
	@RNodeType nvarchar(2),
	@Label nvarchar(255)
)
RETURNS bit
AS
BEGIN

	DECLARE
		@SBZ bit

	IF @RNodeType <> ''''L''''  --Not Leaf
		SET @SBZ = 1
	ELSE
		BEGIN
			IF (SELECT COUNT(1) FROM pcINTEGRATOR..Dimension WHERE DimensionID = @DimensionID AND HiddenMember LIKE ''''%|'''' + @Label + ''''|%'''' AND NOT (@DimensionID = -8 AND @Label = ''''RAWDATA'''')) > 0 --HiddenMember
				SET @SBZ = 1
			ELSE --Not Hidden Leaf
				SET @SBZ = 0
		END

	RETURN @SBZ       
END'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

			END

SET @Step = 'Create function f_ReplaceText'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Function' AND ObjectName = 'f_ReplaceText' AND DatabaseName = @ETLDatabase) = 0
			BEGIN

				SET @SQLStatement = 'CREATE FUNCTION [dbo].[f_ReplaceText]
(
    @InputText nvarchar(max),
	@StringTypeBM int --1 = Code, 2 = Text
)
RETURNS nvarchar(max)
AS
BEGIN
	IF @StringTypeBM = 1 --Code
		BEGIN
			SET @InputText = @InputText
		END

	ELSE IF @StringTypeBM = 2 --Text
		BEGIN
			SET @InputText = @InputText
		END

	RETURN @InputText       
END'
 
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql spCreate_f_ReplaceText'
				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

			END

SET @Step = 'Create function f_ScanText'

		IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Function' AND ObjectName = 'f_ScanText' AND DatabaseName = @ETLDatabase) = 0
			BEGIN

				SET @SQLStatement = 'CREATE FUNCTION [dbo].[f_ScanText]
(
    @InputText nvarchar(max),
	@StringTypeBM int --1 = Code, 2 = Text
)

RETURNS nvarchar(max)
AS

BEGIN

DECLARE
	@Position int,
	@ReturnStatement nvarchar(max) = ''''''''

	IF @StringTypeBM = 1 --Code
		BEGIN
			SELECT @Position = CHARINDEX (char(0), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + ''''InputText = '''' + @InputText + '''', CharacterCode = char(0), Position = '''' + CONVERT(nvarchar, @Position) + ''''; ''''
		END

	ELSE IF @StringTypeBM = 2 --Text
		BEGIN
			SELECT @Position = CHARINDEX (char(0), @InputText) IF @Position <> 0 SET @ReturnStatement = @ReturnStatement + ''''InputText = '''' + @InputText + '''', CharacterCode = char(0), Position = '''' + CONVERT(nvarchar, @Position) + ''''; ''''
		END

	IF @ReturnStatement <> '''''''' SET @ReturnStatement = SUBSTRING(@ReturnStatement, 1, LEN(@ReturnStatement) - 1)
	RETURN @ReturnStatement      
END'
				
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql spCreate_f_ScanText'
				IF @Debug <> 0 PRINT @SQLStatement 
				EXEC (@SQLStatement)

			END


	END  --END of pcETL Functions

	SET @Step = 'Drop temp tables'	
		DROP TABLE #Object

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		RAISERROR ('100 percent', 0, 100) WITH NOWAIT
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version

	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
--	CLOSE ETL_Object_Cursor
--	DEALLOCATE ETL_Object_Cursor
	RETURN @ErrorNumber
END CATCH





GO
