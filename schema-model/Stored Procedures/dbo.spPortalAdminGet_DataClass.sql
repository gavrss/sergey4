SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[spPortalAdminGet_DataClass]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@ResultTypeBM int = NULL, --1=DataOrigin, 2=DataOrigin Columns, 4=DataClass, 8=Dimension, 16=Property, 32=Measure, 64=Process
	@DataClassID int = NULL, --
	@DimensionID int = NULL,
	@ProcessID int=NULL,
	@DataOriginID int=NULL, --Optional ResultTypeBM =1 & 2
	@PropertyID int= NULL,
	@ShowDeletedYN bit= 0,


	@JobID int = NULL,
	@JobLogID int = NULL,
	@SetJobLogYN bit = 1,
	@AuthenticatedUserID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000923,
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
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'spPortalAdminGet_DataClass',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spPortalAdminGet_DataClass] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [spPortalAdminGet_DataClass] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@Par1 int,
	@Par2 int,

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
	@ModifiedBy nvarchar(50) = 'AlGa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Get meta data for DataClass and other related tables',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.1.2.2199' SET @Description = 'Procedure created.'

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

	SET @Step = '@ResultTypeBM = 1, DataOrigin'
		IF @ResultTypeBM & 1 > 0
			BEGIN

				SELECT 
						[ResultTypeBM] = 1, 
						[InstanceID]
						,[VersionID]
						,[DataOriginID]
						,[DataOriginName]
						,[ConnectionTypeID]
						,[ConnectionName]
						,[SourceID]
						,[StagingPosition]
						,[MasterDataYN]
						,[DataClassID]
						,[DeletedID]
					FROM pcIntegrator_Data.[dbo].[DataOrigin] 
						WHERE InstanceID=@InstanceID
							AND VersionID= @VersionID
							AND ( DataOriginID=@DataOriginID OR @DataOriginID is NULL)
							AND ([DeletedID] IS NULL or @ShowDeletedYN !=0)
							
			END

	SET @Step = '@ResultTypeBM = 2, DataOriginColumn'
		IF @ResultTypeBM & 2 > 0
			BEGIN
				
				SELECT 
					[ResultTypeBM] = 2, 
					DOC.[InstanceID]
					,DOC.[VersionID]
					,DOC.[DataOriginID]
					,DOC.[ColumnName]
					,DOC.[ColumnOrder]
					,DOC.[ColumnTypeID]
					,C.[ColumnTypeName]
					,C.[ColumnTypeValue]
					,DOC.[DestinationName]
					,DOC.[DataType]
					,DOC.[uOM]
					,DOC.[PropertyType]
					,DOC.[HierarchyLevel]
					,DOC.[Comment]
					,DOC.[AutoAddYN]
					,DOC.[DataClassYN]
					,DOC.[DeletedID]
						FROM pcIntegrator_Data.[dbo].[DataOriginColumn] DOC
							INNER JOIN [pcIntegrator]..[ColumnType] C
								ON C.ColumnTypeID = doc.ColumnTypeID
						WHERE InstanceID=@InstanceID
							and VersionID= @VersionID
							AND ( DataOriginID=@DataOriginID OR @DataOriginID is NULL)
							AND ([DeletedID] IS NULL or @ShowDeletedYN !=0)

			END

	SET @Step = '@ResultTypeBM = 4, DataClass'
		IF (@ResultTypeBM & 4 > 0)
			BEGIN
				SELECT
					[ResultTypeBM] = 4, 
					[DataClassID],
					[DataClassName],
					[DataClassDescription],
					[DataClassTypeID],
					--[ModelBM],
					--[StorageTypeBM],
					--[ReadAccessDefaultYN],
					--ActualDataClassID,
					--FullAccountDataClassID,
					--[TabularYN],
					--PrimaryJoin_DimensionID,
					--[TextSupportYN],
					--[ModelingStatusID],
					--[ModelingComment],
					--[InheritedFrom],
					[SelectYN]
					--[Version],
					--[DeletedID]
				FROM
					[pcINTEGRATOR_Data].[dbo].[DataClass] DC
				WHERE
					DC.[InstanceID] = @InstanceID AND
					DC.[VersionID] = @VersionID AND
					(DC.[DeletedID] IS NULL or @ShowDeletedYN !=0)
					AND ( [DataClassID]=@DataClassID OR @DataClassID is NULL)
			END

	SET @Step = '@ResultTypeBM = 8, Dimension'
		IF @ResultTypeBM & 8 > 0
			BEGIN
								
					SELECT
						[ResultTypeBM] = 8
						,D.[InstanceID]
						,D.[DimensionID]
						,D.[DimensionName]
						,D.[DimensionDescription]
						,D.[DimensionTypeID]
						,D.[ObjectGuiBehaviorBM]
						,D.[GenericYN]
						,D.[MultipleProcedureYN]
						,D.[AllYN]
						,D.[ReportOnlyYN]
						,D.[HiddenMember]
						,D.[Hierarchy]
						,D.[TranslationYN]
						,D.[DefaultSelectYN]
						,D.[DefaultSetMemberKey] 
						,D.[DefaultGetMemberKey]
						,D.[DefaultGetHierarchyNo]
						,D.[DefaultValue]
						,D.[DeleteJoinYN]
						,D.[SourceTypeBM]
						,D.[MasterDimensionID]
						,D.[HierarchyMasterDimensionID]
						,D.[InheritedFrom]
						,D.[SeedMemberID]
						,D.[LoadSP]
						,D.[MasterDataManagementBM]
						,D.[ModelingStatusID]
						,D.[ModelingComment]
						,D.[Introduced]
						,D.[SelectYN]
						,D.[DeletedID]
						,D.[Version]
					FROM [pcINTEGRATOR].[dbo].[Dimension] D
						INNER JOIN Dimension_StorageType DST 
							ON  DST.DimensionID = D.DimensionID 
								AND DST.InstanceID = @InstanceID 
									AND DST.VersionID = @VersionID 
						WHERE D.InstanceID IN (0, @InstanceID)
							AND ([DeletedID] IS NULL or @ShowDeletedYN !=0)
							AND	(D.DimensionID = @DimensionID OR @DimensionID IS NULL) 
						ORDER BY [DimensionName]
				
			END

	SET @Step = '@ResultTypeBM = 12, DataClass and Dimension'
		IF (@ResultTypeBM & 4 > 0 AND  @ResultTypeBM & 8 > 0)
			BEGIN
				
				SELECT 
					[ResultTypeBM] = 12, 
					DCD.DataClassID,
					DC.DataClassName,
					DCD.DimensionID,
					D.DimensionName,
					CASE WHEN DOC.ColumnTypeID=4 THEN DOC.PropertyType ELSE NULL END as 'DefaultValue', 
					DCD.SortOrder
					FROM [pcINTEGRATOR].[dbo].[DataClass_Dimension] DCD
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC
							ON DC.DataClassID=DCD.DataClassID
								AND DC.[DeletedID] IS NULL 
								INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D
									ON D.DimensionID= DCD.DimensionID
									AND D.InstanceID in (0, @InstanceID)
									INNER JOIN [pcINTEGRATOR_Data].[dbo].DataOrigin DO
										ON DO.DataClassID = DC.DataClassID
										INNER JOIN [pcINTEGRATOR_Data].[dbo].DataOriginColumn DOC
											ON DOC.DataOriginID = DO.DataOriginID
												AND DOC.DestinationName = D.DimensionName
					WHERE DCD.InstanceID=@InstanceID
						AND DCD.VersionID=@VersionID
						AND DCD.SelectYN!=0
						AND ((DC.[DeletedID] IS NULL OR D.[DeletedID] IS NULL)or @ShowDeletedYN !=0)
						AND	(DCD.DataClassID = @DataClassID OR @DataClassID IS NULL) AND
							(DCD.DimensionID = @DimensionID OR @DimensionID IS NULL) 
					ORDER BY DCD.SortOrder


								--SELECT
				--	[ResultTypeBM] = 8,
				--	DC.DataClassID,
				--	D.DimensionID,
				--	D.DimensionName,
				--	D.DimensionDescription,
				--	D.DimensionTypeID,
				--	DST.StorageTypeBM,
				--	DST.ReadSecurityEnabledYN,
				--	DST.MappingTypeID,
				--	DST.ETLProcedure,
				--	DST.DimensionFilter,
				--	ObjectGuiBehaviorBM = ISNULL(DST.ObjectGuiBehaviorBM, D.ObjectGuiBehaviorBM),
				--	D.MasterDimensionID,
				--	D.HierarchyMasterDimensionID,
				--	--D.GenericYN,
				--	--D.MultipleProcedureYN,
				--	D.AllYN,
				--	D.ReportOnlyYN,
				--	D.HiddenMember,
				--	--D.Hierarchy,
				--	--D.TranslationYN,
				--	DefaultSelectYN,
				--	DefaultSetMemberKey = ISNULL(DST.DefaultSetMemberKey, D.DefaultSetMemberKey),
				--	DefaultGetMemberKey = ISNULL(DST.DefaultGetMemberKey, D.DefaultGetMemberKey),
				--	DefaultGetHierarchyNo = ISNULL(DST.DefaultGetHierarchyNo, D.DefaultGetHierarchyNo),
				--	D.DefaultValue,
				--	--D.DeleteJoinYN,
				--	D.SourceTypeBM,
				--	D.InheritedFrom,
				--	D.SeedMemberID,
				--	D.LoadSP,
				--	--D.MasterDataManagementBM,
				--	D.ModelingStatusID,
				--	D.ModelingComment,
				--	D.Introduced,
				--	D.SelectYN,
				--	--D.DeletedID,
				--	DST.[Version]
				--FROM
				--	[pcINTEGRATOR_Data].[dbo].[DataClass] DC
				--	INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD ON DCD.InstanceID = DC.InstanceID AND DCD.[VersionID] = @VersionID AND DCD.[DataClassID] = DC.[DataClassID]
				--	INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON DCD.InstanceID IN (DC.InstanceID, 0) AND DCD.[VersionID] IN (@VersionID, 0) AND D.[DimensionID] = DCD.[DimensionID]
				--	INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST ON DST.InstanceID = DC.InstanceID AND DST.[VersionID] = DC.[VersionID] AND DST.[DimensionID] = DCD.[DimensionID]
				--WHERE
				--	DC.[InstanceID] = @InstanceID AND
				--	DC.[VersionID] = @VersionID AND
				--	DC.[DataClassID] = @DataClassID AND
				--	D.DeletedID IS NULL
				--ORDER BY
				--	DCD.[SortOrder]



			END

	SET @Step = '@ResultTypeBM = 16, Property'
		IF @ResultTypeBM & 16 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 16
					,[InstanceID]
					,[PropertyID]
					,[PropertyName]
					,[PropertyDescription]
					,[ObjectGuiBehaviorBM]
					,[DataTypeID]
					,[Size]
					,[DependentDimensionID]
					,[StringTypeBM]
					,[DynamicYN]
					,[DefaultValueTable]
					,[DefaultValueView]
					,[SynchronizedYN]
					,[SortOrder]
					,[SourceTypeBM]
					,[StorageTypeBM]
					,[ViewPropertyYN]
					,[HierarchySortOrderYN]
					,[MandatoryYN]
					,[DefaultSelectYN]
					,[Introduced]
					,[SelectYN]
					,[Version]
					,[DefaultNodeTypeBM]
					,[InheritedFrom]
				FROM [pcIntegrator].[dbo].[Property] P 
				WHERE
					P.[InstanceID] IN (@InstanceID, 0) AND
					(P.PropertyID = @PropertyID or @PropertyID  IS NULL) AND 
					[SelectYN]!=0


			END

	SET @Step = '@ResultTypeBM = 24, Property and Dimension'
		IF (@ResultTypeBM & 16 > 0 AND  @ResultTypeBM & 8 > 0)
		--IF (@ResultTypeBM & 16 > 0)
			BEGIN

			CREATE TABLE #Dimension_Property
			(
				PropertyID int,
				PropertyName nvarchar(100) COLLATE DATABASE_DEFAULT,
				PropertyName_Callisto nvarchar(100) COLLATE DATABASE_DEFAULT,
				DisplayName nvarchar(100) COLLATE DATABASE_DEFAULT,
				SortOrder int,
				InstanceID int,
				DataType nvarchar(50),
				GuiObject nvarchar(50),
				NodeTypeBM int,
				DependentDimensionID int,
				DimensionID int,
			)

			INSERT INTO #Dimension_Property
			(
				[PropertyID],
				[PropertyName],
				[DisplayName],
				[NodeTypeBM],
				[SortOrder]
			)
			SELECT PropertyID = 0, PropertyName = 'InstanceID', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 0
			UNION SELECT PropertyID = 0, PropertyName = 'DimensionID', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 0
			UNION SELECT PropertyID = 8, PropertyName = 'MemberID', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 5
			UNION SELECT PropertyID = 5, PropertyName = 'MemberKey', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 10
			UNION SELECT PropertyID = 4, PropertyName = 'MemberDescription', DisplayName = 'Description', [NodeTypeBM] = 1027, [SortOrder] = 20
			UNION SELECT PropertyID = 9, PropertyName = 'HelpText', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 25
			UNION SELECT PropertyID = 12, PropertyName = 'NodeTypeBM', DisplayName = 'NodeType', [NodeTypeBM] = 1027, [SortOrder] = 145
			UNION SELECT PropertyID = 7, PropertyName = 'SBZ', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 150
			UNION SELECT PropertyID = 2, PropertyName = 'Source', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 160
			UNION SELECT PropertyID = 1, PropertyName = 'Synchronized', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 170
			UNION SELECT PropertyID = -204, PropertyName = 'Level', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 175
			UNION SELECT PropertyID = 11, PropertyName = 'SortOrder', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 177
			UNION SELECT PropertyID = 3, PropertyName = 'Parent', DisplayName = NULL, [NodeTypeBM] = 1027, [SortOrder] = 180

			UPDATE DP
			SET
				DataType = DaT.DataTypePortal,
				GuiObject = CASE WHEN P.DependentDimensionID IS NOT NULL THEN 'ComboBox' ELSE DaT.GuiObject END,
				DependentDimensionID = P.DependentDimensionID
			FROM
				#Dimension_Property DP
				INNER JOIN Property P ON P.PropertyID = DP.PropertyID
				INNER JOIN DataType DaT ON DaT.DataTypeID = P.DataTypeID

			UPDATE #Dimension_Property
			SET 
				DimensionID = @DimensionID,
				InstanceID = 0

				
				SELECT
					[ResultTypeBM] = 24,
					DP.[DimensionID],
					D.[DimensionName],
					DP.[PropertyID],
					P.[PropertyName],
					P.PropertyDescription,
					P.DataTypeID,
					P.Size,
					P.DependentDimensionID,
					DP.SortOrder
				FROM
					(
					SELECT
						[DimensionID],
						[PropertyID],
						SortOrder,
						[InstanceID]
					FROM [pcINTEGRATOR].[dbo].[Dimension_Property]
					UNION
					SELECT
						[DimensionID],
						[PropertyID],
						SortOrder,
						[InstanceID]
					FROM #Dimension_Property
					WHERE [PropertyID] <>0
					) DP
					INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.[DimensionID] = DP.[DimensionID]
					INNER JOIN [pcINTEGRATOR].[dbo].[Property] P ON P.InstanceID IN (@InstanceID, 0) AND P.PropertyID = DP.PropertyID
						--LEFT JOIN #Dimension_Property DPT ON DPT.PropertyID = DP.PropertyID
				WHERE
					DP.[InstanceID] IN (@InstanceID, 0) AND
					(D.[DeletedID] IS NULL or @ShowDeletedYN !=0) AND
					(DP.[DimensionID] = @DimensionID OR @DimensionID IS NULL) AND
					(P.PropertyID = @PropertyID or @PropertyID  IS NULL)

				ORDER BY
					DP.SortOrder,
					D.DimensionName

			END

	SET @Step = '@ResultTypeBM = 32, Measure'
		IF @ResultTypeBM & 32 > 0
			BEGIN
				SELECT 
						[ResultTypeBM] = 32 
						,M.[InstanceID]
						,M.[DataClassID]
						,DC.DataClassName
						,M.[MeasureID]
						,M.[VersionID]
						,M.[MeasureName]
						,M.[MeasureDescription]
						,M.[SourceFormula]
						,M.[ExecutionOrder]
						,M.[MeasureParentID]
						,M.[DataTypeID]
						,M.[FormatString]
						,M.[ValidRangeFrom]
						,M.[ValidRangeTo]
						,M.[Unit]
						,M.[AggregationTypeID]
						,M.[TabularYN]
						,M.[DataClassViewBM]
						,M.[TabularFormula]
						,M.[TabularFolder]
						,M.[InheritedFrom]
						,M.[SortOrder]
						,M.[ModelingStatusID]
						,M.[ModelingComment]
						,M.[SelectYN]
						,M.[DeletedID]
						,M.[Version]
				FROM
					[pcINTEGRATOR_Data].[dbo].[Measure] M
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC
							ON DC.DataClassID = M.[DataClassID]
				WHERE
					M.[InstanceID] = @InstanceID AND
					M.[VersionID] = @VersionID AND
					((M.[DeletedID] IS NULL OR DC.[DeletedID] IS NULL)or @ShowDeletedYN !=0)AND
					(M.[DataClassID] =@DataClassID OR @DataClassID IS NULL)

			END

	SET @Step = '@ResultTypeBM = 64, Process'
		IF @ResultTypeBM & 64 > 0
			BEGIN
				SELECT
					[ResultTypeBM] = 64, 
					[ProcessID],
					--[ProcessBM],
					[ProcessName],
					[ProcessDescription],
					--[Destination_DataClassID],
					--[ModelingStatusID],
					--[ModelingComment],
					--[InheritedFrom],
					[SelectYN]
					--[Version]
				FROM
					[pcINTEGRATOR_Data].[dbo].[Process] P
				WHERE
					P.[InstanceID] = @InstanceID AND
					P.[VersionID] = @VersionID AND
					(P.[DeletedID] IS NULL or @ShowDeletedYN !=0) AND
					(P.ProcessID =@ProcessID OR @ProcessID IS NULL)
			END
	
	SET @Step = '@ResultTypeBM = 68, DataClasses and Processes  '
		IF (@ResultTypeBM & 64 > 0 AND  @ResultTypeBM & 4 > 0)
			BEGIN
				
				SELECT [ResultTypeBM] = 68, 
					DCP.DataClassID,
					DC.DataClassName,
					DCP.ProcessID,
					P.ProcessName
					FROM [pcINTEGRATOR].[dbo].[DataClass_Process] DCP
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC
							ON DC.DataClassID = DCP.DataClassID	
								AND DC.[DeletedID] IS NULL 
								INNER JOIN [pcINTEGRATOR_Data].[dbo].[Process] P
									ON P.ProcessID = DCP.ProcessID
						WHERE DCP.[InstanceID] = @InstanceID AND
							DCP.[VersionID] = @VersionID AND
							((DC.[DeletedID] IS NULL OR P.[DeletedID] IS NULL )or @ShowDeletedYN !=0) AND
							(DCP.ProcessID = @ProcessID OR @ProcessID IS NULL) AND
							(DCP.DataClassID = @DataClassID OR @DataClassID IS NULL) 

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
	
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)

GO
