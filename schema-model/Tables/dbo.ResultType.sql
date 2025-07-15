CREATE TABLE [dbo].[ResultType]
(
[ResultTypeBM] [int] NOT NULL,
[ResultTypeName] [nvarchar] (50) NOT NULL,
[ResultTypeDescription] [nvarchar] (255) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_ResultType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ResultType_Upd]
	ON [dbo].[ResultType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE RT
	SET
		[Version] = @Version
	FROM
		[ResultType] RT
		INNER JOIN Inserted I ON	
			I.ResultTypeBM = RT.ResultTypeBM

GO
ALTER TABLE [dbo].[ResultType] ADD CONSTRAINT [PK_ResultType] PRIMARY KEY CLUSTERED ([ResultTypeBM])
GO
