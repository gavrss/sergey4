SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[JobStep] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[Comment],
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[JobStepID],
	[sub].[JobStepTypeBM],
	[sub].[DatabaseName],
	[sub].[StoredProcedure],
	[sub].[Parameter],
	[sub].[SortOrder],
	[sub].[JobFrequencyBM],
	[sub].[JobStepGroupBM],
	[sub].[ProcessBM],
	[sub].[JobSetupStepBM],
	[sub].[InheritedFrom],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[JobStepID],
		[JobStepTypeBM],
		[DatabaseName],
		[StoredProcedure],
		[Parameter],
		[SortOrder],
		[JobFrequencyBM],
		[JobStepGroupBM],
		[ProcessBM],
		[JobSetupStepBM],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[JobStep]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[Comment],
		[InstanceID],
		[VersionID],
		[JobStepID],
		[JobStepTypeBM],
		[DatabaseName],
		[StoredProcedure],
		[Parameter],
		[SortOrder],
		[JobFrequencyBM],
		[JobStepGroupBM],
		[ProcessBM],
		[JobSetupStepBM],
		[InheritedFrom],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_JobStep]
	) sub
GO
