CREATE TABLE [dbo].[@Template_BR07_Master]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[Comment] [nvarchar] (1024) NULL,
[DimensionID] [int] NOT NULL,
[HierarchyNo] [int] NOT NULL,
[DeletedID] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR07_Master_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[@Template_BR07_Master] ADD CONSTRAINT [PK_BR07_Master] PRIMARY KEY CLUSTERED ([BusinessRuleID])
GO
