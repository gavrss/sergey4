CREATE TABLE [dbo].[@Template_MappedMemberKey]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[DimensionID] [int] NOT NULL,
[Entity_MemberKey] [nvarchar] (50) NOT NULL,
[MemberKeyFrom] [nvarchar] (100) NOT NULL,
[MemberKeyTo] [nvarchar] (100) NOT NULL,
[MappingTypeID] [int] NOT NULL CONSTRAINT [DF_MappedMemberKey_MappingTypeID] DEFAULT ((2)),
[MappedMemberKey] [nvarchar] (100) NULL,
[MappedDescription] [nvarchar] (255) NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_MappedMemberKey_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NULL
)
GO
ALTER TABLE [dbo].[@Template_MappedMemberKey] ADD CONSTRAINT [PK_MappedMemberKey] PRIMARY KEY CLUSTERED ([InstanceID], [VersionID], [DimensionID], [Entity_MemberKey], [MemberKeyFrom])
GO
EXEC sp_addextendedproperty N'MS_Description', N'1 = MemberKey PreFixed with Entity, 2 = MemberKey Suffixed with Entity, 3 = Map to MappedMemberKey', 'SCHEMA', N'dbo', 'TABLE', N'@Template_MappedMemberKey', 'COLUMN', N'MappingTypeID'
GO
