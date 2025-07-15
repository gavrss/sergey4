SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminGet_Object]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@StartNode int = 0,
	@ReturnRowsYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000340,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminGet_Object',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_Object] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1
EXEC [spPortalAdminGet_Object] @UserID=-10, @InstanceID=390, @VersionID=1011, @StartNode = -25, @Debug=1 -- pcPortal Features
EXEC [spPortalAdminGet_Object] @UserID=-10, @InstanceID=390, @VersionID=1011, @StartNode = -104, @Debug=1 -- Callisto Actions Access

EXEC [spPortalAdminGet_Object] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@CalledYN bit = 1,

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
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
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get Object tree',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.1.2143' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2147' SET @Description = 'Changed SortOrder, using CTE.'
		IF @Version = '2.0.3.2154' SET @Description = 'Set @ProcedureID in JobLog.'

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

	SET @Step = 'Create temp table #Object'
		IF OBJECT_ID (N'tempdb..#Object', N'U') IS NULL
			BEGIN
				SET @CalledYN = 0

				CREATE TABLE #Object
					(
					[InstanceID] int,
					[ObjectID] int,
					[ObjectName] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[ObjectTypeBM] int,
					[ParentObjectID] int,
					[SecurityLevelBM] int,
					[InheritedFrom] int,
					[SortOrder] nvarchar(1000) COLLATE DATABASE_DEFAULT,
					[Level] int,
					[SelectYN] bit,
					[Version] nvarchar(100) COLLATE DATABASE_DEFAULT,
					[Children] int
					)
			END

	SET @Step = 'Fill temp table #Object using CTE'
		;WITH cte AS
		(
		   --Find top nodes for tree
			SELECT
				[ObjectID],
				[ParentObjectID],
				[Depth] = 1,
				[Path] = RIGHT('0000' + CONVERT(nvarchar(MAX), [SortOrder]), 5)
			FROM
				[pcINTEGRATOR].[dbo].[Object]
			WHERE
				[InstanceID] IN (0, @InstanceID) AND
				[ObjectID] = @StartNode AND
				[SelectYN] <> 0
			UNION ALL
			SELECT
				O.[ObjectID],
				O.[ParentObjectID],
				Depth = c.Depth + 1,
				[Path] = c.[Path] + N'|' + RIGHT('0000' + CONVERT(nvarchar(MAX), O.[SortOrder]), 5)
			FROM
				[pcINTEGRATOR].[dbo].[Object] O
				INNER JOIN cte c on c.[ObjectID] = O.[ParentObjectID]
			WHERE
				[InstanceID] IN (0, @InstanceID) AND
				[SelectYN] <> 0
		)

		INSERT INTO #Object
			(
			[InstanceID],
			[ObjectID],
			[ObjectName],
			[ObjectTypeBM],
			[ParentObjectID],
			[SecurityLevelBM],
			[InheritedFrom],
			[SortOrder],
			[Level],
			[SelectYN],
			[Version],
			[Children]
			)
		SELECT
			[InstanceID],
			cte.[ObjectID],
			[ObjectName],
			[ObjectTypeBM],
			cte.[ParentObjectID],
			[SecurityLevelBM],
			[InheritedFrom],
			[SortOrder] = cte.[Path],
			[Level] = cte.[Depth],
			[SelectYN],
			[Version],
			[Children] = 0
		FROM
			cte
			INNER JOIN [pcINTEGRATOR].[dbo].[Object] O ON O.ObjectID = cte.ObjectID
		ORDER BY
			[SortOrder]

	SET @Step = 'Count children'
		UPDATE O
		SET
			Children = sub.Children
		FROM
			#Object O
			INNER JOIN
				(
				SELECT
					ObjectID = ParentObjectID,
					Children = COUNT(1)
				FROM
					#Object
				GROUP BY
					ParentObjectID
				) sub ON sub.ObjectID = O.ObjectID

	SET @Step = 'Return rows'
		IF @ReturnRowsYN <> 0
			BEGIN
				SELECT
					*
				FROM
					#Object
				ORDER BY
					SortOrder

				SET @Selected = @Selected + @@ROWCOUNT
			END

	SET @Step = 'Drop temp table'
		IF @CalledYN = 0 DROP TABLE #Object

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureID = @ProcedureID, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

--GO
--EXEC [spPortalAdminGet_Object_New] @UserID=-10, @InstanceID=390, @VersionID=1011, @StartNode = -2, @Debug=1 -- Callisto Actions Access
GO
