SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [dbo].[QueryStoreData] AS
SELECT 
    qsqt.query_sql_text,
    qsq.query_id,
    qsp.plan_id,
    qsrs.avg_duration,
    qsp.last_execution_time
FROM 
    sys.query_store_query_text qsqt
JOIN 
    sys.query_store_query qsq ON qsqt.query_text_id = qsq.query_text_id
JOIN 
    sys.query_store_plan qsp ON qsq.query_id = qsp.query_id
JOIN 
    sys.query_store_runtime_stats qsrs ON qsp.plan_id = qsrs.plan_id;
GO
