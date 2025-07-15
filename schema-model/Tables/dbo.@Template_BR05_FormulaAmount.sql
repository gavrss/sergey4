CREATE TABLE [dbo].[@Template_BR05_FormulaAmount]
(
[Comment] [nvarchar] (1024) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[FormulaAmountID] [int] NOT NULL,
[FormulaAmountName] [nvarchar] (50) NOT NULL,
[FormulaAmount] [nvarchar] (255) NULL CONSTRAINT [DF_@Template_BR05_FormulaAmount_FormulaAmount] DEFAULT (''),
[Version] [nvarchar] (100) NOT NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR05_FormulaAmount_Upd]
	ON [dbo].[@Template_BR05_FormulaAmount]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE AF
	SET
		[Version] = @Version
	FROM
		[@Template_BR05_FormulaAmount] AF
		INNER JOIN Inserted I ON	
			I.FormulaAmountID = AF.FormulaAmountID
GO
ALTER TABLE [dbo].[@Template_BR05_FormulaAmount] ADD CONSTRAINT [PK_@Template_BR05_AmountFormula] PRIMARY KEY CLUSTERED ([FormulaAmountID])
GO
