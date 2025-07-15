SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[ParameterType] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[ParameterTypeID],
	[sub].[ParameterTypeName],
	[sub].[ParameterTypeDescription],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[ParameterTypeID],
		[ParameterTypeName],
		[ParameterTypeDescription],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[ParameterType]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[ParameterTypeID],
		[ParameterTypeName],
		[ParameterTypeDescription],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_ParameterType]
	) sub
GO
