CREATE TABLE [dbo].[@Template_BR14_Step]
(
[Comment] [nvarchar] (1024) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[BR14_StepID] [int] NOT NULL IDENTITY(1001, 1),
[ICCounterpart] [nvarchar] (100) NOT NULL,
[Method] [nvarchar] (20) NOT NULL,
[DimensionFilter] [nvarchar] (4000) NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_BR14_Step_SortOrder] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR14_Step_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[@Template_BR14_Step] ADD CONSTRAINT [PK_BR14_Step] PRIMARY KEY CLUSTERED ([BusinessRuleID], [BR14_StepID])
GO
