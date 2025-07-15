SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [dbo].[sp_Tool_Set_DataObject]
	@UserID int = NULL,
	@InstanceID int = NULL,
	@VersionID int = NULL,

	@ReturnDataYN bit = 1,

	@JobID int = NULL,
	@JobLogID int = NULL,
	@Rows int = NULL,
	@ProcedureID int = 880000421,
	@StartTime datetime = NULL,
	@Duration time(7) = '00:00:00' OUT,
	@Deleted int = 0 OUT,
	@Inserted int = 0 OUT,
	@Updated int = 0 OUT,
	@Selected int = 0 OUT,
	@GetVersion bit = 0,
	@Debug bit = 0

--#WITH ENCRYPTION#--

AS
/*
EXEC spRun_Procedure_KeyValuePair
	@ProcedureName = 'sp_Tool_Set_DataObject',
	@JSON = '
		[
		{"TKey" : "UserID",  "TValue": "-10"},
		{"TKey" : "InstanceID",  "TValue": "390"},
		{"TKey" : "VersionID",  "TValue": "1011"}
		]'

EXEC [sp_Tool_Set_DataObject] @UserID=-10, @InstanceID=390, @VersionID=1011, @Debug=1

EXEC [sp_Tool_Set_DataObject] @GetVersion = 1
*/

SET ANSI_WARNINGS OFF

DECLARE
	@Step nvarchar(255),
	@Message nvarchar(500) = '',
	@Severity int = 0,
	@UserName nvarchar(100),
	@ProcedureName nvarchar(100),
	@ErrorNumber int = 0,
	@ErrorSeverity int,
	@ErrorState int,
	@ErrorProcedure nvarchar(128),
	@ErrorLine int,
	@ErrorMessage nvarchar(4000), 
	@ProcedureDescription nvarchar(1024),
	@MandatoryParameter nvarchar(1000),
	@Description nvarchar(255),
	@CreatedBy nvarchar(50) = 'JaWo',
	@ModifiedBy nvarchar(50) = 'NeHa',
	@Version nvarchar(50) = '2.1.1.2177'

IF @GetVersion <> 0
	BEGIN
		SELECT
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@ProcedureDescription = 'Update and return rows from table [DataObject]',
			@MandatoryParameter = '' --Without @, separated by |

		IF @Version = '2.0.0.2142' SET @Description = 'Procedure created.'
		IF @Version = '2.0.1.2143' SET @Description = 'Handle splitted databases.'
		IF @Version = '2.0.2.2144' SET @Description = 'Renamed to [sp_Tool_Set_DataObject] from [spGet_DataObject].'
		IF @Version = '2.0.2.2146' SET @Description = 'Added DeletedIDYN column to [DataObject] table.'
		IF @Version = '2.1.1.2177' SET @Description = 'Changed order of execution: UPDATE Deleted objects first, before Updating non-deleted objects.'

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
			@ProcedureName = OBJECT_NAME(@@PROCID),
			@Deleted = ISNULL(@Deleted, 0),
			@Inserted = ISNULL(@Inserted, 0),
			@Updated = ISNULL(@Updated, 0),
			@Selected = ISNULL(@Selected, 0)

		SET @UserName = ISNULL(@UserName, suser_name())

