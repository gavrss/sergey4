SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spCreate_Application] 

	@JobID int = 0,
	@ApplicationID int = NULL,
	@GetVersion bit = 0,
	@Debug bit = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--
AS

SET ANSI_WARNINGS OFF

--EXEC [spCreate_Application] @ApplicationID = 400, @Debug = 1
--EXEC [spCreate_Application] @ApplicationID = 600, @Debug = 1
--EXEC [spCreate_Application] @ApplicationID = 1358, @Debug = 1

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SourceID int,
	@SQLStatement nvarchar(MAX),
	@SourceDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@LanguageID int,
	@Model nvarchar(100),
	@MappedModel nvarchar(100),
	@Dimension nvarchar(100),
	@MappedDimension nvarchar(100),
	@Property nvarchar(100),
	@Hierarchy nvarchar(100),
	@MappedProperty nvarchar(100),
	@DimensionDescription nvarchar(255),
	@DimensionType nvarchar(50),
	@DataType nvarchar(50),
	@MemberDimension nvarchar(100),
	@MappedMemberDimension nvarchar(100),
	@Size int,
	@DefaultValue nvarchar(255),
	@ModelID int,
	@ValidYN bit,
	@ModelBM int,
	@SumModelBM int = 0,
	@BaseModelID int,
	@ModelYN bit,
	@OptFinanceDimYN bit,
	@TextSupportYN bit,
	@AssumptionModelName nvarchar(100),
	@AssumptionMappedModelName nvarchar(100),
	@DynamicRule nvarchar(max),
	@AdminUser nvarchar(100),
	@SecuredYN bit,
	@MaxTimeTypeBM int,
	@MinTimeTypeBM int,
	@StartupWorkbook nvarchar(50),
	@Total decimal(5,2),
	@Counter decimal(5,2) = 0,
	@CounterString nvarchar(100),
	@PercentDone int,
	@SourceTypeBM_All int,
	@DimensionName nvarchar(100),
	@MappedObjectName nvarchar(100),
	@pcEXCHANGE_SourceDB nvarchar(100),
	@ValueCheck int,
	@InstanceID int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '2.1.0.2155'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2058' SET @Description = 'All list handling excluded from this procedure'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.2.2065' SET @Description = 'Handle SourceTypeID = 6, pcEXCHANGE.'
		IF @Version = '1.3.2070' SET @Description = 'Handle SourceTypeID = 6, pcEXCHANGE. Mandatory Properties added'
		IF @Version = '1.3.2071' SET @Description = 'Handle FullAccount'
		IF @Version = '1.3.2074' SET @Description = 'Handle extra hierarchies'
		IF @Version = '1.3.2075' SET @Description = 'Changed from EntityCode to Entity'
		IF @Version = '1.3.2076' SET @Description = 'Removed tests on VisibleYN'
		IF @Version = '1.3.2088' SET @Description = 'Removed all translations, moved to a previous step.'
		IF @Version = '1.3.2089' SET @Description = 'Added translation properties.'
		IF @Version = '1.3.2095' SET @Description = 'Replaced MandatoryYN and VisibleYN with VisibilityLevelBM'
		IF @Version = '1.3.2097' SET @Description = 'Handle that join between Dimension and Property is CASE sensitive. Only for Segments.'
		IF @Version = '1.3.2107' SET @Description = 'No separate handling of pcEXCHANGE. Test on Nyc.'
		IF @Version = '1.3.2109' SET @Description = 'Exclude property MemberId.'
		IF @Version = '1.3.2111' SET @Description = 'Check on FiscalYearStartMonth when creating TimeWeek hierarchy in TimeDay dimension.'
		IF @Version = '1.3.2112' SET @Description = 'Added parameters for call of [spCreate_Application_BusinessRules].'
		IF @Version = '1.3.1.2120' SET @Description = 'Test on SourceTypeBM for Properties. Added extra properties and hierachies for pcEXCHANGE. Filter GL-segments on ModelBM in MappedObject'
		IF @Version = '1.3.1.2124' SET @Description = 'Security handling moved to [spCreate_Application_Security].'
		IF @Version = '1.4.0.2133' SET @Description = 'Check DynamicYN in table FinancialSegment when adding SegmentProperties used in FullAccount dimension.'
		IF @Version = '1.4.0.2135' SET @Description = 'Use Dimension_Property table instead of DimensionID in Property table.'
		IF @Version = '1.4.0.2136' SET @Description = 'Test on Introduced column in Dimension_Property table.'
		IF @Version = '1.4.0.2139' SET @Description = 'Read DataTypeCallisto instead of DataTypeName from table DataType .'
		IF @Version = '2.0.3.2154' SET @Description = 'Set correct MappedMemberDimension on #PropertyDefinition, typically relevant to SendTo.'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-479: Disable Herve menu by setting [StartWorkBook] to empty string.'

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
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		DECLARE Nyc_Cursor CURSOR FOR
			SELECT
				ModelID = MAX(M.ModelID),
				BM.ModelBM
			FROM
				Model M
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			WHERE
				M.ApplicationID = @ApplicationID AND
				M.SelectYN <> 0
			GROUP BY
				BM.ModelBM

			OPEN Nyc_Cursor
			FETCH NEXT FROM Nyc_Cursor INTO @ModelID, @ModelBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					EXEC spCheck_Feature @ModelID = @ModelID, @ValidYN = @ValidYN OUT, @Debug = @Debug
					SET @SumModelBM = @SumModelBM + @ModelBM * @ValidYN

					FETCH NEXT FROM Nyc_Cursor INTO @ModelID, @ModelBM
				END
		CLOSE Nyc_Cursor
		DEALLOCATE Nyc_Cursor	

		SELECT
			@InstanceID = MAX(A.InstanceID),
			@ETLDatabase = A.ETLDatabase,
			@LanguageID = MAX(A.LanguageID),
			@AdminUser = MAX(A.AdminUser),
			@MaxTimeTypeBM = MAX(BM.TimeTypeBM),
			@MinTimeTypeBM = MIN(BM.TimeTypeBM)
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & @SumModelBM > 0 AND BM.Introduced < @Version AND BM.SelectYN <> 0
		WHERE
			A.ApplicationID = @ApplicationID
		GROUP BY
			A.ETLDatabase

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		SELECT
			@SourceTypeBM_All = SUM(sub.SourceTypeBM)
		FROM
			(
			SELECT DISTINCT
				ST.SourceTypeBM
			FROM
				SourceType ST
				INNER JOIN [Source] S ON S.SourceTypeID = ST.SourceTypeID AND S.SelectYN <> 0
				INNER JOIN Model M ON M.ModelID = S.ModelID AND M.Introduced < @Version AND M.SelectYN <> 0 AND M.ApplicationID = @ApplicationID
			WHERE
				ST.SelectYN <> 0 AND
				ST.Introduced < @Version
			) sub

		IF @SourceTypeBM_All & 32 > 0
			BEGIN
				SELECT
					@pcEXCHANGE_SourceDB = MAX(S.SourceDatabase)
				FROM
					Source S
					INNER JOIN Model M ON M.ModelID = S.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
				WHERE
					S.SourceTypeID = 6 AND
					S.SelectYN <> 0
			END

		IF @Debug <> 0 SELECT [@Version] = @Version

	SET @Step = 'Truncate XT_tables'
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_BusinessRule]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleRequestFilters]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleStepRecordParameters]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleStepRecords]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_BusinessRuleSteps]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_DimensionDefinition]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_HierarchyLevels]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_MemberViewDefinition]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_ModelAssumptions]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_ModelDefinition]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_ModelDimensions]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		SET @SQLStatement = 'DELETE [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition]'
		EXEC (@SQLStatement)
		SET @Deleted = @Deleted + @@ROWCOUNT
			 
		/*
		The following XT-tables are not handled in this procedure.
		
		Those are all handled in "spCreate_ETL_Object_Initial":
		[XT_ListDefinition]
		[XT_ListFieldDefinition]
		[XT_LST_BSRuleDetail]
		[XT_LST_BSRuleMethods]
		[XT_LST_BSRules]
		[XT_LST_CashFlow_Setup]
		[XT_LST_CashFlowAmount]
		[XT_LST_DepreciationMethod]
		[XT_LST_KeyName]
		[XT_LST_Paid]

		Those are all handled in "spCreate_Application_Security":
		[XT_SecurityActionAccess]
		[XT_SecurityMemberAccess]
		[XT_SecurityModelRuleAccess]
		[XT_SecurityRoleDefinition]
		[XT_SecurityUser]
		[XT_UserDefinition]
		*/

