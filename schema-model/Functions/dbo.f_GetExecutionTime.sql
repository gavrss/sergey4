SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [dbo].[f_GetExecutionTime] (@StartTime datetime, @EndTime datetime, @ErrorTime datetime)

RETURNS nvarchar(100)
WITH EXECUTE AS CALLER
AS
BEGIN
	DECLARE
		@ExecutionTime nvarchar(100) = '',
		@DiffInSec int,
		@Day int,
		@Hour int,
		@Min int,
		@Sec int

		SELECT @DiffInSec = DATEDIFF(s, @StartTime, COALESCE(@ErrorTime, @EndTime, GETDATE()))

		IF @DiffInSec < 0 SELECT @ExecutionTime = 'Invalid time frame.'
		ELSE  
			BEGIN 
				SELECT 
					@Day = @DiffInSec / 86400,
					@Hour = (@DiffInSec % 86400) / 3600,
					@Min = ((@DiffInSec % 86400) % 3600) / 60,
					@Sec = ((@DiffInSec % 86400) % 3600) % 60
        
				--SELECT 
				--	@Day = DATEDIFF(dd, @StartTime, COALESCE(@ErrorTime, @EndTime, GETDATE())),
				--	@Hour = DATEDIFF(hh,  @StartTime, COALESCE(@ErrorTime, @EndTime, GETDATE())) - DATEDIFF(dd, @StartTime, COALESCE(@ErrorTime, @EndTime, GETDATE())) * 24,
				--	@Min = DATEDIFF(mi, @StartTime, COALESCE(@ErrorTime, @EndTime, GETDATE())) - DATEDIFF(hh, @StartTime, COALESCE(@ErrorTime, @EndTime, GETDATE())) * 60,
				--	@Sec = DATEDIFF(ss, @StartTime, COALESCE(@ErrorTime, @EndTime, GETDATE())) - DATEDIFF(mi, @StartTime, COALESCE(@ErrorTime, @EndTime, GETDATE())) * 60


				IF @Day <> 0 SELECT @ExecutionTime = CONVERT(nvarchar(15), @Day) + ' day(s) '
				IF @Hour <> 0 SELECT @ExecutionTime = @ExecutionTime + CONVERT(nvarchar(15), @Hour) + ' hr(s) '
				IF @Min <> 0 AND @Day = 0 SELECT @ExecutionTime = @ExecutionTime + CONVERT(nvarchar(15), @Min) + ' min(s) '
				IF @Sec <> 0 AND @Day = 0 AND @Hour = 0 SELECT @ExecutionTime = @ExecutionTime + CONVERT(nvarchar(15), @Sec) + ' sec(s) '
				IF LEN(@ExecutionTime) = 0 SELECT @ExecutionTime = 'Less than 1 sec.'
			END

	RETURN(@ExecutionTime)
END
GO
