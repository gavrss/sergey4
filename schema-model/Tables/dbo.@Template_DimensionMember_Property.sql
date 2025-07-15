CREATE TABLE [dbo].[@Template_DimensionMember_Property]
(
[InstanceID] [int] NOT NULL,
[DimensionID] [int] NOT NULL,
[MemberKey] [nvarchar] (100) NOT NULL,
[PropertyID] [int] NOT NULL,
[Value] [nvarchar] (50) NULL
)
GO
ALTER TABLE [dbo].[@Template_DimensionMember_Property] ADD CONSTRAINT [PK_DimensionMember_Property_1] PRIMARY KEY CLUSTERED ([InstanceID], [DimensionID], [MemberKey], [PropertyID])
GO
ALTER TABLE [dbo].[@Template_DimensionMember_Property] ADD CONSTRAINT [FK_DimensionMember_Property_DimensionMember] FOREIGN KEY ([InstanceID], [DimensionID], [MemberKey]) REFERENCES [dbo].[@Template_DimensionMember] ([InstanceID], [DimensionID], [MemberKey])
GO
ALTER TABLE [dbo].[@Template_DimensionMember_Property] ADD CONSTRAINT [FK_DimensionMember_Property_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_DimensionMember_Property] ADD CONSTRAINT [FK_DimensionMember_Property_Property] FOREIGN KEY ([PropertyID]) REFERENCES [dbo].[@Template_Property] ([PropertyID])
GO
