CREATE TABLE [dbo].[@Template_Dimension]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_Dimension_InstanceID] DEFAULT ((0)),
[DimensionID] [int] NOT NULL,
[DimensionName] [nvarchar] (50) NOT NULL,
[DimensionDescription] [nvarchar] (255) NOT NULL,
[DimensionTypeID] [int] NOT NULL CONSTRAINT [DF_Dimension_DimensionTypeID] DEFAULT ((0)),
[ObjectGuiBehaviorBM] [int] NOT NULL CONSTRAINT [DF_Dimension_ObjectGuiBehaviorBM] DEFAULT ((1)),
[GenericYN] [bit] NOT NULL CONSTRAINT [DF_Dimension_GenericYN] DEFAULT ((0)),
[MultipleProcedureYN] [bit] NOT NULL CONSTRAINT [DF_Dimension_MultipleProcedureYN] DEFAULT ((0)),
[AllYN] [bit] NOT NULL CONSTRAINT [DF_Dimension_AllYN] DEFAULT ((1)),
[ReportOnlyYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Dimension_ReportOnlyYN] DEFAULT ((0)),
[HiddenMember] [nvarchar] (1000) NOT NULL CONSTRAINT [DF_Dimension_HiddenMember] DEFAULT (N'All'),
[Hierarchy] [nvarchar] (50) NULL,
[TranslationYN] [bit] NOT NULL CONSTRAINT [DF_Dimension_TranslationYN] DEFAULT ((1)),
[DefaultSelectYN] [bit] NOT NULL CONSTRAINT [DF_Dimension_DefaultSelectYN] DEFAULT ((1)),
[DefaultSetMemberKey] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_Dimension_DefaultSetMemberKey] DEFAULT (N'NONE'),
[DefaultGetMemberKey] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_Dimension_DefaultGetMemberKey] DEFAULT (N'All_'),
[DefaultGetHierarchyNo] [int] NOT NULL CONSTRAINT [DF_@Template_Dimension_DefaultGetHierarchyNo] DEFAULT ((0)),
[DefaultValue] [nvarchar] (50) NULL,
[DeleteJoinYN] [bit] NOT NULL CONSTRAINT [DF_Dimension_DeleteJoinYN] DEFAULT ((0)),
[SourceTypeBM] [int] NOT NULL CONSTRAINT [DF_Dimension_SourceTypeBM] DEFAULT ((65535)),
[MasterDimensionID] [int] NULL,
[HierarchyMasterDimensionID] [int] NULL,
[InheritedFrom] [int] NULL,
[SeedMemberID] [int] NOT NULL CONSTRAINT [DF_Dimension_SeedMemberID] DEFAULT ((1001)),
[LoadSP] [nvarchar] (50) NULL CONSTRAINT [DF_@Template_Dimension_LoadSP] DEFAULT (N'Dimension_Generic'),
[MasterDataManagementBM] [int] NOT NULL CONSTRAINT [DF_@Template_Dimension_MasterDataManagementBM] DEFAULT ((15)),
[ModelingStatusID] [int] NOT NULL CONSTRAINT [DF_Dimension_ModelingStatusID] DEFAULT ((-40)),
[ModelingComment] [nvarchar] (1024) NULL,
[Introduced] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Dimension_Version1] DEFAULT ((1.4)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Dimension_SelectYN] DEFAULT ((1)),
[DeletedID] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Dimension_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Dimension_Upd]
	ON [dbo].[@Template_Dimension]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE D
	SET
		[Version] = @Version
	FROM
		[@Template_Dimension] D
		INNER JOIN Inserted I ON	
			I.DimensionID = D.DimensionID
GO
ALTER TABLE [dbo].[@Template_Dimension] ADD CONSTRAINT [PK_Dimension] PRIMARY KEY CLUSTERED ([DimensionID])
GO
CREATE UNIQUE NONCLUSTERED INDEX [DimensionName_Unique] ON [dbo].[@Template_Dimension] ([InstanceID], [DimensionName], [DeletedID])
GO
ALTER TABLE [dbo].[@Template_Dimension] ADD CONSTRAINT [FK_@Template_Dimension_ObjectGuiBehavior] FOREIGN KEY ([ObjectGuiBehaviorBM]) REFERENCES [dbo].[ObjectGuiBehavior] ([ObjectGuiBehaviorBM])
GO
ALTER TABLE [dbo].[@Template_Dimension] ADD CONSTRAINT [FK_Dimension_DimensionType] FOREIGN KEY ([DimensionTypeID]) REFERENCES [dbo].[@Template_DimensionType] ([DimensionTypeID])
GO
ALTER TABLE [dbo].[@Template_Dimension] ADD CONSTRAINT [FK_Dimension_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_Dimension] NOCHECK CONSTRAINT [FK_@Template_Dimension_ObjectGuiBehavior]
GO
EXEC sp_addextendedproperty N'MS_Description', N'Extra hierarchy (Except the standard hierarchy with the same name name as the dimension)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Dimension', 'COLUMN', N'Hierarchy'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Used when copying members, based on DimensionID', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Dimension', 'COLUMN', N'InheritedFrom'
GO
EXEC sp_addextendedproperty N'MS_Description', N'All data and default hierarchy will be copied from the MasterDimension.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Dimension', 'COLUMN', N'MasterDimensionID'
GO
EXEC sp_addextendedproperty N'MS_Description', N'If true and SourceDBType=2; create procedure to get sourcedata.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Dimension', 'COLUMN', N'MultipleProcedureYN'
GO