--==============
--pcINTEGRATOR--
--==============
		
	SET @Step = 'Update deleted tables from pcINTEGRATOR'
		UPDATE DO
		SET
			[DeletedYN] = 1
		FROM
			[pcINTEGRATOR].[dbo].[DataObject] DO
		WHERE
			DO.[DatabaseName] = 'pcINTEGRATOR' AND
			DO.[ObjectType] <> 'View' AND
			DO.[DeletedYN] = 0 AND
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR.sys.tables t WHERE t.[type] = 'U' AND t.[name] = DO.[DataObjectName])
		
	SET @Step = 'Update deleted views from pcINTEGRATOR'
		UPDATE DO
		SET
			[DeletedYN] = 1
		FROM
			[pcINTEGRATOR].[dbo].[DataObject] DO
		WHERE
			DO.[DatabaseName] = 'pcINTEGRATOR' AND
			DO.[ObjectType] = 'View' AND
			DO.[DeletedYN] = 0 AND
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR.sys.views v WHERE v.[type] = 'V' AND DO.[DataObjectName] = v.[name])

	SET @Step = 'Insert new tables from pcINTEGRATOR'
		INSERT INTO [pcINTEGRATOR].[dbo].[DataObject]
			(
			[DataObjectName],
			[ObjectType],
			[DatabaseName],
			[IdentityYN],
			[InstanceIDYN],
			[VersionIDYN],
			[Created],
			[Changed]
			)
		SELECT DISTINCT
			[DataObjectName] = t.[name],
			[ObjectType] = CASE WHEN t.[name] LIKE '@Template%' THEN 'Template' ELSE 'Table' END,
			[DatabaseName] = 'pcINTEGRATOR',
			[IdentityYN] = ISNULL(c.is_identity, 0),
			[InstanceIDYN] = CASE WHEN i.[name] = 'InstanceID' THEN 1 ELSE 0 END,
			[VersionIDYN] = CASE WHEN v.[name] = 'VersionID' THEN 1 ELSE 0 END,
			[Created] = t.[create_date],
			[Changed] = t.[modify_date]
		FROM
			pcINTEGRATOR.sys.tables t
			LEFT JOIN pcINTEGRATOR.sys.columns c ON c.object_id = t.object_id AND c.is_identity <> 0
			LEFT JOIN pcINTEGRATOR.sys.columns i ON i.object_id = t.object_id AND i.[name] = 'InstanceID'
			LEFT JOIN pcINTEGRATOR.sys.columns v ON v.object_id = t.object_id AND v.[name] = 'VersionID'
		WHERE
			[type] = 'U' AND
			t.[name] NOT LIKE '%_tmp' AND t.[name] NOT LIKE 'tmp_%' AND t.[name] NOT LIKE '%_eve' AND t.[name] NOT LIKE '%_new' AND t.[name] NOT LIKE '%_old' AND t.[name] <> 'sysdiagrams' AND ISNUMERIC(RIGHT(t.[name], 1)) = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DataObject] DO WHERE DO.[DataObjectName] = t.[name] AND DO.[ObjectType] = CASE WHEN t.[name] LIKE '@Template%' THEN 'Template' ELSE 'Table' END AND DO.[DatabaseName] = 'pcINTEGRATOR')
		ORDER BY
			t.[name]

	SET @Step = 'Update tables from pcINTEGRATOR'
		UPDATE DO
		SET
			[ObjectType] = CASE WHEN t.[name] LIKE '@Template%' THEN 'Template' ELSE 'Table' END,
			[IdentityYN] = ISNULL(c.is_identity, 0),
			[InstanceIDYN] = CASE WHEN i.[name] = 'InstanceID' THEN 1 ELSE 0 END,
			[VersionIDYN] = CASE WHEN v.[name] = 'VersionID' THEN 1 ELSE 0 END,
			[Created] = t.[create_date],
			[Changed] = t.[modify_date],
			[DeletedYN] = 0
		FROM
			[pcINTEGRATOR].[dbo].[DataObject] DO
			INNER JOIN pcINTEGRATOR.sys.tables t ON t.[name] = DO.[DataObjectName]
			LEFT JOIN pcINTEGRATOR.sys.columns c ON c.object_id = t.object_id AND c.is_identity <> 0
			LEFT JOIN pcINTEGRATOR.sys.columns i ON i.object_id = t.object_id AND i.[name] = 'InstanceID'
			LEFT JOIN pcINTEGRATOR.sys.columns v ON v.object_id = t.object_id AND v.[name] = 'VersionID'
		WHERE
			t.[type] = 'U' AND
			DO.[DatabaseName] = 'pcINTEGRATOR' AND
			(
			DO.[ObjectType] <> CASE WHEN t.[name] LIKE '@Template%' THEN 'Template' ELSE 'Table' END OR
			DO.[IdentityYN] <> ISNULL(c.is_identity, 0) OR
			DO.[InstanceIDYN] <> CASE WHEN i.[name] = 'InstanceID' THEN 1 ELSE 0 END OR
			DO.[VersionIDYN] <> CASE WHEN v.[name] = 'VersionID' THEN 1 ELSE 0 END OR
			DO.[Created] <> t.[create_date] OR
			DO.[Changed] <> t.[modify_date] OR
			DO.[DeletedYN] <> 0
			)

	SET @Step = 'Insert new views from pcINTEGRATOR'
		INSERT INTO [pcINTEGRATOR].[dbo].[DataObject]
			(
			[DataObjectName],
			[ObjectType],
			[DatabaseName],
			[IdentityYN],
			[Created],
			[Changed]
			)
		SELECT DISTINCT
			[DataObjectName] = v.[name],
			[ObjectType] = 'View',
			[DatabaseName] = 'pcINTEGRATOR',
			[IdentityYN] = 0,
			[Created] = v.[create_date],
			[Changed] = v.[modify_date]
		FROM
			pcINTEGRATOR.sys.views v
		WHERE
			v.[type] = 'V' AND
			v.[name] NOT LIKE '%_tmp' AND v.[name] NOT LIKE 'tmp_%' AND v.[name] NOT LIKE '%_eve' AND v.[name] NOT LIKE '%_new' AND v.[name] NOT LIKE '%_old' AND v.[name] <> 'sysdiagrams' AND ISNUMERIC(RIGHT(v.[name], 1)) = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DataObject] DO WHERE DO.[DataObjectName] = v.[name] AND DO.[DatabaseName] = 'pcINTEGRATOR' AND DO.[ObjectType] = 'View')
		ORDER BY
			v.[name]

	SET @Step = 'Update views from pcINTEGRATOR'
		UPDATE DO
		SET
			[ObjectType] = 'View',
			[IdentityYN] = 0,
			[InstanceIDYN] = 0,
			[Created] = v.[create_date],
			[Changed] = v.[modify_date],
			[DeletedYN] = 0
		FROM
			[pcINTEGRATOR].[dbo].[DataObject] DO
			INNER JOIN pcINTEGRATOR.sys.views v ON v.[name] = DO.[DataObjectName]
		WHERE
			v.[type] = 'V' AND
			DO.[DatabaseName] = 'pcINTEGRATOR' AND
			DO.[DeletedYN] = 0 AND
			(
			DO.[ObjectType] <> 'View' OR
			DO.[IdentityYN] <> 0 OR
			DO.[InstanceIDYN] <> 0 OR
			DO.[Created] <> v.[create_date] OR
			DO.[Changed] <> v.[modify_date] --OR
			--DO.[DeletedYN] <> 0 
			)

