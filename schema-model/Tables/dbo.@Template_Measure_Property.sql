CREATE TABLE [dbo].[@Template_Measure_Property]
(
[InstanceID] [int] NOT NULL,
[MeasureID] [int] NOT NULL,
[PropertyID] [int] NOT NULL,
[Value] [nvarchar] (50) NULL
)
GO
ALTER TABLE [dbo].[@Template_Measure_Property] ADD CONSTRAINT [PK_Measure_Property_1] PRIMARY KEY CLUSTERED ([MeasureID], [PropertyID])
GO
ALTER TABLE [dbo].[@Template_Measure_Property] ADD CONSTRAINT [FK_Measure_Property_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_Measure_Property] ADD CONSTRAINT [FK_Measure_Property_Measure] FOREIGN KEY ([MeasureID]) REFERENCES [dbo].[@Template_Measure] ([MeasureID])
GO
ALTER TABLE [dbo].[@Template_Measure_Property] ADD CONSTRAINT [FK_Measure_Property_Property] FOREIGN KEY ([PropertyID]) REFERENCES [dbo].[@Template_Property] ([PropertyID])
GO
