CREATE TABLE [dbo].[Brand]
(
[BrandID] [int] NOT NULL IDENTITY(1, 1),
[BrandName] [varchar] (50) NOT NULL,
[BrandDescription] [varchar] (100) NOT NULL,
[BrandLabel] [varchar] (50) NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Brand_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Brand_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Brand_Upd]
	ON [dbo].[Brand]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE B
	SET
		[Version] = @Version
	FROM
		[Brand] B
		INNER JOIN Inserted I ON	
			I.BrandID = B.BrandID
GO
ALTER TABLE [dbo].[Brand] ADD CONSTRAINT [PK_Brand] PRIMARY KEY CLUSTERED ([BrandID])
GO
