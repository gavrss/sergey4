SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[CashFlow_Setup] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[Account_MemberKey_Destination],
	[sub].[Account_MemberKey_Source],
	[sub].[CalculationTypeID],
	[sub].[Sign],
	[sub].[SortOrder],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[Account_MemberKey_Destination],
		[Account_MemberKey_Source],
		[CalculationTypeID],
		[Sign],
		[SortOrder],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[CashFlow_Setup]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[Account_MemberKey_Destination],
		[Account_MemberKey_Source],
		[CalculationTypeID],
		[Sign],
		[SortOrder],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_CashFlow_Setup]
	) sub
GO
