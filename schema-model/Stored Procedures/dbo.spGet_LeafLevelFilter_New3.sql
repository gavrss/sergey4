SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_LeafLevelFilter_New3]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DatabaseName nvarchar(100) = NULL, --Mandatory
	@DimensionID int = NULL,
	@DimensionName nvarchar(100) = NULL, --Mandatory
	@MemberId bigint = NULL, 
	@Filter nvarchar(4000) = NULL OUT,
	@StorageTypeBM_DataClass int = 3, --3 returns _MemberKey, 4 returns _MemberId
	@StorageTypeBM int = NULL, --Mandatory
	@ReturnColNameYN bit = 0,
	@LeafLevelFilter nvarchar(max) = NULL OUT, --Mandatory
	@NodeTypeBM int = NULL OUT,
	
	@HierarchyName nvarchar(100) = NULL,
	@HierarchyNo int = NULL,
	@FilterType nvarchar(10) = 'MemberKey', --MemberKey, @MemberId
	@FilterLevel nvarchar(3) = 'L', --L=LeafLevel, P=Parent, LF=LevelFilter (not up or down), LLF=LevelFilter + all members below
	@LeafMemberOnlyYN bit = 1,
	@GetLeafLevelYN bit = 1,
	@JournalDrillYN bit = NULL,  --defaulted to 0 below
	@UseCacheYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000207,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spGet_LeafLevelFilter',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

DECLARE @Account_LeafLevelFilter nvarchar(max)
EXEC pcINTEGRATOR..spGet_LeafLevelFilter @UserID = -10, @InstanceID = 0, @VersionID = 0, @DatabaseName = 'pcDATA_HD', @DimensionName = 'Account', @Filter = 'Gross_Profit_, ST_AB_Move1st', @StorageTypeBM = 4, @FilterLevel = 'L', @StorageTypeBM_DataClass = 4, @LeafLevelFilter = @Account_LeafLevelFilter OUT, @Debug = 1
SELECT [Account_LeafLevelFilter] = @Account_LeafLevelFilter

DECLARE @LeafLevelFilter nvarchar(4000), @NodeTypeBM int
EXEC spGet_LeafLevelFilter @UserID=3813, @InstanceID=413, @VersionID=1008, @DatabaseName='pcDATA_CBN', @DimensionName='Account', @Filter= 'Financials_', @StorageTypeBM=4, @UseCacheYN=0, @FilterLevel='L', @StorageTypeBM_DataClass=4, @LeafLevelFilter=@LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT, @Debug = 1
SELECT LeafLevelFilter = @LeafLevelFilter, NodeTypeBM = @NodeTypeBM

DECLARE @LeafLevelFilter nvarchar(4000), @NodeTypeBM int
EXEC spGet_LeafLevelFilter @UserID=3813, @InstanceID=16, @VersionID=1002, @DimensionID=-1, @Filter= 'Financials_', @UseCacheYN=0, @FilterLevel='L', @StorageTypeBM=1, @StorageTypeBM_DataClass=3, @LeafLevelFilter=@LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT--, @Debug = 1
SELECT LeafLevelFilter = @LeafLevelFilter, NodeTypeBM = @NodeTypeBM

DECLARE @LeafLevelFilter nvarchar(4000), @NodeTypeBM int
EXEC spGet_LeafLevelFilter @UserID=3813, @InstanceID=424, @VersionID=1017, @DatabaseName='pcDATA_HD', @DimensionName='GL_Office', @Filter= '04%', @StorageTypeBM=4, @UseCacheYN=0, @LeafLevelFilter=@LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT, @Debug = 1
SELECT LeafLevelFilter = @LeafLevelFilter, NodeTypeBM = @NodeTypeBM

DECLARE @LeafLevelFilter nvarchar(4000), @NodeTypeBM int
EXEC spGet_LeafLevelFilter @UserID=3813, @InstanceID=413, @VersionID=1008, @DatabaseName='pcDATA_CBN', @DimensionName='Time', @Filter= 'FY2018, FY2019', @StorageTypeBM=4, @StorageTypeBM_DataClass=4, @FilterLevel = 'LLF', @UseCacheYN=0, @LeafLevelFilter=@LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT, @Debug = 1
SELECT LeafLevelFilter = @LeafLevelFilter, NodeTypeBM = @NodeTypeBM

