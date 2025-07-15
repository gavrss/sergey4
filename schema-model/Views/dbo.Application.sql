SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW [dbo].[Application] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[ApplicationID],
	[sub].[ApplicationName],
	[sub].[ApplicationDescription],
	[sub].[ApplicationServer],
	[sub].[ETLDatabase],
	[sub].[DestinationDatabase],
	[sub].[TabularServer],
	[sub].[AdminUser],
	[sub].[FiscalYearStartMonth],
	[sub].[MasterClosedMonth],
	[sub].[LanguageID],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[Version],
	[sub].[StorageTypeBM],
	[sub].[FinancialsClosedMonth],
	[sub].[ReadSecurityByOpYN],
	[sub].[EnhancedStorageYN],
	[sub].[UseCachedSourceDatabaseYN],
	[sub].[CallistoDeployAndRefreshYN]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[ApplicationID],
		[ApplicationName],
		[ApplicationDescription],
		[ApplicationServer],
		[ETLDatabase],
		[DestinationDatabase],
		[TabularServer],
		[AdminUser],
		[FiscalYearStartMonth],
		[MasterClosedMonth],
		[LanguageID],
		[InheritedFrom],
		[SelectYN],
		[Version],
		[StorageTypeBM],
		[FinancialsClosedMonth],
		[ReadSecurityByOpYN],
		[EnhancedStorageYN],
		[UseCachedSourceDatabaseYN],
		[CallistoDeployAndRefreshYN]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Application]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[ApplicationID],
		[ApplicationName],
		[ApplicationDescription],
		[ApplicationServer],
		[ETLDatabase],
		[DestinationDatabase],
		[TabularServer],
		[AdminUser],
		[FiscalYearStartMonth],
		[MasterClosedMonth],
		[LanguageID],
		[InheritedFrom],
		[SelectYN],
		[Version],
		[StorageTypeBM],
		[FinancialsClosedMonth],
		[ReadSecurityByOpYN],
		[EnhancedStorageYN],
		[UseCachedSourceDatabaseYN],
		[CallistoDeployAndRefreshYN]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Application]
	) sub
GO
