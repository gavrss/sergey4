SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[OrganizationPosition_User] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[OrganizationPositionID],
	[sub].[UserID],
	[sub].[DelegateYN],
	[sub].[Comment],
	[sub].[DeletedID],
	[sub].[DateFrom],
	[sub].[DateTo]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[OrganizationPositionID],
		[UserID],
		[DelegateYN],
		[Comment],
		[DeletedID],
		[DateFrom],
		[DateTo]
	FROM
		[pcINTEGRATOR_Data].[dbo].[OrganizationPosition_User]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[OrganizationPositionID],
		[UserID],
		[DelegateYN],
		[Comment],
		[DeletedID],
		[DateFrom],
		[DateTo]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_OrganizationPosition_User]
	) sub
GO
