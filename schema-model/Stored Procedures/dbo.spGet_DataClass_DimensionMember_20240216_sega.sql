SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_DataClass_DimensionMember_20240216_sega]
	@UserID INT = NULL,
	@InstanceID INT = NULL,
	@VersionID INT = NULL,

	@DataClassID INT = NULL, --Mandatory
	@PropertyList NVARCHAR(1024) = NULL,
	@DimensionList NVARCHAR(1024) = NULL,
	@DimensionListExcluded NVARCHAR(1024) = NULL,
	@AssignmentID INT = NULL,
	@OnlySecuredDimYN BIT = 0,
	@ShowAllMembersYN BIT = 0,
	@OnlyDataClassDimMembersYN BIT = 1,
	@UseCacheYN BIT = 1,
	@Parent_MemberKey NVARCHAR(1024) = NULL, --Sample: 'GL_Student_ID=All_'
	@Hierarchy NVARCHAR(1024) = NULL, --Sample: 'GL_Student_ID=0'
	@NodeTypeBM INT = 1023,
	@NoneYN BIT = 1,
	@ShowConsoStatusYN BIT = 0,

	@JobID INT = NULL,
	@JobLogID INT = NULL,
	@Rows INT = NULL,
	@ProcedureID INT = 880000528,
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
EXEC [spGet_DataClass_DimensionMember]
	@UserID = -10,
	@InstanceID = 574,
	@VersionID = 1081,
	@DataClassID = 5718,
	@DimensionList = '-77',
	@ShowAllMembersYN = 1,
	@Debug = 1

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spGet_DataClass_DimensionMember',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "114"},
		{"TKey" : "VersionID",  "TValue": "1004"},
		{"TKey" : "DataClassID",  "TValue": "1004"}
		]'

EXEC [dbo].[spGet_DataClass_DimensionMember]
	@UserID = -10,
	@InstanceID = -1335,
	@VersionID = -1273,
	@DataClassID = 7480,
	@DimensionList = '-77',
	@ShowAllMembersYN = 1,
	@DebugBM = 3

EXEC [dbo].[spGet_DataClass_DimensionMember]
	@UserID = -10,
	@InstanceID = -1335,
	@VersionID = -1273,
	@DataClassID = 7480,
	@DimensionList = '-4|-35',
	@DebugBM = 3

EXEC [spGet_DataClass_DimensionMember]
	@UserID = -10,
	@InstanceID = 413,
	@VersionID = 1008,
	@DataClassID = 1028,
	@DimensionList = '-2|-3|-63',
	@Debug = 1

EXEC [spGet_DataClass_DimensionMember]
	@UserID = -10,
	@InstanceID = 574,
	@VersionID = 1045,
	@DataClassID = 13964,
	@Debug = 1

EXEC [spGet_DataClass_DimensionMember]
	@UserID = -10,
	@InstanceID = -1590,
	@VersionID = -1590,
	@DataClassID = 18071,
	@DimensionList='-1|-77',
	@Debug = 1

	CLOSE DimensionMember_Cursor
	DEALLOCATE DimensionMember_Cursor

EXEC spGet_DataClass_DimensionMember @UserID='2147', @InstanceID='454',@VersionID='1021', @DataClassID = 7736, @DimensionList = '-2|-3|-63', @Debug = 1
EXEC spGet_DataClass_DimensionMember @UserID=-10, @InstanceID=454, @VersionID=1021, @DataClassID=7736, @DimensionList='-2|-3|-63', @OnlySecuredDimYN=0, @ShowAllMembersYN=0, @OnlyDataClassDimMembersYN=1, @Selected=0, @JobID=880000209, @Debug=0
EXEC spGet_DataClass_DimensionMember @UserID='9392', @InstanceID='523',@VersionID='1051', @DataClassID = 5522, @DimensionList = '5412', @OnlyDataClassDimMembersYN = 0, @Parent_MemberKey = '5412=All_', @DebugBM = 3
EXEC spGet_DataClass_DimensionMember @UserID='26624', @InstanceID='515',@VersionID='1040', @DataClassID = 11795, @DimensionList = '7959', @OnlyDataClassDimMembersYN = 1, @UseCacheYN=1, @DebugBM = 3

EXEC [dbo].[spPortalGet_DataClass_Data]
	@UserID = -10,
	@InstanceID = 454,
	@VersionID = 1021,
	@DataClassID = 7736,
	@ResultTypeBM = 3,
	@GroupBy = 'Time|GL_Cost_Center',
	@Measure = 'Financials',
	@Filter = 'Scenario=ACTUAL|Time=2018|Account=AC_SALESNET',
	@Hierarchy = 'Account=1',
	@DimensionList = '-2|-3|-63',

