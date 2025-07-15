CREATE TABLE [dbo].[@Template_Mapping_DimensionRow]
(
[InstanceID] [int] NOT NULL,
[Mapping_DimensionGroupID] [int] NOT NULL,
[RowID] [int] NOT NULL,
[Updated] [datetime] NOT NULL CONSTRAINT [DF_Mapping_DimensionRow_Updated] DEFAULT (getdate()),
[UpdatedBy] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Mapping_DimensionRow_UpdatedBy] DEFAULT (suser_name())
)
GO
ALTER TABLE [dbo].[@Template_Mapping_DimensionRow] ADD CONSTRAINT [PK_@Template_Mapping_DimensionRow] PRIMARY KEY CLUSTERED ([RowID])
GO
ALTER TABLE [dbo].[@Template_Mapping_DimensionRow] ADD CONSTRAINT [FK_@Template_Mapping_DimensionRow_@Template_Mapping_DimensionGroup] FOREIGN KEY ([Mapping_DimensionGroupID]) REFERENCES [dbo].[@Template_Mapping_DimensionGroup] ([Mapping_DimensionGroupID])
GO
