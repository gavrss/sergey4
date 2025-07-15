SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[JobStepGroup] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[JobStepGroupID],
	[sub].[JobStepGroupBM],
	[sub].[JobStepGroupName],
	[sub].[JobStepGroupDescription],
	[sub].[Version],
	[sub].[VersionID]
FROM
	(
	SELECT
		[InstanceID],
		[JobStepGroupID],
		[JobStepGroupBM],
		[JobStepGroupName],
		[JobStepGroupDescription],
		[Version],
		[VersionID]
	FROM
		[pcINTEGRATOR_Data].[dbo].[JobStepGroup]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[JobStepGroupID],
		[JobStepGroupBM],
		[JobStepGroupName],
		[JobStepGroupDescription],
		[Version],
		[VersionID]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_JobStepGroup]
	) sub
GO