DECLARE @LeafLevelFilter nvarchar(4000), @NodeTypeBM int
EXEC spGet_LeafLevelFilter @UserID = -10, @InstanceID = 454, @VersionID = 1021, @DatabaseName = 'pcDATA_CCM', @DimensionID = -2, @HierarchyNo = 0, @DimensionName = 'BusinessProcess', @Filter = 'INPUT', @StorageTypeBM = 4, @LeafLevelFilter = @LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT--, @Debug = 1
SELECT [@LeafLevelFilter] = @LeafLevelFilter, [@NodeTypeBM] = @NodeTypeBM

DECLARE @LeafLevelFilter nvarchar(4000), @NodeTypeBM int
EXEC spGet_LeafLevelFilter @UserID = -10, @InstanceID = -1318, @VersionID = -1256, @DimensionID = -2, @Filter = 'CONSOLIDATED', @UseCacheYN=0, @StorageTypeBM_DataClass=4, @LeafLevelFilter = @LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT, @Debug = 1
SELECT [@LeafLevelFilter] = @LeafLevelFilter, [@NodeTypeBM] = @NodeTypeBM

DECLARE @LeafLevelFilter nvarchar(4000), @NodeTypeBM int
EXEC spGet_LeafLevelFilter @UserID = -10, @InstanceID = -1318, @VersionID = -1256, @DimensionID = -2, @FilterType = 'MemberID', @Filter = '200', @UseCacheYN=0, @StorageTypeBM_DataClass=4, @LeafLevelFilter = @LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT, @Debug = 1
SELECT [@LeafLevelFilter] = @LeafLevelFilter, [@NodeTypeBM] = @NodeTypeBM

DECLARE @LeafLevelFilter nvarchar(4000) = NULL, @NodeTypeBM int, @Filter nvarchar(max) = NULL
--EXEC spGet_LeafLevelFilter @UserID = -10, @InstanceID = 481, @VersionID = 1031, @DatabaseName = 'pcDATA_NOR', @DimensionID = -1, @HierarchyNo = 0, @DimensionName = 'Account', @MemberID = 2391, @StorageTypeBM = 4, @LeafLevelFilter = @LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT, @Debug = 1
--EXEC spGet_LeafLevelFilter @UserID = -10, @InstanceID = 481, @VersionID = 1031, @DatabaseName = 'pcDATA_NOR', @DimensionName = 'Account', @MemberID = 2391, @StorageTypeBM = 4, @LeafLevelFilter = @LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT, @GetLeafLevelYN = 1, @Debug = 1,@Filter = @Filter OUT
EXEC spGet_LeafLevelFilter @UserID = -10, @InstanceID = 481, @VersionID = 1031, @DatabaseName = 'pcDATA_NOR', @DimensionName = 'Account', @StorageTypeBM = 4, @LeafLevelFilter = @LeafLevelFilter OUT, @NodeTypeBM = @NodeTypeBM OUT, @GetLeafLevelYN = 1, @UseCacheYN=0, @Debug = 1,@Filter = 'AC_MOD_GNI01', @JournalDrillYN=1
SELECT [@LeafLevelFilter] = @LeafLevelFilter, [@NodeTypeBM] = @NodeTypeBM

DECLARE @LeafLevelFilter nvarchar(4000), @NodeTypeBM int
EXEC spGet_LeafLevelFilter @UserID=-10, @InstanceID=529, @VersionID=1001, @DimensionID=-2, @FilterType='MemberID', @Filter='200', @UseCacheYN=0, @StorageTypeBM_DataClass=4, @ReturnColNameYN=1, @LeafLevelFilter=@LeafLevelFilter OUT, @NodeTypeBM=@NodeTypeBM OUT, @Debug=1
SELECT [@LeafLevelFilter] = @LeafLevelFilter, [@NodeTypeBM] = @NodeTypeBM

