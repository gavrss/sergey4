CREATE TABLE [dbo].[Digit]
(
[Number] [int] NOT NULL IDENTITY(0, 1),
[Version] [nvarchar] (100) NOT NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Digit_Upd]
	ON [dbo].[Digit]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE D
	SET
		[Version] = @Version
	FROM
		[Digit] D
		INNER JOIN Inserted I ON	
			I.Number = D.Number

GO
ALTER TABLE [dbo].[Digit] ADD CONSTRAINT [CK__Digit__Number__0841E2CB] CHECK (([Number]>=(0) AND [Number]<=(9)))
GO
ALTER TABLE [dbo].[Digit] ADD CONSTRAINT [PK_Digit] PRIMARY KEY CLUSTERED ([Number])
GO
