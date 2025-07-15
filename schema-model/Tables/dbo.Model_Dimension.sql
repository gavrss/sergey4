CREATE TABLE [dbo].[Model_Dimension]
(
[Comment] [nvarchar] (255) NOT NULL CONSTRAINT [DF_Model_Dimension_Comment] DEFAULT (''),
[ModelID] [int] NOT NULL,
[DimensionID] [int] NOT NULL,
[LinkedPropertyID] [int] NOT NULL,
[VisibilityLevelBM] [int] NOT NULL CONSTRAINT [DF_Model_Dimension_VisibilityLevelBM] DEFAULT ((1)),
[SourceTypeBM] [int] NOT NULL CONSTRAINT [DF_Model_Dimension_SourceTypeBM] DEFAULT ((65535)),
[DefaultSelectYN] [bit] NOT NULL CONSTRAINT [DF_Model_Dimension_DefaultSelectYN] DEFAULT ((1)),
[MappingEnabledYN] [bit] NOT NULL CONSTRAINT [DF_Model_Dimension_MappingEnabledYN] DEFAULT ((1)),
[Introduced] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Model_Dimension_Introduced] DEFAULT ((1.2)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Model_Dimension_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Model_Dimension_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Model_Dimension_Upd]
	ON [dbo].[Model_Dimension]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE MD
	SET
		[Version] = @Version
	FROM
		[Model_Dimension] MD
		INNER JOIN Inserted I ON	
			I.ModelID = MD.ModelID AND
			I.DimensionID = MD.DimensionID


GO
ALTER TABLE [dbo].[Model_Dimension] ADD CONSTRAINT [PK_Model_Dimension] PRIMARY KEY CLUSTERED ([ModelID], [DimensionID], [LinkedPropertyID])
GO
ALTER TABLE [dbo].[Model_Dimension] ADD CONSTRAINT [FK_Model_Dimension_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
ALTER TABLE [dbo].[Model_Dimension] ADD CONSTRAINT [FK_Model_Dimension_Model] FOREIGN KEY ([ModelID]) REFERENCES [dbo].[@Template_Model] ([ModelID])
GO
ALTER TABLE [dbo].[Model_Dimension] ADD CONSTRAINT [FK_Model_Dimension_Property] FOREIGN KEY ([LinkedPropertyID]) REFERENCES [dbo].[@Template_Property] ([PropertyID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'If selected in MappedObject, which property to join to get data in FACT-view', 'SCHEMA', N'dbo', 'TABLE', N'Model_Dimension', 'COLUMN', N'LinkedPropertyID'
GO
