SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[SystemParameter] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[Parameter],
	[sub].[ParameterTypeID],
	[sub].[ProcessID],
	[sub].[ParameterDescription],
	[sub].[HelpText],
	[sub].[ParameterValue],
	[sub].[UxFieldTypeID],
	[sub].[UxEditableYN],
	[sub].[UxHelpUrl],
	[sub].[UxSelectionSource],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[Parameter],
		[ParameterTypeID],
		[ProcessID],
		[ParameterDescription],
		[HelpText],
		[ParameterValue],
		[UxFieldTypeID],
		[UxEditableYN],
		[UxHelpUrl],
		[UxSelectionSource],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[SystemParameter]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[Parameter],
		[ParameterTypeID],
		[ProcessID],
		[ParameterDescription],
		[HelpText],
		[ParameterValue],
		[UxFieldTypeID],
		[UxEditableYN],
		[UxHelpUrl],
		[UxSelectionSource],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_SystemParameter]
	) sub
GO
