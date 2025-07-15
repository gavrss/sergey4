CREATE TABLE [dbo].[SourceColumn]
(
[Comment] [nvarchar] (255) NULL,
[SourceTypeFamilyID] [int] NOT NULL,
[TableCode] [nvarchar] (50) NOT NULL,
[ColumnName] [nvarchar] (100) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SourceColumn_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SourceColumn_Upd]
	ON [dbo].[SourceColumn]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SC
	SET
		[Version] = @Version
	FROM
		[SourceColumn] SC
		INNER JOIN Inserted I ON	
			I.SourceTypeFamilyID = SC.SourceTypeFamilyID AND
			I.TableCode = SC.TableCode AND
			I.ColumnName = SC.ColumnName



GO
ALTER TABLE [dbo].[SourceColumn] ADD CONSTRAINT [PK_SourceColumn] PRIMARY KEY CLUSTERED ([SourceTypeFamilyID], [TableCode], [ColumnName])
GO
