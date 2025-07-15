CREATE TABLE [dbo].[@Template_DataOrigin]
(
[InstanceID] [int] NULL,
[VersionID] [int] NULL,
[DataOriginID] [int] NOT NULL IDENTITY(1001, 1),
[DataOriginName] [nvarchar] (100) NULL,
[ConnectionTypeID] [int] NULL,
[ConnectionName] [nvarchar] (100) NULL,
[SourceID] [int] NULL,
[StagingPosition] [nvarchar] (255) NULL,
[MasterDataYN] [bit] NULL,
[DataClassID] [int] NULL,
[DeletedID] [int] NULL
)
GO
ALTER TABLE [dbo].[@Template_DataOrigin] ADD CONSTRAINT [PK_DataOrigin] PRIMARY KEY CLUSTERED ([DataOriginID])
GO
