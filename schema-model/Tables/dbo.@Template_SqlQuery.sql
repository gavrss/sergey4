CREATE TABLE [dbo].[@Template_SqlQuery]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_SqlQuery_InstanceID] DEFAULT ((0)),
[SqlQueryID] [int] NOT NULL,
[SqlQueryName] [nvarchar] (50) NOT NULL,
[SqlQueryDescription] [nvarchar] (255) NOT NULL,
[SqlQuery] [nvarchar] (max) NOT NULL,
[SqlQueryGroupID] [int] NOT NULL,
[RefID] [int] NULL,
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_SqlQuery_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SqlQuery_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SqlQuery_Upd]
	ON [dbo].[@Template_SqlQuery]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SQ
	SET
		[Version] = @Version
	FROM
		[@Template_SqlQuery] SQ
		INNER JOIN Inserted I ON	
			I.SqlQueryID = SQ.SqlQueryID
GO
ALTER TABLE [dbo].[@Template_SqlQuery] ADD CONSTRAINT [PK_SqlQuery] PRIMARY KEY CLUSTERED ([SqlQueryID])
GO
ALTER TABLE [dbo].[@Template_SqlQuery] ADD CONSTRAINT [FK_SqlQuery_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_SqlQuery] ADD CONSTRAINT [FK_SqlQuery_SqlQueryGroup] FOREIGN KEY ([SqlQueryGroupID]) REFERENCES [dbo].[@Template_SqlQueryGroup] ([SqlQueryGroupID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Reference to standard queries. Primarly used for mapping of CheckSums to SqlQueries.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_SqlQuery', 'COLUMN', N'RefID'
GO
