CREATE TABLE [dbo].[@Template_Mapping_Dimension]
(
[InstanceID] [int] NOT NULL,
[Mapping_DimensionGroupID] [int] NOT NULL,
[Mapping_DimensionID] [int] NOT NULL,
[DataClassPosition] [nchar] (1) NOT NULL,
[DimensionID] [int] NOT NULL,
[DefaultYN] [bit] NOT NULL CONSTRAINT [DF_Mapping_Dimension_DefaultYN] DEFAULT ((1)),
[Updated] [datetime] NOT NULL CONSTRAINT [DF_Mapping_Dimension_Updated] DEFAULT (getdate()),
[UpdatedBy] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Mapping_Dimension_UpdatedBy] DEFAULT (suser_name())
)
GO
ALTER TABLE [dbo].[@Template_Mapping_Dimension] ADD CONSTRAINT [PK_Mapping_Dimension] PRIMARY KEY CLUSTERED ([Mapping_DimensionID])
GO
CREATE UNIQUE NONCLUSTERED INDEX [IDX_Mapping_Dimension] ON [dbo].[@Template_Mapping_Dimension] ([Mapping_DimensionGroupID], [DataClassPosition], [DimensionID])
GO
ALTER TABLE [dbo].[@Template_Mapping_Dimension] ADD CONSTRAINT [FK_Mapping_Dimension_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
ALTER TABLE [dbo].[@Template_Mapping_Dimension] ADD CONSTRAINT [FK_Mapping_Dimension_Mapping_DimensionGroup] FOREIGN KEY ([Mapping_DimensionGroupID]) REFERENCES [dbo].[@Template_Mapping_DimensionGroup] ([Mapping_DimensionGroupID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'A = Source, B = Destination', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Mapping_Dimension', 'COLUMN', N'DataClassPosition'
GO
