SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spExcelGet_Menu_DefaultMember]
(
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ApplicationName	nvarchar(100) = NULL,
	@ModelName			nvarchar(100) = NULL,

	@DimensionName		nvarchar(100) = NULL,
	@Debug				bit = 0
)

AS

/*
	EXEC dbo.[spExcelGet_Menu_DefaultMember] @ApplicationName = 'Salinity2', @ModelName = 'Financials', @DimensionName = 'Scenario', @Debug = 1
	EXEC dbo.[spExcelGet_Menu_DefaultMember] @ApplicationName = 'Salinity2', @ModelName = NULL, @DimensionName = 'Scenario', @Debug = 1
	EXEC dbo.[spExcelGet_Menu_DefaultMember] @ApplicationName = 'Salinity2', @ModelName = 'Sales', @DimensionName = NULL, @Debug = 1
*/	

--#WITH ENCRYPTION#--

DECLARE
	@SQLStatement NVARCHAR(MAX)

	SET @SQLStatement = '
		SELECT 
			[Model],
			[Dimension],
			[DefaultMember] = CASE WHEN ISNULL([ReportDefaultValue], '''') = '''' THEN ''All_'' ELSE [ReportDefaultValue] END
		FROM
			pcDATA_' + @ApplicationName + '.[dbo].[Canvas_Workflow_Segment]
		WHERE
			[Model] = ISNULL(''' + @ModelName + ''', [Model]) AND
			Dimension = ISNULL(''' + @DimensionName + ''', [Dimension])'

IF @Debug <> 0 PRINT @SQLStatement
EXEC (@SQLStatement)
GO
