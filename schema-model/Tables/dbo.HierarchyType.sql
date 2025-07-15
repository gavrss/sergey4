CREATE TABLE [dbo].[HierarchyType]
(
[HierarchyTypeID] [int] NOT NULL,
[HierarchyTypeName] [nvarchar] (50) NOT NULL,
[HierarchyTypeDescription] [nvarchar] (255) NOT NULL,
[ReadOnlyYN] [bit] NOT NULL CONSTRAINT [DF_HierarchyType_ReadOnlyYN] DEFAULT ((0)),
[MandatoryProperty] [nvarchar] (1000) NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_HierarchyType_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_HierarchyType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[HierarchyType_Upd]
	ON [dbo].[HierarchyType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE HT
	SET
		[Version] = @Version
	FROM
		[HierarchyType] HT
		INNER JOIN Inserted I ON	
			I.HierarchyTypeID = HT.HierarchyTypeID
GO
ALTER TABLE [dbo].[HierarchyType] ADD CONSTRAINT [PK_HierarchyType] PRIMARY KEY CLUSTERED ([HierarchyTypeID])
GO
