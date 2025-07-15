CREATE TABLE [dbo].[@Template_BR05_Rule_Consolidation_Row]
(
[Comment] [nvarchar] (1024) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[Rule_ConsolidationID] [int] NOT NULL,
[Rule_Consolidation_RowID] [int] NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_Row_Rule_Consolidation_RowID] DEFAULT ((0)),
[DestinationEntity] [nvarchar] (50) NULL,
[Account] [nvarchar] (50) NULL,
[Flow] [nvarchar] (50) NULL,
[Sign] [int] NOT NULL,
[FormulaAmountID] [int] NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_Row_AmountFormulaID] DEFAULT ((-1)),
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_Row_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_Row_Version] DEFAULT (''),
[NaturalAccountOnlyYN] [bit] NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_Row_NaturalAccountOnlyYN] DEFAULT ((0)),
[SortOrder] [int] NOT NULL CONSTRAINT [DF_BR05_Rule_Consolidation_Row_SortOrder] DEFAULT ((0))
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR05_Rule_Consolidation_Row_Ins]
	ON [dbo].[@Template_BR05_Rule_Consolidation_Row]

	--#WITH ENCRYPTION#--

	AFTER INSERT
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE RC
	SET
		[Rule_Consolidation_RowID] = RCR.Rule_Consolidation_RowID + 1,
		[Version] = @Version
	FROM
		[@Template_BR05_Rule_Consolidation_Row] RC
		INNER JOIN
			(
			SELECT
				[Rule_ConsolidationID] = RC.[Rule_ConsolidationID], 
				[Rule_Consolidation_RowID] = MAX(ISNULL(RC.[Rule_Consolidation_RowID], 0))
			FROM
				[@Template_BR05_Rule_Consolidation_Row] RC
				INNER JOIN Inserted I ON I.Rule_ConsolidationID = RC.Rule_ConsolidationID
			GROUP BY
				RC.[Rule_ConsolidationID]
			) RCR ON RCR.Rule_ConsolidationID = RC.Rule_ConsolidationID
	WHERE
		RC.[Rule_Consolidation_RowID] = 0

			--
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR05_Rule_Consolidation_Row_Upd]
	ON [dbo].[@Template_BR05_Rule_Consolidation_Row]

	--#WITH ENCRYPTION#--

	AFTER UPDATE 
	
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
		[@Template_BR05_Rule_Consolidation_Row] RC
		INNER JOIN Inserted I ON	
			I.Rule_ConsolidationID = RC.Rule_ConsolidationID AND
			I.Rule_Consolidation_RowID = RC.Rule_Consolidation_RowID
GO
ALTER TABLE [dbo].[@Template_BR05_Rule_Consolidation_Row] ADD CONSTRAINT [PK_BR05_Rule_Consolidation_Row] PRIMARY KEY CLUSTERED ([Rule_ConsolidationID], [Rule_Consolidation_RowID])
GO
ALTER TABLE [dbo].[@Template_BR05_Rule_Consolidation_Row] ADD CONSTRAINT [FK_BR05_Rule_Consolidation_Row_BusinessRule] FOREIGN KEY ([BusinessRuleID]) REFERENCES [dbo].[@Template_BusinessRule] ([BusinessRuleID])
GO
