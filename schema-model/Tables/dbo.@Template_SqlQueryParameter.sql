CREATE TABLE [dbo].[@Template_SqlQueryParameter]
(
[InstanceID] [int] NOT NULL,
[SqlQueryID] [int] NOT NULL,
[SqlQueryParameter] [nvarchar] (50) NOT NULL,
[SqlQueryParameterName] [nvarchar] (50) NOT NULL,
[SqlQueryParameterDescription] [nvarchar] (255) NOT NULL,
[DataType] [nvarchar] (50) NOT NULL,
[Size] [int] NOT NULL CONSTRAINT [DF_SqlQueryParameter_Size] DEFAULT ((0)),
[DefaultValue] [nvarchar] (50) NULL CONSTRAINT [DF_SqlQueryParameter_DefaultValue] DEFAULT ((0)),
[SqlQueryParameterQuery] [nvarchar] (max) NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_SqlQueryParameter_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SqlQueryParameter_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SqlQueryParameter_Upd]
	ON [dbo].[@Template_SqlQueryParameter]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SQP
	SET
		[Version] = @Version
	FROM
		[@Template_SqlQueryParameter] SQP
		INNER JOIN Inserted I ON	
			I.SqlQueryID = SQP.SqlQueryID AND
			I.SqlQueryParameter = SQP.SqlQueryParameter
GO
ALTER TABLE [dbo].[@Template_SqlQueryParameter] ADD CONSTRAINT [PK_SqlQueryParameter] PRIMARY KEY CLUSTERED ([SqlQueryID], [SqlQueryParameter])
GO
ALTER TABLE [dbo].[@Template_SqlQueryParameter] ADD CONSTRAINT [FK_SqlQueryParameter_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_SqlQueryParameter] ADD CONSTRAINT [FK_SqlQueryParameter_SqlQuery] FOREIGN KEY ([SqlQueryID]) REFERENCES [dbo].[@Template_SqlQuery] ([SqlQueryID])
GO
