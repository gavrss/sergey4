CREATE TABLE [dbo].[@Template_UxFieldType]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_UxFieldType_InstanceID] DEFAULT ((0)),
[UxFieldTypeID] [int] NOT NULL,
[UxFieldTypeName] [nvarchar] (50) NOT NULL,
[UxFieldTypeDescription] [nvarchar] (255) NOT NULL,
[UxValidation] [nvarchar] (50) NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_UxFieldType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[UxFieldType_Upd]
	ON [dbo].[@Template_UxFieldType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE FT
	SET
		[Version] = @Version
	FROM
		[@Template_UxFieldType] FT
		INNER JOIN Inserted I ON	
			I.UxFieldTypeID = FT.UxFieldTypeID
GO
ALTER TABLE [dbo].[@Template_UxFieldType] ADD CONSTRAINT [PK_UxFieldType] PRIMARY KEY CLUSTERED ([UxFieldTypeID])
GO
