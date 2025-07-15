CREATE TABLE [dbo].[@Template_BR_Type]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_@Template_BR_Type_InstanceID] DEFAULT ((0)),
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_BR_Type_VersionID] DEFAULT ((0)),
[BR_TypeID] [int] NOT NULL,
[BR_TypeCode] [nvarchar] (6) NOT NULL,
[BR_TypeName] [nvarchar] (50) NOT NULL,
[BR_TypeDescription] [nvarchar] (255) NOT NULL,
[Operation] [nvarchar] (20) NOT NULL,
[CallistoEnabledYN] [bit] NOT NULL CONSTRAINT [DF_@Template_BR_Type_CallistoEnabledYN] DEFAULT ((0)),
[ProcedureName] [nvarchar] (50) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR_Type_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR_Type_Upd]
	ON [dbo].[@Template_BR_Type]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE M
	SET
		[BR_TypeCode] = 'BR' + CASE WHEN ABS(I.BR_TypeID) BETWEEN 0 AND 9 THEN '0' ELSE '' END + CONVERT(nvarchar(10), I.BR_TypeID),
		[Version] = @Version
	FROM
		[@Template_BR_Type] M
		INNER JOIN Inserted I ON	
			I.BR_TypeID = M.BR_TypeID
GO
ALTER TABLE [dbo].[@Template_BR_Type] ADD CONSTRAINT [PK_BR_Type] PRIMARY KEY CLUSTERED ([BR_TypeID])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Short user friendly reference used in Callisto', 'SCHEMA', N'dbo', 'TABLE', N'@Template_BR_Type', 'COLUMN', N'Operation'
GO
