CREATE TABLE [dbo].[@Template_Grid]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[GridID] [int] NOT NULL,
[GridName] [nvarchar] (50) NOT NULL,
[GridDescription] [nvarchar] (50) NOT NULL,
[DataClassID] [int] NOT NULL,
[GridSkinID] [int] NOT NULL,
[GetProc] [nvarchar] (100) NULL,
[SetProc] [nvarchar] (100) NULL,
[InheritedFrom] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Grid_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Grid_Upd]
	ON [dbo].[@Template_Grid]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DC
	SET
		[Version] = @Version
	FROM
		[@Template_Grid] DC
		INNER JOIN Inserted I ON	
			I.GridID = DC.GridID
GO
ALTER TABLE [dbo].[@Template_Grid] ADD CONSTRAINT [PK_Grid_1] PRIMARY KEY CLUSTERED ([GridID])
GO
