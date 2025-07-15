SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[UserPropertyType] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[UserPropertyTypeID],
	[sub].[UserPropertyTypeName],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[UserPropertyTypeID],
		[UserPropertyTypeName],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[UserPropertyType]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[UserPropertyTypeID],
		[UserPropertyTypeName],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_UserPropertyType]
	) sub
GO
