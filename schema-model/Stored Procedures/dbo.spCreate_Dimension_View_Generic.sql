SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Dimension_View_Generic] 

	@SourceID int = NULL,
	@DimensionID int = NULL,
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

--EXEC spCreate_Dimension_View_Generic @GetVersion = 1
--EXEC spCreate_Dimension_View_Generic @SourceID = 104,  @DimensionID = -1,  @Debug = true  --Account Sales		E9
--EXEC spCreate_Dimension_View_Generic @SourceID = 107,  @DimensionID = -1,  @Debug = true  --Account Fin		E9 
--EXEC spCreate_Dimension_View_Generic @SourceID = 110,  @DimensionID = -1,  @Debug = true  --Account AR		E9
--EXEC spCreate_Dimension_View_Generic @SourceID = 111,  @DimensionID = -1,  @Debug = true  --Account AP		E9            
--EXEC spCreate_Dimension_View_Generic @SourceID = 307,  @DimensionID = -1,  @Debug = true  --Account Fin		iScala
--EXEC spCreate_Dimension_View_Generic @SourceID = 607,  @DimensionID = -1,  @Debug = true  --Account Fin		pcEXCHANGE
--EXEC spCreate_Dimension_View_Generic @SourceID = 907,  @DimensionID = -1,  @Debug = true  --Account Fin		Axapta
--EXEC spCreate_Dimension_View_Generic @SourceID = 1167, @DimensionID = -1,  @Debug = true  --Account Fin		E10 
--EXEC spCreate_Dimension_View_Generic @SourceID = 1227, @DimensionID = -1,  @Debug = true  --Account Fin		Enterprise
--EXEC spCreate_Dimension_View_Generic @SourceID = 1230, @DimensionID = -1,  @Debug = true  --Account AR		Enterprise
--EXEC spCreate_Dimension_View_Generic @SourceID = 1227, @DimensionID = -1,  @Debug = true  --Account Fin		Enterprise  
--EXEC spCreate_Dimension_View_Generic @SourceID = 990,	 @DimensionID = -1,  @Debug = true  --Account Fin		Bullguard, Axapta                    
--EXEC spCreate_Dimension_View_Generic @SourceID = 107,  @DimensionID = -2,  @Debug = true  --BusinessProcess	E9
--EXEC spCreate_Dimension_View_Generic @SourceID = 307,  @DimensionID = -2,  @Debug = true  --BusinessProcess	iScala
--EXEC spCreate_Dimension_View_Generic @SourceID = 1167, @DimensionID = -2,  @Debug = true  --BusinessProcess	E10
--EXEC spCreate_Dimension_View_Generic @SourceID = 982,  @DimensionID = -2,  @Debug = true  --BusinessProcess	NAV
--EXEC spCreate_Dimension_View_Generic @SourceID = -1579,  @DimensionID = -3,  @Debug = true  --Currency			E9
--EXEC spCreate_Dimension_View_Generic @SourceID = 303,  @DimensionID = -3,  @Debug = true  --Currency			iScala
--EXEC spCreate_Dimension_View_Generic @SourceID = 1103, @DimensionID = -3,  @Debug = true  --Currency			E10
--EXEC spCreate_Dimension_View_Generic @SourceID = 103,  @DimensionID = -4,  @Debug = true  --Entity			E9
--EXEC spCreate_Dimension_View_Generic @SourceID = 6007, @DimensionID = -4,  @Debug = true  --Entity			E101, AnnJoo
--EXEC [spCreate_Dimension_View_Generic] @SourceID = -1579, @DimensionID = -5, @Debug = true  --Rate
--EXEC spCreate_Dimension_View_Generic @SourceID = 3076, @DimensionID = -5,  @Debug = true  --Rate
--EXEC spCreate_Dimension_View_Generic @SourceID = 3078, @DimensionID = -5,  @Debug = true  --Rate
--EXEC spCreate_Dimension_View_Generic @SourceID = 3082, @DimensionID = -5,  @Debug = true  --Rate
--EXEC spCreate_Dimension_View_Generic @SourceID = 304,  @DimensionID = -6,  @Debug = true  --Scenario
--EXEC spCreate_Dimension_View_Generic @SourceID = 1076, @DimensionID = -6,  @Debug = true  --Scenario
--EXEC spCreate_Dimension_View_Generic @SourceID = 1147, @DimensionID = -6,  @Debug = true  --Scenario
--EXEC spCreate_Dimension_View_Generic @SourceID = 1076, @DimensionID = -7,  @Debug = true  --Time
--EXEC spCreate_Dimension_View_Generic @SourceID = 1076, @DimensionID = -8,  @Debug = true  --TimeDataView
--EXEC spCreate_Dimension_View_Generic @SourceID = 104,  @DimensionID = -9,  @Debug = true  --Customer
--EXEC spCreate_Dimension_View_Generic @SourceID = 110,  @DimensionID = -9,  @Debug = true  --Customer
--EXEC spCreate_Dimension_View_Generic @SourceID = 304,  @DimensionID = -9,  @Debug = true  --Customer
--EXEC spCreate_Dimension_View_Generic @SourceID = 111,  @DimensionID = -10, @Debug = true  --Supplier
--EXEC spCreate_Dimension_View_Generic @SourceID = 311,  @DimensionID = -10, @Debug = true  --Supplier
--EXEC spCreate_Dimension_View_Generic @SourceID = 18,   @DimensionID = -11, @Debug = true  --Month
--EXEC spCreate_Dimension_View_Generic @SourceID = 104,  @DimensionID = -12, @Debug = true  --Geography			E9
--EXEC spCreate_Dimension_View_Generic @SourceID = 1104, @DimensionID = -12, @Debug = true  --Geography			E10
--EXEC spCreate_Dimension_View_Generic @SourceID = 110,  @DimensionID = -13, @Debug = true  --CustomerCategory
--EXEC spCreate_Dimension_View_Generic @SourceID = 11,   @DimensionID = -14, @Debug = true  --District
--EXEC spCreate_Dimension_View_Generic @SourceID = 104,  @DimensionID = -15, @Debug = true  --InvoiceNo_AR
--EXEC spCreate_Dimension_View_Generic @SourceID = 3079, @DimensionID = -15, @Debug = true  --InvoiceNo_AR                                       
--EXEC spCreate_Dimension_View_Generic @SourceID = 104,  @DimensionID = -16, @Debug = true  --OrderNo			E9
--EXEC spCreate_Dimension_View_Generic @SourceID = 304,  @DimensionID = -16, @Debug = true  --OrderNo			iScala
--EXEC spCreate_Dimension_View_Generic @SourceID = 904,  @DimensionID = -16, @Debug = true  --OrderNo			AX
--EXEC spCreate_Dimension_View_Generic @SourceID = 1224, @DimensionID = -16, @Debug = true  --OrderNo			ENT                                              
--EXEC spCreate_Dimension_View_Generic @SourceID = 0,    @DimensionID = -17, @Debug = true  --OrderState
--EXEC spCreate_Dimension_View_Generic @SourceID = 8,    @DimensionID = -18, @Debug = true  --OrderType
--EXEC spCreate_Dimension_View_Generic @SourceID = 104,  @DimensionID = -19, @Debug = true  --Product			E9
--EXEC spCreate_Dimension_View_Generic @SourceID = 304,  @DimensionID = -19, @Debug = true  --Product			iScala
--EXEC spCreate_Dimension_View_Generic @SourceID = 804,  @DimensionID = -19, @Debug = true  --Product			NAV
--EXEC spCreate_Dimension_View_Generic @SourceID = 1224, @DimensionID = -19, @Debug = true  --Product			ENT
--EXEC spCreate_Dimension_View_Generic @SourceID = 304,  @DimensionID = -20, @Debug = true  --ProductGroup		iScala
--EXEC spCreate_Dimension_View_Generic @SourceID = 1224, @DimensionID = -20, @Debug = true  --ProductGroup		ENT
--EXEC spCreate_Dimension_View_Generic @SourceID = 304,  @DimensionID = -21, @Debug = true  --ProductCategory	iScala
--EXEC spCreate_Dimension_View_Generic @SourceID = 1224, @DimensionID = -21, @Debug = true  --ProductCategory	ENT
--EXEC spCreate_Dimension_View_Generic @SourceID = 304,  @DimensionID = -22, @Debug = true  --AccountManager	iScala
--EXEC spCreate_Dimension_View_Generic @SourceID = 1224, @DimensionID = -22, @Debug = true  --AccountManager	ENT
--EXEC spCreate_Dimension_View_Generic @SourceID = 1104, @DimensionID = -22, @Debug = true  --AccountManager	E10
--EXEC spCreate_Dimension_View_Generic @SourceID = 1110, @DimensionID = -22, @Debug = true  --AccountManager	E10
--EXEC spCreate_Dimension_View_Generic @SourceID = 3076, @DimensionID = -23, @Debug = true  --SNI
--EXEC spCreate_Dimension_View_Generic @SourceID = 304,  @DimensionID = -24, @Debug = true  --Warehouse
--EXEC spCreate_Dimension_View_Generic @SourceID = 1224, @DimensionID = -24, @Debug = true  --Warehouse			ENT
--EXEC spCreate_Dimension_View_Generic @SourceID = 107,  @DimensionID = -26, @Debug = true  --Version
--EXEC spCreate_Dimension_View_Generic @SourceID = -1585,  @DimensionID = -27, @Debug = true  --LineItem
--EXEC spCreate_Dimension_View_Generic @SourceID = 35,   @DimensionID = -28, @Debug = true  --CurrentOrderState
--EXEC spCreate_Dimension_View_Generic @SourceID = 304,  @DimensionID = -29, @Debug = true  --OrderLine
--EXEC spCreate_Dimension_View_Generic @SourceID = 1224, @DimensionID = -29, @Debug = true  --OrderLine			ENT
--EXEC spCreate_Dimension_View_Generic @SourceID = 103,  @DimensionID = -32, @Debug = true  --BaseCurrency
--EXEC spCreate_Dimension_View_Generic @SourceID = -1077,  @DimensionID = -32, @Debug = true  --BaseCurrency
--EXEC spCreate_Dimension_View_Generic @SourceID = 25,   @DimensionID = -33, @Debug = true  --Simulation
--EXEC spCreate_Dimension_View_Generic @SourceID = 24,   @DimensionID = -34, @Debug = true  --Flow
--EXEC spCreate_Dimension_View_Generic @SourceID = 24,   @DimensionID = -36, @Debug = true  --LegalEntity
--EXEC spCreate_Dimension_View_Generic @SourceID = 111,  @DimensionID = -46, @Debug = true  --InvoiceNo_AP		E9
--EXEC spCreate_Dimension_View_Generic @SourceID = 311,  @DimensionID = -46, @Debug = true  --InvoiceNo_AP		iScala
--EXEC spCreate_Dimension_View_Generic @SourceID = 3080, @DimensionID = -46, @Debug = true  --InvoiceNo_AP		ENT
--EXEC spCreate_Dimension_View_Generic @SourceID = 3076, @DimensionID = -47, @Debug = true  --Aging_AR
--EXEC spCreate_Dimension_View_Generic @SourceID = 3077, @DimensionID = -48, @Debug = true  --Aging_AP
--EXEC spCreate_Dimension_View_Generic @SourceID = 557,  @DimensionID = -53, @Debug = true  --FullAccount
--EXEC spCreate_Dimension_View_Generic @SourceID = 990,  @DimensionID = -53, @Debug = true  --FullAccount		AX Bullguard
--EXEC spCreate_Dimension_View_Generic @SourceID = 107,  @DimensionID = -55, @Debug = true  --BusinessRule		E9
--EXEC spCreate_Dimension_View_Generic @SourceID = 0,    @DimensionID = -58, @Debug = true  --Voucher
--EXEC spCreate_Dimension_View_Generic @SourceID = 1104, @DimensionID = -59, @Debug = true  --OrderManager		E10
--EXEC spCreate_Dimension_View_Generic @SourceID = -1469, @DimensionID = -63, @Debug = true  --WorkflowState		E10

