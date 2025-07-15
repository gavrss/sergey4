CREATE TABLE [dbo].[@Template_DataClass_Dimension]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_DataGroup_Dimension_InstanceID] DEFAULT ((0)),
[VersionID] [int] NOT NULL CONSTRAINT [DF_DataClass_Dimension_VersionID] DEFAULT ((0)),
[DataClassID] [int] NOT NULL,
[DimensionID] [int] NOT NULL,
[ChangeableYN] [bit] NOT NULL CONSTRAINT [DF_@Template_DataClass_Dimension_ChangeableYN] DEFAULT ((0)),
[Conversion_MemberKey] [nvarchar] (100) NULL,
[TabularYN] [bit] NOT NULL CONSTRAINT [DF_@Template_DataClass_Dimension_TabularYN] DEFAULT ((1)),
[DataClassViewBM] [int] NOT NULL CONSTRAINT [DF_@Template_DataClass_Dimension_DataClassViewBM] DEFAULT ((1)),
[FilterLevel] [nvarchar] (2) NOT NULL CONSTRAINT [DF_DataClass_Dimension_FilterLevel] DEFAULT (N'L'),
[SortOrder] [int] NOT NULL CONSTRAINT [DF_DataClass_Dimension_SortOrder] DEFAULT ((0)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_@Template_DataClass_Dimension_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DataClass_Dimension_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DataClass_Dimension_Upd]
	ON [dbo].[@Template_DataClass_Dimension]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DCD
	SET
		[Version] = @Version
	FROM
		[@Template_DataClass_Dimension] DCD
		INNER JOIN Inserted I ON	
			I.DataClassID = DCD.DataClassID AND
			I.VersionID = DCD.VersionID AND
			I.DimensionID = DCD.DimensionID
GO
ALTER TABLE [dbo].[@Template_DataClass_Dimension] ADD CONSTRAINT [PK_@Template_DataClass_Dimension] PRIMARY KEY CLUSTERED ([DataClassID], [DimensionID])
GO
ALTER TABLE [dbo].[@Template_DataClass_Dimension] ADD CONSTRAINT [FK_DataClass_Dimension_DataClass] FOREIGN KEY ([DataClassID]) REFERENCES [dbo].[@Template_DataClass] ([DataClassID])
GO
ALTER TABLE [dbo].[@Template_DataClass_Dimension] ADD CONSTRAINT [FK_DataClass_Dimension_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
ALTER TABLE [dbo].[@Template_DataClass_Dimension] ADD CONSTRAINT [FK_DataClass_Dimension_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'The value to set when running Refresh Actuals and Copy Scenario', 'SCHEMA', N'dbo', 'TABLE', N'@Template_DataClass_Dimension', 'COLUMN', N'Conversion_MemberKey'
GO
EXEC sp_addextendedproperty N'MS_Description', N'L will filter on leaf level members, P will filter on existing parent level members (mostly used for SpreadingKey dataclasses)', 'SCHEMA', N'dbo', 'TABLE', N'@Template_DataClass_Dimension', 'COLUMN', N'FilterLevel'
GO
