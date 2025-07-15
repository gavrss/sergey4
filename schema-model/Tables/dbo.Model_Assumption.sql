CREATE TABLE [dbo].[Model_Assumption]
(
[ModelID] [int] NOT NULL,
[AssumptionModelID] [int] NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Model_Assumption_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Model_Assumption_Upd]
	ON [dbo].[Model_Assumption]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE MA
	SET
		[Version] = @Version
	FROM
		[Model_Assumption] MA
		INNER JOIN Inserted I ON	
			I.ModelID = MA.ModelID AND
			I.AssumptionModelID = MA.AssumptionModelID



GO
ALTER TABLE [dbo].[Model_Assumption] ADD CONSTRAINT [PK_Model_Assumption] PRIMARY KEY CLUSTERED ([ModelID], [AssumptionModelID])
GO
