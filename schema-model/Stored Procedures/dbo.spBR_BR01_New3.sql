SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spBR_BR01_New3]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	@EventTypeID INT = NULL,
	@BusinessRuleID INT = NULL,
	@FromTime INT = NULL,
	@ToTime INT = NULL,
	@CallistoRefreshYN BIT = 1,
	@CallistoRefreshAsynchronousYN BIT = 1,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000360,
	@StartTime DATETIME = NULL,
	@Duration TIME(7) = '00:00:00' OUT,
	@Deleted INT = 0 OUT,
	@Inserted INT = 0 OUT,
	@Updated INT = 0 OUT,
	@Selected INT = 0 OUT,
	@GetVersion BIT = 0,
	@Debug BIT = 0, --1=Set @DebugBM to 3
	@DebugBM INT = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [pcINTEGRATOR].[dbo].[spBR_BR01] @BusinessRuleID='2836',@FromTime='202101',@InstanceID='515',@ToTime='202101',@UserID='-10',@VersionID='1064',@DebugBM=15
EXEC [pcINTEGRATOR].[dbo].[spBR_BR01] @BusinessRuleID='2635',@FromTime='202112',@InstanceID='582',@ToTime='202112',@UserID='9899',@VersionID='1082',@DebugBM=15

EXEC [pcINTEGRATOR].[dbo].[spBR_BR01] @BusinessRuleID='2630',@FromTime='202112',@InstanceID='582',@ToTime='202112',@UserID='9899',@VersionID='1082',@DebugBM=15

EXEC [pcINTEGRATOR].[dbo].[spBR_BR01] @BusinessRuleID='14644',@CallistoRefreshAsynchronousYN='1',@CallistoRefreshYN='1',@EventTypeID='-10',@FromTime='',@InstanceID='-1590',@ToTime='',@UserID='-10',@VersionID='-1590',@DebugBM=3

EXEC [spRun_Procedure_KeyValuePair] 
@JSON='[{"TKey":"Debug","TValue":"1"},
{"TKey":"InstanceID","TValue":"424"},
{"TKey":"ToTime","TValue":"201912"},
{"TKey":"UserID","TValue":"6520"},
{"TKey":"BusinessRuleID","TValue":"1002"},
{"TKey":"VersionID","TValue":"1017"},
{"TKey":"FromTime","TValue":"201901"}]',
 @ProcedureName='spBR_BR01'

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spBR_BR01',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

		CLOSE BR01_Initial_Cursor
		DEALLOCATE BR01_Initial_Cursor

		CLOSE MemberKey_Cursor
		DEALLOCATE MemberKey_Cursor

		CLOSE BR01_Destination_Cursor
		DEALLOCATE BR01_Destination_Cursor

EXEC spBR_BR01 @BusinessRuleID='2008',@FromTime='202004',@InstanceID='424',@ToTime='202004',@UserID='2147',@VersionID='1017', @DebugBM=3
EXEC spBR_BR01 @BusinessRuleID='2008',@FromTime='202004',@InstanceID='424',@ToTime='202004',@UserID='2147',@VersionID='1017', @DebugBM=3

EXEC spBR_BR01 @BusinessRuleID='1030',@FromTime='202004',@InstanceID='413',@ToTime='202004',@UserID='2147',@VersionID='1008', @DebugBM=3
EXEC [spBR_BR01] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleID = 1002, @FromTime = 201901, @ToTime = 201903, @Debug=1
EXEC [spBR_BR01] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleID = 1002, @FromTime = 201901, @ToTime = 201903, @Debug=1
EXEC [spBR_BR01] @UserID=-10, @InstanceID=424, @VersionID=1017, @BusinessRuleID = 1006, @FromTime = 201901, @ToTime = 201901, @Debug=1
EXEC [spBR_BR01] @UserID=-10, @InstanceID=-1001, @VersionID=-1001, @BusinessRuleID = 1043, @FromTime = 201901, @ToTime = 201904, @Debug=1

EXEC [spBR_BR01] @UserID=-10, @InstanceID=413, @VersionID=1008, @BusinessRuleID = 1031, @FromTime = 202004, @ToTime = 202004, @Debug=1


EXEC [pcINTEGRATOR].[dbo].[spBR_BR01] @BusinessRuleID='2480',@CallistoRefreshAsynchronousYN='1',@CallistoRefreshYN='1',@EventTypeID='-10',@FromTime='',@InstanceID='561',@JobID='2',@ToTime='',@UserID='-10',@VersionID='1071',@DebugBM=7


EXEC [spBR_BR01] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
--@segaRows BIGINT,
	@InitialStepID [INT], 
	@InitialStepID_Compare INT,
	@MemberKey [NVARCHAR](100),
	@MemberID BIGINT,
	@DestinationMemberKey [NVARCHAR](100),
	@DestinationMemberID BIGINT,
	@MasterMemberKey [NVARCHAR](100),
	@MasterMemberID BIGINT,
	@ModifierID [INT],
	@Parameter [FLOAT],
	@MasterDataClassID [INT],
	@DataClassID [INT],
	@MasterDataClassName NVARCHAR(100),
	@DataClassName NVARCHAR(100),
	@DataClassDatabase [NVARCHAR](100),
	@BaseObject [NVARCHAR](100),
	@DimensionSetting [NVARCHAR](4000),
	@DimensionFilter [NVARCHAR](4000),
	@DimensionFilterStep [NVARCHAR](4000),
	@BR01_StepID INT,
	@Decimal INT,
	@BR01_StepPartID INT,
	@Operator NCHAR(1),
	@DimensionFilterLeafLevel NVARCHAR(MAX) = '',
	@LeafLevelFilter NVARCHAR(MAX),
	@SQLStatement NVARCHAR(MAX),
	@SQL_Insert NVARCHAR(4000),
	@SQL_Insert_Right NVARCHAR(4000),
	@SQL_Select NVARCHAR(4000),
	@SQL_Select_70 NVARCHAR(4000),
	@SQL_Select_MV_70 NVARCHAR(4000),
	@SQL_Select_Multiply_Master NVARCHAR(4000),
	@SQL_Select_Addition_Master NVARCHAR(4000),
	@SQL_Select_Multiply NVARCHAR(4000),
	@SQL_Select_Addition NVARCHAR(4000),
	@SQL_Select_Addition_Right NVARCHAR(4000),
	@SQL_Join NVARCHAR(MAX),
	@SQL_Join_Delete NVARCHAR(MAX),
	@SQL_Join_Multiply NVARCHAR(MAX),
	@SQL_Join_Addition1 NVARCHAR(MAX),
	@SQL_Join_Addition2 NVARCHAR(MAX),
	@SQL_Join_CM_70 NVARCHAR(MAX),
	@SQL_Join_PM_70 NVARCHAR(MAX),
	@SQL_Where NVARCHAR(MAX),
	@SQL_GroupBy NVARCHAR(4000),
	@PreExec NVARCHAR(100),
	@PostExec NVARCHAR(100),
	@ColumnName NVARCHAR(100),
	@DataType NVARCHAR(20),
	@Variable_Value FLOAT,
	@DimensionName NVARCHAR(100),
	@HierarchyName NVARCHAR(100),
	@Filter NVARCHAR(MAX),
	@PipeString NVARCHAR(MAX),
	@Comment NVARCHAR(255),
	@MultiplyWith FLOAT,
	@StepReference NVARCHAR(20), 

	@Step NVARCHAR(255),
	@Message NVARCHAR(500) = '',
	@Severity INT = 0,
	@UserName NVARCHAR(100),
	@ProcedureName NVARCHAR(100),
	@DebugSub BIT = 0,
	@ErrorNumber INT = 0,
	@ErrorSeverity INT,
	@ErrorState INT,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2187'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Running business rule BR01.',
			@MandatoryParameter = 'FromTime|ToTime' --Without @, separated by |

		IF @Version = '2.0.0.2142' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Changed BR01_ID to BusinessRuleID.'
		IF @Version = '2.0.2.2145' SET @Description = 'Change to a generic version.'
		IF @Version = '2.0.2.2146' SET @Description = 'Split some querystrings that are > 4000 characters. Improved debugging. Automatic refresh cube when done. Adding more Modifiers (40, 45, 80, 85 and 90)'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-165: Removed DROP TABLE #Time'
		IF @Version = '2.0.2.2149' SET @Description = 'Default parameter for Modifier = 70 set to -1. Added handling of multiple dataclasses.'
		IF @Version = '2.0.3.2151' SET @Description = 'Enhanced debugging.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-344: Filter on Static setting when clean DataClass table before insert.'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-344: Bugfix for missing join back to FACT table.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-458: Join error in second loop for multiply fixed. DB-454: MultiplyWith implemented. Added column [DimensionID] to temp table #FilterTable. Handle WorkflowState.'
		IF @Version = '2.1.0.2155' SET @Description = 'DB-461: Listen to master filter for secondary dataclasses. Added @EventTypeID parameter. DB-492: Modified @SQL_Join string; replaced MemberKey with Label.'
		IF @Version = '2.1.0.2157' SET @Description = 'DB-518: Removed Step = Remove references to WorkflowState.'
		IF @Version = '2.1.0.2158' SET @Description = 'Added table reference in where clauses.'
		IF @Version = '2.1.0.2162' SET @Description = 'Check DataClass in NOT EXISTS where clause when add rows to cursor table. Test on [LeafLevelFilter] = '' when creating WHERE-clause. Exclude use of variable @DimensionFilterLeafLevel. Change DataClass check on Initial cursor table. Test on DataType = float in #DataClassList to find measures.'
		IF @Version = '2.1.0.2164' SET @Description = 'Exclude join with WorkflowState when delete old rows before insert new rows.'
		IF @Version = '2.1.1.2170' SET @Description = 'Codepart in Destination_Cursor that exceeded 4000 characters splitted into two.'
		IF @Version = '2.1.1.2173' SET @Description = 'Updated version of temp table #FilterTable. Post @JobID to exec [spRun_Job_Callisto_Generic].'
		IF @Version = '2.1.1.2174' SET @Description = 'Added parameters @CallistoRefreshYN and @CallistoRefreshAsynchronousYN defaulted to 1.'
		IF @Version = '2.1.1.2175' SET @Description = 'Added #FilterTableSmall and "EXISTS" instead of "IN". There was deadlock on a lot of values in "IN" clause'
		IF @Version = '2.1.1.2179' SET @Description = 'Added propertyfilter to Modifier 70 (Movement).'
		IF @Version = '2.1.2.2180' SET @Description = 'Based on Fact table instead on FactView'
		IF @Version = '2.1.2.2184' SET @Description = 'Added missing EXEC(@SQLStatement) when inserting into #BR01_FACT with data from #BR01_FACT_Step.'
		IF @Version = '2.1.2.2187' SET @Description = 'Handle Property filter.'

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
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

