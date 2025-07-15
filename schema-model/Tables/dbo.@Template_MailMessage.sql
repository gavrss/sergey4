CREATE TABLE [dbo].[@Template_MailMessage]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_MailMessage_InstanceID] DEFAULT ((0)),
[ApplicationID] [int] NOT NULL,
[UserPropertyTypeID] [int] NOT NULL,
[Subject] [nvarchar] (255) NOT NULL,
[Body] [nvarchar] (max) NOT NULL,
[Importance] [varchar] (6) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_MailMessage_Version] DEFAULT (''),
[VersionID] [int] NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[MailMessage_Upd]
	ON [dbo].[@Template_MailMessage]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE MM
	SET
		[Version] = @Version
	FROM
		[@Template_MailMessage] MM
		INNER JOIN Inserted I ON	
			I.ApplicationID = MM.ApplicationID AND
			I.UserPropertyTypeID = MM.UserPropertyTypeID

GO
ALTER TABLE [dbo].[@Template_MailMessage] ADD CONSTRAINT [PK_MailMessage] PRIMARY KEY CLUSTERED ([ApplicationID], [UserPropertyTypeID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Low, Normal or High', 'SCHEMA', N'dbo', 'TABLE', N'@Template_MailMessage', 'COLUMN', N'Importance'
GO
