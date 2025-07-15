CREATE TABLE [dbo].[@Template_DataRow]
(
[InstanceID] [int] NOT NULL,
[DataClassID] [int] NOT NULL,
[DataRowID] [bigint] NOT NULL,
[InheritedFrom] [bigint] NULL,
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_DataRow_Inserted] DEFAULT (getdate()),
[InsertedBy] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DataRow_InsertedBy] DEFAULT (suser_name())
)
GO
ALTER TABLE [dbo].[@Template_DataRow] ADD CONSTRAINT [PK_DataRow] PRIMARY KEY CLUSTERED ([DataRowID])
GO
ALTER TABLE [dbo].[@Template_DataRow] ADD CONSTRAINT [FK_DataRow_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Based on DataRowID. Used when copying data.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_DataRow', 'COLUMN', N'InheritedFrom'
GO
