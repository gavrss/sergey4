CREATE TABLE [dbo].[@Template_Customer]
(
[CustomerID] [int] NOT NULL,
[CustomerName] [nvarchar] (50) NOT NULL,
[CustomerDescription] [nvarchar] (255) NOT NULL,
[CompanyTypeID] [int] NOT NULL CONSTRAINT [DF_@Template_Customer_CompanyTypeID] DEFAULT ((0)),
[ProductKey] [nvarchar] (17) NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Customer_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Customer_Upd]
	ON [dbo].[@Template_Customer]

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
		[@Template_Customer] C
		INNER JOIN Inserted I ON	
			I.CustomerID = C.CustomerID
GO
ALTER TABLE [dbo].[@Template_Customer] ADD CONSTRAINT [PK_Customer] PRIMARY KEY CLUSTERED ([CustomerID])
GO
ALTER TABLE [dbo].[@Template_Customer] ADD CONSTRAINT [FK_@Template_Customer_CompanyType] FOREIGN KEY ([CompanyTypeID]) REFERENCES [dbo].[CompanyType] ([CompanyTypeID])
GO
