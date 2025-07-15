CREATE TABLE [dbo].[@Template_Command]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_Command_InstanceID] DEFAULT ((0)),
[ProcessID] [int] NOT NULL CONSTRAINT [DF_Command_ProcessID] DEFAULT ((0)),
[CommandID] [int] NOT NULL,
[CommandName] [nvarchar] (50) NOT NULL,
[CommandDescription] [nvarchar] (255) NOT NULL,
[DatabaseName] [nvarchar] (100) NULL,
[Command] [nvarchar] (255) NOT NULL CONSTRAINT [DF_Command_RunCommand] DEFAULT (''),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Command_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Command_Upd]
	ON [dbo].[@Template_Command]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE C
	SET
		[Version] = @Version
	FROM
		[@Template_Command] C
		INNER JOIN Inserted I ON	
			I.CommandID = C.CommandID
GO
ALTER TABLE [dbo].[@Template_Command] ADD CONSTRAINT [PK_Command] PRIMARY KEY CLUSTERED ([CommandID])
GO
