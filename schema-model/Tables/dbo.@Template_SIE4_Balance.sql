CREATE TABLE [dbo].[@Template_SIE4_Balance]
(
[InstanceID] [int] NOT NULL,
[JobID] [int] NOT NULL,
[Param] [nvarchar] (50) NOT NULL,
[RAR] [int] NOT NULL,
[Account] [nvarchar] (50) NOT NULL,
[Amount] [decimal] (18, 2) NOT NULL,
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Balance_Inserted] DEFAULT (getdate()),
[InsertedBy] [nvarchar] (100) NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_SIE4_Balance] ADD CONSTRAINT [PK_SIE4_Balance] PRIMARY KEY CLUSTERED ([JobID], [Param], [RAR], [Account])
GO
