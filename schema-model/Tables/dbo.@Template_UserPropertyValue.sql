CREATE TABLE [dbo].[@Template_UserPropertyValue]
(
[InstanceID] [int] NOT NULL,
[UserID] [int] NOT NULL,
[UserPropertyTypeID] [int] NOT NULL,
[UserPropertyValue] [nvarchar] (100) NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_UserPropertyValue_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_UserPropertyValue_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[UserPropertyValue_Upd]
	ON [dbo].[@Template_UserPropertyValue]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE UPV
	SET
		[Version] = @Version
	FROM
		[@Template_UserPropertyValue] UPV
		INNER JOIN Inserted I ON	
			I.UserID = UPV.UserID AND
			I.UserPropertyTypeID = UPV.UserPropertyTypeID
GO
ALTER TABLE [dbo].[@Template_UserPropertyValue] ADD CONSTRAINT [PK_UserPropertyValue] PRIMARY KEY CLUSTERED ([UserID], [UserPropertyTypeID])
GO
ALTER TABLE [dbo].[@Template_UserPropertyValue] ADD CONSTRAINT [FK_UserPropertyValue_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_UserPropertyValue] ADD CONSTRAINT [FK_UserPropertyValue_User] FOREIGN KEY ([UserID]) REFERENCES [dbo].[@Template_User] ([UserID])
GO
ALTER TABLE [dbo].[@Template_UserPropertyValue] ADD CONSTRAINT [FK_UserPropertyValue_UserPropertyType] FOREIGN KEY ([UserPropertyTypeID]) REFERENCES [dbo].[@Template_UserPropertyType] ([UserPropertyTypeID])
GO
