SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spPortalAdminCreate_NewEtlProcess]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@DemoYN bit = 1,
	@ModelingStatusID int = -40,
	@ModelingComment nvarchar(100) = 'Copied from Callisto',

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000241,
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
	@ProcedureName = 'spPortalAdminCreate_NewEtlProcess',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminCreate_NewEtlProcess] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1
EXEC [spPortalAdminCreate_NewEtlProcess] @UserID = -1174, @InstanceID = -1001, @VersionID = -1001, @DemoYN = 1, @Debug = 1
EXEC [spPortalAdminCreate_NewEtlProcess] @UserID = 3689, @InstanceID = 424, @VersionID = 1012, @DemoYN = 0, @Debug = 1
EXEC [spPortalAdminCreate_NewEtlProcess] @UserID = 6271, @InstanceID = 442, @VersionID = 1014, @DemoYN = 0, @Debug = 1

EXEC [spPortalAdminCreate_NewEtlProcess] @GetVersion = 1
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
			@ProcedureDescription = 'Create new ETLProcess',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '1.4.0.2139' SET @Description = 'Procedure created.'
		IF @Version = '2.0.0.2141' SET @Description = 'Bug regarding ModelBM in DataClass fixed. Handle loading via Journal.'
		IF @Version = '2.0.1.2143' SET @Description = 'Enhanced structure, changed database to [pcINTEGRATOR_Data].'		
		IF @Version = '2.0.2.2148' SET @Description = 'DB-172: Add [ObjectGuiBehaviorBM] column into [Dimension_StorageType] table.'
		IF @Version = '2.0.3.2151' SET @Description = 'Renamed column [Formula] to [SourceFormula] when inserting into [Measure] table.'
		IF @Version = '2.0.3.2152' SET @Description = 'Removed columns [GetProc] and [SetProc] from [DataClass] table. DB-6: Scenario dimension should be always secured by default.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID.'

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

	SET @Step = 'Standard Callisto Setup; [spInsert_ETL_MappedObject]'
		EXEC [spInsert_ETL_MappedObject] @ApplicationID = @ApplicationID                    --Step 1600, Records are now added to the MappedObject table.

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

	SET @Step = 'Standard Callisto Setup'
		EXEC [spInsert_SqlQuery] @ApplicationID = @ApplicationID                            --Step 2090, Default SqlQueries will be added.
		EXEC [spInsert_ETL_CheckSum] @ApplicationID = @ApplicationID                        --Step 2100, Default CheckSums will be added.

		EXEC [spCreate_Application] @ApplicationID = @ApplicationID                         --Step 2200, Objects for the destination database will now be prepared

		EXEC [spCreate_Job_Agent] @ApplicationID = @ApplicationID, @JobType = 'Create', @DemoYN = @DemoYN      --Step 2300, A SQL Server Agent job for creation of the destination database and importing objects will now be created

		EXEC [spStart_Job_Agent] @ApplicationID = @ApplicationID, @StepName = 'Create'      --Step 2400, SQL Server Agent will now create the destination database.
		EXEC [spSet_User] @ApplicationID = @ApplicationID                                   --Step 2420, Sets the default admin user
		EXEC [spStart_Job_Agent] @ApplicationID = @ApplicationID, @StepName = 'Import'      --Step 2440, SQL Server Agent will now import the new Models and Dimensions.

		EXEC [spCreate_Canvas_Table] @ApplicationID = @ApplicationID                        --Step 2500, All needed Canvas tables will now be created in the destination database.
		EXEC [spCreate_Canvas_Procedure] @ApplicationID = @ApplicationID                    --Step 2600, All needed Canvas procedures will now be created in the destination database.
		EXEC [spCreate_Canvas_Report] @ApplicationID = @ApplicationID                       --Step 2700, All standard reports will now be created in the destination database.

		EXEC [spCreate_ETL_Object_Final] @ApplicationID = @ApplicationID                    --Step 2800, All views and procedures that are used for selecting data from the source database(s) and inserts it to the destination database will now be created.

		SET @SQLStatement = 'EXEC [spIU_Load_All] @LoadTypeBM = 1, @FrequencyBM = 3, @Rows = 10000'      --Step 2900, All ETL tables will now be filled with data.
		SET @SQLStatement = 'EXEC [' + @ETLDatabase + '].dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		SET @SQLStatement = 'EXEC [spIU_Load_All] @LoadTypeBM = 2, @FrequencyBM = 3, @Rows = 10000'      --Step 3200, All dimension tables will be loaded. If the dimension tables are big, this will take a while the first time it is loading.
		SET @SQLStatement = 'EXEC [' + @ETLDatabase + '].dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		EXEC [spInsert_ExtraHierarchy_Member] @ApplicationID = @ApplicationID               --Step 3300, Loads initial members to Extra hierarchies
		EXEC [spCheck_HierarchyTables] @ApplicationID = @ApplicationID                      --Step 3350, Check for empty hierarchies in all dimensions

		EXEC [spCreate_Job_Agent] @ApplicationID = @ApplicationID, @JobType = 'Load', @DemoYN = @DemoYN              --Step 3400, A SQL Server Agent job for loading data into the destination database and deploying the cube(s) will now be created
		EXEC [spStart_Job_Agent] @ApplicationID = @ApplicationID, @StepName = 'Deploy'            --Step 3500, The Fact tables will be created and all the dimensions will now be deployed into the cube.

		EXEC [spAlter_ChangeDatetime] @ApplicationID = @ApplicationID                       --Step 3550, The ChangeDatetime field on all Fact tables will be changed to nvarchar(100)
		EXEC [spCreate_ETL_Object_Initial] @ApplicationID = @ApplicationID, @DataBaseBM = 2 --Step 3600, All ETL Objects in the Destination database will now be created.

		SET @SQLStatement = 'EXEC [spIU_Load_All] @LoadTypeBM = 28, @FrequencyBM = 3, @Rows = 10000'      --Step 3700, All FACT tables will now be loaded and the CheckSums will run.
		SET @SQLStatement = 'EXEC [' + @ETLDatabase + '].dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Only for @DemoYN = 1 and SourceDB = DSPSOURCE01.ERP10. Insert into WorkflowRow and Demodata'
		IF @DemoYN <> 0 AND 
				(SELECT 
					MAX(S.SourceDatabase)
				FROM
					[Source] S
					INNER JOIN [Model] M ON M.ModelID = S.ModelID AND M.BaseModelID = -7
					INNER JOIN [Application] A ON A.ApplicationID = M.ApplicationID AND A.InstanceID = @InstanceID AND A.VersionID = @VersionID)
				= 'DSPSOURCE01.ERP10'
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[WorkflowRow]
					(
					[InstanceID],
					[WorkflowID],
					[DimensionID],
					[Dimension_MemberKey],
					[CogentYN]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[WorkflowID] = WF.[WorkflowID],
					[DimensionID] = WFR.[DimensionID],
					[Dimension_MemberKey] = WFR.[Dimension_MemberKey],
					[CogentYN] = WFR.[CogentYN]
				FROM
					[WorkflowRow] WFR
					INNER JOIN [Workflow] WF ON WF.[InstanceID] = @InstanceID AND WF.[VersionID] = @VersionID AND WF.[InheritedFrom] = WFR.[WorkflowID]
				WHERE
					WFR.[InstanceID] = @SourceInstanceID AND
					NOT EXISTS (SELECT 1 FROM [WorkflowRow] WFRD WHERE WFRD.InstanceID = @InstanceID AND WFRD.[WorkflowID] = WF.[WorkflowID] AND WFRD.[DimensionID] = WFR.[DimensionID] AND WFRD.[Dimension_MemberKey] = WFR.[Dimension_MemberKey])

				EXEC [dbo].[spCreate_DemoData] 
					@UserID = @UserID,
					@InstanceID = @InstanceID,
					@VersionID = @VersionID
			END

	SET @Step = 'Set Initial WorkflowState'
		SET @SQLStatement = '
			UPDATE F
			SET
				[WorkflowState_MemberId] = W.InitialWorkflowStateID
			FROM
				' + @CallistoDatabase + '.[dbo].[FACT_Financials_default_partition] F
				INNER JOIN [Workflow] W ON
							W.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND
							W.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND
							W.ScenarioID = F.[Scenario_MemberId] AND
							F.[Time_MemberId] BETWEEN W.[TimeFrom] AND W.[TimeTo]'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		EXEC [spStart_Job_Agent] @ApplicationID = @ApplicationID, @StepName = 'Deploy'            --Step 3800, All the data will now be deployed into the cube.

		EXEC [spInsert_Extension] @ApplicationID = @ApplicationID                           --Step 5000, All licensed possible extension databases are added to the selection list.

		EXEC [spCreate_pcEXTENSION] @ApplicationID = @ApplicationID                         --Step 5100, All selected databases are created.

		EXEC [spRun_pcOBJECT] @ApplicationID = @ApplicationID                               --Step 5200, Runs any SPs defined in the pcOBJECT database

		--EXEC [spCheck_Setup] @InstanceID = @InstanceID                                    --Step 9000, Summary of the messages during setup.

	SET @Step = 'Copy from Callisto to v2, Process'
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Process]
				(
				[InstanceID],
				[VersionID],
				[ProcessBM],
				[ProcessName],
				[ProcessDescription],
				[ModelingStatusID],
				[ModelingComment],
				[InheritedFrom],
				[SelectYN]
				)
			SELECT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[ProcessBM] = 0,
				[ProcessName] = Label,
				[ProcessDescription] = Label,
				[ModelingStatusID] = ' + CONVERT(nvarchar(10), @ModelingStatusID) + ',
				[ModelingComment] = ''' + @ModelingComment + ''',
				[InheritedFrom] = P.ProcessID,
				[SelectYN] = 1
			FROM
				' + @ETLDatabase + '.[dbo].[XT_ModelDefinition] MD
				INNER JOIN [Process] P ON P.InstanceID = ' + CONVERT(nvarchar(10), @SourceInstanceID) + ' AND P.VersionID = ' + CONVERT(nvarchar(10), @SourceVersionID) + ' AND P.[ProcessName] = MD.Label
			WHERE
				NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Process] PD WHERE PD.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND PD.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND PD.[ProcessName] = MD.Label)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'UPDATE ProcessID in Workflow'
		UPDATE WF
		SET
			[ProcessID] = P.ProcessID
		FROM
			[pcINTEGRATOR_Data].[dbo].[Workflow] WF
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[Process] P ON P.InstanceID = @InstanceID AND P.VersionID = @VersionID AND P.InheritedFrom = -108
		WHERE
			WF.InstanceID = @InstanceID AND
			WF.VersionID = @VersionID

	SET @Step = 'INSERT INTO OrganizationHierarchy_Process'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy_Process]
			(
			[InstanceID],
			[VersionID],
			[OrganizationHierarchyID],
			[ProcessID]
			)
		SELECT 
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[OrganizationHierarchyID] = OH.[OrganizationHierarchyID],
			[ProcessID] = P.ProcessID
		FROM
			[Process] P
			INNER JOIN [OrganizationHierarchy] OH ON OH.InstanceID = @InstanceID AND OH.VersionID = @VersionID AND OH.InheritedFrom = -130
		WHERE
			P.InstanceID = @InstanceID AND 
			P.VersionID = @VersionID AND
			P.InheritedFrom = -108 AND
			NOT EXISTS (SELECT 1 FROM [OrganizationHierarchy_Process] OHP WHERE OHP.[InstanceID] = @InstanceID AND OHP.[OrganizationHierarchyID] = OH.[OrganizationHierarchyID] AND OHP.[ProcessID] = P.ProcessID)

	SET @Step = 'Copy from Callisto to v2, DataClass'
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass]
				(
				[InstanceID],
				[VersionID],
				[DataClassName],
				[DataClassDescription],
				[DataClassTypeID],
				[ModelBM],
				[StorageTypeBM],
				[ActualDataClassID],
				[ModelingStatusID],
				[ModelingComment],
				[InheritedFrom],
				[SelectYN]
				)
			SELECT DISTINCT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[DataClassName] = MD.Label,
				[DataClassDescription] = MD.Label,
				[DataClassTypeID] = -1,
				[ModelBM] = M.ModelBM,
				[StorageTypeBM] = 4,
				[ActualDataClassID] = NULL,
				[ModelingStatusID] = ' + CONVERT(nvarchar(10), @ModelingStatusID) + ',
				[ModelingComment] = ''' + @ModelingComment + ''',
				[InheritedFrom] = DC.DataClassID,
				[SelectYN] = 1
			FROM
				' + @ETLDatabase + '.[dbo].[XT_ModelDefinition] MD
				INNER JOIN [DataClass] DC ON DC.InstanceID = ' + CONVERT(nvarchar(10), @SourceInstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(10), @SourceVersionID) + ' AND DC.[DataClassName] = MD.Label
				LEFT JOIN [Model] M ON M.ModelID BETWEEN -1000 AND -1 AND M.ModelName = MD.Label
			WHERE
				NOT EXISTS (SELECT 1 FROM [DataClass] DC WHERE DC.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND DC.[DataClassName] = MD.Label)'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Insert into Grid'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Grid]
			(
			[InstanceID],
			[GridName],
			[GridDescription],
			[DataClassID],
			[GridSkinID],
			[GetProc],
			[SetProc],
			[InheritedFrom]
			)
		SELECT 
			[InstanceID] = @InstanceID,
			[GridName] = G.[GridName],
			[GridDescription] = G.[GridDescription],
			[DataClassID] = DC.DataClassID,
			[GridSkinID],
			[GetProc] = G.[GetProc],
			[SetProc] = G.[SetProc],
			[InheritedFrom] = G.[GridID]
		FROM
			[Grid] G
			INNER JOIN [DataClass] DC ON DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND DC.InheritedFrom = G.DataClassID 
		WHERE
			G.InstanceID = @SourceInstanceID AND
			NOT EXISTS (SELECT 1 FROM [Grid] GD WHERE GD.InstanceID = @InstanceID AND GD.GridName = G.GridName)

	SET @Step = 'Insert into Grid_Dimension'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Grid_Dimension]
			(
			[InstanceID],
			[GridID],
			[DimensionID],
			[GridAxisID]
			)
		SELECT 
			[InstanceID],
			[GridID],
			[DimensionID],
			[GridAxisID]
		FROM
			(
			SELECT DISTINCT
				[InstanceID] = @InstanceID,
				[GridID],
				[DimensionID] = -1,
				[GridAxisID] = -2
			FROM
				[Grid] G
			WHERE
				G.InstanceID = @InstanceID 
			
			UNION SELECT DISTINCT 
				[InstanceID] = @InstanceID,
				[GridID],
				[DimensionID] = -7,
				[GridAxisID] = -3
			FROM
				[Grid] G
			WHERE
				G.InstanceID = @InstanceID 		
			) sub			
		WHERE
			NOT EXISTS (SELECT 1 FROM [Grid_Dimension] GD WHERE GD.InstanceID = @InstanceID AND GD.GridID = sub.GridID AND GD.[DimensionID] IN (-1, -7))

	SET @Step = 'Copy from Callisto to v2, DataClass_Process'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Process]
			(
			[InstanceID],
			[VersionID],
			[DataClassID],
			[ProcessID]
			)
		SELECT
			P.[InstanceID],
			P.[VersionID],
			DC.[DataClassID],
			P.[ProcessID]
		FROM
			[Process] P
			INNER JOIN [DataClass] DC ON DC.InstanceID = P.InstanceID AND DC.VersionID = P.VersionID AND DC.DataClassName = P.ProcessName
		WHERE
			P.InstanceID = @InstanceID AND
			P.VersionID = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [DataClass_Process] DCP WHERE DCP.InstanceID = P.InstanceID AND DCP.VersionID = P.VersionID AND DCP.DataClassID = DC.DataClassID AND DCP.[ProcessID] = P.[ProcessID])

	SET @Step = 'Copy from Callisto to v2, Measure'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Measure]
			(
			[InstanceID],
			[DataClassID],
			[VersionID],
			[MeasureName],
			[MeasureDescription],
			[SourceFormula],
			[ExecutionOrder],
			[MeasureParentID],
			[DataTypeID],
			[FormatString],
			[ValidRangeFrom],
			[ValidRangeTo],
			[Unit],
			[AggregationTypeID],
			[InheritedFrom],
			[SortOrder],
			[ModelingStatusID],
			[ModelingComment],
			[SelectYN]
			)
		SELECT
			[InstanceID] = DC.[InstanceID],
			[DataClassID] = DC.[DataClassID],
			[VersionID] = DC.[VersionID],
			[MeasureName] = DC.DataClassName,
			[MeasureDescription] = 'Unified measure',
			[SourceFormula] = NULL,
			[ExecutionOrder] = 0,
			[MeasureParentID] = NULL,
			[DataTypeID] = -3,
			[FormatString] = '#,##0',
			[ValidRangeFrom] = NULL,
			[ValidRangeTo] = NULL,
			[Unit] = 'Generic',
			[AggregationTypeID] = -1,
			[InheritedFrom] = NULL,
			[SortOrder] = 1,
			[ModelingStatusID] = @ModelingStatusID,
			[ModelingComment] = @ModelingComment,
			[SelectYN] = 1
		FROM
			[DataClass] DC
		WHERE
			DC.[InstanceID] = @InstanceID AND
			DC.[VersionID] = @VersionID AND 
			NOT EXISTS (SELECT 1 FROM [Measure] M WHERE M.[InstanceID] = DC.[InstanceID] AND M.[DataClassID] = DC.[DataClassID] AND M.[VersionID] = DC.[VersionID] AND M.[MeasureName] = DC.DataClassName)

	SET @Step = 'Copy from Callisto to v2, Dimension'
		SET @SQLStatement = '
			INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension]
				(
				[InstanceID],
				[DimensionName],
				[DimensionDescription],
				[DimensionTypeID],
				[GenericYN],
				[MultipleProcedureYN],
				[AllYN],
				[HiddenMember],
				[Hierarchy],
				[TranslationYN],
				[DefaultSelectYN],
				[DefaultValue],
				[DeleteJoinYN],
				[SourceTypeBM],
				[MasterDimensionID],
				[HierarchyMasterDimensionID],
				[InheritedFrom],
				[SeedMemberID],
				[ModelingStatusID],
				[ModelingComment],
				[Introduced],
				[SelectYN]
				)
			SELECT DISTINCT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[DimensionName] = DD.Label,
				[DimensionDescription] = DD.[Description],
				[DimensionTypeID] = ISNULL(DT.DimensionTypeID, 0),
				[GenericYN] = 1,
				[MultipleProcedureYN] = 0,
				[AllYN] = 1,
				[HiddenMember] = ''All'',
				[Hierarchy] = NULL,
				[TranslationYN] = 1,
				[DefaultSelectYN] = 1,
				[DefaultValue] = NULL,
				[DeleteJoinYN] = 0,
				[SourceTypeBM] = 65535,
				[MasterDimensionID] = NULL,
				[HierarchyMasterDimensionID] = NULL,
				[InheritedFrom] = NULL,
				[SeedMemberID] = 1001,
				[ModelingStatusID] = ' + CONVERT(nvarchar(10), @ModelingStatusID) + ',
				[ModelingComment] = ''' + @ModelingComment + ''',
				[Introduced] = ''' + @Version + ''',
				[SelectYN] = 1
			FROM
				' + @ETLDatabase + '.[dbo].[XT_DimensionDefinition] DD
				LEFT JOIN [DimensionType] DT ON DT.InstanceID IN (0, ' + CONVERT(nvarchar(10), @InstanceID) + ') AND DT.[DimensionTypeName] = DD.[Type]
			WHERE
				NOT EXISTS (SELECT 1 FROM [Dimension] D WHERE D.InstanceID IN (0, ' + CONVERT(nvarchar(10), @InstanceID) + ') AND D.[DimensionName] = DD.Label)
			ORDER BY
				DD.Label'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

	SET @Step = 'Copy from Callisto to v2, DataClass_Dimension'
		CREATE TABLE [#DataClass_Dimension]
			(
			[InstanceID] [int] NULL,
			[VersionID] [int] NULL,
			[DataClassID] [int] NULL,
			[DimensionID] [int] NULL,
			[SortOrder] [int] IDENTITY(1010,10) NOT NULL
			)

		SET @SQLStatement = '
			INSERT INTO [#DataClass_Dimension]
				(
				[InstanceID],
				[VersionID],
				[DataClassID],
				[DimensionID]
				)
			SELECT
				[InstanceID] = ' + CONVERT(nvarchar(10), @InstanceID) + ',
				[VersionID] = ' + CONVERT(nvarchar(10), @VersionID) + ',
				[DataClassID] = DC.[DataClassID],
				[DimensionID] = D.[DimensionID]
			FROM
				' + @ETLDatabase + '.[dbo].[XT_ModelDimensions] MD
				INNER JOIN [DataClass] DC ON DC.InstanceID = ' + CONVERT(nvarchar(10), @InstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(10), @VersionID) + ' AND DC.DataClassName = MD.Model
				INNER JOIN [Dimension] D ON D.InstanceID IN (0, ' + CONVERT(nvarchar(10), @InstanceID) + ') AND D.DimensionName = MD.Dimension
			ORDER BY
				DC.[DataClassID],
				CASE WHEN D.DimensionTypeID = -1 THEN 2 ELSE 1 END,
				D.DimensionName'

		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension]
			(
			[InstanceID],
			[VersionID],
			[DataClassID],
			[DimensionID],
			[SortOrder]
			)
		SELECT
			[InstanceID],
			[VersionID],
			[DataClassID],
			[DimensionID],
			[SortOrder]
		FROM
			[#DataClass_Dimension] DCD
		WHERE
			NOT EXISTS (SELECT 1 FROM [DataClass_Dimension] PDCD WHERE PDCD.[InstanceID] = DCD.[InstanceID] AND PDCD.[VersionID] = DCD.[VersionID] AND PDCD.[DataClassID] = DCD.[DataClassID] AND PDCD.[DimensionID] = DCD.[DimensionID])

		DROP TABLE [#DataClass_Dimension]


	SET @Step = 'Copy from Callisto to v2, Dimension_StorageType'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
			(
			[InstanceID],
			[VersionID],
			[DimensionID],
			[StorageTypeBM],
			[ObjectGuiBehaviorBM],
			[ReadSecurityEnabledYN]
			)
		SELECT DISTINCT
			[InstanceID] = DCD.InstanceID,
			[VersionID] = DCD.VersionID,
			[DimensionID] = DCD.DimensionID,
			[StorageTypeBM] = 4,
			[ObjectGuiBehaviorBM] = D.ObjectGuiBehaviorBM,
			[ReadSecurityEnabledYN] = CASE WHEN DCD.DimensionID = -6 THEN 1 ELSE 0 END
		FROM
			[DataClass_Dimension] DCD
			INNER JOIN Dimension D ON D.DimensionID = DCD.DimensionID
		WHERE
			DCD.[InstanceID] = @InstanceID AND
			DCD.[VersionID] = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [Dimension_StorageType] DST WHERE DST.[InstanceID] = DCD.[InstanceID] AND DST.[DimensionID] = DCD.[DimensionID])

	SET @Step = 'Copy from Callisto to v2, DimensionHierarchy'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
			(
			[Comment],
			[InstanceID],
			[DimensionID],
			[HierarchyNo],
			[HierarchyName],
			[FixedLevelsYN],
			[LockedYN]
			)
		SELECT DISTINCT
			[Comment] = D.DimensionName,
			[InstanceID] = @InstanceID,
			[DimensionID] = DCD.[DimensionID],
			[HierarchyNo] = 0,
			[HierarchyName] = D.DimensionName,
			[FixedLevelsYN] = 1,
			[LockedYN] = 0
		FROM
			[DataClass_Dimension] DCD
			INNER JOIN [Dimension] D ON D.DimensionID = DCD.DimensionID AND D.[InstanceID] <> 0
		WHERE
			DCD.[InstanceID] = @InstanceID AND
			DCD.[VersionID] = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [DimensionHierarchy] DH WHERE DH.[InstanceID] = DCD.[InstanceID] AND DH.[DimensionID] = DCD.[DimensionID] AND DH.[HierarchyNo] = 0)

	SET @Step = 'Copy from Callisto to v2, DimensionHierarchyLevel'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
			(
			[Comment],
			[InstanceID],
			[DimensionID],
			[HierarchyNo],
			[LevelNo],
			[LevelName]
			)
		SELECT
			sub.[Comment],
			sub.[InstanceID],
			sub.[DimensionID],
			sub.[HierarchyNo],
			sub.[LevelNo],
			sub.[LevelName]
		FROM
			(
			SELECT DISTINCT
				[Comment] = D.DimensionName,
				[InstanceID] = @InstanceID,
				[DimensionID] = DCD.[DimensionID],
				[HierarchyNo] = 0,
				[LevelNo] = 1,
				[LevelName] = 'TopNode'
			FROM
				[DataClass_Dimension] DCD
				INNER JOIN [Dimension] D ON D.DimensionID = DCD.DimensionID AND D.[InstanceID] <> 0
			WHERE
				DCD.[InstanceID] = @InstanceID AND
				DCD.[VersionID] = @VersionID
			UNION SELECT DISTINCT
				[Comment] = D.DimensionName,
				[InstanceID] = @InstanceID,
				[DimensionID] = DCD.[DimensionID],
				[HierarchyNo] = 0,
				[LevelNo] = 2,
				[LevelName] = REPLACE(D.DimensionName, 'GL_', '')
			FROM
				[DataClass_Dimension] DCD
				INNER JOIN [Dimension] D ON D.DimensionID = DCD.DimensionID AND D.[InstanceID] <> 0
			WHERE
				DCD.[InstanceID] = @InstanceID AND
				DCD.[VersionID] = @VersionID
				) sub
		WHERE
			NOT EXISTS (SELECT 1 FROM [DimensionHierarchyLevel] DHL WHERE DHL.[InstanceID] = sub.[InstanceID] AND DHL.[DimensionID] = sub.[DimensionID] AND DHL.[HierarchyNo] = sub.[HierarchyNo] AND DHL.[LevelNo] = sub.[LevelNo])
		ORDER BY
			sub.[InstanceID],
			sub.[DimensionID],
			sub.[HierarchyNo],
			sub.[LevelNo]

	SET @Step = 'Rerun Journal load and FACT Financials'
		SET @SQLStatement = 'EXEC [spIU_0000_FACT_Financials]'      
		SET @SQLStatement = 'EXEC [' + @ETLDatabase + '].dbo.sp_executesql N''' + @SQLStatement + ''''
		IF @Debug <> 0 PRINT @SQLStatement
		EXEC (@SQLStatement)

		EXEC [spStart_Job_Agent] @ApplicationID = @ApplicationID, @StepName = 'Deploy'            --Step 3800, All the data will now be deployed into the cube.

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
