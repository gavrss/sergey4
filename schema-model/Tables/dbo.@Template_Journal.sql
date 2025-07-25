CREATE TABLE [dbo].[@Template_Journal]
(
[JobID] [int] NOT NULL CONSTRAINT [DF_Journal_JobID] DEFAULT ((0)),
[JournalID] [bigint] NOT NULL,
[InstanceID] [int] NOT NULL CONSTRAINT [DF_Journal_InstanceID] DEFAULT ((0)),
[Entity] [nvarchar] (50) NOT NULL,
[Book] [nvarchar] (50) NOT NULL,
[FiscalYear] [int] NOT NULL,
[FiscalPeriod] [int] NOT NULL,
[JournalSequence] [nvarchar] (50) NOT NULL,
[JournalNo] [nvarchar] (50) NOT NULL,
[JournalLine] [int] NOT NULL,
[YearMonth] [int] NULL,
[TransactionTypeBM] [int] NOT NULL CONSTRAINT [DF_Journal_TransactionTypeBM] DEFAULT ((1)),
[BalanceYN] [bit] NOT NULL CONSTRAINT [DF_Journal_BalanceYN] DEFAULT ((0)),
[Account] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Account] DEFAULT (''),
[Segment01] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment01] DEFAULT (''),
[Segment02] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment02] DEFAULT (''),
[Segment03] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment03] DEFAULT (''),
[Segment04] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment04] DEFAULT (''),
[Segment05] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment05] DEFAULT (''),
[Segment06] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment06] DEFAULT (''),
[Segment07] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment07] DEFAULT (''),
[Segment08] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment08] DEFAULT (''),
[Segment09] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment09] DEFAULT (''),
[Segment10] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment10] DEFAULT (''),
[Segment11] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment11] DEFAULT (''),
[Segment12] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment12] DEFAULT (''),
[Segment13] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment13] DEFAULT (''),
[Segment14] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment14] DEFAULT (''),
[Segment15] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment15] DEFAULT (''),
[Segment16] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment16] DEFAULT (''),
[Segment17] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment17] DEFAULT (''),
[Segment18] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment18] DEFAULT (''),
[Segment19] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment19] DEFAULT (''),
[Segment20] [nvarchar] (50) NULL CONSTRAINT [DF_Journal_Segment20] DEFAULT (''),
[JournalDate] [date] NULL,
[TransactionDate] [date] NULL,
[PostedDate] [date] NULL,
[PostedStatus] [bit] NULL,
[PostedBy] [nvarchar] (100) NULL,
[Source] [nvarchar] (50) NULL,
[Flow] [nvarchar] (50) NULL,
[ConsolidationGroup] [nvarchar] (50) NULL,
[InterCompanyEntity] [nvarchar] (50) NULL,
[Scenario] [nvarchar] (50) NULL,
[Customer] [nvarchar] (50) NULL,
[Supplier] [nvarchar] (50) NULL,
[Description_Head] [nvarchar] (255) NULL,
[Description_Line] [nvarchar] (255) NULL,
[Description] [nvarchar] (255) NULL,
[Currency_Book] [nchar] (3) NULL,
[ValueDebit_Book] [float] NULL,
[ValueCredit_Book] [float] NULL,
[Currency_Group] [nchar] (3) NULL,
[ValueDebit_Group] [float] NULL,
[ValueCredit_Group] [float] NULL,
[Currency_Transaction] [nchar] (3) NULL,
[ValueDebit_Transaction] [float] NULL,
[ValueCredit_Transaction] [float] NULL,
[SourceModule] [nvarchar] (20) NULL,
[SourceModuleReference] [nvarchar] (100) NULL,
[SourceCounter] [bigint] NULL,
[SourceGUID] [uniqueidentifier] NULL,
[Inserted] [datetime] NULL CONSTRAINT [DF_Journal_Inserted] DEFAULT (getdate()),
[InsertedBy] [nvarchar] (100) NULL CONSTRAINT [DF_Journal_InsertedBy] DEFAULT (suser_name())
)
GO
ALTER TABLE [dbo].[@Template_Journal] ADD CONSTRAINT [PK_Journal_1] PRIMARY KEY CLUSTERED ([JournalID])
GO
CREATE NONCLUSTERED INDEX [Journal_Index_1] ON [dbo].[@Template_Journal] ([InstanceID], [Entity], [Book], [FiscalYear], [FiscalPeriod], [JournalSequence], [JournalNo], [JournalLine])
GO
