SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[SqlQueryParameter] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[SqlQueryID],
	[sub].[SqlQueryParameter],
	[sub].[SqlQueryParameterName],
	[sub].[SqlQueryParameterDescription],
	[sub].[DataType],
	[sub].[Size],
	[sub].[DefaultValue],
	[sub].[SqlQueryParameterQuery],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[SqlQueryID],
		[SqlQueryParameter],
		[SqlQueryParameterName],
		[SqlQueryParameterDescription],
		[DataType],
		[Size],
		[DefaultValue],
		[SqlQueryParameterQuery],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[SqlQueryParameter]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[SqlQueryID],
		[SqlQueryParameter],
		[SqlQueryParameterName],
		[SqlQueryParameterDescription],
		[DataType],
		[Size],
		[DefaultValue],
		[SqlQueryParameterQuery],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_SqlQueryParameter]
	) sub
GO
