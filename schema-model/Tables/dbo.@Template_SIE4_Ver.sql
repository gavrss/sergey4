CREATE TABLE [dbo].[@Template_SIE4_Ver]
(
[InstanceID] [int] NOT NULL,
[JobID] [int] NOT NULL,
[Param] [nvarchar] (50) NOT NULL,
[Seq] [nvarchar] (50) NOT NULL,
[Ver] [nvarchar] (50) NOT NULL,
[Date] [int] NOT NULL,
[Description] [nvarchar] (255) NULL,
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Ver_Inserted] DEFAULT (getdate()),
[InsertedBy] [nvarchar] (100) NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_SIE4_Ver] ADD CONSTRAINT [PK_SIE4_Ver] PRIMARY KEY CLUSTERED ([JobID], [Param], [Seq], [Ver])
GO
