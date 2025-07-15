CREATE TABLE [dbo].[@Template_BusinessRule]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[BR_Name] [nvarchar] (50) NOT NULL,
[BR_Description] [nvarchar] (255) NOT NULL,
[BR_TypeID] [int] NOT NULL,
[InheritedFrom] [int] NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_@Template_BusinessRule_SortOrder] DEFAULT ((0)),
[LastExecTime] [time] NOT NULL CONSTRAINT [DF_@Template_BusinessRule_LastExecTime] DEFAULT ('00:01:00'),
[ExpectedExecTime] [time] NOT NULL CONSTRAINT [DF_@Template_BusinessRule_ExpectedExecTime] DEFAULT ('00:01:00'),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_@Template_BusinessRule_SelectYN] DEFAULT ((0)),
[DeletedID] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_BR_List_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[@Template_BusinessRule_Upd]
	ON [dbo].[@Template_BusinessRule]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE BR
	SET
		[Version] = @Version
	FROM
		[@Template_BusinessRule] BR
		INNER JOIN Inserted I ON	
			I.BusinessRuleID = BR.BusinessRuleID
GO
ALTER TABLE [dbo].[@Template_BusinessRule] ADD CONSTRAINT [PK_@Template_BusinessRule] PRIMARY KEY CLUSTERED ([BusinessRuleID])
GO
ALTER TABLE [dbo].[@Template_BusinessRule] ADD CONSTRAINT [FK_@Template_BR_List_@Template_BR01_Master] FOREIGN KEY ([BusinessRuleID]) REFERENCES [dbo].[@Template_BR01_Master] ([BusinessRuleID])
GO
ALTER TABLE [dbo].[@Template_BusinessRule] ADD CONSTRAINT [FK_@Template_BR_List_BR_Type] FOREIGN KEY ([BR_TypeID]) REFERENCES [dbo].[@Template_BR_Type] ([BR_TypeID])
GO
ALTER TABLE [dbo].[@Template_BusinessRule] NOCHECK CONSTRAINT [FK_@Template_BR_List_@Template_BR01_Master]
GO