DECLARE @LeafLevelFilter nvarchar(4000), @NodeTypeBM int
EXEC spGet_LeafLevelFilter @UserID=-10, @InstanceID=529, @VersionID=1001, @DimensionID=-53, @HierarchyNo=2, @FilterType='MemberID', @Filter='CA_Balance Sheet', @UseCacheYN=1, @StorageTypeBM_DataClass=4, @ReturnColNameYN=1, @LeafLevelFilter=@LeafLevelFilter OUT, @NodeTypeBM=@NodeTypeBM OUT, @DebugBM=7
SELECT [@LeafLevelFilter] = @LeafLevelFilter, [@NodeTypeBM] = @NodeTypeBM

DECLARE @LeafLevelFilter nvarchar(4000), @NodeTypeBM int
EXEC spGet_LeafLevelFilter @UserID=-10, @InstanceID=529, @VersionID=1001, @DimensionID=-26, @HierarchyNo=0, @FilterType='MemberID', @Filter='V01', @UseCacheYN=1, @StorageTypeBM_DataClass=4, @ReturnColNameYN=1, @LeafLevelFilter=@LeafLevelFilter OUT, @NodeTypeBM=@NodeTypeBM OUT, @DebugBM=7
SELECT [@LeafLevelFilter] = @LeafLevelFilter, [@NodeTypeBM] = @NodeTypeBM

