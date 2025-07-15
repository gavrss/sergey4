CREATE TABLE [dbo].[SqlSource_Property_SourceType]
(
[Comment] [nvarchar] (255) NULL,
[PropertyID] [int] NOT NULL,
[SourceTypeBM] [int] NOT NULL,
[FieldName] [nvarchar] (255) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SqlSource_Property_SourceType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SqlSource_Property_SourceType_Upd]
	ON [dbo].[SqlSource_Property_SourceType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SSPST
	SET
		[Version] = @Version
	FROM
		[SqlSource_Property_SourceType] SSPST
		INNER JOIN Inserted I ON	
			I.PropertyID = SSPST.PropertyID AND
			I.SourceTypeBM = SSPST.SourceTypeBM



GO
ALTER TABLE [dbo].[SqlSource_Property_SourceType] ADD CONSTRAINT [PK_SqlSource_Property_SourceType] PRIMARY KEY CLUSTERED ([PropertyID], [SourceTypeBM])
GO
