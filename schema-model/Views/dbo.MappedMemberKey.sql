SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[MappedMemberKey] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[DimensionID],
	[sub].[Entity_MemberKey],
	[sub].[MemberKeyFrom],
	[sub].[MemberKeyTo],
	[sub].[MappingTypeID],
	[sub].[MappedMemberKey],
	[sub].[MappedDescription],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[DimensionID],
		[Entity_MemberKey],
		[MemberKeyFrom],
		[MemberKeyTo],
		[MappingTypeID],
		[MappedMemberKey],
		[MappedDescription],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[MappedMemberKey]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[DimensionID],
		[Entity_MemberKey],
		[MemberKeyFrom],
		[MemberKeyTo],
		[MappingTypeID],
		[MappedMemberKey],
		[MappedDescription],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_MappedMemberKey]
	) sub
GO
