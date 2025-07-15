CREATE TABLE [dbo].[@Template_BR03_Rule_Allocation_Row]
(
[Comment] [nvarchar] (1024) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[Rule_AllocationID] [int] NOT NULL,
[Rule_Allocation_RowID] [int] NOT NULL CONSTRAINT [DF_BR03_Rule_Allocation_Row_Rule_Allocation_RowID] DEFAULT ((0)),
[MultiDimSetting] [nvarchar] (4000) NULL,
[CrossEntityYN] [bit] NOT NULL CONSTRAINT [DF_BR03_Rule_Allocation_Row_CrossEntityYN] DEFAULT ((0)),
[BaseRow] [nvarchar] (10) NOT NULL,
[Factor] [float] NOT NULL,
[Sign] [int] NOT NULL,
[InheritedFrom] [int] NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_BR03_Rule_Allocation_Row_SortOrder] DEFAULT ((0)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_BR03_Rule_Allocation_Row_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR03_Rule_Allocation_Row_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[@Template_BR03_Rule_Allocation_Row] ADD CONSTRAINT [PK_BR03_Rule_Allocation_Row] PRIMARY KEY CLUSTERED ([Rule_AllocationID], [Rule_Allocation_RowID])
GO
ALTER TABLE [dbo].[@Template_BR03_Rule_Allocation_Row] ADD CONSTRAINT [FK_BR03_Rule_Allocation_Row_BusinessRule] FOREIGN KEY ([BusinessRuleID]) REFERENCES [dbo].[@Template_BusinessRule] ([BusinessRuleID])
GO
