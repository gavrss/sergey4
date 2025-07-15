CREATE TABLE [dbo].[DefaultMemberSource]
(
[DefaultMemberSourceID] [int] NOT NULL,
[Description] [nvarchar] (100) NOT NULL,
[SourceTable] [nvarchar] (100) NOT NULL
)
GO
ALTER TABLE [dbo].[DefaultMemberSource] ADD CONSTRAINT [PK_DefaultMemberSource] PRIMARY KEY CLUSTERED ([DefaultMemberSourceID])
GO
