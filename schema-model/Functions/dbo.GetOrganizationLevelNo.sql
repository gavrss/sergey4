SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[GetOrganizationLevelNo]
	(
	@Func_OrganizationPositionID int
	)
RETURNS int
WITH EXECUTE AS CALLER
AS
BEGIN

	DECLARE 
		@Func_ParentOrganizationPositionID int,
		@Func_LevelNo int = 1,
		@Func_OrganizationHierarchyID int

	SELECT
		@Func_ParentOrganizationPositionID = ParentOrganizationPositionID,
		@Func_OrganizationHierarchyID = OrganizationHierarchyID
	FROM
		[OrganizationPosition]
	WHERE
		OrganizationPositionID = @Func_OrganizationPositionID AND
		DeletedID IS NULL

	WHILE @Func_ParentOrganizationPositionID IS NOT NULL AND @Func_OrganizationPositionID <> @Func_ParentOrganizationPositionID
		BEGIN
			SELECT 
				@Func_ParentOrganizationPositionID = ParentOrganizationPositionID,
				@Func_LevelNo = @Func_LevelNo + 1
			FROM
				[OrganizationPosition]
			WHERE
				OrganizationHierarchyID = @Func_OrganizationHierarchyID AND
				OrganizationPositionID = @Func_ParentOrganizationPositionID AND
				DeletedID IS NULL
		END

	RETURN (@Func_LevelNo)
END
GO
