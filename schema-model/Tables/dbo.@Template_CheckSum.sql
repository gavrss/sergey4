CREATE TABLE [dbo].[@Template_CheckSum]
(
[InstanceID] [int] NOT NULL CONSTRAINT [DF_CheckSum_InstanceID] DEFAULT ((0)),
[VersionID] [int] NULL,
[CheckSumID] [int] NOT NULL,
[CheckSumName] [nvarchar] (50) NOT NULL,
[CheckSumDescription] [nvarchar] (255) NOT NULL,
[spCheckSum] [nvarchar] (100) NULL,
[InheritedFrom] [int] NULL,
[SortOrder] [int] NOT NULL CONSTRAINT [DF_CheckSum_SortOrder] DEFAULT ((0)),
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_CheckSum_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_CheckSum_Version] DEFAULT (''),
[ObjectGuiBehaviorBM] [int] NOT NULL CONSTRAINT [DF_@Template_CheckSum_ObjectGuiBehaviorBM] DEFAULT ((4)),
[DescriptionColumns] [nvarchar] (4000) NULL,
[DescriptionMitigate] [nvarchar] (1000) NULL,
[ActionResponsible] [nvarchar] (100) NULL,
[JiraIssueID] [int] NULL,
[JiraIssueStatusID] [int] NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[CheckSum_Upd]
	ON [dbo].[@Template_CheckSum]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE CS
	SET
		[Version] = @Version
	FROM
		[@Template_CheckSum] CS
		INNER JOIN Inserted I ON	
			I.CheckSumID = CS.CheckSumID
GO
ALTER TABLE [dbo].[@Template_CheckSum] ADD CONSTRAINT [PK_CheckSum] PRIMARY KEY CLUSTERED ([CheckSumID])
GO
ALTER TABLE [dbo].[@Template_CheckSum] ADD CONSTRAINT [FK_@Template_CheckSum_@Template_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
