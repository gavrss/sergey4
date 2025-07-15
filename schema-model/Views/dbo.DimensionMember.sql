SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[DimensionMember] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[DimensionID],
	[sub].[MemberKey],
	[sub].[MemberID],
	[sub].[MemberDescription],
	[sub].[HelpText],
	[sub].[NodeTypeBM],
	[sub].[SBZ],
	[sub].[Source],
	[sub].[Synchronized],
	[sub].[Level],
	[sub].[SortOrder],
	[sub].[ParentMemberID],
	[sub].[Parent],
	[sub].[Version],
	[sub].[MemberCounter],
	[sub].[Reference]
FROM
	(
	SELECT
		[InstanceID],
		[DimensionID],
		[MemberKey],
		[MemberID],
		[MemberDescription],
		[HelpText],
		[NodeTypeBM],
		[SBZ],
		[Source],
		[Synchronized],
		[Level],
		[SortOrder],
		[ParentMemberID],
		[Parent],
		[Version],
		[MemberCounter],
		[Reference]
	FROM
		[pcINTEGRATOR_Data].[dbo].[DimensionMember]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[DimensionID],
		[MemberKey],
		[MemberID],
		[MemberDescription],
		[HelpText],
		[NodeTypeBM],
		[SBZ],
		[Source],
		[Synchronized],
		[Level],
		[SortOrder],
		[ParentMemberID],
		[Parent],
		[Version],
		[MemberCounter],
		[Reference]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_DimensionMember]
	) sub
GO
