CREATE TABLE [dbo].[@Template_EntityPropertyType]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_EntityPropertyType_InstanceID] DEFAULT ((0)),
[EntityPropertyTypeID] [int] NOT NULL,
[EntityPropertyTypeName] [nvarchar] (100) NOT NULL,
[EntityPropertyTypeDescription] [nvarchar] (255) NULL,
[SourceTypeBM] [int] NOT NULL CONSTRAINT [DF_@Template_EntityPropertyType_SourceTypeBM] DEFAULT ((0)),
[MandatoryYN] [bit] NOT NULL CONSTRAINT [DF_@Template_EntityPropertyType_MandatoryYN] DEFAULT ((0)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_EntityPropertyType_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_EntityPropertyType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[EntityPropertyType_Upd]
	ON [dbo].[@Template_EntityPropertyType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE EPT
	SET
		[Version] = @Version
	FROM
		[@Template_EntityPropertyType] EPT
		INNER JOIN Inserted I ON	
			I.EntityPropertyTypeID = EPT.EntityPropertyTypeID
GO
ALTER TABLE [dbo].[@Template_EntityPropertyType] ADD CONSTRAINT [PK_EntityPropertyType] PRIMARY KEY CLUSTERED ([EntityPropertyTypeID])
GO
ALTER TABLE [dbo].[@Template_EntityPropertyType] ADD CONSTRAINT [FK_EntityPropertyType_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
