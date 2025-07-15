CREATE TABLE [dbo].[@Template_SIE4_Job]
(
[UserID] [int] NOT NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[JobID] [int] NOT NULL,
[FLAGGA] [nvarchar] (100) NULL,
[PROGRAM] [nvarchar] (100) NULL,
[FORMAT] [nvarchar] (100) NULL,
[GEN] [nvarchar] (100) NULL,
[SIETYP] [nvarchar] (100) NULL,
[PROSA] [nvarchar] (100) NULL,
[FNR] [nvarchar] (100) NULL,
[ORGNR] [nvarchar] (100) NULL,
[BKOD] [nvarchar] (100) NULL,
[ADRESS] [nvarchar] (100) NULL,
[FNAMN] [nvarchar] (100) NULL,
[RAR_0_FROM] [int] NOT NULL,
[RAR_0_TO] [int] NOT NULL,
[RAR_1_FROM] [int] NULL,
[RAR_1_TO] [int] NULL,
[TAXAR] [nvarchar] (50) NULL,
[OMFATTN] [nvarchar] (100) NULL,
[KPTYP] [nvarchar] (50) NULL,
[VALUTA] [nchar] (3) NULL,
[KSUMMA] [nvarchar] (100) NULL,
[EntityID] [int] NULL,
[SentRows] [int] NULL,
[StartTime] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Load_StartTime] DEFAULT (getdate()),
[EndTime] [datetime] NULL,
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Load_Inserted] DEFAULT (getdate()),
[InsertedBy] [nvarchar] (100) NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_SIE4_Job] ADD CONSTRAINT [PK_SIE4_Load] PRIMARY KEY CLUSTERED ([JobID] DESC)
GO
