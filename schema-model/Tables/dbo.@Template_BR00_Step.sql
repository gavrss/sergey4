CREATE TABLE [dbo].[@Template_BR00_Step]
(
[Comment] [nvarchar] (1024) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[BR00_StepID] [int] NOT NULL IDENTITY(1001, 1),
[BusinessRule_SubID] [int] NOT NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_BR00_Step_SortOrder] DEFAULT ((0)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_BR00_Master_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR00_Master_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR00_Step_Upd]
	ON [dbo].[@Template_BR00_Step]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE BS
	SET
		[Version] = @Version
	FROM
		[@Template_BR00_Step] BS
		INNER JOIN Inserted I ON	
			I.BusinessRuleID = BS.BusinessRuleID AND
			I.BR00_StepID = BS.BR00_StepID
GO
ALTER TABLE [dbo].[@Template_BR00_Step] ADD CONSTRAINT [PK_BR00_Step] PRIMARY KEY CLUSTERED ([BR00_StepID])
GO
ALTER TABLE [dbo].[@Template_BR00_Step] ADD CONSTRAINT [FK_BR00_Master_BusinessRule] FOREIGN KEY ([BusinessRuleID]) REFERENCES [dbo].[@Template_BusinessRule] ([BusinessRuleID])
GO
ALTER TABLE [dbo].[@Template_BR00_Step] ADD CONSTRAINT [FK_BR00_Master_BusinessRule1] FOREIGN KEY ([BusinessRule_SubID]) REFERENCES [dbo].[@Template_BusinessRule] ([BusinessRuleID])
GO
