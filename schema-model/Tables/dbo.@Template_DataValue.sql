CREATE TABLE [dbo].[@Template_DataValue]
(
[InstanceID] [int] NOT NULL,
[DataClassID] [int] NOT NULL,
[DataRowID] [bigint] NOT NULL,
[MeasureID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_DataValue_EnvironmentLevelID] DEFAULT ((0)),
[DataValue] [nvarchar] (100) NOT NULL,
[Updated] [datetime] NOT NULL CONSTRAINT [DF_DataValue_Updated] DEFAULT (getdate()),
[UpdatedBy] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DataValue_UpdatedBy] DEFAULT (suser_name())
)
GO
ALTER TABLE [dbo].[@Template_DataValue] ADD CONSTRAINT [PK_DataValue] PRIMARY KEY CLUSTERED ([DataRowID], [MeasureID], [VersionID])
GO
ALTER TABLE [dbo].[@Template_DataValue] ADD CONSTRAINT [FK_DataValue_DataRow] FOREIGN KEY ([DataRowID]) REFERENCES [dbo].[@Template_DataRow] ([DataRowID])
GO
ALTER TABLE [dbo].[@Template_DataValue] ADD CONSTRAINT [FK_DataValue_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_DataValue] ADD CONSTRAINT [FK_DataValue_Instance1] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_DataValue] ADD CONSTRAINT [FK_DataValue_Measure1] FOREIGN KEY ([MeasureID]) REFERENCES [dbo].[@Template_Measure] ([MeasureID])
GO
ALTER TABLE [dbo].[@Template_DataValue] ADD CONSTRAINT [FK_DataValue_Version] FOREIGN KEY ([VersionID]) REFERENCES [dbo].[@Template_Version] ([VersionID])
GO
