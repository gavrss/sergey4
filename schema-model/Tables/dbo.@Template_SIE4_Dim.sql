CREATE TABLE [dbo].[@Template_SIE4_Dim]
(
[InstanceID] [int] NOT NULL,
[JobID] [int] NOT NULL,
[Param] [nvarchar] (50) NOT NULL,
[DimCode] [nvarchar] (50) NOT NULL,
[DimName] [nvarchar] (100) NOT NULL,
[DimParent] [nvarchar] (50) NULL,
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Dim_Inserted] DEFAULT (getdate()),
[InsertedBy] [nvarchar] (100) NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_SIE4_Dim] ADD CONSTRAINT [PK_SIE4_Dim] PRIMARY KEY CLUSTERED ([JobID], [Param], [DimCode])
GO
