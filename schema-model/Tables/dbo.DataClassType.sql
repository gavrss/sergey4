CREATE TABLE [dbo].[DataClassType]
(
[DataClassTypeID] [int] NOT NULL,
[DataClassTypeName] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DataClassType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DataClassType_Upd]
	ON [dbo].[DataClassType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DCT
	SET
		[Version] = @Version
	FROM
		[DataClassType] DCT
		INNER JOIN Inserted I ON	
			I.DataClassTypeID = DCT.DataClassTypeID
GO
ALTER TABLE [dbo].[DataClassType] ADD CONSTRAINT [PK_DataClassType] PRIMARY KEY CLUSTERED ([DataClassTypeID])
GO
