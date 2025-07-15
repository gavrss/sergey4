CREATE TABLE [dbo].[wrk_Debug]
(
[DebugID] [int] NOT NULL IDENTITY(1, 1),
[ProcedureName] [nvarchar] (100) NULL,
[Comment] [nvarchar] (255) NULL,
[SQLStatement] [nvarchar] (max) NULL,
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_wrk_Debug_Inserted] DEFAULT (getdate()),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_wrk_Debug_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[wrk_Debug_Upd]
	ON [dbo].[wrk_Debug]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE wD
	SET
		[Version] = @Version
	FROM
		[wrk_Debug] wD
		INNER JOIN Inserted I ON	
			I.DebugID = wD.DebugID



GO
ALTER TABLE [dbo].[wrk_Debug] ADD CONSTRAINT [PK_wrk_Debug] PRIMARY KEY CLUSTERED ([DebugID] DESC)
GO
