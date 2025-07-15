CREATE TABLE [dbo].[@Template_ModelingStatus]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_ModelingStatus_InstanceID] DEFAULT ((0)),
[ModelingStatusID] [int] NOT NULL,
[ModelingStatusName] [nvarchar] (50) NOT NULL,
[ModelingStatusDescription] [nvarchar] (255) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_ModelingStatus_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ModelingStatus_Upd]
	ON [dbo].[@Template_ModelingStatus]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE MS
	SET
		[Version] = @Version
	FROM
		[@Template_ModelingStatus] MS
		INNER JOIN Inserted I ON	
			I.ModelingStatusID = MS.ModelingStatusID
GO
ALTER TABLE [dbo].[@Template_ModelingStatus] ADD CONSTRAINT [PK_ModelingStatus] PRIMARY KEY CLUSTERED ([ModelingStatusID])
GO
