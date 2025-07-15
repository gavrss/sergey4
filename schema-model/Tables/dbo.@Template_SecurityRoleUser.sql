CREATE TABLE [dbo].[@Template_SecurityRoleUser]
(
[InstanceID] [int] NOT NULL,
[SecurityRoleID] [int] NOT NULL,
[UserID] [int] NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_SecurityRoleGroup_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SecurityRoleUser_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SecurityRoleUser_Upd]
	ON [dbo].[@Template_SecurityRoleUser]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SRU
	SET
		[Version] = @Version
	FROM
		[@Template_SecurityRoleUser] SRU
		INNER JOIN Inserted I ON	
			I.SecurityRoleID = SRU.SecurityRoleID AND
			I.UserID = SRU.UserID
GO
ALTER TABLE [dbo].[@Template_SecurityRoleUser] ADD CONSTRAINT [PK_SecurityRoleGroup] PRIMARY KEY CLUSTERED ([InstanceID], [SecurityRoleID], [UserID])
GO
ALTER TABLE [dbo].[@Template_SecurityRoleUser] ADD CONSTRAINT [FK_SecurityRoleUser_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_SecurityRoleUser] ADD CONSTRAINT [FK_SecurityRoleUser_SecurityRole] FOREIGN KEY ([SecurityRoleID]) REFERENCES [dbo].[@Template_SecurityRole] ([SecurityRoleID])
GO
ALTER TABLE [dbo].[@Template_SecurityRoleUser] ADD CONSTRAINT [FK_SecurityRoleUser_User] FOREIGN KEY ([UserID]) REFERENCES [dbo].[@Template_User] ([UserID])
GO
