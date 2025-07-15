CREATE TABLE [dbo].[@Template_BR12_Step]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[BR12_StepID] [int] NOT NULL,
[Comment] [nvarchar] (1024) NULL,
[MemberKey] [nvarchar] (100) NOT NULL,
[DimensionFilter] [nvarchar] (4000) NULL,
[SortOrder] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_BR12_Step_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[@Template_BR12_Step] ADD CONSTRAINT [PK_@Template_BR12_Step] PRIMARY KEY CLUSTERED ([BusinessRuleID], [BR12_StepID])
GO
