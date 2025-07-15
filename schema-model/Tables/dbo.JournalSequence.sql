CREATE TABLE [dbo].[JournalSequence]
(
[JournalSequence] [nvarchar] (61) NOT NULL,
[Description] [nvarchar] (255) NULL,
[Source] [nchar] (10) NULL
)
GO
ALTER TABLE [dbo].[JournalSequence] ADD CONSTRAINT [PK_JournalSequence] PRIMARY KEY CLUSTERED ([JournalSequence])
GO
