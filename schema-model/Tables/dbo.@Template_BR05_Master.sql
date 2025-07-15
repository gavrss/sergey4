CREATE TABLE [dbo].[@Template_BR05_Master]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[Comment] [nvarchar] (1024) NULL,
[DataClassID] [int] NOT NULL,
[InterCompany_BusinessRuleID] [int] NULL,
[ByCustomerYN] [bit] NOT NULL CONSTRAINT [DF_@Template_BR05_Master_ByCustomerYN] DEFAULT ((0)),
[BySupplierYN] [bit] NOT NULL CONSTRAINT [DF_@Template_BR05_Master_BySupplierYN] DEFAULT ((0)),
[InheritedFrom] [int] NULL,
[DeletedID] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR05_Master_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[@Template_BR05_Master] ADD CONSTRAINT [PK_BR05_Master] PRIMARY KEY CLUSTERED ([BusinessRuleID])
GO
