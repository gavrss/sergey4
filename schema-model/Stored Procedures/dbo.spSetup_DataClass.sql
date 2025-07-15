SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_DataClass]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@SourceTypeID int = NULL, --Mandatory
	@StorageTypeBM int = NULL, --Mandatory

	/**
		Pre-requisite for SourceTypeID = 17 (Callisto): Do 'Export Application' from modeler. 
		Export to SQL Database [pcCALLISTO_Export] the following: 1)All Dimensions definitions; 2)All Security Roles; and 3)All Users definitions
	**/

	@ModelingStatusID int = -40,
	@ModelingComment nvarchar(100) = 'Copied from Callisto',
	@ProductOptionID int = NULL, --In combination with SourceTypeID = -20, specific DataClass (Optional) will be setup	
	@TemplateObjectID int = NULL, --In combination with SourceTypeID = -20, required for SalesReport DataClass setup

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000447,
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
	@ProcedureName = 'spSetup_DataClass',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [spSetup_DataClass] @UserID=-10, @InstanceID=413, @VersionID=1008, @SourceTypeID= 17, @Debug=1
EXEC [spSetup_DataClass] @UserID = -1174, @InstanceID = -1001, @VersionID = -1001, @SourceTypeID= 17, @DemoYN = 1, @Debug = 1
EXEC [spSetup_DataClass] @UserID = -10, @InstanceID = -1427, @VersionID = -1365, @SourceTypeID = -20, @StorageTypeBM = 4, @ProductOptionID = 211, @DebugBM = 3

EXEC [spSetup_DataClass] @GetVersion = 1
*/

--SET ANSI_WARNINGS OFF
SET ANSI_WARNINGS ON

