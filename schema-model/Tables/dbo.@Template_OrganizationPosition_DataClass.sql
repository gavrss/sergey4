CREATE TABLE [dbo].[@Template_OrganizationPosition_DataClass]
(
[Comment] [nvarchar] (100) NULL,
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_OrganizationPosition_DataClass_VersionID] DEFAULT ((0)),
[OrganizationPositionID] [int] NOT NULL,
[DataClassID] [int] NOT NULL,
[ReadAccessYN] [bit] NOT NULL CONSTRAINT [DF_OrganizationPosition_DataClass_ReadAccessYN] DEFAULT ((1)),
[WriteAccessYN] [bit] NOT NULL CONSTRAINT [DF_@Template_OrganizationPosition_DataClass_WriteAccessYN] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_OrganizationPosition_DataClass_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[OrganizationPosition_DataClass_Upd]
	ON [dbo].[@Template_OrganizationPosition_DataClass]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100),
		@DatabaseName nvarchar(100)
					
	SET @DatabaseName = DB_NAME()
	
	IF @DatabaseName = 'pcINTEGRATOR_Data'
		BEGIN
			EXEC [pcINTEGRATOR].dbo.[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

			IF @DevYN = 0
				SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
			UPDATE OPDC
			SET
				[Version] = @Version
			FROM
				[@Template_OrganizationPosition_DataClass] OPDC
				INNER JOIN Inserted I ON	
					I.OrganizationPositionID = OPDC.OrganizationPositionID AND
					I.DataClassID = OPDC.DataClassID
		END
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition_DataClass] ADD CONSTRAINT [PK_OrganizationPosition_DataClass] PRIMARY KEY CLUSTERED ([OrganizationPositionID], [DataClassID])
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition_DataClass] ADD CONSTRAINT [FK_OrganizationPosition_DataClass_DataClass] FOREIGN KEY ([DataClassID]) REFERENCES [dbo].[@Template_DataClass] ([DataClassID])
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition_DataClass] ADD CONSTRAINT [FK_OrganizationPosition_DataClass_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_OrganizationPosition_DataClass] ADD CONSTRAINT [FK_OrganizationPosition_DataClass_OrganizationPosition] FOREIGN KEY ([OrganizationPositionID]) REFERENCES [dbo].[@Template_OrganizationPosition] ([OrganizationPositionID])
GO
