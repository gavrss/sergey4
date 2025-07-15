CREATE TABLE [dbo].[Member]
(
[Comment] [nvarchar] (255) NOT NULL CONSTRAINT [DF_Member_Comment] DEFAULT (''),
[DimensionID] [int] NOT NULL,
[MemberID] [int] NOT NULL,
[Label] [nvarchar] (50) NOT NULL,
[Description] [nvarchar] (255) NOT NULL,
[HelpText] [nvarchar] (1024) NULL,
[NodeTypeBM] [int] NOT NULL CONSTRAINT [DF_Member_NodeTypeBM] DEFAULT ((0)),
[Parent] [nvarchar] (50) NULL,
[RNodeType] [nvarchar] (2) NOT NULL CONSTRAINT [DF_Member_RNodeType] DEFAULT (N'L'),
[HierarchyNo] [int] NOT NULL CONSTRAINT [DF_Member_HierarchyNo] DEFAULT ((0)),
[MandatoryYN] [bit] NOT NULL CONSTRAINT [DF_Member_MandatoryYN] DEFAULT ((1)),
[DefaultSelectYN] [bit] NOT NULL CONSTRAINT [DF_Member_DefaultSelectYN] DEFAULT ((1)),
[ModelBM] [int] NOT NULL CONSTRAINT [DF_Member_ModelBM] DEFAULT ((0)),
[SourceTypeBM] [int] NOT NULL CONSTRAINT [DF_Member_SourceTypeBM] DEFAULT ((0)),
[Introduced] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Member_Introduced] DEFAULT ((1.2)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Member_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Member_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Member_Upd]
	ON [dbo].[Member]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE M
	SET
		[Version] = @Version
	FROM
		[Member] M
		INNER JOIN Inserted I ON	
			I.DimensionID = M.DimensionID AND
			I.MemberID = M.MemberID
GO
ALTER TABLE [dbo].[Member] ADD CONSTRAINT [PK_Member] PRIMARY KEY CLUSTERED ([DimensionID], [MemberID])
GO
ALTER TABLE [dbo].[Member] ADD CONSTRAINT [FK_Member_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