DECLARE
	--SP-specific variables
	@SourceInstanceID int = -10,
	@SourceVersionID int = -10,
	@SQLStatement nvarchar(max),	
	@ETLDatabase nvarchar(100),
	@CallistoDatabase nvarchar(100),

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
	@CreatedBy nvarchar(50) = 'NeHa',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup DataClass',
			@MandatoryParameter = 'SourceTypeID|StorageTypeBM' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2149' SET @Description = 'Change INNER JOINs on @Template* tables to LEFT JOINs.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID. Added @SourceTypeID = -10.'
		IF @Version = '2.1.1.2169' SET @Description = 'Handle @SourceTypeID = -20; Added parameter @ProductOptionID.'
		IF @Version = '2.1.1.2170' SET @Description = 'Added INSERT to [MemberSelection] query for @SourceTypeID = -20.'
		IF @Version = '2.1.1.2173' SET @Description = 'Added ObjectTypeBM filter when retrieving [TemplateObjectID] from [dbo].[ProductOption].'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-1710: disable/remove creation of Finance Budget and Finance Forecast Grids. Convert @TemplateObjectID (required for SalesReport DC) from variable to parameter.'

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
			@ETLDatabase = [ETLDatabase],
			@CallistoDatabase = [DestinationDatabase]
		FROM
			[Application]
		WHERE
			[InstanceID] = @InstanceID AND
			[VersionID] = @VersionID

		IF @DebugBM & 2 > 0
			SELECT
				[@ProcedureName] = @ProcedureName,
				[@UserID] = @UserID,
				[@InstanceID] = @InstanceID,
				[@VersionID] = @VersionID,
				[@SourceTypeID] = @SourceTypeID,
				[@StorageTypeBM] = @StorageTypeBM,
				[@ModelingStatusID] = @ModelingStatusID,
				[@ModelingComment] = @ModelingComment,
				[@ETLDatabase] = @ETLDatabase,
				[@CallistoDatabase] = @CallistoDatabase

	SET @Step = 'SourceTypeID = -10, Default setup.'
		IF @SourceTypeID = -10
			BEGIN
				--Process
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
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[ProcessBM] = P.[ProcessBM],
					[ProcessName] = P.[ProcessName],
					[ProcessDescription] = P.[ProcessDescription],
					[ModelingStatusID] = @ModelingStatusID,
					[ModelingComment] = @ModelingComment,
					[InheritedFrom] = P.[ProcessID],
					[SelectYN] = P.[SelectYN]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_Process] P
				WHERE
					P.[InstanceID] = @SourceInstanceID AND
					P.[VersionID] = @SourceVersionID AND
					P.[SelectYN] <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Process] PD WHERE PD.InstanceID = @InstanceID AND PD.VersionID = @VersionID AND PD.[ProcessName] =  P.[ProcessName])

				SET @Inserted = @Inserted + @@ROWCOUNT

				--DataClass
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
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DataClassName] = DC.[DataClassName],
					[DataClassDescription] = DC.[DataClassDescription],
					[DataClassTypeID] = DC.[DataClassTypeID],
					[ModelBM] = DC.[ModelBM],
					[StorageTypeBM] = @StorageTypeBM,
					[ActualDataClassID] = DC.[ActualDataClassID],
					[ModelingStatusID] = @ModelingStatusID,
					[ModelingComment] = @ModelingComment,
					[InheritedFrom] = DC.DataClassID,
					[SelectYN] = DC.[SelectYN]
				FROM
					[@Template_DataClass] DC
				WHERE
					DC.[InstanceID] = @SourceInstanceID AND
					DC.[VersionID] = @SourceVersionID AND
					DC.[SelectYN] <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass] DDC WHERE DDC.InstanceID = @InstanceID AND DDC.VersionID = @VersionID AND DDC.[DataClassName] =DC.[DataClassName])

				SET @Inserted = @Inserted + @@ROWCOUNT

				--DataClass_Process
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Process]
					(
					[InstanceID],
					[VersionID],
					[DataClassID],
					[ProcessID]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DataClassID] = DC.DataClassID,
					[ProcessID] = P.ProcessID
				FROM 
					[pcINTEGRATOR].[dbo].[@Template_DataClass_Process] DCP
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.[InstanceID] = @InstanceID AND DC.[VersionID] = @VersionID AND DC.[InheritedFrom] = DCP.DataClassID
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Process] P ON P.[InstanceID] = @InstanceID AND P.[VersionID] = @VersionID AND P.[InheritedFrom] = DCP.ProcessID
				WHERE
					DCP.[InstanceID] = @SourceInstanceID AND
					DCP.[VersionID] = @SourceVersionID AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Process] DDCP WHERE DDCP.[DataClassID] = DC.DataClassID AND DDCP.[ProcessID] = P.ProcessID )

				SET @Inserted = @Inserted + @@ROWCOUNT

				--Measure
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Measure]
					(
					[InstanceID],
					[VersionID],
					[DataClassID],
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
					[TabularYN],
					[DataClassViewBM],
					[TabularFormula],
					[TabularFolder],
					[InheritedFrom],
					[SortOrder],
					[ModelingStatusID],
					[ModelingComment],
					[SelectYN]
					)
				SELECT DISTINCT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DataClassID] = DC.[DataClassID],
					[MeasureName] = M.[MeasureName],
					[MeasureDescription] = M.[MeasureDescription],
					[SourceFormula] = M.[SourceFormula],
					[ExecutionOrder] = M.[ExecutionOrder],
					[MeasureParentID] = M.[MeasureParentID],
					[DataTypeID] = M.[DataTypeID],
					[FormatString] = M.[FormatString],
					[ValidRangeFrom] = M.[ValidRangeFrom],
					[ValidRangeTo] = M.[ValidRangeTo],
					[Unit] = M.[Unit],
					[AggregationTypeID] = M.[AggregationTypeID],
					[TabularYN] = M.[TabularYN],
					[DataClassViewBM] = M.[DataClassViewBM],
					[TabularFormula] = M.[TabularFormula],
					[TabularFolder] = M.[TabularFolder],
					[InheritedFrom] = M.[MeasureID],
					[SortOrder] = M.[SortOrder],
					[ModelingStatusID] = @ModelingStatusID,
					[ModelingComment] = @ModelingComment,
					[SelectYN] = M.[SelectYN]
				FROM 
					[pcINTEGRATOR].[dbo].[@Template_Measure] M
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.[InstanceID] = @InstanceID AND DC.[VersionID] = @VersionID AND DC.[InheritedFrom] = M.DataClassID 
				WHERE
					M.InstanceID = @SourceInstanceID AND 
					M.VersionID = @SourceVersionID AND
					M.SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Measure] DM WHERE DM.[InstanceID] = @InstanceID AND DM.[VersionID] = @VersionID AND DM.[DataClassID] = DC.[DataClassID] AND DM.[MeasureName] = M.[MeasureName])

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'SourceTypeID = -20, Optional setup.'
		IF @SourceTypeID = -20 AND @ProductOptionID IS NOT NULL
			BEGIN
				SELECT 
					@SourceInstanceID = -20, 
					@SourceVersionID = -20,
					@ModelingComment = 'Optional setup',
					@TemplateObjectID = ISNULL(@TemplateObjectID, TemplateObjectID)
				FROM 
					[pcINTEGRATOR].[dbo].[ProductOption]
				WHERE 
					ProductOptionID = @ProductOptionID AND
					ObjectTypeBM & 1 > 0

				IF @DebugBM & 2 > 0 SELECT [@SourceInstanceID] = @SourceInstanceID, [@SourceVersionID] = @SourceVersionID, [@TemplateObjectID] = @TemplateObjectID, [@ModelingComment] = @ModelingComment

				--Process
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
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[ProcessBM] = P.[ProcessBM],
					[ProcessName] = P.[ProcessName],
					[ProcessDescription] = P.[ProcessDescription],
					[ModelingStatusID] = @ModelingStatusID,
					[ModelingComment] = @ModelingComment,
					[InheritedFrom] = P.[ProcessID],
					[SelectYN] = P.[SelectYN]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_Process] P
				WHERE
					P.[InstanceID] = @SourceInstanceID AND
					P.[VersionID] = @SourceVersionID AND
					P.[ProcessID] = @TemplateObjectID AND
					P.[SelectYN] <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Process] PD WHERE PD.InstanceID = @InstanceID AND PD.VersionID = @VersionID AND PD.[ProcessName] =  P.[ProcessName])

				SET @Inserted = @Inserted + @@ROWCOUNT

				--DataClass
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
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DataClassName] = DC.[DataClassName],
					[DataClassDescription] = DC.[DataClassDescription],
					[DataClassTypeID] = DC.[DataClassTypeID],
					[ModelBM] = DC.[ModelBM],
					[StorageTypeBM] = @StorageTypeBM,
					[ActualDataClassID] = DC.[ActualDataClassID],
					[ModelingStatusID] = @ModelingStatusID,
					[ModelingComment] = @ModelingComment,
					[InheritedFrom] = DC.DataClassID,
					[SelectYN] = DC.[SelectYN]
				FROM
					[@Template_DataClass] DC
				WHERE
					DC.[InstanceID] = @SourceInstanceID AND
					DC.[VersionID] = @SourceVersionID AND
					DC.[DataClassID] = @TemplateObjectID AND
					DC.[SelectYN] <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass] DDC WHERE DDC.InstanceID = @InstanceID AND DDC.VersionID = @VersionID AND DDC.[DataClassName] =DC.[DataClassName])

				SET @Inserted = @Inserted + @@ROWCOUNT

				--DataClass_Process
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Process]
					(
					[InstanceID],
					[VersionID],
					[DataClassID],
					[ProcessID]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DataClassID] = DC.DataClassID,
					[ProcessID] = P.ProcessID
				FROM 
					[pcINTEGRATOR].[dbo].[@Template_DataClass_Process] DCP
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.[InstanceID] = @InstanceID AND DC.[VersionID] = @VersionID AND DC.[InheritedFrom] = DCP.DataClassID
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Process] P ON P.[InstanceID] = @InstanceID AND P.[VersionID] = @VersionID AND P.[InheritedFrom] = DCP.ProcessID
				WHERE
					DCP.[InstanceID] = @SourceInstanceID AND
					DCP.[VersionID] = @SourceVersionID AND
					DCP.[DataClassID] = @TemplateObjectID AND
					--DCP.[ProcessID] = @TemplateObjectID AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Process] DDCP WHERE DDCP.[DataClassID] = DC.DataClassID AND DDCP.[ProcessID] = P.ProcessID )

				SET @Inserted = @Inserted + @@ROWCOUNT

				--Measure
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Measure]
					(
					[InstanceID],
					[VersionID],
					[DataClassID],
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
					[TabularYN],
					[DataClassViewBM],
					[TabularFormula],
					[TabularFolder],
					[InheritedFrom],
					[SortOrder],
					[ModelingStatusID],
					[ModelingComment],
					[SelectYN]
					)
				SELECT DISTINCT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DataClassID] = DC.[DataClassID],
					[MeasureName] = M.[MeasureName],
					[MeasureDescription] = M.[MeasureDescription],
					[SourceFormula] = M.[SourceFormula],
					[ExecutionOrder] = M.[ExecutionOrder],
					[MeasureParentID] = M.[MeasureParentID],
					[DataTypeID] = M.[DataTypeID],
					[FormatString] = M.[FormatString],
					[ValidRangeFrom] = M.[ValidRangeFrom],
					[ValidRangeTo] = M.[ValidRangeTo],
					[Unit] = M.[Unit],
					[AggregationTypeID] = M.[AggregationTypeID],
					[TabularYN] = M.[TabularYN],
					[DataClassViewBM] = M.[DataClassViewBM],
					[TabularFormula] = M.[TabularFormula],
					[TabularFolder] = M.[TabularFolder],
					[InheritedFrom] = M.[MeasureID],
					[SortOrder] = M.[SortOrder],
					[ModelingStatusID] = @ModelingStatusID,
					[ModelingComment] = @ModelingComment,
					[SelectYN] = M.[SelectYN]
				FROM 
					[pcINTEGRATOR].[dbo].[@Template_Measure] M
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.[InstanceID] = @InstanceID AND DC.[VersionID] = @VersionID AND DC.[InheritedFrom] = M.DataClassID 
				WHERE
					M.InstanceID = @SourceInstanceID AND 
					M.VersionID = @SourceVersionID AND
					M.DataClassID = @TemplateObjectID AND
					M.SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Measure] DM WHERE DM.[InstanceID] = @InstanceID AND DM.[VersionID] = @VersionID AND DM.[DataClassID] = DC.[DataClassID] AND DM.[MeasureName] = M.[MeasureName])

				SET @Inserted = @Inserted + @@ROWCOUNT

				--MemberSelection
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[MemberSelection]
					(
					[InstanceID],
					[VersionID],
					[DataClassID],
					[DimensionID],
					[Label],
					[SequenceBM],
					[SelectYN]
					)
				SELECT 
					[InstanceID] = DC.InstanceID,
					[VersionID] = DC.VersionID,
					[DataClassID] = DC.DataClassID,
					[DimensionID] = MS.DimensionID,
					[Label] = MS.[Label],
					[SequenceBM] = MS.SequenceBM,
					[SelectYN] = MS.SelectYN
				 FROM 
					[pcINTEGRATOR].[dbo].[@Template_MemberSelection] MS
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.[InstanceID] = @InstanceID AND DC.[VersionID] = @VersionID AND DC.[InheritedFrom] = MS.DataClassID 
				 WHERE 
					MS.InstanceID = @SourceInstanceID AND 
					MS.VersionID = @SourceVersionID AND 
					MS.DataClassID = @TemplateObjectID AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[MemberSelection] M WHERE M.InstanceID = @InstanceID AND M.VersionID = @VersionID AND M.DataClassID = DC.DataClassID AND M.DimensionID = MS.DimensionID AND M.[Label] = MS.[Label])
  
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'SourceTypeID = 16, pcETL'
		IF @SourceTypeID = 16 --pcETL
			BEGIN
				--Process
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
						INNER JOIN Process P ON P.InstanceID = ' + CONVERT(nvarchar(15), @SourceInstanceID) + ' AND P.VersionID = ' + CONVERT(nvarchar(15), @SourceVersionID) + ' AND P.[ProcessName] = MD.Label
					WHERE
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Process] PD WHERE PD.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND PD.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND PD.[ProcessName] = MD.Label)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT

				--DataClass
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
						[GetProc],
						[SetProc],
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
						[GetProc] = NULL,
						[SetProc] = NULL,
						[ActualDataClassID] = NULL,
						[ModelingStatusID] = ' + CONVERT(nvarchar(10), @ModelingStatusID) + ',
						[ModelingComment] = ''' + @ModelingComment + ''',
						[InheritedFrom] = DC.DataClassID,
						[SelectYN] = 1
					FROM
						' + @ETLDatabase + '.[dbo].[XT_ModelDefinition] MD
						INNER JOIN [DataClass] DC ON DC.InstanceID = ' + CONVERT(nvarchar(15), @SourceInstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(15), @SourceVersionID) + ' AND DC.[DataClassName] = MD.Label
						LEFT JOIN [Model] M ON M.ModelID BETWEEN -1000 AND -1 AND M.ModelName = MD.Label
					WHERE
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass] DC WHERE DC.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND DC.[DataClassName] = MD.Label)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT	
			END

	SET @Step = 'SourceTypeID = 17, Callisto'
		IF @SourceTypeID = 17 --Callisto
			BEGIN
				--Process
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
					SELECT DISTINCT 
						[InstanceID] = ' + CONVERT(nvarchar(15),@InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15),@VersionID) + ',
						[ProcessBM] = 0,
						[ProcessName] = M.Label,
						[ProcessDescription] = M.Description,
						[ModelingStatusID] = ' + CONVERT(nvarchar(15), @ModelingStatusID) + ',
						[ModelingComment] = ''' + @ModelingComment + ''',
						[InheritedFrom] = TP.ProcessID,
						[SelectYN] = 1
					FROM 
						' + @CallistoDatabase + '.[dbo].[Models] M
						LEFT JOIN [pcINTEGRATOR].[dbo].[@Template_Process] TP ON TP.InstanceID = ' + CONVERT(nvarchar(15), @SourceInstanceID) + ' AND TP.[ProcessName] = M.Label
					WHERE 
						M.Label <> ''Financials_Detail'' AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Process] P WHERE P.InstanceID = ' + CONVERT(nvarchar(15),@InstanceID) + ' AND P.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND P.ProcessName = M.Label)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
	
				--DataClass
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
						[ReadAccessDefaultYN],
						[ActualDataClassID],
						[ModelingStatusID],
						[ModelingComment],
						[InheritedFrom],
						[SelectYN]
						)
					SELECT DISTINCT
						[InstanceID] = ' + CONVERT(nvarchar(15),@InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15),@VersionID) + ',				
						[DataClassName] = M.Label,
						[DataClassDescription] = M.Description,
						[DataClassTypeID] = -1,
						[ModelBM] = ISNULL(TM.ModelBM,0),
						[StorageTypeBM] = 4,
						[ReadAccessDefaultYN] = 1,
						[ActualDataClassID] = NULL,
						[ModelingStatusID] = ' + CONVERT(nvarchar(15), @ModelingStatusID) + ',
						[ModelingComment] = ''' + @ModelingComment + ''',
						[InheritedFrom] = DC.DataClassID,
						[SelectYN] = 1
					FROM 
						' + @CallistoDatabase + '.[dbo].[Models] M
						LEFT JOIN [pcINTEGRATOR].[dbo].[@Template_DataClass] DC ON DC.InstanceID = ' + CONVERT(nvarchar(15), @SourceInstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(15), @SourceVersionID) + ' AND DC.[DataClassName] = M.Label
						LEFT JOIN [pcINTEGRATOR].[dbo].[@Template_Model] TM ON TM.ModelName = M.Label
					WHERE
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass] DC WHERE DC.InstanceID = ' + CONVERT(nvarchar(15),@InstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(15),@VersionID) + ' AND DC.DataClassName = M.Label)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Insert DataClass_Process to pcINTEGRATOR_Data, if not existing.'
		IF @SourceTypeID IN (16, 17)
			BEGIN
				--DataClass_Process
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Process]
					(
					[InstanceID],
					[VersionID],
					[DataClassID],
					[ProcessID]
					)
				SELECT 
					[InstanceID] = DC.InstanceID,
					[VersionID] = DC.VersionID,
					[DataClassID] = DC.DataClassID,
					[ProcessID] = P.ProcessID
				FROM 
					[pcINTEGRATOR].[dbo].[DataClass] DC
					INNER JOIN [pcINTEGRATOR].[dbo].[Process] P ON P.InstanceID = DC.InstanceID AND P.VersionID = DC.VersionID AND DC.DataClassName LIKE P.ProcessName + '%'
				WHERE
					DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND
					NOT EXISTS (SELECT 1 FROM DataClass_Process DCP WHERE DCP.[InstanceID] = DC.InstanceID AND DCP.[VersionID] = DC.VersionID AND DCP.[DataClassID] = DC.DataClassID AND DCP.[ProcessID] = P.ProcessID )
				
				SET @Inserted = @Inserted + @@ROWCOUNT

				--Measure
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
				SELECT DISTINCT
					[InstanceID] = DC.[InstanceID],
					[DataClassID] = DC.[DataClassID],
					[VersionID] = DC.[VersionID],
					[MeasureName] = DC.[DataClassName],
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
					[pcINTEGRATOR].[dbo].[DataClass] DC 
				WHERE
					DC.InstanceID = @InstanceID AND 
					DC.VersionID = @VersionID AND
					NOT EXISTS (SELECT 1 FROM Measure M WHERE M.InstanceID = DC.InstanceID AND M.VersionID = DC.VersionID AND M.DataClassID = DC.DataClassID AND M.MeasureName = DC.DataClassName)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END