--		SET @BusinessRuleID = ISNULL(@BusinessRuleID, @BR_ID)

		SELECT
			@PreExec = PreExec,
			@PostExec = PostExec,
			@MasterDataClassID = DataClassID,
			@BaseObject = BaseObject,
			@DimensionSetting = DimensionSetting,
			@DimensionFilter = ISNULL(DimensionFilter, '')
--			@DimensionFilter = ISNULL(DimensionFilter, DimensionSetting)
		FROM
			pcINTEGRATOR..BR01_Master
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			BusinessRuleID = @BusinessRuleID

		SELECT
			@MasterDataClassName = DataClassName
		FROM
			pcINTEGRATOR_Data.dbo.DataClass
		WHERE
			DataClassID = @MasterDataClassID

		SELECT
			@DataClassDatabase = DestinationDatabase
		FROM
			pcINTEGRATOR_Data.dbo.[Application]
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID

		IF @DebugBM & 2 > 0 
			SELECT
				[@PreExec] = @PreExec,
				[@PostExec] = @PostExec,
				[@MasterDataClassID] = @MasterDataClassID,
				[@MasterDataClassName] = @MasterDataClassName,
				[@DataClassDatabase] = @DataClassDatabase,
				[@BaseObject] = @BaseObject,
				[@DimensionSetting] = @DimensionSetting,
				[@DimensionFilter] = @DimensionFilter

	SET @Step = 'Run PreExec'
		--Add security check (Correct InstanceID)
