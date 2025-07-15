CREATE TABLE [dbo].[@Template_CheckString]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[Input] [int] NOT NULL,
[StringTypeBM] [int] NOT NULL CONSTRAINT [DF_Replace_StringTypeBM] DEFAULT ((3)),
[Output] [nvarchar] (50) NOT NULL,
[Comment] [nvarchar] (100) NULL,
[ScanYN] [bit] NOT NULL CONSTRAINT [DF_CheckString_ScanYN] DEFAULT ((0)),
[ReplaceYN] [bit] NOT NULL CONSTRAINT [DF_Replace_SelectYN] DEFAULT ((1))
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[CheckString_Upd]
ON [dbo].[@Template_CheckString]
AFTER DELETE, INSERT, UPDATE 
AS 
	EXEC [pcINTEGRATOR].[dbo].[spSet_f_ReplaceString]
	EXEC [pcINTEGRATOR].[dbo].[spSet_f_ScanString]
GO
ALTER TABLE [dbo].[@Template_CheckString] ADD CONSTRAINT [PK_Replace_1] PRIMARY KEY CLUSTERED ([InstanceID], [VersionID], [Input], [StringTypeBM])
GO
EXEC sp_addextendedproperty N'MS_Description', N'1 = Code, 2 = Text, 3 = All (1+2)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_CheckString', 'COLUMN', N'StringTypeBM'
GO
