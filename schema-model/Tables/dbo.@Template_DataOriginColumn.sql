CREATE TABLE [dbo].[@Template_DataOriginColumn]
(
[InstanceID] [int] NULL,
[VersionID] [int] NULL,
[DataOriginID] [int] NULL,
[ColumnID] [int] NOT NULL IDENTITY(1001, 1),
[ColumnName] [nvarchar] (50) NOT NULL,
[ColumnOrder] [int] NULL,
[ColumnTypeID] [int] NULL,
[DestinationName] [nvarchar] (50) NULL,
[DataType] [nvarchar] (50) NULL,
[uOM] [nvarchar] (50) NULL,
[PropertyType] [nvarchar] (50) NULL,
[HierarchyLevel] [int] NULL,
[Comment] [nvarchar] (1024) NULL,
[AutoAddYN] [bit] NULL,
[DataClassYN] [bit] NULL,
[DeletedID] [int] NULL
)
GO
ALTER TABLE [dbo].[@Template_DataOriginColumn] ADD CONSTRAINT [PK_DataOriginColumn] PRIMARY KEY NONCLUSTERED ([ColumnID])
GO
ALTER TABLE [dbo].[@Template_DataOriginColumn] ADD CONSTRAINT [FK_DataOriginID] FOREIGN KEY ([DataOriginID]) REFERENCES [dbo].[@Template_DataOrigin] ([DataOriginID])
GO
