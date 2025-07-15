CREATE TABLE [dbo].[ChangeLog]
(
[ChangeLogID] [int] NOT NULL IDENTITY(1, 1),
[Description] [nvarchar] (1000) NOT NULL,
[TableName] [nvarchar] (100) NULL,
[DatabaseName] [nvarchar] (50) NULL,
[Version] [nvarchar] (100) NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ChangeLog_Upd]
	ON [dbo].[ChangeLog]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE CL
	SET
		[Version] = @Version
	FROM
		[ChangeLog] CL
		INNER JOIN Inserted I ON I.ChangeLogID = CL.ChangeLogID
	WHERE
		CL.[Version] = ''
GO
ALTER TABLE [dbo].[ChangeLog] ADD CONSTRAINT [PK_ChangeLog] PRIMARY KEY CLUSTERED ([ChangeLogID] DESC)
GO
