SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[OrganizationHierarchy] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[OrganizationHierarchyID],
	[sub].[VersionID],
	[sub].[OrganizationHierarchyName],
	[sub].[LinkedDimensionID],
	[sub].[ModelingStatusID],
	[sub].[ModelingComment],
	[sub].[InheritedFrom],
	[sub].[DeletedID]
FROM
	(
	SELECT
		[InstanceID],
		[OrganizationHierarchyID],
		[VersionID],
		[OrganizationHierarchyName],
		[LinkedDimensionID],
		[ModelingStatusID],
		[ModelingComment],
		[InheritedFrom],
		[DeletedID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[OrganizationHierarchy]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[OrganizationHierarchyID],
		[VersionID],
		[OrganizationHierarchyName],
		[LinkedDimensionID],
		[ModelingStatusID],
		[ModelingComment],
		[InheritedFrom],
		[DeletedID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_OrganizationHierarchy]
	) sub
GO
