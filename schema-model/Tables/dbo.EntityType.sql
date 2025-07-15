CREATE TABLE [dbo].[EntityType]
(
[EntityTypeID] [int] NOT NULL,
[EntityTypeName] [nvarchar] (50) NOT NULL,
[EntityTypeDescription] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_EntityType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[EntityType_Upd]
	ON [dbo].[EntityType]

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
		[EntityType] ET
		INNER JOIN Inserted I ON	
			I.EntityTypeID = ET.EntityTypeID
GO
ALTER TABLE [dbo].[EntityType] ADD CONSTRAINT [PK_EntityType] PRIMARY KEY CLUSTERED ([EntityTypeID])
GO
