SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[f_GetDataClassID]
(
    @InstanceID int,
	@VersionID int,
	@SourceDataClassID int
)
RETURNS int
AS
BEGIN

	DECLARE
		@DataClassID int

	SELECT
		@DataClassID = DataClassID
	FROM
		pcINTEGRATOR_Data..DataClass DC
		INNER JOIN
			(
			SELECT
				DataClassName,
				DataClassTypeID
			FROM
				pcINTEGRATOR_Data..DataClass
			WHERE
				DataClassID = @SourceDataClassID
			) sub ON sub.DataClassName = DC.DataClassName AND sub.DataClassTypeID = DC.DataClassTypeID
	WHERE
		DC.InstanceID = @InstanceID AND
		DC.VersionID = @VersionID

	RETURN @DataClassID       
END
GO
