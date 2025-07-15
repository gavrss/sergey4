CREATE TABLE [dbo].[@Template_UserPropertyType]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_UserPropertyType_InstanceID] DEFAULT ((0)),
[UserPropertyTypeID] [int] NOT NULL,
[UserPropertyTypeName] [nvarchar] (100) NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_UserPropertyType_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_UserPropertyType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[UserPropertyType_Upd]
	ON [dbo].[@Template_UserPropertyType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE UPT
	SET
		[Version] = @Version
	FROM
		[@Template_UserPropertyType] UPT
		INNER JOIN Inserted I ON	
			I.UserPropertyTypeID = UPT.UserPropertyTypeID
GO
ALTER TABLE [dbo].[@Template_UserPropertyType] ADD CONSTRAINT [PK_UserPropertyType] PRIMARY KEY CLUSTERED ([UserPropertyTypeID])
GO
ALTER TABLE [dbo].[@Template_UserPropertyType] ADD CONSTRAINT [FK_UserPropertyType_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
