CREATE TABLE [dbo].[@Template_OrganizationPositionRow]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_OrganizationPositionRow_InstanceID] DEFAULT ((0)),
[VersionID] [int] NULL,
[OrganizationPositionID] [int] NOT NULL,
[DimensionID] [int] NOT NULL,
[Dimension_MemberKey] [nvarchar] (100) NOT NULL
)
GO
ALTER TABLE [dbo].[@Template_OrganizationPositionRow] ADD CONSTRAINT [PK_OrganizationPositionRow] PRIMARY KEY CLUSTERED ([OrganizationPositionID], [DimensionID], [Dimension_MemberKey])
GO
ALTER TABLE [dbo].[@Template_OrganizationPositionRow] ADD CONSTRAINT [FK_OrganizationPositionRow_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
ALTER TABLE [dbo].[@Template_OrganizationPositionRow] ADD CONSTRAINT [FK_OrganizationPositionRow_OrganizationPosition] FOREIGN KEY ([OrganizationPositionID]) REFERENCES [dbo].[@Template_OrganizationPosition] ([OrganizationPositionID])
GO
