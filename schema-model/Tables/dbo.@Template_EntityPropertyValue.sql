CREATE TABLE [dbo].[@Template_EntityPropertyValue]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_EntityPropertyValue_InstanceID] DEFAULT ((0)),
[VersionID] [int] NOT NULL,
[EntityID] [int] NOT NULL,
[EntityPropertyTypeID] [int] NOT NULL,
[EntityPropertyValue] [nvarchar] (100) NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_EntityPropertyValue_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_EntityPropertyValue_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[EntityPropertyValue_Upd]
	ON [dbo].[@Template_EntityPropertyValue]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE EPV
	SET
		[Version] = @Version
	FROM
		[@Template_EntityPropertyValue] EPV
		INNER JOIN Inserted I ON	
			I.EntityID = EPV.EntityID AND
			I.EntityPropertyTypeID = EPV.EntityPropertyTypeID
GO
ALTER TABLE [dbo].[@Template_EntityPropertyValue] ADD CONSTRAINT [PK_@Template_EntityPropertyValue] PRIMARY KEY CLUSTERED ([InstanceID], [VersionID], [EntityID], [EntityPropertyTypeID], [EntityPropertyValue])
GO
ALTER TABLE [dbo].[@Template_EntityPropertyValue] ADD CONSTRAINT [FK_EntityPropertyValue_Entity] FOREIGN KEY ([EntityID]) REFERENCES [dbo].[@Template_Entity] ([EntityID])
GO
ALTER TABLE [dbo].[@Template_EntityPropertyValue] ADD CONSTRAINT [FK_EntityPropertyValue_EntityPropertyType] FOREIGN KEY ([EntityPropertyTypeID]) REFERENCES [dbo].[@Template_EntityPropertyType] ([EntityPropertyTypeID])
GO
