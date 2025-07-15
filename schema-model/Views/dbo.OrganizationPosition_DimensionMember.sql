SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[OrganizationPosition_DimensionMember] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[OrganizationPositionID],
	[sub].[DimensionID],
	[sub].[MemberKey],
	[sub].[ReadAccessYN],
	[sub].[DeletedID],
	[sub].[HierarchyNo],
	[sub].[WriteAccessYN]
FROM
	(
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[OrganizationPositionID],
		[DimensionID],
		[MemberKey],
		[ReadAccessYN],
		[DeletedID],
		[HierarchyNo],
		[WriteAccessYN]
	FROM
		[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DimensionMember]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[OrganizationPositionID],
		[DimensionID],
		[MemberKey],
		[ReadAccessYN],
		[DeletedID],
		[HierarchyNo],
		[WriteAccessYN]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_OrganizationPosition_DimensionMember]
	) sub
GO
