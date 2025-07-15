SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[OrganizationPosition_DataClass] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[OrganizationPositionID],
	[sub].[DataClassID],
	[sub].[ReadAccessYN],
	[sub].[VersionID],
	[sub].[WriteAccessYN],
	[sub].[Version]
FROM
	(
	SELECT
		[Comment],
		[InstanceID],
		[OrganizationPositionID],
		[DataClassID],
		[ReadAccessYN],
		[VersionID],
		[WriteAccessYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_DataClass]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[OrganizationPositionID],
		[DataClassID],
		[ReadAccessYN],
		[VersionID],
		[WriteAccessYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_OrganizationPosition_DataClass]
	) sub
GO
