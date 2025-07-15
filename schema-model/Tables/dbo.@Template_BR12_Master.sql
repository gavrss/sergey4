CREATE TABLE [dbo].[@Template_BR12_Master]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[Comment] [nvarchar] (1024) NULL,
[DataClassID] [int] NOT NULL,
[DimensionID] [int] NOT NULL,
[InheritedFrom] [int] NULL,
[DeletedID] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_BR12_Master_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[@Template_BR12_Master] ADD CONSTRAINT [PK_@Template_BR12_Master] PRIMARY KEY CLUSTERED ([BusinessRuleID])
GO
