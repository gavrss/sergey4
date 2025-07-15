CREATE TABLE [dbo].[@Template_Procedure]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_@Template_Procedure_InstanceID] DEFAULT ((0)),
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_Procedure_VersionID] DEFAULT ((0)),
[ProcedureID] [int] NOT NULL IDENTITY(880000001, 1),
[DatabaseName] [nvarchar] (100) NOT NULL CONSTRAINT [DF_@Template_Procedure_DatabaseName] DEFAULT (N'pcINTEGRATOR'),
[ProcedureName] [nvarchar] (100) NOT NULL,
[ProcedureDescription] [nvarchar] (1024) NULL,
[StdParameterYN] [bit] NOT NULL CONSTRAINT [DF_Procedure_StdParameterYN] DEFAULT ((0)),
[StdParameterMandatoryYN] [bit] NOT NULL CONSTRAINT [DF_Procedure_StdParameterMandatoryYN] DEFAULT ((0)),
[Updated] [datetime] NOT NULL CONSTRAINT [DF_Procedure_Updated] DEFAULT (getdate()),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Procedure_Version] DEFAULT (''),
[DeletedID] [int] NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Procedure_Upd]
	ON [dbo].[@Template_Procedure]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE P
	SET
		[Version] = @Version
	FROM
		[@Template_Procedure] P
		INNER JOIN [Inserted] I ON	
			I.ProcedureID = P.ProcedureID
GO
ALTER TABLE [dbo].[@Template_Procedure] ADD CONSTRAINT [PK_Procedure] PRIMARY KEY CLUSTERED ([ProcedureID])
GO
CREATE UNIQUE NONCLUSTERED INDEX [NonClusteredIndex-20230501-200724] ON [dbo].[@Template_Procedure] ([InstanceID], [VersionID], [DatabaseName], [ProcedureName], [DeletedID])
GO
