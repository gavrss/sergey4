CREATE TABLE [dbo].[@Template_DimensionType]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_DimensionType_InstanceID] DEFAULT ((0)),
[DimensionTypeID] [int] NOT NULL,
[DimensionTypeName] [nvarchar] (50) NOT NULL,
[AS_DimensionTypeName] [nvarchar] (50) NULL,
[DimensionTypeDescription] [nvarchar] (255) NOT NULL,
[ExtensionYN] [bit] NOT NULL CONSTRAINT [DF_DimensionType_ExtensionYN] DEFAULT ((1)),
[DimensionTypeGroupID] [int] NOT NULL CONSTRAINT [DF_DimensionType_DimensionTypeGroupID] DEFAULT ((1)),
[SecuredYN] [bit] NOT NULL CONSTRAINT [DF_DimensionType_SecuredYN] DEFAULT ((0)),
[MappingEnabledYN] [bit] NOT NULL CONSTRAINT [DF_DimensionType_MappingEnabledYN] DEFAULT ((0)),
[DefaultMappingTypeID] [int] NOT NULL CONSTRAINT [DF_DimensionType_DefaultMappingTypeID] DEFAULT ((0)),
[ReplaceTextEnabledYN] [bit] NOT NULL CONSTRAINT [DF_DimensionType_ReplaceTextEnabledYN] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DimensionType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DimensionType_Upd]
	ON [dbo].[@Template_DimensionType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DT
	SET
		[Version] = @Version
	FROM
		[@Template_DimensionType] DT
		INNER JOIN Inserted I ON	
			I.DimensionTypeID = DT.DimensionTypeID
GO
ALTER TABLE [dbo].[@Template_DimensionType] ADD CONSTRAINT [PK_DimensionType] PRIMARY KEY CLUSTERED ([DimensionTypeID])
GO
ALTER TABLE [dbo].[@Template_DimensionType] ADD CONSTRAINT [FK_DimensionType_DimensionTypeGroup] FOREIGN KEY ([DimensionTypeGroupID]) REFERENCES [dbo].[DimensionTypeGroup] ([DimensionTypeGroupID])
GO
ALTER TABLE [dbo].[@Template_DimensionType] ADD CONSTRAINT [FK_DimensionType_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
