CREATE TABLE [dbo].[ObjectType]
(
[ObjectTypeBM] [int] NOT NULL,
[ObjectTypeName] [nvarchar] (50) NOT NULL,
[ParentObjectTypeBM] [int] NOT NULL CONSTRAINT [DF_ObjectType_ParentObjectTypeBM] DEFAULT ((0)),
[SecurityObjectYN] [bit] NOT NULL CONSTRAINT [DF_ObjectType_SecurityObjectYN] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_ObjectType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ObjectType_Upd]
	ON [dbo].[ObjectType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE OT
	SET
		[Version] = @Version
	FROM
		[ObjectType] OT
		INNER JOIN Inserted I ON	
			I.ObjectTypeBM = OT.ObjectTypeBM


GO
ALTER TABLE [dbo].[ObjectType] ADD CONSTRAINT [PK_ObjectType_1] PRIMARY KEY CLUSTERED ([ObjectTypeBM])
GO
