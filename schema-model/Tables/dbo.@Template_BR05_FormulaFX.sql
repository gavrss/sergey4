CREATE TABLE [dbo].[@Template_BR05_FormulaFX]
(
[Comment] [nvarchar] (1024) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[FormulaFXID] [int] NOT NULL,
[FormulaFXName] [nvarchar] (255) NOT NULL,
[FormulaFX] [nvarchar] (255) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR05_FXFormula_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR05_FormulaFX_Upd]
	ON [dbo].[@Template_BR05_FormulaFX]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE AF
	SET
		[Version] = @Version
	FROM
		[@Template_BR05_FormulaFX] AF
		INNER JOIN Inserted I ON	
			I.FormulaFXID = AF.FormulaFXID
GO
ALTER TABLE [dbo].[@Template_BR05_FormulaFX] ADD CONSTRAINT [PK_BR05_FXFormula] PRIMARY KEY CLUSTERED ([FormulaFXID])
GO
