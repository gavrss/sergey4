CREATE TABLE [dbo].[BR_Modifier]
(
[ModifierID] [int] NOT NULL,
[ModifierName] [nvarchar] (50) NOT NULL,
[Parameter] [nvarchar] (50) NOT NULL,
[ModifierDescription] [nvarchar] (255) NOT NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_BR_Modifier_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR_Modifier_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR_Modifier_Upd]
	ON [dbo].[BR_Modifier]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE M
	SET
		[Version] = @Version
	FROM
		[BR_Modifier] M
		INNER JOIN Inserted I ON	
			I.ModifierID = M.ModifierID
GO
ALTER TABLE [dbo].[BR_Modifier] ADD CONSTRAINT [PK_BR_Modifier] PRIMARY KEY CLUSTERED ([ModifierID])
GO
