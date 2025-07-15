CREATE TABLE [dbo].[@Template_Locale]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_Locale_InstanceID] DEFAULT ((0)),
[LocaleID] [int] NOT NULL,
[LocaleCode] [nvarchar] (50) NULL,
[LocaleName] [nvarchar] (50) NULL,
[LanguageID] [int] NULL,
[CountryID] [int] NULL,
[SelectYN] [bit] NULL
)
GO
ALTER TABLE [dbo].[@Template_Locale] ADD CONSTRAINT [PK_Locale] PRIMARY KEY CLUSTERED ([LocaleID])
GO