--===================
--pcINTEGRATOR_Data--
--===================
		
	SET @Step = 'Update deleted tables from pcINTEGRATOR_Data'
		UPDATE DO
		SET
			[DeletedYN] = 1
		FROM
			[pcINTEGRATOR].[dbo].[DataObject] DO
		WHERE
			DO.[DatabaseName] = 'pcINTEGRATOR_Data' AND
			DO.[ObjectType] <> 'View' AND
			DO.[DeletedYN] = 0 AND
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data.sys.tables t WHERE t.[type] = 'U' AND t.[name] = DO.[DataObjectName])

	SET @Step = 'Update deleted views from pcINTEGRATOR_Data'
		UPDATE DO
		SET
			[DeletedYN] = 1
		FROM
			[pcINTEGRATOR].[dbo].[DataObject] DO
		WHERE
			DO.[DatabaseName] = 'pcINTEGRATOR_Data' AND
			DO.[ObjectType] = 'View' AND
			DO.[DeletedYN] = 0 AND
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Data.sys.views v WHERE v.[type] = 'V' AND DO.[DataObjectName] = v.[name])

	SET @Step = 'Insert new tables from pcINTEGRATOR_Data'
		INSERT INTO [pcINTEGRATOR].[dbo].[DataObject]
			(
			[DataObjectName],
			[ObjectType],
			[DatabaseName],
			[IdentityYN],
			[InstanceIDYN],
			[VersionIDYN],
			[DeletedIDYN],
			[Created],
			[Changed]
			)
		SELECT DISTINCT
			[DataObjectName] = t.[name],
			[ObjectType] = CASE WHEN t.[name] LIKE '@Template%' THEN 'Template' ELSE 'Table' END,
			[DatabaseName] = 'pcINTEGRATOR_Data',
			[IdentityYN] = ISNULL(c.is_identity, 0),
			[InstanceIDYN] = CASE WHEN i.[name] = 'InstanceID' THEN 1 ELSE 0 END,
			[VersionIDYN] = CASE WHEN v.[name] = 'VersionID' THEN 1 ELSE 0 END,
			[DeletedIDYN] = CASE WHEN d.[name] = 'DeletedID' THEN 1 ELSE 0 END,
			[Created] = t.[create_date],
			[Changed] = t.[modify_date]
		FROM
			pcINTEGRATOR_Data.sys.tables t
			LEFT JOIN pcINTEGRATOR_Data.sys.columns c ON c.object_id = t.object_id AND c.is_identity <> 0
			LEFT JOIN pcINTEGRATOR_Data.sys.columns i ON i.object_id = t.object_id AND i.[name] = 'InstanceID'
			LEFT JOIN pcINTEGRATOR_Data.sys.columns v ON v.object_id = t.object_id AND v.[name] = 'VersionID'
			LEFT JOIN pcINTEGRATOR_Data.sys.columns d ON d.object_id = t.object_id AND d.[name] = 'DeletedID'
		WHERE
			[type] = 'U' AND
			t.[name] NOT LIKE '%_tmp' AND t.[name] NOT LIKE 'tmp_%' AND t.[name] NOT LIKE '%_eve' AND t.[name] NOT LIKE '%_new' AND t.[name] NOT LIKE '%_old' AND t.[name] <> 'sysdiagrams' AND ISNUMERIC(RIGHT(t.[name], 1)) = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DataObject] DO WHERE DO.[DataObjectName] = t.[name] AND [ObjectType] = CASE WHEN t.[name] LIKE '@Template%' THEN 'Template' ELSE 'Table' END AND DO.[DatabaseName] = 'pcINTEGRATOR_Data')
		ORDER BY
			t.[name]

	SET @Step = 'Update tables from pcINTEGRATOR_Data'
		UPDATE DO
		SET
			[ObjectType] = CASE WHEN t.[name] LIKE '@Template%' THEN 'Template' ELSE 'Table' END,
			[IdentityYN] = ISNULL(c.is_identity, 0),
			[InstanceIDYN] = CASE WHEN i.[name] = 'InstanceID' THEN 1 ELSE 0 END,
			[VersionIDYN] = CASE WHEN v.[name] = 'VersionID' THEN 1 ELSE 0 END,
			[DeletedIDYN] = CASE WHEN d.[name] = 'DeletedID' THEN 1 ELSE 0 END,
			[Created] = t.[create_date],
			[Changed] = t.[modify_date],
			[DeletedYN] = 0
		FROM
			[pcINTEGRATOR].[dbo].[DataObject] DO
			INNER JOIN pcINTEGRATOR_Data.sys.tables t ON t.[name] = DO.[DataObjectName]
			LEFT JOIN pcINTEGRATOR_Data.sys.columns c ON c.object_id = t.object_id AND c.is_identity <> 0
			LEFT JOIN pcINTEGRATOR_Data.sys.columns i ON i.object_id = t.object_id AND i.[name] = 'InstanceID'
			LEFT JOIN pcINTEGRATOR_Data.sys.columns v ON v.object_id = t.object_id AND v.[name] = 'VersionID'
			LEFT JOIN pcINTEGRATOR_Data.sys.columns d ON d.object_id = t.object_id AND d.[name] = 'DeletedID'
		WHERE
			t.[type] = 'U' AND
			DO.[DatabaseName] = 'pcINTEGRATOR_Data' AND
			DO.[DeletedYN] = 0 AND
			(
			DO.[ObjectType] <> CASE WHEN t.[name] LIKE '@Template%' THEN 'Template' ELSE 'Table' END OR
			DO.[IdentityYN] <> ISNULL(c.is_identity, 0) OR
			DO.[InstanceIDYN] <> CASE WHEN i.[name] = 'InstanceID' THEN 1 ELSE 0 END OR
			DO.[VersionIDYN] <> CASE WHEN v.[name] = 'VersionID' THEN 1 ELSE 0 END OR
			DO.[DeletedIDYN] <> CASE WHEN d.[name] = 'DeletedID' THEN 1 ELSE 0 END OR
			DO.[Created] <> t.[create_date] OR
			DO.[Changed] <> t.[modify_date] --OR
			--DO.[DeletedYN] <> 0
			)

	SET @Step = 'Insert new views from pcINTEGRATOR_Data'
		INSERT INTO [pcINTEGRATOR].[dbo].[DataObject]
			(
			[DataObjectName],
			[ObjectType],
			[DatabaseName],
			[IdentityYN],
			[Created],
			[Changed]
			)
		SELECT DISTINCT
			[DataObjectName] = v.[name],
			[ObjectType] = 'View',
			[DatabaseName] = 'pcINTEGRATOR_Data',
			[IdentityYN] = 0,
			[Created] = v.[create_date],
			[Changed] = v.[modify_date]
		FROM
			pcINTEGRATOR_Data.sys.views v
		WHERE
			v.[type] = 'V' AND
			v.[name] NOT LIKE '%_tmp' AND v.[name] NOT LIKE 'tmp_%' AND v.[name] NOT LIKE '%_eve' AND v.[name] NOT LIKE '%_new' AND v.[name] NOT LIKE '%_old' AND v.[name] <> 'sysdiagrams' AND ISNUMERIC(RIGHT(v.[name], 1)) = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DataObject] DO WHERE DO.[DataObjectName] = v.[name] AND [ObjectType] = 'View' AND DO.[DatabaseName] = 'pcINTEGRATOR_Data')
		ORDER BY
			v.[name]

	SET @Step = 'Update views from pcINTEGRATOR_Data'
		UPDATE DO
		SET
			[ObjectType] = 'View',
			[IdentityYN] = 0,
			[InstanceIDYN] = 0,
			[Created] = v.[create_date],
			[Changed] = v.[modify_date],
			[DeletedYN] = 0
		FROM
			[pcINTEGRATOR].[dbo].[DataObject] DO
			INNER JOIN pcINTEGRATOR_Data.sys.views v ON v.[name] = DO.[DataObjectName]
		WHERE
			v.[type] = 'V' AND
			DO.[DatabaseName] = 'pcINTEGRATOR_Data' AND
			(
			DO.[ObjectType] <> 'View' OR
			DO.[IdentityYN] <> 0 OR
			DO.[InstanceIDYN] <> 0 OR
			DO.[Created] <> v.[create_date] OR
			DO.[Changed] <> v.[modify_date] OR
			DO.[DeletedYN] <> 0
			)

