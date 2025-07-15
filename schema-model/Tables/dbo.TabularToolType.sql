CREATE TABLE [dbo].[TabularToolType]
(
[TabularToolTypeID] [int] NOT NULL,
[TabularToolTypeName] [nvarchar] (50) NOT NULL,
[FileExtension] [nvarchar] (10) NOT NULL,
[ContentType] [nvarchar] (100) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_TabularToolType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[TabularToolType_Upd]
	ON [dbo].[TabularToolType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE TTT
	SET
		[Version] = @Version
	FROM
		[TabularToolType] TTT
		INNER JOIN Inserted I ON	
			I.TabularToolTypeID = TTT.TabularToolTypeID
GO
ALTER TABLE [dbo].[TabularToolType] ADD CONSTRAINT [PK_TabularToolType] PRIMARY KEY CLUSTERED ([TabularToolTypeID])
GO
