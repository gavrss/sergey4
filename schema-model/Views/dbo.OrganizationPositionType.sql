SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[OrganizationPositionType] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[OrganizationPositionTypeID],
	[sub].[OrganizationPositionTypeName],
	[sub].[OrganizationPositionTypeDescription],
	[sub].[CommissionParameter],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[OrganizationPositionTypeID],
		[OrganizationPositionTypeName],
		[OrganizationPositionTypeDescription],
		[CommissionParameter],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[OrganizationPositionType]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[OrganizationPositionTypeID],
		[OrganizationPositionTypeName],
		[OrganizationPositionTypeDescription],
		[CommissionParameter],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_OrganizationPositionType]
	) sub
GO
