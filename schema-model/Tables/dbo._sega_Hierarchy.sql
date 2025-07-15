CREATE TABLE [dbo].[_sega_Hierarchy]
(
[MemberId] [bigint] NULL,
[MemberKey] [nvarchar] (100) NULL,
[Description] [nvarchar] (255) NULL,
[ParentMemberId] [bigint] NULL,
[Level] [int] NULL,
[NodeTypeBM] [int] NULL,
[Path] [nvarchar] (1000) NULL
)
GO
