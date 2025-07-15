CREATE TABLE [dbo].[@Template_UserMember]
(
[InstanceID] [int] NOT NULL,
[UserID_Group] [int] NOT NULL,
[UserID_User] [int] NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_UserGroupMember_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_UserMember_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[UserMember_Upd]
	ON [dbo].[@Template_UserMember]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE UM
	SET
		[Version] = @Version
	FROM
		[@Template_UserMember] UM
		INNER JOIN Inserted I ON	
			I.UserID_Group = UM.UserID_Group AND
			I.UserID_User = UM.UserID_User
GO
ALTER TABLE [dbo].[@Template_UserMember] ADD CONSTRAINT [PK_UserGroupMember] PRIMARY KEY CLUSTERED ([UserID_Group], [UserID_User])
GO
ALTER TABLE [dbo].[@Template_UserMember] ADD CONSTRAINT [FK_UserMember_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_UserMember] ADD CONSTRAINT [FK_UserMember_User] FOREIGN KEY ([UserID_Group]) REFERENCES [dbo].[@Template_User] ([UserID])
GO
ALTER TABLE [dbo].[@Template_UserMember] ADD CONSTRAINT [FK_UserMember_User1] FOREIGN KEY ([UserID_User]) REFERENCES [dbo].[@Template_User] ([UserID])
GO
