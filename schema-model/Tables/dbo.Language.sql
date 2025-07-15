CREATE TABLE [dbo].[Language]
(
[LanguageID] [int] NOT NULL IDENTITY(1001, 1),
[LanguageCode] [nchar] (2) NOT NULL,
[LanguageName] [nvarchar] (50) NOT NULL,
[LanguageCode_ISO3] [nchar] (3) NULL,
[LanguageName_Eng] [nvarchar] (50) NULL,
[LanguageName_ISO] [nvarchar] (50) NULL,
[LanguageName_Native] [nvarchar] (50) NULL,
[LanguageCode_639-1] [nchar] (2) NULL,
[LanguageCode_639-2/T] [nchar] (3) NULL,
[LanguageCode_639-2/B] [nchar] (3) NULL,
[LanguageCode_639-3] [nvarchar] (10) NULL,
[LanguageFamily] [nvarchar] (50) NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Language_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Language_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Language_Upd]
	ON [dbo].[Language]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE L
	SET
		[Version] = @Version
	FROM
		[Language] L
		INNER JOIN Inserted I ON	
			I.LanguageID = L.LanguageID


GO
ALTER TABLE [dbo].[Language] ADD CONSTRAINT [PK_Language] PRIMARY KEY CLUSTERED ([LanguageID])
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_Language] ON [dbo].[Language] ([LanguageCode])
GO
