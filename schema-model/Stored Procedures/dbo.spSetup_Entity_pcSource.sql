SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Entity_pcSource]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,
	@ModelingStatusID int = -40,
	@ModelingComment nvarchar(100) = 'Copied from Callisto',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000519,
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
	@ProcedureName = 'spSetup_Entity',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spSetup_Entity_pcSource] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1
EXEC [spSetup_Entity_pcSource] @UserID = -1174, @InstanceID = -1001, @VersionID = -1001, @Debug = 1
EXEC [spSetup_Entity_pcSource] @UserID = 3689, @InstanceID = 424, @VersionID = 1012, @Debug = 1
EXEC [spSetup_Entity_pcSource] @UserID = 6271, @InstanceID = 442, @VersionID = 1014, @Debug = 1

EXEC [spSetup_Entity_pcSource] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceInstanceID int = -10,
	@SourceVersionID int = -10,
	@SQLStatement nvarchar(max),	
	@ApplicationID int,
	@ApplicationName nvarchar(100),
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),
	@EntityGroupID int,
	@SourceID_Financials int,
	@SourceID_FxRate int,

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
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'JaWo',
	@Version nvarchar(50) = '2.0.3.2154'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup Entity',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'
		IF @Version = '2.0.3.2151' SET @Description = 'Set correct ProcedureID.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID. Remove @DemoYN.'

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

		SELECT
			@ApplicationID = [ApplicationID],
			@ApplicationName = [ApplicationName],
			@ETLDatabase = [ETLDatabase],
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

	SET @Step = 'Fill Entity'
	
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity]
				(
				InstanceID,
				VersionID,
				MemberKey,
				EntityName,
				SelectYN
				)
			SELECT
				InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ',
				MemberKey = CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE E.Entity END,
				EntityName = MAX(CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN REPLACE(E.EntityName, '' - '' + E.Par02, '''') ELSE E.EntityName END),
				SelectYN = MAX(CONVERT(int, E.SelectYN))
			FROM
				' + @ETLDatabase + '..Entity E
				INNER JOIN [Source] S ON S.SourceID = E.SourceID
				INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
			WHERE
				E.SourceID = ' + CONVERT(nvarchar(10), @SourceID_Financials) + ' AND
				NOT EXISTS (SELECT 1 FROM [Entity] pcIE WHERE pcIE.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND pcIE.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND pcIE.MemberKey = CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE E.Entity END)
			GROUP BY
				CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE E.Entity END'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity', * FROM [pcINTEGRATOR_Data].[dbo].[Entity] WHERE InstanceID = @InstanceID AND VersionID = @VersionID

	SET @Step = 'Fill Entity_Book'
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity_Book]
				(
				[InstanceID],
				[VersionID],
				[EntityID],
				[Book],
				[Currency],
				[BookTypeBM],
				SelectYN
				)
			SELECT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[EntityID] = pcIE.[EntityID],
				[Book] = CASE WHEN ST.SourceTypeFamilyID IN (1) AND BM.ModelID = -7 THEN E.Par02 ELSE CASE WHEN BM.ModelID = -7 THEN ''GL'' ELSE BM.ModelName END END,
				[Currency] = E.[Currency],
				[BookTypeBM] = CASE BM.ModelID WHEN -7 THEN 1 WHEN -3 THEN 4 ELSE 8 END + CASE WHEN BM.ModelID = -7 AND ((ST.SourceTypeFamilyID IN (1) AND E.Par08 = ''1'') OR ST.SourceTypeFamilyID NOT IN (1)) THEN 2 ELSE 0 END,
				SelectYN = E.SelectYN
			FROM
				' + @ETLDatabase + '..Entity E
				INNER JOIN [Source] S ON S.SourceID = E.SourceID
				INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
				INNER JOIN [Entity] pcIE ON pcIE.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND pcIE.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND pcIE.MemberKey = CASE WHEN ST.SourceTypeFamilyID IN (1, 5, 8) THEN E.Par01 ELSE E.Entity END
				INNER JOIN Model M ON M.ModelID = S.ModelID
				INNER JOIN Model BM ON BM.ModelID = M.BaseModelID
			WHERE
				E.SourceID IN (' + CONVERT(nvarchar(10), @SourceID_Financials) + ', ' + CONVERT(nvarchar(10), @SourceID_FxRate) + ') AND
				NOT EXISTS (SELECT 1 FROM [Entity_Book] EB WHERE EB.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND EB.EntityID = pcIE.EntityID AND EB.Book = CASE WHEN ST.SourceTypeFamilyID IN (1) AND BM.ModelID = -7 THEN E.Par02 ELSE CASE WHEN BM.ModelID = -7 THEN ''GL'' ELSE BM.ModelName END END)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		IF @Debug <> 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity_Book', EB.* FROM [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity] E ON E.EntityID = EB.EntityID WHERE E.InstanceID = @InstanceID AND E.VersionID = @VersionID


	SET @Step = 'Update Entity structure'
		EXEC [spPortalAdminSet_SegmentDimension] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID

	SET @Step = 'Update [EntityPropertyValue] (-2, SourceTypeID)'
		--Must handle other SourceTypes than E10. Fix later
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue]
			(
			[InstanceID],
			[VersionID],
			[EntityID],
			[EntityPropertyTypeID],
			[EntityPropertyValue],
			[SelectYN],
			[Version]
			)
		SELECT
			[InstanceID],
			[VersionID],
			[EntityID],
			[EntityPropertyTypeID] = -2,
			[EntityPropertyValue] = 11, --Epicor 10
			[SelectYN],
			[Version]
		FROM
			[Entity] E
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [EntityPropertyValue] EPV WHERE EPV.[EntityID] = E.[EntityID] AND EPV.[EntityPropertyTypeID] = -2)

	SET @Step = 'Add Group Entity to Entity table'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity]
			(
			[InstanceID],
			[VersionID],
			[MemberKey],
			[EntityName],
			[EntityTypeID]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[MemberKey] = 'Group',
			[EntityName] = 'Group',
			[EntityTypeID] = 0
		WHERE
			NOT EXISTS (SELECT 1 FROM [Entity] E WHERE E.[InstanceID] = @InstanceID AND E.[VersionID] = @VersionID AND E.[MemberKey] = 'Group')

		SET @EntityGroupID = @@IDENTITY

	SET @Step = 'Add Entities to EntityHierarchy table'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[EntityHierarchy]
			(
			[InstanceID],
			[VersionID],
			[EntityGroupID],
			[EntityID],
			[ParentID],
			[ValidFrom],
			[OwnershipDirect],
			[OwnershipUltimate],
			[OwnershipConsolidation],
			[ConsolidationMethodBM],
			[SortOrder]
			)
		SELECT
			[InstanceID],
			[E].[VersionID],
			[EntityGroupID] = @EntityGroupID,
			[EntityID],
			[ParentID] = @EntityGroupID,
			[ValidFrom] = '2018-01-01',
			[OwnershipDirect] = 1,
			[OwnershipUltimate] = 1,
			[OwnershipConsolidation] = 1,
			[ConsolidationMethodBM] = 1,
			[SortOrder] = 0
		FROM
			[Entity] E
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [EntityHierarchy] EH WHERE EH.InstanceID = @InstanceID AND EH.EntityID = E.EntityID)

	SET @Step = 'Copy Entity structure to ETL Entity'
		--Must check other sources than Financials in ETL Entity. Fix later
		SET @SQLStatement = '
			UPDATE ETLE
			SET
				[SelectYN] = CONVERT(int, E.SelectYN)
			FROM 
				[Entity] E
				INNER JOIN [' + @ETLDatabase + '].[dbo].[Entity] ETLE ON ETLE.EntityCode = E.MemberKey
			WHERE
				E.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				E.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + '

			UPDATE ETLE
			SET
				[SelectYN] = CONVERT(int, E.SelectYN) * CONVERT(int, EB.SelectYN)
			FROM 
				[Entity] E
				INNER JOIN [Entity_Book] EB ON EB.EntityID = E.EntityID
				INNER JOIN [' + @ETLDatabase + '].[dbo].[Entity] ETLE ON ETLE.EntityCode = E.MemberKey + ''_'' + EB.Book
			WHERE
				E.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				E.VersionID = ' + CONVERT(nvarchar(10), @VersionID)

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Copy Entity/Segment structure to MappedObject'
		SET @SQLStatement = '
			UPDATE MO
			SET
				[MappedObjectName] = JSN.SegmentName,
				[SelectYN] = CONVERT(int, E.SelectYN) * CONVERT(int, EB.SelectYN) * CONVERT(int, JSN.SelectYN)
			FROM 
				[Entity] E
				INNER JOIN [Entity_Book] EB ON EB.EntityID = E.EntityID
				INNER JOIN [Journal_SegmentNo] JSN ON JSN.EntityID = EB.EntityID AND JSN.Book = EB.Book
				INNER JOIN [' + @ETLDatabase + '].[dbo].[MappedObject] MO ON MO.Entity = E.MemberKey + CASE WHEN EB.BookTypeBM & 2 > 0 THEN '''' ELSE ''_'' + EB.Book END AND MO.ObjectName = JSN.SegmentCode AND MO.DimensionTypeID = -1
			WHERE
				E.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
				E.VersionID = ' + CONVERT(nvarchar(10), @VersionID)

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)


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
