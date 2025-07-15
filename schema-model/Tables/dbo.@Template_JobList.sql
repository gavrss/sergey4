CREATE TABLE [dbo].[@Template_JobList]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_JobList_VersionID] DEFAULT ((0)),
[JobListID] [int] NOT NULL,
[JobListName] [nvarchar] (50) NOT NULL,
[JobListDescription] [nvarchar] (255) NOT NULL,
[JobStepTypeBM] [int] NOT NULL CONSTRAINT [DF_JobList_JobStepTypeBM] DEFAULT ((65535)),
[JobFrequencyBM] [int] NOT NULL CONSTRAINT [DF_JobList_FrequencyBM] DEFAULT ((65535)),
[JobStepGroupBM] [int] NOT NULL CONSTRAINT [DF_JobList_JobStepGroupBM] DEFAULT ((65535)),
[ProcessBM] [int] NULL,
[JobSetupStepBM] [int] NULL,
[JobStep_List] [nvarchar] (4000) NULL,
[Entity_List] [nvarchar] (4000) NULL,
[DelayedStart] [time] NOT NULL CONSTRAINT [DF_@Template_JobList_DelayedStart] DEFAULT ('00:00:00'),
[UserID] [int] NOT NULL,
[InheritedFrom] [int] NULL,
[SelectYN] [bit] NOT NULL CONSTRAINT [DF_JobList_SelectYN] DEFAULT ((1)),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_JobList_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[JobList_Upd]
	ON [dbo].[@Template_JobList]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100)
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE JL
	SET
		[Version] = @Version
	FROM
		[@Template_JobList] JL
		INNER JOIN Inserted I ON	
			I.JobListID = JL.JobListID
GO
ALTER TABLE [dbo].[@Template_JobList] ADD CONSTRAINT [PK_JobList] PRIMARY KEY CLUSTERED ([JobListID])
GO
