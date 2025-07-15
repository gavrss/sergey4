CREATE TABLE [dbo].[@Template_Assignment_OrganizationLevel]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NULL,
[AssignmentID] [int] NOT NULL,
[OrganizationLevelNo] [int] NOT NULL,
[OrganizationPositionID] [int] NULL,
[LevelInWorkflowYN] [bit] NULL CONSTRAINT [DF_Assignment_OrganizationLevel_LevelInWorkflowYN] DEFAULT (NULL),
[ExpectedDate] [date] NULL CONSTRAINT [DF_Assignment_OrganizationLevel_ExpectedDate] DEFAULT (NULL),
[ActionDescription] [nvarchar] (50) NULL CONSTRAINT [DF_Assignment_OrganizationLevel_ActionDescription] DEFAULT (NULL),
[GridID] [int] NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_Assignment_OrganizationLevel_Version] DEFAULT (''),
[DeletedID] [int] NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[Assignment_OrganizationLevel_Upd]
	ON [dbo].[@Template_Assignment_OrganizationLevel]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
	
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)

	UPDATE AOL
	SET
		[Version] = @Version
	FROM
		[@Template_Assignment_OrganizationLevel] AOL
		INNER JOIN Inserted I ON I.AssignmentID = AOL.AssignmentID AND I.OrganizationLevelNo = AOL.OrganizationLevelNo
GO
ALTER TABLE [dbo].[@Template_Assignment_OrganizationLevel] ADD CONSTRAINT [PK_Assignment_OrganizationLevel] PRIMARY KEY CLUSTERED ([AssignmentID], [OrganizationLevelNo])
GO
ALTER TABLE [dbo].[@Template_Assignment_OrganizationLevel] ADD CONSTRAINT [FK_Assignment_OrganizationLevel_Assignment] FOREIGN KEY ([AssignmentID]) REFERENCES [dbo].[@Template_Assignment] ([AssignmentID])
GO
