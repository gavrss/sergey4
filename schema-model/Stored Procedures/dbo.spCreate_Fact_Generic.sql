SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Fact_Generic]

	@SourceID int = NULL,
	@ProcedureName nvarchar(100) = '' OUT,
	@JobID int = 0,
	@Encryption smallint = 1,
	@GetVersion bit = 0,
	@Debug int = 0,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT

--#WITH ENCRYPTION#--

AS

--EXEC [spCreate_Fact_Generic] @SourceID = 103, @Debug = 1 --E9 FxRate
--EXEC [spCreate_Fact_Generic] @SourceID = 104, @Debug = 1 --E9 Sales
--EXEC [spCreate_Fact_Generic] @SourceID = 107, @Debug = 1 --E9 Financials
--EXEC [spCreate_Fact_Generic] @SourceID = 110, @Debug = 1 --E9 AR
--EXEC [spCreate_Fact_Generic] @SourceID = 111, @Debug = 1 --E9 AP

--EXEC [spCreate_Fact_Generic] @SourceID = 123, @Debug = 1 --E9 FxRate
--EXEC [spCreate_Fact_Generic] @SourceID = 124, @Debug = 1 --E9 Sales
--EXEC [spCreate_Fact_Generic] @SourceID = 127, @Debug = 1 --E9 Financials
--EXEC [spCreate_Fact_Generic] @SourceID = 130, @Debug = 1 --E9 AR
--EXEC [spCreate_Fact_Generic] @SourceID = 131, @Debug = 1 --E9 AP

--EXEC [spCreate_Fact_Generic] @SourceID = 303, @Debug = 1 --iScala FxRate
--EXEC [spCreate_Fact_Generic] @SourceID = 304, @Debug = 1 --iScala Sales
--EXEC [spCreate_Fact_Generic] @SourceID = 307, @Debug = 1 --iScala Financials
--EXEC [spCreate_Fact_Generic] @SourceID = 310, @Debug = 1 --iScala AR
--EXEC [spCreate_Fact_Generic] @SourceID = 311, @Debug = 1 --iScala AP

--EXEC [spCreate_Fact_Generic] @SourceID = 903, @Debug = 1 --AX FxRate
--EXEC [spCreate_Fact_Generic] @SourceID = 904, @Debug = 1 --AX Sales
--EXEC [spCreate_Fact_Generic] @SourceID = 907, @Debug = 1 --AX Financials
--EXEC [spCreate_Fact_Generic] @SourceID = 910, @Debug = 1 --AX AR
--EXEC [spCreate_Fact_Generic] @SourceID = 911, @Debug = 1 --AX AP

--EXEC [spCreate_Fact_Generic] @SourceID = 1103, @Debug = 1 --E10 FxRate
--EXEC [spCreate_Fact_Generic] @SourceID = 1104, @Debug = 1 --E10 Sales
--EXEC [spCreate_Fact_Generic] @SourceID = 1107, @Debug = 1 --E10 Financials
--EXEC [spCreate_Fact_Generic] @SourceID = 1110, @Debug = 1 --E10 AR
--EXEC [spCreate_Fact_Generic] @SourceID = 1111, @Debug = 1 --E10 AP

--EXEC [spCreate_Fact_Generic] @SourceID = 1143, @Debug = 1 --E10.1 Linked FxRate
--EXEC [spCreate_Fact_Generic] @SourceID = 1144, @Debug = 1 --E10.1 Linked Sales
--EXEC [spCreate_Fact_Generic] @SourceID = 1147, @Debug = 1 --E10.1 Linked Financials
--EXEC [spCreate_Fact_Generic] @SourceID = 1150, @Debug = 1 --E10.1 Linked AR
--EXEC [spCreate_Fact_Generic] @SourceID = 1151, @Debug = 1 --E10.1 Linked AP

--EXEC [spCreate_Fact_Generic] @SourceID = 1163, @Debug = 1 --E10.1 Linked FxRate
--EXEC [spCreate_Fact_Generic] @SourceID = 1164, @Debug = 1 --E10.1 Linked Sales
--EXEC [spCreate_Fact_Generic] @SourceID = 1167, @Debug = 1 --E10.1 Linked Financials
--EXEC [spCreate_Fact_Generic] @SourceID = 1170, @Debug = 1 --E10.1 Linked AR
--EXEC [spCreate_Fact_Generic] @SourceID = 1171, @Debug = 1 --E10.1 Linked AP

--EXEC [spCreate_Fact_Generic] @SourceID = 1223, @Debug = 1 --ENT FxRate
--EXEC [spCreate_Fact_Generic] @SourceID = 1224, @Debug = 1 --ENT Sales
--EXEC [spCreate_Fact_Generic] @SourceID = 1227, @Debug = 1 --ENT Financials
--EXEC [spCreate_Fact_Generic] @SourceID = 1230, @Debug = 1 --ENT AR
--EXEC [spCreate_Fact_Generic] @SourceID = 1231, @Debug = 1 --ENT AP

--EXEC [spCreate_Fact_Generic] @SourceID = 990, @Debug = 1 --AX Financials Bullguard
--EXEC [spCreate_Fact_Generic] @SourceID = 991, @Debug = 1 --AX FxRate Bullguard
--EXEC [spCreate_Fact_Generic] @SourceID = -1066, @Debug = 1 --E10 Cloud demo

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@SQLStatement_Delete nvarchar(1000),
	@SQLStatement_DeleteJoin nvarchar(1000),
	@SQLStatement_FACT_DeleteJoin nvarchar(1000),
	@SQLStatement_Action nvarchar(1000),
	@SQLStatement_SourceString nvarchar(max),
	@SQLStatement_CreateTable nvarchar(4000),
	@SQLStatement_InsertInto nvarchar(4000),
	@SQLStatement_Select nvarchar(4000),
	@SQLStatement_Where nvarchar(4000),
	@SQLStatement_SelectID nvarchar(max),
	@SQLStatement_DimJoin nvarchar(max),
	@SQLStatement_SubSelect nvarchar(max),
	@SQLStatement_SubFrom nvarchar(4000),
	@SQLStatement_SubGroupBy nvarchar(max),
	@SQLStatement_SubWhere nvarchar(4000),
	@SQLStatement_SubHaving nvarchar(4000),
	@SQLStatement_MapJoin nvarchar(max),
	@SQLStatement_FxRate nvarchar(max),
	@InstanceID int,
	@ApplicationID int,
	@SourceDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@ETLDatabase_Linked nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@SourceID_varchar nvarchar(50),
	@ObjectName nvarchar(100),
	@TempTableName nvarchar(100),
	@Action nvarchar(10),
	@BaseModelID int,
	@StartYear int,
	@Entity nvarchar(50),
	@Company_COACode nvarchar(50),
	@SourceTypeID int,
	@LanguageID int,
	@LanguageCode nchar(3),
	@ModelName nvarchar(100),
	@SourceTypeBM int,
	@RevisionBM int,
	@LinkedBM int,
	@SourceTypeName nvarchar(100),
	@ModelBM int,
	@OptFinanceDimYN bit,
	@FinanceAccountYN bit,
	@SourceTypeFamilyID int,
	@Owner nvarchar(50),
	@SegmentCode nvarchar(50),
	@PrevSegmentCode nvarchar(50),
	@TimeLevelID int,
	@SourceDBTypeID int,
	@StartYearString nvarchar(10),
	@BusinessProcess nvarchar(50),
	@BusinessRule nvarchar(50),
	@TotalEntityCount int,
	@MappedObjectName nvarchar(100),
	@EntityCount int,
	@SequenceBMSum int,
	@SequenceBMStep int,
	@SequenceCounter int = 0,
	@SequenceDescription nvarchar(255),
	@SequenceBM int,
	@FCurrency nvarchar(50),
	@FTime nvarchar(50),
	@FTimeYear nvarchar(50),
	@FTimeMonth nvarchar(50),
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2065' SET @Description = 'Bug in segment handling for Epicor ERP fixed.'
		IF @Version = '1.2.2066' SET @Description = 'Bugs in handling of multiple db types fixed.'
		IF @Version = '1.2.2068' SET @Description = 'SET ANSI_WARNINGS OFF.'
		IF @Version = '1.3.2070' SET @Description = 'Collation problems fixed. SET ANSI_WARNINGS ON if needed.'
		IF @Version = '1.3.2073' SET @Description = 'Handle @RevisionBM (BudgetCode Epicor 10.1)'
		IF @Version = '1.3.2075' SET @Description = 'Change from EntityCode to Entity, Not necessary joins to MappedLabel removed.'
		IF @Version = '1.3.2076' SET @Description = 'Changed VisibleYN handling. VisibleYN = 0 --> Always added to view and used in cleaning part of procedure.'
		IF @Version = '1.3.2077' SET @Description = 'Changed Multiple handling of DimensionTypeID = 1.'
		IF @Version = '1.3.2083' SET @Description = 'Added handling of ETLDatabase_Linked. Added parameter @Encryption. Handle MappingTypeID set in MappedObject. Add brackets around ML_ objects to handle odd signs in segment names.'
		IF @Version = '1.2.2090' SET @Description = 'Fixed bug in handling mandatory dimensions.'
		IF @Version = '1.3.2092' SET @Description = 'Fixed bug in handling Encryption for MultipleDBs. Also fixed VisibleYN bug regarding MultipleDBs'
		IF @Version = '1.3.2095' SET @Description = 'Replaced MandatoryYN and VisibleYN with [VisibilityLevelBM], ISNULL test on @ETLDatabase_Linked'
		IF @Version = '1.3.2097' SET @Description = 'Drop TABLE tmp_Model_Raw - if exists. Test on rows existing for multiple.'
		IF @Version = '1.3.2099' SET @Description = 'Mandatory addition of COLLATE statement when dimension concatenated with Entity'
		IF @Version = '1.3.2101' SET @Description = 'Enhanced handling of default values for mandatory dimensions when not defined in MetaData tables. Enhanced handling of ANSI_WARNINGS.'
		IF @Version = '1.3.2104' SET @Description = 'Enabled financial segments for other models than Financials. Only tested for iScala. Added @MasterEntity for FxRate. Added BusinessRule.'
		IF @Version = '1.3.2107' SET @Description = 'Test on SourceTypeID = 6'
		IF @Version = '1.3.2110' SET @Description = 'Handle Currency conversion.'
		IF @Version = '1.3.2112' SET @Description = 'Fixed hardcoded reference to NaturalAccount in iScala FACT join.'
		IF @Version = '1.3.2116' SET @Description = 'Fixed bug when Financial segments have the same name as standard dimensions.'
		IF @Version = '1.3.1.2120' SET @Description = 'Removed not selected not mandatory dimensions.'
		IF @Version = '1.3.1.2121' SET @Description = 'Group by MappedObjectName in Sequence-loop.'
		IF @Version = '1.4.0.2129' SET @Description = 'Run selected BusinessRules.'
		IF @Version = '1.4.0.2133' SET @Description = 'Values for default BusinessRules and BusinessProcesses are changed.'
		IF @Version = '1.4.0.2135' SET @Description = 'Handle statistical accounts for Epicor ERP.'
		IF @Version = '1.4.0.2136' SET @Description = 'Handle BusinessProcess for iScala and Enterprise.'
		IF @Version = '1.4.0.2139' SET @Description = 'Brackets around view name FxRate.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
	END

