CREATE TABLE [dbo].[Table_Property]
(
[Comment] [nvarchar] (255) NOT NULL CONSTRAINT [DF_Table_Property_Comment] DEFAULT (''),
[TableID] [int] NOT NULL,
[PropertyID] [int] NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Table_Property_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Table_Property_Upd]
	ON [dbo].[Table_Property]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE TP
	SET
		[Version] = @Version
	FROM
		[Table_Property] TP
		INNER JOIN Inserted I ON	
			I.TableID = TP.TableID AND
			I.PropertyID = TP.PropertyID


GO
ALTER TABLE [dbo].[Table_Property] ADD CONSTRAINT [PK_Table_Property] PRIMARY KEY CLUSTERED ([TableID], [PropertyID])
GO
ALTER TABLE [dbo].[Table_Property] ADD CONSTRAINT [FK_Table_Property_Property] FOREIGN KEY ([PropertyID]) REFERENCES [dbo].[@Template_Property] ([PropertyID])
GO
ALTER TABLE [dbo].[Table_Property] ADD CONSTRAINT [FK_Table_Property_Table] FOREIGN KEY ([TableID]) REFERENCES [dbo].[Table] ([TableID])
GO
