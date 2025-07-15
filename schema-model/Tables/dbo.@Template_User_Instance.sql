CREATE TABLE [dbo].[@Template_User_Instance]
(
[InstanceID] [int] NOT NULL,
[UserID] [int] NOT NULL,
[ExpiryDate] [date] NULL CONSTRAINT [DF_@Template_User_Instance_ExpiryDate] DEFAULT (getdate()+(60)),
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_@Template_User_Instance_Inserted] DEFAULT (getdate()),
[InsertedBy] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_@Template_User_Instance_SelectYN] DEFAULT ((1)),
[LoginEnabledYN] [bit] NOT NULL CONSTRAINT [DF_@Template_User_Instance_LoginEnabledYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_User_Instance_Version] DEFAULT (''),
[DeletedID] [int] NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[User_Instance_Upd]
	ON [dbo].[@Template_User_Instance]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100),
		@DatabaseName nvarchar(100)
					
	SET @DatabaseName = DB_NAME()
	
	IF @DatabaseName = 'pcINTEGRATOR_Data'
		BEGIN
			EXEC [pcINTEGRATOR].dbo.[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

			IF @DevYN = 0
				SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
			UPDATE UI
			SET
				[Version] = @Version
			FROM
				[@Template_User_Instance] UI
				INNER JOIN Inserted I ON	
					I.InstanceID = UI.InstanceID AND
					I.UserID = UI.UserID
		END
GO
ALTER TABLE [dbo].[@Template_User_Instance] ADD CONSTRAINT [PK_@Template_User_Instance] PRIMARY KEY CLUSTERED ([InstanceID], [UserID])
GO
ALTER TABLE [dbo].[@Template_User_Instance] ADD CONSTRAINT [FK_@Template_User_Instance_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_User_Instance] ADD CONSTRAINT [FK_@Template_User_Instance_User] FOREIGN KEY ([UserID]) REFERENCES [dbo].[@Template_User] ([UserID])
GO
ALTER TABLE [dbo].[@Template_User_Instance] NOCHECK CONSTRAINT [FK_@Template_User_Instance_Instance]
GO
ALTER TABLE [dbo].[@Template_User_Instance] NOCHECK CONSTRAINT [FK_@Template_User_Instance_User]
GO
