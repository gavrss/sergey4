CREATE TABLE [dbo].[Table]
(
[TableID] [int] NOT NULL IDENTITY(1001, 1),
[TableName] [nvarchar] (100) NOT NULL,
[LabelYN] [bit] NOT NULL CONSTRAINT [DF_Table_LabelYN] DEFAULT ((1)),
[SortOrderYN] [bit] NOT NULL CONSTRAINT [DF_Table_SortOrderYN] DEFAULT ((1)),
[ModelBM] [nchar] (10) NOT NULL CONSTRAINT [DF_Table_ModelBM] DEFAULT ((0)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Table_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Table_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Table_Upd]
	ON [dbo].[Table]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE T
	SET
		[Version] = @Version
	FROM
		[Table] T
		INNER JOIN Inserted I ON	
			I.TableID = T.TableID


GO
ALTER TABLE [dbo].[Table] ADD CONSTRAINT [PK_Table] PRIMARY KEY CLUSTERED ([TableID])
GO
