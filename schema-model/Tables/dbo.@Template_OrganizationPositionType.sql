CREATE TABLE [dbo].[@Template_OrganizationPositionType]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_OrganizationPositionType_InstanceID] DEFAULT ((0)),
[VersionID] [int] NOT NULL,
[OrganizationPositionTypeID] [int] NOT NULL,
[OrganizationPositionTypeName] [nvarchar] (50) NOT NULL,
[OrganizationPositionTypeDescription] [nvarchar] (255) NOT NULL,
[CommissionParameter] [float] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_OrganizationPositionType_Version] DEFAULT ('')
)
GO
ALTER TABLE [dbo].[@Template_OrganizationPositionType] ADD CONSTRAINT [PK_OrganizationPositionType] PRIMARY KEY CLUSTERED ([OrganizationPositionTypeID])
GO
