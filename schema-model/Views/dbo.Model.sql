SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Model] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[ModelID],
	[sub].[ModelName],
	[sub].[ModelDescription],
	[sub].[ApplicationID],
	[sub].[BaseModelID],
	[sub].[ModelBM],
	[sub].[ProcessID],
	[sub].[ListSetBM],
	[sub].[TimeLevelID],
	[sub].[TimeTypeBM],
	[sub].[OptFinanceDimYN],
	[sub].[FinanceAccountYN],
	[sub].[TextSupportYN],
	[sub].[VirtualYN],
	[sub].[DynamicRule],
	[sub].[StartupWorkbook],
	[sub].[Introduced],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[ModelID],
		[ModelName],
		[ModelDescription],
		[ApplicationID],
		[BaseModelID],
		[ModelBM],
		[ProcessID],
		[ListSetBM],
		[TimeLevelID],
		[TimeTypeBM],
		[OptFinanceDimYN],
		[FinanceAccountYN],
		[TextSupportYN],
		[VirtualYN],
		[DynamicRule],
		[StartupWorkbook],
		[Introduced],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Model]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[ModelID],
		[ModelName],
		[ModelDescription],
		[ApplicationID],
		[BaseModelID],
		[ModelBM],
		[ProcessID],
		[ListSetBM],
		[TimeLevelID],
		[TimeTypeBM],
		[OptFinanceDimYN],
		[FinanceAccountYN],
		[TextSupportYN],
		[VirtualYN],
		[DynamicRule],
		[StartupWorkbook],
		[Introduced],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Model]
	) sub
GO
