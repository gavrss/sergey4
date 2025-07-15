CREATE TABLE [dbo].[TimeType]
(
[TimeTypeBM] [int] NOT NULL,
[TimeTypeName] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_TimeType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[TimeType_Upd]
	ON [dbo].[TimeType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE TT
	SET
		[Version] = @Version
	FROM
		[TimeType] TT
		INNER JOIN Inserted I ON	
			I.TimeTypeBM = TT.TimeTypeBM



GO
ALTER TABLE [dbo].[TimeType] ADD CONSTRAINT [PK_TimeType] PRIMARY KEY CLUSTERED ([TimeTypeBM])
GO
