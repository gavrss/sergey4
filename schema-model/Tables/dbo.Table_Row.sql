CREATE TABLE [dbo].[Table_Row]
(
[Table_RowID] [int] NOT NULL IDENTITY(1, 1),
[TableID] [int] NOT NULL,
[BrandID] [int] NOT NULL CONSTRAINT [DF_Table_Row_BrandID] DEFAULT ((0)),
[ModelBM] [int] NOT NULL CONSTRAINT [DF_Table_Row_ModelBM] DEFAULT ((64)),
[Script] [nvarchar] (1000) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Table_Row_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Table_Row_Upd]
	ON [dbo].[Table_Row]

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
		[Table_Row] TP
		INNER JOIN Inserted I ON	
			I.Table_RowID = TP.Table_RowID


GO
ALTER TABLE [dbo].[Table_Row] ADD CONSTRAINT [PK_Table_Row] PRIMARY KEY CLUSTERED ([Table_RowID])
GO