/*
	SET @Step = 'Add static members'  --Temporary hardcoded
		SET @SQLStatement = '
		INSERT [' + @ETLDatabase + '].[dbo].[XT_SecurityRoleDefinition] ([Action], [Label], [Description], [LicenseUserType]) VALUES (NULL, N''FullAccess'', N''Full Access'', N''Unrestricted'')
		INSERT [' + @ETLDatabase + '].[dbo].[XT_SecurityRoleDefinition] ([Action], [Label], [Description], [LicenseUserType]) VALUES (NULL, N''Administrators'', N''Administrators'', N''Unrestricted'')
		INSERT [' + @ETLDatabase + '].[dbo].[XT_SecurityRoleDefinition] ([Action], [Label], [Description], [LicenseUserType]) VALUES (NULL, N''All Users'', N''All Application Users'', N''Unrestricted'')
		INSERT [' + @ETLDatabase + '].[dbo].[XT_SecurityUser] ([Role], [WinUser], [WinGroup]) VALUES (N''Administrators'', N''' + @AdminUser + ''', NULL)
		INSERT [' + @ETLDatabase + '].[dbo].[XT_SecurityUser] ([Role], [WinUser], [WinGroup]) VALUES (N''FullAccess'', N''' + @AdminUser + ''', NULL)
		INSERT [' + @ETLDatabase + '].[dbo].[XT_SecurityActionAccess] ([Role], [Label], [HideAction]) VALUES (N''FullAccess'', N''HideControlPanel'', 1)
		INSERT [' + @ETLDatabase + '].[dbo].[XT_SecurityActionAccess] ([Role], [Label], [HideAction]) VALUES (N''FullAccess'', N''CollapseControlPanel'', 1)
	'

		IF @Debug <> 0 PRINT (@SQLStatement)
		EXEC (@SQLStatement)
*/

	SET @Step = 'Add Hierarchy levels'
		--XT_HierarchyDefinition, extra hierarchies
		SET @SQLStatement = 
		'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition]
			(
			[Dimension],
			[Label]
			)
		SELECT DISTINCT
			[Dimension] = MO.MappedObjectName,
			[Label] = L.Hierarchy
		FROM
			[' + @ETLDatabase + '].[dbo].MappedObject MO
			INNER JOIN Dimension D ON (D.DimensionName = MO.ObjectName AND MO.DimensionTypeID <> -1) AND D.SelectYN <> 0 
			INNER JOIN Model_Dimension MD ON MD.DimensionID = D.DimensionID
			INNER JOIN Model BM ON BM.ModelID = MD.ModelID AND BM.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
			INNER JOIN Model M ON M.BaseModelID = BM.ModelID AND M.ApplicationID = ' + CONVERT(nvarchar, @ApplicationID) + ' AND M.SelectYN <> 0
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.SelectYN <> 0
			INNER JOIN [Level] L ON 
								L.DimensionID = D.DimensionID AND 
								L.Hierarchy <> ''Default'' AND 
								(L.FiscalYearStartMonth = 0 OR L.FiscalYearStartMonth = A.FiscalYearStartMonth) AND 
								(L.TimeTypeBM & ' + CONVERT(nvarchar, @MinTimeTypeBM) + ' > 0 OR L.TimeTypeBM & ' + CONVERT(nvarchar, @MaxTimeTypeBM) + ' > 0 OR L.TimeTypeBM = 0)
		WHERE
			ObjectTypeBM & 2 > 0 AND
			(MO.SelectYN <> 0 OR MD.VisibilityLevelBM & 8 > 0) AND
			NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition] XT WHERE XT.Dimension = MO.MappedObjectName AND XT.Label = L.Hierarchy) '

		IF @Debug <> 0 PRINT (@SQLStatement)
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

		SET @SQLStatement = '
		INSERT [' + @ETLDatabase + '].[dbo].[XT_HierarchyLevels]
			(
			[Action], 
			[Dimension], 
			[Hierarchy], 
			[LevelName], 
			[SequenceNumber]
			)
		SELECT DISTINCT
			[Action] = NULL,
			[Dimension] = MappedObjectName,
			[Hierarchy] = CASE WHEN L.Hierarchy = ''Default'' THEN MappedObjectName ELSE L.Hierarchy END,
			[LevelName] = L.LevelName,
			[SequenceNumber] = L.LevelID
		FROM
			[' + @ETLDatabase + '].[dbo].MappedObject MO
			INNER JOIN Dimension D ON (D.DimensionName = MO.ObjectName AND MO.DimensionTypeID <> -1) AND D.SelectYN <> 0
			INNER JOIN Model_Dimension MD ON MD.DimensionID = D.DimensionID
			INNER JOIN Model BM ON BM.ModelID = MD.ModelID AND BM.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
			INNER JOIN Model M ON M.BaseModelID = BM.ModelID AND M.ApplicationID = ' + CONVERT(nvarchar, @ApplicationID) + ' AND M.SelectYN <> 0
			INNER JOIN [Level] L ON L.DimensionID = D.DimensionID AND (L.TimeTypeBM & ' + CONVERT(nvarchar, @MinTimeTypeBM) + ' > 0 OR L.TimeTypeBM & ' + CONVERT(nvarchar, @MaxTimeTypeBM) + ' > 0 OR L.TimeTypeBM = 0)
		WHERE
			ObjectTypeBM & 2 > 0 AND
			(MO.SelectYN <> 0 OR MD.VisibilityLevelBM & 8 > 0)'

		IF @Debug <> 0 PRINT (@SQLStatement)
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Create #Models'
		CREATE TABLE #Models
		(
			Model nvarchar(100) COLLATE DATABASE_DEFAULT,
			MappedModel nvarchar(100) COLLATE DATABASE_DEFAULT,
			BaseModelID int,
			SourceID int,
			OptFinanceDimYN bit,
			TextSupportYN bit,
			DynamicRule nvarchar(max) COLLATE DATABASE_DEFAULT,
			ModelID int,
			StartupWorkbook nvarchar(50) --,
--			pcExchangeYN bit
		)

		SET @SQLStatement = '
		INSERT INTO #Models
			(
			Model,
			MappedModel,
			BaseModelID,
			SourceID,
			OptFinanceDimYN,
			TextSupportYN,
			DynamicRule,
			ModelID,
			StartupWorkbook --,
--			pcExchangeYN
			)
		SELECT
			Model = MO.ObjectName,
			MappedModel = MO.MappedObjectName,
			BaseModelID = M.BaseModelID,
			SourceID = S.SourceID,
			BM.OptFinanceDimYN,
			BM.TextSupportYN,
			ISNULL(BM.DynamicRule, ''''),
			M.ModelID,
			[StartupWorkbook] = ''''
			--ISNULL(BM.StartupWorkbook, '''') --,
--			pcExchangeYN = 0
		FROM
			Model M 
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.ModelBM & ' + CONVERT(nvarchar, @SumModelBM) + ' > 0 AND BM.VirtualYN = 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
			INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.ObjectName = BM.ModelName AND MO.ObjectTypeBM & 1 > 0
			LEFT JOIN Source S ON S.ModelID = M.ModelID AND S.SelectYN <> 0
			LEFT JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID
		WHERE
			M.ApplicationID = ' + CONVERT(nvarchar, @ApplicationID) + ' AND
			M.SelectYN <> 0'

		IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
		EXEC (@SQLStatement)
/*
-------------
	SET @Step = 'Add Models from pcEXCHANGE'
		SET @SQLStatement = '
		INSERT INTO #Models
			(
			Model,
			MappedModel,
			BaseModelID,
			SourceID,
			OptFinanceDimYN,
			TextSupportYN,
			DynamicRule,
			ModelID,
			StartupWorkbook,
			pcExchangeYN
			)
		SELECT
			Model = MO.ObjectName,
			MappedModel = MO.MappedObjectName,
			BaseModelID = M.BaseModelID,
			SourceID = S.SourceID,
			BM.OptFinanceDimYN,
			BM.TextSupportYN,
			ISNULL(BM.DynamicRule, ''''),
			BM.ModelID,
			ISNULL(BM.StartupWorkbook, ''''),
			pcExchangeYN = 1
		FROM
			[' + @SourceDatabase + '].[dbo].Model M 
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.VirtualYN = 0 AND BM.Introduced < ''' + @Version + ''' AND BM.SelectYN <> 0
			INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.ObjectName = BM.ModelName AND MO.ObjectTypeBM & 1 > 0
			INNER JOIN SourceType ST ON ST.SourceTypeID = 6
			INNER JOIN Source S ON S.SourceTypeID = ST.SourceTypeID AND S.SelectYN <> 0'

		IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
		EXEC (@SQLStatement)
*/
-------------
		CREATE TABLE #BaseModel
		(
			BaseModelID int
		)

	SET @Step = 'Calculate progress'
		SELECT
			@Total = COUNT(1) + 1
		FROM
			#Models

		SET @Counter = 1
		SET @CounterString = CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed'
		SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

		RAISERROR (@CounterString, 0, @PercentDone) WITH NOWAIT

		IF @Debug <> 0 SELECT TempTable = '#Models', * FROM #Models

	SET @Step = 'Loop on different SourceIDs'
		DECLARE Create_Model_Cursor CURSOR FOR

		--Get Definitions

		SELECT
			Model,
			MappedModel,
			BaseModelID,
			SourceID,
			OptFinanceDimYN,
			TextSupportYN,
			DynamicRule,
			ModelID,
			StartupWorkbook
		FROM
			#Models
	
		OPEN Create_Model_Cursor

		FETCH NEXT FROM Create_Model_Cursor INTO @Model, @MappedModel, @BaseModelID, @SourceID, @OptFinanceDimYN, @TextSupportYN, @DynamicRule, @ModelID, @StartupWorkbook

		WHILE @@FETCH_STATUS = 0
		  BEGIN
  
		  --PRINT 'ModelID = ' + CONVERT(nvarchar, @ModelID) + ', OptFinanceDimYN = ' + CONVERT(nvarchar, @OptFinanceDimYN)

		IF @Debug <> 0 SELECT ETLDatabase = @ETLDatabase, Model = @Model, BaseModelID = @BaseModelID, SourceID = @SourceID

		-----------------------------
		SET @Step = 'XT_ModelDefinition; ' + @Model
		-----------------------------
		SET @SQLStatement = '

		INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_ModelDefinition]
			(
			[Label],
			[Description],
			[ModelType],
			[TextSupport],
			[ChangeInfo],
			[StartupWorkbook]
			)
		SELECT
			[Label] = ''' + @MappedModel + ''',
			[Description] = ''' + @MappedModel + ''',
			[ModelType] = ''Generic'',
			[TextSupport] = ' + CONVERT(nvarchar, CONVERT(int, @TextSupportYN)) + ',
			[ChangeInfo] = 0,
			[StartupWorkbook] = ''' + @StartupWorkbook + '''
		WHERE
			NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_ModelDefinition] MD WHERE MD.Label = ''' + @MappedModel + ''')'
		
		IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

		-----------------------------
		SET @Step = 'XT_ModelAssumptions  (Has to be changed for handling multiple assumptions); ' + @Model
		-----------------------------

		SELECT
			@AssumptionModelName = BM.ModelName,
			@AssumptionMappedModelName = M.MappedModel
		FROM
			Model_Assumption MA
			INNER JOIN Model BM ON BM.ModelID = MA.AssumptionModelID
			INNER JOIN #Models M ON M.Model = BM.ModelName
		WHERE
			MA.ModelID = @BaseModelID

		IF @AssumptionModelName IS NOT NULL
		  BEGIN

			SET @SQLStatement = '

			INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_ModelAssumptions]
				(
					[Model],
					[AssumptionModel]
				)
				 SELECT
					[Model] = ''' + @MappedModel + ''',
					[AssumptionModel] = ''' + @AssumptionMappedModelName + '''
				WHERE
					NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_ModelAssumptions] MA WHERE MA.Model = ''' + @MappedModel + ''' AND MA.AssumptionModel = ''' + @AssumptionMappedModelName + ''')'

			SET @AssumptionModelName = NULL	
				
			IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
			EXEC (@SQLStatement)
			SET @Inserted = @Inserted + @@ROWCOUNT
		  END

		-----------------------------
		SET @Step = 'XT_DimensionDefinition & XT_HierarchyDefinition & XT_ModelDimensions; ' + @Model
		-----------------------------

		CREATE TABLE [#Dimensions](
			[DimensionName] [nvarchar](100) COLLATE DATABASE_DEFAULT NOT NULL,
			[MappedDimensionName] [nvarchar](100) COLLATE DATABASE_DEFAULT NOT NULL,
			[DimensionDescription] [nvarchar](255) COLLATE DATABASE_DEFAULT NOT NULL,
			[DimensionTypeName] [nvarchar](50) COLLATE DATABASE_DEFAULT NOT NULL,
			[Hierarchy] [nvarchar](50) COLLATE DATABASE_DEFAULT NULL,
			[SecuredYN] [bit] NOT NULL,
			[ModelYN] [int] NOT NULL
		)

		SET @SQLStatement = '
--Included Dimensions Model = ' + @Model + '
			INSERT INTO #Dimensions
				(
				DimensionName,
				MappedDimensionName,
				DimensionDescription,
				DimensionTypeName,
				[Hierarchy],
				[SecuredYN],
				ModelYN
				)
			SELECT DISTINCT
				DimensionName = MO.ObjectName,
				MappedDimensionName = MO.MappedObjectName,
				D.DimensionDescription,
				DT.DimensionTypeName,
				[Hierarchy] = ISNULL(MOH.MappedObjectName, D.Hierarchy),
				DT.[SecuredYN],
				ModelYN = CASE WHEN ((MO.ObjectTypeBM & 2 > 0 AND MO.ModelBM & BM.ModelBM > 0) OR MD.VisibilityLevelBM & 8 > 0) THEN 1 ELSE 0 END
			FROM
				Model M  
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
				INNER JOIN Model_Dimension MD ON MD.ModelID = M.BaseModelID
				INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.SelectYN <> 0
				INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.Entity = ''-1'' AND (MO.ObjectName = D.DimensionName AND MO.DimensionTypeID <> -1) AND (MO.SelectYN <> 0 OR MD.VisibilityLevelBM & 8 > 0)
				INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID
				LEFT JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MOH ON MOH.Entity = ''-1'' AND (MOH.ObjectName = D.Hierarchy AND MOH.DimensionTypeID <> -1) AND MOH.SelectYN <> 0
			WHERE
				M.ModelID = ' + CONVERT(nvarchar, @ModelID)

		SET @SQLStatement = @SQLStatement + '
--linked dims
			INSERT INTO #Dimensions
				(
				DimensionName,
				MappedDimensionName,
				DimensionDescription,
				DimensionTypeName,
				[Hierarchy],
				[SecuredYN],
				ModelYN
				)
			SELECT DISTINCT
				DimensionName = DMO.ObjectName,
				MappedDimensionName = DMO.MappedObjectName,
				DD.DimensionDescription,
				DDT.DimensionTypeName,
				[Hierarchy] = ISNULL(MOH.MappedObjectName, DD.Hierarchy),
				DDT.[SecuredYN],
				ModelYN = 0
			FROM
				Model M  
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
				INNER JOIN Model_Dimension MD ON MD.ModelID = M.BaseModelID AND MD.VisibilityLevelBM & 9 > 0
				INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.Introduced < ''' + @Version + ''' AND D.SelectYN <> 0
				INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.Entity = ''-1'' AND (MO.ObjectName = D.DimensionName AND MO.DimensionTypeID <> -1) AND (MO.SelectYN <> 0 OR MD.VisibilityLevelBM & 8 > 0)
				INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID
				INNER JOIN Dimension_Property DP ON DP.DimensionID = D.DimensionID AND DP.Introduced < ''' + @Version + ''' AND DP.SelectYN <> 0
				INNER JOIN Property P ON P.PropertyID = DP.PropertyID AND P.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM_All) + ' > 0 AND BM.Introduced < ''' + @Version + ''' AND P.SelectYN <> 0
				INNER JOIN Dimension DD ON DD.DimensionID = P.DependentDimensionID AND DD.SelectYN <> 0
				INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] DMO ON DMO.Entity = ''-1'' AND (DMO.ObjectName = DD.DimensionName AND DMO.DimensionTypeID <> -1) AND DMO.SelectYN <> 0
				INNER JOIN DimensionType DDT ON DDT.DimensionTypeID = DD.DimensionTypeID
				LEFT JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MOH ON MOH.Entity = ''-1'' AND (MOH.ObjectName = DD.Hierarchy AND MOH.DimensionTypeID <> -1) AND MOH.SelectYN <> 0
			WHERE
				M.ModelID = ' + CONVERT(nvarchar, @ModelID) + ' AND
				NOT EXISTS (SELECT 1 FROM #Dimensions DDD WHERE DDD.MappedDimensionName = DMO.MappedObjectName)'

		IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = '#Dimensions', Model = @Model, D.* FROM #Dimensions D

		-----------------------------
		SET @Step = 'Add mandatory dimensions; ' + @Model
		-----------------------------

		DECLARE XT_DimensionDefinition_Cursor CURSOR FOR

			SELECT
				DimensionName,
				MappedDimensionName,
				DimensionDescription,
				DimensionTypeName,
				Hierarchy,
				SecuredYN,
				ModelYN
			FROM
				#Dimensions  

			OPEN XT_DimensionDefinition_Cursor
			FETCH NEXT FROM XT_DimensionDefinition_Cursor INTO @Dimension, @MappedDimension, @DimensionDescription, @DimensionType, @Hierarchy, @SecuredYN, @ModelYN

			WHILE @@FETCH_STATUS = 0
			  BEGIN

		-----------------------------
		SET @Step = 'XT_DimensionDefinition, XT_HierarchyDefinition & XT_ModelDimensions; ' + @Model
		-----------------------------

				SET @SQLStatement = 

		--XT_DimensionDefinition
				'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_DimensionDefinition]
					(
					[Action],
					[Label],
					[Description],
					[Type],
					[Secured],
					[DefaultHierarchy]
					)
				SELECT
					[Action] = NULL,
					[Label] = ''' + @MappedDimension + ''',
					[Description] = ''' + @DimensionDescription + ''',
					[Type] = ''' + @DimensionType + ''',
					[Secured] = ' + CONVERT(nvarchar, CONVERT(int, @SecuredYN)) + ',
					[DefaultHierarchy] = ''' + @MappedDimension + '_' + @MappedDimension + '''
				WHERE
					NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_DimensionDefinition] XT WHERE XT.Label = ''' + @MappedDimension + ''') ' +

		--XT_HierarchyDefinition
				'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition]
					(
					[Dimension],
					[Label]
					)
				 SELECT DISTINCT
					[Dimension] = ''' + @MappedDimension + ''',
					[Label] = ''' + @MappedDimension + '''
				WHERE
					NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition] XT WHERE XT.Dimension = ''' + @MappedDimension + ''' AND XT.Label = ''' + @MappedDimension + ''') '

			IF @Hierarchy IS NOT NULL
				SET @SQLStatement = @SQLStatement + '
				INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition]
					(
					[Dimension],
					[Label]
					)
				 SELECT DISTINCT
					[Dimension] = ''' + @MappedDimension + ''',
					[Label] = ''' + @Hierarchy + '''
				WHERE
					NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition] XT WHERE XT.Dimension = ''' + @MappedDimension + ''' AND XT.Label = ''' + @Hierarchy + ''') '

		--XT_ModelDimensions
		IF @ModelYN <> 0
			SET @SQLStatement = @SQLStatement +
				'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_ModelDimensions]
					(
					[Model],
					[Dimension]
					)
				 SELECT DISTINCT
					[Model] = ''' + @MappedModel + ''',
					[Dimension] = ''' + @MappedDimension + '''
				WHERE
					NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_ModelDimensions] XT WHERE XT.Model = ''' + @MappedModel + ''' AND XT.Dimension = ''' + @MappedDimension + ''')'
			
				IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			
				FETCH NEXT FROM XT_DimensionDefinition_Cursor INTO @Dimension, @MappedDimension, @DimensionDescription, @DimensionType, @Hierarchy, @SecuredYN, @ModelYN
			  END

		CLOSE XT_DimensionDefinition_Cursor
		DEALLOCATE XT_DimensionDefinition_Cursor	

 		-----------------------------
		SET @Step = 'Add Finance segment dimensions; ' + @Model
		-----------------------------

		IF @OptFinanceDimYN <> 0
			BEGIN
			--Add optional dimensions	
	
			--XT_DimensionDefinition	
				SET @SQLStatement = 
				'INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_DimensionDefinition]
					(
					[Action],
					[Label],
					[Description],
					[Type],
					[Secured],
					[DefaultHierarchy]
					)
				 SELECT DISTINCT
					[Action] = NULL,
					[Label] = MO.MappedObjectName,
					[Description] = MO.MappedObjectName,
					[Type] = DT.DimensionTypeName,
					[Secured] = 0,
					[DefaultHierarchy] = MO.MappedObjectName + ''_'' + MO.MappedObjectName
				 FROM
					Model M
					INNER JOIN DimensionType DT ON DT.DimensionTypeID = -1
					INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.DimensionTypeID = -1 AND MO.SelectYN <> 0
				 WHERE
					M.ModelID = ' + CONVERT(nvarchar, @ModelID) + ' AND
					M.ApplicationID = ' + CONVERT(nvarchar, @ApplicationID) + ' AND
					NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_DimensionDefinition] XT WHERE XT.Label = MO.MappedObjectName)'
			
			--XT_ModelDimensions
				SET @SQLStatement = @SQLStatement + '
				INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_ModelDimensions]
					(
					[Model],
					[Dimension]
					)
				SELECT DISTINCT
					[Model] = ''' + @MappedModel + ''',
					[Dimension] = MO.MappedObjectName
				FROM
					Model M
					INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.SelectYN <> 0
					INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.DimensionTypeID = -1 AND MO.ModelBM & BM.ModelBM > 0 AND MO.SelectYN <> 0
				WHERE
 					M.ModelID = ' + CONVERT(nvarchar, @ModelID) + ' AND
					M.ApplicationID = ' + CONVERT(nvarchar, @ApplicationID) + ' AND
					M.SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_ModelDimensions] XT WHERE XT.Model = ''' + @MappedModel + ''' AND XT.Dimension = MO.MappedObjectName) ' +

			--XT_HierarchyDefinition
				'INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_HierarchyDefinition]
					(
					[Dimension],
					[Label]
					)
				 SELECT DISTINCT
					[Dimension] = MO.MappedObjectName,
					[Label] = MO.MappedObjectName
				 FROM
					Model M
					INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.DimensionTypeID = -1 AND MO.SelectYN <> 0
				 WHERE
					M.ModelID = ' + CONVERT(nvarchar, @ModelID) + ' AND
					M.ApplicationID = ' + CONVERT(nvarchar, @ApplicationID) + ' AND
					NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition] XT WHERE XT.Dimension = MO.MappedObjectName AND XT.Label = MO.MappedObjectName)'

				IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END
	
 		-----------------------------
		SET @Step = 'XT_PropertyDefinition; ' + @Model
		-----------------------------

		CREATE TABLE [#Property](
			[PropertyName] [nvarchar](100) COLLATE DATABASE_DEFAULT NOT NULL,
			[MappedPropertyName] [nvarchar](100) COLLATE DATABASE_DEFAULT NOT NULL,
			[SelectYN] bit
		)

		SET @SQLStatement = '

			INSERT INTO #Property
				(
				PropertyName,
				MappedPropertyName,
				[SelectYN]
				)
			SELECT DISTINCT
				PropertyName = MO.ObjectName,
				MappedPropertyName = MO.MappedObjectName,
				[SelectYN] = MO.[SelectYN]
			FROM
				[' + @ETLDatabase + '].[dbo].[MappedObject] MO
			WHERE
				MO.ObjectTypeBM & 4 > 0'

			IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
			EXEC (@SQLStatement)

		CREATE TABLE [#DimensionProperty](
			[DimensionName] [nvarchar](100) COLLATE DATABASE_DEFAULT NOT NULL,
			[MappedDimensionName] [nvarchar](100) COLLATE DATABASE_DEFAULT NOT NULL
		)

		SET @SQLStatement = '

			INSERT INTO #DimensionProperty
				(
				DimensionName,
				MappedDimensionName
				)
			SELECT DISTINCT
				DimensionName = MO.ObjectName,
				MappedDimensionName = MO.MappedObjectName
			FROM
				[' + @ETLDatabase + '].[dbo].[MappedObject] MO
			WHERE
				MO.DimensionTypeID <> -1 AND
				MO.ObjectTypeBM & 2 > 0 AND
				MO.SelectYN <> 0'

			IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
			EXEC (@SQLStatement)
			IF @Debug <> 0 SELECT TempTable = '#DimensionProperty', * FROM #DimensionProperty
 		-----------------------------
		SET @Step = 'Add properties for mandatory dimensions; ' + @Model

			SELECT DISTINCT
				Dimension = D.DimensionName,
				MappedDimension = ISNULL(DP.MappedDimensionName, D.DimensionName),
				Property = P.PropertyName,
				MappedProperty = ISNULL(Pr.MappedPropertyName, P.PropertyName),
				DataType = DT.DataTypeCallisto,
				Size = P.Size,
				DefaultValue = P.DefaultValueTable,
				MemberDimension = DD.DimensionName,
				--MappedMemberDimension = ISNULL(DPr.MappedDimensionName, DD.DimensionName)
				MappedMemberDimension = CASE WHEN DT.DataTypeCallisto = 'Member' AND ISNULL(DPr.MappedDimensionName, DD.DimensionName) IS NULL THEN D.DimensionName ELSE ISNULL(DPr.MappedDimensionName, DD.DimensionName) END
			INTO
				#PropertyDefinition
			FROM
				Model M
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
				INNER JOIN Model_Dimension MD ON MD.ModelID = BM.ModelID AND MD.Introduced < @Version AND MD.SelectYN <> 0
				INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.Introduced < @Version AND D.SelectYN <> 0
				INNER JOIN #DimensionProperty DP ON DP.DimensionName = D.DimensionName
				LEFT JOIN Dimension_Property DP1 ON DP1.DimensionID = D.DimensionID AND DP1.Introduced < @Version AND DP1.SelectYN <> 0
				LEFT JOIN Property P ON P.PropertyID NOT BETWEEN 100 AND 1000 AND P.PropertyID NOT IN (3, 4, 5, 8, 12) AND (P.PropertyID = DP1.PropertyID OR P.DimensionID = 0) AND P.SourceTypeBM & @SourceTypeBM_All > 0 AND P.Introduced < @Version AND P.SelectYN <> 0
				LEFT JOIN #Property Pr ON Pr.PropertyName = P.PropertyName
				INNER JOIN DataType DT ON DT.DataTypeID = P.DataTypeID
				LEFT JOIN Dimension DD ON DD.DimensionID = P.DependentDimensionID AND DD.Introduced < @Version
				LEFT JOIN #DimensionProperty DPr ON DPr.DimensionName = DD.DimensionName
			WHERE
				M.ModelID = @ModelID AND
				M.SelectYN <> 0 AND
				(DD.DimensionID IS NULL OR (DD.DimensionID IS NOT NULL AND DD.SelectYN <> 0)) AND
				(Pr.PropertyName IS NULL OR (Pr.PropertyName IS NOT NULL AND Pr.SelectYN <> 0)) AND
				NOT EXISTS (SELECT 1 FROM Dimension DDD WHERE DDD.DimensionID = P.DependentDimensionID AND (DDD.Introduced >= @Version OR DDD.SelectYN = 0))

			IF @Debug <> 0 SELECT TempTable = '#PropertyDefinition', * FROM #PropertyDefinition

			IF (SELECT COUNT(1) FROM #PropertyDefinition WHERE Property = 'SegmentProperty') > 0
				BEGIN
				/*
					SET @SQLStatement = '
					INSERT INTO #PropertyDefinition
						(
						Dimension,
						MappedDimension,
						Property,
						MappedProperty,
						DataType,
						Size,
						DefaultValue,
						MemberDimension,
						MappedMemberDimension
						)
					SELECT DISTINCT
						Dimension = PD.Dimension,
						MappedDimension = PD.MappedDimension,
						Property = MO.MappedObjectName,
						MappedProperty = MO.MappedObjectName,
						DataType = PD.DataType,
						Size = PD.Size,
						DefaultValue = PD.DefaultValue,
						MemberDimension = MO.MappedObjectName,
						MappedMemberDimension = MO.MappedObjectName
					FROM
						[' + @ETLDatabase + '].[dbo].[MappedObject] MO
						INNER JOIN #PropertyDefinition PD ON PD.Property = ''SegmentProperty''
						INNER JOIN Model M ON M.ModelID = ' + CONVERT(nvarchar(10), @BaseModelID) + '
					WHERE
						MO.Entity <> ''-1'' AND
						MO.DimensionTypeID = -1 AND
						MO.ObjectTypeBM & 2 > 0 AND
						MO.ModelBM & M.ModelBM > 0 AND
						MO.SelectYN <> 0'
*/

					SET @SQLStatement = '
					INSERT INTO #PropertyDefinition
						(
						Dimension,
						MappedDimension,
						Property,
						MappedProperty,
						DataType,
						Size,
						DefaultValue,
						MemberDimension,
						MappedMemberDimension
						)
					SELECT DISTINCT
						Dimension = PD.Dimension,
						MappedDimension = PD.MappedDimension,
						Property = MO.MappedObjectName,
						MappedProperty = MO.MappedObjectName,
						DataType = PD.DataType,
						Size = PD.Size,
						DefaultValue = PD.DefaultValue,
						MemberDimension = MO.MappedObjectName,
						MappedMemberDimension = CASE WHEN PD.DataType = ''Member'' AND MO.MappedObjectName IS NULL THEN PD.Dimension ELSE MO.MappedObjectName END
					FROM
						[' + @ETLDatabase + '].[dbo].[MappedObject] MO
						INNER JOIN ' + @ETLDatabase + '.[dbo].[Entity] E ON E.SourceID = ' + CONVERT(nvarchar(10), @SourceID) + ' AND E.Entity = MO.Entity AND E.SelectYN <> 0
						INNER JOIN ' + @ETLDatabase + '.[dbo].[FinancialSegment] FS ON FS.SourceID = E.SourceID AND FS.EntityCode = E.EntityCode AND FS.SegmentName = MO.ObjectName AND FS.DynamicYN = 0
						INNER JOIN #PropertyDefinition PD ON PD.Property = ''SegmentProperty''
						INNER JOIN Model M ON M.ModelID = ' + CONVERT(nvarchar(10), @BaseModelID) + '
					WHERE
						MO.Entity <> ''-1'' AND
						MO.DimensionTypeID = -1 AND
						MO.ObjectTypeBM & 2 > 0 AND
						MO.ModelBM & M.ModelBM > 0 AND
						MO.SelectYN <> 0'
					IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
					EXEC (@SQLStatement)

					DELETE #PropertyDefinition WHERE Property = 'SegmentProperty'
				END
		-----------------------------
		DECLARE XT_PropertyDefinition_Cursor CURSOR FOR
			SELECT
				Dimension,
				MappedDimension,
				Property,
				MappedProperty,
				DataType,
				Size,
				DefaultValue,
				MemberDimension,
				MappedMemberDimension
			FROM
				#PropertyDefinition

			OPEN XT_PropertyDefinition_Cursor
			FETCH NEXT FROM XT_PropertyDefinition_Cursor INTO @Dimension, @MappedDimension, @Property, @MappedProperty, @DataType, @Size, @DefaultValue, @MemberDimension, @MappedMemberDimension

			WHILE @@FETCH_STATUS = 0
			  BEGIN

		--SELECT Dimension = @Dimension, Property = @Property, Size = @Size, DefaultValue = @DefaultValue

				SET @SQLStatement = 
		
				'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition]
					(
					[Action],
					[Dimension],
					[Label],
					[DataType],
					[Size],
					[DefaultValue],
					[MemberDimension],
					[MemberHierarchy]
					)
				SELECT
					[Action] = NULL,
					[Dimension] = ''' + @MappedDimension + ''',
					[Label] = ''' + @MappedProperty + ''',
					[DataType] = ''' + @DataType + ''',
					[Size] = ' + CONVERT(nvarchar, ISNULL(@Size, 0)) + ',
					[DefaultValue] = ''' + ISNULL(@DefaultValue, '') + ''',
					[MemberDimension] = ''' + ISNULL(@MappedMemberDimension, '') + ''',
					[MemberHierarchy] = ''' + ISNULL(@MappedMemberDimension, '') + '''
				WHERE
					NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition] XT WHERE XT.Dimension = ''' + @MappedDimension + ''' AND XT.Label = ''' + @MappedProperty + ''')'

				IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			
				FETCH NEXT FROM XT_PropertyDefinition_Cursor INTO @Dimension, @MappedDimension, @Property, @MappedProperty, @DataType, @Size, @DefaultValue, @MemberDimension, @MappedMemberDimension
			  END

		CLOSE XT_PropertyDefinition_Cursor
		DEALLOCATE XT_PropertyDefinition_Cursor		

		DROP TABLE #PropertyDefinition

		IF @OptFinanceDimYN <> 0
			BEGIN
			--Add properties for optional dimensions		
				SET @SQLStatement = 
	
				'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition]
					(
					[Action],
					[Dimension],
					[Label],
					[DataType],
					[Size],
					[DefaultValue],
					[MemberDimension],
					[MemberHierarchy]
					)
				SELECT DISTINCT
					[Action] = NULL,
					Dimension = XTDD.Label,
					Label = P.PropertyName,
					DataType = DT.DataTypeCallisto,
					Size = P.Size,
					DefaultValue = P.DefaultValueTable,
					MemberDimension = ISNULL(DD.DimensionName, ''''),
					MemberHierarchy = ISNULL(DD.DimensionName, '''')
				FROM
					[' + @ETLDatabase + '].[dbo].[MappedObject] MO
					INNER JOIN ' + @ETLDatabase + '.[dbo].[XT_DimensionDefinition] XTDD ON XTDD.Label = MO.MappedObjectName
					INNER JOIN Dimension_Property DP ON DP.DimensionID = 0 AND DP.Introduced < ''' + @Version + ''' AND DP.SelectYN <> 0
					INNER JOIN Property P ON P.PropertyID NOT BETWEEN 100 AND 1000 AND P.PropertyID NOT IN (3, 4, 5, 8, 12) AND P.PropertyID = DP.PropertyID AND P.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM_All) + ' > 0 AND P.Introduced < ''' + @Version + ''' AND P.SelectYN <> 0
					INNER JOIN DataType DT ON DT.DataTypeID = P.DataTypeID
					LEFT JOIN Dimension DD ON DD.DimensionID = P.DependentDimensionID AND DD.SelectYN <> 0
				WHERE
					MO.DimensionTypeID = -1 AND
					MO.SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition] XT WHERE XT.Dimension = MO.MappedObjectName AND XT.Label = P.PropertyName)'
			
				IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			
			END

   		-----------------------------
		SET @Step = 'Add Business Rules & Model dependent Security Rules; ' + @Model
		-----------------------------
			IF (SELECT COUNT(1) FROM #BaseModel WHERE BaseModelID = @BaseModelID) = 0
				BEGIN
					INSERT INTO #BaseModel (BaseModelID) SELECT BaseModelID = @BaseModelID
					EXEC [spCreate_Application_BusinessRules] @JobID = @JobID, @ApplicationID = @ApplicationID, @ETLDatabase = @ETLDatabase, @BaseModelID = @BaseModelID, @LanguageID = @LanguageID, @Debug = @Debug

/*
					SET @SQLStatement = '
					INSERT [' + @ETLDatabase + '].[dbo].[XT_SecurityMemberAccess] ([Role], [Model], [Dimension], [Hierarchy], [Member], [AccessType]) VALUES (N''FullAccess'', N''' + @Model + ''', N''Scenario'', NULL, NULL, 3)
					INSERT [' + @ETLDatabase + '].[dbo].[XT_SecurityModelRuleAccess] ([Role], [Model], [Rule], [AllRules]) VALUES (N''FullAccess'', N''' + @Model + ''', N'''', 1)
					'
					IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
					EXEC (@SQLStatement)
*/
				END

   		-----------------------------
		SET @Step = 'Drop Model dependent tables; ' + @Model
		-----------------------------

			DROP TABLE #Dimensions
			DROP TABLE #DimensionProperty
			DROP TABLE #Property

			SET @Counter = @Counter + 1
			SET @CounterString = CONVERT(nvarchar(10), CONVERT(int, @Counter)) + ' of ' + CONVERT(nvarchar(10), CONVERT(int, @Total)) + ' processed'
			SET @PercentDone = CONVERT(int, @Counter / @Total * 100.0)

			RAISERROR (@CounterString, 0, @PercentDone) WITH NOWAIT

			FETCH NEXT FROM Create_Model_Cursor INTO @Model, @MappedModel, @BaseModelID, @SourceID, @OptFinanceDimYN, @TextSupportYN, @DynamicRule, @ModelID, @StartupWorkbook
		  END

		CLOSE Create_Model_Cursor
		DEALLOCATE Create_Model_Cursor

	SET @Step = 'Add translation properties'
		SET @SQLStatement = 
		
		'INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition]
			(
			[Action],
			[Dimension],
			[Label],
			[DataType],
			[Size],
			[DefaultValue],
			[MemberDimension],
			[MemberHierarchy]
			)
		SELECT DISTINCT
			[Action] = NULL,
			Dimension = DD.Label,
			Label = ''Translation_'' + L.LanguageCode, 
			DataType = ''Text'',
			Size = 512,
			DefaultValue = '''',
			MemberDimension = '''',
			MemberHierarchy = ''''
		FROM
			Application_Translation AT
			INNER JOIN [Language] L ON L.LanguageID = AT.LanguageID
			INNER JOIN [' + @ETLDatabase + ']..XT_DimensionDefinition DD ON 1 = 1
		WHERE
			AT.ApplicationID = ' + CONVERT(nvarchar(10), @ApplicationID) + ' AND
			AT.SelectYN <> 0 AND
			NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + ']..MappedObject MO WHERE MO.ObjectTypeBM & 2 > 0 AND MO.MappedObjectName = DD.Label AND TranslationYN = 0 AND SelectYN <> 0) AND
			NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition] XT WHERE XT.Dimension = DD.Label AND XT.Label = ''Translation_'' + L.LanguageCode)'
			
		IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
		EXEC (@SQLStatement)
		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Handle extra properties and hierarchies for pcEXCHANGE'	
		IF @SourceTypeBM_All & 32 > 0
			BEGIN
				IF @Debug <> 0 SELECT pcEXCHANGE_SourceDB = @pcEXCHANGE_SourceDB, ETLDatabase = @ETLDatabase
				CREATE TABLE #Counter ([Count] int)
				CREATE TABLE #pcEXCHANGE_Dimension
					(
					DimensionName nvarchar(100),
					MappedObjectName nvarchar(100)
					)

				SET @SQLStatement = '
					INSERT INTO #pcEXCHANGE_Dimension
						(
						DimensionName,
						MappedObjectName
						)
					SELECT DISTINCT
						D.DimensionName,
						MappedObjectName = ISNULL(MO.MappedObjectName, D.DimensionName)
					FROM
						[' + @pcEXCHANGE_SourceDB + '].[dbo].[Dimension] D
						LEFT JOIN ' + @ETLDatabase + '..MappedObject MO ON MO.ObjectName = D.DimensionName AND MO.DimensionTypeID = D.DimensionTypeID AND MO.ObjectTypeBM & 2 > 0 AND MO.SelectYN <> 0
					ORDER BY
						D.DimensionName'

				IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
				EXEC (@SQLStatement)

				IF @Debug <> 0 SELECT TempTable = '#pcEXCHANGE_Dimension', * FROM #pcEXCHANGE_Dimension

				DECLARE pcEXCHANGE_Cursor CURSOR FOR

					SELECT DISTINCT
						DimensionName,
						MappedObjectName
					FROM
						#pcEXCHANGE_Dimension
					ORDER BY
						DimensionName

					OPEN pcEXCHANGE_Cursor
					FETCH NEXT FROM pcEXCHANGE_Cursor INTO @DimensionName, @MappedObjectName

					WHILE @@FETCH_STATUS = 0
						BEGIN

							IF @Debug <> 0 SELECT DimensionName = @DimensionName, MappedObjectName = @MappedObjectName

							SELECT @Counter = 0, @ValueCheck = 1
							WHILE @Counter < 20 AND @ValueCheck > 0
								BEGIN
									SET @Counter = @Counter + 1
									SET @CounterString = CASE WHEN @Counter <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), CONVERT(int, @Counter))
									TRUNCATE TABLE #Counter

									IF @Debug <> 0 SELECT Step = 'XT_PropertyDefinition', Counterstring = @CounterString

									SET @SQLStatement = '
										INSERT INTO #Counter
											(
											[Count]
											)
										SELECT 
											Count = COUNT(1)
										FROM
											[' + @pcEXCHANGE_SourceDB + '].[dbo].[Dimension] D
										WHERE
											D.DimensionName = ''' + @DimensionName + ''' AND
											D.PropertyName' + @CounterString + ' IS NOT NULL'

									IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
									EXEC (@SQLStatement)

									SELECT @ValueCheck = [Count] FROM #Counter

									IF @ValueCheck > 0
										BEGIN
											SET @SQLStatement = '
												INSERT INTO [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition]
													(
													[Action],
													[Dimension],
													[Label],
													[DataType],
													[Size],
													[DefaultValue],
													[MemberDimension],
													[MemberHierarchy]
													)
												SELECT DISTINCT
													[Action] = NULL,
													Dimension = ''' + @MappedObjectName + ''',
													Label = PropertyName' + @CounterString + ', 
													DataType = CASE PropertyDataTypeID' + @CounterString + ' WHEN 1 THEN ''Integer'' WHEN 2 THEN ''Text'' WHEN 4 THEN ''TrueFalse'' WHEN 5 THEN ''DoubleNum'' END,
													Size = PropertySize' + @CounterString + ',
													DefaultValue = '''',
													MemberDimension = '''',
													MemberHierarchy = ''''
												FROM
													[' + @pcEXCHANGE_SourceDB + '].[dbo].[Dimension] D
												WHERE
													D.DimensionName = ''' + @DimensionName + ''' AND
													PropertyDataTypeID' + @CounterString + ' <> 3 AND
													NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_PropertyDefinition] XT WHERE XT.Dimension = ''' + @MappedObjectName + ''' AND XT.Label = PropertyName' + @CounterString + ')'
			
											IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
											EXEC (@SQLStatement)
											SET @Inserted = @Inserted + @@ROWCOUNT
										END
								END

							SELECT @Counter = 0, @ValueCheck = 1
							WHILE @Counter < 5 AND @ValueCheck > 0
								BEGIN
									SET @Counter = @Counter + 1
									SET @CounterString = CONVERT(nvarchar(10), CONVERT(int, @Counter))
									TRUNCATE TABLE #Counter

									IF @Debug <> 0 SELECT Step = 'XT_HierarchyDefinition', Counterstring = @CounterString

									SET @SQLStatement = '
										INSERT INTO #Counter
											(
											[Count]
											)
										SELECT 
											Count = COUNT(1)
										FROM
											[' + @pcEXCHANGE_SourceDB + '].[dbo].[Dimension] D
										WHERE
											D.DimensionName = ''' + @DimensionName + ''' AND
											D.HierarchyName' + @CounterString + ' IS NOT NULL'

									IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
									EXEC (@SQLStatement)

									SELECT @ValueCheck = [Count] FROM #Counter

									IF @ValueCheck > 0
										BEGIN
											SET @SQLStatement = '
												INSERT INTO ' + @ETLDatabase + '.[dbo].[XT_HierarchyDefinition]
													(
													[Dimension],
													[Label]
													)
												 SELECT DISTINCT
													[Dimension] = ''' + @MappedObjectName + ''',
													[Label] = ISNULL(MO.MappedObjectName, D.HierarchyName' + @CounterString + ')
												 FROM
													[' + @pcEXCHANGE_SourceDB + '].[dbo].[Dimension] D
													LEFT JOIN ' + @ETLDatabase + '..MappedObject MO ON MO.ObjectName = D.DimensionName AND MO.ObjectName = D.HierarchyName' + @CounterString + ' AND MO.DimensionTypeID = D.DimensionTypeID AND MO.ObjectTypeBM & 2 > 0 AND MO.SelectYN <> 0
												WHERE
													D.DimensionName = ''' + @DimensionName + ''' AND
													NOT EXISTS (SELECT 1 FROM [' + @ETLDatabase + '].[dbo].[XT_HierarchyDefinition] XT WHERE XT.Dimension = ''' + @MappedObjectName + ''' AND XT.Label = ISNULL(MO.MappedObjectName, D.HierarchyName' + @CounterString + '))'

											IF @Debug <> 0 PRINT (@SQLStatement) --(Debug)
											EXEC (@SQLStatement)
											SET @Inserted = @Inserted + @@ROWCOUNT
										END
								END

							FETCH NEXT FROM pcEXCHANGE_Cursor INTO @DimensionName, @MappedObjectName
						END

				CLOSE pcEXCHANGE_Cursor
				DEALLOCATE pcEXCHANGE_Cursor	

				DROP TABLE #Counter
				DROP TABLE #pcEXCHANGE_Dimension
			END

	SET @Step = 'Handle Security settings'
--		Handled in [spPortalAdminCreate_NewInstance]
--		EXEC [spInsert_Security_Default] @JobID = @JobID, @ApplicationID = @ApplicationID, @Debug = @Debug
		EXEC [spCreate_Application_Security] @JobID = @JobID, @ApplicationID = @ApplicationID, @Debug = @Debug

	SET @Step = 'Drop table #Models'
		DROP TABLE #Models
		DROP TABLE #BaseModel

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
