CREATE TABLE [dbo].[@Template_Journal_SegmentNo]
(
[Comment] [nvarchar] (50) NOT NULL CONSTRAINT [DF_Journal_SegmentNo_Entity] DEFAULT (N'Company'),
[JobID] [int] NOT NULL CONSTRAINT [DF_Journal_SegmentNo_JobID] DEFAULT ((0)),
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[EntityID] [int] NOT NULL,
[Book] [nvarchar] (50) NOT NULL CONSTRAINT [DF_Journal_SegmentNo_Book] DEFAULT (N'GL'),
[SegmentCode] [nvarchar] (50) NOT NULL,
[SourceCode] [nvarchar] (50) NULL,
[SegmentNo] [int] NOT NULL CONSTRAINT [DF_Journal_SegmentNo_SegmentNo] DEFAULT ((-1)),
[SegmentName] [nvarchar] (100) NOT NULL,
[DimensionID] [int] NULL,
[BalanceAdjYN] [bit] NOT NULL CONSTRAINT [DF_@Template_Journal_SegmentNo_BalanceAdjYN] DEFAULT ((1)),
[MaskPosition] [int] NULL,
[MaskCharacters] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Journal_SegmentNo_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Journal_SegmentNo_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Journal_SegmentNo_Upd]
	ON [dbo].[@Template_Journal_SegmentNo]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE JSN
	SET
		[Version] = @Version
	FROM
		[@Template_Journal_SegmentNo] JSN
		INNER JOIN Inserted I ON	
			I.EntityID = JSN.EntityID AND
			I.Book = JSN.Book AND
			I.SegmentCode = JSN.SegmentCode
GO
ALTER TABLE [dbo].[@Template_Journal_SegmentNo] ADD CONSTRAINT [PK_Journal_SegmentNo] PRIMARY KEY CLUSTERED ([EntityID], [Book], [SegmentCode])
GO
ALTER TABLE [dbo].[@Template_Journal_SegmentNo] ADD CONSTRAINT [FK_Journal_SegmentNo_Entity_Book] FOREIGN KEY ([EntityID], [Book]) REFERENCES [dbo].[@Template_Entity_Book] ([EntityID], [Book])
GO
EXEC sp_addextendedproperty N'MS_Description', N'If TRUE, should be included in join when calculating OB_ADJ.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Journal_SegmentNo', 'COLUMN', N'BalanceAdjYN'
GO
