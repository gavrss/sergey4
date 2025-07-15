SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalGet_AdvConso_Status]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ResultTypeBM int = 31, --1=List of dimensions, 2=Members, 4=Conso Status, 8=Dependencies
	@Group_MemberKey nvarchar(50) = NULL,
	@Entity_MemberKey nvarchar(50) = NULL,
	@FiscalYear int = NULL, --Mandatory

	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000777,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines, 8=Large tables, 16=Execution time, 32=Special purpose

--#WITH ENCRYPTION#--

AS
/*
EXEC [spPortalGet_AdvConso_Status] @UserID=-10, @InstanceID=527, @VersionID=1043, @Debug=1
EXEC [spPortalGet_AdvConso_Status] @UserID=-10, @InstanceID=529, @VersionID=1001, @Debug=1
EXEC [spPortalGet_AdvConso_Status] @UserID=-10, @InstanceID=-1590, @VersionID=-1590, @Group_MemberKey = 'G_Alpha', @Debug=1
EXEC [spPortalGet_AdvConso_Status] @UserID=-10, @InstanceID=576, @VersionID=1082, @Group_MemberKey = 'G_AXYZ', @Debug=1

EXEC [spPortalGet_AdvConso_Status] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@DataClassID int,
	@DimensionList nvarchar(1024) = '-35|-6|-4',
--	@DimensionList nvarchar(1024) = '-6',
	@JournalTable nvarchar(100),
	@SQLStatement nvarchar(max),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
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
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get data for Advanced Consolidation Status Page',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.1.2171' SET @Description = 'Procedure created.'
		IF @Version = '2.1.2.2187' SET @Description = 'Added parameter @FiscalYear.'
		IF @Version = '2.1.2.2196' SET @Description = 'Added Scenario.'
		IF @Version = '2.1.2.2199' SET @Description = 'Changed ResultTypeBM = 4 to show all Entities regardless if they have been in use before.'
		
		EXEC [pcINTEGRATOR].[dbo].[spSet_Procedure]	@CalledInstanceID=@InstanceID, @CalledVersionID=@VersionID, @CalledProcedureID=@ProcedureID, @CalledDatabaseName=@DatabaseName, @CalledProcedureName=@ProcedureName, @CalledProcedureDescription=@ProcedureDescription, @CalledMandatoryParameter=@MandatoryParameter, @CalledVersion=@Version, @CalledVersionDescription=@Description, @CalledCreatedBy=@CreatedBy, @CalledModifiedBy=@ModifiedBy, @JobID=@ProcedureID
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		EXEC [pcINTEGRATOR].[dbo].[spGet_User] @UserID = @UserID, @UserName = @UserName OUT, @JobID = @JobID			
		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		SELECT 
			@DataClassID = DataClassID
		FROM
			pcINTEGRATOR_Data..DataClass
		WHERE
			InstanceID = @InstanceID AND
			VersionID = @VersionID AND
			DataClassTypeID = -1 AND
			ModelBM & 64 > 0

		EXEC [spGet_JournalTable] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @JobID = @JobID, @JournalTable = @JournalTable OUT 

		IF @DebugBM & 2 > 0
			SELECT
				[@DataClassID] = @DataClassID,
				[@JournalTable] = @JournalTable

	SET @Step = '@ResultTypeBM & 1'
		IF @ResultTypeBM & 1 > 0
			BEGIN
				EXEC [dbo].[spGet_DataClass_DimensionList] @UserID=@UserID, @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID=@DataClassID, @DimensionList=@DimensionList, @ResultTypeBM=1, @JobID=@JobID, @Debug=@DebugSub
			END

	SET @Step = '@ResultTypeBM & 2'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				IF @DebugBM & 2 > 0 SELECT [@UserID]=@UserID, [@InstanceID]=@InstanceID, [@VersionID]=@VersionID, [@DataClassID]=@DataClassID, [@PropertyList]=NULL, [@AssignmentID]=NULL, [@DimensionList]=@DimensionList, [@OnlySecuredDimYN]=0, [@ShowAllMembersYN]=1, [@OnlyDataClassDimMembersYN]=0, [@Parent_MemberKey]=NULL, [@Selected]=@Selected, [@JobID]=@JobID, [@Debug]=@DebugSub
				EXEC [spGet_DataClass_DimensionMember] @UserID=@UserID,  @InstanceID=@InstanceID, @VersionID=@VersionID, @DataClassID=@DataClassID, @PropertyList=NULL, @AssignmentID=NULL, @DimensionList=@DimensionList, @OnlySecuredDimYN=0, @ShowAllMembersYN=1, @OnlyDataClassDimMembersYN=0, @Parent_MemberKey=NULL, @Selected=@Selected OUT, @NodeTypeBM=1, @NoneYN=0, @ShowConsoStatusYN = 1, @JobID=@JobID, @Debug=@DebugSub
			END

	SET @Step = '@ResultTypeBM & 4'
		IF @ResultTypeBM & 4 > 0
			BEGIN
				--SELECT
				--	[Entity] = E.MemberKey,
				--	[Source] = ST.SourceTypeName
				--FROM 
				--	[pcINTEGRATOR_Data].[dbo].[Entity] E
				--	INNER JOIN [pcINTEGRATOR_Data].[dbo].[Source] S ON S.InstanceID = E.InstanceID AND S.VersionID = E.VersionID AND S.SourceID = E.SourceID
				--	INNER JOIN [pcINTEGRATOR].[dbo].[SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
				--WHERE
				--	E.InstanceID = @InstanceID AND
				--	E.VersionID = @VersionID AND
				--	E.MemberKey = '18' AND
				--	E.SelectYN <> 0 AND
				--	E.DeletedID IS NULL

				CREATE TABLE #LastPosted
					(
					Entity nvarchar(50) COLLATE DATABASE_DEFAULT,
					LastPostedSource date,
					Consolidation datetime
					)

				SET @SQLStatement = '
					INSERT INTO #LastPosted
						(
						Entity,
						LastPostedSource,
						Consolidation
						)
					SELECT
						Entity,
						LastPostedSource = MAX(CASE WHEN ConsolidationGroup IS NULL AND TransactionTypeBM & 17 > 0 THEN PostedDate ELSE NULL END),
						Consolidation = MAX(CASE WHEN ConsolidationGroup IS NOT NULL THEN Inserted ELSE NULL END)
					FROM
						' + @JournalTable + '
					WHERE
						Scenario = ''ACTUAL''' + CASE WHEN @FiscalYear IS NOT NULL THEN ' AND
						FiscalYear = ' + CONVERT(nvarchar(15), @FiscalYear) ELSE '' END + '
					GROUP BY
						Entity'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)

--LastPostedSource = MAX(CASE WHEN ConsolidationGroup IS NULL AND Source = ''iScala'' THEN PostedDate ELSE NULL END),

				--SELECT
				--	ResultTypeBM = 4,
				--	LP.Entity,
				--	E.EntityName,
				--	LP.LastPostedSource,
				--	LP.Consolidation
				--FROM
				--	#LastPosted LP
				--	INNER JOIN pcINTEGRATOR_Data..Entity E ON E.InstanceID = @InstanceID AND E.VersionID = @VersionID AND E.MemberKey = LP.Entity
				--ORDER BY
				--	LP.Entity

/*
				SELECT DISTINCT
					ResultTypeBM = 4,
					LP.Entity,
					E.EntityName,
					LP.LastPostedSource,
					LP.Consolidation
				FROM
					#LastPosted LP
					INNER JOIN pcINTEGRATOR_Data..Entity E ON E.InstanceID = @InstanceID AND E.VersionID = @VersionID AND E.MemberKey = LP.Entity
					INNER JOIN pcINTEGRATOR_Data..EntityHierarchy EH ON EH.EntityID = E.EntityID
					INNER JOIN pcINTEGRATOR_Data..Entity G ON G.InstanceID = EH.InstanceID AND G.VersionID = EH.VersionID AND G.EntityID = EH.EntityGroupID AND G.EntityTypeID = 0 AND G.SelectYN <> 0 AND G.DeletedID IS NULL
				WHERE
					(G.MemberKey = @Group_MemberKey OR @Group_MemberKey IS NULL)
				ORDER BY
					LP.Entity
*/
				SELECT DISTINCT
					ResultTypeBM = 4,
					Entity = E.MemberKey,
					E.EntityName,
					LP.LastPostedSource,
					LP.Consolidation
				FROM
					pcINTEGRATOR_Data..Entity G 
					INNER JOIN pcINTEGRATOR_Data..EntityHierarchy EH ON EH.InstanceID = G.InstanceID AND EH.VersionID = G.VersionID AND EH.EntityGroupID = G.EntityID 
					INNER JOIN pcINTEGRATOR_Data..Entity E ON E.InstanceID = G.InstanceID AND E.VersionID = G.VersionID AND E.EntityID = EH.EntityID
					LEFT JOIN #LastPosted LP ON LP.Entity = E.MemberKey
				WHERE
					G.InstanceID = @InstanceID AND
					G.VersionID = @VersionID AND
					G.EntityTypeID = 0 AND
					G.SelectYN <> 0 AND
					G.DeletedID IS NULL AND
					(G.MemberKey = @Group_MemberKey OR @Group_MemberKey IS NULL)
				ORDER BY
					E.MemberKey

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = '@ResultTypeBM & 8'
		IF @ResultTypeBM & 8 > 0
			BEGIN
				SELECT
					ResultTypeBM = 8,
					Group_MemberKey = G.MemberKey,
					Entity_MemberKey = E.MemberKey
				FROM
					pcINTEGRATOR_Data..EntityHierarchy EH
					INNER JOIN pcINTEGRATOR_Data..Entity G ON G.InstanceID = EH.InstanceID AND G.VersionID = EH.VersionID AND G.EntityID = EH.EntityGroupID AND G.EntityTypeID = 0 AND G.SelectYN <> 0 AND G.DeletedID IS NULL
					INNER JOIN pcINTEGRATOR_Data..Entity E ON E.InstanceID = EH.InstanceID AND E.VersionID = EH.VersionID AND E.EntityID = EH.EntityID AND E.EntityTypeID = -1 AND E.SelectYN <> 0 AND E.DeletedID IS NULL
				WHERE
					EH.InstanceID = @InstanceID AND
					EH.VersionID = @VersionID AND
					(G.MemberKey = @Group_MemberKey OR @Group_MemberKey IS NULL)

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		IF @SetJobLogYN <> 0 OR (@Deleted + @Inserted + @Updated) <> 0
			EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [pcINTEGRATOR].[dbo].[spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName, @AuthenticatedUserID = @AuthenticatedUserID
	SELECT [@ErrorNumber] = @ErrorNumber, [@ErrorSeverity] = @ErrorSeverity, [@ErrorState] = @ErrorState, [@ErrorProcedure] = @ErrorProcedure, [@ErrorStep] = @Step, [@ErrorLine] = @ErrorLine, [@ErrorMessage] = @ErrorMessage

	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
