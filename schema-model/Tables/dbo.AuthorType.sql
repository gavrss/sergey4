CREATE TABLE [dbo].[AuthorType]
(
[AuthorType] [nchar] (1) NOT NULL,
[Name] [nvarchar] (50) NOT NULL,
[Description] [nvarchar] (255) NOT NULL,
[Version] [nvarchar] (100) NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[AuthorType_Upd]
	ON [dbo].[AuthorType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE CL
	SET
		[Version] = @Version
	FROM
		[AuthorType] CL
		INNER JOIN Inserted I ON	
			I.AuthorType = CL.AuthorType

GO
ALTER TABLE [dbo].[AuthorType] ADD CONSTRAINT [PK_AuthorType] PRIMARY KEY CLUSTERED ([AuthorType])
GO
