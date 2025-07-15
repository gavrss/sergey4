CREATE TABLE [dbo].[@Template_Mapping_DimensionMember]
(
[InstanceID] [int] NOT NULL,
[Mapping_DimensionID] [int] NOT NULL,
[RowID] [int] NOT NULL,
[MemberKey] [nvarchar] (100) NOT NULL,
[Updated] [datetime] NOT NULL CONSTRAINT [DF_Mapping_DimensionMember_Updated] DEFAULT (getdate()),
[UpdatedBy] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Mapping_DimensionMember_UpdatedBy] DEFAULT (suser_name())
)
GO
ALTER TABLE [dbo].[@Template_Mapping_DimensionMember] ADD CONSTRAINT [PK_Mapping_DimensionMember_1] PRIMARY KEY CLUSTERED ([Mapping_DimensionID], [RowID], [MemberKey])
GO
ALTER TABLE [dbo].[@Template_Mapping_DimensionMember] ADD CONSTRAINT [FK_@Template_Mapping_DimensionMember_@Template_Mapping_Dimension] FOREIGN KEY ([Mapping_DimensionID]) REFERENCES [dbo].[@Template_Mapping_Dimension] ([Mapping_DimensionID])
GO
ALTER TABLE [dbo].[@Template_Mapping_DimensionMember] ADD CONSTRAINT [FK_@Template_Mapping_DimensionMember_@Template_Mapping_DimensionRow] FOREIGN KEY ([RowID]) REFERENCES [dbo].[@Template_Mapping_DimensionRow] ([RowID])
GO
