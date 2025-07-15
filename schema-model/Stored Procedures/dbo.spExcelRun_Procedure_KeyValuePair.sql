SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spExcelRun_Procedure_KeyValuePair]
	@ProcedureName NVARCHAR(100) = NULL, --Mandatory
	@XML XML = NULL

--#WITH ENCRYPTION#--

AS
/*
EXEC pcINTEGRATOR..spExcelRun_Procedure_KeyValuePair
	'spExcelGet_Menu_Workflow',
	'<root>
  <row TKey="UserID" TValue="2129" />
  <row TKey="InstanceID" TValue="404" />
  <row TKey="VersionID" TValue="1003" />
  <row TKey="ApplicationName" TValue="pcDATA_Salinity2" />
  <row TKey="ModelName" TValue="Financials" />
  <row TKey="ResultTypeBM" TValue="1" />
</root>'
*/

EXEC spRun_Procedure_KeyValuePair @ProcedureName = @ProcedureName, @XML = @XML
GO
