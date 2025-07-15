CREATE TABLE [dbo].[@Template_Mapping_DataClass_Filter]
(
[InstanceID] [int] NOT NULL,
[Mapping_DimensionGroupID] [int] NOT NULL,
[DataClassPosition] [nchar] (1) NOT NULL,
[DimensionID] [int] NOT NULL,
[MemberKey] [nvarchar] (100) NOT NULL,
[Updated] [datetime] NOT NULL CONSTRAINT [DF_Mapping_DataClass_Filter_Updated] DEFAULT (getdate()),
[UpdatedBy] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Mapping_DataClass_Filter_UpdatedBy] DEFAULT (suser_name())
)
GO
ALTER TABLE [dbo].[@Template_Mapping_DataClass_Filter] ADD CONSTRAINT [PK_Mapping_DataClass_Filter] PRIMARY KEY CLUSTERED ([Mapping_DimensionGroupID], [DataClassPosition], [DimensionID], [MemberKey])
GO
ALTER TABLE [dbo].[@Template_Mapping_DataClass_Filter] ADD CONSTRAINT [FK_Mapping_DataClass_Filter_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
ALTER TABLE [dbo].[@Template_Mapping_DataClass_Filter] ADD CONSTRAINT [FK_Mapping_DataClass_Filter_Mapping_DimensionGroup] FOREIGN KEY ([Mapping_DimensionGroupID]) REFERENCES [dbo].[@Template_Mapping_DimensionGroup] ([Mapping_DimensionGroupID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'A = Source, B = Destination', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Mapping_DataClass_Filter', 'COLUMN', N'DataClassPosition'
GO
