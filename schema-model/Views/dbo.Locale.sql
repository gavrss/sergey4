SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Locale] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[LocaleID],
	[sub].[LocaleCode],
	[sub].[LocaleName],
	[sub].[LanguageID],
	[sub].[CountryID],
	[sub].[SelectYN]
FROM
	(
	SELECT
		[InstanceID],
		[LocaleID],
		[LocaleCode],
		[LocaleName],
		[LanguageID],
		[CountryID],
		[SelectYN]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Locale]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[LocaleID],
		[LocaleCode],
		[LocaleName],
		[LanguageID],
		[CountryID],
		[SelectYN]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Locale]
	) sub
GO
