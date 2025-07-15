SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[Assignment_OrganizationLevel] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[AssignmentID],
	[sub].[OrganizationLevelNo],
	[sub].[OrganizationPositionID],
	[sub].[LevelInWorkflowYN],
	[sub].[ExpectedDate],
	[sub].[ActionDescription],
	[sub].[GridID],
	[sub].[Version],
	[sub].[DeletedID]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[AssignmentID],
		[OrganizationLevelNo],
		[OrganizationPositionID],
		[LevelInWorkflowYN],
		[ExpectedDate],
		[ActionDescription],
		[GridID],
		[Version],
		[DeletedID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[Assignment_OrganizationLevel]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[AssignmentID],
		[OrganizationLevelNo],
		[OrganizationPositionID],
		[LevelInWorkflowYN],
		[ExpectedDate],
		[ActionDescription],
		[GridID],
		[Version],
		[DeletedID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_Assignment_OrganizationLevel]
	) sub
GO
