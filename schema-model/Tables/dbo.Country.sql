CREATE TABLE [dbo].[Country]
(
[CountryID] [int] NOT NULL,
[CountryCode] [nvarchar] (255) NOT NULL,
[CountryName] [nvarchar] (512) NOT NULL,
[ISO_Alpha_2] [nvarchar] (10) NULL,
[ISO_Alpha_3] [nvarchar] (10) NULL,
[ISO_Numeric] [nvarchar] (10) NULL
)
GO
ALTER TABLE [dbo].[Country] ADD CONSTRAINT [PK_Country] PRIMARY KEY CLUSTERED ([CountryID])
GO
