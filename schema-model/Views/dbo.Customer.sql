SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Customer] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[CustomerID],
	[sub].[CustomerName],
	[sub].[CustomerDescription],
	[sub].[CompanyTypeID],
	[sub].[Version],
	[sub].[ProductKey]
FROM
	(
	SELECT
		[CustomerID],
		[CustomerName],
		[CustomerDescription],
		[CompanyTypeID],
		[Version],
		[ProductKey]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Customer]
	

	
	UNION
	SELECT
		[CustomerID],
		[CustomerName],
		[CustomerDescription],
		[CompanyTypeID],
		[Version],
		[ProductKey]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Customer]
	) sub
GO
