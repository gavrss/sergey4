SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[DataType] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[DataTypeID],
	[sub].[DataTypeName],
	[sub].[DataTypeDescription],
	[sub].[DataTypeCode],
	[sub].[DataTypePortal],
	[sub].[DataTypeCallisto],
	[sub].[SizeYN],
	[sub].[GuiObject],
	[sub].[DataTypeGroupBM],
	[sub].[Version],
	[sub].[PropertyTypeID]
FROM
	(
	SELECT
		[InstanceID],
		[DataTypeID],
		[DataTypeName],
		[DataTypeDescription],
		[DataTypeCode],
		[DataTypePortal],
		[DataTypeCallisto],
		[SizeYN],
		[GuiObject],
		[DataTypeGroupBM],
		[Version],
		[PropertyTypeID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DataType]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[DataTypeID],
		[DataTypeName],
		[DataTypeDescription],
		[DataTypeCode],
		[DataTypePortal],
		[DataTypeCallisto],
		[SizeYN],
		[GuiObject],
		[DataTypeGroupBM],
		[Version],
		[PropertyTypeID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DataType]
	) sub
GO
