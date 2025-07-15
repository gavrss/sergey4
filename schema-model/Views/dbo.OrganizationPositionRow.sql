SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[OrganizationPositionRow] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[OrganizationPositionID],
	[sub].[DimensionID],
	[sub].[Dimension_MemberKey]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[OrganizationPositionID],
		[DimensionID],
		[Dimension_MemberKey]
	FROM
		[pcINTEGRATOR_Data].[dbo].[OrganizationPositionRow]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[OrganizationPositionID],
		[DimensionID],
		[Dimension_MemberKey]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_OrganizationPositionRow]
	) sub
GO
