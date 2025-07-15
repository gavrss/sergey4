SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Entity]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL,	--Mandatory

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000446,
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
	@ProcedureName = 'spSetup_Entity',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spSetup_Entity] @UserID = -10, @InstanceID = -1319, @VersionID = -1257, @SourceTypeID = 11, @Debug=1
EXEC [spSetup_Entity] @UserID = -10, @InstanceID = 525, @VersionID = 1054, @SourceTypeID = 11, @DebugBM=1

EXEC [spSetup_Entity] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@JSON nvarchar(max),
	@EntityGroupID int,

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
	@ModifiedBy nvarchar(50) = 'DoSa',
	@Version nvarchar(50) = '2.1.1.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup Entity',
			@MandatoryParameter = 'SourceTypeID' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created. Added @SourceTypeID parameter.'
		IF @Version = '2.0.3.2151' SET @Description = 'Code enhancement. Added @SourceTypeID as mandatory parameter. Set SegmentDimension.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID. Enhanced debugging. Remove @DemoYN.'
		IF @Version = '2.1.0.2163' SET @Description = 'Added @Step = Add Group Entity to EntityBook table.'
		IF @Version = '2.1.0.2164' SET @Description = 'Added @Step = Update [Journal_SegmentNo]. But later deleted this step. When adding/updating [Journal_SegmentNo], use SP [spSetup_Segment].'
		IF @Version = '2.1.0.2165' SET @Description = 'Added iScala.'
		IF @Version = '2.1.1.2168' SET @Description = 'Handle SIE4.'
		IF @Version = '2.1.1.2171' SET @Description = 'Only add Group member Group if no other groups exist.'
		IF @Version = '2.1.1.2174' SET @Description = 'Add DISTINCT word to @Step = Update [EntityPropertyValue] (-2, SourceTypeID)'
		IF @Version = '2.1.1.2179' SET @Description = 'Moved setting of @EntityGroupID before the Step = ''Add Group Entity to Entity_Book table''. Added back the Step = ''Add Entities to EntityHierarchy table''.'
		IF @Version = '2.1.2.2199' SET @Description = 'Added P21.'

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

		IF @DebugBM & 2 > 0
			SELECT
				[@ProcedureName] = @ProcedureName,
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@SourceTypeID] = @SourceTypeID,
				[@JobID] = @JobID

	SET @Step = 'Fill Entity'
		SET @JSON = '
					[
					{"TKey" : "UserID",  "TValue": "' + CONVERT(nvarchar(15), @UserID) + '"},
					{"TKey" : "InstanceID",  "TValue": "' + CONVERT(nvarchar(15), @InstanceID) + '"},
					{"TKey" : "VersionID",  "TValue": "' + CONVERT(nvarchar(15), @VersionID) + '"},
					{"TKey" : "SourceTypeID",  "TValue": "' + CONVERT(nvarchar(15), @SourceTypeID) + '"},
					{"TKey" : "JobID",  "TValue": "' + CONVERT(nvarchar(15), @JobID) + '"},
					{"TKey" : "Debug",  "TValue": "' + CONVERT(nvarchar(15), @DebugSub) + '"}
					]'

		IF @DebugBM & 2 > 0 PRINT @JSON
		
		IF @SourceTypeID = 1 --Epicor ERP
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Entity_EpicorERP', @JSON = @JSON

		IF @SourceTypeID = 3 --iScala
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Entity_iScala', @JSON = @JSON
		
		IF @SourceTypeID = 5 --P21
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Entity_P21', @JSON = @JSON

		--IF @SourceTypeID = 7 --SIE4
		--	EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Entity_SIE4', @JSON = @JSON

		IF @SourceTypeID = 8 --Navision
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Entity_Navision', @JSON = @JSON

		IF @SourceTypeID = 11 --Epicor ERP
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Entity_EpicorERP', @JSON = @JSON

		IF @SourceTypeID = 12 --Enterprise
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Entity_Enterprise', @JSON = @JSON

		IF @SourceTypeID = 15 --pcSource
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Entity_pcSource', @JSON = @JSON
		
		IF @SourceTypeID = 16 --pcETL
			EXEC spRun_Procedure_KeyValuePair @ProcedureName = 'spSetup_Entity_pcETL', @JSON = @JSON
	
	SET @Step = 'Update [EntityPropertyValue] (-2, SourceTypeID)'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue]
			(
			[InstanceID],
			[VersionID],
			[EntityID],
			[EntityPropertyTypeID],
			[EntityPropertyValue]
			)
		SELECT DISTINCT
			E.[InstanceID],
			E.[VersionID],
			[EntityID],
			[EntityPropertyTypeID] = -2,
			[EntityPropertyValue] = CONVERT(nvarchar(15), @SourceTypeID)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Model] M ON M.[InstanceID] = E.[InstanceID] AND M.[VersionID] = E.[VersionID] AND M.[BaseModelID] IN (-7)
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Source] S ON S.[InstanceID] = M.[InstanceID] AND S.[VersionID] = M.[VersionID] AND S.[ModelID] = M.[ModelID] AND S.[SourceTypeID] = @SourceTypeID
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [EntityPropertyValue] EPV WHERE EPV.[EntityID] = E.[EntityID] AND EPV.[EntityPropertyTypeID] = -2)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Add Group Entity to Entity table'
		IF (SELECT COUNT(1) FROM [pcINTEGRATOR_Data].[dbo].[Entity] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID AND [EntityTypeID] = 0) = 0
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity]
					(
					[InstanceID],
					[VersionID],
					[SourceID],
					[MemberKey],
					[EntityName],
					[EntityTypeID]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[SourceID] = 0,
					[MemberKey] = 'Group',
					[EntityName] = 'Group',
					[EntityTypeID] = 0
				WHERE
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Entity] E WHERE E.[InstanceID] = @InstanceID AND E.[VersionID] = @VersionID AND E.[MemberKey] = 'Group')

				SET @Inserted = @Inserted + @@ROWCOUNT
		END

	SET @Step = 'Set @EntityGroupID'
		SELECT
			@EntityGroupID = MIN(EntityID)
		FROM
			[pcINTEGRATOR_Data].[dbo].[Entity] E
		WHERE
			E.[InstanceID] = @InstanceID AND
			E.[VersionID] = @VersionID AND
			E.[EntityTypeID] = 0

	SET @Step = 'Add Group Entity to Entity_Book table'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Entity_Book]
			(
			[InstanceID],
			[VersionID],
			[EntityID],
			[Book],
			[Currency],
			[BookTypeBM],
			[SelectYN]
			)
		SELECT
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[EntityID] = @EntityGroupID,
			[Book] = 'Group',
			[Currency] = NULL,
			[BookTypeBM] = 16,
			[SelectYN] = 1
		WHERE
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Entity_Book] E WHERE E.[InstanceID] = @InstanceID AND E.[VersionID] = @VersionID AND E.[EntityID] = @EntityGroupID AND E.[Book] = 'Group' AND E.[BookTypeBM] = 16)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Add Entities to EntityHierarchy table'
--/* Removed 20210703 by JaWo
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
			[pcINTEGRATOR_Data].[dbo].[Entity] E
		WHERE
			E.InstanceID = @InstanceID AND
			E.VersionID = @VersionID AND
			E.EntityTypeID IN (0, -1) AND
			E.SelectYN <> 0 AND
			E.DeletedID IS NULL AND
			NOT EXISTS (SELECT 1 FROM [EntityHierarchy] EH WHERE EH.InstanceID = @InstanceID AND EH.VersionID = @VersionID AND EH.EntityID = E.EntityID)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Add rows for Budget selection'
		EXEC [dbo].[spSetup_Budget_Selection] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @SourceTypeID = @SourceTypeID, @JobID = @JobID, @Debug= @DebugSub

	SET @Step = 'Return information'
		IF @DebugBM & 1 > 0 
			BEGIN
				IF @DebugBM & 1 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity', EB.* FROM [pcINTEGRATOR_Data].[dbo].[Entity] EB WHERE EB.[InstanceID] = @InstanceID AND EB.[VersionID] = @VersionID
				IF @DebugBM & 1 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..Entity_Book', EB.* FROM [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB WHERE EB.InstanceID = @InstanceID AND EB.VersionID = @VersionID
				IF @DebugBM & 1 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..EntityPropertyValue', EB.* FROM [pcINTEGRATOR_Data].[dbo].[EntityPropertyValue] EB WHERE EB.[InstanceID] = @InstanceID AND EB.[VersionID] = @VersionID
				IF @DebugBM & 1 > 0 SELECT [Table] = 'pcINTEGRATOR_Data..[EntityHierarchy]', EH.* FROM [pcINTEGRATOR_Data].[dbo].[EntityHierarchy] EH WHERE EH.[InstanceID] = @InstanceID AND EH.[VersionID] = @VersionID
			END

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
GO
