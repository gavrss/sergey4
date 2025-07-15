CREATE TABLE [dbo].[SourceTable]
(
[Comment] [nvarchar] (255) NOT NULL,
[SourceTypeFamilyID] [int] NOT NULL,
[ModelBM] [int] NOT NULL,
[TableCode] [nvarchar] (50) NOT NULL,
[DimensionID] [int] NOT NULL CONSTRAINT [DF_SourceTable_DestinationID] DEFAULT ((0)),
[TableTypeBM] [int] NOT NULL CONSTRAINT [DF_SourceTable_TableTypeBM] DEFAULT ((2)),
[LevelBM] [int] NOT NULL CONSTRAINT [DF_SourceTable_Level] DEFAULT ((1)),
[YearlyYN] [bit] NOT NULL CONSTRAINT [DF_SourceTable_YearlyYN] DEFAULT ((0)),
[MultiYearYN] [bit] NOT NULL CONSTRAINT [DF_SourceTable_MultiYearYN] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SourceTable_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SourceTable_Upd]
	ON [dbo].[SourceTable]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE ST
	SET
		[Version] = @Version
	FROM
		[SourceTable] ST
		INNER JOIN Inserted I ON	
			I.SourceTypeFamilyID = ST.SourceTypeFamilyID AND
			I.ModelBM = ST.ModelBM AND
			I.TableCode = ST.TableCode
GO
ALTER TABLE [dbo].[SourceTable] ADD CONSTRAINT [PK_SourceTable] PRIMARY KEY CLUSTERED ([SourceTypeFamilyID], [ModelBM], [TableCode], [DimensionID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'CASE WHEN TableTypeBM & 2 > 0 THEN DimensionID, CASE WHEN TableTypeBM & 4 > 0 THEN 0', 'SCHEMA', N'dbo', 'TABLE', N'SourceTable', 'COLUMN', N'DimensionID'
GO
EXEC sp_addextendedproperty N'MS_Description', N'1 = ETL, 2 = Dimension, 4 = Fact', 'SCHEMA', N'dbo', 'TABLE', N'SourceTable', 'COLUMN', N'TableTypeBM'
GO
