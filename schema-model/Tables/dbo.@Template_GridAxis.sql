CREATE TABLE [dbo].[@Template_GridAxis]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_GridAxis_InstanceID] DEFAULT ((0)),
[GridAxisID] [int] NOT NULL,
[GridAxisName] [nvarchar] (50) NOT NULL,
[GridAxisDescription] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_GridAxis_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[GridAxis_Upd]
	ON [dbo].[@Template_GridAxis]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE GA
	SET
		[Version] = @Version
	FROM
		[@Template_GridAxis] GA
		INNER JOIN Inserted I ON	
			I.GridAxisID = GA.GridAxisID
GO
ALTER TABLE [dbo].[@Template_GridAxis] ADD CONSTRAINT [PK_GUIPosition] PRIMARY KEY CLUSTERED ([GridAxisID])
GO
