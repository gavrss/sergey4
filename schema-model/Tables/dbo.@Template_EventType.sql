CREATE TABLE [dbo].[@Template_EventType]
(
[InstanceID] [int] NOT NULL,
[EventTypeID] [int] NOT NULL,
[EventTypeName] [nvarchar] (50) NOT NULL,
[EventTypeDescription] [nvarchar] (255) NOT NULL,
[AutoEventTypeID] [int] NULL,
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_@Template_EventType_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_EventType_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[EventType_Upd]
	ON [dbo].[@Template_EventType]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE ET
	SET
		[Version] = @Version
	FROM
		[@Template_EventType] ET
		INNER JOIN Inserted I ON	
			I.EventTypeID = ET.EventTypeID
GO
ALTER TABLE [dbo].[@Template_EventType] ADD CONSTRAINT [PK_@Template_EventType] PRIMARY KEY CLUSTERED ([EventTypeID])
GO