DECLARE
	@StartTime datetime,
	@Step nvarchar(255),
	@JobLogID int,
	@ErrorNumber int,

	@SequenceBM int,
	@SequenceBMLeafLevel int,
	@SequenceBMSum int,
	@SequenceBMStep int, 
	@SequenceCounter int,
	@SequenceDescription nvarchar(255),
	@DimensionName nvarchar(100),
	@ActionStatement nvarchar(1000),

	@SQLStatement nvarchar(max),
	@SQLStatement1 nvarchar(max),
	@SQLStatement2_01 nvarchar(max) = '',
	@SQLStatement2_02 nvarchar(max) = '',
	@SQLStatement2_03 nvarchar(max) = '',
	@SQLStatement2_04 nvarchar(max) = '',
	@SQLStatement2_05 nvarchar(max) = '',
	@SQLStatement2_06 nvarchar(max) = '',
	@SQLStatement2_07 nvarchar(max) = '',
	@SQLStatement2_08 nvarchar(max) = '',
	@SQLStatement2_09 nvarchar(max) = '',
	@SQLStatement2_10 nvarchar(max) = '',
	@SQLStatement3_01 nvarchar(max) = '',
	@SQLStatement3_02 nvarchar(max) = '',
	@SQLStatement3_03 nvarchar(max) = '',
	@SQLStatement3_04 nvarchar(max) = '',
	@SQLStatement3_05 nvarchar(max) = '',
	@SQLStatement3_06 nvarchar(max) = '',
	@SQLStatement3_07 nvarchar(max) = '',
	@SQLStatement3_08 nvarchar(max) = '',
	@SQLStatement3_09 nvarchar(max) = '',
	@SQLStatement3_10 nvarchar(max) = '',
	@SQLStatement3_11 nvarchar(max) = '',
	@SQLStatement3_12 nvarchar(max) = '',
	@SQLStatement3_13 nvarchar(max) = '',
	@SQLStatement3_14 nvarchar(max) = '',
	@SQLStatement3_15 nvarchar(max) = '',
	@SQLStatement3_16 nvarchar(max) = '',
	@SQLStatement3_17 nvarchar(max) = '',
	@SQLStatement3_18 nvarchar(max) = '',
	@SQLStatement3_19 nvarchar(max) = '',
	@SQLStatement3_20 nvarchar(max) = '',
	@SQLStatement4 nvarchar(max),
	@SQLStatement_Sub nvarchar(max),
	@SQLStatement_Select nvarchar(max),
	@SQLStatement_Where nvarchar(max),
	@SQLStatement_MaxRawSelect nvarchar(max),
	@SQLStatement_RawSelect nvarchar(max),
	@SQLStatement_RawSelect_Entity nvarchar(max),
	@SQLStatement_MapJoin nvarchar(max),
	@SQLStatement_RawFrom nvarchar(max),
	@SQLStatement_RawWhere nvarchar(max),
	@SQLStatement_DimJoin nvarchar(max),
	@SQLStatement_Label nvarchar(max),
	@SQLStatement_Prio nvarchar(max),
	@SQLStatement_Member nvarchar(max),
	@SQLStatement_GroupBy nvarchar(max),
	@Action nvarchar(10),
	@SourceType nvarchar(50),
	@SourceTypeFamilyID int,
	@SourceDBTypeID int,
	@SourceDatabase nvarchar(255),
	@Owner nvarchar(10),
	@ETLDatabase nvarchar(100),
	@ETLDatabase_Linked nvarchar(100),
	@DestinationDatabase nvarchar(100),
	@SourceID_varchar nvarchar(10),
	@ObjectName nvarchar(50),
	@Union nvarchar(100),
	@ModelBM int,
	@DimModelBM int,
	@SourceTypeBM int,
	@RevisionBM int,
	@LinkedBM int,
	@StartYear int,
	@GenericYN bit,
	@MultipleProcedureYN bit,
	@InstanceID int,
	@VersionID int,
	@ApplicationID int,
	@LanguageID int,
	@FinanceAccountYN bit,
	@MappingEnabledYN bit,
	@MappingTypeID int,
	@DimensionTypeID int,
	@BaseModelID int,
	@MasterDimensionID int,
	@SlaveDimensionYN bit,
	@EntityMappingYN bit,
	@AllYN bit,
	@Counter int = 0,
	@CharCounter int,
	@CharCounterResidual int,
	@DefaultCurrency nvarchar(10) = '',
	@SourceTypeBM_All int,
	@Description nvarchar(255),
	@Version nvarchar(50) = '1.4.0.2139'

IF @GetVersion <> 0
    BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2062' SET @Description = 'Version added to JobLog.'
		IF @Version = '1.2.2066' SET @Description = 'Enhanced handling of long SQL strings for @SourceDBTypeID = 2 (Multiple).'
		IF @Version = '1.2.2067' SET @Description = 'Enhanced handling of long SQL strings for fixed members.'
		IF @Version = '1.3.2071' SET @Description = 'Handle FullAccount. Filter PropertyID NOT BETWEEN 100 AND 1000, Handle SourceID = 0'
		IF @Version = '1.3.2073' SET @Description = 'Handle @RevisionBM (BudgetCode Epicor 10.1)'
		IF @Version = '1.3.2075' SET @Description = 'Read Entity instead of EntityCode, Handle @LinkedBM'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2084' SET @Description = 'Fixed bug for static dimensions where @SequenceBMLeafLevel IS NULL'
		IF @Version = '1.3.2085' SET @Description = 'Handle ETL_Linked and Collations in Label.'
		IF @Version = '1.2.2090' SET @Description = 'Modified Entity Priority order.'
		IF @Version = '1.3.2094' SET @Description = 'Test on MappingTypeID when implement EntityPriority'
		IF @Version = '1.3.2095' SET @Description = 'Replaced VisibleYN and MandatoryYN with VisibilityLevelBM, ISNULL test on @ETLDatabase_Linked'
		IF @Version = '1.3.2101' SET @Description = 'Check on AllYN'
		IF @Version = '1.3.2104' SET @Description = 'Move Entity Prioritization to wrk_EntityPriority...'
		IF @Version = '1.3.2106' SET @Description = 'Handle SBZ property. Fixed bug regarding Parent setting when Entity prefixed/suffixed.'
		IF @Version = '1.3.2109' SET @Description = 'Fixed MemberIDs for all Static Members. Increased number of parameters for [spGet_Member] from 15 to 20.'
		IF @Version = '1.3.2110' SET @Description = 'Get fixed MemberIDs from the Member table.'
		IF @Version = '1.3.2116' SET @Description = 'Handle @DefaultCurrency for Entities. Handle HelpText.'
		IF @Version = '1.3.2117' SET @Description = 'Enhanced handling of HelpText.'
		IF @Version = '1.3.0.2118' SET @Description = 'Handling GROUP BY in sequences.'
		IF @Version = '1.3.1.2120' SET @Description = 'Test on @SourceTypeBM. Test on @MasterDimensionID.'
		IF @Version = '1.3.1.2123' SET @Description = 'Handle @MultipleProcedureYN.'
		IF @Version = '1.4.0.2135' SET @Description = 'Enhanced calculation of @SequenceBMLeafLevel.'
		IF @Version = '1.4.0.2139' SET @Description = 'Added REPLACE of @InstanceID, @VersionID and @ApplicationID to handle Cloud solutions. Exclude NodeTypeBM.'

		SELECT [Version] =  @Version, [Description] = @Description
		RETURN
    END

