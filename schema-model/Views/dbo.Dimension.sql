SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Dimension] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[DimensionID],
	[sub].[DimensionName],
	[sub].[DimensionDescription],
	[sub].[DimensionTypeID],
	[sub].[ObjectGuiBehaviorBM],
	[sub].[GenericYN],
	[sub].[MultipleProcedureYN],
	[sub].[AllYN],
	[sub].[ReportOnlyYN],
	[sub].[HiddenMember],
	[sub].[Hierarchy],
	[sub].[TranslationYN],
	[sub].[DefaultSelectYN],
	[sub].[DefaultSetMemberKey],
	[sub].[DefaultGetMemberKey],
	[sub].[DefaultGetHierarchyNo],
	[sub].[DefaultValue],
	[sub].[DeleteJoinYN],
	[sub].[SourceTypeBM],
	[sub].[MasterDimensionID],
	[sub].[HierarchyMasterDimensionID],
	[sub].[InheritedFrom],
	[sub].[SeedMemberID],
	[sub].[LoadSP],
	[sub].[MasterDataManagementBM],
	[sub].[ModelingStatusID],
	[sub].[ModelingComment],
	[sub].[Introduced],
	[sub].[SelectYN],
	[sub].[DeletedID],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[DimensionID],
		[DimensionName],
		[DimensionDescription],
		[DimensionTypeID],
		[ObjectGuiBehaviorBM],
		[GenericYN],
		[MultipleProcedureYN],
		[AllYN],
		[ReportOnlyYN],
		[HiddenMember],
		[Hierarchy],
		[TranslationYN],
		[DefaultSelectYN],
		[DefaultSetMemberKey],
		[DefaultGetMemberKey],
		[DefaultGetHierarchyNo],
		[DefaultValue],
		[DeleteJoinYN],
		[SourceTypeBM],
		[MasterDimensionID],
		[HierarchyMasterDimensionID],
		[InheritedFrom],
		[SeedMemberID],
		[LoadSP],
		[MasterDataManagementBM],
		[ModelingStatusID],
		[ModelingComment],
		[Introduced],
		[SelectYN],
		[DeletedID],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Dimension]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[DimensionID],
		[DimensionName],
		[DimensionDescription],
		[DimensionTypeID],
		[ObjectGuiBehaviorBM],
		[GenericYN],
		[MultipleProcedureYN],
		[AllYN],
		[ReportOnlyYN],
		[HiddenMember],
		[Hierarchy],
		[TranslationYN],
		[DefaultSelectYN],
		[DefaultSetMemberKey],
		[DefaultGetMemberKey],
		[DefaultGetHierarchyNo],
		[DefaultValue],
		[DeleteJoinYN],
		[SourceTypeBM],
		[MasterDimensionID],
		[HierarchyMasterDimensionID],
		[InheritedFrom],
		[SeedMemberID],
		[LoadSP],
		[MasterDataManagementBM],
		[ModelingStatusID],
		[ModelingComment],
		[Introduced],
		[SelectYN],
		[DeletedID],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Dimension]
	) sub
GO
