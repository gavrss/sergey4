CREATE TABLE [dbo].[@Template_Data_DimensionMember]
(
[InstanceID] [int] NOT NULL,
[DataClassID] [int] NOT NULL,
[DataRowID] [bigint] NOT NULL,
[DimensionID] [int] NOT NULL CONSTRAINT [DF_Data_DimensionMember_DimensionID] DEFAULT ((0)),
[MemberKey] [nvarchar] (100) NOT NULL,
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_Data_DimensionMember_Inserted] DEFAULT (getdate()),
[InsertedBy] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Data_DimensionMember_InsertedBy] DEFAULT (suser_name())
)
GO
ALTER TABLE [dbo].[@Template_Data_DimensionMember] ADD CONSTRAINT [PK_Data_DimensionMember_1] PRIMARY KEY CLUSTERED ([DataClassID], [DataRowID], [DimensionID])
GO
ALTER TABLE [dbo].[@Template_Data_DimensionMember] ADD CONSTRAINT [FK_Data_DimensionMember_DataRow] FOREIGN KEY ([DataRowID]) REFERENCES [dbo].[@Template_DataRow] ([DataRowID])
GO
ALTER TABLE [dbo].[@Template_Data_DimensionMember] ADD CONSTRAINT [FK_Data_DimensionMember_DimensionMember] FOREIGN KEY ([InstanceID], [DimensionID], [MemberKey]) REFERENCES [dbo].[@Template_DimensionMember] ([InstanceID], [DimensionID], [MemberKey])
GO
ALTER TABLE [dbo].[@Template_Data_DimensionMember] ADD CONSTRAINT [FK_Data_DimensionMember_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
