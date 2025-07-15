SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[UxFieldType] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[UxFieldTypeID],
	[sub].[UxFieldTypeName],
	[sub].[UxFieldTypeDescription],
	[sub].[UxValidation],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[UxFieldTypeID],
		[UxFieldTypeName],
		[UxFieldTypeDescription],
		[UxValidation],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[UxFieldType]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[UxFieldTypeID],
		[UxFieldTypeName],
		[UxFieldTypeDescription],
		[UxValidation],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_UxFieldType]
	) sub
GO