IF @SourceID IS NULL OR @DimensionID IS NULL
    BEGIN
		PRINT 'Parameter @SourceID and parameter @DimensionID must be set'
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
			@AllYN = AllYN
		FROM
			Dimension
		WHERE
			DimensionID = @DimensionID

		IF @SourceID = 0
			SELECT DISTINCT
				@InstanceID = A.InstanceID,
				@VersionID = A.VersionID,
				@ApplicationID = M.ApplicationID,
				@ETLDatabase = A.ETLDatabase,
				@DestinationDatabase = A.DestinationDatabase,
				@LanguageID = A.LanguageID
			FROM
				Model_Dimension MD 
				INNER JOIN Model BM ON BM.ModelID = MD.ModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
				INNER JOIN Model M ON M.BaseModelID = BM.ModelID AND M.SelectYN <> 0
				INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
			WHERE
				MD.DimensionID = @DimensionID AND
				MD.Introduced < @Version AND
				MD.SelectYN <> 0
		ELSE
			SELECT
				@InstanceID = A.InstanceID,
				@VersionID = A.VersionID,
				@ApplicationID = M.ApplicationID,
				@ETLDatabase = '[' + REPLACE(REPLACE(REPLACE(A.ETLDatabase, '[', ''), ']', ''), '.', '].[') + ']',
				@ETLDatabase_Linked = '[' + REPLACE(REPLACE(REPLACE(S.ETLDatabase_Linked, '[', ''), ']', ''), '.', '].[') + ']',
				@DestinationDatabase = A.DestinationDatabase,
				@LanguageID = A.LanguageID
			FROM
				Model M
				INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID
				INNER JOIN Source S ON S.SourceID = @SourceID AND S.ModelID = M.ModelID AND S.SelectYN <> 0
			WHERE
				M.SelectYN <> 0

		SELECT DISTINCT
			@SourceType = MAX(ST.SourceTypeName),
			@SourceDatabase = '[' + REPLACE(REPLACE(REPLACE(MAX(S.SourceDatabase), '[', ''), ']', ''), '.', '].[') + ']',
			@Owner = MAX(ST.[Owner]),
			@FinanceAccountYN = MAX(CASE WHEN @DimensionID = -1 AND BM.FinanceAccountYN <> 0 THEN 1 ELSE 0 END),
			@DimModelBM = SUM(CASE WHEN MD.ModelID IS NOT NULL THEN 1 ELSE 0 END * BM.ModelBM),
			@SourceTypeBM = MAX(ST.SourceTypeBM),
			@StartYear = MAX(S.StartYear),
			@GenericYN = MAX(CONVERT(int, D.GenericYN)),
			@MultipleProcedureYN = MAX(CONVERT(int, D.MultipleProcedureYN)),
			@MappingEnabledYN = CASE WHEN MAX(D.MasterDimensionID) IS NULL THEN MAX(CONVERT(int, DT.MappingEnabledYN)) ELSE 0 END,
			@DimensionTypeID = MAX(D.DimensionTypeID),
			@SourceDBTypeID = MAX(ST.SourceDBTypeID),
			@SourceTypeFamilyID = MAX(ST.SourceTypeFamilyID),
			@ModelBM = ISNULL(MAX(CASE WHEN S.ModelID = M.ModelID THEN BM.ModelBM ELSE NULL END), MAX(BM.ModelBM)),
			@BaseModelID = ISNULL(MAX(CASE WHEN S.ModelID = M.ModelID THEN M.BaseModelID ELSE NULL END), MAX(M.BaseModelID)),
			@SourceID_varchar = CASE WHEN MAX(CONVERT(int, D.GenericYN)) <> 0 THEN '0000' ELSE CASE WHEN ABS(@SourceID) <= 9 THEN '000' ELSE CASE WHEN ABS(@SourceID) <= 99 THEN '00' ELSE CASE WHEN ABS(@SourceID) <= 999 THEN '0' ELSE '' END END END + CONVERT(nvarchar, ABS(@SourceID)) END,
			@MasterDimensionID = MAX(D.MasterDimensionID)
		FROM
			[Application] A
			INNER JOIN Model M ON M.ApplicationID = A.ApplicationID AND M.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = M.BaseModelID AND BM.Introduced < @Version AND BM.SelectYN <> 0
			INNER JOIN Model_Dimension MD ON MD.ModelID = BM.ModelID AND MD.DimensionID = @DimensionID AND MD.Introduced < @Version AND MD.SelectYN <> 0
			INNER JOIN Dimension D ON D.DimensionID = MD.DimensionID AND D.Introduced < @Version AND D.SelectYN <> 0 
			INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID
			LEFT JOIN [Source] S ON S.SourceID = @SourceID AND S.ModelID = M.ModelID
			LEFT JOIN SourceType ST ON ST.SourceTypeID = S.SourceTypeID AND ST.Introduced < @Version AND ST.SelectYN <> 0
		WHERE
			A.ApplicationID = @ApplicationID
		GROUP BY
			D.DimensionID

		SET @SourceTypeBM = ISNULL(@SourceTypeBM, 4)
		IF @Debug <> 0 SELECT [@SourceTypeBM] = @SourceTypeBM

	SET @Step = 'Check Source DBType'
		IF @SourceDBTypeID = 2 AND @MultipleProcedureYN <> 0 --@GenericYN = 0
			BEGIN
				SELECT @JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END
				SELECT @SlaveDimensionYN = CASE WHEN @MasterDimensionID IS NULL THEN 0 ELSE 1 END
			END
		ELSE
			BEGIN
				EXEC [spCreate_Dimension_Procedure_Generic_Raw_1_SourceDBType] @SourceID = @SourceID, @DimensionID = @DimensionID, @JobID = @JobID, @Encryption = @Encryption, @Debug = @Debug
				RETURN
			END

		CREATE TABLE #MappingType (MappingTypeID int)

		SET @SQLStatement = '
		INSERT INTO #MappingType (MappingTypeID)
		SELECT 
			MappingTypeID
		FROM
			' + @ETLDatabase + '.dbo.MappedObject MO
			INNER JOIN Dimension D ON D.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND D.DimensionTypeID = ' + CONVERT(nvarchar(10), @DimensionTypeID) + ' AND D.Introduced < ''' + @Version + ''' AND D.SelectYN <> 0 
		WHERE
			MO.Entity = -1 AND
			MO.ObjectName = D.DimensionName AND
			MO.DimensionTypeID = D.DimensionTypeID AND
			MO.ObjectTypeBM & 2 > 0 AND
			MO.SelectYN <> 0'

		EXEC (@SQLStatement)

		IF @MappingEnabledYN = 0 OR @SlaveDimensionYN <> 0
			SET @MappingTypeID = 0
		ELSE
			SELECT @MappingTypeID = MappingTypeID FROM #MappingType

		SELECT @MappingTypeID = ISNULL(@MappingTypeID, 0)

		DROP TABLE #MappingType

		IF @DimensionID IN (-4) --Entity
			BEGIN 
				CREATE TABLE #DefaultCurrency (DefaultCurrency nvarchar(10))

				SET @SQLStatement = '
				INSERT INTO #DefaultCurrency (DefaultCurrency)
				SELECT TOP 1
					DefaultCurrency = Currency
				FROM
					(
					SELECT Currency, #Count = COUNT(1) FROM ' + @ETLDatabase + '.dbo.Entity WHERE SelectYN <> 0 GROUP BY Currency
					) sub
				ORDER BY
					#Count DESC'

				EXEC (@SQLStatement)

				SELECT @DefaultCurrency = DefaultCurrency FROM #DefaultCurrency

				SELECT @DefaultCurrency = ISNULL(@DefaultCurrency, 'NONE')

				DROP TABLE #DefaultCurrency
			END

		EXEC [spGet_Revision] @SourceID = @SourceID, @RevisionBM = @RevisionBM OUT
		
		EXEC [spGet_Linked] @SourceID = @SourceID, @LinkedBM = @LinkedBM OUT
		
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

		IF @Debug <> 0
			SELECT
				ApplicationID = @ApplicationID,
				ETLDatabase = @ETLDatabase,
				DestinationDatabase = @DestinationDatabase,
				DimensionID = @DimensionID,
				MappingEnabledYN = @MappingEnabledYN,
				MappingTypeID = @MappingTypeID,
				ModelBM = @ModelBM,
				FinanceAccountYN = @FinanceAccountYN,
				DimModelBM = @DimModelBM,
				GenericYN = @GenericYN,
				LanguageID = @LanguageID,
				DimensionTypeID = @DimensionTypeID,
				BaseModelID = @BaseModelID,
				SourceID_varchar = @SourceID_varchar,
				SourceTypeBM = @SourceTypeBM,
				RevisionBM = @RevisionBM,
				LinkedBM = @LinkedBM,
				SourceDBTypeID = @SourceDBTypeID,
				SourceDatabase = @SourceDatabase,
				[Owner] = @Owner,
				StartYear = @StartYear,
				DefaultCurrency = @DefaultCurrency

	SET @Step = 'Check DimensionType'
		IF @DimensionTypeID IN (7, 25) RETURN  --Time, TimeProperty

		IF @DimensionTypeID = 27 --FullAccount
			BEGIN
				EXEC spCreate_Dimension_View_FullAccount @SourceID = @SourceID, @DimensionID = @DimensionID, @Encryption = @Encryption, @Debug = @Debug
				RETURN
			END

	SET @Step = 'Create #Model_Dimension temp table'
		SELECT DISTINCT
			BM.ModelID,
			D.DimensionID,
			BM.ModelBM,
			VisibilityLevelBM = MD.VisibilityLevelBM,
			MappingEnabledYN = CASE WHEN @SlaveDimensionYN = 0 THEN MD.MappingEnabledYN ELSE 0 END
		INTO
			#Model_Dimension
		FROM
			Dimension D
			INNER JOIN Model_Dimension MD ON MD.DimensionID = D.DimensionID AND MD.Introduced < @Version AND MD.SelectYN <> 0
			INNER JOIN Model BM ON BM.ModelID = MD.ModelID AND BM.ModelBM & @ModelBM > 0 AND BM.Introduced < @Version AND BM.SelectYN <> 0
			INNER JOIN Model M ON M.BaseModelID = BM.ModelID AND M.ApplicationID = @ApplicationID AND M.SelectYN <> 0
			LEFT JOIN [Source] S ON S.SourceID = @SourceID AND S.ModelID = M.ModelID AND S.SelectYN <> 0
		WHERE
			D.DimensionID = @DimensionID AND
			D.Introduced < @Version AND
			D.SelectYN <> 0

		IF @Debug <> 0 SELECT TempTable = '#Model_Dimension', * FROM #Model_Dimension

	SET @Step = 'Set @SequenceBMSum'
		SELECT
			@SequenceBMSum = SUM(SequenceBM)--,
