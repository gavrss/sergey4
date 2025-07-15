CREATE TABLE [dbo].[ConsolidationMethod]
(
[ConsolidationMethodBM] [int] NOT NULL,
[ConsolidationMethodName] [nvarchar] (50) NOT NULL,
[ConsolidationMethodDescription] [nvarchar] (255) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_ConsolidationMethod_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ConsolidationMethod_Upd]
	ON [dbo].[ConsolidationMethod]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE CM
	SET
		[Version] = @Version
	FROM
		[ConsolidationMethod] CM
		INNER JOIN Inserted I ON	
			I.ConsolidationMethodBM = CM.ConsolidationMethodBM
GO
ALTER TABLE [dbo].[ConsolidationMethod] ADD CONSTRAINT [PK_ConsolidationMethod] PRIMARY KEY CLUSTERED ([ConsolidationMethodBM])
GO
