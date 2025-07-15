CREATE TABLE [dbo].[MappingType]
(
[MappingTypeID] [int] NOT NULL,
[MappingTypeName] [nvarchar] (50) NOT NULL,
[MappingTypeDescription] [nvarchar] (100) NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_MappingType_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_MappingType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[MappingType_Upd]
	ON [dbo].[MappingType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE MT
	SET
		[Version] = @Version
	FROM
		[MappingType] MT
		INNER JOIN Inserted I ON	
			I.MappingTypeID = MT.MappingTypeID
GO
ALTER TABLE [dbo].[MappingType] ADD CONSTRAINT [PK_MappingType] PRIMARY KEY CLUSTERED ([MappingTypeID])
GO
