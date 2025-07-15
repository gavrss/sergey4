CREATE TABLE [dbo].[MasterDataManagement]
(
[MasterDataManagementBM] [int] NOT NULL,
[MasterDataManagementName] [nvarchar] (50) NOT NULL,
[MasterDataManagementDescription] [nvarchar] (255) NOT NULL,
[ReadOnlyYN] [bit] NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_MasterDataManagement_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[MasterDataManagement_Upd]
	ON [dbo].[MasterDataManagement]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE MDM
	SET
		[Version] = @Version
	FROM
		[MasterDataManagement] MDM
		INNER JOIN Inserted I ON	
			I.MasterDataManagementBM = MDM.MasterDataManagementBM
GO
ALTER TABLE [dbo].[MasterDataManagement] ADD CONSTRAINT [PK_MasterDataManagement] PRIMARY KEY CLUSTERED ([MasterDataManagementBM])
GO
