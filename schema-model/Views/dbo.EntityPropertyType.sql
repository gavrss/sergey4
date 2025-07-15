SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[EntityPropertyType] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[EntityPropertyTypeID],
	[sub].[EntityPropertyTypeName],
	[sub].[EntityPropertyTypeDescription],
	[sub].[SourceTypeBM],
	[sub].[MandatoryYN],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[EntityPropertyTypeID],
		[EntityPropertyTypeName],
		[EntityPropertyTypeDescription],
		[SourceTypeBM],
		[MandatoryYN],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[EntityPropertyType]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[EntityPropertyTypeID],
		[EntityPropertyTypeName],
		[EntityPropertyTypeDescription],
		[SourceTypeBM],
		[MandatoryYN],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_EntityPropertyType]
	) sub
GO
