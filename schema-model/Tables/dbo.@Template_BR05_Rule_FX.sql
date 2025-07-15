CREATE TABLE [dbo].[@Template_BR05_Rule_FX]
(
[Comment] [nvarchar] (1024) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[Rule_FXID] [int] NOT NULL,
[Rule_FXName] [nvarchar] (50) NOT NULL,
[JournalSequence] [nvarchar] (50) NOT NULL CONSTRAINT [DF_BR05_Rule_FX_JournalSequence] DEFAULT (N'FX'),
[DimensionFilter] [nvarchar] (4000) NULL,
[HistoricYN] [bit] NOT NULL CONSTRAINT [DF_@Template_BR05_Rule_FX_HistoricYN] DEFAULT ((0)),
[SortOrder] [int] NOT NULL CONSTRAINT [DF_BR05_Rule_FX_SortOrder] DEFAULT ((0)),
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_BR05_Rule_FX_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR05_Rule_FX_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR05_Rule_FX_Upd]
	ON [dbo].[@Template_BR05_Rule_FX]

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
		[@Template_BR05_Rule_FX] RC
		INNER JOIN Inserted I ON	
			I.Rule_FXID = RC.Rule_FXID
GO
ALTER TABLE [dbo].[@Template_BR05_Rule_FX] ADD CONSTRAINT [PK_BR05_Rule_FX] PRIMARY KEY CLUSTERED ([Rule_FXID])
GO
ALTER TABLE [dbo].[@Template_BR05_Rule_FX] ADD CONSTRAINT [FK_BR05_Rule_FX_BusinessRule] FOREIGN KEY ([BusinessRuleID]) REFERENCES [dbo].[@Template_BusinessRule] ([BusinessRuleID])
GO
