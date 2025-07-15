CREATE TABLE [dbo].[@Template_BR00_Parameter]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[ParameterName] [nvarchar] (50) NOT NULL,
[ParameterValue] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR00_Parameter_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR00_Parameter_Upd]
	ON [dbo].[@Template_BR00_Parameter]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE BP
	SET
		[Version] = @Version
	FROM
		[@Template_BR00_Parameter] BP
		INNER JOIN Inserted I ON	
			I.BusinessRuleID = BP.BusinessRuleID AND
			I.ParameterName = BP.ParameterName
GO
ALTER TABLE [dbo].[@Template_BR00_Parameter] ADD CONSTRAINT [PK_BR00_Parameter] PRIMARY KEY CLUSTERED ([BusinessRuleID], [ParameterName])
GO
ALTER TABLE [dbo].[@Template_BR00_Parameter] ADD CONSTRAINT [FK_BR00_Parameter_BR00] FOREIGN KEY ([BusinessRuleID]) REFERENCES [dbo].[@Template_BusinessRule] ([BusinessRuleID])
GO
