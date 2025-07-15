CREATE TABLE [dbo].[TransactionType]
(
[TransactionTypeBM] [int] NOT NULL,
[TransactionTypeName] [nvarchar] (50) NULL,
[TransactionTypeDescription] [nvarchar] (128) NULL
)
GO
ALTER TABLE [dbo].[TransactionType] ADD CONSTRAINT [PK_TransactionType] PRIMARY KEY CLUSTERED ([TransactionTypeBM])
GO
