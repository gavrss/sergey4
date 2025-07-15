CREATE TABLE [dbo].[StepXML]
(
[StepID] [int] NOT NULL,
[StepTypeBM] [int] NOT NULL,
[StepLevel] [int] NOT NULL CONSTRAINT [DF_StepXML_StepLevel] DEFAULT ((2)),
[ParamBM] [int] NOT NULL CONSTRAINT [DF_StepXML_pcINTEGRATOR_VariableBM] DEFAULT ((0)),
[Name] [nvarchar] (100) NOT NULL,
[Description] [nvarchar] (1000) NOT NULL,
[Warning] [nvarchar] (max) NULL,
[HelpUrl] [nvarchar] (100) NULL,
[FormName] [nvarchar] (50) NULL,
[FormParameter] [nvarchar] (255) NULL,
[Database] [nvarchar] (100) NOT NULL,
[Command] [nvarchar] (255) NULL,
[Introduced] [nvarchar] (50) NOT NULL,
[Omitted] [nvarchar] (50) NOT NULL CONSTRAINT [DF_StepXML_Omitted] DEFAULT (N'Never'),
[SelectCheck] [nvarchar] (1000) NULL CONSTRAINT [DF_StepXML_SelectCheck] DEFAULT (NULL),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_StepXML_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_StepXML_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[StepXML_Upd]
	ON [dbo].[StepXML]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE T
	SET
		[Version] = @Version
	FROM
		[StepXML] T
		INNER JOIN Inserted I ON	
			I.StepID = T.StepID


GO
ALTER TABLE [dbo].[StepXML] ADD CONSTRAINT [PK_StepXML] PRIMARY KEY CLUSTERED ([StepID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'1 = Pre Instance, 2 = Application, 3 = Post Instance', 'SCHEMA', N'dbo', 'TABLE', N'StepXML', 'COLUMN', N'StepLevel'
GO