IF @SourceID IS NULL
	BEGIN
		PRINT 'Parameter @SourceID must be set'
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

		SELECT
			@InstanceID = A.InstanceID,
			@ApplicationID = A.ApplicationID,
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(S.SourceDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']',
			@ETLDatabase_Linked = '[' + REPLACE(REPLACE(REPLACE(S.ETLDatabase_Linked, '[', ''), ']', ''), '.', '].[') + ']',
			@DestinationDatabase = A.DestinationDatabase,
			@BaseModelID = M.BaseModelID,
			@StartYear = S.StartYear,
			@StartYearString = CONVERT(nvarchar(10), S.StartYear),
			@SourceTypeID = S.SourceTypeID,
			@SourceTypeName = ST.SourceTypeName,
			@SourceTypeFamilyID = ST.SourceTypeFamilyID,
			@BusinessRule = 'NONE',
			@LanguageID = A.LanguageID,
			@LanguageCode = L.LanguageCode,
			@SourceTypeBM = ST.SourceTypeBM,
			@ModelBM = BM.ModelBM,
			@OptFinanceDimYN = BM.OptFinanceDimYN,
			@FinanceAccountYN = BM.FinanceAccountYN,
			@TimeLevelID = BM.TimeLevelID,
			@SourceDBTypeID = CASE WHEN S.SourceTypeID IN (12) AND M.BaseModelID IN (-3) THEN 1 ELSE ST.SourceDBTypeID END,
			@BusinessProcess = S.BusinessProcess
		FROM
			Source S
			INNER JOIN Model M ON M.ModelID = S.ModelID AND M.SelectYN <> 0
			INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
			INNER JOIN [Language] L ON L.LanguageID = A.LanguageID
			INNER JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
		WHERE
			S.SourceID = @SourceID AND
			S.SelectYN <> 0

		SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

		SET @SourceID_varchar = CASE WHEN ABS(@SourceID) <= 9 THEN '000' ELSE CASE WHEN ABS(@SourceID) <= 99 THEN '00' ELSE CASE WHEN ABS(@SourceID) <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, ABS(@SourceID))

		EXEC [spGet_Owner] @SourceTypeID, @Owner OUTPUT
		EXEC [spGet_Revision] @SourceID = @SourceID, @RevisionBM = @RevisionBM OUT
		EXEC [spGet_Linked] @SourceID = @SourceID, @LinkedBM = @LinkedBM OUT

		IF @SourceTypeID = 6 RETURN

		IF @Debug <> 0
			SELECT
				SourceDatabase = @SourceDatabase,
				ETLDatabase = @ETLDatabase,
				DestinationDatabase = @DestinationDatabase,
				BaseModelID = @BaseModelID,
				StartYear = @StartYear,
				StartYearString = @StartYearString,
				SourceTypeID = @SourceTypeID,
				SourceTypeName = @SourceTypeName,
				SourceTypeFamilyID = @SourceTypeFamilyID,
				LanguageCode = @LanguageCode,
				SourceTypeBM = @SourceTypeBM,
				ModelBM = @ModelBM,
				OptFinanceDimYN = @OptFinanceDimYN,
				FinanceAccountYN = @FinanceAccountYN,
				TimeLevelID = @TimeLevelID,
				SourceDBTypeID = @SourceDBTypeID,
				BusinessProcess = @BusinessProcess,
				BusinessRule = @BusinessRule

	SET @Step = 'Drop TABLE tmp_Model_Raw - if exists.'
		SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''IF (SELECT COUNT(1) FROM sys.tables st WHERE [type] = ''''U'''' AND name = ''''tmp_Model_Raw'''') > 0 DROP TABLE tmp_Model_Raw'''
		EXEC (@SQLStatement)

	SET @Step = 'Create temp table #Action'
		CREATE TABLE #Action
			(
			[Action] nvarchar(10) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Get ModelName'
		CREATE TABLE #ModelName
		(
		ModelName nvarchar(100) COLLATE DATABASE_DEFAULT
		)

		SET @SQLStatement = '
		INSERT INTO #ModelName
			(
			ModelName
			)
		SELECT
			ModelName = MO.MappedObjectName
		FROM
			Model M
			INNER JOIN ' + @ETLDatabase + '.[dbo].[MappedObject] MO ON MO.Entity = ''-1'' AND MO.ObjectName = M.ModelName AND MO.ObjectTypeBM & 1 > 0
		WHERE
			M.ModelID = ' + CONVERT(nvarchar, @BaseModelID)

		EXEC (@SQLStatement)

		IF @Debug <> 0 PRINT (@SQLStatement)
  
		SELECT
		 @ModelName = ModelName
		FROM
		 #ModelName

		DROP TABLE #ModelName

	SET @Step = 'Create temp table holding all field info'

		CREATE TABLE #Dimension
		(
			DimensionID int,
			DimensionTypeID int,
			MappedObjectName nvarchar(100),
			SourceField nvarchar(max),
			SequenceBM int,
			LinkedDimension nvarchar(100),
			LinkedProperty nvarchar(100),
			GroupByYN bit,
			DeleteJoinYN bit,
			MappingTypeID nvarchar(10),
			MappingEnabledYN bit,
			ReplaceTextYN bit,
			VisibilityLevelBM int,
			SortOrder int,
			MappedLabelYN bit
		)

	SET @Step = 'Add generic rows to #Dimension table'

		SET @SQLStatement = '
		INSERT INTO #Dimension
		(
			DimensionID,
			DimensionTypeID,
			MappedObjectName,
			SourceField,
			SequenceBM,
			LinkedDimension,
			LinkedProperty,
			GroupByYN,
			DeleteJoinYN,
			MappingTypeID,
			MappingEnabledYN,
			ReplaceTextYN,
			VisibilityLevelBM,
			SortOrder,
			MappedLabelYN
		)
		SELECT DISTINCT
			sub.DimensionID,
			sub.DimensionTypeID,
			sub.MappedObjectName,
			SourceField = ISNULL(CASE WHEN CONVERT(int, sub.ReplaceTextYN) * CONVERT(int, DT.ReplaceTextEnabledYN) <> 0 THEN ''[dbo].[f_ReplaceText] ('' + sub.SourceField + '', 1)'' ELSE sub.SourceField END, ''''''NONE''''''),
			ISNULL(sub.SequenceBM, 0),
			sub.LinkedDimension,
			sub.LinkedProperty,
			sub.GroupByYN,
			sub.DeleteJoinYN,
			MappingTypeID = CONVERT(nvarchar(10), ISNULL(sub.MappingTypeID, 0) * CONVERT(int, DT.MappingEnabledYN) * CONVERT(int, sub.MappingEnabledYN)),
			MappingEnabledYN = CONVERT(int, DT.MappingEnabledYN) * CONVERT(int, sub.MappingEnabledYN),
			ReplaceTextYN = CONVERT(int, sub.ReplaceTextYN) * CONVERT(int, DT.ReplaceTextEnabledYN),
			sub.VisibilityLevelBM,
			sub.SortOrder,
			MappedLabelYN = CASE WHEN ML.MappedObjectName IS NULL THEN 0 ELSE 1 END
		FROM
			('
		SET @SQLStatement = @SQLStatement + '
			--Dimensions
			SELECT DISTINCT
				D.DimensionID,
				MO.DimensionTypeID,
				MO.MappedObjectName,
				SourceField = SSMF.SourceString,
				SequenceBM = SSMF.SequenceBM,
				LinkedDimension = MOLD.MappedObjectName,
				LinkedProperty = MOLP.MappedObjectName,
				GroupByYN = SSMF.GroupByYN,
				D.DeleteJoinYN,
				MO.MappingTypeID,
				MD.MappingEnabledYN,
				ReplaceTextYN = CONVERT(int, MO.ReplaceTextYN) * CONVERT(int, SSMF.ReplaceTextYN),
				VisibilityLevelBM = MD.VisibilityLevelBM + CASE WHEN MO.SelectYN <> 0 AND MO.ModelBM & ' + CONVERT(nvarchar, @ModelBM) + ' > 0 AND MD.[VisibilityLevelBM] & 8 <= 0 THEN 8 ELSE 0 END,
				SortOrder = 2
			FROM
				' + @ETLDatabase + '.dbo.MappedObject MO
				INNER JOIN pcINTEGRATOR.dbo.Model M ON M.ModelBM = ' + CONVERT(nvarchar, @ModelBM) + '
				INNER JOIN pcINTEGRATOR.dbo.Dimension D ON D.DimensionName = MO.ObjectName AND D.SelectYN <> 0
				INNER JOIN pcINTEGRATOR.dbo.Model_Dimension MD ON MD.ModelID = M.ModelID AND MD.DimensionID = D.DimensionID
				LEFT JOIN pcINTEGRATOR.dbo.SqlSource_Model_FACT SSMF ON SSMF.DimensionID = D.DimensionID AND SSMF.SourceTypeBM & ' + CONVERT(nvarchar, @SourceTypeBM) + ' > 0 AND SSMF.RevisionBM & ' + CONVERT(nvarchar, @RevisionBM) + ' > 0 AND SSMF.ModelBM & ' + CONVERT(nvarchar, @ModelBM) + ' > 0 AND SSMF.LinkedBM & ' + CONVERT(nvarchar, @LinkedBM) + ' > 0 AND SSMF.SelectYN <> 0
				LEFT JOIN pcINTEGRATOR.dbo.Property LP ON LP.PropertyID = MD.LinkedPropertyID AND LP.Introduced < ''' + @Version + ''' AND LP.SelectYN <> 0
				LEFT JOIN ' + @ETLDatabase + '.dbo.MappedObject MOLP ON MOLP.Entity = ''-1'' AND MOLP.DimensionTypeID NOT IN (-1) AND MOLP.ObjectName = LP.PropertyName AND MOLP.ObjectTypeBM & 4 > 0 AND MOLP.SelectYN <> 0
				LEFT JOIN pcINTEGRATOR.dbo.Dimension LD ON LD.DimensionID = LP.DimensionID AND LD.Introduced < ''' + @Version + ''' AND LD.SelectYN <> 0
				LEFT JOIN ' + @ETLDatabase + '.dbo.MappedObject MOLD ON MOLD.Entity = ''-1'' AND MOLD.DimensionTypeID NOT IN (-1) AND MOLD.ObjectName = LD.DimensionName AND MOLD.ObjectTypeBM & 2 > 0 AND MOLD.SelectYN <> 0
			WHERE
				MO.Entity = ''-1'' AND
				MO.DimensionTypeID NOT IN (-1) AND
				(MO.ModelBM & ' + CONVERT(nvarchar, @ModelBM) + ' > 0 OR MD.[VisibilityLevelBM] & 14 > 0) AND
				MO.ObjectTypeBM & 2 > 0 AND
				(MO.SelectYN <> 0 OR MD.[VisibilityLevelBM] & 14 > 0)'
--				 AND
--				(D.DimensionID <> -1 OR (D.DimensionID = -1 AND M.FinanceAccountYN = 0))'

		SET @SQLStatement = @SQLStatement + '
			--Not visible dimensions existing in SqlSource_Model_FACT
			UNION SELECT DISTINCT
				D.DimensionID,
				D.DimensionTypeID,
				MappedObjectName = D.DimensionName,
				SourceField = SSMF.SourceString,
				SequenceBM = SSMF.SequenceBM,
				LinkedDimension = NULL,
				LinkedProperty = NULL,
				GroupByYN = SSMF.GroupByYN,
				D.DeleteJoinYN,
				MappingTypeID = 0,
				MappingEnabledYN = 0,
				ReplaceTextYN = 0,
				MD.VisibilityLevelBM,
				SortOrder = 2
			FROM
				pcINTEGRATOR.dbo.SqlSource_Model_FACT SSMF
				INNER JOIN pcINTEGRATOR.dbo.Model M ON M.ModelBM = ' + CONVERT(nvarchar, @ModelBM) + '
				INNER JOIN pcINTEGRATOR.dbo.Dimension D ON D.DimensionID <> 0 AND D.DimensionID = SSMF.DimensionID AND D.SelectYN <> 0
				INNER JOIN pcINTEGRATOR.dbo.Model_Dimension MD ON MD.ModelID = M.ModelID AND MD.DimensionID = D.DimensionID AND MD.[VisibilityLevelBM] & 8 <= 0 AND MD.[VisibilityLevelBM] & 6 > 0
			WHERE
				SSMF.SourceTypeBM & ' + CONVERT(nvarchar, @SourceTypeBM) + ' > 0 AND 
				SSMF.RevisionBM & ' + CONVERT(nvarchar, @RevisionBM) + ' > 0 AND 
				SSMF.ModelBM & ' + CONVERT(nvarchar, @ModelBM) + ' > 0 AND 
				SSMF.LinkedBM & ' + CONVERT(nvarchar, @LinkedBM) + ' > 0 AND
				SSMF.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM ' + @ETLDatabase + '.dbo.MappedObject MO WHERE MO.ObjectName = D.DimensionName AND MO.ObjectTypeBM & 2 > 0)'

		SET @SQLStatement = @SQLStatement + '
			--Measure
			UNION SELECT DISTINCT
				DimensionID = SSMF.DimensionID,
				DimensionTypeID = 0,
				MappedObjectName = ''' + @ModelName + ''' + ''_Value'',
				SourceField = SSMF.SourceString,
				SequenceBM = SSMF.SequenceBM,
				LinkedDimension = NULL,
				LinkedProperty = NULL,
				GroupByYN = SSMF.GroupByYN,
				DeleteJoinYN = 0,
				MappingTypeID = 0,
				MappingEnabledYN = 0,
				ReplaceTextYN = 0,
				VisibilityLevelBM = 8,
				SortOrder = 4
			FROM
				pcINTEGRATOR.dbo.SqlSource_Model_FACT SSMF
			WHERE
				SSMF.DimensionID = 10 AND
				SSMF.SourceTypeBM & ' + CONVERT(nvarchar, @SourceTypeBM) + ' > 0 AND
				SSMF.RevisionBM & ' + CONVERT(nvarchar, @RevisionBM) + ' > 0 AND
				SSMF.ModelBM & ' + CONVERT(nvarchar, @ModelBM) + ' > 0 AND
				SSMF.LinkedBM & ' + CONVERT(nvarchar, @LinkedBM) + ' > 0 AND
				SSMF.SelectYN <> 0
			) sub
			INNER JOIN pcINTEGRATOR.dbo.DimensionType DT ON DT.DimensionTypeID = sub.DimensionTypeID
			LEFT JOIN (SELECT DISTINCT MappedObjectName FROM ' + @ETLDatabase + '.[dbo].[MappedLabel] WHERE SelectYN <> 0) ML ON ML.MappedObjectName = sub.MappedObjectName
		ORDER BY
			sub.SortOrder,
			sub.[MappedObjectName]'

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Add Generic rows to temp table', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)

	SET @Step = 'Set @SequenceBMSum'
		SELECT DISTINCT
			SequenceBM
		INTO
			#SequenceBM
		FROM
			SqlSource_Model_FACT SSMF
		WHERE
			SSMF.SourceTypeBM & @SourceTypeBM > 0 AND
			SSMF.RevisionBM & @RevisionBM > 0 AND
			SSMF.ModelBM & @ModelBM > 0 AND
			SSMF.LinkedBM & @LinkedBM > 0 AND
			SSMF.SelectYN <> 0

		CREATE TABLE #SequenceBMSum
			(
			SequenceBMSum int
			)

		DECLARE SequenceBMSum_Cursor CURSOR FOR

			SELECT 
				SequenceBM
			FROM
				#SequenceBM
			ORDER BY
				SequenceBM

			OPEN SequenceBMSum_Cursor
			FETCH NEXT FROM SequenceBMSum_Cursor INTO @SequenceBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT SequenceBM = @SequenceBM

					INSERT INTO #SequenceBMSum (SequenceBMSum) SELECT SequenceBMSum =   1 WHERE @SequenceBM &   1 > 0 AND NOT EXISTS (SELECT 1 FROM #SequenceBMSum WHERE SequenceBMSum =   1)
					INSERT INTO #SequenceBMSum (SequenceBMSum) SELECT SequenceBMSum =   2 WHERE @SequenceBM &   2 > 0 AND NOT EXISTS (SELECT 1 FROM #SequenceBMSum WHERE SequenceBMSum =   2)
					INSERT INTO #SequenceBMSum (SequenceBMSum) SELECT SequenceBMSum =   4 WHERE @SequenceBM &   4 > 0 AND NOT EXISTS (SELECT 1 FROM #SequenceBMSum WHERE SequenceBMSum =   4)
					INSERT INTO #SequenceBMSum (SequenceBMSum) SELECT SequenceBMSum =   8 WHERE @SequenceBM &   8 > 0 AND NOT EXISTS (SELECT 1 FROM #SequenceBMSum WHERE SequenceBMSum =   8)
					INSERT INTO #SequenceBMSum (SequenceBMSum) SELECT SequenceBMSum =  16 WHERE @SequenceBM &  16 > 0 AND NOT EXISTS (SELECT 1 FROM #SequenceBMSum WHERE SequenceBMSum =  16)
					INSERT INTO #SequenceBMSum (SequenceBMSum) SELECT SequenceBMSum =  32 WHERE @SequenceBM &  32 > 0 AND NOT EXISTS (SELECT 1 FROM #SequenceBMSum WHERE SequenceBMSum =  32)
					INSERT INTO #SequenceBMSum (SequenceBMSum) SELECT SequenceBMSum =  64 WHERE @SequenceBM &  64 > 0 AND NOT EXISTS (SELECT 1 FROM #SequenceBMSum WHERE SequenceBMSum =  64)
					INSERT INTO #SequenceBMSum (SequenceBMSum) SELECT SequenceBMSum = 128 WHERE @SequenceBM & 128 > 0 AND NOT EXISTS (SELECT 1 FROM #SequenceBMSum WHERE SequenceBMSum = 128)
					INSERT INTO #SequenceBMSum (SequenceBMSum) SELECT SequenceBMSum = 256 WHERE @SequenceBM & 256 > 0 AND NOT EXISTS (SELECT 1 FROM #SequenceBMSum WHERE SequenceBMSum = 256)
					INSERT INTO #SequenceBMSum (SequenceBMSum) SELECT SequenceBMSum = 512 WHERE @SequenceBM & 512 > 0 AND NOT EXISTS (SELECT 1 FROM #SequenceBMSum WHERE SequenceBMSum = 512)

					FETCH NEXT FROM SequenceBMSum_Cursor INTO @SequenceBM
				END

		CLOSE SequenceBMSum_Cursor
		DEALLOCATE SequenceBMSum_Cursor

		SELECT @SequenceBMSum = SUM(SequenceBMSum) FROM #SequenceBMSum
		SELECT @SequenceBMSum = ISNULL(@SequenceBMSum, 0)

		DROP TABLE #SequenceBM
		DROP TABLE #SequenceBMSum

		IF @Debug <> 0
			SELECT
				SequenceBMSum = @SequenceBMSum,
				SourceTypeBM = @SourceTypeBM,
				RevisionBM = @RevisionBM,
				ModelBM = @ModelBM,
				LinkedBM = @LinkedBM

	IF @OptFinanceDimYN <> 0
		BEGIN
		SET @Step = 'Add GL-Segment rows to #Dimension table, source specific'

		IF @SourceTypeFamilyID IN (1, 4) --Epicor ERP, Dynamics AX
			BEGIN
				CREATE TABLE #SegmentList
					(
					DimensionTypeID int,
					MappedObjectName nvarchar(100) COLLATE DATABASE_DEFAULT,
					SegmentCode nvarchar(100) COLLATE DATABASE_DEFAULT,
					Entity nvarchar(100) COLLATE DATABASE_DEFAULT,
					Company_COACode nvarchar(100) COLLATE DATABASE_DEFAULT
					)

				SET @SQLStatement = '
				INSERT INTO #SegmentList
					(
					DimensionTypeID,
					MappedObjectName,
					SegmentCode,
					Entity,
					Company_COACode
					)
				SELECT DISTINCT
					FS.DimensionTypeID,
					MO.MappedObjectName,
					SegmentCode = CASE ' + CONVERT(nvarchar(10), @SourceTypeFamilyID) + ' WHEN 1 THEN FS.SegmentCode WHEN 4 THEN MO.MappedObjectName END,
					E.Entity,
					FS.Company_COACode
				FROM
					' + @ETLDatabase + '.dbo.MappedObject MO
					INNER JOIN ' + @ETLDatabase + '.dbo.[Entity] E ON E.SourceID = ' + CONVERT(nvarchar, @SourceID) + ' AND (E.Entity = MO.Entity OR MO.DimensionTypeID = 1)
					INNER JOIN ' + @ETLDatabase + '.dbo.[FinancialSegment] FS ON FS.SourceID = E.SourceID AND FS.EntityCode COLLATE DATABASE_DEFAULT = E.EntityCode AND (FS.SegmentName COLLATE DATABASE_DEFAULT = MO.ObjectName OR (FS.DimensionTypeID = 1 AND MO.DimensionTypeID = 1))
				WHERE
					MO.DimensionTypeID IN (-1, 1) AND
					MO.ObjectTypeBM & 2 > 0 AND
					MO.SelectYN <> 0'

				EXEC (@SQLStatement)

				IF @Debug <> 0 SELECT TempTable = '#SegmentList', * FROM #SegmentList

				CREATE TABLE #Segment_Dimensions
					(
					DimensionTypeID int,
					MappedObjectName nvarchar(100) COLLATE DATABASE_DEFAULT,
					SourceField nvarchar(max) COLLATE DATABASE_DEFAULT,
					SequenceBM int,
					SortOrder int
					)

			
				IF @SourceTypeFamilyID IN (1) --Epicor ERP
					BEGIN
						SET @Step = 'Run GL_Segment_Cursor'
						CREATE TABLE #TotalEntityCount (TotalEntityCount int)
						SET @SQLStatement = '
						INSERT INTO #TotalEntityCount (TotalEntityCount) SELECT TotalEntityCount = COUNT(DISTINCT E.Entity) FROM ' + @ETLDatabase + '.[dbo].[FinancialSegment] FS
						INNER JOIN ' + @ETLDatabase + '.[dbo].[Entity] E ON E.SourceID = ' + CONVERT(nvarchar, @SourceID) + ' AND E.SourceID = FS.SourceID AND E.EntityCode = FS.EntityCode COLLATE DATABASE_DEFAULT AND E.SelectYN <> 0'
						EXEC (@SQLStatement)
						SELECT @TotalEntityCount = TotalEntityCount FROM #TotalEntityCount
						DROP TABLE #TotalEntityCount

						IF @Debug <> 0 SELECT TotalEntityCount = @TotalEntityCount

						DECLARE GL_Segment_Cursor CURSOR FOR

						SELECT
							MappedObjectName
						FROM
							(
							SELECT DISTINCT
								MappedObjectName,
								DimensionTypeID
							FROM
								#SegmentList
							) sub
						ORDER BY
							DimensionTypeID DESC,
							MappedObjectName

						OPEN GL_Segment_Cursor
						FETCH NEXT FROM GL_Segment_Cursor INTO @MappedObjectName

						WHILE @@FETCH_STATUS = 0
							BEGIN
								SELECT @SegmentCode = MAX(SegmentCode) FROM #SegmentList WHERE MappedObjectName = @MappedObjectName
								SELECT @EntityCount = COUNT(DISTINCT Entity) FROM #SegmentList WHERE MappedObjectName = @MappedObjectName AND SegmentCode = @SegmentCode

								IF @EntityCount = @TotalEntityCount
									BEGIN
										IF @Debug <> 0 
											BEGIN
												SELECT MappedObjectName = @MappedObjectName, EntityCount = @EntityCount
												SELECT DISTINCT
													TempTable = '#SegmentList', 
													DimensionTypeID = MAX(SL.DimensionTypeID),
													MappedObjectName,
													SourceField = 'F.' + MAX(SL.SegmentCode) + ' COLLATE DATABASE_DEFAULT',
													SortOrder = CASE WHEN MAX(SL.DimensionTypeID) = -1 THEN 3 ELSE 1 END
												FROM
													#SegmentList SL
												WHERE
													SL.MappedObjectName = @MappedObjectName AND
													SL.SegmentCode = @SegmentCode
												GROUP BY
													SL.MappedObjectName
											END

										INSERT INTO #Segment_Dimensions
											(
											DimensionTypeID,
											MappedObjectName,
											SourceField,
											SequenceBM,
											SortOrder
											)
										SELECT DISTINCT
											DimensionTypeID = MAX(SL.DimensionTypeID),
											MappedObjectName,
											SourceField = 'F.' + MAX(SL.SegmentCode),
											SequenceBM = @SequenceBMSum,
											SortOrder = CASE WHEN MAX(SL.DimensionTypeID) = -1 THEN 3 ELSE 1 END
										FROM
											#SegmentList SL
										WHERE
											SL.MappedObjectName = @MappedObjectName AND
											SL.SegmentCode = @SegmentCode
										GROUP BY
											SL.MappedObjectName
									END
								ELSE
									BEGIN
										IF @Debug <> 0 SELECT MappedObjectName = @MappedObjectName, 'Run per Entity'

										SELECT
											@SQLStatement_SourceString = '',
											@PrevSegmentCode = ''

										DECLARE SegmentCode_Cursor CURSOR FOR

										SELECT
											SegmentCode, 
											Company_COACode
										FROM
											#SegmentList 
										WHERE
											MappedObjectName = @MappedObjectName
										ORDER BY
											SegmentCode, 
											Company_COACode

										OPEN SegmentCode_Cursor
										FETCH NEXT FROM SegmentCode_Cursor INTO @SegmentCode, @Company_COACode

										WHILE @@FETCH_STATUS = 0
											BEGIN
												IF @SegmentCode <> @PrevSegmentCode
													IF LEN(@SQLStatement_SourceString) < 1
														SET @SQLStatement_SourceString = @SQLStatement_SourceString + 'CASE WHEN E.Par01 + ''_'' + E.Par03 IN (''' + @Company_COACode + ''''
													ELSE
														SET @SQLStatement_SourceString = @SQLStatement_SourceString + ') THEN F.' + @PrevSegmentCode + ' ELSE '''' END + CASE WHEN E.Par01 + ''_'' + E.Par03 IN (''' + @Company_COACode + ''''
												ELSE
													SET @SQLStatement_SourceString = @SQLStatement_SourceString + ', ''' + @Company_COACode + ''''

												SET @PrevSegmentCode = @SegmentCode
												FETCH NEXT FROM SegmentCode_Cursor INTO @SegmentCode, @Company_COACode
											END

										CLOSE SegmentCode_Cursor
										DEALLOCATE SegmentCode_Cursor

										SET @SQLStatement_SourceString = @SQLStatement_SourceString + ') THEN F.' + @PrevSegmentCode + ' ELSE '''' END'
						
										IF @Debug <> 0 SELECT SQLSourceString = @SQLStatement_SourceString, SegmentCode = @SegmentCode

										INSERT INTO #Segment_Dimensions
											(
											DimensionTypeID,
											MappedObjectName,
											SourceField,
											SequenceBM,
											SortOrder
											)
										SELECT DISTINCT
											DimensionTypeID = MAX(SL.DimensionTypeID),
											MappedObjectName,
											SourceField = @SQLStatement_SourceString,
											SequenceBM = 7,
											SortOrder = CASE WHEN MAX(SL.DimensionTypeID) = -1 THEN 3 ELSE 1 END
										FROM
											#SegmentList SL
										WHERE
											SL.MappedObjectName = @MappedObjectName AND
											SL.SegmentCode = @SegmentCode
										GROUP BY
											SL.MappedObjectName
									END
								FETCH NEXT FROM GL_Segment_Cursor INTO @MappedObjectName
							END

						CLOSE GL_Segment_Cursor
						DEALLOCATE GL_Segment_Cursor
					END --Epicor ERP

				ELSE IF @SourceTypeFamilyID IN (4) --Dynamics AX
					BEGIN
						INSERT INTO #Segment_Dimensions
							(
							DimensionTypeID,
							MappedObjectName,
							SourceField,
							SequenceBM,
							SortOrder
							)
						SELECT DISTINCT
							DimensionTypeID = MAX(SL.DimensionTypeID),
							MappedObjectName,
							SourceField = 'FA.' + MAX(SL.SegmentCode),
							SequenceBM = 1,
							SortOrder = CASE WHEN MAX(SL.DimensionTypeID) = -1 THEN 3 ELSE 1 END
						FROM
							#SegmentList SL
						GROUP BY
							SL.MappedObjectName
					END

				IF @Debug <> 0 SELECT TempTable = '#Segment_Dimensions', * FROM #Segment_Dimensions

				SET @SQLStatement = '
				INSERT INTO #Dimension
					(
					DimensionID,
					DimensionTypeID,
					MappedObjectName,
					SourceField,
					SequenceBM,
					GroupByYN,
					MappingTypeID,
					MappingEnabledYN,
					ReplaceTextYN,
					VisibilityLevelBM,
					SortOrder,
					MappedLabelYN
					)
				SELECT DISTINCT
					DimensionID = CASE SD.DimensionTypeID WHEN 1 THEN -1 WHEN -1 THEN 0 END,
					SD.DimensionTypeID,
					SD.MappedObjectName,
					SourceField = CASE WHEN SD.SourceField = '''' THEN ''''''NONE'''''' ELSE CASE WHEN CONVERT(int, MO.ReplaceTextYN) * CONVERT(int, DT.ReplaceTextEnabledYN) <> 0 THEN ''[dbo].[f_ReplaceText] ('' + SD.SourceField + '', 1)'' ELSE SD.SourceField END END,
					SequenceBM = SD.SequenceBM,
					GroupByYN = CASE WHEN SD.SourceField = '''' THEN 0 ELSE 1 END,
					MappingTypeID = ISNULL(MO.MappingTypeID, 0),
					MappingEnabledYN = DT.MappingEnabledYN,
					ReplaceTextYN = ISNULL(MO.ReplaceTextYN, 0),
					VisibilityLevelBM = 8,
					SortOrder = SD.SortOrder,
					MappedLabelYN = CASE WHEN ML.MappedObjectName IS NULL THEN 0 ELSE 1 END'
				SET @SQLStatement = @SQLStatement + '
				FROM
					#Segment_Dimensions SD
					INNER JOIN DimensionType DT ON DT.DimensionTypeID = SD.DimensionTypeID
					LEFT JOIN (SELECT DISTINCT MappedObjectName FROM ' + @ETLDatabase + '.[dbo].[MappedLabel] WHERE SelectYN <> 0) ML ON ML.MappedObjectName = SD.MappedObjectName
					LEFT JOIN (	SELECT
									MO.MappedObjectName,
									MappingTypeID = MAX(MO.MappingTypeID),
									ReplaceTextYN = MAX(CONVERT(int, MO.ReplaceTextYN))
								FROM
									' + @ETLDatabase + '.dbo.MappedObject MO 
									INNER JOIN ' + @ETLDatabase + '.dbo.Entity E ON E.SourceID = ' + CONVERT(nvarchar, @SourceID) + ' AND (E.Entity = MO.Entity OR MO.DimensionTypeID = 1) AND E.SelectYN <> 0
								WHERE
									MO.DimensionTypeID IN (1, -1) AND
									MO.ObjectTypeBM & 2 > 0
								GROUP BY
									MO.MappedObjectName
								) MO ON SD.MappedObjectName COLLATE DATABASE_DEFAULT = MO.MappedObjectName'

				EXEC (@SQLStatement)

				SET @Step = 'Drop Epicor TempTables'
					DROP TABLE #SegmentList
					DROP TABLE #Segment_Dimensions

			END

		ELSE IF @SourceDBTypeID = 2 --Multiple (verified for @SourceTypeID = 12 --EnterPrise)
			BEGIN

				SET @SQLStatement = '
					INSERT INTO #Dimension
					(
						DimensionID,
						DimensionTypeID,
						MappedObjectName,
						SourceField,
						SequenceBM,
						GroupByYN,
						MappingTypeID,
						MappingEnabledYN,
						ReplaceTextYN,
						VisibilityLevelBM,
						SortOrder,
						MappedLabelYN
					)
					SELECT DISTINCT
						DimensionID = CASE sub.DimensionTypeID WHEN 1 THEN -1 WHEN -1 THEN 0 END,
						sub.DimensionTypeID,
						sub.MappedObjectName,
						SourceField = CASE WHEN CONVERT(int, sub.ReplaceTextYN) * CONVERT(int, DT.ReplaceTextEnabledYN) <> 0 THEN ''[dbo].[f_ReplaceText] ('' + sub.SourceField + '', 1)'' ELSE sub.SourceField END,
						sub.SequenceBM,
						sub.GroupByYN,
						MappingTypeID = CONVERT(nvarchar(10), ISNULL(sub.MappingTypeID, 0) * CONVERT(int, DT.MappingEnabledYN)),
						DT.MappingEnabledYN,
						ReplaceTextYN = CONVERT(int, sub.ReplaceTextYN) * CONVERT(int, DT.ReplaceTextEnabledYN),
						VisibilityLevelBM = 8,
						sub.SortOrder,
						MappedLabelYN = CASE WHEN ML.MappedObjectName IS NULL THEN 0 ELSE 1 END
					FROM
						('

				SET @SQLStatement = @SQLStatement + '
						--Account & GLSegment
						SELECT DISTINCT
							MOA.DimensionTypeID,
							MOA.MappedObjectName,
							SourceField = ''sub.'' + MOA.MappedObjectName,
							SequenceBM = 0,
							GroupByYN = 0,
							MappingTypeID = 0,
							ReplaceTextYN = 0,
							SortOrder = CASE WHEN MOA.DimensionTypeID = -1 THEN 3 ELSE 1 END
						FROM
							(SELECT DISTINCT DimensionTypeID, MappedObjectName, ObjectName FROM ' + @ETLDatabase + '.dbo.MappedObject WHERE (DimensionTypeID = 1 OR (Entity <> ''-1'' AND SelectYN <> 0)) AND ModelBM & ' + CONVERT(nvarchar, @ModelBM) + ' > 0 AND ObjectTypeBM & 2 > 0) MOA
						) sub
						INNER JOIN pcINTEGRATOR.dbo.DimensionType DT ON DT.DimensionTypeID = sub.DimensionTypeID
						LEFT JOIN (SELECT DISTINCT MappedObjectName FROM ' + @ETLDatabase + '.[dbo].[MappedLabel] WHERE SelectYN <> 0) ML ON ML.MappedObjectName = sub.MappedObjectName
					ORDER BY
						sub.SortOrder,
						sub.[MappedObjectName]'

				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Add GL_Segment Rows to temp table', [SQLStatement] = @SQLStatement

				EXEC (@SQLStatement)


			END --End of @SourceDBTypeID = 2 --Multiple
		END --End of @OptFinanceDimYN <> 0

		IF @Debug <> 0 SELECT TempTable = '#Dimension', * FROM #Dimension ORDER BY SortOrder, [MappedObjectName], SequenceBM

		SELECT @FCurrency = MappedObjectName FROM #Dimension WHERE DimensionID = -3 AND DimensionTypeID = 3

--------------------------------------------------------

	SET @Step = 'Create SQL variables on top level'

		SELECT
			DimensionID = MAX(D.DimensionID),
			MappedObjectName = D.MappedObjectName,
			SourceField = CASE WHEN MAX(D.LinkedDimension) IS NOT NULL THEN '' ELSE MAX(ISNULL(D1.SourceField, '[sub].[' + D.MappedObjectName + ']')) END,
			SourceFieldID = MAX(CASE WHEN D.SortOrder = 4 THEN '[' + D.MappedObjectName + ']' ELSE '[' + D.MappedObjectName + '_MemberId] = ISNULL([' + ISNULL(D.LinkedDimension, D.MappedObjectName) + '].[' + CASE WHEN D.LinkedProperty IS NULL THEN '' ELSE D.LinkedProperty + '_' END + 'MemberId], -1),' END),
			SubLevelYN = CASE WHEN MAX(D.SourceField) IS NULL THEN 0 ELSE 1 END,
			VisibilityLevelBM = MAX(D.VisibilityLevelBM),
			SortOrder = MAX(D.SortOrder)
		INTO
			#FieldList
		FROM
			#Dimension D
			LEFT JOIN #Dimension D1 ON D1.MappedObjectName = D.MappedObjectName AND D1.SequenceBM = 0
		GROUP BY
			D.MappedObjectName

		IF @Debug <> 0 SELECT TempTable = '#FieldList', * FROM #FieldList

		SELECT 
			@SQLStatement_CreateTable = ISNULL(@SQLStatement_CreateTable, '') + CASE WHEN VisibilityLevelBM & 12 > 0 THEN CASE WHEN SortOrder = 4 THEN '' ELSE + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + MappedObjectName + '_MemberId] bigint,' END ELSE '' END,
			@SQLStatement_InsertInto = ISNULL(@SQLStatement_InsertInto, '') + CASE WHEN VisibilityLevelBM & 8 > 0 AND SortOrder <> 4 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + MappedObjectName + '_MemberId],' ELSE '' END,
			@SQLStatement_Select = ISNULL(@SQLStatement_Select, '') + CASE WHEN SubLevelYN = 0 OR SourceField = '' THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + MappedObjectName + '] = ' + SourceField + CASE WHEN SortOrder = 4 THEN '' ELSE ',' END END,
			@SQLStatement_SelectID = ISNULL(@SQLStatement_SelectID, '') + CASE WHEN VisibilityLevelBM & 12 > 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + SourceFieldID ELSE '' END,
			@SQLStatement_DimJoin = ISNULL(@SQLStatement_DimJoin, '') + CASE WHEN VisibilityLevelBM & 12 > 0 THEN CASE WHEN SortOrder = 4 OR SourceField = '' THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'LEFT JOIN [' + @DestinationDatabase + '].[dbo].[S_DS_' + MappedObjectName + '] [' + MappedObjectName + '] ON [' + MappedObjectName + '].Label COLLATE DATABASE_DEFAULT = [Raw].[' + MappedObjectName + ']' END ELSE '' END
		FROM
			#FieldList
		ORDER BY
			[SortOrder],
			[MappedObjectName]

		SELECT
			@SQLStatement_Where = SSMF.SourceString
		FROM
			pcINTEGRATOR.dbo.SqlSource_Model_FACT SSMF
		WHERE
			SSMF.SequenceBM = 0 AND
			SSMF.DimensionID IN (200) AND 
			SSMF.SourceTypeBM & @SourceTypeBM > 0 AND
			SSMF.RevisionBM & @RevisionBM > 0 AND
			SSMF.ModelBM & @ModelBM > 0 AND
			SSMF.LinkedBM & @LinkedBM > 0 AND
			SSMF.SelectYN <> 0

		SELECT @SQLStatement_Where = ISNULL(@SQLStatement_Where, CHAR(9) + CHAR(9) + '1 = 1')

		SELECT 
			@SQLStatement_Delete = CASE WHEN @SQLStatement_Delete IS NULL THEN '' ELSE @SQLStatement_Delete + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) END + '[' + MappedObjectName + '_MemberId]',
			@SQLStatement_DeleteJoin = CASE WHEN @SQLStatement_DeleteJoin IS NULL THEN '' ELSE @SQLStatement_DeleteJoin + ' AND' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) END + 'V.[' + MappedObjectName + '_MemberId] = ' + ISNULL(LinkedDimension, 'F') + '.[' + MappedObjectName + '_MemberId]'
		FROM
			(SELECT DISTINCT [MappedObjectName], [SortOrder], [LinkedDimension] FROM #Dimension WHERE DeleteJoinYN <> 0) sub
		ORDER BY
			[SortOrder],
			[MappedObjectName]

		IF (SELECT COUNT(1) FROM #Dimension WHERE DimensionID = -7 AND DeleteJoinYN <> 0) = 0
			BEGIN
				CREATE TABLE #TimeProp (ObjectName nvarchar(100) COLLATE DATABASE_DEFAULT, MappedObjectName nvarchar(100) COLLATE DATABASE_DEFAULT)

				SET @SQLStatement = 'INSERT INTO #TimeProp (ObjectName, MappedObjectName) SELECT ObjectName, MappedObjectName FROM ' + @ETLDatabase + '..MappedObject WHERE ObjectTypeBM & 2 > 0 AND ObjectName IN (''Time'', ''TimeYear'', ''TimeMonth'')'
				EXEC (@SQLStatement)

				SELECT
					@FTime = MAX(CASE WHEN ObjectName = 'Time' THEN MappedObjectName END),
					@FTimeYear = MAX(CASE WHEN ObjectName = 'TimeYear' THEN MappedObjectName END),
					@FTimeMonth = MAX(CASE WHEN ObjectName = 'TimeMonth' THEN MappedObjectName END)
				FROM
					#TimeProp
		
				DROP TABLE #TimeProp

				SELECT @SQLStatement_Delete = @SQLStatement_Delete + ',' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + @FTime + '_MemberId] = [' + @FTimeYear + '_MemberId] * 100 + ([' + @FTimeMonth + '_MemberId] - 100)'
			END

		SELECT 
			@SQLStatement_FACT_DeleteJoin = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN @SourceDBTypeID = 2 THEN CHAR(9) + CHAR(9) + CHAR(9) ELSE '' END + ISNULL(@SQLStatement_FACT_DeleteJoin, '') + 'INNER JOIN [' + @DestinationDatabase + '].[dbo].[S_DS_' + [LinkedDimension] + '] ' + [LinkedDimension] + ' ON ' + [LinkedDimension] + '.MemberId = F.' + [LinkedDimension] + '_MemberId'
		FROM
			(SELECT DISTINCT [LinkedDimension], [SortOrder] FROM #Dimension WHERE [LinkedDimension] IS NOT NULL AND DeleteJoinYN <> 0) sub
		ORDER BY
			[SortOrder],
			[LinkedDimension]

-----------------------------------------
	IF @SourceDBTypeID = 1 --Single DB
		BEGIN
			CREATE TABLE #SubSelect
			(
				DimensionID int,
				MappedObjectName nvarchar(100) COLLATE DATABASE_DEFAULT,
				SourceField nvarchar(max) COLLATE DATABASE_DEFAULT,
				GroupByYN bit,
				MappingTypeID nvarchar(10) COLLATE DATABASE_DEFAULT,
				MappingEnabledYN bit,
				SortOrder int,
				MappedLabelYN bit
			)

			SET @Step = 'Create SQL variables on sub level'
/*
				SELECT
					@SequenceBMSum = SUM(SequenceBM)
				FROM
					pcINTEGRATOR.dbo.SqlSource_Model_FACT SSMF
				WHERE
					SSMF.DimensionID = 100 AND 
					SSMF.SourceTypeBM & @SourceTypeBM > 0 AND
					SSMF.RevisionBM & @RevisionBM > 0 AND
					SSMF.ModelBM & @ModelBM > 0 AND
					SSMF.LinkedBM & @LinkedBM > 0 AND
					SSMF.SelectYN <> 0
*/
				SET @SQLStatement = NULL
				SET @SequenceCounter = 1
				SET @SequenceBMStep = 1
				WHILE @SequenceBMSum & @SequenceBMStep > 0
					BEGIN
						IF @Debug <> 0 SELECT SequenceBMStep = @SequenceBMStep, TempTable = '#Dimension', * FROM #Dimension D WHERE D.SequenceBM & @SequenceBMStep > 0 ORDER BY D.[SortOrder], D.[MappedObjectName]

						TRUNCATE TABLE #SubSelect
						INSERT INTO #SubSelect
							(
							MappedObjectName,
							SourceField,
							GroupByYN,		
							MappingTypeID,
							MappingEnabledYN,
							SortOrder,
							MappedLabelYN
							)
						SELECT
							MappedObjectName,
							SourceField,
							GroupByYN,		
							MappingTypeID,
							MappingEnabledYN,
							SortOrder,
							MappedLabelYN
						FROM
							(
							SELECT
								MappedObjectName,
								MappingEnabledYN = MAX(CONVERT(int, MappingEnabledYN)),
								SourceField = CASE WHEN MIN(SourceField) <> MAX(SourceField) THEN MAX(SourceField) + ' + ' + MIN(SourceField) ELSE MAX(SourceField) END,
								MappingTypeID = MAX(MappingTypeID),
								GroupByYN = MAX(CONVERT(int, GroupByYN)),
								SortOrder = MIN(SortOrder),
								MappedLabelYN = MAX(CONVERT(int, MappedLabelYN))
							FROM
								#Dimension
							WHERE
								SequenceBM & @SequenceBMStep > 0
							GROUP BY
								MappedObjectName

							UNION
							SELECT DISTINCT
								D1.MappedObjectName,
								MappingEnabledYN = 0,
								SourceField = '''NONE''',
								MappingTypeID = 0,
								GroupByYN = 0,
								D1.SortOrder,
								D1.MappedLabelYN
							FROM
								#Dimension D1
							WHERE
								D1.SequenceBM > 0 AND
								NOT EXISTS (SELECT 1 FROM #Dimension D2 WHERE D2.DimensionTypeID = D1.DimensionTypeID AND D2.MappedObjectName = D1.MappedObjectName AND D2.SequenceBM & @SequenceBMStep > 0)
							) sub

							IF @Debug <> 0 SELECT TempTable = '#SubSelect', * FROM #SubSelect D ORDER BY D.[SortOrder], D.[MappedObjectName]

							SELECT 
--								@SQLStatement_SubSelect = ISNULL(@SQLStatement_SubSelect, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' +  D.MappedObjectName + '] = ' + CASE WHEN D.MappingEnabledYN = 0 OR D.MappedLabelYN = 0 OR D.[SourceField] = '''NONE''' THEN CASE WHEN D.MappedLabelYN = 0 AND D.MappingTypeID = 1 THEN 'E.Entity + ''_'' + ' ELSE '' END + CASE WHEN D.[SourceField] <> '''NONE''' AND D.MappedLabelYN = 0 AND D.MappingTypeID IN (1, 2) THEN '(' ELSE '' END + D.SourceField + CASE WHEN D.[SourceField] <> '''NONE''' AND D.MappedLabelYN = 0 AND D.MappingTypeID IN (1, 2) THEN ') COLLATE DATABASE_DEFAULT' ELSE '' END + CASE WHEN D.MappedLabelYN = 0 AND D.MappingTypeID = 2 THEN ' + ''_'' + E.Entity' ELSE '' END ELSE 'CASE WHEN ISNULL([ML_' + D.MappedObjectName + '].MappingTypeID, ' + D.MappingTypeID + ') = 1 THEN E.Entity + ''_'' ELSE '''' END + CASE WHEN ' + D.[SourceField]  + ' <> ''''''NONE'''''' AND ISNULL([ML_' + D.MappedObjectName + '].MappingTypeID, ' + D.MappingTypeID + ') IN (1, 2) THEN ''('' ELSE '''' END + CASE WHEN [ML_' + D.MappedObjectName + '].MappingTypeID = 3 THEN [ML_' + D.MappedObjectName + '].MappedLabel ELSE ' + D.SourceField + ' END + CASE WHEN ' + D.[SourceField]  + ' <> ''''''NONE'''''' AND ISNULL([ML_' + D.MappedObjectName + '].MappingTypeID, ' + D.MappingTypeID + ') IN (1, 2) THEN '') COLLATE DATABASE_DEFAULT'' ELSE '''' END + CASE WHEN ISNULL([ML_' + D.MappedObjectName + '].MappingTypeID, ' + D.MappingTypeID + ') = 2 THEN ''_'' + E.Entity ELSE '''' END' END + CASE WHEN D.SortOrder = 4 THEN '' ELSE ',' END,
--								@SQLStatement_SubGroupBy = ISNULL(@SQLStatement_SubGroupBy, '') + CASE WHEN D.[GroupByYN] = 0 THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN D.MappingEnabledYN = 0 OR D.MappedLabelYN = 0 THEN CASE WHEN D.MappedLabelYN = 0 AND D.MappingTypeID = 1 THEN 'E.Entity + ''_'' + ' ELSE '' END + CASE WHEN D.[SourceField] <> '''NONE''' AND D.MappedLabelYN = 0 AND D.MappingTypeID IN (1, 2) THEN '(' ELSE '' END + D.SourceField + CASE WHEN D.[SourceField] <> '''NONE''' AND D.MappedLabelYN = 0 AND D.MappingTypeID IN (1, 2) THEN ') COLLATE DATABASE_DEFAULT' ELSE '' END + CASE WHEN D.MappedLabelYN = 0 AND D.MappingTypeID = 2 THEN ' + ''_'' + E.Entity' ELSE '' END ELSE 'CASE WHEN ISNULL([ML_' + D.MappedObjectName + '].MappingTypeID, ' + D.MappingTypeID + ') = 1 THEN E.Entity + ''_'' ELSE '''' END + CASE WHEN ' + D.[SourceField]  + ' <> ''''''NONE'''''' AND ISNULL([ML_' + D.MappedObjectName + '].MappingTypeID, ' + D.MappingTypeID + ') IN (1, 2) THEN ''('' ELSE '''' END + CASE WHEN [ML_' + D.MappedObjectName + '].MappingTypeID = 3 THEN [ML_' + D.MappedObjectName + '].MappedLabel ELSE ' + D.SourceField + ' END + CASE WHEN ' + D.[SourceField]  + ' <> ''''''NONE'''''' AND ISNULL([ML_' + D.MappedObjectName + '].MappingTypeID, ' + D.MappingTypeID + ') IN (1, 2) THEN '') COLLATE DATABASE_DEFAULT'' ELSE '''' END + CASE WHEN ISNULL([ML_' + D.MappedObjectName + '].MappingTypeID, ' + D.MappingTypeID + ') = 2 THEN ''_'' + E.Entity ELSE '''' END' END + ',' END,

								@SQLStatement_SubSelect = ISNULL(@SQLStatement_SubSelect, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' +  D.MappedObjectName + '] = ' + CASE WHEN D.MappingEnabledYN = 0 OR D.MappedLabelYN = 0 OR D.[SourceField] = '''NONE''' THEN CASE WHEN D.MappedLabelYN = 0 AND D.MappingTypeID = 1 THEN 'E.Entity + ''_'' + ' ELSE '' END + CASE WHEN D.[SourceField] <> '''NONE''' AND D.MappedLabelYN = 0 AND D.MappingTypeID IN (1, 2) THEN '(' ELSE '' END + D.SourceField + CASE WHEN D.[SourceField] <> '''NONE''' AND D.MappedLabelYN = 0 AND D.MappingTypeID IN (1, 2) THEN ') COLLATE DATABASE_DEFAULT' ELSE '' END + CASE WHEN D.MappedLabelYN = 0 AND D.MappingTypeID = 2 THEN ' + ''_'' + E.Entity' ELSE '' END ELSE 'CASE WHEN ISNULL([ML_' + D.MappedObjectName + '].MappingTypeID, ' + D.MappingTypeID + ') = 1 THEN E.Entity + ''_'' ELSE '''' END + CASE WHEN [ML_' + D.MappedObjectName + '].MappingTypeID = 3 THEN [ML_' + D.MappedObjectName + '].MappedLabel ELSE (' + D.SourceField + ') COLLATE DATABASE_DEFAULT END + CASE WHEN ISNULL([ML_' + D.MappedObjectName + '].MappingTypeID, ' + D.MappingTypeID + ') = 2 THEN ''_'' + E.Entity ELSE '''' END' END + CASE WHEN D.SortOrder = 4 THEN '' ELSE ',' END,
								@SQLStatement_SubGroupBy = ISNULL(@SQLStatement_SubGroupBy, '') + CASE WHEN D.[GroupByYN] = 0 THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN D.MappingEnabledYN = 0 OR D.MappedLabelYN = 0 THEN CASE WHEN D.MappedLabelYN = 0 AND D.MappingTypeID = 1 THEN 'E.Entity + ''_'' + ' ELSE '' END + CASE WHEN D.[SourceField] <> '''NONE''' AND D.MappedLabelYN = 0 AND D.MappingTypeID IN (1, 2) THEN '(' ELSE '' END + D.SourceField + CASE WHEN D.[SourceField] <> '''NONE''' AND D.MappedLabelYN = 0 AND D.MappingTypeID IN (1, 2) THEN ') COLLATE DATABASE_DEFAULT' ELSE '' END + CASE WHEN D.MappedLabelYN = 0 AND D.MappingTypeID = 2 THEN ' + ''_'' + E.Entity' ELSE '' END ELSE 'CASE WHEN ISNULL([ML_' + D.MappedObjectName + '].MappingTypeID, ' + D.MappingTypeID + ') = 1 THEN E.Entity + ''_'' ELSE '''' END + CASE WHEN [ML_' + D.MappedObjectName + '].MappingTypeID = 3 THEN [ML_' + D.MappedObjectName + '].MappedLabel ELSE (' + D.SourceField + ') COLLATE DATABASE_DEFAULT END + CASE WHEN ISNULL([ML_' + D.MappedObjectName + '].MappingTypeID, ' + D.MappingTypeID + ') = 2 THEN ''_'' + E.Entity ELSE '''' END' END + ',' END,
								@SQLStatement_MapJoin = ISNULL(@SQLStatement_MapJoin, '') + CASE WHEN D.MappingEnabledYN = 0 OR D.MappedLabelYN = 0 OR D.[SourceField] = '''NONE''' THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LEFT JOIN MappedLabel [ML_' + D.MappedObjectName + '] ON [ML_' + D.MappedObjectName + '].Entity = E.Entity AND [ML_' + D.MappedObjectName + '].MappedObjectName = ''' + D.MappedObjectName + ''' AND CONVERT(nvarchar, ' + D.SourceField + ') COLLATE DATABASE_DEFAULT BETWEEN [ML_' + D.MappedObjectName + '].LabelFrom AND [ML_' + D.MappedObjectName + '].LabelTo AND [ML_' + D.MappedObjectName + '].SelectYN <> 0' END,
								@SQLStatement_SubHaving = ISNULL(@SQLStatement_SubHaving, '') + CASE WHEN D.SortOrder = 4 THEN D.SourceField ELSE '' END
							FROM
								#SubSelect D
							ORDER BY
								D.[SortOrder],
								D.[MappedObjectName]
							
							SET @SQLStatement_SubGroupBy = LEFT(@SQLStatement_SubGroupBy, LEN(@SQLStatement_SubGroupBy) - 1)

							SELECT
								@SQLStatement_SubFrom = ISNULL(@SQLStatement_SubFrom, '') + CASE WHEN SSMF.DimensionID = 100 THEN SSMF.SourceString ELSE '' END,
								@SQLStatement_SubWhere = ISNULL(@SQLStatement_SubWhere, '') + CASE WHEN SSMF.DimensionID = 200 THEN SSMF.SourceString ELSE '' END,
								@SequenceDescription = ISNULL(@SequenceDescription, '') + CASE WHEN SSMF.DimensionID = 500 THEN SSMF.SourceString ELSE '' END
							FROM
								pcINTEGRATOR.dbo.SqlSource_Model_FACT SSMF
							WHERE
								SSMF.SequenceBM & @SequenceBMStep > 0 AND
								SSMF.DimensionID IN (100, 200, 500) AND 
								SSMF.SourceTypeBM & @SourceTypeBM > 0 AND
								SSMF.RevisionBM & @RevisionBM > 0 AND
								SSMF.ModelBM & @ModelBM > 0 AND
								SSMF.LinkedBM & @LinkedBM > 0 AND
								SSMF.SelectYN <> 0

							IF @SQLStatement_SubWhere = '' SET @SQLStatement_SubWhere = CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '1 = 1'

							SET @SQLStatement = ISNULL(@SQLStatement, '') + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 
							'--@SequenceCounter = ' + CONVERT(nvarchar(10), @SequenceCounter) + ', @SequenceBMStep = ' + CONVERT(nvarchar(10), @SequenceBMStep)	+ CHAR(13) + CHAR(10) +
							'--' + @SequenceDescription +
							CASE WHEN @SequenceCounter = 1 THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 'UNION ' END + '
			SELECT'
				+ @SQLStatement_SubSelect + '
			FROM
'				+ @SQLStatement_SubFrom +
				+ @SQLStatement_MapJoin + '
			WHERE
'				+ @SQLStatement_SubWhere + '
			GROUP BY '
				+ @SQLStatement_SubGroupBy + '
			HAVING
				' + @SQLStatement_SubHaving + ' <> 0'

						IF @Debug <> 0 PRINT @SQLStatement

						SELECT
							@SQLStatement_SubSelect = NULL,
							@SQLStatement_SubFrom = NULL,
							@SQLStatement_MapJoin = NULL,
							@SQLStatement_SubWhere = NULL,
							@SQLStatement_SubGroupBy = NULL,
							@SQLStatement_SubHaving = NULL,
							@SequenceDescription = NULL

						SELECT @SequenceCounter = @SequenceCounter + 1
						SELECT @SequenceBMStep = @SequenceBMStep + @SequenceBMStep
					END --End of Sequence loop

					DROP TABLE #SubSelect

				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Sub part of View Raw', [SQLStatement] = @SQLStatement

------------------------------------------------------------------
			SET @Step = 'CREATE SQL for FACT view raw'
				IF @Debug <> 0 SELECT SQLStatement_Select = @SQLStatement_Select, SQLStatement = @SQLStatement, SQLStatement_Where = @SQLStatement_Where

				SET @SQLStatement = '
	SELECT' + @SQLStatement_Select + '
	FROM
		(' + @SQLStatement + '
		) sub
	WHERE
' + @SQLStatement_Where

			SET @Step = 'Replace variables'

				IF @Debug <> 0 SELECT SourceDatabase = @SourceDatabase, ETLDatabase_Linked = @ETLDatabase_Linked, DestinationDatabase = @DestinationDatabase, BusinessProcess = @BusinessProcess, BusinessRule = @BusinessRule, StartYear = @StartYearString, SourceID = @SourceID, [Owner] = @Owner

				EXEC pcINTEGRATOR..spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT
				SET @SQLStatement = REPLACE(@SQLStatement, '@SourceDatabase', ISNULL(@SourceDatabase, ''))
				SET @SQLStatement = REPLACE(@SQLStatement, '@ETLDatabase_Linked', ISNULL(@ETLDatabase_Linked, @ETLDatabase))
				SET @SQLStatement = REPLACE(@SQLStatement, '@DestinationDatabase', ISNULL(@DestinationDatabase, ''))
				SET @SQLStatement = REPLACE(@SQLStatement, '@BusinessProcess', ISNULL(@BusinessProcess, ''))
				SET @SQLStatement = REPLACE(@SQLStatement, '@BusinessRule', ISNULL(@BusinessRule, ''))
				SET @SQLStatement = REPLACE(@SQLStatement, '@StartYear', ISNULL(@StartYearString, ''))
				SET @SQLStatement = REPLACE(@SQLStatement, '@SourceID', @SourceID)
				SET @SQLStatement = REPLACE(@SQLStatement, '@Owner', ISNULL(@Owner, ''))
				SET @SQLStatement = REPLACE(@SQLStatement, '''', '''''')
				SET @SQLStatement = REPLACE(@SQLStatement, 'COLLATE DATABASE_DEFAULT COLLATE DATABASE_DEFAULT', 'COLLATE DATABASE_DEFAULT')

				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'FACT View Raw', [SQLStatement] = @SQLStatement

			SET @Step = 'CREATE SQL for FACT view raw'

				SET @ObjectName = 'vw_' + @SourceID_varchar + '_FACT_' + @ModelName + '_Raw'

				SET @SQLStatement_Action = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ObjectName + '''' + ', ' + '''V''' 
				INSERT INTO #Action ([Action]) EXEC (@SQLStatement_Action)
				SELECT @Action = [Action] FROM #Action
				TRUNCATE TABLE #Action

				SET @SQLStatement = @Action + ' VIEW [dbo].[' + @ObjectName + '] 

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS
' + @SQLStatement

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				EXEC (@SQLStatement)

--------------------------------------------------
		IF @ModelBM <> 4 --Not FxRate
			BEGIN
				IF @Debug <> 0 SELECT Step = 'CREATE FACT View with MemberId'
				SET @Step = 'CREATE FACT View with MemberId'

					SET @SQLStatement = '
	SELECT' + @SQLStatement_SelectID + '
	FROM
		[' + @ObjectName + '] [Raw]'
					SET @SQLStatement = @SQLStatement + @SQLStatement_DimJoin

					SET @ObjectName = 'vw_' + @SourceID_varchar + '_FACT_' + @ModelName

					SET @SQLStatement_Action = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ObjectName + '''' + ', ' + '''V''' 
					INSERT INTO #Action ([Action]) EXEC (@SQLStatement_Action)
					SELECT @Action = [Action] FROM #Action
					TRUNCATE TABLE #Action

					SET @SQLStatement = @Action + ' VIEW [dbo].[' + @ObjectName + '] 

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '

AS ' + @SQLStatement
					SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

					EXEC spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT

					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of View with MemberId', [SQLStatement] = @SQLStatement

					EXEC (@SQLStatement)
			END

-------------------------------------------
	IF @Debug <> 0 SELECT Step = 'CREATE PROCEDURE (Single)'
	SET @Step = 'CREATE PROCEDURE (Single)'
		SET @ProcedureName = 'spIU_' + @SourceID_varchar + '_FACT_' + @ModelName
		SET @TempTableName = '#' + @SourceID_varchar + '_FACT_' + @ModelName

		SET @SQLStatement = '

	@JobID int = 0,
	@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
	@SpeedRunYN bit = 0,
	@Entity_MemberId bigint = -10,
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
	@ErrorNumber int'

	+ CASE WHEN @ModelBM = 4 THEN ',' + CHAR(13) + CHAR(10) + CHAR(9) + '@Month int,' + CHAR(13) + CHAR(10) + CHAR(9) + '@Entity nvarchar(50),' + CHAR(13) + CHAR(10) + CHAR(9) + '@MasterEntity nvarchar(50),' + CHAR(13) + CHAR(10) + CHAR(9) + '@SQLStatement nvarchar(max)' ELSE '' END + ',
	@LinkedYN bit,
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
	SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()
		SET DATEFIRST 1

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)
'

		IF @ModelBM <> 4 --Not FxRate
			BEGIN
				SET @SQLStatement_SourceString = '
	SET @Step = ''''Handle ANSI_WARNINGS''''
		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = ''''Insert into temp table''''
		SELECT * INTO [' + @TempTableName + '] FROM ' + @ETLDatabase + '.[dbo].[' + @ObjectName + '] WHERE @Entity_MemberId = -10 OR Entity_MemberId = @Entity_MemberId

		SET ANSI_WARNINGS OFF'

			END

		ELSE --FxRate
			BEGIN
				SET @SQLStatement_SourceString = '
    SET @Step = ''''Create a temp table''''
		CREATE TABLE [' + @TempTableName + ']
			(' + @SQLStatement_CreateTable + '
			[' + @ModelName + '_Value] float
			)'
				EXEC spCreate_Fact_FxRate @ApplicationID = @ApplicationID, @SourceID_varchar = @SourceID_varchar, @TempTableName = @TempTableName, @ModelName = @ModelName, @DestinationDatabase = @DestinationDatabase, @SourceTypeFamilyID = @SourceTypeFamilyID, @SQLStatement_SelectID = @SQLStatement_SelectID, @SQLStatement_DimJoin = @SQLStatement_DimJoin, @StartYear = @StartYear, @SQLStatement = @SQLStatement_FxRate OUT, @Debug = @Debug
				SET @SQLStatement_SourceString = @SQLStatement_SourceString + @SQLStatement_FxRate
			END

	IF @Debug <> 0 SELECT SQLStatement_SourceString = @SQLStatement_SourceString

	SET @SQLStatement = @SQLStatement + @SQLStatement_SourceString + '

	SET @Step = ''''Create #FACT_Update''''
		SELECT DISTINCT
			' + @SQLStatement_Delete + '
		INTO
			#FACT_Update
		FROM
			[' + @TempTableName + ']

	SET @Step = ''''Set all existing rows that should be inserted to 0''''
		UPDATE
			F
		SET
			[' + @ModelName + '_Value] = 0
		FROM
			[' + @DestinationDatabase + '].[dbo].[FACT_' + @ModelName + '_default_partition] F' + ISNULL(@SQLStatement_FACT_DeleteJoin, '') + '
			INNER JOIN [#FACT_Update] V ON
							' + @SQLStatement_DeleteJoin + '

		SET @Updated = @Updated + @@ROWCOUNT'

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Insert new rows''''
		INSERT INTO [' + @DestinationDatabase + '].[dbo].[FACT_' + @ModelName + '_default_partition]
							(' + @SQLStatement_InsertInto + '
							[ChangeDatetime],
							[Userid],
							[' + @ModelName + '_Value]
							)
		SELECT' + @SQLStatement_InsertInto + '
							[ChangeDatetime] = GetDate(),
							[Userid] = suser_name(),
							[' + @ModelName + '_Value]
		FROM
							[' + @TempTableName + ']
		
		SET @Inserted = @Inserted + @@ROWCOUNT'

	IF @BaseModelID <> -3
/*
		SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Add Currency conversion''''
		IF (SELECT COUNT(1) FROM [' + @DestinationDatabase + '].[dbo].[S_DS_' + @FCurrency + '] WHERE [Reporting] <> 0) > 0
			EXEC spIU_0000_FACT_FxTrans @JobID = @JobID, @ModelName = ''''' + @ModelName + ''''', @BPType = ''''ETL'''', @Debug = @Debug'
*/
		SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Run selected BusinessRules''''
		EXEC spRun_BR_All @JobID = @JobID, @Model = ''''' + @ModelName + ''''', @Debug = @Debug'

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Clean up''''
		IF (SELECT DATEPART(WEEKDAY, GETDATE())) IN (6, 7) OR @SpeedRunYN = 0 --Saturday, Sunday or not SpeedRun
			BEGIN
				DELETE
					f
				FROM
					[' + @DestinationDatabase + '].[dbo].[FACT_' + @ModelName + '_default_partition] F
				WHERE
					[' + @ModelName + '_Value] = 0

				SET @Deleted = @Deleted + @@ROWCOUNT
			END'

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Drop the temp table''''
		DROP TABLE [' + @TempTableName + ']
		DROP TABLE #FACT_Update

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
				SELECT
					SQLStatement = @SQLStatement,
					[Version] = @Version,
					SQLStatement_SourceString = @SQLStatement_SourceString,
					ModelName = @ModelName,
					DestinationDatabase = @DestinationDatabase,
					ModelName = @ModelName,
					SQLStatement_FACT_DeleteJoin = @SQLStatement_FACT_DeleteJoin,
					SQLStatement_Delete = @SQLStatement_Delete,
					ObjectName = @ObjectName,
					TempTableName = @TempTableName,
					SQLStatement_DeleteJoin = @SQLStatement_DeleteJoin,
					DestinationDatabase = @DestinationDatabase,
					SQLStatement_InsertInto = @SQLStatement_InsertInto

			SET @SQLStatement_Action = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ProcedureName + '''' + ', ' + '''P''' 
			INSERT INTO #Action ([Action]) EXEC (@SQLStatement_Action)
			SELECT @Action = [Action] FROM #Action

			SET @SQLStatement = @Action + ' PROCEDURE [dbo].[' + @ProcedureName + ']' + @SQLStatement

				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				IF @Debug <> 0 SELECT ApplicationID = @ApplicationID, TranslatedLanguageID = @LanguageID, StringIn = @SQLStatement, StringOut = @SQLStatement
				EXEC spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT, @Debug = @Debug

				IF @Debug <> 0 SELECT ApplicationID = @ApplicationID, TranslatedLanguageID = @LanguageID, StringIn = @SQLStatement, StringOut = @SQLStatement

				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of Procedure', [SQLStatement] = @SQLStatement

				EXEC (@SQLStatement)

			END  --END of @SourceDBTypeID = 1 --Single DB

------------------------------------------------------

		ELSE IF @SourceDBTypeID = 2 --Multiple DB
			BEGIN
				IF @Debug <> 0 SELECT Step = 'CREATE FACT procedure raw (Multiple)'
				SET @Step = 'CREATE FACT procedure raw (Multiple)'
					SET @ProcedureName = 'spIU_' + @SourceID_varchar + '_FACT_' + @ModelName + '_Raw'
					SET @ObjectName = @SourceID_varchar + '_FACT_' + @ModelName + '_Raw'
					SET @TempTableName = '#' + @SourceID_varchar + '_FACT_' + @ModelName

					SET @SQLStatement = '

	@JobID int = 0,
	@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
	@ModelBM int = ' + CONVERT(nvarchar, @ModelBM) + ',
	@EntityCode nvarchar(50),
	@StartYear int = ' + @StartYearString + ',
	@Rows int = NULL,
	@CalledYN bit = 0, --0 = For test purposes, 1 = Called by a parent procedure taking care of the data
	@GetVersion bit = 0,
	@Debug bit = 0

' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
--EXEC [' + @ProcedureName + '] @EntityCode = ''''XX'''', @Debug = 1

AS

SET ANSI_WARNINGS OFF

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,
	@SQLStatement nvarchar(max),
	@SQLStatement_Cursor nvarchar(max),
	@Currency nchar(3),
	@ModelName nvarchar(100),
	@SourceDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@ETLDatabase_Linked nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@BusinessProcess nvarchar(255),
	@BusinessRule nvarchar(50),
	@CreateTable nvarchar(2000),
	@InsertInto nvarchar(2000),
	@Select nvarchar(2000),
	@SelectID nvarchar(max),
	@DimJoin nvarchar(max),
	@GroupBy nvarchar(2000),
	@SubSelect nvarchar(4000),
	@SubFrom nvarchar(2000),
	@SubGroupBy nvarchar(2000),
	@SubWhere nvarchar(2000),
	@SubHaving nvarchar(2000),
	@MapJoin nvarchar(2000),
	@FinancialAccount nvarchar(100),
	@FinancialSegment nvarchar(100),
	@Entity nvarchar(100),
	@MasterEntity nvarchar(50),
	@Month int,
	@LinkedYN bit,
	@AccountSegmentNbr nvarchar(10),
	@SourceTypeBM int,
	@SourceTypeName nvarchar(100),
	@SourceTypeFamilyID int,
	@RevisionBM int,
	@LinkedBM int,
	@SequenceBMSum int,
	@SequenceBMStep int,
	@SequenceCounter int,
	@SequenceDescription nvarchar(255),
	@StartYearString nvarchar(10),
	@FiscalYear int,
	@SourceTable_01 nvarchar(100),
	@SourceTable_02 nvarchar(100),
	@SourceTable_03 nvarchar(100),
	@SourceTable_04 nvarchar(100),
	@SourceTable_05 nvarchar(100),
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
			@Entity = Entity,
			@Currency = Currency,
			@SourceDatabase = Par01,
			@StartYearString = CONVERT(nvarchar(10), @StartYear)
		FROM
			Entity
		WHERE
			SourceID = @SourceID AND
			EntityCode = @EntityCode

		SELECT
			@DestinationDatabase = A.DestinationDatabase,
			@ETLDatabase = ''''['''' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, ''''['''', ''''''''), '''']'''', ''''''''), ''''.'''', ''''].['''') + '''']'''',
			@ETLDatabase_Linked = ''''['''' + REPLACE(REPLACE(REPLACE(S.ETLDatabase_Linked, ''''['''', ''''''''), '''']'''', ''''''''), ''''.'''', ''''].['''') + '''']'''',
			@SourceTypeBM = ST.SourceTypeBM,
			@SourceTypeName = ST.SourceTypeName,
			@SourceTypeFamilyID = ST.SourceTypeFamilyID,
			@BusinessProcess = S.BusinessProcess,
			@BusinessRule = ''''NONE'''',
			@ModelName = MO.MappedObjectName
		FROM
			pcINTEGRATOR.dbo.[Application] A
			INNER JOIN pcINTEGRATOR.dbo.[Model] M ON M.ApplicationID = A.ApplicationID
			INNER JOIN pcINTEGRATOR.dbo.[Source] S ON S.SourceID = @SourceID AND S.ModelID = M.ModelID
			INNER JOIN pcINTEGRATOR.dbo.[SourceType] ST ON ST.SourceTypeID  = S.SourceTypeID
			INNER JOIN MappedObject MO ON MO.Entity = ''''-1'''' AND MO.ObjectName = M.ModelName AND ObjectTypeBM & 1 > 0

		EXEC pcINTEGRATOR..[spGet_Revision] @SourceID = @SourceID, @RevisionBM = @RevisionBM OUT
		EXEC pcINTEGRATOR..[spGet_Linked] @SourceID = @SourceID, @LinkedBM = @LinkedBM OUT
		
		IF @Debug <> 0
			SELECT
				SourceID = @SourceID,
				ModelBM = @ModelBM,
				StartYear = @StartYear,
				DestinationDatabase = @DestinationDatabase,
				ETLDatabase = @ETLDatabase,
				ETLDatabase_Linked = @ETLDatabase_Linked,
				SourceTypeBM = @SourceTypeBM,
				SourceTypeName = @SourceTypeName,
				SourceTypeFamilyID = @SourceTypeFamilyID,
				BusinessProcess = @BusinessProcess,
				BusinessRule = @BusinessRule,
				ModelName = @ModelName'

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Handle ANSI_WARNINGS''''
		EXEC pcINTEGRATOR.dbo.spGet_Linked @SourceID = @SourceID, @LinkedYN = @LinkedYN OUT
		IF @LinkedYN <> 0
			SET ANSI_WARNINGS ON

	SET @Step = ''''Create temp table holding all field info''''

		SELECT DISTINCT
			sub.DimensionID,
			sub.DimensionTypeID,
			sub.MappedObjectName,
			sub.SegmentNbr,
			SourceField = CASE WHEN CONVERT(int, sub.ReplaceTextYN) * CONVERT(int, DT.ReplaceTextEnabledYN) <> 0 THEN ''''[dbo].[f_ReplaceText] ('''' + sub.SourceField + '''', 1)'''' ELSE sub.SourceField END,
			sub.SequenceBM,
			sub.LinkedDimension,
			sub.LinkedProperty,
			sub.GroupByYN,
			MappingTypeID = CONVERT(nvarchar(10), ISNULL(sub.MappingTypeID, 0) * CONVERT(int, DT.MappingEnabledYN) * CONVERT(int, sub.MappingEnabledYN)),
			MappingEnabledYN = CONVERT(int, DT.MappingEnabledYN) * CONVERT(int, sub.MappingEnabledYN),
			ReplaceTextYN = CONVERT(int, sub.ReplaceTextYN) * CONVERT(int, DT.ReplaceTextEnabledYN),
			MappedLabelYN = CASE WHEN ML.MappedObjectName IS NULL THEN 0 ELSE 1 END,
			sub.VisibilityLevelBM,
			sub.SortOrder
		INTO
			#DimensionList
		FROM
			(' +
		CASE WHEN @OptFinanceDimYN <> 0 THEN '
			--Account & GLSegment
			SELECT 
				DimensionID = CASE MOA.DimensionTypeID WHEN 1 THEN -1 ELSE 0 END,
				MOA.DimensionTypeID,
				MOA.MappedObjectName,
				SegmentNbr = MAX(FS.SegmentNbr),' +
			CASE @SourceTypeFamilyID 
			WHEN 2 THEN '
				SourceField = MAX(CASE WHEN FS.SegmentCode IS NULL THEN ''''''''''''NONE'''''''''''' ELSE ''''SUBSTRING(@FinancialSegment, '''' + CONVERT(nvarchar(10), FS.Start) + '''', '''' + CONVERT(nvarchar(10), FS.[Length]) + '''') COLLATE DATABASE_DEFAULT'''' END),'
			WHEN 3 THEN '
				SourceField = MAX(CASE WHEN FS.SegmentCode IS NULL THEN ''''''''''''NONE'''''''''''' ELSE ''''F.'''' + FS.SegmentCode + '''' COLLATE DATABASE_DEFAULT'''' END),'
			ELSE '
				SourceField = '''''''''''''''''''''''','
			END + '
				SequenceBM = 63,
				LinkedDimension = NULL,
				LinkedProperty = NULL,
				GroupByYN = MAX(CASE WHEN FS.SegmentNbr IS NULL THEN 0 ELSE 1 END),
				MappingTypeID = MAX(MO.MappingTypeID),
				MappingEnabledYN = 1,
				ReplaceTextYN = MAX(ISNULL(CONVERT(int, MO.ReplaceTextYN), 0)),
				VisibilityLevelBM = 8,
				SortOrder = MAX(CASE WHEN MOA.DimensionTypeID = -1 THEN 3 ELSE 1 END)
			FROM' +
			CASE @FinanceAccountYN 
			WHEN 0 THEN '
				(SELECT DISTINCT DimensionTypeID, MappedObjectName, ObjectName FROM MappedObject WHERE (Entity <> ''''-1'''' AND SelectYN <> 0) AND ModelBM & ' + CONVERT(nvarchar(10), @ModelBM) + ' > 0 AND ObjectTypeBM & 2 > 0) MOA'
			ELSE '
				(SELECT DISTINCT DimensionTypeID, MappedObjectName, ObjectName FROM MappedObject WHERE (DimensionTypeID = 1 OR (Entity <> ''''-1'''' AND SelectYN <> 0)) AND ModelBM & ' + CONVERT(nvarchar(10), @ModelBM) + ' > 0 AND ObjectTypeBM & 2 > 0) MOA'
			END + '
				INNER JOIN Entity E ON E.SourceID  = ' + CONVERT(nvarchar(10), @SourceID) + ' AND E.EntityCode = @EntityCode
				LEFT JOIN [FinancialSegment] FS ON FS.SourceID = E.SourceID AND FS.EntityCode = E.EntityCode AND FS.DimensionTypeID = MOA.DimensionTypeID AND (FS.SegmentName = MOA.ObjectName OR FS.DimensionTypeID = 1)
				LEFT JOIN MappedObject MO ON (MO.Entity = E.Entity AND MO.ObjectName = MOA.ObjectName) OR (MO.Entity = ''''-1'''' AND MO.DimensionTypeID = MOA.DimensionTypeID AND MO.ObjectName = MOA.ObjectName)
			GROUP BY
				MOA.DimensionTypeID,
				MOA.MappedObjectName'
				ELSE '' END +

'
			--Other dimensions
			' + CASE WHEN @OptFinanceDimYN <> 0 THEN 'UNION' ELSE '' END + ' SELECT DISTINCT
				D.DimensionID,
				MO.DimensionTypeID,
				MO.MappedObjectName,
				SegmentNbr = NULL,
				SourceField = ISNULL(SSMF.SourceString, ''''''''''''NONE''''''''''''),
				SequenceBM = ISNULL(SSMF.SequenceBM, 63),
				LinkedDimension = MOLD.MappedObjectName,
				LinkedProperty = MOLP.MappedObjectName,
				GroupByYN = ISNULL(SSMF.GroupByYN, 0),
				MO.MappingTypeID,
				MD.MappingEnabledYN,
				ReplaceTextYN = CONVERT(int, MO.ReplaceTextYN) * CONVERT(int, ISNULL(SSMF.ReplaceTextYN, 0)),
				VisibilityLevelBM = MD.VisibilityLevelBM + CASE WHEN MO.SelectYN <> 0 AND MO.ModelBM & ' + CONVERT(nvarchar, @ModelBM) + ' > 0 AND MD.[VisibilityLevelBM] & 8 <= 0 THEN 8 ELSE 0 END,
				SortOrder = 2
			FROM
				MappedObject MO
				INNER JOIN pcINTEGRATOR.dbo.Model M ON M.ModelBM = @ModelBM
				INNER JOIN pcINTEGRATOR.dbo.Dimension D ON D.DimensionName = MO.ObjectName AND D.SelectYN <> 0
				INNER JOIN pcINTEGRATOR.dbo.Model_Dimension MD ON MD.ModelID = M.ModelID AND MD.DimensionID = D.DimensionID
				LEFT JOIN pcINTEGRATOR.dbo.SqlSource_Model_FACT SSMF ON SSMF.DimensionID = D.DimensionID AND SSMF.SourceTypeBM & @SourceTypeBM > 0 AND SSMF.RevisionBM & @RevisionBM > 0 AND SSMF.ModelBM & @ModelBM > 0 AND SSMF.LinkedBM & @LinkedBM > 0 AND SSMF.SelectYN <> 0
				LEFT JOIN pcINTEGRATOR.dbo.Property LP ON LP.PropertyID = MD.LinkedPropertyID AND LP.Introduced < @Version AND LP.SelectYN <> 0
				LEFT JOIN MappedObject MOLP ON MOLP.Entity = ''''-1'''' AND MOLP.DimensionTypeID NOT IN (-1) AND MOLP.ObjectName = LP.PropertyName AND MOLP.ObjectTypeBM & 4 > 0 AND MOLP.SelectYN <> 0
				LEFT JOIN pcINTEGRATOR.dbo.Dimension LD ON LD.DimensionID = LP.DimensionID AND LD.Introduced < @Version AND LD.SelectYN <> 0
				LEFT JOIN MappedObject MOLD ON MOLD.Entity = ''''-1'''' AND MOLD.DimensionTypeID NOT IN (-1) AND MOLD.ObjectName = LD.DimensionName AND MOLD.ObjectTypeBM & 2 > 0 AND MOLD.SelectYN <> 0
			WHERE
				MO.Entity = ''''-1'''' AND
				MO.DimensionTypeID NOT IN (-1' + CASE WHEN @FinanceAccountYN <> 0 THEN ', 1' ELSE '' END + ') AND
				(MO.ModelBM & @ModelBM > 0 OR MD.[VisibilityLevelBM] & 14 > 0) AND
				MO.ObjectTypeBM & 2 > 0 AND
				(MO.SelectYN <> 0 OR MD.[VisibilityLevelBM] & 14 > 0)'

	SET @SQLStatement = @SQLStatement + '

			--Not visible dimensions existing in SqlSource_Model_FACT
			UNION SELECT DISTINCT
				D.DimensionID,
				D.DimensionTypeID,
				MappedObjectName = D.DimensionName,
				SegmentNbr = NULL,
				SourceField = SSMF.SourceString,
				SequenceBM = SSMF.SequenceBM,
				LinkedDimension = NULL,
				LinkedProperty = NULL,
				GroupByYN = SSMF.GroupByYN,
				MappingTypeID = 0,
				MappingEnabledYN = 0,
				ReplaceTextYN = 0,
				MD.VisibilityLevelBM,
				SortOrder = 2
			FROM
				pcINTEGRATOR.dbo.SqlSource_Model_FACT SSMF
				INNER JOIN pcINTEGRATOR.dbo.Model M ON M.ModelBM = @ModelBM
				INNER JOIN pcINTEGRATOR.dbo.Dimension D ON D.DimensionID <> 0 AND D.DimensionID = SSMF.DimensionID AND D.SelectYN <> 0
				INNER JOIN pcINTEGRATOR.dbo.Model_Dimension MD ON MD.ModelID = M.ModelID AND MD.DimensionID = D.DimensionID AND MD.[VisibilityLevelBM] & 8 <= 0
			WHERE
				SSMF.SourceTypeBM & @SourceTypeBM > 0 AND 
				SSMF.RevisionBM & @RevisionBM > 0 AND 
				SSMF.ModelBM & @ModelBM > 0 AND 
				SSMF.LinkedBM & @LinkedBM > 0 AND
				SSMF.SelectYN <> 0 AND
				NOT EXISTS (SELECT 1 FROM MappedObject MO WHERE MO.ObjectName = D.DimensionName AND MO.ObjectTypeBM & 2 > 0)

			--Measure & FinancialSegment
			UNION SELECT DISTINCT
				DimensionID = SSMF.DimensionID,
				DimensionTypeID = CASE SSMF.DimensionID WHEN 0 THEN -1 ELSE 0 END,
				MappedObjectName = CASE SSMF.DimensionID WHEN 0 THEN ''''@FinancialSegment'''' ELSE @ModelName + ''''_Value'''' END,
				SegmentNbr = NULL,
				SourceField = SSMF.SourceString,
				SequenceBM = SSMF.SequenceBM,
				LinkedDimension = NULL,
				LinkedProperty = NULL,
				GroupByYN = SSMF.GroupByYN,
				MappingTypeID = 0,
				MappingEnabledYN = 0,
				ReplaceTextYN = 0,
				VisibilityLevelBM = CASE SSMF.DimensionID WHEN 0 THEN 0 ELSE 8 END,
				SortOrder = 4
			FROM
				pcINTEGRATOR.dbo.SqlSource_Model_FACT SSMF
			WHERE
				SSMF.DimensionID IN (0, 10) AND
				SSMF.SourceTypeBM & @SourceTypeBM > 0 AND
				SSMF.RevisionBM & @RevisionBM > 0 AND
				SSMF.ModelBM & @ModelBM > 0 AND
				SSMF.LinkedBM & @LinkedBM > 0 AND
				SSMF.SelectYN <> 0
			) sub
			INNER JOIN pcINTEGRATOR.dbo.DimensionType DT ON DT.DimensionTypeID = sub.DimensionTypeID
			LEFT JOIN (SELECT DISTINCT MappedObjectName FROM [MappedLabel] WHERE SelectYN <> 0) ML ON ML.MappedObjectName = sub.MappedObjectName
		ORDER BY
			sub.SortOrder,
			sub.[MappedObjectName]

		IF @Debug <> 0 SELECT TempTable = ''''#DimensionList'''', * FROM #DimensionList ORDER BY SortOrder, [MappedObjectName], SequenceBM'

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create SQL variables on top level''''

		SELECT
			DimensionID = MAX(D.DimensionID),
			MappedObjectName = D.MappedObjectName,
			SourceField = CASE WHEN MAX(D.LinkedDimension) IS NOT NULL THEN '''''''' ELSE MAX(ISNULL(D1.SourceField, ''''[sub].['''' + D.MappedObjectName + '''']'''')) END,
			SourceFieldID = MAX(CASE WHEN D.SortOrder = 4 THEN ''''['''' + D.MappedObjectName + '''']'''' ELSE ''''['''' + D.MappedObjectName + ''''_MemberId] = ISNULL(['''' + ISNULL(D.LinkedDimension, D.MappedObjectName) + ''''].['''' + CASE WHEN D.LinkedProperty IS NULL THEN '''''''' ELSE D.LinkedProperty + ''''_'''' END + ''''MemberId], -1),'''' END),
			SubLevelYN = CASE WHEN MAX(D.SourceField) IS NULL THEN 0 ELSE 1 END,
			VisibilityLevelBM = MAX(D.VisibilityLevelBM),
			SortOrder = MAX(D.SortOrder)
		INTO
			#FieldList
		FROM
			#DimensionList D
			LEFT JOIN #DimensionList D1 ON D1.MappedObjectName = D.MappedObjectName AND D1.SequenceBM = 0
		WHERE
			D.VisibilityLevelBM > 0
		GROUP BY
			D.MappedObjectName

		IF @Debug <> 0 SELECT TempTable = ''''#FieldList'''', * FROM #FieldList ORDER BY SortOrder, [MappedObjectName]

		SELECT 
			@CreateTable = ISNULL(@CreateTable, '''''''') + CASE WHEN SourceField = '''''''' THEN '''''''' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ''''['''' + MappedObjectName + '''']'''' + CASE WHEN SortOrder = 4 THEN '''' float'''' ELSE '''' nvarchar(255),'''' END END,
			@InsertInto = ISNULL(@InsertInto, '''''''') + CASE WHEN SourceField = '''''''' THEN '''''''' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ''''['''' + MappedObjectName + '''']'''' + CASE WHEN SortOrder = 4 THEN '''''''' ELSE '''','''' END END,
			@Select = ISNULL(@Select, '''''''') + CASE WHEN SubLevelYN = 0 OR SourceField = '''''''' THEN '''''''' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ''''['''' + MappedObjectName + ''''] = '''' + SourceField + CASE WHEN SortOrder = 4 THEN '''''''' ELSE '''','''' END END,
			@SelectID = ISNULL(@SelectID, '''''''') + CASE WHEN VisibilityLevelBM & 12 > 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + SourceFieldID ELSE '''''''' END,
			@DimJoin = ISNULL(@DimJoin, '''''''') + CASE WHEN VisibilityLevelBM & 12 > 0 THEN CASE WHEN SortOrder = 4 OR SourceField = '''''''' THEN '''''''' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + ''''LEFT JOIN ['''' + @DestinationDatabase + ''''].[dbo].[S_DS_'''' + MappedObjectName + ''''] ['''' + MappedObjectName + ''''] ON ['''' + MappedObjectName + ''''].Label COLLATE DATABASE_DEFAULT = [Raw].['''' + MappedObjectName + '''']'''' END ELSE '''''''' END
		FROM
			#FieldList
		ORDER BY
			[SortOrder],
			[MappedObjectName]
			
		SELECT @FinancialAccount = SourceField FROM #DimensionList WHERE DimensionID = -1 AND DimensionTypeID = 1'

	SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create TABLE tmp_Model_Raw''''
		IF (SELECT COUNT(1) FROM sys.tables st WHERE [type] = ''''U'''' AND name = ''''tmp_Model_Raw'''') > 0
			DROP TABLE tmp_Model_Raw

		SET @SQLStatement = ''''
			CREATE TABLE tmp_Model_Raw
			(
			'''' + @CreateTable + ''''
			)''''

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Create temp table'''', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)

	SET @Step = ''''Create SQL variables on sub level''''
		SET @SQLStatement = NULL

		' + CASE WHEN @OptFinanceDimYN <> 0 THEN 'SELECT
			@AccountSegmentNbr = CONVERT(nvarchar(10), SegmentNbr)
		FROM
			#DimensionList
		WHERE
			DimensionTypeID = 1' ELSE '' END + '

		SELECT
			@SequenceBMSum = SUM(SequenceBM)
		FROM
			pcINTEGRATOR.dbo.SqlSource_Model_FACT SSMF
		WHERE
			SSMF.DimensionID = 100 AND 
			SSMF.SourceTypeBM & @SourceTypeBM > 0 AND
			SSMF.RevisionBM & @RevisionBM > 0 AND
			SSMF.ModelBM & @ModelBM > 0 AND
			SSMF.LinkedBM & @LinkedBM > 0 AND
			SSMF.SelectYN <> 0'

	SET @SQLStatement = @SQLStatement + '

		SET @SequenceCounter = 1
		SET @SequenceBMStep = 1
		WHILE @SequenceBMSum & @SequenceBMStep > 0
			BEGIN
				' + CASE WHEN @OptFinanceDimYN <> 0 THEN '
				SELECT
					@FinancialSegment = SourceField
				FROM
					#DimensionList D
				WHERE
					D.SequenceBM & @SequenceBMStep > 0 AND
					D.DimensionID = 0 AND 
					D.DimensionTypeID = -1 AND 
					D.VisibilityLevelBM = 0' ELSE '' END + '

				SELECT 
					@SubSelect = ISNULL(@SubSelect, '''''''') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ''''['''' +  D.MappedObjectName + ''''] = '''' + CASE WHEN D.MappingEnabledYN = 0 OR D.MappedLabelYN = 0 OR D.[SourceField] = ''''''''''''NONE'''''''''''' THEN CASE WHEN D.MappedLabelYN = 0 AND D.MappingTypeID = 1 THEN ''''E.Entity + ''''''''_'''''''' + '''' ELSE '''''''' END + CASE WHEN D.[SourceField] <> ''''''''''''NONE'''''''''''' AND D.MappedLabelYN = 0 AND D.MappingTypeID IN (1, 2) THEN ''''('''' ELSE '''''''' END + D.SourceField + CASE WHEN D.[SourceField] <> ''''''''''''NONE'''''''''''' AND D.MappedLabelYN = 0 AND D.MappingTypeID IN (1, 2) THEN '''') COLLATE DATABASE_DEFAULT'''' ELSE '''''''' END + CASE WHEN D.MappedLabelYN = 0 AND D.MappingTypeID = 2 THEN '''' + ''''''''_'''''''' + E.Entity'''' ELSE '''''''' END ELSE ''''CASE WHEN ISNULL([ML_'''' + D.MappedObjectName + ''''].MappingTypeID, '''' + D.MappingTypeID + '''') = 1 THEN E.Entity + ''''''''_'''''''' ELSE '''''''''''''''' END + CASE WHEN [ML_'''' + D.MappedObjectName + ''''].MappingTypeID = 3 THEN [ML_'''' + D.MappedObjectName + ''''].MappedLabel ELSE ('''' + D.SourceField + '''') COLLATE DATABASE_DEFAULT END + CASE WHEN ISNULL([ML_'''' + D.MappedObjectName + ''''].MappingTypeID, '''' + D.MappingTypeID + '''') = 2 THEN ''''''''_'''''''' + E.Entity ELSE '''''''''''''''' END'''' END + CASE WHEN D.SortOrder = 4 THEN '''''''' ELSE '''','''' END,
					@SubGroupBy = ISNULL(@SubGroupBy, '''''''') + CASE WHEN D.[GroupByYN] = 0 THEN '''''''' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN D.MappingEnabledYN = 0 OR D.MappedLabelYN = 0 THEN CASE WHEN D.MappedLabelYN = 0 AND D.MappingTypeID = 1 THEN ''''E.Entity + ''''''''_'''''''' + '''' ELSE '''''''' END + CASE WHEN D.[SourceField] <> ''''''''''''NONE'''''''''''' AND D.MappedLabelYN = 0 AND D.MappingTypeID IN (1, 2) THEN ''''('''' ELSE '''''''' END + D.SourceField + CASE WHEN D.[SourceField] <> ''''''''''''NONE'''''''''''' AND D.MappedLabelYN = 0 AND D.MappingTypeID IN (1, 2) THEN '''') COLLATE DATABASE_DEFAULT'''' ELSE '''''''' END + CASE WHEN D.MappedLabelYN = 0 AND D.MappingTypeID = 2 THEN '''' + ''''''''_'''''''' + E.Entity'''' ELSE '''''''' END ELSE ''''CASE WHEN ISNULL([ML_'''' + D.MappedObjectName + ''''].MappingTypeID, '''' + D.MappingTypeID + '''') = 1 THEN E.Entity + ''''''''_'''''''' ELSE '''''''''''''''' END + CASE WHEN [ML_'''' + D.MappedObjectName + ''''].MappingTypeID = 3 THEN [ML_'''' + D.MappedObjectName + ''''].MappedLabel ELSE ('''' + D.SourceField + '''') COLLATE DATABASE_DEFAULT END + CASE WHEN ISNULL([ML_'''' + D.MappedObjectName + ''''].MappingTypeID, '''' + D.MappingTypeID + '''') = 2 THEN ''''''''_'''''''' + E.Entity ELSE '''''''''''''''' END'''' END + '''','''' END,'
	SET @SQLStatement = @SQLStatement + '
					@MapJoin = ISNULL(@MapJoin, '''''''') + CASE WHEN D.MappingEnabledYN = 0 OR D.MappedLabelYN = 0 OR D.[SourceField] = ''''''''''''NONE'''''''''''' THEN '''''''' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + ''''LEFT JOIN MappedLabel [ML_'''' + D.MappedObjectName + ''''] ON [ML_'''' + D.MappedObjectName + ''''].Entity = E.Entity AND [ML_'''' + D.MappedObjectName + ''''].MappedObjectName = '''''''''''' + D.MappedObjectName + '''''''''''' AND CONVERT(nvarchar, '''' + D.SourceField + '''') COLLATE DATABASE_DEFAULT BETWEEN [ML_'''' + D.MappedObjectName + ''''].LabelFrom AND [ML_'''' + D.MappedObjectName + ''''].LabelTo AND [ML_'''' + D.MappedObjectName + ''''].SelectYN <> 0'''' END,
					@SubHaving = ISNULL(@SubHaving, '''''''') + CASE WHEN D.SortOrder = 4 THEN D.SourceField ELSE '''''''' END
				FROM
					#DimensionList D
				WHERE
					D.SequenceBM & @SequenceBMStep > 0 AND
					D.VisibilityLevelBM > 0 AND
					D.LinkedDimension IS NULL 
				ORDER BY
					D.[SortOrder],
					D.[MappedObjectName]

				' + CASE WHEN @OptFinanceDimYN <> 0 THEN '
				SET @SubSelect = REPLACE(@SubSelect, ''''@FinancialSegment'''', ISNULL(@FinancialSegment, ''''''''))
				SET @SubGroupBy = REPLACE(@SubGroupBy, ''''@FinancialSegment'''', ISNULL(@FinancialSegment, ''''''''))' ELSE '' END + '
				SET @SubGroupBy = LEFT(@SubGroupBy, LEN(@SubGroupBy) - 1)
				SET @FinancialAccount = REPLACE(@FinancialAccount, ''''@FinancialSegment'''', ISNULL(@FinancialSegment, ''''''''))

				SELECT
					@SubFrom = ISNULL(@SubFrom, '''''''') + CASE WHEN SSMF.DimensionID = 100 THEN SSMF.SourceString ELSE '''''''' END,
					@SubWhere = ISNULL(@SubWhere, '''''''') + CASE WHEN SSMF.DimensionID = 200 THEN SSMF.SourceString ELSE '''''''' END,
					@SequenceDescription = ISNULL(@SequenceDescription, '''''''') + CASE WHEN SSMF.DimensionID = 500 THEN SSMF.SourceString ELSE '''''''' END
				FROM
					pcINTEGRATOR.dbo.SqlSource_Model_FACT SSMF
				WHERE
					SSMF.SequenceBM & @SequenceBMStep > 0 AND
					SSMF.DimensionID IN (100, 200, 500) AND 
					SSMF.SourceTypeBM & @SourceTypeBM > 0 AND
					SSMF.RevisionBM & @RevisionBM > 0 AND
					SSMF.ModelBM & @ModelBM > 0 AND
					SSMF.LinkedBM & @LinkedBM > 0 AND
					SSMF.SelectYN <> 0
					
				IF @SubWhere = '''''''' SET @SubWhere = ''''1 = 1'''''

	SET @SQLStatement = @SQLStatement + '

				SET @SQLStatement = ISNULL(@SQLStatement, '''''''') + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 
				''''--@SequenceCounter = '''' + CONVERT(nvarchar(10), @SequenceCounter) + '''', @SequenceBMStep = '''' + CONVERT(nvarchar(10), @SequenceBMStep)	+ CHAR(13) + CHAR(10) +
				''''--'''' + @SequenceDescription +
				CASE WHEN @SequenceCounter = 1 THEN '''''''' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + ''''UNION '''' END + ''''

			SELECT TOP '''' + CONVERT(nvarchar(50), ISNULL(@Rows, 100000000)) 
				+ @SubSelect + ''''
			FROM
''''				+ @SubFrom +
				+ @MapJoin + ''''
			WHERE
''''				+ @SubWhere + ''''
			GROUP BY ''''
				+ @SubGroupBy + ''''
			HAVING
				'''' + @SubHaving + '''' <> 0''''

				SELECT
					@SubSelect = NULL,
					@SubFrom = NULL,
					@MapJoin = NULL,
					@SubWhere = NULL,
					@SubGroupBy = NULL,
					@SubHaving = NULL,
					@SequenceDescription = NULL

				SELECT @SequenceCounter = @SequenceCounter + 1
				SELECT @SequenceBMStep = @SequenceBMStep + @SequenceBMStep
			END --End of Sequence loop

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Sub part of Raw View'''', [SQLStatement] = @SQLStatement

	SET @Step = ''''Create query for filling temp table (tmp_Model_Raw) with raw data''''
		SET @SQLStatement = ''''
	INSERT INTO tmp_Model_Raw
		('''' 
		+ @InsertInto + ''''
		)
	SELECT TOP '''' + CONVERT(nvarchar(50), ISNULL(@Rows, 100000000)) 
		+ @Select + ''''
	FROM
		(
		'''' + @SQLStatement + ''''
		) sub''''

	SET @Step = ''''Replace variables''''
		EXEC pcINTEGRATOR..spReplace_CodeWord @ApplicationID = ' + CONVERT(nvarchar(10), @ApplicationID) + ', @ObjectTypeBM = 7, @TranslatedLanguageID = ' + CONVERT(nvarchar(10), @LanguageID) + ', @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT
		SET @SQLStatement = REPLACE(@SQLStatement, ''''@EntityCode'''', ISNULL(@EntityCode, ''''''''))
		SET @SQLStatement = REPLACE(@SQLStatement, ''''@SourceDatabase'''', ISNULL(@SourceDatabase, ''''''''))
		SET @SQLStatement = REPLACE(@SQLStatement, ''''@ETLDatabase_Linked'''', ISNULL(@ETLDatabase_Linked, @ETLDatabase))
		SET @SQLStatement = REPLACE(@SQLStatement, ''''@BusinessProcess'''', ISNULL(@BusinessProcess, ''''''''))
		SET @SQLStatement = REPLACE(@SQLStatement, ''''@BusinessRule'''', ISNULL(@BusinessRule, ''''''''))
		SET @SQLStatement = REPLACE(@SQLStatement, ''''@StartYear'''', ISNULL(@StartYearString, ''''''''))
		SET @SQLStatement = REPLACE(@SQLStatement, ''''@SourceID'''', @SourceID)
		SET @SQLStatement = REPLACE(@SQLStatement, ''''@SourceTypeName'''', ISNULL(@SourceTypeName, ''''''''))
		SET @SQLStatement = REPLACE(@SQLStatement, ''''@FinancialAccount'''', ISNULL(@FinancialAccount, ''''''''))
		SET @SQLStatement = REPLACE(@SQLStatement, ''''COLLATE DATABASE_DEFAULT COLLATE DATABASE_DEFAULT'''', ''''COLLATE DATABASE_DEFAULT'''')
		' + CASE WHEN @OptFinanceDimYN <> 0 THEN 'SET @SQLStatement = REPLACE(@SQLStatement, ''''@AccountSegmentNbr'''', ISNULL(@AccountSegmentNbr, ''''''''))' ELSE '' END + '
'

	SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''Create FACT table cursor''''
		DECLARE FACT_' + @SourceID_varchar + '_Table_Cursor CURSOR FOR

		SELECT
			FiscalYear,
			SourceTable_01,
			SourceTable_02,
			SourceTable_03,
			SourceTable_04,
			SourceTable_05
		FROM
			(
			SELECT 	
				TableCode_01 = MAX(CASE WHEN ST.LevelBM & 1 > 0 THEN ST.TableCode ELSE '''''''' END),
				TableCode_02 = MAX(CASE WHEN ST.LevelBM & 2 > 0 THEN ST.TableCode ELSE '''''''' END),
				TableCode_03 = MAX(CASE WHEN ST.LevelBM & 4 > 0 THEN ST.TableCode ELSE '''''''' END),
				TableCode_04 = MAX(CASE WHEN ST.LevelBM & 8 > 0 THEN ST.TableCode ELSE '''''''' END),
				TableCode_05 = MAX(CASE WHEN ST.LevelBM & 16 > 0 THEN ST.TableCode ELSE '''''''' END)
			FROM
				[pcINTEGRATOR].[dbo].[SourceTable] ST
			WHERE
				ST.SourceTypeFamilyID = @SourceTypeFamilyID AND
				ST.ModelBM & @ModelBM > 0 AND
				ST.TableTypeBM & 4 > 0
			) sub1
			INNER JOIN 
			(
			SELECT
				FiscalYear,
				TableCode_01 = MAX(CASE WHEN ST.LevelBM & 1 > 0 THEN wST.TableCode ELSE '''''''' END),
				TableCode_02 = MAX(CASE WHEN ST.LevelBM & 2 > 0 THEN wST.TableCode ELSE '''''''' END),
				TableCode_03 = MAX(CASE WHEN ST.LevelBM & 4 > 0 THEN wST.TableCode ELSE '''''''' END),
				TableCode_04 = MAX(CASE WHEN ST.LevelBM & 8 > 0 THEN wST.TableCode ELSE '''''''' END),
				TableCode_05 = MAX(CASE WHEN ST.LevelBM & 16 > 0 THEN wST.TableCode ELSE '''''''' END),
				SourceTable_01 = MAX(CASE WHEN ST.LevelBM & 1 > 0 THEN wST.TableName ELSE '''''''' END),
				SourceTable_02 = MAX(CASE WHEN ST.LevelBM & 2 > 0 THEN wST.TableName ELSE '''''''' END),
				SourceTable_03 = MAX(CASE WHEN ST.LevelBM & 4 > 0 THEN wST.TableName ELSE '''''''' END),
				SourceTable_04 = MAX(CASE WHEN ST.LevelBM & 8 > 0 THEN wST.TableName ELSE '''''''' END),
				SourceTable_05 = MAX(CASE WHEN ST.LevelBM & 16 > 0 THEN wST.TableName ELSE '''''''' END)
			FROM
				[wrk_SourceTable] wST
				INNER JOIN [pcINTEGRATOR].[dbo].[SourceTable] ST ON ST.SourceTypeFamilyID = @SourceTypeFamilyID AND ST.ModelBM & @ModelBM > 0 AND ST.TableCode = wST.TableCode AND ST.TableTypeBM & 4 > 0
			WHERE
				wST.SourceID = @SourceID AND
				wST.EntityCode = @EntityCode AND
				(EXISTS (SELECT 1 FROM ClosedPeriod CP WHERE CP.SourceID = wST.SourceID AND CP.EntityCode = wST.EntityCode AND CP.TimeFiscalYear = wST.FiscalYear AND CP.UpdateYN <> 0) OR wST.FiscalYear IN (0, 2000)) AND
				(wST.FiscalYear >= @StartYear OR wST.FiscalYear IN (0, 2000))
			GROUP BY
				wST.FiscalYear
			) sub2 ON sub2.TableCode_01 = sub1.TableCode_01 AND sub2.TableCode_02 = sub1.TableCode_02 AND sub2.TableCode_03 = sub1.TableCode_03 AND sub2.TableCode_04 = sub1.TableCode_04 AND sub2.TableCode_05 = sub1.TableCode_05
		ORDER BY
			sub2.FiscalYear'

	SET @SQLStatement = @SQLStatement + '

		OPEN FACT_' + @SourceID_varchar + '_Table_Cursor
		FETCH NEXT FROM FACT_' + @SourceID_varchar + '_Table_Cursor INTO @FiscalYear, @SourceTable_01, @SourceTable_02, @SourceTable_03, @SourceTable_04, @SourceTable_05

		WHILE @@FETCH_STATUS = 0
		  BEGIN
				SET @Step = ''''Replace variables''''
					SET @SQLStatement_Cursor = @SQLStatement

					IF @Debug <> 0
						SELECT
							SQLStatement_Len = LEN(@SQLStatement),
							SQLStatement_Cursor_Len = LEN(@SQLStatement_Cursor),
							EntityCode = @EntityCode,
							SourceTable_01 = @SourceTable_01,
							SourceTable_02 = @SourceTable_02,
							SourceTable_03 = @SourceTable_03,
							SourceTable_04 = @SourceTable_04,
							SourceTable_05 = @SourceTable_05,
							SourceDatabase = @SourceDatabase,
							ETLDatabase = @ETLDatabase,
							ETLDatabase_Linked = @ETLDatabase_Linked,
							DestinationDatabase = @DestinationDatabase,
							BusinessProcess = @BusinessProcess,
							BusinessRule = @BusinessRule,
							StartYear = @StartYearString,
							SourceID = @SourceID,
							AccountSegmentNbr = @AccountSegmentNbr

					SET @SQLStatement_Cursor = REPLACE(@SQLStatement_Cursor, ''''@FiscalYear'''', CONVERT(nvarchar(10), @FiscalYear))
					SET @SQLStatement_Cursor = REPLACE(@SQLStatement_Cursor, ''''@SourceTable_01'''', @SourceTable_01)
					SET @SQLStatement_Cursor = REPLACE(@SQLStatement_Cursor, ''''@SourceTable_02'''', @SourceTable_02)
					SET @SQLStatement_Cursor = REPLACE(@SQLStatement_Cursor, ''''@SourceTable_03'''', @SourceTable_03)
					SET @SQLStatement_Cursor = REPLACE(@SQLStatement_Cursor, ''''@SourceTable_04'''', @SourceTable_04)
					SET @SQLStatement_Cursor = REPLACE(@SQLStatement_Cursor, ''''@SourceTable_05'''', @SourceTable_05)

				SET @Step = ''''Fill temp table (tmp_Model_Raw) with raw data''''
					IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Complete Raw View into temp table'''', [SQLStatement] = @SQLStatement_Cursor
					EXEC (@SQLStatement_Cursor)

			IF @Debug <> 0 SELECT TempTable = ''''tmp_Model_Raw'''', * FROM tmp_Model_Raw

			FETCH NEXT FROM FACT_' + @SourceID_varchar + '_Table_Cursor INTO @FiscalYear, @SourceTable_01, @SourceTable_02, @SourceTable_03, @SourceTable_04, @SourceTable_05
		  END

		CLOSE FACT_' + @SourceID_varchar + '_Table_Cursor
		DEALLOCATE FACT_' + @SourceID_varchar + '_Table_Cursor'

		IF @ModelBM = 4 --FxRate
			BEGIN
				EXEC spCreate_Fact_FxRate @ApplicationID = @ApplicationID, @SourceID_varchar = @SourceID_varchar, @TempTableName = @TempTableName, @ModelName = @ModelName, @DestinationDatabase = @DestinationDatabase, @SourceTypeFamilyID = @SourceTypeFamilyID, @SQLStatement_SelectID = @SQLStatement_SelectID, @SQLStatement_DimJoin = @SQLStatement_DimJoin, @StartYear = @StartYear, @SQLStatement = @SQLStatement_FxRate OUT, @Debug = @Debug
				SET @SQLStatement = @SQLStatement + @SQLStatement_FxRate
			END
		ELSE
			BEGIN
				SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''Create query for returning result''''

		IF @CalledYN <> 0

			SET @SQLStatement = ''''
			INSERT INTO ' + @TempTableName + '''''

		ELSE
			SET @SQLStatement = ''''''''

		SET @SQLStatement = @SQLStatement + ''''
		SELECT
			'''' + @SelectID

		SET @SQLStatement = @SQLStatement + ''''
		FROM
			tmp_Model_Raw raw
			'''' + @DimJoin

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = ''''Complete View with MemberId'''', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)
		'

		SET @SQLStatement = @SQLStatement + '
	SET @Step = ''''Drop temp tables''''
		DROP TABLE #DimensionList
		DROP TABLE #FieldList
		DROP TABLE tmp_Model_Raw'
			END

	SET @SQLStatement = @SQLStatement + '

END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, Deleted = 0, Inserted = 0, Updated = 0, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH'

				SET @SQLStatement_Action = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ProcedureName + '''' + ', ' + '''P''' 
				INSERT INTO #Action ([Action]) EXEC (@SQLStatement_Action)
				SELECT @Action = [Action] FROM #Action

				SET @SQLStatement = @Action + ' PROCEDURE [dbo].[' + @ProcedureName + ']' + @SQLStatement
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				EXEC spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT

				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of Raw Procedure (Multiple)', [SQLStatement] = @SQLStatement

				EXEC (@SQLStatement)

----------------------------------------------------
				IF @Debug <> 0 SELECT Step = 'CREATE FACT procedure (Multiple)'
				SET @Step = 'CREATE FACT procedure (Multiple)'
					SET @ProcedureName = 'spIU_' + @SourceID_varchar + '_FACT_' + @ModelName
					SET @SQLStatement = '
    @JobID int = 0,
	@SourceID int = ' + CONVERT(nvarchar, @SourceID) + ',
	@ModelBM int = ' + CONVERT(nvarchar, @ModelBM) + ',
    @SpeedRunYN bit = 0,
    @Entity_MemberId bigint = -10, -- -10 gives all Entities
	@Rows int = NULL,
	@GetVersion bit = 0,
    @Duration datetime = 0 OUT,
    @Deleted int = 0 OUT,
    @Inserted int = 0 OUT,
    @Updated int = 0 OUT,
    @Debug bit = 0

	' + CASE WHEN @Encryption = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
 
    AS 

SET ANSI_WARNINGS OFF

DECLARE
	@StartTime datetime,
    @StartTime_Step datetime,
    @Step nvarchar(255),
    @JobLogID int,
    @ErrorNumber int,
	@SQLStatement nvarchar(max),
	@EntityCode nvarchar(50),
	@Deleted_Step int = 0,
    @Inserted_Step int = 0,
    @Updated_Step int = 0,
	@Version nvarchar(50) = ''''' + @Version + '''''

IF @GetVersion <> 0
	BEGIN
		SELECT [Version] =  @Version
		RETURN
	END

BEGIN TRY
    SET @Step = ''''Set @StartTime''''
		SET @StartTime = GETDATE()
        SET DATEFIRST 1

	SET @Step = ''''Set procedure variables''''
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

    SET @Step = ''''Create a temp table''''
		CREATE TABLE [' + @TempTableName + ']
			(' + @SQLStatement_CreateTable + '
			[' + @ModelName + '_Value] float
			)'

				SET @SQLStatement = @SQLStatement + '

	SET @Step = ''''Create FACT table cursor''''
		DECLARE FACT_' + @SourceID_varchar + '_' + @ModelName + '_Cursor CURSOR FOR

		SELECT 
			E.[EntityCode]
		FROM
			[Entity] E 
			INNER JOIN ' + @DestinationDatabase + '.dbo.S_DS_€£Entity£€ SE ON SE.Label = E.Entity 
		WHERE
			E.SourceID = @SourceID AND
			E.SelectYN <> 0 AND
			(SE.MemberId = @Entity_MemberId OR @Entity_MemberId = ''''-10'''')

		OPEN FACT_' + @SourceID_varchar + '_' + @ModelName + '_Cursor
		FETCH NEXT FROM FACT_' + @SourceID_varchar + '_' + @ModelName + '_Cursor INTO @EntityCode

		WHILE @@FETCH_STATUS = 0
		  BEGIN
			BEGIN TRY
				SET @Step = ''''Set @StartTime_Step''''
					SET @StartTime_Step = GETDATE()

				SET @Step = ''''Insert into temp table''''
					TRUNCATE TABLE [' + @TempTableName + ']
					EXEC spIU_' + @SourceID_varchar + '_FACT_' + @ModelName + '_Raw @JobID = @JobID, @SourceID = @SourceID, @ModelBM = @ModelBM, @EntityCode = @EntityCode, @Rows = @Rows, @CalledYN = 1
 
				SET @Step = ''''Create #FACT_Update''''
					SELECT DISTINCT
						' + @SQLStatement_Delete + '
					INTO
						#FACT_Update
					FROM
						[' + @TempTableName + ']

				SET @Step = ''''Set all existing rows that should be inserted to 0''''
					UPDATE
						F
					SET
						[' + @ModelName + '_Value] = 0
					FROM
						[' + @DestinationDatabase + '].[dbo].[FACT_' + @ModelName + '_default_partition] F' + ISNULL(@SQLStatement_FACT_DeleteJoin, '') + '
						INNER JOIN [#FACT_Update] V ON
										' + @SQLStatement_DeleteJoin + '

					SET @Updated_Step = @@ROWCOUNT'

				SET @SQLStatement = @SQLStatement + '
 
					SET @Step = ''''Insert new rows''''
						INSERT INTO [' + @DestinationDatabase + '].[dbo].[FACT_' + @ModelName + '_default_partition]
							(' + @SQLStatement_InsertInto + '
							[ChangeDatetime],
							[Userid],
							[' + @ModelName + '_Value]
							)
						SELECT' + @SQLStatement_InsertInto + '
							[ChangeDatetime] = GetDate(),
							[Userid] = suser_name(),
							[' + @ModelName + '_Value]
						FROM
							[' + @TempTableName + ']
                         
						SET @Inserted_Step = @@ROWCOUNT'

				IF @BaseModelID <> -3
/*
					SET @SQLStatement = @SQLStatement + '

						SET @Step = ''''Add Currency conversion''''
							IF (SELECT COUNT(1) FROM [' + @DestinationDatabase + '].[dbo].[S_DS_' + @FCurrency + '] WHERE [Reporting] <> 0) > 0
								EXEC spIU_0000_FACT_FxTrans @JobID = @JobID, @ModelName = ''''' + @ModelName + ''''', @BPType = ''''ETL'''', @Debug = @Debug'
*/

					SET @SQLStatement = @SQLStatement + '

						SET @Step = ''''Run selected BusinessRules''''
							EXEC spRun_BR_All @JobID = @JobID, @Model = ''''' + @ModelName + ''''', @Debug = @Debug'

				SET @SQLStatement = @SQLStatement + ' 

						SET @Step = ''''Drop the temp tables''''
							DROP TABLE #FACT_Update	

						SET @Step = ''''Clean up''''
							IF (SELECT DATEPART(WEEKDAY, GETDATE())) IN (6, 7) OR @SpeedRunYN = 0 --Saturday/Sunday or always cleanup
								BEGIN
									DELETE
										f
									FROM
										[' + @DestinationDatabase + '].[dbo].[FACT_' + @ModelName + '_default_partition] F
									WHERE
										[' + @ModelName + '_Value] = 0

									SET @Deleted_Step = @@ROWCOUNT
 								END'

				SET @SQLStatement = @SQLStatement + '
 
						SET @Step = ''''Set @Duration''''
							SET @Duration = GetDate() - @StartTime_Step
 
						SET @Step = ''''Insert into JobLog''''
							INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime_Step, OBJECT_NAME(@@PROCID) + '''' ('''' + @EntityCode + '''')'''', @Duration, @Deleted_Step, @Inserted_Step, @Updated_Step, @Version
                                                  
			END TRY
 
			BEGIN CATCH
				INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime_Step, OBJECT_NAME(@@PROCID) + '''' ('''' + @EntityCode + '''')'''', GetDate() - @StartTime_Step, @Deleted_Step, @Inserted_Step, @Updated_Step, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
				SET @JobLogID = @@IDENTITY
				SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
				SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
				RETURN @ErrorNumber
			END CATCH

			SET @Step = ''''Set procedure Counters''''
				SET @Updated = @Updated + @Updated_Step
				SET @Deleted = @Deleted + @Deleted_Step
				SET @Inserted = @Inserted + @Inserted_Step
					
			FETCH NEXT FROM FACT_' + @SourceID_varchar + '_' + @ModelName + '_Cursor INTO @EntityCode
		  END

		CLOSE FACT_' + @SourceID_varchar + '_' + @ModelName + '_Cursor
		DEALLOCATE FACT_' + @SourceID_varchar + '_' + @ModelName + '_Cursor

	SET @Step = ''''Drop the temp tables''''
		DROP TABLE [' + @TempTableName + ']

	SET @Step = ''''Set total @Duration''''
		SET @Duration = GetDate() - @StartTime

	SET @Step = ''''Insert total into JobLog''''
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

				SET @SQLStatement_Action = 'EXEC ' + @ETLDatabase + '.dbo.sp_CheckObject ''' + @ProcedureName + '''' + ', ' + '''P''' 
				INSERT INTO #Action ([Action]) EXEC (@SQLStatement_Action)
				SELECT @Action = [Action] FROM #Action

				SET @SQLStatement = @Action + ' PROCEDURE [dbo].[' + @ProcedureName + ']' + @SQLStatement
				SET @SQLStatement = 'EXEC ' + @ETLDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''

				EXEC spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement, @StringOut = @SQLStatement OUTPUT

				IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Creation of Procedure (Multiple)', [SQLStatement] = @SQLStatement

				EXEC (@SQLStatement)

			END  --END of @SourceDBTypeID = 2 --Multiple DB

	SET @Step = 'Drop temporary tables'	
		DROP TABLE #Action
		DROP TABLE #Dimension
		DROP TABLE #FieldList

	SET @Step = 'Set @Duration'	
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ISNULL(' (' + @SourceID_varchar + '_FACT_' + @ModelName + ')', ''), @Duration, @Deleted, @Inserted, @Updated, @Version
						
	RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ISNULL(' (' + @SourceID_varchar + '_FACT_' + @ModelName + ')', ''), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH





GO
