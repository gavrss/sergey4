CREATE TABLE [dbo].[@Template_Workflow_LiveFcstNextFlow]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[WorkflowID] [int] NOT NULL,
[LiveFcstNextFlowID] [int] NOT NULL,
[WorkflowStateID] [int] NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Workflow_LiveFcstNextFlow_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Workflow_LiveFcstNextFlow_Upd]
	ON [dbo].[@Template_Workflow_LiveFcstNextFlow]

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
		[@Template_Workflow_LiveFcstNextFlow] L
		INNER JOIN Inserted I ON	
			I.WorkflowID = L.WorkflowID AND
			I.LiveFcstNextFlowID = L.LiveFcstNextFlowID
GO
ALTER TABLE [dbo].[@Template_Workflow_LiveFcstNextFlow] ADD CONSTRAINT [PK_Workflow_LiveFcstNextFlow] PRIMARY KEY CLUSTERED ([WorkflowID], [LiveFcstNextFlowID])
GO
ALTER TABLE [dbo].[@Template_Workflow_LiveFcstNextFlow] ADD CONSTRAINT [FK_Workflow_LiveFcstNextFlow_LiveFcstNextFlow] FOREIGN KEY ([LiveFcstNextFlowID]) REFERENCES [dbo].[LiveFcstNextFlow] ([LiveFcstNextFlowID])
GO
ALTER TABLE [dbo].[@Template_Workflow_LiveFcstNextFlow] ADD CONSTRAINT [FK_Workflow_LiveFcstNextFlow_Workflow] FOREIGN KEY ([WorkflowID]) REFERENCES [dbo].[@Template_Workflow] ([WorkflowID])
GO
