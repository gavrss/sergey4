SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[MemberSelection] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[DataClassID],
	[sub].[DimensionID],
	[sub].[Label],
	[sub].[SequenceBM],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[DataClassID],
		[DimensionID],
		[Label],
		[SequenceBM],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[MemberSelection]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[DataClassID],
		[DimensionID],
		[Label],
		[SequenceBM],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_MemberSelection]
	) sub
GO
