CREATE TABLE [dbo].[@Template_LoginToken]
(
[UserID] [int] NOT NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[Token] [uniqueidentifier] NOT NULL,
[ValidUntil] [datetime] NOT NULL,
[Inserted] [datetime] NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_LoginToken] ADD CONSTRAINT [PK_LogonToken] PRIMARY KEY CLUSTERED ([Token])
GO
