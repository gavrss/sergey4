CREATE TABLE [dbo].[@Template_SqlSource_Model_FACT]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_SqlSource_Model_FACT_InstanceID] DEFAULT ((0)),
[Comment] [nvarchar] (255) NULL,
[DimensionID] [int] NOT NULL,
[SourceTypeBM] [int] NOT NULL,
[RevisionBM] [int] NOT NULL CONSTRAINT [DF_SqlSource_Model_FACT_RevisionBM] DEFAULT ((15)),
[ModelBM] [int] NOT NULL,
[LinkedBM] [int] NOT NULL CONSTRAINT [DF_SqlSource_Model_FACT_LinkedBM] DEFAULT ((3)),
[SequenceBM] [int] NOT NULL,
[Variance] [nvarchar] (50) NOT NULL CONSTRAINT [DF_SqlSource_Model_FACT_Variance] DEFAULT (''),
[GroupByYN] [bit] NOT NULL CONSTRAINT [DF_SqlSource_Model_FACT_GroupByYN] DEFAULT ((0)),
[ReplaceTextYN] [bit] NOT NULL CONSTRAINT [DF_SqlSource_Model_FACT_ReplaceTextYN] DEFAULT ((0)),
[SourceString] [nvarchar] (max) NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_SqlSource_Model_FACT_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SqlSource_Model_FACT_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SqlSource_Model_FACT_Upd]
	ON [dbo].[@Template_SqlSource_Model_FACT]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SSMF
	SET
		[Version] = @Version
	FROM
		[@Template_SqlSource_Model_FACT] SSMF
		INNER JOIN Inserted I ON	
			I.DimensionID = SSMF.DimensionID AND
			I.SourceTypeBM = SSMF.SourceTypeBM AND
			I.RevisionBM = SSMF.RevisionBM AND
			I.ModelBM = SSMF.ModelBM AND
			I.LinkedBM = SSMF.LinkedBM AND
			I.SequenceBM = SSMF.SequenceBM AND
			I.Variance = SSMF.Variance

GO
ALTER TABLE [dbo].[@Template_SqlSource_Model_FACT] ADD CONSTRAINT [PK_SqlSource_Model_FACT] PRIMARY KEY CLUSTERED ([DimensionID], [SourceTypeBM], [RevisionBM], [ModelBM], [LinkedBM], [SequenceBM], [Variance])
GO
ALTER TABLE [dbo].[@Template_SqlSource_Model_FACT] ADD CONSTRAINT [FK_SqlSource_Model_FACT_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'0 = Value, 100 = FROM clause, 200 = WHERE clause', 'SCHEMA', N'dbo', 'TABLE', N'@Template_SqlSource_Model_FACT', 'COLUMN', N'DimensionID'
GO
EXEC sp_addextendedproperty N'MS_Description', N'1 = Not linked ETL, 2 = Linked ETL', 'SCHEMA', N'dbo', 'TABLE', N'@Template_SqlSource_Model_FACT', 'COLUMN', N'LinkedBM'
GO
