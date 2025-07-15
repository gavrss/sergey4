SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[ScenarioType] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[ScenarioTypeID],
	[sub].[ScenarioTypeName],
	[sub].[WorkflowYN],
	[sub].[FullDimensionalityYN],
	[sub].[LiveYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[ScenarioTypeID],
		[ScenarioTypeName],
		[WorkflowYN],
		[FullDimensionalityYN],
		[LiveYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[ScenarioType]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[ScenarioTypeID],
		[ScenarioTypeName],
		[WorkflowYN],
		[FullDimensionalityYN],
		[LiveYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_ScenarioType]
	) sub
GO
