CREATE TABLE [dbo].[@Template_SecurityRole]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_SecurityRole_InstanceID] DEFAULT ((0)),
[SecurityRoleID] [int] NOT NULL,
[SecurityRoleName] [nvarchar] (100) NOT NULL,
[UserLicenseTypeID] [int] NOT NULL CONSTRAINT [DF_SecurityRole_UserLicenseTypeID] DEFAULT ((1)),
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_SecurityRole_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SecurityRole_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SecurityRole_Upd]
	ON [dbo].[@Template_SecurityRole]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SR
	SET
		[Version] = @Version
	FROM
		[@Template_SecurityRole] SR
		INNER JOIN Inserted I ON	
			I.SecurityRoleID = SR.SecurityRoleID
GO
ALTER TABLE [dbo].[@Template_SecurityRole] ADD CONSTRAINT [PK_SecurityRole] PRIMARY KEY CLUSTERED ([SecurityRoleID])
GO
ALTER TABLE [dbo].[@Template_SecurityRole] ADD CONSTRAINT [FK_SecurityRole_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_SecurityRole] ADD CONSTRAINT [FK_SecurityRole_UserLicenseType] FOREIGN KEY ([UserLicenseTypeID]) REFERENCES [dbo].[UserLicenseType] ([UserLicenseTypeID])
GO
