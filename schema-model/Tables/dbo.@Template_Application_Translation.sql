CREATE TABLE [dbo].[@Template_Application_Translation]
(
[InstanceID] [int] NOT NULL,
[ApplicationID] [int] NOT NULL,
[TranslationID] [int] NOT NULL CONSTRAINT [DF_Application_Translation_TranslationID] DEFAULT ((0)),
[LanguageID] [int] NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Application_Translation_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Application_Translation_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Application_Translation_Upd]
	ON [dbo].[@Template_Application_Translation]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100),
		@ApplicationID int,
		@TranslationID int,
		@TranslationID_Max int
					
--Version
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)

	UPDATE AT
	SET
		[Version] = @Version
	FROM
		[@Template_Application_Translation] AT
		INNER JOIN Inserted I ON I.ApplicationID = AT.ApplicationID AND I.TranslationID = AT.TranslationID

--TranslationID
	SELECT
		@ApplicationID = ApplicationID,
		@TranslationID = TranslationID
	FROM
		Inserted

	SELECT
		@TranslationID_Max = MAX(TranslationID)
	FROM
		[@Template_Application_Translation]
	WHERE
		ApplicationID = @ApplicationID

	IF @TranslationID = 0
		UPDATE AT
		SET
			[TranslationID] = @TranslationID_Max + 1
		FROM
			[@Template_Application_Translation] AT
			INNER JOIN Inserted I ON I.ApplicationID = AT.ApplicationID AND I.TranslationID = AT.TranslationID
GO
ALTER TABLE [dbo].[@Template_Application_Translation] ADD CONSTRAINT [PK_Application_Translation] PRIMARY KEY CLUSTERED ([ApplicationID], [TranslationID])
GO
ALTER TABLE [dbo].[@Template_Application_Translation] ADD CONSTRAINT [FK_Application_Translation_Application] FOREIGN KEY ([ApplicationID]) REFERENCES [dbo].[@Template_Application] ([ApplicationID])
GO
ALTER TABLE [dbo].[@Template_Application_Translation] ADD CONSTRAINT [FK_Application_Translation_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_Application_Translation] ADD CONSTRAINT [FK_Application_Translation_Language] FOREIGN KEY ([LanguageID]) REFERENCES [dbo].[Language] ([LanguageID])
GO
