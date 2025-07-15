CREATE TABLE [dbo].[CompanyType]
(
[CompanyTypeID] [int] NOT NULL,
[CompanyTypeName] [nvarchar] (50) NOT NULL,
[CompanyTypeDescription] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_CompanyType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[CompanyType_Upd]
	ON [dbo].[CompanyType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE ET
	SET
		[Version] = @Version
	FROM
		[CompanyType] ET
		INNER JOIN Inserted I ON	
			I.CompanyTypeID = ET.CompanyTypeID
GO
ALTER TABLE [dbo].[CompanyType] ADD CONSTRAINT [PK_CompanyType] PRIMARY KEY CLUSTERED ([CompanyTypeID])
GO
