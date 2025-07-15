CREATE TABLE [dbo].[@Template_Mapping_DataClass]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[Mapping_DataClassID] [int] NOT NULL,
[A_DataClassID] [int] NOT NULL,
[B_DataClassID] [int] NOT NULL,
[Updated] [datetime] NOT NULL CONSTRAINT [DF_Mapping_DataClass_Updated] DEFAULT (getdate()),
[UpdatedBy] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Mapping_DataClass_UpdatedBy] DEFAULT (suser_name())
)
GO
ALTER TABLE [dbo].[@Template_Mapping_DataClass] ADD CONSTRAINT [PK_Mapping_DataClass] PRIMARY KEY CLUSTERED ([Mapping_DataClassID])
GO
ALTER TABLE [dbo].[@Template_Mapping_DataClass] ADD CONSTRAINT [FK_Mapping_DataClass_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_Mapping_DataClass] ADD CONSTRAINT [FK_Mapping_DataClass_Version] FOREIGN KEY ([VersionID]) REFERENCES [dbo].[@Template_Version] ([VersionID])
GO
