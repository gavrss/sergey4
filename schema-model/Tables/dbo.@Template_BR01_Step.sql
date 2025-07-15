CREATE TABLE [dbo].[@Template_BR01_Step]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[BR01_StepID] [int] NOT NULL,
[BR01_StepPartID] [int] NOT NULL,
[Comment] [nvarchar] (1024) NULL,
[MemberKey] [nvarchar] (100) NULL,
[ModifierID] [int] NULL,
[Parameter] [float] NULL,
[DataClassID] [int] NULL,
[Decimal] [int] NULL,
[DimensionFilter] [nvarchar] (4000) NULL,
[ValueFilter] [nvarchar] (4000) NULL,
[Operator] [nchar] (1) NULL,
[MultiplyWith] [float] NOT NULL CONSTRAINT [DF_@Template_BR01_Step_MultiplyWith] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_BR01_Step_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[@Template_BR01_Step_Upd]
	ON [dbo].[@Template_BR01_Step]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE S
	SET
		[Version] = @Version
	FROM
		[@Template_BR01_Step] S
		INNER JOIN Inserted I ON	
			I.BusinessRuleID = S.BusinessRuleID AND
			I.BR01_StepID = S.BR01_StepID AND
			I.BR01_StepPartID = S.BR01_StepPartID
GO
ALTER TABLE [dbo].[@Template_BR01_Step] ADD CONSTRAINT [PK_@Template_BR01_Step] PRIMARY KEY CLUSTERED ([BusinessRuleID], [BR01_StepID], [BR01_StepPartID])
GO
ALTER TABLE [dbo].[@Template_BR01_Step] ADD CONSTRAINT [FK_@Template_BR01_Step_@Template_BR01_Master] FOREIGN KEY ([BusinessRuleID]) REFERENCES [dbo].[@Template_BR01_Master] ([BusinessRuleID])
GO
ALTER TABLE [dbo].[@Template_BR01_Step] ADD CONSTRAINT [FK_@Template_BR01_Step_BR_Modifier] FOREIGN KEY ([ModifierID]) REFERENCES [dbo].[BR_Modifier] ([ModifierID])
GO
ALTER TABLE [dbo].[@Template_BR01_Step] ADD CONSTRAINT [FK_@Template_BR01_Step_BR01_StepPart] FOREIGN KEY ([BR01_StepPartID]) REFERENCES [dbo].[BR01_StepPart] ([BR01_StepPartID])
GO
