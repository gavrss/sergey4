CREATE TABLE [dbo].[NodeType]
(
[NodeTypeBM] [int] NOT NULL,
[NodeTypeName] [nvarchar] (50) NOT NULL,
[NodeTypeDescription] [nvarchar] (255) NOT NULL CONSTRAINT [DF_NodeType_NodeTypeDescription] DEFAULT (''),
[NodeTypeCode] [nvarchar] (10) NULL,
[NodeTypeGroupID] [int] NOT NULL CONSTRAINT [DF_NodeType_NodeTypeGroupID] DEFAULT ((1)),
[NodeTypeDependencyBM] [int] NOT NULL CONSTRAINT [DF_NodeType_NodeTypeDependencyBM] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_NodeType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[NodeType_Upd]
	ON [dbo].[NodeType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE NT
	SET
		[Version] = @Version
	FROM
		[NodeType] NT
		INNER JOIN Inserted I ON	
			I.NodeTypeBM = NT.NodeTypeBM
GO
ALTER TABLE [dbo].[NodeType] ADD CONSTRAINT [PK_NodeType] PRIMARY KEY CLUSTERED ([NodeTypeBM])
GO
