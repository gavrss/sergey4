CREATE TABLE [dbo].[SecurityLevel]
(
[SecurityLevelBM] [int] NOT NULL,
[SecurityLevelName] [nvarchar] (100) NOT NULL,
[CallistoAccessType] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SecurityLevel_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SecurityLevel_Upd]
	ON [dbo].[SecurityLevel]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SL
	SET
		[Version] = @Version
	FROM
		[SecurityLevel] SL
		INNER JOIN Inserted I ON	
			I.SecurityLevelBM = SL.SecurityLevelBM


GO
ALTER TABLE [dbo].[SecurityLevel] ADD CONSTRAINT [PK_SecurityLevel] PRIMARY KEY CLUSTERED ([SecurityLevelBM])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Bitmap (1, 2, 4, 8...)', 'SCHEMA', N'dbo', 'TABLE', N'SecurityLevel', 'COLUMN', N'SecurityLevelBM'
GO
