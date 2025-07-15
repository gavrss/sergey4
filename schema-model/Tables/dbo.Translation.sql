CREATE TABLE [dbo].[Translation]
(
[BaseLanguageID] [int] NOT NULL,
[TranslatedLanguageID] [int] NOT NULL,
[ObjectTypeBM] [int] NOT NULL CONSTRAINT [DF_Translation_ObjectTypeBM] DEFAULT ((63)),
[BaseWord] [nvarchar] (256) NOT NULL,
[TranslatedWord] [nvarchar] (512) NOT NULL CONSTRAINT [DF_Translation_TranslatedWord] DEFAULT (''),
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_Translation_Inserted] DEFAULT (getdate()),
[Updated] [datetime] NOT NULL CONSTRAINT [DF_Translation_Updated] DEFAULT (getdate()),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Translation_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Translation_Upd]
	ON [dbo].[Translation]

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
		[Translation] T
		INNER JOIN Inserted I ON
			I.BaseLanguageID = T.BaseLanguageID AND	
			I.TranslatedLanguageID = T.TranslatedLanguageID AND	
			I.ObjectTypeBM = T.ObjectTypeBM AND
			I.BaseWord = T.BaseWord



GO
ALTER TABLE [dbo].[Translation] ADD CONSTRAINT [PK_Translation_1] PRIMARY KEY CLUSTERED ([BaseLanguageID], [TranslatedLanguageID], [ObjectTypeBM], [BaseWord])
GO
ALTER TABLE [dbo].[Translation] ADD CONSTRAINT [FK_Translation_Language] FOREIGN KEY ([BaseLanguageID]) REFERENCES [dbo].[Language] ([LanguageID])
GO
ALTER TABLE [dbo].[Translation] ADD CONSTRAINT [FK_Translation_Language1] FOREIGN KEY ([TranslatedLanguageID]) REFERENCES [dbo].[Language] ([LanguageID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'1 = Application term, 2 = Static member, 3 = Custom member', 'SCHEMA', N'dbo', 'TABLE', N'Translation', 'COLUMN', N'ObjectTypeBM'
GO
