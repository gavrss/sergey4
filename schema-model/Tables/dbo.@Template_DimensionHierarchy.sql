CREATE TABLE [dbo].[@Template_DimensionHierarchy]
(
[Comment] [nvarchar] (255) NOT NULL CONSTRAINT [DF_DimensionHierarchy_Comment] DEFAULT (''),
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_DimensionHierarchy_VersionID] DEFAULT ((0)),
[DimensionID] [int] NOT NULL,
[HierarchyNo] [int] NOT NULL,
[HierarchyName] [nvarchar] (50) NOT NULL,
[HierarchyTypeID] [int] NOT NULL CONSTRAINT [DF_@Template_DimensionHierarchy_HierarchyTypeID] DEFAULT ((1)),
[FixedLevelsYN] [bit] NOT NULL CONSTRAINT [DF_DimensionHierarchy_FixedLevelYN] DEFAULT ((1)),
[BaseDimension] [nvarchar] (50) NULL,
[BaseHierarchy] [nvarchar] (50) NULL,
[BaseDimensionFilter] [nvarchar] (4000) NULL,
[PropertyHierarchy] [nvarchar] (1000) NULL,
[BusinessRuleID] [int] NULL,
[DimensionFilter] [nvarchar] (4000) NULL,
[LockedYN] [bit] NOT NULL CONSTRAINT [DF_DimensionHierarchy_LockedYN] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DimensionHierarchy_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DimensionHierarchy_Upd]
	ON [dbo].[@Template_DimensionHierarchy]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DH
	SET
		[Version] = @Version
	FROM
		[@Template_DimensionHierarchy] DH
		INNER JOIN Inserted I ON	
			I.InstanceID = DH.InstanceID AND
			I.DimensionID = DH.DimensionID AND
			I.HierarchyNo = DH.HierarchyNo
GO
ALTER TABLE [dbo].[@Template_DimensionHierarchy] ADD CONSTRAINT [PK_@Template_DimensionHierarchy] PRIMARY KEY CLUSTERED ([InstanceID], [VersionID], [DimensionID], [HierarchyNo])
GO
ALTER TABLE [dbo].[@Template_DimensionHierarchy] ADD CONSTRAINT [FK_DimensionHierarchy_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Only used for HierarchyTypeID = 7', 'SCHEMA', N'dbo', 'TABLE', N'@Template_DimensionHierarchy', 'COLUMN', N'DimensionFilter'
GO
