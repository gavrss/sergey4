CREATE TABLE [dbo].[@Template_SIE4_Object]
(
[InstanceID] [int] NOT NULL,
[JobID] [int] NOT NULL,
[Param] [nvarchar] (50) NOT NULL,
[DimCode] [nvarchar] (50) NOT NULL,
[ObjectCode] [nvarchar] (50) NOT NULL,
[ObjectName] [nvarchar] (100) NOT NULL,
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_SIE4_Objekt_Inserted] DEFAULT (getdate()),
[InsertedBy] [nvarchar] (100) NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_SIE4_Object] ADD CONSTRAINT [PK_SIE4_Objekt] PRIMARY KEY CLUSTERED ([JobID], [Param], [DimCode], [ObjectCode])
GO
