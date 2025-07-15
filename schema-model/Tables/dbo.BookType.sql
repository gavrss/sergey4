CREATE TABLE [dbo].[BookType]
(
[BookTypeBM] [int] NOT NULL,
[BookTypeName] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BookType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE TRIGGER [dbo].[BookType_Upd]
	ON [dbo].[BookType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE BT
	SET
		[Version] = @Version
	FROM
		[BookType] BT
		INNER JOIN Inserted I ON	
			I.BookTypeBM = BT.BookTypeBM
GO
ALTER TABLE [dbo].[BookType] ADD CONSTRAINT [PK_BookType] PRIMARY KEY CLUSTERED ([BookTypeBM])
GO
