SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[UserPropertyValue] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[UserID],
	[sub].[UserPropertyTypeID],
	[sub].[UserPropertyValue],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[UserID],
		[UserPropertyTypeID],
		[UserPropertyValue],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[UserPropertyValue]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[UserID],
		[UserPropertyTypeID],
		[UserPropertyValue],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_UserPropertyValue]
	) sub
GO