--		IF @PreExec IS NOT NULL
--			EXEC (@PreExec)

	SET @Step = 'Create temp table #DataClass'
		CREATE TABLE #DataClass
			(
			[DataClassID] int,
			)

		INSERT INTO #DataClass
			(
			[DataClassID]
			)
		SELECT
			[DataClassID] = @MasterDataClassID

		INSERT INTO #DataClass
			(
			[DataClassID]
			)
		SELECT DISTINCT
			[DataClassID] = BRS.[DataClassID]
		FROM
			[BR01_Step] BRS
		WHERE
			BRS.InstanceID = @InstanceID AND
			BRS.VersionID = @VersionID AND
			BRS.BusinessRuleID = @BusinessRuleID AND
			BRS.[DataClassID] IS NOT NULL AND
			NOT EXISTS (SELECT 1 FROM #DataClass DC WHERE DC.DataClassID = BRS.[DataClassID])

	SET @Step = 'Create temp table #PipeStringSplit and related tables'
		CREATE TABLE #PipeStringSplit
			(
			[TupleNo] int,
			[PipeObject] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
 			[PipeFilter] nvarchar(max) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #DimensionSetting
			(
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[StaticSetting] nvarchar(max) COLLATE DATABASE_DEFAULT
			)

		CREATE TABLE #FilterTable
			(
			[StepReference] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[TupleNo] int,
			[DimensionID] int,
			[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[DimensionTypeID] int,
			[StorageTypeBM] int,
			[SortOrder] int,
			[ObjectReference] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[HierarchyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[PropertyName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[JournalColumn] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
			[Filter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[PropertyFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
			[Segment] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[Method] nvarchar(20) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Fill #PipeStringSplit for @DimensionSetting'
		EXEC [dbo].[spGet_PipeStringSplit] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @PipeString = @DimensionSetting

		INSERT INTO	#DimensionSetting
			(
			[DimensionName],
			[StaticSetting]
			)
		SELECT
			[DimensionName] = [PipeObject],
			[StaticSetting] = [PipeFilter]
		FROM
			#PipeStringSplit
		
	SET @Step = 'Set @DimensionFilterLeafLevel'
		IF @DebugBM & 2 > 0 
			SELECT 
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@StepReference] = 'BR01',
				[@PipeString] = @DimensionFilter,
				[@StorageTypeBM_DataClass] = 3,
				[@StorageTypeBM] = 4, 
				[@Debug] = 0

		EXEC pcINTEGRATOR..spGet_FilterTable
			@UserID = @UserID,
			@InstanceID = @InstanceID,
			@VersionID = @VersionID,
			@StepReference = 'BR01_0',
			@PipeString = @DimensionFilter,
			@StorageTypeBM_DataClass = 4, --@StorageTypeBM_DataClass,
			@StorageTypeBM = 4, --@StorageTypeBM,
			@Debug = 0

		SELECT
			@DimensionFilterLeafLevel = @DimensionFilterLeafLevel + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'DC.[' + DimensionName + '] IN (' + LeafLevelFilter + ') AND'
		FROM
			#FilterTable
		WHERE
			[StepReference] = 'BR01_0'

		IF @DebugBM & 2 > 0 PRINT '@DimensionFilterLeafLevel: ' + @DimensionFilterLeafLevel

	SET @Step = 'Create temp tables for data'
		CREATE TABLE #BR01_FACT
			(
			[InitialStepID] int
			)

		CREATE TABLE #BR01_FACT_Step
			(
			[Dummy] int
			)

	SET @Step = 'Create cursor table for creating temp tables for data'
		CREATE TABLE #DataClassList
			(
			[DataClassID] int,
			[DimensionID] int,
			[ColumnName] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[DataType] nvarchar(20) COLLATE DATABASE_DEFAULT,
			[StaticSetting] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[BaseObjectYN] bit,
			[ReportOnlyYN] bit,
			[SortOrder] int
			)

		INSERT INTO #DataClassList
			(
			[DataClassID],
			[DimensionID],
			[ColumnName],
			[DataType],
			[StaticSetting],
			[BaseObjectYN],
			[ReportOnlyYN],
			[SortOrder]
			)
		SELECT 
			[DataClassID] = DC.[DataClassID],
			[DimensionID] = DCD.[DimensionID],
			[ColumnName] = D.[DimensionName] + '_MemberID',
			[DataType] = 'bigint',
			[StaticSetting] = DS.[StaticSetting],
			[BaseObjectYN] = 0,
			[ReportOnlyYN] = D.[ReportOnlyYN],
			[SortOrder] = DCD.[SortOrder]
		FROM
			#DataClass DC
			INNER JOIN pcINTEGRATOR_Data..DataClass_Dimension DCD ON DCD.InstanceID = @InstanceID AND DCD.VersionID = @VersionID AND DCD.DataClassID = DC.DataClassID
			INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID AND D.DimensionTypeID NOT IN (27,50)
			LEFT JOIN #DimensionSetting DS ON DS.DimensionName = D.DimensionName

		UNION
		SELECT 
			[DataClassID] = DC.[DataClassID],
			[DimensionID] = NULL,
			[ColumnName] = M.[MeasureName] + '_Value',
			[DataType] = 'float',
			[StaticSetting] = NULL,
			[BaseObjectYN] = 0,
			[ReportOnlyYN] = 0,
			[SortOrder] = 10000 + M.[SortOrder]
		FROM
			#DataClass DC
			INNER JOIN pcINTEGRATOR_Data..Measure M ON M.InstanceID = @InstanceID AND M.VersionID = @VersionID AND M.DataClassID = DC.DataClassID

		UPDATE #DataClassList
		SET
			BaseObjectYN = 1,
			SortOrder = -10
		WHERE
			ColumnName = @BaseObject + '_MemberID'

	--SET @Step = 'Remove references to WorkflowState'
	--	IF (SELECT COUNT(1) FROM #DataClassList WHERE DataClassID = @MasterDataClassID AND ColumnName = 'WorkflowState_MemberKey') > 0
	--		BEGIN
	--			INSERT INTO	#DimensionSetting
	--				(
	--				[DimensionName],
	--				[StaticSetting]
	--				)
	--			SELECT
	--				[DimensionName] = 'WorkflowState',
	--				[StaticSetting] = 'NONE'
	--			WHERE
	--				NOT EXISTS (SELECT 1 FROM #DimensionSetting DS WHERE DS.[DimensionName] = 'WorkflowState')

	--			DELETE #DataClassList WHERE ColumnName = 'WorkflowState_MemberKey'
	--		END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionSetting', * FROM #DimensionSetting
		IF @DebugBM & 2 > 0 SELECT TempTable = '#DataClassList', * FROM #DataClassList ORDER BY DataClassID, SortOrder

	SET @Step = 'Run cursor for adding columns to temp tables for data'
		IF CURSOR_STATUS('global','AddColumn_Cursor') >= -1 DEALLOCATE AddColumn_Cursor
		DECLARE AddColumn_Cursor CURSOR FOR
			SELECT 
				ColumnName,
				DataType
			FROM
				#DataClassList
			WHERE
				DataClassID = @MasterDataClassID AND
				StaticSetting IS NULL
			ORDER BY
				DataType DESC,
				SortOrder

			OPEN AddColumn_Cursor
			FETCH NEXT FROM AddColumn_Cursor INTO @ColumnName, @DataType

			WHILE @@FETCH_STATUS = 0
				BEGIN
					SET @SQLStatement = '
						ALTER TABLE #BR01_FACT ADD [' + @ColumnName + '] ' + @DataType + '
						ALTER TABLE #BR01_FACT_Step ADD [' + @ColumnName + '] ' + @DataType

						IF @DebugBM & 2 > 0 PRINT @SQLStatement
						EXEC (@SQLStatement)

					FETCH NEXT FROM AddColumn_Cursor INTO  @ColumnName, @DataType
				END

		CLOSE AddColumn_Cursor
		DEALLOCATE AddColumn_Cursor	

/*
		ALTER TABLE #BR01_FACT_Step DROP Dummy
		IF @DebugBM & 2 > 0
			BEGIN
				SELECT * FROM #BR01_FACT
				SELECT * FROM #BR01_FACT_Step
			END
*/

	SET @Step = 'Create and fill temp table #BR01_Initial_Cursor_Table'
		CREATE TABLE #BR01_Initial_Cursor_Table
			(
			[InitialStepID] [int] IDENTITY(1,1) NOT NULL, 
			[BR01_StepID] int,
			[MemberKey] [nvarchar](100) COLLATE DATABASE_DEFAULT,
			[MemberID] [BIGINT],
			[ModifierID] [int] NULL,
			[MultiplyWith] float NULL,
			[Parameter] [float] NULL,
			[DataClassID] [int] NULL,
			[DataClassName] nvarchar(100),
			[DimensionFilter] [nvarchar](4000) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #BR01_Initial_Cursor_Table
			(
			[BR01_StepID],
			[MemberKey],
			[ModifierID],
			[MultiplyWith],
			[Parameter],
			[DataClassID],
			[DataClassName],
			[DimensionFilter]
			)
		SELECT
			[BR01_StepID] = S.[BR01_StepID],
			[MemberKey] = S.[MemberKey],
			[ModifierID] = ISNULL(S.[ModifierID], 0),
			[MultiplyWith] = MAX(S.[MultiplyWith]),
			[Parameter] = ISNULL(S.[Parameter], 0.0),
			[DataClassID] = ISNULL(S.[DataClassID], M.[DataClassID]),
			[DataClassName] = MAX(DC.[DataClassName]),
			[DimensionFilter] = CASE WHEN S.[DimensionFilter] = '' THEN NULL ELSE S.[DimensionFilter] END
		FROM
			BR01_Master M 
			INNER JOIN BR01_Step S ON S.InstanceID = M.InstanceID AND S.VersionID = M.VersionID AND S.BusinessRuleID = M.BusinessRuleID AND S.BR01_StepPartID >= 0
			INNER JOIN BR01_Step_SortOrder SSO ON SSO.[InstanceID] = S.InstanceID AND SSO.[VersionID] = S.VersionID AND  SSO.[BusinessRuleID] = S.BusinessRuleID AND SSO.[BR01_StepID] = S.BR01_StepID
			INNER JOIN DataClass DC ON DC.DataClassID = ISNULL(S.[DataClassID], M.[DataClassID])
		WHERE
			M.InstanceID = @InstanceID AND
			M.VersionID = @VersionID AND
			M.BusinessRuleID = @BusinessRuleID AND
--			NOT EXISTS (SELECT 1 FROM BR01_Step D WHERE D.BusinessRuleID = S.BusinessRuleID AND D.BR01_StepPartID = -1 AND D.MemberKey = S.MemberKey)
--			NOT EXISTS (SELECT 1 FROM BR01_Step D WHERE D.BusinessRuleID = S.BusinessRuleID AND D.BR01_StepPartID = -1 AND D.MemberKey = S.MemberKey AND ISNULL(D.DataClassID, M.DataClassID) = S.DataClassID)
			NOT EXISTS (SELECT 1 FROM BR01_Step D WHERE D.BusinessRuleID = S.BusinessRuleID AND D.BR01_StepPartID = -1 AND D.MemberKey = S.MemberKey AND M.DataClassID = ISNULL(S.DataClassID, M.DataClassID))
		GROUP BY
			S.[BR01_StepID],
			S.MemberKey,
			S.ModifierID,
			S.Parameter,
			ISNULL(S.[DataClassID], M.[DataClassID]),
			S.DimensionFilter
		ORDER BY
			MIN(SSO.[SortOrder]),
			MIN(S.[BR01_StepPartID])

		SET @SQLStatement = '
			UPDATE CT 
			SET 
				CT.MemberID = D.MemberId
			FROM 
				#BR01_Initial_Cursor_Table CT
				JOIN ['+ @DataClassDatabase + '].[dbo].[S_DS_' + @BaseObject + '] D ON D.[Label] = CT.MemberKey'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 1 > 0 SELECT TempTable = '#BR01_Initial_Cursor_Table', * FROM #BR01_Initial_Cursor_Table

	SET @Step = 'Create temp table #Modifier'
		CREATE TABLE #Modifier
			(
			ModifierID int,
			Parameter float
			)

		CREATE TABLE #Modifier_Value
			(
			ModifierID int,
			Parameter float,
			DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT,
			MemberKey nvarchar(100) COLLATE DATABASE_DEFAULT,
			MemberKey_Modified nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		INSERT INTO #Modifier
			(
			ModifierID,
			Parameter
			)
		SELECT DISTINCT
			ModifierID = ModifierID,
			Parameter = Parameter
		FROM
			#BR01_Initial_Cursor_Table
		WHERE
			ModifierID IS NOT NULL
		
		UNION SELECT DISTINCT
			ModifierID = 0,
			Parameter = 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Modifier', * FROM #Modifier

	SET @Step = 'Create temp table #Time'
		CREATE TABLE #Month
		   ( 
		   [Counter] int IDENTITY(1, 1), 
		   [Time] int
		   )

		INSERT INTO #Month
			(
			[Time]
			)
		SELECT DISTINCT TOP 1000000
			[Time] = Y.Y * 100 + M.M
		FROM
			(
				SELECT
					[Y] = D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 
				FROM
					Digit D1,
					Digit D2,
					Digit D3,
					Digit D4
				WHERE
					D4.Number * 1000 + D3.Number * 100 + D2.Number * 10 + D1.Number + 1 BETWEEN (@ToTime / 100) - 2 AND (@ToTime / 100) + 2
			) Y,
			(
				SELECT
					[M] = D2.Number * 10 + D1.Number + 1 
				FROM
					Digit D1,
					Digit D2
				WHERE
					D2.Number * 10 + D1.Number + 1 BETWEEN 1 AND 12
			) M 
		ORDER BY
			Y.Y * 100 + M.M

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Month', * FROM #Month ORDER BY [Counter]

	SET @Step = 'Run Modifier_Cursor'
		IF CURSOR_STATUS('global','Modifier_Cursor') >= -1 
			BEGIN
				CLOSE Modifier_Cursor
				DEALLOCATE Modifier_Cursor
			END

		DECLARE Modifier_Cursor CURSOR FOR
			SELECT
				ModifierID,
				Parameter
			FROM
				#Modifier
			ORDER BY
				ModifierID,
				Parameter

			OPEN Modifier_Cursor
			FETCH NEXT FROM Modifier_Cursor INTO @ModifierID, @Parameter

			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0 SELECT [@ModifierID] = @ModifierID, [@Parameter] = @Parameter

					IF @ModifierID IN (30, 70)
						SET @SQLStatement = '
							INSERT INTO #Modifier_Value
								(
								ModifierID,
								Parameter,
								DimensionName,
								MemberKey,
								MemberKey_Modified
								)
							SELECT
								ModifierID = ' + CONVERT(nvarchar(10), @ModifierID) + ',
								Parameter = ' + CONVERT(nvarchar(50), @Parameter) + ',
								DimensionName = ''Time'',
								MemberKey = T.MemberId,
								MemberKey_Modified = pcINTEGRATOR.[dbo].[Get_BR_Modifier] (30, T.MemberId, ' + CONVERT(nvarchar(50), CASE WHEN @ModifierID = 70 AND @Parameter = 0 THEN -1 ELSE @Parameter END) + ')
							FROM
								[' + @DataClassDatabase + '].[dbo].[S_DS_Time] T
							WHERE
								T.MemberId BETWEEN ' + CONVERT(nvarchar(10), @FromTime) + ' AND ' + CONVERT(nvarchar(10), @ToTime)

					ELSE IF @ModifierID IN (40) --Full Fiscal Year
						SET @SQLStatement = '
							INSERT INTO #Modifier_Value
								(
								ModifierID,
								Parameter,
								DimensionName,
								MemberKey,
								MemberKey_Modified
								)
							SELECT
								ModifierID = ' + CONVERT(nvarchar(10), @ModifierID) + ',
								Parameter = ' + CONVERT(nvarchar(50), @Parameter) + ',
								DimensionName = ''Time'',
								MemberKey = T.MemberId,
								MemberKey_Modified = TM.MemberId
							FROM
								[' + @DataClassDatabase + '].[dbo].[S_DS_Time] T
								INNER JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_Time] TP ON TP.MemberID = T.MemberID + (' + CONVERT(nvarchar(50), @Parameter) + ' * 100)
								INNER JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_Time] TM ON TM.TimeFiscalYear = TP.TimeFiscalYear AND TM.[Level] = ''Month''
							WHERE
								T.MemberID BETWEEN ' + CONVERT(nvarchar(10), @FromTime) + ' AND ' + CONVERT(nvarchar(10), @ToTime) + '
							ORDER BY
								MemberKey, MemberKey_Modified'

					ELSE IF @ModifierID IN (45) --Full Calendar Year
						SET @SQLStatement = '
							INSERT INTO #Modifier_Value
								(
								ModifierID,
								Parameter,
								DimensionName,
								MemberKey,
								MemberKey_Modified
								)
							SELECT
								ModifierID = ' + CONVERT(nvarchar(10), @ModifierID) + ',
								Parameter = ' + CONVERT(nvarchar(50), @Parameter) + ',
								DimensionName = ''Time'',
								MemberKey = T.MemberId,
								MemberKey_Modified = TM.MemberId
							FROM
								[' + @DataClassDatabase + '].[dbo].[S_DS_Time] T
								INNER JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_Time] TP ON TP.MemberID = T.MemberID + (' + CONVERT(nvarchar(50), @Parameter) + ' * 100)
								INNER JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_Time] TM ON TM.TimeYear = TP.TimeYear AND TM.[Level] = ''Month''
							WHERE
								T.MemberID BETWEEN ' + CONVERT(nvarchar(10), @FromTime) + ' AND ' + CONVERT(nvarchar(10), @ToTime) + '
							ORDER BY
								MemberKey, MemberKey_Modified'

					ELSE IF @ModifierID IN (80) --FYTD Fiscal Year To Date
						SET @SQLStatement = '
							INSERT INTO #Modifier_Value
								(
								ModifierID,
								Parameter,
								DimensionName,
								MemberKey,
								MemberKey_Modified
								)
							SELECT
								ModifierID = ' + CONVERT(nvarchar(10), @ModifierID) + ',
								Parameter = ' + CONVERT(nvarchar(50), @Parameter) + ',
								DimensionName = ''Time'',
								MemberKey = T.MemberId,
								MemberKey_Modified = TM.MemberId
							FROM
								[' + @DataClassDatabase + '].[dbo].[S_DS_Time] T
								INNER JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_Time] TP ON TP.MemberID = T.MemberID + (' + CONVERT(nvarchar(50), @Parameter) + ' * 100)
								INNER JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_Time] TM ON TM.TimeFiscalYear = TP.TimeFiscalYear AND TM.MemberId <= TP.MemberID AND TM.[Level] = ''Month''
							WHERE
								T.MemberId BETWEEN ' + CONVERT(nvarchar(15), @FromTime) + ' AND ' + CONVERT(nvarchar(15), @ToTime) + '
							ORDER BY
								MemberKey, MemberKey_Modified'

					ELSE IF @ModifierID IN (85) --YTD Calendar Year To Date
						SET @SQLStatement = '
							INSERT INTO #Modifier_Value
								(
								ModifierID,
								Parameter,
								DimensionName,
								MemberKey,
								MemberKey_Modified
								)
							SELECT
								ModifierID = ' + CONVERT(nvarchar(10), @ModifierID) + ',
								Parameter = ' + CONVERT(nvarchar(50), @Parameter) + ',
								DimensionName = ''Time'',
								MemberKey = T.MemberId,
								MemberKey_Modified = TM.MemberId
							FROM
								[' + @DataClassDatabase + '].[dbo].[S_DS_Time] T
								INNER JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_Time] TP ON TP.MemberID = T.MemberID + (' + CONVERT(nvarchar(50), @Parameter) + ' * 100)
								INNER JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_Time] TM ON TM.TimeYear = TP.TimeYear AND TM.MemberId <= TP.MemberID AND TM.[Level] = ''Month''
							WHERE
								T.MemberId BETWEEN ' + CONVERT(nvarchar(15), @FromTime) + ' AND ' + CONVERT(nvarchar(15), @ToTime) + '
							ORDER BY
								MemberKey, MemberKey_Modified'

					ELSE IF @ModifierID IN (90) --R12
						SET @SQLStatement = '
							INSERT INTO #Modifier_Value
								(
								ModifierID,
								Parameter,
								DimensionName,
								MemberKey,
								MemberKey_Modified
								)
							SELECT
								ModifierID = ' + CONVERT(nvarchar(10), @ModifierID) + ',
								Parameter = ' + CONVERT(nvarchar(50), @Parameter) + ',
								DimensionName = ''Time'',
								MemberKey = M1.[Time],
								MemberKey_Modified = M2.[Time]
							FROM
								#Month M1
								INNER JOIN #Month M2 ON M2.[Counter] BETWEEN (SELECT [Counter] + (-11 + ' + CONVERT(nvarchar(50), @Parameter) + ') FROM #Month M WHERE M.[Time] = M1.[Time]) AND (SELECT [Counter] + (' + CONVERT(nvarchar(50), @Parameter) + ') FROM #Month M WHERE M.[Time] = M1.[Time])
							WHERE
								M1.[Time] BETWEEN ' + CONVERT(nvarchar(10), @FromTime) + ' AND ' + CONVERT(nvarchar(10), @ToTime)

					ELSE
						SET @SQLStatement = '
							INSERT INTO #Modifier_Value
								(
								ModifierID,
								Parameter,
								DimensionName,
								MemberKey,
								MemberKey_Modified
								)
							SELECT
								ModifierID = ' + CONVERT(NVARCHAR(10), @ModifierID) + ',
								Parameter = ' + CONVERT(NVARCHAR(50), @Parameter) + ',
								DimensionName = ''Time'',
								MemberKey = T.MemberId,
								MemberKey_Modified = T.MemberId
							FROM
								[' + @DataClassDatabase + '].[dbo].[S_DS_Time] T
							WHERE
								T.MemberId BETWEEN ' + CONVERT(NVARCHAR(10), @FromTime) + ' AND ' + CONVERT(NVARCHAR(10), @ToTime)

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)

					FETCH NEXT FROM Modifier_Cursor INTO @ModifierID, @Parameter
				END

		CLOSE Modifier_Cursor
		DEALLOCATE Modifier_Cursor
		
		IF @DebugBM & 2 > 0 SELECT TempTable = '#Modifier_Value', * FROM #Modifier_Value ORDER BY ModifierID, Parameter, MemberKey, MemberKey_Modified
		IF @DebugBM & 2 > 0
			BEGIN
				IF OBJECT_ID (N'pcINTEGRATOR_Log.dbo.tmp_Modifier_Value', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log.dbo.tmp_Modifier_Value
				SELECT * INTO pcINTEGRATOR_Log.dbo.tmp_Modifier_Value FROM #Modifier_Value
			END

	SET @Step = 'Create temp table #BaseObject_Member'
		CREATE TABLE #BaseObject_Member
			(
			MemberId bigint,
			MemberKey nvarchar(100) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Create temp table #JoinExclusion'
		CREATE TABLE #JoinExclusion
			(
			InitialStepID int,
			DimensionName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

	SET @Step = 'Run Cursor on #BR01_Initial_Cursor_Table'
		IF @DebugBM & 2 > 0 PRINT '=============================' + CHAR(13) + CHAR(10) + 'Initial Cursor' + CHAR(13) + CHAR(10) + '============================='
		IF CURSOR_STATUS('global','BR01_Initial_Cursor') >= -1 DEALLOCATE BR01_Initial_Cursor
		DECLARE BR01_Initial_Cursor CURSOR FOR
			
			SELECT
				[BR01_StepID],
				[InitialStepID], 
				[MemberKey],
				[MemberID],
				[ModifierID],
				[MultiplyWith],
				[Parameter],
				[DataClassID],
				[DataClassName],
				[DimensionFilter]
			FROM
				#BR01_Initial_Cursor_Table
			ORDER BY
				[InitialStepID]

			OPEN BR01_Initial_Cursor
			FETCH NEXT FROM BR01_Initial_Cursor INTO @BR01_StepID, @InitialStepID, @MemberKey, @MemberID, @ModifierID, @MultiplyWith, @Parameter, @DataClassID, @DataClassName, @DimensionFilterStep

			WHILE @@FETCH_STATUS = 0
				BEGIN

--					SET @PipeString = @BaseObject + '=' + @MemberKey + CASE WHEN @DimensionFilterStep IS NOT NULL THEN '|' + @DimensionFilterStep ELSE '' END
					SET @PipeString = @BaseObject + '=' + @MemberKey + CASE WHEN @DimensionFilter IS NOT NULL THEN '|' + @DimensionFilter ELSE '' END + CASE WHEN @DimensionFilterStep IS NOT NULL THEN '|' + @DimensionFilterStep ELSE '' END

					SET @PipeString = REPLACE(@PipeString, '''', '')
					SET @StepReference = 'BR01_1_' + CONVERT(nvarchar(15), @InitialStepID)

					IF @DebugBM & 2 > 0 SELECT [@BR01_StepID] = @BR01_StepID, [@InitialStepID] = @InitialStepID, [@MemberKey] = @MemberKey, [@MemberID] = @MemberID, [@ModifierID] = @ModifierID, [@Parameter] = @Parameter, [@DataClassID] = @DataClassID, [@PipeString] = @PipeString, [@DimensionFilterStep] = @DimensionFilterStep

					IF @PipeString IS NULL
						TRUNCATE TABLE #FilterTable
					ELSE
						BEGIN
							EXEC pcINTEGRATOR..spGet_FilterTable
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								--@StepReference = 'BR01_1',
								@StepReference = @StepReference,
								@PipeString = @PipeString,
								@StorageTypeBM_DataClass = 4, --@StorageTypeBM_DataClass,
								@StorageTypeBM = 4, --@StorageTypeBM,
								@Debug = 0

							INSERT INTO #JoinExclusion
								(
								[InitialStepID],
								[DimensionName]
								)
							SELECT
								[InitialStepID] = @InitialStepID,
								[DimensionName]
							FROM
								#FilterTable
							WHERE
								[EqualityString] = '-'  AND
								[StepReference] = @StepReference

							IF @DebugBM & 2 > 0 SELECT TempTable = '#FilterTable', * FROM #FilterTable
						END

					SELECT
						@SQL_Insert = '[InitialStepID],',
						@SQL_Select = '[InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ',',
						@SQL_Select_70 = '[InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ',',
						@SQL_Select_MV_70 = '',
						@SQL_GroupBy = '',
						@SQL_Where = '',
						@SQL_Join = '',
						@SQL_Join_CM_70 = '',
						@SQL_Join_PM_70 = ''

					SELECT
						@SQL_Insert = @SQL_Insert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + CASE WHEN DCL.DataType = 'float' THEN @MasterDataClassName + '_Value' ELSE DCL.ColumnName END + '],',
						@SQL_Select = @SQL_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + DCL.ColumnName + '] = ' + 
						CASE 
							WHEN DCL.BaseObjectYN <> 0 THEN  CONVERT(NVARCHAR(20), @MemberID)
							ELSE 
								CASE 
									WHEN DCL.DataType = 'float' THEN 'SUM(DC.[' + DCL.ColumnName + ']) * ' + CONVERT(nvarchar(20), @MultiplyWith) + 
																		CASE @ModifierID 
																				WHEN 10 THEN ' * ' + CONVERT(nvarchar(10), @Parameter) 
																				WHEN 20 THEN ' / ' + CONVERT(nvarchar(10), @Parameter) 
																				ELSE '' 
																		END 
									ELSE CASE 
												WHEN DCL.ColumnName = 'Time_MemberID' THEN 'MV.MemberKey' 
												ELSE 'DC.[' + DCL.ColumnName + ']' 
										END 
								END 
						END + ',',
						@SQL_Select_70 = @SQL_Select_70 + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + DCL.ColumnName + '] = ' + CASE WHEN DCL.BaseObjectYN <> 0 THEN CONVERT(NVARCHAR(20), @MemberID) ELSE CASE WHEN DCL.DataType = 'float' THEN '(ISNULL(CM.[' + @MasterDataClassName + '_Value], 0.0) - ISNULL(PM.[' + @MasterDataClassName + '_Value], 0.0)) * ' + CONVERT(nvarchar(20), @MultiplyWith) ELSE 'M.[' + DCL.ColumnName + ']' END END + ',',
						@SQL_GroupBy = @SQL_GroupBy + CASE WHEN DCL.BaseObjectYN <> 0 OR DCL.DataType = 'float' THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN DCL.ColumnName = 'Time_MemberID' THEN 'MV.[MemberKey],' ELSE 'DC.[' + DCL.ColumnName + '],' END END,
						@SQL_Select_MV_70 = @SQL_Select_MV_70 + CASE WHEN DCL.BaseObjectYN <> 0 OR DCL.DataType = 'float' THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CASE WHEN DCL.ColumnName = 'Time_MemberID' THEN '[' + DCL.ColumnName + '] = MV.[MemberKey],' ELSE '[' + DCL.ColumnName + '] = DC.[' + DCL.ColumnName + '],' END END,
						@SQL_Join_CM_70 = @SQL_Join_CM_70 + CASE WHEN DCL.BaseObjectYN <> 0 OR DCL.DataType = 'float' THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'CM.[' + DCL.ColumnName + '] = [M].[' + DCL.ColumnName + '] AND' END,
						@SQL_Join_PM_70 = @SQL_Join_PM_70 + CASE WHEN DCL.BaseObjectYN <> 0 OR DCL.DataType = 'float' THEN '' ELSE CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'PM.[' + DCL.ColumnName + '] = [M].[' + DCL.ColumnName + '] AND' END
					FROM
						#DataClassList DCL
						INNER JOIN (SELECT ColumnName, DataType FROM #DataClassList WHERE DataClassID = @MasterDataClassID) MDCL ON MDCL.ColumnName = DCL.ColumnName OR (MDCL.DataType = 'float' AND DCL.DataType = 'float')
					WHERE
						DCL.DataClassID = @DataClassID AND
						NOT EXISTS (SELECT 1 FROM #DimensionSetting DS WHERE DS.DimensionName = REPLACE(DCL.ColumnName, '_MemberID', ''))
					ORDER BY
						SortOrder

					SELECT
						@SQL_Where = @SQL_Where + 
							CASE WHEN ISNULL(FT.[LeafLevelFilter], '') <> '' AND ISNULL(FT.[PropertyName], '') = ''
							THEN
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'DC.[' + FT.[DimensionName] + '_MemberID] IN (' + FT.[LeafLevelFilter] + ') AND'
							ELSE
								''
							END,
						@SQL_Join = @SQL_Join +
							CASE WHEN ISNULL(FT.[PropertyName], '') <> '' AND ISNULL(FT.[Filter], '') <> ''
							THEN 
								CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_' + FT.[DimensionName] + '] [' + FT.[DimensionName]  + '] ON [' + FT.[DimensionName] + '].[MemberId] = DC.[' + FT.[DimensionName] + '_MemberId] AND [' + FT.[DimensionName] + '].[' + FT.[PropertyName] + '] = ''' + FT.[Filter] + ''''
							ELSE
								''
							END
					FROM

						#FilterTable FT
						INNER JOIN #DataClassList DCL ON DCL.[DataClassID] = @DataClassID AND DCL.[DimensionID] = FT.[DimensionID]
					WHERE
						FT.[StepReference] = @StepReference --'BR01_1'

					SELECT
						@SQL_Insert = LEFT(@SQL_Insert, LEN(@SQL_Insert) - 1),
						@SQL_Select = LEFT(@SQL_Select, LEN(@SQL_Select) - 1),
						@SQL_Select_70 = LEFT(@SQL_Select_70, LEN(@SQL_Select_70) - 1),
						@SQL_Select_MV_70 = LEFT(@SQL_Select_MV_70, LEN(@SQL_Select_MV_70) - 1),
						@SQL_Where = LEFT(@SQL_Where, LEN(@SQL_Where) - 4),
						@SQL_GroupBy = LEFT(@SQL_GroupBy, LEN(@SQL_GroupBy) - 1),
						@SQL_Join_CM_70 = LEFT(@SQL_Join_CM_70, LEN(@SQL_Join_CM_70) - 4),
						@SQL_Join_PM_70 = LEFT(@SQL_Join_PM_70, LEN(@SQL_Join_PM_70) - 4)

					IF @ModifierID = 70
						BEGIN
							SET @SQLStatement = '
								INSERT INTO #BR01_FACT
									(' + @SQL_Insert + '
									)
								SELECT 
									' + @SQL_Select_70 + '
								FROM
									(
									SELECT DISTINCT' + @SQL_Select_MV_70 + '
									FROM
										[' + @DataClassDatabase + '].[dbo].[FACT_' + @MasterDataClassName + '_default_partition] DC' + @SQL_Join + '
										INNER JOIN [#Modifier_Value] MV ON MV.ModifierID = 0 AND MV.Parameter = 0 AND MV.DimensionName = ''Time'' AND MV.[MemberKey_Modified] = DC.Time_MemberId
									WHERE' + @SQL_Where + '

									UNION SELECT DISTINCT' + @SQL_Select_MV_70 + '
									FROM
										[' + @DataClassDatabase + '].[dbo].[FACT_' + @MasterDataClassName + '_default_partition] DC' + @SQL_Join + '
										INNER JOIN [#Modifier_Value] MV ON MV.ModifierID = ' + CONVERT(nvarchar(10), @ModifierID) + ' AND MV.Parameter = ' + CONVERT(nvarchar(50), @Parameter) + ' AND MV.DimensionName = ''Time'' AND MV.[MemberKey_Modified] = DC.Time_MemberId
									WHERE' + @SQL_Where + '
									) [M]
									LEFT JOIN (
										SELECT' + @SQL_Select_MV_70 + ',
											[' + @MasterDataClassName + '_Value] = SUM(DC.[' + @MasterDataClassName + '_Value])
										FROM
											[' + @DataClassDatabase + '].[dbo].[FACT_' + @MasterDataClassName + '_default_partition] DC' + @SQL_Join + '
											INNER JOIN [#Modifier_Value] MV ON MV.ModifierID = 0 AND MV.Parameter = 0 AND MV.DimensionName = ''Time'' AND MV.[MemberKey_Modified] = DC.Time_MemberId
										WHERE' + @SQL_Where + '
										GROUP BY' + @SQL_GroupBy + '
										) CM ON' + @SQL_Join_CM_70 + '
									LEFT JOIN (
										SELECT' + @SQL_Select_MV_70 + ',
											[' + @MasterDataClassName + '_Value] = SUM(DC.[' + @MasterDataClassName + '_Value])
										FROM
											[' + @DataClassDatabase + '].[dbo].[FACT_' + @MasterDataClassName + '_default_partition] DC' + @SQL_Join + '
											INNER JOIN [#Modifier_Value] MV ON MV.ModifierID = ' + CONVERT(NVARCHAR(10), @ModifierID) + ' AND MV.Parameter = ' + CONVERT(NVARCHAR(50), @Parameter) + ' AND MV.DimensionName = ''Time'' AND MV.[MemberKey_Modified] = DC.Time_MemberId
										WHERE' + @SQL_Where + '
										GROUP BY' + @SQL_GroupBy + '
										) PM ON' + @SQL_Join_PM_70
						END
					ELSE
						BEGIN
							IF LEN(@SQL_Join) > 0 SELECT @SQL_Join = REPLACE(@SQL_Join, 'MemberKey', 'Label')

							SET @SQLStatement = '
								INSERT INTO #BR01_FACT
									(
									' + @SQL_Insert + '
									)
								SELECT 
									' + @SQL_Select + '
								FROM
									[' + @DataClassDatabase + '].[dbo].[FACT_' + @DataClassName + '_default_partition] DC' + @SQL_Join + '
									INNER JOIN [#Modifier_Value] MV ON MV.ModifierID = ' + CONVERT(NVARCHAR(10), @ModifierID) + ' AND MV.Parameter = ' + CONVERT(NVARCHAR(50), @Parameter) + ' AND MV.DimensionName = ''Time'' AND MV.[MemberKey_Modified] = DC.Time_MemberId
								WHERE' + @SQL_Where + '
								GROUP BY' + @SQL_GroupBy
						END

					IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000 
						BEGIN
							PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; @InitialStepID = ' + CONVERT(NVARCHAR(10), @InitialStepID) + ' #BR01_FACT Initial'
							SET @Comment = '#BR01_FACT Initial; @InitialStepID = ' + CONVERT(NVARCHAR(10), @InitialStepID)
							EXEC [dbo].[spSet_wrk_Debug]
								@UserID = @UserID,
								@InstanceID = @InstanceID,
								@VersionID = @VersionID,
								@DatabaseName = 'pcINTEGRATOR',
								@CalledProcedureName = @ProcedureName,
								@Comment = @Comment, 
								@SQLStatement = @SQLStatement
						END
					ELSE IF @DebugBM & 2 > 0
						PRINT @SQLStatement

					EXEC (@SQLStatement)
					FETCH NEXT FROM BR01_Initial_Cursor INTO @BR01_StepID, @InitialStepID, @MemberKey, @MemberID, @ModifierID, @MultiplyWith, @Parameter, @DataClassID, @DataClassName, @DimensionFilterStep
				END

		CLOSE BR01_Initial_Cursor
		DEALLOCATE BR01_Initial_Cursor

		IF @DebugBM & 2 > 0 SELECT TempTable = '#BR01_FACT', * FROM #BR01_FACT ORDER BY InitialStepID
		IF @DebugBM & 1 > 0 SELECT TempTable = '#BR01_FACT', InitialStepID, Account_MemberID, [#Rows] = COUNT(1) FROM #BR01_FACT GROUP BY InitialStepID, Account_MemberID ORDER BY InitialStepID, Account_MemberID
		IF @DebugBM & 2 > 0
			BEGIN
				IF OBJECT_ID (N'pcINTEGRATOR_Log.dbo.tmp_BR01_FACT', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log.dbo.tmp_BR01_FACT
				SELECT * INTO pcINTEGRATOR_Log.dbo.tmp_BR01_FACT FROM #BR01_FACT
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#JoinExclusion', * FROM #JoinExclusion

	SET @Step = 'Create temp table #BR01_Destination_Cursor_Table'
		SELECT
			[BR01_StepID] = S.[BR01_StepID],
			[DestinationMemberKey] = CONVERT(NVARCHAR(100), MAX(CASE WHEN S.BR01_StepPartID = -1 THEN S.[MemberKey] ELSE NULL END)),
			[DestinationMemberID] = CAST(NULL AS BIGINT),
			[ModifierID] = MAX(CASE WHEN S.BR01_StepPartID = -1 THEN S.[ModifierID] ELSE NULL END),
			[MultiplyWith] = ISNULL(MAX(CASE WHEN S.BR01_StepPartID = -1 THEN S.[MultiplyWith] ELSE NULL END), 1.0),
			[Parameter] = MAX(CASE WHEN S.BR01_StepPartID = -1 THEN S.[Parameter] ELSE NULL END),
			[Decimal] = MAX(CASE WHEN S.BR01_StepPartID = -1 THEN S.[Decimal] ELSE NULL END),
			[MasterMemberKey] = CONVERT(NVARCHAR(100), MAX(CASE WHEN S.BR01_StepPartID = 0 THEN S.[MemberKey] ELSE NULL END)),
			[MasterMemberID] = CAST(NULL AS BIGINT),
			[InitialStepID] = MAX(CASE WHEN S.BR01_StepPartID = 0 THEN [IS].[InitialStepID] ELSE NULL END),
--			[InitialStepID] = CASE WHEN S.BR01_StepPartID = 0 THEN [IS].[InitialStepID] ELSE NULL END,
			[SortOrder] = MAX(SSO.[SortOrder])
		INTO
			#BR01_Destination_Cursor_Table
		FROM 
			BR01_Step S
			INNER JOIN BR01_Step_SortOrder SSO ON SSO.[InstanceID] = S.InstanceID AND SSO.[VersionID] = S.VersionID AND  SSO.[BusinessRuleID] = S.BusinessRuleID AND SSO.[BR01_StepID] = S.BR01_StepID
			LEFT JOIN #BR01_Initial_Cursor_Table [IS] ON [IS].[BR01_StepID] = S.[BR01_StepID] AND [IS].[MemberKey] = S.[MemberKey] AND ISNULL([IS].[ModifierID], 0) = ISNULL(S.[ModifierID], 0) AND ISNULL([IS].[Parameter], 0) = ISNULL(S.[Parameter], 0) AND ISNULL([IS].[DimensionFilter], '') = ISNULL(S.[DimensionFilter],'')
		WHERE
			S.InstanceID = @InstanceID AND
			S.VersionID = @VersionID AND
			S.[BusinessRuleID] = @BusinessRuleID AND
			S.[BR01_StepPartID] IN (-1, 0)
		GROUP BY
			S.[BR01_StepID]--,
--			CASE WHEN S.BR01_StepPartID = 0 THEN [IS].[InitialStepID] ELSE NULL END

		IF @DebugBM & 1 > 0 SELECT TempTable = 'INTO #BR01_Destination_Cursor_Table', * FROM #BR01_Destination_Cursor_Table ORDER BY [SortOrder]

		SET @SQLStatement = '
			UPDATE DCT 
			SET 
				DCT.DestinationMemberID = D_DEST.MemberId,
				DCT.MasterMemberID = D_MASTER.MemberId
			FROM 
				#BR01_Destination_Cursor_Table DCT
				JOIN ['+ @DataClassDatabase + '].[dbo].[S_DS_' + @BaseObject + '] D_DEST ON D_DEST.[Label] = DCT.[DestinationMemberKey]
				JOIN ['+ @DataClassDatabase + '].[dbo].[S_DS_' + @BaseObject + '] D_MASTER ON D_MASTER.[Label] = DCT.[MasterMemberKey]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @DebugBM & 1 > 0 SELECT TempTable = 'UPDATE #BR01_Destination_Cursor_Table', * FROM #BR01_Destination_Cursor_Table ORDER BY [SortOrder]

	SET @Step = 'Run BR01_Destination_Cursor'
		IF @DebugBM & 2 > 0 PRINT '=============================' + CHAR(13) + CHAR(10) + 'Destination Cursor' + CHAR(13) + CHAR(10) + '============================='
		IF CURSOR_STATUS('global','BR01_Destination_Cursor') >= -1 DEALLOCATE BR01_Destination_Cursor
		DECLARE BR01_Destination_Cursor CURSOR FOR
			SELECT
				[BR01_StepID],
				[DestinationMemberKey],
				[DestinationMemberID],
				[ModifierID],
				[MultiplyWith],
				[Parameter],
				[Decimal],
				[MasterMemberKey],
				[MasterMemberID],
				[InitialStepID]
			FROM 
				#BR01_Destination_Cursor_Table
			ORDER BY
				[SortOrder]

			OPEN BR01_Destination_Cursor
			FETCH NEXT FROM BR01_Destination_Cursor INTO @BR01_StepID, @DestinationMemberKey, @DestinationMemberID, @ModifierID, @MultiplyWith, @Parameter, @Decimal, @MasterMemberKey, @MasterMemberID, @InitialStepID
			WHILE @@FETCH_STATUS = 0
				BEGIN
					IF @DebugBM & 2 > 0
						BEGIN
							SELECT
								[Cursor] = 'BR01_Destination_Cursor',
								[@BR01_StepID] = @BR01_StepID,
								[@DestinationMemberKey] = @DestinationMemberKey,
								[@DestinationMemberID] = @DestinationMemberID,
								[@ModifierID] = @ModifierID,
								[@Parameter] = @Parameter,
								[@Decimal] = @Decimal,
								[@MasterMemberKey] = @MasterMemberKey,
								[@MasterMemberID] = @MasterMemberID,
								[@InitialStepID] = @InitialStepID

							PRINT '-----------------------------------' + CHAR(13) + CHAR(10) + 'Begin Loop for [@BR01_StepID] = ' + CONVERT(NVARCHAR(15), @BR01_StepID) + CHAR(13) + CHAR(10) + '-----------------------------------'
						END

					SELECT
						@SQL_Insert = '',
						@SQL_Insert_Right = '',
						@SQL_Select = '',
						@SQL_Select_Multiply_Master = '',
						@SQL_Select_Addition_Master = '',
						@SQL_Join_Multiply = '',
						@SQL_Select_Addition_Right = '',
						@SQL_Join_Addition1 = '',
						@SQL_Join_Addition2 = ''

					SELECT
						@SQL_Insert = @SQL_Insert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '],',
						@SQL_Insert_Right = @SQL_Insert_Right + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '],',
						@SQL_Select = @SQL_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + ']' + CASE WHEN DCL.BaseObjectYN <> 0 THEN ' = ' + CONVERT(NVARCHAR(20), @DestinationMemberID) ELSE '' END + ',',
						@SQL_Select_Multiply_Master = @SQL_Select_Multiply_Master + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '] = ' + CASE WHEN DCL.BaseObjectYN <> 0 THEN CONVERT(NVARCHAR(20), @DestinationMemberID) ELSE CASE WHEN DCL.DataType = 'float' THEN 'F.[' + ColumnName + '] @Operator OP.[' + ColumnName + ']' ELSE 'F.[' + ColumnName + ']' END END + ',',
						@SQL_Select_Addition_Master = @SQL_Select_Addition_Master + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '] = ' + CASE WHEN DCL.BaseObjectYN <> 0 THEN CONVERT(NVARCHAR(20), @DestinationMemberID) ELSE CASE WHEN DCL.DataType = 'float' THEN 'ISNULL(F.[' + ColumnName + '], 0) @Operator ISNULL(OP.[' + ColumnName + '], 0)' ELSE 'M.[' + ColumnName + ']' END END + ',',
--						@SQL_Join_Multiply = @SQL_Join_Multiply + CASE WHEN DCL.BaseObjectYN = 0 AND DCL.DataType <> 'float' THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'OP.[' + ColumnName + '] = F.[' + ColumnName + '] AND' ELSE '' END,
						@SQL_Select_Addition_Right = @SQL_Select_Addition_Right + CASE WHEN DCL.BaseObjectYN = 0 AND DCL.DataType <> 'float' THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + ColumnName + '],' ELSE '' END,
						@SQL_Join_Addition1 = @SQL_Join_Addition1 + CASE WHEN DCL.BaseObjectYN = 0 AND DCL.DataType <> 'float' THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'F.[' + ColumnName + '] = M.[' + ColumnName + '] AND' ELSE '' END,
						@SQL_Join_Addition2 = @SQL_Join_Addition2 + CASE WHEN DCL.BaseObjectYN = 0 AND DCL.DataType <> 'float' THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'OP.[' + ColumnName + '] = M.[' + ColumnName + '] AND' ELSE '' END
					FROM
						#DataClassList DCL
					WHERE
						DCL.DataClassID = @MasterDataClassID AND
						DCL.StaticSetting IS NULL
					ORDER BY
						SortOrder

					SELECT
						@SQL_Insert = LEFT(@SQL_Insert, LEN(@SQL_Insert) - 1),
						@SQL_Insert_Right = LEFT(@SQL_Insert_Right, LEN(@SQL_Insert_Right) - 1),
						@SQL_Select = LEFT(@SQL_Select, LEN(@SQL_Select) - 1),
						@SQL_Select_Multiply_Master = LEFT(@SQL_Select_Multiply_Master, LEN(@SQL_Select_Multiply_Master) - 1),
						@SQL_Select_Addition_Master = LEFT(@SQL_Select_Addition_Master, LEN(@SQL_Select_Addition_Master) - 1),
--						@SQL_Join_Multiply = LEFT(@SQL_Join_Multiply, LEN(@SQL_Join_Multiply) - 4),
						@SQL_Select_Addition_Right = LEFT(@SQL_Select_Addition_Right, LEN(@SQL_Select_Addition_Right) - 1),
						@SQL_Join_Addition1 = LEFT(@SQL_Join_Addition1, LEN(@SQL_Join_Addition1) - 4)

					SET @SQLStatement = '
						INSERT INTO #BR01_FACT
							(' + @SQL_Insert + '
							)
						SELECT' + @SQL_Select + '
						FROM
							#BR01_FACT F
						WHERE
							F.[' + @BaseObject + '_MemberID] = ' + CONVERT(NVARCHAR(20), @MasterMemberID) + ' AND
							(F.[InitialStepID] = ' + CONVERT(nvarchar(10), ISNULL(@InitialStepID, 0)) + ' OR ''' + CONVERT(nvarchar(10), ISNULL(@InitialStepID, 0)) + ''' = ''0'')'

					IF @DebugBM & 2 > 0 
						BEGIN
							PRINT '[Cursor] = BR01_Destination_Cursor, [@BR01_StepID] = ' + CONVERT(nvarchar(15), ISNULL(@BR01_StepID, 0))
							SELECT [Cursor] = 'BR01_Destination_Cursor', [@BR01_StepID] = @BR01_StepID, [@SQL_Insert] = @SQL_Insert, [@SQL_Select] = @SQL_Select, [@BaseObject] = @BaseObject, [@DestinationMemberKey] = @DestinationMemberKey, [@DestinationMemberID] = @DestinationMemberID, [@Decimal] = @Decimal, [@MasterMemberKey] = @MasterMemberKey, [@MasterMemberID] = @MasterMemberID, [@InitialStepID] = @InitialStepID
							PRINT '[Cursor] = BR01_Destination_Cursor, [BR01_StepID] = ' + CONVERT(nvarchar(10), @BR01_StepID) + ', [DestinationMemberKey] = ' + @DestinationMemberKey  + ', [DestinationMemberID] = ' + CONVERT(NVARCHAR(20), @DestinationMemberID) + ', [Decimal] = ' + CONVERT(nvarchar(10), ISNULL(@Decimal, 0)) + ', [MasterMemberKey] = ' + @MasterMemberKey + ', [MasterMemberID] = ' + CONVERT(NVARCHAR(20), @MasterMemberID) + ', [InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID)
							PRINT @SQLStatement
						END
					EXEC (@SQLStatement)
					SET @BR01_StepPartID = 1
					WHILE @BR01_StepPartID <= (SELECT MAX(BR01_StepPartID) FROM BR01_Step S WHERE S.BusinessRuleID = @BusinessRuleID AND S.[BR01_StepID] = @BR01_StepID)
						BEGIN
							SELECT
								@MemberKey = S.[MemberKey],
								@MemberID = [IS].MemberID,
								@Operator = S.[Operator],
								@InitialStepID = [IS].[InitialStepID],
								@InitialStepID_Compare = 0
							FROM
								BR01_Step S
								LEFT JOIN #BR01_Initial_Cursor_Table [IS] ON [IS].[BR01_StepID] = S.[BR01_StepID] AND [IS].[MemberKey] = S.[MemberKey] AND ISNULL([IS].[ModifierID], 0) = ISNULL(S.[ModifierID], 0) AND ISNULL([IS].[Parameter], 0) = ISNULL(S.[Parameter], 0) AND ISNULL([IS].[DimensionFilter], '') = ISNULL(S.[DimensionFilter],'')
							WHERE
								S.BusinessRuleID = @BusinessRuleID AND 
								S.[BR01_StepID] = @BR01_StepID AND 
								S.BR01_StepPartID = @BR01_StepPartID

							IF @InitialStepID IS NULL
								BEGIN
									INSERT INTO #BR01_Initial_Cursor_Table
										(
										BR01_StepID,
										MemberKey,
										MemberID,
										ModifierID,
										Parameter,
										DataClassID,
										DimensionFilter
										)
									SELECT
										BR01_StepID,
										MemberKey,
										MemberID = @MemberID, -- null? because null on "left join" see several rows above 
										ModifierID,
										Parameter,
										DataClassID,
										DimensionFilter
									FROM
										[pcINTEGRATOR_Data].[dbo].[BR01_Step]
									WHERE
										BR01_StepID = @BR01_StepID AND
										BR01_StepPartID = @BR01_StepPartID AND
										MemberKey = @MemberKey

									SET @InitialStepID = @@IDENTITY
									SET @InitialStepID_Compare = @InitialStepID

									SET @SQLStatement = '
										UPDATE CT 
										SET 
											CT.MemberID = D.MemberId
										FROM 
											#BR01_Initial_Cursor_Table CT
											JOIN ['+ @DataClassDatabase + '].[dbo].[S_DS_' + @BaseObject + '] D ON D.[Label] = CT.MemberKey
										where CT.InitialStepID = ' + CAST(@InitialStepID AS VARCHAR(255))

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									SELECT @MemberID = MemberID
									FROM #BR01_Initial_Cursor_Table
									WHERE InitialStepID = @InitialStepID

									SELECT @PipeString = DimensionFilter FROM #BR01_Initial_Cursor_Table WHERE InitialStepID = @InitialStepID

									EXEC pcINTEGRATOR..spGet_FilterTable
										@UserID = @UserID,
										@InstanceID = @InstanceID,
										@VersionID = @VersionID,
										@StepReference = 'BR01_2',
										@PipeString = @PipeString,
										@StorageTypeBM_DataClass = 4, --@StorageTypeBM_DataClass,
										@StorageTypeBM = 4, --@StorageTypeBM,
										@Debug = 0

									INSERT INTO #JoinExclusion
										(
										[InitialStepID],
										[DimensionName]
										)
									SELECT
										[InitialStepID] = @InitialStepID,
										[DimensionName]
									FROM
										#FilterTable
									WHERE
										[EqualityString] = '-' AND
										[StepReference] = 'BR01_2'

									IF @DebugBM & 2 > 0 SELECT TempTable = '#JoinExclusion', * FROM #JoinExclusion
								END

							IF @DebugBM & 2 > 0 SELECT [@BR01_StepPartID] = @BR01_StepPartID, [@MemberKey] = @MemberKey, [@InitialStepID] = @InitialStepID, [@Operator] = @Operator
							IF @DebugBM & 2 > 0 PRINT '@BR01_StepPartID = ' + CONVERT(nvarchar(10), @BR01_StepPartID) + ', @MemberKey = ' + @MemberKey + ', @MemberID = ' + CONVERT(nvarchar(20), @MemberID) + ', @InitialStepID = ' + CONVERT(nvarchar(10), @InitialStepID) + ', @Operator = ' + @Operator

							SET @SQL_Join_Multiply = ''
							
							SELECT
								@SQL_Join_Multiply = @SQL_Join_Multiply + CASE WHEN DCL.BaseObjectYN = 0 AND DCL.DataType <> 'float' THEN CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '(OP.[' + ColumnName + '] = F.[' + ColumnName + '] OR OP.[' + ColumnName + '] IS NULL) AND' ELSE '' END
							FROM
								#DataClassList DCL
							WHERE
								DCL.DataClassID = @MasterDataClassID AND
								DCL.ReportOnlyYN = 0 AND
								DCL.StaticSetting IS NULL AND
								NOT EXISTS (SELECT 1 FROM #JoinExclusion JE WHERE JE.InitialStepID = @InitialStepID AND JE.DimensionName + '_MemberID' = DCL.ColumnName)
							ORDER BY
								SortOrder

							SET @SQL_Join_Multiply = LEFT(@SQL_Join_Multiply, LEN(@SQL_Join_Multiply) - 4) 

							IF @DebugBM & 2 > 0 
								BEGIN
									SELECT
										DCL.*
									FROM
										#DataClassList DCL
									WHERE
										DCL.DataClassID = @MasterDataClassID AND
										DCL.ReportOnlyYN = 0 AND
										DCL.StaticSetting IS NULL
									ORDER BY
										SortOrder

									SELECT 
										*
									FROM #JoinExclusion JE WHERE JE.InitialStepID = @InitialStepID 
							
									SELECT [@SQL_Join_Multiply] = @SQL_Join_Multiply
								END
							
							IF LEFT(@MemberKey, 1) = '@'
								BEGIN
									EXEC [spGet_Variable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @Variable_MemberKey = @MemberKey, @Variable_Value = @Variable_Value OUT
									IF @DebugBM & 2 > 0 SELECT [@MemberKey] = @MemberKey, [@Variable_Value] = @Variable_Value
								END
							ELSE
								BEGIN
									TRUNCATE TABLE #BR01_FACT_Step

									IF @DebugBM & 2 > 0 
										BEGIN
											SELECT [@SQL_Insert] = @SQL_Insert, [@BaseObject] = @BaseObject, [@DestinationMemberKey] = @DestinationMemberKey
										END

									SET @SQLStatement = '
						INSERT INTO #BR01_FACT_Step
							(' + @SQL_Insert + '
							)
						SELECT' + @SQL_Insert + '
						FROM
							#BR01_FACT F
						WHERE
							F.[' + @BaseObject + '_MemberID] = ' + CONVERT(NVARCHAR(20), @DestinationMemberID)

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

						IF @DebugBM & 2 > 0
							BEGIN
								SET @SQLStatement = '
									SELECT
										[Step_' + CONVERT(nvarchar(15), @BR01_StepID) + '_#BR01_FACT_Step] = ' + CONVERT(nvarchar(15), @BR01_StepID) + ', TempTable = ''#BR01_FACT_Step'', *
									FROM
										#BR01_FACT_Step
									WHERE
										' + @BaseObject + '_MemberID = ' + CONVERT(NVARCHAR(20), @DestinationMemberID)

								IF @DebugBM & 1 > 0 PRINT @SQLStatement
								EXEC (@SQLSTatement)
							END

									SET @SQLStatement = '
						DELETE #BR01_FACT
						WHERE
							[' + @BaseObject + '_MemberID] = ' + CONVERT(NVARCHAR(20), @DestinationMemberID)

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)

									IF @Operator IN ('*', '/')
										BEGIN
											SET @SQL_Select_Multiply = REPLACE(@SQL_Select_Multiply_Master, '@Operator', @Operator)
											
											IF @DebugBM & 2 > 0 
												BEGIN
													SET @SQLStatement = '
								SELECT [SubQuery] = ''Multiply inner join'', ' + @SQL_Insert_Right + '
								FROM
									#BR01_FACT
								WHERE
									[' + @BaseObject + '_MemberID] = ' + CONVERT(NVARCHAR(20), @MemberID) + ' AND
									([InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ' OR ' + CONVERT(nvarchar(10), ISNULL(@InitialStepID, 0)) + ' = ' + CONVERT(nvarchar(10), ISNULL(@InitialStepID_Compare, 0)) + ') AND
									[' + @MasterDataClassName + '_Value] <> 0'

													EXEC (@SQLStatement)

												END
											
											SET @SQLStatement = '
						INSERT INTO #BR01_FACT
							(' + @SQL_Insert + '
							)
						SELECT' + @SQL_Select_Multiply + ' 
						FROM
							#BR01_FACT_Step F
							INNER JOIN (
								SELECT' + @SQL_Insert_Right + '
								FROM
									#BR01_FACT
								WHERE
									[' + @BaseObject + '_MemberID] = ' + CONVERT(NVARCHAR(20), @MemberID) + ' AND
									([InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ' OR ' + CONVERT(nvarchar(10), ISNULL(@InitialStepID, 0)) + ' = ' + CONVERT(nvarchar(10), ISNULL(@InitialStepID_Compare, 0)) + ') AND
									[' + @MasterDataClassName + '_Value] <> 0
									) OP ON' + @SQL_Join_Multiply + '
						WHERE
							F.[' + @BaseObject + '_MemberID] = ' + CONVERT(NVARCHAR(20), @DestinationMemberID)

											IF @DebugBM & 2 > 0 PRINT @SQLStatement
											EXEC (@SQLStatement)
										END
									ELSE IF @Operator IN ('+', '-')
										BEGIN
											SET @SQL_Select_Addition = REPLACE(@SQL_Select_Addition_Master, '@Operator', @Operator)
											SET @SQLStatement = '
						INSERT INTO #BR01_FACT
							(' + @SQL_Insert + '
							)
						SELECT' + @SQL_Select_Addition + '
						FROM
							(
							SELECT DISTINCT' + @SQL_Select_Addition_Right + '
							FROM
								#BR01_FACT_Step'

											SET @SQLStatement = @SQLStatement + '
							UNION SELECT DISTINCT' + @SQL_Select_Addition_Right + '
							FROM
								#BR01_FACT'

											SET @SQLStatement = @SQLStatement + '
							WHERE
								[' + @BaseObject + '_MemberID] = ' + CONVERT(NVARCHAR(20), @MemberID) + ' AND
								([InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ' OR ' + CONVERT(nvarchar(10), ISNULL(@InitialStepID, 0)) + ' = ' + CONVERT(nvarchar(10), ISNULL(@InitialStepID_Compare, 0)) + ')
							) M
							LEFT JOIN #BR01_FACT_Step F ON' + @SQL_Join_Addition1 + '
							LEFT JOIN #BR01_FACT OP ON
								OP.[' + @BaseObject + '_MemberID] = ' + CONVERT(NVARCHAR(20), @MemberID) + ' AND' + @SQL_Join_Addition2 + ' 
								(OP.[InitialStepID] = ' + CONVERT(nvarchar(10), @InitialStepID) + ' OR ' + CONVERT(nvarchar(10), ISNULL(@InitialStepID, 0)) + ' = ' + CONVERT(nvarchar(10), ISNULL(@InitialStepID_Compare, 0)) + ')'

											IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000 
												BEGIN
													PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; @InitialStepID = ' + CONVERT(nvarchar(10), @InitialStepID) + ' #BR01_FACT Destination'
													SET @Comment = '#BR01_FACT Destination; @InitialStepID = ' + CONVERT(nvarchar(10), @InitialStepID)
													EXEC [dbo].[spSet_wrk_Debug]
														@UserID = @UserID,
														@InstanceID = @InstanceID,
														@VersionID = @VersionID,
														@DatabaseName = 'pcINTEGRATOR',
														@CalledProcedureName = @ProcedureName,
														@Comment = @Comment, 
														@SQLStatement = @SQLStatement

													SELECT [TempTable_#BR01_FACT_Destination] = '#BR01_FACT', * FROM #BR01_FACT
												END
											ELSE IF @DebugBM & 2 > 0
												PRINT COALESCE(@SQLStatement, '@SQLStatement=null')

											EXEC (@SQLStatement)

										END
								END

							SET @BR01_StepPartID = @BR01_StepPartID + 1
						END

						IF @ModifierID IN (10, 20)
							BEGIN
								IF @ModifierID = 10
									SET @SQLStatement = '
										UPDATE #BR01_FACT
										SET
											' + @MasterDataClassName + '_Value = ' + @MasterDataClassName + '_Value * ' + CONVERT(nvarchar(50), @Parameter) + '
										WHERE
											' + @BaseObject + '_MemberID = ' + CONVERT(NVARCHAR(20), @DestinationMemberID)

								ELSE IF @ModifierID = 20
									SET @SQLStatement = '
										UPDATE #BR01_FACT
										SET
											' + @MasterDataClassName + '_Value = ' + @MasterDataClassName + '_Value / ' + CONVERT(NVARCHAR(50), @Parameter) + '
										WHERE
											' + @BaseObject + '_MemberID = ' + CONVERT(NVARCHAR(20), @DestinationMemberID)

								IF @DebugBM & 2 > 0 PRINT @SQLStatement
								EXEC (@SQLSTatement)
							END

						SET @SQLStatement = '
							UPDATE #BR01_FACT
							SET
								' + @MasterDataClassName + '_Value = ' + @MasterDataClassName + '_Value * ' + CONVERT(nvarchar(50), @MultiplyWith) + '
							WHERE
								' + @BaseObject + '_MemberID = ' + CONVERT(NVARCHAR(20), @DestinationMemberID)

						IF @DebugBM & 1 > 0 PRINT @SQLStatement
						EXEC (@SQLSTatement)

						IF @DebugBM & 2 > 0
							BEGIN
								SET @SQLStatement = '
									SELECT
										[Step_' + CONVERT(nvarchar(15), @BR01_StepID) + '] = ' + CONVERT(nvarchar(15), @BR01_StepID) + ', TempTable = ''#BR01_FACT'', *
									FROM
										#BR01_FACT
									WHERE
										' + @BaseObject + '_MemberID = ' + CONVERT(NVARCHAR(20), @DestinationMemberID)

								IF @DebugBM & 1 > 0 PRINT @SQLStatement
								EXEC (@SQLSTatement)
							END

					FETCH NEXT FROM BR01_Destination_Cursor INTO @BR01_StepID, @DestinationMemberKey, @DestinationMemberID, @ModifierID, @MultiplyWith, @Parameter, @Decimal, @MasterMemberKey, @MasterMemberID, @InitialStepID
				END

		CLOSE BR01_Destination_Cursor
		DEALLOCATE BR01_Destination_Cursor

		IF @DebugBM & 1 > 0 EXEC('SELECT TempTable = ''#BR01_FACT'', * FROM #BR01_FACT WHERE [InitialStepID] IS NULL ORDER BY ' + @BaseObject + '_MemberID, Time_MemberID')
-- sega
IF @DebugBM & 2 > 0
	BEGIN
		IF OBJECT_ID (N'pcINTEGRATOR_Log.dbo.tmp_BR01_FACT_sega', N'U') IS NOT NULL DROP TABLE pcINTEGRATOR_Log.dbo.tmp_BR01_FACT_sega
		SELECT * INTO pcINTEGRATOR_Log.dbo.tmp_BR01_FACT_sega FROM #BR01_FACT 
	END
--------
	SET @Step = 'Delete existing records from FACT table'
		SET @SQLStatement = '
			INSERT INTO #BaseObject_Member
				(
				MemberId,
				MemberKey
				)
			SELECT
				[MemberID] = F.[' + @BaseObject + '_MemberID],
				[MemberKey] = D.Label
			FROM
				[' + @DataClassDatabase + '].[dbo].[S_DS_' + @BaseObject + '] D
				INNER JOIN (SELECT DISTINCT [' + @BaseObject + '_MemberID] FROM #BR01_FACT WHERE [InitialStepID] IS NULL) F ON F.[' + @BaseObject + '_MemberID] = D.[MemberId]'

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Selected = @Selected + @@ROWCOUNT
		
		IF @DebugBM & 2 > 0 SELECT [TempTable_#BaseObject_Member] = '#BaseObject_Member', * FROM #BaseObject_Member ORDER BY [MemberKey]

		SELECT
			@SQL_Join_Delete = ''
		SELECT
			@SQL_Join_Delete = @SQL_Join_Delete + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'INNER JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_' + REPLACE(DCL.ColumnName, '_MemberID', '') + '] [' + REPLACE(DCL.ColumnName, '_MemberID', '') + '] ON [' + REPLACE(DCL.ColumnName, '_MemberID', '') + '].[MemberId] = F.[' + REPLACE(DCL.ColumnName, '_MemberID', '') + '_MemberId] AND [' + REPLACE(DCL.ColumnName, '_MemberID', '') + '].[Label] COLLATE DATABASE_DEFAULT = ' + '''' + DCL.StaticSetting + ''''
		FROM
			#DataClassList DCL
		WHERE
			DCL.DataClassID = @MasterDataClassID AND
			DCL.DataType <> 'float' AND
			DCL.StaticSetting IS NOT NULL AND
			DCL.ColumnName <> 'WorkflowState_MemberKey'
		ORDER BY
			SortOrder

		SET @SQLStatement = '
			DELETE F
			FROM
				[' + @DataClassDatabase + '].[dbo].[FACT_' + @MasterDataClassName + '_default_partition] F
				INNER JOIN #BaseObject_Member BOM ON BOM.[MemberId] = F.[' + @BaseObject + '_MemberId]' + @SQL_Join_Delete + '
			WHERE
				F.Time_MemberId BETWEEN ' + CONVERT(nvarchar(10), @FromTime) + ' AND ' + CONVERT(nvarchar(10), @ToTime)

		IF @DebugBM & 2 > 0 PRINT @SQLStatement
		EXEC (@SQLStatement)
		
		SET @Deleted = @Deleted + @@ROWCOUNT

	SET @Step = 'Write back to FACT table'
		SELECT
			@SQL_Insert = '',
			@SQL_Select = '',
			@SQL_Join = ''

		SET @SQLStatement = '
			UPDATE CT 
			SET 
				CT.MemberID = D.MemberId
			FROM 
				#BR01_Initial_Cursor_Table CT
				JOIN ['+ @DataClassDatabase + '].[dbo].[S_DS_' + @BaseObject + '] D ON D.[Label] = CT.MemberKey'	
	
		SELECT
			@SQL_Insert = @SQL_Insert + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + DCL.ColumnName + '],',
			-- @SQL_Select = @SQL_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + DCL.ColumnName + '] = ISNULL([' + DCL.ColumnName + '], -1),',
			@SQL_Select = @SQL_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + DCL.ColumnName + '] = ISNULL(' + CASE WHEN DCL.StaticSetting IS NULL THEN '[Raw].[' + DCL.ColumnName + ']' ELSE '[' + REPLACE(DCL.ColumnName, '_MemberID', '') +'].[MemberID]' END + ', -1),',
			--@SQL_Select = @SQL_Select + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + '[' + DCL.ColumnName + '] = ISNULL(' + CASE WHEN DCL.StaticSetting IS NULL THEN '[Raw].[' + DCL.ColumnName + ']' ELSE '''' + DCL.StaticSetting + '''' END + ', -1),',
			--@SQL_Join = '' -- @SQL_Join + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LEFT JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_' + REPLACE(DCL.ColumnName, '_MemberID', '') + '] [' + REPLACE(DCL.ColumnName, '_MemberID', '') + '] ON [' + REPLACE(DCL.ColumnName, '_MemberID', '') + '].Label COLLATE DATABASE_DEFAULT = ' + CASE WHEN DCL.StaticSetting IS NULL THEN '[Raw].[' + DCL.ColumnName + ']' ELSE '''' + DCL.StaticSetting + '''' END
			@SQL_Join =  CASE WHEN DCL.StaticSetting IS NULL THEN @SQL_Join + ''
								ELSE @SQL_Join + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + 'LEFT JOIN [' + @DataClassDatabase + '].[dbo].[S_DS_' + REPLACE(DCL.ColumnName, '_MemberID', '') + '] [' + REPLACE(DCL.ColumnName, '_MemberID', '') + '] ON [' + REPLACE(DCL.ColumnName, '_MemberID', '') + '].Label COLLATE DATABASE_DEFAULT = ' + CASE WHEN DCL.StaticSetting IS NULL THEN '[Raw].[' + DCL.ColumnName + ']' ELSE '''' + DCL.StaticSetting + '''' END
								END
		FROM
			#DataClassList DCL
		WHERE
			DCL.DataClassID = @MasterDataClassID AND
			DCL.DataType <> 'float'
		ORDER BY
			SortOrder

		SET @SQLStatement = '
			INSERT INTO [' + @DataClassDatabase + '].[dbo].[FACT_' + @MasterDataClassName + '_default_partition]
				(' + @SQL_Insert + '
				[ChangeDatetime],
				[Userid],
				[' + @MasterDataClassName + '_Value]
				)
			SELECT' + @SQL_Select + '
				[ChangeDatetime] = GetDate(),
				[Userid] = suser_name(),
				[' + @MasterDataClassName + '_Value] = [Raw].[' + @MasterDataClassName + '_Value]
			FROM'

		SET @SQLStatement = @SQLStatement + ' 
				#BR01_FACT [Raw]' + @SQL_Join + '
			WHERE
				[Raw].[InitialStepID] IS NULL'

		IF @DebugBM & 2 > 0 AND LEN(@SQLStatement) > 4000 
			BEGIN
				PRINT 'Length of @SQLStatement more than 4000, see pcINTEGRATOR_Log..wrk_Debug; ' + @Step
				SET @Comment = '#BR01_FACT; ' + @Step
				EXEC [dbo].[spSet_wrk_Debug]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@DatabaseName = 'pcINTEGRATOR',
					@CalledProcedureName = @ProcedureName,
					@Comment = @Comment, 
					@SQLStatement = @SQLStatement
			END
		ELSE IF @DebugBM & 2 > 0
			PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Refresh Fact table'
		IF @CallistoRefreshYN <> 0
			BEGIN
				EXEC [spRun_Job_Callisto_Generic] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @StepName = 'Refresh', @ModelName = @MasterDataClassName, @AsynchronousYN = @CallistoRefreshAsynchronousYN, @JobID = @JobID
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #PipeStringSplit
		DROP TABLE #DimensionSetting
		DROP TABLE #FilterTable
		DROP TABLE #DataClassList
		DROP TABLE #Modifier
		DROP TABLE #Modifier_Value
		DROP TABLE #BR01_Initial_Cursor_Table
		DROP TABLE #BR01_Destination_Cursor_Table
		DROP TABLE #BR01_FACT
		DROP TABLE #BR01_FACT_Step
		DROP TABLE #BaseObject_Member
		DROP TABLE #JoinExclusion
--		DROP TABLE #Time

	SET @Step = 'Run PostExec'
		--Add security check (Correct InstanceID)
--		IF @PostExec IS NOT NULL
--			EXEC (@PostExec)

	SET @Step = 'Set @Duration'
		SET @Duration = GETDATE() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GETDATE() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
