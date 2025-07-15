CREATE TABLE [dbo].[@Template_Property]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_Property_InstanceID] DEFAULT ((0)),
[PropertyID] [int] NOT NULL,
[PropertyName] [nvarchar] (50) NOT NULL,
[PropertyDescription] [nvarchar] (255) NOT NULL,
[ObjectGuiBehaviorBM] [int] NOT NULL CONSTRAINT [DF_Property_ObjectGuiBehaviorBM] DEFAULT ((1)),
[DataTypeID] [int] NOT NULL,
[Size] [int] NULL,
[DependentDimensionID] [int] NULL,
[StringTypeBM] [int] NOT NULL CONSTRAINT [DF_Property_StringTypeBM] DEFAULT ((0)),
[DynamicYN] [bit] NOT NULL CONSTRAINT [DF_Property_DynamicYN] DEFAULT ((1)),
[DefaultValueTable] [nvarchar] (255) NULL,
[DefaultValueView] [nvarchar] (255) NOT NULL CONSTRAINT [DF_Property_DefaultValueView] DEFAULT ('NONE'),
[SynchronizedYN] [bit] NOT NULL CONSTRAINT [DF_Property_SynchronizedYN] DEFAULT ((1)),
[SortOrder] [int] NOT NULL CONSTRAINT [DF_Property_SortOrder] DEFAULT ((30)),
[SourceTypeBM] [int] NOT NULL CONSTRAINT [DF_Property_SourceTypeBM] DEFAULT ((65535)),
[StorageTypeBM] [int] NOT NULL CONSTRAINT [DF_@Template_Property_StorageTypeBM] DEFAULT ((7)),
[ViewPropertyYN] [bit] NOT NULL CONSTRAINT [DF_Property_ViewPropertyYN] DEFAULT ((0)),
[HierarchySortOrderYN] [bit] NOT NULL CONSTRAINT [DF_Property_HierarchySortOrderYN] DEFAULT ((0)),
[MandatoryYN] [bit] NOT NULL CONSTRAINT [DF_Property_MandatoryYN] DEFAULT ((1)),
[DefaultNodeTypeBM] [int] NOT NULL CONSTRAINT [DF_@Template_Property_NodeTypeBM] DEFAULT ((1027)),
[DefaultSelectYN] [bit] NOT NULL CONSTRAINT [DF_Property_DefaultSelectYN] DEFAULT ((1)),
[InheritedFrom] [int] NULL,
[Introduced] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Property_Introduced] DEFAULT ((2.0)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Property_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Property_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Property_Upd]
	ON [dbo].[@Template_Property]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE P
	SET
		[Version] = @Version
	FROM
		[@Template_Property] P
		INNER JOIN Inserted I ON	
			I.PropertyID = P.PropertyID
GO
ALTER TABLE [dbo].[@Template_Property] ADD CONSTRAINT [PK_Property] PRIMARY KEY CLUSTERED ([PropertyID])
GO
CREATE UNIQUE NONCLUSTERED INDEX [Property_Unique] ON [dbo].[@Template_Property] ([InstanceID], [PropertyName])
GO
ALTER TABLE [dbo].[@Template_Property] ADD CONSTRAINT [FK_Property_DataType] FOREIGN KEY ([DataTypeID]) REFERENCES [dbo].[@Template_DataType] ([DataTypeID])
GO
ALTER TABLE [dbo].[@Template_Property] ADD CONSTRAINT [FK_Property_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Default value for which level in a hierarchy the property is relevant. Can be over written in each instantiation of the property (Dimension_Property)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Property', 'COLUMN', N'DefaultNodeTypeBM'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Default value for a property if not specified in Member_Property_Value or in source view.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Property', 'COLUMN', N'DefaultValueView'
GO
EXEC sp_addextendedproperty N'MS_Description', N'If a property should be updated or not when Synchronized is set to true for a specific member.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Property', 'COLUMN', N'SynchronizedYN'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Not a property in the dimension, only available on View-level', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Property', 'COLUMN', N'ViewPropertyYN'
GO
