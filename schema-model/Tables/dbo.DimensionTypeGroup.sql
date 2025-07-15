CREATE TABLE [dbo].[DimensionTypeGroup]
(
[DimensionTypeGroupID] [int] NOT NULL,
[DimensionTypeGroupName] [nvarchar] (50) NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DimensionTypeGroup_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DimensionTypeGroup_Upd]
	ON [dbo].[DimensionTypeGroup]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DTG
	SET
		[Version] = @Version
	FROM
		[DimensionTypeGroup] DTG
		INNER JOIN Inserted I ON	
			I.DimensionTypeGroupID = DTG.DimensionTypeGroupID




GO
ALTER TABLE [dbo].[DimensionTypeGroup] ADD CONSTRAINT [PK_DimensionTypeGroup] PRIMARY KEY CLUSTERED ([DimensionTypeGroupID])
GO
