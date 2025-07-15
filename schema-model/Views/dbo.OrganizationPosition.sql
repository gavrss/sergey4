SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[OrganizationPosition] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[OrganizationPositionID],
	[sub].[VersionID],
	[sub].[OrganizationPositionName],
	[sub].[OrganizationPositionDescription],
	[sub].[OrganizationHierarchyID],
	[sub].[ParentOrganizationPositionID],
	[sub].[OrganizationLevelNo],
	[sub].[LinkedDimension_MemberKey],
	[sub].[InheritedFrom],
	[sub].[SortOrder],
	[sub].[DeletedID],
	[sub].[OrganizationPositionTypeID]
FROM
	(
	SELECT
		[InstanceID],
		[OrganizationPositionID],
		[VersionID],
		[OrganizationPositionName],
		[OrganizationPositionDescription],
		[OrganizationHierarchyID],
		[ParentOrganizationPositionID],
		[OrganizationLevelNo],
		[LinkedDimension_MemberKey],
		[InheritedFrom],
		[SortOrder],
		[DeletedID],
		[OrganizationPositionTypeID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[OrganizationPosition]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[OrganizationPositionID],
		[VersionID],
		[OrganizationPositionName],
		[OrganizationPositionDescription],
		[OrganizationHierarchyID],
		[ParentOrganizationPositionID],
		[OrganizationLevelNo],
		[LinkedDimension_MemberKey],
		[InheritedFrom],
		[SortOrder],
		[DeletedID],
		[OrganizationPositionTypeID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_OrganizationPosition]
	) sub
GO