/*
	SET @Step = 'Insert into Grid'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Grid]
			(
			[InstanceID],
			[VersionID],
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
			[VersionID] = @VersionID,
			[GridName] = G.[GridName],
			[GridDescription] = G.[GridDescription],
			[DataClassID] = DC.DataClassID,
			[GridSkinID] = G.[GridSkinID],
			[GetProc] = G.[GetProc],
			[SetProc] = G.[SetProc],
			[InheritedFrom] = G.[GridID]
		FROM
			[pcINTEGRATOR].[dbo].[@Template_Grid] G
			INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND DC.InheritedFrom = G.DataClassID 
		WHERE
			G.InstanceID = @SourceInstanceID AND
			G.[VersionID] = @SourceVersionID AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Grid] DG WHERE DG.InstanceID = @InstanceID AND DG.[VersionID] = @VersionID AND DG.GridName = G.GridName)

		SELECT @Inserted = @Inserted + @@ROWCOUNT
*/
	SET @Step = 'Return information'
		IF @DebugBM & 1 > 0 
			BEGIN
				SELECT [Table] = 'pcINTEGRATOR_Data..Process', * FROM [pcINTEGRATOR_Data].[dbo].[Process] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
				SELECT [Table] = 'pcINTEGRATOR_Data..DataClass', * FROM [pcINTEGRATOR_Data].[dbo].[DataClass] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
				SELECT [Table] = 'pcINTEGRATOR_Data..DataClass_Process', * FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Process] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
				SELECT [Table] = 'pcINTEGRATOR_Data..Measure', * FROM [pcINTEGRATOR_Data].[dbo].[Measure] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
				SELECT [Table] = 'pcINTEGRATOR_Data..Grid', * FROM [pcINTEGRATOR_Data].[dbo].[Grid] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
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
