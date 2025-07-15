CREATE TABLE [dbo].[@Template_User]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_User_InstanceID] DEFAULT ((0)),
[UserID] [int] NOT NULL,
[UserName] [nvarchar] (100) NOT NULL,
[UserNameAD] [nvarchar] (100) NULL,
[UserNameDisplay] [nvarchar] (100) NULL,
[UserTypeID] [int] NOT NULL,
[UserLicenseTypeID] [int] NOT NULL CONSTRAINT [DF_User_UserLicenseTypeID] DEFAULT ((0)),
[PersonID] [int] NULL,
[LocaleID] [int] NOT NULL CONSTRAINT [DF_User_LocaleID] DEFAULT ((1)),
[LanguageID] [int] NOT NULL CONSTRAINT [DF_User_LanguageID] DEFAULT ((1)),
[ObjectGuiBehaviorBM] [int] NOT NULL CONSTRAINT [DF_User_ObjectGuiBehaviorBM] DEFAULT ((1)),
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_UserObject_SelectYN] DEFAULT ((1)),
[LoginEnabledYN] [bit] NOT NULL CONSTRAINT [DF_@Template_User_LoginEnabledYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_User_Version] DEFAULT (''),
[DeletedID] [int] NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[User_Upd]
	ON [dbo].[@Template_User]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE U
	SET
		[Version] = @Version
	FROM
		[@Template_User] U
		INNER JOIN Inserted I ON	
			I.UserID = U.UserID
GO
ALTER TABLE [dbo].[@Template_User] ADD CONSTRAINT [PK_UserID] PRIMARY KEY CLUSTERED ([UserID])
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_UserName] ON [dbo].[@Template_User] ([UserName], [DeletedID])
GO
ALTER TABLE [dbo].[@Template_User] ADD CONSTRAINT [FK_User_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_User] ADD CONSTRAINT [FK_User_UserLicenseType] FOREIGN KEY ([UserLicenseTypeID]) REFERENCES [dbo].[UserLicenseType] ([UserLicenseTypeID])
GO
ALTER TABLE [dbo].[@Template_User] ADD CONSTRAINT [FK_User_UserType] FOREIGN KEY ([UserTypeID]) REFERENCES [dbo].[UserType] ([UserTypeID])
GO
