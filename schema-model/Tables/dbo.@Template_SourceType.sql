CREATE TABLE [dbo].[@Template_SourceType]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF__@Template__Insta__7A06D39C] DEFAULT ((0)),
[VersionID] [int] NOT NULL CONSTRAINT [DF__@Template__Versi__7AFAF7D5] DEFAULT ((0)),
[SourceTypeID] [int] NOT NULL IDENTITY(1001, 1),
[SourceTypeName] [nvarchar] (50) NOT NULL,
[SourceTypeDescription] [nvarchar] (255) NOT NULL,
[SourceTypeBM] [int] NOT NULL CONSTRAINT [DF_Template_SourceType_SourceTypeBM] DEFAULT ((0)),
[SourceTypeFamilyID] [int] NOT NULL CONSTRAINT [DF_Template_SourceType_SourceTypeFamilyID] DEFAULT ((0)),
[SourceDBTypeID] [int] NOT NULL CONSTRAINT [DF_Template_SourceType_SourceDBTypeID] DEFAULT ((1)),
[Owner] [nvarchar] (10) NOT NULL CONSTRAINT [DF_Template_SourceType_Owner] DEFAULT (N'dbo'),
[BrandBM] [int] NOT NULL CONSTRAINT [DF_Template_SourceType_BrandBM] DEFAULT ((0)),
[Introduced] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Template_SourceType_Introduced] DEFAULT ((1.2)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Template_SourceType_SelectYN] DEFAULT ((1)),
[SortOrder] [int] NOT NULL CONSTRAINT [DF_Template_SourceType_SortOrder] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Template_SourceType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE TRIGGER [dbo].[SourceType_Upd]
	ON [dbo].[@Template_SourceType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN BIT,
		@Version NVARCHAR(100),
		@DatabaseName NVARCHAR(100)
					
	SET @DatabaseName = DB_NAME()
	
	IF @DatabaseName = 'pcINTEGRATOR'
		BEGIN
			EXEC [pcINTEGRATOR].dbo.[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

			IF @DevYN = 0
				SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(NVARCHAR(10), GETDATE(), 112)
					
			UPDATE S
			SET
				[Version] = @Version
			FROM
				[@Template_SourceType] S
				INNER JOIN Inserted I ON	
					I.SourceTypeID = S.SourceTypeID
		END
GO
ALTER TABLE [dbo].[@Template_SourceType] ADD CONSTRAINT [PK_SourceType] PRIMARY KEY CLUSTERED ([SourceTypeID])
GO
ALTER TABLE [dbo].[@Template_SourceType] ADD CONSTRAINT [FK_Template_SourceType_SourceDBType] FOREIGN KEY ([SourceDBTypeID]) REFERENCES [dbo].[SourceDBType] ([SourceDBTypeID])
GO
ALTER TABLE [dbo].[@Template_SourceType] ADD CONSTRAINT [FK_Template_SourceType_SourceTypeFamily] FOREIGN KEY ([SourceTypeFamilyID]) REFERENCES [dbo].[SourceTypeFamily] ([SourceTypeFamilyID])
GO
