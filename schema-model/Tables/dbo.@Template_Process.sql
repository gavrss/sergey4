CREATE TABLE [dbo].[@Template_Process]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[ProcessID] [int] NOT NULL,
[ProcessBM] [int] NOT NULL CONSTRAINT [DF_Process_ProcessBM] DEFAULT ((0)),
[ProcessName] [nvarchar] (50) NOT NULL,
[ProcessDescription] [nvarchar] (50) NOT NULL,
[Destination_DataClassID] [int] NULL,
[ModelingStatusID] [int] NOT NULL CONSTRAINT [DF_Process_ModelingStatusID] DEFAULT ((-40)),
[ModelingComment] [nvarchar] (1024) NULL,
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Process_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Process_Version] DEFAULT (''),
[DeletedID] [int] NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Process_Upd]
	ON [dbo].[@Template_Process]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100),
		@InstanceID int,
		@ProcessID int,
		@MaxProcessBM int
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)

	UPDATE P
	SET
		[Version] = @Version
	FROM
		[@Template_Process] P
		INNER JOIN Inserted I ON	
			I.ProcessID = P.ProcessID

	DECLARE ProcessBM_Cursor CURSOR FOR

		SELECT
			I.InstanceID,
			I.ProcessID
		FROM
			Inserted I
		WHERE
			I.ProcessBM = 0
		ORDER BY
			I.InstanceID,
			I.ProcessID

		OPEN ProcessBM_Cursor
		FETCH NEXT FROM ProcessBM_Cursor INTO @InstanceID, @ProcessID

		WHILE @@FETCH_STATUS = 0
			BEGIN
				SELECT @MaxProcessBM = MAX(ProcessBM) FROM [@Template_Process] WHERE InstanceID = @InstanceID

				UPDATE P
				SET
					[ProcessBM] = CASE WHEN @MaxProcessBM = 0 THEN 1 ELSE @MaxProcessBM * 2 END
				FROM
					[@Template_Process] P
				WHERE
					P.ProcessID = @ProcessID

				FETCH NEXT FROM ProcessBM_Cursor INTO @InstanceID, @ProcessID
			END

	CLOSE ProcessBM_Cursor
	DEALLOCATE ProcessBM_Cursor
GO
ALTER TABLE [dbo].[@Template_Process] ADD CONSTRAINT [PK_Process] PRIMARY KEY CLUSTERED ([ProcessID])
GO
ALTER TABLE [dbo].[@Template_Process] ADD CONSTRAINT [FK_Process_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
