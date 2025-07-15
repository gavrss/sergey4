SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spSetup_Dimension]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

/***
	NOTE: Pre-requisite for SourceTypeID = 17 (Callisto): 
	- Do 'Export Application' from Callisto Modeler.
	- Export to SQL Database [pcCALLISTO_Export] the following: 1)All Dimensions definitions; 2)All Security Roles; and 3)All Users definitions
***/
	@SourceTypeID int = NULL, --Mandatory
	@StorageTypeBM int = 4, 
	@ModelingStatusID int = -40,
	@ModelingComment nvarchar(100) = 'Copied from Callisto',
	@DimensionID int = NULL, --In combination with SourceTypeID = -10, specific Dimension will be setup
	@DimensionName nvarchar(50) = NULL,
	@ProductOptionID int = NULL, --In combination with SourceTypeID = -20, default Dimensions of a specific DataClass (Optional) will be setup
	@TemplateObjectID INT = NULL, --In combination with SourceTypeID = -20, required for SalesReport DataClass setup

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000449,
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
EXEC [spSetup_Dimension] @UserID=-10, @InstanceID=52, @VersionID=1035, @SourceTypeID = -10, @Debug=1
EXEC [spSetup_Dimension] @UserID=-10, @InstanceID=571, @VersionID=1079, @SourceTypeID = -11, @Debug=1
EXEC [spSetup_Dimension] @UserID = -1174, @InstanceID = -1001, @VersionID = -1001, @Debug = 1
EXEC [spSetup_Dimension] @UserID = -10, @InstanceID = 529, @VersionID = 1001, @SourceTypeID = -10, @DimensionID = -10, @DebugBM = 3
EXEC [spSetup_Dimension] @UserID = -10, @InstanceID = -1427, @VersionID = -1365, @SourceTypeID = -20, @StorageTypeBM = 4, @ProductOptionID = 211, @DebugBM = 3

