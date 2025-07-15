CREATE TABLE [dbo].[@Template_BR05_Rule_ICmatch]
(
[Comment] [nvarchar] (1024) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[Rule_ICmatchID] [int] NOT NULL,
[Rule_ICmatchName] [nvarchar] (50) NOT NULL,
[DimensionFilter] [nvarchar] (4000) NOT NULL,
[AccountInterCoDiffManual] [nvarchar] (50) NULL,
[AccountInterCoDiffAuto] [nvarchar] (50) NULL,
[Source] [nvarchar] (50) NOT NULL CONSTRAINT [DF_BR05_Rule_ICmatch_Source] DEFAULT (N'Journal'),
[SortOrder] [int] NOT NULL,
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_BR05_Rule_ICmatch_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR05_Rule_ICmatch_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[@Template_BR05_Rule_ICmatch] ADD CONSTRAINT [PK_BR05_Rule_ICmatch] PRIMARY KEY CLUSTERED ([Rule_ICmatchID])
GO
