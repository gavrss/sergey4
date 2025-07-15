CREATE TABLE [dbo].[SourceDBType]
(
[SourceDBTypeID] [int] NOT NULL IDENTITY(1001, 1),
[SourceDBTypeName] [nvarchar] (50) NOT NULL,
[Description] [nvarchar] (100) NULL,
[SourceDBTypeBM] [int] NOT NULL CONSTRAINT [DF_SourceDBType_SourceDBTypeBM] DEFAULT ((0)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_SourceDBType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[SourceDBType_Upd]
	ON [dbo].[SourceDBType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SDBT
	SET
		[Version] = @Version
	FROM
		[SourceDBType] SDBT
		INNER JOIN Inserted I ON	
			I.SourceDBTypeID = SDBT.SourceDBTypeID


GO
ALTER TABLE [dbo].[SourceDBType] ADD CONSTRAINT [PK_SourceDBType] PRIMARY KEY CLUSTERED ([SourceDBTypeID])
GO