--===================
--pcINTEGRATOR_Log--
--===================
	
	SET @Step = 'Update deleted tables from pcINTEGRATOR_Log'
		UPDATE DO
		SET
			[DeletedYN] = 1
		FROM
			[pcINTEGRATOR].[dbo].[DataObject] DO
		WHERE
			DO.[DatabaseName] = 'pcINTEGRATOR_Log' AND
			DO.[ObjectType] <> 'View' AND
			DO.[DeletedYN] = 0 AND
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Log.sys.tables t WHERE t.[type] = 'U' AND t.[name] = DO.[DataObjectName])
	
	SET @Step = 'Update deleted views from pcINTEGRATOR_Log'
		UPDATE DO
		SET
			[DeletedYN] = 1
		FROM
			[pcINTEGRATOR].[dbo].[DataObject] DO
		WHERE
			DO.[DatabaseName] = 'pcINTEGRATOR_Log' AND
			DO.[ObjectType] = 'View' AND
			DO.[DeletedYN] = 0 AND
			NOT EXISTS (SELECT 1 FROM pcINTEGRATOR_Log.sys.views v WHERE v.[type] = 'V' AND DO.[DataObjectName] = v.[name])

	SET @Step = 'Insert new tables from pcINTEGRATOR_Log'
		INSERT INTO [pcINTEGRATOR].[dbo].[DataObject]
			(
			[DataObjectName],
			[ObjectType],
			[DatabaseName],
			[IdentityYN],
			[InstanceIDYN],
			[VersionIDYN],
			[Created],
			[Changed]
			)
		SELECT DISTINCT
			[DataObjectName] = t.[name],
			[ObjectType] = CASE WHEN t.[name] LIKE '@Template%' THEN 'Template' ELSE 'Table' END,
			[DatabaseName] = 'pcINTEGRATOR_Log',
			[IdentityYN] = ISNULL(c.is_identity, 0),
			[InstanceIDYN] = CASE WHEN i.[name] = 'InstanceID' THEN 1 ELSE 0 END,
			[VersionIDYN] = CASE WHEN v.[name] = 'VersionID' THEN 1 ELSE 0 END,
			[Created] = t.[create_date],
			[Changed] = t.[modify_date]
		FROM
			pcINTEGRATOR_Log.sys.tables t
			LEFT JOIN pcINTEGRATOR_Log.sys.columns c ON c.object_id = t.object_id AND c.is_identity <> 0
			LEFT JOIN pcINTEGRATOR_Log.sys.columns i ON i.object_id = t.object_id AND i.[name] = 'InstanceID'
			LEFT JOIN pcINTEGRATOR_Log.sys.columns v ON v.object_id = t.object_id AND v.[name] = 'VersionID'
		WHERE
			[type] = 'U' AND
			t.[name] NOT LIKE '%_tmp' AND t.[name] NOT LIKE 'tmp_%' AND t.[name] NOT LIKE '%_eve' AND t.[name] NOT LIKE '%_new' AND t.[name] NOT LIKE '%_old' AND t.[name] <> 'sysdiagrams' AND ISNUMERIC(RIGHT(t.[name], 1)) = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DataObject] DO WHERE DO.[DataObjectName] = t.[name] AND [ObjectType] = CASE WHEN t.[name] LIKE '@Template%' THEN 'Template' ELSE 'Table' END AND DO.[DatabaseName] = 'pcINTEGRATOR_Log')
		ORDER BY
			t.[name]

	SET @Step = 'Update tables from pcINTEGRATOR_Log'
		UPDATE DO
		SET
			[ObjectType] = CASE WHEN t.[name] LIKE '@Template%' THEN 'Template' ELSE 'Table' END,
			[IdentityYN] = ISNULL(c.is_identity, 0),
			[InstanceIDYN] = CASE WHEN i.[name] = 'InstanceID' THEN 1 ELSE 0 END,
			[VersionIDYN] = CASE WHEN v.[name] = 'VersionID' THEN 1 ELSE 0 END,
			[Created] = t.[create_date],
			[Changed] = t.[modify_date],
			[DeletedYN] = 0
		FROM
			[pcINTEGRATOR].[dbo].[DataObject] DO
			INNER JOIN pcINTEGRATOR_Log.sys.tables t ON t.[name] = DO.[DataObjectName]
			LEFT JOIN pcINTEGRATOR_Log.sys.columns c ON c.object_id = t.object_id AND c.is_identity <> 0
			LEFT JOIN pcINTEGRATOR_Log.sys.columns i ON i.object_id = t.object_id AND i.[name] = 'InstanceID'
			LEFT JOIN pcINTEGRATOR_Log.sys.columns v ON v.object_id = t.object_id AND v.[name] = 'VersionID'
		WHERE
			t.[type] = 'U' AND
			DO.[DatabaseName] = 'pcINTEGRATOR_Log' AND
			(
			DO.[ObjectType] <> CASE WHEN t.[name] LIKE '@Template%' THEN 'Template' ELSE 'Table' END OR
			DO.[IdentityYN] <> ISNULL(c.is_identity, 0) OR
			DO.[InstanceIDYN] <> CASE WHEN i.[name] = 'InstanceID' THEN 1 ELSE 0 END OR
			DO.[VersionIDYN] <> CASE WHEN v.[name] = 'VersionID' THEN 1 ELSE 0 END OR
			DO.[Created] <> t.[create_date] OR
			DO.[Changed] <> t.[modify_date] OR
			DO.[DeletedYN] <> 0
			)

	SET @Step = 'Insert new views from pcINTEGRATOR_Log'
		INSERT INTO [pcINTEGRATOR].[dbo].[DataObject]
			(
			[DataObjectName],
			[ObjectType],
			[DatabaseName],
			[IdentityYN],
			[Created],
			[Changed]
			)
		SELECT DISTINCT
			[DataObjectName] = v.[name],
			[ObjectType] = 'View',
			[DatabaseName] = 'pcINTEGRATOR_Log',
			[IdentityYN] = 0,
			[Created] = v.[create_date],
			[Changed] = v.[modify_date]
		FROM
			pcINTEGRATOR_Log.sys.views v
		WHERE
			v.[type] = 'V' AND
			v.[name] NOT LIKE '%_tmp' AND v.[name] NOT LIKE 'tmp_%' AND v.[name] NOT LIKE '%_eve' AND v.[name] NOT LIKE '%_new' AND v.[name] NOT LIKE '%_old' AND v.[name] <> 'sysdiagrams' AND ISNUMERIC(RIGHT(v.[name], 1)) = 0 AND
			NOT EXISTS (SELECT 1 FROM [pcINTEGRATOR].[dbo].[DataObject] DO WHERE DO.[DataObjectName] = v.[name] AND [ObjectType] = 'View' AND DO.[DatabaseName] = 'pcINTEGRATOR_Log')
		ORDER BY
			v.[name]

	SET @Step = 'Update views from pcINTEGRATOR_Log'
		UPDATE DO
		SET
			[ObjectType] = 'View',
			[IdentityYN] = 0,
			[InstanceIDYN] = 0,
			[Created] = v.[create_date],
			[Changed] = v.[modify_date],
			[DeletedYN] = 0
		FROM
			[pcINTEGRATOR].[dbo].[DataObject] DO
			INNER JOIN pcINTEGRATOR_Log.sys.views v ON v.[name] = DO.[DataObjectName]
		WHERE
			v.[type] = 'V' AND
			DO.[DatabaseName] = 'pcINTEGRATOR_Log' AND
			(
			DO.[ObjectType] <> 'View' OR
			DO.[IdentityYN] <> 0 OR
			DO.[InstanceIDYN] <> 0 OR
			DO.[Created] <> v.[create_date] OR
			DO.[Changed] <> v.[modify_date] OR
			DO.[DeletedYN] <> 0
			)

	SET @Step = 'Return rows from [DataObject]'
		IF @ReturnDataYN <> 0
			BEGIN
				SELECT 
					*
				FROM
					[pcINTEGRATOR].[dbo].[DataObject]
				WHERE
					[DeletedYN] = 0
				ORDER BY
					ISNULL([SortOrder], 0) DESC,
					[DataObjectName]
			END

	SET @Step = 'Set @Duration'
		SET @Duration = GetDate() - @StartTime

	SET @Step = 'Insert into JobLog'
		EXEC [spSet_JobLog] @UserID = @UserID, @InstanceID = @InstanceID, @VersionID = @VersionID, @JobID = @JobID, @JobLogID = @JobLogID, @LogStartTime = @StartTime, @ProcedureName = @ProcedureName, @Duration = @Duration, @Deleted = @Deleted, @Inserted = @Inserted, @Updated = @Updated, @Selected = @Selected, @ErrorNumber = @ErrorNumber, @LogVersion = @Version, @UserName = @UserName
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
