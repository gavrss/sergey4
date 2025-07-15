CREATE TABLE [dbo].[@Template_Dimension_StorageType]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_Dimension_StorageType_VersionID] DEFAULT ((0)),
[DimensionID] [int] NOT NULL,
[StorageTypeBM] [int] NOT NULL CONSTRAINT [DF_Dimension_StorageType_StorageTypeBM] DEFAULT ((0)),
[ObjectGuiBehaviorBM] [int] NOT NULL CONSTRAINT [DF_@Template_Dimension_StorageType_ObjectGuiBehaviorBM] DEFAULT ((1)),
[ReadSecurityEnabledYN] [bit] NOT NULL CONSTRAINT [DF_Dimension_StorageType_ReadSecurityEnabledYN] DEFAULT ((0)),
[MappingTypeID] [int] NOT NULL CONSTRAINT [DF_@Template_Dimension_StorageType_MappingTypeID] DEFAULT ((0)),
[NumberHierarchy] [int] NOT NULL CONSTRAINT [DF_@Template_Dimension_StorageType_NumberHierarchy] DEFAULT ((0)),
[ReplaceStringYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Dimension_StorageType_ReplaceStringYN] DEFAULT ((0)),
[DefaultSetMemberKey] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_Dimension_StorageType_DefaultSetMemberKey] DEFAULT (N'NONE'),
[DefaultGetMemberKey] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_Dimension_StorageType_DefaultGetMemberKey] DEFAULT (N'All_'),
[DefaultGetHierarchyNo] [int] NOT NULL CONSTRAINT [DF_@Template_Dimension_StorageType_DefaultGetHierarchyNo] DEFAULT ((0)),
[DimensionFilter] [nvarchar] (4000) NULL,
[ETLProcedure] [nvarchar] (255) NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Dimension_StorageType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Dimension_StorageType_Upd]
	ON [dbo].[@Template_Dimension_StorageType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DST
	SET
		[Version] = @Version
	FROM
		[@Template_Dimension_StorageType] DST
		INNER JOIN Inserted I ON	
			I.InstanceID = DST.InstanceID AND
			I.DimensionID = DST.DimensionID
GO
ALTER TABLE [dbo].[@Template_Dimension_StorageType] ADD CONSTRAINT [PK_Dimension_StorageType] PRIMARY KEY CLUSTERED ([InstanceID], [VersionID], [DimensionID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Only valid for DimensionTypeID = 27 (MultiDim)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Dimension_StorageType', 'COLUMN', N'DimensionFilter'
GO
EXEC sp_addextendedproperty N'MS_Description', N'0=Default, Label from Source; 1=Prefix, Label PreFixed with EntityCode; 2=Suffix, Label Suffixed with EntityCode; 3=Mapped, Map to MappedLabel', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Dimension_StorageType', 'COLUMN', N'MappingTypeID'
GO
EXEC sp_addextendedproperty N'MS_Description', N'0=Default, Label from Source; 1=Prefix, Label PreFixed with EntityCode; 2=Suffix, Label Suffixed with EntityCode; 3=Mapped, Map to MappedLabel', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Dimension_StorageType', 'COLUMN', N'ReplaceStringYN'
GO
