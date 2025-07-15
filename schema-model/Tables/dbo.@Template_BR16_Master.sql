CREATE TABLE [dbo].[@Template_BR16_Master]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[BusinessRuleID] [int] NOT NULL,
[Comment] [nvarchar] (1024) NULL,
[FromTime] [int] NULL,
[ToTime] [int] NULL,
[Filter] [nvarchar] (max) NULL,
[DataClassID] [int] NOT NULL,
[BackupLogID_Reference] [int] NULL,
[PurgePlanned] [datetime] NULL,
[StoringDatabaseName] [nvarchar] (100) NULL,
[InheritedFrom] [int] NULL,
[DeletedID] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR16_Master_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR16_Master_Upd]
	ON [dbo].[@Template_BR16_Master]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE M
	SET
		[Version] = @Version
	FROM
		[@Template_BR16_Master] M
		INNER JOIN Inserted I ON	
			I.BusinessRuleID = M.BusinessRuleID
GO
ALTER TABLE [dbo].[@Template_BR16_Master] ADD CONSTRAINT [PK_BR16_Master] PRIMARY KEY CLUSTERED ([BusinessRuleID])
GO
