SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[spGet_Version]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	--SP-specific parameters
	@Version nvarchar(50) = NULL OUTPUT,
	@BrandID int = NULL OUTPUT,
	@ProductName nvarchar(50) = NULL OUTPUT,
	@LongName nvarchar(100) = NULL OUTPUT,
	@OrgBrand nvarchar(50) = NULL OUTPUT,
	@Collation nvarchar(50) = NULL OUTPUT,
	@DevYN bit = NULL OUTPUT,
	@Description nvarchar(255) = NULL OUTPUT,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000086,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion int = 0, --1=[Version], 2=BrandID, 4=ProductName, 8=LongName, 16=OrgBrand, 32=Collation
	@Debug bit = 0, --1=Set @DebugBM to 3
	@DebugBM int = 0 --1=High Prio, 2=Low Prio, 4=Sub routines

--#WITH ENCRYPTION#--

AS
/*
EXEC [spGet_Version]
EXEC [spGet_Version] @GetVersion = 1 --[Version]
EXEC [spGet_Version] @GetVersion = 2 --BrandID
EXEC [spGet_Version] @GetVersion = 4 --ProductName
EXEC [spGet_Version] @GetVersion = 8 --LongName
EXEC [spGet_Version] @GetVersion = 16 --OrgBrand
EXEC [spGet_Version] @GetVersion = 32 --Collation
EXEC [spGet_Version] @GetVersion = 63 --All
EXEC [spGet_Version] @Debug = 1

DECLARE @Version nvarchar(50)
EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT
SELECT Version = @Version

DECLARE @BrandID int
EXEC [spGet_Version] @GetVersion = 0, @InstanceID = 404, @BrandID = @BrandID OUTPUT
SELECT BrandID = @BrandID

DECLARE @ProductName nvarchar(50)
EXEC [spGet_Version] @GetVersion = 0, @ProductName = @ProductName OUTPUT
SELECT ProductName = @ProductName

DECLARE @LongName nvarchar(100)
EXEC [spGet_Version] @GetVersion = 0, @LongName = @LongName OUTPUT
SELECT LongName = @LongName

DECLARE @OrgBrand nvarchar(50)
EXEC [spGet_Version] @GetVersion = 0, @OrgBrand = @OrgBrand OUTPUT
SELECT OrgBrand = @OrgBrand

DECLARE @Version nvarchar(50), @BrandID int, @ProductName nvarchar(50), @LongName nvarchar(100), @OrgBrand nvarchar(50), @Collation nvarchar(50)
EXEC [spGet_Version] @GetVersion = 0, @Version = @Version OUTPUT, @BrandID = @BrandID OUTPUT, @ProductName = @ProductName OUTPUT, @LongName = @LongName OUTPUT, @OrgBrand = @OrgBrand OUTPUT, @Collation = @Collation OUTPUT
SELECT Version = @Version, BrandID = @BrandID, ProductName = @ProductName, LongName = @LongName, OrgBrand = @OrgBrand, Collation = @Collation

EXEC [spGet_Version] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	--SP-specific variables
	@SQLStatement nvarchar(max),

	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@DatabaseName nvarchar(100),
	@ProcedureName nvarchar(100),
	@DebugSub bit = 0,
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@ToBeChanged nvarchar(255) = '',
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa'

SET @Step = 'Set Version'
	SET @Version = '2.1.2.2198'

	IF @Version = '1.2.2052' SET @Description = 'Version handling.'
	IF @Version = '1.2.2054' SET @Description = '2014-12-08 1.2 Beta'
	IF @Version = '1.2.2055' SET @Description = '2014-12-09 1.2 Beta'
	IF @Version = '1.2.2056' SET @Description = '2014-12-10 1.2 Beta'
	IF @Version = '1.2.2057' SET @Description = '2014-12-11 1.2 Beta'
	IF @Version = '1.2.2058' SET @Description = '2014-12-12 1.2 Beta'
	IF @Version = '1.2.2059' SET @Description = '2014-12-16 1.2 Beta'
	IF @Version = '1.2.2060' SET @Description = '2014-12-18 1.2 Beta'
	IF @Version = '1.2.2061' SET @Description = '2015-01-20 1.2 Beta'
	IF @Version = '1.2.2062' SET @Description = '2015-01-23 1.2 Beta'
	IF @Version = '1.2.2063' SET @Description = '2015-01-27 1.2 Beta'
	IF @Version = '1.2.2064' SET @Description = '2015-01-29 1.2 Beta'
	IF @Version = '1.2.2065' SET @Description = '2015-02-10 1.2 RC1'
	IF @Version = '1.2.2066' SET @Description = '2015-02-17 1.2 RC2'
	IF @Version = '1.2.2067' SET @Description = '2015-03-11 1.2 RC3'
	IF @Version = '1.3.2068' SET @Description = '2015-03-13 1.3 Beta'
	IF @Version = '1.2.2069' SET @Description = '2015-03-16 1.2'
	IF @Version = '1.3.2070' SET @Description = '2015-04-01 1.3 Beta'
	IF @Version = '1.3.2071' SET @Description = 'Never built'
	IF @Version = '1.2.2072' SET @Description = '2015-05-05 1.2'
	IF @Version = '1.3.2073' SET @Description = '2015-05-13 1.3 RC1'
	IF @Version = '1.3.2074' SET @Description = '2015-05-21 1.3 RC1'
	IF @Version = '1.3.2075' SET @Description = '2015-06-03 1.3 RC1'
	IF @Version = '1.3.2076' SET @Description = '2015-06-09 1.3 RC1'
	IF @Version = '1.3.2077' SET @Description = '2015-06-10 1.3 RC2'
	IF @Version = '1.3.2078' SET @Description = '2015-06-15 1.3 RC2'
	IF @Version = '1.3.2079' SET @Description = '2015-06-15 1.3 RC2'
	IF @Version = '1.3.2080' SET @Description = '2015-06-18 1.3 RC2'
	IF @Version = '1.3.2081' SET @Description = '2015-06-23 1.3 RC2'
	IF @Version = '1.3.2082' SET @Description = '2015-06-26 1.3 RC2'
	IF @Version = '1.3.2083' SET @Description = '2015-09-29 1.3 RC2'
	IF @Version = '1.3.2084' SET @Description = '2015-09-29 1.3 RC2'
	IF @Version = '1.3.2085' SET @Description = '2015-10-12 1.3 RC2'
	IF @Version = '1.3.2086' SET @Description = '2015-10-13 1.3 RC2'
	IF @Version = '1.3.2087' SET @Description = '2015-10-15 1.3 RC2'
	IF @Version = '1.3.2088' SET @Description = '2015-10-16 1.3 RC2'
	IF @Version = '1.2.2089' SET @Description = '2015-10-21 1.2'
	IF @Version = '1.2.2090' SET @Description = '2015-10-22 1.2'
	IF @Version = '1.3.2091' SET @Description = '2015-10-29 1.3 RC2'
	IF @Version = '1.3.2092' SET @Description = '2015-11-10 1.3 RC2'
	IF @Version = '1.2.2093' SET @Description = '2015-11-12 1.2'
	IF @Version = '1.3.2094' SET @Description = '2015-11-16 1.3 RC2'
	IF @Version = '1.3.2095' SET @Description = '2015-11-27 1.3 RC2'
	IF @Version = '1.3.2096' SET @Description = '2015-12-08 1.3 RC2'
	IF @Version = '1.3.2097' SET @Description = '2015-12-11 1.3 RC2'
	IF @Version = '1.3.2098' SET @Description = '2015-12-22 1.3 RC2'
	IF @Version = '1.3.2099' SET @Description = '2016-01-11 1.3 RC2'
	IF @Version = '1.3.2100' SET @Description = '2016-01-15 1.3 RC3'
	IF @Version = '1.3.2101' SET @Description = '2016-02-08 1.3 RC3'
	IF @Version = '1.3.2102' SET @Description = '2016-02-09 1.3 RC3'
	IF @Version = '1.3.2103' SET @Description = '2016-02-11 1.3 RC3'
	IF @Version = '1.3.2104' SET @Description = '2016-03-10 1.3 RC3'
	IF @Version = '1.3.2105' SET @Description = '2016-03-14 1.3 RC3'
	IF @Version = '1.3.2106' SET @Description = '2016-03-21 1.3 RC3'
	IF @Version = '1.3.2107' SET @Description = '2016-04-08 1.3 RC3'
	IF @Version = '1.3.2108' SET @Description = '2016-04-12 1.3 RC3'
	IF @Version = '1.3.2109' SET @Description = '2016-04-18 1.3 RC3'
	IF @Version = '1.3.2110' SET @Description = '2016-05-23 1.3 RC3'
	IF @Version = '1.3.2111' SET @Description = '2016-05-31 1.3 RC3'
	IF @Version = '1.3.2112' SET @Description = '2016-06-17 1.3 RC3'
	IF @Version = '1.3.2113' SET @Description = '2016-06-23 1.3 RC3'
	IF @Version = '1.3.2114' SET @Description = '2016-06-27 1.3 RC3'
	IF @Version = '1.3.2115' SET @Description = '2016-07-25 1.3 RC4'
	IF @Version = '1.3.2116' SET @Description = '2016-08-09 1.3 RC4'
	IF @Version = '1.3.2117' SET @Description = '2016-08-11 1.3 RC4'
	IF @Version = '1.3.0.2118' SET @Description = '2016-09-05 1.3 RC4'
	IF @Version = '1.3.0.2119' SET @Description = '2016-09-07 1.3 GA'
	IF @Version = '1.3.1.2120' SET @Description = '2016-10-19 1.3.1 RC1'
	IF @Version = '1.3.1.2121' SET @Description = '2016-10-31 1.3.1 RC1'
	IF @Version = '1.3.1.2122' SET @Description = '2016-11-01 1.3.1 RC1'
	IF @Version = '1.3.1.2123' SET @Description = '2016-11-03 1.3.1 RC1'
	IF @Version = '1.3.1.2124' SET @Description = '2016-11-10 1.3.1 LB'
	IF @Version = '1.3.1.2125' SET @Description = '2016-11-14 1.3.1 LB'
	IF @Version = '1.4.0.2126' SET @Description = '2016-11-24 1.4.0 LB'
	IF @Version = '1.4.0.2127' SET @Description = '2016-11-29 1.4.0 LB'
	IF @Version = '1.4.0.2128' SET @Description = '2017-01-17 1.4.0 LB'
	IF @Version = '1.4.0.2129' SET @Description = '2017-02-14 1.4.0 LB'
	IF @Version = '1.4.0.2130' SET @Description = '2017-02-21 1.4.0 LB'
	IF @Version = '1.4.0.2131' SET @Description = '2017-02-23 1.4.0 LB'
	IF @Version = '1.4.0.2132' SET @Description = '2017-02-28 1.4.0 LB'
	IF @Version = '1.4.0.2133' SET @Description = '2017-03-10 1.4.0 LB'
	IF @Version = '1.4.0.2134' SET @Description = '2017-03-30 1.4.0 LB'
	IF @Version = '1.4.0.2135' SET @Description = '2017-05-05 1.4.0 RC1'
	IF @Version = '1.4.0.2136' SET @Description = '2017-05-18 1.4.0 GA'
	IF @Version = '1.4.0.2137' SET @Description = '2017-07-01 1.4.0 GA'
	IF @Version = '1.4.0.2138' SET @Description = '2017-07-27 1.4.0 GA'
	IF @Version = '1.4.0.2139' SET @Description = '2017-09-30 1.4.0 GA'
	IF @Version = '2.0.0.2140' SET @Description = '2018-10-15 2.0.0 LB' --Christian Berner VersionID = 1013
	IF @Version = '2.0.0.2141' SET @Description = '2018-10-29 2.0.0 LB' --Christian Berner VersionID = 1013, updated
	IF @Version = '2.0.0.2142' SET @Description = '2018-10-31 2.0.0 LB'
	IF @Version = '2.0.1.2143' SET @Description = '2019-06-03 2.0.1 LB' --pcINTEGRATOR splitted
	IF @Version = '2.0.2.2144' SET @Description = '2019-07-04 2.0.2 LB'
	IF @Version = '2.0.2.2145' SET @Description = '2019-08-07 2.0.2 LB' --NOT DEPLOYED
	IF @Version = '2.0.2.2146' SET @Description = '2019-09-18 2.0.2 LB' --NOT DEPLOYED
	IF @Version = '2.0.2.2147' SET @Description = '2019-10-07 2.0.2 LB' --NOT DEPLOYED
	IF @Version = '2.0.2.2148' SET @Description = '2019-11-25 2.0.2 LB' --User and Security Management
	IF @Version = '2.0.2.2149' SET @Description = '2019-12-09 2.0.2 LB' --Bugfixes of 2.0.2.2148
	IF @Version = '2.0.2.2150' SET @Description = '2019-12-11 2.0.2 LB' --Bugfixes of 2.0.2.2149; User & Security Management
	IF @Version = '2.0.3.2151' SET @Description = '2020-01-15 2.0.3 LB' --Consolidation (BR05), bugfixes and enhancements
	IF @Version = '2.0.3.2152' SET @Description = '2020-02-14 2.0.3 LB' --Bugfixes of 2.0.2.2151; JournalDrill for Prefixed/Suffixed Dimensions
	IF @Version = '2.0.3.2153' SET @Description = '2020-03-13 2.0.3 LB' --Bugfixes of 2.0.3.2152; Advanced Consolidation; ETL for Journal
	IF @Version = '2.0.3.2154' SET @Description = '2020-05-27 2.0.3 LB' --Only for Regresssion Testing
	IF @Version = '2.1.0.2155' SET @Description = '2020-07-20 2.1.0 LB' --Only for Regresssion Testing
	IF @Version = '2.1.0.2156' SET @Description = '2020-08-14 2.1.0 LB' --Only for Regresssion Testing
	IF @Version = '2.1.0.2157' SET @Description = '2020-08-31 2.1.0 LB' --Deploy on Demo02
	IF @Version = '2.1.0.2158' SET @Description = '2020-09-04 2.1.0 LB' --Deploy on Trial01
	IF @Version = '2.1.0.2159' SET @Description = '2020-09-16 2.1.0 LB' --Deploy on Demo01
	IF @Version = '2.1.0.2160' SET @Description = '2020-09-21 2.1.0 LB' --Deploy on Trial01 and Test03
	IF @Version = '2.1.0.2161' SET @Description = '2020-10-09 2.1.0 LB' --Hotfix for Test03
	IF @Version = '2.1.0.2162' SET @Description = '2020-12-03 2.1.0 LB' --Deploy on Test03; Candidate for PROD
	IF @Version = '2.1.0.2163' SET @Description = '2021-01-29 2.1.0 LB' --Deploy on Beta01; Candidate for PROD
	IF @Version = '2.1.0.2164' SET @Description = '2021-02-05 2.1.0 LB' --Deploy on Demo01; Candidate for PROD
	IF @Version = '2.1.0.2165' SET @Description = '2021-02-22 2.1.0 LB' --Deploy on EFPDEMO02
	IF @Version = '2.1.0.2167' SET @Description = '2021-04-01 2.1.0 LB' --Deploy on EfpCarrierProd; Telia Carrier
	IF @Version = '2.1.1.2168' SET @Description = '2021-04-05 2.1.1 LB' --Never Deployed; Mistakenly destroyed by copying from PROD
	IF @Version = '2.1.1.2169' SET @Description = '2021-04-15 2.1.1 LB' --Deploy on TEST03; Candidate for PROD
	IF @Version = '2.1.1.2170' SET @Description = '2021-05-04 2.1.1 LB' --Partial Upgrade for DEMO02 and PROD
	IF @Version = '2.1.1.2171' SET @Description = '2021-08-04 2.1.1 LB' --Deploy on TEST03; Candidate for PROD
	IF @Version = '2.1.1.2172' SET @Description = '2021-10-04 2.1.1 LB' --Scenario-handling deployed to PROD
	IF @Version = '2.1.1.2173' SET @Description = '2021-10-20 2.1.1 LB' --Upgrade of ProcedureID handling for custom DBs
	IF @Version = '2.1.1.2174' SET @Description = '2021-11-22 2.1.1 LB' --Deploy on PROD, DEMO and PRODAU (schema and SP changes related to REM Commission Rule)
	IF @Version = '2.1.2.2175' SET @Description = '2021-11-29 2.1.1 LB' --Candidate for PROD
	IF @Version = '2.1.2.2177' SET @Description = '2022-01-18 2.1.1 LB' --Deployed to DSPPROD03
	IF @Version = '2.1.2.2178' SET @Description = '2022-01-24 2.1.1 LB' --Deployed to DSPPROD03
	IF @Version = '2.1.2.2179' SET @Description = '2022-04-05 2.1.2 LB' --Deployed to DSPSTAGE01
	IF @Version = '2.1.2.2181' SET @Description = '2022-06-03 2.1.2 LB' --Deployed to DSPSTAGE01 (copy of DSPPROD03)
	IF @Version = '2.1.2.2182' SET @Description = '2022-07-13 2.1.2 LB' --Deployed to DSPSTAGEAU01 (copy of DSPPRODAU01)
	IF @Version = '2.1.2.2183' SET @Description = '2022-07-31 2.1.2 LB' --Deployed to DSPPRODAU01 (copy of fixes done on DSPSTAGEAU01)
	IF @Version = '2.1.2.2184' SET @Description = '2022-08-06 2.1.2 LB' --Deployed to DSPPROD03 (copy of DSPPRODAU01)
	IF @Version = '2.1.2.2185' SET @Description = '2022-08-17 2.1.2 LB' --Deployed to DSPSTAGE01 (copy of DSPPROD02); Candidate for DSPPROD02
	IF @Version = '2.1.2.2186' SET @Description = '2022-08-20 2.1.2 LB' --Deployed to DSPPROD02
	IF @Version = '2.1.2.2187' SET @Description = '2022-10-04 2.1.2 LB' --Deployed to DSPPROD02, DSPPRODAU01, DSPPROD03, EFPDEMO01
	IF @Version = '2.1.2.2188' SET @Description = '2022-10-11 2.1.2 LB' --Deployed to DSPPROD02, DSPPRODAU01, DSPPROD03, EFPDEMO01
	IF @Version = '2.1.2.2189' SET @Description = '2022-10-19 2.1.2 LB' --Deployed to DSPPROD02, DSPPRODAU01, DSPPROD03, EFPDEMO01
	IF @Version = '2.1.2.2190' SET @Description = '2022-11-28 2.1.2 LB' --Deployed to DSPPROD02, DSPPRODAU01, DSPPROD03, EFPDEMO01
	IF @Version = '2.1.2.2191' SET @Description = '2023-01-23 2.1.2 LB' --Deployed to DSPPROD02, DSPPRODAU01, DSPPROD03, EFPDEMO01
	IF @Version = '2.1.2.2192' SET @Description = '2023-02-13 2.1.2 LB' --Deployed to DSPPROD02, DSPPRODAU01, DSPPROD03, EFPDEMO01
	IF @Version = '2.1.2.2193' SET @Description = '2023-03-27 2.1.2 LB' --Deployed to DSPPROD02, DSPPRODAU01, DSPPROD03, EFPDEMO01
	IF @Version = '2.1.2.2194' SET @Description = '2023-04-03 2.1.2 LB' --Deployed to DSPPROD02, DSPPRODAU01, DSPPROD03, EFPDEMO01
	IF @Version = '2.1.2.2195' SET @Description = '2023-04-17 2.1.2 LB' --Candidate for PROD
	IF @Version = '2.1.2.2196' SET @Description = '2023-05-30 2.1.2 LB' --Deployed to DSPPROD02
	IF @Version = '2.1.2.2197' SET @Description = '2023-07-05 2.1.2 LB' --Deployed to DSPPROD02, DSPPRODAU01, DSPPROD03, EFPDEMO01
	IF @Version = '2.1.2.2198' SET @Description = '2023-10-18 2.1.2 LB' --Deployed to DSPPROD02, DSPPRODAU01, DSPPROD03, EFPDEMO01

IF @GetVersion = 1
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'SP to return Version and version related properties',
			@MandatoryParameter = '' --Without @, separated by |
		EXEC [spSet_Procedure] @CalledProcedureID = @ProcedureID, @CalledProcedureName = @ProcedureName, @CalledProcedureDescription = @ProcedureDescription, @CalledMandatoryParameter = @MandatoryParameter, @CalledVersion = @Version, @CalledVersionDescription = @Description, @CalledCreatedBy = @CreatedBy, @CalledModifiedBy =  @ModifiedBy
		RETURN
	END

SET NOCOUNT ON 

BEGIN TRY
	SET @Step = 'Set @StartTime'
		SET @StartTime = ISNULL(@StartTime, GETDATE())

	SET @Step = 'Set procedure variables'
		SELECT
			@JobID = ISNULL(@JobID, @ProcedureID),
			@DatabaseName = DB_NAME(),
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

		IF @Debug <> 0 AND @DebugBM = 0 SET @DebugBM = 3
		IF @Debug = 0 AND @DebugBM & 3 > 0 SET @Debug = 1
		IF @DebugBM & 4 > 0 SET @DebugSub = 1

		IF (SELECT COUNT(1) FROM sys.databases WHERE [name] = 'pcINTEGRATOR_Data') = 0
			SET @BrandID = 1
		ELSE
			IF @InstanceID IS NOT NULL
				SELECT @BrandID = BrandID FROM Instance WHERE InstanceID = @InstanceID
			ELSE
				SET @BrandID = 1

		SET @DevYN = 1
		SET @Collation = 'SQL_Latin1_General_CP1_CI_AS'

	SET @Step = 'SET Base Value dependent properties'
		SELECT 
			BrandID,
			ProductName = [BrandName],
			LongName = [BrandDescription],
			OrgBrand = [BrandLabel]
		INTO
			#Brand
		FROM
			[Brand]

		SELECT
			@ProductName = ProductName,
			@LongName = LongName,
			@OrgBrand = OrgBrand
		FROM
			#Brand
		WHERE
			BrandID = @BrandID

	SET @Step = 'Debug'
		IF @Debug <> 0 
			BEGIN
				SELECT [Version] = @Version, BrandID = @BrandID, ProductName = @ProductName, LongName = @LongName, OrgBrand = @OrgBrand, Collation = @Collation
				PRINT 'Version = ' + @Version + ', BrandID = ' + CONVERT(nvarchar(10), @BrandID) + ', ProductName = ' + @ProductName + ', LongName = ' + @LongName + ', OrgBrand = ' + @OrgBrand + ', Collation = ' + @Collation
			END

	SET @Step = 'GetVersion'
		IF @GetVersion <> 0
			BEGIN
				SET @SQLStatement = 'SELECT'
				IF @GetVersion & 1 > 0 SET @SQLStatement = @SQLStatement + ' [Version] = ''' + @Version + ''','
				IF @GetVersion & 2 > 0 SET @SQLStatement = @SQLStatement + ' [BrandID] = ' + CONVERT(nvarchar(10), @BrandID) + ','
				IF @GetVersion & 4 > 0 SET @SQLStatement = @SQLStatement + ' [ProductName] = ''' + @ProductName + ''','
				IF @GetVersion & 8 > 0 SET @SQLStatement = @SQLStatement + ' [LongName] = ''' + @LongName + ''','
				IF @GetVersion & 16 > 0 SET @SQLStatement = @SQLStatement + ' [OrgBrand] = ''' + @OrgBrand + ''','
				IF @GetVersion & 32 > 0 SET @SQLStatement = @SQLStatement + ' [Collation] = ''' + @Collation + ''','

				SET @SQLStatement = SUBSTRING(@SQLStatement, 1, LEN(@SQLStatement) -1)

				EXEC (@SQLStatement)
			END

	SET @Step = 'Drop temp tables'
		DROP TABLE #Brand

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
--		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
END TRY

BEGIN CATCH
	SELECT @Duration = GetDate() - @StartTime, @ErrorNumber = ERROR_NUMBER(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE(), @ErrorProcedure = ERROR_PROCEDURE(), @ErrorLine = ERROR_LINE(), @ErrorMessage = ERROR_MESSAGE()
	EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @ErrorSeverity = @ErrorSeverity, @ErrorState = @ErrorState, @ErrorProcedure = @ErrorProcedure, @ErrorStep = @Step, @ErrorLine = @ErrorLine, @ErrorMessage = @ErrorMessage, @LogVersion = @Version, @UserName = @UserName
	SELECT ErrorNumber = @ErrorNumber, ErrorSeverity = @ErrorSeverity, ErrorState = @ErrorState, ErrorProcedure = @ErrorProcedure, ErrorStep = @Step, ErrorLine = @ErrorLine, ErrorMessage = @ErrorMessage
	RETURN @ErrorNumber
END CATCH

SET @Step = 'Define exit point'
	EXITPOINT:
	RAISERROR (@Message, @Severity, 100)
GO
