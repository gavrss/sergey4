CREATE TABLE [dbo].[@Template_SqlSource_Dimension]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_SqlSource_Dimension_InstanceID] DEFAULT ((0)),
[Comment] [nvarchar] (255) NOT NULL,
[DimensionID] [int] NOT NULL,
[SourceTypeBM] [int] NOT NULL,
[RevisionBM] [int] NOT NULL CONSTRAINT [DF_SqlSource_Dimension_RevisionBM] DEFAULT ((15)),
[ModelBM] [int] NOT NULL,
[PropertyID] [int] NOT NULL,
[LinkedBM] [int] NOT NULL CONSTRAINT [DF_SqlSource_Dimension_LinkedBM] DEFAULT ((3)),
[SequenceBM] [int] NOT NULL,
[SubQuery] [nvarchar] (10) NOT NULL CONSTRAINT [DF_SqlSource_Dimension_SubName] DEFAULT (''),
[Variance] [nvarchar] (50) NOT NULL CONSTRAINT [DF_SqlSource_Dimension_Variance] DEFAULT (''),
[LeafLevelYN] [bit] NOT NULL CONSTRAINT [DF_SqlSource_Dimension_LeafLevelYN] DEFAULT ((0)),
[GroupByYN] [bit] NOT NULL CONSTRAINT [DF_SqlSource_Dimension_GroupByYN] DEFAULT ((0)),
[ReplaceTextEnabledYN] [bit] NOT NULL CONSTRAINT [DF_SqlSource_Dimension_ReplaceTextYN] DEFAULT ((0)),
[SourceString] [nvarchar] (max) NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_SqlSource_Dimension_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SqlSource_Dimension_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SqlSource_Dimension_Upd]
	ON [dbo].[@Template_SqlSource_Dimension]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)

	UPDATE SSD
	SET
		[Version] = @Version
	FROM
		[@Template_SqlSource_Dimension] SSD
		INNER JOIN Inserted I ON	
			I.DimensionID = SSD.DimensionID AND
			I.SourceTypeBM = SSD.SourceTypeBM AND
			I.RevisionBM = SSD.RevisionBM AND
			I.ModelBM = SSD.ModelBM AND
			I.PropertyID = SSD.PropertyID AND
			I.LinkedBM = SSD.LinkedBM AND
			I.SequenceBM = SSD.SequenceBM AND
			I.SubQuery = SSD.SubQuery AND
			I.Variance = SSD.Variance

GO
ALTER TABLE [dbo].[@Template_SqlSource_Dimension] ADD CONSTRAINT [PK_SqlSource_Dimension] PRIMARY KEY CLUSTERED ([DimensionID], [SourceTypeBM], [RevisionBM], [ModelBM], [PropertyID], [LinkedBM], [SequenceBM], [SubQuery], [Variance])
GO
ALTER TABLE [dbo].[@Template_SqlSource_Dimension] ADD CONSTRAINT [FK_SqlSource_Dimension_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
ALTER TABLE [dbo].[@Template_SqlSource_Dimension] ADD CONSTRAINT [FK_SqlSource_Dimension_Property] FOREIGN KEY ([PropertyID]) REFERENCES [dbo].[@Template_Property] ([PropertyID])
GO
