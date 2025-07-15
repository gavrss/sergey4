CREATE TABLE [dbo].[@Template_JobStepGroup]
(
[InstanceID] [int] NOT NULL,
[VersionID] [int] NOT NULL CONSTRAINT [DF_@Template_JobStepGroup_VersionID] DEFAULT ((0)),
[JobStepGroupID] [int] NOT NULL,
[JobStepGroupBM] [int] NOT NULL CONSTRAINT [DF_JobStepGroup_JobStepGroupBM] DEFAULT ((0)),
[JobStepGroupName] [nvarchar] (50) NOT NULL,
[JobStepGroupDescription] [nvarchar] (255) NOT NULL,
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_JobStepGroup_Version] DEFAULT ('')
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[JobStepGroup_Upd]
	ON [dbo].[@Template_JobStepGroup]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100),
		@InstanceID int,
		@JobStepGroupID int,
		@MaxJobStepGroupBM int
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)

	UPDATE JSG
	SET
		[Version] = @Version
	FROM
		[@Template_JobStepGroup] JSG
		INNER JOIN Inserted I ON	
			I.JobStepGroupID =JSG.JobStepGroupID

	DECLARE JobStepGroupBM_Cursor CURSOR FOR

		SELECT
			I.InstanceID,
			I.JobStepGroupID
		FROM
			Inserted I
		WHERE
			I.JobStepGroupBM = 0
		ORDER BY
			I.InstanceID,
			I.JobStepGroupID

		OPEN JobStepGroupBM_Cursor
		FETCH NEXT FROM JobStepGroupBM_Cursor INTO @InstanceID, @JobStepGroupID

		WHILE @@FETCH_STATUS = 0
			BEGIN
				SELECT @MaxJobStepGroupBM = MAX(JobStepGroupBM) FROM JobStepGroup WHERE InstanceID = @InstanceID

				UPDATE JSG
				SET
					[JobStepGroupBM] = CASE WHEN @MaxJobStepGroupBM = 0 THEN 1 ELSE @MaxJobStepGroupBM * 2 END
				FROM
					[@Template_JobStepGroup] JSG
				WHERE
					JSG.JobStepGroupID = @JobStepGroupID

				FETCH NEXT FROM JobStepGroupBM_Cursor INTO @InstanceID, @JobStepGroupID
			END

	CLOSE JobStepGroupBM_Cursor
	DEALLOCATE JobStepGroupBM_Cursor
GO
ALTER TABLE [dbo].[@Template_JobStepGroup] ADD CONSTRAINT [PK_JobStepGroup] PRIMARY KEY CLUSTERED ([JobStepGroupID])
GO
