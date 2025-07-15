CREATE TABLE [dbo].[@Template_DimensionHierarchyLevel]
(
[Comment] [nvarchar] (255) NOT NULL CONSTRAINT [DF_DimensionHierarchyLevel_Comment] DEFAULT (''),
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_DimensionHierarchyLevel_VersionID] DEFAULT ((0)),
[DimensionID] [int] NOT NULL,
[HierarchyNo] [int] NOT NULL,
[LevelNo] [int] NOT NULL,
[LevelName] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DimensionHierarchyLevel_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DimensionHierarchyLevel_Upd]
	ON [dbo].[@Template_DimensionHierarchyLevel]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DHL
	SET
		[Version] = @Version
	FROM
		[@Template_DimensionHierarchyLevel] DHL
		INNER JOIN Inserted I ON	
			I.InstanceID = DHL.InstanceID AND
			I.DimensionID = DHL.DimensionID AND
			I.HierarchyNo = DHL.HierarchyNo AND
			I.LevelNo = DHL.LevelNo
GO
ALTER TABLE [dbo].[@Template_DimensionHierarchyLevel] ADD CONSTRAINT [PK_DimensionHierarchyLevel] PRIMARY KEY CLUSTERED ([InstanceID], [VersionID], [DimensionID], [HierarchyNo], [LevelNo])
GO
