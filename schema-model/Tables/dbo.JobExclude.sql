CREATE TABLE [dbo].[JobExclude]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[Description] [nvarchar] (255) NULL
)
GO
ALTER TABLE [dbo].[JobExclude] ADD CONSTRAINT [PK_JobExclude] PRIMARY KEY CLUSTERED ([InstanceID], [VersionID])
GO
