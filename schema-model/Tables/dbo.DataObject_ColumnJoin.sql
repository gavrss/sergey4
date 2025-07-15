CREATE TABLE [dbo].[DataObject_ColumnJoin]
(
[TableName] [nvarchar] (100) NOT NULL,
[ColumnName] [nvarchar] (100) NOT NULL,
[DefaultValue] [nvarchar] (100) NULL,
[SourceTableName] [nvarchar] (100) NOT NULL,
[SourceColumnName] [nvarchar] (100) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DataObject_ColumnJoin_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DataObject_ColumnJoin_Upd]
	ON [dbo].[DataObject_ColumnJoin]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DOCJ
	SET
		[Version] = @Version
	FROM
		[DataObject_ColumnJoin] DOCJ
		INNER JOIN Inserted I ON	
			I.TableName = DOCJ.TableName AND
			I.ColumnName = DOCJ.ColumnName
GO
ALTER TABLE [dbo].[DataObject_ColumnJoin] ADD CONSTRAINT [PK_DataObject_ColumnJoin] PRIMARY KEY CLUSTERED ([TableName], [ColumnName])
GO
