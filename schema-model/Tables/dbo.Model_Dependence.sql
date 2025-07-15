CREATE TABLE [dbo].[Model_Dependence]
(
[BaseModelID] [int] NOT NULL,
[DependenceModelID] [int] NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Model_Dependence_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Model_Dependence_Upd]
	ON [dbo].[Model_Dependence]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE MD
	SET
		[Version] = @Version
	FROM
		[Model_Dependence] MD
		INNER JOIN Inserted I ON	
			I.BaseModelID = MD.BaseModelID AND
			I.DependenceModelID = MD.DependenceModelID



GO
ALTER TABLE [dbo].[Model_Dependence] ADD CONSTRAINT [PK_Model_Dependence] PRIMARY KEY CLUSTERED ([BaseModelID], [DependenceModelID])
GO
