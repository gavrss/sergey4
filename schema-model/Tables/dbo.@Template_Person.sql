CREATE TABLE [dbo].[@Template_Person]
(
[InstanceID] [int] NOT NULL,
[PersonID] [int] NOT NULL IDENTITY(1001, 1),
[ReplacedBy_PersonID] [int] NULL,
[EmployeeNumber] [nvarchar] (50) NULL,
[DisplayName] [nvarchar] (100) NULL,
[FamilyName] [nvarchar] (50) NULL,
[GivenName] [nvarchar] (50) NULL,
[Email] [nvarchar] (100) NULL,
[SocialSecurityNumber] [nvarchar] (50) NULL,
[SourceSpecificKey] [nvarchar] (100) NULL,
[Source] [nvarchar] (50) NULL,
[SourceID] [int] NULL,
[Inserted] [datetime] NULL CONSTRAINT [DF_Person_Inserted] DEFAULT (getdate()),
[InsertedBy] [nvarchar] (100) NULL CONSTRAINT [DF_Person_InsertedBy] DEFAULT (suser_name()),
[Updated] [datetime] NULL CONSTRAINT [DF_Person_Updated] DEFAULT (getdate()),
[UpdatedBy] [nvarchar] (100) NULL CONSTRAINT [DF_Person_UpdatedBy] DEFAULT (suser_name()),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Person_Version] DEFAULT (''),
[DeletedID] [int] NULL
)
GO
ALTER TABLE [dbo].[@Template_Person] ADD CONSTRAINT [PK_PersonID] PRIMARY KEY CLUSTERED ([PersonID])
GO
