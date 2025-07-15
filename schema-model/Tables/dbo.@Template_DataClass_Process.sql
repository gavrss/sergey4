CREATE TABLE [dbo].[@Template_DataClass_Process]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_DataClass_Process_VersionID] DEFAULT ((0)),
[DataClassID] [int] NOT NULL,
[ProcessID] [int] NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DataClass_Process_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DataClass_Process_Upd]
	ON [dbo].[@Template_DataClass_Process]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DCP
	SET
		[Version] = @Version
	FROM
		[@Template_DataClass_Process] DCP
		INNER JOIN Inserted I ON	
			I.DataClassID = DCP.DataClassID AND
			I.VersionID = DCP.VersionID AND
			I.ProcessID = DCP.ProcessID

GO
ALTER TABLE [dbo].[@Template_DataClass_Process] ADD CONSTRAINT [PK_@Template_DataClass_Process] PRIMARY KEY CLUSTERED ([DataClassID], [ProcessID])
GO
ALTER TABLE [dbo].[@Template_DataClass_Process] ADD CONSTRAINT [FK_DataClass_Process_DataClass] FOREIGN KEY ([DataClassID]) REFERENCES [dbo].[@Template_DataClass] ([DataClassID])
GO
ALTER TABLE [dbo].[@Template_DataClass_Process] ADD CONSTRAINT [FK_DataClass_Process_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_DataClass_Process] ADD CONSTRAINT [FK_DataClass_Process_Process] FOREIGN KEY ([ProcessID]) REFERENCES [dbo].[@Template_Process] ([ProcessID])
GO
