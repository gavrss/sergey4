CREATE TABLE [dbo].[@Template_Source]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_Source_VersionID] DEFAULT ((0)),
[SourceID] [int] NOT NULL,
[SourceName] [nvarchar] (100) NOT NULL,
[SourceDescription] [nvarchar] (255) NULL,
[BusinessProcess] [nvarchar] (50) NOT NULL CONSTRAINT [DF_Source_BusinessRule] DEFAULT (N'N/A'),
[ModelID] [int] NOT NULL,
[SourceTypeID] [int] NOT NULL,
[SourceDatabase] [nvarchar] (255) NOT NULL,
[ETLDatabase_Linked] [nvarchar] (100) NULL,
[StartYear] [int] NOT NULL CONSTRAINT [DF_Source_StartYear] DEFAULT ((0)),
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_Source_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Source_Version] DEFAULT (''),
[SourceDatabase_Original] [nvarchar] (255) NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Source_Upd]
	ON [dbo].[@Template_Source]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE S
	SET
		[Version] = @Version
	FROM
		[@Template_Source] S
		INNER JOIN Inserted I ON	
			I.SourceID = S.SourceID

	UPDATE S
	SET
		[ETLDatabase_Linked] = CASE WHEN S.SourceDatabase LIKE '%.%' AND S.SourceTypeID <> 6 THEN CASE WHEN S.ETLDatabase_Linked IS NULL THEN SUBSTRING(S.SourceDatabase, 1, CHARINDEX ('.', S.SourceDatabase) - 1) + '.pcETL_LINKED_' + A.ApplicationName ELSE S.[ETLDatabase_Linked] END ELSE NULL END
	FROM
		[@Template_Source] S
		INNER JOIN [@Template_Model] M ON M.ModelID = S.ModelID
		INNER JOIN [@Template_Application] A ON A.ApplicationID = M.ApplicationID

	UPDATE S
	SET
		[BusinessProcess] = ST.SourceTypeName + '_' + CONVERT(nvarchar(10), S.SourceID)
	FROM
		[@Template_Source] S
		INNER JOIN [SourceType] ST ON ST.SourceTypeID = S.SourceTypeID
	WHERE
		S.[BusinessProcess] IS NULL OR S.[BusinessProcess] = 'N/A'

	UPDATE S
	SET
		[StartYear] = CASE WHEN S.SourceTypeID = 6 THEN 2014 ELSE DATEPART(YEAR, GETDATE()) - 1 END
	FROM
		[@Template_Source] S
		INNER JOIN Inserted I ON I.SourceID = S.SourceID
	WHERE
		S.[StartYear] = 0
GO
ALTER TABLE [dbo].[@Template_Source] ADD CONSTRAINT [PK_Source_1] PRIMARY KEY CLUSTERED ([SourceID])
GO
ALTER TABLE [dbo].[@Template_Source] ADD CONSTRAINT [FK_Source_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
ALTER TABLE [dbo].[@Template_Source] ADD CONSTRAINT [FK_Source_Model] FOREIGN KEY ([ModelID]) REFERENCES [dbo].[@Template_Model] ([ModelID])
GO
ALTER TABLE [dbo].[@Template_Source] ADD CONSTRAINT [FK_Source_SourceType] FOREIGN KEY ([SourceTypeID]) REFERENCES [dbo].[@Template_SourceType] ([SourceTypeID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Based on ApplicationID. Used when upgrading.', 'SCHEMA', N'dbo', 'TABLE', N'@Template_Source', 'COLUMN', N'InheritedFrom'
GO