EXEC [spGet_DataClass_DimensionMember] @GetVersion = 1
*/
DECLARE
	@DimensionID int,
	@DataClassName nvarchar(100),
	@DataClassTypeID int,
	@DimensionName nvarchar(100),
	@DimensionNameProblem  nvarchar(100),
	@HierarchyName nvarchar(100),
	@StorageTypeBM_Dimension int,
	@StorageTypeBM_DataClass int,
	@CallistoDatabase nvarchar(100),
	@ETLDatabase nvarchar(100),
	@SQLStatement nvarchar(max),
	@InstanceID_String nvarchar(10),
	@CreateTempTableYN bit = 0,
	@Property nvarchar(50),
	@SQLPropertyList nvarchar(1024),
	@SQLPropertyListTrick nvarchar(1024),
	@SQLPropertyNotExists nvarchar(1024),
	@StartPoint int = 1,
	@LoopStep int = 0,
	@GroupYN bit = 0,
	@ApplicationID int,
	@ClosedMonth int,
	@TimeFrom int,
	@TimeTo int,
	@CalledYN bit = 1,
	@LeafLevelFilter_RA nvarchar(max),
	@PipeStringSplitCreatedYN bit = 0,
	@ColumnNo nvarchar(20),
	@Parent_MemberID bigint,
	@DimensionTypeID int,
	@SumMemberID bigint = 0,
	@WriteAccessYN bit = 0,

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
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version NVARCHAR(50) = '2.1.2.2198'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return rows for all Dimensions included in selected DataClass.',
			@MandatoryParameter = 'DataClassID'

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2140' SET @Description = 'Updated log handling.'
		IF @Version = '2.0.0.2141' SET @Description = 'Return data when @AssignmentID IS NULL with WriteYN set to 0.'
		IF @Version = '2.0.1.2143' SET @Description = 'Check ReadAccess.'
		IF @Version = '2.0.2.2146' SET @Description = 'DB-87: Implemented parameter @DimensionList to reduce number of returned dimensions.'
		IF @Version = '2.0.2.2147' SET @Description = 'Handle DataClassTypeID = -7 (FullAccount).'
		IF @Version = '2.0.2.2148' SET @Description = 'Check for existing cursor.'
		IF @Version = '2.0.2.2149' SET @Description = 'Added parameter @ShowAllMembersYN'
		IF @Version = '2.0.3.2151' SET @Description = 'Renamed from spGet_DimensionMember_DataClass to spGet_DataClass_DimensionMember. Test on NodeTypeBM = 8 to set WriteYN.'
		IF @Version = '2.0.3.2153' SET @Description = 'DB-376: Reports are not working - Incorrect syntax near the keyword ''Group''.'
		IF @Version = '2.1.0.2157' SET @Description = 'Added parameter @DimensionListExcluded.'
		IF @Version = '2.1.0.2161' SET @Description = 'Use fact table instead of view. Added parameter @OnlyDataClassDimMembersYN.'
		IF @Version = '2.1.0.2162' SET @Description = 'DB-573: Increased column size of [MemberDescription] to (512) in temp table #Members.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added parameter @UseCacheYN.'
		IF @Version = '2.1.0.2164' SET @Description = 'Added parameter @Parent_MemberKey. DB-608: Fixed missing BEGIN-END bug.'
		IF @Version = '2.1.1.2168' SET @Description = 'Applied table hint WITH (NOLOCK) when reading from @CallistoDatabase FACT table in @Step = Run DimensionMember_Cursor.'
		IF @Version = '2.1.1.2169' SET @Description = 'Handle DimensionType AutoMultiDim.'
		IF @Version = '2.1.1.2171' SET @Description = 'Filter on RA.StorageTypeBM & 2 > 0 when creating cursor table. Avoid infinite loops when members points to non existing parents. Added parameters @NodeTypeBM and @NoneYN.'
		IF @Version = '2.1.1.2177' SET @Description = 'Handle when NodeTypeBM exists in dimension table.'
		IF @Version = '2.1.2.2179' SET @Description = 'Reinitialize variable @SumMemberID in dimension cursor. Always use SortOrder from table DataClass_Dimension. Set #PropertyList for all dimensions initially.'
		IF @Version = '2.1.2.2182' SET @Description = 'Set correct object name (for MemberKey) when returning resultset.'
		IF @Version = '2.1.2.2183' SET @Description = 'Set correct InstanceID for DimensionID = -77 (TimeView).'
		IF @Version = '2.1.2.2195' SET @Description = 'Fixed ReverseSign and other cases when the Properties are set in the PropoertyList but doesn''t not exists in a Dimension.'
		IF @Version = '2.1.2.2198' SET @Description = 'DB-1519: Handle WriteAccess from Workflow setup of an Assignment.'

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

		SELECT
			@DataClassName = DataClassName,
			@DataClassTypeID = DataClassTypeID,
			@StorageTypeBM_DataClass = StorageTypeBM,
			@InstanceID_String = CASE LEN(ABS(@InstanceID)) WHEN 1 THEN '000' WHEN 2 THEN '00' WHEN 3 THEN '0' ELSE '' END + CONVERT(nvarchar(10), ABS(@InstanceID))
		FROM
			DataClass
		WHERE
			InstanceID = @InstanceID AND
			DataClassID = @DataClassID

		SELECT
			@ClosedMonth = S.ClosedMonth,
			@TimeFrom = W.TimeFrom,
			@TimeTo = W.TimeTo
		FROM
			[Assignment] A
			INNER JOIN [Workflow] W ON W.WorkflowID = A.WorkflowID
			INNER JOIN [Scenario] S ON S.ScenarioID = W.ScenarioID
		WHERE
			A.InstanceID = @InstanceID AND
			A.AssignmentID = @AssignmentID

		IF @DebugBM & 2 > 0 SELECT [@DataClassTypeID] = @DataClassTypeID, [@StorageTypeBM_DataClass] = @StorageTypeBM_DataClass, [@ShowAllMembersYN] = @ShowAllMembersYN

	SET @Step = 'Create temp table #Dimension'
		CREATE TABLE #Dimension (DimensionID int)

		INSERT INTO #Dimension (DimensionID) SELECT [DimensionID] = [Value] FROM STRING_SPLIT (@DimensionList, '|')

		IF (SELECT COUNT(1) FROM #Dimension) = 0
			INSERT INTO #Dimension (DimensionID) SELECT [DimensionID] = 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#Dimension', * FROM #Dimension ORDER BY DimensionID

	SET @Step = 'Create temp table #DimensionExcluded'
		CREATE TABLE #DimensionExcluded (DimensionID int)

		INSERT INTO #DimensionExcluded (DimensionID) SELECT [DimensionID] = [Value] FROM STRING_SPLIT (@DimensionListExcluded, '|')

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionExcluded', * FROM #DimensionExcluded ORDER BY DimensionID

	SET @Step = 'If needed create temp table #PipeStringSplit'
		IF OBJECT_ID (N'tempdb..#PipeStringSplit', N'U') IS NULL
			BEGIN
				CREATE TABLE #PipeStringSplit
					(
					[TupleNo] int,
					[PipeObject] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[EqualityString] nvarchar(10) COLLATE DATABASE_DEFAULT,
					[PipeFilter] nvarchar(max) COLLATE DATABASE_DEFAULT
					)
			END

	SET @Step = 'If needed create temp table #HierarchyList'
		IF OBJECT_ID (N'tempdb..#HierarchyList', N'U') IS NULL
			BEGIN
				CREATE TABLE #HierarchyList
					(
					DimensionID int,
					DimensionName nvarchar(50) COLLATE DATABASE_DEFAULT,
					HierarchyNo int,
					HierarchyName nvarchar(50) COLLATE DATABASE_DEFAULT
					)

				IF LEN(@Hierarchy) > 3
					BEGIN
						TRUNCATE TABLE #PipeStringSplit

						EXEC [spGet_PipeStringSplit] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @PipeString = @Hierarchy, @Debug = 0

						INSERT INTO #HierarchyList
							(
							[DimensionName],
							[HierarchyNo]
							)
						SELECT
							[DimensionName] = PSS.[PipeObject],
							[HierarchyNo] = PSS.[PipeFilter]
						FROM
							#PipeStringSplit PSS

						UPDATE HL
						SET
							DimensionID = D.DimensionID
						FROM
							#HierarchyList HL
							INNER JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND D.DimensionName = HL.DimensionName

						UPDATE HL
						SET
							HierarchyName = CASE WHEN DH.HierarchyName IS NULL AND HL.HierarchyNo = 0 THEN HL.DimensionName ELSE DH.HierarchyName END
						FROM
							#HierarchyList HL
							LEFT JOIN DimensionHierarchy DH ON DH.InstanceID = @InstanceID AND DH.DimensionID = HL.DimensionID AND DH.HierarchyNo = HL.HierarchyNo

						IF @DebugBM & 2 > 0 SELECT TempTable = '#HierarchyList', * FROM #HierarchyList
					END
			END

		IF @DebugBM & 16 > 0 SELECT [Step] = 'Initial settings', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

	SET @Step = 'Create temp table #Parent_MemberKey'
		CREATE TABLE #Parent_MemberKey ([DimensionName] nvarchar(100), [Parent_MemberKey] nvarchar(100))
		IF @Parent_MemberKey IS NOT NULL
			BEGIN
				TRUNCATE TABLE #PipeStringSplit

				EXEC [spGet_PipeStringSplit]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@PipeString = @Parent_MemberKey,
					@JobID = @JobID,
					@Debug = @DebugSub

				IF @DebugBM & 2 > 0 SELECT TempTable = '#PipeStringSplit', * FROM #PipeStringSplit ORDER BY TupleNo, PipeObject

				INSERT INTO #Parent_MemberKey ([DimensionName], [Parent_MemberKey]) SELECT [DimensionName] = [PipeObject], [Parent_MemberKey] = [PipeFilter] FROM #PipeStringSplit

				IF @DebugBM & 2 > 0 SELECT TempTable = '#Parent_MemberKey', * FROM #Parent_MemberKey ORDER BY [DimensionName]
			END

	SET @Step = 'If needed fill temp table #DimensionList'
		IF OBJECT_ID (N'tempdb..#DimensionList', N'U') IS NULL
			BEGIN
				SET @CreateTempTableYN = 1

				CREATE TABLE #DimensionList
					(
					[DimensionID] int,
					[DimensionName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[DimensionTypeID] int,
					[StorageTypeBM] int,
					[SortOrder] int,
					[SelectYN] bit,
					[ReadSecurityEnabledYN] bit
					)

				IF OBJECT_ID (N'tempdb..#FilterTable', N'U') IS NULL
					BEGIN
						INSERT INTO #DimensionList
							(
							[DimensionID],
							[DimensionName],
							[DimensionTypeID],
							[StorageTypeBM],
							[SortOrder],
							[SelectYN],
							[ReadSecurityEnabledYN]
							)
						SELECT DISTINCT
							[DimensionID] = D.[DimensionID],
							[DimensionName] = D.[DimensionName],
							[DimensionTypeID] = D.[DimensionTypeID],
							[StorageTypeBM] = DST.[StorageTypeBM],
							[SortOrder] = ISNULL(DCD.[SortOrder], 0),
							[SelectYN] = 1,
							[ReadSecurityEnabledYN] = ISNULL(DST.[ReadSecurityEnabledYN], 0)
						FROM
							#Dimension D1
							LEFT JOIN DataClass_Dimension DCD ON DCD.InstanceID = @InstanceID AND DCD.VersionID = @VersionID AND DCD.DataClassID = @DataClassID AND DCD.[SelectYN] <> 0 AND (DCD.SortOrder > 0 OR @DataClassTypeID <> -7) AND (DCD.DimensionID = D1.DimensionID OR D1.DimensionID = 0)
							LEFT JOIN Dimension D ON D.InstanceID IN (0, @InstanceID) AND (D.DimensionID = D1.DimensionID OR (D1.DimensionID = 0 AND D.DimensionID = DCD.DimensionID)) AND D.DimensionID <> 0
							LEFT JOIN Dimension_StorageType DST ON DST.InstanceID IN (0, @InstanceID) AND DST.VersionID IN (0, @VersionID) AND (DST.DimensionID = D1.DimensionID OR (D1.DimensionID = 0 AND DST.DimensionID = DCD.DimensionID))
						ORDER BY
							ISNULL(DCD.[SortOrder], 0)
					END
				ELSE
					BEGIN
						INSERT INTO #DimensionList
							(
							[DimensionID],
							[DimensionName],
							[DimensionTypeID],
							[StorageTypeBM],
							[SortOrder],
							[SelectYN],
							[ReadSecurityEnabledYN]
							)
						SELECT DISTINCT
							[DimensionID] = FT.[DimensionID],
							[DimensionName] = FT.[DimensionName],
							[DimensionTypeID] = FT.[DimensionTypeID],
							[StorageTypeBM] = FT.[StorageTypeBM],
							[SortOrder] = FT.[SortOrder],
							[SelectYN] = 1,
							[ReadSecurityEnabledYN] = ISNULL(DST.[ReadSecurityEnabledYN], 0)
						FROM
							#FilterTable FT
							LEFT JOIN Dimension_StorageType DST ON DST.[InstanceID] IN (0, @InstanceID) AND DST.[VersionID] IN (0, @VersionID) AND DST.[DimensionID] = FT.[DimensionID]
						ORDER BY
							FT.SortOrder
					END
			END
		ELSE
			BEGIN
				UPDATE DL
				SET
					[SortOrder] = DCD.[SortOrder]
				FROM
					#DimensionList DL
					INNER JOIN DataClass_Dimension DCD ON DCD.[InstanceID] = @InstanceID AND DCD.[VersionID] = @VersionID AND DCD.[DataClassID] = @DataClassID AND DCD.[DimensionID] = DL.[DimensionID]
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionList', * FROM #DimensionList ORDER BY SortOrder

		IF (SELECT COUNT(1) FROM #DimensionList DL WHERE StorageTypeBM & 4 > 0) > 0 OR @StorageTypeBM_DataClass & 4 > 0
			BEGIN
				SELECT @ApplicationID = MAX(ApplicationID) FROM [Application] WHERE InstanceID = @InstanceID AND VersionID = @VersionID AND SelectYN <> 0
				SELECT @CallistoDatabase = DestinationDatabase, @ETLDatabase = ETLDatabase FROM [Application] WHERE ApplicationID = @ApplicationID
				IF @DebugBM & 2 > 0 SELECT ApplicationID = @ApplicationID, CallistoDatabase = @CallistoDatabase, ETLDatabase = @ETLDatabase
			END

	SET @Step = 'Check if called, else create #ReadAccess'
		IF OBJECT_ID (N'tempdb..#ReadAccess', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #ReadAccess
					(
					[DimensionID] int,
					[DimensionName] nvarchar(100),
					[StorageTypeBM] int,
					[Filter] nvarchar(4000) COLLATE DATABASE_DEFAULT,
					[LeafLevelFilter] nvarchar(max) COLLATE DATABASE_DEFAULT,
					[DataColumn] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[SelectYN] bit
					)

				EXEC [pcINTEGRATOR].[dbo].[spGet_ReadAccess] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @UseCacheYN=@UseCacheYN, @JobID = @JobID, @Debug = @DebugSub
			END

			EXEC [pcINTEGRATOR].[dbo].[spGet_ReadAccess] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @UseCacheYN=@UseCacheYN, @StorageTypeBM_DataClass = 2, @JobID = @JobID, @Debug = @DebugSub

			IF @DebugBM & 2 > 0 SELECT TempTable = '#ReadAccess', * FROM #ReadAccess

	SET @Step = 'Get WriteAccess on Assignment'
		CREATE TABLE #WorkflowState
			(
			[WorkflowStateID] int,
			[Scenario_MemberKey] nvarchar(50),
			[Scenario_MemberId] bigint,
			[TimeFrom] int,
			[TimeTo] int
			)

		EXEC [pcINTEGRATOR].[dbo].[spGet_WriteAccess] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @AssignmentID = @AssignmentID, @DataClassID = @DataClassID, @JobID = @JobID, @Debug = @DebugSub
		IF @DebugBM & 2 > 0 SELECT TempTable = '#WorkflowState', * FROM #WorkflowState

		SELECT @WriteAccessYN = COUNT(1) FROM #WorkflowState
		IF @DebugBM & 2 > 0 SELECT [@WriteAccessYN] = @WriteAccessYN

	SET @Step = 'Create temp tables'
		CREATE TABLE #DimRows (MemberKey nvarchar(100) COLLATE DATABASE_DEFAULT)

		CREATE TABLE #Members
			(
			MemberID bigint,
			MemberKey nvarchar(100) COLLATE DATABASE_DEFAULT,
			MemberDescription nvarchar(512) COLLATE DATABASE_DEFAULT,
			NodeTypeBM int,
			ParentMemberId bigint,
			SortOrder int
			)

		CREATE TABLE #PropertyList
			(
			[PropertyString] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[DimensionName] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[Property] nvarchar(50) COLLATE DATABASE_DEFAULT,
			[SortOrder] int IDENTITY(1,1)
			)

	SET @Step = 'Fill temp table #PropertyList'
		INSERT INTO #PropertyList
			(
			[PropertyString]
			)
		SELECT
			[PropertyString] = [Value]
		FROM
			STRING_SPLIT (@PropertyList, '|')

		UPDATE #PropertyList
		SET
			[DimensionName] = LEFT([PropertyString], CHARINDEX ('.', [PropertyString]) -1),
			[Property] = SUBSTRING([PropertyString], CHARINDEX ('.', [PropertyString]) + 1, LEN([PropertyString]))
		WHERE
			LEN([PropertyString]) > 0 AND
			CHARINDEX ('.', [PropertyString]) <> 0

		IF @DebugBM & 2 > 0 SELECT TempTable = '#PropertyList', * FROM #PropertyList

	SET @Step = 'Run DimensionMember_Cursor'
		SELECT DISTINCT
			[DimensionID] = DL.[DimensionID],
			[DimensionName] = DL.[DimensionName],
			[DimensionTypeID] = DL.[DimensionTypeID],
			[HierarchyName] = ISNULL(HL.[HierarchyName], DL.[DimensionName]),
			[StorageTypeBM_Dimension] = DL.[StorageTypeBM],
			[LeafLevelFilter_RA] = CASE WHEN @ShowAllMembersYN <> 0 AND RA.LeafLevelFilter = '''#NotAllowed#''' THEN NULL ELSE RA.LeafLevelFilter END,
			[SortOrder] = DL.[SortOrder],
			[Parent_MemberKey] = PMK.[Parent_MemberKey]
		INTO
			#DimensionMember_Cursor
		FROM
			#Dimension D1
			LEFT JOIN #DimensionList DL ON (DL.DimensionID = D1.DimensionID OR D1.DimensionID = 0) AND (DL.[ReadSecurityEnabledYN] <> 0 OR @OnlySecuredDimYN = 0) AND DL.SelectYN <> 0
--			INNER JOIN #DimensionReturnList DRL ON DRL.DimensionID = DL.DimensionID
			LEFT JOIN #ReadAccess RA ON RA.DimensionID = DL.DimensionID AND RA.StorageTypeBM & 2 > 0
			LEFT JOIN #Parent_MemberKey PMK ON PMK.DimensionName = DL.DimensionName
			LEFT JOIN #HierarchyList HL ON HL.DimensionID = D1.DimensionID
		WHERE
			NOT EXISTS (SELECT 1 FROM #DimensionExcluded DE WHERE DE.DimensionID = DL.DimensionID)
		ORDER BY
			DL.SortOrder

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimensionMember_Cursor', * FROM #DimensionMember_Cursor ORDER BY SortOrder

		IF @DebugBM & 16 > 0 SELECT [Step] = 'All initial settings done', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

		IF CURSOR_STATUS('global','DimensionMember_Cursor') >= -1 DEALLOCATE DimensionMember_Cursor
		DECLARE DimensionMember_Cursor CURSOR FOR

			SELECT
				[DimensionID],
				[DimensionName],
				[DimensionTypeID],
				[HierarchyName],
				[StorageTypeBM_Dimension],
				[LeafLevelFilter_RA],
				[Parent_MemberKey]
			FROM
				#DimensionMember_Cursor
			ORDER BY
				[SortOrder],
				[DimensionName]

			OPEN DimensionMember_Cursor
			FETCH NEXT FROM DimensionMember_Cursor INTO @DimensionID, @DimensionName, @DimensionTypeID, @HierarchyName, @StorageTypeBM_Dimension, @LeafLevelFilter_RA, @Parent_MemberKey


			WHILE @@FETCH_STATUS = 0
				BEGIN
					SELECT
						@GroupYN = 0,
						@SumMemberID = 0

					IF @DimensionID = -1
						BEGIN
							CREATE TABLE #Count ([Counter] int)

							SET @SQLStatement = '
								INSERT INTO #Count ([Counter])
								SELECT [Counter] = COUNT(1)
								FROM
									' + @CallistoDatabase + '.sys.Tables T
									INNER JOIN ' + @CallistoDatabase + '.sys.Columns C ON C.object_id = T.object_id AND C.[name] = ''GroupYN''
								WHERE
									T.[name] = ''S_DS_Account'''

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							IF (SELECT [Counter] FROM #Count) > 0
								BEGIN
									SET @GroupYN = 1
									SET @SQLStatement = '
										UPDATE D
										SET
											[GroupYN] = 0
										FROM
											' + @CallistoDatabase + '.[dbo].[S_DS_Account] D

										UPDATE D
										SET
											[GroupYN] = 1
										FROM
											' + @CallistoDatabase + '.[dbo].[S_DS_Account] D
											INNER JOIN
												(
												SELECT
													MemberId = H.ParentMemberID
												FROM
													' + @CallistoDatabase + '.[dbo].[S_DS_Account] D
													INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_HS_Account_Account] H ON H.MemberID = D.MemberID
												GROUP BY
													H.ParentMemberID
												HAVING
													COUNT(D.MemberID) = COUNT(CASE WHEN D.RNodeType = ''L'' THEN 1 END)
												) sub ON sub.MemberId = D.MemberId'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END
							DROP TABLE #Count
						END
					IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName, [@StorageTypeBM_Dimension] = @StorageTypeBM_Dimension, [@PropertyList] = @PropertyList

					TRUNCATE TABLE #DimRows
					TRUNCATE TABLE #Members

					SET @SQLPropertyList = ''
					IF (SELECT COUNT(1) FROM #PropertyList WHERE DimensionName = @DimensionName) > 0
						BEGIN
							SELECT
								@SQLPropertyList = CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + @SQLPropertyList + Property + ','
							FROM
								#PropertyList
							WHERE
								DimensionName = @DimensionName
							ORDER BY
								SortOrder
						END

					IF @DebugBM & 2 > 0 SELECT [TempTable_#PropertyList] = '#PropertyList', * FROM #PropertyList WHERE DimensionName = @DimensionName ORDER BY SortOrder
					IF @DebugBM & 2 > 0 SELECT [@ShowAllMembersYN] = @ShowAllMembersYN

					IF @ShowAllMembersYN = 0
						BEGIN
							--IF @StorageTypeBM_DataClass & 1 > 0 AND @DataClassTypeID = -7
							--	BEGIN
							--		IF @DimensionID = -62
							--			BEGIN
							--				INSERT INTO #DimRows (MemberKey)
							--				SELECT DISTINCT [AccountType]
							--				FROM [pcINTEGRATOR_Data].[dbo].[FullAccount]
							--			END

							--		ELSE IF @DimensionID = -65
							--			BEGIN
							--				INSERT INTO #DimRows (MemberKey)
							--				SELECT DISTINCT [AccountCategory]
							--				FROM [pcINTEGRATOR_Data].[dbo].[FullAccount]
							--			END

							--		ELSE
							--			BEGIN
							--				SELECT
							--					@ColumnNo = CASE WHEN SortOrder <= 9 THEN '0' ELSE '' END + CONVERT(nvarchar(15), SortOrder)
							--				FROM
							--					DataClass_Dimension
							--				WHERE
							--					DataClassID = @DataClassID AND
							--					DimensionID = @DimensionID AND
							--					SortOrder > 0

							--				SET @SQLStatement = '
							--					INSERT INTO #DimRows (MemberKey)
							--					SELECT DISTINCT [SourceCol' + @ColumnNo + ']
							--					FROM [pcINTEGRATOR_Data].[dbo].[FullAccount]'

							--				IF @DebugBM & 2 > 0 PRINT @SQLStatement
							--				EXEC (@SQLStatement)
							--			END
							--	END

							--ELSE
							IF @StorageTypeBM_DataClass & 1 > 0
								BEGIN
									SET @Message = 'StorageTypeBM_DataClass = 1, not yet implemented'
									SET @Severity = 16
									GOTO EXITPOINT
								END

							ELSE IF @StorageTypeBM_DataClass & 2 > 0
								BEGIN
									SET @SQLStatement = '
										INSERT INTO #DimRows (MemberKey)
										SELECT DISTINCT MemberKey = ' + @DimensionName + '_MemberKey
										FROM ' + @ETLDatabase + '.[dbo].[pcDC_' + @InstanceID_String + '_' + @DataClassName + ']'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END

							ELSE IF @StorageTypeBM_DataClass & 4 > 0
								BEGIN
									IF @DebugBM & 16 > 0 SELECT [Step] = 'Before temp table #DimRows is filled for ' + @DimensionName, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)
									IF @StorageTypeBM_Dimension & 4 > 0 AND (@OnlyDataClassDimMembersYN = 0 OR @DimensionTypeID IN (27))

										BEGIN
											SET @SQLStatement = '
												INSERT INTO #DimRows ([MemberKey])
												SELECT DISTINCT [MemberKey] = D.[Label]
												FROM
													' + @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + '] D'

											IF @DebugBM & 2 > 0 PRINT @SQLStatement

											IF @Parent_MemberKey IS NOT NULL
												BEGIN
													SET @SQLStatement = '
														SELECT @InternalVariable = MemberId FROM ' + @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + '] D WHERE [Label] = ''' + @Parent_MemberKey + ''''

													EXEC sp_executesql @SQLStatement, N'@InternalVariable bigint OUT', @InternalVariable = @Parent_MemberID OUT

													IF @DebugBM & 2 > 0 SELECT [@Parent_MemberID] = @Parent_MemberID

													SET @SQLStatement = '
														INSERT INTO #DimRows ([MemberKey])
														SELECT DISTINCT [MemberKey] = D.[Label]
														FROM
															' + @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + '] D
															INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H ON H.MemberId = D.MemberId AND H.ParentMemberId = ' + CONVERT(NVARCHAR(15), @Parent_MemberID)
												END
										END
									ELSE IF @StorageTypeBM_Dimension & 4 > 0
										SET @SQLStatement = '
											INSERT INTO #DimRows ([MemberKey])
											SELECT DISTINCT [MemberKey] = D.[Label]
											FROM
												' + @CallistoDatabase + '.[dbo].[FACT_' + @DataClassName + '_default_partition] F WITH (NOLOCK)
												INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_DS_' + @DimensionName + '] D ON D.[MemberId] = F.[' + @DimensionName + '_MemberId]'

									IF @DebugBM & 2 > 0 PRINT @SQLStatement
									EXEC (@SQLStatement)
								END
						END
					ELSE
						BEGIN
							INSERT INTO #DimRows
								(
								[MemberKey]
								)
							SELECT
								[MemberKey] = '0'
						END

				IF @DebugBM & 2 > 0 SELECT [TempTable_#DimRows] = '#DimRows', * FROM #DimRows
				IF @DebugBM & 16 > 0 SELECT [Step] = 'Temp table #DimRows is filled for ' + @DimensionName, [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

					IF @StorageTypeBM_Dimension & 1 > 0
						BEGIN
							SET @Step = 'DimensionMember_Cursor: @StorageTypeBM_Dimension & 1 > 0'
							INSERT INTO #Members
								(
								MemberID,
								MemberKey,
								MemberDescription,
								NodeTypeBM,
								ParentMemberId,
								SortOrder
								)
							SELECT
								MemberID = DM.MemberID,
								MemberKey = DM.MemberKey,
								MemberDescription = DM.[MemberDescription],
								NodeTypeBM = DM.NodeTypeBM,
								ParentMemberId = DM.ParentMemberId,
								SortOrder = DM.SortOrder
							FROM
								DimensionMember DM
								--INNER JOIN #DimRows F ON F.MemberKey = DM.MemberKey OR @ShowAllMembersYN <> 0
							WHERE
								DM.InstanceID IN (0, @InstanceID) AND
								DM.DimensionID = @DimensionID
							ORDER BY
								DM.SortOrder,
								DM.MemberKey

							--Loop to find missing parents
							WHILE (SELECT COUNT(1) FROM #Members P WHERE ISNULL(P.ParentMemberId, 0) <> 0 AND NOT EXISTS (SELECT 1 FROM #Members M WHERE M.MemberID = P.ParentMemberID)) > 0
								BEGIN
									INSERT INTO #Members
										(
										MemberID,
										MemberKey,
										MemberDescription,
										NodeTypeBM,
										ParentMemberId,
										SortOrder
										)
									SELECT
										MemberID = DM.MemberID,
										MemberKey = DM.MemberKey,
										MemberDescription = DM.[MemberDescription],
										NodeTypeBM = DM.NodeTypeBM,
										ParentMemberId = DM.ParentMemberId,
										SortOrder = DM.SortOrder
									FROM
										DimensionMember DM
										INNER JOIN (SELECT DISTINCT MemberId = ParentMemberId FROM #Members P WHERE NOT EXISTS (SELECT 1 FROM #Members M WHERE M.MemberID = P.ParentMemberID)) NP ON NP.MemberId = DM.MemberId
									WHERE
										DM.InstanceID = @InstanceID AND
										DM.DimensionID = @DimensionID
									ORDER BY
										DM.SortOrder,
										DM.MemberKey
								END

							SET @SQLStatement = '
								SELECT DISTINCT
									ResultTypeBM = 2,
									Dim = ''' + @DimensionName + ''',
									M.MemberID,
									MemberKey,
									MemberDescription,' + @SQLPropertyList + '
									NodeTypeBM,
									ParentMemberId,
									WriteYN = CASE WHEN M.[NodeTypeBM] & 8 > 0 THEN 0 ELSE ' + CASE WHEN @AssignmentID IS NULL THEN '0' ELSE 'CASE WHEN ' + CONVERT(nvarchar(10), @DimensionID) + ' IN (-7) AND (M.MemberID <= ' + CONVERT(nvarchar(10), @ClosedMonth) + ' OR M.MemberID NOT BETWEEN ' + CONVERT(nvarchar(10), @TimeFrom) + ' AND ' + CONVERT(nvarchar(10), @TimeTo) + ') THEN 0 ELSE 1 END' END + ' END,
									SortOrder
								FROM
									#Members M
								ORDER BY
									SortOrder,
									MemberKey'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Selected = @Selected + @@ROWCOUNT
						END

					ELSE IF @StorageTypeBM_Dimension & 2 > 0
						BEGIN
							SET @Step = 'DimensionMember_Cursor: @StorageTypeBM_Dimension & 2 > 0'
							SET @Message = 'StorageTypeBM_Dimension = 2, not yet implemented'
							SET @Severity = 16
							GOTO EXITPOINT
						END

					ELSE IF @StorageTypeBM_Dimension & 4 > 0
						BEGIN
							SET @Step = 'DimensionMember_Cursor: @StorageTypeBM_Dimension & 4 > 0'
							SET @SQLStatement = '
								INSERT INTO #Members
									(
									MemberID,
									MemberKey,
									MemberDescription,
									NodeTypeBM,
									ParentMemberId,
									SortOrder
									)
								SELECT
									MemberID = D.MemberID,
									MemberKey = D.Label,
									MemberDescription = D.[Description],
									NodeTypeBM = CASE D.RNodeType WHEN ''L'' THEN 1 WHEN ''P'' THEN 18 WHEN ''LC'' THEN 9 WHEN ''PC'' THEN 10 ELSE 18 END + ' + CASE WHEN @GroupYN <> 0 THEN 'CASE WHEN D.GroupYN <> 0 THEN 256 ELSE 0 END' ELSE '0' END + ',
									ParentMemberId = H.ParentMemberId,
									SortOrder = H.SequenceNumber
								FROM
									' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' D
									INNER JOIN ' + @CallistoDatabase + '..S_HS_' + @DimensionName + '_' + @HierarchyName + ' H ON H.MemberId = D.MemberId
									INNER JOIN #DimRows F ON F.MemberKey = D.Label  OR ' + CONVERT(nvarchar(15), CONVERT(int, @ShowAllMembersYN)) + ' <> 0
								WHERE
									1 = 1'
									+ CASE WHEN LEN(@LeafLevelFilter_RA) > 0 THEN ' AND D.Label IN (' + @LeafLevelFilter_RA + ')' ELSE '' END + '
								ORDER BY
									SortOrder,
									D.Label'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							IF @DebugBM & 2 > 0 SELECT [TempTable_#Members] = '#Members_1', * FROM #Members

							IF @DebugBM & 16 > 0 SELECT [Step] = 'Leaf level members for ' + @DimensionName + ' are inserted in temp table', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

							--Loop to find missing parents

							IF @DebugBM & 32 > 0
								BEGIN
									SELECT
										[CountMembers] = (SELECT COUNT(1) FROM #Members P WHERE ISNULL(P.ParentMemberId, 0) <> 0 AND NOT EXISTS (SELECT 1 FROM #Members M WHERE M.MemberID = P.ParentMemberID)),
										[SumMembers] = (SELECT SUM(MemberId) FROM #Members P WHERE ISNULL(P.ParentMemberId, 0) <> 0 AND NOT EXISTS (SELECT 1 FROM #Members M WHERE M.MemberID = P.ParentMemberID)),
										[@SumMemberID] = @SumMemberID
								END

							WHILE
								(SELECT COUNT(1)       FROM #Members P WHERE ISNULL(P.ParentMemberId, 0) <> 0 AND NOT EXISTS (SELECT 1 FROM #Members M WHERE M.MemberID = P.ParentMemberID)) > 0 AND
								(SELECT SUM(MemberId)  FROM #Members P WHERE ISNULL(P.ParentMemberId, 0) <> 0 AND NOT EXISTS (SELECT 1 FROM #Members M WHERE M.MemberID = P.ParentMemberID)) <> @SumMemberID
									BEGIN
										SELECT
											@SumMemberID = SUM(MemberId)
										FROM
											#Members P
										WHERE
											ISNULL(P.ParentMemberId, 0) <> 0 AND
											NOT EXISTS (SELECT 1 FROM #Members M WHERE M.MemberID = P.ParentMemberID)

										IF @DebugBM & 2 > 0
											BEGIN
												SELECT
													TempTable = '#Members',
													Step = 'Loop to find missing parents',
													[@SumMemberID] = @SumMemberID,
													P.*
												FROM
													#Members P
												WHERE
													ISNULL(P.ParentMemberId, 0) <> 0 AND
													NOT EXISTS (SELECT 1 FROM #Members M WHERE M.MemberID = P.ParentMemberID)
											END

										SET @SQLStatement = '
											INSERT INTO #Members
												(
												MemberID,
												MemberKey,
												MemberDescription,
												NodeTypeBM,
												ParentMemberId,
												SortOrder
												)
											SELECT
												MemberID = D.MemberID,
												MemberKey = D.Label,
												MemberDescription = D.[Description],
												NodeTypeBM = CASE D.RNodeType WHEN ''L'' THEN 1 WHEN ''P'' THEN 18 WHEN ''LC'' THEN 9 WHEN ''PC'' THEN 10 ELSE 18 END + ' + CASE WHEN @GroupYN <> 0 THEN 'CASE WHEN D.GroupYN <> 0 THEN 256 ELSE 0 END' ELSE '0' END + ',
												ParentMemberId = H.ParentMemberId,
												SortOrder = ISNULL(H.SequenceNumber, 0)
											FROM
												' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' D
												INNER JOIN (SELECT DISTINCT MemberId = ParentMemberId FROM #Members P WHERE NOT EXISTS (SELECT 1 FROM #Members M WHERE M.MemberID = P.ParentMemberID)) NP ON NP.MemberId = D.MemberId
												LEFT JOIN ' + @CallistoDatabase + '..S_HS_' + @DimensionName + '_' + @HierarchyName + ' H ON H.MemberId = D.MemberId
											ORDER BY
												SortOrder,
												D.Label'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC (@SQLStatement)
										IF @DebugBM & 2 > 0 SELECT TempTable = '#Members_2', * FROM #Members ORDER BY MemberId, SortOrder, MemberKey
									END

/*
Situations when dimension Time is not included in the DataClass must be handled to set WriteYN correct.
One idea is to set TimeYear_MemberKey as an extra column on TimeMonth and TimeFiscalYear_MemberKey on TimeFiscalPeriod
That is how Book is handled in relation to Entity in Journal
*/
							IF @DebugBM & 16 > 0 SELECT [Step] = 'Temp table for ' + @DimensionName + ' is prepared', [TimeConsumed] = CONVERT(Time(7), GetDate() - @StartTime)

							--SET @SQLPropertyListTrick = REPLACE(REPLACE(REPLACE(REPLACE(@SQLPropertyList, ' ', ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')
							--set @SQLPropertyListTrick = COALESCE((SELECT IIF(a = '', '', a + ',')
							--											FROM (
							--													SELECT a = CASE WHEN SUB.[PropertyName] IS NOT NULL then SPL.[value]
							--																				ELSE '' -- SPL.[value] + '=NULL'
							--																			END
							--													FROM  STRING_SPLIT(@SQLPropertyListTrick, ',')  AS SPL
							--													LEFT JOIN (SELECT P.[PropertyName]
							--																FROM [pcINTEGRATOR]..[Dimension_Property] DP
							--																JOIN [pcINTEGRATOR]..[Property] P ON	P.[PropertyID] = DP.[PropertyID]
							--																							AND P.[InstanceID] = DP.[InstanceID]
							--																WHERE	DP.[InstanceID] in (@InstanceID, 0)
							--																	AND DP.[DimensionID] = @DimensionID
							--																) as SUB ON SUB.[PropertyName] = SPL.[value]
							--													WHERE	RTRIM(SPL.[value]) <> ''
							--													) AS ABC
							--											FOR XML PATH('')
							--										 )
							--										 ,'')

							---- if didn't any problem before...
							--IF COALESCE(@SQLPropertyNotExists, '') = ''
							--	begin
							--	SET @SQLPropertyNotExists = REPLACE(REPLACE(REPLACE(REPLACE(@SQLPropertyList, ' ', ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')
							--	set @SQLPropertyNotExists = COALESCE((SELECT IIF(a = '', '', a + ',')
							--												FROM (
							--														SELECT a = CASE WHEN SUB.[PropertyName] IS NOT NULL then ''
							--																					ELSE SPL.[value]
							--																				END
							--														FROM  STRING_SPLIT(@SQLPropertyNotExists, ',')  AS SPL
							--														LEFT JOIN (SELECT P.[PropertyName]
							--																	FROM [pcINTEGRATOR]..[Dimension_Property] DP
							--																	JOIN [pcINTEGRATOR]..[Property] P ON	P.[PropertyID] = DP.[PropertyID]
							--																								AND P.[InstanceID] = DP.[InstanceID]
							--																	WHERE	DP.[InstanceID] in (@InstanceID, 0)
							--																		AND DP.[DimensionID] = @DimensionID
							--																	) as SUB ON SUB.[PropertyName] = SPL.[value]
							--														WHERE	RTRIM(SPL.[value]) <> ''
							--														) AS ABC
							--												FOR XML PATH('')
							--											 )
							--											 ,'')
							--	SET @DimensionNameProblem = @DimensionName;

							--	--IF COALESCE(@SQLPropertyNotExists, '') <> ''
							--	--	BEGIN
							--	--	SET @SQLPropertyNotExists = CASE WHEN LEN(@SQLPropertyNotExists) > 1 THEN LEFT(@SQLPropertyNotExists, LEN(@SQLPropertyNotExists)-1)
							--	--									ELSE @SQLPropertyNotExists
							--	--									end;
							--	--	SET @ErrorMessage = 'Selected properties: ''' + @SQLPropertyNotExists + ''' do not exist in Dimension: ''' + @DimensionNameProblem + '''';
							--	--	THROW 51000, @ErrorMessage, 2;
							--	--	END;
							--	END;

							SET @SQLStatement = '
								SELECT DISTINCT
									ResultTypeBM = 2,
									Dim = ''' + @DimensionName + ''',
									M.MemberID,
									M.MemberKey,
									M.MemberDescription,' + @SQLPropertyList + '
									M.NodeTypeBM,
									M.ParentMemberId,
									--WriteYN = CASE WHEN M.[NodeTypeBM] & 8 > 0 THEN 0 ELSE ' + CASE WHEN @AssignmentID IS NULL THEN '0' ELSE 'CASE WHEN ' + CONVERT(NVARCHAR(10), @DimensionID) + ' IN (-7) AND (M.MemberID <= ' + CONVERT(NVARCHAR(10), @ClosedMonth) + ' OR M.MemberID NOT BETWEEN ' + CONVERT(NVARCHAR(10), @TimeFrom) + ' AND ' + CONVERT(NVARCHAR(10), @TimeTo) + ') THEN 0 ELSE 1 END' END + ' END,
									WriteYN = CASE WHEN M.[NodeTypeBM] & 8 > 0 THEN 0 ELSE ' + CASE WHEN @AssignmentID IS NULL OR @WriteAccessYN = 0 THEN '0' ELSE 'CASE WHEN ' + CONVERT(NVARCHAR(10), @DimensionID) + ' IN (-7) AND (M.MemberID <= ' + CONVERT(NVARCHAR(10), @ClosedMonth) + ' OR M.MemberID NOT BETWEEN ' + CONVERT(NVARCHAR(10), @TimeFrom) + ' AND ' + CONVERT(NVARCHAR(10), @TimeTo) + ') THEN 0 ELSE 1 END' END + ' END,
									' + CASE WHEN @ShowConsoStatusYN <> 0 THEN '[Status] = '''',' ELSE '' END + '
									M.SortOrder
								FROM
									#Members M
									LEFT JOIN ' + @CallistoDatabase + '..S_DS_' + @DimensionName + ' D ON D.Label = M.MemberKey
								WHERE
									M.NodeTypeBM & ' + CONVERT(NVARCHAR(15), @NodeTypeBM) + ' > 0 AND
									(M.MemberID <> -1 OR ' + CONVERT(NVARCHAR(15), CONVERT(INT, @NoneYN)) + ' <> 0)
								ORDER BY
									M.SortOrder,
									M.MemberKey'

							IF @DebugBM & 2 > 0 PRINT @SQLStatement
							EXEC (@SQLStatement)

							SET @Selected = @Selected + @@ROWCOUNT
						END

					FETCH NEXT FROM DimensionMember_Cursor INTO @DimensionID, @DimensionName, @DimensionTypeID, @HierarchyName, @StorageTypeBM_Dimension, @LeafLevelFilter_RA, @Parent_MemberKey

				END

		CLOSE DimensionMember_Cursor
		DEALLOCATE DimensionMember_Cursor

	SET @Step = 'Drop temp tables'
		DROP TABLE #DimRows
		DROP TABLE #DimensionMember_Cursor
		DROP TABLE #Parent_MemberKey
		DROP TABLE #PropertyList
		DROP TABLE #WorkflowState

		IF @CreateTempTableYN <> 0 DROP TABLE #DimensionList

		IF @CalledYN = 0
			BEGIN
				DROP TABLE #ReadAccess
				DROP TABLE #PipeStringSplit
				DROP TABLE #HierarchyList
			END

	--IF COALESCE(@SQLPropertyNotExists, '') <> ''
	--	BEGIN
	--	SET @SQLPropertyNotExists = CASE WHEN LEN(@SQLPropertyNotExists) > 1 THEN LEFT(@SQLPropertyNotExists, LEN(@SQLPropertyNotExists)-1)
	--									ELSE @SQLPropertyNotExists
	--									end;
	--	SET @ErrorMessage = 'Selected properties: ''' + @SQLPropertyNotExists + ''' do not exist in Dimension: ''' + @DimensionNameProblem + '''';
	--	THROW 51000, @ErrorMessage, 2;
	--	END;

	SET @Step = 'Set @Duration'
		SET @Duration = GETDATE() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GETDATE() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
--	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
