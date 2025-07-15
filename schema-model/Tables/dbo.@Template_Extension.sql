CREATE TABLE [dbo].[@Template_Extension]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[ExtensionID] [int] NOT NULL,
[ExtensionName] [nvarchar] (50) NOT NULL,
[ApplicationID] [int] NOT NULL,
[ExtensionTypeID] [int] NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Extension_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Extension_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Extension_Upd]
	ON [dbo].[@Template_Extension]

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
		[@Template_Extension] C
		INNER JOIN Inserted I ON	
			I.ExtensionID = C.ExtensionID
GO
ALTER TABLE [dbo].[@Template_Extension] ADD CONSTRAINT [PK_Extension] PRIMARY KEY CLUSTERED ([ExtensionID])
GO
ALTER TABLE [dbo].[@Template_Extension] ADD CONSTRAINT [FK_Extension_Application] FOREIGN KEY ([ApplicationID]) REFERENCES [dbo].[@Template_Application] ([ApplicationID])
GO
ALTER TABLE [dbo].[@Template_Extension] ADD CONSTRAINT [FK_Extension_ExtensionType] FOREIGN KEY ([ExtensionTypeID]) REFERENCES [dbo].[ExtensionType] ([ExtensionTypeID])
GO
ALTER TABLE [dbo].[@Template_Extension] ADD CONSTRAINT [FK_Extension_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
