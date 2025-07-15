CREATE TABLE [dbo].[@Template_Procedure_20231130]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL,
[ProcedureID] [int] NOT NULL IDENTITY(880000001, 1),
[DatabaseName] [nvarchar] (100) NOT NULL,
[ProcedureName] [nvarchar] (100) NOT NULL,
[ProcedureDescription] [nvarchar] (1024) NULL,
[StdParameterYN] [bit] NOT NULL,
[StdParameterMandatoryYN] [bit] NOT NULL,
[Updated] [datetime] NOT NULL,
[Version] [nvarchar] (100) NOT NULL,
[DeletedID] [int] NULL
)
GO
