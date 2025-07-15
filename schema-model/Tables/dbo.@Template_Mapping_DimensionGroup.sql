CREATE TABLE [dbo].[@Template_Mapping_DimensionGroup]
(
[InstanceID] [int] NOT NULL,
[Comment] [nvarchar] (255) NULL,
[Mapping_DataClassID] [int] NOT NULL,
[Mapping_DimensionGroupID] [int] NOT NULL,
[Updated] [datetime] NOT NULL,
[UpdatedBy] [nvarchar] (100) NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_Mapping_DimensionGroup] ADD CONSTRAINT [PK_Mapping_DimensionGroup_1] PRIMARY KEY CLUSTERED ([Mapping_DimensionGroupID])
GO
ALTER TABLE [dbo].[@Template_Mapping_DimensionGroup] ADD CONSTRAINT [FK_Mapping_DimensionGroup_Mapping_DataClass] FOREIGN KEY ([Mapping_DataClassID]) REFERENCES [dbo].[@Template_Mapping_DataClass] ([Mapping_DataClassID])
GO
