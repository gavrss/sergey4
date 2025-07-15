CREATE TABLE [dbo].[UserLicenseType]
(
[UserLicenseTypeID] [int] NOT NULL IDENTITY(1001, 1),
[UserLicenseTypeName] [nvarchar] (100) NOT NULL,
[SecurityLevelBM] [int] NOT NULL CONSTRAINT [DF_UserLicenseType_SecurityLevelBM] DEFAULT ((0)),
[CallistoRestriction] [nvarchar] (50) NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_UserLicenseType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[UserLicenseType_Upd]
	ON [dbo].[UserLicenseType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE ULT
	SET
		[Version] = @Version
	FROM
		[UserLicenseType] ULT
		INNER JOIN Inserted I ON	
			I.UserLicenseTypeID = ULT.UserLicenseTypeID
GO
ALTER TABLE [dbo].[UserLicenseType] ADD CONSTRAINT [PK_UserLicenseType] PRIMARY KEY CLUSTERED ([UserLicenseTypeID])
GO
