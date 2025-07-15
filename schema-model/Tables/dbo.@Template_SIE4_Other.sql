CREATE TABLE [dbo].[@Template_SIE4_Other]
(
[InstanceID] [int] NOT NULL,
[JobID] [int] NOT NULL,
[Param] [nvarchar] (50) NOT NULL,
[String] [nvarchar] (255) NOT NULL,
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Other_Inserted] DEFAULT (getdate()),
[InsertedBy] [nvarchar] (100) NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_SIE4_Other] ADD CONSTRAINT [PK_SIE4_Other] PRIMARY KEY CLUSTERED ([JobID], [Param], [String])
GO
