CREATE TABLE [dbo].[ProductOption]
(
[Comment] [nvarchar] (100) NOT NULL,
[ProductOptionID] [int] NOT NULL,
[ObjectTypeBM] [int] NOT NULL,
[TemplateObjectID] [int] NOT NULL
)
GO
ALTER TABLE [dbo].[ProductOption] ADD CONSTRAINT [PK_ProductOption] PRIMARY KEY CLUSTERED ([ProductOptionID], [ObjectTypeBM], [TemplateObjectID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'DataClassID, DimensionID, PropertyID defined in template tables belonging to InstanceID = 20', 'SCHEMA', N'dbo', 'TABLE', N'ProductOption', 'COLUMN', N'TemplateObjectID'
GO
