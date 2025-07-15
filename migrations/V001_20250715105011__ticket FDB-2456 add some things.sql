SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT N'Dropping constraints from [dbo].[@Template_AggregationType]'
GO
ALTER TABLE [dbo].[@Template_AggregationType] DROP CONSTRAINT [DF_AggregationType_Version]
GO
PRINT N'Altering [dbo].[@Template_AggregationType]'
GO
ALTER TABLE [dbo].[@Template_AggregationType] ADD
[Version111] [nvarchar] (100) NOT NULL CONSTRAINT [DF_AggregationType_Version] DEFAULT (''),
[SomeExtraColumn] [nchar] (10) NULL
GO
ALTER TABLE [dbo].[@Template_AggregationType] DROP
COLUMN [Version]
GO
PRINT N'Altering [dbo].[CollectAllQueries]'
GO

ALTER PROCEDURE [dbo].[CollectAllQueries] AS
BEGIN
    SET NOCOUNT ON;
	-- test comment
SELECT
	 server_name = 'dspProd02'
	,database_name = 'pcINTEGRATOR'
    ,qsqt.query_sql_text as query_text
    ,qsq.query_id
    ,qsp.plan_id
    ,qsrs.last_execution_time
    ,qsrs.avg_duration
	,qsrs.count_executions
	,qsrs.avg_cpu_time
FROM 
    pcINTEGRATOR.sys.query_store_query_text qsqt
JOIN 
    pcINTEGRATOR.sys.query_store_query qsq ON qsqt.query_text_id = qsq.query_text_id
JOIN 
    pcINTEGRATOR.sys.query_store_plan qsp ON qsq.query_id = qsp.query_id
JOIN 
    pcINTEGRATOR.sys.query_store_runtime_stats qsrs ON qsp.plan_id = qsrs.plan_id
ORDER BY 
         qsrs.last_execution_time asc;
END;

GO
PRINT N'Creating [dbo].[_procTest1]'
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[_procTest1] 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

END
GO

