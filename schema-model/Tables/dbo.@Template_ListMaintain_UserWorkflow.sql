CREATE TABLE [dbo].[@Template_ListMaintain_UserWorkflow]
(
[UserID] [int] NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[Email] [nvarchar] (100) NOT NULL,
[GivenName] [nvarchar] (50) NULL,
[FamilyName] [nvarchar] (50) NULL,
[Title] [nvarchar] (50) NULL,
[UserNameDisplay] [nvarchar] (100) NULL,
[UserNameAD] [nvarchar] (100) NULL,
[LicenseType] [nvarchar] (100) NULL,
[ReportsTo] [nvarchar] (100) NULL,
[OnBehalfOf] [nvarchar] (100) NULL,
[LinkedDimensionID] [int] NULL,
[ResponsibleFor] [nvarchar] (100) NULL,
[Updated] [datetime] NOT NULL CONSTRAINT [DF_ListMaintain_UserWorkflow_Updated] DEFAULT (getdate()),
[UpdatedBy] [nvarchar] (128) NULL CONSTRAINT [DF_ListMaintain_UserWorkflow_UpdatedBy] DEFAULT (suser_name())
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ListMaintain_UserWorkflow_Upd]
	ON [dbo].[@Template_ListMaintain_UserWorkflow]

	--#WITH ENCRYPTION#--

	AFTER UPDATE 
	
	AS 

	UPDATE L
	SET
		[Updated] = GetDate()
	FROM
		[@Template_ListMaintain_UserWorkflow] L
		INNER JOIN Inserted I ON	
			I.InstanceID = L.InstanceID AND
			I.Email = L.Email


GO
ALTER TABLE [dbo].[@Template_ListMaintain_UserWorkflow] ADD CONSTRAINT [PK_ListMaintain_UserWorkflow] PRIMARY KEY CLUSTERED ([InstanceID], [Email])
GO
