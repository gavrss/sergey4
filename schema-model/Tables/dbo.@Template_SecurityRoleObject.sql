CREATE TABLE [dbo].[@Template_SecurityRoleObject]
(
[InstanceID] [int] NOT NULL,
[SecurityRoleID] [int] NOT NULL,
[ObjectID] [int] NOT NULL,
[SecurityLevelBM] [int] NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_SecurityRoleObject_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SecurityRoleObject_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SecurityRoleObject_Upd]
	ON [dbo].[@Template_SecurityRoleObject]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SRO
	SET
		[Version] = @Version
	FROM
		[@Template_SecurityRoleObject] SRO
		INNER JOIN Inserted I ON	
			I.SecurityRoleID = SRO.SecurityRoleID AND
			I.ObjectID = SRO.ObjectID
GO
ALTER TABLE [dbo].[@Template_SecurityRoleObject] ADD CONSTRAINT [PK_SecurityRoleObject] PRIMARY KEY CLUSTERED ([InstanceID], [SecurityRoleID], [ObjectID])
GO
ALTER TABLE [dbo].[@Template_SecurityRoleObject] ADD CONSTRAINT [FK_SecurityRoleObject_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_SecurityRoleObject] ADD CONSTRAINT [FK_SecurityRoleObject_Object] FOREIGN KEY ([ObjectID]) REFERENCES [dbo].[@Template_Object] ([ObjectID])
GO
ALTER TABLE [dbo].[@Template_SecurityRoleObject] ADD CONSTRAINT [FK_SecurityRoleObject_SecurityLevel] FOREIGN KEY ([SecurityLevelBM]) REFERENCES [dbo].[SecurityLevel] ([SecurityLevelBM])
GO
ALTER TABLE [dbo].[@Template_SecurityRoleObject] ADD CONSTRAINT [FK_SecurityRoleObject_SecurityRole] FOREIGN KEY ([SecurityRoleID]) REFERENCES [dbo].[@Template_SecurityRole] ([SecurityRoleID])
GO
ALTER TABLE [dbo].[@Template_SecurityRoleObject] NOCHECK CONSTRAINT [FK_SecurityRoleObject_SecurityLevel]
GO
