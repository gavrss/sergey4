CREATE TABLE [dbo].[LogoType]
(
[Comment] [nvarchar] (255) NULL,
[TypeID] [int] NOT NULL,
[BrandID] [int] NOT NULL,
[LogoType] [varbinary] (max) NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_LogoType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[LogoType_Upd]
	ON [dbo].[LogoType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE LT
	SET
		[Version] = @Version
	FROM
		[LogoType] LT
		INNER JOIN Inserted I ON	
			I.TypeID = LT.TypeID AND
			I.BrandID = LT.BrandID



GO
ALTER TABLE [dbo].[LogoType] ADD CONSTRAINT [PK_LogoType] PRIMARY KEY CLUSTERED ([TypeID], [BrandID])
GO