EXEC [spGet_LeafLevelFilter] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),
	@MappingTypeID int,
	@DimensionTypeID int,

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
	@ToBeChanged nvarchar(255) = 'Verify call to spGet_FilterLevelParent. Temp table #FilterLevel_MemberKey only created in sp [spPortalGet_DataClass_Data]',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2188'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Return correct where clause for selected filter',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2145' SET @Description = 'Enhanced structure. Handle wildcards.'
		IF @Version = '2.0.2.2146' SET @Description = 'Handle @FilterLevel = LF (LevelFilter, not up or down). DB-98: Modified validation for #Check. Always check cache, pcINTEGRATOR_Log..wrk_LeafLevelFilter'
		IF @Version = '2.0.2.2148' SET @Description = 'DB-134: Handle filter on dimensions in Journal that is not dimensions from a DW perspective.'
		IF @Version = '2.0.3.2152' SET @Description = 'DB-331: Deallocate cursor Check_Cursor if exists. DB-336: Handle MemberKeyBase for Mapped dimensions. DB-352: Journal filter on parents for prefixed/suffixed accounts.'
		IF @Version = '2.0.3.2154' SET @Description = 'Implement @FilterType + @FilterLevel=LLF, Enhanced performance by using STRING_SPLIT() and CTE. DB-448 Invalid Filters set to -999.'
		IF @Version = '2.1.0.2162' SET @Description = 'DB-578: Added @Step = Set @LeafLevelFilter in string format. Test on @MemberID = 1.'
		IF @Version = '2.1.0.2163' SET @Description = 'Do not save into cache if @UseCacheYN = 0.'
		IF @Version = '2.1.0.2165' SET @Description = 'Check for duplicates when insert into [pcINTEGRATOR_Log].[dbo].[wrk_LeafLevelFilter].'
		IF @Version = '2.1.1.2169' SET @Description = 'Handle AutoMultiDim (SourceTypeID=27).'
		IF @Version = '2.1.2.2181' SET @Description = 'Set @UseCacheYN = 0 as a temporal hot-fix.'
		IF @Version = '2.1.2.2188' SET @Description = 'Parameter @JournalDrillYN is set to 1 if not passed and @StorageTypeBM_DataClass & 1 > 0'

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

		SET @LeafMemberOnlyYN = CASE WHEN @FilterLevel IN ('LF', 'LLF') THEN 0 ELSE @LeafMemberOnlyYN END

		-- temporal hot-fix issue PrimaryKey on inserting (for example https://dspanel.atlassian.net/browse/EA-865)
		SET @UseCacheYN = 0

		SET	@JournalDrillYN = ISNULL(@JournalDrillYN, CASE WHEN @StorageTypeBM_DataClass & 1 > 0 THEN 1 ELSE 0 END)

		IF @DebugBM & 2 > 0
			SELECT
				[@JournalDrillYN] = @JournalDrillYN

	SET @Step = 'Check @FilterLevel'
		IF @FilterLevel = 'P'
			BEGIN
				EXEC [dbo].[spGet_FilterLevelParent]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@DatabaseName = @DatabaseName,
					@DimensionName = @DimensionName,
					@HierarchyName = @HierarchyName,
					@Filter = @Filter,
					@StorageTypeBM = @StorageTypeBM,
					@LeafLevelFilter = @LeafLevelFilter OUT,
					@Debug = @Debug

				GOTO EXITPOINT
			END

	SET @Step = 'Check All_'
		IF @FilterLevel <> 'LF' AND ((@FilterType = 'MemberKey' AND @Filter = 'All_') OR (@MemberId = 1))
			BEGIN
				SET @LeafLevelFilter = ''
				GOTO EXITPOINT
			END

	SET @Step = 'Set DimensionID/Name, HierarchyNo/Name and @MappingTypeID'
		IF @DimensionID IS NULL
			SELECT @DimensionID = DimensionID, @DimensionTypeID = DimensionTypeID FROM Dimension WHERE InstanceID IN (0, @InstanceID) AND DimensionName = @DimensionName

		IF @DimensionName IS NULL
			SELECT @DimensionName = DimensionName, @DimensionTypeID = ISNULL(@DimensionTypeID, DimensionTypeID) FROM Dimension WHERE InstanceID IN (0, @InstanceID) AND DimensionID = @DimensionID

		IF @DimensionTypeID IS NULL
			SELECT @DimensionTypeID = DimensionTypeID FROM Dimension WHERE InstanceID IN (0, @InstanceID) AND DimensionID = @DimensionID

		IF @HierarchyNo IS NULL AND @HierarchyName IS NULL
			SELECT @HierarchyNo = 0, @HierarchyName = @DimensionName
			
		ELSE IF @HierarchyNo = 0 AND @HierarchyName IS NULL
			SELECT @HierarchyName = @DimensionName		

		ELSE IF @HierarchyNo IS NULL
			SELECT @HierarchyNo = ISNULL(DH.[HierarchyNo], 0) FROM (SELECT [Dummy] = 0) D LEFT JOIN [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH ON DH.InstanceID = @InstanceID AND DH.DimensionID = @DimensionID AND DH.HierarchyName = @HierarchyName
		
		ELSE IF @HierarchyName IS NULL
			SELECT @HierarchyName = ISNULL(DH.[HierarchyName], @DimensionName) FROM (SELECT [Dummy] = 0) D LEFT JOIN [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] DH ON DH.InstanceID = @InstanceID AND DH.DimensionID = @DimensionID AND DH.HierarchyNo = @HierarchyNo
		
		IF @JournalDrillYN <> 0 SET @StorageTypeBM_DataClass = 2
		
		SELECT
			@MappingTypeID = CASE WHEN @JournalDrillYN = 0 THEN 0 ELSE MappingTypeID END
		FROM
			pcINTEGRATOR_Data..Dimension_StorageType
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DimensionID = @DimensionID

		IF @DebugBM & 2 > 0 
			SELECT 
				[@MappingTypeID] = @MappingTypeID, 
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@DimensionID] = @DimensionID,
				[@DimensionTypeID] = @DimensionTypeID

		IF @StorageTypeBM IS NULL
			SELECT 
				@StorageTypeBM = StorageTypeBM
			FROM
				pcINTEGRATOR_Data..Dimension_StorageType
			WHERE
				InstanceID = @InstanceID AND
				VersionID = @VersionID AND
				DimensionID = @DimensionID


		IF @DatabaseName IS NULL
			SELECT
				@DatabaseName = CASE WHEN @StorageTypeBM & 1 > 0 THEN 'pcINTEGRATOR_Data' ELSE CASE WHEN @StorageTypeBM & 2 > 0 THEN ETLDatabase ELSE CASE WHEN @StorageTypeBM & 4 > 0 THEN DestinationDatabase ELSE '' END END END
			FROM
				[Application]
			WHERE
				InstanceID = @InstanceID AND
				VersionID = @VersionID

		IF @DebugBM & 2 > 0
			SELECT
				[@DatabaseName] = @DatabaseName,
				[@DimensionID] = @DimensionID,
				[@DimensionName] = @DimensionName,
				[@HierarchyNo] = @HierarchyNo,
				[@HierarchyName] = @HierarchyName,
				[@FilterType] = @FilterType,
				[@FilterLevel] = @FilterLevel,
				[@MappingTypeID] = @MappingTypeID,
				[@JournalDrillYN] = @JournalDrillYN, 
				[@Filter] = @Filter,
				[@StorageTypeBM] = @StorageTypeBM,
				[@StorageTypeBM_DataClass] = @StorageTypeBM_DataClass

	SET @Step = 'Check Cache'
		IF @UseCacheYN <> 0
			IF @FilterLevel <> 'P' AND LEN(@Filter) <= 400
				BEGIN
					SET @LeafLevelFilter = NULL

					SELECT
						@LeafLevelFilter = [LeafLevelFilter],
						@NodeTypeBM = [NodeTypeBM]
					FROM
						[pcINTEGRATOR_Log].[dbo].[wrk_LeafLevelFilter]
					WHERE
						[InstanceID] = @InstanceID AND
						[VersionID] = @VersionID AND
						[UserId] = @UserId AND
						[DimensionID] = @DimensionID AND
						[HierarchyNo] = @HierarchyNo AND
						[FilterType] = @FilterType AND
						[FilterLevel] = @FilterLevel AND
						[StorageTypeBM] & @StorageTypeBM_DataClass > 0 AND
						[JournalDrillYN] = @JournalDrillYN AND
						[Filter] = @Filter AND
						[ReturnColNameYN] = @ReturnColNameYN AND
						[Inserted] > DATEADD (hour, -10 , SYSUTCDATETIME())

					IF @LeafLevelFilter IS NOT NULL GOTO EXITPOINT
				END
	SET @Step = 'Check AutoMultiDim'
		IF @DimensionTypeID = 27 AND @ReturnColNameYN <> 0 --AND @Filter <> 'All_'
			BEGIN
				EXEC [dbo].[spGet_AutoMultiDimFilter]
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID,
					@DimensionID = @DimensionID,
					@DimensionName = @DimensionName,
					@HierarchyNo = @HierarchyNo,
					@HierarchyName = @HierarchyName,
					@MemberKey = @Filter,
					@StorageTypeBM_DataClass = @StorageTypeBM_DataClass,
					@LeafLevelFilter = @LeafLevelFilter OUT,
					@JobID = @JobID,
					@Debug = @DebugSub

				GOTO SetCache
			END

 	SET @Step = 'Create temp table #DimRow' 
		CREATE TABLE #DimRow
			(
			[MemberId] bigint,
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[MemberKeyBase] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[NodeTypeBM] int,
			[ParentMemberId] bigint
			)

		IF @StorageTypeBM & 1 > 0
			BEGIN
				INSERT INTO #DimRow
					(
					[MemberId],
					[MemberKey],
					[NodeTypeBM],
					[ParentMemberId]
					)
				SELECT
					[MemberId] = DM.MemberID,
					[MemberKey] = DM.[MemberKey],
					[NodeTypeBM] = DM.[NodeTypeBM],
					[ParentMemberId] = DM.[ParentMemberId]
				FROM
					pcINTEGRATOR_Data..DimensionMember DM
				WHERE
					DM.InstanceID = @InstanceID AND
					DM.DimensionID = @DimensionID
			END

		ELSE IF @StorageTypeBM & 2 > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #DimRow
						(
						[MemberId],
						[MemberKey],
						[MemberKeyBase],
						[NodeTypeBM],
						[ParentMemberId]
						)
					SELECT
						[MemberId] = D.[MemberID],
						[MemberKey] = D.[MemberKey],
						[MemberKeyBase] = ' + CASE WHEN @MappingTypeID = 0 THEN 'NULL' ELSE 'D.[MemberKeyBase]' END + ',
						[NodeTypeBM] = D.[NodeTypeBM],
						[ParentMemberId] = ' + CASE WHEN @HierarchyNo = 0 THEN 'D.[ParentMemberID]' ELSE 'H.[ParentMemberID]' END + '
					FROM
						' + @DatabaseName + '.[dbo].[pcD_' + @DimensionName + '] D
						' + CASE WHEN @HierarchyNo <> 0 THEN 'INNER JOIN ' + @DatabaseName + '.[dbo].[pcDH_Hierarchy] H ON H.DimensionID = ' + CONVERT(nvarchar(15), @DimensionID) + ' AND H.HierarchyNo = ' + CONVERT(nvarchar(15), @HierarchyNo) + ' AND H.MemberID = D.MemberID' ELSE '' END

				IF @DebugBM & 2 > 0 
					BEGIN
						PRINT @SQLStatement
						SELECT TempTable = '#DimRow', * FROM #DimRow
					END
				EXEC (@SQLStatement)
			END
		ELSE IF @StorageTypeBM & 4 > 0
			BEGIN
				SET @SQLStatement = '
					INSERT INTO #DimRow
						(
						[MemberId],
						[MemberKey],
						[MemberKeyBase],
						[NodeTypeBM],
						[ParentMemberId]
						)
					SELECT
						[MemberId] = D.[MemberID],
						[MemberKey] = D.[Label],
						[MemberKeyBase] = ' + CASE WHEN @MappingTypeID = 0 THEN 'NULL' ELSE 'D.[MemberKeyBase]' END + ',
						[NodeTypeBM] = CASE D.RNodeType WHEN ''L'' THEN 1 WHEN ''P'' THEN 18 WHEN ''LC'' THEN 9 WHEN ''PC'' THEN 10 END,
						[ParentMemberId]
					FROM
						' + @DatabaseName + '.[dbo].[S_HS_' + @DimensionName + '_' + @HierarchyName + '] H
						INNER JOIN ' + @DatabaseName + '..S_DS_' + @DimensionName + ' D ON D.MemberID = H.MemberID'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
			END

		IF @DebugBM & 2 > 0 SELECT TempTable = '#DimRow', * FROM #DimRow ORDER BY [MemberKey]

 	SET @Step = 'Get @LeafLevelFilter' 
		SET @LeafLevelFilter = ''

		CREATE TABLE #Check
			(
			[MemberKey] nvarchar(100) COLLATE DATABASE_DEFAULT,
			[MemberId] bigint,
			[NodeTypeBM] int
			)

		IF LEN(@Filter) > 0
			BEGIN
				IF @FilterType = 'MemberKey'
					BEGIN
						INSERT INTO #Check ([MemberKey]) SELECT [MemberKey] = LTRIM(RTRIM([Value])) FROM STRING_SPLIT(@Filter, ',')

						INSERT INTO #Check
							(
							[MemberKey]
							)
						SELECT
							[MemberKey] = D.[MemberKey]
						FROM
							#Check MK
							INNER JOIN #DimRow D ON D.[MemberKey] LIKE MK.[MemberKey]
						WHERE
							NOT EXISTS (SELECT 1 FROM #Check C WHERE C.[MemberKey] = D.[MemberKey])

						IF @MappingTypeID <> 0
							BEGIN
								INSERT INTO #Check
									(
									[MemberId],
									[MemberKey]
									)
								SELECT
									[MemberId] = D.[MemberId],
									[MemberKey] = D.[MemberKeyBase]
								FROM
									#Check MK
									INNER JOIN #DimRow D ON D.[MemberKey] = MK.[MemberKey]
								WHERE
									NOT EXISTS (SELECT 1 FROM #Check C WHERE C.[MemberKey] = D.[MemberKeyBase])
							END

							UPDATE MK
							SET
								[MemberId] = D.MemberId,
								[NodeTypeBM] = D.[NodeTypeBM]
							FROM
								#Check MK
								INNER JOIN #DimRow D ON D.[MemberId] = MK.[MemberId] OR D.[MemberKey] = MK.[MemberKey]
					END

				ELSE IF @FilterType = 'MemberId'
					BEGIN
						INSERT INTO #Check ([MemberId]) SELECT [MemberId] = LTRIM(RTRIM([Value])) FROM STRING_SPLIT(@Filter, ',')

						UPDATE MK
						SET
							[MemberKey] = CASE WHEN @MappingTypeID = 0 THEN D.[MemberKey] ELSE D.[MemberKeyBase] END,
							[NodeTypeBM] = D.[NodeTypeBM]
						FROM
							#Check MK
							INNER JOIN #DimRow D ON D.[MemberId] = MK.[MemberId]
					END
			END
		ELSE IF @MemberId IS NOT NULL
			BEGIN
				INSERT INTO #Check
					(
					[MemberKey],
					[MemberId],
					[NodeTypeBM]
					)
				SELECT
					[MemberKey] = D.[MemberKey],
					[MemberId] = @MemberId,
					[NodeTypeBM] = D.[NodeTypeBM]
				FROM
					#DimRow D
				WHERE
					D.MemberId = @MemberId AND
					NOT EXISTS (SELECT 1 FROM #Check C WHERE C.[MemberKey] = D.[MemberKey])
			END

		IF @DebugBM & 1 > 0 SELECT TempTable = '#Check', * FROM #Check

		IF @GetLeafLevelYN = 0
			RETURN

	SET @Step = 'Get children'
		IF @FilterLevel <> 'LF'
			BEGIN
				IF CURSOR_STATUS('global','Check_Cursor') >= -1 DEALLOCATE Check_Cursor
				DECLARE Check_Cursor CURSOR FOR

					SELECT DISTINCT
						[MemberId] = [MemberId]
					FROM
						#Check
					WHERE
						NodeTypeBM & 2 > 0

					OPEN Check_Cursor
					FETCH NEXT FROM Check_Cursor INTO @MemberId

					WHILE @@FETCH_STATUS = 0
						BEGIN
							IF @DebugBM & 2 > 0 SELECT [@MemberId] = @MemberId, [@StorageTypeBM] = @StorageTypeBM

							;WITH cte AS
							(
								--Find top nodes for tree
								SELECT
									D.[MemberID],
									D.[ParentMemberID]
								FROM
									#DimRow D
								WHERE
									D.[MemberID] = @MemberId
								UNION ALL
								SELECT
									D.[MemberID],
									D.[ParentMemberID]
								FROM
									#DimRow D
									INNER JOIN cte c on c.[MemberID] = D.[ParentMemberID]
							)
							INSERT INTO #Check
								(
								[MemberId],
								[MemberKey],
								[NodeTypeBM]
								)
							SELECT
								[MemberId] = D.[MemberId],
								[MemberKey],
								[NodeTypeBM]
							FROM
								cte
								INNER JOIN #DimRow D ON D.MemberID = cte.MemberID

							FETCH NEXT FROM Check_Cursor INTO @MemberId
						END

				CLOSE Check_Cursor
				DEALLOCATE Check_Cursor
			END

		IF @DebugBM & 1 > 0
			SELECT 
				TempTable = '#Check', C.*
			FROM
				#Check C
			WHERE
				CASE WHEN C.NodeTypeBM & 1 > 0 THEN 1 ELSE 0 END = CASE WHEN @LeafMemberOnlyYN = 0 THEN 0 ELSE 1 END OR @LeafMemberOnlyYN = 0

		IF (SELECT COUNT(1) FROM #Check C WHERE CASE WHEN C.NodeTypeBM & 1 > 0 THEN 1 ELSE 0 END = CASE WHEN @LeafMemberOnlyYN = 0 THEN 0 ELSE 1 END OR @LeafMemberOnlyYN = 0) = 0
			BEGIN
				IF @StorageTypeBM_DataClass & 4 > 0
					SET @LeafLevelFilter = '-999'
				ELSE
					SET @LeafLevelFilter = '''' + @Filter + ''''
				
				GOTO EXITPOINT
			END

		IF @StorageTypeBM_DataClass & 4 > 0
			SELECT 
				@LeafLevelFilter = @LeafLevelFilter + CONVERT(nvarchar(20), MemberID) + ','
			FROM
				#Check C
			WHERE
				CASE WHEN C.NodeTypeBM & 1 > 0 THEN 1 ELSE 0 END = CASE WHEN @LeafMemberOnlyYN = 0 THEN 0 ELSE 1 END OR @LeafMemberOnlyYN = 0
			ORDER BY
				C.MemberID
		ELSE IF @StorageTypeBM_DataClass & 3 > 0
			SELECT
				@LeafLevelFilter = @LeafLevelFilter + '''' + sub.MemberKey + ''','
			FROM
				(
				SELECT DISTINCT
					[MemberKey] = ISNULL(D.MemberKeyBase, C.MemberKey)
				FROM
					#Check C
					INNER JOIN #DimRow D ON D.MemberID = C.MemberID
				WHERE
					CASE WHEN C.NodeTypeBM & 1 > 0 THEN 1 ELSE 0 END = CASE WHEN @LeafMemberOnlyYN = 0 THEN 0 ELSE 1 END OR @LeafMemberOnlyYN = 0
				) sub
			ORDER BY
				sub.MemberKey

		SET @LeafLevelFilter = CASE WHEN LEN(@LeafLevelFilter) = 0 THEN '-999,' ELSE @LeafLevelFilter END 

		SET @LeafLevelFilter = LEFT(@LeafLevelFilter, LEN(@LeafLevelFilter) - 1)

		IF @ReturnColNameYN <> 0
			SET @LeafLevelFilter = CASE WHEN @StorageTypeBM_DataClass & 2 > 0 THEN '[Label] IN (' + @LeafLevelFilter + ')'  ELSE 'DC.[' + @DimensionName + '_MemberId] IN (' + @LeafLevelFilter + ')' END

		IF @DebugBM & 2 > 0 SELECT [@LeafLevelFilter] = @LeafLevelFilter

	SET @Step = 'Set NodeTypeBM'
		SELECT @NodeTypeBM = CASE WHEN @LeafLevelFilter = '-999' THEN 0 ELSE (SELECT MIN(C.[NodeTypeBM]) FROM #Check C WHERE C.[NodeTypeBM] IS NOT NULL) END

	SET @Step = 'Set @LeafLevelFilter in string format'
		SET @LeafLevelFilter = CASE WHEN @LeafLevelFilter = '-999' THEN '''-999''' ELSE @LeafLevelFilter END 

	SET @Step = 'Drop temp tables'
		DROP TABLE #Check
		DROP TABLE #DimRow

	SET @Step = 'Insert into cache table'
		SetCache:
		IF @UseCacheYN <> 0 AND @FilterLevel <> 'P' AND LEN(@Filter) <= 400
			INSERT INTO [pcINTEGRATOR_Log].[dbo].[wrk_LeafLevelFilter]
				(
				[InstanceID],
				[VersionID],
				[UserId],
				[DimensionID],
				[HierarchyNo],
				[FilterType],
				[FilterLevel],
				[StorageTypeBM],
				[JournalDrillYN],
				[Filter],
				[ReturnColNameYN],
				[LeafLevelFilter],
				[NodeTypeBM]
				)
			SELECT
				[InstanceID] = @InstanceID,
				[VersionID] = @VersionID,
				[UserId] = @UserId,
				[DimensionID] = @DimensionID,
				[HierarchyNo] = @HierarchyNo,
				[FilterType] = @FilterType,
				[FilterLevel] = @FilterLevel,
				[StorageTypeBM] = CASE WHEN @StorageTypeBM_DataClass & 3 > 0 THEN 3 ELSE @StorageTypeBM_DataClass END,
				[JournalDrillYN] = @JournalDrillYN,
				[Filter] = @Filter,
				[ReturnColNameYN] = @ReturnColNameYN,
				[LeafLevelFilter] = @LeafLevelFilter,
				[NodeTypeBM] = @NodeTypeBM 
			WHERE
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Log].[dbo].[wrk_LeafLevelFilter] WHERE 
					[InstanceID] = @InstanceID AND
					[VersionID] = @VersionID AND
					[UserId] = @UserId AND
					[DimensionID] = @DimensionID AND
					[HierarchyNo] = @HierarchyNo AND
					[FilterType] = @FilterType AND
					[FilterLevel] = @FilterLevel AND
					[StorageTypeBM] = CASE WHEN @StorageTypeBM_DataClass & 3 > 0 THEN 3 ELSE @StorageTypeBM_DataClass END AND
					[JournalDrillYN] = @JournalDrillYN AND
					[Filter] = @Filter AND
					[ReturnColNameYN] = @ReturnColNameYN AND
					CONVERT(date, [Inserted]) = CONVERT(date, sysutcdatetime()))

	SET @Step = 'Drop temp tables'
		IF OBJECT_ID('tempdb..#Check') IS NOT NULL DROP TABLE #Check
		IF OBJECT_ID('tempdb..#DimRow') IS NOT NULL DROP TABLE #DimRow

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
--		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
