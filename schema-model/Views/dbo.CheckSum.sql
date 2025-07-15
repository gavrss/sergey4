SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [dbo].[CheckSum] AS
-- Current Version: 2.1.2.2198
-- Created: Apr  2 2025  8:34AM

SELECT 
	[sub].[InstanceID],
	[sub].[VersionID],
	[sub].[CheckSumID],
	[sub].[CheckSumName],
	[sub].[CheckSumDescription],
	[sub].[DescriptionColumns],
	[sub].[DescriptionMitigate],
	[sub].[ActionResponsible],
	[sub].[spCheckSum],
	[sub].[JiraIssueID],
	[sub].[JiraIssueStatusID],
	[sub].[ObjectGuiBehaviorBM],
	[sub].[InheritedFrom],
	[sub].[SortOrder],
	[sub].[SelectYN],
	[sub].[Version]
FROM
	(
	SELECT
		[InstanceID],
		[VersionID],
		[CheckSumID],
		[CheckSumName],
		[CheckSumDescription],
		[DescriptionColumns],
		[DescriptionMitigate],
		[ActionResponsible],
		[spCheckSum],
		[JiraIssueID],
		[JiraIssueStatusID],
		[ObjectGuiBehaviorBM],
		[InheritedFrom],
		[SortOrder],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR_Data].[dbo].[CheckSum]
	WHERE
		InstanceID NOT IN (-10, 0)

	
	UNION
	SELECT
		[InstanceID],
		[VersionID],
		[CheckSumID],
		[CheckSumName],
		[CheckSumDescription],
		[DescriptionColumns],
		[DescriptionMitigate],
		[ActionResponsible],
		[spCheckSum],
		[JiraIssueID],
		[JiraIssueStatusID],
		[ObjectGuiBehaviorBM],
		[InheritedFrom],
		[SortOrder],
		[SelectYN],
		[Version]
	FROM
		[pcINTEGRATOR].[dbo].[@Template_CheckSum]
	) sub
GO
