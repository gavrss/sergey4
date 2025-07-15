SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[JobList] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[JobListID],
	[sub].[JobListName],
	[sub].[JobListDescription],
	[sub].[JobStepTypeBM],
	[sub].[JobFrequencyBM],
	[sub].[JobStepGroupBM],
	[sub].[ProcessBM],
	[sub].[JobSetupStepBM],
	[sub].[JobStep_List],
	[sub].[Entity_List],
	[sub].[DelayedStart],
	[sub].[UserID],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[JobListID],
		[JobListName],
		[JobListDescription],
		[JobStepTypeBM],
		[JobFrequencyBM],
		[JobStepGroupBM],
		[ProcessBM],
		[JobSetupStepBM],
		[JobStep_List],
		[Entity_List],
		[DelayedStart],
		[UserID],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[JobList]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[JobListID],
		[JobListName],
		[JobListDescription],
		[JobStepTypeBM],
		[JobFrequencyBM],
		[JobStepGroupBM],
		[ProcessBM],
		[JobSetupStepBM],
		[JobStep_List],
		[Entity_List],
		[DelayedStart],
		[UserID],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_JobList]
	) sub
GO
