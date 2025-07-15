CREATE TABLE [dbo].[UpgradeManualCheck]
(
[CheckID] [int] NOT NULL IDENTITY(1, 1),
[ObjectType] [nvarchar] (50) NOT NULL,
[ObjectName] [nvarchar] (255) NOT NULL,
[Info] [nvarchar] (max) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_UpgradeManualCheck_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[UpgradeManualCheck_Upd]
	ON [dbo].[UpgradeManualCheck]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE D
	SET
		[Version] = @Version
	FROM
		[UpgradeManualCheck] D
		INNER JOIN Inserted I ON	
			I.CheckID = D.CheckID

GO
ALTER TABLE [dbo].[UpgradeManualCheck] ADD CONSTRAINT [PK_UpgradeManualCheck] PRIMARY KEY CLUSTERED ([CheckID])
GO
