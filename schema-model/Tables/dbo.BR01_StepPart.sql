CREATE TABLE [dbo].[BR01_StepPart]
(
[BR01_StepPartID] [int] NOT NULL,
[BR01_StepPartName] [nvarchar] (50) NOT NULL,
[LogicDescription] [nvarchar] (1024) NULL,
[DataClassYN] [bit] NOT NULL,
[DecimalYN] [bit] NOT NULL,
[DimensionFilterYN] [bit] NOT NULL CONSTRAINT [DF_BR01_StepPart_DimensionFilterYN] DEFAULT ((0)),
[OperatorYN] [bit] NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_BR01_StepPart_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[BR01_StepPart_Upd]
	ON [dbo].[BR01_StepPart]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC pcINTEGRATOR..[spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SP
	SET
		[Version] = @Version
	FROM
		[BR01_StepPart] SP
		INNER JOIN Inserted I ON	
			I.BR01_StepPartID = SP.BR01_StepPartID
GO
ALTER TABLE [dbo].[BR01_StepPart] ADD CONSTRAINT [PK_BR01_StepPart] PRIMARY KEY CLUSTERED ([BR01_StepPartID])
GO
