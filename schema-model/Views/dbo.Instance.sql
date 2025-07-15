SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Instance] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[InstanceName],
	[sub].[InstanceDescription],
	[sub].[CustomerID],
	[sub].[FiscalYearStartMonth],
	[sub].[FiscalYearNaming],
	[sub].[ProductKey],
	[sub].[pcPortal_URL],
	[sub].[Mail_ProfileName],
	[sub].[Rows],
	[sub].[Nyc],
	[sub].[Nyu],
	[sub].[BrandID],
	[sub].[TriggerActiveYN],
	[sub].[AllowExternalAccessYN],
	[sub].[LastLogin],
	[sub].[LastLoginByUserID],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[Version],
	[sub].[StartYear],
	[sub].[AddYear],
	[sub].[InstanceShortName],
	[sub].[FiscalYearStartMonthSetYN],
	[sub].[FiscalYearNamingSetYN],
	[sub].[MultiplyYN],
	[sub].[CommercialUseYN]
FROM
	(
	SELECT
		[InstanceID],
		[InstanceName],
		[InstanceDescription],
		[CustomerID],
		[FiscalYearStartMonth],
		[FiscalYearNaming],
		[ProductKey],
		[pcPortal_URL],
		[Mail_ProfileName],
		[Rows],
		[Nyc],
		[Nyu],
		[BrandID],
		[TriggerActiveYN],
		[AllowExternalAccessYN],
		[LastLogin],
		[LastLoginByUserID],
		[InheritedFrom],
		[SelectYN],
		[Version],
		[StartYear],
		[AddYear],
		[InstanceShortName],
		[FiscalYearStartMonthSetYN],
		[FiscalYearNamingSetYN],
		[MultiplyYN],
		[CommercialUseYN]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Instance]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[InstanceName],
		[InstanceDescription],
		[CustomerID],
		[FiscalYearStartMonth],
		[FiscalYearNaming],
		[ProductKey],
		[pcPortal_URL],
		[Mail_ProfileName],
		[Rows],
		[Nyc],
		[Nyu],
		[BrandID],
		[TriggerActiveYN],
		[AllowExternalAccessYN],
		[LastLogin],
		[LastLoginByUserID],
		[InheritedFrom],
		[SelectYN],
		[Version],
		[StartYear],
		[AddYear],
		[InstanceShortName],
		[FiscalYearStartMonthSetYN],
		[FiscalYearNamingSetYN],
		[MultiplyYN],
		[CommercialUseYN]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Instance]
	) sub
GO