EXEC [spSetup_Dimension] @GetVersion = 1
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
	@MaxID int,

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
	@ModifiedBy nvarchar(50) = 'HaLa',
	@Version nvarchar(50) = '2.1.2.2199'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Setup Dimension',
			@MandatoryParameter = 'SourceTypeID' --Without @, separated by |

		IF @Version = '2.0.2.2146' SET @Description = 'Procedure created.'
		IF @Version = '2.0.2.2149' SET @Description = 'Added mandatory parameter @SourceTypeID. Added @SourceTemplateYN.'
		IF @Version = '2.0.3.2151' SET @Description = 'By default, not add Instance-specific Dimension Hierarchies.'
		IF @Version = '2.0.3.2154' SET @Description = 'DB-423: Remove GUID. DB-427: Adding VersionID to tables DimensionHierarchy, DimensionHierarchyLevel & Dimension_Property. Added @SourceTypeID = -10.'
		IF @Version = '2.1.0.2165' SET @Description = 'Handle optional specific dimensions in combination with @SourceTypeID = -10.'
		IF @Version = '2.1.1.2168' SET @Description = 'Enhanced handling of DimensionName for SourceTypeID = -11.'
		IF @Version = '2.1.1.2169' SET @Description = 'Changed NOT EXISTS handling for [Grid_Dimension] to match the PrimaryKey. Filter on Dimension_Property.SelectYN <> 0. Handle @SourceTypeID = -20; Added parameter @ProductOptionID.'
		IF @Version = '2.1.1.2173' SET @Description = 'Added ObjectTypeBM filter when retrieving [TemplateObjectID] from [dbo].[ProductOption].'
		IF @Version = '2.1.1.2180' SET @Description = 'Do not include deleted Dimensions for Financial Segments setup.'
		IF @Version = '2.1.2.2198' SET @Description = 'DB-1581: Added [ETLProcedure] column when inserting into [Dimension_StorageType] table.'
		IF @Version = '2.1.2.2199' SET @Description = 'FDB-2906: Updates [DimensionID] column when value is NULL in [Journal_SegmentNo] table. Convert @TemplateObjectID (required for SalesReport DC) from variable to parameter.'

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
				[@ProductOptionID] = @ProductOptionID,
				[@StorageTypeBM] = @StorageTypeBM,
				[@ModelingStatusID] = @ModelingStatusID,
				[@ModelingComment] = @ModelingComment,
				[@ETLDatabase] = @ETLDatabase,
				[@CallistoDatabase] = @CallistoDatabase,
				[@JobID] = @JobID

	SET @Step = 'Create temp table #Property.'
		CREATE TABLE [dbo].#Property
			(
			[InstanceID] [int],
			[PropertyName] [nvarchar](50),
			[PropertyDescription] [nvarchar](255),
			[ObjectGuiBehaviorBM] [int],
			[DataTypeID] [int],
			[Size] [int],
			[DependentDimensionID] [int],
			[StringTypeBM] [int],
			[DynamicYN] [bit],
			[DefaultValueTable] [nvarchar](255),
			[DefaultValueView] [nvarchar](255),
			[SynchronizedYN] [bit],
			[SortOrder] [int],
			[SourceTypeBM] [int],
			[StorageTypeBM] [int],
			[ViewPropertyYN] [bit],
			[HierarchySortOrderYN] [bit],
			[MandatoryYN] [bit],
			[DefaultSelectYN] [bit],
			[Introduced] [nvarchar](100),
			[SelectYN] [bit],
			[Version] [nvarchar](100)
			)

	SET @Step = 'SourceTypeID = -11, Financial segment setup.'
		IF @SourceTypeID = -11
			BEGIN
				--Dimension
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension]
					(
					[InstanceID],
					[DimensionName],
					[DimensionDescription],
					[DimensionTypeID],
					[ObjectGuiBehaviorBM],
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
					[LoadSP],
					[ModelingStatusID],
					[ModelingComment],
					[Introduced],
					[SelectYN]
					)
				SELECT DISTINCT
					[InstanceID] = @InstanceID,
					[DimensionName] = 'GL_' + REPLACE(REPLACE(JSN.[SegmentName], ' ', ''), 'GL_', ''),
					[DimensionDescription] = 'GL_' + REPLACE(REPLACE(JSN.[SegmentName], ' ', ''), 'GL_', ''),
					[DimensionTypeID] = -1,
					[ObjectGuiBehaviorBM] = 1,
					[GenericYN] = 1,
					[MultipleProcedureYN] = 0,
					[AllYN] = 1,
					[HiddenMember] = 'All',
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
					[LoadSP] = 'Segment',
					[ModelingStatusID] = @ModelingStatusID,
					[ModelingComment] = @ModelingComment,
					[Introduced] = @Version,
					[SelectYN] = 1
				FROM
					[pcINTEGRATOR_Data].[dbo].[Entity] E
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Entity_Book] EB ON EB.EntityID = E.EntityID AND EB.SelectYN <> 0
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN ON JSN.EntityID = EB.EntityID AND JSN.Book = EB.Book AND JSN.DimensionID IS NULL AND JSN.SelectYN <> 0
				WHERE
					E.InstanceID = @InstanceID AND
					E.VersionID = @VersionID AND
					E.SelectYN <> 0 AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension] D WHERE D.InstanceID = @InstanceID AND D.[DimensionName] = JSN.SegmentName AND D.DeletedID IS NULL)
				ORDER BY
					'GL_' + REPLACE(REPLACE(JSN.[SegmentName], ' ', ''), 'GL_', '')

				SET @Inserted = @Inserted + @@ROWCOUNT
				IF @DebugBM & 2 > 0 SELECT [Status]  = 'Done Inserting'

				--Set DimensionID in Journal_SegmentNo
				UPDATE JSN
				SET
					DimensionID = D.DimensionID
				FROM
					[pcINTEGRATOR_Data].[dbo].[Journal_SegmentNo] JSN
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Dimension] D ON D.InstanceID = JSN.InstanceID AND D.[DimensionName] = 'GL_' + REPLACE(REPLACE(JSN.[SegmentName], ' ', ''), 'GL_', '') AND D.DeletedID IS NULL
				WHERE
					JSN.InstanceID = @InstanceID AND
					JSN.VersionID = @VersionID

				SET @Updated = @Updated + @@ROWCOUNT

				--Dimension_StorageType
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
					(
					[InstanceID],
					[VersionID],
					[DimensionID],
					[StorageTypeBM],
					[ObjectGuiBehaviorBM],
					[ReadSecurityEnabledYN],
					[MappingTypeID],
					[ETLProcedure]
					)
				SELECT DISTINCT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DimensionID] = D.DimensionID,
					[StorageTypeBM] = @StorageTypeBM,
					[ObjectGuiBehaviorBM] = D.ObjectGuiBehaviorBM,
					[ReadSecurityEnabledYN] = 0,
					[MappingTypeID] = 0,
					[ETLProcedure] = 'spIU_Dim_' + TD.[LoadSP] + '_Callisto'
				FROM
					[pcINTEGRATOR_Data].[dbo].[Dimension] D
					INNER JOIN [pcINTEGRATOR].[dbo].[@Template_Dimension] TD ON TD.DimensionTypeID=D.DimensionTypeID AND TD.DimensionID = 0
				WHERE
					D.[InstanceID] = @InstanceID AND
					D.[DimensionTypeID] = -1 AND
					D.[DeletedID] IS NULL AND 
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DDST WHERE DDST.[InstanceID] = @InstanceID AND DDST.[VersionID] = @VersionID AND DDST.[DimensionID] = D.[DimensionID])

				SET @Inserted = @Inserted + @@ROWCOUNT

				--DataClass_Dimension
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension]
					(
					[InstanceID],
					[VersionID],
					[DataClassID],
					[DimensionID],
					[ChangeableYN],
					[Conversion_MemberKey],
					[TabularYN],
					[DataClassViewBM],
					[FilterLevel],
					[SortOrder]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DataClassID] = DC.[DataClassID],
					[DimensionID] = D.[DimensionID],
					[ChangeableYN] = 0,
					[Conversion_MemberKey] = NULL,
					[TabularYN] = 1,
					[DataClassViewBM] = 1,
					[FilterLevel] = 'L',
					[SortOrder] = 1500
				FROM
					[pcINTEGRATOR_Data].[dbo].[Dimension] D
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND DC.DataClassTypeID = -1 AND DC.ModelBM & 64 > 0
				WHERE
					D.[InstanceID] = @InstanceID AND
					D.[DimensionTypeID] = -1 AND
					D.[DeletedID] IS NULL AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DDCD WHERE DDCD.InstanceID = @InstanceID AND DDCD.VersionID = @VersionID AND DDCD.DataClassID = DC.DataClassID AND DDCD.DimensionID = D.DimensionID)

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'SourceTypeID = -10, Default setup.'
		IF @SourceTypeID = -10
			BEGIN
				IF @DimensionID IS NOT NULL
					BEGIN
						SELECT
							@SourceInstanceID = -20,
							@SourceVersionID = -20
					END

				--Dimension_StorageType
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
					(
					[InstanceID],
					[VersionID],
					[DimensionID],
					[StorageTypeBM],
					[ObjectGuiBehaviorBM],
					[ReadSecurityEnabledYN],
					[MappingTypeID],
					[ETLProcedure]
					)
				SELECT DISTINCT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DimensionID],
					[StorageTypeBM] = @StorageTypeBM,
					[ObjectGuiBehaviorBM],
					[ReadSecurityEnabledYN],
					[MappingTypeID],
					[ETLProcedure] = DST.ETLProcedure
				FROM
					[pcINTEGRATOR].[dbo].[@Template_Dimension_StorageType] DST
				WHERE
					DST.[InstanceID] = @SourceInstanceID AND
					DST.[VersionID] = @SourceVersionID AND
					(DST. DimensionID = @DimensionID OR @DimensionID IS NULL) AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DDST WHERE DDST.[InstanceID] = @InstanceID AND DDST.[VersionID] = @VersionID AND DDST.[DimensionID] = DST.[DimensionID])

				SET @Inserted = @Inserted + @@ROWCOUNT

				--Dimension_StorageType, dependencies
				WHILE 
					(
					SELECT 
						COUNT(DISTINCT P.[DependentDimensionID])
					FROM
						[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
						INNER JOIN Dimension_Property DP ON DP.[InstanceID] IN (0, DST.[InstanceID]) AND DP.[VersionID] IN (0, DST.[VersionID]) AND DP.[DimensionID] = DST.[DimensionID]
						INNER JOIN Property P ON P.[InstanceID] IN (0, DST.[InstanceID]) AND P.[PropertyID] = DP.[PropertyID] AND P.[DependentDimensionID] IS NOT NULL
						INNER JOIN Dimension D ON D.[InstanceID] IN (0, DST.[InstanceID]) AND D.[DimensionID] = P.[DependentDimensionID]
 					WHERE
						DST.[InstanceID] = @InstanceID AND
						DST.[VersionID] = @VersionID AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DDST WHERE DDST.[InstanceID] = DST.[InstanceID] AND DDST.[VersionID] = DST.[VersionID] AND DDST.[DimensionID] = P.[DependentDimensionID])
					) > 0
					BEGIN
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
							(
							[InstanceID],
							[VersionID],
							[DimensionID],
							[StorageTypeBM],
							[ObjectGuiBehaviorBM],
							[ReadSecurityEnabledYN],
							[MappingTypeID]
							)
						SELECT DISTINCT
							[InstanceID] = DST.[InstanceID],
							[VersionID] = DST.[VersionID],
							[DimensionID] = P.[DependentDimensionID],
							[StorageTypeBM] = @StorageTypeBM,
							[ObjectGuiBehaviorBM] = D.[ObjectGuiBehaviorBM],
							[ReadSecurityEnabledYN] = 0,
							[MappingTypeID] = 0
						FROM
							[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
							INNER JOIN Dimension_Property DP ON DP.[InstanceID] IN (0, DST.[InstanceID]) AND DP.[VersionID] IN (0, DST.[VersionID]) AND DP.[DimensionID] = DST.[DimensionID] AND DP.[SelectYN] <> 0
							INNER JOIN Property P ON P.[InstanceID] IN (0, DST.[InstanceID]) AND P.[PropertyID] = DP.[PropertyID] AND P.[DependentDimensionID] IS NOT NULL
							INNER JOIN Dimension D ON D.[InstanceID] IN (0, DST.[InstanceID]) AND D.[DimensionID] = P.[DependentDimensionID]
 						WHERE
							DST.[InstanceID] = @InstanceID AND
							DST.[VersionID] = @VersionID AND
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DDST WHERE DDST.[InstanceID] = DST.[InstanceID] AND DDST.[VersionID] = DST.[VersionID] AND DDST.[DimensionID] = P.[DependentDimensionID])

						SET @Inserted = @Inserted + @@ROWCOUNT
					END

				--DataClass_Dimension
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension]
					(
					[InstanceID],
					[VersionID],
					[DataClassID],
					[DimensionID],
					[ChangeableYN],
					[Conversion_MemberKey],
					[TabularYN],
					[DataClassViewBM],
					[FilterLevel],
					[SortOrder]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DataClassID] = DC.[DataClassID],
					[DimensionID] = DCD.[DimensionID],
					[ChangeableYN] = DCD.[ChangeableYN],
					[Conversion_MemberKey] = DCD.[Conversion_MemberKey],
					[TabularYN] = DCD.[TabularYN],
					[DataClassViewBM] = DCD.[DataClassViewBM],
					[FilterLevel] = DCD.[FilterLevel],
					[SortOrder] = DCD.[SortOrder]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_DataClass_Dimension] DCD
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND DC.InheritedFrom = DCD.DataClassID
				WHERE
					DCD.[InstanceID] = @SourceInstanceID AND
					DCD.[VersionID] = @SourceVersionID AND
					(DCD. DimensionID = @DimensionID OR @DimensionID IS NULL) AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DDCD WHERE DDCD.InstanceID = @InstanceID AND DDCD.VersionID = @VersionID AND DDCD.DataClassID = DC.DataClassID AND DDCD.DimensionID = DCD.DimensionID)

				SET @Inserted = @Inserted + @@ROWCOUNT

				--Grid_Dimension
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Grid_Dimension]
					(
					[InstanceID],
					[VersionID],
					[GridID],
					[DimensionID],
					[GridAxisID]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[GridID] = G.[GridID],
					[DimensionID] = GD.[DimensionID],
					[GridAxisID] = GD.[GridAxisID]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_Grid_Dimension] GD
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Grid] G ON G.[InstanceID] = @InstanceID AND G.[VersionID] = @VersionID AND G.[InheritedFrom] = GD.[GridID]
				WHERE
					GD.[InstanceID] = @SourceInstanceID AND
					GD.[VersionID] = @SourceVersionID AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Grid_Dimension] DGD WHERE DGD.[GridID] = G.[GridID] AND DGD.[DimensionID] = GD.[DimensionID] AND DGD.[GridAxisID] = GD.[GridAxisID])

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

				--DataClass_Dimension (add default dimensions of an optional DataClass)
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension]
					(
					[InstanceID],
					[VersionID],
					[DataClassID],
					[DimensionID],
					[ChangeableYN],
					[Conversion_MemberKey],
					[TabularYN],
					[DataClassViewBM],
					[FilterLevel],
					[SortOrder]
					)
				SELECT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DataClassID] = DC.[DataClassID],
					[DimensionID] = DCD.[DimensionID],
					[ChangeableYN] = DCD.[ChangeableYN],
					[Conversion_MemberKey] = DCD.[Conversion_MemberKey],
					[TabularYN] = DCD.[TabularYN],
					[DataClassViewBM] = DCD.[DataClassViewBM],
					[FilterLevel] = DCD.[FilterLevel],
					[SortOrder] = DCD.[SortOrder]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_DataClass_Dimension] DCD
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.InstanceID = @InstanceID AND DC.VersionID = @VersionID AND DC.InheritedFrom = DCD.DataClassID
				WHERE
					DCD.[InstanceID] = -10 AND
					DCD.[VersionID] = -10 AND
					DCD.[DataClassID] = @TemplateObjectID AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DDCD WHERE DDCD.InstanceID = @InstanceID AND DDCD.VersionID = @VersionID AND DDCD.DataClassID = DC.DataClassID AND DDCD.DimensionID = DCD.DimensionID)

				SET @Inserted = @Inserted + @@ROWCOUNT

				--Dimension_StorageType
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
					(
					[InstanceID],
					[VersionID],
					[DimensionID],
					[StorageTypeBM],
					[ObjectGuiBehaviorBM],
					[ReadSecurityEnabledYN],
					[MappingTypeID],
					[ETLProcedure]
					)
				SELECT DISTINCT
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[DimensionID] = DST.DimensionID,
					[StorageTypeBM] = @StorageTypeBM,
					[ObjectGuiBehaviorBM] = DST.ObjectGuiBehaviorBM,
					[ReadSecurityEnabledYN] = DST.ReadSecurityEnabledYN,
					[MappingTypeID] = DST.MappingTypeID,
					[ETLProcedure] = DST.ETLProcedure
				FROM
					[pcINTEGRATOR].[dbo].[@Template_Dimension_StorageType] DST
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] DCD ON DCD.InstanceID = @InstanceID AND DCD.VersionID = @VersionID AND DCD.DimensionID = DST.DimensionID
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.InstanceID = DCD.InstanceID AND DC.VersionID = DCD.VersionID AND DC.DataClassID = DCD.DataClassID AND DC.InheritedFrom = @TemplateObjectID
				WHERE
					DST.[InstanceID] = @SourceInstanceID AND
					DST.[VersionID] = @SourceVersionID AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DDST WHERE DDST.[InstanceID] = @InstanceID AND DDST.[VersionID] = @VersionID AND DDST.[DimensionID] = DST.[DimensionID])

				SET @Inserted = @Inserted + @@ROWCOUNT

				--Dimension_StorageType, dependencies
				WHILE 
					(
					SELECT 
						COUNT(DISTINCT P.[DependentDimensionID])
					FROM
						[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
						INNER JOIN Dimension_Property DP ON DP.[InstanceID] IN (0, DST.[InstanceID]) AND DP.[VersionID] IN (0, DST.[VersionID]) AND DP.[DimensionID] = DST.[DimensionID]
						INNER JOIN Property P ON P.[InstanceID] IN (0, DST.[InstanceID]) AND P.[PropertyID] = DP.[PropertyID] AND P.[DependentDimensionID] IS NOT NULL
						INNER JOIN Dimension D ON D.[InstanceID] IN (0, DST.[InstanceID]) AND D.[DimensionID] = P.[DependentDimensionID]
 					WHERE
						DST.[InstanceID] = @InstanceID AND
						DST.[VersionID] = @VersionID AND
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DDST WHERE DDST.[InstanceID] = DST.[InstanceID] AND DDST.[VersionID] = DST.[VersionID] AND DDST.[DimensionID] = P.[DependentDimensionID])
					) > 0
					BEGIN
						INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
							(
							[InstanceID],
							[VersionID],
							[DimensionID],
							[StorageTypeBM],
							[ObjectGuiBehaviorBM],
							[ReadSecurityEnabledYN],
							[MappingTypeID]
							)
						SELECT DISTINCT
							[InstanceID] = DST.[InstanceID],
							[VersionID] = DST.[VersionID],
							[DimensionID] = P.[DependentDimensionID],
							[StorageTypeBM] = @StorageTypeBM,
							[ObjectGuiBehaviorBM] = D.[ObjectGuiBehaviorBM],
							[ReadSecurityEnabledYN] = 0,
							[MappingTypeID] = 0
						FROM
							[pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DST
							INNER JOIN Dimension_Property DP ON DP.[InstanceID] IN (0, DST.[InstanceID]) AND DP.[VersionID] IN (0, DST.[VersionID]) AND DP.[DimensionID] = DST.[DimensionID] AND DP.[SelectYN] <> 0
							INNER JOIN Property P ON P.[InstanceID] IN (0, DST.[InstanceID]) AND P.[PropertyID] = DP.[PropertyID] AND P.[DependentDimensionID] IS NOT NULL
							INNER JOIN Dimension D ON D.[InstanceID] IN (0, DST.[InstanceID]) AND D.[DimensionID] = P.[DependentDimensionID]
 						WHERE
							DST.[InstanceID] = @InstanceID AND
							DST.[VersionID] = @VersionID AND
							NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] DDST WHERE DDST.[InstanceID] = DST.[InstanceID] AND DDST.[VersionID] = DST.[VersionID] AND DDST.[DimensionID] = P.[DependentDimensionID])

						SET @Inserted = @Inserted + @@ROWCOUNT
					END

				--Grid_Dimension
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Grid_Dimension]
					(
					[InstanceID],
					[VersionID],
					[GridID],
					[DimensionID],
					[GridAxisID]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[GridID] = G.[GridID],
					[DimensionID] = GD.[DimensionID],
					[GridAxisID] = GD.[GridAxisID]
				FROM
					[pcINTEGRATOR].[dbo].[@Template_Grid_Dimension] GD
					INNER JOIN [pcINTEGRATOR_Data].[dbo].[Grid] G ON G.[InstanceID] = @InstanceID AND G.[VersionID] = @VersionID AND G.[InheritedFrom] = GD.[GridID]
				WHERE
					GD.[InstanceID] = @SourceInstanceID AND
					GD.[VersionID] = @SourceVersionID AND
					NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR_Data].[dbo].[Grid_Dimension] DGD WHERE DGD.[GridID] = G.[GridID] AND DGD.[DimensionID] = GD.[DimensionID] AND DGD.[GridAxisID] = GD.[GridAxisID])

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Reseed DimensionID'
		SELECT @MaxID = MAX(DimensionID) FROM [pcINTEGRATOR_Data].[dbo].[Dimension]
		SET @SQLStatement = 'EXEC [pcINTEGRATOR_Data].dbo.sp_executesql N''DBCC CHECKIDENT ([Dimension], RESEED, ' + CONVERT(NVARCHAR(15), @MaxID) + ')'''		
		EXEC (@SQLStatement)

	SET @Step = 'Insert Dimension to pcINTEGRATOR_Data, if not existing.'
		IF @SourceTypeID = 16 --pcETL
			BEGIN
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
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
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
						[ModelingStatusID] = ' + CONVERT(nvarchar(15), @ModelingStatusID) + ',
						[ModelingComment] = ''' + @ModelingComment + ''',
						[Introduced] = ''' + @Version + ''',
						[SelectYN] = 1
					FROM
						' + @ETLDatabase + '.[dbo].[XT_DimensionDefinition] DD
						LEFT JOIN [DimensionType] DT ON DT.InstanceID IN (0, ' + CONVERT(nvarchar(15), @InstanceID) + ') AND DT.[DimensionTypeName] = DD.[Type]
					WHERE
						NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[Dimension] D WHERE D.InstanceID IN (0, ' + CONVERT(nvarchar(15), @InstanceID) + ') AND D.[DimensionName] = DD.Label)
					ORDER BY
						DD.Label'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Insert DataClass_Dimension to pcINTEGRATOR_Data, if not existing.'
		IF @SourceTypeID = 16 --pcETL
			BEGIN
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
						[InstanceID] = ' + CONVERT(nvarchar(15), @InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15), @VersionID) + ',
						[DataClassID] = DC.[DataClassID],
						[DimensionID] = D.[DimensionID]
					FROM
						' + @ETLDatabase + '.[dbo].[XT_ModelDimensions] MD
						INNER JOIN [DataClass] DC ON DC.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND DC.DataClassName = MD.Model
						INNER JOIN [Dimension] D ON D.InstanceID IN (0, ' + CONVERT(nvarchar(15), @InstanceID) + ') AND D.DimensionName = MD.Dimension
					ORDER BY
						DC.[DataClassID],
						CASE WHEN D.DimensionTypeID = -1 THEN 2 ELSE 1 END,
						D.DimensionName'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
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

				SET @Inserted = @Inserted + @@ROWCOUNT
				DROP TABLE [#DataClass_Dimension]
			END

	SET @Step = 'Create temp tables'
		IF @SourceTypeID = 17 --Callisto
			BEGIN
				SET @Step = 'Create temp table #CallistoDimension'
				CREATE TABLE #CallistoDimension (DimensionCount int)

				SET @SQLStatement = '
					INSERT INTO 
						#CallistoDimension (DimensionCount)
					SELECT 
						DimensionCount = COUNT (1)
					FROM ' + @CallistoDatabase + '.[dbo].[S_Dimensions] 
					' + CASE WHEN @DimensionName IS NOT NULL THEN + ' WHERE Label = ''' + @DimensionName + '''' ELSE  '' END
			
				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)
				IF @DebugBM & 2 > 0 SELECT [TempTable] = '#CallistoDimension', *	FROM #CallistoDimension

				SET @Step = 'SP-Specific check'
					IF (SELECT DimensionCount FROM #CallistoDimension) < 1
						BEGIN
							SET @Message = 'The Dimension is not existing in Callisto. Please create first the Dimension in the Modeler.'
							SET @Severity = 16
							GOTO EXITPOINT
						END

				SET @Step = 'Create temp table #CallistoDimensionHierarchy'
					CREATE TABLE #CallistoDimensionHierarchy
						(
						[Comment] nvarchar(255),
						[InstanceID] int,
						[VersionID] int,
						[DimensionID] int,
						[HierarchyNo] int IDENTITY(1,1),
						[HierarchyName] nvarchar(50),
						[FixedLevelsYN] bit,
						[LockedYN] bit
						)
			END

		IF @SourceTypeID = 17 --Callisto
			BEGIN
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension]
						(
						[InstanceID],
						[DimensionName],
						[DimensionDescription],
						[DimensionTypeID],
						[ObjectGuiBehaviorBM],
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
						[SelectYN],
						[DeletedID],
						[Version]
						)
					SELECT DISTINCT
						[InstanceID] = ' + CONVERT(nvarchar(15),@InstanceID) + ',
						[DimensionName] = D.Label,
						[DimensionDescription] = D.Label,
						[DimensionTypeID] = ISNULL(DT.DimensionTypeID, 0),
						[ObjectGuiBehaviorBM] = 1,
						[GenericYN] = 0,
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
						[ModelingStatusID] = -40,
						[ModelingComment] = ''Copied from Callisto'',
						[Introduced] = ''' + @Version + ''',
						[SelectYN] = 1,
						[DeletedID] = NULL,
						[Version] = ''' + @Version + '''
					FROM 
						' + @CallistoDatabase + '.[dbo].[S_Dimensions] D
						LEFT JOIN [pcINTEGRATOR].[dbo].[DimensionType] DT ON DT.InstanceID IN (0, ' + CONVERT(nvarchar(15),@InstanceID) +') AND DT.[DimensionTypeName] = D.Type
					WHERE
						' + CASE WHEN @DimensionName IS NOT NULL THEN + ' D.Label = ''' + @DimensionName + ''' AND ' ELSE  '' END + '
						NOT EXISTS (SELECT 1 FROM Dimension DD WHERE DD.InstanceID IN (0, ' + CONVERT(nvarchar(15),@InstanceID) + ') AND DD.DimensionName = D.Label)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC (@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

		IF @SourceTypeID = 17 --Callisto
			BEGIN
				SET @SQLStatement = '
					INSERT INTO [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension]
						(
						[InstanceID],
						[VersionID],
						[DataClassID],
						[DimensionID],
						[FilterLevel],
						[SortOrder],
						[Version]
						)
					SELECT
						[InstanceID] = ' + CONVERT(nvarchar(15),@InstanceID) + ',
						[VersionID] = ' + CONVERT(nvarchar(15),@VersionID) + ',
						[DataClassID] = DC.DataClassID,
						[DimensionID] = D.DimensionID,
						[FilterLevel] = ''L'',
						[SortOrder] = 1,
						[Version] = ''' + @Version + '''
					FROM
						' + @CallistoDatabase + '.[dbo].[ModelDimensions] MD
						INNER JOIN [pcINTEGRATOR].[dbo].[Dimension] D ON D.InstanceID IN (0, ' + CONVERT(nvarchar(15),@InstanceID) + ') AND D.DimensionName = MD.Dimension 
						INNER JOIN [pcINTEGRATOR_Data].[dbo].[DataClass] DC ON DC.InstanceID = ' + CONVERT(nvarchar(15),@InstanceID) + ' AND DC.VersionID = ' + CONVERT(nvarchar(15),@VersionID) + ' AND DC.DataClassName = MD.Model
					WHERE
						' + CASE WHEN @DimensionName IS NOT NULL THEN + ' MD.Dimension = ''' + @DimensionName + ''' AND ' ELSE  '' END + '	 
						NOT EXISTS (SELECT 1 FROM DataClass_Dimension DCD WHERE DCD.InstanceID = ' + CONVERT(nvarchar(15),@InstanceID) + ' AND DCD.VersionID = ' + CONVERT(nvarchar(15),@VersionID) + ' AND DCD.DataClassID = DC.DataClassID AND DCD.DimensionID = D.DimensionID)'

				IF @DebugBM & 2 > 0 PRINT @SQLStatement
				EXEC(@SQLStatement)
				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Create Dimension Cursor for Callisto Dimensions'
		IF @SourceTypeID = 17 --Callisto
			BEGIN
				SET @Step = 'Create temp table #Dim_Cur_Table'
					CREATE TABLE #Dim_Cur_Table
						(
						DimensionID int,	
						DimensionName nvarchar(50)
						)

					SET @SQLStatement = '
						INSERT INTO #Dim_Cur_Table
							(
							DimensionID,	
							DimensionName
							)
						SELECT	
							DimensionID,
							DimensionName
						FROM 
							Dimension D
							INNER JOIN ' + @CallistoDatabase + '.[dbo].[S_Dimensions] SD ON SD.Label = D.DimensionName
						WHERE
							D.InstanceID IN (0, ' + CONVERT(nvarchar(10),@InstanceID) + ') ' + CASE WHEN @DimensionName IS NOT NULL THEN 'AND D.DimensionName = ''' + @DimensionName + '''' ELSE '' END				

					IF @DebugBM & 2 > 0 PRINT @SQLStatement
					EXEC (@SQLStatement)		
					IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Dim_Cur_Table', * FROM #Dim_Cur_Table

				SET @Step = 'Dimension_Cursor'
					IF CURSOR_STATUS('global','Dimension_Cursor') >= -1 DEALLOCATE Dimension_Cursor
					DECLARE Dimension_Cursor CURSOR FOR
			
						SELECT	
							DimensionID,
							DimensionName
						FROM 
							#Dim_Cur_Table

						OPEN Dimension_Cursor
						FETCH NEXT FROM Dimension_Cursor INTO @DimensionID, @DimensionName

						WHILE @@FETCH_STATUS = 0
							BEGIN
								IF @DebugBM & 2 > 0 SELECT [@DimensionID] = @DimensionID, [@DimensionName] = @DimensionName

									SET @Step = 'Insert Dimension_StorageType to pcINTEGRATOR_Data, if not existing.'
										INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
											(
											[InstanceID],
											[VersionID],
											[DimensionID],
											[StorageTypeBM],
											[ReadSecurityEnabledYN],
											[Version]
											)
										SELECT 
											[InstanceID] = @InstanceID,
											[VersionID] = @VersionID,
											[DimensionID] = D.DimensionID,
											[StorageTypeBM] = @StorageTypeBM,
											[ReadSecurityEnabledYN] = 0,
											[Version] = @Version
										FROM [pcINTEGRATOR].[dbo].[Dimension] D
										WHERE
											D.InstanceID IN (0, @InstanceID) AND 
											D.DimensionName = @DimensionName AND
											NOT EXISTS (SELECT 1 FROM Dimension_StorageType DST WHERE DST.[InstanceID] = @InstanceID AND DST.[VersionID] = @VersionID AND DST.[DimensionID] = D.DimensionID)
			
										SET @Inserted = @Inserted + @@ROWCOUNT 
			
									SET @Step = 'Insert Property to pcINTEGRATOR_Data, if not existing.'
										SET @SQLStatement = '	
											INSERT INTO #Property
												(
												[InstanceID],
												[PropertyName],
												[PropertyDescription]
												[ObjectGuiBehaviorBM],
												[DataTypeID],
												[Size],
												[DependentDimensionID],
												[StringTypeBM],
												[DynamicYN],
												[DefaultValueTable],
												[DefaultValueView],
												[SynchronizedYN],
												[SortOrder],
												[SourceTypeBM],
												[StorageTypeBM],
												[ViewPropertyYN],
												[HierarchySortOrderYN],
												[MandatoryYN],
												[DefaultSelectYN],
												[Introduced],
												[SelectYN],
												[Version]
												)
											SELECT 
												[InstanceID] = ' + CONVERT(nvarchar(10),@InstanceID) + ',
												[PropertyName] = C.name,
												[PropertyDescription] = C.name,
												[ObjectGuiBehaviorBM] = 9,
												[DataTypeID] = CASE WHEN M.DataType IS NOT NULL THEN 3 ELSE DT.DataTypeID END,
												[Size] = CASE WHEN Ty.name IN (''nvarchar'',''varchar'', ''nchar'', ''char'') AND M.PropertyName IS NULL THEN C.max_length/2 ELSE NULL END,
												[DependentDimensionID] = D.DimensionID,
												[StringTypeBM] = 0,
												[DynamicYN] = 1,
												[DefaultValueTable] = NULL,
												[DefaultValueView] = ''NONE'',
												[SynchronizedYN] = 1,
												[SortOrder] = C.column_id + 30,
												[SourceTypeBM] = 65535,
												[StorageTypeBM] = ' + CONVERT(nvarchar(15), @StorageTypeBM) + ',
												[ViewPropertyYN] = 0,
												[HierarchySortOrderYN] = 0,
												[MandatoryYN] = 1,
												[DefaultSelectYN] = 1,
												[Introduced] = ''' + @Version + ''',
												[SelectYN] = 1,
												[Version] = ''' + @Version + '''
											FROM 
												' + @CallistoDatabase + '.sys.tables T 
												INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON C.object_id = T.object_id AND C.name NOT IN (''MemberId'', ''Label'', ''Description'', ''HelpText'', ''RNodeType'', ''SBZ'', ''Source'', ''Synchronized'') AND C.NAME NOT LIKE ''%_MemberId''
												INNER JOIN ' + @CallistoDatabase + '.sys.types Ty ON Ty.system_type_id = C.system_type_id AND Ty.user_type_id = C.user_type_id
												LEFT JOIN
												(
												SELECT DataType = ''Member'', PropertyName = REPLACE(C.Name,''_MemberId'', '''') 
												FROM ' + @CallistoDatabase + '.sys.tables T 
													INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON c.object_id = T.object_id AND C.name LIKE ''%_MemberId''
												WHERE T.name = ''S_DS_' + @DimensionName + '''
												)
												AS M ON M.PropertyName = C.name
												LEFT JOIN [pcINTEGRATOR].[dbo].[DataType] DT ON DT.DataTypeID IN (1,2,4,5,8,9) AND DT.DataTypeCode = ISNULL(CONVERT(NVARCHAR(100),M.DataType), Ty.name)
												LEFT JOIN [pcCALLISTO_Export].[dbo].[XT_PropertyDefinition] XPD ON XPD.Dimension = ''' + @DimensionName + ''' AND XPD.Label = C.name AND XPD.DataType = ''Member''
												LEFT JOIN 
												(
												SELECT InstanceID, DimensionID, DimensionName 
												FROM [pcINTEGRATOR].[dbo].[Dimension] 
												WHERE InstanceID IN (0, ' + CONVERT(nvarchar(10),@InstanceID) + ')
												)
												AS D ON D.DimensionName = XPD.MemberDimension
											WHERE
												T.name = ''S_DS_' + @DimensionName + ''' AND
												NOT EXISTS (SELECT 1 FROM Property PR WHERE PR.InstanceID IN (0, ' + CONVERT(nvarchar(10),@InstanceID) + ') AND PR.PropertyName = C.name)
											ORDER BY 
												C.column_id'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC(@SQLStatement)

										IF @DebugBM & 2 > 0 SELECT [TempTable] = '#Property', * FROM #Property

										SET @SQLStatement = '	
											INSERT INTO pcINTEGRATOR_Data..Property
												(
												[InstanceID],
												[PropertyName],
												[PropertyDescription]
												[ObjectGuiBehaviorBM],
												[DataTypeID],
												[Size],
												[DependentDimensionID],
												[StringTypeBM],
												[DynamicYN],
												[DefaultValueTable],
												[DefaultValueView],
												[SynchronizedYN],
												[SortOrder],
												[SourceTypeBM],
												[StorageTypeBM],
												[ViewPropertyYN],
												[HierarchySortOrderYN],
												[MandatoryYN],
												[DefaultSelectYN],
												[Introduced],
												[SelectYN],
												[Version]
												)
											SELECT 
												[InstanceID],
												[PropertyName],
												[PropertyDescription]
												[ObjectGuiBehaviorBM],
												[DataTypeID],
												[Size],
												[DependentDimensionID],
												[StringTypeBM],
												[DynamicYN],
												[DefaultValueTable],
												[DefaultValueView],
												[SynchronizedYN],
												[SortOrder],
												[SourceTypeBM],
												[StorageTypeBM],
												[ViewPropertyYN],
												[HierarchySortOrderYN],
												[MandatoryYN],
												[DefaultSelectYN],
												[Introduced],
												[SelectYN],
												[Version]
											FROM 
												#Property
											ORDER BY 
												[SortOrder]'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC(@SQLStatement)

										SET @Inserted = @Inserted + @@ROWCOUNT

									SET @Step = 'Delete Dimension_Property in pcINTEGRATOR_Data, if Property is not existing in Callisto.'
										SET @SQLStatement = '
											DELETE DP
											FROM 
												[pcINTEGRATOR_Data].[dbo].[Dimension_Property] DP
												INNER JOIN [pcINTEGRATOR_Data].[dbo].[Property] P ON P.PropertyID = DP.PropertyID
											WHERE
												DP.InstanceID = ' + CONVERT(nvarchar(15), @InstanceID) + ' AND
												DP.VersionID = ' + CONVERT(nvarchar(15), @VersionID) + ' AND
												DP.DimensionID = ' + CONVERT(nvarchar(15), @DimensionID) + ' AND
												NOT EXISTS 
												(
												SELECT C.[name]
												FROM 
													' + @CallistoDatabase + '.sys.tables T 
													INNER JOIN ' + @CallistoDatabase + '.sys.columns C ON C.object_id = T.object_id AND C.name NOT IN (''MemberId'', ''Label'', ''Description'', ''HelpText'', ''RNodeType'', ''SBZ'', ''Source'', ''Synchronized'') AND C.NAME NOT LIKE ''%_MemberId''
												WHERE 
													T.[name] = ''S_DS_' + @DimensionName + ''' AND
													C.[name] = P.PropertyName	
												)'

										IF @DebugBM & 2 > 0 PRINT @SQLStatement
										EXEC(@SQLStatement)

										SET @Deleted = @Deleted + @@ROWCOUNT

									SET @Step = 'Insert Dimension_Property to pcINTEGRATOR_Data, if not existing.'
										INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_Property]
											(
											[Comment],
											[InstanceID],
											[VersionID],
											[DimensionID],
											[PropertyID],
											[SortOrder],
											[Introduced],
											[SelectYN],
											[Version]
											)
										SELECT
											[Comment] = P.PropertyName,
											[InstanceID] = P.[InstanceID],
											[VersionID] = @VersionID,
											[DimensionID] = @DimensionID,
											[PropertyID],
											[SortOrder] = P.[SortOrder],
											[Introduced] = P.[Introduced],
											[SelectYN] = P.[SelectYN],
											[Version] = P.[Version]
										FROM
											#Property TP
											INNER JOIN [pcINTEGRATOR_Data].[dbo].[Property] P ON P.InstanceID = @InstanceID AND P.PropertyName = TP.PropertyName
										WHERE
											NOT EXISTS (SELECT 1 FROM Dimension_Property DP WHERE DP.InstanceID IN (0, @InstanceID) AND DP.VersionID IN (0, @VersionID) AND DP.DimensionID = @DimensionID AND DP.PropertyID = P.PropertyID)

										SET @Inserted = @Inserted + @@ROWCOUNT

									SET @Step = 'Insert values to #CallistoDimensionHierarchy.'
										INSERT INTO #CallistoDimensionHierarchy
											(
											[Comment],
											[InstanceID],
											[VersionID],
											[DimensionID],
											[HierarchyName],
											[FixedLevelsYN],
											[LockedYN]
											)
										SELECT
											[Comment] = XHD.Dimension,
											[InstanceID] = @InstanceID,
											[VersionID] = @VersionID,
											[DimensionID] = @DimensionID,
											[HierarchyName] = XHD.Label,
											[FixedLevelsYN] = 1,
											[LockedYN] = 0
										FROM 
											[pcCALLISTO_Export].[dbo].[XT_HierarchyDefinition] XHD
										WHERE
											XHD.Dimension = @DimensionName AND XHD.Dimension <> XHD.Label

										IF @DebugBM & 2 > 0 SELECT [TempTable] = '#CallistoDimensionHierarchy', * FROM #CallistoDimensionHierarchy

									SET @Step = 'Insert DimensionHierarchy to pcINTEGRATOR_Data, if not existing.'
										INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
											(
											[Comment],
											[InstanceID],
											[VersionID],
											[DimensionID],
											[HierarchyNo],
											[HierarchyName],
											[FixedLevelsYN],
											[LockedYN],
											[Version]
											)
										SELECT
											[Comment],
											[InstanceID],
											[VersionID],
											[DimensionID],
											[HierarchyNo],
											[HierarchyName],
											[FixedLevelsYN],
											[LockedYN],
											[Version] = @Version
										FROM
											(
											SELECT
												[Comment] = @DimensionName,
												[InstanceID] = @InstanceID,
												[VersionID] = @VersionID,
												[DimensionID] = @DimensionID,
												[HierarchyNo] = 0,
												[HierarchyName] = @DimensionName,
												[FixedLevelsYN] = 0,
												[LockedYN] = 0
											UNION
											SELECT
												[Comment],
												[InstanceID],
												[VersionID],
												[DimensionID],
												[HierarchyNo],
												[HierarchyName],
												[FixedLevelsYN],
												[LockedYN]
											FROM #CallistoDimensionHierarchy
											) AS sub
										WHERE
											NOT EXISTS (SELECT 1 FROM DimensionHierarchy DH WHERE DH.InstanceID IN (0, sub.InstanceID) AND DH.[VersionID] IN (0, sub.VersionID) AND DH.DimensionID = sub.DimensionID AND DH.HierarchyName = sub.HierarchyName)

										SET @Inserted = @Inserted + @@ROWCOUNT 

									SET @Step = 'Insert DimensionHierarchyLevel to pcINTEGRATOR_Data, if not existing.'
										INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
											(
											[Comment],
											[InstanceID],
											[VersionID],
											[DimensionID],
											[HierarchyNo],
											[LevelNo],
											[LevelName],
											[Version]
											)
										SELECT
											[Comment],
											[InstanceID],
											[VersionID] = @VersionID,
											[DimensionID],
											[HierarchyNo],
											[LevelNo],
											[LevelName],
											[Version] = @Version
										FROM
											(
											SELECT 
												[Comment] = @DimensionName,
												[InstanceID] = @InstanceID,
												[DimensionID] = @DimensionID,
												[HierarchyNo] = 0, 
												[LevelNo] = 1,
												[LevelName] = 'Top Node'
											UNION
											SELECT
												[Comment] = @DimensionName,
												[InstanceID] = @InstanceID,
												[DimensionID] = @DimensionID,
												[HierarchyNo] = 0,  
												[LevelNo] = 2,
												[LevelName] = @DimensionName
											)
											AS sub
										WHERE
											NOT EXISTS (SELECT 1 FROM DimensionHierarchyLevel DHL WHERE DHL.InstanceID IN (0, sub.InstanceID) AND DHL.[VersionID] IN (0, @VersionID) AND DHL.DimensionID = sub.DimensionID AND DHL.HierarchyNo = sub.HierarchyNo AND DHL.LevelNo = sub.LevelNo)
	
										SET @Inserted = @Inserted + @@ROWCOUNT

						FETCH NEXT FROM Dimension_Cursor INTO @DimensionID, @DimensionName
						END

					CLOSE Dimension_Cursor
					DEALLOCATE Dimension_Cursor
			END

	SET @Step = 'Insert Grid_Dimension to pcINTEGRATOR_Data, if not existing.'
		IF @SourceTypeID IN (16, 17)
			BEGIN
				INSERT INTO [pcINTEGRATOR_Data].[dbo].[Grid_Dimension]
					(
					[InstanceID],
					[VersionID],
					[GridID],
					[DimensionID],
					[GridAxisID]
					)
				SELECT 
					[InstanceID] = @InstanceID,
					[VersionID] = @VersionID,
					[GridID],
					[DimensionID],
					[GridAxisID]
				FROM
					(
					SELECT DISTINCT
						[GridID],
						[DimensionID] = -1,
						[GridAxisID] = -2
					FROM
						[Grid] G
					WHERE
						G.[InstanceID] = @InstanceID AND G.[VersionID] = @VersionID			
					UNION 
					SELECT DISTINCT 
						[GridID],
						[DimensionID] = -7,
						[GridAxisID] = -3
					FROM
						[Grid] G
					WHERE
						G.[InstanceID] = @InstanceID AND G.[VersionID] = @VersionID	
					) sub			
				WHERE
					NOT EXISTS (SELECT 1 FROM [Grid_Dimension] GD WHERE GD.[InstanceID] = @InstanceID AND GD.[VersionID] = @VersionID AND GD.[GridID] = sub.[GridID] AND GD.[DimensionID] IN (-1, -7))

				SET @Inserted = @Inserted + @@ROWCOUNT
			END

	SET @Step = 'Insert Dimension_StorageType to pcINTEGRATOR_Data, if not existing.'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType]
			(
			[InstanceID],
			[VersionID],
			[DimensionID],
			[StorageTypeBM],
			[ETLProcedure]
			)
		SELECT DISTINCT
			[InstanceID] = DCD.[InstanceID],
			[VersionID] = DCD.[VersionID],
			[DimensionID] = DCD.[DimensionID],
			[StorageTypeBM] = @StorageTypeBM,
			[ETLProcedure] = TDS.[ETLProcedure]
		FROM
			[DataClass_Dimension] DCD
			INNER JOIN [pcINTEGRATOR].[dbo].[@Template_Dimension_StorageType] TDS ON TDS.DimensionID=DCD.DimensionID
		WHERE
			DCD.[InstanceID] = @InstanceID AND
			DCD.[VersionID] = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [Dimension_StorageType] DST WHERE DST.[InstanceID] = DCD.[InstanceID] AND DST.[VersionID] = DCD.[VersionID] AND DST.[DimensionID] = DCD.[DimensionID])

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert DimensionHierarchy to pcINTEGRATOR_Data, if not existing.'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy]
			(
			[Comment],
			[InstanceID],
			[VersionID],
			[DimensionID],
			[HierarchyNo],
			[HierarchyName],
			[FixedLevelsYN],
			[LockedYN]
			)
		SELECT DISTINCT
			[Comment] = D.DimensionName,
			[InstanceID] = DCD.[InstanceID],
			[VersionID] = DCD.[VersionID],
			[DimensionID] = DCD.[DimensionID],
			[HierarchyNo] = 0,
			[HierarchyName] = D.DimensionName,
			[FixedLevelsYN] = 1,
			[LockedYN] = 0
		FROM
			[DataClass_Dimension] DCD
			INNER JOIN [Dimension] D ON D.DimensionID = DCD.DimensionID AND D.[InstanceID] IN (0, DCD.[InstanceID]) AND D.DeletedID IS NULL
		WHERE
			DCD.[InstanceID] = @InstanceID AND
			DCD.[VersionID] = @VersionID AND
			NOT EXISTS (SELECT 1 FROM [DimensionHierarchy] DH WHERE DH.[InstanceID] IN (0, DCD.[InstanceID]) AND DH.[VersionID] IN (0, DCD.[VersionID]) AND DH.[DimensionID] = DCD.[DimensionID] AND DH.[HierarchyNo] = 0)

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Insert DimensionHierarchyLevel to pcINTEGRATOR_Data, if not existing.'
		INSERT INTO [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel]
			(
			[Comment],
			[InstanceID],
			[VersionID],
			[DimensionID],
			[HierarchyNo],
			[LevelNo],
			[LevelName]
			)
		SELECT
			[Comment] = sub.[Comment],
			[InstanceID] = @InstanceID,
			[VersionID] = @VersionID,
			[DimensionID] = sub.[DimensionID],
			[HierarchyNo] = sub.[HierarchyNo],
			[LevelNo] = sub.[LevelNo],
			[LevelName] = sub.[LevelName]
		FROM
			(
			SELECT DISTINCT
				[Comment] = D.DimensionName,
				[DimensionID] = DCD.[DimensionID],
				[HierarchyNo] = 0,
				[LevelNo] = 1,
				[LevelName] = 'TopNode'
			FROM
				[DataClass_Dimension] DCD
				INNER JOIN [Dimension] D ON D.DimensionID = DCD.DimensionID AND D.[InstanceID] IN (0, DCD.[InstanceID]) AND D.DeletedID IS NULL
			WHERE
				DCD.[InstanceID] = @InstanceID AND
				DCD.[VersionID] = @VersionID
			UNION SELECT DISTINCT
				[Comment] = D.DimensionName,
				[DimensionID] = DCD.[DimensionID],
				[HierarchyNo] = 0,
				[LevelNo] = 2,
				[LevelName] = REPLACE(D.DimensionName, 'GL_', '')
			FROM
				[DataClass_Dimension] DCD
				INNER JOIN [Dimension] D ON D.DimensionID = DCD.DimensionID AND D.[InstanceID] IN (0, DCD.[InstanceID]) AND D.DeletedID IS NULL
			WHERE
				DCD.[InstanceID] = @InstanceID AND
				DCD.[VersionID] = @VersionID
			) sub
		WHERE
			NOT EXISTS (SELECT 1 FROM [DimensionHierarchyLevel] DHL WHERE DHL.[InstanceID] IN (0, @InstanceID) AND DHL.[VersionID] IN (0, @VersionID) AND DHL.[DimensionID] = sub.[DimensionID] AND DHL.[HierarchyNo] = sub.[HierarchyNo] AND DHL.[LevelNo] = sub.[LevelNo])
		ORDER BY
			sub.[DimensionID],
			sub.[HierarchyNo],
			sub.[LevelNo]

		SET @Inserted = @Inserted + @@ROWCOUNT

	SET @Step = 'Return information'
		IF @DebugBM & 1 > 0 
			BEGIN
				SELECT [Table] = 'pcINTEGRATOR_Data..Dimension', * FROM [pcINTEGRATOR_Data].[dbo].[Dimension] WHERE [InstanceID] = @InstanceID
				SELECT [Table] = 'pcINTEGRATOR_Data..Dimension_StorageType', * FROM [pcINTEGRATOR_Data].[dbo].[Dimension_StorageType] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
				SELECT [Table] = 'pcINTEGRATOR_Data..DataClass_Dimension', * FROM [pcINTEGRATOR_Data].[dbo].[DataClass_Dimension] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
				SELECT [Table] = 'pcINTEGRATOR_Data..Grid_Dimension', * FROM [pcINTEGRATOR_Data].[dbo].[Grid_Dimension] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
				SELECT [Table] = 'pcINTEGRATOR_Data..Property', * FROM [pcINTEGRATOR_Data].[dbo].[Property] WHERE [InstanceID] = @InstanceID
				SELECT [Table] = 'pcINTEGRATOR_Data..Dimension_Property', * FROM [pcINTEGRATOR_Data].[dbo].[Dimension_Property] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
				SELECT [Table] = 'pcINTEGRATOR_Data..DimensionHierarchy', * FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchy] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
				SELECT [Table] = 'pcINTEGRATOR_Data..DimensionHierarchyLevel', * FROM [pcINTEGRATOR_Data].[dbo].[DimensionHierarchyLevel] WHERE [InstanceID] = @InstanceID AND [VersionID] = @VersionID
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
