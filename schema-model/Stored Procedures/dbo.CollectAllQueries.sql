SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [dbo].[CollectAllQueries] AS
BEGIN
    SET NOCOUNT ON;

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
