SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[AssignmentRow] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[AssignmentID],
	[sub].[DimensionID],
	[sub].[Dimension_MemberKey],
	[sub].[Dimension_MemberID],
	[sub].[DeletedID]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[AssignmentID],
		[DimensionID],
		[Dimension_MemberKey],
		[Dimension_MemberID],
		[DeletedID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[AssignmentRow]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[AssignmentID],
		[DimensionID],
		[Dimension_MemberKey],
		[Dimension_MemberID],
		[DeletedID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_AssignmentRow]
	) sub
GO
