CREATE TABLE [dbo].[@Template_BR03_Rule_Allocation]
(
[Comment] [nvarchar] (1024) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[Rule_AllocationID] [int] NOT NULL IDENTITY(1001, 1),
[Rule_AllocationName] [nvarchar] (50) NOT NULL,
[JournalSequence] [nvarchar] (50) NOT NULL CONSTRAINT [DF_@Template_BR03_Rule_Allocation_JournalSequence] DEFAULT (N'ALLOC'),
[Source_DataClassID] [int] NULL,
[Source_DimensionFilter] [nvarchar] (4000) NULL,
[Across_DataClassID] [int] NULL,
[Across_Member] [nvarchar] (4000) NULL,
[Across_WithinDim] [nvarchar] (4000) NULL,
[Across_Basis] [nvarchar] (4000) NULL,
[Across_Member_Default] [nvarchar] (1000) NULL,
[JournalOnlyYN] [bit] NOT NULL CONSTRAINT [DF_@Template_BR03_Rule_Allocation_JournalOnlyYN] DEFAULT ((0)),
[ModifierID] [int] NULL,
[Parameter] [float] NULL,
[StartTime] [int] NULL,
[EndTime] [int] NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_@Template_BR03_Rule_Allocation_SortOrder] DEFAULT ((0)),
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_@Template_BR03_Rule_Allocation_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_BR03_Rule_Allocation_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[@Template_BR03_Rule_Allocation] ADD CONSTRAINT [PK_BR03_Rule_Allocation] PRIMARY KEY CLUSTERED ([Rule_AllocationID])
GO
ALTER TABLE [dbo].[@Template_BR03_Rule_Allocation] ADD CONSTRAINT [FK_BR03_Rule_Allocation_BusinessRule] FOREIGN KEY ([BusinessRuleID]) REFERENCES [dbo].[@Template_BusinessRule] ([BusinessRuleID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Filter', 'SCHEMA', N'dbo', 'TABLE', N'@Template_BR03_Rule_Allocation', 'COLUMN', N'Across_Basis'
GO
EXEC sp_addextendedproperty N'MS_Description', N'DataClass used as basis for allocation', 'SCHEMA', N'dbo', 'TABLE', N'@Template_BR03_Rule_Allocation', 'COLUMN', N'Across_DataClassID'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Group By and filter', 'SCHEMA', N'dbo', 'TABLE', N'@Template_BR03_Rule_Allocation', 'COLUMN', N'Across_Member'
GO
EXEC sp_addextendedproperty N'MS_Description', N'GroupBy and in denominator', 'SCHEMA', N'dbo', 'TABLE', N'@Template_BR03_Rule_Allocation', 'COLUMN', N'Across_WithinDim'
GO
