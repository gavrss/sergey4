CREATE TABLE [dbo].[@Template_Entity]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_Entity_VersionID] DEFAULT ((0)),
[SourceID] [int] NULL,
[EntityID] [int] NOT NULL,
[MemberKey] [nvarchar] (50) NOT NULL,
[EntityName] [nvarchar] (100) NOT NULL,
[EntityTypeID] [int] NOT NULL CONSTRAINT [DF_Entity_EntityTypeID] DEFAULT ((-1)),
[LegalID] [nvarchar] (50) NULL,
[LegalName] [nvarchar] (100) NULL,
[CountryID] [int] NOT NULL CONSTRAINT [DF_Entity_CountryID] DEFAULT ((-1)),
[Priority] [int] NULL,
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Entity_SelectYN] DEFAULT ((1)),
[DeletedID] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Entity_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Entity_Upd]
	ON [dbo].[@Template_Entity]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE E
	SET
		[Version] = @Version
	FROM
		[@Template_Entity] E
		INNER JOIN Inserted I ON	
			I.EntityID = E.EntityID
GO
ALTER TABLE [dbo].[@Template_Entity] ADD CONSTRAINT [PK_Entity] PRIMARY KEY CLUSTERED ([EntityID])
GO
ALTER TABLE [dbo].[@Template_Entity] ADD CONSTRAINT [FK_Entity_Country] FOREIGN KEY ([CountryID]) REFERENCES [dbo].[Country] ([CountryID])
GO
ALTER TABLE [dbo].[@Template_Entity] ADD CONSTRAINT [FK_Entity_EntityType] FOREIGN KEY ([EntityTypeID]) REFERENCES [dbo].[EntityType] ([EntityTypeID])
GO
ALTER TABLE [dbo].[@Template_Entity] ADD CONSTRAINT [FK_Entity_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
