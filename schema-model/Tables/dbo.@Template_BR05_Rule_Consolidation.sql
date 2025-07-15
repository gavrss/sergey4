CREATE TABLE [dbo].[@Template_BR05_Rule_Consolidation]
(
[Comment] [nvarchar] (1024) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[Rule_ConsolidationID] [int] NOT NULL,
[Rule_ConsolidationName] [nvarchar] (50) NOT NULL,
[JournalSequence] [nvarchar] (50) NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_JournalSequence] DEFAULT (N'CONS'),
[DimensionFilter] [nvarchar] (4000) NULL,
[ConsolidationMethodBM] [int] NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_ConsolidationMethodBM] DEFAULT ((0)),
[ModifierID] [int] NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_ModifierID] DEFAULT ((0)),
[OnlyInterCompanyInGroupYN] [bit] NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_OnlyInterCompanyInGroupYN] DEFAULT ((1)),
[FunctionalCurrencyYN] [bit] NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_FunctionalCurrencyYN] DEFAULT ((0)),
[UsePreviousStepYN] [bit] NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_UsePreviousStepYN] DEFAULT ((0)),
[SortOrder] [int] NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_SortOrder] DEFAULT ((0)),
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_Version] DEFAULT (''),
[MovementYN] [bit] NOT NULL CONSTRAINT [DF_@Template_BR05_Rule_Consolidation_MovementYN] DEFAULT ((0))
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR05_Rule_Consolidation_Upd]
	ON [dbo].[@Template_BR05_Rule_Consolidation]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE RC
	SET
		[Version] = @Version
	FROM
		[@Template_BR05_Rule_Consolidation] RC
		INNER JOIN Inserted I ON	
			I.Rule_ConsolidationID = RC.Rule_ConsolidationID
GO
ALTER TABLE [dbo].[@Template_BR05_Rule_Consolidation] ADD CONSTRAINT [PK_BR05_Rule_Consolidation] PRIMARY KEY CLUSTERED ([Rule_ConsolidationID])
GO
ALTER TABLE [dbo].[@Template_BR05_Rule_Consolidation] ADD CONSTRAINT [FK_BR05_Rule_Consolidation_BusinessRule] FOREIGN KEY ([BusinessRuleID]) REFERENCES [dbo].[@Template_BusinessRule] ([BusinessRuleID])
GO
