CREATE TABLE [dbo].[@Template_ScenarioType]
(
[InstanceID] [int] NOT NULL,
[ScenarioTypeID] [int] NOT NULL,
[ScenarioTypeName] [nvarchar] (50) NOT NULL,
[WorkflowYN] [bit] NOT NULL,
[FullDimensionalityYN] [bit] NOT NULL CONSTRAINT [DF_ScenarioType_FullDimensionalityYN] DEFAULT ((0)),
[LiveYN] [bit] NOT NULL,
[Version] [nvarchar] (100) NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ScenarioType_Upd]
	ON [dbo].[@Template_ScenarioType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE ST
	SET
		[Version] = @Version
	FROM
		[@Template_ScenarioType] ST
		INNER JOIN Inserted I ON	
			I.ScenarioTypeID = ST.ScenarioTypeID
GO
ALTER TABLE [dbo].[@Template_ScenarioType] ADD CONSTRAINT [PK_ScenarioType] PRIMARY KEY CLUSTERED ([ScenarioTypeID])
GO
