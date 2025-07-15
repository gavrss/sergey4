CREATE TABLE [dbo].[wrk_DeleteList_Last]
(
[CustomerID] [int] NOT NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[ApplicationID] [int] NULL,
[ETLDatabase] [nvarchar] (100) NULL,
[CallistoDatabase] [nvarchar] (100) NULL,
[ETLDatabase_Linked] [nvarchar] (100) NULL,
[Inserted] [datetime] NOT NULL
)
GO
