SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[ListMaintain_UserWorkflow] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[UserID],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[Email],
	[sub].[GivenName],
	[sub].[FamilyName],
	[sub].[Title],
	[sub].[UserNameDisplay],
	[sub].[UserNameAD],
	[sub].[LicenseType],
	[sub].[ReportsTo],
	[sub].[OnBehalfOf],
	[sub].[LinkedDimensionID],
	[sub].[ResponsibleFor],
	[sub].[Updated],
	[sub].[UpdatedBy]
FROM
	(
	SELECT
		[UserID],
		[InstanceID],
		[VersionID],
		[Email],
		[GivenName],
		[FamilyName],
		[Title],
		[UserNameDisplay],
		[UserNameAD],
		[LicenseType],
		[ReportsTo],
		[OnBehalfOf],
		[LinkedDimensionID],
		[ResponsibleFor],
		[Updated],
		[UpdatedBy]
	FROM
		[pcINTEGRATOR_Data].[dbo].[ListMaintain_UserWorkflow]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[UserID],
		[InstanceID],
		[VersionID],
		[Email],
		[GivenName],
		[FamilyName],
		[Title],
		[UserNameDisplay],
		[UserNameAD],
		[LicenseType],
		[ReportsTo],
		[OnBehalfOf],
		[LinkedDimensionID],
		[ResponsibleFor],
		[Updated],
		[UpdatedBy]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_ListMaintain_UserWorkflow]
	) sub
GO
