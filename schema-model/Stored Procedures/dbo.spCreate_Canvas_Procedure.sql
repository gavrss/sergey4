SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spCreate_Canvas_Procedure] 
            @ApplicationID int = NULL,
            @Debug bit = 0,
            @JobID int = 0,
            @Encryption smallint = 1,
            @GetVersion bit = 0,
            @Duration time(7) = '00:00:00' OUT,
            @Deleted int = 0 OUT,
            @Inserted int = 0 OUT,
            @Updated int = 0 OUT 

--#WITH ENCRYPTION#--
AS

--EXEC [spCreate_Canvas_Procedure] @ApplicationID = 400, @Debug = true

DECLARE
    @StartTime datetime,
    @Step nvarchar(255),
    @JobLogID int,
    @ErrorNumber int,
    @DestinationDatabase nvarchar(100),
    @SQLStatement nvarchar(max),
    @Action nvarchar(10),
	@InstanceID int,
    @Description nvarchar(255),
    @Version nvarchar(50) = '1.4.0.2136'

IF @GetVersion <> 0
	BEGIN
		IF @Version = '1.2.2052' SET @Description = 'Version handling.'
		IF @Version = '1.2.2053' SET @Description = 'Procedures changed.'
		IF @Version = '1.2.2056' SET @Description = 'Procedures changed.'
		IF @Version = '1.2.2058' SET @Description = 'Procedures changed.'
		IF @Version = '1.2.2059' SET @Description = 'Procedures changed.'
		IF @Version = '1.2.2063' SET @Description = 'Procedures changed.'
		IF @Version = '1.2.2067' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2073' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2074' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2075' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2076' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2077' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2079' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2081' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2082' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2083' SET @Description = 'Added parameter @Encryption'
		IF @Version = '1.3.2092' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2097' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2101' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2102' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2103' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2104' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2106' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2107' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2110' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2111' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2112' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2113' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.2117' SET @Description = 'Canvas_LST_Menu changed by JaWo. Sales_Admin added.'
		IF @Version = '1.3.0.2118' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.0.2119' SET @Description = 'Procedures changed.'
		IF @Version = '1.3.1.2121' SET @Description = 'Procedures changed.'
		IF @Version = '1.4.0.2127' SET @Description = 'Built for Callisto 4.'
		IF @Version = '1.4.0.2128' SET @Description = 'Handle case sensitive.'
		IF @Version = '1.4.0.2129' SET @Description = 'Procedures changed.'
		IF @Version = '1.4.0.2131' SET @Description = 'Procedures changed.'
		IF @Version = '1.4.0.2132' SET @Description = 'Procedures changed.'
		IF @Version = '1.4.0.2133' SET @Description = 'Procedures changed.'
		IF @Version = '1.4.0.2135' SET @Description = 'Removed hardcoded references to BusinessProcesses in AR/AP. Canvas_FxTrans removed.'
		IF @Version = '1.4.0.2136' SET @Description = 'Encryption handled for Canvas_Max_Voucher.'

        SELECT [Version] =  @Version, [Description] = @Description
        RETURN
	END

IF @ApplicationID IS NULL
    BEGIN
        PRINT 'Parameter @ApplicationID must be set'
        RETURN 
    END

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = GETDATE()

	SET @Step = 'Check if the procedures are needed or not'
		IF (SELECT COUNT(1) FROM Model WHERE BaseModelID IN (-7, -8) AND ApplicationID = @ApplicationID) = 0
            RETURN

	SET @Step = 'Set procedure variables'
		EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT
		SELECT
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0)

		SELECT
			@InstanceID = A.InstanceID,
			@DestinationDatabase = DestinationDatabase
		FROM
			[Application] A
		WHERE
			ApplicationID = @ApplicationID

		SELECT
			@JobID = CASE WHEN @JobID = 0 THEN @InstanceID ELSE @JobID END

	SET @Step = 'CREATE TABLE #Object'
		CREATE TABLE #Object
            (
			ObjectType nvarchar(100) COLLATE DATABASE_DEFAULT,
			ObjectName nvarchar(100) COLLATE DATABASE_DEFAULT
			)

		TRUNCATE TABLE #Object

		SET @SQLStatement = 'SELECT ObjectType = ''Procedure'', ObjectName = sp.name FROM ' + @DestinationDatabase + '.sys.procedures sp'
		INSERT INTO #Object (ObjectType, ObjectName) EXEC (@SQLStatement)

--==========================================================================================================================================
--==========================================================================================================================================
--==========================================================================================================================================


/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_Calculate_Aging]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_AR_AP_Calculate_Aging'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_AR_AP_Calculate_Aging') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_AR_AP_Calculate_Aging]
@AR_AP Nvarchar(2) = ''''AR'''',
@ETL Bit = 0
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

--DECLARE @AR_AP Nvarchar(2) ,@ETL Bit = 0
--Set @AR_Ap = ''''AR''''
--Set @ETL = 0


	If @ETL <> 0 Select * into #Temp_ParameterValues From Wrk_ETL_Values Where Proc_Name = ''''Canvas_AR_AP_Calculate_Aging''''

	Declare @Sign Nvarchar(2),@InvoiceDim Nvarchar(50),@ClientDim Nvarchar(50),@AgingDim Nvarchar(50)
	SET @Sign = ''''1''''

	--DECLARE @ScenarioID NVARCHAR(255),@TimeID NVARCHAR(255),@Entity INT,@Account INT,@Invoice INT,@EntityID NVARCHAR(255),@ret bigint,@Alldim_Memberid Nvarchar(Max)
	DECLARE @Scenario INT,@Time INT,@User Nvarchar(50),@modelname nvarchar(200),@Businessprocess BIGINT,@BusinessprocessDim Nvarchar(50)
	DECLARE @Account_Invoiced_ID NVARCHAR(255),@Account_Due_ID NVARCHAR(255),@Account_DueOverDue_ID NVARCHAR(255),@Account_Paid_ID NVARCHAR(255)
	,@Account_AVG_Due_Day_ID NVARCHAR(255),@Account_AVG_Open_Day_ID NVARCHAR(255),@Account_DSO_ID NVARCHAR(255),@Account_Opening_ID NVARCHAR(255)
	,@lap int,@scenarioDim Nvarchar(50),@TimeDim Nvarchar(50),@AccountDim Nvarchar(50),@EntityDim Nvarchar(50), @DimLabel Nvarchar(50)
	,@DimType Nvarchar(50),@Sql Nvarchar(Max),@Found int,@Alldim Nvarchar(Max),@Otherdim Nvarchar(Max),@Sep Nvarchar(2)

	Select @user = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''UserId''''
	Select @ModelName = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''Model''''

	DECLARE     @Proc_Id BIGINT
    SELECT @Proc_ID = MAX(Proc_Id) FROM Canvas_User_Run_Status
    IF @Proc_ID IS NULL  SET @Proc_ID = 0
    SET @Proc_ID = @Proc_Id + 1
    declare @userid int
    Select @Userid =  UserId from Canvas_Users Where label = @user

    INSERT INTO Canvas_User_Run_Status  
    ([User_RecordId],[User],[Proc_Id],[Proc_Name],[Begin_Date],[End_Date])
    VALUES (@Userid,@User,@Proc_Id,''''calculate_Aging'''',GETDATE(),'''''''') 
	
	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0

	SET @Lap = 1  

	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin ' 


			SET @SQLStatement = @SQLStatement + '

		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''
		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''InvoiceNo''''
		begin
			set @InvoiceDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end 

		if @DimType = ''''Customer''''
		begin
			set @ClientDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '


		if @DimType = ''''Supplier''''
		begin
			set @ClientDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end		if @DimType = ''''Aging''''
		begin
			set @AgingDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType

	end
	close Dim_cursor
	deallocate Dim_cursor 


	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')

	Set @Alldim = @Alldim + '''',[TimeDataView] ''''

	Create table #FactData (Value Float)
	SET @Sql = ''''ALTER TABLE #FactData ADD ''''+Replace(@Alldim,'''']'''',''''_Memberid] BIGINT'''')
	--Print(@Sql)
	EXEC(@Sql)

	Create Table #TempLabel (label Nvarchar(255))
	Create Table #Temp (Memberid BigINT)
	Create Table #Account (memberid BIGINT,label Nvarchar(255),KeyName_Account nvarchar(255))

	Truncate Table #temp
	Set @sql = ''''INsert into #Temp select memberid from [DS_''''+@ScenarioDim+''''] Where label  = ''''''''ACTUAL'''''''' '''' 
	EXEC(@Sql)
	select @Scenario = Memberid From #Temp

	Truncate Table #temp
	Set @sql = ''''INsert into #Temp select memberid from [DS_''''+@BusinessprocessDim+'''']'''' --Where label  in (''''''''E9'''''''',''''''''E10'''''''',''''''''iSCALA'''''''')
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


	Select @Businessprocess = Memberid From #Temp

		Set @sql = ''''INsert into #Account 
		select memberid,label,KeyName_Account from [DS_''''+@AccountDim+''''] 
		Where KeyName_Account IN (''''''''Invoiced_'''' + @AR_AP+'''''''''''',''''''''Due_'''' + @AR_AP+'''''''''''',''''''''DueOverDue_'''' + @AR_AP+'''''''''''',''''''''Paid_'''' + @AR_AP+'''''''''''',''''''''Opening_'''' + @AR_AP+'''''''''''') 
		UNION ALL
		select memberid,label,KeyName_Account from [DS_''''+@AccountDim+''''] 
		Where KeyName_Account IN (''''''''AVG_Due_Day'''''''',''''''''AVG_Open_Day'''''''',''''''''DSO'''''''')	'''' 
	--Print(@Sql)
	EXEC(@Sql) 

	Select @Account_Invoiced_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''Invoiced_'''' + @AR_AP
	Select @Account_Due_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''Due_'''' + @AR_AP
	Select @Account_DueOverDue_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''DueOverDue_'''' + @AR_AP
	Select @Account_Paid_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''Paid_'''' + @AR_AP
	Select @Account_Opening_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''Opening_'''' + @AR_AP
	Select @Account_AVG_Due_Day_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''AVG_Due_Day''''
	Select @Account_AVG_Open_Day_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''AVG_Open_Day''''
	Select @Account_DSO_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''DSO''''

	Declare @TodayDate Nvarchar(8),@TodayDateID Nvarchar(10)
	Create Table #time (MemberID BIGINT)
	

	DECLARE @Year Nvarchar(4),@PYear Nvarchar(4)
	SET  @Sql = ''''Insert Into #tempLabel Select label From [DS_''''+@TimeDim+''''] Where Memberid in (Select memberid from #Time)''''
	EXEC(@Sql)


	Set @TodayDate =  (year(getdate())*10000)+Month(getdate())*100+Day(getdate())

	--Select @TodayDate = label From #TempLabel
	SET @Year = LEFT(@TodayDate,4)
	SET @PYear = CAST( @Year as int) - 1

	Truncate Table #temp
	Set @sql = ''''INsert into #TEmp select Memberid From DS_''''+@TimeDim+'''' Where Label = ''''''''''''+@TodayDate+''''''''''''''''
	Exec(@Sql)
	Select @TodayDateID = Memberid From #Temp

	

	Declare @Mindate INT
	Set @mindate = (CAST(left(@todaydate,6) as INT)) * 100

	Set @Sql = ''''DELETE FROM FACT_''''+@ModelName+''''_default_partition
	WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
--	and ''''+@InvoiceDim+''''_Memberid in (select memberid from DS_''''+@InvoiceDim+'''' Where Paid = ''''''''N'''''''') 
	and ''''+@EntityDim+''''_Memberid in (Select Memberid from #Temp_ParameterValues Where parameterName = ''''''''EntityMbrs'''''''')
	and ''''+@TimeDim+''''_Memberid in (Select Memberid from #Temp_ParameterValues Where parameterName = ''''''''TimeMbrs'''''''')
	And [''''+@AccountDim+''''_Memberid] IN (''''+@Account_DueOverDue_ID+'''')  
--	And [''''+@TimeDim+''''_Memberid] in (Select memberid from DS_''''+@TimeDim+'''' Where len(Label) = 8 and  CAST(Label as INT) >= ''''+CAst(@mindate as char)+'''' And CAST(Label as INT) <= ''''+@todaydate+'''')''''
	EXEC(@Sql)  ' 


			SET @SQLStatement = @SQLStatement + '


	Create Table #InvoiceNumber 
	(InvoiceNumber_memberid BIGINT, Value Float, timelabel nvarchar(255),DueLabel nvarchar(255),TodayDate Nvarchar(255),NumDay INT,client_Memberid BIGINT,Entity_Memberid BIGINT)
	
	DECLARE @maxdate Nvarchar(8)
	SEt @maxdate = YEAR(DATEADD(day,120, @todaydate))*10000 + MONTH(DATEADD(day,120, @todaydate))*100 + DAY(DATEADD(day,120, @todaydate))

	Set @Sql = ''''Insert into #InvoiceNumber
	Select Distinct a.''''+@InvoiceDim+''''_memberid,0
	,c.label
	,''''''''''''''''
	,''''''''''''+@TodayDate+''''''''''''
	,0 
	,''''+@ClientDim+''''_Memberid
	,''''+@EntityDim+''''_Memberid
	From FACT_''''+@ModelName+''''_default_partition a,  [DS_''''+@TimeDim+''''] c   
	WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
	and ''''+@InvoiceDim+''''_Memberid in (select memberid from DS_''''+@InvoiceDim+'''' Where paid = ''''''''N'''''''') 
	and ''''+@EntityDim+''''_Memberid in (Select Memberid from #Temp_ParameterValues Where parameterName = ''''''''EntityMbrs'''''''')
	And a.[''''+@AccountDim+''''_Memberid] = ''''+@Account_Due_ID+''''
	And a.[''''+@TimeDim+''''_Memberid] = c.Memberid 
	And a.[''''+@TimeDim+''''_Memberid] in (Select memberid from DS_''''+@TimeDim+'''' Where Label <= ''''''''''''+@MaxDate+'''''''''''')
	And a.[''''+@modelname+''''_Value] <> 0 ''''
	PRINT(@Sql)
	EXEC(@Sql) 

	update #InvoiceNumber set numday = DATEDIFF(day, Todaydate, Timelabel)
	ALTER TABLE #InvoiceNumber ADD [Account_Memberid] BIGINT,Aging_memberid BIGINT
	Update #InvoiceNumber SET  [Account_Memberid] = @Account_DueOverDue_ID 

	SET @Sql = ''''Update #InvoiceNumber Set Aging_memberid = b.memberid From #InvoiceNumber a,Ds_''''+@AgingDim+'''' b
	Where a.NumDay >= b.FromDay and a.NumDay <= b.ToDay
	And b.FromDay <> b.ToDay ''''
	--Print(@Sql)
	EXEC(@Sql)

	SET @Sql = ''''Update #InvoiceNumber Set Aging_memberid = -1 Where Aging_memberid IS NULL ''''
	--Print(@Sql)
	EXEC(@Sql)

	DECLARE @Select nvarchar(max)

	SEt @Select = Replace(Replace(@Alldim,'''']'''',''''_Memberid]''''),''''['''',''''a.['''')
	SET @Select = Replace(@Select,''''a.[''''+@AgingDim+''''_memberid]'''',''''b.[Aging_memberid]'''')
	SET @Select = Replace(@Select,''''a.[''''+@AccountDim+''''_memberid]'''',''''b.[Account_memberid]'''')

	Set @Sql = ''''Insert into #FactData    
	Select 
	a.''''+@ModelName+''''_Value
	,''''+@Select+'''' 
	From FACT_''''+@ModelName+''''_default_partition a, #Invoicenumber b, [DS_''''+@TimeDim+''''] c   
	WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
	--And Aging_Memberid not in (select memberid from DS_Aging Where label = ''''''''Not Due'''''''')  
	and a.''''+@EntityDim+''''_Memberid in (Select Memberid from #Temp_ParameterValues Where parameterName = ''''''''EntityMbrs'''''''')
	and a.''''+@EntityDim+''''_Memberid = b.Entity_Memberid
	And a.[''''+@AccountDim+''''_Memberid] = ''''+@Account_Invoiced_ID+''''  
	And a.''''+@InvoiceDim+''''_memberid = b.InvoiceNumber_Memberid
	And a.[''''+@TimeDim+''''_Memberid] = c.Memberid 
	And a.[''''+@TimeDim+''''_Memberid] in (Select memberid from DS_''''+@TimeDim+'''' Where Label <= ''''''''''''+@TodayDate+'''''''''''')''''
	--PRINT(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''Update #factData Set ''''+@BusinessProcessDim+''''_Memberid = b.Memberid, ''''+@TimeDim+''''_Memberid = ''''+@TodayDateID+''''  
	From #FactData a, DS_''''+@BusinessProcessDim +'''' b Where b.label = ''''''''Input'''''''' ''''
	Exec(@Sql)

	Select Distinct INvoiceNumber_memberid, Aging_memberid into #Invoice From #InvoiceNumber 


 	Set @Sql = ''''INsert Into FACT_''''+@ModelName+''''_default_partition 
	(''''+@ModelName+''''_Value,''''+Replace(@Alldim,'''']'''',''''_Memberid]'''')+'''',[ChangeDateTime],userId)
	SELECT Sum(Value),''''+Replace(@Alldim,'''']'''',''''_Memberid]'''')+'''',GETDATE(),''''''''''''+@USer+''''''''''''
	From #FactData
	Group By ''''+Replace(@Alldim,'''']'''',''''_Memberid]'''')
	--PRINT(@Sql)
	EXEC(@Sql)
	
--======================================================================> DEBUT DAYS
	Set @Sql = ''''DELETE FROM FACT_''''+@ModelName+''''_default_partition
	WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
	and ''''+@EntityDim+''''_Memberid in (Select Memberid from #Temp_ParameterValues Where parameterName = ''''''''EntityMbrs'''''''')
	And [''''+@AccountDim+''''_Memberid] IN (''''+@Account_AVG_Due_Day_ID+'''',''''+@Account_AVG_Open_Day_ID+'''',''''+@Account_DSO_ID+'''')  
	And [''''+@TimeDim+''''_Memberid] in (Select memberid from DS_''''+@TimeDim+'''' Where len(Label) = 8 and  CAST(Label as INT) >= ''''+CAst(@mindate as char)+'''' And CAST(Label as INT) <= ''''+@todaydate+'''')''''
	--PRINT(@Sql)
	EXEC(@Sql)
	
--===========================================> Calculation AVG Number of day (Due)
	Create table #TempFact 
	(InvoiceNumber_memberid BIGINT, timelabel nvarchar(255),TodayDate Nvarchar(255),client_Memberid BIGINT,Account_memberid BIGINT,Entity_memberid BIGINT)

	Truncate table #invoiceNumber
	Set @Sql = ''''Insert into #TempFact
	Select Distinct a.''''+@InvoiceDim+''''_memberid,
	c.label
	,''''''''''''+@TodayDate+''''''''''''
	,''''+@ClientDim+''''_Memberid
	,Account_memberid
	,''''+@EntityDim+''''_Memberid
	From FACT_''''+@ModelName+''''_default_partition a,  [DS_''''+@TimeDim+''''] c   
	WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
	and ''''+@EntityDim+''''_Memberid in (Select Memberid from #Temp_ParameterValues Where parameterName = ''''''''EntityMbrs'''''''')
	And a.[''''+@AccountDim+''''_Memberid] in (''''+@Account_Invoiced_ID+'''')
	And a.[''''+@TimeDim+''''_Memberid] = c.Memberid 
	And a.[''''+@TimeDim+''''_Memberid] in (Select memberid from DS_''''+@TimeDim+'''' Where Label <= ''''''''''''+@TodayDate+'''''''''''' And left(label,4) in (''''''''''''+@Year+'''''''''''',''''''''''''+@PYear+''''''''''''))
	And a.[''''+@modelname+''''_Value] <> 0 ''''
	--PRINT(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


	Set @Sql = ''''Insert into #TempFact
	Select Distinct a.''''+@InvoiceDim+''''_memberid,
	c.label
	,''''''''''''+@TodayDate+''''''''''''
	,''''+@ClientDim+''''_Memberid
	,Account_memberid
	,''''+@EntityDim+''''_Memberid
	From FACT_''''+@ModelName+''''_default_partition a,  [DS_''''+@TimeDim+''''] c   
	WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
	and ''''+@EntityDim+''''_Memberid in (Select Memberid from #Temp_ParameterValues Where parameterName = ''''''''EntityMbrs'''''''')
	And a.[''''+@AccountDim+''''_Memberid] in (''''+@Account_Due_ID+'''',''''+@Account_paid_ID+'''')
	And a.[''''+@TimeDim+''''_Memberid] = c.Memberid 
	And a.[''''+@TimeDim+''''_Memberid] in (Select memberid from DS_''''+@TimeDim+'''' Where Label <= ''''''''''''+@TodayDate+'''''''''''' And left(label,4) = ''''''''''''+@Year+'''''''''''')
	And a.[''''+@modelname+''''_Value] <> 0 ''''
	--PRINT(@Sql)
	EXEC(@Sql)

	Set @Sql = ''''Insert into #InvoiceNumber
	Select Distinct a.invoicenumber_memberid,0
	,a.timelabel
	,b.Timelabel
	,a.TodayDate
	,0 
	,a.Client_Memberid
	,a.''''+@EntityDim+''''_Memberid
	,0
	,0
	From #tempFACT a, #tempFACT b
	WHERE a.InvoiceNumber_Memberid = b.InvoiceNumber_Memberid
	And a.[''''+@EntityDim+''''_Memberid] = b.[''''+@EntityDim+''''_Memberid]
	And a.[''''+@AccountDim+''''_Memberid] = ''''+@Account_Invoiced_ID+''''
	And b.[''''+@AccountDim+''''_Memberid] = ''''+@Account_Due_ID
	--PRINT(@Sql)
	EXEC(@Sql) 


	update #InvoiceNumber set numday = DATEDIFF(day,Timelabel , Duelabel)


	Create Table #TempClient
	(InvoiceNumber_memberid BIGINT, NumDay INT,client_Memberid BIGINT,Entity_Memberid BIGINT)

	Create Table #ClientNB
	(Client_memberid BIGINT, NB INT)

	Create Table #Client
	(Client_memberid BIGINT, NumDay INT,NB INT,AVGDay INT,Entity_Memberid BIGINT) ' 


			SET @SQLStatement = @SQLStatement + '


	Insert into #Tempclient	Select Distinct InvoiceNumber_memberid, NumDay ,client_Memberid,Entity_Memberid  from #InvoiceNumber
	If @@ROWCOUNT > 0
	BEGIN
		insert into #clientNB select client_memberid,count(*) from #Tempclient
		group by client_memberid

		INSERT INTO #Client 
		Select a.Client_memberid,Sum(a.Numday),b.NB,0,a.Entity_Memberid
		From #tempClient a,#ClientNB b
		Where a.client_memberid = b.client_memberid
		group by a.Client_memberid,b.NB,a.Entity_Memberid 


		Insert into #Client Select -1,Sum(NumDay),sum(NB),Sum(AVGDay),Entity_Memberid from #Client Group By Entity_Memberid

		update #client set AVGDay = Numday / NB

		Set @Sql = ''''INsert Into FACT_''''+@ModelName+''''_default_partition 
		(''''+@ModelName+''''_Value 
		,[''''+@ScenarioDim+''''_Memberid]
		,[''''+@TimeDim+''''_Memberid]
		,[''''+@EntityDim+''''_Memberid]
		,[''''+@AccountDim+''''_Memberid]
		,[''''+@BusinessprocessDim+''''_Memberid]
		,[''''+@ClientDim+''''_Memberid]
		,[ChangeDateTime]
		,[TimeDataview_memberid]
		,userId)
		SELECT 
		AVGDay * ''''+@Sign+'''' 
		,''''+CAST(@Scenario as char)+''''
		,''''+@TodayDateID+''''
		,Entity_Memberid
		,''''+@Account_AVG_Due_Day_ID+''''
		,''''+CAST(@Businessprocess as Char)+''''
		,[Client_Memberid]
		,GETDATE()
		,4
		,''''''''''''+@USer+''''''''''''
		From #Client ''''
		--Print(@Sql)
		EXEC(@Sql)

	END
--===========================================> Calculation AVG Number of day (Open)

	TRUNCATE tABLE #InvoiceNumber ' 


			SET @SQLStatement = @SQLStatement + '


	Set @Sql = ''''Insert into #InvoiceNumber
	Select Distinct a.InvoiceNumber_memberid,0
	,a.timelabel
	,b.Timelabel
	,a.TodayDate
	,0 
	,a.Client_Memberid
	,a.''''+@EntityDim+''''_Memberid
	,0
	,0
	From #tempFACT a, #tempFACT b
	WHERE a.InvoiceNumber_Memberid = b.InvoiceNumber_Memberid
	And a.[''''+@EntityDim+''''_Memberid] = b.[''''+@EntityDim+''''_Memberid]
	And a.[''''+@AccountDim+''''_Memberid] = ''''+@Account_Invoiced_ID+''''
	And b.[''''+@AccountDim+''''_Memberid] = ''''+@Account_PAID_ID
	--PRINT(@Sql)
	EXEC(@Sql)

	update #InvoiceNumber set numday = DATEDIFF(day,Timelabel , Duelabel)

	TRUNCATE Table #TempClient
	TRUNCATE Table #ClientNB
	TRUNCATE Table #Client

	Insert into #Tempclient	Select Distinct InvoiceNumber_memberid, NumDay ,client_Memberid,Entity_Memberid  from #InvoiceNumber
	IF @@ROWCOUNT > 0
	BEGIN

		insert into #clientNB select client_memberid,count(*) from #Tempclient
		group by client_memberid 


		INSERT INTO #Client 
		Select a.Client_memberid,Sum(a.Numday),b.NB,0,a.Entity_Memberid
		From #tempClient a,#ClientNB b
		Where a.client_memberid = b.client_memberid
		group by a.Client_memberid,b.NB,a.Entity_Memberid


		Insert into #Client Select -1,Sum(NumDay),sum(NB),Sum(AVGDay),Entity_Memberid from #Client Group by Entity_Memberid

		update #client set AVGDay = Numday / NB ' 


			SET @SQLStatement = @SQLStatement + '

		Set @Sql = ''''INsert Into FACT_''''+@ModelName+''''_default_partition 
		(''''+@ModelName+''''_Value
		,[''''+@ScenarioDim+''''_Memberid]
		,[''''+@TimeDim+''''_Memberid]
		,[''''+@EntityDim+''''_Memberid]
		,[''''+@AccountDim+''''_Memberid]
		,[''''+@BusinessprocessDim+''''_Memberid]
		,[''''+@ClientDim+''''_Memberid]
		,[ChangeDateTime]
		,[TimeDataview_memberid]
		,userId)
		SELECT 
		AVGDay * ''''+@Sign+'''' 
		,''''+CAST(@Scenario as char)+''''
		,''''+@TodayDateID+''''
		,Entity_Memberid
		,''''+@Account_AVG_Open_Day_ID+''''
		,''''+CAST(@Businessprocess as Char)+''''
		,[Client_Memberid]
		,GETDATE()
		,4
		,''''''''''''+@USer+''''''''''''
		From #Client ''''
		--Print(@Sql)
		EXEC(@Sql)
	END 

--===========================================> Calculation DSO
	Truncate table #TempFact 
	Truncate table #invoiceNumber
	
	Set @Sql = ''''Insert into #InvoiceNumber
	Select Distinct 
	a.''''+@InvoiceDim+''''_memberid
	,a.''''+@ModelName+''''_Value 
	,c.label
	,''''''''''''''''
	,''''''''''''+@TodayDate+''''''''''''
	,0 
	,a.''''+@ClientDim+''''_Memberid
	,a.''''+@EntityDim+''''_Memberid
	,a.[''''+@AccountDim+''''_memberid]
	,0
	From FACT_''''+@ModelName+''''_default_partition a,  [DS_''''+@TimeDim+''''] c   
	WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
	and ''''+@EntityDim+''''_Memberid in (Select Memberid from #Temp_ParameterValues Where parameterName = ''''''''EntityMbrs'''''''')
--	And a.[''''+@AccountDim+''''_Memberid] in (''''+@Account_Invoiced_ID+'''',''''+@Account_Paid_ID+'''',''''+@Account_Opening_ID+'''')
	And a.[''''+@AccountDim+''''_Memberid] in (''''+@Account_Invoiced_ID+'''',''''+@Account_Paid_ID+'''')
	And a.[''''+@TimeDim+''''_Memberid] = c.Memberid 
	And a.[''''+@TimeDim+''''_Memberid] in (Select memberid from DS_''''+@TimeDim+'''' Where Label <= ''''''''''''+@TodayDate+'''''''''''' And left(label,4) in (''''''''''''+@year+'''''''''''',''''''''''''+@year+''''''''''''))
	And a.[''''+@modelname+''''_Value] <> 0 ''''
	--PRINT(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


	update #InvoiceNumber set numday = DatePart("y",Todaydate) 

	truncate Table #TempClient
	Truncate Table #ClientNB
	Truncate Table #Client

	Create Table #DSO
	(Client_memberid BIGINT, balance Float, sales float, numday int,Entity_memberid BIGINT) 

	INSERT INTO #DSO
	Select Client_memberid , SUM(balance) as balance , SUM(sales) as Sales , numday, Entity_Memberid
	From (
	Select Client_memberid , Value as balance , 0 as Sales , numday, Entity_Memberid
	From #InvoiceNumber 
	UNION ALL
	Select Client_memberid , 0 as balance , value as Sales , numday, Entity_Memberid
	From #InvoiceNumber 
	Where Account_memberid = @Account_Invoiced_ID
	) as Tmp Group by
	client_memberid,numday,Entity_Memberid

	ALTER TABLE #DSO ADD Value Float
	
	Update #DSO set Value =  0
	
	Insert into #DSO Select -1,Sum(Balance),sum(Sales),NumDay ,Sum(Value),Entity_Memberid from #DSO
	Group by numday,Entity_Memberid

	Update #DSO set Value = (balance * Numday) / sales Where sales <> 0  ' 

			SET @SQLStatement = @SQLStatement + '

	Set @Sql = ''''INsert Into FACT_''''+@ModelName+''''_default_partition 
	(''''+@ModelName+''''_Value ,[''''+@ScenarioDim+''''_Memberid] ,[''''+@TimeDim+''''_Memberid]	,[''''+@EntityDim+''''_Memberid]	,[''''+@AccountDim+''''_Memberid]
	,[''''+@BusinessprocessDim+''''_Memberid]	,[''''+@ClientDim+''''_Memberid]	,[ChangeDateTime]	,[TimeDataview_memberid]	,userId)
	SELECT 	Value * ''''+@Sign+'''' ,''''+CAST(@Scenario as char)+'''',''''+@TodayDateID+'''',Entity_Memberid,''''+@Account_DSO_ID+'''',''''+CAST(@Businessprocess as Char)+''''
	,[Client_Memberid],GETDATE(),4,''''''''''''+@USer+''''''''''''
	From #DSO ''''
	--Print(@Sql)
	EXEC(@Sql)
	
	If @ETL = 0 
	BEGIn
		if not exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = ''''Wrk_ETL_Values'''')  
		BEGIN

			CREATE TABLE [dbo].[Wrk_ETL_Values](
				[ParameterName] [nvarchar](255) NULL,
				[MemberId] [bigint] NULL,
				[StringValue] [nvarchar](512) NULL,
				[Proc_Name] [nvarchar](512) NULL
			) ON [PRIMARY]
		END
		INSERT INTO [Wrk_ETL_Values] 
		([ParameterName],[MemberId],[StringValue],[Proc_Name])
		Select [ParameterName],[MemberId],[StringValue],''''Canvas_AR_AP_PayedInvoice'''' From #Temp_ParameterValues
	END
	ELSE
	BEGIn
		Update [Wrk_ETL_Values] Set Proc_Name = ''''Canvas_AR_AP_PayedInvoice''''
	END
	
	Execute Canvas_AR_AP_PayedInvoice @AR_AP,1
	
    UPDATE Canvas_User_Run_Status SET END_Date = GETDATE() WHERE Proc_Id = @Proc_Id
END  '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

-- Drop table #temp,#DSO,#factdata,#templabel,#account,#time,#invoiceNumber,#Client,#ClientNB,#Invoice,#TempClient,#tempfact



/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_Copy_Opening]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_AR_AP_Copy_Opening'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_AR_AP_Copy_Opening') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_AR_AP_Copy_Opening]
@AR_AP Nvarchar(2) = ''''AR'''',
@ETL Bit = 0
--	@ModelName as nvarchar(255) = ''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	--DECLARE @TimeID NVARCHAR(255),@ScenarioID NVARCHAR(255),@Businessprocess INT,@Time INT,@Entity INT,@Account INT,@Invoice INT,@EntityID NVARCHAR(255),@Alldim_Memberid Nvarchar(Max)
	DECLARE @Scenario INT,@User Nvarchar(50),@modelname nvarchar(200),@BusinessprocessDim Nvarchar(50),@InvoiceDim Nvarchar(50)	
	DECLARE @Account_Invoiced_ID NVARCHAR(255),@Account_Opening_ID NVARCHAR(255),@Account_Paid_ID NVARCHAR(255),@lap int,@ret BIGINT
	,@scenarioDim Nvarchar(50),@TimeDim Nvarchar(50),@AccountDim Nvarchar(50),@EntityDim Nvarchar(50),@DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max)
	,@Found int,@Alldim Nvarchar(Max),@Otherdim Nvarchar(Max),@Sep Nvarchar(2)

	If @ETL <> 0 Select * into #Temp_ParameterValues From Wrk_ETL_Values Where Proc_Name = ''''Canvas_AR_AP_Copy_Opening''''

	Select @user = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''
	Select @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''

	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0 ' 


			SET @SQLStatement = @SQLStatement + '

	DECLARE @Proc_Id BIGINT 
	SELECT @Proc_ID = MAX(Proc_Id) FROM Canvas_User_Run_Status
	IF @Proc_ID IS NULL  SET @Proc_ID = 0
	SET @Proc_ID = @Proc_Id + 1
	declare @userid int
	Select @Userid =  UserId from Canvas_Users Where label = @user
	INSERT INTO Canvas_User_Run_Status
	([User_RecordId],[User],[Proc_Id],[Proc_Name],[Begin_Date],[End_Date])
	VALUES (@Userid,@User,@Proc_Id,''''Copy_opening'''',GETDATE(),'''''''') 

	SET @Lap = 1 
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''

		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1 ' 


			SET @SQLStatement = @SQLStatement + '

		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Number''''
		begin
			set @InvoiceDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType

	end
	close Dim_cursor
	deallocate Dim_cursor ' 


			SET @SQLStatement = @SQLStatement + '


	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')

	Set @Alldim = @Alldim + '''',[TimeDataView] ''''

	Create table #FactData (Value Float)
	SET @Sql = ''''ALTER TABLE #FactData ADD ''''+Replace(@Alldim,'''']'''',''''_Memberid] BIGINT'''')
	Print(@Sql)
	EXEC(@Sql)

	Select * Into #FactFinal from #Factdata
	
	Create Table #Account (memberid BIGINT,label Nvarchar(255),KeyName_Account nvarchar(255))
	Create Table #tempTime (memberid BIGINT,label Nvarchar(255),Source_memberid BIGINT,Source_Label Nvarchar(255))
	Create Table #Time (memberid BIGINT,label Nvarchar(255),Source_memberid BIGINT,Source_Label Nvarchar(255))
	Create Table #Temp (MemberID BIGINT)
	Create Table #TempLabel (Label Nvarchar(255))
	
	Truncate table #temp
	Set @Sql = ''''Insert Into #temp Select memberid from DS_''''+@ScenarioDim+'''' Where Label = ''''''''ACTUAL'''''''' ''''
	EXEC(@Sql)
	select @Scenario = Memberid From #temp
	
	Set @sql = ''''INsert into #Account select memberid,label,KeyName_Account from [DS_''''+@AccountDim+''''] Where KeyName_Account IN (''''''''Invoiced_''''+@AR_AP+'''''''''''',''''''''Paid_''''+@AR_AP+'''''''''''',''''''''Opening_''''+@AR_AP+'''''''''''')'''' 
	--Print(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '

	--Truncate table #temp

	Select @Account_Invoiced_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''Invoiced_''''+@AR_AP
	Select @Account_Paid_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''Paid_''''+@AR_AP
	Select @Account_opening_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''Opening_''''+@AR_AP

	DECLARE @Year Nvarchar(4),@PYear Nvarchar(4),@TodayDate Nvarchar(8), @TodayDATEiD Nvarchar(10)

	SET @Sql = ''''INsert into #TempLabel Select Label from DS_''''+@Timedim+'''' 
	Where memberid in (Select memberid From #temp_parametervalues Where parameterName = ''''''''TimeMbrs'''''''')''''
	Print(@Sql)
	EXEC(@Sql)

	SELECT @TodayDate = Label from #TempLabel
	
	SET @TodayDate = RTRIM(LTRIM(@TodayDate))
	SET @TodayDate = LEFT(@TodayDate,4)+''''0101'''' 
	SET @Year = LEFT(@Todaydate,4)
	SET @PYear = @year - 1

	Set @Sql = ''''INsert into #temptime select Distinct 0,''''+@TodayDate+'''',0,label 
	From DS_''''+@TimeDim+'''' Where LEN(Label) = 8 and LEFT(Label,4) = ''''''''''''+@Pyear+'''''''''''' ''''
	PRINT(@Sql)
	EXEC(@Sql)

	Set @sql = ''''INsert into #time select 0,a.label,b.memberid,b.label from #temptime a,DS_''''+@Timedim+'''' b
	Where b.label = a.Source_label ''''
	EXEC(@Sql)

	SEt @sql = ''''Update #time set memberid = b.Memberid from #Time a, DS_''''+@TimeDim+'''' b Where a.Label = b.Label ''''
	--Print(@Sql)
	EXEC(@Sql)

	Insert into #time (memberid,Label,source_memberid,Source_label)
	VALUES (-1,''''None'''',-1,''''None'''') ' 


			SET @SQLStatement = @SQLStatement + '

		Declare @Label nvarchar(8),@memberid BIGINT,@Source_Label nvarchar(8),@Source_memberid BIGINT, @oldlabel nvarchar(8),@Dest_Memberid BIGINT
		DECLARE @Select nvarchar(max)

		Set @Select  = REPLACE(@AllDim,'''']'''',''''_Memberid]'''')
		Truncate Table #temp
		Set @Sql = ''''Insert Into #temp Select memberid from DS_''''+@TimeDim+'''' Where Label = ''''''''''''+@Year+''''0101''''''''''''
		EXEC(@Sql)
		Select @Dest_Memberid = Memberid From #temp
		Set @Select  = REPLACE(@Select,''''[''''+@TimeDim+''''_Memberid]'''',Rtrim(CAST(@Dest_Memberid as Char)))

		Set @Sql = ''''DELETE FROM FACT_''''+@ModelName+''''_default_partition
		WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
		and ''''+@EntityDim+''''_Memberid in (Select Memberid from #temp_parametervalues Where parameterName = ''''''''EntityMbrs'''''''')
		And [''''+@AccountDim+''''_Memberid] IN (''''+@Account_Opening_ID+'''')  
		And [''''+@TimeDim+''''_Memberid] = ''''+CAST(@Dest_memberid as char)
		--PRINT(@Sql)
		EXEC(@Sql)

		SEt @Select = Replace(@AllDim,'''']'''',''''_memberid]'''')
		SEt @Select = Replace(@Select,''''['''',''''a.['''')
		SEt @Select = Replace(@Select,''''a.[''''+@TimeDim+''''_memberid]'''',''''b.memberid'''')
		SET @Select = Replace(@Select,''''a.[''''+@AccountDim+''''_memberid]'''',RTRIM(CAST(@Account_Opening_ID as char)))
		SET @Select = Replace(@Select,''''a.[AR_Aging_memberid]'''',-1)

		Set @Sql = ''''Insert into #FactData    
		Select 
		''''+@ModelName+''''_Value
		,''''+@Select+'''' 
		From FACT_''''+@ModelName+''''_default_partition a, #Time b 
		WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
		and ''''+@EntityDim+''''_Memberid in (Select Memberid from #temp_parametervalues Where parameterName = ''''''''EntityMbrs'''''''')
		And [''''+@AccountDim+''''_Memberid] in (''''+@Account_Invoiced_ID+'''',''''+@Account_Paid_ID+'''',''''+@Account_Opening_ID+'''')  
		And [''''+@TimeDim+''''_Memberid] =  b.Source_Memberid ''''
		PRINT(@Sql)
		EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '

		SET @sql = ''''Update #FactData set ''''+@BusinessprocessDim+''''_Memberid = b.Memberid 
		From #FactData a, DS_''''+@BusinessprocessDim+ '''' b 
		Where b.label = ''''''''Input'''''''' ''''
		Exec(@Sql) 

		Set @Sql = ''''INsert Into #FactFinal
		SELECT Sum(Value),''''+Replace(@Alldim,'''']'''',''''_Memberid]'''')+'''' 
		From #FactData
		Group By ''''+Replace(@Alldim,'''']'''',''''_Memberid]'''')
		--PRINT(@Sql)
		EXEC(@Sql)
		
		Set @Sql = ''''INsert Into FACT_''''+@ModelName+''''_default_partition 
		(''''+@ModelName+''''_Value,''''+Replace(@Alldim,'''']'''',''''_Memberid]'''')+'''',[ChangeDateTime],userId)
		SELECT Value,''''+Replace(@Alldim,'''']'''',''''_Memberid]'''')+'''',GETDATE(),''''''''''''+@USer+''''''''''''
		From #FactFinal Where Value <> 0 ''''
		--PRINT(@Sql)
		EXEC(@Sql)

		UPDATE Canvas_User_Run_Status SET END_Date = GETDATE() WHERE Proc_Id = @Proc_Id

		If @ETL <> 0 Delete From Wrk_ETL_Values Where Proc_Name = ''''Canvas_AR_AP_Copy_Opening''''

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END




/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_Deploy_payment]    Script Date: 3/2/2017 11:34:03 AM ******/

/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_Deploy_payment]    Script Date: 9/5/2014 3:48:00 PM ******/
SET @Step = 'Create Canvas_AR_AP_Deploy_payment'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_AR_AP_Deploy_payment') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_AR_AP_Deploy_payment]
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	update FACT_AccountReceivable_default_partition
	Set Timeday_memberid = timeday_memberid 
	Where scenario_memberid = -1
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END




/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_Due_SO_PO]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_AR_AP_Due_SO_PO'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_AR_AP_Due_SO_PO') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_AR_AP_Due_SO_PO]
	@AR_Ap Nvarchar(2) =''''AR'''',
	@ETL Bit = 0
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	--DECLARE @TimeID NVARCHAR(255),@ScenarioID NVARCHAR(255),@Account INT,@Invoice INT,@InvoiceDim Nvarchar(50),@Account_Due_ID NVARCHAR(255)
	--,@Account_Opening_ID NVARCHAR(255),@Account_Paid_ID NVARCHAR(255),@Alldim_Memberid Nvarchar(Max)
	DECLARE @Scenario INT,@Time INT,@User Nvarchar(50),@modelname nvarchar(200),@Businessprocess INT,@BusinessprocessDim Nvarchar(50),@ClientDim Nvarchar(50)		
	,@lap int,@ret bigint,@scenarioDim Nvarchar(50),@TimeDim Nvarchar(50),@AccountDim Nvarchar(50),@OrderDim Nvarchar(50),@EntityDim Nvarchar(50)
	DECLARE @DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max),@Found int,@Alldim Nvarchar(Max),@Otherdim Nvarchar(Max),@Sep Nvarchar(2)

	Select @user = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''
	Select @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''

	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0 ' 


			SET @SQLStatement = @SQLStatement + '


	If @ETL <> 0 Select * into #Temp_ParameterValues From Wrk_ETL_Values Where Proc_Name = ''''Canvas_AR_AP_Due_SO_PO''''

	SET @Lap = 1 
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''

		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Number''''
		begin
			set @OrderDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Customer''''
		begin
			set @ClientDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Supplier''''
		begin
			set @ClientDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
		end ' 


			SET @SQLStatement = @SQLStatement + '

		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType
	end
	close Dim_cursor
	deallocate Dim_cursor ' 


			SET @SQLStatement = @SQLStatement + '


	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')

	Set @Alldim = @Alldim + '''',[TimeDataView] ''''

	Create table #FactData (Value Float)
	SET @Sql = ''''ALTER TABLE #FactData ADD ''''+Replace(@Alldim,'''']'''',''''_Memberid] BIGINT'''')+'''', Datelabel Nvarchar(8) COLLATE SQL_Latin1_General_CP1_CI_AS
	, paymentTerm INT, FinalDateLabel INT ''''
	--Print(@Sql)
	EXEC(@Sql)

	Create Table #Account (memberid BIGINT,label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
	Destmemberid BIGINT,destlabel Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	--Create Table #Time (memberid BIGINT,label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,Source_memberid BIGINT,Source_Label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	Create Table #Temp (MemberID BIGINT)
	Create Table #TempLabel (Label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS) ' 


			SET @SQLStatement = @SQLStatement + '


	Truncate table #temp
	Set @sql = ''''Insert into #temp select Memberid from DS_''''+@ScenarioDim+'''' Where label = ''''''''ACTUAL''''''''''''
	EXEC(@Sql)
	SELECT @Scenario = Memberid from #temp

	INsert into #Account VALUES (0,''''CFCAPPOR_'''',0,''''CFCAPPORDue_'''')
	INsert into #Account VALUES (0,''''CFCAPPOM_'''',0,''''CFCAPPOMDue_'''')
	INsert into #Account VALUES (0,''''CFCAPSI_'''',0,''''CFCAPSIDue_'''')
	INsert into #Account VALUES (0,''''CFCARSONS_'''',0,''''CFCARSONSDue_'''')
	INsert into #Account VALUES (0,''''CFCARSOS_'''',0,''''CFCARSOSDue_'''')
	INsert into #Account VALUES (0,''''CFCARSOI_'''',0,''''CFCARSOIDue_'''')
	INsert into #Account VALUES (0,''''CFCARSI_'''',0,''''CFCARSIDue_'''')
	INsert into #Account VALUES (0,''''CFCAROI_'''',0,''''CFCAROIDue_'''')
	INsert into #Account VALUES (0,''''CFCOF_'''',0,''''CFCOFDue_'''')
	INsert into #Account VALUES (0,''''CFCODLF_'''',0,''''CFCODLFDue_'''')
	INsert into #Account VALUES (0,''''CFCOOCS_'''' ,0,''''CFCOOCSDue_'''')

	Set @sql = ''''Update #Account set memberid = b.Memberid from #account a, DS_''''+@AccountDim+'''' b Where a.Label = b.label''''
	Exec(@Sql)

	Set @sql = ''''Update #Account set Destmemberid = b.Memberid from #account a, DS_''''+@AccountDim+'''' b Where a.DestLabel = b.label''''
	Exec(@Sql)

	Truncate table #temp
	Set @sql = ''''INsert into #temp select memberid from [DS_''''+@BusinessprocessDim+''''] Where Label = ''''''''Input'''''''''''' 
	EXEC(@Sql)
	SElect @Businessprocess = Memberid from #temp 
	Truncate table #temp ' 


			SET @SQLStatement = @SQLStatement + '


	DECLARE @Year Nvarchar(4),@PYear Nvarchar(4),@TodayDate Nvarchar(8), @TodayDATEiD Nvarchar(10)

	SET @TodayDate = YEAR(GETDATE()) * 10000 +  MONTH(GETDATE()) * 100 +  DAY(GETDATE()) 

	Declare @Label nvarchar(8),@memberid BIGINT,@Source_Label nvarchar(8),@Source_memberid BIGINT, @oldlabel nvarchar(8),@Dest_Memberid BIGINT
	DECLARE @Select nvarchar(max)

		Set @Select  = REPLACE(@AllDim,'''']'''',''''_Memberid]'''')

		Set @Sql = ''''DELETE FROM FACT_''''+@ModelName+''''_default_partition
		WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
		And [''''+@AccountDim+''''_Memberid] in (Select Memberid from DS_''''+@Accountdim+'''' 
		Where Label IN (''''''''CFCAPPORDue_'''''''',''''''''CFCAPPOMDue_'''''''',''''''''CFCAPSIDue_'''''''',''''''''CFCARSONSDue_'''''''',''''''''CFCARSOSDue_'''''''',''''''''CFCARSOIDue_'''''''',''''''''CFCARSIDue_'''''''',''''''''CFCAROIDue_'''''''',
		''''''''CFCOFDue_'''''''',''''''''CFCODLFDue_'''''''',''''''''CFCOOCSDue_'''''''')) ''''
		--PRINT(@Sql)
		EXEC(@Sql)

		SEt @Select = Replace(@AllDim,'''']'''',''''_memberid]'''')
		SEt @Select = Replace(@Select,''''['''',''''a.['''')
		SEt @Select = Replace(@Select,''''a.[''''+@AccountDim+''''_Memberid]'''',''''c.[DestMemberid]'''')

		Set @Sql = ''''Insert into #FactData    
		Select 
		''''+@ModelName+''''_Value
		,''''+@Select+''''
		,''''''''''''''''
		,b.PaymentTerm 
		,''''''''''''''''
		From FACT_''''+@ModelName+''''_default_partition a, DS_''''+@ClientDim+'''' b ,#Account c
		WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
		and ''''+@AccountDim+''''_Memberid = c.Memberid 
		And a.''''+@ClientDim+''''_memberId = b.Memberid  ''''
		EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


		Set @Sql = ''''Update #FactData set Datelabel = b.Label From #FactData a,DS_''''+@TimeDim+'''' b 
		Where Len(b.Label) = 8 and  a.''''+@TimeDim+''''_Memberid = b.Memberid ''''
		--PRINT(@Sql)
		EXEC(@Sql)

		Update #FactData Set 
		FinaldateLabel = YEAR(DATEADD(day,PaymentTerm, DateLabel)) * 10000
		+ MONTH(DATEADD(day,PaymentTerm, DateLabel))*100 
		+ DAY(DATEADD(day,PaymentTerm, DateLabel))
		Where datelabel <> ''''None''''

		set @sql = ''''Update #FactData Set ''''+@TimeDim+''''_Memberid = b.memberid From #FactData a, DS_''''+@TimeDim+'''' b 
		Where Len(b.Label) = 8 and  a.FinalDateLabel = b.Label ''''
		--Print(@Sql)
		Exec(@Sql)
		
		Set @sql = ''''Update #FactData Set ''''+@BusinessprocessDim+''''_Memberid = ''''+CAST(@Businessprocess as char)
		EXEC(@Sql)

		Set @Sql = ''''INsert Into FACT_''''+@ModelName+''''_default_partition 
		(''''+@ModelName+''''_Value,''''+Replace(@Alldim,'''']'''',''''_Memberid]'''')+'''',[ChangeDateTime],userId)
		SELECT Value,''''+Replace(@Alldim,'''']'''',''''_Memberid]'''')+'''',GETDATE(),''''''''''''+@USer+''''''''''''
		From #FactData Where Value <> 0 ''''
		--PRINT(@Sql)
		EXEC(@Sql)

		If @ETL <> 0 Delete From Wrk_ETL_Values Where Proc_Name = ''''Canvas_AR_AP_Due_SO_PO''''

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END




/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_PayedInvoice]    Script Date: 3/2/2017 11:34:03 AM ******/

/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_PayedInvoice]    Script Date: 5/16/2014 2:26:43 PM ******/
--SET ANSI_NULLS ON
----SET QUOTED_IDENTIFIER ON
--SET @Step = 'Create Canvas_AR_AP_Calculate_Aging'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_AR_AP_PayedInvoice') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_AR_AP_PayedInvoice]
@AR_AP Nvarchar(2) = ''''AR'''',
@ETL Bit = 0
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
--DECLARE @AR_AP Nvarchar(2),@ETL Bit 
--SET @AR_AP = ''''AP''''
SET @ETL = 1

	If @ETL <> 0 Select * into #Temp_ParameterValues From Wrk_ETL_Values Where Proc_Name = ''''Canvas_AR_AP_PayedInvoice''''

	--,@Time Nvarchar(8),@ScenarioID NVARCHAR(255),@TimeID NVARCHAR(255)@EntityID NVARCHAR(255),@Alldim_Memberid Nvarchar(Max)
	DECLARE @User Nvarchar(50),@modelname nvarchar(200),@Account_Invoiced_ID NVARCHAR(255)
	,@Account_Paid_ID NVARCHAR(255),@AccountDim Nvarchar(50),@EntityDim Nvarchar(50),@ScenarioDim Nvarchar(50)
	,@BusinessProcessDim Nvarchar(50),@TimeDim Nvarchar(50),@InvoiceDim Nvarchar(50),@Entity Nvarchar(8),@Scenario Nvarchar(8)
	,@DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max),@Lap INT,@Found int,@Alldim Nvarchar(Max),@Otherdim Nvarchar(Max),@Sep Nvarchar(2)

	Select @user = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''UserId''''
	Select @ModelName = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''Model'''' ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0

	SET @Lap = 1 
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''

		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessProcessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''InvoiceNo''''
		begin
			set @InvoiceDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType
	end
	close Dim_cursor
	deallocate Dim_cursor ' 

			SET @SQLStatement = @SQLStatement + '

	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')

	Set @Alldim = @Alldim + '''',[TimeDataView] ''''

	Create table #InvoiceNumber (InvoiceNo_Memberid BIGINT, Value_Invoiced Float,Value_Paid Float)

	Create Table #TempLabel (label Nvarchar(255))
	Create Table #Temp (Memberid BigINT)
	Create Table #Account (memberid BIGINT,label Nvarchar(255),KeyName_Account nvarchar(255))

	Truncate Table #temp
	Set @Sql = ''''Insert Into #temp Select memberid from DS_''''+@ScenarioDim+'''' Where Label = ''''''''ACTUAL'''''''' ''''
	EXEC(@Sql)
	select @Scenario = Memberid From #Temp

	select @Entity = Memberid From #Temp_ParameterValues Where parameterName = ''''EntityMbrs''''

	Create Table #BusinessProcess (Memberid Bigint)
	Set @sql = ''''INsert into #BusinessProcess select memberid from [DS_''''+@BusinessprocessDim+'''']'''' --Where label  in (''''''''E9'''''''',''''''''E10'''''''',''''''''iSCALA'''''''')
	EXEC(@Sql)
	
	Set @sql = ''''INsert into #Account 
	select memberid,label,KeyName_Account from [DS_''''+@AccountDim+''''] 
	Where KeyName_Account IN (''''''''Invoiced_'''' + @AR_AP+'''''''''''',''''''''Paid_'''' + @AR_AP+'''''''''''') '''' 
	--Print(@Sql)
	EXEC(@Sql)

	Create Table #time (Memberid BIGINT, label Nvarchar(255))
	SET @Sql = ''''INSERT INTO #time select b.memberid,b.label from  DS_''''+@TimeDim+'''' a, DS_''''+@TimeDim+'''' b
	Where a.Memberid in (Select Memberid From #temp_parametervalues where parametername = ''''''''TimeMbrs'''''''') 
	And b.Label <= a.Label
	and len(b.label) = 8 
	and substring(b.label,5,1) Not in (''''''''Q'''''''')''''
	Exec(@Sql)

	--Truncate table #temp
	
	Select @Account_Invoiced_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''Invoiced_'''' + @AR_AP
	Select @Account_Paid_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''Paid_'''' + @AR_AP
	
	Set @Sql = ''''Insert into #InvoiceNumber
	Select  InvoiceNo_Memberid, Sum(Value_Invoiced) as Value_Invoiced , Sum(Value_Paid) as Value_Paid FROM (
	Select Distinct ''''+@InvoiceDim+''''_memberid As InvoiceNo_Memberid,''''+@ModelName+''''_Value as Value_INvoiced, 0 as Value_Paid
	From FACT_''''+@ModelName+''''_default_partition 
	WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
	and ''''+@InvoiceDim+''''_Memberid in (select memberid from DS_''''+@InvoiceDim+'''' Where paid In (''''''''N'''''''',''''''''P'''''''') )
	and ''''+@EntityDim+''''_Memberid in (Select Memberid from #Temp_ParameterValues Where parameterName = ''''''''EntityMbrs'''''''')
	And [''''+@AccountDim+''''_Memberid] in (''''+@Account_Invoiced_ID+'''') 
	And [''''+@modelname+''''_Value] <> 0 
	And [''''+@TimeDim+''''_Memberid] in (Select memberid from #Time) 
	UNION ALL
	Select Distinct ''''+@InvoiceDim+''''_memberid As InvoiceNo_Memberid, 0 as Value_Invoiced, ''''+@ModelName+''''_Value as Value_Paid
	From FACT_''''+@ModelName+''''_default_partition 
	WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
	and ''''+@InvoiceDim+''''_Memberid in (select memberid from DS_''''+@InvoiceDim+'''' Where paid In (''''''''N'''''''',''''''''P'''''''') )
	and ''''+@EntityDim+''''_Memberid in (Select Memberid from #Temp_ParameterValues Where parameterName = ''''''''EntityMbrs'''''''')
	And [''''+@AccountDim+''''_Memberid] in (''''+@Account_Paid_ID+'''') 
	And [''''+@TimeDim+''''_Memberid] in (Select memberid from #Time) 
	) as Tmp
	Group By InvoiceNo_Memberid ''''
	--PRINT(@Sql)
	EXEC(@Sql) ' 
	

			SET @SQLStatement = @SQLStatement + '


	If @@ROWCOUNT > 0
	BEGIN
		SET @sql = ''''Alter table #InvoiceNumber ADD Value Float,PAid Nvarchar(1)''''
		EXEC(@Sql) 
		SET @sql = ''''Update #InvoiceNumber Set Value = Value_Invoiced + Value_Paid,Paid  = ''''''''N'''''''' ''''
		EXEC(@Sql) 
		SET @sql = ''''Update #INvoicenumber Set Paid = ''''''''Y'''''''' where Value = 0 ''''
		EXEC(@Sql) 
		SET @sql = ''''Update #INvoicenumber Set Paid = ''''''''P'''''''' where VAlue <> 0 AND ABS(Value) <> ABS(Value_Invoiced) ''''
		EXEC(@Sql) 
		SET @sql = ''''Delete from #InvoiceNumber Where Paid = ''''''''N'''''''' ''''
 		EXEC(@Sql) 
		SET @sql = ''''Update DS_''''+@InvoiceDim+ '''' Set Paid = b.Paid
		From  DS_''''+@InvoiceDim+ '''' a, #InvoiceNumber b 
		Where  a.Memberid =  b. InvoiceNo_Memberid ''''
		Exec(@Sql)
		SET @sql = ''''Update O_DS_''''+@InvoiceDim+ '''' Set Paid = b.Paid
		From  O_DS_''''+@InvoiceDim+ '''' a, #InvoiceNumber b 
		Where  a.Memberid =  b. InvoiceNo_Memberid ''''
		Exec(@Sql)
		SET @sql = ''''Update S_DS_''''+@InvoiceDim+ '''' Set Paid = ''''''''Y''''''''
		From  S_DS_''''+@InvoiceDim+ '''' a, #InvoiceNumber b 
		Where  a.Memberid =  b. InvoiceNo_Memberid ''''
		Exec(@Sql)
	END

	SET @Sql = ''''UPDATE S_Dimensions SET ChangeDatetime = GETDATE() WHERE Label = ''''''''''''+@InvoiceDim++''''''''''''''''
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''UPDATE Checkout SET ChangeDatetime = GETDATE() WHERE Label = ''''''''''''+@InvoiceDim++'''''''''''' AND Type = ''''''''Dimension'''''''' ''''
	EXEC(@Sql)

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END




/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_Payment]    Script Date: 3/2/2017 11:34:03 AM ******/

--SET ANSI_NULLS ON
----SET QUOTED_IDENTIFIER ON
--SET @Step = 'Create Canvas_AR_Payment'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_AR_AP_Payment') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_AR_AP_Payment]
	@ModelName as nvarchar(255)
	,@UserName as nvarchar(255)
	,@Amount as Nvarchar(255)
	,@EntityName as Nvarchar(255)
	,@ClientName as Nvarchar(255) = ''''''''
	,@AccountName as Nvarchar(255) = ''''''''
	,@Sort as Nvarchar(255) = 4
	,@List as nvarchar(255) = ''''Y''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
	Declare @Account_Invoiced NVARCHAR(255),@Account_Due NVARCHAR(255),@Account_Paid NVARCHAR(255),@InvoiceDim Nvarchar(50),@ClientDim Nvarchar(50)
	,@AndPaid Nvarchar(255),@AR_AP Nvarchar(2)

	Declare @alldim nvarchar(max), @Select nvarchar(max),@Otherdim nvarchar(max), @Found INT,@Lap INT,@sep nvarchar(2),@DimLabel Nvarchar(50)
	,@DimType Nvarchar(50),@Sql Nvarchar(Max),@Params Nvarchar(max),@AccountDim Nvarchar(50),@ScenarioDim Nvarchar(50),@EntityDim Nvarchar(50)
	,@BusinessprocessDim Nvarchar(50),@CurrencyDim Nvarchar(50),@TimeDim Nvarchar(50),@OrderDim Nvarchar(50)

	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0

	SET @Lap = 1  ' 


			SET @SQLStatement = @SQLStatement + '

	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''
		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Currency''''
		begin
			set @CurrencyDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end

		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''InvoiceNo''''
		begin
			set @InvoiceDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Number''''
		begin
			set @OrderDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Customer''''
		begin
			set @ClientDim = RTRIM(@DimLabel)
			Set @AndPaid = '''' And sign = -1 '''' 
			Set @AR_AP = ''''AR''''
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end

		if @DimType = ''''Supplier''''
		begin
			set @ClientDim = RTRIM(@DimLabel)
			Set @AndPaid = '''' And sign = 1 '''' 			
			Set @AR_AP = ''''AP''''
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType
	end
	close Dim_cursor
	deallocate Dim_cursor 

	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')
	--SET @AllDim_Memberid = Replace(@Alldim,'''']'''',''''_Memberid]'''') 

	Set @Alldim = @Alldim + '''',[TimeDataView] ''''
	DECLARE @EntityMbrid Nvarchar(20), @ClientMbrid Nvarchar(20) ' 


			SET @SQLStatement = @SQLStatement + '

	set @Params = ''''@EntityMbridOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @EntityMbridOUT=[MemberId] from [DS_''''+@EntityDim+''''] where [Label]=''''''''''''+@EntityName+''''''''''''''''
	exec sp_executesql @sql, @Params, @EntityMbridOUT=@EntityMbrid OUTPUT

	set @Params = ''''@clientMbridOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @ClientMbridOUT=[MemberId] from [DS_''''+@ClientDim+''''] where [Label]=''''''''''''+@ClientName+''''''''''''''''
	exec sp_executesql @sql, @Params, @ClientMbridOUT=@ClientMbrid OUTPUT

	Create table #entity (Label Nvarchar(255),Memberid Bigint)
 	Create table #Client (Label Nvarchar(255),Memberid Bigint)

	SET @Sql = ''''INSERT INTO #Entity Select distinct b.Label,b.memberid From HC_''''+@EntityDim+'''' a, DS_''''+@EntityDim+'''' b
	Where  a.Memberid = b.memberid and a.Parentid = ''''+@EntityMbrid
	EXEC(@Sql)

	SET @Sql = ''''INSERT INTO #Client Select b.Label,b.memberid From HC_''''+@ClientDim+'''' a, DS_''''+@ClientDim+'''' b
	Where  a.Memberid = b.memberid and a.Parentid = ''''+@ClientMbrid
	EXEC(@Sql)

	Create Table #account(Memberid Bigint, label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS, [Sign] INT, KeyName_Account Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

	SEt @sql = ''''insert into #Account Select Memberid, label, [Sign],KeyName_Account from S_ds_''''+@AccountDim +'''' 
	Where KeyName_Account in (''''''''Invoiced_''''+@AR_AP+'''''''''''',''''''''Due_''''+@AR_AP+'''''''''''',''''''''Paid_''''+@AR_AP+'''''''''''') '''' 
	--Print(@Sql) 
	Exec(@Sql) 

	Select @Account_Invoiced = Label from #account where KeyName_Account = ''''Invoiced_''''+@AR_AP
	Select @Account_Due = Label from #account where KeyName_Account = ''''Due_''''+@AR_AP
	Select @Account_Paid = Label from #account where KeyName_Account = ''''Paid_''''+@AR_AP

	If @AccountNAme <> @Account_Paid 
	BEGIN	
		SET @Account_Invoiced = @accountName
		SET @Account_Due = REPLACE(@accountName,''''_'''',''''Due_'''')
	END

	Declare @today as nvarchar(8)
	SET @Today = YEAR(GETDATE()) * 10000 + MONTH(GETDATE()) * 100 + DAY(GETDATE()) 
	 
	Create table #Fact_Sales (invoiceNumber Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,client Nvarchar(255)COLLATE SQL_Latin1_General_CP1_CI_AS
	,timeday Nvarchar(8) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Currency Nvarchar(8) COLLATE SQL_Latin1_General_CP1_CI_AS
	,value Float) ' 


			SET @SQLStatement = @SQLStatement + '

	Create table #Fact_Due (invoiceNumber Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,client Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,timeday Nvarchar(8) COLLATE SQL_Latin1_General_CP1_CI_AS,Currency Nvarchar(8) COLLATE SQL_Latin1_General_CP1_CI_AS,value Float)
	Create table #Fact_paid (invoiceNumber Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,client Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,timeday Nvarchar(8) COLLATE SQL_Latin1_General_CP1_CI_AS,Currency Nvarchar(8) COLLATE SQL_Latin1_General_CP1_CI_AS,value Float)
	Create table #Fact_paid_Manual (invoiceNumber Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,client Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,timeday Nvarchar(8) COLLATE SQL_Latin1_General_CP1_CI_AS,Currency Nvarchar(8) COLLATE SQL_Latin1_General_CP1_CI_AS,value Float)

	If @AccountName <> @Account_paid Set @InvoiceDim = @OrderDim
	
	Set @Sql = ''''INSERT into #Fact_Sales
	select ''''+@InvoiceDim+'''',''''+@ClientDim+'''',''''+@TimeDim+'''',''''+@CurrencyDim+'''',sum(''''+@ModelName+''''_Value) as value
	from FACT_''''+@ModelName+''''_View
	Where ''''+@AccountDim+'''' = ''''''''''''+@Account_Invoiced+''''''''''''
	And ''''+@EntityDim+'''' IN (Select Label from #Entity)  
	And ''''+@ClientDim+'''' IN (Select Label from #Client)  ''''
	If @AccountName = @Account_paid SET @Sql = @Sql + '''' and ''''+@InvoiceDim+'''' in (select label from S_DS_''''+@InvoiceDim+'''' where Paid = ''''''''N'''''''') ''''
	Set @sql = @sql +'''' 
	and LEN(''''+@TimeDim+'''') = 8 and ''''+@TimeDim+'''' <= ''''+@today+''''
	group by ''''+@InvoiceDim+'''',''''+@ClientDim+'''',''''+@TimeDim+'''',''''+@CurrencyDim+''''''''
	--Print(@Sql)
	EXEC(@Sql)

	Set @Sql = ''''INSERT into #Fact_Due
	select ''''+@InvoiceDim+'''',''''+@ClientDim+'''',''''+@TimeDim+'''',''''+@CurrencyDim+'''',sum(''''+@ModelName+''''_Value)  as value
	from FACT_''''+@ModelName+''''_View
	Where ''''+@AccountDim+'''' = ''''''''''''+@Account_due+''''''''''''
	and  ''''+@ScenarioDim+'''' = ''''''''ACTUAL'''''''' 
	And ''''+@EntityDim+'''' IN (Select Label from #Entity)  
	And ''''+@ClientDim+'''' IN (Select Label from #Client)  ''''
	If @AccountName = @Account_paid SET @Sql = @Sql + ''''and ''''+@InvoiceDim+'''' in (select label from S_DS_''''+@InvoiceDim+'''' where Paid = ''''''''N'''''''')''''
	Set @sql = @sql +'''' 
	group by ''''+@InvoiceDim+'''',''''+@ClientDim+'''',''''+@TimeDim+'''',''''+@CurrencyDim+''''''''
	--Print(@Sql)
	EXEC(@Sql)

	SET @Sql = ''''INSERT into #Fact_paid
	select ''''+@InvoiceDim+'''',''''+@ClientDim+'''',''''+@TimeDim+'''',''''+@CurrencyDim+'''',sum(''''+@ModelName+''''_Value)  as value
	from FACT_''''+@ModelName+''''_View
	Where ''''+@AccountDim+'''' = ''''''''''''+@AccountName+'''''''''''' 
	And ''''+@EntityDim+'''' IN (Select Label from #Entity)  
	And ''''+@ClientDim+'''' IN (Select Label from #Client)  ''''
	If @AccountName = @Account_paid SET @Sql = @Sql + ''''and ''''+@InvoiceDim+'''' in (select label from S_DS_''''+@InvoiceDim+'''' where Paid = ''''''''N'''''''')''''
	Set @sql = @sql +'''' and ''''+@ScenarioDim+'''' = ''''''''FORECAST''''''''
	group by ''''+@InvoiceDim+'''',''''+@ClientDim+'''',''''+@TimeDim+'''',''''+@CurrencyDim+''''''''
	--Print(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


	SEt @Sql = ''''INSERT into #Fact_paid_Manual
	select ''''+@InvoiceDim+'''',''''+@ClientDim+'''',''''+@TimeDim+'''',''''+@CurrencyDim+'''',sum(''''+@ModelName+''''_Value)  as value
	from FACT_''''+@ModelName+''''_View
	Where ''''+@AccountDim+'''' = ''''''''''''+@AccountName+'''''''''''' 
	And ''''+@EntityDim+'''' IN (Select Label from #Entity)  
	And ''''+@ClientDim+'''' IN (Select Label from #Client)  ''''
	If @AccountName = @Account_paid SET @Sql = @Sql + ''''and ''''+@InvoiceDim+'''' in (select label from S_DS_''''+@InvoiceDim+'''' where Paid = ''''''''N'''''''')''''
	Set @sql = @sql +'''' 
	and ''''+@ScenarioDim+'''' = ''''''''REFORECAST''''''''
	group by ''''+@InvoiceDim+'''',''''+@ClientDim+'''',''''+@TimeDim+'''',''''+@CurrencyDim+''''''''
	--Print(@Sql)
	EXEC(@Sql)	

	Select InvoiceNumber_Source	,Reforecast_Date_Source	,invoiceNumber 
	,Client,Max(timeday) as timeday,Currency
	,Sum(value) as value,MAX(Due_Date) as Due_Date,clientHabitDay,MAX(Forecast_Date) as Forecast_Date
	,MAX(Reforecast_Date) As Reforecast_Date
	,label 
	into #Temp
	From (
	Select a.invoiceNumber as invoiceNumber_Source,''''        '''' as Reforecast_Date_Source
	,a.invoiceNumber
	,a.client,a.timeday,a.Currency,a.value
	,''''''''  as Due_Date,0 as clientHabitDay,''''''''  as Forecast_Date,''''        '''' as Reforecast_Date
	,a.client as label
	from #Fact_Sales a
	UNION ALL
	Select b.invoiceNumber as invoiceNumber_Source,''''        '''' as Reforecast_Date_Source
	,b.invoiceNumber
	,b.client,'''''''' as Timeday,b.Currency,0 as value
	,b.timeday as Due_Date,0 as clientHabitDay,'''''''' as Forecast_Date,''''        '''' as Reforecast_Date
	,b.client as label
	from #Fact_Due b
	UNION ALL
	Select c.invoiceNumber as invoiceNumber_Source,''''        '''' as Reforecast_Date_Source
	,c.invoiceNumber
	,c.client,'''''''' as timeday,c.Currency,0 as value,
	'''''''' as Due_Date ,0 as clientHabitDay,c.timeday as Forecast_Date,''''        '''' as Reforecast_Date
	,c.client as label
	from #Fact_paid c
	) As Tmp
	Group By InvoiceNumber_Source,Reforecast_Date_Source,invoiceNumber,label,client,Currency,clientHabitDay
	order by 1
	
	Delete from #temp where Timeday = ''''''''
	Delete from #temp where Due_Date = ''''''''

	UPDate #temp set Reforecast_Date = b.Timeday From #temp a, #Fact_paid_Manual b
	Where a.InvoiceNumber = b.InvoiceNumber

	create table #temp2 (invoicenumber nvarchar(255), memberid bigint)

	SET @Sql = ''''INSERT into #temp2 Select a.invoicenumber, b.memberid From #temp a, S_DS_''''+@InvoiceDim+'''' b 
	where Reforecast_Date = ''''''''        '''''''' and a.invoicenumber = b.label ''''
	--Print(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


	IF @@ROWCOUNT > 0
	BEGIN
		DECLARE @AccountMbrid Nvarchar(20),@ForScenarioMbrid Nvarchar(20),@ACTUALScenarioMbrid Nvarchar(20),@ReForScenarioMbrid Nvarchar(20)
		
		set @Params = ''''@AccountMbridOUT nvarchar(20) OUTPUT''''
		set @SQL = ''''select @AccountMbridOUT=[MemberId] from [S_DS_''''+@AccountDim+''''] where [Label]=''''''''''''+@Accountname+''''''''''''''''
		exec sp_executesql @sql, @Params, @AccountMbridOUT=@AccountMbrid OUTPUT

		set @Params = ''''@ForScenarioMbridOUT nvarchar(20) OUTPUT''''
		set @SQL = ''''select @ForScenarioMbridOUT=[MemberId] from [DS_''''+@ScenarioDim+''''] where [Label]=''''''''Forecast''''''''''''
		exec sp_executesql @sql, @Params, @ForScenarioMbridOUT=@ForScenarioMbrid OUTPUT

		set @Params = ''''@ACTUALScenarioMbridOUT nvarchar(20) OUTPUT''''
		set @SQL = ''''select @ACTUALScenarioMbridOUT=[MemberId] from [DS_''''+@ScenarioDim+''''] where [Label]=''''''''ACTUAL''''''''''''
		exec sp_executesql @sql, @Params, @ACTUALScenarioMbridOUT=@ACTUALScenarioMbrid OUTPUT

		set @Params = ''''@ReForScenarioMbridOUT nvarchar(20) OUTPUT''''
		set @SQL = ''''select @ReForScenarioMbridOUT=[MemberId] from [DS_''''+@ScenarioDim+''''] where [Label]=''''''''ReForecast''''''''''''
		exec sp_executesql @sql, @Params, @ReForScenarioMbridOUT=@ReForScenarioMbrid OUTPUT

		Set @Alldim = REPLACE(@Alldim,'''']'''',''''_Memberid]'''')
		Set @Select = REPLACE(@Alldim,''''[''''+@ScenarioDim+''''_Memberid]'''',@ReForScenarioMbrid)

		If @AccountName = @Account_paid
		BEGIN
			Set @Sql = ''''INsert Into FACT_''''+@ModelName+''''_default_partition 
			(''''+@ModelName+''''_Value,''''+@Alldim+'''',[ChangeDateTime],userId)
			SELECT '''' 
			+@ModelName+''''_Value,''''+@Select+'''',GETDATE(),''''''''''''+@UserName+''''''''''''
			FROM  dbo.FACT_''''+@ModelName+''''_default_partition  
			Where ''''+@InvoiceDim+''''_Memberid in (Select Memberid From #temp2)  
			And ''''+@EntityDim+''''_Memberid IN (Select Memberid from #Entity)  
			And ''''+@ClientDim+''''_Memberid IN (Select Memberid from #Client)  
			and ''''+@AccountDim+''''_memberid = ''''+@AccountMbrid+'''' 
			and ''''+@scenarioDim+''''_Memberid = ''''+@ForScenarioMbrid
			--Print(@Sql)
			EXEC(@Sql)
		END
		ELSE ' 


			SET @SQLStatement = @SQLStatement + '

		BEGIN
			Set @Sql = ''''INsert Into FACT_''''+@ModelName+''''_default_partition 
			(''''+@ModelName+''''_Value,''''+@Alldim+'''',[ChangeDateTime],userId)
			SELECT '''' 
			+@ModelName+''''_Value,''''+@Select+'''',GETDATE(),''''''''''''+@UserName+''''''''''''
			FROM  dbo.FACT_''''+@ModelName+''''_default_partition  
			Where ''''+@InvoiceDim+''''_Memberid in (Select Memberid From #temp2) 
			And ''''+@EntityDim+''''_Memberid IN (Select Memberid from #Entity)  
			And ''''+@ClientDim+''''_Memberid IN (Select Memberid from #Client)  
			and ''''+@AccountDim+''''_memberid = ''''+@AccountMbrid+'''' 
			and ''''+@scenarioDim+''''_Memberid = ''''+@ACTUALScenarioMbrid
			--Print(@Sql)
			EXEC(@Sql)
		END

	END
	update #temp set Reforecast_Date = Forecast_Date Where Reforecast_Date IN (NULL ,'''''''')
	update #temp set Reforecast_Date = Due_Date,forecast_Date = Due_Date Where Forecast_Date IN (NULL ,'''''''') and  Reforecast_Date IN (NULL ,'''''''')
	update #temp set Reforecast_Date = Due_Date, Forecast_date= Due_Date Where forecast_Date IN (NULL ,'''''''',''''        '''')
	update #temp set Reforecast_Date_Source = ReForecast_Date where Reforecast_Date_Source = ''''        ''''
	update #temp set Reforecast_Date_Source = Forecast_Date where Reforecast_Date_Source = ''''        ''''
	update #temp set Reforecast_Date_Source = Due_Date,forecast_Date = Due_Date where Reforecast_Date_Source = ''''        '''' and forecast_Date = ''''        ''''
		
	Set @sql = ''''Update #temp SET InvoiceNumber_source = b.Description,InvoiceNumber = b.Description From #Temp a, S_DS_''''+@InvoiceDim+'''' b 
	Where a.invoiceNumber_source = b.Label''''
	Exec(@Sql)

	Set @sql = ''''Update #temp SET Client = b.Description, clienthabitday = b.PaymentHabit From #Temp a, DS_''''+@clientDim+'''' b 
	Where a.Client = b.Label And b.PaymentHabit IS NOT NULL''''
	Exec(@Sql)

	Alter TABLE #temp add NbDay INT

	Update #temp SET NbDay = datediff(Day,CAST(Forecast_date as Date),CAST(ReForecast_date as Date))
	Where Reforecast_DAte <> ''''None'''' 
	
	Update #temp set NbDay = '''''''' Where NbDay is NULL 
	
	IF @LISt = ''''y'''' 
	BEGIN
		If @sort = ''''1'''' 
		begin
			Select * from #temp Where ABS(value) >= @Amount  And due_date <> ''''None'''' order by 11
		end
		If @sort = ''''2''''
		begin
			Select * from #temp Where ABS(value) >= @Amount  And due_date <> ''''None'''' order by 8
		end
		If @sort = ''''3''''
		begin
			Select * from #temp Where ABS(value) >= @Amount  And due_date <> ''''None'''' order by  5
		end ' 


			SET @SQLStatement = @SQLStatement + '

		If @sort = ''''4''''
		begin
			Select * from #temp Where ABS(value) >= @Amount  And due_date <> ''''None'''' order by  4
		end
	END
--	drop table #Fact_Sales, #Fact_Due,#Fact_paid,#Fact_paid_Manual,#temp,#temp2,#account,#client,#Entity

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END



/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_Payment_Update]    Script Date: 3/2/2017 11:34:03 AM ******/

--/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_Payment_Update]    Script Date: 5/8/2014 4:10:08 PM ******/
--SET ANSI_NULLS ON
----SET QUOTED_IDENTIFIER ON
--SET @Step = 'Create Canvas_AR_Payment_Update'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_AR_AP_Payment_Update') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_AR_AP_Payment_Update]
	@ModelName as nvarchar(255),
	@InvoiceNumber  as nvarchar(255),
	@ReforecastPaymentdate  as nvarchar(255),
	@Client  as nvarchar(255),
	@Account  as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
	--@V1 INT,@V2 INT,@TimeDay NVARCHAR(255),
	DECLARE @sql Nvarchar(max), @AccountDim Nvarchar(50),@ScenarioDim Nvarchar(50),@InvoiceDim Nvarchar(50),@OrderDim Nvarchar(50),@ClientDim Nvarchar(50)
	,@AR_AP Nvarchar(255),@Params Nvarchar(Max),@InvoiceNumberMbrid Nvarchar(20),@TimeDayMbrid Nvarchar(20),@AccountMbrid Nvarchar(20),@ClientMbrid nvarchar(20)

	Select @AccountDim = a.Dimension from ModelDimensions a, Dimensions b
	Where a.Dimension = b.Label And b.[type] = ''''Account'''' and a.Model = @ModelName

	Select @InvoiceDim = a.Dimension from ModelDimensions a, Dimensions b
	Where a.Dimension = b.Label And b.[type] = ''''InvoiceNo'''' and a.Model = @ModelName

	Select @OrderDim = a.Dimension from ModelDimensions a, Dimensions b
	Where a.Dimension = b.Label And b.[type] = ''''Number'''' and a.Model = @ModelName

	Select @ScenarioDim = a.Dimension from ModelDimensions a, Dimensions b
	Where a.Dimension = b.Label And b.[type] = ''''Scenario'''' and a.Model = @ModelName

	SET @AR_AP = ''''AR''''
	Select @ClientDim = a.Dimension from ModelDimensions a, Dimensions b
	Where a.Dimension = b.Label And b.[type] = ''''Customer'''' and a.Model = @ModelName
	IF @@Rowcount = 0 
	BEGIn
		Select @ClientDim = a.Dimension from ModelDimensions a, Dimensions b
		Where a.Dimension = b.Label And b.[type] = ''''Supplier'''' and a.Model = @ModelName
		IF @@Rowcount > 0 SET @AR_AP = ''''AP''''
	END

	DECLARE @AccountPaid Nvarchar(255)
	set @Params = ''''@AccountOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @AccountOUT=[Label] from [DS_''''+@AccountDim+''''] where [KeyName_Account]  = ''''''''Paid_''''+@AR_AP+''''''''''''''''
	exec sp_executesql @sql, @Params, @AccountOUT=@AccountPaid OUTPUT ' 


			SET @SQLStatement = @SQLStatement + '


	Create table #tempID (Memberid Bigint)
	set @Params = ''''@ClientMbridOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''INsert into #tempId select [MemberId] from [DS_''''+@ClientDim+''''] where [Label]=''''''''''''+@Client+''''''''''''''''
	exec(@Sql)
	Select @ClientMbrid = Memberid from #tempId
	Drop table #tempid

	IF @Account <> @AccountPaid SET @invoiceDim = @OrderDim

	set @Params = ''''@InvoiceNumberMbridOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @InvoiceNumberMbridOUT=[MemberId] from [DS_''''+@InvoiceDim+''''] where [Description]=''''''''''''+@InvoiceNumber+''''''''''''''''
	exec sp_executesql @sql, @Params, @InvoiceNumberMbridOUT=@InvoiceNumberMbrid OUTPUT

	set @Params = ''''@TimeDayMbridOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @TimeDayMbridOUT=[MemberId] from [DS_TimeDay] where [Label]=''''''''''''+@ReforecastPaymentdate+''''''''''''''''
	exec sp_executesql @sql, @Params, @TimeDayMbridOUT=@TimeDayMbrid OUTPUT

	set @Params = ''''@AccountMbridOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @AccountMbridOUT=[MemberId] from [DS_''''+@AccountDim+''''] where [Label]=''''''''''''+@Account+''''''''''''''''
	exec sp_executesql @sql, @Params, @AccountMbridOUT=@AccountMbrid OUTPUT

	SET @sql = ''''UPDATE dbo.FACT_''''+@ModelName+''''_default_partition SET [TimeDay_Memberid] = ''''+@TimeDayMbrid+''''
	Where ''''+@InvoiceDim+''''_Memberid = ''''+@InvoiceNumberMbrid+'''' and ''''+@accountdim+''''_memberid = ''''+@AccountMbrid+'''' 
	and ''''+@scenarioDim+''''_Memberid in (Select memberid from ds_''''+@ScenarioDim+'''' where label = ''''''''Reforecast'''''''')
	And ''''+@ClientDim+''''_Memberid = ''''+@ClientMbrid
	--Print (@Sql)
	EXEC(@Sql)

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END



/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_RunAll]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_AR_AP_RunAll'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_AR_AP_RunAll') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  


  PROCEDURE  [dbo].[Canvas_AR_AP_RunAll]
@AR_AP Nvarchar(2) = ''''AR'''',
@PO_SO Nvarchar(3) = ''''No''''
--	@ModelName as nvarchar(255) = ''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--DECLaRE @AR_AP Nvarchar(2) ,@PO_SO Nvarchar(3)
--SET  @PO_SO = ''''No''''
-- SEt @AR_AP=''''AR''''
BEGIN
	SET NOCOUNT ON

	--Clear
	IF @AR_AP = ''''AP''''
	BEGIN
		DELETE FROM FACT_AccountPayable_default_partition Where Aging_AP_MemberId <> -1 and account_memberid in (select memberid from ds_account where label = ''''PayableDue_OverDue_'''')
		DELETE FROM FACT_AccountPayable_default_partition Where Scenario_Memberid in (select memberid from ds_scenario where Label in (''''FORECAST'''',''''REFORECAST''''))
	END
	IF @AR_AP = ''''AR''''
	BEGIN
		DELETE FROM FACT_AccountReceivable_default_partition Where Aging_AR_MemberId <> -1 and account_memberid in (select memberid from ds_account where Label = ''''ReceivableDue_OverDue_'''')
		DELETE FROM FACT_AccountReceivable_default_partition Where Scenario_Memberid in (select memberid from ds_scenario where Label in (''''FORECAST'''',''''REFORECAST''''))
	END

	if exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = /*$*/''''Wrk_ETL_Values''''/*$*/)  
	BEGIN
		Drop table Wrk_ETL_Values
	END
	CREATE TABLE [dbo].[Wrk_ETL_Values]([ParameterName] [nvarchar](255) NULL,[MemberId] [bigint] NULL,
		[StringValue] [nvarchar](512) NULL,	[Proc_Name] [nvarchar](512) NULL) ON [PRIMARY]

	INSERT [dbo].Wrk_ETL_Values ([ParameterName], [MemberId], [StringValue], [Proc_Name]) VALUES (N''''ScenarioMbrs'''', 1, NULL,'''''''')
	INSERT [dbo].Wrk_ETL_Values ([ParameterName], [MemberId], [StringValue], [Proc_Name]) VALUES (N''''TimeMbrs'''', 1, NULL,'''''''')
	INSERT [dbo].Wrk_ETL_Values ([ParameterName], [MemberId], [StringValue], [Proc_Name]) VALUES (N''''Model'''', NULL, N''''Financials'''','''''''')
	INSERT [dbo].Wrk_ETL_Values ([ParameterName], [MemberId], [StringValue], [Proc_Name]) VALUES (N''''Userid'''', NULL, N''''Dspanel'''','''''''')

	Insert into [dbo].Wrk_ETL_Values (ParameterName, Memberid)
	Select ''''EntityMbrs'''', memberid 
	from DS_Entity 
	Where Memberid not in (Select parentid from HC_Account Where parentid <> Memberid) ' 

	
				SET @SQLStatement = @SQLStatement + '
	

	Declare @TimeDim nvarchar(50) ,@sql nvarchar(max),@Lap INT,@Max INT,@NB INT

	IF @AR_AP = ''''AR''''
	BEGIN
		select @TimeDim = A.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
		where A.[Model] = ''''AccountReceivable'''' and b.type = ''''Time'''' 
			Update DS_InvoiceNo_AR set paid = ''''N''''
			Update S_DS_InvoiceNo_AR set paid = ''''N''''
			Update O_DS_InvoiceNo_AR set paid = ''''N''''
	END
	IF @AR_AP = ''''AP''''
	BEGIN
		select @TimeDim = A.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
		where A.[Model] = ''''AccountPayable'''' and b.type = ''''Time'''' 
			Update DS_InvoiceNo_AP set paid = ''''N''''
			Update S_DS_InvoiceNo_AP set paid = ''''N''''
			Update O_DS_InvoiceNo_AP set paid = ''''N''''
	END

	Create table #timeTemp
	(ID INT identity(1,1),Label nvarchar(8),Monthlabel nvarchar(6),memberid Bigint)
	
	DECLARE @Maxdate Nvarchar(8)
	
	SET @Maxdate = CAST((YEAR(getdate())*10000) + (MONTH(getdate())*100)+DAY(getdate()) as char)

	
	SET @Sql = ''''INsert into #timeTemp
	Select MAX(label),left(label,6),0
	from ds_''''+@timedim+''''  
	Where len(label) = 8
	and left(label,4) in (''''''''2012'''''''',''''''''2013'''''''',''''''''2014'''''''',''''''''2015'''''''')
	And label  <= ''''''''''''+@maxdate + ''''''''''''
	group by left(label,6)
	Order by 1''''
	--Print(@Sql)
	EXEC(@Sql)
	SET @max = @@Rowcount

	SET @sql = ''''Update #timeTemp set memberid = b.memberid 
	from #timeTemp a,Ds_''''+@TimeDim+'''' b where a.label = b.label ''''
	EXEC(@Sql) ' 

	
				SET @SQLStatement = @SQLStatement + '
	

	Set @Lap = 1

	Declare @Count INT

	While @LAp <= @Max
	BEGIN
		Print ''''===========================================================================''''
		Print ''''===========================================================================''''
		Print rtrim(Ltrim(CAST(@Lap as char))) + '''' / '''' + rtrim(Ltrim(CAST(@max as char)))
		Print ''''===========================================================================''''
		Print ''''===========================================================================''''

		IF @AR_AP = ''''AR''''
		BEGIN
			--====================================================================================
			-- RECEIVABLES
			--====================================================================================

			Update [dbo].Wrk_ETL_Values SET Memberid = b.Memberid 
			From [dbo].Wrk_ETL_Values a, #timeTemp b
			Where a.[ParameterName]= ''''TimeMbrs''''
			And b.ID = @Lap

			update Wrk_ETL_Values set stringValue = ''''AccountReceivable'''' where parametername = ''''MOdel''''

			--Delete from FACT_AccountReceivable_default_partition 
			--where scenario_memberid in (Select Memberid from DS_Scenario Where label in (''''Forecast'''',''''Reforecast''''))

			update Wrk_ETL_Values set proc_name = ''''Canvas_AR_AP_Calculate_Aging'''' ' 

	
				SET @SQLStatement = @SQLStatement + '
	

			Print ''''===================================================================> Canvas_AR_AP_Calculate_Aging''''

			Exec [Canvas_AR_AP_Calculate_Aging] ''''AR'''',1

			Select @Count = Count(*) From Wrk_ETL_Values

			If @PO_SO = ''''Yes'''' 
			BEGIN
				update Wrk_ETL_Values set proc_name = ''''Canvas_AR_AP_Due_SO_PO''''
				Exec [Canvas_AR_AP_Due_SO_PO] ''''AR'''',1
			END


			select @NB = count(*) from ds_invoiceNo_AR where paid = ''''N''''
			print ''''---------> ''''+cast(@NB as char)
		END

		IF @AR_AP = ''''AP''''
		BEGIN
			--====================================================================================
			-- PAYABLES
			--====================================================================================

			Update [dbo].Wrk_ETL_Values SET Memberid = b.Memberid 
			From [dbo].Wrk_ETL_Values a, #timeTemp b
			Where a.[ParameterName]= ''''TimeMbrs''''
			And b.ID = @Lap

			update Wrk_ETL_Values set stringValue = ''''AccountPayable'''' where parametername = ''''Model'''' ' 

	
				SET @SQLStatement = @SQLStatement + '
	

			--Delete from FACT_AccountReceivable_default_partition 
			--where scenario_memberid in (Select Memberid from DS_Scenario Where label in (''''Forecast'''',''''Reforecast''''))

			update Wrk_ETL_Values set proc_name = ''''Canvas_AR_AP_Calculate_Aging''''

			Print ''''===================================================================> Canvas_AR_AP_Calculate_Aging''''

			Exec [Canvas_AR_AP_Calculate_Aging] ''''AP'''',1

			Select @Count = Count(*) From Wrk_ETL_Values

			If @PO_SO = ''''Yes'''' 
			BEGIN
				update Wrk_ETL_Values set proc_name = ''''Canvas_AR_AP_Due_SO_PO''''
				Exec [Canvas_AR_AP_Due_SO_PO] ''''AP'''',1
			END


			select @NB = count(*) from ds_invoiceNo_AR where paid = ''''N''''
			print ''''---------> ''''+cast(@NB as char)

	
		end

	SET @Lap = @LAp + 1
	END ' 

	
				SET @SQLStatement = @SQLStatement + '
	


	update Wrk_ETL_Values set proc_name = ''''Canvas_AR_AP_Update_Forecast''''
	Print ''''===================================================================> Canvas_AR_AP_Update_Forecast''''
	Exec [Canvas_AR_AP_Update_Forecast] @AR_AP,1
	Select @Count = Count(*) From Wrk_ETL_Values
	print ''''---------> ''''+cast(@count as char)

	DELETE FROM [dbo].Wrk_ETL_Values

	SET NOCOUNT OFF

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END



-- Drop table #Timetemp
/*
select * from FACT_AccountReceivable_View where account = ''''ReceivableInvoice_''''
and left(timeday,4)=''''2012''''

truncate table fact_accountreceivable_default_partition 
insert into fact_accountreceivable_default_partition  select * from fact_accountreceivable_save

*/







/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_Update_Forecast]    Script Date: 3/2/2017 11:34:03 AM ******/

--/****** Object:  StoredProcedure [dbo].[Canvas_AR_AP_Update_Forecast]    Script Date: 4/1/2014 6:01:00 PM ******/
SET @Step = 'Create Canvas_AR_Update_Forecast'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_AR_AP_Update_Forecast') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  

  PROCEDURE  [dbo].[Canvas_AR_AP_Update_Forecast]
	@AR_Ap Nvarchar(2) =''''AR'''',
	@ETL Bit = 0
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	-- select * into #temp_parametervalues from temp_parametervalues

	If @ETL <> 0 Select * into #Temp_ParameterValues From Wrk_ETL_Values Where Proc_Name = ''''Canvas_AR_AP_Update_Forecast''''
	--@Alldim_Memberid Nvarchar(Max),@TimeID NVARCHAR(255),@ScenarioID NVARCHAR(255),@Entity INT,,@Time INT,@Account INT,@Invoice INT,@EntityID NVARCHAR(255),@ret bigint
	DECLARE @Scenario INT,@SourceScenario INT,@User Nvarchar(50),@modelname nvarchar(200),@Businessprocess INT,@BusinessprocessDim Nvarchar(50)
	,@InvoiceDim Nvarchar(50),@OrderDim Nvarchar(50),@ClientDim Nvarchar(50),@Account_Due_ID NVARCHAR(255),@Account_Opening_ID NVARCHAR(255)
	,@Account_Paid_ID NVARCHAR(255),@lap int,@scenarioDim Nvarchar(50),@TimeDim Nvarchar(50),@AccountDim Nvarchar(50),@EntityDim Nvarchar(50)
	DECLARE @DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max),@Found int,@Alldim Nvarchar(Max),@Otherdim Nvarchar(Max),@Sep Nvarchar(2)

	Select @user = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''
	Select @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''

    DECLARE     @Proc_Id BIGINT
    SELECT @Proc_ID = MAX(Proc_Id) FROM Canvas_User_Run_Status
    IF @Proc_ID IS NULL  SET @Proc_ID = 0
    SET @Proc_ID = @Proc_Id + 1
    declare @userid int
    Select @Userid =  UserId from Canvas_Users Where label = @user

    INSERT INTO Canvas_User_Run_Status  
    ([User_RecordId],[User],[Proc_Id],[Proc_Name],[Begin_Date],[End_Date])
    VALUES (@Userid,@User,@Proc_Id,''''Estimated_payment_Calculation'''',GETDATE(),'''''''') 

	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0

	SET @Lap = 1  ' 


			SET @SQLStatement = @SQLStatement + '


	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''

		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''InvoiceNo''''
		begin
			set @InvoiceDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Number''''
		begin
			set @OrderDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Customer''''
		begin
			set @ClientDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Supplier''''
		begin
			set @ClientDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType

	end
	close Dim_cursor
	deallocate Dim_cursor ' 


			SET @SQLStatement = @SQLStatement + '


	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')

	Set @Alldim = @Alldim + '''',[TimeDataView] ''''

	Create table #FactData (Value Float)
	SET @Sql = ''''ALTER TABLE #FactData ADD ''''+Replace(@Alldim,'''']'''',''''_Memberid] BIGINT'''')+'''', Datelabel Nvarchar(8) COLLATE SQL_Latin1_General_CP1_CI_AS
	, paymenthabit INT, FinalDateLabel INT ''''
	--Print(@Sql)
	EXEC(@Sql)

	
	Create Table #Account (memberid BIGINT,label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,KeyName_Account nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	--Create Table #Time (memberid BIGINT,label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,Source_memberid BIGINT,Source_Label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	Create Table #Temp (MemberID BIGINT)
	Create Table #TempLabel (Label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

	Truncate table #temp
	SET @Sql = ''''Insert into #temp Select memberid from ds_''''+@scenarioDim+'''' Where label = ''''''''ACTUAL'''''''' ''''
	EXEC(@Sql)
	select @SourceScenario = Memberid From #temp

	Truncate table #temp
	Set @sql = ''''Insert into #temp select Memberid from DS_''''+@ScenarioDim+'''' Where label = ''''''''FORECAST''''''''''''
	EXEC(@Sql)
	SELECT @Scenario = Memberid from #temp

	Set @sql = ''''INsert into #Account select memberid,label,KeyName_Account from [DS_''''+@AccountDim+''''] 
	Where KeyName_Account IN (''''''''Paid_''''+@AR_Ap+'''''''''''',''''''''Due_''''+@AR_Ap+'''''''''''')'''' 
	--Print(@Sql)
	EXEC(@Sql)

	Select @Account_Due_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''Due_''''+@AR_Ap
	Select @Account_Paid_ID = RTRIM(LTRIM(CAST(memberid as char))) from #account where KeyName_Account = ''''Paid_''''+@AR_Ap

	Truncate table #temp
	Set @sql = ''''INsert into #temp select memberid from [DS_''''+@BusinessprocessDim+''''] Where Label = ''''''''Input'''''''''''' 
	EXEC(@Sql)
	SElect @Businessprocess = Memberid from #temp 
	Truncate table #temp ' 


			SET @SQLStatement = @SQLStatement + '


	DECLARE @Year Nvarchar(4),@PYear Nvarchar(4),@TodayDate Nvarchar(8), @TodayDATEiD Nvarchar(10)

	SET @Sql = ''''INsert into #TempLabel Select Label from DS_''''+@Timedim+'''' 
	Where memberid in (Select memberid From #temp_parametervalues Where parameterName = ''''''''TimeMbrs'''''''')''''
	EXEC(@Sql)
	IF @@ROWCOUNT > 0
	BEGIN
		SELECT @TodayDate = Label from #TempLabel
	END
	ELSE
	BEGIN
		SET @TodayDate = YEAR(GETDATE()) * 10000 +  MONTH(GETDATE()) * 100 +  DAY(GETDATE()) 
	END

	Declare @Label nvarchar(8),@memberid BIGINT,@Source_Label nvarchar(8),@Source_memberid BIGINT, @oldlabel nvarchar(8),@Dest_Memberid BIGINT
	DECLARE @Select nvarchar(max)

		Set @Select  = REPLACE(@AllDim,'''']'''',''''_Memberid]'''')
		Truncate Table #temp
		Set @Sql = ''''Insert Into #temp Select memberid from DS_''''+@TimeDim+'''' Where Label = ''''''''''''+@Year+''''0101''''''''''''
		EXEC(@Sql)
		Select @Dest_Memberid = Memberid From #temp
		Set @Select  = REPLACE(@Select,''''[''''+@TimeDim+''''_Memberid]'''',Rtrim(CAST(@Dest_Memberid as Char)))

		Set @Sql = ''''DELETE FROM FACT_''''+@ModelName+''''_default_partition
		WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
		And [''''+@AccountDim+''''_Memberid] IN (''''+@Account_Paid_ID+'''')  ''''
		--PRINT(@Sql)
		EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


--		and ''''+@EntityDim+''''_Memberid in (Select Memberid from #temp_parametervalues Where parameterName = ''''''''EntityMbrs'''''''')


		Set @Sql = ''''DELETE FROM FACT_''''+@ModelName+''''_default_partition
		WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)+'''' 
		And [''''+@AccountDim+''''_Memberid] in (Select Memberid from DS_''''+@Accountdim+'''' 
		Where Label in (''''''''CFCAPPOR_'''''''',''''''''CFCAPPOM_'''''''',''''''''CFCAPSI_'''''''',''''''''CFCARSONS_'''''''',''''''''CFCARSOS_'''''''',''''''''CFCARSOI_'''''''',''''''''CFCARSI_'''''''',''''''''CFCAROI_'''''''')) ''''
		--PRINT(@Sql)
		EXEC(@Sql)

		Create Table #DestAccount (destmemberid BIGINT,destlabel Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
		memberid BIGINT,label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

		INsert into #DestAccount VALUES (0,''''CFCAPPOR_'''',0,''''CFCAPPORDue_'''')
		INsert into #DestAccount VALUES (0,''''CFCAPPOM_'''',0,''''CFCAPPOMDue_'''')
		INsert into #DestAccount VALUES (0,''''CFCAPSI_'''',0,''''CFCAPSIDue_'''')
		INsert into #DestAccount VALUES (0,''''CFCARSONS_'''',0,''''CFCARSONSDue_'''')
		INsert into #DestAccount VALUES (0,''''CFCARSOS_'''',0,''''CFCARSOSDue_'''')
		INsert into #DestAccount VALUES (0,''''CFCARSOI_'''',0,''''CFCARSOIDue_'''')
		INsert into #DestAccount VALUES (0,''''CFCARSI_'''',0,''''CFCARSIDue_'''')
		INsert into #DestAccount VALUES (0,''''CFCAROI_'''',0,''''CFCAROIDue_'''')
		INsert into #DestAccount VALUES (0,''''CFCOF_'''',0,''''CFCOFDue_'''')
		INsert into #DestAccount VALUES (0,''''CFCODLF_'''',0,''''CFCODLFDue_'''')
		INsert into #DestAccount VALUES (0,''''CFCOOCS_'''' ,0,''''CFCOOCSDue_'''')

		Set @sql = ''''Update #DestAccount set memberid = b.Memberid from #Destaccount a, DS_''''+@AccountDim+'''' b Where a.DestLabel = b.label''''
		Exec(@Sql)

		Set @sql = ''''Update #DestAccount set Destmemberid = b.Memberid from #Destaccount a, DS_''''+@AccountDim+'''' b Where a.DestLabel = b.label''''
		Exec(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


		SEt @Select = Replace(@AllDim,'''']'''',''''_memberid]'''')
		SEt @Select = Replace(@Select,''''['''',''''a.['''')
		SET @Select = Replace(@Select,''''a.[''''+@AccountDim+''''_memberid]'''',RTRIM(CAST(@Account_Paid_ID as char)))
		
		Set @Sql = ''''Insert into #FactData    
		Select 
		''''+@ModelName+''''_Value
		,''''+@Select+''''
		,''''''''''''''''
		,b.PaymentHabit 
		,''''''''''''''''
		From FACT_''''+@ModelName+''''_default_partition a, DS_''''+@ClientDim+'''' b --,#Time c
		WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@SourceScenario as char)+'''' 
		--and ''''+@TimeDim+''''_Memberid = c.Source_Memberid 
		and ''''+@EntityDim+''''_Memberid in (Select Memberid from #temp_parametervalues Where parameterName = ''''''''EntityMbrs'''''''')
		And [''''+@AccountDim+''''_Memberid] in (''''+@Account_Due_ID+'''')  
		And a.''''+@ClientDim+''''_memberId = b.Memberid 
		And a.''''+@invoiceDim+''''_MemberId in (Select Memberid from DS_''''+@invoiceDim+'''' Where paid = ''''''''N'''''''') ''''
		--PRINT(@Sql)
		EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


		Set @Sql = ''''Update #FactData set Datelabel = b.Label From #FactData a,DS_''''+@TimeDim+'''' b 
		Where Len(b.Label) = 8 and  a.''''+@TimeDim+''''_Memberid = b.Memberid ''''
		--PRINT(@Sql)
		EXEC(@Sql)

		Set @Sql = ''''Update #FactData set ''''+@ScenarioDim+''''_Memberid = ''''+CAST(@Scenario as char)
		--PRINT(@Sql)
		EXEC(@Sql)

		Update #FactData Set 
		FinaldateLabel = YEAR(DATEADD(day,PaymentHabit, DateLabel)) * 10000
		+ MONTH(DATEADD(day,PaymentHabit, DateLabel))*100 
		+ DAY(DATEADD(day,PaymentHabit, DateLabel))
		Where datelabel <> ''''None''''

		set @sql = ''''Update #FactData Set ''''+@TimeDim+''''_Memberid = b.memberid From #FactData a, DS_''''+@TimeDim+'''' b 
		Where Len(b.Label) = 8 and  a.FinalDateLabel = b.Label ''''
		--Print(@Sql)
		Exec(@Sql)

		Set @sql = ''''Update #FactData Set ''''+@BusinessprocessDim+''''_Memberid = ''''+CAST(@Businessprocess as char)
		EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


		Set @Sql = ''''INsert Into FACT_''''+@ModelName+''''_default_partition 
		(''''+@ModelName+''''_Value,''''+Replace(@Alldim,'''']'''',''''_Memberid]'''')+'''',[ChangeDateTime],userId)
		SELECT Value,''''+Replace(@Alldim,'''']'''',''''_Memberid]'''')+'''',GETDATE(),''''''''''''+@USer+''''''''''''
		From #FactData Where Value <> 0 ''''
		--PRINT(@Sql)
		EXEC(@Sql)

        UPDATE Canvas_User_Run_Status SET END_Date = GETDATE() WHERE Proc_Id = @Proc_Id

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END



/****** Object:  StoredProcedure [dbo].[Canvas_Asumption]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Asumption'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Asumption') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Asumption]
@AsType INT
,@Storeonly BIT = 0
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--DECLARE @AsType INT,@Storeonly BIT
--SET @astype = 2
--SET @Storeonly = 0

BEGIN
	DECLARE @Nb INT
	Select @NB = Count(*) From [EventDefinition] Where Action = ''''Canvas_Asumption_AccountUpdate''''
	IF @NB = 0
	BEGIN
		INSERT [dbo].[EventDefinition] ([Event], [Action], [ActionType], [ActionDescription], [SequenceNumber]) 
		VALUES (N''''EndDeploy'''', N''''Canvas_Asumption_AccountUpdate'''', 1, N''''Update Canvas AccountAsumption'''', 1)
	END 
	
	-- Drop table #temp_parametervalues
	-- select * into #temp_parametervalues from temp_parametervalues

	DECLARE @ScenarioID BIGINT,@TimeID BIGINT,@BusinessprocessID BIGINT,@AsumptionRateID BIGINT,@BusinessprocessInputID BIGINT,@BusinessprocessMemberid BIGINT
	,@Time  Nvarchar(255),@User Nvarchar(255),@ModelName Nvarchar(50)
	,@SourceAccount NVARCHAR(50), @SourceScenario NVARCHAR(50),@SourceTime NVARCHAR(50),@SourceCondition NVARCHAR(250)

	DECLARE @DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max),@Lap INT,@Params Nvarchar(max)
	declare @Found int,@Alldim Nvarchar(Max),@Otherdim Nvarchar(Max),@Sep Nvarchar(2)
	Declare  @AccountDim Nvarchar(50),@ScenarioDim Nvarchar(50),@EntityDim Nvarchar(50),@BusinessProcessDim Nvarchar(50),@CurrencyDim Nvarchar(50)
	,@TimeDim Nvarchar(50),@LineItemDim nvarchar(50),@VersionDim nvarchar(50),@Where Nvarchar(max),@Alldim2 Nvarchar(Max)

	Select @user = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''
	Select @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''


	Exec [Canvas_Asumption_AccountUpdate] @ModelName,@User

	SET @Where = ''''''''
	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0 ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Lap = 1 
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname+'''''''' And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''
		If @DimLabel = ''''LineItem'''' SET @DimType = ''''LineItem''''
		If @DimLabel = ''''Version'''' SET @DimType = ''''Version''''
		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Currency''''
		begin
			set @CurrencyDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''LineItem''''
		begin
			set @LineItemDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Version''''
		begin
			set @VersionDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
			set @Where = @Where + '''' AND a.[''''+@DimLabel+''''_Memberid] = b.[''''+@DimLabel+''''] ''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType

	end
	close Dim_cursor
	deallocate Dim_cursor ' 


			SET @SQLStatement = @SQLStatement + '
 

	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')

	Set @Alldim = @Alldim + '''',[TimeDataView] ''''

	set @Params = ''''@ScenarioIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @ScenarioIDOUT=[MemberId] from [#temp_parametervalues] where [parameterName]=''''''''ScenarioMbrs''''''''''''
	exec sp_executesql @sql, @Params, @ScenarioIDOUT=@Scenarioid OUTPUT

	set @Params = ''''@BusinessprocessIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''BR_AS''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessIDOUT=@BusinessprocessID OUTPUT

	set @Params = ''''@SourceAccountOUT nvarchar(50) OUTPUT''''
	set @SQL = ''''select @SourceAccountOUT=CAST([MemberId] as char) from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''SourceAccount''''''''''''
	exec sp_executesql @sql, @Params, @SourceAccountOUT=@SourceAccount OUTPUT

	set @Params = ''''@SourceScenarioOUT nvarchar(50) OUTPUT''''
	set @SQL = ''''select @SourceScenarioOUT=CAST([MemberId] as char) from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''SourceScenario''''''''''''
	exec sp_executesql @sql, @Params, @SourceScenarioOUT=@SourceScenario OUTPUT

	set @Params = ''''@SourceTimeOUT nvarchar(50) OUTPUT''''
	set @SQL = ''''select @SourceTimeOUT=CAST([MemberId] as char) from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''SourceTime''''''''''''
	exec sp_executesql @sql, @Params, @SourceTimeOUT=@SourceTime OUTPUT

	set @Params = ''''@SourceConditionOUT nvarchar(250) OUTPUT''''
	set @SQL = ''''select @SourceConditionOUT=CAST([MemberId] as char) from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''SourceCondition''''''''''''
	exec sp_executesql @sql, @Params, @SourceConditionOUT=@SourceCondition OUTPUT

	set @Params = ''''@BusinessprocessInputIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessInputIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''Input''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessInputIDOUT=@BusinessprocessInputID OUTPUT

	set @Params = ''''@AsumptionRateIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @AsumptionRateIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''AsumptionRate''''''''''''
	exec sp_executesql @sql, @Params, @AsumptionRateIDOUT=@AsumptionRateID OUTPUT
	If @@rowcount = 0 
	begin
		set @Params = ''''@AsumptionRateIDOUT nvarchar(20) OUTPUT''''
		set @SQL = ''''select @AsumptionRateIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''AssumptionRate''''''''''''
		exec sp_executesql @sql, @Params, @AsumptionRateIDOUT=@AsumptionRateID OUTPUT
	end
--==============================================> Debut StartPeriod
	Declare @Year INT
	Select @year = DefaultValue from Canvas_Workflow_Segment Where Dimension = @TimeDim 
 ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Time = (@Year * 100) + 1  	

	CREATE TABLE #Account (Account_Memberid BIGINT,Store Bit)

--	IF @Storeonly = 1
--	BEGIN
		INSERT INTO #Account SELECT Distinct account_Memberid, Store FROM dbo.Canvas_AsumptionAccount 
		WHERE --Store = 0 and AND 
		Asumption_Type = @AsType
--	END
--	ELSE
--	BEGIN
--		INSERT INTO #Account SELECT Distinct  account_Memberid, Store FROM dbo.Canvas_AsumptionAccount Where Asumption_Type = @AsType
--	END

	Create table #Time (NumPer INT IDENTITY(1,1),[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,Time_Memberid BIGINT
	,[Year] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,Year_Memberid BIGINT,[PrevPeriod] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,PrevPeriod_Memberid BIGINT,[OPenPeriod] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,OpenPeriod_Memberid BIGINT
	,[PrevYear] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,PrevYear_Memberid BIGINT)

	INSERT INTO #Time
	([Time],Time_Memberid,Year,PrevPeriod,OpenPeriod,PrevYear)
	Select label,Memberid,LEFT(Label,4)
	,CASE WHEN Right(Label,2) =''''01'''' THEN (CAST(LEFT(Label,4) as INT)-1) *100 + 12 ELSE CAST(Label as INT) - 1 END
	,(CAST(LEFT(Label,4) as INT)-1) *100 + 12 
	,CAST(Label as INT) - 100
	from DS_Time 
	Where Len(Label) = 6
	AND SUBSTRING(Label,5,1) <> ''''Q''''
	And Right(Label,2) Not in (''''00'''',''''13'''')
	And Memberid in (Select Memberid from #Temp_parameterValues Where parametername = ''''TimeMbrs'''')
	Order by [Label] ' 


			SET @SQLStatement = @SQLStatement + '


	Update #time Set Year_Memberid = b.Memberid From #time a,Ds_time b Where a.year = b.label
	Update #time Set PrevPeriod_Memberid = b.Memberid From #time a,Ds_time b Where a.Prevperiod = b.label
	Update #time Set openperiod_Memberid = b.Memberid From #time a,Ds_time b Where a.openperiod = b.label
	Update #time Set Prevyear_Memberid = b.Memberid From #time a,Ds_time b Where a.Prevyear = b.label
 
Create Table #TempRate (
Entity_memberid Bigint,Account_memberid Bigint,scenario_memberid Bigint,time_memberid Bigint,LineItem_memberid BIGINT
,S_Account Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,S_scenario Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
,S_Time Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,S_Condition Nvarchar(10)  COLLATE SQL_Latin1_General_CP1_CI_AS
,S_Account_memberid Bigint,S_scenario_memberid Bigint,S_time_memberid Bigint,Rate Float) ' 


			SET @SQLStatement = @SQLStatement + '


Create Table #Rate (
Entity_memberid Bigint,Account_memberid Bigint,scenario_memberid Bigint,time_memberid BIGINT,LineItem_memberid BIGINT
,S_Account Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,S_scenario Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
,S_Time Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,S_Condition Nvarchar(10)  COLLATE SQL_Latin1_General_CP1_CI_AS
,S_Account_memberid Bigint,S_scenario_memberid Bigint,S_time_memberid Bigint,Rate Float,AccSign INt)


SET @Sql = ''''INSERT into #Temprate
Select 
[Entity_Memberid] = [Entity_Memberid]
,[Account_memberid] = [Account_memberid]
,[Scenario_memberid] = [Scenario_memberid]
,[Time_memberid] = [Time_memberid]
,[LineItem_memberid] = [LineItem_memberid]
,S_Account = MAX(S_Account) 
,S_scenario = MAX(S_scenario) 
,S_Time = MAX(S_time) 
,S_Condition = MAX(S_Condition) 
,S_Account_memberid = S_Account_memberid
,S_scenario_memberid = S_scenario_memberid
,S_time_memberid = S_time_memberid
,Rate = SUM(Rate) 
FROM (
SELECT  ' 


			SET @SQLStatement = @SQLStatement + '

 [Entity_Memberid]  = a.[''''+@EntityDim+''''_Memberid]
,[Account_memberid] = a.[''''+@AccountDim+''''_memberid]
,[Scenario_memberid] = a.[''''+@ScenarioDim+''''_memberid]
,[Time_memberid] = b.[Time_memberid]
,[LineItem_memberid] = a.[LineItem_memberid]
,[S_Account] = CASE WHEN a.[''''+@BusinessprocessDim+''''_Memberid] = ''''+@SourceAccount+'''' THEN a.[''''+@ModelName+''''_Detail_Text] ELSE '''''''''''''''' END
,[S_Scenario] = CASE WHEN a.[''''+@BusinessprocessDim+''''_Memberid] = ''''+@SourceScenario+'''' THEN a.[''''+@ModelName+''''_Detail_Text] ELSE '''''''''''''''' END
,[S_Time] = CASE WHEN a.[''''+@BusinessprocessDim+''''_Memberid] = ''''+@SourceTime+'''' THEN a.[''''+@ModelName+''''_Detail_Text] ELSE '''''''''''''''' END
,[S_Condition] = CASE WHEN a.[''''+@BusinessprocessDim+''''_Memberid] = ''''+@Sourcecondition+'''' THEN REPLACE(a.[''''+@ModelName+''''_Detail_Text],'''''''' '''''''','''''''''''''''') ELSE '''''''''''''''' END
,S_Account_memberid = 0 
,S_scenario_memberid = 0 
,S_time_memberid = 0 
,rate =  0
from [FACT_''''+@ModelName+''''_Detail_Text] a,#Time b
Where a.[''''+@TimeDim+''''_Memberid] in (b.Time_Memberid,b.Year_Memberid) 
And b.Time_MemberId in (Select Memberid from #Temp_Parametervalues where parameterName = ''''''''TimeMbrs'''''''')
And a.[''''+@ScenarioDim+''''_MemberId] in (Select Memberid from #Temp_Parametervalues where parameterName = ''''''''ScenarioMbrs'''''''')
And a.[Version_MemberId] = -1
And a.[''''+@ModelName+''''_Detail_Text] <> ''''''''''''''''
UNION ALL
Select 
[Entity_memberid]=[''''+@EntityDim+''''_memberid]
,[Account_Memberid]=[''''+@AccountDim+''''_Memberid]
,[Scenario_Memberid]=[''''+@ScenarioDim+''''_Memberid]
,[Time_Memberid]=[''''+@TimeDim+''''_Memberid]
,[LineItem_Memberid]=[LineItem_Memberid]
,S_Account = ''''''''''''''''
,S_Scenario = ''''''''''''''''
,S_Time = ''''''''''''''''
,S_Condition = ''''''''''''''''
,S_Account_memberid=0
,S_scenario_memberid=0
,S_time_memberid=0
,Rate = ABS(''''+@ModelName+''''_Detail_Value) 
From FACT_''''+@modelname+''''_Detail_default_partition a 
Where  a. [''''+@BusinessProcessDim+''''_memberid] in (select memberid from [DS_''''+@BusinessProcessDim+''''] where label in (''''''''AsumptionRate'''''''',''''''''AssumptionRate''''''''))
And a.[''''+@TimeDim+''''_MemberId] in (Select Memberid from #Temp_Parametervalues where parameterName = ''''''''TimeMbrs'''''''')
And a.[''''+@ScenarioDim+''''_MemberId] in (Select Memberid from #Temp_Parametervalues where parameterName = ''''''''ScenarioMbrs'''''''')
And a.[''''+@AccountDim+''''_MemberId] in (Select Account_Memberid from #Account)
And a.[Version_MemberId] = -1
) As TMP 
group By  Entity_memberid,Account_memberid,scenario_memberid,time_memberid,LineItem_memberid
,S_Account_memberid,S_scenario_memberid,S_time_memberid ''''
PRINT (@Sql)
Exec(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


Create Table #Entity (Entity_Memberid BIGINT,Source_Entity_Memberid BIGINT)
Create Table #EntityTMP (Entity_Memberid BIGINT)

INSERT INTO #EntityTmp Select Distinct Entity_Memberid from #TempRate Where Entity_Memberid > 0
INSERT INTO #Entity Select Entity_Memberid, Entity_Memberid from #EntityTMP
INSERT  INTO #Entity Select Memberid, -1 From #temp_parametervalues 
where ParameterName = ''''EntityMbrs'''' and Memberid not in (Select Entity_Memberid from #EntityTMP) 


SET @Sql = ''''Update #TempRate Set S_Account_Memberid = b.Memberid from #Temprate a, [S_DS_''''+@AccountDim+''''] b Where a.S_Account = b.label''''
EXEC(@Sql)

If @AsType = 1
BEGIN
	SET @Sql = ''''Update #TempRate Set S_Scenario_Memberid = b.Memberid from #Temprate a, [DS_''''+@ScenarioDim+''''] b Where a.S_Scenario = b.label''''
	EXEC(@Sql)

	Update #TempRate Set S_Time_Memberid = b.PrevYear_Memberid from #Temprate a, #Time b Where a.Time_Memberid = b.Time_Memberid And A.S_Time = ''''Previous_Year''''
	Update #TempRate Set S_Time_Memberid = b.PrevPeriod_Memberid from #Temprate a, #Time b Where a.Time_Memberid = b.Time_Memberid And A.S_Time = ''''Previous_Period''''
	Update #TempRate Set S_Time_Memberid = b.OpenPeriod_Memberid from #Temprate a, #Time b Where a.Time_Memberid = b.Time_Memberid And A.S_Time = ''''Opening_Period''''
	Update #TempRate Set S_Time_Memberid = b.Time_Memberid from #Temprate a, #Time b Where a.Time_Memberid = b.Time_Memberid And A.S_Time = ''''Same_Period''''
END
If @AsType = 2
BEGIN
	Update #TempRate Set S_Scenario_Memberid = Scenario_Memberid Where S_Scenario_Memberid = 0 OR S_Scenario = '''''''' 
	Update #TempRate Set S_time_memberid = time_memberid Where S_Time_Memberid = 0 AND S_Time = ''''''''
	Update #TempRate Set S_Time_Memberid = b.PrevYear_Memberid from #Temprate a, #Time b Where a.Time_Memberid = b.Time_Memberid And A.S_Time = ''''Previous_Year''''
	Update #TempRate Set S_Time_Memberid = b.PrevPeriod_Memberid from #Temprate a, #Time b Where a.Time_Memberid = b.Time_Memberid And A.S_Time = ''''Previous_Period''''
	Update #TempRate Set S_Time_Memberid = b.OpenPeriod_Memberid from #Temprate a, #Time b Where a.Time_Memberid = b.Time_Memberid And A.S_Time = ''''Opening_Period''''
	Update #TempRate Set S_Time_Memberid = b.Time_Memberid from #Temprate a, #Time b Where a.Time_Memberid = b.Time_Memberid And A.S_Time = ''''Same_Period''''
END ' 


			SET @SQLStatement = @SQLStatement + '



SET @Sql = ''''
INSERT INTO #Rate Select  
a.Entity_Memberid,a.Account_Memberid,a.scenario_memberid
,a.time_memberid
,a.LineItem_memberid
,a.S_Account
,a.S_scenario
,a.S_Time 
,a.S_Condition 
,b.memberid 
,a.S_scenario_memberid
,a.S_time_memberid
,a.Rate Float 
,-1
From #Temprate a, [HC_''''+@AccountDim+''''] b Where a.S_Account_Memberid = b.parentid ''''
IF @AsType = 1 SET @Sql = @Sql + '''' AND S_Scenario_Memberid <> Scenario_Memberid ''''
IF @AsType = 2 SET @Sql = @Sql + '''' AND S_Scenario_Memberid  = Scenario_Memberid ''''
Print(@Sql)
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '



SET @sql = ''''Update #rate set AccSign = 1 Where Account_Memberid in (Select memberid from [S_DS_''''+@AccountDim+''''] Where sign = 1)''''
EXEC(@Sql) 

Update #rate Set S_Condition = Replace(S_Condition,'''' '''','''''''') 

Create Table #Fact(Value Float)
Set @Sql = ''''ALTER TABLE #Fact ADD ''''+REPLACE(@Alldim,'''']'''',''''_Memberid] BIGINT'''')+'''',S_Condition Nvarchar(10)  COLLATE SQL_Latin1_General_CP1_CI_AS''''
print (@sql)
EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '


Set @Alldim2 = REPLACE(@AllDim,'''']'''',''''_Memberid]'''')
Set @Alldim2 = REPLACE(@AllDim2,''''['''',''''a.['''')
Set @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@AccountDim+''''_Memberid]'''',''''b.[Account_Memberid]'''')
Set @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@ScenarioDim+''''_Memberid]'''',''''b.[Scenario_Memberid]'''')
Set @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@TimeDim+''''_Memberid]'''',''''b.[Time_Memberid]'''')

SET @BusinessprocessMemberid = @BusinessprocessID
IF @AsType = 1 SET @BusinessprocessMemberid = @BusinessprocessInputID

SET @Sql = ''''INSERT INTO #Fact 
Select ABS(a.[''''+@ModelName+''''_Value]) * b.[Rate] * b.AccSign 
,''''+REPLACE(@Alldim2,''''a.[''''+@BusinessProcessDim+''''_Memberid]'''',@BusinessprocessMemberid) +'''', b.S_Condition 
From [Fact_''''+@ModelName+''''_Default_Partition] a, #Rate b, #Entity e
Where a.[''''+@AccountDim+''''_Memberid] = b.S_Account_memberid
And a.[''''+@ScenarioDim+''''_Memberid] = b.S_Scenario_memberid
And a.[''''+@TimeDim+''''_Memberid] = b.S_Time_memberid 
And a.[''''+@EntityDim+''''_Memberid] = e.Entity_memberid
And b.[''''+@EntityDim+''''_Memberid] = e.Source_Entity_memberid
And a.[''''+@VersionDim+''''_MemberId] = -1
And a.[''''+@EntityDim+''''_Memberid] in (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''EntityMbrs'''''''') 
And a.[''''+@EntityDim+''''_Memberid] = e.Entity_memberid ''''
IF @AsType = 2 SET @Sql = @Sql + '''' And [''''+@BusinessprocessDim+''''_Memberid] <> ''''+CAST(@BusinessprocessID as Char) 
Print(@Sql)
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


Update #Fact Set Value = 0 Where Value < 0 And S_Condition = ''''>=0''''
Update #Fact Set Value = 0 Where Value > 0 And S_Condition = ''''<=0''''


SET @Sql = ''''UPDATE #Fact Set ''''+@BusinessProcessDim+''''_Memberid  = ''''+CAST(@BusinessprocessInputID AS CHAR)+'''' 
Where ''''+@AccountDim+''''_Memberid in (Select Account_Memberid from #Account Where store = 0)''''
EXEC(@sql)

SET @Sql = ''''DELETE FROM [FACT_''''+@ModelName+''''_Default_Partition]
Where [''''+@ScenarioDim+''''_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''ScenarioMbrs'''''''')
And [''''+@TimeDim+''''_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''TimeMbrs'''''''')
And [''''+@EntityDim+''''_Memberid] in (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''EntityMbrs'''''''') 
And [''''+@VersionDim+''''_MemberId] = -1
And [''''+@AccountDim+''''_Memberid] in (Select Account_Memberid from #Account WHere store = 0)   
And [''''+@BusinessprocessDim+''''_Memberid] not in (''''+RTRIM(LTRIM(CAST(@AsumptionRateID as char)))+'''') ''''
Exec(@Sql)

SET @Sql = ''''DELETE FROM [FACT_''''+@ModelName+''''_Default_Partition]
Where [''''+@ScenarioDim+''''_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''ScenarioMbrs'''''''')
And [''''+@TimeDim+''''_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''TimeMbrs'''''''')
And [''''+@EntityDim+''''_Memberid] in (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''EntityMbrs'''''''') 
And [''''+@VersionDim+''''_MemberId] = -1
And [''''+@AccountDim+''''_Memberid] in (Select Account_Memberid from #Account WHere store = 1)   
And [''''+@BusinessprocessDim+''''_Memberid] not in (''''+RTRIM(LTRIM(CAST(@AsumptionRateID as char)))+'''',''''+RTRIM(LTRIM(CAST(@BusinessprocessInputID as char)))+'''') ''''
Exec(@Sql)


SET @Sql = ''''INSERT INTO [FACT_''''+@ModelName+''''_Default_Partition]
(''''+REPLACE(@AllDim,'''']'''',''''_Memberid]'''')+'''',[''''+@ModelName+''''_Value],USerid,ChangeDateTime)
SELECT ''''+REPLACE(@AllDim,'''']'''',''''_Memberid]'''')+'''',SUM(Value),''''''''''''+@User+'''''''''''',GETDATE()
FROM #Fact  
Where 
Value <> 0 
Group By ''''+REPLACE(@AllDim,'''']'''',''''_Memberid]'''')
Print (@Sql)
EXEC(@Sql)

-- DROP TABLE #time,#TempRate,#Rate,#account,#fact,#Entity,#Entity,#EntityTMP

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END





/****** Object:  StoredProcedure [dbo].[Canvas_Asumption_AccountUpdate]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Asumption_AccountUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Asumption_AccountUpdate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Asumption_AccountUpdate]
@ModelName Nvarchar(50)  = ''''Financial''''
,@User Nvarchar(255) =''''Dspanel''''
,@UPDATEACC Nvarchar(255) =''''N''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--DECLARE @ModelName Nvarchar(50),@User Nvarchar(255),@UpdateACC Nvarchar(255)
--SET @ModelName = ''''Financials''''
--SET @user = ''''herve''''
--Set @UpdateACC = ''''N''''

BEGIN

	DECLARE @AccountDim Nvarchar(50),@BusinessprocessDim Nvarchar(50),@ScenarioDim Nvarchar(50), @Sql Nvarchar(Max)

	select @AccountDim = A.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] = ''''Account''''

	select @BusinessprocessDim = A.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] = ''''BusinessProcess''''

	select  @ScenarioDim = A.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] = ''''Scenario''''

	Declare @params Nvarchar(max),@BusinessprocessID Bigint,@IBusinessprocessID Bigint,@StoreBusinessprocessID Bigint,@SCBusinessprocessID Bigint,@PBusinessprocessID Bigint

	set @Params = ''''@BusinessprocessIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''SourceAccount''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessIDOUT=@BusinessprocessID OUTPUT

	set @Params = ''''@SCBusinessprocessIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @SCBusinessprocessIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''SourceScenario''''''''''''
	exec sp_executesql @sql, @Params, @SCBusinessprocessIDOUT=@SCBusinessprocessID OUTPUT

	set @Params = ''''@PBusinessprocessIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @PBusinessprocessIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''PREALLOC''''''''''''
	exec sp_executesql @sql, @Params, @PBusinessprocessIDOUT=@PBusinessprocessID OUTPUT

	set @Params = ''''@IBusinessprocessIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @IBusinessprocessIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''INPUT''''''''''''
	exec sp_executesql @sql, @Params, @IBusinessprocessIDOUT=@IBusinessprocessID OUTPUT

	set @Params = ''''@StoreBusinessprocessIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @StoreBusinessprocessIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''BP_STORE_AS''''''''''''
	exec sp_executesql @sql, @Params, @StoreBusinessprocessIDOUT=@StoreBusinessprocessID OUTPUT

	Create table #accountScenario (Account_Memberid BIGINT, Store Bit)
	Create table #account (Account_Memberid BIGINT, Store Bit)
	CREATE table #Store (Account_Memberid BIGINT)

	SET @Sql = ''''Insert into #accountScenario 
	Select Distinct a.Account_memberid,0
	from  Fact_''''+@ModelName+''''_Detail_Text a Where ''''+@BusinessprocessDim+''''_Memberid =  ''''+LTRIM(RTRIM(CAST(@SCBusinessprocessID as char))) +''''
	And ''''+@ModelName+''''_Detail_Text <> '''''''''''''''' '''' -- (SourceAcount)
	Print(@Sql)
	EXEC(@Sql)

	Set @Sql = ''''
	Insert into #Account 
	Select Distinct a.''''+@AccountDim+''''_memberid ,0
	from Fact_''''+@Modelname+''''_Detail_Text a 
	Where ''''+@BusinessprocessDim+''''_Memberid =  ''''+LTRIM(RTRIM(CAST(@BusinessprocessID as char))) 
	+'''' AND ''''+@AccountDim+''''_Memberid not in (Select Account_Memberid from #AccountScenario)
	And ''''+@ModelName+''''_Detail_Text <> '''''''''''''''' '''' 
	Print(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '

	
	Set @Sql = ''''Insert into #account
	Select a.''''+@AccountDim+''''_memberid,0 from 
	Fact_''''+@Modelname+''''_Detail_Text a, DS_''''+@ScenarioDim+'''' b,DS_''''+@BusinessprocessDim+'''' c 
	Where a.''''+@BusinessprocessDim+''''_memberid = c.Memberid  
	and c.label = ''''''''SourceScenario'''''''' 
	And a.''''+@ModelName+''''_Detail_Text = b.Label 
	and a.''''+@ScenarioDim+''''_Memberid = b.memberid 
	And ''''+@ModelName+''''_Detail_Text <> '''''''''''''''' '''' 
	Print(@Sql)
	EXEC(@Sql)

	Set @Sql = ''''Insert into #Store
	Select a.''''+@AccountDim+''''_memberid 
	from Fact_''''+@Modelname+''''_Detail_Text a 
	Where a.''''+@BusinessprocessDim+''''_memberid =''''+LTRIM(RTRIM(CAST(@StoreBusinessprocessID as char))) +''''
	And ''''+@ModelName+''''_Detail_Text <> ''''''''Yes'''''''' '''' 
	Print(@Sql)
	EXEC(@Sql)
	
	UPDATE #Account SET Store = 0 WHERE Account_Memberid IN (Select Account_Memberid FROM #Store)  
	UPDATE #Account SET Store = 1 WHERE Account_Memberid NOT IN (Select Account_Memberid FROM #Store)  
	UPDATE #accountScenario SET Store = 0 WHERE Account_Memberid IN (Select Account_Memberid FROM #Store)  

	IF @UPDATEACC = ''''Y''''
	BEGIN
		SET @Sql = ''''Update S_Ds_''''+@AccountDim+'''' set BP_Budget = ''''''''INPUT'''''''',BP_Budget_MemberId = ''''+LTRIM(RTRIM(CAST(@IBusinessprocessID as char)))+'''' 
		From S_DS_''''+@AccountDim+'''' a''''
	--	Print(@Sql)
		Exec(@Sql)

		SET @Sql = ''''Update S_Ds_''''+@AccountDim+'''' set BP_Budget = ''''''''PREALLOC'''''''',BP_Budget_MemberId = ''''+LTRIM(RTRIM(CAST(@PBusinessprocessID as char)))+'''' 
		From S_DS_''''+@AccountDim+'''' a, #Account b 
		Where a.Memberid = b.Account_Memberid 
		And b.Store = 0 ''''
	--	Print(@Sql)
		Exec(@Sql)


		SET @Sql = ''''TRUNCATE TABLE O_Ds_''''+@AccountDim
	--	Print(@Sql)
		Exec(@Sql)

		SET @Sql = ''''INSERT INTO O_Ds_''''+@AccountDim+'''' SELECT * from S_Ds_''''+@AccountDim+''''''''
	--	Print(@Sql)
		Exec(@Sql)

		Set @Sql = ''''UPDATE S_Dimensions SET ChangeDatetime = GETDATE() WHERE Label = ''''''''''''+@AccountDim+''''''''''''''''
	--	Print(@Sql)
		Exec(@Sql)
	END
	
	if not exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = /*$*/''''Canvas_AsumptionAccount''''/*$*/)  
	BEGIN
		CREATE TABLE [dbo].[Canvas_AsumptionAccount](
		[Account_Memberid] [bigint],
		Asumption_Type INT,
		Store bit) ON [PRIMARY]
	END
	Truncate table [Canvas_AsumptionAccount]
	
	INSERT INTO Canvas_AsumptionAccount 
	Select Account_memberid,2,Store From #Account
	UNION ALL  
	Select Account_memberid,1,Store From #AccountScenario where Account_memberid not in (select account_memberid from #account)

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END
-- Drop  table #Account,#Accountscenario,#Store
	
	




/****** Object:  StoredProcedure [dbo].[Canvas_Capex_BR]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Capex_BR'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Capex_BR') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
 PROCEDURE  [dbo].[Canvas_Capex_BR]
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

-- SELECT * INTO #temp_parametervalues FROM dbo.temp_parametervalues
BEGIN

/****** Script for SelectTopNRows command from SSMS  ******/
DECLARE @ScenarioID BIGINT
,@TimeID BIGINT
,@BusinessprocessID BIGINT
,@Time  Nvarchar(255)
,@MinTime  Nvarchar(255)
,@MaxOffset  INT
,@User Nvarchar(255)
,@ModelName Nvarchar(50)

--==================================================================================================================================
DECLARE @DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max),@Lap INT,@Params Nvarchar(max),@Select Nvarchar(max)
declare @Found int,@Alldim Nvarchar(Max),@AlldimS Nvarchar(Max),@Alldim_Memberid Nvarchar(Max),@Otherdim Nvarchar(Max),@Sep Nvarchar(2)
Declare  @AccountDim Nvarchar(50),@ScenarioDim Nvarchar(50),@EntityDim Nvarchar(50),@BusinessProcessDim Nvarchar(50),@CurrencyDim Nvarchar(50)
,@TimeDim Nvarchar(50),@LineItemDim nvarchar(50),@VersionDim nvarchar(50),@RoundDim nvarchar(50),@Where Nvarchar(max),@Group Nvarchar(max),@Alldim_Main Nvarchar(Max)

Declare @IsRound Bit
set @IsRound = 0

Select @user = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''
Select @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''

	SET @Where = ''''''''
	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Alldim_Main = ''''''''
	SET @Found = 0 ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Lap = 1 
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname+'''''''' And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''
		If @DimLabel = ''''LineItem'''' SET @DimType = ''''LineItem''''
		If @DimLabel = ''''Version'''' SET @DimType = ''''Version''''
		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Round''''
		begin
			set @RoundDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
			Set @IsRound = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Currency''''
		begin
			set @CurrencyDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''LineItem''''
		begin
			set @LineItemDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Version''''
		begin
			set @VersionDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
			set @Where = @Where + '''' AND a.[''''+@DimLabel+''''_Memberid] = b.[''''+@DimLabel+''''] ''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType

	end
	close Dim_cursor
	deallocate Dim_cursor ' 


			SET @SQLStatement = @SQLStatement + '
 

	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	IF @OtherDim <> '''''''' Set @AllDim_Main = @AllDim_Main + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')
	SET @Alldim_Main = Replace(@Alldim_Main,'''',,'''','''','''')

	Set @Alldim = @Alldim + '''',[TimeDataView] ''''
	SET @AllDim_Memberid = Replace(@Alldim,'''']'''',''''_Memberid]'''') 



--=================================================================================================================================
Select @user = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''UserId''''
Select @ModelName = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''Model''''

select @ScenarioID = Memberid From #Temp_ParameterValues Where parameterName = ''''ScenarioMbrs''''
select @TimeID = Memberid From #Temp_ParameterValues Where parameterName = ''''TimeMbrs''''
Select @BusinessprocessID = Memberid From Ds_BusinessProcess Where Label = ''''BR_CAPEX''''

--SET @TimeID = ''''31''''
--SET @ScenarioID = 4
--SET @User = ''''Herve-PC\Herve''''USE [DemoBudget_Epicor_New]
-- Select * into #temp_parametervalues from temp_parametervalues
-- Drop table  #temp_parametervalues
Select @Time = Label From DS_Time Where Memberid = @TimeID
Select @Maxoffset = MIN(BaseAmtTimeOffset) From LST_BSRuleDetail
SET @MinTime = YEAR(DATEADD(Month,@Maxoffset,@Time+''''01''''))*100 + MONTH(DATEADD(Month,@Maxoffset,@Time+''''01''''))

Create table #Time (NumPer INT IDENTITY(1,1),[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,Time_Memberid BIGINT)
Create table #TimeFinal (NumPer INT,[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,TimeOrigin_Memberid BIGINT,Time_Memberid BIGINT,TimeOffset INT)
Create table #TimeFinalPercent (NumPer INT,[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,TimeOrigin_Memberid BIGINT,Time_Memberid BIGINT,TimeOffset INT)

Create table #offsetAccount (TimeOffset INT)
INSERT INTO #offsetAccount Select Distinct BaseAmtTimeOffset from LST_BSRuleDetail

Create table #offsetPercent (TimeOffset INT)
INSERT INTO #offsetPercent Select Distinct BaseAmtTimeOffset from LST_BSRuleDetail ' 


			SET @SQLStatement = @SQLStatement + '


INSERT INTO #Time
([Time],Time_Memberid)
Select label,Memberid from DS_Time 
WHERE Memberid IN (SELECT memberid FROM #temp_parametervalues WHERE Parametername = ''''TimeMbrs'''')
--Where Len(Label) = 6
--AND SUBSTRING(Label,5,1) <> ''''Q''''
--And Right(Label,2) Not in (''''00'''',''''13'''')
--AND Label >= @MinTime	
--Order by [Label]

INSERT INTO #TimeFinal
Select a.*,a.Time_Memberid,b.Timeoffset 
from #time a,#offsetAccount b
Where a.Time_Memberid  =  @TimeID

Update #TimeFinal Set Numper = Numper + TimeOffset
Update #TimeFinal Set Time_Memberid = b.Time_Memberid,Time = b.Time From #TimeFinal a, #time b
Where a.Numper = b.NumPer

INSERT INTO #TimeFinalPercent
Select a.*,a.Time_Memberid,b.Timeoffset 
from #time a,#offsetPercent b
Where a.Time_Memberid  =  @TimeID

Update #TimeFinalPercent Set Numper = Numper + TimeOffset
Update #TimeFinalPercent Set Time_Memberid = b.Time_Memberid,Time = b.Time From #TimeFinalPercent a, #time b
Where a.Numper = b.NumPer

CREATE TABLE [#Account]
(
	[BSRule_RecordId] [bigint] NULL,
	[BSRuleDetail_RecordId] [bigint] NULL,
	[BaseAmtAcct_MemberId] [bigint] NULL,
	[BaseAmtTimeOffset] [int] NULL,
	[BasePctAcct_MemberId] [bigint] NULL,
	[BasePctTimeoffset] [int] NULL,
	[OnlyClosing] [bit] NULL,
	[Acct_MemberId] [bigint] NULL,
	[Sign] [int] NULL,
	[BSRuleMethod_RecordId] [bigint] NULL,
	[FixedPct] [float] NULL,
	[BusinessProcess_Destination_Memberid] Bigint NULL
) ON [PRIMARY] ' 


			SET @SQLStatement = @SQLStatement + '



CREATE TABLE [#AccountPercent]
(
	[BSRule_RecordId] [bigint] NULL,
	[BSRuleDetail_RecordId] [bigint] NULL,
	[BasePctAcct_MemberId] [bigint] NULL,
	[BasePctTimeoffset] [int] NULL,
	[OnlyClosing] [bit] NULL,
	[Acct_MemberId] [bigint] NULL,
	[Sign] [int] NULL,
	[BSRuleMethod_RecordId] [bigint] NULL,
	[FixedPct] [float] NULL,
	[BusinessProcess_Destination_Memberid] Bigint NULL
) ON [PRIMARY]

Insert into [#Account]
Select 
	 a.[BSRule_RecordId]
	,a.RecordId
	,b.Memberid as [BaseAmtAcct_MemberId]
	,a.[BaseAmtTimeOffset]
	,a.[BasePctAcct_MemberId]
	,a.[BasePctTimeoffset]
	,a.[OnlyClosing]
	,a.[Acct_MemberId]
	,a.[Sign]
	,a.[BSRuleMethod_RecordId]
	,a.[FixedPct]
	,c.[BusinessProcess_Destination_Memberid] 
From LST_BSRuleDetail a, Hc_Account b, LST_BSRules c
Where b.ParentId = a.[BaseAmtAcct_MemberId]
And a.BSRule_RecordId = c.RecordId ' 


			SET @SQLStatement = @SQLStatement + '



Insert into [#AccountPercent]
Select Distinct 
	 a.[BSRule_RecordId] 
	,a.RecordId
	,a.[BasePctAcct_MemberId]
	,a.[BasePctTimeoffset]
	,a.[OnlyClosing]
	,a.[Acct_MemberId]
	,a.[Sign]
	,a.[BSRuleMethod_RecordId]
	,a.[FixedPct]
	,c.[BusinessProcess_Destination_Memberid] 
From LST_BSRuleDetail a, Hc_Account b, LST_BSRules c
Where b.ParentId = a.[BaseAmtAcct_MemberId]
And a.BSRule_RecordId = c.RecordId

Create Table #Businessprocess (BusinessProcess_Memberid Bigint)
insert into #Businessprocess Select distinct BusinessProcess_Destination_Memberid from #account

CREATE TABLE #Fact(Financials_Value FLOAT
,Financials_percent Float
,Fix_percent Float
,[BSRule_RecordId] [bigint] NULL
,[BSRuleDetail_RecordId] [bigint] NULL
,[OnlyClosing] [bit] NULL
,[BSRuleMethod_RecordId] [bigint] NULL
)

SET @sql =''''ALTER TABLE #Fact ADD ''''+REPLACE(@Alldim,'''']'''',''''_Memberid] BIGINT'''')
EXEC(@Sql)

Select * Into #factPercent From #Fact 
Select * Into #factAmount From #Fact  ' 


			SET @SQLStatement = @SQLStatement + '



SET @AlldimS = REPLACE(@Alldim,'''']'''',''''_Memberid]'''')
SET @AlldimS = REPLACE(@AlldimS,''''['''',''''a.['''')
SET @AlldimS = REPLACE(@AllDimS,''''a.[''''+@AccountDim+''''_Memberid]'''',''''b.[Acct_MemberId]'''')
SET @AlldimS = REPLACE(@AllDimS,''''a.[''''+@BusinessProcessDim+''''_Memberid]'''',''''b.[BusinessProcess_Destination_Memberid]'''')
SET @AlldimS = REPLACE(@AllDimS,''''a.[''''+@TimeDim+''''_Memberid]'''',''''c.[TimeOrigin_Memberid]'''')

SET @Sql = ''''INSERT INTO #FactAmount
	SELECT 
	CASE WHEN b.[BSRuleMethod_RecordId] = 1 THEN a.''''+@Modelname+''''_Value * b.[Sign] * b.[FixedPct] ELSE a.''''+@Modelname+''''_Value * b.[Sign] END
	,0 As Financial_Percent
	,b.[FixedPct]
	,b.[BSRule_RecordId]
	,b.[BSRuleDetail_RecordId]
	,b.[OnlyClosing] 
	,b.[BSRuleMethod_RecordId],''''+@AllDimS+''''
	FROM  FACT_''''+@modelname+''''_default_partition a , #Account b, #TimeFinal c
	WHERE	a.''''+@ModelName+''''_Value <> 0
		And a.''''+@AccountDim+''''_Memberid = b.[BaseAmtAcct_MemberId]
		And a.''''+@TimeDim+''''_Memberid =  c.Time_Memberid
		And b.BaseAmtTimeOffset = c.TimeOffset	''''
		IF @Isround = 1 Set @sql = @sql + '''' 
		And a.''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parameterbname = ''''''''RoundMbrs'''''''') ''''
		Set @sql = @sql + ''''
		And a.''''+@Scenariodim+''''_Memberid = ''''+CAST(@ScenarioID AS CHAR)+'''' 
		And a.''''+@BusinessProcessDim+''''_MemberId <> b.BusinessProcess_Destination_Memberid ''''
	Print(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


SET @Sql = ''''INSERT INTO #factPercent
	SELECT 0 as financials_Value
	,0
	,SUM(''''+@ModelName+''''_Value) As Financials_Percent
	,b.[BSRule_RecordId]
	,b.[BSRuleDetail_RecordId]
	,b.[OnlyClosing] 
	,b.[BSRuleMethod_RecordId],''''+@AlldimS+''''
	FROM  FACT_''''+@ModelName+''''_default_partition a , #AccountPercent b, #TimeFinalPercent c
	WHERE	a.''''+@modelname+''''_Value <> 0
		And a.''''+@Accountdim+''''_Memberid = b.[BasePctAcct_MemberId]
		And a.''''+@Timedim+''''_Memberid =  c.Time_Memberid
		And b.BasePctTimeoffset = c.TimeOffset	
		And a.''''+@Scenariodim+''''_Memberid = ''''+CAST(@ScenarioID AS CHAR)
		IF @Isround = 1 Set @sql = @sql + '''' 
		And a.''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parameterbname = ''''''''RoundMbrs'''''''') ''''
		Set @sql = @sql + ''''
		And a.''''+@BusinessProcessdim+''''_MemberId <> b.BusinessProcess_Destination_Memberid 
Group by ''''+@AllDimS+'''',b.[BSRule_RecordId]
	,b.[BSRuleDetail_RecordId]
	,b.[OnlyClosing] 
	,b.[BSRuleMethod_RecordId] ''''

	SET @AlldimS = REPLACE(@Alldim,'''']'''',''''_Memberid]'''') ' 


			SET @SQLStatement = @SQLStatement + '

	
	SET @Sql =''''INSERT INTO #Fact
	SELECT SUM(Financials_Value) as financials_Value
		,SUM(Financials_Percent) as financials_percent
		,[Fix_Percent] = 0
		,[BSRule_RecordId]
		,[BSRuleDetail_RecordId]
		,[OnlyClosing] 
		,[BSRuleMethod_RecordId]
		,''''+@AlldimS+''''
	FROM (
	SELECT Financials_Value
		,0 As Financials_Percent
		,0 AS Fix_Percent
		,[BSRule_RecordId]
		,[BSRuleDetail_RecordId]
		,[OnlyClosing] 
		,[BSRuleMethod_RecordId]
		,''''+@AlldimS+''''
	FROM  #factAmount 
	UNION ALL
	SELECT 0 as Financials_Value
		,Financials_Percent
		, 0 AS Fix_percent
		,[BSRule_RecordId]
		,[BSRuleDetail_RecordId]
		,[OnlyClosing] 
		,[BSRuleMethod_RecordId]
		,''''+@AlldimS+''''
	FROM  #factPercent
	) AS tmp
	Group by ''''+@AlldimS+''''
	 	,[BSRule_RecordId]
		,[BSRuleDetail_RecordId]
		,[OnlyClosing] 
		,[BSRuleMethod_RecordId] ''''
	print(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '



	--Update #Fact Set Fix_Percent = b.FixedPct From #Fact a, LST_BSRuleDetail b 
	--Where a.BSRuleDetail_RecordId = b.RecordId

	--Update #Fact Set Financials_Value = Financials_Value * Fix_percent Where BSRuleMethod_RecordId = 1
	Update #Fact Set Financials_Value = Financials_Value * Financials_percent Where BSRuleMethod_RecordId = 2
	Update #Fact Set Financials_Value = Financials_Value * (1-Financials_percent) Where BSRuleMethod_RecordId = 3

	SET @Sql = ''''DELETE FROM FACT_''''+@ModelName+''''_default_partition 
	WHERE ''''+@ScenarioDim+''''_memberid = ''''+CAST(@ScenarioID AS CHAR)+'''' 
	And ''''+@BusinessProcessDim+''''_MemberId IN (Select BusinessProcess_MemberId From #Businessprocess)
	And ''''+@TimeDim+''''_memberid = ''''+ CAST(@TimeID  AS CHAR)
	IF @Isround = 1 Set @sql = @sql + '''' 
	And a.''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parameterbname = ''''''''RoundMbrs'''''''') ''''
	Exec(@sql)



	SET @AlldimS = REPLACE(@AllDimS,''''[''''+@ScenarioDim+''''_Memberid]'''',RTRIM(LTRIM(CAST(@ScenarioID AS CHAR))))
	SET @AlldimS = REPLACE(@AllDimS,''''[''''+@VersionDim+''''_Memberid]'''',-1)

	SET @Sql = ''''INSERT INTO [FACT_Financials_Default_Partition]
	(''''+REPLACE(@Alldim,'''']'''',''''_Memberid]'''')+''''
		  ,[ChangeDatetime]
		  ,[Userid]
		  ,[''''+@Modelname+''''_Value])
	SELECT ''''+@AlldimS+ ''''
		  ,Getdate() as [ChangeDatetime]
		  ,''''''''''''+@User+'''''''''''' as [Userid]
		  ,[Financials_Value]
	FROM #Fact ''''
	Print(@Sql)
	EXEC(@Sql)


END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

----   Drop table #max,#Account,#Fact,#time,#Min,#offsetAccount,#offsetPercent,#TimeFinal,#TimeFinalPercent,#FactPercent,#FactAmount,#AccountPercent,#Businessprocess






/****** Object:  StoredProcedure [dbo].[Canvas_Capex_Calculation]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Capex_Calculation'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Capex_Calculation') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Capex_Calculation]
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

/****** Script for SelectTopNRows command from SSMS  ******/
DECLARE @ScenarioID BIGINT
,@TimeID BIGINT
,@BusinessprocessID BIGINT
,@Time  Nvarchar(255)
,@User Nvarchar(255)
,@ModelName Nvarchar(50)

Select @user = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''UserId''''
Select @ModelName = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''Model''''

	select @ScenarioID = Memberid From #Temp_ParameterValues Where parameterName = ''''ScenarioMbrs''''

	Select @BusinessprocessID = Memberid From Ds_BusinessProcess Where Label = ''''BR_CAPEX''''

--==============================================> Debut StartPeriod
	declare @image varchar(max), @MaxVar INT

	Select @maxvar = MAX([version]) from [ApplicationDefinitionObjects] Where Type = ''''Variables'''' 

	Select @image = CAST(CAST([XmlDef] as Varbinary(Max)) as varchar(Max)) from [ApplicationDefinitionObjects]
	Where Type = ''''Variables'''' and version = @Maxvar

	DECLARE @Step1 INT,@Len INT,@Debut INT
	SET @Step1 =  CHARINDEX (''''BudgetFirstPeriod'''' ,@Image , 1  )
	SET @Debut =  CHARINDEX (''''[Time].[Time].['''' ,@Image , @Step1  ) + 15
	SET @len =  CHARINDEX ('''']'''' ,@Image , @Debut  ) - @Debut 

	Set @Time = Substring(@image,@debut,@len)
	select @TimeID = Memberid From DS_Time Where Label = @Time ' 


			SET @SQLStatement = @SQLStatement + '



Create table #Time (NumPer INT IDENTITY(1,1),[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,Time_Memberid BIGINT)
INSERT INTO #Time
([Time],Time_Memberid)
Select label,Memberid from DS_Time 
Where Len(Label) = 6
AND SUBSTRING(Label,5,1) <> ''''Q''''
And Right(Label,2) Not in (''''00'''',''''13'''')
AND Label >= @Time	
Order by [Label]

CREATE TABLE #Account (Account_Memberid BIGINT)
INSERT INTO #Account 
Select AssetBalanceAcct_MemberId From Ds_capex
UNION ALL
Select DepAcct_MemberId From Ds_capex 
UNION ALL
Select WIPAcct_MemberId From Ds_capex 
UNION ALL
Select CAshAcct_MemberId From Ds_capex 
UNION ALL
Select AccumDepAcct_MemberId From Ds_capex 

CREATE TABLE #Fact([Account_MemberId] BIGINT
,[BusinessProcess_MemberId] BIGINT
,[Currency_MemberId] BIGINT
,[Entity_Memberid] BIGINT
,[TimeDataView_MemberId] BIGINT
,[LineItem_Memberid] BIGINT
,[Time_Memberid] BIGINT
,[GL_Cost_Centre_Memberid] BIGINT
,[GL_Reference_Memberid] BIGINT
,[GL_Zone_Memberid] BIGINT
,[CAPEX_Memberid] BIGINT
,Financials_Detail_Value Float
,AssetBalanceAcct_MemberId BIGINT
,DepAcct_MemberId BIGINT
,DepMonths BIGINT
,WIPAcct_MemberId BIGINT
,CashAcct_MemberId BIGINT
,AccumDepAcct_MemberId BIGINT
,[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
,[MAXTime] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
,NumPer INT
,NumPerOrig INT
) ' 


			SET @SQLStatement = @SQLStatement + '


CREATE TABLE #FactCum(
 [Account_MemberId] BIGINT
,[Currency_MemberId] BIGINT
,[Entity_Memberid] BIGINT
,[TimeDataView_MemberId] BIGINT
,[LineItem_Memberid] BIGINT
,[Time_Memberid] BIGINT
,[GL_Cost_Centre_Memberid] BIGINT
,[GL_Reference_Memberid] BIGINT
,[GL_Zone_Memberid] BIGINT
,[CAPEX_Memberid] BIGINT
,Financials_Detail_Value Float
,NumPer INT
,NumPerOrig INT
) ' 


			SET @SQLStatement = @SQLStatement + '


--========================================

--=========================================
INSERT INTO #Fact
SELECT a.[Account_MemberId]
      ,a.[BusinessProcess_MemberId]
      ,a.[Currency_MemberId]
	  ,a.[Entity_Memberid]
      ,a.[TimeDataView_MemberId]
      ,a.[LineItem_Memberid]
      ,a.[Time_Memberid]
      ,a.[GL_Cost_Centre_Memberid]
      ,a.[GL_Reference_Memberid]
      ,a.[GL_Zone_Memberid]
      ,a.[CAPEX_Memberid]
	  ,Financials_Detail_Value
	  ,b.AssetBalanceAcct_MemberId
	  ,b.DepAcct_MemberId
	  ,b.DepMonths
	  ,b.WIPAcct_MemberId
	  ,b.CashAcct_MemberId
	  ,b.AccumDepAcct_MemberId
	  ,c.[Time]
	  ,''''''''
	  ,c.NumPer
	  ,c.NumPer
FROM [FACT_Financials_Detail_Default_Partition] a, DS_CAPEX b, #Time c
WHERE	a.Financials_Detail_Value <> 0
		And a.Capex_Memberid = b.Memberid
		And a.Time_Memberid =  c.Time_Memberid	
		And A.Scenario_Memberid = @ScenarioID
		AND a.[Version_MemberId]=-1
		And a.Account_Memberid in (Select Memberid from DS_account where Label = ''''CAPEX_SPEND'''')
		And a.BusinessProcess_MemberId <> @BusinessprocessID  ' 


			SET @SQLStatement = @SQLStatement + '

	
CREATE TABLE #Max
([BusinessProcess_MemberId] BIGINT
      ,[Currency_MemberId] BIGINT
	  ,[Entity_Memberid] BIGINT
      ,[TimeDataView_MemberId] BIGINT
      ,[LineItem_Memberid] BIGINT
      ,[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
      ,[GL_Cost_Centre_Memberid] BIGINT
      ,[GL_Reference_Memberid] BIGINT
      ,[GL_Zone_Memberid] BIGINT
      ,[CAPEX_Memberid] BIGINT
	  ,Time_Memberid BIGINT)
	  
CREATE TABLE #Min
(Account_Memberid BIGINT
      ,[BusinessProcess_MemberId] BIGINT
      ,[Currency_MemberId] BIGINT
	  ,[Entity_Memberid] BIGINT
      ,[TimeDataView_MemberId] BIGINT
      ,[LineItem_Memberid] BIGINT
      ,[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
      ,[GL_Cost_Centre_Memberid] BIGINT
      ,[GL_Reference_Memberid] BIGINT
      ,[GL_Zone_Memberid] BIGINT
      ,[CAPEX_Memberid] BIGINT
	  ,Financials_Detail_Value Float
	  ,Time_Memberid BIGINT
	  ,CashAcct_Memberid Bigint) ' 


			SET @SQLStatement = @SQLStatement + '


INSERT INTO #Max
SELECT [BusinessProcess_MemberId]
      ,[Currency_MemberId]
	  ,[Entity_Memberid]
      ,[TimeDataView_MemberId]
      ,[LineItem_Memberid]
      ,MAX([Time]) as [time]
      ,[GL_Cost_Centre_Memberid]
      ,[GL_Reference_Memberid]
      ,[GL_Zone_Memberid]
      ,[CAPEX_Memberid]
	  ,0
FROM [#FACT]
WHERE	Financials_Detail_Value <> 0
GROUP BY 
[BusinessProcess_MemberId]
,[Currency_MemberId]
,[Entity_Memberid]
,[TimeDataView_MemberId]
,[LineItem_Memberid]
,[GL_Cost_Centre_Memberid]
,[GL_Reference_Memberid]
,[GL_Zone_Memberid]
,[CAPEX_Memberid]

UPDATE #Max SET Time_Memberid = b.Memberid from #MAX a,DS_Time b Where a.Time = b.Label ' 


			SET @SQLStatement = @SQLStatement + '


DELETE FROM FACT_Financials_detail_default_partition 
WHERE Account_Memberid in (Select Account_Memberid from #Account)
AND Scenario_memberid = @ScenarioID
And BusinessProcess_MemberId = @BusinessprocessID 
And Time_memberid in (Select Time_MemberId from #Time)

DELETE FROM FACT_Financials_default_partition 
WHERE Account_Memberid in (Select Account_Memberid from #Account)
AND Scenario_memberid = @ScenarioID
And BusinessProcess_MemberId = @BusinessprocessID 
And Time_memberid in (Select Time_MemberId from #Time)


UPDATE #fact
SET MAXTime = b.[Time]
FROM #fact a,#Max b
Where a.[BusinessProcess_MemberId]=b.[BusinessProcess_MemberId]
      AND a.[Currency_MemberId]=b.[Currency_MemberId]
	  AND a.[Entity_Memberid]=b.[Entity_Memberid]
      AND a.[TimeDataView_MemberId]=b.[TimeDataView_MemberId]
      AND a.[LineItem_Memberid]=b.[LineItem_Memberid]
      AND a.[GL_Cost_Centre_Memberid]=b.[GL_Cost_Centre_Memberid]
      AND a.[GL_Reference_Memberid]= b.[GL_Reference_Memberid]
      AND a.[GL_Zone_Memberid] = b.[GL_Zone_Memberid]
      AND a.[CAPEX_Memberid]=b.[CAPEX_Memberid] ' 


			SET @SQLStatement = @SQLStatement + '


--=========================================================> BALANCESHEET ACCOUNT

UPDATE #FACT Set Numper = b.Numper,Numperorig = b.Numper from #fact a,#Time b where a.Maxtime = b.Time

INSERT INTO [FACT_Financials_Detail_Default_Partition]
([Account_MemberId],[BusinessProcess_MemberId],[Currency_MemberId],[Entity_Memberid],[TimeDataView_MemberId],[Version_MemberId]
,[LineItem_Memberid],[Scenario_Memberid],[Time_Memberid],[GL_Cost_Centre_Memberid],[GL_Reference_Memberid],[GL_Zone_Memberid]
,[CAPEX_Memberid],Financials_Detail_Value,USerid,ChangeDateTime)
SELECT a.AssetBalanceAcct_MemberId
      ,@BusinessprocessID
      ,a.[Currency_MemberId]
	  ,a.[Entity_Memberid]
      ,a.[TimeDataView_MemberId]
	  ,-1 as [Version_MemberId]
      ,a.[LineItem_Memberid]
	  ,@ScenarioID	
      ,b.[Time_Memberid]
      ,a.[GL_Cost_Centre_Memberid]
      ,a.[GL_Reference_Memberid]
      ,a.[GL_Zone_Memberid]
      ,a.[CAPEX_Memberid]
	  ,SUM(Financials_Detail_Value)
	  ,@USer
	  ,GETDATE()
FROM #Fact a,#Time b
Where --a.MAXTime = b.[time]
a.Financials_Detail_Value <> 0
And b.NumPer <= a.DepMonths + a.Numper -1
And b.NumPer >= a.Numper
Group by a.AssetBalanceAcct_MemberId,a.[Currency_MemberId],a.[Entity_Memberid],a.[TimeDataView_MemberId],a.[LineItem_Memberid]
      ,b.[Time_Memberid],a.[GL_Cost_Centre_Memberid],a.[GL_Reference_Memberid],a.[GL_Zone_Memberid],a.[CAPEX_Memberid] ' 


			SET @SQLStatement = @SQLStatement + '


--=========================================================> CASH ACCOUNT
INSERT INTO [FACT_Financials_Detail_Default_Partition]
([Account_MemberId],[BusinessProcess_MemberId],[Currency_MemberId],[Entity_Memberid],[TimeDataView_MemberId],[Version_MemberId]
,[LineItem_Memberid],[Scenario_Memberid],[Time_Memberid],[GL_Cost_Centre_Memberid],[GL_Reference_Memberid],[GL_Zone_Memberid]
,[CAPEX_Memberid],Financials_Detail_Value,USerid,ChangeDateTime)
SELECT a.CashAcct_MemberId
      ,@BusinessprocessID
      ,a.[Currency_MemberId]
	  ,a.[Entity_Memberid]
      ,a.[TimeDataView_MemberId]
	  ,-1 as [Version_MemberId]
      ,a.[LineItem_Memberid]
	  ,@ScenarioID	
      ,b.[Time_Memberid]
      ,a.[GL_Cost_Centre_Memberid]
      ,a.[GL_Reference_Memberid]
      ,a.[GL_Zone_Memberid]
      ,a.[CAPEX_Memberid]
	  ,SUM(Financials_Detail_Value)
	  ,@USer
	  ,GETDATE()
FROM #Fact a,#Time b
Where --a.MAXTime = b.[time]
a.Financials_Detail_Value <> 0
And b.NumPer <= a.DepMonths + a.Numper -1
And b.NumPer >= a.Numper
Group by a.CashAcct_MemberId,a.[Currency_MemberId],a.[Entity_Memberid],a.[TimeDataView_MemberId],a.[LineItem_Memberid]
      ,b.[Time_Memberid],a.[GL_Cost_Centre_Memberid],a.[GL_Reference_Memberid],a.[GL_Zone_Memberid],a.[CAPEX_Memberid] ' 


			SET @SQLStatement = @SQLStatement + '

--=========================================================> MIN FOR WIP
INSERT INTO #Min
SELECT a.WIPAcct_MemberId as Account_Memberid
      ,a.[BusinessProcess_MemberId]
      ,a.[Currency_MemberId]
	  ,a.[Entity_Memberid]
      ,a.[TimeDataView_MemberId]
      ,a.[LineItem_Memberid]
      ,b.[Time]
      ,a.[GL_Cost_Centre_Memberid]
      ,a.[GL_Reference_Memberid]
      ,a.[GL_Zone_Memberid]
      ,a.[CAPEX_Memberid]
	  ,a.Financials_Detail_Value
	  ,b.Time_Memberid
	  ,a.CashAcct_MemberId
FROM [#FACT] a, #Time b 
Where 
a.Financials_Detail_Value <> 0
AND a.Time < a.MAXTime
AND b.Time >= a.Time
AND b.Time < a.MAXTime ' 


			SET @SQLStatement = @SQLStatement + '


--UPDATE #Min SET Time_Memberid = b.Memberid from #MAX a,DS_Time b Where a.Time = b.Label

INSERT INTO [FACT_Financials_Detail_Default_Partition]
([Account_MemberId]
,[BusinessProcess_MemberId]
,[Currency_MemberId]
,[Entity_Memberid]
,[TimeDataView_MemberId]
,[Version_MemberId]
,[LineItem_Memberid]
,[Scenario_Memberid]
,[Time_Memberid]
,[GL_Cost_Centre_Memberid]
,[GL_Reference_Memberid]
,[GL_Zone_Memberid]
,[CAPEX_Memberid]
,Financials_Detail_Value
,USerid
,ChangeDateTime)
SELECT Account_MemberId
      ,@BusinessprocessID
      ,[Currency_MemberId]
	  ,[Entity_Memberid]
      ,[TimeDataView_MemberId]
	  ,-1 as [Version_MemberId]
      ,[LineItem_Memberid]
	  ,@ScenarioID	
      ,[Time_Memberid]
      ,[GL_Cost_Centre_Memberid]
      ,[GL_Reference_Memberid]
      ,[GL_Zone_Memberid]
      ,[CAPEX_Memberid]
	  ,Financials_Detail_Value
	  ,@USer
	  ,GETDATE()
FROM #Min ' 


			SET @SQLStatement = @SQLStatement + '

--=========================================================> CASH (WIP)
INSERT INTO [FACT_Financials_Detail_Default_Partition]
([Account_MemberId]
,[BusinessProcess_MemberId]
,[Currency_MemberId]
,[Entity_Memberid]
,[TimeDataView_MemberId]
,[Version_MemberId]
,[LineItem_Memberid]
,[Scenario_Memberid]
,[Time_Memberid]
,[GL_Cost_Centre_Memberid]
,[GL_Reference_Memberid]
,[GL_Zone_Memberid]
,[CAPEX_Memberid]
,Financials_Detail_Value 
,USerid
,ChangeDateTime)
SELECT CAshacct_Memberid as Account_MemberId
      ,@BusinessprocessID
      ,[Currency_MemberId]
	  ,[Entity_Memberid]
      ,[TimeDataView_MemberId]
	  ,-1 as [Version_MemberId]
      ,[LineItem_Memberid]
	  ,@ScenarioID	
      ,[Time_Memberid]
      ,[GL_Cost_Centre_Memberid]
      ,[GL_Reference_Memberid]
      ,[GL_Zone_Memberid]
      ,[CAPEX_Memberid]
	  ,Financials_Detail_Value
	  ,@USer
	  ,GETDATE()
FROM #Min ' 


			SET @SQLStatement = @SQLStatement + '


--===========================================================> DEPRECIATION


--UPDATE #FACT Set NumperOrig = b.Numper from #fact a,#Time b where a.time = b.Time

UPDATE #FACT SET Financials_Detail_Value = Financials_Detail_Value / DepMonths

INSERT INTO [FACT_Financials_Detail_Default_Partition]
([Account_MemberId]
,[BusinessProcess_MemberId]
,[Currency_MemberId]
,[Entity_Memberid]
,[TimeDataView_MemberId]
,[Version_MemberId]
,[LineItem_Memberid]
,[Scenario_Memberid]
,[Time_Memberid]
,[GL_Cost_Centre_Memberid]
,[GL_Reference_Memberid]
,[GL_Zone_Memberid]
,[CAPEX_Memberid]
,Financials_Detail_Value
,USerid
,ChangeDateTime) ' 


			SET @SQLStatement = @SQLStatement + '

SELECT a.DepAcct_Memberid as Account_Memberid
      ,@BusinessprocessID
      ,a.[Currency_MemberId]
	  ,a.[Entity_Memberid]
      ,a.[TimeDataView_MemberId]
	  ,-1 as [Version_MemberId]
      ,a.[LineItem_Memberid]
	  ,@ScenarioID as Scenario_Memberid
      ,b.[Time_Memberid]
      ,a.[GL_Cost_Centre_Memberid]
      ,a.[GL_Reference_Memberid]
      ,a.[GL_Zone_Memberid]
      ,a.[CAPEX_Memberid]
	  ,SUM(a.Financials_Detail_Value*-1)
	  ,@User
	  ,GETDATE()
FROM #Fact a, #Time b 
Where 
a.Financials_Detail_Value <> 0
And b.NumPer <= a.DepMonths + a.Numper -1
And b.NumPer >= a.Numper
GROUP BY a.DepAcct_Memberid
      ,a.[Currency_MemberId]
	  ,a.[Entity_Memberid]
      ,a.[TimeDataView_MemberId]
      ,a.[LineItem_Memberid]
      ,b.[Time_Memberid]
      ,a.[GL_Cost_Centre_Memberid]
      ,a.[GL_Reference_Memberid]
      ,a.[GL_Zone_Memberid]
      ,a.[CAPEX_Memberid] ' 


			SET @SQLStatement = @SQLStatement + '



INSERT INTO [#FactCum]
([Account_MemberId]
,[Currency_MemberId]
,[Entity_Memberid]
,[TimeDataView_MemberId]
,[LineItem_Memberid]
,[Time_Memberid]
,[GL_Cost_Centre_Memberid]
,[GL_Reference_Memberid]
,[GL_Zone_Memberid]
,[CAPEX_Memberid]
,Financials_Detail_Value
,Numper
,NumperOrig)
SELECT a.AccumDepAcct_MemberId as Account_Memberid
      ,a.[Currency_MemberId]
	  ,a.[Entity_Memberid]
      ,a.[TimeDataView_MemberId]
      ,a.[LineItem_Memberid]
      ,b.[Time_Memberid]
      ,a.[GL_Cost_Centre_Memberid]
      ,a.[GL_Reference_Memberid]
      ,a.[GL_Zone_Memberid]
      ,a.[CAPEX_Memberid]
	  ,SUM(a.Financials_Detail_Value*-1)
	  ,b.Numper
	  ,a.Numperorig
FROM #Fact a, #Time b 
Where 
a.Financials_Detail_Value <> 0
And b.NumPer <= a.DepMonths + a.Numper -1
And b.NumPer >= a.Numper
GROUP BY a.AccumDepAcct_MemberId
      ,a.[Currency_MemberId]
	  ,a.[Entity_Memberid]
      ,a.[TimeDataView_MemberId]
      ,a.[LineItem_Memberid]
      ,b.[Time_Memberid]
      ,a.[GL_Cost_Centre_Memberid]
      ,a.[GL_Reference_Memberid]
      ,a.[GL_Zone_Memberid]
      ,a.[CAPEX_Memberid]
	  ,b.Numper
	  ,a.Numperorig ' 


			SET @SQLStatement = @SQLStatement + '


INSERT INTO [FACT_Financials_Detail_Default_Partition]
([Account_MemberId]
,[BusinessProcess_MemberId]
,[Currency_MemberId]
,[Entity_Memberid]
,[TimeDataView_MemberId]
,[Version_MemberId]
,[LineItem_Memberid]
,[Scenario_Memberid]
,[Time_Memberid]
,[GL_Cost_Centre_Memberid]
,[GL_Reference_Memberid]
,[GL_Zone_Memberid]
,[CAPEX_Memberid]
,Financials_Detail_Value
,USerid
,ChangeDateTime)
SELECT a.Account_Memberid
      ,@BusinessprocessID
      ,a.[Currency_MemberId]
	  ,a.[Entity_Memberid]
      ,a.[TimeDataView_MemberId]
	  ,-1 as [Version_MemberId]
      ,a.[LineItem_Memberid]
	  ,@ScenarioID as Scenario_Memberid
      ,a.[Time_Memberid]
      ,a.[GL_Cost_Centre_Memberid]
      ,a.[GL_Reference_Memberid]
      ,a.[GL_Zone_Memberid]
      ,a.[CAPEX_Memberid]
	  ,a.Financials_Detail_Value *(Numper - NumperOrig + 1) 
	  ,@User
	  ,GETDATE()
FROM #FactCum a
Where 
a.Financials_Detail_Value <> 0 ' 


			SET @SQLStatement = @SQLStatement + '


--===========================================================> INSERT INTO FINANCIALS
	INSERT INTO FACT_Financials_default_partition
	([Account_MemberId]	,[BusinessProcess_MemberId]	,[Currency_MemberId]	,[Entity_MemberId]	,[Scenario_MemberId]
	,[Time_MemberId]	,[TimeDataView_MemberId]	,[Version_MemberId]	,[GL_Cost_Centre_MemberId]	,[GL_Reference_MemberId]
	,[GL_Zone_MemberId]	,[ChangeDatetime]	,[Userid]	,[Financials_Value])
	Select a.[Account_MemberId] 	,a.[BusinessProcess_MemberId]	,a.[Currency_MemberId]	,a.[Entity_MemberId]	,a.[Scenario_MemberId]
	,a.[Time_MemberId]	,a.[TimeDataView_MemberId]	,a.[Version_MemberId]	,a.[GL_Cost_Centre_MemberId]	,a.[GL_Reference_MemberId]
	,a.[GL_Zone_MemberId]	,GETDATE()	,@User	,SUM(a.[Financials_Detail_Value])
	FROM FACT_Financials_Detail_default_partition a, #Time b
	Where a.Time_MemberId = b.Time_Memberid
	And a.Account_Memberid in (Select Account_Memberid from #Account)
	And a.Scenario_MemberId = @ScenarioID
	GROUP BY a.[Account_MemberId] 	,a.[BusinessProcess_MemberId]	,a.[Currency_MemberId]	,a.[Entity_MemberId]	,a.[Scenario_MemberId]
	,a.[Time_MemberId]	,a.[TimeDataView_MemberId]	,a.[Version_MemberId]	,a.[GL_Cost_Centre_MemberId]	,a.[GL_Reference_MemberId]
	,a.[GL_Zone_MemberId]

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

/****** Object:  StoredProcedure [dbo].[Canvas_CashFlow_Calculation]    Script Date: 9/5/2014 3:48:00 PM ******/
SET ANSI_NULLS ON









/****** Object:  StoredProcedure [dbo].[Canvas_Capex_Calculation2]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Capex_Calculation2'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Capex_Calculation2') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Capex_Calculation2]
@Dim1 Nvarchar(50)  = ''''''''
,@Dim2 Nvarchar(50) = ''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS


BEGIN

--Declare @Dim1 Nvarchar(50), @Dim2 Nvarchar(50)
--SET @Dim1= ''''''''
--SET @Dim2= ''''''''

--  Drop table #temp_parametervalues  
--  Select * into  #temp_parametervalues  from  temp_parametervaluesHC 
/****** Script for SelectTopNRows command from SSMS  ******/
DECLARE @ScenarioID BIGINT
,@TimeID BIGINT
,@BusinessprocessID BIGINT
,@BusinessprocessMID BIGINT
,@Time  Nvarchar(255)
,@User Nvarchar(255)
,@ModelName Nvarchar(50)

DECLARE @DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max),@Lap INT,@Params Nvarchar(max),@Select Nvarchar(max)
declare @Found int,@Alldim Nvarchar(Max),@Alldim_Memberid Nvarchar(Max),@Otherdim Nvarchar(Max),@Sep Nvarchar(2)
Declare  @AccountDim Nvarchar(50),@ScenarioDim Nvarchar(50),@EntityDim Nvarchar(50),@BusinessProcessDim Nvarchar(50),@CurrencyDim Nvarchar(50)
,@TimeDim Nvarchar(50),@LineItemDim nvarchar(50),@RoundDim nvarchar(50),@VersionDim nvarchar(50),@Where Nvarchar(max),@Group Nvarchar(max),@Alldim_Main Nvarchar(Max)

Select @user = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''

SELECT @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''
IF RIGHT(@Modelname,7) <> ''''_Detail'''' SET @ModelName = @Modelname + ''''_Detail''''

DECLARE @IsRound Bit
Set @IsRound = 0

	SET @Where = ''''''''
	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Alldim_Main = ''''''''
	SET @Found = 0 ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Lap = 1 
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname+'''''''' And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''
		If @DimLabel = ''''LineItem'''' SET @DimType = ''''LineItem''''
		If @DimLabel = ''''Version'''' SET @DimType = ''''Version''''
		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Round''''
		begin
			set @RoundDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
			Set @IsRound = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Currency''''
		begin
			set @CurrencyDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''LineItem''''
		begin
			set @LineItemDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Version''''
		begin
			set @VersionDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			SET @AllDim_Main = @AllDim_Main + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
			set @Where = @Where + '''' AND a.[''''+@DimLabel+''''_Memberid] = b.[''''+@DimLabel+''''] ''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType

	end
	close Dim_cursor
	deallocate Dim_cursor ' 


			SET @SQLStatement = @SQLStatement + '
 

	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	IF @OtherDim <> '''''''' Set @AllDim_Main = @AllDim_Main + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')
	SET @Alldim_Main = Replace(@Alldim_Main,'''',,'''','''','''')

	Set @Alldim = @Alldim + '''',[TimeDataView] ''''
	SET @AllDim_Memberid = Replace(@Alldim,'''']'''',''''_Memberid]'''') 

	Set @Alldim_Main = @Alldim_Main + '''',[TimeDataView] ''''
	SET @Alldim_Main = Replace(@Alldim_Main,'''']'''',''''_Memberid]'''') 

	SET @Where = '''' ''''
	IF @Dim1 <> '''''''' SET @Where =  @Where + '''' 
	AND ''''+@Dim1+''''_Memberid IN (Select Memberid From #temp_parametervalues Where ParameterName = ''''''''''''+@Dim1+''''Mbrs'''''''')''''
	IF @Dim2 <> '''''''' SET @Where =  @Where + '''' 
	AND ''''+@Dim2+''''_Memberid IN (Select Memberid From #temp_parametervalues Where ParameterName = ''''''''''''+@Dim2+''''Mbrs'''''''')''''

--select @ScenarioID = Memberid From #temp_parametervalues Where parameterName = ''''ScenarioMbrs''''
	set @Params = ''''@ScenarioIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @ScenarioIDOUT=[MemberId] from [#temp_parametervalues] where [parameterName]=''''''''ScenarioMbrs''''''''''''
	exec sp_executesql @sql, @Params, @ScenarioIDOUT=@Scenarioid OUTPUT

--	Select @BusinessprocessID = Memberid From Ds_BusinessProcess Where Label = ''''BR_CAPEX''''
	set @Params = ''''@BusinessprocessIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''BR_CAPEX''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessIDOUT=@BusinessprocessID OUTPUT

	set @Params = ''''@BusinessprocessMIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessMIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''Depr_Year''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessMIDOUT=@BusinessprocessMID OUTPUT

--==============================================> Debut StartPeriod
	Declare @Year INT
	Select @year = DefaultValue from Canvas_Workflow_Segment Where Dimension = @TimeDim  And Model = REPLACE(@ModelName,''''_Detail'''','''''''')

SET @Time = (@Year * 100) + 1  	

Create table #Time (NumPer INT IDENTITY(1,1),[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,Time_Memberid BIGINT
,[TimeText] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,TimeText_Memberid BIGINT)

Set @sql = '''' INSERT INTO #Time
([Time],Time_Memberid,TimeText,TimeText_Memberid)
Select label,Memberid,LEFT(Label,4)+''''''''01'''''''',0 from DS_Time 
Where Len(Label) = 6
AND SUBSTRING(Label,5,1) <> ''''''''Q''''''''
And Right(Label,2) Not in (''''''''00'''''''',''''''''13'''''''')
AND Label >= ''''''''''''+@Time+''''''''''''
Order by [Label]''''
Print(@sql)
Exec(@sql) ' 


			SET @SQLStatement = @SQLStatement + '



Update #Time set Timetext_memberid = b.Memberid From #Time a,DS_Time b Where b.label = @Time

CREATE TABLE #DelAccount (Account_Memberid BIGINT)
CREATE TABLE #Account (Account_Memberid BIGINT,DAccount_Memberid BIGINT,S_Account_Memberid BIGINT,A_Account_Memberid BIGINT,C_Account_Memberid BIGINT,IsCopy Bit)
INSERT INTO #Account Select AssetAccount_memberid, PL_Depr_account_memberid,Selling_memberid,Admin_memberid,COGS_memberid,copy From LST_Depreciation

INSERT INTO #DelAccount 
Select PL_Depr_account_memberid From LST_Depreciation
UNION ALL 
Select Selling_memberid From LST_Depreciation
UNION ALL 
Select Admin_memberid From LST_Depreciation
UNION ALL 
Select COGS_memberid From LST_Depreciation
--Select Distinct destination_account_memberid from LST_Depreciation_Exception

CREATE TABLE #Fact (Value Float) ' 


			SET @SQLStatement = @SQLStatement + '


SET @Sql = ''''ALTER TABLE #fact ADD '''' 
+REPLACE(@AllDim,'''']'''',''''_Memberid] BIGINT'''')+''''
,Daccount_MemberId BIGINT
,S_account_MemberId BIGINT
,A_account_MemberId BIGINT
,C_account_MemberId BIGINT
,DepMonths BIGINT
,[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
,NumPer INT
,NumPerOrig INT''''
Print(@Sql)
EXEC(@Sql)

Alter table #fact ADD MyText Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,Iscopy bit 
Select * into #Fact_Amount from #fact
--Select * into #Fact_Copy  from #fact
Select * into #Fact_Month  from #fact
Select * into #Fact_Text from #fact

--SET @Select = REPLACE(@Alldim,'''']'''',''''_Memberid]'''')
SET @Select = REPLACE(@Alldim_Memberid,''''['''',''''a.['''')
--SET @Select = REPLACE(@Select,''''a.[''''+@AccountDim+''''_Memberid]'''',''''b.[DAccount_Memberid]'''')
SET @Select = REPLACE(@Select,''''a.[''''+@BusinessProcessDim+''''_Memberid]'''', LTRIM(RTRIM(CAST(@BusinessprocessID as char))) )

SET @Sql = ''''INSERT INTO #Fact_Amount
SELECT a.[''''+@ModelName+''''_Value], '''' + @Select + '''' 
	  ,b.Daccount_Memberid
	  ,b.S_account_Memberid
	  ,b.A_account_Memberid
	  ,b.C_account_Memberid
	  ,0
  	  ,c.[Time]
	  ,c.NumPer
	  ,c.NumPer
	  ,''''''''''''''''
	  ,b.Iscopy
FROM [FACT_''''+@ModelName+''''_Default_Partition] a, #Account b, #Time c
WHERE	a.''''+@ModelName+''''_Value <> 0
		And a.[''''+@AccountDim+''''_Memberid] = b.Account_Memberid
		And a.[''''+@TimeDim+''''_Memberid] =  c.Time_Memberid	
		And A.[''''+@ScenarioDim+''''_Memberid] = ''''+CAST(@ScenarioID as char)+'''' 
		AND a.[''''+@VersionDim+''''_MemberId] = -1
		And a.[''''+@BusinessProcessDim+''''_MemberId] Not in (''''+CAST(@BusinessprocessID as char)+'''',''''+CAST(@BusinessprocessMID as char)+'''')''''
		+@Where
		IF @IsRound = 1 set @sql = @sql + ''''
		And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''')''''
Print(@Sql)
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '



SET @Sql = ''''INSERT INTO #Fact_month
SELECT a.[''''+@ModelName+''''_Value], '''' + @Select + '''' 
	  ,b.Daccount_Memberid
	  ,b.S_account_Memberid
	  ,b.A_account_Memberid
	  ,b.C_account_Memberid
	  ,0
  	  ,''''''''''''''''
	  ,0
	  ,0
	  ,''''''''''''''''
	  ,b.Iscopy
FROM [FACT_''''+@ModelName+''''_Default_Partition] a, #Account b, #Time c
WHERE	a.''''+@ModelName+''''_Value <> 0
		And a.[''''+@AccountDim+''''_Memberid] = b.Account_Memberid
		And a.[''''+@TimeDim+''''_Memberid] =  c.Time_Memberid	
		And A.[''''+@ScenarioDim+''''_Memberid] = ''''+CAST(@ScenarioID as char)+'''' 
		AND a.[''''+@VersionDim+''''_MemberId] = -1
		And a.[''''+@BusinessProcessDim+''''_MemberId] = ''''+CAST(@BusinessprocessMID as char)
		+@Where
		IF @IsRound = 1 set @sql = @sql + ''''
		And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''')''''
Print(@Sql)
EXEC(@Sql)

SET @Select = REPLACE(@Select,''''a.[''''+@TimeDim+''''_Memberid]'''', ''''c.[Time_Memberid]'''' )
SET @Select = REPLACE(@Select,''''a.[Timedataview_Memberid]'''', ''''4'''' )

SET @Sql = ''''INSERT INTO #Fact_Text
SELECT 0, '''' + @Select + '''' 
	  ,b.Daccount_Memberid
	  ,b.S_account_Memberid
	  ,b.A_account_Memberid
	  ,b.C_account_Memberid
	  ,0
  	  ,''''''''''''''''
	  ,0
	  ,0
	  ,a.[''''+@ModelName+''''_Text]
	  ,b.Iscopy
FROM [FACT_''''+@ModelName+''''_Text] a, #Account b, #Time c
WHERE	a.''''+@ModelName+''''_Text <> ''''''''''''''''
		And a.[''''+@AccountDim+''''_Memberid] = b.Account_Memberid
		And a.[''''+@TimeDim+''''_Memberid] =  c.TimeText_Memberid	
		And A.[''''+@ScenarioDim+''''_Memberid] = ''''+CAST(@ScenarioID as char)+'''' 
		AND a.[''''+@VersionDim+''''_MemberId] = -1
		And a.[''''+@BusinessProcessDim+''''_MemberId] = -1''''
		+@Where
		IF @IsRound = 1 set @sql = @sql + ''''
		And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''')''''
Print(@Sql)
EXEC(@Sql)

SET @Select = REPLACE(@Alldim_Memberid,''''[''''+@TimeDim+''''_Memberid]'''',''''0 as [''''+@TimeDim+''''_Memberid]'''') ' 


			SET @SQLStatement = @SQLStatement + '


SET @Sql = ''''
INSERT INTO #fact
SELECT	
	Sum([Value]) as Value
	,''''+@Alldim_Memberid+''''
	,Daccount_Memberid	    
	,S_account_Memberid
	,A_account_Memberid
	,C_account_Memberid
	,Sum(DepMonths) as depmonths
	,Max([Time]) As Time	    
	,Max(NumPer) as Numper	    
	,Max(NumPerOrig) as NumperOrig 
	,Max(Mytext) as MyText
    ,Iscopy
FROM (
Select  
	[Value]
	,''''+@Select+''''		
	,Daccount_Memberid	
	,S_account_Memberid
	,A_account_Memberid
	,C_account_Memberid
	,DepMonths 
	,[Time]	   
	,NumPer	    
	,NumPerOrig
	,MyText
    ,Iscopy
FROM #Fact_Amount Where IsCopy = 0
UNION ALL ' 


			SET @SQLStatement = @SQLStatement + '

Select  
	[Value]
	,''''+@Alldim_Memberid+''''		
	,Daccount_Memberid	
	,S_account_Memberid
	,A_account_Memberid
	,C_account_Memberid
	,DepMonths 
	,[Time]	   
	,NumPer	    
	,NumPerOrig
	,MyText
    ,Iscopy
FROM #Fact_Amount Where IsCopy = 1
UNION ALL ' 


			SET @SQLStatement = @SQLStatement + '

Select  
	0 as value
	,''''+@Select+''''
	,Daccount_Memberid
	,S_account_Memberid
	,A_account_Memberid
	,C_account_Memberid
	,value*12 as DepMonths
	,[Time]	    
	,NumPer	    
	,NumPerOrig
	,MyText
    ,Iscopy
FROM #Fact_Month
UNION ALL
Select  
	0 as value
	,''''+@Select+''''
	,Daccount_Memberid
	,S_account_Memberid
	,A_account_Memberid
	,C_account_Memberid
	,0 As DepMonths
	,[Time]	    
	,NumPer	    
	,NumPerOrig
	,MyText
    ,Iscopy
FROM #Fact_text
) as tmp
group by ''''+@AllDim_Memberid+'''' ,Daccount_Memberid,S_account_Memberid	,A_account_Memberid	,C_account_Memberid,Iscopy ''''
Print(@Sql)
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


SET @Sql = ''''DELETE FROM FACT_''''+@ModelName+''''_default_partition 
WHERE [''''+@AccountDim+''''_Memberid] in (Select Account_Memberid from #Account)
AND [''''+@ScenarioDim+''''_memberid] = ''''+CAST(@ScenarioID as Char)+'''' 
And [''''+@BusinessProcessDim+''''_MemberId] = ''''+CAST(@BusinessprocessID as Char)+'''' 
And [''''+@TimeDim+''''_memberid] in (Select Time_MemberId from #Time)''''
+@Where
IF @IsRound = 1 set @sql = @sql + ''''
And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''')''''
Print(@Sql)
EXEC(@Sql)

SET @Sql = ''''DELETE FROM FACT_''''+REPLACE(@ModelName,''''_Detail'''','''''''')+''''_default_partition 
WHERE [''''+@AccountDim+''''_Memberid] in (Select Account_Memberid from #DelAccount)
AND [''''+@ScenarioDim+''''_memberid] = ''''+CAST(@ScenarioID as Char)+'''' 
And [''''+@BusinessProcessDim+''''_MemberId] = ''''+CAST(@BusinessprocessID as Char)+'''' 
And [''''+@TimeDim+''''_memberid] in (Select Time_MemberId from #Time)''''
+@Where
IF @IsRound = 1 set @sql = @sql + ''''
And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''')''''
Print(@Sql)
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


--===========================================================> DEPRECIATION

--UPDATE #FACT Set NumperOrig = b.Numper from #fact a,#Time b where a.time = b.Time

UPDATE #FACT SET Value = Value / DepMonths Where iscopy = 0 and Depmonths <> 0

--SET @Select = REPLACE(@AllDim,'''']'''',''''_Memberid]'''')
SET @Select = REPLACE(@AllDim_Memberid,''''['''',''''a.['''')
SET @Select = REPLACE(@Select,''''a.[''''+@TimeDim+''''_Memberid]'''',''''b.[Time_Memberid]'''')
--SET @Select = REPLACE(@Select,''''a.[''''+@AccountDim+''''_Memberid]'''',''''a.[DepAcct_Memberid]'''')

SET @Sql = ''''INSERT INTO [FACT_''''+@Modelname+''''_Default_Partition]
(''''+@Alldim_Memberid+'''',''''+@Modelname+''''_Value,USerid,ChangeDateTime)
SELECT ''''+@Alldim_Memberid+'''',Sum(''''+@ModelName+''''_Value) ,userId,ChangeDateTime
FROM (
SELECT ''''+@Select+'''',a.Value*-1 as ''''+@ModelName+''''_Value,''''''''''''+@User+'''''''''''' as userId,GETDATE() as ChangeDateTime
FROM #Fact a, #Time b 
Where 
a.Value <> 0
And b.NumPer <= a.DepMonths + a.Numper -1
And b.NumPer >= a.Numper
And a.IsCopy = 0
UNION ALL
SELECT ''''+@Alldim_Memberid+'''',Value*-1 as ''''+@ModelName+''''_Value,''''''''''''+@User+'''''''''''' as userId,GETDATE() as ChangeDateTime
FROM #Fact  
Where 
Value <> 0
And IsCopy = 1
) AS tmp
GROUP BY ''''+@Alldim_Memberid+'''',userId,ChangeDateTime ''''
Print (@Sql)
EXEC(@Sql)


Update #Fact Set DAccount_Memberid = A_Account_memberid Where MyText = ''''Admin''''
Update #Fact Set DAccount_Memberid = S_Account_memberid Where MyText = ''''Selling''''
Update #Fact Set DAccount_Memberid = C_Account_memberid Where MyText = ''''COGS''''

SET @Select = REPLACE(@Alldim_Main,''''['''',''''a.['''')
SET @Select = REPLACE(@Select,''''a.[''''+@TimeDim+''''_Memberid]'''',''''b.[Time_Memberid]'''')
SET @Select = REPLACE(@Select,''''a.[''''+@AccountDim+''''_Memberid]'''',''''a.[DAccount_Memberid]'''')


SET @Sql = ''''INSERT INTO [FACT_''''+REPLACE(@ModelName,''''_Detail'''','''''''')+''''_Default_Partition]
(''''+@Alldim_Main+'''',''''+REPLACE(@ModelName,''''_Detail'''','''''''')+''''_Value,USerid,ChangeDateTime)
SELECT ''''+@Select+'''',SUM(a.Value*-1),''''''''''''+@User+'''''''''''',GETDATE()
FROM #Fact a, #Time b 
Where 
a.Value <> 0
And b.NumPer <= a.DepMonths + a.Numper -1
And b.NumPer >= a.Numper
And a.IsCopy = 0
GROUP BY ''''+@Select
Print (@Sql)
EXEC(@Sql)

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END
-- Drop  table #time,#Account,#InvoiceNumber,#Factdata,#Invoice,#temp,#FactFinal,#temptime,#tempLabel,#delaccount,#fact,#Fact_Amount,#Fact_Month,#Fact_text



-- UPDATE #temp_parametervalues SET stringvalue = ''''Financials_detail'''' WHERE stringvalue = ''''Financials''''


/****** Object:  StoredProcedure [dbo].[Canvas_CashFlow_Calculation]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_CashFlow_Calculation'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_CashFlow_Calculation') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_CashFlow_Calculation]
@Period BIT =0
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN


--declare @Period BIT =0
--SET @Period = 0

-- select * into #temp_parametervalues from temp_parametervalues

	DECLARE @ScenarioID BIGINT
	,@BusinessprocessID BIGINT
	,@User Nvarchar(255)
	,@ModelName Nvarchar(50)

	DECLARE @DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max),@Lap INT,@Params Nvarchar(max),@Select Nvarchar(max)
	declare @Found int,@Alldim Nvarchar(Max),@Alldim_Memberid Nvarchar(Max),@Otherdim Nvarchar(Max),@Sep Nvarchar(2)
	Declare  @AccountDim Nvarchar(50),@ScenarioDim Nvarchar(50),@EntityDim Nvarchar(50),@BusinessProcessDim Nvarchar(50),@CurrencyDim Nvarchar(50)
	,@TimeDim Nvarchar(50),@LineItemDim nvarchar(50),@RoundDim nvarchar(50),@VersionDim nvarchar(50),@Where Nvarchar(max),@MaxPeriod INT

	declare @isRound Bit
	Set @isRound = 0

	Select @user = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''UserId''''
	Select @ModelName = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''Model'''' ' 

	
				SET @SQLStatement = @SQLStatement + '
	
	SET @Where = ''''''''
	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0

	SET @Lap = 1 
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''

		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Round''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
			set @IsRound = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Currency''''
		begin
			set @CurrencyDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''LineItem''''
		begin
			set @LineItemDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Version''''
		begin
			set @VersionDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
			set @Where = @Where + '''' AND a.[''''+@DimLabel+''''_Memberid] = b.[''''+@DimLabel+''''] ''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType

	end
	close Dim_cursor
	deallocate Dim_cursor ' 


			SET @SQLStatement = @SQLStatement + '



	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')

	Set @Alldim = @Alldim + '''',[TimeDataView] ''''
	SET @AllDim_Memberid = Replace(@Alldim,'''']'''',''''_Memberid]'''') 


--select @ScenarioID = Memberid From #Temp_ParameterValues Where parameterName = ''''ScenarioMbrs''''
	set @Params = ''''@ScenarioIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @ScenarioIDOUT=[MemberId] from [#Temp_ParameterValues] where [parameterName]=''''''''ScenarioMbrs''''''''''''
	exec sp_executesql @sql, @Params, @ScenarioIDOUT=@Scenarioid OUTPUT

--	Select @BusinessprocessID = Memberid From Ds_BusinessProcess Where Label = ''''BR_CAPEX''''
	set @Params = ''''@BusinessprocessIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''BR_CF''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessIDOUT=@BusinessprocessID OUTPUT

--==============================================> Debut Time

	Create table #Time 
	([Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Time_Memberid BIGINT
	,[year] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Period] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[PreviousTime] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,PreviousTime_Memberid BIGINT
	,[openingTime] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,OpeningTime_Memberid BIGINT)

	Create table #temp (Nb INT)
	Set @Sql = ''''INSERT INTo #temp Select Count(*) from DS_''''+@TimeDim+ '''' Where Left(Label,2) = ''''''''FY'''''''' and len (Label) = 6 ''''
	EXEC(@Sql)
	Declare @Count INT
	SELECT @Count = Nb from #temp ' 

	
				SET @SQLStatement = @SQLStatement + '
	


	IF @Count > 0
	BEGIN
--		SEt @PrevYear = REPLACE(@year,''''FY'''','''''''') - 1
		SET @Sql = ''''INSERT INTO #Time
		([Time],Time_Memberid,[year],Period)
		Select label,Memberid,TimeFiscalYear,TimeFiscalPeriod from DS_''''+@TimeDim+''''  
		Where Memberid in (Select Memberid from #Temp_parameterValues Where parametername = ''''''''TimeMbrs'''''''')
		Order by [Label] ''''
		EXEC(@Sql)

		SET @Sql = ''''Update #time Set PreviousTime = b.label,PreviousTime_Memberid = b.memberid From #time a, DS_''''+@TimeDim+'''' b
		Where 
		a.Period = ''''''''FP01''''''''
		And b.timefiscalperiod = ''''''''FP12''''''''
		And b.timefiscalyear <> ''''''''None''''''''
		And REPLACE(b.TimeFiscalYear,''''''''FY'''''''','''''''''''''''') = REPLACE(a.Year,''''''''FY'''''''','''''''''''''''') - 1 ''''
		EXEC(@Sql)

		Set @Sql = ''''Update #time Set PreviousTime = b.label,previousTime_memberid = b.Memberid From #time a, DS_''''+@TimeDim+'''' b
		Where 
		a.Period <> ''''''''FP01''''''''
		AND b.TimeFiscalPeriod <> ''''''''None''''''''
		And REPLACE(b.TimeFiscalPeriod,''''''''FP'''''''','''''''''''''''') = REPLACE(a.period,''''''''FP'''''''','''''''''''''''') - 1 
		And b.timefiscalyear <> ''''''''None''''''''
		And b.TimeFiscalYear = a.Year  ''''
		EXEC(@Sql)

		Set @sql = ''''Update #time Set OpeningTime = b.label,OpeningTime_memberid = b.Memberid From #time a, DS_''''+@TimeDim+'''' b
		Where 
		    b.timefiscalperiod = ''''''''FP12''''''''
		And b.timefiscalyear <> ''''''''None''''''''
		And REPLACE(b.TimeFiscalYear,''''''''FY'''''''','''''''''''''''') = REPLACE(a.Year,''''''''FY'''''''','''''''''''''''') - 1  ''''
		EXEC(@Sql)
	END ' 

	
				SET @SQLStatement = @SQLStatement + '
	
	ELSE
	BEGIN
		SET @Sql = ''''INSERT INTO #Time
		([Time],Time_Memberid,Year,period)
		Select label,Memberid,Timeyear,TimeMonth
		from DS_''''+@TimeDim+''''  
		Where Memberid in (Select Memberid from #Temp_parameterValues Where parametername = ''''''''TimeMbrs'''''''')
		Order by [Label] ''''
		EXEC(@Sql)

		Set @Sql = ''''Update #time Set PreviousTime = b.label,previoustime_memberid = b.Memberid From #time a, DS_''''+@TimeDim+'''' b
		Where 
		a.Period = ''''''''01''''''''
		And b.timeMonth = ''''''''12''''''''
		And b.timeyear <> ''''''''None''''''''
		And b.TimeYear = a.[Year] - 1 ''''
		EXEC(@Sql)

		Set @Sql = ''''Update #time Set Previoustime = b.label,previousTime_memberid = b.Memberid From #time a, DS_''''+@TimeDim+'''' b
		Where 
		a.Period <> ''''''''01''''''''
		AND b.TimeMonth <> ''''''''None''''''''
		And b.TimeMonth = a.period - 1 
		And b.timeyear <> ''''''''None''''''''
		And b.TimeYear = a.Year ''''
		EXEC(@Sql)

		SET @Sql = ''''Update #time Set OpeningTime = b.label,OpeningTime_memberid = b.Memberid From #time a, DS_''''+@TimeDim+'''' b
		Where 
		    b.timeMonth = ''''''''12''''''''
		And b.timeyear <> ''''''''None''''''''
		And b.TimeYear = a.[Year] - 1 ''''
		EXEC(@Sql)
	END ' 


			SET @SQLStatement = @SQLStatement + '


CREATE TABLE #Account (Account_Memberid BIGINT,Source_Account_Memberid BIGINT,[Sign] INT,Source_Amount_Recordid INT)
SET @Sql = ''''INSERT INTO #Account 
Select c.MemberId,b.Memberid,a.[Sign],a.Source_Amount_Recordid From LST_CashFlow_Setup a,[HC_''''+@AccountDim+''''] b,[DS_''''+@AccountDim+''''] c
Where a.Account_Memberid = b.Parentid 
and c.Label = a.CashFlow_Account''''
Print(@Sql)
EXEC(@Sql)

CREATE TABLE #Fact (Value Float)
SET @Sql = ''''ALTER TABLE #fact ADD '''' 
+REPLACE(@AllDim,'''']'''',''''_Memberid] BIGINT'''')+''''
,DestAccount_Memberid BIGINT
,[Sign] INT
,Source_Amount_Recordid INT''''
--Print(@Sql)
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '



SET @Select = REPLACE(@Alldim_Memberid,''''['''',''''a.['''')
SET @Select = REPLACE(@Select,''''a.[''''+@TimeDim+''''_Memberid]'''',''''c.[Time_Memberid]'''')

SET @Sql = ''''INSERT INTO #Fact
SELECT a.[''''+@ModelName+''''_Value], '''' + @Select + '''' 
	  ,b.Account_MemberId
	  ,b.[Sign]
	  ,b.Source_Amount_Recordid
FROM [FACT_''''+@ModelName+''''_Default_Partition] a, #Account b, #Time c
WHERE	a.''''+@ModelName+''''_Value <> 0 
		And b.Source_Amount_Recordid IN (1,2)
		And a.[''''+@AccountDim+''''_Memberid] = b.Source_Account_Memberid
		And a.[''''+@TimeDim+''''_Memberid] =  c.Time_Memberid	
		And a.[''''+@ScenarioDim+''''_Memberid] = ''''+CAST(@ScenarioID as char)+'''' 
		And a.[''''+@BusinessProcessDim+''''_MemberId] <> ''''+CAST(@BusinessprocessID as char)
IF @Period = 0 Set @Sql = @Sql + ''''
		And a.[''''+@BusinessProcessDim+''''_MemberId] Not in (Select Memberid From DS_''''+@BusinessProcessDim+'''' Where Label in (''''''''FP0'''''''',''''''''FP13'''''''',''''''''FP14'''''''',''''''''FP15''''''''))  ''''
IF @IsRound = 1 set @sql = @sql + ''''
		And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''')''''

Print(@Sql)
EXEC(@Sql)

SET @Sql = ''''INSERT INTO #Fact
SELECT a.[''''+@ModelName+''''_Value], '''' + @Select + '''' 
	  ,b.Account_MemberId
	  ,b.[Sign]
	  ,b.Source_Amount_Recordid * -1
FROM [FACT_''''+@ModelName+''''_Default_Partition] a, #Account b, #Time c
WHERE	a.''''+@ModelName+''''_Value <> 0
		And b.Source_Amount_Recordid IN (2,3)
		And a.[''''+@AccountDim+''''_Memberid] = b.Source_Account_Memberid
		And a.[''''+@TimeDim+''''_Memberid] =  c.PreviousTime_Memberid	
		And A.[''''+@ScenarioDim+''''_Memberid] = ''''+CAST(@ScenarioID as char)+'''' 
		And a.[''''+@BusinessProcessDim+''''_MemberId] <> ''''+CAST(@BusinessprocessID as char)
IF @Period = 0 Set @Sql = @Sql + ''''
		And a.[''''+@BusinessProcessDim+''''_MemberId] Not in (Select Memberid From DS_''''+@BusinessProcessDim+'''' Where Label in (''''''''FP0'''''''',''''''''FP13'''''''',''''''''FP14'''''''',''''''''FP15''''''''))  ''''
IF @IsRound = 1 set @sql = @sql + ''''
		And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''')''''

--Print(@Sql)
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


SET @Sql = ''''INSERT INTO #Fact
SELECT a.[''''+@ModelName+''''_Value], '''' + @Select + '''' 
	  ,b.Account_MemberId
	  ,b.[Sign]
	  ,b.Source_Amount_Recordid
FROM [FACT_''''+@ModelName+''''_Default_Partition] a, #Account b, #Time c
WHERE	a.''''+@ModelName+''''_Value <> 0
		And b.Source_Amount_Recordid = 4
		And a.[''''+@AccountDim+''''_Memberid] = b.Source_Account_Memberid
		And a.[''''+@TimeDim+''''_Memberid] =  c.OpeningTime_Memberid	
		And A.[''''+@ScenarioDim+''''_Memberid] = ''''+CAST(@ScenarioID as char)+'''' 
		And a.[''''+@BusinessProcessDim+''''_MemberId] <> ''''+CAST(@BusinessprocessID as char)
IF @Period = 0 Set @Sql = @Sql + ''''
		And a.[''''+@BusinessProcessDim+''''_MemberId] Not in (Select Memberid From DS_''''+@BusinessProcessDim+'''' Where Label in (''''''''FP0'''''''',''''''''FP13'''''''',''''''''FP14'''''''',''''''''FP15''''''''))  ''''
IF @IsRound = 1 set @sql = @sql + ''''
		And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''')''''
Print(@Sql)
EXEC(@Sql)

Update #Fact SET Value = Value * -1 Where Source_Amount_Recordid = -2

SET @Sql = ''''Update #Fact SET Value = Value * [Sign]
						, [''''+@AccountDim+''''_Memberid] = DestAccount_Memberid  
						, [''''+@BusinessProcessDim+''''_Memberid] = ''''+LTRIM(CAST(@BusinessprocessID as char))
EXEC(@Sql)

SET @Sql = ''''DELETE FROM FACT_''''+@ModelName+''''_default_partition 
WHERE [''''+@AccountDim+''''_Memberid] in (Select Account_Memberid from #Account)
AND [''''+@ScenarioDim+''''_memberid] = ''''+CAST(@ScenarioID as Char)+'''' 
And [''''+@BusinessProcessDim+''''_MemberId] = ''''+CAST(@BusinessprocessID as Char)+'''' 
And [''''+@TimeDim+''''_memberid] in (Select Time_MemberId from #Time)''''
IF @IsRound = 1 set @sql = @sql + ''''
And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''')''''
--Print(@Sql)
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''INSERT INTO [FACT_''''+@ModelName+''''_Default_Partition]
	(''''+@Alldim_Memberid+'''',''''+@Modelname+''''_Value,USerid,ChangeDateTime)
	SELECT ''''+@Alldim_Memberid+''''
		  ,SUM(Value)
		  ,''''''''''''+@USer+''''''''''''
		  ,GETDATE()
	FROM #Fact 
	Group by ''''+@Alldim_Memberid
	Print(@Sql)
	EXEC(@Sql)
END '

IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

-- Drop table #time,#temp,#account,#fact






/****** Object:  StoredProcedure [dbo].[Canvas_Copy_CYNI]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Copy_CYNI'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Copy_CYNI') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
 PROCEDURE  [dbo].[Canvas_Copy_CYNI]
@BP_Conv bit = 0 
,@InitDim1  Nvarchar(100) = '''''''' 
,@InitDim2  Nvarchar(100) = '''''''' 
,@InitDim3  Nvarchar(100) = '''''''' 
,@InitDim4  Nvarchar(100) = '''''''' 
,@InitDim5  Nvarchar(100) = '''''''' 
,@InitDim6  Nvarchar(100) = '''''''' 
,@InitDim7  Nvarchar(100) = '''''''' 
,@InitDim8  Nvarchar(100) = '''''''' 
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS


--Declare @BP_Conv  bit, @InitDim1 nvarchar(4000) , @InitDim2 nvarchar(4000) , @InitDim3 nvarchar(4000) , @InitDim4 nvarchar(4000) , @InitDim5 nvarchar(4000) , @InitDim6 nvarchar(4000) 
--, @InitDim7 nvarchar(4000) , @InitDim8 nvarchar(4000) set @bp_conv = 0
--SET @InitDim1 = ''''Intercompany''''
--SET @InitDim2 = ''''''''
--SET @InitDim3 = ''''''''
--SET @InitDim4 = ''''''''
--SET @InitDim4 = ''''''''
--SET @InitDim5 = ''''''''
--SET @InitDim6 = ''''''''
--Set @InitDim7 = ''''''''
--Set @InitDim8 = ''''''''
--Set @BP_Conv = ''''0''''


-- Drop table #temp_parameterValues
-- select * into #temp_parameterValues from temp_parameterValues

If @BP_Conv <> 0 Select * into #Temp_ParameterValues From Wrk_ETL_Values Where Proc_Name = ''''Canvas_Copy_CYNI''''

BEGIN


	DECLARE @modelName nvarchar(100), @userName Nvarchar(100)
	DECLARE @DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max),@Lap INT
	declare @Found int,@Alldim Nvarchar(Max),@AlldimSQL Nvarchar(Max),@Sep Nvarchar(2)
	Declare  @AccountDim Nvarchar(50),@ScenarioDim Nvarchar(50),@EntityDim Nvarchar(50),@BusinessProcessDim Nvarchar(50),@CurrencyDim Nvarchar(50)
	,@TimeDim Nvarchar(50),@LineItemDim nvarchar(50),@RoundDim nvarchar(50),@VersionDim nvarchar(50),@Where Nvarchar(max),@Alldim2 Nvarchar(Max),@AlldimSelect Nvarchar(Max)

	Declare @IsRound bit
	SET @IsRound = 0

	Select @UserName = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''
	Select @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''

	SET @Where = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0
	SET @Lap = 1 
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname+''''''''   ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''
		If @DimLabel = ''''LineItem'''' SET @DimType = ''''LineItem''''
		If @DimLabel = ''''Version'''' SET @DimType = ''''Version''''
		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Round''''
		begin
			set @RoundDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
			set @IsRound = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Currency''''
		begin
			set @CurrencyDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''LineItem''''
		begin
			set @LineItemDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Version''''
		begin
			set @VersionDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @AllDim = @AllDim +@Sep + RTRIM(@DimLabel)+'''']''''
--			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
--			set @Where = @Where + '''' AND a.[''''+@DimLabel+''''_Memberid] = b.[''''+@DimLabel+''''] ''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType

	end
	close Dim_cursor
	deallocate Dim_cursor ' 


			SET @SQLStatement = @SQLStatement + '
 


/****** Script for SelectTopNRows command from SSMS  ******/
DECLARE @ScenarioID BIGINT
,@TimeID BIGINT
,@BusinessprocessID BIGINT
,@Time  Nvarchar(255)
,@MinTime  Nvarchar(255)
,@MaxOffset  INT


DECLARE @BPConvProperty Smallint
SET @BPConvProperty = 0 ' 


			SET @SQLStatement = @SQLStatement + '


Create table #temp (Name nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
Insert into #temp select Dimension From ModelDimensions 
where model = @ModelName and Dimension = ''''BusinessRule''''
IF @@ROWCOUNT = 1 
BEGIN
	SET @BPConvProperty = 2
END
ELSE
BEGIN
	Truncate table  #temp
	Set @sql = ''''Insert into #temp select b.name 
	From sysobjects a,syscolumns b 
	where a.id = b.id and a.name = ''''''''DS_''''+@BusinessProcessDim+''''''''''''
	And b.Name = ''''''''BP_Converted''''''''''''
	EXEC(@Sql)
IF @@ROWCOUNT = 1 SET @BPConvProperty = 1
END

Create table #TimeCYNI (
Time_memberid BIGINT
,[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
,SourceTime_Memberid BIGINT
,[SourceTime] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS) ' 


			SET @SQLStatement = @SQLStatement + '



--Create table #TimeFinal (NumPer INT,[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,TimeOrigin_Memberid BIGINT,Time_Memberid BIGINT,TimeOffset INT)
--Create table #TimeFinalPercent (NumPer INT,[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,TimeOrigin_Memberid BIGINT,Time_Memberid BIGINT,TimeOffset INT)

SET @Sql = ''''INSERT INTO #TimeCYNI 
Select a.Memberid, b.label,c.memberid,c.label
From #temp_parametervalues a, DS_''''+@TimeDim+'''' b, DS_''''+@TimeDim+'''' c
Where
b.TimeFiscalperiod in (''''''''FP01'''''''',''''''''FP02'''''''',''''''''FP03'''''''',''''''''FP04'''''''',''''''''FP05'''''''',''''''''FP06'''''''',''''''''FP07'''''''',''''''''FP08'''''''',''''''''FP09'''''''',''''''''FP10'''''''',''''''''FP11'''''''',''''''''FP12'''''''')
and c.TimeFiscalPeriod in (''''''''FP01'''''''',''''''''FP02'''''''',''''''''FP03'''''''',''''''''FP04'''''''',''''''''FP05'''''''',''''''''FP06'''''''',''''''''FP07'''''''',''''''''FP08'''''''',''''''''FP09'''''''',''''''''FP10'''''''',''''''''FP11'''''''',''''''''FP12'''''''')
AND a.memberid = b.memberid and a.Parametername = ''''''''TimeMbrs''''''''
and b.TimeFiscalperiod >= c.TimeFiscalperiod
And b.TimeFiscalyear = c.TimeFiscalyear
order by 2 ''''
Exec(@Sql)

CREATE TABLE [#AccountCYNI]
(
	[Account_MemberId] [bigint] NULL
	,[SourceAccount_memberId] [bigint] NULL
) ON [PRIMARY]

--prof_Dist (pl) = 353
--3201  (BS)    = 131

Set @Sql = ''''Insert into #AccountCYNI 
Select a.memberid, b.Memberid
From HC_''''+@AccountDim+'''' b, DS_''''+@AccountDim+'''' a, DS_''''+@AccountDim+'''' c 
where 
a.keyname_Account = ''''''''NetIncomeBS''''''''
AND b.parentid = c.memberid
AND c.Keyname_account = ''''''''NetIncome'''''''' ''''
Exec(@Sql)

Create table #FactCYNI ([Value] [float]  NULL)

Set @Sql = ''''ALTER TABLE #FactCYNI ADD ''''+REPLACE(@AllDim,'''']'''',''''_Memberid] BIGINT'''')
Print(@Sql)
Exec(@Sql)

SET @Alldim2 = REPLACE(@AllDim,'''']'''',''''_Memberid]'''')
SET @AlldimSQL = REPLACE(@AllDim2,''''['''',''''a.['''')
SET @AlldimSQL = REPLACE(@AllDimSQL,''''a.[''''+@AccountDim+''''_memberid]'''',''''b.[Account_memberid]'''')
SET @AlldimSQL = REPLACE(@AllDimSQL,''''a.[''''+@TimeDim+''''_memberid]'''',''''c.[Time_memberid]'''')
SET @AllDimSelect =  @AllDimSQL
IF @InitDim1 <> '''''''' SET @AlldimSQL = REPLACE(@AllDIMSQL,''''a.[''''+@InitDim1+''''_Memberid]'''',''''-1 AS [''''+@InitDim1+''''_Memberid]'''')
IF @InitDim2 <> '''''''' SET @AlldimSQL = REPLACE(@AllDIMSQL,''''a.[''''+@InitDim2+''''_Memberid]'''',''''-1 AS [''''+@InitDim2+''''_Memberid]'''')
IF @InitDim3 <> '''''''' SET @AlldimSQL = REPLACE(@AllDIMSQL,''''a.[''''+@InitDim3+''''_Memberid]'''',''''-1 AS [''''+@InitDim3+''''_Memberid]'''')
IF @InitDim4 <> '''''''' SET @AlldimSQL = REPLACE(@AllDIMSQL,''''a.[''''+@InitDim4+''''_Memberid]'''',''''-1 AS [''''+@InitDim4+''''_Memberid]'''')
IF @InitDim5 <> '''''''' SET @AlldimSQL = REPLACE(@AllDIMSQL,''''a.[''''+@InitDim5+''''_Memberid]'''',''''-1 AS [''''+@InitDim5+''''_Memberid]'''')
IF @InitDim6 <> '''''''' SET @AlldimSQL = REPLACE(@AllDIMSQL,''''a.[''''+@InitDim6+''''_Memberid]'''',''''-1 AS [''''+@InitDim6+''''_Memberid]'''')
IF @InitDim7 <> '''''''' SET @AlldimSQL = REPLACE(@AllDIMSQL,''''a.[''''+@InitDim7+''''_Memberid]'''',''''-1 AS [''''+@InitDim7+''''_Memberid]'''')
IF @InitDim8 <> '''''''' SET @AlldimSQL = REPLACE(@AllDIMSQL,''''a.[''''+@InitDim8+''''_Memberid]'''',''''-1 AS [''''+@InitDim8+''''_Memberid]'''') ' 


			SET @SQLStatement = @SQLStatement + '



SET @Sql = ''''INSERT INTO #FactCYNI
 SELECT 
	 Sum(a.[''''+@modelName+''''_Value]),''''
	+@AlldimSQL+'''' 
 FROM [Fact_''''+@modelName+''''_Default_Partition] a, #AccountCYNI b, #TimeCYNI c	
 WHERE	
	a.''''+@ModelName+''''_Value <> 0
	And a.''''+@AccountDim+''''_Memberid = b.SourceAccount_memberId
	And a.''''+@TimeDim+''''_Memberid =  c.SourceTime_Memberid
	And a.''''+@ScenarioDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
	And a.''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''') '''' 
	IF @BP_Conv = 1 
	BEGIN
		IF @BPConvProperty = 1 Set @Sql = @Sql + '''' And ''''+@businessprocessDim+''''_memberid in (Select BP_Converted_Memberid From DS_''''+@BusinessProcessDim+'''' Where BP_Converted_Memberid > 0) ''''
		IF @BPConvProperty = 2 Set @Sql = @Sql + '''' And BusinessRule_memberid in (Select Memberid From DS_BusinessRule Where Label = ''''''''Conversion'''''''') ''''
	END
IF @IsRound = 1 set @sql = @sql + ''''
	And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''')''''
	Set @Sql = @Sql + ''''
	Group by '''' + @AlldimSelect
	print(@Sql)
	Exec(@Sql)

		IF @BP_Conv = 1 
		BEGIN
			Declare @TRANSLATION Bigint
			Select @TRANSLATION = memberid From Ds_Account Where label = ''''TRANSLATION''''
			--Select @TRANSLATION = memberid From Ds_Account Where label = ''''NONE''''
 
		SET @Alldim2 = REPLACE(@AllDim,'''']'''',''''_Memberid]'''')
		SET @Alldim2 = REPLACE(@AllDim2,''''['''',''''a.['''')
		SET @Alldim2 = REPLACE(@AllDim2,''''[''''+@AccountDim+''''_Memberid]'''',+RTRIm(LTRIm(CAST(@Translation as char))) +'''' As Account_memberid'''')

 		Set @AllDimSQL = Replace(@Alldim2,LTRIM(RTRIM(CAST(@Translation as Char))) +'''' As Account_memberid'''','''''''')
		Set @AllDimSQL = Replace(@AllDimSQL,'''',,'''','''','''')
		IF Left(@AllDimSQL,1) = '''','''' SET @AlldimSQL = Substring(@AlldimSQL,2,2000)

 		SET @Sql = ''''INSERT INTO #FactCYNI
		SELECT 
		,Sum(a.[Value]*-1),''''
		+@Alldim2+'''' 
		FROM  #FACTCYNI a
			Group by ''''+@alldimSql
		print(@Sql)
		Exec(@Sql)
		END ' 


			SET @SQLStatement = @SQLStatement + '


--	IF @BP_Conv = 1 INSERT INTO #AccountCYNI VALUES(@TRANSLATION,@TRANSLATION)	

	SET @Sql = ''''DELETE FROM FACT_''''+@ModelName+''''_default_partition 
	WHERE
		Account_memberid in (Select Distinct Account_memberid from #AccountCYNI)
		And Scenario_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
		And Entity_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')
		And Time_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''') ''''
		IF @BP_Conv = 1 
		BEGIN
			IF @BPConvProperty = 1 Set @Sql = @Sql + '''' And ''''+@businessprocessDim+''''_memberid in (Select BP_Converted_Memberid From DS_''''+@BusinessProcessDim+'''' Where BP_Converted_Memberid > 0) ''''
			IF @BPConvProperty = 2 Set @Sql = @Sql + '''' And BusinessRule_memberid in (Select Memberid From DS_BusinessRule Where Label = ''''''''Conversion'''''''') ''''
		END
	IF @IsRound = 1 set @sql = @sql + ''''
	And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''')''''
	print @sql
	Exec(@Sql)

	Set @Sql = ''''
	INSERT INTO [FACT_''''+@ModelName+''''_Default_Partition]
	(''''+REPLACE(@AllDim,'''']'''',''''_Memberid]'''')+''''
		,[ChangeDatetime]
		,[Userid]
		,[''''+@Modelname+''''_Value])
	SELECT ''''+REPLACE(@AllDim,'''']'''',''''_Memberid]'''')+''''
	,Getdate() as [ChangeDatetime]
	,''''''''''''+@UserName+'''''''''''' as [Userid]
	,[Value]
	FROM #FactCYNI '''' 
	Print(@Sql)
	Exec(@Sql)
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END


----   Drop table #max,#AccountCYNI,#FactCYNI,#TimeCYNI,#Min,#offsetAccount,#offsetPercent,#TimeFinal,#TimeFinalPercent,#FactPercent,#FactAmount,#AccountPercent,#Businessprocess,#temp
-- Drop table #temp_parametervalues
--  delete from FACT_Financials_Detail_default_partition where  Time_MemberId not in (select memberid from DS_Time)
		

/****** Object:  StoredProcedure [dbo].[Canvas_Copy_Journal]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Capex_BR'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Copy_Voucher') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
 PROCEDURE  [dbo].[Canvas_Copy_Journal]
@dim1 Nvarchar(255) =''''Cost_Center''''
,@dim2 Nvarchar(255) =''''''''
,@dim3 Nvarchar(255) =''''''''
,@dim4 Nvarchar(255) =''''''''
,@dim5 Nvarchar(255) =''''''''

' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS


Select * into JNL_Values from #temp_parametervalues 

return

--DECLARE @dim1 Nvarchar(255),@dim2 Nvarchar(255),@dim3 Nvarchar(255),@dim4 Nvarchar(255),@dim5 Nvarchar(255) 
--Set @Dim1=''''Cost_center''''
--Set @Dim2=''''''''
--Set @Dim3=''''''''
--Set @Dim4=''''''''
--Set @Dim5=''''''''
 -- Select * into #temp_parametervalues from temp_parametervalues

BEGIN

	DECLARE @ScenarioID BIGINT
	,@TimeID BIGINT
	,@BusinessprocessID BIGINT
	,@Time  Nvarchar(255)
	,@MinTime  Nvarchar(255)
	,@MaxOffset  INT
	,@User Nvarchar(255)
	,@ModelName Nvarchar(50)
	,@Lap INT
	,@NBDim INT

	Select @user = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''UserId''''
	Select @ModelName = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''Model''''

	Declare  @AccountDim nvarchar(100)
	,@ScenarioDim nvarchar(100)
	, @EntityDim nvarchar(100)
	,@BusinessprocessDim nvarchar(100)
	,@CurrencyDim nvarchar(100)
	,@TimeDim nvarchar(100)
	,@LineItemDim nvarchar(100)
	,@VersionDim nvarchar(100)
	,@DimType nvarchar(100)
	,@Dimlabel nvarchar(100)
	,@Sql nvarchar(max)
	,@SelectDim nvarchar(max)
	,@SelectDimAS nvarchar(max)


	create table #dimModel (Dimension nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS,Dimtype nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS)
	
	INsert into #dimModel select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname+'''''''' And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]

	Declare Dim_cursor cursor for select [Dimension],[DimType] from #DimModel ORDER BY [Dimtype]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		if @DimType = ''''Account'''' set @AccountDim = RTRIM(@DimLabel)
		if @DimType = ''''Scenario'''' Set @ScenarioDim = RTRIM(@DimLabel)
		if @DimType = ''''Entity'''' set @EntityDim = RTRIM(@DimLabel)
		if @DimType = ''''BusinessProcess'''' Set @BusinessprocessDim = RTRIM(@DimLabel)
		if @DimType = ''''Currency'''' set @CurrencyDim = RTRIM(@DimLabel)
		if @DimType = ''''Time'''' set @TimeDim = RTRIM(@DimLabel)
	fetch next from Dim_cursor into @DimLabel,@DimType
	end
	close Dim_cursor
	deallocate Dim_cursor ' 


			SET @SQLStatement = @SQLStatement + '
 
	
	Create table #Year (year_label nvarchar(6) COLLATE SQL_Latin1_General_CP1_CI_AS)
	Create table #TimeTemp (memberid BIGINT, label nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

	SET @Sql = ''''INSERT INTO #year
	Select TimeFiscalyear 
	From #temp_parametervalues a, [DS_''''+@TimeDim+''''] b
	Where
	a.memberid = b.memberid and a.Parametername = ''''''''TimeMbrs'''''''' ''''
	Print(@Sql)
	EXEC(@Sql)

	Set @Sql = ''''INSERT INTO #TimeTemp
	Select b.memberid,b.label
	From #year a, [DS_''''+@TimeDim+''''] b
	Where
	b.TimeFiscalYear = a.Year_label
	AND b.TimeFiscalPeriod in (''''''''FP01'''''''',''''''''FP02'''''''',''''''''FP03'''''''',''''''''FP04'''''''',''''''''FP05'''''''',''''''''FP06'''''''',''''''''FP07'''''''',''''''''FP08'''''''',''''''''FP09'''''''',''''''''FP10'''''''',''''''''FP11'''''''',''''''''FP12'''''''') ''''
	Print(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '
 

	Create table #Time (
	Time_memberid BIGINT
	,[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,SourceTime_Memberid BIGINT
	,[SourceTime] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

	SET @Sql = ''''INSERT INTO #Time 
	Select a.Memberid, b.label,c.memberid,c.label
	From #Timetemp a, [DS_''''+@TimeDim+''''] b, [DS_''''+@TimeDim+''''] c
	Where
	b.TimeFiscalPeriod in (''''''''FP01'''''''',''''''''FP02'''''''',''''''''FP03'''''''',''''''''FP04'''''''',''''''''FP05'''''''',''''''''FP06'''''''',''''''''FP07'''''''',''''''''FP08'''''''',''''''''FP09'''''''',''''''''FP10'''''''',''''''''FP11'''''''',''''''''FP12'''''''')
	and c.TimeFiscalPeriod in (''''''''FP01'''''''',''''''''FP02'''''''',''''''''FP03'''''''',''''''''FP04'''''''',''''''''FP05'''''''',''''''''FP06'''''''',''''''''FP07'''''''',''''''''FP08'''''''',''''''''FP09'''''''',''''''''FP10'''''''',''''''''FP11'''''''',''''''''FP12'''''''')
	AND a.memberid = b.memberid
	and b.TimeFiscalPeriod >= c.TimeFiscalPeriod
	And b.TimeFiscalyear = c.TimeFiscalyear
	order by 2 ''''
	EXEC(@Sql)


	Create Table #Businessprocess (businessprocess_memberid BIGINT)
	Insert into #Businessprocess
	Select memberid from ds_businessprocess Where manual = 1 
	--And memberid not in (Select BP_converted_memberid from ds_businessprocess)

	CREATE TABLE #vouchers (
	[Voucher_MemberId] BIGINT
	,[Scenario_MemberId] BIGINT
	,[Time_MemberId] BIGINT
	,[Entity_MemberId] BIGINT
	,[Active] INT
	,[Cumulative] INT
	)
	
	SET @Sql = ''''INSERT INTO #Vouchers
	SELECT [Voucher_MemberId],[Scenario_MemberId],[Time_MemberId],[Entity_MemberId],Sum([Active]) as Active,Sum([Cumulative]) As Cumulative
	FROM (
	Select a.[Voucher_MemberId],a.[''''+@ScenarioDim+''''_MemberId],a.[''''+@TimeDim+''''_MemberId],a.[''''+@EntityDim+''''_MemberId]
	,CASE WHEN Vouchers_Text = ''''''''Yes'''''''' THEN 1 ELSE 0 END as Active
	,0 As Cumulative
	FROM  FACT_Vouchers_Text a
	WHERE	a.Vouchers_text <> ''''''''''''''''
			And a.Lineitem_memberid in (select memberid from DS_LineItem where label = ''''''''Active'''''''')
			And a.''''+@TimeDim+''''_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
			And a.''''+@ScenarioDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
			And a.''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')
	UNION ALL
	Select a.[Voucher_MemberId],a.[''''+@ScenarioDim+''''_MemberId],a.[''''+@TimeDim+''''_MemberId],a.[''''+@EntityDim+''''_MemberId]
	,0 As Active
	,CASE WHEN Vouchers_Text = ''''''''Yes'''''''' THEN 1 ELSE 0 END as Cumulative
	FROM  FACT_Vouchers_Text a
	WHERE	a.Vouchers_text <> ''''''''''''''''
			And a.Lineitem_memberid in (select memberid from DS_LineItem where label = ''''''''Cumulative'''''''')
			And a.''''+@TimeDim+''''_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
			And a.''''+@Scenariodim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
			And a.''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')
	) As tmp
	Group By [Voucher_MemberId],[''''+@ScenarioDim+''''_MemberId],[''''+@TimeDim+''''_MemberId],[''''+@EntityDim+''''_MemberId]''''
	Print(@Sql)
	Exec(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '
 

	CREATE TABLE #vouchersHeader ([Voucher_MemberId] BIGINT,[Scenario_MemberId] BIGINT,[Time_MemberId] BIGINT,[Entity_MemberId] BIGINT
	,[BusinessProcess_Memberid] BIGINT,[Currency_Memberid] BIGINT)

	SET @Sql = ''''INSERT INTO #VouchersHeader
	SELECT [Voucher_MemberId] ,[Scenario_MemberId] ,[Time_MemberId] ,[Entity_MemberId]
	,SUM([BusinessProcess_Memberid] ) as [BusinessProcess_Memberid] 
	,SUM([Currency_Memberid] ) as [Currency_Memberid] 
	FROM (
	Select 
	a.[Voucher_MemberId]
	,a.[''''+@ScenarioDim+''''_MemberId]
	,a.[''''+@TimeDim+''''_MemberId]
	,a.[''''+@EntityDim+''''_MemberId]
	,b.memberid as [Businessprocess_MemberId]
	,0 as [Currency_MemberId]
	FROM  FACT_Vouchers_Text a, DS_''''+@BusinessprocessDim+'''' b
	WHERE	a.Vouchers_text <> ''''''''''''''''
			And a.Lineitem_memberid in (select memberid from DS_LineItem where label = ''''''''BP'''''''')
			And a.Vouchers_Text = b.Label
			And a.''''+@TimeDim+''''_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
			And a.''''+@ScenarioDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
			And a.''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')
	UNION ALL
	Select 
	a.[Voucher_MemberId],a.[''''+@ScenarioDim+''''_MemberId],a.[''''+@TimeDim+''''_MemberId],a.[''''+@EntityDim+''''_MemberId]
	,0 as [Businessprocess_MemberId]
	,b.memberid as [Currency_MemberId]
	FROM  FACT_Vouchers_Text a, DS_''''+@CurrencyDim+'''' b
	WHERE	a.Vouchers_text <> ''''''''''''''''
			And a.Lineitem_memberid in (select memberid from DS_LineItem where label = ''''''''CUR'''''''')
			And a.Vouchers_Text = b.Label
			And a.''''+@TimeDim+''''_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
			And a.''''+@ScenarioDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
			And a.''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')
	)
	AS TMP
	GROUP BY 
	[Voucher_MemberId] ,[Scenario_MemberId] ,[Time_MemberId] ,[Entity_MemberId]''''
	Exec(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '
 

--=============================================>
	CREATE TABLE #vouchersDetail (
	 [Voucher_MemberId] BIGINT
	,[Scenario_MemberId] BIGINT
	,[Time_MemberId] BIGINT
	,[Entity_MemberId] BIGINT
	,[LineItem_Memberid] BIGINT
	,[Account_Memberid] BIGINT
	)


	If @Dim1 <> '''''''' 
	BEGIN
		Set @Sql = @Sql + ''''ALTER TABLE #vouchersDetail ADD [''''+@Dim1+''''_Memberid] BIGINT''''
		If @Dim2 <> '''''''' Set @Sql = @Sql + '''',[''''+@Dim2+''''_Memberid] BIGINT''''
		If @Dim3 <> '''''''' Set @Sql = @Sql + '''',[''''+@Dim3+''''_Memberid] BIGINT''''
		If @Dim4 <> '''''''' Set @Sql = @Sql + '''',[''''+@Dim4+''''_Memberid] BIGINT''''
		If @Dim5 <> '''''''' Set @Sql = @Sql + '''',[''''+@Dim5+''''_Memberid] BIGINT''''
		Exec(@Sql)
	END
	Set @Sql =  ''''ALTER TABLE #vouchersDetail ADD 
	 [Sign] INT
	,[Debitcredit] INT
	,[Active] INT
	,[Cumulative] INT 
	,[BusinessProcess_Memberid] BIGINT 
	,[Currency_Memberid] BIGINT ''''
	Exec(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '
 

	Set @SelectDim = ''''''''
	Set @SelectDimAS = ''''''''
	Set @NBDim = 0
	If @Dim1 <> '''''''' 
	BEGIN
		Set @NBDim = 1
		Set @SelectDim = ''''[''''+@Dim1+''''_memberid]''''
		Set @SelectDimAS = '''',SUM([''''+@Dim1+''''_Memberid]) as [''''+@Dim1+''''_Memberid]''''
		If @Dim2 <> '''''''' 
		BEGIn
			Set @NBDim = 2
			Set @SelectDim = @SelectDim + '''',[''''+@Dim2+''''_memberid]''''
			Set @SelectDimAS = @SelectDimAS + '''',SUM([''''+@Dim2+''''_Memberid]) as [''''+@Dim2+''''_Memberid]''''
			If @Dim3 <> '''''''' 
			BEGIN
				Set @NBDim = 3
				Set @SelectDim = @SelectDim + '''',[''''+@Dim3+''''_memberid]''''
				Set @SelectDimAS = @SelectDimAS + '''',SUM([''''+@Dim3+''''_Memberid]) as [''''+@Dim3+''''_Memberid]''''
				If @Dim4 <> '''''''' 
				BEGIN
					Set @NBDim = 4
					Set @SelectDim = @SelectDim + '''',[''''+@Dim4+''''_memberid]''''
					Set @SelectDimAS = @SelectDimAS + '''',SUM([''''+@Dim4+''''_Memberid]) as [''''+@Dim4+''''_Memberid]''''
					If @Dim5 <> '''''''' 
					BEGIn
						Set @NBDim = 5
						Set @SelectDim = @SelectDim + '''',[''''+@Dim5+''''_memberid]''''
						Set @SelectDimAS = @SelectDimAS + '''',SUM([''''+@Dim5+''''_Memberid]) as [''''+@Dim5+''''_Memberid]''''
					END
				END
			END
		END
	END ' 


			SET @SQLStatement = @SQLStatement + '
 

	Set @Sql = ''''INSERT INTO #VouchersDetail
	SELECT 
	[Voucher_MemberId] 
	,[Scenario_MemberId] 
	,[Time_MemberId] 
	,[Entity_MemberId]
	,[LineItem_MemberId] 
	,SUM([Account_Memberid] ) as [Account_Memberid] ''''
	+@SelectdimAS+''''
	,SUM([Sign]) as [Sign]
	,SUM([DebitCredit]) as DebitCredit 
	,[Active] = 0
	,[Cumulative] = 0 
	,[BusinessProcess_Memberid]  = 0
	,[Currency_Memberid] = 0 
	FROM (
	Select 
	 a.[Voucher_MemberId]
	,a.[''''+@ScenarioDim+''''_MemberId]
	,a.[''''+@TimeDim+''''_MemberId]
	,a.[''''+@EntityDim+''''_MemberId]
	,a.[LineItem_MemberId]
	,b.memberid as [Account_MemberId] 
	,''''+REPLACE(@SelectDim,''''['''',''''0 AS ['''') +''''
	,0 as [DebitCredit]
	,b.[sign] 
	FROM  FACT_Vouchers_Text a, DS_Account b
	WHERE	a.Vouchers_text <> ''''''''''''''''
			And a.businessprocess_memberid in (select memberid from DS_Businessprocess where label = ''''''''BP_Account'''''''')
			And a.Vouchers_Text = b.Label
			And a.Time_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
			And a.Scenario_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
			And a.Entity_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')
	UNION ALL
	Select 
	a.[Voucher_MemberId]
	,a.[Scenario_MemberId]
	,a.[Time_MemberId]
	,a.[Entity_MemberId]
	,a.[LineItem_MemberId]
	,0 as [Account_MemberId] 
	,''''+REPLACE(@SelectDim,''''['''',''''0 AS ['''') +''''
	,CASE WHEN Vouchers_Text = ''''''''Debit'''''''' THEN 1 ELSE -1 END as DebitCredit
	,0 as [Sign]
	FROM  FACT_Vouchers_Text a
	WHERE	a.Vouchers_text <> ''''''''''''''''
			And a.businessprocess_memberid in (select memberid from DS_Businessprocess where label = ''''''''BP_DEBITCREDIT'''''''')
			And a.Time_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
			And a.Scenario_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
			And a.Entity_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''') ''''

	Set @lap = 0 ' 


			SET @SQLStatement = @SQLStatement + '
 
	DECLARE @MyDim Nvarchar(100)
	While @Lap <= @NBDim
	BEGIN 
		SET @Lap = @Lap+1
		IF @lap = 1 SET @Mydim = @Dim1
		IF @lap = 2 SET @Mydim = @Dim2
		IF @lap = 3 SET @Mydim = @Dim3
		IF @lap = 4 SET @Mydim = @Dim4
		IF @lap = 5 SET @Mydim = @Dim5

		SET @Sql = @Sql + ''''
		UNION ALL
		Select 
		a.[Voucher_MemberId]
		,a.[Scenario_MemberId]
		,a.[Time_MemberId]
		,a.[Entity_MemberId]
		,a.[LineItem_MemberId]
		,0 as [Account_MemberId] 
		,''''+REPLACE(@SelectDim,''''[''''+@MyDim+''''_Memberid]'''',''''b.memberid AS [''''+@MyDim+''''_Memberid]'''') +''''
		,0 as [DebitCredit]
		,0 as [Sign]
		FROM  FACT_Vouchers_Text a, DS_''''+@MyDim+'''' b
		WHERE	a.Vouchers_text <> ''''''''''''''''
				And a.businessprocess_memberid in (select memberid from DS_Businessprocess where label = ''''''''BP_''''+@MyDim+'''''''''''')
				And a.Vouchers_Text = b.Label
				And a.Time_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
				And a.Scenario_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
				And a.Entity_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''') ''''
		SET @Lap = @lap + 1
	END
	
	Set @sql = @Sql + ''''
	)
	AS TMP
	GROUP BY [Voucher_MemberId] ,[Scenario_MemberId] ,[Time_MemberId] ,[Entity_MemberId] ,[LineItem_MemberId] ''''
	Print(@Sql)
	Exec(@Sql)


	UPDATE #vouchersDetail
	SET [Active] = b.[Active], [Cumulative]=b.[Cumulative]
	FROM #vouchersDetail a, #vouchers b
	WHERE 
	a.[Voucher_MemberId] =b.[Voucher_MemberId] 
	AND a.[Scenario_MemberId] =b.[Scenario_MemberId] 
	AND a.[Time_MemberId] =b.[Time_MemberId] 
	AND a.[Entity_MemberId] =b.[Entity_MemberId]  ' 


			SET @SQLStatement = @SQLStatement + '
 
	
	UPDATE #vouchersDetail
	SET [BusinessProcess_Memberid] = b.[BusinessProcess_Memberid], [Currency_Memberid]=b.[Currency_Memberid]
	FROM #vouchersDetail a, #vouchersheader b
	WHERE 
	a.[Voucher_MemberId] =b.[Voucher_MemberId] 
	AND a.[Scenario_MemberId] =b.[Scenario_MemberId] 
	AND a.[Time_MemberId] =b.[Time_MemberId] 
	AND a.[Entity_MemberId] =b.[Entity_MemberId] 

	Create table #Fact
	(
	 [Account_MemberId] [bigint]  
	,[BusinessProcess_MemberId] [bigint]  
	,[Currency_MemberId] [bigint] 
	,[Entity_MemberId] [bigint] 
	,[Scenario_MemberId] [bigint] 
	,[Time_MemberId] [bigint] 
	,[TimeDataView_MemberId] [bigint] 
	,[Financials_Value] [float]  NULL)

	IF @NBDim > 0 
	BEGIN
		SET @Sql = ''''ALTER TABLE #Fact add ''''+REPLACE(@SelectDim,'''']'''',''''] BIGINT'''')
		EXEC(@Sql)
	END
	ALTER TABLE #fact ADD [Voucher_MemberId] Bigint,[LineItem_MemberId] Bigint

	SET @sql = ''''INSERT INTO #Fact
	SELECT 
	 v.[Account_MemberId]
	,v.[BusinessProcess_MemberId]
	,v.[Currency_MemberId]
	,a.[''''+@EntityDim+''''_MemberId]
	,a.[''''+@ScenarioDim+''''_MemberId]
	,a.[''''+@TimeDim+''''_MemberId]
	,a.[TimeDataView_MemberId]
	,a.[Vouchers_Value] * v.Debitcredit * v.[Sign] ''''

	IF @NBDim > 0  Set @Sql = @sql + '''','''' + REPLACE(@SelectDim,''''['''',''''v.['''')

	SEt @Sql = @Sql + '''',a.[Voucher_MemberId]
	,a.[LineItem_MemberId]
	FROM  FACT_Vouchers_default_partition a , #vouchersDetail v, #TimeTemp t 
	WHERE	a.Vouchers_Value <> 0
			And a.Version_Memberid = -1
			And a.''''+@BusinessProcessDim+''''_MemberId = -1
			And a.''''+@TimeDim+''''_Memberid  = t.memberid
			And a.''''+@ScenarioDim+''''_Memberid = v.Scenario_memberid
			And a.''''+@EntityDim+''''_Memberid = v.Entity_MemberId
			And a.Voucher_MemberId = v.Voucher_MemberId
			And a.Lineitem_MemberId = v.lineItem_MemberId
			And v.active = 1
			And v.Cumulative = 0 ''''
	Exec(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '
 

	SET @Sql = ''''INSERT INTO #Fact
	SELECT 
	 v.[Account_MemberId]
	,v.[BusinessProcess_MemberId]
	,v.[Currency_MemberId]
	,a.[''''+@EntityDim+''''_MemberId]
	,a.[''''+@ScenarioDim+''''_MemberId]
	,a.[''''+@TimeDim+''''_MemberId]
	,a.[TimeDataView_MemberId]
	,a.[Vouchers_Value]* v.Debitcredit * v.[Sign]''''

	IF @NBDim > 0 Set @Sql = @Sql + '''','''' + REPLACE(@SelectDim,''''['''',''''v.['''')

	Set @Sql = @sql + ''''
	,a.[Voucher_MemberId]
	,a.[LineItem_MemberId]
	FROM  FACT_Vouchers_default_partition a, #vouchersDetail v, #TimeTemp t 
	WHERE	a.Vouchers_Value <> 0
	And a.Version_Memberid = -1
	And a.''''+@BusinessProcessDim+''''_MemberId = -1
	And a.''''+@TimeDim+''''_Memberid  = t.memberid
	And a.''''+@ScenarioDim+''''_Memberid = v.Scenario_MemberId
	And a.''''+@EntityDim+''''_Memberid = v.Entity_MemberId
	And a.Voucher_MemberId = v.Voucher_MemberId
	And a.Lineitem_MemberId = v.LineItem_MemberId
	And v.active = 1
	And v.Cumulative = 1
	And v.Account_memberid in (Select memberid from Ds_''''+@AccountDim+'''' where TimeBalance = 0)''''
	Exec(@Sql)

	Set @sql = ''''INSERT INTO #Fact
	SELECT 
	 v.[Account_MemberId]
	,v.[BusinessProcess_MemberId]
	,v.[Currency_MemberId]
	,a.[''''+@EntityDim+''''_MemberId]
	,a.[''''+@ScenarioDim+''''_MemberId]
	,t.[Time_MemberId]
	,a.[TimeDataView_MemberId]
	,a.[Vouchers_Value]* v.Debitcredit * v.[Sign]''''

	If @nbdim > 0 Set @sql = @sql + '''','''' + REPLACE(@SelectDim,''''['''',''''v.['''') ' 


			SET @SQLStatement = @SQLStatement + '
 

	Set @sql = @sql + ''''
	,a.[Voucher_MemberId]
	,a.[LineItem_MemberId]
	FROM  FACT_Vouchers_default_partition a, #vouchersDetail v, #Time t 
	WHERE	a.Vouchers_Value <> 0
	And a.Version_Memberid = -1
	And a.BusinessProcess_MemberId = -1
	And a.Time_Memberid  = t.SourceTime_Memberid
	And a.Scenario_Memberid = v.Scenario_MemberId
	And a.Entity_Memberid = v.Entity_MemberId
	And a.Voucher_MemberId = v.Voucher_MemberId
	And a.LineItem_MemberId = v.LineItem_MemberId
	And v.active = 1
	And v.Cumulative = 1 
	And v.Account_memberid in (Select memberid from Ds_''''+@AccountDim+'''' where TimeBalance = 1)''''
	Exec(@sql)

	Set @sql = ''''DELETE FROM FACT_Financials_default_partition 
	WHERE
		''''+@businessprocessDim+''''_memberid in (select businessprocess_memberid from #Businessprocess)
		And ''''+@TimeDim+''''_Memberid  IN (select memberid From #TimeTemp)
		And ''''+@ScenarioDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
		And ''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')''''
	Exec(@Sql)

	Set @Sql = ''''DELETE FROM FACT_Vouchers_default_partition 
	WHERE
			''''+@businessprocessDim+''''_memberid in (select businessprocess_memberid from #Businessprocess)
		And ''''+@TimeDim+''''_Memberid  IN (select memberid From #TimeTemp)
		And ''''+@ScenarioDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
		And ''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')''''

	Set @sql = ''''INSERT INTO [FACT_Vouchers_Default_Partition]
	(
	 [''''+@AccountDim+''''_MemberId]
	,[''''+@BusinessProcessDim+''''_MemberId]
	,[''''+@CurrencyDim+''''_MemberId]
	,[''''+@EntityDim+''''_MemberId]
	,[LineItem_MemberId]
	,[''''+@ScenarioDim+''''_MemberId]
	,[''''+@TimeDim+''''_MemberId]
	,[TimeDataView_MemberId]
	,[Voucher_MemberId]'''' ' 


			SET @SQLStatement = @SQLStatement + '
 

	IF @Nbdim > 0 Set @Sql = @Sql + '''','''' + @SelectDim

	Set @sql = @sql + ''''
	,[ChangeDatetime]
	,[Userid]
	,[Vouchers_Value]
	)
	SELECT 
	 [Account_MemberId]
	,[BusinessProcess_MemberId]
	,[Currency_MemberId]
	,[Entity_MemberId]
	,[LineItem_MemberId]
	,[Scenario_MemberId]
	,[Time_MemberId]
	,[TimeDataView_MemberId]
	,[Voucher_MemberId]''''

	IF @Nbdim > 0 Set @Sql = @Sql + '''','''' + @SelectDim

	Set @sql = @sql  +'''',Getdate() as [ChangeDatetime]
	,''''''''''''+@User+'''''''''''' as [Userid]
	,SUM([Financials_Value])
	FROM #Fact 
	GROUP BY 
	 [Account_MemberId]
	,[BusinessProcess_MemberId]
	,[Currency_MemberId]
	,[Entity_MemberId]
	,[LineItem_MemberId]
	,[Scenario_MemberId]
	,[Time_MemberId]
	,[TimeDataView_MemberId]''''

	IF @Nbdim > 0 Set @Sql = @Sql + '''','''' + @SelectDim

	Set @sql = @sql + '''',[Voucher_MemberId]''''
	Print(@sql)
	Exec(@sql)


	Set @sql = ''''INSERT INTO [FACT_Financials_Default_Partition]
	([''''+@AccountDim+''''_MemberId]
	,[''''+@BusinessProcessDim+''''_MemberId]
	,[''''+@CurrencyDim+''''_MemberId]
	,[''''+@EntityDim+''''_MemberId]
	,[''''+@ScenarioDim+''''_MemberId]
	,[''''+@TimeDim+''''_MemberId]
	,[TimeDataView_MemberId] ''''

	IF @Nbdim > 0 Set @Sql = @Sql + '''','''' + @SelectDim ' 


			SET @SQLStatement = @SQLStatement + '
 

	Set @sql = @sql + ''''
	,[ChangeDatetime]
	,[Userid]
	,[Financials_Value])
	SELECT 
	 [Account_MemberId]
	,[BusinessProcess_MemberId]
	,[Currency_MemberId]
	,[Entity_MemberId]
	,[Scenario_MemberId]
	,[Time_MemberId]
	,[TimeDataView_MemberId]''''

	IF @Nbdim > 0 Set @Sql = @Sql + '''','''' + @SelectDim

	Set @sql = @sql + ''''
	,Getdate() as [ChangeDatetime]
	,''''''''''''+@User+'''''''''''' as [Userid]
	,Sum([Financials_Value])
	FROM #Fact 
	GROUP BY 
	 [Account_MemberId]
	,[BusinessProcess_MemberId]
	,[Currency_MemberId]
	,[Entity_MemberId]
	,[Scenario_MemberId]
	,[Time_MemberId]
	,[TimeDataView_MemberId] ''''
	IF @Nbdim > 0 Set @Sql = @Sql + '''','''' + @SelectDim

	Print(@sql)
	Exec(@sql)

----   Drop table #Fact,#Businessprocess,#time,#year,#timetemp,#vouchers,#vouchersDetail,#vouchersheader,#dimmodel

END '

IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END






/****** Object:  StoredProcedure [dbo].[Canvas_Copy_Voucher]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Copy_Voucher'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Copy_Voucher') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
 PROCEDURE  [dbo].[Canvas_Copy_Voucher]
@dim1 Nvarchar(255) =''''''''
,@dim2 Nvarchar(255) =''''''''
,@dim3 Nvarchar(255) =''''''''
,@dim4 Nvarchar(255) =''''''''
,@dim5 Nvarchar(255) =''''''''

' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS


--DECLARE @dim1 Nvarchar(255),@dim2 Nvarchar(255),@dim3 Nvarchar(255),@dim4 Nvarchar(255),@dim5 Nvarchar(255) 
--Set @Dim1=''''Cost_center''''
--Set @Dim2=''''''''
--Set @Dim3=''''''''
--Set @Dim4=''''''''
--Set @Dim5=''''''''
 -- Select * into #temp_parametervalues from temp_parametervalues

BEGIN

	DECLARE @ScenarioID BIGINT
	,@TimeID BIGINT
	,@BusinessprocessID BIGINT
	,@Time  Nvarchar(255)
	,@MinTime  Nvarchar(255)
	,@MaxOffset  INT
	,@User Nvarchar(255)
	,@ModelName Nvarchar(50)
	,@Lap INT
	,@NBDim INT

	Select @user = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''UserId''''
	Select @ModelName = Stringvalue From #Temp_ParameterValues Where ParameterName = ''''Model''''

	Declare  @AccountDim nvarchar(100)
	,@ScenarioDim nvarchar(100)
	, @EntityDim nvarchar(100)
	,@BusinessprocessDim nvarchar(100)
	,@CurrencyDim nvarchar(100)
	,@TimeDim nvarchar(100)
	,@RoundDim nvarchar(100)
	,@LineItemDim nvarchar(100)
	,@VersionDim nvarchar(100)
	,@DimType nvarchar(100)
	,@Dimlabel nvarchar(100)
	,@Sql nvarchar(max)
	,@SelectDim nvarchar(max)
	,@SelectDimAS nvarchar(max) ' 


			SET @SQLStatement = @SQLStatement + '
 
	

	Declare @IsRound Bit
	Set @IsRound = 0

	create table #dimModel (Dimension nvarchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS,Dimtype nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS)
	
	INsert into #dimModel select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname+'''''''' And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]

	Declare Dim_cursor cursor for select [Dimension],[DimType] from #DimModel ORDER BY [Dimtype]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		if @DimType = ''''Account'''' set @AccountDim = RTRIM(@DimLabel)
		if @DimType = ''''Scenario'''' Set @ScenarioDim = RTRIM(@DimLabel)
		if @DimType = ''''Entity'''' set @EntityDim = RTRIM(@DimLabel)
		if @DimType = ''''BusinessProcess'''' Set @BusinessprocessDim = RTRIM(@DimLabel)
		if @DimType = ''''Currency'''' set @CurrencyDim = RTRIM(@DimLabel)
		if @DimType = ''''Time'''' set @TimeDim = RTRIM(@DimLabel)
		if @DimType = ''''Round'''' 
		begin
			set @roundDim = RTRIM(@DimLabel)
			Set @IsRound = 1
		end

	fetch next from Dim_cursor into @DimLabel,@DimType
	end
	close Dim_cursor
	deallocate Dim_cursor ' 


			SET @SQLStatement = @SQLStatement + '
 
	
	Create table #Year (year_label nvarchar(6) COLLATE SQL_Latin1_General_CP1_CI_AS)
	Create table #TimeTemp (memberid BIGINT, label nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

	SET @Sql = ''''INSERT INTO #year
	Select TimeFiscalyear 
	From #temp_parametervalues a, [DS_''''+@TimeDim+''''] b
	Where
	a.memberid = b.memberid and a.Parametername = ''''''''TimeMbrs'''''''' ''''
	Print(@Sql)
	EXEC(@Sql)

	Set @Sql = ''''INSERT INTO #TimeTemp
	Select b.memberid,b.label
	From #year a, [DS_''''+@TimeDim+''''] b
	Where
	b.TimeFiscalYear = a.Year_label
	AND b.TimeFiscalPeriod in (''''''''FP01'''''''',''''''''FP02'''''''',''''''''FP03'''''''',''''''''FP04'''''''',''''''''FP05'''''''',''''''''FP06'''''''',''''''''FP07'''''''',''''''''FP08'''''''',''''''''FP09'''''''',''''''''FP10'''''''',''''''''FP11'''''''',''''''''FP12'''''''') ''''
	Print(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '
 

	Create table #Time (
	Time_memberid BIGINT
	,[Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,SourceTime_Memberid BIGINT
	,[SourceTime] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

	SET @Sql = ''''INSERT INTO #Time 
	Select a.Memberid, b.label,c.memberid,c.label
	From #Timetemp a, [DS_''''+@TimeDim+''''] b, [DS_''''+@TimeDim+''''] c
	Where
	b.TimeFiscalPeriod in (''''''''FP01'''''''',''''''''FP02'''''''',''''''''FP03'''''''',''''''''FP04'''''''',''''''''FP05'''''''',''''''''FP06'''''''',''''''''FP07'''''''',''''''''FP08'''''''',''''''''FP09'''''''',''''''''FP10'''''''',''''''''FP11'''''''',''''''''FP12'''''''')
	and c.TimeFiscalPeriod in (''''''''FP01'''''''',''''''''FP02'''''''',''''''''FP03'''''''',''''''''FP04'''''''',''''''''FP05'''''''',''''''''FP06'''''''',''''''''FP07'''''''',''''''''FP08'''''''',''''''''FP09'''''''',''''''''FP10'''''''',''''''''FP11'''''''',''''''''FP12'''''''')
	AND a.memberid = b.memberid
	and b.TimeFiscalPeriod >= c.TimeFiscalPeriod
	And b.TimeFiscalyear = c.TimeFiscalyear
	order by 2 ''''
	EXEC(@Sql)


	Create Table #Businessprocess (businessprocess_memberid BIGINT)
	Insert into #Businessprocess
	Select memberid from ds_businessprocess Where manual = 1 
	--And memberid not in (Select BP_converted_memberid from ds_businessprocess)

	CREATE TABLE #vouchers (
	[Voucher_MemberId] BIGINT
	,[Scenario_MemberId] BIGINT
	,[Time_MemberId] BIGINT
	,[Entity_MemberId] BIGINT
	,[Round_MemberId] BIGINT
	,[Active] INT
	,[Cumulative] INT
	)
	
	SET @Sql = ''''INSERT INTO #Vouchers
	SELECT [Voucher_MemberId],[Scenario_MemberId],[Time_MemberId],[Entity_MemberId],[Round_MemberId],Sum([Active]) as Active,Sum([Cumulative]) As Cumulative
	FROM (
	Select a.[Voucher_MemberId],a.[''''+@ScenarioDim+''''_MemberId],a.[''''+@TimeDim+''''_MemberId],a.[''''+@EntityDim+''''_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[''''+@RoundDim+''''_Memberid] ''''
	IF @IsRound = 0 set @sql = @sql + '''',-1 As [''''+@RoundDim+''''_Memberid] ''''
	Set @sql = @sql + '''' 
	,CASE WHEN Vouchers_Text = ''''''''Yes'''''''' THEN 1 ELSE 0 END as Active
	,0 As Cumulative
	FROM  FACT_Vouchers_Text a
	WHERE	a.Vouchers_text <> ''''''''''''''''
			And a.Lineitem_memberid in (select memberid from DS_LineItem where label = ''''''''Active'''''''')
			And a.''''+@TimeDim+''''_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
			And a.''''+@ScenarioDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
			And a.''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')'''' ' 


			SET @SQLStatement = @SQLStatement + '
 
	
	IF @IsRound = 1 set @sql = @sql + ''''
			And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''') ''''
	Set @sql = @sql + '''' 
	UNION ALL
	Select a.[Voucher_MemberId],a.[''''+@ScenarioDim+''''_MemberId],a.[''''+@TimeDim+''''_MemberId],a.[''''+@EntityDim+''''_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[''''+@RoundDim+''''_Memberid] ''''
	IF @IsRound = 0 set @sql = @sql + '''',-1 As [''''+@RoundDim+''''_Memberid] ''''
	Set @sql = @sql + '''' 
	,0 As Active
	,CASE WHEN Vouchers_Text = ''''''''Yes'''''''' THEN 1 ELSE 0 END as Cumulative
	FROM  FACT_Vouchers_Text a
	WHERE	a.Vouchers_text <> ''''''''''''''''
			And a.Lineitem_memberid in (select memberid from DS_LineItem where label = ''''''''Cumulative'''''''')
			And a.''''+@TimeDim+''''_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
			And a.''''+@Scenariodim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
			And a.''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''') ''''
	IF @IsRound = 1 set @sql = @sql + ''''
			And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''') ''''
	Set @sql = @sql + '''' 
	) As tmp
	Group By [Voucher_MemberId],[Scenario_MemberId],[Time_MemberId],[Entity_MemberId],[Round_Memberid]''''
	Print(@Sql)
	Exec(@Sql)


	CREATE TABLE #vouchersHeader ([Voucher_MemberId] BIGINT,[Scenario_MemberId] BIGINT,[Time_MemberId] BIGINT,[Entity_MemberId] BIGINT,[Round_MemberId] BIGINT
	,[BusinessProcess_Memberid] BIGINT,[Currency_Memberid] BIGINT)

	SET @Sql = ''''INSERT INTO #VouchersHeader
	SELECT [Voucher_MemberId] ,[Scenario_MemberId] ,[Time_MemberId] ,[Entity_MemberId],[Round_MemberId]
	,SUM([BusinessProcess_Memberid] ) as [BusinessProcess_Memberid] 
	,SUM([Currency_Memberid] ) as [Currency_Memberid] 
	FROM (
	Select 
	a.[Voucher_MemberId]
	,a.[''''+@ScenarioDim+''''_MemberId]
	,a.[''''+@TimeDim+''''_MemberId]
	,a.[''''+@EntityDim+''''_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[''''+@RoundDim+''''_Memberid] ''''
	IF @IsRound = 0 set @sql = @sql + '''',-1 As [''''+@RoundDim+''''_Memberid] ''''
	Set @sql = @sql + '''' 
	,b.memberid as [Businessprocess_MemberId]
	,0 as [Currency_MemberId]
	FROM  FACT_Vouchers_Text a, DS_''''+@BusinessprocessDim+'''' b
	WHERE	a.Vouchers_text <> ''''''''''''''''
			And a.Lineitem_memberid in (select memberid from DS_LineItem where label = ''''''''BP'''''''')
			And a.Vouchers_Text = b.Label
			And a.''''+@TimeDim+''''_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
			And a.''''+@ScenarioDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
			And a.''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')'''' ' 


			SET @SQLStatement = @SQLStatement + '
 
	
	IF @IsRound = 1 set @sql = @sql + ''''
			And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''') ''''
	Set @sql = @sql + '''' 
	UNION ALL
	Select 
	a.[Voucher_MemberId],a.[''''+@ScenarioDim+''''_MemberId],a.[''''+@TimeDim+''''_MemberId],a.[''''+@EntityDim+''''_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[''''+@RoundDim+''''_Memberid] ''''
	IF @IsRound = 0 set @sql = @sql + '''',-1 As [''''+@RoundDim+''''_Memberid] ''''
	Set @sql = @sql + '''' 
	,0 as [Businessprocess_MemberId]
	,b.memberid as [Currency_MemberId]
	FROM  FACT_Vouchers_Text a, DS_''''+@CurrencyDim+'''' b
	WHERE	a.Vouchers_text <> ''''''''''''''''
			And a.Lineitem_memberid in (select memberid from DS_LineItem where label = ''''''''CUR'''''''')
			And a.Vouchers_Text = b.Label
			And a.''''+@TimeDim+''''_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
			And a.''''+@ScenarioDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
			And a.''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')''''
	IF @IsRound = 1 set @sql = @sql + ''''
			And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''') ''''
	Set @sql = @sql + '''' 
	)
	AS TMP
	GROUP BY 
	[Voucher_MemberId] ,[Scenario_MemberId] ,[Time_MemberId] ,[Entity_MemberId],[Round_MemberId]''''
	Exec(@Sql)

--=============================================>
	CREATE TABLE #vouchersDetail (
	 [Voucher_MemberId] BIGINT
	,[Scenario_MemberId] BIGINT
	,[Time_MemberId] BIGINT
	,[Entity_MemberId] BIGINT
	,[Round_MemberId] BIGINT
	,[LineItem_Memberid] BIGINT
	,[Account_Memberid] BIGINT
	)


	If @Dim1 <> '''''''' 
	BEGIN
		Set @Sql = @Sql + ''''ALTER TABLE #vouchersDetail ADD [''''+@Dim1+''''_Memberid] BIGINT''''
		If @Dim2 <> '''''''' Set @Sql = @Sql + '''',[''''+@Dim2+''''_Memberid] BIGINT''''
		If @Dim3 <> '''''''' Set @Sql = @Sql + '''',[''''+@Dim3+''''_Memberid] BIGINT''''
		If @Dim4 <> '''''''' Set @Sql = @Sql + '''',[''''+@Dim4+''''_Memberid] BIGINT''''
		If @Dim5 <> '''''''' Set @Sql = @Sql + '''',[''''+@Dim5+''''_Memberid] BIGINT''''
		Exec(@Sql)
	END ' 


			SET @SQLStatement = @SQLStatement + '
 
	
	Set @Sql =  ''''ALTER TABLE #vouchersDetail ADD 
	 [Sign] INT
	,[Debitcredit] INT
	,[Active] INT
	,[Cumulative] INT 
	,[BusinessProcess_Memberid] BIGINT 
	,[Currency_Memberid] BIGINT ''''
	Exec(@Sql)

	Set @SelectDim = ''''''''
	Set @SelectDimAS = ''''''''
	Set @NBDim = 0
	If @Dim1 <> '''''''' 
	BEGIN
		Set @NBDim = 1
		Set @SelectDim = ''''[''''+@Dim1+''''_memberid]''''
		Set @SelectDimAS = '''',SUM([''''+@Dim1+''''_Memberid]) as [''''+@Dim1+''''_Memberid]''''
		If @Dim2 <> '''''''' 
		BEGIn
			Set @NBDim = 2
			Set @SelectDim = @SelectDim + '''',[''''+@Dim2+''''_memberid]''''
			Set @SelectDimAS = @SelectDimAS + '''',SUM([''''+@Dim2+''''_Memberid]) as [''''+@Dim2+''''_Memberid]''''
			If @Dim3 <> '''''''' 
			BEGIN
				Set @NBDim = 3
				Set @SelectDim = @SelectDim + '''',[''''+@Dim3+''''_memberid]''''
				Set @SelectDimAS = @SelectDimAS + '''',SUM([''''+@Dim3+''''_Memberid]) as [''''+@Dim3+''''_Memberid]''''
				If @Dim4 <> '''''''' 
				BEGIN
					Set @NBDim = 4
					Set @SelectDim = @SelectDim + '''',[''''+@Dim4+''''_memberid]''''
					Set @SelectDimAS = @SelectDimAS + '''',SUM([''''+@Dim4+''''_Memberid]) as [''''+@Dim4+''''_Memberid]''''
					If @Dim5 <> '''''''' 
					BEGIn
						Set @NBDim = 5
						Set @SelectDim = @SelectDim + '''',[''''+@Dim5+''''_memberid]''''
						Set @SelectDimAS = @SelectDimAS + '''',SUM([''''+@Dim5+''''_Memberid]) as [''''+@Dim5+''''_Memberid]''''
					END
				END
			END
		END
	END ' 


			SET @SQLStatement = @SQLStatement + '
 
	

	Set @Sql = ''''INSERT INTO #VouchersDetail
	SELECT 
	[Voucher_MemberId] 
	,[Scenario_MemberId] 
	,[Time_MemberId] 
	,[Entity_MemberId]
	,[Round_MemberId]
	,[LineItem_MemberId] 
	,SUM([Account_Memberid] ) as [Account_Memberid] ''''
	+@SelectdimAS+''''
	,SUM([Sign]) as [Sign]
	,SUM([DebitCredit]) as DebitCredit 
	,[Active] = 0
	,[Cumulative] = 0 
	,[BusinessProcess_Memberid]  = 0
	,[Currency_Memberid] = 0 
	FROM (
	Select 
	 a.[Voucher_MemberId]
	,a.[''''+@ScenarioDim+''''_MemberId]
	,a.[''''+@TimeDim+''''_MemberId]
	,a.[''''+@EntityDim+''''_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[''''+@RoundDim+''''_Memberid] ''''
	IF @IsRound = 0 set @sql = @sql + '''',-1 As [''''+@RoundDim+''''_Memberid] ''''
	Set @sql = @sql + '''' 
	,a.[LineItem_MemberId]
	,b.memberid as [Account_MemberId] 
	,''''+REPLACE(@SelectDim,''''['''',''''0 AS ['''') +''''
	,0 as [DebitCredit]
	,b.[sign] 
	FROM  FACT_Vouchers_Text a, DS_Account b
	WHERE	a.Vouchers_text <> ''''''''''''''''
			And a.businessprocess_memberid in (select memberid from DS_Businessprocess where label = ''''''''BP_Account'''''''')
			And a.Vouchers_Text = b.Label
			And a.Time_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
			And a.Scenario_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
			And a.Entity_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')''''
	IF @IsRound = 1 set @sql = @sql + ''''
			And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''') ''''
	Set @sql = @sql + '''' 
	UNION ALL
	Select 
	a.[Voucher_MemberId]
	,a.[Scenario_MemberId]
	,a.[Time_MemberId]
	,a.[Entity_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[''''+@RoundDim+''''_Memberid] ''''
	IF @IsRound = 0 set @sql = @sql + '''',-1 As [''''+@RoundDim+''''_Memberid] '''' ' 


			SET @SQLStatement = @SQLStatement + '
 
	
	Set @sql = @sql + '''' 
	,a.[LineItem_MemberId]
	,0 as [Account_MemberId] 
	,''''+REPLACE(@SelectDim,''''['''',''''0 AS ['''') +''''
	,CASE WHEN Vouchers_Text = ''''''''Debit'''''''' THEN 1 ELSE -1 END as DebitCredit
	,0 as [Sign]
	FROM  FACT_Vouchers_Text a
	WHERE	a.Vouchers_text <> ''''''''''''''''
			And a.businessprocess_memberid in (select memberid from DS_Businessprocess where label = ''''''''BP_DEBITCREDIT'''''''')
			And a.Time_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
			And a.Scenario_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
			And a.Entity_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''') ''''
	IF @IsRound = 1 set @sql = @sql + ''''
			And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''') ''''

	Set @lap = 0
	DECLARE @MyDim Nvarchar(100)
	While @Lap <= @NBDim
	BEGIN 
		SET @Lap = @Lap+1
		IF @lap = 1 SET @Mydim = @Dim1
		IF @lap = 2 SET @Mydim = @Dim2
		IF @lap = 3 SET @Mydim = @Dim3
		IF @lap = 4 SET @Mydim = @Dim4
		IF @lap = 5 SET @Mydim = @Dim5

		SET @Sql = @Sql + ''''
		UNION ALL
		Select 
		a.[Voucher_MemberId]
		,a.[Scenario_MemberId]
		,a.[Time_MemberId]
		,a.[Entity_MemberId]
		,a.[LineItem_MemberId]
		,0 as [Account_MemberId] 
		,''''+REPLACE(@SelectDim,''''[''''+@MyDim+''''_Memberid]'''',''''b.memberid AS [''''+@MyDim+''''_Memberid]'''') +''''''''
	IF @IsRound = 1 set @sql = @sql + '''',[''''+@RoundDim+''''_Memberid] ''''
	IF @IsRound = 0 set @sql = @sql + '''',-1 As [''''+@RoundDim+''''_Memberid] ''''
	Set @sql = @sql + '''' 
		,0 as [DebitCredit]
		,0 as [Sign]
		FROM  FACT_Vouchers_Text a, DS_''''+@MyDim+'''' b
		WHERE	a.Vouchers_text <> ''''''''''''''''
				And a.businessprocess_memberid in (select memberid from DS_Businessprocess where label = ''''''''BP_''''+@MyDim+'''''''''''')
				And a.Vouchers_Text = b.Label
				And a.Time_Memberid  IN (select memberid From #Temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
				And a.Scenario_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
				And a.Entity_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''') ''''
		IF @IsRound = 1 set @sql = @sql + ''''
			And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''') ''''
		SET @Lap = @lap + 1
	END ' 


			SET @SQLStatement = @SQLStatement + '
 
	
	Set @sql = @Sql + ''''
	)
	AS TMP
	GROUP BY [Voucher_MemberId] ,[Scenario_MemberId] ,[Time_MemberId] ,[Entity_MemberId],[Round_MemberId] ,[LineItem_MemberId] ''''
	Print(@Sql)
	Exec(@Sql)

	Create table #Fact
	(
	 [Account_MemberId] [bigint]  
	,[BusinessProcess_MemberId] [bigint]  
	,[Currency_MemberId] [bigint] 
	,[Entity_MemberId] [bigint] 
	,[Round_MemberId] [bigint] 
	,[Scenario_MemberId] [bigint] 
	,[Time_MemberId] [bigint] 
	,[TimeDataView_MemberId] [bigint] 
	,[Financials_Value] [float]  NULL)

	IF @NBDim > 0 
	BEGIN
		SET @Sql = ''''ALTER TABLE #Fact add ''''+REPLACE(@SelectDim,'''']'''',''''] BIGINT'''')
		EXEC(@Sql)
	END
	ALTER TABLE #fact ADD [Voucher_MemberId] Bigint,[LineItem_MemberId] Bigint

	SET @sql = ''''INSERT INTO #Fact
	SELECT 
	 v.[Account_MemberId]
	,v.[BusinessProcess_MemberId]
	,v.[Currency_MemberId]
	,a.[''''+@EntityDim+''''_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[''''+@RoundDim+''''_Memberid] ''''
	IF @IsRound = 0 set @sql = @sql + '''',-1 As [''''+@RoundDim+''''_Memberid] ''''
	Set @sql = @sql + '''' 
	,a.[''''+@ScenarioDim+''''_MemberId]
	,a.[''''+@TimeDim+''''_MemberId]
	,a.[TimeDataView_MemberId]
	,a.[Vouchers_Value] * v.Debitcredit * v.[Sign] ''''

	IF @NBDim > 0  Set @Sql = @sql + '''','''' + REPLACE(@SelectDim,''''['''',''''v.['''') ' 


			SET @SQLStatement = @SQLStatement + '
 
	

	SEt @Sql = @Sql + '''',a.[Voucher_MemberId]
	,a.[LineItem_MemberId]
	FROM  FACT_Vouchers_default_partition a , #vouchersDetail v, #TimeTemp t 
	WHERE	a.Vouchers_Value <> 0
			And a.Version_Memberid = -1
			And a.''''+@BusinessProcessDim+''''_MemberId = -1
			And a.''''+@TimeDim+''''_Memberid  = t.memberid
			And a.''''+@ScenarioDim+''''_Memberid = v.Scenario_memberid
			And a.''''+@EntityDim+''''_Memberid = v.Entity_MemberId
			And a.''''+@RoundDim+''''_Memberid = v.Round_MemberId
			And a.Voucher_MemberId = v.Voucher_MemberId
			And a.Lineitem_MemberId = v.lineItem_MemberId
			And v.active = 1
			And v.Cumulative = 0 ''''
	Exec(@Sql)

	SET @Sql = ''''INSERT INTO #Fact
	SELECT 
	 v.[Account_MemberId]
	,v.[BusinessProcess_MemberId]
	,v.[Currency_MemberId]
	,a.[''''+@EntityDim+''''_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[''''+@RoundDim+''''_Memberid] ''''
	IF @IsRound = 0 set @sql = @sql + '''',-1 As [''''+@RoundDim+''''_Memberid] ''''
	Set @sql = @sql + '''' 
	,a.[''''+@ScenarioDim+''''_MemberId]
	,a.[''''+@TimeDim+''''_MemberId]
	,a.[TimeDataView_MemberId]
	,a.[Vouchers_Value]* v.Debitcredit * v.[Sign]''''

	IF @NBDim > 0 Set @Sql = @Sql + '''','''' + REPLACE(@SelectDim,''''['''',''''v.['''')

	Set @Sql = @sql + ''''
	,a.[Voucher_MemberId]
	,a.[LineItem_MemberId]
	FROM  FACT_Vouchers_default_partition a, #vouchersDetail v, #TimeTemp t 
	WHERE	a.Vouchers_Value <> 0
	And a.Version_Memberid = -1
	And a.''''+@BusinessProcessDim+''''_MemberId = -1
	And a.''''+@TimeDim+''''_Memberid  = t.memberid
	And a.''''+@ScenarioDim+''''_Memberid = v.Scenario_MemberId
	And a.''''+@EntityDim+''''_Memberid = v.Entity_MemberId''''
	IF @IsRound = 1 set @sql = @sql + ''''
		And a.''''+@RoundDim+''''_Memberid = v.Round_MemberId ''''
	Set @Sql = @Sql + ''''
	And a.Voucher_MemberId = v.Voucher_MemberId
	And a.Lineitem_MemberId = v.LineItem_MemberId
	And v.active = 1
	And v.Cumulative = 1
	And v.Account_memberid in (Select memberid from Ds_''''+@AccountDim+'''' where TimeBalance = 0)''''
	Exec(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '
 

	Set @sql = ''''INSERT INTO #Fact
	SELECT 
	 v.[Account_MemberId]
	,v.[BusinessProcess_MemberId]
	,v.[Currency_MemberId]
	,a.[''''+@EntityDim+''''_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[''''+@RoundDim+''''_Memberid] ''''
	IF @IsRound = 0 set @sql = @sql + '''',-1 As [''''+@RoundDim+''''_Memberid] ''''
	Set @sql = @sql + '''' 
	,a.[''''+@ScenarioDim+''''_MemberId]
	,t.[Time_MemberId]
	,a.[TimeDataView_MemberId]
	,a.[Vouchers_Value]* v.Debitcredit * v.[Sign]''''

	If @nbdim > 0 Set @sql = @sql + '''','''' + REPLACE(@SelectDim,''''['''',''''v.['''')

	Set @sql = @sql + ''''
	,a.[Voucher_MemberId]
	,a.[LineItem_MemberId]
	FROM  FACT_Vouchers_default_partition a, #vouchersDetail v, #Time t 
	WHERE	a.Vouchers_Value <> 0
	And a.Version_Memberid = -1
	And a.BusinessProcess_MemberId = -1
	And a.Time_Memberid  = t.SourceTime_Memberid
	And a.Scenario_Memberid = v.Scenario_MemberId
	And a.Entity_Memberid = v.Entity_MemberId''''
	IF @IsRound = 1 set @sql = @sql + ''''
		And a.''''+@RoundDim+''''_Memberid = v.Round_MemberId ''''
	Set @Sql = @Sql + ''''
	And a.Voucher_MemberId = v.Voucher_MemberId
	And a.LineItem_MemberId = v.LineItem_MemberId
	And v.active = 1
	And v.Cumulative = 1 
	And v.Account_memberid in (Select memberid from Ds_''''+@AccountDim+'''' where TimeBalance = 1)''''
	Exec(@sql)

	Set @sql = ''''DELETE FROM FACT_Financials_default_partition 
	WHERE
		''''+@businessprocessDim+''''_memberid in (select businessprocess_memberid from #Businessprocess)
		And ''''+@TimeDim+''''_Memberid  IN (select memberid From #TimeTemp)
		And ''''+@ScenarioDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
		And ''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')''''
	IF @IsRound = 1 set @sql = @sql + ''''
			And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''') ''''
	Exec(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '
 
	

	Set @Sql = ''''DELETE FROM FACT_Vouchers_default_partition 
	WHERE
			''''+@businessprocessDim+''''_memberid in (select businessprocess_memberid from #Businessprocess)
		And ''''+@TimeDim+''''_Memberid  IN (select memberid From #TimeTemp)
		And ''''+@ScenarioDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''ScenarioMbrs'''''''')
		And ''''+@EntityDim+''''_Memberid IN (select memberid From #Temp_parametervalues where parametername = ''''''''EntityMbrs'''''''')''''
	IF @IsRound = 1 set @sql = @sql + ''''
			And ''''+@RoundDim+''''_Memberid in (Select memberid from #temp_parametervalues Where parametername = ''''''''RoundMbrs'''''''') ''''

	Set @sql = ''''INSERT INTO [FACT_Vouchers_Default_Partition]
	(
	 [''''+@AccountDim+''''_MemberId]
	,[''''+@BusinessProcessDim+''''_MemberId]
	,[''''+@CurrencyDim+''''_MemberId]
	,[''''+@EntityDim+''''_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[''''+@RoundDim+''''_Memberid] ''''
	Set @sql = @sql + '''' 
	,[LineItem_MemberId]
	,[''''+@ScenarioDim+''''_MemberId]
	,[''''+@TimeDim+''''_MemberId]
	,[TimeDataView_MemberId]
	,[Voucher_MemberId]''''

	IF @Nbdim > 0 Set @Sql = @Sql + '''','''' + @SelectDim

	Set @sql = @sql + ''''
	,[ChangeDatetime]
	,[Userid]
	,[Vouchers_Value]
	)
	SELECT 
	 [Account_MemberId]
	,[BusinessProcess_MemberId]
	,[Currency_MemberId]
	,[Entity_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[Round_Memberid] ''''
	Set @sql = @sql + '''' 
	,[LineItem_MemberId]
	,[Scenario_MemberId]
	,[Time_MemberId]
	,[TimeDataView_MemberId]
	,[Voucher_MemberId]''''

	IF @Nbdim > 0 Set @Sql = @Sql + '''','''' + @SelectDim ' 


			SET @SQLStatement = @SQLStatement + '
 
	

	Set @sql = @sql  +'''',Getdate() as [ChangeDatetime]
	,''''''''''''+@User+'''''''''''' as [Userid]
	,SUM([Financials_Value])
	FROM #Fact 
	GROUP BY 
	 [Account_MemberId]
	,[BusinessProcess_MemberId]
	,[Currency_MemberId]
	,[Entity_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[Round_Memberid] ''''
	Set @sql = @sql + '''' 
	,[LineItem_MemberId]
	,[Scenario_MemberId]
	,[Time_MemberId]
	,[TimeDataView_MemberId]''''

	IF @Nbdim > 0 Set @Sql = @Sql + '''','''' + @SelectDim

	Set @sql = @sql + '''',[Voucher_MemberId]''''
	Print(@sql)
	Exec(@sql)


	Set @sql = ''''INSERT INTO [FACT_Financials_Default_Partition]
	([''''+@AccountDim+''''_MemberId]
	,[''''+@BusinessProcessDim+''''_MemberId]
	,[''''+@CurrencyDim+''''_MemberId]
	,[''''+@EntityDim+''''_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[''''+@RoundDim+''''_Memberid] ''''
	Set @sql = @sql + '''' 
	,[''''+@ScenarioDim+''''_MemberId]
	,[''''+@TimeDim+''''_MemberId]
	,[TimeDataView_MemberId] ''''

	IF @Nbdim > 0 Set @Sql = @Sql + '''','''' + @SelectDim

	Set @sql = @sql + ''''
	,[ChangeDatetime]
	,[Userid]
	,[Financials_Value])
	SELECT 
	 [Account_MemberId]
	,[BusinessProcess_MemberId]
	,[Currency_MemberId]
	,[Entity_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[Round_Memberid] ''''
	Set @sql = @sql + '''' 
	,[Scenario_MemberId]
	,[Time_MemberId]
	,[TimeDataView_MemberId]''''

	IF @Nbdim > 0 Set @Sql = @Sql + '''','''' + @SelectDim ' 


			SET @SQLStatement = @SQLStatement + '
 
	

	Set @sql = @sql + ''''
	,Getdate() as [ChangeDatetime]
	,''''''''''''+@User+'''''''''''' as [Userid]
	,Sum([Financials_Value])
	FROM #Fact 
	GROUP BY 
	 [Account_MemberId]
	,[BusinessProcess_MemberId]
	,[Currency_MemberId]
	,[Entity_MemberId]''''
	IF @IsRound = 1 set @sql = @sql + '''',[Round_Memberid] ''''
	Set @sql = @sql + '''' 
	,[Scenario_MemberId]
	,[Time_MemberId]
	,[TimeDataView_MemberId] ''''
	IF @Nbdim > 0 Set @Sql = @Sql + '''','''' + @SelectDim
	Print(@sql)
	Exec(@sql)

----   Drop table #Fact,#Businessprocess,#time,#year,#timetemp,#vouchers,#vouchersDetail,#vouchersheader,#dimmodel

END '

IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END


/****** Object:  StoredProcedure [dbo].[Canvas_Export_Financials]    Script Date: 3/2/2017 11:34:03 AM ******/
/****** Object:  StoredProcedure [dbo].[Canvas_FullAccount]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_FullAccount'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_FullAccount') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
 PROCEDURE  [dbo].[Canvas_FullAccount]
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
--------------------------- --------------------------------------------------------> DECLARE VARIABLES 
	DECLARE @Sql NVARCHAR(MAX),@AccountDim NVARCHAR(200),@lap INT,@MaxLap INT,@Hierarchy NVARCHAR(100),@Total INT,@Class INT
	,@Max BIGINT,@Count INT, @DimLabel nvarchar(50)
	CREATE TABLE #Temp (Label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS, ParentLabel Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,SequenceNumber Bigint)
	CREATE TABLE #Account (ID INT IDENTITY(1,1), Memberid Bigint,Label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	CREATE TABLE #Hierarchy (ID BIGINT IDENTITY(1,1),Hierarchy NVARCHAR(250) COLLATE SQL_Latin1_General_CP1_CI_AS)

	SELECT @AccountDim = [Label] from [Dimensions] Where [Type] = ''''Account''''
	if exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = ''''Checkout'''')  
	BEGIN
		UPDATE [Checkout] SET Status = 0,ChangeDatetime = GETDATE() WHERE Type = ''''Dimension'''' AND label = ''''FullAccount''''
	END
	UPDATE dbo.Dimensions SET ChangeDatetime = GETDATE() WHERE label = ''''FullAccount''''
		
	SET @Sql = ''''INSERT INTO #hierarchy SELECT hierarchy FROM DimensionHierarchies where dimension = ''''''''''''+@AccountDim+''''''''''''''''
	EXEC(@Sql)

	SET @MaxLap = @@rowcount
	SET @Lap = 1
	While @lap <= @MaxLap
	BEGIN
			SELECT @Hierarchy = Hierarchy FROM #Hierarchy Where id = @lap

			if exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = ''''S_HS_''''+@AccountDim+''''_''''+@Hierarchy)  
		BEGIN

			Truncate Table #temp
			Truncate Table #Account

			SET @Sql = ''''INSERT INTO #Temp SELECT 
			Label = b.Label 
			,ParentLabel = c.Label 
			,Sequencenumber = a.SequenceNumber 
			FROM [S_HS_''''+@AccountDim+''''_''''+@Hierarchy+''''] a, [S_DS_''''+@AccountDim+''''] b, [S_DS_''''+@AccountDim+''''] c
			WHERE a.Memberid = b.Memberid
			And a.ParentMemberid = c.memberid ''''  
			Print(@Sql)
			EXEC(@Sql) ' 

	
				SET @SQLStatement = @SQLStatement + '
	

			SET @Count = 1
			WHILE @Count > 0
			BEGIN
				Delete from #temp Where Label Not in (Select Account From s_ds_fullaccount) and label not in (Select parentlabel from #temp)
				SET @Count = @@ROWCOUNT
			END

			--Set @Sql = ''''Truncate table [HS_FullAccount_''''+@Hierarchy+'''']''''
			--EXEC(@sql)	
			Set @Sql = ''''Truncate table [S_HS_FullAccount_''''+@Hierarchy+'''']''''
			EXEC(@sql)	
			Set @Sql = ''''Truncate table [O_HS_FullAccount_''''+@Hierarchy+'''']''''
			EXEC(@sql)	

			delete From ds_fullaccount where Entity is null
			delete From s_ds_fullaccount where Entity is null
			delete From o_ds_fullaccount where Entity is null
			delete From ds_fullaccount where Entity = ''''None''''
			delete From s_ds_fullaccount where Entity = ''''None''''
			delete From o_ds_fullaccount where Entity = ''''None''''
			--delete From ds_fullaccount where Entity is null

			INSERT INTO #Account
			(Memberid, Label) 
			Select Distinct 0, ParentLabel 
			From #temp 
			Where 
			(ParentLabel Not in (Select Account From [S_DS_FullAccount]) OR ParentLabel Not in (Select Label From S_DS_FullAccount))

			Select @Max = MAX(Memberid) From S_DS_FullAccount 

			Set @Sql = ''''INSERT INTO S_DS_FullAccount 
			(memberid, Label, Description,Account_Memberid,Account) 
			Select a.ID + ''''+CAST(@MAX as char)+'''', a.Label, b.Description,b.Memberid,b.label   
			From #Account a, S_DS_''''+@AccountDim+''''  b
			Where a.Label = b.Label 
			And a.Label in (Select ParentLabel From #temp)
			And Not Exists (Select 1 From S_DS_Fullaccount F Where F.Label = a.Label) ''''
			Print(@Sql)
			Exec(@Sql) ' 

	
				SET @SQLStatement = @SQLStatement + '
	

			SET @Count = 1 
			Declare Dim_cursor cursor for 	SELECT b.Name FROM sysobjects a, Syscolumns b WHERE a.id = b.id AND a.Name=''''DS_FullAccount''''
			AND b.Name IN (SELECT Dimension FROM ModelAllDimensions WHERE Model = ''''Financials'''')
			open Dim_cursor
			fetch next from Dim_cursor into @DimLabel
			while @@FETCH_STATUS = 0
			begin
					SET @Sql = ''''Update S_DS_FullAccount SET ''''+@DimLabel +'''' = ''''''''None'''''''',''''+@DimLabel +''''_Memberid = -1 Where ''''+@DimLabel +'''' IS NULL  ''''
					EXEC(@Sql)
					Set @Count = @Count + 1  
				fetch next from Dim_cursor into @DimLabel
			end
			close Dim_cursor
			deallocate Dim_cursor


			INSERT INTO O_DS_FullAccount SELECT * FROM S_DS_FullAccount


			SET @Sql = ''''INSERT INTO [S_HS_FullAccount_''''+@Hierarchy+''''] 
			Select b.memberid, c.Memberid, a.SequenceNumber 
			From #temp a, [S_DS_FullAccount] b, [S_DS_FullAccount] c
			WHERE
			a.label = b.Account
			And a.PArentLabel = c.Account 
			UNION ALL
			select Distinct c.memberid,0, MIN(a.SequenceNumber) from #temp a, [S_DS_FullAccount] c
			Where a.ParentLabel not in (Select label from #temp)
			And a.ParentLabel = c.Account 
			group by c.memberid ''''
	--		Print(@sql)
			EXEC(@sql)	

			SET @Sql = ''''INSERT INTO [O_HS_FullAccount_''''+@Hierarchy+''''] Select * from [S_HS_FullAccount_''''+@Hierarchy+'''']''''
			Exec(@Sql) 

			--SET @Sql = ''''INSERT INTO [HS_FullAccount_''''+@Hierarchy+''''] Select * from [S_HS_FullAccount_''''+@Hierarchy+'''']''''
			--Exec(@Sql) 
		

			UPDATE S_Dimensions SET ChangeDatetime = GETDATE() WHERE Label = ''''FullAccount''''


	END
	SET @Lap =@Lap + 1
	END	


END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END
--   DROP TABLE #model,#ID,#Temp,#Hierarchy,#GroupH,#tempfull,#Account




/****** Object:  StoredProcedure [dbo].[Canvas_FullAccountData]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_FullAccountData'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_FullAccountData') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_FullAccountData]
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

/****** Script for SelectTopNRows command from SSMS  ******/
DECLARE @ScenarioID BIGINT
,@TimeID BIGINT
,@BusinessprocessID BIGINT
,@BusinessprocessMID BIGINT
,@Time  Nvarchar(255)
,@User Nvarchar(255)
,@ModelName Nvarchar(50)

DECLARE @DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max),@Lap INT,@Select Nvarchar(max)
declare @Found int,@Alldim Nvarchar(Max),@Sep Nvarchar(2)
Declare  @AccountDim Nvarchar(50),@ScenarioDim Nvarchar(50),@EntityDim Nvarchar(50),@BusinessProcessDim Nvarchar(50),@CurrencyDim Nvarchar(50)
,@TimeDim Nvarchar(50),@LineItemDim nvarchar(50),@VersionDim nvarchar(50)

-- SELECT * INTO #temp_parametervalues FROM DemoBudget_Epicor_New_1_3.dbo.temp_parametervalues
--Select @user = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''
--Select @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''

SET @user = ''''DSPanel''''
SET @ModelName = ''''Financials''''

	SET @Select = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0 ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Lap = 1 
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname+'''''''' And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''
		If @DimLabel = ''''LineItem'''' SET @DimType = ''''LineItem''''
		If @DimLabel = ''''Version'''' SET @DimType = ''''Version''''
		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+''''_Memberid]''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+''''_Memberid]''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Currency''''
		begin
			set @CurrencyDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+''''_Memberid]''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+''''_MemberId]''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''LineItem''''
		begin
			set @LineItemDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+''''_MemberId]''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Version''''
		begin
			set @VersionDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+''''_MemberId]''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		--if @Found = 0
		--begin
		--	set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
		--	--set @Select = @Select + '''' AND a.[''''+@DimLabel+''''_Memberid] = b.[''''+@DimLabel+''''] ''''
		--end
		--Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType

	end
	close Dim_cursor
	deallocate Dim_cursor ' 


			SET @SQLStatement = @SQLStatement + '
 

	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')

	SET @Lap = 1 
	Declare Dim_cursor cursor for 	SELECT b.Name FROM sysobjects a, Syscolumns b WHERE a.id = b.id AND a.Name=''''DS_FullAccount''''
	AND b.Name IN (SELECT Dimension FROM ModelAllDimensions WHERE Model = ''''Financials'''')
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel
	while @@FETCH_STATUS = 0
	begin

			SET @Select  = @Select + @Sep + RTRIM(@DimLabel)+''''_MemberId]''''
			Set @Lap = @Lap + 1  

		fetch next from Dim_cursor into @DimLabel
	end
	close Dim_cursor
	deallocate Dim_cursor

	Declare @TimeDataViewID BIGINT ' 


			SET @SQLStatement = @SQLStatement + '
 
    SELECT @TimeDataViewID = Memberid FROM DS_TimeDataView WHERE Label = ''''RAWDATA''''

	SET @Sql = ''''
	DELETE 
	FROM dbo.FACT_''''+@ModelName+''''_default_partition 
	Where [''''+@ScenarioDim+''''_Memberid] = -1 
	And [''''+@TimeDim+''''_Memberid] = -1 ''''
	Print(@Sql)
	EXEC(@Sql)

	SET @Sql = ''''INSERT INTO dbo.FACT_''''+@ModelName+''''_default_partition
	 (''''+@ModelName+''''_Value
	 , ChangeDatetime 
	 , Userid 
	 , TimeDataView_Memberid 
	 ,''''+ @AllDim 
	 + @Select+''''
	 )
		SELECT '''' + 
		+@ModelName+''''_Value = 1  
		,ChangeDatetime = GETDATE()
		,Userid = ''''''''''''+@User+'''''''''''' 
		,TimeDataView_Memberid = ''''+RTRIM(LTRIM(CAST(@TimeDataViewID AS char))) +''''
		,''''+Replace(@Alldim,'''']'''',''''] = -1'''')  + @Select +''''
		FROM [dbo].[DS_FullAccount]  ''''
	Print(@Sql)
	EXEC(@Sql)

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END





/****** Object:  StoredProcedure [dbo].[Canvas_FXTrans]    Script Date: 3/2/2017 11:34:03 AM ******/
IF 1 = 0 BEGIN
SET @Step = 'Create Canvas_FXTrans'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_FXTrans') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
 PROCEDURE  [dbo].[Canvas_FXTrans]
@Type Nvarchar(20) = ''''Multiply''''
,@BaseCurrency Nvarchar(20) = ''''USD''''
,@CopyCYNI BIT = 0
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN


if not exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = ''''FACT_FxRate_default_partition'''' and xtype = ''''U'''')  RETURN

IF @BaseCurrency IS NULL Select @BaseCurrency = Basecurrency from FACT_FXRate_View Where entity = ''''None''''


--========================================================
--========================================================
--========================================================
--Declare @BaseCurrency Nvarchar(255), @Type Nvarchar(20),@CopyCYNI BIT
--SET @BaseCurrency = ''''USD''''
--SET @Type = ''''Multiply''''
--SET @CopyCYNI = 0
--========================================================
--========================================================
--========================================================

-- drop table  #temp_parametervalues 
-- Select * into  #temp_parametervalues  from  temp_parametervalues 
/****** Script for SelectTopNRows command from SSMS  ******/

DECLARE @ScenarioID BIGINT
,@TimeID BIGINT
,@BusinessprocessID BIGINT
,@CurrencyID BIGINT
,@BusinessprocessInputID BIGINT,@BusinessprocessMemberid BIGINT
,@Time  Nvarchar(255)
,@User Nvarchar(255)
,@ModelName Nvarchar(50)
,@Sign Nvarchar(1)
,@NBReporting INT



SET @Sign = ''''*''''
IF @Type = ''''Divide'''' SET @Sign = ''''/''''

DECLARE @DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max),@Sql2 Nvarchar(Max),@Lap INT,@Params Nvarchar(max),@Select Nvarchar(max)
declare @Found int,@Alldim Nvarchar(Max),@Otherdim Nvarchar(Max),@Sep Nvarchar(2)
Declare  @AccountDim Nvarchar(50),@ScenarioDim Nvarchar(50),@EntityDim Nvarchar(50),@BusinessProcessDim Nvarchar(50),@CurrencyDim Nvarchar(50)
,@TimeDim Nvarchar(50),@LineItemDim nvarchar(50),@VersionDim nvarchar(50),@Where Nvarchar(max),@Group Nvarchar(max),@Alldim2 Nvarchar(Max)

Select @user = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''
Select @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''

--=================================================================================
--=================================================================================
--=================================================================================
Declare @proc_ID bigint,@UserId Bigint
SELECT @Proc_ID = MAX(Proc_Id) FROM Canvas_User_Run_Status
IF @Proc_ID IS NULL  SET @Proc_ID = 0
SET @Proc_ID = @Proc_Id + 1

Select @Userid =  UserId from Canvas_Users Where label = @user
IF @@Rowcount =  0 Select @Userid =  UserId from Canvas_Users Where winuser = @user
IF @@ROWCOUNT = 0 SET @userId = 0

INSERT INTO Canvas_User_Run_Status 
([User_RecordId],[User],[Proc_Id],[Proc_Name],[Begin_Date],[End_Date])
VALUES (@Userid,@User,@Proc_Id,''''FxTrans'''',GETDATE(),'''''''') 
--=================================================================================
--=================================================================================
--=================================================================================


	SET @Where = ''''''''
	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0 ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Lap = 1 
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname+'''''''' And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''
		If @DimLabel = ''''LineItem'''' SET @DimType = ''''LineItem''''
		If @DimLabel = ''''Version'''' SET @DimType = ''''Version''''
		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1
		end  
		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Currency''''
		begin
			set @CurrencyDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''LineItem''''
		begin
			set @LineItemDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Version''''
		begin
			set @VersionDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
			set @Where = @Where + '''' AND a.[''''+@DimLabel+''''_Memberid] = b.[''''+@DimLabel+''''] ''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType
	end
	close Dim_cursor
	deallocate Dim_cursor 

	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')

	Set @Alldim = @Alldim + '''',[TimeDataView] ''''

--select @ScenarioID = Memberid From #temp_parametervalues Where parameterName = ''''ScenarioMbrs''''
	set @Params = ''''@ScenarioIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @ScenarioIDOUT=[MemberId] from [#temp_parametervalues] where [parameterName]=''''''''ScenarioMbrs''''''''''''
	exec sp_executesql @sql, @Params, @ScenarioIDOUT=@Scenarioid OUTPUT

--	Select @BusinessprocessID = Memberid From Ds_BusinessProcess Where Label = ''''BR_AS''''
	set @Params = ''''@BusinessprocessIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessIDOUT=[MemberId] from [S_DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''Input_Conv''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessIDOUT=@BusinessprocessID OUTPUT ' 


			SET @SQLStatement = @SQLStatement + '


--	Select @BusinessprocessID = Memberid From Ds_BusinessProcess Where Label = ''''Input
	set @Params = ''''@BusinessprocessInputIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessInputIDOUT=[MemberId] from [S_DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''Input''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessInputIDOUT=@BusinessprocessInputID OUTPUT

	set @Params = ''''@currencyIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @CurrencyIDOUT=[MemberId] from [S_DS_''''+@CurrencyDim+''''] where [Label] = ''''''''''''+@BaseCurrency+''''''''''''''''
	exec sp_executesql @sql, @Params, @CurrencyIDOUT=@CurrencyID OUTPUT
	
	Create table #Currency (Currency_Memberid BIGINT , Currency nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	SET @Sql = ''''INSERT Into #Currency Select memberid,Label From S_DS_''''+@CurrencyDim+'''' Where Reporting = 1''''
	EXEC(@Sql)
	SET @NbReporting = @@Rowcount

	DECLARE @TimeRateDim Nvarchar(50)

	select @TimeRateDim = A.[Dimension] 
	From [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	Where A.[Model] = ''''Fxrate'''' And b.[Type] = ''''Time''''

--==============================================> Debut StartPeriod
Create Table #Rate (
Is_CTA INT
,Reporting_Currency_memberid Bigint
,Rate_memberid Bigint
,scenario_memberid Bigint
,time_memberid Bigint
,Currency_memberid Bigint
,Value Float)

--Select * into #Rate2 from #rate

Create table #TimeCYNI  (SourceTime_memberid BIGINT,SourceTime_label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
Time_memberid BIGINT,Time_label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

Create table #Timeparam (Time_memberid BIGINT,Time_label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

Set @sql = ''''INSERT INTo #Timeparam 
Select Distinct a.memberid,a.label
From S_DS_''''+@TimeDim+'''' a, S_DS_''''+@TimeDim+'''' b
where 
b.memberid in (Select memberid from #temp_parametervalues where parametername = ''''''''TimeMbrs'''''''')
And a.TimeFiscalyear_MemberId=b.TimeFiscalyear_MemberId
And len(a.label)= 6 and substring(a.label,5,1) in (''''''''0'''''''',''''''''1'''''''')''''
print(@Sql)
Exec(@Sql)

INSERT INTo #TimeCYNI 
Select a.time_memberid,A.time_label,b.time_memberid, b.time_label
From #Timeparam a, #Timeparam b
Where a.time_label < b.time_label
Order by 4 ' 


			SET @SQLStatement = @SQLStatement + '


CREATE TABLE #Time (
 Time_label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
,Time_memberid BIGINT
,Lastyear_label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
,lastyear_memberid BIGINT
,Timerate_label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
,Timerate_memberid BIGINT
,Previous_label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
,Previous_memberid BIGINT
)

Set @sql = ''''Insert into #Time 
Select Distinct a.Time_Label,a.Time_memberid, '''''''''''''''', 0 , c.label, c.memberid,0,''''''''''''''''
From #timeParam a, S_Ds_''''+@TimeRateDim+'''' c   
where 
	LEFT(c.label,6) = LEFT(a.Time_label,6)''''
Print(@Sql)
Exec(@Sql)

Update #time Set Lastyear_label = ((Left(Time_label,4) - 1) * 100) + 12 
Set @Sql = ''''Update #time Set Lastyear_memberid = b.memberid from #time a, S_DS_''''+@TimeDim+'''' b 
Where a.Lastyear_label = b.label ''''
EXEC(@Sql)

Update #time Set Previous_label = Time_label - 1 
Set @Sql = ''''Update #time Set previous_memberid = b.memberid from #time a, S_DS_''''+@TimeDim+'''' b 
Where a.previous_label = b.label ''''
EXEC(@Sql)


DECLARE @BPConvProperty Smallint
SET @BPConvProperty = 0 ' 


			SET @SQLStatement = @SQLStatement + '


Create table #temp (Name nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
Insert into #temp select Dimension From ModelDimensions 
where model = @ModelName and Dimension = ''''BusinessRule''''
IF @@ROWCOUNT = 1 
BEGIN
	SET @BPConvProperty = 2
END
ELSE
BEGIN
	Truncate table  #temp
	Set @sql = ''''Insert into #temp select b.name 
	From sysobjects a,syscolumns b 
	where a.id = b.id and a.name = ''''''''S_DS_''''+@BusinessProcessDim+''''''''''''
	And b.Name = ''''''''BP_Converted''''''''''''
	EXEC(@Sql)
IF @@ROWCOUNT = 1 SET @BPConvProperty = 1
END

 ' 


			SET @SQLStatement = @SQLStatement + '

Create table #BP (memberid BIGINT, Source_memberid BIGINT)
IF @BPConvProperty = 1
BEGIN
	Set @Sql = ''''Insert into #BP Select BP_Converted_Memberid , memberid 
	from S_DS_''''+@BusinessProcessDim+'''' 
	Where (NoAutoFx = 0 OR NoAutoFx IS NULL)
	And memberid not in (Select parentid from HC_''''+@businessprocessdim+'''' Where Memberid <> parentid)
	And memberid <> BP_Converted_Memberid
	And BP_Converted_Memberid > 0 ''''
END
IF @BPConvProperty = 0
BEGIN
	Set @Sql = ''''Insert into #BP Select ''''+RTRIM(LTRIM(CAST(@BusinessprocessID as char)))+'''',Memberid   
	from S_DS_''''+@BusinessProcessDim+'''' 
	Where (NoAutoFx = 0 OR NoAutoFx IS NULL)
	And memberid not in (Select parentid from HC_''''+@businessprocessdim+'''' Where Memberid <> parentid)''''
END
IF @BPConvProperty = 2
BEGIN
	Set @Sql = ''''Insert into #BP Select memberid ,memberid 
	from S_DS_''''+@BusinessProcessDim+'''' 
	Where (NoAutoFx = 0 OR NoAutoFx IS NULL)
	And memberid not in (Select parentid from HC_''''+@businessprocessdim+'''' Where Memberid <> parentid)''''
END
Print(@Sql)
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '

--======================================> Normal rate

SET @Sql = ''''INsert into #rate
Select 0,''''+RTRIM(LTRIM(CAST(@CurrencyID as char)))+'''', rate_Memberid,''''+@ScenarioDim+''''_memberid,b.Time_memberid,''''+@CurrencyDim+''''_memberid,Fxrate_Value
from FACT_fxrate_Default_Partition a, #Time b
Where 
	b.[Time_Memberid] in (Select timerate_Memberid from #time) 
and	a.''''+@TimeRateDim+''''_memberid = b.Timerate_memberid
And a.[''''+@ScenarioDim+''''_Memberid] in (Select Memberid from #temp_Parametervalues where parametername = ''''''''ScenarioMbrs'''''''') 
--And a.[Rounds_Memberid] in (Select Memberid from #temp_Parametervalues where parametername = ''''''''RoundsMbrs'''''''') 
And a.''''+@EntityDim+''''_memberid = -1''''
Print(@Sql)
EXEC(@Sql)


--> history
SET @Sql = ''''INsert into #rate
Select 1,a.reporting_currency_memberid, 4 as rate_Memberid,a.scenario_memberid,a.time_memberid,a.Currency_memberid,a.Value
from #rate a
Where 
a.rate_memberid IN (Select memberid from ds_rate where label = ''''''''EOP'''''''') ''''
Print(@Sql)
EXEC(@Sql)

--> CYNI
SET @Sql = ''''INsert into #rate
Select 4,a.reporting_currency_memberid, b.Memberid,a.scenario_memberid,a.time_memberid,a.Currency_memberid,a.Value
from #rate a, S_DS_rate b
Where 
a.rate_memberid IN (Select memberid from S_ds_rate where label = ''''''''Average'''''''') 
And b.label = ''''''''CYNI'''''''' ''''
--Print(@Sql)
EXEC(@Sql)

SET @Sql = ''''INsert into #rate
Select 3,a.reporting_currency_memberid, b.Memberid,a.scenario_memberid,a.time_memberid,a.Currency_memberid,a.Value
from #rate a, S_DS_rate b
Where 
a.rate_memberid IN (Select memberid from S_ds_rate where label = ''''''''EOP'''''''') 
And b.label = ''''''''CYNI'''''''' ''''
--Print(@Sql)
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


--======================================> je prend Begining_ EOP et Average 
SET @Sql = ''''INsert into #rate
Select 
Is_CTA 
,Reporting_Currency_memberid 
,Rate_memberid 
,scenario_memberid 
,time_memberid 
,Currency_memberid 
,value From (
--,SUM(Value) as value From (
Select 
is_CTA = 0
,Reporting_Currency_memberid = ''''+RTRIM(LTRIM(CAST(@CurrencyID as char)))+''''
,Rate_memberid = c.Memberid
,scenario_memberid = a.''''+@ScenarioDim+''''_memberid
,Time_memberid = t.time_memberid
,Currency_memberid = a.''''+@CurrencyDim+''''_memberid
,Value = a.Fxrate_Value
from FACT_fxrate_Default_Partition a, S_DS_Rate b, S_DS_Rate c, #time t
Where 
a.[''''+@TimeRateDim+''''_Memberid] = t.lastyear_memberid
And a.[''''+@ScenarioDim+''''_Memberid] in (Select Memberid from #temp_Parametervalues where parametername = ''''''''ScenarioMbrs'''''''') 
--And a.[Rounds_Memberid] in (Select Memberid from #temp_Parametervalues where parametername = ''''''''RoundsMbrs'''''''') 
And a.Rate_memberid = b.Memberid
And ''''''''Begining_''''''''+b.label = c.Label
And a.''''+@EntityDim+''''_memberid = -1
UNION ALL '''' ' 


			SET @SQLStatement = @SQLStatement + '

--======================================> je prend Begining_ EOP et Average en moins pour CTA
Set @Sql =@Sql + '''' 
Select 
is_CTA = -1
,Reporting_Currency_memberid = ''''+RTRIM(LTRIM(CAST(@CurrencyID as char)))+''''
,Rate_memberid = c.Memberid
,scenario_memberid = a.''''+@ScenarioDim+''''_memberid
,Time_memberid = t.time_memberid
,Currency_memberid = a.''''+@CurrencyDim+''''_memberid
,value = a.Fxrate_Value*-1
from FACT_fxrate_Default_Partition a, S_DS_Rate b, S_DS_Rate c, #time t
Where 
a.[''''+@TimeRateDim+''''_Memberid] = t.lastyear_memberid
And a.[''''+@ScenarioDim+''''_Memberid] in (Select Memberid from #temp_Parametervalues where parametername = ''''''''ScenarioMbrs'''''''') 
--And a.[Rounds_Memberid] in (Select Memberid from #temp_Parametervalues where parametername = ''''''''RoundsMbrs'''''''') 
And a.rate_memberid = b.Memberid
And ''''''''Begining_''''''''+b.label = c.Label
And a.''''+@EntityDim+''''_memberid = -1
UNION ALL '''' ' 


			SET @SQLStatement = @SQLStatement + '

--======================================> je prend EOP et Average pour CTA
SET @Sql = @Sql + ''''
Select 
is_CTA = 1,
Reporting_currency_memberid = ''''+RTRIM(LTRIM(CAST(@CurrencyID as char)))+''''
,rate_memberid  = c.Memberid
,Scenario_memberid  = a.''''+@ScenarioDim+''''_memberid
,time_memberid  = t.Time_memberid
,currency_memberid = a.''''+@CurrencyDim+''''_memberid
,value = a.Fxrate_Value
from FACT_fxrate_Default_Partition a, S_DS_Rate b, S_DS_Rate c, #time t
Where 
t.[Timerate_Memberid] in (Select Memberid from #temp_Parametervalues where parametername = ''''''''''''+@TimeDim+''''Mbrs'''''''') 
and a.[''''+@TimerateDim+''''_Memberid] = t.Timerate_memberid
And a.[''''+@ScenarioDim+''''_Memberid] in (Select Memberid from #temp_Parametervalues where parametername = ''''''''ScenarioMbrs'''''''') 
--And a.[Rounds_Memberid] in (Select Memberid from #temp_Parametervalues where parametername = ''''''''RoundsMbrs'''''''') 
And a.''''+@EntityDim+''''_memberid = -1 
And Substring(c.Label,10,20) = b.Label
And a.rate_memberid = b.memberid 
) As Tmp ''''
Print(@Sql)
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '

-- mettre EOP en +  

IF @NbReporting > 1
BEGIN
	SET @Sql = ''''INSERT INTO #rate 
	select a.is_CTA,b.Currency_Memberid, a.rate_memberid, a.scenario_memberid,a.time_memberid,a.currency_memberid''''
	IF @Type = ''''Divide'''' SET @Sql = @Sql + '''',CASE a.is_CTA WHEN 2 then a.Value/ c.Value * -1 WHEN -1 then a.Value/ c.Value * -1 ELSE a.Value/ c.Value  END  ''''
	IF @Type = ''''Multiply''''   SET @Sql = @Sql + '''',c.Value/ a.Value  ''''
	--IF @Type = ''''Multiply'''' SET @Sql = @Sql + '''', CASE c.Value WHEN 0 THEN 0 ELSE a.Value/ c.Value END ''''
	--IF @Type = ''''Divide''''   SET @Sql = @Sql + '''', CASE a.Value WHEN 0 THEN 0 ELSE c.Value/ a.Value END ''''
	SET @Sql = @Sql + ''''
	from #rate a, #Currency b, #Rate c
	Where b.Currency <> ''''''''''''+@BaseCurrency+'''''''''''' 
	And a.rate_memberid = c.rate_memberid
	And a.Scenario_memberid = c.Scenario_memberid
	And a.Time_memberid = c.Time_memberid
	And c.Currency_memberid = b.Currency_memberid 
	and a.is_CTA = c.Is_CTA ''''
	if @Type = ''''Divide'''' Set @sql = @sql + '''' And c.Value <> 0 ''''
	if @Type = ''''multiply'''' Set @sql = @sql + '''' And a.Value <> 0 ''''
	--Print(@Sql)
	EXEC(@Sql)
END ' 


			SET @SQLStatement = @SQLStatement + '



--	Update #rate set value = value * -1 where is_cta = 2


	DECLARE @Count INT
	SELECT @Count = COUNT(*) FROM s_ds_account WHERE LEFT([Account type],8) = ''''LastYear''''

	--PRINT CAST(@count AS CHAR)
	--return

	Create Table #Fact(Is_CTA INT,BusinessRule_Value Float,fxrate Float,Value Float)
	Set @Sql = ''''ALTER TABLE #Fact ADD ''''+REPLACE(@Alldim,'''']'''',''''_Memberid] BIGINT'''')+'''',AccountType nvarchar(50), CTA_Account_Memberid BIGINT ''''
	--print (@sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '



	IF @BPConvProperty = 2
	BEGIN
		DECLARE @ID BIGINT
		Create table #tempI (memberid BIGINT)
		SET @Sql = ''''INSERT INTO #tempI Select Memberid from S_DS_BusinessRule Where Label = ''''''''Conversion'''''''' ''''
		EXEC(@Sql)
		Select @ID = Memberid from #TempI  
		SET @Alldim2 = REPLACE(@Alldim2,''''a.[BusinessRule_memberid]'''',LTRIM(RTRIM(CAST(@ID as char))))
	END

	IF @BPConvProperty = 0
	BEGIN
	SET @Sql = '''' Delete from FACT_''''+@ModelName+''''_default_partition 
	From FACT_''''+@ModelName+''''_default_partition a, S_DS_entity b 
	where 
	a.''''+@entityDim+''''_memberid = b.memberid 
	and a.''''+@CurrencyDim+''''_memberid <> b.Currency_MemberId
	And a.[''''+@ScenarioDim+''''_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''ScenarioMbrs'''''''')
	And a.[''''+@TimeDim+''''_Memberid] In (Select Time_Memberid from #Timeparam)
	And a.[''''+@EntityDim+''''_Memberid] in (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''EntityMbrs'''''''') 
	And [''''+@AccountDim+''''_memberid] not in (select memberid from [s_DS_''''+@AccountDim+''''] where rate = ''''''''History'''''''')''''
	END
	ELSE
	BEGIn
		SET @Sql = ''''DELETE FROM [FACT_''''+@ModelName+''''_Default_Partition]
		Where [''''+@ScenarioDim+''''_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''ScenarioMbrs'''''''')
		And  [''''+@TimeDim+''''_Memberid] In (Select Time_Memberid from #Timeparam)
		And   [''''+@EntityDim+''''_Memberid] in (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''EntityMbrs'''''''') ''''
		IF @BPConvProperty = 2 SET @Sql = @sql + '''' And BusinessRule_memberid = ''''+LTRIM(RTRIM(CAST(@ID as char)))
		IF @BPConvProperty = 1 SET @Sql = @sql + ''''And [''''+@BusinessprocessDim+''''_Memberid] IN (Select memberid from #BP) ''''
	END
	Print(@Sql)
	EXEC(@Sql)
	
	SET @Alldim2 = REPLACE(@Alldim,'''']'''',''''_Memberid]'''')
	SET @Alldim2 = REPLACE(@Alldim2,''''['''',''''a.['''')
	IF @BPConvProperty = 0 SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@BusinessProcessDim+''''_memberid]'''',@BusinessprocessID)
	IF @BPConvProperty = 2 SET @Alldim2 = REPLACE(@Alldim2,''''a.[BusinessRule_memberid]'''',LTRIM(RTRIM(CAST(@ID as char))))
	SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@BusinessProcessDim+''''_memberid]'''',''''Bp.[memberid]'''')
	SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@CurrencyDim+''''_memberid]'''',''''b.[Reporting_Currency_memberid]'''') ' 

	
				SET @SQLStatement = @SQLStatement + '
	

	SET @Sql = ''''INSERT INTO #Fact 
	Select b.is_cta,a.[''''+@ModelName+''''_Value],b.[Value],a.[''''+@ModelName+''''_Value] ''''+@sign+'''' b.[Value]
	,''''+@Alldim2 +'''',c.[Account Type],c.CTA_Account_memberid
	From [Fact_''''+@ModelName+''''_Default_Partition] a, #Rate b, S_DS_''''+@AccountDim+'''' c, S_DS_''''+@EntityDim+'''' e, #BP bp 
	Where 
	b.Value <> 0
	--And a.[Rounds_Memberid] in (Select Memberid from #temp_Parametervalues where parametername = ''''''''RoundsMbrs'''''''') 
	And a.[''''+@ScenarioDim+''''_Memberid] = b.Scenario_memberid
	And a.[''''+@CurrencyDim+''''_Memberid] = b.currency_memberid
	And a.[''''+@CurrencyDim+''''_Memberid] <> b.reporting_currency_Memberid
	And a.[''''+@AccountDim+''''_Memberid] = c.memberid
	And a.[''''+@EntityDim+''''_Memberid] = e.memberid 
	And c.Rate_Memberid = b.Rate_Memberid
	And a.[''''+@TimeDim+''''_Memberid] = b.Time_memberid 
	And a.[''''+@EntityDim+''''_Memberid] in (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''EntityMbrs'''''''')  ''''
	IF @BPConvProperty = 2 SET @Sql = @Sql + '''' And a.BusinessRule_Memberid <> ''''+LTRIM(RTRIM(CAST(@ID as char)))   ' 

	
				SET @SQLStatement = @SQLStatement + '
	
	IF @BPConvProperty = 0 
	begin
		SET @Sql = @sql + '''' And a.[''''+@BusinessProcessDim+''''_memberid] = ''''+LTRIM(CAST(@BusinessprocessInputID as char))
	end
	Else
	begin
		SET @Sql = @sql + '''' And a.[''''+@BusinessProcessDim+''''_memberid] = BP.Source_memberid '''' 
	end
	Print(@Sql)
	EXEC(@Sql) ' 



			SET @SQLStatement = @SQLStatement + '


----================================================================> Extract Previous Period for CYNI

	SET @Alldim2 = REPLACE(@Alldim,'''']'''',''''_Memberid]'''')
	SET @Alldim2 = REPLACE(@Alldim2,''''['''',''''a.['''')
	SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@TimeDim+''''_Memberid]'''',''''t.[Time_Memberid]'''')
	IF @BPConvProperty = 0 SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@BusinessProcessDim+''''_memberid]'''',@BusinessprocessID)
	IF @BPConvProperty = 2 SET @Alldim2 = REPLACE(@Alldim2,''''a.[BusinessRule_memberid]'''',LTRIM(RTRIM(CAST(@ID as char))))
	SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@BusinessProcessDim+''''_memberid]'''',''''Bp.[memberid]'''')
	SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@CurrencyDim+''''_memberid]'''',''''b.[Reporting_Currency_memberid]'''')

	SET @Sql = ''''INSERT INTO #Fact 
	Select -4,a.[''''+@ModelName+''''_Value],b.[Value],a.[''''+@ModelName+''''_Value] ''''+@sign+'''' b.[Value]*-1
	,''''+@Alldim2 +'''',c.[Account Type],c.CTA_Account_memberid
	From [Fact_''''+@ModelName+''''_Default_Partition] a, #Rate b, S_DS_''''+@AccountDim+'''' c, S_DS_''''+@EntityDim+'''' e, #BP bp, #time t 
	Where 
	b.Value <> 0 and is_CTA = 4
	--And a.[Rounds_Memberid] in (Select Memberid from #temp_Parametervalues where parametername = ''''''''RoundsMbrs'''''''') 
	And a.[''''+@ScenarioDim+''''_Memberid] = b.Scenario_memberid
	And a.[''''+@CurrencyDim+''''_Memberid] = b.currency_memberid
	And a.[''''+@CurrencyDim+''''_Memberid] <> b.reporting_currency_Memberid
	And a.[''''+@AccountDim+''''_Memberid] = c.memberid
	And a.[''''+@EntityDim+''''_Memberid] = e.memberid 
	And c.Rate_Memberid = b.Rate_Memberid
	And b.[Time_Memberid] = t.Time_memberid 
	And a.[''''+@TimeDim+''''_Memberid] = t.previous_memberid 
	And a.[''''+@EntityDim+''''_Memberid] in (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''EntityMbrs'''''''')  ''''
	IF @BPConvProperty = 2 SET @Sql = @Sql + '''' And a.BusinessRule_Memberid <> ''''+LTRIM(RTRIM(CAST(@ID as char)))   ' 

	
				SET @SQLStatement = @SQLStatement + '
	
	IF @BPConvProperty = 0 
	begin
		SET @Sql = @sql + '''' And a.[''''+@BusinessProcessDim+''''_memberid] = ''''+LTRIM(CAST(@BusinessprocessInputID as char))
	end
	Else
	begin
		SET @Sql = @sql + '''' And a.[''''+@BusinessProcessDim+''''_memberid] = BP.Source_memberid '''' 
	end
	Print(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


----================================================================> FIN Extract Previous Period for CYNI
	-- CYNI

	Set @sql = ''''Update #Fact set ''''+@AccountDim+''''_memberid = CTA_Account_memberid Where is_CTA in (1,2,3) ''''
	Exec(@Sql)


	SET @Alldim2 = REPLACE(@Alldim,'''']'''',''''_Memberid]'''')
	SET @Alldim2 = REPLACE(@Alldim2,''''['''',''''a.['''')
	SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@TimeDim+''''_memberid]'''', ''''t.Time_memberid'''')
	
	SET @Sql = ''''INSERT INTO #Fact 
	Select 44,a.BusinessRule_Value,a.fxrate,a.Value
	,''''+@Alldim2 +'''',a.[AccountType],a.CTA_Account_memberid
	From #Fact a, #timeCYNI t
	Where 
	a.Value <> 0 
	AND a.Is_CTA in (4,-4)
	And a.[''''+@TimeDim+''''_Memberid] = t.SourceTime_memberid ''''
	Print(@Sql)
	EXEC(@Sql)


	SET @Alldim2 = REPLACE(@Alldim,'''']'''',''''_Memberid]'''')
	SET @Alldim2 = REPLACE(@Alldim2,''''['''',''''a.['''')
	SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@AccountDim+''''_memberid]'''', ''''a.CTA_Account_memberid'''')

	SET @Sql = ''''INSERT INTO #Fact 
	Select -3,a.BusinessRule_Value,a.fxrate,a.Value*-1
	,''''+@Alldim2 +'''',a.[AccountType],a.CTA_Account_memberid
	From #Fact a
	Where 
	a.Value <> 0 
	AND a.Is_CTA in (4,-4,44) ''''
	Print(@Sql)
	EXEC(@Sql)
	

	-- FOR HISTORY
	SET @Alldim2 = REPLACE(@Alldim,'''']'''',''''_Memberid]'''')
	SET @Alldim2 = REPLACE(@Alldim2,''''['''',''''a.['''')
	--SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@BusinessProcessDim+''''_memberid]'''',''''Bp.[memberid]'''')
	SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@AccountDim+''''_memberid]'''',''''c.CTA_Account_memberid'''')
	IF @BPConvProperty = 0 SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@BusinessProcessDim+''''_memberid]'''',@BusinessprocessID)
	IF @BPConvProperty = 2 SET @Alldim2 = REPLACE(@Alldim2,''''a.[BusinessRule_memberid]'''',LTRIM(RTRIM(CAST(@ID as char)))) ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''INSERT INTO #Fact 
	Select 1,1,1,a.[''''+@ModelName+''''_Value] *-1,
	''''+@Alldim2 +'''',c.[Account Type],0
	From [Fact_''''+@ModelName+''''_Default_Partition] a , S_DS_''''+@AccountDim+'''' c, S_DS_''''+@EntityDim+'''' e, #Bp Bp
	Where 
	[''''+@ScenarioDim+''''_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''ScenarioMbrs'''''''')
	And   [''''+@TimeDim+''''_Memberid] In (Select Time_Memberid from #Time)
	And [''''+@EntityDim+''''_Memberid] in (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''EntityMbrs'''''''') 
	And a.[''''+@EntityDim+''''_Memberid] = e.memberid
	and a.[''''+@currencyDim+''''_memberid] <> e.currency_memberid
	And a.[''''+@AccountDim+''''_Memberid] = c.memberid
	And c.rate = ''''''''History''''''''
	and a.currency_memberid in (select memberid from ds_currency where reporting = 1)''''
--	IF @BPConvProperty = 2 SET @Sql = @Sql + '''' And a.BusinessRule_Memberid <> ''''+LTRIM(RTRIM(CAST(@ID as char)))  
	IF @BPConvProperty = 0 
	begin
		SET @Sql = @sql + '''' And a.[''''+@BusinessProcessDim+''''_memberid] = ''''+LTRIM(CAST(@BusinessprocessInputID as char))
	end
	Else
	begin
		SET @Sql = @sql + '''' And a.[''''+@BusinessProcessDim+''''_memberid] = BP.Source_memberid '''' 
	end
	Print(@Sql)
	EXEC(@Sql)

	SET @Alldim2 = REPLACE(@Alldim,'''']'''',''''_Memberid]'''')
	SET @Alldim2 = REPLACE(@Alldim2,''''['''',''''a.['''')
	SET @Alldim2 = REPLACE(@Alldim2,''''a.[''''+@AccountDim+''''_memberid]'''',''''b.[memberid]'''')


	SET @Sql = ''''INSERT INTO [FACT_''''+@ModelName+''''_Default_Partition]
	(''''+REPLACE(@AllDim,'''']'''',''''_Memberid]'''')+'''',[''''+@ModelName+''''_Value],USerid,ChangeDateTime)
	SELECT ''''+REPLACE(@AllDim,'''']'''',''''_Memberid]'''')+'''',SUM(Value),''''''''''''+@User+'''''''''''',GETDATE()
	FROM #Fact 
	Where 
	Value <> 0 
	Group By ''''+REPLACE(@AllDim,'''']'''',''''_Memberid]'''')
	--Print (@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


	if @CopyCYNI = 1 
	BEGIN
		if not exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = ''''Wrk_ETL_Values'''' and xtype = ''''U'''')  
		BEGIN
			CREATE TABLE [dbo].[Wrk_ETL_Values](
			[ParameterName] [nvarchar](255) NULL,
			[MemberId] [bigint] NULL,
			[StringValue] [nvarchar](512) NULL,
			[Proc_Name] [nvarchar](512) NULL
			) ON [PRIMARY]	
		END
		Truncate table Wrk_ETL_Values
		Insert Into Wrk_ETL_Values Select *,''''Canvas_Copy_CYNI'''' From #Temp_ParameterValues
		Exec [Canvas_Copy_CYNI] 1
	END

	UPDATE Canvas_User_Run_Status SET END_Date = GETDATE() WHERE Proc_Id = @Proc_Id

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END
-- Drop  table #time,#Fact,#Rate,#TempRate,#currency,#rate2,#BP,#temp,#tempI

/*

 Drop  table #time,#Fact,#Rate,#TempRate,#currency,#rate2,#BP,#temp,#tempI,#timeparam,#timecyni

*/

END --End of test for creating Canvas_FxTrans

/****** Object:  StoredProcedure [dbo].[Canvas_ICEliminations]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_ICEliminations'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_ICEliminations') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_ICEliminations]
	@FilterMbrs nvarchar(2048) = '''''''',
	@ScenarioMbrs as nvarchar(255) = ''''ScenarioMbrs'''',
	@TimeMbrs as nvarchar(255) = ''''TimeMbrs'''',
	@BR as Bit = 1
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS


BEGIN


--DECLARE	@FilterMbrs nvarchar(2048),
--	@ScenarioMbrs as nvarchar(255),
--	@TimeMbrs as nvarchar(255),
--	@BR as Bit = 1
--SET @FilterMbrs =''''''''
--SET @ScenarioMbrs = ''''ScenarioMbrs''''
--SET @TimeMbrs =''''TimeMbrs''''
--SET	@BR = 1


-- retrieve parameters passed in
-- uncomment following for production
declare @TempTbl nvarchar(25)
declare @Model nvarchar(50)
declare @Userid nvarchar(255)
set @TempTbl = ''''#Temp_ParameterValues''''
set @Model = (select [StringValue] from [#Temp_ParameterValues] where [ParameterName]=''''Model'''')
set @Userid = (select [StringValue] from [#Temp_ParameterValues] where [ParameterName]=''''Userid'''')

-- uncomment following for dev work
--declare @TempTbl nvarchar(25)
--declare @FilterMbrs nvarchar(2048)
--declare @Model nvarchar(50)
--declare @Userid nvarchar(255)
--declare @ScenarioMbrs as nvarchar(255)
--set @FilterMbrs = ''''''''
--set @ScenarioMbrs = ''''ScenarioMbrs''''
--declare @TimeMbrs as nvarchar(255)
--set @TimeMbrs = ''''TimeMbrs''''
--set @TempTbl = ''''#Temp_ParameterValues''''
--set @Model = (select [StringValue] from [#Temp_ParameterValues] where [ParameterName]=''''Model'''')
--BEGIN


-- select * into #temp_parametervalues from temp_parametervalues


if @Userid is null
	set @Userid = ''''''''
if @Model is null
begin
	Raiserror(''''Missing Model name'''', 18, 1)
	return
end
	
declare @AccountDim nvarchar(50)
declare @RoundDim nvarchar(50)
declare @BRuleDim nvarchar(50)
declare @ScenarioDim nvarchar(50)
declare @EntityDim nvarchar(50)
declare @IntercompanyDim nvarchar(50)
declare @BusinessProcessDim nvarchar(50)
declare @BusinessRuleDim nvarchar(50)
declare @TimeDim nvarchar(50)
declare @CurrencyDim nvarchar(50)

declare @IsRound Bit
declare @IsBRule Bit

declare @DimLabel nvarchar(50)
declare @DimType nvarchar(50)
declare @BPElimMbrId nvarchar(20)
declare @EntityHierTbl nvarchar(50)
declare @OtherDimQry nvarchar(max)
declare @OtherDimInsert nvarchar(max)
declare @Found int
declare @Valid int
declare @Stmt as nvarchar(max)
declare @Params nvarchar(max) ' 

			SET @SQLStatement = @SQLStatement + '



Set @IsRound = 0
Set @IsBRule = 0

set @OtherDimQry = ''''''''
set @OtherDimInsert = ''''''''
set @Valid = 0

-- retrieve dimension names
declare Dim_cursor cursor for 
select A.[Dimension],B.[Type] from [ModelDimensions] as A 
left join [Dimensions] as B on A.[Dimension]=B.[Label] 
where A.[Model] = @Model

open Dim_cursor
fetch next from Dim_cursor into @DimLabel,@DimType
while @@FETCH_STATUS = 0
begin
	set @Found = 0
	if @DimType = ''''Scenario''''
	begin
		set @ScenarioDim = @DimLabel
		set @Found = 1
	end
	if @DimType = ''''Round''''
	begin
		set @RoundDim = @DimLabel
		set @Found = 1
		Set @IsRound = 1
	end
	if @DimType = ''''BusinessRule''''
	begin
		set @BusinessRuleDim = @DimLabel
		set @Found = 1
		Set @IsBRule = 1
	end
	if @DimType = ''''Account''''
	begin
		set @AccountDim = @DimLabel
		set @Found = 1
	end
	if @DimType = ''''Entity''''
	begin
		set @EntityDim = @DimLabel
		set @Found = 1
	end
	if @DimType = ''''Intercompany''''
	begin
		set @IntercompanyDim = @DimLabel
		set @Found = 1
	end
	if @DimType = ''''BusinessProcess''''
	begin
		set @BusinessProcessDim = @DimLabel
		set @Found = 1
	end
	if @DimType = ''''Time''''
	begin
		set @TimeDim = @DimLabel
		set @Found = 1
	end
	if @DimType = ''''Currency''''
	begin
		set @CurrencyDim = @DimLabel
		set @Found = 1
	end ' 

			SET @SQLStatement = @SQLStatement + '


	if @Found = 0
	begin
		set @OtherDimQry = @OtherDimQry + ''''F.['''' + @DimLabel + ''''_MemberId],''''
		set @OtherDimInsert = @OtherDimInsert + ''''['''' + @DimLabel + ''''_MemberId],''''
	end

	fetch next from Dim_cursor into @DimLabel,@DimType
end
close Dim_cursor
deallocate Dim_cursor

-- validate all required dimensions found
if @Valid = 0
begin
	if @ScenarioDim is null
	begin
		raiserror(''''Missing Scenario type dimension'''', 18, 1)
		set @Valid = 1
	end
	if @EntityDim is null
	begin
		raiserror(''''Missing Entity type dimension'''', 18, 1)
		set @Valid = 1
	end
	if @AccountDim is null
	begin
		raiserror(''''Missing Account type dimension'''', 18, 1)
		set @Valid = 1
	end
	if @IntercompanyDim is null
	begin
		raiserror(''''Missing Intercompany type dimension'''', 18, 1)
		set @Valid = 1
	end
	if @BusinessProcessDim is null
	begin
		raiserror(''''Missing BusinessProcess type dimension'''', 18, 1)
		set @Valid = 1
	end
	if @TimeDim is null
	begin
		raiserror(''''Missing Time type dimension'''', 18, 1)
		set @Valid = 1
	end
end ' 

			SET @SQLStatement = @SQLStatement + '


if @Valid = 0
begin

	-- verify all required dimension properties exist
	if not Exists(select * from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME=''''DS_'''' + @BusinessProcessDim and COLUMN_NAME=''''NoAutoElim'''')
	begin
		raiserror(''''Model: %s Dimension: %s missing NoAutoElim property'''', 18, 1, @Model, @BusinessProcessDim)
		set @Valid = 1
	end
	if not Exists(select * from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME=''''DS_'''' + @EntityDim and COLUMN_NAME=''''Elim'''')
	begin
		raiserror(''''Model: %s Dimension: %s missing Elim property'''', 18, 1, @Model, @EntityDim)
		set @Valid = 1
	end
	if not Exists(select * from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME=''''DS_'''' + @AccountDim and COLUMN_NAME=''''ICELIM'''')
	begin
		raiserror(''''Model: %s Dimension: %s missing ICELIM property'''', 18, 1, @Model, @AccountDim)
		set @Valid = 1
	end
	if not Exists(select * from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME=''''DS_'''' + @AccountDim and COLUMN_NAME=''''IC'''')
	begin
		raiserror(''''Model: %s Dimension: %s missing IC property'''', 18, 1, @Model, @AccountDim)
		set @Valid = 1
	end
end

if @Valid = 0
begin
	Create table #DS_account (Memberid bigint,icelim_memberid Bigint,sign int)
	
	set @stmt = ''''Insert into #DS_account
	Select b.Memberid,a.icelim_memberid, a.sign 
	from DS_''''+@AccountDim+'''' a, hc_''''+@AccountDim+'''' b
	where a.memberid = b.parentid and a.icelim <> '''''''''''''''' and IC_other = 0''''
	Exec(@stmt)

	-- find ELIMINATION member of BusinessProcess dimension
	IF @Br = 0
	BEGIN
		
		print ''''=====''''
		set @Params = ''''@BPElimMbrIdOut bigint OUTPUT''''
		set @Stmt = ''''select @BPElimMbrIdOut=[MemberId] from [DS_'''' + @BusinessProcessDim + ''''] where [Label]=''''''''ELIMINATION''''''''''''
		exec sp_executesql @Stmt, @Params, @BPElimMbrIdOut=@BPElimMbrId OUTPUT
		if @BPElimMbrId is null
		begin
			Raiserror(''''ELIMINATION member is missing from BusinessProcess type dimension'''', 18, 1)
			set @Valid = 1
		end
	END
	ELSE
	BEGIN
		set @Params = ''''@BPElimMbrIdOut bigint OUTPUT''''
		set @Stmt = ''''select @BPElimMbrIdOut=[MemberId] from [DS_'''' + @BusinessRuleDim + ''''] where [Label]=''''''''Elimination''''''''''''
print ''''====''''
		print  @Stmt
print ''''====''''
		exec sp_executesql @Stmt, @Params, @BPElimMbrIdOut=@BPElimMbrId OUTPUT
		if @BPElimMbrId is null
		begin
			Raiserror(''''ELIMINATION member is missing from BusinessRule type dimension'''', 18, 1)
			set @Valid = 1
		end
	END
end ' 

			SET @SQLStatement = @SQLStatement + '


-- create @FilterWhere clause ************************************
declare @Dimension nvarchar(100)
declare @Hierarchy nvarchar(100)
declare @Member nvarchar(255)
declare @MemberId bigint
declare @StartPtr int
declare @EndPtr int
declare @Len int
declare @Mbr nvarchar(250)
declare @FilterHier nvarchar(100)
declare @FilterMbrId bigint
declare @FilterDim nvarchar(100)
declare @PriorFilterDim nvarchar(100)
declare @PriorFilterHier nvarchar(100)
declare @FilterDimCnt int
declare @ReturnCode int

create table [#FilterMbrs] ([Dimension] nvarchar(50), [Hierarchy] nvarchar(50), [MemberId] bigint)
if @FilterMbrs is null
	set @FilterMbrs = ''''''''
if len(@FilterMbrs) > 0
begin
	set @Mbr = @FilterMbrs
	set @StartPtr = 0
	set @EndPtr = len(@FilterMbrs)
	while @EndPtr > 0
	begin
		set @EndPtr = charindex(''''],['''', @FilterMbrs, @StartPtr)
		if @EndPtr > 0
			set @Len = @EndPtr - @StartPtr + 1
		else
			set @Len = len(@FilterMbrs) - @StartPtr + 1
		set @Mbr = substring(@FilterMbrs, @StartPtr, @Len)
		exec brp_ParseDimHierMbr @Mbr, @Dimension output, @Hierarchy output, @Member output, @MemberId output
		if @Dimension is not null and @MemberId is not null
		begin
			insert into [#FilterMbrs] ([Dimension],[Hierarchy],[MemberId]) values (@Dimension,@Hierarchy,@MemberId)
		end
		else
		begin
			Raiserror(''''FilterMbrs contains invalid member "%s"'''', 18, 1, @Mbr)
			set @Valid = 1
		end
		--print @Mbr
		set @StartPtr = @EndPtr + 2
	end
end

-- create @FilterWhere clause ************************************
set @Found = 1 ' 

			SET @SQLStatement = @SQLStatement + '


declare Filter_cursor cursor for
select distinct [Dimension],[Hierarchy],[MemberId] from [#FilterMbrs] order by [Dimension],[Hierarchy]

open Filter_cursor
fetch next from Filter_cursor into @FilterDim,@FilterHier,@FilterMbrId
while @@FETCH_STATUS = 0
begin
	if @FilterDim <> @PriorFilterDim or @FilterHier <> @PriorFilterHier
	begin
		if @Found = 0
			set @Valid = 1
		set @Found = 1
	end
	
	if @FilterDim = @TimeDim
	begin
		exec @ReturnCode = brp_IsMemberInScope @TempTbl, ''''TimeMbrs'''', @FilterDim, @FilterHier, @FilterMbrId
		if @ReturnCode = 1
			set @Found = 0
	end
	if @FilterDim = @ScenarioDim
	begin
		exec @ReturnCode = brp_IsMemberInScope @TempTbl, ''''ScenarioMbrs'''', @FilterDim, @FilterHier, @FilterMbrId
		if @ReturnCode = 1
			set @Found = 0
	end

	fetch next from Filter_cursor into @FilterDim,@FilterHier,@FilterMbrId
end
close Filter_cursor
deallocate Filter_cursor

if @Found = 0
	set @Valid = 1

drop table [#FilterMbrs]

if @Valid = 1
	return

-- clear any existing ELIMINATION records
IF @IsBRule = 1 
BEGIN
	DECLARE @ID BIGINT
	Create table #tempI (memberid BIGINT)
	SET @Stmt = ''''INSERT INTO #tempI Select Memberid from DS_''''+@BRuleDim+'''' Where Label = ''''''''Elimination'''''''' ''''
	EXEC(@Stmt)
	Select @ID = Memberid from #TempI  
END ' 

			SET @SQLStatement = @SQLStatement + '


set @Stmt = 
''''delete from FACT_'''' + @Model + ''''_default_partition 
where (
	['''' + @IntercompanyDim + ''''_MemberId] > 0 ''''
IF @BR = 0 SET @Stmt = @Stmt + ''''
and ['''' + @BusinessProcessDim + ''''_MemberId] = '''' + @BPElimMbrId 
IF @BR = 1 SET @Stmt = @Stmt + ''''
and ['''' + @BusinessRuleDim + ''''_MemberId] = '''' + @BPElimMbrId 
SET @Stmt = @Stmt + ''''
and ['''' + @ScenarioDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]='''''''''''' + @ScenarioMbrs + '''''''''''')
	and ['''' + @TimeDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]='''''''''''' + @TimeMbrs + '''''''''''') ''''
IF @IsRound = 1 Set @Stmt = @Stmt + '''' 
and ['''' + @RoundDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]=''''''''RoundMbrs'''''''') ''''
IF @IsBrule = 1 Set @Stmt = @Stmt + '''' 
and ['''' + @BRuleDim + ''''_MemberId] = ''''+RTRIM(LTRIM(CAST(@ID as char))) 
Set @Stmt = @Stmt + ''''
)''''
print @Stmt
exec(@Stmt) ' 

			SET @SQLStatement = @SQLStatement + '


-- create entries for each hierarchy in the Entity dim
declare @HierLabel nvarchar(50)
declare Hier_cursor cursor for
select [Hierarchy] from [DimensionHierarchies] where [Dimension]=@EntityDim
--and [Hierarchy] = ''''EntitySEK''''
declare @Tmp_Eliminated nvarchar(20)
set @Tmp_Eliminated = ''''#Tmp_Eliminated''''

open Hier_cursor
fetch next from Hier_cursor into @HierLabel
while @@FETCH_STATUS = 0
begin
	set @EntityHierTbl = ''''HL_'''' + @EntityDim + ''''_'''' + @HierLabel

	if Exists(select * from INFORMATION_SCHEMA.TABLES where TABLE_NAME=@Tmp_Eliminated)
	begin
		exec(''''drop table ['''' + @Tmp_Eliminated + '''']'''')
	end
	create table [#Tmp_Eliminated] ([Entity_MemberId] bigint, [Intercompany_MemberId] bigint)
	--exec(''''create table ['''' + @Tmp_Eliminated + ''''] ([Entity_MemberId] bigint, [Intercompany_MemberId] bigint)'''')

	-- create elimination entries by level
	declare Level_cursor cursor for
	select A.name from syscolumns as A
	left join sysobjects as B on A.id = B.id
	where B.name = @EntityHierTbl and A.name like ''''Parent_%''''
	order by A.colorder desc

	declare @BaseLvl as nvarchar(255)
	declare @ChildLvl as nvarchar(255)
	declare @ParLvl as nvarchar(255)

	open Level_cursor
	fetch next from Level_cursor into @ParLvl
	set @ChildLvl = @ParLvl
	set @BaseLvl = @ParLvl
	fetch next from Level_cursor into @ParLvl
	while @@FETCH_STATUS = 0
	begin

	-- generate elimination records
	set @Stmt = 
	''''insert into [FACT_'''' + @Model + ''''_default_partition] (
	['''' + @BusinessProcessDim + ''''_MemberId],''''
	IF @BR = 1 SET @Stmt = @Stmt+ ''''
	['''' + @BusinessRuleDim + ''''_MemberId],''''
	SET @Stmt = @Stmt+ ''''
	['''' + @AccountDim + ''''_MemberId],
	['''' + @IntercompanyDim + ''''_MemberId],
	['''' + @EntityDim + ''''_MemberId],''''
	if @CurrencyDim is not null
	begin
		set @Stmt = @Stmt + ''''['''' + @CurrencyDim + ''''_MemberId],''''
	end ' 

			SET @SQLStatement = @SQLStatement + '

	set @Stmt = @Stmt + 
	''''['''' + @ScenarioDim + ''''_MemberId],
	['''' + @TimeDim + ''''_MemberId], '''' 
--	IF @IsBRule = 1 set @Stmt = @Stmt + ''''['''' + @BRuleDim + ''''_MemberId],''''
	IF @Isround = 1 set @Stmt = @Stmt + ''''['''' + @RoundDim + ''''_MemberId],''''
	Set @Stmt = @Stmt + ''''
	'''' + @OtherDimQry + ''''
	['''' + @Model + ''''_Value],[ChangeDatetime],[Userid]
	)
	select ''''
	IF @BR = 0 SET @Stmt = @Stmt + @BPElimMbrId + '''' as ['''' +  @BusinessProcessDim + ''''_MemberId],''''
	IF @BR = 1 SET @Stmt = @Stmt + 
	''''['''' + @BusinessProcessDim + ''''_MemberId],''''+
	 @BPElimMbrId +  '''' as [''''+@BusinessRuleDim + ''''_MemberId],''''
	SET @Stmt = @Stmt+''''	
	F.['''' + @AccountDim + ''''_MemberId],
	F.['''' + @IntercompanyDim + ''''_MemberId],
	G.ElimMbr as ['''' + @EntityDim + ''''_MemberId],''''
	if @CurrencyDim is not null
	begin
		set @Stmt = @Stmt + ''''F.['''' + @CurrencyDim + ''''_MemberId],''''
	end ' 

			SET @SQLStatement = @SQLStatement + '

	set @Stmt = @Stmt +
	''''F.['''' + @ScenarioDim + ''''_MemberId],
	F.['''' + @TimeDim + ''''_MemberId], '''' 
	--IF @IsBRule = 1 set @Stmt = @Stmt + RTRIM(LTRIM(CAst(@ID as char)))+'''' AS ['''' + @BRuleDim + ''''_MemberId], ''''
	IF @Isround = 1 set @Stmt = @Stmt + '''' F.['''' + @RoundDim + ''''_MemberId], ''''
	Set @Stmt = @Stmt + ''''
	'''' + @OtherDimQry + ''''
	-1*F.['''' + @Model + ''''_Value] as ['''' + @Model + ''''_Value],GetDate(),'''''''''''' + @Userid + '''''''''''' 
	from [FACT_'''' + @Model + ''''_default_partition] as F 
	left join [#DS_Account] as DA on DA.[MemberId]=F.['''' + @AccountDim + ''''_MemberId] 
	left join ['''' + @Tmp_Eliminated + ''''] as TE on F.['''' + @EntityDim + ''''_MemberId]=TE.[Entity_MemberId] 
	and F.['''' + @IntercompanyDim + ''''_MemberId]=TE.[Intercompany_MemberId]
	left join (
		-- get base level members of only parents with an elim child at this level
		select HLA.['''' + @ParLvl + ''''] as ParentMbr,HLB.[ElimMbr],['''' + @BaseLvl + ''''] as BaseMbr from ['''' + @EntityHierTbl + ''''] as HLA
		left join (
			-- get parents with an elim child at this level
			select ['''' + @ParLvl + ''''] as PMbr,['''' + @ChildLvl + ''''] as ElimMbr from ['''' + @EntityHierTbl + ''''] as ELA 
			left join [DS_'''' + @EntityDim + ''''] as ELB on ELA.['''' + @ChildLvl + ''''] = ELB.[MemberId] 
			where ELA.['''' + @ParLvl + ''''] <> ELA.['''' + @ChildLvl + ''''] and ELB.[Elim] = ''''''''True''''''''
		) as HLB on HLA.['''' + @ParLvl + ''''] = HLB.[PMbr]
	) as G on F.['''' + @EntityDim + ''''_MemberId] = G.[BaseMbr]
	left join ['''' + @EntityHierTbl + ''''] as HL on F.['''' + @EntityDim + ''''_MemberId] = HL.['''' + @BaseLvl + '''']
	where  
	DA.ICELIM_MemberId > 0 ''''
	if @CurrencyDim is not null
	begin
		set @Stmt = @Stmt + '''' and F.['''' + @CurrencyDim + ''''_MemberId] > 0 ''''
	end ' 

			SET @SQLStatement = @SQLStatement + '

	
	set @Stmt = @Stmt +
	'''' and F.['''' + @IntercompanyDim + ''''_MemberId] in (
		select ICC.[MemberId] as IC_MemberId from ['''' + @EntityHierTbl + ''''] as ICA
		left join [DS_'''' + @EntityDim + ''''] as ICB on ICA.['''' + @BaseLvl + ''''] = ICB.[MemberId]
		left join [DS_'''' + @IntercompanyDim + ''''] as ICC on ICB.[Label] = ICC.['''' + @EntityDim + '''']
		where ICC.[MemberId] is not null and ICA.['''' + @ParLvl + ''''] = HL.['''' + @ParLvl + '''']
	)
	
	and F.['''' + @BusinessProcessDim + ''''_MemberId]  in (select [MemberId] from [DS_'''' + @BusinessProcessDim + ''''] where [NoAutoElim]=''''''''False'''''''')''''
	IF @BR  = 1 SET @Stmt = @Stmt + ''''
	and F.['''' + @BusinessRuleDim + ''''_MemberId]  in (select [MemberId] from [DS_'''' + @BusinessRuleDim + ''''] where [Label] NOT IN (''''''''Elimination''''''''))
	and F.['''' + @ScenarioDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]='''''''''''' + @ScenarioMbrs + '''''''''''') 
	and F.['''' + @TimeDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]='''''''''''' + @TimeMbrs + '''''''''''') ''''
	IF @IsRound = 1 Set @Stmt = @Stmt + '''' 
	and ['''' + @RoundDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]=''''''''RoundMbrs'''''''') ''''
	Set @Stmt = @Stmt + '''' 
	and F.['''' + @EntityDim + ''''_MemberId] in (select ['''' + @BaseLvl + ''''] from ['''' + @EntityHierTbl + ''''] where ['''' + @ParLvl + ''''] in (
		select ['''' + @ParLvl + ''''] as Parent from ['''' + @EntityHierTbl + ''''] as A 
		left join [DS_'''' + @EntityDim +''''] as B on A.['''' + @ChildLvl + ''''] = B.[MemberId] 
		where A.['''' + @ParLvl + ''''] <> A.['''' + @ChildLvl + ''''] and B.[Elim] = ''''''''True''''''''))
	and TE.[Entity_MemberId] is null
	and TE.[Intercompany_MemberId] is null'''' ' 

			SET @SQLStatement = @SQLStatement + '

--	Print(@Stmt)
	exec(@Stmt)

	-- generate offset records against ICDIFF to keep all the numbers propertly balanced
	set @Stmt = 
	''''insert into [FACT_'''' + @Model + ''''_default_partition] (
	['''' + @BusinessProcessDim + ''''_MemberId],''''
	IF @BR = 1 SET @stmt = @stmt + ''''
	['''' + @BusinessRuleDim + ''''_MemberId],''''
	SET @stmt = @stmt + ''''
	['''' + @AccountDim + ''''_MemberId],
	['''' + @IntercompanyDim + ''''_MemberId],
	['''' + @EntityDim + ''''_MemberId],''''
	if @CurrencyDim is not null
	begin
		set @Stmt = @Stmt + ''''['''' + @CurrencyDim + ''''_MemberId],''''
	end ' 

			SET @SQLStatement = @SQLStatement + '

	set @Stmt = @Stmt +
	''''['''' + @ScenarioDim + ''''_MemberId],
	['''' + @TimeDim + ''''_MemberId], '''' 
--	IF @IsBRule = 1 set @Stmt = @Stmt + ''''['''' + @BRuleDim + ''''_MemberId],''''
	IF @Isround = 1 set @Stmt = @Stmt + ''''['''' + @RoundDim + ''''_MemberId],''''
	Set @Stmt = @Stmt + ''''
	'''' + @OtherDimInsert + ''''
	['''' + @Model + ''''_Value],[ChangeDatetime],[Userid]
	)
	select ''''
	IF @BR = 0 SET @Stmt = @Stmt + @BPElimMbrId + '''' as ['''' + @BusinessProcessDim + ''''_MemberId],''''
	IF @BR = 1 SET @Stmt = @Stmt + ''''['''' + @BusinessProcessDim + ''''_MemberId],''''+
	@BPElimMbrId + '''' as ['''' + @BusinessRuleDim + ''''_MemberId],''''
	SET @Stmt = @Stmt + ''''
	DA.ICELIM_MemberId as ['''' + @AccountDim + ''''_MemberId],
	F.['''' + @IntercompanyDim + ''''_MemberId],
	G.[ElimMbr] as ['''' + @EntityDim + ''''_MemberId],''''
	if @CurrencyDim is not null
	begin
		set @Stmt = @Stmt + ''''F.['''' + @CurrencyDim + ''''_MemberId],''''
	end ' 

			SET @SQLStatement = @SQLStatement + '

	set @Stmt = @Stmt + ''''
	F.['''' + @ScenarioDim + ''''_MemberId],
	F.['''' + @TimeDim + ''''_MemberId], '''' 
	--IF @IsBRule = 1 set @Stmt = @Stmt + RTRIM(LTRIM(CAst(@ID as char)))+'''' AS ['''' + @BRuleDim + ''''_MemberId], ''''
	IF @Isround = 1 set @Stmt = @Stmt + '''' F.['''' + @RoundDim + ''''_MemberId], ''''
	Set @Stmt = @Stmt + ''''
	'''' + @OtherDimQry + ''''
	F.['''' + @Model + ''''_Value] as ['''' + @Model + ''''_Value],GetDate(),'''''''''''' + @Userid + '''''''''''' 
	from [FACT_'''' + @Model + ''''_default_partition] as F 
	left join [#DS_Account] as DA on DA.[MemberId]=F.['''' + @AccountDim + ''''_MemberId] 
	left join ['''' + @Tmp_Eliminated + ''''] as TE on F.['''' + @EntityDim + ''''_MemberId]=TE.[Entity_MemberId] 
	and F.['''' + @IntercompanyDim + ''''_MemberId]=TE.[Intercompany_MemberId]
	left join (
		-- get base level members of only parents with an elim child at this level
		select HLA.['''' + @ParLvl + ''''] as ParentMbr,HLB.[ElimMbr],['''' + @BaseLvl + ''''] as BaseMbr from ['''' + @EntityHierTbl + ''''] as HLA
		left join (
			-- get parents with an elim child at this level
			select ['''' + @ParLvl + ''''] as PMbr,['''' + @ChildLvl + ''''] as ElimMbr from ['''' + @EntityHierTbl + ''''] as ELA 
			left join [DS_'''' + @EntityDim + ''''] as ELB on ELA.['''' + @ChildLvl + ''''] = ELB.[MemberId] 
			where ELA.['''' + @ParLvl + ''''] <> ELA.['''' + @ChildLvl + ''''] and ELB.[Elim] = ''''''''True''''''''
		) as HLB on HLA.['''' + @ParLvl + ''''] = HLB.[PMbr]
	) as G on F.['''' + @EntityDim + ''''_MemberId] = G.[BaseMbr]
	left join ['''' + @EntityHierTbl + ''''] as HL on F.['''' + @EntityDim + ''''_MemberId] = HL.['''' + @BaseLvl + '''']
	where  
	DA.ICELIM_MemberId > 0 '''' ' 

			SET @SQLStatement = @SQLStatement + '

	if @CurrencyDim is not null
	begin
		set @Stmt = @Stmt + '''' and F.['''' + @CurrencyDim + ''''_MemberId] > 0 ''''
	end
	set @Stmt = @Stmt +
	'''' and F.['''' + @IntercompanyDim + ''''_MemberId] in (
		select ICC.[MemberId] as [IC_MemberId] from ['''' + @EntityHierTbl + ''''] as ICA
		left join [DS_'''' + @EntityDim + ''''] as ICB on ICA.['''' + @BaseLvl + ''''] = ICB.[MemberId]
		left join [DS_'''' + @IntercompanyDim + ''''] as ICC on ICB.[Label] = ICC.['''' + @EntityDim + '''']
		where ICC.[MemberId] is not null and ICA.['''' + @ParLvl + ''''] = HL.['''' + @ParLvl + '''']
	)
	and F.['''' + @BusinessProcessDim + ''''_MemberId] in (select [MemberId] from [DS_'''' + @BusinessProcessDim + ''''] where [NoAutoElim]=''''''''False'''''''')  ''''
	IF @BR = 0 SET @Stmt = @stmt + ''''
	and F.['''' + @BusinessProcessDim + ''''_MemberId] <> '''' + @BPElimMbrId 
	IF @BR = 1 SET @Stmt = @stmt + ''''
	and F.['''' + @BusinessRuleDim + ''''_MemberId] <> '''' + @BPElimMbrId 
	SET @Stmt = @Stmt + ''''
	and F.['''' + @ScenarioDim + ''''_MemberId] in (select [MemberId] from ['''' + @TempTbl + ''''] where [ParameterName]='''''''''''' + @ScenarioMbrs + '''''''''''') 
	and F.['''' + @TimeDim + ''''_MemberId] in (select [MemberId] from ['''' + @TempTbl + ''''] where [ParameterName]='''''''''''' + @TimeMbrs + '''''''''''')  ''''
	IF @IsRound = 1 Set @Stmt = @Stmt + '''' 
	and ['''' + @RoundDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]=''''''''RoundMbrs'''''''') ''''
	Set @Stmt = @Stmt + ''''
	and F.['''' + @EntityDim + ''''_MemberId] in (select ['''' + @BaseLvl + ''''] from ['''' + @EntityHierTbl + ''''] where ['''' + @ParLvl + ''''] in (
		select ['''' + @ParLvl + ''''] as [Parent] from ['''' + @EntityHierTbl + ''''] as A 
		left join [DS_'''' + @EntityDim + ''''] as B on A.['''' + @ChildLvl + ''''] = B.[MemberId] 
		where A.['''' + @ParLvl + ''''] <> A.['''' + @ChildLvl + ''''] and B.[Elim] = ''''''''True''''''''))
	and TE.[Entity_MemberId] is null
	and TE.[Intercompany_MemberId] is null'''' ' 

			SET @SQLStatement = @SQLStatement + '


	--print ''''generate offset records''''
	--print @Stmt
	exec(@Stmt)

	-- add records to list of already Eliminated points in the Entity-Intercompany dimensions
	set @Stmt =
	''''insert into ['''' + @Tmp_Eliminated + ''''] ([Entity_MemberId],[Intercompany_MemberId])
	select distinct
	HE.['''' + @BaseLvl + ''''] as [Entity_MemberId],
	HE.[MemberId] as [Intercompany_MemberId]
	from (select * from ['''' + @EntityHierTbl + ''''], [DS_'''' + @IntercompanyDim + '''']) as HE
	left join [DS_'''' + @EntityDim + ''''] as DE on DE.[MemberId]=HE.['''' + @BaseLvl + '''']
	left join ['''' + @Tmp_Eliminated + ''''] as TE on HE.['''' + @BaseLvl + '''']=TE.[Entity_MemberId] and HE.[MemberId]=TE.[Intercompany_MemberId]
	left join (
		-- get base level members of only parents with an elim child at this level
		select HLA.['''' + @ParLvl + ''''] as [ParentMbr],['''' + @BaseLvl + ''''] as [BaseMbr] from ['''' + @EntityHierTbl + ''''] as HLA
		left join (
			-- get parents with an elim child at this level
			select ['''' + @ParLvl + ''''] as [PMbr] from ['''' + @EntityHierTbl + ''''] as ELA 
			left join [DS_'''' + @EntityDim + ''''] as ELB on ELA.['''' + @ChildLvl + ''''] = ELB.[MemberId] 
			where ELA.['''' + @ParLvl + ''''] <> ELA.['''' + @ChildLvl + ''''] and ELB.[Elim] = ''''''''True''''''''
		) as HLB on HLA.['''' + @ParLvl + ''''] = HLB.[PMbr]
	) as G on HE.['''' + @ChildLvl + ''''] = G.[BaseMbr]
	where  
	HE.[MemberId] in (
		-- only include intercompany members that part of this parents branch of the hierarchy
		select ICC.[MemberId] as [IC_MemberId] from ['''' + @EntityHierTbl + ''''] as ICA
		left join [DS_'''' + @EntityDim + ''''] as ICB on ICA.['''' + @BaseLvl + ''''] = ICB.[MemberId]
		left join [DS_'''' + @IntercompanyDim + ''''] as ICC on ICB.[Label] = ICC.['''' + @EntityDim + '''']
		where ICC.[MemberId] is not null and ICA.['''' + @ParLvl + ''''] = HE.['''' + @ParLvl + '''']
	) ' 

			SET @SQLStatement = @SQLStatement + '

	and HE.['''' + @BaseLvl + ''''] in (
		select ['''' + @BaseLvl + ''''] from ['''' + @EntityHierTbl + ''''] where ['''' + @ParLvl + ''''] in (
		-- only include parents with an elim child at this level
		select ['''' + @ParLvl + ''''] as [Parent] from ['''' + @EntityHierTbl + ''''] as A 
		left join [DS_'''' + @EntityDim + ''''] as B on A.['''' + @ChildLvl + ''''] = B.[MemberId] 
		where A.['''' + @ParLvl + ''''] <> A.['''' + @ChildLvl + ''''] and B.[Elim] = ''''''''True''''''''
		)
	)
	-- only include intercompany members not eliminated at lower levels of the hierarchy
	and TE.[Entity_MemberId] is null
	and TE.[Intercompany_MemberId] is null '''' ' 

			SET @SQLStatement = @SQLStatement + '


	--print ''''add to list of already eliminated points in Entity-Intercompany dimension''''
	print @Stmt
	exec(@Stmt)

	set @ChildLvl = @ParLvl
	-- end Level procesing
	fetch next from Level_cursor into @ParLvl
	end
	close Level_cursor
	deallocate Level_cursor

	--exec(''''drop table ['''' + @Tmp_Eliminated + '''']'''')

	drop table [#Tmp_Eliminated]
	-- end Hierarchy processing
	fetch next from Hier_cursor into @HierLabel
end
close Hier_cursor
deallocate Hier_cursor

drop table #DS_account,#tempI

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

--  Drop table [#Tmp_Eliminated]
--	close Level_cursor
--	deallocate Level_cursor


/****** Object:  StoredProcedure [dbo].[Canvas_ICEliminationsOther]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_ICEliminationsOther'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_ICEliminationsOther') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_ICEliminationsOther]
	@FilterMbrs nvarchar(2048),
	@ScenarioMbrs as nvarchar(255),
	@TimeMbrs as nvarchar(255),
	@BR Bit = 1
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

--Declare @FilterMbrs nvarchar(2048),@ScenarioMbrs as nvarchar(255),@TimeMbrs as nvarchar(255),@BR Bit = 1
--Set @FilterMbrs = ''''''''
--Set @ScenarioMbrs = ''''ScenarioMbrs''''
--Set @TimeMbrs = ''''TimeMbrs''''
--Set @BR = 1

-- retrieve parameters passed in
-- uncomment following for production
declare @TempTbl nvarchar(25)
declare @Model nvarchar(50)
declare @Userid nvarchar(255)
set @TempTbl = ''''#Temp_ParameterValues''''
set @Model = (select [StringValue] from [#Temp_ParameterValues] where [ParameterName]=''''Model'''')
set @Userid = (select [StringValue] from [#Temp_ParameterValues] where [ParameterName]=''''Userid'''')

---- uncomment following for dev work
---- Select * into #Temp_Parametervalues from Temp_Parametervalues
--declare @count INT


--declare @TempTbl nvarchar(25)
--declare @FilterMbrs nvarchar(2048)
--declare @Model nvarchar(50)
--declare @Userid nvarchar(255)
--declare @ScenarioMbrs as nvarchar(255)
--set @FilterMbrs = ''''''''
--set @ScenarioMbrs = ''''ScenarioMbrs''''
--declare @TimeMbrs as nvarchar(255)
--set @TimeMbrs = ''''TimeMbrs''''
--set @TempTbl = ''''#Temp_ParameterValues''''
--set @Model = (select [StringValue] from [#Temp_ParameterValues] where [ParameterName]=''''Model'''')
--BEGIN
------uncomment  end

if @Userid is null
	set @Userid = ''''''''
if @Model is null
begin
	Raiserror(''''Missing Model name'''', 18, 1)
	return
end ' 

			SET @SQLStatement = @SQLStatement + '

	
declare @AccountDim nvarchar(50)
declare @ScenarioDim nvarchar(50)
declare @EntityDim nvarchar(50)
declare @IntercompanyDim nvarchar(50)
declare @BusinessProcessDim nvarchar(50)
declare @BusinessRuleDim nvarchar(50)
declare @TimeDim nvarchar(50)
declare @CurrencyDim nvarchar(50)
declare @RoundDim nvarchar(50)
declare @BRuleDim nvarchar(50)

Declare @IsRound Bit
Declare @IsBRule Bit

declare @DimLabel nvarchar(50)
declare @DimType nvarchar(50)
declare @BPElimMbrId nvarchar(20)
declare @EntityHierTbl nvarchar(50)
declare @OtherDimQry nvarchar(max)
declare @OtherDimInsert nvarchar(max)
declare @Found int
declare @Valid int
declare @Stmt as nvarchar(max)
declare @Sql as nvarchar(max)
declare @Params nvarchar(max)


set @IsRound = 0
set @IsBrule = 0

set @OtherDimQry = ''''''''
set @OtherDimInsert = ''''''''
set @Valid = 0

-- retrieve dimension names
declare Dim_cursor cursor for 
select A.[Dimension],B.[Type] from [ModelDimensions] as A 
left join [Dimensions] as B on A.[Dimension]=B.[Label] 
where A.[Model] = @Model

open Dim_cursor
fetch next from Dim_cursor into @DimLabel,@DimType
while @@FETCH_STATUS = 0
begin
	set @Found = 0
	if @DimType = ''''Scenario''''
	begin
		set @ScenarioDim = @DimLabel
		set @Found = 1
	end
	if @DimType = ''''BusinessRule''''
	begin
		set @BusinessRuleDim = @DimLabel
		set @Found = 1
		set @IsBrule = 1
	end
	if @DimType = ''''Round''''
	begin
		set @RoundDim = @DimLabel
		set @Found = 1
		set @IsRound = 1
	end
	if @DimType = ''''Account''''
	begin
		set @AccountDim = @DimLabel
		set @Found = 1
	end
	if @DimType = ''''Entity''''
	begin
		set @EntityDim = @DimLabel
		set @Found = 1
	end ' 

			SET @SQLStatement = @SQLStatement + '

	if @DimType = ''''Intercompany''''
	begin
		set @IntercompanyDim = @DimLabel
		set @Found = 1
	end
	if @DimType = ''''BusinessProcess''''
	begin
		set @BusinessProcessDim = @DimLabel
		set @Found = 1
	end
	if @DimType = ''''Time''''
	begin
		set @TimeDim = @DimLabel
		set @Found = 1
	end
	if @DimType = ''''Currency''''
	begin
		set @CurrencyDim = @DimLabel
		set @Found = 1
	end

	if @Found = 0
	begin
		set @OtherDimQry = @OtherDimQry + ''''F.['''' + @DimLabel + ''''_MemberId],''''
		set @OtherDimInsert = @OtherDimInsert + ''''['''' + @DimLabel + ''''_MemberId],''''
	end

	fetch next from Dim_cursor into @DimLabel,@DimType
end
close Dim_cursor
deallocate Dim_cursor

-- validate all required dimensions found
if @Valid = 0
begin
	if @ScenarioDim is null
	begin
		raiserror(''''Missing Scenario type dimension'''', 18, 1)
		set @Valid = 1
	end
	if @EntityDim is null
	begin
		raiserror(''''Missing Entity type dimension'''', 18, 1)
		set @Valid = 1
	end
	if @AccountDim is null
	begin
		raiserror(''''Missing Account type dimension'''', 18, 1)
		set @Valid = 1
	end
	if @IntercompanyDim is null
	begin
		raiserror(''''Missing Intercompany type dimension'''', 18, 1)
		set @Valid = 1
	end ' 

			SET @SQLStatement = @SQLStatement + '

	if @BusinessProcessDim is null
	begin
		raiserror(''''Missing BusinessProcess type dimension'''', 18, 1)
		set @Valid = 1
	end
	if @TimeDim is null
	begin
		raiserror(''''Missing Time type dimension'''', 18, 1)
		set @Valid = 1
	end
end

if @Valid = 0
begin

	-- verify all required dimension properties exist
	if not Exists(select * from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME=''''DS_'''' + @BusinessProcessDim and COLUMN_NAME=''''NoAutoElim'''')
	begin
		raiserror(''''Model: %s Dimension: %s missing NoAutoElim property'''', 18, 1, @Model, @BusinessProcessDim)
		set @Valid = 1
	end
	if not Exists(select * from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME=''''DS_'''' + @EntityDim and COLUMN_NAME=''''Elim'''')
	begin
		raiserror(''''Model: %s Dimension: %s missing Elim property'''', 18, 1, @Model, @EntityDim)
		set @Valid = 1
	end
	if not Exists(select * from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME=''''DS_'''' + @AccountDim and COLUMN_NAME=''''ICELIM'''')
	begin
		raiserror(''''Model: %s Dimension: %s missing ICELIM property'''', 18, 1, @Model, @AccountDim)
		set @Valid = 1
	end
	if not Exists(select * from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME=''''DS_'''' + @AccountDim and COLUMN_NAME=''''IC'''')
	begin
		raiserror(''''Model: %s Dimension: %s missing IC property'''', 18, 1, @Model, @AccountDim)
		set @Valid = 1
	end
end

if @Valid = 0
begin
	Create table #DS_account (Memberid bigint,icelim_memberid Bigint,sign int,Icelim_holding bit)
	
	set @stmt = ''''Insert into #DS_account
	Select b.Memberid,a.icelim_memberid, a.sign ,icelim_holding
	from DS_''''+@AccountDim+'''' a, hc_''''+@AccountDim+'''' b
	where a.memberid = b.parentid and a.icelim <> '''''''''''''''' and IC_Other = 1 ''''
	Exec(@stmt) ' 

			SET @SQLStatement = @SQLStatement + '


	-- find ELIMINATION member of BusinessProcess dimension
	IF @BR = 0
	BEGIN
		set @Params = ''''@BPElimMbrIdOut bigint OUTPUT''''
		set @Stmt = ''''select @BPElimMbrIdOut=[MemberId] from [DS_'''' + @BusinessProcessDim + ''''] where [Label]=''''''''ELIMINATION_OTHER''''''''''''
		exec sp_executesql @Stmt, @Params, @BPElimMbrIdOut=@BPElimMbrId OUTPUT
		if @BPElimMbrId is null
		begin
			Raiserror(''''ELIMINATION_OTHER member is missing from BusinessProcess type dimension'''', 18, 1)
			set @Valid = 1
		end
	END
	ELSE
	BEGIN
		set @Params = ''''@BPElimMbrIdOut bigint OUTPUT''''
		set @Stmt = ''''select @BPElimMbrIdOut=[MemberId] from [DS_'''' + @BusinessRuleDim + ''''] where [Label]=''''''''ELIMINATION_OTHER''''''''''''
		exec sp_executesql @Stmt, @Params, @BPElimMbrIdOut=@BPElimMbrId OUTPUT
		if @BPElimMbrId is null
		begin
			Raiserror(''''ELIMINATION_OTHER member is missing from BusinessRule type dimension'''', 18, 1)
			set @Valid = 1
		end
	END
end

-- create @FilterWhere clause ************************************
declare @Dimension nvarchar(100)
declare @Hierarchy nvarchar(100)
declare @Member nvarchar(255)
declare @MemberId bigint
declare @StartPtr int
declare @EndPtr int
declare @Len int
declare @Mbr nvarchar(250)
declare @FilterHier nvarchar(100)
declare @FilterMbrId bigint
declare @FilterDim nvarchar(100)
declare @PriorFilterDim nvarchar(100)
declare @PriorFilterHier nvarchar(100)
declare @FilterDimCnt int
declare @ReturnCode int

Create table #Level (ParentMbr BIGINT,ElimMbr BIGINT,BaseMbr BIGINT, HoldingMbr BIGINT)

create table [#FilterMbrs] ([Dimension] nvarchar(50), [Hierarchy] nvarchar(50), [MemberId] bigint)
if @FilterMbrs is null
	set @FilterMbrs = ''''''''
if len(@FilterMbrs) > 0
begin
	set @Mbr = @FilterMbrs
	set @StartPtr = 0
	set @EndPtr = len(@FilterMbrs)
	while @EndPtr > 0
	begin
		set @EndPtr = charindex(''''],['''', @FilterMbrs, @StartPtr)
		if @EndPtr > 0
			set @Len = @EndPtr - @StartPtr + 1
		else
			set @Len = len(@FilterMbrs) - @StartPtr + 1
		set @Mbr = substring(@FilterMbrs, @StartPtr, @Len)
		exec brp_ParseDimHierMbr @Mbr, @Dimension output, @Hierarchy output, @Member output, @MemberId output
		if @Dimension is not null and @MemberId is not null
		begin
			insert into [#FilterMbrs] ([Dimension],[Hierarchy],[MemberId]) values (@Dimension,@Hierarchy,@MemberId)
		end ' 

			SET @SQLStatement = @SQLStatement + '

		else
		begin
			Raiserror(''''FilterMbrs contains invalid member "%s"'''', 18, 1, @Mbr)
			set @Valid = 1
		end
		--print @Mbr
		set @StartPtr = @EndPtr + 2
	end
end

-- create @FilterWhere clause ************************************
set @Found = 1

declare Filter_cursor cursor for
select distinct [Dimension],[Hierarchy],[MemberId] from [#FilterMbrs] order by [Dimension],[Hierarchy]

open Filter_cursor
fetch next from Filter_cursor into @FilterDim,@FilterHier,@FilterMbrId
while @@FETCH_STATUS = 0
begin
	if @FilterDim <> @PriorFilterDim or @FilterHier <> @PriorFilterHier
	begin
		if @Found = 0
			set @Valid = 1
		set @Found = 1
	end
	
	if @FilterDim = @TimeDim
	begin
		exec @ReturnCode = brp_IsMemberInScope @TempTbl, ''''TimeMbrs'''', @FilterDim, @FilterHier, @FilterMbrId
		if @ReturnCode = 1
			set @Found = 0
	end
	if @FilterDim = @ScenarioDim
	begin
		exec @ReturnCode = brp_IsMemberInScope @TempTbl, ''''ScenarioMbrs'''', @FilterDim, @FilterHier, @FilterMbrId
		if @ReturnCode = 1
			set @Found = 0
	end

	fetch next from Filter_cursor into @FilterDim,@FilterHier,@FilterMbrId
end
close Filter_cursor
deallocate Filter_cursor

if @Found = 0
	set @Valid = 1

drop table [#FilterMbrs] ' 

			SET @SQLStatement = @SQLStatement + '


if @Valid = 1
	return

-- clear any existing ELIMINATION records

IF @BR = 1 
BEGIN
	DECLARE @ID BIGINT
	Create table #tempI (memberid BIGINT)
	SET @Stmt = ''''INSERT INTO #tempI Select Memberid from DS_''''+@BRuleDim+'''' Where Label = ''''''''Elimination_Other'''''''' ''''
	EXEC(@Stmt)
	Select @ID = Memberid from #TempI  
END

set @Stmt = 
''''delete from FACT_'''' + @Model + ''''_default_partition 
where ( ''''
IF @BR = 0 SET @Stmt = @Stmt + ''''['''' + @BusinessProcessDim + ''''_MemberId] = '''' + @BPElimMbrId 
IF @BR = 1 SET @Stmt = @Stmt + ''''['''' + @BusinessRuleDim + ''''_MemberId] = '''' + @BPElimMbrId 
SET @Stmt = @Stmt + ''''
	and ['''' + @ScenarioDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]='''''''''''' + @ScenarioMbrs + '''''''''''')
	and ['''' + @TimeDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]='''''''''''' + @TimeMbrs + '''''''''''') ''''
	IF @IsRound = 1 Set @Stmt = @Stmt + '''' 
	and ['''' + @RoundDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]=''''''''RoundMbrs'''''''') ''''
	--IF @IsBrule = 1 Set @Stmt = @Stmt + '''' 
	--and ['''' + @BRuleDim + ''''_MemberId] = ''''+RTRIM(LTRIM(CAST(@ID as char))) 
	Set @Stmt = @Stmt + ''''
)''''
--print @Stmt
exec(@Stmt)

-- create entries for each hierarchy in the Entity dim
declare @HierLabel nvarchar(50)
declare Hier_cursor cursor for

select hierarchy from [DimensionHierarchies] where Dimension = ''''Entity''''
--and Hierarchy in (''''NCABGROUP_OP'''')
--and Hierarchy in (''''EntitySEK'''')
--select [Hierarchy] from [DimensionHierarchies] where [Dimension]=@EntityDim
--and Hierarchy in (''''EntitySEK'''',''''NCABGROUP_OP'''')


--NCABGROUP_OP
--Select Distinct  ''''ENTITYSEK''''  from [DimensionHierarchies] where [Dimension]=@EntityDim

declare @Tmp_Eliminated nvarchar(20), @CountTmp INT,@Holding Nvarchar(5),@num INT,@IsHolding Bit
Set @num = 1
set @Tmp_Eliminated = ''''#Tmp_Eliminated''''
Create table #temp (memberid Bigint)
open Hier_cursor
fetch next from Hier_cursor into @HierLabel
while @@FETCH_STATUS = 0
begin
	Truncate table #temp
	SET @Isholding = 1
	Set @Stmt = ''''Insert into #temp Select Holding_memberid from DS_''''+@EntityDim+'''' 
	Where Memberid in (Select memberid from [HS_''''+@EntityDim+''''_''''+@Hierlabel+''''] Where Parentmemberid = 0 )
	And Holding_Memberid IS Not NULL ''''
	EXEC(@Stmt)

	If @@ROWCOUNT = 0 SET @IsHolding = 0

	Select @Holding = CAst(memberid as Char) from #temp
	IF @IsHolding = 0 SET @Holding = ''''-1''''

	set @EntityHierTbl = ''''HL_'''' + @EntityDim + ''''_'''' + @HierLabel ' 

			SET @SQLStatement = @SQLStatement + '


	if Exists(select * from INFORMATION_SCHEMA.TABLES where TABLE_NAME=@Tmp_Eliminated)
	begin
		exec(''''drop table ['''' + @Tmp_Eliminated + '''']'''')
	end
	create table [#Tmp_Eliminated] ([Entity_MemberId] bigint, [Intercompany_MemberId] bigint,Holding Bit,New INT)
	--exec(''''create table ['''' + @Tmp_Eliminated + ''''] ([Entity_MemberId] bigint, [Intercompany_MemberId] bigint)'''')

	-- create elimination entries by level
	declare Level_cursor cursor for
	select A.name from syscolumns as A
	left join sysobjects as B on A.id = B.id
	where B.name = @EntityHierTbl and A.name like ''''Parent_%''''
	order by A.colorder desc

	declare @BaseLvl as nvarchar(255)
	declare @ChildLvl as nvarchar(255)
	declare @ParLvl as nvarchar(255)

	open Level_cursor
	fetch next from Level_cursor into @ParLvl
	set @ChildLvl = @ParLvl
	set @BaseLvl = @ParLvl
	fetch next from Level_cursor into @ParLvl
	while @@FETCH_STATUS = 0
	begin


	Select @CountTmp = COUNT(*) from #tmp_Eliminated

--If @HierLabel = ''''EntitySEK''''  
--BEgin
--	IF @ParLvl =''''Parent_L2'''' RETURN
--end


--=============================================
--=============================================
		Truncate table #level
		-- get base level members of only parents with an elim child at this level
		set @sql = '''' 
		insert into #level 
		select HLA.['''' + @ParLvl + ''''] as ParentMbr,HLB.[ElimMbr],['''' + @BaseLvl + ''''] as BaseMbr ,HLb.Holding_memberid
		from ['''' + @EntityHierTbl + ''''] as HLA
		left join (
			-- get parents with an elim child at this level
			select ['''' + @ParLvl + ''''] as PMbr,['''' + @ChildLvl + ''''] as ElimMbr, elp.Holding_memberid from ['''' + @EntityHierTbl + ''''] as ELA 
			left join [DS_'''' + @EntityDim + ''''] as ELB on ELA.['''' + @ChildLvl + ''''] = ELB.[MemberId] 
			left join [DS_'''' + @EntityDim + ''''] as ELP on ELA.['''' + @ParLvl + ''''] = ELP.[MemberId] 
			where ELA.['''' + @ParLvl + ''''] <> ELA.['''' + @ChildLvl + ''''] and ELB.[Elim] = ''''''''True''''''''
		) as HLB on HLA.['''' + @ParLvl + ''''] = HLB.[PMbr] 
		Where HLB.[ElimMbr] Is not null ''''
		print @sql
		Exec(@sql) ' 

			SET @SQLStatement = @SQLStatement + '

--=============================================
--=============================================

	-- generate elimination records
	set @Stmt = 
	''''insert into [FACT_'''' + @Model + ''''_default_partition] (
	['''' + @BusinessProcessDim + ''''_MemberId],''''
	IF @BR = 1 SET @Stmt = @Stmt + 
	''''['''' + @BusinessRuleDim + ''''_MemberId],''''
	SET @Stmt = @Stmt + ''''
	['''' + @AccountDim + ''''_MemberId],
	['''' + @IntercompanyDim + ''''_MemberId],
	['''' + @EntityDim + ''''_MemberId],''''
	if @CurrencyDim is not null
	begin
		set @Stmt = @Stmt + ''''['''' + @CurrencyDim + ''''_MemberId],''''
	end
	set @Stmt = @Stmt + 
	''''['''' + @ScenarioDim + ''''_MemberId],
	['''' + @TimeDim + ''''_MemberId], '''' 
	--IF @IsBRule = 1 set @Stmt = @Stmt + ''''['''' + @BRuleDim + ''''_MemberId],''''
	IF @Isround = 1 set @Stmt = @Stmt + ''''['''' + @RoundDim + ''''_MemberId],''''
	Set @Stmt = @Stmt + ''''
	'''' + @OtherDimQry + ''''
	['''' + @Model + ''''_Value],[ChangeDatetime],[Userid]
	)
	select ''''
	IF @BR = 0 SET @Stmt = @Stmt + @BPElimMbrId + '''' as ['''' + @BusinessProcessDim + ''''_MemberId],''''
	IF @BR = 1 SET @Stmt = @Stmt + ''''['''' + @BusinessProcessDim + ''''_MemberId],''''+
	@BPElimMbrId + '''' as ['''' + @BusinessRuleDim + ''''_MemberId],''''
	SET @Stmt = @Stmt + ''''
	F.['''' + @AccountDim + ''''_MemberId],
	F.['''' + @IntercompanyDim + ''''_MemberId],
	G.ElimMbr as ['''' + @EntityDim + ''''_MemberId],''''
	if @CurrencyDim is not null
	begin
		set @Stmt = @Stmt + ''''F.['''' + @CurrencyDim + ''''_MemberId],''''
	end
	set @Stmt = @Stmt +
	''''F.['''' + @ScenarioDim + ''''_MemberId],
	F.['''' + @TimeDim + ''''_MemberId], '''' 
	--IF @IsBRule = 1 set @Stmt = @Stmt + RTRIM(LTRIM(CAst(@ID as char)))+'''' AS ['''' + @BRuleDim + ''''_MemberId], ''''
	IF @Isround = 1 set @Stmt = @Stmt + '''' F.['''' + @RoundDim + ''''_MemberId], ''''
	Set @Stmt = @Stmt + ''''
	'''' + @OtherDimQry + ''''
	-1*F.['''' + @Model + ''''_Value] as ['''' + @Model + ''''_Value],GetDate(),'''''''''''' + @Userid + '''''''''''' 
	from [FACT_'''' + @Model + ''''_default_partition] as F 
	left join [#DS_Account] as DA on DA.[MemberId]=F.['''' + @AccountDim + ''''_MemberId] 
	left join ['''' + @Tmp_Eliminated + ''''] as TE on F.['''' + @EntityDim + ''''_MemberId]=TE.[Entity_MemberId] 
	-- and F.['''' + @IntercompanyDim + ''''_MemberId]=TE.[Intercompany_MemberId]
	left join 
		--(
		---- get base level members of only parents with an elim child at this level
		--select HLA.['''' + @ParLvl + ''''] as ParentMbr,HLB.[ElimMbr],['''' + @BaseLvl + ''''] as BaseMbr from ['''' + @EntityHierTbl + ''''] as HLA
		--left join (
		--	-- get parents with an elim child at this level
		--	select ['''' + @ParLvl + ''''] as PMbr,['''' + @ChildLvl + ''''] as ElimMbr from ['''' + @EntityHierTbl + ''''] as ELA 
		--	left join [DS_'''' + @EntityDim + ''''] as ELB on ELA.['''' + @ChildLvl + ''''] = ELB.[MemberId] 
		--	where ELA.['''' + @ParLvl + ''''] <> ELA.['''' + @ChildLvl + ''''] and ELB.[Elim] = ''''''''True''''''''
		--) as HLB on HLA.['''' + @ParLvl + ''''] = HLB.[PMbr]
		--) 
		#Level as G on F.['''' + @EntityDim + ''''_MemberId] = G.[BaseMbr]
	left join ['''' + @EntityHierTbl + ''''] as HL on F.['''' + @EntityDim + ''''_MemberId] = HL.['''' + @BaseLvl + '''']
	where   ' 

			SET @SQLStatement = @SQLStatement + '

	DA.ICELIM_MemberId > 0 ''''
	if @CurrencyDim is not null
	begin
		set @Stmt = @Stmt + '''' and F.['''' + @CurrencyDim + ''''_MemberId] > 0 ''''
	end
	set @Stmt = @Stmt +
	'''' 
	--and F.['''' + @IntercompanyDim + ''''_MemberId] in (
	--	select ICC.[MemberId] as IC_MemberId from ['''' + @EntityHierTbl + ''''] as ICA
	--	left join [DS_'''' + @EntityDim + ''''] as ICB on ICA.['''' + @BaseLvl + ''''] = ICB.[MemberId]
	--	left join [DS_'''' + @IntercompanyDim + ''''] as ICC on ICB.[Label] = ICC.['''' + @EntityDim + '''']
	--	where ICC.[MemberId] is not null and ICA.['''' + @ParLvl + ''''] = HL.['''' + @ParLvl + '''']
	--)
	and F.['''' + @BusinessProcessDim + ''''_MemberId]  in (select [MemberId] from [DS_'''' + @BusinessProcessDim + ''''] where [NoAutoElim]=''''''''False'''''''')
	and F.['''' + @ScenarioDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]='''''''''''' + @ScenarioMbrs + '''''''''''') 
	and F.['''' + @TimeDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]='''''''''''' + @TimeMbrs + '''''''''''')  ''''
	IF @IsRound = 1 Set @Stmt = @Stmt + '''' 
	and ['''' + @RoundDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]=''''''''RoundMbrs'''''''') ''''
	Set @Stmt = @Stmt + '''' 
	and F.['''' + @EntityDim + ''''_MemberId] in (select ['''' + @BaseLvl + ''''] from ['''' + @EntityHierTbl + ''''] where ['''' + @ParLvl + ''''] in (
		select ['''' + @ParLvl + ''''] as Parent from ['''' + @EntityHierTbl + ''''] as A 
		left join [DS_'''' + @EntityDim +''''] as B on A.['''' + @ChildLvl + ''''] = B.[MemberId] 
		where A.['''' + @ParLvl + ''''] <> A.['''' + @ChildLvl + ''''] and B.[Elim] = ''''''''True''''''''))''''
	--and TE.[Intercompany_MemberId] is null''''

	DECLARE @Stmt2 Nvarchar(Max)
	IF @BR = 0 SET @Stmt2 = '''' And ''''+@BusinessProcessDim+''''_Memberid <> ''''+ @BPElimMbrId 
	IF @BR = 1 SET @Stmt2 = '''' And ''''+@BusinessRuleDim+''''_Memberid <> ''''+ @BPElimMbrId 

	exec(@Stmt + ''''
	and TE.[Entity_MemberId] is null
	And DA.[ICELIM_Holding] = 1 '''' + @Stmt2 )

	IF @CountTmp > 0
	BEGIN
		exec(@Stmt + ''''
		And ((TE.[Entity_MemberId]  is null) OR (TE.[holding]=1 and TE.NEW = 1))
		And DA.[ICELIM_Holding] = 0
		And F.['''' + @EntityDim + ''''_MemberId] Not in (Select HoldingMbr from #level)
		--And F.['''' + @EntityDim + ''''_MemberId] <> ''''+@Holding+'''' 
		--And F.['''' + @EntityDim + ''''_MemberId] Not in 
		--(Select Holding_memberid from [DS_''''+@EntityDim+''''] Where Holding_memberid not in 
		--(Select Entity_memberid from ['''' + @Tmp_Eliminated + ''''] Where Holding = 1)) 
		And F.['''' + @EntityDim + ''''_MemberId] Not in (Select Entity_memberid from [#Tmp_Eliminated] where holding = 1 And New > 1)''''
		+@Stmt2)
	END
	ELSE
	BEGIN
		exec(@Stmt + ''''
		and TE.[Entity_MemberId] is null
		And DA.[ICELIM_Holding] = 0
		And F.['''' + @EntityDim + ''''_MemberId] Not in (Select HoldingMbr  from #Level)
--		And F.['''' + @EntityDim + ''''_MemberId] <> ''''+@Holding+'''' 
		And F.['''' + @EntityDim + ''''_MemberId] Not in (Select Holding_memberid from [DS_''''+@EntityDim+'''']) ''''
		+@Stmt2 )
	END	 ' 

			SET @SQLStatement = @SQLStatement + '


--=============================================================================================
--=============================================================================================
--=============================================================================================
--=============================================================================================
	-- generate offset records against ICDIFF to keep all the numbers propertly balanced
	set @Stmt = 
	''''insert into [FACT_'''' + @Model + ''''_default_partition] (
	['''' + @BusinessProcessDim + ''''_MemberId],''''
	IF @BR = 1 SET @Stmt = @Stmt + '''' 
	['''' + @BusinessRuleDim + ''''_MemberId],''''
	SET @Stmt = @Stmt +'''' 
	['''' + @AccountDim + ''''_MemberId],
	['''' + @IntercompanyDim + ''''_MemberId],
	['''' + @EntityDim + ''''_MemberId],''''
	if @CurrencyDim is not null
	begin
		set @Stmt = @Stmt + ''''['''' + @CurrencyDim + ''''_MemberId],''''
	end
	set @Stmt = @Stmt + 
	''''['''' + @ScenarioDim + ''''_MemberId],
	['''' + @TimeDim + ''''_MemberId], '''' 
	--IF @IsBRule = 1 set @Stmt = @Stmt + ''''['''' + @BRuleDim + ''''_MemberId],''''
	IF @Isround = 1 set @Stmt = @Stmt + ''''['''' + @RoundDim + ''''_MemberId],''''
	Set @Stmt = @Stmt + ''''
	'''' + @OtherDimQry + ''''
	['''' + @Model + ''''_Value],[ChangeDatetime],[Userid]
	)
	select ''''
	IF @BR = 0 SET @Stmt = @Stmt + @BPElimMbrId + '''' as ['''' + @BusinessProcessDim + ''''_MemberId],''''
	IF @BR = 1 SET @Stmt = @Stmt + ''''['''' + @BusinessprocessDim + ''''_MemberId],'''' + 
	@BPElimMbrId + '''' as ['''' + @BusinessRuleDim + ''''_MemberId],''''
	SET @Stmt = @Stmt + ''''
	DA.[icelim_memberid],
	F.['''' + @IntercompanyDim + ''''_MemberId],
	G.ElimMbr as ['''' + @EntityDim + ''''_MemberId],''''
	if @CurrencyDim is not null
	begin
		set @Stmt = @Stmt + ''''F.['''' + @CurrencyDim + ''''_MemberId],''''
	end
	set @Stmt = @Stmt +
	''''F.['''' + @ScenarioDim + ''''_MemberId],
	F.['''' + @TimeDim + ''''_MemberId], '''' 
	--IF @IsBRule = 1 set @Stmt = @Stmt + RTRIM(LTRIM(CAst(@ID as char)))+'''' AS ['''' + @BRuleDim + ''''_MemberId], ''''
	IF @Isround = 1 set @Stmt = @Stmt + '''' F.['''' + @RoundDim + ''''_MemberId], ''''
	Set @Stmt = @Stmt + ''''
	'''' + @OtherDimQry + ''''
	F.['''' + @Model + ''''_Value] as ['''' + @Model + ''''_Value],GetDate(),'''''''''''' + @Userid + '''''''''''' 
	from [FACT_'''' + @Model + ''''_default_partition] as F 
	left join [#DS_Account] as DA on DA.[MemberId]=F.['''' + @AccountDim + ''''_MemberId] 
	left join ['''' + @Tmp_Eliminated + ''''] as TE on F.['''' + @EntityDim + ''''_MemberId]=TE.[Entity_MemberId] 
	-- and F.['''' + @IntercompanyDim + ''''_MemberId]=TE.[Intercompany_MemberId]
	left join 
		--(
		---- get base level members of only parents with an elim child at this level
		--select HLA.['''' + @ParLvl + ''''] as ParentMbr,HLB.[ElimMbr],['''' + @BaseLvl + ''''] as BaseMbr from ['''' + @EntityHierTbl + ''''] as HLA
		--left join (
		--	-- get parents with an elim child at this level
		--	select ['''' + @ParLvl + ''''] as PMbr,['''' + @ChildLvl + ''''] as ElimMbr from ['''' + @EntityHierTbl + ''''] as ELA 
		--	left join [DS_'''' + @EntityDim + ''''] as ELB on ELA.['''' + @ChildLvl + ''''] = ELB.[MemberId] 
		--	where ELA.['''' + @ParLvl + ''''] <> ELA.['''' + @ChildLvl + ''''] and ELB.[Elim] = ''''''''True''''''''
		--) as HLB on HLA.['''' + @ParLvl + ''''] = HLB.[PMbr]
		--)  ' 

			SET @SQLStatement = @SQLStatement + '

		#level as G on F.['''' + @EntityDim + ''''_MemberId] = G.[BaseMbr]
	left join ['''' + @EntityHierTbl + ''''] as HL on F.['''' + @EntityDim + ''''_MemberId] = HL.['''' + @BaseLvl + '''']
	where  
	DA.ICELIM_MemberId > 0 ''''
	if @CurrencyDim is not null
	begin
		set @Stmt = @Stmt + '''' and F.['''' + @CurrencyDim + ''''_MemberId] > 0 ''''
	end
	set @Stmt = @Stmt +
	'''' 
	--and F.['''' + @IntercompanyDim + ''''_MemberId] in (
	--	select ICC.[MemberId] as IC_MemberId from ['''' + @EntityHierTbl + ''''] as ICA
	--	left join [DS_'''' + @EntityDim + ''''] as ICB on ICA.['''' + @BaseLvl + ''''] = ICB.[MemberId]
	--	left join [DS_'''' + @IntercompanyDim + ''''] as ICC on ICB.[Label] = ICC.['''' + @EntityDim + '''']
	--	where ICC.[MemberId] is not null and ICA.['''' + @ParLvl + ''''] = HL.['''' + @ParLvl + '''']
	--)
	and F.['''' + @BusinessProcessDim + ''''_MemberId]  in (select [MemberId] from [DS_'''' + @BusinessProcessDim + ''''] where [NoAutoElim]=''''''''False'''''''')
	and F.['''' + @ScenarioDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]='''''''''''' + @ScenarioMbrs + '''''''''''') 
	and F.['''' + @TimeDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]='''''''''''' + @TimeMbrs + '''''''''''') ''''
	IF @IsRound = 1 Set @Stmt = @Stmt + '''' 
	and ['''' + @RoundDim + ''''_MemberId] in (select MemberId from ['''' + @TempTbl + ''''] where [ParameterName]=''''''''RoundMbrs'''''''') ''''
	Set @Stmt = @Stmt + ''''  
	and F.['''' + @EntityDim + ''''_MemberId] in (select ['''' + @BaseLvl + ''''] from ['''' + @EntityHierTbl + ''''] where ['''' + @ParLvl + ''''] in (
		select ['''' + @ParLvl + ''''] as Parent from ['''' + @EntityHierTbl + ''''] as A 
		left join [DS_'''' + @EntityDim +''''] as B on A.['''' + @ChildLvl + ''''] = B.[MemberId] 
		where A.['''' + @ParLvl + ''''] <> A.['''' + @ChildLvl + ''''] and B.[Elim] = ''''''''True''''''''))''''
	--and TE.[Intercompany_MemberId] is null''''

	--print ''''''''
	--print ''''generate elimination records for level - '''' + @ParLvl

	exec(@Stmt + ''''
	and TE.[Entity_MemberId] is null
	And DA.[ICELIM_Holding] = 1 ''''
	+@Stmt2 )

	--Print(@Stmt + ''''
	--And DA.[ICELIM_Holding] = 0
	--And F.['''' + @EntityDim + ''''_MemberId] Not in (Select Holding_memberid from [DS_''''+@EntityDim+''''])'''')

	IF @CountTmp > 0
	BEGIN
		exec(@Stmt + ''''
		And ((TE.[Entity_MemberId]  is null) OR (TE.[holding]=1 and TE.NEW = 1))
		And DA.[ICELIM_Holding] = 0
		And F.['''' + @EntityDim + ''''_MemberId] Not in (Select HoldingMbr  from #Level)
--		And F.['''' + @EntityDim + ''''_MemberId] <> ''''+@Holding+'''' 
		And F.['''' + @EntityDim + ''''_MemberId] Not in (Select Entity_memberid from [#Tmp_Eliminated] where holding = 1 And New > 1) ''''
		+@Stmt2 )
	END ' 

			SET @SQLStatement = @SQLStatement + '

	ELSE
	BEGIN
		exec(@Stmt + ''''
		and TE.[Entity_MemberId] is null
		And DA.[ICELIM_Holding] = 0
		And F.['''' + @EntityDim + ''''_MemberId] Not in (Select HoldingMbr  from #Level)
--		And F.['''' + @EntityDim + ''''_MemberId] <> ''''+@Holding+'''' 
		And F.['''' + @EntityDim + ''''_MemberId] Not in (Select Holding_memberid from [DS_''''+@EntityDim+'''']) ''''
		+@Stmt2 )
	END	
	
	--''''insert into ['''' + @Tmp_Eliminated + ''''] ([Entity_MemberId],[Intercompany_MemberId],[Holding])

	-- add records to list of already Eliminated points in the Entity-Intercompany dimensions

	Update #Tmp_Eliminated Set New = New + 1
	Update #Tmp_Eliminated Set New = 1,Holding = 0  where Holding = 1 and New <=1
		
	set @Stmt =
	''''insert into ['''' + @Tmp_Eliminated + ''''] ([Entity_MemberId],[Intercompany_MemberId],[Holding],[New])
	select distinct
	HE.['''' + @BaseLvl + ''''] as [Entity_MemberId],
	-1,0,1
	from (select * from ['''' + @EntityHierTbl + ''''], [DS_'''' + @IntercompanyDim + '''']) as HE
	left join [DS_'''' + @EntityDim + ''''] as DE on DE.[MemberId]=HE.['''' + @BaseLvl + '''']
	left join ['''' + @Tmp_Eliminated + ''''] as TE on HE.['''' + @BaseLvl + '''']=TE.[Entity_MemberId] and HE.[MemberId]=TE.[Intercompany_MemberId]
	left join (
		-- get base level members of only parents with an elim child at this level
		select HLA.['''' + @ParLvl + ''''] as [ParentMbr],['''' + @BaseLvl + ''''] as [BaseMbr] from ['''' + @EntityHierTbl + ''''] as HLA
		left join (
			-- get parents with an elim child at this level
			select ['''' + @ParLvl + ''''] as [PMbr] from ['''' + @EntityHierTbl + ''''] as ELA 
			left join [DS_'''' + @EntityDim + ''''] as ELB on ELA.['''' + @ChildLvl + ''''] = ELB.[MemberId] 
			where ELA.['''' + @ParLvl + ''''] <> ELA.['''' + @ChildLvl + ''''] and ELB.[Elim] = ''''''''True''''''''
		) as HLB on HLA.['''' + @ParLvl + ''''] = HLB.[PMbr]
	) as G on HE.['''' + @ChildLvl + ''''] = G.[BaseMbr]
	where  
	HE.[MemberId] in (
		-- only include intercompany members that part of this parents branch of the hierarchy
		select ICC.[MemberId] as [IC_MemberId] from ['''' + @EntityHierTbl + ''''] as ICA
		left join [DS_'''' + @EntityDim + ''''] as ICB on ICA.['''' + @BaseLvl + ''''] = ICB.[MemberId]
		left join [DS_'''' + @IntercompanyDim + ''''] as ICC on ICB.[Label] = ICC.['''' + @EntityDim + '''']
		where ICC.[MemberId] is not null and ICA.['''' + @ParLvl + ''''] = HE.['''' + @ParLvl + '''']
	)
	and HE.['''' + @BaseLvl + ''''] in (
		select ['''' + @BaseLvl + ''''] from ['''' + @EntityHierTbl + ''''] where ['''' + @ParLvl + ''''] in (
		-- only include parents with an elim child at this level
		select ['''' + @ParLvl + ''''] as [Parent] from ['''' + @EntityHierTbl + ''''] as A 
		left join [DS_'''' + @EntityDim + ''''] as B on A.['''' + @ChildLvl + ''''] = B.[MemberId] 
		where A.['''' + @ParLvl + ''''] <> A.['''' + @ChildLvl + ''''] and B.[Elim] = ''''''''True''''''''
		)
	)
	-- only include intercompany members not eliminated at lower levels of the hierarchy
	and TE.[Entity_MemberId] is null
	and TE.[Intercompany_MemberId] is null''''

	--print ''''add to list of already eliminated points in Entity-Intercompany dimension''''
	exec(@Stmt)

	Set @Stmt = ''''Update ['''' + @Tmp_Eliminated + ''''] Set Holding = 1 where Entity_Memberid in (Select Holding_memberid From [DS_''''+@EntityDim+'''']) 
	And New = 1 ''''
	exec(@Stmt)
	set @num = @num + 1 ' 

			SET @SQLStatement = @SQLStatement + '



	set @ChildLvl = @ParLvl
	-- end Level procesing
	fetch next from Level_cursor into @ParLvl
	end
	close Level_cursor
	deallocate Level_cursor

	--exec(''''drop table ['''' + @Tmp_Eliminated + '''']'''')

	drop table [#Tmp_Eliminated]
	-- end Hierarchy processing
	fetch next from Hier_cursor into @HierLabel
end
close Hier_cursor
deallocate Hier_cursor

drop table #DS_account
Drop table #temp,#level,#tempI
-- drop table #Tmp_Eliminated, #level,#tempi
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END








/****** Object:  StoredProcedure [dbo].[Canvas_LST_Comments]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_AR_Calculate_Aging'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_AR_AP_Calculate_Aging') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  

  PROCEDURE  [dbo].[Canvas_LST_Comments]
	@ModelName as nvarchar(255),
	@RecordId nvarchar(255),
	@DebutRow nvarchar(255),
	@NBRow nvarchar(255),
	@DebutCol nvarchar(255),
	@NBCol nvarchar(255),
	@StartPeriod nvarchar(255) = ''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--declare
--	@ModelName as nvarchar(255),
--	@RecordId nvarchar(255),
--	@DebutRow nvarchar(255),
--	@NBRow nvarchar(255),
--	@DebutCol nvarchar(255),
--	@NBCol nvarchar(255),
--	@StartPeriod nvarchar(255) = ''''''''

--	SET @ModelName = ''''financials''''
--	SET @RecordId =''''1''''
--	SET @DebutRow =''''12''''
--	SET @NBRow =''''6''''
--	SET @DebutCol=''''12''''
--	SET @NBCol =''''12''''
--	SET @StartPeriod  = ''''''''

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @Sql NVARCHAR(MAX), @Scenario NVARCHAR(255),@Time NVARCHAR(255),@Schedule_ID INT,@V1 INT,@V2 INT,@NBDriver INT
	,@Select NVARCHAR(MAX),@Where NVARCHAR(MAX),@Insert NVARCHAR(MAX),@Values NVARCHAR(MAX),@TestRow INT
	,@Scenario_ID INT,@Schedule Nvarchar(255)
	DECLARE @Lap INT

	SELECT @NBdriver = MAX(Driver_Number) From Canvas_Workflow_Segment Where Segment_type = ''''Segment_Driver'''' And Model = @ModelName
	
	
	SELECT @Schedule = b.Schedule_template From Canvas_Workflow_Detail a,Canvas_Workflow_Schedule b 
	Where a.RecordId = @RecordId And a.Schedule = b.Label and a.Model = @ModelName and a.model = b.model
	
	CREATE TABLE #TempI (Memberid BigInt)
	CREATE TABLE #TempN (label Nvarchar(255))
	Declare @Dname nvarchar(255),@D Nvarchar(255) ,@D_memberid BIGINT
	
	SEt @Lap = 1
	SET @Where = '''' ''''
	While @lap <= @NbDriver 
	BEGIN
		
		Select @DName = Dimension From Canvas_Workflow_Segment Where Segment_type = ''''Segment_Driver'''' and Driver_Number = @Lap  And Model = @ModelName

		TRUNCATE TABLE #TempN
		Set @Sql = ''''INSERT INTO #TempN Select ''''+@Dname+'''' From Canvas_Workflow_Detail Where RecordId = ''''+@RecordId+'''' and Model = ''''''''''''+@ModelName+''''''''''''''''
		EXEC(@Sql)
		Select @D = label From #TempN  

		TRUNCATE TABLE #tempI
		SET @sql = ''''INSERT INTO #TempI Select memberid From DS_''''+@Dname+'''' Where label = ''''''''''''+@D+''''''''''''''''
		EXEC(@Sql)
		Select @D_memberid = memberid From #TempI

		SET @WHERE = @WHERE + '''' 
		And ''''+@Dname + ''''_Memberid = ''''+CAST(@D_Memberid AS CHAR) 

		SET @lap = @lap + 1
	END ' 

			SET @SQLStatement = @SQLStatement + '

    SELECT @Scenario = Dimension FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Scenario'''' And Model = @ModelName
    SELECT @Time = Dimension FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Time'''' And Model = @ModelName
	SELECT @Schedule_ID = RecordId FROM Canvas_Workflow_Schedule WHERE Schedule_Template = REPLACE(@Schedule,''''.Xlsm'''','''''''') and model = @ModelName

--    SELECT @D1 = Dimension FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Segment_Driver'''' AND Driver_Number = 1


	SET @Sql = ''''INSERT INTO #TempI SELECT Memberid From DS_''''+@Scenario+'''' a, Canvas_Workflow_Reforecast b 
	Where a.Label = b.Scenario And b.Active = ''''''''True'''''''' And b.Model = ''''''''''''+@ModelName+''''''''''''''''
	EXEC(@Sql)
	SELECT @Scenario_id = memberid FROM #TempI
    
	Create table #time (Memberid Bigint)
	If @StartPeriod <> '''''''' 
	BEGIN
		SET @Lap = 1 
		Declare @Timelap Nvarchar(255)
		While @Lap <= @Nbcol
		BEGIN
			Set @TimeLap = Year(DATEADD(Month,@Lap,@StartPeriod+''''01''''))*100 + Month(DATEADD(Month,@Lap,@StartPeriod+''''01''''))

			SET @Sql = ''''INSERT INTO #Time SELECT Memberid From DS_''''+@Time+'''' 
			Where Label = ''''''''''''+@TimeLap+'''''''''''' ''''
			Print(@Sql)
			EXEC(@Sql)
			SET @Lap = @Lap + 1
		END
	END
	ELSE
	BEGIN
		SET @Sql = ''''INSERT INTO #Time SELECT Memberid From DS_''''+@Time+'''' a, Canvas_Workflow_Reforecast b 
		Where Left(a.Label,4) = left(b.Startperiod,4) And b.Active = ''''''''True'''''''' 
		And Substring(a.label,5,2) >= Substring(b.Startperiod,5,2) 
		And Substring(a.label,5,1) Not in (''''''''Q'''''''',''''''''S'''''''') And b.Model = ''''''''''''+@ModelName+'''''''''''' ''''
		EXEC(@Sql)
	END

	SELECT @Scenario_id = memberid FROM #TempI
	--SET @Sql = ''''INSERT INTO #TempI SELECT Memberid From DS_''''+@D1+'''' Where Label = ''''''''''''+@Driver1+''''''''''''''''
	--EXEC(@Sql)
	--SELECT @D1_Memberid = memberid FROM #TempI

	SET @select = '''' SELECT [RowNum] '''' 
	SET @Insert = ''''INSERT INTO #Temp (''''
	SET @Values = '''' VALUES (''''

	CREATE TABLE #Temp (RowNum Int)
	SET @Lap = 1 
	WHILE @Lap <= @NBCol
	BEGIN
		SET @Sql = ''''ALTER TABLE #Temp ADD COL''''+CAST(@Lap AS CHAR)+'''' Nvarchar(255)''''
		EXEC(@Sql)
		
		IF @lap > 1 SET @Insert = @Insert + '''',''''
		IF @lap > 1 SET @Values = @Values + '''',''''
		SET @Insert = @Insert + ''''COL''''+RTRIM(CAST(@Lap AS CHAR))
		SET @VAlues = @Values + ''''''''''''''''''''''''
		
		SET @Lap = @Lap + 1 
	END

	SELECT * INTO #tempFinal FROM #temp 


	SET @Lap = 1 
	WHILE @Lap <= @NBCol
	BEGIN ' 

			SET @SQLStatement = @SQLStatement + '

		SET @select = @Select + '''',MAX(Col'''' + RTRIM(CAST(@Lap AS CHAR)) + '''')'''' 
		SET @Sql = '''' INSERT INTO #Temp Select [Row] ''''  
		+ REPLICATE('''','''''''''''''''''''',@Lap-1) + '''',''''+@ModelName+''''_Text''''+ REPLICATE('''','''''''''''''''''''',@NBCol - @Lap ) + ''''
		From Fact_''''+@ModelName+''''_Text
		WHere Schedule_recordId = ''''+CAST(@Schedule_ID AS CHAR)+'''' 
		And Col = ''''+CAST(@Lap + @DebutCol- 1 AS char)+'''' 
		And ''''+@Scenario + ''''_Memberid = ''''+CAST(@Scenario_id AS CHAR)+'''' 
		And ''''+@Time + ''''_Memberid In (Select memberid from #time) ''''
		+@Where 
--		And ''''+@D1 + ''''_Memberid = ''''+CAST(@D1_Memberid AS CHAR) +'''' 
		EXEC(@Sql)
		SET @Lap = @Lap + 1 
	END
	
	SET @Lap = CAST(@DebutRow AS INT)
	
	WHILE @Lap <= CAST(@DebutRow AS INT)+CAST(@NBRow AS INT)
	BEGIN
		SELECT @TestRow = RowNum FROM #Temp WHERE RowNum = @Lap
		IF @@ROWCOUNT = 0 
		BEGIN
			SET @Sql = @Insert  + '''',RowNum)'''' + @Values + '''','''' + RTRIM(CAST(@Lap AS CHAR))+'''')''''		
			EXEC(@Sql)
		END
		SET @Lap = @Lap + 1 
	END

	SET @Sql = ''''INSERT INTO #tempFinal ''''+@Select+ ''''
	FROM #temp 
	GROUP BY Rownum
	ORDER BY [rownum]'''' 
	EXEC(@Sql)


	SELECT * FROM #tempFinal ORDER BY [RowNum]
	
END '

IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

-- drop TABLE #tempI,#tempN,#time,#temp,#tempFinal







/****** Object:  StoredProcedure [dbo].[Canvas_LST_CommentsList]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_CommentsList'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_CommentsList') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_CommentsList]
	@ModelName as nvarchar(255),
	@Schedule nvarchar(255),
	@Driver1 nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS


--Declare	@ModelName as nvarchar(255),
--	@Schedule nvarchar(255),
--	@Driver1 nvarchar(255)

--set @modelname = ''''Financials''''
--set @Schedule = ''''false''''
--set @driver1= ''''false''''




BEGIN
	SET NOCOUNT ON;

	UPDATE Canvas_Workflow_Schedule Set Dimrow = '''''''' Where dimrow is null
	UPDATE Canvas_Workflow_Schedule Set DimCol = '''''''' Where dimcol is null


	IF @Driver1 IN (''''False'''',''''No'''') SET @Driver1 = ''''''''
	IF @Schedule IN (''''False'''',''''No'''') SET @schedule = ''''''''
	
	DECLARE @Sql NVARCHAR(MAX),@Scenario NVARCHAR(255),@Schedule_ID INT
	,@Where NVARCHAR(MAX),@Driver1Name NVARCHAR(255),@Driver1Memberid BIGINT,@TestRow INT
	,@Scenario_ID INT,@lap INT,@maxlap INT,@time NVARCHAR(255),@time_label NVARCHAR(255),@time_ID Bigint
	,@dimrow Nvarchar(255),@dimcol nvarchar(255),@scenariodim nvarchar(50),@Timedim nvarchar(50)

	SELECT @Time = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Time'''' And Model = @ModelName
	SELECT @Time_label = defaultvalue FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Time'''' And Model = @ModelName

    SELECT @Scenario = Dimension FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Scenario'''' And Model = @ModelName
	SELECT @Schedule_ID = RecordId FROM Canvas_Workflow_Schedule WHERE Schedule_Template = REPLACE(@Schedule,''''.Xlsm'''','''''''') and model = @ModelName


	CREATE TABLE #TempI (Memberid BigInt)
	CREATE TABLE #TempN (label Nvarchar(255))
	Declare @Dname nvarchar(255),@D Nvarchar(255) ,@D_memberid BIGINT,@NbDriver INT,@ALTER Nvarchar(max),@Select Nvarchar(max)

--	SELECT @NBdriver = MAX(Driver_Number) From Canvas_Workflow_Segment Where Segment_type = ''''Segment_Driver''''
	SELECT @NBdriver = 8

	CREATE TABLE #temp (UserName nvarchar(255),ChangeDateTime DATETIME,Schedule_ID BIGINT)
	
print ''''111111'''' 

	SEt @Lap = 1
	SET @Where = '''' ''''
	SET @Select = '''' ''''
	SET @Alter = ''''ALTER TABLE #Temp ADD  ''''
	While @lap <= @NbDriver 
	BEGIN
print @nbdriver
print ''''222222'''' 
		
		Select @DName = Dimension From Canvas_Workflow_Segment Where Segment_type = ''''Segment_Driver'''' and Driver_Number = @Lap  And Model = @ModelName
		If @@ROWCOUNT = 0 
		BEGIN
			SET @Dname = ''''Driver''''+RTRIM(CAst(@Lap as char))
			SET @Select = @Select + '''','''''''''''''''' AS ''''+@Dname+''''_Memberid''''
		END
		ELSE
		BEGIN
		TRUNCATE TABLE #TempN
			SET @Select = @Select + '''' 
			,''''+@Dname+''''_Memberid''''
		END

		IF @lap > 1 SET @Alter = @alter + '''','''' 
		SEt @ALTER = @ALTER + @Dname +''''_Memberid Nvarchar(255) ''''

		SET @lap = @lap + 1
	END

	EXEC(@ALTER) ' 

			SET @SQLStatement = @SQLStatement + '


	ALTER Table #temp ADD DimRow_Memberid Nvarchar(255),DimCol_Memberid Nvarchar(255),Comment NVARCHAR(255),DimRow Nvarchar(255),DimCol Nvarchar(255)

	SELECT @Driver1Name = Dimension FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Segment_Driver'''' AND Driver_Number = 1 And Model = @ModelName

	CREATE TABLE #Time (memberid BigINT)

	Select @DimRow = DimRow From Canvas_Workflow_Schedule Where Model = @modelname
	Select @DimCol = DimCol From Canvas_Workflow_Schedule Where Model = @modelname

	SET @WHERE = '''' ''''
	IF @DimRow = ''''Time'''' SET @Where = @Where + '''' AND ''''+@DimRow+''''_memberid in (Select Memberid From #Time)'''' 
	IF @DimCol = ''''Time'''' SET @Where = @Where + '''' AND ''''+@DimCol+''''_memberid in (Select Memberid From #Time)'''' 
    
	TRUNCATE TABLE #TempI
	SET @Sql = ''''INSERT INTO #TempI SELECT Memberid From DS_''''+@Time+'''' Where Label = ''''''''''''+@Time_Label+''''''''''''''''
	EXEC(@Sql)
	SELECT @Time_ID = memberid FROM #TempI

	TRUNCATE TABLE #TempI
	SET @Sql = ''''INSERT INTO #TempI SELECT Memberid From DS_''''+@Driver1NAme+'''' Where Label = ''''''''''''+@Driver1+''''''''''''''''
	EXEC(@Sql)
	SELECT @Driver1Memberid = memberid FROM #TempI

	TRUNCATE TABLE #TempI
	SET @Sql = ''''INSERT INTO #TempI SELECT Memberid From DS_''''+@Scenario+'''' a, canvas_workflow_reforecast b 
	Where a.Label = b.scenario And b.active = ''''''''True'''''''' And b.Model = ''''''''''''+@ModelName+'''''''''''' ''''
	EXEC(@Sql)
	SELECT @Scenario_id = memberid FROM #TempI

	SET @Sql = ''''INSERT INTO #time 
	SELECT Distinct b.memberid FROM DS_''''+@Time+'''' a, HC_Time b 
	WHERE a.memberid = b.memberid and b.ParentId = ''''+RTRIM(CAST(@Time_ID AS CHAR))
	Print (@Sql)
	EXEC(@Sql)

	Create table #tempdim (id INT identity(1,1),Dimrow nvarchar(255),dimcol nvarchar(255))
	Insert into #tempdim 
	select Distinct DimRow,DimCol 
	FROM (
	select Distinct DimRow,DimCol from canvas_workflow_Schedule Where Dimrow <> '''''''' and DimCol <> ''''''''  and model = @ModelName
	UNION ALL
	Select Distinct ''''Account'''',''''Time'''' from canvas_workflow_Schedule
	) As tmp
	

	SET @maxlap = @@Rowcount
--	SET @maxlap = 2
	SEt @Lap = 1

	DECLARE @ROWCOL Nvarchar(500),@OLDROWCOL Nvarchar(500)
	SET @OLDROWCOL = ''''''''
	While @lap <= @maxlap
	BEGIn

		Select @DimRow = Dimrow from #tempdim where id = @lap
		Select @DimCol = DimCol from #tempdim where id = @lap
		SET @ROWCOL = @DimRow+''''|''''+@DimCol ' 

			SET @SQLStatement = @SQLStatement + '


		IF @ROWCOL <> @OLDROWCOL
		BEGIN
			INSERT INTO #temp 
			(DimRow_Memberid,DimCol_Memberid,Comment)
			VALUES (@DimRow,@DimCol,'''''''')
		END

Print ''''INSERT INTO #temp Select UserId,ChangeDateTime,Schedule_recordId ''''
print @Select +'''',''''+@DimRow+''''_memberid,''''+@DimCol+''''_memberid,''''+@ModelName+''''_text ,''''''''''''+@DimRow+'''''''''''',''''''''''''+@DimCol +''''''''''''''''
Print ''''FROM FACT_''''+@Modelname+''''_text ''''
print ''''		WHERE ''''+@Scenario +''''_memberid  = ''''+RTRIM(CAST(@Scenario_id AS char))
print '''' And ''''+@Time+''''_Memberid IN (Select memberid from #time) ''''
print ''''		And schedule_recordid in (Select recordId from Canvas_Workflow_schedule where DimRow in (''''''''''''+@DimRow+'''''''''''','''''''''''''''') And DimCol in (''''''''''''+@DimCol+'''''''''''','''''''''''''''') and model = ''''''''''''+@ModelName+'''''''''''')''''
print ''''		And ''''+@Modelname+''''_text  <> '''''''''''''''' '''' 


		SET @Sql = ''''INSERT INTO #temp Select UserId,ChangeDateTime,Schedule_recordId ''''
		+@Select +'''',''''+@DimRow+''''_memberid,''''+@DimCol+''''_memberid,''''+@ModelName+''''_text ,''''''''''''+@DimRow+'''''''''''',''''''''''''+@DimCol +''''''''''''
		FROM FACT_''''+@Modelname+''''_text 
		WHERE ''''+@Scenario +''''_memberid  = ''''+RTRIM(CAST(@Scenario_id AS char))
		+'''' And ''''+@Time+''''_Memberid IN (Select memberid from #time) 
		And schedule_recordid in (Select recordId from Canvas_Workflow_schedule where DimRow in (''''''''''''+@DimRow+'''''''''''','''''''''''''''') And DimCol in (''''''''''''+@DimCol+'''''''''''','''''''''''''''') and model = ''''''''''''+@ModelName+'''''''''''')
		And ''''+@Modelname+''''_text  <> '''''''''''''''' '''' 
	
		IF @Schedule <> '''''''' SEt @Sql = @Sql + '''' AND Schedule_recordId = ''''+RTRIM(CAST(@Schedule_id AS char)) 
		IF @Driver1 <> '''''''' SET @Sql = @Sql + '''' AND ''''+@Driver1name+''''_memberid In (Select Memberid From HC_''''+@Driver1Name+'''' Where ParentId = ''''+RTRIM(CAST(@Driver1Memberid AS char)) +'''')''''

		SET @Sql = @Sql + @Where

		PRINT(@Sql)
		EXEC(@Sql)

		IF @@ROWCOUNT =  0 DELETE FROM #temp Where DimCol_memberid = @DimCol and DimRow_memberid = @DimRow And Comment = ''''''''

		SET @SQL = ''''UPDATE #Temp SET DimROW_Memberid = b.Label FROM #Temp a,DS_''''+@DimROw+'''' b WHere CAST(a.DimRow_Memberid as INT) = b.Memberid And username <> '''''''''''''''' 
		And DimRow = ''''''''''''+@DimRow+'''''''''''' And DimCol = ''''''''''''+@DimCol+''''''''''''''''
		EXEC(@Sql)
		SET @SQL = ''''UPDATE #Temp SET DimCOl_Memberid = b.Label FROM #Temp a,DS_''''+@DimCol+'''' b WHere CAST(a.DimCol_Memberid as INT) = b.Memberid  And username <> '''''''''''''''' 
		And DimRow = ''''''''''''+@DimRow+'''''''''''' And DimCol = ''''''''''''+@DimCol+''''''''''''''''
		EXEC(@Sql)
		SET @Lap = @Lap + 1

	END 

	SEt @Lap = 1
	While @lap <= @NbDriver 
	BEGIN
		
		Select @DName = Dimension From Canvas_Workflow_Segment Where Segment_type = ''''Segment_Driver'''' and Driver_Number = @Lap  And Model = @ModelName
		If @@ROWCOUNT <> 0 
		BEGIN
			SET @SQL = ''''UPDATE #Temp SET ''''+@Dname+''''_Memberid = b.Label FROM #Temp a,DS_''''+@DName+'''' b WHere CAST(a.''''+@Dname+''''_Memberid as INT) = b.Memberid  And username <> '''''''''''''''''''' 
		    EXEC(@Sql)
		END

	SET @Lap = @Lap + 1
	END



	SELECT * FROM #temp
	
END '

IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

-- drop table #temp,#tempI,#tempN,#Time,#tempdim





/****** Object:  StoredProcedure [dbo].[Canvas_LST_CommentsUpdate]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_CommentsUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_CommentsUpdate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_CommentsUpdate]
	@ModelName as nvarchar(255),
	@UserName as nvarchar(255),
	@InfoRow AS nvarchar(255),
	@InfoCol nvarchar(255),
	@RecordId nvarchar(255),
	@InfoAddress nvarchar(255) ,@Comment NVARCHAR(255),
	@CommentType NVARCHAR(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

----=====================================================
----=====================================================
--	DECLARE @ModelName as nvarchar(255),@UserName as nvarchar(255),@InfoRow AS nvarchar(255),@InfoCol nvarchar(255),@RecordId nvarchar(255),@InfoAddress nvarchar(255),
--	@Comment NVARCHAR(255),	@CommentType NVARCHAR(255)
--	SET	@ModelName = ''''Financials''''
--	SET @UserName = ''''Administrator''''
--	SET	@InfoRow = ''''FullAccount|53840-921-00000-00000000-SLX''''
--	SET @InfoCol = ''''Time|201701''''
--	SET @RecordId = ''''2601''''
--	SET @InfoAddress = ''''12|10''''
--	SET @Comment = ''''CCCCCC''''
--	SET @CommentType = ''''New''''
----=====================================================
----=====================================================

BEGIN
	
	SET NOCOUNT ON;

	IF @Comment IN (''''False'''','''' '''') SET @Comment = '''''''' 

	DECLARE	@DimRow AS nvarchar(255),	@MemberRow nvarchar(255),	@DimCol nvarchar(255),
	@MemberCol nvarchar(255),	@DriverName nvarchar(255),	@Driver nvarchar(255),
	@RowNum nvarchar(255) ,	@ColNum nvarchar(255) ,	@V INT,@winuser NVARCHAR(100)
	DECLARE @Sql NVARCHAR(MAX),@Scenario NVARCHAR(255),@ScenarioID NVARCHAR(255),@ScenarioLabel NVARCHAR(255),@Ret INT
	,@IdCol INT, @IDRow INT, @IDDriver INT,@Schedule_ID INT	,@NbDriver INT,@Schedule Nvarchar(255)
 
	CREATE TABLE #Temp (Comment Nvarchar(255))
	CREATE TABLE #TempN (Label Nvarchar(255))
	CREATE TABLE #TempID (MemberID INT)


	TRUNCATE TABLE #TempN
	SET @Sql = ''''INSERT INTO #TempN Select b.Name from sysobjects a, Syscolumns b Where a.id = b.id and a.Name = ''''''''FACT_''''+@ModelName+''''_Text'''''''' and b.name = ''''''''Row'''''''' ''''
	EXEC(@Sql)
	IF @@ROWCOUNT = 0
	BEGIN
		SET @SQL = ''''ALTER TABLE FACT_''''+@ModelName+''''_Text ADD [Row] [Bigint] NULL ''''
		EXEC(@Sql)
		SET @SQL = ''''ALTER TABLE FACT_''''+@ModelName+''''_Text  ADD  CONSTRAINT [DF_FACT_''''+@ModelName+''''_text_Row]  DEFAULT ((-1)) FOR [Row] ''''
		EXEC(@Sql)
	END   
	TRUNCATE TABLE #TempN
	SET @Sql = ''''INSERT INTO #TempN Select b.Name from sysobjects a, Syscolumns b Where a.id = b.id and a.Name = ''''''''FACT_''''+@ModelName+''''_Text'''''''' and b.name = ''''''''Col'''''''' ''''
	EXEC(@Sql)
	IF @@ROWCOUNT = 0
	BEGIN
		SET @SQL = ''''ALTER TABLE FACT_''''+@ModelName+''''_Text ADD [Col] [Bigint] NULL ''''
		EXEC(@Sql)
		SET @SQL = ''''ALTER TABLE FACT_''''+@ModelName+''''_Text  ADD  CONSTRAINT [DF_FACT_''''+@ModelName+''''_text_Col]  DEFAULT ((-1)) FOR [Col] ''''
		EXEC(@Sql)
	END   
	TRUNCATE TABLE #TempN
	SET @Sql = ''''INSERT INTO #TempN Select b.Name from sysobjects a, Syscolumns b Where a.id = b.id and a.Name = ''''''''FACT_''''+@ModelName+''''_Text'''''''' and b.name = ''''''''Schedule_RecordId'''''''' ''''
	EXEC(@Sql)
	IF @@ROWCOUNT = 0
	BEGIN
		SET @SQL = ''''ALTER TABLE FACT_''''+@ModelName+''''_Text ADD [Schedule_RecordId] [Bigint] NULL ''''
		EXEC(@Sql)
		SET @SQL = ''''ALTER TABLE FACT_''''+@ModelName+''''_Text  ADD  CONSTRAINT [DF_FACT_''''+@ModelName+''''_text_Schedule_RecordId]  DEFAULT ((-1)) FOR [Schedule_RecordId] ''''
		EXEC(@Sql)
	END   

			
	TRUNCATE TABLE #TempN

	SELECT @WinUser = WinUser FROM canvas_users WHERE label = @Username 
	IF @@ROWCOUNT = 0 SET @Winuser = @Username 
	
	SET @V = CHARINDEX(''''|'''',@InfoRow,1)
	SET @DimRow = SUBSTRING(@InfoRow,1,@V-1)
	SET @MemberRow = SUBSTRING(@InfoRow,@V+1,255)

	SET @V = CHARINDEX(''''|'''',@InfoCol,1)
	SET @DimCol = SUBSTRING(@InfoCol,1,@V-1)
	SET @MemberCol = SUBSTRING(@InfoCol,@V+1,255)

	--SET @V = CHARINDEX(''''|'''',@InfoDriver,1)
	--SET @DriverName = SUBSTRING(@InfoDriver,1,@V-1)
	--SET @Driver = SUBSTRING(@InfoDriver,@V+1,255)

	SET @V = CHARINDEX(''''|'''',@InfoAddress,1)
	SET @RowNum = SUBSTRING(@InfoAddress,1,@V-1)
	SET @ColNum = SUBSTRING(@InfoAddress,@V+1,255) ' 

			SET @SQLStatement = @SQLStatement + '

   
	SELECT @NBdriver = MAX(Driver_Number) From Canvas_Workflow_Segment Where Segment_type = ''''Segment_Driver'''' And Model = @ModelName

	SELECT @Schedule = b.Schedule_template From Canvas_Workflow_Detail a,Canvas_Workflow_Schedule b 
	Where a.RecordId = @RecordId And a.Schedule = b.Label  and a.Model = @ModelName and a.model = b.model

	DECLARE @lap INT, @INSERT Nvarchar(MAX),@VALUES NVARCHAR(MAX),@DName Nvarchar(255),@D Nvarchar(255),@D_memberid BIGINT,@Where Nvarchar(max)
	SEt @Lap = 1
	SET @INSERT = '''' ''''
	SET @VALUES = '''' ''''
	SET @WHERE = '''' ''''
	While @lap <= @NbDriver 
	BEGIN
		
		Select @DName = Dimension From Canvas_Workflow_Segment Where Segment_type = ''''Segment_Driver'''' and Driver_Number = @Lap  And Model = @ModelName

		TRUNCATE TABLE #TempN
		Set @Sql = ''''INSERT INTO #TempN Select ''''+@Dname+'''' From Canvas_Workflow_Detail Where RecordId = ''''+@RecordId+'''' And Model = ''''''''''''+@ModelName+'''''''''''' ''''
		EXEC(@Sql)
		Select @D = label From #TempN  

		TRUNCATE TABLE #tempID
		SET @sql = ''''INSERT INTO #TempID Select memberid From DS_''''+@Dname+'''' Where label = ''''''''''''+@D+''''''''''''''''
		EXEC(@Sql)
		Select @D_memberid = memberid From #TempID

		SET @INsert = @INSERT + '''',''''+@Dname+''''_Memberid'''' 
		SET @Values = @VAlues + '''',''''+CAST(@D_Memberid as Char)
		SET @WHERE = @WHERE + '''' 
		And ''''+@Dname + ''''_Memberid = ''''+CAST(@D_Memberid AS CHAR) 

		SET @lap = @lap + 1
	END


    SELECT @Scenario = Dimension FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Scenario'''' And Model = @ModelName
    --SELECT @ScenarioLabel = DefaultValue FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Scenario''''
	SELECT @Schedule_ID = RecordId FROM Canvas_Workflow_Schedule WHERE Schedule_Template = REPLACE(@Schedule,''''.Xlsm'''','''''''') and model = @ModelName
	
	TRUNCATE TABLE #TempID
	SET @Sql = ''''INSERT INTO #TempID SELECT Memberid From DS_''''+@Scenario+'''' a, Canvas_Workflow_Reforecast b 
	Where a.Label = b.Scenario And b.Active = ''''''''True'''''''' And b.Model = ''''''''''''+@ModelName+'''''''''''' ''''
	EXEC(@Sql)
	SELECT @Scenarioid = memberid FROM #TempID     ' 

			SET @SQLStatement = @SQLStatement + '


	TRUNCATE TABLE #TempID
	SET @Sql = ''''INsert into #TempID Select memberid from DS_''''+@DimCol+'''' Where Label = ''''''''''''+@MemberCol+''''''''''''''''
	EXEC(@Sql)
	IF @@Rowcount = 0
	BEGIN
		SET @Sql = ''''INsert into #TempID Select memberid from DS_''''+@DimCol+'''' Where Description = ''''''''''''+@MemberCol+''''''''''''''''
		EXEC(@Sql)
	END
	SELECT @IdCol = memberID FROM #TempID

	TRUNCATE TABLE #TempID
	SET @Sql = ''''INsert into #TempID Select memberid from DS_''''+@DimRow+'''' Where Label = ''''''''''''+@MemberRow+''''''''''''''''
	EXEC(@Sql)
	IF @@ROWCOUNT = 0 
	BEGIN	
		SET @Sql = ''''INsert into #TempID Select memberid from DS_''''+@DimRow+'''' Where Description = ''''''''''''+@MemberRow+''''''''''''''''
		Exec(@Sql)
	END
	SELECT @IdRow = memberID FROM #TempID

	--TRUNCATE TABLE #TempID
	--SET @Sql = ''''INsert into #TempID Select memberid from DS_''''+@DriverName+'''' Where Label = ''''''''''''+@Driver+''''''''''''''''
	--EXEC(@Sql)
	--SELECT @IdDriver = memberID FROM #TempID
	-- REPLACE(@Comment,''''~*'''',CHAR(13) + CHAR(10))

	IF @CommentType = ''''New''''
		BEGIN
			DECLARE @Date DATETIME
			SET @Date = GETDATE()
			SET @Sql = ''''INSERT INTO FACT_''''+@ModelName+''''_Text 
			(''''+@DimRow+''''_Memberid,''''+@DimCol+''''_Memberid''''+@INSERT+'''',''''+@Scenario+''''_Memberid,Row,Col,Schedule_RecordId,''''+@ModelName+''''_Text,
			UserId,ChangeDateTime)
			VALUES ( ''''+
			CAST(@IdRow AS CHAR)+'''',''''
			+CAST(@IdCol AS CHAR)+@VALUES+'''',''''
			+CAST(@ScenarioId AS CHAR)+'''',''''
			+CAST(@RowNum AS CHAR)+'''',''''
			+CAST(@ColNum AS CHAR)+'''',''''
			+CAST(@Schedule_ID AS CHAR)
			+'''',''''''''''''+@Comment+'''''''''''',''''''''''''+@Winuser+'''''''''''',''''''''''''+CAST(@DATE AS CHAR)+'''''''''''')''''
			Print(@sql)
			EXEC(@Sql)



Print ''''INSERT INTO FACT_''''+@ModelName+''''_Text ''''
Print ''''(''''+@DimRow+''''_Memberid,''''+@DimCol+''''_Memberid''''+@INSERT+'''',''''+@Scenario+''''_Memberid,Row,Col,Schedule_RecordId,''''+@ModelName+''''_Text,''''
Print ''''UserId,ChangeDateTime)''''
Print ''''VALUES ( ''''
Print CAST(@IdRow AS CHAR)+'''',''''
Print CAST(@IdCol AS CHAR)+@VALUES+'''',''''
Print CAST(@ScenarioId AS CHAR)+'''',''''
Print CAST(@RowNum AS CHAR)+'''',''''
Print CAST(@ColNum AS CHAR)+'''',''''
Print CAST(@Schedule_ID AS CHAR)
Print '''',''''''''''''+@Comment+'''''''''''',''''''''''''+@Winuser+'''''''''''',''''''''''''+CAST(@DATE AS CHAR)+'''''''''''')''''


		END
		ELSE
		BEGIN
			SET @Sql = ''''UPDATE FACT_''''+@ModelName+''''_Text
			SET ''''+@ModelName+''''_Text = ''''''''''''+@Comment+'''''''''''' 
			WHERE ''''+@DimRow + ''''_Memberid = ''''+CAST(@IdRow AS CHAR) + '''' 
			AND ''''+@DimCol + ''''_Memberid = ''''+CAST(@IdCol AS CHAR) +@Where + '''' 
			And ''''+@Scenario + ''''_Memberid = ''''+CAST(@ScenarioID AS CHAR) + '''' 
			And Schedule_RecordId = ''''+CAST(@Schedule_ID AS CHAR)
			Print(@sql)
			EXEC(@sql)

		END
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

-- drop table #temp,#tempN,#tempID








/****** Object:  StoredProcedure [dbo].[Canvas_LST_Depreciation]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_Depreciation'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_Depreciation') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_Depreciation]
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    -- Insert statements for procedure here
	SELECT Distinct AssetAccount FROM LST_Depreciation
	ORDER BY 1

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_Dimensions]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_Dimensions'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_Dimensions') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_Dimensions]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT DISTINCT ''''Generic'''',''''Measures'''' FROM dimensions
UNION ALL
SELECT b.type,a.Dimension FROM dbo.ModelAllDimensions a,dbo.Dimensions b 
WHERE a.model = @modelname
AND a.Dimension = b.Label
ORDER BY 1


END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_LST_List_Menu_Type]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_List_Menu_Type'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_List_Menu_Type') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_List_Menu_Type]
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    -- Insert statements for procedure here
	SELECT Label,RecordId FROM Canvas_menu_Type
	UNION 
	SELECT DISTINCT NULL,0 FROM Canvas_Menu_Type
	ORDER BY RecordId

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_ListeLog]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_ListeLog'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_ListeLog') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_ListeLog]
	@RuleLabel as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
		SELECT [proc_Id],[User],[Begin_Date],[End_Date]
		FROM [Canvas_User_Run_Status] Where Proc_Name = @RuleLabel
		ORDER BY Proc_Id DESC

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_LST_ListVersion]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_ListVersion'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_ListVersion') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_ListVersion]
	@Modelname nvarchar(255),
	@Recordid nvarchar(255),
	@Version nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @Sql nvarchar(max)

	SET @Sql = ''''SELECT [Version_Label] FROM Canvas_WorkFlow WHERE Workflow_Detail_RecordId = ''''+@Recordid+'''' AND [Version] = ''''''''''''+@Version +'''''''''''' 
	and Model = ''''''''''''+@modelname+'''''''''''' ''''
	EXEC(@Sql)

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_LST_Menu]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_Menu'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_Menu') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  

  PROCEDURE  [dbo].[Canvas_LST_Menu]
	@UserName as nvarchar(255),
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
	DECLARE @MenuRecordid INT, @UserRecordID INT,@UserID INT,@Menu NVARCHAR(255)
	DECLARE @ID BIGINT,@V1 INT,@Winuser NVARCHAR(255),@user NVARCHAR(255),@testchar Nvarchar(100)

	Create Table #menu (Menu Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	
	INsert into #menu select Label From canvas_menus Where Model = @Modelname and right(Label,6) = ''''_Admin''''  
	IF @ModelName = ''''AccountReceivables'''' INsert into #menu values (''''Reeivables'''')
	IF @ModelName = ''''AccountPayables'''' INsert into #menu values (''''Receivables'''')



	Select @Menu = menu From #menu 

		SET NOCOUNT ON;

		Delete from  canvas_Users Where WinUser Not in (Select WinUser from users)
		Delete from  Canvas_Menu_Users Where WinUser Not in (Select WinUser from users)

		CREATE TABLE #Temp (Winuser NVARCHAR(255),userid Bigint)
		
		INSERT INTO #temp SELECT winuser,userid FROM users Where UserId not in (Select RecordId from canvas_Users)
		And Winuser in (Select winuser from SecurityRoleMembers Where RoleLabel = ''''Administrators'''')
		IF @@ROWCOUNT > 0
		BEGIN
			DECLARE Table_Cursor CURSOR FOR select winuser,userid from #Temp

			OPEN Table_Cursor 
			FETCH NEXT FROM Table_Cursor INTO @winuser,@Id
			WHILE @@FETCH_STATUS = 0 
			BEGIN
				SET @V1 = len(@winuser)
		
				WHILE @V1 >  0
				BEGIN
					SET @testChar = Substring(@winuser,@V1,1)
					IF @testChar = ''''\'''' 
					BEGIN
						SET @user = SUBSTRING(@Winuser,@V1+1,255)
						SET IDENTITY_INSERT  Canvas_Users ON
							INSERT INTO canvas_users (RecordId,[Label],[UserId],[WinUser])
							VALUES (@id,@user,@id,@winuser)
						SET IDENTITY_INSERT canvas_users OFF 
						Set @V1 = 0
					END
					SET @V1 = @V1 - 1	
				END
				FETCH NEXT FROM Table_Cursor INTO @winuser,@Id
			END 
			CLOSE Table_Cursor 
			DEALLOCATE Table_Cursor
		END ' 

			SET @SQLStatement = @SQLStatement + '
 


		Truncate table #temp
		INSERT INTO #temp 
		SELECT winuser,userid FROM users Where UserId not in (Select User_RecordID from canvas_Menu_Users Where menu = @menu)
		And Winuser in (Select winuser from SecurityRoleMembers Where RoleLabel = ''''Administrators'''')
		--AND Winuser = @username  
		IF @@ROWCOUNT > 0
		BEGIN
		--Select * from #temp
			DECLARE Table_Cursor CURSOR FOR select winuser,userid from #Temp

			OPEN Table_Cursor 
			FETCH NEXT FROM Table_Cursor INTO @winuser,@Id
			WHILE @@FETCH_STATUS = 0 
			BEGIN
				SET @V1 = len(@winuser) ' 

			SET @SQLStatement = @SQLStatement + '

		
				WHILE @V1 >  0
				BEGIN
					SET @testChar = Substring(@winuser,@V1,1)
					--print @testchar
					IF @testChar = ''''\'''' 
					BEGIN
							SET @user = SUBSTRING(@Winuser,@V1+1,255)

							--SELECT @MenuRecordId = Recordid from canvas_Menus Where Label = ''''Menu''''
							--And Model = @ModelName

							--INSERT INTO Canvas_Menu_Users
							--(SortOrder,menu_Recordid,Menu,User_RecordId,[User],WinUser)
							--VALUES(0,@MenuRecordid,@Menu,@Id,@User,@WinUser)
							
							SELECT @MenuRecordId = Recordid from canvas_Menus Where Label = ''''Budget_Admin''''
							INSERT INTO Canvas_Menu_Users
							(SortOrder,menu_Recordid,Menu,User_RecordId,[User],WinUser)
							VALUES(0,@MenuRecordid,''''Budget_Admin'''',@Id,@User,@WinUser)

							SELECT @MenuRecordId = Recordid from canvas_Menus Where Label = ''''Receivables''''
							INSERT INTO Canvas_Menu_Users
							(SortOrder,menu_Recordid,Menu,User_RecordId,[User],WinUser)
							VALUES(0,@MenuRecordid,''''Receivables'''',@Id,@User,@WinUser)

							SELECT @MenuRecordId = Recordid from canvas_Menus Where Label = ''''Payables''''
							INSERT INTO Canvas_Menu_Users
							(SortOrder,menu_Recordid,Menu,User_RecordId,[User],WinUser)
							VALUES(0,@MenuRecordid,''''Payables'''',@Id,@User,@WinUser)

							SELECT @MenuRecordId = Recordid from canvas_Menus Where Label = ''''Sales_Admin''''
							INSERT INTO Canvas_Menu_Users
							(SortOrder,menu_Recordid,Menu,User_RecordId,[User],WinUser)
							VALUES(0,@MenuRecordid,''''Sales_Admin'''',@Id,@User,@WinUser)

					END
					SET @V1 = @V1 - 1	
				END
				FETCH NEXT FROM Table_Cursor INTO @winuser,@Id
			END 
			CLOSE Table_Cursor 
			DEALLOCATE Table_Cursor
			Drop table #temp
			
		END  ' 

			SET @SQLStatement = @SQLStatement + '


	CREATE TABLE #TempMenu
		(
		 recordid BIGINT Identity(1,1)
		 ,Nocol BIGINT 
		,Menu_Item Nvarchar(250)
		,Menu_Type NVARCHAR(250)
		,Item_Name NVARCHAR(250)
		,Group_Number INT
		,Group_Row_Number INT
		,RowType NVARCHAR(5)
		,Run_Delet_NAme NVARCHAR(250)
		,Run_Report_Name NVARCHAR(250)
		,Run_Parameter NVARCHAR(250)
		,LocalCurrency Bit
		)
		
	DECLARE @Submenu Bit, @sql nvarchar(max)
	Set @SubMenu = 0 	
	if exists(
	select b.name from sysobjects a,syscolumns b 
	where a.id = b.id and a.name = ''''Canvas_Menu_Detail'''' and b.name = ''''SubMenu_Number'''')  
	SET @SubMenu = 1

	IF @Submenu = 1 ALTER TABLE #tempMenu ADD SubMenu_number INT, Submenu_Name Nvarchar(50) ,Group_Image Nvarchar(50) ' 

			SET @SQLStatement = @SQLStatement + '



	SET @Sql = ''''INSERT into #tempMenu
	(Nocol
	,Menu_Item
	,Menu_Type
	,Item_Name
	,Group_Number
	,Group_Row_Number
	,RowType
	,Run_Delet_NAme
	,Run_Report_Name
	,Run_Parameter
	,LocalCurrency''''
	IF @Submenu = 1 SET @Sql = @Sql + '''',SubMenu_number, Submenu_Name, group_Image''''
	Set @sql = @sql + ''''
	)
	SELECT DISTINCT '''''''''''''''',a.Menu_Item	,Menu_Type	,a.Item_Name	,a.Group_Number	,a.Group_RowNumber	
	,RTRIM(CAST(a.Group_Number AS CHAR))+''''''''$''''''''+LTRIM(CAST(a.Group_RowNumber AS CHAR)), 
	a.run_delete_name	,a.run_report_name	,Run_Parameter	,a.LocalCurrency ''''
	IF @Submenu = 1 SET @Sql = @Sql + '''',a.SubMenu_number, Menu_Item as SubMenu_Name, a.Group_Image''''
	Set @sql = @sql + ''''
	FROM dbo.Canvas_Menu_Detail a,dbo.Canvas_Menu_Users b,dbo.Canvas_Menus c
	WHERE a.Menu = b.Menu 
	And (b.[User] = ''''''''''''+@UserName+'''''''''''' OR b.[WinUser] = ''''''''''''+@UserName+'''''''''''' )
	And a.Group_RowNumber <> ''''''''0''''''''
	AND b.Menu = c.Label
	AND c.Model = ''''''''''''+@ModelName+''''''''''''
	Union All
	SELECT DISTINCT '''''''''''''''',a.Menu_Item, a.Menu_Type	,a.Group_Image,a.Group_Number,a.Group_RowNumber
	,RTRIM(CAST(a.Group_Number AS CHAR))+''''''''$0'''''''', 	a.run_delete_name,a.run_report_name,Run_Parameter,a.LocalCurrency ''''
	IF @Submenu = 1 SET @Sql = @Sql + '''',a.SubMenu_number, a.Menu_Item as Submenu_Name,a.Group_Image''''
	Set @sql = @sql + ''''
	FROM dbo.Canvas_Menu_Detail a, dbo.Canvas_Menu_Users b ,dbo.Canvas_Menus c ' 

			SET @SQLStatement = @SQLStatement + '

	WHERE a.Menu = b.Menu 
	And (b.[User] = ''''''''''''+@UserName+'''''''''''' OR b.[WinUser] = ''''''''''''+@UserName+'''''''''''' )
	And a.Group_RowNumber IS NULL
	AND b.Menu = c.Label
	AND c.Model = ''''''''''''+@ModelName+''''''''''''
	Union All
	SELECT DISTINCT '''''''''''''''',a.Menu_Item,a.Menu_Type,a.Group_Image,a.Group_Number,a.Group_RowNumber,RTRIM(CAST(a.Group_Number AS CHAR))+''''''''$0'''''''', 
	a.run_delete_name,a.run_report_name,Run_Parameter,a.LocalCurrency ''''
	IF @Submenu = 1 SET @Sql = @Sql + '''',a.SubMenu_number, a.Menu_Item as Submenu_Name,a.Group_Image''''
	Set @sql = @sql + ''''
	FROM dbo.Canvas_Menu_Detail a, dbo.Canvas_Menu_Users b ,dbo.Canvas_Menus c
	WHERE a.Menu = b.Menu 
	And (b.[User] = ''''''''''''+@UserName+'''''''''''' OR b.[WinUser] = ''''''''''''+@UserName+'''''''''''' )
	And a.Group_RowNumber = ''''''''0''''''''
	AND b.Menu = c.Label
	AND c.Model = ''''''''''''+@ModelName+''''''''''''
	Union all
	SELECT DISTINCT '''''''''''''''',CAST(MAX(a.Group_RowNumber) AS CHAR),'''''''''''''''','''''''''''''''',a.Group_Number,99,RTRIM(CAST(a.Group_Number AS CHAR))+''''''''$99'''''''','''''''''''''''','''''''''''''''','''''''''''''''','''''''''''''''' ''''
	IF @Submenu = 1 SEt @Sql = @sql + '''','''''''''''''''','''''''''''''''','''''''''''''''' ''''
	SET @sql = @sql + '''' 
	FROM dbo.Canvas_Menu_Detail a,dbo.Canvas_Menu_Users b ,dbo.Canvas_Menus c
	WHERE a.Menu = b.Menu 
	And (b.[User] = ''''''''''''+@UserName+'''''''''''' OR b.[WinUser] = ''''''''''''+@UserName+'''''''''''' )
	AND b.Menu = c.Label
	AND c.Model = ''''''''''''+@ModelName+''''''''''''
	GROUP BY a.Group_Number
	ORDER BY 5,6 ''''
	IF @Submenu = 1 SEt @Sql = @sql + '''',12  ''''
	Print(@sql)
	exec(@sql) ' 

			SET @SQLStatement = @SQLStatement + '


	Declare @max INT,@min INT, @NBGroup INT, @Lap INT,@Num INT
	SELECT @Max = MAX(Group_Number) FROM #TempMenu
	SELECT @Min = MIN(Group_Number) FROM #TempMenu
	SELECT @NbGroup = COUNT(DISTINCT Group_Number) FROM #TempMenu
	
	SET @Lap = 1
	SET @Num = 1
	WHILE @LAp <= @Max
	BEGIN
		UPDATE #tempMenu SET NoCol = @Num WHERE group_number = @Lap
		IF @@ROWCOUNT <> 0 SET @num = @Num + 1
		SET @Lap = @Lap + 1
	END
	UPDATE #TempMenu SET Group_Number = NoCol
	UPDATE #TempMenu SET RowType = LTRIM(RTRIM(CAST(NoCol AS CHAR))) + RIGHT(RTRIM(LTRIM(Rowtype)),2) WHERE LEN(RTRIM(LTRIM(Rowtype))) = 3
	UPDATE #TempMenu SET RowType = LTRIM(RTRIM(CAST(NoCol AS CHAR))) + RIGHT(RTRIM(LTRIM(Rowtype)),3) WHERE LEN(RTRIM(LTRIM(Rowtype))) = 4
	UPDATE #TempMenu SET NoCol = ''''''''

	IF @Submenu = 1
	BEGIN
		CREATE TABLE #SubMenu (Group_number INT,Group_row_number int,Menu_item nvarchar(50))
		INSERT INTO #SubMenu 
		Select Group_number,Group_row_number,Menu_item
		From #tempMenu
		WHERE Menu_Type = ''''SubMenu''''

		UPDATE #TempMenu Set Submenu_Name = b.Menu_item
		From #TempMenu a, #SubMenu b
		Where a.Group_Number = b.Group_number
		and a.Group_Row_Number = b.Group_row_number

		Update #TempMenu Set SubMenu_Number = 0 Where Submenu_number is null
	END ' 

			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''SELECT 	recordid ,Menu_Item ,Menu_Type	,Item_Name	,Group_Number	,Group_Row_Number	,RowType	,Run_Delet_NAme	,Run_Report_Name
	,Run_Parameter	,LocalCurrency ''''
	IF @Submenu = 1 SET @Sql = @Sql + '''',SubMenu_number, Submenu_Name,group_image''''
	Set @sql = @sql + '''' FROM #tempMenu ''''
	Exec(@sql)



END  '

IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END
--  Drop table #tempmenu,#menu,#SubMenu,#temp







/****** Object:  StoredProcedure [dbo].[Canvas_LST_MenuChoix]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_MenuChoix'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_MenuChoix') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_MenuChoix]

	@UserName as nvarchar(255),
	@ModelName as nvarchar(255),
	@MenuName NVARCHAR(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
	SELECT menu_Item,Group_number FROM Canvas_menu_detail WHERE menu = @menuname AND Group_RowNumber = 0 
	ORDER BY group_number

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_LST_MenuDetailGroup]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_MenuDetailGroup'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_MenuDetailGroup') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_MenuDetailGroup]
	@UserName as nvarchar(255),
	@ModelName as nvarchar(255),
	@MenuName as nvarchar(255),
	@GroupNumber as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
	SELECT a.*
	FROM dbo.Canvas_Menu_Detail a,dbo.Canvas_Menu_Users b,dbo.Canvas_Menus c 
	WHERE a.Menu = b.Menu And b.[User] = @UserName
	And a.Group_RowNumber <> 0
	AND c.Model = @ModelName
	AND b.Menu = c.Label
	AND a.Menu = @MenuName
	AND a.Group_Number = @GroupNumber
	Union All
	SELECT a.*
	FROM dbo.Canvas_Menu_Detail a, dbo.Canvas_Menu_Users b ,dbo.Canvas_Menus c 
	WHERE a.Menu = b.Menu And b.[User] = @UserName
	And a.Group_RowNumber IS NULL
	AND c.Model = @ModelName
	AND b.Menu = c.Label
	AND a.Menu = @MenuName
	AND a.Group_Number = @GroupNumber
	Union All
	SELECT a.*
	FROM dbo.Canvas_Menu_Detail a, dbo.Canvas_Menu_Users b ,dbo.Canvas_Menus c 
	WHERE a.Menu = b.Menu And b.[User] = @UserName
	And a.Group_RowNumber = 0
	AND c.Model = @ModelName
	AND b.Menu = c.Label
	AND a.Menu = @MenuName
	AND a.Group_Number = @GroupNumber
	ORDER BY Group_RowNumber
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_MenuList]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_MenuList'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_MenuList') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_MenuList]
	@UserName as nvarchar(255),
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
	SELECT Label,recordId,model FROM dbo.Canvas_Menus Where model = @modelname ORDER BY 1
	
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_NBDimensions]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_NBDimensions'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_NBDimensions') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_NBDimensions]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

CREATE TABLE #temp (TypeDim nvarchar(255),Dimension Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

INSERT INTO #temp 
SELECT DISTINCT ''''Generic'''',''''Measures'''' FROM dimensions
UNION ALL
SELECT b.type,a.Dimension FROM dbo.ModelAllDimensions a,dbo.Dimensions b 
WHERE a.model = @modelname
AND a.Dimension = b.Label
ORDER BY 1


SELECT count(*) FROM #temp

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_Parameter]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_Parameter'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_Parameter') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_Parameter]
@Type AS NVARCHAR(255),
@Name AS NVARCHAR(255)	
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
		SELECT StringValue FROM Canvas_Parameters WHERE ParameterType = @Type AND ParameterName = @Name
		
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_ReturnAccount]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_ReturnAccount'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_ReturnAccount') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_ReturnAccount]
	@Model Nvarchar(100),
	@Acc1 as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	Create table #temp (label nvarchar(255),ID INT)

	DECLARE @Sql nvarchar(max),@AccountDim Nvarchar(100)
	
	SELECT @AccountDim = a.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Model And b.[Type] = ''''Account''''

    -- Insert statements for procedure here
    
	SET @Sql = ''''INSERT INTO #Temp Select Label,1 from DS_''''+@AccountDim+'''' Where KeyName = ''''''''''''+@Acc1+''''''''''''''''
	EXEC(@Sql)

	Select label From #temp order by ID

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_ReturnDimension]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_ReturnDimension'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_ReturnDimension') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_ReturnDimension]
	@Model Nvarchar(100),
	@DimType as nvarchar(255),
	@ProductDim as nvarchar(255) = ''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	Create Table #temp (Dimension Nvarchar(100))
		
	INSERT INTO #temp SELECT a.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Model And b.[Type] = @DimType
	IF @@ROWCOUNT = 0
	BEGIN
		If @ProductDim <> ''''''''
		BEGIN
			INsert into #temp SELECT a.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
			where A.[Model] = @Model And a.[Dimension] = @ProductDim
		END
	END
	Select * from #temp
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_ReturnDimLabel]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_ReturnDimLabel'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_ReturnDimLabel') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_ReturnDimLabel]
	@Model Nvarchar(100),
	@Member1 as nvarchar(255),
	@DimType Nvarchar(255) = ''''Account''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	Create table #temp (label nvarchar(255),ID INT)

	DECLARE @Sql nvarchar(max),@Dim Nvarchar(100)
	
	SELECT @Dim = a.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Model And b.[Type] = @DimType

    -- Insert statements for procedure here
    
	SET @Sql = ''''INSERT INTO #Temp Select Label,1 from DS_''''+@Dim+'''' Where KeyName = ''''''''''''+@Member1+''''''''''''''''
	EXEC(@Sql)

	Select label From #temp order by ID

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_LST_ReturnParam]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_ReturnParam'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_ReturnParam') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_ReturnParam]
	@Model Nvarchar(100),
	@Param as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	If @Model <> ''''$''''
	BEGIN
		Select StringValue From Canvas_Parameters Where ParameterName = @param And Model = @Model
	END
	ELSE
	BEGIN
		Select StringValue From Canvas_Parameters Where ParameterName = @param 
	END
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_LST_SpreadAccount]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_SpreadAccount'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_SpreadAccount') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_SpreadAccount]
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

	SET NOCOUNT ON;
	SELECT DISTINCT Spreading_Account FROM dbo.LST_Spreading_Detail WHERE Spreading_Account IS NOT Null
	
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_SpreadDetail]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_SpreadDetail'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_SpreadDetail') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_SpreadDetail]
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

	SET NOCOUNT ON;
	SELECT label,Spreading_Type,Spreading_Account,Spreading_percent,Spreading_Fix_Key FROM dbo.canvas_Spreading
		 
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END












/****** Object:  StoredProcedure [dbo].[Canvas_LST_SpreadFormula]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_SpreadFormula'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_SpreadFormula') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_SpreadFormula]
	@Spreading NVARCHAR(255),
	@NBRow NVARCHAR(255),
	@NBCol NVARCHAR(255),
	@RowAccount Nvarchar(255),
	@DiffCol NVARCHAR(255) = 0
--	,@Percent Nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
	SET NOCOUNT ON;
	DECLARE @Nb INT,@NbR INT,@Start INT,@OldStart INT,@Pos INT,@Sql NVARCHAR(255),@SqlInsert NVARCHAR(Max)
	,@KeyCol NVARCHAR(255),@KeyRow NVARCHAR(255)
	--,@Spreading_Percent Bit
	CREATE TABLE #temp (ID INT IDENTITY (1,1))
    DECLARE @Spreading_Type INT
    DECLARE @Spreading_Key NVARCHAR(2000),@Key Nvarchar(2000)
    
    SELECT @Spreading_type = Spreading_type_recordid FROM Canvas_Spreading WHERE Label = @Spreading
    --IF @@ROWCOUNT = 0 RETURN
    SELECT @Spreading_Key = Spreading_Fix_Key FROM Canvas_Spreading WHERE Label = @Spreading
--    SELECT @Spreading_Percent = Spreading_Percent FROM LST_Spreading_Detail WHERE Label = @Spreading

    IF @Spreading_type = 1 -- Fix
	BEGIN
		SET @SqlInsert = ''''INSERT INTO #temp (''''
		SET @Nb = 1
		SET @Start = 1
		SET @Pos = 1
		WHILE @NB <= @NBCol
		BEGIN
			SET @OldStart = @Start 
			SET @Pos = CHARINDEX('''':'''',@Spreading_Key,@Start)
				SET @Sql = ''''ALTER TABLE #Temp ADD Col''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))+'''' Nvarchar(255)''''
				PRINT(@Sql)
				
				EXEC(@Sql)
				IF @Nb = 1 SET @Sqlinsert = @SqlInsert + ''''Col''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))
				IF @Nb > 1 SET @Sqlinsert = @SqlInsert + '''',Col''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))
				SET @Start = @Pos+1 
			SET @NB = @NB+1
		END
		SET @SqlInsert = @SqlInsert + '''') VALUES(''''+REPLACE(@Spreading_key,'''':'''','''','''')+'''')''''
		SET @NB = 1
		WHILE @NB <=@NbRow
		BEGIN
			EXEC(@Sqlinsert)
			SET @NB = @NB + 1
		END
	END ' 

			SET @SQLStatement = @SQLStatement + '

    IF @Spreading_type IN (2,5) -- Same Factor + Same Amount
	BEGIN
		SET @SqlInsert = ''''INSERT INTO #temp (''''
		SET @NbR = 1
		WHILE @NBr <= @NBRow
		BEGIN
			SET @KeyRow = ''''Sheets("Factor").Range("SpreadFactors").Row + 1 +'''' + RTRIM(LTRIM(CAST(@NB AS CHAR)))
			SET @Nb  = 1
			WHILE @NB <= @NBCol
			BEGIN
				IF @NBr = 1 
				BEGIN
					SET @Sql = ''''ALTER TABLE #Temp ADD Col''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))+'''' Nvarchar(255)''''
					EXEC(@Sql)
					IF @NB = 1 SET @SqlInsert = @SqlInsert + ''''Col''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))
					IF @NB > 1 SET @SqlInsert = @SqlInsert + '''',Col''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))
				END
				SET @Key = ''''''''''''=INDEX(FactorExpand,''''+RTRIM(LTRIM(CAST(@NBr+1 AS CHAR)))+'''',''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))+'''')''''''''''''
--				IF @Spreading_Percent = ''''True'''' SET @Key = ''''''''''''=INDEX(SpreadAll,''''+RTRIM(LTRIM(CAST(@NBr+1 AS CHAR)))+'''',''''+RTRIM(LTRIM(CAST(@NB+15 AS CHAR)))+'''')'''' +'''' * ''''+@Percent+''''''''''''''''
				IF @NB = 1 SET @Spreading_Key = @Key
				IF @NB > 1 SET @Spreading_Key = @Spreading_Key + '''','''' + @Key
				SET @NB = @Nb + 1 
			END
			PRINT(@SqlInsert+'''') VALUES(''''+@Spreading_key+'''')'''')
			EXEC(@SqlInsert+'''') VALUES(''''+@Spreading_key+'''')'''')
			
			SET @NBr = @Nbr + 1 
		END
	END


    IF @Spreading_type = 3 -- Single Factor
	BEGIN
		SET @SqlInsert = ''''INSERT INTO #temp (''''
		SET @NbR = 1
		WHILE @NBr <= @NBRow
		BEGIN
			SET @KeyRow = ''''Sheets("Factor").Range("SpreadFactors").Row + 1 +'''' + RTRIM(LTRIM(CAST(@NB AS CHAR)))
			SET @Nb  = 1
			WHILE @NB <= @NBCol
			BEGIN
				IF @NBr = 1 
				BEGIN
					SET @Sql = ''''ALTER TABLE #Temp ADD Col''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))+'''' Nvarchar(255)''''
					EXEC(@Sql)
					IF @NB = 1 SET @SqlInsert = @SqlInsert + ''''Col''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))
					IF @NB > 1 SET @SqlInsert = @SqlInsert + '''',Col''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))
				END ' 

			SET @SQLStatement = @SQLStatement + '

				SET @Key = ''''''''''''=INDEX(SpreadAll,''''+RTRIM(LTRIM(CAST(@RowAccount AS CHAR)))+'''',''''+RTRIM(LTRIM(CAST(@NB+15 AS CHAR)))+'''')''''''''''''
--				IF @Spreading_Percent = ''''True'''' SET @Key = @Key +'''' * ''''+@Percent
				IF @NB = 1 SET @Spreading_Key = @Key
				IF @NB > 1 SET @Spreading_Key = @Spreading_Key + '''','''' + @Key
				SET @NB = @Nb + 1 
			END
			EXEC(@SqlInsert+'''') VALUES(''''+@Spreading_key+'''')'''')
			SET @NBr = @Nbr + 1 
		END
	END
    IF @Spreading_type = 4 -- Retor Calculation
	BEGIN
		SET @SqlInsert = ''''INSERT INTO #temp (''''
		SET @NbR = 1
		WHILE @NBr <= @NBRow
		BEGIN
			SET @KeyRow = ''''Sheets("Factor").Range("SpreadFactors").Row + 1 +'''' + RTRIM(LTRIM(CAST(@NB AS CHAR)))
			SET @Nb  = 1
			WHILE @NB <= @NBCol
			BEGIN
				IF @NBr = 1 
				BEGIN
					SET @Sql = ''''ALTER TABLE #Temp ADD Col''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))+'''' Nvarchar(255)''''
					EXEC(@Sql)
					IF @NB = 1 SET @SqlInsert = @SqlInsert + ''''Col''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))
					IF @NB > 1 SET @SqlInsert = @SqlInsert + '''',Col''''+RTRIM(LTRIM(CAST(@NB AS CHAR)))
				END
				SET @Key = ''''''''''''=INDEX(InputAll,''''+RTRIM(LTRIM(CAST(@NBr+2 AS CHAR)))+'''',''''+RTRIM(LTRIM(CAST(@NB+@DiffCol AS CHAR)))+'''')''''''''''''
--				IF @Spreading_Percent = ''''True'''' SET @Key = @Key +'''' * ''''+@Percent
				IF @NB = 1 SET @Spreading_Key = @Key
				IF @NB > 1 SET @Spreading_Key = @Spreading_Key + '''','''' + @Key
				SET @NB = @Nb + 1 
			END
			EXEC(@SqlInsert+'''') VALUES(''''+@Spreading_key+'''')'''')
			SET @NBr = @Nbr + 1 
		END
	END
	
	SET @Sql = ''''ALTER TABLE #Temp DROP COLUMN ID''''
	EXEC(@Sql)
    
	SELECT * FROM #temp
		
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_Spreading]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_Spreading'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_Spreading') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_Spreading]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
	DECLARE @WorkFlow Nvarchar(255)

	SELECT	[RecordId]
			,[Label],[Spreading_Type],[Spreading_Fix_Key],[Spreading_Account],[Spreading_Percent]
			,[Label],[Spreading_Type],[Spreading_Fix_Key],[Spreading_Account],[Spreading_Percent]
	FROM Canvas_spreading      

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END








/****** Object:  StoredProcedure [dbo].[Canvas_LST_SpreadingListType]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_SpreadingListType'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_SpreadingListType') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_SpreadingListType]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
	DECLARE @WorkFlow Nvarchar(255)

	SELECT	Label,[RecordId] FROM Canvas_spreading_Type      

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_SpreadingUpdate]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_SpreadingUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_SpreadingUpdate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_SpreadingUpdate]
	@ModelName as nvarchar(255),
	@RecordId  as nvarchar(255),
	@AllParam  as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
	DECLARE @V1 INT,@V2 INT,@V3 INT,@V4 INT
	DECLARE @label NVARCHAR(255),@SpreadingType NVARCHAR(255),@SpreadingFixKey NVARCHAR(255),@SpreadingAccount NVARCHAR(255),@SpreadingPercent NVARCHAR(255)
	SET @V1 = CHARINDEX('''','''',@AllParam,1)
	SET @V2 =  CHARINDEX('''','''',@AllParam,@V1+1)
	SET @V3 =  CHARINDEX('''','''',@AllParam,@V2+1)
	SET @V4 =  CHARINDEX('''','''',@AllParam,@V3+1)
	
	SET @Label = SUBSTRING(@allparam,1,@V1-1)
	SET @SpreadingType    = SUBSTRING(@allparam,@V1+1,@V2-1 -@V1)
	SET @SpreadingFixKey  = SUBSTRING(@allparam,@V2+1,@V3-1 -@V2)
	SET @SpreadingAccount = SUBSTRING(@allparam,@V3+1,@V4-1-@V3)
	SET @SpreadingPercent = SUBSTRING(@allparam,@V4+1,255)

	DECLARE @WorkFlow Nvarchar(255)
	SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName

--	IF @DefaultValue = ''''$'''' SET @DefaultValue = ''''''''

	IF @RecordId > 0
	BEGIN
		UPDATE dbo.Canvas_Spreading SET [Label] = @label,Spreading_Type = @SpreadingType,Spreading_Fix_Key = @SpreadingFixKey
		,Spreading_Account = @SpreadingAccount,Spreading_Percent = @SpreadingPercent
		WHERE RecordId = @Recordid
	END
	IF @RecordId = 0
	BEGIN
		INSERT INTO dbo.Canvas_Spreading 
		([Label],[Spreading_Type],[Spreading_Fix_Key],[Spreading_Account],[Spreading_Percent])
		VALUES (@Label,@SpreadingType,@SpreadingFixKey,@SpreadingAccount,@SpreadingPercent)
	END
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_Traveling]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_Traveling'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_Traveling') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_Traveling]
@Entity AS NVARCHAR(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
		Select Destination,Ticket,Hotel,Allowance,Currency,Ticket_Account,Hotel_Account,Allowance_Account
		from lst_traveling
		Where entity = @Entity
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END









/****** Object:  StoredProcedure [dbo].[Canvas_LST_UpdateParam]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_UpdateParam'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_UpdateParam') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_UpdateParam]
	@Model Nvarchar(100),
	@Param as nvarchar(255),
	@ParamValue as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	Update Canvas_Parameters Set StringValue = @ParamValue Where ParameterName = @param 
	

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_Users_Email]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_Users_Email'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_Users_Email') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE [dbo].[Canvas_LST_Users_Email]
	@modelname Nvarchar(250),
	@User Nvarchar(250),
	@Type nvarchar(250), 
	@WorkflowID nvarchar(250) = 0
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
as

BEGIN
create table #temp (users  nvarchar(max),Scenario_Label Nvarchar(250),time_label nvarchar(250))
Declare @lap INT, @Sql Nvarchar(max), @Sql1 Nvarchar(max), @Sql2 Nvarchar(max), @Sql3 Nvarchar(max)
SET @Lap = 1

create table #users (label nvarchar(255),winUser nvarchar(255),Email nvarchar(255))

Set @sql1 = ''''

	Select Distinct a.Responsible as Label, b.Winuser, b.Email 
	From canvas_workflow_Detail a, Users b, Canvas_Users c
	Where a.Active = 1 ''''
	If @Type <> ''''All'''' Set @Sql = @Sql + '''' And a.RecordId = ''''+@WorkflowID
	Set @sql1 = @sql1 + ''''	And a.Responsible = c.Label
	And a.Model = ''''''''''''+@ModelName+''''''''''''
	And b.winuser = c.winuser 	
	And b.Email <> '''''''''''''''' ''''

	
	Set @sql2 = ''''Select Distinct a.Approver as Label, b.Winuser, b.Email 
	From canvas_workflow_Detail a, Users b, Canvas_Users c
	Where a.Active = 1 ''''
	If @Type <> ''''All'''' Set @Sql = @Sql + '''' And a.RecordId = ''''+@WorkflowID
	Set @sql2 = @sql2 + ''''	And a.Approver = c.Label
	And a.Model = ''''''''''''+@ModelName+''''''''''''
	And b.winuser = c.winuser 
	And b.Email <> '''''''''''''''' ''''

	Set @sql3 = ''''Select Distinct a.Administrator as Label, b.Winuser, b.Email  
	From canvas_workflow_Detail a, Users b, Canvas_Users c
	Where a.Active = 1  ''''
	If @Type <> ''''All'''' Set @Sql = @Sql + '''' And a.RecordId = ''''+@WorkflowID
	Set @sql3 = @sql3 + ''''	And a.Administrator = c.Label
	And a.Model = ''''''''''''+@ModelName+''''''''''''
	And b.winuser = c.winuser 
	And b.Email <> '''''''''''''''' ''''


	Set @sql = 	''''
	Insert into #Users 
	Select Distinct label,winuser,Email From (''''
	If @type = ''''All''''
	Begin
		Set @sql = @sql + @sql1+ 
		'''' Union All ''''
		+@sql2+ 
		'''' Union All ''''
		+@sql3 
		+'''') as Tmp ''''
	end ' 

			SET @SQLStatement = @SQLStatement + '

	If @type = ''''Submission''''
	Begin
		Set @sql = @sql + @sql2+ 
		'''' Union All ''''
		+@sql3+ 
		+'''') as Tmp ''''
	end
	If @type in (''''Approval'''' , ''''reject'''')
	Begin
		Set @sql = @sql + @sql1+ 
		'''' Union All ''''
		+@sql3+ 
		+'''') as Tmp ''''
	end
	Print(@sql)
	EXEC(@sql)
	
	Declare User_Cursor cursor for select Email from #Users
	open User_Cursor
	fetch next from User_Cursor into @User
	while @@FETCH_STATUS = 0
	begin
		If @Lap = 1 INSERT INTO #temp VAlues (@user,'''''''','''''''')
		IF @lap > 1 Update #temp set users = users +'''';''''+@user

		Set @Lap = @Lap + 1  
		fetch next from User_Cursor into @User
	end
	close User_Cursor
	deallocate User_Cursor

	Update #temp set Scenario_Label = Scenario, time_label = StartPeriod From Canvas_Workflow_ReForecast Where Active = 1  And Model = @ModelName


select * from #temp

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

--Drop table #temp,#Users



/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlow]    Script Date: 3/2/2017 11:34:03 AM ******/

/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlow]    Script Date: 08-May-15 9:32:09 AM ******/
SET @Step = 'Create Canvas_LST_WorkFlow'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlow') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlow]
	@Modelname as nvarchar(100),
	@Type as nvarchar(255),
	@Version as nvarchar(255),
	@Comment as nvarchar(255),
	@Workflow_Detail_RecordId as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @Test Nvarchar(25),@Now SMALLDATETIME,@BuildDate NVARCHAR(50)
	SET @Now = GETDATE()
	SET @Builddate = YEAR(@now)

	IF  RTRIM(CAST(MONTH(@Now)AS CHAR)) < 10
	BEGIN
		SET @BuildDate = @Builddate + ''''-0'''' + RTRIM(CAST(MONTH(@Now)AS CHAR))
	END
	ELSE
	BEGIN
		SET @BuildDate = @Builddate + ''''-'''' + RTRIM(CAST(MONTH(@Now)AS CHAR))
	END
	IF  RTRIM(CAST(Day(@Now)AS CHAR)) < 10
	BEGIN
		SET @BuildDate = @Builddate + ''''-0'''' + RTRIM(CAST(Day(@Now)AS CHAR))
	end
	ELSE
	BEGIN
		SET @BuildDate = @Builddate + ''''-'''' + RTRIM(CAST(Day(@Now)AS CHAR))
	end
	
	IF RTRIM(CAST(DATEPART ( Hour , @Now ) as CHAR)) < 10 
	BEGIN
		SET @BuildDate = @Builddate + '''' at 0'''' + RTRIM(CAST(DATEPART ( Hour , @Now ) as CHAR))
	END
	ELSE
	BEGIN
		SET @BuildDate = @Builddate + '''' at '''' + RTRIM(CAST(DATEPART ( Hour , @Now ) as CHAR))
	END
	IF RTRIM(CAST(DATEPART ( Minute , @Now ) as CHAR)) < 10 
	BEGIn
		SET @BuildDate = @Builddate + '''':0'''' + RTRIM(CAST(DATEPART ( Minute , @Now ) as CHAR))
	END
	ELSE
	BEGIn
		SET @BuildDate = @Builddate + '''':'''' + RTRIM(CAST(DATEPART ( Minute , @Now ) as CHAR))
	END
	IF @Type = ''''Submission''''
	BEGIN
		SELECT @TEST = Submission_date FROM Dbo.[Canvas_WorkFlow] WHERE WorkFlow_Number = 0 and model = @Modelname
		IF @TEST = ''''''''
		BEGIN ' 

			SET @SQLStatement = @SQLStatement + '

			Update Dbo.[Canvas_WorkFlow] SET Submission_Date = @BuildDate, [Status] = ''''Submitted'''', CreateDateTime = @Now
			, SubMission_Comment = @Comment
			, [Version] = @Version
			WHERE WorkFlow_Number = 0 AND Workflow_Detail_RecordId = @Workflow_Detail_RecordId and model = @Modelname
		END
		ELSE
		BEGIN
			INSERT INTO Dbo.[Canvas_WorkFlow] 
			([Model] 
			,[Workflow_Detail_RecordId]
			,[Submission_Date]
			,[Rejected_Date] 
			,[Approval_Date] 
			,[Status] 
			,[WorkFlow_Number]
			,[CreatedateTime] 
			,[Submission_Comment]
			,[Approval_Comment]
			,[Reject_Comment]
			,[Version] 
			,[Version_Label])
			SELECT 
			[Model] = @Modelname
			,[Workflow_Detail_RecordId] = @Workflow_Detail_RecordId
			,[Submission_Date] = @BuildDate
			,[Rejected_Date] = '''''''' 
			,[Approval_Date] = ''''''''
			,[Status] = ''''Submitted''''
			,[WorkFlow_Number] = -1
			,[CreatedateTime] = @Now
			,[Submission_Comment] = @Comment
			,[Approval_Comment] = ''''''''
			,[Reject_Comment] = ''''''''
			,[Version] = @Version
			,[Version_Label] = Version_Label
			FROM Dbo.[Canvas_WorkFlow] 
			WHERE WorkFlow_Number = 0  AND Workflow_Detail_RecordId = @Workflow_Detail_RecordId

			UPDATE Dbo.[Canvas_WorkFlow] SET WorkFlow_Number = WorkFlow_Number + 1 
			WHERE  Workflow_Detail_RecordId = @Workflow_Detail_RecordId and model = @Modelname
			
			UPDATE Dbo.[Canvas_WorkFlow] SET SubMission_Date = @BuildDate
			WHERE  WorkFlow_Number = 0  AND Workflow_Detail_RecordId = @Workflow_Detail_RecordId and model = @Modelname
		END
	END 
	IF @Type = ''''Approval''''
	BEGIN
		Update Dbo.[Canvas_WorkFlow] SET Approval_Date = @BuildDate, [Status] = ''''Approved'''', CreateDateTime = @Now
		, Approval_Comment = @Comment
		, [Version] = @Version
		WHERE WorkFlow_Number = 0  AND Workflow_Detail_RecordId = @Workflow_Detail_RecordId and model = @Modelname
	END 
	IF @Type = ''''Reject''''
	BEGIN
		Update Dbo.[Canvas_WorkFlow] SET Rejected_Date = @BuildDate, [Status] = ''''Rejected'''', CreateDateTime = @Now
		, Reject_Comment = @Comment
   	    , [Version] = @Version
		WHERE WorkFlow_Number = 0  AND Workflow_Detail_RecordId = @Workflow_Detail_RecordId and model = @Modelname
	END 
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowActive]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowActive'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowActive') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowActive]
	@ModelName as nvarchar(100) 
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

	SELECT Scenario FROM Canvas_Workflow_ReForecast Where active = ''''True''''  And Model = @ModelName

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END




/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowDetail]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowDetail'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowDetail') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowDetail]
	@Modelname  as nvarchar(255) = ''''Financials''''
	,@UserName as nvarchar(255)
	,@Status  as nvarchar(255) = ''''''''
	,@header  as nvarchar(3) = ''''Yes''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--Declare @UserName as nvarchar(255),@Status nvarchar(255) ,@header nvarchar(3), @Modelname nvarchar(50)
--Set @username = ''''Administrator''''
--Set @status = ''''''''
--Set @header = ''''Yes'''' 
--Set @modelname = ''''Financials''''
BEGIN
	
	If @Status = ''''All'''' SET @Status = ''''''''

	CREATE TABLE #temp (Id Nvarchar(1)
	,[Workflow_Detail_RecordId] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Submission_Date] [nvarchar](25)  COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Rejected_Date] [nvarchar](25)  COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Approval_Date] [nvarchar](25)  COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[WorkFlow_Number] [int] NULL
	,[CreatedateTime] [smalldatetime] NULL
	,[Submission_Comment] [nvarchar](255)  COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Approval_Comment] [nvarchar](255)  COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Reject_Comment] [nvarchar](255)  COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Version] [nvarchar](255)  COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,Max_submission_date  NVARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Max_approval_date  NVARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Schedule NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Status] [nvarchar](50)  COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,Workflow_description NVARCHAR(1000) COLLATE SQL_Latin1_General_CP1_CI_AS
	,responsible  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,approver  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,administrator  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Scenario  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[time]  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Currency]  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	)

	DECLARE @Sql NVARCHAR(MAX), @max INT, @Lap INT,@driv NVARCHAR(255),@Drivers NVARCHAR(MAX),@entityDim NVARCHAR(255),@dimtype NVARCHAR(255)
	,@WinUserName NVARCHAR(255)
	DECLARE @Scenario Nvarchar(100),@Time Nvarchar(100),@Curr Nvarchar(100)
	SELECT @Scenario = Dimension FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Scenario'''' And Model = @ModelName
	SELECT @Time = Dimension FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Time'''' And Model = @ModelName
	
	CREATE TABLE #Driver (Id INT IDENTITY(1,1), Driver NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	SET @Drivers = '''' ''''
	
	SELECT @WinUserName = WinUser FROM dbo.Canvas_Users WHERE label = @Username
	IF @@ROWCOUNT = 0 
	BEGIN
		SET @WinuserName = @Username
		SELECT @UserName = label FROM dbo.Canvas_Users WHERE WinUser = @WinUsername
	END ' 

			SET @SQLStatement = @SQLStatement + '

	INSERT INTO #Driver SELECT Dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Segment_Driver''''  And Model = @ModelName ORDER BY Driver_number
	SET @max = @@ROWCOUNT
	SET @Lap = 1
	WHILE @lap <= @max 
	BEGIN
		SET @Driv = ''''''''
		SELECT @Driv = Driver FROM #Driver WHERE Id = @lap
		SELECT @Dimtype = [Type] FROM Dimensions WHERE label = @driv
		IF @Dimtype = ''''Entity'''' SET @EntityDim = @Driv 	
		SET @Drivers = @Drivers + '''',b.['''' + @Driv+'''']''''

--		set  @sql = ''''-'''' + driv1 + ''''-'''' + driv2 + ''''-'''' + driv3


		SET @sql = ''''ALTER TABLE #Temp ADD [''''+@Driv + ''''] Nvarchar(255)  COLLATE SQL_Latin1_General_CP1_CI_AS''''
--		PRINT(@Sql)
		EXEC(@Sql)

		SET @lap = @Lap + 1 
	END
	
	Select * into #temp_final from #temp

--	IF @type = ''''Responsible''''
	BEGIN
		SET @Sql = ''''INSERT INTO #temp
		SELECT DISTINCT 3,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.submission_date AS Max_Submission_Date,b.approval_date,b.Schedule
		 ,''''''''In Progress'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM Canvas_workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = b.RecordId AND a.workflow_number = 0 AND a.status = ''''''''In Progress''''''''
		AND b.responsible In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		And a.Model = ''''''''''''+@ModelName+''''''''''''
		And a.Model = b.Model
		UNION ALL
		SELECT DISTINCT 5,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.submission_date,b.approval_date,b.Schedule 
		 ,''''''''Rejected'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM Canvas_workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = b.RecordId AND a.workflow_number = 0 AND a.status = ''''''''Rejected''''''''
		AND b.responsible In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		And a.Model = ''''''''''''+@ModelName+''''''''''''
		And a.Model = b.Model
		UNION ALL
		SELECT DISTINCT 7,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.submission_date,b.approval_date,b.Schedule 
		 ,''''''''Submitted'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM Canvas_workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = b.RecordId AND a.workflow_number = 0 AND a.status = ''''''''Submitted''''''''
		AND b.responsible In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		And a.Model = ''''''''''''+@ModelName+''''''''''''
		And a.Model = b.Model
		UNION ALL
		SELECT DISTINCT 9,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.submission_date,b.approval_date,b.Schedule 
		 ,''''''''Approved'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+'''' ' 

			SET @SQLStatement = @SQLStatement + '

		FROM Canvas_workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = b.RecordId AND a.workflow_number = 0 AND a.status = ''''''''Approved''''''''
		AND b.responsible In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		And a.Model = ''''''''''''+@ModelName+''''''''''''
		And a.Model = b.Model ''''
--		Print(@Sql)
		EXEC(@Sql)
		SET @Sql = ''''INSERT INTO #temp
		SELECT DISTINCT 1,b.RecordId,'''''''''''''''','''''''''''''''','''''''''''''''',0,'''''''''''''''','''''''''''''''','''''''''''''''','''''''''''''''',''''''''''''''''
		,b.submission_date,b.approval_date,b.Schedule
		 ,''''''''Ready To Complete'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM dbo.Canvas_WorkFlow_Detail b
		WHERE b.RecordId NOT IN (SELECT Workflow_Detail_RecordId FROM Canvas_Workflow)
		AND b.responsible In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''') 
		AND b.ACTIVE = ''''''''True''''''''	
		And b.Model = ''''''''''''+@ModelName+'''''''''''' ''''	
--		Print(@Sql)
		EXEC(@Sql)
	
		IF @Status = ''''Inactive''''
		BEGIn
			SET @Sql = ''''INSERT INTO #temp
			SELECT DISTINCT -1,b.RecordId,'''''''''''''''','''''''''''''''','''''''''''''''',0,'''''''''''''''','''''''''''''''','''''''''''''''','''''''''''''''',''''''''''''''''
			,b.submission_date,b.approval_date,b.Schedule
			 ,''''''''Inactive'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
			FROM dbo.Canvas_WorkFlow_Detail b
			WHERE b.RecordId NOT IN (SELECT Workflow_Detail_RecordId FROM Canvas_Workflow)
			AND b.responsible In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''') 
			AND b.ACTIVE = ''''''''False''''''''
			And b.Model = ''''''''''''+@ModelName+'''''''''''' ''''	
	--		PRINT(@Sql)
			EXEC(@Sql)
		END
	END
--	IF @type = ''''Approver''''
	BEGIN
		SET @sql = ''''INSERT INTO #temp
		SELECT DISTINCT 3,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.submission_date,b.approval_date,b.Schedule 
		 ,''''''''In Progress'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM Canvas_workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = b.RecordId AND a.workflow_number = 0 AND a.status = ''''''''In Progress''''''''
		AND b.approver In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Approver <> b.Responsible
		And a.Model = ''''''''''''+@ModelName+''''''''''''
		And a.Model = b.Model
		UNION ALL
		SELECT DISTINCT 5,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.submission_date,b.approval_date,b.Schedule 
		 ,''''''''Rejected'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM Canvas_workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = b.RecordId AND a.workflow_number = 0 AND a.status = ''''''''Rejected''''''''
		AND b.approver In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Approver <> b.Responsible
		And a.Model = ''''''''''''+@ModelName+''''''''''''
		And a.Model = b.Model
		UNION ALL ' 

			SET @SQLStatement = @SQLStatement + '

		SELECT DISTINCT 7,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.submission_date,b.approval_date,b.Schedule 
		 ,''''''''Submitted'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM Canvas_workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = b.RecordId AND a.workflow_number = 0 AND a.status = ''''''''Submitted''''''''
		AND b.approver In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Approver <> b.Responsible
		And a.Model = ''''''''''''+@ModelName+''''''''''''
		And a.Model = b.Model
		UNION ALL
		SELECT DISTINCT 9,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.submission_date,b.approval_date,b.Schedule 
		 ,''''''''Approved'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM Canvas_workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = b.RecordId AND a.workflow_number = 0 AND a.status = ''''''''Approved''''''''
		AND b.approver In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Approver <> b.Responsible 
		And a.Model = ''''''''''''+@ModelName+''''''''''''
		And a.Model = b.Model ''''
--		Print(@Sql)
		EXEC(@Sql)
		SET @Sql = ''''INSERT INTO #temp
		SELECT DISTINCT 1,b.RecordId,'''''''''''''''','''''''''''''''','''''''''''''''',0,'''''''''''''''','''''''''''''''','''''''''''''''','''''''''''''''',''''''''''''''''
		,b.submission_date,b.approval_date,b.Schedule
		 ,''''''''Ready To Complete'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM dbo.Canvas_WorkFlow_Detail b
		WHERE b.RecordId NOT IN (SELECT Workflow_Detail_RecordId FROM Canvas_Workflow)
		AND b.approver In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''') 
		AND b.ACTIVE = ''''''''True''''''''	
		AND b.Approver <> b.Responsible 
		And b.Model = ''''''''''''+@ModelName+'''''''''''' ''''
--		Print(@Sql)
		EXEC(@Sql)
		IF @Status = ''''Inactive''''
		BEGIN
		SET @Sql = ''''INSERT INTO #temp
			SELECT DISTINCT -1,b.RecordId,'''''''''''''''','''''''''''''''','''''''''''''''',0,'''''''''''''''','''''''''''''''','''''''''''''''','''''''''''''''',''''''''''''''''
			,b.submission_date,b.approval_date,b.Schedule
			 ,''''''''Inactive'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
			FROM dbo.Canvas_WorkFlow_Detail b
			WHERE b.Recordid NOT IN (SELECT Workflow_Detail_RecordId FROM Canvas_Workflow)
			AND b.approver In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''') 
			AND b.ACTIVE = ''''''''False''''''''
			AND b.Approver <> b.Responsible 
			And b.Model = ''''''''''''+@ModelName+'''''''''''' ''''
	--		Print(@Sql)
			EXEC(@Sql)
		END
	END
--	IF @type = ''''Administrator''''
	BEGIN
		SET @Sql = ''''INSERT INTO #temp
		SELECT DISTINCT 3,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version] ' 

			SET @SQLStatement = @SQLStatement + '

		,b.submission_date,b.approval_date,b.Schedule 
		 ,''''''''In Progress'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM Canvas_workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = b.RecordId AND a.workflow_number = 0 AND a.status = ''''''''In Progress''''''''
		AND b.Administrator In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Administrator <> b.Responsible
		AND b.Administrator <> b.Approver 
		And a.Model = ''''''''''''+@ModelName+''''''''''''
		And a.Model = b.Model
		UNION ALL
		SELECT DISTINCT 5,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.submission_date,b.approval_date,b.Schedule 
		 ,''''''''Rejected'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM Canvas_workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = b.RecordId AND a.workflow_number = 0 AND a.status = ''''''''Rejected''''''''
		AND b.Administrator In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Administrator <> b.Responsible
		AND b.Administrator <> b.Approver 
		And a.Model = ''''''''''''+@ModelName+''''''''''''
		And a.Model = b.Model
		UNION ALL
		SELECT DISTINCT 9,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.submission_date,b.approval_date,b.Schedule 
		 ,''''''''Approved'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM Canvas_workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = b.RecordId AND a.workflow_number = 0 AND a.status = ''''''''Approved''''''''
		AND b.Administrator In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Administrator <> b.Responsible
		AND b.Administrator <> b.Approver 
		And a.Model = ''''''''''''+@ModelName+''''''''''''
		And a.Model = b.Model
		UNION ALL
		SELECT DISTINCT 7,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.submission_date,b.approval_date,b.Schedule 
		 ,''''''''Submitted'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM Canvas_workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = b.RecordId AND a.workflow_number = 0 AND a.status = ''''''''Submitted''''''''
		AND b.Administrator In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Administrator <> b.Responsible
		AND b.Administrator <> b.Approver 
		And a.Model = ''''''''''''+@ModelName+''''''''''''
		And a.Model = b.Model ''''
		EXEC(@Sql)
		SET @sql = ''''INSERT INTO #temp
		SELECT DISTINCT 1,b.RecordId,'''''''''''''''','''''''''''''''','''''''''''''''',0,'''''''''''''''','''''''''''''''','''''''''''''''','''''''''''''''',''''''''''''''''
		,b.submission_date,b.approval_date,b.Schedule
		 ,''''''''Ready To Complete'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
		FROM dbo.Canvas_WorkFlow_Detail b
		WHERE b.RecordId NOT IN (SELECT Workflow_Detail_RecordId FROM Canvas_Workflow)
		AND b.Administrator In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''') 
		AND b.ACTIVE = ''''''''True''''''''
		AND b.Administrator <> b.Responsible
		AND b.Administrator <> b.Approver 
		And b.Model = ''''''''''''+@ModelName+'''''''''''' ''''
		EXEC(@Sql)
	
		IF @Status = ''''Inactive'''' ' 

			SET @SQLStatement = @SQLStatement + '

		BEGIN
			SET @sql = ''''INSERT INTO #temp
			SELECT DISTINCT -1,b.RecordId,'''''''''''''''','''''''''''''''','''''''''''''''',0,'''''''''''''''','''''''''''''''','''''''''''''''','''''''''''''''',''''''''''''''''
			,b.submission_date,b.approval_date,b.Schedule
			 ,''''''''Inactive'''''''' AS [Status],b.Workflow_description,b.responsible,b.approver,b.administrator,b.[Scenario],b.[Time],''''''''''''''''''''+@drivers+''''
			FROM dbo.Canvas_WorkFlow_Detail b
			WHERE b.RecordId NOT IN (SELECT Workflow_Detail_RecordId FROM Canvas_Workflow)
			AND b.Administrator <> b.Responsible
			AND b.Administrator <> b.Approver 
			AND b.Administrator In (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''') AND b.ACTIVE = ''''''''False''''''''
			And b.Model = ''''''''''''+@ModelName+'''''''''''' ''''
			Print(@Sql)
			EXEC(@Sql)
		END
	END

--		SET @sql = ''''UPDATE #Temp SET Entity_description = ''''+@EntityDim+''''+'''''''' - ''''''''+b.[DESCRIPTION] 
--		FROM #Temp a,DS_''''+@EntityDim+'''' b WHERE a.''''+@EntityDim+'''' = b.RecordId''''
--		EXEC(@Sql)
		SET @sql = ''''UPDATE #Temp SET Workflow_description = Workflow_description+''''+'''' + '''''''' - (''''''''+responsible+'''''''' >>> ''''''''+approver+'''''''')''''''''''''
		PRINT(@Sql)
		EXEC(@Sql)


		Select @Curr = DefaultValue From Canvas_Workflow_Segment Where Segment_Type = ''''Currency'''' And Model = @ModelName
		If @curr in ('''''''',''''None'''')
		Begin
			Set @Sql = ''''Update #temp set Currency = b.Currency from #temp a,DS_''''+@entityDim+'''' b Where a.[''''+@EntityDim+''''] = b.Label''''
--			Print(@sql)
			Exec(@sql)
		end
		else
		begin
			Update #Temp Set Currency = @curr
		end
		
		UPDATE #TEmp SET Schedule = b.Schedule_template FROM #Temp a, Canvas_WorkFlow_Schedule b WHERE a.Schedule = b.label and b.model = @ModelName

		If @header = ''''yes'''' 
		BEGIn		
			INSERT INTO #temp (ID,Status,Workflow_description) SELECT DISTINCT -2,''''INACTIVE '''',        '''' STATUS - INACTIVE '''' FROM #Temp WHERE Id = -1
			INSERT INTO #temp (ID,Status,Workflow_description) SELECT DISTINCT 0,''''Ready To Complete'''','''' STATUS - READY TO COMPLETE '''' FROM #Temp WHERE Id = 1
			INSERT INTO #temp (ID,Status,Workflow_description) SELECT DISTINCT 2,''''In Progress'''',      '''' STATUS - IN PROGRESS '''' FROM #Temp WHERE Id = 3
			INSERT INTO #temp (ID,Status,Workflow_description) SELECT DISTINCT 4,''''Rejected'''',         '''' STATUS - REJECTED '''' FROM #Temp WHERE Id = 5
			INSERT INTO #temp (ID,Status,Workflow_description) SELECT DISTINCT 6,''''Submitted'''',         '''' STATUS - SUBMITTED '''' FROM #Temp WHERE Id = 7
			INSERT INTO #temp (ID,Status,Workflow_description) SELECT DISTINCT 8,''''Approved'''',         '''' STATUS - APPROVED '''' FROM #Temp WHERE Id = 9
		END
		

		--SET @Sql = ''''INsert into #tempFinal Select * From #Temp ORDER BY Id''''+Replace(@Drivers,''''b.'''','''''''')+'''',Schedule''''
		--EXEC(@Sql)


		


		IF @Status = '''''''' ' 

			SET @SQLStatement = @SQLStatement + '

		BEGIN
			SET @Sql = ''''Insert into #temp_final Select * From #Temp ORDER BY Id''''+Replace(@Drivers,''''b.'''','''''''')+'''',Schedule''''
			print(@Sql)
			EXEC(@Sql)

--			SELECT DISTINCT * FROM #tempFinal
		END
		ELSE
		BEGIN
			SET @Sql = ''''Insert into #temp_final Select * From #Temp WHERE LTRIM([Status]) = ''''''''''''+@Status+'''''''''''' ORDER BY Id''''+Replace(@Drivers,''''b.'''','''''''')+'''',Schedule''''
			print(@Sql)
			EXEC(@Sql)
--			SELECT DISTINCT * FROM #tempfinal WHERE LTRIM([Status]) = @Status 
		END

		If @header = ''''No'''' Alter table #temp_final add recordid INT identity (1,1)

		set @Sql =''''Select * from #temp_final ORDER BY Id''''+Replace(@Drivers,''''b.'''','''''''')+'''',Schedule''''
		Exec(@sql)

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END


-- drop table #temp,#driver,#temp_final



/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowDriver1]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowDriver1'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowDriver1') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowDriver1]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
DECLARE @driverName nvarchar(255),@sql NVARCHAR(MAX)

SELECT @DriverName = dimension FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Segment_Driver'''' AND Driver_Number = 1 And Model = @ModelName
      
	CREATE TABLE #Temp(
	[RecordId] [bigint] NOT NULL
	,[SDriver1] [nvarchar](255) NULL
	,[SResponsible] [nvarchar](255) NULL
	,[SApprover] [nvarchar](255) NULL
	,[SAdministrator] [nvarchar](255) NULL
	,[Driver1] [nvarchar](255) NULL
	,[Responsible] [nvarchar](255) NULL
	,[Approver] [nvarchar](255) NULL
	,[Administrator] [nvarchar](255) NULL	)

	SET @Sql = ''''INSERT INTO #temp 
	SELECT recordid,Driver1,responsible,approver,administrator,Driver1,responsible,approver,administrator 
	FROM canvas_Workflow_Driver1
	Where Model = ''''''''''''+@ModelName+''''''''''''''''
	EXEC(@Sql)
	
	SET @sql = ''''INSERT INTO #Temp 
	SELECT 0,Label,'''''''''''''''','''''''''''''''','''''''''''''''',label,'''''''''''''''','''''''''''''''','''''''''''''''' From DS_''''+@DriverName+ '''' 
	Where Label Not in (Select Driver1 From Canvas_Workflow_Driver1 Where Model = ''''''''''''+@ModelName+'''''''''''') 
	And memberid Not in (Select parentId from HC_''''+@Drivername+ '''' Where parentId <> memberid)
	And memberid in (Select Memberid from HC_''''+@Drivername+ '''' Where parentId <> memberid) 
	And Memberid > 0 
	And Elim = 0 ''''
	Print(@Sql)
	EXEC(@Sql)
	
	SELECT * FROM #Temp ORDER BY [SDriver1]
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END



/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowDriver1Update]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowDriver1Update'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowDriver1Update') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowDriver1Update]
	@ModelName as nvarchar(255),
	@RecordId  as nvarchar(255),
	@AllParam  as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS


--DECLARE 
--	@ModelName as nvarchar(255),
--	@RecordId  as nvarchar(255),
--	@AllParam  as nvarchar(255)

--Set @ModelName = ''''Financials''''
--Set @recordid = 29
--Set @AllParam = ''''LE14,Hakan,Jan,Administrator''''

BEGIN

	DECLARE @V1 INT,@V2 INT,@V3 INT,@Driver1 NVARCHAR(255),@Responsible NVARCHAR(255),@Approver NVARCHAR(255),@Admin NVARCHAR(255)
	,@Sql NVARCHAR(MAX),@DriverName NVARCHAR(255)

	SELECT @DriverName = dimension FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Segment_Driver'''' AND Driver_Number = 1 And Model = @ModelName

	SET @V1 = CHARINDEX('''','''',@AllParam,1)
	SET @V2 =  CHARINDEX('''','''',@AllParam,@V1+1)
	SET @V3 =  CHARINDEX('''','''',@AllParam,@V2+1)
	SET @Driver1 = SUBSTRING(@allparam,1,@V1-1)
	SET @Responsible= SUBSTRING(@allparam,@V1+1,@V2-1 -@V1)
	SET @Approver =  SUBSTRING(@allparam,@V2+1,@V3-1 -@V2)
	SET @Admin =  SUBSTRING(@allparam,@V3+1,255)



	IF @RecordId <> 0
	BEGIn 
		SET @Sql = ''''UPDATE dbo.Canvas_WorkFlow_Driver1 SET 
		[Driver1] = ''''''''''''+@Driver1+''''''''''''
		,[Responsible] = ''''''''''''+@Responsible+''''''''''''
		,[Approver] = ''''''''''''+@Approver+''''''''''''
		,[Administrator] = ''''''''''''+@Admin+''''''''''''
		WHERE Recordid = ''''+@RecordId+''''
		And Model = ''''''''''''+@ModelName+'''''''''''' ''''
	END
	ELSE
	BEGIN
		SET @sql = ''''INSERT INTO Canvas_Workflow_Driver1	
		(  Model
		  ,[Driver1_MemberId]
		  ,[Driver1]
		  ,[Responsible_RecordId]
		  ,[Responsible]
		  ,[Approver_RecordId]
		  ,[Approver]
		  ,[Administrator_RecordId]
		  ,[Administrator])
		  Values (''''''''''''+@modelname+'''''''''''',0,''''''''''''+@Driver1+'''''''''''',0,''''''''''''+@responsible+'''''''''''',0,''''''''''''+@Approver+'''''''''''',0,''''''''''''+@Admin+'''''''''''')''''
     END  
     EXEC(@Sql)
	      
      SET @Sql = ''''UPDATE Canvas_Workflow_Driver1 SET Driver1_Memberid = b.memberid 
      FROM Canvas_Workflow_Driver1 a,DS_''''+@DriverName+'''' b WHERE a.Driver1 = b.Label 
      And Driver1 = ''''''''''''+@Driver1+''''''''''''
	  And Model = ''''''''''''+@ModelName+'''''''''''' ''''
      EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '


      SET @Sql = ''''UPDATE Canvas_Workflow_Driver1 SET Responsible_recordid = b.userid 
      FROM Canvas_Workflow_Driver1 a,Canvas_Users b WHERE a.Responsible = b.Label 
      And Driver1 = ''''''''''''+@Driver1+''''''''''''
	  And Model = ''''''''''''+@ModelName+'''''''''''' ''''
      EXEC(@Sql)

      SET @Sql = ''''UPDATE Canvas_Workflow_Driver1 SET Approver_recordid = b.userid 
      FROM Canvas_Workflow_Driver1 a,Canvas_Users b WHERE a.Approver = b.Label 
      And Driver1 = ''''''''''''+@Driver1+''''''''''''
	  And Model = ''''''''''''+@ModelName+'''''''''''' ''''
      EXEC(@Sql)

      SET @Sql = ''''UPDATE Canvas_Workflow_Driver1 SET Administrator_recordid = b.userid 
      FROM Canvas_Workflow_Driver1 a,Canvas_Users b WHERE a.Administrator = b.Label 
      And Driver1 = ''''''''''''+@Driver1+''''''''''''
	  And Model = ''''''''''''+@ModelName+'''''''''''' ''''
      EXEC(@Sql)
     
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END



/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowGenerate]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowGenerate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowGenerate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowGenerate]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

	DECLARE @Scenario Nvarchar(255),@Time Nvarchar(255),@Driver Nvarchar(255),@Driver_1 Nvarchar(255),@MaxDriver INT,@Lap INT,
	@SQL Nvarchar(max),@Select NVARCHAR(2000),@FROM NVARCHAR(2000),@WHERE NVARCHAR(MAX),@Default NVARCHAR(255)

	SELECT @Scenario = DefaultValue FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Scenario''''
	SELECT @Time = DefaultValue FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Time''''

	CREATE TABLE #Temp (Driver_Number INT,Driver NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	INSERT INTO #Temp SELECT Driver_Number,Dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Segment_Driver'''' ORDER BY 1
	SET @maxDriver = @@ROWCOUNT
	SET @lap = 1

	SET @FROM = ''''FROM Canvas_Workflow_Schedule a''''
	SET @WHERE = ''''WHERE ''''
	SET @Select = ''''SELECT ''''''''''''+@ModelName+'''''''''''',''''''''''''+@Scenario+'''''''''''',''''''''''''+@Time+'''''''''''' '''' 

	WHILE @lap <= @MaxDriver
	BEGIN
		SELECT @Driver = Dimension FROM Canvas_Workflow_Segment WHERE Driver_number = @lap 
		SELECT @Default = DefaultValue FROM Canvas_Workflow_Segment WHERE Driver_number = @lap 
		IF @Lap = 1 
		BEGIN
			SET @Driver_1 = @Driver
			SET @Select = @Select + '''',Canvas_Workflow_Driver1_Responsible.[Responsible]
									,Canvas_Workflow_Driver1_Responsible.[Approver]
									,Canvas_Workflow_Driver1_Responsible.[Administrator]''''  
			SET @select = @Select + '''',a.Submission_Date,a.Approval_date,a.Label,'''''''''''''''',1''''  
			SET @Where = @Where + ''''Canvas_Workflow_Driver1_Responsible.[Responsible] <> '''''''''''''''' '''' 

			SET @SELECT = @SELECT + '''',Canvas_Workflow_Driver1_Responsible.Driver1''''
			SET @FROM = @FROM + '''',Canvas_Workflow_Driver1_Responsible'''' 
			IF @Default = '''''''' 
			BEGIN
				SET @WHERE = @Where + '''' 
				AND Canvas_Workflow_Driver1_Responsible.Driver1_memberid NOT IN (SELECT parentid FROM hc_''''+@Driver+'''' WHERE ParentId <> memberid) 
				AND Canvas_Workflow_Driver1_Responsible.Driver1_Memberid > 0 ''''
			END
			ELSE
			BEGIN	
				SET @WHERE = @Where + '''' 
				AND Canvas_Workflow_Driver1_Responsible.Driver1 = ''''''''''''+@Default+''''''''''''''''
			END
		END
		ELSE
		BEGIN		
			SET @SELECT = @SELECT + '''',DS_''''+@Driver+''''.Label''''
			SET @FROM = @FROM + '''',DS_''''+@Driver 
			IF @Default = '''''''' 
			BEGIN
				SET @WHERE = @Where + '''' 
				AND DS_''''+@Driver+''''.memberid NOT IN (SELECT parentid FROM hc_''''+@Driver+'''' WHERE ParentId <> memberid) 
				AND DS_''''+@Driver+''''.Memberid > 0 ''''
			END
			ELSE
			BEGIN	
				SET @WHERE = @Where + '''' 
				AND DS_''''+@Driver+''''.Label = ''''''''''''+@Default+''''''''''''''''
			END
		END
		SET @Lap = @Lap + 1


	END

	SET @Sql =  ''''INSERT INTO Canvas_Workflow_Detail '''' + @Select
	SET @Sql = @Sql + '''' 
	''''+@From
	SET @Sql = @Sql + '''' 
	''''+@Where
	PRINT (@sql)
	EXEC (@sql)

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END



/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowHeader]    Script Date: 3/2/2017 11:34:03 AM ******/


SET @Step = 'Create Canvas_LST_WorkFlowHeader'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowHeader') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowHeader]
	@AllParam as nvarchar(255),
	@ScheduleName as nvarchar(255),
	@D1 as nvarchar(255),
	@D2 as nvarchar(255),
	@D3 as nvarchar(255),
	@D4 as nvarchar(255),
	@D5 as nvarchar(255),
	@D6 as nvarchar(255),
	@D7 as nvarchar(255),
	@D8 as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--DECLARE @AllpAram as nvarchar(255),	@ScheduleName as nvarchar(255),	@D1 as nvarchar(255),	@D2 as nvarchar(255),
--	@D3 as nvarchar(255),	@D4 as nvarchar(255),	@D5 as nvarchar(255),	@D6 as nvarchar(255),	@D7 as nvarchar(255),
--	@D8 as nvarchar(255)
	
--SET @Allparam = ''''Sales|Administrator''''
--SET @ScheduleName = ''''Sales_Supplier.xlsm''''
--SET @D1 = ''''01''''
--SET @D2 = ''''01_1037''''
--SET @D3 = ''''False''''
--SET @D4 = ''''False''''
--SET @D5 = ''''False''''
--SET @D6 = ''''False''''
--SET @D7 = ''''False''''
--SET @D8 = ''''False''''

BEGIN
	SET NOCOUNT ON;
	DECLARE @V1 INT,@V2 INT
	,@UserName as nvarchar(255),@ModelName as nvarchar(255)

	SET @V1 = CHARINDEX(''''|'''',@AllParam,1)
	SET @ModelName = SUBSTRING(@allparam,1,@V1-1)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @UserName= SUBSTRING(@allparam,@V1+1,255)

	DECLARE @Sql Nvarchar(MAX),@Where Nvarchar(MAX),@Where2 Nvarchar(MAX),@Schedule NVARCHAR(255)
	,@Lap INT,@Driv NVARCHAR(255),@D NVARCHAR(255),@TypeDim NVARCHAR(255),@max INT,@WinUserName NVARCHAR(255)
	,@Scenario NVARCHAR(255),@Time NVARCHAR(255)
	
	SELECT @Scenario = Dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Scenario'''' And Model = @ModelName
	SELECT @Time = Dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Time'''' And Model = @ModelName
	
	
	SET @Lap = 1
	SET @WHERE = ''''WHERE ''''
	SET @WHERE2 = ''''WHERE ''''
	
	SELECT @WinUserName = WinUser FROM dbo.Canvas_Users WHERE label = @Username
	IF @@ROWCOUNT = 0 
	BEGIN
		SET @WinuserName = @Username
		SELECT @UserName = label FROM dbo.Canvas_Users WHERE WinUser = @WinUsername
	END
	CREATE TABLE #Temp (
	UserName NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,UserNameRole NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Responsible NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Approver NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Submission_Date NVARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Approval_Date NVARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Scenario NVARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Time] NVARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Workflow_Detail_RecordId NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,ExcelTab Bit
	,Administrator NVARCHAR(255)
	,StartPeriod INT
	,ReForecast_Number INT )




	CREATE TABLE #WF (Workflow nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS) ' 

			SET @SQLStatement = @SQLStatement + '

	
	CREATE TABLE #Driver (Id INT IDENTITY(1,1), Driver NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

	INSERT INTO #Driver SELECT Dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Segment_Driver''''  And Model = @ModelName ORDER BY Driver_number
	SET @max = @@ROWCOUNT
	WHILE @lap <= @max 
	BEGIN
		SET @Driv = ''''''''
		SELECT @Driv = Driver FROM #Driver WHERE Id = @lap
		SELECT @typedim = Type FROM Dimensions WHERE label = @driv
   		    IF @lap = 1 SET @D = @D1
   		    IF @lap = 2 SET @D = @D2
   		    IF @lap = 3 SET @D = @D3
   		    IF @lap = 4 SET @D = @D4
   		    IF @lap = 5 SET @D = @D5
   		    IF @lap = 6 SET @D = @D6
   		    IF @lap = 7 SET @D = @D7
   		    IF @lap = 8 SET @D = @D8

			IF @Lap <> 1 
			BEGIN
				SET @Where = @Where +'''' 	AND ''''
				SET @Where2 = @Where2 +'''' AND ''''
			END
   		    SET @Where = @Where + ''''b.''''+@Driv+'''' = ''''''''''''+@D+''''''''''''''''
   		    SET @Where2 = @where2 + '''' a.''''+@Driv+'''' = ''''''''''''+@D+''''''''''''''''
		SET @lap = @Lap + 1 
	END

	SELECT @Schedule = Label From Canvas_Workflow_schedule WHERE schedule_template = REPLACE(REPLACE(@ScheduleName,''''.xlsm'''',''''''''),''''.xls'''','''''''') and model = @ModelName


	SET @sql = ''''INSERT INTO #WF SELECT a.Workflow_Detail_RecordId FROM Canvas_Workflow a,Canvas_Workflow_Detail b  '''' +
	@WHere + '''' AND b.Schedule = ''''''''''''+@Schedule+''''''''''''
	AND a.Workflow_Detail_RecordId = b.RecordId 
	AND Workflow_Number = 0 
	And a.Model = ''''''''''''+@ModelName+''''''''''''
	And a.Model = b.Model ''''
	PRINT(@Sql)
	EXEC(@Sql)
	

	IF @@ROWCOUNT = 0 
	BEGIN

		DECLARE @Date AS SMALLDATETIME
		SET @Date = GETDATE()

		DECLARE @Version as NVARCHAR(255), @Version_label as NVARCHAR(255)
		CREATE TABLE #TempVersion (Label nvarchar(255))
		SET @Version = ''''V01''''
		SET @Version_Label = ''''Initial Version''''
		SET @Sql = ''''INSERT INTO #tempversion SELECT a.Version FROM Canvas_Workflow a,Canvas_Workflow_Detail b  '''' +
		@WHere + ''''AND a.Workflow_Detail_RecordId = b.RecordId AND Workflow_Number = 0 ''''
		Print(@Sql)
		EXEC(@Sql)
		IF @@ROWCOUNT > 0  ' 

			SET @SQLStatement = @SQLStatement + '

		BEGIN
			Select @Version = Max(label) From #TempVersion
			TRUNCATE Table #TempVersion
			SET @Sql = ''''INSERT INTO #tempversion SELECT a.Version_label 
			FROM Canvas_Workflow a,Canvas_Workflow_Detail b  '''' +
			@WHere + '''' AND Workflow_Number = 0 AND a.Workflow_Detail_RecordId = b.RecordId  and version = ''''''''''''+@Version+''''''''''''
			And a.Model = ''''''''''''+@ModelName+''''''''''''
			And a.Model = b.Model	''''
			EXEC(@Sql)
			Select @Version_label = label From #TempVersion
		END

	
--		SET @Version = ''''V01''''
--		SET @Version_Label = ''''Initial Version''''

		SET @sql = ''''INSERT INTO Canvas_WorkFlow 
		([Model] ,[Workflow_Detail_RecordID] ,[Submission_Date] ,[Rejected_Date] ,[Approval_Date] ,[Status] ,[Workflow_Number] ,[CreateDateTime]
      ,[Submission_Comment] ,[Approval_Comment] ,[Reject_Comment] ,[Version] ,[Version_Label])
	  SELECT DISTINCT a.Model,RecordId AS [Workflow_Detail_RecordId],'''''''''''''''','''''''''''''''','''''''''''''''',''''''''In Progress'''''''',0,''''''''''''
		+CAST(@Date AS CHAR)+'''''''''''','''''''''''''''','''''''''''''''','''''''''''''''',''''''''''''+@Version+'''''''''''',''''''''''''+@Version_Label+''''''''''''
		FROM Canvas_workflow_Detail a ''''
		+@Where2 + ''''
		AND (a.Responsible In (''''''''''''+@UserName+'''''''''''',''''''''''''+@WinUserName+'''''''''''') OR a.Approver <> a.Responsible OR a.Administrator <> a.Responsible)
		And Schedule = ''''''''''''+@Schedule+''''''''''''
		And a.Model = ''''''''''''+@ModelName+'''''''''''' ''''
		PRINT(@Sql)
		print ''''==========''''
		EXEC(@Sql)
		print ''''==========''''
	END
	SET @Sql = ''''INSERT INTO #Temp
	SELECT DISTINCT ''''''''''''+@USerName+'''''''''''',''''''''Responsible'''''''',a.responsible,a.Approver,a.Submission_date,a.Approval_date,a.[Scenario],a.[Time]
	,a.RecordId,Excel_Tab,a.Administrator,a.startperiod,a.Reforecast_number
	FROM Canvas_workflow_Detail a '''' 
	+@WHERE2 +''''
	AND a.Responsible In (''''''''''''+@UserName+'''''''''''',''''''''''''+@WinUserName+'''''''''''')
	And a.Schedule = ''''''''''''+@Schedule+''''''''''''
	And a.Model = ''''''''''''+@ModelName+'''''''''''' ''''
	PRINT(@Sql)
	EXEC(@Sql)
	IF @@ROWCOUNT = 0 
	BEGIN
		SET @Sql = ''''INSERT INTO #Temp
		SELECT DISTINCT ''''''''''''+@USerName+'''''''''''',''''''''Approver'''''''',a.responsible,a.Approver,a.Submission_date,a.Approval_date,a.[Scenario],a.[Time]
		,a.RecordId,a.Excel_Tab,a.Administrator,a.startperiod,a.Reforecast_number
		FROM Canvas_workflow_Detail a  ''''
		+@WHERE2 +''''
		AND a.Approver In (''''''''''''+@UserName+'''''''''''',''''''''''''+@WinUserName+'''''''''''')
		And a.Schedule = ''''''''''''+@Schedule+''''''''''''
		And a.Model = ''''''''''''+@ModelName+'''''''''''' ''''
		print(@Sql)
		EXEC(@Sql)


		IF @@ROWCOUNT = 0 
			BEGIN
				SET @Sql = ''''INSERT INTO #Temp
				SELECT DISTINCT ''''''''''''+@USerName+'''''''''''',''''''''Administrator'''''''',a.responsible,a.Approver,a.Submission_date,a.Approval_date,a.[Scenario],a.[Time]
				,a.RecordId,a.Excel_Tab,a.Administrator,a.startperiod,a.Reforecast_number
				FROM Canvas_workflow_Detail a ''''
				+@WHERE2 +''''
				AND a.Administrator In (''''''''''''+@UserName+'''''''''''',''''''''''''+@WinUserName+'''''''''''')
				And a.Schedule = ''''''''''''+@Schedule+''''''''''''		
				And a.Model = ''''''''''''+@ModelName+'''''''''''' ''''

				--Print(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '

				EXEC(@Sql)
				IF @@ROWCOUNT = 0 
				BEGIN
					SET @Sql = ''''INSERT INTO #Temp
					SELECT DISTINCT ''''''''''''+@USerName+'''''''''''',''''''''Viewer'''''''',a.responsible,a.Approver,a.Submission_date,a.Approval_date,a.[Scenario],a.[Time]
					,a.RecordId,a.Excel_Tab,a.Administrator,a.startperiod,a.Reforecast_number
					FROM Canvas_workflow_Detail a ''''
					+@WHERE2 +''''
					And a.Schedule = ''''''''''''+@Schedule+''''''''''''
					And a.Model = ''''''''''''+@ModelName+'''''''''''' ''''
					EXEC(@Sql)
				END 
			END 
	END 
	
	
	Update #Temp set UserNameRole = ''''Approver'''' Where Approver IN (@UserName,@WinUserName)
	Update #Temp set UserNameRole = ''''Administrator'''' Where Administrator in (@UserName,@WinUserName)
	

	SELECT Administrator	,UserNameRole 	,Responsible 	,Approver 	,Submission_Date	,Approval_Date	,Scenario 	,[Time]	,Workflow_Detail_RecordId 	
	,ExcelTab ,startperiod,Reforecast_number
	From #Temp

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END


-- Drop table #temp,#WF,#Driver,#tempversion



/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowItemsUpdate]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowItemsUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowItemsUpdate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowItemsUpdate]
	@ModelName as nvarchar(255),
	@RecordId  as nvarchar(255),
	@AllParam  as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

--DECLARE	@ModelName as nvarchar(255),@RecordId  as nvarchar(255),@AllParam  as nvarchar(255)
--set @recordid = ''''1''''
--SEt @Allparam = ''''LE14,Herve,Hakan,jan,2013-09-11,2013-09-20,Currentassets,FALSE,TRUE''''
--Set @ModelName = ''''Financials''''


	CREATE TABLE #MyTable (Responsible nvarchar(255),Approver nvarchar(255),Administrator nvarchar(255))

	SET @AllParam = REPLACE (@AllParam,'''',TRUE'''','''',1'''')
	SET @AllParam = REPLACE (@AllParam,'''',FALSE'''','''',0'''')

	DECLARE @WorkFlow Nvarchar(255),@active Bit
	SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName
	IF @@ROWCOUNT = 0 SET @WorkFlow = ''''Budget''''

	DECLARE @debut INT,@fin INT,@Driv NVARCHAR(255),@Nb INT,@Lap INT,@Update NVARCHAR(MAX),@Insert NVARCHAR(MAX),@Sql NVARCHAR(MAX),@NbDriver INT,
	@Scenario NVARCHAR(255),@time NVARCHAR(255),@New AS BIT,@Desc AS NVARCHAR(2000),@DrivBit Bit,@INsertHide Nvarchar(MAX),@DELETE Nvarchar(MAX),
	@Schedule Nvarchar(255),@INsertName Nvarchar(MAX),@DELETENAME Nvarchar(max)

	DECLARE @Responsible Nvarchar(255),@Approver Nvarchar(255),@Administrator Nvarchar(255)
	DECLARE @OldResponsible Nvarchar(255),@oldApprover Nvarchar(255),@oldAdministrator Nvarchar(255)


	--IF @DefaultValue = ''''$'''' SET @DefaultValue = ''''''''
	SET @new = ''''False''''
	IF @RecordId = 0 SET @New = ''''True''''

	SELECT @NbDriver = MAX(Driver_Number) FROM dbo.Canvas_WorkFlow_Segment WHERE Model = @ModelName
	SELECT @Scenario = DefaultValue FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Scenario'''' And Model = @ModelName
	SELECT @Time = DefaultValue FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Time'''' And Model = @ModelName

	SET @debut = 1
	SET @lap = 1
	SET @Desc = ''''''''
	SET @Update = ''''UPDATE Canvas_WorkFlow_Detail SET ''''
	SET @INSERT = ''''INSERT INTO Canvas_WorkFlow_Detail (Model,Scenario,Time'''' 
	SET @INSERTHIDE = ''''INSERT INTO Canvas_Workflow_HideDetail (Model,Driver1'''' 
	SET @INSERTNAME = ''''INSERT INTO Canvas_Workflow_StoreNames (Model,Driver1'''' 
	SET @DELETE = ''''DELETE FROM Canvas_Workflow_HideDetail WHERE '''' 
	SET @DELETENAME = ''''DELETE FROM Canvas_Workflow_StoreNames WHERE ''''  ' 

			SET @SQLStatement = @SQLStatement + '


	IF @NbDriver >=2 SET @INsertHide = @INsertHide + '''',Driver2''''
	IF @NbDriver >=3 SET @INsertHide = @INsertHide + '''',Driver3''''
	IF @NbDriver >=4 SET @INsertHide = @INsertHide + '''',Driver4''''
	IF @NbDriver >=5 SET @INsertHide = @INsertHide + '''',Driver5''''
	IF @NbDriver >=6 SET @INsertHide = @INsertHide + '''',Driver6''''
	IF @NbDriver >=7 SET @INsertHide = @INsertHide + '''',Driver7''''
	IF @NbDriver >=8 SET @INsertHide = @INsertHide + '''',Driver8''''

	IF @NbDriver >=2 SET @INSERTNAME = @INSERTNAME + '''',Driver2''''
	IF @NbDriver >=3 SET @INSERTNAME = @INSERTNAME + '''',Driver3''''
	IF @NbDriver >=4 SET @INSERTNAME = @INSERTNAME + '''',Driver4''''
	IF @NbDriver >=5 SET @INSERTNAME = @INSERTNAME + '''',Driver5''''
	IF @NbDriver >=6 SET @INSERTNAME = @INSERTNAME + '''',Driver6''''
	IF @NbDriver >=7 SET @INSERTNAME = @INSERTNAME + '''',Driver7''''
	IF @NbDriver >=8 SET @INSERTNAME = @INSERTNAME + '''',Driver8''''

	Set @INSERTHIDE = @INSERTHIDE + '''',Schedule)''''
	Set @INsertHide = @INsertHide + '''' VALUES (''''''''''''+@ModelName+'''''''''''',''''

	Set @INSERTNAME = @INSERTNAME + '''',Schedule,Responsible,Approver,Administrator)''''
	Set @INSERTNAME = @INSERTNAME + '''' VALUES (''''''''''''+@ModelName+'''''''''''',''''

	SET @Nb = LEN(@AllParam) - LEN(REPLACE(@AllParam,'''','''','''''''')) + 1
	WHILE @lap <= @Nb
	BEGIN
	  
		IF @Lap >=1 OR @Lap <= @NbDriver SELECT @Driv = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE driver_Number = @lap And Model = @ModelName
		IF @lap - @NbDriver = 1 SET @Driv = ''''Responsible''''
		IF @lap - @NbDriver = 2 SET @Driv = ''''Approver''''
		IF @lap - @NbDriver = 3 SET @Driv = ''''Administrator''''
		IF @lap - @NbDriver = 4 SET @Driv = ''''Submission_Date''''
		IF @lap - @NbDriver = 5 SET @Driv = ''''Approval_Date''''
		IF @lap - @NbDriver = 6 SET @Driv = ''''Schedule''''
		IF @lap - @NbDriver = 7 SET @Driv = ''''Active''''
		IF @lap - @NbDriver = 8 SET @Driv = ''''Excel_Tab'''' ' 

			SET @SQLStatement = @SQLStatement + '



		SET @fin = CHARINDEX('''','''',@AllParam,@Debut)
		IF @Fin = 0 SET @Fin = 255


	If @lap = 1
	BEGIN
		set @sql = ''''INSERT INTO #MyTable Select Responsible,Approver,Administrator 
		From  Canvas_WorkFlow_Driver1 Where Driver1 = ''''''''''''+SUBSTRING(@allParam,@debut,@fin-@debut)+'''''''''''' And model = ''''''''''''+@ModelName+'''''''''''' ''''
		EXEC(@Sql)
		Select @OldResponsible = Responsible From  #MyTable
		Select @oldApprover = Approver From  #MyTable
		Select @oldAdministrator = Administrator From  #MyTable
	END

		if @lap = 1 + @NbDriver SET @Responsible = SUBSTRING(@allParam,@debut,@fin-@debut)
		if @lap = 2 + @NbDriver SET @Approver = SUBSTRING(@allParam,@debut,@fin-@debut)
		if @lap = 3 + @NbDriver SET @Administrator = SUBSTRING(@allParam,@debut,@fin-@debut)

		IF @New = ''''False''''
		BEGIN
			IF @Lap > 1 SET @Update = @Update + '''',''''
			SET @Update = @Update +@driv +''''='''''''''''' + SUBSTRING(@allParam,@debut,@fin-@debut) + ''''''''''''''''
			if @lap = 6 + @NbDriver SET @Schedule = SUBSTRING(@allParam,@debut,@fin-@debut)
		END
		ELSE
		BEGIN
			SET @Insert = @Insert +'''',''''+@driv 
			IF @lap = 1 SET @Desc = @Desc + SUBSTRING(@allParam,@debut,@fin-@debut)
			IF @lap <= @NbDriver AND @Lap > 1 SET @Desc = @Desc + '''' - ''''+SUBSTRING(@allParam,@debut,@fin-@debut)
			IF @Driv = ''''Schedule''''  SET @Desc = @Desc + '''' - ''''+SUBSTRING(@allParam,@debut,@fin-@debut)
			if @lap = 7 SET @Schedule = SUBSTRING(@allParam,@debut,@fin-@debut)
		END	
	
		IF @Driv = ''''Active'''' SET @Active = SUBSTRING(@allParam,@debut,@fin-@debut)
	
		IF @Lap > 1 And  @Lap <= @NbDriver 
		BEGIN
			SET @INsertHide = @INsertHide + '''','''' 
			SET @INsertNAME = @INsertNAME + '''','''' 
			SET @DELETE = @Delete + '''' AND ''''
			SET @DELETENAME = @DeleteNAME + '''' AND ''''
		END
		IF @Lap <= @NbDriver
		BEGIn
			SET @DELETE = @DELETE + '''' Driver'''' +  LTRIM(RTRIM(CAST(@Lap as char))) + '''' = ''''''''''''+SUBSTRING(@allParam,@debut,@fin-@debut)+''''''''''''''''
			SET @DELETENAME = @DELETENAME + '''' Driver'''' +  LTRIM(RTRIM(CAST(@Lap as char))) + '''' = ''''''''''''+SUBSTRING(@allParam,@debut,@fin-@debut)+''''''''''''''''
			SET @InsertHide = @insertHide + ''''''''''''''''+ SUBSTRING(@allParam,@debut,@fin-@debut)+''''''''''''''''
			SET @INsertNAME = @INsertNAME + ''''''''''''''''+ SUBSTRING(@allParam,@debut,@fin-@debut)+''''''''''''''''
		END ' 

			SET @SQLStatement = @SQLStatement + '


		SET @lap = @Lap + 1
		SET @debut = @fin+1 

	END

	SET @INsertHide = @INsertHide + '''',''''''''''''+@Schedule+'''''''''''')''''
	SET @INsertName = @INsertName + '''',''''''''''''+@Schedule+'''''''''''',''''''''''''+@Responsible+'''''''''''',''''''''''''+@Approver+'''''''''''',''''''''''''+@Administrator+'''''''''''')''''

	SET @Update = @Update + '''' WHERE RecordId = ''''+@recordId+'''' And Model = ''''''''''''+@ModelName+'''''''''''' ''''
	SET @INsert = @Insert + '''',WorkFlow_Description) 
	VALUES (''''''''''''+@ModelName+'''''''''''',''''''''''''+@Scenario+'''''''''''',''''''''''''+@Time+ '''''''''''',''''''''''''+REPLACE(@Allparam,'''','''','''''''''''','''''''''''')+'''''''''''',''''''''''''+@Desc+'''''''''''')''''

	Set @DELETENAME = @DELETENAME + '''' AND Schedule = ''''''''''''+@Schedule+''''''''''''''''
	print @deletename
	EXEC (@DELETENAME+'''' And Schedule = ''''''''''''+@Schedule+'''''''''''' And Model = ''''''''''''+@ModelName+'''''''''''''''')

	IF Rtrim(Ltrim(@Administrator))+Rtrim(Ltrim(@Approver))+Rtrim(Ltrim(@Administrator)) <> Rtrim(Ltrim(@OldAdministrator))+Rtrim(Ltrim(@oldApprover))+Rtrim(Ltrim(@oldAdministrator))
	BEGIN
		PRINT  (@Insertname)
		EXEC  (@Insertname)
	END

	PRINT (@Update)
	EXEC (@Update) ' 

			SET @SQLStatement = @SQLStatement + '


	If @Active = ''''False'''' 
	BEGIN
	print ''''inserthide''''
		PRINT  (@InsertHide)
		EXEC (@InsertHide)
	END
	ELSE
	BEGIN
		print @delete
		EXEC (@DELETE+'''' And Schedule = ''''''''''''+@Schedule+'''''''''''' And Model = ''''''''''''+@ModelName+'''''''''''' '''')
	END
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END


--UPDATE Canvas_WorkFlow_Detail SET Entity=''''New'''',Responsible=''''Herve'''',Approver=''''Herve'''',Administrator=''''Herve'''',Submission_Date=''''2013-09-11'''',Approval_Date=''''2013-09-20'''',Schedule=''''GrossMargin'''',Active=''''1'''',Excel_Tab=''''1'''' WHERE RecordId = 13
--DELETE FROM Canvas_Workflow_HideDetail WHERE  Driver1 = ''''New''''

-- Drop table #mytable




/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowListDriverNumber]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowListDriverNumber'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowListDriverNumber') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowListDriverNumber]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

	DECLARE @WorkFlow Nvarchar(255),@maxId BIGINT
	SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName
	IF @@ROWCOUNT = 0 SET @WorkFlow = ''''Budget''''
	CREATE TABLE #temp (ID INT)
	INSERT INTO #Temp Values(1)
	INSERT INTO #Temp Values(2)
	INSERT INTO #Temp Values(3)
	INSERT INTO #Temp Values(4)
	INSERT INTO #Temp Values(5)
	INSERT INTO #Temp Values(6)
	INSERT INTO #Temp Values(7)
	INSERT INTO #Temp Values(8)
	SELECT * FROM #temp ORDER BY 1
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END




/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowListe]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowListe'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowListe') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowListe]
	@ModelName as nvarchar(255),
	@Workflow_Detail_RecordId as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

	SET NOCOUNT ON;

	Declare @Sql nvarchar(max)

	SEt @Sql = ''''SELECT ''''''''Submitted: ''''''''+Submission_date,Submission_Comment,[Version],workflow_Number,3 
	FROM Canvas_workflow 
	WHERE Submission_date <> '''''''''''''''' AND Workflow_Detail_RecordId = ''''+@Workflow_Detail_RecordId+'''' and Model = ''''''''''''+@modelName+''''''''''''
	UNION ALL
	SELECT ''''''''Rejected: ''''''''+Rejected_date,Reject_Comment,[Version],workflow_Number,2 FROM Canvas_workflow 
	WHERE Rejected_date <> '''''''''''''''' AND Workflow_Detail_RecordId = ''''+@Workflow_Detail_RecordId+'''' and Model = ''''''''''''+@modelName+''''''''''''
	UNION ALL
	SELECT ''''''''Approved: ''''''''+Approval_date,Approval_Comment,[Version],workflow_Number,1 FROM Canvas_workflow  
	WHERE Approval_date <> '''''''''''''''' AND Workflow_Detail_RecordId = ''''+@Workflow_Detail_RecordId+'''' and Model = ''''''''''''+@modelName+''''''''''''
	ORDER BY 4,5 DESC ''''
	EXEC(@Sql)
	


END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END




/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowListSchedule]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowListSchedule'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowListSchedule') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowListSchedule]
	@ModelName as nvarchar(255),
	@ScheduleName as nvarchar(255) =''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	DECLARE @WorkFlow Nvarchar(255),@maxId BIGINT
	SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName
	IF @@ROWCOUNT = 0 SET @WorkFlow = ''''Budget''''

	CREATE TABLE #Temp (
	[RecordId] [bigint] NULL
	,[SLabel] [nvarchar](255) NOT NULL
	,[SSchedule_Template] [nvarchar](255) NULL
	,[SList] [bit] NULL
	,[SSubmission_Date] [nvarchar](50) NULL
	,[SApproval_Date] [nvarchar](50) NULL
	,[SActive] [bit] NULL
	,[Label] [nvarchar](255) NOT NULL
	,[Schedule_Template] [nvarchar](255) NULL
	,[List] [bit] NULL,
	[Submission_Date] [nvarchar](50) NULL
	,[Approval_Date] [nvarchar](50) NULL
	,[Active] [bit] NULL 
	) ON [PRIMARY]

	If @ScheduleName <> ''''''''
	BEGIN
		INSERT INTO #Temp
		SELECT recordId,label,Schedule_Template,list,submission_date,Approval_date,active,
		label,Schedule_Template,list,submission_date,Approval_date,active 
		FROM dbo.Canvas_WorkFlow_Schedule
		WHERE Schedule_Template  = LTRIM(RTRIM(REPLACE(@ScheduleName,''''.xlsm'''','''''''')))
		IF @@Rowcount = 0 
		BEGIN
			SELECT @MaxId = MAX(RecordId) FROM Canvas_WorkFlow_Schedule
			INSERT INTO dbo.Canvas_WorkFlow_Schedule 
			([RecordId],Model,[Label],[Schedule_Template],[List],[Submission_Date],[Approval_Date],[Active])
			VALUES (@MAXID,@modelname,REPLACE(@ScheduleName,''''.xlsm'''',''''''''),@ScheduleName,0,'''''''','''''''',1)
			INSERT INTO #Temp
			SELECT recordId,@ModelName,
			label,Schedule_Template,list,submission_date,Approval_date,ACTIVE, 
			label,Schedule_Template,list,submission_date,Approval_date,ACTIVE 
			FROM dbo.Canvas_WorkFlow_Schedule
			WHERE RecordId = @MaxId
		END
		SELECT * FROM #temp
	END
	ELSE
	BEGIN
		SELECT label FROM dbo.Canvas_WorkFlow_Schedule
	END
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowListSegmentType]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowListSegmentType'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowListSegmentType') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowListSegmentType]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

	DECLARE @WorkFlow Nvarchar(255),@maxId BIGINT
	SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName
	IF @@ROWCOUNT = 0 SET @WorkFlow = ''''Budget''''
	SELECT label,RecordId 
	FROM Canvas_WorkFlow_Segment_Type
	WHERE Label in (''''Segment_Fixed'''',''''Segment_Driver'''',''''Segment_Variable'''') 
	ORDER BY 2

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowListUser]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowListUser'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowListUser') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowListUser]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	DECLARE @WorkFlow Nvarchar(255),@maxId BIGINT
	DECLARE @ID BIGINT,@V1 INT,@OLDV1 INT,@Deb INT,@Winuser NVARCHAR(255),@user NVARCHAR(255)
	CREATE TABLE #Temp (Winuser NVARCHAR(255),userid Bigint)
	
	DELETE FROM canvas_users Where Winuser Not in (Select Winuser From Users)

	INSERT INTO #temp SELECT winuser,userid FROM users Where Winuser not in (Select winuser from canvas_Users)
	IF @@ROWCOUNT > 0
	BEGIN
		DECLARE Table_Cursor CURSOR FOR select winuser,userid from #Temp
		OPEN Table_Cursor 
		FETCH NEXT FROM Table_Cursor INTO @winuser,@Id
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			SET @V1 = 1
			SET @Deb = 1
	
			WHILE @V1 > 0
			BEGIN
				SET @V1 = CHARINDEX(''''\'''',@WinUser,@Deb)
				PRINT CAST(@V1 AS CHAR)
				IF @V1 <> 0 
				BEGIN		
				SET @OLDV1 = @V1
				SET @Deb = @V1 + 1
				END
				SET @USER = SUBSTRING(@Winuser,@OLDV1+1,255)
				INSERT INTO canvas_users ([Label],[UserId],[WinUser])
				VALUES (@user,@id,@winuser)
			END
	
			FETCH NEXT FROM Table_Cursor INTO @winuser,@Id
		END 
		CLOSE Table_Cursor 
		DEALLOCATE Table_Cursor

		Drop table #temp
	END

	SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName
	IF @@ROWCOUNT = 0 SET @WorkFlow = ''''Budget''''

	SELECT Label FROM dbo.Canvas_Users	ORDER BY recordid
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowNewVersion]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowNewVersion'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowNewVersion') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowNewVersion]
	@ModelName as nvarchar(255),
	@Workflow_Detail_RecordId as nvarchar(255),
	@UserName as nvarchar(255),
	@VersionDescription as nvarchar(255),
	@ActionType NVARCHAR(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

	SET NOCOUNT ON;
	
	CREATE TABLE #temp ([version] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS) 

	DECLARE @VersionID BIGINT, @Version Nvarchar(255), @NewVersion Nvarchar(255)
	DECLARE @NbDriver INT,@lap INT,@WHERE Nvarchar(max),@Driver nvarchar(255),@DriverName nvarchar(50),@sql Nvarchar(max)
	
	Create Table #tempI (versionID	INT)

	SET @Sql = ''''Insert into #tempI 
	SELECT MAX(CAST(REPLACE([Version],''''''''V'''''''','''''''''''''''') AS INT)) 
	FROM dbo.Canvas_Workflow 
	WHERE Workflow_Detail_RecordId = ''''+@Workflow_Detail_RecordId+'''' 
	AND Model = ''''''''''''+@ModelName+'''''''''''' ''''
	EXEC(@Sql)

	SELECT @VersionID = VersionID From #tempI
	
	SET @VersionID = @VersionID + 1 
	IF @VersionID >0 AND @VersionID <= 9
	BEGIN
		SET @NewVersion = ''''V0'''' + LTRIM(CAST(@VersionID AS CHAR))
	END
	ELSE
	BEGIN
		SET @NewVersion = ''''V'''' + LTRIM(CAST(@VersionID AS CHAR))
	END

	Create table #tempN (Label nvarchar(255))
	Select  @NbDriver = Max(driver_number) from Canvas_Workflow_segment Where Model = @ModelName
	SET @lap= 1
	SET @Where =  '''' ''''
	While @Lap <= @NbDriver
	BEGIN
		SELECT @drivername = Dimension from Canvas_Workflow_Segment Where Driver_Number = @Lap And Model = @ModelName
		TRUNCATE TABLE #tempN
		SET @Sql = ''''INsert into #tempN Select ''''+@DriverName+'''' From Canvas_Workflow_detail where RecordId = ''''+@Workflow_Detail_RecordId+ '''' And Model = ''''''''''''+@ModelName+'''''''''''' ''''
		Print(@Sql)
		EXEC(@Sql)
		SELECT @driver = Label from #tempN
		--IF @Lap = 1 SET @Where = @Where + '''' '''' + @DriverName +'''' = ''''+@Driver 
		SET @Where = @Where + '''' AND '''' + @DriverName +'''' = ''''''''''''+@Driver +''''''''''''''''
		Set @lap = @lap + 1
	END

	Create table #Recordid (RecordId BIGINT)

	SET @Sql = ''''INSERT INTO #recordId Select RecordId from Canvas_Workflow_detail Where Recordid > 0 and model = ''''''''''''+@ModelName+'''''''''''' '''' + @WHERE
	Print(@Sql)
	EXEC(@Sql)

	SET @Sql = ''''UPDATE Canvas_WorkFlow SET WorkFlow_Number = WorkFlow_Number + 1 WHERE Workflow_Detail_RecordId in (Select recordid from #recordid) 
	And  Model = ''''''''''''+@ModelName+'''''''''''' ''''
	EXEC(@sql)
	
	UPDATE Canvas_WorkFlow SET [Submission_Comment]=''''New Version '''',[Approval_Comment]='''''''',[Reject_Comment]='''''''' 
	WHERE [Submission_Comment] = ''''''''

	SET @Sql = ''''INSERT INTO Canvas_WorkFlow 
	(  [Model]
      ,[Workflow_Detail_RecordId]
      ,[Submission_Date]
      ,[Rejected_Date]
      ,[Approval_Date]
      ,[Status]
      ,[WorkFlow_Number]
      ,[CreatedateTime]
      ,[Submission_Comment]
      ,[Approval_Comment]
      ,[Reject_Comment]
      ,[Version]
      ,[Version_Label])
	SELECT DISTINCT ''''''''''''+@ModelName+''''''''''''
	,b.recordid as [Workflow_Detail_RecordId]
	,a.[Submission_Date]
	,a.[Rejected_Date]
	,a.[Approval_Date]
	,a.[Status]
	,0 AS [WorkFlow_Number]
	,GETDATE()
	,'''''''''''''''' AS [Submission_Comment]
	,'''''''''''''''' AS [Approval_Comment]
	,'''''''''''''''' AS [Reject_Comment]
	,''''''''''''+LTRIM(RTRIM(@NewVersion))+'''''''''''' 
	,''''''''''''+@VersionDescription+''''''''''''	
	FROM Canvas_Workflow a,#recordid b 
	WHERE a.Workflow_detail_RecordId = b.recordid  
	And  a.Model = ''''''''''''+@ModelName+'''''''''''' ''''
	Print (@Sql)
	EXEC (@Sql)

	

	Truncate table #temp
	INSERT INTO #Temp ([Version]) VALUES (@NewVersion)
	
	SELECT * FROM #temp

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END
-- Drop TABLE #temp,#tempN,#recordID,#tempI



/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowReforecast]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowReforecast'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowReforecast') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowReforecast]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
--declare @modelname nvarchar(255)
--set @modelname = ''''legal''''


DECLARE @WorkFlow Nvarchar(255),@Ismeasures Nvarchar(255),@ScenarioDim Nvarchar(255),@TimeDim Nvarchar(255),@ReforeCastMax Nvarchar(2),@IsReforeCast INT
CREATE TABLE #Temp(
	[RecordId] [bigint] NULL,
	[WorkFlow] [nvarchar](50) NULL,
	[Reforecast_NumberS] [bigint] NULL,
	[ScenarioS] [nvarchar](50) NULL,
	[StartPeriodS] [nvarchar](50) NULL,
	[CopyFromS] [nvarchar](255) NULL,
	[ActiveS] [Bit] NULL,
	[Reforecast_Number] [bigint] NULL,
	[Scenario] [nvarchar](255) NULL,
	[StartPeriod] [nvarchar](50) NULL,
	[CopyFrom] [nvarchar](255) NULL,
	[Active] [Bit] NULL
) ON [PRIMARY]

	CREATE TABLE #Dim(
	[RecordId] [bigint] IDENTITY (1,1),
	[Dimension] [nvarchar](50) NULL) ON [PRIMARY]

	SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName
	IF @@ROWCOUNT = 0 SET @WorkFlow = ''''Budget''''
	
	CREATE TABLE #ModelAllDimensions (Model NVARCHAR(100)COLLATE SQL_Latin1_General_CP1_CI_AS,Dimension NVARCHAR(255)COLLATE SQL_Latin1_General_CP1_CI_AS)
	INSERT INTO #ModelAllDimensions SELECT model,dimension FROM ModelAllDimensions

	Select @ReforeCastMax = StringValue From Canvas_Parameters Where ParameterType = ''''Workflow'''' And ParameterName = ''''ReforeCast_Number''''
	IF @@rowcount = 0 
	BEGIN
		INSERT INTO  Canvas_Parameters ([SortOrder],[Model],[Parametertype],[ParameterName],[StringValue])
		VALUES (0,@Modelname,''''WorkFlow'''',''''Reforecast_Number'''',''''1'''')
		SET @ReforecastMax = 1
	END

	Declare @LapReforecast INT
	Select @ScenarioDim = a.Dimension From ModelDimensions a,Dimensions b Where a.Model = @modelname 
	And a.Dimension = b.Label
	And b.[Type] = ''''Scenario''''
	Select @TimeDim = a.Dimension From ModelDimensions a,Dimensions b Where a.Model = @modelname 
	And a.Dimension = b.Label
	And b.[Type] = ''''Time''''
	SET @LapReforecast = 0
	WHILE @LapReforecast <= @ReforeCastMax
	BEGIN
		Truncate Table #Dim
		INSERT INTO #Dim SELECT Scenario FROM Canvas_WorkFlow_ReForeCast WHERE Reforecast_Number = @LapReforecast And Model = @ModelName
		IF @@Rowcount = 0
		BEGIN
			IF @LapReforecast = 0
			BEGIN
				INSERT INTO dbo.Canvas_WorkFlow_ReForeCast
				(Model,[WorkFlow],[Scenario],[StartPeriod],[Reforecast_Number],Active,[CopyFrom])
				Select  a.Model,a.WorkFlow,a.DefaultValue,b.DefaultValue,0,''''True'''','''''''' from Canvas_Workflow_Segment a,Canvas_Workflow_Segment b 
				Where a.Segment_Type = ''''Scenario'''' And b.Segment_Type = ''''Time'''' 
				And a.model = @modelname and a.model = b.model
			END ' 

			SET @SQLStatement = @SQLStatement + '

			ELSE
			BEGIN
				INSERT INTO dbo.Canvas_WorkFlow_ReForeCast
				(Model,[WorkFlow],[Scenario],[StartPeriod],[Reforecast_Number],active,CopyFrom)
				VALUES (@modelname,@WorkFlow,'''''''','''''''',@LapReforecast,''''False'''','''''''')
			END
		END
		SET @LapReforecast = @LapReforecast + 1
	END

	Delete from Canvas_WorkFlow_ReForeCast Where Reforecast_Number > @ReforeCastMax And Model = @ModelName

	INSERT INTO #temp 
	SELECT a.[RecordId] ,a.[WorkFlow] ,a.[Reforecast_Number]
    ,a.[Scenario] ,a.[StartPeriod],a.copyFrom,a.Active
	,a.[Reforecast_Number]
    ,a.[Scenario] ,a.[StartPeriod],a.copyFrom,a.Active
    FROM dbo.Canvas_WorkFlow_Reforecast a
	WHERE a.Workflow = @Workflow
	And a.Model = @ModelName

	SELECT * FROM #temp ORDER BY [Reforecast_Number]
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

--  Drop table #temp,#dim,#ModelAllDimensions









/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowReForeCastUpdate]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowReForeCastUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowReForeCastUpdate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowReForeCastUpdate]
	@ModelName as nvarchar(255),
	@RecordId  as nvarchar(255),
	@AllParam  as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

	DECLARE @V1 INT,@V2 INT,@ReforeCast_Number NVARCHAR(255)
	,@Scenario NVARCHAR(255),@StartPeriod NVARCHAR(255),@CopyFrom NVARCHAR(255),@Active NVARCHAR(255)

	SET @V1 = CHARINDEX(''''|'''',@AllParam,1)
	SET @ReforeCast_Number = SUBSTRING(@allparam,1,@V1-1)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @Scenario= SUBSTRING(@allparam,@V1+1,@V2-1 -@V1)
	SET @V1 =  CHARINDEX(''''|'''',@AllParam,@V2+1)
	SET @StartPeriod =  SUBSTRING(@allparam,@V2+1,@V1-1 -@V2)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @CopyFrom= SUBSTRING(@allparam,@V1+1,@V2-1 -@V1)
	SET @V1 =  CHARINDEX(''''|'''',@AllParam,@V2+1)
	SET @Active =  SUBSTRING(@allparam,@V2+1,255)

	DECLARE @WorkFlow Nvarchar(255),@maxReforecast INT,@IdTable BIGINT,@Lap INT,@Sql NVARCHAR(MAX)
	,@driv nvarchar(255),@Name nvarchar(255),@OldSegmentType NVARCHAR(255)
	SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName
	IF @@Rowcount = 0 SET @Workflow = ''''Budget''''

	--	IF @DefaultValue = ''''$'''' SET @DefaultValue = ''''''''

	UPDATE dbo.Canvas_WorkFlow_ReforeCast SET [ReforeCast_Number] = @ReforeCast_Number,Scenario = @Scenario,StartPeriod = @StartPeriod
	,Active = @Active,CopyFrom = @CopyFrom
	WHERE [ReforeCast_Number] = @ReforeCast_Number And Model = @ModelName
	
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowScheduleListe]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowScheduleListe'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowScheduleListe') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowScheduleListe]
	@ModelName as nvarchar(255),
	@ScheduleName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	DECLARE @WorkFlow Nvarchar(255),@maxId BIGINT
	SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName
	IF @@ROWCOUNT = 0 SET @WorkFlow = ''''Budget''''

	CREATE TABLE #Temp (
	[RecordId] [bigint] NULL,
	[SLabel] [nvarchar](255) NOT NULL
	,[SSchedule_Template] [nvarchar](255) NULL
	,[SList] [bit] NULL,
	[SSubmission_Date] [nvarchar](50) NULL
	,[SApproval_Date] [nvarchar](50) NULL
	,[SActive] [bit] NULL
	, [SExcel_Tab] [bit] NULL, 
	[Label] [nvarchar](255) NOT NULL
	,[Schedule_Template] [nvarchar](255) NULL
	,[List] [bit] NULL,
	[Submission_Date] [nvarchar](50) NULL
	,[Approval_Date] [nvarchar](50) NULL
	,[Active] [bit] NULL 
	,[Excel_Tab] [bit] NULL 
	) ON [PRIMARY]

	INSERT INTO #Temp
	SELECT recordId,label,Schedule_Template,list,submission_date,Approval_date,active,Excel_Tab,
	label,Schedule_Template,list,submission_date,Approval_date,active ,Excel_Tab
	FROM dbo.Canvas_WorkFlow_Schedule
	WHERE Schedule_Template  = LTRIM(RTRIM(REPLACE(@ScheduleName,''''.xlsm'''',''''''''))) And Model = @modelname
	

	IF @@Rowcount = 0 
	BEGIN
--		SELECT @MaxId = MAX(RecordId) FROM Canvas_WorkFlow_Schedule
		INSERT INTO dbo.Canvas_WorkFlow_Schedule 
		(Model,[Label],[Schedule_Template],[List],[Submission_Date],[Approval_Date],[Active])
		VALUES (@ModelName,REPLACE(@ScheduleName,''''.xlsm'''',''''''''), REPLACE(@ScheduleName,''''.xlsm'''',''''''''),0,'''''''','''''''',1)

		INSERT INTO #Temp
		SELECT recordId,
		label,Schedule_Template,list,submission_date,Approval_date,ACTIVE,Excel_Tab, 
		label,Schedule_Template,list,submission_date,Approval_date,ACTIVE,Excel_Tab
		FROM dbo.Canvas_WorkFlow_Schedule
		WHERE Schedule_Template = REPLACE(@ScheduleName,''''.xlsm'''','''''''') And Model = @modelname
	END
	SELECT * FROM #temp
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowScheduleUpdate]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowScheduleUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowScheduleUpdate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowScheduleUpdate]
	@ModelName as nvarchar(255),
	@RecordId as nvarchar(255),
	@Label as nvarchar(255) ='''''''',
	@Schedule_Wizard as nvarchar(255) ='''''''',
	@list as nvarchar(255) ='''''''',
	@submission_date as nvarchar(255) ='''''''',
	@Approval_date as nvarchar(255) ='''''''',
	@ACTIVE  as nvarchar(255) ='''''''',
	@Excel_Tab  as nvarchar(255) =''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
If	@submission_date = ''''$'''' SET @Submission_Date  =''''''''
If	@Approval_date  =''''$'''' SET @Approval_Date = ''''''''

IF @List = ''''true'''' SET @List = 1
IF @List = ''''False'''' SET @List = 0
IF @Active = ''''true'''' SET @List = 1
IF @Active = ''''False'''' SET @List = 0
IF @Excel_Tab = ''''true'''' SET @List = 1
IF @Excel_Tab = ''''False'''' SET @List = 0

DECLARE @WorkFlow Nvarchar(255)
SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName
IF @@ROWCOUNT = 0 SET @WorkFlow = ''''Budget''''

--IF @DefaultValue = ''''$'''' SET @DefaultValue = ''''''''

IF @RecordId > 0
begin 
UPDATE dbo.Canvas_WorkFlow_Schedule
SET label = @Label,
	Schedule_Template = @Schedule_Wizard,
	List = @list,
	Submission_date = @submission_date,
	Approval_date = @Approval_date,
	ACTIVE = @ACTIVE,
	Excel_Tab = @Excel_Tab
WHERE RecordId = @RecordId
END
ELSE
BEGIN
	INSERT INTO Canvas_WorkFlow_Schedule (Model,[Label],[Schedule_Template],[List],[Submission_Date],[Approval_Date],[Active],[Excel_tab])
	VALUES (@ModelName,@Label,@Schedule_Wizard,@List,@Submission_date,@Approval_Date,@Active,@Excel_tab)
END

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowSegment]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowSegment'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowSegment') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowSegment]
	@ModelName as nvarchar(255),
	@IsDriver  as nvarchar(255) = ''''No''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

	print ''''=====''''
--Declare	@ModelName as nvarchar(255),	@IsDriver  as nvarchar(255)
--SET @ModelName = ''''Financials''''
--SET	@IsDriver  = ''''No''''

	print ''''=====''''

	if not exists(Select b.Name from dbo.sysobjects a, dbo.syscolumns b
	Where a.name = ''''Canvas_WorkFlow_Segment'''' and b.name = ''''ReportDefaultValue'''' and a.id = b.id )
	BEGIN
		ALTER TABLE Canvas_WorkFlow_Segment ADD [ReportDefaultValue] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	END

	DECLARE @WorkFlow Nvarchar(255),@Ismeasures Nvarchar(255) 
	CREATE TABLE #Temp(
		[RecordId] [bigint] IDENTITY (1,1),
		[WorkFlow] [nvarchar](50) NULL,
		[DimensionS] [nvarchar](50) NULL,
		[Segment_TypeS] [nvarchar](255) NULL,
		[Driver_NumberS] [bigint] NULL,
		[DefaultValueS] [nvarchar](50) NULL,
		[ReportDefaultValueS] [nvarchar](50) NULL,
		[SystemDimensionS] [Bit] NULL,
		[Dimension] [nvarchar](255) NOT NULL,
		[Segment_Type] [nvarchar](255) NULL,
		[Driver_Number] [bigint] NULL,
		[DefaultValue] [nvarchar](255) NULL,
		[ReportDefaultValue] [nvarchar](255) NULL,
		[SystemDimension] [Bit] NULL
	) ON [PRIMARY]  ' 

			SET @SQLStatement = @SQLStatement + '


	CREATE TABLE #Dim(
		[RecordId] [bigint] IDENTITY (1,1)
		,[Dimension] [nvarchar](50) NULL
		,[Type] Nvarchar(50) NULL
		,[Segment_Type_RecordId] [bigint] NULL
		,[Segment_Type] [nvarchar](255) NULL
		,[DefaultValue] [nvarchar](255) NULL
		,[ReportDefaultValue] [nvarchar](255) NULL
		,[SystemDimension] [Bit] NULL
		) ON [PRIMARY]

	SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName
	IF @@ROWCOUNT = 0 SET @WorkFlow = ''''Budget''''  ' 

			SET @SQLStatement = @SQLStatement + '


	CREATE TABLE #ModelAllDimensions (Model NVARCHAR(100) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Dimension NVARCHAR(255)COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Type] NVARCHAR(50)COLLATE SQL_Latin1_General_CP1_CI_AS)
	
	INSERT INTO #ModelAllDimensions SELECT a.model,a.dimension,a.[type] 
	FROM ModelAllDimensions a

	INSERT INTO #Dim SELECT Dimension,[Type],0,'''''''','''''''','''''''',''''False'''' FROM #ModelAllDimensions WHERE Model = @ModelName
	AND Dimension NOT IN (SELECT Dimension FROM Canvas_WorkFlow_Segment Where Model = @ModelName)
	If @@Rowcount > 0
	BEGIN
		Declare @scenario Nvarchar(250),@scenarioName Nvarchar(50) ,@Time Nvarchar(250),@TimeName Nvarchar(50) ,@Sql Nvarchar(200)
		Select @ScenarioName = Dimension From #Dim Where [Type] = ''''Scenario''''
		SET @Scenario = ''''''''
		Create Table #TempLabel (Label Nvarchar(250))
		SET @Sql = ''''INsert into #TempLabel Select Label From DS_''''+@ScenarioName+'''' Where Label = ''''''''Budget'''''''' ''''
		EXEC(@Sql)
		If @@Rowcount > 0 Set @Scenario =''''Budget''''  ' 

			SET @SQLStatement = @SQLStatement + '

		Select @TimeName = Dimension From #Dim Where [Type] = ''''Time''''
		SET @Time = ''''''''
		SET @Sql = ''''Insert into #TempLabel Select Label From DS_''''+@TimeName+'''' Where Label = ''''''''''''+CAST(YEAR(Getdate()) as VARCHAR(4)) +'''''''''''' ''''
		EXEC(@Sql)
		If @@Rowcount > 0 Set @Time = CAST(YEAR(Getdate()) as VARCHAR(4)) 

		Update #Dim Set SystemDimension = ''''True'''', [Segment_Type_RecordId] = 4 , [Segment_Type] = ''''Account'''' Where type = ''''Account''''
		Update #Dim Set SystemDimension = ''''True'''', [Segment_Type_RecordId] = 12 , [Segment_Type] = ''''BusinessRule'''', DefaultValue = ''''None'''', ReportDefaultValue = ''''None'''' Where type = ''''BusinessRule''''
		Update #Dim Set SystemDimension = ''''True'''', [Segment_Type_RecordId] = 3 , [Segment_Type] = ''''Segment_Fixed'''' Where type = ''''BusinessProcess''''
		Update #Dim Set SystemDimension = ''''True'''', [Segment_Type_RecordId] = 11 , [Segment_Type] = ''''Currency'''', DefaultValue = ''''None'''', ReportDefaultValue = ''''None'''' Where type = ''''Currency''''
		Update #Dim Set SystemDimension = ''''True'''', [Segment_Type_RecordId] = 8 , [Segment_Type] = ''''LineItem'''', DefaultValue = ''''None'''', ReportDefaultValue = ''''None'''' Where type = ''''LineItem''''
		Update #Dim Set SystemDimension = ''''True'''', [Segment_Type_RecordId] = 6 , [Segment_Type] = ''''Scenario'''', DefaultValue = @Scenario, ReportDefaultValue = @Scenario Where type = ''''Scenario''''
		Update #Dim Set SystemDimension = ''''True'''', [Segment_Type_RecordId] = 5 , [Segment_Type] = ''''Time'''', DefaultValue = @Time, ReportDefaultValue = @Time Where type = ''''Time''''
		Update #Dim Set SystemDimension = ''''True'''', [Segment_Type_RecordId] = 7 , [Segment_Type] = ''''TimeDataView'''', DefaultValue = ''''Periodic'''', ReportDefaultValue = ''''Periodic'''' Where type = ''''TimeDataView''''
		Update #Dim Set SystemDimension = ''''True'''', [Segment_Type_RecordId] = 10 , [Segment_Type] = ''''Version'''', DefaultValue = ''''None'''', ReportDefaultValue = ''''None'''' Where type = ''''Version''''

		Declare @BusinessProcessDim Nvarchar(50),@BusinessProcess Nvarchar(255)
		SELECT @BusinessProcessDim = Dimension From #ModelAllDimensions Where Type = ''''BusinessProcess''''
		If @@Rowcount > 0 
		BEGIN
			Truncate table #TempLabel
			SET @Sql = ''''Insert into #TempLabel Select Label From DS_''''+@BusinessProcessDim+'''' Where Label = ''''''''INPUT'''''''' ''''
			EXEC(@Sql)
			If @@Rowcount > 0 
			BEGIN
				Set @BusinessProcess = ''''INPUT'''' 
				Update #Dim Set DefaultValue = ''''INPUT'''' WHere Dimension = @BusinessProcessDim
			END
		END   ' 

			SET @SQLStatement = @SQLStatement + '


		SELECT @IsMeasures = Dimension FROM Canvas_WorkFlow_Segment Where Model = @ModelName
		IF @@ROWCOUNT = 0 
		BEGIN
			INSERT INTO #Dim ([Dimension],[Type],[Segment_Type_RecordId],[Segment_Type],[DefaultValue],[ReportDefaultValue],[SystemDimension])
			VALUES (''''Measures'''',''''Measures'''',9,''''Measures'''',@ModelName+''''_Value'''',@ModelName+''''_Value'''',''''True'''')
		END
		INSERT INTO dbo.Canvas_WorkFlow_Segment
		(Model,[WorkFlow],[Dimension],[Segment_Type_RecordId],[Segment_Type],[DefaultValue],[ReportDefaultValue],[Driver_Number],[SystemDimension])
		SELECT @modelname,@WorkFlow,Dimension,[Segment_Type_RecordId],[Segment_Type],[DefaultValue],[ReportDefaultValue],0,[SystemDimension] FROM #Dim

	END

	Delete from Canvas_WorkFlow_Segment Where Dimension Not in (select dimension from ModelAllDimensions Where Model = @ModelName) And Model = @ModelName
	INSERT INTO #temp 
	([WorkFlow],
	[DimensionS],
	[Segment_TypeS],
	[Driver_NumberS],
	[DefaultValueS],
	[ReportDefaultValueS],
	[SystemDimensionS],
	[Dimension],
	[Segment_Type],
	[Driver_Number],
	[DefaultValue],
	[ReportDefaultValue],
	[SystemDimension]
	)  ' 

			SET @SQLStatement = @SQLStatement + '

	SELECT a.[WorkFlow] 
      ,a.[Dimension] ,a.[Segment_Type] ,a.[Driver_Number] ,a.[DefaultValue],a.[ReportDefaultValue],a.SystemDimension ,Dimension
      ,Segment_Type ,a.[Driver_Number] ,DefaultValue, ReportDefaultValue,a.SystemDimension 
    FROM dbo.Canvas_WorkFlow_Segment a
	WHERE a.Workflow = @Workflow And a.Model = @ModelName
	ORDER BY a.SystemDimension,a.Dimension
	
	
	--Update #temp Set RecordId = 0 Where recordid is null

	IF @ISDriver = ''''No''''
	BEGIN
		SELECT * FROM #temp ORDER BY SystemDimension,Dimension
	END
	ELSE
	BEGIN
		SELECT Dimension,Driver_Number FROM #temp WHERE Segment_Type = ''''Segment_Driver'''' ORDER BY 2
	END
	
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END



-- Drop table #temp,#dim,#ModelAllDimensions




/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowSegmentDimensions]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowSegmentDimensions'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowSegmentDimensions') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowSegmentDimensions]
	@ModelName as nvarchar(255),
	@Driver AS NVARCHAR(255),
	@report as nvarchar(3) = ''''No''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
DECLARE @WorkFlow Nvarchar(255)
CREATE TABLE #Temp(
	[Driver_Number] [Integer] NULL
	,[Dimension] [nvarchar](255) NOT NULL
	,[SegmentType] [nvarchar](255) NULL
	,[DefaultValue] [nvarchar](255) NULL
) ON [PRIMARY]

SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName
IF @@ROWCOUNT = 0 SET @WorkFlow = ''''Budget''''

CREATE TABLE #Dim(
	[RecordId] [bigint] IDENTITY (1,1),
	[Dimension] [nvarchar](50) NULL) ON [PRIMARY]

	IF @Driver = ''''False''''
	BEGIN
		IF @report = ''''No''''
		BEGIN
			INSERT INTO #temp
			SELECT driver_number,Dimension,Segment_Type,DefaultValue FROM dbo.Canvas_WorkFlow_Segment 
			WHERE Workflow = @Workflow And Model = @ModelName
			And Dimension in (Select Dimension From ModelAllDimensions Where Model = @ModelName)
			UNION ALL
			Select 0,Dimension,''''Segment_Fixed'''',''''None'''' from ModelAllDimensions Where Model = @ModelName 
			And Dimension Not in (Select Dimension from Canvas_WorkFlow_Segment Where Model = @ModelName)
 			ORDER BY driver_Number
		END
		ELSE
		BEGIN
			INSERT INTO #temp
			SELECT driver_number,Dimension,Segment_Type,ReportDefaultValue FROM dbo.Canvas_WorkFlow_Segment 
			WHERE Workflow = @Workflow And Model = @ModelName
			And Dimension in (Select Dimension From ModelAllDimensions Where Model = @ModelName)
		END
	END
	ELSE
	BEGIN
		INSERT INTO #temp
		SELECT driver_number,Dimension,Segment_Type,DefaultValue FROM dbo.Canvas_WorkFlow_Segment 
		WHERE Workflow = @Workflow AND Segment_Type = ''''Segment_Driver'''' And Model = @ModelName
		ORDER BY driver_Number
	END
	
	IF @@ROWCOUNT =0 
	BEGIN
		INSERT INTO #Dim SELECT Dimension FROM dbo.ModelDimensions WHERE Model = @ModelName
	
		INSERT INTO #temp
		SELECT 0,Dimension,'''''''','''''''' FROM #Dim
	END
	SELECT * FROM #temp ORDER BY driver_Number
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowSegmentUpdate]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowSegmentUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowSegmentUpdate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowSegmentUpdate]
	@ModelName as nvarchar(255),
	@RecordId  as nvarchar(255),
	@AllParam  as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

--DECLARE	@ModelName as nvarchar(255),@RecordId  as nvarchar(255),@AllParam  as nvarchar(255)

--SET	@ModelName =''''Financials''''
--SET	@RecordId  = ''''39''''
--SET	@AllParam = ''''BusinessRule|Segment_Fixed|0|None|Total''''


	DECLARE @V1 INT,@V2 INT,@V3 INT,@V4 INT,@Dimension NVARCHAR(255)
	,@SegmentType NVARCHAR(255),@DriverNumber NVARCHAR(255),@DefaultValue NVARCHAR(255),@ReportDefaultValue NVARCHAR(255)


SET @V1 = CHARINDEX(''''|'''',@AllParam,1)
	SET @Dimension = SUBSTRING(@allparam,1,@V1-1)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @SegmentType= SUBSTRING(@allparam,@V1+1,@V2-1 -@V1)
	SET @V1 =  CHARINDEX(''''|'''',@AllParam,@V2+1)
	SET @DriverNumber =  SUBSTRING(@allparam,@V2+1,@V1-1 -@V2)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @DefaultValue= SUBSTRING(@allparam,@V1+1,@V2-1 -@V1)
	SET @V1 =  CHARINDEX(''''|'''',@AllParam,@V2+1)
	SET @ReportDefaultValue =  SUBSTRING(@allparam,@V2+1,255)


	--SET @V1 = CHARINDEX('''','''',@AllParam,1)
	--SET @V2 =  CHARINDEX('''','''',@AllParam,@V1+1)
	--SET @V3 =  CHARINDEX('''','''',@AllParam,@V2+1)
	--SET @Dimension = SUBSTRING(@allparam,1,@V1-1)
	--SET @SegmentType= SUBSTRING(@allparam,@V1+1,@V2-1 -@V1)
	--SET @DriverNumber =  SUBSTRING(@allparam,@V2+1,@V3-1 -@V2)
	--SET @DefaultValue =  SUBSTRING(@allparam,@V3+1,@V4-1 -@V3)
	--SET @ReportDefaultValue =  SUBSTRING(@allparam,@V4+1,255)

	DECLARE @WorkFlow Nvarchar(255),@maxdriver INT,@IdTable BIGINT,@Lap INT,@Sql NVARCHAR(MAX)
	,@driv nvarchar(255),@Name nvarchar(255),@OldSegmentType NVARCHAR(255)
	SELECT @Workflow = label FROM Canvas_WorkFlow_Name WHERE model = @modelName
	IF @@Rowcount = 0 SET @Workflow = ''''Budget''''

	SELECT @OldSegmenttype = Segment_type FROM Canvas_Workflow_Segment WHERE dimension = @Dimension And Model = @ModelName

--	IF @DefaultValue = ''''$'''' SET @DefaultValue = ''''''''

	UPDATE dbo.Canvas_WorkFlow_Segment SET [Segment_Type] = @SegmentType,Driver_number = @DriverNumber,DefaultValue = @DefaultValue
	, ReportDefaultValue = @ReportDefaultValue
	WHERE dimension = @Dimension And Model = @ModelName 
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END




/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowSetup]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowSetup'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowSetup') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowSetup]
	@ModelName as nvarchar(255),
	@ShowInactive AS Nvarchar(255) = ''''No'''',
	@Schedule AS Nvarchar(255) = '''''''',
	@DriverFilter1 AS Nvarchar(255) = '''''''',
	@DriverFilter2 AS Nvarchar(255) = '''''''',
	@DriverFilter3 AS Nvarchar(255) = '''''''',
	@DriverFilter4 AS Nvarchar(255) = '''''''',
	@DriverFilter5 AS Nvarchar(255) = '''''''',
	@DriverFilter6 AS Nvarchar(255) = ''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--DECLARE @ModelName as nvarchar(255),@ShowInactive AS Nvarchar(255),@Schedule AS Nvarchar(255) ,@DriverFilter1 AS Nvarchar(255),@DriverFilter2 AS Nvarchar(255),
--	@DriverFilter3 AS Nvarchar(255),@DriverFilter4 AS Nvarchar(255),@DriverFilter5 AS Nvarchar(255),
--	@DriverFilter6 AS Nvarchar(255)

--SET @ModelName = ''''Financials''''
--Set @ShowInactive = ''''No''''
--Set @Schedule  = ''''''''
--Set @DriverFilter1  = ''''''''
--SET @DriverFilter2  = ''''''''
--SET	@DriverFilter3  = ''''''''
--SET	@DriverFilter4  = ''''''''
--SET	@DriverFilter5  = ''''''''
--SET	@DriverFilter6  = ''''''''


BEGIN

	IF @Schedule      = ''''*'''' SET @Schedule = ''''''''
	IF @DriverFilter1 = ''''*'''' SET @DriverFilter1 = ''''''''
	IF @DriverFilter2 = ''''*'''' SET @DriverFilter2 = ''''''''
	IF @DriverFilter3 = ''''*'''' SET @DriverFilter3 = ''''''''
	IF @DriverFilter4 = ''''*'''' SET @DriverFilter4 = ''''''''
	IF @DriverFilter5 = ''''*'''' SET @DriverFilter5 = ''''''''
	IF @DriverFilter6 = ''''*'''' SET @DriverFilter6 = ''''''''

	CREATE TABLE #Temp(
	[RecordId] [bigint] NOT NULL
	,[Scenario] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Time] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[WorkFlow_Description] [nvarchar](250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,SD1 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,SD2 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,SD3 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,SD4 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,SD5 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,SD6 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,SD7 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,SD8 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[SResponsible] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[SApprover] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[SAdministrator] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[SSubmission_Date] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[SApproval_Date] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[SSchedule] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[SActive] [bit] NULL
	,[SExcel_Tab] [bit] NULL
	,D1 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D2 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D3 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D4 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D5 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D6 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D7 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D8 NVARCHAR(255)  COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Responsible] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Approver] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Administrator] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Submission_Date] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ' 

			SET @SQLStatement = @SQLStatement + '

	,[Approval_Date] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Schedule] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Active] [bit] NULL
	,[Excel_Tab] [bit] NULL
	)

	DECLARE @Sql Nvarchar(max),@D1 Nvarchar(255),@D2 Nvarchar(255),@D3 Nvarchar(255),@D4 Nvarchar(255)
	,@D5 Nvarchar(255),@D6 Nvarchar(255),@D7 Nvarchar(255),@D8 Nvarchar(255),@Driver NVARCHAR(1500)
	,@SD1 Nvarchar(255),@SD2 Nvarchar(255),@SD3 Nvarchar(255),@SD4 Nvarchar(255),
	@SD5 Nvarchar(255),@SD6 Nvarchar(255),@SD7 Nvarchar(255),@SD8 Nvarchar(255),@SDriver NVARCHAR(1500)
	,@Show NVARCHAR(5)
	DECLARE @Scenario Nvarchar(100),@Time Nvarchar(100)
	SELECT @Scenario = Dimension FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Scenario'''' And Model = @ModelName
	SELECT @Time = Dimension FROM Canvas_Workflow_Segment WHERE Segment_Type = ''''Time'''' And Model = @ModelName

	SET @Show = ''''True''''
	IF @ShowInactive = ''''Yes'''' SET @Show = ''''False''''

	SELECT @D1 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 1 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D1 = ''''''''''''''''''''''''
	SELECT @D2 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 2 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D2 = ''''''''''''''''''''''''
	SELECT @D3 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 3 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D3 = ''''''''''''''''''''''''
	SELECT @D4 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 4 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D4 = ''''''''''''''''''''''''
	SELECT @D5 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 5 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D5 = ''''''''''''''''''''''''
	SELECT @D6 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 6 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D6 = ''''''''''''''''''''''''
	SELECT @D7 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 7 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D7 = ''''''''''''''''''''''''
	SELECT @D8 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 8 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D8 = ''''''''''''''''''''''''
	SET @Driver = '''',''''+@D1+'''',''''+@D2+'''',''''+@D3+'''',''''+@D4+'''',''''+@D5+'''',''''+@D6+'''',''''+@D7+'''',''''+@D8
	
	SET @sql = ''''INSERT INTO #Temp Select 
	[RecordId],[Scenario],[Time]
	,[WorkFlow_Description]''''
	+@driver+''''
	,[Responsible],[Approver],[Administrator],[Submission_Date],[Approval_Date]
	,[Schedule],[Active],[Excel_Tab]''''
	+@driver+''''
	,[Responsible],[Approver],[Administrator],[Submission_Date],[Approval_Date]
	,[Schedule],[Active],[Excel_Tab]
	FROM Canvas_WorkFlow_Detail 
	Where Model = ''''''''''''+@ModelName+'''''''''''' ''''

	DECLARE @SqlFilter Nvarchar(max),@Id BIGINT,@lap int,@nbfilter INT,@driverfilter Nvarchar(255),@D Nvarchar(255)
	CREATE TABLE #Tempid(memberid BIGINT) 
	SET @lap = 0
	SET @nbfilter = 0 ' 

			SET @SQLStatement = @SQLStatement + '

	CREATE TABLE #TempFilter(label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS) 
	While @lap <= 6
	BEGIN
		IF @lap = 0 SET @driverfilter = @Schedule
		IF @lap = 1 SET @driverfilter = @driverfilter1
		IF @lap = 2 SET @driverfilter = @driverfilter2
		IF @lap = 3 SET @driverfilter = @driverfilter3
		IF @lap = 4 SET @driverfilter = @driverfilter4
		IF @lap = 5 SET @driverfilter = @driverfilter5
		IF @lap = 6 SET @driverfilter = @driverfilter6

		IF @lap = 0 SET @d = ''''Schedule'''' 
		IF @lap = 1 SET @d = @D1
		IF @lap = 2 SET @d = @D2
		IF @lap = 3 SET @d = @D3
		IF @lap = 4 SET @d = @D4
		IF @lap = 5 SET @d = @D5
		IF @lap = 6 SET @d = @D6
		IF @DriverFilter <> '''''''' 
		BEGIN
			IF @lap = 1 CREATE TABLE #TempFilter1(label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS) 
			IF @lap = 2 CREATE TABLE #TempFilter2(label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS) 
			IF @lap = 3 CREATE TABLE #TempFilter3(label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS) 
			IF @lap = 4 CREATE TABLE #TempFilter4(label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS) 
			IF @lap = 5 CREATE TABLE #TempFilter5(label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS) 
			IF @lap = 6 CREATE TABLE #TempFilter6(label NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS) 
			
			SET @Id = 0
			If @Lap > 0
			begin
				TRUNCATE TABLE #tempid
				SET @SqlFilter = ''''INSERT INTO #tempid Select Distinct memberid from DS_'''' + @D + '''' Where label = ''''''''''''+@DriverFilter+''''''''''''''''
				PRINT(@SqlFilter)
				EXEC(@SqlFilter)
				SELECT @ID = memberid FROM #tempid	

				SET @sqlfilter = ''''INSERT INTO #TempFilter'''' + Ltrim(rtrim(@Lap)) + '''' 
				SELECT label FROM DS_'''' + @D + '''' WHERE Memberid IN (SELECT memberid FROM HC_''''+@D+'''' WHERE Parentid = ''''+CAST(@ID AS CHAR)+'''')''''
				PRINT(@SqlFilter)
				EXEC(@SqlFilter)

				IF @nbfilter = 0 SET @Sql = @Sql + '''' AND ''''
				IF @nbfilter > 0 SET @Sql = @Sql + '''' AND ''''
				SET @Sql = @Sql + @D + '''' In (Select Label from #tempFilter'''' + Ltrim(rtrim(@Lap)) + '''') ''''
				SET @nbfilter = @nbfilter + 1
			END
			ELSE
			BEGIN
				
				If @Schedule <> '''''''' 
				BEGIN
				SET @Sql = @Sql + '''' AND  Schedule = ''''''''''''+@Schedule+''''''''''''''''
				SET @nbfilter = @nbfilter + 1	
				END

			END

			
		END
	SET @lap = @lap + 1
	END
--	Print(@Sql)
	EXEC(@Sql)

	SELECT * FROM #Temp WHERE Active = @show ORDER BY D1,D2,D3,D4,D5,Schedule
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END



-- Drop table #temp,#tempid,#tempfilter,#tempfilter1







/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowStatus]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowStatus'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowStatus') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowStatus]
	@Workflow_Detail_RecordId NVARCHAR(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
	
	SELECT DISTINCT '''''''',Submission_Date,Approval_Date,Rejected_Date,[Status],[Version],Workflow_Detail_RecordId,Version_Label
	FROM Canvas_Workflow
	WHERE WorkFlow_Number = 0 AND Workflow_Detail_RecordId = @Workflow_Detail_RecordId
	--UNION ALL
	--SELECT DISTINCT Entity,'''''''' AS Submission_Date,'''''''' AS Approval_Date,'''''''' AS Rejected_Date,''''Ready To Complete'''' AS [Status],''''V01'''' AS [Version]
	--,Label,''''Initial Version''''
	--FROM LST_Workflow_Entity WHERE label = @Workflow_Detail_RecordId AND label NOT IN (SELECT label FROM 
	

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowStatusReport]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowStatusReport'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowStatusReport') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowStatusReport]
	@ModelName as nvarchar(255), 
	@UserName as nvarchar(255) 
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

	CREATE TABLE #temp (Id INT
	,[Workflow_Detail_RecordId] [nvarchar](255) NULL
	,[Submission_Date] [nvarchar](25) NULL
	,[Rejected_Date] [nvarchar](25) NULL
	,[Approval_Date] [nvarchar](25) NULL
	,[WorkFlow_Number] [int] NULL
	,[CreatedateTime] [smalldatetime] NULL
	,[Submission_Comment] [nvarchar](255) NULL
	,[Approval_Comment] [nvarchar](255) NULL
	,[Reject_Comment] [nvarchar](255) NULL
	,[Version] [nvarchar](255) NULL
	,scenario  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[time]  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Max_submission_date  NVARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Max_approval_date  NVARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Schedule NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Status] [nvarchar](50) NULL
	,Workflow_description NVARCHAR(MAx) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D1_description NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,responsible  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,approver  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,administrator  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D1 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D2 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D3 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D4 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D5 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D6 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D7 NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,D8 NVARCHAR(255) )

	DECLARE @Sql Nvarchar(max),@D1 Nvarchar(255),@D2 Nvarchar(255),@D3 Nvarchar(255),@D4 Nvarchar(255),
	@D5 Nvarchar(255),@D6 Nvarchar(255),@D7 Nvarchar(255),@D8 Nvarchar(255),@Driver NVARCHAR(1500),@WinUserName Nvarchar(255)

	--SELECT @WinUserName = WinUser FROM dbo.Canvas_Users WHERE label = @UserName
	--IF @@ROWCOUNT = 0 SET @WinuserName = @Username
	SELECT @WinUserName = WinUser FROM dbo.Canvas_Users WHERE label = @Username
	IF @@ROWCOUNT = 0 
	BEGIN
		SET @WinuserName = @Username
		SELECT @UserName = label FROM dbo.Canvas_Users WHERE WinUser = @WinUsername
	END

	SELECT @D1 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 1 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D1 = ''''''''''''''''''''''''
	SELECT @D2 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 2 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D2 = '''''''''''''''''''''''' ' 

			SET @SQLStatement = @SQLStatement + '

	SELECT @D3 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 3 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D3 = ''''''''''''''''''''''''
	SELECT @D4 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 4 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D4 = ''''''''''''''''''''''''
	SELECT @D5 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 5 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D5 = ''''''''''''''''''''''''
	SELECT @D6 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 6 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D6 = ''''''''''''''''''''''''
	SELECT @D7 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 7 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D7 = ''''''''''''''''''''''''
	SELECT @D8 = dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Driver_Number = 8 And Model = @ModelName
	IF @@ROWCOUNT = 0 SET @D8 = ''''''''''''''''''''''''
	SET @Driver = '''',''''+@D1+'''',''''+@D2+'''',''''+@D3+'''',''''+@D4+'''',''''+@D5+'''',''''+@D6+'''',''''+@D7+'''',''''+@D8
	
--	IF @type = ''''Responsible''''
	BEGIN
		SET @Sql = ''''INSERT INTO #temp
		SELECT DISTINCT 3,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.scenario,b.time,b.submission_date AS Max_Submission_Date,b.approval_date,b.Schedule
		 ,a.[Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM Canvas_Workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = CAST(b.RecordId AS CHAR) AND a.workflow_number = 0 AND a.status = ''''''''In progress''''''''
		AND b.responsible IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		And b.active = ''''''''true''''''''
		And a.Model = ''''''''''''+@Modelname+''''''''''''
		And a.Model = b.model
		UNION ALL
		SELECT DISTINCT 5,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule 
		 ,a.[Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM Canvas_Workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = CAST(b.RecordId AS CHAR) AND a.workflow_number = 0 AND a.status = ''''''''Rejected''''''''
		AND b.responsible IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		And b.active = ''''''''true''''''''
		And a.Model = ''''''''''''+@Modelname+''''''''''''
		And a.Model = b.model
		UNION ALL ' 

			SET @SQLStatement = @SQLStatement + '

		SELECT DISTINCT 7,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule 
		 ,a.[Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM Canvas_Workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = CAST(b.RecordId AS CHAR) AND a.workflow_number = 0 AND a.status = ''''''''Submitted''''''''
		AND b.responsible IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		And b.active = ''''''''true''''''''
		And a.Model = ''''''''''''+@Modelname+''''''''''''
		And a.Model = b.model
		UNION ALL
		SELECT DISTINCT 9,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule 
		 ,a.[Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM Canvas_Workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = CAST(b.RecordId AS CHAR) AND a.workflow_number = 0 AND a.status = ''''''''Approved''''''''
		AND b.responsible IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''') ' 

			SET @SQLStatement = @SQLStatement + '

		And b.active = ''''''''true''''''''
		And a.Model = ''''''''''''+@Modelname+''''''''''''
		And a.Model = b.model ''''
		EXEC(@Sql)
		SET @Sql = ''''INSERT INTO #temp 
		SELECT DISTINCT 1,CAST(b.RecordId AS CHAR),'''''''''''''''','''''''''''''''','''''''''''''''',0,'''''''''''''''','''''''''''''''','''''''''''''''','''''''''''''''',''''''''''''''''
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule
		 ,''''''''Ready to Complete'''''''' AS [Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM dbo.Canvas_WorkFlow_Detail b
		WHERE CAST(b.RecordId AS CHAR) NOT IN (SELECT Workflow_Detail_RecordId FROM Canvas_Workflow)
		AND b.responsible IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''') 
		AND b.ACTIVE = ''''''''True''''''''	
		And b.Model = ''''''''''''+@Modelname+''''''''''''''''
		EXEC(@Sql)
	END ' 

			SET @SQLStatement = @SQLStatement + '

--	IF @type = ''''Approver''''
	BEGIN
		SET @Sql = ''''INSERT INTO #temp
		SELECT DISTINCT 3,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule 
		 ,a.[Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM Canvas_Workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = CAST(b.RecordId AS CHAR) AND a.workflow_number = 0 AND a.status = ''''''''In progress''''''''
		AND b.approver IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Approver <> b.Responsible
		And b.active = ''''''''true''''''''
		And a.Model = ''''''''''''+@Modelname+''''''''''''
		And a.Model = b.model
		UNION ALL
		SELECT DISTINCT 5,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule 
		 ,a.[Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM Canvas_Workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = CAST(b.RecordId AS CHAR) AND a.workflow_number = 0 AND a.status = ''''''''Rejected''''''''
		AND b.approver IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Approver <> b.Responsible
		And b.active = ''''''''true''''''''
		And a.Model = ''''''''''''+@Modelname+''''''''''''
		And a.Model = b.model
		UNION ALL
		SELECT DISTINCT 7,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule 
		 ,a.[Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM Canvas_Workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = CAST(b.RecordId AS CHAR) AND a.workflow_number = 0 AND a.status = ''''''''Submitted''''''''
		AND b.approver IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Approver <> b.Responsible ' 

			SET @SQLStatement = @SQLStatement + '

		And b.active = ''''''''true''''''''
		And a.Model = ''''''''''''+@Modelname+''''''''''''
		And a.Model = b.model
		UNION ALL
		SELECT DISTINCT 9,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule 
		 ,a.[Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM Canvas_Workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = CAST(b.RecordId AS CHAR) AND a.workflow_number = 0 AND a.status = ''''''''Approved''''''''
		AND b.approver IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Approver <> b.Responsible 
		And b.active = ''''''''true'''''''' 
		And a.Model = ''''''''''''+@Modelname+''''''''''''
		And a.Model = b.model ''''
		EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '

		SET @Sql = ''''INSERT INTO #temp 
		SELECT DISTINCT 1,CAST(b.RecordId AS CHAR),'''''''''''''''','''''''''''''''','''''''''''''''',0,'''''''''''''''','''''''''''''''','''''''''''''''','''''''''''''''',''''''''''''''''
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule
		 ,''''''''Ready to Complete'''''''' AS [Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM dbo.Canvas_WorkFlow_Detail b
		WHERE CAST(b.RecordId AS CHAR) NOT IN (SELECT Workflow_Detail_RecordId FROM Canvas_Workflow)
		AND b.approver IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''') 
		AND b.ACTIVE = ''''''''True''''''''		
		AND b.Approver <> b.Responsible 
		And b.Model = ''''''''''''+@Modelname+''''''''''''''''
		EXEC(@Sql)
		
	END
--	IF @type = ''''Administrator''''
	BEGIN
		SET @Sql = ''''INSERT INTO #temp
		SELECT DISTINCT 3,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule 
		 ,a.[Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM Canvas_Workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = CAST(b.RecordId AS CHAR) AND a.workflow_number = 0 AND a.status = ''''''''In progress''''''''
		AND b.Administrator IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Administrator <> b.Responsible
		AND b.Administrator <> b.Approver 
		And b.active = ''''''''true''''''''
		And a.Model = ''''''''''''+@Modelname+''''''''''''
		And a.Model = b.model
		UNION ALL
		SELECT DISTINCT 5,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule 
		 ,a.[Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+'''' ' 

			SET @SQLStatement = @SQLStatement + '

		FROM Canvas_Workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = CAST(b.RecordId AS CHAR) AND a.workflow_number = 0 AND a.status = ''''''''Rejected''''''''
		AND b.Administrator IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Administrator <> b.Responsible
		AND b.Administrator <> b.Approver 
		And b.active = ''''''''true'''''''' 
		And a.Model = ''''''''''''+@Modelname+''''''''''''
		And a.Model = b.model ''''
		EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '

		SET @Sql = ''''INSERT INTO #temp 
		SELECT DISTINCT 7,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule 
		 ,a.[Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM Canvas_Workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = CAST(b.RecordId AS CHAR) AND a.workflow_number = 0 AND a.status = ''''''''Submitted''''''''
		AND b.Administrator IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Administrator <> b.Responsible
		AND b.Administrator <> b.Approver 
		And b.active = ''''''''true''''''''
		And a.Model = ''''''''''''+@Modelname+''''''''''''
		And a.Model = b.model
		UNION ALL
		SELECT DISTINCT 9,a.[Workflow_Detail_RecordId],a.[Submission_Date],a.[Rejected_Date],a.[Approval_Date],a.[WorkFlow_Number]
		,a.[CreatedateTime],a.[Submission_Comment],a.[Approval_Comment],a.[Reject_Comment],a.[Version]
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule 
		 ,a.[Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM Canvas_Workflow a, dbo.Canvas_WorkFlow_Detail b
		WHERE a.Workflow_Detail_RecordId = CAST(b.RecordId AS CHAR) AND a.workflow_number = 0 AND a.status = ''''''''Approved''''''''
		AND b.Administrator IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''')
		AND b.Administrator <> b.Responsible
		AND b.Administrator <> b.Approver 
		And b.active = ''''''''true'''''''' 
		And a.Model = ''''''''''''+@Modelname+''''''''''''
		And a.Model = b.model ''''
		EXEC(@Sql)
		SET @Sql = ''''INSERT INTO #temp 
		SELECT DISTINCT 1,CAST(b.RecordId AS CHAR),'''''''''''''''','''''''''''''''','''''''''''''''',0,'''''''''''''''','''''''''''''''','''''''''''''''','''''''''''''''',''''''''''''''''
		,b.scenario,b.time,b.submission_date,b.approval_date,b.Schedule
		 ,''''''''Ready to Complete'''''''' AS [Status],b.Workflow_description,'''''''''''''''',b.responsible,b.approver,b.administrator''''+@Driver+''''
		FROM dbo.Canvas_WorkFlow_Detail b
		WHERE CAST(b.RecordId AS CHAR) NOT IN (SELECT Workflow_Detail_RecordId FROM Canvas_Workflow)
		AND b.Administrator IN (''''''''''''+@userName+'''''''''''',''''''''''''+@WinuserName+'''''''''''') 
		AND b.ACTIVE = ''''''''True''''''''
		AND b.Administrator <> b.Responsible
		AND b.Administrator <> b.Approver 
		And b.Model = ''''''''''''+@Modelname+'''''''''''' ''''
		EXEC(@Sql)
	END ' 

			SET @SQLStatement = @SQLStatement + '

	Set @Sql = ''''UPDATE #Temp SET D1_description = b.label+'''''''' - ''''''''+b.DESCRIPTION FROM #temp a,DS_''''+@D1+'''' b WHERE a.D1 = b.Label ''''
	EXEC(@Sql) 

	INSERT INTO #temp (ID,D1,D1_Description) SELECT DISTINCT -2,D1,D1_Description FROM #temp

	SELECT * FROM #temp ORDER BY D1,Id
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END




/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowStatusVar]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowStatusVar'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowStatusVar') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowStatusVar]
	@Workflow_Detail_RecordId NVARCHAR(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
	
	SELECT DISTINCT [Status]
	FROM Canvas_Workflow
	WHERE WorkFlow_Number = 0 AND Workflow_Detail_RecordId = @Workflow_Detail_RecordId
	
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowTemplateUpdate]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowTemplateUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowTemplateUpdate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowTemplateUpdate]
	@ModelName as nvarchar(255),
	@Schedule as nvarchar(255),
	@DimRow  as nvarchar(255),
	@DimCol  as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	UPDATE dbo.Canvas_WorkFlow_Schedule SET 
	DimRow = @DimRow, DimCol = @DimCol 
	WHERE Label =  REPLACE(@Schedule,''''.Xlsm'''','''''''')
	And Model = @ModelName
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END




/****** Object:  StoredProcedure [dbo].[Canvas_LST_WorkFlowVersion]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowVersion'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_LST_WorkFlowVersion') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_LST_WorkFlowVersion]
	@Modelname as nvarchar(255),
	@Version as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @Sql nvarchar(max)

	SET @Sql = ''''SELECT DISTINCT [Version_label] FROM dbo.Canvas_WorkFlow WHERE [Version] = @Version and model = ''''''''''''+@modelname+'''''''''''' ''''
	EXEC(@Sql)

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END



/****** Object:  StoredProcedure [dbo].[Canvas_Matching_Report]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Matching_Report'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Matching_Report') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Matching_Report]
@Scen		NVARCHAR(250) ,
@Time		NVARCHAR(250) ,
@Currency	NVARCHAR(250) ,
@Ent		NVARCHAR(250) ,
@Intco		NVARCHAR(250) ,
@TC			NVARCHAR(250) ,
@DiffValueUSER	NVARCHAR(250) ,
@Booking	NVARCHAR(10) = '''''''',
@ModelName	NVARCHAR(100) = ''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
--------------------------------------------------------------------------------------------------------------> DECLARE Variables
BEGIN
	DECLARE @Sql Nvarchar(Max),@Select Nvarchar(Max)
	,@User		NVARCHAR(250) ,@DiffValue Nvarchar(255),@V1 INT,@V2 INT

	SET @V1 = CHARINDEX(''''|'''',@DiffValueUSER,1)
	SET @DiffValue = SUBSTRING(@DiffValueUSER,1,@V1-1)
	SET @V2 =  CHARINDEX(''''|'''',@DiffValueUSER,@V1+1)
	SET @User= SUBSTRING(@DiffValueUSER,@V1+1,255)

	DECLARE @Dest Nvarchar(250),@Col INT,@Ret INT,@Rows INT --????
	DECLARE @IsBreak Bit,@BreakNum INT,@IntcoTemp NVARCHAR(250)
	DECLARE @Dim1 nvarchar(40), @Dim2 nvarchar(40), @Dim3 nvarchar(40)
	DECLARE @MultipleEntity BIT,@OnlyOneEntity INT,@Proc_Id BIGINT
	DECLARE @Entity int,@Intercompany int,@OldReportingCurrency int,@OldDestAccount int,@OldEntity int,@OldIntercompany int,@Account int,@Flow INT
	,@BusinessProcess int,@ReportingCurrency int,@OldBusinessProcess int,@Lap INT,@DestAccount INT

	DECLARE @Model Nvarchar(100),@AccountDim Nvarchar(100),@FlowDim Nvarchar(100),@EntityDim Nvarchar(100)
	,@IntercompanyDim Nvarchar(100),@BusinessProcessDim Nvarchar(100),@ScenarioDim Nvarchar(100),@TimeDim Nvarchar(100)
	,@CurrencyDim Nvarchar(100),@GroupDim Nvarchar(100)

---------------------------------------------------------------------------------------------------------------> 
	SELECT @Proc_ID = MAX(Proc_Id) FROM Canvas_User_Run_Status
	IF @Proc_ID IS NULL  SET @Proc_ID = 0
	SET @Proc_ID = @Proc_Id + 1
---------------------------------------------------------------------------------------------------------------> CREATE TEMP TABLES
	CREATE TABLE #TempN (Id Nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS)
	CREATE TABLE #TempI (Id INT)
	CREATE TABLE #Entity_To_Extract (Entity INt)

	SET @model = @ModelNAme

	SELECT @AccountDim = a.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Model And b.[Type] = ''''Account'''' ' 

			SET @SQLStatement = @SQLStatement + '


	SELECT @BusinessProcessDim = a.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Model And b.[Type] = ''''BusinessProcess''''

	SELECT @ScenarioDim = a.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Model And b.[Type] = ''''Scenario''''

	SELECT @TimeDim = a.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Model And b.[Type] = ''''Time''''

	SELECT @EntityDim = a.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Model And b.[Type] in (''''LegalEntity'''',''''Entity'''')

	SELECT @IntercompanyDim = a.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Model And b.[Type] in (''''Intercompany'''')

	SELECT @CurrencyDim = a.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Model And b.[Type] in (''''Currency'''')

	Create table #destination_Account ([Account] INT,[Accountreceivables] INT,[AccountPayables] INT
	,[Account_Label] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Accountreceivables_Label] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[AccountPayables_Label] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,Matching_Id Bigint)

	Create table #DelAccount ([Account] INT,[Flow] int,[BusinessProcess] int)

	CREATE TABLE #Intercompany_Matching
	([Matching_Rule] [bigint] NULL,[RecordId] [bigint] NULL
	,[Label] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[Description] [nvarchar](250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Entity] [bigint] NULL,[Buyer_Rule] [bit] NULL,[Destination_Other] [bigint] NULL,[Available_Period] [bigint] NULL
	,[Tolerance] [int] NULL,[Dimension_Breakdown] [bigint] NULL,[Source_BusinessProcess] [bigint] NULL,[Destination_BusinessProcess] [bigint] NULL
	,[Destination_Account] [bigint] NULL,[Sign] [bigint] NULL,[Account] [bigint] NULL,[Flow] [bigint] NULL
	,[Source_Filter] [bigint] NULL,[Matching_Type] [bigint] NULL,) ON [PRIMARY]


	Create table #Difference ([Destination_Account] INT
	,[BusinessProcess_MemberId] INT,[Currency_MemberId] INT
	,[Entity_MemberId] INT,[Group_MemberId] INT,[Intercompany_MemberId] INT,[Scenario_MemberId] INT,[Time_MemberId] INT
	,value Float,entity_C INT,value_C Float,DiffValue Float)

	Create Table #Diff ([Destination_Account] INT,[Time] INT,Currency INT
	,entity INT,entity_C INT,DiffValue Float,Existing BIT)

	Create Table #Diff_to_Update ([Destination_Account] INT,[Time] INT,Currency INT
	,entity INT,entity_C INT,DiffValue Float) ' 

			SET @SQLStatement = @SQLStatement + '


	CREATE TABLE #Intercompany_Booking ([Intercompany_Matching_Rule_RecordId] [bigint] NULL,[Matching_Type_RecordId] [bigint] NULL,[Account_MemberId] [bigint] NULL
	,[Flow_MemberId] [bigint] NULL,[Intercompany_MemberId] [bigint] NULL,[Destination_Other_RecordId] [bigint] NULL,Destination_BusinessProcess BIGINT,tolerance Bigint,Buyer_rule Bit	)

	Create table #Report (
	[Destination_Account] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Id] INT
	,[Account_MemberId] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[BusinessProcess_MemberId] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Currency_MemberId] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Entity_MemberId] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Intercompany_MemberId] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Scenario_MemberId] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Time_MemberId] NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,value Float
	,entity_C  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,BusinessProcess_C  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,account_C  NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,value_C FLOAT
	,[SortOrder] Nvarchar(2) COLLATE SQL_Latin1_General_CP1_CI_AS
	,DiffValue Float)

	SELECT * INTO #Booking FROM #Report

	ALTER TABLE #Booking ADD [Matching_Type] [bigint] NULL,[Account] [bigint] NULL,[Flow] [bigint] NULL,[Intercompany] [bigint] NULL
	,[Destination_Other] [bigint] NULL,Destination_BusinessProcess BIGINT,tolerance BIGINT,Buyer_rule Bit	


	Create Table #Booking_To_Compare ([Scenario] INT,[Time] INT,[Currency] INT
	,[Transaction_Currency] INT
	,[Account] INT,Flow INT,entity INT,Intercompany INT,BusinessProcess INT,Value Float,Existing Bit)

	Create Table #Booking_To_Update ([Scenario] INT,[Time] INT,[Currency] INT
	,[Transaction_Currency] INT
	,[Account] INT,Flow INT,entity INT,Intercompany INT,BusinessProcess INT,Value Float)


	CREATE TABLE #Matching_Report(
	[Destination]  [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Scenario]  [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Time]  [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Currency]  [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Destination_Account]  [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Id] [int] NULL
	,[Entity] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[BusinessProcess] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[Account] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Value] [decimal](25, 8) NULL
	,[Entity_C] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[BusinessProcess_C] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[Account_C] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Value_C] [decimal](25, 8) NULL
	,[SortOrder] [Nvarchar](2) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[Diffvalue] [decimal](25, 10) NULL
	,[Matching_Id] [BIGINT] 
	,[Receivables_Id] [BIGINT]
	,[Payables_Id] [BIGINT] 
) ' 

			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''INSERT INTO #Entity_To_Extract Select Memberid from [HC_''''+@EntityDim+'''']
	Where ParentId = ''''+RTRIM(LTRIM(@Ent))
	Exec(@Sql)
	IF @@Rowcount > 1 SET @MultipleEntity = ''''True''''
	
	CREATE TABLE #Time ([Time] BIGINT,label nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS, Time_memberid BIGINT, ismax BIT)
	SET @Sql = ''''INSERT into #TIme select distinct a.memberid,b.label,a.parentid,0 
	From [HC_''''+@TimeDim+''''] a,[DS_''''+@TimeDim+''''] b  where a.ParentId = ''''+@Time+'''' And a.memberid = b.memberid ''''
	EXEC(@Sql)
	IF @@ROWCOUNT = 0 Print ''''No Time''''
	declare @maxtime as nvarchar(255) 
	Select @maxtime = max(label) From #time
	Update #time set ismax = 1 Where label = @maxtime
	
	Create table #Account (
	 Matching_Rule bigint
	,[Account] bigINT
	,[AccountType] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Label] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Description] Nvarchar(512) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Id] [int])

	SET @Sql = ''''INSERT into #account 
	select 
	b.icElim_memberid
	,a.memberid
	,b.[Account Type]
	,b.label
	,b.[Description]
	,0
	from [DS_''''+@AccountDim+''''] b,[HC_''''+@AccountDim+''''] a
	Where
	a.MemberId = b.memberid
	AND a.ParentId = b.Memberid 
	And b.IC = 1 
	And b.icElim_memberid <> 0 ''''
	Print(@Sql)
	EXEC(@Sql)
	

	Declare @max Int,@Hierarchy nvarchar(50),@NBAcc INT

	Create table #Acc (ID INT IDENTITY(1,1),[Memberid] INT,[Label] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS, SequenceNumber INT) ' 

			SET @SQLStatement = @SQLStatement + '


	Create table #Receivables
	(
	[Destination_Account] INT,[Id] INT,[Account_MemberId] INT,[BusinessProcess_MemberId] INT,[Currency_MemberId] INT
	,[Entity_MemberId] INT,[Intercompany_MemberId] INT,[Scenario_MemberId] INT,[Time_MemberId] INT,VALUE Float)

	Create table #Payables
	([Destination_Account] INT,[Id] INT,[Account_MemberId] INT,[BusinessProcess_MemberId] INT,[Currency_MemberId] INT
	,[Entity_MemberId] INT,[Intercompany_MemberId] INT,[Scenario_MemberId] INT,[Time_MemberId] INT,VALUE Float)

	SET @Sql = ''''INSERT INTO #Receivables 
	Select  
	b.[Matching_Rule],0 as numid,[''''+@AccountDim+''''_MemberId],[''''+@BusinessprocessDim+''''_MemberId],[''''+@CurrencyDim+''''_MemberId],[''''+@EntityDim+''''_MemberId]
	,[''''+@IntercompanyDim+''''_MemberId],[''''+@ScenarioDim+''''_MemberId],c.Time_memberid as [''''+@TimeDim+''''_MemberId]
	,SUM(a.[''''+@Model+''''_value])
	From [FACT_''''+@Model+''''_default_partition] a,#account b,#Time c
	Where a.[''''+@ScenarioDim+''''_MemberId] = ''''+@Scen+'''' 
	And a.[''''+@TimeDim+''''_MemberId] = c.[TIME]
	and a.[''''+@IntercompanyDim+''''_MemberId] > 0
	and a.[''''+@CurrencyDim+''''_MemberId] = ''''+@Currency+'''' 
	and a.[''''+@AccountDim+''''_MemberId] = b.Account
	And b.AccountType in (''''''''Income'''''''')
	and a.[''''+@BusinessprocessDim+''''_MemberId] Not in (Select memberid from DS_''''+@BusinessProcessDim+'''' Where Label = ''''''''ELIMINATION'''''''')
	And a.[''''+@EntityDim+''''_MemberId] Not in (Select Memberid from DS_''''+@EntityDim+'''' Where Elim = 1)
	And (a.[''''+@EntityDim+''''_MemberId] IN (Select Entity from #Entity_To_Extract) OR a.[Intercompany_MemberId] IN (Select Entity from #Entity_To_Extract))
	Group by b.[Matching_Rule]
	,[''''+@AccountDim+''''_MemberId],[''''+@BusinessprocessDim+''''_MemberId],[''''+@CurrencyDim+''''_MemberId]
	,[''''+@EntityDim+''''_MemberId],[''''+@IntercompanyDim+''''_MemberId],[''''+@ScenarioDim+''''_MemberId],c.[''''+@TimeDim+''''_MemberId]''''
	print(@Sql)
	EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''INSERT INTO #Receivables 
	Select  
	b.[Matching_Rule],0 as numid,[''''+@AccountDim+''''_MemberId],[''''+@BusinessprocessDim+''''_MemberId],[''''+@CurrencyDim+''''_MemberId],[''''+@EntityDim+''''_MemberId]
	,[''''+@IntercompanyDim+''''_MemberId],[''''+@ScenarioDim+''''_MemberId],c.Time_memberid as [''''+@TimeDim+''''_MemberId]
	,SUM(a.[''''+@Model+''''_value])
	From [FACT_''''+@Model+''''_default_partition] a,#account b,#Time c
	Where a.[''''+@ScenarioDim+''''_MemberId] = ''''+@Scen+'''' 
	And a.[''''+@TimeDim+''''_MemberId] = c.[TIME]
	And c.ismax = 1
	and a.[''''+@IntercompanyDim+''''_MemberId] > 0
	and a.[''''+@CurrencyDim+''''_MemberId] = ''''+@Currency+'''' 
	and a.[''''+@AccountDim+''''_MemberId] = b.Account
	And b.AccountType in (''''''''Asset'''''''')
	and a.[''''+@BusinessprocessDim+''''_MemberId] Not in (Select memberid from DS_''''+@BusinessProcessDim+'''' Where Label = ''''''''ELIMINATION'''''''')
	And a.[''''+@EntityDim+''''_MemberId] Not in (Select Memberid from DS_''''+@EntityDim+'''' Where Elim = 1)
	And (a.[''''+@EntityDim+''''_MemberId] IN (Select Entity from #Entity_To_Extract) OR a.[Intercompany_MemberId] IN (Select Entity from #Entity_To_Extract))
	Group by b.[Matching_Rule]
	,[''''+@AccountDim+''''_MemberId],[''''+@BusinessprocessDim+''''_MemberId],[''''+@CurrencyDim+''''_MemberId]
	,[''''+@EntityDim+''''_MemberId],[''''+@IntercompanyDim+''''_MemberId],[''''+@ScenarioDim+''''_MemberId],c.[''''+@TimeDim+''''_MemberId]''''
	print(@Sql)
	EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '


	SET @Sql = '''' INSERT INTO #Payables 
	Select  b.[Matching_Rule],0 as numid,[''''+@AccountDim+''''_MemberId],[''''+@BusinessprocessDim+''''_MemberId],[''''+@CurrencyDim+''''_MemberId]
	,[''''+@EntityDim+''''_MemberId],[''''+@IntercompanyDim+''''_MemberId],[''''+@ScenarioDim+''''_MemberId],c.[''''+@TimeDim+''''_MemberId]
	,SUM(a.[''''+@Model+''''_value]) 
	From [FACT_''''+@Model+''''_default_partition] a,#account b,#Time c
	Where a.[''''+@ScenarioDim+''''_MemberId] = ''''+@Scen+''''   
	And a.[''''+@TimeDim+''''_MemberId] = c.[TIME]
	and a.[''''+@IntercompanyDim+''''_MemberId] > 0
	and a.[''''+@CurrencyDim+''''_MemberId] = ''''+@Currency+'''' 
	and a.[''''+@AccountDim+''''_MemberId] = b.Account
	And b.AccountType in (''''''''Expense'''''''')
	and a.[''''+@BusinessprocessDim+''''_MemberId] Not in (Select memberid from DS_''''+@BusinessProcessDim+'''' Where Label = ''''''''ELIMINATION'''''''')
	And a.[''''+@EntityDim+''''_MemberId] Not in (Select Memberid from DS_''''+@EntityDim+'''' Where Elim = 1)
	And (a.[''''+@EntityDim+''''_MemberId] IN (Select Entity from #Entity_To_Extract) OR a.[Intercompany_MemberId] IN (Select Entity from #Entity_To_Extract)) 
	Group by b.[Matching_Rule]
	,[''''+@AccountDim+''''_MemberId],[''''+@BusinessprocessDim+''''_MemberId],[''''+@CurrencyDim+''''_MemberId]
	,[''''+@EntityDim+''''_MemberId]
	,[''''+@IntercompanyDim+''''_MemberId],[''''+@ScenarioDim+''''_MemberId],c.[''''+@TimeDim+''''_MemberId] ''''
	print(@Sql)
	EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '


	SET @Sql = '''' INSERT INTO #Payables 
	Select  b.[Matching_Rule],0 as numid,[''''+@AccountDim+''''_MemberId],[''''+@BusinessprocessDim+''''_MemberId],[''''+@CurrencyDim+''''_MemberId]
	,[''''+@EntityDim+''''_MemberId],[''''+@IntercompanyDim+''''_MemberId],[''''+@ScenarioDim+''''_MemberId],c.[''''+@TimeDim+''''_MemberId]
	,SUM(a.[''''+@Model+''''_value]) 
	From [FACT_''''+@Model+''''_default_partition] a,#account b,#Time c
	Where a.[''''+@ScenarioDim+''''_MemberId] = ''''+@Scen+''''   
	And a.[''''+@TimeDim+''''_MemberId] = c.[TIME]
	And c.ismax = 1
	and a.[''''+@IntercompanyDim+''''_MemberId] > 0
	and a.[''''+@CurrencyDim+''''_MemberId] = ''''+@Currency+'''' 
	and a.[''''+@AccountDim+''''_MemberId] = b.Account
	And b.AccountType in (''''''''Liability'''''''',''''''''Equity'''''''')
	and a.[''''+@BusinessprocessDim+''''_MemberId] Not in (Select memberid from DS_''''+@BusinessProcessDim+'''' Where Label = ''''''''ELIMINATION'''''''')
	And a.[''''+@EntityDim+''''_MemberId] Not in (Select Memberid from DS_''''+@EntityDim+'''' Where Elim = 1)
	And (a.[''''+@EntityDim+''''_MemberId] IN (Select Entity from #Entity_To_Extract) OR a.[Intercompany_MemberId] IN (Select Entity from #Entity_To_Extract)) 
	Group by b.[Matching_Rule]
	,[''''+@AccountDim+''''_MemberId],[''''+@BusinessprocessDim+''''_MemberId],[''''+@CurrencyDim+''''_MemberId]
	,[''''+@EntityDim+''''_MemberId]
	,[''''+@IntercompanyDim+''''_MemberId],[''''+@ScenarioDim+''''_MemberId],c.[''''+@TimeDim+''''_MemberId] ''''
	print(@Sql)
	EXEC(@Sql)


	DELETE FROM #Receivables WHERE ABS(VALUE) < 0.4
	DELETE FROM #Payables WHERE  ABS(VALUE) < 0.4 ' 

			SET @SQLStatement = @SQLStatement + '


	SET @Lap = 0
	SET @OldEntity = -1
	SET @OldIntercompany = -1
	SET @oldBusinessProcess = -1
	DECLARE NUM_CUR CURSOR FOR	SELECT [Entity_MemberId],[Intercompany_MemberId]
								,Destination_Account,[Account_MemberId]
								FROM #Receivables order by  
								[Entity_MemberId],[Intercompany_MemberId]
								,Destination_Account,[Account_MemberId]
	OPEN NUM_CUR
	FETCH NEXT FROM NUM_CUR INTO @Entity,@Intercompany,@DestAccount,@Account
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF RTRIM(CAST(@DestAccount as CHAR))+''''_''''+RTRIM(CAST(@Entity as CHAR))+''''_''''+RTRIM(CAST(@Intercompany as CHAR))
		 = 
		RTRIM(CAST(@OldDestAccount as CHAR))+''''_''''+RTRIM(CAST(@OldEntity as CHAR))+''''_''''+RTRIM(CAST(@OldIntercompany as CHAR))
		BEGIN
			SET @Lap = @Lap + 1
		END
		ELSE
		BEGIN
			SET @Lap = 1
		END
		UPDATE #Receivables set Id = @Lap
		where Destination_Account = @DestAccount
		And [entity_MemberId] = @Entity 
		And [intercompany_MemberId] = @Intercompany 
		And [account_MemberId] = @Account 

		SET @OldDestAccount = @DestAccount
		SET @OldEntity = @Entity
		SET @OldIntercompany = @Intercompany
		SET @OldBusinessProcess = @BusinessProcess
	FETCH NEXT FROM NUM_CUR INTO @Entity,@Intercompany,@DestAccount,@Account
	END
	CLOSE NUM_CUR
	DEALLOCATE NUM_CUR

	SET @Lap = 0
	SET @OldEntity = -1
	SET @OldIntercompany = -1
	SET @oldBusinessProcess = -1 ' 

			SET @SQLStatement = @SQLStatement + '


	DECLARE NUM_CUR CURSOR FOR  SELECT [Entity_MemberId],[Intercompany_MemberId]
								,Destination_Account,[Account_MemberId]
								FROM #Payables  order by 
								[Entity_MemberId],[Intercompany_MemberId]
								,Destination_Account,[Account_MemberId]
	OPEN NUM_CUR
	FETCH NEXT FROM NUM_CUR INTO @Entity,@Intercompany,@DestAccount,@Account
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF RTRIM(CAST(@DestAccount as CHAR))+''''_''''+RTRIM(CAST(@Entity as CHAR))+''''_''''+RTRIM(CAST(@Intercompany as CHAR))
		 = 
		RTRIM(CAST(@OldDestAccount as CHAR))+''''_''''+RTRIM(CAST(@OldEntity as CHAR))+''''_''''+RTRIM(CAST(@OldIntercompany as CHAR))
		BEGIN
			SET @Lap = @Lap + 1
		END
		ELSE
		BEGIN
			SET @Lap = 1
		END
	
		UPDATE #Payables set Id = @Lap 
		where Destination_Account = @DestAccount
		And [entity_MemberId] = @Entity 
		And [intercompany_MemberId] = @Intercompany 
		And [account_MemberId] = @Account 
	
		SET @OldDestAccount = @DestAccount
		SET @OldEntity = @Entity
		SET @OldIntercompany = @Intercompany
		SET @OldBusinessProcess = @BusinessProcess

	FETCH NEXT FROM NUM_CUR INTO @Entity,@Intercompany,@DestAccount,@Account
	END
	CLOSE NUM_CUR
	DEALLOCATE NUM_CUR

	UPDATE #payables SET intercompany_memberid = entity_memberid, Entity_Memberid  = intercompany_memberid


	Create table #Solde (
	[Destination_Account] INT
	,[Id] INT
	,[Account_MemberId] INT
	,[BusinessProcess_MemberId] INT
	,[Currency_MemberId] INT
	,[Entity_MemberId] INT
	,[Intercompany_MemberId] INT
	,[Scenario_MemberId] INT
	,[Time_MemberId] INT
	,value Float
	,entity_C INT
	,BusinessProcess_C INT
	,account_C INT
	,value_C Float) ' 

			SET @SQLStatement = @SQLStatement + '


	INSERT INTO #Solde
	SELECT 
	Tmp.[Destination_Account]
	,Tmp.Id
	,Tmp.[Account_MemberId]
	,Tmp.[BusinessProcess_MemberId]
	,Tmp.[Currency_MemberId]
	,Tmp.[Entity_MemberId]
	,Tmp.[Intercompany_MemberId]
	,Tmp.[Scenario_MemberId]
	,Tmp.[Time_MemberId]
	,SUM(Tmp.value) As Value,
	Tmp.Entity_C
	,Tmp.BusinessProcess_C
	,Tmp.account_C
	,SUM(Tmp.value_C) as Value_C
	FROM (
	SELECT a.[Destination_Account],a.Id
	,a.[Account_MemberId],a.[BusinessProcess_MemberId],a.[Currency_MemberId]
	,a.[Entity_MemberId],a.[Intercompany_MemberId],a.[Scenario_MemberId],a.[Time_MemberId]
	,a.value
	,b.[Intercompany_MemberId] as entity_C,b.[Businessprocess_MemberId] as BusinessProcess_C,b.[Account_MemberId] as account_C
	,(b.value) as value_C
	FROM #Receivables a,#Payables b 
	Where a.Id=b.Id
	and a.[Entity_MemberId] = b.[Entity_MemberId]
	and a.[Intercompany_MemberId] = b.[Intercompany_MemberId]
	And a.[Destination_Account] = b.[Destination_Account]
	and a.[Currency_MemberId] = b.[Currency_MemberId]
	UNION all
	SELECT a.[Destination_Account],a.Id
	,a.[Account_MemberId],a.[BusinessProcess_MemberId],a.[Currency_MemberId]
	,a.[Entity_MemberId],a.[Intercompany_MemberId],a.[Scenario_MemberId],a.[Time_MemberId]
	,a.value
	,a.[Intercompany_MemberId] as entity_C,-1 as BusinessProcess_C,-1 as account_C,0 as value_C
	FROM #Receivables a
	Where RTRIM(CAST(a.[Destination_Account] as char))+RTRIM(CAST(a.Id as char))+RTRIM(CAST(a.[Entity_MemberId] as char))+RTRIM(CAST(a.[Intercompany_MemberId] as char))+RTRIM(CAST(a.[Currency_MemberId] as char))
	Not in (Select RTRIM(CAST([Destination_Account] as char))+RTRIM(CAST(Id as char))+RTRIM(CAST([Entity_MemberId] as char))+RTRIM(CAST([Intercompany_MemberId] as char))+RTRIM(CAST([Currency_MemberId] as char))
	From #Payables)
	UNION all ' 

			SET @SQLStatement = @SQLStatement + '


	SELECT a.[Destination_Account],a.Id
	,-1 AS [Account_MemberId],-1 AS [BusinessProcess_MemberId],a.[Currency_MemberId]
	,a.[Entity_MemberId]
	,a.[Intercompany_MemberId],a.[Scenario_MemberId],a.[Time_MemberId],0 as value,
	a.[Intercompany_MemberId] as entity_C,a.[BusinessProcess_MemberId] as BusinessProcess_C,a.[Account_MemberId] as account_C
	,a.value as value_C
	FROM #Payables a
	Where RTRIM(CAST(a.[Destination_Account] as char))+RTRIM(CAST(a.Id as char))+RTRIM(CAST(a.[Entity_MemberId] as char))+RTRIM(CAST(a.[Intercompany_MemberId] as char))+RTRIM(CAST(a.[Currency_MemberId] as CHAR))
	Not in (Select RTRIM(CAST([Destination_Account] as char))+RTRIM(CAST(Id as char))+RTRIM(CAST([Entity_MemberId] as char))+RTRIM(CAST([Intercompany_MemberId] as char))+RTRIM(CAST([Currency_MemberId] as char)) 
	From #Receivables)
	) as tmp
	Group by 
	Tmp.[Destination_Account],Tmp.Id
	,Tmp.[Account_MemberId],Tmp.[BusinessProcess_MemberId],Tmp.[Currency_MemberId]
	,Tmp.[Entity_MemberId],Tmp.[Intercompany_MemberId],Tmp.[Scenario_MemberId],Tmp.[Time_MemberId]
	,Tmp.Entity_C,Tmp.BusinessProcess_C,Tmp.account_C
	Order by [Entity_MemberId],entity_C,[Destination_Account],id

	INSERT INTO #Report SELECT *,''''30'''',0 FROM #Solde 

	INSERT INTO #Report
	SELECT [Destination_Account],0 AS Id
	,0 AS [Account_MemberId],0 AS [BusinessProcess_MemberId],[Currency_MemberId]
	,[Entity_MemberId],0 AS [Intercompany_MemberId],[Scenario_MemberId],[Time_MemberId]
	,SUM(a.VALUE),
	Entity_C,0 AS BusinessProcess_C,0 AS Account_C,SUM(Value_C) AS Value_C,''''20'''' as [SortOrder],Sum(value)+Sum(value_C) as Diff
	FROM #Solde a 
	Group by [Destination_Account],[Currency_MemberId]
	,[Entity_MemberId],[Scenario_MemberId],[Time_MemberId]
	,Entity_C

	INSERT INTO #Report
	SELECT 0 AS [Destination_Account],-1 AS Id
	,0 AS [Account_MemberId],0 AS [BusinessProcess_MemberId],[Currency_MemberId]
	,[Entity_MemberId],0 AS [Intercompany_MemberId],[Scenario_MemberId],[Time_MemberId]
	,SUM(a.VALUE),
	Entity_C,0 AS BusinessProcess_C,0 AS Account_C,SUM(Value_C) AS Value_C,''''10'''' as [SortOrder],Sum(value)+Sum(value_C) as Diff
	FROM #Solde a 
	Group by [Currency_MemberId],[Entity_MemberId],[Scenario_MemberId],[Time_MemberId],Entity_C ' 

			SET @SQLStatement = @SQLStatement + '


	INSERT INTO #Diff 
	Select Distinct [Destination_Account],[Time_MemberId],[Currency_MemberId]
	,[Entity_MemberId],entity_C,Diffvalue,''''False''''
	FROM #Report Where SortOrder = ''''20'''' and DiffValue <> 0 

	Update #Report set DiffValue = b.DiffValue From #Report a,#Diff b 
	Where a.[Entity_MemberId] = b.[Entity]
	AND a.[Currency_MemberId] = b.[Currency]
	AND a.[Time_MemberId] = b.[Time] 
	and a.Entity_C = b.entity_C 
	and a.[Destination_Account] = b.[Destination_Account]
	And a.SortOrder = ''''30''''

	SET @Sql = ''''INSERT INTO #Matching_Report
	select '''''''''''''''',a.[Scenario_MemberId],a.[Time_MemberId],a.[Currency_MemberId]
	,a.[Destination_Account]
	,Id,e.Label as Entity,[BusinessProcess_MemberId],a.[Account_MemberId]
	,Value,f.label as Entity_C,BusinessProcess_C,Account_C
	,Value_C,a.[SortOrder],DiffValue,Destination_Account,0,0
	from #report a,[DS_''''+@EntityDim+''''] e,[DS_''''+@EntityDim+''''] f
	Where a.[Entity_Memberid] = e.MemberId
	And a.Entity_C = f.MemberId
	order by a.[Entity_MemberId],entity_C,a.[Destination_Account],[SortOrder]''''
	PRINT(@Sql)
	EXEC(@Sql)

	SET @Sql = ''''Update #Matching_Report set [Destination_account] = b.[Label]
	From #Matching_Report a,[DS_''''+@AccountDim+''''] b
	Where a.Destination_Account = b.MemberId  and a.[SortOrder] IN (''''''''20'''''''',''''''''30'''''''')''''
	EXEC(@Sql)

	seT @Sql = ''''Update #Matching_Report set Account = b.[Label] 
	From #Matching_Report a,[DS_''''+@AccountDim+''''] b 
	Where a.Account = CAST(b.MemberId as char)  and [SortOrder] = ''''''''30''''''''

	Update #Matching_Report set BusinessProcess = b.[Label] 
	From #Matching_Report a,[DS_''''+@BusinessProcessDim+''''] b 
	Where a.BusinessProcess = CAST(b.MemberId as char)  and [SortOrder] = ''''''''30''''''''

	Update #Matching_Report set BusinessProcess_C = b.[Label] 
	From #Matching_Report a,[DS_''''+@BusinessProcessDim+''''] b 
	Where a.BusinessProcess_C = CAST(b.MemberId as char)  and [SortOrder] = ''''''''30''''''''

	Update #Matching_Report set Account_C = b.[label]
	From #Matching_Report a,[DS_''''+@AccountDim+''''] b 
	Where a.Account_C = CAST(b.MemberId as char) and [SortOrder] = ''''''''30'''''''' '''' ' 

			SET @SQLStatement = @SQLStatement + '

	Print(@Sql)
	EXEC(@Sql)

	Update #Matching_Report 
	set Account='''''''' ,Account_C ='''''''',
	BusinessProcess='''''''' where [SortOrder] IN (''''20'''',''''10'''')
	
	Update #Matching_Report 
	set Account ='''''''' Where account IN (''''None'''')

	Update #Matching_Report 
	set Account_C ='''''''' Where account_C IN (''''None'''')
	
	Update #Matching_Report
	set BusinessProcess ='''''''' WHERE BusinessProcess = ''''None''''

	Update #Matching_Report 
	set BusinessProcess_C ='''''''' Where BusinessProcess_C = ''''None''''
	
	Update #Matching_Report set Account = Destination_Account,Account_C = Destination_Account  Where [SortOrder] = ''''20''''

	Update #Matching_Report 
	set Account = '''''''',Account_C = ''''''''  Where [SortOrder] = ''''10''''

	SET @Sql = ''''Update #Matching_Report set Account = b.[Label]+'''''''' - ''''''''+b.[Description]
	From #Matching_Report a,[DS_''''+@EntityDim+''''] b 
	Where a.Entity = b.Label  
	and [SortOrder] = ''''''''10''''''''

	Update #Matching_Report set Account_C = b.[Label]+'''''''' - ''''''''+b.[Description]
	From #Matching_Report a,[DS_''''+@EntityDim+''''] b 
	Where a.Entity_C = b.Label 
	and [SortOrder] = ''''''''10''''''''''''
	EXEC(@Sql)

----===================================================================================================================> Update Matching Accounts

	SET NOCOUNT ON;

	SELECT [Scenario],[Time],b.[Currency],'''''''','''''''',[Destination_Account],[Id]
	,[Entity]+'''' - ''''+b.[Description],[BusinessProcess],[Account],'''''''',Floor([Value]),[Entity_C],[BusinessProcess_C]
	,[Account_C],'''''''',Floor([Value_C]),[SortOrder],Floor([Diffvalue]) 
	FROM [#Matching_Report] a, DS_Entity b
	WHERE  a.Entity = b.Label 
	And Abs(diffValue) >= @DiffValue 
	And sortorder <> ''''20''''
	ORDER BY Entity,Entity_C
	/*$*/--$RC$--,[Transaction_Currency]
	,Destination_Account,SortOrder 

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END


/*
DROP TABLE  #matching_report
DROP TABLE 	#account,#Receivables,#Receivables2,#Payables,#Payables2,#solde,#Report,#ReportFinal,#tempI,#BusinessProcess,#Intercompany_Matching,
			#Breakdown,#Dim,#Dim2,#BookDiff,#Difference,#report,#Accountdetail,#DelAccount,#temp,
			#Bookdiff2,#BookFinal,#BookFinal2,#TempN,#diff,#accounttmp,#breakdown,#Dimbreakdown,#Entity_To_Extract,#RuleSelected,#Time,#Currency,
			#Diff_to_update,#Intercompany_Booking,#Booking,#Booking_to_compare,#Booking_to_update,#Destination_Account,#Acc,#hierarchy
			
*/





/****** Object:  StoredProcedure [dbo].[Canvas_Max_Voucher]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Max_Voucher'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Max_Voucher') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
 PROCEDURE  [dbo].[Canvas_Max_Voucher]
@modelName Nvarchar(255)
,@Scenario Nvarchar(255)
,@Time Nvarchar(255)
,@Entity Nvarchar(255)
--,@Round Nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

/****** Script for SelectTopNRows command from SSMS  ******/
	SET NOCOUNT ON;
	
	Declare @TimeDim nvarchar(100),@ScenarioDim nvarchar(100),@EntityDim nvarchar(100),@Sql nvarchar(max)

	select @ScenarioDim = A.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] where A.[Model] = @Modelname And b.[Type] <> ''''Scenario''''
	select @TimeDim = A.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] where A.[Model] = @Modelname And b.[Type] <> ''''Time''''
	select @EntityDim = A.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] where A.[Model] = @Modelname And b.[Type] <> ''''Entity''''


	Set @sql = '''' Select max(Voucher)
	From FACT_Vouchers_text_View 
	WHERE 
	''''+@ScenarioDim+'''' = ''''''''''''+@Scenario+''''''''''''
	And LEFT([''''+@TimeDim+''''],4) = ''''''''''''+@Time+''''''''''''
	And ''''+@EntityDim+'''' = ''''''''''''+@Entity+''''''''''''''''
	Exec(@Sql)

END '

IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END



/****** Object:  StoredProcedure [dbo].[Canvas_Profit_CurrentView]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Profit_CurrentView'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Profit_CurrentView') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Profit_CurrentView]
@Model AS NVARCHAR(255)
,@Username AS Nvarchar(255)
,@Dimension AS Nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;

	if not exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = ''''Canvas_Profit_DimensionsCurrentView'''')  
	Begin
		CREATE TABLE [dbo].[Canvas_Profit_DimensionsCurrentView](
		[RecordId] [bigint] IDENTITY(1,1),
		[UserName] [nvarchar](100) NULL,
		[Dimension] [nvarchar](100) NULL,
		[Selected] Bit 
		) ON [PRIMARY]

	end
	Else
	Begin
		Delete from Canvas_Profit_DimensionsCurrentView Where Username = @Username
	End

	INsert into Canvas_Profit_DimensionsCurrentView 
	([UserName],Dimension,Selected)
	Select @UserName,Dimension,0 from ModelAllDimensions Where Model = @Model

	Update Canvas_Profit_DimensionsCurrentView Set Selected = 1 Where USername = @Username And dimension = @dimension

 
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END






/****** Object:  StoredProcedure [dbo].[Canvas_Profit_INIT_DimensionsMembers]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Profit_LST_Dimensions'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Profit_LST_Dimensions') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Profit_INIT_DimensionsMembers]
@Model AS NVARCHAR(255)
,@Dimension Nvarchar(255)
,@raz nvarchar(255) = ''''No''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;

	IF @Raz = ''''Init''''
	BEGIN
		Update Canvas_Profit_DimensionsMembers SET IsDelete = 1 Where Model = @Model  And Dimension = @Dimension
	END
	ELSE
	BEGIN
		DELETE FROM Canvas_Profit_DimensionsMembers WHERE IsDelete = 1 
	END 
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END






/****** Object:  StoredProcedure [dbo].[Canvas_Profit_LST_CurrentView]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Profit_CurrentView'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Profit_LST_CurrentView') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Profit_LST_CurrentView]
 @Username AS Nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;

	Select Distinct Dimension,Selected From [Canvas_Profit_DimensionsCurrentView] Where Username = @Username
 
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END






/****** Object:  StoredProcedure [dbo].[Canvas_Profit_LST_Dimensions]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Profit_LST_Dimensions'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Profit_LST_Dimensions') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Profit_LST_Dimensions]
@Model AS NVARCHAR(255)
,@Selected AS Nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

--Declare @Model AS NVARCHAR(255)
--,@Selected AS Nvarchar(255)

--set @Model = ''''Financials''''
--set @Selected = ''''no''''

	SET NOCOUNT ON;

	Declare @Max INT, @Measures Nvarchar(255), @Measures_Detail Nvarchar(255), @Select Bit

	IF @Selected = ''''Yes'''' SET @Select = 1
	IF @Selected = ''''No'''' SET @Select = 0

	SET @Measures = @Model+''''_Measures''''
	SET @Measures_Detail = @Model+''''_Detail_Measures''''
	Select @Max = Count(*) from Canvas_Profit_Dimensions 
	

	Create table  #temp (
	id INT identity(1,1)
	,recordid INT
	,[Dimension] [nvarchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS
	,[Selected] [bit]
	,Label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS
	 ) 

	 Insert into #temp (recordid,Dimension,Selected,label)
	 Select 0,Dimension,0,'''''''' From ModelAllDimensions Where Model = @Model
	 And Dimension Not in (Select Dimension From Canvas_Profit_Dimensions Where Model = @Model)
	 And Type Not in (''''Account'''',''''TimeDataView'''',''''Time'''',''''Version'''',@Measures, @Measures_Detail,''''LineItem'''',''''BusinessProcess'''',''''Scenario'''',''''Currency'''',''''Intercompany'''') 

	 update #temp set recordid = id + @Max

	 --SET IDENTITY_INSERT Canvas_profit_Dimensions On
	Insert into Canvas_profit_Dimensions 
	 ([Model]      ,[Dimension]      ,[Selected])	Select @Model, Dimension,0 from #temp
	 --SET IDENTITY_INSERT Canvas_profit_Dimensions oFF

	delete from Canvas_Profit_DimensionsMembers where dimension not in (Select dimension from Canvas_Profit_Dimensions where selected = 1) 

	Truncate table #temp
	 
	Insert into #temp Select a.recordid,a.Dimension,@Select, label
	From Canvas_Profit_Dimensions a 
	left join Canvas_Profit_DimensionsMembers b on a.Dimension = b.dimension
	Where a.Selected = @Select
	ORDER BY Dimension

	update #temp set label = '''''''' where label is null

	Select ID,Dimension,label from #temp
	 
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END




/****** Object:  StoredProcedure [dbo].[Canvas_Profit_LST_DimensionsMembers]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Profit_LST_Dimensions'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Profit_LST_Dimensions') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Profit_LST_DimensionsMembers]
@Model AS NVARCHAR(255)
,@Dimension Nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
	Declare @Sql Nvarchar(Max)

	Set @Sql = ''''Select a.Label,a.Label+'''''''' ''''''''+b.Description 
	 From Canvas_Profit_DimensionsMembers a,DS_''''+@Dimension+''''  b
	 Where a.Model = ''''''''''''+@Model+'''''''''''' 
	 And a.Dimension = ''''''''''''+@Dimension+'''''''''''' 
	 And a.Memberid = b.memberid ''''
	 Exec(@Sql)	 
	 
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END





/****** Object:  StoredProcedure [dbo].[Canvas_Profit_Update_Dimensions]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Profit_LST_Dimensions'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Profit_LST_Dimensions') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Profit_Update_Dimensions]
@Model AS NVARCHAR(255)
,@Dimension AS Nvarchar(255)
,@Selection as Nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	
	Declare @Selected Bit
	Set @Selected = 1
	IF @Selection = ''''No'''' SET @Selected = 0

	Update [Canvas_profit_Dimensions] SET Selected = @Selected Where Dimension = @Dimension and model = @Model
	 
END '
IF @Debug <> 0 
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END






/****** Object:  StoredProcedure [dbo].[Canvas_Profit_Update_DimensionsMembers]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Profit_LST_Dimensions'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Profit_LST_Dimensions') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Profit_Update_DimensionsMembers]
@Model AS NVARCHAR(255)
,@Dimension AS Nvarchar(255)
,@Label Nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

--Declare @Model AS NVARCHAR(255),Dimension AS Nvarchar(255),@Label Nvarchar(255)
--Set @Model = ''''Financials''''
--Set @Dimension = ''''Entity''''
--Set @label = ''''LE14''''


	DECLARE @Sql nvarchar(Max), @Max INT
	Create table #temp (Label Nvarchar(255))
	
	Set @Sql = ''''INSERT INTO #Temp
	Select Label From Canvas_Profit_DimensionsMembers
	Where Model = ''''''''''''+@Model+''''''''''''
	And Dimension = ''''''''''''+@Dimension+''''''''''''
	And Label = ''''''''''''+@Label+''''''''''''''''
	Exec(@sql)
	IF @@Rowcount = 0
	BEGIN
		
		Select @Max = MAX(Recordid) From Canvas_Profit_DimensionsMembers
		IF @MAX IS NULL SET @MAX = 0
		IF @@ROWCOUNT = 0 SET @Max = 0

		
		SET @Sql = '''' 
		INSERT INTO Canvas_Profit_DimensionsMembers 
		(RecordID,Model,Dimensoin,memberid,label,IsDelete)
		Select ''''+CAST(@Max + 1 as char)+'''',''''''''''''+@Model+'''''''''''',''''''''''''+@Dimension+'''''''''''',Memberid,''''''''''''+@Label+'''''''''''',0
		From DS_''''+@Dimension+'''' Where label = ''''''''''''+@Label+'''''''''''' '''' 
		Print(@Sql)
		EXEC(@Sql)

	END
	ELSE
	BEGIN
		Update Canvas_Profit_DimensionsMembers Set IsDelete = 0 Where Model = @Model And Dimension = @Dimension And Label = @Label
	END
	 
END '
IF @Debug <> 0 
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END
		
-- Drop table #temp





/****** Object:  StoredProcedure [dbo].[Canvas_Profitability]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Profitability'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Profitability') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Profitability]
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

--Declare @AsType INT
--SET @AsType = 2
---- drop table  #temp_parametervalues 
---- Select * into  #temp_parametervalues  from  temp_parametervalues 
--/****** Script for SelectTopNRows command from SSMS  ******/

DECLARE @ScenarioID BIGINT
,@TimeID BIGINT
,@BusinessprocessID BIGINT
,@BusinessprocessAccID BIGINT
,@BusinessprocessSprID BIGINT
,@BusinessprocessMemberid BIGINT
,@Time  Nvarchar(255)
,@User Nvarchar(255)
,@ModelName Nvarchar(50)

DECLARE @DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max),@Lap INT,@Count INT,@Lap2 INT,@Max INT,@Params Nvarchar(max)
declare @Found int,@Alldim Nvarchar(Max),@Alldim2 Nvarchar(Max),@Where NVARCHAR(Max),@WhereAll NVARCHAR(Max),@Otherdim Nvarchar(Max),@Sep Nvarchar(2)
Declare  @AccountDim Nvarchar(50),@ScenarioDim Nvarchar(50),@EntityDim Nvarchar(50),@BusinessProcessDim Nvarchar(50),@CurrencyDim Nvarchar(50)
,@TimeDim Nvarchar(50),@LineItemDim nvarchar(50),@VersionDim nvarchar(50),@year NVARCHAR(4),@YearID BIGINT,@Suite NVARCHAR(5),@table NVARCHAR(50),@Value NVARCHAR(50)

Select @user = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''
Select @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''



	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0 ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Lap = 1 
	SET @Count = 1 
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname+'''''''' And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''
		If @DimLabel = ''''LineItem'''' SET @DimType = ''''LineItem''''
		If @DimLabel = ''''Version'''' SET @DimType = ''''Version''''
		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Entity''''
		begin
			set @EntityDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Currency''''
		begin
			set @CurrencyDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end ' 


			SET @SQLStatement = @SQLStatement + '

		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''LineItem''''
		begin
			set @LineItemDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Version''''
		begin
			set @VersionDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType

	end
	close Dim_cursor
	deallocate Dim_cursor ' 


			SET @SQLStatement = @SQLStatement + '
 

	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')

	Set @Alldim = @Alldim + '''',[TimeDataView] ''''

----select @ScenarioID = Memberid From #temp_parametervalues Where parameterName = ''''ScenarioMbrs''''
--	set @Params = ''''@ScenarioIDOUT nvarchar(20) OUTPUT''''
--	set @SQL = ''''select @ScenarioIDOUT=[MemberId] from [#temp_parametervalues] where [parameterName]=''''''''ScenarioMbrs''''''''''''
--	exec sp_executesql @sql, @Params, @ScenarioIDOUT=@Scenarioid OUTPUT

--	Select @BusinessprocessID = Memberid From Ds_BusinessProcess Where Label = ''''BR_AS''''
	set @Params = ''''@BusinessprocessIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''BR_Profitability''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessIDOUT=@BusinessprocessID OUTPUT

	set @Params = ''''@BusinessprocessAccIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessAccIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''profit_account''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessaccIDOUT=@BusinessprocessaccID OUTPUT

	set @Params = ''''@BusinessprocessSprIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessSprIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''profit_Spread''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessSprIDOUT=@BusinessprocessSprID OUTPUT

--==============================================> Debut StartPeriod
 ' 


			SET @SQLStatement = @SQLStatement + '


Create table #Time ([Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,Time_Memberid BIGINT)
Create table #Year ([Time] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

INSERT INTO #Time
([Time],Time_Memberid)
Select label,Memberid
from DS_Time 
Where Memberid in (Select Memberid from #Temp_parameterValues Where parametername = ''''TimeMbrs'''')
Order by [Label] ' 


			SET @SQLStatement = @SQLStatement + '


INSERT INTO #year SELECT DISTINCT LEFT(Time,4) FROM #time
SELECT @Year = Time FROM #Year

set @Params = ''''@YearIDOUT nvarchar(20) OUTPUT''''
set @SQL = ''''select @YearIDOUT=[MemberId] from [DS_''''+@TimeDim+''''] where [Label] IN (''''''''''''+@Year+'''''''''''',''''''''FY''''+@Year+'''''''''''')''''
exec sp_executesql @sql, @Params, @YearIDOUT=@YearID OUTPUT

Create Table #Fact(Value Float)
Set @Sql = ''''ALTER TABLE #Fact ADD ''''+REPLACE(@Alldim,'''']'''',''''_Memberid] BIGINT'''')
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


SELECT * INTO #FactAmount FROM #fact
SELECT * INTO #FactFinal FROM #fact

ALTER TABLE #FactAmount ADD Rule_Memberid BIGINT
ALTER TABLE #Fact ADD OriginalDim BIGINT, Spread_Value FLOAT, Final_Value FLOAT,original Bit
ALTER TABLE #FactFinal ADD original Bit
CREATE Table #FactSpread(Rule_Memberid BIGINT,Scenario_Memberid BIGINT,[Time_Memberid] BIGINT,Dimension BIGINT,Value Float,Total Float)
Create Table #FactTotal (Rule_Memberid BIGINT,Scenario_Memberid BIGINT,[Time_Memberid] BIGINT,Dimension BIGINT,Value FLOAT)

SET @Sql = ''''DELETE FROM [FACT_''''+@ModelName+''''_Default_Partition]
Where [''''+@ScenarioDim+''''_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''ScenarioMbrs'''''''')
And [''''+@TimeDim+''''_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''''''TimeMbrs'''''''')
--And [''''+@VersionDim+''''_MemberId] = -1
And [''''+@BusinessprocessDim+''''_Memberid] = ''''+CAST(@BusinessprocessID AS Char)
Print(@Sql)
EXEC(@Sql)

CREATE TABLE #Account (Dimension  NVARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS ,Account_memberid BIGINT, [RULE_label] Nvarchar(255)  COLLATE SQL_Latin1_General_CP1_CI_AS ,Rule_Memberid BIGINT,Rule_Type NVARCHAR(1))
SET @Sql = ''''INSERT INTo #Account
Select REPLACE(c.Label,''''''''V'''''''','''''''''''''''') ,a.[''''+@AccountDim+''''_Memberid], a.''''+@ModelName+''''_Text ,b.memberid,''''''''S''''''''
From Fact_''''+@ModelName+''''_Text a, DS_''''+@AccountDim+'''' b, DS_Version c 
Where   a.[''''+@ScenarioDim+''''_Memberid] in (Select Memberid From #temp_parametervalues Where parameterName = ''''''''ScenarioMbrs'''''''')
	And a.[''''+@TimeDim+''''_Memberid] = -1
	And a.''''+@ModelName+''''_Text = b.Label
	And a.version_Memberid = c.memberid
	And a.[''''+@BusinessprocessDim+''''_Memberid] = ''''+CAST(@BusinessprocessAccID AS CHAR)+'''' 
	AND b.[Memberid] IN (Select Memberid from [DS_''''+@AccountDim+''''] Where KEYNAME_ACCOUNT = ''''''''Profitability_Spread'''''''')
UNION ALL
Select REPLACE(c.Label,''''''''V'''''''','''''''''''''''') ,a.[''''+@AccountDim+''''_Memberid], a.''''+@ModelName+''''_Text ,b.memberid,''''''''A''''''''
From Fact_''''+@ModelName+''''_Text a, DS_''''+@AccountDim+'''' b, DS_Version c 
Where   a.[''''+@ScenarioDim+''''_Memberid] in (Select Memberid From #temp_parametervalues Where parameterName = ''''''''ScenarioMbrs'''''''')
	And a.[''''+@TimeDim+''''_Memberid] = -1
	And a.''''+@ModelName+''''_Text = b.Label
	And a.version_Memberid = c.memberid
	And a.[''''+@BusinessprocessDim+''''_Memberid] = ''''+CAST(@BusinessprocessAccID AS CHAR)+'''' 
	AND b.[Memberid] NOT IN (Select Memberid from [DS_''''+@AccountDim+''''] Where KEYNAME_ACCOUNT = ''''''''Profitability_Spread'''''''')	''''
Print(@Sql)
EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


CREATE TABLE #profit (ID INT IDENTITY(1,1),Recordid INT,Dimension NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
CREATE TABLE #Where (ID INT IDENTITY(1,1),Recordid INT,Dimension NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS)

INSERT INTO #Where SELECT RecordId, Dimension FROM dbo.Canvas_Profit_Dimensions ORDER BY RecordId
SET @max = @@Rowcount


Declare @Selected BIT
SET  @lap = 1
SET @WhereAll = ''''''''
WHILE @Lap <= @max
BEGIN
	SELECT @Dimlabel = Dimension FROM #Where WHERE ID  = @lap
	
		SET @WhereAll = @WhereAll +'''' 
		AND [''''+@Dimlabel+''''_Memberid] = -1''''


SET @lap = @lap + 1
END

INSERT INTO #profit SELECT RecordId, Dimension FROM dbo.Canvas_Profit_Dimensions WHERE Selected = 1 ORDER BY Dimension
SET @max = @@Rowcount

UPDATE #Account SET Dimension = b.Dimension FROM #Account a, #profit b
WHERE 
CAST(a.Dimension AS INT) = b.ID ' 


			SET @SQLStatement = @SQLStatement + '


SET @lap = 1
WHILE @Lap < = @Max
BEGIN
	TRUNCATE TABLE #Fact
	TRUNCATE TABLE #FactAmount
	TRUNCATE TABLE #FactSpread
	TRUNCATE TABLE #FactTotal

	IF @lap = 1 SET @Suite = ''''''''
	IF @lap > 1 SET @Suite = '''' * -1''''
	IF @Lap = 1 SET @table = ''''[Fact_''''+@ModelName+''''_Default_Partition]''''
	IF @Lap > 1 SET @table = ''''#FactFinal''''
	IF @Lap = 1 SET @value = ''''[''''+@ModelName+''''_Value]''''
	IF @Lap > 1 SET @value = ''''Value''''

	SELECT @Dimlabel = Dimension FROM #profit WHERE ID  = @lap
	SET @Where = REPLACE(@WHEREAll,''''AND [''''+@Dimlabel+''''_Memberid] = -1'''','''''''')	 ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''INSERT INTO #FactSpread 
	Select 
	  a.[''''+@AccountDim+''''_Memberid]
	, a.[''''+@ScenarioDim+''''_Memberid]
	, a.[''''+@TimeDim+''''_Memberid]
	, a.[''''+@DimLabel+''''_Memberid]
	, a.[''''+@ModelName+''''_Value]
	, 0 As Total
	From [Fact_''''+@ModelName+''''_Default_Partition] a, #Time b
	Where a.[''''+@AccountDim+''''_Memberid] in (Select Memberid from [DS_''''+@AccountDim+''''] Where KEYNAME_ACCOUNT = ''''''''Profitability_Spread'''''''')
	And a.[''''+@EntityDim+''''_Memberid] = -1
	And a.[''''+@CurrencyDim+''''_Memberid] = -1
	And a.[''''+@ScenarioDim+''''_Memberid] in (Select Memberid From #temp_parametervalues Where parameterName = ''''''''ScenarioMbrs'''''''')
	And a.[''''+@TimeDim+''''_Memberid] = b.Time_memberid 
	And [''''+@BusinessprocessDim+''''_Memberid] = ''''+CAST(@BusinessprocessSprID AS CHAR)+'''' 
	And a.[''''+@VersionDim+''''_MemberId] = -1 ''''
	+@Where
	Print(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''INSERT INTO #FactSpread 
	Select 
	  a.[''''+@AccountDim+''''_Memberid]
	, a.[''''+@ScenarioDim+''''_Memberid]
	, a.[''''+@TimeDim+''''_Memberid]
	, a.[''''+@DimLabel+''''_Memberid]
	, a.[''''+@ModelName+''''_Value]
	, 0 As Total
	From [Fact_''''+@ModelName+''''_Default_Partition] a, #Time b
	Where a.[''''+@AccountDim+''''_Memberid] in (Select Rule_Memberid from #Account Where Rule_Type = ''''''''A'''''''')
	And a.[''''+@EntityDim+''''_Memberid] = -1
	And a.[''''+@CurrencyDim+''''_Memberid] = -1
	And a.[''''+@ScenarioDim+''''_Memberid] in (Select Memberid From #temp_parametervalues Where parameterName = ''''''''ScenarioMbrs'''''''')
	And a.[''''+@TimeDim+''''_Memberid] = b.Time_memberid 
	And [''''+@BusinessprocessDim+''''_Memberid] = ''''+CAST(@BusinessprocessAccID AS CHAR)+'''' 
	And a.[''''+@VersionDim+''''_MemberId] = -1 ''''
	+@Where
	Print(@Sql)
	EXEC(@Sql) ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''INSERT INTO #FactTotal
	SELECT 
	  a.[''''+@AccountDim+''''_Memberid]
	, a.[''''+@ScenarioDim+''''_Memberid]
	, a.[''''+@TimeDim+''''_Memberid]
	, -1 
	,SUM(a.[''''+@ModelName+''''_Value]) 
	From [Fact_''''+@ModelName+''''_Default_Partition] a, #Time b
	Where a.[''''+@AccountDim+''''_Memberid] in (Select Memberid from [DS_''''+@AccountDim+''''] Where KEYNAME_ACCOUNT = ''''''''Profitability_Spread'''''''')
	And a.[''''+@EntityDim+''''_Memberid] = -1
	And a.[''''+@CurrencyDim+''''_Memberid] = -1
	And a.[''''+@ScenarioDim+''''_Memberid] in (Select Memberid From #temp_parametervalues Where parameterName = ''''''''ScenarioMbrs'''''''')
	And a.[''''+@TimeDim+''''_Memberid] = b.Time_memberid 
	And [''''+@BusinessprocessDim+''''_Memberid] = ''''+CAST(@BusinessprocessSprID AS CHAR)+'''' 
	And a.[''''+@VersionDim+''''_MemberId] = -1 ''''
	+@Where+'''' 
	Group By a.[''''+@AccountDim+''''_Memberid],a.[''''+@ScenarioDim+''''_Memberid], a.[''''+@TimeDim+''''_Memberid] ''''
	Print(@Sql)
	EXEC(@Sql) ' 



			SET @SQLStatement = @SQLStatement + '



	SET @Sql = ''''INSERT INTO #FactTotal
	SELECT 
	  a.[''''+@AccountDim+''''_Memberid]
	, a.[''''+@ScenarioDim+''''_Memberid]
	, a.[''''+@TimeDim+''''_Memberid]
	, -1 
	,SUM(a.[''''+@ModelName+''''_Value]) 
	From [Fact_''''+@ModelName+''''_Default_Partition] a, #Time b
	Where a.[''''+@AccountDim+''''_Memberid] in (Select Rule_Memberid from #Account Where Rule_Type = ''''''''A'''''''')
	And a.[''''+@EntityDim+''''_Memberid] = -1
	And a.[''''+@CurrencyDim+''''_Memberid] = -1
	And a.[''''+@ScenarioDim+''''_Memberid] in (Select Memberid From #temp_parametervalues Where parameterName = ''''''''ScenarioMbrs'''''''')
	And a.[''''+@TimeDim+''''_Memberid] = b.Time_memberid 
	And [''''+@BusinessprocessDim+''''_Memberid] = ''''+CAST(@BusinessprocessSprID AS CHAR)+'''' 
	And a.[''''+@VersionDim+''''_MemberId] = -1 ''''
	+@Where+'''' 
	Group By a.[''''+@AccountDim+''''_Memberid],a.[''''+@ScenarioDim+''''_Memberid], a.[''''+@TimeDim+''''_Memberid] ''''
	Print(@Sql)
	EXEC(@Sql)


	UPDATE #FactSpread SET total = a.Value / b.Value 
	FROM #FactSpread a, #factTotal b 
	WHERE a.Scenario_Memberid = b.Scenario_Memberid 
	AND a.time_memberid = b.Time_Memberid 
	AND a.Rule_memberid = b.Rule_memberid ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''INSERT INTO #FactAmount 
	Select SUM(a.''''+@Value+'''')
	,''''+REPLACE(REPLACE(@Alldim,'''']'''',''''_Memberid]''''),''''['''',''''a.['''')+'''', c.Rule_memberid
	From ''''+ @Table + '''' a, #time b, #Account c
	Where 
	c.Dimension = ''''''''''''+@DimLabel+''''''''''''''''
--	IF @Lap > 1 SET @Sql = @Sql + '''' And original = 0 ''''
	SET @Sql = @Sql + '''' And a.[''''+@AccountDim+''''_Memberid] = c.Account_memberid
	And a.[''''+@ScenarioDim+''''_Memberid] in (Select Memberid From #temp_parametervalues Where parameterName = ''''''''ScenarioMbrs'''''''')
	And a.[''''+@TimeDim+''''_Memberid] = b.Time_memberid 
	And a.[''''+@versionDim+''''_Memberid] = -1
	And a.[''''+@DimLabel+''''_Memberid] in (Select memberid From [Canvas_profit_Dimensionsmembers] WHERE Dimension = ''''''''''''+@DimLabel+'''''''''''')''''
	IF @Lap > 1 SET @SQL = @Sql + '''' AND a.[''''+@BusinessProcessDim+''''_Memberid] = ''''+LTRIM(RTRIM(CAST(@BusinessprocessID AS char)))
	SET @Sql = @Sql + '''' GROUP BY ''''+REPLACE(REPLACE(@Alldim,'''']'''',''''_Memberid]''''),''''['''',''''a.['''')+'''', c.Rule_memberid ''''
	Print(@Sql)
	EXEC(@Sql)

	SET @AllDim2 = REPLACE(@Alldim,'''']'''',''''_Memberid]'''')
	SET @AllDim2 = REPLACE(@Alldim2,''''['''',''''a.['''')
	SET @AllDim2 = REPLACE(@Alldim2,''''a.[''''+@DimLabel+''''_Memberid]'''',''''b.[Dimension]'''')

	SET @Sql = ''''INSERT INTO #Fact
	SELECT a.Value,''''+@AllDim2+ '''',a.[''''+@DimLabel+''''_Memberid],b.Total,a.Value * b.Total *-1 ,0
	FROM #factamount a, #FactSpread b
	WHERE a.[''''+@ScenarioDim+''''_Memberid] = b.Scenario_Memberid 
	AND a.[''''+@TimeDim+''''_Memberid] = b.Time_Memberid 
	AND a.Rule_Memberid = b.Rule_Memberid ''''
	Print (@Sql)
	EXEC (@Sql) ' 


			SET @SQLStatement = @SQLStatement + '



	IF @Count = 1
	BEGIn
		SET @AllDim2 = REPLACE(@AllDim,'''']'''',''''_Memberid]'''')
		SET @AllDim2 = REPLACE(@Alldim2,''''[''''+@BusinessprocessDim+''''_Memberid]'''',LTRIM(RTRIM(CAST(@BusinessprocessID AS char))))

		SET @Sql = ''''INSERT INTO [FACT_''''+@ModelName+''''_Default_Partition]
		(''''+ REPLACE(@AllDim,'''']'''',''''_Memberid]'''')+'''',[''''+@ModelName+''''_Value],USerid,ChangeDateTime)
		SELECT ''''+@AllDim2+'''',Value*-1,''''''''''''+@User+'''''''''''',GETDATE()
		FROM #FactAmount 
		Where 
		Value <> 0 ''''
		Print (@Sql)
		EXEC(@Sql)

		SET @Count = 2
		--SET @Sql = ''''INSERT INTO #Fact
		--SELECT a.Value,''''+@AllDim2+ '''',a.[''''+@DimLabel+''''_Memberid],1,a.Value ,1
		--FROM #factamount a ''''
		--Print (@Sql)
		--EXEC (@Sql)
	END
	IF @lap = 1
	BEGIn

		SET @Sql = ''''UPDATE #fact SET [''''+@BusinessProcessDim+''''_Memberid] = ''''+LTRIM(RTRIM(CAST(@BusinessprocessID AS char)))
		EXEC(@Sql)
	END
   
 	TRUNCATE TABLE #factfinal

	SET @Sql = ''''INSERT INTO #FACTFinal
	SELECT Sum(Final_Value),''''+REPLACE(@AllDim,'''']'''',''''_Memberid]'''')+'''',Original
	FROM #Fact  
	Where 
	Final_Value <> 0 
	Group by ''''+REPLACE(@AllDim,'''']'''',''''_Memberid]'''')+'''',original''''
	Print (@Sql)
	EXEC(@Sql)
	SET @Lap = @lap + 1

END ' 


			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''INSERT INTO [FACT_''''+@ModelName+''''_Default_Partition]
	(''''+ REPLACE(@AllDim,'''']'''',''''_Memberid]'''')+'''',[''''+@ModelName+''''_Value],USerid,ChangeDateTime)
	SELECT ''''+REPLACE(@AllDim,'''']'''',''''_Memberid]'''')+'''',Value,''''''''''''+@User+'''''''''''',GETDATE()
	FROM #FactFinal  
	Where 
	Value <> 0 ''''
	Print (@Sql)
	EXEC(@Sql)

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END
-- Drop  table #time,#Fact,#Rate,#TempRate,#profit,#Where,#factTotal,#factSpread,#factAmount,#account,#year,#FactFinal






/****** Object:  StoredProcedure [dbo].[Canvas_Run_ETL]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Run_ETL'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Run_ETL') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Run_ETL]
	@ETL NVARCHAR(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

Declare	@ModelName NVARCHAR(255),@UserName NVARCHAR(255)
--Set @ModelName = ''''Financials''''
--Set @UserName = ''''herve-pc\herve''''

	DECLARE	@Proc_Id BIGINT
	Select @userName = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''

	SELECT @Proc_ID = MAX(Proc_Id) FROM Canvas_User_Run_Status
	IF @Proc_ID IS NULL  SET @Proc_ID = 0
	SET @Proc_ID = @Proc_Id + 1
	declare @userid int
	Select @Userid =  UserId from Canvas_Users Where label = @username
	INSERT INTO Canvas_User_Run_Status 
    ([User_RecordId],[User],[Proc_Id],[Proc_Name],[Begin_Date],[End_Date])
	VALUES (@Userid,@UserName,@Proc_Id,''''Refresh_'''' + LTRIM(@ETL),GETDATE(),'''''''') 
	
	IF @ETL = ''''Application'''' EXECUTE Canvas_ETL_LoadAll
	IF @ETL = ''''Data'''' EXECUTE Canvas_ETL_RefreshData


	UPDATE Canvas_User_Run_Status SET END_Date = GETDATE() WHERE Proc_Id = @Proc_Id

	
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END








/****** Object:  StoredProcedure [dbo].[Canvas_Sales_Calculation]    Script Date: 3/2/2017 11:34:03 AM ******/


SET @Step = 'Create Canvas_Sales_Calculation'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Sales_Calculation') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  

 PROCEDURE  [dbo].[Canvas_Sales_Calculation]
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

--Declare @BaseCurrency Nvarchar(255), @Type Nvarchar(20)
--SET @BaseCurrency = ''''NONE''''
--SET @Type = ''''Multiply''''

-- drop table  #temp_parametervalues 
-- Select * into  #temp_parametervalues  from  temp_parametervalues 

/****** Script for SelectTopNRows command from SSMS  ******/


DECLARE @ScenarioID BIGINT
,@TimeID BIGINT
,@BusinessprocessID BIGINT
,@CurrencyID BIGINT
,@BusinessprocessInputID BIGINT
,@BusinessprocessMemberid BIGINT
,@Time  Nvarchar(255)
,@User Nvarchar(255)
,@ModelName Nvarchar(50)
,@Sign Nvarchar(1)
,@NBReporting INT

DECLARE @DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max),@Sql2 Nvarchar(Max),@Lap INT,@Params Nvarchar(max),@Select Nvarchar(max)
declare @Found int,@Alldim Nvarchar(Max),@Otherdim Nvarchar(Max),@Sep Nvarchar(2)
Declare  @AccountDim Nvarchar(50),@ScenarioDim Nvarchar(50),@EntityDim Nvarchar(50),@BusinessProcessDim Nvarchar(50),@CurrencyDim Nvarchar(50)
,@TimeDim Nvarchar(50),@LineItemDim nvarchar(50),@VersionDim nvarchar(50),@Where Nvarchar(max),@Group Nvarchar(max),@Alldim2 Nvarchar(Max)

Select @user = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''
--Select @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''
Select @ModelName = ''''Sales''''

	set @Params = ''''@ScenarioIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @ScenarioIDOUT=[MemberId] from [#temp_parametervalues] where [parameterName]=''''''''ScenarioMbrs''''''''''''
	exec sp_executesql @sql, @Params, @ScenarioIDOUT=@Scenarioid OUTPUT

	set @Params = ''''@BusinessprocessIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''Input_Conv''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessIDOUT=@BusinessprocessID OUTPUT ' 


			SET @SQLStatement = @SQLStatement + '


--	Select @BusinessprocessID = Memberid From Ds_BusinessProcess Where Label = ''''Input
	set @Params = ''''@BusinessprocessInputIDOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @BusinessprocessInputIDOUT=[MemberId] from [DS_''''+@BusinessProcessDim+''''] where [Label]=''''''''Input''''''''''''
	exec sp_executesql @sql, @Params, @BusinessprocessInputIDOUT=@BusinessprocessInputID OUTPUT

	CREATE TABLE #Time (
	Time_memberid BIGINT
	,Time_Label Nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS
	,MyTime_memberid BIGINT
	,MyTime_Label Nvarchar(50) COLLATE SQL_Latin1_General_CP1_CI_AS)

	Insert into #time 
	select b.memberid,b.Label,0,(b.Timeyear * 100) + 12
	from #Temp_parametervalues a ,ds_time b
	Where a.ParameterName = ''''TimeMbrs''''
	And a.memberid = b.memberid
	
	Update #time set MyTime_memberid = b.memberid 
	from #Time a,DS_time b where a.MyTime_Label = b.label

	-- DT_FINLAND	10	8
	-- DT_USA		40	12 
	-- DT_BEIJING	25	9
	-- DT_HONG_KONG 20	11

	CREATE TABLE #Product (Memberid BIGINT,parentmemberid BIGINT,Label nvarchar(255),Grpmemberid BIGINT)
	INSERT INTO #product Select a.memberid, a.parentmemberid, b.label, c.memberid 
	From  HS_Product_product a, DS_product b, DS_Product c
	Where a.ParentMemberId = b.memberid
	and b.label = c.label

	CREATE TABLE #AccountEntity (
	Account_memberid BIGINT,Entity_memberid BIGINT,Geography_memberid BIGINT)
	
	Insert into #AccountEntity 
	Select a.memberid, b.Memberid, c.memberid
	From ds_account a , DS_Entity  b, DS_Geography c
	Where 
	a.label in (''''4000'''')
	AND b.memberid in (Select memberid from HC_entity where memberid <> parentid)
	And b.memberid > -1
	AND c.memberid in (Select memberid from HC_Geography where memberid <> parentid)
	And c.memberid > -1

	Create table #AccountEntityCost (Account_memberid BIGINT,Entity_memberid BIGINT,Intercompany_Memberid BIGINT)
	

	INSERT Into #AccountEntityCost
	Select a.memberid,e.memberid,c.memberid 
	FROM DS_Account a, DS_Entity e, DS_Intercompany c 
	Where a.label = ''''5050'''' 
	And e.label = c.label
	and e.Memberid in (Select Memberid from #Temp_Parametervalues where Parametername = ''''EntityMbrs'''')

	Create Table #Fact
	(
	 [Account_MemberId] BIGINT
	,[Account_Manager_MemberId] BIGINT
	,[BusinessProcess_MemberId] BIGINT
	,[BusinessUnit_MemberId] BIGINT
	,[CostCenter_MemberId] BIGINT
	,[Currency_MemberId] BIGINT
	,[Customer_MemberId] BIGINT
	,[Entity_MemberId] BIGINT
	,[Geography_MemberId] BIGINT
	,[Product_MemberId] BIGINT
	,[Scenario_MemberId] BIGINT
	,[Rounds_MemberId] BIGINT
	,[Time_MemberId] BIGINT
	,[TimeDataView_MemberId] BIGINT
	,[Source_MemberId] BIGINT
	,[Sales_Value] FLOAT
	)


	Create Table #FactSales
	(
	 [Account_MemberId] BIGINT
	,[Account_Manager_MemberId] BIGINT
	,[BusinessProcess_MemberId] BIGINT
	,[BusinessUnit_MemberId] BIGINT
	,[CostCenter_MemberId] BIGINT
	,[Currency_MemberId] BIGINT
	,[Customer_MemberId] BIGINT
	,[Entity_MemberId] BIGINT
	,[Geography_MemberId] BIGINT
	,[Product_MemberId] BIGINT
	,[Scenario_MemberId] BIGINT
	,[Rounds_MemberId] BIGINT
	,[Time_MemberId] BIGINT
	,[TimeDataView_MemberId] BIGINT
	,[Source_MemberId] BIGINT
	,[Unit_Value] Float
	,[Price_Value] Float
	,[STDPrice_Value] Float
	,[STDCost_Value] Float
	,[STDCostUnit_Value] Float
	,[Sales_Value] Float 
	,[Cost_Value] Float
	,MyTop Bit 
	)

	Create Table #FactQTEPrice
	(
	 [Account_MemberId] BIGINT
	,[Account_Manager_MemberId] BIGINT
	,[BusinessProcess_MemberId] BIGINT
	,[BusinessUnit_MemberId] BIGINT
	,[CostCenter_MemberId] BIGINT
	,[Currency_MemberId] BIGINT
	,[Customer_MemberId] BIGINT
	,[Entity_MemberId] BIGINT
	,[Geography_MemberId] BIGINT
	,[Product_MemberId] BIGINT
	,[Scenario_MemberId] BIGINT
	,[Rounds_MemberId] BIGINT
	,[Time_MemberId] BIGINT
	,[TimeDataView_MemberId] BIGINT
	,[Source_MemberId] BIGINT
	,[Unit_Value] Float
	,[Price_Value] Float
	,[STDPrice_Value] Float
	)

	Create Table #FactPrice(
       [Scenario_MemberId] BIGINT
       ,[Rounds_MemberId] BIGINT
      ,[Time_MemberId] BIGINT
      ,[Currency_MemberId] BIGINT
      ,[Customer_MemberId] BIGINT
      ,[Product_MemberId] BIGINT
      ,[Price_Value] Float
	  ,[STDPrice_Value] Float)

	Create Table #FactSTDPrice(
       [Time_MemberId] BIGINT
      ,[Currency_MemberId] BIGINT
      ,[Product_MemberId] BIGINT
	  ,[STDPrice_Value] Float)

	Create Table #FactCost(
       [Scenario_MemberId] BIGINT
      ,[Rounds_MemberId] BIGINT
      ,[Time_MemberId] BIGINT
      ,[Currency_MemberId] BIGINT
      ,[Product_MemberId] BIGINT
      ,[STDCost_Value] Float
      ,[STDCostUnit_Value] Float)

	
	DECLARE @Acc_QTE nvarchar(20),@Acc_Price nvarchar(20),@Acc_Cost nvarchar(20),@Acc_STDPrice nvarchar(20)

	Select @Acc_QTE = Memberid from ds_account where label = ''''SalesUnits''''
	Select @Acc_Price = Memberid from ds_account where label = ''''UnitPrice''''
	Select @Acc_Cost = Memberid from ds_account where label = ''''Std_Cost_Group''''
	Select @Acc_STDPrice = Memberid from ds_account where label = ''''StandardPrice''''

	Insert into #FactPrice
	Select 
	 a.[Scenario_MemberId]
	,a.[Rounds_MemberId]
	,a.[Time_MemberId]
	,a.[Currency_MemberId]
	,a.[Customer_MemberId]
	,a.[Product_MemberId]
	,Sum(a.Sales_value) as Price_Value
	,0
	From [FACT_Sales_Default_Partition] a, #time b
	Where 
	a.Scenario_memberid  in (select memberid from #Temp_parametervalues where parametername = ''''ScenarioMbrs'''')
	And a.Rounds_memberid in (select memberid from #Temp_parametervalues where parametername = ''''RoundsMbrs'''')
	and a.Time_MemberId = b.Time_MemberId
	and a.account_memberid in (Select Memberid from ds_account where label = ''''UnitPrice'''')
	And a.sales_value <> 0
	Group By a.[Currency_MemberId]
	,a.[Customer_MemberId]
	,a.[Product_MemberId]
	,a.[Scenario_MemberId]
	,a.[Rounds_MemberId]
	,a.[Time_MemberId]
	

	Insert into #FactSTDPrice
	Select 
	 a.[Time_MemberId]
	,a.[Currency_MemberId]
	,a.[Product_MemberId]
	,Sum(a.Sales_value) as STDPrice_Value
	From [FACT_Sales_Default_Partition] a, #time b
	Where 
	a.Scenario_memberid = -1 
	And a.Rounds_memberid = -1
	and a.Time_MemberId = b.Time_MemberId
	and a.account_memberid in (Select Memberid from ds_account where label = ''''StandardPrice'''')
	And a.sales_value <> 0
	Group By 
	 a.[Currency_MemberId]
	,a.[Product_MemberId]
	,a.[Time_MemberId]

	Update #FactPrice SET STDPrice_Value = b.STDPrice_Value
	From #FactPrice a, #FactSTDPrice b
	Where 
	a.Time_MemberId = b.Time_MemberId
	And a.Product_MemberId = b.Product_MemberId
	And a.Currency_MemberId = b.Currency_MemberId

	
	Insert into #FactCost
	Select 
	 [Scenario_MemberId]
	,[Rounds_MemberId]
	,[Time_MemberId]
	,[Currency_MemberId]
	,[Product_MemberId]
	,sum(STDCost_Value) as STDCost_Value
	,sum(STDCostunit_Value) as STDUnitCost_Value
	FROM(
	Select 
	 a.[Scenario_MemberId]
	 ,a.[Rounds_MemberId]
	,b.[Time_MemberId]
	,a.[Currency_MemberId]
	,a.[Product_MemberId]
	,a.sales_value as STDCost_Value
	,0 as STDCostunit_Value
	From [FACT_Sales_Default_Partition] a, #time b
	Where 
	a.Scenario_memberid in (select memberid from #Temp_parametervalues where parametername = ''''scenarioMbrs'''')
	And a.Rounds_memberid in (select memberid from #Temp_parametervalues where parametername = ''''RoundsMbrs'''')
	and a.Time_MemberId = b.MyTime_MemberId
	And a.sales_value <> 0
	and a.account_memberid IN ( Select Memberid from ds_account where label = ''''Std_Cost_Group'''')
	UNION ALL
	Select 
	 a.[Scenario_MemberId]
	 ,a.[Rounds_MemberId]
	,b.[Time_MemberId]
	,a.[Currency_MemberId]
	,a.[Product_MemberId]
	,0 as STDCost_Value
	,a.sales_value as STDCostunit_Value
	From [FACT_Sales_Default_Partition] a, #time b
	Where 
	a.Scenario_memberid in (select memberid from #Temp_parametervalues where parametername = ''''scenarioMbrs'''')
	And a.Rounds_memberid in (select memberid from #Temp_parametervalues where parametername = ''''RoundsMbrs'''')
	and a.Time_MemberId = b.MyTime_MemberId
	And a.sales_value <> 0
	and a.account_memberid IN ( Select Memberid from ds_account where label = ''''UnitCost'''')
	) As TMP
	Group By
       [Scenario_MemberId]
      ,[Rounds_MemberId]
	  ,[Time_MemberId] 
 	  ,[Currency_MemberId]
      ,[Product_MemberId] 

	  -- FAIRE JOINTURE ABVEC #ACCOUNTENTITy ET AVEC GEOGRAPHY FROM DS8CUSTOMER
	  
	INSERT into #Fact
	Select 
	   a.[Account_MemberId]
      ,a.[Account_Manager_MemberId]
      ,a.[BusinessProcess_MemberId]
      ,a.[BusinessUnit_MemberId]
      ,a.[CostCenter_MemberId]
      ,a.[Currency_MemberId]
      ,a.[Customer_MemberId]
      ,a.[Entity_MemberId]
      ,c.[Geography_MemberId]
      ,a.[Product_MemberId]
      ,a.[Scenario_MemberId]
      ,a.[Rounds_MemberId]
      ,a.[Time_MemberId]
      ,a.[TimeDataView_MemberId]
      ,a.[Source_MemberId]
      ,a.[Sales_Value]
	FROm FACT_Sales_default_partition a, #time b, DS_Customer c
	WHere 
	a.Scenario_memberid  in (select memberid from #Temp_parametervalues where parametername = ''''ScenarioMbrs'''')
	And a.Rounds_memberid in (select memberid from #Temp_parametervalues where parametername = ''''RoundsMbrs'''')
	and a.Source_MemberId = -1
	and a.Time_MemberId = b.Time_MemberId
	and a.account_memberid in (Select  Memberid from ds_account where label = ''''SalesUnits'''')
	and a.entity_memberid in (Select Memberid from #temp_parametervalues Where parametername = ''''EntityMbrs'''')
	and a.Customer_MemberId = c.memberid

	INSERT INTO #FactQTEPrice
	SELECT
	   a.[Account_MemberId] 
      ,a.[Account_Manager_MemberId]
      ,a.[BusinessProcess_MemberId]
      ,a.[BusinessUnit_MemberId]
      ,a.[CostCenter_MemberId]
      ,b.[Currency_MemberId]
      ,a.[Customer_MemberId]
      ,a.[Entity_MemberId]
      ,a.[Geography_MemberId]
      ,a.[Product_MemberId]
      ,a.[Scenario_MemberId]
      ,a.[Rounds_MemberId]
      ,a.[Time_MemberId]
      ,a.[TimeDataView_MemberId]
      ,a.[Source_MemberId]
      ,[Unit_Value] = a.[Sales_Value]
	  ,[Price_Value] = b.Price_Value
	  ,[STDPrice_Value] = b.STDPrice_Value
	From #fact a, #Factprice b
	Where 
	 a.[Scenario_MemberId] = b.[Scenario_memberid]
	AND a.[Time_MemberId]=b.[Time_MemberId] 
	AND a.[Customer_MemberId]=b.[Customer_MemberId]
	AND a.[Product_MemberId]=b.[Product_MemberId]
	AND a.[Rounds_MemberId]=b.[Rounds_MemberId]

	INSERT INTO #factSales
	Select 
	   [Account_MemberId] = c.[Account_MemberId]
      ,[Account_Manager_MemberId] = a.[Account_Manager_MemberId]
      ,[BusinessProcess_MemberId] = a.[BusinessProcess_MemberId]
      ,[BusinessUnit_MemberId] = a.[BusinessUnit_MemberId]
      ,[CostCenter_MemberId] = a.[CostCenter_MemberId]
      ,[Currency_MemberId] = a.[Currency_MemberId]
      ,[Customer_MemberId] = a.[Customer_MemberId]
      ,[Entity_MemberId] = a.[Entity_MemberId]
      ,[Geography_MemberId] = a.[Geography_MemberId]
      ,[Product_MemberId] = a.[Product_MemberId]
      ,[Scenario_MemberId] = a.[Scenario_MemberId]
      ,[Rounds_MemberId] = a.[Rounds_MemberId]
      ,[Time_MemberId] = a.[Time_MemberId]
      ,[Timedataview_MemberId] = a.[Timedataview_MemberId]
      ,[Source_MemberId] = a.[Source_MemberId]
      ,[Unit_Value] = a.[Unit_Value]
      ,[Price_Value] = a.[Price_Value]
      ,[STDPrice_Value] = a.[STDPrice_Value]
      ,[STDCost_Value] = b.[STDCost_Value]
      ,[STDCostUnit_Value] = b.[STDCostUnit_Value]
      ,[Cost_Value] = 0
      ,[Sales_Value] = 0 
      ,[MyTop] = 0 
	From #FactQTEPrice a
	LEFT JOIN #FactCost b ON 
		 a.[Scenario_MemberId] = b.[Scenario_memberid]
		AND a.[Rounds_MemberId] = b.[Rounds_memberid]
		AND a.[Time_MemberId] = b.[Time_MemberId] 
		AND a.[Currency_MemberId] = b.[Currency_MemberId] 
		AND a.[Product_MemberId]=b.[Product_MemberId]
	INNER JOIN #AccountEntity c ON 
	a.Geography_MemberId = c.Geography_memberid
	AND a.Entity_MemberId = c.Entity_MemberId


	Update #FactSales Set STDCost_Value = 0 Where STDCost_Value is NULL
	Update #FactSales Set Sales_Value = Unit_Value * Price_Value
	Update #FactSales Set Cost_Value  = Unit_Value * STDCostUnit_Value 

	
	DELETE FROM [FACT_Sales_Default_Partition]
	Where [Scenario_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''ScenarioMbrs'''')
	And   [Time_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''TimeMbrs'''')
	And   [Entity_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''EntityMbrs'''')
	And   [Rounds_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''RoundsMbrs'''')
	And   [Businessprocess_Memberid] in (select memberid from ds_businessprocess where label = ''''Input'''')
	And   [Account_memberid] in (Select Account_memberid from #AccountEntity)

	DELETE FROM [FACT_Sales_Default_Partition]
	Where [Scenario_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''ScenarioMbrs'''')
	And   [Time_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''TimeMbrs'''')
	And   [Entity_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''EntityMbrs'''')
	And   [Rounds_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''RoundsMbrs'''')
	And   [Businessprocess_Memberid] in (select memberid from ds_businessprocess where label = ''''Input'''')
	And   [Account_memberid] in (Select memberid from DS_account Where label = ''''SalesDiscount'''')

	DELETE FROM [FACT_Sales_Default_Partition]
	Where [Scenario_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''ScenarioMbrs'''')
	And   [Time_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''TimeMbrs'''')
	And   [Entity_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''EntityMbrs'''')
	And   [Businessprocess_Memberid] in (select memberid from ds_businessprocess where label = ''''Input'''')
	And   [Rounds_Memberid] In (Select Memberid from #Temp_Parametervalues Where ParameterName = ''''RoundsMbrs'''')
	And   [Account_memberid] in (Select Account_memberid from #AccountEntityCost)


	-- INSERT SALES IN SALES CUBE
	INSERT INTO [FACT_Sales_Default_Partition]
	(
	 [Account_MemberId]
	,[Account_Manager_MemberId]
	,[BusinessProcess_MemberId]
	,[BusinessUnit_MemberId]
	,[CostCenter_MemberId]
	,[Currency_MemberId]
	,[Customer_MemberId]
	,[Entity_MemberId]
	,[Geography_MemberId]
	,[Product_MemberId]
	,[Scenario_MemberId]
	,[Rounds_MemberId]
	,[Time_MemberId]
	,[TimeDataView_MemberId]
	,[Source_MemberId]
--	,[Version_MemberId]
	,[ChangeDatetime]
	,[Userid]
	,[Sales_Value]
	)
	SELECT 
	 [Account_MemberId]
	,[Account_Manager_MemberId]
	,[BusinessProcess_MemberId]
	,[BusinessUnit_MemberId]
	,[CostCenter_MemberId]
	,[Currency_MemberId]
	,[Customer_MemberId]
	,[Entity_MemberId]
	,[Geography_MemberId]
	,[Product_MemberId]
	,[Scenario_MemberId]
	,Rounds_memberid
	,[Time_MemberId]
	,[TimeDataView_MemberId]
	,[Source_MemberId]
	--,-1 [Version_MemberId] 
	,GETDATE() as [ChangeDatetime]
	,@user as [Userid]
	,[Sales_Value] 
	FROM #FactSales
	Where Sales_Value <> 0 
	And [MyTop] = 0 

--===================================================> Discounts
	INSERT INTO [FACT_Sales_Default_Partition]
	(
	 [Account_MemberId]
	,[Account_Manager_MemberId]
	,[BusinessProcess_MemberId]
	,[BusinessUnit_MemberId]
	,[CostCenter_MemberId]
	,[Currency_MemberId]
	,[Customer_MemberId]
	,[Entity_MemberId]
	,[Geography_MemberId]
	,[Product_MemberId]
	,[Scenario_MemberId]
	,[Rounds_MemberId]
	,[Time_MemberId]
	,[TimeDataView_MemberId]
	,[Source_MemberId]
--	,[Version_MemberId]
	,[ChangeDatetime]
	,[Userid]
	,[Sales_Value]
	)
	SELECT 
	 b.Memberid as [Account_MemberId]
	,a.[Account_Manager_MemberId]
	,a.[BusinessProcess_MemberId]
	,a.[BusinessUnit_MemberId]
	,a.[CostCenter_MemberId]
	,a.[Currency_MemberId]
	,a.[Customer_MemberId]
	,a.[Entity_MemberId]
	,a.[Geography_MemberId]
	,a.[Product_MemberId]
	,a.[Scenario_MemberId]
	,a.Rounds_memberid
	,a.[Time_MemberId]
	,a.[TimeDataView_MemberId]
	,a.[Source_MemberId]
	--,-1 [Version_MemberId] 
	,GETDATE() as [ChangeDatetime]
	,@user as [Userid]
	,[Unit_Value] * (STDPrice_Value - Price_Value) * -1
	FROM #FactSales a, DS_account b
	Where Sales_Value <> 0 
	And b.label = ''''SalesDiscount''''
	And [MyTop] = 0 



-- INSERT COST IN SALES CUBE

	INSERT INTO [FACT_Sales_Default_Partition]
	(
	 [Account_MemberId]
	,[Account_Manager_MemberId]
	,[BusinessProcess_MemberId]
	,[BusinessUnit_MemberId]
	,[CostCenter_MemberId]
	,[Currency_MemberId]
	,[Customer_MemberId]
	,[Entity_MemberId]
	,[Geography_MemberId]
	,[Product_MemberId]
	,[Scenario_MemberId]
	,[rounds_MemberId]
	,[Time_MemberId]
	,[TimeDataView_MemberId]
	,[Source_MemberId]
	,[ChangeDatetime]
	,[Userid]
	,[Sales_Value]
	)
	SELECT 
	 b.[Account_memberid] as [Account_MemberId]
	,a.[Account_Manager_MemberId]
	,a.[BusinessProcess_MemberId]
	,a.[BusinessUnit_MemberId]
	,a.[CostCenter_MemberId]
	,a.[Currency_MemberId]
	,a.[Customer_MemberId]
	,a.[Entity_MemberId]
	,a.[Geography_MemberId]
	,a.[Product_MemberId]
	,a.[Scenario_MemberId]
	,a.Rounds_memberid
	,a.[Time_MemberId]
	,a.[TimeDataView_MemberId]
	,a.[Source_MemberId] 
	,GETDATE() as [ChangeDatetime]
	,@user as [Userid]
	,a.[Cost_Value]
	FROM #FactSales a, #AccountEntityCost b
	Where a.Sales_Value <> 0 
	and a.Entity_memberid = b.entity_memberid
	And a.[MyTop] = 0 



END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END
-- Drop  table #time,#Fact,#Rate,#TempRate,#currency,#Accountentity,#FactPrice,#FactSTDPrice,#FactCost,#FactSales,#FactQTEPrice,#product,#AccountEntityCost








/****** Object:  StoredProcedure [dbo].[Canvas_TAB_LIST]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_TAB_LIST'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TAB_LIST') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TAB_LIST]
	@ModelName as nvarchar(255)
	,@Table as nvarchar(255)
	,@Rule as nvarchar(255) =''''''''
	,@RuleNumber as nvarchar(255) =''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	DECLARE @Sql Nvarchar(MAX),@Select Nvarchar(MAX),@Where Nvarchar(1200),@FROM Nvarchar(200)

	set @Where = ''''''''
	Set @Sql = ''''
		SELECT 
		[RecordId]=a.[RecordId]
		,[Begin] = ''''''''$'''''''' ''''
	SET @From = '''' FROM ''''+@Table+ '''' a ''''

--============================================> Canvas_Consolidation_Formula
	IF @Table = ''''Canvas_Consolidation_Formula'''' 
	BEGIN
      SET @Select = ''''
	  ,[SortOrder]=a.[SortOrder]
      ,[Label]=a.[Label] ''''
	END
--============================================> Canvas_Consolidation_Rule
	IF @Table = ''''Canvas_Consolidation_Rule'''' 
	BEGIN
      SET @Select = ''''
	  ,[SortOrder]=a.[SortOrder]
      ,[Label]=a.[Label]
      ,[Consolidation_Rule]=a.[Consolidation_Rule]
      ,[Rule_Number]=a.[Rule_Number]
      ,[Scenario]=a.[Scenario]
      ,[Source_BusinessProcess]=a.[Source_BusinessProcess]
      ,[Destination_BusinessProcess]=a.[Destination_BusinessProcess]
      ,[Journal_Number]=a.[Journal_Number]
      ,[Execution_Level]=a.[Execution_Level]
      ,[Group]=a.[Group]
      ,[Available_Period]=a.[Available_Period]
      ,[From]=a.[From]
      ,[To]=a.[To]
      ,[Local_Currency]=a.[Local_Currency]
      ,[Special_Event]=a.[Special_Event]
      ,[Consolidation_Class]=a.[Consolidation_Class]''''
	END ' 


			SET @SQLStatement = @SQLStatement + '

--============================================> Canvas_Consolidation_Rule_Detail
	IF @Table = ''''Canvas_Consolidation_Rule_Detail'''' 
	BEGIN
		Set @Sql = ''''
			SELECT 
			[RecordId]=a.[RecordId]
			,[Consolidation_Rule]=a.[Consolidation_Rule]
			,[Rule_Number]=a.[Rule_Number]
			,[Begin] = ''''''''$''''''''''''	

		SET @Select = ''''
		  ,[SortOrder]=a.[SortOrder]
		  ,[Source_Flow]=a.[Source_Flow]
		  ,[Source_Time]=a.[Source_Time]
		  ,[Source_Filter]=a.[Source_Filter]
		  ,[Sign]=a.[Sign]
		  ,[Destination_Account]=a.[Destination_Account]
		  ,[Destination_Flow]=a.[Destination_Flow]
		  ,[Destination_Intercompany]=a.[Destination_Intercompany]
		  ,[Destination_Other]=a.[Destination_Other]
		  ,[Swap_Equity_Account]=a.[Swap_Equity_Account]
		  ,[Repartition]=a.[Repartition]
		  ,[Repartition_Class]=a.[Repartition_Class]
		  ,[Invert]=a.[Invert] ''''

		SET @WHERE = '''' WHERE a.[Consolidation_Rule] = ''''''''''''+@Rule+'''''''''''' 
					   AND a.[Rule_Number] = ''''+@RuleNumber
	END
--============================================> Canvas_Method_Selection
	IF @Table = ''''Canvas_Method_Selection'''' 
	BEGIN
		SET @Select = ''''
		,[SortOrder]=a.[SortOrder]
		,[Label]=a.[Label] ''''
	END
--============================================> Canvas_Method_Selection_Detail
	IF @Table = ''''Canvas_Method_Selection_Detail'''' 
	BEGIN
		SET @Select = ''''
		,[SortOrder]=a.[SortOrder]
		,[Method]=a.[Method] ''''

		SET @WHERE = '''' WHERE a.[Method_Selection] = ''''''''''''+@Rule+''''''''''''''''
	END ' 


			SET @SQLStatement = @SQLStatement + '

--============================================> Canvas_Conversion_Formula
	IF @Table = ''''Canvas_Conversion_Formula'''' 
	BEGIN

		SET @Select = ''''
			,[S_SortOrder]=a.[SortOrder]
			,[S_Label]=a.[Label]
			,[S_Source_Year]=a.[Source_Year]
			,[S_Source_Period]=a.[Source_Period]  ''''
	END
--============================================> Canvas_Conversion_Rule
	IF @Table = ''''Canvas_Conversion_Rule'''' 
	BEGIN
		SET @Select = ''''
	    ,[SortOrder]=a.[SortOrder]
		,[Label]=a.[Label] ''''
	END
--============================================> Canvas_Conversion_Rule_Detail
	IF @Table = ''''Canvas_Conversion_Rule_Detail'''' 
	BEGIN
		SET @Select = ''''
		,[SortOrder]=a.[SortOrder]
		,[Entity]=a.[Entity]
		,[Flow]=a.[Flow]
		,[Apply_Periodic]=a.[Apply_Periodic]
		,[Destination_Flow]=a.[Destination_Flow]
		,[Destination_Account]=a.[Destination_Account]
		,[Formula]=a.[Formula]
		,[Sum_To_Flow]=a.[Sum_To_Flow]
		,[From]=a.[From]
		,[To]=a.[To] ''''
		  
		 SET @Where = '''' WHERE Conversion_Rule = ''''''''''''+@Rule+''''''''''''''''
	END
--============================================> Canvas_Copyopening_Rule
	IF @Table = ''''Canvas_Copyopening_Rule'''' 
	BEGIN
		SET @Select = ''''
		,[SortOrder]=[SortOrder]
		,[Label]=[Label]
		,[CopyOpening_Number]=[CopyOpening_Number]
		,[Entity]=[Entity]
		,[Scenario]=[Scenario]
		,[BusinessProcess]=[BusinessProcess]
		,[Flow]=[Flow]
		,[Source_Year]=[Source_Year]
		,[Source_Period]=[Source_Period]
		,[Opening_Scenario]=[Opening_Scenario]
		,[Opening_BusinessProcess]=[Opening_BusinessProcess]
		,[Opening_Account]=[Opening_Account]
		,[Opening_Flow]=[Opening_Flow]
		,[Available_Period]=[Available_Period]
		,[Destination_Other]=[Destination_Other]
		,[Copy_Converted_Amount]=[Copy_Converted_Amount]
		,[Invert_Amount]=[Invert_Amount]
		,[Ytd]=[Ytd] ''''
	END ' 


			SET @SQLStatement = @SQLStatement + '

--============================================> Canvas_Repartition
	IF @Table = ''''Canvas_Repartition'''' 
	BEGIN
		SET @Select = ''''
		,[SortOrder]=a.[SortOrder]
		,[Label]=a.[Label] ''''
	END
--============================================> Canvas_Repartition_Class
	IF @Table = ''''Canvas_Repartition_Class'''' 
	BEGIN
		SET @Select = ''''
		,[SortOrder]=a.[SortOrder]
		,[Label]=a.[Label] ''''
	END
--============================================> Canvas_Repartition_Detail
	IF @Table = ''''Canvas_Repartition_Detail'''' 
	BEGIN
		SET @Select = ''''
		,[SortOrder]=a.[SortOrder]
		,[Method]=a.[Method]
		,[New_Entity]=a.[New_Entity]
		,[Interco_Method]=a.[Interco_Method]
		,[Investment_Method]=a.[Investment_Method]
		,[Repartition_Class]=a.[Repartition_Class]
		,[Formula]=a.[Formula]
		,[Opening_Method]=a.[Opening_Method]
		,[Previous_Method]=a.[Previous_Method]''''

		SET @Where = '''' WHERE [Repartition] = ''''''''''''+@Rule+''''''''''''''''
	END
--============================================> Canvas_Validation
	IF @Table = ''''Canvas_Validation'''' 
	BEGIN
		SET @Select = ''''
		,[Sortorder]=a.[Sortorder]
		,[Label]=a.[Label]
		,[Entity]=a.[Entity]
		,[Validation_Type]=a.[Validation_Type]
		,[Destination_Other]=a.[Destination_Other]
		,[Available_Period]=a.[Available_Period]
		,[Tolerance]=a.[Tolerance]
		,[Dimension_BreakDown]=a.[Dimension_BreakDown]
		,[Lock]=a.[Lock]
		,[From]=a.[From]
		,[To]=a.[To]
		,[Destination_Account]=a.[Destination_Account]
		,[Compare_Account]=a.[Compare_Account]
		,[Compare_Amount]=a.[Compare_Amount] ''''
	END ' 


			SET @SQLStatement = @SQLStatement + '

--============================================> Canvas_Validation_Detail
	IF @Table = ''''Canvas_Validation_Detail'''' 
	BEGIN
		SET @Select = ''''
		,[SortOrder]=a.[SortOrder]
		,[Sign]=a.[Sign]
		,[Account]=a.[Account]
		,[Description]=b.[Description]
		,[Flow]=a.[Flow]
		,[Dimension_Filter]=a.[Dimension_Filter]
		,[Periodic]=a.[Periodic] ''''
 
		SET @From = @From + '''', DS_Account b''''

		SET @WHERE = '''' WHERE [Validation] = ''''''''''''+@Rule+''''''''''''
						And a.Account = b.Label ''''

	END
--============================================> Canvas_Intercompany_Matching
	IF @Table = ''''Canvas_Intercompany_Matching'''' 
	BEGIN
		SET @Select = ''''
		,[Sortorder]=a.[Sortorder]
		,[Label]=a.[Label]
		,[Description]=a.[Description]
		,[Entity]=a.[Entity]
		,[Buyer_Rule]=a.[Buyer_Rule]
		,[Available_Period]=a.[Available_Period]
		,[Tolerance]=a.[Tolerance]
		,[Source_Businessprocess]=a.[Source_Businessprocess]
		,[Dimension_Breakdown]=a.[Dimension_Breakdown]
		,[Destination_BusinessProcess]=a.[Destination_BusinessProcess]
		,[Destination_Account]=a.[Destination_Account]
		,[Destination_Other]=a.[Destination_Other]
		,[Destination_Account_Receivables_Incomes]=a.[Destination_Account_Receivables_Incomes]
		,[Destination_Account_Payables_Expenses]=a.[Destination_Account_Payables_Expenses]''''
 
	END
--============================================> Canvas_Intercompany_Matching_Detail
	IF @Table = ''''Canvas_Intercompany_Matching_Detail'''' 
	BEGIN
		SET @Select = ''''
			 ,[SortOrder]=a.[SortOrder]
			,[Sign]=a.[Sign]
			,[Account]=a.[Account]
			,[Description]=b.[Description]
			,[Flow]=a.[Flow]
			,[Source_Filter]=a.[Source_Filter]
			,[Matching_Type]= a.[Matching_Type] ''''

		SET @From = @From + '''', DS_Account b''''

		SET @WHERE = '''' WHERE [Intercompany_Matching_Rule] = ''''''''''''+@Rule+''''''''''''
		And a.Account = b.Label ''''

 	END ' 


			SET @SQLStatement = @SQLStatement + '

--============================================> Canvas_Intercompany_Matching_Detail
	IF @Table = ''''Canvas_Intercompany_Booking'''' 
	BEGIN
		SET @Select = ''''
		,[SortOrder]=a.[SortOrder]
		,[DebitCredit]=a.[DebitCredit]
		,[Account]=a.[Account]
		,[Description]=b.[Description]
		,[Flow]=a.[Flow]
		,[Intercompany]=a.[Intercompany]
		,[Destination_Other]=a.[Destination_Other] ''''

		SET @From = @From + '''', DS_Account b''''

		SET @WHERE = '''' WHERE [Intercompany_Matching_Rule] = ''''''''''''+@Rule+'''''''''''' 
		And a.Account = b.Label ''''
 	END
--============================================> Canvas_Menus
	IF @Table = ''''Canvas_Menus'''' 
	BEGIN
		SET @Select = ''''
		,[SortOrder]=a.[SortOrder]
		,[Label]=a.[Label] 
		,[Model]=a.[Model] ''''
	END
--============================================> Canvas_Menu_Detail
	IF @Table = ''''Canvas_Menu_Detail'''' 
	BEGIN
		SET @Select = ''''
		  ,[SortOrder]=a.[SortOrder]
		  ,[Group_Number]=a.[Group_Number]
		  ,[Group_RowNumber]=a.[Group_RowNumber]
		  ,[SubMenu_Number]=a.[SubMenu_Number]
		  ,[Menu_Item]=a.[Menu_Item]
		  ,[Menu_Type]=a.[Menu_Type]
		  ,[Item_Name]=a.[Item_Name]
		  ,[Group_Image]=a.[Group_Image]
		  ,[Run_Delete_Name]=a.[Run_Delete_Name]
		  ,[Run_Report_Name]=a.[Run_Report_Name]
		  ,[Run_Parameter]=a.[Run_Parameter]
		  ,[LocalCurrency]=a.[LocalCurrency]''''

		SET @WHERE = '''' WHERE [Menu] = ''''''''''''+@Rule+''''''''''''''''

 	END
--============================================> Canvas_Copy_Model_Dimension
	IF @Table = ''''Canvas_Copy_Model_Dimension'''' 
	BEGIN
		SET @Select = ''''
		,[SortOrder]=a.[SortOrder]
		,[Label]=a.[Label] 
		,[From_Model]=a.[From_Model] 
		,[To_Model]=a.[To_Model] 
		,[From_Dimension]=a.[From_Dimension] 
		,[To_Dimension]=a.[To_Dimension] ''''
	END
--============================================> Canvas_Copy_Model_Dimension_Detail
	IF @Table = ''''Canvas_Copy_Model_Dimension_Detail'''' 
	BEGIN
		SET @Select = ''''
		  ,[SortOrder]=a.[SortOrder]
		  ,[From_Label]=a.[From_Label]
		  ,[To_Label]=a.[To_Label]
		  ,[InvertSign]=a.[InvertSign]
		  ,[YTD]=a.[YTD]''''

		SET @WHERE = '''' WHERE [Copy_Model_Dimension] = ''''''''''''+@Rule+''''''''''''''''
 	END

--====================================================================
	SET @Sql = @Sql 
	+REPLACE(@Select,'''',['''','''',[S_'''')
	+@Select
	+@From
	+@Where
	
	IF @Table = ''''Canvas_Menu_Detail'''' 
	BEGIN
		SET @Sql = @sql + '''' 
		ORDER BY [Group_Number],[Group_RowNumber],[SubMenu_Number]''''
	END
	ELSE
	BEGIN
		Set @sql = @sql + ''''
		ORDER BY a.[Sortorder]''''
	END
	--Print(@Sql)
	exec(@Sql)
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END



/****** Object:  StoredProcedure [dbo].[Canvas_TAB_Update]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowItemsUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TAB_Update') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TAB_Update]
	 @ModelName as nvarchar(255)
	,@SaveDelFin  as nvarchar(255)
	,@RecordId  as nvarchar(255)
	,@Dimtable as Nvarchar(50)
	,@Table as Nvarchar(50)
	,@Column  as nvarchar(255)
	,@Label  as nvarchar(255)
	,@CanvasTable Nvarchar(255)
	,@Rule Nvarchar(255) = ''''''''
	,@RuleNumber Nvarchar(255) = ''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

DECLARE @sql nvarchar(max), @AllCol nvarchar(max), @Count INT,@TimeDim nvarchar(100),@SystemDefined Nvarchar(15),@SystemDefinedvalue Nvarchar(3)
Set @systemdefined = '''', SystemDefined''''
Set @systemdefinedvalue = '''', 0''''

IF not exists (Select b.name from sysobjects a, syscolumns b where a.id = b.id and a.name = @CanvasTable and b.name = ''''SystemDefined'''') 
	Set @systemdefined = ''''''''
	Set @systemdefinedvalue = ''''''''

IF @Table = ''''TRUEFALSE'''' SET @table = ''''$''''

select @TimeDim = A.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
where A.[Model] = @Modelname And b.[Type] = ''''Time''''

If @table = ''''Year'''' 
BEGIN
	SET @table = ''''$''''
	SET @Dimtable = @TimeDim
END

If @table = ''''Period'''' 
BEGIN
	SET @table = ''''$''''
	SET @Dimtable = ''''TimeFiscalPeriod''''
END
If @table = ''''Method'''' 
BEGIN
	SET @table = ''''$''''
	SET @Dimtable = ''''Method''''
END

DECLARE @Fin nvarchar(100)
	IF @Canvastable = ''''Canvas_Consolidation_Formula'''' Set @Fin = ''''[Label]''''
	IF @Canvastable = ''''Canvas_Consolidation_Rule''''  Set @Fin = ''''[Consolidation_Class]''''
	IF @Canvastable = ''''Canvas_Consolidation_Rule_Detail''''  Set @Fin = ''''[Invert]''''
	IF @Canvastable = ''''Canvas_Method_Selection''''  Set @Fin = ''''[Label]''''
	IF @Canvastable = ''''Canvas_Method_Selection_Detail''''  Set @Fin = ''''[Method]''''
	IF @Canvastable = ''''Canvas_Conversion_Formula''''  Set @Fin = ''''[S_Source_Period]''''
	IF @Canvastable = ''''Canvas_Conversion_Rule''''  Set @Fin = ''''[Label]''''
	IF @Canvastable = ''''Canvas_Conversion_Rule_Detail''''  Set @Fin = ''''[To]''''
	IF @Canvastable = ''''Canvas_Copyopening_Rule''''  Set @Fin = ''''[Ytd]''''
	IF @Canvastable = ''''Canvas_Repartition''''  Set @Fin = ''''[Label]''''
	IF @Canvastable = ''''Canvas_Repartition_Class''''  Set @Fin = ''''[Label]''''
	IF @Canvastable = ''''Canvas_Repartition_Detail''''  Set @Fin = ''''[Previous_Method]''''
	IF @Canvastable = ''''Canvas_Validation''''  Set @Fin = ''''[Compare_Amount]''''
	IF @Canvastable = ''''Canvas_Validation_Detail''''  Set @Fin = ''''[Periodic]''''
	IF @Canvastable = ''''Canvas_Intercompany_Matching''''  Set @Fin = ''''[Destination_Account_Payables_Expenses]''''
	IF @Canvastable = ''''Canvas_Intercompany_Matching_Detail''''  Set @Fin = ''''[Matching_Type]''''
	IF @Canvastable = ''''Canvas_Intercompany_Booking''''  Set @Fin = ''''[Destination_Other]''''
	IF @Canvastable = ''''Canvas_Menus''''  Set @Fin = ''''[Model]''''
	IF @Canvastable = ''''Canvas_Menu_Detail''''  Set @Fin = ''''[LocalCurrency]''''
	IF @Canvastable = ''''Canvas_Copy_Model_Dimension''''  Set @Fin = ''''[To_Dimension]''''
	IF @Canvastable = ''''Canvas_Copy_Model_Dimension_Detail''''  Set @Fin = ''''[YTD]'''' ' 

			SET @SQLStatement = @SQLStatement + '


	--SET @Column = REPLACE(REPLACE(@Column,''''['''',''''''''),'''']'''','''''''')
	SET @CanvasTable = REPLACE(REPLACE(@CanvasTable,''''['''',''''''''),'''']'''','''''''')

	If @SaveDelFin = ''''Delete''''
	BEGIN
		Set @Sql = ''''Delete from ''''+@CanvasTable + '''' Where Recordid = '''' +@RecordId 
		EXEC(@Sql)
	END
	If @SaveDelFin = ''''Save''''
	BEGIN

		IF @Dimtable = ''''$'''' SET @Dimtable = ''''''''
		IF @table = ''''$'''' SET @table = ''''''''
		IF @label = ''''$'''' SET @label = ''''''''
	
		If @recordid < 0
		Begin
			IF @Column = ''''[Sortorder]''''
			BEGIn

				Set @Sql = ''''
				SET IDENTITY_INSERT ''''+@CanvasTable+'''' ON
					INsert into ''''+ @CanvasTable+'''' 
					(recordid''''+@systemdefined+'''',sortOrder''''
				IF Right(@CanvasTable,6) <> ''''Detail'''' AND Right(@CanvasTable,7) <> ''''Booking'''' Set @Sql = @Sql + '''',label''''

				IF @CanvasTable = ''''Canvas_Consolidation_Rule_Detail'''' SET @Sql = @Sql + '''',Consolidation_Rule,Rule_Number'''' 
				IF @CanvasTable = ''''Canvas_Intercompany_Matching_Detail'''' SET @Sql = @Sql + '''',Intercompany_Matching_Rule'''' 
				IF @CanvasTable = ''''Canvas_Intercompany_Booking'''' SET @Sql = @Sql + '''',Intercompany_Matching_Rule'''' 
				IF @CanvasTable = ''''Canvas_Validation_Detail'''' SET @Sql = @Sql + '''',Validation'''' 
				IF @CanvasTable = ''''Canvas_Conversion_Rule_Detail'''' SET @Sql = @Sql + '''',Conversion_Rule'''' 
				IF @CanvasTable = ''''Canvas_Repartition_Detail'''' SET @Sql = @Sql + '''',Repartition'''' 
				IF @CanvasTable = ''''Canvas_Menu_Detail'''' SET @Sql = @Sql + '''',Menu '''' 
				IF @CanvasTable = ''''Canvas_Method_Selection_Detail'''' SET @Sql = @Sql + '''',Method_Selection ''''
				IF @CanvasTable = ''''Canvas_Copy_Model_Dimension_Detail'''' SET @Sql = @Sql + '''',Copy_Model_Dimension '''' ' 

			SET @SQLStatement = @SQLStatement + '
 

				SET @Sql = @Sql +  '''') values (''''+@recordid+@Systemdefinedvalue+'''',''''+@Label
				IF Right(@CanvasTable,6) <> ''''Detail''''  AND Right(@CanvasTable,7) <> ''''Booking'''' Set @Sql = @Sql + '''','''''''''''''''' ''''

				IF @CanvasTable = ''''Canvas_Consolidation_Rule_Detail'''' SET @Sql = @Sql + '''',''''''''''''+@Rule+'''''''''''',''''''''''''+@RuleNumber+''''''''''''''''
				IF @CanvasTable = ''''Canvas_Intercompany_Matching_Detail'''' SET @Sql = @Sql + '''',''''''''''''+@Rule+'''''''''''' ''''
				IF @CanvasTable = ''''Canvas_Intercompany_Booking'''' SET @Sql = @Sql + '''',''''''''''''+@Rule+'''''''''''' ''''
				IF @CanvasTable = ''''Canvas_Validation_Detail'''' SET @Sql = @Sql + '''',''''''''''''+@Rule+'''''''''''' ''''
				IF @CanvasTable = ''''Canvas_Conversion_Rule_Detail'''' SET @Sql = @Sql + '''',''''''''''''+@Rule+'''''''''''' ''''
				IF @CanvasTable = ''''Canvas_Repartition_Detail'''' SET @Sql = @Sql + '''',''''''''''''+@Rule+'''''''''''' ''''
				IF @CanvasTable = ''''Canvas_Menu_Detail'''' SET @Sql = @Sql + '''',''''''''''''+@Rule+'''''''''''' ''''
				IF @CanvasTable = ''''Canvas_Method_Selection_Detail'''' SET @Sql = @Sql + '''',''''''''''''+@Rule+'''''''''''' ''''
				IF @CanvasTable = ''''Canvas_Copy_Model_Dimension_Detail'''' SET @Sql = @Sql + '''',''''''''''''+@Rule+'''''''''''' ''''

				Set @Sql = @Sql + '''')
				SET IDENTITY_INSERT ''''+@canvastable+''''  OFF ''''
				Print(@Sql)
				EXEC(@Sql)
				
				SET @sql = ''''''''

				IF @CanvasTable = ''''Canvas_Consolidation_Rule_Detail'''' SET @Sql = 
				''''Update Canvas_Consolidation_Rule_Detail Set Consolidation_Rule_recordid = b.Recordid 
				From Canvas_Consolidation_Rule_Detail a, Canvas_Consolidation_Rule b 
				Where a.Consolidation_Rule = b.label 
				And b.label = ''''''''''''+@Rule+''''''''''''''''

				IF @CanvasTable = ''''Canvas_Intercompany_Matching_Detail'''' SET @Sql = 
				''''Update Canvas_Intercompany_Matching_Detail Set Intercompany_Matching_Rule_RecordId = b.Recordid 
				From Canvas_Intercompany_Matching_Detail a, Canvas_Intercompany_Matching b 
				Where a.Intercompany_Matching_Rule = b.label 
				And b.label = ''''''''''''+@Rule+'''''''''''''''' ' 

			SET @SQLStatement = @SQLStatement + '


				IF @CanvasTable = ''''Canvas_Intercompany_Booking'''' SET @Sql = 
				''''Update Canvas_Intercompany_Booking Set Intercompany_Matching_Rule_RecordId = b.Recordid 
				From Canvas_Intercompany_Booking a, Canvas_Intercompany_Matching b 
				Where a.Intercompany_Matching_Rule = b.label 
				And b.label = ''''''''''''+@Rule+''''''''''''''''

				IF @CanvasTable = ''''Canvas_Validation_Detail'''' SET @Sql = 
				''''Update Canvas_Validation_Detail Set Validation_recordid = b.Recordid 
				From Canvas_Validation_Detail a, Canvas_Validation b 
				Where a.Validation = b.label 
				And b.label = ''''''''''''+@Rule+''''''''''''''''

				IF @CanvasTable = ''''Canvas_Conversion_Rule_Detail'''' SET @Sql = 
				''''Update Canvas_Conversion_Rule_Detail Set Conversion_Rule_recordid = b.Recordid 
				From Canvas_Conversion_Rule_Detail a, Canvas_Conversion_Rule b 
				Where a.Conversion_Rule = b.label 
				And b.label = ''''''''''''+@Rule+''''''''''''''''

				IF @CanvasTable = ''''Canvas_Repartition_Detail'''' SET @Sql = 
				''''Update Canvas_Repartition_Detail Set Repartition_recordid = b.Recordid 
				From Canvas_Repartition_Detail a, Canvas_Repartition b 
				Where a.Repartition = b.label 
				And b.label = ''''''''''''+@Rule+'''''''''''''''' ' 

			SET @SQLStatement = @SQLStatement + '


				IF @CanvasTable = ''''Canvas_Menu_Detail'''' SET @Sql = 
				''''Update Canvas_Menu_Detail Set Menu_recordid = b.Recordid 
				From Canvas_Menu_Detail a, Canvas_Menus b 
				Where a.Menu = b.label 
				And b.label = ''''''''''''+@Rule+''''''''''''''''

				IF @CanvasTable = ''''Canvas_Method_Selection_Detail'''' SET @Sql = 
				''''Update Canvas_Method_Selection_Detail Set Method_Selection_recordid = b.Recordid 
				From Canvas_Method_Selection_Detail a, Canvas_Method_Selection b 
				Where a.Method_Selection = b.label 
				And b.label = ''''''''''''+@Rule+''''''''''''''''

				IF @CanvasTable = ''''Canvas_Copy_Model_Dimension_Detail'''' SET @Sql = 
				''''Update Canvas_Copy_Model_Dimension_Detail Set Copy_Model_Dimension_recordid = b.Recordid 
				From Canvas_Copy_Model_Dimension_Detail a, Canvas_Copy_Model_Dimension b 
				Where a.Copy_Model_Dimension = b.label 
				And b.label = ''''''''''''+@Rule+''''''''''''''''


				Print(@Sql)
				Exec(@Sql)

			END	
			ELSE
			BEGIn
				Set @sql = ''''UPDATE ''''+@CanvasTable+'''' Set ''''+ @Column + ''''='''''''''''' + @Label+'''''''''''' WHERE RecordID =''''+@Recordid
				Print(@Sql)
				EXEC(@Sql)
			END
		end ' 

			SET @SQLStatement = @SQLStatement + '

		If @recordid > 0
		BEGIN
			Set @sql = ''''UPDATE ''''+@CanvasTable+'''' Set ''''+ @Column + ''''='''''''''''' + @Label+'''''''''''' WHERE RecordID =''''+@Recordid
			Print(@Sql)
			EXEC(@Sql)
		END
			If @table <> ''''''''
			Begin
				If @label = '''''''' 
				BEGIN
					Set @Sql = ''''Update ''''+@canvastable+'''' Set ''''+REPLACE(@Column,'''']'''',''''_recordid]'''')+'''' = 0
					From  ''''+@canvastable+'''' a Where a.RecordId = ''''+@RecordId
					Print(@Sql)
					Exec(@Sql)
				end
				ELSE
				begin
					Select @Count = Count(b.Name) From Sysobjects a, Syscolumns b 
					Where a.Id = b.Id 
					and a.Name = @CanvasTable  
					and b.Name = REPLACE(REPLACE(@Column,''''['''',''''''''),'''']'''','''''''') ' 

			SET @SQLStatement = @SQLStatement + '


					IF @Count > 0
					BEGIN
						IF  ''''Canvas_''''+@Table <> @Canvastable
						BEGIN
							If @Column <> ''''[Sign]''''
							BEGIn				
								Set @Sql = ''''Update ''''+@Canvastable+'''' Set ''''+REPLACE(@Column,'''']'''',''''_recordid]'''')+'''' = b.Recordid 
								From  ''''+@Canvastable+'''' a, Canvas_''''+@Table+ '''' b 
								Where a.''''+@Column+'''' = b.Label 
								And a.RecordId = ''''+@RecordId
							END
							ELSE	
							BEGIN
								IF @Label = ''''-''''
								BEGIN
									Set @Sql = ''''Update ''''+@Canvastable+'''' Set ''''+REPLACE(@Column,'''']'''',''''_recordid]'''')+'''' = -1 
									From  ''''+@Canvastable+'''' a
									Where a.RecordId = ''''+@RecordId
								END
								IF @Label = ''''+''''
								BEGIN
									Set @Sql = ''''Update ''''+@Canvastable+'''' Set ''''+REPLACE(@Column,'''']'''',''''_recordid]'''')+'''' = 1 
									From  ''''+@Canvastable+'''' a
									Where a.RecordId = ''''+@RecordId
								END
							END				
						END ' 

			SET @SQLStatement = @SQLStatement + '

						ELSE
						BEGIN
							DECLARE @MyID BIGINT
							CREATE TABLE #Temp (RecordId BIGINT)	
							SET @sql = ''''INSERT INTO 
							#Temp Select RecordId From ''''+@CanvasTable+'''' 
							Where Label = ''''''''''''+@Label+''''''''''''''''
							EXEC(@Sql)
							Select @MyID = RecordID from #Temp
							Drop table #temp	
							SET @sql = ''''UPDATE ''''+@Canvastable+'''' Set ''''+REPLACE(@Column,'''']'''',''''_recordid]'''')+'''' = ''''+RTRIM(CAST(@MyID as char))+ '''' Where Recordid = ''''+@Recordid
						END
						Print(@Sql)
						Exec(@Sql)
					END
				end
			End
			if @DimTable <> ''''''''
			BEGIN
				If @label = '''''''' 
				BEGIN
					Set @Sql = ''''Update ''''+@CanvasTable + '''' Set ''''+REPLACE(@Column,'''']'''',''''_Memberid]'''')+'''' = 0
					From  ''''+@Canvastable+'''' a Where a.RecordId = ''''+@RecordId
					Print(@Sql)
					Exec(@Sql)
				end ' 

			SET @SQLStatement = @SQLStatement + '

				ELSE
				begin
					Select @Count = Count(b.Name) From Sysobjects a, Syscolumns b 
					Where a.Id = b.Id 
					and a.Name = @CanvasTable  
					and b.Name = REPLACE(REPLACE(@Column,''''['''',''''''''),'''']'''','''''''')

					IF @Count > 0
					BEGIN
						Set @Sql = ''''Update ''''+@canvastable+'''' Set ''''+REPLACE(@Column,'''']'''',''''_Memberid]'''')+'''' = b.memberid 
						From  ''''+@canvastable+'''' a, DS_''''+@DimTable+ '''' b 
						Where a.''''+@Column+'''' = b.Label 
						And a.RecordId = ''''+@RecordId
						Print(@Sql)
						Exec(@Sql)
					END
				end
			END
		--END
	IF @Column = @Fin Set @SaveDelFin = ''''Fin'''' 
	END ' 

			SET @SQLStatement = @SQLStatement + '

	If @SaveDelFin = ''''Fin''''
	BEGIN

				IF @CanvasTable = ''''Canvas_Menus''''
				SET @allcol =  ''''[SortOrder],[Label],[SystemDefined],[Model]''''			 

				IF @CanvasTable = ''''Canvas_Menu_Detail''''
				SET @allcol = 
				  ''''[SortOrder] ,[Menu_RecordId],[Menu],[Group_Number],[Group_RowNumber],[Menu_Item],[Menu_Type_RecordId],[Menu_Type],[Item_Name]
				  ,[Group_Image],[Run_Delete_Name],[Run_Report_Name],[Run_Parameter],[LocalCurrency],[SubMenu_Number]''''			 

				IF @CanvasTable = ''''Canvas_Consolidation_Rule''''
				SET @allcol = 
				 ''''[SortOrder],[Label],[SystemDefined],[Consolidation_Rule_RecordId],[Consolidation_Rule],[Rule_Number],[Scenario_MemberId],[Scenario]
				 ,[Source_BusinessProcess_MemberId],[Source_BusinessProcess],[Destination_BusinessProcess_MemberId],[Destination_BusinessProcess]
				 ,[Journal_Number],[Execution_Level],[Group_MemberId],[Group],[Available_Period_RecordId],[Available_Period],[From_MemberId],[From]
				 ,[To_MemberId],[To],[Local_Currency],[Special_Event],[Consolidation_Class_RecordId],[Consolidation_Class]''''

				IF @CanvasTable = ''''Canvas_Consolidation_Rule_Detail''''
				SET @allcol = 
				''''[SystemDefined],[SortOrder],[Consolidation_Rule_RecordId],[Consolidation_Rule],[Rule_Number],[Source_Flow_MemberId],[Source_Flow]
				,[Source_Time_RecordId],[Source_Time],[Source_Filter_RecordId],[Source_Filter],[Sign_RecordId],[Sign],[Destination_Account_MemberId]
				,[Destination_Account],[Destination_Flow_MemberId],[Destination_Flow],[Destination_Intercompany_MemberId],[Destination_Intercompany]
				,[Destination_Other_RecordId],[Destination_Other],[Swap_Equity_Account_MemberId],[Swap_Equity_Account],[Repartition_RecordId],[Repartition]
				,[Repartition_Class_RecordId],[Repartition_Class],[Invert_RecordId],[Invert]'''' ' 

			SET @SQLStatement = @SQLStatement + '

				
				IF @CanvasTable = ''''Canvas_Copyopening_Rule''''
				SET @allcol = 
				''''[Label],[SortOrder],[CopyOpening_Number],[Entity_MemberId],[Entity],[Scenario_MemberId],[Scenario],[BusinessProcess_MemberId],[BusinessProcess]
				,[Flow_MemberId],[Flow],[Source_Year_memberid],[Source_Year],[Source_Period_RecordId],[Source_Period],[Opening_Scenario_MemberId],[Opening_Scenario]
				,[Opening_BusinessProcess_MemberId],[Opening_BusinessProcess],[Opening_Account_MemberId],[Opening_Account],[Opening_Flow_MemberId],[Opening_Flow]
				,[Available_Period_RecordId],[Available_Period],[Destination_Other_RecordId],[Destination_Other],[Copy_Converted_Amount],[Invert_Amount],[Ytd]''''

				IF @CanvasTable = ''''Canvas_Conversion_Rule_Detail''''
				SET @allcol = 
				''''[Conversion_Rule_RecordId],[Conversion_Rule],[SortOrder],[Entity_MemberId],[Entity],[Flow_MemberId],[Flow],[Apply_Periodic_RecordId]
				,[Apply_Periodic],[Destination_Flow_MemberId],[Destination_Flow],[Destination_Account_MemberId],[Destination_Account],[Formula_RecordId]
				,[Formula],[Sum_To_Flow_MemberId],[Sum_To_Flow],[From_MemberId],[From],[To_MemberId],[To]''''

				IF @CanvasTable = ''''Canvas_Conversion_Rule''''
				SET @allcol = 
				''''[Label],[SortOrder],[SystemDefined],[MultiCurrency]''''

				IF @CanvasTable = ''''Canvas_Validation''''
				SET @allcol = 
				''''[Label],[Sortorder],[Entity_MemberId],[Entity],[Validation_Type_RecordId],[Validation_Type],[Destination_Other_RecordId],[Destination_Other]
				,[Available_Period_RecordId],[Available_Period],[Tolerance],[Dimension_BreakDown_RecordId],[Dimension_BreakDown],[Lock],[From_MemberId],[From]
				,[To_MemberId],[To],[Destination_Account_MemberId],[Destination_Account],[Compare_Account_MemberId],[Compare_Account],[Compare_Amount]'''' ' 

			SET @SQLStatement = @SQLStatement + '


				IF @CanvasTable = ''''Canvas_Validation_Detail''''
				SET @allcol = 
				''''[SortOrder],[Validation_RecordId],[Validation],[Sign_RecordId],[Sign],[Account_MemberId],[Account],[Flow_MemberId],[Flow]
				,[Dimension_Filter_RecordId],[Dimension_Filter],[Periodic]	''''

				IF @CanvasTable = ''''Canvas_Repartition_class''''
				SET @allcol = 
				''''[Label],[SortOrder]''''

				IF @CanvasTable = ''''Canvas_Repartition''''
				SET @allcol = 
				''''[Label],[SortOrder]''''

				IF @CanvasTable = ''''Canvas_Repartition_Detail''''
				SET @allcol = 
				''''[SortOrder],[Repartition_RecordId],[Repartition],[Method_RecordId],[Method],[New_Entity],[Interco_Method_RecordId],[Interco_Method]
				,[Investment_Method_RecordId],[Investment_Method],[Repartition_Class_RecordId],[Repartition_Class],[Formula_RecordId],[Formula]
				,[Opening_Method_RecordId],[Opening_Method],[Previous_Method_RecordId],[Previous_Method]''''

				IF @CanvasTable = ''''Canvas_Conversion_Formula''''
				SET @allcol = 
				''''[Label],[SortOrder],[Source_Year],[Source_Period_MemberId],[Source_Period]''''

				IF @CanvasTable = ''''Canvas_Consolidation_Formula''''
				SET @allcol = 
				''''[Label],[SortOrder]'''' ' 

			SET @SQLStatement = @SQLStatement + '


				IF @CanvasTable = ''''Canvas_Method_Selection''''
				SET @allcol = 
				''''[Label],[SortOrder]''''

				IF @CanvasTable = ''''Canvas_Method_Selection_Detail''''
				SET @allcol = 
				''''[SortOrder],[Method_selection_RecordId],[Method_selection],[Method_MemberId],[Method]''''

				IF @CanvasTable = ''''Canvas_Intercompany_Matching''''
				SET @allcol = 
				''''[Label],[Sortorder],[Description],[Entity_MemberId],[Entity],[Buyer_Rule],[Available_Period_RecordId],[Available_Period],[Tolerance]
				,[Dimension_Breakdown_RecordId],[Dimension_Breakdown],[Destination_BusinessProcess_MemberId],[Destination_BusinessProcess],[Destination_Account_MemberId]
				,[Destination_Account],[Destination_Other_RecordId],[Destination_Other],[Source_Businessprocess_MemberId],[Source_Businessprocess]
				,[Destination_Account_Receivables_Incomes_MemberId],[Destination_Account_Receivables_Incomes],[Destination_Account_Payables_Expenses_MemberId],[Destination_Account_Payables_Expenses]''''

				IF @CanvasTable = ''''Canvas_Intercompany_Matching_Detail''''
				SET @allcol = 
				''''[SortOrder],[Intercompany_Matching_Rule_RecordId],[Intercompany_Matching_Rule],[Sign_RecordId],[Sign],[Account_MemberId],[Account]
				,[Flow_MemberId],[Flow],[Source_Filter_RecordId],[Source_Filter],[Matching_Type_RecordId],[Matching_Type]''''

				IF @CanvasTable = ''''Canvas_Intercompany_Booking''''
				SET @allcol = 
				''''[SortOrder],[Intercompany_Matching_Rule_RecordId],[Intercompany_Matching_Rule],[DebitCredit_RecordId],[DebitCredit],[Account_MemberId],[Account],[Flow_MemberId]
				,[Flow],[Intercompany_MemberId],[Intercompany],[Destination_Other_RecordId],[Destination_Other]''''
				
				
				IF @CanvasTable = ''''Canvas_Copy_Model_Dimension''''
				SET @allcol = 
				''''Sortorder, Label , From_Model, To_Model ,From_Dimension, To_Dimension''''

				IF @CanvasTable = ''''Canvas_Copy_Model_Dimension_Detail''''
				SET @allcol = 
				''''Sortorder ,Copy_Model_Dimension_RecordId, Copy_Model_Dimension, From_Memberid, From_Label, To_Memberid, To_Label, InvertSign, YTD'''' ' 

			SET @SQLStatement = @SQLStatement + '


--==================================================================> 
				
				Set @Sql = ''''INSERT INTO ''''+@Canvastable + ''''
				(''''+@AllCol+'''')
				Select '''' +
				@AllCol +''''
				From ''''+@Canvastable+'''' Where Recordid = '''' + @Recordid
				Print(@Sql)
				EXEC(@Sql)

				SET @Sql = ''''Delete from ''''+@Canvastable+'''' Where  Recordid = '''' +@RecordId
				print(@sql)
				Exec(@sql)


	END	
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

--DROP table #temp,#dim




/****** Object:  StoredProcedure [dbo].[Canvas_TB_Dimensions]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_TB_Dimensions'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TB_Dimensions') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TB_Dimensions]
	@ModelName as nvarchar(255),
	@Dimtype AS NVARCHAR(255),
	@DimLabel AS NVARCHAR(255),
	@Hierarchy AS NVARCHAR(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @sql AS NVARCHAR(MAX),@DimName NVARCHAR(255),@Property NVARCHAR(MAX)
	,@AllSelect NVARCHAR(Max),@AllSelectNew NVARCHAR(Max)

	SELECT @DimName = Label FROM Dimensions WHERE [Type] = @DimType
	IF @DimType = ''''Account''''
	BEGIN
	SET @SQL = ''''SELECT [RecordId],[SortOrder]
		,[''''+@DimName+''''_MemberId],[DebitCredit_RecordId],-99,-99,[CopyOpening_Rule_RecordId],[Conversion_Rule_RecordId],[Consolidation_Rule_RecordId],-99
		,[''''+@DimName+''''],[DebitCredit],CASE [Input] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END,CASE [Journal] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		,[CopyOpening_Rule],[Conversion_Rule],[Consolidation_Rule],CASE [FlowCalculation] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		,[''''+@DimName+''''],[DebitCredit]
		,CASE [Input] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		,CASE [Journal] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		,[CopyOpening_Rule]
		,[Conversion_Rule]
		,[Consolidation_Rule]
		,CASE [FlowCalculation] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		FROM [dbo].[Canvas_Dim''''+@DimName+''''] 
		UNION ALL 
		SELECT 0,999999
		,[MemberId],[Sign],-99,-99,-1,-1,-1,-99
		,[Label],CASE Sign WHEN 1 THEN ''''''''Debit'''''''' ELSE ''''''''Credit'''''''' END,''''''''True'''''''',''''''''True'''''''','''''''''''''''','''''''''''''''','''''''''''''''',''''''''False''''''''
		,[Label],CASE Sign WHEN 1 THEN ''''''''Debit'''''''' ELSE ''''''''Credit'''''''' END,''''''''True'''''''',''''''''True'''''''','''''''''''''''','''''''''''''''','''''''''''''''',''''''''False''''''''
		FROM [dbo].[DS_''''+@DimName+''''] 
		Where Memberid not in (Select ''''+@DimName+''''_Memberid From [Canvas_Dim''''+@DimName+'''']) ''''
		If @Dimlabel In ('''''''',''''false'''',''''No'''') Set @Sql = @Sql + '''' And Memberid In (Select memberid from HC_''''+@DimName+ '''' 
		Where parentid = ''''''''''''+@DimLabel+'''''''''''' And hierarchy = ''''''''''''+@Hierarchy+'''''''''''')''''  
		Set @Sql = @Sql + ''''	ORDER BY 	[SortOrder] ''''
	
	END
	IF @DimType = ''''Businessprocess''''
	BEGIN
		DECLARE @GroupName AS NVARCHAR(100)
		SELECT @Groupname = Label FROM Dimensions WHERE [Type] = ''''Group''''
		SET @SQL = ''''SELECT [RecordId],[SortOrder]
		,[''''+@DimName+''''_MemberId],[Input],[journal],[Conversion],[Consolidation],[LowerStage_BusinessProcess_MemberId],[BusinessProcess_Class_RecordId]
		,[''''+@GroupName+''''_MemberId],[BusinessProcessElimCompany_MemberId]
		,[''''+@DimName+'''']
		,CASE [Input] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		,CASE [Journal] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		,CASE [Conversion] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		,CASE [Consolidation] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		,[LowerStage_BusinessProcess],[BusinessProcess_Class],[''''+@GroupName+''''],[BusinessProcessElimCompany]
		,[''''+@DimName+''''] ' 

			SET @SQLStatement = @SQLStatement + '

		,CASE [Input] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		,CASE [Journal] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		,CASE [Conversion] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		,CASE [Consolidation] WHEN 1 THEN ''''''''True'''''''' ELSE ''''''''False'''''''' END
		,[LowerStage_BusinessProcess],[BusinessProcess_Class],[''''+@GroupName+''''],[BusinessProcessElimCompany]
		FROM [dbo].[Canvas_Dim''''+@DimName+''''] 
		UNION ALL 
		SELECT 0,999999
		,[MemberId],1,1,1,1,-1,-1,-1,-1
		,[Label],''''''''True'''''''',''''''''True'''''''',''''''''True'''''''',''''''''True'''''''',''''''''NONE'''''''',''''''''NONE'''''''',''''''''NONE'''''''',''''''''NONE''''''''
		,[Label],''''''''True'''''''',''''''''True'''''''',''''''''True'''''''',''''''''True'''''''',''''''''NONE'''''''',''''''''NONE'''''''',''''''''NONE'''''''',''''''''NONE''''''''
		FROM [dbo].[DS_''''+@DimName+''''] 
		Where Memberid not in (Select ''''+@DimName+''''_Memberid From [Canvas_Dim''''+@DimName+'''']) ''''
		If @Dimlabel In ('''''''',''''false'''',''''No'''') Set @Sql = @Sql + '''' And Memberid In (Select memberid from HC_''''+@DimName+ '''' 
		Where parentid = ''''''''''''+@DimLabel+'''''''''''' And hierarchy = ''''''''''''+@Hierarchy+'''''''''''')''''  
		Set @Sql = @Sql + ''''	ORDER BY 	[SortOrder] ''''
	END		
	--Print(@Sql)	     
	EXEC(@Sql)	     

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END











/****** Object:  StoredProcedure [dbo].[Canvas_TB_ListTable]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_LST_WorkFlowItemsUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TB_ListTable') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TB_ListTable]
	@ModelName as nvarchar(255),
	@TableName Nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	DECLARE @Sql Nvarchar(1000),@TimeDim Nvarchar(50)

	Select @TimeDim = b.label From ModelDimensions a, Dimensions b Where b.label = a.Dimension and b.[Type] = ''''Time''''

	SET @Sql = ''''SELECT [Label] FROM [dbo].['''' + @TableName  + '''']  ORDER BY SortOrder'''' 
	IF @TableName = ''''Canvas_Models'''' OR @TableName = ''''Models'''' 
	begin
		SET @Sql = ''''SELECT [Label] FROM Models '''' 
	end
	IF @TableName = ''''Users'''' 
	BEGIN
		SET @Sql = ''''SELECT [WinUser] FROM [dbo].['''' + @TableName  + '''']  ORDER BY 1'''' 
		CREATE TABLE #Temp (Winuser NVARCHAR(255),userid Bigint)
		INSERT INTO #temp SELECT winuser,userid FROM users Where Winuser not in (Select winuser from canvas_Users)
		IF @@ROWCOUNT > 0
		BEGIN
			DECLARE @ID BIGINT,@V1 INT,@Winuser NVARCHAR(255),@user NVARCHAR(255),@testchar Nvarchar(100)
			DECLARE Table_Cursor CURSOR FOR select winuser,userid from #Temp

			OPEN Table_Cursor 
			FETCH NEXT FROM Table_Cursor INTO @winuser,@Id
			WHILE @@FETCH_STATUS = 0 
			BEGIN
				SET @V1 = len(@winuser)
		
				WHILE @V1 >  0
				BEGIN
					SET @testChar = Substring(@winuser,@V1,1)
					print @testchar
					IF @testChar = ''''\'''' 
					BEGIN
							SET @user = SUBSTRING(@Winuser,@V1+1,255)
							INSERT INTO canvas_users ([Label],[UserId],[WinUser])
							VALUES (@user,@id,@winuser)
							Set @V1 = 0
					END
					SET @V1 = @V1 - 1	
				END
				FETCH NEXT FROM Table_Cursor INTO @winuser,@Id
			END 
			CLOSE Table_Cursor 
			DEALLOCATE Table_Cursor
			Drop table #temp
		END
	END ' 

			SET @SQLStatement = @SQLStatement + '

	
	IF @TableName = ''''canvas_Users'''' SET @Sql = ''''SELECT [WinUser] FROM [dbo].['''' + @TableName  + '''']  ORDER BY SortOrder'''' 
	IF @TableName = ''''canvas_Year''''  SET @Sql = ''''
	SELECT [Label],1 FROM [dbo].[DS_'''' + @Timedim  + ''''] 
	Where Label <> ''''''''None'''''''' 
	and len(Label) = 4 
	UNION ALL
	SELECT [Label],2 FROM [dbo].[DS_'''' + @Timedim  + '''']  Where left(label,1) in (''''''''+'''''''',''''''''-'''''''',''''''''='''''''')
	ORDER BY 2'''' 
	IF @TableName = ''''canvas_Period''''  SET @Sql = ''''SELECT [Label] FROM [dbo].[DS_TimeFiscalPeriod] ORDER BY Label'''' 
	IF @TableName = ''''Canvas_Available_Period'''' SET @Sql = ''''SELECT [Label] FROM [dbo].['''' + @TableName  + ''''] WHERE label <> '''''''''''''''' AND period IS NULL ORDER BY SortOrder'''' 
	IF @TableName = ''''Canvas_Dimension_BreakDown'''' SET @Sql = ''''SELECT DISTINCT [Label] FROM [dbo].['''' + @TableName  + ''''] ORDER BY SortOrder'''' 
	IF @TableName = ''''Canvas_Consolidation_Rule'''' SET @Sql = ''''SELECT DISTINCT [Consolidation_Rule] FROM [dbo].['''' + @TableName  + ''''] WHERE Rule_Number = 1  ORDER BY SortOrder '''' 
	IF @TableName = ''''Canvas_listEntity'''' SET @Sql = ''''SELECT DISTINCT [Label] FROM [dbo].[DS_'''' + @TableName  + ''''] WHERE Rule_Number = 1  ORDER BY SortOrder '''' 
	IF @TableName = ''''Canvas_Menus'''' SET @Sql = ''''SELECT [Label],Model FROM [dbo].['''' + @TableName  + '''']  Where model = ''''''''''''+@ModelName+'''''''''''''''' 
	IF @TableName = ''''Canvas_Dimensions'''' SET @Sql = ''''SELECT [Dimension] FROM [dbo].[ModelAllDimensions]  Where model = ''''''''''''+@ModelName+'''''''''''''''' 
	IF @TableName = ''''Dimensions'''' SET @Sql = ''''SELECT [Dimension] FROM [dbo].[ModelAllDimensions]  Where model = ''''''''''''+@ModelName+'''''''''''''''' 
	EXEC(@Sql)

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END









/****** Object:  StoredProcedure [dbo].[Canvas_TB_Menu]    Script Date: 3/2/2017 11:34:03 AM ******/

/****** Object:  StoredProcedure [dbo].[Canvas_TB_Menu]    Script Date: 9/5/2014 3:48:00 PM ******/
SET @Step = 'Create Canvas_TB_Menu'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TB_Menu') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TB_Menu]
	@ModelName as nvarchar(255),
	@menu as nvarchar(255),
	@Num  as nvarchar(255)=''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN

If @Num = 0
BEGIN
SELECT [RecordId]
      ,[Menu_RecordId]
      ,[SortOrder]
      ,[Menu]
	  ,[Group_Number]	,[Group_RowNumber]  ,[Menu_Item]  ,[Menu_Type]  ,[Item_Name]
	  ,[Group_Image]  ,[Run_Delete_Name]  ,[Run_Report_Name]  ,[Run_Parameter]  ,[LocalCurrency]
	  ,[Group_Number]  ,[Group_RowNumber]  ,[Menu_Item]  ,[Menu_Type]  ,[Item_Name]
	  ,[Group_Image]  ,[Run_Delete_Name]  ,[Run_Report_Name]  ,[Run_Parameter]  ,[LocalCurrency]
  FROM [dbo].[Canvas_Menu_Detail]
  WHERE Menu = @Menu
  ORDER BY 15,16,	[SortOrder]   
END
ELSE
BEGIN
SELECT [RecordId]
      ,[Menu_RecordId]
      ,[SortOrder]
	  ,[Menu]
	  ,[Group_Number]	,[Group_RowNumber]  ,[Menu_Item]  ,[Menu_Type]  ,[Item_Name]
	  ,[Group_Image]  ,[Run_Delete_Name]  ,[Run_Report_Name]  ,[Run_Parameter]  ,[LocalCurrency]
	  ,[Group_Number]  ,[Group_RowNumber]  ,[Menu_Item]  ,[Menu_Type]  ,[Item_Name]
	  ,[Group_Image]  ,[Run_Delete_Name]  ,[Run_Report_Name]  ,[Run_Parameter]  ,[LocalCurrency]
  FROM [dbo].[Canvas_Menu_Detail]
  WHERE Menu = @Menu And group_Number = @Num
  ORDER BY 15,16,	[SortOrder]   
END

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END









/****** Object:  StoredProcedure [dbo].[Canvas_TB_MenuHeader]    Script Date: 3/2/2017 11:34:03 AM ******/

/****** Object:  StoredProcedure [dbo].[Canvas_TB_MenuHeader]    Script Date: 9/5/2014 3:48:00 PM ******/
SET @Step = 'Create Canvas_TB_MenuHeader'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TB_MenuHeader') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TB_MenuHeader]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
	SELECT [RecordId],SortOrder,-99 AS Label_recordId,-99 AS Model_recordId, Label, Model, Label, Model FROM Canvas_Menus
    ORDER BY 	[SortOrder]   
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END








/****** Object:  StoredProcedure [dbo].[Canvas_TB_MenuHeaderUpdate]    Script Date: 3/2/2017 11:34:03 AM ******/

/****** Object:  StoredProcedure [dbo].[Canvas_TB_MenuHeaderUpdate]    Script Date: 9/5/2014 3:48:00 PM ******/
SET @Step = 'Create Canvas_TB_MenuHeaderUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TB_MenuHeaderUpdate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TB_MenuHeaderUpdate]
	@ModelName as nvarchar(255),
	@RecordId  as nvarchar(255),
	@AllParam  as nvarchar(255),
	@SortOrder  as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN



	DECLARE @V1 int,@V2 INT 
	,@Label Nvarchar(255)
	,@Model Nvarchar(100)

	SET @V1 = CHARINDEX(''''|'''',@AllParam,1)
	SET @Label = SUBSTRING(@AllParam,1,@V1-1)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @Model = SUBSTRING(@AllParam,@V1+1,255)

		
	--	IF @DefaultValue = ''''$'''' SET @DefaultValue = ''''''''
	IF @recordid > 0 
	BEGIN	
		UPDATE dbo.Canvas_Menus
		SET 
		[Label] = @Label
		,[Model] = @Model
		,[SortOrder] = @SortOrder
		WHERE RecordiD = @RecordId
	END
	ELSE
	BEGIN
		INSERT INTO dbo.Canvas_Menus
		([Label],[Model],[SortOrder]) 
		VALUES (@Label,@Model,@SortOrder)
	END	
	
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END








/****** Object:  StoredProcedure [dbo].[Canvas_TB_MenuListHeader]    Script Date: 3/2/2017 11:34:03 AM ******/

/****** Object:  StoredProcedure [dbo].[Canvas_TB_MenuListHeader]    Script Date: 9/5/2014 3:48:00 PM ******/
SET @Step = 'Create Canvas_TB_MenuListHeader'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TB_MenuListHeader') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TB_MenuListHeader]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
	Create Table #Temp (Label Nvarchar(255),Recordid Bigint ,Sortorder bigint identity (1,1))

	Insert into #temp 
	(Label,Recordid)
	SELECT [Label],[RecordId] FROM [dbo].[Canvas_Menus]  ORDER BY 2

	select * from #temp


END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END








/****** Object:  StoredProcedure [dbo].[Canvas_TB_MenuUpdate]    Script Date: 3/2/2017 11:34:03 AM ******/

/****** Object:  StoredProcedure [dbo].[Canvas_TB_MenuUpdate]    Script Date: 9/5/2014 3:48:00 PM ******/
SET @Step = 'Create Canvas_TB_MenuUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TB_MenuUpdate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  

  PROCEDURE  [dbo].[Canvas_TB_MenuUpdate]
	@ModelName as nvarchar(255),
	@RecordId  as nvarchar(255),
	@AllParam  as nvarchar(255),
	@SortOrder  as nvarchar(255),
	@Menu  as nvarchar(255) = '''''''',
	@MenuId AS NVARCHAR(255) = ''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
	DECLARE @Lap INT, @V1 INT,@V2 INT,@Menu_recordid INT
	,@Id BIGINT
	,@Group_Number NVARCHAR(255)
	,@Group_RowNumber NVARCHAR(255)
	,@Menu_Item NVARCHAR(255)
	,@Menu_Type NVARCHAR(255)
	,@Item_Name NVARCHAR(255)
	,@Group_Image NVARCHAR(255)
	,@Run_Delete_Name NVARCHAR(255)
	,@Run_Report_Name NVARCHAR(255)
	,@Run_Parameter NVARCHAR(255)
	,@LocalCurrency NVARCHAR(255)
	,@Menu_Type_RecordId NVARCHAR(255)

	SET @V1 = CHARINDEX(''''|'''',@AllParam,1)
	SET @Group_Number = SUBSTRING(@allparam,1,@V1-1)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @Group_RowNumber= SUBSTRING(@allparam,@V1+1,@V2-1 -@V1)
	SET @V1 =  CHARINDEX(''''|'''',@AllParam,@V2+1)
	SET @Menu_Item =  SUBSTRING(@allparam,@V2+1,@V1-1 -@V2)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @Menu_Type= SUBSTRING(@allparam,@V1+1,@V2-1 -@V1)
	SET @V1 =  CHARINDEX(''''|'''',@AllParam,@V2+1)
	SET @Item_Name =  SUBSTRING(@allparam,@V2+1,@V1-1 -@V2)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @Group_Image= SUBSTRING(@allparam,@V1+1,@V2-1 -@V1)
	SET @V1 =  CHARINDEX(''''|'''',@AllParam,@V2+1)
	SET @Run_Delete_Name =  SUBSTRING(@allparam,@V2+1,@V1-1 -@V2)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @Run_Report_Name = SUBSTRING(@allparam,@V1+1,@V2-1 -@V1)
	SET @V1 =  CHARINDEX(''''|'''',@AllParam,@V2+1)
	SET @Run_Parameter =  SUBSTRING(@allparam,@V2+1,@V1-1 -@V2)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @LocalCurrency = SUBSTRING(@allparam,@V1+1,255)

	--	IF @DefaultValue = ''''$'''' SET @DefaultValue = ''''''''

	select * from Canvas_Menu_Type

	Select @Menu_Type_RecordId = recordId From Canvas_Menu_Type Where Label = @Menu_Type

	IF @recordid > 0 
	BEGIN	
		UPDATE dbo.Canvas_Menu_Detail 
		SET [Group_Number] = @Group_Number
		,[Group_RowNumber] = @Group_RowNumber
		,[Menu_Item] = @Menu_Item
		,[Menu_Type] = @Menu_Type  
		,[Item_Name] = @Item_Name
		,[Group_Image] = @Group_Image
		,[Run_Delete_Name] = @Run_Delete_Name
		,[Run_Report_Name] = @Run_Report_Name  
		,[Run_Parameter] = @Run_Parameter
		,[LocalCurrency] = @LocalCurrency
		,[Menu_Type_recordid] = @Menu_Type_RecordId 
		,[SortOrder] = @SortOrder 
		WHERE RecordiD = @RecordId
	END
	ELSE
	BEGIN
		SELECT @Menu_Recordid = Recordid FROM dbo.Canvas_Menus WHERE Label = @Menu

		INSERT INTO dbo.Canvas_menu_Detail 
		([SortOrder],[Menu_RecordId],[Menu],[Group_Number],[Group_RowNumber],[Menu_Item],[Menu_Type_RecordId]
		,[Menu_Type],[Item_Name],[Group_Image],[Run_Delete_Name],[Run_Report_Name],[Run_Parameter],[LocalCurrency])

		VALUES (@SortOrder,@Menu_RecordId,@Menu,@Group_Number,@Group_RowNumber,@Menu_Item,@Menu_Type_RecordId
		,@Menu_Type,@Item_Name,@Group_Image,@Run_Delete_Name,@Run_Report_Name,@Run_Parameter,@LocalCurrency)
	END	
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END








/****** Object:  StoredProcedure [dbo].[Canvas_TB_MenuUsers]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_TB_MenuUsers'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TB_MenuUsers') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TB_MenuUsers]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
	Create table #temp (
	[RecordId] Bigint,
	SortOrder INT ,
	RowId INT Identity(1,1) ,
	WMenu Nvarchar(255), 
	[WWinUSER] Nvarchar(255), 
	Menu Nvarchar(255), 
	[WinUSER] Nvarchar(255))

	Insert into #temp
	( [RecordId],SortOrder,WMenu,[WWinUSER],Menu,[WinUSER])
	SELECT a.[RecordId],a.SortOrder, a.Menu, a.[WinUSER], a.Menu, a.[WinUSER] 
	FROM [Canvas_Menu_Users] a, Canvas_Menus b
	Where 
	b.model = @ModelName
	and	a.menu = b.Label
	and a.Winuser in (Select Winuser from Users) OR User in (Select Winuser from Users) 

	Select * from #temp order by rowid

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END








/****** Object:  StoredProcedure [dbo].[Canvas_TB_MenuUsersUpdate]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_TB_MenuUsersUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TB_MenuUsersUpdate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TB_MenuUsersUpdate]
	@ModelName as nvarchar(255),
	@RecordId  as nvarchar(255),
	@AllParam  as nvarchar(255),
	@SortOrder  as nvarchar(255),
	@MenuName  as nvarchar(255) = '''''''',
	@MenuNameId AS NVARCHAR(255) = ''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
	DECLARE @Lap INT, @V1 INT,@V2 INT,@Deb INT,@OldV1 INT
	,@Id BIGINT
    ,@Menu NVARCHAR(255)
    ,@User NVARCHAR(255)
    ,@WinUser NVARCHAR(255)
    ,@Menu_RecordId NVARCHAR(255)
    ,@UserId NVARCHAR(255)
      

	SET @V1 = CHARINDEX(''''|'''',@AllParam,1)
	SET @Menu = SUBSTRING(@allparam,1,@V1-1)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @WINUser= SUBSTRING(@allparam,@V1+1,255)



	SET @V1 = 1
	SET @Deb = 1 ' 

			SET @SQLStatement = @SQLStatement + '

	SELECT @UserId = Userid from Users Where Winuser = @WinUser OR DisplayName = @WinUser
	SELECT @Menu_RecordId = recordId from Canvas_Menus Where Label = @Menu
		
	WHILE @V1 > 0
	BEGIN
		SET @V1 = CHARINDEX(''''\'''',@WinUser,@Deb)
		PRINT CAST(@V1 AS CHAR)
		IF @V1 <> 0 
		BEGIN		
		SET @OLDV1 = @V1
		SET @Deb = @V1 + 1
		END
	END
	
	SET @USER = SUBSTRING(@Winuser,@OLDV1+1,255)
	

	--	IF @DefaultValue = ''''$'''' SET @DefaultValue = ''''''''
	IF @recordid > 0 
	BEGIN	
		UPDATE dbo.Canvas_Menu_USers 
		SET [Menu] = @Menu
		,[WinUser] = @WinUser
		,[User] = @User
		,[Menu_RecordId] = @Menu_RecordId
		,[User_recordID] = @UserId 
		,[SortOrder] = 0 
		WHERE RecordiD = @RecordId
	END
	ELSE
	BEGIN
		INSERT INTO dbo.Canvas_menu_USers 
		([SortOrder],[Menu],[WinUser],[User],[Menu_RecordId],[User_recordID])
		VALUES (0,@Menu,@WinUser,@User,@Menu_RecordId,@USerID)
	END	
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END








/****** Object:  StoredProcedure [dbo].[Canvas_TB_Parameters]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_TB_Parameters'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TB_Parameters') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TB_Parameters]
	@ModelName as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
	SELECT [RecordId],Sortorder,Parametertype,ParameterName,StringValue,Parametertype,ParameterName,StringValue
	  FROM [dbo].[Canvas_Parameters]
	  ORDER BY 	[SortOrder]   
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END








/****** Object:  StoredProcedure [dbo].[Canvas_TB_ParametersUpdate]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Canvas_TB_ParametersUpdate'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TB_ParametersUpdate') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TB_ParametersUpdate]
	@ModelName as nvarchar(255),
	@RecordId as nvarchar(255),
	@AllParam  as nvarchar(255),
	@SortOrder  as nvarchar(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

BEGIN
DECLARE @V1 int,@V2 INT 
,@ParameterType Nvarchar(255)
,@ParameterName Nvarchar(255)
,@StringValue Nvarchar(255)

	SET @V1 = CHARINDEX(''''|'''',@AllParam,1)
	SET @ParameterType = SUBSTRING(@AllParam,1,@V1-1)
	SET @V2 =  CHARINDEX(''''|'''',@AllParam,@V1+1)
	SET @ParameterName = SUBSTRING(@AllParam,@V1+1,@V2-1 -@V1)
	SET @V1 =  CHARINDEX(''''|'''',@AllParam,@V2+1)
	SET @StringValue =  SUBSTRING(@AllParam,@V2+1,255)


	IF @recordid > 0 
	BEGIN	
		UPDATE dbo.Canvas_Parameters
		SET 
		ParameterType = @ParameterType
		,ParameterName = @ParameterName
		,StringValue = @StringValue
		WHERE RecordiD = @RecordId
	END
	ELSE
	BEGIN
		INSERT INTO dbo.Canvas_Parameters
		(ParameterType,ParameterName,StringValue,Sortorder) 
		VALUES (@ParameterType,@ParameterName,@StringValue,@SortOrder)
	END	
	
END '

IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END








/****** Object:  StoredProcedure [dbo].[Canvas_TB_TableDelete]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Canvas_TB_TableDelete' 

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_TB_TableDelete') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_TB_TableDelete]
	@ModelName as nvarchar(255),
	@RecordId  as nvarchar(255),
	@TableName AS NVARCHAR(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN
	DECLARE @SQL NVARCHAR(MAX),@Label Nvarchar(255),@Num Int
	--	IF @DefaultValue = ''''$'''' SET @DefaultValue = ''''''''
	IF @recordid > 0 
	BEGIN	
		SET @SQL = ''''DELETE FROM dbo.[''''+@TableName+''''] WHERE RecordiD = ''''+@RecordId
		EXEC(@Sql)
		IF @TableName = ''''Canvas_Conversion_Rule'''' 
		BEGIN
			SELECT @Label = label FROM [Canvas_Conversion_Rule] WHERE recordId = @RecordId
			DELETE FROM [Canvas_Conversion_Rule_Detail] WHERE Conversion_Rule = @Label			
		END
		IF @TableName = ''''Canvas_Validation'''' 
		BEGIN
			SELECT @Label = label FROM [Canvas_Validation] WHERE recordId = @RecordId
			DELETE FROM [Canvas_Validation_Detail] WHERE [Validation] = @Label			
		END
		IF @TableName = ''''Canvas_Menus'''' 
		BEGIN
			SELECT @Label = label FROM [Canvas_Menus] WHERE recordId = @RecordId
			DELETE FROM [Canvas_Menu_Detail] WHERE Menu = @Label			
		END
		IF @TableName = ''''Canvas_Consolidation_Rule'''' 
		BEGIN
			SELECT @Label = Consolidation_Rule FROM [Canvas_Consolidation_Rule] WHERE recordId = @RecordId
			SELECT @Num = Rule_Number FROM [Canvas_Consolidation_Rule] WHERE recordId = @RecordId
			DELETE FROM [Canvas_Consolidation_Rule_Detail] WHERE Consolidation_Rule = @Label AND Rule_Number = @Num			
		END
	END
	
END '

IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END








/****** Object:  StoredProcedure [dbo].[canvas_Users_Email]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create canvas_Users_Email'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'canvas_Users_Email') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE [dbo].[canvas_Users_Email]
	@modelname Nvarchar(250),
	@User Nvarchar(250),
	@All nvarchar(250)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
as
BEGIN
	create table #temp (allusers  nvarchar(max))
	Declare @lap INT
	SET @Lap = 1
	Declare User_Cursor cursor for select b.Email from canvas_users a,Users b where a.winuser = b.winuser
	open User_Cursor
	fetch next from User_Cursor into @User
	while @@FETCH_STATUS = 0
	begin
		If @Lap = 1 INSERT INTO #temp VAlues (@user)
		IF @lap > 1 Update #temp set allusers = allusers +'''',''''+@user

		Set @Lap = @Lap + 1  
		fetch next from User_Cursor into @User
	end
	close User_Cursor
	deallocate User_Cursor

	select * from #temp

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END










/****** Object:  StoredProcedure [dbo].[Canvas_Util_CopyDataWorkFlow]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Util_CopyDataWorkFlow'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Util_CopyDataWorkFlow') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  

  PROCEDURE    [dbo].[Canvas_Util_CopyDataWorkFlow]
	@ModelName as nvarchar(255) = ''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--====================================
--====================================
--====================================
--DECLARE	@ModelName as nvarchar(255) 
--SET @Modelname = ''''Sales''''
--====================================
--====================================
--====================================

BEGIN
 
--  select * into #temp_parametervalues From temp_parametervalues 

	DECLARE @Scenario INT,@ScenarioSource1 INT,@ScenarioSource2 INT,@Time INT,@TimeDataView INT,@Version INT
	DECLARE @Businessprocess INT,@ASBusinessprocess INT,@BusinessprocessDim Nvarchar(50)	
	DECLARE @ScenarioID NVARCHAR(255),@ScenarioSource1ID NVARCHAR(255),@ScenarioSource2ID NVARCHAR(255),@TimeID NVARCHAR(255)
	,@lap int,@ret bigint,@scenarioDim Nvarchar(50),@TimeDim Nvarchar(50),@AccountDim Nvarchar(50)
	DECLARE @DimLabel Nvarchar(50),@DimType Nvarchar(50),@Sql Nvarchar(Max)
	declare @Found int,@Alldim Nvarchar(Max),@Otherdim Nvarchar(Max),@Alldim_Memberid Nvarchar(Max),@Sep Nvarchar(2),@StartPeriod Nvarchar(255)
	DECLARE @MaxNumber INT,@Number INT,@MaxScenario INT,@ScenarioSourceBudget INT,@user nvarchar(250)
	DECLARE @variable Nvarchar(50),@Update Nvarchar(Max),@Count INT,@Memberid INT

	Select @user = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''
	Select @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''

	Create Table #temp (ID BIGINT)

	DECLARE @FactText BIT,@FactDetail Bit,@FactDetailText Bit
	SET @FactText = 0
	SET @FactDetail = 0
	SET @FactDetailText = 0
	IF EXISTS(select name FROM dbo.sysobjects WITH (NOLOCK) where name =''''FACT_''''+@ModelName+''''_Text'''' And xtype = ''''U'''')  SET @FactText = 1
	IF EXISTS(select name FROM dbo.sysobjects WITH (NOLOCK) where name =''''FACT_''''+@ModelName+''''_Detail'''' And xtype = ''''U'''')  SET @FactDetail = 1
	IF EXISTS(select name FROM dbo.sysobjects WITH (NOLOCK) where name =''''FACT_''''+@ModelName+''''_Detail_Text'''' And xtype = ''''U'''')  SET @FactDetailtext = 1

	SET @Otherdim = ''''''''
	SET @Alldim = ''''''''
	SET @Found = 0
	SET @Count = 0
	SET @Update = ''''UPDATE #Fact1 SET ''''

	DECLARE @isversion BIT
	SET @isversion = 0
	SET @Lap = 1 
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] <> ''''TimeDataView'''' ORDER BY b.[type]
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin ' 

			SET @SQLStatement = @SQLStatement + '

		Select @variable = Segment_Type from Canvas_WorkFlow_Segment Where Model = @ModelName and Dimension = @DimLabel

		If @lap = 1 SET @Sep = ''''[''''
		If @lap > 1 SET @Sep = '''',[''''

		IF @Dimlabel = ''''Version'''' SET @isversion = 1

		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Account''''
		begin
			set @AccountDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end 

		if @DimType = ''''BusinessProcess''''
		begin
			set @BusinessprocessDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		Set @Lap = @Lap + 1  
		end
		if @Found = 0
		begin
			If @variable = ''''Segment_Fixed'''' 
			BEGIN
				Truncate table #temp
				Set @Memberid = 0
				Set @sql = ''''INsert into #temp select Memberid from DS_''''+@Dimlabel+'''' 
				Where label IN (Select  DefaultValue From Canvas_Workflow_Segment Where Model = ''''''''''''+@ModelName+'''''''''''' and Dimension = ''''''''''''+@Dimlabel+'''''''''''') ''''
				EXEC(@Sql)
				Select @Memberid = ID from #temp
				
				IF @memberid <> 0 
				BEGIN
					IF @Count = 0 set @Update = @Update +''''
					''''+@Dimlabel+''''_Memberid = ''''+RTRIM(LTRIM(Cast(@Memberid as char)))

					IF @Count > 0 set @Update = @Update +''''
					,''''+@Dimlabel+''''_Memberid = ''''+RTRIM(LTRIM(Cast(@Memberid as char)))
				 				
					Set @count = @count + 1
				END
			END
			set @OtherDim = @OtherDim +@Sep + RTRIM(@DimLabel)+'''']''''
		end
		Set @Found = 0
		fetch next from Dim_cursor into @DimLabel,@DimType

	end
	close Dim_cursor
	deallocate Dim_cursor 


	

	IF @OtherDim <> '''''''' Set @AllDim = @AllDim + '''','''' + @OtherDim
	SET @Alldim = Replace(@Alldim,'''',,'''','''','''')
	SET @AllDim_Memberid = Replace(@Alldim,'''']'''',''''_Memberid]'''') 
	
	Create table #account (Account_Memberid Bigint) 
	Set @Sql = ''''Insert into #account select memberid from DS_''''+@AccountDim +'''' Where BP_BUDGET = ''''''''PREALLOC'''''''' ''''
	--EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '


	Create table #Fact (Value Float)
	Set @sql = ''''Alter table #Fact add ''''+REPLACE(@AllDim_Memberid,'''']'''',''''] Bigint'''')
	EXEC(@Sql)

	Select * into #Fact1 from #Fact

	Select * into #Fact_Detail from #Fact
	ALTER TABLE #Fact_Detail ADD LineItem_Memberid BIGINT

	Create table #Fact_text (Text_Value Nvarchar(4000))
	Set @sql = ''''Alter table #Fact_Text add ''''+REPLACE(@AllDim_Memberid,'''']'''',''''] Bigint'''')+'''',Row Bigint, Col Bigint,Schedule_RecordId Bigint''''
	--Print(@Sql)
	EXEC(@Sql)

	Create table #Fact_Detail_text (Text_Value Nvarchar(4000))
	Set @sql = ''''Alter table #Fact_Detail_Text add ''''+REPLACE(@AllDim_Memberid,'''']'''',''''] Bigint'''')+'''',LineItem_Memberid BIGINT''''
	--Print(@Sql)
	EXEC(@Sql)

	Declare @Year Int
	Select @MaxNumber = Max(ReForecast_Number) From Canvas_Workflow_ReForecast  Where Model = @ModelName
	Select @Number = ReForecast_Number  From Canvas_Workflow_ReForecast Where Active = ''''True'''' And Model = @ModelName
	Select @StartPeriod = startPeriod  From Canvas_Workflow_ReForecast Where Active = ''''True'''' And Model = @ModelName

	If @number = 0 
	begin
		set @year = @startperiod
	end
	Else
	begin
		Set @year = CAST(Substring(@startPeriod,1,4) as INT)
	end 

	TRUNCATE TABLE #Temp
	Set @sql = ''''INsert into #temp select Memberid from DS_''''+@ScenarioDim+'''' 
	Where label IN (Select Scenario From Canvas_Workflow_ReForecast Where Active = ''''''''True'''''''' And Model = ''''''''''''+@ModelName+'''''''''''') ''''
	EXEC(@Sql)
	Select @Scenario = ID from #temp
	IF @number = 0
	begin
		truncate table #temp
		Set @sql = ''''INsert into #temp select Memberid from DS_''''+@ScenarioDim+'''' 
		Where label IN (Select Scenario  From Canvas_Workflow_ReForecast Where Reforecast_Number = ''''+CAST(@MaxNumber as char)+'''' And Model = ''''''''''''+@ModelName+'''''''''''')''''
		EXEC(@Sql)
		Select @ScenarioSourcebudget = ID from #temp
	end

	truncate table #temp ' 

			SET @SQLStatement = @SQLStatement + '

	Set @sql = ''''INsert into #temp select Memberid from DS_''''+@ScenarioDim+'''' 
	Where label IN (Select  StringValue From Canvas_Parameters Where ParameterName = ''''''''ReforeCast_Copy'''''''' and parameterType = ''''''''Workflow'''''''') ''''
	EXEC(@Sql)
	Select @ScenarioSource1 = ID from #temp

	TRUNCATE TABLE #Temp
	Set @sql = ''''INsert into #temp select Memberid from DS_''''+@ScenarioDim+'''' 
	Where label IN (Select copyfrom  From Canvas_Workflow_ReForecast Where Active = ''''''''True'''''''' And Model = ''''''''''''+@ModelName+'''''''''''')''''
	EXEC(@Sql)
	IF @@ROWCOUNT = 0 RETURN
	Select @ScenarioSource2 = ID from #temp


	IF @number = 0
	BEGIN
		IF @ScenarioSource1 <> @ScenarioSource2 
		BEGIN
			SET @ScenarioSource1 = @ScenarioSource2
			SET @maxNumber = 1
		END
	END

	TRUNCATE TABLE #Temp 

	Set @sql = ''''INsert into #temp select Memberid from DS_''''+@BusinessProcessDim+'''' 
	Where label IN (Select DefaultValue From Canvas_Workflow_Segment Where Dimension = ''''''''''''+@BusinessProcessDim+''''''''''''  And Model = ''''''''''''+@ModelName+'''''''''''' )''''
	EXEC(@Sql)
	Select @BusinessProcess = ID from #temp
	CREATE TABLE #Businessprocess (Memberid BIGINT)

	Set @sql = ''''INsert into #Businessprocess 
	select Memberid from DS_''''+@BusinessProcessDim+'''' 
	Where label IN (Select DefaultValue From Canvas_Workflow_Segment Where Dimension = ''''''''''''+@BusinessProcessDim+'''''''''''' And Model = ''''''''''''+@ModelName+'''''''''''')
	UNION ALL 
	select Memberid from DS_''''+@BusinessProcessDim+'''' 
	Where label IN (''''''''BR_AS'''''''',''''''''BR_BS'''''''',''''''''BR_CF'''''''')''''
	EXEC(@Sql)

	TRUNCATE TABLE #Temp
	Set @sql = ''''INsert into #temp select Memberid from DS_''''+@TimeDim+'''' 
	Where label IN (Select startPeriod  From Canvas_Workflow_ReForecast Where Active = ''''''''True'''''''' And Model = ''''''''''''+@ModelName+'''''''''''')''''
	EXEC(@Sql)
	Select @Time = ID from #temp
	
	Create Table #Time (Memberid Bigint,Label Nvarchar(255))
	Create Table #Time2 (Memberid Bigint,Label Nvarchar(255))
	Set @Sql = ''''Insert into #Time Select memberid,label From Ds_''''+@TimeDim+'''' Where Substring(Label,1,4) = ''''''''''''+CAST(@Year as char)+''''''''''''
	And Memberid not in (Select parentId from HC_''''+@TimeDim+'''' where Parentid <> Memberid )''''
	EXEC(@Sql) 


	Set @Sql = ''''Insert into #Time2 Select memberid,label From Ds_''''+@TimeDim+'''' Where Substring(Label,1,4) = ''''''''''''+CAST(@Year - 1 as char)+''''''''''''
	And Memberid not in (Select parentId from HC_''''+@TimeDim+'''' where Parentid <> Memberid ) ''''
	EXEC(@Sql)
	
	CREATE Table #tempN (name nvarchar(255))
	SET @Sql = ''''Insert into #tempN Select b.name 
	FROM dbo.sysobjects a, dbo.syscolumns b WITH (NOLOCK) 
	where a.name = ''''''''FACT_''''+@ModelName+''''_Text''''''''
	And b.Name = ''''''''Row'''''''' ''''
	Exec(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '

	IF @@ROWCOUNT = 0 
	BEGIN
		SET @Sql = ''''ALTER TABLE FACT_''''+@ModelName+''''_text ADD Row BIGINT ''''
		EXEC(@Sql)
	END

	IF @FactText = 1
	BEGIN
		Truncate table #tempN
		SET @Sql = ''''Insert into #tempN Select b.name 
		FROM dbo.sysobjects a, dbo.syscolumns b WITH (NOLOCK) 
		where a.name = ''''''''FACT_''''+@ModelName+''''_Text''''''''
		And b.Name = ''''''''Col'''''''' ''''
		Exec(@Sql)
		IF @@ROWCOUNT = 0 
		BEGIN
			SET @Sql = ''''ALTER TABLE FACT_''''+@ModelName+''''_text ADD Col BIGINT ''''
			EXEC(@Sql)
		END
		Truncate table #tempN
		SET @Sql = ''''Insert into #tempN Select b.name 
		FROM dbo.sysobjects a, dbo.syscolumns b WITH (NOLOCK) 
		where a.name = ''''''''FACT_''''+@ModelName+''''_Text''''''''
		And b.Name = ''''''''Schedule_recordId'''''''' ''''
		Exec(@Sql)
		IF @@ROWCOUNT = 0 
		BEGIN
			SET @Sql = ''''ALTER TABLE FACT_''''+@ModelName+''''_text ADD Schedule_recordId BIGINT ''''
			EXEC(@Sql)
		END
	END
 


--	IF @Number <> 0
--	BEGIN
		Set @Sql = ''''Delete From FACT_''''+@ModelName+''''_default_partition Where ''''+@ScenarioDim+''''_Memberid = ''''''''''''+CAST(@Scenario as char)+'''''''''''' 
		And ''''+@TimeDim+''''_Memberid IN (Select Memberid From #time)
		And ''''+@BusinessProcessDim+''''_Memberid in (Select Memberid From #Businessprocess) ''''
		--Print(@Sql)
		EXEC(@Sql)
		IF @FactDetail = 1
		BEGIN
			Set @Sql = ''''Delete From FACT_''''+@ModelName+''''_Detail_default_partition Where ''''+@ScenarioDim+''''_Memberid = ''''''''''''+CAST(@Scenario as char)+'''''''''''' 
			And ''''+@TimeDim+''''_Memberid IN (Select Memberid From #time)
			And ''''+@BusinessProcessDim+''''_Memberid in (Select Memberid From #Businessprocess) ''''
			Print(@Sql)
			EXEC(@Sql)
		END ' 

			SET @SQLStatement = @SQLStatement + '

		IF @FactText = 1
		BEGIN
			Set @Sql = ''''Delete From FACT_''''+@ModelName+''''_Text Where ''''+@ScenarioDim+''''_Memberid = ''''''''''''+CAST(@Scenario as char)+'''''''''''' 
			And ''''+@TimeDim+''''_Memberid IN (Select Memberid From #time)
			And ''''+@BusinessProcessDim+''''_Memberid in (Select Memberid From #Businessprocess) ''''
			Print(@Sql)
			EXEC(@Sql)
		END
		IF @FactDetailText = 1
		BEGIN
			Set @Sql = ''''Delete From FACT_''''+@ModelName+''''_Detail_Text Where ''''+@ScenarioDim+''''_Memberid = ''''''''''''+CAST(@Scenario as char)+'''''''''''' 
			And ''''+@TimeDim+''''_Memberid IN (Select Memberid From #time)
			And ''''+@BusinessProcessDim+''''_Memberid in (Select Memberid From #Businessprocess) ''''
			Print(@Sql)
			EXEC(@Sql)
		END


		Set @Sql = ''''Insert into ''''
		IF @Count > 0 SET @Sql = @Sql + '''' #Fact1 ''''
		IF @Count = 0 SET @Sql = @Sql + '''' #Fact ''''
		SET @Sql = @Sql + '''' Select ''''+@ModelName+''''_Value,''''+@Alldim_Memberid+''''
		From FACT_''''+@ModelName+''''_default_partition 
		WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@ScenarioSource1 as char) 
		iF @Isversion = 1 Set @sql = @sql + '''' 
		And Version_Memberid = -1 ''''
		Set @Sql = @Sql + '''' 
		And ''''+@AccountDim+''''_memberid not in (Select Account_memberid from #Account)
		And ''''+@BusinessprocessDim+''''_memberid not in (Select memberid from DS_''''+@BusinessprocessDim+'''' Where label in (''''''''BR_Profitability'''''''',''''''''Amount'''''''')) 
		And ''''+@TimeDim+''''_Memberid IN (Select Memberid From '''' 
		If @number = 0 set @sql = @sql + '''' #time2 Where Substring(Label,1,4) = ''''''''''''+RTRIM(CAST(@Year - 1 as char))+'''''''''''' ''''
		If @number <> 0 set @sql = @sql + '''' #time Where Substring(Label,1,4) = ''''''''''''+RTRIM(CAST(@Year as char))+'''''''''''' 
		and SubString(Label,5,2) < ''''''''''''+Substring(@StartPeriod,5,2)+''''''''''''''''
		SET @Sql = @sql + '''')''''
		PRINT(@Sql)
		EXEC(@Sql) 

		IF @Count > 0
		BEGIN
			Print(@Update)
			Exec(@Update)

			Set @Sql = ''''Insert into #Fact Select SUM(Value),''''+@Alldim_Memberid+''''
			From #FACT1
			Group By ''''+@Alldim_Memberid
			PRINT(@Sql)
			EXEC(@Sql)
		END

		IF @FactText = 1
		BEGIN
			Set @Sql = ''''Insert into #Fact_Text Select ''''+@ModelName+''''_Text,''''+@Alldim_Memberid+'''',Row,Col,Schedule_RecordId
			From FACT_''''+@ModelName+''''_Text
			WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@ScenarioSource1 as char)
			iF @Isversion = 1 Set @sql = @sql + '''' 
			And Version_Memberid = -1 ''''
			Set @Sql = @Sql + '''' 
			And ''''+@BusinessprocessDim+''''_memberid not in (Select memberid from DS_''''+@BusinessprocessDim+'''' Where label in (''''''''BR_Profitability'''''''',''''''''Amount'''''''')) 
			And ''''+@TimeDim+''''_Memberid IN (Select Memberid From '''' 
			If @number = 0 set @sql = @sql + '''' #time2 Where Substring(Label,1,4) = ''''''''''''+RTRIM(CAST(@Year - 1 as char))+'''''''''''' ''''
			If @number <> 0 set @sql = @sql + '''' #time Where Substring(Label,1,4) = ''''''''''''+RTRIM(CAST(@Year as char))+'''''''''''' 
			and SubString(Label,5,2) < ''''''''''''+Substring(@StartPeriod,5,2)+''''''''''''''''
			SET @Sql = @sql + '''')''''
			PRINT(@Sql)
			EXEC(@Sql)
		END ' 

			SET @SQLStatement = @SQLStatement + '

		IF @FactDetail = 1
		BEGIN
			Set @Sql = ''''Insert into #Fact_Detail Select ''''+@ModelName+''''_Detail_Value,''''+@Alldim_Memberid+'''',LineItem_Memberid
			From FACT_''''+@ModelName+''''_Detail_default_partition 
			WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@ScenarioSource1 as char)+'''' 
			
			And ''''+@BusinessprocessDim+''''_memberid not in (Select memberid from DS_''''+@BusinessprocessDim+'''' Where label in (''''''''BR_Profitability'''''''',''''''''Amount'''''''')) 
			And ''''+@TimeDim+''''_Memberid IN (Select Memberid From '''' 
			If @number = 0 set @sql = @sql + '''' #time2 Where Substring(Label,1,4) = ''''''''''''+RTRIM(CAST(@Year - 1 as char))+'''''''''''' ''''
			If @number <> 0 set @sql = @sql + '''' #time Where Substring(Label,1,4) = ''''''''''''+RTRIM(CAST(@Year as char))+'''''''''''' 
			and SubString(Label,5,2) < ''''''''''''+Substring(@StartPeriod,5,2)+''''''''''''''''
			SET @Sql = @sql + '''')''''
			PRINT(@Sql)
			EXEC(@Sql)
		END
		IF @FactDetailText = 1
		BEGIN
			Set @Sql = ''''Insert into #Fact_Detail_Text Select ''''+@ModelName+''''_Detail_Text,''''+@Alldim_Memberid+'''',LineItem_Memberid
			From FACT_''''+@ModelName+''''_Detail_Text
			WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@ScenarioSource1 as char) 
			iF @Isversion = 1 Set @sql = @sql + '''' 
			And Version_Memberid = -1 ''''
			Set @Sql = @Sql + '''' 
			And ''''+@BusinessprocessDim+''''_memberid not in (Select memberid from DS_''''+@BusinessprocessDim+'''' Where label in (''''''''BR_Profitability'''''''',''''''''Amount'''''''')) 
			And ''''+@TimeDim+''''_Memberid IN (Select Memberid From '''' 
			If @number = 0 set @sql = @sql + '''' #time2 Where Substring(Label,1,4) = ''''''''''''+RTRIM(CAST(@Year - 1 as char))+'''''''''''' ''''
			If @number <> 0 set @sql = @sql + '''' #time Where Substring(Label,1,4) = ''''''''''''+RTRIM(CAST(@Year as char))+'''''''''''' 
			and SubString(Label,5,2) < ''''''''''''+Substring(@StartPeriod,5,2)+''''''''''''''''
			SET @Sql = @sql + '''')''''
			PRINT(@Sql)
			EXEC(@Sql)
		END

	Create table #timebudget (time_memberid Bigint)
	If @Number = 0
	Begin
 		SET @sql = ''''Insert into #timebudget Select Distinct ''''+@timeDim+''''_memberid From #fact''''
		EXEC(@Sql)
		Delete from #time2 where memberid in (Select time_memberid from #timebudget)

		Alter table #timebudget add TimeDest Bigint
		
		Set @sql =''''Update #timebudget Set TimeDest = c.memberid From #timebudget a,Ds_''''+@TimeDim+'''' b,Ds_''''+@TimeDim+'''' c
		Where Substring(b.Label,1,4) = ''''''''''''+RTRIM(CAST(@Year - 1 as char))+'''''''''''' 
		And Substring(c.Label,1,4) = ''''''''''''+RTRIM(CAST(@Year as char))+''''''''''''  
		And Substring(b.Label,5,4) = Substring(c.Label,5,4)
		And a.time_memberid = b.memberid		''''
		print(@sql)
		EXEC(@sql)  ' 

			SET @SQLStatement = @SQLStatement + '



		SET @ret = @MaxNumber
		SET @lap = 1
		While @ret = 0
		Begin
			Set @Sql = ''''Insert into #Fact Select ''''+@ModelName+''''_Value,''''+@Alldim_Memberid+''''
			From FACT_''''+@ModelName+''''_default_partition 
			WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@ScenarioSourceBudget as char) 
			iF @Isversion = 1 Set @sql = @sql + '''' 
			And Version_Memberid = -1 ''''
			Set @Sql = @Sql + '''' 
			And ''''+@AccountDim+''''_memberid not in (Select Account_memberid from #Account)
			And ''''+@BusinessprocessDim+''''_memberid not in (Select memberid from DS_''''+@BusinessprocessDim+'''' Where label in (''''''''BR_Profitability'''''''')) 
			And ''''+@TimeDim+''''_Memberid IN (Select Memberid From #time2 Where 
			Substring(Label,1,4) = ''''''''''''+CAST(@Year as char)+'''''''''''' 
			And ''''+@ModelName+''''_Value <> 0 ''''
			print(@Sql)
			EXEC(@Sql)
	
			SET @ret = @@Rowcount
			
			IF @FactText = 1
			BEGIN
				Set @Sql = ''''Insert into #Fact_Text Select ''''+@ModelName+''''_Text,''''+@Alldim_Memberid+'''',row,col,schedule_recordid 
				From FACT_''''+@ModelName+''''_Text
				WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@ScenarioSourceBudget as char) 
				iF @Isversion = 1 Set @sql = @sql + '''' 
				And Version_Memberid = -1 ''''
				Set @Sql = @Sql + '''' 
				And ''''+@TimeDim+''''_Memberid IN (Select Memberid From #time2 Where 
				Substring(Label,1,4) = ''''''''''''+CAST(@Year as char)+'''''''''''' 
				And ''''+@ModelName+''''_Text <> '''''''''''''''' ''''
				EXEC(@Sql)
				SET @ret = @ret + @@Rowcount
			END
			IF @FactDetail = 1
			BEGIN
				Set @Sql = ''''Insert into #Fact_Detail Select ''''+@ModelName+''''_Detail_Value,''''+@Alldim_Memberid+'''',LineItem_Memberid
				From FACT_''''+@ModelName+''''_Detail_default_partition 
				WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@ScenarioSourceBudget as char) 
				iF @Isversion = 1 Set @sql = @sql + '''' 
				And Version_Memberid = -1 ''''
				Set @Sql = @Sql + '''' 
				And ''''+@TimeDim+''''_Memberid IN (Select Memberid From #time2 Where 
				Substring(Label,1,4) = ''''''''''''+CAST(@Year as char)+'''''''''''' 
				And ''''+@ModelName+''''_Value <> 0 ''''
				EXEC(@Sql)
				SET @ret = @@Rowcount
			END
			IF @FactDetailText = 1
			BEGIN
				Set @Sql = ''''Insert into #Fact_Text Select ''''+@ModelName+''''_Text,''''+@Alldim_Memberid+'''',row,col,schedule_recordid ,LineItem_Memberid
				From FACT_''''+@ModelName+''''_Detail_Text
				WHERE ''''+@scenarioDim+''''_Memberid = ''''+CAST(@ScenarioSourceBudget as char) 
				iF @Isversion = 1 Set @sql = @sql + '''' 
				And Version_Memberid = -1 ''''
				Set @Sql = @Sql + '''' 
				And ''''+@TimeDim+''''_Memberid IN (Select Memberid From #time2 Where 
				Substring(Label,1,4) = ''''''''''''+CAST(@Year as char)+'''''''''''' 
				And ''''+@ModelName+''''_Text <> '''''''''''''''' ''''
				EXEC(@Sql)
				SET @ret = @ret + @@Rowcount
			END ' 

			SET @SQLStatement = @SQLStatement + '


			Set @lap = @lap - 1
			truncate table #temp
			Set @sql = ''''INsert into #temp select Memberid from DS_''''+@ScenarioDim+'''' 
			Where label IN (Select Scenario  From Canvas_Workflow_ReForecast Where Reforecast_Number = ''''+CAST(@lap as char)+'''' And Model = ''''''''''''+@ModelName+'''''''''''')''''
			EXEC(@Sql)
			Select @ScenarioSourcebudget = ID from #temp
			If @Lap = 1 set @ret = 0

		End 

		SET @sql = ''''Update #fact set [''''+@TimeDim+''''_Memberid] = b.timedest 
		from #Fact a, #timebudget b 
		Where a.''''+@TimeDim+''''_Memberid = b.Time_Memberid ''''
--		PRINT(@Sql)		
		EXEC(@Sql)		

		IF @FactText = 1
		BEGIN
			SET @sql = ''''Update #fact_Text set [''''+@TimeDim+''''_Memberid] = b.timedest 
			from #Fact_Text a, #timebudget b 
			Where a.''''+@TimeDim+''''_Memberid = b.Time_Memberid ''''
	--		PRINT(@Sql)		
			EXEC(@Sql)		
		END
		IF @FactDetail = 1
		BEGIN
			SET @sql = ''''Update #fact_Detail set [''''+@TimeDim+''''_Memberid] = b.timedest 
			from #Fact a, #timebudget b 
			Where a.''''+@TimeDim+''''_Memberid = b.Time_Memberid ''''
	--		PRINT(@Sql)		
			EXEC(@Sql)		
		END
		IF @FactDetailText = 1
		BEGIN
			SET @sql = ''''Update #fact_Detail_Text set [''''+@TimeDim+''''_Memberid] = b.timedest 
			from #Fact_Text a, #timebudget b 
			Where a.''''+@TimeDim+''''_Memberid = b.Time_Memberid ''''
	--		PRINT(@Sql)		
			EXEC(@Sql)		
		END
	end  ' 

			SET @SQLStatement = @SQLStatement + '


	If @number <> 0
	begin
		Set @Sql = ''''Insert into #Fact Select ''''+@ModelName+''''_Value,''''+@Alldim_Memberid+'''' 
		From FACT_''''+@ModelName+''''_default_partition 
		WHERE ''''+@scenarioDim+''''_Memberid = ''''+cast(@ScenarioSource2 as char)+'''' And ''''+@TimeDim+''''_Memberid IN (Select Memberid From #time Where 
		Substring(Label,1,4) = ''''''''''''+CAST(@Year as char)+'''''''''''' and SubString(Label,5,2) >= ''''''''''''+Substring(@StartPeriod,5,2)+'''''''''''') ''''
		iF @Isversion = 1 Set @sql = @sql + '''' 
		And Version_Memberid = -1 ''''
		Set @Sql = @Sql + '''' 
		And ''''+@BusinessprocessDim+''''_memberid not in (Select memberid from DS_''''+@BusinessprocessDim+'''' Where label in (''''''''BR_Profitability'''''''')) 
		And ''''+@AccountDim+''''_memberid not in (Select Account_memberid from #Account) ''''
		Print (@Sql)
		EXEC(@Sql)

		IF @FactText = 1
		BEGIN
			Set @Sql = ''''Insert into #Fact_Text Select ''''+@ModelName+''''_Text,''''+@Alldim_Memberid+'''',row,col,schedule_recordid 
			From FACT_''''+@ModelName+''''_Text
			WHERE ''''+@scenarioDim+''''_Memberid = ''''+cast(@ScenarioSource2 as char)+'''' And ''''+@TimeDim+''''_Memberid IN (Select Memberid From #time Where 
			Substring(Label,1,4) = ''''''''''''+CAST(@Year as char)+'''''''''''' and SubString(Label,5,2) >= ''''''''''''+Substring(@StartPeriod,5,2)+'''''''''''') ''''
			iF @Isversion = 1 Set @sql = @sql + '''' 
			And Version_Memberid = -1 ''''
			Print(@Sql)
			EXEC(@Sql)
		END
		IF @FactDetail = 1
		BEGIN
			Set @Sql = ''''Insert into #Fact_Detail Select ''''+@ModelName+''''_Detail_Value,''''+@Alldim_Memberid+'''',LineItem_Memberid 
			From FACT_''''+@ModelName+''''_Detail_default_partition 
			WHERE ''''+@scenarioDim+''''_Memberid = ''''+cast(@ScenarioSource2 as char)+'''' And ''''+@TimeDim+''''_Memberid IN (Select Memberid From #time Where 
			Substring(Label,1,4) = ''''''''''''+CAST(@Year as char)+'''''''''''' and SubString(Label,5,2) >= ''''''''''''+Substring(@StartPeriod,5,2)+'''''''''''')'''' 
			iF @Isversion = 1 Set @sql = @sql + '''' 
			And Version_Memberid = -1 ''''
			EXEC(@Sql)
		END
		IF @FactDetailText = 1
		BEGIN
			Set @Sql = ''''Insert into #Fact_Detail_Text Select ''''+@ModelName+''''_Detail_Text,''''+@Alldim_Memberid+'''',LineItem_Memberid
			From FACT_''''+@ModelName+''''_Detail_Text
			WHERE ''''+@scenarioDim+''''_Memberid = ''''+cast(@ScenarioSource2 as char)+'''' And ''''+@TimeDim+''''_Memberid IN (Select Memberid From #time Where 
			Substring(Label,1,4) = ''''''''''''+CAST(@Year as char)+'''''''''''' and SubString(Label,5,2) >= ''''''''''''+Substring(@StartPeriod,5,2)+'''''''''''')'''' 
			iF @Isversion = 1 Set @sql = @sql + '''' 
			And Version_Memberid = -1 ''''
			Print(@Sql)
			EXEC(@Sql)
		END
	end 


	SET @Sql = ''''Update #Fact Set ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as CHAR)+'''', ''''+@BusinessProcessDim+''''_Memberid = ''''+CAST(@BusinessProcess as CHAR)+'''', BusinessRule_Memberid = -1'''' 
	Print(@Sql)  
	EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '





	Select @TimeDataView = memberid From DS_TimeDataView Where Label = ''''RAWDATA''''
	If @isversion = 1 Select @Version = memberid From DS_Version Where Label IN (select DefaultValue from Canvas_WorkFlow_Segment Where Segment_Type = ''''Version'''' And Model = @ModelName)
	If @isversion = 0 Set @Version = 0

	IF @FactText = 1
	BEGIN
		SET @Sql = ''''Update #Fact_Text Set ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as CHAR)+'''', ''''+@BusinessProcessDim+''''_Memberid = ''''+CAST(@BusinessProcess as CHAR) +'''', BusinessRule_Memberid = -1''''
		EXEC(@Sql)
		
		IF @isversion = 1 Update #Fact_text Set version_memberid = @Version
	END
	IF @FactDetail = 1
	BEGIN
		SET @Sql = ''''Update #Fact_Detail Set ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as CHAR)+'''', ''''+@BusinessProcessDim+''''_Memberid = ''''+CAST(@BusinessProcess as CHAR)+'''', BusinessRule_Memberid = -1'''' 
		EXEC(@Sql)
	END	
	IF @FactDetailText = 1
	BEGIN
		SET @Sql = ''''Update #Fact_Detail_Text Set ''''+@scenarioDim+''''_Memberid = ''''+CAST(@Scenario as CHAR)+'''', ''''+@BusinessProcessDim+''''_Memberid = ''''+CAST(@BusinessProcess as CHAR)+'''', BusinessRule_Memberid = -1'''' 
		EXEC(@Sql)
	END

	If @isversion = 1 Update #Fact Set version_memberid = @Version
	
	--Update #Fact Set TimeDataView_memberid = @TimeDataView
	DECLARE @CurrentDim nvarchar(250),@Defaultvalue nvarchar(250),@DefaultvalueID BIGINT

print ''''======================================================================================''''
print ''''======================================================================================''''
print ''''======================================================================================''''
	
	Declare CurDim_cursor cursor for Select Dimension,DefaultValue from Canvas_Workflow_Segment where Segment_Type = ''''Segment_Fixed'''' and Model = @ModelName 
	open CurDim_cursor
	fetch next from CurDim_cursor into @CurrentDim,@DEfaultvalue
	while @@FETCH_STATUS = 0
	begin

		Truncate table #temp
		Set @sql = ''''Insert into #temp select memberid from DS_''''+@currentDim+'''' where label = ''''''''''''+@Defaultvalue+''''''''''''''''
		Print(@Sql)
		Exec(@Sql)
		Select @DefaultvalueID = id from #Temp

		SET @Sql = ''''Update #Fact Set ''''+@CurrentDim+ ''''_memberid = ''''+CAST(@DefaultvalueID as char)
			Print(@Sql)
		EXEC(@Sql)

		IF @FactDetail = 1
		BEGIN
			SET @Sql = ''''Update #Fact_Detail Set ''''+@CurrentDim+ ''''_memberid = ''''+CAST(@DefaultvalueID as char)
			Print(@Sql)
			EXEC(@Sql)
		END
		fetch next from CurDim_cursor into @CurrentDim,@DEfaultvalue

	end
	close CurDim_cursor
	deallocate CurDim_cursor  ' 

			SET @SQLStatement = @SQLStatement + '


print ''''======================================================================================''''
print ''''======================================================================================''''
print ''''======================================================================================''''



	SET @Sql = ''''INSERT INTO [FACT_''''+@ModelNAME+''''_default_partition] 
	(''''+@AllDim_Memberid+'''',[ChangeDateTime],[''''+@ModelNAME+''''_Value],TimeDataView_Memberid,userId)
	SELECT ''''+@AllDim_Memberid+'''',GETDATE(),VALUE,''''+CAST(@TimeDataView as CHAR)+'''',''''''''''''+@USer+''''''''''''
	From #Fact
	WHERE ABS(Value) > 0.05 ''''
	EXEC(@Sql)

	IF @FactText = 1
	BEGIN
		SET @Sql = ''''INSERT INTO [FACT_''''+@ModelNAME+''''_Text] 
		(''''+@AllDim_Memberid+'''',[ChangeDateTime],[''''+@ModelNAME+''''_text],TimeDataView_Memberid,userId,Row,Col,Schedule_recordid)
		SELECT ''''+@AllDim_Memberid+'''',GETDATE(),text_VALUE,''''+CAST(@TimeDataView as CHAR)+'''',''''''''''''+@USer+'''''''''''',Row,Col,Schedule_recordid
		From #Fact_text ''''
		Print(@Sql)
		EXEC(@Sql)
	END
	IF @FactDetail = 1
	BEGIN
		SET @Sql = ''''INSERT INTO [FACT_''''+@ModelNAME+''''_Detail_default_partition] 
		(''''+@AllDim_Memberid+'''',[ChangeDateTime],[''''+@ModelNAME+''''_Detail_Value],TimeDataView_Memberid,userId,LineItem_Memberid)
		SELECT ''''+@AllDim_Memberid+'''',GETDATE(),VALUE,''''+CAST(@TimeDataView as CHAR)+'''',''''''''''''+@USer+'''''''''''',LineItem_Memberid
		From #Fact_Detail
		WHERE ABS(Value) > 0.05 ''''
		--Print(@Sql)
		EXEC(@Sql)
	END
	IF @FactDetailText = 1
	BEGIN
		SET @Sql = ''''INSERT INTO [FACT_''''+@ModelNAME+''''_Detail_Text] 
		(''''+@AllDim_Memberid+'''',[ChangeDateTime],[''''+@ModelNAME+''''_Detail_text],TimeDataView_Memberid,userId,LineItem_Memberid)
		SELECT ''''+@AllDim_Memberid+'''',GETDATE(),text_VALUE,''''+CAST(@TimeDataView as CHAR)+'''',''''''''''''+@USer+'''''''''''',LineItem_Memberid
		From #Fact_detail_text ''''
		--Print(@Sql)
		EXEC(@Sql)
	END
	
-- Drop table #account,#fact,#fact,#fact1,#fact_detail,#fact_text,#Fact_Detail_text,#temp,#tempN,#Businessprocess,#time,#time2,#timebudget

END  '

IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

/****** Object:  StoredProcedure [dbo].[Canvas_Util_generate_WorkFlow]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Util_generate_WorkFlow'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Util_generate_WorkFlow') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Util_generate_WorkFlow]
	@ModelName NVARCHAR(255),
	@UserName NVARCHAR(255)
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

--DECLARE	@ModelName NVARCHAR(255),@UserName NVARCHAR(255)
--Set @ModelName = ''''Financials''''
--Set @username = ''''Administrator''''

	DECLARE	@Proc_Id BIGINT, @EXIST Bit, @NBEXIST int
	DECLARE @Scenario Nvarchar(255),@Time Nvarchar(255),@ScenarioName Nvarchar(255),@TimeName Nvarchar(255),@Driver Nvarchar(255),@Driver_1 Nvarchar(255),@MaxDriver INT,@Lap INT,
	@SQL Nvarchar(max),@Select NVARCHAR(2000),@FROM NVARCHAR(2000),@WHERE NVARCHAR(MAX),@Default NVARCHAR(255),@UPDATE NVARCHAR(1000),@ALTER NVARCHAR(2000),
	@ALTER2  NVARCHAR(2000),	@Values NVARCHAR(max),@WinUserName NVARCHAR(255),@Maxs INT,@testS Nvarchar(255),@Schedule Nvarchar(255),@UPDATEHIDE NVARCHAR(MAX),@UPDATEShow NVARCHAR(MAX)
	,@SelectAll nvarchar(Max),@SelectAllDriver nvarchar(Max),@SelectHide nvarchar(Max),@AND_Hide nvarchar(Max),@UPDATEName NVARCHAR(MAX)
	DECLARE @ScenarioDim Nvarchar(100),@TimeDim Nvarchar(100),@SelectDISTINCT NVARCHAR(2000),@Year nvarchar(4)

	SELECT @ScenarioDim = A.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] = ''''Scenario''''
	SELECT @TimeDim = A.[Dimension] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Modelname And b.[Type] = ''''Time''''

	Create table #time (Label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	Create table #existing (fix Nvarchar(1) COLLATE SQL_Latin1_General_CP1_CI_AS) ' 

			SET @SQLStatement = @SQLStatement + '


	Create table #tempI (ID INT)
	Create table #tempS (ID INT identity(1,1),Label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	Create table #tempN (Label Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	INSERT INTO #TempS Select Schedule_Template From Canvas_Workflow_Schedule
	SET @Maxs = @@Rowcount
	SET @Lap = 1
	While @Lap <= @maxs
	BEGIN
		Select @Schedule = Label From #tempS Where ID = @Lap
		TRuncate table #TempN
		SET @Sql = ''''INSERT INTO #TempN Select Label From WorkbookLibrary Where label Like ''''''''%Workflow\''''+@Schedule+''''%'''''''' ''''
		EXEC(@Sql)
		IF @@Rowcount = 0 Delete from canvas_Workflow_Schedule Where Schedule_Template = @Schedule	And Model = @ModelName
		SET  @Lap = @Lap + 1 
	END

	SELECT @WinUserName = WinUser FROM dbo.Canvas_Users WHERE label = @Username
	IF @@ROWCOUNT = 0 
	BEGIN
		SET @WinuserName = @Username
		SELECT @UserName = label FROM dbo.Canvas_Users WHERE WinUser = @WinUsername
	END

	SELECT @Proc_ID = MAX(Proc_Id) FROM Canvas_User_Run_Status
	IF @Proc_ID IS NULL  SET @Proc_ID = 0
	SET @Proc_ID = @Proc_Id + 1
	declare @userid int
	Select @Userid =  UserId from Canvas_Users Where label = @username
	
	INSERT INTO Canvas_User_Run_Status 
    ([User_RecordId],[User],[Proc_Id],[Proc_Name],[Begin_Date],[End_Date])
	VALUES (@Userid,@UserName,@Proc_Id,''''GenerateWorkFlow'''',GETDATE(),'''''''') 
	
	SELECT @Scenario = Scenario FROM dbo.Canvas_Workflow_ReForecast WHERE Active = ''''True'''' And Model = @ModelName

	SELECT @Time = DefaultValue FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Time'''' And Model = @ModelName
	SELECT @ScenarioName = Dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Scenario'''' And Model = @ModelName
	SELECT @TimeName = Dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Time'''' And Model = @ModelName

	if not exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = /*$*/''''Canvas_Workflow_HideDetail''''/*$*/)  
	BEGIN
		CREATE TABLE [dbo].[Canvas_Workflow_HideDetail](
		[RecordId] [bigint] IDENTITY(1,1) NOT NULL,
		[Model] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver1] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver2] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver3] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver4] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver5] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver6] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver7] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver8] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Schedule] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
		 CONSTRAINT [Canvas_Workflow_HideDetailn] PRIMARY KEY CLUSTERED 
		(
			[RecordId] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]
	END ' 

			SET @SQLStatement = @SQLStatement + '

	Else
	BEGIN
		if not exists(select b.name from sysobjects a,Syscolumns b Where a.id = b.id And b.name = ''''Model'''' and a.name = ''''Canvas_Workflow_HideDetail'''') 
		ALTER TABLE [Canvas_Workflow_HideDetail] ADD [Model] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

		if not exists(select b.name from sysobjects a,Syscolumns b Where a.id = b.id And b.name = ''''Schedule'''' and a.name = ''''Canvas_Workflow_HideDetail'''') 
		ALTER TABLE [Canvas_Workflow_HideDetail] ADD [Schedule] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	END

	if not exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = ''''Canvas_Workflow_StoreNames'''')
	BEGIN

		CREATE TABLE [dbo].[Canvas_Workflow_StoreNames](
		[RecordId] [bigint] IDENTITY(1,1) NOT NULL,
		[Model] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver1] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver2] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver3] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver4] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver5] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver6] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver7] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Driver8] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Schedule] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Responsible] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Approver] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Administrator] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

		 CONSTRAINT [Canvas_Workflow_StoreNamesn] PRIMARY KEY CLUSTERED 
		(
			[RecordId] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
		) ON [PRIMARY]

	END  ' 


			SET @SQLStatement = @SQLStatement + '

	ELSE
	BEGIN
		if not exists(select b.name from sysobjects a,Syscolumns b Where a.id = b.id And b.name = ''''Model'''' and a.name = ''''Canvas_Workflow_StoreNames'''') 
		ALTER TABLE [Canvas_Workflow_StoreNames] ADD [Model] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	END


	CREATE TABLE #Temp (Driver_Number INT,Driver NVARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS)
	INSERT INTO #Temp SELECT Driver_Number,Dimension FROM dbo.Canvas_WorkFlow_Segment WHERE Segment_Type = ''''Segment_Driver''''  And Model = @ModelName ORDER BY 1
	SET @maxDriver = @@ROWCOUNT
	SET @lap = 1 ' 

			SET @SQLStatement = @SQLStatement + '


	SET @FROM = '''' FROM Canvas_Workflow_Schedule a,Canvas_WorkFlow_Driver1 b''''
	SET @WHERE = '''' WHERE b.[Responsible] <> '''''''''''''''' 
	And b.Model = ''''''''''''+@ModelName+'''''''''''' 
	And a.Model = b.Model '''' 
	SET @Select = '''' SELECT ''''''''''''+@ModelName+'''''''''''',''''''''''''+@Scenario+'''''''''''',''''''''''''+@Time+'''''''''''' 
	,b.[Responsible],b.[Approver],b.[Administrator],a.Submission_Date,a.Approval_date,a.Label,'''''''''''''''',a.Active,a.Excel_Tab ''''  
	SET @SelectDISTINCT = '''' SELECT DISTINCT ''''''''Y'''''''',''''

 	SET @UPDATEShow = ''''  ''''
	SET @UPDATEHIDE = '''' SET active = ''''''''False'''''''', Sortorder = 2 FROM Canvas_WorkFlow_Detail a, Canvas_Workflow_HideDetail b WHERE ''''
	SET @UPDATEName = '''' SET responsible = b.responsible,Approver = b.approver,Administrator = b.Administrator 
	FROM Canvas_WorkFlow_Detail a, Canvas_Workflow_StoreNames b WHERE ''''
	SET @UPDATE = '''' SET WorkFlow_Description = ''''
	SET @ALTER = '''' ALTER TABLE Canvas_Workflow_Detail ADD ''''
	SET @ALTER2 = '''' ALTER TABLE #Existing ADD ''''
	SET @VALUES = ''''[Model],[Scenario],[Time],[Responsible],[Approver],[Administrator],[Submission_Date],[Approval_Date],[Schedule],[WorkFlow_Description],[Active],[Excel_Tab]''''
	SET @SelectAll = ''''Schedule''''
	SET @SelectAllDriver = ''''Schedule''''
	SET @AND_Hide = '''' ''''
	
	SET @NBEXIST = 0
	WHILE @lap <= @MaxDriver
	BEGIN
		SET @exist = 0
		SELECT @Driver = Dimension FROM Canvas_Workflow_Segment WHERE Driver_number = @lap  And Model = @ModelName
		SELECT @Default = DefaultValue FROM Canvas_Workflow_Segment WHERE Driver_number = @lap  And Model = @ModelName

		if exists(select b.name FROM dbo.sysobjects a,syscolumns b WITH (NOLOCK) 
			where a.id = b.id and a.name = ''''Canvas_WorkFlow_Detail'''' and b.name = @Driver)  
		BEGIN	
			Set @exist = 1
			Set @NBexist = @NBEXIST + 1
		END
		IF @Lap = 1 
		BEGIN
			SET @Driver_1 = @Driver
			SET @UPDATE = @UPDATE + ''''['''' + @Driver + '''']''''
			IF @Exist = 0 SET @ALTER = @ALTER + '''',['''' +@Driver + ''''] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS''''
			SET @ALTER2 = @ALTER2 + ''''['''' + @Driver + ''''] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS''''
			SET @SELECT = @SELECT + '''',b.Driver1''''
			SET @SELECTDISTINCT  = @SELECTDISTINCT +''''a.[''''+@Driver+'''']''''
			SET @UPDATEHIDE = @UPDATEHIDE + '''' a.[''''+@Driver +''''] = b.Driver1 ''''
			SET @UPDATEName = @UPDATEName + '''' a.[''''+@Driver +''''] = b.Driver1 ''''
			SET @UPDATEShow = @UPDATEShow + '''' a.[''''+@Driver +''''] = b.[''''+@Driver +'''']''''
			SET @AND_Hide = @AND_Hide + ''''['''' + @Driver +'''']''''
		END
		ELSE
		BEGIN
			SET @UPDATE = @UPDATE + '''' + '''''''' - '''''''' + [''''+@Driver+'''']''''
			IF @Exist = 0 
			BEGIN
				SET @ALTER = @ALTER + '''',['''' + @Driver + ''''] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS''''
				--IF @NBEXIST = 1 SET @ALTER = @ALTER + '''',['''' + @Driver + ''''] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS''''
				--IF @NBEXIST > 1  SET @ALTER = @ALTER + '''',['''' +@Driver + ''''] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS''''
			END
			SET @ALTER2 = @ALTER2 + '''',['''' +@Driver + ''''] Nvarchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS''''
			SET @SELECT = @SELECT + '''',[DS_''''+@Driver+''''].Label''''
			SET @SELECTDISTINCT  = @SELECTDISTINCT + '''',a.['''' + @Driver + '''']''''
			SET @FROM = @FROM + '''',[DS_''''+@Driver+'''']''''
			SET @UPDATEHIDE = @UPDATEHIDE + '''' 
			AND  a.[''''+@Driver +''''] = b.Driver''''+LTRIM(RTRIM(CAST(@Lap as char)))
			SET @UPDATEName = @UPDATEName + '''' 
			AND  a.[''''+@Driver +''''] = b.Driver''''+LTRIM(RTRIM(CAST(@Lap as char)))
			SET @UPDATEshow = @UPDATEshow + '''' 
			,  a.[''''+@Driver +''''] = b.[''''+@Driver+'''']''''
			SET @AND_Hide = @AND_Hide + ''''+''''''''|''''''''+[''''+@Driver+'''']''''
		END ' 

			SET @SQLStatement = @SQLStatement + '


		SET @VALUES = @VALUES + '''',[''''+@Driver+'''']''''
		SET @SelectAllDriver = @SelectAllDriver + '''',[''''+@Driver+'''']''''
		SET @SelectAll = @Selectall + '''',Driver''''+LTRIM(RTRIM(CAST(@Lap as char)))

		IF @Default = '''''''' 
		BEGIN
			IF @Lap = 1 
			BEGIN
				SET @WHERE = @Where + '''' 
				AND b.Driver1_memberid NOT IN (SELECT parentid FROM [hc_''''+@Driver+''''] WHERE ParentId <> memberid) 
				AND b.Driver1_Memberid > 0 ''''
			END
			ELSE
			BEGIN
				SET @WHERE = @Where + '''' 
				AND [DS_''''+@Driver+''''].memberid NOT IN (SELECT parentid FROM [hc_''''+@Driver+''''] WHERE ParentId <> memberid) ''''
--				AND DS_''''+@Driver+''''.memberid > 0 ''''
			END
		END
		ELSE
		BEGIN	
			SET @WHERE = @Where + '''' 
			AND [DS_''''+@Driver+''''].Label = ''''''''''''+@Default+''''''''''''''''
		END

		SET @Lap = @Lap + 1
	END

	SET @WHERE = @WHERE + ''''	AND a.Active = 1 ''''

	SET @ALTER = REPLACE(@ALTER,''''ADD ,'''',''''ADD '''')

	if exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = /*$*/''''Canvas_WorkFlow_Detail''''/*$*/)  
	BEGIN
		if not exists(select b.name from sysobjects a,Syscolumns b Where a.id = b.id And b.name = ''''Model'''' and a.Name = ''''Canvas_WorkFlow_Detail'''') 
		BEGIN
			ALTER TABLE [dbo].[Canvas_Workflow_Detail] ADD Model  [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
		END
		SET @Sql = ''''Delete from  dbo.Canvas_WorkFlow_Detail where model = ''''''''''''+@ModelName+'''''''''''' ''''
		EXEC(@Sql)

		IF @ALTER <> '''' ALTER TABLE Canvas_Workflow_Detail ADD '''' EXEC (@ALTER)
	
	END
	ELSE ' 

			SET @SQLStatement = @SQLStatement + '

	BEGIN


		SET @Sql = ''''CREATE TABLE [dbo].[Canvas_Workflow_Detail](
		[RecordId] [bigint] IDENTITY(1,1) NOT NULL,
		[SortOrder] [bigint] NOT NULL,
		[Model] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Scenario] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Time] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Responsible] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Approver] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Administrator] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Submission_Date] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Approval_Date] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Schedule] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[WorkFlow_Description] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[Active] [bit] NULL,
		[Excel_Tab] [bit] NULL,
		[StartPeriod] [INT] NULL,
		[ReForecast_Number] [INT] NULL,

			CONSTRAINT [PK_Canvas_Workflow_Detail] PRIMARY KEY CLUSTERED 
		(
			[RecordId] ASC
		)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
		) ON [PRIMARY] 

		ALTER TABLE [dbo].[Canvas_Workflow_Detail] ADD  CONSTRAINT [DF_Canvas_Workflow_Detail_SortOrder]  DEFAULT ((1)) FOR [SortOrder] ''''
		--Print(@Sql)
		EXEC(@Sql)

	--Print (@ALTER)
	EXEC (@ALTER)
	END

	if exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = /*$*/''''Canvas_WorkFlow''''/*$*/)  
	BEGIn
		Delete FROM Canvas_Workflow where model = @ModelName
	END

--	SET @ALTER = REPLACE(@ALTER,''''Canvas_Workflow_Detail'''',''''#Existing'''')
	EXEC (@ALTER2)

	Select * into #Missing from #Existing

	SET @Sql =  ''''INSERT INTO Canvas_Workflow_Detail ('''' + @ValueS+'''')
	'''' + @Select
	SET @Sql = @Sql + '''' 
	''''+@From
	SET @Sql = @Sql + '''' 
	''''+@Where
	--print (@sql)
	EXEC (@sql) ' 

			SET @SQLStatement = @SQLStatement + '


	SET @Sql = ''''UPDATE Canvas_WorkFlow_Detail ''''+@UPDATE + ''''+'''''''' - '''''''''''' + '''' + Schedule WHERE Model = ''''''''''''+@ModelName+''''''''''''''''
	--PRINT(@Sql)
	EXEC(@Sql)

	SET @Sql = ''''UPDATE Canvas_WorkFlow_Detail ''''+@UPDATEHIDE +'''' And a.Schedule = b.Schedule AND a.Model = ''''''''''''+@ModelName+'''''''''''' And a.Model = b.Model''''
	--PRINT(@Sql)
	EXEC(@Sql)

	SET @Sql = ''''UPDATE Canvas_WorkFlow_Detail ''''+@UPDATENAME +'''' And a.Schedule = b.Schedule AND a.Model = ''''''''''''+@ModelName+'''''''''''' And a.Model = b.Model ''''
	--PRINT(@Sql)
	EXEC(@Sql)


	DECLARE @StartPeriod INT,@Reforecast_Number INT

	Select @Reforecast_Number = ReforeCast_Number from Canvas_Workflow_Reforecast Where  Active = ''''True'''' And Model = @ModelName

	truncate table #tempI
	SET @Sql = ''''Insert Into #tempI Select Substring(b.Label,5,2) From DS_''''+@TimeDim+'''' b, Canvas_Workflow_Reforecast a
	Where  a.Active = ''''''''True'''''''' and a.StartPeriod = b.Label  And a.Model = ''''''''''''+@ModelName+'''''''''''' ''''
	--Print(@Sql)
	EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '

	Select @StartPeriod = ID From #TempI

	Select @Year = LEFT(StartPeriod,4) From Canvas_Workflow_Reforecast Where  Active = ''''True'''' And Model = @ModelName
	
	SET @Sql = ''''Insert into #time select Label from ds_''''+@timedim+'''' Where left(label,4) = ''''''''''''+@Year+''''''''''''
	And memberid not in (select parentid from HC_''''+@timeDim+ '''' Where Memberid <> PArentId)''''
	exec(@sql)
	
	set @sql = ''''insert into #existing ''''+@SelectDISTINCT + '''' from Fact_''''+@ModelName + ''''_View a ''''
	--Where a.[''''+@Timedim+''''] in (Select Label from #time)''''
	--Print(@sql)
	EXEC(@sql)

	Set @sql =''''insert into #Missing ''''+REPLACE(@SelectDistinct,''''''''''''Y'''''''','''',''''b.fix,'''')+'''' From Canvas_Workflow_Detail a
	left outer join #existing as [b] on ''''+Replace (@UPDATEShow,'''','''','''' AND '''')
	EXEC(@sql)
	--Print(@sql)
		
	Set @sql =  ''''Update canvas_workflow_detail set active = 0, Sortorder = 2 
	From canvas_workflow_detail a, #Missing b 
	Where '''' +Replace (@UPDATEShow,'''','''','''' AND '''')+'''' and b.fix IS NULL And a.model = ''''''''''''+@ModelName+'''''''''''' ''''
	EXEC (@sql)
	--print (@sql)

	SET @Sql = ''''Update canvas_Workflow_detail set active = 1 Where Active = 0 and sortorder = 1  and Model = ''''''''''''+@ModelName+'''''''''''' ''''
	EXEC(@sql)
	SET @Sql = ''''Update canvas_Workflow_detail set sortorder = 0 where active = 1  and Model = ''''''''''''+@ModelName+'''''''''''' ''''
	EXEC(@sql)

	SET @Sql = ''''Update Canvas_WorkFlow_Detail Set StartPeriod = ''''+LTRIM(RTRIM(CAST(@StartPeriod as char)))+''''  WHERE Model = ''''''''''''+@ModelName+'''''''''''' ''''
	EXEC(@sql)
	SET @Sql = ''''Update Canvas_WorkFlow_Detail Set Reforecast_Number = ''''+LTRIM(RTRIM(CAST(@Reforecast_Number as char)))+''''  WHERE Model = ''''''''''''+@ModelName+'''''''''''' ''''
	EXEC(@sql)

	if exists(select name FROM dbo.sysobjects WITH (NOLOCK) where name = /*$*/''''DS_FullAccount''''/*$*/)  
	BEGIN
		SET @SelectHide = REPLACE(@SelectAllDriver,''''Schedule,'''','''''''')
		SET @SelectHide = REPLACE(@SelectHide,'''','''',''''+'''')
		SET @Sql = ''''UPDATE  Canvas_WorkFlow_Detail SET active = 0 WHERE Active = 1 and ''''+@SelectHide +'''' Not in (Select ''''+ @SelectHide+ '''' From DS_FullAccount) and Model = ''''''''''''+@ModelName+'''''''''''' ''''
		--Print(@Sql)
		EXEC(@Sql)
	END

	SET @Sql = ''''INSERT INTO Canvas_Workflow_HideDetail 
				(''''+@Selectall+'''') Select ''''+@SelectAllDriver+'''' From Canvas_workflow_detail Where Active = ''''''''False'''''''' 
				AND ''''+@AND_Hide+ '''' Not in (Select ''''+@AND_Hide + '''' From Canvas_Workflow_HideDetail)  and Model = ''''''''''''+@ModelName+'''''''''''' ''''
	--Print (@Sql)
	Exec(@Sql)

	UPDATE Canvas_User_Run_Status SET END_Date = GETDATE() WHERE Proc_Id = @Proc_Id

	
END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

-- DROP TABLE #time,#existing,#tempI,#tempS,#tempN,#temp,#missing


/****** Object:  StoredProcedure [dbo].[Canvas_Util_Reprocess]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Util_Reprocess'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Util_Reprocess') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Util_Reprocess]
	@ModelName as nvarchar(255) = ''''''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS

--DECLARE	@ModelName as nvarchar(255) 
--SET @Modelname = ''''Legal''''


BEGIN
DECLARE	@User as nvarchar(255) 

--select * into #temp_parametervalues From HCHCVALUES 


	Select @user = Stringvalue From #temp_parametervalues Where ParameterName = ''''UserId''''
	Select @ModelName = Stringvalue From #temp_parametervalues Where ParameterName = ''''Model''''



END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

-- drop table #fact,#fact_text,#Fact_Detail_text,#Fact_Detail,#temp,#businessprocess,#time,#time2,#tempN,#timebudget,#account



/****** Object:  StoredProcedure [dbo].[Canvas_Util_WorkFlowCopyCurrentVersion]    Script Date: 3/2/2017 11:34:03 AM ******/

SET @Step = 'Create Canvas_Util_WorkFlowCopyCurrentVersion'

			IF (SELECT COUNT(1) FROM #Object WHERE ObjectType = 'Procedure' AND ObjectName = 'Canvas_Util_WorkFlowCopyCurrentVersion') = 0 SET @Action = 'CREATE ' ELSE SET @Action = 'ALTER '

SET @SQLStatement = @Action + '  
  PROCEDURE  [dbo].[Canvas_Util_WorkFlowCopyCurrentVersion]
	@FinalVersion AS Bit =''''False''''
' + CASE WHEN @ENCRYPTION = 42 THEN '--#--#WITH ENCRYPTION#--#--' ELSE '--#WITH ENCRYPTION#--' END + '
AS
BEGIN

--declare @finalversion as bit
--Set @finalversion = ''''False''''

	DECLARE @D1 BIGINT	,@D2 BIGINT	,@D3 BIGINT	,@D4 BIGINT	,@D5 BIGINT	,@D6 BIGINT	,@D7 BIGINT	,@D8 BIGINT
	,@D1Label Nvarchar(250)	,@D2Label Nvarchar(250)	,@D3Label Nvarchar(250)	,@D4Label Nvarchar(250)	,@D5Label Nvarchar(250)	,@D6Label Nvarchar(250)	,@D7Label Nvarchar(250)	,@D8Label Nvarchar(250)
	,@Cost_Center BIGINT,@Scenario BIGINT,@Time BIGINT,@Version BIGINT,@SourceVersion BIGINT,@username NVARCHAR(255)
	,@model NVARCHAR(100), @MaxDriver as INT, @MaxVersion as Nvarchar(250),@sql nvarchar(max),@Lap INT,@Sep Nvarchar(2),@DimType Nvarchar(50),@DimLabel Nvarchar(50)
	,@ScenarioDim Nvarchar(50),@TimeDim Nvarchar(50),@VersionDim Nvarchar(50),@Alldim Nvarchar(MAx),@AlldimList Nvarchar(MAx),@found INT

	--	select * into testparam From  #temp_Parametervalues   
	--select * into #temp_Parametervalues from testparam 

	Select @Model = StringValue From #temp_Parametervalues Where ParameterName = ''''Model''''


	DECLARE @FactText BIT,@FactDetail Bit,@FactDetailText Bit
	SET @FactText = 0
	SET @FactDetail = 0
	SET @FactDetailText = 0
	IF EXISTS(select name FROM dbo.sysobjects WITH (NOLOCK) where name =''''FACT_''''+@Model+''''_Text'''' And xtype = ''''U'''')  SET @FactText = 1
	IF EXISTS(select name FROM dbo.sysobjects WITH (NOLOCK) where name =''''FACT_''''+@Model+''''_Detail'''' And xtype = ''''U'''')  SET @FactDetail = 1
	IF EXISTS(select name FROM dbo.sysobjects WITH (NOLOCK) where name =''''FACT_''''+@Model+''''_Detail_Text'''' And xtype = ''''U'''')  SET @FactDetailtext = 1

	SET @Alldim = ''''''''
	SET @Sep = ''''[''''
	SEt @Lap = 1
	Declare Dim_cursor cursor for select A.[Dimension],B.[Type] from [ModelDimensions] as A left join [Dimensions] as B on A.[Dimension]=B.[Label] 
	where A.[Model] = @Model And b.[Type] <> ''''TimeDataView'''' ORDER BY a.Dimension
	open Dim_cursor
	fetch next from Dim_cursor into @DimLabel,@DimType
	while @@FETCH_STATUS = 0
	begin
		SEt @Found = 0
		If @Lap > 1 SET @Sep ='''',[''''
		if @DimType = ''''Scenario''''
		begin
			set @ScenarioDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		end
		if @DimType = ''''Time''''
		begin
			set @TimeDim = RTRIM(@DimLabel)
			SET @AllDim = @AllDim + @Sep + RTRIM(@DimLabel)+'''']''''
			set @Found = 1
		end
		if @Found = 0
		begin
			set @AllDim = @AllDim +@Sep + RTRIM(@DimLabel)+'''']''''
		end
		Set @Lap = @Lap + 1  
		fetch next from Dim_cursor into @DimLabel,@DimType
	end
	close Dim_cursor
	deallocate Dim_cursor

	Create table #temp (Value Float)

	SET @Sql = ''''Alter Table #temp ADD ''''+REPLACE(@AllDim,'''']'''',''''_Memberid] BIgint'''')
	EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '

	Alter table #temp add TimeDataView_Memberid Bigint

	Select @MaxDriver = MAX(Driver_Number) from Canvas_Workflow_Segment WHERE Model = @model
	
	SELECT @Username = StringValue FROM #Temp_ParameterValues  WHERE parameterName = ''''UserId''''
	
	SELECT	@D1 = MemberId FROM #Temp_ParameterValues WHERE parameterName = ''''Driver1''''


	IF @MAxDriver > 1 SELECT @D2 = MemberId FROM #Temp_ParameterValues WHERE parameterName = ''''Driver2''''
	IF @MAxDriver > 2 SELECT @D3 = MemberId FROM #Temp_ParameterValues WHERE parameterName = ''''Driver3''''
	IF @MAxDriver > 3 SELECT @D4 = MemberId FROM #Temp_ParameterValues WHERE parameterName = ''''Driver4''''
	IF @MAxDriver > 4 SELECT @D5 = MemberId FROM #Temp_ParameterValues WHERE parameterName = ''''Driver5''''
	IF @MAxDriver > 5 SELECT @D6 = MemberId FROM #Temp_ParameterValues WHERE parameterName = ''''Driver6''''
	IF @MAxDriver > 6 SELECT @D7 = MemberId FROM #Temp_ParameterValues WHERE parameterName = ''''Driver7''''
	IF @MAxDriver > 7 SELECT @D8 = MemberId FROM #Temp_ParameterValues WHERE parameterName = ''''Driver8''''

	--SELECT @Time = MemberId FROM #Temp_ParameterValues WHERE parameterName IN (''''Time'''')
	SELECT @Scenario = MemberId FROM #Temp_ParameterValues WHERE parameterName = ''''ScenarioMbrs''''
	CREATE TABLE #Time (Memberid Bigint)

	Declare @Year INT, @params nvarchar(1000)

	set @Params = ''''@YearOUT nvarchar(20) OUTPUT''''
	set @SQL = ''''select @YearOUT=b.Memberid  From Canvas_Workflow_Segment a,DS_TIME b Where a.DefaultValue = b.Label and a.Dimension = ''''''''''''+@TimeDim+'''''''''''' And a.Model = ''''''''''''+@Model+''''''''''''''''
	exec sp_executesql @sql, @Params, @YearOUT=@Year OUTPUT

	SET @Sql = ''''INSERT INTO #Time 
	Select Distinct MemberId FROM HC_''''+@TimeDim+'''' WHERE ParentId = ''''+CAST(@Year as char)
	EXEC(@Sql)
	
	--If 	@FinalVersion =''''False'''' 
	--begin

		Declare @D1Name as Nvarchar(50),@D2Name as Nvarchar(50),@D3Name as Nvarchar(50),@D4Name as Nvarchar(50)
		,@D5Name as Nvarchar(50),@D6Name as Nvarchar(50),@D7Name as Nvarchar(50),@D8Name as Nvarchar(50)
		
		Create table #templabel (Label Nvarchar(250))
	
		Select @D1Name = Dimension from Canvas_Workflow_Segment Where Driver_Number = 1 And Model = @Model
		SET @Sql = ''''INsert into #tempLabel Select Label from DS_''''+@D1Name+'''' Where Memberid = ''''+Cast(@D1 as char)
		EXEC(@Sql)

		Select @D1Label = label from #tempLabel
		If @MaxDriver > 1 
		BEGIN
			Select @D2Name = Dimension from Canvas_Workflow_Segment Where Driver_Number = 2 And Model = @Model
			Truncate table #tempLabel
			SET @Sql = ''''INsert into #tempLabel Select Label from DS_''''+@D2Name+'''' Where Memberid = ''''+Cast(@D2 as char)
			EXEC(@Sql)
			Select @D2Label = label from #tempLabel
		END
		If @MaxDriver > 2 
		BEGIN
			Select @D3Name = Dimension from Canvas_Workflow_Segment Where Driver_Number = 3 And Model = @Model
			Truncate table #tempLabel
			SET @Sql = ''''INsert into #tempLabel Select Label from DS_''''+@D3Name+'''' Where Memberid = ''''+Cast(@D3 as char)
			EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '

			Select @D3Label = label from #tempLabel
		END
		If @MaxDriver > 3 
		BEGIN
			Select @D4Name = Dimension from Canvas_Workflow_Segment Where Driver_Number = 4 And Model = @Model
			Truncate table #tempLabel
			SET @Sql = ''''INsert into #tempLabel Select Label from DS_''''+@D4Name+'''' Where Memberid = ''''+Cast(@D4 as char)
			EXEC(@Sql)
			Select @D4Label = label from #tempLabel
		END
		If @MaxDriver > 4 
		BEGIN
			Select @D5Name = Dimension from Canvas_Workflow_Segment Where Driver_Number = 5 And Model = @Model
			Truncate table #tempLabel
			SET @Sql = ''''INsert into #tempLabel Select Label from DS_''''+@D5Name+'''' Where Memberid = ''''+Cast(@D5 as char)
			EXEC(@Sql)
			Select @D5Label = label from #tempLabel
		END
		If @MaxDriver > 5 
		BEGIN
			Select @D6Name = Dimension from Canvas_Workflow_Segment Where Driver_Number = 6 And Model = @Model
			Truncate table #tempLabel
			SET @Sql = ''''INsert into #tempLabel Select Label from DS_''''+@D6Name+'''' Where Memberid = ''''+Cast(@D6 as char)
			EXEC(@Sql)
			Select @D6Label = label from #tempLabel
		END
		If @MaxDriver > 6 
		BEGIN
			Select @D7Name = Dimension from Canvas_Workflow_Segment Where Driver_Number = 7 And Model = @Model
			Truncate table #tempLabel
			SET @Sql = ''''INsert into #tempLabel Select Label from DS_''''+@D7Name+'''' Where Memberid = ''''+Cast(@D7 as char)
			EXEC(@Sql)
			Select @D7Label = label from #tempLabel
		END
		If @MaxDriver > 7 
		BEGIN
			Select @D8Name = Dimension from Canvas_Workflow_Segment Where Driver_Number = 8 And Model = @Model
			Truncate table #tempLabel
			SET @Sql = ''''INsert into #tempLabel Select Label from DS_''''+@D8Name+'''' Where Memberid = ''''+Cast(@D8 as char)
			EXEC(@Sql)
			Select @D8Label = label from #tempLabel
		END
		
		Truncate table #tempLabel
		Set @Sql = ''''INSERT INTO #Templabel
		Select Max(a.[Version]) From Canvas_Workflow a, Canvas_Workflow_Detail b 
		Where a.Workflow_Detail_recordId = b.recordid 
		And a.Model = +''''''''''''+@model+'''''''''''' 
		and a.model = b.model 
		And b.[''''+@D1Name+''''] = ''''''''''''+@D1Label+'''''''''''' ''''
		IF @MaxDriver > 1 SET @Sql = @Sql + '''' And b.[''''+@D2Name+''''] = ''''''''''''+@D2Label+''''''''''''''''
		IF @MaxDriver > 2 SET @Sql = @Sql + '''' And b.[''''+@D3Name+''''] = ''''''''''''+@D3Label+''''''''''''''''
		IF @MaxDriver > 3 SET @Sql = @Sql + '''' And b.[''''+@D4Name+''''] = ''''''''''''+@D4Label+'''''''''''''''' ' 

			SET @SQLStatement = @SQLStatement + '

		IF @MaxDriver > 4 SET @Sql = @Sql + '''' And b.[''''+@D5Name+''''] = ''''''''''''+@D5Label+''''''''''''''''
		IF @MaxDriver > 5 SET @Sql = @Sql + '''' And b.[''''+@D6Name+''''] = ''''''''''''+@D6Label+''''''''''''''''
		IF @MaxDriver > 6 SET @Sql = @Sql + '''' And b.[''''+@D7Name+''''] = ''''''''''''+@D7Label+''''''''''''''''
		IF @MaxDriver > 7 SET @Sql = @Sql + '''' And b.[''''+@D8Name+''''] = ''''''''''''+@D8Label+''''''''''''''''
		Print(@Sql)
		EXEC(@Sql)

		Select @MaxVersion = Label From #tempLabel
		
			
		IF CAST(Right (@MaxVersion,2) as INT) > 10
		BEGIN
			Select @Version = memberid from DS_Version Where Label = ''''V'''' + CAST(CAST(Right (@MaxVersion,2) as INT) - 1  as char)
		END
		ELSE
		BEGIN
			Select @Version = memberid from DS_Version Where Label = ''''V0'''' + CAST(CAST(Right (@MaxVersion,2) as INT) - 1  as char)
		END 

		Set @SourceVersion = -1 

	--END ' 

			SET @SQLStatement = @SQLStatement + '

	If @version <> -1
	BEGIN
		SET @Sql = ''''DELETE FROM dbo.FACT_''''+@Model+''''_default_partition WHERE 
		[''''+@ScenarioDim+''''_MemberId] = ''''+CAst(@Scenario as char)+'''' 
		AND [''''+@TimeDim+''''_MemberId] IN (SELECT MemberId FROM #Time) 
		AND [Version_memberid] = ''''+CASt(@Version as Char)
		If @D1Name = ''''Entity'''' 
		BEGIN
			Set @Sql = @sql + '''' AND [''''+@D1Name+''''_MemberId] IN (''''+CAST(@D1 as Char)+'''',-1)'''' 
		END
		ELSE
		BEGIN
			Set @Sql = @Sql + '''' AND [''''+@D1Name+''''_MemberId] = ''''+CAST(@D1 as Char) 
		END
		IF @MaxDriver > 1 SET @Sql = @Sql +'''' AND [''''+@D2Name+''''_MemberId] = ''''+CAST(@D2 as Char) 
		IF @MaxDriver > 2 SET @Sql = @Sql +'''' AND [''''+@D3Name+''''_MemberId] = ''''+CAST(@D3 as Char) 
		IF @MaxDriver > 3 SET @Sql = @Sql +'''' AND [''''+@D4Name+''''_MemberId] = ''''+CAST(@D4 as Char) 
		IF @MaxDriver > 4 SET @Sql = @Sql +'''' AND [''''+@D5Name+''''_MemberId] = ''''+CAST(@D5 as Char) 
		IF @MaxDriver > 5 SET @Sql = @Sql +'''' AND [''''+@D6Name+''''_MemberId] = ''''+CAST(@D6 as Char) 
		IF @MaxDriver > 6 SET @Sql = @Sql +'''' AND [''''+@D7Name+''''_MemberId] = ''''+CAST(@D7 as Char) 
		IF @MaxDriver > 7 SET @Sql = @Sql +'''' AND [''''+@D8Name+''''_MemberId] = ''''+CAST(@D8 as Char) 
		EXEC(@Sql)
	END ' 

			SET @SQLStatement = @SQLStatement + '

	
	SET @AllDimList = REPLACE(@AllDim,'''']'''',''''_Memberid]'''')
	SET @AllDim = REPLACE(@AllDimList,''''[version_Memberid]'''',CAST(@Version as char))
-- ============================================> FACT
	SET @Sql = ''''INSERT INTO dbo.[FACT_''''+@model+''''_default_partition]  
	(''''+@Model+''''_Value,''''+@AllDimList+'''',TimeDataView_Memberid,Userid,Changedatetime)
	Select ''''+@Model+''''_Value,''''+@AllDim +'''',TimeDataView_Memberid,''''''''''''+@UserName+'''''''''''',GETDATE() 
	FROM dbo.FACT_''''+@Model+''''_default_partition 
	WHERE [''''+@ScenarioDim+''''_MemberId] = ''''+CAst(@Scenario as char)+'''' 
	AND [''''+@TimeDim+''''_MemberId] IN (SELECT MemberId FROM #Time) 
	AND [Version_memberid] = ''''+CASt(@SourceVersion as Char)
	If @D1Name = ''''Entity'''' 
	BEGIN
		Set @Sql = @sql + '''' AND [''''+@D1Name+''''_MemberId] IN (''''+CAST(@D1 as Char)+'''',-1)'''' 
	END
	ELSE
	BEGIN
		Set @Sql = @Sql + '''' AND [''''+@D1Name+''''_MemberId] = ''''+CAST(@D1 as Char) 
	END
	IF @MaxDriver > 1 SET @Sql = @Sql +'''' AND [''''+@D2Name+''''_MemberId] = ''''+CAST(@D2 as Char) 
	IF @MaxDriver > 2 SET @Sql = @Sql +'''' AND [''''+@D3Name+''''_MemberId] = ''''+CAST(@D3 as Char) 
	IF @MaxDriver > 3 SET @Sql = @Sql +'''' AND [''''+@D4Name+''''_MemberId] = ''''+CAST(@D4 as Char) 
	IF @MaxDriver > 4 SET @Sql = @Sql +'''' AND [''''+@D5Name+''''_MemberId] = ''''+CAST(@D5 as Char) 
	IF @MaxDriver > 5 SET @Sql = @Sql +'''' AND [''''+@D6Name+''''_MemberId] = ''''+CAST(@D6 as Char) 
	IF @MaxDriver > 6 SET @Sql = @Sql +'''' AND [''''+@D7Name+''''_MemberId] = ''''+CAST(@D7 as Char) 
	IF @MaxDriver > 7 SET @Sql = @Sql +'''' AND [''''+@D8Name+''''_MemberId] = ''''+CAST(@D8 as Char) 
--	Print(@Sql)
	EXEC(@Sql) ' 

			SET @SQLStatement = @SQLStatement + '

-- ============================================> FACT TEXT
	IF @FactText = 1
	BEGIN
		SET @Sql = ''''INSERT INTO dbo.[FACT_''''+@model+''''_Text]  
		(''''+@Model+''''_Text,''''+@AllDimList+'''',TimeDataView_Memberid,Userid,Changedatetime)
		Select ''''+@Model+''''_Text,''''+@AllDim +'''',TimeDataView_Memberid,''''''''''''+@UserName+'''''''''''',GETDATE() 
		FROM dbo.FACT_''''+@Model+''''_Text 
		WHERE [''''+@ScenarioDim+''''_MemberId] = ''''+CAst(@Scenario as char)+'''' 
		AND [''''+@TimeDim+''''_MemberId] IN (SELECT MemberId FROM #Time) 
		AND [Version_memberid] = ''''+CASt(@SourceVersion as Char)
		If @D1Name = ''''Entity'''' 
		BEGIN
			Set @Sql = @sql + '''' AND [''''+@D1Name+''''_MemberId] IN (''''+CAST(@D1 as Char)+'''',-1)'''' 
		END
		ELSE
		BEGIN
			Set @Sql = @Sql + '''' AND [''''+@D1Name+''''_MemberId] = ''''+CAST(@D1 as Char) 
		END
		IF @MaxDriver > 1 SET @Sql = @Sql +'''' AND [''''+@D2Name+''''_MemberId] = ''''+CAST(@D2 as Char) 
		IF @MaxDriver > 2 SET @Sql = @Sql +'''' AND [''''+@D3Name+''''_MemberId] = ''''+CAST(@D3 as Char) 
		IF @MaxDriver > 3 SET @Sql = @Sql +'''' AND [''''+@D4Name+''''_MemberId] = ''''+CAST(@D4 as Char) 
		IF @MaxDriver > 4 SET @Sql = @Sql +'''' AND [''''+@D5Name+''''_MemberId] = ''''+CAST(@D5 as Char) 
		IF @MaxDriver > 5 SET @Sql = @Sql +'''' AND [''''+@D6Name+''''_MemberId] = ''''+CAST(@D6 as Char) 
		IF @MaxDriver > 6 SET @Sql = @Sql +'''' AND [''''+@D7Name+''''_MemberId] = ''''+CAST(@D7 as Char) 
		IF @MaxDriver > 7 SET @Sql = @Sql +'''' AND [''''+@D8Name+''''_MemberId] = ''''+CAST(@D8 as Char) 
	--	Print(@Sql)
		EXEC(@Sql)
	END	 ' 

			SET @SQLStatement = @SQLStatement + '

-- ============================================> FACT DETAIL
	IF @FactDetail = 1 
	BEGIn
		SET @Sql = ''''INSERT INTO dbo.[FACT_''''+@model+''''_Detail_default_partition]  
		(''''+@Model+''''_Detail_Value,''''+@AllDimList+'''',TimeDataView_Memberid,Lineitem_memberid,Userid,Changedatetime)
		Select ''''+@Model+''''_Detail_Value,''''+@AllDim +'''',TimeDataView_Memberid,LineItem_MemberId,''''''''''''+@UserName+'''''''''''',GETDATE() 
		FROM dbo.FACT_''''+@Model+''''_Detail_default_partition WHERE 
		[''''+@ScenarioDim+''''_MemberId] = ''''+CAst(@Scenario as char)+'''' 
		AND [''''+@TimeDim+''''_MemberId] IN (SELECT MemberId FROM #Time) 
		AND [Version_memberid] = ''''+CASt(@SourceVersion as Char)
		If @D1Name = ''''Entity'''' 
		BEGIN
			Set @Sql = @sql + '''' AND [''''+@D1Name+''''_MemberId] IN (''''+CAST(@D1 as Char)+'''',-1)'''' 
		END
		ELSE
		BEGIN
			Set @Sql = @Sql + '''' AND [''''+@D1Name+''''_MemberId] = ''''+CAST(@D1 as Char) 
		END
		IF @MaxDriver > 1 SET @Sql = @Sql +'''' AND [''''+@D2Name+''''_MemberId] = ''''+CAST(@D2 as Char) 
		IF @MaxDriver > 2 SET @Sql = @Sql +'''' AND [''''+@D3Name+''''_MemberId] = ''''+CAST(@D3 as Char) 
		IF @MaxDriver > 3 SET @Sql = @Sql +'''' AND [''''+@D4Name+''''_MemberId] = ''''+CAST(@D4 as Char) 
		IF @MaxDriver > 4 SET @Sql = @Sql +'''' AND [''''+@D5Name+''''_MemberId] = ''''+CAST(@D5 as Char) 
		IF @MaxDriver > 5 SET @Sql = @Sql +'''' AND [''''+@D6Name+''''_MemberId] = ''''+CAST(@D6 as Char) 
		IF @MaxDriver > 6 SET @Sql = @Sql +'''' AND [''''+@D7Name+''''_MemberId] = ''''+CAST(@D7 as Char) 
		IF @MaxDriver > 7 SET @Sql = @Sql +'''' AND [''''+@D8Name+''''_MemberId] = ''''+CAST(@D8 as Char) 
	--	Print(@Sql)
		EXEC(@Sql)
	END  ' 

			SET @SQLStatement = @SQLStatement + '

-- ============================================> FACT DETAIL_TEXT
	IF @FactDetailText = 1
	BEGIN
		SET @Sql = ''''INSERT INTO dbo.[FACT_''''+@model+''''_Detail_Text]  
		(''''+@Model+''''_Detail_Text,''''+@AllDimList+'''',TimeDataView_Memberid,Lineitem_memberid,Userid,Changedatetime)
		Select ''''+@Model+''''_Detail_Text,''''+@AllDim +'''',TimeDataView_Memberid,LineItem_memberid,''''''''''''+@UserName+'''''''''''',GETDATE()
		FROM dbo.FACT_''''+@Model+''''_Detail_Text WHERE 
		[''''+@ScenarioDim+''''_MemberId] = ''''+CAst(@Scenario as char)+'''' 
		AND [''''+@TimeDim+''''_MemberId] IN (SELECT MemberId FROM #Time) 
		AND [Version_memberid] = ''''+CASt(@SourceVersion as Char)
		If @D1Name = ''''Entity'''' 
		BEGIN
			Set @Sql = @sql + '''' AND [''''+@D1Name+''''_MemberId] IN (''''+CAST(@D1 as Char)+'''',-1)'''' 
		END
		ELSE
		BEGIN
			Set @Sql = @Sql + '''' AND [''''+@D1Name+''''_MemberId] = ''''+CAST(@D1 as Char) 
		END
		IF @MaxDriver > 1 SET @Sql = @Sql +'''' AND [''''+@D2Name+''''_MemberId] = ''''+CAST(@D2 as Char) 
		IF @MaxDriver > 2 SET @Sql = @Sql +'''' AND [''''+@D3Name+''''_MemberId] = ''''+CAST(@D3 as Char) 
		IF @MaxDriver > 3 SET @Sql = @Sql +'''' AND [''''+@D4Name+''''_MemberId] = ''''+CAST(@D4 as Char) 
		IF @MaxDriver > 4 SET @Sql = @Sql +'''' AND [''''+@D5Name+''''_MemberId] = ''''+CAST(@D5 as Char) 
		IF @MaxDriver > 5 SET @Sql = @Sql +'''' AND [''''+@D6Name+''''_MemberId] = ''''+CAST(@D6 as Char) 
		IF @MaxDriver > 6 SET @Sql = @Sql +'''' AND [''''+@D7Name+''''_MemberId] = ''''+CAST(@D7 as Char) 
		IF @MaxDriver > 7 SET @Sql = @Sql +'''' AND [''''+@D8Name+''''_MemberId] = ''''+CAST(@D8 as Char) 
	--	Print(@Sql)
		EXEC(@Sql)
	END
--		SET @Sql = ''''UPDATE #temp SET Version_MemberId = ''''+CAST(@Version as char) 
----		Print(@Sql)		
--		EXEC(@Sql)

		--SET @Sql =''''INSERT INTO dbo.[FACT_''''+@model+''''_default_partition] 
		--(''''+@Model+''''_Value,''''+REPLACE(@AllDim,'''']'''',''''_Memberid]'''')+'''',TimeDataView_Memberid,Userid,Changedatetime)
		--SELECT *,''''''''''''+@UserName+'''''''''''',GETDATE() FROM #temp ''''
		--Print(@Sql)
		--EXEC(@Sql)

END '
IF @Debug <> 0
                PRINT @SQLStatement 
ELSE 
                BEGIN
                            SET @SQLStatement = 'EXEC ' + @DestinationDatabase + '.dbo.sp_executesql N''' + @SQLStatement + ''''
                            EXEC (@SQLStatement)
                END

-- drop table #temp,#time,#templabel










--==========================================================================================================================================
--==========================================================================================================================================
--==========================================================================================================================================
            SET @Step = 'Set @Duration'          
                         SET @Duration = GetDate() - @StartTime

            SET @Step = 'Insert into JobLog'
                         INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), @Duration, @Deleted, @Inserted, @Updated, @Version
                                                                           
            RETURN 0

END TRY
BEGIN CATCH
            INSERT INTO JobLog (JobID, StartTime, ProcedureName, Duration, Deleted, Inserted, Updated, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorProcedure, ErrorStep, ErrorMessage, [Version]) SELECT @JobID, @StartTime, OBJECT_NAME(@@PROCID), GetDate() - @StartTime, @Deleted, @Inserted, @Updated, ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_PROCEDURE(), @Step, ERROR_MESSAGE(), @Version
            SET @JobLogID = @@IDENTITY
            SELECT @ErrorNumber = ErrorNumber FROM JobLog WHERE JobLogID = @JobLogID
            SELECT ErrorNumber, ErrorSeverity, ErrorState, ErrorProcedure, ErrorStep, ErrorLine, ErrorMessage FROM JobLog WHERE JobLogID = @JobLogID
            RETURN @ErrorNumber
END CATCH






GO
