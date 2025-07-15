CREATE TABLE [dbo].[@Template_Dimension_Property]
(
[Comment] [nvarchar] (255) NOT NULL CONSTRAINT [DF_Dimension_Property_Comment] DEFAULT (''),
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_Dimension_Property_VersionID] DEFAULT ((0)),
[DimensionID] [int] NOT NULL,
[PropertyID] [int] NOT NULL,
[DependencyPrio] [int] NOT NULL CONSTRAINT [DF_@Template_Dimension_Property_DependencyPrio] DEFAULT ((0)),
[MultiDimYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Dimension_Property_MultiDimYN] DEFAULT ((0)),
[TabularYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Dimension_Property_TabularYN] DEFAULT ((1)),
[NodeTypeBM] [int] NOT NULL CONSTRAINT [DF_@Template_Dimension_Property_NodeTypeBM] DEFAULT ((1027)),
[SortOrder] [int] NOT NULL CONSTRAINT [DF_Dimension_Property_SortOrder] DEFAULT ((0)),
[Introduced] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Dimension_Property_Introduced] DEFAULT ((2.0)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Dimension_Property_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Dimension_Property_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Dimension_Property_Upd]
	ON [dbo].[@Template_Dimension_Property]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DP
	SET
		[Version] = @Version
	FROM
		[@Template_Dimension_Property] DP
		INNER JOIN Inserted I ON	
			I.DimensionID = DP.DimensionID AND
			I.PropertyID = DP.PropertyID
GO
ALTER TABLE [dbo].[@Template_Dimension_Property] ADD CONSTRAINT [PK_Dimension_Property] PRIMARY KEY CLUSTERED ([InstanceID], [VersionID], [DimensionID], [PropertyID])
GO
ALTER TABLE [dbo].[@Template_Dimension_Property] ADD CONSTRAINT [FK_Dimension_Property_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
ALTER TABLE [dbo].[@Template_Dimension_Property] ADD CONSTRAINT [FK_Dimension_Property_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_Dimension_Property] ADD CONSTRAINT [FK_Dimension_Property_Property] FOREIGN KEY ([PropertyID]) REFERENCES [dbo].[@Template_Property] ([PropertyID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Says for which level in a hierarchy the property is relevant.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Dimension_Property', 'COLUMN', N'NodeTypeBM'
GO
