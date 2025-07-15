CREATE TABLE [dbo].[@Template_SqlQueryGroup]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_SqlQueryGroup_InstanceID] DEFAULT ((0)),
[SqlQueryGroupID] [int] NOT NULL,
[SqlQueryGroupName] [nvarchar] (50) NOT NULL,
[SqlQueryGroupDescription] [nvarchar] (255) NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_SqlQueryGroup_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SqlQueryGroup_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SqlQueryGroup_Upd]
	ON [dbo].[@Template_SqlQueryGroup]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SQG
	SET
		[Version] = @Version
	FROM
		[@Template_SqlQueryGroup] SQG
		INNER JOIN Inserted I ON	
			I.SqlQueryGroupID = SQG.SqlQueryGroupID
GO
ALTER TABLE [dbo].[@Template_SqlQueryGroup] ADD CONSTRAINT [PK_SqlQueryGroup] PRIMARY KEY CLUSTERED ([SqlQueryGroupID])
GO
ALTER TABLE [dbo].[@Template_SqlQueryGroup] ADD CONSTRAINT [FK_SqlQueryGroup_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
