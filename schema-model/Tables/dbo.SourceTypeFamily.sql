CREATE TABLE [dbo].[SourceTypeFamily]
(
[SourceTypeFamilyID] [int] NOT NULL IDENTITY(1001, 1),
[SourceTypeFamilyName] [nvarchar] (50) NOT NULL,
[SourceTypeFamilyDescription] [nvarchar] (255) NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SourceTypeFamily_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SourceTypeFamily_Upd]
	ON [dbo].[SourceTypeFamily]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE STF
	SET
		[Version] = @Version
	FROM
		[SourceTypeFamily] STF
		INNER JOIN Inserted I ON	
			I.SourceTypeFamilyID = STF.SourceTypeFamilyID


GO
ALTER TABLE [dbo].[SourceTypeFamily] ADD CONSTRAINT [PK_SourceTypeFamily] PRIMARY KEY CLUSTERED ([SourceTypeFamilyID])
GO
