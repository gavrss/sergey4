SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[WorkflowState] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[WorkflowID],
	[sub].[WorkflowStateId],
	[sub].[WorkflowStateName],
	[sub].[InheritedFrom]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[WorkflowID],
		[WorkflowStateId],
		[WorkflowStateName],
		[InheritedFrom]
	FROM
		[pcINTEGRATOR_Data].[dbo].[WorkflowState]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[WorkflowID],
		[WorkflowStateId],
		[WorkflowStateName],
		[InheritedFrom]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_WorkflowState]
	) sub
GO
