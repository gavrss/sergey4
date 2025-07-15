CREATE TABLE [dbo].[UserType]
(
[UserTypeID] [int] NOT NULL IDENTITY(1001, 1),
[UserTypeName] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_UserType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[UserType_Upd]
	ON [dbo].[UserType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE UT
	SET
		[Version] = @Version
	FROM
		[UserType] UT
		INNER JOIN Inserted I ON	
			I.UserTypeID = UT.UserTypeID


GO
ALTER TABLE [dbo].[UserType] ADD CONSTRAINT [PK_UserType] PRIMARY KEY CLUSTERED ([UserTypeID])
GO