--			@SequenceBMLeafLevel = MAX(SequenceBM)
		FROM
			pcINTEGRATOR.dbo.SqlSource_Dimension SSD
		WHERE
			SSD.DimensionID = @DimensionID AND 
			SSD.SourceTypeBM & @SourceTypeBM > 0 AND
			SSD.RevisionBM & @RevisionBM > 0 AND
			SSD.ModelBM & @ModelBM > 0 AND
			SSD.LinkedBM & @LinkedBM > 0 AND
			SSD.PropertyID = 100 AND
			SSD.SelectYN <> 0

		SET @SequenceBMSum = ISNULL(@SequenceBMSum, 0)

	SET @Step = 'Set @SequenceBMLeafLevel'
		SELECT DISTINCT
			SequenceBM
		INTO
			#SequenceBM
		FROM
			SqlSource_Dimension SSD
		WHERE
			SSD.DimensionID = @DimensionID AND 
			SSD.SourceTypeBM & @SourceTypeBM > 0 AND
			SSD.RevisionBM & @RevisionBM > 0 AND
			SSD.ModelBM & @ModelBM > 0 AND
			SSD.LinkedBM & @LinkedBM > 0 AND
			SSD.SelectYN <> 0 AND
			SSD.LeafLevelYN <> 0

		CREATE TABLE #LeafLevelBM
			(
			LeafLevelBM int
			)

		DECLARE LeafLevel_Cursor CURSOR FOR

			SELECT 
				SequenceBM
			FROM
				#SequenceBM
			ORDER BY
				SequenceBM

			OPEN LeafLevel_Cursor
			FETCH NEXT FROM LeafLevel_Cursor INTO @SequenceBM

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @Debug <> 0 SELECT SequenceBM = @SequenceBM

					INSERT INTO #LeafLevelBM (LeafLevelBM) SELECT LeafLevelBM =   1 WHERE @SequenceBM &   1 > 0 AND NOT EXISTS (SELECT 1 FROM #LeafLevelBM WHERE LeafLevelBM =   1)
					INSERT INTO #LeafLevelBM (LeafLevelBM) SELECT LeafLevelBM =   2 WHERE @SequenceBM &   2 > 0 AND NOT EXISTS (SELECT 1 FROM #LeafLevelBM WHERE LeafLevelBM =   2)
					INSERT INTO #LeafLevelBM (LeafLevelBM) SELECT LeafLevelBM =   4 WHERE @SequenceBM &   4 > 0 AND NOT EXISTS (SELECT 1 FROM #LeafLevelBM WHERE LeafLevelBM =   4)
					INSERT INTO #LeafLevelBM (LeafLevelBM) SELECT LeafLevelBM =   8 WHERE @SequenceBM &   8 > 0 AND NOT EXISTS (SELECT 1 FROM #LeafLevelBM WHERE LeafLevelBM =   8)
					INSERT INTO #LeafLevelBM (LeafLevelBM) SELECT LeafLevelBM =  16 WHERE @SequenceBM &  16 > 0 AND NOT EXISTS (SELECT 1 FROM #LeafLevelBM WHERE LeafLevelBM =  16)
					INSERT INTO #LeafLevelBM (LeafLevelBM) SELECT LeafLevelBM =  32 WHERE @SequenceBM &  32 > 0 AND NOT EXISTS (SELECT 1 FROM #LeafLevelBM WHERE LeafLevelBM =  32)
					INSERT INTO #LeafLevelBM (LeafLevelBM) SELECT LeafLevelBM =  64 WHERE @SequenceBM &  64 > 0 AND NOT EXISTS (SELECT 1 FROM #LeafLevelBM WHERE LeafLevelBM =  64)
					INSERT INTO #LeafLevelBM (LeafLevelBM) SELECT LeafLevelBM = 128 WHERE @SequenceBM & 128 > 0 AND NOT EXISTS (SELECT 1 FROM #LeafLevelBM WHERE LeafLevelBM = 128)
					INSERT INTO #LeafLevelBM (LeafLevelBM) SELECT LeafLevelBM = 256 WHERE @SequenceBM & 256 > 0 AND NOT EXISTS (SELECT 1 FROM #LeafLevelBM WHERE LeafLevelBM = 256)
					INSERT INTO #LeafLevelBM (LeafLevelBM) SELECT LeafLevelBM = 512 WHERE @SequenceBM & 512 > 0 AND NOT EXISTS (SELECT 1 FROM #LeafLevelBM WHERE LeafLevelBM = 512)

					FETCH NEXT FROM LeafLevel_Cursor INTO @SequenceBM
				END

		CLOSE LeafLevel_Cursor
		DEALLOCATE LeafLevel_Cursor

		SELECT @SequenceBMLeafLevel = SUM(LeafLevelBM) FROM #LeafLevelBM
		SELECT @SequenceBMLeafLevel = ISNULL(@SequenceBMLeafLevel, 0)

		DROP TABLE #SequenceBM
		DROP TABLE #LeafLevelBM

		IF @Debug <> 0
			SELECT
				SequenceBMLeafLevel = @SequenceBMLeafLevel,
				SequenceBMSum = @SequenceBMSum,
				DimensionID = @DimensionID,
				SourceTypeBM = @SourceTypeBM,
				RevisionBM = @RevisionBM,
				ModelBM = @ModelBM,
				LinkedBM = @LinkedBM
			
	SET @Step = 'Set dimension properties in temp table (#DimensionProperty)'
		CREATE TABLE #DimensionProperty
			(
			DimensionID int,
			DimensionName nvarchar(100),
			PropertyID int,
			PropertyName nvarchar(100),
			DataTypeID int,
			DependentDimensionID int,
			DependentDimensionName nvarchar(100),
			DynamicYN bit,
			SequenceBM int,
			GroupByYN bit,
			SourceString nvarchar(4000),
			DefaultValueView nvarchar(100),
			MappingEnabledYN bit,
			MappingTypeID int,
			StringTypeBM int,
			SortOrder int
			)

		IF @Debug <> 0
			SELECT
				SequenceBMSum = @SequenceBMSum,
				AllYN = @AllYN,
				SlaveDimensionYN = @SlaveDimensionYN,
				SequenceBMLeafLevel = @SequenceBMLeafLevel,
				SlaveDimensionYN = @SlaveDimensionYN,
				DimensionID = @DimensionID,
				[Version] = @Version,
				ModelBM = @ModelBM,
				ETLDatabase = @ETLDatabase,
				SourceTypeBM = @SourceTypeBM,
				RevisionBM = @RevisionBM,
				LinkedBM = @LinkedBM,
				BaseModelID = @BaseModelID,
				SourceTypeBM_All = @SourceTypeBM_All

		SET @SQLStatement = '
			INSERT INTO #DimensionProperty
				(
				DimensionID,
				DimensionName,
				PropertyID,
				PropertyName,
				DataTypeID,
				DependentDimensionID,
				DependentDimensionName,
				DynamicYN,
				SequenceBM,
				GroupByYN,
				SourceString,
				DefaultValueView,
				MappingEnabledYN,
				MappingTypeID,
				StringTypeBM,
				SortOrder
				)
			SELECT DISTINCT
				P.DimensionID,
				DimensionName = MO.MappedObjectName,
				P.PropertyID,
				P.PropertyName,
				P.DataTypeID,
				P.DependentDimensionID,
				DependentDimensionName = DD.DimensionName,
				P.DynamicYN,
				SequenceBM = CASE WHEN SSD.SequenceBM IS NULL THEN CASE WHEN MPV.PropertyID IS NULL AND P.PropertyID NOT IN (8, 9) THEN 0 ELSE ' + CONVERT(nvarchar(10), ISNULL(@SequenceBMSum, 0)) + ' END ELSE SSD.SequenceBM END, 
				GroupByYN = ISNULL(SSD.GroupByYN, 0),
				SourceString = CASE WHEN P.PropertyID = 3 AND ' + CONVERT(nvarchar(10), @AllYN) + ' = 0 AND ISNULL(SSD.SourceString, P.DefaultValueView) = ''''''All_'''''' THEN ''''''NULL'''''' ELSE ISNULL(SSD.SourceString, P.DefaultValueView) END,
				DefaultValueView = P.DefaultValueView,
				MappingEnabledYN = CASE WHEN ' + CONVERT(nvarchar(10), @SlaveDimensionYN) + ' = 0 THEN CASE WHEN (P.PropertyID IN (5, 4, 3) AND (SSD.SequenceBM & ' + CONVERT(nvarchar(10), ISNULL(@SequenceBMLeafLevel, 0)) + ' > 0 OR SSD.SequenceBM & SSD610.SequenceBM > 0)) OR (P.PropertyID IN (3) AND SSD.SequenceBM & SSD620.SequenceBM > 0) THEN CONVERT(int, MD.MappingEnabledYN) * CONVERT(int, DT.MappingEnabledYN) ELSE CONVERT(int, ISNULL(DMD.MappingEnabledYN, 0)) * CONVERT(int, ISNULL(DDT.MappingEnabledYN, 0)) END ELSE 0 END,
				MappingTypeID = CASE WHEN ' + CONVERT(nvarchar(10), @SlaveDimensionYN) + ' = 0 THEN CASE WHEN (P.PropertyID IN (5, 4, 3) AND (SSD.SequenceBM & ' + CONVERT(nvarchar(10), ISNULL(@SequenceBMLeafLevel, 0)) + ' > 0 OR SSD.SequenceBM & SSD610.SequenceBM > 0)) OR (P.PropertyID IN (3) AND SSD.SequenceBM & SSD620.SequenceBM > 0) THEN MO.MappingTypeID * CONVERT(int, MD.MappingEnabledYN) * CONVERT(int, DT.MappingEnabledYN) ELSE ISNULL(DMO.MappingTypeID, 0) * CONVERT(int, ISNULL(DMD.MappingEnabledYN, 0)) * CONVERT(int, ISNULL(DDT.MappingEnabledYN, 0)) END ELSE 0 END,
				StringTypeBM = CONVERT(int, CASE WHEN P.PropertyID IN (5, 4, 3) THEN MO.ReplaceTextYN ELSE ISNULL(DMO.ReplaceTextYN, 0) END) * P.StringTypeBM * ISNULL(CONVERT(int, SSD.ReplaceTextEnabledYN), 0) * CONVERT(int, ISNULL(CASE WHEN P.PropertyID IN (5, 4, 3) THEN DT.ReplaceTextEnabledYN ELSE DDT.ReplaceTextEnabledYN END, 0)),
				P.SortOrder'

		SET @SQLStatement = @SQLStatement + '
			FROM
				Property P
				INNER JOIN Dimension D ON D.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND D.Introduced < ''' + @Version + ''' AND D.SelectYN <> 0
				INNER JOIN DimensionType DT ON DT.DimensionTypeID = D.DimensionTypeID
				INNER JOIN (SELECT                  
								MD.ModelID,
								MD.DimensionID,
								MD.ModelBM,
								YN1.VisibilityLevelBM,
								YN1.MappingEnabledYN
							FROM
								#Model_Dimension MD,
								(           
								SELECT TOP 1 VisibilityLevelBM, MappingEnabledYN
								FROM  
									(SELECT SortOrder = 1, VisibilityLevelBM, MappingEnabledYN FROM #Model_Dimension WHERE ModelBM = ' + CONVERT(nvarchar(10), @ModelBM) + '
									UNION SELECT SortOrder = 2, VisibilityLevelBM = MAX(VisibilityLevelBM), MappingEnabledYN = MAX(CONVERT(int, MappingEnabledYN)) FROM #Model_Dimension) sub
								ORDER BY
									SortOrder
								) YN1
							) MD ON MD.VisibilityLevelBM & 9 > 0
				INNER JOIN ' + @ETLDatabase + '.dbo.MappedObject MO ON MO.Entity = ''-1'' AND MO.ObjectName = D.DimensionName AND MO.DimensionTypeID = D.DimensionTypeID AND ((MO.ObjectTypeBM & 2 > 0 AND MO.SelectYN <> 0) OR MD.VisibilityLevelBM & 8 > 0)
				LEFT JOIN SqlSource_Dimension SSD ON (SSD.DimensionID = P.DimensionID OR SSD.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ') AND SSD.PropertyID = P.PropertyID AND SSD.SourceTypeBM & ' + CONVERT(nvarchar(10), ISNULL(@SourceTypeBM, 2048)) + ' > 0 AND SSD.RevisionBM & ' + CONVERT(nvarchar(10), @RevisionBM) + ' > 0 AND SSD.ModelBM & ' + CONVERT(nvarchar(10), @ModelBM) + ' > 0 AND SSD.LinkedBM & ' + CONVERT(nvarchar(10), @LinkedBM) + ' > 0 AND SSD.SelectYN <> 0
				LEFT JOIN Dimension DD ON DD.DimensionID = P.DependentDimensionID AND DD.Introduced < ''' + @Version + ''' AND DD.SelectYN <> 0
				LEFT JOIN DimensionType DDT ON DDT.DimensionTypeID = DD.DimensionTypeID
				LEFT JOIN Model_Dimension DMD ON DMD.ModelID = ' + CONVERT(nvarchar(10), @BaseModelID) + ' AND DMD.DimensionID = P.DependentDimensionID AND DMD.VisibilityLevelBM & 9 > 0 AND DMD.Introduced < ''' + @Version + ''' AND DMD.SelectYN <> 0
				LEFT JOIN ' + @ETLDatabase + '.dbo.MappedObject DMO ON DMO.Entity = ''-1'' AND DMO.ObjectName = DD.DimensionName AND DMO.DimensionTypeID = DD.DimensionTypeID AND (DMO.ObjectTypeBM & 4 > 0 OR DMD.VisibilityLevelBM & 8 > 0)
				LEFT JOIN (SELECT DISTINCT
								MPV.PropertyID
							FROM
								Member M
								INNER JOIN Member_Property_Value MPV ON MPV.DimensionID = M.DimensionID AND MPV.MemberID = M.MemberID
							WHERE
								M.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND
								M.ModelBM & ' + CONVERT(nvarchar(10), @ModelBM) + ' > 0 AND
								M.SourceTypeBM & ' + CONVERT(nvarchar(10), ISNULL(@SourceTypeBM, 2048)) + ' > 0
							) MPV ON MPV.PropertyID = P.PropertyID
				LEFT JOIN SqlSource_Dimension SSD610 ON SSD610.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND SSD610.PropertyID = 610 AND SSD610.SourceTypeBM & ' + CONVERT(nvarchar(10), ISNULL(@SourceTypeBM, 2048)) + ' > 0 AND SSD610.RevisionBM & ' + CONVERT(nvarchar(10), @RevisionBM) + ' > 0 AND SSD610.ModelBM & ' + CONVERT(nvarchar(10), @ModelBM) + ' > 0 AND SSD610.LinkedBM & ' + CONVERT(nvarchar(10), @LinkedBM) + ' > 0 AND SSD610.SelectYN <> 0
				LEFT JOIN SqlSource_Dimension SSD620 ON SSD620.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND SSD620.PropertyID = 620 AND SSD620.SourceTypeBM & ' + CONVERT(nvarchar(10), ISNULL(@SourceTypeBM, 2048)) + ' > 0 AND SSD620.RevisionBM & ' + CONVERT(nvarchar(10), @RevisionBM) + ' > 0 AND SSD620.ModelBM & ' + CONVERT(nvarchar(10), @ModelBM) + ' > 0 AND SSD620.LinkedBM & ' + CONVERT(nvarchar(10), @LinkedBM) + ' > 0 AND SSD620.SelectYN <> 0

			WHERE
				P.DimensionID IN (0, ' + CONVERT(nvarchar(10), @DimensionID) + ') AND
				P.PropertyID NOT BETWEEN 100 AND 1000 AND P.PropertyID <> 12 AND
				P.SourceTypeBM & ' + CONVERT(nvarchar(10), @SourceTypeBM_All) + ' > 0 AND
				P.Introduced < ''' + @Version + ''' AND
				P.SelectYN <> 0 AND
				(DMO.ObjectName IS NULL OR (DMO.ObjectName IS NOT NULL AND DMO.SelectYN <> 0)) AND
				NOT EXISTS (SELECT 1 FROM Dimension DDD WHERE DDD.DimensionID = P.DependentDimensionID AND (DDD.Introduced >= ''' + @Version + ''' OR DDD.SelectYN = 0))'

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'INSERT INTO #DimensionProperty', [SQLStatement] = @SQLStatement

		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT TempTable = '#DimensionProperty', * FROM #DimensionProperty ORDER BY [SortOrder], [PropertyName]

	SET @Step = 'Set procedure variables from Temp table'
		SELECT @DimensionName = MAX(DimensionName) FROM #DimensionProperty
		
		IF @SlaveDimensionYN <> 0
			SET @EntityMappingYN = 0
		ELSE
			BEGIN
				CREATE TABLE #RowCount
					(
					TableName nvarchar(50),
					EntMapCount int
					)

				SET @SQLStatement = 'INSERT INTO #RowCount (TableName, EntMapCount) SELECT TableName = ''MappedLabel'', EntMapCount = COUNT(1) FROM ' + @ETLDatabase + '.dbo.MappedLabel WHERE MappedObjectName = ''' + @DimensionName + ''' AND MappingTypeID IN (1, 2)'
				EXEC (@SQLStatement)
				INSERT INTO #RowCount (TableName, EntMapCount) SELECT TableName = '#DimensionProperty', EntMapCount = COUNT(1) FROM #DimensionProperty WHERE PropertyID = 5 AND MappingTypeID IN (1, 2)

				IF @Debug <> 0 SELECT TempTable = '#RowCount', * FROM #RowCount

				IF (SELECT SUM(EntMapCount) FROM #RowCount) > 0
					SET @EntityMappingYN = 1
				ELSE
					SET @EntityMappingYN = 0
				
				DROP TABLE #RowCount
			END

		IF @Debug <> 0 SELECT DimensionName = @DimensionName, EntityMappingYN = @EntityMappingYN

	SET @Step = 'Create SQL variables on top level'

		SELECT
			PropertyName = DP.PropertyName,
			PropertyID = MAX(DP.PropertyID),
			SelectString = CASE MAX(DP.PropertyID) WHEN 3 THEN MAX('CASE [MaxRaw].[' + DP.PropertyName + '] WHEN ''NULL'' THEN NULL ELSE [MaxRaw].[' + DP.PropertyName + '] END') WHEN 8 THEN 'ISNULL([MaxRaw].[MemberId], M.MemberID)' WHEN 9 THEN 'CASE WHEN [MaxRaw].[HelpText] = '''' THEN [MaxRaw].[Description] ELSE [MaxRaw].[HelpText] END' ELSE MAX('[MaxRaw].[' + DP.PropertyName + ']') END,
			MaxRawSelectString = CASE WHEN [dbo].[GetDefaultPropertyYN] (MAX(DP.DimensionID), MAX(DP.PropertyID), @SourceTypeBM, @ModelBM) = 0 THEN 'MAX([Raw].[' + DP.PropertyName + '])' ELSE ISNULL(MAX(DP1.SourceString), 'MAX([Raw].[' + DP.PropertyName + '])') END,
			SubLevelYN = CASE WHEN MAX(DP.SourceString) IS NULL THEN 0 ELSE 1 END,
			SortOrder = MAX(DP.SortOrder),
			DataTypeID = MAX(DP.DataTypeID),
			SetDefaultPropertyYN = [dbo].[GetDefaultPropertyYN] (MAX(DP.DimensionID), MAX(DP.PropertyID), @SourceTypeBM, @ModelBM),
			DynamicYN = MAX(CONVERT(int, DP.DynamicYN)),
			DP1_SourceString = MAX(DP1.SourceString),
			DependentDimensionName = MAX(DP.DependentDimensionName)
		INTO
			#DimensionFieldList
		FROM
			#DimensionProperty DP
			LEFT JOIN #DimensionProperty DP1 ON DP1.PropertyName = DP.PropertyName AND DP1.SequenceBM = 0
		GROUP BY
			DP.PropertyName

		IF @Debug <> 0 SELECT TempTable = '#DimensionFieldList', * FROM #DimensionFieldList ORDER BY SortOrder, PropertyName

		SELECT 
			@SQLStatement_Select = ISNULL(@SQLStatement_Select, '') + CASE WHEN SubLevelYN = 0 THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + PropertyName + '] = ' + SelectString + CASE WHEN SortOrder = 80 THEN '' ELSE ',' END END + CASE WHEN DataTypeID = 3 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + '[' + PropertyName + '_MemberId] = ISNULL([' + PropertyName + '].[MemberId], -1),' ELSE '' END,
			@SQLStatement_MaxRawSelect = ISNULL(@SQLStatement_MaxRawSelect, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + PropertyName + '] = ' + CASE WHEN PropertyID = 5 THEN '[Raw].[' + PropertyName + ']' ELSE MaxRawSelectString END + CASE WHEN SortOrder = 80 THEN '' ELSE ',' END,
			@SQLStatement_DimJoin = ISNULL(@SQLStatement_DimJoin, '') + CASE WHEN DataTypeID = 3 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + 'LEFT JOIN [' + @DestinationDatabase + '].[dbo].[S_DS_' + DependentDimensionName + '] [' + PropertyName + '] ON [' + PropertyName + '].Label COLLATE DATABASE_DEFAULT = [MaxRaw].[' + PropertyName + ']' ELSE '' END
		FROM
			#DimensionFieldList
		ORDER BY
			[SortOrder],
			[PropertyName]

		IF @Debug <> 0 SELECT TempTable = '#DimensionFieldList', SQLStatement_Select = @SQLStatement_Select, * FROM #DimensionFieldList ORDER BY SortOrder, PropertyName

		SELECT
			@SQLStatement_Where = SSD.SourceString
		FROM
			pcINTEGRATOR.dbo.SqlSource_Dimension SSD
		WHERE
			SSD.DimensionID IN (@DimensionID) AND 
			SSD.SourceTypeBM & @SourceTypeBM > 0 AND
			SSD.RevisionBM & @RevisionBM > 0 AND
			SSD.ModelBM & @ModelBM > 0 AND
			SSD.LinkedBM & @LinkedBM > 0 AND
			SSD.PropertyID = 200 AND
			SSD.SequenceBM = 0 AND
			SSD.SelectYN <> 0

		SELECT @SQLStatement_Where = ISNULL(@SQLStatement_Where, CHAR(9) + CHAR(9) + '1 = 1')

	SET @Step = 'Create Entity Mapping'
		IF @EntityMappingYN <> 0
			BEGIN
				SELECT DISTINCT
					DP.PropertyName,
					[SourceString] = CASE DP.PropertyID WHEN 6 THEN '''P''' WHEN 5 THEN 'E.Entity' WHEN 4 THEN 'E.EntityName' ELSE P.DefaultValueView END ,
					DP.SortOrder
				INTO
					#EntityMapping
				FROM
					#DimensionProperty DP
					INNER JOIN Property P ON P.PropertyID = DP.PropertyID AND P.DimensionID = DP.DimensionID
				WHERE
					DP.SequenceBM > 0
				ORDER BY
					DP.[SortOrder],
					DP.[PropertyName]

				IF @Debug <> 0 SELECT TempTable = '#EntityMapping', * FROM #EntityMapping ORDER BY SortOrder

				SELECT 
					@SQLStatement_RawSelect_Entity = ISNULL(@SQLStatement_RawSelect_Entity, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' +  PropertyName + '] = ' +  [SourceString] + CASE WHEN SortOrder = 80 THEN '' ELSE ',' END
				FROM
					#EntityMapping
				ORDER BY
					[SortOrder],
					[PropertyName]

				SET @SQLStatement_RawSelect_Entity = '
			SELECT DISTINCT' + @SQLStatement_RawSelect_Entity + '
			FROM
				@ETLDatabase_Linked.[dbo].[Entity] E
			WHERE
				SourceID = @SourceID AND
				SelectYN <> 0
                                                
			UNION '
				DROP TABLE #EntityMapping
			END

	SET @Step = 'Create SQL variables on sub level'
		SET @SQLStatement_Sub = NULL
		SET @SequenceCounter = 1
		SET @SequenceBMStep = 1
		WHILE @SequenceBMSum & @SequenceBMStep > 0
			BEGIN
				IF @Debug <> 0 SELECT SequenceBMStep = @SequenceBMStep, TempTable = '#DimensionProperty', * FROM #DimensionProperty DP WHERE DP.SequenceBM & @SequenceBMStep > 0 ORDER BY DP.[SortOrder], DP.[PropertyName]

				SELECT 
					@SQLStatement_RawSelect = ISNULL(@SQLStatement_RawSelect, '') + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' +  DP.PropertyName + '] = ' + 
                                                             
						CASE WHEN DP.PropertyID = 3 AND @SequenceBMStep = 1 AND @EntityMappingYN <> 0 THEN 'E.Entity COLLATE DATABASE_DEFAULT ' ELSE 
							CASE WHEN DP.MappingEnabledYN = 0 OR DP.[SourceString] = '''NONE''' OR (DP.PropertyID NOT IN (5, 4, 3) AND DP.DependentDimensionName IS NULL) THEN 
								CASE WHEN DP.StringTypeBM <> 0 THEN '[dbo].[f_ReplaceText] (' + DP.[SourceString] + ', ' + CONVERT(nvarchar(10), DP.StringTypeBM) + ')' ELSE DP.[SourceString] END + CASE WHEN DP.DataTypeID IN (2, 3) THEN ' COLLATE DATABASE_DEFAULT' ELSE '' END
							ELSE 
								CASE WHEN DP.PropertyID IN (5, 3) THEN 
									'CASE WHEN ISNULL([ML_' + DP.DimensionName + '].MappingTypeID, ' + CONVERT(nvarchar(10), DP.MappingTypeID) + ') = 1 THEN E.Entity COLLATE DATABASE_DEFAULT + ''_'' ELSE '''' END + '
								ELSE 
									CASE WHEN DP.PropertyID NOT IN (4) THEN 'CASE WHEN ISNULL([ML_' + DP.DependentDimensionName + '_' + DP.PropertyName + '].MappingTypeID, ' + CONVERT(nvarchar(10), DP.MappingTypeID) + ') = 1 THEN E.Entity COLLATE DATABASE_DEFAULT + ''_'' ELSE '''' END + ' ELSE '' END
								END +
                                                                         
								'CASE WHEN [ML_' + CASE WHEN DP.PropertyID IN (5, 4, 3) THEN DP.DimensionName ELSE DP.DependentDimensionName + '_' + DP.PropertyName END + '].MappingTypeID = 3 THEN [ML_' + CASE WHEN DP.PropertyID IN (5, 4, 3) THEN DP.DimensionName ELSE DP.DependentDimensionName + '_' + DP.PropertyName END
								+ '].' + CASE WHEN DP.PropertyID = 4 THEN 'MappedDescription' ELSE 'MappedLabel' END + ' ELSE ' + CASE WHEN DP.StringTypeBM <> 0 THEN '[dbo].[f_ReplaceText] (' + DP.[SourceString] + ', ' + CONVERT(nvarchar(10), DP.StringTypeBM) + ')' ELSE DP.[SourceString] END + ' END' + CASE WHEN DP.DataTypeID IN (2, 3) THEN ' COLLATE DATABASE_DEFAULT' ELSE '' END +

								CASE WHEN DP.PropertyID IN (5, 3) THEN 
									' + CASE WHEN ISNULL([ML_' + DP.DimensionName + '].MappingTypeID, ' + CONVERT(nvarchar(10), DP.MappingTypeID) + ') = 2 THEN ''_'' + E.Entity COLLATE DATABASE_DEFAULT ELSE '''' END'
								ELSE 
									CASE WHEN DP.PropertyID NOT IN (4) THEN ' + CASE WHEN ISNULL([ML_' + DP.DependentDimensionName + '_' + DP.PropertyName + '].MappingTypeID, ' + CONVERT(nvarchar(10), DP.MappingTypeID) + ') = 2 THEN ''_'' + E.Entity COLLATE DATABASE_DEFAULT ELSE '''' END' ELSE '' END
								END
							END
						END 
						+ CASE WHEN DP.SortOrder = 80 THEN '' ELSE ',' END,

					@SQLStatement_MapJoin = ISNULL(@SQLStatement_MapJoin, '') + CASE WHEN DP.MappingEnabledYN = 0 OR DP.[SourceString] = '''NONE''' OR (DP.PropertyID <> 5 AND DP.DependentDimensionName IS NULL) THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LEFT JOIN ' + CASE WHEN @LinkedBM = 2 THEN @ETLDatabase_Linked + '.dbo.' ELSE '' END + 'MappedLabel [ML_' + CASE WHEN DP.PropertyID = 5 THEN DP.DimensionName ELSE DP.DependentDimensionName + '_' + DP.PropertyName END + '] ON [ML_' + CASE WHEN DP.PropertyID = 5 THEN DP.DimensionName ELSE DP.DependentDimensionName + '_' + DP.PropertyName END + '].Entity = E.Entity AND [ML_' + CASE WHEN DP.PropertyID = 5 THEN DP.DimensionName ELSE DP.DependentDimensionName + '_' + DP.PropertyName END + '].MappedObjectName = ''' + CASE WHEN DP.PropertyID = 5 THEN DP.DimensionName ELSE DP.DependentDimensionName + '_' + DP.PropertyName END + ''' AND ' + CASE WHEN DP.StringTypeBM <> 0 THEN '[dbo].[f_ReplaceText] (' + DP.[SourceString] + ', ' + CONVERT(nvarchar(10), DP.StringTypeBM) + ')' ELSE DP.[SourceString] END + ' COLLATE DATABASE_DEFAULT BETWEEN [ML_' + CASE WHEN DP.PropertyID = 5 THEN DP.DimensionName ELSE DP.DependentDimensionName + '_' + DP.PropertyName END + '].LabelFrom AND [ML_' + CASE WHEN DP.PropertyID = 5 THEN DP.DimensionName ELSE DP.DependentDimensionName + '_' + DP.PropertyName END + '].LabelTo AND [ML_' + CASE WHEN DP.PropertyID = 5 THEN DP.DimensionName ELSE DP.DependentDimensionName + '_' + DP.PropertyName END + '].SelectYN <> 0' END,
					@SQLStatement_GroupBy = ISNULL(@SQLStatement_GroupBy, '') + CASE WHEN DP.GroupByYN <> 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + DP.[SourceString] + ',' ELSE '' END
				FROM
					#DimensionProperty DP
				WHERE
					DP.SequenceBM & @SequenceBMStep > 0
				ORDER BY
					DP.[SortOrder],
					DP.[PropertyName]

				IF LEN(@SQLStatement_GroupBy) > 0
					SET @SQLStatement_GroupBy = SUBSTRING(@SQLStatement_GroupBy, 1, LEN(@SQLStatement_GroupBy) - 1)

				IF @Debug <> 0 
					BEGIN
						PRINT 'SequenceBMStep = ' + CONVERT(nvarchar(10), @SequenceBMStep)
						PRINT @SQLStatement_RawSelect
					END

				SELECT
					@SQLStatement_RawFrom = ISNULL(@SQLStatement_RawFrom, '') + CASE WHEN SSD.PropertyID = 100 THEN SSD.SourceString ELSE '' END,
					@SQLStatement_RawWhere = ISNULL(@SQLStatement_RawWhere, '') + CASE WHEN SSD.PropertyID = 200 THEN SSD.SourceString ELSE '' END,
					@SequenceDescription = ISNULL(@SequenceDescription, '') + CASE WHEN SSD.PropertyID = 500 THEN SSD.SourceString ELSE '' END
				FROM
					pcINTEGRATOR.dbo.SqlSource_Dimension SSD
				WHERE
					SSD.SequenceBM & @SequenceBMStep > 0 AND
					SSD.DimensionID = @DimensionID AND 
					SSD.SourceTypeBM & @SourceTypeBM > 0 AND
					SSD.RevisionBM & @RevisionBM > 0 AND
					SSD.ModelBM & @ModelBM > 0 AND
					SSD.LinkedBM & @LinkedBM > 0 AND
					SSD.PropertyID IN (100, 200, 500) AND
					SSD.SelectYN <> 0

				IF @SQLStatement_RawWhere = '' SET @SQLStatement_RawWhere = CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '1 = 1'

	SET @Step = 'Set Entity priority order'
				IF @GenericYN = 0 AND @MappingEnabledYN = 1 AND @SequenceBMStep & @SequenceBMLeafLevel > 0 AND @SourceDBTypeID = 1 AND @MappingTypeID NOT IN (1, 2) AND @SlaveDimensionYN = 0
					BEGIN
						SELECT @SQLStatement_Label = ISNULL(@SQLStatement_Label, '') + 
							CASE WHEN DP.MappingEnabledYN = 0 OR DP.[SourceString] = '''NONE''' THEN
								CASE WHEN DP.StringTypeBM <> 0 THEN '[dbo].[f_ReplaceText] (' + DP.[SourceString] + ', ' + CONVERT(nvarchar(10), DP.StringTypeBM) + ')' ELSE DP.[SourceString] END
							ELSE
								'CASE WHEN ISNULL([ML_' + DP.DimensionName + '].MappingTypeID, ' + CONVERT(nvarchar(10), DP.MappingTypeID) + ') = 1 THEN E.Entity COLLATE DATABASE_DEFAULT + ''_'' ELSE '''' END + ' +
                                                                                                              
								'CASE WHEN [ML_' + DP.DimensionName + '].MappingTypeID = 3 THEN [ML_' + DP.DimensionName + '].MappedLabel ELSE ' + 
									CASE WHEN DP.StringTypeBM <> 0 THEN '[dbo].[f_ReplaceText] (' + DP.[SourceString] + ', ' + CONVERT(nvarchar(10), DP.StringTypeBM) + ')' 
									ELSE DP.[SourceString] END + 
									CASE WHEN DP.DataTypeID IN (2, 3) THEN ' COLLATE DATABASE_DEFAULT' ELSE '' END + ' END + ' +
                                                                                                              
								'CASE WHEN ISNULL([ML_' + DP.DimensionName + '].MappingTypeID, ' + CONVERT(nvarchar(10), DP.MappingTypeID) + ') = 2 THEN ''_'' + E.Entity COLLATE DATABASE_DEFAULT ELSE '''' END'
							END +

							CASE WHEN DP.DataTypeID IN (2, 3) THEN ' COLLATE DATABASE_DEFAULT' ELSE '' END
						FROM
							#DimensionProperty DP
						WHERE
							DP.PropertyID = 5 AND
							DP.SequenceBM & @SequenceBMStep > 0
						ORDER BY
							DP.[SortOrder],
							DP.[PropertyName]
/*
						SET @SQLStatement_Prio = '
						INNER JOIN
						(
							SELECT
								[Label] = ' + @SQLStatement_Label + ',
								[EntityPriority] = MIN(ISNULL(E.EntityPriority, 99999999))
							FROM' + CHAR(13) + CHAR(10) + REPLACE(@SQLStatement_RawFrom + @SQLStatement_MapJoin, CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9), CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)) + '
							GROUP BY
								' + @SQLStatement_Label + '
						) PRIO ON PRIO.Label = ' + @SQLStatement_Label + ' AND PRIO.[EntityPriority] = ISNULL(E.EntityPriority, 99999999)'
*/

						SET @SQLStatement_Prio = '
							INSERT INTO ' + @ETLDatabase + ' .[dbo].[wrk_EntityPriority_Member]
								(
								[DimensionID],
								[SourceID],
								[SequenceBM],
								[Label],
								[EntityPriority]
								)
							SELECT
								[DimensionID] = ' + CONVERT(nvarchar(10), @DimensionID) + ',
								[SourceID] = ' + CONVERT(nvarchar(10), @SourceID) + ',
								[SequenceBM] = ' + CONVERT(nvarchar(10), @SequenceBMStep) + ',
								[Label] = ' + @SQLStatement_Label + ',
								[EntityPriority] = MIN(ISNULL(E.EntityPriority, 99999999))
							FROM' + CHAR(13) + CHAR(10) + REPLACE(@SQLStatement_RawFrom + @SQLStatement_MapJoin, CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9), CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)) + '
							GROUP BY
								' + @SQLStatement_Label

						EXEC pcINTEGRATOR..spReplace_CodeWord @ApplicationID = @ApplicationID, @ObjectTypeBM = 7, @TranslatedLanguageID = @LanguageID, @StringIn = @SQLStatement_Prio, @StringOut = @SQLStatement_Prio OUTPUT
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@SourceDatabase', ISNULL(@SourceDatabase, ''))
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@Owner', ISNULL(@Owner, ''))
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@DestinationDatabase', @DestinationDatabase)
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@ETLDatabase_Linked', ISNULL(@ETLDatabase_Linked, @ETLDatabase))
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@SourceType', ISNULL(@SourceType, ''))
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@SourceID_varchar', @SourceID_varchar)
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@SourceID', @SourceID)
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@DimensionID', @DimensionID)
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@InstanceID', @InstanceID)
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@VersionID', @VersionID)
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@ApplicationID', @ApplicationID)
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@DefaultCurrency', @DefaultCurrency)
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '@StartYear', ISNULL(CONVERT(nvarchar(10), @StartYear), ''))
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, '''', '''''')
						SET @SQLStatement_Prio = REPLACE(@SQLStatement_Prio, 'COLLATE DATABASE_DEFAULT COLLATE DATABASE_DEFAULT', 'COLLATE DATABASE_DEFAULT')

						IF @Debug <> 0 
							SELECT
								DimensionID = @DimensionID,
								SourceID = @SourceID,
								SequenceBM = @SequenceBMStep,
								SQLStatement = @SQLStatement_Prio

						SET @SQLStatement = '
				DELETE ' + @ETLDatabase + ' .[dbo].[wrk_EntityPriority_SQLStatement]
				WHERE 
					[DimensionID] = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND
					[SourceID] = ' + CONVERT(nvarchar(10), @SourceID) + ' AND
					[SequenceBM] = ' + CONVERT(nvarchar(10), @SequenceBMStep) + '

				INSERT INTO ' + @ETLDatabase + ' .[dbo].[wrk_EntityPriority_SQLStatement]
					(
					[DimensionID],
					[SourceID],
					[SequenceBM],
					[SQLStatement]
					)
				SELECT
					[DimensionID] = ' + CONVERT(nvarchar(10), @DimensionID) + ',
					[SourceID] = ' + CONVERT(nvarchar(10), @SourceID) + ',
					[SequenceBM] = ' + CONVERT(nvarchar(10), @SequenceBMStep) + ',
					[SQLStatement] = ''' + @SQLStatement_Prio + ''''
							
						IF @Debug <> 0 PRINT @SQLStatement

						EXEC (@SQLStatement)

						SET @SQLStatement_Prio = '
				INNER JOIN ' + @ETLDatabase + '.[dbo].[wrk_EntityPriority_Member] PRIO ON PRIO.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND PRIO.[SourceID] = ' + CONVERT(nvarchar(10), @SourceID) + ' AND PRIO.[SequenceBM] = ' + CONVERT(nvarchar(10), @SequenceBMStep) + ' AND PRIO.Label = ' + @SQLStatement_Label + ' AND PRIO.[EntityPriority] = ISNULL(E.EntityPriority, 99999999)'

					END
				ELSE
					SET @SQLStatement_Prio = ''

	SET @Step = 'Set @SQLStatement_Sub'
				SET @SQLStatement_Sub = ISNULL(@SQLStatement_Sub, '') + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 
					'--@SequenceCounter = ' + CONVERT(nvarchar(10), @SequenceCounter) + ', @SequenceBMStep = ' + CONVERT(nvarchar(10), @SequenceBMStep) + CHAR(13) + CHAR(10) +
					'--Sequence Description = ' + @SequenceDescription +
					CASE WHEN @SequenceCounter = 1 THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 'UNION ' END + '

			SELECT DISTINCT'
				+ @SQLStatement_RawSelect + '
			FROM
'				+ @SQLStatement_RawFrom +
				+ @SQLStatement_MapJoin + 
				+ @SQLStatement_Prio + '
			WHERE
'				+ @SQLStatement_RawWhere + CASE WHEN LEN(@SQLStatement_GroupBy) > 0 THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 'GROUP BY' + @SQLStatement_GroupBy ELSE '' END

				SELECT
					@SQLStatement_RawSelect = NULL,
					@SQLStatement_RawFrom = NULL,
					@SQLStatement_MapJoin = NULL,
					@SQLStatement_RawWhere = NULL,
					@SQLStatement_Label = NULL,
					@SQLStatement_Prio = NULL,
					@SequenceDescription = NULL

				SELECT @SequenceCounter = @SequenceCounter + 1
				SELECT @SequenceBMStep = @SequenceBMStep + @SequenceBMStep
                                                
			END --End of Sequence loop

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = 'Sub part of View Raw', [SQLStatement] = @SQLStatement

	SET @Step = 'Get default members'
		IF @Debug <> 0 SELECT SourceID = @SourceID, DimensionID = @DimensionID, SQLStatementMember = @SQLStatement_Member

		EXEC spGet_Member @SourceID = @SourceID, @DimensionID = @DimensionID, 
						@SQLStatement3_01 = @SQLStatement3_01 OUT, @SQLStatement3_02 = @SQLStatement3_02 OUT, @SQLStatement3_03 = @SQLStatement3_03 OUT, @SQLStatement3_04 = @SQLStatement3_04 OUT, @SQLStatement3_05 = @SQLStatement3_05 OUT,
						@SQLStatement3_06 = @SQLStatement3_06 OUT, @SQLStatement3_07 = @SQLStatement3_07 OUT, @SQLStatement3_08 = @SQLStatement3_08 OUT, @SQLStatement3_09 = @SQLStatement3_09 OUT, @SQLStatement3_10 = @SQLStatement3_10 OUT,
						@SQLStatement3_11 = @SQLStatement3_11 OUT, @SQLStatement3_12 = @SQLStatement3_12 OUT, @SQLStatement3_13 = @SQLStatement3_13 OUT, @SQLStatement3_14 = @SQLStatement3_14 OUT, @SQLStatement3_15 = @SQLStatement3_15 OUT,
						@SQLStatement3_16 = @SQLStatement3_16 OUT, @SQLStatement3_17 = @SQLStatement3_17 OUT, @SQLStatement3_18 = @SQLStatement3_18 OUT, @SQLStatement3_19 = @SQLStatement3_19 OUT, @SQLStatement3_20 = @SQLStatement3_20 OUT

		SET @SQLStatement_Member =	@SQLStatement3_01 + @SQLStatement3_02 + @SQLStatement3_03 + @SQLStatement3_04 + @SQLStatement3_05 + @SQLStatement3_06 + @SQLStatement3_07 + @SQLStatement3_08 + @SQLStatement3_09 + @SQLStatement3_10 + 
									@SQLStatement3_11 + @SQLStatement3_12 + @SQLStatement3_13 + @SQLStatement3_14 + @SQLStatement3_15 + @SQLStatement3_16 + @SQLStatement3_17 + @SQLStatement3_18 + @SQLStatement3_19 + @SQLStatement3_20

		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = '@SQLStatement3_15', [SQLStatement] = @SQLStatement3_15
		IF @Debug <> 0 INSERT INTO wrk_Debug ([ProcedureName], [Comment], [SQLStatement]) SELECT [ProcedureName] = OBJECT_NAME(@@PROCID), [Comment] = '@SQLStatement_Member', [SQLStatement] = @SQLStatement_Member
		IF @Debug <> 0 SELECT SourceID = @SourceID, DimensionID = @DimensionID, SQLStatementMember = @SQLStatement_Member

	SET @Step = 'Create SQL Statement'
		IF @SQLStatement_Sub IS NOT NULL AND @SQLStatement_Member IS NOT NULL
			SET @Union = CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + '--Sequence Description = Static rows' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + 'UNION '
		ELSE
			SET @Union = ''

		IF @Debug <> 0
			SELECT
				SQLStatement_Select = @SQLStatement_Select,
				SQLStatement_MaxRawSelect = @SQLStatement_MaxRawSelect,
				SQLStatement_RawSelect_Entity = @SQLStatement_RawSelect_Entity,
				SQLStatement = @SQLStatement,
				SQLStatement_Member = @SQLStatement_Member,
				SQLStatement_DimJoin = @SQLStatement_DimJoin


				SET @SQLStatement1 = '
	SELECT TOP @RowsToInsert' + @SQLStatement_Select + '
	FROM
		(
		SELECT' + @SQLStatement_MaxRawSelect + '
		FROM
			(' + ISNULL(@SQLStatement_RawSelect_Entity, '')

						SET @SQLStatement4 = '
			) [Raw]
		GROUP BY
			[Raw].[Label]
		) [MaxRaw]
		LEFT JOIN pcINTEGRATOR..Member M ON M.DimensionID = ' + CONVERT(nvarchar(10), @DimensionID) + ' AND M.Label = [MaxRaw].Label' + @SQLStatement_DimJoin + '
	WHERE
		[MaxRaw].[Label] IS NOT NULL
	ORDER BY
		CASE WHEN [MaxRaw].[Label] IN (''All_'', ''NONE'', ''pcPlaceHolder'') OR [MaxRaw].[Label] LIKE ''%NONE%'' THEN ''  '' + [MaxRaw].[Label] ELSE [MaxRaw].[Label] END'

				SET @CharCounter = LEN(@SQLStatement_Sub)
				SET @CharCounterResidual = @CharCounter
                                                
				WHILE @CharCounterResidual > 0
					BEGIN
						SET @Counter = @Counter + 1
						SET @CharCounterResidual = @CharCounter - ((@Counter - 1) * 4000)

						IF @CharCounterResidual > 0
						BEGIN
							IF @Counter = 1
								SET @SQLStatement2_01 = SUBSTRING(@SQLStatement_Sub, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END)
							ELSE IF @Counter = 2
								SET @SQLStatement2_02 = SUBSTRING(@SQLStatement_Sub, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END)
							ELSE IF @Counter = 3
								SET @SQLStatement2_03 = SUBSTRING(@SQLStatement_Sub, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END)
							ELSE IF @Counter = 4
								SET @SQLStatement2_04 = SUBSTRING(@SQLStatement_Sub, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END)
							ELSE IF @Counter = 5
								SET @SQLStatement2_05 = SUBSTRING(@SQLStatement_Sub, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END)
							ELSE IF @Counter = 6
								SET @SQLStatement2_06 = SUBSTRING(@SQLStatement_Sub, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END)
							ELSE IF @Counter = 7
								SET @SQLStatement2_07 = SUBSTRING(@SQLStatement_Sub, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END)
							ELSE IF @Counter = 8
								SET @SQLStatement2_08 = SUBSTRING(@SQLStatement_Sub, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END)
							ELSE IF @Counter = 9
								SET @SQLStatement2_09 = SUBSTRING(@SQLStatement_Sub, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END)
							ELSE IF @Counter = 10
								SET @SQLStatement2_10 = SUBSTRING(@SQLStatement_Sub, (@Counter - 1) * 4000 + 1, CASE WHEN @CharCounterResidual < 4000 THEN @CharCounterResidual ELSE 4000 END)
						END
					END

				IF @Debug <> 0
					BEGIN
						PRINT '@SQLStatement1' PRINT @SQLStatement1
						PRINT '@SQLStatement2_01' PRINT @SQLStatement2_01
						PRINT '@SQLStatement2_02' PRINT @SQLStatement2_02
						PRINT '@SQLStatement2_03' PRINT @SQLStatement2_03
						PRINT '@SQLStatement2_04' PRINT @SQLStatement2_04
						PRINT '@SQLStatement2_05' PRINT @SQLStatement2_05
						PRINT '@SQLStatement2_06' PRINT @SQLStatement2_06
						PRINT '@SQLStatement2_07' PRINT @SQLStatement2_07
						PRINT '@SQLStatement2_08' PRINT @SQLStatement2_08
						PRINT '@SQLStatement2_09' PRINT @SQLStatement2_09
						PRINT '@SQLStatement2_10' PRINT @SQLStatement2_10
						PRINT '@SQLStatement3_01' PRINT @SQLStatement3_01
						PRINT '@SQLStatement3_02' PRINT @SQLStatement3_02
						PRINT '@SQLStatement3_03' PRINT @SQLStatement3_03
						PRINT '@SQLStatement3_04' PRINT @SQLStatement3_04
						PRINT '@SQLStatement3_05' PRINT @SQLStatement3_05
						PRINT '@SQLStatement3_06' PRINT @SQLStatement3_06
						PRINT '@SQLStatement3_07' PRINT @SQLStatement3_07
						PRINT '@SQLStatement3_08' PRINT @SQLStatement3_08
						PRINT '@SQLStatement3_09' PRINT @SQLStatement3_09
						PRINT '@SQLStatement3_10' PRINT @SQLStatement3_10
						PRINT '@SQLStatement3_11' PRINT @SQLStatement3_11
						PRINT '@SQLStatement3_12' PRINT @SQLStatement3_12
						PRINT '@SQLStatement3_13' PRINT @SQLStatement3_13
						PRINT '@SQLStatement3_14' PRINT @SQLStatement3_14
						PRINT '@SQLStatement3_15' PRINT @SQLStatement3_15
						PRINT '@SQLStatement3_16' PRINT @SQLStatement3_16
						PRINT '@SQLStatement3_17' PRINT @SQLStatement3_17
						PRINT '@SQLStatement3_18' PRINT @SQLStatement3_18
						PRINT '@SQLStatement3_19' PRINT @SQLStatement3_19
						PRINT '@SQLStatement3_20' PRINT @SQLStatement3_20
						PRINT '@SQLStatement4' PRINT @SQLStatement4
					END

				EXEC [spCreate_Dimension_Procedure_Generic_Raw_2_SourceDBType]
					@SourceID = @SourceID,
					@DimensionID = @DimensionID,
					@SQLStatement1 = @SQLStatement1,
					@SQLStatement2_01 = @SQLStatement2_01,
					@SQLStatement2_02 = @SQLStatement2_02,
					@SQLStatement2_03 = @SQLStatement2_03,
					@SQLStatement2_04 = @SQLStatement2_04,
					@SQLStatement2_05 = @SQLStatement2_05,
					@SQLStatement2_06 = @SQLStatement2_06,
					@SQLStatement2_07 = @SQLStatement2_07,
					@SQLStatement2_08 = @SQLStatement2_08,
					@SQLStatement2_09 = @SQLStatement2_09,
					@SQLStatement2_10 = @SQLStatement2_10,
					@Union = @Union,
					@SQLStatement3_01 = @SQLStatement3_01,
					@SQLStatement3_02 = @SQLStatement3_02,
					@SQLStatement3_03 = @SQLStatement3_03,
					@SQLStatement3_04 = @SQLStatement3_04,
					@SQLStatement3_05 = @SQLStatement3_05,
					@SQLStatement3_06 = @SQLStatement3_06,
					@SQLStatement3_07 = @SQLStatement3_07,
					@SQLStatement3_08 = @SQLStatement3_08,
					@SQLStatement3_09 = @SQLStatement3_09,
					@SQLStatement3_10 = @SQLStatement3_10,
					@SQLStatement3_11 = @SQLStatement3_11,
					@SQLStatement3_12 = @SQLStatement3_12,
					@SQLStatement3_13 = @SQLStatement3_13,
					@SQLStatement3_14 = @SQLStatement3_14,
					@SQLStatement3_15 = @SQLStatement3_15,
					@SQLStatement3_16 = @SQLStatement3_16,
					@SQLStatement3_17 = @SQLStatement3_17,
					@SQLStatement3_18 = @SQLStatement3_18,
					@SQLStatement3_19 = @SQLStatement3_19,
					@SQLStatement3_20 = @SQLStatement3_20,
					@SQLStatement4 = @SQLStatement4,
					@Debug = @Debug,
					@JobID = @JobID,
					@Encryption = @Encryption,
					@Duration = @Duration,
					@Deleted = @Deleted,
					@Inserted = @Inserted,
					@Updated = @Updated


	SET @Step = 'Drop Temp tables'      
		DROP TABLE #DimensionProperty
		DROP TABLE #DimensionFieldList
		DROP TABLE #Model_Dimension

	SET @Step = 'Set @Duration'         
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ' (' + ISNULL(@ObjectName, '') + ')', @Duration, @Deleted, @Inserted, @Updated, @Version
		RETURN 0
END TRY

BEGIN CATCH
	INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID) + ' (' + ISNULL(@ObjectName, '') + ')', GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
	SET @JobLogID = @@IDENTITY
	SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
	SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
	RETURN @ErrorNumber
END CATCH






GO
