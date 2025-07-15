CREATE TABLE [dbo].[@Template_BR05_Rule_FX_Row]
(
[Comment] [nvarchar] (1024) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[Rule_FXID] [int] NOT NULL,
[Rule_FX_RowID] [int] NOT NULL CONSTRAINT [DF_BR05_Rule_FX_Row_Rule_FX_RowID] DEFAULT ((0)),
[FlowFilter] [nvarchar] (100) NULL,
[Modifier] [nvarchar] (20) NULL,
[ResultValueFilter] [nvarchar] (100) NULL,
[Sign] [int] NOT NULL,
[FormulaFXID] [int] NOT NULL CONSTRAINT [DF_BR05_Rule_FX_Row_FormulaFXID] DEFAULT ((-1)),
[Account] [nvarchar] (50) NULL,
[Flow] [nvarchar] (50) NULL,
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_BR05_Rule_FX_Row_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR05_Rule_FX_Row_Version] DEFAULT (''),
[NaturalAccountOnlyYN] [bit] NOT NULL CONSTRAINT [DF_BR05_Rule_FX_Row_NaturalAccountOnlyYN] DEFAULT ((0)),
[SortOrder] [int] NOT NULL CONSTRAINT [DF_BR05_Rule_FX_Row_SortOrder] DEFAULT ((0))
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR05_Rule_FX_Row_Ins]
	ON [dbo].[@Template_BR05_Rule_FX_Row]

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
		[Rule_FX_RowID] = RCR.Rule_FX_RowID + 1,
		[Version] = @Version
	FROM
		[@Template_BR05_Rule_FX_Row] RC
		INNER JOIN
			(
			SELECT
				[Rule_FXID] = RC.[Rule_FXID], 
				[Rule_FX_RowID] = MAX(ISNULL(RC.[Rule_FX_RowID], 0))
			FROM
				[@Template_BR05_Rule_FX_Row] RC
				INNER JOIN Inserted I ON I.Rule_FXID = RC.Rule_FXID
			GROUP BY
				RC.[Rule_FXID]
			) RCR ON RCR.Rule_FXID = RC.Rule_FXID
	WHERE
		RC.[Rule_FX_RowID] = 0

			--
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR05_Rule_FX_Row_Upd]
	ON [dbo].[@Template_BR05_Rule_FX_Row]

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
		[@Template_BR05_Rule_FX_Row] RC
		INNER JOIN Inserted I ON	
			I.Rule_FXID = RC.Rule_FXID AND
			I.Rule_FX_RowID = RC.Rule_FX_RowID
GO
ALTER TABLE [dbo].[@Template_BR05_Rule_FX_Row] ADD CONSTRAINT [PK_BR05_Rule_FX_Row] PRIMARY KEY CLUSTERED ([Rule_FXID], [Rule_FX_RowID])
GO
ALTER TABLE [dbo].[@Template_BR05_Rule_FX_Row] ADD CONSTRAINT [FK_BR05_Rule_FX_Row_BusinessRule] FOREIGN KEY ([BusinessRuleID]) REFERENCES [dbo].[@Template_BusinessRule] ([BusinessRuleID])
GO
