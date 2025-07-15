CREATE TABLE [dbo].[@Template_DimensionMember]
(
[InstanceID] [int] NOT NULL,
[DimensionID] [int] NOT NULL,
[MemberKey] [nvarchar] (100) NOT NULL,
[MemberID] [int] NULL,
[MemberDescription] [nvarchar] (255) NOT NULL,
[HelpText] [nvarchar] (1024) NULL,
[NodeTypeBM] [int] NOT NULL CONSTRAINT [DF_DimensionMember_NodeTypeBM] DEFAULT ((1)),
[SBZ] [bit] NOT NULL CONSTRAINT [DF_DimensionMember_SBZ] DEFAULT ((0)),
[Source] [nvarchar] (50) NOT NULL CONSTRAINT [DF_DimensionMember_Source] DEFAULT (N'Grid'),
[Synchronized] [bit] NOT NULL CONSTRAINT [DF_DimensionMember_Synchronized] DEFAULT ((1)),
[Level] [nvarchar] (50) NULL CONSTRAINT [DF_DimensionMember_Level] DEFAULT (N'Leaf'),
[SortOrder] [int] NULL CONSTRAINT [DF_DimensionMember_SortOrder] DEFAULT ((0)),
[ParentMemberID] [int] NULL,
[Parent] [nvarchar] (100) NULL CONSTRAINT [DF_DimensionMember_Parent] DEFAULT (N'All_'),
[Version] [nvarchar] (100) NOT NULL CONSTRAINT [DF_DimensionMember_Version] DEFAULT (''),
[MemberCounter] [bigint] NOT NULL,
[Reference] [nvarchar] (100) NULL
)
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [dbo].[DimensionMember_Upd]
	ON [dbo].[@Template_DimensionMember]

	--#WITH ENCRYPTION#--

	AFTER INSERT, UPDATE 
	
	AS 

	DECLARE
		@DevYN bit,
		@Version nvarchar(100),
		@InstanceID int,
		@DimensionID int,
		@SeedMemberID int
					
	EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @DevYN = @DevYN OUTPUT

	IF @DevYN = 0
		SET @Version = @Version + ' CUSTOM ' + SUSER_NAME() + ' ' + CONVERT(nvarchar(10), GetDate(), 112)
					
	UPDATE DM
	SET
		[Version] = @Version
	FROM
		[@Template_DimensionMember] DM
		INNER JOIN Inserted I ON
			I.InstanceID = DM.InstanceID AND	
			I.DimensionID = DM.DimensionID AND
			I.MemberKey = DM.MemberKey

	CREATE TABLE #Member
		(
		[MemberID] [int] IDENTITY(1001,1),
		[MemberKey] [nvarchar](100)
		)

		DECLARE MemberID_Cursor CURSOR FOR

			SELECT 
				DM.InstanceID,
				DM.DimensionID,
				SeedMemberID = COALESCE(MAX(CASE WHEN I.MemberID > DM.MemberID THEN I.MemberID ELSE DM.MemberID END) + 1, MAX(D.SeedMemberID))
			FROM
				Inserted I
				INNER JOIN [@Template_Dimension] D ON D.DimensionID = I.DimensionID
				LEFT JOIN [@Template_DimensionMember] DM ON DM.InstanceID = I.InstanceID AND DM.DimensionID = I.DimensionID
			WHERE
				DM.MemberID IS NULL OR I.MemberID IS NULL
			GROUP BY
				DM.InstanceID,
				DM.DimensionID

			OPEN MemberID_Cursor
			FETCH NEXT FROM MemberID_Cursor INTO @InstanceID, @DimensionID, @SeedMemberID

			WHILE @@FETCH_STATUS = 0
				BEGIN
					TRUNCATE TABLE #Member
					DBCC CHECKIDENT (#Member, RESEED, @SeedMemberID)

					UPDATE DM
					SET
						MemberID = M.MemberID
					FROM
						[@Template_DimensionMember] DM
						INNER JOIN Member M ON M.DimensionID IN (0, DM.DimensionID) AND M.Label = DM.MemberKey
					WHERE
						DM.InstanceID = @InstanceID AND
						DM.DimensionID = @DimensionID AND
						DM.MemberID IS NULL

					INSERT INTO #Member
						(
						MemberKey
						)
					SELECT 
						MemberKey
					FROM
						[@Template_DimensionMember]
					WHERE
						InstanceID = @InstanceID AND
						DimensionID = @DimensionID AND
						MemberID IS NULL

					UPDATE DM
					SET
						MemberID = M.MemberID
					FROM
						[@Template_DimensionMember] DM
						INNER JOIN #Member M ON M.MemberKey = DM.MemberKey
					WHERE
						DM.InstanceID = @InstanceID AND
						DM.DimensionID = @DimensionID

					FETCH NEXT FROM MemberID_Cursor INTO @InstanceID, @DimensionID, @SeedMemberID
				END

		CLOSE MemberID_Cursor
		DEALLOCATE MemberID_Cursor	

		DROP TABLE #Member
GO
ALTER TABLE [dbo].[@Template_DimensionMember] ADD CONSTRAINT [PK_DimensionMember] PRIMARY KEY CLUSTERED ([InstanceID], [DimensionID], [MemberKey])
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_DimensionMember] ON [dbo].[@Template_DimensionMember] ([InstanceID], [DimensionID], [MemberKey])
GO
ALTER TABLE [dbo].[@Template_DimensionMember] ADD CONSTRAINT [FK_DimensionMember_Dimension] FOREIGN KEY ([DimensionID]) REFERENCES [dbo].[@Template_Dimension] ([DimensionID])
GO
ALTER TABLE [dbo].[@Template_DimensionMember] ADD CONSTRAINT [FK_DimensionMember_Instance] FOREIGN KEY ([InstanceID]) REFERENCES [dbo].[@Template_Instance] ([InstanceID])
GO
