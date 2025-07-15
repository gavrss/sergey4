CREATE TABLE [dbo].[LiveFcstNextFlow]
(
[LiveFcstNextFlowID] [int] NOT NULL,
[LiveFcstNextFlowName] [nvarchar] (50) NOT NULL,
[LiveFcstNextFlowDescription] [nvarchar] (255) NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_LiveFcstNextFlow_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[LiveFcstNextFlow_Upd]
	ON [dbo].[LiveFcstNextFlow]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE L
	SET
		[Version] = @Version
	FROM
		[LiveFcstNextFlow] L
		INNER JOIN Inserted I ON	
			I.LiveFcstNextFlowID = L.LiveFcstNextFlowID


GO
ALTER TABLE [dbo].[LiveFcstNextFlow] ADD CONSTRAINT [PK_LiveFcstNextFlow] PRIMARY KEY CLUSTERED ([LiveFcstNextFlowID])
GO
