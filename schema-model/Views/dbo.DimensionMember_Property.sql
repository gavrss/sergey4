SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[DimensionMember_Property] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[DimensionID],
	[sub].[MemberKey],
	[sub].[PropertyID],
	[sub].[Value]
FROM
	(
	SELECT
		[InstanceID],
		[DimensionID],
		[MemberKey],
		[PropertyID],
		[Value]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DimensionMember_Property]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[DimensionID],
		[MemberKey],
		[PropertyID],
		[Value]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DimensionMember_Property]
	) sub
GO
