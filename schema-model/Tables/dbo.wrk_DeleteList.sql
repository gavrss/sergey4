CREATE TABLE [dbo].[wrk_DeleteList]
(
[UserID] [int] NOT NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[Inserted] [datetime] NOT NULL CONSTRAINT [DF_wrk_DeleteList_Inserted] DEFAULT (getdate())
)
GO
