SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Entity_Tree]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ResultTypeBM int = 63, --1 = Count enabled Legal Entities, 2 = Entity, 4 = Book, 8 = EntityType
	@BookTypeBM int = 19, --1 = Financials, 2 = Main, 4 = FxRate, 8 = Other
	@ShowAllYN bit = 0, --0 = Shows enabled Entities and Books, 1 = Shows all Entities and Books
	@EntityID int = NULL,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000285,
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

EXEC [spRun_Procedure_KeyValuePair] @JSON='[{"TKey":"InstanceID","TValue":"-1590"},{"TKey":"UserID","TValue":"18518"},
{"TKey":"VersionID","TValue":"-1590"},{"TKey":"ShowAllYN","TValue":"false"},{"TKey":"ResultTypeBM","TValue":"31"},{"TKey":"DebugBM","TValue":"15"}
]', @ProcedureName='spPortalAdminGet_Entity_Tree'

EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminGet_Entity_Tree',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spRun_Procedure_KeyValuePair] 
	@JSON='[
		{"TKey":"InstanceID","TValue":"-1287"},{"TKey":"UserID","TValue":"-10"},
		{"TKey":"VersionID","TValue":"-1287"},{"TKey":"ShowAllYN","TValue":"false"}]', 
	@ProcedureName='spPortalAdminGet_Entity_Tree'

EXEC [spPortalAdminGet_Entity_Tree] @UserID = -10, @InstanceID = -1187, @VersionID = -1125
EXEC [spPortalAdminGet_Entity_Tree] @UserID = -10, @InstanceID = -1240, @VersionID = -1178, @ShowAllYN = 1
EXEC [spPortalAdminGet_Entity_Tree] @UserID = -10, @InstanceID = -1335, @VersionID = -1273, @ResultTypeBM = 15

EXEC [spPortalAdminGet_Entity_Tree] @GetVersion = 1
*/

/*
Returns 3 resultsets to construct Entity tree.
The first resultset counts selected Entities.
Resultset 2 and 3 gives Entities and Books to be placed into the tree.
*/

SET ANSI_WARNINGS OFF

DECLARE

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
	@Version nvarchar(50) = '2.1.0.2162'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Displays Entity Tree.',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2141' SET @Description = 'Added ResultTypeBM = 8.'
		IF @Version = '2.0.2.2150' SET @Description = 'Code enhancement.'
		IF @Version = '2.0.3.2153' SET @Description = 'Added more result types.'
		IF @Version = '2.1.0.2162' SET @Description = 'Now obsolete and replaced by [spPortalAdminGet_Entity] @ResultTypeBM = 132. Still not removed for legacy reasons.'

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
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 SET @DebugBM = 3
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

	SET @Step = '@ResultTypeBM & 1, Count enabled Entities'
		IF @ResultTypeBM & 1 > 0
			SELECT 
				ResultTypeBM = 1,
				EntityLicensed# = COUNT(1),
				EntitySelected# = COUNT(CASE WHEN SelectYN <> 0 THEN 1 END)
			FROM
				Entity
			WHERE
				InstanceID = @InstanceID AND
				VersionID = @VersionID AND
				EntityTypeID = -1
		
	SET @Step = '@ResultTypeBM & 2, Entity tree'
		IF @ResultTypeBM & 2 > 0
			SELECT DISTINCT
				ResultTypeBM = 2,
				EntityGroupID = EH.EntityGroupID,
				EntityGroupName = EG.EntityName,
				EntityID = EH.EntityID,
				MemberKey = E.MemberKey,
				EntityName = E.EntityName,
				EntityParentID = EH.ParentID,
				EntityTypeID = E.EntityTypeID,
				EntityTypeName = ET.EntityTypeName,
				SelectYN = E.SelectYN,
				SortOrder = EH.SortOrder
			FROM
				EntityHierarchy EH
				INNER JOIN Entity E ON E.InstanceID = EH.InstanceID AND E.VersionID = @VersionID AND E.EntityID = EH.EntityID AND (E.SelectYN <> 0 OR @ShowAllYN <> 0)
				INNER JOIN Entity EG ON E.InstanceID = EH.InstanceID AND E.VersionID = @VersionID AND EG.EntityID = EH.EntityGroupID
				LEFT JOIN EntityType ET ON ET.EntityTypeID = E.EntityTypeID
			WHERE
				EH.InstanceID = @InstanceID AND
				EH.VersionID = @VersionID
			ORDER BY
				EH.SortOrder

--			SELECT * FROM Entity WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = '@ResultTypeBM & 4, Books'
		IF @ResultTypeBM & 4 > 0  
			BEGIN
				SELECT
					ResultTypeBM = 4,
					EB.EntityID,
					MemberKey = E.MemberKey,
					E.EntityName,
					EB.Book,
					EB.Currency,
					EB.BookTypeBM,
					EB.SelectYN
				FROM
					Entity_Book EB
					INNER JOIN Entity E ON E.InstanceID = EB.InstanceID AND E.VersionID = @VersionID AND E.EntityID = EB.EntityID AND (E.SelectYN <> 0 OR @ShowAllYN <> 0)
				WHERE
					EB.InstanceID = @InstanceID AND
					EB.VersionID = @VersionID AND
					EB.BookTypeBM & @BookTypeBM > 0 AND
					(EB.SelectYN <> 0 OR @ShowAllYN <> 0)
			END

	SET @Step = '@ResultTypeBM & 8, Entity types'
		IF @ResultTypeBM & 8 > 0  
			BEGIN
				SELECT 
					[ResultTypeBM] = 8,
					[EntityTypeID],
					[EntityTypeName],
					[EntityTypeDescription]
				FROM
					[EntityType]
				ORDER BY
					[EntityTypeID] DESC
			END

	SET @Step = '@ResultTypeBM & 16, Consolidation method'
		IF @ResultTypeBM & 16 > 0  
			BEGIN
				SELECT 
					[ResultTypeBM] = 16,
					[ConsolidationMethodBM],
					[ConsolidationMethodName],
					[ConsolidationMethodDescription]
				FROM
					[ConsolidationMethod]
				ORDER BY
					[ConsolidationMethodBM]
			END

	SET @Step = '@ResultTypeBM & 32, Consolidation method'
		IF @ResultTypeBM & 32 > 0  
			BEGIN
				SELECT 
					[ResultTypeBM] = 32,
					EH.EntityGroupID,
					GroupName = EG.EntityName,
					FromPeriod = CONVERT(date, ValidFrom),
					ToPeriod = '',
					EH.ConsolidationMethodBM,
					OwnershipConsolidation
				FROM
					pcINTEGRATOR_Data..[EntityHierarchy] EH
					INNER JOIN Entity EG ON EG.EntityID = EH.EntityGroupID
				WHERE
					EH.InstanceID = @InstanceID AND
					EH.VersionID = @VersionID AND
					EH.EntityID = @EntityID
				ORDER BY
					EG.EntityName
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
