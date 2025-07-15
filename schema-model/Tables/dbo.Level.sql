CREATE TABLE [dbo].[Level]
(
[DimensionID] [int] NOT NULL,
[Hierarchy] [nvarchar] (50) NOT NULL CONSTRAINT [DF_Level_Hierarchy] DEFAULT (N'Default'),
[LevelID] [int] NOT NULL,
[LevelName] [nvarchar] (50) NOT NULL,
[LevelDescription] [nvarchar] (255) NOT NULL,
[TimeTypeBM] [int] NOT NULL CONSTRAINT [DF_Level_TimeTypeBM] DEFAULT ((0)),
[FiscalYearStartMonth] [int] NOT NULL CONSTRAINT [DF_Level_FiscalYearStartMonth] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Level_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Level_Upd]
	ON [dbo].[Level]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE L
	SET
		[Version] = @Version
	FROM
		[Level] L
		INNER JOIN Inserted I ON	
			I.DimensionID = L.DimensionID AND
			I.Hierarchy = L.Hierarchy AND
			I.LevelID = L.LevelID


GO
ALTER TABLE [dbo].[Level] ADD CONSTRAINT [PK_Level] PRIMARY KEY CLUSTERED ([DimensionID], [Hierarchy], [LevelID])
GO
ALTER TABLE [dbo].[Level] ADD CONSTRAINT [FK_Level_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'0 = All start months, 1 - 12 corresponds to specific start months (normally 1 to define calendar hierarchy)', 'SCHEMA', N'dbo', 'TABLE', N'Level', 'COLUMN', N'FiscalYearStartMonth'
GO
