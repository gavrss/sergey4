CREATE TABLE [dbo].[VisibilityLevel]
(
[VisibilityLevelBM] [int] NOT NULL,
[VisibilityLevelName] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_VisibilityLevel_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[VisibilityLevel_Upd]
	ON [dbo].[VisibilityLevel]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE ST
	SET
		[Version] = @Version
	FROM
		[VisibilityLevel] ST
		INNER JOIN Inserted I ON	
			I.VisibilityLevelBM = ST.VisibilityLevelBM




GO
ALTER TABLE [dbo].[VisibilityLevel] ADD CONSTRAINT [PK_VisibilityLevel] PRIMARY KEY CLUSTERED ([VisibilityLevelBM])
GO
