CREATE TABLE [dbo].[@Template_EntityHierarchy]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[EntityGroupID] [int] NOT NULL,
[EntityID] [int] NOT NULL,
[ParentID] [int] NOT NULL,
[ValidFrom] [date] NOT NULL,
[ValidTo] [date] NULL,
[OwnershipDirect] [float] NULL,
[OwnershipUltimate] [float] NULL,
[OwnershipConsolidation] [float] NULL,
[ConsolidationMethodBM] [int] NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_EntityHierarchy_SortOrder] DEFAULT ((0))
)
GO
ALTER TABLE [dbo].[@Template_EntityHierarchy] ADD CONSTRAINT [PK_EntityHierarchy] PRIMARY KEY CLUSTERED ([EntityGroupID], [EntityID], [ParentID], [ValidFrom])
GO
ALTER TABLE [dbo].[@Template_EntityHierarchy] ADD CONSTRAINT [FK_EntityHierarchy_Entity] FOREIGN KEY ([EntityGroupID]) REFERENCES [dbo].[@Template_Entity] ([EntityID])
GO
ALTER TABLE [dbo].[@Template_EntityHierarchy] ADD CONSTRAINT [FK_EntityHierarchy_Entity1] FOREIGN KEY ([EntityID]) REFERENCES [dbo].[@Template_Entity] ([EntityID])
GO
ALTER TABLE [dbo].[@Template_EntityHierarchy] ADD CONSTRAINT [FK_EntityHierarchy_Entity2] FOREIGN KEY ([ParentID]) REFERENCES [dbo].[@Template_Entity] ([EntityID])
GO
