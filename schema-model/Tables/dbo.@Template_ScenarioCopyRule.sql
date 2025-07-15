CREATE TABLE [dbo].[@Template_ScenarioCopyRule]
(
[InstanceID] [int] NOT NULL,
[CopyRuleID] [int] NOT NULL,
[ToDataClassID] [int] NOT NULL CONSTRAINT [DF_ScenarioCopyRule_DataClassID] DEFAULT ((0)),
[FromDataClassID] [int] NOT NULL CONSTRAINT [DF_ScenarioCopyRule_FromDataClassID] DEFAULT ((0)),
[DimensionID] [int] NULL,
[MeasureID] [int] NULL,
[SetTo_MemberKey] [nvarchar] (100) NULL,
[SetTo_Column] [nvarchar] (100) NULL,
[Filter_MemberKey] [nvarchar] (4000) NULL,
[CaseFilter_MemberKey] [nvarchar] (4000) NULL,
[Version] [nvarchar] (100) NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[ScenarioCopyRule_Upd]
	ON [dbo].[@Template_ScenarioCopyRule]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE SCR
	SET
		[Version] = @Version
	FROM
		[@Template_ScenarioCopyRule] SCR
		INNER JOIN Inserted I ON	
			I.CopyRuleID = SCR.CopyRuleID
GO
ALTER TABLE [dbo].[@Template_ScenarioCopyRule] ADD CONSTRAINT [PK_ScenarioCopyRule] PRIMARY KEY CLUSTERED ([CopyRuleID])
GO
